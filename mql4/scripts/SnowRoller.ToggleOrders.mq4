/**
 * SnowRoller.ToggleOrders
 *
 * Send a chart command to SnowRoller to toggle the order display.
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
   string label = "SnowRoller.command";
   string mutex = "mutex."+ label;

   // check chart for SnowRoller
   if (ObjectFind("SnowRoller.status") == 0) {
      // aquire write-lock
      if (!AquireLock(mutex, true)) return(ERR_RUNTIME_ERROR);

      // set command
      if (ObjectFind(label) != 0) {
         if (!ObjectCreate(label, OBJ_LABEL, 0, 0, 0))                return(_int(catch("onStart(1)"), ReleaseLock(mutex)));
         if (!ObjectSet(label, OBJPROP_TIMEFRAMES, OBJ_PERIODS_NONE)) return(_int(catch("onStart(2)"), ReleaseLock(mutex)));
      }
      ObjectSetText(label, "orderdisplay");

      // release lock and notify the chart
      if (!ReleaseLock(mutex)) return(ERR_RUNTIME_ERROR);
      Chart.SendTick();
   }
   else {
      PlaySoundEx("Windows Chord.wav");
      MessageBoxEx(__NAME(), "No sequence found.", MB_ICONEXCLAMATION|MB_OK);
   }

   return(catch("onStart(3)"));
}
