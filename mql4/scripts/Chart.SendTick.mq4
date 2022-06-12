/**
 * Schickt einen künstlichen Tick an den aktuellen Chart.
 */
#include <stddefines.mqh>
int   __InitFlags[] = {INIT_NO_BARS_REQUIRED};
int __DeinitFlags[];
#include <core/script.mqh>
#include <stdfunctions.mqh>


/**
 * Main-Funktion
 *
 * @return int - error status
 */
int onStart() {
   return(Chart.SendTick(true));
}


