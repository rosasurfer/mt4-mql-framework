/**
 * Gibt alle verfügbaren MarketInfos des aktuellen Instruments aus.
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
   DebugMarketInfo("onStart()");
   return(last_error);
}
