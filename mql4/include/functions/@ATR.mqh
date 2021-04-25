/**
 * Return the average true range from the built-in function iATR() and perform additional error handling.
 * The function always writes the last_error variable (on success it is reset).
 *
 * @param  string symbol                   - symbol    (NULL = the current symbol)
 * @param  int    timeframe                - timeframe (NULL = the current timeframe)
 * @param  int    periods
 * @param  int    offset
 * @param  int    fIgnoreErrors [optional] - flags of errors to ignore (default: none)
 *                                           supported values: F_ERS_HISTORY_UPDATE (see notes)
 *
 * @return double - ATR value or NULL in case of an error not covered by the passed fIgnoreErrors flags
 *
 * Note: As ERS_HISTORY_UPDATE is a status and not a regular error the status is set even if the error is ignored
 *       (by passing F_ERS_HISTORY_UPDATE). Thus it is possible to ignore the error and to query a set ERS_HISTORY_UPDATE
 *       status in the calling code.
 */
double @ATR(string symbol, int timeframe, int periods, int offset, int fIgnoreErrors = NULL) {
   int error = GetLastError();
   if (error != NO_ERROR) return(!catch("@ATR(1)", error));    // catch previously unhandled errors

   if (symbol == "0")         // (string) NULL
      symbol = Symbol();
   double result = iATR(symbol, timeframe, periods, offset);   // throws ERR_SERIES_NOT_AVAILABLE | ERS_HISTORY_UPDATE

   error = GetLastError();
   if (error == NO_ERROR) {
      SetLastError(NO_ERROR);                                  // reset all errors
      return(result);
   }

   if (error == ERR_SERIES_NOT_AVAILABLE) {
      if (IsStdTimeframe(timeframe)) {                         // On built-in timeframes ERR_SERIES_NOT_AVAILABLE essentially
         error = ERS_HISTORY_UPDATE;                           // means ERS_HISTORY_UPDATE.
         debug("@ATR(2)  silently converting ERR_SERIES_NOT_AVAILABLE to ERS_HISTORY_UPDATE");
      }
      else {
         return(!catch("@ATR(3)  "+ PeriodDescription(ifInt(!timeframe, Period(), timeframe)), error));
      }
   }

   if (error == ERS_HISTORY_UPDATE) {
      if (fIgnoreErrors & F_ERS_HISTORY_UPDATE && 1) {
         SetLastError(ERS_HISTORY_UPDATE);                     // set the status
         return(result);                                       // ignore the error (result may be NULL)
      }
   }
   return(!catch("@ATR(4)  "+ PeriodDescription(ifInt(!timeframe, Period(), timeframe)), error));
}
