/**
 * Damiani Volameter v3.2
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern int    ATR.Fast.Periods    = 13;
extern int    ATR.Slow.Periods    = 40;
extern bool   ATR.NoLag           = true;
extern int    StdDev.Fast.Periods = 20;
extern int    StdDev.Slow.Periods = 100;
extern double StdDev.ZeroPoint    = 1.4;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <stdlibs.mqh>

#define MODE_ATR_RATIO        0
#define MODE_STDDEV_MIRROR    1

#property indicator_separate_window
#property indicator_buffers   2                                   // configurable buffers (input dialog)
int       allocated_buffers = 2;                                  // used buffers

#property indicator_color1    LimeGreen
#property indicator_width1    2
#property indicator_color2    Tomato
#property indicator_width2    2

// buffers
double bufferAtrRatio    [];                                      // ATR ratio
double bufferStdDevMirror[];                                      // mirrored StdDev ratio

double atr.noLag.K = 0.5;


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
   SetIndexBuffer(MODE_ATR_RATIO,     bufferAtrRatio    );
   SetIndexBuffer(MODE_STDDEV_MIRROR, bufferStdDevMirror);

   // data display configuration, names and labels
   string sNoLag    = ifString(ATR.NoLag, ", NoLag", "");
   string shortName = "Damiani Volameter 3.2:  ATR("+ ATR.Fast.Periods +"/"+ ATR.Slow.Periods + sNoLag +")  Z-StdDev("+ StdDev.Fast.Periods +"/"+ StdDev.Slow.Periods +")  ";
   IndicatorShortName(shortName);                                 // subwindow and context menu
   SetIndexLabel(MODE_ATR_RATIO,     "Damiani ATR ratio");        // "Data" window and tooltips
   SetIndexLabel(MODE_STDDEV_MIRROR, "Damiani Z-StdDev ratio");
   IndicatorDigits(4);

   // drawing options and styles
   SetIndicatorOptions();
   return(catch("onInit(1)"));
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
      ArrayInitialize(bufferAtrRatio,     EMPTY_VALUE);
      ArrayInitialize(bufferStdDevMirror, EMPTY_VALUE);
      SetIndicatorOptions();
   }

   // synchronize buffers with a shifted offline chart
   if (ShiftedBars > 0) {
      ShiftIndicatorBuffer(bufferAtrRatio,     Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(bufferStdDevMirror, Bars, ShiftedBars, EMPTY_VALUE);
   }


   // (1) calculate start bar
   int maxPeriods = MathMax(ATR.Slow.Periods, StdDev.Slow.Periods);
   int maxBar     = Bars - (maxPeriods+3);                           // +3 is required only if ATR.NoLag=TRUE
   int startBar   = Min(ChangedBars-1, maxBar);
   if (startBar < 0) return(catch("onTick(2)", ERR_HISTORY_INSUFFICIENT));


   // (2) recalculate invalid indicator values
   double fastAtr, slowAtr, atrRatio, fastStdDev, slowStdDev, stdDevRatio;

   for (int bar=startBar; bar >= 0; bar--) {
      fastAtr  = iATR(NULL, NULL, ATR.Fast.Periods, bar);
      slowAtr  = iATR(NULL, NULL, ATR.Slow.Periods, bar);
      atrRatio = fastAtr/slowAtr;
      if (ATR.NoLag)
         atrRatio += atr.noLag.K * (bufferAtrRatio[bar+1] - bufferAtrRatio[bar+3]);
      bufferAtrRatio[bar] = atrRatio;

      fastStdDev  = iStdDev(NULL, NULL, StdDev.Fast.Periods, 0, MODE_LWMA, PRICE_TYPICAL, bar);
      slowStdDev  = iStdDev(NULL, NULL, StdDev.Slow.Periods, 0, MODE_LWMA, PRICE_TYPICAL, bar);
      stdDevRatio = fastStdDev/slowStdDev;

      bufferStdDevMirror[bar] = StdDev.ZeroPoint - stdDevRatio;
   }
   return(last_error);
}


/**
 * Workaround for various terminal bugs when setting indicator options. Usually options are set in init(). However after
 * recompilation options must be set in start() to not get ignored.
 */
void SetIndicatorOptions() {
   IndicatorBuffers(allocated_buffers);

   SetIndexStyle(MODE_ATR_RATIO,     ifInt(indicator_color1==CLR_NONE, DRAW_NONE, DRAW_LINE), EMPTY, EMPTY);
   SetIndexStyle(MODE_STDDEV_MIRROR, ifInt(indicator_color2==CLR_NONE, DRAW_NONE, DRAW_LINE), EMPTY, EMPTY);
}


/**
 * Store input parameters in the chart before recompilation.
 *
 * @return bool - success status
 */
bool StoreInputParameters() {
   Chart.StoreInt   (__NAME__ +".input.ATR.Fast.Periods",    ATR.Fast.Periods   );
   Chart.StoreInt   (__NAME__ +".input.ATR.Slow.Periods",    ATR.Slow.Periods   );
   Chart.StoreBool  (__NAME__ +".input.ATR.NoLag",           ATR.NoLag          );
   Chart.StoreInt   (__NAME__ +".input.StdDev.Fast.Periods", StdDev.Fast.Periods);
   Chart.StoreInt   (__NAME__ +".input.StdDev.Slow.Periods", StdDev.Slow.Periods);
   Chart.StoreDouble(__NAME__ +".input.StdDev.ZeroPoint",    StdDev.ZeroPoint   );
   return(!catch("StoreInputParameters(1)"));
}


/**
 * Restore input parameters found in the chart after recompilation.
 *
 * @return bool - success status
 */
bool RestoreInputParameters() {
   Chart.RestoreInt   ("ATR.Fast.Periods",    ATR.Fast.Periods   );
   Chart.RestoreInt   ("ATR.Slow.Periods",    ATR.Slow.Periods   );
   Chart.RestoreBool  ("ATR.NoLag",           ATR.NoLag          );
   Chart.RestoreInt   ("StdDev.Fast.Periods", StdDev.Fast.Periods);
   Chart.RestoreInt   ("StdDev.Slow.Periods", StdDev.Slow.Periods);
   Chart.RestoreDouble("StdDev.ZeroPoint",    StdDev.ZeroPoint   );
   return(!catch("RestoreInputParameters(1)"));
}


/**
 * Return a string representation of the input parameters. Used to log iCustom() calls.
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("input: ",

                            "ATR.Fast.Periods=",    ATR.Fast.Periods,                     "; ",
                            "ATR.Slow.Periods=",    ATR.Slow.Periods,                     "; ",
                            "ATR.NoLag=",           BoolToStr(ATR.NoLag),                 "; ",
                            "StdDev.Fast.Periods=", StdDev.Fast.Periods,                  "; ",
                            "StdDev.Slow.Periods=", StdDev.Slow.Periods,                  "; ",
                            "StdDev.ZeroPoint=",    NumberToStr(StdDev.ZeroPoint, ".1+"), "; ")
   );
}
