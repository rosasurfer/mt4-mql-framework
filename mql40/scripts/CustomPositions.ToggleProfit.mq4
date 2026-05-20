/**
 * CustomPositions.ToggleProfit
 *
 * Sends a command to the ChartInfos indicator in the current chart to toggle displayed profits of custom positions
 * between absolute and percentage values.
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
   string command = "toggle-profit::"+ keys;

   SendChartCommand("ChartInfos.command", command);
   return(last_error);
}
