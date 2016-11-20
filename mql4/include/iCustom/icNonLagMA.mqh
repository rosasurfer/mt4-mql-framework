/**
 * Ruft den "NonLagMA"-Indikator auf und gibt den angegebenen Wert zurück.
 *
 * @param  int    timeframe      - Timeframe, in dem der Indikator geladen wird
 *
 * @param  string maPeriods      - Indikator-Parameter
 * @param  string maTimeframe    - Indikator-Parameter
 * @param  string maMethod       - Indikator-Parameter
 * @param  string maAppliedPrice - Indikator-Parameter
 *
 * @param  int    iBuffer        - Bufferindex des zurückzugebenden Wertes
 * @param  int    iBar           - Barindex des zurückzugebenden Wertes
 *
 * @return double - Indikatorwert oder NULL, falls ein Fehler auftrat
 */
double icNonLagMA(int timeframe, int cycleLength, string filterVersion, int maxValues, int iBuffer, int iBar) {
   static int lpExecutionContext = 0;
   if (!lpExecutionContext) lpExecutionContext = GetIntsAddress(__ExecutionContext);

   double value = iCustom(NULL, timeframe, "NonLagMA",
                          cycleLength,                                     // int    Cycle.Length
                          filterVersion,                                   // string Filter.Version

                          CLR_NONE,                                        // color  Color.UpTrend
                          CLR_NONE,                                        // color  Color.DownTrend
                          "Dot",                                           // string Drawing.Type
                          1,                                               // int    Drawing.Line.Width

                          maxValues,                                       // int    Max.Values
                          0,                                               // int    Shift.Vertical.Pips
                          0,                                               // int    Shift.Horizontal.Bars
                          "",                                              // string _____________________
                          false,                                           // bool   Signal.onTrendChange
                          "off",                                           // string Signal.Sound
                          "off",                                           // string Signal.Mail.Receiver
                          "off",                                           // string Signal.SMS.Receiver
                          "off",                                           // string Signal.IRC.Channel
                          "",                                              // string _____________________
                          lpExecutionContext,                              // int    __lpSuperContext

                          iBuffer, iBar);

   int error = GetLastError();
   if (error != NO_ERROR) {
      if (error != ERS_HISTORY_UPDATE)
         return(_NULL(catch("icNonLagMA(1)", error)));
      warn("icNonLagMA(2)  ERS_HISTORY_UPDATE (tick="+ Tick +")");         // TODO: geladene Bars prüfen
   }

   error = ec_MqlError(__ExecutionContext);                                // TODO: Synchronisation von Original und Kopie sicherstellen
   if (!error)
      return(value);
   return(_NULL(SetLastError(error)));
}


// --------------------------------------------------------------------------------------------------------------------------------------------------


#import "Expander.dll"
   int ec_MqlError(/*EXECUTION_CONTEXT*/int ec[]);
#import
