/**
 * Non-repainting ZigZag indicator suitable for automation
 *
 *
 * The ZigZag indicator provided by MetaQuotes is of little use. The implementation is flawed and the indicator heavily
 * repaints. Also it can't be used for automation.
 *
 * This indicator fixes all those issues. The display can be changed from ZigZag lines to reversal points (aka semaphores).
 * Once a ZigZag reversal occures the reversal point will not change anymore. Like the MetaQuotes version this indicator uses
 * a Donchian channel for determining possible reversals but draws vertical line segments if a large bar crosses both upper
 * and lower channel band. Additionally this indicator can display the trail of a ZigZag leg as it developes over time.
 *
 *
 * TODO:
 *  - Periods=2: intrabar bug in tester (control points) on USDJPY,M15 2021.08.03 00:45
 *  - visible buffer for breakout markers
 *  - add breakout markers to "Data" window
 *  - invisible marker descriptions (or are built-in breakout markers enough)
 *  - after data pumping changed marker decsriptions are not removed
 *  - add auto-configuration
 *  - implement magic values (INT_MIN, INT_MAX) for double crossing bars
 *  - add dynamic period changes
 *  - document iCustom() usage
 *  - document inputs
 *  - move indicator properties below input section (really?)
 *  - restore default values (hide channel and trail)
 */
#include <stddefines.mqh>
int   __InitFlags[];
int __DeinitFlags[];

#property indicator_chart_window
#property indicator_buffers   8

#property indicator_color1    Blue                             // the ZigZag line is built from two buffers using the color of the first buffer
#property indicator_width1    1
#property indicator_color2    CLR_NONE

#property indicator_color3    DodgerBlue                       // upper channel band
#property indicator_style3    STYLE_DOT                        //
#property indicator_color4    Magenta                          // lower channel band
#property indicator_style4    STYLE_DOT                        //

#property indicator_color5    indicator_color3                 // trail of upward ZigZag leg
#property indicator_color6    indicator_color4                 // trail of downward ZigZag leg

#property indicator_color7    CLR_NONE                         // trend buffer
#property indicator_color8    CLR_NONE                         // notrend buffer (waiting)

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern int    ZigZag.Periods          = 10;                    // 12 lookback periods of the Donchian channel
extern string ZigZag.Type             = "Line | Semaphores*";  // a ZigZag line or reversal points, can be shortened to "L | S"
extern int    ZigZag.Width            = indicator_width1;
extern color  ZigZag.Color            = indicator_color1;

extern int    Semaphores.Symbol       = 108;                   // that's a small dot

extern bool   ShowZigZagChannel       = true;
extern bool   ShowZigZagTrail         = true;
extern color  UpperChannel.Color      = indicator_color3;
extern color  LowerChannel.Color      = indicator_color4;
extern int    Max.Bars                = 10000;                 // max. values to calculate (-1: all available)

extern string __1___________________________ = "=== Signaling of new ZigZag reversals ===";
extern bool   Signal.onReversal       = false;
extern bool   Signal.onReversal.Sound = false;
extern bool   Signal.onReversal.Popup = true;
extern bool   Signal.onReversal.Mail  = false;
extern bool   Signal.onReversal.SMS   = false;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <rsfLibs.mqh>
#include <functions/ConfigureSignals.mqh>

// breakout direction types
#define D_LONG    TRADE_DIRECTION_LONG                   // 1
#define D_SHORT   TRADE_DIRECTION_SHORT                  // 2

// indicator buffer ids
#define MODE_REVERSAL_OPEN    ZigZag.MODE_REVERSAL_OPEN  // 0: reversal open price
#define MODE_REVERSAL_CLOSE   ZigZag.MODE_REVERSAL_CLOSE // 1: reversal close price
#define MODE_UPPER_BAND       ZigZag.MODE_UPPER_BAND     // 2: upper channel band
#define MODE_LOWER_BAND       ZigZag.MODE_LOWER_BAND     // 3: lower channel band
#define MODE_UPPER_CROSS      ZigZag.MODE_UPPER_CROSS    // 4: upper channel band crossing
#define MODE_LOWER_CROSS      ZigZag.MODE_LOWER_CROSS    // 5: lower channel band crossing
#define MODE_TREND            ZigZag.MODE_TREND          // 6: trend
#define MODE_WAITING          ZigZag.MODE_WAITING        // 7: unknown trend

double zigzagOpen [];                                    // ZigZag semaphores (open price of a vertical segment)
double zigzagClose[];                                    // ZigZag semaphores (close price of a vertical segment)
double upperBand  [];                                    // upper channel band
double lowerBand  [];                                    // lower channel band
double upperCross [];                                    // upper band crossings
double lowerCross [];                                    // lower band crossings
double trend      [];                                    // trend direction and length
double notrend    [];                                    // bar periods with not yet known trend direction

int    zigzagPeriods;
int    zigzagDrawType;
int    maxValues;
string indicatorName = "";
string legendLabel   = "";

//string signalSoundUp    = "AlertDefault.wav";
//string signalSoundDown  = "AlertDefault.wav";
string signalSoundUp      = "Signal-Up.wav";
string signalSoundDown    = "Signal-Down.wav";
string signalMailSender   = "";
string signalMailReceiver = "";
string signalSmsReceiver  = "";
string signalDescription  = "";


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   // validate inputs
   // ZigZag.Periods
   if (ZigZag.Periods < 2)      return(catch("onInit(1)  invalid input parameter ZigZag.Periods: "+ ZigZag.Periods, ERR_INVALID_INPUT_PARAMETER));
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
   else                         return(catch("onInit(2)  invalid input parameter ZigZag.Type: "+ DoubleQuoteStr(ZigZag.Type), ERR_INVALID_INPUT_PARAMETER));
   // ZigZag.Width
   if (ZigZag.Width < 0)        return(catch("onInit(3)  invalid input parameter ZigZag.Width: "+ ZigZag.Width, ERR_INVALID_INPUT_PARAMETER));
   // Semaphores.Symbol
   if (Semaphores.Symbol <  32) return(catch("onInit(4)  invalid input parameter Semaphores.Symbol: "+ Semaphores.Symbol, ERR_INVALID_INPUT_PARAMETER));
   if (Semaphores.Symbol > 255) return(catch("onInit(5)  invalid input parameter Semaphores.Symbol: "+ Semaphores.Symbol, ERR_INVALID_INPUT_PARAMETER));
   // Max.Bars
   if (Max.Bars < -1)           return(catch("onInit(6)  invalid input parameter Max.Bars: "+ Max.Bars, ERR_INVALID_INPUT_PARAMETER));
   maxValues = ifInt(Max.Bars==-1, INT_MAX, Max.Bars);
   // colors: after deserialization the terminal might turn CLR_NONE (0xFFFFFFFF) into Black (0xFF000000)
   if (ZigZag.Color       == 0xFF000000) ZigZag.Color       = CLR_NONE;
   if (UpperChannel.Color == 0xFF000000) UpperChannel.Color = CLR_NONE;
   if (LowerChannel.Color == 0xFF000000) LowerChannel.Color = CLR_NONE;

   // signaling
   string signalId = "Signal.onReversal";
   if (!ConfigureSignals2(signalId, AutoConfiguration, Signal.onReversal))                                                      return(last_error);
   if (Signal.onReversal) {
      if (!ConfigureSignalsBySound2(signalId, AutoConfiguration, Signal.onReversal.Sound))                                      return(last_error);
      if (!ConfigureSignalsByPopup (signalId, AutoConfiguration, Signal.onReversal.Popup))                                      return(last_error);
      if (!ConfigureSignalsByMail2 (signalId, AutoConfiguration, Signal.onReversal.Mail, signalMailSender, signalMailReceiver)) return(last_error);
      if (!ConfigureSignalsBySMS2  (signalId, AutoConfiguration, Signal.onReversal.SMS, signalSmsReceiver))                     return(last_error);
      if (Signal.onReversal.Sound || Signal.onReversal.Popup || Signal.onReversal.Mail || Signal.onReversal.SMS) {
         signalDescription = "onReversal="+ StrLeft(ifString(Signal.onReversal.Sound, "Sound+", "") + ifString(Signal.onReversal.Popup, "Popup+", "") + ifString(Signal.onReversal.Mail, "Mail+", "") + ifString(Signal.onReversal.SMS, "SMS+", ""), -1);
         if (IsLogDebug()) logDebug("onInit(7)  "+ signalDescription);
      }
      else Signal.onReversal = false;
   }

   // buffer management
   indicatorName = StrTrim(ProgramName()) +"("+ ZigZag.Periods +")";
   SetIndexBuffer(MODE_REVERSAL_OPEN,  zigzagOpen ); SetIndexEmptyValue(MODE_REVERSAL_OPEN,  0); SetIndexLabel(MODE_REVERSAL_OPEN,  NULL);
   SetIndexBuffer(MODE_REVERSAL_CLOSE, zigzagClose); SetIndexEmptyValue(MODE_REVERSAL_CLOSE, 0); SetIndexLabel(MODE_REVERSAL_CLOSE, NULL);
   SetIndexBuffer(MODE_UPPER_BAND,     upperBand  ); SetIndexEmptyValue(MODE_UPPER_BAND,     0); SetIndexLabel(MODE_UPPER_BAND,     indicatorName +" upper band");
   SetIndexBuffer(MODE_LOWER_BAND,     lowerBand  ); SetIndexEmptyValue(MODE_LOWER_BAND,     0); SetIndexLabel(MODE_LOWER_BAND,     indicatorName +" lower band");
   SetIndexBuffer(MODE_UPPER_CROSS,    upperCross ); SetIndexEmptyValue(MODE_UPPER_CROSS,    0); SetIndexLabel(MODE_UPPER_CROSS,    NULL);
   SetIndexBuffer(MODE_LOWER_CROSS,    lowerCross ); SetIndexEmptyValue(MODE_LOWER_CROSS,    0); SetIndexLabel(MODE_LOWER_CROSS,    NULL);
   SetIndexBuffer(MODE_TREND,          trend      ); SetIndexEmptyValue(MODE_TREND,          0); SetIndexLabel(MODE_TREND,          indicatorName +" trend");
   SetIndexBuffer(MODE_WAITING,        notrend    ); SetIndexEmptyValue(MODE_WAITING,        0); SetIndexLabel(MODE_WAITING,        indicatorName +" waiting");

   // names, labels and display options
   IndicatorShortName(indicatorName);           // chart tooltips and context menu
   SetIndicatorOptions();
   IndicatorDigits(Digits);

   if (!IsSuperContext()) {
       legendLabel = CreateLegendLabel();
       RegisterObject(legendLabel);
   }
   return(catch("onInit(8)"));
}


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   // on the first tick after terminal start buffers may not yet be initialized (spurious issue)
   if (!ArraySize(zigzagOpen)) return(logInfo("onTick(1)  size(zigzagOpen) = 0", SetLastError(ERS_TERMINAL_NOT_YET_READY)));

   // reset buffers before performing a full recalculation
   if (!UnchangedBars) {
      ArrayInitialize(zigzagOpen,  0);
      ArrayInitialize(zigzagClose, 0);
      ArrayInitialize(upperBand,   0);
      ArrayInitialize(lowerBand,   0);
      ArrayInitialize(upperCross,  0);
      ArrayInitialize(lowerCross,  0);
      ArrayInitialize(trend,       0);
      ArrayInitialize(notrend,     0);
      SetIndicatorOptions();
   }

   // synchronize buffers with a shifted offline chart
   if (ShiftedBars > 0) {
      ShiftIndicatorBuffer(zigzagOpen,  Bars, ShiftedBars, 0);
      ShiftIndicatorBuffer(zigzagClose, Bars, ShiftedBars, 0);
      ShiftIndicatorBuffer(upperBand,   Bars, ShiftedBars, 0);
      ShiftIndicatorBuffer(lowerBand,   Bars, ShiftedBars, 0);
      ShiftIndicatorBuffer(upperCross,  Bars, ShiftedBars, 0);
      ShiftIndicatorBuffer(lowerCross,  Bars, ShiftedBars, 0);
      ShiftIndicatorBuffer(trend,       Bars, ShiftedBars, 0);
      ShiftIndicatorBuffer(notrend,     Bars, ShiftedBars, 0);
   }

   // calculate start bar
   int bars     = Min(ChangedBars, maxValues);
   int startbar = Min(bars-1, Bars-zigzagPeriods);
   if (startbar < 0) return(logInfo("onTick(2)  Tick="+ Tick, ERR_HISTORY_INSUFFICIENT));

   // recalculate changed bars
   for (int bar=startbar; bar >= 0; bar--) {
      zigzagOpen [bar] = 0;
      zigzagClose[bar] = 0;
      upperBand  [bar] = 0;
      lowerBand  [bar] = 0;
      upperCross [bar] = 0;
      lowerCross [bar] = 0;
      trend      [bar] = 0;
      notrend    [bar] = 0;

      // recalculate Donchian channel and crossings (potential ZigZag reversals)
      upperBand[bar] = High[iHighest(NULL, NULL, MODE_HIGH, zigzagPeriods, bar)];
      lowerBand[bar] =  Low[ iLowest(NULL, NULL, MODE_LOW,  zigzagPeriods, bar)];
      if (High[bar] == upperBand[bar]) upperCross[bar] = upperBand[bar];
      if ( Low[bar] == lowerBand[bar]) lowerCross[bar] = lowerBand[bar];

      // recalculate ZigZag
      // if no channel crossings (trend is unknown)
      if (!upperCross[bar] && !lowerCross[bar]) {
         trend  [bar] = trend[bar+1];                                // keep known trend
         notrend[bar] = Round(notrend[bar+1] + 1);                   // increase unknown trend
      }

      // if two crossings (upper and lower band crossed by the same bar)
      else if (upperCross[bar] && lowerCross[bar]) {
         if (IsUpperCrossFirst(bar)) {
            int prevZZ = ProcessUpperCross(bar);                     // first process the upper crossing

            if (notrend[bar] > 0) {                                  // then process the lower crossing
               SetTrend(prevZZ-1, bar, -1);                          // (it always marks a new down leg)
               zigzagOpen[bar] = lowerCross[bar];
            }
            else {
               SetTrend(bar, bar, -1);                               // mark a new downtrend
            }
            zigzagClose[bar] = lowerCross[bar];
            MarkBreakoutLevel(D_SHORT, bar);                         // mark the breakout level
         }
         else {
            prevZZ = ProcessLowerCross(bar);                         // first process the lower crossing

            if (notrend[bar] > 0) {                                  // then process the upper crossing
               SetTrend(prevZZ-1, bar, 1);                           // (it always marks a new up leg)
               zigzagOpen[bar] = upperCross[bar];
            }
            else {
               SetTrend(bar, bar, 1);                                // mark a new uptrend
            }
            zigzagClose[bar] = upperCross[bar];
            MarkBreakoutLevel(D_LONG, bar);                          // mark the breakout level
         }
      }

      // if a single upper band crossing
      else if (upperCross[bar] != 0) {
         ProcessUpperCross(bar);
      }

      // if a single lower band crossing
      else {
         ProcessLowerCross(bar);
      }
   }

   if (!IsSuperContext()) UpdateLegend();                            // signal handling happens in MarkBreakoutLevel()
   return(catch("onTick(3)"));
}


/**
 * Update the chart legend.
 */
void UpdateLegend() {
   static double lastTrend, lastNotrend;
   static datetime lastBarTime;

   // update if trend[0], notrend[0] or the current bar changed
   if (trend[0]!=lastTrend || notrend[0]!=lastNotrend || Time[0]!=lastBarTime) {
      int    iNotrend = notrend[0];
      string sTrend   = "  "+ NumberToStr(trend[0], "+.");
      string sNotrend = ifString(!iNotrend, "", " (waiting: "+ iNotrend +")");

      string text = StringConcatenate(indicatorName, "    ", sTrend, sNotrend);
      color clr = ZigZag.Color;
      if      (clr == Aqua        ) clr = DeepSkyBlue;
      else if (clr == Gold        ) clr = Orange;
      else if (clr == LightSkyBlue) clr = C'94,174,255';
      else if (clr == Lime        ) clr = LimeGreen;
      else if (clr == Yellow      ) clr = Orange;

      ObjectSetText(legendLabel, text, 9, "Arial Fett", clr);
      int error = GetLastError();
      if (error && error!=ERR_OBJECT_DOES_NOT_EXIST) catch("UpdateLegend(1)", error);     // on Object::onDrag() or opened "Properties" dialog
   }

   lastTrend   = trend  [0];
   lastNotrend = notrend[0];
   lastBarTime = Time   [0];
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
 * Resolve the bar offset of the last ZigZag point preceeding the specified startbar. May be in same or opposite trend
 * direction.
 *
 * @param  int bar - startbar offset
 *
 * @return int - point offset or the previous bar offset if no previous ZigZag point exists
 */
int GetPreviousZigZagPoint(int bar) {
   int nextBar = bar + 1;
   if      (notrend[nextBar] > 0) int zzOffset = nextBar + notrend[nextBar];
   else if (!zigzagClose[nextBar])    zzOffset = nextBar + Abs(trend[nextBar]);
   else                               zzOffset = nextBar;
   return(zzOffset);
}


/**
 * Process an upper channel band crossing at the specified bar offset.
 *
 * @param  int  bar - offset
 *
 * @return int - bar offset of the previous ZigZag reversal (same or opposite trend direction)
 */
int ProcessUpperCross(int bar) {
   int prevZZ    = GetPreviousZigZagPoint(bar);                // bar offset of the previous ZigZag reversal (same or opposite trend direction)
   int prevTrend = trend[prevZZ];                              // trend at the previous ZigZag reversal

   if (prevTrend > 0) {                                        // an uptrend continuation
      if (upperCross[bar] > upperCross[prevZZ]) {              // a new high
         SetTrend(prevZZ, bar, prevTrend);                     // update existing trend
         if (zigzagOpen[prevZZ] == zigzagClose[prevZZ]) {      // reset previous reversal marker
            zigzagOpen [prevZZ] = 0;
            zigzagClose[prevZZ] = 0;
         }
         else {
            zigzagClose[prevZZ] = zigzagOpen[prevZZ];
         }
         zigzagOpen [bar] = upperCross[bar];                   // set new reversal marker
         zigzagClose[bar] = upperCross[bar];
      }
      else {                                                   // a lower high
         upperCross[bar] = 0;                                  // reset channel cross marker
         trend     [bar] = trend[bar+1];                       // keep known trend
         notrend   [bar] = Round(notrend[bar+1] + 1);          // increase unknown trend
      }
   }
   else {                                                      // a new uptrend
      if (trend[bar+1] < 0 || notrend[bar+1])
         MarkBreakoutLevel(D_LONG, bar);                       // mark the breakout
      SetTrend(prevZZ-1, bar, 1);                              // set the trend
      zigzagOpen [bar] = upperCross[bar];
      zigzagClose[bar] = upperCross[bar];
   }
   return(prevZZ);
}


/**
 * Process a lower channel band crossing at the specified bar offset.
 *
 * @param  int bar - offset
 *
 * @return int - bar offset of the previous ZigZag reversal (same or opposite trend direction)
 */
int ProcessLowerCross(int bar) {
   int prevZZ    = GetPreviousZigZagPoint(bar);                // bar offset of the previous ZigZag reversal (same or opposite trend direction)
   int prevTrend = trend[prevZZ];                              // trend at the previous ZigZag reversal

   if (prevTrend < 0) {                                        // a downtrend continuation
      if (lowerCross[bar] < lowerCross[prevZZ]) {              // a new low
         SetTrend(prevZZ, bar, prevTrend);                     // update existing trend
         if (zigzagOpen[prevZZ] == zigzagClose[prevZZ]) {      // reset previous reversal marker
            zigzagOpen [prevZZ] = 0;
            zigzagClose[prevZZ] = 0;
         }
         else {
            zigzagClose[prevZZ] = zigzagOpen[prevZZ];
         }
         zigzagOpen [bar] = lowerCross[bar];                   // set new reversal marker
         zigzagClose[bar] = lowerCross[bar];
      }
      else {                                                   // a higher low
         lowerCross[bar] = 0;                                  // reset channel cross marker
         trend     [bar] = trend[bar+1];                       // keep known trend
         notrend   [bar] = Round(notrend[bar+1] + 1);          // increase unknown trend
      }
   }
   else {                                                      // a new downtrend
      if (trend[bar+1] > 0 || notrend[bar+1])
         MarkBreakoutLevel(D_SHORT, bar);                      // mark the breakout
      SetTrend(prevZZ-1, bar, -1);                             // set the trend
      zigzagOpen [bar] = lowerCross[bar];
      zigzagClose[bar] = lowerCross[bar];
   }
   return(prevZZ);
}


/**
 * Set the 'trend' counter and reset the 'notrend' counter of the specified bar range.
 *
 * @param  int from  - start offset of the bar range
 * @param  int to    - end offset of the bar range
 * @param  int value - trend start value
 */
void SetTrend(int from, int to, int value) {
   for (int i=from; i >= to; i--) {
      trend  [i] = value;
      notrend[i] = 0;

      if (value > 0) value++;
      else           value--;
   }
}


/**
 * Mark the channel breakout level of the ZigZag leg at the specified bar and trigger new reversal signals.
 *
 * @param  int direction - breakout direction: D_LONG | D_SHORT
 * @param  int bar       - breakout offset
 *
 * @return bool - success status
 */
bool MarkBreakoutLevel(int direction, int bar) {
   if (direction!=D_LONG && direction!=D_SHORT) return(!catch("MarkBreakoutLevel(1)  invalid parameter direction: "+ direction, ERR_INVALID_PARAMETER));

   string sDirection = "";
   double price;
   color  clr;

   if (direction == D_LONG) {
      sDirection = "long";
      price = upperBand[bar+1];
      if (price > High[bar]) price = High[bar];
      if (price <  Low[bar]) price =  Low[bar];
      clr = ifInt(price==High[bar] && ChangedBars > 2, CLR_NONE, UpperChannel.Color);
   }
   else {
      sDirection = "short";
      price = lowerBand[bar+1];
      if (price > High[bar]) price = High[bar];
      if (price <  Low[bar]) price =  Low[bar];
      clr = ifInt(price==Low[bar] && ChangedBars > 2, CLR_NONE, LowerChannel.Color);
   }
   string label = StringConcatenate(indicatorName, " ", sDirection, " breakout at ", NumberToStr(price, PriceFormat), NL, TimeToStr(Time[bar], TIME_DATE|TIME_MINUTES));

   if (ObjectFind(label) == 0)
      ObjectDelete(label);
   if (ObjectCreate(label, OBJ_ARROW, 0, Time[bar], price)) {
      ObjectSet    (label, OBJPROP_ARROWCODE, 161);
      ObjectSet    (label, OBJPROP_COLOR,     clr);
      ObjectSet    (label, OBJPROP_WIDTH,     0);
      RegisterObject(label);
   }

   // trigger new reversal signals
   if (Signal.onReversal && ChangedBars <= 2)
      return(onReversal(direction, bar));
   return(true);
}


/**
 * Event handler for new ZigZag reversals.
 *
 * @param  int direction - reversal direction: D_LONG | D_SHORT
 * @param  int bar       - bar of the reversal (the current or the closed bar)
 *
 * @return bool - success status
 */
bool onReversal(int direction, int bar) {
   if (direction!=D_LONG && direction!=D_SHORT) return(!catch("onReversal(1)  invalid parameter direction: "+ direction, ERR_INVALID_PARAMETER));
   if (bar > 1)                                 return(!catch("onReversal(2)  illegal parameter bar: "+ bar, ERR_ILLEGAL_STATE));

   // check wether the event has already been signaled
   int    hWnd  = ifInt(This.IsTesting(), __ExecutionContext[EC.hChart], GetTerminalMainWindow());
   string event = "rsf."+ Symbol() +","+ PeriodDescription() +"."+ indicatorName +".onReversal("+ direction +")."+ TimeToStr(Time[bar], TIME_DATE|TIME_MINUTES);
   bool isSignaled = false;
   if (hWnd > 0) isSignaled = (GetWindowIntegerA(hWnd, event) != 0);

   int error = NO_ERROR;

   if (!isSignaled) {
      if (hWnd > 0) SetWindowIntegerA(hWnd, event, 1);                        // mark event as signaled

      string message="", accountTime="("+ TimeToStr(TimeLocal(), TIME_MINUTES|TIME_SECONDS) +", "+ GetAccountAlias() +")";

      if (direction == D_LONG) {
         message = indicatorName +" reversal up, bar "+ bar +", "+ TimeToStr(Time[bar], TIME_MINUTES|TIME_SECONDS) +" (market: "+ NumberToStr(Bid, PriceFormat) +")";
         if (IsLogInfo()) logInfo("onReversal(2)  "+ message);
         message = Symbol() +","+ PeriodDescription() +": "+ message;

         if (Signal.onReversal.Popup)           Alert(message);               // "Sound" drowns out an enabled alert sound
         if (Signal.onReversal.Sound) error |= !PlaySoundEx(signalSoundUp);
         if (Signal.onReversal.Mail)  error |= !SendEmail(signalMailSender, signalMailReceiver, message, message + NL + accountTime);
         if (Signal.onReversal.SMS)   error |= !SendSMS(signalSmsReceiver, message + NL + accountTime);
      }

      if (direction == D_SHORT) {
         message = indicatorName +" reversal down, bar "+ bar +", "+ TimeToStr(Time[bar], TIME_MINUTES|TIME_SECONDS) +" (market: "+ NumberToStr(Bid, PriceFormat) +")";
         if (IsLogInfo()) logInfo("onReversal(3)  "+ message);
         message = Symbol() +","+ PeriodDescription() +": "+ message;

         if (Signal.onReversal.Popup)           Alert(message);               // "Sound" drowns out an enabled alert sound
         if (Signal.onReversal.Sound) error |= !PlaySoundEx(signalSoundDown);
         if (Signal.onReversal.Mail)  error |= !SendEmail(signalMailSender, signalMailReceiver, message, message + NL + accountTime);
         if (Signal.onReversal.SMS)   error |= !SendSMS(signalSmsReceiver, message + NL + accountTime);
      }
   }
   return(!error);
}


/**
 * Workaround for various terminal bugs when setting indicator options. Usually options are set in init(). However after
 * recompilation options must be set in start() to not be ignored.
 */
void SetIndicatorOptions() {
   int drawType  = ifInt(ZigZag.Width, zigzagDrawType, DRAW_NONE);
   int drawWidth = ifInt(zigzagDrawType==DRAW_ZIGZAG, ZigZag.Width, ZigZag.Width-1);

   SetIndexStyle(MODE_REVERSAL_OPEN,  drawType, EMPTY, drawWidth, ZigZag.Color); SetIndexArrow(MODE_REVERSAL_OPEN,  Semaphores.Symbol);
   SetIndexStyle(MODE_REVERSAL_CLOSE, drawType, EMPTY, drawWidth, ZigZag.Color); SetIndexArrow(MODE_REVERSAL_CLOSE, Semaphores.Symbol);

   drawType = ifInt(ShowZigZagChannel, DRAW_LINE, DRAW_NONE);
   SetIndexStyle(MODE_UPPER_BAND, drawType, EMPTY, EMPTY, UpperChannel.Color);
   SetIndexStyle(MODE_LOWER_BAND, drawType, EMPTY, EMPTY, LowerChannel.Color);

   drawType = ifInt(ShowZigZagTrail, DRAW_ARROW, DRAW_NONE);
   SetIndexStyle(MODE_UPPER_CROSS, drawType, EMPTY, EMPTY, UpperChannel.Color); SetIndexArrow(MODE_UPPER_CROSS, 161);   // an open circle (dot)
   SetIndexStyle(MODE_LOWER_CROSS, drawType, EMPTY, EMPTY, LowerChannel.Color); SetIndexArrow(MODE_LOWER_CROSS, 161);   // ...

   SetIndexStyle(MODE_TREND,   DRAW_NONE);
   SetIndexStyle(MODE_WAITING, DRAW_NONE);
}


/**
 * Return a string representation of the input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("ZigZag.Periods=",          ZigZag.Periods,                     ";", NL,
                            "ZigZag.Type=",             DoubleQuoteStr(ZigZag.Type),        ";", NL,
                            "ZigZag.Width=",            ZigZag.Width,                       ";", NL,
                            "ZigZag.Color=",            ColorToStr(ZigZag.Color),           ";", NL,
                            "Semaphores.Symbol=",       Semaphores.Symbol,                  ";", NL,
                            "ShowZigZagChannel=",       BoolToStr(ShowZigZagChannel),       ";", NL,
                            "ShowZigZagTrail=",         BoolToStr(ShowZigZagTrail),         ";", NL,
                            "UpperChannel.Color=",      ColorToStr(UpperChannel.Color),     ";", NL,
                            "LowerChannel.Color=",      ColorToStr(LowerChannel.Color),     ";", NL,
                            "Max.Bars=",                Max.Bars,                           ";", NL,

                            "Signal.onReversal=",       BoolToStr(Signal.onReversal),       ";", NL,
                            "Signal.onReversal.Sound=", BoolToStr(Signal.onReversal.Sound), ";", NL,
                            "Signal.onReversal.Popup=", BoolToStr(Signal.onReversal.Popup), ";", NL,
                            "Signal.onReversal.Mail=",  BoolToStr(Signal.onReversal.Mail),  ";", NL,
                            "Signal.onReversal.SMS=",   BoolToStr(Signal.onReversal.SMS),   ";")
   );
}
