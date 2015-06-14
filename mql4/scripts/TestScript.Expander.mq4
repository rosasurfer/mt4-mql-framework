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
#include <history.mqh>
#include <test/testlibrary.mqh>


#import "Expander.Release.dll"
   bool Test_onInit  (int context[], int logLevel);
   bool Test_onStart (int context[], int logLevel);
   bool Test_onDeinit(int context[], int logLevel);

   int  Test();
#import


/**
 *
 * @return int - Fehlerstatus
 */
int onInit() {
   //EXECUTION_CONTEXT.toStr(__ExecutionContext, true);
   //Test_onInit(__ExecutionContext, L_DEBUG);
   return(last_error);
}


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onStart() {
   //Test_onStart(__ExecutionContext, L_DEBUG);
   //Test();

   testlibrary();
   debug("onStart()->testlibrary()");

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
