#define MaChannel.MODE_MA1_UPPER_BAND  0              // indicator buffer ids
#define MaChannel.MODE_MA1_LOWER_BAND  1              //
#define MaChannel.MODE_MA2_UPPER_BAND  2              //
#define MaChannel.MODE_MA2_LOWER_BAND  3              //
#define MaChannel.MODE_MA3_UPPER_BAND  4              //
#define MaChannel.MODE_MA3_LOWER_BAND  5              //
#define MaChannel.MODE_POSITION        6              // overall price position (all MA channels): -1..0..+1
#define MaChannel.MODE_TREND           7              // overall channel trend (all MA channels):  -n..0..+n


/**
 * Load the "MA Channel" indicator and return a value.
 *
 * @param  int timeframe       - timeframe to load the indicator (NULL: the current timeframe)
 *
 * @param  int ma1Method       - indicator parameter
 * @param  int ma1Periods      - indicator parameter
 * @param  int ma1ChannelWidth - indicator parameter
 * @param  int ma2Method       - indicator parameter
 * @param  int ma2Periods      - indicator parameter
 * @param  int ma2ChannelWidth - indicator parameter
 * @param  int ma3Method       - indicator parameter
 * @param  int ma3Periods      - indicator parameter
 * @param  int ma3ChannelWidth - indicator parameter
 *
 * @param  int iBuffer         - indicator buffer index of the value to return
 * @param  int iBar            - bar index of the value to return
 *
 * @return double - indicator value or NULL in case of errors
 */
double icMaChannel(int timeframe, int ma1Method, int ma1Periods, int ma1ChannelWidth, int ma2Method, int ma2Periods, int ma2ChannelWidth, int ma3Method, int ma3Periods, int ma3ChannelWidth, int iBuffer, int iBar) {
   static int lpSuperContext = 0; if (!lpSuperContext) {
      lpSuperContext = GetIntsAddress(__ExecutionContext);
   }
   string sMa1Method = ma1Method;                     // we can't implicitly cast iCustom() arguments
   string sMa2Method = ma2Method;
   string sMa3Method = ma3Method;

   double value = iCustom(NULL, timeframe, "MA Channel",
                          "",                         // string _______________________
                          sMa1Method,                 // string MA1.Method
                          ma1Periods,                 // int    MA1.Periods
                          ma1ChannelWidth,            // int    MA1.ChannelWidth.Pct
                          CLR_NONE,                   // color  MA1.Color

                          sMa2Method,                 // string MA2.Method
                          ma2Periods,                 // int    MA2.Periods
                          ma2ChannelWidth,            // int    MA2.ChannelWidth.Pct
                          CLR_NONE,                   // color  MA2.Color

                          sMa3Method,                 // string MA3.Method
                          ma3Periods,                 // int    MA3.Periods
                          ma3ChannelWidth,            // int    MA3.ChannelWidth.Pct
                          CLR_NONE,                   // color  MA3.Color

                          "",                         // string _______________________
                          false,                      // bool   ShowChartLegend
                          -1,                         // int    MaxBarsBack

                          "",                         // string _______________________
                          false,                      // bool   Signal.onPositionChange
                          "",                         // string Signal.onPosition.Types
                          "",                         // string Signal.onPosition.Sound.Above
                          "",                         // string Signal.onPosition.Sound.Below
                          "",                         // string Signal.onPosition.Sound.Between

                          false,                      // bool   Signal.onTrendChange
                          "",                         // string Signal.onTrend.Types
                          "",                         // string Signal.onTrend.Sound.Up
                          "",                         // string Signal.onTrend.Sound.Down

                          "",                         // string _______________________
                          false,                      // bool   AutoConfiguration
                          lpSuperContext,             // int    __lpSuperContext

                          iBuffer, iBar);

   int error = GetLastError();
   if (error != NO_ERROR) {
      if (error != ERS_HISTORY_UPDATE) return(!catch("icMaChannel(1)", error));
      logWarn("icMaChannel(2)  "+ PeriodDescription(timeframe) +" (tick="+ Ticks +")", ERS_HISTORY_UPDATE);
   }

   error = __ExecutionContext[EC.mqlError];           // TODO: synchronize execution contexts
   if (!error) return(value);
   return(!SetLastError(error));
}
