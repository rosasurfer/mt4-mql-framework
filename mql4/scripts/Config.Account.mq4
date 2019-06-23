/**
 * Schickt dem ChartInfos-Indikator des aktuellen Charts die Nachricht, die Konfigurationsdatei des aktuellen Accounts in den
 * Editor zu laden.
 */
#include <stddefines.mqh>
int   __INIT_FLAGS__[] = {INIT_NO_BARS_REQUIRED};
int __DEINIT_FLAGS__[];
#include <core/script.mqh>
#include <stdfunctions.mqh>


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onStart() {
   SendChartCommand("ChartInfos.command", "cmd=EditAccountConfig");
   return(catch("onStart(1)"));
}
