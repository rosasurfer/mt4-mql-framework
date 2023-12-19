/**
 * Chart.ToggleOpenOrders
 *
 * Send a command to a running EA or the ChartInfos indicator to toggle the display of open orders.
 */
#include <stddefines.mqh>
int   __InitFlags[] = { INIT_NO_BARS_REQUIRED };
int __DeinitFlags[];
#include <core/script.mqh>
#include <stdfunctions.mqh>


/**
 * Main function
 *
 * @return int - error status
 */
int onStart() {
   if (__isTesting) Tester.Pause();

   string command   = "toggle-open-orders";
   string params    = "";
   string modifiers = ifString(IsVirtualKeyDown(VK_SHIFT), "VK_SHIFT", "");

   command = command +":"+ params +":"+ modifiers;

   // send to a running EA or the ChartInfos indicator
   if (ObjectFind("EA.status") == 0) SendChartCommand("EA.command", command);
   else                              SendChartCommand("ChartInfos.command", command);
   return(last_error);
}
