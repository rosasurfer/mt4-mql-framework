/**
 * Chart.ToggleTradeHistory
 *
 * Send a command to active listeners (Duel or ChartInfos) to toggle the display of the trade history. A Duel instance is
 * preferred.
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
   if (This.IsTesting()) Tester.Pause();

   if (false && ObjectFind("Duel.status")==0) {
      // chart status object of an active Duel instance found
      SendChartCommand("Duel.command", "ToggleTradeHistory");
   }
   else {
      // no active Duel instance found
      SendChartCommand("ChartInfos.command", "cmd=ToggleTradeHistory");
   }
   return(catch("onStart(1)"));
}
