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
 * For the signaled ZigZag 1-2-3 pattern see https://www.forexfactory.com/thread/210023-123-pattern-ea#
 *
 *
 * Input parameters
 * ----------------
 *  � ZigZag.Periods:               Lookback periods of the Donchian channel.
 *  � ZigZag.Periods.Step:          Controls parameter 'ZigZag.Periods' via the keyboard. If non-zero it enables the parameter
 *                                   stepper and defines its step size. If zero the parameter stepper is disabled.
 *  � ZigZag.Type:                  Whether to display the ZigZag line or ZigZag semaphores. Can be shortened as long as distinct.
 *  � ZigZag.Width:                 The ZigZag's line width/semaphore size.
 *  � ZigZag.Semaphores.Wingdings:  WingDing symbol used for ZigZag semaphores.
 *  � ZigZag.Color:                 Color of ZigZag line/semaphores.
 *
 *  � Donchian.ShowChannel:         Whether to display the internal Donchian channel.
 *  � Donchian.ShowCrossings:       Which Donchian channel crossings to display, one of:
 *                                   "off":   No crossings are displayed.
 *                                   "first": Only the first crossing per direction is displayed (the moment when ZigZag creates a new leg).
 *                                   "all":   All crossings are displayed. Displays the trail of a ZigZag leg as it develops over time.
 *  � Donchian.Crossings.Width:     Size of displayed Donchian channel crossings.
 *  � Donchian.Crossings.Wingdings: WingDing symbol used for Donchian channel crossings.
 *  � Donchian.Upper.Color:         Color of upper Donchian channel band/upper crossings.
 *  � Donchian.Lower.Color:         Color of lower Donchian channel band/lower crossings.
 *
 *  � MaxBarsBack:                  Maximum number of bars back to calculate the indicator (performance).
 *  � ShowChartLegend:              Whether do display the chart legend.
 *
 *  � Signal.onReversal:            Whether to signal ZigZag reversals (the moment when ZigZag creates a new leg).
 *  � Signal.onReversal.Types:      Reversal signaling methods, can be a combination of "sound", "alert", "mail", "sms".
 *
 *  � Signal.onBreakout:            Whether to signal ZigZag breakouts (price exceeding the previous swing's ZigZag semaphore).
 *  � Signal.onBreakout.123Only:    Whether to signal valid 1-2-3 pattern breakouts only.
 *  � Signal.onBreakout.Types:      Breakout signaling methods, can be a combination of "sound", "alert", "mail", "sms".
 *
 *  � Signal.Sound.Up:              Sound file to use for signal type "sound".
 *  � Signal.Sound.Down:            Sound file to use for signal type "sound".
 *
 *  � Sound.onChannelWidening:      Whether to play a sound on Donchian channel widenings (channel crossings).
 *  � Sound.onNewChannelHigh:       Sound file to use for Donchian channel widenings to the upside.
 *  � Sound.onNewChannelLow:        Sound file to use for Donchian channel widenings to the downside.
 *
 *  � AutoConfiguration:            If enabled all input parameters can be overwritten with custom default values.
 *
 *
 *
 * TODO:
 *  - fix triple-crossing at GBPJPY,M5 2023.12.18 00:00, ZigZag(20)
 *  - keep bar status in IsUpperCrossLast()
 *  - document usage of iCustom()
 */
#include <stddefines.mqh>
int   __InitFlags[];
int __DeinitFlags[];

///////////////////////////////////////////////////// Input parameters //////////////////////////////////////////////////////

extern string ___a__________________________ = "=== ZigZag settings ===";
extern int    ZigZag.Periods                 = 40;                      // lookback periods of the Donchian channel
extern int    ZigZag.Periods.Step            = 0;                       // step size for a stepped input parameter (hotkey)
extern string ZigZag.Type                    = "Lines | Semaphores*";   // ZigZag lines or reversal points (may be shortened)
extern int    ZigZag.Width                   = 2;
extern int    ZigZag.Semaphores.Wingdings    = 108;                     // a large point
extern color  ZigZag.Color                   = Blue;

extern string ___b__________________________ = "=== Donchian settings ===";
extern bool   Donchian.ShowChannel           = true;                    // whether to display the Donchian channel
extern string Donchian.ShowCrossings         = "off | first* | all";    // which channel crossings to display
extern int    Donchian.Crossings.Width       = 1;
extern int    Donchian.Crossings.Wingdings   = 163;                     // a circle
extern color  Donchian.Upper.Color           = Blue;
extern color  Donchian.Lower.Color           = Magenta;
extern int    MaxBarsBack                    = 10000;                   // max. values to calculate (-1: all available)
extern bool   ShowChartLegend                = true;

extern string ___c__________________________ = "=== Signal settings ===";
extern bool   Signal.onReversal              = false;                   // signal ZigZag reversals (first Donchian channel crossing)
extern string Signal.onReversal.Types        = "sound* | alert | mail | sms";

extern bool   Signal.onBreakout              = false;                   // signal ZigZag breakouts
extern bool   Signal.onBreakout.123Only      = false;                   // signal valid 1-2-3 breakouts only
extern string Signal.onBreakout.Types        = "sound* | alert | mail | sms";

extern string Signal.Sound.Up                = "Signal Up.wav";
extern string Signal.Sound.Down              = "Signal Down.wav";

extern string ___d__________________________ = "=== Other ===";
extern bool   Sound.onChannelWidening        = false;                   // signal Donchian channel widenings
extern string Sound.onNewChannelHigh         = "Price Advance.wav";
extern string Sound.onNewChannelLow          = "Price Decline.wav";

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <rsfLib.mqh>
#include <functions/chartlegend.mqh>
#include <functions/ConfigureSignals.mqh>
#include <functions/HandleCommands.mqh>
#include <functions/ManageDoubleIndicatorBuffer.mqh>
#include <functions/ManageIntIndicatorBuffer.mqh>
#include <functions/iCustom/ZigZag.mqh>
#include <win32api.mqh>

// indicator buffer ids
#define MODE_SEMAPHORE_OPEN      ZigZag.MODE_SEMAPHORE_OPEN    //  0: semaphore open price
#define MODE_SEMAPHORE_CLOSE     ZigZag.MODE_SEMAPHORE_CLOSE   //  1: semaphore close price
#define MODE_UPPER_BAND          ZigZag.MODE_UPPER_BAND        //  2: upper channel band
#define MODE_LOWER_BAND          ZigZag.MODE_LOWER_BAND        //  3: lower channel band
#define MODE_UPPER_CROSS         ZigZag.MODE_UPPER_CROSS       //  4: upper channel crossings
#define MODE_LOWER_CROSS         ZigZag.MODE_LOWER_CROSS       //  5: lower channel crossings
#define MODE_REVERSAL            ZigZag.MODE_REVERSAL          //  6: offset of last ZigZag reversal to previous ZigZag semaphore
#define MODE_COMBINED_TREND      ZigZag.MODE_TREND             //  7: trend (combined buffers MODE_KNOWN_TREND and MODE_UNKNOWN_TREND)
#define MODE_UPPER_CROSS_HIGH    8                             //  8: new High after an upper channel crossing (potential new semaphore)
#define MODE_LOWER_CROSS_LOW     9                             //  9: new Low after a lower channel crossing (potential new semaphore)
#define MODE_KNOWN_TREND         10                            // 10: known trend
#define MODE_UNKNOWN_TREND       11                            // 11: not yet known trend

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

#property indicator_color5    indicator_color3                 // upper channel crossings
#property indicator_width5    0                                //
#property indicator_color6    indicator_color4                 // lower channel crossings
#property indicator_width6    0                                //

#property indicator_color7    CLR_NONE                         // offset of last ZigZag reversal to previous ZigZag semaphore
#property indicator_color8    CLR_NONE                         // trend (combined buffers MODE_KNOWN_TREND and MODE_UNKNOWN_TREND)

double   semaphoreOpen [];                                     // ZigZag semaphore open price (a vertical line if open != close)
double   semaphoreClose[];                                     // ZigZag semaphore close price (a vertical line if open != close)
double   upperBand     [];                                     // upper channel band
double   lowerBand     [];                                     // lower channel band
double   upperCross    [];                                     // upper channel crossings
double   lowerCross    [];                                     // lower channel crossings
double   upperCrossHigh[];                                     // new High after an upper channel crossing (potential new semaphore)
double   lowerCrossLow [];                                     // new Low after a lower channel crossing (potential new semaphore)
double   reversal      [];                                     // offset of last ZigZag reversal to previous ZigZag semaphore
int      knownTrend    [];                                     // known direction and length of a ZigZag reversal
int      unknownTrend  [];                                     // not yet known direction and length after a ZigZag reversal
double   combinedTrend [];                                     // trend (combined buffers MODE_KNOWN_TREND and MODE_UNKNOWN_TREND)

#define MODE_FIRST_CROSSING   1                                // crossing draw types
#define MODE_ALL_CROSSINGS    2

int      zigzagDrawType;
int      crossingDrawType;

double   prevBid;
double   prevUpperBand;
double   prevLowerBand;
double   sema1, sema2, sema3;                                  // last 3 semaphores for breakout tracking

string   indicatorName = "";
string   shortName     = "";
string   legendLabel   = "";
string   legendInfo    = "";                                   // additional chart legend info

bool     signal.onReversal.sound;
bool     signal.onReversal.alert;
bool     signal.onReversal.mail;
bool     signal.onReversal.sms;

bool     signal.onBreakout.sound;
bool     signal.onBreakout.alert;
bool     signal.onBreakout.mail;
bool     signal.onBreakout.sms;

datetime skipSignals;                                          // skip signals until this time to wait for possible data pumping
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
   string indicator = WindowExpertName();

   // validate inputs
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
   // MaxBarsBack
   if (AutoConfiguration) MaxBarsBack = GetConfigInt(indicator, "MaxBarsBack", MaxBarsBack);
   if (MaxBarsBack < -1)                   return(catch("onInit(11)  invalid input parameter MaxBarsBack: "+ MaxBarsBack, ERR_INVALID_INPUT_PARAMETER));
   if (MaxBarsBack == -1) MaxBarsBack = INT_MAX;
   // ShowChartLegend
   if (AutoConfiguration) ShowChartLegend = GetConfigBool(indicator, "ShowChartLegend", ShowChartLegend);

   // Signal.onReversal
   string signalId = "Signal.onReversal";
   legendInfo = "";
   ConfigureSignals(signalId, AutoConfiguration, Signal.onReversal);
   if (Signal.onReversal) {
      if (!ConfigureSignalTypes(signalId, Signal.onReversal.Types, AutoConfiguration, signal.onReversal.sound, signal.onReversal.alert, signal.onReversal.mail, signal.onReversal.sms)) {
         return(catch("onInit(12)  invalid input parameter Signal.onReversal.Types: "+ DoubleQuoteStr(Signal.onReversal.Types), ERR_INVALID_INPUT_PARAMETER));
      }
      if (signal.onReversal.sound || signal.onReversal.alert || signal.onReversal.mail || signal.onReversal.sms) {
         legendInfo = StrLeft(ifString(signal.onReversal.sound, "sound,", "") + ifString(signal.onReversal.alert, "alert,", "") + ifString(signal.onReversal.mail, "mail,", "") + ifString(signal.onReversal.sms, "sms,", ""), -1);
         legendInfo = "("+ legendInfo +")";
      }
      else Signal.onReversal = false;
   }
   // Signal.onBreakout
   signalId = "Signal.onBreakout";
   ConfigureSignals(signalId, AutoConfiguration, Signal.onBreakout);
   if (Signal.onBreakout) {
      if (!ConfigureSignalTypes(signalId, Signal.onBreakout.Types, AutoConfiguration, signal.onBreakout.sound, signal.onBreakout.alert, signal.onBreakout.mail, signal.onBreakout.sms)) {
         return(catch("onInit(13)  invalid input parameter Signal.onBreakout.Types: "+ DoubleQuoteStr(Signal.onBreakout.Types), ERR_INVALID_INPUT_PARAMETER));
      }
      // Signal.onBreakout.123Only
      if (AutoConfiguration) Signal.onBreakout.123Only = GetConfigBool(indicator, "Signal.onBreakout.123Only", Signal.onBreakout.123Only);
   }
   // Sound.onChannelWidening
   if (AutoConfiguration) Sound.onChannelWidening = GetConfigBool(indicator, "Sound.onChannelWidening", Sound.onChannelWidening);

   // restore a stored runtime status
   RestoreStatus();

   // buffer management and display options
   SetIndicatorOptions();
   if (ShowChartLegend) legendLabel = CreateChartLegend();

   // Indicator events like reversals occur "on tick", not on "bar open" or "bar close". We need a chart ticker to prevent
   // invalid signals caused by ticks during data pumping.
   if (!__isTesting) {
      int hWnd = __ExecutionContext[EC.hChart];
      int millis = 2000;                                         // a virtual tick every 2 seconds
      __tickTimerId = SetupTickTimer(hWnd, millis, NULL);
      if (!__tickTimerId) return(catch("onInit(14)->SetupTickTimer() failed", ERR_RUNTIME_ERROR));
   }
   return(catch("onInit(15)"));
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
   // on the first tick after terminal start buffers may not yet be initialized (spurious issue)
   if (!ArraySize(semaphoreOpen)) return(logInfo("onTick(1)  sizeof(semaphoreOpen) = 0", SetLastError(ERS_TERMINAL_NOT_YET_READY)));

   // process incoming commands (may rewrite ValidBars/ChangedBars/ShiftedBars)
   if (__isChart && ZigZag.Periods.Step) HandleCommands("ParameterStepper", false);

   // framework: manage additional buffers
   ManageDoubleIndicatorBuffer(MODE_UPPER_CROSS_HIGH, upperCrossHigh);
   ManageDoubleIndicatorBuffer(MODE_LOWER_CROSS_LOW,  lowerCrossLow );
   ManageIntIndicatorBuffer   (MODE_KNOWN_TREND,      knownTrend    );
   ManageIntIndicatorBuffer   (MODE_UNKNOWN_TREND,    unknownTrend  );

   // reset buffers before performing a full recalculation
   if (!ValidBars) {
      ArrayInitialize(semaphoreOpen,  0);
      ArrayInitialize(semaphoreClose, 0);
      ArrayInitialize(upperBand,      0);
      ArrayInitialize(lowerBand,      0);
      ArrayInitialize(upperCross,     0);
      ArrayInitialize(lowerCross,     0);
      ArrayInitialize(upperCrossHigh, 0);
      ArrayInitialize(lowerCrossLow,  0);
      ArrayInitialize(reversal,      -1);
      ArrayInitialize(knownTrend,     0);
      ArrayInitialize(unknownTrend,   0);
      ArrayInitialize(combinedTrend,  0);
      prevUpperBand = 0;
      prevLowerBand = 0;
      sema1 = 0;
      sema2 = 0;
      sema3 = 0;
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
      ShiftDoubleIndicatorBuffer(upperCrossHigh, Bars, ShiftedBars,  0);
      ShiftDoubleIndicatorBuffer(lowerCrossLow,  Bars, ShiftedBars,  0);
      ShiftDoubleIndicatorBuffer(reversal,       Bars, ShiftedBars, -1);
      ShiftIntIndicatorBuffer   (knownTrend,     Bars, ShiftedBars,  0);
      ShiftIntIndicatorBuffer   (unknownTrend,   Bars, ShiftedBars,  0);
      ShiftDoubleIndicatorBuffer(combinedTrend,  Bars, ShiftedBars,  0);
   }

   // check data pumping on every tick so the reversal handler can skip errornous signals
   IsPossibleDataPumping();

   // calculate start bar
   int startbar = Min(MaxBarsBack-1, ChangedBars-1, Bars-ZigZag.Periods);
   if (startbar < 0 && MaxBarsBack) return(logInfo("onTick(2)  Tick="+ Ticks +"  Bars="+ Bars +"  needed="+ ZigZag.Periods, ERR_HISTORY_INSUFFICIENT));

   // recalculate changed bars
   if (startbar > 2) {
      semaphoreOpen [startbar] =  0;
      semaphoreClose[startbar] =  0;
      upperBand     [startbar] =  0;
      lowerBand     [startbar] =  0;
      upperCross    [startbar] =  0;
      lowerCross    [startbar] =  0;
      upperCrossHigh[startbar] =  0;
      lowerCrossLow [startbar] =  0;
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
         upperCross    [bar] = upperBand[bar+1]+Point;
         upperCrossHigh[bar] = upperBand[bar];
      }
      if (lowerBand[bar] < lowerBand[bar+1]) {
         lowerCross   [bar] = lowerBand[bar+1]-Point;
         lowerCrossLow[bar] = lowerBand[bar];
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
            if (!knownTrend[bar]) ProcessLowerCross(bar);         // if bar not yet processed process both crossings
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

      // hide non-configured crossing buffers
      if (!crossingDrawType) {                                    // hide all crossings
         upperCross[bar] = 0;
         lowerCross[bar] = 0;
      }
      else if (crossingDrawType == MODE_FIRST_CROSSING) {         // hide all crossings except the 1st
         bool isReversal = false;

         if (!unknownTrend[bar]) {
            int absTrend = MathAbs(knownTrend[bar]);
            if      (absTrend == reversal[bar])       isReversal = true;
            else if (absTrend == 1 && !reversal[bar]) isReversal = true;
         }
         if (isReversal) {
            if (knownTrend[bar] > 0) lowerCross[bar] = 0;
            else                     upperCross[bar] = 0;
         }
         else {
            upperCross[bar] = 0;
            lowerCross[bar] = 0;
         }
      }
   }

   if (!__isSuperContext) {
      if (__isChart && ShowChartLegend) UpdateChartLegend();

      if (ChangedBars > 2) {
         // get last 3 semaphores
         bar   = Abs(knownTrend[0]) + unknownTrend[0];
         sema1 = semaphoreClose[bar];
         bar   = FindPreceedingSemaphore(bar+1);
         sema2 = semaphoreClose[bar];
         bar   = FindPreceedingSemaphore(bar+1);
         sema3 = semaphoreClose[bar];
      }
      else {
         // signal ZigZag breakouts
         if (Signal.onBreakout && sema3) {
            if (prevBid < sema2+Point/2) /*&&*/ if (_Bid > sema2+Point/2) /*&&*/ if (_Bid > High[0]-Point/2) {
               if (iHighest(NULL, NULL, MODE_HIGH, 1+knownTrend[0]) == 0) {   // the current bar must be the High since sema1
                  bool is123Pattern = (sema3 < sema1+Point/2);
                  if (!Signal.onBreakout.123Only || is123Pattern) onBreakout(D_LONG, is123Pattern, ChangedBars-1);
               }
            }
            if (prevBid > sema2-Point/2) /*&&*/ if (_Bid < sema2-Point/2) /*&&*/ if (_Bid < Low[0]+Point/2) {
               if (iLowest(NULL, NULL, MODE_LOW, 1-knownTrend[0]) == 0) {     // the current bar must be the Low since sema1
                  is123Pattern = (sema3 > sema1-Point/2);
                  if (!Signal.onBreakout.123Only || is123Pattern) onBreakout(D_SHORT, is123Pattern, ChangedBars-1);
               }
            }
            prevBid = _Bid;
         }

         // signal Donchian channel widenings
         if (Sound.onChannelWidening) {
            if (ChangedBars == 2) {
               prevUpperBand = upperBand[1];
               prevLowerBand = lowerBand[1];
            }
            if (prevUpperBand && prevLowerBand) {
               if      (upperBand[0] > prevUpperBand+Point/2) onChannelWidening(D_LONG);
               else if (lowerBand[0] < prevLowerBand-Point/2) onChannelWidening(D_SHORT);
            }
            prevUpperBand = upperBand[0];
            prevLowerBand = lowerBand[0];
         }
      }
   }
   return(catch("onTick(3)"));
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
 * Resolve the chart offset of the ZigZag semaphore preceeding the current tick at the specified bar. The bar may be part of
 * a finished (historic) or unfinished (currently progressing) ZigZag leg. As bar 0 and 1 can receive multiple ticks the
 * semaphore may be located at the current bar.
 *
 * @param  int bar - chart bar
 *
 * @return int - chart offset of the preceeding semaphore
 */
int FindPreceedingSemaphore(int bar) {
   int semBar;

   if (semaphoreClose[bar] != NULL) {                             // semaphore is located at the current bar
      semBar = bar;
   }
   else {                                                         // semaphore is located at a previous bar
      int nextBar = bar+1;
      semBar = nextBar + unknownTrend[nextBar];                   // unknown[] (may be 0) points to the preceeding semaphore
      if (!semaphoreClose[semBar]) {                              // if called for a historic bar before the first cross
         semBar = nextBar + Abs(knownTrend[nextBar]);
      }
   }
   return(semBar);
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
   int prevSem = FindPreceedingSemaphore(bar);                       // resolve the preceeding semaphore
   int prevTrend = knownTrend[prevSem];                              // trend at the preceeding semaphore

   if (prevTrend > 0) {
      if (prevSem == bar) {                                          // trend buffers are already set
         if (semaphoreOpen[bar] != lowerCrossLow[bar]) {             // update existing semaphore
            semaphoreOpen[bar] = upperCrossHigh[bar];
         }
         semaphoreClose[bar] = upperCrossHigh[bar];
      }
      else {
         if (upperCrossHigh[bar] > upperCrossHigh[prevSem]) {        // an uptrend continuation
            UpdateTrend(prevSem, prevTrend, bar, false);             // update existing trend
            if (semaphoreOpen[prevSem] == semaphoreClose[prevSem]) {
               semaphoreOpen [prevSem] = 0;                          // reset previous semaphore
            }
            semaphoreClose[prevSem] = semaphoreOpen[prevSem];
            semaphoreOpen [bar]     = upperCrossHigh[bar];           // set new semaphore
            semaphoreClose[bar]     = upperCrossHigh[bar];
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
         semaphoreOpen[bar] = upperCrossHigh[bar];                   // set new semaphore
      }
      semaphoreClose[bar] = upperCrossHigh[bar];
      reversal      [bar] = prevSem-bar;                             // set new reversal offset

      sema3 = sema2;                                                 // update the last 3 semaphores
      sema2 = sema1;
      sema1 = Low[bar+knownTrend[bar]];

      if (Signal.onReversal && ChangedBars <= 2) onReversal(D_LONG, bar);
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
   int prevSem = FindPreceedingSemaphore(bar);                       // resolve the preceeding semaphore
   int prevTrend = knownTrend[prevSem];                              // trend at the preceeding semaphore

   if (prevTrend < 0) {
      if (prevSem == bar) {                                          // trend buffers are already set
         if (semaphoreOpen[bar] != upperCrossHigh[bar]) {            // update existing semaphore
            semaphoreOpen [bar] = lowerCrossLow[bar];
         }
         semaphoreClose[bar] = lowerCrossLow[bar];
      }
      else {
         if (lowerCrossLow[bar] < lowerCrossLow[prevSem]) {          // a downtrend continuation
            UpdateTrend(prevSem, prevTrend, bar, false);             // update existing trend
            if (semaphoreOpen[prevSem] == semaphoreClose[prevSem]) {
               semaphoreOpen [prevSem] = 0;                          // reset previous semaphore
            }
            semaphoreClose[prevSem] = semaphoreOpen[prevSem];
            semaphoreOpen [bar]     = lowerCrossLow[bar];            // set new semaphore
            semaphoreClose[bar]     = lowerCrossLow[bar];
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
         semaphoreOpen[bar] = lowerCrossLow[bar];                    // set new semaphore
      }
      semaphoreClose[bar] = lowerCrossLow[bar];
      reversal      [bar] = prevSem-bar;                             // set the new reversal offset

      sema3 = sema2;                                                 // update the last 3 semaphores
      sema2 = sema1;
      sema1 = High[bar-knownTrend[bar]];

      if (Signal.onReversal && ChangedBars <= 2) onReversal(D_SHORT, bar);
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
 * Handle AccountChange events.
 *
 * @param  int previous - account number
 * @param  int current  - account number
 *
 * @return int - error status
 */
int onAccountChange(int previous, int current) {
   lastTick        = 0;             // reset global vars used by the various event handlers
   lastSoundSignal = 0;
   skipSignals     = 0;
   return(onInit());
}


/**
 * Event handler signaling new ZigZag reversals. Prevents duplicate signals triggered by multiple running instances.
 *
 * @param  int direction - reversal direction: D_LONG | D_SHORT
 * @param  int bar       - reversal bar (the current or the closed bar)
 *
 * @return bool - success status
 */
bool onReversal(int direction, int bar) {
   if (direction!=D_LONG && direction!=D_SHORT) return(!catch("onReversal(1)  invalid parameter direction: "+ direction, ERR_INVALID_PARAMETER));
   if (bar > 1)                                 return(!catch("onReversal(2)  illegal parameter bar: "+ bar, ERR_INVALID_PARAMETER));
   if (!__isChart)                              return(true);
   if (IsPossibleDataPumping())                 return(true);        // skip signals during possible data pumping

   // skip the signal if it already was signaled before
   int hWnd = ifInt(__isTesting, __ExecutionContext[EC.hChart], GetDesktopWindow()), error;
   string sPeriod = PeriodDescription();
   string sEvent  = "rsf::"+ StdSymbol() +","+ sPeriod +"."+ indicatorName +"(P="+ ZigZag.Periods +").onReversal("+ direction +")."+ TimeToStr(Time[bar]);
   if (GetPropA(hWnd, sEvent) != 0) return(true);
   SetPropA(hWnd, sEvent, 1);                                        // immediately mark as signaled (prevents duplicate signals with slow CPU)

   string message = ifString(direction==D_LONG, "up", "down") +" (bid: "+ NumberToStr(_Bid, PriceFormat) +")", accountTime="";
   if (IsLogInfo()) logInfo("onReversal(P="+ ZigZag.Periods +")  "+ message);

   if (signal.onReversal.sound) {
      error = PlaySoundEx(ifString(direction==D_LONG, Signal.Sound.Up, Signal.Sound.Down));
      if (!error)                           lastSoundSignal = GetTickCount();
      else if (error == ERR_FILE_NOT_FOUND) signal.onReversal.sound = false;
   }

   message = Symbol() +","+ PeriodDescription() +": "+ WindowExpertName() +"(P="+ ZigZag.Periods +") reversal "+ message;
   if (signal.onReversal.mail || signal.onReversal.sms) accountTime = "("+ TimeToStr(TimeLocalEx("onReversal(3)"), TIME_MINUTES|TIME_SECONDS) +", "+ GetAccountAlias() +")";

   if (signal.onReversal.alert)          Alert(message);
   if (signal.onReversal.mail) error |= !SendEmail("", "", message, message + NL + accountTime);
   if (signal.onReversal.sms)  error |= !SendSMS("", message + NL + accountTime);
   return(!error);
}


/**
 * Event handler signaling new ZigZag breakouts. Prevents duplicate signals triggered by multiple running instances.
 *
 * @param  int  direction    - breakout direction: D_LONG | D_SHORT
 * @param  bool is123Pattern - whether the breakout represents a valid 1-2-3 pattern
 * @param  int  bar          - breakout bar (the current or the closed bar)
 *
 * @return bool - success status
 */
bool onBreakout(int direction, bool is123Pattern, int bar) {
   is123Pattern = is123Pattern!=0;
   if (direction!=D_LONG && direction!=D_SHORT) return(!catch("onBreakout(1)  invalid parameter direction: "+ direction, ERR_INVALID_PARAMETER));
   if (bar > 1)                                 return(!catch("onBreakout(2)  illegal parameter bar: "+ bar, ERR_INVALID_PARAMETER));
   if (!__isChart)                              return(true);
   if (IsPossibleDataPumping())                 return(true);        // skip signals during possible data pumping

   // skip the signal if it already was signaled before
   int hWnd = ifInt(__isTesting, __ExecutionContext[EC.hChart], GetDesktopWindow()), error;
   string sPeriod = PeriodDescription();
   string sEvent  = "rsf::"+ StdSymbol() +","+ sPeriod +"."+ indicatorName +"(P="+ ZigZag.Periods +").onBreakout("+ direction +")."+ TimeToStr(Time[bar]);
   if (GetPropA(hWnd, sEvent) != 0) return(true);
   SetPropA(hWnd, sEvent, 1);                                        // immediately mark as signaled (prevents duplicate signals with slow CPU)

   string message = ifString(direction==D_LONG, "long", "short") + ifString(is123Pattern, ", 1-2-3 pattern", "") +" (bid: "+ NumberToStr(_Bid, PriceFormat) +")", accountTime="";
   if (IsLogInfo()) logInfo("onBreakout(P="+ ZigZag.Periods +")  "+ message);

   if (signal.onBreakout.sound) {
      error = PlaySoundEx(ifString(direction==D_LONG, Signal.Sound.Up, Signal.Sound.Down));
      if (!error)                           lastSoundSignal = GetTickCount();
      else if (error == ERR_FILE_NOT_FOUND) signal.onBreakout.sound = false;
   }

   message = Symbol() +","+ PeriodDescription() +": "+ WindowExpertName() +"(P="+ ZigZag.Periods +") breakout "+ message;
   if (signal.onReversal.mail || signal.onReversal.sms) accountTime = "("+ TimeToStr(TimeLocalEx("onReversal(3)"), TIME_MINUTES|TIME_SECONDS) +", "+ GetAccountAlias() +")";

   if (signal.onBreakout.alert)          Alert(message);
   if (signal.onBreakout.mail) error |= !SendEmail("", "", message, message + NL + accountTime);
   if (signal.onBreakout.sms)  error |= !SendSMS("", message + NL + accountTime);
   return(!error);
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

   if (lastSoundSignal+2000 < GetTickCount()) {                      // at least 2 sec pause between consecutive sound signals
      int error = PlaySoundEx(ifString(direction==D_LONG, Sound.onNewChannelHigh, Sound.onNewChannelLow));
      if (!error)                           lastSoundSignal = GetTickCount();
      else if (error == ERR_FILE_NOT_FOUND) Sound.onChannelWidening = false;
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
   static int lastTickcount = 0;
   int tickcount = StrToInteger(params);

   // stepper cmds are not removed from the queue: compare tickcount with last processed command and skip if old
   if (__isChart) {
      string label = "rsf."+ WindowExpertName() +".cmd.tickcount";
      bool objExists = (ObjectFind(label) != -1);

      if (objExists) lastTickcount = StrToInteger(ObjectDescription(label));
      if (tickcount <= lastTickcount) return(false);

      if (!objExists) ObjectCreate(label, OBJ_LABEL, 0, 0, 0);
      ObjectSet    (label, OBJPROP_TIMEFRAMES, OBJ_PERIODS_NONE);
      ObjectSetText(label, ""+ tickcount);
   }
   else if (tickcount <= lastTickcount) return(false);
   lastTickcount = tickcount;

   if (cmd == "parameter-up")   return(ParameterStepper(STEP_UP, keys));
   if (cmd == "parameter-down") return(ParameterStepper(STEP_DOWN, keys));

   return(!logNotice("onCommand(1)  unsupported command: \""+ cmd +":"+ params +":"+ keys +"\""));
}


/**
 * Step up/down the input parameter "ZigZag.Periods".
 *
 * @param  int direction - STEP_UP | STEP_DOWN
 * @param  int keys      - modifier keys (not used by this indicator)
 *
 * @return bool - success status
 */
bool ParameterStepper(int direction, int keys) {
   if (direction!=STEP_UP && direction!=STEP_DOWN) return(!catch("ParameterStepper(1)  invalid parameter direction: "+ direction, ERR_INVALID_PARAMETER));

   double step = ZigZag.Periods.Step;

   if (!step || ZigZag.Periods + direction*step < 2) {      // no stepping if parameter limit reached
      PlaySoundEx("Plonk.wav");
      return(false);
   }
   if (direction == STEP_UP) ZigZag.Periods += step;
   else                      ZigZag.Periods -= step;

   ChangedBars = Bars;
   ValidBars   = 0;
   ShiftedBars = 0;

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
      string sSignal   = ifString(Signal.onReversal, "  "+ legendInfo, "");
      string text      = StringConcatenate(indicatorName, sKnown, sUnknown, sReversal, sSignal);

      color clr = ZigZag.Color;
      if      (clr == Aqua        ) clr = DeepSkyBlue;
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
 * Workaround for various terminal bugs when setting indicator options. Usually options are set in init(). However after
 * recompilation options must be set in start() to not be ignored.
 */
void SetIndicatorOptions() {
   string name   = ProgramName();
   indicatorName = name +"("+ ifString(ZigZag.Periods.Step, "step:", "") + ZigZag.Periods +")";
   shortName     = name +"("+ ZigZag.Periods +")";
   IndicatorShortName(shortName);

   IndicatorBuffers(terminal_buffers);
   SetIndexBuffer(MODE_SEMAPHORE_OPEN,  semaphoreOpen ); SetIndexEmptyValue(MODE_SEMAPHORE_OPEN,  0); SetIndexLabel(MODE_SEMAPHORE_OPEN,  NULL);
   SetIndexBuffer(MODE_SEMAPHORE_CLOSE, semaphoreClose); SetIndexEmptyValue(MODE_SEMAPHORE_CLOSE, 0); SetIndexLabel(MODE_SEMAPHORE_CLOSE, NULL);
   SetIndexBuffer(MODE_UPPER_BAND,      upperBand     ); SetIndexEmptyValue(MODE_UPPER_BAND,      0); SetIndexLabel(MODE_UPPER_BAND,      shortName +" upper band"); if (!Donchian.ShowChannel) SetIndexLabel(MODE_UPPER_BAND,  NULL);
   SetIndexBuffer(MODE_LOWER_BAND,      lowerBand     ); SetIndexEmptyValue(MODE_LOWER_BAND,      0); SetIndexLabel(MODE_LOWER_BAND,      shortName +" lower band"); if (!Donchian.ShowChannel) SetIndexLabel(MODE_LOWER_BAND,  NULL);
   SetIndexBuffer(MODE_UPPER_CROSS,     upperCross    ); SetIndexEmptyValue(MODE_UPPER_CROSS,     0); SetIndexLabel(MODE_UPPER_CROSS,     shortName +" cross up");   if (!crossingDrawType)     SetIndexLabel(MODE_UPPER_CROSS, NULL);
   SetIndexBuffer(MODE_LOWER_CROSS,     lowerCross    ); SetIndexEmptyValue(MODE_LOWER_CROSS,     0); SetIndexLabel(MODE_LOWER_CROSS,     shortName +" cross down"); if (!crossingDrawType)     SetIndexLabel(MODE_LOWER_CROSS, NULL);
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
                            "MaxBarsBack=",                  MaxBarsBack                             +";"+ NL,
                            "ShowChartLegend=",              BoolToStr(ShowChartLegend)              +";"+ NL,

                            "Signal.onReversal=",            BoolToStr(Signal.onReversal)            +";"+ NL,
                            "Signal.onReversal.Types=",      DoubleQuoteStr(Signal.onReversal.Types) +";"+ NL,
                            "Signal.onBreakout=",            BoolToStr(Signal.onBreakout)            +";"+ NL,
                            "Signal.onBreakout.123Only=",    BoolToStr(Signal.onBreakout.123Only)    +";"+ NL,
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
