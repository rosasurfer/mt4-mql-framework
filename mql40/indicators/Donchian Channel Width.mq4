/**
 * Donchian Channel Width
 */
#include <rsf/stddefines.mqh>
int   __InitFlags[];
int __DeinitFlags[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern int   Periods      = 20;              // Donchian Channel periods
extern int   Periods.Step = 0;               // step size
extern color LineColor    = Blue;
extern int   MaxBarsBack  = 10000;           // max. values to calculate (-1: all available)

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <rsf/core/indicator.mqh>
#include <rsf/stdfunctions.mqh>
#include <rsf/stdlib.mqh>
#include <rsf/functions/chartlegend.mqh>
#include <rsf/functions/HandleCommands.mqh>
#include <rsf/functions/ObjectCreateRegister.mqh>

// indicator buffer ids
#define MODE_MAIN            0
#define MODE_UPPER_BAND      1
#define MODE_LOWER_BAND      2

#property indicator_separate_window
#property indicator_buffers  1               // visible buffers
int       terminal_buffers = 3;              // all buffers

#property indicator_color1    CLR_NONE

double main     [];
double upperBand[];
double lowerBand[];

string indicatorName = "";
string shortName     = "";
string legendLabel   = "";
int    chartWindow;
bool   isChartLegend = false;                // chart legend in main window

// parameter stepper directions
#define STEP_UP    1
#define STEP_DOWN -1


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   string indicator = WindowExpertName();

   // validate inputs
   // Periods
   if (AutoConfiguration) Periods = GetConfigInt(indicator, "Periods", Periods);
   if (Periods < 2)      return(catch("onInit(1)  invalid input parameter Periods: "+ Periods, ERR_INVALID_INPUT_PARAMETER));
   // Periods.Step
   if (AutoConfiguration) Periods.Step = GetConfigInt(indicator, "Periods.Step", Periods.Step);
   if (Periods.Step < 0) return(catch("onInit(2)  invalid input parameter Periods.Step: "+ Periods.Step +" (must be >= 0)", ERR_INVALID_INPUT_PARAMETER));
   // colors: after deserialization the terminal might turn CLR_NONE (0xFFFFFFFF) into Black (0xFF000000)
   if (AutoConfiguration) LineColor = GetConfigColor(indicator, "LineColor", LineColor);
   if (LineColor == 0xFF000000) LineColor = CLR_NONE;
   // MaxBarsBack
   if (AutoConfiguration) MaxBarsBack = GetConfigInt(indicator, "MaxBarsBack", MaxBarsBack);
   if (MaxBarsBack < -1) return(catch("onInit(3)  invalid input parameter MaxBarsBack: "+ MaxBarsBack, ERR_INVALID_INPUT_PARAMETER));
   if (MaxBarsBack == -1) MaxBarsBack = INT_MAX;

   // reset an active command handler
   if (__isChart && Periods.Step) {
      string sNull[];
      GetChartCommand("ParameterStepper", sNull);
   }

   // restore a stored runtime status
   RestoreStatus();

   // buffer management and display options
   SetIndicatorOptions();

   // always initialize a chart legend (removed on the first tick if not used)
   legendLabel = CreateChartLegend();
   chartWindow = GetChartWindow(shortName);

   return(catch("onInit(4)"));
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
   if (__isChart && Periods.Step) {
      if (!HandleCommands("ParameterStepper")) return(last_error);
   }

   // reset buffers before performing a full recalculation
   if (!ValidBars) {
      ArrayInitialize(main,      0);
      ArrayInitialize(upperBand, 0);
      ArrayInitialize(lowerBand, 0);
      SetIndicatorOptions();

      // initialize additional legend in main chart
      if (__isChart && !__isSuperContext) {
         if (chartWindow == -1) chartWindow = GetChartWindow(shortName);
         isChartLegend = (chartWindow == 0);
         if (!isChartLegend) RemoveChartLegend();
      }
   }

   // synchronize buffers with a shifted offline chart
   if (ShiftedBars > 0) {
      ShiftDoubleIndicatorBuffer(main,      Bars, ShiftedBars, 0);
      ShiftDoubleIndicatorBuffer(upperBand, Bars, ShiftedBars, 0);
      ShiftDoubleIndicatorBuffer(lowerBand, Bars, ShiftedBars, 0);
   }

   // calculate start bar
   int startbar = Min(MaxBarsBack-1, ChangedBars-1, Bars-Periods);
   if (startbar < 0 && MaxBarsBack) return(logInfo("onTick(1)  Tick="+ Ticks +"  Bars="+ Bars +"  needed="+ Periods, ERR_HISTORY_INSUFFICIENT));

   // recalculate changed bars
   if (startbar > 2) {
      upperBand[startbar] = 0;
      lowerBand[startbar] = 0;
   }
   for (int bar=startbar; bar >= 0; bar--) {
      if (bar > 0) {
         upperBand[bar] = High[iHighest(NULL, NULL, MODE_HIGH, Periods, bar)];
         lowerBand[bar] =  Low[ iLowest(NULL, NULL, MODE_LOW,  Periods, bar)];
      }
      else {
         upperBand[0] = MathMax(upperBand[1], High[0]);
         lowerBand[0] = MathMin(lowerBand[1],  Low[0]);
      }
      main[bar] = (upperBand[bar] - lowerBand[bar])/pUnit;
   }

   if (isChartLegend) UpdateChartLegend();

   return(last_error);
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

   // step up/down input parameter "Periods"
   int step = Periods.Step;

   if (!step || Periods + direction*step < 1) {          // stop if parameter limit reached
      PlaySoundEx("Plonk.wav");
      return(false);
   }
   if (direction == STEP_UP) Periods += step;
   else                      Periods -= step;

   ChangedBars = Bars;
   ValidBars   = 0;

   PlaySoundEx("Parameter Step.wav");
   return(true);
}


/**
 * Update the chart legend.
 */
void UpdateChartLegend() {
   static int lastTime, lastAccount;
   static double lastWidth;

   // update on full recalculation or if indicator name, channel width, current bar or the account changed
   if (!ValidBars || main[0]!=lastWidth || Time[0]!=lastTime || AccountNumber()!=lastAccount) {
      string text = StringConcatenate(indicatorName, "   ", NumberToStr(main[0], pUnitFormat));
      color clr = LineColor; clr = Blue;

      ObjectSetText(legendLabel, text, 9, "Arial Fett", clr);
      int error = GetLastError();
      if (error && error!=ERR_OBJECT_DOES_NOT_EXIST) catch("UpdateChartLegend(1)", error);     // on ObjectDrag or opened "Properties" dialog

      lastTime    = Time[0];
      lastAccount = AccountNumber();
      lastWidth   = main[0];
   }
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
   IndicatorBuffers(terminal_buffers);

   string stepSize = ifString(Periods.Step, ":"+ Periods.Step, "");
   indicatorName = "Donchian Channel("+ Periods + stepSize +") Width";
   shortName     = "Donchian Channel("+ Periods +") Width";
   IndicatorShortName(shortName);

   SetIndexBuffer(MODE_MAIN,       main     ); SetIndexEmptyValue(MODE_MAIN,       0);
   SetIndexBuffer(MODE_UPPER_BAND, upperBand); SetIndexEmptyValue(MODE_UPPER_BAND, 0);
   SetIndexBuffer(MODE_LOWER_BAND, lowerBand); SetIndexEmptyValue(MODE_LOWER_BAND, 0);
   IndicatorDigits(pDigits);

   SetIndexStyle(MODE_MAIN, DRAW_LINE, EMPTY, EMPTY, LineColor);
   SetIndexLabel(MODE_MAIN, "Donchian("+ Periods +") Width");

   if (redraw) WindowRedraw();
   return(!catch("SetIndicatorOptions(1)"));
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
   if (Chart.RestoreInt(prefix +"Periods", iValue)) {       // restore and remove it
      if (Periods.Step > 0) {                               // apply if stepper is still active
         if (iValue > 0) Periods = iValue;                  // silent validation
      }
   }
   return(!catch("RestoreStatus(1)"));
}


/**
 * Store the status of the parameter stepper in the chart (for init cyles, template reloads or terminal restarts).
 *
 * @return bool - success status
 */
bool StoreStatus() {
   if (__isChart && Periods.Step) {
      string prefix = "rsf."+ WindowExpertName() +".";
      Chart.StoreInt(prefix +"Periods", Periods);
   }
   return(catch("StoreStatus(1)"));
}


/**
 * Return a string representation of all input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("Periods=",      Periods,               ";", NL,
                            "Periods.Step=", Periods.Step,          ";", NL,
                            "LineColor=",    ColorToStr(LineColor), ";", NL,
                            "MaxBarsBack=",  MaxBarsBack,           ";")
   );
}
