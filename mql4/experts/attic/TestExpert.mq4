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
#include <structs/xtrade/ExecutionContext.mqh>


#import "Expander.dll"
#import


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {

   int error = UpdateGridSize();

   return(error);
}


/**
 * Calculate the current grid size and return the price at which to open the next position.
 *
 * @return int - error status
 */
double UpdateGridSize() {
   if (__STATUS_OFF) return(NO_ERROR);

   int timeframe = PERIOD_M1;
   int bars      = 70;

   int e1, e2, e3, e4, error;

   int highest = iHighest(NULL, timeframe, MODE_HIGH, bars, 1); e1 = GetLastError(); if (IsError(e1)) error = e1;
   double high = iHigh   (NULL, timeframe, highest);            e2 = GetLastError(); if (IsError(e2)) error = e2;
   int  lowest = iLowest(NULL, timeframe, MODE_LOW, bars, 1);   e3 = GetLastError(); if (IsError(e3)) error = e3;
   double low  = iLow   (NULL, timeframe, lowest);              e4 = GetLastError(); if (IsError(e4)) error = e4;

   if (IsError(error))
      return(catch("UpdateGridSize(1)  e1="+ ifString(!e1, "0", ErrorToStr(e1)) +"  e2="+ ifString(!e2, "0", ErrorToStr(e2)) +"  e3="+ ifString(!e3, "0", ErrorToStr(e3)) +"  e4="+ ifString(!e4, "0", ErrorToStr(e4)), error));
   return(NO_ERROR);
}


/**
 * Return a string representation of the input parameters.
 *
 * @return string
 */
string InputsToStr() {
   return(EMPTY_STR);
}
