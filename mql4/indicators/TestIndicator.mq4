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


int tickTimerId;


/**
 *
 * @return int - Fehlerstatus
 */
int onInit() {
   int hWnd = WindowHandleEx(NULL); if (!hWnd) return(last_error);
   tickTimerId = SetupTickTimer(hWnd, 500, TICK_OFFLINE_REFRESH);
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
 *
 * @return int - Fehlerstatus
 */
int onDeinit() {
   if (tickTimerId != NULL) {
      RemoveTickTimer(tickTimerId);
      tickTimerId = NULL;
   }
   return(last_error);
}
