#define HalfTrend.MODE_MAIN       MODE_MAIN              // SR line (0)
#define HalfTrend.MODE_TREND              1              // trend direction and length


/**
 * Load the "HalfTrend" indicator and return a value.
 *
 * @param  int timeframe - timeframe to load the indicator (NULL: the current timeframe)
 * @param  int periods   - indicator parameter
 * @param  int iBuffer   - indicator buffer index of the value to return
 * @param  int iBar      - bar index of the value to return
 *
 * @return double - indicator value or NULL in case of errors
 */
double icHalfTrend(int timeframe, int periods, int iBuffer, int iBar) {
   static int lpSuperContext = 0; if (!lpSuperContext) {
      lpSuperContext = GetIntsAddress(__ExecutionContext);
   }

   double value = iCustom(NULL, timeframe, "HalfTrend",
                          periods,                       // int    Periods
                          Blue,                          // color  Color.UpTrend
                          Red,                           // color  Color.DownTrend
                          CLR_NONE,                      // color  Color.Channel
                          "Line",                        // string Draw.Type
                          1,                             // int    Draw.Width
                          -1,                            // int    MaxBarsBack

                          "",                            // string ______________________________
                          false,                         // bool   Signal.onTrendChange
                          false,                         // bool   Signal.onTrendChange.Sound
                          "",                            // string Signal.onTrendChange.SoundUp
                          "",                            // string Signal.onTrendChange.SoundDown
                          false,                         // bool   Signal.onTrendChange.Alert
                          false,                         // bool   Signal.onTrendChange.Mail
                          false,                         // bool   Signal.onTrendChange.SMS

                          "",                            // string ______________________________
                          false,                         // bool   AutoConfiguration
                          lpSuperContext,                // int    __lpSuperContext

                          iBuffer, iBar);

   int error = GetLastError();
   if (error != NO_ERROR) {
      if (error != ERS_HISTORY_UPDATE) return(!catch("icHalfTrend(1)", error));
      logWarn("icHalfTrend(2)  "+ PeriodDescription(timeframe) +" (tick="+ Ticks +")", ERS_HISTORY_UPDATE);
   }

   error = __ExecutionContext[EC.mqlError];              // TODO: synchronize execution contexts
   if (!error) return(value);
   return(!SetLastError(error));
}
