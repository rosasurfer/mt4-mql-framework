/**
 * TestScript
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <core/script.mqh>
#include <stdlib.mqh>


#import "StdLib.Release.dll"
   bool pw_IsCustomTimeframe(int timeframe);
#import


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onStart() {

   pw_IsCustomTimeframe(3);

   debug("onStart()");
   return(last_error);
}
