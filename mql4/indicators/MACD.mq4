/**
 * A MACD indicator with support for different "Moving Average" methods and additional features.
 *
 *
 * Moving Average types:
 *  • SMA  - Simple Moving Average:          equal bar weighting
 *  • LWMA - Linear Weighted Moving Average: bar weighting using a linear function
 *  • EMA  - Exponential Moving Average:     bar weighting using an exponential function
 *  • SMMA - Smoothed Moving Average:        bar weighting using an exponential function (an EMA, see notes)
 *  • ALMA - Arnaud Legoux Moving Average:   bar weighting using a Gaussian function
 *
 *
 * Indicator buffers for iCustom():
 *  • MACD.MODE_MAIN:    MACD main value
 *  • MACD.MODE_SECTION: MACD section and section length since last crossing of the zero level
 *    - section: positive values denote a MACD above zero (+1...+n), negative values a MACD below zero (-1...-n)
 *    - length:  the absolute value is the histogram section length (bars since the last crossing of zero)
 *
 *
 * Notes: The SMMA is in fact an EMA with a different period. It holds: SMMA(n) = EMA(2*n-1)
 *        @see  https://web.archive.org/web/20221120050520/https://en.wikipedia.org/wiki/Moving_average#Modified_moving_average
 */
#include <stddefines.mqh>
int   __InitFlags[];
int __DeinitFlags[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern int    FastMA.Periods                 = 12;
extern string FastMA.Method                  = "SMA | LWMA | EMA* | SMMA| ALMA";
extern string FastMA.AppliedPrice            = "Open | High | Low | Close* | Median | Typical | Weighted";

extern int    SlowMA.Periods                 = 26;
extern string SlowMA.Method                  = "SMA | LWMA | EMA | ALMA*";
extern string SlowMA.AppliedPrice            = "Open | High | Low | Close* | Median | Typical | Weighted";

extern color  Histogram.Color.Upper          = LimeGreen;
extern color  Histogram.Color.Lower          = Red;
extern int    Histogram.Style.Width          = 2;

extern color  MainLine.Color                 = DodgerBlue;
extern int    MainLine.Width                 = 1;
extern int    MaxBarsBack                    = 10000;                // max. values to calculate (-1: all available)

extern string ___a__________________________ = "=== Signaling ===";
extern bool   Signal.onCross                 = false;
extern string Signal.onCross.Types           = "sound* | alert | mail | sms";
extern string Signal.Sound.Up                = "Signal Up.wav";
extern string Signal.Sound.Down              = "Signal Down.wav";

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <rsfLib.mqh>
#include <functions/ConfigureSignals.mqh>
#include <functions/IsBarOpen.mqh>
#include <functions/iCustom/MACD.mqh>
#include <functions/ta/ALMA.mqh>
#include <win32api.mqh>

#define MODE_MAIN             MACD.MODE_MAIN                // indicator buffer ids
#define MODE_SECTION          MACD.MODE_SECTION
#define MODE_UPPER_SECTION    2
#define MODE_LOWER_SECTION    3

#property indicator_separate_window
#property indicator_buffers   4

#property indicator_color1    CLR_NONE
#property indicator_color2    CLR_NONE
#property indicator_color3    CLR_NONE
#property indicator_color4    CLR_NONE

#property indicator_level1    0

double bufferMACD   [];                                     // MACD main value:           visible, displayed in "Data" window
double bufferSection[];                                     // MACD section and length:   invisible
double bufferUpper  [];                                     // positive histogram values: visible
double bufferLower  [];                                     // negative histogram values: visible

int    fastMA.periods;
int    fastMA.method;
int    fastMA.appliedPrice;
double fastALMA.weights[];                                  // fast ALMA weights

int    slowMA.periods;
int    slowMA.method;
int    slowMA.appliedPrice;
double slowALMA.weights[];                                  // slow ALMA weights

string indicatorName = "";                                  // "Data" window and signal notification name

bool   signal.sound;
bool   signal.alert;
bool   signal.mail;
bool   signal.sms;


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   // validate inputs
   string indicator = WindowExpertName();

   // FastMA.Periods
   if (AutoConfiguration) FastMA.Periods = GetConfigInt(indicator, "FastMA.Periods", FastMA.Periods);
   if (FastMA.Periods < 1)              return(catch("onInit(1)  invalid input parameter FastMA.Periods: "+ FastMA.Periods, ERR_INVALID_INPUT_PARAMETER));
   fastMA.periods = FastMA.Periods;
   // FastMA.Method
   string values[], sValue = FastMA.Method;
   if (AutoConfiguration) sValue = GetConfigString(indicator, "FastMA.Method", sValue);
   if (Explode(sValue, "*", values, 2) > 1) {
      int size = Explode(values[0], "|", values, NULL);
      sValue = values[size-1];
   }
   fastMA.method = StrToMaMethod(sValue, F_PARTIAL_ID|F_ERR_INVALID_PARAMETER);
   if (fastMA.method == -1)             return(catch("onInit(2)  invalid input parameter FastMA.Method: "+ DoubleQuoteStr(FastMA.Method), ERR_INVALID_INPUT_PARAMETER));
   FastMA.Method = MaMethodDescription(fastMA.method);
   // FastMA.AppliedPrice
   sValue = FastMA.AppliedPrice;
   if (AutoConfiguration) sValue = GetConfigString(indicator, "FastMA.AppliedPrice", sValue);
   if (Explode(sValue, "*", values, 2) > 1) {
      size = Explode(values[0], "|", values, NULL);
      sValue = values[size-1];
   }
   sValue = StrTrim(sValue);
   if (sValue == "") sValue = "close";                                  // default price type
   fastMA.appliedPrice = StrToPriceType(sValue, F_PARTIAL_ID|F_ERR_INVALID_PARAMETER);
   if (fastMA.appliedPrice == -1)       return(catch("onInit(3)  invalid input parameter FastMA.AppliedPrice: "+ DoubleQuoteStr(FastMA.AppliedPrice), ERR_INVALID_INPUT_PARAMETER));
   FastMA.AppliedPrice = PriceTypeDescription(fastMA.appliedPrice);
   // SlowMA.Periods
   if (AutoConfiguration) SlowMA.Periods = GetConfigInt(indicator, "SlowMA.Periods", SlowMA.Periods);
   if (SlowMA.Periods < 1)              return(catch("onInit(4)  invalid input parameter SlowMA.Periods: "+ SlowMA.Periods, ERR_INVALID_INPUT_PARAMETER));
   slowMA.periods = SlowMA.Periods;
   if (FastMA.Periods > SlowMA.Periods) return(catch("onInit(5)  parameter mis-match of FastMA.Periods/SlowMA.Periods: "+ FastMA.Periods +"/"+ SlowMA.Periods +" (fast value must be smaller than slow one)", ERR_INVALID_INPUT_PARAMETER));
   if (fastMA.periods == slowMA.periods) {
      if (fastMA.method == slowMA.method) {
         if (fastMA.appliedPrice == slowMA.appliedPrice) {
            return(catch("onInit(6)  parameter mis-match (fast MA must differ from slow MA)", ERR_INVALID_INPUT_PARAMETER));
         }
      }
   }
   // SlowMA.Method
   sValue = SlowMA.Method;
   if (AutoConfiguration) sValue = GetConfigString(indicator, "SlowMA.Method", sValue);
   if (Explode(sValue, "*", values, 2) > 1) {
      size = Explode(values[0], "|", values, NULL);
      sValue = values[size-1];
   }
   slowMA.method = StrToMaMethod(sValue, F_PARTIAL_ID|F_ERR_INVALID_PARAMETER);
   if (slowMA.method == -1)             return(catch("onInit(7)  invalid input parameter SlowMA.Method: "+ DoubleQuoteStr(SlowMA.Method), ERR_INVALID_INPUT_PARAMETER));
   SlowMA.Method = MaMethodDescription(slowMA.method);
   // SlowMA.AppliedPrice
   sValue = SlowMA.AppliedPrice;
   if (AutoConfiguration) sValue = GetConfigString(indicator, "SlowMA.AppliedPrice", sValue);
   if (Explode(sValue, "*", values, 2) > 1) {
      size = Explode(values[0], "|", values, NULL);
      sValue = values[size-1];
   }
   sValue = StrTrim(sValue);
   if (sValue == "") sValue = "close";                                  // default price type
   slowMA.appliedPrice = StrToPriceType(sValue, F_PARTIAL_ID|F_ERR_INVALID_PARAMETER);
   if (slowMA.appliedPrice == -1)       return(catch("onInit(8)  invalid input parameter SlowMA.AppliedPrice: "+ DoubleQuoteStr(SlowMA.AppliedPrice), ERR_INVALID_INPUT_PARAMETER));
   SlowMA.AppliedPrice = PriceTypeDescription(slowMA.appliedPrice);
   // colors: after deserialization the terminal might turn CLR_NONE (0xFFFFFFFF) into Black (0xFF000000)
   if (AutoConfiguration) Histogram.Color.Upper = GetConfigColor(indicator, "Histogram.Color.Upper", Histogram.Color.Upper);
   if (AutoConfiguration) Histogram.Color.Lower = GetConfigColor(indicator, "Histogram.Color.Lower", Histogram.Color.Lower);
   if (AutoConfiguration) MainLine.Color        = GetConfigColor(indicator, "MainLine.Color",        MainLine.Color);
   if (Histogram.Color.Upper == 0xFF000000) Histogram.Color.Upper = CLR_NONE;
   if (Histogram.Color.Lower == 0xFF000000) Histogram.Color.Lower = CLR_NONE;
   if (MainLine.Color        == 0xFF000000) MainLine.Color        = CLR_NONE;
   // Histogram.Style.Width
   if (AutoConfiguration) Histogram.Style.Width = GetConfigInt(indicator, "Histogram.Style.Width", Histogram.Style.Width);
   if (Histogram.Style.Width < 0)       return(catch("onInit(9)  invalid input parameter Histogram.Style.Width: "+ Histogram.Style.Width +" (valid range: 0-5)", ERR_INVALID_INPUT_PARAMETER));
   if (Histogram.Style.Width > 5)       return(catch("onInit(10)  invalid input parameter Histogram.Style.Width: "+ Histogram.Style.Width +" (valid range: 0-5)", ERR_INVALID_INPUT_PARAMETER));
   // MainLine.Width
   if (AutoConfiguration) MainLine.Width = GetConfigInt(indicator, "MainLine.Width", MainLine.Width);
   if (MainLine.Width < 0)              return(catch("onInit(11)  invalid input parameter MainLine.Width: "+ MainLine.Width +" (must be non-negative)", ERR_INVALID_INPUT_PARAMETER));
   // MaxBarsBack
   if (AutoConfiguration) MaxBarsBack = GetConfigInt(indicator, "MaxBarsBack", MaxBarsBack);
   if (MaxBarsBack < -1)                return(catch("onInit(12)  invalid input parameter MaxBarsBack: "+ MaxBarsBack, ERR_INVALID_INPUT_PARAMETER));
   if (MaxBarsBack == -1) MaxBarsBack = INT_MAX;

   // signal configuration
   string signalId = "Signal.onCross", signalInfo = "";
   if (!ConfigureSignals(signalId, AutoConfiguration, Signal.onCross)) return(last_error);
   if (Signal.onCross) {
      if (!ConfigureSignalTypes(signalId, Signal.onCross.Types, AutoConfiguration, signal.sound, signal.alert, signal.mail, signal.sms)) {
         return(catch("onInit(13)  invalid input parameter Signal.onCross.Types: "+ DoubleQuoteStr(Signal.onCross.Types), ERR_INVALID_INPUT_PARAMETER));
      }
      Signal.onCross = (signal.sound || signal.alert || signal.mail || signal.sms);
      if (Signal.onCross) signalInfo = "  onCross="+ StrLeft(ifString(signal.sound, "sound,", "") + ifString(signal.alert, "alert,", "") + ifString(signal.mail, "mail,", "") + ifString(signal.sms, "sms,", ""), -1);
   }
   // Signal.Sound.*
   if (AutoConfiguration) Signal.Sound.Up   = GetConfigString(indicator, "Signal.Sound.Up",   Signal.Sound.Up);
   if (AutoConfiguration) Signal.Sound.Down = GetConfigString(indicator, "Signal.Sound.Down", Signal.Sound.Down);

   // buffer management
   SetIndexBuffer(MODE_MAIN,          bufferMACD   );                   // MACD main value:         visible, displayed in "Data" window
   SetIndexBuffer(MODE_SECTION,       bufferSection);                   // MACD section and length: invisible
   SetIndexBuffer(MODE_UPPER_SECTION, bufferUpper  );                   // positive values:         visible
   SetIndexBuffer(MODE_LOWER_SECTION, bufferLower  );                   // negative values:         visible

   // display options, names and labels
   string dataName="", sAppliedPrice="";
   if (fastMA.appliedPrice!=slowMA.appliedPrice || fastMA.appliedPrice!=PRICE_CLOSE) sAppliedPrice = ","+ PriceTypeDescription(fastMA.appliedPrice);
   string fastMA.name = FastMA.Method +"("+ fastMA.periods + sAppliedPrice +")";
   sAppliedPrice = "";
   if (fastMA.appliedPrice!=slowMA.appliedPrice || slowMA.appliedPrice!=PRICE_CLOSE) sAppliedPrice = ","+ PriceTypeDescription(slowMA.appliedPrice);
   string slowMA.name = SlowMA.Method +"("+ slowMA.periods + sAppliedPrice +")";

   if (FastMA.Method==SlowMA.Method && fastMA.appliedPrice==slowMA.appliedPrice) indicatorName = WindowExpertName() +" "+ FastMA.Method +"("+ fastMA.periods +","+ slowMA.periods + sAppliedPrice +")";
   else                                                                          indicatorName = WindowExpertName() +" "+ fastMA.name +", "+ slowMA.name;
   if (FastMA.Method==SlowMA.Method)                                             dataName      = WindowExpertName() +" "+ FastMA.Method +"("+ fastMA.periods +","+ slowMA.periods +")";
   else                                                                          dataName      = WindowExpertName() +" "+ FastMA.Method +"("+ fastMA.periods +"), "+ SlowMA.Method +"("+ slowMA.periods +")";

   IndicatorShortName(indicatorName + signalInfo +"  ");                // chart subwindow and context menu
   SetIndexLabel(MODE_MAIN,          dataName);                         // chart tooltips and "Data" window
   SetIndexLabel(MODE_SECTION,       NULL);
   SetIndexLabel(MODE_UPPER_SECTION, NULL);
   SetIndexLabel(MODE_LOWER_SECTION, NULL);
   IndicatorDigits(pDigits + 1);
   SetIndicatorOptions();

   // calculate ALMA bar weights
   double almaOffset=0.85, almaSigma=6.0;
   if (fastMA.method == MODE_ALMA) ALMA.CalculateWeights(fastMA.periods, almaOffset, almaSigma, fastALMA.weights);
   if (slowMA.method == MODE_ALMA) ALMA.CalculateWeights(slowMA.periods, almaOffset, almaSigma, slowALMA.weights);

   return(catch("onInit(14)"));
}


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   // on the first tick after terminal start buffers may not yet be initialized (spurious issue)
   if (!ArraySize(bufferMACD)) return(logInfo("onTick(1)  sizeof(bufferMACD) = 0", SetLastError(ERS_TERMINAL_NOT_YET_READY)));

   // reset buffers before performing a full recalculation
   if (!ValidBars) {
      ArrayInitialize(bufferMACD,  EMPTY_VALUE);
      ArrayInitialize(bufferSection,         0);
      ArrayInitialize(bufferUpper, EMPTY_VALUE);
      ArrayInitialize(bufferLower, EMPTY_VALUE);
      SetIndicatorOptions();
   }

   // synchronize buffers with a shifted offline chart
   if (ShiftedBars > 0) {
      ShiftDoubleIndicatorBuffer(bufferMACD,    Bars, ShiftedBars, EMPTY_VALUE);
      ShiftDoubleIndicatorBuffer(bufferSection, Bars, ShiftedBars,           0);
      ShiftDoubleIndicatorBuffer(bufferUpper,   Bars, ShiftedBars, EMPTY_VALUE);
      ShiftDoubleIndicatorBuffer(bufferLower,   Bars, ShiftedBars, EMPTY_VALUE);
   }

   // calculate start bar
   int startbar = Min(MaxBarsBack-1, ChangedBars-1, Bars-slowMA.periods);
   if (startbar < 0 && MaxBarsBack) return(logInfo("onTick(2)  Tick="+ Ticks, ERR_HISTORY_INSUFFICIENT));

   // recalculate changed bars
   double fastMA, slowMA;

   for (int bar=startbar; bar >= 0; bar--) {
      // fast MA
      if (fastMA.method == MODE_ALMA) {
         fastMA = 0;
         for (int i=0; i < fastMA.periods; i++) {
            fastMA += fastALMA.weights[i] * iMA(NULL, NULL, 1, 0, MODE_SMA, fastMA.appliedPrice, bar+i);
         }
      }
      else {
         fastMA = iMA(NULL, NULL, fastMA.periods, 0, fastMA.method, fastMA.appliedPrice, bar);
      }

      // slow MA
      if (slowMA.method == MODE_ALMA) {
         slowMA = 0;
         for (i=0; i < slowMA.periods; i++) {
            slowMA += slowALMA.weights[i] * iMA(NULL, NULL, 1, 0, MODE_SMA, slowMA.appliedPrice, bar+i);
         }
      }
      else {
         slowMA = iMA(NULL, NULL, slowMA.periods, 0, slowMA.method, slowMA.appliedPrice, bar);
      }

      // final MACD
      bufferMACD[bar] = (fastMA - slowMA)/pUnit;

      if (bufferMACD[bar] > 0) {
         bufferUpper[bar] = bufferMACD[bar];
         bufferLower[bar] = EMPTY_VALUE;
      }
      else {
         bufferUpper[bar] = EMPTY_VALUE;
         bufferLower[bar] = bufferMACD[bar];
      }

      // update section length (duration)
      if      (bufferSection[bar+1] > 0 && bufferMACD[bar] >= 0) bufferSection[bar] = bufferSection[bar+1] + 1;
      else if (bufferSection[bar+1] < 0 && bufferMACD[bar] <= 0) bufferSection[bar] = bufferSection[bar+1] - 1;
      else                                                       bufferSection[bar] = Sign(bufferMACD[bar]);
   }

   // detect zero line crossings
   if (!__isSuperContext) {
      if (Signal.onCross) /*&&*/ if (IsBarOpen()) {
         static int lastSide; if (!lastSide) lastSide = bufferSection[2];
         int side = bufferSection[1];
         if      (lastSide<=0 && side > 0) onCross(MODE_UPPER_SECTION);    // this also detects crosses on bars without ticks (e.g. on slow M1)
         else if (lastSide>=0 && side < 0) onCross(MODE_LOWER_SECTION);
         lastSide = side;
      }
   }
   return(last_error);
}


/**
 * Event handler called on BarOpen if the MACD crossed the zero line.
 *
 * @param  int direction
 *
 * @return bool - success status
 */
bool onCross(int direction) {
   if (direction!=MODE_UPPER_SECTION && direction!=MODE_LOWER_SECTION) return(!catch("onCross(1)  invalid parameter direction: "+ direction, ERR_INVALID_PARAMETER));

   // skip the signal if it was already signaled elsewhere
   int hWnd = ifInt(__isTesting, __ExecutionContext[EC.hChart], GetDesktopWindow());
   string sPeriod = PeriodDescription();
   string sEvent  = "rsf::"+ StdSymbol() +","+ sPeriod +"."+ indicatorName +".onCross("+ direction +")."+ TimeToStr(Time[0]);
   if (GetPropA(hWnd, sEvent) != 0) return(true);
   SetPropA(hWnd, sEvent, 1);                         // immediately mark as signaled (prevents duplicate signals on slow CPU)

   string message = indicatorName +" crossed "+ ifString(direction==MODE_UPPER_SECTION, "up", "down") +" (bid: "+ NumberToStr(_Bid, PriceFormat) +")";
   if (IsLogInfo()) logInfo("onCross(2)  "+ message);

   message = Symbol() +","+ PeriodDescription() +": "+ message;
   string sAccount = "("+ TimeToStr(TimeLocalEx("onCross(3)"), TIME_MINUTES|TIME_SECONDS) +", "+ GetAccountAlias() +")";
   int error = NO_ERROR;

   if (signal.alert)          Alert(message);
   if (signal.sound) error  = PlaySoundEx(ifString(direction==MODE_UPPER_SECTION, Signal.Sound.Up, Signal.Sound.Down)); if (error == ERR_FILE_NOT_FOUND) signal.sound = false;
   if (signal.mail)  error |= !SendEmail("", "", message, message + NL + sAccount);
   if (signal.sms)   error |= !SendSMS("", message + NL + sAccount);
   return(!error);
}


/**
 * Workaround for various terminal bugs when setting indicator options. Usually options are set in init(). However after
 * recompilation options must be set in start() to not be ignored.
 */
void SetIndicatorOptions() {
   IndicatorBuffers(indicator_buffers);

   int mainType    = ifInt(MainLine.Width,        DRAW_LINE,      DRAW_NONE);
   int sectionType = ifInt(Histogram.Style.Width, DRAW_HISTOGRAM, DRAW_NONE);

   SetIndexStyle(MODE_MAIN,          mainType,    EMPTY, MainLine.Width,        MainLine.Color       );
   SetIndexStyle(MODE_SECTION,       DRAW_NONE,   EMPTY, EMPTY,                 CLR_NONE             );
   SetIndexStyle(MODE_UPPER_SECTION, sectionType, EMPTY, Histogram.Style.Width, Histogram.Color.Upper);
   SetIndexStyle(MODE_LOWER_SECTION, sectionType, EMPTY, Histogram.Style.Width, Histogram.Color.Lower);
}


/**
 * Return a string representation of the input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("FastMA.Periods=",        FastMA.Periods,                       ";", NL,
                            "FastMA.Method=",         DoubleQuoteStr(FastMA.Method),        ";", NL,
                            "FastMA.AppliedPrice=",   DoubleQuoteStr(FastMA.AppliedPrice),  ";", NL,
                            "SlowMA.Periods=",        SlowMA.Periods,                       ";", NL,
                            "SlowMA.Method=",         DoubleQuoteStr(SlowMA.Method),        ";", NL,
                            "SlowMA.AppliedPrice=",   DoubleQuoteStr(SlowMA.AppliedPrice),  ";", NL,
                            "Histogram.Color.Upper=", ColorToStr(Histogram.Color.Upper),    ";", NL,
                            "Histogram.Color.Lower=", ColorToStr(Histogram.Color.Lower),    ";", NL,
                            "Histogram.Style.Width=", Histogram.Style.Width,                ";", NL,
                            "MainLine.Color=",        ColorToStr(MainLine.Color),           ";", NL,
                            "MainLine.Width=",        MainLine.Width,                       ";", NL,
                            "MaxBarsBack=",           MaxBarsBack,                          ";", NL,

                            "Signal.onCross=",        BoolToStr(Signal.onCross),            ";", NL,
                            "Signal.onCross.Types=",  DoubleQuoteStr(Signal.onCross.Types), ";", NL,
                            "Signal.Sound.Up=",       DoubleQuoteStr(Signal.Sound.Up),      ";", NL,
                            "Signal.Sound.Down=",     DoubleQuoteStr(Signal.Sound.Down),    ";")
   );

   // suppress compiler warnings
   icMACD(NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
}
