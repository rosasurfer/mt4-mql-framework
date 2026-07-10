/**
 * Schickt dem TradeTerminal die Nachricht, eine "Buy Market"-Order f�r das aktuelle Symbol auszuf�hren. Muß auf dem
 * jeweiligen LFX-Chart ausgef�hrt werden.
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
