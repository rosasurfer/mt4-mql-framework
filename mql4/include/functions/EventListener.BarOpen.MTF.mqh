/**
 * Prüft, ob der aktuelle Tick in den angegebenen Timeframes ein BarOpen-Event darstellt. Auch bei wiederholten Aufrufen während
 * desselben Ticks wird das Event korrekt erkannt.
 *
 * @param  int results[] - Array, das nach Rückkehr die IDs der angegebenen Timeframes enthält, in denen das Event aufgetreten ist
 * @param  int flags     - Flags ein oder mehrerer zu prüfender Timeframes (default: der aktuelle Timeframe)
 *
 * @return bool - ob mindestens ein BarOpen-Event aufgetreten ist
 */
bool EventListener.BarOpen.MTF(int results[], int flags=NULL) {
   if (Indicator.IsTesting()) /*&&*/ if (!IsSuperContext())            // TODO: !!! IsSuperContext() ist unzureichend, das Root-Programm muß ein EA sein
      return(!catch("EventListener.BarOpen.MTF(1)  function cannot be tested in standalone indicator (Tick.Time value not available)", ERR_ILLEGAL_STATE));

   if (ArraySize(results) != 0)
      ArrayResize(results, 0);

   if (flags == NULL)
      flags = PeriodFlag(Period());

   /*                                                                   // TODO: Listener für PERIOD_MN1 implementieren
   +--------------------------+--------------------------+
   | Aufruf bei erstem Tick   | Aufruf bei weiterem Tick |
   +--------------------------+--------------------------+
   | Tick.prevTime = 0;       | Tick.prevTime = time[1]; |              // time[] ist hier nur Pseudovariable (existiert nicht)
   | Tick.Time     = time[0]; | Tick.Time     = time[0]; |
   +--------------------------+--------------------------+
   */
   static datetime bar.openTimes[], bar.closeTimes[];                   // Open/CloseTimes der Bars der jeweiligen Perioden

                                                                        // die am häufigsten verwendeten Perioden zuerst (beschleunigt Ausführung)
   static int sizeOfPeriods, periods    []={  PERIOD_H1,   PERIOD_M30,   PERIOD_M15,   PERIOD_M5,   PERIOD_M1,   PERIOD_H4,   PERIOD_D1,   PERIOD_W1/*,   PERIOD_MN1*/},
                             periodFlags[]={F_PERIOD_H1, F_PERIOD_M30, F_PERIOD_M15, F_PERIOD_M5, F_PERIOD_M1, F_PERIOD_H4, F_PERIOD_D1, F_PERIOD_W1/*, F_PERIOD_MN1*/};
   if (sizeOfPeriods == 0) {
      sizeOfPeriods = ArraySize(periods);
      ArrayResize(bar.openTimes,  sizeOfPeriods);
      ArrayResize(bar.closeTimes, sizeOfPeriods);
   }

   int isEvent;

   for (int i=0; i < sizeOfPeriods; i++) {
      if (flags & periodFlags[i] != 0) {
         // BarOpen/Close-Time des aktuellen Ticks ggf. neuberechnen
         if (Tick.Time >= bar.closeTimes[i]) {                          // true sowohl bei Initialisierung als auch bei BarOpen
            bar.openTimes [i] = Tick.Time - Tick.Time % (periods[i]*MINUTES);
            bar.closeTimes[i] = bar.openTimes[i]      + (periods[i]*MINUTES);
         }

         // Event anhand des vorherigen Ticks bestimmen
         if (Tick.prevTime < bar.openTimes[i]) {
            if (!Tick.prevTime) {
               if (Expert.IsTesting())                                  // im Tester ist der 1. Tick BarOpen-Event      TODO: !!! nicht für alle Timeframes !!!
                  isEvent = ArrayPushInt(results, periods[i]);
            }
            else {
               isEvent = ArrayPushInt(results, periods[i]);
            }
         }

         // Abbruch, wenn nur dieses einzelne Flag geprüft werden soll (die am häufigsten verwendeten Perioden sind zuerst angeordnet)
         if (flags == periodFlags[i])
            break;
      }
   }
   return(isEvent != 0);
}