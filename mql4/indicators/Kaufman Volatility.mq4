/**
 * Kaufman Volatility as the amount price moved in any direction
 *
 * The absolute range of two bars as measured by e.g. an ATR indicator may be equal but price activity (volatility) in the
 * bar periods can significantly differ. Imagine range bars. The value calculated by this indicator resembles something
 * similar to the number of completed range bars per time period. The displayed unit is "pip", that's range bars of 1 pip size.
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern int Periods = 38;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <stdlibs.mqh>

#property indicator_separate_window
#property indicator_buffers   1                             // configurable buffers (input dialog)
int       allocated_buffers = 1;                            // used buffers

#property indicator_color1    Blue
#property indicator_width1    1

// buffers
double bufferVola[];

string ind.shortName;


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   if (InitReason() == IR_RECOMPILE) {
      if (!RestoreInputParameters()) return(last_error);
   }

   // input validation
   // Periods
   if (Periods < 1) return(catch("onInit(1)  Invalid input parameter Periods = "+ Periods, ERR_INVALID_INPUT_PARAMETER));

   // buffer management
   SetIndexBuffer(0, bufferVola);

   // data display configuration, names, labels
   ind.shortName = "Kaufman Volatility("+ Periods +")  ";
   IndicatorShortName(ind.shortName);                       // subwindow and context menu
   SetIndexLabel(0, StringTrim(ind.shortName));             // "Data" window and tooltips
   IndicatorDigits(1);

   // drawing options and styles
   SetIndicatorOptions();

   return(catch("onInit(2)"));
}


/**
 * Deinitialization
 *
 * @return int - error status
 */
int onDeinit() {
   DeleteRegisteredObjects(NULL);
   return(last_error);
}


/**
 * Called before recompilation.
 *
 * @return int - error status
 */
int onDeinitRecompile() {
   StoreInputParameters();
   return(last_error);
}


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   // check for finished buffer initialization (needed on terminal start)
   if (!ArraySize(bufferVola))
      return(log("onTick(1)  size(bufferVola) = 0", SetLastError(ERS_TERMINAL_NOT_YET_READY)));

   // reset all buffers and delete garbage before doing a full recalculation
   if (!ValidBars) {
      ArrayInitialize(bufferVola, EMPTY_VALUE);
      SetIndicatorOptions();
   }

   // synchronize buffers with a shifted offline chart
   if (ShiftedBars > 0) {
      ShiftIndicatorBuffer(bufferVola, Bars, ShiftedBars, EMPTY_VALUE);
   }


   // (1) calculate start bar
   int startBar = Min(ChangedBars-1, Bars-Periods-1);
   if (startBar < 0) return(catch("onTick(2)", ERR_HISTORY_INSUFFICIENT));


   // (2) recalculate invalid indicator values
   for (int bar=startBar; bar >= 0; bar--) {
      bufferVola[bar] = CalculateVolatility(bar);
   }
   return(last_error);
}


/**
 * Calculate and return the Kaufman volatility for a bar.
 *
 * @param  int bar
 *
 * @return double - volatility in pip
 */
double CalculateVolatility(int bar) {
   double vola = 0;

   for (int i=Periods-1; i >= 0; i--) {
      vola += MathAbs(Close[bar+i] - Close[bar+i+1]);
   }
   return(NormalizeDouble(vola/Pips, 1));
}


/**
 * Workaround for various terminal bugs when setting indicator options. Usually options are set in init(). However after
 * recompilation options must be set in start() to not get ignored.
 */
void SetIndicatorOptions() {
   IndicatorBuffers(allocated_buffers);
}


/**
 * Store input parameters in the chart before recompilation.
 *
 * @return bool - success status
 */
bool StoreInputParameters() {
   Chart.StoreInt(__NAME__ +".input.Periods", Periods);
   return(!catch("StoreInputParameters(1)"));
}


/**
 * Restore input parameters found in the chart after recompilation.
 *
 * @return bool - success status
 */
bool RestoreInputParameters() {
   Chart.RestoreInt("Periods", Periods);
   return(!catch("RestoreInputParameters(1)"));
}


/**
 * Return a string representation of the input parameters. Used to log iCustom() calls.
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("input: ",

                            "Periods=", Periods, "; ")
   );
}
