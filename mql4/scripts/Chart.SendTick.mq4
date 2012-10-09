/**
 * Schickt einen einzelnen Fake-Tick an den aktuellen Chart.
 */
#include <stdtypes.mqh>
#define     __TYPE__    T_SCRIPT
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <stddefine.mqh>
#include <stdlib.mqh>


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onStart() {
   return(Chart.SendTick(true));
}


