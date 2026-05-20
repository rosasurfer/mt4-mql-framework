/**
 * Chart.ToggleOpenOrders
 *
 * Sends a command to an EA or a ChartInfos indicator in the current chart to toggle the display of open orders.
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
   string command = "toggle-open-orders::"+ keys;

   bool isEA     = (ObjectFind("EA.status") == 0);
   bool shiftKey = (keys & F_VK_SHIFT && 1);
   bool winKey   = (keys & F_VK_LWIN  && 1);

   // send the command to an existing EA or the chart
   if (isEA && !shiftKey && !winKey) SendChartCommand("EA.command", command);
   else                              SendChartCommand("ChartInfos.command", command);
   return(last_error);
}
