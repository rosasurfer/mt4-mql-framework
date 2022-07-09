/**
 * ParameterStepper Up
 *
 * Broadcast a command to listening programs to increase a variable parameter.
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

   string command   = "parameter-up";
   string params    = GetTickCount();
   string modifiers = ifString(IsVirtualKeyDown(VK_SHIFT), "VK_SHIFT", "");

   command = command +":"+ params +":"+ modifiers;

   SendChartCommand("ParameterStepper.command", command);
   return(catch("onStart(1)"));
}
