/**
 * SnowRoller.ToggleOrders
 *
 * Send a chart command to SnowRoller to toggle the order display.
 *
 * @see  SnowRoller::ToggleOrderDisplayMode()
 */
#include <stddefines.mqh>
int   __InitFlags[];
int __DeinitFlags[];
#include <core/script.mqh>
#include <stdfunctions.mqh>


/**
 * Main function
 *
 * @return int - error status
 */
int onStart() {
   // check chart for SnowRoller
   if (ObjectFind("EA.status") == 0) {
      SendChartCommand("EA.command", "orderdisplay");
   }
   else {
      PlaySoundEx("Windows Chord.wav");
      MessageBoxEx(ProgramName(), "No sequence found.", MB_ICONEXCLAMATION|MB_OK);
   }
   return(catch("onStart(1)"));
}
