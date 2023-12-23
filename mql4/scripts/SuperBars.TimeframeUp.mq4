/**
 * SuperBars Up
 *
 * Send the SuperBars indicator a command to switch to the next higher SuperBars timeframe.
 */
#include <stddefines.mqh>
int   __InitFlags[] = {INIT_NO_BARS_REQUIRED};
int __DeinitFlags[];
#include <core/script.mqh>
#include <stdfunctions.mqh>


/**
 * Main function
 *
 * @return int - error status
 */
int onStart() {
   SendChartCommand("SuperBars.command", "timeframe:up");
   return(catch("onStart(1)"));
}
