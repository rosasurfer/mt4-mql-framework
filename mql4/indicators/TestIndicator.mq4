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


#import "test/testlibrary1.ex4"
   void testlibrary1();
   void testlibrary1_nested();

#import "test/testlibrary2.ex4"
   void testlibrary2();

#import


/**
 *
 * @return int - Fehlerstatus
 */
int onInit() {

   //testlibrary1();
   //testlibrary2();

   return(last_error);
}


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onTick() {
   //testlibrary1_nested();
   return(last_error);
}


/**
 *
 * @return int - Fehlerstatus
 */
int onDeinit() {
   return(last_error);
}
