/**
 * Ruft den "ChartInfos"-Indikator auf. Der Indikator hat keine Buffer und gibt keinen Wert zurück.
 *
 * @param  int timeframe - Timeframe, in dem der Indikator geladen werden soll
 *
 * @return bool - Erfolgsstatus
 */
bool icChartInfos(int timeframe) {
   // TODO: Aufruf statisch machen
   int lpLocalContext = GetBufferAddress(__ExecutionContext);

   iCustom(NULL, timeframe, "ChartInfos",                                  // throws ERS_HISTORY_UPDATE, ERR_TIMEFRAME_NOT_AVAILABLE
           "",                                                             // ________________
           lpLocalContext,                                                 // __SuperContext__
           0,                                                              // iBuffer
           0);                                                             // iBar

   int error = GetLastError();
   if (error != NO_ERROR) {
      if (error != ERS_HISTORY_UPDATE)
         return(!catch("icChartInfos(1)", error));
      warn("icChartInfos(2)   ERS_HISTORY_UPDATE (tick="+ Tick +")");      // TODO: geladene Bars prüfen
   }
   error = ec.LastError(__ExecutionContext);                               // TODO: Synchronisation von Original und Kopie sicherstellen
   if (!error)
      return(true);
   return(!SetLastError(error));
}


// --------------------------------------------------------------------------------------------------------------------------------------------------


#import "stdlib.dll"
   int GetBufferAddress(int buffer[]);

#import "struct.EXECUTION_CONTEXT.ex4"
   int ec.LastError(/*EXECUTION_CONTEXT*/int ec[]);
#import
