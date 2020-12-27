/**
 * Schickt dem TradeTerminal die Nachricht, eine "Sell Market"-Order für das aktuelle Symbol auszuführen. Muß auf dem
 * jeweiligen LFX-Chart ausgeführt werden.
 */
#include <stddefines.mqh>
int   __InitFlags[];
int __DeinitFlags[];

#include <core/script.mqh>
#include <stdfunctions.mqh>


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
