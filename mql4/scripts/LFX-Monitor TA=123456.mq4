/**
 * Schickt dem LFX-Monitor-Indikator des aktuellen Charts die Nachricht, den Trade-Account umzuschalten.
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
   SendChartCommand("LFX-Monitor.command", "trade-account:{account-company},{account-number}");
   return(catch("onStart(1)"));
}
