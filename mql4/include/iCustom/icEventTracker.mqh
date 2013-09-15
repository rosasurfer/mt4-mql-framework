/**
 * In Headerdatei implementiert, um direkt in EA's inkludiert werden zu können.  Dies ist notwendig, wenn die Indikatorausgabe
 * im Tester nach Testende bei VisualMode=On gezeichnet werden soll.  Der Tester zeichnet den Inhalt der Buffer nur dann, wenn
 * der iCustom()-Aufruf direkt im EA erfolgt (nicht bei Aufruf in einer Library).
 */

#import "structs1.ex4"
   int  ec.LastError(/*EXECUTION_CONTEXT*/int ec[]);
#import


/**
 * Ruft den "EventTracker"-Indikator auf (gibt keinen Wert zurück).
 *
 * @param  int timeframe - Timeframe, in dem der Indikator geladen wird
 *
 * @return bool - Erfolgsstatus
 */
bool icEventTracker(int timeframe) {
   if (IsLastError())
      return(false);

   int lpLocalContext = GetBufferAddress(__ExecutionContext);

   double value = iCustom(NULL, timeframe, "EventTracker",                 //throws ERS_HISTORY_UPDATE, ERR_TIMEFRAME_NOT_AVAILABLE
                          "",                                              // ________________
                          lpLocalContext,                                  // __SuperContext__
                          0,                                               // iBuffer
                          0);                                              // iBar

   int error = GetLastError();
   if (IsError(error)) {
      if (error != ERS_HISTORY_UPDATE)
         return(_false(catch("icEventTracker(1)", error)));
      warn("icEventTracker(2)   ERS_HISTORY_UPDATE (tick="+ Tick +")");    // TODO: geladene Bars prüfen
   }

   error = ec.LastError(__ExecutionContext);                               // TODO: Synchronisation von Original und Kopie sicherstellen
   if (!error)
      return(true);

   return(_false(SetLastError(error)));
}
