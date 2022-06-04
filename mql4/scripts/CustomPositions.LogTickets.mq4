/**
 * Schickt dem ChartInfos-Indikator des aktuellen Charts die Nachricht, einmalig die Tickets der aktuellen Positionen zu
 * loggen.
 */
#include <stddefines.mqh>
int   __InitFlags[] = {INIT_NO_BARS_REQUIRED};
int __DeinitFlags[];
#include <core/script.mqh>
#include <stdfunctions.mqh>


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onStart() {
   SendChartCommand("ChartInfos.command", "log-custom-positions");
   return(catch("onStart(1)"));
}
