/**
 * Schickt dem LFX-Monitor-Indikator des aktuellen Charts die Nachricht, den Trade-Account umzuschalten.
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
   SendChartCommand("LFX-Monitor.command", "trade-account:{account-company}:{account-number}");
   return(catch("onStart(1)"));
}
