/**
 * TestExpert
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern string sParameter = "dummy";
extern int    iParameter = 12345;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/expert.mqh>
#include <stdfunctions.mqh>
#include <stdlibs.mqh>
#include <functions/EventListener.BarOpen.mqh>
#include <iCustom/icMACD.mqh>


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   if (EventListener.BarOpen()) {
      int trend = icMACD(NULL, 14, "ALMA", "Close", 24, "ALMA", "Close", 200, MACD.MODE_TREND, 1);

      if (trend ==  1) debug("onTick(1)  MACD turned positive");
      if (trend == -1) debug("onTick(2)  MACD turned negative");
   }
   return(last_error);
}


/**
 * Return a string representation of the input parameters.
 *
 * @return string
 */
string InputsToStr() {
   return(EMPTY_STR);
}
