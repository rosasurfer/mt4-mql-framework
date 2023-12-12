/**
 * MA Tunnel
 *
 * A signal monitor for price crossing a High/Low channel (aka a tunnel) around a single Moving Average.
 */
#include <stddefines.mqh>
int   __InitFlags[];
int __DeinitFlags[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern int    MA.Periods                     = 36;
extern string MA.Method                      = "SMA | LWMA | EMA* | SMMA";
extern color  Tunnel.Color                   = Magenta;
extern int    Max.Bars                       = 10000;     // max. values to calculate (-1: all available)

extern string ___a__________________________ = "=== Signaling ===";
extern bool   Signal.onBarCross              = false;     // on channel leave at opposite side of bar-close
extern bool   Signal.onBarCross.Sound        = true;
extern bool   Signal.onBarCross.Popup        = false;
extern bool   Signal.onBarCross.Mail         = false;
extern bool   Signal.onBarCross.SMS          = false;
extern bool   Signal.onTickCross.Sound       = false;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <rsfLib.mqh>
#include <functions/ConfigureSignals.mqh>
#include <functions/chartlegend.mqh>

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
string signalInfo    = "";

bool   signal.barCross;
bool   signal.barCross.sound;
bool   signal.barCross.popup;
bool   signal.barCross.mail;
bool   signal.barCross.sms;
bool   signal.tickCross;


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   string indicator = WindowExpertName();

   // input validattion
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

   // signal configuration
   signal.barCross       = Signal.onBarCross;
   signal.barCross.sound = Signal.onBarCross.Sound;
   signal.barCross.popup = Signal.onBarCross.Popup;
   signal.barCross.mail  = Signal.onBarCross.Mail;
   signal.barCross.sms   = Signal.onBarCross.SMS;
   string signalId = "Signal.onBarCross";
   if (!ConfigureSignals2(signalId, AutoConfiguration, signal.barCross)) return(last_error);
   if (signal.barCross) {
      if (!ConfigureSignalsBySound2(signalId, AutoConfiguration, signal.barCross.sound)) return(last_error);
      if (!ConfigureSignalsByPopup (signalId, AutoConfiguration, signal.barCross.popup)) return(last_error);
      if (!ConfigureSignalsByMail2 (signalId, AutoConfiguration, signal.barCross.mail))  return(last_error);
      if (!ConfigureSignalsBySMS2  (signalId, AutoConfiguration, signal.barCross.sms))   return(last_error);
      signal.barCross = (signal.barCross.sound || signal.barCross.popup || signal.barCross.mail || signal.barCross.sms);
   }
   signal.tickCross = Signal.onTickCross.Sound;
   if (!ConfigureSignalsBySound2("Signal.onTickCross", AutoConfiguration, signal.tickCross)) return(last_error);
   signalInfo = "";
   if (signal.barCross) {
      signalInfo = ifString(signal.barCross.sound, "sound,", "") + ifString(signal.barCross.popup, "popup,", "") + ifString(signal.barCross.mail, "mail,", "") + ifString(signal.barCross.sms, "sms,", "");
      signalInfo = "("+ StrLeft(signalInfo, -1) +")";
   }

   // buffer management
   SetIndexBuffer(MODE_UPPER_BAND, upperBand);
   SetIndexBuffer(MODE_LOWER_BAND, lowerBand);
   SetIndexBuffer(MODE_BAR_TREND,  barTrend);  SetIndexEmptyValue(MODE_BAR_TREND, 0);
   SetIndexBuffer(MODE_TICK_TREND, tickTrend); SetIndexEmptyValue(MODE_TICK_TREND, 0);

   // names, labels and display options
   legendLabel = CreateChartLegend();
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

   // update legend and monitor signals
   if (!__isSuperContext) {
      string status = signalInfo;
      if (signal.tickCross) {
         string sBarTrend  = NumberToStr(barTrend [0], "+.");
         string sTickTrend = NumberToStr(tickTrend[0], "+.");
         status = StringConcatenate(sBarTrend, "/", sTickTrend, "  ", signalInfo);
      }
      UpdateBandLegend(legendLabel, indicatorName, status, Tunnel.Color, upperBand[0], lowerBand[0]);

      // signal trend changes
      if (signal.tickCross) {
         //if      (trend[1] == +1) onTunnelCross(MODE_UPTREND);
         //else if (trend[1] == -1) onTunnelCross(MODE_DOWNTREND);
      }
      if (signal.barCross) {
         //if      (trend[1] == +1) onTunnelCross(MODE_UPTREND);
         //else if (trend[1] == -1) onTunnelCross(MODE_DOWNTREND);
      }
   }
   return(catch("onTick(3)"));
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
   return(StringConcatenate("MA.Periods=",              MA.Periods,                          ";", NL,
                            "MA.Method=",               DoubleQuoteStr(MA.Method),           ";", NL,
                            "Tunnel.Color=",            ColorToStr(Tunnel.Color),            ";", NL,
                            "Max.Bars=",                Max.Bars,                            ";", NL,

                            "Signal.onBarCross",        BoolToStr(Signal.onBarCross),        ";", NL,
                            "Signal.onBarCross.Sound",  BoolToStr(Signal.onBarCross.Sound),  ";", NL,
                            "Signal.onBarCross.Popup",  BoolToStr(Signal.onBarCross.Popup),  ";", NL,
                            "Signal.onBarCross.Mail",   BoolToStr(Signal.onBarCross.Mail),   ";", NL,
                            "Signal.onBarCross.SMS",    BoolToStr(Signal.onBarCross.SMS),    ";", NL,
                            "Signal.onTickCross.Sound", BoolToStr(Signal.onTickCross.Sound), ";")
   );
}
