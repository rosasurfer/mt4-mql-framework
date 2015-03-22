/**
 * Test-Script für den MT4Expander
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <core/script.mqh>
#include <stdfunctions.mqh>
#include <stdlib.mqh>
#include <structs/pewa/EXECUTION_CONTEXT.mqh>


#import "Expander.Release.dll"
   bool Test_onInit  (int context[], int logLevel);
   bool Test_onStart (int context[], int logLevel);
   bool Test_onDeinit(int context[], int logLevel);

   bool SyncExecutionContext(int context[]);

#import "test/testlibrary.ex4"
   int test_context();
#import


/**
 *
 * @return int - Fehlerstatus
 */
int onInit() {
   //Test_onInit(__ExecutionContext, L_DEBUG);
   return(last_error);
}


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onStart() {
   Test_onStart(__ExecutionContext, L_DEBUG);

   int context[EXECUTION_CONTEXT.intSize];
   //if (!SyncExecutionContext(context)) return(catch("onStart(1)->SyncExecutionContext() failed", ERR_RUNTIME_ERROR));
   //EXECUTION_CONTEXT.toStr(context, true);

   return(last_error);
}


/**
 *
 * @return int - Fehlerstatus
 */
int onDeinit() {
   //Test_onDeinit(__ExecutionContext, L_DEBUG);
   //int error = test_context(); if (IsError(error)) return(catch("onStart(2)->test_context() failed", error));
   return(last_error);
}
