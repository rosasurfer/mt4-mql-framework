/**
 * MA Channel
 *
 * An indicator forming a High/Low channel around a Moving Average. The indicator can display up to 3 separate channels.
 * This indicator is the core element of the XARD Trend indicator.
 *
 *
 * Input parameters
 * ----------------
 *  • ...
 *  • ...
 *
 *
 * Usage with iCustom()
 * --------------------
 * @see /mql40/include/rsf/functions/iCustom/MaChannel.mqh
 *
 *
 * TODO:
 *  - add input "Channel.Width" = 100% (percent of High/Low range)
 */
#include <rsf/stddefines.mqh>
int   __InitFlags[];
int __DeinitFlags[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern string ___a__________________________ = "=== MA definitions ===";
extern string MA1.Method  = "SMA* | LWMA | EMA | SMMA | ALMA";
extern int    MA1.Periods = 100;
extern color  MA1.Color   = Magenta;

extern string MA2.Method  = "SMA* | LWMA | EMA | SMMA | ALMA";
extern int    MA2.Periods = 0;
extern color  MA2.Color   = Blue;

extern string MA3.Method  = "SMA* | LWMA | EMA | SMMA | ALMA";
extern int    MA3.Periods = 0;
extern color  MA3.Color   = Red;

extern string ___b__________________________ = "=== Display options ===";
extern bool   ShowChartLegend                = true;
extern int    MaxBarsBack                    = 10000;                   // max. values to calculate (-1: all available)

extern string ___c__________________________ = "=== Signaling ===";
extern bool   Signal.onBarCross              = false;                   // on BarClose crossing the most outer channel
extern string Signal.onBarCross.Types        = "sound* | alert | mail | telegram";
extern string Signal.Sound.Up                = "Signal Up.wav";
extern string Signal.Sound.Down              = "Signal Down.wav";

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <rsf/core/indicator.mqh>
#include <rsf/stdfunctions.mqh>
#include <rsf/stdlib.mqh>
#include <rsf/functions/chartlegend.mqh>
#include <rsf/functions/ConfigureSignals.mqh>
#include <rsf/functions/IsBarOpen.mqh>
#include <rsf/functions/ObjectCreateRegister.mqh>
#include <rsf/functions/iCustom/MaChannel.mqh>
#include <rsf/win32api.mqh>

#define MODE_MA1_UPPER_BAND   MaChannel.MODE_MA1_UPPER_BAND    // 0 indicator buffer ids
#define MODE_MA1_LOWER_BAND   MaChannel.MODE_MA1_LOWER_BAND    // 1
#define MODE_MA2_UPPER_BAND   MaChannel.MODE_MA2_UPPER_BAND    // 2
#define MODE_MA2_LOWER_BAND   MaChannel.MODE_MA2_LOWER_BAND    // 3
#define MODE_MA3_UPPER_BAND   MaChannel.MODE_MA3_UPPER_BAND    // 4
#define MODE_MA3_LOWER_BAND   MaChannel.MODE_MA3_LOWER_BAND    // 5

#property indicator_chart_window
#property indicator_buffers   6                          // visible buffers

#property indicator_color1    CLR_NONE
#property indicator_color2    CLR_NONE
#property indicator_color3    CLR_NONE

int    ma1.method;                                       // MA definition
int    ma1.periods;                                      //
double ma1.upperBand[];                                  // indicator buffers
double ma1.lowerBand[];                                  //

int    ma2.method;
int    ma2.periods;
double ma2.upperBand[];
double ma2.lowerBand[];

int    ma3.method;
int    ma3.periods;
double ma3.upperBand[];
double ma3.lowerBand[];

int    maxMaPeriods;

string indicatorName = "";
string legendLabel   = "";
string legendInfo    = "";

bool   signal.sound;
bool   signal.alert;
bool   signal.mail;
bool   signal.telegram;

#define D_LONG  TRADE_DIRECTION_LONG                     // signal direction types
#define D_SHORT TRADE_DIRECTION_SHORT                    //


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   // input validation
   string indicator = WindowExpertName();

   // MA1.Periods (must be checked before MA.Method)
   if (AutoConfiguration) MA1.Periods = GetConfigInt(indicator, "MA1.Periods", MA1.Periods);
   if (MA1.Periods < 0)  return(catch("onInit(1)  invalid input parameter MA1.Periods: "+ MA1.Periods +" (must be >= zero)", ERR_INVALID_INPUT_PARAMETER));
   ma1.periods = MA1.Periods;
   // MA1.Method
   if (!ma1.periods) {
      MA1.Method = "";
   }
   else {
      if (AutoConfiguration) MA1.Method = GetConfigString(indicator, "MA1.Method", MA1.Method);
      string sValues[], sValue = MA1.Method;
      if (Explode(sValue, "*", sValues, 2) > 1) {
         int size = Explode(sValues[0], "|", sValues, NULL);
         sValue = sValues[size-1];
      }
      ma1.method = StrToMaMethod(sValue, F_PARTIAL_ID|F_ERR_INVALID_PARAMETER);
      if (ma1.method == -1) return(catch("onInit(2)  invalid input parameter MA1.Method: "+ DoubleQuoteStr(MA1.Method), ERR_INVALID_INPUT_PARAMETER));
      MA1.Method = MaMethodDescription(ma1.method);
   }

   // MA2.Periods
   if (AutoConfiguration) MA2.Periods = GetConfigInt(indicator, "MA2.Periods", MA2.Periods);
   if (MA2.Periods < 0)  return(catch("onInit(3)  invalid input parameter MA2.Periods: "+ MA2.Periods +" (must be >= zero)", ERR_INVALID_INPUT_PARAMETER));
   ma2.periods = MA2.Periods;
   // MA2.Method
   if (!ma2.periods) {
      MA2.Method = "";
   }
   else {
      if (AutoConfiguration) MA2.Method = GetConfigString(indicator, "MA2.Method", MA2.Method);
      sValue = MA2.Method;
      if (Explode(sValue, "*", sValues, 2) > 1) {
         size = Explode(sValues[0], "|", sValues, NULL);
         sValue = sValues[size-1];
      }
      ma2.method = StrToMaMethod(sValue, F_PARTIAL_ID|F_ERR_INVALID_PARAMETER);
      if (ma2.method == -1) return(catch("onInit(4)  invalid input parameter MA2.Method: "+ DoubleQuoteStr(MA2.Method), ERR_INVALID_INPUT_PARAMETER));
      MA2.Method = MaMethodDescription(ma2.method);
   }

   // MA3.Periods
   if (AutoConfiguration) MA3.Periods = GetConfigInt(indicator, "MA3.Periods", MA3.Periods);
   if (MA3.Periods < 0)  return(catch("onInit(5)  invalid input parameter MA3.Periods: "+ MA3.Periods +" (must be >= zero)", ERR_INVALID_INPUT_PARAMETER));
   ma3.periods = MA3.Periods;
   // MA3.Method
   if (!ma3.periods) {
      MA3.Method = "";
   }
   else {
      if (AutoConfiguration) MA3.Method = GetConfigString(indicator, "MA3.Method", MA3.Method);
      sValue = MA3.Method;
      if (Explode(sValue, "*", sValues, 2) > 1) {
         size = Explode(sValues[0], "|", sValues, NULL);
         sValue = sValues[size-1];
      }
      ma3.method = StrToMaMethod(sValue, F_PARTIAL_ID|F_ERR_INVALID_PARAMETER);
      if (ma3.method == -1) return(catch("onInit(6)  invalid input parameter MA3.Method: "+ DoubleQuoteStr(MA3.Method), ERR_INVALID_INPUT_PARAMETER));
      MA3.Method = MaMethodDescription(ma3.method);
   }
   maxMaPeriods = Max(ma1.periods, ma2.periods, ma3.periods);
   if (!maxMaPeriods)    return(catch("onInit(7)  invalid MA definitions: at least one MA needs a period value", ERR_INVALID_INPUT_PARAMETER));

   // colors: after deserialization the terminal may turn CLR_NONE (0xFFFFFFFF) into Black (0xFF000000)
   if (AutoConfiguration) MA1.Color = GetConfigColor(indicator, "MA1.Color", MA1.Color);
   if (AutoConfiguration) MA2.Color = GetConfigColor(indicator, "MA2.Color", MA2.Color);
   if (AutoConfiguration) MA3.Color = GetConfigColor(indicator, "MA3.Color", MA3.Color);
   if (MA1.Color == 0xFF000000) MA1.Color = CLR_NONE;
   if (MA2.Color == 0xFF000000) MA2.Color = CLR_NONE;
   if (MA3.Color == 0xFF000000) MA3.Color = CLR_NONE;

   // ShowChartLegend
   if (AutoConfiguration) ShowChartLegend = GetConfigBool(indicator, "ShowChartLegend", ShowChartLegend);
   // MaxBarsBack
   if (AutoConfiguration) MaxBarsBack = GetConfigInt(indicator, "MaxBarsBack", MaxBarsBack);
   if (MaxBarsBack < -1)               return(catch("onInit(8)  invalid input parameter MaxBarsBack: "+ MaxBarsBack, ERR_INVALID_INPUT_PARAMETER));
   if (MaxBarsBack == -1) MaxBarsBack = INT_MAX;

   // Signal.onBarCross
   string signalId = "Signal.onBarCross";
   legendInfo = "";
   if (!ConfigureSignals(signalId, AutoConfiguration, Signal.onBarCross)) return(last_error);
   if (Signal.onBarCross) {
      if (!ConfigureSignalTypes(signalId, Signal.onBarCross.Types, AutoConfiguration, signal.sound, signal.alert, signal.mail, signal.telegram)) {
         return(catch("onInit(9)  invalid input parameter Signal.onBarCross.Types: "+ DoubleQuoteStr(Signal.onBarCross.Types), ERR_INVALID_INPUT_PARAMETER));
      }
      Signal.onBarCross = (signal.sound || signal.alert || signal.mail || signal.telegram);
      if (Signal.onBarCross) legendInfo = "("+ StrLeft(ifString(signal.sound, "sound,", "") + ifString(signal.alert, "alert,", "") + ifString(signal.mail, "mail,", "") + ifString(signal.telegram, "tgm,", ""), -1) +")";
   }
   // Signal.Sound.*
   if (AutoConfiguration) Signal.Sound.Up   = GetConfigString(indicator, "Signal.Sound.Up",   Signal.Sound.Up);
   if (AutoConfiguration) Signal.Sound.Down = GetConfigString(indicator, "Signal.Sound.Down", Signal.Sound.Down);

   // chart legend
   if (ShowChartLegend) legendLabel = CreateChartLegend();

   SetIndicatorOptions();
   return(catch("onInit(10)"));
}


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   // reset buffers before performing a full recalculation
   if (!ValidBars) {
      ArrayInitialize(ma1.upperBand, EMPTY_VALUE);
      ArrayInitialize(ma1.lowerBand, EMPTY_VALUE);
      ArrayInitialize(ma2.upperBand, EMPTY_VALUE);
      ArrayInitialize(ma2.lowerBand, EMPTY_VALUE);
      ArrayInitialize(ma3.upperBand, EMPTY_VALUE);
      ArrayInitialize(ma3.lowerBand, EMPTY_VALUE);
      SetIndicatorOptions();
   }

   // synchronize buffers with a shifted offline chart
   if (ShiftedBars > 0) {
      ShiftDoubleIndicatorBuffer(ma1.upperBand, Bars, ShiftedBars, EMPTY_VALUE);
      ShiftDoubleIndicatorBuffer(ma1.lowerBand, Bars, ShiftedBars, EMPTY_VALUE);
      ShiftDoubleIndicatorBuffer(ma2.upperBand, Bars, ShiftedBars, EMPTY_VALUE);
      ShiftDoubleIndicatorBuffer(ma2.lowerBand, Bars, ShiftedBars, EMPTY_VALUE);
      ShiftDoubleIndicatorBuffer(ma3.upperBand, Bars, ShiftedBars, EMPTY_VALUE);
      ShiftDoubleIndicatorBuffer(ma3.lowerBand, Bars, ShiftedBars, EMPTY_VALUE);
   }

   // calculate start bar
   int startbar = Min(MaxBarsBack-1, ChangedBars-1, Bars-maxMaPeriods);
   if (startbar < 0 && MaxBarsBack) return(logInfo("onTick(1)  Tick="+ Ticks, ERR_HISTORY_INSUFFICIENT));

   // recalculate changed bars
   for (int bar=startbar; bar >= 0; bar--) {
      if (ma1.periods > 0) {
         ma1.upperBand[bar] = iMA(NULL, NULL, ma1.periods, 0, ma1.method, PRICE_HIGH, bar);
         ma1.lowerBand[bar] = iMA(NULL, NULL, ma1.periods, 0, ma1.method, PRICE_LOW,  bar);
      }
      if (ma2.periods > 0) {
         ma2.upperBand[bar] = iMA(NULL, NULL, ma2.periods, 0, ma2.method, PRICE_HIGH, bar);
         ma2.lowerBand[bar] = iMA(NULL, NULL, ma2.periods, 0, ma2.method, PRICE_LOW,  bar);
      }
      if (ma3.periods > 0) {
         ma3.upperBand[bar] = iMA(NULL, NULL, ma3.periods, 0, ma3.method, PRICE_HIGH, bar);
         ma3.lowerBand[bar] = iMA(NULL, NULL, ma3.periods, 0, ma3.method, PRICE_LOW,  bar);
      }
   }

   if (__isChart && !__isSuperContext) {
      //if (ShowChartLegend) UpdateBandLegend(legendLabel, indicatorName, legendInfo, Channel.Color, upperBand[0], lowerBand[0]);

      // monitor signals
      if (Signal.onBarCross) /*&&*/ if (IsBarOpen()) {
         if      (false) onCross(D_LONG);
         else if (false) onCross(D_SHORT);
      }
   }
   return(last_error);
}


/**
 * Event handler signaling channel crossings.
 *
 * @param  int direction - crossing direction: D_LONG | D_SHORT
 *
 * @return bool - success status
 */
bool onCross(int direction) {
   if (direction!=D_LONG && direction!=D_SHORT) return(!catch("onCross(1)  invalid parameter direction: "+ direction, ERR_INVALID_PARAMETER));
   if (!Signal.onBarCross) return(false);
   if (ChangedBars > 2)    return(false);

   // skip the signal if it was already handled elsewhere
   string sPeriod   = PeriodDescription();
   string eventName = "rsf::"+ StdSymbol() +","+ sPeriod +"."+ indicatorName +".onCross("+ direction +")."+ TimeToStr(Time[0]), propertyName = "";
   string message1  = "bar close "+ ifString(direction==D_LONG, "above ", "below ") + indicatorName;
   string message2  = Symbol() +","+ sPeriod +": "+ message1;
   string localTime = TimeToStr(TimeLocalEx("onCross(2)"), TIME_MINUTES|TIME_SECONDS);
   string accountAlias = GetAccountAlias();

   int hWndTerminal = GetTerminalMainWindow(), hWndDesktop = GetDesktopWindow();
   bool eventAction;

   // log: once per terminal
   if (IsLogInfo()) {
      eventAction = true;
      if (!__isTesting) {
         propertyName = eventName +"|log";
         eventAction = !GetWindowPropertyA(hWndTerminal, propertyName);
         SetWindowPropertyA(hWndTerminal, propertyName, 1);
      }
      if (eventAction) logInfo("onCross(3)  "+ message1);
   }

   // sound: once per system
   if (signal.sound) {
      eventAction = true;
      if (!__isTesting) {
         propertyName = eventName +"|sound";
         eventAction = !GetWindowPropertyA(hWndDesktop, propertyName);
         SetWindowPropertyA(hWndDesktop, propertyName, 1);
      }
      if (eventAction) PlaySoundEx(ifString(direction==D_LONG, Signal.Sound.Up, Signal.Sound.Down));
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
      if (eventAction) SendEmail("", "", message2, message2 + NL +"("+ localTime +", "+ accountAlias +")");
   }

   // telegram: once per system
   if (signal.telegram) {
      eventAction = true;
      if (!__isTesting) {
         propertyName = eventName +"|telegram";
         eventAction = !GetWindowPropertyA(hWndDesktop, propertyName);
         SetWindowPropertyA(hWndDesktop, propertyName, 1);
      }
      if (eventAction) SendTelegramMessage("signal", message2 + NL +"("+ localTime +", "+ accountAlias +")");
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
   redraw = (redraw != 0);
   indicatorName = GetChannelDescription();
   IndicatorShortName(indicatorName);

   IndicatorBuffers(indicator_buffers);
   IndicatorDigits(Digits);

   SetIndexBuffer(MODE_MA1_UPPER_BAND, ma1.upperBand);
   SetIndexBuffer(MODE_MA1_LOWER_BAND, ma1.lowerBand);
   SetIndexStyle (MODE_MA1_UPPER_BAND, DRAW_LINE, EMPTY, EMPTY, MA1.Color);
   SetIndexStyle (MODE_MA1_LOWER_BAND, DRAW_LINE, EMPTY, EMPTY, MA1.Color);
   SetIndexLabel (MODE_MA1_UPPER_BAND, MA1.Method +"("+ MA1.Periods +") upper band");
   SetIndexLabel (MODE_MA1_LOWER_BAND, MA1.Method +"("+ MA1.Periods +") lower band");

   SetIndexBuffer(MODE_MA2_UPPER_BAND, ma2.upperBand);
   SetIndexBuffer(MODE_MA2_LOWER_BAND, ma2.lowerBand);
   SetIndexStyle (MODE_MA2_UPPER_BAND, DRAW_LINE, EMPTY, EMPTY, MA2.Color);
   SetIndexStyle (MODE_MA2_LOWER_BAND, DRAW_LINE, EMPTY, EMPTY, MA2.Color);
   SetIndexLabel (MODE_MA2_UPPER_BAND, MA2.Method +"("+ MA2.Periods +") upper band");
   SetIndexLabel (MODE_MA2_LOWER_BAND, MA2.Method +"("+ MA2.Periods +") lower band");

   SetIndexBuffer(MODE_MA3_UPPER_BAND, ma3.upperBand);
   SetIndexBuffer(MODE_MA3_LOWER_BAND, ma3.lowerBand);
   SetIndexStyle (MODE_MA3_UPPER_BAND, DRAW_LINE, EMPTY, EMPTY, MA3.Color);
   SetIndexStyle (MODE_MA3_LOWER_BAND, DRAW_LINE, EMPTY, EMPTY, MA3.Color);
   SetIndexLabel (MODE_MA3_UPPER_BAND, MA3.Method +"("+ MA3.Periods +") upper band");
   SetIndexLabel (MODE_MA3_LOWER_BAND, MA3.Method +"("+ MA3.Periods +") lower band");

   if (!ma1.periods) {
      SetIndexStyle(MODE_MA1_UPPER_BAND, DRAW_NONE);
      SetIndexStyle(MODE_MA1_LOWER_BAND, DRAW_NONE);
      SetIndexLabel(MODE_MA1_UPPER_BAND, NULL);
      SetIndexLabel(MODE_MA1_LOWER_BAND, NULL);
   }
   if (!ma2.periods) {
      SetIndexStyle(MODE_MA2_UPPER_BAND, DRAW_NONE);
      SetIndexStyle(MODE_MA2_LOWER_BAND, DRAW_NONE);
      SetIndexLabel(MODE_MA2_UPPER_BAND, NULL);
      SetIndexLabel(MODE_MA2_LOWER_BAND, NULL);
   }
   if (!ma3.periods) {
      SetIndexStyle(MODE_MA3_UPPER_BAND, DRAW_NONE);
      SetIndexStyle(MODE_MA3_LOWER_BAND, DRAW_NONE);
      SetIndexLabel(MODE_MA3_UPPER_BAND, NULL);
      SetIndexLabel(MODE_MA3_LOWER_BAND, NULL);
   }

   if (redraw) WindowRedraw();
   return(!catch("SetIndicatorOptions(1)"));
}


/**
 * Generate a channel description for the chart legend.
 *
 * @return string
 */
string GetChannelDescription() {
   string sameMethods = "", differentMethods = "";
   bool allSameMethod = true;

   if (ma1.periods > 0) {
      sameMethods      = MA1.Method +"("+ MA1.Periods;
      differentMethods = differentMethods +","+ MA1.Method +"("+ MA1.Periods +")";
   }
   if (ma2.periods > 0) {
      sameMethods      = sameMethods +","+ MA2.Periods;
      differentMethods = differentMethods +","+ MA2.Method +"("+ MA2.Periods +")";

      if (ma1.periods > 0) {
         allSameMethod = (ma1.method == ma2.method);
      }
   }
   if (ma3.periods > 0) {
      sameMethods      = sameMethods +","+ MA3.Periods;
      differentMethods = differentMethods +","+ MA3.Method +"("+ MA3.Periods +")";

      if (ma1.periods > 0) {
         allSameMethod = (ma1.method == ma3.method);
      }
      if (ma2.periods > 0) {
         allSameMethod = (ma2.method == ma3.method);
      }
   }
   sameMethods      = sameMethods +") Channel";
   differentMethods = StrRight(differentMethods, -1) +" Channel";

   if (allSameMethod)
      return(sameMethods);
   return(differentMethods);
}


/**
 * Return a string representation of all input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate(
      "MA1.Method=",              DoubleQuoteStr(MA1.Method),              ";", NL,
      "MA1.Periods=",             MA1.Periods,                             ";", NL,
      "MA1.Color=",               ColorToStr(MA1.Color),                   ";", NL,

      "MA2.Method=",              DoubleQuoteStr(MA2.Method),              ";", NL,
      "MA2.Periods=",             MA2.Periods,                             ";", NL,
      "MA2.Color=",               ColorToStr(MA2.Color),                   ";", NL,

      "MA3.Method=",              DoubleQuoteStr(MA3.Method),              ";", NL,
      "MA3.Periods=",             MA3.Periods,                             ";", NL,
      "MA3.Color=",               ColorToStr(MA3.Color),                   ";", NL,

      "ShowChartLegend=",         BoolToStr(ShowChartLegend),              ";", NL,
      "MaxBarsBack=",             MaxBarsBack,                             ";", NL,

      "Signal.onBarCross=",       BoolToStr(Signal.onBarCross),            ";", NL,
      "Signal.onBarCross.Types=", DoubleQuoteStr(Signal.onBarCross.Types), ";", NL,
      "Signal.Sound.Up=",         DoubleQuoteStr(Signal.Sound.Up),         ";", NL,
      "Signal.Sound.Down=",       DoubleQuoteStr(Signal.Sound.Down),       ";", NL
   ));

   // suppress compiler warnings
   icMaChannel(NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
}
