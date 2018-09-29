/**
 * TestExpert
 */
#include <stddefines.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern string sParameter = "dummy";
extern int    iParameter = 12345;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/expert.mqh>
#include <stdfunctions.mqh>
#include <rsfLibs.mqh>
#include <functions/EventListener.BarOpen.mqh>
#include <iCustom/icTrix.mqh>


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   if (EventListener.BarOpen()) {
      double trix = icTrix(NULL, 20, PRICE_CLOSE, Slope.MODE_MAIN,  1);
      int   trend = icTrix(NULL, 20, PRICE_CLOSE, Slope.MODE_TREND, 1);

      if (trend ==  1) debug("onTick(1)  Trix turned up,   last bar value: "+ trix +"  last bar trend: "+ _int(trend));
      if (trend == -1) debug("onTick(2)  Trix turned down, last bar value: "+ trix +"  last bar trend: "+ _int(trend));

      if (Abs(trend) == 1) Tester.Pause();
   }
   return(last_error);
}


/**
 * Return a string representation of the input parameters (used for logging).
 *
 * @return string
 */
string InputsToStr() {
   return(EMPTY_STR);
}
