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

   string label = "Duel.status";

   if (ObjectFind(label) == 0) {                                     // chart status of a Duel instance found
      if (StrToInteger(StrTrim(ObjectDescription(label))) > 0) {     // check for a valid instance id: format {sid}|{status}
         SendChartCommand("Duel.command", "ToggleTradeHistory");
         return(last_error);
      }
   }

   // no active Duel instance found
   SendChartCommand("ChartInfos.command", "cmd=ToggleTradeHistory");
   return(last_error);
}
