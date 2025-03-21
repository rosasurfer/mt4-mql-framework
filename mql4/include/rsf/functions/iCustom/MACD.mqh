#define MACD.MODE_MAIN     MODE_MAIN                  // main line
#define MACD.MODE_TREND            1                  // trend and trend length


/**
 * Load the custom "MACD" indicator and return a value.
 *
 * @param  int    timeframe          - timeframe to load the indicator (NULL: the current timeframe)
 * @param  string fastMaMethod       - indicator parameter
 * @param  int    fastMaPeriods      - indicator parameter
 * @param  string fastMaAppliedPrice - indicator parameter
 * @param  string slowMaMethod       - indicator parameter
 * @param  int    slowMaPeriods      - indicator parameter
 * @param  string slowMaAppliedPrice - indicator parameter
 * @param  string unit               - indicator parameter
 * @param  int    adrPeriods         - indicator parameter
 * @param  int    iBuffer            - indicator buffer index of the value to return
 * @param  int    iBar               - bar index of the value to return
 *
 * @return double - indicator value or NULL in case of errors
 */
double icMACD(int timeframe, string fastMaMethod, int fastMaPeriods, string fastMaAppliedPrice, string slowMaMethod, int slowMaPeriods, string slowMaAppliedPrice, string unit, int adrPeriods, int iBuffer, int iBar) {
   static int lpSuperContext = 0; if (!lpSuperContext) {
      lpSuperContext = GetIntsAddress(__ExecutionContext);
   }

   double value = iCustom(NULL, timeframe, "MACD",
                          fastMaMethod,               // string Fast.MA.Method
                          fastMaPeriods,              // int    Fast.MA.Periods
                          fastMaAppliedPrice,         // string Fast.MA.AppliedPrice

                          slowMaMethod,               // string Slow.MA.Method
                          slowMaPeriods,              // int    Slow.MA.Periods
                          slowMaAppliedPrice,         // string Slow.MA.AppliedPrice

                          Green,                      // color  Histogram.Color.Upper
                          Red,                        // color  Histogram.Color.Lower
                          2,                          // int    Histogram.Style.Width

                          Blue,                       // color  MainLine.Color
                          1,                          // int    MainLine.Width

                          "",                         // string _____________________
                          unit,                       // string VScale.Unit
                          adrPeriods,                 // int    VScale.ADR.Periods
                          -1,                         // int    MaxBarsBack

                          "",                         // string _____________________
                          false,                      // bool   Signal.onCross
                          "",                         // string Signal.onCross.Types
                          "",                         // string Signal.Sound.Up
                          "",                         // string Signal.Sound.Down

                          "",                         // string _____________________
                          false,                      // bool   AutoConfiguration
                          lpSuperContext,             // int    __lpSuperContext

                          iBuffer, iBar);

   int error = GetLastError();
   if (error != NO_ERROR) {
      if (error != ERS_HISTORY_UPDATE) return(!catch("icMACD(1)", error));
      logWarn("icMACD(2)  "+ PeriodDescription(timeframe) +" (tick="+ Ticks +")", ERS_HISTORY_UPDATE);
   }

   error = __ExecutionContext[EC.mqlError];           // TODO: synchronize execution contexts
   if (!error) return(value);
   return(!SetLastError(error));
}
