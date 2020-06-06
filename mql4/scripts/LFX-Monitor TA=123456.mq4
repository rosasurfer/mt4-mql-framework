/**
 * Schickt dem LFX-Monitor-Indikator des aktuellen Charts die Nachricht, den Trade-Account umzuschalten.
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
   SendChartCommand("LFX-Monitor.command", "cmd=account:"+ AC.ICMarkets +":"+ 123456);
   return(catch("onStart(1)"));
}
