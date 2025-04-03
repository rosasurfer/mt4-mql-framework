/**
 * Average (True) Range
 */
#include <rsf/stddefines.mqh>
int   __InitFlags[];
int __DeinitFlags[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern bool   TrueRange                      = true;                       // whether to reflect the traded or the true range

extern string ___a__________________________ = "=== MA settings ===";
extern string MA.Method                      = "SMA | LWMA* | EMA | SMMA"; // averaging type
extern int    MA.Periods                     = 20;                         // averaging periods
extern int    MA.Periods.Step                = 0;                          // step size for a stepped input parameter

extern string ___b__________________________ = "=== Display settings ===";
extern int    Line.Width                     = 2;
extern color  Line.Color                     = Blue;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <rsf/core/indicator.mqh>
#include <rsf/stdfunctions.mqh>
#include <rsf/stdlib.mqh>
#include <rsf/functions/HandleCommands.mqh>

// parameter stepper directions
#define STEP_UP               1
#define STEP_DOWN            -1

// indicator buffer ids
#define MODE_MA               0              // average
#define MODE_RANGE            1              // range values

#property indicator_separate_window
#property indicator_buffers   1              // visible buffers
int       terminal_buffers  = 2;             // all buffers

#property indicator_color1    CLR_NONE
#property indicator_width1    1

double ranges[];
double ma    [];

int maMethod;


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   string indicator = WindowExpertName();

   // validate inputs
   // MA.Periods
   if (AutoConfiguration) MA.Periods = GetConfigInt(indicator, "MA.Periods", MA.Periods);
   if (MA.Periods < 1)       return(catch("onInit(1)  invalid input parameter MA.Periods: "+ MA.Periods, ERR_INVALID_INPUT_PARAMETER));
   // MA.Periods.Step
   if (AutoConfiguration) MA.Periods.Step = GetConfigInt(indicator, "MA.Periods.Step", MA.Periods.Step);
   if (MA.Periods.Step < 0)  return(catch("onInit(2)  invalid input parameter MA.Periods.Step: "+ MA.Periods.Step +" (must be >= 0)", ERR_INVALID_INPUT_PARAMETER));
   // MA.Method
   string sValues[], sValue = MA.Method;
   if (AutoConfiguration) sValue = GetConfigString(indicator, "MA.Method", sValue);
   if (Explode(sValue, "*", sValues, 2) > 1) {
      int size = Explode(sValues[0], "|", sValues, NULL);
      sValue = sValues[size-1];
   }
   maMethod = StrToMaMethod(sValue, F_PARTIAL_ID|F_ERR_INVALID_PARAMETER);
   if (maMethod == -1)       return(catch("onInit(3)  invalid input parameter MA.Method: "+ DoubleQuoteStr(MA.Method), ERR_INVALID_INPUT_PARAMETER));
   if (maMethod > MODE_LWMA) return(catch("onInit(4)  unsupported MA.Method: "+ DoubleQuoteStr(MA.Method), ERR_INVALID_INPUT_PARAMETER));
   MA.Method = MaMethodDescription(maMethod);
   // TrueRange
   // Line.Width
   if (AutoConfiguration) Line.Width = GetConfigInt(indicator, "Line.Width", Line.Width);
   if (Line.Width < 0)       return(catch("onInit(5)  invalid input parameter Line.Width: "+ Line.Width, ERR_INVALID_INPUT_PARAMETER));
   // colors: after deserialization the terminal might turn CLR_NONE (0xFFFFFFFF) into Black (0xFF000000)
   if (AutoConfiguration) Line.Color = GetConfigColor(indicator, "Line.Color", Line.Color);
   if (Line.Color == 0xFF000000) Line.Color = CLR_NONE;

   // reset an active command handler
   if (__isChart && MA.Periods.Step) {
      GetChartCommand("ParameterStepper", sValues);
   }

   // restore a stored runtime status
   RestoreStatus();

   // buffer management and options
   IndicatorBuffers(terminal_buffers);
   SetIndexBuffer(MODE_RANGE, ranges);       // invisible
   SetIndexBuffer(MODE_MA,    ma);           // visible
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
   if (__isChart && MA.Periods.Step) {
      if (!HandleCommands("ParameterStepper")) return(last_error);
   }

   // reset buffers before performing a full recalculation
   if (!ValidBars) {
      ArrayInitialize(ranges, EMPTY_VALUE);
      ArrayInitialize(ma,     EMPTY_VALUE);
      SetIndicatorOptions();
   }

   // synchronize buffers with a shifted offline chart
   if (ShiftedBars > 0) {
      ShiftDoubleIndicatorBuffer(ranges, Bars, ShiftedBars, EMPTY_VALUE);
      ShiftDoubleIndicatorBuffer(ma,     Bars, ShiftedBars, EMPTY_VALUE);
   }

   // calculate start bar
   int bars = Min(ChangedBars, Bars-1);
   int startbar = bars-1;

   // recalculate changed bars
   for (int bar=startbar; bar >= 0; bar--) {
      if (TrueRange) {
         ranges[bar] = MathMax(High[bar], Close[bar+1]) - MathMin(Low[bar], Close[bar+1]);
      }
      else {
         ranges[bar] = High[bar] - Low[bar];
      }
   }
   for (bar=startbar; bar >= 0; bar--) {
      ma[bar] = iMAOnArray(ranges, WHOLE_ARRAY, MA.Periods, 0, maMethod, bar);
   }
   return(catch("onTick(1)"));
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

   // step up/down input parameter "T3.Periods"
   int step = MA.Periods.Step;

   if (!step || MA.Periods + direction*step < 1) {          // no stepping if parameter limit reached
      PlaySoundEx("Plonk.wav");
      return(false);
   }
   if (direction == STEP_UP) MA.Periods += step;
   else                      MA.Periods -= step;

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
   IndicatorBuffers(terminal_buffers);

   string name = ifString(TrueRange, "ATR", "AvgRange") +"("+ ifString(MA.Periods.Step, "step:", "") + MA.Periods +")";
   IndicatorShortName(name);

   int drawType = ifInt(Line.Width, DRAW_LINE, DRAW_NONE);

   SetIndexStyle(MODE_RANGE, DRAW_NONE, EMPTY, EMPTY,      CLR_NONE);
   SetIndexStyle(MODE_MA,    drawType,  EMPTY, Line.Width, Line.Color); SetIndexLabel(MODE_MA, name);
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
   if (__isChart && MA.Periods.Step) {
      string prefix = "rsf."+ WindowExpertName() +".";
      Chart.StoreInt(prefix +"MA.Periods", MA.Periods);
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
   }
   return(!catch("RestoreStatus(1)"));
}


/**
 * Return a string representation of all input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("TrueRange=",       BoolToStr(TrueRange),      ";", NL,
                            "MA.Method=",       DoubleQuoteStr(MA.Method), ";", NL,
                            "MA.Periods=",      MA.Periods,                ";", NL,
                            "MA.Periods.Step=", MA.Periods.Step,           ";", NL,
                            "Line.Width=",      Line.Width,                ";", NL,
                            "Line.Color=",      ColorToStr(Line.Color),    ";")
   );
}
