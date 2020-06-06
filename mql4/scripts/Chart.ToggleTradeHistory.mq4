/**
 * Schickt dem ChartInfos-Indikator des aktuellen Charts die Nachricht, die Anzeige der Trade-History umzuschaltem.
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
   SendChartCommand("ChartInfos.command", "cmd=ToggleTradeHistory");
   return(catch("onStart(1)"));
}
