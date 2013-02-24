/**
 * TestExpert
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <stdlib.mqh>

#include <core/expert.mqh>


///////////////////////////////////////////////////////////////////// Konfiguration /////////////////////////////////////////////////////////////////////

extern string Parameter = "dummy";

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


#include <test/testlibrary.mqh>
//#include <test/teststatic.mqh>


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onTick() {
   bool sized   = false;
   bool init    = true;
   bool _static = true;

   //GlobalPrimitives(init);
   //LocalPrimitives(init);

   //GlobalArrays(sized, init);
   //LocalArrays(sized, init, _static);

   return(last_error);
}


/**
 *
 * @return int - Fehlerstatus
 */
void DummyCalls() {
   GlobalPrimitives(NULL);
   LocalPrimitives(NULL);
   GlobalArrays(NULL, NULL);
   LocalArrays(NULL, NULL, NULL);
}
