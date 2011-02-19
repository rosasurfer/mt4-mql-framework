/**
 * SendTick.mq4
 *
 * Schickt einen einzelnen Fake-Tick an den aktuellen Chart.
 */
#include <stdlib.mqh>


/**
 * Initialisierung
 *
 * @return int - Fehlerstatus
 */
int init() {
   __SCRIPT__ = WindowExpertName();
   stdlib_init(__SCRIPT__);
   return(catch("init()"));
}


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int start() {
   SendTick(true);
   return(catch("start()"));
}
