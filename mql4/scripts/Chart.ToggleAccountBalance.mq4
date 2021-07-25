/**
 * Chart.ToggleAccountBalance
 *
 * Send a command to the ChartInfos indicator to toggle the display of the account balance.
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
   SendChartCommand("ChartInfos.command", "cmd=ToggleAccountBalance");
   return(catch("onStart(1)"));
}
