/**
 * DebugMarketInfo
 *
 * Print all MarketInfo() data of the current symbol to the debug output.
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
   DebugMarketInfo("onStart()");
   return(last_error);
}
