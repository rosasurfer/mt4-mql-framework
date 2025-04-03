/**
 * CustomPositions.LogOrders
 *
 * Send a command to the ChartInfos indicator to log all order tickets of custom positions.
 */
#include <rsf/stddefines.mqh>
int   __InitFlags[] = {INIT_NO_BARS_REQUIRED};
int __DeinitFlags[];
#include <rsf/core/script.mqh>
#include <rsf/stdfunctions.mqh>


/**
 * Main-Funktion
 *
 * @return int - error status
 */
int onStart() {
   string command   = "log-custom-positions";
   string params    = "";
   string modifiers = ifString(IsVirtualKeyDown(VK_SHIFT), "VK_SHIFT", "");

   command = command +":"+ params +":"+ modifiers;

   SendChartCommand("ChartInfos.command", command);
   return(catch("onStart(1)"));
}
