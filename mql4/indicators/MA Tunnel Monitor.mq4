/**
 * MA Tunnel Monitor
 *
 * A signal monitor for an "MA Tunnel" setup.
 */
#include <stddefines.mqh>
int   __InitFlags[];
int __DeinitFlags[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern string __1___________________________ = "=== MA 1 =====================================";
extern bool   UseMA1                         = true;
extern int    MA1.Periods                    = 9;
extern string MA1.Method                     = "SMA | LWMA | EMA* | SMMA";
extern string MA1.AppliedPrice               = "Open | High | Low | Close | Median* | Typical | Weighted";

extern string __2___________________________ = "=== MA 2 =====================================";
extern bool   UseMA2                         = true;
extern int    MA2.Periods                    = 36;
extern string MA2.Method                     = "SMA | LWMA | EMA* | SMMA";
extern string MA2.AppliedPrice               = "Open | High | Low | Close | Median* | Typical | Weighted";

extern string __3___________________________ = "=== MA 3 =====================================";
extern bool   UseMA3                         = true;
extern int    MA3.Periods                    = 144;
extern string MA3.Method                     = "SMA | LWMA | EMA* | SMMA";
extern string MA3.AppliedPrice               = "Open | High | Low | Close | Median* | Typical | Weighted";

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <rsfLibs.mqh>
#include <functions/IsBarOpen.mqh>

#define MODE_MA1              0              // indicator buffer ids
#define MODE_MA2              1
#define MODE_MA3              2
#define MODE_MA1_TREND        3
#define MODE_MA2_TREND        4
#define MODE_MA3_TREND        5
#define MODE_TOTAL_TREND      6

#define MODE_LONG             1              // breakout ids
#define MODE_SHORT            2

#property indicator_chart_window
#property indicator_buffers   3              // buffers visible in input dialog
int       terminal_buffers =  7;             // buffers managed by the terminal

#property indicator_color1    Red
#property indicator_color2    Blue
#property indicator_color3    Magenta

double ma1[];
double ma1Trend[];
int    ma1Periods;
int    ma1InitPeriods;
int    ma1Method;
int    ma1AppliedPrice;

double ma2[];
double ma2Trend[];
int    ma2Periods;
int    ma2InitPeriods;
int    ma2Method;
int    ma2AppliedPrice;

double ma3[];
double ma3Trend[];
int    ma3Periods;
int    ma3InitPeriods;
int    ma3Method;
int    ma3AppliedPrice;

int    totalInitPeriods;
double totalTrend[];

bool   signals          = true;
bool   signal.onTick    = true;
bool   signal.onBarOpen = true;


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   // input validation
   if (UseMA1) {
      // MA1.Periods
      if (MA1.Periods < 1)                                         return(catch("onInit(1)  invalid input parameter MA1.Periods: "+ MA1.Periods, ERR_INVALID_INPUT_PARAMETER));
      ma1Periods = MA1.Periods;
      // MA1.Method
      string sValues[], sValue = MA1.Method;
      if (Explode(sValue, "*", sValues, 2) > 1) {
         int size = Explode(sValues[0], "|", sValues, NULL);
         sValue = sValues[size-1];
      }
      ma1Method = StrToMaMethod(sValue, F_ERR_INVALID_PARAMETER);
      if (ma1Method == -1)                                         return(catch("onInit(2)  invalid input parameter MA1.Method: "+ DoubleQuoteStr(MA1.Method), ERR_INVALID_INPUT_PARAMETER));
      MA1.Method = MaMethodDescription(ma1Method);
      // MA1.AppliedPrice
      sValue = MA1.AppliedPrice;
      if (Explode(sValue, "*", sValues, 2) > 1) {
         size = Explode(sValues[0], "|", sValues, NULL);
         sValue = sValues[size-1];
      }
      if (StrTrim(sValue) == "") sValue = "close";                 // default price type
      ma1AppliedPrice = StrToPriceType(sValue, F_PARTIAL_ID|F_ERR_INVALID_PARAMETER);
      if (ma1AppliedPrice==-1 || ma1AppliedPrice > PRICE_WEIGHTED) return(catch("onInit(3)  invalid input parameter MA1.AppliedPrice: "+ DoubleQuoteStr(MA1.AppliedPrice), ERR_INVALID_INPUT_PARAMETER));
      MA1.AppliedPrice = PriceTypeDescription(ma1AppliedPrice);
      // IIR filters (EMA, SMMA) need at least 10 bars for initialization
      ma1InitPeriods = ifInt(ma1Method==MODE_EMA || ma1Method==MODE_SMMA, Max(10, ma1Periods*3), ma1Periods);
   }

   if (UseMA2) {
      // MA2.Periods
      if (MA2.Periods < 1)                                         return(catch("onInit(4)  invalid input parameter MA2.Periods: "+ MA2.Periods, ERR_INVALID_INPUT_PARAMETER));
      ma2Periods = MA2.Periods;
      // MA2.Method
      sValue = MA2.Method;
      if (Explode(sValue, "*", sValues, 2) > 1) {
         size = Explode(sValues[0], "|", sValues, NULL);
         sValue = sValues[size-1];
      }
      ma2Method = StrToMaMethod(sValue, F_ERR_INVALID_PARAMETER);
      if (ma2Method == -1)                                         return(catch("onInit(5)  invalid input parameter MA2.Method: "+ DoubleQuoteStr(MA2.Method), ERR_INVALID_INPUT_PARAMETER));
      MA2.Method = MaMethodDescription(ma2Method);
      // MA2.AppliedPrice
      sValue = MA2.AppliedPrice;
      if (Explode(sValue, "*", sValues, 2) > 1) {
         size = Explode(sValues[0], "|", sValues, NULL);
         sValue = sValues[size-1];
      }
      if (StrTrim(sValue) == "") sValue = "close";                 // default price type
      ma2AppliedPrice = StrToPriceType(sValue, F_PARTIAL_ID|F_ERR_INVALID_PARAMETER);
      if (ma2AppliedPrice==-1 || ma2AppliedPrice > PRICE_WEIGHTED) return(catch("onInit(6)  invalid input parameter MA2.AppliedPrice: "+ DoubleQuoteStr(MA2.AppliedPrice), ERR_INVALID_INPUT_PARAMETER));
      MA2.AppliedPrice = PriceTypeDescription(ma2AppliedPrice);
      // IIR filters (EMA, SMMA) need at least 10 bars for initialization
      ma2InitPeriods = ifInt(ma2Method==MODE_EMA || ma2Method==MODE_SMMA, Max(10, ma2Periods*3), ma2Periods);
   }

   if (UseMA3) {
      // MA3.Periods
      if (MA3.Periods < 1)                                         return(catch("onInit(7)  invalid input parameter MA3.Periods: "+ MA3.Periods, ERR_INVALID_INPUT_PARAMETER));
      ma3Periods = MA3.Periods;
      // MA3.Method
      sValue = MA3.Method;
      if (Explode(sValue, "*", sValues, 2) > 1) {
         size = Explode(sValues[0], "|", sValues, NULL);
         sValue = sValues[size-1];
      }
      ma3Method = StrToMaMethod(sValue, F_ERR_INVALID_PARAMETER);
      if (ma3Method == -1)                                         return(catch("onInit(8)  invalid input parameter MA3.Method: "+ DoubleQuoteStr(MA3.Method), ERR_INVALID_INPUT_PARAMETER));
      MA3.Method = MaMethodDescription(ma3Method);
      // MA3.AppliedPrice
      sValue = MA3.AppliedPrice;
      if (Explode(sValue, "*", sValues, 2) > 1) {
         size = Explode(sValues[0], "|", sValues, NULL);
         sValue = sValues[size-1];
      }
      if (StrTrim(sValue) == "") sValue = "close";                 // default price type
      ma3AppliedPrice = StrToPriceType(sValue, F_PARTIAL_ID|F_ERR_INVALID_PARAMETER);
      if (ma3AppliedPrice==-1 || ma3AppliedPrice > PRICE_WEIGHTED) return(catch("onInit(9)  invalid input parameter MA3.AppliedPrice: "+ DoubleQuoteStr(MA3.AppliedPrice), ERR_INVALID_INPUT_PARAMETER));
      MA3.AppliedPrice = PriceTypeDescription(ma3AppliedPrice);
      // IIR filters (EMA, SMMA) need at least 10 bars for initialization
      ma3InitPeriods = ifInt(ma3Method==MODE_EMA || ma3Method==MODE_SMMA, Max(10, ma3Periods*3), ma3Periods);
   }
   if (!UseMA1 && !UseMA2 && !UseMA3)                              return(catch("onInit(10)  invalid input parameters (at least one MA must be configured)", ERR_INVALID_INPUT_PARAMETER));
   totalInitPeriods = Max(ma1InitPeriods, ma2InitPeriods, ma3InitPeriods);

   // signal configuration

   // buffer management
   SetIndexBuffer(MODE_MA1,         ma1);
   SetIndexBuffer(MODE_MA2,         ma2);
   SetIndexBuffer(MODE_MA3,         ma3);
   SetIndexBuffer(MODE_MA1_TREND,   ma1Trend);   SetIndexEmptyValue(MODE_MA1_TREND,   0);
   SetIndexBuffer(MODE_MA2_TREND,   ma2Trend);   SetIndexEmptyValue(MODE_MA2_TREND,   0);
   SetIndexBuffer(MODE_MA3_TREND,   ma3Trend);   SetIndexEmptyValue(MODE_MA3_TREND,   0);
   SetIndexBuffer(MODE_TOTAL_TREND, totalTrend); SetIndexEmptyValue(MODE_TOTAL_TREND, 0);

   SetIndexLabel(MODE_MA1, NULL);
   SetIndexLabel(MODE_MA2, NULL);
   SetIndexLabel(MODE_MA3, NULL);

   IndicatorDigits(Digits);
   SetIndicatorOptions();

   return(catch("onInit(10)"));
}


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   // on the first tick after terminal start buffers may not yet be initialized (spurious issue)
   if (!ArraySize(ma1)) return(logInfo("onTick(1)  size(ma1) = 0", SetLastError(ERS_TERMINAL_NOT_YET_READY)));

   // reset buffers before performing a full recalculation
   if (!ValidBars) {
      ArrayInitialize(ma1,        EMPTY_VALUE);
      ArrayInitialize(ma2,        EMPTY_VALUE);
      ArrayInitialize(ma3,        EMPTY_VALUE);
      ArrayInitialize(ma1Trend,   0);
      ArrayInitialize(ma2Trend,   0);
      ArrayInitialize(ma3Trend,   0);
      ArrayInitialize(totalTrend, 0);
      SetIndicatorOptions();
   }

   // synchronize buffers with a shifted offline chart
   if (ShiftedBars > 0) {
      ShiftIndicatorBuffer(ma1,        Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(ma2,        Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(ma3,        Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(ma1Trend,   Bars, ShiftedBars, 0);
      ShiftIndicatorBuffer(ma2Trend,   Bars, ShiftedBars, 0);
      ShiftIndicatorBuffer(ma3Trend,   Bars, ShiftedBars, 0);
      ShiftIndicatorBuffer(totalTrend, Bars, ShiftedBars, 0);
   }

   // calculate start bar
   int startbar = Min(ChangedBars-1, Bars-totalInitPeriods), i, prevTrend;
   if (startbar < 0) return(logInfo("onTick(2)  Tick="+ Tick, ERR_HISTORY_INSUFFICIENT));

   // MA1
   if (UseMA1) {
      for (i=startbar; i >= 0; i--) {
         ma1[i] = iMA(NULL, NULL, ma1Periods, 0, ma1Method, ma1AppliedPrice, i);

         prevTrend = ma1Trend[i+1];
         if      (Close[i] > iMA(NULL, NULL, ma1Periods, 0, ma1Method, PRICE_HIGH, i+1)) ma1Trend[i] = Max(prevTrend, 0) + 1;
         else if (Close[i] < iMA(NULL, NULL, ma1Periods, 0, ma1Method, PRICE_LOW,  i+1)) ma1Trend[i] = Min(prevTrend, 0) - 1;
         else                                                                            ma1Trend[i] = prevTrend + Sign(prevTrend);
      }
   }

   // MA2
   if (UseMA2) {
      for (i=startbar; i >= 0; i--) {
         ma2[i] = iMA(NULL, NULL, ma2Periods, 0, ma2Method, ma2AppliedPrice, i);

         prevTrend = ma2Trend[i+1];
         if      (Close[i] > iMA(NULL, NULL, ma2Periods, 0, ma2Method, PRICE_HIGH, i+1)) ma2Trend[i] = Max(prevTrend, 0) + 1;
         else if (Close[i] < iMA(NULL, NULL, ma2Periods, 0, ma2Method, PRICE_LOW,  i+1)) ma2Trend[i] = Min(prevTrend, 0) - 1;
         else                                                                            ma2Trend[i] = prevTrend + Sign(prevTrend);
      }
   }

   // MA3
   if (UseMA3) {
      for (i=startbar; i >= 0; i--) {
         ma3[i] = iMA(NULL, NULL, ma3Periods, 0, ma3Method, ma3AppliedPrice, i);

         prevTrend = ma3Trend[i+1];
         if      (Close[i] > iMA(NULL, NULL, ma3Periods, 0, ma3Method, PRICE_HIGH, i+1)) ma3Trend[i] = Max(prevTrend, 0) + 1;
         else if (Close[i] < iMA(NULL, NULL, ma3Periods, 0, ma3Method, PRICE_LOW,  i+1)) ma3Trend[i] = Min(prevTrend, 0) - 1;
         else                                                                            ma3Trend[i] = prevTrend + Sign(prevTrend);
      }
   }

   // total trend
   for (i=startbar; i >= 0; i--) {
      prevTrend = totalTrend[i+1];
      if      ((!UseMA1 || ma1Trend[i] > 0) && (!UseMA2 || ma2Trend[i] > 0) && (!UseMA3 || ma3Trend[i] > 0)) totalTrend[i] = Max(prevTrend, 0) + 1;
      else if ((!UseMA1 || ma1Trend[i] < 0) && (!UseMA2 || ma2Trend[i] < 0) && (!UseMA3 || ma3Trend[i] < 0)) totalTrend[i] = Min(prevTrend, 0) - 1;
      else                                                                                                   totalTrend[i] = prevTrend + Sign(prevTrend);
   }


   //if (!ValidBars) {
   //   debug("onTick(0.1)  ma1="+ NumberToStr(ma1[0], ".+") +"  trend="+ _int(ma1Trend[0]) +" ("+ ColorToStr(indicator_color1) +")");
   //   debug("onTick(0.2)  ma2="+ NumberToStr(ma2[0], ".+") +"  trend="+ _int(ma2Trend[0]) +" ("+ ColorToStr(indicator_color2) +")");
   //   debug("onTick(0.3)  ma3="+ NumberToStr(ma3[0], ".+") +"  trend="+ _int(ma3Trend[0]) +" ("+ ColorToStr(indicator_color3) +")");
   //}
   //if (IsBarOpen()) debug("onTick(0.4)  totalTrend="+ _int(totalTrend[1]));

   CheckSignals();
   ShowStatus();
   return(last_error);
}


/**
 * Check and process signals
 *
 * @return bool - success status
 */
bool CheckSignals() {
   if (IsSuperContext() || !signals) return(true);

   if (signal.onTick) {
   }

   // detect tunnel breakouts to the opposite side of the current trend (but not trend continuation signals)
   if (signal.onBarOpen) /*&&*/ if (IsBarOpen()) {
      static int lastTrend; if (!lastTrend) lastTrend = totalTrend[2];
      int trend = totalTrend[1];
      if      (lastTrend<=0 && trend > 0) onBreakout(MODE_LONG);        // also detects breakouts on bars without ticks (M1)
      else if (lastTrend>=0 && trend < 0) onBreakout(MODE_SHORT);
      lastTrend = trend;
   }
}


/**
 * Event handler for tunnel breakouts.
 *
 * @param  int mode - breakout id: MODE_LONG | MODE_SHORT
 *
 * @return bool - success status
 */
bool onBreakout(int mode) {
   if (mode == MODE_LONG) {
      debug("onBreakout(1)  breakout LONG");
   }
   else if (mode == MODE_SHORT) {
      debug("onBreakout(2)  breakout SHORT");
   }
   else return(!catch("onBreakout(3)  invalid parameter mode: "+ mode, ERR_INVALID_PARAMETER));

   return(true);
}


/**
 * Workaround for various terminal bugs when setting indicator options. Usually options are set in init(). However after
 * recompilation options must be set in start() to not be ignored.
 */
void SetIndicatorOptions() {
   IndicatorBuffers(terminal_buffers);
   //SetIndexStyle(int buffer, int drawType, int lineStyle=EMPTY, int drawWidth=EMPTY, color drawColor=NULL)

   SetIndexStyle(MODE_MA1, DRAW_LINE, EMPTY, 2);
   SetIndexStyle(MODE_MA2, DRAW_LINE, EMPTY, 2);
   SetIndexStyle(MODE_MA3, DRAW_LINE, EMPTY, 2);
}


/**
 * Display the current runtime status.
 *
 * @param  int error [optional] - error to display (default: none)
 *
 * @return int - the same error or the current error status if no error was passed
 */
int ShowStatus(int error = NO_ERROR) {
   //if (!__isChart) return(error);
   //
   //static bool isRecursion = false;             // to prevent recursive calls a specified error is displayed only once
   //if (error != 0) {
   //   if (isRecursion) return(error);
   //   isRecursion = true;
   //}
   //
   //string sError = "";
   //if (__STATUS_OFF) sError = StringConcatenate("  [switched off => ", ErrorDescription(__STATUS_OFF.reason), "]");
   //string msg = sError;
   //
   //// 4 lines margin-top for instrument and indicator legends
   //Comment(NL, NL, NL, NL, msg);
   //if (__CoreFunction == CF_INIT) WindowRedraw();
   //
   //isRecursion = false;
   return(error);
}


/**
 * Return a string representation of the input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("UseMA1=",           BoolToStr(UseMA1),                ";", NL,
                            "MA1.Periods=",      MA1.Periods,                      ";", NL,
                            "MA1.Method=",       DoubleQuoteStr(MA1.Method),       ";", NL,
                            "MA1.AppliedPrice=", DoubleQuoteStr(MA1.AppliedPrice), ";", NL,
                            "UseMA2=",           BoolToStr(UseMA2),                ";", NL,
                            "MA2.Periods=",      MA2.Periods,                      ";", NL,
                            "MA2.Method=",       DoubleQuoteStr(MA2.Method),       ";", NL,
                            "MA2.AppliedPrice=", DoubleQuoteStr(MA2.AppliedPrice), ";", NL,
                            "UseMA3=",           BoolToStr(UseMA3),                ";", NL,
                            "MA3.Periods=",      MA3.Periods,                      ";", NL,
                            "MA3.Method=",       DoubleQuoteStr(MA3.Method),       ";", NL,
                            "MA3.AppliedPrice=", DoubleQuoteStr(MA3.AppliedPrice), ";")
   );
}
