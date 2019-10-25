/**
 * Load the "NonLagMA" indicator and return an indicator value.
 *
 * @param  int timeframe   - timeframe to load the indicator (NULL: the current timeframe)
 * @param  int cycleLength - indicator parameter
 * @param  int iBuffer     - indicator buffer index of the value to return
 * @param  int iBar        - bar index of the value to return
 *
 * @return double - indicator value or NULL in case of errors
 */
double icNonLagMA(int timeframe, int cycleLength, int iBuffer, int iBar) {
   static int lpSuperContext = 0; if (!lpSuperContext)
      lpSuperContext = GetIntsAddress(__ExecutionContext);

   double value = iCustom(NULL, timeframe, "NonLagMA",
                          cycleLength,                                     // int    Cycle.Length

                          RoyalBlue,                                       // color  Color.UpTrend
                          Red,                                             // color  Color.DownTrend
                          "Dot",                                           // string Draw.Type
                          1,                                               // int    Draw.LineWidth
                          -1,                                              // int    Max.Values
                          "",                                              // string _____________________
                          "off",                                           // string Signal.onTrendChange
                          "off",                                           // string Signal.Sound
                          "off",                                           // string Signal.Mail.Receiver
                          "off",                                           // string Signal.SMS.Receiver
                          "",                                              // string _____________________
                          lpSuperContext,                                  // int    __lpSuperContext

                          iBuffer, iBar);

   int error = GetLastError();
   if (error != NO_ERROR) {
      if (error != ERS_HISTORY_UPDATE)
         return(!catch("icNonLagMA(1)", error));
      warn("icNonLagMA(2)  "+ PeriodDescription(ifInt(!timeframe, Period(), timeframe)) +" (tick="+ Tick +")", ERS_HISTORY_UPDATE);
   }                                                                       // TODO: check number of loaded bars

   error = __ExecutionContext[EC.mqlError];                                // TODO: synchronize execution contexts
   if (error != NO_ERROR)
      return(!SetLastError(error));
   return(value);
}
