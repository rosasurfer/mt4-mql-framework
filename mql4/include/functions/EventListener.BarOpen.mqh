/**
 * Prüft, ob der aktuelle Tick im aktuellen Timeframe ein BarOpen-Event darstellt. Auch bei wiederholten Aufrufen während
 * desselben Ticks wird das Event korrekt erkannt. Diese Funktion erkennt BarOpen-Events dann nicht, wenn das Event beim ersten
 * Tick nach einem init()-Cycle auftritt (Timeframewechsel, Parameteränderung).
 *
 * @return bool - ob ein Event aufgetreten ist
 */
bool EventListener.BarOpen() {
   static int      lastTick;
   static datetime lastTime;
   static bool     result;

   if (Tick == lastTick) {
      //debug("EventListener.BarOpen(1)  same tick="+ Tick +"  same result="+ result);
   }
   else if (ChangedBars > 2) {
      result = false;
      //debug("EventListener.BarOpen(2)  ChangedBars="+ ChangedBars +"  result="+ result);
   }
   else {
      result = (Time[0] > lastTime);
      //if (result) debug("EventListener.BarOpen(3)  ChangedBars="+ ChangedBars +"  result="+ result);
   }

   lastTick = Tick;
   lastTime = Time[0];

   return(result);
}
