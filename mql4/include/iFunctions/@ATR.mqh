/**
 * Ermittelt einen ATR-Value. Die Funktion setzt immer den internen Fehlercode, bei Erfolg setzt sie ihn also zurück.
 *
 * @param  string symbol    - Symbol    (default: NULL = das aktuelle Symbol   )
 * @param  int    timeframe - Timeframe (default: NULL = der aktuelle Timeframe)
 * @param  int    periods
 * @param  int    offset
 *
 * @return double - ATR-Value oder -1 (EMPTY), falls ein Fehler auftrat
 */
double @ATR(string symbol, int timeframe, int periods, int offset) {// throws ERS_HISTORY_UPDATE
   if (symbol == "0")         // (string) NULL
      symbol = Symbol();

   double atr = iATR(symbol, timeframe, periods, offset);// throws ERS_HISTORY_UPDATE, ERR_SERIES_NOT_AVAILABLE

   int error = GetLastError();
   if (error != NO_ERROR) {
      if      (timeframe == Period()            ) {                                     return(_EMPTY(catch("@ATR(1)", error))); }    // sollte niemals auftreten
      if      (error == ERR_SERIES_NOT_AVAILABLE) { if (!IsBuiltinTimeframe(timeframe)) return(_EMPTY(catch("@ATR(2)", error))); }
      else if (error != ERS_HISTORY_UPDATE      ) {                                     return(_EMPTY(catch("@ATR(3)", error))); }
      atr   = 0;
      error = ERS_HISTORY_UPDATE;
   }

   SetLastError(error);
   return(atr);
}
