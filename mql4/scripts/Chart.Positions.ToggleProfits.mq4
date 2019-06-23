/**
 * Schickt dem ChartInfos-Indikator des aktuellen Charts die Nachricht, die Anzeige der P/L-Beträge der Positionen von
 * "absolut" zu "prozentual" umzuschaltem.
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
   SendChartCommand("ChartInfos.command", "cmd=ToggleProfits");
   return(catch("onStart(1)"));
}
