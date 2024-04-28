/**
 * Arnaud Legoux Moving Average
 *
 * A moving average using a Gaussian distribution function for weight calculation.
 *
 *
 * Indicator buffers for iCustom():
 *  • MovingAverage.MODE_MA:    MA values
 *  • MovingAverage.MODE_TREND: trend direction and length
 *    - trend direction:        positive values denote an uptrend (+1...+n), negative values denote a downtrend (-1...-n)
 *    - trend length:           the absolute value of the direction is the trend length in bars since the last reversal
 *
 *
 *  @see  http://web.archive.org/web/20180307031850/http://www.arnaudlegoux.com/#              [Arnaud Legoux Moving Average]
 *  @see  https://www.forexfactory.com/thread/251668#                                          [Arnaud Legoux Moving Average]
 */
#include <stddefines.mqh>
int   __InitFlags[];
int __DeinitFlags[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern int    MA.Periods                     = 38;
extern int    MA.Periods.Step                = 0;                 // step size for a stepped input parameter (hotkey)
extern string MA.AppliedPrice                = "Open | High | Low | Close* | Median | Typical | Weighted";
extern double Distribution.Offset            = 0.85;              // Gaussian distribution offset (offset of parabola vertex: 0..1)
extern double Distribution.Sigma             = 6.0;               // Gaussian distribution sigma (parabola steepness)
extern double MA.ReversalFilter              = 0.4;               // min. MA change in std-deviations for a trend reversal
extern double MA.ReversalFilter.Step         = 0;                 // step size for a stepped input parameter (hotkey + VK_SHIFT)

extern string Draw.Type                      = "Line* | Dot";
extern int    Draw.Width                     = 3;
extern color  Color.UpTrend                  = Blue;
extern color  Color.DownTrend                = Red;
extern bool   ShowChartLegend                = true;
extern int    MaxBarsBack                    = 10000;             // max. values to calculate (-1: all available)

extern string ___a__________________________ = "=== Signaling ===";
extern bool   Signal.onTrendChange           = false;
extern string Signal.onTrendChange.Types     = "sound* | alert | mail | sms";
extern string Signal.Sound.Up                = "Signal Up.wav";
extern string Signal.Sound.Down              = "Signal Down.wav";

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <rsfLib.mqh>
#include <functions/chartlegend.mqh>
#include <functions/ConfigureSignals.mqh>
#include <functions/HandleCommands.mqh>
#include <functions/IsBarOpen.mqh>
#include <functions/ObjectCreateRegister.mqh>
#include <functions/trend.mqh>
#include <functions/ta/ALMA.mqh>
#include <win32api.mqh>

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
double maAverage [];                                     // average of maChange[] over the last 'MA.Periods' bars

int    maAppliedPrice;
double maWeights[];                                      // bar weighting of the MA
int    drawType;

string indicatorName = "";
string shortName     = "";
string legendLabel   = "";
string legendInfo    = "";                               // additional chart legend info
bool   enableMultiColoring;

bool   signal.sound;
bool   signal.alert;
bool   signal.mail;
bool   signal.sms;

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

   // MA.Periods
   if (AutoConfiguration) MA.Periods = GetConfigInt(indicator, "MA.Periods", MA.Periods);
   if (MA.Periods < 1)                                     return(catch("onInit(1)  invalid input parameter MA.Periods: "+ MA.Periods, ERR_INVALID_INPUT_PARAMETER));
   // MA.Periods.Step
   if (AutoConfiguration) MA.Periods.Step = GetConfigInt(indicator, "MA.Periods.Step", MA.Periods.Step);
   if (MA.Periods.Step < 0)                                return(catch("onInit(2)  invalid input parameter MA.Periods.Step: "+ MA.Periods.Step +" (must be >= 0)", ERR_INVALID_INPUT_PARAMETER));
   // MA.AppliedPrice
   string sValues[], sValue = MA.AppliedPrice;
   if (AutoConfiguration) sValue = GetConfigString(indicator, "MA.AppliedPrice", sValue);
   if (Explode(sValue, "*", sValues, 2) > 1) {
      int size = Explode(sValues[0], "|", sValues, NULL);
      sValue = sValues[size-1];
   }
   sValue = StrTrim(sValue);
   maAppliedPrice = StrToPriceType(sValue, F_PARTIAL_ID|F_ERR_INVALID_PARAMETER);
   if (maAppliedPrice == -1)                               return(catch("onInit(3)  invalid input parameter MA.AppliedPrice: "+ DoubleQuoteStr(sValue), ERR_INVALID_INPUT_PARAMETER));
   MA.AppliedPrice = PriceTypeDescription(maAppliedPrice);
   // Distribution.Offset
   if (AutoConfiguration) Distribution.Offset = GetConfigDouble(indicator, "Distribution.Offset", Distribution.Offset);
   if (Distribution.Offset < 0 || Distribution.Offset > 1) return(catch("onInit(4)  invalid input parameter Distribution.Offset: "+ NumberToStr(Distribution.Offset, ".1+") +" (must be from 0 to 1)", ERR_INVALID_INPUT_PARAMETER));
   // Distribution.Sigma
   if (AutoConfiguration) Distribution.Sigma = GetConfigDouble(indicator, "Distribution.Sigma", Distribution.Sigma);
   if (Distribution.Sigma <= 0)                            return(catch("onInit(5)  invalid input parameter Distribution.Sigma: "+ NumberToStr(Distribution.Sigma, ".1+") +" (must be positive)", ERR_INVALID_INPUT_PARAMETER));
   // MA.ReversalFilter
   if (AutoConfiguration) MA.ReversalFilter = GetConfigDouble(indicator, "MA.ReversalFilter", MA.ReversalFilter);
   if (MA.ReversalFilter < 0)                              return(catch("onInit(6)  invalid input parameter MA.ReversalFilter: "+ NumberToStr(MA.ReversalFilter, ".1+") +" (must be >= 0)", ERR_INVALID_INPUT_PARAMETER));
   // MA.ReversalFilter.StepS
   if (AutoConfiguration) MA.ReversalFilter.Step = GetConfigDouble(indicator, "MA.ReversalFilter.Step", MA.ReversalFilter.Step);
   if (MA.ReversalFilter.Step < 0)                         return(catch("onInit(7)  invalid input parameter MA.ReversalFilter.Step: "+ NumberToStr(MA.ReversalFilter.Step, ".1+") +" (must be >= 0)", ERR_INVALID_INPUT_PARAMETER));
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
   else                                                    return(catch("onInit(8)  invalid input parameter Draw.Type: "+ DoubleQuoteStr(sValue), ERR_INVALID_INPUT_PARAMETER));
   // Draw.Width
   if (AutoConfiguration) Draw.Width = GetConfigInt(indicator, "Draw.Width", Draw.Width);
   if (Draw.Width < 0)                                     return(catch("onInit(9)  invalid input parameter Draw.Width: "+ Draw.Width, ERR_INVALID_INPUT_PARAMETER));
   // colors: after deserialization the terminal might turn CLR_NONE (0xFFFFFFFF) into Black (0xFF000000)
   if (AutoConfiguration) Color.UpTrend   = GetConfigColor(indicator, "Color.UpTrend",   Color.UpTrend  );
   if (AutoConfiguration) Color.DownTrend = GetConfigColor(indicator, "Color.DownTrend", Color.DownTrend);
   if (Color.UpTrend   == 0xFF000000) Color.UpTrend   = CLR_NONE;
   if (Color.DownTrend == 0xFF000000) Color.DownTrend = CLR_NONE;
   // ShowChartLegend
   if (AutoConfiguration) ShowChartLegend = GetConfigBool(indicator, "ShowChartLegend", ShowChartLegend);
   // MaxBarsBack
   if (AutoConfiguration) MaxBarsBack = GetConfigInt(indicator, "MaxBarsBack", MaxBarsBack);
   if (MaxBarsBack < -1)                                   return(catch("onInit(10)  invalid input parameter MaxBarsBack: "+ MaxBarsBack, ERR_INVALID_INPUT_PARAMETER));
   if (MaxBarsBack == -1) MaxBarsBack = INT_MAX;

   // signal configuration
   string signalId = "Signal.onTrendChange";
   legendInfo = "";
   if (!ConfigureSignals(signalId, AutoConfiguration, Signal.onTrendChange)) return(last_error);
   if (Signal.onTrendChange) {
      if (!ConfigureSignalTypes(signalId, Signal.onTrendChange.Types, AutoConfiguration, signal.sound, signal.alert, signal.mail, signal.sms)) {
         return(catch("onInit(11)  invalid input parameter Signal.onTrendChange.Types: "+ DoubleQuoteStr(Signal.onTrendChange.Types), ERR_INVALID_INPUT_PARAMETER));
      }
      Signal.onTrendChange = (signal.sound || signal.alert || signal.mail || signal.sms);
      if (Signal.onTrendChange) legendInfo = "("+ StrLeft(ifString(signal.sound, "sound,", "") + ifString(signal.alert, "alert,", "") + ifString(signal.mail, "mail,", "") + ifString(signal.sms, "sms,", ""), -1) +")";
   }
   // Signal.Sound.*
   if (AutoConfiguration) Signal.Sound.Up   = GetConfigString(indicator, "Signal.Sound.Up",   Signal.Sound.Up);
   if (AutoConfiguration) Signal.Sound.Down = GetConfigString(indicator, "Signal.Sound.Down", Signal.Sound.Down);

   // reset an active command handler
   if (__isChart && (MA.Periods.Step || MA.ReversalFilter.Step)) {
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

   // calculate ALMA bar weights
   ALMA.CalculateWeights(MA.Periods, Distribution.Offset, Distribution.Sigma, maWeights);

   // chart legend and coloring
   if (ShowChartLegend) legendLabel = CreateChartLegend();
   enableMultiColoring = !__isSuperContext;

   return(catch("onInit(12)"));
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
   if (__isChart && (MA.Periods.Step || MA.ReversalFilter.Step)) {
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
   int startbar = Min(MaxBarsBack-1, ChangedBars-1, Bars-MA.Periods);
   if (startbar < 0 && MaxBarsBack) return(logInfo("onTick(2)  Tick="+ Ticks +"  Bars="+ Bars +"  needed="+ MA.Periods, ERR_HISTORY_INSUFFICIENT));

   double sum, stdDev, minChange;

   // recalculate changed bars
   for (int bar=startbar; bar >= 0; bar--) {
      maRaw[bar] = 0;
      for (int i=0; i < MA.Periods; i++) {
         maRaw[bar] += maWeights[i] * iMA(NULL, NULL, 1, 0, MODE_SMA, maAppliedPrice, bar+i);
      }
      maFiltered[bar] = maRaw[bar];

      if (MA.ReversalFilter > 0) {
         maChange[bar] = maFiltered[bar] - maFiltered[bar+1];        // calculate the change of current raw to previous filtered MA
         sum = 0;
         for (i=0; i < MA.Periods; i++) {                            // calculate average(change) over last 'MA.Periods'
            sum += maChange[bar+i];
         }
         maAverage[bar] = sum/MA.Periods;

         if (maChange[bar] * trend[bar+1] < 0) {                     // on opposite signs = trend reversal
            sum = 0;                                                 // calculate stdDeviation(maChange[]) over last 'MA.Periods'
            for (i=0; i < MA.Periods; i++) {
               sum += MathPow(maChange[bar+i] - maAverage[bar+i], 2);
            }
            stdDev = MathSqrt(sum/MA.Periods);
            minChange = MA.ReversalFilter * stdDev;                  // calculate required min. change

            if (MathAbs(maChange[bar]) < minChange) {
               maFiltered[bar] = maFiltered[bar+1];                  // discard trend reversal if MA change is smaller
            }
         }
      }
      UpdateTrendDirection(maFiltered, bar, trend, uptrend, downtrend, uptrend2, enableMultiColoring, enableMultiColoring, drawType, Digits);
   }

   if (!__isSuperContext) {
      if (__isChart && ShowChartLegend) UpdateTrendLegend(legendLabel, indicatorName, legendInfo, Color.UpTrend, Color.DownTrend, maFiltered[0], trend[0]);

      if (Signal.onTrendChange) /*&&*/ if (IsBarOpen()) {            // monitor trend reversals
         int iTrend = Round(trend[1]);
         if      (iTrend ==  1) onTrendChange(MODE_UPTREND);
         else if (iTrend == -1) onTrendChange(MODE_DOWNTREND);
      }
   }
   return(last_error);

   // Speed test on Toshiba Satellite
   // -----------------------------------------------------------------------------------------------------
   // ALMA(7xD1) on H1  = ALMA(168)      weights(  168)=0.009 sec   bars(2000)=0.110 sec   loops=   336,000
   // ALMA(7xD1) on M30 = ALMA(336)      weights(  336)=0.009 sec   bars(2000)=0.250 sec   loops=   672,000
   // ALMA(7xD1) on M15 = ALMA(672)      weights(  672)=0.009 sec   bars(2000)=0.453 sec   loops= 1,344,000
   // ALMA(7xD1) on M5  = ALMA(2016)     weights( 2016)=0.016 sec   bars(2000)=1.547 sec   loops= 4,032,000
   // ALMA(7xD1) on M1  = ALMA(10080)    weights(10080)=0.016 sec   bars(2000)=7.110 sec   loops=20,160,000
   //
   // Speed test on Toshiba Portege
   // -----------------------------------------------------------------------------------------------------
   // as above            ALMA(168)      as above                   bars(2000)=0.078 sec   as above
   // ...                 ALMA(336)      ...                        bars(2000)=0.156 sec   ...
   // ...                 ALMA(672)      ...                        bars(2000)=0.312 sec   ...
   // ...                 ALMA(2016)     ...                        bars(2000)=0.952 sec   ...
   // ...                 ALMA(10080)    ...                        bars(2000)=4.773 sec   ...
   //
   // Speed test on Dell Precision
   // -----------------------------------------------------------------------------------------------------
   // as above            ALMA(168)      as above                   bars(2000)=0.062 sec   as above
   // ...                 ALMA(336)      ...                        bars(2000)=0.109 sec   ...
   // ...                 ALMA(672)      ...                        bars(2000)=0.218 sec   ...
   // ...                 ALMA(2016)     ...                        bars(2000)=0.671 sec   ...
   // ...                 ALMA(10080)    ...                        bars(2000)=3.323 sec   ...
   //                     ALMA(38/0.7)   ...                       bars(10000)=?     sec   loops=  380,000
   //                     ALMA(38/0.7)   ...                       bars(60000)=?     sec   loops=2,280,000
   //                     ALMA(38/0.7)   ...                      bars(240000)=?     sec   loops=9,120,000

   // Speed test on Dell Precision
   // -----------------------------------------------------------------------------------------------------
   //                     NLMA(34/0.7)   weights(169)               bars(2000)=0.062 sec   as above            ...
   //                     NLMA(68/0.7)   weights(339)               bars(2000)=0.125 sec   ...
   //                     NLMA(135/0.7)  weights(674)               bars(2000)=0.234 sec   ...
   //                     NLMA(404/0.7)  weights(2019)              bars(2000)=0.733 sec   ...
   //                     NLMA(2016/0.7) weights(10079)             bars(2000)=3.557 sec   ...
   //                     NLMA(20/0.7)   weights(99)               bars(10000)=0.187 sec   loops=   990,000
   //                     NLMA(20/0.7)   weights(99)               bars(60000)=0.904 sec   loops= 5,940,000
   //                     NLMA(20/0.7)   weights(99)              bars(240000)=3.448 sec   loops=23,760,000

   // Conclusion: Weight calculation can be ignored, bottleneck is the nested loop in MA calculation.
}


/**
 * Event handler for trend changes.
 *
 * @param  int direction - direction
 *
 * @return bool - success status
 */
bool onTrendChange(int direction) {
   if (direction!=MODE_UPTREND && direction!=MODE_DOWNTREND) return(!catch("onTrendChange(1)  invalid parameter direction: "+ direction, ERR_INVALID_PARAMETER));

   // skip the signal if it was already signaled elsewhere
   int hWnd = ifInt(__isTesting, __ExecutionContext[EC.hChart], GetDesktopWindow());
   string sPeriod = PeriodDescription();
   string sName   = "ALMA("+ MA.Periods +", "+ PriceTypeDescription(maAppliedPrice) +")";
   string sEvent  = "rsf::"+ StdSymbol() +","+ sPeriod +"."+ sName +".onTrendChange("+ direction +")."+ TimeToStr(Time[0]);
   if (GetPropA(hWnd, sEvent) != 0) return(true);
   SetPropA(hWnd, sEvent, 1);                         // immediately mark as signaled (prevents duplicate signals on slow CPU)

   string message = shortName +" turned "+ ifString(direction==MODE_UPTREND, "up", "down") +" (bid: "+ NumberToStr(_Bid, PriceFormat) +")";
   if (IsLogInfo()) logInfo("onTrendChange(2)  "+ message);

   message = Symbol() +","+ PeriodDescription() +": "+ message;
   string sAccount = "("+ TimeToStr(TimeLocalEx("onTrendChange(3)"), TIME_MINUTES|TIME_SECONDS) +", "+ GetAccountAlias() +")";
   int error = NO_ERROR;

   if (signal.alert)          Alert(message);
   if (signal.sound) error  = PlaySoundEx(ifString(direction==MODE_UPTREND, Signal.Sound.Up, Signal.Sound.Down)); if (error == ERR_FILE_NOT_FOUND) signal.sound = false;
   if (signal.mail)  error |= !SendEmail("", "", message, message + NL + sAccount);
   if (signal.sms)   error |= !SendSMS("", message + NL + sAccount);
   return(!error);
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
      // step up/down input parameter "MA.Periods"
      double step = MA.Periods.Step;

      if (!step || MA.Periods + direction*step < 1) {          // no stepping if parameter limit reached
         PlaySoundEx("Plonk.wav");
         return(false);
      }
      if (direction == STEP_UP) MA.Periods += step;
      else                      MA.Periods -= step;

      if (!ALMA.CalculateWeights(MA.Periods, Distribution.Offset, Distribution.Sigma, maWeights)) return(false);
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
   indicatorName        = WindowExpertName() +"("+ ifString(MA.Periods.Step || MA.ReversalFilter.Step, "step:", "") + MA.Periods + sMaFilter + sAppliedPrice +")";
   shortName            = "ALMA("+ MA.Periods +")";
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
   if (__isChart && (MA.Periods.Step || MA.ReversalFilter.Step)) {
      string prefix = "rsf."+ WindowExpertName() +".";

      Chart.StoreInt   (prefix +"MA.Periods",        MA.Periods);
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
      if (Chart.RestoreInt(prefix +"MA.Periods", iValue)) {
         if (MA.Periods.Step > 0) {
            if (iValue >= 1) MA.Periods = iValue;              // silent validation
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
   return(StringConcatenate("MA.Periods=",                 MA.Periods,                                 ";"+ NL,
                            "MA.Periods.Step=",            MA.Periods.Step,                            ";"+ NL,
                            "MA.AppliedPrice=",            DoubleQuoteStr(MA.AppliedPrice),            ";"+ NL,
                            "Distribution.Offset=",        NumberToStr(Distribution.Offset, ".1+"),    ";"+ NL,
                            "Distribution.Sigma=",         NumberToStr(Distribution.Sigma, ".1+"),     ";"+ NL,
                            "MA.ReversalFilter=",          NumberToStr(MA.ReversalFilter, ".1+"),      ";"+ NL,
                            "MA.ReversalFilter.Step=",     NumberToStr(MA.ReversalFilter.Step, ".1+"), ";"+ NL,

                            "Draw.Type=",                  DoubleQuoteStr(Draw.Type),                  ";"+ NL,
                            "Draw.Width=",                 Draw.Width,                                 ";"+ NL,
                            "Color.DownTrend=",            ColorToStr(Color.DownTrend),                ";"+ NL,
                            "Color.UpTrend=",              ColorToStr(Color.UpTrend),                  ";"+ NL,
                            "ShowChartLegend=",            BoolToStr(ShowChartLegend),                 ";"+ NL,
                            "MaxBarsBack=",                MaxBarsBack,                                ";"+ NL,

                            "Signal.onTrendChange=",       BoolToStr(Signal.onTrendChange),            ";"+ NL,
                            "Signal.onTrendChange.Types=", DoubleQuoteStr(Signal.onTrendChange.Types), ";"+ NL,
                            "Signal.Sound.Up=",            DoubleQuoteStr(Signal.Sound.Up),            ";"+ NL,
                            "Signal.Sound.Down=",          DoubleQuoteStr(Signal.Sound.Down),          ";")
   );
}
