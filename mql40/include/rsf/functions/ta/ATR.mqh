/**
 * Return the average true range using the built-in function iATR() and perform additional error handling.
 * This function always sets the variable 'last_error' (on success it is reset).
 *
 * @param  string symbol                 - symbol (NULL: the current symbol)
 * @param  int    timeframe              - timeframe (NULL: the current timeframe)
 * @param  int    periods
 * @param  int    offset
 * @param  int    fMuteErrors [optional] - flags of errors which are set silently (default: none)
 *                                         F_ERS_HISTORY_UPDATE: ERS_HISTORY_UPDATE is a status and not an error
 *
 * @return double - ATR value or NULL in case of errors
 */
double ATR(string symbol, int timeframe, int periods, int offset, int fMuteErrors = NULL) {
   if (symbol == "0") symbol = Symbol();                       // (string) NULL

   int error = GetLastError();
   if (error != NO_ERROR) return(!catch("ATR(1)", error));     // catch previously unhandled errors

   double result = iATR(symbol, timeframe, periods, offset);

   error = GetLastError();
   if (!error) {
      SetLastError(NO_ERROR);                                  // reset last_error
      return(result);
   }

   if (error == ERR_SERIES_NOT_AVAILABLE) {
      if (!IsStandardTimeframe(timeframe)) return(!catch("ATR(2)  "+ PeriodDescription(timeframe), error));

      // with built-in timeframes ERR_SERIES_NOT_AVAILABLE (no local history) means ERS_HISTORY_UPDATE
      logDebug("ATR(3)  converting ERR_SERIES_NOT_AVAILABLE to ERS_HISTORY_UPDATE");
      error = ERS_HISTORY_UPDATE;
   }

   if (error == ERS_HISTORY_UPDATE) {
      if (fMuteErrors & F_ERS_HISTORY_UPDATE && 1) {
         SetLastError(error);                                  // set status silently
         return(result);                                       // may/may not be NULL
      }
   }
   return(!catch("ATR(4)  "+ PeriodDescription(timeframe), error));
}
