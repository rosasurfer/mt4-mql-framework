
#define MACD.MODE_MAIN     MODE_MAIN         // MACD main line
#define MACD.MODE_SECTION          1         // MACD trend and trend length


/**
 * Load the custom "MACD" indicator and return a value.
 *
 * @param  int    timeframe          - timeframe to load the indicator (NULL: the current timeframe)
 * @param  int    fastMaPeriods      - indicator parameter
 * @param  string fastMaMethod       - indicator parameter
 * @param  string fastMaAppliedPrice - indicator parameter
 * @param  int    slowMaPeriods      - indicator parameter
 * @param  string slowMaMethod       - indicator parameter
 * @param  string slowMaAppliedPrice - indicator parameter
 * @param  int    iBuffer            - indicator buffer index of the value to return
 * @param  int    iBar               - bar index of the value to return
 *
 * @return double - indicator value or NULL in case of errors
 */
double icMACD(int timeframe, int fastMaPeriods, string fastMaMethod, string fastMaAppliedPrice, int slowMaPeriods, string slowMaMethod, string slowMaAppliedPrice, int iBuffer, int iBar) {
   static int lpSuperContext = 0; if (!lpSuperContext) {
      lpSuperContext = GetIntsAddress(__ExecutionContext);
   }

   double value = iCustom(NULL, timeframe, "MACD",
                          fastMaPeriods,                    // int    Fast.MA.Periods
                          fastMaMethod,                     // string Fast.MA.Method
                          fastMaAppliedPrice,               // string Fast.MA.AppliedPrice
                          slowMaPeriods,                    // int    Slow.MA.Periods
                          slowMaMethod,                     // string Slow.MA.Method
                          slowMaAppliedPrice,               // string Slow.MA.AppliedPrice
                          Blue,                             // color  MainLine.Color
                          1,                                // int    MainLine.Width
                          Green,                            // color  Histogram.Color.Upper
                          Red,                              // color  Histogram.Color.Lower
                          2,                                // int    Histogram.Style.Width
                          -1,                               // int    MaxBarsBack

                          "",                               // string ________________________
                          false,                            // bool   Signal.onCross
                          false,                            // bool   Signal.onCross.Sound
                          "",                               // string Signal.onCross.SoundUp
                          "",                               // string Signal.onCross.SoundDown
                          false,                            // bool   Signal.onCross.Alert
                          false,                            // bool   Signal.onCross.Mail
                          false,                            // bool   Signal.onCross.SMS

                          "",                               // string ________________________
                          false,                            // bool   AutoConfiguration
                          lpSuperContext,                   // int    __lpSuperContext

                          iBuffer, iBar);

   int error = GetLastError();
   if (error != NO_ERROR) {
      if (error != ERS_HISTORY_UPDATE) return(!catch("icMACD(1)", error));
      logWarn("icMACD(2)  "+ PeriodDescription(ifInt(!timeframe, Period(), timeframe)) +" (tick="+ Ticks +")", ERS_HISTORY_UPDATE);
   }

   error = __ExecutionContext[EC.mqlError];                 // TODO: synchronize execution contexts
   if (!error) return(value);
   return(!SetLastError(error));
}
