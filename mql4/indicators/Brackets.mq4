/**
 * Bracketeer
 *
 * Marks breakout ranges for bracketing and displays bracket details.
 */
#include <stddefines.mqh>
int   __InitFlags[];
int __DeinitFlags[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern string BracketWindow    = "09:00-10:00";    // 00:00-00:00
extern string BracketInterval  = "D1";             // D1 | ECB | FOMC
extern int    StopLevelPercent = 67;               // stop level in percent of the bracket range (in marker description)
extern int    NumberOfBrackets = 1;
extern bool   SkipHolidays     = false;

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
