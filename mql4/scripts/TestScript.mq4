/**
 * TestScript
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <core/script.mqh>
#include <stdlib.mqh>


#import "StdLib.Release.dll"
   bool Test();
#import


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onStart() {

   bool result = Test();
   debug("onStart()->Test() => "+ result);

   return(last_error);
}
