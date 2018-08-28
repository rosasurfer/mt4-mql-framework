/**
 * MACD (Moving Average Convergence-Divergence)
 *
 *
 * Available Moving Average types:
 *  • SMA  - Simple Moving Average:          equal bar weighting
 *  • LWMA - Linear Weighted Moving Average: bar weighting using a linear function
 *  • EMA  - Exponential Moving Average:     bar weighting using an exponential function
 *  • ALMA - Arnaud Legoux Moving Average:   bar weighting using a Gaussian function
 *
 * The Smoothed Moving Average (SMMA) is omitted as it's just an EMA of a different period: SMMA(n) = EMA(2*n-1)
 *
 *
 * Indicator buffers to use with iCustom():
 *  • MACD.MODE_MAIN:      MACD main values
 *  • MACD.MODE_DIRECTION: MACD direction and section length since last crossing of the zero level
 *    - direction: positive values denote a MACD above zero (+1...+n), negative values a MACD below zero (-1...-n)
 *    - length:    the absolute value is the histogram section length (bars since the last crossing of zero)
 *
 *
 * Note: The file is intentionally named "MACD .mql" as a file "MACD.mql" would be overwritten by newer terminal versions.
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern int    Fast.MA.Periods       = 12;
extern string Fast.MA.Method        = "SMA | LWMA | EMA | ALMA*";
extern string Fast.MA.AppliedPrice  = "Open | High | Low | Close* | Median | Typical | Weighted";

extern int    Slow.MA.Periods       = 38;
extern string Slow.MA.Method        = "SMA | LWMA | EMA | ALMA*";
extern string Slow.MA.AppliedPrice  = "Open | High | Low | Close* | Median | Typical | Weighted";

extern color  MainLine.Color        = DodgerBlue;           // indicator style management in MQL
extern int    MainLine.Width        = 1;

extern color  Histogram.Color.Upper = LimeGreen;
extern color  Histogram.Color.Lower = Red;
extern int    Histogram.Style.Width = 2;

extern int    Max.Values            = 5000;                 // max. number of values to display: -1 = all

extern string __________________________;

extern string Signal.onCross        = "auto* | off | on";
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
#define MODE_DIRECTION        MACD.MODE_DIRECTION
#define MODE_UPPER_SECTION    2
#define MODE_LOWER_SECTION    3

#property indicator_separate_window
#property indicator_buffers   4                             // configurable buffers (input dialog)
int       allocated_buffers = 4;                            // used buffers
#property indicator_level1    0

double bufferMACD     [];                                   // MACD main value:           visible, displayed in "Data" window
double bufferDirection[];                                   // MACD direction and length: invisible
double bufferUpper    [];                                   // positive histogram values: visible
double bufferLower    [];                                   // negative histogram values: visible

int    fast.ma.periods;
int    fast.ma.method;
int    fast.ma.appliedPrice;
double fast.alma.weights[];                                 // fast ALMA weights

int    slow.ma.periods;
int    slow.ma.method;
int    slow.ma.appliedPrice;
double slow.alma.weights[];                                 // slow ALMA weights

string ind.shortName;                                       // "Data" window and signal notification name

bool   signals;

bool   signal.sound;
string signal.sound.crossUp   = "Signal-Up.wav";
string signal.sound.crossDown = "Signal-Down.wav";

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
   if (!Configure.Signal("MACD", Signal.onCross, signals))                                                      return(last_error);
   if (signals) {
      if (!Configure.Signal.Sound(Signal.Sound,         signal.sound                                         )) return(last_error);
      if (!Configure.Signal.Mail (Signal.Mail.Receiver, signal.mail, signal.mail.sender, signal.mail.receiver)) return(last_error);
      if (!Configure.Signal.SMS  (Signal.SMS.Receiver,  signal.sms,                      signal.sms.receiver )) return(last_error);
      if (!signal.sound && !signal.mail && !signal.sms)
         signals = false;
   }


   // (2) setup buffer management
   SetIndexBuffer(MODE_MAIN,          bufferMACD        );              // MACD main value:              visible, displayed in "Data" window
   SetIndexBuffer(MODE_DIRECTION,     bufferDirection   );              // MACD direction and length:    invisible
   SetIndexBuffer(MODE_UPPER_SECTION, bufferUpper       );              // positive values:              visible
   SetIndexBuffer(MODE_LOWER_SECTION, bufferLower       );              // negative values:              visible


   // (3) data display configuration and names
   string ind.dataName, strAppliedPrice="";
   if (fast.ma.appliedPrice != PRICE_CLOSE) strAppliedPrice = ","+ PriceTypeDescription(fast.ma.appliedPrice);
   string fast.ma.name = Fast.MA.Method +"("+ fast.ma.periods + strAppliedPrice +")";
   strAppliedPrice = "";
   if (slow.ma.appliedPrice != PRICE_CLOSE) strAppliedPrice = ","+ PriceTypeDescription(slow.ma.appliedPrice);
   string slow.ma.name = Slow.MA.Method +"("+ slow.ma.periods + strAppliedPrice +")";

   if (Fast.MA.Method==Slow.MA.Method && fast.ma.appliedPrice==slow.ma.appliedPrice) ind.shortName = "MACD "+ Fast.MA.Method +"("+ fast.ma.periods +","+ slow.ma.periods + strAppliedPrice +")";
   else                                                                              ind.shortName = "MACD "+ fast.ma.name +", "+ slow.ma.name;
   if (Fast.MA.Method==Slow.MA.Method)                                               ind.dataName  = "MACD "+ Fast.MA.Method +"("+ fast.ma.periods +","+ slow.ma.periods +")";
   else                                                                              ind.dataName  = "MACD "+ Fast.MA.Method +"("+ fast.ma.periods +"), "+ Slow.MA.Method +"("+ slow.ma.periods +")";
   string signalInfo = ifString(signals, "  onCross="+ StringLeft(ifString(signal.sound, "Sound,", "") + ifString(signal.mail,  "Mail,",  "") + ifString(signal.sms, "SMS,", ""), -1), "");

   // names and labels
   IndicatorShortName(ind.shortName + signalInfo +"  ");                // indicator subwindow and context menu
   SetIndexLabel(MODE_MAIN,          ind.dataName);                     // "Data" window and tooltips
   SetIndexLabel(MODE_DIRECTION,     NULL);
   SetIndexLabel(MODE_UPPER_SECTION, NULL);
   SetIndexLabel(MODE_LOWER_SECTION, NULL);
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
   if (fast.ma.method == MODE_ALMA) @ALMA.CalculateWeights(fast.alma.weights, fast.ma.periods);
   if (slow.ma.method == MODE_ALMA) @ALMA.CalculateWeights(slow.alma.weights, slow.ma.periods);

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
   // check for finished buffer initialization (needed on terminal start)
   if (!ArraySize(bufferMACD))
      return(log("onTick(1)  size(bufferMACD) = 0", SetLastError(ERS_TERMINAL_NOT_YET_READY)));

   // reset all buffers and delete garbage behind Max.Values before doing a full recalculation
   if (!ValidBars) {
      ArrayInitialize(bufferMACD,      EMPTY_VALUE);
      ArrayInitialize(bufferDirection,           0);
      ArrayInitialize(bufferUpper,     EMPTY_VALUE);
      ArrayInitialize(bufferLower,     EMPTY_VALUE);
      SetIndicatorOptions();
   }

   // synchronize buffers with a shifted offline chart
   if (ShiftedBars > 0) {
      ShiftIndicatorBuffer(bufferMACD,      Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(bufferDirection, Bars, ShiftedBars,           0);
      ShiftIndicatorBuffer(bufferUpper,     Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(bufferLower,     Bars, ShiftedBars, EMPTY_VALUE);
   }


   // (1) calculate start bar
   int changedBars = ChangedBars;
   if (Max.Values >= 0) /*&&*/ if (ChangedBars > Max.Values)
      changedBars = Max.Values;
   int startBar = Min(changedBars-1, Bars-slow.ma.periods);
   if (startBar < 0) return(catch("onTick(2)", ERR_HISTORY_INSUFFICIENT));


   double fast.ma, slow.ma;


   // (2) recalculate invalid bars
   for (int bar=startBar; bar >= 0; bar--) {
      // fast MA
      if (fast.ma.method == MODE_ALMA) {
         fast.ma = 0;
         for (int i=0; i < fast.ma.periods; i++) {
            fast.ma += fast.alma.weights[i] * iMA(NULL, NULL, 1, 0, MODE_SMA, fast.ma.appliedPrice, bar+i);
         }
      }
      else {
         fast.ma = iMA(NULL, NULL, fast.ma.periods, 0, fast.ma.method, fast.ma.appliedPrice, bar);
      }

      // slow MA
      if (slow.ma.method == MODE_ALMA) {
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
      if      (bufferDirection[bar+1] > 0 && bufferMACD[bar] >= 0) bufferDirection[bar] = bufferDirection[bar+1] + 1;
      else if (bufferDirection[bar+1] < 0 && bufferMACD[bar] <= 0) bufferDirection[bar] = bufferDirection[bar+1] - 1;
      else                                                         bufferDirection[bar] = Sign(bufferMACD[bar]);
   }

   // signal zero line crossing
   if (!IsSuperContext()) {
      if (signals) /*&&*/ if (EventListener.BarOpen()) {                // current timeframe
         if      (bufferDirection[1] ==  1) onCross(MODE_UPPER_SECTION);
         else if (bufferDirection[1] == -1) onCross(MODE_LOWER_SECTION);
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
bool onCross(int section) {
   string message = "";
   int    success = 0;

   if (section == MODE_UPPER_SECTION) {
      message = ind.shortName +" turned positive";
      log("onCross(1)  "+ message);
      message = Symbol() +","+ PeriodDescription(Period()) +": "+ message;

      if (signal.sound) success &= _int(PlaySoundEx(signal.sound.crossUp));
      if (signal.mail)  success &= !SendEmail(signal.mail.sender, signal.mail.receiver, message, "");   // subject only (empty mail body)
      if (signal.sms)   success &= !SendSMS(signal.sms.receiver, message);
      return(success != 0);
   }

   if (section == MODE_LOWER_SECTION) {
      message = ind.shortName +" turned negative";
      log("onCross(2)  "+ message);
      message = Symbol() +","+ PeriodDescription(Period()) +": "+ message;

      if (signal.sound) success &= _int(PlaySoundEx(signal.sound.crossDown));
      if (signal.mail)  success &= !SendEmail(signal.mail.sender, signal.mail.receiver, message, "");   // subject only (empty mail body)
      if (signal.sms)   success &= !SendSMS(signal.sms.receiver, message);
      return(success != 0);
   }

   return(!catch("onCross(3)  invalid parameter section = "+ section, ERR_INVALID_PARAMETER));
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
   SetIndexStyle(MODE_DIRECTION,     DRAW_NONE,   EMPTY, EMPTY,                 CLR_NONE             );
   SetIndexStyle(MODE_UPPER_SECTION, sectionType, EMPTY, Histogram.Style.Width, Histogram.Color.Upper);
   SetIndexStyle(MODE_LOWER_SECTION, sectionType, EMPTY, Histogram.Style.Width, Histogram.Color.Lower);
}


/**
 * Store input parameters in the chart before recompilation.
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
   Chart.StoreColor (__NAME__ +".input.MainLine.Color",        MainLine.Color       );
   Chart.StoreInt   (__NAME__ +".input.MainLine.Width",        MainLine.Width       );
   Chart.StoreColor (__NAME__ +".input.Histogram.Color.Upper", Histogram.Color.Upper);
   Chart.StoreColor (__NAME__ +".input.Histogram.Color.Lower", Histogram.Color.Lower);
   Chart.StoreInt   (__NAME__ +".input.Histogram.Style.Width", Histogram.Style.Width);
   Chart.StoreInt   (__NAME__ +".input.Max.Values",            Max.Values           );
   Chart.StoreString(__NAME__ +".input.Signal.onCross",        Signal.onCross       );
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
   Chart.RestoreInt   ("Fast.MA.Periods",       Fast.MA.Periods      );
   Chart.RestoreString("Fast.MA.Method",        Fast.MA.Method       );
   Chart.RestoreString("Fast.MA.AppliedPrice",  Fast.MA.AppliedPrice );
   Chart.RestoreInt   ("Slow.MA.Periods",       Slow.MA.Periods      );
   Chart.RestoreString("Slow.MA.Method",        Slow.MA.Method       );
   Chart.RestoreString("Slow.MA.AppliedPrice",  Slow.MA.AppliedPrice );
   Chart.RestoreColor ("MainLine.Color",        MainLine.Color       );
   Chart.RestoreInt   ("MainLine.Width",        MainLine.Width       );
   Chart.RestoreColor ("Histogram.Color.Upper", Histogram.Color.Upper);
   Chart.RestoreColor ("Histogram.Color.Lower", Histogram.Color.Lower);
   Chart.RestoreInt   ("Histogram.Style.Width", Histogram.Style.Width);
   Chart.RestoreInt   ("Max.Values",            Max.Values           );
   Chart.RestoreString("Signal.onCross",        Signal.onCross       );
   Chart.RestoreString("Signal.Sound",          Signal.Sound         );
   Chart.RestoreString("Signal.Mail.Receiver",  Signal.Mail.Receiver );
   Chart.RestoreString("Signal.SMS.Receiver",   Signal.SMS.Receiver  );
   return(!catch("RestoreInputParameters(1)"));
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

                            "Signal.onCross=",        DoubleQuoteStr(Signal.onCross),       "; ",
                            "Signal.Sound=",          DoubleQuoteStr(Signal.Sound),         "; ",
                            "Signal.Mail.Receiver=",  DoubleQuoteStr(Signal.Mail.Receiver), "; ",
                            "Signal.SMS.Receiver=",   DoubleQuoteStr(Signal.SMS.Receiver),  "; ")
   );
}
