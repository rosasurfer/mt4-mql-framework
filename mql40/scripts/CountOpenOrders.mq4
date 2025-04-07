/**
 * Loggt die Anzahl der offenen Tickets.
 */
#include <rsf/stddefines.mqh>
int   __InitFlags[] = {INIT_NO_BARS_REQUIRED};
int __DeinitFlags[];
#include <rsf/core/script.mqh>
#include <rsf/stdfunctions.mqh>


/**
 * Main-Funktion
 *
 * @return int - error status
 */
int onStart() {
   string msg = OrdersTotal() +" open orders";
   logInfo("onStart(1)  "+ msg);
   Comment(NL, NL, NL, msg);
   return(last_error);
}
