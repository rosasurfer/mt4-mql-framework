/**
 * CustomPositions.ToggleMaxExposure
 *
 * Send a command to the ChartInfos indicator to toggle the MaxExposure display of custom positions.
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
   SendChartCommand("ChartInfos.command", "toggle-max-exposure");
   return(catch("onStart(1)"));
}
