/**
 * MarketWatch.Symbols
 *
 * Executes the main menu command View->Symbols.
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
   MarketWatch.Symbols();
   return(last_error);
}
