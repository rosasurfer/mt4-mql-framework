/**
 * Arnaud Legoux Moving Average
 *
 * A moving average using a Gaussian distribution function for calculating bar weights (algorithm by Arnaud Legoux).
 *
 * Indicator buffers for iCustom():
 *  • MovingAverage.MODE_MA:    MA values
 *  • MovingAverage.MODE_TREND: trend direction and length
 *    - trend direction:        positive values denote an uptrend (+1...+n), negative values a downtrend (-1...-n)
 *    - trend length:           the absolute direction value is the length of the trend in bars since the last reversal
 *
 *  @link  http://web.archive.org/web/20180307031850/http://www.arnaudlegoux.com/#             [Arnaud Legoux Moving Average]
 *  @link  https://www.forexfactory.com/thread/251668#                                         [Arnaud Legoux Moving Average]
 *  @see   "/etc/doc/alma/ALMA Weighted Distribution.xls"                                        [ALMA weighted distribution]
 */
#include <stddefines.mqh>
int   __InitFlags[];
int __DeinitFlags[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern int    MA.Periods                     = 38;
extern string MA.AppliedPrice                = "Open | High | Low | Close* | Median | Average | Typical | Weighted";
extern double Distribution.Offset            = 0.85;              // Gaussian distribution offset (offset of parabola vertex: 0..1)
extern double Distribution.Sigma             = 6.0;               // Gaussian distribution sigma (parabola steepness)

extern string Draw.Type                      = "Line* | Dot";
extern int    Draw.Width                     = 3;
extern color  Color.UpTrend                  = Blue;
extern color  Color.DownTrend                = Red;
extern int    Max.Bars                       = 10000;             // max. values to calculate (-1: all available)
extern int    PeriodStepper.StepSize         = 0;                 // parameter stepper for MA.Periods

extern string ___a__________________________ = "=== Signaling ===";
extern bool   Signal.onTrendChange           = false;
extern bool   Signal.onTrendChange.Sound     = true;
extern string Signal.onTrendChange.SoundUp   = "Signal Up.wav";
extern string Signal.onTrendChange.SoundDown = "Signal Down.wav";
extern bool   Signal.onTrendChange.Popup     = false;
extern bool   Signal.onTrendChange.Mail      = false;
extern bool   Signal.onTrendChange.SMS       = false;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <rsfLib.mqh>
#include <functions/ConfigureSignals.mqh>
#include <functions/HandleCommands.mqh>
#include <functions/IsBarOpen.mqh>
#include <functions/Trend.mqh>
#include <functions/ta/ALMA.mqh>

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

double main     [];                                      // ALMA main values:    invisible, displayed in legend and "Data" window
double trend    [];                                      // trend direction:     invisible, displayed in "Data" window
double uptrend  [];                                      // uptrend values:      visible
double downtrend[];                                      // downtrend values:    visible
double uptrend2 [];                                      // single-bar uptrends: visible

int    maPeriods;
int    maAppliedPrice;
double maWeights[];                                      // bar weighting of the MA
int    drawType;
int    maxValues;

string indicatorName = "";
string legendLabel   = "";
string legendInfo    = "";                               // additional chart legend info
bool   enableMultiColoring;

bool   signalTrendChange;
bool   signalTrendChange.sound;
bool   signalTrendChange.popup;
bool   signalTrendChange.mail;
string signalTrendChange.mailSender   = "";
string signalTrendChange.mailReceiver = "";
bool   signalTrendChange.sms;
string signalTrendChange.smsReceiver = "";

// period stepper directions
#define STEP_UP    1
#define STEP_DOWN -1


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   string indicator = ProgramName(MODE_NICE);

   // validate inputs
   // MA.Periods
   maPeriods = MA.Periods;
   if (AutoConfiguration) maPeriods = GetConfigInt(indicator, "MA.Periods", maPeriods);
   if (maPeriods < 1)                                        return(catch("onInit(1)  invalid input parameter MA.Periods: "+ maPeriods, ERR_INVALID_INPUT_PARAMETER));
   // MA.AppliedPrice
   string sValues[], sValue = MA.AppliedPrice;
   if (AutoConfiguration) sValue = GetConfigString(indicator, "MA.AppliedPrice", sValue);
   if (Explode(sValue, "*", sValues, 2) > 1) {
      int size = Explode(sValues[0], "|", sValues, NULL);
      sValue = sValues[size-1];
   }
   sValue = StrTrim(sValue);
   maAppliedPrice = StrToPriceType(sValue, F_PARTIAL_ID|F_ERR_INVALID_PARAMETER);
   if (maAppliedPrice==-1 || maAppliedPrice > PRICE_AVERAGE) return(catch("onInit(2)  invalid input parameter MA.AppliedPrice: "+ DoubleQuoteStr(sValue), ERR_INVALID_INPUT_PARAMETER));
   MA.AppliedPrice = PriceTypeDescription(maAppliedPrice);
   // Distribution.Offset
   if (AutoConfiguration) Distribution.Offset = GetConfigDouble(indicator, "Distribution.Offset", Distribution.Offset);
   if (Distribution.Offset < 0 || Distribution.Offset > 1)   return(catch("onInit(3)  invalid input parameter Distribution.Offset: "+ NumberToStr(Distribution.Offset, ".1+") +" (must be from 0 to 1)", ERR_INVALID_INPUT_PARAMETER));
   // Distribution.Sigma
   if (AutoConfiguration) Distribution.Sigma = GetConfigDouble(indicator, "Distribution.Sigma", Distribution.Sigma);
   if (Distribution.Sigma <= 0)                              return(catch("onInit(4)  invalid input parameter Distribution.Sigma: "+ NumberToStr(Distribution.Sigma, ".1+") +" (must be positive)", ERR_INVALID_INPUT_PARAMETER));
   // Draw.Type
   sValue = Draw.Type;
   if (AutoConfiguration) sValue = GetConfigString(indicator, "Draw.Type", sValue);
   if (Explode(sValue, "*", sValues, 2) > 1) {
      size = Explode(sValues[0], "|", sValues, NULL);
      sValue = sValues[size-1];
   }
   sValue = StrToLower(StrTrim(sValue));
   if      (StrStartsWith("line", sValue)) { drawType = DRAW_LINE;  Draw.Type = "Line"; }
   else if (StrStartsWith("dot",  sValue)) { drawType = DRAW_ARROW; Draw.Type = "Dot";  }
   else                                                      return(catch("onInit(5)  invalid input parameter Draw.Type: "+ DoubleQuoteStr(sValue), ERR_INVALID_INPUT_PARAMETER));
   // Draw.Width
   if (AutoConfiguration) Draw.Width = GetConfigInt(indicator, "Draw.Width", Draw.Width);
   if (Draw.Width < 0)                                       return(catch("onInit(6)  invalid input parameter Draw.Width: "+ Draw.Width, ERR_INVALID_INPUT_PARAMETER));
   // colors: after deserialization the terminal might turn CLR_NONE (0xFFFFFFFF) into Black (0xFF000000)
   if (AutoConfiguration) Color.UpTrend   = GetConfigColor(indicator, "Color.UpTrend",   Color.UpTrend  );
   if (AutoConfiguration) Color.DownTrend = GetConfigColor(indicator, "Color.DownTrend", Color.DownTrend);
   if (Color.UpTrend   == 0xFF000000) Color.UpTrend   = CLR_NONE;
   if (Color.DownTrend == 0xFF000000) Color.DownTrend = CLR_NONE;
   // Max.Bars
   if (AutoConfiguration) Max.Bars = GetConfigInt(indicator, "Max.Bars", Max.Bars);
   if (Max.Bars < -1)                                        return(catch("onInit(7)  invalid input parameter Max.Bars: "+ Max.Bars, ERR_INVALID_INPUT_PARAMETER));
   maxValues = ifInt(Max.Bars==-1, INT_MAX, Max.Bars);
   // PeriodStepper.StepSize
   if (PeriodStepper.StepSize < 0)                           return(catch("onInit(8)  invalid input parameter PeriodStepper.StepSize: "+ PeriodStepper.StepSize +" (must be >= 0)", ERR_INVALID_INPUT_PARAMETER));

   // signaling
   signalTrendChange       = Signal.onTrendChange;
   signalTrendChange.sound = Signal.onTrendChange.Sound;
   signalTrendChange.popup = Signal.onTrendChange.Popup;
   signalTrendChange.mail  = Signal.onTrendChange.Mail;
   signalTrendChange.sms   = Signal.onTrendChange.SMS;
   legendInfo              = "";
   string signalId = "Signal.onTrendChange";
   if (!ConfigureSignals2(signalId, AutoConfiguration, signalTrendChange)) return(last_error);
   if (signalTrendChange) {
      if (!ConfigureSignalsBySound2(signalId, AutoConfiguration, signalTrendChange.sound))                                                              return(last_error);
      if (!ConfigureSignalsByPopup (signalId, AutoConfiguration, signalTrendChange.popup))                                                              return(last_error);
      if (!ConfigureSignalsByMail2 (signalId, AutoConfiguration, signalTrendChange.mail, signalTrendChange.mailSender, signalTrendChange.mailReceiver)) return(last_error);
      if (!ConfigureSignalsBySMS2  (signalId, AutoConfiguration, signalTrendChange.sms, signalTrendChange.smsReceiver))                                 return(last_error);
      if (signalTrendChange.sound || signalTrendChange.popup || signalTrendChange.mail || signalTrendChange.sms) {
         legendInfo = StrLeft(ifString(signalTrendChange.sound, "sound,", "") + ifString(signalTrendChange.popup, "popup,", "") + ifString(signalTrendChange.mail, "mail,", "") + ifString(signalTrendChange.sms, "sms,", ""), -1);
         legendInfo = "("+ legendInfo +")";
      }
      else signalTrendChange = false;
   }

   // buffer management and display options
   SetIndexBuffer(MODE_MA,        main     );            // MA main values:      invisible, displayed in legend and "Data" window
   SetIndexBuffer(MODE_TREND,     trend    );            // trend direction:     invisible, displayed in "Data" window
   SetIndexBuffer(MODE_UPTREND,   uptrend  );            // uptrend values:      visible
   SetIndexBuffer(MODE_DOWNTREND, downtrend);            // downtrend values:    visible
   SetIndexBuffer(MODE_UPTREND2,  uptrend2 );            // single-bar uptrends: visible
   SetIndicatorOptions();

   // calculate ALMA bar weights
   ALMA.CalculateWeights(maPeriods, Distribution.Offset, Distribution.Sigma, maWeights);

   // chart legend and coloring
   if (!__isSuperContext) {
      legendLabel = CreateLegendLabel();
      enableMultiColoring = true;
   }
   else {
      enableMultiColoring = false;
   }
   return(catch("onInit(9)"));
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
   int starttime = GetTickCount();

   // on the first tick after terminal start buffers may not yet be initialized (spurious issue)
   if (!ArraySize(main)) return(logInfo("onTick(1)  sizeof(main) = 0", SetLastError(ERS_TERMINAL_NOT_YET_READY)));

   // process incoming commands (may rewrite ValidBars/ChangedBars/ShiftedBars)
   if (__isChart && PeriodStepper.StepSize) HandleCommands("ParameterStepper", false);

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
   int startbar = Min(bars-1, Bars-maPeriods);
   if (startbar < 0) return(logInfo("onTick(2)  Tick="+ Ticks +"  Bars="+ Bars +"  needed="+ maPeriods, ERR_HISTORY_INSUFFICIENT));

   // recalculate changed bars
   for (int bar=startbar; bar >= 0; bar--) {
      main[bar] = 0;
      for (int i=0; i < maPeriods; i++) {
         main[bar] += maWeights[i] * GetPrice(maAppliedPrice, bar+i);
      }
      Trend.UpdateDirection(main, bar, trend, uptrend, downtrend, uptrend2, enableMultiColoring, enableMultiColoring, drawType, Digits);
   }

   if (!__isSuperContext) {
      Trend.UpdateLegend(legendLabel, indicatorName, legendInfo, Color.UpTrend, Color.DownTrend, main[0], Digits, trend[0], Time[0]);

      // monitor trend changes
      if (signalTrendChange) /*&&*/ if (IsBarOpen()) {
         int iTrend = Round(trend[1]);
         if      (iTrend ==  1) onTrendChange(MODE_UPTREND);
         else if (iTrend == -1) onTrendChange(MODE_DOWNTREND);
      }
   }

   int millis = (GetTickCount()-starttime);
   //if (!ValidBars) debug("onTick(0.1)  Tick="+ Ticks +"  bars="+ (startbar+1) +"  time="+ DoubleToStr(millis/1000., 3) +" sec");
   return(last_error);

   // Speed test on Toshiba Satellite
   // ---------------------------------------------------------------------------------------------------
   // ALMA(7xD1) on H1  = ALMA(168)    weights(  168)=0.009 sec   bars(2000)=0.110 sec   loops=   336,000
   // ALMA(7xD1) on M30 = ALMA(336)    weights(  336)=0.009 sec   bars(2000)=0.250 sec   loops=   672,000
   // ALMA(7xD1) on M15 = ALMA(672)    weights(  672)=0.009 sec   bars(2000)=0.453 sec   loops= 1,344,000
   // ALMA(7xD1) on M5  = ALMA(2016)   weights( 2016)=0.016 sec   bars(2000)=1.547 sec   loops= 4,032,000
   // ALMA(7xD1) on M1  = ALMA(10080)  weights(10080)=0.016 sec   bars(2000)=7.110 sec   loops=20,160,000
   //
   // Speed test on Toshiba Portege
   // ---------------------------------------------------------------------------------------------------
   // as above            ALMA(168)    as above                   bars(2000)=0.078 sec   as above
   // ...                 ALMA(336)    ...                        bars(2000)=0.156 sec   ...
   // ...                 ALMA(672)    ...                        bars(2000)=0.312 sec   ...
   // ...                 ALMA(2016)   ...                        bars(2000)=0.952 sec   ...
   // ...                 ALMA(10080)  ...                        bars(2000)=4.773 sec   ...
   //
   // Speed test on Dell Precision
   // ---------------------------------------------------------------------------------------------------
   // as above            ALMA(168)    as above                   bars(2000)=0.062 sec   as above           // no quantifiable difference between iMA() and GetPrice()
   // ...                 ALMA(336)    ...                        bars(2000)=0.109 sec   ...
   // ...                 ALMA(672)    ...                        bars(2000)=0.218 sec   ...
   // ...                 ALMA(2016)   ...                        bars(2000)=0.671 sec   ...
   // ...                 ALMA(10080)  ...                        bars(2000)=3.323 sec   ...
   //                     ALMA(38)     ...                       bars(10000)=0.063 sec
   //
   // Speed test on Dell Precision NonLagMA
   // ---------------------------------------------------------------------------------------------------
   //                     NLMA(34)     weights(169)               bars(2000)=0.062 sec   as above           // no quantifiable difference between iMA() and GetPrice()
   //                     NLMA(68)     weights(339)               bars(2000)=0.125 sec   ...
   //                     NLMA(135)    weights(674)               bars(2000)=0.234 sec   ...
   //                     NLMA(404)    weights(2019)              bars(2000)=0.733 sec   ...
   //                     NLMA(2016)   weights(10079)             bars(2000)=3.557 sec   ...
   //                     NLMA(20)     weights(99)               bars(10000)=0.187 sec
   //
   // Conclusion: Weights calculation can be ignored, bottleneck is the nested loop in MA calculation.
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
   int error = NO_ERROR;

   if (trend == MODE_UPTREND) {
      message = indicatorName +" turned up (bid: "+ NumberToStr(Bid, PriceFormat) +")";
      if (IsLogInfo()) logInfo("onTrendChange(1)  "+ message);
      message = Symbol() +","+ PeriodDescription() +": "+ message;

      if (signalTrendChange.popup)          Alert(message);
      if (signalTrendChange.sound) error |= PlaySoundEx(Signal.onTrendChange.SoundUp);
      if (signalTrendChange.mail)  error |= !SendEmail(signalTrendChange.mailSender, signalTrendChange.mailReceiver, message, message + NL + accountTime);
      if (signalTrendChange.sms)   error |= !SendSMS(signalTrendChange.smsReceiver, message + NL + accountTime);
      return(!error);
   }

   if (trend == MODE_DOWNTREND) {
      message = indicatorName +" turned down (bid: "+ NumberToStr(Bid, PriceFormat) +")";
      if (IsLogInfo()) logInfo("onTrendChange(2)  "+ message);
      message = Symbol() +","+ PeriodDescription() +": "+ message;

      if (signalTrendChange.popup)          Alert(message);
      if (signalTrendChange.sound) error |= PlaySoundEx(Signal.onTrendChange.SoundDown);
      if (signalTrendChange.mail)  error |= !SendEmail(signalTrendChange.mailSender, signalTrendChange.mailReceiver, message, message + NL + accountTime);
      if (signalTrendChange.sms)   error |= !SendSMS(signalTrendChange.smsReceiver, message + NL + accountTime);
      return(!error);
   }

   return(!catch("onTrendChange(3)  invalid parameter trend: "+ trend, ERR_INVALID_PARAMETER));
}


/**
 * Process an incoming command.
 *
 * @param  string cmd                  - command name
 * @param  string params [optional]    - command parameters (default: none)
 * @param  string modifiers [optional] - command modifiers (default: none)
 *
 * @return bool - success status of the executed command
 */
bool onCommand(string cmd, string params="", string modifiers="") {
   string fullCmd = cmd +":"+ params +":"+ modifiers;

   static int lastTickcount = 0;
   int tickcount = StrToInteger(params);
   if (tickcount <= lastTickcount) return(false);
   lastTickcount = tickcount;

   if (cmd == "parameter-up")   return(PeriodStepper(STEP_UP));
   if (cmd == "parameter-down") return(PeriodStepper(STEP_DOWN));

   return(!logNotice("onCommand(1)  unsupported command: \""+ fullCmd +"\""));
}


/**
 * Change the currently active parameter "MA.Periods".
 *
 * @param  int direction - STEP_UP | STEP_DOWN
 *
 * @return bool - success status
 */
bool PeriodStepper(int direction) {
   if (direction!=STEP_UP && direction!=STEP_DOWN) return(!catch("PeriodStepper(1)  invalid parameter direction: "+ direction, ERR_INVALID_PARAMETER));

   int step = PeriodStepper.StepSize;

   if (!step || maPeriods + direction*step < 1) {
      PlaySoundEx("Plonk.wav");                       // no stepping or parameter limit reached
      return(false);
   }

   if (direction == STEP_UP) maPeriods += step;
   else                      maPeriods -= step;

   ChangedBars = Bars;
   ValidBars   = 0;
   ShiftedBars = 0;

   if (!ALMA.CalculateWeights(maPeriods, Distribution.Offset, Distribution.Sigma, maWeights)) return(false);
   PlaySoundEx("Parameter Step.wav");
   return(true);
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
   string sAppliedPrice = ifString(maAppliedPrice==PRICE_CLOSE, "", ", "+ PriceTypeDescription(maAppliedPrice));
   indicatorName = "ALMA("+ ifString(PeriodStepper.StepSize, "var:", "") + maPeriods + sAppliedPrice +")";
   string shortName = "ALMA("+ maPeriods +")";
   IndicatorShortName(shortName);

   int draw_type = ifInt(Draw.Width, drawType, DRAW_NONE);

   SetIndexStyle(MODE_MA,        DRAW_NONE, EMPTY, EMPTY,      CLR_NONE       );                                     SetIndexLabel(MODE_MA,        shortName);
   SetIndexStyle(MODE_TREND,     DRAW_NONE, EMPTY, EMPTY,      CLR_NONE       );                                     SetIndexLabel(MODE_TREND,     shortName +" trend");
   SetIndexStyle(MODE_UPTREND,   draw_type, EMPTY, Draw.Width, Color.UpTrend  ); SetIndexArrow(MODE_UPTREND,   158); SetIndexLabel(MODE_UPTREND,   NULL);
   SetIndexStyle(MODE_DOWNTREND, draw_type, EMPTY, Draw.Width, Color.DownTrend); SetIndexArrow(MODE_DOWNTREND, 158); SetIndexLabel(MODE_DOWNTREND, NULL);
   SetIndexStyle(MODE_UPTREND2,  draw_type, EMPTY, Draw.Width, Color.UpTrend  ); SetIndexArrow(MODE_UPTREND2,  158); SetIndexLabel(MODE_UPTREND2,  NULL);
   IndicatorDigits(Digits);
}


/**
 * Return a string representation of the input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("MA.Periods=",                     MA.Periods,                                     ";"+ NL,
                            "MA.AppliedPrice=",                DoubleQuoteStr(MA.AppliedPrice),                ";"+ NL,
                            "Distribution.Offset=",            NumberToStr(Distribution.Offset, ".1+"),        ";"+ NL,
                            "Distribution.Sigma=",             NumberToStr(Distribution.Sigma, ".1+"),         ";"+ NL,

                            "Draw.Type=",                      DoubleQuoteStr(Draw.Type),                      ";"+ NL,
                            "Draw.Width=",                     Draw.Width,                                     ";"+ NL,
                            "Color.DownTrend=",                ColorToStr(Color.DownTrend),                    ";"+ NL,
                            "Color.UpTrend=",                  ColorToStr(Color.UpTrend),                      ";"+ NL,
                            "Max.Bars=",                       Max.Bars,                                       ";"+ NL,
                            "PeriodStepper.StepSize=",         PeriodStepper.StepSize,                         ";"+ NL,

                            "Signal.onTrendChange=",           BoolToStr(Signal.onTrendChange),                ";"+ NL,
                            "Signal.onTrendChange.Sound=",     BoolToStr(Signal.onTrendChange.Sound),          ";"+ NL,
                            "Signal.onTrendChange.SoundUp=",   DoubleQuoteStr(Signal.onTrendChange.SoundUp),   ";"+ NL,
                            "Signal.onTrendChange.SoundDown=", DoubleQuoteStr(Signal.onTrendChange.SoundDown), ";"+ NL,
                            "Signal.onTrendChange.Popup=",     BoolToStr(Signal.onTrendChange.Popup),          ";"+ NL,
                            "Signal.onTrendChange.Mail=",      BoolToStr(Signal.onTrendChange.Mail),           ";"+ NL,
                            "Signal.onTrendChange.SMS=",       BoolToStr(Signal.onTrendChange.SMS),            ";")
   );
}
