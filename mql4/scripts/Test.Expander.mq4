/**
 * Test-Script für den MT4Expander
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <core/script.mqh>
#include <stdlib.mqh>
#include <win32api.mqh>


//#import "expander.debug.dll"
#import "expander.release.dll"

   bool Expander_init  (int xec[]);
   bool Expander_start (int xec[]);
   bool Expander_deinit(int xec[]);

#import


#define I_XEC_ERROR     0
#define I_XEC_MESSAGE   1


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onStart() {

   /*ERROR_CONTEXT*/int xec[2];

   Expander_start(xec);
   debug("onStart(0.1)  exp.error="+ xec[I_XEC_ERROR] +"  errorMsg="+ GetString(xec[I_XEC_MESSAGE]));

   Expander_start(xec);
   debug("onStart(0.2)  exp.error="+ xec[I_XEC_ERROR] +"  errorMsg="+ GetString(xec[I_XEC_MESSAGE]));


   return(catch("onStart(1)"));
}
