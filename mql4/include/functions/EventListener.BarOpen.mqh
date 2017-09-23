/**
 * Prüft, ob der aktuelle Tick im aktuellen Timeframe ein BarOpen-Event darstellt. Kann mehrmals während desselben Ticks aufgerufen werden.
 *
 * Erkennt BarOpen-Events nicht, die beim ersten Tick nach dem init()-Cycle eines Indikators auftreten (Timeframewechsel, Parameteränderung).
 * Erkennt BarOpen-Events nicht, die beim ersten Tick nach Recompilation auftreten.
 *
 * @return bool - ob ein Event aufgetreten ist
 */
bool EventListener.BarOpen() {
   static int      lastTick;
   static int      lastPeriod;                                 // used by experts only
   static datetime lastBarOpenTime;
   static bool     lastResult, result;

   if (Volume[0] == 1) {
      result = true;
      //debug("EventListener.BarOpen(1)  Volume[0]="+ _int(Volume[0]) +"  result="+ result);
   }
   else if (!lastBarOpenTime) {
      result = false;
      //debug("EventListener.BarOpen(2)  function not yet initialized  result="+ result);
   }
   else if (Tick == lastTick) {
      result = lastResult;
      //debug("EventListener.BarOpen(3)  same tick="+ Tick +"  same result="+ result);
   }
   else if (IsIndicator()) {
      if (ChangedBars > 2) {
         result = false;
         //debug("EventListener.BarOpen(4)  ChangedBars="+ ChangedBars +"  result="+ result);
      }
      else {
         result = (Time[0] > lastBarOpenTime);
         if (result && zTick < 30) {
            debug("EventListener.BarOpen(5)  zTick="+ zTick +"  Tick.isVirtual="+ Tick.isVirtual +"  lastBarOpenTime="+ TimeToStr(lastBarOpenTime, TIME_FULL) +"  Time[0]="+ TimeToStr(Time[0], TIME_FULL) +"  Volume[0]="+ _int(Volume[0]) +"  ChangedBars="+ ChangedBars +"  result="+ result);
         }
      }
   }
   else {
      // experts carry static vars through init cycles
      if (Period() == lastPeriod) {
         result = (Time[0] > lastBarOpenTime);
         //debug("EventListener.BarOpen(6)  timeframe unchanged  Time[0]="+ TimeToStr(Time[0], TIME_FULL) +"  result="+ result);
      }
      else {
         // changed timeframe, calculate lastBarOpenTime from Tick.prevTime
         lastBarOpenTime = Tick.prevTime - Tick.prevTime % (Period()*MINUTES);
         result          = (Time[0] > lastBarOpenTime);
         //debug("EventListener.BarOpen(7)  timeframe changed  Time[0]="+ TimeToStr(Time[0], TIME_FULL) +"  Tick.prevTime="+ TimeToStr(Tick.prevTime, TIME_FULL) +"  result="+ result);
      }
   }

   lastTick        = Tick;
   lastPeriod      = Period();
   lastBarOpenTime = Time[0];
   lastResult      = result;

   return(result);
}
