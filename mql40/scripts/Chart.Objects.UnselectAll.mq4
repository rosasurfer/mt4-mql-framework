/**
 * Chart.Objects.UnselectAll
 *
 * Executes the main menu command Charts->Objects->Unselect-All.
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
   Chart.Objects.UnselectAll();
   return(last_error);
}
