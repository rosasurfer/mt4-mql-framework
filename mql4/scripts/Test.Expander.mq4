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

   bool expander_onInit  (int context[]);
   bool expander_onStart (int context[]);
   bool expander_onDeinit(int context[]);

#import "struct.EXECUTION_CONTEXT.ex4"
   int    ec.Whereami(/*EXECUTION_CONTEXT*/int ec[]);
#import


/**
 *
 * @return int - Fehlerstatus
 */
int onInit() {
   expander_onInit(__ExecutionContext);
   return(last_error);
}


/**
 *
 * @return int - Fehlerstatus
 */
int onDeinit() {
   expander_onDeinit(__ExecutionContext);
   return(last_error);
}


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onStart() {
   expander_onStart(__ExecutionContext);
   return(catch("onStart(1)"));
}
