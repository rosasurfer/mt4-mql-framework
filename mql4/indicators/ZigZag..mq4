/**
 * A ZigZag indicator with non-repainting price reversals suitable for automation.
 *
 *
 * The ZigZag indicator provided by MetaQuotes is of little use. The algorithm is seriously flawed and the implementation
 * performes badly. Furthermore the indicator repaints past ZigZag points and can't be used for automation.
 *
 * This indicator fixes those issues. The display can be changed from ZigZag lines to reversal points (aka semaphores). Once
 * the ZigZag direction changed the reversal point will not change anymore. Similar to the MetaQuotes version the indicator
 * uses a Donchian channel for determining reversals but this indicator draws vertical line segments if a large bar crosses
 * both upper and lower Donchian channel band. Additionally it can display the trail of a ZigZag leg as it developed over
 * time. The indicator supports signaling of new reversals.
 *
 * Notes:
 *  - The additional dot in the name prevents the indicator to be overwritten by the MetaQuotes indicator of the same name.
 *
 *
 * TODO:
 *  - implement magic values (INT_MIN, INT_MAX) for double crossings
 *  - fix positioning bug of multiple legends
 *  - move period stepper command to the window
 *  - after init cycle the period stepper forgets current values
 *  - remove logic from IsChartCommand() and replace processing by global include
 *  - add signal onZigZagBreakout
 *  - add auto-configuration
 *  - restore default values (type, hide channel and trail)
 *  - document inputs
 *  - document usage of iCustom()
 */
#include <stddefines.mqh>
int   __InitFlags[];
int __DeinitFlags[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern string ___a__________________________ = "=== ZigZag settings ===";
extern int    ZigZag.Periods                 = 40;                      // lookback periods of the Donchian channel
extern string ZigZag.Type                    = "Line | Semaphores*";    // a ZigZag line or reversal points (may be shortened)
extern int    ZigZag.Width                   = 1;
extern color  ZigZag.Color                   = Blue;
extern int    ZigZag.Semaphores.Wingdings    = 108;                     // a medium dot

extern string ___b__________________________ = "=== Donchian settings ===";
extern bool   Donchian.ShowChannel           = true;                    // whether to display the Donchian channel
extern string Donchian.ShowCrossings         = "off | first* | all";    // which channel crossings to display
extern color  Donchian.Upper.Color           = DodgerBlue;
extern color  Donchian.Lower.Color           = Magenta;
extern int    Donchian.Crossings.Wingdings   = 161;                     // a small circle

extern string ___c__________________________ = "=== Other ===";
extern int    Max.Bars                       = 10000;                   // max. values to calculate (-1: all available)
extern int    PeriodStepper.StepSize         = 0;                       // enable the period stepper with the specified step size

extern string ___d__________________________ = "=== Reversal signaling ===";
extern bool   Signal.onReversal              = false;
extern bool   Signal.onReversal.Sound        = true;
extern string Signal.onReversal.SoundUp      = "Signal Up.wav";         // on ZigZag reversal (first channel crossing)
extern string Signal.onReversal.SoundDown    = "Signal Down.wav";
extern bool   Signal.onReversal.Popup        = false;
extern bool   Signal.onReversal.Mail         = false;
extern bool   Signal.onReversal.SMS          = false;

extern string ___e__________________________ = "=== High/Low signaling ===";
extern bool   Sound.onCrossing               = false;
extern string Sound.onCrossing.Up            = "AlertDefault.wav";      // on channel widening (all channel crossings)
extern string Sound.onCrossing.Down          = "Chotoneto.wav";

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <rsfLib.mqh>
#include <functions/ConfigureSignals.mqh>
#include <functions/ManageDoubleIndicatorBuffer.mqh>
#include <functions/ManageIntIndicatorBuffer.mqh>
#include <win32api.mqh>

// indicator buffer ids
#define MODE_SEMAPHORE_OPEN        ZigZag.MODE_SEMAPHORE_OPEN  //  0: semaphore open price
#define MODE_SEMAPHORE_CLOSE       ZigZag.MODE_SEMAPHORE_CLOSE //  1: semaphore close price
#define MODE_UPPER_BAND_VISIBLE    ZigZag.MODE_UPPER_BAND      //  2: visible upper channel band segments
#define MODE_LOWER_BAND_VISIBLE    ZigZag.MODE_LOWER_BAND      //  3: visible lower channel band segments
#define MODE_UPPER_CROSS           ZigZag.MODE_UPPER_CROSS     //  4: upper channel crossings
#define MODE_LOWER_CROSS           ZigZag.MODE_LOWER_CROSS     //  5: lower channel crossings
#define MODE_REVERSAL              ZigZag.MODE_REVERSAL        //  6: bar offset of the current ZigZag reversal from the previous ZigZag extreme
#define MODE_COMBINED_TREND        ZigZag.MODE_TREND           //  7: combined MODE_KNOWN_TREND + MODE_UNKNOWN_TREND buffers
#define MODE_UPPER_BAND            8                           //  8: full upper Donchian channel band
#define MODE_LOWER_BAND            9                           //  9: full lower Donchian channel band
#define MODE_UPPER_CROSS_ENTRY     10                          // 10: entry points of upper channel crossings
#define MODE_UPPER_CROSS_EXIT      11                          // 11: exit points of upper channel crossings
#define MODE_LOWER_CROSS_ENTRY     12                          // 12: entry points of lower channel crossings
#define MODE_LOWER_CROSS_EXIT      13                          // 13: exit points of lower channel crossings
#define MODE_KNOWN_TREND           14                          // 14: known trend
#define MODE_UNKNOWN_TREND         15                          // 15: not yet known trend

#property indicator_chart_window
#property indicator_buffers   8                                // buffers visible to the user
int       terminal_buffers  = 8;                               // buffers managed by the terminal
int       framework_buffers = 8;                               // buffers managed by the framework

#property indicator_color1    Blue                             // the ZigZag line is built from two buffers using the color of the first buffer
#property indicator_width1    1
#property indicator_color2    CLR_NONE

#property indicator_color3    DodgerBlue                       // visible upper channel band segments
#property indicator_style3    STYLE_DOT                        //
#property indicator_color4    Magenta                          // visible lower channel band segments
#property indicator_style4    STYLE_DOT                        //

#property indicator_color5    indicator_color3                 // upper channel crossings (entry or exit points)
#property indicator_width5    0                                //
#property indicator_color6    indicator_color4                 // lower channel crossings (entry or exit points)
#property indicator_width6    0                                //

#property indicator_color7    CLR_NONE                         // combined MODE_KNOWN_TREND + MODE_UNKNOWN_TREND buffers
#property indicator_color8    CLR_NONE                         // ZigZag leg reversal bar

double   semaphoreOpen   [];                                   // ZigZag semaphores (open prices of a vertical line segment)
double   semaphoreClose  [];                                   // ZigZag semaphores (close prices of a vertical line segment)
double   upperBand       [];                                   // full upper channel band
double   lowerBand       [];                                   // full lower channel band
double   upperBandVisible[];                                   // visible upper channel band segments
double   lowerBandVisible[];                                   // visible lower channel band segments
double   upperCross      [];                                   // upper channel crossings (entry or exit points)
double   upperCrossEntry [];                                   // entry points of upper channel crossings
double   upperCrossExit  [];                                   // exit points of upper channel crossings
double   lowerCross      [];                                   // lower channel crossings (entry or exit points)
double   lowerCrossEntry [];                                   // entry points of lower channel crossings
double   lowerCrossExit  [];                                   // exit points of lower channel crossings
double   reversal        [];                                   // offset of the 1st bar crossing the opposite channel (thus forming a new ZigZag reversal)
int      knownTrend      [];                                   // known direction and length of a ZigZag reversal
int      unknownTrend    [];                                   // not yet known direction and length after a ZigZag reversal
double   combinedTrend   [];                                   // combined knownTrend[] and unknownTrend[] buffers

#define MODE_FIRST_CROSSING   1                                // crossing draw types
#define MODE_ALL_CROSSINGS    2

int      zigzagPeriods;
int      zigzagDrawType;
int      crossingDrawType;
string   crossingModeDescriptions[] = {"off", "first", "all"};
int      maxValues;
string   indicatorName = "";
string   legendLabel   = "";
int      tickTimerId;
double   tickSize;
datetime lastTick;
int      lastSound;
datetime waitUntil;
double   prevUpperBand;
double   prevLowerBand;

bool     signalReversal;
bool     signalReversal.sound;
bool     signalReversal.popup;
bool     signalReversal.mail;
string   signalReversal.mailSender   = "";
string   signalReversal.mailReceiver = "";
bool     signalReversal.sms;
string   signalReversal.smsReceiver = "";
string   signalInfo                 = "";

// signal direction types
#define D_LONG     TRADE_DIRECTION_LONG      // 1
#define D_SHORT    TRADE_DIRECTION_SHORT     // 2

// period stepper directions
#define STEP_UP    1
#define STEP_DOWN -1


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   // validate inputs
   string indicator = ProgramName(MODE_NICE);
   // ZigZag.Periods
   if (ZigZag.Periods < 2)                 return(catch("onInit(1)  invalid input parameter ZigZag.Periods: "+ ZigZag.Periods, ERR_INVALID_INPUT_PARAMETER));
   zigzagPeriods = ZigZag.Periods;
   // ZigZag.Type
   string sValues[], sValue = StrToLower(ZigZag.Type);
   if (Explode(sValue, "*", sValues, 2) > 1) {
      int size = Explode(sValues[0], "|", sValues, NULL);
      sValue = sValues[size-1];
   }
   sValue = StrTrim(sValue);
   if      (StrStartsWith("line",       sValue)) { zigzagDrawType = DRAW_ZIGZAG; ZigZag.Type = "Line";        }
   else if (StrStartsWith("semaphores", sValue)) { zigzagDrawType = DRAW_ARROW;  ZigZag.Type = "Semaphores";  }
   else                                    return(catch("onInit(2)  invalid input parameter ZigZag.Type: "+ DoubleQuoteStr(ZigZag.Type), ERR_INVALID_INPUT_PARAMETER));
   // ZigZag.Width
   if (ZigZag.Width < 0)                   return(catch("onInit(3)  invalid input parameter ZigZag.Width: "+ ZigZag.Width, ERR_INVALID_INPUT_PARAMETER));
   // ZigZag.Semaphores.Wingdings
   if (ZigZag.Semaphores.Wingdings <  32)  return(catch("onInit(4)  invalid input parameter ZigZag.Semaphores.Wingdings: "+ ZigZag.Semaphores.Wingdings, ERR_INVALID_INPUT_PARAMETER));
   if (ZigZag.Semaphores.Wingdings > 255)  return(catch("onInit(5)  invalid input parameter ZigZag.Semaphores.Wingdings: "+ ZigZag.Semaphores.Wingdings, ERR_INVALID_INPUT_PARAMETER));
   // Donchian.ShowCrossings: "off | first | all"
   if (!Donchian.ShowChannel) Donchian.ShowCrossings = "off";
   sValue = Donchian.ShowCrossings;
   if (Explode(sValue, "*", sValues, 2) > 1) {
      size = Explode(sValues[0], "|", sValues, NULL);
      sValue = sValues[size-1];
   }
   sValue = StrToLower(StrTrim(sValue));
   if      (StrStartsWith("off",   sValue)) crossingDrawType = NULL;
   else if (StrStartsWith("first", sValue)) crossingDrawType = MODE_FIRST_CROSSING;
   else if (StrStartsWith("all",   sValue)) crossingDrawType = MODE_ALL_CROSSINGS;
   else                                    return(catch("onInit(6)  invalid input parameter Donchian.ShowCrossings: "+ DoubleQuoteStr(Donchian.ShowCrossings), ERR_INVALID_INPUT_PARAMETER));
   Donchian.ShowCrossings = crossingModeDescriptions[crossingDrawType];
   // Donchian.Crossings.Wingdings
   if (Donchian.Crossings.Wingdings <  32) return(catch("onInit(7)  invalid input parameter Donchian.Crossings.Wingdings: "+ Donchian.Crossings.Wingdings, ERR_INVALID_INPUT_PARAMETER));
   if (Donchian.Crossings.Wingdings > 255) return(catch("onInit(8)  invalid input parameter Donchian.Crossings.Wingdings: "+ Donchian.Crossings.Wingdings, ERR_INVALID_INPUT_PARAMETER));
   // Max.Bars
   if (Max.Bars < -1)                      return(catch("onInit(9)  invalid input parameter Max.Bars: "+ Max.Bars, ERR_INVALID_INPUT_PARAMETER));
   maxValues = ifInt(Max.Bars==-1, INT_MAX, Max.Bars);
   // PeriodStepper.StepSize
   if (PeriodStepper.StepSize < 0)         return(catch("onInit(10)  invalid input parameter PeriodStepper.StepSize: "+ PeriodStepper.StepSize +" (must be non-negative)", ERR_INVALID_INPUT_PARAMETER));
   // colors: after deserialization the terminal might turn CLR_NONE (0xFFFFFFFF) into Black (0xFF000000)
   if (ZigZag.Color         == 0xFF000000) ZigZag.Color         = CLR_NONE;
   if (Donchian.Upper.Color == 0xFF000000) Donchian.Upper.Color = CLR_NONE;
   if (Donchian.Lower.Color == 0xFF000000) Donchian.Lower.Color = CLR_NONE;
   // signaling
   signalReversal       = Signal.onReversal;                      // reset global vars (for possible account change)
   signalReversal.sound = Signal.onReversal.Sound;
   signalReversal.popup = Signal.onReversal.Popup;
   signalReversal.mail  = Signal.onReversal.Mail;
   signalReversal.sms   = Signal.onReversal.SMS;
   signalInfo           = "";
   string signalId = "Signal.onReversal";
   if (!ConfigureSignals2(signalId, AutoConfiguration, signalReversal))                                                                        return(last_error);
   if (signalReversal) {
      if (!ConfigureSignalsBySound2(signalId, AutoConfiguration, signalReversal.sound))                                                        return(last_error);
      if (!ConfigureSignalsByPopup (signalId, AutoConfiguration, signalReversal.popup))                                                        return(last_error);
      if (!ConfigureSignalsByMail2 (signalId, AutoConfiguration, signalReversal.mail, signalReversal.mailSender, signalReversal.mailReceiver)) return(last_error);
      if (!ConfigureSignalsBySMS2  (signalId, AutoConfiguration, signalReversal.sms, signalReversal.smsReceiver))                              return(last_error);
      if (signalReversal.sound || signalReversal.popup || signalReversal.mail || signalReversal.sms) {
         signalInfo = StrLeft(ifString(signalReversal.sound, "sound,", "") + ifString(signalReversal.popup, "popup,", "") + ifString(signalReversal.mail, "mail,", "") + ifString(signalReversal.sms, "sms,", ""), -1);
      }
      else signalReversal = false;
   }
   // Sound.onCrossing
   if (AutoConfiguration) Sound.onCrossing = GetConfigBool(ifString(This.IsTesting(), "Tester.", "") + indicator, "Sound.onCrossing", Sound.onCrossing);

   // buffer management, indicator names and display options
   SetIndicatorOptions();
   if (!IsSuperContext()) {
       legendLabel = CreateLegendLabel();
       RegisterObject(legendLabel);
   }

   // setup a chart ticker for detection of data pumping
   if (!This.IsTesting()) {
      int hWnd    = __ExecutionContext[EC.hChart];
      int millis  = 2000;                                         // a virtual tick every 2 seconds
      int timerId = SetupTickTimer(hWnd, millis, NULL);
      if (!timerId) return(catch("onInit(11)->SetupTickTimer() failed", ERR_RUNTIME_ERROR));
      tickTimerId = timerId;
   }
   return(catch("onInit(12)"));
}


/**
 * Deinitialization
 *
 * @return int - error status
 */
int onDeinit() {
   // remove an installed chhart ticker
   if (tickTimerId > NULL) {
      int id = tickTimerId; tickTimerId = NULL;
      if (!RemoveTickTimer(id)) return(catch("onDeinit(1)->RemoveTickTimer(timerId="+ id +") failed", ERR_RUNTIME_ERROR));
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
   if (!ArraySize(semaphoreOpen)) return(logInfo("onTick(1)  size(semaphoreOpen) = 0", SetLastError(ERS_TERMINAL_NOT_YET_READY)));

   // process incoming commands
   if (__isChart && PeriodStepper.StepSize) HandleCommands();

   // manage framework buffers
   ManageDoubleIndicatorBuffer(MODE_UPPER_BAND,        upperBand      );
   ManageDoubleIndicatorBuffer(MODE_LOWER_BAND,        lowerBand      );
   ManageDoubleIndicatorBuffer(MODE_UPPER_CROSS_ENTRY, upperCrossEntry);
   ManageDoubleIndicatorBuffer(MODE_UPPER_CROSS_EXIT,  upperCrossExit );
   ManageDoubleIndicatorBuffer(MODE_LOWER_CROSS_ENTRY, lowerCrossEntry);
   ManageDoubleIndicatorBuffer(MODE_LOWER_CROSS_EXIT,  lowerCrossExit );
   ManageIntIndicatorBuffer   (MODE_KNOWN_TREND,       knownTrend     );
   ManageIntIndicatorBuffer   (MODE_UNKNOWN_TREND,     unknownTrend   );

   // reset buffers before performing a full recalculation
   if (!ValidBars) {
      ArrayInitialize(semaphoreOpen,    0);
      ArrayInitialize(semaphoreClose,   0);
      ArrayInitialize(upperBand,        0);
      ArrayInitialize(lowerBand,        0);
      ArrayInitialize(upperBandVisible, 0);
      ArrayInitialize(lowerBandVisible, 0);
      ArrayInitialize(upperCross,       0);
      ArrayInitialize(upperCrossEntry,  0);
      ArrayInitialize(upperCrossExit,   0);
      ArrayInitialize(lowerCross,       0);
      ArrayInitialize(lowerCrossEntry,  0);
      ArrayInitialize(lowerCrossExit,   0);
      ArrayInitialize(reversal,        -1);
      ArrayInitialize(knownTrend,       0);
      ArrayInitialize(unknownTrend,     0);
      ArrayInitialize(combinedTrend,    0);
      SetIndicatorOptions();
   }
   if (IsError(last_error)) return(last_error);

   // synchronize buffers with a shifted offline chart
   if (ShiftedBars > 0) {
      ShiftDoubleIndicatorBuffer(semaphoreOpen,    Bars, ShiftedBars,  0);
      ShiftDoubleIndicatorBuffer(semaphoreClose,   Bars, ShiftedBars,  0);
      ShiftDoubleIndicatorBuffer(upperBand,        Bars, ShiftedBars,  0);
      ShiftDoubleIndicatorBuffer(lowerBand,        Bars, ShiftedBars,  0);
      ShiftDoubleIndicatorBuffer(upperBandVisible, Bars, ShiftedBars,  0);
      ShiftDoubleIndicatorBuffer(lowerBandVisible, Bars, ShiftedBars,  0);
      ShiftDoubleIndicatorBuffer(upperCross,       Bars, ShiftedBars,  0);
      ShiftDoubleIndicatorBuffer(upperCrossEntry,  Bars, ShiftedBars,  0);
      ShiftDoubleIndicatorBuffer(upperCrossExit,   Bars, ShiftedBars,  0);
      ShiftDoubleIndicatorBuffer(lowerCross,       Bars, ShiftedBars,  0);
      ShiftDoubleIndicatorBuffer(lowerCrossEntry,  Bars, ShiftedBars,  0);
      ShiftDoubleIndicatorBuffer(lowerCrossExit,   Bars, ShiftedBars,  0);
      ShiftDoubleIndicatorBuffer(reversal,         Bars, ShiftedBars, -1);
      ShiftIntIndicatorBuffer   (knownTrend,       Bars, ShiftedBars,  0);
      ShiftIntIndicatorBuffer   (unknownTrend,     Bars, ShiftedBars,  0);
      ShiftDoubleIndicatorBuffer(combinedTrend,    Bars, ShiftedBars,  0);
   }

   // check data pumping on every tick so the reversal handler can skip errornous signals
   IsPossibleDataPumping();

   // calculate start bar
   int bars     = Min(ChangedBars, maxValues);
   int startbar = Min(bars-1, Bars-zigzagPeriods);
   if (startbar < 0) return(logInfo("onTick(2)  Tick="+ Ticks, ERR_HISTORY_INSUFFICIENT));

   // recalculate changed bars
   for (int bar=startbar; bar >= 0; bar--) {
      semaphoreOpen   [bar] =  0;
      semaphoreClose  [bar] =  0;
      upperBand       [bar] =  0;
      lowerBand       [bar] =  0;
      upperBandVisible[bar] =  0;
      lowerBandVisible[bar] =  0;
      upperCross      [bar] =  0;
      upperCrossEntry [bar] =  0;
      upperCrossExit  [bar] =  0;
      lowerCross      [bar] =  0;
      lowerCrossEntry [bar] =  0;
      lowerCrossExit  [bar] =  0;
      knownTrend      [bar] =  0;
      unknownTrend    [bar] =  0;
      combinedTrend   [bar] =  0;
      reversal        [bar] = -1;

      // recalculate Donchian channel
      if (bar > 0) {
         upperBand[bar] = High[iHighest(NULL, NULL, MODE_HIGH, zigzagPeriods, bar)];
         lowerBand[bar] =  Low[ iLowest(NULL, NULL, MODE_LOW,  zigzagPeriods, bar)];
      }
      else {
         upperBand[bar] = MathMax(upperBand[1], High[0]);
         lowerBand[bar] = MathMin(lowerBand[1],  Low[0]);
      }

      // recalculate channel crossings
      if (upperBand[bar] > upperBand[bar+1]) {
         upperCrossEntry[bar] = MathMax(Low[bar], upperBand[bar+1]);
         upperCrossExit [bar] = upperBand[bar];
      }

      if (lowerBand[bar] < lowerBand[bar+1]) {
         lowerCrossEntry[bar] = MathMin(High[bar], lowerBand[bar+1]);
         lowerCrossExit [bar] = lowerBand[bar];
      }

      // recalculate ZigZag
      // if no channel crossing (future direction is not yet known)
      if (!upperCrossExit[bar] && !lowerCrossExit[bar]) {
         knownTrend   [bar] = knownTrend[bar+1];                  // keep known trend:       in combinedTrend[] <  100'000
         unknownTrend [bar] = unknownTrend[bar+1] + 1;            // increase unknown trend: in combinedTrend[] >= 100'000
         combinedTrend[bar] = Round(Sign(knownTrend[bar]) * unknownTrend[bar] * 100000 + knownTrend[bar]);
         reversal     [bar] = reversal[bar+1];                    // keep previous reversal bar offset
      }

      // if two channel crossings (upper and lower band crossed by the same bar)
      else if (upperCrossExit[bar] && lowerCrossExit[bar]) {
         if (IsUpperCrossFirst(bar)) {
            int prevZZ = ProcessUpperCross(bar);                  // first process the upper crossing

            if (unknownTrend[bar] > 0) {                          // then process the lower crossing
               SetTrend(prevZZ-1, bar, -1, false);                // it always marks a new down leg
               semaphoreOpen[bar] = lowerCrossExit[bar];
            }
            else {
               SetTrend(bar, bar, -1, false);                     // mark a new downtrend
            }
            semaphoreClose[bar] = lowerCrossExit[bar];
            onReversal(D_SHORT, bar);                             // handle the reversal
         }
         else {
            prevZZ = ProcessLowerCross(bar);                      // first process the lower crossing

            if (unknownTrend[bar] > 0) {                          // then process the upper crossing
               SetTrend(prevZZ-1, bar, 1, false);                 // it always marks a new up leg
               semaphoreOpen[bar] = upperCrossExit[bar];
            }
            else {
               SetTrend(bar, bar, 1, false);                      // mark a new uptrend
            }
            semaphoreClose[bar] = upperCrossExit[bar];
            onReversal(D_LONG, bar);                              // handle the reversal
         }
         reversal[bar] = 0;                                       // the 2nd crossing always defines a new reversal
      }

      // if a single band crossing
      else if (upperCrossExit[bar] != 0) ProcessUpperCross(bar);
      else                               ProcessLowerCross(bar);

      // populate visible channel buffers
      if (Donchian.ShowChannel) {
         upperBandVisible[bar] = upperBand[bar];
         lowerBandVisible[bar] = lowerBand[bar];
      }

      // populate visible crossing buffers
      if (crossingDrawType == MODE_ALL_CROSSINGS) {
         upperCross[bar] = upperCrossEntry[bar];
         lowerCross[bar] = lowerCrossEntry[bar];
      }
      else if (crossingDrawType == MODE_FIRST_CROSSING) {
         if (reversal[bar] == Abs(knownTrend[bar])) {
            upperCross[bar] = upperCrossEntry[bar];
            lowerCross[bar] = lowerCrossEntry[bar];
         }
      }
   }

   // sound alert on channel widenings (new high/low) except if a reversal occurred at the same tick (has separate signaling)
   if (Sound.onCrossing && ChangedBars <= 2) {
      if (ChangedBars == 2) {
         prevUpperBand = upperBand[1];
         prevLowerBand = lowerBand[1];
      }
      if      (prevUpperBand && GT(upperBand[0], prevUpperBand)) onChannelCrossing(D_LONG);
      else if (prevLowerBand && LT(lowerBand[0], prevLowerBand)) onChannelCrossing(D_SHORT);

      prevUpperBand = upperBand[0];
      prevLowerBand = lowerBand[0];
   }

   if (!IsSuperContext()) UpdateLegend();
   return(catch("onTick(5)"));
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
   tickSize  = 0;
   lastTick  = 0;                                                 // reset vars used by the reversal event handler
   waitUntil = 0;
   return(onInit());
}


/**
 * Dispatch incoming commands.
 *
 * @param  string commands[] - received commands
 *
 * @return bool - success status
 */
bool onCommand(string commands[]) {
   if (!ArraySize(commands)) return(!logWarn("onCommand(1)  empty parameter commands: {}"));
   string cmd = commands[0];
   if (IsLogDebug()) logDebug("onCommand(2)  "+ DoubleQuoteStr(cmd));

   if (StrStartsWith(cmd, "up|"))   return(PeriodStepper(STEP_UP));
   if (StrStartsWith(cmd, "down|")) return(PeriodStepper(STEP_DOWN));

   return(!logNotice("onCommand(3)  unsupported command: "+ DoubleQuoteStr(cmd)));
}


/**
 * Check for received commands and pass them to the command handler.
 *
 * @return bool - success status
 */
bool HandleCommands() {
   string commands[];
   ArrayResize(commands, 0);

   if (IsChartCommand(commands))
      return(onCommand(commands));
   return(true);
}


/**
 * Whether a chart command was sent to the indicator. If true the command is retrieved and returned.
 *
 * @param  _InOut_ string &commands[] - array to add the received command to
 *
 * @return bool
 */
bool IsChartCommand(string &commands[]) {
   if (!__isChart) return(false);
   string label = "PeriodStepper.command";

   if (ObjectFind(label) == 0) {
      string cmd = ObjectDescription(label);
      int tickcount = StrToInteger(StrRightFrom(cmd, "|"));
      static int lastTickcount;

      if (tickcount > lastTickcount) {
         ArrayPushString(commands, cmd);
         lastTickcount = tickcount;
         return(true);
      }
   }
   return(false);
}


/**
 * Change the currently active ZigZag period.
 *
 * @param  int direction - STEP_UP | STEP_DOWN
 *
 * @return bool - success status
 */
bool PeriodStepper(int direction) {
   if (direction!=STEP_UP && direction!=STEP_DOWN) return(!catch("PeriodStepper(1)  invalid parameter direction: "+ direction, ERR_INVALID_PARAMETER));

   if (direction == STEP_UP) zigzagPeriods += PeriodStepper.StepSize;
   else                      zigzagPeriods -= PeriodStepper.StepSize;

   ChangedBars = Bars;
   ValidBars   = 0; UnchangedBars = ValidBars;
   ShiftedBars = 0;

   return(true);
}


/**
 * Update the chart legend.
 */
void UpdateLegend() {
   static int lastTrend, lastBarTime, lastAccount;

   // update on full recalculation or if trend, current bar or the account changed
   if (!ValidBars || combinedTrend[0]!=lastTrend || Time[0]!=lastBarTime || AccountNumber()!=lastAccount) {
      string sKnown    = "   "+ NumberToStr(knownTrend[0], "+.");
      string sUnknown  = ifString(!unknownTrend[0], "", "/"+ unknownTrend[0]);
      if (!tickSize) tickSize = GetTickSize();
      string sReversal = "   next reversal @" + NumberToStr(ifDouble(knownTrend[0] < 0, upperBand[0]+tickSize, lowerBand[0]-tickSize), PriceFormat);
      string sSignal   = ifString(signalReversal, "   ("+ signalInfo +")", "");
      string text      = StringConcatenate(indicatorName, sKnown, sUnknown, sReversal, sSignal);

      color clr = ZigZag.Color;
      if      (clr == Aqua        ) clr = DeepSkyBlue;
      else if (clr == Gold        ) clr = Orange;
      else if (clr == LightSkyBlue) clr = C'94,174,255';
      else if (clr == Lime        ) clr = LimeGreen;
      else if (clr == Yellow      ) clr = Orange;

      ObjectSetText(legendLabel, text, 9, "Arial Fett", clr);
      int error = GetLastError();
      if (error && error!=ERR_OBJECT_DOES_NOT_EXIST) catch("UpdateLegend(1)", error);     // on ObjectDrag or opened "Properties" dialog

      lastTrend   = combinedTrend[0];
      lastBarTime = Time[0];
      lastAccount = AccountNumber();
   }
}


/**
 * Resolve the current ticksize.
 *
 * @return double - ticksize value or NULL (0) in case of errors
 */
double GetTickSize() {
   double tickSize = MarketInfo(Symbol(), MODE_TICKSIZE);      // fails if there is no tick yet, e.g.
                                                               // - symbol not yet subscribed (on start or account/template change), it shows up later
   int error = GetLastError();                                 // - synthetic symbol in offline chart
   if (IsError(error)) {
      if (error == ERR_SYMBOL_NOT_AVAILABLE)
         return(!logInfo("GetTickSize(1)  MarketInfo(MODE_TICKSIZE)", error));
      return(!catch("GetTickSize(2)", error));
   }
   if (!tickSize) logInfo("GetTickSize(3)  MarketInfo(MODE_TICKSIZE=0)");

   return(tickSize);
}


/**
 * Whether a bar crossing both channel bands crossed the upper band first.
 *
 * @param  int bar - bar offset
 *
 * @return bool
 */
bool IsUpperCrossFirst(int bar) {
   double ho = High [bar] - Open [bar];
   double ol = Open [bar] - Low  [bar];
   double hc = High [bar] - Close[bar];
   double cl = Close[bar] - Low  [bar];

   double minOpen  = MathMin(ho, ol);
   double minClose = MathMin(hc, cl);

   if (minOpen < minClose)
      return(ho < ol);
   return(hc > cl);
}


/**
 * Get the bar offset of the last ZigZag point preceeding the specified startbar. If this is the chart's youngest ZigZag
 * point, then it's unfinished and subject to change.
 *
 * @param  int bar - startbar offset
 *
 * @return int - ZigZag point offset or the previous bar offset if no previous ZigZag point exists yet
 */
int GetPreviousZigZagPoint(int bar) {
   int zzOffset, nextBar=bar + 1;

   if (unknownTrend[nextBar] > 0)     zzOffset = nextBar + unknownTrend[nextBar];
   else if (!semaphoreClose[nextBar]) zzOffset = nextBar + Abs(knownTrend[nextBar]);
   else                               zzOffset = nextBar;
   return(zzOffset);
}


/**
 * Process an upper channel band crossing at the specified bar offset.
 *
 * @param  int  bar - offset
 *
 * @return int - bar offset of the previous ZigZag point
 */
int ProcessUpperCross(int bar) {
   int prevZZ    = GetPreviousZigZagPoint(bar);                   // bar offset of the previous ZigZag point
   int prevTrend = knownTrend[prevZZ];                            // trend at the previous ZigZag point

   if (prevTrend > 0) {                                           // an uptrend continuation
      if (upperCrossExit[bar] > upperCrossExit[prevZZ]) {         // a new high
         SetTrend(prevZZ, bar, prevTrend, false);                 // update existing trend
         if (semaphoreOpen[prevZZ] == semaphoreClose[prevZZ]) {   // reset previous reversal marker
            semaphoreOpen [prevZZ] = 0;
            semaphoreClose[prevZZ] = 0;
         }
         else {
            semaphoreClose[prevZZ] = semaphoreOpen[prevZZ];
         }
         semaphoreOpen [bar] = upperCrossExit[bar];               // set new reversal marker
         semaphoreClose[bar] = upperCrossExit[bar];
      }
      else {                                                      // a lower high
         knownTrend   [bar] = knownTrend[bar+1];                  // keep known trend
         unknownTrend [bar] = unknownTrend[bar+1] + 1;            // increase unknown trend
         combinedTrend[bar] = Round(Sign(knownTrend[bar]) * unknownTrend[bar] * 100000 + knownTrend[bar]);
      }
      reversal[bar] = reversal[bar+1];                            // keep previous reversal bar offset
   }
   else {                                                         // a new uptrend
      if (knownTrend[bar+1] < 0) {
         onReversal(D_LONG, bar);
         SetTrend(prevZZ-1, bar, 1, true);                        // set the new trend and the new reversal bar offset
         reversal[bar] = prevZZ-bar;
      }
      else {
         SetTrend(prevZZ-1, bar, 1, false);                       // rewrite the existing trend and keep the previous reversal bar offset
         reversal[bar] = ifInt(reversal[bar+1] < 0, prevZZ-bar, reversal[bar+1]);
      }
      semaphoreOpen [bar] = upperCrossExit[bar];
      semaphoreClose[bar] = upperCrossExit[bar];
   }
   return(prevZZ);
}


/**
 * Process a lower channel band crossing at the specified bar offset.
 *
 * @param  int bar - offset
 *
 * @return int - bar offset of the previous ZigZag point
 */
int ProcessLowerCross(int bar) {
   int prevZZ    = GetPreviousZigZagPoint(bar);                   // bar offset of the previous ZigZag point
   int prevTrend = knownTrend[prevZZ];                            // trend at the previous ZigZag point

   if (prevTrend < 0) {                                           // a downtrend continuation
      if (lowerCrossExit[bar] < lowerCrossExit[prevZZ]) {         // a new low
         SetTrend(prevZZ, bar, prevTrend, false);                 // update existing trend
         if (semaphoreOpen[prevZZ] == semaphoreClose[prevZZ]) {   // reset previous reversal marker
            semaphoreOpen [prevZZ] = 0;
            semaphoreClose[prevZZ] = 0;
         }
         else {
            semaphoreClose[prevZZ] = semaphoreOpen[prevZZ];
         }
         semaphoreOpen [bar] = lowerCrossExit[bar];               // set new reversal marker
         semaphoreClose[bar] = lowerCrossExit[bar];
      }
      else {                                                      // a higher low
         knownTrend   [bar] = knownTrend[bar+1];                  // keep known trend
         unknownTrend [bar] = unknownTrend[bar+1] + 1;            // increase unknown trend
         combinedTrend[bar] = Round(Sign(knownTrend[bar]) * unknownTrend[bar] * 100000 + knownTrend[bar]);
      }
      reversal[bar] = reversal[bar+1];                            // keep previous reversal offset
   }
   else {                                                         // a new downtrend
      if (knownTrend[bar+1] > 0) {
         onReversal(D_SHORT, bar);
         SetTrend(prevZZ-1, bar, -1, true);                       // set the new trend and the new reversal bar offset
         reversal[bar] = prevZZ-bar;
      }
      else {
         SetTrend(prevZZ-1, bar, -1, false);                      // rewrite the existing trend and keep the previous reversal bar offset
         reversal[bar] = ifInt(reversal[bar+1] < 0, prevZZ-bar, reversal[bar+1]);
      }
      semaphoreOpen [bar] = lowerCrossExit[bar];
      semaphoreClose[bar] = lowerCrossExit[bar];
   }
   return(prevZZ);
}


/**
 * Set the 'knownTrend' and reset the 'unknownTrend' counters of the specified bar range.
 *
 * @param  int  from          - start offset of the bar range
 * @param  int  to            - end offset of the bar range
 * @param  int  value         - trend start value
 * @param  bool resetReversal - whether to reset the reversal buffer
 */
void SetTrend(int from, int to, int value, bool resetReversal) {
   resetReversal = resetReversal!=0;

   for (int i=from; i >= to; i--) {
      knownTrend   [i] = value;
      unknownTrend [i] = 0;
      combinedTrend[i] = Round(Sign(knownTrend[i]) * unknownTrend[i] * 100000 + knownTrend[i]);

      if (resetReversal) reversal[i] = -1;

      if (value > 0) value++;
      else           value--;
   }
}


/**
 * An event handler signaling new ZigZag reversals. Prevents duplicate signals triggered by multiple parallel running
 * terminals.
 *
 * @param  int direction - reversal direction: D_LONG | D_SHORT
 * @param  int bar       - bar of the reversal (the current or the closed bar)
 *
 * @return bool - success status
 */
bool onReversal(int direction, int bar) {
   if (!signalReversal)                         return(false);
   if (ChangedBars > 2)                         return(false);
   if (direction!=D_LONG && direction!=D_SHORT) return(!catch("onReversal(1)  invalid parameter direction: "+ direction, ERR_INVALID_PARAMETER));
   if (bar > 1)                                 return(!catch("onReversal(2)  illegal parameter bar: "+ bar, ERR_ILLEGAL_STATE));
   if (IsPossibleDataPumping())                 return(true);                 // skip signals during possible data pumping

   // check wether the event was already signaled
   int hWnd = ifInt(This.IsTesting(), __ExecutionContext[EC.hChart], GetDesktopWindow());
   string sPeriod = PeriodDescription();
   string sEvent  = "rsf::"+ StdSymbol() +","+ sPeriod +"."+ indicatorName +"("+ zigzagPeriods +").onReversal("+ direction +")."+ TimeToStr(Time[bar], TIME_DATE|TIME_MINUTES);
   bool isSignaled = false;
   if (hWnd > 0) isSignaled = (GetPropA(hWnd, sEvent) != 0);

   int error = NO_ERROR;

   if (!isSignaled) {
      string message     = ifString(direction==D_LONG, "up", "down") +" (bid: "+ NumberToStr(Bid, PriceFormat) +")";
      string accountTime = "("+ TimeToStr(TimeLocal(), TIME_MINUTES|TIME_SECONDS) +", "+ GetAccountAlias() +")";
      if (IsLogInfo()) logInfo("onReversal("+ zigzagPeriods +"x"+ sPeriod +")  "+ message);

      if (signalReversal.sound) {
         error = PlaySoundEx(ifString(direction==D_LONG, Signal.onReversal.SoundUp, Signal.onReversal.SoundDown));
         if (!error)                           lastSound = GetTickCount();
         else if (error == ERR_FILE_NOT_FOUND) signalReversal.sound = false;
         else                                  error |= error;
      }

      message = Symbol() +","+ PeriodDescription() +": "+ indicatorName +" reversal "+ message;
      if (signalReversal.popup)           Alert(message);
      if (signalReversal.mail)  error |= !SendEmail(signalReversal.mailSender, signalReversal.mailReceiver, message, message + NL + accountTime);
      if (signalReversal.sms)   error |= !SendSMS(signalReversal.smsReceiver, message + NL + accountTime);
      if (hWnd > 0) SetPropA(hWnd, sEvent, 1);                                // mark as signaled
   }
   return(!error);
}


/**
 * An event handler signaling Donchian channel crossings.
 *
 * @param  int direction - crossing direction: D_LONG | D_SHORT
 *
 * @return bool - success status
 */
bool onChannelCrossing(int direction) {
   if (!Sound.onCrossing) return(false);
   if (direction!=D_LONG && direction!=D_SHORT) return(!catch("onChannelCrossing(1)  invalid parameter direction: "+ direction, ERR_INVALID_PARAMETER));

   if (lastSound+2000 < GetTickCount()) {                                  // at least 2 sec pause between sound signals
      int error = PlaySoundEx(ifString(direction==D_LONG, Sound.onCrossing.Up, Sound.onCrossing.Down));

      if      (!error)                      lastSound = GetTickCount();
      else if (error == ERR_FILE_NOT_FOUND) Sound.onCrossing = false;

      if (IsLogDebug()) logDebug("onChannelCrossing(2)  new "+ ifString(direction==D_LONG, "High", "Low") +": "+ NumberToStr(upperBand[0], PriceFormat));
   }
   return(!catch("onChannelCrossing(3)"));
}


/**
 * Whether the current tick may have occurred during data pumping.
 *
 * @return bool
 */
bool IsPossibleDataPumping() {
   if (This.IsTesting()) return(false);

   int waitTime = 20 * SECONDS;
   datetime now = GetGmtTime();
   bool result = true;

   if (now > waitUntil) waitUntil = 0;
   if (!waitUntil) {
      if (now > lastTick + waitTime) waitUntil = now + waitTime;
      else                           result = false;
   }
   lastTick = now;
   return(result);
}


/**
 * Workaround for various terminal bugs when setting indicator options. Usually options are set in init(). However after
 * recompilation options must be set in start() to not be ignored.
 */
void SetIndicatorOptions() {
   indicatorName = "ZigZag("+ ifString(PeriodStepper.StepSize, "dyn:", "") + zigzagPeriods +")";
   IndicatorShortName(indicatorName);
   IndicatorDigits(Digits);

   IndicatorBuffers(terminal_buffers);
   SetIndexBuffer(MODE_SEMAPHORE_OPEN,     semaphoreOpen   ); SetIndexEmptyValue(MODE_SEMAPHORE_OPEN,     0); SetIndexLabel(MODE_SEMAPHORE_OPEN,     NULL);
   SetIndexBuffer(MODE_SEMAPHORE_CLOSE,    semaphoreClose  ); SetIndexEmptyValue(MODE_SEMAPHORE_CLOSE,    0); SetIndexLabel(MODE_SEMAPHORE_CLOSE,    NULL);
   SetIndexBuffer(MODE_UPPER_BAND_VISIBLE, upperBandVisible); SetIndexEmptyValue(MODE_UPPER_BAND_VISIBLE, 0); SetIndexLabel(MODE_UPPER_BAND_VISIBLE, indicatorName +" upper band");
   SetIndexBuffer(MODE_LOWER_BAND_VISIBLE, lowerBandVisible); SetIndexEmptyValue(MODE_LOWER_BAND_VISIBLE, 0); SetIndexLabel(MODE_LOWER_BAND_VISIBLE, indicatorName +" lower band");
   SetIndexBuffer(MODE_UPPER_CROSS,        upperCross      ); SetIndexEmptyValue(MODE_UPPER_CROSS,        0); SetIndexLabel(MODE_UPPER_CROSS,        indicatorName +" cross up");
   SetIndexBuffer(MODE_LOWER_CROSS,        lowerCross      ); SetIndexEmptyValue(MODE_LOWER_CROSS,        0); SetIndexLabel(MODE_LOWER_CROSS,        indicatorName +" cross down");
   SetIndexBuffer(MODE_REVERSAL,           reversal        ); SetIndexEmptyValue(MODE_REVERSAL,          -1); SetIndexLabel(MODE_REVERSAL,           indicatorName +" reversal bar");
   SetIndexBuffer(MODE_COMBINED_TREND,     combinedTrend   ); SetIndexEmptyValue(MODE_COMBINED_TREND,     0); SetIndexLabel(MODE_COMBINED_TREND,     indicatorName +" trend");

   int drawType  = ifInt(ZigZag.Width, zigzagDrawType, DRAW_NONE);
   int drawWidth = ifInt(zigzagDrawType==DRAW_ZIGZAG, ZigZag.Width, ZigZag.Width-1);

   SetIndexStyle(MODE_SEMAPHORE_OPEN,  drawType, EMPTY, drawWidth, ZigZag.Color); SetIndexArrow(MODE_SEMAPHORE_OPEN,  ZigZag.Semaphores.Wingdings);
   SetIndexStyle(MODE_SEMAPHORE_CLOSE, drawType, EMPTY, drawWidth, ZigZag.Color); SetIndexArrow(MODE_SEMAPHORE_CLOSE, ZigZag.Semaphores.Wingdings);

   drawType = ifInt(Donchian.ShowChannel, DRAW_LINE, DRAW_NONE);
   SetIndexStyle(MODE_UPPER_BAND_VISIBLE, drawType, EMPTY, EMPTY, Donchian.Upper.Color);
   SetIndexStyle(MODE_LOWER_BAND_VISIBLE, drawType, EMPTY, EMPTY, Donchian.Lower.Color);

   drawType = ifInt(crossingDrawType, DRAW_ARROW, DRAW_NONE);
   SetIndexStyle(MODE_UPPER_CROSS, drawType, EMPTY, EMPTY, Donchian.Upper.Color); SetIndexArrow(MODE_UPPER_CROSS, Donchian.Crossings.Wingdings);
   SetIndexStyle(MODE_LOWER_CROSS, drawType, EMPTY, EMPTY, Donchian.Lower.Color); SetIndexArrow(MODE_LOWER_CROSS, Donchian.Crossings.Wingdings);

   SetIndexStyle(MODE_REVERSAL,       DRAW_NONE);
   SetIndexStyle(MODE_COMBINED_TREND, DRAW_NONE);
}


/**
 * Return a string representation of the input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("ZigZag.Periods=",               ZigZag.Periods                              +";"+ NL,
                            "ZigZag.Type=",                  DoubleQuoteStr(ZigZag.Type)                 +";"+ NL,
                            "ZigZag.Width=",                 ZigZag.Width                                +";"+ NL,
                            "ZigZag.Color=",                 ColorToStr(ZigZag.Color)                    +";"+ NL,
                            "ZigZag.Semaphores.Wingdings=",  ZigZag.Semaphores.Wingdings                 +";"+ NL,

                            "Donchian.ShowChannel=",         BoolToStr(Donchian.ShowChannel)             +";"+ NL,
                            "Donchian.ShowCrossings=",       DoubleQuoteStr(Donchian.ShowCrossings)      +";"+ NL,
                            "Donchian.Upper.Color=",         ColorToStr(Donchian.Upper.Color)            +";"+ NL,
                            "Donchian.Lower.Color=",         ColorToStr(Donchian.Lower.Color)            +";"+ NL,
                            "Donchian.Crossings.Wingdings=", Donchian.Crossings.Wingdings                +";"+ NL,

                            "Max.Bars=",                     Max.Bars                                    +";"+ NL,
                            "PeriodStepper.StepSize=",       PeriodStepper.StepSize                      +";"+ NL,

                            "Signal.onReversal=",            BoolToStr(Signal.onReversal)                +";"+ NL,
                            "Signal.onReversal.Sound=",      BoolToStr(Signal.onReversal.Sound)          +";"+ NL,
                            "Signal.onReversal.SoundUp=",    DoubleQuoteStr(Signal.onReversal.SoundUp)   +";"+ NL,
                            "Signal.onReversal.SoundDown=",  DoubleQuoteStr(Signal.onReversal.SoundDown) +";"+ NL,
                            "Signal.onReversal.Popup=",      BoolToStr(Signal.onReversal.Popup)          +";"+ NL,
                            "Signal.onReversal.Mail=",       BoolToStr(Signal.onReversal.Mail)           +";"+ NL,
                            "Signal.onReversal.SMS=",        BoolToStr(Signal.onReversal.SMS)            +";"+ NL,

                            "Sound.onCrossing=",             BoolToStr(Sound.onCrossing)                 +";"+ NL,
                            "Sound.onCrossing.Up=",          DoubleQuoteStr(Sound.onCrossing.Up)         +";"+ NL,
                            "Sound.onCrossing.Down=",        DoubleQuoteStr(Sound.onCrossing.Down)       +";")
   );
}
