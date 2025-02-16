/**
 * T3 Moving Average by Tim Tillson
 *
 * The T3 is a six-pole nonlinear Kalman filter. Kalman filters use the error to correct themselves. In technical analysis
 * they are called adaptive moving averages, they track the time series more aggressively when it makes large moves.
 *
 * The input parameter 'T3.Periods' can be scaled following Matulich which is just cosmetics and makes the T3 look more
 * synchronized with an SMA or EMA of the same length (MA calculation does not change).
 *
 * Indicator buffers for iCustom():
 *  � MovingAverage.MODE_MA:    MA values
 *  � MovingAverage.MODE_TREND: trend direction and length
 *    - trend direction:        positive values denote an uptrend (+1...+n), negative values denote a downtrend (-1...-n)
 *    - trend length:           the absolute value of the direction is the trend length in bars since the last reversal
 *
 *
 *  @see  http://unicorn.us.com/trading/el.html#_T3Average                                      [T3 Moving Average, Matulich]
 *  @see  additional notes at the end of this file
 */
#include <rsf/stddefines.mqh>
int   __InitFlags[];
int __DeinitFlags[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern string ___a__________________________ = "=== T3 settings ===";
extern int    T3.Periods                     = 10;                // bar periods for alpha calculation
extern int    T3.Periods.Step                = 0;                 // step size for a stepped input parameter (hotkey)
extern bool   T3.Periods.MatulichScale       = true;
extern double T3.VolumeFactor                = 0.7;
extern double T3.VolumeFactor.Step           = 0;                 // step size for a stepped input parameter (hotkeys + VK_LWIN)
extern string T3.AppliedPrice                = "Open | High | Low | Close* | Median | Typical | Weighted";

extern string ___b__________________________ = "=== Trend reversal filter ===";
extern double MA.ReversalFilter.StdDev       = 0.1;               // min. MA change in std-deviations for a trend reversal
extern double MA.ReversalFilter.Step         = 0;                 // step size for a stepped input parameter (hotkeys + VK_SHIFT)

extern string ___c__________________________ = "=== Drawing options ===";
extern string Draw.Type                      = "Line* | Dot";
extern int    Draw.Width                     = 3;
extern color  Color.UpTrend                  = Blue;
extern color  Color.DownTrend                = Aqua;
extern int    MaxBarsBack                    = 10000;             // max. values to calculate (-1: all available)

extern string ___d__________________________ = "=== Signaling ===";
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
#include <rsf/functions/HandleCommands.mqh>
#include <rsf/functions/IsBarOpen.mqh>
#include <rsf/functions/ManageDoubleIndicatorBuffer.mqh>
#include <rsf/functions/ObjectCreateRegister.mqh>
#include <rsf/functions/trend.mqh>

#define MODE_MA_FILTERED      MovingAverage.MODE_MA      // indicator buffer ids
#define MODE_TREND            MovingAverage.MODE_TREND
#define MODE_UPTREND          2
#define MODE_DOWNTREND        3
#define MODE_UPTREND2         4
#define MODE_MA_RAW           5
#define MODE_MA_CHANGE        6
#define MODE_AVG              7
#define MODE_EMA1             8
#define MODE_EMA2             9
#define MODE_EMA3            10
#define MODE_EMA4            11
#define MODE_EMA5            12
#define MODE_EMA6            13

#property indicator_chart_window
#property indicator_buffers   5                          // visible buffers
int       terminal_buffers  = 8;                         // buffers managed by the terminal
int       framework_buffers = 6;                         // buffers managed by the framework

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

double maChange [];                                      // absolute change of current maRaw[] to previous maFiltered[]
double maAverage[];                                      // average of maChange[] over the last 'MA.Periods' bars

double ema1[];                                           // EMA buffers
double ema2[];                                           //
double ema3[];                                           //
double ema4[];                                           //
double ema5[];                                           //
double ema6[];                                           //

double c1;                                               // T3 coefficients
double c2;                                               //
double c3;                                               //
double c4;                                               //
double alpha;                                            // weight of the current price

int    appliedPrice;
int    requiredBars;
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

   // T3.Periods
   if (AutoConfiguration) T3.Periods = GetConfigInt(indicator, "T3.Periods", T3.Periods);
   if (T3.Periods < 1)                             return(catch("onInit(1)  invalid input parameter T3.Periods: "+ T3.Periods, ERR_INVALID_INPUT_PARAMETER));
   // T3.Periods.Step
   if (AutoConfiguration) T3.Periods.Step = GetConfigInt(indicator, "T3.Periods.Step", T3.Periods.Step);
   if (T3.Periods.Step < 0)                        return(catch("onInit(2)  invalid input parameter T3.Periods.Step: "+ T3.Periods.Step +" (must be >= 0)", ERR_INVALID_INPUT_PARAMETER));
   // T3.Periods.MatulichScale
   if (AutoConfiguration) T3.Periods.MatulichScale = GetConfigBool(indicator, "T3.Periods.MatulichScale", T3.Periods.MatulichScale);
   // T3.VolumeFactor
   if (AutoConfiguration) T3.VolumeFactor = GetConfigDouble(indicator, "T3.VolumeFactor", T3.VolumeFactor);
   if (T3.VolumeFactor < 0 || T3.VolumeFactor > 1) return(catch("onInit(3)  invalid input parameter T3.VolumeFactor: "+ NumberToStr(T3.VolumeFactor, ".1+") +" (must be from 0 to 1)", ERR_INVALID_INPUT_PARAMETER));
   // T3.VolumeFactor.Step
   if (AutoConfiguration) T3.VolumeFactor.Step = GetConfigDouble(indicator, "T3.VolumeFactor.Step", T3.VolumeFactor.Step);
   if (T3.VolumeFactor.Step < 0)                   return(catch("onInit(4)  invalid input parameter T3.VolumeFactor.Step: "+ NumberToStr(T3.VolumeFactor.Step, ".1+") +" (must be >= 0)", ERR_INVALID_INPUT_PARAMETER));
   // T3.AppliedPrice
   string sValues[], sValue = T3.AppliedPrice;
   if (AutoConfiguration) sValue = GetConfigString(indicator, "T3.AppliedPrice", sValue);
   if (Explode(sValue, "*", sValues, 2) > 1) {
      int size = Explode(sValues[0], "|", sValues, NULL);
      sValue = sValues[size-1];
   }
   sValue = StrTrim(sValue);
   appliedPrice = StrToPriceType(sValue, F_PARTIAL_ID|F_ERR_INVALID_PARAMETER);
   if (appliedPrice == -1)                         return(catch("onInit(5)  invalid input parameter T3.AppliedPrice: "+ DoubleQuoteStr(sValue), ERR_INVALID_INPUT_PARAMETER));
   T3.AppliedPrice = PriceTypeDescription(appliedPrice);
   // MA.ReversalFilter.StdDev
   if (AutoConfiguration) MA.ReversalFilter.StdDev = GetConfigDouble(indicator, "MA.ReversalFilter.StdDev", MA.ReversalFilter.StdDev);
   if (MA.ReversalFilter.StdDev < 0)               return(catch("onInit(6)  invalid input parameter MA.ReversalFilter.StdDev: "+ NumberToStr(MA.ReversalFilter.StdDev, ".1+") +" (must be >= 0)", ERR_INVALID_INPUT_PARAMETER));
   // MA.ReversalFilter.StepS
   if (AutoConfiguration) MA.ReversalFilter.Step = GetConfigDouble(indicator, "MA.ReversalFilter.Step", MA.ReversalFilter.Step);
   if (MA.ReversalFilter.Step < 0)                 return(catch("onInit(7)  invalid input parameter MA.ReversalFilter.Step: "+ NumberToStr(MA.ReversalFilter.Step, ".1+") +" (must be >= 0)", ERR_INVALID_INPUT_PARAMETER));
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
   else                                            return(catch("onInit(8)  invalid input parameter Draw.Type: "+ DoubleQuoteStr(sValue), ERR_INVALID_INPUT_PARAMETER));
   // Draw.Width
   if (AutoConfiguration) Draw.Width = GetConfigInt(indicator, "Draw.Width", Draw.Width);
   if (Draw.Width < 0)                             return(catch("onInit(9)  invalid input parameter Draw.Width: "+ Draw.Width, ERR_INVALID_INPUT_PARAMETER));
   // colors: after deserialization the terminal might turn CLR_NONE (0xFFFFFFFF) into Black (0xFF000000)
   if (AutoConfiguration) Color.UpTrend   = GetConfigColor(indicator, "Color.UpTrend",   Color.UpTrend  );
   if (AutoConfiguration) Color.DownTrend = GetConfigColor(indicator, "Color.DownTrend", Color.DownTrend);
   if (Color.UpTrend   == 0xFF000000) Color.UpTrend   = CLR_NONE;
   if (Color.DownTrend == 0xFF000000) Color.DownTrend = CLR_NONE;
   // MaxBarsBack
   if (AutoConfiguration) MaxBarsBack = GetConfigInt(indicator, "MaxBarsBack", MaxBarsBack);
   if (MaxBarsBack < -1)                           return(catch("onInit(10)  invalid input parameter MaxBarsBack: "+ MaxBarsBack, ERR_INVALID_INPUT_PARAMETER));
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
   if (__isChart && (T3.Periods.Step || T3.VolumeFactor.Step || MA.ReversalFilter.Step)) {
      GetChartCommand("ParameterStepper", sValues);
   }

   // restore a stored runtime status
   RestoreStatus();

   // buffer management and options
   SetIndexBuffer(MODE_MA_RAW,      maRaw     );      // MA raw main values:      invisible
   SetIndexBuffer(MODE_MA_FILTERED, maFiltered);      // MA filtered main values: invisible, displayed in legend and "Data" window
   SetIndexBuffer(MODE_TREND,       trend     );      // trend direction:         invisible, displayed in "Data" window
   SetIndexBuffer(MODE_UPTREND,     uptrend   );      // uptrend values:          visible
   SetIndexBuffer(MODE_DOWNTREND,   downtrend );      // downtrend values:        visible
   SetIndexBuffer(MODE_UPTREND2,    uptrend2  );      // single-bar uptrends:     visible
   SetIndexBuffer(MODE_MA_CHANGE,   maChange  );      //                          invisible
   SetIndexBuffer(MODE_AVG,         maAverage );      //                          invisible
   SetIndicatorOptions();

   // chart legend and coloring
   legendLabel = CreateChartLegend();
   enableMultiColoring = !__isSuperContext;

   InitializeT3();
   return(catch("onInit(11)"));
}


/**
 * Initialize T3 calculation.
 *
 * @return bool - success status
 */
bool InitializeT3() {                                          // see notes at the end of this file
   double v = T3.VolumeFactor;

   // initialize T3 coefficients and weight of the current price (alpha)
   c1 = -1*v*v*v;                                              // -1v�
   c2 =  3*v*v*v +3*v*v;                                       //  3v� +3v�
   c3 = -3*v*v*v -6*v*v -3*v;                                  // -3v� -6v� -3v
   c4 =  1*v*v*v +3*v*v +3*v +1;                               //  1v� +3v� +3v +1

   if (T3.Periods.MatulichScale) alpha = 4/(T3.Periods + 3.);  // N = (N-1)/2+1
   else                          alpha = 2/(T3.Periods + 1.);

   // initialize required bars for 99.9% of weights covered by known data
   double rel   = MathPow(0.999, 1/6.);                        // 99.9% reliability for all EMAs => 99.98% per single EMA
   double bars  = MathLog(1-rel)/MathLog(1-alpha);             // k = log(1-rel)/log(1-alpha)
   requiredBars = MathCeil(bars);

   if (MaxBarsBack + requiredBars < 0) {
      MaxBarsBack -= requiredBars;                             // prevent integer overflow
   }
   return(!catch("InitializeT3(1)"));
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

   // process incoming commands (rewrites ValidBars/ChangedBars/ShiftedBars)
   if (__isChart && (T3.Periods.Step || T3.VolumeFactor.Step || MA.ReversalFilter.Step)) {
      if (!HandleCommands("ParameterStepper")) return(last_error);
   }

   ManageDoubleIndicatorBuffer(MODE_EMA1, ema1);
   ManageDoubleIndicatorBuffer(MODE_EMA2, ema2);
   ManageDoubleIndicatorBuffer(MODE_EMA3, ema3);
   ManageDoubleIndicatorBuffer(MODE_EMA4, ema4);
   ManageDoubleIndicatorBuffer(MODE_EMA5, ema5);
   ManageDoubleIndicatorBuffer(MODE_EMA6, ema6);

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
      ArrayInitialize(ema1,                 0);
      ArrayInitialize(ema2,                 0);
      ArrayInitialize(ema3,                 0);
      ArrayInitialize(ema4,                 0);
      ArrayInitialize(ema5,                 0);
      ArrayInitialize(ema6,                 0);
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
      ShiftDoubleIndicatorBuffer(ema1,       Bars, ShiftedBars,           0);
      ShiftDoubleIndicatorBuffer(ema2,       Bars, ShiftedBars,           0);
      ShiftDoubleIndicatorBuffer(ema3,       Bars, ShiftedBars,           0);
      ShiftDoubleIndicatorBuffer(ema4,       Bars, ShiftedBars,           0);
      ShiftDoubleIndicatorBuffer(ema5,       Bars, ShiftedBars,           0);
      ShiftDoubleIndicatorBuffer(ema6,       Bars, ShiftedBars,           0);
   }

   // calculate start bar
   int limit = Min(ChangedBars, Bars-1, MaxBarsBack+requiredBars-1);    // how many bars need recalculation
   int startbar = limit-1;
   if (Bars < requiredBars) return(logInfo("onTick(2)  Tick="+ Ticks +"  Bars="+ Bars +"  required="+ requiredBars, ERR_HISTORY_INSUFFICIENT));

   double price, sum, stdDev, minChange, maFilterPeriods=T3.Periods;

   // initialize an empty previous bar
   if (!ema1[limit]) {
      price = iMA(NULL, NULL, 1, 0, MODE_SMA, appliedPrice, limit);
      ema1      [limit] = price;
      ema2      [limit] = price;
      ema3      [limit] = price;
      ema4      [limit] = price;
      ema5      [limit] = price;
      ema6      [limit] = price;
      maRaw     [limit] = price;
      maFiltered[limit] = price;
   }

   // recalculate changed bars
   for (int bar=startbar; bar >= 0; bar--) {
      price = iMA(NULL, NULL, 1, 0, MODE_SMA, appliedPrice, bar);
      ema1[bar] = ema1[bar+1] + alpha * (price     - ema1[bar+1]);
      ema2[bar] = ema2[bar+1] + alpha * (ema1[bar] - ema2[bar+1]);
      ema3[bar] = ema3[bar+1] + alpha * (ema2[bar] - ema3[bar+1]);
      ema4[bar] = ema4[bar+1] + alpha * (ema3[bar] - ema4[bar+1]);
      ema5[bar] = ema5[bar+1] + alpha * (ema4[bar] - ema5[bar+1]);
      ema6[bar] = ema6[bar+1] + alpha * (ema5[bar] - ema6[bar+1]);

      maRaw     [bar] = c1 * ema6[bar] + c2 * ema5[bar] + c3 * ema4[bar] + c4 * ema3[bar];
      maFiltered[bar] = maRaw[bar];

      if (MA.ReversalFilter.StdDev > 0) {
         maChange[bar] = maFiltered[bar] - maFiltered[bar+1];        // calculate the change of current raw to previous filtered MA
         sum = 0;
         for (int i=0; i < maFilterPeriods; i++) {                   // calculate average(change) over last 'maFilterPeriods'
            sum += maChange[bar+i];
         }
         maAverage[bar] = sum/maFilterPeriods;

         if (maChange[bar] * trend[bar+1] < 0) {                     // on opposite signs = trend reversal
            sum = 0;                                                 // calculate stdDeviation(maChange[]) over last 'maFilterPeriods'
            for (i=0; i < maFilterPeriods; i++) {
               sum += MathPow(maChange[bar+i] - maAverage[bar+i], 2);
            }
            stdDev = MathSqrt(sum/maFilterPeriods);
            minChange = MA.ReversalFilter.StdDev * stdDev;           // calculate required min. change

            if (MathAbs(maChange[bar]) < minChange) {
               maFiltered[bar] = maFiltered[bar+1];                  // discard trend reversal if MA change is smaller
            }
         }
      }
      UpdateTrend(maFiltered, bar, trend, uptrend, downtrend, uptrend2, enableMultiColoring, enableMultiColoring, drawType, Digits);
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

   if (keys & F_VK_LWIN != 0) {
      // step up/down input parameter "T3.VolumeFactor"
      double step = T3.VolumeFactor.Step;
                                                                     // no stepping if parameter limit reached
      if (!step || T3.VolumeFactor + direction*step < 0 || T3.VolumeFactor + direction*step > 1) {
         PlaySoundEx("Plonk.wav");
         return(false);
      }

      if (direction == STEP_UP) T3.VolumeFactor += step;
      else                      T3.VolumeFactor -= step;

      if (!InitializeT3()) return(false);
   }
   else if (keys & F_VK_SHIFT != 0) {
      // step up/down input parameter "MA.ReversalFilter"
      step = MA.ReversalFilter.Step;

      if (!step || MA.ReversalFilter.StdDev + direction*step < 0) {  // no stepping if parameter limit reached
         PlaySoundEx("Plonk.wav");
         return(false);
      }
      if (direction == STEP_UP) MA.ReversalFilter.StdDev += step;
      else                      MA.ReversalFilter.StdDev -= step;
   }
   else {
      // step up/down input parameter "T3.Periods"
      step = T3.Periods.Step;

      if (!step || T3.Periods + direction*step < 1) {                // no stepping if parameter limit reached
         PlaySoundEx("Plonk.wav");
         return(false);
      }
      if (direction == STEP_UP) T3.Periods += step;
      else                      T3.Periods -= step;

      if (!InitializeT3()) return(false);
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
   string sAppliedPrice = ifString(appliedPrice==PRICE_CLOSE, "", ", "+ PriceTypeDescription(appliedPrice));
   indicatorName        = WindowExpertName() +"("+ ifString(T3.Periods.Step || T3.VolumeFactor.Step || MA.ReversalFilter.Step, "step:", "") + T3.Periods +","+ NumberToStr(T3.VolumeFactor, ".1+") + sMaFilter + sAppliedPrice +")";
   shortName            = "T3MA("+ T3.Periods +")";
   IndicatorShortName(shortName);

   int draw_type = ifInt(Draw.Width, drawType, DRAW_NONE);

   IndicatorBuffers(terminal_buffers);
   SetIndexStyle(MODE_MA_FILTERED, DRAW_NONE, EMPTY, EMPTY,      CLR_NONE       );                                     SetIndexLabel(MODE_MA_FILTERED, shortName);
   SetIndexStyle(MODE_TREND,       DRAW_NONE, EMPTY, EMPTY,      CLR_NONE       );                                     SetIndexLabel(MODE_TREND,       shortName +" trend");
   SetIndexStyle(MODE_UPTREND,     draw_type, EMPTY, Draw.Width, Color.UpTrend  ); SetIndexArrow(MODE_UPTREND,   158); SetIndexLabel(MODE_UPTREND,     NULL);
   SetIndexStyle(MODE_DOWNTREND,   draw_type, EMPTY, Draw.Width, Color.DownTrend); SetIndexArrow(MODE_DOWNTREND, 158); SetIndexLabel(MODE_DOWNTREND,   NULL);
   SetIndexStyle(MODE_UPTREND2,    draw_type, EMPTY, Draw.Width, Color.UpTrend  ); SetIndexArrow(MODE_UPTREND2,  158); SetIndexLabel(MODE_UPTREND2,    NULL);
   IndicatorDigits(Digits);

   if (redraw) WindowRedraw();
   return(!catch("SetIndicatorOptions(1)"));
}


/**
 * Store the status of an active parameter stepper in the chart (for init cyles, template reloads and/or terminal restarts).
 *
 * @return bool - success status
 */
bool StoreStatus() {
   if (__isChart && (T3.Periods.Step || MA.ReversalFilter.Step)) {
      string prefix = "rsf."+ WindowExpertName() +".";

      Chart.StoreInt   (prefix +"T3.Periods",               T3.Periods);
      Chart.StoreDouble(prefix +"MA.ReversalFilter.StdDev", MA.ReversalFilter.StdDev);
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
      if (Chart.RestoreInt(prefix +"T3.Periods", iValue)) {
         if (T3.Periods.Step > 0) {
            if (iValue >= 1) T3.Periods = iValue;                 // silent validation
         }
      }

      double dValue;
      if (Chart.RestoreDouble(prefix +"MA.ReversalFilter", dValue)) {
         if (MA.ReversalFilter.Step > 0) {
            if (dValue >= 0) MA.ReversalFilter.StdDev = dValue;   // silent validation
         }
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
   return(StringConcatenate("T3.Periods=",                     T3.Periods,                                     ";"+ NL,
                            "T3.Periods.Step=",                T3.Periods.Step,                                ";"+ NL,
                            "T3.Periods.MatulichScale=",       BoolToStr(T3.Periods.MatulichScale),            ";"+ NL,
                            "T3.VolumeFactor=",                NumberToStr(T3.VolumeFactor, ".1+"),            ";"+ NL,
                            "T3.VolumeFactor.Step=",           NumberToStr(T3.VolumeFactor.Step, ".1+"),       ";"+ NL,
                            "T3.AppliedPrice=",                DoubleQuoteStr(T3.AppliedPrice),                ";"+ NL,

                            "MA.ReversalFilter.StdDev=",       NumberToStr(MA.ReversalFilter.StdDev, ".1+"),   ";"+ NL,
                            "MA.ReversalFilter.Step=",         NumberToStr(MA.ReversalFilter.Step, ".1+"),     ";"+ NL,

                            "Draw.Type=",                      DoubleQuoteStr(Draw.Type),                      ";"+ NL,
                            "Draw.Width=",                     Draw.Width,                                     ";"+ NL,
                            "Color.DownTrend=",                ColorToStr(Color.DownTrend),                    ";"+ NL,
                            "Color.UpTrend=",                  ColorToStr(Color.UpTrend),                      ";"+ NL,
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


/*
T3 calculation
--------------
int periods = 8;                                   // T3 length
double v    = 0.7;                                 // volume factor between 0 and 1 (default: 0.7)

double ema1 = ema(PRICE_CLOSE, periods)
double ema2 = ema(ema1, periods)
double ema3 = ema(ema2, periods)
double ema4 = ema(ema3, periods)
double ema5 = ema(ema4, periods)
double ema6 = ema(ema5, periods)
double c1   = -1v�
double c2   =  3v� +3v�
double c3   = -3v� -6v� -3v
double c4   =  1v� +3v� +3v +1
double T3   = c1*ema6 + c2*ema5 + c3*ema4 + c4*ema3


EMA calculation
---------------
EMA = weight * price + (1-weight) * EMA(prev)      // "weigth" = "alpha"
or
EMA = EMA(prev) + weight * (price-EMA(prev))
                                                   // @see  https://en.wikipedia.org/wiki/Moving_average#Approximating_the_EMA_with_a_limited_number_of_terms
required values: k = log(0.001)/log(1-alpha)       // 99.9% of weights are covered by known data, 0.1% = 0.001 are covered by unknown data:

EMA:    alpha = 2/(N + 1)                          // @see  https://en.wikipedia.org/wiki/Moving_average#Relationship_between_SMA_and_EMA
equals: N     = 2/alpha - 1

EMA(10) - an EMA having weights with the same "center of mass" as an SMA(10): alpha = 0.181818
- requires 19.5 values to be reliable to 98%
- requires 22.9 values to be reliable to 99%
- requires 34.4 values to be reliable to 99.9%

Fast-EMA: substitutes N = (N-1)/2 + 1              // Matulich: The Length parameter is divided by two to make the T3's lag equivalent to the lag of traditional
          alpha = 4/(N + 3)                        // moving averages. This way the T3 can be used with the same Length parameter as an SMA or EMA.
equals:   N     = 4/alpha - 3                      // @see  http://unicorn.us.com/trading/el.html#_T3Average

it holds: SMMA(n) = EMA(2*n-1)                     // All three EMAs are identical (length looks different, alpha is the same).
          EMA(n)  = Fast-EMA(2*n-1)                // e.g. SMMA(10) = EMA(19) = Fast-EMA(37)
*/
