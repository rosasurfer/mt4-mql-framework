/**
 * TestScript
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <core/script.mqh>
//#include <stdlib.mqh>

//#include <structs/pewa/ORDER_EXECUTION.mqh>


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onStart() {
   catch("onStart()");
   return(last_error);
}
