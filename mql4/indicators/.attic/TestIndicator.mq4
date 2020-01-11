/**
 * TestIndicator
 */
#include <stddefines.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <rsfLibs.mqh>

#property indicator_chart_window


#import "test/testlibrary.ex4"
   int ex4_GetIntValue(int value);
#import


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   static bool done = false;
   if (!done) {

      int bar = 1;
      double price = iMA(NULL, -1, -1, 0, MODE_SMA, -1, bar); // result: on invalid parameters iMA doesn't set any errors

      debug("onTick()  price = "+ price);
      done = true;
   }
   return(catch("onTick(1)"));
}
