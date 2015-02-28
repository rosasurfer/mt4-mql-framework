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


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onTick() {
   HandleEvent(EVENT_NEW_TICK);
   return(last_error);
}


/**
 * Prüft, ob der aktuelle Tick ein neuer Tick ist.
 *
 * @param  int results[] - event-spezifische Detailinfos (zur Zeit keine)
 * @param  int flags     - zusätzliche eventspezifische Flags (default: keine)
 *
 * @return bool - Ergebnis
 */
bool EventListener.NewTick(int results[], int flags=NULL) {
   static double   lastBid, lastAsk;
   static int      lastVol;
   static datetime lastTime;

   int      vol   = Volume[0];
   datetime time  = MarketInfo(Symbol(), MODE_TIME);
   bool isNewTick = false;

   if (Bid && Ask && vol && time) {                                  // wenn aktueller Tick gültig ist
      if (lastTime != 0) {                                           // wenn letzter Tick gültig war
         if      (NE(Bid, lastBid)) isNewTick = true;                // wenn der aktuelle Tick ungleich dem letztem Tick ist
         else if (NE(Ask, lastAsk)) isNewTick = true;
         else if (vol  != lastVol ) isNewTick = true;
         else if (time != lastTime) isNewTick = true;

         if (!isNewTick) debug("EventListener.NewTick(zTick="+ zTick +")  currentTick is exactly as lastTick");
      }
      lastBid  = Bid;                                                // aktuellen Tick speichern, wenn er gültig ist
      lastAsk  = Ask;
      lastVol  = vol;
      lastTime = time;
   }
   return(isNewTick);
}


/**
 * Wird bei Eintreffen eines neuen Ticks ausgeführt, nicht bei sonstigen Aufrufen der start()-Funktion.
 *
 * @param  int data[] - event-spezifische Daten (zur Zeit keine)
 *
 * @return bool - Erfolgsstatus
 */
bool onNewTick(int data[]) {
   //debug("onNewTick()");
   return(true);
}


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 *
int onTick() {
   //debug("onTick(1)");

   string separator      = "";
   int    lpLocalContext = GetBufferAddress(__ExecutionContext);

   iCustom(NULL, Period(), "TestIndicator2",       //
           separator,                              // ________________
           lpLocalContext,                         // __SuperContext__
           0,                                      // iBuffer
           0);                                     // iBar

   int error = GetLastError();
   if (IsError(error))
      return(error);

   error = ec.LastError(__ExecutionContext);
   if (IsError(error))
      return(error);

   return(last_error);
}


#import "struct.EXECUTION_CONTEXT.ex4"
   int ec.LastError(int ec[]);
#import
*/
