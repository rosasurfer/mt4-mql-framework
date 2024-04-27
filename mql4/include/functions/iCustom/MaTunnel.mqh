
#define MaTunnel.MODE_UPPER_BAND    0                 // indicator buffer ids
#define MaTunnel.MODE_LOWER_BAND    1                 //
#define MaTunnel.MODE_BAR_TREND     2                 //
#define MaTunnel.MODE_TICK_TREND    3                 //


/**
 * Load the "MA Tunnel" indicator and return a value.
 *
 * @param  int    timeframe        - timeframe to load the indicator (NULL: the current timeframe)
 * @param  string tunnelDefinition - indicator parameter
 * @param  int    iBuffer          - indicator buffer index of the value to return
 * @param  int    iBar             - bar index of the value to return
 *
 * @return double - indicator value or NULL in case of errors
 */
double icMaTunnel(int timeframe, string tunnelDefinition, int iBuffer, int iBar) {
   static int lpSuperContext = 0; if (!lpSuperContext)
      lpSuperContext = GetIntsAddress(__ExecutionContext);

   double value = iCustom(NULL, timeframe, "MA Tunnel",
                          tunnelDefinition,           // string Tunnel.Definition
                          "",                         // string Supported.MA.Methods
                          Blue,                       // color  Tunnel.Color
                          false,                      // bool   ShowChartLegend
                          -1,                         // int    MaxBarsBack

                          "",                         // string ____________________________
                          false,                      // bool   Signal.onBarCross
                          false,                      // bool   Signal.onBarCross.Sound
                          "",                         // string Signal.onBarCross.SoundUp
                          "",                         // string Signal.onBarCross.SoundDown
                          false,                      // bool   Signal.onBarCross.Alert
                          false,                      // bool   Signal.onBarCross.Mail
                          false,                      // bool   Signal.onBarCross.SMS

                          "",                         // string ____________________________
                          false,                      // bool   Signal.onTickCross.Sound
                          "",                         // string Signal.onTickCross.SoundUp
                          "",                         // string Signal.onTickCross.SoundDown

                          "",                         // string ____________________________
                          false,                      // bool   AutoConfiguration
                          lpSuperContext,             // int    __lpSuperContext

                          iBuffer, iBar);

   int error = GetLastError();
   if (error != NO_ERROR) {
      if (error != ERS_HISTORY_UPDATE)
         return(!catch("icMaTunnel(1)", error));
      logWarn("icMaTunnel(2)  "+ PeriodDescription(ifInt(!timeframe, Period(), timeframe)) +" (tick="+ Ticks +")", ERS_HISTORY_UPDATE);
   }

   error = __ExecutionContext[EC.mqlError];           // TODO: synchronize execution contexts
   if (!error)
      return(value);
   return(!SetLastError(error));
}
