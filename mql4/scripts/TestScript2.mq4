/**
 * TestScript
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[] = { INIT_NO_BARS_REQUIRED };
int __DEINIT_FLAGS__[];
#include <core/script.mqh>
#include <stdfunctions.mqh>
#include <stdlib.mqh>


#import "test/testlibrary.ex4"
   void fn();
#import


/**
 * Main function
 *
 * @return int - error status
 */
int onStart() {

   fn();

   return(catch("onStart(1)"));
}
