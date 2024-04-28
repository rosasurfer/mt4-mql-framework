/**
 * MA Tunnel
 *
 * An indicator for price crossing a High/Low channel (aka a tunnel) built from one or more Moving Averages.
 *
 *
 * TODO:
 *  - add input "Tunnel.Width" = 100% (percent of High/Low range)
 */
#include <stddefines.mqh>
int   __InitFlags[];
int __DeinitFlags[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern string Tunnel.Definition              = "EMA(144)";              // one or more MAs separated by ","
extern string Supported.MA.Methods           = "SMA, LWMA, EMA, SMMA";
extern color  Tunnel.Color                   = Magenta;
extern bool   ShowChartLegend                = true;
extern int    MaxBarsBack                    = 10000;                   // max. values to calculate (-1: all available)

extern string ___a__________________________ = "=== Signaling ===";
extern bool   Signal.onBarCross              = false;                   // onBarClose: on channel cross at opposite side of the last crossing
extern string Signal.onBarCross.Types        = "sound* | alert | mail | sms";
extern string Signal.Sound.Up                = "Signal Up.wav";
extern string Signal.Sound.Down              = "Signal Down.wav";

extern string ___b__________________________;
extern bool   Sound.onTickCross             = false;                    // onTick: on channel cross at opposite side of the last crossing
extern string Sound.onTickCross.Up          = "Alert Up.wav";
extern string Sound.onTickCross.Down        = "Alert Down.wav";

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <rsfLib.mqh>
#include <functions/chartlegend.mqh>
#include <functions/ConfigureSignals.mqh>
#include <functions/IsBarOpen.mqh>
#include <functions/ObjectCreateRegister.mqh>
#include <functions/iCustom/MaTunnel.mqh>

#define MODE_UPPER_BAND       MaTunnel.MODE_UPPER_BAND   // indicator buffer ids
#define MODE_LOWER_BAND       MaTunnel.MODE_LOWER_BAND   //
#define MODE_BAR_TREND        MaTunnel.MODE_BAR_TREND    // direction/shift of the last tunnel crossing: +1...+n=up, -1...-n=down
#define MODE_TICK_TREND       MaTunnel.MODE_TICK_TREND   // ...

#property indicator_chart_window
#property indicator_buffers   4

#property indicator_color1    CLR_NONE
#property indicator_color2    CLR_NONE
#property indicator_color3    CLR_NONE
#property indicator_color4    CLR_NONE

double upperBand[];                                      // upper band:      visible
double lowerBand[];                                      // lower band:      visible
double barTrend [];                                      // trend direction: invisible, displayed in "Data" window
double tickTrend[];                                      // ...

#define MA_METHOD    0                                   // indexes of ma[]
#define MA_PERIODS   1

string maDefinitions[];                                  // MA definitions
int    ma[][2];                                          // integer representation
int    maxMaPeriods;

string indicatorName = "";
string legendLabel   = "";
string legendInfo    = "";

bool   signal.sound;
bool   signal.alert;
bool   signal.mail;
bool   signal.sms;

#define D_LONG    TRADE_DIRECTION_LONG                   // signal direction types
#define D_SHORT   TRADE_DIRECTION_SHORT                  //


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   // input validation
   string indicator = WindowExpertName();

   // Tunnel.Definition
   ArrayResize(ma, 0);
   ArrayResize(maDefinitions, 0);
   int mas = 0;
   maxMaPeriods = 0;

   string sValues[], sValue = Tunnel.Definition;
   if (AutoConfiguration) sValue = GetConfigString(indicator, "Tunnel.Definition", sValue);
   int size = Explode(sValue, ",", sValues, NULL);
   for (int i=0; i < size; i++) {
      sValue = StrTrim(sValues[i]);
      if (sValue == "") continue;

      string sMethod = StrLeftTo(sValue, "(");
      if (sMethod == sValue)           return(catch("onInit(1)  invalid "+ DoubleQuoteStr(sValue) +" in input parameter Tunnel.Definition: "+ DoubleQuoteStr(Tunnel.Definition) +" (expected format: \"MaMethod(int)\")", ERR_INVALID_INPUT_PARAMETER));
      int iMethod = StrToMaMethod(sMethod, F_ERR_INVALID_PARAMETER);
      if (iMethod == -1)               return(catch("onInit(2)  invalid "+ DoubleQuoteStr(sMethod) +" in input parameter Tunnel.Definition: "+ DoubleQuoteStr(Tunnel.Definition) +" (unsupported MA method)", ERR_INVALID_INPUT_PARAMETER));
      if (iMethod > MODE_LWMA)         return(catch("onInit(3)  invalid "+ DoubleQuoteStr(sMethod) +" in input parameter Tunnel.Definition: "+ DoubleQuoteStr(Tunnel.Definition) +" (unsupported MA method)", ERR_INVALID_INPUT_PARAMETER));

      string sPeriods = StrRightFrom(sValue, "(");
      if (!StrEndsWith(sPeriods, ")")) return(catch("onInit(4)  invalid "+ DoubleQuoteStr(sValue) +" in input parameter Tunnel.Definition: "+ DoubleQuoteStr(Tunnel.Definition) +" (expected format: \"MaMethod(int)\")", ERR_INVALID_INPUT_PARAMETER));
      sPeriods = StrTrim(StrLeft(sPeriods, -1));
      if (!StrIsDigits(sPeriods))      return(catch("onInit(5)  invalid "+ DoubleQuoteStr(sValue) +" in input parameter Tunnel.Definition: "+ DoubleQuoteStr(Tunnel.Definition) +" (expected format: \"MaMethod(int)\")", ERR_INVALID_INPUT_PARAMETER));
      int iPeriods = StrToInteger(sPeriods);
      if (iPeriods < 1)                return(catch("onInit(6)  invalid MA periods "+ iPeriods +" in input parameter Tunnel.Definition: "+ DoubleQuoteStr(Tunnel.Definition) +" (must be positive)", ERR_INVALID_INPUT_PARAMETER));

      ArrayResize(ma, mas+1);
      ArrayResize(maDefinitions, mas+1);
      ma[mas][MA_METHOD ] = iMethod;
      ma[mas][MA_PERIODS] = iPeriods;
      maDefinitions[mas]  = MaMethodDescription(iMethod) +"("+ iPeriods +")";
      maxMaPeriods = MathMax(maxMaPeriods, iPeriods);
      mas++;
   }
   if (!mas)                           return(catch("onInit(7)  missing input parameter Tunnel.Definition", ERR_INVALID_INPUT_PARAMETER));

   // Tunnel.Color: after deserialization the terminal might turn CLR_NONE (0xFFFFFFFF) into Black (0xFF000000)
   if (AutoConfiguration) Tunnel.Color = GetConfigColor(indicator, "Tunnel.Color", Tunnel.Color);
   if (Tunnel.Color == 0xFF000000) Tunnel.Color = CLR_NONE;
   // ShowChartLegend
   if (AutoConfiguration) ShowChartLegend = GetConfigBool(indicator, "ShowChartLegend", ShowChartLegend);
   // MaxBarsBack
   if (AutoConfiguration) MaxBarsBack = GetConfigInt(indicator, "MaxBarsBack", MaxBarsBack);
   if (MaxBarsBack < -1)               return(catch("onInit(8)  invalid input parameter MaxBarsBack: "+ MaxBarsBack, ERR_INVALID_INPUT_PARAMETER));
   if (MaxBarsBack == -1) MaxBarsBack = INT_MAX;

   // signal configuration
   string signalId = "Signal.onBarCross";
   legendInfo = "";
   if (!ConfigureSignals(signalId, AutoConfiguration, Signal.onBarCross)) return(last_error);
   if (Signal.onBarCross) {
      if (!ConfigureSignalTypes(signalId, Signal.onBarCross.Types, AutoConfiguration, signal.sound, signal.alert, signal.mail, signal.sms)) {
         return(catch("onInit(9)  invalid input parameter Signal.onBarCross.Types: "+ DoubleQuoteStr(Signal.onBarCross.Types), ERR_INVALID_INPUT_PARAMETER));
      }
      Signal.onBarCross = (signal.sound || signal.alert || signal.mail || signal.sms);
      if (Signal.onBarCross) legendInfo = "("+ StrLeft(ifString(signal.sound, "sound,", "") + ifString(signal.alert, "alert,", "") + ifString(signal.mail, "mail,", "") + ifString(signal.sms, "sms,", ""), -1) +")";
   }
   // Signal.Sound.*
   if (AutoConfiguration) Signal.Sound.Up   = GetConfigString(indicator, "Signal.Sound.Up",   Signal.Sound.Up);
   if (AutoConfiguration) Signal.Sound.Down = GetConfigString(indicator, "Signal.Sound.Down", Signal.Sound.Down);
   // Sound.onTickCross
   if (AutoConfiguration) Sound.onTickCross      = GetConfigBool(indicator, "Sound.onTickCross", Sound.onTickCross);
   if (AutoConfiguration) Sound.onTickCross.Up   = GetConfigString(indicator, "Sound.onTickCross.Up",   Sound.onTickCross.Up);
   if (AutoConfiguration) Sound.onTickCross.Down = GetConfigString(indicator, "Sound.onTickCross.Down", Sound.onTickCross.Down);

   // buffer management
   SetIndexBuffer(MODE_UPPER_BAND, upperBand);
   SetIndexBuffer(MODE_LOWER_BAND, lowerBand);
   SetIndexBuffer(MODE_BAR_TREND,  barTrend);  SetIndexEmptyValue(MODE_BAR_TREND, 0);
   SetIndexBuffer(MODE_TICK_TREND, tickTrend); SetIndexEmptyValue(MODE_TICK_TREND, 0);

   // names, labels and display options
   if (ShowChartLegend) legendLabel = CreateChartLegend();
   indicatorName = WindowExpertName() +" "+ JoinStrings(maDefinitions, ",");
   IndicatorShortName(indicatorName);                             // chart tooltips and context menu
   SetIndexLabel(MODE_UPPER_BAND, indicatorName +" upper band");  // "Data" window and context menu
   SetIndexLabel(MODE_LOWER_BAND, indicatorName +" lower band");  // ...
   SetIndexLabel(MODE_BAR_TREND,  indicatorName +" bar trend" );  //
   SetIndexLabel(MODE_TICK_TREND, indicatorName +" tick trend");  //
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
   if (!ArraySize(barTrend)) return(logInfo("onTick(1)  sizeof(barTrend) = 0", SetLastError(ERS_TERMINAL_NOT_YET_READY)));

   // reset buffers before performing a full recalculation
   if (!ValidBars) {
      ArrayInitialize(upperBand, EMPTY_VALUE);
      ArrayInitialize(lowerBand, EMPTY_VALUE);
      ArrayInitialize(barTrend,            0);
      ArrayInitialize(tickTrend,           0);
      SetIndicatorOptions();
   }

   // synchronize buffers with a shifted offline chart
   if (ShiftedBars > 0) {
      ShiftDoubleIndicatorBuffer(upperBand, Bars, ShiftedBars, EMPTY_VALUE);
      ShiftDoubleIndicatorBuffer(lowerBand, Bars, ShiftedBars, EMPTY_VALUE);
      ShiftDoubleIndicatorBuffer(barTrend,  Bars, ShiftedBars,           0);
      ShiftDoubleIndicatorBuffer(tickTrend, Bars, ShiftedBars,           0);
   }

   // calculate start bar
   int bars     = Min(ChangedBars, MaxBarsBack);
   int startbar = Min(bars-1, Bars-maxMaPeriods), prevBarTrend;
   if (startbar < 0 && MaxBarsBack) return(logInfo("onTick(2)  Tick="+ Ticks, ERR_HISTORY_INSUFFICIENT));

   int numberOfMas = ArrayRange(ma, 0);

   // recalculate changed bars
   for (int bar=startbar; bar >= 0; bar--) {
      double high=INT_MIN, low=INT_MAX;

      for (int i=0; i < numberOfMas; i++) {
         high = MathMax(high, iMA(NULL, NULL, ma[i][MA_PERIODS], 0, ma[i][MA_METHOD], PRICE_HIGH, bar));
         low  = MathMin(low,  iMA(NULL, NULL, ma[i][MA_PERIODS], 0, ma[i][MA_METHOD], PRICE_LOW,  bar));
      }
      upperBand[bar] = high;
      lowerBand[bar] = low;

      prevBarTrend = barTrend[bar+1];
      if      (Close[bar] > upperBand[bar]) barTrend[bar] = _int(MathMax(prevBarTrend, 0)) + 1;
      else if (Close[bar] < lowerBand[bar]) barTrend[bar] = _int(MathMin(prevBarTrend, 0)) - 1;
      else                                  barTrend[bar] = prevBarTrend + Sign(prevBarTrend);
      tickTrend[bar] = barTrend[bar];
   }

   // recalculate tick trend
   static int currTickTrend, prevTickTrend;
   if (!prevTickTrend) prevTickTrend = tickTrend[0];
   static double prevHigh=INT_MAX, prevLow=INT_MIN;

   if      (Close[0] > upperBand[0] || (High[0] > prevHigh && High[0] > upperBand[0])) currTickTrend = MathMax(prevTickTrend, 0) + 1;
   else if (Close[0] < lowerBand[0] || (Low [0] < prevLow  && Low [0] < lowerBand[0])) currTickTrend = MathMin(prevTickTrend, 0) - 1;
   else                                                                                currTickTrend = prevTickTrend + Sign(prevTickTrend);
   tickTrend[0]  = currTickTrend;
   prevTickTrend = currTickTrend;
   prevHigh      = High[0];
   prevLow       = Low [0];

   if (!__isSuperContext) {
      // update chart legend
      if (ShowChartLegend) UpdateBandLegend(legendLabel, indicatorName, legendInfo, Tunnel.Color, upperBand[0], lowerBand[0]);

      // monitor signals
      if (Sound.onTickCross) {
         if      (tickTrend[0] == +1) onCross(D_LONG, 0);
         else if (tickTrend[0] == -1) onCross(D_SHORT, 0);
      }
      if (Signal.onBarCross) /*&&*/ if (IsBarOpen()) {
         if      (barTrend[1] == +1) onCross(D_LONG, 1);
         else if (barTrend[1] == -1) onCross(D_SHORT, 1);
      }
   }
   return(catch("onTick(3)"));
}


/**
 * Event handler signaling tunnel crossings.
 *
 * @param  int direction - crossing direction: D_LONG | D_SHORT
 * @param  int bar       - bar of the crossing (the current or the closed bar)
 *
 * @return bool - success status
 */
bool onCross(int direction, int bar) {
   if (ChangedBars > 2)                         return(false);
   if (direction!=D_LONG && direction!=D_SHORT) return(!catch("onCross(1)  invalid parameter direction: "+ direction, ERR_INVALID_PARAMETER));

   int error = NO_ERROR;

   if (bar == 0) {
      if (!Sound.onTickCross) return(false);

      if (direction == D_LONG) {
         if (IsLogInfo()) logInfo("onCross(2)  tick above "+ indicatorName);
         error |= PlaySoundEx(Sound.onTickCross.Up);
      }
      else /*direction == D_SHORT*/ {
         if (IsLogInfo()) logInfo("onCross(3)  tick below "+ indicatorName);
         error |= PlaySoundEx(Sound.onTickCross.Down);
      }
      return(!error);
   }
   if (bar == 1) {
      if (!Signal.onBarCross) return(false);

      string message="", accountTime="("+ TimeToStr(TimeLocalEx("onCross(4)"), TIME_MINUTES|TIME_SECONDS) +", "+ GetAccountAlias() +")";

      if (direction == D_LONG) {
         message = "bar close above "+ indicatorName;
         if (IsLogInfo()) logInfo("onCross(5)  "+ message);
         message = Symbol() +","+ PeriodDescription() +": "+ message;

         if (signal.alert)          Alert(message);
         if (signal.sound) error |= PlaySoundEx(Signal.Sound.Up);
         if (signal.mail)  error |= !SendEmail("", "", message, message +NL+ accountTime);
         if (signal.sms)   error |= !SendSMS("", message +NL+ accountTime);
      }
      else /*direction == D_SHORT*/ {
         message = "bar close below "+ indicatorName;
         if (IsLogInfo()) logInfo("onCross(6)  "+ message);
         message = Symbol() +","+ PeriodDescription() +": "+ message;

         if (signal.alert)          Alert(message);
         if (signal.sound) error |= PlaySoundEx(Signal.Sound.Down);
         if (signal.mail)  error |= !SendEmail("", "", message, message +NL+ accountTime);
         if (signal.sms)   error |= !SendSMS("", message +NL+ accountTime);
      }
      return(!error);
   }

   return(!catch("onCross(7)  illegal parameter bar: "+ bar, ERR_INVALID_PARAMETER));
}


/**
 * Workaround for various terminal bugs when setting indicator options. Usually options are set in init(). However after
 * recompilation options must be set in start() to not be ignored.
 */
void SetIndicatorOptions() {
   //SetIndexStyle(int buffer, int drawType, int lineStyle=EMPTY, int drawWidth=EMPTY, color drawColor=NULL)

   SetIndexStyle(MODE_UPPER_BAND, DRAW_LINE, EMPTY, EMPTY, Tunnel.Color);
   SetIndexStyle(MODE_LOWER_BAND, DRAW_LINE, EMPTY, EMPTY, Tunnel.Color);
   SetIndexStyle(MODE_BAR_TREND,  DRAW_NONE, EMPTY, EMPTY, CLR_NONE);
   SetIndexStyle(MODE_TICK_TREND, DRAW_NONE, EMPTY, EMPTY, CLR_NONE);
}


/**
 * Return a string representation of the input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("Tunnel.Definition=",       DoubleQuoteStr(Tunnel.Definition),       ";", NL,
                            "Tunnel.Color=",            ColorToStr(Tunnel.Color),                ";", NL,
                            "ShowChartLegend=",         BoolToStr(ShowChartLegend),              ";", NL,
                            "MaxBarsBack=",             MaxBarsBack,                             ";", NL,

                            "Signal.onBarCross=",       BoolToStr(Signal.onBarCross),            ";", NL,
                            "Signal.onBarCross.Types=", DoubleQuoteStr(Signal.onBarCross.Types), ";", NL,
                            "Signal.Sound.Up=",         DoubleQuoteStr(Signal.Sound.Up),         ";", NL,
                            "Signal.Sound.Down=",       DoubleQuoteStr(Signal.Sound.Down),       ";", NL,

                            "Sound.onTickCross=",       BoolToStr(Sound.onTickCross),            ";", NL,
                            "Sound.onTickCross.Up=",    DoubleQuoteStr(Sound.onTickCross.Up),    ";", NL,
                            "Sound.onTickCross.Down=",  DoubleQuoteStr(Sound.onTickCross.Down),  ";")
   );

   // suppress compiler warnings
   icMaTunnel(NULL, NULL, NULL, NULL);
}
