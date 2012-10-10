/**
 * Gibt alle verfügbaren MarketInfos des aktuellen Instruments aus.
 */
#include <core/define.mqh>
#define     __TYPE__    T_SCRIPT
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <stddefine.mqh>
#include <stdlib.mqh>

#include <core/script.mqh>


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onStart() {
   DebugMarketInfo();
   return(catch("onStart()"));
}
