/**
 * TestExpert
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <core/expert.mqh>
#include <stdfunctions.mqh>
#include <stdlib.mqh>


//////////////////////////////////////////////////////////////////////////////// Konfiguration ////////////////////////////////////////////////////////////////////////////////

extern string sParameter = "dummy";
extern int    iParameter = 12345;

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


/**
 *
 * @return int - Fehlerstatus
 */
int onInit() {
   debug("onInit()    WindowHandle="+ WindowHandle(Symbol(), NULL), GetLastError());
   return(last_error);
}


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onTick() {
   debug("onTick()    WindowHandle="+ WindowHandle(Symbol(), NULL), GetLastError());
   return(last_error);
}


/**
 *
 * @return int - Fehlerstatus
 */
int onDeinit() {
   debug("onDeinit()  WindowHandle="+ WindowHandle(Symbol(), NULL), GetLastError());
   return(last_error);
}
