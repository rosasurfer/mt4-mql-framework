/**
 * Multi-color MACD
 *
 *
 * Available Moving Average types:
 *  • SMA  - Simple Moving Average:          equal bar weighting
 *  • TMA  - Triangular Moving Average:      SMA which has been averaged again: SMA(SMA(n/2)/2), more smooth but more lag
 *  • LWMA - Linear Weighted Moving Average: bar weighting using a linear function
 *  • EMA  - Exponential Moving Average:     bar weighting using an exponential function
 *  • ALMA - Arnaud Legoux Moving Average:   bar weighting using a Gaussian function
 *
 * The Smoothed Moving Average (SMMA) is not supported as it's just an EMA of a different period.
 *
 * Indicator buffers to use with iCustom():
 *  • MACD.MODE_MAIN:    MACD main values
 *  • MACD.MODE_TREND:   trend direction and length
 *    - trend direction: positive values denote a MACD above zero (+1...+n), negative values a MACD below zero (-1...-n)
 *    - trend length:    the absolute direction value is the histogram section length (bars since the last crossing of zero)
 *
 *
 * Note: The file is intentionally named "MACD .mql" as a file "MACD.mql" would be overwritten by newer terminal versions.
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern int    Fast.MA.Periods       = 12;
extern string Fast.MA.Method        = "SMA | TMA | LWMA | EMA | ALMA*";
extern string Fast.MA.AppliedPrice  = "Open | High | Low | Close* | Median | Typical | Weighted";

extern int    Slow.MA.Periods       = 38;
extern string Slow.MA.Method        = "SMA | TMA | LWMA | EMA | ALMA*";
extern string Slow.MA.AppliedPrice  = "Open | High | Low | Close* | Median | Typical | Weighted";

extern color  MainLine.Color        = DodgerBlue;           // indicator style management in MQL
extern int    MainLine.Width        = 1;

extern color  Histogram.Color.Upper = LimeGreen;
extern color  Histogram.Color.Lower = Red;
extern int    Histogram.Style.Width = 2;

extern int    Max.Values            = 5000;                 // max. number of values to display: -1 = all

extern string __________________________;

extern string Signal.onZeroCross    = "auto* | off | on";
extern string Signal.Sound          = "auto* | off | on";
extern string Signal.Mail.Receiver  = "auto* | off | on | {email-address}";
extern string Signal.SMS.Receiver   = "auto* | off | on | {phone-number}";

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <stdlibs.mqh>
#include <functions/@ALMA.mqh>
#include <functions/Configure.Signal.mqh>
#include <functions/Configure.Signal.Mail.mqh>
#include <functions/Configure.Signal.SMS.mqh>
#include <functions/Configure.Signal.Sound.mqh>
#include <functions/EventListener.BarOpen.mqh>

#define MODE_MAIN             MACD.MODE_MAIN                // indicator buffer ids
#define MODE_TREND            MACD.MODE_TREND
#define MODE_UPPER_SECTION    2
#define MODE_LOWER_SECTION    3
#define MODE_FAST_TMA_SMA     4
#define MODE_SLOW_TMA_SMA     5

#property indicator_separate_window
#property indicator_buffers   4                             // configurable buffers (input dialog)
int       allocated_buffers = 6;                            // used buffers
#property indicator_level1    0

double bufferMACD[];                                        // MACD main value:           visible, displayed in "Data" window
double bufferTrend[];                                       // MACD direction and length: invisible
double bufferUpper[];                                       // positive histogram values: visible
double bufferLower[];                                       // negative histogram values: visible

int    fast.ma.periods;
int    fast.ma.method;
int    fast.ma.appliedPrice;
int    fast.tma.periods.1;                                  // TMA subperiods
int    fast.tma.periods.2;
double fast.tma.bufferSMA[];                                // fast TMA intermediate SMA buffer
double fast.alma.weights[];                                 // fast ALMA weights

int    slow.ma.periods;
int    slow.ma.method;
int    slow.ma.appliedPrice;
int    slow.tma.periods.1;
int    slow.tma.periods.2;
double slow.tma.bufferSMA[];                                // slow TMA intermediate SMA buffer
double slow.alma.weights[];                                 // slow ALMA weights

string macd.shortName;                                      // "Data" window and signal notification name

bool   signals;

bool   signal.sound;
string signal.sound.zeroCross_plus  = "Signal-Up.wav";
string signal.sound.zeroCross_minus = "Signal-Down.wav";

bool   signal.mail;
string signal.mail.sender   = "";
string signal.mail.receiver = "";

bool   signal.sms;
string signal.sms.receiver = "";


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   if (InitReason() == IR_RECOMPILE) {
      if (!RestoreInputParameters()) return(last_error);
   }

   // (1) validate inputs
   // Fast.MA.Periods
   if (Fast.MA.Periods < 1)                return(catch("onInit(1)  Invalid input parameter Fast.MA.Periods = "+ Fast.MA.Periods, ERR_INVALID_INPUT_PARAMETER));
   fast.ma.periods = Fast.MA.Periods;

   // Slow.MA.Periods
   if (Slow.MA.Periods < 1)                return(catch("onInit(2)  Invalid input parameter Slow.MA.Periods = "+ Slow.MA.Periods, ERR_INVALID_INPUT_PARAMETER));
   slow.ma.periods = Slow.MA.Periods;
   if (Fast.MA.Periods >= Slow.MA.Periods) return(catch("onInit(3)  Parameter mis-match of Fast.MA.Periods/Slow.MA.Periods: "+ Fast.MA.Periods +"/"+ Slow.MA.Periods +" (fast value must be smaller than slow one)", ERR_INVALID_INPUT_PARAMETER));

   // Fast.MA.Method
   string sValue, values[];
   if (Explode(Fast.MA.Method, "*", values, 2) > 1) {
      int size = Explode(values[0], "|", values, NULL);
      sValue = values[size-1];
   }
   else {
      sValue = StringTrim(Fast.MA.Method);
      if (sValue == "") sValue = "EMA";                                 // default MA method
   }
   fast.ma.method = StrToMaMethod(sValue, F_ERR_INVALID_PARAMETER);
   if (fast.ma.method == -1)               return(catch("onInit(4)  Invalid input parameter Fast.MA.Method = "+ DoubleQuoteStr(Fast.MA.Method), ERR_INVALID_INPUT_PARAMETER));
   Fast.MA.Method = MaMethodDescription(fast.ma.method);

   // Slow.MA.Method
   if (Explode(Slow.MA.Method, "*", values, 2) > 1) {
      size = Explode(values[0], "|", values, NULL);
      sValue = values[size-1];
   }
   else {
      sValue = StringTrim(Slow.MA.Method);
      if (sValue == "") sValue = "EMA";                                 // default MA method
   }
   slow.ma.method = StrToMaMethod(sValue, F_ERR_INVALID_PARAMETER);
   if (slow.ma.method == -1)               return(catch("onInit(5)  Invalid input parameter Slow.MA.Method = "+ DoubleQuoteStr(Slow.MA.Method), ERR_INVALID_INPUT_PARAMETER));
   Slow.MA.Method = MaMethodDescription(slow.ma.method);

   // Fast.MA.AppliedPrice
   sValue = StringToLower(Fast.MA.AppliedPrice);
   if (Explode(sValue, "*", values, 2) > 1) {
      size = Explode(values[0], "|", values, NULL);
      sValue = values[size-1];
   }
   sValue = StringTrim(sValue);
   if (sValue == "") sValue = "close";                                  // default price type
   if      (StringStartsWith("open",     sValue)) fast.ma.appliedPrice = PRICE_OPEN;
   else if (StringStartsWith("high",     sValue)) fast.ma.appliedPrice = PRICE_HIGH;
   else if (StringStartsWith("low",      sValue)) fast.ma.appliedPrice = PRICE_LOW;
   else if (StringStartsWith("close",    sValue)) fast.ma.appliedPrice = PRICE_CLOSE;
   else if (StringStartsWith("median",   sValue)) fast.ma.appliedPrice = PRICE_MEDIAN;
   else if (StringStartsWith("typical",  sValue)) fast.ma.appliedPrice = PRICE_TYPICAL;
   else if (StringStartsWith("weighted", sValue)) fast.ma.appliedPrice = PRICE_WEIGHTED;
   else                                    return(catch("onInit(6)  Invalid input parameter Fast.MA.AppliedPrice = "+ DoubleQuoteStr(Fast.MA.AppliedPrice), ERR_INVALID_INPUT_PARAMETER));
   Fast.MA.AppliedPrice = PriceTypeDescription(fast.ma.appliedPrice);

   // Slow.MA.AppliedPrice
   sValue = StringToLower(Slow.MA.AppliedPrice);
   if (Explode(sValue, "*", values, 2) > 1) {
      size = Explode(values[0], "|", values, NULL);
      sValue = values[size-1];
   }
   sValue = StringTrim(sValue);
   if (sValue == "") sValue = "close";                                  // default price type
   if      (StringStartsWith("open",     sValue)) slow.ma.appliedPrice = PRICE_OPEN;
   else if (StringStartsWith("high",     sValue)) slow.ma.appliedPrice = PRICE_HIGH;
   else if (StringStartsWith("low",      sValue)) slow.ma.appliedPrice = PRICE_LOW;
   else if (StringStartsWith("close",    sValue)) slow.ma.appliedPrice = PRICE_CLOSE;
   else if (StringStartsWith("median",   sValue)) slow.ma.appliedPrice = PRICE_MEDIAN;
   else if (StringStartsWith("typical",  sValue)) slow.ma.appliedPrice = PRICE_TYPICAL;
   else if (StringStartsWith("weighted", sValue)) slow.ma.appliedPrice = PRICE_WEIGHTED;
   else                                    return(catch("onInit(7)  Invalid input parameter Slow.MA.AppliedPrice = "+ DoubleQuoteStr(Slow.MA.AppliedPrice), ERR_INVALID_INPUT_PARAMETER));
   Slow.MA.AppliedPrice = PriceTypeDescription(slow.ma.appliedPrice);

   // Colors
   if (MainLine.Color        == 0xFF000000) MainLine.Color        = CLR_NONE;    // after unserialization the terminal might turn CLR_NONE (0xFFFFFFFF)
   if (Histogram.Color.Upper == 0xFF000000) Histogram.Color.Upper = CLR_NONE;    // into Black (0xFF000000)
   if (Histogram.Color.Lower == 0xFF000000) Histogram.Color.Lower = CLR_NONE;

   // Styles
   if (MainLine.Width < 0)                 return(catch("onInit(8)  Invalid input parameter MainLine.Width = "+ MainLine.Width, ERR_INVALID_INPUT_PARAMETER));
   if (MainLine.Width > 5)                 return(catch("onInit(9)  Invalid input parameter MainLine.Width = "+ MainLine.Width, ERR_INVALID_INPUT_PARAMETER));
   if (Histogram.Style.Width < 0)          return(catch("onInit(10)  Invalid input parameter Histogram.Style.Width = "+ Histogram.Style.Width, ERR_INVALID_INPUT_PARAMETER));
   if (Histogram.Style.Width > 5)          return(catch("onInit(11)  Invalid input parameter Histogram.Style.Width = "+ Histogram.Style.Width, ERR_INVALID_INPUT_PARAMETER));

   // Max.Values
   if (Max.Values < -1)                    return(catch("onInit(12)  Invalid input parameter Max.Values = "+ Max.Values, ERR_INVALID_INPUT_PARAMETER));

   // Signals
   if (!Configure.Signal("MACD", Signal.onZeroCross, signals))                                                  return(last_error);
   if (signals) {
      if (!Configure.Signal.Sound(Signal.Sound,         signal.sound                                         )) return(last_error);
      if (!Configure.Signal.Mail (Signal.Mail.Receiver, signal.mail, signal.mail.sender, signal.mail.receiver)) return(last_error);
      if (!Configure.Signal.SMS  (Signal.SMS.Receiver,  signal.sms,                      signal.sms.receiver )) return(last_error);
      if (!signal.sound && !signal.mail && !signal.sms)
         signals = false;
   }


   // (2) setup buffer management
   SetIndexBuffer(MODE_MAIN,          bufferMACD        );              // MACD main value:              visible, displayed in "Data" window
   SetIndexBuffer(MODE_TREND,         bufferTrend       );              // MACD direction and length:    invisible
   SetIndexBuffer(MODE_UPPER_SECTION, bufferUpper       );              // positive values:              visible
   SetIndexBuffer(MODE_LOWER_SECTION, bufferLower       );              // negative values:              visible
   SetIndexBuffer(MODE_FAST_TMA_SMA,  fast.tma.bufferSMA);              // fast intermediate TMA buffer: invisible
   SetIndexBuffer(MODE_SLOW_TMA_SMA,  slow.tma.bufferSMA);              // slow intermediate TMA buffer: invisible


   // (3) data display configuration and names
   string strAppliedPrice = "";
   if (fast.ma.appliedPrice != PRICE_CLOSE) strAppliedPrice = ","+ PriceTypeDescription(fast.ma.appliedPrice);
   string fast.ma.name = Fast.MA.Method +"("+ fast.ma.periods + strAppliedPrice +")";
   strAppliedPrice = "";
   if (slow.ma.appliedPrice != PRICE_CLOSE) strAppliedPrice = ","+ PriceTypeDescription(slow.ma.appliedPrice);
   string slow.ma.name = Slow.MA.Method +"("+ slow.ma.periods + strAppliedPrice +")";
   macd.shortName = "MACD "+ fast.ma.name +", "+ slow.ma.name;
   string signalInfo = ifString(Signal.onZeroCross, "  ZeroCross="+ StringLeft(ifString(signal.sound, "Sound,", "") + ifString(signal.mail,  "Mail,",  "") + ifString(signal.sms, "SMS,", ""), -1), "");
   string macd.name  = macd.shortName + signalInfo +"  ";

   // names and labels
   IndicatorShortName(macd.name);                                       // indicator subwindow and context menu
   string macd.dataName = "MACD "+ Fast.MA.Method +"("+ fast.ma.periods +"), "+ Slow.MA.Method +"("+ slow.ma.periods +")";
   SetIndexLabel(MODE_MAIN,          macd.dataName);                    // "Data" window and tooltips
   SetIndexLabel(MODE_TREND,         NULL);
   SetIndexLabel(MODE_UPPER_SECTION, NULL);
   SetIndexLabel(MODE_LOWER_SECTION, NULL);
   SetIndexLabel(MODE_FAST_TMA_SMA,  NULL);
   SetIndexLabel(MODE_SLOW_TMA_SMA,  NULL);
   IndicatorDigits(2);


   // (4) drawing options and styles
   int startDraw = 0;
   if (Max.Values >= 0) startDraw += Bars - Max.Values;
   if (startDraw  <  0) startDraw  = 0;
   SetIndexDrawBegin(MODE_MAIN,          startDraw);
   SetIndexDrawBegin(MODE_UPPER_SECTION, startDraw);
   SetIndexDrawBegin(MODE_LOWER_SECTION, startDraw);
   SetIndicatorOptions();


   // (5) initialize indicator calculations where applicable
   if (fast.ma.method == MODE_TMA) {
      fast.tma.periods.1 = fast.ma.periods / 2;
      fast.tma.periods.2 = fast.ma.periods - fast.tma.periods.1 + 1;    // subperiods overlap by one bar: TMA(2) = SMA(1) + SMA(2)
   }
   else if (fast.ma.method == MODE_ALMA) {
      @ALMA.CalculateWeights(fast.alma.weights, fast.ma.periods);
   }
   if (slow.ma.method == MODE_TMA) {
      slow.tma.periods.1 = slow.ma.periods / 2;
      slow.tma.periods.2 = slow.ma.periods - slow.tma.periods.1 + 1;
   }
   else if (slow.ma.method == MODE_ALMA) {
      @ALMA.CalculateWeights(slow.alma.weights, slow.ma.periods);
   }

   return(catch("onInit(13)"));
}


/**
 * Called before recompilation.
 *
 * @return int - error status
 */
int onDeinitRecompile() {
   StoreInputParameters();
   return(NO_ERROR);
}


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   // check for finished buffer initialization (sometimes needed on terminal start)
   if (!ArraySize(bufferMACD))
      return(log("onTick(1)  size(bufferMACD) = 0", SetLastError(ERS_TERMINAL_NOT_YET_READY)));

   // reset all buffers and delete garbage behind Max.Values before doing a full recalculation
   if (!ValidBars) {
      ArrayInitialize(bufferMACD,         EMPTY_VALUE);
      ArrayInitialize(bufferTrend,                  0);
      ArrayInitialize(bufferUpper,        EMPTY_VALUE);
      ArrayInitialize(bufferLower,        EMPTY_VALUE);
      ArrayInitialize(fast.tma.bufferSMA, EMPTY_VALUE);
      ArrayInitialize(slow.tma.bufferSMA, EMPTY_VALUE);
      SetIndicatorOptions();
   }

   // synchronize buffers with a shifted offline chart
   if (ShiftedBars > 0) {
      ShiftIndicatorBuffer(bufferMACD,         Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(bufferTrend,        Bars, ShiftedBars,           0);
      ShiftIndicatorBuffer(bufferUpper,        Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(bufferLower,        Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(fast.tma.bufferSMA, Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(slow.tma.bufferSMA, Bars, ShiftedBars, EMPTY_VALUE);
   }


   // (1) calculate start bar
   int changedBars = ChangedBars;
   if (Max.Values >= 0) /*&&*/ if (ChangedBars > Max.Values)
      changedBars = Max.Values;
   int startBar = Min(changedBars-1, Bars-slow.ma.periods);
   if (startBar < 0) return(catch("onTick(2)", ERR_HISTORY_INSUFFICIENT));


   // (2) recalculate invalid bars
   if (fast.ma.method == MODE_TMA) {
      // pre-calculate a fast TMA's intermediate SMA
      for (int bar=startBar; bar >= 0; bar--) {
         fast.tma.bufferSMA[bar] = iMA(NULL, NULL, fast.tma.periods.1, 0, MODE_SMA, fast.ma.appliedPrice, bar);
      }
   }
   if (slow.ma.method == MODE_TMA) {
      // pre-calculate a slow TMA's intermediate SMA
      for (bar=startBar; bar >= 0; bar--) {
         slow.tma.bufferSMA[bar] = iMA(NULL, NULL, slow.tma.periods.1, 0, MODE_SMA, slow.ma.appliedPrice, bar);
      }
   }

   for (bar=startBar; bar >= 0; bar--) {
      // fast MA
      if (fast.ma.method == MODE_TMA) {
         double fast.ma = iMAOnArray(fast.tma.bufferSMA, WHOLE_ARRAY, fast.tma.periods.2, 0, MODE_SMA, bar);
      }
      else if (fast.ma.method == MODE_ALMA) {
         fast.ma = 0;
         for (int i=0; i < fast.ma.periods; i++) {
            fast.ma += fast.alma.weights[i] * iMA(NULL, NULL, 1, 0, MODE_SMA, fast.ma.appliedPrice, bar+i);
         }
      }
      else {
         fast.ma = iMA(NULL, NULL, fast.ma.periods, 0, fast.ma.method, fast.ma.appliedPrice, bar);
      }

      // slow MA
      if (slow.ma.method == MODE_TMA) {
         double slow.ma = iMAOnArray(slow.tma.bufferSMA, WHOLE_ARRAY, slow.tma.periods.2, 0, MODE_SMA, bar);
      }
      else if (slow.ma.method == MODE_ALMA) {
         slow.ma = 0;
         for (i=0; i < slow.ma.periods; i++) {
            slow.ma += slow.alma.weights[i] * iMA(NULL, NULL, 1, 0, MODE_SMA, slow.ma.appliedPrice, bar+i);
         }
      }
      else {
         slow.ma = iMA(NULL, NULL, slow.ma.periods, 0, slow.ma.method, slow.ma.appliedPrice, bar);
      }

      // final MACD
      bufferMACD[bar] = (fast.ma - slow.ma)/Pips;

      if (bufferMACD[bar] > 0) {
         bufferUpper[bar] = bufferMACD[bar];
         bufferLower[bar] = EMPTY_VALUE;
      }
      else {
         bufferUpper[bar] = EMPTY_VALUE;
         bufferLower[bar] = bufferMACD[bar];
      }

      // update section length (duration)
      if      (bufferTrend[bar+1] > 0 && bufferMACD[bar] >= 0) bufferTrend[bar] = bufferTrend[bar+1] + 1;
      else if (bufferTrend[bar+1] < 0 && bufferMACD[bar] <= 0) bufferTrend[bar] = bufferTrend[bar+1] - 1;
      else                                                     bufferTrend[bar] = Sign(bufferMACD[bar]);
   }

   // signal zero line crossing
   if (!IsSuperContext()) {
      if (signals) /*&&*/ if (EventListener.BarOpen()) {                // current timeframe
         if      (bufferTrend[1] ==  1) onZeroCross(MODE_UPPER_SECTION);
         else if (bufferTrend[1] == -1) onZeroCross(MODE_LOWER_SECTION);
      }
   }
   return(last_error);
}


/**
 * Event handler called on BarOpen if the MACD crossed the zero line.
 *
 * @param  int section
 *
 * @return bool - success status
 */
bool onZeroCross(int section) {
   string message = "";
   int    success = 0;

   if (section == MODE_UPPER_SECTION) {
      message = macd.shortName +" turned positive";
      log("onZeroCross(1)  "+ message);
      message = Symbol() +","+ PeriodDescription(Period()) +": "+ message;

      if (signal.sound) success &= _int(PlaySoundEx(signal.sound.zeroCross_plus));
      if (signal.mail)  success &= !SendEmail(signal.mail.sender, signal.mail.receiver, message, "");   // subject only (empty mail body)
      if (signal.sms)   success &= !SendSMS(signal.sms.receiver, message);
      return(success != 0);
   }

   if (section == MODE_LOWER_SECTION) {
      message = macd.shortName +" turned negative";
      log("onZeroCross(2)  "+ message);
      message = Symbol() +","+ PeriodDescription(Period()) +": "+ message;

      if (signal.sound) success &= _int(PlaySoundEx(signal.sound.zeroCross_minus));
      if (signal.mail)  success &= !SendEmail(signal.mail.sender, signal.mail.receiver, message, "");   // subject only (empty mail body)
      if (signal.sms)   success &= !SendSMS(signal.sms.receiver, message);
      return(success != 0);
   }

   return(!catch("onZeroCross(3)  invalid parameter section = "+ section, ERR_INVALID_PARAMETER));
}


/**
 * Workaround for various terminal bugs when setting indicator options. Usually options are set in init(). However after
 * recompilation options must be set in start() to not get ignored.
 */
void SetIndicatorOptions() {
   IndicatorBuffers(allocated_buffers);

   int mainType    = ifInt(MainLine.Width,        DRAW_LINE,      DRAW_NONE);
   int sectionType = ifInt(Histogram.Style.Width, DRAW_HISTOGRAM, DRAW_NONE);

   SetIndexStyle(MODE_MAIN,          mainType,    EMPTY, MainLine.Width,        MainLine.Color       );
   SetIndexStyle(MODE_TREND,         DRAW_NONE,   EMPTY, EMPTY,                 CLR_NONE             );
   SetIndexStyle(MODE_UPPER_SECTION, sectionType, EMPTY, Histogram.Style.Width, Histogram.Color.Upper);
   SetIndexStyle(MODE_LOWER_SECTION, sectionType, EMPTY, Histogram.Style.Width, Histogram.Color.Lower);
}


/**
 * Store input parameters in the chart for restauration after recompilation.
 *
 * @return bool - success status
 */
bool StoreInputParameters() {
   Chart.StoreInt   (__NAME__ +".input.Fast.MA.Periods",       Fast.MA.Periods      );
   Chart.StoreString(__NAME__ +".input.Fast.MA.Method",        Fast.MA.Method       );
   Chart.StoreString(__NAME__ +".input.Fast.MA.AppliedPrice",  Fast.MA.AppliedPrice );
   Chart.StoreInt   (__NAME__ +".input.Slow.MA.Periods",       Slow.MA.Periods      );
   Chart.StoreString(__NAME__ +".input.Slow.MA.Method",        Slow.MA.Method       );
   Chart.StoreString(__NAME__ +".input.Slow.MA.AppliedPrice",  Slow.MA.AppliedPrice );
   Chart.StoreInt   (__NAME__ +".input.MainLine.Color",        MainLine.Color       );
   Chart.StoreInt   (__NAME__ +".input.MainLine.Width",        MainLine.Width       );
   Chart.StoreInt   (__NAME__ +".input.Histogram.Color.Upper", Histogram.Color.Upper);
   Chart.StoreInt   (__NAME__ +".input.Histogram.Color.Lower", Histogram.Color.Lower);
   Chart.StoreInt   (__NAME__ +".input.Histogram.Style.Width", Histogram.Style.Width);
   Chart.StoreInt   (__NAME__ +".input.Max.Values",            Max.Values           );
   Chart.StoreString(__NAME__ +".input.Signal.onZeroCross",    Signal.onZeroCross   );
   Chart.StoreString(__NAME__ +".input.Signal.Sound",          Signal.Sound         );
   Chart.StoreString(__NAME__ +".input.Signal.Mail.Receiver",  Signal.Mail.Receiver );
   Chart.StoreString(__NAME__ +".input.Signal.SMS.Receiver",   Signal.SMS.Receiver  );
   return(!catch("StoreInputParameters(1)"));
}


/**
 * Restore input parameters found in the chart after recompilation.
 *
 * @return bool - success status
 */
bool RestoreInputParameters() {
   string label = __NAME__ +".input.Fast.MA.Periods";
   if (ObjectFind(label) == 0) {
      string sValue = StringTrim(ObjectDescription(label));
      if (!StringIsDigit(sValue))   return(!catch("RestoreInputParameters(1)  illegal chart value "+ label +" = "+ DoubleQuoteStr(ObjectDescription(label)), ERR_INVALID_CONFIG_PARAMVALUE));
      ObjectDelete(label);
      Fast.MA.Periods = StrToInteger(sValue);                     // (int) string
   }

   label = __NAME__ +".input.Fast.MA.Method";
   if (ObjectFind(label) == 0) {
      sValue = ObjectDescription(label);
      ObjectDelete(label);
      Fast.MA.Method = sValue;                                    // string
   }

   label = __NAME__ +".input.Fast.MA.AppliedPrice";
   if (ObjectFind(label) == 0) {
      sValue = ObjectDescription(label);
      ObjectDelete(label);
      Fast.MA.AppliedPrice = sValue;                              // string
   }

   label = __NAME__ +".input.Slow.MA.Periods";
   if (ObjectFind(label) == 0) {
      sValue = StringTrim(ObjectDescription(label));
      if (!StringIsDigit(sValue))   return(!catch("RestoreInputParameters(2)  illegal chart value "+ label +" = "+ DoubleQuoteStr(ObjectDescription(label)), ERR_INVALID_CONFIG_PARAMVALUE));
      ObjectDelete(label);
      Slow.MA.Periods = StrToInteger(sValue);                     // (int) string
   }

   label = __NAME__ +".input.Slow.MA.Method";
   if (ObjectFind(label) == 0) {
      sValue = ObjectDescription(label);
      ObjectDelete(label);
      Slow.MA.Method = sValue;                                    // string
   }

   label = __NAME__ +".input.Slow.MA.AppliedPrice";
   if (ObjectFind(label) == 0) {
      sValue = ObjectDescription(label);
      ObjectDelete(label);
      Slow.MA.AppliedPrice = sValue;                              // string
   }

   label = __NAME__ +".input.MainLine.Color";
   if (ObjectFind(label) == 0) {
      sValue = StringTrim(ObjectDescription(label));
      if (!StringIsInteger(sValue)) return(!catch("RestoreInputParameters(3)  illegal chart value "+ label +" = "+ DoubleQuoteStr(ObjectDescription(label)), ERR_INVALID_CONFIG_PARAMVALUE));
      int iValue = StrToInteger(sValue);
      if (iValue < CLR_NONE || iValue > C'255,255,255')
                                    return(!catch("RestoreInputParameters(4)  illegal chart value "+ label +" = "+ DoubleQuoteStr(ObjectDescription(label)) +" (0x"+ IntToHexStr(iValue) +")", ERR_INVALID_CONFIG_PARAMVALUE));
      ObjectDelete(label);
      MainLine.Color = iValue;                                    // (color)(int) string
   }

   label = __NAME__ +".input.MainLine.Width";
   if (ObjectFind(label) == 0) {
      sValue = StringTrim(ObjectDescription(label));
      if (!StringIsDigit(sValue))   return(!catch("RestoreInputParameters(5)  illegal chart value "+ label +" = "+ DoubleQuoteStr(ObjectDescription(label)), ERR_INVALID_CONFIG_PARAMVALUE));
      ObjectDelete(label);
      MainLine.Width = StrToInteger(sValue);                      // (int) string
   }

   label = __NAME__ +".input.Histogram.Color.Upper";
   if (ObjectFind(label) == 0) {
      sValue = StringTrim(ObjectDescription(label));
      if (!StringIsInteger(sValue)) return(!catch("RestoreInputParameters(6)  illegal chart value "+ label +" = "+ DoubleQuoteStr(ObjectDescription(label)), ERR_INVALID_CONFIG_PARAMVALUE));
      iValue = StrToInteger(sValue);
      if (iValue < CLR_NONE || iValue > C'255,255,255')
                                    return(!catch("RestoreInputParameters(7)  illegal chart value "+ label +" = "+ DoubleQuoteStr(ObjectDescription(label)) +" (0x"+ IntToHexStr(iValue) +")", ERR_INVALID_CONFIG_PARAMVALUE));
      ObjectDelete(label);
      Histogram.Color.Upper = iValue;                             // (color)(int) string
   }

   label = __NAME__ +".input.Histogram.Color.Lower";
   if (ObjectFind(label) == 0) {
      sValue = StringTrim(ObjectDescription(label));
      if (!StringIsInteger(sValue)) return(!catch("RestoreInputParameters(8)  illegal chart value "+ label +" = "+ DoubleQuoteStr(ObjectDescription(label)), ERR_INVALID_CONFIG_PARAMVALUE));
      iValue = StrToInteger(sValue);
      if (iValue < CLR_NONE || iValue > C'255,255,255')
                                    return(!catch("RestoreInputParameters(9)  illegal chart value "+ label +" = "+ DoubleQuoteStr(ObjectDescription(label)) +" (0x"+ IntToHexStr(iValue) +")", ERR_INVALID_CONFIG_PARAMVALUE));
      ObjectDelete(label);
      Histogram.Color.Lower = iValue;                             // (color)(int) string
   }

   label = __NAME__ +".input.Histogram.Style.Width";
   if (ObjectFind(label) == 0) {
      sValue = StringTrim(ObjectDescription(label));
      if (!StringIsDigit(sValue))   return(!catch("RestoreInputParameters(10)  illegal chart value "+ label +" = "+ DoubleQuoteStr(ObjectDescription(label)), ERR_INVALID_CONFIG_PARAMVALUE));
      ObjectDelete(label);
      Histogram.Style.Width = StrToInteger(sValue);               // (int) string
   }

   label = __NAME__ +".input.Max.Values";
   if (ObjectFind(label) == 0) {
      sValue = StringTrim(ObjectDescription(label));
      if (!StringIsInteger(sValue)) return(!catch("RestoreInputParameters(11)  illegal chart value "+ label +" = "+ DoubleQuoteStr(ObjectDescription(label)), ERR_INVALID_CONFIG_PARAMVALUE));
      ObjectDelete(label);
      Max.Values = StrToInteger(sValue);                          // (int) string
   }

   label = __NAME__ +".input.Signal.onZeroCross";
   if (ObjectFind(label) == 0) {
      sValue = ObjectDescription(label);
      ObjectDelete(label);
      Signal.onZeroCross = sValue;                                // string
   }

   label = __NAME__ +".input.Signal.Sound";
   if (ObjectFind(label) == 0) {
      sValue = ObjectDescription(label);
      ObjectDelete(label);
      Signal.Sound = sValue;                                      // string
   }

   label = __NAME__ +".input.Signal.Mail.Receiver";
   if (ObjectFind(label) == 0) {
      sValue = ObjectDescription(label);
      ObjectDelete(label);
      Signal.Mail.Receiver = sValue;                              // string
   }

   label = __NAME__ +".input.Signal.SMS.Receiver";
   if (ObjectFind(label) == 0) {
      sValue = ObjectDescription(label);
      ObjectDelete(label);
      Signal.SMS.Receiver = sValue;                               // string
   }

   return(!catch("RestoreInputParameters(12)"));
}


/**
 * Return a string representation of the input parameters. Used to log iCustom() calls.
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("input: ",

                            "Fast.MA.Periods=",       Fast.MA.Periods,                      "; ",
                            "Fast.MA.Method=",        DoubleQuoteStr(Fast.MA.Method),       "; ",
                            "Fast.MA.AppliedPrice=",  DoubleQuoteStr(Fast.MA.AppliedPrice), "; ",

                            "Slow.MA.Periods=",       Slow.MA.Periods,                      "; ",
                            "Slow.MA.Method=",        DoubleQuoteStr(Slow.MA.Method),       "; ",
                            "Slow.MA.AppliedPrice=",  DoubleQuoteStr(Slow.MA.AppliedPrice), "; ",

                            "MainLine.Color=",        ColorToStr(MainLine.Color),           "; ",
                            "MainLine.Width=",        MainLine.Width,                       "; ",

                            "Histogram.Color.Upper=", ColorToStr(Histogram.Color.Upper),    "; ",
                            "Histogram.Color.Lower=", ColorToStr(Histogram.Color.Lower),    "; ",
                            "Histogram.Style.Width=", Histogram.Style.Width,                "; ",

                            "Max.Values=",            Max.Values,                           "; ",

                            "Signal.onZeroCross=",    DoubleQuoteStr(Signal.onZeroCross),   "; ",
                            "Signal.Sound=",          DoubleQuoteStr(Signal.Sound),         "; ",
                            "Signal.Mail.Receiver=",  DoubleQuoteStr(Signal.Mail.Receiver), "; ",
                            "Signal.SMS.Receiver=",   DoubleQuoteStr(Signal.SMS.Receiver),  "; ")
   );
}
