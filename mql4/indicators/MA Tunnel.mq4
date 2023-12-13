/**
 * MA Tunnel
 *
 * An indicator for price crossing a High/Low channel (aka a tunnel) around a single Moving Average.
 */
#include <stddefines.mqh>
int   __InitFlags[];
int __DeinitFlags[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern int    MA.Periods                     = 36;
extern string MA.Method                      = "SMA | LWMA | EMA* | SMMA";
extern color  Tunnel.Color                   = Magenta;
extern int    Max.Bars                       = 10000;             // max. values to calculate (-1: all available)
extern bool   ShowChartLegend                = true;

extern string ___a__________________________ = "=== Signaling ===";
extern bool   Signal.onBarCross              = false;             // on channel leave at opposite side of the last crossing
extern bool   Signal.onBarCross.Sound        = true;
extern string Signal.onBarCross.SoundUp      = "Signal Up.wav";
extern string Signal.onBarCross.SoundDown    = "Signal Down.wav";
extern bool   Signal.onBarCross.Popup        = false;
extern bool   Signal.onBarCross.Mail         = false;
extern bool   Signal.onBarCross.SMS          = false;
extern string ___b__________________________;
extern bool   Signal.onTickCross.Sound       = false;
extern string Signal.onTickCross.SoundUp     = "Alert Up.wav";
extern string Signal.onTickCross.SoundDown   = "Alert Down.wav";

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <rsfLib.mqh>
#include <functions/chartlegend.mqh>
#include <functions/ConfigureSignals.mqh>
#include <functions/IsBarOpen.mqh>

#define MODE_UPPER_BAND       0              // indicator buffer ids
#define MODE_LOWER_BAND       1              //
#define MODE_BAR_TREND        2              // direction + shift of the last tunnel crossing: +1...+n=up, -1...-n=down
#define MODE_TICK_TREND       3              // ...

#property indicator_chart_window
#property indicator_buffers   4

#property indicator_color1    CLR_NONE
#property indicator_color2    CLR_NONE
#property indicator_color3    CLR_NONE
#property indicator_color4    CLR_NONE

double upperBand[];                          // upper band:      visible
double lowerBand[];                          // lower band:      visible
double barTrend [];                          // trend direction: invisible, displayed in "Data" window
double tickTrend[];                          // ...

int    maMethod;
int    maxBarsBack;

string indicatorName = "";
string legendLabel   = "";

bool   signal.barCross;
bool   signal.tickCross;
string signalInfo = "";

#define D_LONG    TRADE_DIRECTION_LONG       // 1 (signal direction types)
#define D_SHORT   TRADE_DIRECTION_SHORT      // 2


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   string indicator = WindowExpertName();

   // input validation
   // MA.Periods
   if (AutoConfiguration) MA.Periods = GetConfigInt(indicator, "MA.Periods", MA.Periods);
   if (MA.Periods < 1)                  return(catch("onInit(1)  invalid input parameter MA.Periods: "+ MA.Periods, ERR_INVALID_INPUT_PARAMETER));
   // MA.Method
   string sValues[], sValue = MA.Method;
   if (AutoConfiguration) sValue = GetConfigString(indicator, "MA.Method", sValue);
   if (Explode(sValue, "*", sValues, 2) > 1) {
      int size = Explode(sValues[0], "|", sValues, NULL);
      sValue = sValues[size-1];
   }
   maMethod = StrToMaMethod(sValue, F_ERR_INVALID_PARAMETER);
   if (maMethod == -1)                  return(catch("onInit(2)  invalid input parameter MA.Method: "+ DoubleQuoteStr(MA.Method), ERR_INVALID_INPUT_PARAMETER));
   if (maMethod > MODE_LWMA)            return(catch("onInit(3)  unsupported input parameter MA.Method: "+ DoubleQuoteStr(MA.Method), ERR_INVALID_INPUT_PARAMETER));
   MA.Method = MaMethodDescription(maMethod);
   // Tunnel.Color: after deserialization the terminal might turn CLR_NONE (0xFFFFFFFF) into Black (0xFF000000)
   if (AutoConfiguration) Tunnel.Color = GetConfigColor(indicator, "Tunnel.Color", Tunnel.Color);
   if (Tunnel.Color == 0xFF000000) Tunnel.Color = CLR_NONE;
   // Max.Bars
   if (AutoConfiguration) Max.Bars = GetConfigInt(indicator, "Max.Bars", Max.Bars);
   if (Max.Bars < -1)                   return(catch("onInit(8)  invalid input parameter Max.Bars: "+ Max.Bars, ERR_INVALID_INPUT_PARAMETER));
   maxBarsBack = ifInt(Max.Bars==-1, INT_MAX, Max.Bars);
   // ShowChartLegend
   if (AutoConfiguration) ShowChartLegend = GetConfigBool(indicator, "ShowChartLegend", ShowChartLegend);

   // signal configuration
   string signalId = "Signal.onBarCross";
   if (!ConfigureSignals2(signalId, AutoConfiguration, Signal.onBarCross)) return(last_error);
   if (Signal.onBarCross) {
      if (!ConfigureSignalsBySound2(signalId, AutoConfiguration, Signal.onBarCross.Sound)) return(last_error);
      if (!ConfigureSignalsByPopup (signalId, AutoConfiguration, Signal.onBarCross.Popup)) return(last_error);
      if (!ConfigureSignalsByMail2 (signalId, AutoConfiguration, Signal.onBarCross.Mail))  return(last_error);
      if (!ConfigureSignalsBySMS2  (signalId, AutoConfiguration, Signal.onBarCross.SMS))   return(last_error);
      Signal.onBarCross = (Signal.onBarCross.Sound || Signal.onBarCross.Popup || Signal.onBarCross.Mail || Signal.onBarCross.SMS);
   }
   signal.barCross = Signal.onBarCross;
   if (AutoConfiguration) Signal.onBarCross.SoundUp   = GetConfigString(indicator, "Signal.onBarCross.SoundUp",   Signal.onBarCross.SoundUp);
   if (AutoConfiguration) Signal.onBarCross.SoundDown = GetConfigString(indicator, "Signal.onBarCross.SoundDown", Signal.onBarCross.SoundDown);

   if (!ConfigureSignalsBySound2("Signal.onTickCross", AutoConfiguration, Signal.onTickCross.Sound)) return(last_error);
   signal.tickCross = Signal.onTickCross.Sound;
   if (AutoConfiguration) Signal.onTickCross.SoundUp   = GetConfigString(indicator, "Signal.onTickCross.SoundUp",   Signal.onTickCross.SoundUp);
   if (AutoConfiguration) Signal.onTickCross.SoundDown = GetConfigString(indicator, "Signal.onTickCross.SoundDown", Signal.onTickCross.SoundDown);

   signalInfo = "";
   if (signal.barCross) {
      signalInfo = ifString(Signal.onBarCross.Sound, "sound,", "") + ifString(Signal.onBarCross.Popup, "popup,", "") + ifString(Signal.onBarCross.Mail, "mail,", "") + ifString(Signal.onBarCross.SMS, "sms,", "");
      signalInfo = "("+ StrLeft(signalInfo, -1) +")";
   }

   // buffer management
   SetIndexBuffer(MODE_UPPER_BAND, upperBand);
   SetIndexBuffer(MODE_LOWER_BAND, lowerBand);
   SetIndexBuffer(MODE_BAR_TREND,  barTrend);  SetIndexEmptyValue(MODE_BAR_TREND, 0);
   SetIndexBuffer(MODE_TICK_TREND, tickTrend); SetIndexEmptyValue(MODE_TICK_TREND, 0);

   // names, labels and display options
   if (ShowChartLegend) legendLabel = CreateChartLegend();
   indicatorName = MA.Method +"("+ MA.Periods +") Tunnel";
   IndicatorShortName(indicatorName);                             // chart tooltips and context menu
   SetIndexLabel(MODE_UPPER_BAND, indicatorName +" upper band");  // "Data" window and context menu
   SetIndexLabel(MODE_LOWER_BAND, indicatorName +" lower band");  // ...
   SetIndexLabel(MODE_BAR_TREND,  indicatorName +" bar trend" );  //
   SetIndexLabel(MODE_TICK_TREND, indicatorName +" tick trend");  //
   IndicatorDigits(Digits);
   SetIndicatorOptions();

   return(catch("onInit(9)"));
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
   int bars     = Min(ChangedBars, maxBarsBack);
   int startbar = Min(bars-1, Bars-MA.Periods), prevBarTrend;
   if (startbar < 0) return(logInfo("onTick(2)  Tick="+ Ticks, ERR_HISTORY_INSUFFICIENT));

   // recalculate changed bars
   for (int bar=startbar; bar >= 0; bar--) {
      upperBand[bar] = iMA(NULL, NULL, MA.Periods, 0, maMethod, PRICE_HIGH, bar);
      lowerBand[bar] = iMA(NULL, NULL, MA.Periods, 0, maMethod, PRICE_LOW,  bar);

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

   // update chart legend and monitor signals
   if (!__isSuperContext) {
      if (ShowChartLegend) UpdateBandLegend(legendLabel, indicatorName, signalInfo, Tunnel.Color, upperBand[0], lowerBand[0]);

      // signal tunnel crosses
      if (signal.tickCross) {
         if      (tickTrend[0] == +1) onCross(D_LONG, 0);
         else if (tickTrend[0] == -1) onCross(D_SHORT, 0);
      }
      if (signal.barCross) /*&&*/ if (IsBarOpen()) {
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
      if (!signal.tickCross) return(false);

      if (direction == D_LONG) {
         if (IsLogInfo()) logInfo("onCross(2)  tick above "+ indicatorName);
         error |= PlaySoundEx(Signal.onTickCross.SoundUp);
      }
      else /*direction == D_SHORT*/ {
         if (IsLogInfo()) logInfo("onCross(3)  tick below "+ indicatorName);
         error |= PlaySoundEx(Signal.onTickCross.SoundDown);
      }
      return(!error);
   }
   if (bar == 1) {
      if (!signal.barCross) return(false);

      string message="", accountTime="("+ TimeToStr(TimeLocalEx("onCross(4)"), TIME_MINUTES|TIME_SECONDS) +", "+ GetAccountAlias() +")";

      if (direction == D_LONG) {
         message = "bar close above "+ indicatorName;
         if (IsLogInfo()) logInfo("onCross(5)  "+ message);
         message = Symbol() +","+ PeriodDescription() +": "+ message;

         if (Signal.onBarCross.Sound) error |= PlaySoundEx(Signal.onBarCross.SoundUp);
         if (Signal.onBarCross.Mail)  error |= !SendEmail("", "", message, message +NL+ accountTime);
         if (Signal.onBarCross.SMS)   error |= !SendSMS("", message +NL+ accountTime);
      }
      else /*direction == D_SHORT*/ {
         message = "bar close below "+ indicatorName;
         if (IsLogInfo()) logInfo("onCross(6)  "+ message);
         message = Symbol() +","+ PeriodDescription() +": "+ message;

         if (Signal.onBarCross.Sound) error |= PlaySoundEx(Signal.onBarCross.SoundDown);
         if (Signal.onBarCross.Mail)  error |= !SendEmail("", "", message, message +NL+ accountTime);
         if (Signal.onBarCross.SMS)   error |= !SendSMS("", message +NL+ accountTime);
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
   return(StringConcatenate("MA.Periods=",                   MA.Periods,                                   ";", NL,
                            "MA.Method=",                    DoubleQuoteStr(MA.Method),                    ";", NL,
                            "Tunnel.Color=",                 ColorToStr(Tunnel.Color),                     ";", NL,
                            "Max.Bars=",                     Max.Bars,                                     ";", NL,
                            "ShowChartLegend",               BoolToStr(ShowChartLegend),                   ";", NL,

                            "Signal.onBarCross",             BoolToStr(Signal.onBarCross),                 ";", NL,
                            "Signal.onBarCross.Sound",       BoolToStr(Signal.onBarCross.Sound),           ";", NL,
                            "Signal.onBarCross.SoundUp=",    DoubleQuoteStr(Signal.onBarCross.SoundUp),    ";", NL,
                            "Signal.onBarCross.SoundDown=",  DoubleQuoteStr(Signal.onBarCross.SoundDown),  ";", NL,
                            "Signal.onBarCross.Popup",       BoolToStr(Signal.onBarCross.Popup),           ";", NL,
                            "Signal.onBarCross.Mail",        BoolToStr(Signal.onBarCross.Mail),            ";", NL,
                            "Signal.onBarCross.SMS",         BoolToStr(Signal.onBarCross.SMS),             ";", NL,

                            "Signal.onTickCross.Sound",      BoolToStr(Signal.onTickCross.Sound),          ";", NL,
                            "Signal.onTickCross.SoundUp=",   DoubleQuoteStr(Signal.onTickCross.SoundUp),   ";", NL,
                            "Signal.onTickCross.SoundDown=", DoubleQuoteStr(Signal.onTickCross.SoundDown), ";")
   );
}
