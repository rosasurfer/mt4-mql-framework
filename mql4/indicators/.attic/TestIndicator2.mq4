/**
 * TestIndicator
 */
#include <stddefines.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <rsfLibs.mqh>

#include <MT4iQuickChannel.mqh>
#include <win32api.mqh>

#property indicator_chart_window


/**
 *
 * @return int - Fehlerstatus
 */
int onInit() {
   //debug("onInit()    TimeLocal="+ TimeToStr(TimeLocal()) +"  TimeCurrent="+ TimeToStr(TimeCurrent()));
   return(last_error);
}


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onTick() {
   debug("onTick()  Tick="+ Tick +"  isVirtual="+ Tick.isVirtual +"  vol="+ _int(Volume[0]) +"  Bars="+ Bars +"  ChangedBars="+ ChangedBars);
   return(last_error);



   // --------------------------------------------------------------------------------------------------------------
   debug("onTick()    TimeLocal="+ TimeToStr(TimeLocal()) +"  TimeCurrent="+ TimeToStr(TimeCurrent()));
   return(last_error);

   // --------------------------------------------------------------------------------------------------------------
   static bool done;
   if (!done) {
      debug("onTick(1) "+ ifString(IsUIThread(NULL), "ui", "  ") +"thread="+ GetCurrentThreadId() +"  sc="+ __lpSuperContext +"  Visual="+ IsVisualModeFix() +"  Testing="+ IsTesting());
      done = true;
   }
   return(last_error);
}


/**
 *
 * @return int - Fehlerstatus
 */
int onDeinit() {
   //debug("onDeinit()  TimeLocal="+ TimeToStr(TimeLocal()) +"  TimeCurrent="+ TimeToStr(TimeCurrent()));
   return(last_error);
}
