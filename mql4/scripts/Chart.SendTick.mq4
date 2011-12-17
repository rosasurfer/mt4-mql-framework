/**
 * Schickt einen einzelnen Fake-Tick an den aktuellen Chart.
 */
#include <stdlib.mqh>
#include <win32api.mqh>


/**
 * Initialisierung
 *
 * @return int - Fehlerstatus
 */
int init() {
   __TYPE__ = T_SCRIPT; __SCRIPT__ = WindowExpertName();
   stdlib_init(__TYPE__, __SCRIPT__);
   return(NO_ERROR);
}


/**
 * Deinitialisierung
 *
 * @return int - Fehlerstatus
 */
int deinit() {
   return(catch("deinit()"));
}


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onStart() {
   SendTick(true);
   return(catch("onTick()"));
}


