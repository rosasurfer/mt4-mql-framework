
#define ZigZag.MODE_UPPER_BAND         0              // upper channel band: positive or 0
#define ZigZag.MODE_LOWER_BAND         1              // lower channel band: positive or 0
#define ZigZag.MODE_SEMAPHORE_OPEN     2              // semaphore open prices: positive or 0
#define ZigZag.MODE_SEMAPHORE_CLOSE    3              // semaphore close prices: positive or 0 (if open != close it forms a vertical line segment)
#define ZigZag.MODE_UPPER_CROSS        4              // upper channel band crossings: positive or 0
#define ZigZag.MODE_LOWER_CROSS        5              // lower channel band crossings: positive or 0
#define ZigZag.MODE_REVERSAL_OFFSET    6              // int: offset of the ZigZag reversal to the leg's start semaphore: non-negative or -1
#define ZigZag.MODE_COMBINED_TREND     7              // int: combined internal buffers MODE_TREND and MODE_UNKNOWN_TREND: positive/negative or 0

/**
 * Notes
 * -----
 * Since MQL4.0 limits the number of available indicator buffers to 8, MODE_TREND and MODE_UNKNOWN_TREND are combined into
 * a single buffer ZigZag.MODE_COMBIND_TREND (7). To retrieve the original values with iCustom(), input "TrendBufferAsDecimal"
 * must be set to FALSE.
 *
 * Each value from buffer ZigZag.MODE_COMBIND_TREND must be cast to an integer. The LOWORD of this integer holds the MODE_TREND
 * value, and the HIWORD of the integer holds the MODE_UNKNOWN_TREND value. For final results, both values must be converted
 * to signed short (sign extension).
 */


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
                          "separator",                // string   ___a_______________________
                          periods,                    // int      ZigZag.Periods
                          0,                          // int      ZigZag.Periods.Step
                          "Line",                     // string   ZigZag.Type
                          "dot",                      // string   ZigZag.Semaphores.Symbol
                          1,                          // int      ZigZag.Width
                          CLR_NONE,                   // color    ZigZag.Color

                          "separator",                // string   ___b_______________________
                          false,                      // bool     Donchian.ShowChannel
                          CLR_NONE,                   // color    Donchian.Channel.UpperColor
                          CLR_NONE,                   // color    Donchian.Channel.LowerColor
                          "all",                      // string   Donchian.ShowCrossings
                          "ring",                     // string   Donchian.Crossing.Symbol
                          1,                          // int      Donchian.Crossing.Width
                          CLR_NONE,                   // color    Donchian.Crossing.Color

                          "separator",                // string   ___c_______________________
                          false,                      // bool     ShowChartLegend
                          -1,                         // int      MaxBarsBack

                          "separator",                // string   ___d_______________________
                          false,                      // bool     Signal.onReversal
                          "",                         // string   Signal.onReversal.Types

                          false,                      // bool     Signal.onBreakout
                          "",                         // string   Signal.onBreakout.Types

                          "",                         // string   Signal.Sound.Up
                          "",                         // string   Signal.Sound.Down

                          false,                      // bool     Sound.onChannelWidening
                          "",                         // string   Sound.onNewChannelHigh
                          "",                         // string   Sound.onNewChannelLow

                          "separator",                // string   ___e_______________________
                          false,                      // bool     TrackVirtualProfit
                          0,                          // datetime TrackVirtualProfit.Since
                          "",                         // string   TrackVirtualProfit.Symbol

                          "separator",                // string   ___f_______________________
                           false,                     // bool     TrendBufferAsDecimal

                          "separator",                // string   ___________________________
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
