/**
 * CustomPositions.LogTickets
 *
 * Send a command to the ChartInfos indicator to log tickets of custom positions.
 */
#include <stddefines.mqh>
int   __InitFlags[] = {INIT_NO_BARS_REQUIRED};
int __DeinitFlags[];
#include <core/script.mqh>
#include <stdfunctions.mqh>


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
