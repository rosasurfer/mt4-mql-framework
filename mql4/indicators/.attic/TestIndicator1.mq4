/**
 * TestIndicator
 */
#include <stddefines.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <rsfLibs.mqh>

#property indicator_chart_window


#import "test/testlibrary.ex4"
   void testlibrary();
#import


/**
 *
 * @return int - Fehlerstatus
 */
int onInit() {
   //debug("onInit(1)  UninitializeReason="+ UninitializeReasonToStr(UninitializeReason()) +"  WindowOnDropped="+ WindowOnDropped() +"  WindowXOnDropped="+ WindowXOnDropped());
   return(last_error);
}


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onTick() {
   //debug("onTick()  Tick="+ Tick +"  Bars="+ Bars +"  ChangedBars="+ ChangedBars);
   return(last_error);
}


/**
 *
 * @return int - Fehlerstatus
 */
int onDeinit() {
   //debug("onDeinit(1)");
   return(last_error);
}
