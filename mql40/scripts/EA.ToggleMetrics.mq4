/**
 * EA.ToggleMetrics
 *
 * Sends a command to an EA in the current chart to toggle the status display between available metrics.
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
   int keys = GetPressedVirtualKeys(F_VK_ALL);
   string command = "toggle-metrics::"+ keys;

   // send the command to an existing EA
   if (ObjectFind("EA.status") == 0) {
      SendChartCommand("EA.command", command);
   }
   return(last_error);
}
