/**
 * Chart.ToggleOpenOrders
 *
 * Send a command to the ChartInfos indicator or an active EA to toggle the display of open orders.
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

   string sVirtualKey = ifString(IsAsyncKeyDown(VK_LSHIFT), "|VK_LSHIFT", "");

   // check chart for an active EA
   string label = "EA.status";
   if (ObjectFind(label) == 0) {
      SendChartCommand("EA.command", "toggleOpenOrders"+ sVirtualKey);
      return(last_error);
   }

   // no EA found
   SendChartCommand("ChartInfos.command", "cmd=ToggleOpenOrders"+ sVirtualKey);
   return(last_error);
}
