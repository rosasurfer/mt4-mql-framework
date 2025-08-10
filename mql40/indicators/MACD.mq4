/**
 * A MACD indicator with support for different MA methods and additional features.
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
 *  • MACD.MODE_MAIN:  MACD main value
 *  • MACD.MODE_TREND: MACD trend and trend length since last crossing of the zero level
 *    - trend:  positive values denote a MACD above zero (+1...+n), negative values denote a MACD below zero (-1...-n)
 *    - length: the absolute value is the histogram section length (bars since the last crossing of zero)
 *
 *
 * Notes: The SMMA is in fact an EMA with a different period. It holds: SMMA(n) = EMA(2*n-1)
 *        @see  https://web.archive.org/web/20221120050520/https://en.wikipedia.org/wiki/Moving_average#Modified_moving_average
 */
#include <rsf/stddefines.mqh>
int   __InitFlags[];
int __DeinitFlags[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern string FastMA.Method                  = "SMA | LWMA | EMA* | SMMA| ALMA";
extern int    FastMA.Periods                 = 12;
extern string FastMA.AppliedPrice            = "Open | High | Low | Close* | Median | Typical | Weighted";

extern string SlowMA.Method                  = "SMA | LWMA | EMA* | ALMA";
extern int    SlowMA.Periods                 = 26;
extern string SlowMA.AppliedPrice            = "Open | High | Low | Close* | Median | Typical | Weighted";

extern color  Histogram.Color.Upper          = LimeGreen;
extern color  Histogram.Color.Lower          = Red;
extern int    Histogram.Style.Width          = 2;

extern color  MainLine.Color                 = DodgerBlue;
extern int    MainLine.Width                 = 1;

extern string ___a__________________________ = "=== Display settings ===";
extern string VScale.Unit                    = "price* | bps-price | bps-adr";
extern int    VScale.ADR.Periods             = 20;
extern int    MaxBarsBack                    = 10000;                // max. values to calculate (-1: all available)

extern string ___b__________________________ = "=== Signaling ===";
extern bool   Signal.onCross                 = false;
extern string Signal.onCross.Types           = "sound* | alert | mail";
extern string Signal.Sound.Up                = "Signal Up.wav";
extern string Signal.Sound.Down              = "Signal Down.wav";

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <rsf/core/indicator.mqh>
#include <rsf/stdfunctions.mqh>
#include <rsf/stdlib.mqh>
#include <rsf/functions/ConfigureSignals.mqh>
#include <rsf/functions/IsBarOpen.mqh>
#include <rsf/functions/iCustom/MACD.mqh>
#include <rsf/functions/ta/ALMA.mqh>
#include <rsf/win32api.mqh>

#define MODE_MAIN             MACD.MODE_MAIN       // 0 indicator buffer ids
#define MODE_TREND            MACD.MODE_TREND      // 1
#define MODE_UPPER_SECTION    2
#define MODE_LOWER_SECTION    3

#define VSCALE_UNIT_PRICE     1                    // vscale unit ids
#define VSCALE_UNIT_BPS_PRICE 2                    //
#define VSCALE_UNIT_BPS_ADR   3                    //

#property indicator_separate_window
#property indicator_buffers   4

#property indicator_color1    CLR_NONE
#property indicator_color2    CLR_NONE
#property indicator_color3    CLR_NONE
#property indicator_color4    CLR_NONE

#property indicator_level1    0

double macd[];                                     // all histogram values:      visible, displayed in "Data" window
double macdUpper[];                                // positive histogram values: visible
double macdLower[];                                // negative histogram values: visible
double trend[];                                    // trend and trend length:    invisible

int    fastMA.periods;
int    fastMA.method;
int    fastMA.appliedPrice;
double fastALMA.weights[];                         // fast ALMA weights

int    slowMA.periods;
int    slowMA.method;
int    slowMA.appliedPrice;
double slowALMA.weights[];                         // slow ALMA weights

int    vscaleUnit;
int    vscaleAdrPeriods;

bool   signal.sound;
bool   signal.alert;
bool   signal.mail;

string indicatorName = "";                         // "Data" window and signal notification name


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   string indicator = WindowExpertName();

   // validate inputs
   // FastMA.Method
   string sValues[], sValue = FastMA.Method;
   if (AutoConfiguration) sValue = GetConfigString(indicator, "FastMA.Method", sValue);
   if (Explode(sValue, "*", sValues, 2) > 1) {
      int size = Explode(sValues[0], "|", sValues, NULL);
      sValue = sValues[size-1];
   }
   fastMA.method = StrToMaMethod(sValue, F_PARTIAL_ID|F_ERR_INVALID_PARAMETER);
   if (fastMA.method == -1)             return(catch("onInit(1)  invalid input parameter FastMA.Method: "+ DoubleQuoteStr(FastMA.Method), ERR_INVALID_INPUT_PARAMETER));
   FastMA.Method = MaMethodDescription(fastMA.method);
   // FastMA.Periods
   if (AutoConfiguration) FastMA.Periods = GetConfigInt(indicator, "FastMA.Periods", FastMA.Periods);
   if (FastMA.Periods < 1)              return(catch("onInit(2)  invalid input parameter FastMA.Periods: "+ FastMA.Periods, ERR_INVALID_INPUT_PARAMETER));
   fastMA.periods = FastMA.Periods;
   // FastMA.AppliedPrice
   sValue = FastMA.AppliedPrice;
   if (AutoConfiguration) sValue = GetConfigString(indicator, "FastMA.AppliedPrice", sValue);
   if (Explode(sValue, "*", sValues, 2) > 1) {
      size = Explode(sValues[0], "|", sValues, NULL);
      sValue = sValues[size-1];
   }
   sValue = StrTrim(sValue);
   if (sValue == "") sValue = "close";                                  // default price type
   fastMA.appliedPrice = StrToPriceType(sValue, F_PARTIAL_ID|F_ERR_INVALID_PARAMETER);
   if (fastMA.appliedPrice == -1)       return(catch("onInit(3)  invalid input parameter FastMA.AppliedPrice: "+ DoubleQuoteStr(FastMA.AppliedPrice), ERR_INVALID_INPUT_PARAMETER));
   FastMA.AppliedPrice = PriceTypeDescription(fastMA.appliedPrice);
   // SlowMA.Method
   sValue = SlowMA.Method;
   if (AutoConfiguration) sValue = GetConfigString(indicator, "SlowMA.Method", sValue);
   if (Explode(sValue, "*", sValues, 2) > 1) {
      size = Explode(sValues[0], "|", sValues, NULL);
      sValue = sValues[size-1];
   }
   slowMA.method = StrToMaMethod(sValue, F_PARTIAL_ID|F_ERR_INVALID_PARAMETER);
   if (slowMA.method == -1)             return(catch("onInit(4)  invalid input parameter SlowMA.Method: "+ DoubleQuoteStr(SlowMA.Method), ERR_INVALID_INPUT_PARAMETER));
   SlowMA.Method = MaMethodDescription(slowMA.method);
   // SlowMA.Periods
   if (AutoConfiguration) SlowMA.Periods = GetConfigInt(indicator, "SlowMA.Periods", SlowMA.Periods);
   if (SlowMA.Periods < 1)              return(catch("onInit(5)  invalid input parameter SlowMA.Periods: "+ SlowMA.Periods, ERR_INVALID_INPUT_PARAMETER));
   slowMA.periods = SlowMA.Periods;
   if (FastMA.Periods > SlowMA.Periods) return(catch("onInit(6)  parameter mis-match of FastMA.Periods/SlowMA.Periods: "+ FastMA.Periods +"/"+ SlowMA.Periods +" (fast value must be smaller than slow one)", ERR_INVALID_INPUT_PARAMETER));
   // SlowMA.AppliedPrice
   sValue = SlowMA.AppliedPrice;
   if (AutoConfiguration) sValue = GetConfigString(indicator, "SlowMA.AppliedPrice", sValue);
   if (Explode(sValue, "*", sValues, 2) > 1) {
      size = Explode(sValues[0], "|", sValues, NULL);
      sValue = sValues[size-1];
   }
   sValue = StrTrim(sValue);
   if (sValue == "") sValue = "close";                                  // default price type
   slowMA.appliedPrice = StrToPriceType(sValue, F_PARTIAL_ID|F_ERR_INVALID_PARAMETER);
   if (slowMA.appliedPrice == -1)       return(catch("onInit(7)  invalid input parameter SlowMA.AppliedPrice: "+ DoubleQuoteStr(SlowMA.AppliedPrice), ERR_INVALID_INPUT_PARAMETER));
   if (fastMA.periods == slowMA.periods) {
      if (fastMA.method == slowMA.method) {
         if (fastMA.appliedPrice == slowMA.appliedPrice) {
            return(catch("onInit(8)  parameter mis-match (fast MA must differ from slow MA)", ERR_INVALID_INPUT_PARAMETER));
         }
      }
   }
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
   if (Histogram.Style.Width < 0)       return(catch("onInit(9)  invalid input parameter Histogram.Style.Width: "+ Histogram.Style.Width +" (must be from 0-5)", ERR_INVALID_INPUT_PARAMETER));
   if (Histogram.Style.Width > 5)       return(catch("onInit(10)  invalid input parameter Histogram.Style.Width: "+ Histogram.Style.Width +" (must be from 0-5)", ERR_INVALID_INPUT_PARAMETER));
   // MainLine.Width
   if (AutoConfiguration) MainLine.Width = GetConfigInt(indicator, "MainLine.Width", MainLine.Width);
   if (MainLine.Width < 0)              return(catch("onInit(11)  invalid input parameter MainLine.Width: "+ MainLine.Width +" (must be non-negative)", ERR_INVALID_INPUT_PARAMETER));
   // VScale.Unit
   sValue = VScale.Unit;
   if (AutoConfiguration) sValue = GetConfigString(indicator, "VScale.Unit", sValue);
   if (Explode(sValue, "*", sValues, 2) > 1) {
      size = Explode(sValues[0], "|", sValues, NULL);
      sValue = sValues[size-1];
   }
   sValue = StrToLower(StrTrim(sValue));
   if      (sValue == "price")     vscaleUnit = VSCALE_UNIT_PRICE;
   else if (sValue == "bps-price") vscaleUnit = VSCALE_UNIT_BPS_PRICE;
   else if (sValue == "bps-adr")   vscaleUnit = VSCALE_UNIT_BPS_ADR;
   else                                 return(catch("onInit(12)  invalid input parameter VScale.Unit: "+ DoubleQuoteStr(VScale.Unit), ERR_INVALID_INPUT_PARAMETER));
   VScale.Unit = sValue;
   // VScale.ADR.Periods
   if (AutoConfiguration) VScale.ADR.Periods = GetConfigInt(indicator, "VScale.ADR.Periods", VScale.ADR.Periods);
   if (VScale.ADR.Periods < 1)          return(catch("onInit(13)  invalid input parameter VScale.ADR.Periods: "+ VScale.ADR.Periods, ERR_INVALID_INPUT_PARAMETER));
   vscaleAdrPeriods = VScale.ADR.Periods;
   // MaxBarsBack
   if (AutoConfiguration) MaxBarsBack = GetConfigInt(indicator, "MaxBarsBack", MaxBarsBack);
   if (MaxBarsBack < -1)                return(catch("onInit(14)  invalid input parameter MaxBarsBack: "+ MaxBarsBack, ERR_INVALID_INPUT_PARAMETER));
   if (MaxBarsBack == -1) MaxBarsBack = INT_MAX;

   // signal configuration
   string signalId = "Signal.onCross";
   if (!ConfigureSignals(signalId, AutoConfiguration, Signal.onCross)) return(last_error);
   if (Signal.onCross) {
      if (!ConfigureSignalTypes(signalId, Signal.onCross.Types, AutoConfiguration, signal.sound, signal.alert, signal.mail)) {
         return(catch("onInit(15)  invalid input parameter Signal.onCross.Types: "+ DoubleQuoteStr(Signal.onCross.Types), ERR_INVALID_INPUT_PARAMETER));
      }
      Signal.onCross = (signal.sound || signal.alert || signal.mail);
   }
   // Signal.Sound.*
   if (AutoConfiguration) Signal.Sound.Up   = GetConfigString(indicator, "Signal.Sound.Up",   Signal.Sound.Up);
   if (AutoConfiguration) Signal.Sound.Down = GetConfigString(indicator, "Signal.Sound.Down", Signal.Sound.Down);

   // calculate ALMA bar weights
   double almaOffset=0.85, almaSigma=6.0;
   if (fastMA.method == MODE_ALMA) ALMA.CalculateWeights(fastMA.periods, almaOffset, almaSigma, fastALMA.weights);
   if (slowMA.method == MODE_ALMA) ALMA.CalculateWeights(slowMA.periods, almaOffset, almaSigma, slowALMA.weights);

   SetIndicatorOptions();
   return(catch("onInit(16)"));
}


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   // reset buffers before performing a full recalculation
   if (!ValidBars) {
      ArrayInitialize(macd,      EMPTY_VALUE);
      ArrayInitialize(macdUpper, EMPTY_VALUE);
      ArrayInitialize(macdLower, EMPTY_VALUE);
      ArrayInitialize(trend,               0);
      SetIndicatorOptions();
   }

   // synchronize buffers with a shifted offline chart
   if (ShiftedBars > 0) {
      ShiftDoubleIndicatorBuffer(macd,      Bars, ShiftedBars, EMPTY_VALUE);
      ShiftDoubleIndicatorBuffer(macdUpper, Bars, ShiftedBars, EMPTY_VALUE);
      ShiftDoubleIndicatorBuffer(macdLower, Bars, ShiftedBars, EMPTY_VALUE);
      ShiftDoubleIndicatorBuffer(trend,     Bars, ShiftedBars,           0);
   }

   // calculate start bar
   int startbar = Min(MaxBarsBack-1, ChangedBars-1, Bars-slowMA.periods);
   if (startbar < 0 && MaxBarsBack) return(logInfo("onTick(1)  Tick="+ Ticks, ERR_HISTORY_INSUFFICIENT));

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

      // MACD
      if (vscaleUnit == VSCALE_UNIT_PRICE) {
         macd[bar] = (fastMA - slowMA)/pUnit;               // nominal difference
      }
      else if (vscaleUnit == VSCALE_UNIT_BPS_PRICE) {
         macd[bar] = 10000 * (fastMA/slowMA - 1);           // ratio difference/price in bps
      }
      else if (vscaleUnit == VSCALE_UNIT_BPS_ADR) {
         int offset = iBarShift(NULL, PERIOD_D1, Time[bar], true);
         if (offset < 0) {
            debug("onTick(0.1)  iBarShift(D1, Time["+ bar +"]="+ TimeToStr(Time[bar]) +") = 0", GetLastError());
         }
         else {
            double adr = iATR(NULL, PERIOD_D1, VScale.ADR.Periods, offset+1);
            if (adr == 0) {
               debug("onTick(0.2)  iATR(D1, bar="+ (offset+1) +") = 0", GetLastError());
            }
            else {
               macd[bar] = 10000 * (fastMA - slowMA)/adr;   // ratio difference/ADR in bps
            }
         }
      }

      if (macd[bar] > 0) {
         macdUpper[bar] = macd[bar];
         macdLower[bar] = EMPTY_VALUE;
      }
      else {
         macdUpper[bar] = EMPTY_VALUE;
         macdLower[bar] = macd[bar];
      }

      // update trend length (duration)
      if      (trend[bar+1] > 0 && macd[bar] >= 0) trend[bar] = _int(trend[bar+1]) + 1;
      else if (trend[bar+1] < 0 && macd[bar] <= 0) trend[bar] = _int(trend[bar+1]) - 1;
      else                                         trend[bar] =  Sign(macd[bar]);
   }

   // detect zero line crossings
   if (!__isSuperContext) {
      if (Signal.onCross) /*&&*/ if (IsBarOpen()) {
         // TODO: check signals on bars without ticks (e.g. on slow M1)
         if      (trend[2] < 0 && trend[1] > 0) onCross(MODE_UPPER_SECTION);
         else if (trend[2] > 0 && trend[1] < 0) onCross(MODE_LOWER_SECTION);
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

   // skip the signal if it was already processed elsewhere
   string sPeriod   = PeriodDescription();
   string eventName = "rsf::"+ StdSymbol() +","+ sPeriod +"."+ indicatorName +".onCross("+ direction +")."+ TimeToStr(Time[0]), propertyName = "";
   string message1  = indicatorName +" crossed "+ ifString(direction==MODE_UPPER_SECTION, "up", "down") +" (bid: "+ NumberToStr(_Bid, PriceFormat) +")";
   string message2  = Symbol() +","+ sPeriod +": "+ message1;

   int hWndTerminal=GetTerminalMainWindow(), hWndDesktop=GetDesktopWindow();
   bool eventAction;

   // log: once per terminal
   if (IsLogInfo()) {
      eventAction = true;
      if (!__isTesting) {
         propertyName = eventName +"|log";
         eventAction = !GetWindowPropertyA(hWndTerminal, propertyName);
         SetWindowPropertyA(hWndTerminal, propertyName, 1);
      }
      if (eventAction) logInfo("onCross(2)  "+ message1);
   }

   // sound: once per system
   if (signal.sound) {
      eventAction = true;
      if (!__isTesting) {
         propertyName = eventName +"|sound";
         eventAction = !GetWindowPropertyA(hWndDesktop, propertyName);
         SetWindowPropertyA(hWndDesktop, propertyName, 1);
      }
      if (eventAction) PlaySoundEx(ifString(direction==MODE_UPPER_SECTION, Signal.Sound.Up, Signal.Sound.Down));
   }

   // alert: once per terminal
   if (signal.alert) {
      eventAction = true;
      if (!__isTesting) {
         propertyName = eventName +"|alert";
         eventAction = !GetWindowPropertyA(hWndTerminal, propertyName);
         SetWindowPropertyA(hWndTerminal, propertyName, 1);
      }
      if (eventAction) Alert(message2);
   }

   // mail: once per system
   if (signal.mail) {
      eventAction = true;
      if (!__isTesting) {
         propertyName = eventName +"|mail";
         eventAction = !GetWindowPropertyA(hWndDesktop, propertyName);
         SetWindowPropertyA(hWndDesktop, propertyName, 1);
      }
      if (eventAction) SendEmail("", "", message2, message2 + NL + "("+ TimeToStr(TimeLocalEx("onCross(3)"), TIME_MINUTES|TIME_SECONDS) +", "+ GetAccountAlias() +")");
   }
   return(!catch("onCross(4)"));
}


/**
 * Set indicator options. After recompilation the function must be called from start() for options not to be ignored.
 *
 * @param  bool redraw [optional] - whether to redraw the chart (default: no)
 *
 * @return bool - success status
 */
bool SetIndicatorOptions(bool redraw = false) {
   redraw = redraw!=0;

   IndicatorBuffers(indicator_buffers);
   SetIndexBuffer(MODE_MAIN,          macd     );                       // all histogram values:      visible, displayed in "Data" window
   SetIndexBuffer(MODE_UPPER_SECTION, macdUpper);                       // positive histogram values: visible
   SetIndexBuffer(MODE_LOWER_SECTION, macdLower);                       // negative histogram values: visible
   SetIndexBuffer(MODE_TREND,         trend    );                       // trend and trend length:    invisible

   int mainType = ifInt(MainLine.Width,        DRAW_LINE,      DRAW_NONE);
   int drawType = ifInt(Histogram.Style.Width, DRAW_HISTOGRAM, DRAW_NONE);

   SetIndexStyle(MODE_MAIN,          mainType,  EMPTY, MainLine.Width,        MainLine.Color       );
   SetIndexStyle(MODE_UPPER_SECTION, drawType,  EMPTY, Histogram.Style.Width, Histogram.Color.Upper);
   SetIndexStyle(MODE_LOWER_SECTION, drawType,  EMPTY, Histogram.Style.Width, Histogram.Color.Lower);
   SetIndexStyle(MODE_TREND,         DRAW_NONE, EMPTY, EMPTY,                 CLR_NONE             );

   string dataName="", sAppliedPrice="";
   if (fastMA.appliedPrice!=slowMA.appliedPrice || fastMA.appliedPrice!=PRICE_CLOSE) sAppliedPrice = ","+ PriceTypeDescription(fastMA.appliedPrice);
   string fastMA.name = FastMA.Method +"("+ fastMA.periods + sAppliedPrice +")";
   sAppliedPrice = "";
   if (fastMA.appliedPrice!=slowMA.appliedPrice || slowMA.appliedPrice!=PRICE_CLOSE) sAppliedPrice = ","+ PriceTypeDescription(slowMA.appliedPrice);
   string slowMA.name = SlowMA.Method +"("+ slowMA.periods + sAppliedPrice +")";

   if (FastMA.Method==SlowMA.Method && fastMA.appliedPrice==slowMA.appliedPrice) indicatorName = "MACD "+ FastMA.Method +"("+ fastMA.periods +","+ slowMA.periods + sAppliedPrice +")";
   else                                                                          indicatorName = "MACD "+ fastMA.name +", "+ slowMA.name;
   if (FastMA.Method==SlowMA.Method)                                             dataName      = "MACD "+ FastMA.Method +"("+ fastMA.periods +","+ slowMA.periods +")";
   else                                                                          dataName      = "MACD "+ FastMA.Method +"("+ fastMA.periods +"), "+ SlowMA.Method +"("+ slowMA.periods +")";

   string sUnit = "";
   int digits = 2;
   if      (vscaleUnit == VSCALE_UNIT_PRICE)     digits = pDigits;
   else if (vscaleUnit == VSCALE_UNIT_BPS_PRICE) sUnit  = " in bps/price";
   else if (vscaleUnit == VSCALE_UNIT_BPS_ADR)   sUnit  = " in bps/ADR";

   string subWindowName = "MACD  "+ StrRight(indicatorName, -5);
   IndicatorShortName(subWindowName + sUnit +"  ");                     // chart subwindow and context menu
   SetIndexLabel(MODE_MAIN,          dataName);                         // chart tooltips and "Data" window
   SetIndexLabel(MODE_UPPER_SECTION, NULL);
   SetIndexLabel(MODE_LOWER_SECTION, NULL);
   SetIndexLabel(MODE_TREND,         NULL);

   IndicatorDigits(digits);

   if (redraw) WindowRedraw();
   return(!catch("SetIndicatorOptions(1)"));
}


/**
 * Return a string representation of all input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("FastMA.Method=",         DoubleQuoteStr(FastMA.Method),        ";"+ NL,
                            "FastMA.Periods=",        FastMA.Periods,                       ";"+ NL,
                            "FastMA.AppliedPrice=",   DoubleQuoteStr(FastMA.AppliedPrice),  ";"+ NL,

                            "SlowMA.Method=",         DoubleQuoteStr(SlowMA.Method),        ";"+ NL,
                            "SlowMA.Periods=",        SlowMA.Periods,                       ";"+ NL,
                            "SlowMA.AppliedPrice=",   DoubleQuoteStr(SlowMA.AppliedPrice),  ";"+ NL,

                            "Histogram.Color.Upper=", ColorToStr(Histogram.Color.Upper),    ";"+ NL,
                            "Histogram.Color.Lower=", ColorToStr(Histogram.Color.Lower),    ";"+ NL,
                            "Histogram.Style.Width=", Histogram.Style.Width,                ";"+ NL,

                            "MainLine.Color=",        ColorToStr(MainLine.Color),           ";"+ NL,
                            "MainLine.Width=",        MainLine.Width,                       ";"+ NL,

                            "VScale.Unit=",           DoubleQuoteStr(VScale.Unit),          ";"+ NL,
                            "VScale.ADR.Periods=",    VScale.ADR.Periods,                   ";"+ NL,
                            "MaxBarsBack=",           MaxBarsBack,                          ";"+ NL,

                            "Signal.onCross=",        BoolToStr(Signal.onCross),            ";"+ NL,
                            "Signal.onCross.Types=",  DoubleQuoteStr(Signal.onCross.Types), ";"+ NL,
                            "Signal.Sound.Up=",       DoubleQuoteStr(Signal.Sound.Up),      ";"+ NL,
                            "Signal.Sound.Down=",     DoubleQuoteStr(Signal.Sound.Down),    ";")
   );

   // suppress compiler warnings
   icMACD(NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
}
