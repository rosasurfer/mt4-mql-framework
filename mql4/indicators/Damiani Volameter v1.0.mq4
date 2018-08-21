/**
 * Damiani Volameter v1.0
 *
 * Completely rewritten version.
 *
 * @origin  v1.0: https://www.mql5.com/en/code/10118          (ATR and StdDev periods are equal)
 * @origin  v3.2: http://www.damianifx.com.br/indicators1.php (ATR and StdDev periods can be configured separately)
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern int    Fast.Periods     = 7;
extern int    Slow.Periods     = 50;
extern bool   ATR.NoLag        = true;
extern double StdDev.ZeroPoint = 1.1;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <stdlibs.mqh>
#include <structs/xtrade/ExecutionContext.mqh>

#define MODE_ATR_RATIO        0
#define MODE_STDDEV_RATIO     1

#property indicator_separate_window
#property indicator_buffers   2                                   // configurable buffers (input dialog)
int       allocated_buffers = 2;                                  // used buffers

#property indicator_color1    LimeGreen
#property indicator_width1    2
#property indicator_color2    Tomato
#property indicator_width2    2

// buffers
double bufferAtrRatio   [];                                       // ATR ratio
double bufferStdDevRatio[];                                       // mirrored StdDev ratio

double atr.noLag.K = 0.5;
string ind.shortName;


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   if (InitReason() == IR_RECOMPILE) {
      if (!RestoreInputParameters()) return(last_error);
   }

   // buffer management
   SetIndexBuffer(MODE_ATR_RATIO,    bufferAtrRatio   );
   SetIndexBuffer(MODE_STDDEV_RATIO, bufferStdDevRatio);

   // data display configuration, names and labels
   string sNoLag = ifString(ATR.NoLag, ", NoLag", "");
   ind.shortName = "Damiani Volameter 1.0:  ATR("+ Fast.Periods +"/"+ Slow.Periods + sNoLag +")  StdDev("+ Fast.Periods +"/"+ Slow.Periods +")  ";
   IndicatorShortName(ind.shortName);                             // subwindow and context menu
   SetIndexLabel(MODE_ATR_RATIO,    "Damiani ATR ratio");         // "Data" window and tooltips
   SetIndexLabel(MODE_STDDEV_RATIO, "Damiani StdDev ratio");
   IndicatorDigits(4);

   // drawing options and styles
   SetIndicatorOptions();
   return(catch("onInit(1)"));
}


/**
 * Deinitialization
 *
 * @return int - error status
 */
int onDeinit() {
   DeleteRegisteredObjects(NULL);
   return(last_error);
}


/**
 * Called before recompilation.
 *
 * @return int - error status
 */
int onDeinitRecompile() {
   StoreInputParameters();
   return(last_error);
}


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   // check for finished buffer initialization (needed on terminal start)
   if (!ArraySize(bufferAtrRatio))
      return(log("onTick(1)  size(bufferAtrRatio) = 0", SetLastError(ERS_TERMINAL_NOT_YET_READY)));

   // reset all buffers and delete garbage before doing a full recalculation
   if (!ValidBars) {
      ArrayInitialize(bufferAtrRatio,    EMPTY_VALUE);
      ArrayInitialize(bufferStdDevRatio, EMPTY_VALUE);
      SetIndicatorOptions();
   }

   // synchronize buffers with a shifted offline chart
   if (ShiftedBars > 0) {
      ShiftIndicatorBuffer(bufferAtrRatio,    Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(bufferStdDevRatio, Bars, ShiftedBars, EMPTY_VALUE);
   }


   // (1) calculate start bar
   int maxBar   = Bars - (Slow.Periods+3);                           // +3 is required only if ATR.NoLag=TRUE
   int startBar = Min(ChangedBars-1, maxBar);
   if (startBar < 0) return(catch("onTick(2)", ERR_HISTORY_INSUFFICIENT));


   // (2) recalculate invalid indicator values
   double fastAtr, slowAtr, atrRatio, fastStdDev, slowStdDev, stdDevRatio;

   for (int bar=startBar; bar >= 0; bar--) {
      fastAtr  = iATR(NULL, NULL, Fast.Periods, bar);
      slowAtr  = iATR(NULL, NULL, Slow.Periods, bar);
      if (!slowAtr) {
         warn("onTick(3)  slowAtr=0");
         slowAtr = 0.1*Pip;
      }
      atrRatio = fastAtr/slowAtr;
      if (ATR.NoLag)
         atrRatio += atr.noLag.K * (bufferAtrRatio[bar+1] - bufferAtrRatio[bar+3]);
      bufferAtrRatio[bar] = atrRatio;

      fastStdDev  = iStdDev(NULL, NULL, Fast.Periods, 0, MODE_LWMA, PRICE_TYPICAL, bar);
      slowStdDev  = iStdDev(NULL, NULL, Slow.Periods, 0, MODE_LWMA, PRICE_TYPICAL, bar);
      if (!slowStdDev) {
         warn("onTick(4)  slowStdDev=0");
         slowStdDev = 0.1*Pip;
      }
      stdDevRatio = fastStdDev/slowStdDev;

      bufferStdDevRatio[bar] = StdDev.ZeroPoint - stdDevRatio;
   }
   return(last_error);
}


/**
 * Workaround for various terminal bugs when setting indicator options. Usually options are set in init(). However after
 * recompilation options must be set in start() to not get ignored.
 */
void SetIndicatorOptions() {
   IndicatorBuffers(allocated_buffers);
   SetIndexStyle(MODE_ATR_RATIO,    ifInt(indicator_color1==CLR_NONE, DRAW_NONE, DRAW_LINE), EMPTY, EMPTY);
   SetIndexStyle(MODE_STDDEV_RATIO, ifInt(indicator_color2==CLR_NONE, DRAW_NONE, DRAW_LINE), EMPTY, EMPTY);
   SetIndicatorLevels();
}


/**
 * Setup indicator levels and level styles.
 *
 * @return bool - success status
 */
bool SetIndicatorLevels() {
   if (__WHEREAMI__==RF_INIT || IsSuperContext())                 // WindowFind() can't be used in init() or iCustom()
      return(true);

   string uniqueName = __NAME__ +"|"+ ec_ProgramIndex(__ExecutionContext);
   IndicatorShortName(uniqueName);
   int self = WindowFind(uniqueName);
   if (self == -1) return(!catch("SetIndicatorLevels(1)  can't find chart subwindow for uniqueName "+ DoubleQuoteStr(uniqueName), ERR_RUNTIME_ERROR));
   IndicatorShortName(ind.shortName);

   //string label      = uniqueName +".level.ATR.center";
   //color  levelColor = indicator_color1;
   //if (ObjectFind(label) != -1)
   //  ObjectDelete(label);
   //ObjectCreate(  label, OBJ_HLINE, self, 0, 0);
   //ObjectSet(     label, OBJPROP_STYLE,  STYLE_DOT );
   //ObjectSet(     label, OBJPROP_COLOR,  levelColor);
   //ObjectSet(     label, OBJPROP_BACK,   false     );
   //ObjectSet(     label, OBJPROP_PRICE1, 1         );
   //ObjectRegister(label);

   //label      = uniqueName +".level.ATR.ZeroPoint";
   //levelColor = ColorAdjust(indicator_color1, NULL, -50, +50);    // lighten up the color
   //if (ObjectFind(label) != -1)
   //  ObjectDelete(label);
   //ObjectCreate(  label, OBJ_HLINE, self, 0, 0);
   //ObjectSet(     label, OBJPROP_STYLE,  STYLE_SOLID);
   //ObjectSet(     label, OBJPROP_COLOR,  levelColor );
   //ObjectSet(     label, OBJPROP_BACK,   true       );
   //ObjectSet(     label, OBJPROP_PRICE1, 0          );
   //ObjectRegister(label);

   //label      = uniqueName +".level.StdDev.center";
   //levelColor = indicator_color2;
   //if (ObjectFind(label) != -1)
   //  ObjectDelete(label);
   //ObjectCreate(  label, OBJ_HLINE, self, 0, 0);
   //ObjectSet(     label, OBJPROP_STYLE,  STYLE_DOT         );
   //ObjectSet(     label, OBJPROP_COLOR,  levelColor        );
   //ObjectSet(     label, OBJPROP_BACK,   false             );
   //ObjectSet(     label, OBJPROP_PRICE1, StdDev.ZeroPoint-1);
   //ObjectRegister(label);

   //label      = uniqueName +".level.StdDev.ZeroPoint";
   //levelColor = ColorAdjust(indicator_color2, NULL, -30, +30);    // lighten up the color
   //if (ObjectFind(label) != -1)
   //  ObjectDelete(label);
   //ObjectCreate(  label, OBJ_HLINE, self, 0, 0);
   //ObjectSet(     label, OBJPROP_STYLE,  STYLE_SOLID     );
   //ObjectSet(     label, OBJPROP_COLOR,  levelColor      );
   //ObjectSet(     label, OBJPROP_BACK,   true            );
   //ObjectSet(     label, OBJPROP_PRICE1, StdDev.ZeroPoint);
   //ObjectRegister(label);

   return(!catch("SetIndicatorLevels(2)"));
}


/**
 * Store input parameters in the chart before recompilation.
 *
 * @return bool - success status
 */
bool StoreInputParameters() {
   Chart.StoreInt   (__NAME__ +".input.Fast.Periods",     Fast.Periods    );
   Chart.StoreInt   (__NAME__ +".input.Slow.Periods",     Slow.Periods    );
   Chart.StoreBool  (__NAME__ +".input.ATR.NoLag",        ATR.NoLag       );
   Chart.StoreDouble(__NAME__ +".input.StdDev.ZeroPoint", StdDev.ZeroPoint);
   return(!catch("StoreInputParameters(1)"));
}


/**
 * Restore input parameters found in the chart after recompilation.
 *
 * @return bool - success status
 */
bool RestoreInputParameters() {
   Chart.RestoreInt   ("Fast.Periods",     Fast.Periods    );
   Chart.RestoreInt   ("Slow.Periods",     Slow.Periods    );
   Chart.RestoreBool  ("ATR.NoLag",        ATR.NoLag       );
   Chart.RestoreDouble("StdDev.ZeroPoint", StdDev.ZeroPoint);
   return(!catch("RestoreInputParameters(1)"));
}


/**
 * Return a string representation of the input parameters. Used to log iCustom() calls.
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("input: ",

                            "Fast.Periods=",     Fast.Periods,                 "; ",
                            "Slow.Periods=",     Slow.Periods,                 "; ",
                            "ATR.NoLag=",        BoolToStr(ATR.NoLag),         "; ",
                            "StdDev.ZeroPoint=", NumberToStr(StdDev.ZeroPoint, ".1+"), "; ")
   );
}
