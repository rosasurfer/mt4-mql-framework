/**
 * SuperBars Up
 *
 * Sends a command to the SuperBars indicator in the current chart to switch to the next higher timeframe.
 */
#include <rsf/stddefines.mqh>
int   __InitFlags[] = {INIT_NO_BARS_REQUIRED};
int __DeinitFlags[];
#include <rsf/core/script.mqh>
#include <rsf/stdfunctions.mqh>


/**
 * Main function
 *
 * @return int - error status
 */
int onStart() {
   if (__isTesting) Tester.Pause();

   int keys = GetPressedVirtualKeys(F_VK_ALL);
   string command = "";

   if (keys & F_VK_SHIFT && 1) {
      command = "barwidth:increase:"+ keys;
      SendChartCommand("TrendBars.command", command);
   }
   else {
      command = "timeframe:up:"+ keys;
      SendChartCommand("SuperBars.command", command);
   }
   return(last_error);
}
