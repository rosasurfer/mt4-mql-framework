/**
 * Load the "MACD" indicator and calculate and return a value.
 *
 * @param  int    timeframe          - timeframe to load the indicator in (NULL: current timeframe)
 * @param  int    fastMaPeriods      - indicator parameter
 * @param  string fastMaMethod       - indicator parameter
 * @param  string fastMaAppliedPrice - indicator parameter
 * @param  int    slowMaPeriods      - indicator parameter
 * @param  string slowMaMethod       - indicator parameter
 * @param  string slowMaAppliedPrice - indicator parameter
 * @param  int    maxValues          - indicator parameter
 * @param  int    iBuffer            - buffer index of the value to return
 * @param  int    iBar               - bar index of the value to return
 *
 * @return double - value or NULL in case of errors
 */
double icMACD(int timeframe/*=NULL*/, int fastMaPeriods, string fastMaMethod, string fastMaAppliedPrice, int slowMaPeriods, string slowMaMethod, string slowMaAppliedPrice, int maxValues, int iBuffer, int iBar) {
   static int lpSuperContext = 0; if (!lpSuperContext)
      lpSuperContext = GetIntsAddress(__ExecutionContext);

   double value = iCustom(NULL, timeframe, "MACD ",
                          fastMaPeriods,                                   // int    Fast.MA.Periods
                          fastMaMethod,                                    // string Fast.MA.Method
                          fastMaAppliedPrice,                              // string Fast.MA.AppliedPrice

                          slowMaPeriods,                                   // int    Slow.MA.Periods
                          slowMaMethod,                                    // string Slow.MA.Method
                          slowMaAppliedPrice,                              // string Slow.MA.AppliedPrice

                          DodgerBlue,                                      // color  Color.MainLine
                          1,                                               // int    Style.MainLine.Width
                          LimeGreen,                                       // color  Color.Histogram.Upper
                          Red,                                             // color  Color.Histogram.Lower
                          2,                                               // int    Style.Histogram.Width

                          maxValues,                                       // int    Max.Values

                          "",                                              // string _____________________
                          false,                                           // bool   Signal.onZeroCross
                          "off",                                           // string Signal.Sound
                          "off",                                           // string Signal.Mail.Receiver
                          "off",                                           // string Signal.SMS.Receiver

                          "",                                              // string _____________________
                          lpSuperContext,                                  // int    __SuperContext__

                          iBuffer, iBar);

   int error = GetLastError();
   if (IsError(error)) {
      if (error != ERS_HISTORY_UPDATE)
         return(_NULL(catch("icMACD(1)", error)));
      warn("icMACD(2)  "+ PeriodDescription(ifInt(!timeframe, Period(), timeframe)) +" (tick="+ Tick +")", ERS_HISTORY_UPDATE);
   }                                                                       // TODO: check number of loaded bars

   error = ec_MqlError(__ExecutionContext);                                // TODO: synchronize execution contexts
   if (!error)
      return(value);
   return(_NULL(SetLastError(error)));
}
