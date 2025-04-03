/**
 * EA.ToggleMetrics
 *
 * Send a command to a running EA to toggle the status between calculated/displayed metrics.
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
   string command   = "toggle-metrics";
   string params    = "";
   string modifiers = ifString(IsVirtualKeyDown(VK_SHIFT), "VK_SHIFT", "");

   command = command +":"+ params +":"+ modifiers;

   // send to an active EA
   if (ObjectFind("EA.status") == 0) {
      SendChartCommand("EA.command", command);
   }
   return(last_error);
}
