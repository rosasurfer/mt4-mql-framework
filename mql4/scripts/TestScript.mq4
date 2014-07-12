/**
 * TestScript
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <core/script.mqh>
#include <stdlib.mqh>


#import "StdLib.Release.dll"
#import


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onStart() {
   debug("onStart()");
   return(last_error);
}
