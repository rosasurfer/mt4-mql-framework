/**
 * TestScript
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[] = { INIT_DOESNT_REQUIRE_BARS };
int __DEINIT_FLAGS__[];
#include <core/script.mqh>
#include <stdfunctions.mqh>
#include <stdlib.mqh>

#include <structs/myfx/ExecutionContext.mqh>


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
   string result;

   debug("onStart(1)  dll = "+ EXECUTION_CONTEXT_toStr(__ExecutionContext, false));

   return(catch("onStart(99)"));



   // -------------------------------------------------------------------------------------
   int hWnd = ec_hChart(__ExecutionContext);
   debug("onStart(2)  SubclassWindow()   => "+ SubclassWindow(hWnd));
   debug("onStart(3)  UnsubclassWindow() => "+ UnsubclassWindow(hWnd));
   return(catch("onStart(4)"));

   EXECUTION_CONTEXT_toStr(__ExecutionContext, NULL);
}
