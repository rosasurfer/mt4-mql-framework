/**
 * TestIndicator
 */
#property indicator_chart_window
#include <stddefines.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <rsfLibs.mqh>


#import "test/testlibrary.ex4"
   int ex4_GetIntValue(int value);
#import


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onTick() {
   return(last_error);

   static bool done = false;
   if (!done) {
      debug("onTick()");
      //DecreasePeriod(PERIOD_H1);
      //ex4_GetIntValue(1);
      done = true;
   }
   return(last_error);
}
