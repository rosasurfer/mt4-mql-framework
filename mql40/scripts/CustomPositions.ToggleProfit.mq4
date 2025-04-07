/**
 * Schickt dem ChartInfos-Indikator des aktuellen Charts die Nachricht, die Anzeige der PL-Beträge der Positionen von
 * "absolut" zu "prozentual" umzuschaltem.
 */
#include <rsf/stddefines.mqh>
int   __InitFlags[] = {INIT_NO_BARS_REQUIRED};
int __DeinitFlags[];
#include <rsf/core/script.mqh>
#include <rsf/stdfunctions.mqh>


/**
 * Main-Funktion
 *
 * @return int - error status
 */
int onStart() {
   SendChartCommand("ChartInfos.command", "toggle-profit");
   return(catch("onStart(1)"));
}
