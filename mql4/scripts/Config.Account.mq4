/**
 * Send the command to the ChartInfos indicator to load the current account configuration into the editor.
 */
#include <stddefines.mqh>
int   __INIT_FLAGS__[] = {INIT_NO_BARS_REQUIRED};
int __DEINIT_FLAGS__[];
#include <core/script.mqh>
#include <stdfunctions.mqh>
#include <rsfLibs.mqh>


/**
 * Main function
 *
 * @return int - error status
 */
int onStart() {
   SendChartCommand("ChartInfos.command", "cmd=EditAccountConfig");
   return(catch("onStart(1)"));
}
