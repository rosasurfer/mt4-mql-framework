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
   int  iNull[];

   bool newTick_full     = EventListener.NewTick(iNull);
   bool newTick_no_time  = EventListener.NewTick_no_time();
   bool newTick_vol_only = EventListener.NewTick_vol_only();

   static double   lastBid, lastAsk;
   static int      lastVol;
   static datetime lastTime;

   int      vol  = Volume[0];
   datetime time = MarketInfo(Symbol(), MODE_TIME);

   if (Bid && Ask && vol && time) {
      if (lastTime != 0) {
         if (newTick_full != newTick_no_time ) debug("onTick(0.1)  newTick_full("+ newTick_full +") != newTick_no_time("+ newTick_no_time +")");
         if (newTick_full != newTick_vol_only) debug("onTick(0.2)  newTick_full("+ newTick_full +") != newTick_vol_only("+ newTick_vol_only +")");
      }
      lastBid  = Bid;
      lastAsk  = Ask;
      lastVol  = vol;
      lastTime = time;
   }

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

   int      vol  = Volume[0];
   datetime time = MarketInfo(Symbol(), MODE_TIME);
   bool newTick;

   if (Bid && Ask && vol && time) {                                  // wenn aktueller Tick gültig ist
      if (lastTime != 0) {                                           // wenn letzter Tick gültig war
         if      (vol  != lastVol ) newTick = true;                  // wenn der aktuelle Tick ungleich dem letztem Tick ist
         else if (NE(Bid, lastBid)) newTick = true;
         else if (NE(Ask, lastAsk)) newTick = true;
         else if (time != lastTime) newTick = true;
      }
      lastBid  = Bid;                                                // aktuellen Tick speichern, wenn er gültig ist
      lastAsk  = Ask;
      lastVol  = vol;
      lastTime = time;
   }
   return(newTick);
}


/**
 * Prüft ohne Berücksichtigung der Zeit, ob der aktuelle Tick ein neuer Tick ist.
 *
 * @return bool - Ergebnis
 */
bool EventListener.NewTick_no_time() {
   static double   lastBid, lastAsk;
   static int      lastVol;

   int  vol = Volume[0];
   bool newTick;

   if (Bid && Ask && vol) {                                          // wenn aktueller Tick gültig ist
      if (lastVol != 0) {                                            // wenn letzter Tick gültig war
         if      (vol  != lastVol ) newTick = true;                  // wenn der aktuelle Tick ungleich dem letztem Tick ist
         else if (NE(Bid, lastBid)) newTick = true;
         else if (NE(Ask, lastAsk)) newTick = true;
      }
      lastBid  = Bid;                                                // aktuellen Tick speichern, wenn er gültig ist
      lastAsk  = Ask;
      lastVol  = vol;
   }
   return(newTick);
}


/**
 * Prüft nur unter Berücksichtigung des Volumens, ob der aktuelle Tick ein neuer Tick ist.
 *
 * @return bool - Ergebnis
 */
bool EventListener.NewTick_vol_only() {
   static int lastVol;

   int  vol = Volume[0];
   bool newTick;

   if (vol != 0) {                                                   // wenn aktueller Tick gültig ist
      newTick = (lastVol && vol!=lastVol);                           // wenn der letzte Tick gültig war und das aktuelle Volumen ungleich dem letzten Volumen ist
      lastVol = vol;                                                 // aktuellen Tick speichern, wenn er gültig ist
   }
   return(newTick);
}
