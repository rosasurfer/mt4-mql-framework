/**
 * ZigZag indicator with non-repainting price reversals suitable for automation
 *
 *
 * The ZigZag indicator provided by MetaQuotes is of little use. The algorithm is seriously flawed and the implementation
 * performes badly. Furthermore the indicator repaints past ZigZag points and can't be used for automation.
 *
 * This indicator fixes those issues. The display can be changed from ZigZag lines to reversal points (aka semaphores). Once
 * the direction changed the reversal point will not change anymore. Similar to the MetaQuotes version the indicator uses a
 * Donchian channel for determining reversals but draws vertical line segments if a large bar crosses both upper and lower
 * channel band. Additionally it can display the trail of a ZigZag leg as it developes over time. The indicator supports
 * reversal signaling.
 *
 *
 * TODO:
 *  - add auto-configuration and remove global var __isAutoConfig
 *  - implement magic values (INT_MIN, INT_MAX) for large double crossing bars
 *  - add dynamic period changing
 *  - restore default values (type, hide channel and trail)
 *  - document inputs
 *  - document usage of iCustom()
 */
#include <stddefines.mqh>
int   __InitFlags[];
int __DeinitFlags[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern int    ZigZag.Periods             = 12;                    // lookback periods of the Donchian channel
extern string ZigZag.Type                = "Line | Semaphores*";  // a ZigZag line or reversal points, may be shortened
extern int    ZigZag.Width               = 1;
extern color  ZigZag.Color               = Blue;

extern bool   ShowZigZagChannel          = true;                  // display the channel for determining reversal points
extern bool   ShowZigZagTrail            = true;                  // display only the crossings forming a ZigZag leg
extern bool   ShowAllChannelCrossings    = true;                  // display all channel crossings
extern bool   ShowFirstCrossingPerBar    = true;                  // display the first or the last crossing per bar
extern color  UpperChannel.Color         = DodgerBlue;
extern color  LowerChannel.Color         = Magenta;

extern int    Semaphores.WingDingsSymbol = 108;                   // a medium dot
extern int    Crossings.WingDingsSymbol  = 161;                   // a small circle

extern int    Max.Bars                   = 10000;                 // max. values to calculate (-1: all available)

extern string __1___________________________ = "=== Signaling of new ZigZag reversals ===";
extern bool   Signal.onReversal          = false;
extern bool   Signal.onReversal.Sound    = true;
extern bool   Signal.onReversal.Popup    = false;
extern bool   Signal.onReversal.Mail     = false;
extern bool   Signal.onReversal.SMS      = false;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <rsfLibs.mqh>
#include <functions/ConfigureSignals.mqh>
#include <functions/ManageDoubleIndicatorBuffer.mqh>
#include <functions/ManageIntIndicatorBuffer.mqh>

// indicator buffer ids
#define MODE_SEMAPHORE_OPEN        ZigZag.MODE_SEMAPHORE_OPEN  //  0: semaphore open price
#define MODE_SEMAPHORE_CLOSE       ZigZag.MODE_SEMAPHORE_CLOSE //  1: semaphore close price
#define MODE_UPPER_BAND            ZigZag.MODE_UPPER_BAND      //  2: upper channel band
#define MODE_LOWER_BAND            ZigZag.MODE_LOWER_BAND      //  3: lower channel band
#define MODE_UPPER_BREAKOUT        4                           //  4: upper channel breakout (start or end point)
#define MODE_LOWER_BREAKOUT        5                           //  5: lower channel breakout (start or end point)
#define MODE_REVERSAL              6                           //  6: ZigZag leg reversal bar
#define MODE_COMBINED_TREND        7                           //  7: combined MODE_TREND + MODE_WAITING buffers
#define MODE_UPPER_BREAKOUT_START  8                           //  8: start point of upper breakout
#define MODE_UPPER_BREAKOUT_END    9                           //  9: end point of upper breakout
#define MODE_LOWER_BREAKOUT_START  10                          // 10: start point of lower breakout
#define MODE_LOWER_BREAKOUT_END    11                          // 11: end point of lower breakout
#define MODE_TREND                 12                          // 12: known trend
#define MODE_WAITING               13                          // 13: not yet known trend

#property indicator_chart_window
#property indicator_buffers   8                                // buffers visible to the user
int       terminal_buffers  = 8;                               // buffers managed by the terminal
int       framework_buffers = 6;                               // buffers managed by the framework

#property indicator_color1    Blue                             // the ZigZag line is built from two buffers using the color of the first buffer
#property indicator_width1    1
#property indicator_color2    CLR_NONE

#property indicator_color3    DodgerBlue                       // upper channel band
#property indicator_style3    STYLE_DOT                        //
#property indicator_color4    Magenta                          // lower channel band
#property indicator_style4    STYLE_DOT                        //

#property indicator_color5    indicator_color3                 // upper channel breakout (start or end point)
#property indicator_width5    0                                //
#property indicator_color6    indicator_color4                 // lower channel breakout (start or end point)
#property indicator_width6    0                                //

#property indicator_color7    CLR_NONE                         // combined MODE_TREND + MODE_WAITING buffers
#property indicator_color8    CLR_NONE                         // ZigZag leg reversal bar

double   semaphoreOpen     [];                                 // ZigZag semaphores (open price of a vertical segment)
double   semaphoreClose    [];                                 // ZigZag semaphores (close price of a vertical segment)
double   upperBand         [];                                 // upper channel band
double   lowerBand         [];                                 // lower channel band
double   upperBreakout     [];                                 // upper channel breakout (start or end point)
double   upperBreakoutStart[];                                 // start point of upper channel breakout
double   upperBreakoutEnd  [];                                 // end point of upper channel breakout
double   lowerBreakout     [];                                 // lower channel breakout (start or end point)
double   lowerBreakoutStart[];                                 // start point of lower channel breakout
double   lowerBreakoutEnd  [];                                 // end point of lower channel breakout
double   reversal          [];                                 // offset of the ZigZag leg reversal bar
int      trend             [];                                 // trend direction and length
int      waiting           [];                                 // bar periods with not yet known trend direction
double   combinedTrend     [];                                 // combined trend[] and waiting[] buffers

int      zigzagPeriods;
int      zigzagDrawType;
int      maxValues;
string   indicatorName = "";
string   legendLabel   = "";
int      tickTimerId;
double   tickSize;
datetime lastTick;
datetime waitUntil;

bool     signalReversal;
bool     signalReversal.Sound;
string   signalReversal.SoundUp   = "Signal-Up.wav";
string   signalReversal.SoundDown = "Signal-Down.wav";
bool     signalReversal.Popup;
bool     signalReversal.Mail;
string   signalReversal.MailSender   = "";
string   signalReversal.MailReceiver = "";
bool     signalReversal.SMS;
string   signalReversal.SMSReceiver = "";
string   signalInfo                 = "";

// breakout direction types
#define D_LONG    TRADE_DIRECTION_LONG       // 1
#define D_SHORT   TRADE_DIRECTION_SHORT      // 2


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   // validate inputs
   // ZigZag.Periods
   if (ZigZag.Periods < 2)               return(catch("onInit(1)  invalid input parameter ZigZag.Periods: "+ ZigZag.Periods, ERR_INVALID_INPUT_PARAMETER));
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
   else                                  return(catch("onInit(2)  invalid input parameter ZigZag.Type: "+ DoubleQuoteStr(ZigZag.Type), ERR_INVALID_INPUT_PARAMETER));
   // ZigZag.Width
   if (ZigZag.Width < 0)                 return(catch("onInit(3)  invalid input parameter ZigZag.Width: "+ ZigZag.Width, ERR_INVALID_INPUT_PARAMETER));
   // Semaphores.WingDingsSymbol
   if (Semaphores.WingDingsSymbol <  32) return(catch("onInit(4)  invalid input parameter Semaphores.WingDingsSymbol: "+ Semaphores.WingDingsSymbol, ERR_INVALID_INPUT_PARAMETER));
   if (Semaphores.WingDingsSymbol > 255) return(catch("onInit(5)  invalid input parameter Semaphores.WingDingsSymbol: "+ Semaphores.WingDingsSymbol, ERR_INVALID_INPUT_PARAMETER));
   // Crossings.WingDingsSymbol
   if (Crossings.WingDingsSymbol <  32)  return(catch("onInit(6)  invalid input parameter Crossings.WingDingsSymbol: "+ Crossings.WingDingsSymbol, ERR_INVALID_INPUT_PARAMETER));
   if (Crossings.WingDingsSymbol > 255)  return(catch("onInit(7)  invalid input parameter Crossings.WingDingsSymbol: "+ Crossings.WingDingsSymbol, ERR_INVALID_INPUT_PARAMETER));
   // Max.Bars
   if (Max.Bars < -1)                    return(catch("onInit(8)  invalid input parameter Max.Bars: "+ Max.Bars, ERR_INVALID_INPUT_PARAMETER));
   maxValues = ifInt(Max.Bars==-1, INT_MAX, Max.Bars);
   // colors: after deserialization the terminal might turn CLR_NONE (0xFFFFFFFF) into Black (0xFF000000)
   if (ZigZag.Color       == 0xFF000000) ZigZag.Color       = CLR_NONE;
   if (UpperChannel.Color == 0xFF000000) UpperChannel.Color = CLR_NONE;
   if (LowerChannel.Color == 0xFF000000) LowerChannel.Color = CLR_NONE;

   // signaling
   signalReversal       = Signal.onReversal;                      // reset global vars (possible account change)
   signalReversal.Sound = Signal.onReversal.Sound;
   signalReversal.Popup = Signal.onReversal.Popup;
   signalReversal.Mail  = Signal.onReversal.Mail;
   signalReversal.SMS   = Signal.onReversal.SMS;
   signalInfo           = "";
   string signalId = "Signal.onReversal";
   if (!ConfigureSignals2(signalId, AutoConfiguration, signalReversal))                                                                        return(last_error);
   if (signalReversal) {
      if (!ConfigureSignalsBySound2(signalId, AutoConfiguration, signalReversal.Sound))                                                        return(last_error);
      if (!ConfigureSignalsByPopup (signalId, AutoConfiguration, signalReversal.Popup))                                                        return(last_error);
      if (!ConfigureSignalsByMail2 (signalId, AutoConfiguration, signalReversal.Mail, signalReversal.MailSender, signalReversal.MailReceiver)) return(last_error);
      if (!ConfigureSignalsBySMS2  (signalId, AutoConfiguration, signalReversal.SMS, signalReversal.SMSReceiver))                              return(last_error);
      if (signalReversal.Sound || signalReversal.Popup || signalReversal.Mail || signalReversal.SMS) {
         signalInfo = StrLeft(ifString(signalReversal.Sound, "sound,", "") + ifString(signalReversal.Popup, "popup,", "") + ifString(signalReversal.Mail, "mail,", "") + ifString(signalReversal.SMS, "sms,", ""), -1);
      }
      else signalReversal = false;
   }

   // buffer management
   indicatorName = StrTrim(ProgramName()) +"("+ ZigZag.Periods +")";
   SetIndexBuffer(MODE_SEMAPHORE_OPEN,  semaphoreOpen ); SetIndexEmptyValue(MODE_SEMAPHORE_OPEN,  0); SetIndexLabel(MODE_SEMAPHORE_OPEN,  NULL);
   SetIndexBuffer(MODE_SEMAPHORE_CLOSE, semaphoreClose); SetIndexEmptyValue(MODE_SEMAPHORE_CLOSE, 0); SetIndexLabel(MODE_SEMAPHORE_CLOSE, NULL);
   SetIndexBuffer(MODE_UPPER_BAND,      upperBand     ); SetIndexEmptyValue(MODE_UPPER_BAND,      0); SetIndexLabel(MODE_UPPER_BAND,      indicatorName +" upper band");
   SetIndexBuffer(MODE_LOWER_BAND,      lowerBand     ); SetIndexEmptyValue(MODE_LOWER_BAND,      0); SetIndexLabel(MODE_LOWER_BAND,      indicatorName +" lower band");
   SetIndexBuffer(MODE_UPPER_BREAKOUT,  upperBreakout ); SetIndexEmptyValue(MODE_UPPER_BREAKOUT,  0); SetIndexLabel(MODE_UPPER_BREAKOUT,  indicatorName +" breakout up");
   SetIndexBuffer(MODE_LOWER_BREAKOUT,  lowerBreakout ); SetIndexEmptyValue(MODE_LOWER_BREAKOUT,  0); SetIndexLabel(MODE_LOWER_BREAKOUT,  indicatorName +" breakout down");
   SetIndexBuffer(MODE_REVERSAL,        reversal      ); SetIndexEmptyValue(MODE_REVERSAL,       -1); SetIndexLabel(MODE_REVERSAL,        indicatorName +" reversal");
   SetIndexBuffer(MODE_COMBINED_TREND,  combinedTrend ); SetIndexEmptyValue(MODE_COMBINED_TREND,  0); SetIndexLabel(MODE_COMBINED_TREND,  indicatorName +" trend");

   // names, labels and display options
   IndicatorShortName(indicatorName);                             // chart tooltips and context menu
   SetIndicatorOptions();
   IndicatorDigits(Digits);

   if (!IsSuperContext()) {
       legendLabel = CreateLegendLabel();
       RegisterObject(legendLabel);
   }

   // setup a chart ticker to detect data pumping periods by the reversal event handler
   if (!This.IsTesting()) {
      int hWnd    = __ExecutionContext[EC.hChart];
      int millis  = 2000;                                         // a virtual tick every 2 seconds
      int timerId = SetupTickTimer(hWnd, millis, NULL);
      if (!timerId) return(catch("onInit(9)->SetupTickTimer() failed", ERR_RUNTIME_ERROR));
      tickTimerId = timerId;
   }
   return(catch("onInit(10)"));
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

   ManageDoubleIndicatorBuffer(MODE_UPPER_BREAKOUT_START, upperBreakoutStart);
   ManageDoubleIndicatorBuffer(MODE_UPPER_BREAKOUT_END,   upperBreakoutEnd  );
   ManageDoubleIndicatorBuffer(MODE_LOWER_BREAKOUT_START, lowerBreakoutStart);
   ManageDoubleIndicatorBuffer(MODE_LOWER_BREAKOUT_END,   lowerBreakoutEnd  );
   ManageIntIndicatorBuffer   (MODE_TREND,                trend             );
   ManageIntIndicatorBuffer   (MODE_WAITING,              waiting           );

   // reset buffers before performing a full recalculation
   if (!ValidBars) {
      ArrayInitialize(semaphoreOpen,      0);
      ArrayInitialize(semaphoreClose,     0);
      ArrayInitialize(upperBand,          0);
      ArrayInitialize(lowerBand,          0);
      ArrayInitialize(upperBreakout,      0);
      ArrayInitialize(upperBreakoutStart, 0);
      ArrayInitialize(upperBreakoutEnd,   0);
      ArrayInitialize(lowerBreakout,      0);
      ArrayInitialize(lowerBreakoutStart, 0);
      ArrayInitialize(lowerBreakoutEnd,   0);
      ArrayInitialize(reversal,          -1);
      ArrayInitialize(trend,              0);
      ArrayInitialize(waiting,            0);
      ArrayInitialize(combinedTrend,      0);
      SetIndicatorOptions();
   }
   if (IsError(last_error)) return(last_error);

   // synchronize buffers with a shifted offline chart
   if (ShiftedBars > 0) {
      ShiftDoubleIndicatorBuffer(semaphoreOpen,      Bars, ShiftedBars,  0);
      ShiftDoubleIndicatorBuffer(semaphoreClose,     Bars, ShiftedBars,  0);
      ShiftDoubleIndicatorBuffer(upperBand,          Bars, ShiftedBars,  0);
      ShiftDoubleIndicatorBuffer(lowerBand,          Bars, ShiftedBars,  0);
      ShiftDoubleIndicatorBuffer(upperBreakout,      Bars, ShiftedBars,  0);
      ShiftDoubleIndicatorBuffer(upperBreakoutStart, Bars, ShiftedBars,  0);
      ShiftDoubleIndicatorBuffer(upperBreakoutEnd,   Bars, ShiftedBars,  0);
      ShiftDoubleIndicatorBuffer(lowerBreakout,      Bars, ShiftedBars,  0);
      ShiftDoubleIndicatorBuffer(lowerBreakoutStart, Bars, ShiftedBars,  0);
      ShiftDoubleIndicatorBuffer(lowerBreakoutEnd,   Bars, ShiftedBars,  0);
      ShiftDoubleIndicatorBuffer(reversal,           Bars, ShiftedBars, -1);
      ShiftIntIndicatorBuffer   (trend,              Bars, ShiftedBars,  0);
      ShiftIntIndicatorBuffer   (waiting,            Bars, ShiftedBars,  0);
      ShiftDoubleIndicatorBuffer(combinedTrend,      Bars, ShiftedBars,  0);
   }

   // check data pumping so the reversal handler can skip possibly errornous signals
   IsPossibleDataPumping();

   // calculate start bar
   int bars     = Min(ChangedBars, maxValues);
   int startbar = Min(bars-1, Bars-zigzagPeriods);
   if (startbar < 0) return(logInfo("onTick(2)  Tick="+ Tick, ERR_HISTORY_INSUFFICIENT));

   // recalculate changed bars
   for (int bar=startbar; bar >= 0; bar--) {
      semaphoreOpen     [bar] = 0;
      semaphoreClose    [bar] = 0;
      upperBand         [bar] = 0;
      lowerBand         [bar] = 0;
      upperBreakout     [bar] = 0;
      upperBreakoutStart[bar] = 0;
      upperBreakoutEnd  [bar] = 0;
      lowerBreakout     [bar] = 0;
      lowerBreakoutStart[bar] = 0;
      lowerBreakoutEnd  [bar] = 0;
      trend             [bar] = 0;
      waiting           [bar] = 0;
      combinedTrend     [bar] = 0;
      reversal          [bar] = 0;

      // recalculate Donchian channel
      if (bar > 0) {
         upperBand[bar] = High[iHighest(NULL, NULL, MODE_HIGH, zigzagPeriods, bar)];
         lowerBand[bar] =  Low[ iLowest(NULL, NULL, MODE_LOW,  zigzagPeriods, bar)];
      }
      else {
         upperBand[bar] = MathMax(upperBand[1], High[0]);
         lowerBand[bar] = MathMin(lowerBand[1],  Low[0]);
      }

      // recalculate channel breakouts
      if (upperBand[bar] > upperBand[bar+1]) {
         upperBreakoutStart[bar] = MathMax(Low[bar], upperBand[bar+1]);
         upperBreakoutEnd  [bar] = upperBand[bar];
      }

      if (lowerBand[bar] < lowerBand[bar+1]) {
         lowerBreakoutStart[bar] = MathMin(High[bar], lowerBand[bar+1]);
         lowerBreakoutEnd  [bar] = lowerBand[bar];
      }

      // recalculate ZigZag
      // if no channel crossings (future direction is unknown)
      if (!upperBreakoutEnd[bar] && !lowerBreakoutEnd[bar]) {
         trend        [bar] = trend[bar+1];                                // keep known trend:        in combinedTrend[] <  100'000
         waiting      [bar] = waiting[bar+1] + 1;                          // increase unknown buffer: in combinedTrend[] >= 100'000
         combinedTrend[bar] = Round(Sign(trend[bar]) * waiting[bar] * 100000 + trend[bar]);
         reversal     [bar] = reversal[bar+1];                             // keep previous reversal offset
      }

      // if two crossings (upper and lower channel band crossed by the same bar)
      else if (upperBreakoutEnd[bar] && lowerBreakoutEnd[bar]) {
         if (IsUpperCrossFirst(bar)) {
            int prevZZ = ProcessUpperCross(bar);                           // first process the upper crossing

            if (waiting[bar] > 0) {                                        // then process the lower crossing
               SetTrend(prevZZ-1, bar, -1);                                // (it always marks a new down leg)
               semaphoreOpen[bar] = lowerBreakoutEnd[bar];
            }
            else {
               SetTrend(bar, bar, -1);                                     // mark a new downtrend
            }
            semaphoreClose[bar] = lowerBreakoutEnd[bar];
            onReversal(D_SHORT, bar);                                      // handle the reversal
         }
         else {
            prevZZ = ProcessLowerCross(bar);                               // first process the lower crossing

            if (waiting[bar] > 0) {                                        // then process the upper crossing
               SetTrend(prevZZ-1, bar, 1);                                 // (it always marks a new up leg)
               semaphoreOpen[bar] = upperBreakoutEnd[bar];
            }
            else {
               SetTrend(bar, bar, 1);                                      // mark a new uptrend
            }
            semaphoreClose[bar] = upperBreakoutEnd[bar];
            onReversal(D_LONG, bar);                                       // handle the reversal
         }
         reversal[bar] = 0;                                                // the 2nd crossing is always a new reversal
      }

      // if a single band crossing
      else if (upperBreakoutEnd[bar] != 0) ProcessUpperCross(bar);
      else                                 ProcessLowerCross(bar);

      // populate the visible breakout buffers
      if (ShowAllChannelCrossings || (ShowZigZagTrail && !waiting[bar])) {
         if (ShowFirstCrossingPerBar) {
            upperBreakout[bar] = upperBreakoutStart[bar];
            lowerBreakout[bar] = lowerBreakoutStart[bar];
         }
         else {
            upperBreakout[bar] = upperBreakoutEnd[bar];
            lowerBreakout[bar] = lowerBreakoutEnd[bar];
         }
      }
   }

   if (!IsSuperContext()) UpdateLegend();                                  // signals are processed in CheckReversalSignal()
   return(catch("onTick(3)"));
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
   lastTick  = 0;             // reset vars of the reversal event handler
   waitUntil = 0;
   return(onInit());
}


/**
 * Update the chart legend.
 */
void UpdateLegend() {
   static int lastTrend, lastBarTime, lastAccount;

   // update if trend, current bar or the account changed
   if (combinedTrend[0]!=lastTrend || Time[0]!=lastBarTime || AccountNumber()!=lastAccount) {
      string sTrend    = "   "+ NumberToStr(trend[0], "+.");
      string sWaiting  = ifString(!waiting[0], "", "/"+ waiting[0]);
      if (!tickSize) tickSize = GetTickSize();
      string sReversal = "   next "+ ifString(trend[0] < 0, "up", "down") +" reversal @" + NumberToStr(ifDouble(trend[0] < 0, upperBand[0]+tickSize, lowerBand[0]-tickSize), PriceFormat);
      string sSignal   = ifString(signalReversal, "   ("+ signalInfo +")", "");
      string text      = StringConcatenate(indicatorName, sTrend, sWaiting, sReversal, sSignal);

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
         return(_NULL(logInfo("GetTickSize(1)  MarketInfo(MODE_TICKSIZE)", error)));
      return(!catch("GetTickSize(2)", error));
   }
   if (!tickSize) logInfo("GetTickSize(3)  MarketInfo(MODE_TICKSIZE): 0");

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
 * Resolve the bar offset of the last ZigZag point preceeding the specified startbar. The chart's youngest ZigZag point is
 * always unfinished and subject to change.
 *
 * @param  int bar - startbar offset
 *
 * @return int - ZigZag point offset or the previous bar offset if no previous ZigZag point exists yet
 */
int GetPreviousZigZagPoint(int bar) {
   int zzOffset, nextBar=bar + 1;

   if (waiting[nextBar] > 0)          zzOffset = nextBar + waiting[nextBar];
   else if (!semaphoreClose[nextBar]) zzOffset = nextBar + Abs(trend[nextBar]);
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
   int prevTrend = trend[prevZZ];                                 // trend at the previous ZigZag point

   if (prevTrend > 0) {                                           // an uptrend continuation
      if (upperBreakoutEnd[bar] > upperBreakoutEnd[prevZZ]) {     // a new high
         SetTrend(prevZZ, bar, prevTrend);                        // update existing trend
         if (semaphoreOpen[prevZZ] == semaphoreClose[prevZZ]) {   // reset previous reversal marker
            semaphoreOpen [prevZZ] = 0;
            semaphoreClose[prevZZ] = 0;
         }
         else {
            semaphoreClose[prevZZ] = semaphoreOpen[prevZZ];
         }
         semaphoreOpen [bar] = upperBreakoutEnd[bar];             // set new reversal marker
         semaphoreClose[bar] = upperBreakoutEnd[bar];
      }
      else {                                                      // a lower high
         trend        [bar] = trend[bar+1];                       // keep known trend
         waiting      [bar] = waiting[bar+1] + 1;                 // increase unknown trend
         combinedTrend[bar] = Round(Sign(trend[bar]) * waiting[bar] * 100000 + trend[bar]);
      }
      reversal[bar] = reversal[bar+1];                            // keep previous reversal offset
   }
   else {                                                         // a new uptrend
      if (trend[bar+1] < 0 || waiting[bar+1])
         onReversal(D_LONG, bar);
      SetTrend(prevZZ-1, bar, 1, true);                           // set the trend
      semaphoreOpen [bar] = upperBreakoutEnd[bar];
      semaphoreClose[bar] = upperBreakoutEnd[bar];
      reversal      [bar] = prevZZ-bar;                           // set the new reversal offset
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
   int prevTrend = trend[prevZZ];                                 // trend at the previous ZigZag point

   if (prevTrend < 0) {                                           // a downtrend continuation
      if (lowerBreakoutEnd[bar] < lowerBreakoutEnd[prevZZ]) {     // a new low
         SetTrend(prevZZ, bar, prevTrend);                        // update existing trend
         if (semaphoreOpen[prevZZ] == semaphoreClose[prevZZ]) {   // reset previous reversal marker
            semaphoreOpen [prevZZ] = 0;
            semaphoreClose[prevZZ] = 0;
         }
         else {
            semaphoreClose[prevZZ] = semaphoreOpen[prevZZ];
         }
         semaphoreOpen [bar] = lowerBreakoutEnd[bar];             // set new reversal marker
         semaphoreClose[bar] = lowerBreakoutEnd[bar];
      }
      else {                                                      // a higher low
         trend        [bar] = trend[bar+1];                       // keep known trend
         waiting      [bar] = waiting[bar+1] + 1;                 // increase unknown trend
         combinedTrend[bar] = Round(Sign(trend[bar]) * waiting[bar] * 100000 + trend[bar]);
      }
      reversal[bar] = reversal[bar+1];                            // keep previous reversal offset
   }
   else {                                                         // a new downtrend
      if (trend[bar+1] > 0 || waiting[bar+1])
         onReversal(D_SHORT, bar);
      SetTrend(prevZZ-1, bar, -1, true);                          // set the trend
      semaphoreOpen [bar] = lowerBreakoutEnd[bar];
      semaphoreClose[bar] = lowerBreakoutEnd[bar];
      reversal      [bar] = prevZZ-bar;                           // set the new reversal offset
   }
   return(prevZZ);
}


/**
 * Set the 'trend' counter and reset the 'notrend' counter of the specified bar range.
 *
 * @param  int  from                     - start offset of the bar range
 * @param  int  to                       - end offset of the bar range
 * @param  int  value                    - trend start value
 * @param  bool resetReversal [optional] - reset the reversal buffer (default: no)
 */
void SetTrend(int from, int to, int value, bool resetReversal = false) {
   resetReversal = resetReversal!=0;

   for (int i=from; i >= to; i--) {
      trend        [i] = value;
      waiting      [i] = 0;
      combinedTrend[i] = Round(Sign(trend[i]) * waiting[i] * 100000 + trend[i]);

      if (resetReversal) reversal[i] = -1;

      if (value > 0) value++;
      else           value--;
   }
}


/**
 * An event handler signaling new ZigZag reversals.
 *
 * @param  int direction - reversal direction: D_LONG | D_SHORT
 * @param  int bar       - bar of the reversal (the current or the closed bar)
 *
 * @return bool - success status
 */
bool onReversal(int direction, int bar) {
   if (!signalReversal || ChangedBars > 2)      return(false);
   if (direction!=D_LONG && direction!=D_SHORT) return(!catch("onReversal(1)  invalid parameter direction: "+ direction, ERR_INVALID_PARAMETER));
   if (bar > 1)                                 return(!catch("onReversal(2)  illegal parameter bar: "+ bar, ERR_ILLEGAL_STATE));
   if (IsPossibleDataPumping())                 return(true);                 // skip signals during possible data pumping

   // check wether the event was already signaled
   int    hWnd  = ifInt(This.IsTesting(), __ExecutionContext[EC.hChart], GetTerminalMainWindow());
   string sEvent = "rsf."+ Symbol() +","+ PeriodDescription() +"."+ indicatorName +".onReversal("+ direction +")."+ TimeToStr(Time[bar], TIME_DATE|TIME_MINUTES);
   bool isSignaled = false;
   if (hWnd > 0) isSignaled = (GetWindowIntegerA(hWnd, sEvent) != 0);

   int error = NO_ERROR;

   if (!isSignaled) {
      if (hWnd > 0) SetWindowIntegerA(hWnd, sEvent, 1);                       // mark event as signaled
      string message="", accountTime="("+ TimeToStr(TimeLocal(), TIME_MINUTES|TIME_SECONDS) +", "+ GetAccountAlias() +")";

      if (direction == D_LONG) {
         message = "up (bid: "+ NumberToStr(Bid, PriceFormat) +")";
         if (IsLogInfo()) logInfo("onReversal(2)  "+ message);
         message = Symbol() +","+ PeriodDescription() +": "+ indicatorName +" reversal "+ message;

         if (signalReversal.Popup)           Alert(message);                  // before "Sound" to get drowned out by the next sound
         if (signalReversal.Sound) error |= !PlaySoundEx(signalReversal.SoundUp);
         if (signalReversal.Mail)  error |= !SendEmail(signalReversal.MailSender, signalReversal.MailReceiver, message, message + NL + accountTime);
         if (signalReversal.SMS)   error |= !SendSMS(signalReversal.SMSReceiver, message + NL + accountTime);
      }

      if (direction == D_SHORT) {
         message = "down (bid: "+ NumberToStr(Bid, PriceFormat) +")";
         if (IsLogInfo()) logInfo("onReversal(3)  "+ message);
         message = Symbol() +","+ PeriodDescription() +": "+ indicatorName +" reversal "+ message;

         if (signalReversal.Popup)           Alert(message);                  // before "Sound" to get drowned out by the next sound
         if (signalReversal.Sound) error |= !PlaySoundEx(signalReversal.SoundDown);
         if (signalReversal.Mail)  error |= !SendEmail(signalReversal.MailSender, signalReversal.MailReceiver, message, message + NL + accountTime);
         if (signalReversal.SMS)   error |= !SendSMS(signalReversal.SMSReceiver, message + NL + accountTime);
      }
   }
   return(!error);
}


/**
 * Whether the current tick possibly occurred during data pumping.
 *
 * @return bool
 */
bool IsPossibleDataPumping() {
   if (This.IsTesting()) return(false);

   int waitTime = 10 * SECONDS;
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
   IndicatorBuffers(terminal_buffers);

   int drawType  = ifInt(ZigZag.Width, zigzagDrawType, DRAW_NONE);
   int drawWidth = ifInt(zigzagDrawType==DRAW_ZIGZAG, ZigZag.Width, ZigZag.Width-1);

   SetIndexStyle(MODE_SEMAPHORE_OPEN,  drawType, EMPTY, drawWidth, ZigZag.Color); SetIndexArrow(MODE_SEMAPHORE_OPEN,  Semaphores.WingDingsSymbol);
   SetIndexStyle(MODE_SEMAPHORE_CLOSE, drawType, EMPTY, drawWidth, ZigZag.Color); SetIndexArrow(MODE_SEMAPHORE_CLOSE, Semaphores.WingDingsSymbol);

   drawType = ifInt(ShowZigZagChannel, DRAW_LINE, DRAW_NONE);
   SetIndexStyle(MODE_UPPER_BAND, drawType, EMPTY, EMPTY, UpperChannel.Color);
   SetIndexStyle(MODE_LOWER_BAND, drawType, EMPTY, EMPTY, LowerChannel.Color);

   drawType = ifInt(ShowZigZagTrail || ShowAllChannelCrossings, DRAW_ARROW, DRAW_NONE);
   SetIndexStyle(MODE_UPPER_BREAKOUT, drawType, EMPTY, EMPTY, UpperChannel.Color); SetIndexArrow(MODE_UPPER_BREAKOUT, Crossings.WingDingsSymbol);
   SetIndexStyle(MODE_LOWER_BREAKOUT, drawType, EMPTY, EMPTY, LowerChannel.Color); SetIndexArrow(MODE_LOWER_BREAKOUT, Crossings.WingDingsSymbol);

   SetIndexStyle(MODE_REVERSAL,       DRAW_NONE);
   SetIndexStyle(MODE_COMBINED_TREND, DRAW_NONE);
}


/**
 * Return a string representation of the input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("ZigZag.Periods=",             ZigZag.Periods,                     ";"+ NL,
                            "ZigZag.Type=",                DoubleQuoteStr(ZigZag.Type),        ";"+ NL,
                            "ZigZag.Width=",               ZigZag.Width,                       ";"+ NL,
                            "ZigZag.Color=",               ColorToStr(ZigZag.Color),           ";"+ NL,
                            "ShowZigZagChannel=",          BoolToStr(ShowZigZagChannel),       ";"+ NL,
                            "ShowZigZagTrail=",            BoolToStr(ShowZigZagTrail),         ";"+ NL,
                            "ShowAllChannelCrossings=",    BoolToStr(ShowAllChannelCrossings), ";"+ NL,
                            "ShowFirstCrossingPerBar=",    BoolToStr(ShowFirstCrossingPerBar), ";"+ NL,
                            "UpperChannel.Color=",         ColorToStr(UpperChannel.Color),     ";"+ NL,
                            "LowerChannel.Color=",         ColorToStr(LowerChannel.Color),     ";"+ NL,
                            "Semaphores.WingDingsSymbol=", Semaphores.WingDingsSymbol,         ";"+ NL,
                            "Crossings.WingDingsSymbol=",  Crossings.WingDingsSymbol,          ";"+ NL,
                            "Max.Bars=",                   Max.Bars,                           ";"+ NL,

                            "Signal.onReversal=",          BoolToStr(Signal.onReversal),       ";"+ NL,
                            "Signal.onReversal.Sound=",    BoolToStr(Signal.onReversal.Sound), ";"+ NL,
                            "Signal.onReversal.Popup=",    BoolToStr(Signal.onReversal.Popup), ";"+ NL,
                            "Signal.onReversal.Mail=",     BoolToStr(Signal.onReversal.Mail),  ";"+ NL,
                            "Signal.onReversal.SMS=",      BoolToStr(Signal.onReversal.SMS),   ";")
   );
}
