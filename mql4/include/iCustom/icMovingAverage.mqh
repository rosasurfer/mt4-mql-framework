/**
 * Ruft den "Moving Average"-Indikator auf, berechnet den angegebenen Wert und gibt ihn zurück.
 *
 * @param  int    timeframe      - Timeframe, in dem der Indikator geladen wird (NULL: aktueller Timeframe)
 * @param  int    maPeriods      - Indikator-Parameter
 * @param  string maTimeframe    - Indikator-Parameter
 * @param  string maMethod       - Indikator-Parameter
 * @param  string maAppliedPrice - Indikator-Parameter
 * @param  int    maxValues
 * @param  int    iBuffer        - Bufferindex des zurückzugebenden Wertes
 * @param  int    iBar           - Barindex des zurückzugebenden Wertes
 *
 * @return double - Wert oder 0, falls ein Fehler auftrat
 */
double icMovingAverage(int timeframe/*=NULL*/, int maPeriods, string maTimeframe, string maMethod, string maAppliedPrice, int maxValues, int iBuffer, int iBar) {
   static int lpSuperContext = 0; if (!lpSuperContext)
      lpSuperContext = GetIntsAddress(__ExecutionContext);

   double value = iCustom(NULL, timeframe, "Moving Average",
                          maPeriods,                                       // int    MA.Periods
                          maTimeframe,                                     // string MA.Timeframe
                          maMethod,                                        // string MA.Method
                          maAppliedPrice,                                  // string MA.AppliedPrice

                          Blue,                                            // color  Color.UpTrend
                          Orange,                                          // color  Color.DownTrend
                          "Line",                                          // string Draw.Type
                          1,                                               // int    Draw.LineWidth

                          maxValues,                                       // int    Max.Values
                          0,                                               // int    Shift.Vertical.Pips
                          0,                                               // int    Shift.Horizontal.Bars

                          "",                                              // string _____________________
                          false,                                           // bool   Signal.onTrendChange
                          "off",                                           // string Signal.Sound
                          "off",                                           // string Signal.Mail.Receiver
                          "off",                                           // string Signal.SMS.Receiver

                          "",                                              // string _____________________
                          lpSuperContext,                                  // int    __SuperContext__

                          iBuffer, iBar);

   int error = GetLastError();
   if (IsError(error)) {
      if (error != ERS_HISTORY_UPDATE)
         return(_NULL(catch("icMovingAverage(1)", error)));
      warn("icMovingAverage(2)  "+ PeriodDescription(ifInt(!timeframe, Period(), timeframe)) +" (tick="+ Tick +")", ERS_HISTORY_UPDATE);
   }                                                                       // TODO: Anzahl geladener Bars prüfen

   error = ec_MqlError(__ExecutionContext);                                // TODO: Synchronisation von Original und Kopie sicherstellen
   if (!error)
      return(value);
   return(_NULL(SetLastError(error)));
}
