/**
 * Schickt dem ChartInfos-Indikator des aktuellen Charts die Nachricht, die Assets-under-Management-Anzeige umzuschalten.
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
   SendChartCommand("ChartInfos.command", "cmd=ToggleAuM");
   return(catch("onStart(1)"));
}
