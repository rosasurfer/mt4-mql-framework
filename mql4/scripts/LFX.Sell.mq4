/**
 * Schickt dem TradeTerminal die Nachricht, eine "Sell Market"-Order für das aktuelle Symbol auszuführen. Muß auf dem
 * jeweiligen LFX-Chart ausgeführt werden.
 */
#include <stddefines.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];

#include <core/script.mqh>
#include <stdfunctions.mqh>
#include <rsfLibs.mqh>


/**
 * Initialisierung
 *
 * @return int - Fehlerstatus
 */
int onInit() {
   return(last_error);
}


/**
 * Deinitialisierung
 *
 * @return int - Fehlerstatus
 */
int onDeinit() {
   return(last_error);
}


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onStart() {
   return(last_error);
}
