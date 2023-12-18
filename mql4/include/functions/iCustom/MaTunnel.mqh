/**
 * Load the "MA Tunnel" indicator and return a value.
 *
 * @param  int    timeframe - timeframe to load the indicator (NULL: the current timeframe)
 * @param  int    maPeriods - indicator parameter
 * @param  string maMethod  - indicator parameter
 * @param  int    iBuffer   - indicator buffer index of the value to return
 * @param  int    iBar      - bar index of the value to return
 *
 * @return double - indicator value or NULL in case of errors
 */
double icMaTunnel(int timeframe, int maPeriods, string maMethod, int iBuffer, int iBar) {
   static int lpSuperContext = 0; if (!lpSuperContext)
      lpSuperContext = GetIntsAddress(__ExecutionContext);

   double value = iCustom(NULL, timeframe, "MA Tunnel",
                          maPeriods,                        // int    MA.Periods
                          maMethod,                         // string MA.Method
                          Blue,                             // color  Tunnel.Color
                          -1,                               // int    Max.Bars
                          false,                            // bool   ShowChartLegend
                          "",                               // string ____________________________
                          false,                            // bool   Signal.onBarCross
                          false,                            // bool   Signal.onBarCross.Sound
                          "",                               // string Signal.onBarCross.SoundUp
                          "",                               // string Signal.onBarCross.SoundDown
                          false,                            // bool   Signal.onBarCross.Popup
                          false,                            // bool   Signal.onBarCross.Mail
                          false,                            // bool   Signal.onBarCross.SMS
                          "",                               // string ____________________________
                          false,                            // bool   Signal.onTickCross.Sound
                          "",                               // string Signal.onTickCross.SoundUp
                          "",                               // string Signal.onTickCross.SoundDown
                          "",                               // string ____________________________
                          false,                            // bool   AutoConfiguration
                          lpSuperContext,                   // int    __lpSuperContext

                          iBuffer, iBar);

   int error = GetLastError();
   if (error != NO_ERROR) {
      if (error != ERS_HISTORY_UPDATE)
         return(!catch("icMaTunnel(1)", error));
      logWarn("icMaTunnel(2)  "+ PeriodDescription(ifInt(!timeframe, Period(), timeframe)) +" (tick="+ Ticks +")", ERS_HISTORY_UPDATE);
   }

   error = __ExecutionContext[EC.mqlError];                 // TODO: synchronize execution contexts
   if (!error)
      return(value);
   return(!SetLastError(error));
}
