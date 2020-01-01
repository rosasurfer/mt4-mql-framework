/**
 * Kaufman Efficiency Ratio
 *
 * Ratio between the amount price moved in one way (direction) to the amount price moved in any way (volatility).
 */
#include <stddefines.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern int Periods = 32;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <rsfLibs.mqh>

#property indicator_separate_window
#property indicator_buffers   1

#property indicator_color1    Blue
#property indicator_width1    1

#property indicator_minimum   0
#property indicator_maximum   1

// buffers
double bufferKER[];

string ind.shortName;


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   if (ProgramInitReason() == IR_RECOMPILE) {
      if (!RestoreInputParameters()) return(last_error);
   }

   // input validation
   // Periods
   if (Periods < 1) return(catch("onInit(1)  Invalid input parameter Periods = "+ Periods, ERR_INVALID_INPUT_PARAMETER));

   // buffer management
   SetIndexBuffer(0, bufferKER);

   // data display configuration, names, labels
   ind.shortName = "Kaufman Efficiency("+ Periods +")  ";
   IndicatorShortName(ind.shortName);                       // subwindow and context menu
   SetIndexLabel(0, StrTrim(ind.shortName));                // "Data" window and tooltips
   IndicatorDigits(3);

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
   // a not initialized buffer can happen on terminal start under specific circumstances
   if (!ArraySize(bufferKER))
      return(log("onTick(1)  size(bufferKER) = 0", SetLastError(ERS_TERMINAL_NOT_YET_READY)));

   // reset all buffers and delete garbage before doing a full recalculation
   if (!UnchangedBars) {
      ArrayInitialize(bufferKER, EMPTY_VALUE);
      SetIndicatorOptions();
   }

   // synchronize buffers with a shifted offline chart
   if (ShiftedBars > 0) {
      ShiftIndicatorBuffer(bufferKER, Bars, ShiftedBars, EMPTY_VALUE);
   }


   // (1) calculate start bar
   int startBar = Min(ChangedBars-1, Bars-Periods-1);
   if (startBar < 0) return(catch("onTick(2)", ERR_HISTORY_INSUFFICIENT));


   double direction, noise;


   // (2) recalculate invalid indicator values
   for (int bar=startBar; bar >= 0; bar--) {
      direction = NetDifference(bar);
      noise     = Volatility(bar);

      if (!noise) bufferKER[bar] = 0;
      else        bufferKER[bar] = direction/noise;
   }
   return(last_error);
}


/**
 * Calculate and return the absolute price difference for a bar.
 *
 * @param  int bar
 *
 * @return double - difference
 */
double NetDifference(int bar) {
   return(MathAbs(Close[bar+Periods] - Close[bar]));
}


/**
 * Calculate and return the Kaufman volatility for a bar.
 *
 * @param  int bar
 *
 * @return double - volatility
 */
double Volatility(int bar) {
   double vola = 0;
   for (int i=Periods-1; i >= 0; i--) {
      vola += MathAbs(Close[bar+i+1] - Close[bar+i]);
   }
   return(vola);
}


/**
 * Workaround for various terminal bugs when setting indicator options. Usually options are set in init(). However after
 * recompilation options must be set in start() to not get ignored.
 */
void SetIndicatorOptions() {
   IndicatorBuffers(indicator_buffers);
}


/**
 * Store input parameters in the chart before recompilation.
 *
 * @return bool - success status
 */
bool StoreInputParameters() {
   Chart.StoreInt(__NAME() +".input.Periods", Periods);
   return(!catch("StoreInputParameters(1)"));
}


/**
 * Restore input parameters found in the chart after recompilation.
 *
 * @return bool - success status
 */
bool RestoreInputParameters() {
   Chart.RestoreInt(__NAME() +".input.Periods", Periods);
   return(!catch("RestoreInputParameters(1)"));
}


/**
 * Return a string representation of the input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("Periods=", Periods, ";"));
}
