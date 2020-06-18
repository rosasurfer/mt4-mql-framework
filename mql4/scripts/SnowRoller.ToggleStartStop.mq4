/**
 * SnowRoller.ToggleStartStop
 *
 * Send a chart command to SnowRoller to toggle the display of sequence start/stop markers.
 */
#include <stddefines.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <core/script.mqh>
#include <stdfunctions.mqh>


/**
 * Main function
 *
 * @return int - error status
 */
int onStart() {
   // check chart for SnowRoller
   if (ObjectFind("SnowRoller.status") == 0) {
      SendChartCommand("SnowRoller.command", "startstopdisplay");
   }
   else {
      PlaySoundEx("Windows Chord.wav");
      MessageBoxEx(__NAME(), "No sequence found.", MB_ICONEXCLAMATION|MB_OK);
   }
   return(catch("onStart(1)"));
}
