/**
 * TestScript
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[] = { INIT_NO_BARS_REQUIRED };
int __DEINIT_FLAGS__[];
#include <core/script.mqh>
#include <stdfunctions.mqh>
#include <stdlib.mqh>

#include <structs/xtrade/ExecutionContext.mqh>


#import "Expander.Release.dll"
   bool   SubclassWindow(int hWnd);
   bool   UnsubclassWindow(int hWnd);
   int    Test();
#import


/**
 * Main function
 *
 * @return int - error status
 */
int onStart() {
   debug("onStart(1)  ec="+ EXECUTION_CONTEXT_toStr(__ExecutionContext, false));

   return(catch("onStart(2)"));



   // -------------------------------------------------------------------------------------
   int hWnd = ec_hChart(__ExecutionContext);
   debug("onStart(2)  SubclassWindow()   => "+ SubclassWindow(hWnd));
   debug("onStart(3)  UnsubclassWindow() => "+ UnsubclassWindow(hWnd));
   return(catch("onStart(4)"));

   EXECUTION_CONTEXT_toStr(__ExecutionContext, NULL);
}
