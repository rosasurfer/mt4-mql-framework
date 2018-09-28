/**
 * Test-Script für den MT4Expander
 */
#include <stddefines.mqh>
int   __INIT_FLAGS__[] = { INIT_NO_BARS_REQUIRED };
int __DEINIT_FLAGS__[];
#include <core/script.mqh>
#include <stdfunctions.mqh>
#include <functions/InitializeByteBuffer.mqh>
#include <rsfLibs.mqh>
#include <win32api.mqh>

#include <rsfHistory.mqh>
//#include <test/testlibrary.mqh>


#import "rsfExpander.Release.dll"
   int    Test();
   string tzi_StandardName(/*TIME_ZONE_INFORMATION*/int tzi[]);
#import



/**
 *
 * @return int - Fehlerstatus
 */
int onInit() {
   //EXECUTION_CONTEXT_toStr(__ExecutionContext, true);
   return(last_error);
}


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onStart() {
   //Test();
   //testlibrary();
   //debug("onStart()->testlibrary()");


   /*TIME_ZONE_INFORMATION*/int tzi[]; InitializeByteBuffer(tzi, TIME_ZONE_INFORMATION.size);
   int type = GetTimeZoneInformation(tzi);

   string stdName.dll = tzi_StandardName(tzi);
   debug("onStart()->tzi_StandardName() = "+ DoubleQuoteStr(stdName.dll));


   ArrayResize(tzi, 0);

   return(last_error);
}


/**
 *
 * @return int - Fehlerstatus
 */
int onDeinit() {
   //int error = test_context(); if (IsError(error)) return(catch("onStart(2)->test_context() failed", error));
   return(last_error);
}
