/**
 * Schickt dem ChartInfos-Indikator des aktuellen Charts die Nachricht, die Anzeige der offenen Orders umzuschaltem.
 */
#include <stddefines.mqh>
int   __INIT_FLAGS__[] = {INIT_NO_BARS_REQUIRED};
int __DEINIT_FLAGS__[];
#include <core/script.mqh>
#include <stdfunctions.mqh>
#include <rsfLibs.mqh>


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
      return(ERR_RUNTIME_ERROR);


   // (2) Command setzen                                          // TODO: Command zu bereits existierenden Commands hinzufügen
   if (ObjectFind(label) != 0) {
      if (!ObjectCreate(label, OBJ_LABEL, 0, 0, 0))                return(_int(catch("onStart(1)"), ReleaseLock(mutex)));
      if (!ObjectSet(label, OBJPROP_TIMEFRAMES, OBJ_PERIODS_NONE)) return(_int(catch("onStart(2)"), ReleaseLock(mutex)));
   }
   if (!ObjectSetText(label, "cmd=ToggleOpenOrders"))              return(_int(catch("onStart(3)"), ReleaseLock(mutex)));


   // (3) Schreibzugriff auf Command-Object freigeben
   if (!ReleaseLock(mutex))
      return(ERR_RUNTIME_ERROR);


   // (4) Tick senden
   Chart.SendTick();

   return(catch("onStart(4)"));
}
