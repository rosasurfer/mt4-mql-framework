/**
 * Damiani Volameter WIP version
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern int    Fast.Periods    = 7;
extern int    Slow.Periods    = 50;
extern double Threshold.Level = 1.1;
extern bool   NonLag          = true;
extern double NonLag.K        = 0.5;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <stdlibs.mqh>

#define MODE_ATR_RATIO        0
#define MODE_ATR_LOG_RATIO    1
#define MODE_STDDEV_RATIO     2

#property indicator_separate_window
#property indicator_buffers   3                                // configurable buffers (input dialog)
int       allocated_buffers = 3;                               // used buffers

#property indicator_color1       LimeGreen
#property indicator_width1       2
#property indicator_color2       Blue
#property indicator_width2       1
#property indicator_color3       CLR_NONE //Tomato
#property indicator_width3       2

#property indicator_level1       0
//#property indicator_level2     0.5
#property indicator_level3       1
//#property indicator_level4     2
#property indicator_levelstyle   STYLE_DOT
#property indicator_levelcolor   Red

// buffers
double bufferAtrRatio   [];
double bufferAtrRatioLog[];
double bufferStdDevRatio[];


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
   SetIndexBuffer(MODE_ATR_RATIO,     bufferAtrRatio   );
   SetIndexBuffer(MODE_ATR_LOG_RATIO, bufferAtrRatioLog);
   SetIndexBuffer(MODE_STDDEV_RATIO,  bufferStdDevRatio);

   // data display configuration, names and labels
   string shortName = "Damiani Volameter WIP   NonLag="+ BoolToStr(NonLag) +"   ";
   IndicatorShortName(shortName);                              // subwindow and context menu
   SetIndexLabel(MODE_ATR_RATIO,     "Dam. ATR ratio");        // "Data" window and tooltips
   SetIndexLabel(MODE_ATR_LOG_RATIO, "Dam. ATR log ratio");    // "Data" window and tooltips
   SetIndexLabel(MODE_STDDEV_RATIO,  "Dam. StdDev ratio");
   IndicatorDigits(4);

   //SetLevelValue(0, 1);
   //SetLevelValue(1, Threshold.Level);

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
      ArrayInitialize(bufferAtrRatio,    EMPTY_VALUE);
      ArrayInitialize(bufferAtrRatioLog, EMPTY_VALUE);
      ArrayInitialize(bufferStdDevRatio, EMPTY_VALUE);
      SetIndicatorOptions();
   }

   // synchronize buffers with a shifted offline chart
   if (ShiftedBars > 0) {
      ShiftIndicatorBuffer(bufferAtrRatio,    Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(bufferAtrRatioLog, Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(bufferStdDevRatio, Bars, ShiftedBars, EMPTY_VALUE);
   }


   int changed_bars = IndicatorCounted();
   int limit = Bars - changed_bars;
   if (limit > Slow.Periods+5)
      limit -= Slow.Periods;

   double fastAtr,        minFastAtr       =INT_MAX, maxFastAtr       =INT_MIN;
   double slowAtr,        minSlowAtr       =INT_MAX, maxSlowAtr       =INT_MIN;
   double atrRatio,       minAtrRatio      =INT_MAX, maxAtrRatio      =INT_MIN;
   double atrNonLagRatio, minAtrNonLagRatio=INT_MAX, maxAtrNonLagRatio=INT_MIN;
   double atrLogRatio,    minAtrLogRatio   =INT_MAX, maxAtrLogRatio   =INT_MIN;
   double fastStdDev;
   double slowStdDev;
   double stdDevRatio;

   for (int bar=limit; bar >= 0; bar--) {
      fastAtr  = iATR(NULL, NULL, Fast.Periods, bar); minFastAtr = MathMin(fastAtr, minFastAtr); maxFastAtr = MathMax(fastAtr, maxFastAtr);
      slowAtr  = iATR(NULL, NULL, Slow.Periods, bar); minSlowAtr = MathMin(slowAtr, minSlowAtr); maxSlowAtr = MathMax(slowAtr, maxSlowAtr);
      if (slowAtr == 0) {
         warn("onTick(1)  slowAtr=0");
         slowAtr = 0.1*Pip;
      }

      atrRatio       = fastAtr/slowAtr;               minAtrRatio = MathMin(atrRatio, minAtrRatio); maxAtrRatio = MathMax(atrRatio, maxAtrRatio);
      atrNonLagRatio = atrRatio + NonLag.K * (bufferAtrRatio[bar+1] - bufferAtrRatio[bar+3]);
      if (NonLag) bufferAtrRatio[bar] = atrNonLagRatio;
      else        bufferAtrRatio[bar] = atrRatio;

      // Log(atrRatio)(base=2)
      atrLogRatio = MathLog(atrRatio)/MathLog(5); minAtrLogRatio = MathMin(atrLogRatio, minAtrLogRatio); maxAtrLogRatio = MathMax(atrLogRatio, maxAtrLogRatio);
      bufferAtrRatioLog[bar] = atrLogRatio;

      fastStdDev  = iStdDev(NULL, NULL, Fast.Periods, 0, MODE_LWMA, PRICE_TYPICAL, bar);
      slowStdDev  = iStdDev(NULL, NULL, Slow.Periods, 0, MODE_LWMA, PRICE_TYPICAL, bar);
      if (slowStdDev == 0) {
         warn("onTick(2)  slowStdDev=0");
         slowStdDev = 0.1*Pip;
      }
      stdDevRatio = fastStdDev/slowStdDev;

      bufferStdDevRatio[bar] = Threshold.Level - stdDevRatio;
   }

   if (!ValidBars) {
      debug("onTick(0.1)  minSlowAtr=    "+ DoubleToStr(minSlowAtr/Pips, 2) +"    maxSlowAtr=    "+ DoubleToStr(maxSlowAtr/Pips, 2));
      debug("onTick(0.2)  minFastAtr=    "+ DoubleToStr(minFastAtr/Pips, 2) +"    maxFastAtr=    "+ DoubleToStr(maxFastAtr/Pips, 2));
      debug("onTick(0.3)  minAtrRatio=   "+ DoubleToStr(minAtrRatio, 4)       +"  maxAtrRatio=   "+ DoubleToStr(maxAtrRatio, 4));
      debug("onTick(0.4)  minAtrLogRatio="+ DoubleToStr(minAtrLogRatio, 4)    +"  maxAtrLogRatio="+ DoubleToStr(maxAtrLogRatio, 4));
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
   SetIndexStyle(MODE_ATR_LOG_RATIO, ifInt(indicator_color2==CLR_NONE, DRAW_NONE, DRAW_LINE), EMPTY, EMPTY);
   SetIndexStyle(MODE_STDDEV_RATIO,  ifInt(indicator_color3==CLR_NONE, DRAW_NONE, DRAW_LINE), EMPTY, EMPTY);
}


/**
 * Store input parameters in the chart before recompilation.
 *
 * @return bool - success status
 */
bool StoreInputParameters() {
   Chart.StoreInt   (__NAME__ +".input.Fast.Periods",    Fast.Periods   );
   Chart.StoreInt   (__NAME__ +".input.Slow.Periods",    Slow.Periods   );
   Chart.StoreDouble(__NAME__ +".input.Threshold.Level", Threshold.Level);
   Chart.StoreBool  (__NAME__ +".input.NonLag",          NonLag         );
   Chart.StoreDouble(__NAME__ +".input.NonLag.K",        NonLag.K       );
   return(!catch("StoreInputParameters(1)"));
}


/**
 * Restore input parameters found in the chart after recompilation.
 *
 * @return bool - success status
 */
bool RestoreInputParameters() {
   Chart.RestoreInt   ("Fast.Periods",    Fast.Periods   );
   Chart.RestoreInt   ("Slow.Periods",    Slow.Periods   );
   Chart.RestoreDouble("Threshold.Level", Threshold.Level);
   Chart.RestoreBool  ("NonLag",          NonLag         );
   Chart.RestoreDouble("NonLag.K",        NonLag.K       );
   return(!catch("RestoreInputParameters(1)"));
}


/**
 * Return a string representation of the input parameters. Used to log iCustom() calls.
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("input: ",

                            "Fast.Periods=",    Fast.Periods,                        "; ",
                            "Slow.Periods=",    Slow.Periods,                        "; ",
                            "Threshold.Level=", NumberToStr(Threshold.Level, ".1+"), "; ",
                            "NonLag=",          BoolToStr(NonLag),                   "; ",
                            "NonLag.K=",        NumberToStr(NonLag.K, ".1+"),        "; ")
   );
}
