/**
 * MA Tunnel Monitor
 *
 * A signal monitor for trends defined by multiple moving averages. Can be used e.g. for the "XARD trend following" or the
 * "Vegas tunnel" system.
 *
 * @link  https://forex-station.com/viewtopic.php?f=578267&t=8416709#                  [XARD - Simple Trend Following System]
 * @link  https://www.forexfactory.com/thread/4365#                                                     [Vegas Tunnel Method]
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

extern string __4___________________________ = "=== Signaling ================================";
extern bool   Signal.onBreakout              = false;
extern bool   Signal.onBreakout.Sound        = true;
extern bool   Signal.onBreakout.Popup        = true;
extern bool   Signal.onBreakout.Mail         = false;
extern bool   Signal.onBreakout.SMS          = false;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <rsfLibs.mqh>
#include <functions/ConfigureSignals.mqh>
#include <functions/IsBarOpen.mqh>

#define MODE_MA1              0              // indicator buffer ids
#define MODE_MA2              1
#define MODE_MA3              2
#define MODE_TOTAL_TREND      3
#define MODE_MA1_TREND        4
#define MODE_MA2_TREND        5
#define MODE_MA3_TREND        6

#define MODE_LONG             1              // breakout directions
#define MODE_SHORT            2

#property indicator_chart_window
#property indicator_buffers   4              // buffers visible to the user
int       terminal_buffers =  7;             // buffers managed by the terminal

#property indicator_color1    Magenta
#property indicator_color2    Red
#property indicator_color3    Blue

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

string signalSoundUp      = "Signal-Up.wav";
string signalSoundDown    = "Signal-Down.wav";
string signalMailSender   = "";
string signalMailReceiver = "";
string signalSmsReceiver  = "";
string signalDescription  = "";


/**
 * Initialization
 *
 * @param  bool accountChange [optional] - whether called due to an account change event (default: no)
 *
 * @return int - error status
 */
int onInit(bool accountChange = false) {
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

   // signaling
   string signalId = "Signal.onBreakout";
   if (!ConfigureSignals2(signalId, AutoConfiguration, Signal.onBreakout))                                                      return(last_error);
   if (Signal.onBreakout) {
      if (!ConfigureSignalsBySound2(signalId, AutoConfiguration, Signal.onBreakout.Sound))                                      return(last_error);
      if (!ConfigureSignalsByPopup (signalId, AutoConfiguration, Signal.onBreakout.Popup))                                      return(last_error);
      if (!ConfigureSignalsByMail2 (signalId, AutoConfiguration, Signal.onBreakout.Mail, signalMailSender, signalMailReceiver)) return(last_error);
      if (!ConfigureSignalsBySMS2  (signalId, AutoConfiguration, Signal.onBreakout.SMS, signalSmsReceiver))                     return(last_error);
      if (Signal.onBreakout.Sound || Signal.onBreakout.Popup || Signal.onBreakout.Mail || Signal.onBreakout.SMS) {
         signalDescription = "onBreakout="+ StrLeft(ifString(Signal.onBreakout.Sound, "Sound+", "") + ifString(Signal.onBreakout.Popup, "Popup+", "") + ifString(Signal.onBreakout.Mail, "Mail+", "") + ifString(Signal.onBreakout.SMS, "SMS+", ""), -1);
         if (IsLogDebug()) logDebug("onInit(11)  "+ signalDescription);
      }
      else Signal.onBreakout = false;
   }

   // buffer management
   SetIndexBuffer(MODE_MA1,         ma1);
   SetIndexBuffer(MODE_MA2,         ma2);
   SetIndexBuffer(MODE_MA3,         ma3);
   SetIndexBuffer(MODE_MA1_TREND,   ma1Trend);   SetIndexEmptyValue(MODE_MA1_TREND,   0);
   SetIndexBuffer(MODE_MA2_TREND,   ma2Trend);   SetIndexEmptyValue(MODE_MA2_TREND,   0);
   SetIndexBuffer(MODE_MA3_TREND,   ma3Trend);   SetIndexEmptyValue(MODE_MA3_TREND,   0);
   SetIndexBuffer(MODE_TOTAL_TREND, totalTrend); SetIndexEmptyValue(MODE_TOTAL_TREND, 0);

   // display options
   SetIndexLabel(MODE_MA1, NULL); if (UseMA1) SetIndexLabel(MODE_MA1, "MA Tunnel "+ MA1.Method +"("+ MA1.Periods +")");
   SetIndexLabel(MODE_MA2, NULL); if (UseMA2) SetIndexLabel(MODE_MA2, "MA Tunnel "+ MA2.Method +"("+ MA2.Periods +")");
   SetIndexLabel(MODE_MA3, NULL); if (UseMA3) SetIndexLabel(MODE_MA3, "MA Tunnel "+ MA3.Method +"("+ MA3.Periods +")");
   SetIndexLabel(MODE_TOTAL_TREND, "MA Tunnel trend");

   IndicatorDigits(Digits);
   SetIndicatorOptions();

   return(catch("onInit(12)"));
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
   if (!UnchangedBars) {
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

   CheckSignals();
   ShowStatus();                 // TODO: implement it (currently empty)
   return(last_error);
}


/**
 * Check and process signals
 *
 * @return bool - success status
 */
bool CheckSignals() {
   if (IsSuperContext()) return(true);

   // detect tunnel breakouts to the opposite side of the current trend (skips trend continuation signals)
   if (Signal.onBreakout) /*&&*/ if (IsBarOpen()) {
      static int lastTrend; if (!lastTrend) lastTrend = totalTrend[2];
      int trend = totalTrend[1];
      if      (lastTrend<=0 && trend > 0) onBreakout(MODE_LONG);        // also detects breakouts on bars without ticks (M1)
      else if (lastTrend>=0 && trend < 0) onBreakout(MODE_SHORT);
      lastTrend = trend;
   }

   //if (Signal.onMainCross) {
   //}
}


/**
 * Event handler for tunnel breakouts.
 *
 * @param  int mode - breakout id: MODE_LONG | MODE_SHORT
 *
 * @return bool - success status
 */
bool onBreakout(int mode) {
   string message="", accountTime="("+ TimeToStr(TimeLocal(), TIME_MINUTES|TIME_SECONDS) +", "+ GetAccountAlias() +")";
   int error = NO_ERROR;

   if (mode == MODE_LONG) {
      message = "MA tunnel breakout LONG ("+ NumberToStr((Bid+Ask)/2, PriceFormat) +")";
      if (IsLogInfo()) logInfo("onBreakout(1)  "+ message);
      message = Symbol() +","+ PeriodDescription() +": "+ message;

      if (Signal.onBreakout.Popup)           Alert(message);               // before "Sound" to overwrite an enabled alert sound
      if (Signal.onBreakout.Sound) error |= !PlaySoundEx(signalSoundUp);
      if (Signal.onBreakout.Mail)  error |= !SendEmail(signalMailSender, signalMailReceiver, message, message + NL + accountTime);
      if (Signal.onBreakout.SMS)   error |= !SendSMS(signalSmsReceiver, message +NL+ accountTime);
      return(!error);
   }

   if (mode == MODE_SHORT) {
      message = "MA tunnel breakout SHORT ("+ NumberToStr((Bid+Ask)/2, PriceFormat) +")";
      if (IsLogInfo()) logInfo("onBreakout(2)  "+ message);
      message = Symbol() +","+ PeriodDescription() +": "+ message;

      if (Signal.onBreakout.Popup)           Alert(message);               // before "Sound" to overwrite an enabled alert sound
      if (Signal.onBreakout.Sound) error |= !PlaySoundEx(signalSoundDown);
      if (Signal.onBreakout.Mail)  error |= !SendEmail(signalMailSender, signalMailReceiver, message, message + NL + accountTime);
      if (Signal.onBreakout.SMS)   error |= !SendSMS(signalSmsReceiver, message +NL+ accountTime);
      return(!error);
   }

   return(!catch("onBreakout(3)  invalid parameter mode: "+ mode, ERR_INVALID_PARAMETER));
}


/**
 * Workaround for various terminal bugs when setting indicator options. Usually options are set in init(). However after
 * recompilation options must be set in start() to not be ignored.
 */
void SetIndicatorOptions() {
   IndicatorBuffers(terminal_buffers);
   //SetIndexStyle(int buffer, int drawType, int lineStyle=EMPTY, int drawWidth=EMPTY, color drawColor=NULL)

   SetIndexStyle(MODE_MA1, ifInt(UseMA1, DRAW_LINE, DRAW_NONE), EMPTY, 2, indicator_color1);
   SetIndexStyle(MODE_MA2, ifInt(UseMA2, DRAW_LINE, DRAW_NONE), EMPTY, 2, indicator_color2);
   SetIndexStyle(MODE_MA3, ifInt(UseMA3, DRAW_LINE, DRAW_NONE), EMPTY, 2, indicator_color3);

   SetIndexStyle(MODE_TOTAL_TREND, DRAW_NONE, EMPTY, EMPTY, CLR_NONE);
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
   return(StringConcatenate("UseMA1="                + BoolToStr(UseMA1)                  +";"+ NL
                           +"MA1.Periods="           + MA1.Periods                        +";"+ NL
                           +"MA1.Method="            + DoubleQuoteStr(MA1.Method)         +";"+ NL
                           +"MA1.AppliedPrice="      + DoubleQuoteStr(MA1.AppliedPrice)   +";"+ NL
                           +"UseMA2="                + BoolToStr(UseMA2)                  +";"+ NL
                           +"MA2.Periods="           + MA2.Periods                        +";"+ NL
                           +"MA2.Method="            + DoubleQuoteStr(MA2.Method)         +";"+ NL
                           +"MA2.AppliedPrice="      + DoubleQuoteStr(MA2.AppliedPrice)   +";"+ NL
                           +"UseMA3="                + BoolToStr(UseMA3)                  +";"+ NL
                           +"MA3.Periods="           + MA3.Periods                        +";"+ NL
                           +"MA3.Method="            + DoubleQuoteStr(MA3.Method)         +";"+ NL
                           +"MA3.AppliedPrice="      + DoubleQuoteStr(MA3.AppliedPrice)   +";"+ NL
                           +"Signal.onBreakout"      + BoolToStr(Signal.onBreakout)       +";"+ NL
                           +"Signal.onBreakout.Sound"+ BoolToStr(Signal.onBreakout.Sound) +";"+ NL
                           +"Signal.onBreakout.Popup"+ BoolToStr(Signal.onBreakout.Popup) +";"+ NL
                           +"Signal.onBreakout.Mail" + BoolToStr(Signal.onBreakout.Mail)  +";"+ NL
                           +"Signal.onBreakout.SMS"  + BoolToStr(Signal.onBreakout.SMS),   ";")
   );
}
