/**
 * ParameterStepper Down
 *
 * Broadcast a command to listening programs to decrease a variable parameter.
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
   if (__isTesting) Tester.Pause();

   string command   = "parameter-down";
   string params    = GetTickCount();
   string modifiers = "";
   if (IsVirtualKeyDown(VK_CAPITAL)) modifiers = modifiers +",VK_CAPITAL";
   if (IsVirtualKeyDown(VK_SHIFT))   modifiers = modifiers +",VK_SHIFT";
   if (IsVirtualKeyDown(VK_LWIN))    modifiers = modifiers +",VK_LWIN";
   modifiers = StrRight(modifiers, -1);

   command = command +":"+ params +":"+ modifiers;

   SendChartCommand("ParameterStepper.command", command);
   return(catch("onStart(1)"));
}
