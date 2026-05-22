/**
 * Chart.ToggleUnitSize
 *
 * Sends a command to the ChartInfos indicator in the current chart to toggle the "unitsize" location between
 * "top" and "bottom".
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
   string command = "toggle-unit-size::"+ keys;

   SendChartCommand("ChartInfos.command", command);
   return(last_error);
}
