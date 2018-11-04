/**
 * Load the "RSI" indicator and return an indicator value.
 *
 * @param  int    timeframe       - timeframe to load the indicator (NULL: the current timeframe)
 *
 * @param  int    rsiPeriods      - indicator parameter
 * @param  string rsiAppliedPrice - indicator parameter
 * @param  int    maxValues       - indicator parameter
 *
 * @param  int    iBuffer         - indicator buffer index of the value to return
 * @param  int    iBar            - bar index of the value to return
 *
 * @return double - indicator value or NULL in case of errors
 */
double icRSI(int timeframe, int rsiPeriods, string rsiAppliedPrice, int maxValues, int iBuffer, int iBar) {
   static int lpSuperContext = 0; if (!lpSuperContext)
      lpSuperContext = GetIntsAddress(__ExecutionContext);

   double value = iCustom(NULL, timeframe, "RSI ",
                          rsiPeriods,                                      // int    RSI.Periods
                          rsiAppliedPrice,                                 // string RSI.AppliedPrice

                          Blue,                                            // color  MainLine.Color
                          1,                                               // int    MainLine.Width

                          Blue,                                            // color  Histogram.Color.Upper
                          Red,                                             // color  Histogram.Color.Lower
                          0,                                               // int    Histogram.Style.Width

                          maxValues,                                       // int    Max.Values
                          "",                                              // string _____________________
                          lpSuperContext,                                  // int    __SuperContext__

                          iBuffer, iBar);

   int error = GetLastError();
   if (error != NO_ERROR) {
      if (error != ERS_HISTORY_UPDATE)
         return(!catch("icRSI(1)", error));
      warn("icRSI(2)  "+ PeriodDescription(ifInt(!timeframe, Period(), timeframe)) +" (tick="+ Tick +")", ERS_HISTORY_UPDATE);
   }                                                                       // TODO: check number of loaded bars

   error = __ExecutionContext[I_EC.mqlError];                              // TODO: synchronize execution contexts
   if (error != NO_ERROR)
      return(!SetLastError(error));
   return(value);
}
