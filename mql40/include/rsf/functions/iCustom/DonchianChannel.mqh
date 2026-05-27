
#define Donchian.MODE_UPPER_BAND     0    // upper channel band
#define Donchian.MODE_LOWER_BAND     1    // lower channel band
#define Donchian.MODE_REVERSAL_LONG  2    // all long reversals
#define Donchian.MODE_REVERSAL_SHORT 3    // all short reversals
#define Donchian.MODE_TREND          5    // int: direction and length of the reversals
#define Donchian.MODE_REVERSAL_COUNT 6    // int: number of consecutive winning/losing reversals


/**
 * Load the "Donchian Channel" indicator and return a value.
 *
 * @param  int timeframe - timeframe to load the indicator (NULL: the current timeframe)
 * @param  int periods   - indicator parameter
 * @param  int iBuffer   - indicator buffer index of the value to return
 * @param  int iBar      - bar index of the value to return
 *
 * @return double - indicator value or NULL in case of errors
 */
double icDonchianChannel(int timeframe, int periods, int iBuffer, int iBar) {
   static int lpSuperContext = 0; if (!lpSuperContext) {
      lpSuperContext = GetIntsAddress(__ExecutionContext);
   }

   double value = iCustom(NULL, timeframe, "Donchian Channel",
                          "separator",                // string ___a_______________________
                          periods,                    // int    Periods
                          0,                          // int    Periods.Step

                          false,                      // bool   ShowChannel
                          CLR_NONE,                   // color  Channel.UpperColor
                          CLR_NONE,                   // color  Channel.LowerColor

                          "on",                       // string ShowReversals
                          "dot",                      // string Reversal.Symbol
                          1,                          // int    Reversal.Width
                          CLR_NONE,                   // color  Reversal.Color

                          "separator",                // string ___b_______________________
                          false,                      // bool   ShowChartLegend
                          -1,                         // int    MaxBarsBack

                          "separator",                // string ___c_______________________
                          false,                      // bool   Signal.onReversal
                          "",                         // string Signal.onReversal.Types
                          "",                         // string Signal.onReversal.SoundUp
                          "",                         // string Signal.onReversal.SoundDown

                          false,                      // bool   Sound.onChannelWidening
                          "",                         // string Sound.onNewChannelHigh
                          "",                         // string Sound.onNewChannelLow

                          "separator",                // string ___d_______________________
                          false,                      // bool   TrackReversalBalance
                          "",                         // string TrackReversalBalance.Symbol

                          "separator",                // string _________________________
                          false,                      // bool   AutoConfiguration
                          lpSuperContext,             // int    __lpSuperContext

                          iBuffer, iBar);

   int error = GetLastError();
   if (error != NO_ERROR) {
      if (error != ERS_HISTORY_UPDATE) return(!catch("icDonchianChannel(1)", error));
      logWarn("icDonchianChannel(2)  "+ PeriodDescription(timeframe) +" (tick="+ Ticks +")", ERS_HISTORY_UPDATE);
   }

   error = __ExecutionContext[EC.mqlError];           // TODO: synchronize execution contexts
   if (!error) return(value);
   return(!SetLastError(error));
}
