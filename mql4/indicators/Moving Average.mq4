/**
 * Multi-color Moving Average
 *
 *
 * Available MA types:
 *  • SMA  - Simple Moving Average:          equal bar weighting
 *  • TMA  - Triangular Moving Average:      SMA which has been averaged again: SMA(SMA(n/2)/2), more smooth but more lag
 *  • LWMA - Linear Weighted Moving Average: bar weighting using a linear function
 *  • EMA  - Exponential Moving Average:     bar weighting using an exponential function
 *  • ALMA - Arnaud Legoux Moving Average:   bar weighting using a Gaussian function
 *
 * The Smoothed Moving Average (SMMA) is omitted as it's just an EMA of a different period: SMMA(n) = EMA(2*n-1)
 *
 * Indicator buffers to use with iCustom():
 *  • MovingAverage.MODE_MA:    MA values
 *  • MovingAverage.MODE_TREND: trend direction and length
 *    - trend direction:        positive values represent an uptrend (+1...+n), negative values a downtrend (-1...-n)
 *    - trend length:           the absolute direction value is the length of the trend in bars since the last reversal
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern int    MA.Periods           = 38;
extern string MA.Method            = "SMA* | TMA | LWMA | EMA | ALMA";
extern string MA.AppliedPrice      = "Open | High | Low | Close* | Median | Typical | Weighted";

extern color  Color.UpTrend        = Blue;                 // indicator style management in MQL
extern color  Color.DownTrend      = Red;
extern string Draw.Type            = "Line* | Dot";
extern int    Draw.LineWidth       = 2;

extern int    Max.Values           = 3000;                 // max. number of values to display: -1 = all
extern string __________________________;

extern string Signal.onTrendChange = "auto* | off | on";
extern string Signal.Sound         = "auto* | off | on";
extern string Signal.Mail.Receiver = "auto* | off | on | {email-address}";
extern string Signal.SMS.Receiver  = "auto* | off | on | {phone-number}";

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <stdlibs.mqh>
#include <functions/@ALMA.mqh>
#include <functions/@Trend.mqh>
#include <functions/Configure.Signal.mqh>
#include <functions/Configure.Signal.Mail.mqh>
#include <functions/Configure.Signal.SMS.mqh>
#include <functions/Configure.Signal.Sound.mqh>
#include <functions/EventListener.BarOpen.mqh>

#define MODE_MA             MovingAverage.MODE_MA           // indicator buffer ids
#define MODE_TREND          MovingAverage.MODE_TREND        //
#define MODE_UPTREND        2                               // Draw.Type=Line: If a downtrend is interrupted by a one-bar uptrend this
#define MODE_DOWNTREND      3                               // uptrend is covered by the continuing downtrend. To make single-bar uptrends
#define MODE_UPTREND1       MODE_UPTREND                    // visible they are copied to buffer MODE_UPTREND2 which overlays MODE_DOWNTREND.
#define MODE_UPTREND2       4                               //
#define MODE_TMA_SMA        5                               //

#property indicator_chart_window

#property indicator_buffers 5

#property indicator_width1  0
#property indicator_width2  0
#property indicator_width3  2
#property indicator_width4  2
#property indicator_width5  2

double bufferMA       [];                                   // all MA values:       invisible, displayed in "Data" window
double bufferTrend    [];                                   // trend direction:     invisible
double bufferUpTrend1 [];                                   // uptrend values:      visible
double bufferDownTrend[];                                   // downtrend values:    visible, overlays uptrend values
double bufferUpTrend2 [];                                   // single-bar uptrends: visible, overlays downtrend values

int    ma.periods;
int    ma.method;
int    ma.appliedPrice;
string ma.shortName;                                        // name for chart, "Data" window and context menues

int    tma.periods.1;                                       // TMA sub periods
int    tma.periods.2;
double tma.bufferSMA[];                                     // TMA intermediate SMA buffer

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
   if (InitReason() == IR_RECOMPILE) {
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
      sValue = StringTrim(MA.Method);
      if (sValue == "") sValue = "SMA";                                 // default MA method
   }
   ma.method = StrToMaMethod(sValue, F_ERR_INVALID_PARAMETER);
   if (ma.method == -1)    return(catch("onInit(4)  Invalid input parameter MA.Method = "+ DoubleQuoteStr(MA.Method), ERR_INVALID_INPUT_PARAMETER));
   MA.Method = MaMethodDescription(ma.method);

   // MA.AppliedPrice
   if (Explode(MA.AppliedPrice, "*", values, 2) > 1) {
      size = Explode(values[0], "|", values, NULL);
      sValue = values[size-1];
   }
   else {
      sValue = StringTrim(MA.AppliedPrice);
      if (sValue == "") sValue = "Close";                               // default price type
   }
   ma.appliedPrice = StrToPriceType(sValue, F_ERR_INVALID_PARAMETER);
   if (ma.appliedPrice==-1 || ma.appliedPrice > PRICE_WEIGHTED)
                           return(catch("onInit(5)  Invalid input parameter MA.AppliedPrice = "+ DoubleQuoteStr(MA.AppliedPrice), ERR_INVALID_INPUT_PARAMETER));
   MA.AppliedPrice = PriceTypeDescription(ma.appliedPrice);

   // Colors
   if (Color.UpTrend   == 0xFF000000) Color.UpTrend   = CLR_NONE;       // after deserialization the terminal might turn CLR_NONE (0xFFFFFFFF) into Black (0xFF000000)
   if (Color.DownTrend == 0xFF000000) Color.DownTrend = CLR_NONE;

   // Draw.Type
   sValue = StringToLower(Draw.Type);
   if (Explode(sValue, "*", values, 2) > 1) {
      size = Explode(values[0], "|", values, NULL);
      sValue = values[size-1];
   }
   sValue = StringTrim(sValue);
   if      (StringStartsWith("line", sValue)) { draw.type = DRAW_LINE;  Draw.Type = "Line"; }
   else if (StringStartsWith("dot",  sValue)) { draw.type = DRAW_ARROW; Draw.Type = "Dot";  }
   else                    return(catch("onInit(6)  Invalid input parameter Draw.Type = "+ DoubleQuoteStr(Draw.Type), ERR_INVALID_INPUT_PARAMETER));

   // Draw.LineWidth
   if (Draw.LineWidth < 1) return(catch("onInit(7)  Invalid input parameter Draw.LineWidth = "+ Draw.LineWidth, ERR_INVALID_INPUT_PARAMETER));
   if (Draw.LineWidth > 5) return(catch("onInit(8)  Invalid input parameter Draw.LineWidth = "+ Draw.LineWidth, ERR_INVALID_INPUT_PARAMETER));

   // Max.Values
   if (Max.Values < -1)    return(catch("onInit(9)  Invalid input parameter Max.Values = "+ Max.Values, ERR_INVALID_INPUT_PARAMETER));

   // Signals
   if (!Configure.Signal("MovingAverage", Signal.onTrendChange, signals))                                       return(last_error);
   if (signals) {
      if (!Configure.Signal.Sound(Signal.Sound,         signal.sound                                         )) return(last_error);
      if (!Configure.Signal.Mail (Signal.Mail.Receiver, signal.mail, signal.mail.sender, signal.mail.receiver)) return(last_error);
      if (!Configure.Signal.SMS  (Signal.SMS.Receiver,  signal.sms,                      signal.sms.receiver )) return(last_error);
      if (!signal.sound && !signal.mail && !signal.sms)
         signals = false;
      signal.info = "TrendChange="+ StringLeft(ifString(signal.sound, "Sound,", "") + ifString(signal.mail,  "Mail,",  "") + ifString(signal.sms, "SMS,", ""), -1);
   }


   // (2) setup buffer management
   IndicatorBuffers(6);
   SetIndexBuffer(MODE_MA,        bufferMA       );                     // all MA values:       invisible, displayed in "Data" window
   SetIndexBuffer(MODE_TREND,     bufferTrend    );                     // trend direction:     invisible
   SetIndexBuffer(MODE_UPTREND1,  bufferUpTrend1 );                     // uptrend values:      visible
   SetIndexBuffer(MODE_DOWNTREND, bufferDownTrend);                     // downtrend values:    visible, overlays uptrend values
   SetIndexBuffer(MODE_UPTREND2,  bufferUpTrend2 );                     // single-bar uptrends: visible, overlays downtrend values
   SetIndexBuffer(MODE_TMA_SMA,   tma.bufferSMA  );                     // intermediate buffer: invisible


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
   SetIndexLabel(MODE_TMA_SMA,   NULL);
   IndicatorDigits(SubPipDigits);


   // (4) drawing options and styles
   int startDraw = 0;
   if (Max.Values >= 0) startDraw = Bars - Max.Values;
   if (startDraw  <  0) startDraw = 0;
   SetIndexDrawBegin(MODE_UPTREND1,  startDraw);
   SetIndexDrawBegin(MODE_DOWNTREND, startDraw);
   SetIndexDrawBegin(MODE_UPTREND2,  startDraw);
   SetIndicatorStyles();


   // (5) initialize indicator calculations where applicable
   if (ma.periods > 1) {                                                // can be < 2 when switching to a too long timeframe
      if (ma.method == MODE_TMA) {
         tma.periods.1 = MA.Periods / 2;
         tma.periods.2 = MA.Periods - tma.periods.1 + 1;                // subperiods overlap by one bar: TMA(2) = SMA(1) + SMA(2)
      }
      else if (ma.method == MODE_ALMA) {
         @ALMA.CalculateWeights(alma.weights, ma.periods);
      }
   }
   return(catch("onInit(10)"));
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
   // check for finished buffer initialization
   if (!ArraySize(bufferMA))                                            // can happen on terminal start
      return(log("onTick(1)  size(bufferMA) = 0", SetLastError(ERS_TERMINAL_NOT_YET_READY)));

   // reset all buffers and delete garbage behind Max.Values before doing a full recalculation
   if (!ValidBars) {
      ArrayInitialize(bufferMA,        EMPTY_VALUE);
      ArrayInitialize(bufferTrend,               0);
      ArrayInitialize(bufferUpTrend1,  EMPTY_VALUE);
      ArrayInitialize(bufferDownTrend, EMPTY_VALUE);
      ArrayInitialize(bufferUpTrend2,  EMPTY_VALUE);
      ArrayInitialize(tma.bufferSMA,   EMPTY_VALUE);
      SetIndicatorStyles();                                             // fix for various terminal bugs
   }

   // synchronize buffers with a shifted offline chart (if applicable)
   if (ShiftedBars > 0) {
      ShiftIndicatorBuffer(bufferMA,        Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(bufferTrend,     Bars, ShiftedBars,           0);
      ShiftIndicatorBuffer(bufferUpTrend1,  Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(bufferDownTrend, Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(bufferUpTrend2,  Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(tma.bufferSMA,   Bars, ShiftedBars, EMPTY_VALUE);
   }

   if (ma.periods < 2)                                                  // abort when switching to a too long timeframe
      return(NO_ERROR);


   // (1) calculate start bar
   int changedBars = ChangedBars;
   if (Max.Values >= 0) /*&&*/ if (ChangedBars > Max.Values)
      changedBars = Max.Values;
   int startBar = Min(changedBars-1, Bars-ma.periods);
   if (startBar < 0) return(catch("onTick(2)", ERR_HISTORY_INSUFFICIENT));


   // (2) recalculate invalid bars
   if (ma.method == MODE_TMA) {
      // pre-calculate the TMA's intermediate SMA
      for (int bar=startBar; bar >= 0; bar--) {
         tma.bufferSMA[bar] = iMA(NULL, NULL, tma.periods.1, 0, MODE_SMA, ma.appliedPrice, bar);
      }
   }

   for (bar=startBar; bar >= 0; bar--) {
      if (ma.method == MODE_TMA) {
         // final moving average
         bufferMA[bar] = iMAOnArray(tma.bufferSMA, WHOLE_ARRAY, tma.periods.2, 0, MODE_SMA, bar);
      }
      else if (ma.method == MODE_ALMA) {
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
      message = ma.shortName +" turned up";
      log("onTrendChange(1)  "+ message);
      message = Symbol() +","+ PeriodDescription(Period()) +": "+ message;

      if (signal.sound) success &= _int(PlaySoundEx(signal.sound.trendChange_up));
      if (signal.mail)  success &= !SendEmail(signal.mail.sender, signal.mail.receiver, message, "");   // subject only (empty mail body)
      if (signal.sms)   success &= !SendSMS(signal.sms.receiver, message);
      return(success != 0);
   }

   if (trend == MODE_DOWNTREND) {
      message = ma.shortName +" turned down";
      log("onTrendChange(2)  "+ message);
      message = Symbol() +","+ PeriodDescription(Period()) +": "+ message;

      if (signal.sound) success &= _int(PlaySoundEx(signal.sound.trendChange_down));
      if (signal.mail)  success &= !SendEmail(signal.mail.sender, signal.mail.receiver, message, "");   // subject only (empty mail body)
      if (signal.sms)   success &= !SendSMS(signal.sms.receiver, message);
      return(success != 0);
   }

   return(!catch("onTrendChange(3)  invalid parameter trend = "+ trend, ERR_INVALID_PARAMETER));
}


/**
 * Set indicator styles. Workaround for various terminal bugs when setting styles or levels. Usually styles are applied in
 * init(). However after recompilation styles must be applied in start() to not get ignored.
 */
void SetIndicatorStyles() {
   int width = ifInt(draw.type==DRAW_ARROW, draw.arrowSize, Draw.LineWidth);

   SetIndexStyle(MODE_MA,        DRAW_NONE, EMPTY, EMPTY, CLR_NONE       );
   SetIndexStyle(MODE_TREND,     DRAW_NONE, EMPTY, EMPTY, CLR_NONE       );
   SetIndexStyle(MODE_UPTREND1,  draw.type, EMPTY, width, Color.UpTrend  ); SetIndexArrow(MODE_UPTREND1,  159);
   SetIndexStyle(MODE_DOWNTREND, draw.type, EMPTY, width, Color.DownTrend); SetIndexArrow(MODE_DOWNTREND, 159);
   SetIndexStyle(MODE_UPTREND2,  draw.type, EMPTY, width, Color.UpTrend  ); SetIndexArrow(MODE_UPTREND2,  159);
}


/**
 * Store input parameters in the chart for restauration after recompilation.
 *
 * @return bool - success status
 */
bool StoreInputParameters() {
   Chart.StoreInt   (__NAME__ +".input.MA.Periods",           MA.Periods           );
   Chart.StoreString(__NAME__ +".input.MA.Method",            MA.Method            );
   Chart.StoreString(__NAME__ +".input.MA.AppliedPrice",      MA.AppliedPrice      );
   Chart.StoreInt   (__NAME__ +".input.Color.UpTrend",        Color.UpTrend        );
   Chart.StoreInt   (__NAME__ +".input.Color.DownTrend",      Color.DownTrend      );
   Chart.StoreString(__NAME__ +".input.Draw.Type",            Draw.Type            );
   Chart.StoreInt   (__NAME__ +".input.Draw.LineWidth",       Draw.LineWidth       );
   Chart.StoreInt   (__NAME__ +".input.Max.Values",           Max.Values           );
   Chart.StoreString(__NAME__ +".input.Signal.onTrendChange", Signal.onTrendChange );
   Chart.StoreString(__NAME__ +".input.Signal.Sound",         Signal.Sound         );
   Chart.StoreString(__NAME__ +".input.Signal.Mail.Receiver", Signal.Mail.Receiver );
   Chart.StoreString(__NAME__ +".input.Signal.SMS.Receiver",  Signal.SMS.Receiver  );

   return(!catch("StoreInputParameters(1)"));
}


/**
 * Restore input parameters found in the chart after recompilation.
 *
 * @return bool - success status
 */
bool RestoreInputParameters() {
   string label = __NAME__ +".input.MA.Periods";
   if (ObjectFind(label) == 0) {
      string sValue = StringTrim(ObjectDescription(label));
      if (!StringIsDigit(sValue))   return(!catch("RestoreInputParameters(1)  illegal chart value "+ label +" = "+ DoubleQuoteStr(ObjectDescription(label)), ERR_INVALID_CONFIG_PARAMVALUE));
      ObjectDelete(label);
      MA.Periods = StrToInteger(sValue);                          // (int) string
   }

   label = __NAME__ +".input.MA.Method";
   if (ObjectFind(label) == 0) {
      sValue = ObjectDescription(label);
      ObjectDelete(label);
      MA.Method = sValue;                                         // string
   }

   label = __NAME__ +".input.MA.AppliedPrice";
   if (ObjectFind(label) == 0) {
      sValue = ObjectDescription(label);
      ObjectDelete(label);
      MA.AppliedPrice = sValue;                                   // string
   }

   label = __NAME__ +".input.Color.UpTrend";
   if (ObjectFind(label) == 0) {
      sValue = StringTrim(ObjectDescription(label));
      if (!StringIsInteger(sValue)) return(!catch("RestoreInputParameters(2)  illegal chart value "+ label +" = "+ DoubleQuoteStr(ObjectDescription(label)), ERR_INVALID_CONFIG_PARAMVALUE));
      int iValue = StrToInteger(sValue);
      if (iValue < CLR_NONE || iValue > C'255,255,255')
                                    return(!catch("RestoreInputParameters(3)  illegal chart value "+ label +" = "+ DoubleQuoteStr(ObjectDescription(label)) +" (0x"+ IntToHexStr(iValue) +")", ERR_INVALID_CONFIG_PARAMVALUE));
      ObjectDelete(label);
      Color.UpTrend = iValue;                                     // (color)(int) string
   }

   label = __NAME__ +".input.Color.DownTrend";
   if (ObjectFind(label) == 0) {
      sValue = StringTrim(ObjectDescription(label));
      if (!StringIsInteger(sValue)) return(!catch("RestoreInputParameters(4)  illegal chart value "+ label +" = "+ DoubleQuoteStr(ObjectDescription(label)), ERR_INVALID_CONFIG_PARAMVALUE));
      iValue = StrToInteger(sValue);
      if (iValue < CLR_NONE || iValue > C'255,255,255')
                                    return(!catch("RestoreInputParameters(5)  illegal chart value "+ label +" = "+ DoubleQuoteStr(ObjectDescription(label)) +" (0x"+ IntToHexStr(iValue) +")", ERR_INVALID_CONFIG_PARAMVALUE));
      ObjectDelete(label);
      Color.DownTrend = iValue;                                   // (color)(int) string
   }

   label = __NAME__ +".input.Draw.Type";
   if (ObjectFind(label) == 0) {
      sValue = ObjectDescription(label);
      ObjectDelete(label);
      Draw.Type = sValue;                                         // string
   }

   label = __NAME__ +".input.Draw.LineWidth";
   if (ObjectFind(label) == 0) {
      sValue = StringTrim(ObjectDescription(label));
      if (!StringIsDigit(sValue))   return(!catch("RestoreInputParameters(6)  illegal chart value "+ label +" = "+ DoubleQuoteStr(ObjectDescription(label)), ERR_INVALID_CONFIG_PARAMVALUE));
      ObjectDelete(label);
      Draw.LineWidth = StrToInteger(sValue);                      // (int) string
   }

   label = __NAME__ +".input.Max.Values";
   if (ObjectFind(label) == 0) {
      sValue = StringTrim(ObjectDescription(label));
      if (!StringIsInteger(sValue)) return(!catch("RestoreInputParameters(7)  illegal chart value "+ label +" = "+ DoubleQuoteStr(ObjectDescription(label)), ERR_INVALID_CONFIG_PARAMVALUE));
      ObjectDelete(label);
      Max.Values = StrToInteger(sValue);                          // (int) string
   }

   label = __NAME__ +".input.Signal.onTrendChange";
   if (ObjectFind(label) == 0) {
      sValue = ObjectDescription(label);
      ObjectDelete(label);
      Signal.onTrendChange = sValue;                              // string
   }

   label = __NAME__ +".input.Signal.Sound";
   if (ObjectFind(label) == 0) {
      sValue = ObjectDescription(label);
      ObjectDelete(label);
      Signal.Sound = sValue;                                      // string
   }

   label = __NAME__ +".input.Signal.Mail.Receiver";
   if (ObjectFind(label) == 0) {
      sValue = ObjectDescription(label);
      ObjectDelete(label);
      Signal.Mail.Receiver = sValue;                              // string
   }

   label = __NAME__ +".input.Signal.SMS.Receiver";
   if (ObjectFind(label) == 0) {
      sValue = ObjectDescription(label);
      ObjectDelete(label);
      Signal.SMS.Receiver = sValue;                               // string
   }

   return(!catch("RestoreInputParameters(8)"));
}


/**
 * Return a string representation of the input parameters. Used when logging iCustom() calls.
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("input: ",

                            "MA.Periods=",           MA.Periods,                           "; ",
                            "MA.Method=",            DoubleQuoteStr(MA.Method),            "; ",
                            "MA.AppliedPrice=",      DoubleQuoteStr(MA.AppliedPrice),      "; ",

                            "Color.UpTrend=",        ColorToStr(Color.UpTrend),            "; ",
                            "Color.DownTrend=",      ColorToStr(Color.DownTrend),          "; ",
                            "Draw.Type=",            DoubleQuoteStr(Draw.Type),            "; ",
                            "Draw.LineWidth=",       Draw.LineWidth,                       "; ",

                            "Max.Values=",           Max.Values,                           "; ",

                            "Signal.onTrendChange=", DoubleQuoteStr(Signal.onTrendChange), "; ",
                            "Signal.Sound=",         DoubleQuoteStr(Signal.Sound),         "; ",
                            "Signal.Mail.Receiver=", DoubleQuoteStr(Signal.Mail.Receiver), "; ",
                            "Signal.SMS.Receiver=",  DoubleQuoteStr(Signal.SMS.Receiver),  "; ")
   );
}
