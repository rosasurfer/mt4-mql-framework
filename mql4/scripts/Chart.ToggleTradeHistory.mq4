/**
 * Chart.ToggleTradeHistory
 *
 * Send a command to the ChartInfos indicator or an active EA to toggle the display of the trade history.
 */
#include <stddefines.mqh>
int   __InitFlags[] = {INIT_NO_BARS_REQUIRED};
int __DeinitFlags[];
#include <core/script.mqh>
#include <stdfunctions.mqh>
#include <win32api.mqh>


/**
 * Main function
 *
 * @return int - error status
 */
int onStart() {
   if (This.IsTesting()) Tester.Pause();

   string sVirtualKey = ifString(IsVirtualKeyDown(VK_LSHIFT), "|VK_LSHIFT", "");

   // check chart for an active EA
   string label = "EA.status";
   if (ObjectFind(label) == 0) {
      SendChartCommand("EA.command", "toggleTradeHistory"+ sVirtualKey);
      return(last_error);
   }

   // no active EA found
   SendChartCommand("ChartInfos.command", "cmd=ToggleTradeHistory"+ sVirtualKey);
   return(last_error);
}
