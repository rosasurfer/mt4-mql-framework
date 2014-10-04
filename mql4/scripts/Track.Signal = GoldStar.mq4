/**
 * Schickt dem ChartInfos-Indikator im aktuellen Chart das Command, den internen Parameter "Track.Signal" umzuschalten.
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <core/script.mqh>
#include <stdlib.mqh>


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onStart() {
   string label = "ChartInfos.command";
   string mutex = "mutex."+ label;


   // (1) Schreibzugriff auf Command-Object synchronisieren (Lesen ist ohne Lock möglich)
   if (!AquireLock(mutex, true))
      return(SetLastError(stdlib.GetLastError()));


   // (2) Command setzen                                          // TODO: Command zu bereits existierenden Commands hinzufügen
   if (ObjectFind(label) != 0) {
      if (!ObjectCreate(label, OBJ_LABEL, 0, 0, 0))                return(_int(catch("onStart(1)"), ReleaseLock(mutex)));
      if (!ObjectSet(label, OBJPROP_TIMEFRAMES, OBJ_PERIODS_NONE)) return(_int(catch("onStart(2)"), ReleaseLock(mutex)));
   }
   if (!ObjectSetText(label, "Track.Signal=goldstar"))             return(_int(catch("onStart(3)"), ReleaseLock(mutex)));


   // (3) Schreibzugriff auf Command-Object freigeben
   if (!ReleaseLock(mutex))
      return(SetLastError(stdlib.GetLastError()));


   // (4) Tick senden
   Chart.SendTick(false);

   return(catch("onStart(4)"));
}
