/**
 * TestScript
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[] = { INIT_NO_BARS_REQUIRED };
int __DEINIT_FLAGS__[];
#include <core/script.mqh>
#include <stdfunctions.mqh>
#include <stdlib.mqh>


//#import "test/testlibrary.ex4"
//   void fn();
//#import


string values[];


/**
 * Main function
 *
 * @return int - error status
 */
int onStart() {
   ArrayResize(values, 1);

   string msg = "  values[0]="+ DoubleQuoteStr(values[0]);
   debug("onStart(0.1)  "+ msg);

   return(catch("onStart(1)"));
}
