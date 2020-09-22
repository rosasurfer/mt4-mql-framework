/**
 * Loggt die Anzahl der offenen Tickets.
 */
#include <stddefines.mqh>
int   __InitFlags[] = {INIT_NO_BARS_REQUIRED};
int __DeinitFlags[];
#include <core/script.mqh>
#include <stdfunctions.mqh>


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onStart() {
   string msg = OrdersTotal() +" open orders";
   logInfo("onStart(1)  "+ msg);
   Comment(NL, NL, NL, msg);
   return(last_error);
}
