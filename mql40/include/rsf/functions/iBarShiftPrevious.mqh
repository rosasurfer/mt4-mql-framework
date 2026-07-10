/**
 * Ermittelt den Bar-Offset eines Zeitpunktes innerhalb einer Datenreihe und gibt bei nicht existierender Bar die letzte
 * vorherige existierende Bar zurück.
 *
 * @param  string   symbol          - Symbol der zu untersuchenden Datenreihe  (NULL = aktuelles Symbol)
 * @param  int      period          - Periode der zu untersuchenden Datenreihe (NULL = aktuelle Periode)
 * @param  datetime time            - Zeitpunkt (Serverzeit)
 * @param  int      mute [optional] - Flags der Fehler, die still gesetzt werden sollen (default: keine)
 *
 * @return int - Bar-Index oder -1, wenn keine entsprechende Bar existiert (Zeitpunkt ist zu alt für Datenreihe);
 *               EMPTY_VALUE, falls ein Fehler auftrat
 *
 * Note: Ein gemeldeter Status ERS_HISTORY_UPDATE ist kein Fehler und wird nicht weitergemeldet.
 */
int iBarShiftPrevious(string symbol/*=NULL*/, int period/*=NULL*/, datetime time, int mute=NULL) {
   if (symbol == "0") symbol = Symbol();                                                  // (string) NULL
   if (time < 0) return(_EMPTY_VALUE(catch("iBarShiftPrevious(1)  invalid parameter time: "+ time, ERR_INVALID_PARAMETER)));

   // int iBarShift(string symbol, int period, datetime time, bool exact);
   //   exact = TRUE : Gibt den Index der Bar zurück, die den angegebenen Zeitpunkt abdeckt oder, falls keine solche Bar existiert, -1.
   //   exact = FALSE: Gibt den Index der Bar zurück, die den angegebenen Zeitpunkt abdeckt oder, falls keine solche Bar existiert, den Index
   //                  der vorhergehenden, älteren Bar. Existiert keine solche vorhergehende Bar, wird der Index der letzten Bar zurückgegeben.
   //
   //   - Existieren keine entsprechenden Daten, gibt iBarShift() -1 zurück.
   //   - Ist das Symbol unbekannt (existiert nicht in "symbols.raw") oder ist der Timeframe kein Standard-Timeframe, meldet iBarShift() keinen Fehler.
   //   - Ist das Symbol bekannt, wird ggf. der Status ERS_HISTORY_UPDATE gemeldet.

   // Datenreihe holen
   datetime times[];
   int bars  = ArrayCopySeries(times, MODE_TIME, symbol, period);//throws ERR_ARRAY_ERROR, wenn solche Daten (noch) nicht existieren
   int error = GetLastError();

   if (bars<=0 || error) {                                                                // Da immer beide Bedingungen geprüft werden müssen, braucht das OR nicht optimiert werden.
      if (bars<=0 || error!=ERS_HISTORY_UPDATE) {
         if (!error || error==ERS_HISTORY_UPDATE || error==ERR_ARRAY_ERROR)               // aus ERR_ARRAY_ERROR wird ERR_SERIES_NOT_AVAILABLE
            error = ERR_SERIES_NOT_AVAILABLE;
         if (error==ERR_SERIES_NOT_AVAILABLE && mute & F_ERR_SERIES_NOT_AVAILABLE)
            return(_EMPTY_VALUE(SetLastError(error)));                                    // leise
         return(_EMPTY_VALUE(catch("iBarShiftPrevious(2)->ArrayCopySeries("+ symbol +","+ PeriodDescription(period) +") => "+ bars, error)));   // laut
      }
   }
   // bars ist hier immer größer 0

   // Bars überprüfen
   if (time < times[bars-1]) {
      int bar = -1;                                                                       // Zeitpunkt ist zu alt für die Reihe
   }
   else {
      bar   = iBarShift(symbol, period, time, false);
      error = GetLastError();
      if (error!=NO_ERROR) /*&&*/ if (error!=ERS_HISTORY_UPDATE)
         return(_EMPTY_VALUE(catch("iBarShiftPrevious(3)->iBarShift("+ symbol +","+ PeriodDescription(period) +") => "+ bar, error)));
   }
   return(bar);
}
