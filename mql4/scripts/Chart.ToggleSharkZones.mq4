/**
 * Chart.ToggleSharkZones
 *
 * Send a command to the ChartInfos indicator to toggle the display of shark zones (zones of hidden institutional activity).
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
   if (This.IsTesting()) Tester.Pause();

   string sVirtualKey = ifString(IsAsyncKeyDown(VK_LSHIFT), "|VK_LSHIFT", "");

   SendChartCommand("ChartInfos.command", "cmd=ToggleSharkZones"+ sVirtualKey);
   return(last_error);
}
