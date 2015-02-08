/**
 * Ermittelt den Bar-Offset eines Zeitpunktes innerhalb einer Datenreihe und gibt bei nicht existierender Bar die letzte vorherige existierende Bar zurück.
 *
 * @param  string   symbol - Symbol der zu untersuchenden Datenreihe  (NULL = aktuelles Symbol)
 * @param  int      period - Periode der zu untersuchenden Datenreihe (NULL = aktuelle Periode)
 * @param  datetime time   - Zeitpunkt (Serverzeit)
 *
 * @return int - Bar-Index oder -1, wenn keine entsprechende Bar existiert (Zeitpunkt ist zu alt für Datenreihe);
 *               EMPTY_VALUE, falls ein Fehler auftrat
 *
 *
 * Note: Ein ausgelöster Status ERS_HISTORY_UPDATE wird nicht als Fehler interpretiert und nicht weitergeleitet.
 *       Er ist nicht relevant für die momentan vorhanden Daten.
 */
int iBarShiftPrevious(string symbol/*=NULL*/, int period/*=NULL*/, datetime time) {
   if (symbol == "0")                                       // (string) NULL
      symbol = Symbol();
   if (time < 0) return(_EMPTY_VALUE(catch("iBarShiftPrevious(1)  invalid parameter time = "+ time, ERR_INVALID_PARAMETER)));

   /*
   int iBarShift(symbol, period, time, exact=false);
      exact = TRUE : Gibt den Index der Bar zurück, die den angegebenen Zeitpunkt abdeckt oder, falls keine solche Bar existiert, -1.
      exact = FALSE: Gibt den Index der Bar zurück, die den angegebenen Zeitpunkt abdeckt oder, falls keine solche Bar existiert, den Index
                     der vorhergehenden, älteren Bar. Existiert keine solche vorhergehende Bar, wird der Index der letzten Bar zurückgegeben.
   */

   // Datenreihe holen
   datetime times[];
   int bars  = ArrayCopySeries(times, MODE_TIME, symbol, period);
   int error = GetLastError();
      if (error == ERS_HISTORY_UPDATE) error = NO_ERROR;
      if (error != NO_ERROR) return(_EMPTY_VALUE(catch("iBarShiftPrevious(2: "+ symbol +","+ PeriodDescription(period) +") => bars="+ bars, error)));
   if (!bars)                return(_EMPTY_VALUE(catch("iBarShiftPrevious(3: "+ symbol +","+ PeriodDescription(period) +") => bars="+ bars, ERR_SERIES_NOT_AVAILABLE)));


   // Bars überprüfen
   if (time < times[bars-1]) {
      int bar = -1;                                                  // Zeitpunkt ist zu alt für die Reihe
   }
   else {
      bar   = iBarShift(symbol, period, time);
      error = GetLastError();
      if (error == ERS_HISTORY_UPDATE) error = NO_ERROR;
      if (error != NO_ERROR) return(_EMPTY_VALUE(catch("iBarShiftPrevious(4: "+ symbol +","+ PeriodDescription(period) +") => bar="+ bar, error)));
   }
   return(bar);
}
