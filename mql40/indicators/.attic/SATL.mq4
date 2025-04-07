/**
 * SATL - Slow Adaptive Trendline
 *
 * Coefficients are more than 10 years old.
 *
 * Indicator buffers for iCustom():
 *  � MovingAverage.MODE_MA:    MA values
 *  � MovingAverage.MODE_TREND: trend direction and length
 *    - trend direction:        positive values denote an uptrend (+1...+n), negative values denote a downtrend (-1...-n)
 *    - trend length:           the absolute value of the direction is the trend length in bars since the last reversal
 *
 * @link  http://www.finware.com/generator.html
 * @link  http://fx.qrz.ru/
 */
#include <rsf/stddefines.mqh>
int   __InitFlags[];
int __DeinitFlags[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern color  Color.UpTrend                  = Blue;
extern color  Color.DownTrend                = Red;
extern string Draw.Type                      = "Line* | Dot";
extern int    Draw.Width                     = 3;
extern int    MaxBarsBack                    = 10000;    // max. values to calculate (-1: all available)

extern string ___a__________________________ = "=== Signaling ===";
extern bool   Signal.onTrendChange           = false;
extern bool   Signal.onTrendChange.Sound     = true;
extern string Signal.onTrendChange.SoundUp   = "Signal Up.wav";
extern string Signal.onTrendChange.SoundDown = "Signal Down.wav";
extern bool   Signal.onTrendChange.Alert     = false;
extern bool   Signal.onTrendChange.Mail      = false;
extern bool   Signal.onTrendChange.SMS       = false;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <rsf/core/indicator.mqh>
#include <rsf/stdfunctions.mqh>
#include <rsf/stdlib.mqh>
#include <rsf/functions/chartlegend.mqh>
#include <rsf/functions/ConfigureSignals.mqh>
#include <rsf/functions/IsBarOpen.mqh>
#include <rsf/functions/ObjectCreateRegister.mqh>
#include <rsf/functions/trend.mqh>

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

double main     [];                                      // filter main values:  invisible, displayed in legend and "Data" window
double trend    [];                                      // trend direction:     invisible, displayed in "Data" window
double uptrend  [];                                      // uptrend values:      visible
double downtrend[];                                      // downtrend values:    visible
double uptrend2 [];                                      // single-bar uptrends: visible

double filterWeights[];                                  // filter coefficients

string indicatorName = "";
string legendLabel   = "";
string legendInfo    = "";                               // additional chart legend info
int    drawType;


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   // validate inputs
   // colors: after deserialization the terminal might turn CLR_NONE (0xFFFFFFFF) into Black (0xFF000000)
   if (Color.UpTrend   == 0xFF000000) Color.UpTrend   = CLR_NONE;
   if (Color.DownTrend == 0xFF000000) Color.DownTrend = CLR_NONE;
   // Draw.Type
   string sValues[], sValue=StrToLower(Draw.Type);
   if (Explode(sValue, "*", sValues, 2) > 1) {
      int size = Explode(sValues[0], "|", sValues, NULL);
      sValue = sValues[size-1];
   }
   sValue = StrTrim(sValue);
   if      (StrStartsWith("line", sValue)) { drawType = DRAW_LINE;  Draw.Type = "Line"; }
   else if (StrStartsWith("dot",  sValue)) { drawType = DRAW_ARROW; Draw.Type = "Dot";  }
   else                  return(catch("onInit(1)  invalid input parameter Draw.Type: "+ DoubleQuoteStr(Draw.Type), ERR_INVALID_INPUT_PARAMETER));
   // Draw.Width
   if (Draw.Width < 0)   return(catch("onInit(2)  invalid input parameter Draw.Width: "+ Draw.Width, ERR_INVALID_INPUT_PARAMETER));
   // MaxBarsBack
   if (MaxBarsBack < -1) return(catch("onInit(3)  invalid input parameter MaxBarsBack: "+ MaxBarsBack, ERR_INVALID_INPUT_PARAMETER));
   if (MaxBarsBack == -1) MaxBarsBack = INT_MAX;

   // signaling
   string signalId = "Signal.onTrendChange";
   legendInfo = "";
   if (!ConfigureSignals(signalId, AutoConfiguration, Signal.onTrendChange)) return(last_error);
   if (Signal.onTrendChange) {
      if (!ConfigureSignalsBySound(signalId, AutoConfiguration, Signal.onTrendChange.Sound)) return(last_error);
      if (!ConfigureSignalsByAlert(signalId, AutoConfiguration, Signal.onTrendChange.Alert)) return(last_error);
      if (!ConfigureSignalsByMail (signalId, AutoConfiguration, Signal.onTrendChange.Mail))  return(last_error);
      if (!ConfigureSignalsBySMS  (signalId, AutoConfiguration, Signal.onTrendChange.SMS))   return(last_error);
      if (Signal.onTrendChange.Sound || Signal.onTrendChange.Alert || Signal.onTrendChange.Mail || Signal.onTrendChange.SMS) {
         legendInfo = StrLeft(ifString(Signal.onTrendChange.Sound, "sound,", "") + ifString(Signal.onTrendChange.Alert, "alert,", "") + ifString(Signal.onTrendChange.Mail, "mail,", "") + ifString(Signal.onTrendChange.SMS, "sms,", ""), -1);
         legendInfo = "("+ legendInfo +")";
      }
      else Signal.onTrendChange = false;
   }

   // buffer management
   SetIndexBuffer(MODE_MA,        main     );            // filter main values:  invisible, displayed in legend and "Data" window
   SetIndexBuffer(MODE_TREND,     trend    );            // trend direction:     invisible, displayed in "Data" window
   SetIndexBuffer(MODE_UPTREND,   uptrend  );            // uptrend values:      visible
   SetIndexBuffer(MODE_DOWNTREND, downtrend);            // downtrend values:    visible
   SetIndexBuffer(MODE_UPTREND2,  uptrend2 );            // single-bar uptrends: visible

   // names, labels and display options
   legendLabel = CreateChartLegend();
   indicatorName = ProgramName();
   IndicatorShortName(indicatorName);                    // chart tooltips and context menu
   SetIndexLabel(MODE_MA,        indicatorName);         // chart tooltips and "Data" window
   SetIndexLabel(MODE_TREND,     indicatorName +" trend");
   SetIndexLabel(MODE_UPTREND,   NULL);
   SetIndexLabel(MODE_DOWNTREND, NULL);
   SetIndexLabel(MODE_UPTREND2,  NULL);
   IndicatorDigits(Digits);
   SetIndicatorOptions();

   // initialize filter settings
   InitFilter();

   return(catch("onInit(4)"));
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
   int length   = ArraySize(filterWeights);
   int startbar = Min(MaxBarsBack-1, ChangedBars-1, Bars-length);
   if (startbar < 0 && MaxBarsBack) return(logInfo("onTick(2)  Tick="+ Ticks, ERR_HISTORY_INSUFFICIENT));

   // recalculate changed bars
   for (int bar=startbar; bar >= 0; bar--) {
      main[bar] = 0;
      for (int i=0; i < length; i++) {
         main[bar] += filterWeights[i] * Close[bar+i];
      }
      UpdateTrend(main, bar, trend, uptrend, downtrend, uptrend2, true, true, drawType, Digits);
   }

   if (!__isSuperContext) {
      UpdateTrendLegend(legendLabel, indicatorName, legendInfo, Color.UpTrend, Color.DownTrend, main[0], trend[0]);

      if (Signal.onTrendChange) /*&&*/ if (IsBarOpen()) {
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
   string message="", accountTime="("+ TimeToStr(TimeLocalEx("onTrendChange()1"), TIME_MINUTES|TIME_SECONDS) +", "+ GetAccountAlias() +")";

   if (trend == MODE_UPTREND) {
      message = indicatorName +" turned up (market: "+ NumberToStr((Bid+Ask)/2, PriceFormat) +")";
      if (IsLogInfo()) logInfo("onTrendChange(2)  "+ message);
      message = Symbol() +","+ PeriodDescription() +": "+ message;

      if (Signal.onTrendChange.Alert) Alert(message);
      if (Signal.onTrendChange.Sound) PlaySoundEx(Signal.onTrendChange.SoundUp);
      if (Signal.onTrendChange.Mail)  SendEmail("", "", message, message + NL + accountTime);
      if (Signal.onTrendChange.SMS)   SendSMS("", message + NL + accountTime);
      return(!catch("onTrendChange(3)"));
   }

   if (trend == MODE_DOWNTREND) {
      message = indicatorName +" turned down (market: "+ NumberToStr((Bid+Ask)/2, PriceFormat) +")";
      if (IsLogInfo()) logInfo("onTrendChange(4)  "+ message);
      message = Symbol() +","+ PeriodDescription() +": "+ message;

      if (Signal.onTrendChange.Alert) Alert(message);
      if (Signal.onTrendChange.Sound) PlaySoundEx(Signal.onTrendChange.SoundDown);
      if (Signal.onTrendChange.Mail)  SendEmail("", "", message, message + NL + accountTime);
      if (Signal.onTrendChange.SMS)   SendSMS("", message + NL + accountTime);
      return(!catch("onTrendChange(6)"));
   }

   return(!catch("onTrendChange(6)  invalid parameter trend: "+ trend, ERR_INVALID_PARAMETER));
}


/**
 * Initialize and populate the filter coefficients.
 *
 * @return bool - success status
 */
bool InitFilter() {
   double filter[] = {
      +0.0982862174,
      +0.0975682269,
      +0.0961401078,
      +0.0940230544,
      +0.0912437090,
      +0.0878391006,
      +0.0838544303,
      +0.0793406350,
      +0.0743569346,
      +0.0689666682,
      +0.0632381578,
      +0.0572428925,
      +0.0510534242,
      +0.0447468229,
      +0.0383959950,
      +0.0320735368,
      +0.0258537721,
      +0.0198005183,
      +0.0139807863,
      +0.0084512448,
      +0.0032639979,
      -0.0015350359,
      -0.0059060082,
      -0.0098190256,
      -0.0132507215,
      -0.0161875265,
      -0.0186164872,
      -0.0205446727,
      -0.0219739146,
      -0.0229204861,
      -0.0234080863,
      -0.0234566315,
      -0.0231017777,
      -0.0223796900,
      -0.0213300463,
      -0.0199924534,
      -0.0184126992,
      -0.0166377699,
      -0.0147139428,
      -0.0126796776,
      -0.0105938331,
      -0.0084736770,
      -0.0063841850,
      -0.0043466731,
      -0.0023956944,
      -0.0005535180,
      +0.0011421469,
      +0.0026845693,
      +0.0040471369,
      +0.0052380201,
      +0.0062194591,
      +0.0070340085,
      +0.0076266453,
      +0.0080376628,
      +0.0083037666,
      +0.0083694798,
      +0.0082901022,
      +0.0080741359,
      +0.0077543820,
      +0.0073260526,
      +0.0068163569,
      +0.0062325477,
      +0.0056078229,
      +0.0049516078,
      +0.0161380976
   };
   ArrayCopy(filterWeights, filter);

   double sum = SumDoubles(filterWeights);

   if (NE(sum, 1))
      return(!catch("InitFilter(1)  sum of filter("+ ArraySize(filterWeights) +") weights is not equal 1: "+ NumberToStr(sum, ".1+"), ERR_RUNTIME_ERROR));
   return(!catch("InitFilter(2)"));
}


/**
 * Set indicator options. After recompilation the function must be called from start() for options not to be ignored.
 *
 * @param  bool redraw [optional] - whether to redraw the chart (default: no)
 *
 * @return bool - success status
 */
bool SetIndicatorOptions(bool redraw = false) {
   redraw = redraw!=0;
   int draw_type = ifInt(Draw.Width, drawType, DRAW_NONE);

   SetIndexStyle(MODE_MA,        DRAW_NONE, EMPTY, EMPTY,      CLR_NONE);
   SetIndexStyle(MODE_TREND,     DRAW_NONE, EMPTY, EMPTY,      CLR_NONE);
   SetIndexStyle(MODE_UPTREND,   draw_type, EMPTY, Draw.Width, Color.UpTrend  ); SetIndexArrow(MODE_UPTREND,   158);
   SetIndexStyle(MODE_DOWNTREND, draw_type, EMPTY, Draw.Width, Color.DownTrend); SetIndexArrow(MODE_DOWNTREND, 158);
   SetIndexStyle(MODE_UPTREND2,  draw_type, EMPTY, Draw.Width, Color.UpTrend  ); SetIndexArrow(MODE_UPTREND2,  158);

   if (redraw) WindowRedraw();
   return(!catch("SetIndicatorOptions(1)"));
}


/**
 * Return a string representation of all input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("Color.UpTrend=",                  ColorToStr(Color.UpTrend),                      ";", NL,
                            "Color.DownTrend=",                ColorToStr(Color.DownTrend),                    ";", NL,
                            "Draw.Type=",                      DoubleQuoteStr(Draw.Type),                      ";", NL,
                            "Draw.Width=",                     Draw.Width,                                     ";", NL,
                            "MaxBarsBack=",                    MaxBarsBack,                                    ";", NL,

                            "Signal.onTrendChange=",           BoolToStr(Signal.onTrendChange),                ";", NL,
                            "Signal.onTrendChange.Sound=",     BoolToStr(Signal.onTrendChange.Sound),          ";", NL,
                            "Signal.onTrendChange.SoundUp=",   DoubleQuoteStr(Signal.onTrendChange.SoundUp),   ";", NL,
                            "Signal.onTrendChange.SoundDown=", DoubleQuoteStr(Signal.onTrendChange.SoundDown), ";", NL,
                            "Signal.onTrendChange.Alert=",     BoolToStr(Signal.onTrendChange.Alert),          ";", NL,
                            "Signal.onTrendChange.Mail=",      BoolToStr(Signal.onTrendChange.Mail),           ";", NL,
                            "Signal.onTrendChange.SMS=",       BoolToStr(Signal.onTrendChange.SMS),            ";")
   );
}
