/**
 * Multi-color Moving Average
 *
 *
 * Available Moving Average types:
 *  • SMA  - Simple Moving Average:          equal bar weighting
 *  • LWMA - Linear Weighted Moving Average: bar weighting using a linear function
 *  • EMA  - Exponential Moving Average:     bar weighting using an exponential function;       SMMA(n) = EMA(2*n-1)
 *  • ALMA - Arnaud Legoux Moving Average:   bar weighting using a Gaussian function
 *
 *
 * Indicator buffers for iCustom():
 *  • MovingAverage.MODE_MA:    MA values
 *  • MovingAverage.MODE_TREND: trend direction and length
 *    - trend direction:        positive values denote an uptrend (+1...+n), negative values a downtrend (-1...-n)
 *    - trend length:           the absolute direction value is the length of the trend in bars since the last reversal
 */
#include <stddefines.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern int    MA.Periods           = 38;
extern string MA.Method            = "SMA* | LWMA | EMA | ALMA";
extern string MA.AppliedPrice      = "Open | High | Low | Close* | Median | Typical | Weighted";

extern color  Color.UpTrend        = Blue;                 // indicator style management in MQL
extern color  Color.DownTrend      = Red;
extern string Draw.Type            = "Line* | Dot";
extern int    Draw.LineWidth       = 2;

extern int    Max.Values           = 5000;                 // max. number of values to calculate: -1 = all
extern string __________________________;

extern string Signal.onTrendChange = "auto* | off | on";
extern string Signal.Sound         = "auto* | off | on";
extern string Signal.Mail.Receiver = "auto* | off | on | {email-address}";
extern string Signal.SMS.Receiver  = "auto* | off | on | {phone-number}";

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <rsfLibs.mqh>
#include <functions/@ALMA.mqh>
#include <functions/@Trend.mqh>
#include <functions/Configure.Signal.mqh>
#include <functions/Configure.Signal.Mail.mqh>
#include <functions/Configure.Signal.SMS.mqh>
#include <functions/Configure.Signal.Sound.mqh>
#include <functions/EventListener.BarOpen.mqh>

#define MODE_MA               MovingAverage.MODE_MA         // indicator buffer ids
#define MODE_TREND            MovingAverage.MODE_TREND      //
#define MODE_UPTREND          2                             // Draw.Type=Line: If a downtrend is interrupted by a one-bar uptrend this
#define MODE_DOWNTREND        3                             // uptrend is covered by the continuing downtrend. To make single-bar uptrends
#define MODE_UPTREND1         MODE_UPTREND                  // visible they are copied to buffer MODE_UPTREND2 which overlays MODE_DOWNTREND.
#define MODE_UPTREND2         4                             //

#property indicator_chart_window
#property indicator_buffers   5                             // configurable buffers (input dialog)
int       allocated_buffers = 5;                            // used buffers

#property indicator_width1    0
#property indicator_width2    0
#property indicator_width3    2
#property indicator_width4    2
#property indicator_width5    2

double bufferMA       [];                                   // all MA values:       invisible, displayed in "Data" window
double bufferTrend    [];                                   // trend direction:     invisible
double bufferUpTrend1 [];                                   // uptrend values:      visible
double bufferDownTrend[];                                   // downtrend values:    visible, overlays uptrend values
double bufferUpTrend2 [];                                   // single-bar uptrends: visible, overlays downtrend values

int    ma.periods;
int    ma.method;
int    ma.appliedPrice;
string ma.shortName;                                        // name for chart, "Data" window and context menues

double alma.weights[];                                      // ALMA weights

int    draw.type      = DRAW_LINE;                          // DRAW_LINE | DRAW_ARROW
int    draw.arrowSize = 1;                                  // default symbol size for Draw.Type="dot"
string legendLabel;

bool   signals;

bool   signal.sound;
string signal.sound.trendChange_up   = "Signal-Up.wav";
string signal.sound.trendChange_down = "Signal-Down.wav";

bool   signal.mail;
string signal.mail.sender   = "";
string signal.mail.receiver = "";

bool   signal.sms;
string signal.sms.receiver = "";

string signal.info = "";                                    // trend change status hint in chart legend


/**
 * Initialization.
 *
 * @return int - error status
 */
int onInit() {
   if (ProgramInitReason() == IR_RECOMPILE) {
      if (!RestoreInputParameters()) return(last_error);
   }

   // (1) validate inputs
   // MA.Periods
   if (MA.Periods < 1)     return(catch("onInit(1)  Invalid input parameter MA.Periods = "+ MA.Periods, ERR_INVALID_INPUT_PARAMETER));
   ma.periods = MA.Periods;

   // MA.Method
   string sValue, values[];
   if (Explode(MA.Method, "*", values, 2) > 1) {
      int size = Explode(values[0], "|", values, NULL);
      sValue = values[size-1];
   }
   else {
      sValue = StrTrim(MA.Method);
      if (sValue == "") sValue = "SMA";                                 // default MA method
   }
   ma.method = StrToMaMethod(sValue, F_ERR_INVALID_PARAMETER);
   if (ma.method == -1)    return(catch("onInit(2)  Invalid input parameter MA.Method = "+ DoubleQuoteStr(MA.Method), ERR_INVALID_INPUT_PARAMETER));
   MA.Method = MaMethodDescription(ma.method);

   // MA.AppliedPrice
   sValue = StrToLower(MA.AppliedPrice);
   if (Explode(sValue, "*", values, 2) > 1) {
      size = Explode(values[0], "|", values, NULL);
      sValue = values[size-1];
   }
   sValue = StrTrim(sValue);
   if (sValue == "") sValue = "close";                                  // default price type
   ma.appliedPrice = StrToPriceType(sValue, F_ERR_INVALID_PARAMETER);
   if (IsEmpty(ma.appliedPrice)) {
      if      (StrStartsWith("open",     sValue)) ma.appliedPrice = PRICE_OPEN;
      else if (StrStartsWith("high",     sValue)) ma.appliedPrice = PRICE_HIGH;
      else if (StrStartsWith("low",      sValue)) ma.appliedPrice = PRICE_LOW;
      else if (StrStartsWith("close",    sValue)) ma.appliedPrice = PRICE_CLOSE;
      else if (StrStartsWith("median",   sValue)) ma.appliedPrice = PRICE_MEDIAN;
      else if (StrStartsWith("typical",  sValue)) ma.appliedPrice = PRICE_TYPICAL;
      else if (StrStartsWith("weighted", sValue)) ma.appliedPrice = PRICE_WEIGHTED;
      else                 return(catch("onInit(3)  Invalid input parameter MA.AppliedPrice = "+ DoubleQuoteStr(MA.AppliedPrice), ERR_INVALID_INPUT_PARAMETER));
   }
   MA.AppliedPrice = PriceTypeDescription(ma.appliedPrice);

   // Colors: after unserialization the terminal might turn CLR_NONE (0xFFFFFFFF) into Black (0xFF000000)
   if (Color.UpTrend   == 0xFF000000) Color.UpTrend   = CLR_NONE;
   if (Color.DownTrend == 0xFF000000) Color.DownTrend = CLR_NONE;

   // Draw.Type
   sValue = StrToLower(Draw.Type);
   if (Explode(sValue, "*", values, 2) > 1) {
      size = Explode(values[0], "|", values, NULL);
      sValue = values[size-1];
   }
   sValue = StrTrim(sValue);
   if      (StrStartsWith("line", sValue)) { draw.type = DRAW_LINE;  Draw.Type = "Line"; }
   else if (StrStartsWith("dot",  sValue)) { draw.type = DRAW_ARROW; Draw.Type = "Dot";  }
   else                    return(catch("onInit(4)  Invalid input parameter Draw.Type = "+ DoubleQuoteStr(Draw.Type), ERR_INVALID_INPUT_PARAMETER));

   // Draw.LineWidth
   if (Draw.LineWidth < 0) return(catch("onInit(5)  Invalid input parameter Draw.LineWidth = "+ Draw.LineWidth, ERR_INVALID_INPUT_PARAMETER));
   if (Draw.LineWidth > 5) return(catch("onInit(6)  Invalid input parameter Draw.LineWidth = "+ Draw.LineWidth, ERR_INVALID_INPUT_PARAMETER));

   // Max.Values
   if (Max.Values < -1)    return(catch("onInit(7)  Invalid input parameter Max.Values = "+ Max.Values, ERR_INVALID_INPUT_PARAMETER));

   // Signals
   if (!Configure.Signal("MovingAverage", Signal.onTrendChange, signals))                                       return(last_error);
   if (signals) {
      if (!Configure.Signal.Sound(Signal.Sound,         signal.sound                                         )) return(last_error);
      if (!Configure.Signal.Mail (Signal.Mail.Receiver, signal.mail, signal.mail.sender, signal.mail.receiver)) return(last_error);
      if (!Configure.Signal.SMS  (Signal.SMS.Receiver,  signal.sms,                      signal.sms.receiver )) return(last_error);
      if (!signal.sound && !signal.mail && !signal.sms)
         signals = false;
      signal.info = "TrendChange="+ StrLeft(ifString(signal.sound, "Sound,", "") + ifString(signal.mail,  "Mail,",  "") + ifString(signal.sms, "SMS,", ""), -1);
   }


   // (2) setup buffer management
   SetIndexBuffer(MODE_MA,        bufferMA       );                     // all MA values:       invisible, displayed in "Data" window
   SetIndexBuffer(MODE_TREND,     bufferTrend    );                     // trend direction:     invisible
   SetIndexBuffer(MODE_UPTREND1,  bufferUpTrend1 );                     // uptrend values:      visible
   SetIndexBuffer(MODE_DOWNTREND, bufferDownTrend);                     // downtrend values:    visible, overlays uptrend values
   SetIndexBuffer(MODE_UPTREND2,  bufferUpTrend2 );                     // single-bar uptrends: visible, overlays downtrend values


   // (3) data display configuration
   // chart legend
   string strAppliedPrice = "";
   if (ma.appliedPrice != PRICE_CLOSE) strAppliedPrice = ", "+ PriceTypeDescription(ma.appliedPrice);
   ma.shortName  = MA.Method +"("+ MA.Periods + strAppliedPrice +")";
   if (!IsSuperContext()) {                                             // no chart legend if called by iCustom()
       legendLabel = CreateLegendLabel(ma.shortName);
       ObjectRegister(legendLabel);
   }

   // names and labels
   IndicatorShortName(ma.shortName);                                    // context menu
   string ma.dataName = MA.Method +"("+ MA.Periods +")";
   SetIndexLabel(MODE_MA,        ma.dataName);                          // "Data" window and tooltips
   SetIndexLabel(MODE_TREND,     NULL);
   SetIndexLabel(MODE_UPTREND1,  NULL);
   SetIndexLabel(MODE_DOWNTREND, NULL);
   SetIndexLabel(MODE_UPTREND2,  NULL);
   IndicatorDigits(SubPipDigits);


   // (4) drawing options and styles
   int startDraw = 0;
   if (Max.Values >= 0)
      startDraw = Max(startDraw, Bars-Max.Values);
   SetIndexDrawBegin(MODE_UPTREND1,  startDraw);
   SetIndexDrawBegin(MODE_DOWNTREND, startDraw);
   SetIndexDrawBegin(MODE_UPTREND2,  startDraw);
   SetIndicatorOptions();


   // (5) initialize indicator calculations where applicable
   if (ma.periods > 1) {
      if (ma.method == MODE_ALMA) @ALMA.CalculateWeights(alma.weights, ma.periods);
   }
   return(catch("onInit(8)"));
}


/**
 * Deinitialization
 *
 * @return int - error status
 */
int onDeinit() {
   DeleteRegisteredObjects(NULL);
   RepositionLegend();
   return(catch("onDeinit(1)"));
}


/**
 * Called before recompilation.
 *
 * @return int - error status
 */
int onDeinitRecompile() {
   StoreInputParameters();
   return(NO_ERROR);
}


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   // check for finished buffer initialization (needed on terminal start)
   if (!ArraySize(bufferMA))
      return(log("onTick(1)  size(bufferMA) = 0", SetLastError(ERS_TERMINAL_NOT_YET_READY)));

   // reset all buffers and delete garbage behind Max.Values before doing a full recalculation
   if (!UnchangedBars) {
      ArrayInitialize(bufferMA,        EMPTY_VALUE);
      ArrayInitialize(bufferTrend,               0);
      ArrayInitialize(bufferUpTrend1,  EMPTY_VALUE);
      ArrayInitialize(bufferDownTrend, EMPTY_VALUE);
      ArrayInitialize(bufferUpTrend2,  EMPTY_VALUE);
      SetIndicatorOptions();
   }

   // synchronize buffers with a shifted offline chart
   if (ShiftedBars > 0) {
      ShiftIndicatorBuffer(bufferMA,        Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(bufferTrend,     Bars, ShiftedBars,           0);
      ShiftIndicatorBuffer(bufferUpTrend1,  Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(bufferDownTrend, Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(bufferUpTrend2,  Bars, ShiftedBars, EMPTY_VALUE);
   }


   // (1) calculate start bar
   int changedBars = ChangedBars;
   if (Max.Values >= 0) /*&&*/ if (ChangedBars > Max.Values)
      changedBars = Max.Values;
   int startBar = Min(changedBars-1, Bars-ma.periods);
   if (startBar < 0) return(catch("onTick(2)", ERR_HISTORY_INSUFFICIENT));


   // (2) recalculate changed bars
   for (int bar=startBar; bar >= 0; bar--) {
      if (ma.method == MODE_ALMA) {
         // ALMA
         bufferMA[bar] = 0;
         for (int i=0; i < ma.periods; i++) {
            bufferMA[bar] += alma.weights[i] * iMA(NULL, NULL, 1, 0, MODE_SMA, ma.appliedPrice, bar+i);
         }
      }
      else {
         // regular built-in moving average
         bufferMA[bar] = iMA(NULL, NULL, ma.periods, 0, ma.method, ma.appliedPrice, bar);
      }

      // trend direction and length
      @Trend.UpdateDirection(bufferMA, bar, bufferTrend, bufferUpTrend1, bufferDownTrend, bufferUpTrend2, draw.type, true, true, SubPipDigits);
   }


   // (3) update chart legend
   if (!IsSuperContext()) {
       @Trend.UpdateLegend(legendLabel, ma.shortName, "", Color.UpTrend, Color.DownTrend, bufferMA[0], bufferTrend[0], Time[0]);

      // (4) signal trend change
      if (signals) /*&&*/ if (EventListener.BarOpen()) {                // current timeframe
         if      (bufferTrend[1] ==  1) onTrendChange(MODE_UPTREND  );
         else if (bufferTrend[1] == -1) onTrendChange(MODE_DOWNTREND);
      }
   }
   return(last_error);
}


/**
 * Event handler, called on BarOpen if trend has changed.
 *
 * @param  int trend - direction
 *
 * @return bool - success status
 */
bool onTrendChange(int trend) {
   string message = "";
   int    success = 0;

   if (trend == MODE_UPTREND) {
      message = ma.shortName +" turned up: "+ NumberToStr(bufferMA[1], PriceFormat) +" (market: "+ NumberToStr((Bid+Ask)/2, PriceFormat) +")";
      log("onTrendChange(1)  "+ message);
      message = Symbol() +","+ PeriodDescription(Period()) +": "+ message;

      if (signal.sound) success &= _int(PlaySoundEx(signal.sound.trendChange_up));
      if (signal.mail)  success &= !SendEmail(signal.mail.sender, signal.mail.receiver, message, message);  // subject = body
      if (signal.sms)   success &= !SendSMS(signal.sms.receiver, message);
      return(success != 0);
   }

   if (trend == MODE_DOWNTREND) {
      message = ma.shortName +" turned down: "+ NumberToStr(bufferMA[1], PriceFormat) +" (market: "+ NumberToStr((Bid+Ask)/2, PriceFormat) +")";
      log("onTrendChange(2)  "+ message);
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
   IndicatorBuffers(allocated_buffers);

   int drawType  = ifInt(draw.type==DRAW_ARROW, DRAW_ARROW, ifInt(Draw.LineWidth, DRAW_LINE, DRAW_NONE));
   int drawWidth = ifInt(draw.type==DRAW_ARROW, draw.arrowSize, Draw.LineWidth);

   SetIndexStyle(MODE_MA,        DRAW_NONE, EMPTY, EMPTY);
   SetIndexStyle(MODE_TREND,     DRAW_NONE, EMPTY, EMPTY);
   SetIndexStyle(MODE_UPTREND1,  drawType,  EMPTY, drawWidth, Color.UpTrend  ); SetIndexArrow(MODE_UPTREND1,  159);
   SetIndexStyle(MODE_DOWNTREND, drawType,  EMPTY, drawWidth, Color.DownTrend); SetIndexArrow(MODE_DOWNTREND, 159);
   SetIndexStyle(MODE_UPTREND2,  drawType,  EMPTY, drawWidth, Color.UpTrend  ); SetIndexArrow(MODE_UPTREND2,  159);
}


/**
 * Store input parameters in the chart before recompilation.
 *
 * @return bool - success status
 */
bool StoreInputParameters() {
   string name = __NAME();
   Chart.StoreInt   (name +".input.MA.Periods",           MA.Periods           );
   Chart.StoreString(name +".input.MA.Method",            MA.Method            );
   Chart.StoreString(name +".input.MA.AppliedPrice",      MA.AppliedPrice      );
   Chart.StoreColor (name +".input.Color.UpTrend",        Color.UpTrend        );
   Chart.StoreColor (name +".input.Color.DownTrend",      Color.DownTrend      );
   Chart.StoreString(name +".input.Draw.Type",            Draw.Type            );
   Chart.StoreInt   (name +".input.Draw.LineWidth",       Draw.LineWidth       );
   Chart.StoreInt   (name +".input.Max.Values",           Max.Values           );
   Chart.StoreString(name +".input.Signal.onTrendChange", Signal.onTrendChange );
   Chart.StoreString(name +".input.Signal.Sound",         Signal.Sound         );
   Chart.StoreString(name +".input.Signal.Mail.Receiver", Signal.Mail.Receiver );
   Chart.StoreString(name +".input.Signal.SMS.Receiver",  Signal.SMS.Receiver  );
   return(!catch("StoreInputParameters(1)"));
}


/**
 * Restore input parameters found in the chart after recompilation.
 *
 * @return bool - success status
 */
bool RestoreInputParameters() {
   string name = __NAME();
   Chart.RestoreInt   (name +".input.MA.Periods",           MA.Periods           );
   Chart.RestoreString(name +".input.MA.Method",            MA.Method            );
   Chart.RestoreString(name +".input.MA.AppliedPrice",      MA.AppliedPrice      );
   Chart.RestoreColor (name +".input.Color.UpTrend",        Color.UpTrend        );
   Chart.RestoreColor (name +".input.Color.DownTrend",      Color.DownTrend      );
   Chart.RestoreString(name +".input.Draw.Type",            Draw.Type            );
   Chart.RestoreInt   (name +".input.Draw.LineWidth",       Draw.LineWidth       );
   Chart.RestoreInt   (name +".input.Max.Values",           Max.Values           );
   Chart.RestoreString(name +".input.Signal.onTrendChange", Signal.onTrendChange );
   Chart.RestoreString(name +".input.Signal.Sound",         Signal.Sound         );
   Chart.RestoreString(name +".input.Signal.Mail.Receiver", Signal.Mail.Receiver );
   Chart.RestoreString(name +".input.Signal.SMS.Receiver",  Signal.SMS.Receiver  );
   return(!catch("RestoreInputParameters(1)"));
}


/**
 * Return a string representation of the input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("MA.Periods=",           MA.Periods,                           ";", NL,
                            "MA.Method=",            DoubleQuoteStr(MA.Method),            ";", NL,
                            "MA.AppliedPrice=",      DoubleQuoteStr(MA.AppliedPrice),      ";", NL,

                            "Color.UpTrend=",        ColorToStr(Color.UpTrend),            ";", NL,
                            "Color.DownTrend=",      ColorToStr(Color.DownTrend),          ";", NL,
                            "Draw.Type=",            DoubleQuoteStr(Draw.Type),            ";", NL,
                            "Draw.LineWidth=",       Draw.LineWidth,                       ";", NL,

                            "Max.Values=",           Max.Values,                           ";", NL,

                            "Signal.onTrendChange=", DoubleQuoteStr(Signal.onTrendChange), ";", NL,
                            "Signal.Sound=",         DoubleQuoteStr(Signal.Sound),         ";", NL,
                            "Signal.Mail.Receiver=", DoubleQuoteStr(Signal.Mail.Receiver), ";", NL,
                            "Signal.SMS.Receiver=",  DoubleQuoteStr(Signal.SMS.Receiver),  ";")
   );
}
