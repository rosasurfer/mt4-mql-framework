/**
 * Test-Script für den MT4Expander
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <core/script.mqh>
#include <stdlib.mqh>
#include <win32api.mqh>


//#import "Expander.Debug.dll"
#import "Expander.Release.dll"

   bool Expander_init  (int context[]);
   bool Expander_start (int context[]);
   bool Expander_deinit(int context[]);
#import



/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onStart() {

   return(catch("onStart(1)"));
}
