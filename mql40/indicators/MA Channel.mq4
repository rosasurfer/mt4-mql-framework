/**
 * MA Channel
 *
 * An indicator forming a High/Low channel around a Moving Average. The indicator can display up to 3 separate channels.
 * This indicator provides the foundation for the XARD trend system.
 *
 *
 * Input parameters
 * ----------------
 *
 *
 * Supported Moving Average methods
 * --------------------------------
 *  • SMA  = Simple Moving Average:          equal bar weighting
 *  • LWMA = Linear Weighted Moving Average: bar weighting using a linear function
 *  • EMA  = Exponential Moving Average:     bar weighting using an exponential function
 *  • SMMA = Smoothed Moving Average:        bar weighting using an exponential function (an EMA of a different period)
 *  • ALMA = Arnaud Legoux Moving Average:   bar weighting using a Gaussian function (see notes)
 *
 *
 * Usage with iCustom()
 * --------------------
 * @see /mql40/include/rsf/functions/iCustom/MaChannel.mqh
 *
 *
 * Notes
 * -----
 *  • EMA calculation:
 *    @see https://web.archive.org/web/20221120050520/https://en.wikipedia.org/wiki/Moving_average#Exponential_moving_average
 *
 *  • SMMA calculation: The SMMA is an EMA with a different period. It holds true: SMMA(n) = EMA(2*n-1)
 *    @see https://web.archive.org/web/20221120050520/https://en.wikipedia.org/wiki/Moving_average#Modified_moving_average
 *
 *  • ALMA calculation:
 *    @see http://web.archive.org/web/20180307031850/http://www.arnaudlegoux.com/
 */
#include <rsf/stddefines.mqh>
int   __InitFlags[];
int __DeinitFlags[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern string ___a__________________________ = "=== MA definitions ===";
extern string MA1.Method                     = "SMA* | LWMA | EMA | SMMA | ALMA";
extern int    MA1.Periods                    = 100;
extern int    MA1.ChannelWidth.Pct           = 100;                     // percent of High/Low range
extern color  MA1.Color                      = Magenta;

extern string MA2.Method                     = "SMA* | LWMA | EMA | SMMA | ALMA";
extern int    MA2.Periods                    = 0;
extern int    MA2.ChannelWidth.Pct           = 100;
extern color  MA2.Color                      = Blue;

extern string MA3.Method                     = "SMA* | LWMA | EMA | SMMA | ALMA";
extern int    MA3.Periods                    = 0;
extern int    MA3.ChannelWidth.Pct           = 100;
extern color  MA3.Color                      = Red;

extern string ___b__________________________ = "=== Display options ===";
extern bool   ShowChartLegend                = true;
extern int    MaxBarsBack                    = 10000;                   // max. values to calculate (-1: all available)

extern string ___c__________________________ = "=== Signaling ===";
extern bool   Signal.onPositionChange        = false;                   // on BarClose crossing the position boundary
extern string Signal.onPosition.Types        = "sound* | alert | mail | telegram";
extern string Signal.onPosition.Sound.Above  = "Signal Up.wav";
extern string Signal.onPosition.Sound.Inside = "Signal Inside.wav";
extern string Signal.onPosition.Sound.Below  = "Signal Down.wav";

extern bool   Signal.onTrendChange           = false;                   // on BarClose causing a trend change
extern string Signal.onTrend.Types           = "sound* | alert | mail | telegram";
extern string Signal.onTrend.Sound.Up        = "Signal Up.wav";
extern string Signal.onTrend.Sound.Down      = "Signal Down.wav";

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <rsf/core/indicator.mqh>
#include <rsf/stdfunctions.mqh>
#include <rsf/stdlib.mqh>
#include <rsf/functions/chartlegend.mqh>
#include <rsf/functions/ConfigureSignals.mqh>
#include <rsf/functions/IsBarOpen.mqh>
#include <rsf/functions/ManageIntIndicatorBuffer.mqh>
#include <rsf/functions/ObjectCreateRegister.mqh>
#include <rsf/functions/iCustom/MaChannel.mqh>
#include <rsf/functions/ta/ALMA.mqh>

#define MODE_MA1_UPPER  MaChannel.MODE_MA1_UPPER_BAND    // 0 indicator buffer ids
#define MODE_MA1_LOWER  MaChannel.MODE_MA1_LOWER_BAND    // 1
#define MODE_MA2_UPPER  MaChannel.MODE_MA2_UPPER_BAND    // 2
#define MODE_MA2_LOWER  MaChannel.MODE_MA2_LOWER_BAND    // 3
#define MODE_MA3_UPPER  MaChannel.MODE_MA3_UPPER_BAND    // 4
#define MODE_MA3_LOWER  MaChannel.MODE_MA3_LOWER_BAND    // 5
#define MODE_POSITION   MaChannel.MODE_POSITION          // 6 price position inside/outside of the channel:    -1..0..+1
#define MODE_TREND      MaChannel.MODE_TREND             // 7 trend/length of the last outer channel crossing: -n..0..+n

#define MODE_MA1_POSITION   8                            // price position in relation to single MA channel: -1..0..+1
#define MODE_MA1_TREND      9                            // single MA channel trend:                         -n..0..+n
#define MODE_MA2_POSITION  10                            //
#define MODE_MA2_TREND     11                            //
#define MODE_MA3_POSITION  12                            //
#define MODE_MA3_TREND     13                            //

#property indicator_chart_window
#property indicator_buffers   8                          // buffers managed by the terminal
int       framework_buffers = 6;                         // buffers managed by the framework

#property indicator_color1    CLR_NONE
#property indicator_color2    CLR_NONE
#property indicator_color3    CLR_NONE
#property indicator_color4    CLR_NONE
#property indicator_color5    CLR_NONE
#property indicator_color6    CLR_NONE
#property indicator_color7    CLR_NONE
#property indicator_color8    CLR_NONE

bool   ma1.enabled;                                      // MA settings
int    ma1.method;                                       //
int    ma1.periods;                                      //
double ma1.upperBand[];                                  //
double ma1.lowerBand[];                                  //
int    ma1.position[];                                   //
int    ma1.trend[];                                      //
double ma1.almaWeights[];                                // ALMA bar weights (if applicable

bool   ma2.enabled;
int    ma2.method;
int    ma2.periods;
double ma2.upperBand[];
double ma2.lowerBand[];
int    ma2.position[];
int    ma2.trend[];
double ma2.almaWeights[];

bool   ma3.enabled;
int    ma3.method;
int    ma3.periods;
double ma3.upperBand[];
double ma3.lowerBand[];
int    ma3.position[];
int    ma3.trend[];
double ma3.almaWeights[];

double channelPosition[];                                // overall price position in relation to channel: -1..0..+1
double channelTrend[];                                   // overall channel trend (all MAs): -n..0..+n

int    maxMaPeriods;

string indicatorName = "";
string legendLabel = "";
string legendInfo = "";
color  legendColor;

bool   signal.onPosition.sound;
bool   signal.onPosition.alert;
bool   signal.onPosition.mail;
bool   signal.onPosition.telegram;

bool   signal.onTrend.sound;
bool   signal.onTrend.alert;
bool   signal.onTrend.mail;
bool   signal.onTrend.telegram;

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

   // MA1.Periods (enables/disables MA1 and must be checked first)
   ma1.enabled = false;
   if (AutoConfiguration) MA1.Periods = GetConfigInt(indicator, "MA1.Periods", MA1.Periods);
   if (MA1.Periods < 0)             return(catch("onInit(1)  invalid input parameter MA1.Periods: "+ MA1.Periods +" (must be >= zero)", ERR_INVALID_INPUT_PARAMETER));
   ma1.periods = MA1.Periods;
   if (!ma1.periods) {
      MA1.Method = "";
      MA1.ChannelWidth.Pct = 100;
   }
   else {
      // MA1.Method
      if (AutoConfiguration) MA1.Method = GetConfigString(indicator, "MA1.Method", MA1.Method);
      string sValues[], sValue = MA1.Method;
      if (Explode(sValue, "*", sValues, 2) > 1) {
         int size = Explode(sValues[0], "|", sValues, NULL);
         sValue = sValues[size-1];
      }
      ma1.method = StrToMaMethod(sValue, F_PARTIAL_ID|F_ERR_INVALID_PARAMETER);
      if (ma1.method == -1)         return(catch("onInit(2)  invalid input parameter MA1.Method: "+ DoubleQuoteStr(MA1.Method), ERR_INVALID_INPUT_PARAMETER));
      MA1.Method = MaMethodDescription(ma1.method);
      ma1.enabled = true;
      // MA1.ChannelWidth.Pct
      if (AutoConfiguration) MA1.ChannelWidth.Pct = GetConfigInt(indicator, "MA1.ChannelWidth.Pct", MA1.ChannelWidth.Pct);
      if (MA1.ChannelWidth.Pct < 1) return(catch("onInit(3)  invalid input parameter MA1.ChannelWidth.Pct: "+ MA1.ChannelWidth.Pct +" (must be > 0)", ERR_INVALID_INPUT_PARAMETER));
   }

   // MA2.Periods (enables/disables MA2 and must be checked first)
   ma2.enabled = false;
   if (AutoConfiguration) MA2.Periods = GetConfigInt(indicator, "MA2.Periods", MA2.Periods);
   if (MA2.Periods < 0)             return(catch("onInit(4)  invalid input parameter MA2.Periods: "+ MA2.Periods +" (must be >= zero)", ERR_INVALID_INPUT_PARAMETER));
   ma2.periods = MA2.Periods;
   if (!ma2.periods) {
      MA2.Method = "";
      MA2.ChannelWidth.Pct = 100;
   }
   else {
      // MA2.Method
      if (AutoConfiguration) MA2.Method = GetConfigString(indicator, "MA2.Method", MA2.Method);
      sValue = MA2.Method;
      if (Explode(sValue, "*", sValues, 2) > 1) {
         size = Explode(sValues[0], "|", sValues, NULL);
         sValue = sValues[size-1];
      }
      ma2.method = StrToMaMethod(sValue, F_PARTIAL_ID|F_ERR_INVALID_PARAMETER);
      if (ma2.method == -1)         return(catch("onInit(5)  invalid input parameter MA2.Method: "+ DoubleQuoteStr(MA2.Method), ERR_INVALID_INPUT_PARAMETER));
      MA2.Method = MaMethodDescription(ma2.method);
      ma2.enabled = true;
      // MA2.ChannelWidth.Pct
      if (AutoConfiguration) MA2.ChannelWidth.Pct = GetConfigInt(indicator, "MA2.ChannelWidth.Pct", MA2.ChannelWidth.Pct);
      if (MA2.ChannelWidth.Pct < 1) return(catch("onInit(6)  invalid input parameter MA2.ChannelWidth.Pct: "+ MA2.ChannelWidth.Pct +" (must be > 0)", ERR_INVALID_INPUT_PARAMETER));
   }

   // MA3.Periods (enables/disables MA3 and must be checked first)
   ma3.enabled = false;
   if (AutoConfiguration) MA3.Periods = GetConfigInt(indicator, "MA3.Periods", MA3.Periods);
   if (MA3.Periods < 0)             return(catch("onInit(7)  invalid input parameter MA3.Periods: "+ MA3.Periods +" (must be >= zero)", ERR_INVALID_INPUT_PARAMETER));
   ma3.periods = MA3.Periods;
   if (!ma3.periods) {
      MA3.Method = "";
      MA3.ChannelWidth.Pct = 100;
   }
   else {
      // MA3.Method
      if (AutoConfiguration) MA3.Method = GetConfigString(indicator, "MA3.Method", MA3.Method);
      sValue = MA3.Method;
      if (Explode(sValue, "*", sValues, 2) > 1) {
         size = Explode(sValues[0], "|", sValues, NULL);
         sValue = sValues[size-1];
      }
      ma3.method = StrToMaMethod(sValue, F_PARTIAL_ID|F_ERR_INVALID_PARAMETER);
      if (ma3.method == -1)         return(catch("onInit(8)  invalid input parameter MA3.Method: "+ DoubleQuoteStr(MA3.Method), ERR_INVALID_INPUT_PARAMETER));
      MA3.Method = MaMethodDescription(ma3.method);
      ma3.enabled = true;
      // MA3.ChannelWidth.Pct
      if (AutoConfiguration) MA3.ChannelWidth.Pct = GetConfigInt(indicator, "MA3.ChannelWidth.Pct", MA3.ChannelWidth.Pct);
      if (MA3.ChannelWidth.Pct < 1) return(catch("onInit(9)  invalid input parameter MA3.ChannelWidth.Pct: "+ MA3.ChannelWidth.Pct +" (must be > 0)", ERR_INVALID_INPUT_PARAMETER));
   }

   maxMaPeriods = Max(ma1.periods, ma2.periods, ma3.periods);
   if (!maxMaPeriods)               return(catch("onInit(10)  invalid MA definitions: at least one MA needs a period value", ERR_INVALID_INPUT_PARAMETER));

   // colors: after deserialization the terminal may turn CLR_NONE (0xFFFFFFFF) into Black (0xFF000000)
   if (AutoConfiguration) MA1.Color = GetConfigColor(indicator, "MA1.Color", MA1.Color);
   if (AutoConfiguration) MA2.Color = GetConfigColor(indicator, "MA2.Color", MA2.Color);
   if (AutoConfiguration) MA3.Color = GetConfigColor(indicator, "MA3.Color", MA3.Color);
   if (MA1.Color == 0xFF000000) MA1.Color = CLR_NONE;
   if (MA2.Color == 0xFF000000) MA2.Color = CLR_NONE;
   if (MA3.Color == 0xFF000000) MA3.Color = CLR_NONE;
   if      (ma1.enabled) legendColor = MA1.Color;
   else if (ma2.enabled) legendColor = MA2.Color;
   else                  legendColor = MA3.Color;

   // ShowChartLegend
   if (AutoConfiguration) ShowChartLegend = GetConfigBool(indicator, "ShowChartLegend", ShowChartLegend);
   // MaxBarsBack
   if (AutoConfiguration) MaxBarsBack = GetConfigInt(indicator, "MaxBarsBack", MaxBarsBack);
   if (MaxBarsBack < -1)            return(catch("onInit(11)  invalid input parameter MaxBarsBack: "+ MaxBarsBack, ERR_INVALID_INPUT_PARAMETER));
   if (MaxBarsBack == -1) MaxBarsBack = INT_MAX;

   // Signal.onPositionChange
   string signalId = "Signal.onPositionChange";
   legendInfo = "";
   if (!ConfigureSignals(signalId, AutoConfiguration, Signal.onPositionChange)) return(last_error);
   if (Signal.onPositionChange) {
      if (!ConfigureSignalTypes(signalId, Signal.onPosition.Types, AutoConfiguration, signal.onPosition.sound, signal.onPosition.alert, signal.onPosition.mail, signal.onPosition.telegram)) {
         return(catch("onInit(12)  invalid input parameter Signal.onPosition.Types: "+ DoubleQuoteStr(Signal.onPosition.Types), ERR_INVALID_INPUT_PARAMETER));
      }
      Signal.onPositionChange = (signal.onPosition.sound || signal.onPosition.alert || signal.onPosition.mail || signal.onPosition.telegram);
      if (Signal.onPositionChange) legendInfo = "("+ StrLeft(ifString(signal.onPosition.sound, "sound,", "") + ifString(signal.onPosition.alert, "alert,", "") + ifString(signal.onPosition.mail, "mail,", "") + ifString(signal.onPosition.telegram, "tgm,", ""), -1) +")";
   }

   // Signal.onTrendChange
   signalId = "Signal.onTrendChange";
   if (!ConfigureSignals(signalId, AutoConfiguration, Signal.onTrendChange)) return(last_error);
   if (Signal.onTrendChange) {
      if (!ConfigureSignalTypes(signalId, Signal.onTrend.Types, AutoConfiguration, signal.onTrend.sound, signal.onTrend.alert, signal.onTrend.mail, signal.onTrend.telegram)) {
         return(catch("onInit(13)  invalid input parameter Signal.onTrend.Types: "+ DoubleQuoteStr(Signal.onTrend.Types), ERR_INVALID_INPUT_PARAMETER));
      }
      Signal.onTrendChange = (signal.onTrend.sound || signal.onTrend.alert || signal.onTrend.mail || signal.onTrend.telegram);
      if (Signal.onTrendChange) legendInfo = StrTrimLeft(legendInfo +" (") + StrLeft(ifString(signal.onTrend.sound, "sound,", "") + ifString(signal.onTrend.alert, "alert,", "") + ifString(signal.onTrend.mail, "mail,", "") + ifString(signal.onTrend.telegram, "tgm,", ""), -1) +")";
   }

   // sounds
   if (AutoConfiguration) Signal.onPosition.Sound.Above  = GetConfigString(indicator, "Signal.onPosition.Sound.Above",  Signal.onPosition.Sound.Above);
   if (AutoConfiguration) Signal.onPosition.Sound.Inside = GetConfigString(indicator, "Signal.onPosition.Sound.Inside", Signal.onPosition.Sound.Inside);
   if (AutoConfiguration) Signal.onPosition.Sound.Below  = GetConfigString(indicator, "Signal.onPosition.Sound.Below",  Signal.onPosition.Sound.Below);

   if (AutoConfiguration) Signal.onTrend.Sound.Up   = GetConfigString(indicator, "Signal.onTrend.Sound.Up",   Signal.onTrend.Sound.Up);
   if (AutoConfiguration) Signal.onTrend.Sound.Down = GetConfigString(indicator, "Signal.onTrend.Sound.Down", Signal.onTrend.Sound.Down);

   // calculate ALMA bar weights
   double almaOffset=0.85, almaSigma=6.0;
   if (ma1.method == MODE_ALMA) ALMA.CalculateWeights(ma1.periods, almaOffset, almaSigma, ma1.almaWeights);
   if (ma2.method == MODE_ALMA) ALMA.CalculateWeights(ma2.periods, almaOffset, almaSigma, ma2.almaWeights);
   if (ma3.method == MODE_ALMA) ALMA.CalculateWeights(ma3.periods, almaOffset, almaSigma, ma3.almaWeights);

   // buffer management and display options
   SetIndicatorOptions();
   if (ShowChartLegend) legendLabel = CreateChartLegend();

   return(catch("onInit(14)"));
}


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   // manage additional framework buffers
   ManageIntIndicatorBuffer(MODE_MA1_POSITION, ma1.position, 0);
   ManageIntIndicatorBuffer(MODE_MA1_TREND,    ma1.trend,    0);
   ManageIntIndicatorBuffer(MODE_MA2_POSITION, ma2.position, 0);
   ManageIntIndicatorBuffer(MODE_MA2_TREND,    ma2.trend,    0);
   ManageIntIndicatorBuffer(MODE_MA3_POSITION, ma3.position, 0);
   ManageIntIndicatorBuffer(MODE_MA3_TREND,    ma3.trend,    0);

   // reset buffers before performing a full recalculation
   if (!ValidBars) {
      ArrayInitialize(ma1.upperBand, EMPTY_VALUE);
      ArrayInitialize(ma1.lowerBand, EMPTY_VALUE);
      ArrayInitialize(ma1.position,            0);
      ArrayInitialize(ma1.trend,               0);
      ArrayInitialize(ma2.upperBand, EMPTY_VALUE);
      ArrayInitialize(ma2.lowerBand, EMPTY_VALUE);
      ArrayInitialize(ma2.position,            0);
      ArrayInitialize(ma2.trend,               0);
      ArrayInitialize(ma3.upperBand, EMPTY_VALUE);
      ArrayInitialize(ma3.lowerBand, EMPTY_VALUE);
      ArrayInitialize(ma3.position,            0);
      ArrayInitialize(ma3.trend,               0);
      ArrayInitialize(channelPosition,         0);
      ArrayInitialize(channelTrend,            0);
      SetIndicatorOptions();
   }

   // synchronize buffers with a shifted offline chart
   if (ShiftedBars > 0) {
      ShiftDoubleIndicatorBuffer(ma1.upperBand,   Bars, ShiftedBars, EMPTY_VALUE);
      ShiftDoubleIndicatorBuffer(ma1.lowerBand,   Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIntIndicatorBuffer   (ma1.position,    Bars, ShiftedBars,           0);
      ShiftIntIndicatorBuffer   (ma1.trend,       Bars, ShiftedBars,           0);
      ShiftDoubleIndicatorBuffer(ma2.upperBand,   Bars, ShiftedBars, EMPTY_VALUE);
      ShiftDoubleIndicatorBuffer(ma2.lowerBand,   Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIntIndicatorBuffer   (ma2.position,    Bars, ShiftedBars,           0);
      ShiftIntIndicatorBuffer   (ma2.trend,       Bars, ShiftedBars,           0);
      ShiftDoubleIndicatorBuffer(ma3.upperBand,   Bars, ShiftedBars, EMPTY_VALUE);
      ShiftDoubleIndicatorBuffer(ma3.lowerBand,   Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIntIndicatorBuffer   (ma3.position,    Bars, ShiftedBars,           0);
      ShiftIntIndicatorBuffer   (ma3.trend,       Bars, ShiftedBars,           0);
      ShiftDoubleIndicatorBuffer(channelPosition, Bars, ShiftedBars,           0);
      ShiftDoubleIndicatorBuffer(channelTrend,    Bars, ShiftedBars,           0);
   }

   double range, extension;

   // calculate start bar
   int startbar = Min(MaxBarsBack-1, ChangedBars-1, Bars-maxMaPeriods), prevTrend;
   if (startbar < 0 && MaxBarsBack) return(logInfo("onTick(1)  Tick="+ Ticks, ERR_HISTORY_INSUFFICIENT));

   // recalculate changed bars
   for (int bar=startbar, i; bar >= 0; bar--) {
      // MA1 channel
      if (ma1.enabled) {
         if (ma1.method == MODE_ALMA) {
            ma1.upperBand[bar] = 0;
            ma1.lowerBand[bar] = 0;
            for (i=0; i < ma1.periods; i++) {
               ma1.upperBand[bar] += ma1.almaWeights[i] * High[bar+i];
               ma1.lowerBand[bar] += ma1.almaWeights[i] * Low [bar+i];
            }
         }
         else {
            ma1.upperBand[bar] = iMA(NULL, NULL, ma1.periods, 0, ma1.method, PRICE_HIGH, bar);
            ma1.lowerBand[bar] = iMA(NULL, NULL, ma1.periods, 0, ma1.method, PRICE_LOW,  bar);
         }
         if (MA1.ChannelWidth.Pct != 100) {
            range     = ma1.upperBand[bar] - ma1.lowerBand[bar];
            extension = (MA1.ChannelWidth.Pct - 100) / 100.0 / 2;
            ma1.upperBand[bar] += extension * range;
            ma1.lowerBand[bar] -= extension * range;
         }

         if      (Close[bar] > ma1.upperBand[bar]) ma1.position[bar] = +1;
         else if (Close[bar] < ma1.lowerBand[bar]) ma1.position[bar] = -1;
         else                                      ma1.position[bar] =  0;

         prevTrend = ma1.trend[bar+1];
         if      (Close[bar] > ma1.upperBand[bar]) ma1.trend[bar] = Max(prevTrend, 0) + 1;
         else if (Close[bar] < ma1.lowerBand[bar]) ma1.trend[bar] = Min(prevTrend, 0) - 1;
         else                                      ma1.trend[bar] = prevTrend + Sign(prevTrend);
      }

      // MA2 channel
      if (ma2.enabled) {
         if (ma2.method == MODE_ALMA) {
            ma2.upperBand[bar] = 0;
            ma2.lowerBand[bar] = 0;
            for (i=0; i < ma2.periods; i++) {
               ma2.upperBand[bar] += ma2.almaWeights[i] * High[bar+i];
               ma2.lowerBand[bar] += ma2.almaWeights[i] * Low [bar+i];
            }
         }
         else {
            ma2.upperBand[bar] = iMA(NULL, NULL, ma2.periods, 0, ma2.method, PRICE_HIGH, bar);
            ma2.lowerBand[bar] = iMA(NULL, NULL, ma2.periods, 0, ma2.method, PRICE_LOW,  bar);
         }
         if (MA2.ChannelWidth.Pct != 100) {
            range     = ma2.upperBand[bar] - ma2.lowerBand[bar];
            extension = (MA2.ChannelWidth.Pct - 100) / 100.0 / 2;
            ma2.upperBand[bar] += extension * range;
            ma2.lowerBand[bar] -= extension * range;
         }

         if      (Close[bar] > ma2.upperBand[bar]) ma2.position[bar] = +1;
         else if (Close[bar] < ma2.lowerBand[bar]) ma2.position[bar] = -1;
         else                                      ma2.position[bar] =  0;

         prevTrend = ma2.trend[bar+1];
         if      (Close[bar] > ma2.upperBand[bar]) ma2.trend[bar] = Max(prevTrend, 0) + 1;
         else if (Close[bar] < ma2.lowerBand[bar]) ma2.trend[bar] = Min(prevTrend, 0) - 1;
         else                                      ma2.trend[bar] = prevTrend + Sign(prevTrend);
      }

      // MA3 channel
      if (ma3.enabled) {
         if (ma3.method == MODE_ALMA) {
            ma3.upperBand[bar] = 0;
            ma3.lowerBand[bar] = 0;
            for (i=0; i < ma3.periods; i++) {
               ma3.upperBand[bar] += ma3.almaWeights[i] * High[bar+i];
               ma3.lowerBand[bar] += ma3.almaWeights[i] * Low [bar+i];
            }
         }
         else {
            ma3.upperBand[bar] = iMA(NULL, NULL, ma3.periods, 0, ma3.method, PRICE_HIGH, bar);
            ma3.lowerBand[bar] = iMA(NULL, NULL, ma3.periods, 0, ma3.method, PRICE_LOW,  bar);
         }
         if (MA3.ChannelWidth.Pct != 100) {
            range     = ma3.upperBand[bar] - ma3.lowerBand[bar];
            extension = (MA3.ChannelWidth.Pct - 100) / 100.0 / 2;
            ma3.upperBand[bar] += extension * range;
            ma3.lowerBand[bar] -= extension * range;
         }

         if      (Close[bar] > ma3.upperBand[bar]) ma3.position[bar] = +1;
         else if (Close[bar] < ma3.lowerBand[bar]) ma3.position[bar] = -1;
         else                                      ma3.position[bar] =  0;

         prevTrend = ma3.trend[bar+1];
         if      (Close[bar] > ma3.upperBand[bar]) ma3.trend[bar] = Max(prevTrend, 0) + 1;
         else if (Close[bar] < ma3.lowerBand[bar]) ma3.trend[bar] = Min(prevTrend, 0) - 1;
         else                                      ma3.trend[bar] = prevTrend + Sign(prevTrend);
      }

      // overall channel position
      bool allUp = true;
      if (ma1.enabled) allUp = allUp && ma1.position[bar] > 0;
      if (ma2.enabled) allUp = allUp && ma2.position[bar] > 0;
      if (ma3.enabled) allUp = allUp && ma3.position[bar] > 0;

      bool allDown = true;
      if (ma1.enabled) allDown = allDown && ma1.position[bar] < 0;
      if (ma2.enabled) allDown = allDown && ma2.position[bar] < 0;
      if (ma3.enabled) allDown = allDown && ma3.position[bar] < 0;

      if      (allUp)   channelPosition[bar] = +1;
      else if (allDown) channelPosition[bar] = -1;
      else              channelPosition[bar] =  0;

      // overall channel trend
      allUp = true;
      if (ma1.enabled) allUp = allUp && ma1.trend[bar] > 0;
      if (ma2.enabled) allUp = allUp && ma2.trend[bar] > 0;
      if (ma3.enabled) allUp = allUp && ma3.trend[bar] > 0;

      allDown = true;
      if (ma1.enabled) allDown = allDown && ma1.trend[bar] < 0;
      if (ma2.enabled) allDown = allDown && ma2.trend[bar] < 0;
      if (ma3.enabled) allDown = allDown && ma3.trend[bar] < 0;

      prevTrend = channelTrend[bar+1];
      if      (allUp)   channelTrend[bar] = Max(prevTrend, 0) + 1;
      else if (allDown) channelTrend[bar] = Min(prevTrend, 0) - 1;
      else              channelTrend[bar] = prevTrend + Sign(prevTrend);
   }

   if (__isChart && !__isSuperContext) {
      if (ShowChartLegend) UpdateChartLegend();

      // monitor signals
      if (Signal.onPositionChange || Signal.onTrendChange) {
         if (IsBarOpen()) {
            if (Signal.onPositionChange) {
               if (channelPosition[1] != channelPosition[2]) {
                  onPositionChange(channelPosition[1]);
               }
            }
            if (Signal.onTrendChange) {
               if      (channelTrend[1] ==  1) onTrendChange(D_LONG);
               else if (channelTrend[1] == -1) onTrendChange(D_SHORT);
            }
         }
      }
   }
   return(last_error);
}


/**
 * Event handler signaling a price change relative to the channel position.
 *
 * @param  int position - new position: -1..0..+1
 *
 * @return bool - success status
 */
bool onPositionChange(int position) {
   if (Abs(position) > 1)        return(!catch("onPositionChange(1)  invalid parameter position: "+ position, ERR_INVALID_PARAMETER));
   if (!Signal.onPositionChange) return(false);
   if (ChangedBars > 2)          return(false);

   static string sPositions[] = { "below", "inside", "above" };

   // skip the signal if it was already handled elsewhere
   string sPeriod   = PeriodDescription();
   string eventName = "rsf."+ StdSymbol() +","+ sPeriod +"."+ indicatorName +".onPositionChange("+ position +")."+ TimeToStr(Time[0]), propertyName = "";
   string message1  = "bar close "+ sPositions[position+1] +" "+ indicatorName;
   string message2  = Symbol() +","+ sPeriod +": "+ message1;
   string localTime = TimeToStr(TimeLocalEx("onPositionChange(2)"), TIME_MINUTES|TIME_SECONDS);
   string alias     = GetAccountAlias();
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
      if (eventAction) logInfo("onPositionChange(3)  "+ message1);
   }

   // sound: once per system
   if (signal.onPosition.sound) {
      eventAction = true;
      if (!__isTesting) {
         propertyName = eventName +"|sound";
         eventAction = !GetWindowPropertyA(hWndDesktop, propertyName);
         SetWindowPropertyA(hWndDesktop, propertyName, 1);
      }
      if (eventAction) {
         if      (position > 0) PlaySoundEx(Signal.onPosition.Sound.Above);
         else if (position < 0) PlaySoundEx(Signal.onPosition.Sound.Below);
         else                   PlaySoundEx(Signal.onPosition.Sound.Inside);
      }
   }

   // alert: once per terminal
   if (signal.onPosition.alert) {
      eventAction = true;
      if (!__isTesting) {
         propertyName = eventName +"|alert";
         eventAction = !GetWindowPropertyA(hWndTerminal, propertyName);
         SetWindowPropertyA(hWndTerminal, propertyName, 1);
      }
      if (eventAction) Alert(message2);
   }

   // mail: once per system
   if (signal.onPosition.mail) {
      eventAction = true;
      if (!__isTesting) {
         propertyName = eventName +"|mail";
         eventAction = !GetWindowPropertyA(hWndDesktop, propertyName);
         SetWindowPropertyA(hWndDesktop, propertyName, 1);
      }
      if (eventAction) SendEmail("", "", message2, message2 + NL +"("+ localTime +", "+ alias +")");
   }

   // telegram: once per system
   if (signal.onPosition.telegram) {
      eventAction = true;
      if (!__isTesting) {
         propertyName = eventName +"|telegram";
         eventAction = !GetWindowPropertyA(hWndDesktop, propertyName);
         SetWindowPropertyA(hWndDesktop, propertyName, 1);
      }
      if (eventAction) SendTelegramMessage("signal", message2 + NL +"("+ localTime +", "+ alias +")");
   }
   return(!catch("onPositionChange(4)"));
}


/**
 * Event handler signaling a trend change.
 *
 * @param  int direction - trend direction: D_LONG | D_SHORT
 *
 * @return bool - success status
 */
bool onTrendChange(int direction) {
   if (direction!=D_LONG && direction!=D_SHORT) return(!catch("onTrendChange(1)  invalid parameter direction: "+ direction, ERR_INVALID_PARAMETER));
   if (!Signal.onTrendChange)                   return(false);
   if (ChangedBars > 2)                         return(false);

   static string sTrendDirections[] = { "", "up", "down" };

   // skip the signal if it was already handled elsewhere
   string sPeriod   = PeriodDescription();
   string eventName = "rsf."+ StdSymbol() +","+ sPeriod +"."+ indicatorName +".onTrendChange("+ direction +")."+ TimeToStr(Time[0]), propertyName = "";
   string message1  = "bar close on "+ indicatorName +" changed to "+ sTrendDirections[direction] +" trend";
   string message2  = Symbol() +","+ sPeriod +": "+ message1;
   string localTime = TimeToStr(TimeLocalEx("onTrendChange(2)"), TIME_MINUTES|TIME_SECONDS);
   string alias     = GetAccountAlias();
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
      if (eventAction) logInfo("onTrendChange(3)  "+ message1);
   }

   // sound: once per system
   if (signal.onTrend.sound) {
      eventAction = true;
      if (!__isTesting) {
         propertyName = eventName +"|sound";
         eventAction = !GetWindowPropertyA(hWndDesktop, propertyName);
         SetWindowPropertyA(hWndDesktop, propertyName, 1);
      }
      if (eventAction) PlaySoundEx(ifString(direction==D_LONG, Signal.onTrend.Sound.Up, Signal.onTrend.Sound.Down));
   }

   // alert: once per terminal
   if (signal.onTrend.alert) {
      eventAction = true;
      if (!__isTesting) {
         propertyName = eventName +"|alert";
         eventAction = !GetWindowPropertyA(hWndTerminal, propertyName);
         SetWindowPropertyA(hWndTerminal, propertyName, 1);
      }
      if (eventAction) Alert(message2);
   }

   // mail: once per system
   if (signal.onTrend.mail) {
      eventAction = true;
      if (!__isTesting) {
         propertyName = eventName +"|mail";
         eventAction = !GetWindowPropertyA(hWndDesktop, propertyName);
         SetWindowPropertyA(hWndDesktop, propertyName, 1);
      }
      if (eventAction) SendEmail("", "", message2, message2 + NL +"("+ localTime +", "+ alias +")");
   }

   // telegram: once per system
   if (signal.onTrend.telegram) {
      eventAction = true;
      if (!__isTesting) {
         propertyName = eventName +"|telegram";
         eventAction = !GetWindowPropertyA(hWndDesktop, propertyName);
         SetWindowPropertyA(hWndDesktop, propertyName, 1);
      }
      if (eventAction) SendTelegramMessage("signal", message2 + NL +"("+ localTime +", "+ alias +")");
   }
   return(!catch("onTrendChange(4)"));
}


/**
 * Update the chart legend.
 */
void UpdateChartLegend() {
   double upperValue = 0, lowerValue = INT_MAX;

   if (channelPosition[1] > 0) {
      // resolve the nearest lower channel band
      if (ma1.enabled) upperValue = ma1.lowerBand[0];
      if (ma2.enabled) upperValue = MathMax(upperValue, ma2.lowerBand[0]);
      if (ma3.enabled) upperValue = MathMax(upperValue, ma3.lowerBand[0]);

      // resolve the farest lower channel band
      if (ma1.enabled) lowerValue = ma1.lowerBand[0];
      if (ma2.enabled) lowerValue = MathMin(lowerValue, ma2.lowerBand[0]);
      if (ma3.enabled) lowerValue = MathMin(lowerValue, ma3.lowerBand[0]);
   }
   else if (channelPosition[1] < 0) {
      // resolve the farest upper channel band
      if (ma1.enabled) upperValue = ma1.upperBand[0];
      if (ma2.enabled) upperValue = MathMax(upperValue, ma2.upperBand[0]);
      if (ma3.enabled) upperValue = MathMax(upperValue, ma3.upperBand[0]);

      // resolve the nearest upper channel band
      if (ma1.enabled) lowerValue = ma1.upperBand[0];
      if (ma2.enabled) lowerValue = MathMin(lowerValue, ma2.upperBand[0]);
      if (ma3.enabled) lowerValue = MathMin(lowerValue, ma3.upperBand[0]);
   }
   else {
      // resolve the farest upper band
      if (ma1.enabled) upperValue = ma1.upperBand[0];
      if (ma2.enabled) upperValue = MathMax(upperValue, ma2.upperBand[0]);
      if (ma3.enabled) upperValue = MathMax(upperValue, ma3.upperBand[0]);

      // resolve the farest lower band
      if (ma1.enabled) lowerValue = ma1.lowerBand[0];
      if (ma2.enabled) lowerValue = MathMin(lowerValue, ma2.lowerBand[0]);
      if (ma3.enabled) lowerValue = MathMin(lowerValue, ma3.lowerBand[0]);
   }

   string sUpperValue = NumberToStr(upperValue, PriceFormat);
   string sLowerValue = NumberToStr(lowerValue, PriceFormat);
   string text = StringConcatenate(indicatorName, "   ", sUpperValue, " / ", sLowerValue, "   ", legendInfo);

   color  textColor = legendColor;
   if      (textColor == Aqua        ) textColor = DodgerBlue;
   else if (textColor == Gold        ) textColor = Orange;
   else if (textColor == LightSkyBlue) textColor = C'94,174,255';
   else if (textColor == Lime        ) textColor = LimeGreen;
   else if (textColor == Yellow      ) textColor = Orange;
   ObjectSetText(legendLabel, text, 9, "Arial Fett", textColor);

   int error = GetLastError();                                    // on ObjectDrag or opened "Properties" dialog
   if (error && error!=ERR_OBJECT_DOES_NOT_EXIST) catch("UpdateChartLegend(1)", error);
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

   SetIndexBuffer(MODE_MA1_UPPER, ma1.upperBand);
   SetIndexBuffer(MODE_MA1_LOWER, ma1.lowerBand);
   SetIndexStyle (MODE_MA1_UPPER, DRAW_LINE, EMPTY, EMPTY, MA1.Color);
   SetIndexStyle (MODE_MA1_LOWER, DRAW_LINE, EMPTY, EMPTY, MA1.Color);
   SetIndexLabel (MODE_MA1_UPPER, MA1.Method +"("+ MA1.Periods +") upper band");
   SetIndexLabel (MODE_MA1_LOWER, MA1.Method +"("+ MA1.Periods +") lower band");

   SetIndexBuffer(MODE_MA2_UPPER, ma2.upperBand);
   SetIndexBuffer(MODE_MA2_LOWER, ma2.lowerBand);
   SetIndexStyle (MODE_MA2_UPPER, DRAW_LINE, EMPTY, EMPTY, MA2.Color);
   SetIndexStyle (MODE_MA2_LOWER, DRAW_LINE, EMPTY, EMPTY, MA2.Color);
   SetIndexLabel (MODE_MA2_UPPER, MA2.Method +"("+ MA2.Periods +") upper band");
   SetIndexLabel (MODE_MA2_LOWER, MA2.Method +"("+ MA2.Periods +") lower band");

   SetIndexBuffer(MODE_MA3_UPPER, ma3.upperBand);
   SetIndexBuffer(MODE_MA3_LOWER, ma3.lowerBand);
   SetIndexStyle (MODE_MA3_UPPER, DRAW_LINE, EMPTY, EMPTY, MA3.Color);
   SetIndexStyle (MODE_MA3_LOWER, DRAW_LINE, EMPTY, EMPTY, MA3.Color);
   SetIndexLabel (MODE_MA3_UPPER, MA3.Method +"("+ MA3.Periods +") upper band");
   SetIndexLabel (MODE_MA3_LOWER, MA3.Method +"("+ MA3.Periods +") lower band");

   if (!ma1.enabled) {
      SetIndexStyle(MODE_MA1_UPPER, DRAW_NONE);
      SetIndexStyle(MODE_MA1_LOWER, DRAW_NONE);
      SetIndexLabel(MODE_MA1_UPPER, NULL);
      SetIndexLabel(MODE_MA1_LOWER, NULL);
   }
   if (!ma2.enabled) {
      SetIndexStyle(MODE_MA2_UPPER, DRAW_NONE);
      SetIndexStyle(MODE_MA2_LOWER, DRAW_NONE);
      SetIndexLabel(MODE_MA2_UPPER, NULL);
      SetIndexLabel(MODE_MA2_LOWER, NULL);
   }
   if (!ma3.enabled) {
      SetIndexStyle(MODE_MA3_UPPER, DRAW_NONE);
      SetIndexStyle(MODE_MA3_LOWER, DRAW_NONE);
      SetIndexLabel(MODE_MA3_UPPER, NULL);
      SetIndexLabel(MODE_MA3_LOWER, NULL);
   }

   SetIndexBuffer(MODE_POSITION, channelPosition);
   SetIndexStyle (MODE_POSITION, DRAW_NONE);
   SetIndexLabel (MODE_POSITION, "MA Channel position");

   SetIndexBuffer(MODE_TREND, channelTrend);
   SetIndexStyle (MODE_TREND, DRAW_NONE);
   SetIndexLabel (MODE_TREND, "MA Channel trend");

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

   if (ma1.enabled) {
      sameMethods      = MA1.Method +"("+ MA1.Periods;
      differentMethods = differentMethods +","+ MA1.Method +"("+ MA1.Periods +")";
   }
   if (ma2.enabled) {
      if (sameMethods == "") sameMethods = MA2.Method +"("+ MA2.Periods;
      else                   sameMethods = sameMethods +","+ MA2.Periods;
      differentMethods = differentMethods +","+ MA2.Method +"("+ MA2.Periods +")";

      if (ma1.enabled) {
         allSameMethod = (ma1.method == ma2.method);
      }
   }
   if (ma3.enabled) {
      if (sameMethods == "") sameMethods = MA3.Method +"("+ MA3.Periods;
      else                   sameMethods = sameMethods +","+ MA3.Periods;
      differentMethods = differentMethods +","+ MA3.Method +"("+ MA3.Periods +")";

      if (ma1.enabled) {
         allSameMethod = (ma1.method == ma3.method);
      }
      if (ma2.enabled) {
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
      "MA1.Method=",                     DoubleQuoteStr(MA1.Method)                     +";"+ NL,
      "MA1.Periods=",                    MA1.Periods                                    +";"+ NL,
      "MA1.ChannelWidth.Pct=",           MA1.ChannelWidth.Pct                           +";"+ NL,
      "MA1.Color=",                      ColorToStr(MA1.Color)                          +";"+ NL,

      "MA2.Method=",                     DoubleQuoteStr(MA2.Method)                     +";"+ NL,
      "MA2.Periods=",                    MA2.Periods                                    +";"+ NL,
      "MA2.ChannelWidth.Pct=",           MA2.ChannelWidth.Pct                           +";"+ NL,
      "MA2.Color=",                      ColorToStr(MA2.Color)                          +";"+ NL,

      "MA3.Method=",                     DoubleQuoteStr(MA3.Method)                     +";"+ NL,
      "MA3.Periods=",                    MA3.Periods                                    +";"+ NL,
      "MA3.ChannelWidth.Pct=",           MA3.ChannelWidth.Pct                           +";"+ NL,
      "MA3.Color=",                      ColorToStr(MA3.Color)                          +";"+ NL,

      "ShowChartLegend=",                BoolToStr(ShowChartLegend)                     +";"+ NL,
      "MaxBarsBack=",                    MaxBarsBack                                    +";"+ NL,

      "Signal.onPositionChange=",        BoolToStr(Signal.onPositionChange)             +";"+ NL,
      "Signal.onPosition.Types=",        DoubleQuoteStr(Signal.onPosition.Types)        +";"+ NL,
      "Signal.onPosition.Sound.Above=",  DoubleQuoteStr(Signal.onPosition.Sound.Above)  +";"+ NL,
      "Signal.onPosition.Sound.Inside=", DoubleQuoteStr(Signal.onPosition.Sound.Inside) +";"+ NL,
      "Signal.onPosition.Sound.Below=",  DoubleQuoteStr(Signal.onPosition.Sound.Below)  +";"+ NL,

      "Signal.onTrendChange=",           BoolToStr(Signal.onTrendChange)                +";"+ NL,
      "Signal.onTrend.Types=",           DoubleQuoteStr(Signal.onTrend.Types)           +";"+ NL,
      "Signal.onTrend.Sound..Up=",       DoubleQuoteStr(Signal.onTrend.Sound.Up)        +";"+ NL,
      "Signal.onTrend.Sound..Down=",     DoubleQuoteStr(Signal.onTrend.Sound.Down)      +";"+ NL
   ));

   // suppress compiler warnings
   icMaChannel(NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
}
