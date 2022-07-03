/**
 * Calculate and return the Average Daily Range of the current symbol. Implemented as LWMA(20, ATR(1)).
 *
 * @param  int flags [optional] - controls error behavior (default: trigger a fatal error)
 *                                F_ERR_NO_HISTORY_DATA: silently handle ERR_NO_HISTORY_DATA
 *
 * @return double - ADR value in quote units or NULL in case of errors
 */
double iADR(int flags = NULL) {
   int maPeriods = 20, error;                            // TODO: convert to current timeframe for non-FXT brokers

   double ranges[];
   ArrayResize(ranges, maPeriods);
   ArraySetAsSeries(ranges, true);

   for (int i=0; i < maPeriods; i++) {
      ranges[i] = iATR(NULL, PERIOD_D1, 1, i+1);

      if (!ranges[i]) {
         error = intOr(GetLastError(), ERR_NO_HISTORY_DATA);
         break;
      }
   }

   if (!error) {
      double adr = iMAOnArray(ranges, WHOLE_ARRAY, maPeriods, 0, MODE_LWMA, 0);
      error = GetLastError();
      if (!error || error==ERS_HISTORY_UPDATE) return(adr);
   }

   if (error==ERR_NO_HISTORY_DATA && flags & F_ERR_NO_HISTORY_DATA)
      return(!SetLastError(error));
   return(!catch("iADR(1)", error));
}
