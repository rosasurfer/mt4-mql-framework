/**
 * Ruft den "Moving Average"-Indikator auf, berechnet den angegebenen Wert und gibt ihn zurück.
 *
 * @param  int    timeframe      - Timeframe, in dem der Indikator geladen wird
 * @param  string maPeriods      - Indikator-Parameter
 * @param  string maTimeframe    - Indikator-Parameter
 * @param  string maMethod       - Indikator-Parameter
 * @param  string maAppliedPrice - Indikator-Parameter
 * @param  int    iBuffer        - Bufferindex des zurückzugebenden Wertes
 * @param  int    iBar           - Barindex des zurückzugebenden Wertes
 *
 * @return double - Wert oder 0, falls ein Fehler auftrat
 *
 *
 * Note: Der Tester zeichnet den Inhalt der Buffer nach Testende nur dann, wenn der iCustom()-Aufruf im Hauptmodul des Programms
 *       (also im EA selbst) erfolgt, nicht bei Aufruf in einer Library (anderes Modul).
 */
double icMovingAverage(int timeframe, string maPeriods, string maTimeframe, string maMethod, string maAppliedPrice, int iBuffer, int iBar) {

   bool hotkeysEnabled = false;
   int  maMaxValues    = 10;                                               // mindestens 10 Werte berechnen, um vorherrschenden Trend korrekt zu detektieren
   int  lpLocalContext = GetIntsAddress(__ExecutionContext);

   double value = iCustom(NULL, timeframe, "Moving Average",
                          maPeriods,                                       // MA.Periods
                          hotkeysEnabled,                                  // MA.Periods.Hotkeys.Enabled
                          maTimeframe,                                     // MA.Timeframe
                          maMethod,                                        // MA.Method
                          maAppliedPrice,                                  // AppliedPrice

                          ForestGreen,                                     // Color.UpTrend
                          Red,                                             // Color.DownTrend

                          maMaxValues,                                     // Max.Values
                          0,                                               // Shift.Horizontal.Bars
                          0,                                               // Shift.Vertical.Pips

                          "",                                              // ________________
                          lpLocalContext,                                  // __SuperContext__
                          iBuffer, iBar);

   int error = GetLastError();

   if (IsError(error)) {
      if (error != ERS_HISTORY_UPDATE)
         return(_NULL(catch("icMovingAverage(1)", error)));
      warn("icMovingAverage(2)  ERS_HISTORY_UPDATE (tick="+ Tick +")");    // TODO: geladene Bars prüfen
   }

   error = ec_LastError(__ExecutionContext);                               // TODO: Synchronisation von Original und Kopie sicherstellen
   if (!error)
      return(value);
   return(_NULL(SetLastError(error)));
}


// --------------------------------------------------------------------------------------------------------------------------------------------------


#import "Expander.dll"
   int ec_LastError(/*EXECUTION_CONTEXT*/int ec[]);
#import
