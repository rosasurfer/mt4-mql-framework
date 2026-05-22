/**
 * ParameterStepper Up
 *
 * Sends a command to listening programs to increase a program-specific parameter.
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

   int keys = GetPressedVirtualKeys(F_VK_ALL);
   string command = "parameter:up:"+ keys;

   SendChartCommand("ParameterStepper.command", command);
   return(last_error);
}
