/**
 * Load the "Volume Delta" indicator and return an indicator value.
 *
 * @param  int timeframe   - timeframe to load the indicator (NULL: the current timeframe)
 * @param  int signalLevel - indicator parameter
 * @param  int iBuffer     - buffer index of the value to return: VolumeDelta.MODE_MAIN | VolumeDelta.MODE_SIGNAL
 * @param  int iBar        - bar index of the value to return
 *
 * @return double - indicator value or NULL in case of errors
 */
double icVolumeDelta(int timeframe, int signalLevel, int iBuffer, int iBar) {
   if (iBar < 0) return(!catch("icVolumeDelta(1)  invalid parameter iBar: "+ iBar, ERR_INVALID_PARAMETER));

   static int lpSuperContext = 0; if (!lpSuperContext) {
      lpSuperContext = GetIntsAddress(__ExecutionContext);
   }

   double value = iCustom(NULL, timeframe, "Volume Delta",
                          LimeGreen,                                       // color  Histogram.Color.Long
                          Red,                                             // color  Histogram.Color.Short
                          2,                                               // int    Histogram.Style.Width

                          -1,                                              // int    Max.Values

                          "",                                              // string _____________________
                          signalLevel,                                     // int    Signal.Level
                          "off",                                           // string Signal.onLevelCross
                          "off",                                           // string Signal.Sound
                          "off",                                           // string Signal.Mail.Receiver
                          "off",                                           // string Signal.SMS.Receiver

                          "",                                              // string _____________________
                          lpSuperContext,                                  // int    __lpSuperContext

                          iBuffer, iBar);

   int error = GetLastError();
   if (error != NO_ERROR) {
      if (error != ERS_HISTORY_UPDATE)
         return(!catch("icVolumeDelta(2)", error));
      warn("icVolumeDelta(3)  "+ PeriodDescription(ifInt(!timeframe, Period(), timeframe)) +" (tick="+ Tick +")", ERS_HISTORY_UPDATE);
   }
   error = ec_MqlError(__ExecutionContext);                                // TODO: synchronize execution contexts
   if (error != NO_ERROR)
      return(!SetLastError(error));
   return(value);
}
