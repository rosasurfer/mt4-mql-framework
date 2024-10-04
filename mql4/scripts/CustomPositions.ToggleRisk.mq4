/**
 * CustomPositions.ToggleRisk
 *
 * Send a command to the ChartInfos indicator to toggle the MaxRisk display of custom positions.
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
   SendChartCommand("ChartInfos.command", "toggle-risk");
   return(catch("onStart(1)"));
}
