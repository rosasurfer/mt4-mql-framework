/**
 * Chart.ToggleAccountBalance
 *
 * Send a command to the ChartInfos indicator to toggle the display of the account balance.
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
   SendChartCommand("ChartInfos.command", "toggle-account-balance");
   return(catch("onStart(1)"));
}
