/**
 * Schickt dem ChartInfos-Indikator des aktuellen Charts die Nachricht, einmalig die Tickets der aktuellen Positionen zu
 * loggen.
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
   SendChartCommand("ChartInfos.command", "cmd=LogPositionTickets");
   return(catch("onStart(1)"));
}
