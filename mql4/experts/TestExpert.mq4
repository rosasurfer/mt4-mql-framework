/**
 * TestExpert
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];

////////////////////////////////////////////////////////////////////////////////// Konfiguration ////////////////////////////////////////////////////////////////////////////////////

extern string sParameter = "dummy";
extern int    iParameter = 12345;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/expert.mqh>
#include <stdfunctions.mqh>
#include <stdlib.mqh>


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
   static int lastTickCount;

   int tickCount = GetTickCount();
   debug("onTick()  Tick="+ Tick +"  vol="+ _int(Volume[0]) +"  ChangedBars="+ ChangedBars +"  after "+ (tickCount-lastTickCount) +" msec");

   lastTickCount = tickCount;
   return(last_error);
}


/**
 * @return int - Fehlerstatus
 */
int onDeinit() {
   return(NO_ERROR);
}
