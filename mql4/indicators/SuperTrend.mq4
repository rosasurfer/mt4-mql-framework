/**
 * SuperTrend Indicator
 *
 * Combination of a Price-SMA cross-over and a Keltner Channel.
 *
 * Depending on a Price-SMA cross-over signal the upper or the lower band of a Keltner Channel (ATR channel) is used to
 * calculate a supportive signal line.  The Keltner Channel is calculated around High and Low of the current bar rather than
 * around the usual Moving Average.  The value of the signal line is restricted to only rising or falling values until (1) an
 * opposite SMA cross-over signal occures and (2) the opposite channel band crosses the former supportive signal line.
 * It means with the standard settings price has to move 2 * ATR + BarSize against the current trend to trigger a change in
 * indicator direction. This significant counter-move helps to avoid trading in choppy markets.
 *
 *   SMA:          SMA(50, TypicalPrice)
 *   TypicalPrice: (H+L+C)/3
 *
 * The original implementations use the SMA part of a CCI.
 *
 * @source http://www.forexfactory.com/showthread.php?t=214635 (Andrew Forex Trading System)
 * @see    http://www.forexfactory.com/showthread.php?t=268038 (Plateman's CCI aka SuperTrend)
 * @see    http://stockcharts.com/school/doku.php?id=chart_school:technical_indicators:keltner_channels
 *
 * TODO: - SuperTrend Channel per iCustom() hinzuladen
 *       - LineType konfigurierbar machen
 */
#include <stddefines.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern int    SMA.Periods          = 50;
extern string SMA.PriceType        = "Close | Median | Typical* | Weighted";
extern int    ATR.Periods          = 1;

extern color  Color.Uptrend        = Blue;                           // color management here to allow access by the code
extern color  Color.Downtrend      = Red;
extern color  Color.Changing       = Yellow;
extern color  Color.MovingAverage  = Magenta;

extern int    Line.Width           = 2;                              // signal line width

extern int    Max.Values           = 5000;                           // max. number of values to calculate: -1 = all

extern string __________________________;

extern string Signal.onTrendChange = "auto* | off | on";
extern string Signal.Sound         = "auto* | off | on";
extern string Signal.Mail.Receiver = "auto* | off | on | {email-address}";
extern string Signal.SMS.Receiver  = "auto* | off | on | {phone-number}";

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <rsfLibs.mqh>
#include <functions/@Trend.mqh>
#include <functions/Configure.Signal.mqh>
#include <functions/Configure.Signal.Mail.mqh>
#include <functions/Configure.Signal.SMS.mqh>
#include <functions/Configure.Signal.Sound.mqh>
#include <functions/EventListener.BarOpen.mqh>

#property indicator_chart_window
#property indicator_buffers   7                                      // configurable buffers (input dialog)
int       allocated_buffers = 7;                                     // used buffers

#define ST.MODE_SIGNAL        SuperTrend.MODE_SIGNAL                 // signal line index
#define ST.MODE_TREND         SuperTrend.MODE_TREND                  // signal trend index
#define ST.MODE_UPTREND       2                                      // signal uptrend line index
#define ST.MODE_DOWNTREND     3                                      // signal downtrend line index
#define ST.MODE_CIP           4                                      // signal change-in-progress index (no 1-bar-reversal buffer)
#define ST.MODE_MA            5                                      // MA index
#define ST.MODE_MA_SIDE       6                                      // MA side of price index

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

string indicator.shortName;                                          // name for chart, chart context menu and Data window
string chart.legendLabel;

bool   signals;

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
   else {
      strValue = StrTrim(SMA.PriceType);
      if (strValue == "") strValue = "Typical";                            // default price type
   }
   sma.priceType = StrToPriceType(strValue, F_ERR_INVALID_PARAMETER);
   if (sma.priceType!=PRICE_CLOSE && (sma.priceType < PRICE_MEDIAN || sma.priceType > PRICE_WEIGHTED))
                           return(catch("onInit(2)  Invalid input parameter SMA.PriceType = \""+ SMA.PriceType +"\"", ERR_INVALID_INPUT_PARAMETER));
   SMA.PriceType = PriceTypeDescription(sma.priceType);

   // ATR
   if (ATR.Periods < 1)    return(catch("onInit(3)  Invalid input parameter ATR.Periods = "+ ATR.Periods, ERR_INVALID_INPUT_PARAMETER));

   // Colors
   if (Color.Uptrend       == 0xFF000000) Color.Uptrend       = CLR_NONE;  // at times after re-compilation or re-start the terminal convertes
   if (Color.Downtrend     == 0xFF000000) Color.Downtrend     = CLR_NONE;  // CLR_NONE (0xFFFFFFFF) to 0xFF000000 (which appears Black)
   if (Color.Changing      == 0xFF000000) Color.Changing      = CLR_NONE;
   if (Color.MovingAverage == 0xFF000000) Color.MovingAverage = CLR_NONE;

   // Line.Width
   if (Line.Width < 0)     return(catch("onInit(4)  Invalid input parameter Line.Width = "+ Line.Width, ERR_INVALID_INPUT_PARAMETER));
   if (Line.Width > 5)     return(catch("onInit(5)  Invalid input parameter Line.Width = "+ Line.Width, ERR_INVALID_INPUT_PARAMETER));

   // Max.Values
   if (Max.Values < -1)    return(catch("onInit(6)  Invalid input parameter Max.Values = "+ Max.Values, ERR_INVALID_INPUT_PARAMETER));
   maxValues = ifInt(Max.Values==-1, INT_MAX, Max.Values);

   // Signale
   if (!Configure.Signal("SuperTrend", Signal.onTrendChange, signals))                                          return(last_error);
   if (signals) {
      if (!Configure.Signal.Sound(Signal.Sound,         signal.sound                                         )) return(last_error);
      if (!Configure.Signal.Mail (Signal.Mail.Receiver, signal.mail, signal.mail.sender, signal.mail.receiver)) return(last_error);
      if (!Configure.Signal.SMS  (Signal.SMS.Receiver,  signal.sms,                      signal.sms.receiver )) return(last_error);
      if (!signal.sound && !signal.mail && !signal.sms)
         signals = false;
      signal.info = "TrendChange="+ StrLeft(ifString(signal.sound, "Sound,", "") + ifString(signal.mail,  "Mail,",  "") + ifString(signal.sms,   "SMS,",   ""), -1);
   }


   // (2) Chart legend
   indicator.shortName = __NAME() +"("+ SMA.Periods +")";
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
   int startDraw = 0;
   if (Max.Values >= 0) startDraw = Bars - Max.Values;
   if (startDraw  <  0) startDraw = 0;
   SetIndexDrawBegin(ST.MODE_UPTREND,   startDraw);
   SetIndexDrawBegin(ST.MODE_DOWNTREND, startDraw);
   SetIndexDrawBegin(ST.MODE_CIP,       startDraw);
   SetIndexDrawBegin(ST.MODE_MA,        startDraw);


   // (4) Indicator styles and display options
   IndicatorDigits(SubPipDigits);
   IndicatorShortName(indicator.shortName);                          // chart context menu
   SetIndicatorOptions();

   return(catch("onInit(7)"));
}


/**
 * Initialization post processing
 *
 * @return int - error status
 */
int afterInit() {
   // Install chart ticker in signal mode on a synthetic chart. ChartInfos might not run (e.g. on VPS).
   if (signals) /*&&*/ if (!This.IsTesting()) /*&&*/ if (StrCompareI(GetServerName(), "XTrade-Synthetic")) {
      int hWnd    = __ExecutionContext[I_EC.hChart];
      int millis  = 10000;                                           // 10 seconds are sufficient in VPS environment
      int timerId = SetupTickTimer(hWnd, millis, TICK_CHART_REFRESH);
      if (!timerId) return(catch("afterInit(1)->SetupTickTimer(hWnd="+ IntToHexStr(hWnd) +") failed", ERR_RUNTIME_ERROR));
      tickTimerId = timerId;

      // Display ticker status.
      string label = __NAME() +".Status";
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
   if (!ArraySize(bufferSignal))                                     // may happen at terminal start
      return(log("onTick(1)  size(bufferSignal) = 0", SetLastError(ERS_TERMINAL_NOT_YET_READY)));

   // reset all buffers and delete garbage behind Max.Values before doing a full recalculation
   if (!UnchangedBars) {
      ArrayInitialize(bufferSignal,    EMPTY_VALUE);
      ArrayInitialize(bufferTrend,               0);
      ArrayInitialize(bufferUptrend,   EMPTY_VALUE);
      ArrayInitialize(bufferDowntrend, EMPTY_VALUE);
      ArrayInitialize(bufferCip,       EMPTY_VALUE);
      ArrayInitialize(bufferMa,        EMPTY_VALUE);
      ArrayInitialize(bufferMaSide,              0);
      SetIndicatorOptions();
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


   // (2) re-calculate changed bars
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
      @Trend.UpdateDirection(bufferSignal, bar, bufferTrend, bufferUptrend, bufferDowntrend, dNull, DRAW_LINE, true);

      // update "change" buffer on flat line (after trend calculation)
      if (checkCipBuffer) {
         if (bufferTrend[bar] > 0) {                                 // uptrend
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
       if (signals) /*&&*/ if (EventListener.BarOpen()) {      // BarOpen on current timeframe
          if      (bufferTrend[1] ==  1) onTrendChange(ST.MODE_UPTREND  );
          else if (bufferTrend[1] == -1) onTrendChange(ST.MODE_DOWNTREND);
       }
   }
   return(catch("onTick(3)"));
}


/**
 * Event handler, called on BarOpen if trend has changed.
 *
 * @param  int trend - direction
 *
 * @return bool - error status
 */
bool onTrendChange(int trend) {
   string message = "";
   int    success = 0;

   if (trend == ST.MODE_UPTREND) {
      message = indicator.shortName +" turned up: "+ NumberToStr(bufferSignal[1], PriceFormat) +" (market: "+ NumberToStr((Bid+Ask)/2, PriceFormat) +")";
      if (__LOG()) log("onTrendChange(1)  "+ message);
      message = Symbol() +","+ PeriodDescription(Period()) +": "+ message;

      if (signal.sound) success &= _int(PlaySoundEx(signal.sound.trendChange_up));
      if (signal.mail)  success &= !SendEmail(signal.mail.sender, signal.mail.receiver, message, message);  // subject = body
      if (signal.sms)   success &= !SendSMS(signal.sms.receiver, message);

      return(success != 0);
   }

   if (trend == ST.MODE_DOWNTREND) {
      message = indicator.shortName +" turned down: "+ NumberToStr(bufferSignal[1], PriceFormat) +" (market: "+ NumberToStr((Bid+Ask)/2, PriceFormat) +")";
      if (__LOG()) log("onTrendChange(2)  "+ message);
      message = Symbol() +","+ PeriodDescription(Period()) +": "+ message;

      if (signal.sound) success &= _int(PlaySoundEx(signal.sound.trendChange_down));
      if (signal.mail)  success &= !SendEmail(signal.mail.sender, signal.mail.receiver, message, message);  // subject = body
      if (signal.sms)   success &= !SendSMS(signal.sms.receiver, message);

      return(success != 0);
   }

   return(!catch("onTrendChange(3)  invalid parameter trend = "+ trend, ERR_INVALID_PARAMETER));
}


/**
 * Workaround for various terminal bugs when setting indicator options. Usually options are set in init(). However after
 * recompilation options must be set in start() to not get ignored.
 */
void SetIndicatorOptions() {
   int drawType = ifInt(Line.Width, DRAW_LINE, DRAW_NONE);

   SetIndexStyle(ST.MODE_SIGNAL,    DRAW_NONE, EMPTY, EMPTY);
   SetIndexStyle(ST.MODE_TREND,     DRAW_NONE, EMPTY, EMPTY);
   SetIndexStyle(ST.MODE_UPTREND,   drawType,  EMPTY, Line.Width, Color.Uptrend      );
   SetIndexStyle(ST.MODE_DOWNTREND, drawType,  EMPTY, Line.Width, Color.Downtrend    );
   SetIndexStyle(ST.MODE_CIP,       drawType,  EMPTY, Line.Width, Color.Changing     );
   SetIndexStyle(ST.MODE_MA,        DRAW_LINE, EMPTY, EMPTY,      Color.MovingAverage);
   SetIndexStyle(ST.MODE_MA_SIDE,   DRAW_NONE, EMPTY, EMPTY);

   SetIndexLabel(ST.MODE_SIGNAL,    indicator.shortName);            // chart tooltip and Data window
   SetIndexLabel(ST.MODE_TREND,     NULL               );
   SetIndexLabel(ST.MODE_UPTREND,   NULL               );
   SetIndexLabel(ST.MODE_DOWNTREND, NULL               );
   SetIndexLabel(ST.MODE_CIP,       NULL               );
   SetIndexLabel(ST.MODE_MA,        NULL               );
   SetIndexLabel(ST.MODE_MA_SIDE,   NULL               );
}


/**
 * Return a string representation of the input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("SMA.Periods=",          SMA.Periods,                          ";", NL,
                            "SMA.PriceType=",        DoubleQuoteStr(SMA.PriceType),        ";", NL,
                            "ATR.Periods=",          ATR.Periods,                          ";", NL,

                            "Color.Uptrend=",        ColorToStr(Color.Uptrend),            ";", NL,
                            "Color.Downtrend=",      ColorToStr(Color.Downtrend),          ";", NL,
                            "Color.Changing=",       ColorToStr(Color.Changing),           ";", NL,
                            "Color.MovingAverage=",  ColorToStr(Color.MovingAverage),      ";", NL,

                            "Line.Width=",           Line.Width,                           ";", NL,
                            "Max.Values=",           Max.Values,                           ";", NL,

                            "Signal.onTrendChange=", DoubleQuoteStr(Signal.onTrendChange), ";", NL,
                            "Signal.Sound=",         DoubleQuoteStr(Signal.Sound),         ";", NL,
                            "Signal.Mail.Receiver=", DoubleQuoteStr(Signal.Mail.Receiver), ";", NL,
                            "Signal.SMS.Receiver=",  DoubleQuoteStr(Signal.SMS.Receiver),  ";")
   );
}
