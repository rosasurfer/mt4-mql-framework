/**
 * Brackets
 *
 * Marks breakout ranges and displays bracket details.
 *
 * TODDO:
 *  - visualization
 *     line length: 60 minutes up to 2 minutes before High/Low
 *     line width:  3
 *     color:       Magenta
 */
#include <stddefines.mqh>
int   __InitFlags[];
int __DeinitFlags[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern string BracketWindow    = "09:00-10:00";    // 00:00-00:00
extern int    NumberOfBrackets = 1;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <rsfLib.mqh>

#property indicator_chart_window


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   SetIndexLabel(0, NULL);                         // disable "Data" window display
   return(catch("onInit(1)"));
}


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   return(last_error);
}
