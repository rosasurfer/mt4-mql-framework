/**
 * Donchian Channel
 *
 * The indicator supports manual stepping of the Donchian Channel period via hotkey and provides multiple signaling modes.
 *
 *
 * Input parameters
 * ----------------
 *  • Periods:                     Look-back periods of the Donchian Channel.
 *  • Periods.Step:                Option to control parameter "Period" via keyboard. If non-zero it defines the step size of
 *                                 the parameter stepper. If 0 (zero) parameter stepping is disabled.
 *  • Channel.UpperColor:          Color of the upper Donchian Channel band.
 *  • Channel.LowerColor:          Color of the lower Donchian Channel band.
 *
 *  • ShowReversals:               Whether to display Donchian Channel reversals (may contain filter conditions).
 *  • Reversal.Symbol:             Graphic symbol used for Donchian Channel reversals.
 *  • Reversal.Width:              Size of displayed Donchian Channel reversals.
 *  • Reversal.Color:              Separate color of Donchian Channel reversals (default: color of channel bands).
 *
 *  • ShowChartLegend:             Whether do display the chart legend.
 *  • MaxBarsBack:                 Maximum number of bars back to calculate the indicator for (affects performance).
 *
 *  • Signal.onReversal:           Whether to signal Donchian Channel reversals.
 *  • Signal.onReversal.Types:     Signaling methods, a combination of "sound", "alert", "email" and/or "telegram".
 *  • Signal.onReversal.SoundUp:   Sound file for long reversals.
 *  • Signal.onReversal.SoundDown: Sound file for short reversals.
 *
 *  • Sound.onChannelWidening:     Whether to play a sound on Donchian Channel widening.
 *  • Sound.onNewChannelHigh:      Sound file for channel widenings to the upside.
 *  • Sound.onNewChannelLow:       Sound file for channel widenings to the downside.
 *
 *  • TrackReversalBalance:        Whether to track the balance of Donchian Channel reversals.
 *  • TrackReversalBalance.Symbol: Custom symbol for balance tracking (default: generated).
 *
 *  • AutoConfiguration:           If enabled all input parameters can be pre-defined in the configuration.
 *
 *
 * Usage with iCustom()
 * --------------------
 * @see /mql40/include/rsf/functions/iCustom/DonchianChannel.mqh
 */
#include <rsf/stddefines.mqh>
int   __InitFlags[];
int __DeinitFlags[];

///////////////////////////////////////////////////// Input parameters //////////////////////////////////////////////////////

extern string ___a__________________________ = "=== Donchian settings ===";
extern int    Periods                        = 200;                        // look-back period
extern int    Periods.Step                   = 0;                          // step size for parameter stepping

extern color  Channel.UpperColor             = Blue;
extern color  Channel.LowerColor             = Red;

extern string ShowReversals                  = "on* | off | +N | -N";      // which channel reversals to display
extern string Reversal.Symbol                = "dot | thin-ring | ring | thick-ring*";
extern int    Reversal.Width                 = 1;
extern color  Reversal.Color                 = CLR_NONE;                   // separate reversal color (default: channel color)

extern string ___b__________________________ = "=== Display settings ===";
extern bool   ShowChartLegend                = true;
extern int    MaxBarsBack                    = 10000;                      // max. values to calculate (-1: all available)

extern string ___c__________________________ = "=== Signaling ===";
extern bool   Signal.onReversal              = false;                      // signal channel reversals
extern string Signal.onReversal.Types        = "sound* | alert | mail | telegram";
extern string Signal.onReversal.SoundUp      = "Signal Up.wav";
extern string Signal.onReversal.SoundDown    = "Signal Down.wav";

extern bool   Sound.onChannelWidening        = false;                      // signal channel widenings
extern string Sound.onNewChannelHigh         = "Price Advance.wav";
extern string Sound.onNewChannelLow          = "Price Decline.wav";

extern string ___d__________________________ = "=======================";
extern bool   TrackReversalBalance           = false;                      // whether to track the balance of channel reversals
extern string TrackReversalBalance.Symbol    = "(default)";                // custom symbol for balance tracking

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <rsf/core/indicator.mqh>
#include <rsf/stdfunctions.mqh>
#include <rsf/stdlib.mqh>
#include <rsf/history.mqh>
#include <rsf/functions/chartlegend.mqh>
#include <rsf/functions/ConfigureSignals.mqh>
#include <rsf/functions/HandleCommands.mqh>
#include <rsf/functions/iBarShiftNext.mqh>
#include <rsf/functions/iCustom/DonchianChannel.mqh>
#include <rsf/functions/ManageDoubleIndicatorBuffer.mqh>
#include <rsf/functions/ObjectCreateRegister.mqh>

#property indicator_chart_window
#property indicator_buffers   7                                // buffers managed by the terminal
int       framework_buffers = 4;                               // buffers managed by the framework


// indicator buffer ids
#define MODE_UPPER_BAND          Donchian.MODE_UPPER_BAND      // 0 upper channel band
#define MODE_LOWER_BAND          Donchian.MODE_LOWER_BAND      // 1 lower channel band
#define MODE_REVERSAL_LONG       Donchian.MODE_REVERSAL_LONG   // 2 long reversals
#define MODE_REVERSAL_SHORT      Donchian.MODE_REVERSAL_SHORT  // 3 short reversals
#define MODE_REVERSAL_DIMMED     4                             // 4 filtered reversals (dimmed representation)
#define MODE_TREND               Donchian.MODE_TREND           // 5 int: direction and length of channel reversals
#define MODE_REVERSAL_COUNT      Donchian.MODE_REVERSAL_COUNT  // 6 int: number of consecutive winning/losing reversals
#define MODE_REVERSAL_BALANCE_O  7                             // reversal balance in pUnits: positive/negative or EMPTY_VALUE
#define MODE_REVERSAL_BALANCE_H  8                             // ...
#define MODE_REVERSAL_BALANCE_L  9                             // ...
#define MODE_REVERSAL_BALANCE_C 10                             // ...

#property indicator_color1 Blue              // upper channel band
#property indicator_style1 STYLE_DOT         //
#property indicator_color2 Red               // lower channel band
#property indicator_style2 STYLE_DOT         //

#property indicator_color3 indicator_color1  // long reversals
#property indicator_width3 0                 //
#property indicator_color4 indicator_color2  // short reversals
#property indicator_width4 0                 //
#property indicator_color5 DarkGray          // filtered (dimmed) reversals
#property indicator_width5 0                 //

#property indicator_color6 CLR_NONE
#property indicator_color7 CLR_NONE

double   upperBand        [];
double   lowerBand        [];
double   upperCross       [];
double   lowerCross       [];
double   dimmed           [];                // filtered (dimmed) reversals
double   trend            [];                // int: direction and length of channel reversals
double   reversalCount    [];                // int: number of consecutive winning/losing reversals
double   reversalBalance_O[];                // reversal balance in pUnits: positive/negative or EMPTY_VALUE
double   reversalBalance_H[];                // ...
double   reversalBalance_L[];                // ...
double   reversalBalance_C[];                // ...

string   indicatorName = "";
string   shortName     = "";
string   legendLabel   = "";
string   legendInfo    = "";                 // additional chart legend info

bool     reversals.show;                     // whether to show reversals
int      reversals.countFrom;                // which reversals to show
int      reversals.symbol;

bool     signal.onReversal.sound;
bool     signal.onReversal.alert;
bool     signal.onReversal.mail;
bool     signal.onReversal.telegram;

double   lastUpperBand;                      // detection of channel widenings
double   lastLowerBand;                      // upper/lower band values at the previous tick

datetime skipSignals;                        // skip signals until the specified time to wait for possible data pumping
datetime lastTick;
int      lastSoundSignal;                    // GetTickCount() value of the last audio signal


// recorder status
bool     recorder.initialized;
string   recorder.hstDirectory = "";
int      recorder.hstFormat;
string   recorder.symbol = "";
string   recorder.symbolDescr = "";
string   recorder.group = "";
int      recorder.priceBase = 1;
int      recorder.hSet;
datetime recorder.startTime;


// signal direction types
#define D_LONG  TRADE_DIRECTION_LONG         // 1
#define D_SHORT TRADE_DIRECTION_SHORT        // 2

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
   // Periods
   if (AutoConfiguration) Periods = GetConfigInt(indicator, "Periods", Periods);
   if (Periods < 2) return(catch("onInit(1)  invalid input parameter Periods: "+ Periods, ERR_INVALID_INPUT_PARAMETER));
   // Periods.Step
   if (AutoConfiguration) Periods.Step = GetConfigInt(indicator, "Periods.Step", Periods.Step);
   if (Periods.Step < 0) return(catch("onInit(2)  invalid input parameter Periods.Step: "+ Periods.Step +" (must be >= 0)", ERR_INVALID_INPUT_PARAMETER));
   // ShowReversals
   if (AutoConfiguration) ShowReversals = GetConfigString(indicator, "ShowReversals", ShowReversals);
   if (!ValidateShowReversals(ShowReversals, reversals.show, reversals.countFrom)) {
      return(catch("onInit(3)  invalid input parameter ShowReversals: "+ DoubleQuoteStr(ShowReversals), ERR_INVALID_INPUT_PARAMETER));
   }
   // Reversal.Symbol
   if (AutoConfiguration) Reversal.Symbol = GetConfigString(indicator, "Reversal.Symbol", Reversal.Symbol);
   string sValues[], sValue = Reversal.Symbol;
   if (Explode(sValue, "*", sValues, 2) > 1) {
      int size = Explode(sValues[0], "|", sValues, NULL);
      sValue = sValues[size-1];
   }
   sValue = StrToLower(StrTrim(sValue));
   if      (sValue == "dot"       ) reversals.symbol = 108;    // that's Wingding characters
   else if (sValue == "thin-ring" ) reversals.symbol = 161;    // ...
   else if (sValue == "ring"      ) reversals.symbol = 162;    // ...
   else if (sValue == "thick-ring") reversals.symbol = 163;    // ...
   else return(catch("onInit(4)  invalid input parameter Reversal.Symbol: "+ DoubleQuoteStr(Reversal.Symbol), ERR_INVALID_INPUT_PARAMETER));
   Reversal.Symbol = sValue;
   // Reversal.Width
   if (AutoConfiguration) Reversal.Width = GetConfigInt(indicator, "Reversal.Width", Reversal.Width);
   if (Reversal.Width < 0) return(catch("onInit(5)  invalid input parameter Reversal.Width: "+ Reversal.Width, ERR_INVALID_INPUT_PARAMETER));
   // colors: after deserialization the terminal might turn CLR_NONE (0xFFFFFFFF) into Black (0xFF000000)
   if (AutoConfiguration) Channel.UpperColor = GetConfigColor(indicator, "Channel.UpperColor", Channel.UpperColor);
   if (AutoConfiguration) Channel.LowerColor = GetConfigColor(indicator, "Channel.LowerColor", Channel.LowerColor);
   if (AutoConfiguration) Reversal.Color     = GetConfigColor(indicator, "Reversal.Color",     Reversal.Color);
   if (Channel.UpperColor == 0xFF000000) Channel.UpperColor = CLR_NONE;
   if (Channel.LowerColor == 0xFF000000) Channel.LowerColor = CLR_NONE;
   if (Reversal.Color     == 0xFF000000) Reversal.Color     = CLR_NONE;
   // ShowChartLegend
   if (AutoConfiguration) ShowChartLegend = GetConfigBool(indicator, "ShowChartLegend", ShowChartLegend);
   // MaxBarsBack
   if (AutoConfiguration) MaxBarsBack = GetConfigInt(indicator, "MaxBarsBack", MaxBarsBack);
   if (MaxBarsBack < -1) return(catch("onInit(6)  invalid input parameter MaxBarsBack: "+ MaxBarsBack, ERR_INVALID_INPUT_PARAMETER));
   if (MaxBarsBack == -1) MaxBarsBack = INT_MAX;

   // Signal.onReversal
   string signalId = "Signal.onReversal";
   legendInfo = "";
   ConfigureSignals(signalId, AutoConfiguration, Signal.onReversal);
   if (Signal.onReversal) {
      if (!ConfigureSignalTypes(signalId, Signal.onReversal.Types, AutoConfiguration, signal.onReversal.sound, signal.onReversal.alert, signal.onReversal.mail, signal.onReversal.telegram)) {
         return(catch("onInit(7)  invalid input parameter Signal.onReversal.Types: "+ DoubleQuoteStr(Signal.onReversal.Types), ERR_INVALID_INPUT_PARAMETER));
      }
      Signal.onReversal = (signal.onReversal.sound || signal.onReversal.alert || signal.onReversal.mail || signal.onReversal.telegram);
      if (Signal.onReversal) {
         legendInfo = "("+ StrLeft(ifString(signal.onReversal.sound, "sound,", "") + ifString(signal.onReversal.alert, "alert,", "") + ifString(signal.onReversal.mail, "mail,", "") + ifString(signal.onReversal.telegram, "tgm,", ""), -1) +")";
         legendInfo = StrReplace(legendInfo, "sound,alert", "alert");
      }
   }
   if (AutoConfiguration) Signal.onReversal.SoundUp   = GetConfigString(indicator, "Signal.onReversal.SoundUp",   Signal.onReversal.SoundUp);
   if (AutoConfiguration) Signal.onReversal.SoundDown = GetConfigString(indicator, "Signal.onReversal.SoundDown", Signal.onReversal.SoundDown);
   // Sound.*
   if (AutoConfiguration) Sound.onChannelWidening = GetConfigBool(indicator, "Sound.onChannelWidening", Sound.onChannelWidening);
   if (AutoConfiguration) Sound.onNewChannelHigh  = GetConfigString(indicator, "Sound.onNewChannelHigh", Sound.onNewChannelHigh);
   if (AutoConfiguration) Sound.onNewChannelLow   = GetConfigString(indicator, "Sound.onNewChannelLow", Sound.onNewChannelLow);
   if (Sound.onChannelWidening) {
      if (legendInfo == "") legendInfo = "(w)";
      else                  legendInfo = StrLeft(legendInfo, -1) +",w)";
   }
   // TrackReversalBalance
   if (AutoConfiguration) TrackReversalBalance = GetConfigBool(indicator, "TrackReversalBalance", TrackReversalBalance);
   if (__isSuperContext || __isTesting) TrackReversalBalance = false;
   // TrackReversalBalance.Symbol
   if (AutoConfiguration) TrackReversalBalance.Symbol = GetConfigBool(indicator, "TrackReversalBalance.Symbol", TrackReversalBalance.Symbol);

   // reset an active command handler
   if (__isChart && Periods.Step) {
      GetChartCommand("ParameterStepper", sValues);
   }
   RestoreStatus();

   // buffer management and display options
   SetIndicatorOptions();
   if (ShowChartLegend) legendLabel = CreateChartLegend();

   // Indicator event "breakout" occurs on tick, not on "bar-open" or "bar-close".
   // We need a chart ticker to prevent invalid signals caused by ticks during data pumping.
   if (!__isTesting && !__virtualTicksTimerId) {
      int hWnd = __ExecutionContext[EC.chart];
      int millis = 2000;                                         // a virtual tick every 2 seconds
      __virtualTicksTimerId = SetupTickTimer(hWnd, millis, NULL);
      if (!__virtualTicksTimerId) return(catch("onInit(8)->SetupTickTimer() failed", ERR_RUNTIME_ERROR));
   }
   return(catch("onInit(9)"));
}


/**
 * Deinitialization
 *
 * @return int - error status
 */
int onDeinit() {
   StoreStatus();

   // release the chart ticker
   if (__virtualTicksTimerId > 0) {
      int tmp = __virtualTicksTimerId;
      __virtualTicksTimerId = NULL;
      if (!ReleaseTickTimer(tmp)) return(catch("onDeinit(1)->ReleaseTickTimer(timerId="+ tmp +") failed", ERR_RUNTIME_ERROR));
   }

   // close an open history set
   if (recorder.hSet != 0) {
      tmp = recorder.hSet;
      recorder.hSet = NULL;
      if (!HistorySet1.Close(tmp)) return(ERR_RUNTIME_ERROR);
   }
   return(catch("onDeinit(2)"));
}


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   // process incoming commands (rewrites ValidBars/ChangedBars/ShiftedBars)
   if (__isChart && Periods.Step) {
      if (!HandleCommands("ParameterStepper")) return(last_error);
   }

   // manage additional framework buffers
   ManageDoubleIndicatorBuffer(MODE_REVERSAL_BALANCE_O, reversalBalance_O, EMPTY_VALUE);
   ManageDoubleIndicatorBuffer(MODE_REVERSAL_BALANCE_H, reversalBalance_H, EMPTY_VALUE);
   ManageDoubleIndicatorBuffer(MODE_REVERSAL_BALANCE_L, reversalBalance_L, EMPTY_VALUE);
   ManageDoubleIndicatorBuffer(MODE_REVERSAL_BALANCE_C, reversalBalance_C, EMPTY_VALUE);

   // reset buffers before performing a full recalculation
   if (!ValidBars) {
      ArrayInitialize(upperBand,         0);
      ArrayInitialize(lowerBand,         0);
      ArrayInitialize(upperCross,        0);
      ArrayInitialize(lowerCross,        0);
      ArrayInitialize(dimmed,            0);
      ArrayInitialize(trend,             0);
      ArrayInitialize(reversalCount,     0);
      ArrayInitialize(reversalBalance_O, EMPTY_VALUE);
      ArrayInitialize(reversalBalance_H, EMPTY_VALUE);
      ArrayInitialize(reversalBalance_L, EMPTY_VALUE);
      ArrayInitialize(reversalBalance_C, EMPTY_VALUE);
      SetIndicatorOptions();

      lastUpperBand = 0;
      lastLowerBand = 0;
   }

   // synchronize buffers with a shifted offline chart
   if (ShiftedBars > 0) {
      ShiftDoubleIndicatorBuffer(upperBand,         Bars, ShiftedBars, 0);
      ShiftDoubleIndicatorBuffer(lowerBand,         Bars, ShiftedBars, 0);
      ShiftDoubleIndicatorBuffer(upperCross,        Bars, ShiftedBars, 0);
      ShiftDoubleIndicatorBuffer(lowerCross,        Bars, ShiftedBars, 0);
      ShiftDoubleIndicatorBuffer(dimmed,            Bars, ShiftedBars, 0);
      ShiftDoubleIndicatorBuffer(trend,             Bars, ShiftedBars, 0);
      ShiftDoubleIndicatorBuffer(reversalCount,     Bars, ShiftedBars, 0);
      ShiftDoubleIndicatorBuffer(reversalBalance_O, Bars, ShiftedBars, EMPTY_VALUE);
      ShiftDoubleIndicatorBuffer(reversalBalance_H, Bars, ShiftedBars, EMPTY_VALUE);
      ShiftDoubleIndicatorBuffer(reversalBalance_L, Bars, ShiftedBars, EMPTY_VALUE);
      ShiftDoubleIndicatorBuffer(reversalBalance_C, Bars, ShiftedBars, EMPTY_VALUE);
   }

   // check data pumping on every tick so the breakout handler can skip errornous signals
   if (!__isTesting) IsPossibleDataPumping();

   // calculate start bar
   int startBar = Min(MaxBarsBack-1, ChangedBars-1, Bars-Periods);
   if (startBar < 0 && MaxBarsBack) return(logInfo("onTick(1)  Tick="+ Ticks +"  Bars="+ Bars +"  needed="+ Periods, ERR_HISTORY_INSUFFICIENT));
   if (!ValidBars) recorder.startTime = Time[startBar];

   // recalculate changed bars
   for (int bar=startBar; bar >= 0; bar--) {
      // reset the bar to update
      upperBand        [bar] = 0;
      lowerBand        [bar] = 0;
      upperCross       [bar] = 0;
      lowerCross       [bar] = 0;
      dimmed           [bar] = 0;
      trend            [bar] = 0;
      reversalCount    [bar] = 0;
      reversalBalance_O[bar] = EMPTY_VALUE;
      reversalBalance_H[bar] = EMPTY_VALUE;
      reversalBalance_L[bar] = EMPTY_VALUE;
      reversalBalance_C[bar] = EMPTY_VALUE;

      // recalculate Donchian Channel
      if (bar > 0) {
         upperBand[bar] = High[iHighest(NULL, NULL, MODE_HIGH, Periods, bar)];
         lowerBand[bar] =  Low[ iLowest(NULL, NULL, MODE_LOW,  Periods, bar)];
      }
      else {
         upperBand[0] = MathMax(upperBand[1], High[0]);
         lowerBand[0] = MathMin(lowerBand[1],  Low[0]);
      }

      // recalculate channel crossings
      if (upperBand[bar] > upperBand[bar+1] && upperBand[bar+1]) {
         upperCross[bar] = upperBand[bar+1] + Point;
      }
      if (lowerBand[bar] < lowerBand[bar+1]) {
         lowerCross[bar] = lowerBand[bar+1] - Point;
      }

      // whether the processed bar is a reversal bar (not whether the current tick triggered the reversal)
      bool isReversalBar = false, isDoubleCross = false, cross1_isReversalBar = false, cross1_isUpper = false;
      double firstCross = 0, lastCross = 0;

      // recalculate trend/reversal data
      // if no channel crossing
      if (!upperCross[bar] && !lowerCross[bar]) {
         int iTrend = trend[bar+1];
         trend        [bar] = iTrend + Sign(iTrend);        // increase trend if it was set
         reversalCount[bar] = reversalCount[bar+1];         // keep reversal counter (may be 0)
      }

      // if two channel crossings (upper and lower band crossed by the same bar)
      else if (upperCross[bar] && lowerCross[bar]) {
         isDoubleCross  = true;
         cross1_isUpper = !IsUpperCrossLast(bar);
         if (cross1_isUpper) {
            cross1_isReversalBar = ProcessUpperCross(bar);  // process both crossings in order
            isReversalBar        = ProcessLowerCross(bar);
            firstCross           = upperCross[bar];
            lastCross            = lowerCross[bar];
         }
         else {
            cross1_isReversalBar = ProcessLowerCross(bar);  // process both crossings in order
            isReversalBar        = ProcessUpperCross(bar);
            firstCross           = lowerCross[bar];
            lastCross            = upperCross[bar];
         }
      }

      // else a single channel crossing
      else if (!lowerCross[bar]) {
         isReversalBar = ProcessUpperCross(bar);
         lastCross     = upperCross[bar];
      }
      else {
         isReversalBar = ProcessLowerCross(bar);
         lastCross     = lowerCross[bar];
      }

      // update reversal balance
      if (TrackReversalBalance) {
         if (!UpdateReversalBalance(bar, isReversalBar, isDoubleCross, cross1_isUpper, reversalBalance_O, reversalBalance_H, reversalBalance_L, reversalBalance_C)) return(last_error);
      }

      // hide all non-reversal crossings
      if (!isReversalBar) {
         upperCross[bar] = 0;
         lowerCross[bar] = 0;
      }
      else if (isDoubleCross && !cross1_isReversalBar) {
         if (cross1_isUpper) upperCross[bar] = 0;           // hide the 1st crossing if not a reversal
         else                lowerCross[bar] = 0;
      }

      // dim filtered reversals
      if (isReversalBar && reversals.show && reversals.countFrom) {
         dimmed[bar] = lastCross;                           // hide all reversals

         bool showThisReversal = false;
         if (reversals.countFrom > 0 && reversalCount[bar] >= reversals.countFrom) {
            showThisReversal = true;                        // positive filter
         }
         if (reversals.countFrom < 0 && reversalCount[bar] <= reversals.countFrom) {
            showThisReversal = true;                        // negative filter
         }
         if (showThisReversal) {
            dimmed[bar] = 0;                                // unhide this reversal
            int count = reversals.countFrom;
            int prevReversalBar = bar;

            while (true) {                                  // unhide its predecessors
               iTrend = trend[prevReversalBar+1];
               if (!count || !iTrend) break;
               prevReversalBar += Abs(iTrend);
               dimmed[prevReversalBar] = 0;
               count -= Sign(reversals.countFrom);
            }
         }
      }

      if (last_error != NO_ERROR) return(last_error);
   }

   // chart legend, balance tracking, signaling
   if (__isChart && !__isSuperContext) {
      if (ShowChartLegend) UpdateChartLegend();

      // record reversal balance
      if (TrackReversalBalance) {
         if (!RecordReversalBalance()) return(last_error);
      }

      // detect channel widenings
      if (Sound.onChannelWidening && ChangedBars <= 2) {
         if (lastUpperBand && lastLowerBand) {
            int widening = 0;
            if (ChangedBars == 2) {
               if      (upperBand[1] > lastUpperBand+HalfPoint) widening = +1;
               else if (lowerBand[0] < lastLowerBand-HalfPoint) widening = -1;
               lastUpperBand = upperBand[1];
               lastLowerBand = lowerBand[1];
            }
            if      (widening > 0 || upperBand[0] > lastUpperBand+HalfPoint) onChannelWidening(D_LONG);
            else if (widening < 0 || lowerBand[0] < lastLowerBand-HalfPoint) onChannelWidening(D_SHORT);
         }
         lastUpperBand = upperBand[0];
         lastLowerBand = lowerBand[0];
      }
   }
   return(last_error);
}


/**
 * Process an incoming command.
 *
 * @param  string cmd    - command name
 * @param  string params - command parameters
 * @param  int    keys   - flags of pressed modifier keys
 *
 * @return bool - success status of the executed command
 */
bool onCommand(string cmd, string params, int keys) {
   if (cmd == "parameter") {
      if (params == "up")   return(ParameterStepper(STEP_UP,   keys));
      if (params == "down") return(ParameterStepper(STEP_DOWN, keys));
   }
   return(!logNotice("onCommand(1)  unsupported command: "+ DoubleQuoteStr(cmd +":"+ params +":"+ keys)));
}


/**
 * Update the reversal balance for the specified bar.
 *
 * @param  _In_    int    bar            - bar offset
 * @param  _In_    bool   isReversalBar  - whether the bar is a reversal bar
 * @param  _In_    bool   isDoubleCross  - whether a reversal is a double crossing
 * @param  _In_    bool   cross1_isUpper - whether the 1st of a double crossing is the upper cross
 * @param  _InOut_ double open []        - balance timeseries (passed by reference to simplify local var names)
 * @param  _InOut_ double high []        - ...
 * @param  _InOut_ double low  []        - ...
 * @param  _InOut_ double close[]        - ...
 *
 * @return bool - success status
 */
bool UpdateReversalBalance(int bar, bool isReversalBar, bool isDoubleCross, bool cross1_isUpper, double &open[], double &high[], double &low[], double &close[]) {
   isReversalBar  = (isReversalBar != 0);
   isDoubleCross  = (isDoubleCross != 0);
   cross1_isUpper = (cross1_isUpper != 0);

   open [bar] = close[bar+1];
   high [bar] = close[bar+1];
   low  [bar] = close[bar+1];
   close[bar] = close[bar+1];

   bool isPosition = (close[bar] != EMPTY_VALUE);

   // reversal bar, flip the position
   if (isReversalBar) {
      if (!isPosition) {
         open [bar] = 0;
         high [bar] = 0;
         low  [bar] = 0;
         close[bar] = 0;
      }

      if (!isDoubleCross) {
         // regular crossing
         if (trend[bar] > 0) {                                                // upper crossing, switch to long
            if (isPosition) {
               open [bar]  = close[bar+1];
               close[bar] -= (upperCross[bar]-Point - Close[bar+1]);          // close short position
               close[bar] += (Close[bar] - (upperCross[bar]-Point));          // open new long position
               high [bar]  = MathMax(open[bar], close[bar]);
               low  [bar]  = MathMin(open[bar], close[bar]);                  // the exact intra-bar path is unknown
            }
            else {
               high [bar] = ( High[bar] - (upperCross[bar]-Point));           // open long position
               low  [bar] = (  Low[bar] - (upperCross[bar]-Point));
               close[bar] = (Close[bar] - (upperCross[bar]-Point));
            }
         }
         else /*trend[bar] < 0*/ {                                            // lower crossing, switch to short
            if (isPosition) {
               open [bar]  = close[bar+1];
               close[bar] += (lowerCross[bar]+Point - Close[bar+1]);          // close long position
               close[bar] += (lowerCross[bar]+Point - Close[bar]);            // open new short position
               high [bar]  = MathMax(open[bar], close[bar]);
               low  [bar]  = MathMin(open[bar], close[bar]);                  // the exact intra-bar path is unknown
            }
            else {
               high [bar] = (lowerCross[bar]+Point -   Low[bar]);             // open short position
               low  [bar] = (lowerCross[bar]+Point -  High[bar]);
               close[bar] = (lowerCross[bar]+Point - Close[bar]);
            }
         }
      }
      else {
         // double crossing
         if (cross1_isUpper) {
            if (isPosition) {
               open [bar]  = close[bar+1];
               close[bar] -= (upperCross[bar]-Point - Close[bar+1]);          // close existing short position
            }
            close[bar] -= (upperCross[bar]-Point - (lowerCross[bar]+Point));  // open new long position and immediately close it
            close[bar] += (lowerCross[bar]+Point - Close[bar]);               // open new short position
         }
         else /*cross1_isLower*/ {
            if (isPosition) {
               open [bar]  = close[bar+1];
               close[bar] += (lowerCross[bar]+Point - Close[bar+1]);          // close existing long position
            }
            close[bar] -= (upperCross[bar]-Point - (lowerCross[bar]+Point));  // open new short position and immediately close it
            close[bar] += (Close[bar] - (upperCross[bar]-Point));             // open new long position
         }

         high[bar] = MathMax(open[bar], close[bar]);                          // the exact intra-bar path is unknown
         low [bar] = MathMin(open[bar], close[bar]);
      }
   }

   // normal bar without a crossing, update an existing position
   else if (isPosition) {
      open[bar] = close[bar+1];

      if (trend[bar] > 0) {
         close[bar] += (Close[bar] - Close[bar+1]);
         high [bar]  = close[bar] + (High[bar] - Close[bar]);
         low  [bar]  = close[bar] + ( Low[bar] - Close[bar]);
      }
      else /*trend[bar] < 0*/ {
         close[bar] -= (Close[bar] - Close[bar+1]);
         high [bar]  = close[bar] - ( Low[bar] - Close[bar]);
         low  [bar]  = close[bar] - (High[bar] - Close[bar]);
      }
   }

   // normal bar without a position (before first reversal near MaxBarsBack)
   //else {}

   // adjust the price base for the timeseries to always be positive
   double hstValue = low[bar] + recorder.priceBase;
   while (hstValue <= 0) {
      recorder.priceBase *= 10;
      hstValue = low[bar] + recorder.priceBase;
   }
   return(true);
}


/**
 * Record a timeseries with the reversal balance.
 *
 * @return bool - success status
 */
bool RecordReversalBalance() {
   if (!recorder.initialized) {
      // create symbol and group
      recorder.symbol       = Symbol() +".db";
      recorder.symbolDescr  = "Donchian reversal balance";
      recorder.group        = "Donch. balance";          // max length: 15
      recorder.hstDirectory = Recorder_GetHstDirectory();
      recorder.hstFormat    = Recorder_GetHstFormat();
      if (last_error != NULL) return(false);

      if (!IsRawSymbol(recorder.symbol, recorder.hstDirectory)) {
         int symbolId = CreateRawSymbol(recorder.symbol, recorder.symbolDescr, recorder.group, pDigits, AccountCurrency(), AccountCurrency(), recorder.hstDirectory);
         if (symbolId < 0) return(false);
      }
      recorder.initialized = true;
   }

   int startBar = 0, flags = HST_FILL_GAPS|HST_BUFFER_TICKS;
   double open, high, low, close;

   if (ChangedBars > 2) {                                // rewrite the full history (intentionally skip rewriting bar 1 on BarOpen)
      if (recorder.hSet > 0) {
         int tmp = recorder.hSet;
         recorder.hSet = NULL;
         if (!HistorySet1.Close(tmp)) return(false);     // TODO: HistorySet.Create() should auto-close an open set but errors
      }
      startBar = iBarShiftNext(NULL, NULL, recorder.startTime);
   }

   if (recorder.hSet <= 0) {
      recorder.hSet = HistorySet1.Create(recorder.symbol, recorder.symbolDescr, pDigits, recorder.hstFormat, recorder.hstDirectory);
      if (!recorder.hSet) return(false);
   }

   for (int bar=startBar; bar >= 0; bar--) {
      open  = reversalBalance_O[bar];
      high  = reversalBalance_H[bar];
      low   = reversalBalance_L[bar];
      close = reversalBalance_C[bar];
      if (close >= EMPTY_VALUE) continue;

      if (!HistorySet1.AddTick(recorder.hSet, Time[bar], open + recorder.priceBase, flags)) return(false);
      if (!HistorySet1.AddTick(recorder.hSet, Time[bar], high + recorder.priceBase, flags)) return(false);
      if (!HistorySet1.AddTick(recorder.hSet, Time[bar], low  + recorder.priceBase, flags)) return(false);
      if (bar == 0) {
         flags &= ~HST_BUFFER_TICKS;                     // disable the tick buffer on bar 0 (for realtime updates)
      }
      if (!HistorySet1.AddTick(recorder.hSet, Time[bar], close + recorder.priceBase, flags)) return(false);
   }
   return(true);
}


/**
 * Resolve the history directory for recorded timeseries.
 *
 * @return string - directory or an empty string in case of errors
 */
string Recorder_GetHstDirectory() {
   string section = "SignalPerformance";
   string key = "HistoryDirectory", sValue="";

   if (IsConfigKey(section, key)) {
      sValue = GetConfigString(section, key, "");
   }
   if (!StringLen(sValue)) return(_EMPTY_STR(catch("Recorder_GetHstDirectory(1)  missing config value ["+ section +"]->"+ key, ERR_INVALID_CONFIG_VALUE)));
   return(sValue);
}


/**
 * Resolve the history format for recorded timeseries.
 *
 * @return int - history format or NULL (0) in case of errors
 */
int Recorder_GetHstFormat() {
   string section = "SignalPerformance";
   string key = "HistoryFormat", sValue="";

   if (IsConfigKey(section, key)) {
      int iValue = GetConfigInt(section, key, 0);
   }
   if (iValue!=400 && iValue!=401) return(!catch("Recorder_GetHstFormat(1)  invalid config value ["+ section +"]->"+ key +": "+ iValue +" (must be 400 or 401)", ERR_INVALID_CONFIG_VALUE));
   return(iValue);
}


/**
 * Step up/down input parameter "Periods".
 *
 * @param  int direction - STEP_UP | STEP_DOWN
 * @param  int keys      - modifier keys
 *
 * @return bool - success status
 */
bool ParameterStepper(int direction, int keys) {
   if (direction!=STEP_UP && direction!=STEP_DOWN) return(!catch("ParameterStepper(1)  invalid parameter direction: "+ direction, ERR_INVALID_PARAMETER));

   int step = Periods.Step;
   if (!step || Periods + direction*step < 2) {       // stop if parameter limit reached
      PlaySoundEx("Plonk.wav");
      return(false);
   }
   if (direction == STEP_UP) Periods += step;
   else                      Periods -= step;

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

   int waitPeriod = 20 * SECONDS;         // TODO: review this seemingly strange implementation
   datetime now = GetGmtTime();
   bool isPumping = true;

   if (now > skipSignals) skipSignals = 0;
   if (!skipSignals) {
      if (now > lastTick + waitPeriod) skipSignals = now + waitPeriod;
      else                             isPumping = false;
   }
   lastTick = now;
   return(isPumping);
}


/**
 * Whether a bar crossing both channel bands crossed the upper band last. The result is just a "best guess".
 *
 * @param  int bar - bar offset
 *
 * @return bool
 */
bool IsUpperCrossLast(int bar) {
   if (!bar) logInfo("IsUpperCrossLast(1)  bar=0  we must not guess");      // TODO

   double ho = High [bar] - Open [bar];
   double ol = Open [bar] - Low  [bar];
   double hc = High [bar] - Close[bar];
   double cl = Close[bar] - Low  [bar];

   double minOpen  = MathMin(ho, ol);
   double minClose = MathMin(hc, cl);

   if (minOpen < minClose) {
      return(ho > ol);
   }
   return(hc < cl);
}


/**
 * Update buffers at the specified bar offset after an upper channel band crossing. If bar 0 (zero) crosses the upper band
 * this function will be called for all following ticks of the bar, even for ticks below the crossing level.
 *
 * @param  int bar - offset
 *
 * @return bool - whether the bar is a reversal bar (not whether the current tick triggered the reversal)
 */
bool ProcessUpperCross(int bar) {
   bool isReversalBar = false;

   if (!trend[bar]) {                                       // 1st crossing
      if (trend[bar+1] > 0) {
         int iTrend = trend[bar+1];
         trend        [bar] = iTrend + 1;
         reversalCount[bar] = reversalCount[bar+1];         // keep reversal counter
      }
      else if (trend[bar+1] < 0) {
         trend[bar] = 1;

         // resolve profitability of the finished short section
         int    startBar   = bar - trend[bar+1];
         double startPrice = lowerCross[startBar] + Point;
         double endPrice   = upperCross[bar] - Point;
         if (!lowerCross[startBar]) return(!catch("ProcessUpperCross(1)  bar="+ bar +"|"+ TimeToStr(Time[bar]) +"  missing trend start price: start bar="+ startBar +"|"+ TimeToStr(Time[startBar]) +"  lowerCross["+ startBar +"]=0", ERR_ILLEGAL_STATE));

         if      (startPrice-HalfPoint > endPrice) reversalCount[bar] = Max(reversalCount[bar+1], 0) + 1;   // winner
         else if (startPrice+HalfPoint < endPrice) reversalCount[bar] = Min(reversalCount[bar+1], 0) - 1;   // loser
         else                                      reversalCount[bar] = reversalCount[bar+1];               // scratch
         isReversalBar = true;
      }
      else /*trend[bar+1] == 0*/ {                          // a cross without previous reversal (near MaxBarsBack)
         trend        [bar] = 1;
         reversalCount[bar] = 0;
         isReversalBar = true;
      }
   }
   else {                                                   // 2nd (double) crossing
      if (trend[bar] > 0) return(!catch("ProcessUpperCross(2)  bar="+ bar +"|"+ TimeToStr(Time[bar]) +"  unexpected 2nd upper cross: trend["+ (bar+1) +"]="+ _int(trend[bar+1]) +"  trend["+ bar +"]="+ _int(trend[bar]), ERR_ILLEGAL_STATE));
      trend        [bar] = 1;
      reversalCount[bar] = Min(reversalCount[bar], 0) - 1;  // loser
      isReversalBar = true;
   }

   // detect new reversals (only the first occurrence)
   bool isNewReversal = false;
   static datetime lastReversalTime;
   static double   lastReversalPrice;

   if (isReversalBar && ChangedBars <= 2) {
      if (Time[bar] != lastReversalTime || NE(upperCross[bar], lastReversalPrice, Digits)) {
         isNewReversal     = true;
         lastReversalTime  = Time[bar];
         lastReversalPrice = upperCross[bar];
      }
   }

   // handle new reversals
   if (isNewReversal) {
      // skip signaling if the filter condition doesn't match
      string sFilter = "";
      if (reversals.show && reversals.countFrom) {
         if (reversals.countFrom > 0 && reversalCount[bar] < reversals.countFrom) return(isReversalBar);
         if (reversals.countFrom < 0 && reversalCount[bar] > reversals.countFrom) return(isReversalBar);
         sFilter = "count: "+ NumberToStr(reversalCount[bar], "+.") +", ";
      }
      string sLevel = NumberToStr(upperCross[bar], PriceFormat);

      // log reversal
      if (IsLogInfo()) {
         bool logReversal = true;
         if (!__isSuperContext && !__isTesting) {           // once per terminal
            int hWndTerminal = GetTerminalMainWindow();
            string eventName = "rsf::"+ StdSymbol() +","+ PeriodDescription() +"."+ WindowExpertName() +"("+ Periods +")" +".ProcessUpperCross("+ sLevel +")."+ TimeToStr(Time[bar]);
            logReversal = !GetWindowPropertyA(hWndTerminal, eventName);
            SetWindowPropertyA(hWndTerminal, eventName, 1);
         }
         if (logReversal) logInfo("onReversal(P="+ Periods +")  reversal up ("+ sFilter +"level: "+ sLevel +")");
      }

      // signal reversal
      if (Signal.onReversal) {
         onReversal(bar, D_LONG, sFilter, sLevel);
      }
   }
   return(isReversalBar);
}


/**
 * Update buffers at the specified bar offset after a lower channel band crossing. If bar 0 (zero) crosses the lower band
 * this function will be called for all following ticks of the bar, even for ticks above the crossing level.
 *
 * @param  int bar - offset
 *
 * @return bool - whether the bar is a reversal bar (not whether the current tick triggered the reversal)
 */
bool ProcessLowerCross(int bar) {
   bool isReversalBar = false;

   if (!trend[bar]) {                                       // 1st crossing
      if (trend[bar+1] < 0) {
         int iTrend = trend[bar+1];
         trend        [bar] = iTrend - 1;
         reversalCount[bar] = reversalCount[bar+1];         // keep reversal counter
      }
      else if (trend[bar+1] > 0) {
         trend[bar] = -1;

         // resolve profitability of the finished long section
         int    startBar   = bar + trend[bar+1];
         double startPrice = upperCross[startBar] - Point;
         double endPrice   = lowerCross[bar] + Point;
         if (!upperCross[startBar]) return(!catch("ProcessLowerCross(1)  bar="+ bar +"|"+ TimeToStr(Time[bar]) +"  missing trend start price: start bar="+ startBar +"|"+ TimeToStr(Time[startBar]) +"  upperCross["+ startBar +"]=0", ERR_ILLEGAL_STATE));

         if      (startPrice+HalfPoint < endPrice) reversalCount[bar] = Max(reversalCount[bar+1], 0) + 1;   // winner
         else if (startPrice-HalfPoint > endPrice) reversalCount[bar] = Min(reversalCount[bar+1], 0) - 1;   // loser
         else                                      reversalCount[bar] = reversalCount[bar+1];               // scratch
         isReversalBar = true;
      }
      else /*trend[bar+1] == 0*/ {                          // a cross without previous reversal (near MaxBarsBack)
         trend        [bar] = -1;
         reversalCount[bar] = 0;
         isReversalBar = true;
      }
   }
   else {                                                   // 2nd (double) crossing
      if (trend[bar] < 0) return(!catch("ProcessLowerCross(2)  bar="+ bar +"|"+ TimeToStr(Time[bar]) +"  unexpected 2nd lower cross: trend["+ (bar+1) +"]="+ _int(trend[bar+1]) +"  trend["+ bar +"]="+ _int(trend[bar]), ERR_ILLEGAL_STATE));
      trend        [bar] = -1;
      reversalCount[bar] = Min(reversalCount[bar], 0) - 1;  // loser
      isReversalBar = true;
   }

   // detect new reversals (only the first occurrence)
   bool isNewReversal = false;
   static datetime lastReversalTime;
   static double   lastReversalPrice;

   if (isReversalBar && ChangedBars <= 2) {
      if (Time[bar] != lastReversalTime || NE(lowerCross[bar], lastReversalPrice, Digits)) {
         isNewReversal     = true;
         lastReversalTime  = Time[bar];
         lastReversalPrice = lowerCross[bar];
      }
   }

   // handle new reversals
   if (isNewReversal) {
      // skip signaling if the filter condition doesn't match
      string sFilter = "";
      if (reversals.show && reversals.countFrom) {
         if (reversals.countFrom > 0 && reversalCount[bar] < reversals.countFrom) return(isReversalBar);
         if (reversals.countFrom < 0 && reversalCount[bar] > reversals.countFrom) return(isReversalBar);
         sFilter = "count: "+ NumberToStr(reversalCount[bar], "+.") +", ";
      }
      string sLevel = NumberToStr(lowerCross[bar], PriceFormat);

      // log reversal
      if (IsLogInfo()) {
         bool logReversal = true;
         if (!__isSuperContext && !__isTesting) {        // once per terminal
            int hWndTerminal = GetTerminalMainWindow();
            string eventName = "rsf::"+ StdSymbol() +","+ PeriodDescription() +"."+ WindowExpertName() +"("+ Periods +")" +".ProcessLowerCross("+ sLevel +")."+ TimeToStr(Time[bar]);
            logReversal = !GetWindowPropertyA(hWndTerminal, eventName);
            SetWindowPropertyA(hWndTerminal, eventName, 1);
         }
         if (logReversal) logInfo("onReversal(P="+ Periods +")  reversal down ("+ sFilter +"level: "+ sLevel +")");
      }

      // signal reversal
      if (Signal.onReversal) {
         onReversal(bar, D_SHORT, sFilter, sLevel);
      }
   }
   return(isReversalBar);
}


/**
 * Event handler for new channel reversals (on current tick).
 *
 * @param  int    bar       - bar which triggered the reversal: 0 or 1
 * @param  int    direction - reversal direction: D_LONG | D_SHORT
 * @param  string sFilter   - the filter condition (if enabled)
 * @param  string sLevel    - the price level of the reversal (cross of upper/lower channel band)
 *
 * @return bool - success status
 */
bool onReversal(int bar, int direction, string sFilter, string sLevel) {
   if (direction!=D_LONG && direction!=D_SHORT) return(!catch("onReversal(1)  invalid parameter direction: "+ direction, ERR_INVALID_PARAMETER));
   if (IsPossibleDataPumping())                 return(true);

   // skip the signal if it was already handled elsewhere
   string sPeriod    = PeriodDescription();
   string sName      = WindowExpertName() +"("+ Periods +")";
   string sDirection = ifString(direction==D_LONG, "up", "down");
   string eventName  = "rsf::"+ StdSymbol() +","+ sPeriod +"."+ sName +".onReversal("+ sDirection +")."+ TimeToStr(Time[bar]), propertyName = "";
   string message    = Symbol() +","+ sPeriod +": "+ sName +" reversal "+ sDirection +" ("+ sFilter +"level: "+ sLevel +")";
   string localTime  = TimeToStr(TimeLocalEx("onReversal(2)"), TIME_MINUTES|TIME_SECONDS);
   string accountAlias = GetAccountAlias();

   int hWndTerminal = GetTerminalMainWindow(), hWndDesktop = GetDesktopWindow();
   bool eventAction;

   // sound: once per system
   if (signal.onReversal.sound) {
      eventAction = true;
      if (!__isTesting) {
         propertyName = eventName +"|sound";
         eventAction = !GetWindowPropertyA(hWndDesktop, propertyName);
         SetWindowPropertyA(hWndDesktop, propertyName, 1);
      }
      if (eventAction) {
         int error = PlaySoundEx(ifString(direction==D_LONG, Signal.onReversal.SoundUp, Signal.onReversal.SoundDown));
         if (!error) lastSoundSignal = GetTickCount();
      }
   }

   // alert: once per terminal
   if (signal.onReversal.alert) {
      eventAction = true;
      if (!__isTesting) {
         propertyName = eventName +"|alert";
         eventAction = !GetWindowPropertyA(hWndTerminal, propertyName);
         SetWindowPropertyA(hWndTerminal, propertyName, 1);
      }
      if (eventAction) Alert(message);
   }

   // mail: once per system
   if (signal.onReversal.mail) {
      eventAction = true;
      if (!__isTesting) {
         propertyName = eventName +"|mail";
         eventAction = !GetWindowPropertyA(hWndDesktop, propertyName);
         SetWindowPropertyA(hWndDesktop, propertyName, 1);
      }
      if (eventAction) SendEmail("", "", message, message + NL +"("+ localTime +", "+ accountAlias +")");
   }

   // Telegram: once per system
   if (signal.onReversal.telegram) {
      eventAction = true;
      if (!__isTesting) {
         propertyName = eventName +"|telegram";
         eventAction = !GetWindowPropertyA(hWndDesktop, propertyName);
         SetWindowPropertyA(hWndDesktop, propertyName, 1);
      }
      if (eventAction) SendTelegramMessage("signal", message + NL +"("+ localTime +", "+ accountAlias +")");
   }
   return(!catch("onReversal(3)"));
}


/**
 * Event handler signaling channel widenings.
 *
 * @param  int direction - crossing direction: D_LONG | D_SHORT
 *
 * @return bool - success status
 */
bool onChannelWidening(int direction) {
   if (direction!=D_LONG && direction!=D_SHORT) return(!catch("onChannelWidening(1)  invalid parameter direction: "+ direction, ERR_INVALID_PARAMETER));

   // TODO: skip the signal if it already has been signaled elsewhere

   if (lastSoundSignal+2000 < GetTickCount()) {       // at least 2 sec pause between consecutive sound signals
      int error = PlaySoundEx(ifString(direction==D_LONG, Sound.onNewChannelHigh, Sound.onNewChannelLow));
      if (!error) lastSoundSignal = GetTickCount();
   }
   return(!catch("onChannelWidening(2)"));
}


/**
 * Update the chart legend.
 */
void UpdateChartLegend() {
   static int lastTrend, lastTime, lastAccount;

   // update on full recalculation or if indicator name, trend, current bar or the account changed
   if (!ValidBars || trend[0]!=lastTrend || Time[0]!=lastTime || AccountNumber()!=lastAccount) {
      string sFilter = "", sTrend = "";
      if (reversals.show && reversals.countFrom) {
         sFilter = "   filter("+ NumberToStr(reversals.countFrom, "+.") +")";
      }
      else {
         sTrend = "   "+ NumberToStr(trend[0], "+.");
      }
      string sReversal = "   next rev. @" + NumberToStr(ifDouble(trend[0] < 0, upperBand[0]+Point, lowerBand[0]-Point), PriceFormat);
      string sSignal   = ifString(Signal.onReversal || Sound.onChannelWidening, "  "+ legendInfo, "");
      string text      = StringConcatenate(indicatorName, sTrend, sFilter, sReversal, sSignal);

      color clr = Reversal.Color;
      if (clr == CLR_NONE) {
         clr = ifInt(trend[0] > 0, Channel.UpperColor, Channel.LowerColor);
      }
      if      (clr == Aqua        ) clr = DodgerBlue;
      else if (clr == Gold        ) clr = Orange;
      else if (clr == LightSkyBlue) clr = C'94,174,255';
      else if (clr == Lime        ) clr = LimeGreen;
      else if (clr == Yellow      ) clr = Orange;

      ObjectSetText(legendLabel, text, 9, "Arial Fett", clr);
      int error = GetLastError();
      if (error && error!=ERR_OBJECT_DOES_NOT_EXIST) catch("UpdateChartLegend(1)", error);     // on ObjectDrag or opened "Properties" dialog

      lastTrend   = trend[0];
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

   indicatorName = WindowExpertName() +"("+ Periods + ifString(Periods.Step, ":"+ Periods.Step, "") +")";
   shortName     = "Donchian("+ Periods +")";
   IndicatorShortName(shortName);

   IndicatorBuffers(indicator_buffers);
   SetIndexBuffer(MODE_UPPER_BAND,      upperBand    ); SetIndexEmptyValue(MODE_UPPER_BAND,      0); SetIndexLabel(MODE_UPPER_BAND,      shortName +" upper band");
   SetIndexBuffer(MODE_LOWER_BAND,      lowerBand    ); SetIndexEmptyValue(MODE_LOWER_BAND,      0); SetIndexLabel(MODE_LOWER_BAND,      shortName +" lower band");
   SetIndexBuffer(MODE_REVERSAL_LONG,   upperCross   ); SetIndexEmptyValue(MODE_REVERSAL_LONG,   0); SetIndexLabel(MODE_REVERSAL_LONG,   shortName +" reversal up");
   SetIndexBuffer(MODE_REVERSAL_SHORT,  lowerCross   ); SetIndexEmptyValue(MODE_REVERSAL_SHORT,  0); SetIndexLabel(MODE_REVERSAL_SHORT,  shortName +" reversal down");
   SetIndexBuffer(MODE_REVERSAL_DIMMED, dimmed       ); SetIndexEmptyValue(MODE_REVERSAL_DIMMED, 0); SetIndexLabel(MODE_REVERSAL_DIMMED, NULL);
   SetIndexBuffer(MODE_TREND,           trend        ); SetIndexEmptyValue(MODE_TREND,           0); SetIndexLabel(MODE_TREND,           shortName +" trend");
   SetIndexBuffer(MODE_REVERSAL_COUNT,  reversalCount); SetIndexEmptyValue(MODE_REVERSAL_COUNT,  0); SetIndexLabel(MODE_REVERSAL_COUNT,  shortName +" reversal count");
   IndicatorDigits(Digits);

   SetIndexStyle(MODE_UPPER_BAND, DRAW_LINE, EMPTY, EMPTY, Channel.UpperColor);
   SetIndexStyle(MODE_LOWER_BAND, DRAW_LINE, EMPTY, EMPTY, Channel.LowerColor);

   int drawType = ifInt(reversals.show && Reversal.Width, DRAW_ARROW, DRAW_NONE);
   int drawWidth = Reversal.Width - 1;                  // minus 1 to map valid symbol size "0" to a positive user value
   SetIndexStyle(MODE_REVERSAL_LONG,   drawType, EMPTY, drawWidth, colorOr(Reversal.Color, Channel.UpperColor)); SetIndexArrow(MODE_REVERSAL_LONG,   reversals.symbol);
   SetIndexStyle(MODE_REVERSAL_SHORT,  drawType, EMPTY, drawWidth, colorOr(Reversal.Color, Channel.LowerColor)); SetIndexArrow(MODE_REVERSAL_SHORT,  reversals.symbol);
   SetIndexStyle(MODE_REVERSAL_DIMMED, drawType, EMPTY, drawWidth, indicator_color5);                            SetIndexArrow(MODE_REVERSAL_DIMMED, reversals.symbol);

   SetIndexStyle(MODE_TREND,          DRAW_NONE);
   SetIndexStyle(MODE_REVERSAL_COUNT, DRAW_NONE);

   if (redraw) WindowRedraw();
   return(!catch("SetIndicatorOptions(1)"));
}


/**
 * Store the status of the parameter stepper in the chart (for init cyles, template reloads and terminal restarts).
 *
 * @return bool - success status
 */
bool StoreStatus() {
   if (__isChart && Periods.Step) {
      string prefix = "rsf."+ WindowExpertName() +".";
      Chart.StoreInt(prefix +"Periods", Periods);
   }
   return(catch("StoreStatus(1)"));
}


/**
 * Restore the status of the parameter stepper from the chart.
 *
 * @return bool - success status
 */
bool RestoreStatus() {
   if (!__isChart) return(true);
   string prefix = "rsf."+ WindowExpertName() +".";

   int iValue;
   if (Chart.RestoreInt(prefix +"Periods", iValue)) {    // restore and remove it
      if (Periods.Step > 0) {                            // apply if stepper is still active
         if (iValue >= 2) Periods = iValue;              // silent validation
      }
   }
   return(!catch("RestoreStatus(1)"));
}


/**
 * Parse and validate input `ShowReversals`.
 *
 * @param  _InOut_ string value         - input value, format: "on | off | +N | -N"
 * @param  _Out_   bool   showReversals - result: whether to show any reversals
 * @param  _Out_   int    countFrom     - result: min. reversal count of the reversals to show
 *
 * @return bool - validation success status
 */
bool ValidateShowReversals(string &value, bool &showReversals, int &countFrom) {
   showReversals = false;
   countFrom = 0;

   string sValues[], sValue = value;
   if (Explode(sValue, "*", sValues, 2) > 1) {
      int size = Explode(sValues[0], "|", sValues, NULL);
      sValue = sValues[size-1];
   }
   sValue = StrToLower(StrTrim(sValue));

   if (sValue == "" || sValue == "on" || sValue == "all" ) {
      showReversals = true;
      countFrom = 0;
      sValue = "on";
   }
   else if (sValue == "off" || sValue == "0") {
      showReversals = false;
      sValue = "off";
   }
   else if (StrIsInteger(sValue)) {
      showReversals = true;
      countFrom = StrToInteger(sValue);
   }
   else return(false);

   value = sValue;
   return(true);
}


/**
 * Return a string representation of all input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("Periods=",                     Periods                                     +";"+ NL,
                            "Periods.Step=",                Periods.Step                                +";"+ NL,

                            "Channel.UpperColor=",          ColorToStr(Channel.UpperColor)              +";"+ NL,
                            "Channel.LowerColor=",          ColorToStr(Channel.LowerColor)              +";"+ NL,

                            "ShowReversals=",               DoubleQuoteStr(ShowReversals)               +";"+ NL,
                            "Reversal.Symbol=",             DoubleQuoteStr(Reversal.Symbol)             +";"+ NL,
                            "Reversal.Width=",              Reversal.Width                              +";"+ NL,
                            "Reversal.Color=",              ColorToStr(Reversal.Color)                  +";"+ NL,

                            "ShowChartLegend=",             BoolToStr(ShowChartLegend)                  +";"+ NL,
                            "MaxBarsBack=",                 MaxBarsBack                                 +";"+ NL,

                            "Signal.onReversal=",           BoolToStr(Signal.onReversal)                +";"+ NL,
                            "Signal.onReversal.Types=",     DoubleQuoteStr(Signal.onReversal.Types)     +";"+ NL,
                            "Signal.onReversal.SoundUp=",   DoubleQuoteStr(Signal.onReversal.SoundUp)   +";"+ NL,
                            "Signal.onReversal.SoundDown=", DoubleQuoteStr(Signal.onReversal.SoundDown) +";"+ NL,

                            "Sound.onChannelWidening=",     BoolToStr(Sound.onChannelWidening)          +";"+ NL,
                            "Sound.onNewChannelHigh=",      DoubleQuoteStr(Sound.onNewChannelHigh)      +";"+ NL,
                            "Sound.onNewChannelLow=",       DoubleQuoteStr(Sound.onNewChannelLow)       +";"+ NL,

                            "TrackReversalBalance=",        BoolToStr(TrackReversalBalance)             +";"+ NL,
                            "TrackReversalBalance.Symbol=", DoubleQuoteStr(TrackReversalBalance.Symbol) +";")
   );

   // suppress compiler warnings
   icDonchianChannel(NULL, NULL, NULL, NULL);
}
