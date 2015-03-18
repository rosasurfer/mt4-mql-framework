/**
 * TestIndicator
 */
#property indicator_chart_window

#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <core/indicator.mqh>
#include <stdfunctions.mqh>
//#include <stdlib.mqh>


#import "Expander.Release.dll"
   /*
   bool Expander_onInit  (int context[]);
   bool Expander_onStart (int context[]);
   bool Expander_onDeinit(int context[]);
   */
#import


/**
 *
 * @return int - Fehlerstatus
 */
int onInit() {
   Expander_onInit(__ExecutionContext);
   return(last_error);
}


/**
 *
 * @return int - Fehlerstatus
 */
int onDeinit() {
   Expander_onDeinit(__ExecutionContext);
   return(last_error);
}


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onTick() {
   Expander_onStart(__ExecutionContext);
   return(last_error);
}
