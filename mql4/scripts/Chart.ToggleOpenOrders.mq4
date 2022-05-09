/**
 * Chart.ToggleOpenOrders
 *
 * Send a chart command to an active EA or the ChartInfos indicator to toggle the display of open orders.
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

   string label = "EA.status";

   if (ObjectFind(label) == 0) {                                  // check for the chart status of an active EA
      SendChartCommand("EA.command", "toggleOpenOrders");
      return(last_error);
   }

   // no active EA found
   SendChartCommand("ChartInfos.command", "cmd=ToggleOpenOrders");
   return(last_error);
}
