/**
 * TestIndicator
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <stdlib.mqh>

#include <core/indicator.mqh>

#property indicator_chart_window


//#include <test/testlibrary.mqh>
#include <test/teststatic.mqh>


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onTick() {

   /*
   bool st = true;               // static ...
   bool si = true;               // sized array declaration
   bool in = false;              // initializer

   //GlobalPrimitives(st, in);
   //LocalPrimitives (    in);

   //GlobalArrays(st, si, in);
   //LocalArrays (st, si, in);
   */
   return(last_error);
}


/**
 *
 * @return int - Fehlerstatus
 */
void DummyCalls() {
   GlobalPrimitives(NULL, NULL);
   LocalPrimitives(NULL);
   GlobalArrays(NULL, NULL, NULL);
   LocalArrays(NULL, NULL, NULL);
}
