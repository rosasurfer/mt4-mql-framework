/**
 * Load the custom "Moving Average" and return an indicator value.
 *
 * @param  int    timeframe      - timeframe to load the indicator (NULL: the current timeframe)
 * @param  int    maPeriods      - indicator parameter
 * @param  string maMethod       - indicator parameter
 * @param  string maAppliedPrice - indicator parameter
 * @param  int    iBuffer        - indicator buffer index of the value to return
 * @param  int    iBar           - bar index of the value to return
 *
 * @return double - indicator value or NULL in case of errors
 */
double icMovingAverage(int timeframe, int maPeriods, string maMethod, string maAppliedPrice, int iBuffer, int iBar) {
   static int lpSuperContext = 0; if (!lpSuperContext) {
      lpSuperContext = GetIntsAddress(__ExecutionContext);
   }

   double value = iCustom(NULL, timeframe, "Moving Average",
                          maPeriods,                        // int    MA.Periods
                          maMethod,                         // string MA.Method
                          maAppliedPrice,                   // string MA.AppliedPrice

                          "Line",                           // string Draw.Type
                          0,                                // int    Draw.Width
                          Blue,                             // color  UpTrend.Color
                          Blue,                             // color  DownTrend.Color
                          CLR_NONE,                         // color  Background.Color
                          0,                                // int    Background.Width
                          false,                            // bool   ShowChartLegend
                          -1,                               // int    MaxBarsBack

                          "",                               // string __________________________
                          false,                            // bool   Signal.onTrendChange
                          "",                               // string Signal.onTrendChange.Types
                          "",                               // string Signal.Sound.Up
                          "",                               // string Signal.Sound.Down

                          "",                               // string __________________________
                          false,                            // bool   AutoConfiguration
                          lpSuperContext,                   // int    __lpSuperContext

                          iBuffer, iBar);

   int error = GetLastError();
   if (error != NO_ERROR) {
      if (error != ERS_HISTORY_UPDATE) return(!catch("icMovingAverage(1)", error));
      logWarn("icMovingAverage(2)  "+ PeriodDescription(timeframe) +" (tick="+ Ticks +")", ERS_HISTORY_UPDATE);
   }

   error = __ExecutionContext[EC.mqlError];                 // TODO: synchronize execution contexts
   if (!error) return(value);
   return(!SetLastError(error));
}
