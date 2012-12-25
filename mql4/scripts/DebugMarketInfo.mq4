/**
 * Gibt alle verfügbaren MarketInfos des aktuellen Instruments aus.
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <stdlib.mqh>

#include <core/script.mqh>


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onStart() {
   DebugMarketInfo("onStart()");
   return(catch("onStart()"));
}
