/**
 * HalfTrend SR - a continuous support/resistance line defined by a trading range channel
 *
 * Similar to the SuperTrend indicator but uses a slightly different channel calculation and trend logic.
 *
 * Indicator buffers for iCustom():
 *  • HalfTrend.MODE_MAIN:  main SR values
 *  • HalfTrend.MODE_TREND: trend direction and length
 *    - trend direction:    positive values denote an uptrend (+1...+n), negative values a downtrend (-1...-n)
 *    - trend length:       the absolute direction value is the length of the trend in bars since the last reversal
 */
#include <stddefines.mqh>
int   __InitFlags[];
int __DeinitFlags[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern int    Periods              = 3;

extern color  Color.UpTrend        = Blue;
extern color  Color.DownTrend      = Red;
extern color  Color.Channel        = CLR_NONE;
extern string Draw.Type            = "Line* | Dot";
extern int    Draw.Width           = 3;
extern int    Max.Bars             = 10000;              // max. values to calculate (-1: all available)
extern string __________________________;

extern string Signal.onTrendChange = "on | off | auto*";
extern string Signal.Sound         = "on | off | auto*";
extern string Signal.Mail.Receiver = "on | off | auto* | {email-address}";
extern string Signal.SMS.Receiver  = "on | off | auto* | {phone-number}";

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <rsfLibs.mqh>
#include <functions/@Trend.mqh>
#include <functions/BarOpenEvent.mqh>
#include <functions/ConfigureSignal.mqh>
#include <functions/ConfigureSignalMail.mqh>
#include <functions/ConfigureSignalSMS.mqh>
#include <functions/ConfigureSignalSound.mqh>

#define MODE_MAIN             HalfTrend.MODE_MAIN        // indicator buffer ids
#define MODE_TREND            HalfTrend.MODE_TREND
#define MODE_UPTREND          2
#define MODE_DOWNTREND        3
#define MODE_UPPER_BAND       4
#define MODE_LOWER_BAND       5

#property indicator_chart_window
#property indicator_buffers   6

#property indicator_color1    CLR_NONE
#property indicator_color2    CLR_NONE
#property indicator_color3    CLR_NONE
#property indicator_color4    CLR_NONE
#property indicator_color5    CLR_NONE
#property indicator_color6    CLR_NONE

double main     [];                                      // all SR values:      invisible, displayed in legend and "Data" window
double trend    [];                                      // trend direction:    invisible, displayed in "Data" window
double upLine   [];                                      // support line:       visible
double downLine [];                                      // resistance line:    visible
double upperBand[];                                      // upper channel band: visible
double lowerBand[];                                      // lower channel band: visible

int    maxValues;
int    drawType;

string indicatorName;
string chartLegendLabel;

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
   // Periods
   if (Periods < 1)    return(catch("onInit(1)  Invalid input parameter Periods = "+ Periods, ERR_INVALID_INPUT_PARAMETER));

   // colors: after deserialization the terminal might turn CLR_NONE (0xFFFFFFFF) into Black (0xFF000000)
   if (Color.UpTrend   == 0xFF000000) Color.UpTrend   = CLR_NONE;
   if (Color.DownTrend == 0xFF000000) Color.DownTrend = CLR_NONE;
   if (Color.Channel   == 0xFF000000) Color.Channel   = CLR_NONE;

   // Draw.Type
   string sValues[], sValue = StrToLower(Draw.Type);
   if (Explode(sValue, "*", sValues, 2) > 1) {
      int size = Explode(sValues[0], "|", sValues, NULL);
      sValue = sValues[size-1];
   }
   sValue = StrTrim(sValue);
   if      (StrStartsWith("line", sValue)) { drawType = DRAW_LINE;  Draw.Type = "Line"; }
   else if (StrStartsWith("dot",  sValue)) { drawType = DRAW_ARROW; Draw.Type = "Dot";  }
   else                return(catch("onInit(2)  Invalid input parameter Draw.Type = "+ DoubleQuoteStr(Draw.Type), ERR_INVALID_INPUT_PARAMETER));

   // Draw.Width
   if (Draw.Width < 0) return(catch("onInit(3)  Invalid input parameter Draw.Width = "+ Draw.Width, ERR_INVALID_INPUT_PARAMETER));
   if (Draw.Width > 5) return(catch("onInit(4)  Invalid input parameter Draw.Width = "+ Draw.Width, ERR_INVALID_INPUT_PARAMETER));

   // Max.Bars
   if (Max.Bars < -1)  return(catch("onInit(5)  Invalid input parameter Max.Bars = "+ Max.Bars, ERR_INVALID_INPUT_PARAMETER));
   maxValues = ifInt(Max.Bars==-1, INT_MAX, Max.Bars);

   // signals
   if (!ConfigureSignal(ProgramName(), Signal.onTrendChange, signals))                                        return(last_error);
   if (signals) {
      if (!ConfigureSignalSound(Signal.Sound,         signal.sound                                         )) return(last_error);
      if (!ConfigureSignalMail (Signal.Mail.Receiver, signal.mail, signal.mail.sender, signal.mail.receiver)) return(last_error);
      if (!ConfigureSignalSMS  (Signal.SMS.Receiver,  signal.sms,                      signal.sms.receiver )) return(last_error);
      if (signal.sound || signal.mail || signal.sms) {
         signal.info = "TrendChange="+ StrLeft(ifString(signal.sound, "Sound+", "") + ifString(signal.mail, "Mail+", "") + ifString(signal.sms, "SMS+", ""), -1);
      }
      else signals = false;
   }

   // buffer management
   SetIndexBuffer(MODE_MAIN,       main     );           // all SR values:      invisible, displayed in legend and "Data" window
   SetIndexBuffer(MODE_TREND,      trend    );           // trend direction:    invisible, displayed in "Data" window
   SetIndexBuffer(MODE_UPTREND,    upLine   );           // support line:       visible
   SetIndexBuffer(MODE_DOWNTREND,  downLine );           // resistance line:    visible
   SetIndexBuffer(MODE_UPPER_BAND, upperBand);           // upper channel band: visible
   SetIndexBuffer(MODE_LOWER_BAND, lowerBand);           // lower channel band: visible

   // chart legend
   if (!IsSuperContext()) {
      chartLegendLabel = CreateLegendLabel();
      RegisterObject(chartLegendLabel);
   }

   // names, labels and display options
   indicatorName = ProgramName() +"("+ Periods +")";
   IndicatorShortName(indicatorName);                    // chart tooltips and context menu
   SetIndexLabel(MODE_MAIN,      indicatorName);         // chart tooltips and "Data" window
   SetIndexLabel(MODE_TREND,     indicatorName +" trend");
   SetIndexLabel(MODE_UPTREND,   NULL);
   SetIndexLabel(MODE_DOWNTREND, NULL);
   IndicatorDigits(Digits);
   SetIndicatorOptions();

   return(catch("onInit(6)"));
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
   if (!ArraySize(main)) return(logInfo("onTick(1)  size(main) = 0", SetLastError(ERS_TERMINAL_NOT_YET_READY)));

   // reset all buffers before doing a full recalculation
   if (!UnchangedBars) {
      ArrayInitialize(main,      EMPTY_VALUE);
      ArrayInitialize(trend,               0);
      ArrayInitialize(upLine,    EMPTY_VALUE);
      ArrayInitialize(downLine,  EMPTY_VALUE);
      ArrayInitialize(upperBand, EMPTY_VALUE);
      ArrayInitialize(lowerBand, EMPTY_VALUE);
      SetIndicatorOptions();
   }

   // synchronize buffers with a shifted offline chart
   if (ShiftedBars > 0) {
      ShiftIndicatorBuffer(main,      Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(trend,     Bars, ShiftedBars,           0);
      ShiftIndicatorBuffer(upLine,    Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(downLine,  Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(upperBand, Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(lowerBand, Bars, ShiftedBars, EMPTY_VALUE);
   }

   // calculate start bar
   int bars     = Min(ChangedBars, maxValues);
   int startBar = Min(bars-1, Bars-Periods);
   if (startBar < 0) return(logInfo("onTick(2)  Tick="+ Tick, ERR_HISTORY_INSUFFICIENT));

   // recalculate changed bars
   for (int i=startBar; i >= 0; i--) {
      upperBand[i] = iMA(NULL, NULL, Periods, 0, MODE_SMA, PRICE_HIGH, i);
      lowerBand[i] = iMA(NULL, NULL, Periods, 0, MODE_SMA, PRICE_LOW,  i);

      double currentHigh = iHigh(NULL, NULL, iHighest(NULL, NULL, MODE_HIGH, Periods, i));
      double currentLow  = iLow (NULL, NULL, iLowest (NULL, NULL, MODE_LOW,  Periods, i));

      // update trend direction and main SR values
      if (trend[i+1] > 0) {
         main[i] = MathMax(main[i+1], currentLow);
         if (upperBand[i] < main[i] && Close[i] < Low[i+1]) {
            trend[i] = -1;
            main [i] = MathMin(main[i+1], currentHigh);
         }
         else trend[i] = trend[i+1] + 1;
      }
      else if (trend[i+1] < 0) {
         main[i] = MathMin(main[i+1], currentHigh);
         if (lowerBand[i] > main[i] && Close[i] > High[i+1]) {
            trend[i] = 1;
            main [i] = MathMax(main[i+1], currentLow);
         }
         else trend[i] = trend[i+1] - 1;
      }
      else {
         // initialize the first, left-most value
         if (Close[i] > Close[i+1]) {
            trend[i] = 1;
            main [i] = currentLow;
         }
         else {
            trend[i] = -1;
            main [i] = currentHigh;
         }
      }

      // update SR sections
      if (trend[i] > 0) {
         upLine  [i] = main[i];
         downLine[i] = EMPTY_VALUE;
         if (drawType == DRAW_LINE) {                       // make sure reversals become visible
            upLine[i+1] = main[i+1];
            if (trend[i+1] > 0)
               downLine[i+1] = EMPTY_VALUE;
         }
      }
      else /*(trend[i] < 0)*/{
         upLine  [i] = EMPTY_VALUE;
         downLine[i] = main[i];
         if (drawType == DRAW_LINE) {                       // make sure reversals become visible
            if (trend[i+1] < 0)
               upLine[i+1] = EMPTY_VALUE;
            downLine[i+1] = main[i+1];
         }
      }
   }

   if (!IsSuperContext()) {
      @Trend.UpdateLegend(chartLegendLabel, indicatorName, signal.info, Color.UpTrend, Color.DownTrend, main[0], Digits, trend[0], Time[0]);

      // signal trend changes
      if (signals) /*&&*/ if (IsBarOpenEvent()) {
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
      message = Symbol() +","+ PeriodDescription(Period()) +": "+ message;

      if (signal.sound) error |= !PlaySoundEx(signal.sound.trendChange_up);
      if (signal.mail)  error |= !SendEmail(signal.mail.sender, signal.mail.receiver, message, message +NL+ accountTime);
      if (signal.sms)   error |= !SendSMS(signal.sms.receiver, message +NL+ accountTime);
      return(!error);
   }

   if (trend == MODE_DOWNTREND) {
      message = indicatorName +" turned down (market: "+ NumberToStr((Bid+Ask)/2, PriceFormat) +")";
      if (IsLogInfo()) logInfo("onTrendChange(2)  "+ message);
      message = Symbol() +","+ PeriodDescription(Period()) +": "+ message;

      if (signal.sound) error |= !PlaySoundEx(signal.sound.trendChange_down);
      if (signal.mail)  error |= !SendEmail(signal.mail.sender, signal.mail.receiver, message, message +NL+ accountTime);
      if (signal.sms)   error |= !SendSMS(signal.sms.receiver, message +NL+ accountTime);
      return(!error);
   }

   return(!catch("onTrendChange(3)  invalid parameter trend = "+ trend, ERR_INVALID_PARAMETER));
}


/**
 * Workaround for various terminal bugs when setting indicator options. Usually options are set in init(). However after
 * recompilation options must be set in start() to not be ignored.
 */
void SetIndicatorOptions() {
   int draw_type = ifInt(Draw.Width, drawType, DRAW_NONE);

   SetIndexStyle(MODE_MAIN,       DRAW_NONE, EMPTY, EMPTY,      CLR_NONE       );
   SetIndexStyle(MODE_TREND,      DRAW_NONE, EMPTY, EMPTY,      CLR_NONE       );
   SetIndexStyle(MODE_UPTREND,    draw_type, EMPTY, Draw.Width, Color.UpTrend  ); SetIndexArrow(MODE_UPTREND,   158);
   SetIndexStyle(MODE_DOWNTREND,  draw_type, EMPTY, Draw.Width, Color.DownTrend); SetIndexArrow(MODE_DOWNTREND, 158);
   SetIndexStyle(MODE_UPPER_BAND, DRAW_LINE, EMPTY, EMPTY,      Color.Channel  );
   SetIndexStyle(MODE_LOWER_BAND, DRAW_LINE, EMPTY, EMPTY,      Color.Channel  );

   if (Color.Channel == CLR_NONE) {
      SetIndexLabel(MODE_UPPER_BAND, NULL);
      SetIndexLabel(MODE_LOWER_BAND, NULL);
   }
   else {
      SetIndexLabel(MODE_UPPER_BAND, ProgramName() +" upper band");
      SetIndexLabel(MODE_LOWER_BAND, ProgramName() +" lower band");
   }
}


/**
 * Store input parameters in the chart before recompilation.
 *
 * @return bool - success status
 */
bool StoreInputParameters() {
   string name = ProgramName();
   Chart.StoreInt   (name +".input.Periods",              Periods             );
   Chart.StoreColor (name +".input.Color.UpTrend",        Color.UpTrend       );
   Chart.StoreColor (name +".input.Color.DownTrend",      Color.DownTrend     );
   Chart.StoreColor (name +".input.Color.Channel",        Color.Channel       );
   Chart.StoreString(name +".input.Draw.Type",            Draw.Type           );
   Chart.StoreInt   (name +".input.Draw.Width",           Draw.Width          );
   Chart.StoreInt   (name +".input.Max.Bars",             Max.Bars            );
   Chart.StoreString(name +".input.Signal.onTrendChange", Signal.onTrendChange);
   Chart.StoreString(name +".input.Signal.Sound",         Signal.Sound        );
   Chart.StoreString(name +".input.Signal.Mail.Receiver", Signal.Mail.Receiver);
   Chart.StoreString(name +".input.Signal.SMS.Receiver",  Signal.SMS.Receiver );
   return(!catch("StoreInputParameters(1)"));
}


/**
 * Restore input parameters found in the chart after recompilation.
 *
 * @return bool - success status
 */
bool RestoreInputParameters() {
   string name = ProgramName();
   Chart.RestoreInt   (name +".input.Periods",              Periods             );
   Chart.RestoreColor (name +".input.Color.UpTrend",        Color.UpTrend       );
   Chart.RestoreColor (name +".input.Color.DownTrend",      Color.DownTrend     );
   Chart.RestoreColor (name +".input.Color.Channel",        Color.Channel       );
   Chart.RestoreString(name +".input.Draw.Type",            Draw.Type           );
   Chart.RestoreInt   (name +".input.Draw.Width",           Draw.Width          );
   Chart.RestoreInt   (name +".input.Max.Bars",             Max.Bars            );
   Chart.RestoreString(name +".input.Signal.onTrendChange", Signal.onTrendChange);
   Chart.RestoreString(name +".input.Signal.Sound",         Signal.Sound        );
   Chart.RestoreString(name +".input.Signal.Mail.Receiver", Signal.Mail.Receiver);
   Chart.RestoreString(name +".input.Signal.SMS.Receiver",  Signal.SMS.Receiver );
   return(!catch("RestoreInputParameters(1)"));
}


/**
 * Return a string representation of the input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("Periods=",              Periods,                              ";", NL,
                            "Color.UpTrend=",        ColorToStr(Color.UpTrend),            ";", NL,
                            "Color.DownTrend=",      ColorToStr(Color.DownTrend),          ";", NL,
                            "Color.Channel=",        ColorToStr(Color.Channel),            ";", NL,
                            "Draw.Type=",            DoubleQuoteStr(Draw.Type),            ";", NL,
                            "Draw.Width=",           Draw.Width,                           ";", NL,
                            "Max.Bars=",             Max.Bars,                             ";", NL,
                            "Signal.onTrendChange=", DoubleQuoteStr(Signal.onTrendChange), ";", NL,
                            "Signal.Sound=",         DoubleQuoteStr(Signal.Sound),         ";", NL,
                            "Signal.Mail.Receiver=", DoubleQuoteStr(Signal.Mail.Receiver), ";", NL,
                            "Signal.SMS.Receiver=",  DoubleQuoteStr(Signal.SMS.Receiver),  ";")
   );
}
