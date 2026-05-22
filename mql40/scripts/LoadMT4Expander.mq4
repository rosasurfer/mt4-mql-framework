/**
 * LoadMT4Expander
 *
 * Load the MT4Expander. Any MQL program using the framework will implicitly load it during initialization.
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
   LoadMT4Expander();
   return(last_error);
}
