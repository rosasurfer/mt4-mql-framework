/**
 * Inside Bars (work in progress)
 *
 *
 * Marks inside bars and SR levels of the specified timeframes in the chart.
 */
#include <stddefines.mqh>
int   __INIT_FLAGS__[] = {INIT_TIMEZONE};
int __DEINIT_FLAGS__[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern string Configuration  = "manual | auto*";
extern int    Max.InsideBars = 20;                    //  max. amount of inside bars to find (-1: all)

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <rsfLibs.mqh>

#property indicator_chart_window

int maxInsideBars;


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   // validate inputs
   // Configuration                                   // TODO

   // Max.InsideBars
   if (Max.InsideBars < -1) return(catch("onInit(1)  Invalid input parameter Max.InsideBars: "+ Max.InsideBars, ERR_INVALID_INPUT_PARAMETER));
   maxInsideBars = ifInt(Max.InsideBars==-1, INT_MAX, Max.InsideBars);

   return(catch("onInit(2)"));
}


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   if (ChangedBars < Bars)
      return(last_error);

   int    timeframe  = Period();
   string sTimeframe = PeriodDescription(timeframe);
   int    findMore   = maxInsideBars;

   // find the specified number of inside bars
   for (int i=1; findMore && i < Bars; i++) {
      if (High[i] >= High[i-1] && Low[i] <= Low[i-1]) {
         debug("onTick(1)  "+ sTimeframe +" inside bar at "+ GmtTimeFormat(Time[i-1], "%a, %d.%m.%Y %H:%M"));
         findMore--;
      }
   }
   return(last_error);
}


/**
 * Return a string representation of the input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("Configuration=",  DoubleQuoteStr(Configuration), ";", NL,
                            "Max.InsideBars=", Max.InsideBars, ";")
   );
}
