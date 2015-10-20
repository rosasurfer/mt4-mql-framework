/**
 *
 */
#property indicator_chart_window
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <stdlib.mqh>


int hTickTimer;


/**
 *
 * @return int - Fehlerstatus
 */
int onInit() {
   int hWnd = WindowHandleEx(NULL);
   if (!hWnd) return(last_error);

   int millis = 500;

   hTickTimer = SetupTimedTicks(hWnd, Round(millis/1.56));
   debug("onInit()   SetupTimedTicks(hWnd="+ hWnd +", millis="+ millis +") => "+ hTickTimer);

   /*
   5000 => 7800    1.56
   2000 => 3120    1.56
   1000 => 1560    1.56
    500 =>  780    1.56
    400 =>  624
    300 =>  468
    200 =>  312    1.56
    100 =>  156    1.56
   */

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

   debug("onTick()  Tick="+ Tick +"  vol="+ _int(Volume[0]) +"  after "+ (tickCount-lastTickCount) +" msec");

   lastTickCount = tickCount;
   return(last_error);
}


/**
 *
 * @return int - Fehlerstatus
 */
int onDeinit() {
   if (hTickTimer > NULL) {
      bool result = RemoveTimedTicks(hTickTimer);
      debug("onDeinit()   RemoveTimedTicks(hTimer="+ hTickTimer +") => "+ BoolToStr(result));
   }
   return(last_error);
}
