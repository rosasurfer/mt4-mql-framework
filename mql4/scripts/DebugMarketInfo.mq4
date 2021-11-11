/**
 * Gibt alle verfügbaren MarketInfos des aktuellen Instruments aus.
 */
#include <stddefines.mqh>
int   __InitFlags[] = {INIT_NO_BARS_REQUIRED};
int __DeinitFlags[];
#include <core/script.mqh>
#include <stdfunctions.mqh>
#include <rsfLib.mqh>


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onStart() {
   DebugMarketInfo("onStart()");
   return(last_error);
}
