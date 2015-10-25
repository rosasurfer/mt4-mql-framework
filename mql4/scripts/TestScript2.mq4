/**
 * TestScript2
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[] = { INIT_DOESNT_REQUIRE_BARS };
int __DEINIT_FLAGS__[];
#include <core/script.mqh>
#include <stdfunctions.mqh>
#include <stdlib.mqh>


int tickTimer;


/**
 *
 * @return int - Fehlerstatus
 */
int onInit() {
   int hWnd = WindowHandleEx(NULL); if (!hWnd) return(last_error);

   int timerId = SetupTickTimer(hWnd, 4000, NULL);
   if (timerId > 0) {
      debug("onInit(1)  SetupTickTimer() success, result="+ timerId);
      tickTimer = timerId;
   }
   else {
      catch("onInit(2)  SetupTickTimer() failed, result="+ timerId, ERR_RUNTIME_ERROR);
      tickTimer = NULL;
   }
   return(last_error);
}


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onStart() {
   return(NO_ERROR);
}


/**
 * @return int - Fehlerstatus
 */
int onDeinit() {
   if (tickTimer != NULL) {
      bool result = RemoveTickTimer(tickTimer);
      catch("onDeinit(1)  RemoveTickTimer("+ tickTimer +")  result="+ result);
      tickTimer = NULL;
   }
   return(last_error);
}
