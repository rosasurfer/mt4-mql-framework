/**
 * Tunnel
 *
 * An indicator forming a High/Low channel built from one or more Moving Averages.
 *
 *
 * TODO:
 *  - add input "Tunnel.Width" = 100% (percent of High/Low range)
 */
#include <rsf/stddefines.mqh>
int   __InitFlags[];
int __DeinitFlags[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern string Tunnel.Definition              = "EMA(144)";              // one or more MAs separated by ","
extern color  Tunnel.Color                   = Magenta;
extern string Supported.MovingAverages       = "SMA, LWMA, EMA, SMMA";
extern bool   ShowChartLegend                = true;
extern int    MaxBarsBack                    = 10000;                   // max. values to calculate (-1: all available)

extern string ___a__________________________ = "=== Signaling ===";
extern bool   Signal.onBarCross              = false;                   // onBarClose: on channel cross at opposite side of the last crossing
extern string Signal.onBarCross.Types        = "sound* | alert | mail | sms";
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
#include <rsf/functions/iCustom/Tunnel.mqh>
#include <rsf/win32api.mqh>

#define MODE_UPPER_BAND       Tunnel.MODE_UPPER_BAND     // 0 indicator buffer ids
#define MODE_LOWER_BAND       Tunnel.MODE_LOWER_BAND     // 1
#define MODE_TREND            Tunnel.MODE_TREND          // 2 direction/length of the last tunnel crossing: +1...+n=up, -1...-n=down

#property indicator_chart_window
#property indicator_buffers   3                          // visible buffers

#property indicator_color1    CLR_NONE
#property indicator_color2    CLR_NONE
#property indicator_color3    CLR_NONE

double upperBand[];                                      // upper band:      visible
double lowerBand[];                                      // lower band:      visible
double barTrend [];                                      // trend direction: invisible, displayed in "Data" window

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
   Tunnel.Definition = JoinStrings(maDefinitions, ",");

   // Tunnel.Color: after deserialization the terminal might turn CLR_NONE (0xFFFFFFFF) into Black (0xFF000000)
   if (AutoConfiguration) Tunnel.Color = GetConfigColor(indicator, "Tunnel.Color", Tunnel.Color);
   if (Tunnel.Color == 0xFF000000) Tunnel.Color = CLR_NONE;
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
      if (!ConfigureSignalTypes(signalId, Signal.onBarCross.Types, AutoConfiguration, signal.sound, signal.alert, signal.mail, signal.sms)) {
         return(catch("onInit(9)  invalid input parameter Signal.onBarCross.Types: "+ DoubleQuoteStr(Signal.onBarCross.Types), ERR_INVALID_INPUT_PARAMETER));
      }
      Signal.onBarCross = (signal.sound || signal.alert || signal.mail || signal.sms);
      if (Signal.onBarCross) legendInfo = "("+ StrLeft(ifString(signal.sound, "sound,", "") + ifString(signal.alert, "alert,", "") + ifString(signal.mail, "mail,", "") + ifString(signal.sms, "sms,", ""), -1) +")";
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
   // on the first tick after terminal start buffers may not yet be initialized (spurious issue)
   if (!ArraySize(barTrend)) return(logInfo("onTick(1)  sizeof(barTrend) = 0", SetLastError(ERS_TERMINAL_NOT_YET_READY)));

   // reset buffers before performing a full recalculation
   if (!ValidBars) {
      ArrayInitialize(upperBand, EMPTY_VALUE);
      ArrayInitialize(lowerBand, EMPTY_VALUE);
      ArrayInitialize(barTrend,            0);
      SetIndicatorOptions();
   }

   // synchronize buffers with a shifted offline chart
   if (ShiftedBars > 0) {
      ShiftDoubleIndicatorBuffer(upperBand, Bars, ShiftedBars, EMPTY_VALUE);
      ShiftDoubleIndicatorBuffer(lowerBand, Bars, ShiftedBars, EMPTY_VALUE);
      ShiftDoubleIndicatorBuffer(barTrend,  Bars, ShiftedBars,           0);
   }

   // calculate start bar
   int startbar = Min(MaxBarsBack-1, ChangedBars-1, Bars-maxMaPeriods), prevBarTrend;
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
   }

   if (!__isSuperContext) {
      if (ShowChartLegend) UpdateBandLegend(legendLabel, indicatorName, legendInfo, Tunnel.Color, upperBand[0], lowerBand[0]);

      // monitor signals
      if (Signal.onBarCross) /*&&*/ if (IsBarOpen()) {
         if      (barTrend[1] == +1) onCross(D_LONG);
         else if (barTrend[1] == -1) onCross(D_SHORT);
      }
   }
   return(catch("onTick(3)"));
}


/**
 * Event handler signaling tunnel crossings.
 *
 * @param  int direction - crossing direction: D_LONG | D_SHORT
 *
 * @return bool - success status
 */
bool onCross(int direction) {
   if (direction!=D_LONG && direction!=D_SHORT) return(!catch("onCross(1)  invalid parameter direction: "+ direction, ERR_INVALID_PARAMETER));
   if (!Signal.onBarCross) return(false);
   if (ChangedBars > 2)    return(false);

   // skip the signal if it already has been signaled elsewhere
   int hWnd = ifInt(__isTesting, __ExecutionContext[EC.chart], GetDesktopWindow());
   string sPeriod = PeriodDescription();
   string sEvent  = "rsf::"+ StdSymbol() +","+ sPeriod +"."+ indicatorName +".onCross("+ direction +")."+ TimeToStr(Time[0]);
   if (GetPropA(hWnd, sEvent) != 0) return(true);
   SetPropA(hWnd, sEvent, 1);                                        // immediately mark as signaled (prevents duplicate signals on slow CPU)

   string message = "bar close "+ ifString(direction==D_LONG, "above ", "below ") + indicatorName;
   if (IsLogInfo()) logInfo("onCross(2)  "+ message);

   message = Symbol() +","+ PeriodDescription() +": "+ message;
   string sAccount = "("+ TimeToStr(TimeLocalEx("onCross(3)"), TIME_MINUTES|TIME_SECONDS) +", "+ GetAccountAlias() +")";

   if (signal.alert) Alert(message);
   if (signal.sound) PlaySoundEx(ifString(direction==D_LONG, Signal.Sound.Up, Signal.Sound.Down));
   if (signal.mail)  SendEmail("", "", message, message + NL + sAccount);
   if (signal.sms)   SendSMS("", message + NL + sAccount);
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
   if (ArraySize(maDefinitions) == 1) indicatorName = Tunnel.Definition +" Tunnel";
   else                               indicatorName = WindowExpertName() +" "+ Tunnel.Definition;
   IndicatorShortName(indicatorName);

   IndicatorBuffers(indicator_buffers);
   SetIndexBuffer(MODE_UPPER_BAND, upperBand);
   SetIndexBuffer(MODE_LOWER_BAND, lowerBand);
   SetIndexBuffer(MODE_TREND,      barTrend); SetIndexEmptyValue(MODE_TREND, 0);
   IndicatorDigits(Digits);

   SetIndexStyle(MODE_UPPER_BAND, DRAW_LINE, EMPTY, EMPTY, Tunnel.Color);
   SetIndexStyle(MODE_LOWER_BAND, DRAW_LINE, EMPTY, EMPTY, Tunnel.Color);
   SetIndexStyle(MODE_TREND,      DRAW_NONE);

   SetIndexLabel(MODE_UPPER_BAND, indicatorName +" upper");
   SetIndexLabel(MODE_LOWER_BAND, indicatorName +" lower");
   SetIndexLabel(MODE_TREND,      NULL);

   if (redraw) WindowRedraw();
   return(!catch("SetIndicatorOptions(1)"));
}


/**
 * Return a string representation of all input parameters (for logging purposes).
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
                            "Signal.Sound.Down=",       DoubleQuoteStr(Signal.Sound.Down),       ";")
   );

   // suppress compiler warnings
   icTunnel(NULL, NULL, NULL, NULL);
}
