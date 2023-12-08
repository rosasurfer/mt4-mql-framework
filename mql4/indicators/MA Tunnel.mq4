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
extern bool   Signal.onTunnelCross           = false;     // on channel leave at opposite side
extern bool   Signal.onTunnelCross.Sound     = true;
extern bool   Signal.onTunnelCross.Popup     = false;
extern bool   Signal.onTunnelCross.Mail      = false;
extern bool   Signal.onTunnelCross.SMS       = false;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <rsfLib.mqh>
#include <functions/ConfigureSignals.mqh>
#include <functions/legend.mqh>

#define MODE_UPPER_BAND       0                       // indicator buffer ids
#define MODE_LOWER_BAND       1                       //
#define MODE_TREND            2                       // direction + shift of the last tunnel crossing: +1...+n=up, -1...-n=down

#property indicator_chart_window
#property indicator_buffers   3

#property indicator_color1    CLR_NONE
#property indicator_color2    CLR_NONE
#property indicator_color3    CLR_NONE

double upperBand[];                                   // upper band:      visible
double lowerBand[];                                   // lower band:      visible
double trend    [];                                   // trend direction: invisible, displayed in "Data" window

int    maMethod;
int    maPeriods;
int    maxBarsBack;

string indicatorName = "";
string legendLabel   = "";
string legendInfo    = "";                            // additional chart legend info

bool   signalCrossing;
bool   signalCrossing.sound;
bool   signalCrossing.popup;
bool   signalCrossing.mail;
bool   signalCrossing.sms;


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
   maPeriods = MA.Periods;
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
   signalCrossing       = Signal.onTunnelCross;
   signalCrossing.sound = Signal.onTunnelCross.Sound;
   signalCrossing.popup = Signal.onTunnelCross.Popup;
   signalCrossing.mail  = Signal.onTunnelCross.Mail;
   signalCrossing.sms   = Signal.onTunnelCross.SMS;
   legendInfo           = "";
   string signalId = "Signal.onTunnelCross";
   if (!ConfigureSignals2(signalId, AutoConfiguration, signalCrossing)) return(last_error);
   if (signalCrossing) {
      if (!ConfigureSignalsBySound2(signalId, AutoConfiguration, signalCrossing.sound)) return(last_error);
      if (!ConfigureSignalsByPopup (signalId, AutoConfiguration, signalCrossing.popup)) return(last_error);
      if (!ConfigureSignalsByMail2 (signalId, AutoConfiguration, signalCrossing.mail))  return(last_error);
      if (!ConfigureSignalsBySMS2  (signalId, AutoConfiguration, signalCrossing.sms))   return(last_error);
      if (signalCrossing.sound || signalCrossing.popup || signalCrossing.mail || signalCrossing.sms) {
         legendInfo = StrLeft(ifString(signalCrossing.sound, "sound,", "") + ifString(signalCrossing.popup, "popup,", "") + ifString(signalCrossing.mail, "mail,", "") + ifString(signalCrossing.sms, "sms,", ""), -1);
         legendInfo = "("+ legendInfo +")";
      }
      else signalCrossing = false;
   }

   // buffer management
   SetIndexBuffer(MODE_UPPER_BAND, upperBand);
   SetIndexBuffer(MODE_LOWER_BAND, lowerBand);
   SetIndexBuffer(MODE_TREND,      trend    ); SetIndexEmptyValue(MODE_TREND, 0);

   // names, labels and display options
   legendLabel = CreateLegend();
   indicatorName = "Tunnel "+ MA.Method +"("+ MA.Periods +")";
   IndicatorShortName(indicatorName);                 // chart tooltips and context menu
   SetIndexLabel(MODE_TREND, indicatorName);          // chart tooltips and "Data" window
   SetIndexLabel(MODE_UPPER_BAND, NULL);
   SetIndexLabel(MODE_LOWER_BAND, NULL);
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
   if (!ArraySize(trend)) return(logInfo("onTick(1)  sizeof(trend) = 0", SetLastError(ERS_TERMINAL_NOT_YET_READY)));

   // reset buffers before performing a full recalculation
   if (!ValidBars) {
      ArrayInitialize(upperBand, EMPTY_VALUE);
      ArrayInitialize(lowerBand, EMPTY_VALUE);
      ArrayInitialize(trend,               0);
      SetIndicatorOptions();
   }

   // synchronize buffers with a shifted offline chart
   if (ShiftedBars > 0) {
      ShiftDoubleIndicatorBuffer(upperBand, Bars, ShiftedBars, EMPTY_VALUE);
      ShiftDoubleIndicatorBuffer(lowerBand, Bars, ShiftedBars, EMPTY_VALUE);
      ShiftDoubleIndicatorBuffer(trend,     Bars, ShiftedBars,           0);
   }

   // calculate start bar
   int bars     = Min(ChangedBars, maxBarsBack);
   int startbar = Min(bars-1, Bars-maPeriods), prevTrend;
   if (startbar < 0) return(logInfo("onTick(2)  Tick="+ Ticks, ERR_HISTORY_INSUFFICIENT));

   // recalculate changed bars
   for (int bar=startbar; bar >= 0; bar--) {
      upperBand[bar] = iMA(NULL, NULL, maPeriods, 0, maMethod, PRICE_HIGH, bar);
      lowerBand[bar] = iMA(NULL, NULL, maPeriods, 0, maMethod, PRICE_LOW,  bar);

      prevTrend = trend[bar+1];
      if      (Close[bar] > upperBand[bar+1]) trend[bar] = _int(MathMax(prevTrend, 0)) + 1;
      else if (Close[bar] < lowerBand[bar+1]) trend[bar] = _int(MathMin(prevTrend, 0)) - 1;
      else                                    trend[bar] = prevTrend + Sign(prevTrend);
   }

   if (!__isSuperContext) {
      //UpdateTrendLegend(legendLabel, indicatorName, legendInfo, Color.UpTrend, Color.DownTrend, main[0], Digits, trend[0], Time[0]);

      // signal trend changes
      if (signalCrossing) {
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
   SetIndexStyle(MODE_TREND,      DRAW_NONE, EMPTY, EMPTY, CLR_NONE);
}


/**
 * Return a string representation of the input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("MA.Periods=",                MA.Periods,                            ";", NL,
                            "MA.Method=",                 DoubleQuoteStr(MA.Method),             ";", NL,
                            "Tunnel.Color=",              ColorToStr(Tunnel.Color),              ";", NL,
                            "Max.Bars=",                  Max.Bars,                              ";", NL,

                            "Signal.onTunnelCross",       BoolToStr(Signal.onTunnelCross),       ";", NL,
                            "Signal.onTunnelCross.Sound", BoolToStr(Signal.onTunnelCross.Sound), ";", NL,
                            "Signal.onTunnelCross.Popup", BoolToStr(Signal.onTunnelCross.Popup), ";", NL,
                            "Signal.onTunnelCross.Mail",  BoolToStr(Signal.onTunnelCross.Mail),  ";", NL,
                            "Signal.onTunnelCross.SMS",   BoolToStr(Signal.onTunnelCross.SMS),   ";")
   );
}
