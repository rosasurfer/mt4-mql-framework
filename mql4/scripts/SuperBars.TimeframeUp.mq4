/**
 * SuperBars Up
 *
 * Send the SuperBars indicator a command to switch to the next higher SuperBars timeframe.
 */
#include <stddefines.mqh>
int   __INIT_FLAGS__[] = {INIT_NO_BARS_REQUIRED};
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
   // synchronize access of the Command object
   string mutex = "mutex.SuperBars.command";
   if (!AquireLock(mutex, true))
      return(ERR_RUNTIME_ERROR);

   // set Command
   string label = "SuperBars.command";                             // TODO: add Command to existing ones
   if (ObjectFind(label) != 0) {
      if (!ObjectCreate(label, OBJ_LABEL, 0, 0, 0))                return(_int(catch("onStart(1)"), ReleaseLock(mutex)));
      if (!ObjectSet(label, OBJPROP_TIMEFRAMES, OBJ_PERIODS_NONE)) return(_int(catch("onStart(2)"), ReleaseLock(mutex)));
   }
   if (!ObjectSetText(label, "Timeframe=Up"))                      return(_int(catch("onStart(3)"), ReleaseLock(mutex)));

   // release locked Command object
   if (!ReleaseLock(mutex))
      return(ERR_RUNTIME_ERROR);

   // send a tick
   Chart.SendTick();
   return(catch("onStart(4)"));
}
