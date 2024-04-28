/**
 * Load the "ALMA" indicator and return a value.
 *
 * @param  int    timeframe          - timeframe to load the indicator (NULL: the current timeframe)
 * @param  int    maPeriods          - indicator parameter
 * @param  string maAppliedPrice     - indicator parameter
 * @param  double distributionOffset - indicator parameter
 * @param  double distributionSigma  - indicator parameter
 * @param  double maReversalFilter   - indicator parameter
 * @param  int    iBuffer            - indicator buffer index of the value to return
 * @param  int    iBar               - bar index of the value to return
 *
 * @return double - indicator value or NULL in case of errors
 */
double icALMA(int timeframe, int maPeriods, string maAppliedPrice, double distributionOffset, double distributionSigma, double maReversalFilter, int iBuffer, int iBar) {
   static int lpSuperContext = 0; if (!lpSuperContext) {
      lpSuperContext = GetIntsAddress(__ExecutionContext);
   }

   double value = iCustom(NULL, timeframe, "ALMA",
                          maPeriods,                  // int    MA.Periods
                          0,                          // int    MA.Periods.Step
                          maAppliedPrice,             // string MA.AppliedPrice
                          distributionOffset,         // double Distribution.Offset
                          distributionSigma,          // double Distribution.Sigma
                          maReversalFilter,           // double MA.ReversalFilter
                          0,                          // double MA.ReversalFilter.Step

                          "Line",                     // string Draw.Type
                          1,                          // int    Draw.Width
                          CLR_NONE,                   // color  Color.UpTrend
                          CLR_NONE,                   // color  Color.DownTrend
                          false,                      // bool   ShowChartLegend
                          -1,                         // int    MaxBarsBack

                          "",                         // string __________________________
                          false,                      // bool   Signal.onTrendChange
                          "",                         // string Signal.onTrendChange.Types
                          "",                         // string Signal.Sound.Up
                          "",                         // string Signal.Sound.Down

                          "",                         // string __________________________
                          false,                      // bool   AutoConfiguration
                          lpSuperContext,             // int    __lpSuperContext

                          iBuffer, iBar);

   int error = GetLastError();
   if (error != NO_ERROR) {
      if (error != ERS_HISTORY_UPDATE) return(!catch("icALMA(1)", error));
      logWarn("icALMA(2)  "+ PeriodDescription(ifInt(!timeframe, Period(), timeframe)) +" (tick="+ Ticks +")", ERS_HISTORY_UPDATE);
   }

   error = __ExecutionContext[EC.mqlError];           // TODO: synchronize execution contexts
   if (!error) return(value);
   return(!SetLastError(error));
}
