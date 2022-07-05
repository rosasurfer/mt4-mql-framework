/**
 * NonLag Moving Average
 *
 * The "NonLag Moving Average" of Igor Durkin aka igorad, enhanced and converted to this framework.
 *
 * Indicator buffers for iCustom():
 *  • MovingAverage.MODE_MA:    MA values
 *  • MovingAverage.MODE_TREND: trend direction and length
 *    - trend direction:        positive values denote an uptrend (+1...+n), negative values a downtrend (-1...-n)
 *    - trend length:           the absolute direction value is the length of the trend in bars since the last reversal
 *
 *  @link  https://www.forexfactory.com/thread/571026#                                           [NonLag Moving Average v4.0]
 *  @link  http://www.yellowfx.com/nonlagma-v7-1-mq4-indicator.htm#                              [NonLag Moving Average v7.1]
 *  @link  http://www.mql5.com/en/forum/175037/page62#comment_4583907#                           [NonLag Moving Average v7.8]
 *  @link  https://www.mql5.com/en/forum/175037/page74#comment_4584032#                          [NonLag Moving Average v7.9]
 *
 *
 * TODO:
 *  - uses the formula of v4, v7 is a bit less responsive
 */
#include <stddefines.mqh>
int   __InitFlags[];
int __DeinitFlags[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern int    Cycle.Length         = 20;
extern string AppliedPrice         = "Open | High | Low | Close* | Median | Average | Typical | Weighted";

extern string Draw.Type            = "Line* | Dot";
extern int    Draw.Width           = 3;
extern color  Color.UpTrend        = RoyalBlue;
extern color  Color.DownTrend      = Red;
extern int    Max.Bars             = 10000;              // max. values to calculate (-1: all available)
extern string ___a__________________________;

extern string Signal.onTrendChange = "on | off | auto*";
extern string Signal.Sound         = "on | off | auto*";
extern string Signal.Mail          = "on | off | auto*";
extern string Signal.SMS           = "on | off | auto*";

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <rsfLib.mqh>
#include <functions/ConfigureSignals.mqh>
#include <functions/ConfigureSignalsByMail.mqh>
#include <functions/ConfigureSignalsBySMS.mqh>
#include <functions/ConfigureSignalsBySound.mqh>
#include <functions/IsBarOpen.mqh>
#include <functions/Trend.mqh>
#include <functions/ta/NLMA.mqh>

#define MODE_MA               MovingAverage.MODE_MA      // indicator buffer ids
#define MODE_TREND            MovingAverage.MODE_TREND
#define MODE_UPTREND          2
#define MODE_DOWNTREND        3
#define MODE_UPTREND2         4

#property indicator_chart_window
#property indicator_buffers   5

#property indicator_color1    CLR_NONE
#property indicator_color2    CLR_NONE
#property indicator_color3    CLR_NONE
#property indicator_color4    CLR_NONE
#property indicator_color5    CLR_NONE

double main     [];                                      // MA main values:      invisible, displayed in legend and "Data" window
double trend    [];                                      // trend direction:     invisible, displayed in "Data" window
double uptrend  [];                                      // uptrend values:      visible
double downtrend[];                                      // downtrend values:    visible
double uptrend2 [];                                      // single-bar uptrends: visible

int    cycles = 4;
int    cycleLength;
int    cycleWindowSize;
double maWeights[];                                      // bar weighting of the MA
int    maAppliedPrice;
int    drawType;
int    maxValues;

string indicatorName = "";
string legendLabel   = "";
string legendInfo    = "";                               // additional chart legend info
bool   enableMultiColoring;

bool   signals;
bool   signal.sound;
string signal.sound.trendChange_up   = "Signal Up.wav";
string signal.sound.trendChange_down = "Signal Down.wav";
bool   signal.mail;
string signal.mail.sender   = "";
string signal.mail.receiver = "";
bool   signal.sms;
string signal.sms.receiver = "";


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   // validate inputs
   // Cycle.Length
   if (Cycle.Length < 2) return(catch("onInit(1)  invalid input parameter Cycle.Length: "+ Cycle.Length, ERR_INVALID_INPUT_PARAMETER));
   cycleLength     = Cycle.Length;
   cycleWindowSize = cycles*cycleLength + cycleLength-1;

   // AppliedPrice
   string sValues[], sValue = StrToLower(AppliedPrice);
   if (Explode(sValue, "*", sValues, 2) > 1) {
      int size = Explode(sValues[0], "|", sValues, NULL);
      sValue = sValues[size-1];
   }
   sValue = StrTrim(sValue);
   if (sValue == "") sValue = "close";                   // default price type
   maAppliedPrice = StrToPriceType(sValue, F_PARTIAL_ID|F_ERR_INVALID_PARAMETER);
   if (maAppliedPrice==-1 || maAppliedPrice > PRICE_WEIGHTED)
                         return(catch("onInit(2)  invalid input parameter AppliedPrice: "+ DoubleQuoteStr(AppliedPrice), ERR_INVALID_INPUT_PARAMETER));
   AppliedPrice = PriceTypeDescription(maAppliedPrice);

   // Draw.Type
   sValue = StrToLower(Draw.Type);
   if (Explode(sValue, "*", sValues, 2) > 1) {
      size = Explode(sValues[0], "|", sValues, NULL);
      sValue = sValues[size-1];
   }
   sValue = StrTrim(sValue);
   if      (StrStartsWith("line", sValue)) { drawType = DRAW_LINE;  Draw.Type = "Line"; }
   else if (StrStartsWith("dot",  sValue)) { drawType = DRAW_ARROW; Draw.Type = "Dot";  }
   else                  return(catch("onInit(3)  invalid input parameter Draw.Type: "+ DoubleQuoteStr(Draw.Type), ERR_INVALID_INPUT_PARAMETER));

   // Draw.Width
   if (Draw.Width < 0)   return(catch("onInit(4)  invalid input parameter Draw.Width: "+ Draw.Width, ERR_INVALID_INPUT_PARAMETER));

   // colors: after deserialization the terminal might turn CLR_NONE (0xFFFFFFFF) into Black (0xFF000000)
   if (Color.UpTrend   == 0xFF000000) Color.UpTrend   = CLR_NONE;
   if (Color.DownTrend == 0xFF000000) Color.DownTrend = CLR_NONE;

   // Max.Bars
   if (Max.Bars < -1)    return(catch("onInit(5)  invalid input parameter Max.Bars: "+ Max.Bars, ERR_INVALID_INPUT_PARAMETER));
   maxValues = ifInt(Max.Bars==-1, INT_MAX, Max.Bars);

   // signaling
   if (!ConfigureSignals(ProgramName(MODE_NICE), Signal.onTrendChange, signals))                         return(last_error);
   if (signals) {
      if (!ConfigureSignalsBySound(Signal.Sound, signal.sound                                         )) return(last_error);
      if (!ConfigureSignalsByMail (Signal.Mail,  signal.mail, signal.mail.sender, signal.mail.receiver)) return(last_error);
      if (!ConfigureSignalsBySMS  (Signal.SMS,   signal.sms,                      signal.sms.receiver )) return(last_error);
      if (signal.sound || signal.mail || signal.sms) {
         legendInfo = "TrendChange="+ StrLeft(ifString(signal.sound, "Sound+", "") + ifString(signal.mail, "Mail+", "") + ifString(signal.sms, "SMS+", ""), -1);
      }
      else signals = false;
   }

   // buffer management
   SetIndexBuffer(MODE_MA,        main     );            // MA main values:      invisible, displayed in legend and "Data" window
   SetIndexBuffer(MODE_TREND,     trend    );            // trend direction:     invisible, displayed in "Data" window
   SetIndexBuffer(MODE_UPTREND,   uptrend  );            // uptrend values:      visible
   SetIndexBuffer(MODE_DOWNTREND, downtrend);            // downtrend values:    visible
   SetIndexBuffer(MODE_UPTREND2,  uptrend2 );            // single-bar uptrends: visible

   // chart legend and coloring
   if (!IsSuperContext()) {
      legendLabel = CreateLegendLabel();
      RegisterObject(legendLabel);
      enableMultiColoring = true;
   }
   else {
      enableMultiColoring = false;
   }

   // names, labels and display options
   string sAppliedPrice = ifString(maAppliedPrice==PRICE_CLOSE, "", ", "+ PriceTypeDescription(maAppliedPrice));
   indicatorName = ProgramName(MODE_NICE) +"("+ cycleLength + sAppliedPrice +")";
   string shortName = "NLMA("+ cycleLength +")";
   IndicatorShortName(shortName);                        // chart tooltips and context menu
   SetIndexLabel(MODE_MA,        shortName);             // chart tooltips and "Data" window
   SetIndexLabel(MODE_TREND,     shortName +" trend");
   SetIndexLabel(MODE_UPTREND,   NULL);
   SetIndexLabel(MODE_DOWNTREND, NULL);
   SetIndexLabel(MODE_UPTREND2,  NULL);
   IndicatorDigits(Digits);
   SetIndicatorOptions();

   // pre-calculate NLMA bar weights
   NLMA.CalculateWeights(maWeights, cycles, cycleLength);

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
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   // on the first tick after terminal start buffers may not yet be initialized (spurious issue)
   if (!ArraySize(main)) return(logInfo("onTick(1)  sizeof(main) = 0", SetLastError(ERS_TERMINAL_NOT_YET_READY)));

   // reset buffers before performing a full recalculation
   if (!ValidBars) {
      ArrayInitialize(main,      EMPTY_VALUE);
      ArrayInitialize(trend,               0);
      ArrayInitialize(uptrend,   EMPTY_VALUE);
      ArrayInitialize(downtrend, EMPTY_VALUE);
      ArrayInitialize(uptrend2,  EMPTY_VALUE);
      SetIndicatorOptions();
   }

   // synchronize buffers with a shifted offline chart
   if (ShiftedBars > 0) {
      ShiftDoubleIndicatorBuffer(main,      Bars, ShiftedBars, EMPTY_VALUE);
      ShiftDoubleIndicatorBuffer(trend,     Bars, ShiftedBars,           0);
      ShiftDoubleIndicatorBuffer(uptrend,   Bars, ShiftedBars, EMPTY_VALUE);
      ShiftDoubleIndicatorBuffer(downtrend, Bars, ShiftedBars, EMPTY_VALUE);
      ShiftDoubleIndicatorBuffer(uptrend2,  Bars, ShiftedBars, EMPTY_VALUE);
   }

   // calculate start bar
   int bars     = Min(ChangedBars, maxValues);
   int startbar = Min(bars-1, Bars-cycleWindowSize);
   if (startbar < 0) return(logInfo("onTick(2)  Tick="+ Ticks, ERR_HISTORY_INSUFFICIENT));

   // recalculate changed bars
   for (int bar=startbar; bar >= 0; bar--) {
      main[bar] = 0;
      for (int i=0; i < cycleWindowSize; i++) {
         main[bar] += maWeights[i] * GetPrice(maAppliedPrice, bar+i);
      }
      Trend.UpdateDirection(main, bar, trend, uptrend, downtrend, uptrend2, enableMultiColoring, enableMultiColoring, drawType, Digits);
   }

   if (!IsSuperContext()) {
      Trend.UpdateLegend(legendLabel, indicatorName, legendInfo, Color.UpTrend, Color.DownTrend, main[0], Digits, trend[0], Time[0]);

      // signal trend changes
      if (signals) /*&&*/ if (IsBarOpen()) {
         int iTrend = Round(trend[1]);
         if      (iTrend ==  1) onTrendChange(MODE_UPTREND);
         else if (iTrend == -1) onTrendChange(MODE_DOWNTREND);
      }
   }
   return(last_error);
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

      if (signal.sound) error |= PlaySoundEx(signal.sound.trendChange_up);
      if (signal.mail)  error |= !SendEmail(signal.mail.sender, signal.mail.receiver, message, message +NL+ accountTime);
      if (signal.sms)   error |= !SendSMS(signal.sms.receiver, message +NL+ accountTime);
      return(!error);
   }

   if (trend == MODE_DOWNTREND) {
      message = indicatorName +" turned down (market: "+ NumberToStr((Bid+Ask)/2, PriceFormat) +")";
      if (IsLogInfo()) logInfo("onTrendChange(2)  "+ message);
      message = Symbol() +","+ PeriodDescription() +": "+ message;

      if (signal.sound) error |= PlaySoundEx(signal.sound.trendChange_down);
      if (signal.mail)  error |= !SendEmail(signal.mail.sender, signal.mail.receiver, message, message +NL+ accountTime);
      if (signal.sms)   error |= !SendSMS(signal.sms.receiver, message +NL+ accountTime);
      return(!error);
   }

   return(!catch("onTrendChange(3)  invalid parameter trend: "+ trend, ERR_INVALID_PARAMETER));
}


/**
 * Get the price of the specified type at the given bar offset.
 *
 * @param  int type - price type
 * @param  int i    - bar offset
 *
 * @return double - price or NULL in case of errors
 */
double GetPrice(int type, int i) {
   if (i < 0 || i >= Bars) return(!catch("GetPrice(1)  invalid parameter i: "+ i +" (out of range)", ERR_INVALID_PARAMETER));

   switch (type) {
      case PRICE_CLOSE:                                                          // 0
      case PRICE_BID:      return(Close[i]);                                     // 8
      case PRICE_OPEN:     return( Open[i]);                                     // 1
      case PRICE_HIGH:     return( High[i]);                                     // 2
      case PRICE_LOW:      return(  Low[i]);                                     // 3
      case PRICE_MEDIAN:                                                         // 4: (H+L)/2
      case PRICE_TYPICAL:                                                        // 5: (H+L+C)/3
      case PRICE_WEIGHTED: return(iMA(NULL, NULL, 1, 0, MODE_SMA, type, i));     // 6: (H+L+C+C)/4
      case PRICE_AVERAGE:  return((Open[i] + High[i] + Low[i] + Close[i])/4);    // 7: (O+H+L+C)/4
   }
   return(!catch("GetPrice(2)  invalid or unsupported price type: "+ type, ERR_INVALID_PARAMETER));
}


/**
 * Workaround for various terminal bugs when setting indicator options. Usually options are set in init(). However after
 * recompilation options must be set in start() to not be ignored.
 */
void SetIndicatorOptions() {
   int draw_type = ifInt(Draw.Width, drawType, DRAW_NONE);

   SetIndexStyle(MODE_MA,        DRAW_NONE, EMPTY, EMPTY,      CLR_NONE       );
   SetIndexStyle(MODE_TREND,     DRAW_NONE, EMPTY, EMPTY,      CLR_NONE       );
   SetIndexStyle(MODE_UPTREND,   draw_type, EMPTY, Draw.Width, Color.UpTrend  ); SetIndexArrow(MODE_UPTREND,   158);
   SetIndexStyle(MODE_DOWNTREND, draw_type, EMPTY, Draw.Width, Color.DownTrend); SetIndexArrow(MODE_DOWNTREND, 158);
   SetIndexStyle(MODE_UPTREND2,  draw_type, EMPTY, Draw.Width, Color.UpTrend  ); SetIndexArrow(MODE_UPTREND2,  158);
}


/**
 * Return a string representation of the input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("Cycle.Length=",         Cycle.Length,                         ";", NL,
                            "AppliedPrice=",         DoubleQuoteStr(AppliedPrice),         ";", NL,
                            "Draw.Type=",            DoubleQuoteStr(Draw.Type),            ";", NL,
                            "Draw.Width=",           Draw.Width,                           ";", NL,
                            "Color.UpTrend=",        ColorToStr(Color.UpTrend),            ";", NL,
                            "Color.DownTrend=",      ColorToStr(Color.DownTrend),          ";", NL,
                            "Max.Bars=",             Max.Bars,                             ";", NL,
                            "Signal.onTrendChange=", DoubleQuoteStr(Signal.onTrendChange), ";", NL,
                            "Signal.Sound=",         DoubleQuoteStr(Signal.Sound),         ";", NL,
                            "Signal.Mail=",          DoubleQuoteStr(Signal.Mail),          ";", NL,
                            "Signal.SMS=",           DoubleQuoteStr(Signal.SMS),           ";")
   );
}
