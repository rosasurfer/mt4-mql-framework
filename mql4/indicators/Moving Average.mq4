/**
 * A "Moving Average" indicator with support for more MA methods and additional features.
 *
 *
 * Available Moving Average types:
 *  • SMA  - Simple Moving Average:          equal bar weighting
 *  • LWMA - Linear Weighted Moving Average: bar weighting using a linear function
 *  • EMA  - Exponential Moving Average:     bar weighting using an exponential function
 *  • SMMA - Smoothed Moving Average:        bar weighting using an exponential function (an EMA, see notes)
 *  • ALMA - Arnaud Legoux Moving Average:   bar weighting using a Gaussian function
 *
 *
 * Indicator buffers for iCustom():
 *  • MovingAverage.MODE_MA:    MA values
 *  • MovingAverage.MODE_TREND: trend direction and length
 *    - trend direction:        positive values denote an uptrend (+1...+n), negative values denote a downtrend (-1...-n)
 *    - trend length:           the absolute value of the direction is the trend length in bars since the last reversal
 *
 *
 * Notes:
 *  (1) EMA calculation:
 *      @see https://web.archive.org/web/20221120050520/https://en.wikipedia.org/wiki/Moving_average#Exponential_moving_average
 *
 *  (2) The SMMA is in fact an EMA with a different period. It holds: SMMA(n) = EMA(2*n-1)
 *      @see https://web.archive.org/web/20221120050520/https://en.wikipedia.org/wiki/Moving_average#Modified_moving_average
 *
 *  (3) ALMA calculation:
 *      @see http://web.archive.org/web/20180307031850/http://www.arnaudlegoux.com/
 */
#include <stddefines.mqh>
int   __InitFlags[];
int __DeinitFlags[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern int    MA.Periods                     = 100;
extern string MA.Method                      = "SMA* | LWMA | EMA | SMMA | ALMA";
extern string MA.AppliedPrice                = "Open | High | Low | Close* | Median | Typical | Weighted";

extern color  UpTrend.Color                  = DeepSkyBlue;
extern color  DownTrend.Color                = Gold;
extern string Draw.Type                      = "Line* | Dot";
extern int    Draw.Width                     = 4;
extern color  Background.Color               = DimGray;           // background for Draw.Type = "Line"
extern int    Background.Width               = 2;
extern bool   ShowChartLegend                = true;
extern int    MaxBarsBack                    = 10000;             // max. values to calculate (-1: all available)

extern string ___a__________________________ = "=== Signaling ===";
extern bool   Signal.onTrendChange           = false;
extern string Signal.onTrendChange.Types     = "sound* | alert | mail | sms";
extern string Signal.Sound.Up                = "Signal Up.wav";
extern string Signal.Sound.Down              = "Signal Down.wav";

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <rsfLib.mqh>
#include <functions/chartlegend.mqh>
#include <functions/ConfigureSignals.mqh>
#include <functions/IsBarOpen.mqh>
#include <functions/ObjectCreateRegister.mqh>
#include <functions/trend.mqh>
#include <functions/ta/ALMA.mqh>

#define MODE_MA               MovingAverage.MODE_MA      // indicator buffer ids
#define MODE_TREND            MovingAverage.MODE_TREND
#define MODE_UPTREND          2
#define MODE_DOWNTREND        3
#define MODE_UPTREND2         4

#property indicator_chart_window
#property indicator_buffers   5

#property indicator_color1    CLR_NONE
#property indicator_color2    CLR_NONE
#property indicator_color3    CLR_NONE
#property indicator_color4    CLR_NONE
#property indicator_color5    CLR_NONE

double main     [];                                      // MA main values:      visible (background), displayed in legend and "Data" window
double trend    [];                                      // trend direction:     invisible, displayed in "Data" window
double uptrend  [];                                      // uptrend values:      visible
double downtrend[];                                      // downtrend values:    visible
double uptrend2 [];                                      // single-bar uptrends: visible

int    maMethod;
int    maAppliedPrice;
double almaWeights[];                                    // ALMA bar weights

string indicatorName = "";
string legendLabel   = "";
string legendInfo    = "";                               // additional chart legend info
int    drawType;

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

   // MA.Periods
   if (AutoConfiguration) MA.Periods = GetConfigInt(indicator, "MA.Periods", MA.Periods);
   if (MA.Periods < 1)       return(catch("onInit(1)  invalid input parameter MA.Periods: "+ MA.Periods, ERR_INVALID_INPUT_PARAMETER));
   // MA.Method
   string sValues[], sValue = MA.Method;
   if (AutoConfiguration) sValue = GetConfigString(indicator, "MA.Method", sValue);
   if (Explode(sValue, "*", sValues, 2) > 1) {
      int size = Explode(sValues[0], "|", sValues, NULL);
      sValue = sValues[size-1];
   }
   maMethod = StrToMaMethod(sValue, F_PARTIAL_ID|F_ERR_INVALID_PARAMETER);
   if (maMethod == -1)       return(catch("onInit(2)  invalid input parameter MA.Method: "+ DoubleQuoteStr(MA.Method), ERR_INVALID_INPUT_PARAMETER));
   MA.Method = MaMethodDescription(maMethod);
   // MA.AppliedPrice
   sValue = MA.AppliedPrice;
   if (AutoConfiguration) sValue = GetConfigString(indicator, "MA.AppliedPrice", sValue);
   if (Explode(sValue, "*", sValues, 2) > 1) {
      size = Explode(sValues[0], "|", sValues, NULL);
      sValue = sValues[size-1];
   }
   if (StrTrim(sValue) == "") sValue = "close";               // default price type
   maAppliedPrice = StrToPriceType(sValue, F_PARTIAL_ID|F_ERR_INVALID_PARAMETER);
   if (maAppliedPrice == -1) return(catch("onInit(3)  invalid input parameter MA.AppliedPrice: "+ DoubleQuoteStr(MA.AppliedPrice), ERR_INVALID_INPUT_PARAMETER));
   MA.AppliedPrice = PriceTypeDescription(maAppliedPrice);
   // Draw.Type
   sValue = Draw.Type;
   if (AutoConfiguration) sValue = GetConfigString(indicator, "Draw.Type", sValue);
   if (Explode(sValue, "*", sValues, 2) > 1) {
      size = Explode(sValues[0], "|", sValues, NULL);
      sValue = sValues[size-1];
   }
   sValue = StrToLower(StrTrim(sValue));
   if      (StrStartsWith("line", sValue)) { drawType = DRAW_LINE;  Draw.Type = "Line"; }
   else if (StrStartsWith("dot",  sValue)) { drawType = DRAW_ARROW; Draw.Type = "Dot";  }
   else                      return(catch("onInit(4)  invalid input parameter Draw.Type: "+ DoubleQuoteStr(Draw.Type), ERR_INVALID_INPUT_PARAMETER));
   // Draw.Width
   if (AutoConfiguration) Draw.Width = GetConfigInt(indicator, "Draw.Width", Draw.Width);
   if (Draw.Width < 0)       return(catch("onInit(5)  invalid input parameter Draw.Width: "+ Draw.Width +" (must be >= 0)", ERR_INVALID_INPUT_PARAMETER));
   // Background.Width
   if (AutoConfiguration) Background.Width = GetConfigInt(indicator, "Background.Width", Background.Width);
   if (Background.Width < 0) return(catch("onInit(6)  invalid input parameter Background.Width: "+ Background.Width +" (must be >= 0)", ERR_INVALID_INPUT_PARAMETER));
   // colors: after deserialization the terminal might turn CLR_NONE (0xFFFFFFFF) into Black (0xFF000000)
   if (AutoConfiguration) Background.Color = GetConfigColor(indicator, "Background.Color", Background.Color);
   if (AutoConfiguration) UpTrend.Color    = GetConfigColor(indicator, "UpTrend.Color",    UpTrend.Color);
   if (AutoConfiguration) DownTrend.Color  = GetConfigColor(indicator, "DownTrend.Color",  DownTrend.Color);
   if (Background.Color == 0xFF000000) Background.Color = CLR_NONE;
   if (UpTrend.Color    == 0xFF000000) UpTrend.Color    = CLR_NONE;
   if (DownTrend.Color  == 0xFF000000) DownTrend.Color  = CLR_NONE;
   // ShowChartLegend
   if (AutoConfiguration) ShowChartLegend = GetConfigBool(indicator, "ShowChartLegend", ShowChartLegend);
   // MaxBarsBack
   if (AutoConfiguration) MaxBarsBack = GetConfigInt(indicator, "MaxBarsBack", MaxBarsBack);
   if (MaxBarsBack < -1)     return(catch("onInit(7)  invalid input parameter MaxBarsBack: "+ MaxBarsBack, ERR_INVALID_INPUT_PARAMETER));
   if (MaxBarsBack == -1) MaxBarsBack = INT_MAX;

   // signal configuration
   string signalId = "Signal.onTrendChange";
   legendInfo = "";
   if (!ConfigureSignals(signalId, AutoConfiguration, Signal.onTrendChange)) return(last_error);
   if (Signal.onTrendChange) {
      if (!ConfigureSignalTypes(signalId, Signal.onTrendChange.Types, AutoConfiguration, signal.sound, signal.alert, signal.mail, signal.sms)) {
         return(catch("onInit(8)  invalid input parameter Signal.onTrendChange.Types: "+ DoubleQuoteStr(Signal.onTrendChange.Types), ERR_INVALID_INPUT_PARAMETER));
      }
      Signal.onTrendChange = (signal.sound || signal.alert || signal.mail || signal.sms);
      if (Signal.onTrendChange) legendInfo = "("+ StrLeft(ifString(signal.sound, "sound,", "") + ifString(signal.alert, "alert,", "") + ifString(signal.mail, "mail,", "") + ifString(signal.sms, "sms,", ""), -1) +")";
   }
   // Signal.Sound.*
   if (AutoConfiguration) Signal.Sound.Up   = GetConfigString(indicator, "Signal.Sound.Up",   Signal.Sound.Up);
   if (AutoConfiguration) Signal.Sound.Down = GetConfigString(indicator, "Signal.Sound.Down", Signal.Sound.Down);

   // buffer management
   SetIndexBuffer(MODE_MA,        main     );            // MA main values:       visible (background), displayed in legend and "Data" window
   SetIndexBuffer(MODE_TREND,     trend    );            // trend direction:      invisible, displayed in "Data" window
   SetIndexBuffer(MODE_UPTREND,   uptrend  );            // uptrend values:       visible
   SetIndexBuffer(MODE_DOWNTREND, downtrend);            // downtrend values:     visible
   SetIndexBuffer(MODE_UPTREND2,  uptrend2 );            // single-bar uptrends:  visible

   // names, labels and display options
   if (ShowChartLegend) legendLabel = CreateChartLegend();
   string sAppliedPrice = ifString(maAppliedPrice==PRICE_CLOSE, "", ", "+ PriceTypeDescription(maAppliedPrice));
   indicatorName = MA.Method +"("+ MA.Periods + sAppliedPrice +")";
   string shortName = MA.Method +"("+ MA.Periods +")";
   IndicatorShortName(shortName);                        // chart tooltips and context menu
   SetIndexLabel(MODE_MA,        shortName);             // chart tooltips and "Data" window
   SetIndexLabel(MODE_TREND,     shortName +" trend");
   SetIndexLabel(MODE_UPTREND,   NULL);
   SetIndexLabel(MODE_DOWNTREND, NULL);
   SetIndexLabel(MODE_UPTREND2,  NULL);
   IndicatorDigits(Digits);
   SetIndicatorOptions();

   // calculate ALMA bar weights
   if (maMethod == MODE_ALMA) {
      double almaOffset=0.85, almaSigma=6.0;
      ALMA.CalculateWeights(MA.Periods, almaOffset, almaSigma, almaWeights);
   }
   return(catch("onInit(9)"));
}


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   // on the first tick after terminal start buffers may not yet be initialized (spurious issue)
   if (!ArraySize(main)) return(logInfo("onTick(1)  sizeof(main) = 0", SetLastError(ERS_TERMINAL_NOT_YET_READY)));

   // reset buffers before performing a full recalculation
   if (!ValidBars) {
      ArrayInitialize(main,      EMPTY_VALUE);
      ArrayInitialize(trend,               0);
      ArrayInitialize(uptrend,   EMPTY_VALUE);
      ArrayInitialize(downtrend, EMPTY_VALUE);
      ArrayInitialize(uptrend2,  EMPTY_VALUE);
      SetIndicatorOptions();
   }

   // synchronize buffers with a shifted offline chart
   if (ShiftedBars > 0) {
      ShiftDoubleIndicatorBuffer(main,      Bars, ShiftedBars, EMPTY_VALUE);
      ShiftDoubleIndicatorBuffer(trend,     Bars, ShiftedBars,           0);
      ShiftDoubleIndicatorBuffer(uptrend,   Bars, ShiftedBars, EMPTY_VALUE);
      ShiftDoubleIndicatorBuffer(downtrend, Bars, ShiftedBars, EMPTY_VALUE);
      ShiftDoubleIndicatorBuffer(uptrend2,  Bars, ShiftedBars, EMPTY_VALUE);
   }

   // calculate start bar
   int startbar = Min(MaxBarsBack-1, ChangedBars-1, Bars-MA.Periods);
   if (startbar < 0 && MaxBarsBack) return(logInfo("onTick(2)  Tick="+ Ticks, ERR_HISTORY_INSUFFICIENT));

   // recalculate changed bars
   for (int bar=startbar; bar >= 0; bar--) {
      if (maMethod == MODE_ALMA) {           // ALMA
         main[bar] = 0;
         for (int i=0; i < MA.Periods; i++) {
            main[bar] += almaWeights[i] * iMA(NULL, NULL, 1, 0, MODE_SMA, maAppliedPrice, bar+i);
         }
      }
      else {                                 // built-in moving averages
         main[bar] = iMA(NULL, NULL, MA.Periods, 0, maMethod, maAppliedPrice, bar);
      }
      UpdateTrendDirection(main, bar, trend, uptrend, downtrend, uptrend2, true, true, drawType, Digits);
   }

   if (!__isSuperContext) {
      if (__isChart && ShowChartLegend) UpdateTrendLegend(legendLabel, indicatorName, legendInfo, UpTrend.Color, DownTrend.Color, main[0], trend[0]);

      // signal trend changes
      if (Signal.onTrendChange) /*&&*/ if (IsBarOpen()) {
         int iTrend = Round(trend[1]);
         if      (iTrend ==  1) onTrendChange(MODE_UPTREND);
         else if (iTrend == -1) onTrendChange(MODE_DOWNTREND);
      }
   }
   return(last_error);
}


/**
 * Event handler for trend changes.
 *
 * @param  int trend - direction
 *
 * @return bool - success status
 */
bool onTrendChange(int trend) {
   string message="", accountTime="("+ TimeToStr(TimeLocalEx("onTrendChange(1)"), TIME_MINUTES|TIME_SECONDS) +", "+ GetAccountAlias() +")";
   int error = NO_ERROR;

   if (trend == MODE_UPTREND) {
      message = indicatorName +" turned up (market: "+ NumberToStr((Bid+Ask)/2, PriceFormat) +")";
      if (IsLogInfo()) logInfo("onTrendChange(2)  "+ message);
      message = Symbol() +","+ PeriodDescription() +": "+ message;

      if (signal.alert)          Alert(message);
      if (signal.sound) error |= PlaySoundEx(Signal.Sound.Up);
      if (signal.mail)  error |= !SendEmail("", "", message, message + NL + accountTime);
      if (signal.sms)   error |= !SendSMS("", message + NL + accountTime);
      return(!error);
   }

   if (trend == MODE_DOWNTREND) {
      message = indicatorName +" turned down (market: "+ NumberToStr((Bid+Ask)/2, PriceFormat) +")";
      if (IsLogInfo()) logInfo("onTrendChange(3)  "+ message);
      message = Symbol() +","+ PeriodDescription() +": "+ message;

      if (signal.alert)          Alert(message);
      if (signal.sound) error |= PlaySoundEx(Signal.Sound.Down);
      if (signal.mail)  error |= !SendEmail("", "", message, message + NL + accountTime);
      if (signal.sms)   error |= !SendSMS("", message + NL + accountTime);
      return(!error);
   }

   return(!catch("onTrendChange(4)  invalid parameter trend: "+ trend, ERR_INVALID_PARAMETER));
}


/**
 * Workaround for various terminal bugs when setting indicator options. Usually options are set in init(). However after
 * recompilation options must be set in start() to not be ignored.
 */
void SetIndicatorOptions() {
   //SetIndexStyle(int buffer, int drawType, int lineStyle=EMPTY, int drawWidth=EMPTY, color drawColor=NULL)
   int draw_type = ifInt(drawType==DRAW_LINE, drawType, DRAW_NONE);
   SetIndexStyle(MODE_MA,        draw_type, EMPTY, Draw.Width+Background.Width, Background.Color);

   draw_type = ifInt(Draw.Width, drawType, DRAW_NONE);
   SetIndexStyle(MODE_TREND,     DRAW_NONE, EMPTY, EMPTY,      CLR_NONE       );
   SetIndexStyle(MODE_UPTREND,   draw_type, EMPTY, Draw.Width, UpTrend.Color  ); SetIndexArrow(MODE_UPTREND,   158);
   SetIndexStyle(MODE_DOWNTREND, draw_type, EMPTY, Draw.Width, DownTrend.Color); SetIndexArrow(MODE_DOWNTREND, 158);
   SetIndexStyle(MODE_UPTREND2,  draw_type, EMPTY, Draw.Width, UpTrend.Color  ); SetIndexArrow(MODE_UPTREND2,  158);
}


/**
 * Return a string representation of the input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("MA.Periods=",                 MA.Periods,                                 ";", NL,
                            "MA.Method=",                  DoubleQuoteStr(MA.Method),                  ";", NL,
                            "MA.AppliedPrice=",            DoubleQuoteStr(MA.AppliedPrice),            ";", NL,

                            "UpTrend.Color=",              ColorToStr(UpTrend.Color),                  ";", NL,
                            "DownTrend.Color=",            ColorToStr(DownTrend.Color),                ";", NL,
                            "Draw.Type=",                  DoubleQuoteStr(Draw.Type),                  ";", NL,
                            "Draw.Width=",                 Draw.Width,                                 ";", NL,
                            "Background.Color=",           ColorToStr(Background.Color),               ";", NL,
                            "Background.Width=",           Background.Width,                           ";", NL,
                            "ShowChartLegend=",            BoolToStr(ShowChartLegend),                 ";", NL,
                            "MaxBarsBack=",                MaxBarsBack,                                ";", NL,

                            "Signal.onTrendChange=",       BoolToStr(Signal.onTrendChange),            ";", NL,
                            "Signal.onTrendChange.Types=", DoubleQuoteStr(Signal.onTrendChange.Types), ";", NL,
                            "Signal.Sound.Up=",            DoubleQuoteStr(Signal.Sound.Up),            ";", NL,
                            "Signal.Sound.Down=",          DoubleQuoteStr(Signal.Sound.Down),          ";")
   );
}
