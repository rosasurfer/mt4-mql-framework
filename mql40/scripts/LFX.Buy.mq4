/**
 * Schickt dem TradeTerminal die Nachricht, eine "Buy Market"-Order für das aktuelle Symbol auszuführen. Muß auf dem
 * jeweiligen LFX-Chart ausgeführt werden.
 */
#include <rsf/stddefines.mqh>
int   __InitFlags[];
int __DeinitFlags[];
#include <rsf/core/script.mqh>
#include <rsf/stdfunctions.mqh>


/**
 * Main function
 *
 * @return int - error status
 */
int onStart() {
   return(last_error);
}
