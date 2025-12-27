/**
 * Arnaud Legoux Moving Average
 *
 * A moving average using a Gaussian distribution function for weight calculations.
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
 */
#include <rsf/stddefines.mqh>
int   __InitFlags[];
int __DeinitFlags[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern int    MA.Periods                     = 38;
extern int    MA.Periods.Step                = 0;                 // step size for a stepped input parameter (hotkey)
extern string MA.AppliedPrice                = "Open | High | Low | Close* | Median | Typical | Weighted";
extern double Distribution.Offset            = 0.85;              // Gaussian distribution offset (offset of parabola vertex: 0..1)
extern double Distribution.Sigma             = 6.0;               // Gaussian distribution sigma (parabola steepness)
extern double MA.ReversalFilter.StdDev       = 0.1;               // min. MA change in std-deviations for a trend reversal
extern double MA.ReversalFilter.Step         = 0;                 // step size for a stepped input parameter (hotkey + VK_SHIFT)

extern string Draw.Type                      = "Line* | Dot";
extern int    Draw.Width                     = 3;
extern color  UpTrend.Color                  = DeepSkyBlue;
extern color  DownTrend.Color                = Yellow;
extern color  Background.Color               = DarkGray;          // background for Draw.Type = "Line"
extern int    Background.Width               = 2;
extern bool   ShowChartLegend                = true;
extern int    MaxBarsBack                    = 10000;             // max. values to calculate (-1: all available)

extern string ___a__________________________ = "=== Signaling ===";
extern bool   Signal.onTrendChange           = false;
extern string Signal.onTrendChange.Types     = "sound* | alert | mail";
extern string Signal.Sound.Up                = "Signal Up.wav";
extern string Signal.Sound.Down              = "Signal Down.wav";

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <rsf/core/indicator.mqh>
#include <rsf/stdfunctions.mqh>
#include <rsf/stdlib.mqh>
#include <rsf/functions/chartlegend.mqh>
#include <rsf/functions/ConfigureSignals.mqh>
#include <rsf/functions/HandleCommands.mqh>
#include <rsf/functions/IsBarOpen.mqh>
#include <rsf/functions/ObjectCreateRegister.mqh>
#include <rsf/functions/trend.mqh>
#include <rsf/functions/ta/ALMA.mqh>
#include <rsf/win32api.mqh>

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
double maFiltered[];                                     // MA filtered main values: visible (background), displayed in legend and "Data" window
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
   // MA.ReversalFilter.StdDev
   if (AutoConfiguration) MA.ReversalFilter.StdDev = GetConfigDouble(indicator, "MA.ReversalFilter.StdDev", MA.ReversalFilter.StdDev);
   if (MA.ReversalFilter.StdDev < 0)                       return(catch("onInit(6)  invalid input parameter MA.ReversalFilter.StdDev: "+ NumberToStr(MA.ReversalFilter.StdDev, ".1+") +" (must be >= 0)", ERR_INVALID_INPUT_PARAMETER));
   // MA.ReversalFilter.Step
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
   // Background.Width
   if (AutoConfiguration) Background.Width = GetConfigInt(indicator, "Background.Width", Background.Width);
   if (Background.Width < 0)                               return(catch("onInit(10)  invalid input parameter Background.Width: "+ Background.Width +" (must be >= 0)", ERR_INVALID_INPUT_PARAMETER));
   // colors: after deserialization the terminal might turn CLR_NONE (0xFFFFFFFF) into Black (0xFF000000)
   if (AutoConfiguration) UpTrend.Color    = GetConfigColor(indicator, "UpTrend.Color",    UpTrend.Color);
   if (AutoConfiguration) DownTrend.Color  = GetConfigColor(indicator, "DownTrend.Color",  DownTrend.Color);
   if (AutoConfiguration) Background.Color = GetConfigColor(indicator, "Background.Color", Background.Color);
   if (UpTrend.Color    == 0xFF000000) UpTrend.Color    = CLR_NONE;
   if (DownTrend.Color  == 0xFF000000) DownTrend.Color  = CLR_NONE;
   if (Background.Color == 0xFF000000) Background.Color = CLR_NONE;
   // ShowChartLegend
   if (AutoConfiguration) ShowChartLegend = GetConfigBool(indicator, "ShowChartLegend", ShowChartLegend);
   // MaxBarsBack
   if (AutoConfiguration) MaxBarsBack = GetConfigInt(indicator, "MaxBarsBack", MaxBarsBack);
   if (MaxBarsBack < -1)                                   return(catch("onInit(11)  invalid input parameter MaxBarsBack: "+ MaxBarsBack, ERR_INVALID_INPUT_PARAMETER));
   if (MaxBarsBack == -1) MaxBarsBack = INT_MAX;

   // signal configuration
   string signalId = "Signal.onTrendChange";
   legendInfo = "";
   if (!ConfigureSignals(signalId, AutoConfiguration, Signal.onTrendChange)) return(last_error);
   if (Signal.onTrendChange) {
      if (!ConfigureSignalTypes(signalId, Signal.onTrendChange.Types, AutoConfiguration, signal.sound, signal.alert, signal.mail)) {
         return(catch("onInit(12)  invalid input parameter Signal.onTrendChange.Types: "+ DoubleQuoteStr(Signal.onTrendChange.Types), ERR_INVALID_INPUT_PARAMETER));
      }
      Signal.onTrendChange = (signal.sound || signal.alert || signal.mail);
      if (Signal.onTrendChange) legendInfo = "("+ StrLeft(ifString(signal.sound, "sound,", "") + ifString(signal.alert, "alert,", "") + ifString(signal.mail, "mail,", ""), -1) +")";
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

   // calculate ALMA bar weights
   ALMA.CalculateWeights(MA.Periods, Distribution.Offset, Distribution.Sigma, maWeights);

   // chart legend and coloring
   if (ShowChartLegend) legendLabel = CreateChartLegend();
   enableMultiColoring = !__isSuperContext;

   SetIndicatorOptions();
   return(catch("onInit(13)"));
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
   if (startbar < 0 && MaxBarsBack) return(logInfo("onTick(1)  Tick="+ Ticks +"  Bars="+ Bars +"  needed="+ MA.Periods, ERR_HISTORY_INSUFFICIENT));

   double sum, stdDev, minChange;

   // recalculate changed bars
   for (int bar=startbar; bar >= 0; bar--) {
      maRaw[bar] = 0;
      for (int i=0; i < MA.Periods; i++) {
         maRaw[bar] += maWeights[i] * iMA(NULL, NULL, 1, 0, MODE_SMA, maAppliedPrice, bar+i);
      }
      maFiltered[bar] = maRaw[bar];

      if (MA.ReversalFilter.StdDev > 0) {
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
            minChange = MA.ReversalFilter.StdDev * stdDev;           // calculate required min. change

            if (MathAbs(maChange[bar]) < minChange) {
               maFiltered[bar] = maFiltered[bar+1];                  // discard trend reversal if MA change is smaller
            }
         }
      }
      UpdateTrend(maFiltered, bar, trend, uptrend, downtrend, uptrend2, enableMultiColoring, enableMultiColoring, drawType, Digits);
   }

   if (!__isSuperContext) {
      if (__isChart && ShowChartLegend) UpdateTrendLegend(legendLabel, indicatorName, legendInfo, UpTrend.Color, DownTrend.Color, maFiltered[0], trend[0]);

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
   //
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
   //
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

   // skip the signal if it was already processed elsewhere
   string sPeriod   = PeriodDescription();
   string eventName = "rsf::"+ StdSymbol() +","+ sPeriod +".ALMA("+ MA.Periods +", "+ PriceTypeDescription(maAppliedPrice) +").onTrendChange("+ direction +")."+ TimeToStr(Time[0]), propertyName = "";
   string message1  = shortName +" turned "+ ifString(direction==MODE_UPTREND, "up", "down") +" (bid: "+ NumberToStr(_Bid, PriceFormat) +")";
   string message2  = Symbol() +","+ sPeriod +": "+ message1;

   int hWndTerminal=GetTerminalMainWindow(), hWndDesktop=GetDesktopWindow();
   bool eventAction;

   // log: once per terminal
   if (IsLogInfo()) {
      eventAction = true;
      if (!__isTesting) {
         propertyName = eventName +"|log";
         eventAction = !GetWindowPropertyA(hWndTerminal, propertyName);
         SetWindowPropertyA(hWndTerminal, propertyName, 1);
      }
      if (eventAction) logInfo("onTrendChange(2)  "+ message1);
   }

   // sound: once per system
   if (signal.sound) {
      eventAction = true;
      if (!__isTesting) {
         propertyName = eventName +"|sound";
         eventAction = !GetWindowPropertyA(hWndDesktop, propertyName);
         SetWindowPropertyA(hWndDesktop, propertyName, 1);
      }
      if (eventAction) PlaySoundEx(ifString(direction==MODE_UPTREND, Signal.Sound.Up, Signal.Sound.Down));
   }

   // alert: once per terminal
   if (signal.alert) {
      eventAction = true;
      if (!__isTesting) {
         propertyName = eventName +"|alert";
         eventAction = !GetWindowPropertyA(hWndTerminal, propertyName);
         SetWindowPropertyA(hWndTerminal, propertyName, 1);
      }
      if (eventAction) Alert(message2);
   }

   // mail: once per system
   if (signal.mail) {
      eventAction = true;
      if (!__isTesting) {
         propertyName = eventName +"|mail";
         eventAction = !GetWindowPropertyA(hWndDesktop, propertyName);
         SetWindowPropertyA(hWndDesktop, propertyName, 1);
      }
      if (eventAction) SendEmail("", "", message2, message2 + NL + "("+ TimeToStr(TimeLocalEx("onReversal(3)"), TIME_MINUTES|TIME_SECONDS) +", "+ GetAccountAlias() +")");
   }
   return(!catch("onTrendChange(4)"));
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
      int step = MA.Periods.Step;

      if (!step || MA.Periods + direction*step < 1) {                   // stop if parameter limit reached
         PlaySoundEx("Plonk.wav");
         return(false);
      }
      if (direction == STEP_UP) MA.Periods += step;
      else                      MA.Periods -= step;

      if (!ALMA.CalculateWeights(MA.Periods, Distribution.Offset, Distribution.Sigma, maWeights)) return(false);
   }
   else {
      // step up/down input parameter "MA.ReversalFilter"
      double dStep = MA.ReversalFilter.Step;

      if (!dStep || MA.ReversalFilter.StdDev + direction*dStep < 0) {   // stop if parameter limit reached
         PlaySoundEx("Plonk.wav");
         return(false);
      }
      if (direction == STEP_UP) MA.ReversalFilter.StdDev += dStep;
      else                      MA.ReversalFilter.StdDev -= dStep;
   }

   ChangedBars = Bars;
   ValidBars   = 0;

   PlaySoundEx("Parameter Step.wav");
   return(true);
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

   string sMaFilter     = ifString(MA.ReversalFilter.StdDev || MA.ReversalFilter.Step, "/"+ NumberToStr(MA.ReversalFilter.StdDev, ".1+"), "");
   string sAppliedPrice = ifString(maAppliedPrice==PRICE_CLOSE, "", ", "+ PriceTypeDescription(maAppliedPrice));
   indicatorName        = WindowExpertName() +"("+ ifString(MA.Periods.Step || MA.ReversalFilter.Step, "step:", "") + MA.Periods + sMaFilter + sAppliedPrice +")";
   shortName            = "ALMA("+ MA.Periods +")";
   IndicatorShortName(shortName);

   IndicatorBuffers(terminal_buffers);
   SetIndexBuffer(MODE_MA_RAW,      maRaw     );   // MA raw main values:      invisible
   SetIndexBuffer(MODE_MA_FILTERED, maFiltered);   // MA filtered main values: visible as background, displayed in legend and "Data" window
   SetIndexBuffer(MODE_TREND,       trend     );   // trend direction:         invisible, displayed in "Data" window
   SetIndexBuffer(MODE_UPTREND,     uptrend   );   // uptrend values:          visible
   SetIndexBuffer(MODE_DOWNTREND,   downtrend );   // downtrend values:        visible
   SetIndexBuffer(MODE_UPTREND2,    uptrend2  );   // single-bar uptrends:     visible
   SetIndexBuffer(MODE_MA_CHANGE,   maChange  );   //                          invisible
   SetIndexBuffer(MODE_AVG,         maAverage );   //                          invisible
   IndicatorDigits(Digits);

   int draw_type = ifInt(drawType==DRAW_LINE, drawType, DRAW_NONE);
   SetIndexStyle(MODE_MA_FILTERED, draw_type, EMPTY, Draw.Width+Background.Width, Background.Color);

   draw_type = ifInt(Draw.Width, drawType, DRAW_NONE);
   SetIndexStyle(MODE_TREND,       DRAW_NONE, EMPTY, EMPTY,      CLR_NONE       );
   SetIndexStyle(MODE_UPTREND,     draw_type, EMPTY, Draw.Width, UpTrend.Color  ); SetIndexArrow(MODE_UPTREND,   158);
   SetIndexStyle(MODE_DOWNTREND,   draw_type, EMPTY, Draw.Width, DownTrend.Color); SetIndexArrow(MODE_DOWNTREND, 158);
   SetIndexStyle(MODE_UPTREND2,    draw_type, EMPTY, Draw.Width, UpTrend.Color  ); SetIndexArrow(MODE_UPTREND2,  158);

   SetIndexLabel(MODE_MA_FILTERED, shortName);
   SetIndexLabel(MODE_TREND,       shortName +" trend");
   SetIndexLabel(MODE_UPTREND,     shortName +" up");
   SetIndexLabel(MODE_DOWNTREND,   shortName +" down");
   SetIndexLabel(MODE_UPTREND2,    NULL);

   if (redraw) WindowRedraw();
   return(!catch("SetIndicatorOptions(1)"));
}


/**
 * Store the status of the parameter stepper in the chart (for init cyles, template reloads or terminal restarts).
 *
 * @return bool - success status
 */
bool StoreStatus() {
   if (__isChart && (MA.Periods.Step || MA.ReversalFilter.Step)) {
      string prefix = "rsf."+ WindowExpertName() +".";

      Chart.StoreInt   (prefix +"MA.Periods",               MA.Periods);
      Chart.StoreDouble(prefix +"MA.ReversalFilter.StdDev", MA.ReversalFilter.StdDev);
   }
   return(catch("StoreStatus(1)"));
}


/**
 * Restore the status of the parameter stepper from the chart.
 *
 * @return bool - success status
 */
bool RestoreStatus() {
   if (!__isChart) return(true);
   string prefix = "rsf."+ WindowExpertName() +".";

   int iValue;
   if (Chart.RestoreInt(prefix +"MA.Periods", iValue)) {             // restore and remove it
      if (MA.Periods.Step > 0) {                                     // apply if stepper is still active
         if (iValue > 0) MA.Periods = iValue;                        // silent validation
      }
   }

   double dValue;
   if (Chart.RestoreDouble(prefix +"MA.ReversalFilter", dValue)) {   // restore and remove it
      if (MA.ReversalFilter.Step > 0) {                              // apply if stepper is still active
         if (dValue >= 0) MA.ReversalFilter.StdDev = dValue;         // silent validation
      }
   }
   return(!catch("RestoreStatus(1)"));
}


/**
 * Return a string representation of all input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("MA.Periods=",                 MA.Periods,                                   ";"+ NL,
                            "MA.Periods.Step=",            MA.Periods.Step,                              ";"+ NL,
                            "MA.AppliedPrice=",            DoubleQuoteStr(MA.AppliedPrice),              ";"+ NL,
                            "Distribution.Offset=",        NumberToStr(Distribution.Offset, ".1+"),      ";"+ NL,
                            "Distribution.Sigma=",         NumberToStr(Distribution.Sigma, ".1+"),       ";"+ NL,
                            "MA.ReversalFilter.StdDev=",   NumberToStr(MA.ReversalFilter.StdDev, ".1+"), ";"+ NL,
                            "MA.ReversalFilter.Step=",     NumberToStr(MA.ReversalFilter.Step, ".1+"),   ";"+ NL,

                            "Draw.Type=",                  DoubleQuoteStr(Draw.Type),                    ";"+ NL,
                            "Draw.Width=",                 Draw.Width,                                   ";"+ NL,
                            "UpTrend.Color=",              ColorToStr(UpTrend.Color),                    ";"+ NL,
                            "DownTrend.Color=",            ColorToStr(DownTrend.Color),                  ";"+ NL,
                            "Background.Color=",           ColorToStr(Background.Color),                 ";", NL,
                            "Background.Width=",           Background.Width,                             ";", NL,
                            "ShowChartLegend=",            BoolToStr(ShowChartLegend),                   ";"+ NL,
                            "MaxBarsBack=",                MaxBarsBack,                                  ";"+ NL,

                            "Signal.onTrendChange=",       BoolToStr(Signal.onTrendChange),              ";"+ NL,
                            "Signal.onTrendChange.Types=", DoubleQuoteStr(Signal.onTrendChange.Types),   ";"+ NL,
                            "Signal.Sound.Up=",            DoubleQuoteStr(Signal.Sound.Up),              ";"+ NL,
                            "Signal.Sound.Down=",          DoubleQuoteStr(Signal.Sound.Down),            ";")
   );
}
