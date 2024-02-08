/**
 * JMA - Jurik Moving Average
 *
 * A non-repainting version with sources based on the original Jurik algorithm published by Nikolay Kositsin.
 *
 * Indicator buffers for iCustom():
 *  • MovingAverage.MODE_MA:    MA values
 *  • MovingAverage.MODE_TREND: trend direction and length
 *    - trend direction:        positive values denote an uptrend (+1...+n), negative values a downtrend (-1...-n)
 *    - trend length:           the absolute direction value is the length of the trend in bars since the last reversal
 *
 * @link  http://www.jurikres.com/catalog1/ms_ama.htm
 * @link  https://www.mql5.com/en/articles/1450
 */
#include <stddefines.mqh>
int   __InitFlags[];
int __DeinitFlags[];

/*
-----------------------------------------------------------------------------------------------------------------------------

// @author  everget
// @version 1                                                                                      http://www.tradingview.com
//
// Copyright (c) 2007-present Jurik Research and Consulting. All rights reserved.
// Copyright (c) 2018-present, Alex Orekhov (everget)
// Jurik Moving Average script may be freely distributed under the MIT license.
study("Jurik Moving Average", shorttitle="JMA", overlay=true)

length = input(title="Length", type=integer, defval=14)
power = input(title="Power", type=integer, defval=1)
rMult = input(title="R Multiplier", type=float, step=0.1, defval=2.5)
src = input(title="Source", type=source, defval=close)

jma(src, length, power, rMult) =>
    beta = 0.45 * (length - 1) / (0.45 * (length - 1) + 2)
    alpha = pow(beta, power)

    e0 = 0.0
    e1 = 0.0
    e2 = 0.0
    jma = 0.0

    e0 := (1 - alpha) * src + alpha * nz(e0[1])
    e1 := (src - e0) * (1 - beta) + beta * nz(e1[1])
    e2 := pow(1 - alpha, 2) * (e0 + rMult * e1 - nz(jma[1])) + pow(alpha, 2) * nz(e2[1])
    jma := nz(jma[1]) + e2

plot(jma(src, length, power, rMult), title="JMA", linewidth=2, color=#6d1e7f, transp=0)

-----------------------------------------------------------------------------------------------------------------------------

// @author  everget
// @version 2
//
// Copyright (c) 2007-present Jurik Research and Consulting. All rights reserved.
// Copyright (c) 2018-present, Alex Orekhov (everget)
// Jurik Moving Average script may be freely distributed under the MIT license.
study("Jurik Moving Average", shorttitle="JMA", overlay=true)

length = input(title="Length", type=integer, defval=7)
phase = input(title="Phase", type=integer, defval=50)
power = input(title="Power", type=integer, defval=2)
src = input(title="Source", type=source, defval=close)
highlightMovements = input(title="Highlight Movements ?", type=bool, defval=true)

phaseRatio = phase < -100 ? 0.5 : phase > 100 ? 2.5 : phase / 100 + 1.5

beta = 0.45 * (length - 1) / (0.45 * (length - 1) + 2)
alpha = pow(beta, power)

jma = 0.0

e0 = 0.0
e0 := (1 - alpha) * src + alpha * nz(e0[1])

e1 = 0.0
e1 := (src - e0) * (1 - beta) + beta * nz(e1[1])

e2 = 0.0
e2 := (e0 + phaseRatio * e1 - nz(jma[1])) * pow(1 - alpha, 2) + pow(alpha, 2) * nz(e2[1])

jma := e2 + nz(jma[1])

jmaColor = highlightMovements ? (jma > jma[1] ? green : red) : #6d1e7f
plot(jma, title="JMA", linewidth=2, color=jmaColor, transp=0)

-----------------------------------------------------------------------------------------------------------------------------

// @author  everget
// @version 3                                               https://www.tradingview.com/script/nZuBWW9j-Jurik-Moving-Average/
//
// Copyright (c) 2007-present Jurik Research and Consulting. All rights reserved.
// Copyright (c) 2018-present, Alex Orekhov (everget)
// Jurik Moving Average script may be freely distributed under the MIT license.
study("Jurik Moving Average", shorttitle="JMA", overlay=true)

length = input(title="Length", type=integer, defval=7)
phase = input(title="Phase", type=integer, defval=50)
power = input(title="Power", type=integer, defval=2)
src = input(title="Source", type=source, defval=close)
highlightMovements = input(title="Highlight Movements ?", type=bool, defval=true)

phaseRatio = phase < -100 ? 0.5 : phase > 100 ? 2.5 : phase / 100 + 1.5

beta = 0.45 * (length - 1) / (0.45 * (length - 1) + 2)
alpha = pow(beta, power)

jma = 0.0

e0 = 0.0
e0 := (1 - alpha) * src + alpha * nz(e0[1])

e1 = 0.0
e1 := (src - e0) * (1 - beta) + beta * nz(e1[1])

e2 = 0.0
e2 := (e0 + phaseRatio * e1 - nz(jma[1])) * pow(1 - alpha, 2) + pow(alpha, 2) * nz(e2[1])

jma := e2 + nz(jma[1])

jmaColor = highlightMovements ? (jma > jma[1] ? green : red) : #6d1e7f
plot(jma, title="JMA", linewidth=2, color=jmaColor, transp=0)

-----------------------------------------------------------------------------------------------------------------------------
*/

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern int    Periods                        = 14;
extern int    Phase                          = 0;        // indicator overshooting: -100 (none)...+100 (max)
extern string AppliedPrice                   = "Open | High | Low | Close* | Median | Typical | Weighted";

extern color  Color.UpTrend                  = Blue;
extern color  Color.DownTrend                = Red;
extern string Draw.Type                      = "Line* | Dot";
extern int    Draw.Width                     = 3;

extern string ___a__________________________ = "=== Signaling ===";
extern bool   Signal.onTrendChange           = false;
extern bool   Signal.onTrendChange.Sound     = true;
extern string Signal.onTrendChange.SoundUp   = "Signal Up.wav";
extern string Signal.onTrendChange.SoundDown = "Signal Down.wav";
extern bool   Signal.onTrendChange.Popup     = false;
extern bool   Signal.onTrendChange.Mail      = false;
extern bool   Signal.onTrendChange.SMS       = false;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <rsfLib.mqh>
#include <functions/chartlegend.mqh>
#include <functions/ConfigureSignals.mqh>
#include <functions/IsBarOpen.mqh>
#include <functions/trend.mqh>
#include <functions/ta/JMA.mqh>

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

double main     [];                                      // MA main values:      invisible, displayed in legend and "Data" window
double trend    [];                                      // trend direction:     invisible, displayed in "Data" window
double uptrend  [];                                      // uptrend values:      visible
double downtrend[];                                      // downtrend values:    visible
double uptrend2 [];                                      // single-bar uptrends: visible

int    appliedPrice;
int    drawType;

string indicatorName = "";
string legendLabel   = "";
string legendInfo    = "";                               // additional chart legend info


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   // validate inputs
   // Periods
   if (Periods  < 1)   return(catch("onInit(1)  invalid input parameter Periods: "+ Periods, ERR_INVALID_INPUT_PARAMETER));
   // Phase
   if (Phase < -100)   return(catch("onInit(2)  invalid input parameter Phase: "+ Phase +" (-100..+100)", ERR_INVALID_INPUT_PARAMETER));
   if (Phase > +100)   return(catch("onInit(3)  invalid input parameter Phase: "+ Phase +" (-100..+100)", ERR_INVALID_INPUT_PARAMETER));
   // AppliedPrice
   string sValues[], sValue = StrToLower(AppliedPrice);
   if (Explode(sValue, "*", sValues, 2) > 1) {
      int size = Explode(sValues[0], "|", sValues, NULL);
      sValue = sValues[size-1];
   }
   sValue = StrTrim(sValue);
   if (sValue == "") sValue = "close";                // default price type
   appliedPrice = StrToPriceType(sValue, F_PARTIAL_ID|F_ERR_INVALID_PARAMETER);
   if (appliedPrice==-1 || appliedPrice > PRICE_WEIGHTED)
                       return(catch("onInit(4)  invalid input parameter AppliedPrice: "+ DoubleQuoteStr(AppliedPrice), ERR_INVALID_INPUT_PARAMETER));
   AppliedPrice = PriceTypeDescription(appliedPrice);
   // colors: after deserialization the terminal might turn CLR_NONE (0xFFFFFFFF) into Black (0xFF000000)
   if (Color.UpTrend   == 0xFF000000) Color.UpTrend   = CLR_NONE;
   if (Color.DownTrend == 0xFF000000) Color.DownTrend = CLR_NONE;
   // Draw.Type
   sValue = StrToLower(Draw.Type);
   if (Explode(sValue, "*", sValues, 2) > 1) {
      size = Explode(sValues[0], "|", sValues, NULL);
      sValue = sValues[size-1];
   }
   sValue = StrTrim(sValue);
   if      (StrStartsWith("line", sValue)) { drawType = DRAW_LINE;  Draw.Type = "Line"; }
   else if (StrStartsWith("dot",  sValue)) { drawType = DRAW_ARROW; Draw.Type = "Dot";  }
   else                return(catch("onInit(5)  invalid input parameter Draw.Type: "+ DoubleQuoteStr(Draw.Type), ERR_INVALID_INPUT_PARAMETER));
   // Draw.Width
   if (Draw.Width < 0) return(catch("onInit(6)  invalid input parameter Draw.Width: "+ Draw.Width, ERR_INVALID_INPUT_PARAMETER));

   // signaling
   string signalId = "Signal.onTrendChange";
   legendInfo = "";
   if (!ConfigureSignals(signalId, AutoConfiguration, Signal.onTrendChange)) return(last_error);
   if (Signal.onTrendChange) {
      if (!ConfigureSignalsBySound(signalId, AutoConfiguration, Signal.onTrendChange.Sound)) return(last_error);
      if (!ConfigureSignalsByPopup(signalId, AutoConfiguration, Signal.onTrendChange.Popup)) return(last_error);
      if (!ConfigureSignalsByMail (signalId, AutoConfiguration, Signal.onTrendChange.Mail))  return(last_error);
      if (!ConfigureSignalsBySMS  (signalId, AutoConfiguration, Signal.onTrendChange.SMS))   return(last_error);
      if (Signal.onTrendChange.Sound || Signal.onTrendChange.Popup || Signal.onTrendChange.Mail || Signal.onTrendChange.SMS) {
         legendInfo = StrLeft(ifString(Signal.onTrendChange.Sound, "sound,", "") + ifString(Signal.onTrendChange.Popup, "popup,", "") + ifString(Signal.onTrendChange.Mail, "mail,", "") + ifString(Signal.onTrendChange.SMS, "sms,", ""), -1);
         legendInfo = "("+ legendInfo +")";
      }
      else Signal.onTrendChange = false;
   }

   // buffer management
   SetIndexBuffer(MODE_MA,        main     );            // MA main values:      invisible, displayed in legend and "Data" window
   SetIndexBuffer(MODE_TREND,     trend    );            // trend direction:     invisible, displayed in "Data" window
   SetIndexBuffer(MODE_UPTREND,   uptrend  );            // uptrend values:      visible
   SetIndexBuffer(MODE_DOWNTREND, downtrend);            // downtrend values:    visible
   SetIndexBuffer(MODE_UPTREND2,  uptrend2 );            // single-bar uptrends: visible

   // names, labels and display options
   legendLabel = CreateChartLegend();
   string sPhase = ifString(!Phase, "", ", Phase="+ Phase);
   string sAppliedPrice = ifString(appliedPrice==PRICE_CLOSE, "", ", "+ PriceTypeDescription(appliedPrice));
   indicatorName = WindowExpertName() +"("+ Periods + sPhase + sAppliedPrice +")";
   string shortName = "JMA("+ Periods +")";
   IndicatorShortName(shortName);                        // chart tooltips and context menu
   SetIndexLabel(MODE_MA,        shortName);             // chart tooltips and "Data" window
   SetIndexLabel(MODE_TREND,     shortName +" trend");
   SetIndexLabel(MODE_UPTREND,   NULL);
   SetIndexLabel(MODE_DOWNTREND, NULL);
   SetIndexLabel(MODE_UPTREND2,  NULL);
   IndicatorDigits(Digits);
   SetIndicatorOptions();

   return(catch("onInit(7)"));
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
   if (Bars < 32) return(logInfo("onTick(2)  Tick="+ Ticks, ERR_HISTORY_INSUFFICIENT));
   int validBars = ValidBars, error;
   if (validBars > 0) validBars--;
   int oldestBar = Bars-1;
   int startbar  = oldestBar - validBars;                // TODO: startbar is 1 too big

   // recalculate changed bars
   for (int bar=startbar; bar >= 0; bar--) {
      double price = iMA(NULL, NULL, 1, 0, MODE_SMA, appliedPrice, bar);
      main[bar] = JMASeries(0, oldestBar, startbar, Periods, Phase, price, bar); if (last_error != 0) return(last_error);

      UpdateTrendDirection(main, bar, trend, uptrend, downtrend, uptrend2, true, true, drawType, Digits);
   }

   if (!__isSuperContext) {
      UpdateTrendLegend(legendLabel, indicatorName, legendInfo, Color.UpTrend, Color.DownTrend, main[0], trend[0]);

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
   int error = 0;

   if (trend == MODE_UPTREND) {
      message = indicatorName +" turned up (market: "+ NumberToStr((Bid+Ask)/2, PriceFormat) +")";
      if (IsLogInfo()) logInfo("onTrendChange(2)  "+ message);
      message = Symbol() +","+ PeriodDescription() +": "+ message;

      if (Signal.onTrendChange.Popup)          Alert(message);
      if (Signal.onTrendChange.Sound) error |= PlaySoundEx(Signal.onTrendChange.SoundUp);
      if (Signal.onTrendChange.Mail)  error |= !SendEmail("", "", message, message + NL + accountTime);
      if (Signal.onTrendChange.SMS)   error |= !SendSMS("", message + NL + accountTime);
      return(!error);
   }

   if (trend == MODE_DOWNTREND) {
      message = indicatorName +" turned down (market: "+ NumberToStr((Bid+Ask)/2, PriceFormat) +")";
      if (IsLogInfo()) logInfo("onTrendChange(3)  "+ message);
      message = Symbol() +","+ PeriodDescription() +": "+ message;

      if (Signal.onTrendChange.Popup)          Alert(message);
      if (Signal.onTrendChange.Sound) error |= PlaySoundEx(Signal.onTrendChange.SoundDown);
      if (Signal.onTrendChange.Mail)  error |= !SendEmail("", "", message, message + NL + accountTime);
      if (Signal.onTrendChange.SMS)   error |= !SendSMS("", message + NL + accountTime);
      return(!error);
   }

   return(!catch("onTrendChange(4)  invalid parameter trend: "+ trend, ERR_INVALID_PARAMETER));
}


/**
 * Workaround for various terminal bugs when setting indicator options. Usually options are set in init(). However after
 * recompilation options must be set in start() to not be ignored.
 */
void SetIndicatorOptions() {
   int draw_type = ifInt(Draw.Width, drawType, DRAW_NONE);

   SetIndexStyle(MODE_MA,        DRAW_NONE, EMPTY, EMPTY,      CLR_NONE       );
   SetIndexStyle(MODE_TREND,     DRAW_NONE, EMPTY, EMPTY,      CLR_NONE       );
   SetIndexStyle(MODE_UPTREND,   draw_type, EMPTY, Draw.Width, Color.UpTrend  ); SetIndexArrow(MODE_UPTREND,   158);
   SetIndexStyle(MODE_DOWNTREND, draw_type, EMPTY, Draw.Width, Color.DownTrend); SetIndexArrow(MODE_DOWNTREND, 158);
   SetIndexStyle(MODE_UPTREND2,  draw_type, EMPTY, Draw.Width, Color.UpTrend  ); SetIndexArrow(MODE_UPTREND2,  158);
}


/**
 * Return a string representation of the input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("Periods=",                        Periods,                                        ";", NL,
                            "Phase=",                          Phase,                                          ";", NL,
                            "AppliedPrice=",                   DoubleQuoteStr(AppliedPrice),                   ";", NL,
                            "Color.UpTrend=",                  ColorToStr(Color.UpTrend),                      ";", NL,
                            "Color.DownTrend=",                ColorToStr(Color.DownTrend),                    ";", NL,
                            "Draw.Type=",                      DoubleQuoteStr(Draw.Type),                      ";", NL,
                            "Draw.Width=",                     Draw.Width,                                     ";", NL,

                            "Signal.onTrendChange=",           BoolToStr(Signal.onTrendChange),                ";", NL,
                            "Signal.onTrendChange.Sound=",     BoolToStr(Signal.onTrendChange.Sound),          ";", NL,
                            "Signal.onTrendChange.SoundUp=",   DoubleQuoteStr(Signal.onTrendChange.SoundUp),   ";", NL,
                            "Signal.onTrendChange.SoundDown=", DoubleQuoteStr(Signal.onTrendChange.SoundDown), ";", NL,
                            "Signal.onTrendChange.Popup=",     BoolToStr(Signal.onTrendChange.Popup),          ";", NL,
                            "Signal.onTrendChange.Mail=",      BoolToStr(Signal.onTrendChange.Mail),           ";", NL,
                            "Signal.onTrendChange.SMS=",       BoolToStr(Signal.onTrendChange.SMS),            ";")
   );
}
