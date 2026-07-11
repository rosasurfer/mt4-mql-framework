/**
 * Relative Bar Range
 *
 * Defined as the ratio of current bar range to the "Average True Range" of a specified number of bars.
 */
#include <rsf/stddefines.mqh>
int   __InitFlags[];
int __DeinitFlags[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern string ___a__________________________ = "=== ATR settings ===";
extern int    ATR.Periods                    = 21;
extern int    ATR.Periods.Step               = 0;             // step size for parameter stepper via hotkey

extern string ___b__________________________ = "=== Display settings ===";
extern color  Histogram.Color.AboveAverage   = LimeGreen;
extern color  Histogram.Color.BelowAverage   = Red;
extern int    Histogram.Width                = 2;
extern int    MaxBarsBack                    = 10000;         // max. values to calculate (-1: all available)

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <rsf/core/indicator.mqh>
#include <rsf/stdfunctions.mqh>
#include <rsf/stdlib.mqh>
#include <rsf/functions/HandleCommands.mqh>
#include <rsf/functions/ta/ATR.mqh>

#property indicator_separate_window
#property indicator_buffers    3

#property indicator_color1     CLR_NONE
#property indicator_color2     CLR_NONE
#property indicator_color3     CLR_NONE

#property indicator_minimum    0
#property indicator_maximum    3

#property indicator_level1     1.0
#property indicator_level2     2.0
#property indicator_level3     3.0

#property indicator_levelcolor LightGray

#define MODE_CURRENT_RANGE     0          // indicator buffer ids
#define MODE_AVERAGE_RANGE     1
#define MODE_RATIO             2

double currentRange[];                    // indicator buffers
double averageRange[];
double relativeRange[];

#define STEP_UP                1          // parameter stepper directions
#define STEP_DOWN             -1


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   string indicator = WindowExpertName();

   // validate inputs
   // ATR.Periods
   if (AutoConfiguration) ATR.Periods = GetConfigInt(indicator, "ATR.Periods", ATR.Periods);
   if (ATR.Periods < 1)      return(catch("onInit(1)  invalid input parameter ATR.Periods: "+ ATR.Periods, ERR_INVALID_INPUT_PARAMETER));
   // ATR.Periods.Step
   if (AutoConfiguration) ATR.Periods.Step = GetConfigInt(indicator, "ATR.Periods.Step", ATR.Periods.Step);
   if (ATR.Periods.Step < 0) return(catch("onInit(2)  invalid input parameter ATR.Periods.Step: "+ ATR.Periods.Step +" (must be >= 0)", ERR_INVALID_INPUT_PARAMETER));
   // Histogram.Color.*: after deserialization the terminal may turn CLR_NONE (0xFFFFFFFF) into Black (0xFF000000)
   if (AutoConfiguration) Histogram.Color.AboveAverage = GetConfigColor(indicator, "Histogram.Color.AboveAverage", Histogram.Color.AboveAverage);
   if (AutoConfiguration) Histogram.Color.BelowAverage = GetConfigColor(indicator, "Histogram.Color.BelowAverage", Histogram.Color.BelowAverage);
   if (Histogram.Color.AboveAverage == 0xFF000000) Histogram.Color.AboveAverage = CLR_NONE;
   if (Histogram.Color.BelowAverage == 0xFF000000) Histogram.Color.BelowAverage = CLR_NONE;
   // Histogram.Width
   if (AutoConfiguration) Histogram.Width = GetConfigInt(indicator, "Histogram.Width", Histogram.Width);
   if (Histogram.Width < 0)  return(catch("onInit(3)  invalid input parameter Histogram.Width: "+ Histogram.Width +" (valid range: 0-5)", ERR_INVALID_INPUT_PARAMETER));
   if (Histogram.Width > 5)  return(catch("onInit(4)  invalid input parameter Histogram.Width: "+ Histogram.Width +" (valid range: 0-5)", ERR_INVALID_INPUT_PARAMETER));
   // MaxBarsBack
   if (AutoConfiguration) MaxBarsBack = GetConfigInt(indicator, "MaxBarsBack", MaxBarsBack);
   if (MaxBarsBack < -1)     return(catch("onInit(5)  invalid input parameter MaxBarsBack: "+ MaxBarsBack, ERR_INVALID_INPUT_PARAMETER));
   if (MaxBarsBack == -1) MaxBarsBack = INT_MAX;

   // reset an active command handler
   if (__isChart && ATR.Periods.Step) {
      string sNull[];
      GetChartCommand("ParameterStepper", sNull);
   }

   RestoreStatus();
   SetIndicatorOptions();
   return(catch("onInit(6)"));
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
   // process incoming commands (rewrites ValidBars/ChangedBars/ShiftedBars)
   if (__isChart && ATR.Periods.Step) {
      if (!HandleCommands("ParameterStepper")) return(last_error);
   }

   // reset buffers before performing a full recalculation
   if (!ValidBars) {
      ArrayInitialize(currentRange,  0);
      ArrayInitialize(averageRange,  0);
      ArrayInitialize(relativeRange, 0);
      SetIndicatorOptions();
   }

   // synchronize buffers with a shifted offline chart
   if (ShiftedBars > 0) {
      ShiftDoubleIndicatorBuffer(currentRange,  Bars, ShiftedBars, 0);
      ShiftDoubleIndicatorBuffer(averageRange,  Bars, ShiftedBars, 0);
      ShiftDoubleIndicatorBuffer(relativeRange, Bars, ShiftedBars, 0);
   }

   // calculate start bar
   int startbar = Min(MaxBarsBack-1, ChangedBars-1, Bars-ATR.Periods);
   if (startbar < 0 && MaxBarsBack) return(logInfo("onTick(1)  Tick="+ Ticks, ERR_HISTORY_INSUFFICIENT));

   // recalculate changed bars
   for (int bar=startbar; bar >= 0; bar--) {
      currentRange[bar] = (MathMax(High[bar], Close[bar+1]) - MathMin(Low[bar], Close[bar+1])) / pUnit;
      averageRange[bar] = ATR(NULL, NULL, ATR.Periods, bar, F_ERS_HISTORY_UPDATE) / pUnit;
      if (!averageRange[bar]) return(last_error);

      // calculate ratio
      relativeRange[bar] = currentRange[bar] / averageRange[bar];
   }
   return(catch("onTick(1)"));
}


/**
 * Process an incoming command.
 *
 * @param  string cmd    - command name
 * @param  string params - command parameters
 * @param  int    keys   - flags of pressed modifier keys
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

   int step = ATR.Periods.Step;                       // step up/down input parameter "ATR.Periods"

   if (!step || ATR.Periods + direction*step < 1) {   // stop if parameter limit reached
      PlaySoundEx("Plonk.wav");
      return(false);
   }
   if (direction == STEP_UP) ATR.Periods += step;
   else                      ATR.Periods -= step;

   ChangedBars = Bars;
   ValidBars   = 0;

   PlaySoundEx("Parameter Step.wav");
   return(true);
}


/**
 * Store the status of the parameter stepper in the chart (for init cyles, template reloads and terminal restarts).
 *
 * @return bool - success status
 */
bool StoreStatus() {
   if (__isChart && ATR.Periods.Step) {
      string prefix = "rsf."+ WindowExpertName() +".";
      Chart.StoreInt(prefix +"ATR.Periods", ATR.Periods);
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
   if (Chart.RestoreInt(prefix +"ATR.Periods", iValue)) {   // restore and remove it
      if (ATR.Periods.Step > 0) {                           // apply if stepper is still active
         if (iValue > 0) ATR.Periods = iValue;              // silent validation
      }
   }
   return(!catch("RestoreStatus(1)"));
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
   string stepSize = ifString(ATR.Periods.Step, ":"+ ATR.Periods.Step, "");
   string name = "BarRange / ATR("+ ATR.Periods + stepSize +") / Ratio";
   IndicatorShortName(name);

   IndicatorBuffers(indicator_buffers);
   SetIndexBuffer(MODE_CURRENT_RANGE, currentRange ); SetIndexEmptyValue(MODE_CURRENT_RANGE, 0);
   SetIndexBuffer(MODE_AVERAGE_RANGE, averageRange ); SetIndexEmptyValue(MODE_AVERAGE_RANGE, 0);
   SetIndexBuffer(MODE_RATIO,         relativeRange); SetIndexEmptyValue(MODE_RATIO,         0);
   IndicatorDigits(pDigits);

   // MODE_CURRENT_RANGE and MODE_AVERAGE_RANGE are not hidden to get legend values
   SetIndexStyle(MODE_RATIO, DRAW_LINE, EMPTY, 1, Blue);

   if (redraw) WindowRedraw();
   return(!catch("SetIndicatorOptions(1)"));
}


/**
 * Return a string representation of all input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("ATR.Periods=",                  ATR.Periods,                              ";", NL,
                            "ATR.Periods.Step=",             ATR.Periods.Step,                         ";", NL,

                            "Histogram.Color.AboveAverage=", ColorToStr(Histogram.Color.AboveAverage), ";", NL,
                            "Histogram.Color.BelowAverage=", ColorToStr(Histogram.Color.BelowAverage), ";", NL,
                            "Histogram.Width=",              Histogram.Width,                          ";", NL,
                            "MaxBarsBack=",                  MaxBarsBack,                              ";")
   );
}
