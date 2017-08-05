/**
 * SuperTrend aka Trend Magic Indicator
 *
 * Combination of a Price-SMA cross-over and a Keltner Channel.
 *
 * Depending on a SMA cross-over signal the upper or the lower band of a Keltner Channel (an ATR channel) is used to calculate a supportive signal
 * line.  The Keltner Channel is calculated around High and Low of the current bar, rather than around the usual Moving Average.  The value of the
 * signal line is restricted to only rising or only falling values until (1) an opposite SMA cross-over signal occures and (2) the opposite channel
 * band crosses the (former supportive) signal line. It means with the standard settings price has to move 2 * ATR + BarSize against the current
 * trend to trigger a change in market direction. This significant counter-move helps to avoid trading in choppy markets.
 *
 * Originally the calculation was done using a CCI (only the SMA part of the CCI was used).
 *
 *   SMA:          SMA(50, TypicalPrice)
 *   TypicalPrice: (H+L+C)/3
 *
 * @source http://www.forexfactory.com/showthread.php?t=214635 (Andrew Forex Trading System)
 * @see    http://www.forexfactory.com/showthread.php?t=268038 (Plateman's CCI aka SuperTrend)
 * @see    http://stockcharts.com/school/doku.php?id=chart_school:technical_indicators:keltner_channels
 *
 * TODO: - SuperTrend Channel per iCustom() hinzuladen
 *       - LineType konfigurierbar machen
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];

/////////////////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////////////////

extern int    SMA.Periods           = 50;
extern string SMA.PriceType         = "Close | Median | Typical* | Weighted";
extern int    ATR.Periods           = 5;

extern color  Color.Uptrend         = Blue;                                            // color management here to allow access by the code
extern color  Color.Downtrend       = Red;
extern color  Color.Changing        = Yellow;
extern color  Color.MovingAverage   = Magenta;

extern string Line.Type             = "Line* | Dot";                                   // signal line type
extern int    Line.Width            = 2;                                               // signal line width

extern int    Max.Values            = 6000;                                            // maximum indicator values to draw: -1 = all
extern int    Shift.Vertical.Pips   = 0;                                               // vertical shift in pips
extern int    Shift.Horizontal.Bars = 0;                                               // horizontal shift in bars

extern string __________________________;

extern bool   Signal.onTrendChange  = false;                                           // signal on trend change
extern string Signal.Sound          = "on | off | account*";
extern string Signal.Mail.Receiver  = "system | account | auto* | off | {address}";    // email address
extern string Signal.SMS.Receiver   = "system | account | auto* | off | {phone}";      // phone number
extern string Signal.IRC.Channel    = "system | account | auto* | off | {channel}";    // IRC channel (not yet implemented)

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <stdlib.mqh>
#include <iFunctions/@Trend.mqh>
#include <signals/Configure.Signal.Mail.mqh>
#include <signals/Configure.Signal.SMS.mqh>
#include <signals/Configure.Signal.Sound.mqh>

#property indicator_chart_window

#property indicator_buffers 7

#define ST.MODE_SIGNAL      SuperTrend.MODE_SIGNAL                   // signal line index
#define ST.MODE_TREND       SuperTrend.MODE_TREND                    // signal trend index
#define ST.MODE_UPTREND     2                                        // signal uptrend line index
#define ST.MODE_DOWNTREND   3                                        // signal downtrend line index
#define ST.MODE_CIP         4                                        // signal change-in-progress index (no 1-bar-reversal buffer)
#define ST.MODE_MA          5                                        // MA index
#define ST.MODE_MA_SIDE     6                                        // MA side of price index

double bufferSignal   [];                                            // full signal line:                       invisible
double bufferTrend    [];                                            // signal trend:                           invisible (+/-)
double bufferUptrend  [];                                            // signal uptrend line:                    visible
double bufferDowntrend[];                                            // signal downtrend line:                  visible
double bufferCip      [];                                            // signal change-in-progress line:         visible
double bufferMa       [];                                            // MA                                      visible
double bufferMaSide   [];                                            // whether price is above or below the MA: invisible

int    sma.periods;
int    sma.priceType;

int    maxValues;                                                    // maximum values to draw:  all values = INT_MAX
double shift.vertical;

string indicator.shortName;                                          // name for chart, chart context menu and "Data Window"
string chart.legendLabel;

bool   signal.sound;
string signal.sound.trendChange_up   = "Signal-Up.wav";
string signal.sound.trendChange_down = "Signal-Down.wav";

bool   signal.mail;
string signal.mail.sender   = "";
string signal.mail.receiver = "";

bool   signal.sms;
string signal.sms.receiver = "";

string signal.info = "";                                             // Infotext in der Chartlegende

int    tickTimerId;                                                  // ticker id (if installed)


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   // (1) Validation
   // SMA.Periods
   if (SMA.Periods < 2)    return(catch("onInit(1)  Invalid input parameter SMA.Periods = "+ SMA.Periods, ERR_INVALID_INPUT_PARAMETER));
   sma.periods = SMA.Periods;
   // SMA.PriceType
   string strValue, elems[];
   if (Explode(SMA.PriceType, "*", elems, 2) > 1) {
      int size = Explode(elems[0], "|", elems, NULL);
      strValue = elems[size-1];
   }
   else strValue = SMA.PriceType;
   sma.priceType = StrToPriceType(strValue, MUTE_ERR_INVALID_PARAMETER);
   if (sma.priceType!=PRICE_CLOSE && (sma.priceType < PRICE_MEDIAN || sma.priceType > PRICE_WEIGHTED))
                           return(catch("onInit(2)  Invalid input parameter SMA.PriceType = \""+ SMA.PriceType +"\"", ERR_INVALID_INPUT_PARAMETER));
   SMA.PriceType = PriceTypeDescription(sma.priceType);

   // ATR
   if (ATR.Periods < 1)    return(catch("onInit(3)  Invalid input parameter ATR.Periods = "+ ATR.Periods, ERR_INVALID_INPUT_PARAMETER));

   // Colors
   if (Color.Uptrend       == 0xFF000000) Color.Uptrend       = CLR_NONE;     // at times after re-compilation or re-start the terminal convertes
   if (Color.Downtrend     == 0xFF000000) Color.Downtrend     = CLR_NONE;     // CLR_NONE (0xFFFFFFFF) to 0xFF000000 (which appears Black)
   if (Color.Changing      == 0xFF000000) Color.Changing      = CLR_NONE;
   if (Color.MovingAverage == 0xFF000000) Color.MovingAverage = CLR_NONE;

   // Line.Width
   if (Line.Width < 1)     return(catch("onInit(4)  Invalid input parameter Line.Width = "+ Line.Width, ERR_INVALID_INPUT_PARAMETER));
   if (Line.Width > 5)     return(catch("onInit(5)  Invalid input parameter Line.Width = "+ Line.Width, ERR_INVALID_INPUT_PARAMETER));

   // Max.Values
   if (Max.Values < -1)    return(catch("onInit(6)  Invalid input parameter Max.Values = "+ Max.Values, ERR_INVALID_INPUT_PARAMETER));
   maxValues = ifInt(Max.Values==-1, INT_MAX, Max.Values);

   // Signale
   if (Signal.onTrendChange) {
      if (!Configure.Signal.Sound(Signal.Sound,         signal.sound                                         )) return(last_error);
      if (!Configure.Signal.Mail (Signal.Mail.Receiver, signal.mail, signal.mail.sender, signal.mail.receiver)) return(last_error);
      if (!Configure.Signal.SMS  (Signal.SMS.Receiver,  signal.sms,                      signal.sms.receiver )) return(last_error);
      signal.info = "TrendChange="+ StringLeft(ifString(signal.sound, "Sound,", "") + ifString(signal.mail,  "Mail,",  "") + ifString(signal.sms,   "SMS,",   ""), -1);
      log("onInit(7)  Signal.onTrendChange="+ Signal.onTrendChange +"  Sound="+ signal.sound +"  Mail="+ ifString(signal.mail, signal.mail.receiver, "0") +"  SMS="+ ifString(signal.sms, signal.sms.receiver, "0"));
   }


   // (2) Chart legend
   indicator.shortName = __NAME__ +"("+ SMA.Periods +")";
   if (!IsSuperContext()) {
      chart.legendLabel   = CreateLegendLabel(indicator.shortName);
      ObjectRegister(chart.legendLabel);
   }


   // (3) Buffer management
   SetIndexBuffer(ST.MODE_SIGNAL,    bufferSignal   );
   SetIndexBuffer(ST.MODE_TREND,     bufferTrend    );
   SetIndexBuffer(ST.MODE_UPTREND,   bufferUptrend  );
   SetIndexBuffer(ST.MODE_DOWNTREND, bufferDowntrend);
   SetIndexBuffer(ST.MODE_CIP,       bufferCip      );
   SetIndexBuffer(ST.MODE_MA,        bufferMa       );
   SetIndexBuffer(ST.MODE_MA_SIDE,   bufferMaSide   );

   // Drawing options
   int startDraw = Max(SMA.Periods-1, Bars-ifInt(Max.Values < 0, Bars, Max.Values)) + Shift.Horizontal.Bars;
   SetIndexDrawBegin(ST.MODE_SIGNAL,    startDraw); SetIndexShift(ST.MODE_SIGNAL,    Shift.Horizontal.Bars);
   SetIndexDrawBegin(ST.MODE_TREND,     startDraw); SetIndexShift(ST.MODE_TREND,     Shift.Horizontal.Bars);
   SetIndexDrawBegin(ST.MODE_UPTREND,   startDraw); SetIndexShift(ST.MODE_UPTREND,   Shift.Horizontal.Bars);
   SetIndexDrawBegin(ST.MODE_DOWNTREND, startDraw); SetIndexShift(ST.MODE_DOWNTREND, Shift.Horizontal.Bars);
   SetIndexDrawBegin(ST.MODE_CIP,       startDraw); SetIndexShift(ST.MODE_CIP,       Shift.Horizontal.Bars);
   SetIndexDrawBegin(ST.MODE_MA,        startDraw); SetIndexShift(ST.MODE_MA,        Shift.Horizontal.Bars);
   SetIndexDrawBegin(ST.MODE_MA_SIDE,   startDraw); SetIndexShift(ST.MODE_MA_SIDE,   Shift.Horizontal.Bars);

   shift.vertical = Shift.Vertical.Pips * Pips;                      // TODO: prevent Digits/Point errors


   // (4) Indicator styles and display options
   IndicatorDigits(SubPipDigits);
   IndicatorShortName(indicator.shortName);                          // chart context menu
   SetIndicatorStyles();                                             // work around various terminal bugs (see there)

   return(catch("onInit(8)"));
}


/**
 * Initialization post processing
 *
 * @return int - error status
 */
int afterInit() {
   // Install chart ticker in signal mode on a synthetic chart. ChartInfos might not run (e.g. on VPS).
   if (Signal.onTrendChange) /*&&*/ if (!This.IsTesting()) /*&&*/ if (StringCompareI(GetServerName(), "XTrade-Synthetic")) {
      int hWnd    = ec_hChart(__ExecutionContext);
      int millis  = 10000;                                           // 10 seconds are sufficient in VPS environment
      int timerId = SetupTickTimer(hWnd, millis, TICK_CHART_REFRESH);
      if (!timerId) return(catch("afterInit(1)->SetupTickTimer(hWnd="+ IntToHexStr(hWnd) +") failed", ERR_RUNTIME_ERROR));
      tickTimerId = timerId;

      // Display ticker status.
      string label = __NAME__+".Status";
      if (ObjectFind(label) == 0)
         ObjectDelete(label);
      if (ObjectCreate(label, OBJ_LABEL, 0, 0, 0)) {
         ObjectSet    (label, OBJPROP_CORNER, CORNER_TOP_RIGHT);
         ObjectSet    (label, OBJPROP_XDISTANCE, 38);
         ObjectSet    (label, OBJPROP_YDISTANCE, 38);
         ObjectSetText(label, "n", 6, "Webdings", LimeGreen);        // Webdings, circled marker, green="Online"
         ObjectRegister(label);
      }
   }
   return(catch("afterInit(3)"));
}


/**
 * De-initialization
 *
 * @return int - error status
 */
int onDeinit() {
   // uninstall an installed chart ticker
   if (tickTimerId > NULL) {
      int id = tickTimerId; tickTimerId = NULL;
      if (!RemoveTickTimer(id)) return(catch("onDeinit(1)->RemoveTickTimer(timerId="+ id +") failed", ERR_RUNTIME_ERROR));
   }
   DeleteRegisteredObjects(NULL);
   RepositionLegend();
   return(catch("onDeinit(2)"));
}



/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   // make sure indicator buffers are initialized
   if (ArraySize(bufferSignal) == 0)                                 // may happen at terminal start
      return(debug("onTick(1)  size(bufferSignal) = 0", SetLastError(ERS_TERMINAL_NOT_YET_READY)));

   // reset buffers before doing a full re-calculation (clears garbage after Max.Values)
   if (!ValidBars) {
      ArrayInitialize(bufferSignal,    EMPTY_VALUE);
      ArrayInitialize(bufferTrend,               0);
      ArrayInitialize(bufferUptrend,   EMPTY_VALUE);
      ArrayInitialize(bufferDowntrend, EMPTY_VALUE);
      ArrayInitialize(bufferCip,       EMPTY_VALUE);
      ArrayInitialize(bufferMa,        EMPTY_VALUE);
      ArrayInitialize(bufferMaSide,              0);
      SetIndicatorStyles();                                          // work around various terminal bugs (see there)
   }

   // on ShiftedBars synchronize buffers accordingly
   if (ShiftedBars > 0) {
      ShiftIndicatorBuffer(bufferSignal,    Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(bufferTrend,     Bars, ShiftedBars,           0);
      ShiftIndicatorBuffer(bufferUptrend,   Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(bufferDowntrend, Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(bufferCip,       Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(bufferMa,        Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(bufferMaSide,    Bars, ShiftedBars,           0);
   }


   // (1) calculate the start bar
   int bars     = Min(ChangedBars, maxValues);
   int startBar = Min(bars-1, Bars-sma.periods);
   if (startBar < 0) {
      if (IsSuperContext()) return(catch("onTick(2)", ERR_HISTORY_INSUFFICIENT));
      SetLastError(ERR_HISTORY_INSUFFICIENT);                        // set error but don't return to update the legend
   }

   double dNull[];


   // (2) re-calculate invalid bars
   for (int bar=startBar; bar >= 0; bar--) {
      // price, MA, ATR, bands
      double price  = iMA(NULL, NULL,           1, 0, MODE_SMA, sma.priceType, bar);
      bufferMa[bar] = iMA(NULL, NULL, sma.periods, 0, MODE_SMA, sma.priceType, bar);

      double atr = iATR(NULL, NULL, ATR.Periods, bar);
      if (bar == 0) {                                                // suppress ATR jitter at the progressing bar 0
         double  tr0 = iATR(NULL, NULL,           1, 0);             // TrueRange of the progressing bar 0
         double atr1 = iATR(NULL, NULL, ATR.Periods, 1);             // ATR(Periods) of the previous closed bar 1
         if (tr0 < atr1)                                             // use the previous ATR as long as the progressing bar's range does not exceed it
            atr = atr1;
      }

      double upperBand = High[bar] + atr;
      double lowerBand = Low [bar] - atr;

      bool checkCipBuffer = false;

      if (price > bufferMa[bar]) {                                   // price is above the MA
         bufferMaSide[bar] = 1;

         bufferSignal[bar] = lowerBand;
         if (bufferMaSide[bar+1] != 0) {                             // limit the signal line to rising values
            if (bufferSignal[bar+1] > bufferSignal[bar]) {
               bufferSignal[bar] = bufferSignal[bar+1];
               checkCipBuffer    = true;
            }
         }
      }
      else /*price < bufferMa[bar]*/ {                               // price is below the MA
         bufferMaSide[bar] = -1;

         bufferSignal[bar] = upperBand;
         if (bufferMaSide[bar+1] != 0) {                             // limit the signal line to falling values
            if (bufferSignal[bar+1] < bufferSignal[bar]) {
               bufferSignal[bar] = bufferSignal[bar+1];
               checkCipBuffer    = true;
            }
         }
      }

      // update trend direction and colors (no uptrend2[] buffer as there can't be 1-bar-reversals)
      @Trend.UpdateDirection(bufferSignal, bar, bufferTrend, bufferUptrend, bufferDowntrend, DRAW_LINE, dNull);

      // update "change" buffer on flat line (after trend calculation)
      if (checkCipBuffer) {
         if (bufferTrend[bar] > 0) {                                 // up-trend
            if (bufferMaSide[bar] < 0) {                             // set "change" buffer if on opposite MA side
               bufferCip[bar]   = bufferSignal[bar];
               bufferCip[bar+1] = bufferSignal[bar+1];
            }
         }
         else /*downtrend*/{
            if (bufferMaSide[bar] > 0) {                             // set "change" buffer if on opposite MA side
               bufferCip[bar]   = bufferSignal[bar];
               bufferCip[bar+1] = bufferSignal[bar+1];
            }
         }
      }
      // reset a previously set "change" buffer after trend change (not on continuation)
      else if (bufferTrend[bar] * bufferTrend[bar+1] <= 0) {         // on trend continuation the result is always positive
         int i = bar+1;
         while (bufferCip[i] != EMPTY_VALUE) {
            bufferCip[i] = EMPTY_VALUE;
            i++;
         }
      }
   }


   if (!IsSuperContext()) {
        // (4) update chart legend
       @Trend.UpdateLegend(chart.legendLabel, indicator.shortName, signal.info, Color.Uptrend, Color.Downtrend, bufferSignal[0], bufferTrend[0], Time[0]);


       // (5) Signal mode: check for and signal trend changes
       if (Signal.onTrendChange) /*&&*/ if (EventListener.BarOpen()) {   // BarOpen on current timeframe
          if      (bufferTrend[1] ==  1) onTrendChange(ST.MODE_UPTREND  );
          else if (bufferTrend[1] == -1) onTrendChange(ST.MODE_DOWNTREND);
       }
   }
   return(catch("onTick(3)"));
}


/**
 * Event handler, called after change of trend on BarOpen.
 *
 * @return bool - error status
 */
bool onTrendChange(int trend) {
   string message = "";
   int    success = 0;

   if (trend == ST.MODE_UPTREND) {
      message = indicator.shortName +" turned up";
      if (__LOG) log("onTrendChange(1)  "+ message);
      message = Symbol() +","+ PeriodDescription(Period()) +": "+ message;

      if (signal.sound) success &= _int(PlaySoundEx(signal.sound.trendChange_up));
      if (signal.mail)  success &= !SendEmail(signal.mail.sender, signal.mail.receiver, message, "");    // subject only (empty mail body)
      if (signal.sms)   success &= !SendSMS(signal.sms.receiver, message);

      return(success != 0);
   }

   if (trend == ST.MODE_DOWNTREND) {
      message = indicator.shortName +" turned down";
      if (__LOG) log("onTrendChange(2)  "+ message);
      message = Symbol() +","+ PeriodDescription(Period()) +": "+ message;

      if (signal.sound) success &= _int(PlaySoundEx(signal.sound.trendChange_down));
      if (signal.mail)  success &= !SendEmail(signal.mail.sender, signal.mail.receiver, message, "");    // subject only (empty mail body)
      if (signal.sms)   success &= !SendSMS(signal.sms.receiver, message);

      return(success != 0);
   }

   return(!catch("onTrendChange(3)  invalid parameter trend = "+ trend, ERR_INVALID_PARAMETER));
}


/**
 * Set indicator styles. Works around various terminal bugs causing indicator color/style changes after re-compilation. Regularily styles must be
 * set in init(). However, after re-compilation styles must be set in start() to be displayed correctly.
 */
void SetIndicatorStyles() {
   SetIndexStyle(ST.MODE_SIGNAL,    DRAW_NONE, EMPTY, EMPTY,      CLR_NONE           );
   SetIndexStyle(ST.MODE_TREND,     DRAW_NONE, EMPTY, EMPTY,      CLR_NONE           );
   SetIndexStyle(ST.MODE_UPTREND,   DRAW_LINE, EMPTY, Line.Width, Color.Uptrend      );
   SetIndexStyle(ST.MODE_DOWNTREND, DRAW_LINE, EMPTY, Line.Width, Color.Downtrend    );
   SetIndexStyle(ST.MODE_CIP,       DRAW_LINE, EMPTY, Line.Width, Color.Changing     );
   SetIndexStyle(ST.MODE_MA,        DRAW_LINE, EMPTY, EMPTY,      Color.MovingAverage);
   SetIndexStyle(ST.MODE_MA_SIDE,   DRAW_NONE, EMPTY, EMPTY,      CLR_NONE           );

   SetIndexLabel(ST.MODE_SIGNAL,    indicator.shortName);            // chart tooltip and "Data Window"
   SetIndexLabel(ST.MODE_TREND,     NULL               );
   SetIndexLabel(ST.MODE_UPTREND,   NULL               );
   SetIndexLabel(ST.MODE_DOWNTREND, NULL               );
   SetIndexLabel(ST.MODE_CIP,       NULL               );
   SetIndexLabel(ST.MODE_MA,        NULL               );
   SetIndexLabel(ST.MODE_MA_SIDE,   NULL               );
}


/**
 * Return a string presentation of the input parameters (logging).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("init()  inputs: ",

                            "SMA.Periods=",           SMA.Periods                    , "; ",
                            "SMA.PriceType=",         DoubleQuoteStr(SMA.PriceType)  , "; ",
                            "ATR.Periods=",           ATR.Periods                    , "; ",

                            "Color.Uptrend=",         ColorToStr(Color.Uptrend)      , "; ",
                            "Color.Downtrend=",       ColorToStr(Color.Downtrend)    , "; ",
                            "Color.Changing=",        ColorToStr(Color.Changing)     , "; ",
                            "Color.MovingAverage=",   ColorToStr(Color.MovingAverage), "; ",

                            "Line.Type=",             DoubleQuoteStr(Line.Type)      , "; ",
                            "Line.Width=",            Line.Width                     , "; ",

                            "Max.Values=",            Max.Values                     , "; ",
                            "Shift.Vertical.Pips=",   Shift.Vertical.Pips            , "; ",
                            "Shift.Horizontal.Bars=", Shift.Horizontal.Bars          , "; ",

                            "__lpSuperContext=0x",    IntToHexStr(__lpSuperContext)  , "; ")
   );
}
