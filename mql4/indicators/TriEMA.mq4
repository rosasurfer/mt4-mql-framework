/**
 * Triple Smoothed Exponential Moving Average
 *
 *
 * A three times applied exponential moving average (not to be confused with the TEMA moving average). This indicator is the
 * base of the Trix indicator.
 *
 * Indicator buffers for iCustom():
 *  • MovingAverage.MODE_MA:    MA values
 *  • MovingAverage.MODE_TREND: trend direction and length
 *    - trend direction:        positive values denote an uptrend (+1...+n), negative values a downtrend (-1...-n)
 *    - trend length:           the absolute direction value is the length of the trend in bars since the last reversal
 */
#include <stddefines.mqh>
int   __InitFlags[];
int __DeinitFlags[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern int    MA.Periods           = 38;
extern string MA.AppliedPrice      = "Open | High | Low | Close* | Median | Typical | Weighted";

extern color  Color.UpTrend        = Blue;
extern color  Color.DownTrend      = Red;
extern string Draw.Type            = "Line* | Dot";
extern int    Draw.Width           = 3;
extern int    Max.Bars             = 10000;              // max. values to calculate (-1: all available)
extern string __a___________________________;

extern string Signal.onTrendChange = "on | off | auto*";
extern string Signal.Sound         = "on | off | auto*";
extern string Signal.Mail          = "on | off | auto*";
extern string Signal.SMS           = "on | off | auto*";

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <rsfLibs.mqh>
#include <functions/ConfigureSignals.mqh>
#include <functions/ConfigureSignalsByMail.mqh>
#include <functions/ConfigureSignalsBySMS.mqh>
#include <functions/ConfigureSignalsBySound.mqh>
#include <functions/IsBarOpen.mqh>
#include <functions/@Trend.mqh>

#define MODE_MA               MovingAverage.MODE_MA      // indicator buffer ids
#define MODE_TREND            MovingAverage.MODE_TREND
#define MODE_UPTREND          2
#define MODE_DOWNTREND        3
#define MODE_UPTREND1         MODE_UPTREND
#define MODE_UPTREND2         4                          // MODE_UPTREND2 holds single-bar trend reversal which otherwise go unnoticed
#define MODE_EMA_1            5
#define MODE_EMA_2            6
#define MODE_EMA_3            MODE_MA

#property indicator_chart_window
#property indicator_buffers   5                          // buffers visible to the user
int       terminal_buffers  = 7;                         // buffers managed by the terminal

#property indicator_color1    CLR_NONE
#property indicator_color2    CLR_NONE
#property indicator_color3    CLR_NONE
#property indicator_color4    CLR_NONE
#property indicator_color5    CLR_NONE

double firstEma [];                                      // first intermediate EMA buffer:  invisible
double secondEma[];                                      // second intermediate EMA buffer: invisible
double thirdEma [];                                      // TriEMA main value:              invisible, displayed in legend and "Data" window
double trend    [];                                      // trend direction:                invisible, displayed in "Data" window
double uptrend1 [];                                      // uptrend values:                 visible
double downtrend[];                                      // downtrend values:               visible
double uptrend2 [];                                      // single-bar uptrends:            visible

int    maAppliedPrice;
int    maxValues;
int    drawType;

string indicatorName = "";
string legendLabel   = "";

bool   signals;
bool   signal.sound;
string signal.sound.trendChange_up   = "Signal-Up.wav";
string signal.sound.trendChange_down = "Signal-Down.wav";
bool   signal.mail;
string signal.mail.sender   = "";
string signal.mail.receiver = "";
bool   signal.sms;
string signal.sms.receiver = "";
string signal.info = "";                                 // additional chart legend info


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   if (ProgramInitReason() == IR_RECOMPILE) {
      if (!RestoreInputParameters()) return(last_error);
   }

   // validate inputs
   // MA.Periods
   if (MA.Periods < 1) return(catch("onInit(1)  invalid input parameter MA.Periods: "+ MA.Periods, ERR_INVALID_INPUT_PARAMETER));

   // MA.AppliedPrice
   string sValues[], sValue = StrToLower(MA.AppliedPrice);
   if (Explode(sValue, "*", sValues, 2) > 1) {
      int size = Explode(sValues[0], "|", sValues, NULL);
      sValue = sValues[size-1];
   }
   sValue = StrTrim(sValue);
   if (sValue == "") sValue = "close";                   // default price type
   if      (StrStartsWith("open",     sValue)) maAppliedPrice = PRICE_OPEN;
   else if (StrStartsWith("high",     sValue)) maAppliedPrice = PRICE_HIGH;
   else if (StrStartsWith("low",      sValue)) maAppliedPrice = PRICE_LOW;
   else if (StrStartsWith("close",    sValue)) maAppliedPrice = PRICE_CLOSE;
   else if (StrStartsWith("median",   sValue)) maAppliedPrice = PRICE_MEDIAN;
   else if (StrStartsWith("typical",  sValue)) maAppliedPrice = PRICE_TYPICAL;
   else if (StrStartsWith("weighted", sValue)) maAppliedPrice = PRICE_WEIGHTED;
   else                return(catch("onInit(2)  invalid input parameter MA.AppliedPrice: "+ DoubleQuoteStr(MA.AppliedPrice), ERR_INVALID_INPUT_PARAMETER));
   MA.AppliedPrice = PriceTypeDescription(maAppliedPrice);

   // colors: after deserialization the terminal might turn CLR_NONE (0xFFFFFFFF) into Black (0xFF000000)
   if (Color.UpTrend   == 0xFF000000) Color.UpTrend   = CLR_NONE;
   if (Color.DownTrend == 0xFF000000) Color.DownTrend = CLR_NONE;

   // Draw.Type
   sValue = StrToLower(Draw.Type);
   if (Explode(sValue, "*", sValues, 2) > 1) {
      size = Explode(sValues[0], "|", sValues, NULL);
      sValue = sValues[size-1];
   }
   sValue = StrTrim(sValue);
   if      (StrStartsWith("line", sValue)) { drawType = DRAW_LINE;  Draw.Type = "Line"; }
   else if (StrStartsWith("dot",  sValue)) { drawType = DRAW_ARROW; Draw.Type = "Dot";  }
   else                return(catch("onInit(3)  invalid input parameter Draw.Type: "+ DoubleQuoteStr(Draw.Type), ERR_INVALID_INPUT_PARAMETER));

   // Draw.Width
   if (Draw.Width < 0) return(catch("onInit(4)  invalid input parameter Draw.Width: "+ Draw.Width, ERR_INVALID_INPUT_PARAMETER));
   if (Draw.Width > 5) return(catch("onInit(5)  invalid input parameter Draw.Width: "+ Draw.Width, ERR_INVALID_INPUT_PARAMETER));

   // Max.Bars
   if (Max.Bars < -1)  return(catch("onInit(6)  invalid input parameter Max.Bars: "+ Max.Bars, ERR_INVALID_INPUT_PARAMETER));
   maxValues = ifInt(Max.Bars==-1, INT_MAX, Max.Bars);

   // signaling
   if (!ConfigureSignals(ProgramName(), Signal.onTrendChange, signals))                                  return(last_error);
   if (signals) {
      if (!ConfigureSignalsBySound(Signal.Sound, signal.sound                                         )) return(last_error);
      if (!ConfigureSignalsByMail (Signal.Mail,  signal.mail, signal.mail.sender, signal.mail.receiver)) return(last_error);
      if (!ConfigureSignalsBySMS  (Signal.SMS,   signal.sms,                      signal.sms.receiver )) return(last_error);
      if (signal.sound || signal.mail || signal.sms) {
         signal.info = "TrendChange="+ StrLeft(ifString(signal.sound, "Sound+", "") + ifString(signal.mail, "Mail+", "") + ifString(signal.sms, "SMS+", ""), -1);
      }
      else signals = false;
   }

   // buffer management
   SetIndexBuffer(MODE_EMA_1,     firstEma );            // first intermediate EMA buffer:  invisible
   SetIndexBuffer(MODE_EMA_2,     secondEma);            // second intermediate EMA buffer: invisible
   SetIndexBuffer(MODE_EMA_3,     thirdEma );            // TriEMA main value:              invisible, displayed in legend and "Data" window
   SetIndexBuffer(MODE_TREND,     trend    );            // trend direction:                invisible, displayed in "Data" window
   SetIndexBuffer(MODE_UPTREND1,  uptrend1 );            // uptrend values:                 visible
   SetIndexBuffer(MODE_UPTREND2,  uptrend2 );            // downtrend values:               visible
   SetIndexBuffer(MODE_DOWNTREND, downtrend);            // single-bar uptrends:            visible

   // chart legend
   if (!IsSuperContext()) {
      legendLabel = CreateLegendLabel();
      RegisterObject(legendLabel);
   }

   // names, labels and display options
   string sAppliedPrice = ifString(maAppliedPrice==PRICE_CLOSE, "", ", "+ PriceTypeDescription(maAppliedPrice));
   indicatorName = ProgramName() +"("+ MA.Periods + sAppliedPrice +")";
   string shortName = ProgramName() +"("+ MA.Periods +")";
   IndicatorShortName(shortName);                        // chart tooltips and context menu
   SetIndexLabel(MODE_EMA_1,     NULL);
   SetIndexLabel(MODE_EMA_2,     NULL);
   SetIndexLabel(MODE_EMA_3,     shortName);             // chart tooltips and "Data" window
   SetIndexLabel(MODE_TREND,     shortName +" trend");
   SetIndexLabel(MODE_UPTREND1,  NULL);
   SetIndexLabel(MODE_UPTREND2,  NULL);
   SetIndexLabel(MODE_DOWNTREND, NULL);
   IndicatorDigits(Digits);
   SetIndicatorOptions();

   return(catch("onInit(7)"));
}


/**
 * Deinitialization
 *
 * @return int - error status
 */
int onDeinit() {
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
   return(catch("onDeinitRecompile(1)"));
}


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   // on the first tick after terminal start buffers may not yet be initialized (spurious issue)
   if (!ArraySize(firstEma)) return(logInfo("onTick(1)  size(firstEma) = 0", SetLastError(ERS_TERMINAL_NOT_YET_READY)));

   // reset buffers before performing a full recalculation
   if (!ValidBars) {
      ArrayInitialize(firstEma,  EMPTY_VALUE);
      ArrayInitialize(secondEma, EMPTY_VALUE);
      ArrayInitialize(thirdEma,  EMPTY_VALUE);
      ArrayInitialize(trend,               0);
      ArrayInitialize(uptrend1,  EMPTY_VALUE);
      ArrayInitialize(uptrend2,  EMPTY_VALUE);
      ArrayInitialize(downtrend, EMPTY_VALUE);
      SetIndicatorOptions();
   }

   // synchronize buffers with a shifted offline chart
   if (ShiftedBars > 0) {
      ShiftIndicatorBuffer(firstEma,  Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(secondEma, Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(thirdEma,  Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(trend,     Bars, ShiftedBars,           0);
      ShiftIndicatorBuffer(uptrend1,  Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(uptrend2,  Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(downtrend, Bars, ShiftedBars, EMPTY_VALUE);
   }

   // calculate start bar
   int i, bars  = Min(ChangedBars, maxValues);                                              // Because EMA(EMA(EMA)) is used in the calculation TriEMA
   int startbar = Min(bars-1, Bars - (3*MA.Periods-2));                                     // needs 3*<period>-2 samples to start producing values,
   if (startbar < 0) return(logInfo("onTick(2)  Tick="+ Tick, ERR_HISTORY_INSUFFICIENT));   // in contrast to <period> samples needed by a regular EMA.

   // recalculate changed bars
   for (i=ChangedBars-1; i >= 0; i--)   firstEma [i] =        iMA(NULL,      NULL,        MA.Periods, 0, MODE_EMA, maAppliedPrice, i);
   for (i=ChangedBars-1; i >= 0; i--)   secondEma[i] = iMAOnArray(firstEma,  WHOLE_ARRAY, MA.Periods, 0, MODE_EMA,                 i);
   for (i=startbar;      i >= 0; i--) { thirdEma [i] = iMAOnArray(secondEma, WHOLE_ARRAY, MA.Periods, 0, MODE_EMA,                 i);
      @Trend.UpdateDirection(thirdEma, i, trend, uptrend1, downtrend, uptrend2, true, true, drawType, Digits);
   }

   if (!IsSuperContext()) {
       @Trend.UpdateLegend(legendLabel, indicatorName, signal.info, Color.UpTrend, Color.DownTrend, thirdEma[0], Digits, trend[0], Time[0]);

      // signal trend changes
      if (signals) /*&&*/ if (IsBarOpen()) {
         int iTrend = Round(trend[1]);
         if      (iTrend ==  1) onTrendChange(MODE_UPTREND);
         else if (iTrend == -1) onTrendChange(MODE_DOWNTREND);
      }
   }
   return(catch("onTick(3)"));
}


/**
 * Event handler for trend changes.
 *
 * @param  int trend - direction
 *
 * @return bool - success status
 */
bool onTrendChange(int trend) {
   string message="", accountTime="("+ TimeToStr(TimeLocal(), TIME_MINUTES|TIME_SECONDS) +", "+ GetAccountAlias() +")";
   int error = 0;

   if (trend == MODE_UPTREND) {
      message = indicatorName +" turned up (market: "+ NumberToStr((Bid+Ask)/2, PriceFormat) +")";
      if (IsLogInfo()) logInfo("onTrendChange(1)  "+ message);
      message = Symbol() +","+ PeriodDescription() +": "+ message;

      if (signal.sound) error |= !PlaySoundEx(signal.sound.trendChange_up);
      if (signal.mail)  error |= !SendEmail(signal.mail.sender, signal.mail.receiver, message, message +NL+ accountTime);
      if (signal.sms)   error |= !SendSMS(signal.sms.receiver, message +NL+ accountTime);
      return(!error);
   }

   if (trend == MODE_DOWNTREND) {
      message = indicatorName +" turned down (market: "+ NumberToStr((Bid+Ask)/2, PriceFormat) +")";
      if (IsLogInfo()) logInfo("onTrendChange(2)  "+ message);
      message = Symbol() +","+ PeriodDescription() +": "+ message;

      if (signal.sound) error |= !PlaySoundEx(signal.sound.trendChange_down);
      if (signal.mail)  error |= !SendEmail(signal.mail.sender, signal.mail.receiver, message, message +NL+ accountTime);
      if (signal.sms)   error |= !SendSMS(signal.sms.receiver, message +NL+ accountTime);
      return(!error);
   }

   return(!catch("onTrendChange(3)  invalid parameter trend: "+ trend, ERR_INVALID_PARAMETER));
}


/**
 * Workaround for various terminal bugs when setting indicator options. Usually options are set in init(). However after
 * recompilation options must be set in start() to not be ignored.
 */
void SetIndicatorOptions() {
   IndicatorBuffers(terminal_buffers);

   int draw_type = ifInt(Draw.Width, drawType, DRAW_NONE);

   SetIndexStyle(MODE_MA,        DRAW_NONE, EMPTY, EMPTY,      CLR_NONE       );
   SetIndexStyle(MODE_TREND,     DRAW_NONE, EMPTY, EMPTY,      CLR_NONE       );
   SetIndexStyle(MODE_UPTREND1,  draw_type, EMPTY, Draw.Width, Color.UpTrend  ); SetIndexArrow(MODE_UPTREND1,  158);
   SetIndexStyle(MODE_DOWNTREND, draw_type, EMPTY, Draw.Width, Color.DownTrend); SetIndexArrow(MODE_DOWNTREND, 158);
   SetIndexStyle(MODE_UPTREND2,  draw_type, EMPTY, Draw.Width, Color.UpTrend  ); SetIndexArrow(MODE_UPTREND2,  158);
}


/**
 * Store input parameters in the chart before recompilation.
 *
 * @return bool - success status
 */
bool StoreInputParameters() {
   string name = ProgramName();
   Chart.StoreInt   (name +".input.MA.Periods",           MA.Periods          );
   Chart.StoreString(name +".input.MA.AppliedPrice",      MA.AppliedPrice     );
   Chart.StoreColor (name +".input.Color.UpTrend",        Color.UpTrend       );
   Chart.StoreColor (name +".input.Color.DownTrend",      Color.DownTrend     );
   Chart.StoreString(name +".input.Draw.Type",            Draw.Type           );
   Chart.StoreInt   (name +".input.Draw.Width",           Draw.Width          );
   Chart.StoreInt   (name +".input.Max.Bars",             Max.Bars            );
   Chart.StoreString(name +".input.Signal.onTrendChange", Signal.onTrendChange);
   Chart.StoreString(name +".input.Signal.Sound",         Signal.Sound        );
   Chart.StoreString(name +".input.Signal.Mail",          Signal.Mail         );
   Chart.StoreString(name +".input.Signal.SMS",           Signal.SMS          );
   return(!catch("StoreInputParameters(1)"));
}


/**
 * Restore input parameters found in the chart after recompilation.
 *
 * @return bool - success status
 */
bool RestoreInputParameters() {
   string name = ProgramName();
   Chart.RestoreInt   (name +".input.MA.Periods",           MA.Periods          );
   Chart.RestoreString(name +".input.MA.AppliedPrice",      MA.AppliedPrice     );
   Chart.RestoreColor (name +".input.Color.UpTrend",        Color.UpTrend       );
   Chart.RestoreColor (name +".input.Color.DownTrend",      Color.DownTrend     );
   Chart.RestoreString(name +".input.Draw.Type",            Draw.Type           );
   Chart.RestoreInt   (name +".input.Draw.Width",           Draw.Width          );
   Chart.RestoreInt   (name +".input.Max.Bars",             Max.Bars            );
   Chart.RestoreString(name +".input.Signal.onTrendChange", Signal.onTrendChange);
   Chart.RestoreString(name +".input.Signal.Sound",         Signal.Sound        );
   Chart.RestoreString(name +".input.Signal.Mail",          Signal.Mail         );
   Chart.RestoreString(name +".input.Signal.SMS",           Signal.SMS          );
   return(!catch("RestoreInputParameters(1)"));
}


/**
 * Return a string representation of the input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("MA.Periods=",           MA.Periods,                           ";", NL,
                            "MA.AppliedPrice=",      DoubleQuoteStr(MA.AppliedPrice),      ";", NL,
                            "Color.UpTrend=",        ColorToStr(Color.UpTrend),            ";", NL,
                            "Color.DownTrend=",      ColorToStr(Color.DownTrend),          ";", NL,
                            "Draw.Type=",            DoubleQuoteStr(Draw.Type),            ";", NL,
                            "Draw.Width=",           Draw.Width,                           ";", NL,
                            "Max.Bars=",             Max.Bars,                             ";", NL,
                            "Signal.onTrendChange=", DoubleQuoteStr(Signal.onTrendChange), ";", NL,
                            "Signal.Sound=",         DoubleQuoteStr(Signal.Sound),         ";", NL,
                            "Signal.Mail=",          DoubleQuoteStr(Signal.Mail),          ";", NL,
                            "Signal.SMS=",           DoubleQuoteStr(Signal.SMS),           ";")
   );
}
