/**
 * A non-repainting ZigZag indicator suitable for automation
 *
 *
 * MetaQuotes' ZigZag indicator is flawed and poorly implemented. It repaints the calculated swing extremes, at times even
 * two swings back. Also it cannot be used for automation. This indicator doesn't have such issues. Once the ZigZag direction
 * has changed, the change is permanent.
 *
 * Internally the indicator uses a Donchian channel for calculation. The indicator draws vertical line segments if a single
 * price bar crosses both upper and lower Donchian channel. Additionally, it can display the trail of a ZigZag leg as it
 * develops over time. The display can be switched between full ZigZag lines or only swing extremes (aka ZigZag semaphores).
 *
 * The indicator allows manual stepping of the ZigZag period via hotkey and supports multiple signaling modes.
 *
 *
 * Input parameters
 * ----------------
 *  • ZigZag.Periods:                Look-back periods of the Donchian channel.
 *  • ZigZag.Periods.Step:           Controls parameter "ZigZag.Periods" via keyboard. If non-zero it defines the step size
 *                                   of the parameter stepper. If 0 (zero) the parameter stepper is disabled.
 *  • ZigZag.Type:                   Whether to display the ZigZag line or ZigZag semaphores.
 *  • ZigZag.Semaphores.Symbol:      Graphic symbol used for ZigZag semaphores.
 *  • ZigZag.Width:                  The ZigZag's line width or semaphore size.
 *  • ZigZag.Color:                  Color of ZigZag line or semaphores.
 *
 *  • Donchian.ShowChannel:          Whether to display the internal Donchian channel.
 *  • Donchian.Channel.UpperColor:   Color of upper Donchian channel band.
 *  • Donchian.Channel.LowerColor:   Color of lower Donchian channel band.
 *
 *  • Donchian.ShowCrossings:        Which Donchian channel crossings to display, one of:
 *                                    "off":   No crossings are displayed.
 *                                    "first": Only the first crossing is displayed (the moment a new ZigZag leg appears).
 *                                    "all":   All crossings are displayed. Displays the trail of a ZigZag leg as it develops over time.
 *  • Donchian.Crossing.Symbol:      Graphic symbol used for Donchian channel crossings.
 *  • Donchian.Crossing.Width:       Size of displayed Donchian channel crossings.
 *  • Donchian.Crossing.Color:       Custom color of channel crossings (default: color of channel bands).
 *
 *  • ShowChartLegend:               Whether do display the chart legend.
 *  • MaxBarsBack:                   Maximum number of bars back to calculate the indicator for (affects performance).
 *
 *  • Signal.onReversal:             Whether to signal ZigZag reversals (the moment a new ZigZag leg appears).
 *  • Signal.onReversal.Types:       Signaling methods, can be a combination of "sound", "alert" and/or "mail".
 *
 *  • Signal.onBreakout:             Whether to signal ZigZag breakouts (a ZigZag leg exceeding the previous ZigZag leg).
 *  • Signal.onBreakout.Types:       Signaling methods, can be a combination of "sound", "alert" and/or "mail".
 *
 *  • Signal.Sound.Up:               Sound file for signals to the upside.
 *  • Signal.Sound.Down:             Sound file for signals to the downside.
 *
 *  • Sound.onChannelWidening:       Whether to play a sound on Donchian channel widening (channel crossings).
 *  • Sound.onNewChannelHigh:        Sound file for channel widenings to the upside.
 *  • Sound.onNewChannelLow:         Sound file for channel widenings to the downside.
 *
 *  • TrackSignalPerformance:        Whether to track the performance of the reversal signal.
 *  • TrackSignalPerformance.Since:  Start time to track signal performance from (default: MaxBarsBack).
 *  • TrackSignalPerformance.Symbol: Custom symbol to use for performance tracking (default: auto-generated).
 *
 *  • AutoConfiguration:             If enabled all input parameters may use predefined defaults from the configuration.
 *
 *
 * TODO:
 *  - convert TrackSignalPerformance.Since to string
 *  - remove debug code
 *  - once finished, update logic in usage locations of icZigZag()
 *
 *  - calculate/display ZigZag zero balance projections
 *  - fix triple-crossing at GBPJPY,M5 2023.12.18 00:00, ZigZag(20)
 *  - keep bar status in IsUpperCrossLast()
 *  - document usage of iCustom()
 */
#include <rsf/stddefines.mqh>
int   __InitFlags[];
int __DeinitFlags[];

///////////////////////////////////////////////////// Input parameters //////////////////////////////////////////////////////

extern string   ___a__________________________ = "=== ZigZag settings ===";
extern int      ZigZag.Periods                 = 40;                           // lookback periods of the Donchian channel
extern int      ZigZag.Periods.Step            = 0;                            // step size for parameter stepper via hotkey
extern string   ZigZag.Type                    = "Lines* | Semaphores";        // ZigZag lines or reversal points (can be shortened)
extern string   ZigZag.Semaphores.Symbol       = "dot* | thin-ring | ring | thick-ring";
extern int      ZigZag.Width                   = 2;
extern color    ZigZag.Color                   = Blue;

extern string   ___b__________________________ = "=== Donchian settings ===";
extern bool     Donchian.ShowChannel           = true;                         // whether to display the Donchian channel
extern color    Donchian.Channel.UpperColor    = Blue;
extern color    Donchian.Channel.LowerColor    = Magenta;
extern string   Donchian.ShowCrossings         = "off | first* | all";         // which channel crossings to display
extern string   Donchian.Crossing.Symbol       = "dot | thin-ring | ring | thick-ring*";
extern int      Donchian.Crossing.Width        = 1;
extern color    Donchian.Crossing.Color        = CLR_NONE;

extern string   ___c__________________________ = "=== Display settings ===";
extern bool     ShowChartLegend                = true;
extern int      MaxBarsBack                    = 10000;                          // max. values to calculate (-1: all available)

extern string   ___d__________________________ = "=== Signaling ===";
extern bool     Signal.onReversal              = false;                          // signal ZigZag reversals (first Donchian channel crossing)
extern string   Signal.onReversal.Types        = "sound* | alert | mail";

extern bool     Signal.onBreakout              = false;                          // signal ZigZag breakouts
extern string   Signal.onBreakout.Types        = "sound* | alert | mail";

extern string   Signal.Sound.Up                = "Signal Up.wav";
extern string   Signal.Sound.Down              = "Signal Down.wav";

extern bool     Sound.onChannelWidening        = false;                          // signal Donchian channel widenings
extern string   Sound.onNewChannelHigh         = "Price Advance.wav";
extern string   Sound.onNewChannelLow          = "Price Decline.wav";

extern string   ___e__________________________ = "=== Signal performance ===";
extern bool     TrackSignalPerformance         = false;                          // whether to track the signal performance
extern datetime TrackSignalPerformance.Since   = 0;                              // start time to track signal performance from
extern string   TrackSignalPerformance.Symbol  = "(default)";                    // custom symbol to use for performance tracking

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

bool     TrackZigZagBalance       = false;   // whether to track ZigZag balances
datetime TrackZigZagBalance.Since = 0;       // mark ZigZag balances since this time
bool     ProjectNextBalance       = false;   // whether to project zero-balance levels

#include <rsf/core/indicator.mqh>
#include <rsf/stdfunctions.mqh>
#include <rsf/stdlib.mqh>
#include <rsf/history.mqh>
#include <rsf/win32api.mqh>
#include <rsf/functions/chartlegend.mqh>
#include <rsf/functions/ConfigureSignals.mqh>
#include <rsf/functions/HandleCommands.mqh>
#include <rsf/functions/iBarShiftNext.mqh>
#include <rsf/functions/iCustom/ZigZag.mqh>
#include <rsf/functions/ManageDoubleIndicatorBuffer.mqh>
#include <rsf/functions/ManageIntIndicatorBuffer.mqh>
#include <rsf/functions/ObjectCreateRegister.mqh>
#include <rsf/functions/ParseDateTime.mqh>


// indicator buffer ids
#define MODE_UPPER_BAND          ZigZag.MODE_UPPER_BAND        //  0: upper channel band: positive or 0
#define MODE_LOWER_BAND          ZigZag.MODE_LOWER_BAND        //  1: lower channel band: positive or 0
#define MODE_SEMAPHORE_OPEN      ZigZag.MODE_SEMAPHORE_OPEN    //  2: final semaphores, open price: positive or 0
#define MODE_SEMAPHORE_CLOSE     ZigZag.MODE_SEMAPHORE_CLOSE   //  3: final semaphores, close price: positive or 0 (if open != close it forms a vertical line segment)
#define MODE_UPPER_CROSS         ZigZag.MODE_UPPER_CROSS       //  4: upper channel band crossings: positive or 0
#define MODE_LOWER_CROSS         ZigZag.MODE_LOWER_CROSS       //  5: lower channel band crossings: positive or 0
#define MODE_REVERSAL_OFFSET     ZigZag.MODE_REVERSAL_OFFSET   //  6: int: offset of the ZigZag reversal to the leg's start semaphore: non-negative or -1
#define MODE_COMBINED_TREND      ZigZag.MODE_COMBINED_TREND    //  7: int: combined buffers MODE_TREND & MODE_UNKNOWN_TREND: positive/negative or 0
#define MODE_UPPER_CROSS_HIGH    8                             //  8: bar High of an upper channel band crossing: positive or 0
#define MODE_LOWER_CROSS_LOW     9                             //  9: bar Low of a lower channel band crossing: positive or 0
#define MODE_TREND               10                            // 10: int: length of a ZigZag leg: positive/negative or 0
#define MODE_UNKNOWN_TREND       11                            // 11: int: number of bars after a leg's end semaphore: non-negative or -1
#define MODE_SIGNAL_PERFORMANCE  12                            // 12: accumulated signal performance in price units: positive/negative or EMPTY_VALUE

#property indicator_chart_window
#property indicator_buffers   8                                // visible buffers
int       terminal_buffers  = 8;                               // buffers managed by the terminal
int       framework_buffers = 5;                               // buffers managed by the framework

#property indicator_color1    Blue                             // upper channel band
#property indicator_style1    STYLE_DOT                        //
#property indicator_color2    Magenta                          // lower channel band
#property indicator_style2    STYLE_DOT                        //

#property indicator_color3    DodgerBlue                       // the ZigZag line is built from two buffers using the color of the first buffer
#property indicator_width3    1                                //
#property indicator_color4    CLR_NONE                         //

#property indicator_color5    indicator_color3                 // upper channel band crossings
#property indicator_width5    0                                //
#property indicator_color6    indicator_color4                 // lower channel band crossings
#property indicator_width6    0                                //

#property indicator_color7    CLR_NONE                         // trend (combined buffers MODE_TREND & MODE_UNKNOWN_TREND)
#property indicator_color8    CLR_NONE                         // offset of the previous ZigZag reversal to its preceeding semaphore

double   upperBand        [];                                  // upper channel band: positive or 0
double   lowerBand        [];                                  // lower channel band: positive or 0
double   upperCross       [];                                  // upper channel band crossings: positive or 0
double   upperCrossHigh   [];                                  // bar High of an upper channel band crossing (potential semaphore): positive or 0
double   lowerCross       [];                                  // lower channel band crossings: positive or 0
double   lowerCrossLow    [];                                  // bar Low of a lower channel band crossing (potential semaphore): positive or 0
double   semaphoreOpen    [];                                  // final semaphore, open price: positive or 0
double   semaphoreClose   [];                                  // final semaphore, close price: positive or 0 (if open != close it creates a vertical line segment)
double   reversalOffset   [];                                  // int: offset of the ZigZag reversal to the leg's start semaphore (): non-negative or -1
int      trend            [];                                  // int: length of a ZigZag leg: positive/negative or 0
int      unknownTrend     [];                                  // int: number of bars after a leg's end semaphore: non-negative or -1
double   combinedTrend    [];                                  // int: combined buffers MODE_TREND & MODE_UNKNOWN_TREND: positive/negative or 0
double   signalPerformance[];                                  // accumulated signal performance in price units: positive/negative or EMPTY_VALUE

string   indicatorName = "";
string   shortName     = "";
string   legendLabel   = "";
string   legendInfo    = "";                                   // additional chart legend info
string   labels[];                                             // chart object labels

int      zigzagDrawType;
int      zigzagSymbol;
int      crossingDrawType;
int      crossingSymbol;

#define MODE_FIRST_CROSSING   1                                // crossing draw types
#define MODE_ALL_CROSSINGS    2

bool     signal.onReversal.sound;
bool     signal.onReversal.alert;
bool     signal.onReversal.mail;

bool     signal.onBreakout.sound;
bool     signal.onBreakout.alert;
bool     signal.onBreakout.mail;

double   sema1, sema2, sema3;                                  // last 3 semaphores for detection of ZigZag breakouts
double   lastLegHigh, lastLegLow;                              // leg high/low at the previous tick

double   lastUpperBand;                                        // detection of channel widenings
double   lastLowerBand;                                        // upper/lower band values at the previous tick

datetime skipSignals;                                          // skip signals until the specified time to wait for possible data pumping
datetime lastTick;
int      lastSoundSignal;                                      // GetTickCount() value of the last audio signal


// recorder status
bool     recorder.initialized;
string   recorder.hstDirectory = "";
int      recorder.hstFormat;
string   recorder.symbol = "";
string   recorder.symbolDescr = "";
string   recorder.group = "";
int      recorder.priceBase;
int      recorder.hSet;
datetime recorder.startTime;


// signal direction types
#define D_LONG     TRADE_DIRECTION_LONG                        // 1
#define D_SHORT    TRADE_DIRECTION_SHORT                       // 2

// parameter stepper directions
#define STEP_UP    1
#define STEP_DOWN -1

// event types for reversal balance tracking
#define EVENT_SEMAPHORE_HIGH  1
#define EVENT_SEMAPHORE_LOW   2
#define EVENT_REVERSAL_UP     3
#define EVENT_REVERSAL_DOWN   4


//
// ZigZag leg up:   formed by two channel crossings in order "low band, high band" which create the preceeding Low semaphore
// ZigZag leg down: formed by two channel crossings in order "high band, low band" which create the preceeding High semaphore
//
// It's not enough to track only the last channel crossing. For ZigZag, a new channel crossing does not necessarily mean a
// new ZigZag High/Low. The channel may narrow after a crossing and can be crossed again without creating a new High/Low.
// If only the last crossing is tracked, the position of the semaphore will be lost. Thus the semaphore position is tracked.
//
//
// Buffer contents of the possible bar types
// -----------------------------------------
// • Bar before MaxBarsBack
//    double upperBand     :  0 (default)
//    double lowerBand     :  0 (default)
//    double upperCross    :  0 (default)
//    double upperCrossHigh:  0 (default)
//    double lowerCross    :  0 (default)
//    double lowerCrossLow :  0 (default)
//    double semaphoreOpen :  0 (default)
//    double semaphoreClose:  0 (default)
//    int    reversalOffset: -1 (default)
//    int    trend         :  0 (default)
//    int    unknownTrend  : -1 (default)
//
// • Bar between MaxBarsBack and first semaphore
//    double upperBand     :  positive
//    double lowerBand     :  positive
//    double upperCross    :  0 (default) or positive (only upper or lower values may be set, not both)
//    double upperCrossHigh:  0 (default) or positive
//    double lowerCross    :  0 (default) or positive
//    double lowerCrossLow :  0 (default) or positive
//    double semaphoreOpen :  0 (default)
//    double semaphoreClose:  0 (default)
//    int    reversalOffset: -1 (default)
//    int    trend         :  0 (default)
//    int    unknownTrend  : -1 (default) before the last cross, otherwise non-negative
//
// • Bar of ZigZag leg up
//    double upperBand     :  positive
//    double lowerBand     :  positive
//    double upperCross    :  0 (default) or positive
//    double upperCrossHigh:  0 (default) or positive
//    double lowerCross    :  0 (default)
//    double lowerCrossLow :  0 (default)
//    double semaphoreOpen :  0 (default)
//    double semaphoreClose:  0 (default)
//    int    reversalOffset: -1 (default) before the reversal, otherwise positive
//    int    trend         :  positive
//    int    unknownTrend  : -1 (default) before the last cross, otherwise non-negative
//
// • Bar of ZigZag leg down
//    double upperBand     :  positive
//    double lowerBand     :  positive
//    double upperCross    :  0 (default)
//    double upperCrossHigh:  0 (default)
//    double lowerCross    :  0 (default) or positive
//    double lowerCrossLow :  0 (default) or positive
//    double semaphoreOpen :  0 (default)
//    double semaphoreClose:  0 (default)
//    int    reversalOffset: -1 (default) before the reversal, otherwise positive
//    int    trend         :  negative
//    int    unknownTrend  : -1 (default) before the last cross, otherwise non-negative
//
// • High semaphore bar
//    double upperBand     :  positive
//    double lowerBand     :  positive
//    double upperCross    :  positive
//    double upperCrossHigh:  positive
//    double lowerCross    :  0 (default)
//    double lowerCrossLow :  0 (default)
//    double semaphoreOpen :  positive
//    double semaphoreClose:  positive (open = close)
//    int    reversalOffset:  positive (previous reversal offset)
//    int    trend         :  positive (previous trend length)
//    int    unknownTrend  :  0
//
// • Low semaphore bar
//    double upperBand     :  positive
//    double lowerBand     :  positive
//    double upperCross    :  0 (default)
//    double upperCrossHigh:  0 (default)
//    double lowerCross    :  positive
//    double lowerCrossLow :  positive
//    double semaphoreOpen :  positive
//    double semaphoreClose:  positive (open == close)
//    int    reversalOffset:  positive (previous reversal offset)
//    int    trend         :  negative (previous trend length)
//    int    unknownTrend  :  0
//
// • Double crossing bar (high+low semaphore) after processing of the 2nd crossing
//    double upperBand     :  positive
//    double lowerBand     :  positive
//    double upperCross    :  positive
//    double upperCrossHigh:  positive
//    double lowerCross    :  positive
//    double lowerCrossLow :  positive
//    double semaphoreOpen :  positive
//    double semaphoreClose:  positive (open != close)
//    int    reversalOffset:  0 (the previous reversal occurred on the same bar)
//    int    trend         :  0 (the whole last trend ocurred on the same bar)
//    int    unknownTrend  :  0 (same as reversal offset)
//
// • Triple+ crossing bar (more than two semaphores)              ???
//
// • Bar 0 (zero), the current bar                                ???
//

bool     debugging = false;
datetime devStartTime, devFirstCrossing, devFrom, devTo;
string   semTypes[] = {"NULL", "LOW", "HIGH"};


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   devStartTime     = D'2026.03.19 01:41';                     // TODO: remove once finished
   devFirstCrossing = D'2026.03.19 01:48';
                                                               // double crossings:
   devFrom = devStartTime     +  6 * Period() * MINUTES;       // P=8, 2026.03.16 20:47
   devTo   = devFirstCrossing + 32 * Period() * MINUTES;

   if (debugging && Symbol()=="BTCUSD" && Period()==PERIOD_M1 && ZigZag.Periods <= 20) {
      MaxBarsBack = iBarShift(NULL, NULL, devStartTime);
   }

   string indicator = WindowExpertName();

   // validate inputs
   // ZigZag.Periods
   if (AutoConfiguration) ZigZag.Periods = GetConfigInt(indicator, "ZigZag.Periods", ZigZag.Periods);
   if (ZigZag.Periods < 2)           return(catch("onInit(1)  invalid input parameter ZigZag.Periods: "+ ZigZag.Periods, ERR_INVALID_INPUT_PARAMETER));
   // ZigZag.Periods.Step
   if (AutoConfiguration) ZigZag.Periods.Step = GetConfigInt(indicator, "ZigZag.Periods.Step", ZigZag.Periods.Step);
   if (ZigZag.Periods.Step < 0)      return(catch("onInit(2)  invalid input parameter ZigZag.Periods.Step: "+ ZigZag.Periods.Step +" (must be >= 0)", ERR_INVALID_INPUT_PARAMETER));
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
   else                              return(catch("onInit(3)  invalid input parameter ZigZag.Type: "+ DoubleQuoteStr(sValue), ERR_INVALID_INPUT_PARAMETER));
   // ZigZag.Semaphores.Symbol
   if (AutoConfiguration) ZigZag.Semaphores.Symbol = GetConfigString(indicator, "ZigZag.Semaphores.Symbol", ZigZag.Semaphores.Symbol);
   sValue = ZigZag.Semaphores.Symbol;
   if (Explode(sValue, "*", sValues, 2) > 1) {
      size = Explode(sValues[0], "|", sValues, NULL);
      sValue = sValues[size-1];
   }
   sValue = StrToLower(StrTrim(sValue));
   if      (sValue == "dot"       ) zigzagSymbol = 108;     // that's Wingding characters
   else if (sValue == "thin-ring" ) zigzagSymbol = 161;     // ...
   else if (sValue == "ring"      ) zigzagSymbol = 162;     // ...
   else if (sValue == "thick-ring") zigzagSymbol = 163;     // ...
   else                              return(catch("onInit(4)  invalid input parameter ZigZag.Semaphores.Symbol: "+ DoubleQuoteStr(ZigZag.Semaphores.Symbol), ERR_INVALID_INPUT_PARAMETER));
   ZigZag.Semaphores.Symbol = sValue;
   // ZigZag.Width
   if (AutoConfiguration) ZigZag.Width = GetConfigInt(indicator, "ZigZag.Width", ZigZag.Width);
   if (ZigZag.Width < 0)             return(catch("onInit(5)  invalid input parameter ZigZag.Width: "+ ZigZag.Width, ERR_INVALID_INPUT_PARAMETER));

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
   else                              return(catch("onInit(6)  invalid input parameter Donchian.ShowCrossings: "+ DoubleQuoteStr(sValue), ERR_INVALID_INPUT_PARAMETER));
   // Donchian.Crossing.Symbol
   if (AutoConfiguration) Donchian.Crossing.Symbol = GetConfigString(indicator, "Donchian.Crossing.Symbol", Donchian.Crossing.Symbol);
   sValue = Donchian.Crossing.Symbol;
   if (Explode(sValue, "*", sValues, 2) > 1) {
      size = Explode(sValues[0], "|", sValues, NULL);
      sValue = sValues[size-1];
   }
   sValue = StrToLower(StrTrim(sValue));
   if      (sValue == "dot"       ) crossingSymbol = 108;   // that's Wingding characters
   else if (sValue == "thin-ring" ) crossingSymbol = 161;   // ...
   else if (sValue == "ring"      ) crossingSymbol = 162;   // ...
   else if (sValue == "thick-ring") crossingSymbol = 163;   // ...
   else                              return(catch("onInit(7)  invalid input parameter Donchian.Crossing.Symbol: "+ DoubleQuoteStr(Donchian.Crossing.Symbol), ERR_INVALID_INPUT_PARAMETER));
   Donchian.Crossing.Symbol = sValue;
   // Donchian.Crossing.Width
   if (AutoConfiguration) Donchian.Crossing.Width = GetConfigInt(indicator, "Donchian.Crossing.Width", Donchian.Crossing.Width);
   if (Donchian.Crossing.Width < 0)  return(catch("onInit(8)  invalid input parameter Donchian.Crossing.Width: "+ Donchian.Crossing.Width, ERR_INVALID_INPUT_PARAMETER));
   // colors: after deserialization the terminal might turn CLR_NONE (0xFFFFFFFF) into Black (0xFF000000)
   if (AutoConfiguration) ZigZag.Color                = GetConfigColor(indicator, "ZigZag.Color",                ZigZag.Color);
   if (AutoConfiguration) Donchian.Channel.UpperColor = GetConfigColor(indicator, "Donchian.Channel.UpperColor", Donchian.Channel.UpperColor);
   if (AutoConfiguration) Donchian.Channel.LowerColor = GetConfigColor(indicator, "Donchian.Channel.LowerColor", Donchian.Channel.LowerColor);
   if (AutoConfiguration) Donchian.Crossing.Color     = GetConfigColor(indicator, "Donchian.Crossing.Color",     Donchian.Crossing.Color);
   if (ZigZag.Color                == 0xFF000000) ZigZag.Color                = CLR_NONE;
   if (Donchian.Channel.UpperColor == 0xFF000000) Donchian.Channel.UpperColor = CLR_NONE;
   if (Donchian.Channel.LowerColor == 0xFF000000) Donchian.Channel.LowerColor = CLR_NONE;
   if (Donchian.Crossing.Color     == 0xFF000000) Donchian.Crossing.Color     = CLR_NONE;

   // ShowChartLegend
   if (AutoConfiguration) ShowChartLegend = GetConfigBool(indicator, "ShowChartLegend", ShowChartLegend);
   // MaxBarsBack
   if (AutoConfiguration) MaxBarsBack = GetConfigInt(indicator, "MaxBarsBack", MaxBarsBack);
   if (MaxBarsBack < -1) return(catch("onInit(9)  invalid input parameter MaxBarsBack: "+ MaxBarsBack, ERR_INVALID_INPUT_PARAMETER));
   if (MaxBarsBack == -1) MaxBarsBack = INT_MAX;

   // Signal.onReversal
   string signalId = "Signal.onReversal";
   legendInfo = "";
   ConfigureSignals(signalId, AutoConfiguration, Signal.onReversal);
   if (Signal.onReversal) {
      if (!ConfigureSignalTypes(signalId, Signal.onReversal.Types, AutoConfiguration, signal.onReversal.sound, signal.onReversal.alert, signal.onReversal.mail)) {
         return(catch("onInit(10)  invalid input parameter Signal.onReversal.Types: "+ DoubleQuoteStr(Signal.onReversal.Types), ERR_INVALID_INPUT_PARAMETER));
      }
      Signal.onReversal = (signal.onReversal.sound || signal.onReversal.alert || signal.onReversal.mail);
      if (Signal.onReversal) {
         legendInfo = "("+ StrLeft(ifString(signal.onReversal.sound, "sound,", "") + ifString(signal.onReversal.alert, "alert,", "") + ifString(signal.onReversal.mail, "mail,", ""), -1) +")";
         legendInfo = StrReplace(legendInfo, "sound,alert", "alert");
      }
   }
   // Signal.onBreakout
   signalId = "Signal.onBreakout";
   ConfigureSignals(signalId, AutoConfiguration, Signal.onBreakout);
   if (Signal.onBreakout) {
      if (!ConfigureSignalTypes(signalId, Signal.onBreakout.Types, AutoConfiguration, signal.onBreakout.sound, signal.onBreakout.alert, signal.onBreakout.mail)) {
         return(catch("onInit(11)  invalid input parameter Signal.onBreakout.Types: "+ DoubleQuoteStr(Signal.onBreakout.Types), ERR_INVALID_INPUT_PARAMETER));
      }
      Signal.onBreakout = (signal.onBreakout.sound || signal.onBreakout.alert || signal.onBreakout.mail);
   }
   // Signal.Sound.*
   if (AutoConfiguration) Signal.Sound.Up   = GetConfigString(indicator, "Signal.Sound.Up",   Signal.Sound.Up);
   if (AutoConfiguration) Signal.Sound.Down = GetConfigString(indicator, "Signal.Sound.Down", Signal.Sound.Down);
   // Sound.onChannelWidening
   if (AutoConfiguration) Sound.onChannelWidening = GetConfigBool(indicator, "Sound.onChannelWidening", Sound.onChannelWidening);
   if (AutoConfiguration) Sound.onNewChannelHigh  = GetConfigString(indicator, "Sound.onNewChannelHigh", Sound.onNewChannelHigh);
   if (AutoConfiguration) Sound.onNewChannelLow   = GetConfigString(indicator, "Sound.onNewChannelLow", Sound.onNewChannelLow);
   if (Sound.onChannelWidening) {
      if (legendInfo == "") legendInfo = "(w)";
      else                  legendInfo = StrLeft(legendInfo, -1) +",w)";
   }

   // TrackSignalPerformance
   if (AutoConfiguration) TrackSignalPerformance = GetConfigBool(indicator, "TrackSignalPerformance", TrackSignalPerformance);
   if (__isSuperContext) TrackSignalPerformance = false;
   if (__isTesting)      TrackSignalPerformance = false;
   // TrackSignalPerformance.Since
   datetime dtValue = TrackSignalPerformance.Since;
   if (AutoConfiguration) {
      sValue = GetConfigString(indicator, "TrackSignalPerformance.Since", "");
      if (sValue != "") {
         int result[];
         if (!ParseDateTime(sValue, DATE_YYYYMMDD|TIME_OPTIONAL, result)) {
            return(catch("onInit(12)  invalid config parameter TrackSignalPerformance.Since: "+ DoubleQuoteStr(sValue), ERR_INVALID_INPUT_PARAMETER));
         }
         TrackSignalPerformance.Since = DateTime2(result);
      }
   }
   // TrackSignalPerformance.Symbol
   if (AutoConfiguration) TrackSignalPerformance.Symbol = GetConfigBool(indicator, "TrackSignalPerformance.Symbol", TrackSignalPerformance.Symbol);

   // reset global vars used by the various event handlers
   skipSignals     = 0;
   lastTick        = 0;
   lastSoundSignal = 0;

   // reset an active command handler
   if (__isChart && ZigZag.Periods.Step) {
      GetChartCommand("ParameterStepper", sValues);
   }
   RestoreStatus();

   // buffer management and display options
   SetIndicatorOptions();
   if (ShowChartLegend) legendLabel = CreateChartLegend();

   // Indicator events like reversals occur "on-tick" and not on "bar-open" or "bar-close".
   // We need a chart ticker to prevent invalid signals caused by ticks during data pumping.
   if (!__tickTimerId && !__isTesting) {
      int hWnd = __ExecutionContext[EC.chart];
      int millis = 2000;                                         // a virtual tick every 2 seconds
      __tickTimerId = SetupTickTimer(hWnd, millis, NULL);
      if (!__tickTimerId) return(catch("onInit(13)->SetupTickTimer() failed", ERR_RUNTIME_ERROR));
   }
   return(catch("onInit(14)"));
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

   // close an open history set
   if (recorder.hSet != 0) {
      int tmp = recorder.hSet;
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
   // process incoming commands (may rewrite ValidBars/ChangedBars/ShiftedBars)
   if (__isChart && ZigZag.Periods.Step) {
      if (!HandleCommands("ParameterStepper")) return(last_error);
   }

   // manage additional fraemwork buffers
   ManageDoubleIndicatorBuffer(MODE_UPPER_CROSS_HIGH,   upperCrossHigh  );
   ManageDoubleIndicatorBuffer(MODE_LOWER_CROSS_LOW,    lowerCrossLow   );
   ManageIntIndicatorBuffer   (MODE_TREND,              trend           );
   ManageIntIndicatorBuffer   (MODE_UNKNOWN_TREND,      unknownTrend, -1);
   ManageDoubleIndicatorBuffer(MODE_SIGNAL_PERFORMANCE, signalPerformance, EMPTY_VALUE);

   // reset buffers before performing a full recalculation
   if (!ValidBars) {
      ArrayInitialize(upperBand,         0);             // double: positive or 0
      ArrayInitialize(lowerBand,         0);             // double: positive or 0
      ArrayInitialize(upperCross,        0);             // double: positive or 0
      ArrayInitialize(upperCrossHigh,    0);             // double: positive or 0
      ArrayInitialize(lowerCross,        0);             // double: positive or 0
      ArrayInitialize(lowerCrossLow,     0);             // double: positive or 0
      ArrayInitialize(semaphoreOpen,     0);             // double: positive or 0
      ArrayInitialize(semaphoreClose,    0);             // double: positive or 0
      ArrayInitialize(reversalOffset,   -1);             // int:    non-negative or -1
      ArrayInitialize(trend,             0);             // int:    positive/negative or 0
      ArrayInitialize(unknownTrend,     -1);             // int:    non-negative or -1
      ArrayInitialize(combinedTrend,     0);             // int:    positive/negative or 0
      ArrayInitialize(signalPerformance, EMPTY_VALUE);   // double: positive/negative or EMPTY_VALUE
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
      ShiftDoubleIndicatorBuffer(upperBand,         Bars, ShiftedBars,  0);
      ShiftDoubleIndicatorBuffer(lowerBand,         Bars, ShiftedBars,  0);
      ShiftDoubleIndicatorBuffer(upperCross,        Bars, ShiftedBars,  0);
      ShiftDoubleIndicatorBuffer(upperCrossHigh,    Bars, ShiftedBars,  0);
      ShiftDoubleIndicatorBuffer(lowerCross,        Bars, ShiftedBars,  0);
      ShiftDoubleIndicatorBuffer(lowerCrossLow,     Bars, ShiftedBars,  0);
      ShiftDoubleIndicatorBuffer(semaphoreOpen,     Bars, ShiftedBars,  0);
      ShiftDoubleIndicatorBuffer(semaphoreClose,    Bars, ShiftedBars,  0);
      ShiftDoubleIndicatorBuffer(reversalOffset,    Bars, ShiftedBars, -1);
      ShiftIntIndicatorBuffer   (trend,             Bars, ShiftedBars,  0);
      ShiftIntIndicatorBuffer   (unknownTrend,      Bars, ShiftedBars, -1);
      ShiftDoubleIndicatorBuffer(combinedTrend,     Bars, ShiftedBars,  0);
      ShiftDoubleIndicatorBuffer(signalPerformance, Bars, ShiftedBars, EMPTY_VALUE);
   }

   // check data pumping on every tick so the reversal handler can skip errornous signals
   if (!__isTesting) IsPossibleDataPumping();

   // calculate start bar
   int startBar = Min(MaxBarsBack-1, ChangedBars-1, Bars-ZigZag.Periods);
   if (startBar < 0 && MaxBarsBack) return(logInfo("onTick(1)  Tick="+ Ticks +"  Bars="+ Bars +"  needed="+ ZigZag.Periods, ERR_HISTORY_INSUFFICIENT));
   if (!ValidBars) recorder.startTime = Time[startBar];

   // recalculate changed bars
   if (startBar > 2) {                       // TODO: why 2 and not 1
      upperBand        [startBar] =  0;
      lowerBand        [startBar] =  0;
      upperCross       [startBar] =  0;
      upperCrossHigh   [startBar] =  0;
      lowerCross       [startBar] =  0;
      lowerCrossLow    [startBar] =  0;
      semaphoreOpen    [startBar] =  0;
      semaphoreClose   [startBar] =  0;
      reversalOffset   [startBar] = -1;
      trend            [startBar] =  0;
      unknownTrend     [startBar] = -1;
      combinedTrend    [startBar] =  0;
      signalPerformance[startBar] = EMPTY_VALUE;
   }

   for (int bar=startBar; bar >= 0; bar--) {
      // recalculate Donchian channel
      if (bar > 0) {
         upperBand[bar] = High[iHighest(NULL, NULL, MODE_HIGH, ZigZag.Periods, bar)];
         lowerBand[bar] =  Low[ iLowest(NULL, NULL, MODE_LOW,  ZigZag.Periods, bar)];
      }
      else {
         upperBand[0] = MathMax(upperBand[1], High[0]);
         lowerBand[0] = MathMin(lowerBand[1],  Low[0]);
      }

      // recalculate channel crossings
      if (upperBand[bar] > upperBand[bar+1] && upperBand[bar+1]) {
         upperCross    [bar] = upperBand[bar+1]+Point;
         upperCrossHigh[bar] = upperBand[bar];
      }
      if (lowerBand[bar] < lowerBand[bar+1]) {
         lowerCross   [bar] = lowerBand[bar+1]-Point;
         lowerCrossLow[bar] = lowerBand[bar];
      }

      // recalculate ZigZag data
      // if no channel crossing                                      // before or after the first semaphore
      if (!upperCross[bar] && !lowerCross[bar]) {
         reversalOffset[bar] = reversalOffset[bar+1];                // keep reversal offset (may be -1)
         trend         [bar] = trend         [bar+1];                // keep trend (may be 0)
         unknownTrend  [bar] = unknownTrend  [bar+1];                // get previous unknown trend
         if (unknownTrend[bar] > -1) {
            unknownTrend[bar]++;                                     // increase if it was set
         }
      }

      // if two channel crossings (upper and lower band crossed by the same bar)
      else if (upperCross[bar] && lowerCross[bar]) {
         if (IsUpperCrossLast(bar)) {
            if (!trend[bar]) ProcessLowerCross(bar);                 // if bar not yet processed then process both crossings in order,
            ProcessUpperCross(bar);                                  // otherwise process only the last crossing
         }
         else {
            if (!trend[bar]) ProcessUpperCross(bar);                 // ...
            ProcessLowerCross(bar);                                  // ...
         }
      }

      // if a single channel crossing (before or after the first semaphore)
      else if (upperCross[bar] != 0) ProcessUpperCross(bar);
      else                           ProcessLowerCross(bar);

      // whether the current bar is a reversal bar (not whether the current tick triggered a reversal)
      bool isReversalBar = false;
      if (!unknownTrend[bar]) {
         isReversalBar = (Abs(trend[bar]) == reversalOffset[bar]);
      }

      // calculate signal performance
      if (TrackSignalPerformance) {
         RecalculateSignalPerformance(bar, isReversalBar);
      }

      if (debugging && Ticks == 1) {
         if (Time[bar] >= devFrom && Time[bar] <= devTo) {
            debug("onTick(0.1)  Tick="+ Ticks +" bar="+ bar +" "+ TimeToStr(Time[bar]) +"  reversalOffset="+ _int(reversalOffset[bar]) +"  trend="+ trend[bar] +"  unknownTrend="+ unknownTrend[bar]);
            if (isReversalBar) {
            debug("onTick(0.2)  Tick="+ Ticks +" bar="+ bar +" "+ TimeToStr(Time[bar]) +"  isReversalBar=1");
            }
            if (semaphoreClose[bar] != NULL) {
            debug("onTick(0.3)  Tick="+ Ticks +" bar="+ bar +" "+ TimeToStr(Time[bar]) +"  isSemaphoreBar=1");
            }
         }
      }

      // hide non-configured crossings
      if (!crossingDrawType) {                                    // hide all crossings
         upperCross[bar] = 0;
         lowerCross[bar] = 0;
      }
      else if (crossingDrawType == MODE_FIRST_CROSSING) {         // hide all crossings except the 1st
         if (isReversalBar) {
            if (reversalOffset[bar+1] >= 0) {                     // keep preceeding reversals on the same bar
               if (trend[bar] > 0) lowerCross[bar] = 0;
               else                upperCross[bar] = 0;
            }
         }
         else {
            upperCross[bar] = 0;
            lowerCross[bar] = 0;
         }
      }

      // set combinedTrend[]
      combinedTrend[bar] = Sign(trend[bar]) * unknownTrend[bar] * 100000 + trend[bar];
   }

   if (__isChart && !__isSuperContext) {
      if (ShowChartLegend) UpdateChartLegend();

      // record signal performance
      if (TrackSignalPerformance) {
         RecordSignalPerformance();
      }

      // detect ZigZag breakouts (comparing legs against bands also detects breakouts on missed ticks)
      if (Signal.onBreakout) {
         if (ChangedBars > 2) {
            while (true) {
               int resultType = 0;
               bar = FindSemaphore(0, resultType); if (bar < 0) break;

               // resolve leg high/low
               if (resultType == MODE_HIGH) {
                  lastLegHigh = High[bar];
                  lastLegLow = 0;
               }
               else {
                  lastLegHigh = 0;
                  lastLegLow = Low[bar];
               }

               // resolve the last 3 semaphores
               bar   = FindSemaphore(bar, resultType, resultType);           if (bar < 0) break;
               sema1 = ifDouble(resultType==MODE_HIGH, High[bar], Low[bar]);
               bar   = FindSemaphore(bar, resultType, resultType);           if (bar < 0) break;
               sema2 = ifDouble(resultType==MODE_HIGH, High[bar], Low[bar]);
               bar   = FindSemaphore(bar, resultType, resultType);           if (bar < 0) break;
               sema3 = ifDouble(resultType==MODE_HIGH, High[bar], Low[bar]);
               break;
            }
         }
         else if (sema3 != 0) {
            if (trend[0] > 0) {
               if (lastLegHigh < sema2+HalfPoint && upperBand[0] > sema2+HalfPoint) {
                  onBreakout(D_LONG);
               }
               lastLegHigh = High[unknownTrend[0]];               // leg high for comparison at the nex tick
            }
            else if (trend[0] < 0) {
               if ((!lastLegLow || lastLegLow > sema2-HalfPoint) && lowerBand[0] < sema2-HalfPoint) {
                  onBreakout(D_SHORT);
               }
               lastLegLow = Low[unknownTrend[0]];                 // leg low for comparison at the nex tick
            }
         }
      }

      // detect Donchian channel widenings
      if (Sound.onChannelWidening) /*&&*/ if (ChangedBars <= 2) {
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

      // --- old ------------------------------------------------------------------------------------------------------------
      // track ZigZag balance
      if (TrackZigZagBalance) {
         int currSem, prevBar, prevSem, size;
         int currBar = FindSemaphore(0, currSem); if (currBar < 0) return(last_error);

         double events[][3];                                                  // [datetime, type, price]
         ArraySetAsSeries(events, false);
         ArrayResize(events, 0);

         while (true) {                                                       // TODO: these returns are wrong
            prevBar = FindSemaphore(currBar, prevSem, currSem); if (prevBar < 0) return(last_error);

            int reversalBar = prevBar - reversalOffset[currBar];              // standard case

            if (!reversalOffset[currBar] && reversalOffset[currBar+1]==-1) {  // reversal and next semaphore on the same bar
               reversalBar = currBar;
            }
            if (reversalBar > MaxBarsBack-ZigZag.Periods) break;

            size = ArrayRange(events, 0);
            ArrayResize(events, size+2);
            events[size][0] = Time[currBar];
            events[size][1] = ifInt(currSem==MODE_HIGH, EVENT_SEMAPHORE_HIGH, EVENT_SEMAPHORE_LOW);
            events[size][2] = ifDouble(currSem==MODE_HIGH, High[currBar], Low[currBar]);
            size++;
            events[size][0] = Time[reversalBar];                              // crosses may be invisible and buffers upper/lowerCross[] are empty
            events[size][1] = ifInt(currSem==MODE_HIGH, EVENT_REVERSAL_UP, EVENT_REVERSAL_DOWN);
            events[size][2] = ifDouble(currSem==MODE_HIGH, upperBand[reversalBar+1], lowerBand[reversalBar+1]);

            currBar = prevBar;
            currSem = prevSem;
         }

         ArraySetAsSeries(events, true);
         size = ArrayRange(events, 0);

         if (size > 0) {
            double balance=0, prevSemaphore, prevReversal=events[0][2], markerOffset = CalculateMarkerOffset();
            bool   prevBalanceReset = false;
            string fontName = "Microsoft Tai Le Bold";
            int    fontSize = 9;
            color  fontColor;

            for (int i=0; i < size; i++) {
               datetime eventTime  = events[i][0];
               int      eventType  = events[i][1];
               double   eventPrice = events[i][2];

               if (i % 2 == 0) {
                  // reversal: add up negative balances
                  if (eventType == EVENT_REVERSAL_UP) balance += (prevReversal-eventPrice);
                  else                                balance += (eventPrice-prevReversal);

                  if (i > 0) {
                     if      (balance > -HalfPoint) fontColor = C'45,181,45';
                     else if (prevBalanceReset)     fontColor = Blue;
                     else                           fontColor = Red;
                     string name = shortName + ifString(eventType==EVENT_REVERSAL_UP, ".up.", ".down.") + TimeToStr(eventTime);
                     ObjectCreateRegister(name, OBJ_TEXT, 0, eventTime, eventPrice-markerOffset);
                     ObjectSetText(name, NumberToStr(balance/pUnit, ",'R.0"), fontSize, fontName, fontColor);

                     // reset positive balances
                     if (balance > -HalfPoint) balance = 0;
                     prevBalanceReset = false;
                  }
                  prevReversal = eventPrice;
               }
               else {
                  // semaphore
                  if (eventType == EVENT_SEMAPHORE_HIGH) double gain = eventPrice - prevReversal;
                  else                                          gain = prevReversal - eventPrice;

                  // reset negative balances if recovered by the semaphore
                  if (balance < 0 && gain > -balance) {
                     balance = 0;
                     prevBalanceReset = true;
                  }
               }
            }
         }
      }
   }
   return(last_error);
}


/**
 * Recalculate the signal performance for the specified bar.
 *
 * @param  int  bar        - bar offset
 * @param  bool isReversal - whether the bar is a reversal bar
 *
 * @return bool - success status
 */
bool RecalculateSignalPerformance(int bar, bool isReversal) {
   isReversal = (isReversal != 0);
   bool isPosition = (signalPerformance[bar+1] != EMPTY_VALUE);
   double change;

   // either flip the position
   if (isReversal) {
      if (isPosition) {
         if (trend[bar] > 0) {
            change = upperCross[bar] - Close[bar+1];
            signalPerformance[bar]  = signalPerformance[bar+1] - change;   // close existing short position
            signalPerformance[bar] += Close[bar] - upperCross[bar];        // open new long position
         }
         else if (trend[bar] < 0) {
            change = lowerCross[bar] - Close[bar+1];
            signalPerformance[bar]  = signalPerformance[bar+1] + change;   // close existing long position
            signalPerformance[bar] += lowerCross[bar] - Close[bar];        // open new short position
         }
         else {
            logWarn("RecalculateSignalPerformance(0.1)  bar="+ bar +" "+ TimeToStr(Time[bar]) +"  cannot yet flip position with trend=0");
         }
      }
      else {                                                               // open a new position
         if (trend[bar] > 0) {
            signalPerformance[bar] = Close[bar] - upperCross[bar];         // long position
         }
         else if (trend[bar] < 0) {
            signalPerformance[bar] = lowerCross[bar] - Close[bar];         // short position
         }
         else {
            logWarn("RecalculateSignalPerformance(0.2)  bar="+ bar +" "+ TimeToStr(Time[bar]) +"  cannot yet open position with trend=0");
         }
      }
   }

   // or update the position
   else if (isPosition) {
      change = Close[bar] - Close[bar+1];
      if (trend[bar] > 0) {
         signalPerformance[bar] = signalPerformance[bar+1] + change;
      }
      else if (trend[bar] < 0) {
         signalPerformance[bar] = signalPerformance[bar+1] - change;
      }
      else {
         logWarn("RecalculateSignalPerformance(0.4)  bar="+ bar +" "+ TimeToStr(Time[bar]) +"  cannot yet update position with trend=0");
      }
   }

   // or keep existing PnL
   else {
      signalPerformance[bar] = signalPerformance[bar+1];
   }
   return(true);
}


/**
 * Record the signal performance for the specified bar.
 *
 * @param  int bar - bar offset
 *
 * @return bool - success status
 */
bool RecordSignalPerformance(int _bar = 0) {
   if (!recorder.initialized) {
      // create symbol and group
      recorder.symbol       = Symbol() +".zzr";
      recorder.symbolDescr  = "ZigZag reversal";
      recorder.group        = "ZigZag reversal";
      recorder.hstDirectory = Recorder_GetHstDirectory();
      recorder.hstFormat    = Recorder_GetHstFormat();
      if (last_error != NULL) return(false);

      if (!IsRawSymbol(recorder.symbol, recorder.hstDirectory)) {
         int symbolId = CreateRawSymbol(recorder.symbol, recorder.symbolDescr, recorder.group, pDigits, AccountCurrency(), AccountCurrency(), recorder.hstDirectory);
         if (symbolId < 0) return(false);
      }

      // open HistorySet
      if (!recorder.hSet) {
         recorder.hSet = HistorySet1.Get(recorder.symbol, recorder.hstDirectory);
         if (recorder.hSet == -1) {
            recorder.hSet = HistorySet1.Create(recorder.symbol, recorder.symbolDescr, pDigits, recorder.hstFormat, recorder.hstDirectory);
         }
         if (!recorder.hSet) return(false);
      }
      recorder.initialized = true;
      debug("RecordSignalPerformance(0.1)  Tick="+ Ticks +"  recorder initialized");
   }

   int startBar = 0, flags = HST_BUFFER_TICKS|HST_FILL_GAPS;

   if (ChangedBars > 2) {                             // rewrite the full history (intentionally skip rewriting bar 1 on BarOpen)
      if (recorder.hSet != 0) {
         int tmp = recorder.hSet;
         recorder.hSet = NULL;
         if (!HistorySet1.Close(tmp)) return(false);  // TODO: HistorySet.Create() should auto-close an open set but errors
      }
      startBar = iBarShiftNext(NULL, NULL, recorder.startTime);
      debug("RecordSignalPerformance(0.2)  Tick="+ Ticks +"  rewriting all history since "+ TimeToStr(recorder.startTime) +" (bar "+ startBar +")");
   }

   for (int bar=startBar; bar > 0; bar--) {
      if (!recorder.hSet) {
         recorder.hSet = HistorySet1.Create(recorder.symbol, recorder.symbolDescr, pDigits, recorder.hstFormat, recorder.hstDirectory);
         if (!recorder.hSet) return(false);
      }
      double value = signalPerformance[bar] + recorder.priceBase;

      if (value <= 0) {
         switch(recorder.priceBase) {
            case       0: recorder.priceBase =        1; break;
            case       1: recorder.priceBase =       10; break;
            case      10: recorder.priceBase =      100; break;
            case     100: recorder.priceBase =     1000; break;
            case    1000: recorder.priceBase =    10000; break;
            case   10000: recorder.priceBase =   100000; break;
            case  100000: recorder.priceBase =  1000000; break;
            case 1000000: recorder.priceBase = 10000000; break;
         }
         debug("RecordSignalPerformance(0.3)  Tick="+ Ticks +"  updated price base to "+ DoubleToStr(recorder.priceBase, 2));

         tmp = recorder.hSet;
         recorder.hSet = NULL;
         if (!HistorySet1.Close(tmp)) return(false);
         startBar = iBarShiftNext(NULL, NULL, recorder.startTime);
         bar = startBar + 1;
         continue;
      }

      if (bar == 0) flags = HST_FILL_GAPS;
      else          flags = HST_FILL_GAPS|HST_BUFFER_TICKS;
      if (!HistorySet1.AddTick(recorder.hSet, Time[bar], value, flags)) return(false);
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
 * Calculate the balance marker offset for the current view port of the chart.
 *
 * @return double
 */
double CalculateMarkerOffset() {
   double minPrice = NormalizeDouble(WindowPriceMin(), Digits);
   double maxPrice = NormalizeDouble(WindowPriceMax(), Digits);
   if (!minPrice || !maxPrice) return(0);                         // chart not yet ready

   double priceRange = maxPrice - minPrice;
   if (priceRange < HalfPoint) return(0);                         // chart with ScaleFix=1 after resizing to zero height

   double offset = NormalizeDouble(priceRange * 0.007, Digits);   // 7%
   return(offset);
}


/**
 * Whether a bar crossing both channel bands crossed the upper band last. The result is just a "best guess".
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
}


/**
 * Find the next ZigZag semaphore starting at the specified bar looking backwards. On a semaphore bar the semaphore of the
 * bar itself is returned. Specify a semaphore type to be skipped to prevent this.
 *
 * @param  _In_  int bar                 - bar to start searching from
 * @param  _Out_ int resultType          - semaphore result type: MODE_HIGH|MODE_LOW
 * @param  _In_  int skipType [optional] - semaphore type on the start bar to be skipped: MODE_HIGH|MODE_LOW (default: no skipping)
 *
 * @return int - chart offset of the found semaphore;
 *               EMPTY (-1) if no semaphore was found or in case of errors (parameter 'resultType' remains unchanged)
 */
int FindSemaphore(int bar, int &resultType, int skipType = NULL) {
   if (bar < 0 || bar >= Bars)                       return(_EMPTY(catch("FindSemaphore(1)  invalid parameter bar: "+ bar +" (out of range)", ERR_INVALID_PARAMETER)));
   if (skipType != NULL) {
      if (skipType!=MODE_HIGH && skipType!=MODE_LOW) return(_EMPTY(catch("FindSemaphore(2)  invalid parameter skipType: "+ skipType, ERR_INVALID_PARAMETER)));
   }
   static int doDebug = 0;
   if (debugging && (Ticks==1 && Time[bar] >= devFirstCrossing && Time[bar] <= devFirstCrossing + 2*MINUTES) || doDebug) {
      debug("FindSemaphore(0.1)  start @ "+ TimeToStr(Time[bar]) +"  skipType="+ semTypes[skipType]);
      doDebug++;
   }

   // if no skipping (no skip type or not a semaphore bar), then return the next semaphore
   if (!skipType || !semaphoreClose[bar]) {
      if (!semaphoreClose[bar]) {                                    // semaphore is located somewhere before
         bar++;
      }
      if (!semaphoreClose[bar] && unknownTrend[bar] > 0) {           // navigate to the end semaphore (if any),
         bar += unknownTrend[bar];                                   // a current bar has never unknownTrend=-1
      }
      if (!semaphoreClose[bar] && trend[bar]) {                      // navigate to the start semaphore (if any)
         bar += Abs(trend[bar]);
      }
      if (!semaphoreClose[bar]) {
         if (doDebug > 0) { debug("FindSemaphore(0.2)  return "+ EMPTY); doDebug--; }
         return(EMPTY);
      }
      if      (!lowerCrossLow [bar])                                resultType = MODE_HIGH;
      else if (!upperCrossHigh[bar])                                resultType = MODE_LOW;
      else if (semaphoreOpen [bar] < semaphoreClose[bar]-HalfPoint) resultType = MODE_HIGH;
      else if (semaphoreOpen [bar] > semaphoreClose[bar]+HalfPoint) resultType = MODE_LOW;
      else if (semaphoreClose[bar] > upperCrossHigh[bar]-HalfPoint) resultType = MODE_HIGH;  // from here it holds: open == close
      else                                                          resultType = MODE_LOW;   //                     ...
      if (doDebug > 0) { debug("FindSemaphore(0.3)  return "+ bar +" = "+ TimeToStr(Time[bar])); doDebug--; }
      return(bar);
   }


   // if skipping: some semaphore type to skip on the start bar (not used by ZigZag calculation)
   if (semaphoreOpen[bar] == semaphoreClose[bar]) {
      bool isHigh = (semaphoreClose[bar] == upperCrossHigh[bar]);

      if (skipType == MODE_HIGH) {
         if (isHigh) {
            int iTmp = FindSemaphore(bar+1, resultType);
            if (doDebug > 0) { debug("FindSemaphore(0.4)  return "+ iTmp +" = "+ TimeToStr(Time[iTmp])); doDebug--; }
            return(iTmp);
         }
         resultType = MODE_LOW;
      }
      else /*skipType == MODE_LOW*/ {
         if (!isHigh) {
            iTmp = FindSemaphore(bar+1, resultType);
            if (doDebug > 0) { debug("FindSemaphore(0.5)  return "+ iTmp +" = "+ TimeToStr(Time[iTmp])); doDebug--; }
            return(iTmp);
         }
         resultType = MODE_HIGH;
      }
   }
   else {
      bool high2Low = (semaphoreOpen[bar] > semaphoreClose[bar]+HalfPoint);

      if (skipType == MODE_HIGH) {
         if (high2Low) {
            iTmp = FindSemaphore(bar+1, resultType);
            if (doDebug > 0) { debug("FindSemaphore(0.6)  return "+ iTmp +" = "+ TimeToStr(Time[iTmp])); doDebug--; }
            return(iTmp);
         }
         resultType = MODE_LOW;
      }
      else /*skipType == MODE_LOW*/ {
         if (!high2Low) {
            iTmp = FindSemaphore(bar+1, resultType);
            if (doDebug > 0) { debug("FindSemaphore(0.7)  return "+ iTmp +" = "+ TimeToStr(Time[iTmp])); doDebug--; }
            return(iTmp);
         }
         resultType = MODE_HIGH;
      }
   }

   if (doDebug > 0) { debug("FindSemaphore(0.8)  return "+ bar +" = "+ TimeToStr(Time[bar])); doDebug--; }
   return(bar);
}


/**
 * Update buffers after an upper band crossing at the specified bar offset. Resolves the preceeding ZigZag
 * semaphore and counts the trend forward from there.
 *
 * @param  int bar - offset
 *
 * @return bool - success status
 */
bool ProcessUpperCross(int bar) {
   if (debugging && Ticks==1 && Time[bar] >= devFrom && Time[bar] <= devTo) {
      debug("ProcessUpperCross(0.1)      "+ TimeToStr(Time[bar]));
   }
   int lastSemType, lastSemBar = FindSemaphore(bar, lastSemType);    // find the last semaphore

   if (debugging && Ticks==1 && Time[bar] >= devFrom && Time[bar] <= devTo) {
      if (lastSemBar < 0) debug("ProcessUpperCross(0.2)  found no semaphore");
      else                debug("ProcessUpperCross(0.3)  found semaphore at bar["+ lastSemBar +"] "+ TimeToStr(Time[lastSemBar]) +"  type="+ semTypes[lastSemType] +"  trend="+ trend[lastSemBar]);
   }

   // an upper cross without a previous semaphore (near MaxBarsBack)
   if (lastSemBar < 0) {
      if (!last_error) {
         semaphoreOpen [bar] = upperCrossHigh[bar];                  // set new semaphore
         semaphoreClose[bar] = upperCrossHigh[bar];
         reversalOffset[bar] = -1;                                   // no reversal
         trend         [bar] =  0;                                   // no trend
         unknownTrend  [bar] =  0;                                   // current bar
      }
      return(!last_error);
   }

   // another upper cross of a ZigZag leg up
   if (lastSemType == MODE_HIGH) {
      if (lastSemBar == bar) {                                       // double crossing
         if (semaphoreOpen[bar] != lowerCrossLow[bar]) {             // keep trend buffers from first crossing
            semaphoreOpen[bar] = upperCrossHigh[bar];                // update existing semaphore
         }
         semaphoreClose[bar] = upperCrossHigh[bar];
      }
      else {
         if (upperCrossHigh[bar] > upperCrossHigh[lastSemBar]) {     // an uptrend continuation
            SetTrend(lastSemBar, trend[lastSemBar], bar, false);     // update existing trend

            if (semaphoreOpen[lastSemBar] != semaphoreClose[lastSemBar]) {
               SetTrend(lastSemBar-1, 1, bar, false);                // fix trend=0 on double crossings
            }
            else {
               semaphoreOpen[lastSemBar] = 0;                        // reset previous semaphore
            }
            semaphoreClose[lastSemBar] = semaphoreOpen[lastSemBar];
            semaphoreOpen [bar]        = upperCrossHigh[bar];        // set new semaphore
            semaphoreClose[bar]        = upperCrossHigh[bar];
            unknownTrend  [bar] = 0;                                 // current bar
         }
         else {                                                      // a lower High (unknown direction)
            trend       [bar] = trend       [bar+1];                 // keep trend (may be 0)
            unknownTrend[bar] = unknownTrend[bar+1] + 1;             // increase unknown trend
         }
         reversalOffset[bar] = reversalOffset[bar+1];                // keep reversal offset (may be -1)
      }
   }

   // or an upper cross finishing a ZigZag leg down
   else /*lastSemType == MODE_LOW*/ {                                // a reversal from "short" to "long" (new uptrend)
      if (lastSemBar == bar) {
         trend[bar] = 0;                                             // double crossing: reset trend, keep semaphoreOpen[]
      }
      else {
         SetTrend(lastSemBar-1, 1, bar, true);                       // set the new trend range, reset reversals
         semaphoreOpen[bar] = upperCrossHigh[bar];                   // set new semaphore
      }
      semaphoreClose[bar] = upperCrossHigh[bar];
      reversalOffset[bar] = lastSemBar - bar;                        // set new reversal offset
      unknownTrend  [bar] = 0;                                       // current bar

      sema3 = sema2;                                                 // update the last 3 semaphores
      sema2 = sema1;
      sema1 = Low[lastSemBar];
      lastLegHigh = 0;                                               // reset last leg high

      if (Signal.onReversal && __isChart && ChangedBars <= 2) {
         onReversal(D_LONG, upperCross[bar]);
      }
   }
   return(true);
}


/**
 * Update buffers after a lower band crossing at the specified bar offset. Resolves the preceeding ZigZag
 * semaphore and counts the trend forward from there.
 *
 * @param  int bar - offset
 *
 * @return bool - success status
 */
bool ProcessLowerCross(int bar) {
   if (debugging && Ticks==1 && Time[bar] >= devFrom && Time[bar] <= devTo) {
      debug("ProcessLowerCross(0.1)      "+ TimeToStr(Time[bar]));
   }
   int lastSemType, lastSemBar = FindSemaphore(bar, lastSemType);    // find the last semaphore

   if (debugging && Ticks==1 && Time[bar] >= devFrom && Time[bar] <= devTo) {
      if (lastSemBar < 0) debug("ProcessLowerCross(0.2)  found no semaphore");
      else                debug("ProcessLowerCross(0.3)  found semaphore at bar["+ lastSemBar +"] "+ TimeToStr(Time[lastSemBar]) +"  type="+ semTypes[lastSemType] +"  trend="+ trend[lastSemBar]);
   }

   // a lower cross without a previous semaphore (near MaxBarsBack)
   if (lastSemBar < 0) {
      if (!last_error) {
         semaphoreOpen [bar] = lowerCrossLow[bar];                   // set new semaphore
         semaphoreClose[bar] = lowerCrossLow[bar];
         reversalOffset[bar] = -1;                                   // no reversal
         trend         [bar] =  0;                                   // no trend
         unknownTrend  [bar] =  0;                                   // current bar
      }
      return(!last_error);
   }

   // another lower cross of a ZigZag leg down
   if (lastSemType == MODE_LOW) {
      if (lastSemBar == bar) {                                       // double crossing
         if (semaphoreOpen[bar] != upperCrossHigh[bar]) {            // keep trend buffers from first crossing
            semaphoreOpen [bar] = lowerCrossLow[bar];                // update existing semaphore
         }
         semaphoreClose[bar] = lowerCrossLow[bar];
      }
      else {
         if (lowerCrossLow[bar] < lowerCrossLow[lastSemBar]) {       // a downtrend continuation
            SetTrend(lastSemBar, trend[lastSemBar], bar, false);     // update existing trend

            if (semaphoreOpen[lastSemBar] != semaphoreClose[lastSemBar]) {
               SetTrend(lastSemBar-1, -1, bar, false);               // fix trend=0 on double crossings
            }
            else {
               semaphoreOpen[lastSemBar] = 0;                        // reset previous semaphore
            }
            semaphoreClose[lastSemBar] = semaphoreOpen[lastSemBar];
            semaphoreOpen [bar]        = lowerCrossLow[bar];         // set new semaphore
            semaphoreClose[bar]        = lowerCrossLow[bar];
            unknownTrend  [bar] = 0;                                 // current bar
         }
         else {                                                      // a higher Low (unknown direction)
            trend       [bar] = trend       [bar+1];                 // keep trend (may be 0)
            unknownTrend[bar] = unknownTrend[bar+1] + 1;             // increase unknown trend
         }
         reversalOffset [bar] = reversalOffset [bar+1];              // keep reversal offset (may be -1)
      }
   }

   // or a lower cross finishing a ZigZag leg up
   else /*lastSemType == MODE_HIGH*/ {                               // a reversal from "long" to "short" (new downtrend)
      if (lastSemBar == bar) {
         trend[bar] = 0;                                             // double crossing: reset trend, keep semaphoreOpen[]
      }
      else {
         SetTrend(lastSemBar-1, -1, bar, true);                      // set the new trend range, reset reversals
         semaphoreOpen[bar] = lowerCrossLow[bar];                    // set new semaphore
      }
      semaphoreClose[bar] = lowerCrossLow[bar];
      reversalOffset[bar] = lastSemBar - bar;                        // set the new reversal offset
      unknownTrend  [bar] = 0;                                       // current bar

      sema3 = sema2;                                                 // update the last 3 semaphores
      sema2 = sema1;
      sema1 = High[lastSemBar];
      lastLegLow = 0;                                                // reset last leg low

      if (Signal.onReversal && __isChart && ChangedBars <= 2) {
         onReversal(D_SHORT, lowerCross[bar]);
      }
   }
   return(true);
}


/**
 * Update the trend[] values of the specified bar range.
 * If fromValue is non-zero, trend[] values are increased per bar. If fromValue is 0, trend[] values are not increased.
 * Also resets all unknownTrend[] values and optionally the reversalOffset[] values of the specified range.
 *
 * @param  int  fromBar        - start bar of the range to update (older)
 * @param  int  fromValue      - start value for the trend counter
 * @param  int  toBar          - end bar of the range to update (younger)
 * @param  bool resetReversals - whether to reset the reversalOffset[] buffer of the bar range
 */
void SetTrend(int fromBar, int fromValue, int toBar, bool resetReversals) {
   resetReversals = resetReversals!=0;
   int value = fromValue, sign, cross;

   for (int i=fromBar; i >= toBar; i--) {
      trend        [i] = value;
      unknownTrend [i] = -1;
      combinedTrend[i] = trend[i];

      if (resetReversals) reversalOffset[i] = -1;

      if      (value > 0) value++;
      else if (value < 0) value--;
   }
}


/**
 * Event handler signaling new ZigZag reversals.
 *
 * @param  int    direction - reversal direction: D_LONG | D_SHORT
 * @param  double level     - the crossed price level causing the signal
 *
 * @return bool - success status
 */
bool onReversal(int direction, double level) {
   if (direction!=D_LONG && direction!=D_SHORT) return(!catch("onReversal(1)  invalid parameter direction: "+ direction, ERR_INVALID_PARAMETER));
   if (!__isChart)                              return(true);
   if (IsPossibleDataPumping()) {               // skip signals during possible data pumping
      logWarn("onReversal(P="+ ZigZag.Periods +")  Tick="+ Ticks +"  alleged data pumping (Bars="+ Bars +"  ValidBars="+ ValidBars +"  ChangedBars="+ ChangedBars +")");
      return(true);
   }

   // skip the signal if it was already handled elsewhere
   string sPeriod   = PeriodDescription();
   string eventName = "rsf::"+ StdSymbol() +","+ sPeriod +"."+ indicatorName +".onReversal("+ direction +")."+ TimeToStr(Time[0]), propertyName = "";
   string message1  = ifString(direction==D_LONG, "up", "down") +" (level: "+ NumberToStr(level, PriceFormat) +")";
   string message2  = Symbol() +","+ sPeriod +": "+ indicatorName +" reversal "+ message1;

   int hWndTerminal=GetTerminalMainWindow(), hWndDesktop=GetDesktopWindow();
   bool eventAction;

   // log: once per terminal
   if (IsLogInfo()) {
      eventAction = true;
      if (!__isTesting) {
         propertyName = eventName +"|log";
         eventAction = !GetWindowPropertyA(hWndTerminal, propertyName);
         SetWindowPropertyA(hWndTerminal, propertyName, 1);
      }
      if (eventAction) logInfo("onReversal(P="+ ZigZag.Periods +")  "+ message1);
   }

   // sound: once per system
   if (signal.onReversal.sound) {
      eventAction = true;
      if (!__isTesting) {
         propertyName = eventName +"|sound";
         eventAction = !GetWindowPropertyA(hWndDesktop, propertyName);
         SetWindowPropertyA(hWndDesktop, propertyName, 1);
      }
      if (eventAction) {
         int error = PlaySoundEx(ifString(direction==D_LONG, Signal.Sound.Up, Signal.Sound.Down));
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
      if (eventAction) Alert(message2);
   }

   // mail: once per system
   if (signal.onReversal.mail) {
      eventAction = true;
      if (!__isTesting) {
         propertyName = eventName +"|mail";
         eventAction = !GetWindowPropertyA(hWndDesktop, propertyName);
         SetWindowPropertyA(hWndDesktop, propertyName, 1);
      }
      if (eventAction) SendEmail("", "", message2, message2 + NL + "("+ TimeToStr(TimeLocalEx("onReversal(2)"), TIME_MINUTES|TIME_SECONDS) +", "+ GetAccountAlias() +")");
   }
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

   // skip the signal if it was already handled elsewhere
   string sPeriod   = PeriodDescription();
   string eventName = "rsf::"+ StdSymbol() +","+ sPeriod +"."+ indicatorName +"(P="+ ZigZag.Periods +").onBreakout("+ direction +")."+ TimeToStr(Time[0]), propertyName = "";
   string message1  = ifString(direction==D_LONG, "long", "short") +" (bid: "+ NumberToStr(_Bid, PriceFormat) +")";
   string message2  = Symbol() +","+ sPeriod +": "+ WindowExpertName() +"("+ ZigZag.Periods +") breakout "+ message1;

   int hWndTerminal=GetTerminalMainWindow(), hWndDesktop=GetDesktopWindow();
   bool eventAction;

   // log: once per terminal
   if (IsLogInfo()) {
      eventAction = true;
      if (!__isTesting) {
         propertyName = eventName +"|log";
         eventAction = !GetWindowPropertyA(hWndTerminal, propertyName);
         SetWindowPropertyA(hWndTerminal, propertyName, 1);
      }
      if (eventAction) logInfo("onBreakout(P="+ ZigZag.Periods +")  "+ message1);
   }

   // sound: once per system
   if (signal.onBreakout.sound) {
      eventAction = true;
      if (!__isTesting) {
         propertyName = eventName +"|sound";
         eventAction = !GetWindowPropertyA(hWndDesktop, propertyName);
         SetWindowPropertyA(hWndDesktop, propertyName, 1);
      }
      if (eventAction) {
         int error = PlaySoundEx(ifString(direction==D_LONG, Signal.Sound.Up, Signal.Sound.Down));
         if (!error) lastSoundSignal = GetTickCount();
      }
   }

   // alert: once per terminal
   if (signal.onBreakout.alert) {
      eventAction = true;
      if (!__isTesting) {
         propertyName = eventName +"|alert";
         eventAction = !GetWindowPropertyA(hWndTerminal, propertyName);
         SetWindowPropertyA(hWndTerminal, propertyName, 1);
      }
      if (eventAction) Alert(message2);
   }

   // mail: once per system
   if (signal.onBreakout.mail) {
      eventAction = true;
      if (!__isTesting) {
         propertyName = eventName +"|mail";
         eventAction = !GetWindowPropertyA(hWndDesktop, propertyName);
         SetWindowPropertyA(hWndDesktop, propertyName, 1);
      }
      if (eventAction) SendEmail("", "", message2, message2 + NL + "("+ TimeToStr(TimeLocalEx("onBreakout(2)"), TIME_MINUTES|TIME_SECONDS) +", "+ GetAccountAlias() +")");
   }
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
 * @param  int    keys   - flags of pressed modifier keys
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

   // TODO: What kind of nonsense is this implementation?

   int waitPeriod = 20 * SECONDS;
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
 * Update the chart legend.
 */
void UpdateChartLegend() {
   static int lastTrend, lastTime, lastAccount;

   // update on full recalculation or if indicator name, trend, current bar or the account changed
   if (!ValidBars || combinedTrend[0]!=lastTrend || Time[0]!=lastTime || AccountNumber()!=lastAccount) {
      string sTrend    = "   "+ NumberToStr(trend[0], "+.");
      string sUnknown  = ifString(!unknownTrend[0], "", "/"+ unknownTrend[0]);
      string sReversal = "   next reversal @" + NumberToStr(ifDouble(trend[0] < 0, upperBand[0]+Point, lowerBand[0]-Point), PriceFormat);
      string sSignal   = ifString(Signal.onReversal, "  "+ legendInfo, "");
      string text      = StringConcatenate(indicatorName, sTrend, sUnknown, sReversal, sSignal);

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
   indicatorName = name +"("+ ZigZag.Periods + ifString(ZigZag.Periods.Step, ":"+ ZigZag.Periods.Step, "") +")";
   shortName     = name +"("+ ZigZag.Periods +")";
   donchianName  = "Donchian("+ ZigZag.Periods +")";
   IndicatorShortName(shortName);

   IndicatorBuffers(terminal_buffers);
   SetIndexBuffer(MODE_UPPER_BAND,      upperBand     ); SetIndexEmptyValue(MODE_UPPER_BAND,       0); SetIndexLabel(MODE_UPPER_BAND,      donchianName +" upper band"); if (!Donchian.ShowChannel) SetIndexLabel(MODE_UPPER_BAND,      NULL);
   SetIndexBuffer(MODE_LOWER_BAND,      lowerBand     ); SetIndexEmptyValue(MODE_LOWER_BAND,       0); SetIndexLabel(MODE_LOWER_BAND,      donchianName +" lower band"); if (!Donchian.ShowChannel) SetIndexLabel(MODE_LOWER_BAND,      NULL);
   SetIndexBuffer(MODE_SEMAPHORE_OPEN,  semaphoreOpen ); SetIndexEmptyValue(MODE_SEMAPHORE_OPEN,   0);                                                                                              SetIndexLabel(MODE_SEMAPHORE_OPEN,  NULL);
   SetIndexBuffer(MODE_SEMAPHORE_CLOSE, semaphoreClose); SetIndexEmptyValue(MODE_SEMAPHORE_CLOSE,  0); SetIndexLabel(MODE_SEMAPHORE_CLOSE, shortName +" high/low");      if (!ZigZag.Width)         SetIndexLabel(MODE_SEMAPHORE_CLOSE, NULL);
   SetIndexBuffer(MODE_UPPER_CROSS,     upperCross    ); SetIndexEmptyValue(MODE_UPPER_CROSS,      0); SetIndexLabel(MODE_UPPER_CROSS,     shortName +" reversal up");   if (!crossingDrawType)     SetIndexLabel(MODE_UPPER_CROSS,     NULL);
   SetIndexBuffer(MODE_LOWER_CROSS,     lowerCross    ); SetIndexEmptyValue(MODE_LOWER_CROSS,      0); SetIndexLabel(MODE_LOWER_CROSS,     shortName +" reversal down"); if (!crossingDrawType)     SetIndexLabel(MODE_LOWER_CROSS,     NULL);
   SetIndexBuffer(MODE_REVERSAL_OFFSET, reversalOffset); SetIndexEmptyValue(MODE_REVERSAL_OFFSET, -1); SetIndexLabel(MODE_REVERSAL_OFFSET, shortName +" reversal offset");
   SetIndexBuffer(MODE_COMBINED_TREND,  combinedTrend ); SetIndexEmptyValue(MODE_COMBINED_TREND,   0); SetIndexLabel(MODE_COMBINED_TREND,  shortName +" trend");
   IndicatorDigits(Digits);

   int drawType  = ifInt(ZigZag.Width, zigzagDrawType, DRAW_NONE);
   int drawWidth = ifInt(zigzagDrawType==DRAW_ZIGZAG, ZigZag.Width, ZigZag.Width-1);
   SetIndexStyle(MODE_SEMAPHORE_OPEN,  drawType, EMPTY, drawWidth, ZigZag.Color); SetIndexArrow(MODE_SEMAPHORE_OPEN,  zigzagSymbol);
   SetIndexStyle(MODE_SEMAPHORE_CLOSE, drawType, EMPTY, drawWidth, ZigZag.Color); SetIndexArrow(MODE_SEMAPHORE_CLOSE, zigzagSymbol);

   drawType = ifInt(Donchian.ShowChannel, DRAW_LINE, DRAW_NONE);
   SetIndexStyle(MODE_UPPER_BAND, drawType, EMPTY, EMPTY, Donchian.Channel.UpperColor);
   SetIndexStyle(MODE_LOWER_BAND, drawType, EMPTY, EMPTY, Donchian.Channel.LowerColor);

   drawType  = ifInt(crossingDrawType && Donchian.Crossing.Width, DRAW_ARROW, DRAW_NONE);
   drawWidth = Donchian.Crossing.Width - 1;                    // minus 1 to use the same scale as ZigZag.Semaphore.Width
   SetIndexStyle(MODE_UPPER_CROSS, drawType, EMPTY, drawWidth, colorOr(Donchian.Crossing.Color, Donchian.Channel.UpperColor)); SetIndexArrow(MODE_UPPER_CROSS, crossingSymbol);
   SetIndexStyle(MODE_LOWER_CROSS, drawType, EMPTY, drawWidth, colorOr(Donchian.Crossing.Color, Donchian.Channel.LowerColor)); SetIndexArrow(MODE_LOWER_CROSS, crossingSymbol);

   SetIndexStyle(MODE_REVERSAL_OFFSET, DRAW_NONE);
   SetIndexStyle(MODE_COMBINED_TREND,  DRAW_NONE);

   if (redraw) WindowRedraw();
   return(!catch("SetIndicatorOptions(1)"));
}


/**
 * Store the status of the parameter stepper in the chart (for init cyles, template reloads or terminal restarts).
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
 * Restore the status of the parameter stepper from the chart.
 *
 * @return bool - success status
 */
bool RestoreStatus() {
   if (!__isChart) return(true);
   string prefix = "rsf."+ WindowExpertName() +".";

   int iValue;
   if (Chart.RestoreInt(prefix +"ZigZag.Periods", iValue)) {   // restore and remove it
      if (ZigZag.Periods.Step > 0) {                           // apply if stepper is still active
         if (iValue >= 2) ZigZag.Periods = iValue;             // silent validation
      }
   }
   return(!catch("RestoreStatus(1)"));
}


/**
 * Return a string representation of all input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("ZigZag.Periods=",                ZigZag.Periods                                +";"+ NL,
                            "ZigZag.Periods.Step=",           ZigZag.Periods.Step                           +";"+ NL,
                            "ZigZag.Type=",                   DoubleQuoteStr(ZigZag.Type)                   +";"+ NL,
                            "ZigZag.Semaphores.Symbol=",      DoubleQuoteStr(ZigZag.Semaphores.Symbol)      +";"+ NL,
                            "ZigZag.Width=",                  ZigZag.Width                                  +";"+ NL,
                            "ZigZag.Color=",                  ColorToStr(ZigZag.Color)                      +";"+ NL,

                            "Donchian.ShowChannel=",          BoolToStr(Donchian.ShowChannel)               +";"+ NL,
                            "Donchian.Channel.UpperColor=",   ColorToStr(Donchian.Channel.UpperColor)       +";"+ NL,
                            "Donchian.Channel.LowerColor=",   ColorToStr(Donchian.Channel.LowerColor)       +";"+ NL,
                            "Donchian.ShowCrossings=",        DoubleQuoteStr(Donchian.ShowCrossings)        +";"+ NL,
                            "Donchian.Crossing.Symbol=",      DoubleQuoteStr(Donchian.Crossing.Symbol)      +";"+ NL,
                            "Donchian.Crossing.Width=",       Donchian.Crossing.Width                       +";"+ NL,
                            "Donchian.Crossing.Color=",       ColorToStr(Donchian.Crossing.Color)           +";"+ NL,

                            "ShowChartLegend=",               BoolToStr(ShowChartLegend)                    +";"+ NL,
                            "MaxBarsBack=",                   MaxBarsBack                                   +";"+ NL,

                            "Signal.onReversal=",             BoolToStr(Signal.onReversal)                  +";"+ NL,
                            "Signal.onReversal.Types=",       DoubleQuoteStr(Signal.onReversal.Types)       +";"+ NL,
                            "Signal.onBreakout=",             BoolToStr(Signal.onBreakout)                  +";"+ NL,
                            "Signal.onBreakout.Types=",       DoubleQuoteStr(Signal.onBreakout.Types)       +";"+ NL,
                            "Signal.Sound.Up=",               DoubleQuoteStr(Signal.Sound.Up)               +";"+ NL,
                            "Signal.Sound.Down=",             DoubleQuoteStr(Signal.Sound.Down)             +";"+ NL,

                            "Sound.onChannelWidening=",       BoolToStr(Sound.onChannelWidening)            +";"+ NL,
                            "Sound.onNewChannelHigh=",        DoubleQuoteStr(Sound.onNewChannelHigh)        +";"+ NL,
                            "Sound.onNewChannelLow=",         DoubleQuoteStr(Sound.onNewChannelLow)         +";"+ NL,

                            "TrackSignalPerformance=",        BoolToStr(TrackSignalPerformance)             +";"+ NL,
                            "TrackSignalPerformance.Since=",  TimeToStr(TrackSignalPerformance.Since)       +";"+ NL,
                            "TrackSignalPerformance.Symbol=", DoubleQuoteStr(TrackSignalPerformance.Symbol) +";")
   );

   // suppress compiler warnings
   icZigZag(NULL, NULL, NULL, NULL);
}
