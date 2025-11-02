/**
 * SuperBars Up
 *
 * Sends a command to the SuperBars indicator in the current chart to switch to the next higher timeframe.
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
   if (__isTesting) Tester.Pause();

   bool isVkShift = IsVirtualKeyDown(VK_SHIFT);
   string command = "", params = "", modifiers = ",";
   if (IsVirtualKeyDown(VK_ESCAPE))  modifiers = modifiers +",VK_ESCAPE";
   if (IsVirtualKeyDown(VK_TAB))     modifiers = modifiers +",VK_TAB";
   if (IsVirtualKeyDown(VK_CAPITAL)) modifiers = modifiers +",VK_CAPITAL";    // CAPSLOCK key
   if (isVkShift)                    modifiers = modifiers +",VK_SHIFT";
   if (IsVirtualKeyDown(VK_CONTROL)) modifiers = modifiers +",VK_CONTROL";
   if (IsVirtualKeyDown(VK_MENU))    modifiers = modifiers +",VK_MENU";       // ALT key
   if (IsVirtualKeyDown(VK_LWIN))    modifiers = modifiers +",VK_LWIN";
   if (IsVirtualKeyDown(VK_RWIN))    modifiers = modifiers +",VK_RWIN";
   modifiers = StrRight(modifiers, -1);

   if (isVkShift) {
      command = "barwidth";
      params  = "increase";
      command = command +":"+ params +":"+ modifiers;
      SendChartCommand("TrendBars.command", command);
   }
   else {
      command = "timeframe";
      params  = "up";
      command = command +":"+ params +":"+ modifiers;
      SendChartCommand("SuperBars.command", command);
   }
   return(catch("onStart(1)"));
}
