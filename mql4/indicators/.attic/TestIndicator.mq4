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
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onTick() {
   static bool done = false;
   if (true || !done) {
      //debug("onTick()  calling rsfLib1");
      //DecreasePeriod(PERIOD_H1);

      //debug("onTick()  calling testlibrary");
      //ex4_GetIntValue(1);
      done = true;
   }
   return(last_error);
}
