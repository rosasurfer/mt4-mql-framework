/**
 * SnowRoller.ToggleOrders
 *
 * Send a command to a running SnowRoller instance to toggle the order display.
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
   // check chart for an active EA
   if (ObjectFind("EA.status") == 0) {
      SendChartCommand("EA.command", "order-display");
   }
   else {
      PlaySoundEx("Windows Chord.wav");
      MessageBoxEx(ProgramName(), "No running EA found.", MB_ICONEXCLAMATION|MB_OK);
   }
   return(catch("onStart(1)"));
}
