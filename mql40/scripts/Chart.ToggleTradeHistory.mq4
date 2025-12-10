/**
 * Chart.ToggleTradeHistory
 *
 * Sends a command to EA or ChartInfos indicator in the current chart to toggle the display of closed trades.
 */
#include <rsf/stddefines.mqh>
int   __InitFlags[] = {INIT_NO_BARS_REQUIRED};
int __DeinitFlags[];
#include <rsf/core/script.mqh>
#include <rsf/stdfunctions.mqh>
#include <rsf/win32api.mqh>


/**
 * Main function
 *
 * @return int - error status
 */
int onStart() {
   if (__isTesting) Tester.Pause();

   int virtKeys = GetPressedVirtualKeys(F_VK_ALL);
   string command = "toggle-trade-history::"+ virtKeys;

   bool isEA       = (ObjectFind("EA.status") == 0);
   bool isShiftKey = (virtKeys & F_VK_SHIFT && 1);
   bool isWinKey   = (virtKeys & F_VK_LWIN  && 1);

   // send the command to an existing EA or the chart
   if (isEA && !isShiftKey && !isWinKey) SendChartCommand("EA.command", command);
   else                                  SendChartCommand("ChartInfos.command", command);
   return(last_error);
}
