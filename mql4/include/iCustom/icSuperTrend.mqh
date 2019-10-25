/**
 * Load the "SuperTrend" indicator and return an indicator value.
 *
 * @param  int timeframe  - timeframe to load the indicator (NULL: the current timeframe)
 * @param  int atrPeriods - indicator parameter
 * @param  int smaPeriods - indicator parameter
 * @param  int iBuffer    - indicator buffer index of the value to return
 * @param  int iBar       - bar index of the value to return
 *
 * @return double - indicator value or NULL in case of errors
 */
double icSuperTrend(int timeframe, int atrPeriods, int smaPeriods, int iBuffer, int iBar) {
   static int lpSuperContext = 0; if (!lpSuperContext)
      lpSuperContext = GetIntsAddress(__ExecutionContext);

   double value = iCustom(NULL, timeframe, "SuperTrend",
                          atrPeriods,                                      // int    ATR.Periods
                          smaPeriods,                                      // int    SMA.Periods

                          Blue,                                            // color  Color.UpTrend
                          Red,                                             // color  Color.DownTrend
                          CLR_NONE,                                        // color  Color.Channel
                          CLR_NONE,                                        // color  Color.MovingAverage
                          "Line",                                          // string Draw.Type
                          1,                                               // int    Draw.LineWidth
                          -1,                                              // int    Max.Values
                          "",                                              // string _____________________
                          "off",                                           // string Signal.onTrendChange
                          "off",                                           // string Signal.Sound
                          "off",                                           // string Signal.Mail.Receiver
                          "off",                                           // string Signal.SMS.Receiver
                          "",                                              // string _____________________
                          lpSuperContext,                                  // int    __SuperContext__

                          iBuffer, iBar);

   int error = GetLastError();
   if (error != NO_ERROR) {
      if (error != ERS_HISTORY_UPDATE)
         return(!catch("icSuperTrend(1)", error));
      warn("icSuperTrend(2)  "+ PeriodDescription(ifInt(!timeframe, Period(), timeframe)) +" (tick="+ Tick +")", ERS_HISTORY_UPDATE);
   }                                                                       // TODO: check number of loaded bars

   error = __ExecutionContext[iEC.mqlError];                               // TODO: synchronize execution contexts
   if (error != NO_ERROR)
      return(!SetLastError(error));
   return(value);
}
