/**
 * SuperBars Down
 *
 * Schickt dem SuperBars-Indikator im aktuellen Chart die Nachricht, den nächstniedrigeren SuperTimeframe anzuzeigen.
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
   // (1) Schreibzugriff auf Command-Object synchronisieren (Lesen ist ohne Lock möglich)
   string mutex = "mutex.SuperBar.command";
   if (!AquireLock(mutex, true))
      return(SetLastError(stdlib.GetLastError()));


   // (2) Command setzen
   string label = "SuperBar.command";                             // TODO: Command zu bereits existierenden Commands hinzufügen
   if (ObjectFind(label) != 0) {
      if (!ObjectCreate(label, OBJ_LABEL, 0, 0, 0))                return(_int(catch("onStart(1)"), ReleaseLock(mutex)));
      if (!ObjectSet(label, OBJPROP_TIMEFRAMES, OBJ_PERIODS_NONE)) return(_int(catch("onStart(2)"), ReleaseLock(mutex)));
   }
   if (!ObjectSetText(label, "Timeframe=-1"))                      return(_int(catch("onStart(3)"), ReleaseLock(mutex)));


   // (3) Schreibzugriff auf Command-Object freigeben
   if (!ReleaseLock(mutex))
      return(SetLastError(stdlib.GetLastError()));


   // (4) Tick senden
   Chart.SendTick(false);

   return(catch("onStart(4)"));
}
