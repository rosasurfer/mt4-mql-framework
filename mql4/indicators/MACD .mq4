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
 * Indicator buffers for use with iCustom():
 *  • MACD.MODE_MAIN:    MACD main values
 *  • MACD.MODE_TREND:   trend direction and length
 *    - trend direction: positive values represent a MACD above zero (+1...+n), negative values a MACD below zero (-1...-n)
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

extern int    Max.Values            = 3000;                 // max. number of values to display: -1 = all

extern string __________________________;

extern bool   Signal.onZeroCross    = false;
extern string Signal.Sound          = "on | off | account*";
extern string Signal.Mail.Receiver  = "system | account | auto* | off | {address}";
extern string Signal.SMS.Receiver   = "system | account | auto* | off | {phone}";

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <stdlibs.mqh>
#include <functions/@ALMA.mqh>
#include <functions/Configure.Signal.Mail.mqh>
#include <functions/Configure.Signal.SMS.mqh>
#include <functions/Configure.Signal.Sound.mqh>
#include <functions/EventListener.BarOpen.mqh>

#define MODE_MAIN           MACD.MODE_MAIN                  // indicator buffer ids
#define MODE_TREND          MACD.MODE_TREND
#define MODE_UPPER_SECTION  2
#define MODE_LOWER_SECTION  3
#define MODE_FAST_TMA_SMA   4
#define MODE_SLOW_TMA_SMA   5

#property indicator_separate_window
#property indicator_level1  0

#property indicator_buffers 4

#property indicator_width1  1
#property indicator_width2  0
#property indicator_width3  2
#property indicator_width4  2

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
   // (1) validate inputs
   // Fast.MA.Periods
   if (Fast.MA.Periods < 1)                return(catch("onInit(1)  Invalid input parameter Fast.MA.Periods = "+ Fast.MA.Periods, ERR_INVALID_INPUT_PARAMETER));
   fast.ma.periods = Fast.MA.Periods;

   // Slow.MA.Periods
   if (Slow.MA.Periods < 1)                return(catch("onInit(2)  Invalid input parameter Slow.MA.Periods = "+ Slow.MA.Periods, ERR_INVALID_INPUT_PARAMETER));
   slow.ma.periods = Slow.MA.Periods;
   if (Fast.MA.Periods >= Slow.MA.Periods) return(catch("onInit(3)  Parameter mis-match of Fast.MA.Periods/Slow.MA.Periods: "+ Fast.MA.Periods +"/"+ Slow.MA.Periods +" (fast value must be smaller than slow one)", ERR_INVALID_INPUT_PARAMETER));

   // Fast.MA.Method
   string strValue, elems[];
   if (Explode(Fast.MA.Method, "*", elems, 2) > 1) {
      int size = Explode(elems[0], "|", elems, NULL);
      strValue = elems[size-1];
   }
   else {
      strValue = StringTrim(Fast.MA.Method);
      if (strValue == "") strValue = "EMA";                             // default MA method
   }
   fast.ma.method = StrToMaMethod(strValue, F_ERR_INVALID_PARAMETER);
   if (fast.ma.method == -1)               return(catch("onInit(4)  Invalid input parameter Fast.MA.Method = "+ DoubleQuoteStr(Fast.MA.Method), ERR_INVALID_INPUT_PARAMETER));
   Fast.MA.Method = MaMethodDescription(fast.ma.method);

   // Slow.MA.Method
   if (Explode(Slow.MA.Method, "*", elems, 2) > 1) {
      size = Explode(elems[0], "|", elems, NULL);
      strValue = elems[size-1];
   }
   else {
      strValue = StringTrim(Slow.MA.Method);
      if (strValue == "") strValue = "EMA";                             // default MA method
   }
   slow.ma.method = StrToMaMethod(strValue, F_ERR_INVALID_PARAMETER);
   if (slow.ma.method == -1)               return(catch("onInit(5)  Invalid input parameter Slow.MA.Method = "+ DoubleQuoteStr(Slow.MA.Method), ERR_INVALID_INPUT_PARAMETER));
   Slow.MA.Method = MaMethodDescription(slow.ma.method);

   // Fast.MA.AppliedPrice
   if (Explode(Fast.MA.AppliedPrice, "*", elems, 2) > 1) {
      size     = Explode(elems[0], "|", elems, NULL);
      strValue = elems[size-1];
   }
   else {
      strValue = StringTrim(Fast.MA.AppliedPrice);
      if (strValue == "") strValue = "Close";                           // default price type
   }
   fast.ma.appliedPrice = StrToPriceType(strValue, F_ERR_INVALID_PARAMETER);
   if (fast.ma.appliedPrice==-1 || fast.ma.appliedPrice > PRICE_WEIGHTED)
                                           return(catch("onInit(6)  Invalid input parameter Fast.MA.AppliedPrice = "+ DoubleQuoteStr(Fast.MA.AppliedPrice), ERR_INVALID_INPUT_PARAMETER));
   Fast.MA.AppliedPrice = PriceTypeDescription(fast.ma.appliedPrice);

   // Slow.MA.AppliedPrice
   if (Explode(Slow.MA.AppliedPrice, "*", elems, 2) > 1) {
      size     = Explode(elems[0], "|", elems, NULL);
      strValue = elems[size-1];
   }
   else {
      strValue = StringTrim(Slow.MA.AppliedPrice);
      if (strValue == "") strValue = "Close";                           // default price type
   }
   slow.ma.appliedPrice = StrToPriceType(strValue, F_ERR_INVALID_PARAMETER);
   if (slow.ma.appliedPrice==-1 || slow.ma.appliedPrice > PRICE_WEIGHTED)
                                           return(catch("onInit(7)  Invalid input parameter Slow.MA.AppliedPrice = "+ DoubleQuoteStr(Slow.MA.AppliedPrice), ERR_INVALID_INPUT_PARAMETER));
   Slow.MA.AppliedPrice = PriceTypeDescription(slow.ma.appliedPrice);

   // Colors
   if (MainLine.Color        == 0xFF000000) MainLine.Color        = CLR_NONE;    // after deserialization the terminal might turn CLR_NONE (0xFFFFFFFF)
   if (Histogram.Color.Upper == 0xFF000000) Histogram.Color.Upper = CLR_NONE;    // into Black (0xFF000000)
   if (Histogram.Color.Lower == 0xFF000000) Histogram.Color.Lower = CLR_NONE;

   // Styles
   if (MainLine.Width < 1)                 return(catch("onInit(8)  Invalid input parameter MainLine.Width = "+ MainLine.Width, ERR_INVALID_INPUT_PARAMETER));
   if (MainLine.Width > 5)                 return(catch("onInit(9)  Invalid input parameter MainLine.Width = "+ MainLine.Width, ERR_INVALID_INPUT_PARAMETER));
   if (Histogram.Style.Width < 1)          return(catch("onInit(10)  Invalid input parameter Histogram.Style.Width = "+ Histogram.Style.Width, ERR_INVALID_INPUT_PARAMETER));
   if (Histogram.Style.Width > 5)          return(catch("onInit(11)  Invalid input parameter Histogram.Style.Width = "+ Histogram.Style.Width, ERR_INVALID_INPUT_PARAMETER));

   // Max.Values
   if (Max.Values < -1)                    return(catch("onInit(12)  Invalid input parameter Max.Values = "+ Max.Values, ERR_INVALID_INPUT_PARAMETER));

   // Signals
   if (Signal.onZeroCross) {
      if (!Configure.Signal.Sound(Signal.Sound,         signal.sound                                         )) return(last_error);
      if (!Configure.Signal.Mail (Signal.Mail.Receiver, signal.mail, signal.mail.sender, signal.mail.receiver)) return(last_error);
      if (!Configure.Signal.SMS  (Signal.SMS.Receiver,  signal.sms,                      signal.sms.receiver )) return(last_error);
      //log("onInit(13)  Signal.onZeroCross="+ Signal.onZeroCross +"  Sound="+ signal.sound +"  Mail="+ ifString(signal.mail, signal.mail.receiver, "0") +"  SMS="+ ifString(signal.sms, signal.sms.receiver, "0"));
   }


   // (2) setup buffer management
   IndicatorBuffers(6);
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
   SetIndicatorStyles();


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

   return(catch("onInit(14)"));
}


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   // check for finished buffer initialization
   if (!ArraySize(bufferMACD))                                          // can happen on terminal start
      return(debug("onTick(1)  size(bufferMACD) = 0", SetLastError(ERS_TERMINAL_NOT_YET_READY)));

   // reset all buffers and delete garbage behind Max.Values before doing a full recalculation
   if (!ValidBars) {
      ArrayInitialize(bufferMACD,         EMPTY_VALUE);
      ArrayInitialize(bufferTrend,                  0);
      ArrayInitialize(bufferUpper,        EMPTY_VALUE);
      ArrayInitialize(bufferLower,        EMPTY_VALUE);
      ArrayInitialize(fast.tma.bufferSMA, EMPTY_VALUE);
      ArrayInitialize(slow.tma.bufferSMA, EMPTY_VALUE);
      SetIndicatorStyles();                                             // fix for various terminal bugs
   }

   // synchronize buffers with a shifted offline chart (if applicable)
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
      if (Signal.onZeroCross) /*&&*/ if (EventListener.BarOpen()) {     // current timeframe
         if      (bufferTrend[1] ==  1) onZeroCross(MODE_UPPER_SECTION);
         else if (bufferTrend[1] == -1) onZeroCross(MODE_LOWER_SECTION);
      }
   }
   return(last_error);
}


/**
 * Event handler, called on BarOpen if the MACD crossed the zero line.
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
      log("onCross(1)  "+ message);
      message = Symbol() +","+ PeriodDescription(Period()) +": "+ message;

      if (signal.sound) success &= _int(PlaySoundEx(signal.sound.zeroCross_plus));
      if (signal.mail)  success &= !SendEmail(signal.mail.sender, signal.mail.receiver, message, "");   // subject only (empty mail body)
      if (signal.sms)   success &= !SendSMS(signal.sms.receiver, message);
      return(success != 0);
   }

   if (section == MODE_LOWER_SECTION) {
      message = macd.shortName +" turned negative";
      log("onCross(2)  "+ message);
      message = Symbol() +","+ PeriodDescription(Period()) +": "+ message;

      if (signal.sound) success &= _int(PlaySoundEx(signal.sound.zeroCross_minus));
      if (signal.mail)  success &= !SendEmail(signal.mail.sender, signal.mail.receiver, message, "");   // subject only (empty mail body)
      if (signal.sms)   success &= !SendSMS(signal.sms.receiver, message);
      return(success != 0);
   }

   return(!catch("onCross(3)  invalid parameter section = "+ section, ERR_INVALID_PARAMETER));
}


/**
 * Set indicator styles. Workaround for various terminal bugs when setting styles. Usually styles are applied in init().
 * However after recompilation styles must be applied in start() to not get lost.
 */
void SetIndicatorStyles() {
   SetIndexStyle(MODE_MAIN,          DRAW_LINE,      EMPTY, MainLine.Width,        MainLine.Color       );
   SetIndexStyle(MODE_TREND,         DRAW_NONE,      EMPTY, EMPTY,                 CLR_NONE             );
   SetIndexStyle(MODE_UPPER_SECTION, DRAW_HISTOGRAM, EMPTY, Histogram.Style.Width, Histogram.Color.Upper);
   SetIndexStyle(MODE_LOWER_SECTION, DRAW_HISTOGRAM, EMPTY, Histogram.Style.Width, Histogram.Color.Lower);
}


/**
 * Return a string representation of the input parameters. Used when logging iCustom() calls.
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

                            "Signal.onZeroCross=",    BoolToStr(Signal.onZeroCross),        "; ",
                            "Signal.Sound=",          DoubleQuoteStr(Signal.Sound),         "; ",
                            "Signal.Mail.Receiver=",  DoubleQuoteStr(Signal.Mail.Receiver), "; ",
                            "Signal.SMS.Receiver=",   DoubleQuoteStr(Signal.SMS.Receiver),  "; ")
   );
}
