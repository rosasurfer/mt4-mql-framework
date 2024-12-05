/**
 * Reopen the alert dialog window.
 */
#include <rsf/stddefines.mqh>
int   __InitFlags[] = {INIT_NO_BARS_REQUIRED};
int __DeinitFlags[];
#include <rsf/core/script.mqh>
#include <rsf/stdfunctions.mqh>


/**
 * Main function
 *
 * @return int - error status
 */
int onStart() {
   if (!ReopenAlertDialog(false)) {
      PlaySoundEx("Plonk.wav");                 // "Alert" window not found
   }
   return(catch("onStart(1)"));
}
