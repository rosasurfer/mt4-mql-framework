/**
 * Schickt dem TradeTerminal die Nachricht, eine "Buy Market"-Order f�r das aktuelle Symbol auszuf�hren. Mu� auf dem
 * jeweiligen LFX-Chart ausgef�hrt werden.
 */
#include <rsf/stddefines.mqh>
int   __InitFlags[];
int __DeinitFlags[];

#include <rsf/core/script.mqh>
#include <rsf/stdfunctions.mqh>


/**
 * Initialisierung
 *
 * @return int - error status
 */
int onInit() {
   return(last_error);
}


/**
 * Deinitialisierung
 *
 * @return int - error status
 */
int onDeinit() {
   return(last_error);
}


/**
 * Main-Funktion
 *
 * @return int - error status
 */
int onStart() {
   return(last_error);
}
