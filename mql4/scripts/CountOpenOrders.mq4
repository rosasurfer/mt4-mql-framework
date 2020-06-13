/**
 * Loggt die Anzahl der offenen Tickets.
 */
#include <stddefines.mqh>
int   __INIT_FLAGS__[] = {INIT_NO_BARS_REQUIRED};
int __DEINIT_FLAGS__[];
#include <core/script.mqh>
#include <stdfunctions.mqh>


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onStart() {
   string msg = OrdersTotal() +" open orders";
   log("onStart()  "+ msg);
   Comment(NL, NL, NL, msg);
   return(last_error);
}
