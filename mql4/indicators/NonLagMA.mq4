/**
 * NonLag Moving Average
 *
 * A moving average using a cosine wave function for weight calculation. Corrected and enhanced version of the original code
 * published by Igor Durkin (aka igorad).
 *
 * Indicator buffers for iCustom():
 *  • MovingAverage.MODE_MA:    MA values
 *  • MovingAverage.MODE_TREND: trend direction and length
 *    - trend direction:        positive values denote an uptrend (+1...+n), negative values denote a downtrend (-1...-n)
 *    - trend length:           the absolute value of the direction is the trend length in bars since the last reversal
 *
 *  @link  https://www.forexfactory.com/thread/571026#                                           [NonLag Moving Average v4.0]
 *  @link  http://www.yellowfx.com/nonlagma-v7-1-mq4-indicator.htm#                              [NonLag Moving Average v7.1]
 *  @link  https://www.mql5.com/en/forum/175037/page62#comment_4583907                           [NonLag Moving Average v7.8]
 *  @link  https://www.mql5.com/en/forum/175037/page74#comment_4584032                           [NonLag Moving Average v7.9]
 *  @link  https://www.forexfactory.com/thread/561195-scalping-strategy#                          [Scalping Strategy M5 & M1]
 */
#include <rsf/stddefines.mqh>
int   __InitFlags[];
int __DeinitFlags[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern int    WaveCycle.Periods              = 20;                // bar periods per cosine wave cycle
extern int    WaveCycle.Periods.Step         = 0;                 // step size for a stepped input parameter (hotkey)
extern string MA.AppliedPrice                = "Open | High | Low | Close* | Median | Typical | Weighted";
extern double MA.ReversalFilter              = 0.7;               // min. MA change in std-deviations for a trend reversal
extern double MA.ReversalFilter.Step         = 0;                 // step size for a stepped input parameter (hotkey + VK_SHIFT)

extern string Draw.Type                      = "Line* | Dot";
extern int    Draw.Width                     = 3;
extern color  Color.UpTrend                  = Magenta;
extern color  Color.DownTrend                = Yellow;
extern int    MaxBarsBack                    = 10000;             // max. values to calculate (-1: all available)

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
#include <rsf/v40/chartlegend.mqh>
#include <rsf/v40/ConfigureSignals.mqh>
#include <rsf/v40/HandleCommands.mqh>
#include <rsf/v40/IsBarOpen.mqh>
#include <rsf/v40/ObjectCreateRegister.mqh>
#include <rsf/v40/trend.mqh>
#include <rsf/v40/ta/NLMA.mqh>

#define MODE_MA_FILTERED      MovingAverage.MODE_MA      // indicator buffer ids
#define MODE_TREND            MovingAverage.MODE_TREND
#define MODE_UPTREND          2
#define MODE_DOWNTREND        3
#define MODE_UPTREND2         4
#define MODE_MA_RAW           5
#define MODE_MA_CHANGE        6
#define MODE_AVG              7

#property indicator_chart_window
#property indicator_buffers   5                          // visible buffers
int       terminal_buffers  = 8;                         // all buffers

#property indicator_color1    CLR_NONE
#property indicator_color2    CLR_NONE
#property indicator_color3    CLR_NONE
#property indicator_color4    CLR_NONE
#property indicator_color5    CLR_NONE

double maRaw     [];                                     // MA raw main values:      invisible
double maFiltered[];                                     // MA filtered main values: invisible, displayed in legend and "Data" window
double trend     [];                                     // trend direction:         invisible, displayed in "Data" window
double uptrend   [];                                     // uptrend values:          visible
double downtrend [];                                     // downtrend values:        visible
double uptrend2  [];                                     // single-bar uptrends:     visible

double maChange  [];                                     // absolute change of current maRaw[] to previous maFiltered[]
double maAverage [];                                     // average of maChange[] over the last 'waveCyclePeriods' bars

int    waveCycles = 4;                                   // 4 initial cycles (1 more is added later)
int    maPeriods;
int    maAppliedPrice;
double maWeights[];                                      // bar weighting of the MA
int    drawType;

string indicatorName = "";
string shortName     = "";
string legendLabel   = "";
string legendInfo    = "";                               // additional chart legend info
bool   enableMultiColoring;

// parameter stepper directions
#define STEP_UP    1
#define STEP_DOWN -1


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   // validate inputs
   string indicator = WindowExpertName();

   // WaveCycle.Periods
   if (AutoConfiguration) WaveCycle.Periods = GetConfigInt(indicator, "WaveCycle.Periods", WaveCycle.Periods);
   if (WaveCycle.Periods < 3)      return(catch("onInit(1)  invalid input parameter WaveCycle.Periods: "+ WaveCycle.Periods +" (min. 3)", ERR_INVALID_INPUT_PARAMETER));
   // WaveCycle.Periods.Step
   if (AutoConfiguration) WaveCycle.Periods.Step = GetConfigInt(indicator, "WaveCycle.Periods.Step", WaveCycle.Periods.Step);
   if (WaveCycle.Periods.Step < 0) return(catch("onInit(2)  invalid input parameter WaveCycle.Periods.Step: "+ WaveCycle.Periods.Step +" (must be >= 0)", ERR_INVALID_INPUT_PARAMETER));
   // MA.AppliedPrice
   string sValues[], sValue = MA.AppliedPrice;
   if (AutoConfiguration) sValue = GetConfigString(indicator, "MA.AppliedPrice", sValue);
   if (Explode(sValue, "*", sValues, 2) > 1) {
      int size = Explode(sValues[0], "|", sValues, NULL);
      sValue = sValues[size-1];
   }
   sValue = StrTrim(sValue);
   maAppliedPrice = StrToPriceType(sValue, F_PARTIAL_ID|F_ERR_INVALID_PARAMETER);
   if (maAppliedPrice == -1)       return(catch("onInit(3)  invalid input parameter MA.AppliedPrice: "+ DoubleQuoteStr(sValue), ERR_INVALID_INPUT_PARAMETER));
   MA.AppliedPrice = PriceTypeDescription(maAppliedPrice);
   // MA.ReversalFilter
   if (AutoConfiguration) MA.ReversalFilter = GetConfigDouble(indicator, "MA.ReversalFilter", MA.ReversalFilter);
   if (MA.ReversalFilter < 0)      return(catch("onInit(4)  invalid input parameter MA.ReversalFilter: "+ NumberToStr(MA.ReversalFilter, ".1+") +" (must be >= 0)", ERR_INVALID_INPUT_PARAMETER));
   // MA.ReversalFilter.StepS
   if (AutoConfiguration) MA.ReversalFilter.Step = GetConfigDouble(indicator, "MA.ReversalFilter.Step", MA.ReversalFilter.Step);
   if (MA.ReversalFilter.Step < 0) return(catch("onInit(5)  invalid input parameter MA.ReversalFilter.Step: "+ NumberToStr(MA.ReversalFilter.Step, ".1+") +" (must be >= 0)", ERR_INVALID_INPUT_PARAMETER));
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
   else                            return(catch("onInit(6)  invalid input parameter Draw.Type: "+ DoubleQuoteStr(sValue), ERR_INVALID_INPUT_PARAMETER));
   // Draw.Width
   if (AutoConfiguration) Draw.Width = GetConfigInt(indicator, "Draw.Width", Draw.Width);
   if (Draw.Width < 0)             return(catch("onInit(7)  invalid input parameter Draw.Width: "+ Draw.Width, ERR_INVALID_INPUT_PARAMETER));
   // colors: after deserialization the terminal might turn CLR_NONE (0xFFFFFFFF) into Black (0xFF000000)
   if (AutoConfiguration) Color.UpTrend   = GetConfigColor(indicator, "Color.UpTrend",   Color.UpTrend);
   if (AutoConfiguration) Color.DownTrend = GetConfigColor(indicator, "Color.DownTrend", Color.DownTrend);
   if (Color.UpTrend   == 0xFF000000) Color.UpTrend   = CLR_NONE;
   if (Color.DownTrend == 0xFF000000) Color.DownTrend = CLR_NONE;
   // MaxBarsBack
   if (AutoConfiguration) MaxBarsBack = GetConfigInt(indicator, "MaxBarsBack", MaxBarsBack);
   if (MaxBarsBack < -1)           return(catch("onInit(8)  invalid input parameter MaxBarsBack: "+ MaxBarsBack, ERR_INVALID_INPUT_PARAMETER));
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

   // reset an active command handler
   if (__isChart && (WaveCycle.Periods.Step || MA.ReversalFilter.Step)) {
      GetChartCommand("ParameterStepper", sValues);
   }

   // restore a stored runtime status
   RestoreStatus();

   // buffer management and options
   SetIndexBuffer(MODE_MA_RAW,      maRaw     );   // MA raw main values:      invisible
   SetIndexBuffer(MODE_MA_FILTERED, maFiltered);   // MA filtered main values: invisible, displayed in legend and "Data" window
   SetIndexBuffer(MODE_TREND,       trend     );   // trend direction:         invisible, displayed in "Data" window
   SetIndexBuffer(MODE_UPTREND,     uptrend   );   // uptrend values:          visible
   SetIndexBuffer(MODE_DOWNTREND,   downtrend );   // downtrend values:        visible
   SetIndexBuffer(MODE_UPTREND2,    uptrend2  );   // single-bar uptrends:     visible
   SetIndexBuffer(MODE_MA_CHANGE,   maChange  );   //                          invisible
   SetIndexBuffer(MODE_AVG,         maAverage );   //                          invisible
   SetIndicatorOptions();

   // calculate NLMA bar weights
   NLMA.CalculateWeights(waveCycles, WaveCycle.Periods, maWeights);
   maPeriods = ArraySize(maWeights);

   // chart legend and coloring
   legendLabel = CreateChartLegend();
   enableMultiColoring = !__isSuperContext;

   return(catch("onInit(9)"));
}


/**
 * Deinitialization
 *
 * @return int - error status
 */
int onDeinit() {
   StoreStatus();
   return(last_error);
}


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   // on the first tick after terminal start buffers may not yet be initialized (spurious issue)
   if (!ArraySize(maRaw)) return(logInfo("onTick(1)  sizeof(maRaw) = 0", SetLastError(ERS_TERMINAL_NOT_YET_READY)));

   // process incoming commands (may rewrite ValidBars/ChangedBars/ShiftedBars)
   if (__isChart && (WaveCycle.Periods.Step || MA.ReversalFilter.Step)) {
      if (!HandleCommands("ParameterStepper")) return(last_error);
   }

   // reset buffers before performing a full recalculation
   if (!ValidBars) {
      ArrayInitialize(maRaw,                0);
      ArrayInitialize(maFiltered, EMPTY_VALUE);
      ArrayInitialize(maChange,             0);
      ArrayInitialize(maAverage,            0);
      ArrayInitialize(trend,                0);
      ArrayInitialize(uptrend,    EMPTY_VALUE);
      ArrayInitialize(downtrend,  EMPTY_VALUE);
      ArrayInitialize(uptrend2,   EMPTY_VALUE);
      SetIndicatorOptions();
   }

   // synchronize buffers with a shifted offline chart
   if (ShiftedBars > 0) {
      ShiftDoubleIndicatorBuffer(maRaw,      Bars, ShiftedBars,           0);
      ShiftDoubleIndicatorBuffer(maFiltered, Bars, ShiftedBars, EMPTY_VALUE);
      ShiftDoubleIndicatorBuffer(maChange,   Bars, ShiftedBars,           0);
      ShiftDoubleIndicatorBuffer(maAverage,  Bars, ShiftedBars,           0);
      ShiftDoubleIndicatorBuffer(trend,      Bars, ShiftedBars,           0);
      ShiftDoubleIndicatorBuffer(uptrend,    Bars, ShiftedBars, EMPTY_VALUE);
      ShiftDoubleIndicatorBuffer(downtrend,  Bars, ShiftedBars, EMPTY_VALUE);
      ShiftDoubleIndicatorBuffer(uptrend2,   Bars, ShiftedBars, EMPTY_VALUE);
   }

   // calculate start bar
   int startbar = Min(MaxBarsBack-1, ChangedBars-1, Bars-maPeriods);
   if (startbar < 0 && MaxBarsBack) return(logInfo("onTick(2)  Tick="+ Ticks +"  Bars="+ Bars +"  needed="+ maPeriods, ERR_HISTORY_INSUFFICIENT));

   double sum, stdDev, minChange;

   // recalculate changed bars
   for (int bar=startbar; bar >= 0; bar--) {
      maRaw[bar] = 0;
      for (int i=0; i < maPeriods; i++) {
         maRaw[bar] += maWeights[i] * iMA(NULL, NULL, 1, 0, MODE_SMA, maAppliedPrice, bar+i);
      }
      maFiltered[bar] = maRaw[bar];

      if (MA.ReversalFilter > 0) {
         maChange[bar] = maFiltered[bar] - maFiltered[bar+1];        // calculate the change of current raw to previous filtered MA
         sum = 0;
         for (i=0; i < WaveCycle.Periods; i++) {                     // calculate average(change) over last 'WaveCycle.Periods'
            sum += maChange[bar+i];
         }
         maAverage[bar] = sum/WaveCycle.Periods;

         if (maChange[bar] * trend[bar+1] < 0) {                     // on opposite signs = trend reversal
            sum = 0;                                                 // calculate stdDeviation(maChange[]) over last 'WaveCycle.Periods'
            for (i=0; i < WaveCycle.Periods; i++) {
               sum += MathPow(maChange[bar+i] - maAverage[bar+i], 2);
            }
            stdDev = MathSqrt(sum/WaveCycle.Periods);
            minChange = MA.ReversalFilter * stdDev;                  // calculate required min. change

            if (MathAbs(maChange[bar]) < minChange) {
               maFiltered[bar] = maFiltered[bar+1];                  // discard trend reversal if MA change is smaller
            }
         }
      }
      UpdateTrendDirection(maFiltered, bar, trend, uptrend, downtrend, uptrend2, enableMultiColoring, enableMultiColoring, drawType, Digits);
   }

   if (!__isSuperContext) {
      UpdateTrendLegend(legendLabel, indicatorName, legendInfo, Color.UpTrend, Color.DownTrend, maFiltered[0], trend[0]);

      if (Signal.onTrendChange) /*&&*/ if (IsBarOpen()) {            // monitor trend reversals
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
   string message="", accountTime="("+ TimeToStr(TimeLocalEx("onTrendChange(1)"), TIME_MINUTES|TIME_SECONDS) +", "+ GetAccountAlias() +")";

   if (trend == MODE_UPTREND) {
      message = shortName +" turned up (bid: "+ NumberToStr(Bid, PriceFormat) +")";
      if (IsLogInfo()) logInfo("onTrendChange(2)  "+ message);
      message = Symbol() +","+ PeriodDescription() +": "+ message;

      if (Signal.onTrendChange.Alert) Alert(message);
      if (Signal.onTrendChange.Sound) PlaySoundEx(Signal.onTrendChange.SoundUp);
      if (Signal.onTrendChange.Mail)  SendEmail("", "", message, message + NL + accountTime);
      if (Signal.onTrendChange.SMS)   SendSMS("", message + NL + accountTime);
      return(!catch("onTrendChange(3)"));
   }

   if (trend == MODE_DOWNTREND) {
      message = shortName +" turned down (bid: "+ NumberToStr(Bid, PriceFormat) +")";
      if (IsLogInfo()) logInfo("onTrendChange(4)  "+ message);
      message = Symbol() +","+ PeriodDescription() +": "+ message;

      if (Signal.onTrendChange.Alert) Alert(message);
      if (Signal.onTrendChange.Sound) PlaySoundEx(Signal.onTrendChange.SoundDown);
      if (Signal.onTrendChange.Mail)  SendEmail("", "", message, message + NL + accountTime);
      if (Signal.onTrendChange.SMS)   SendSMS("", message + NL + accountTime);
      return(!catch("onTrendChange(5)"));
   }

   return(!catch("onTrendChange(6)  invalid parameter trend: "+ trend, ERR_INVALID_PARAMETER));
}


/**
 * Process an incoming command.
 *
 * @param  string cmd    - command name
 * @param  string params - command parameters
 * @param  int    keys   - combination of pressed modifier keys
 *
 * @return bool - success status of the executed command
 */
bool onCommand(string cmd, string params, int keys) {
   if (cmd == "parameter") {
      if (params == "up")   return(ParameterStepper(STEP_UP, keys));
      if (params == "down") return(ParameterStepper(STEP_DOWN, keys));
   }
   return(!logNotice("onCommand(1)  unsupported command: "+ DoubleQuoteStr(cmd +":"+ params +":"+ keys)));
}


/**
 * Step up/down an input parameter.
 *
 * @param  int direction - STEP_UP | STEP_DOWN
 * @param  int keys      - pressed modifier keys
 *
 * @return bool - success status
 */
bool ParameterStepper(int direction, int keys) {
   if (direction!=STEP_UP && direction!=STEP_DOWN) return(!catch("ParameterStepper(1)  invalid parameter direction: "+ direction, ERR_INVALID_PARAMETER));

   if (!keys & F_VK_SHIFT) {
      // step up/down input parameter "WaveCycle.Periods"
      double step = WaveCycle.Periods.Step;

      if (!step || WaveCycle.Periods + direction*step < 3) {   // no stepping if parameter limit reached
         PlaySoundEx("Plonk.wav");
         return(false);
      }
      if (direction == STEP_UP) WaveCycle.Periods += step;
      else                      WaveCycle.Periods -= step;

      if (!NLMA.CalculateWeights(waveCycles, WaveCycle.Periods, maWeights)) return(false);
      maPeriods = ArraySize(maWeights);
   }
   else {
      // step up/down input parameter "MA.ReversalFilter"
      step = MA.ReversalFilter.Step;

      if (!step || MA.ReversalFilter + direction*step < 0) {   // no stepping if parameter limit reached
         PlaySoundEx("Plonk.wav");
         return(false);
      }
      if (direction == STEP_UP) MA.ReversalFilter += step;
      else                      MA.ReversalFilter -= step;
   }

   ChangedBars = Bars;
   ValidBars   = 0;

   PlaySoundEx("Parameter Step.wav");
   return(true);
}


/**
 * Workaround for various terminal bugs when setting indicator options. Usually options are set in init(). However after
 * recompilation options must be set in start() to not be ignored.
 */
void SetIndicatorOptions() {
   string sMaFilter     = ifString(MA.ReversalFilter || MA.ReversalFilter.Step, "/"+ NumberToStr(MA.ReversalFilter, ".1+"), "");
   string sAppliedPrice = ifString(maAppliedPrice==PRICE_CLOSE, "", ", "+ PriceTypeDescription(maAppliedPrice));
   indicatorName        = WindowExpertName() +"("+ ifString(WaveCycle.Periods.Step || MA.ReversalFilter.Step, "step:", "") + WaveCycle.Periods + sMaFilter + sAppliedPrice +")";
   shortName            = "NLMA("+ WaveCycle.Periods +")";
   IndicatorShortName(shortName);

   int draw_type = ifInt(Draw.Width, drawType, DRAW_NONE);

   IndicatorBuffers(terminal_buffers);
   SetIndexStyle(MODE_MA_FILTERED, DRAW_NONE, EMPTY, EMPTY,      CLR_NONE       );                                     SetIndexLabel(MODE_MA_FILTERED, shortName);
   SetIndexStyle(MODE_TREND,       DRAW_NONE, EMPTY, EMPTY,      CLR_NONE       );                                     SetIndexLabel(MODE_TREND,       shortName +" trend");
   SetIndexStyle(MODE_UPTREND,     draw_type, EMPTY, Draw.Width, Color.UpTrend  ); SetIndexArrow(MODE_UPTREND,   158); SetIndexLabel(MODE_UPTREND,     NULL);
   SetIndexStyle(MODE_DOWNTREND,   draw_type, EMPTY, Draw.Width, Color.DownTrend); SetIndexArrow(MODE_DOWNTREND, 158); SetIndexLabel(MODE_DOWNTREND,   NULL);
   SetIndexStyle(MODE_UPTREND2,    draw_type, EMPTY, Draw.Width, Color.UpTrend  ); SetIndexArrow(MODE_UPTREND2,  158); SetIndexLabel(MODE_UPTREND2,    NULL);
   IndicatorDigits(Digits);
}


/**
 * Store the status of an active parameter stepper in the chart (for init cyles, template reloads and/or terminal restarts).
 *
 * @return bool - success status
 */
bool StoreStatus() {
   if (__isChart && (WaveCycle.Periods.Step || MA.ReversalFilter.Step)) {
      string prefix = "rsf."+ WindowExpertName() +".";

      Chart.StoreInt   (prefix +"WaveCycle.Periods", WaveCycle.Periods);
      Chart.StoreDouble(prefix +"MA.ReversalFilter", MA.ReversalFilter);
   }
   return(catch("StoreStatus(1)"));
}


/**
 * Restore the status of the parameter stepper from the chart if it wasn't changed in between (for init cyles, template
 * reloads and/or terminal restarts).
 *
 * @return bool - success status
 */
bool RestoreStatus() {
   if (__isChart) {
      string prefix = "rsf."+ WindowExpertName() +".";

      int iValue;
      if (Chart.RestoreInt(prefix +"WaveCycle.Periods", iValue)) {
         if (WaveCycle.Periods.Step > 0) {
            if (iValue >= 3) WaveCycle.Periods = iValue;       // silent validation
         }
      }

      double dValue;
      if (Chart.RestoreDouble(prefix +"MA.ReversalFilter", dValue)) {
         if (MA.ReversalFilter.Step > 0) {
            if (dValue >= 0) MA.ReversalFilter = dValue;       // silent validation
         }
      }
   }
   return(!catch("RestoreStatus(1)"));
}


/**
 * Return a string representation of the input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("WaveCycle.Periods=",              WaveCycle.Periods,                              ";"+ NL,
                            "WaveCycle.Periods.Step=",         WaveCycle.Periods.Step,                         ";"+ NL,
                            "MA.AppliedPrice=",                DoubleQuoteStr(MA.AppliedPrice),                ";"+ NL,
                            "MA.ReversalFilter=",              NumberToStr(MA.ReversalFilter, ".1+"),          ";"+ NL,
                            "MA.ReversalFilter.Step=",         NumberToStr(MA.ReversalFilter.Step, ".1+"),     ";"+ NL,

                            "Draw.Type=",                      DoubleQuoteStr(Draw.Type),                      ";"+ NL,
                            "Draw.Width=",                     Draw.Width,                                     ";"+ NL,
                            "Color.UpTrend=",                  ColorToStr(Color.UpTrend),                      ";"+ NL,
                            "Color.DownTrend=",                ColorToStr(Color.DownTrend),                    ";"+ NL,
                            "MaxBarsBack=",                    MaxBarsBack,                                    ";"+ NL,

                            "Signal.onTrendChange=",           BoolToStr(Signal.onTrendChange),                ";"+ NL,
                            "Signal.onTrendChange.Sound=",     BoolToStr(Signal.onTrendChange.Sound),          ";"+ NL,
                            "Signal.onTrendChange.SoundUp=",   DoubleQuoteStr(Signal.onTrendChange.SoundUp),   ";"+ NL,
                            "Signal.onTrendChange.SoundDown=", DoubleQuoteStr(Signal.onTrendChange.SoundDown), ";"+ NL,
                            "Signal.onTrendChange.Alert=",     BoolToStr(Signal.onTrendChange.Alert),          ";"+ NL,
                            "Signal.onTrendChange.Mail=",      BoolToStr(Signal.onTrendChange.Mail),           ";"+ NL,
                            "Signal.onTrendChange.SMS=",       BoolToStr(Signal.onTrendChange.SMS),            ";")
   );
}
