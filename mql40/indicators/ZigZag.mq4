/**
 * A non-repainting ZigZag indicator suitable for automation
 *
 *
 * MetaQuotes' ZigZag indicator is flawed and poorly implemented. It repaints the calculated swing extremes, at times even
 * two swings back. Also it cannot be used for automation. This indicator doesn't have such issues. Once the ZigZag direction
 * has changed, the change is permanent.
 *
 * - Internally the indicator uses a Donchian Channel for calculation.
 * - The indicator draws vertical line segments if a single price bar crosses both upper and lower Donchian Channel.
 * - The indicator can display the trail of a ZigZag leg as it develops over time.
 * - The display can be switched between full ZigZag lines or just swing extremes (aka ZigZag semaphores).
 * - The indicator supports manual stepping of the ZigZag period via hotkey and provides multiple signaling modes.
 *
 *
 * Input parameters
 * ----------------
 *  • ZigZag.Periods:              Look-back periods of the Donchian Channel.
 *  • ZigZag.Periods.Step:         Option to control parameter "ZigZag.Periods" via keyboard. If non-zero it defines the step
 *                                 size of the parameter stepper. If 0 (zero) parameter stepping is disabled.
 *  • ZigZag.Type:                 Whether to display the ZigZag line or ZigZag semaphores.
 *  • ZigZag.Semaphores.Symbol:    Graphic symbol used for ZigZag semaphores.
 *  • ZigZag.Width:                The ZigZag's line width or semaphore size.
 *  • ZigZag.Color:                Color of ZigZag line or semaphores.
 *
 *  • Donchian.ShowChannel:        Whether to display the internal Donchian Channel.
 *  • Donchian.Channel.UpperColor: Color of upper Donchian Channel band.
 *  • Donchian.Channel.LowerColor: Color of lower Donchian Channel band.
 *
 *  • Donchian.ShowCrossings:      Which Donchian Channel crossings to display, one of:
 *                                  "off":   No crossings are displayed.
 *                                  "first": Only the first crossing is displayed (the moment a new ZigZag leg appears).
 *                                  "all":   All crossings are displayed. Displays the trail of a ZigZag leg as over time.
 *  • Donchian.Crossing.Symbol:    Graphic symbol used for Donchian Channel crossings.
 *  • Donchian.Crossing.Width:     Size of displayed Donchian Channel crossings.
 *  • Donchian.Crossing.Color:     Custom color of channel crossings (default: color of channel bands).
 *
 *  • ShowChartLegend:             Whether do display the chart legend.
 *  • MaxBarsBack:                 Maximum number of bars back to calculate the indicator for (affects performance).
 *
 *  • Signal.onReversal:           Whether to signal ZigZag reversals (the moment a new ZigZag leg appears).
 *  • Signal.onReversal.Types:     Signaling methods, a combination of "sound", "alert", "email" and/or "telegram".
 *
 *  • Signal.onBreakout:           Whether to signal ZigZag breakouts (a ZigZag leg exceeding the previous ZigZag leg).
 *  • Signal.onBreakout.Types:     Signaling methods, a combination of "sound", "alert", "email" and/or "telegram".
 *
 *  • Signal.Sound.Up:             Sound file for signals to the upside.
 *  • Signal.Sound.Down:           Sound file for signals to the downside.
 *
 *  • Sound.onChannelWidening:     Whether to play a sound on Donchian Channel widening (channel crossings).
 *  • Sound.onNewChannelHigh:      Sound file for channel widenings to the upside.
 *  • Sound.onNewChannelLow:       Sound file for channel widenings to the downside.
 *
 *  • CombinedBuffersAsBinary:     for iCustom(): Whether combined buffers are encoded human-readable or binary.
 *  • AutoConfiguration:           If enabled all input parameters can be pre-defined in the configuration.
 *
 *
 * Usage with iCustom()
 * --------------------
 * @see /mql40/include/rsf/functions/iCustom/ZigZag.mqh
 */
#include <rsf/stddefines.mqh>
int   __InitFlags[];
int __DeinitFlags[];

///////////////////////////////////////////////////// Input parameters //////////////////////////////////////////////////////

extern string   ___a__________________________ = "=== ZigZag settings ===";
extern int      ZigZag.Periods                 = 200;                            // look-back periods of the Donchian Channel
extern int      ZigZag.Periods.Step            = 0;                              // step size for parameter stepping
extern string   ZigZag.Type                    = "Lines* | Semaphores";          // ZigZag lines or reversal points (can be shortened)
extern string   ZigZag.Semaphores.Symbol       = "dot* | thin-ring | ring | thick-ring";
extern int      ZigZag.Width                   = 2;
extern color    ZigZag.Color                   = Blue;

extern string   ___b__________________________ = "=== Donchian settings ===";
extern bool     Donchian.ShowChannel           = true;                           // whether to display the Donchian Channel
extern color    Donchian.Channel.UpperColor    = Blue;
extern color    Donchian.Channel.LowerColor    = Red;
extern string   Donchian.ShowCrossings         = "off | first* | all";           // which channel crossings to display
extern string   Donchian.Crossing.Symbol       = "dot | thin-ring | ring | thick-ring*";
extern int      Donchian.Crossing.Width        = 1;
extern color    Donchian.Crossing.Color        = CLR_NONE;

extern string   ___c__________________________ = "=== Display settings ===";
extern bool     ShowChartLegend                = true;
extern int      MaxBarsBack                    = 10000;                          // max. values to calculate (-1: all available)

extern string   ___d__________________________ = "=== Signaling ===";
extern bool     Signal.onReversal              = false;                          // signal ZigZag reversals (first Donchian Channel crossing)
extern string   Signal.onReversal.Types        = "sound* | alert | mail | telegram";

extern bool     Signal.onBreakout              = false;                          // signal ZigZag breakouts
extern string   Signal.onBreakout.Types        = "sound* | alert | mail | telegram";

extern string   Signal.Sound.Up                = "Signal Up.wav";
extern string   Signal.Sound.Down              = "Signal Down.wav";

extern bool     Sound.onChannelWidening        = false;                          // signal Donchian Channel widenings
extern string   Sound.onNewChannelHigh         = "Price Advance.wav";
extern string   Sound.onNewChannelLow          = "Price Decline.wav";

extern string   ___e__________________________ = "";
extern bool     CombinedBuffersAsBinary        = false;                          // binary or human-readable encoding of combined buffers (see notes in file header)

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

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

#property indicator_chart_window
#property indicator_buffers   8                             // buffers managed by the terminal
int       framework_buffers = 4;                            // buffers managed by the framework


// indicator buffer ids
#define MODE_UPPER_BAND        ZigZag.MODE_UPPER_BAND       // 0: upper channel band: positive or 0
#define MODE_LOWER_BAND        ZigZag.MODE_LOWER_BAND       // 1: lower channel band: positive or 0
#define MODE_SEMAPHORE_OPEN    ZigZag.MODE_SEMAPHORE_OPEN   // 2: final semaphores, open price: positive or 0
#define MODE_SEMAPHORE_CLOSE   ZigZag.MODE_SEMAPHORE_CLOSE  // 3: final semaphores, close price: positive or 0 (if open != close it forms a vertical line segment)
#define MODE_UPPER_CROSS       ZigZag.MODE_UPPER_CROSS      // 4: upper channel band crossings: positive or 0
#define MODE_LOWER_CROSS       ZigZag.MODE_LOWER_CROSS      // 5: lower channel band crossings: positive or 0
#define MODE_ZZ_COMBINED       ZigZag.MODE_ZZ_COMBINED      // 6: int: combined buffers MODE_ZZ_TREND and MODE_ZZ_UNKNOWN_TREND (see notes in file header)
#define MODE_REVERSAL_OFFSET   ZigZag.MODE_REVERSAL_OFFSET  // 7: offset of the ZigZag reversal to the leg's start semaphore: non-negative or -1
#define MODE_UPPER_CROSS_HIGH  8                            // bar high of an upper channel band crossing: positive or 0
#define MODE_LOWER_CROSS_LOW   9                            // bar low of a lower channel band crossing: positive or 0
#define MODE_ZZ_TREND         10                            // int: direction and length of a ZigZag leg: positive/negative or 0
#define MODE_ZZ_UNKNOWN_TREND 11                            // int: number of undetermined trend bars after a leg's end semaphore: non-negative or -1

#property indicator_color1    Blue                          // upper channel band
#property indicator_style1    STYLE_DOT                     //
#property indicator_color2    Red                           // lower channel band
#property indicator_style2    STYLE_DOT                     //

#property indicator_color3    DodgerBlue                    // the ZigZag line is built from two buffers using the color of the first buffer
#property indicator_width3    1                             //
#property indicator_color4    CLR_NONE                      //

#property indicator_color5    indicator_color3              // upper channel band crossings
#property indicator_width5    0                             //
#property indicator_color6    indicator_color4              // lower channel band crossings
#property indicator_width6    0                             //

#property indicator_color7    CLR_NONE                      // trend (combined buffers MODE_ZZ_TREND and MODE_ZZ_UNKNOWN_TREND)
#property indicator_color8    CLR_NONE                      // offset of the previous ZigZag reversal to its preceeding semaphore

double   upperBand     [];                                  // upper channel band: positive or 0
double   lowerBand     [];                                  // lower channel band: positive or 0
double   upperCross    [];                                  // upper channel band crossings: positive or 0
double   upperCrossHigh[];                                  // bar high of an upper channel band crossing (potential semaphore): positive or 0
double   lowerCross    [];                                  // lower channel band crossings: positive or 0
double   lowerCrossLow [];                                  // bar low of a lower channel band crossing (potential semaphore): positive or 0
double   semaphoreOpen [];                                  // final semaphore, open price: positive or 0
double   semaphoreClose[];                                  // final semaphore, close price: positive or 0 (if open != close it creates a vertical line segment)
double   zzCombined    [];                                  // combined buffers MODE_TREND and MODE_UNKNOWN_TREND (see notes in file header)
int      zzTrend       [];                                  // direction and length of a ZigZag leg: positive/negative or 0
int      zzUnknownTrend[];                                  // number of undetermined trend bars after a leg's end semaphore: non-negative or -1
double   reversalOffset[];                                  // offset of the ZigZag reversal to the leg's start semaphore (): non-negative or -1

string   indicatorName = "";
string   shortName     = "";
string   legendLabel   = "";
string   legendInfo    = "";                                // additional chart legend info

int      zigzagDrawType;
int      zigzagSymbol;
int      crossingDrawType;
int      crossingSymbol;

#define MODE_FIRST_CROSSING   1                             // draw types of channel crossings
#define MODE_ALL_CROSSINGS    2

bool     signal.onReversal.sound;
bool     signal.onReversal.alert;
bool     signal.onReversal.mail;
bool     signal.onReversal.telegram;

bool     signal.onBreakout.sound;
bool     signal.onBreakout.alert;
bool     signal.onBreakout.mail;
bool     signal.onBreakout.telegram;

double   sema1, sema2, sema3;                               // last 3 semaphores for detection of ZigZag breakouts
double   lastLegHigh, lastLegLow;                           // leg high/low at the previous tick

double   lastUpperBand;                                     // detection of channel widenings
double   lastLowerBand;                                     // upper/lower band values at the previous tick

datetime skipSignals;                                       // skip signals until the specified time to wait for possible data pumping
datetime lastTick;
int      lastSoundSignal;                                   // GetTickCount() value of the last audio signal

// signal direction types
#define D_LONG     TRADE_DIRECTION_LONG                     // 1
#define D_SHORT    TRADE_DIRECTION_SHORT                    // 2

// parameter stepper directions
#define STEP_UP    1
#define STEP_DOWN -1

// event types for reversal balance tracking
#define EVENT_SEMAPHORE_HIGH  1
#define EVENT_SEMAPHORE_LOW   2
#define EVENT_REVERSAL_UP     3
#define EVENT_REVERSAL_DOWN   4


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
//    int    zzTrend       :  0 (default)
//    int    zzUnknownTrend: -1 (default)
//    int    reversalOffset: -1 (default)
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
//    int    zzTrend       :  0 (default)
//    int    zzUnknownTrend: -1 (default) before the last cross, otherwise non-negative
//    int    reversalOffset: -1 (default)
//
// • Bar of ZigZag leg up (no semaphore)
//    double upperBand     :  positive
//    double lowerBand     :  positive
//    double upperCross    :  0 (default) or positive
//    double upperCrossHigh:  0 (default) or positive
//    double lowerCross    :  0 (default)
//    double lowerCrossLow :  0 (default)
//    double semaphoreOpen :  0 (default)
//    double semaphoreClose:  0 (default)
//    int    zzTrend       :  positive
//    int    zzUnknownTrend:  0 or positive
//    int    reversalOffset:  positive
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
//    int    zzTrend       :  negative
//    int    zzUnknownTrend:  0 or positive
//    int    reversalOffset:  positive
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
//    int    zzTrend       :  positive
//    int    zzUnknownTrend:  0
//    int    reversalOffset:  positive
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
//    int    zzTrend       :  negative
//    int    zzUnknownTrend:  0
//    int    reversalOffset:  positive
//
// • Double crossing bar (high + low semaphore) after processing of the 2nd crossing
//    double upperBand     :  positive
//    double lowerBand     :  positive
//    double upperCross    :  positive
//    double upperCrossHigh:  positive
//    double lowerCross    :  positive
//    double lowerCrossLow :  positive
//    double semaphoreOpen :  positive
//    double semaphoreClose:  positive (open != close)
//    int    zzTrend       :  0 (the complete leg ocurred in the same bar)
//    int    zzUnknownTrend:  0 (same as reversal offset)
//    int    reversalOffset:  0 (the previous reversal occurred on the same bar)
//
// • Triple+ crossing bar (more than two semaphores)
//    Same as double crossing. The last crossing overwrites values from previous crossings.


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
   if (ZigZag.Periods < 2) return(catch("onInit(1)  invalid input parameter ZigZag.Periods: "+ ZigZag.Periods, ERR_INVALID_INPUT_PARAMETER));
   // ZigZag.Periods.Step
   if (AutoConfiguration) ZigZag.Periods.Step = GetConfigInt(indicator, "ZigZag.Periods.Step", ZigZag.Periods.Step);
   if (ZigZag.Periods.Step < 0) return(catch("onInit(2)  invalid input parameter ZigZag.Periods.Step: "+ ZigZag.Periods.Step +" (must be >= 0)", ERR_INVALID_INPUT_PARAMETER));
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
   else return(catch("onInit(3)  invalid input parameter ZigZag.Type: "+ DoubleQuoteStr(sValue), ERR_INVALID_INPUT_PARAMETER));
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
   else return(catch("onInit(4)  invalid input parameter ZigZag.Semaphores.Symbol: "+ DoubleQuoteStr(ZigZag.Semaphores.Symbol), ERR_INVALID_INPUT_PARAMETER));
   ZigZag.Semaphores.Symbol = sValue;
   // ZigZag.Width
   if (AutoConfiguration) ZigZag.Width = GetConfigInt(indicator, "ZigZag.Width", ZigZag.Width);
   if (ZigZag.Width < 0) return(catch("onInit(5)  invalid input parameter ZigZag.Width: "+ ZigZag.Width, ERR_INVALID_INPUT_PARAMETER));

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
   else return(catch("onInit(6)  invalid input parameter Donchian.ShowCrossings: "+ DoubleQuoteStr(sValue), ERR_INVALID_INPUT_PARAMETER));
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
   else return(catch("onInit(7)  invalid input parameter Donchian.Crossing.Symbol: "+ DoubleQuoteStr(Donchian.Crossing.Symbol), ERR_INVALID_INPUT_PARAMETER));
   Donchian.Crossing.Symbol = sValue;
   // Donchian.Crossing.Width
   if (AutoConfiguration) Donchian.Crossing.Width = GetConfigInt(indicator, "Donchian.Crossing.Width", Donchian.Crossing.Width);
   if (Donchian.Crossing.Width < 0) return(catch("onInit(8)  invalid input parameter Donchian.Crossing.Width: "+ Donchian.Crossing.Width, ERR_INVALID_INPUT_PARAMETER));
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
      if (!ConfigureSignalTypes(signalId, Signal.onReversal.Types, AutoConfiguration, signal.onReversal.sound, signal.onReversal.alert, signal.onReversal.mail, signal.onReversal.telegram)) {
         return(catch("onInit(10)  invalid input parameter Signal.onReversal.Types: "+ DoubleQuoteStr(Signal.onReversal.Types), ERR_INVALID_INPUT_PARAMETER));
      }
      Signal.onReversal = (signal.onReversal.sound || signal.onReversal.alert || signal.onReversal.mail || signal.onReversal.telegram);
      if (Signal.onReversal) {
         legendInfo = "("+ StrLeft(ifString(signal.onReversal.sound, "sound,", "") + ifString(signal.onReversal.alert, "alert,", "") + ifString(signal.onReversal.mail, "mail,", "") + ifString(signal.onReversal.telegram, "tgm,", ""), -1) +")";
         legendInfo = StrReplace(legendInfo, "sound,alert", "alert");
      }
   }
   // Signal.onBreakout
   signalId = "Signal.onBreakout";
   ConfigureSignals(signalId, AutoConfiguration, Signal.onBreakout);
   if (Signal.onBreakout) {
      if (!ConfigureSignalTypes(signalId, Signal.onBreakout.Types, AutoConfiguration, signal.onBreakout.sound, signal.onBreakout.alert, signal.onBreakout.mail, signal.onBreakout.telegram)) {
         return(catch("onInit(11)  invalid input parameter Signal.onBreakout.Types: "+ DoubleQuoteStr(Signal.onBreakout.Types), ERR_INVALID_INPUT_PARAMETER));
      }
      Signal.onBreakout = (signal.onBreakout.sound || signal.onBreakout.alert || signal.onBreakout.mail || signal.onBreakout.telegram);
   }
   // Signal.Sound.*
   if (AutoConfiguration) Signal.Sound.Up   = GetConfigString(indicator, "Signal.Sound.Up",   Signal.Sound.Up);
   if (AutoConfiguration) Signal.Sound.Down = GetConfigString(indicator, "Signal.Sound.Down", Signal.Sound.Down);
   // Sound.*
   if (AutoConfiguration) Sound.onChannelWidening = GetConfigBool(indicator, "Sound.onChannelWidening", Sound.onChannelWidening);
   if (AutoConfiguration) Sound.onNewChannelHigh  = GetConfigString(indicator, "Sound.onNewChannelHigh", Sound.onNewChannelHigh);
   if (AutoConfiguration) Sound.onNewChannelLow   = GetConfigString(indicator, "Sound.onNewChannelLow", Sound.onNewChannelLow);
   if (Sound.onChannelWidening) {
      if (legendInfo == "") legendInfo = "(w)";
      else                  legendInfo = StrLeft(legendInfo, -1) +",w)";
   }

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

   // Indicator events "reversal" and "breakout" occur on tick, not on "bar-open" or "bar-close".
   // We need a chart ticker to prevent invalid signals caused by ticks during data pumping.
   if (!__isTesting && !__virtualTicksTimerId) {
      int hWnd = __ExecutionContext[EC.chart];
      int millis = 2000;                                         // a virtual tick every 2 seconds
      __virtualTicksTimerId = SetupTickTimer(hWnd, millis, NULL);
      if (!__virtualTicksTimerId) return(catch("onInit(13)->SetupTickTimer() failed", ERR_RUNTIME_ERROR));
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
   if (__virtualTicksTimerId > 0) {
      int tmp = __virtualTicksTimerId;
      __virtualTicksTimerId = NULL;
      if (!ReleaseTickTimer(tmp)) return(catch("onDeinit(1)->ReleaseTickTimer(timerId="+ tmp +") failed", ERR_RUNTIME_ERROR));
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
   if (__isChart && ZigZag.Periods.Step) {
      if (!HandleCommands("ParameterStepper")) return(last_error);
   }

   // manage additional framework buffers
   ManageDoubleIndicatorBuffer(MODE_UPPER_CROSS_HIGH, upperCrossHigh    );
   ManageDoubleIndicatorBuffer(MODE_LOWER_CROSS_LOW,  lowerCrossLow     );
   ManageIntIndicatorBuffer   (MODE_ZZ_TREND,         zzTrend           );
   ManageIntIndicatorBuffer   (MODE_ZZ_UNKNOWN_TREND, zzUnknownTrend, -1);

   // reset buffers before performing a full recalculation
   if (!ValidBars) {
      ArrayInitialize(upperBand,       0);   // double: positive or 0
      ArrayInitialize(lowerBand,       0);   // double: positive or 0
      ArrayInitialize(upperCross,      0);   // double: positive or 0
      ArrayInitialize(upperCrossHigh,  0);   // double: positive or 0
      ArrayInitialize(lowerCross,      0);   // double: positive or 0
      ArrayInitialize(lowerCrossLow,   0);   // double: positive or 0
      ArrayInitialize(semaphoreOpen,   0);   // double: positive or 0
      ArrayInitialize(semaphoreClose,  0);   // double: positive or 0
      ArrayInitialize(zzCombined,      0);   // int:    positive/negative or 0
      ArrayInitialize(zzTrend,         0);   // int:    positive/negative or 0
      ArrayInitialize(zzUnknownTrend, -1);   // int:    non-negative or -1
      ArrayInitialize(reversalOffset, -1);   // int:    non-negative or -1
      SetIndicatorOptions();

      lastUpperBand = 0;
      lastLowerBand = 0;
      lastLegHigh   = 0;
      lastLegLow    = 0;
      sema1         = 0;
      sema2         = 0;
      sema3         = 0;
   }

   // synchronize buffers with a shifted offline chart
   if (ShiftedBars > 0) {
      ShiftDoubleIndicatorBuffer(upperBand,      Bars, ShiftedBars,  0);
      ShiftDoubleIndicatorBuffer(lowerBand,      Bars, ShiftedBars,  0);
      ShiftDoubleIndicatorBuffer(upperCross,     Bars, ShiftedBars,  0);
      ShiftDoubleIndicatorBuffer(upperCrossHigh, Bars, ShiftedBars,  0);
      ShiftDoubleIndicatorBuffer(lowerCross,     Bars, ShiftedBars,  0);
      ShiftDoubleIndicatorBuffer(lowerCrossLow,  Bars, ShiftedBars,  0);
      ShiftDoubleIndicatorBuffer(semaphoreOpen,  Bars, ShiftedBars,  0);
      ShiftDoubleIndicatorBuffer(semaphoreClose, Bars, ShiftedBars,  0);
      ShiftDoubleIndicatorBuffer(zzCombined,     Bars, ShiftedBars,  0);
      ShiftIntIndicatorBuffer   (zzTrend,        Bars, ShiftedBars,  0);
      ShiftIntIndicatorBuffer   (zzUnknownTrend, Bars, ShiftedBars, -1);
      ShiftDoubleIndicatorBuffer(reversalOffset, Bars, ShiftedBars, -1);
   }

   // check data pumping on every tick so the reversal handler can skip errornous signals
   if (!__isTesting) IsPossibleDataPumping();

   // calculate start bar
   int startBar = Min(MaxBarsBack-1, ChangedBars-1, Bars-ZigZag.Periods);
   if (startBar < 0 && MaxBarsBack) return(logInfo("onTick(1)  Tick="+ Ticks +"  Bars="+ Bars +"  needed="+ ZigZag.Periods, ERR_HISTORY_INSUFFICIENT));

   // recalculate changed bars
   for (int bar=startBar; bar >= 0; bar--) {
      // reset the bar to update
      upperBand     [bar] =  0;
      lowerBand     [bar] =  0;
      upperCross    [bar] =  0;
      upperCrossHigh[bar] =  0;
      lowerCross    [bar] =  0;
      lowerCrossLow [bar] =  0;
      semaphoreOpen [bar] =  0;
      semaphoreClose[bar] =  0;
      zzCombined    [bar] =  0;
      zzTrend       [bar] =  0;
      zzUnknownTrend[bar] = -1;
      reversalOffset[bar] = -1;

      // recalculate Donchian Channel
      if (bar > 0) {
         upperBand[bar] = High[iHighest(NULL, NULL, MODE_HIGH, ZigZag.Periods, bar)];
         lowerBand[bar] =  Low[ iLowest(NULL, NULL, MODE_LOW,  ZigZag.Periods, bar)];
      }
      else {
         upperBand[bar] = MathMax(upperBand[1], High[0]);
         lowerBand[bar] = MathMin(lowerBand[1],  Low[0]);
      }

      // recalculate channel crossings
      if (upperBand[bar] > upperBand[bar+1] && upperBand[bar+1]) {
         upperCross    [bar] = upperBand[bar+1] + Point;
         upperCrossHigh[bar] = upperBand[bar];
      }
      if (lowerBand[bar] < lowerBand[bar+1]) {
         lowerCross   [bar] = lowerBand[bar+1] - Point;
         lowerCrossLow[bar] = lowerBand[bar];
      }

      // whether the processed bar is a reversal bar (not whether the current tick triggered the reversal)
      bool isReversalBar = false, isDoubleCross = false, cross1_isReversalBar = false, isUpperCrossLast = false;

      // recalculate ZigZag data
      // if no channel crossing                                      // before or after the first semaphore
      if (!upperCross[bar] && !lowerCross[bar]) {
         zzTrend       [bar] = zzTrend       [bar+1];                // keep trend (may be 0)
         zzUnknownTrend[bar] = zzUnknownTrend[bar+1];                // get previous unknown trend
         if (zzUnknownTrend[bar] > -1) {
            zzUnknownTrend[bar]++;                                   // increase if it was set
         }
         reversalOffset[bar] = reversalOffset[bar+1];                // keep reversal offset (may be -1)
      }

      // if two channel crossings (upper and lower band crossed by the same bar)
      else if (upperCross[bar] && lowerCross[bar]) {
         isDoubleCross    = true;
         isUpperCrossLast = IsUpperCrossLast(bar);
         if (isUpperCrossLast) {
            cross1_isReversalBar = ProcessLowerCross(bar);           // process both crossings in order
            isReversalBar        = ProcessUpperCross(bar);
         }
         else {
            cross1_isReversalBar = ProcessUpperCross(bar);           // process both crossings in order
            isReversalBar        = ProcessLowerCross(bar);
         }
      }

      // else a single channel crossing (before or after the first semaphore)
      else if (!lowerCross[bar]) isReversalBar = ProcessUpperCross(bar);
      else                       isReversalBar = ProcessLowerCross(bar);

      // hide non-configured crossings
      if (isReversalBar && crossingDrawType==MODE_FIRST_CROSSING) {  // hide all crossings except the 1st
         if (isDoubleCross && !cross1_isReversalBar) {               // whether the 1st of a double crossing created a reversal bar
            if (isUpperCrossLast) lowerCross[bar] = 0;
            else                  upperCross[bar] = 0;
         }
         // keep the 2nd crossing (it's the 1st crossing of the final leg)
      }
      else if (crossingDrawType != MODE_ALL_CROSSINGS) {             // hide all crossings
         upperCross[bar] = 0;
         lowerCross[bar] = 0;
      }

      // set combined buffers
      if (CombinedBuffersAsBinary) {                                          // iCustom(): binary format
         int short_trend        = zzTrend[bar]        & 0x0000FFFF;           // convert `signed int` to `signed short`
         int short_unknownTrend = zzUnknownTrend[bar] & 0x0000FFFF;           // ...
         zzCombined[bar]        = (short_unknownTrend << 16) | short_trend;   // store as HIWORD + LOWORD
      }
      else {                                                                  // "Data Window": human-readable format
         zzCombined[bar] = ifInt(zzTrend[bar] >= 0, +1, -1) * zzUnknownTrend[bar] * 100000 + zzTrend[bar];
      }
   }

   if (__isChart && !__isSuperContext) {
      if (ShowChartLegend) UpdateChartLegend();

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
               bar   = FindSemaphore(bar, resultType, resultType); if (bar < 0) break;
               sema1 = ifDouble(resultType==MODE_HIGH, High[bar], Low[bar]);
               bar   = FindSemaphore(bar, resultType, resultType); if (bar < 0) break;
               sema2 = ifDouble(resultType==MODE_HIGH, High[bar], Low[bar]);
               bar   = FindSemaphore(bar, resultType, resultType); if (bar < 0) break;
               sema3 = ifDouble(resultType==MODE_HIGH, High[bar], Low[bar]);
               break;
            }
         }
         else if (sema3 != 0) {
            if (zzTrend[0] > 0) {
               if (lastLegHigh < sema2+HalfPoint && upperBand[0] > sema2+HalfPoint) {
                  onBreakout(D_LONG);
               }
               lastLegHigh = High[zzUnknownTrend[0]];             // leg high for comparison at the nex tick
            }
            else if (zzTrend[0] < 0) {
               if ((!lastLegLow || lastLegLow > sema2-HalfPoint) && lowerBand[0] < sema2-HalfPoint) {
                  onBreakout(D_SHORT);
               }
               lastLegLow = Low[zzUnknownTrend[0]];               // leg low for comparison at the nex tick
            }
         }
      }

      // detect Donchian Channel widenings
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
 * Find the most recent ZigZag semaphore starting at the specified bar offset looking backwards. On a semaphore bar the
 * semaphore of the bar itself is returned. Specify a semaphore type to be skipped to prevent this.
 *
 * @param  _In_  int bar                 - bar to start searching from
 * @param  _Out_ int resultType          - type of the found semaphore: MODE_HIGH | MODE_LOW
 * @param  _In_  int skipType [optional] - semaphore on the start bar to be skipped: MODE_HIGH | MODE_LOW (default: none)
 *
 * @return int - chart offset of the found semaphore;
 *               EMPTY (-1) if no semaphore was found or in case of errors
 *
 * Note: A processed bar (history) will hold valid data while an unprocessed bar may hold no data at all. In this case the
 *       function will just look backwards.
 */
int FindSemaphore(int bar, int &resultType, int skipType = NULL) {
   if (bar < 0 || bar >= Bars)                       return(_EMPTY(catch("FindSemaphore(1)  invalid parameter bar: "+ bar +" (out of range)", ERR_INVALID_PARAMETER)));
   if (skipType != NULL) {
      if (skipType!=MODE_HIGH && skipType!=MODE_LOW) return(_EMPTY(catch("FindSemaphore(2)  invalid parameter skipType: "+ skipType, ERR_INVALID_PARAMETER)));
   }

   // if no skipping (no skip type or not a semaphore bar), then return the next semaphore
   if (!skipType || !semaphoreClose[bar]) {
      if (!semaphoreClose[bar]) {                                    // semaphore is located somewhere before
         bar++;                                                      // causes ProcessUpper/LowerCross() to work on a completed bar
      }
      if (!semaphoreClose[bar] && zzUnknownTrend[bar] > 0) {         // navigate to the leg's end semaphore (if any),
         bar += zzUnknownTrend[bar];
      }
      if (!semaphoreClose[bar] && zzTrend[bar]) {                    // navigate to the leg's start semaphore (if any)
         bar += Abs(zzTrend[bar]);
      }
      if (!semaphoreClose[bar]) {
         return(EMPTY);
      }
      if      (!lowerCrossLow [bar])                                resultType = MODE_HIGH;
      else if (!upperCrossHigh[bar])                                resultType = MODE_LOW;
      else if (semaphoreOpen [bar] < semaphoreClose[bar]-HalfPoint) resultType = MODE_HIGH;
      else if (semaphoreOpen [bar] > semaphoreClose[bar]+HalfPoint) resultType = MODE_LOW;
      // from here it holds: semaphoreOpen == semaphoreClose
      else if (semaphoreClose[bar] > upperCrossHigh[bar]-HalfPoint) resultType = MODE_HIGH;
      else                                                          resultType = MODE_LOW;
      return(bar);
   }

   // on a semaphore bar: skip the specified semaphore type (used by ZigZag breakout tracking and TrackZigZagBalance)

   // either the bar holds a single semaphore
   if (semaphoreOpen[bar] == semaphoreClose[bar]) {
      bool isHigh = (semaphoreClose[bar] > upperCrossHigh[bar]-HalfPoint);

      if (skipType == MODE_HIGH) {
         if (isHigh) {
            return(FindSemaphore(bar+1, resultType));
         }
         resultType = MODE_LOW;
      }
      else /*skipType == MODE_LOW*/ {
         if (!isHigh) {
            return(FindSemaphore(bar+1, resultType));
         }
         resultType = MODE_HIGH;
      }
      return(bar);
   }

   // or the bar holds two semaphores
   bool high2low = (semaphoreOpen[bar] > semaphoreClose[bar]+HalfPoint);

   if (skipType == MODE_HIGH) {
      if (high2low) {
         return(FindSemaphore(bar+1, resultType));
      }
      resultType = MODE_LOW;
   }
   else /*skipType == MODE_LOW*/ {
      if (!high2low) {
         return(FindSemaphore(bar+1, resultType));
      }
      resultType = MODE_HIGH;
   }
   return(bar);
}


/**
 * Update buffers at the specified bar offset after an upper channel band crossing. Resolves the preceeding ZigZag semaphore
 * and counts the trend forward from there.
 *
 * If bar 0 (zero) crosses the upper band this function will be called for all following ticks of the bar, even for ticks
 * below the crossing level.
 *
 * @param  int bar - offset
 *
 * @return bool - whether the bar is a reversal bar (not whether the current tick triggered the reversal)
 */
bool ProcessUpperCross(int bar) {
   int lastSemType, lastSemBar = FindSemaphore(bar, lastSemType);       // find the last semaphore

   // an upper cross without a previous semaphore (near MaxBarsBack)
   if (lastSemBar < 0) {
      semaphoreOpen [bar] = upperCrossHigh[bar];                        // set new semaphore
      semaphoreClose[bar] = upperCrossHigh[bar];
      zzTrend       [bar] = 0;                                          // no ZZ trend
      zzUnknownTrend[bar] = 0;                                          // current bar
      reversalOffset[bar] = -1;                                         // no reversal
      return(false);
   }
   bool isReversalBar;

   // another upper cross of a leg up extension
   if (lastSemType == MODE_HIGH) {                                      // it holds: lastSemBar != bar
      if (upperCrossHigh[bar] > upperCrossHigh[lastSemBar]) {           // an uptrend continuation
         if (semaphoreOpen[lastSemBar] == semaphoreClose[lastSemBar]) {
            semaphoreOpen[lastSemBar] = 0;                              // update previous semaphore
         }
         semaphoreClose[lastSemBar] = semaphoreOpen[lastSemBar];
         semaphoreOpen [bar]        = upperCrossHigh[bar];              // set new semaphore
         semaphoreClose[bar]        = upperCrossHigh[bar];
         SetTrend(lastSemBar-1, zzTrend[lastSemBar]+1, bar, false);     // update existing trend
      }
      else {                                                            // a lower High (unknown direction)
         zzTrend       [bar] = zzTrend       [bar+1];                   // keep trend (may be 0)
         zzUnknownTrend[bar] = zzUnknownTrend[bar+1] + 1;               // increase unknown trend
      }
      reversalOffset[bar] = reversalOffset[bar+1];                      // keep reversal offset
      isReversalBar = false;
   }

   else /*lastSemType == MODE_LOW*/ {
      if (lastSemBar == bar) {
         // if on the same bar then this crossing is the 2nd of a double crossing
         semaphoreClose[bar] = upperCrossHigh[bar];                     // keep semaphoreOpen from first crossing
         zzTrend       [bar] = 0;
         zzUnknownTrend[bar] = 0;
         reversalOffset[bar] = 0;
         isReversalBar = true;
      }
      else /*lastSemBar != bar*/ {
         // cross is a regular reversal from "short" to "long" (new leg up)
         // or an extension of an existing up leg on bar 0
         semaphoreOpen [bar] = upperCrossHigh[bar];                     // set/update semaphore
         semaphoreClose[bar] = upperCrossHigh[bar];

         if      (zzTrend[bar+1] > 0) bool isNewLeg = false;
         else if (zzTrend[bar+1] < 0)      isNewLeg = true;
         else   /*zzTrend[bar+1] == 0*/{                                // lastSemType was a double crossing at lastSemBar time
            if (semaphoreOpen[lastSemBar] != semaphoreClose[lastSemBar]) {
               isNewLeg = true;                                         // If still a double crossing, then it's "High-Low" and
            }                                                           // this is a new leg up.
            else {
               isNewLeg = (bar != 0);                                   // If not a double crossing anymore, then it was
            }                                                           // "Low-High" and this is a leg extension on bar 0.
         }
         if (isNewLeg) {                                                // new leg up
            SetTrend(lastSemBar-1, 1, bar, true);                       // update trend/unknownTrend, reset reversals and
            reversalOffset[bar] = lastSemBar - bar;                     // set reversal to current bar
            isReversalBar = true;
         }
         else {                                                         // leg up extension
            SetTrend(lastSemBar-1, 1, bar, false);                      // update trend/unknownTrend and
            reversalOffset[bar] = reversalOffset[bar+1];                // keep existing reversal
            isReversalBar = false;
            if (reversalOffset[bar] == -1) {
               reversalOffset[bar] = lastSemBar - bar;                  // if in reversal bar: set to current bar
               isReversalBar = true;
            }
         }
      }

      //sema3 = sema2;
      //sema2 = sema1;
      //sema1 = Low[lastSemBar];
      //lastLegHigh = 0;

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
         // log reversal
         if (IsLogInfo()) {
            string sCrossLevel = NumberToStr(upperCross[bar], PriceFormat);
            bool logReversal = true;
            if (!__isSuperContext && !__isTesting) {        // once per terminal
               int hWndTerminal = GetTerminalMainWindow();
               string eventName = "rsf::"+ StdSymbol() +","+ PeriodDescription() +"."+ WindowExpertName() +"("+ ZigZag.Periods +")" +".ProcessUpperCross("+ sCrossLevel +")."+ TimeToStr(Time[bar]);
               logReversal = !GetWindowPropertyA(hWndTerminal, eventName);
               SetWindowPropertyA(hWndTerminal, eventName, 1);
            }
            if (logReversal) logInfo("onReversal(P="+ ZigZag.Periods +")  reversal up (level: "+ sCrossLevel +")");
         }

         // signal reversal
         if (Signal.onReversal) {
            onReversal(bar, D_LONG, upperCross[bar]);
         }
      }
   }
   return(isReversalBar);
}


/**
 * Update buffers at the specified bar offset after a lower channel band crossing. Resolves the preceeding ZigZag semaphore
 * and counts the trend forward from there.
 *
 * If bar 0 (zero) crosses the lower band this function will be called for all following ticks of the bar, even for ticks
 * above the crossing level.
 *
 * @param  int bar - offset
 *
 * @return bool - whether the bar is a reversal bar (not whether the current tick triggered the reversal)
 */
bool ProcessLowerCross(int bar) {
   int lastSemType, lastSemBar = FindSemaphore(bar, lastSemType);       // find the last semaphore

   // a lower cross without a previous semaphore (near MaxBarsBack)
   if (lastSemBar < 0) {
      semaphoreOpen [bar] = lowerCrossLow[bar];                         // set new semaphore
      semaphoreClose[bar] = lowerCrossLow[bar];
      zzTrend       [bar] = 0;                                          // no ZZ trend
      zzUnknownTrend[bar] = 0;                                          // current bar
      reversalOffset[bar] = -1;                                         // no reversal
      return(false);
   }
   bool isReversalBar;

   // another lower cross of a leg down extension
   if (lastSemType == MODE_LOW) {                                       // it holds: lastSemBar != bar
      if (lowerCrossLow[bar] < lowerCrossLow[lastSemBar]) {             // a downtrend continuation
         if (semaphoreOpen[lastSemBar] == semaphoreClose[lastSemBar]) {
            semaphoreOpen[lastSemBar] = 0;                              //update previous semaphore
         }
         semaphoreClose[lastSemBar] = semaphoreOpen[lastSemBar];
         semaphoreOpen [bar]        = lowerCrossLow[bar];               // set new semaphore
         semaphoreClose[bar]        = lowerCrossLow[bar];
         SetTrend(lastSemBar-1, zzTrend[lastSemBar]-1, bar, false);     // update existing trend
      }
      else {                                                            // a higher Low (unknown direction)
         zzTrend       [bar] = zzTrend       [bar+1];                   // keep trend (may be 0)
         zzUnknownTrend[bar] = zzUnknownTrend[bar+1] + 1;               // increase unknown trend
      }
      reversalOffset[bar] = reversalOffset[bar+1];                      // keep reversal offset
      isReversalBar = false;
   }

   else /*lastSemType == MODE_HIGH*/ {
      if (lastSemBar == bar) {
         // if on the same bar then this crossing is the 2nd of a double crossing
         semaphoreClose[bar] = lowerCrossLow[bar];                      // keep semaphoreOpen from first crossing
         zzTrend       [bar] = 0;
         zzUnknownTrend[bar] = 0;
         reversalOffset[bar] = 0;
         isReversalBar = true;
      }
      else /*lastSemBar != bar*/ {
         // cross is a regular reversal from "long" to "short" (new leg down)
         // or an extension of an existing down leg on bar 0
         semaphoreOpen [bar] = lowerCrossLow[bar];                      // set/update semaphore
         semaphoreClose[bar] = lowerCrossLow[bar];

         if      (zzTrend[bar+1] > 0) bool isNewLeg = true;
         else if (zzTrend[bar+1] < 0)      isNewLeg = false;
         else   /*zzTrend[bar+1] == 0*/{                                // lastSemType was a double crossing at lastSemBar time
            if (semaphoreOpen[lastSemBar] != semaphoreClose[lastSemBar]) {
               isNewLeg = true;                                         // If still a double crossing, then it's "Low-High" and
            }                                                           // this is a new leg down.
            else {
               isNewLeg = (bar != 0);                                   // If not a double crossing anymore, then it was
            }                                                           // "High-Low" and this is a leg extension on bar 0.
         }
         if (isNewLeg) {                                                // new leg down
            SetTrend(lastSemBar-1, -1, bar, true);                      // update trend/unknownTrend, reset reversals and
            reversalOffset[bar] = lastSemBar - bar;                     // set reversal to current bar
            isReversalBar = true;
         }
         else {                                                         // leg down extension
            SetTrend(lastSemBar-1, -1, bar, false);                     // update trend/unknownTrend and
            reversalOffset[bar] = reversalOffset[bar+1];                // keep existing reversal
            isReversalBar = false;
            if (reversalOffset[bar] == -1) {
               reversalOffset[bar] = lastSemBar - bar;                  // if in reversal bar: set to current bar
               isReversalBar = true;
            }
         }
      }

      //sema3 = sema2;
      //sema2 = sema1;
      //sema1 = High[lastSemBar];
      //lastLegLow = 0;

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
         // log reversal
         if (IsLogInfo()) {
            string sCrossLevel = NumberToStr(lowerCross[bar], PriceFormat);
            bool logReversal = true;
            if (!__isSuperContext && !__isTesting) {        // once per terminal
               int hWndTerminal = GetTerminalMainWindow();
               string eventName = "rsf::"+ StdSymbol() +","+ PeriodDescription() +"."+ WindowExpertName() +"("+ ZigZag.Periods +")" +".ProcessLowerCross("+ sCrossLevel +")."+ TimeToStr(Time[bar]);
               logReversal = !GetWindowPropertyA(hWndTerminal, eventName);
               SetWindowPropertyA(hWndTerminal, eventName, 1);
            }
            if (logReversal) logInfo("onReversal(P="+ ZigZag.Periods +")  reversal down (level: "+ sCrossLevel +")");
         }

         // signal reversal
         if (Signal.onReversal) {
            onReversal(bar, D_SHORT, lowerCross[bar]);
         }
      }
   }
   return(isReversalBar);
}


/**
 * Update the ZigZag trend values of the specified bar range:
 * - If fromValue is non-zero, zzTrend[] values are increased per bar. Otherwise zzTrend[] values are not increased.
 * - All zzUnknownTrend[] values of the range are set to 0 (zero).
 * - Optionally all reversalOffset[] values of the range are reset to -1 (EMPTY).
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
      zzTrend       [i] = value;
      zzUnknownTrend[i] = 0;

      if (resetReversals) reversalOffset[i] = -1;

      if (CombinedBuffersAsBinary) {               // iCustom(): binary format
         zzCombined[i] = zzTrend[i] & 0x0000FFFF;  // convert to `signed short` and store as HIWORD + LOWORD
      }
      else {
         zzCombined[i] = zzTrend[i];               // "Data Window": human-readable format
      }

      if      (value > 0) value++;
      else if (value < 0) value--;
   }
}


/**
 * Event handler for new ZigZag reversals (on current tick).
 *
 * @param  int    bar       - bar which triggered the reversal: 0 or 1
 * @param  int    direction - reversal direction: D_LONG | D_SHORT
 * @param  double level     - the price level causing the event (cross of upper/lower channel band)
 *
 * @return bool - success status
 */
bool onReversal(int bar, int direction, double level) {
   if (direction!=D_LONG && direction!=D_SHORT) return(!catch("onReversal(1)  invalid parameter direction: "+ direction, ERR_INVALID_PARAMETER));
   if (IsPossibleDataPumping())                 return(true);

   // skip the signal if it was already handled elsewhere
   string sPeriod    = PeriodDescription();
   string sName      = WindowExpertName() +"("+ ZigZag.Periods +")";
   string sDirection = ifString(direction==D_LONG, "up", "down");
   string eventName  = "rsf::"+ StdSymbol() +","+ sPeriod +"."+ sName +".onReversal("+ sDirection +")."+ TimeToStr(Time[bar]), propertyName = "";
   string message    = Symbol() +","+ sPeriod +": "+ sName +" reversal "+ sDirection +" (level: "+ NumberToStr(level, PriceFormat) +")";
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
   string localTime = TimeToStr(TimeLocalEx("onBreakout(2)"), TIME_MINUTES|TIME_SECONDS);
   string accountAlias = GetAccountAlias();

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
      if (eventAction) SendEmail("", "", message2, message2 + NL +"("+ localTime +", "+ accountAlias +")");
   }

   // Telegram: once per system
   if (signal.onBreakout.telegram) {
      eventAction = true;
      if (!__isTesting) {
         propertyName = eventName +"|telegram";
         eventAction = !GetWindowPropertyA(hWndDesktop, propertyName);
         SetWindowPropertyA(hWndDesktop, propertyName, 1);
      }
      if (eventAction) SendTelegramMessage("signal", message2 + NL +"("+ localTime +", "+ accountAlias +")");
   }
   return(!catch("onBreakout(3)"));
}


/**
 * Event handler signaling Donchian Channel widenings.
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
      if (params == "up")   return(ParameterStepper(STEP_UP,   keys));
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
 * Update the chart legend.
 */
void UpdateChartLegend() {
   static int lastZzCombined, lastTime, lastAccount;

   // update on full recalculation or if indicator name, trend, current bar or the account changed
   if (!ValidBars || zzCombined[0]!=lastZzCombined || Time[0]!=lastTime || AccountNumber()!=lastAccount) {
      string sTrend    = "   "+ NumberToStr(zzTrend[0], "+.");
      string sUnknown  = ifString(!zzUnknownTrend[0], "", "/"+ zzUnknownTrend[0]);
      string sReversal = "   next reversal @" + NumberToStr(ifDouble(zzTrend[0] < 0, upperBand[0]+Point, lowerBand[0]-Point), PriceFormat);
      string sSignal   = ifString(Signal.onReversal || Sound.onChannelWidening, "  "+ legendInfo, "");
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

      lastZzCombined = zzCombined[0];
      lastTime       = Time[0];
      lastAccount    = AccountNumber();
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

   indicatorName = WindowExpertName() +"("+ ZigZag.Periods + ifString(ZigZag.Periods.Step, ":"+ ZigZag.Periods.Step, "") +")";
   shortName     = WindowExpertName() +"("+ ZigZag.Periods +")";
   string donchianName = "Donchian("+ ZigZag.Periods +")";
   IndicatorShortName(shortName);

   IndicatorBuffers(indicator_buffers);
   SetIndexBuffer(MODE_UPPER_BAND,      upperBand     ); SetIndexEmptyValue(MODE_UPPER_BAND,       0); SetIndexLabel(MODE_UPPER_BAND,      donchianName +" upper band");  if (!Donchian.ShowChannel) SetIndexLabel(MODE_UPPER_BAND,      NULL);
   SetIndexBuffer(MODE_LOWER_BAND,      lowerBand     ); SetIndexEmptyValue(MODE_LOWER_BAND,       0); SetIndexLabel(MODE_LOWER_BAND,      donchianName +" lower band");  if (!Donchian.ShowChannel) SetIndexLabel(MODE_LOWER_BAND,      NULL);
   SetIndexBuffer(MODE_SEMAPHORE_OPEN,  semaphoreOpen ); SetIndexEmptyValue(MODE_SEMAPHORE_OPEN,   0);                                                                                               SetIndexLabel(MODE_SEMAPHORE_OPEN,  NULL);
   SetIndexBuffer(MODE_SEMAPHORE_CLOSE, semaphoreClose); SetIndexEmptyValue(MODE_SEMAPHORE_CLOSE,  0); SetIndexLabel(MODE_SEMAPHORE_CLOSE, shortName +" high/low");       if (!ZigZag.Width)         SetIndexLabel(MODE_SEMAPHORE_CLOSE, NULL);
   SetIndexBuffer(MODE_UPPER_CROSS,     upperCross    ); SetIndexEmptyValue(MODE_UPPER_CROSS,      0); SetIndexLabel(MODE_UPPER_CROSS,     shortName +" extension up");   if (!crossingDrawType)     SetIndexLabel(MODE_UPPER_CROSS,     NULL);
   SetIndexBuffer(MODE_LOWER_CROSS,     lowerCross    ); SetIndexEmptyValue(MODE_LOWER_CROSS,      0); SetIndexLabel(MODE_LOWER_CROSS,     shortName +" extension down"); if (!crossingDrawType)     SetIndexLabel(MODE_LOWER_CROSS,     NULL);
   SetIndexBuffer(MODE_ZZ_COMBINED,     zzCombined    ); SetIndexEmptyValue(MODE_ZZ_COMBINED,      0); SetIndexLabel(MODE_ZZ_COMBINED,     shortName +" trend");
   SetIndexBuffer(MODE_REVERSAL_OFFSET, reversalOffset); SetIndexEmptyValue(MODE_REVERSAL_OFFSET, -1); SetIndexLabel(MODE_REVERSAL_OFFSET, shortName +" reversal");
   IndicatorDigits(Digits);

   int drawType  = ifInt(ZigZag.Width, zigzagDrawType, DRAW_NONE);
   int drawWidth = ifInt(zigzagDrawType==DRAW_ZIGZAG, ZigZag.Width, ZigZag.Width-1);
   SetIndexStyle(MODE_SEMAPHORE_OPEN,  drawType, EMPTY, drawWidth, ZigZag.Color); SetIndexArrow(MODE_SEMAPHORE_OPEN,  zigzagSymbol);
   SetIndexStyle(MODE_SEMAPHORE_CLOSE, drawType, EMPTY, drawWidth, ZigZag.Color); SetIndexArrow(MODE_SEMAPHORE_CLOSE, zigzagSymbol);

   drawType = ifInt(Donchian.ShowChannel, DRAW_LINE, DRAW_NONE);
   SetIndexStyle(MODE_UPPER_BAND, drawType, EMPTY, EMPTY, Donchian.Channel.UpperColor);
   SetIndexStyle(MODE_LOWER_BAND, drawType, EMPTY, EMPTY, Donchian.Channel.LowerColor);

   drawType  = ifInt(crossingDrawType && Donchian.Crossing.Width, DRAW_ARROW, DRAW_NONE);
   drawWidth = Donchian.Crossing.Width - 1;         // minus 1 to map valid symbol size "0" to a positive value
   SetIndexStyle(MODE_UPPER_CROSS, drawType, EMPTY, drawWidth, colorOr(Donchian.Crossing.Color, Donchian.Channel.UpperColor)); SetIndexArrow(MODE_UPPER_CROSS, crossingSymbol);
   SetIndexStyle(MODE_LOWER_CROSS, drawType, EMPTY, drawWidth, colorOr(Donchian.Crossing.Color, Donchian.Channel.LowerColor)); SetIndexArrow(MODE_LOWER_CROSS, crossingSymbol);

   SetIndexStyle(MODE_ZZ_COMBINED,     DRAW_NONE);
   SetIndexStyle(MODE_REVERSAL_OFFSET, DRAW_NONE);

   if (redraw) WindowRedraw();
   return(!catch("SetIndicatorOptions(1)"));
}


/**
 * Store the status of the parameter stepper in the chart (for init cyles, template reloads and terminal restarts).
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
   return(StringConcatenate("ZigZag.Periods=",              ZigZag.Periods                              +";"+ NL,
                            "ZigZag.Periods.Step=",         ZigZag.Periods.Step                         +";"+ NL,
                            "ZigZag.Type=",                 DoubleQuoteStr(ZigZag.Type)                 +";"+ NL,
                            "ZigZag.Semaphores.Symbol=",    DoubleQuoteStr(ZigZag.Semaphores.Symbol)    +";"+ NL,
                            "ZigZag.Width=",                ZigZag.Width                                +";"+ NL,
                            "ZigZag.Color=",                ColorToStr(ZigZag.Color)                    +";"+ NL,

                            "Donchian.ShowChannel=",        BoolToStr(Donchian.ShowChannel)             +";"+ NL,
                            "Donchian.Channel.UpperColor=", ColorToStr(Donchian.Channel.UpperColor)     +";"+ NL,
                            "Donchian.Channel.LowerColor=", ColorToStr(Donchian.Channel.LowerColor)     +";"+ NL,
                            "Donchian.ShowCrossings=",      DoubleQuoteStr(Donchian.ShowCrossings)      +";"+ NL,
                            "Donchian.Crossing.Symbol=",    DoubleQuoteStr(Donchian.Crossing.Symbol)    +";"+ NL,
                            "Donchian.Crossing.Width=",     Donchian.Crossing.Width                     +";"+ NL,
                            "Donchian.Crossing.Color=",     ColorToStr(Donchian.Crossing.Color)         +";"+ NL,

                            "ShowChartLegend=",             BoolToStr(ShowChartLegend)                  +";"+ NL,
                            "MaxBarsBack=",                 MaxBarsBack                                 +";"+ NL,

                            "Signal.onReversal=",           BoolToStr(Signal.onReversal)                +";"+ NL,
                            "Signal.onReversal.Types=",     DoubleQuoteStr(Signal.onReversal.Types)     +";"+ NL,
                            "Signal.onBreakout=",           BoolToStr(Signal.onBreakout)                +";"+ NL,
                            "Signal.onBreakout.Types=",     DoubleQuoteStr(Signal.onBreakout.Types)     +";"+ NL,
                            "Signal.Sound.Up=",             DoubleQuoteStr(Signal.Sound.Up)             +";"+ NL,
                            "Signal.Sound.Down=",           DoubleQuoteStr(Signal.Sound.Down)           +";"+ NL,

                            "Sound.onChannelWidening=",     BoolToStr(Sound.onChannelWidening)          +";"+ NL,
                            "Sound.onNewChannelHigh=",      DoubleQuoteStr(Sound.onNewChannelHigh)      +";"+ NL,
                            "Sound.onNewChannelLow=",       DoubleQuoteStr(Sound.onNewChannelLow)       +";"+ NL,

                            "CombinedBuffersAsBinary=",     BoolToStr(CombinedBuffersAsBinary)          +";")
   );

   // suppress compiler warnings
   icZigZag(NULL, NULL, NULL, NULL);
}
