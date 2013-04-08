/**
 * TestIndicator
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <stdlib.mqh>

#include <core/indicator.mqh>

#property indicator_chart_window

#include <test/testlibrary.mqh>


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onTick() {

   bool st = true;               // static ...
   bool in = true;               // initializer

   GlobalPrimitives(st, in);
   //LocalPrimitives(st, in);


   bool si = false;              // sized array declaration
   //GlobalArrays(si, in);
   //LocalArrays(st, si, in);

   return(last_error);
}
