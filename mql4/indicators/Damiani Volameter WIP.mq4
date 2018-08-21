/**
 * Damiani Volameter WIP
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
extern bool   ATR.NoLag        = false;
extern double ATR.NoLag.K      = 0.5;
extern double StdDev.ZeroPoint = 1.1;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <stdlibs.mqh>
#include <structs/xtrade/ExecutionContext.mqh>

#define MODE_ATR_RATIO        0
#define MODE_ATR_LOGRATIO     1
#define MODE_STDDEV_RATIO     2

#property indicator_separate_window
#property indicator_buffers   3                                // configurable buffers (input dialog)
int       allocated_buffers = 3;                               // used buffers

#property indicator_color1    LimeGreen
#property indicator_width1    2
#property indicator_color2    Blue
#property indicator_width2    1
#property indicator_color3    Tomato
#property indicator_width3    2

#property indicator_level1    INT_MIN
#property indicator_level2    INT_MIN
#property indicator_level3    INT_MIN
#property indicator_level4    INT_MIN
#property indicator_level5    INT_MIN

// buffers
double bufferAtrRatio   [];
double bufferAtrLogRatio[];
double bufferStdDevRatio[];

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
   SetIndexBuffer(MODE_ATR_LOGRATIO, bufferAtrLogRatio);
   SetIndexBuffer(MODE_STDDEV_RATIO, bufferStdDevRatio);

   // data display configuration, names and labels
   string sNoLag = ifString(ATR.NoLag, ", NoLag", "");
   ind.shortName = "Damiani Volameter WIP:  ATR("+ Fast.Periods +"/"+ Slow.Periods + sNoLag +")  StdDev("+ Fast.Periods +"/"+ Slow.Periods +")  ";
   IndicatorShortName(ind.shortName);                             // subwindow and context menu
   SetIndexLabel(MODE_ATR_RATIO,    "Damiani ATR ratio");         // "Data" window and tooltips
   SetIndexLabel(MODE_ATR_LOGRATIO, "Damiani ATR log ratio");     // "Data" window and tooltips
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
      ArrayInitialize(bufferAtrLogRatio, EMPTY_VALUE);
      ArrayInitialize(bufferStdDevRatio, EMPTY_VALUE);
      SetIndicatorOptions();
   }

   // synchronize buffers with a shifted offline chart
   if (ShiftedBars > 0) {
      ShiftIndicatorBuffer(bufferAtrRatio,    Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(bufferAtrLogRatio, Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(bufferStdDevRatio, Bars, ShiftedBars, EMPTY_VALUE);
   }


   // (1) calculate start bar
   int maxBar   = Bars - (Slow.Periods+3);                           // +3 is required only if ATR.NoLag=TRUE
   int startBar = Min(ChangedBars-1, maxBar);
   if (startBar < 0) return(catch("onTick(2)", ERR_HISTORY_INSUFFICIENT));


   // (2) recalculate invalid indicator values
   double fastAtr,        minFastAtr       =INT_MAX, maxFastAtr       =INT_MIN;
   double slowAtr,        minSlowAtr       =INT_MAX, maxSlowAtr       =INT_MIN;
   double atrRatio,       minAtrRatio      =INT_MAX, maxAtrRatio      =INT_MIN;
   double atrNoLagRatio,  minAtrNoLagRatio =INT_MAX, maxAtrNoLagRatio =INT_MIN;
   double atrLogRatio,    minAtrLogRatio   =INT_MAX, maxAtrLogRatio   =INT_MIN;
   double fastStdDev,     minFastStdDev    =INT_MAX, maxFastStdDev    =INT_MIN;
   double slowStdDev,     minSlowStdDev    =INT_MAX, maxSlowStdDev    =INT_MIN;
   double stdDevRatio,    minStdDevRatio   =INT_MAX, maxStdDevRatio   =INT_MIN;
   double stdDevLogRatio, minStdDevLogRatio=INT_MAX, maxStdDevLogRatio=INT_MIN;

   for (int bar=startBar; bar >= 0; bar--) {
      // ATR
      fastAtr = iATR(NULL, NULL, Fast.Periods, bar); minFastAtr = MathMin(fastAtr, minFastAtr); maxFastAtr = MathMax(fastAtr, maxFastAtr);
      slowAtr = iATR(NULL, NULL, Slow.Periods, bar); minSlowAtr = MathMin(slowAtr, minSlowAtr); maxSlowAtr = MathMax(slowAtr, maxSlowAtr);
      if (!slowAtr) {
         warn("onTick(1)  slowAtr=0");
         slowAtr = 0.1*Pip;
      }

      // ATR ratio
      atrRatio      = fastAtr/slowAtr;            minAtrRatio = MathMin(atrRatio, minAtrRatio); maxAtrRatio = MathMax(atrRatio, maxAtrRatio);
      atrNoLagRatio = atrRatio + ATR.NoLag.K * (bufferAtrRatio[bar+1] - bufferAtrRatio[bar+3]);
      if (ATR.NoLag) bufferAtrRatio[bar] = atrNoLagRatio;
      else           bufferAtrRatio[bar] = atrRatio;

      // ATR log ratio
      atrLogRatio = MathLog(atrRatio)/MathLog(2); minAtrLogRatio = MathMin(atrLogRatio, minAtrLogRatio); maxAtrLogRatio = MathMax(atrLogRatio, maxAtrLogRatio);
      bufferAtrLogRatio[bar] = atrLogRatio;

      // StdDev
      fastStdDev = iStdDev(NULL, NULL, Fast.Periods, 0, MODE_LWMA, PRICE_TYPICAL, bar); minFastStdDev = MathMin(fastStdDev, minFastStdDev); maxFastStdDev = MathMax(fastStdDev, maxFastStdDev);
      slowStdDev = iStdDev(NULL, NULL, Slow.Periods, 0, MODE_LWMA, PRICE_TYPICAL, bar); minSlowStdDev = MathMin(slowStdDev, minSlowStdDev); maxSlowStdDev = MathMax(slowStdDev, maxSlowStdDev);
      if (!slowStdDev) {
         warn("onTick(2)  slowStdDev=0");
         slowStdDev = 0.1*Pip;
      }

      // StdDev ratio
      stdDevRatio = fastStdDev/slowStdDev; minStdDevRatio = MathMin(stdDevRatio, minStdDevRatio); maxStdDevRatio = MathMax(stdDevRatio, maxStdDevRatio);
      bufferStdDevRatio[bar] = StdDev.ZeroPoint - stdDevRatio;

      // StdDev log ratio
      stdDevLogRatio = MathLog(stdDevRatio)/MathLog(2); minStdDevLogRatio = MathMin(stdDevLogRatio, minStdDevLogRatio); maxStdDevLogRatio = MathMax(stdDevLogRatio, maxStdDevLogRatio);
   }

   if (!ValidBars) {
      debug("onTick(0.1)  ATR    fast="+ DoubleToStr(minFastAtr/Pips, 2) +".."+ DoubleToStr(maxFastAtr/Pips, 2)      +"   slow="+ DoubleToStr(minSlowAtr/Pips, 2) +".."+ DoubleToStr(maxSlowAtr/Pips, 2));
      debug("onTick(0.2)  ATR    f/s="+ DoubleToStr(minAtrRatio, 4) +".."+ DoubleToStr(maxAtrRatio, 4)                +"  log(f/s)="+ DoubleToStr(minAtrLogRatio, 4) +".."+ DoubleToStr(maxAtrLogRatio, 4));

      debug("onTick(0.3)  StdDev fast="+ DoubleToStr(minFastStdDev/Pips, 2) +".."+ DoubleToStr(maxFastStdDev/Pips, 2) +"   slow="+ DoubleToStr(minSlowStdDev/Pips, 2) +".."+ DoubleToStr(maxSlowStdDev/Pips, 2));
      debug("onTick(0.4)  StdDev f/s="+ DoubleToStr(minStdDevRatio, 4) +".."+ DoubleToStr(maxStdDevRatio, 4)           +"  log(f/s)="+ DoubleToStr(minStdDevLogRatio, 4) +".."+ DoubleToStr(maxStdDevLogRatio, 4));
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
   SetIndexStyle(MODE_ATR_LOGRATIO, ifInt(indicator_color2==CLR_NONE, DRAW_NONE, DRAW_LINE), EMPTY, EMPTY);
   SetIndexStyle(MODE_STDDEV_RATIO, ifInt(indicator_color3==CLR_NONE, DRAW_NONE, DRAW_LINE), EMPTY, EMPTY);
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

   //SetLevelStyle(EMPTY, EMPTY, Red);
   //SetLevelValue(0, 0);
   //SetLevelValue(1, 0.5);
   //SetLevelValue(2, 1);
   //SetLevelValue(3, 2);
   //SetLevelValue(4, StdDev.ZeroPoint);

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
   Chart.StoreDouble(__NAME__ +".input.ATR.NoLag.K",      ATR.NoLag.K     );
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
   Chart.RestoreDouble("ATR.NoLag.K",      ATR.NoLag.K     );
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

                            "Fast.Periods=",     Fast.Periods,                         "; ",
                            "Slow.Periods=",     Slow.Periods,                         "; ",
                            "ATR.NoLag=",        BoolToStr(ATR.NoLag),                 "; ",
                            "ATR.NoLag.K=",      NumberToStr(ATR.NoLag.K, ".1+"),      "; ",
                            "StdDev.ZeroPoint=", NumberToStr(StdDev.ZeroPoint, ".1+"), "; ")
   );
}
