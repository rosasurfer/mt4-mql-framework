/**
 * A ZigZag indicator with non-repainting reversal points suitable for automation.
 *
 *
 * The ZigZag indicator provided by MetaQuotes is flawed and the implementation performes badly. The indicator repaints past
 * ZigZag semaphores and can't be used for automation.
 *
 * This indicator fixes those issues. The display can be changed from ZigZag lines to reversal points (aka semaphores). Once
 * the ZigZag direction changed the semaphore will not change anymore. Similar to the MetaQuotes version this indicator uses
 * a Donchian channel for calculating legs and reversals. Additionally this indicator can draw vertical line segments if a
 * large bar crosses both upper and lower Donchian channel band. Additionally it can display the trail of a ZigZag leg as it
 * develops over time. Also it supports manual period stepping via hotkey (keyboard). Finally the indicator supports multiple
 * signaling and sound options.
 *
 *
 * Input parameters
 * ----------------
 *  • ZigZag.Periods:               Lookback periods of the Donchian channel.
 *  • ZigZag.Periods.Step:          Controls parameter 'ZigZag.Periods' via the keyboard. If non-zero it enables the parameter
 *                                   stepper and defines its step size. If zero the parameter stepper is disabled.
 *  • ZigZag.Type:                  Whether to display the ZigZag line or ZigZag semaphores.
 *  • ZigZag.Width:                 The ZigZag's line width/semaphore size.
 *  • ZigZag.Semaphores.Wingdings:  WingDing symbol used for ZigZag semaphores.
 *  • ZigZag.Color:                 Color of ZigZag line/semaphores.
 *
 *  • Donchian.ShowChannel:         Whether to display the internal Donchian channel.
 *  • Donchian.ShowCrossings:       Which Donchian channel crossings to display, one of:
 *                                   "off":   No crossings are displayed.
 *                                   "first": Only the first crossing per direction is displayed (the moment when ZigZag creates a new leg).
 *                                   "all":   All crossings are displayed. Displays the trail of a ZigZag leg as it develops over time.
 *  • Donchian.Crossings.Width:     Size of displayed Donchian channel crossings.
 *  • Donchian.Crossings.Wingdings: WingDing symbol used for Donchian channel crossings.
 *  • Donchian.Upper.Color:         Color of upper Donchian channel band/upper crossings.
 *  • Donchian.Lower.Color:         Color of lower Donchian channel band/lower crossings.
 *
 *  • ShowChartLegend:              Whether do display the chart legend.
 *  • MaxBarsBack:                  Maximum number of bars back to calculate the indicator (performance).
 *
 *  • Signal.onReversal:            Whether to signal ZigZag reversals (the moment when ZigZag creates a new leg).
 *  • Signal.onReversal.Types:      Reversal signaling methods, can be a combination of "sound", "alert", "mail", "sms".
 *
 *  • Signal.onBreakout:            Whether to signal ZigZag breakouts (price exceeding the previous swing's ZigZag semaphore).
 *  • Signal.onBreakout.Types:      Breakout signaling methods, can be a combination of "sound", "alert", "mail", "sms".
 *
 *  • Signal.Sound.Up:              Sound file for reversal and breakout signals.
 *  • Signal.Sound.Down:            Sound file for reversal and breakout signals.
 *
 *  • Sound.onChannelWidening:      Whether to play a sound on Donchian channel widening (channel crossings).
 *  • Sound.onNewChannelHigh:       Sound file for Donchian channel widenings.
 *  • Sound.onNewChannelLow:        Sound file for Donchian channel widenings.
 *
 *  • AutoConfiguration:            If enabled all input parameters can be overwritten with custom default values.
 *
 *
 *
 * TODO:
 *  - fix triple-crossing at GBPJPY,M5 2023.12.18 00:00, ZigZag(20)
 *  - track swing sizes and display zero sum projection (ZigZag mean reversion)
 *  - keep bar status in IsUpperCrossLast()
 *  - document usage of iCustom()
 */
#include <rsf/stddefines.mqh>
int   __InitFlags[];
int __DeinitFlags[];

///////////////////////////////////////////////////// Input parameters //////////////////////////////////////////////////////

extern string ___a__________________________ = "=== ZigZag settings ===";
extern int    ZigZag.Periods                 = 40;                            // lookback periods of the Donchian channel
extern int    ZigZag.Periods.Step            = 0;                             // step size for a stepped input parameter (hotkey)
extern string ZigZag.Type                    = "Lines* | Semaphores";         // ZigZag lines or reversal points (can be shortened)
extern int    ZigZag.Width                   = 2;
extern int    ZigZag.Semaphores.Wingdings    = 108;                           // a large point
extern color  ZigZag.Color                   = Blue;

extern string ___b__________________________ = "=== Donchian settings ===";
extern bool   Donchian.ShowChannel           = true;                          // whether to display the Donchian channel
extern string Donchian.ShowCrossings         = "off | first* | all";          // which channel crossings to display
extern int    Donchian.Crossings.Width       = 1;
extern int    Donchian.Crossings.Wingdings   = 163;                           // a small ring
extern color  Donchian.Upper.Color           = Blue;
extern color  Donchian.Lower.Color           = Magenta;

extern string ___c__________________________ = "=== Display settings ===";
extern bool   ShowChartLegend                = true;
extern int    MaxBarsBack                    = 10000;                         // max. values to calculate (-1: all available)

extern string ___d__________________________ = "=== Signaling ===";
extern bool   Signal.onReversal              = false;                         // signal ZigZag reversals (first Donchian channel crossing)
extern string Signal.onReversal.Types        = "sound* | alert | mail | sms";

extern bool   Signal.onBreakout              = false;                         // signal ZigZag breakouts
extern string Signal.onBreakout.Types        = "sound* | alert | mail | sms";

extern string Signal.Sound.Up                = "Signal Up.wav";
extern string Signal.Sound.Down              = "Signal Down.wav";

extern bool   Sound.onChannelWidening        = false;                         // signal Donchian channel widenings
extern string Sound.onNewChannelHigh         = "Price Advance.wav";
extern string Sound.onNewChannelLow          = "Price Decline.wav";

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <rsf/core/indicator.mqh>
#include <rsf/stdfunctions.mqh>
#include <rsf/stdlib.mqh>
#include <rsf/functions/chartlegend.mqh>
#include <rsf/functions/ConfigureSignals.mqh>
#include <rsf/functions/HandleCommands.mqh>
#include <rsf/functions/ManageDoubleIndicatorBuffer.mqh>
#include <rsf/functions/ManageIntIndicatorBuffer.mqh>
#include <rsf/functions/ObjectCreateRegister.mqh>
#include <rsf/functions/iCustom/ZigZag.mqh>
#include <rsf/win32api.mqh>

// indicator buffer ids
#define MODE_SEMAPHORE_OPEN      ZigZag.MODE_SEMAPHORE_OPEN    //  0: semaphore open prices
#define MODE_SEMAPHORE_CLOSE     ZigZag.MODE_SEMAPHORE_CLOSE   //  1: semaphore close prices
#define MODE_UPPER_BAND          ZigZag.MODE_UPPER_BAND        //  2: upper channel band
#define MODE_LOWER_BAND          ZigZag.MODE_LOWER_BAND        //  3: lower channel band
#define MODE_UPPER_CROSS         ZigZag.MODE_UPPER_CROSS       //  4: upper channel band crossings
#define MODE_LOWER_CROSS         ZigZag.MODE_LOWER_CROSS       //  5: lower channel band crossings
#define MODE_REVERSAL            ZigZag.MODE_REVERSAL          //  6: offset of the previous reversal pount to the preceeding ZigZag semaphore
#define MODE_COMBINED_TREND      ZigZag.MODE_TREND             //  7: trend (combined buffers MODE_KNOWN_TREND and MODE_UNKNOWN_TREND)
#define MODE_HIGHER_HIGH         8                             //  8: new High after an upper channel band crossing (potential new semaphore)
#define MODE_LOWER_LOW           9                             //  9: new Low after a lower channel band crossing (potential new semaphore)
#define MODE_KNOWN_TREND         10                            // 10: known direction and duration of a ZigZag leg
#define MODE_UNKNOWN_TREND       11                            // 11: not yet known ZigZag direction and duration after the last High/Low

#property indicator_chart_window
#property indicator_buffers   8                                // visible buffers
int       terminal_buffers  = 8;                               // buffers managed by the terminal
int       framework_buffers = 4;                               // buffers managed by the framework

#property indicator_color1    DodgerBlue                       // the ZigZag line is built from two buffers using the color of the first buffer
#property indicator_width1    1                                //
#property indicator_color2    CLR_NONE                         //

#property indicator_color3    Blue                             // upper channel band
#property indicator_style3    STYLE_DOT                        //
#property indicator_color4    Magenta                          // lower channel band
#property indicator_style4    STYLE_DOT                        //

#property indicator_color5    indicator_color3                 // upper channel band crossings
#property indicator_width5    0                                //
#property indicator_color6    indicator_color4                 // lower channel band crossings
#property indicator_width6    0                                //

#property indicator_color7    CLR_NONE                         // offset of last ZigZag reversal to previous ZigZag semaphore
#property indicator_color8    CLR_NONE                         // trend (combined buffers MODE_KNOWN_TREND and MODE_UNKNOWN_TREND)

double   semaphoreOpen [];                                     // ZigZag semaphore open prices  (yields a vertical line segment if open != close)
double   semaphoreClose[];                                     // ZigZag semaphore close prices (yields a vertical line segment if open != close)
double   upperBand     [];                                     // upper channel band
double   lowerBand     [];                                     // lower channel band
double   upperCross    [];                                     // upper channel band crossings
double   lowerCross    [];                                     // lower channel band crossings
double   higherHigh    [];                                     // new High after an upper channel band crossing (potential new semaphore)
double   lowerLow      [];                                     // new Low after a lower channel band crossing (potential new semaphore)
double   reversal      [];                                     // offset of the previous reversal point to the preceeding ZigZag semaphore
int      knownTrend    [];                                     // known direction and duration of a ZigZag leg
int      unknownTrend  [];                                     // not yet known ZigZag direction and duration after the last High/Low
double   combinedTrend [];                                     // resulting trend (combined buffers MODE_KNOWN_TREND and MODE_UNKNOWN_TREND)

#define MODE_FIRST_CROSSING   1                                // crossing draw types
#define MODE_ALL_CROSSINGS    2

int      zigzagDrawType;
int      crossingDrawType;

double   sema1, sema2, sema3;                                  // last 3 semaphores for breakout tracking
double   lastLegHigh, lastLegLow;                              // leg high/low at the previous tick
double   lastUpperBand;
double   lastLowerBand;

string   indicatorName = "";
string   shortName     = "";
string   legendLabel   = "";
string   legendInfo    = "";                                   // additional chart legend info
string   labels[];                                             // chart object labels

bool     signal.onReversal.sound;
bool     signal.onReversal.alert;
bool     signal.onReversal.mail;
bool     signal.onReversal.sms;

bool     signal.onBreakout.sound;
bool     signal.onBreakout.alert;
bool     signal.onBreakout.mail;
bool     signal.onBreakout.sms;

datetime skipSignals;                                          // skip signals until the specified time to wait for possible data pumping
datetime lastTick;
int      lastSoundSignal;                                      // GetTickCount() value of the last audible signal

// signal direction types
#define D_LONG     TRADE_DIRECTION_LONG                        // 1
#define D_SHORT    TRADE_DIRECTION_SHORT                       // 2

// parameter stepper directions
#define STEP_UP    1
#define STEP_DOWN -1


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   // validate inputs
   string indicator = WindowExpertName();

   // ZigZag.Periods
   if (AutoConfiguration) ZigZag.Periods = GetConfigInt(indicator, "ZigZag.Periods", ZigZag.Periods);
   if (ZigZag.Periods < 2)                 return(catch("onInit(1)  invalid input parameter ZigZag.Periods: "+ ZigZag.Periods, ERR_INVALID_INPUT_PARAMETER));
   // ZigZag.Periods.Step
   if (AutoConfiguration) ZigZag.Periods.Step = GetConfigInt(indicator, "ZigZag.Periods.Step", ZigZag.Periods.Step);
   if (ZigZag.Periods.Step < 0)            return(catch("onInit(2)  invalid input parameter ZigZag.Periods.Step: "+ ZigZag.Periods.Step +" (must be >= 0)", ERR_INVALID_INPUT_PARAMETER));
   // ZigZag.Type
   string sValues[], sValue = ZigZag.Type;
   if (AutoConfiguration) sValue = GetConfigString(indicator, "ZigZag.Type", sValue);
   if (Explode(sValue, "*", sValues, 2) > 1) {
      int size = Explode(sValues[0], "|", sValues, NULL);
      sValue = sValues[size-1];
   }
   sValue = StrToLower(StrTrim(sValue));
   if      (StrStartsWith("lines",      sValue)) { zigzagDrawType = DRAW_ZIGZAG; ZigZag.Type = "Lines";       }
   else if (StrStartsWith("semaphores", sValue)) { zigzagDrawType = DRAW_ARROW;  ZigZag.Type = "Semaphores";  }
   else                                    return(catch("onInit(3)  invalid input parameter ZigZag.Type: "+ DoubleQuoteStr(sValue), ERR_INVALID_INPUT_PARAMETER));
   // ZigZag.Width
   if (AutoConfiguration) ZigZag.Width = GetConfigInt(indicator, "ZigZag.Width", ZigZag.Width);
   if (ZigZag.Width < 0)                   return(catch("onInit(4)  invalid input parameter ZigZag.Width: "+ ZigZag.Width, ERR_INVALID_INPUT_PARAMETER));
   // ZigZag.Semaphores.Wingdings
   if (AutoConfiguration) ZigZag.Semaphores.Wingdings = GetConfigInt(indicator, "ZigZag.Semaphores.Wingdings", ZigZag.Semaphores.Wingdings);
   if (ZigZag.Semaphores.Wingdings <  32)  return(catch("onInit(5)  invalid input parameter ZigZag.Semaphores.Wingdings: "+ ZigZag.Semaphores.Wingdings, ERR_INVALID_INPUT_PARAMETER));
   if (ZigZag.Semaphores.Wingdings > 255)  return(catch("onInit(6)  invalid input parameter ZigZag.Semaphores.Wingdings: "+ ZigZag.Semaphores.Wingdings, ERR_INVALID_INPUT_PARAMETER));
   // Donchian.ShowChannel
   if (AutoConfiguration) Donchian.ShowChannel = GetConfigBool(indicator, "Donchian.ShowChannel", Donchian.ShowChannel);
   // Donchian.ShowCrossings
   sValue = Donchian.ShowCrossings;
   if (AutoConfiguration) sValue = GetConfigString(indicator, "Donchian.ShowCrossings", sValue);
   if (Explode(sValue, "*", sValues, 2) > 1) {
      size = Explode(sValues[0], "|", sValues, NULL);
      sValue = sValues[size-1];
   }
   sValue = StrToLower(StrTrim(sValue));
   if      (StrStartsWith("off",   sValue)) { crossingDrawType = NULL;                Donchian.ShowCrossings = "off";   }
   else if (StrStartsWith("first", sValue)) { crossingDrawType = MODE_FIRST_CROSSING; Donchian.ShowCrossings = "first"; }
   else if (StrStartsWith("all",   sValue)) { crossingDrawType = MODE_ALL_CROSSINGS;  Donchian.ShowCrossings = "all";   }
   else                                    return(catch("onInit(7)  invalid input parameter Donchian.ShowCrossings: "+ DoubleQuoteStr(sValue), ERR_INVALID_INPUT_PARAMETER));
   // Donchian.Crossings.Width
   if (AutoConfiguration) Donchian.Crossings.Width = GetConfigInt(indicator, "Donchian.Crossings.Width", Donchian.Crossings.Width);
   if (Donchian.Crossings.Width < 0)       return(catch("onInit(8)  invalid input parameter Donchian.Crossings.Width: "+ Donchian.Crossings.Width, ERR_INVALID_INPUT_PARAMETER));
   // Donchian.Crossings.Wingdings
   if (AutoConfiguration) Donchian.Crossings.Wingdings = GetConfigInt(indicator, "Donchian.Crossings.Wingdings", Donchian.Crossings.Wingdings);
   if (Donchian.Crossings.Wingdings <  32) return(catch("onInit(9)  invalid input parameter Donchian.Crossings.Wingdings: "+ Donchian.Crossings.Wingdings, ERR_INVALID_INPUT_PARAMETER));
   if (Donchian.Crossings.Wingdings > 255) return(catch("onInit(10)  invalid input parameter Donchian.Crossings.Wingdings: "+ Donchian.Crossings.Wingdings, ERR_INVALID_INPUT_PARAMETER));
   // colors: after deserialization the terminal might turn CLR_NONE (0xFFFFFFFF) into Black (0xFF000000)
   if (AutoConfiguration) ZigZag.Color         = GetConfigColor(indicator, "ZigZag.Color",         ZigZag.Color);
   if (AutoConfiguration) Donchian.Upper.Color = GetConfigColor(indicator, "Donchian.Upper.Color", Donchian.Upper.Color);
   if (AutoConfiguration) Donchian.Lower.Color = GetConfigColor(indicator, "Donchian.Lower.Color", Donchian.Lower.Color);
   if (ZigZag.Color         == 0xFF000000) ZigZag.Color         = CLR_NONE;
   if (Donchian.Upper.Color == 0xFF000000) Donchian.Upper.Color = CLR_NONE;
   if (Donchian.Lower.Color == 0xFF000000) Donchian.Lower.Color = CLR_NONE;
   // ShowChartLegend
   if (AutoConfiguration) ShowChartLegend = GetConfigBool(indicator, "ShowChartLegend", ShowChartLegend);
   // MaxBarsBack
   if (AutoConfiguration) MaxBarsBack = GetConfigInt(indicator, "MaxBarsBack", MaxBarsBack);
   if (MaxBarsBack < -1)                   return(catch("onInit(12)  invalid input parameter MaxBarsBack: "+ MaxBarsBack, ERR_INVALID_INPUT_PARAMETER));
   if (MaxBarsBack == -1) MaxBarsBack = INT_MAX;

   // Signal.onReversal
   string signalId = "Signal.onReversal";
   legendInfo = "";
   ConfigureSignals(signalId, AutoConfiguration, Signal.onReversal);
   if (Signal.onReversal) {
      if (!ConfigureSignalTypes(signalId, Signal.onReversal.Types, AutoConfiguration, signal.onReversal.sound, signal.onReversal.alert, signal.onReversal.mail, signal.onReversal.sms)) {
         return(catch("onInit(13)  invalid input parameter Signal.onReversal.Types: "+ DoubleQuoteStr(Signal.onReversal.Types), ERR_INVALID_INPUT_PARAMETER));
      }
      Signal.onReversal = (signal.onReversal.sound || signal.onReversal.alert || signal.onReversal.mail || signal.onReversal.sms);
      if (Signal.onReversal) legendInfo = "("+ StrLeft(ifString(signal.onReversal.sound, "sound,", "") + ifString(signal.onReversal.alert, "alert,", "") + ifString(signal.onReversal.mail, "mail,", "") + ifString(signal.onReversal.sms, "sms,", ""), -1) +")";
   }
   // Signal.onBreakout
   signalId = "Signal.onBreakout";
   ConfigureSignals(signalId, AutoConfiguration, Signal.onBreakout);
   if (Signal.onBreakout) {
      if (!ConfigureSignalTypes(signalId, Signal.onBreakout.Types, AutoConfiguration, signal.onBreakout.sound, signal.onBreakout.alert, signal.onBreakout.mail, signal.onBreakout.sms)) {
         return(catch("onInit(14)  invalid input parameter Signal.onBreakout.Types: "+ DoubleQuoteStr(Signal.onBreakout.Types), ERR_INVALID_INPUT_PARAMETER));
      }
      Signal.onBreakout = (signal.onBreakout.sound || signal.onBreakout.alert || signal.onBreakout.mail || signal.onBreakout.sms);
   }
   // Signal.Sound.*
   if (AutoConfiguration) Signal.Sound.Up   = GetConfigString(indicator, "Signal.Sound.Up",   Signal.Sound.Up);
   if (AutoConfiguration) Signal.Sound.Down = GetConfigString(indicator, "Signal.Sound.Down", Signal.Sound.Down);
   // Sound.onChannelWidening
   if (AutoConfiguration) Sound.onChannelWidening = GetConfigBool(indicator, "Sound.onChannelWidening", Sound.onChannelWidening);
   if (AutoConfiguration) Sound.onNewChannelHigh  = GetConfigString(indicator, "Sound.onNewChannelHigh", Sound.onNewChannelHigh);
   if (AutoConfiguration) Sound.onNewChannelLow   = GetConfigString(indicator, "Sound.onNewChannelLow", Sound.onNewChannelLow);

   // reset global vars used by the various event handlers
   skipSignals     = 0;
   lastTick        = 0;
   lastSoundSignal = 0;

   // reset an active command handler
   if (__isChart && (ZigZag.Periods.Step)) {
      GetChartCommand("ParameterStepper", sValues);
   }

   // restore a stored runtime status
   RestoreStatus();

   // buffer management and display options
   SetIndicatorOptions();
   if (ShowChartLegend) legendLabel = CreateChartLegend();

   // Indicator events like reversals occur "on tick", not on "bar open" or "bar close". We need a chart ticker to prevent
   // invalid signals caused by ticks during data pumping.
   if (!__tickTimerId && !__isTesting) {
      int hWnd = __ExecutionContext[EC.chart];
      int millis = 2000;                                         // a virtual tick every 2 seconds
      __tickTimerId = SetupTickTimer(hWnd, millis, NULL);
      if (!__tickTimerId) return(catch("onInit(15)->SetupTickTimer() failed", ERR_RUNTIME_ERROR));
   }
   return(catch("onInit(16)"));
}


/**
 * Deinitialization
 *
 * @return int - error status
 */
int onDeinit() {
   StoreStatus();

   // release the chart ticker
   if (__tickTimerId > NULL) {
      int id = __tickTimerId; __tickTimerId = NULL;
      if (!ReleaseTickTimer(id)) return(catch("onDeinit(1)->ReleaseTickTimer(timerId="+ id +") failed", ERR_RUNTIME_ERROR));
   }
   return(catch("onDeinit(2)"));
}


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   // process incoming commands (may rewrite ValidBars/ChangedBars/ShiftedBars)
   if (__isChart) /*&&*/ if (ZigZag.Periods.Step != 0) {
      if (!HandleCommands("ParameterStepper")) return(last_error);
   }

   // framework: manage additional buffers
   ManageDoubleIndicatorBuffer(MODE_HIGHER_HIGH,   higherHigh  );
   ManageDoubleIndicatorBuffer(MODE_LOWER_LOW,     lowerLow    );
   ManageIntIndicatorBuffer   (MODE_KNOWN_TREND,   knownTrend  );
   ManageIntIndicatorBuffer   (MODE_UNKNOWN_TREND, unknownTrend);

   // reset buffers before performing a full recalculation
   if (!ValidBars) {
      ArrayInitialize(semaphoreOpen,  0);
      ArrayInitialize(semaphoreClose, 0);
      ArrayInitialize(upperBand,      0);
      ArrayInitialize(lowerBand,      0);
      ArrayInitialize(upperCross,     0);
      ArrayInitialize(lowerCross,     0);
      ArrayInitialize(higherHigh,     0);
      ArrayInitialize(lowerLow,       0);
      ArrayInitialize(reversal,      -1);
      ArrayInitialize(knownTrend,     0);
      ArrayInitialize(unknownTrend,   0);
      ArrayInitialize(combinedTrend,  0);
      lastUpperBand = 0;
      lastLowerBand = 0;
      lastLegHigh   = 0;
      lastLegLow    = 0;
      sema1         = 0;
      sema2         = 0;
      sema3         = 0;
      SetIndicatorOptions();
   }

   // synchronize buffers with a shifted offline chart
   if (ShiftedBars > 0) {
      ShiftDoubleIndicatorBuffer(semaphoreOpen,  Bars, ShiftedBars,  0);
      ShiftDoubleIndicatorBuffer(semaphoreClose, Bars, ShiftedBars,  0);
      ShiftDoubleIndicatorBuffer(upperBand,      Bars, ShiftedBars,  0);
      ShiftDoubleIndicatorBuffer(lowerBand,      Bars, ShiftedBars,  0);
      ShiftDoubleIndicatorBuffer(upperCross,     Bars, ShiftedBars,  0);
      ShiftDoubleIndicatorBuffer(lowerCross,     Bars, ShiftedBars,  0);
      ShiftDoubleIndicatorBuffer(higherHigh,     Bars, ShiftedBars,  0);
      ShiftDoubleIndicatorBuffer(lowerLow,       Bars, ShiftedBars,  0);
      ShiftDoubleIndicatorBuffer(reversal,       Bars, ShiftedBars, -1);
      ShiftIntIndicatorBuffer   (knownTrend,     Bars, ShiftedBars,  0);
      ShiftIntIndicatorBuffer   (unknownTrend,   Bars, ShiftedBars,  0);
      ShiftDoubleIndicatorBuffer(combinedTrend,  Bars, ShiftedBars,  0);
   }

   // check data pumping on every tick so the reversal handler can skip errornous signals
   if (!__isTesting) IsPossibleDataPumping();

   // calculate start bar
   int startbar = Min(MaxBarsBack-1, ChangedBars-1, Bars-ZigZag.Periods);
   if (startbar < 0 && MaxBarsBack) return(logInfo("onTick(1)  Tick="+ Ticks +"  Bars="+ Bars +"  needed="+ ZigZag.Periods, ERR_HISTORY_INSUFFICIENT));

   // recalculate changed bars
   if (startbar > 2) {
      semaphoreOpen [startbar] =  0;
      semaphoreClose[startbar] =  0;
      upperBand     [startbar] =  0;
      lowerBand     [startbar] =  0;
      upperCross    [startbar] =  0;
      lowerCross    [startbar] =  0;
      higherHigh    [startbar] =  0;
      lowerLow      [startbar] =  0;
      reversal      [startbar] = -1;
      knownTrend    [startbar] =  0;
      unknownTrend  [startbar] =  0;
      combinedTrend [startbar] =  0;
   }
   for (int bar=startbar; bar >= 0; bar--) {
      // recalculate Donchian channel
      if (bar == 0) {
         upperBand[bar] = MathMax(upperBand[1], High[0]);
         lowerBand[bar] = MathMin(lowerBand[1],  Low[0]);
      }
      else {
         upperBand[bar] = High[iHighest(NULL, NULL, MODE_HIGH, ZigZag.Periods, bar)];
         lowerBand[bar] =  Low[ iLowest(NULL, NULL, MODE_LOW,  ZigZag.Periods, bar)];
      }

      // recalculate channel crossings
      if (upperBand[bar] > upperBand[bar+1]) {
         upperCross[bar] = upperBand[bar+1]+Point;
         higherHigh[bar] = upperBand[bar];
      }
      if (lowerBand[bar] < lowerBand[bar+1]) {
         lowerCross[bar] = lowerBand[bar+1]-Point;
         lowerLow  [bar] = lowerBand[bar];
      }

      // recalculate ZigZag data
      // if no channel crossing
      if (!upperCross[bar] && !lowerCross[bar]) {
         reversal    [bar] = reversal    [bar+1];                 // keep reversal offset (may be -1)
         knownTrend  [bar] = knownTrend  [bar+1];                 // keep known trend
         unknownTrend[bar] = unknownTrend[bar+1] + 1;             // increase unknown trend
      }

      // if two channel crossings (upper and lower band crossed by the same bar)
      else if (upperCross[bar] && lowerCross[bar]) {
         if (IsUpperCrossLast(bar)) {
            if (!knownTrend[bar]) ProcessLowerCross(bar);         // if bar not yet processed then process both crossings in order,
            ProcessUpperCross(bar);                               // otherwise process only the last crossing
         }
         else {
            if (!knownTrend[bar]) ProcessUpperCross(bar);         // ...
            ProcessLowerCross(bar);                               // ...
         }
      }

      // if a single channel crossing
      else if (upperCross[bar] != 0) ProcessUpperCross(bar);
      else                           ProcessLowerCross(bar);

      // calculate combinedTrend[]
      combinedTrend[bar] = Sign(knownTrend[bar]) * unknownTrend[bar] * 100000 + knownTrend[bar];

      // hide non-configured crossings
      if (!crossingDrawType) {                                             // hide all crossings
         upperCross[bar] = 0;
         lowerCross[bar] = 0;
      }
      else if (crossingDrawType == MODE_FIRST_CROSSING) {                  // hide all crossings except the 1st
         bool isReversal = false;

         if (!unknownTrend[bar]) {
            int absTrend = MathAbs(knownTrend[bar]);
            if      (absTrend == reversal[bar])       isReversal = true;   // reversal offset is 0 if the reversal occurred
            else if (absTrend == 1 && !reversal[bar]) isReversal = true;   // on the same bar as the preceeding semaphore
         }

         if (isReversal) {
            if (reversal[bar+1] >= 0) {                                    // keep preceeding reversals on the same bar
               if (knownTrend[bar] > 0) lowerCross[bar] = 0;
               else                     upperCross[bar] = 0;
            }
         }
         else {
            upperCross[bar] = 0;
            lowerCross[bar] = 0;
         }
      }
   }

   if (__isChart && !__isSuperContext) {
      if (ShowChartLegend) UpdateChartLegend();

      if (ChangedBars > 2) {
         // resolve leg high/low
         int type = NULL;
         bar = FindPrevSemaphore(0, type);

         if (type == MODE_HIGH) {
            lastLegHigh = High[bar];
            lastLegLow = 0;
         }
         else {
            lastLegHigh = 0;
            lastLegLow = Low[bar];
         }

         // resolve the last 3 semaphores
         bar   = FindPrevSemaphore(bar, type);
         sema1 = ifDouble(type==MODE_HIGH, High[bar], Low[bar]);
         bar   = FindPrevSemaphore(bar, type);
         sema2 = ifDouble(type==MODE_HIGH, High[bar], Low[bar]);
         bar   = FindPrevSemaphore(bar, type);
         sema3 = ifDouble(type==MODE_HIGH, High[bar], Low[bar]);
      }
      else {
         // detect ZigZag breakouts (comparing legs against bands also detects breakouts on missed ticks)
         if (Signal.onBreakout && sema3) {
            if (knownTrend[0] > 0) {
               if (lastLegHigh < sema2+HalfPoint && upperBand[0] > sema2+HalfPoint) {
                  onBreakout(D_LONG);
               }
               lastLegHigh = High[unknownTrend[0]];                     // leg high for comparison at the nex tick
            }
            else if (knownTrend[0] < 0) {
               if ((!lastLegLow || lastLegLow > sema2-HalfPoint) && lowerBand[0] < sema2-HalfPoint) {
                  onBreakout(D_SHORT);
               }
               lastLegLow = Low[unknownTrend[0]];                       // leg low for comparison at the nex tick
            }
         }

         // detect Donchian channel widenings
         if (Sound.onChannelWidening) {
            if (ChangedBars == 2) {
               lastUpperBand = upperBand[1];
               lastLowerBand = lowerBand[1];
            }
            if (lastUpperBand && lastLowerBand) {
               if      (upperBand[0] > lastUpperBand+HalfPoint) onChannelWidening(D_LONG);
               else if (lowerBand[0] < lastLowerBand-HalfPoint) onChannelWidening(D_SHORT);
            }
            lastUpperBand = upperBand[0];
            lastLowerBand = lowerBand[0];
         }
      }
   }
   return(last_error);
}


/**
 * Whether a bar crossing both channel bands crossed the upper band first. The returned result is only a "best guess".
 *
 * @param  int bar - bar offset
 *
 * @return bool
 */
bool IsUpperCrossFirst(int bar) {
   static datetime lastBarTime;
   static double lastBarHigh, lastBarLow;
   static bool lastResult = -1;

   if (ChangedBars==1 && bar==0) {                       // to minimze "guessing" errors and have consistent results when
      if (Time[0]==lastBarTime && lastResult != -1) {    // a bar receives multiple ticks we cache the status of Bar[0]
         if (EQ(High[0], lastBarHigh)) {                 // TODO: also cache result for Bar[1]
            if (EQ(Low[0], lastBarLow)) {
               return(lastResult);
            }
         }
      }
   }

   double ho = High [bar] - Open [bar];
   double ol = Open [bar] - Low  [bar];
   double hc = High [bar] - Close[bar];
   double cl = Close[bar] - Low  [bar];

   double minOpen  = MathMin(ho, ol);
   double minClose = MathMin(hc, cl);

   if (minOpen < minClose) lastResult = (ho < ol);
   else                    lastResult = (hc > cl);

   lastBarTime = Time[bar];
   lastBarHigh = High[bar];
   lastBarLow  = Low [bar];

   return(lastResult);
}


/**
 * Whether a bar crossing both channel bands crossed the upper band last.  The returned result is only a "best guess".
 *
 * @param  int bar - bar offset
 *
 * @return bool
 */
bool IsUpperCrossLast(int bar) {
   double ho = High [bar] - Open [bar];
   double ol = Open [bar] - Low  [bar];
   double hc = High [bar] - Close[bar];
   double cl = Close[bar] - Low  [bar];

   double minOpen  = MathMin(ho, ol);
   double minClose = MathMin(hc, cl);

   if (minOpen < minClose)
      return(ho > ol);
   return(hc < cl);

   IsUpperCrossFirst(NULL);
}


/**
 * Find the chart offset of the ZigZag semaphore preceeding the specified semaphore. The found semaphore may be located at
 * the same bar.
 *
 * @param  _In_    int bar  - start bar
 * @param  _InOut_ int type - semaphore type, on of: MODE_HIGH|MODE_LOW|NULL
 *                             In:  type of semaphore to start searching from (NULL: any type)
 *                             Out: type of the found semaphore (MODE_HIGH|MODE_LOW)
 *
 * @return int - chart offset of the found semaphore or EMPTY (-1) in case of errors
 */
int FindPrevSemaphore(int bar, int &type) {
   if (bar < 0 || bar >= Bars)               return(_EMPTY(catch("FindPrevSemaphore(1)  invalid parameter bar: "+ bar +" (out of range)", ERR_INVALID_PARAMETER)));
   if (type != NULL) {
      if (type!=MODE_HIGH && type!=MODE_LOW) return(_EMPTY(catch("FindPrevSemaphore(2)  invalid parameter type: "+ type, ERR_INVALID_PARAMETER)));
   }

   if (!type || !semaphoreClose[bar]) {
      if (semaphoreClose[bar] != NULL) {                             // semaphore is located at the current bar
         int semBar = bar;
      }
      else {                                                         // semaphore is located somewhere before
         bar++;
         semBar = bar + unknownTrend[bar];                           // if unknown[bar] != 0 it points to the preceeding semaphore; if = 0 it doesn't change a thing
         if (!semaphoreClose[semBar]) {
            // a semaphore on a regular bar is located at:                                    bar + trend
            // a semaphore on a large bar (semaphore + reversal to other side) is located at: bar + trend - 1     // Abs(knownTrend[semBar]) = 1 = new trend
            int trend = Abs(knownTrend[bar]);
            semBar = bar + trend - 1;
            if (!semaphoreClose[semBar]) semBar++;
         }
      }
      if      (!lowerLow     [semBar])                                    type = MODE_HIGH;
      else if (!higherHigh   [semBar])                                    type = MODE_LOW;
      else if (semaphoreOpen [semBar] < semaphoreClose[semBar]-HalfPoint) type = MODE_HIGH;
      else if (semaphoreOpen [semBar] > semaphoreClose[semBar]+HalfPoint) type = MODE_LOW;
      else if (semaphoreClose[semBar] == higherHigh[semBar])              type = MODE_HIGH;  // semaphoreOpen == semaphoreClose
      else                                                                type = MODE_LOW;   // ...
      return(semBar);
   }

   if (semaphoreOpen[bar] == semaphoreClose[bar]) {
      bool isHigh = (semaphoreClose[bar] == higherHigh[bar]);

      if (type == MODE_HIGH) {
         if (isHigh) {
            type = NULL;
            return(FindPrevSemaphore(bar+1, type));
         }
         type = MODE_LOW;
      }
      else /*type == MODE_LOW*/ {
         if (!isHigh) {
            type = NULL;
            return(FindPrevSemaphore(bar+1, type));
         }
         type = MODE_HIGH;
      }
   }
   else {
      bool high2Low = (semaphoreOpen[bar] > semaphoreClose[bar]+HalfPoint);

      if (type == MODE_HIGH) {
         if (high2Low) {
            type = NULL;
            return(FindPrevSemaphore(bar+1, type));
         }
         type = MODE_LOW;
      }
      else /*type == MODE_LOW*/ {
         if (!high2Low) {
            type = NULL;
            return(FindPrevSemaphore(bar+1, type));
         }
         type = MODE_HIGH;
      }
   }
   return(bar);
}


/**
 * Update buffers after a SINGLE or DOUBLE upper band crossing at the specified bar offset. Resolves the preceeding ZigZag
 * semaphore and counts the trend forward from there.
 *
 * @param  int bar - offset
 *
 * @return bool - success status
 */
bool ProcessUpperCross(int bar) {
   int type, prevSem=FindPrevSemaphore(bar, type);                   // resolve the previous semaphore
   int prevTrend = knownTrend[prevSem];                              // trend at the previous semaphore

   if (prevTrend > 0) {
      if (prevSem == bar) {                                          // trend buffers are already set
         if (semaphoreOpen[bar] != lowerLow[bar]) {                  // update existing semaphore
            semaphoreOpen[bar] = higherHigh[bar];
         }
         semaphoreClose[bar] = higherHigh[bar];
      }
      else {
         if (higherHigh[bar] > higherHigh[prevSem]) {                // an uptrend continuation
            UpdateTrend(prevSem, prevTrend, bar, false);             // update existing trend
            if (semaphoreOpen[prevSem] == semaphoreClose[prevSem]) {
               semaphoreOpen [prevSem] = 0;                          // reset previous semaphore
            }
            semaphoreClose[prevSem] = semaphoreOpen[prevSem];
            semaphoreOpen [bar]     = higherHigh[bar];               // set new semaphore
            semaphoreClose[bar]     = higherHigh[bar];
         }
         else {                                                      // a lower High (unknown direction)
            knownTrend  [bar] = knownTrend  [bar+1];                 // keep known trend
            unknownTrend[bar] = unknownTrend[bar+1] + 1;             // increase unknown trend
         }
         reversal[bar] = reversal[bar+1];                            // keep reversal offset
      }
   }
   else {                                                            // a reversal from "short" to "long" (new uptrend)
      if (prevSem == bar) {
         UpdateTrend(prevSem, 1, bar, false);                        // flip trend on same bar, keep semaphoreOpen[]
      }
      else {
         UpdateTrend(prevSem-1, 1, bar, true);                       // set the new trend range, reset reversals
         semaphoreOpen[bar] = higherHigh[bar];                       // set new semaphore
      }
      semaphoreClose[bar] = higherHigh[bar];
      reversal      [bar] = prevSem-bar;                             // set new reversal offset

      sema3 = sema2;                                                 // update the last 3 semaphores
      sema2 = sema1;
      sema1 = Low[prevSem];
      lastLegHigh = 0;                                               // reset last leg high
      if (Signal.onReversal && __isChart && ChangedBars <= 2) onReversal(D_LONG);
   }
   return(true);
}


/**
 * Update buffers after a SINGLE or DOUBLE lower band crossing at the specified bar offset. Resolves the preceeding ZigZag
 * semaphore and counts the trend forward from there.
 *
 * @param  int bar - offset
 *
 * @return bool - success status
 */
bool ProcessLowerCross(int bar) {
   int type, prevSem=FindPrevSemaphore(bar, type);                   // resolve the previous semaphore
   int prevTrend = knownTrend[prevSem];                              // trend at the previous semaphore

   if (prevTrend < 0) {
      if (prevSem == bar) {                                          // trend buffers are already set
         if (semaphoreOpen[bar] != higherHigh[bar]) {                // update existing semaphore
            semaphoreOpen [bar] = lowerLow[bar];
         }
         semaphoreClose[bar] = lowerLow[bar];
      }
      else {
         if (lowerLow[bar] < lowerLow[prevSem]) {                    // a downtrend continuation
            UpdateTrend(prevSem, prevTrend, bar, false);             // update existing trend
            if (semaphoreOpen[prevSem] == semaphoreClose[prevSem]) {
               semaphoreOpen [prevSem] = 0;                          // reset previous semaphore
            }
            semaphoreClose[prevSem] = semaphoreOpen[prevSem];
            semaphoreOpen [bar]     = lowerLow[bar];                 // set new semaphore
            semaphoreClose[bar]     = lowerLow[bar];
         }
         else {                                                      // a higher Low (unknown direction)
            knownTrend  [bar] = knownTrend  [bar+1];                 // keep known trend
            unknownTrend[bar] = unknownTrend[bar+1] + 1;             // increase unknown trend
         }
         reversal[bar] = reversal[bar+1];                            // keep reversal offset
      }
   }
   else {                                                            // a reversal from "long" to "short" (new downtrend)
      if (prevSem == bar) {
         UpdateTrend(prevSem, -1, bar, false);                       // flip trend on same bar, keep semaphoreOpen[]
      }
      else {
         UpdateTrend(prevSem-1, -1, bar, true);                      // set the new trend, reset reversals
         semaphoreOpen[bar] = lowerLow[bar];                         // set new semaphore
      }
      semaphoreClose[bar] = lowerLow[bar];
      reversal      [bar] = prevSem-bar;                             // set the new reversal offset

      sema3 = sema2;                                                 // update the last 3 semaphores
      sema2 = sema1;
      sema1 = High[prevSem];
      lastLegLow = 0;                                                // reset last leg low

      if (Signal.onReversal && __isChart && ChangedBars <= 2) onReversal(D_SHORT);
   }
   return(true);
}


/**
 * Update/count forward the 'knownTrend' and 'unknownTrend' counter of the specified bar range.
 *
 * @param  int  fromBar       - start bar of the range to update
 * @param  int  fromValue     - start value for the trend counter
 * @param  int  toBar         - end bar of the range to update
 * @param  bool resetReversal - whether to reset the reversal buffer of the bar range
 */
void UpdateTrend(int fromBar, int fromValue, int toBar, bool resetReversalBuffer) {
   resetReversalBuffer = resetReversalBuffer!=0;
   int value = fromValue;

   for (int i=fromBar; i >= toBar; i--) {
      knownTrend   [i] = value;
      unknownTrend [i] = 0;
      combinedTrend[i] = Sign(knownTrend[i]) * unknownTrend[i] * 100000 + knownTrend[i];

      if (resetReversalBuffer) reversal[i] = -1;

      if (value > 0) value++;
      else           value--;
   }
}


/**
 * Event handler signaling new ZigZag reversals. Prevents duplicate signals triggered by multiple running instances.
 *
 * @param  int direction - reversal direction: D_LONG | D_SHORT
 *
 * @return bool - success status
 */
bool onReversal(int direction) {
   if (direction!=D_LONG && direction!=D_SHORT) return(!catch("onReversal(1)  invalid parameter direction: "+ direction, ERR_INVALID_PARAMETER));
   if (!__isChart)                              return(true);
   if (IsPossibleDataPumping())                 return(true);        // skip signals during possible data pumping

   // skip the signal if it already was signaled before
   int hWnd = ifInt(__isTesting, __ExecutionContext[EC.chart], GetDesktopWindow());
   string sPeriod = PeriodDescription();
   string sEvent  = "rsf::"+ StdSymbol() +","+ sPeriod +"."+ indicatorName +"(P="+ ZigZag.Periods +").onReversal("+ direction +")."+ TimeToStr(Time[0]);
   if (GetPropA(hWnd, sEvent) != 0) return(true);
   SetPropA(hWnd, sEvent, 1);                                        // immediately mark as signaled (prevents duplicate signals with slow CPU)

   string message = ifString(direction==D_LONG, "up", "down") +" (bid: "+ NumberToStr(_Bid, PriceFormat) +")", accountTime="";
   if (IsLogInfo()) logInfo("onReversal(P="+ ZigZag.Periods +")  "+ message);

   if (signal.onReversal.sound) {
      int error = PlaySoundEx(ifString(direction==D_LONG, Signal.Sound.Up, Signal.Sound.Down));
      if (!error) lastSoundSignal = GetTickCount();
   }

   message = Symbol() +","+ PeriodDescription() +": "+ WindowExpertName() +"("+ ZigZag.Periods +") reversal "+ message;
   if (signal.onReversal.mail || signal.onReversal.sms) accountTime = "("+ TimeToStr(TimeLocalEx("onReversal(2)"), TIME_MINUTES|TIME_SECONDS) +", "+ GetAccountAlias() +")";

   if (signal.onReversal.alert) Alert(message);
   if (signal.onReversal.mail)  SendEmail("", "", message, message + NL + accountTime);
   if (signal.onReversal.sms)   SendSMS("", message + NL + accountTime);
   return(!catch("onReversal(3)"));
}


/**
 * Event handler signaling new ZigZag breakouts.
 *
 * @param  int direction - breakout direction: D_LONG | D_SHORT
 *
 * @return bool - success status
 */
bool onBreakout(int direction) {
   if (direction!=D_LONG && direction!=D_SHORT) return(!catch("onBreakout(1)  invalid parameter direction: "+ direction, ERR_INVALID_PARAMETER));
   if (!__isChart)                              return(true);
   if (IsPossibleDataPumping())                 return(true);        // skip signals during possible data pumping

   // skip the signal if it already has been signaled elsewhere
   int hWnd = ifInt(__isTesting, __ExecutionContext[EC.chart], GetDesktopWindow());
   string sPeriod = PeriodDescription();
   string sEvent  = "rsf::"+ StdSymbol() +","+ sPeriod +"."+ indicatorName +"(P="+ ZigZag.Periods +").onBreakout("+ direction +")."+ TimeToStr(Time[0]);
   if (GetPropA(hWnd, sEvent) != 0) return(true);
   SetPropA(hWnd, sEvent, 1);                                        // immediately mark as signaled (prevents duplicate signals on slow CPU)

   string sDirection = ifString(direction==D_LONG, "long", "short");
   string sBid       = NumberToStr(_Bid, PriceFormat);
   if (IsLogInfo()) logInfo("onBreakout(P="+ ZigZag.Periods +")  "+ sDirection +" (bid: "+ sBid +")");

   if (signal.onBreakout.sound) {
      int error = PlaySoundEx(ifString(direction==D_LONG, Signal.Sound.Up, Signal.Sound.Down));
      if (!error) lastSoundSignal = GetTickCount();
   }

   string message = Symbol() +","+ PeriodDescription() +": "+ WindowExpertName() +"("+ ZigZag.Periods +") breakout "+ sDirection +" (bid: "+ sBid +")";
   string sAccount = "";
   if (signal.onReversal.mail || signal.onReversal.sms) sAccount = "("+ TimeToStr(TimeLocalEx("onBreakout(2)"), TIME_MINUTES|TIME_SECONDS) +", "+ GetAccountAlias() +")";

   if (signal.onBreakout.alert) Alert(message);
   if (signal.onBreakout.mail)  SendEmail("", "", message, message + NL + sAccount);
   if (signal.onBreakout.sms)   SendSMS("", message + NL + sAccount);
   return(!catch("onBreakout(3)"));
}


/**
 * Event handler signaling Donchian channel widenings.
 *
 * @param  int direction - crossing direction: D_LONG | D_SHORT
 *
 * @return bool - success status
 */
bool onChannelWidening(int direction) {
   if (direction!=D_LONG && direction!=D_SHORT) return(!catch("onChannelWidening(1)  invalid parameter direction: "+ direction, ERR_INVALID_PARAMETER));

   // TODO: skip the signal if it already has been signaled elsewhere

   if (lastSoundSignal+2000 < GetTickCount()) {                      // at least 2 sec pause between consecutive sound signals
      int error = PlaySoundEx(ifString(direction==D_LONG, Sound.onNewChannelHigh, Sound.onNewChannelLow));
      if (!error) lastSoundSignal = GetTickCount();
   }
   return(!catch("onChannelWidening(2)"));
}


/**
 * Process an incoming command.
 *
 * @param  string cmd    - command name
 * @param  string params - command parameters
 * @param  int    keys   - combination of pressed modifier keys
 *
 * @return bool - success status of the executed command
 */
bool onCommand(string cmd, string params, int keys) {
   if (cmd == "parameter") {
      if (params == "up")   return(ParameterStepper(STEP_UP, keys));
      if (params == "down") return(ParameterStepper(STEP_DOWN, keys));
   }
   return(!logNotice("onCommand(1)  unsupported command: "+ DoubleQuoteStr(cmd +":"+ params +":"+ keys)));
}


/**
 * Step up/down input parameter "ZigZag.Periods".
 *
 * @param  int direction - STEP_UP | STEP_DOWN
 * @param  int keys      - modifier keys
 *
 * @return bool - success status
 */
bool ParameterStepper(int direction, int keys) {
   if (direction!=STEP_UP && direction!=STEP_DOWN) return(!catch("ParameterStepper(1)  invalid parameter direction: "+ direction, ERR_INVALID_PARAMETER));

   int step = ZigZag.Periods.Step;
   if (!step || ZigZag.Periods + direction*step < 2) {      // stop if parameter limit reached
      PlaySoundEx("Plonk.wav");
      return(false);
   }
   if (direction == STEP_UP) ZigZag.Periods += step;
   else                      ZigZag.Periods -= step;
   ChangedBars = Bars;
   ValidBars   = 0;
   PlaySoundEx("Parameter Step.wav");
   return(true);
}


/**
 * Whether the current tick may have occurred during data pumping.
 *
 * @return bool
 */
bool IsPossibleDataPumping() {
   if (__isTesting) return(false);

   int waitPeriod = 20*SECONDS;
   datetime now = GetGmtTime();
   bool pumping = true;

   if (now > skipSignals) skipSignals = 0;
   if (!skipSignals) {
      if (now > lastTick + waitPeriod) skipSignals = now + waitPeriod;
      else                             pumping = false;
   }
   lastTick = now;
   return(pumping);
}


/**
 * Update the chart legend.
 */
void UpdateChartLegend() {
   static int lastTrend, lastTime, lastAccount;

   // update on full recalculation or if indicator name, trend, current bar or the account changed
   if (!ValidBars || combinedTrend[0]!=lastTrend || Time[0]!=lastTime || AccountNumber()!=lastAccount) {
      string sKnown    = "   "+ NumberToStr(knownTrend[0], "+.");
      string sUnknown  = ifString(!unknownTrend[0], "", "/"+ unknownTrend[0]);
      string sReversal = "   next reversal @" + NumberToStr(ifDouble(knownTrend[0] < 0, upperBand[0]+Point, lowerBand[0]-Point), PriceFormat);
      string sSignal   = ifString(Signal.onReversal, "  "+ legendInfo, ""), sInfo="";
      if (Sound.onChannelWidening) sInfo = " (s)";
      string text      = StringConcatenate(indicatorName, sKnown, sUnknown, sReversal, sSignal, sInfo);

      color clr = ZigZag.Color;
      if      (clr == Aqua        ) clr = DodgerBlue;
      else if (clr == Gold        ) clr = Orange;
      else if (clr == LightSkyBlue) clr = C'94,174,255';
      else if (clr == Lime        ) clr = LimeGreen;
      else if (clr == Yellow      ) clr = Orange;

      ObjectSetText(legendLabel, text, 9, "Arial Fett", clr);
      int error = GetLastError();
      if (error && error!=ERR_OBJECT_DOES_NOT_EXIST) catch("UpdateChartLegend(1)", error);     // on ObjectDrag or opened "Properties" dialog

      lastTrend   = combinedTrend[0];
      lastTime    = Time[0];
      lastAccount = AccountNumber();
   }
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

   string name   = ProgramName(), donchianName="";
   indicatorName = name +"("+ ifString(ZigZag.Periods.Step, "step:", "") + ZigZag.Periods +")";
   shortName     = name +"("+ ZigZag.Periods +")";
   donchianName  = "Donchian("+ ZigZag.Periods +")";
   IndicatorShortName(shortName);

   IndicatorBuffers(terminal_buffers);
   SetIndexBuffer(MODE_SEMAPHORE_OPEN,  semaphoreOpen ); SetIndexEmptyValue(MODE_SEMAPHORE_OPEN,  0); SetIndexLabel(MODE_SEMAPHORE_OPEN,  NULL);
   SetIndexBuffer(MODE_SEMAPHORE_CLOSE, semaphoreClose); SetIndexEmptyValue(MODE_SEMAPHORE_CLOSE, 0); SetIndexLabel(MODE_SEMAPHORE_CLOSE, NULL);
   SetIndexBuffer(MODE_UPPER_BAND,      upperBand     ); SetIndexEmptyValue(MODE_UPPER_BAND,      0); SetIndexLabel(MODE_UPPER_BAND,      donchianName +" upper band"); if (!Donchian.ShowChannel) SetIndexLabel(MODE_UPPER_BAND,  NULL);
   SetIndexBuffer(MODE_LOWER_BAND,      lowerBand     ); SetIndexEmptyValue(MODE_LOWER_BAND,      0); SetIndexLabel(MODE_LOWER_BAND,      donchianName +" lower band"); if (!Donchian.ShowChannel) SetIndexLabel(MODE_LOWER_BAND,  NULL);
   SetIndexBuffer(MODE_UPPER_CROSS,     upperCross    ); SetIndexEmptyValue(MODE_UPPER_CROSS,     0); SetIndexLabel(MODE_UPPER_CROSS,     shortName +" cross up");      if (!crossingDrawType)     SetIndexLabel(MODE_UPPER_CROSS, NULL);
   SetIndexBuffer(MODE_LOWER_CROSS,     lowerCross    ); SetIndexEmptyValue(MODE_LOWER_CROSS,     0); SetIndexLabel(MODE_LOWER_CROSS,     shortName +" cross down");    if (!crossingDrawType)     SetIndexLabel(MODE_LOWER_CROSS, NULL);
   SetIndexBuffer(MODE_REVERSAL,        reversal      ); SetIndexEmptyValue(MODE_REVERSAL,       -1); SetIndexLabel(MODE_REVERSAL,        shortName +" reversal");
   SetIndexBuffer(MODE_COMBINED_TREND,  combinedTrend ); SetIndexEmptyValue(MODE_COMBINED_TREND,  0); SetIndexLabel(MODE_COMBINED_TREND,  shortName +" trend");
   IndicatorDigits(Digits);

   int drawType  = ifInt(ZigZag.Width, zigzagDrawType, DRAW_NONE);
   int drawWidth = ifInt(zigzagDrawType==DRAW_ZIGZAG, ZigZag.Width, ZigZag.Width-1);
   SetIndexStyle(MODE_SEMAPHORE_OPEN,  drawType, EMPTY, drawWidth, ZigZag.Color); SetIndexArrow(MODE_SEMAPHORE_OPEN,  ZigZag.Semaphores.Wingdings);
   SetIndexStyle(MODE_SEMAPHORE_CLOSE, drawType, EMPTY, drawWidth, ZigZag.Color); SetIndexArrow(MODE_SEMAPHORE_CLOSE, ZigZag.Semaphores.Wingdings);

   drawType = ifInt(Donchian.ShowChannel, DRAW_LINE, DRAW_NONE);
   SetIndexStyle(MODE_UPPER_BAND, drawType, EMPTY, EMPTY, Donchian.Upper.Color);
   SetIndexStyle(MODE_LOWER_BAND, drawType, EMPTY, EMPTY, Donchian.Lower.Color);

   drawType  = ifInt(crossingDrawType && Donchian.Crossings.Width, DRAW_ARROW, DRAW_NONE);
   drawWidth = Donchian.Crossings.Width-1;                     // minus 1 to use the same scale as ZigZag.Semaphore.Width
   SetIndexStyle(MODE_UPPER_CROSS, drawType, EMPTY, drawWidth, Donchian.Upper.Color); SetIndexArrow(MODE_UPPER_CROSS, Donchian.Crossings.Wingdings);
   SetIndexStyle(MODE_LOWER_CROSS, drawType, EMPTY, drawWidth, Donchian.Lower.Color); SetIndexArrow(MODE_LOWER_CROSS, Donchian.Crossings.Wingdings);

   SetIndexStyle(MODE_REVERSAL,       DRAW_NONE);
   SetIndexStyle(MODE_COMBINED_TREND, DRAW_NONE);

   if (redraw) WindowRedraw();
   return(!catch("SetIndicatorOptions(1)"));
}


/**
 * Store the status of an active parameter stepper in the chart (for init cyles, template reloads and/or terminal restarts).
 *
 * @return bool - success status
 */
bool StoreStatus() {
   if (__isChart && ZigZag.Periods.Step) {
      string prefix = "rsf."+ WindowExpertName() +".";
      Chart.StoreInt(prefix +"ZigZag.Periods", ZigZag.Periods);
   }
   return(catch("StoreStatus(1)"));
}


/**
 * Restore the status of the parameter stepper from the chart if it wasn't changed in between (for init cyles, template
 * reloads and/or terminal restarts).
 *
 * @return bool - success status
 */
bool RestoreStatus() {
   if (__isChart) {
      string prefix = "rsf."+ WindowExpertName() +".";
      int iValue;
      if (Chart.RestoreInt(prefix +"ZigZag.Periods", iValue)) {
         if (ZigZag.Periods.Step > 0) {
            if (iValue >= 2) ZigZag.Periods = iValue;          // silent validation
         }
      }
   }
   return(!catch("RestoreStatus(1)"));
}


/**
 * Return a string representation of the input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("ZigZag.Periods=",               ZigZag.Periods                          +";"+ NL,
                            "ZigZag.Periods.Step=",          ZigZag.Periods.Step                     +";"+ NL,
                            "ZigZag.Type=",                  DoubleQuoteStr(ZigZag.Type)             +";"+ NL,
                            "ZigZag.Width=",                 ZigZag.Width                            +";"+ NL,
                            "ZigZag.Semaphores.Wingdings=",  ZigZag.Semaphores.Wingdings             +";"+ NL,
                            "ZigZag.Color=",                 ColorToStr(ZigZag.Color)                +";"+ NL,

                            "Donchian.ShowChannel=",         BoolToStr(Donchian.ShowChannel)         +";"+ NL,
                            "Donchian.ShowCrossings=",       DoubleQuoteStr(Donchian.ShowCrossings)  +";"+ NL,
                            "Donchian.Crossings.Width=",     Donchian.Crossings.Width                +";"+ NL,
                            "Donchian.Crossings.Wingdings=", Donchian.Crossings.Wingdings            +";"+ NL,
                            "Donchian.Upper.Color=",         ColorToStr(Donchian.Upper.Color)        +";"+ NL,
                            "Donchian.Lower.Color=",         ColorToStr(Donchian.Lower.Color)        +";"+ NL,

                            "ShowChartLegend=",              BoolToStr(ShowChartLegend)              +";"+ NL,
                            "MaxBarsBack=",                  MaxBarsBack                             +";"+ NL,

                            "Signal.onReversal=",            BoolToStr(Signal.onReversal)            +";"+ NL,
                            "Signal.onReversal.Types=",      DoubleQuoteStr(Signal.onReversal.Types) +";"+ NL,
                            "Signal.onBreakout=",            BoolToStr(Signal.onBreakout)            +";"+ NL,
                            "Signal.onBreakout.Types=",      DoubleQuoteStr(Signal.onBreakout.Types) +";"+ NL,
                            "Signal.Sound.Up=",              DoubleQuoteStr(Signal.Sound.Up)         +";"+ NL,
                            "Signal.Sound.Down=",            DoubleQuoteStr(Signal.Sound.Down)       +";"+ NL,

                            "Sound.onChannelWidening=",      BoolToStr(Sound.onChannelWidening)      +";"+ NL,
                            "Sound.onNewChannelHigh=",       DoubleQuoteStr(Sound.onNewChannelHigh)  +";"+ NL,
                            "Sound.onNewChannelLow=",        DoubleQuoteStr(Sound.onNewChannelLow)   +";")
   );

   // suppress compiler warnings
   icZigZag(NULL, NULL, NULL, NULL);
}
