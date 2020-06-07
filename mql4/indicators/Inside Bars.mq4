/**
 * Inside Bars (work in progress)
 *
 * Marks inside bars of the specified timeframes and their SR levels in the chart.
 */
#include <stddefines.mqh>
int   __INIT_FLAGS__[] = {INIT_TIMEZONE};
int __DEINIT_FLAGS__[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern string Configuration = "manual | auto*";

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <rsfLibs.mqh>

#property indicator_chart_window

int timeframe;                                     // the currently active inside bar timeframe


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   return(catch("onInit(1)"));
}


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   timeframe = PERIOD_D1;

   if (!UnchangedBars) {
      // find last inside bar




      // draw found inside bar
   }

   return(last_error);
}


/**
 * Return a string representation of the input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("Configuration=", DoubleQuoteStr(Configuration), ";"));
}
