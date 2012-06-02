/**
 * Schickt einen einzelnen Fake-Tick an den aktuellen Chart.
 */
#include <types.mqh>
#define     __TYPE__    T_SCRIPT
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <stdlib.mqh>


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onStart() {
   return(Chart.SendTick(true));
}


