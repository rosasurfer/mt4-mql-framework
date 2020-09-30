/**
 * Reopen the alert dialog window.
 */
#include <stddefines.mqh>
int   __InitFlags[] = {INIT_NO_BARS_REQUIRED};
int __DeinitFlags[];
#include <core/script.mqh>
#include <stdfunctions.mqh>


/**
 * Main function
 *
 * @return int - error status
 */
int onStart() {
   if (!ReopenAlertDialog(true))
      logInfo("onStart(1)  Alert dialog was not opened before.");
   return(catch("onStart(2)"));
}
