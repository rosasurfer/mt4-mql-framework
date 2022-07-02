/**
 * Kaufman Efficiency Ratio
 *
 * Ratio between the amount price moved in one way (direction) to the amount price moved in any way (volatility).
 */
#include <stddefines.mqh>
int   __InitFlags[];
int __DeinitFlags[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern int Periods = 32;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <rsfLib.mqh>

#property indicator_separate_window
#property indicator_buffers   1

#property indicator_color1    Blue
#property indicator_width1    1

#property indicator_minimum   0
#property indicator_maximum   1

// buffers
double bufferKER[];


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   // input validation
   // Periods
   if (Periods < 1) return(catch("onInit(1)  invalid input parameter Periods: "+ Periods, ERR_INVALID_INPUT_PARAMETER));

   // buffer management
   SetIndexBuffer(0, bufferKER);

   // data display configuration, names, labels
   string name = "Kaufman Efficiency("+ Periods +")";
   IndicatorShortName(name +"  ");                          // chart subwindow and context menu
   SetIndexLabel(0, name);                                  // chart tooltips and "Data" window
   IndicatorDigits(3);

   // drawing options and styles
   SetIndicatorOptions();

   return(catch("onInit(2)"));
}


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   // on the first tick after terminal start buffers may not yet be initialized (spurious issue)
   if (!ArraySize(bufferKER)) return(logInfo("onTick(1)  sizeof(bufferKER) = 0", SetLastError(ERS_TERMINAL_NOT_YET_READY)));

   // reset buffers before performing a full recalculation
   if (!ValidBars) {
      ArrayInitialize(bufferKER, EMPTY_VALUE);
      SetIndicatorOptions();
   }

   // synchronize buffers with a shifted offline chart
   if (ShiftedBars > 0) {
      ShiftDoubleIndicatorBuffer(bufferKER, Bars, ShiftedBars, EMPTY_VALUE);
   }


   // (1) calculate start bar
   int startbar = Min(ChangedBars-1, Bars-Periods-1);
   if (startbar < 0) return(logInfo("onTick(2)  Tick="+ Ticks, ERR_HISTORY_INSUFFICIENT));


   double direction, noise;


   // (2) recalculate invalid indicator values
   for (int bar=startbar; bar >= 0; bar--) {
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
 * recompilation options must be set in start() to not be ignored.
 */
void SetIndicatorOptions() {
   IndicatorBuffers(indicator_buffers);
}


/**
 * Return a string representation of the input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("Periods=", Periods, ";"));
}
