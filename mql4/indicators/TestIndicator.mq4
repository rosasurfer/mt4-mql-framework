/**
 * TestIndicator
 */
#property indicator_chart_window
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <stdlib.mqh>
#include <structs/pewa/EXECUTION_CONTEXT.mqh>
#include <history.mqh>
#include <test/testlibrary.mqh>


#import "Expander.Release.dll"
#import


/**
 *
 * @return int - Fehlerstatus
 */
int onInit() {
   return(last_error);
}


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onTick() {
   //EXECUTION_CONTEXT.toStr(__ExecutionContext, true);

   testlibrary();
   debug("onTick()->testlibrary()");

   return(last_error);

   int iNull[];
   EXECUTION_CONTEXT.toStr(iNull);
}


/**
 *
 * @return int - Fehlerstatus
 */
int onDeinit() {
   //int error = test_context(); if (IsError(error)) return(catch("onStart(2)->test_context() failed", error));
   return(last_error);
}
