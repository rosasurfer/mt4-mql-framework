/**
 * Test-Script für den MT4Expander
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <core/script.mqh>
#include <stdfunctions.mqh>
#include <stdlib.mqh>
//#include <win32api.mqh>


//#import "Expander.Debug.dll"
#import "Expander.Release.dll"

   bool Expander_init  (int context[]);
   bool Expander_start (int context[]);
   bool Expander_deinit(int context[]);

#import "struct.EXECUTION_CONTEXT.ex4"
   int    ec.Whereami(/*EXECUTION_CONTEXT*/int ec[]);
#import


/**
 *
 * @return int - Fehlerstatus
 */
int onInit() {
   Expander_init(__ExecutionContext);
   return(last_error);
}


/**
 *
 * @return int - Fehlerstatus
 */
int onDeinit() {
   Expander_deinit(__ExecutionContext);
   return(last_error);
}


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onStart() {
   Expander_start(__ExecutionContext);
   return(catch("onStart(1)"));
}
