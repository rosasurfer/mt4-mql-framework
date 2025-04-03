/**
 * Chart.ToggleUnitSize
 *
 * Sends a command to the ChartInfos indicator to toggle the location of the unitsize display between "top" and "bottom".
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
   string modifiers = "";
   if (IsVirtualKeyDown(VK_ESCAPE))  modifiers = modifiers +",VK_ESCAPE";
   if (IsVirtualKeyDown(VK_TAB))     modifiers = modifiers +",VK_TAB";
   if (IsVirtualKeyDown(VK_CAPITAL)) modifiers = modifiers +",VK_CAPITAL";    // CAPSLOCK key
   if (IsVirtualKeyDown(VK_SHIFT))   modifiers = modifiers +",VK_SHIFT";
   if (IsVirtualKeyDown(VK_CONTROL)) modifiers = modifiers +",VK_CONTROL";
   if (IsVirtualKeyDown(VK_MENU))    modifiers = modifiers +",VK_MENU";       // ALT key
   if (IsVirtualKeyDown(VK_LWIN))    modifiers = modifiers +",VK_LWIN";
   if (IsVirtualKeyDown(VK_RWIN))    modifiers = modifiers +",VK_RWIN";

   SendChartCommand("ChartInfos.command", "toggle-unit-size::"+ StrRight(modifiers, -1));
   return(catch("onStart(1)"));
}
