/**
 * Ruft den "Moving Average"-Indikator auf, berechnet den angegebenen Wert und gibt ihn zurück.
 *
 * @param  int    timeframe      - Timeframe, in dem der Indikator geladen wird (NULL: aktueller Timeframe)
 * @param  string maPeriods      - Indikator-Parameter
 * @param  string maTimeframe    - Indikator-Parameter
 * @param  string maMethod       - Indikator-Parameter
 * @param  string maAppliedPrice - Indikator-Parameter
 * @param  int    iBuffer        - Bufferindex des zurückzugebenden Wertes
 * @param  int    iBar           - Barindex des zurückzugebenden Wertes
 *
 * @return double - Wert oder 0, falls ein Fehler auftrat
 */
double icMovingAverage(int timeframe/*=NULL*/, string maPeriods, string maTimeframe, string maMethod, string maAppliedPrice, int iBuffer, int iBar) {
   int maMaxValues    = 10;                                                // mindestens 10 Werte berechnen, um vorherrschenden Trend korrekt zu detektieren
   int lpLocalContext = GetIntsAddress(__ExecutionContext);

   double value = iCustom(NULL, timeframe, "Moving Average",
                          maPeriods,                                       // MA.Periods
                          maTimeframe,                                     // MA.Timeframe
                          maMethod,                                        // MA.Method
                          maAppliedPrice,                                  // MA.AppliedPrice

                          ForestGreen,                                     // Color.UpTrend
                          Red,                                             // Color.DownTrend

                          maMaxValues,                                     // Max.Values
                          0,                                               // Shift.Vertical.Pips
                          0,                                               // Shift.Horizontal.Bars

                          "",                                              // ________________
                          lpLocalContext,                                  // __SuperContext__
                          iBuffer, iBar);

   int error = GetLastError();

   if (IsError(error)) {
      if (error != ERS_HISTORY_UPDATE)
         return(_NULL(catch("icMovingAverage(1)", error)));
      warn("icMovingAverage(2)  ERS_HISTORY_UPDATE (tick="+ Tick +")");    // TODO: bei ERS_HISTORY_UPDATE Anzahl verfügbarer Bars prüfen
   }

   error = ec_MqlError(__ExecutionContext);                                // TODO: Synchronisation von Original und Kopie sicherstellen
   if (!error)
      return(value);
   return(_NULL(SetLastError(error)));
}
