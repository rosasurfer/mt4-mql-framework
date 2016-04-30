/**
 * Prüft, ob der aktuelle Tick in den angegebenen Timeframes ein BarOpen-Event darstellt. Auch bei wiederholten Aufrufen während
 * desselben Ticks wird das Event korrekt erkannt.
 *
 * @return bool - ob mindestens ein BarOpen-Event aufgetreten ist
 */
bool EventListener.BarOpen() {
   if (Indicator.IsTesting()) /*&&*/ if (!IsSuperContext())            // TODO: !!! IsSuperContext() ist unzureichend, das Root-Programm muß ein EA sein
      return(!catch("EventListener.BarOpen(1)  function cannot be tested in standalone indicator (Tick.Time value not available)", ERR_ILLEGAL_STATE));
   /*                                                                   // TODO: Listener für PERIOD_MN1 implementieren
   +--------------------------+--------------------------+
   | Aufruf bei erstem Tick   | Aufruf bei weiterem Tick |
   +--------------------------+--------------------------+
   | Tick.prevTime = 0;       | Tick.prevTime = time[1]; |              // time[] ist hier nur eine Pseudovariable (existiert nicht)
   | Tick.Time     = time[0]; | Tick.Time     = time[0]; |
   +--------------------------+--------------------------+
   */
   static datetime bar.openTimes[], bar.closeTimes[];                   // Open/CloseTimes der Bars der jeweiligen Perioden
                                                                        // die am häufigsten verwendeten Perioden zuerst (beschleunigt Ausführung)
   static int sizeOfPeriods, periods[]={PERIOD_H1, PERIOD_M30, PERIOD_M15, PERIOD_M5, PERIOD_M1, PERIOD_H4, PERIOD_D1, PERIOD_W1/*, PERIOD_MN1*/};
   if (sizeOfPeriods == 0) {
      sizeOfPeriods = ArraySize(periods);
      ArrayResize(bar.openTimes,  sizeOfPeriods);
      ArrayResize(bar.closeTimes, sizeOfPeriods);
   }
   int period = Period();

   for (int i=0; i < sizeOfPeriods; i++) {
      if (period == periods[i]) {
         bool isEvent = false;
         // BarOpen/Close-Time des aktuellen Ticks ggf. neuberechnen
         if (Tick.Time >= bar.closeTimes[i]) {                          // true sowohl bei Initialisierung als auch bei BarOpen
            bar.openTimes [i] = Tick.Time - Tick.Time % (periods[i]*MINUTES);
            bar.closeTimes[i] = bar.openTimes[i]      + (periods[i]*MINUTES);
         }

         // Event anhand des vorherigen Ticks bestimmen
         if (Tick.prevTime < bar.openTimes[i]) {
            if (!Tick.prevTime) {
               if (Expert.IsTesting())                                  // im Tester ist der 1. Tick BarOpen-Event      TODO: !!! nicht für alle Timeframes !!!
                  isEvent = true;
            }
            else {
               isEvent = true;
            }
         }
         return(isEvent);
      }
   }
   return(false);
}
