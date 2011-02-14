/**
 * SendTick.mq4
 *
 * Schickt einen einzelnen Fake-Tick an den aktuellen Chart.
 */
#include <stdlib.mqh>


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int start() {
   SendTick(true);
   return(catch("start()"));
}
