/**
 * A system following the trend of the SuperTrend or HalfTrend indicator.
 */
#include <stddefines.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern double Lotsize = 0.1;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/expert.mqh>
#include <stdfunctions.mqh>
#include <rsfLibs.mqh>
#include <functions/BarOpenEvent.mqh>


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   if (IsBarOpenEvent()) {
   }
   return(catch("onTick(1)"));
}


/**
 * Return a string representation of the input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("Lotsize=", NumberToStr(Lotsize, ".1+"), ";")
   );
}
