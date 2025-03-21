#define ZigZag.MODE_SEMAPHORE_OPEN     0              // semaphore open prices
#define ZigZag.MODE_SEMAPHORE_CLOSE    1              // semaphore close prices
#define ZigZag.MODE_UPPER_BAND         2              // upper channel band
#define ZigZag.MODE_LOWER_BAND         3              // lower channel band
#define ZigZag.MODE_UPPER_CROSS        4              // upper channel band crossings
#define ZigZag.MODE_LOWER_CROSS        5              // lower channel band crossings
#define ZigZag.MODE_REVERSAL           6              // offset of the previous ZigZag reversal to the preceeding semaphore
#define ZigZag.MODE_TREND              7              // trend (combined buffers MODE_KNOWN_TREND and MODE_UNKNOWN_TREND)


/**
 * Load the custom "ZigZag" indicator and return a value.
 *
 * @param  int timeframe - timeframe to load the indicator (NULL: the current timeframe)
 * @param  int periods   - indicator parameter
 * @param  int iBuffer   - indicator buffer index of the value to return
 * @param  int iBar      - bar index of the value to return
 *
 * @return double - indicator value or NULL in case of errors
 */
double icZigZag(int timeframe, int periods, int iBuffer, int iBar) {
   static int lpSuperContext = 0; if (!lpSuperContext) {
      lpSuperContext = GetIntsAddress(__ExecutionContext);
   }

   double value = iCustom(NULL, timeframe, "ZigZag",
                          "separator",                // string   ____________________________
                          periods,                    // int      ZigZag.Periods
                          0,                          // int      ZigZag.Periods.Step
                          "Line",                     // string   ZigZag.Type
                          "dot",                      // string   ZigZag.Semaphores.Symbol
                          1,                          // int      ZigZag.Width
                          CLR_NONE,                   // color    ZigZag.Color

                          "separator",                // string   ____________________________
                          false,                      // bool     Donchian.ShowChannel
                          CLR_NONE,                   // color    Donchian.Channel.UpperColor
                          CLR_NONE,                   // color    Donchian.Channel.LowerColor
                          "all",                      // string   Donchian.ShowCrossings
                          "ring",                     // string   Donchian.Crossing.Symbol
                          1,                          // int      Donchian.Crossing.Width
                          CLR_NONE,                   // color    Donchian.Crossing.Color

                          "separator",                // string   ____________________________
                          false,                      // bool     TrackReversalBalance
                          0,                          // datetime TrackReversalBalance.Since
                          false,                      // bool     ProjectReversalBalance

                          "separator",                // string   ____________________________
                          false,                      // bool     ShowChartLegend
                          -1,                         // int      MaxBarsBack

                          "separator",                // string   ____________________________
                          false,                      // bool     Signal.onReversal
                          "",                         // string   Signal.onReversal.Types

                          false,                      // bool     Signal.onBreakout
                          "",                         // string   Signal.onBreakout.Types

                          "",                         // string   Signal.Sound.Up
                          "",                         // string   Signal.Sound.Down

                          false,                      // bool     Sound.onChannelWidening
                          "",                         // string   Sound.onNewChannelHigh
                          "",                         // string   Sound.onNewChannelLow

                          "separator",                // string   ____________________________
                          false,                      // bool     AutoConfiguration
                          lpSuperContext,             // int      __lpSuperContext

                          iBuffer, iBar);

   int error = GetLastError();
   if (error != NO_ERROR) {
      if (error != ERS_HISTORY_UPDATE) return(!catch("icZigZag(1)", error));
      logWarn("icZigZag(2)  "+ PeriodDescription(timeframe) +" (tick="+ Ticks +")", ERS_HISTORY_UPDATE);
   }

   error = __ExecutionContext[EC.mqlError];           // TODO: synchronize execution contexts
   if (!error) return(value);
   return(!SetLastError(error));
}
