/**
 * Load the "Jurik Moving Average" and return an indicator value.
 *
 * @param  int    timeframe    - timeframe to load the indicator (NULL: the current timeframe)
 * @param  int    periods      - indicator parameter
 * @param  int    phase        - indicator parameter
 * @param  string appliedPrice - indicator parameter
 * @param  int    iBuffer      - indicator buffer index of the value to return
 * @param  int    iBar         - bar index of the value to return
 *
 * @return double - indicator value or NULL in case of errors
 */
double icJMA(int timeframe, int periods, int phase, string appliedPrice, int iBuffer, int iBar) {
   static int lpSuperContext = 0; if (!lpSuperContext) {
      lpSuperContext = GetIntsAddress(__ExecutionContext);
   }

   double value = iCustom(NULL, timeframe, "Jurik Moving Average",
                          periods,                                // int    Periods
                          phase,                                  // int    Phase
                          appliedPrice,                           // string AppliedPrice
                          Blue,                                   // color  Color.UpTrend
                          Red,                                    // color  Color.DownTrend
                          "Line",                                 // string Draw.Type
                          1,                                      // int    Draw.Width

                          "",                                     // string ______________________________
                          false,                                  // bool   Signal.onTrendChange
                          false,                                  // bool   Signal.onTrendChange.Sound
                          "",                                     // string Signal.onTrendChange.SoundUp
                          "",                                     // string Signal.onTrendChange.SoundDown
                          false,                                  // bool   Signal.onTrendChange.Alert
                          false,                                  // bool   Signal.onTrendChange.Mail

                          "",                                     // string ______________________________
                          false,                                  // bool   AutoConfiguration
                          lpSuperContext,                         // int    __lpSuperContext

                          iBuffer, iBar);

   int error = GetLastError();
   if (error != NO_ERROR) {
      if (error != ERS_HISTORY_UPDATE) return(!catch("icJMA(1)", error));
      logWarn("icJMA(2)  "+ PeriodDescription(timeframe) +" (tick="+ Ticks +")", ERS_HISTORY_UPDATE);
   }

   error = __ExecutionContext[EC.mqlError];                 // TODO: synchronize execution contexts
   if (!error) return(value);
   return(!SetLastError(error));
}
