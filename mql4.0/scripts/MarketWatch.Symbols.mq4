/**
 * Ruft den Kontextmenü-Befehl MarketWatch->Symbols auf.
 */
#include <rsf/stddefines.mqh>
int   __InitFlags[] = {INIT_NO_BARS_REQUIRED};
int __DeinitFlags[];
#include <rsf/core/script.mqh>
#include <rsf/stdfunctions.mqh>
#include <rsf/stdlib.mqh>


/**
 * Main-Funktion
 *
 * @return int - error status
 */
int onStart() {
   return(MarketWatch.Symbols());
}
