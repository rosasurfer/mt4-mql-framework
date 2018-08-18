/**
 * Volatility as the amount price moved in any direction
 *
 * The absolute range of two bars (as measured by e.g. an ATR indicator) may be equal but price activity and volatility in
 * the time period of the bars may significantly differ. If you imagine a Renko chart the value calculated by this indicator
 * resembles something similar to the number of completed Renko bricks per time period.
 *
 * TODO:
 *   - compare to Kaufman Efficiency Ratio:   https://futures.io/ninjatrader/10916-kaufman-efficiency-study.html
 *                                            https://futures.io/elite-circle/770-detecting-chop-10.html#post91414
 *                                            https://www.mql5.com/en/blogs/post/21200
 *                                            https://www.mql5.com/en/code/10187
 *   - compare to Kaufman Volatility:         https://www.mql5.com/en/code/350
 *   - compare to Chande Momentum Oscillator: http://etfhq.com/blog/2011/02/07/kaufmans-efficiency-ratio/
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern int Periods = 12;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <stdlibs.mqh>

#property indicator_separate_window
#property indicator_buffers   1                             // configurable buffers (input dialog)
int       allocated_buffers = 1;                            // used buffers


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   if (InitReason() == IR_RECOMPILE) {
      if (!RestoreInputParameters()) return(last_error);
   }
   return(catch("onInit(1)"));
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
   return(!catch("RestoreInputParameters(2)"));
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
