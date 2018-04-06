/**
 * Load the "NonLagMA" indicator and return a calculated value.
 *
 * @param  int timeframe   - timeframe to load the indicator (NULL: the current timeframe)
 * @param  int cycleLength - indicator parameter
 * @param  int maxValues   - indicator parameter
 * @param  int iBuffer     - indicator buffer index of the value to return
 * @param  int iBar        - bar index of the value to return
 *
 * @return double - value or NULL in case of errors
 */
double icNonLagMA(int timeframe, int cycleLength, int maxValues, int iBuffer, int iBar) {
   static int lpSuperContext = 0; if (!lpSuperContext)
      lpSuperContext = GetIntsAddress(__ExecutionContext);

   double value = iCustom(NULL, timeframe, "NonLagMA",
                          cycleLength,                                     // int    Cycle.Length

                          RoyalBlue,                                       // color  Color.UpTrend
                          Red,                                             // color  Color.DownTrend
                          "Dot",                                           // string Draw.Type
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
                          lpSuperContext,                                  // int    __lpSuperContext

                          iBuffer, iBar);

   int error = GetLastError();
   if (error != NO_ERROR) {
      if (error != ERS_HISTORY_UPDATE)
         return(_NULL(catch("icNonLagMA(1)", error)));
      warn("icNonLagMA(2)  "+ PeriodDescription(ifInt(!timeframe, Period(), timeframe)) +" (tick="+ Tick +")", ERS_HISTORY_UPDATE);
   }                                                                       // TODO: check number of loaded bars

   error = ec_MqlError(__ExecutionContext);                                // TODO: synchronize execution contexts
   if (!error)
      return(value);
   return(_NULL(SetLastError(error)));
}
