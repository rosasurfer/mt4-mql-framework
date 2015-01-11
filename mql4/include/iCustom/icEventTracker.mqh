/**
 * Ruft den "EventTracker"-Indikator auf. Der Indikator hat keine Buffer und gibt keinen Wert zurück.
 *
 * @param  int timeframe - Timeframe, in dem der Indikator geladen werden soll
 *
 * @return bool - Erfolgsstatus
 */
bool icEventTracker(int timeframe) {
   if (IsLastError())
      return(false);

   int lpLocalContext = GetBufferAddress(__ExecutionContext);

   double value = iCustom(NULL, timeframe, "EventTracker",                 // throws ERS_HISTORY_UPDATE, ERR_SERIES_NOT_AVAILABLE
                          "",                                              // ________________
                          lpLocalContext,                                  // __SuperContext__
                          0,                                               // iBuffer
                          0);                                              // iBar

   int error = GetLastError();
   if (IsError(error)) {
      if (error != ERS_HISTORY_UPDATE)
         return(!catch("icEventTracker(1)", error));
      warn("icEventTracker(2)   ERS_HISTORY_UPDATE (tick="+ Tick +")");    // TODO: geladene Bars prüfen
   }
   error = ec.LastError(__ExecutionContext);                               // TODO: Synchronisation von Original und Kopie sicherstellen
   if (!error)
      return(true);
   return(!SetLastError(error));
}


// --------------------------------------------------------------------------------------------------------------------------------------------------


#import "StdLib.dll"
   int GetBufferAddress(int buffer[]);

#import "struct.EXECUTION_CONTEXT.ex4"
   int ec.LastError(/*EXECUTION_CONTEXT*/int ec[]);
#import
