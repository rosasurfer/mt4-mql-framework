/**
 * CustomPositions.ToggleRisk
 *
 * Send a command to the ChartInfos indicator to toggle the MaxRisk display of custom positions.
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
   SendChartCommand("ChartInfos.command", "toggle-risk");
   return(catch("onStart(1)"));
}
