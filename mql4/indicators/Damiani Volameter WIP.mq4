/**
 * Damiani Volameter WIP version
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

#define MODE_ATR_RATIO        0
#define MODE_ATR_LOGRATIO     1
#define MODE_STDDEV_MIRROR    2

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
double bufferAtrRatio    [];
double bufferAtrLogRatio [];
double bufferStdDevMirror[];


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
   SetIndexBuffer(MODE_ATR_LOGRATIO,  bufferAtrLogRatio );
   SetIndexBuffer(MODE_STDDEV_MIRROR, bufferStdDevMirror);

   // data display configuration, names and labels
   string sNoLag    = ifString(ATR.NoLag, ", NoLag", "");
   string shortName = "Damiani Volameter WIP:  ATR("+ Fast.Periods +"/"+ Slow.Periods + sNoLag +")  Z-StdDev("+ Fast.Periods +"/"+ Slow.Periods +")  ";
   IndicatorShortName(shortName);                              // subwindow and context menu
   SetIndexLabel(MODE_ATR_RATIO,     "Dam. ATR ratio");        // "Data" window and tooltips
   SetIndexLabel(MODE_ATR_LOGRATIO,  "Dam. ATR log ratio");    // "Data" window and tooltips
   SetIndexLabel(MODE_STDDEV_MIRROR, "Dam. Z-StdDev ratio");
   IndicatorDigits(4);

   // drawing options and styles
   SetIndicatorOptions();
   SetLevelValue(0, 0);
   SetLevelValue(1, 0.5);
   SetLevelValue(2, 1);
   SetLevelValue(3, 2);
   SetLevelValue(4, StdDev.ZeroPoint);

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
      ArrayInitialize(bufferAtrLogRatio,  EMPTY_VALUE);
      ArrayInitialize(bufferStdDevMirror, EMPTY_VALUE);
      SetIndicatorOptions();
   }

   // synchronize buffers with a shifted offline chart
   if (ShiftedBars > 0) {
      ShiftIndicatorBuffer(bufferAtrRatio,     Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(bufferAtrLogRatio,  Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(bufferStdDevMirror, Bars, ShiftedBars, EMPTY_VALUE);
   }


   int changed_bars = IndicatorCounted();
   int limit = Bars - changed_bars;
   if (limit > Slow.Periods+5)
      limit -= Slow.Periods;

   double fastAtr,        minFastAtr       =INT_MAX, maxFastAtr       =INT_MIN;
   double slowAtr,        minSlowAtr       =INT_MAX, maxSlowAtr       =INT_MIN;
   double atrRatio,       minAtrRatio      =INT_MAX, maxAtrRatio      =INT_MIN;
   double atrNoLagRatio,  minAtrNoLagRatio =INT_MAX, maxAtrNoLagRatio =INT_MIN;
   double atrLogRatio,    minAtrLogRatio   =INT_MAX, maxAtrLogRatio   =INT_MIN;
   double fastStdDev,     minFastStdDev    =INT_MAX, maxFastStdDev    =INT_MIN;
   double slowStdDev,     minSlowStdDev    =INT_MAX, maxSlowStdDev    =INT_MIN;
   double stdDevRatio,    minStdDevRatio   =INT_MAX, maxStdDevRatio   =INT_MIN;
   double stdDevLogRatio, minStdDevLogRatio=INT_MAX, maxStdDevLogRatio=INT_MIN;

   for (int bar=limit; bar >= 0; bar--) {
      fastAtr = iATR(NULL, NULL, Fast.Periods, bar); minFastAtr = MathMin(fastAtr, minFastAtr); maxFastAtr = MathMax(fastAtr, maxFastAtr);
      slowAtr = iATR(NULL, NULL, Slow.Periods, bar); minSlowAtr = MathMin(slowAtr, minSlowAtr); maxSlowAtr = MathMax(slowAtr, maxSlowAtr);
      if (slowAtr == 0) {
         warn("onTick(1)  slowAtr=0");
         slowAtr = 0.1*Pip;
      }

      // ATR ratio
      atrRatio      = fastAtr/slowAtr;            minAtrRatio = MathMin(atrRatio, minAtrRatio); maxAtrRatio = MathMax(atrRatio, maxAtrRatio);
      atrNoLagRatio = atrRatio + ATR.NoLag.K * (bufferAtrRatio[bar+1] - bufferAtrRatio[bar+3]);
      if (ATR.NoLag) bufferAtrRatio[bar] = atrNoLagRatio;
      else           bufferAtrRatio[bar] = atrRatio;

      // Log(base=2)(atrRatio)
      atrLogRatio = MathLog(atrRatio)/MathLog(2); minAtrLogRatio = MathMin(atrLogRatio, minAtrLogRatio); maxAtrLogRatio = MathMax(atrLogRatio, maxAtrLogRatio);
      bufferAtrLogRatio[bar] = atrLogRatio;

      fastStdDev = iStdDev(NULL, NULL, Fast.Periods, 0, MODE_LWMA, PRICE_TYPICAL, bar); minFastStdDev = MathMin(fastStdDev, minFastStdDev); maxFastStdDev = MathMax(fastStdDev, maxFastStdDev);
      slowStdDev = iStdDev(NULL, NULL, Slow.Periods, 0, MODE_LWMA, PRICE_TYPICAL, bar); minSlowStdDev = MathMin(slowStdDev, minSlowStdDev); maxSlowStdDev = MathMax(slowStdDev, maxSlowStdDev);
      if (slowStdDev == 0) {
         warn("onTick(2)  slowStdDev=0");
         slowStdDev = 0.1*Pip;
      }

      // StdDev ratio
      stdDevRatio = fastStdDev/slowStdDev; minStdDevRatio = MathMin(stdDevRatio, minStdDevRatio); maxStdDevRatio = MathMax(stdDevRatio, maxStdDevRatio);

      // Log(base=2)(stdDevRatio)
      stdDevLogRatio = MathLog(stdDevRatio)/MathLog(2); minStdDevLogRatio = MathMin(stdDevLogRatio, minStdDevLogRatio); maxStdDevLogRatio = MathMax(stdDevLogRatio, maxStdDevLogRatio);

      bufferStdDevMirror[bar] = StdDev.ZeroPoint - stdDevRatio;
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

   SetIndexStyle(MODE_ATR_RATIO,     ifInt(indicator_color1==CLR_NONE, DRAW_NONE, DRAW_LINE), EMPTY, EMPTY);
   SetIndexStyle(MODE_ATR_LOGRATIO,  ifInt(indicator_color2==CLR_NONE, DRAW_NONE, DRAW_LINE), EMPTY, EMPTY);
   SetIndexStyle(MODE_STDDEV_MIRROR, ifInt(indicator_color3==CLR_NONE, DRAW_NONE, DRAW_LINE), EMPTY, EMPTY);

   //SetLevelStyle(EMPTY, EMPTY, Red);
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
