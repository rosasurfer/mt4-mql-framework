/**
 * SnowRoller.ToggleOrders
 *
 * Send a chart command to SnowRoller to toggle the order display.
 *
 * @see  SnowRoller::ToggleOrderDisplayMode()
 */
#include <stddefines.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <core/script.mqh>
#include <stdfunctions.mqh>
#include <rsfLibs.mqh>


/**
 * Main function
 *
 * @return int - error status
 */
int onStart() {
   // check chart for SnowRoller
   if (ObjectFind("SnowRoller.status") == 0) {
      SendChartCommand("SnowRoller.command", "orderdisplay");
   }
   else {
      PlaySoundEx("Windows Chord.wav");
      MessageBoxEx(__NAME(), "No sequence found.", MB_ICONEXCLAMATION|MB_OK);
   }
   return(catch("onStart(1)"));
}
