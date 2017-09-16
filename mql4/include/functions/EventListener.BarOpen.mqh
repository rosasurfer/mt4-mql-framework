/**
 * Prüft, ob der aktuelle Tick im aktuellen Timeframe ein BarOpen-Event darstellt. Auch bei wiederholten Aufrufen während desselben Ticks
 * wird das Event korrekt erkannt. Diese Funktion erkennt BarOpen-Events jedoch dann nicht, wenn das Event beim ersten Tick nach einem
 * init()-Cycle auftritt (Timeframewechsel oder Parameteränderung), da die statischen Variablen dann noch nicht initialisiert sind.
 *
 * @return bool - ob ein Event aufgetreten ist
 */
bool EventListener.BarOpen() {
   static int      lastTick;
   static datetime lastOpenTime;
   static bool     lastResult;

   if (Tick == lastTick) {
      //debug("EventListener.BarOpen(1)  same tick="+ Tick +"  same result="+ lastResult);
   }
   else if (ChangedBars > 2) {
      lastResult = false;
      //debug("EventListener.BarOpen(2)  ChangedBars="+ ChangedBars +"  result="+ lastResult);
   }
   else {
      lastResult = (Time[0] > lastOpenTime);
      //if (lastResult) debug("EventListener.BarOpen(3)  ChangedBars="+ ChangedBars +"  result="+ lastResult);
   }

   lastTick     = Tick;
   lastOpenTime = Time[0];

   return(lastResult);
}
