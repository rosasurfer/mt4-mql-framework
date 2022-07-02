/**
 * Return the number of changed bars of the specified timeseries since the last tick. Equivalent to resolving the number of
 * changed bars in indicators for the current chart timeframe by computing:
 *
 *   ValidBars   = IndicatorCounted()
 *   ChangedBars = Bars - ValidBars
 *   Bars = ValidBars + ChangedBars
 *
 * This function can be used if IndicatorCounted() is not available, i.e. in experts or in indicators with the requested
 * timeframe different from the current chart timeframe.
 *
 * @param  string symbol    [optional] - symbol of the timeseries (default: the current chart symbol)
 * @param  int    timeframe [optional] - timeframe of the timeseries (default: the current chart timeframe)
 *
 * @return int - number of changed bars or EMPTY (-1) in case of errors
 */
int iChangedBars(string symbol="0", int timeframe=NULL) {
   if (__ExecutionContext[EC.programCoreFunction] != CF_START) return(_EMPTY(catch("iChangedBars(1)  invalid calling context: "+ ProgramTypeDescription(__ExecutionContext[EC.programType]) +"::"+ CoreFunctionDescription(__ExecutionContext[EC.programCoreFunction]), ERR_ILLEGAL_STATE)));

   if (symbol == "0") symbol = Symbol();                          // (string) NULL
   if (!timeframe) timeframe = Period();

   // maintain a map "symbol,timeframe" => data[] to enable parallel usage with multiple timeseries
   #define ICB_Tick            0                                  // last value of global var Tick for detecting multiple calls during the same price tick
   #define ICB_Bars            1                                  // last number of bars of the timeseries
   #define ICB_ChangedBars     2                                  // last returned value of ChangedBars
   #define ICB_FirstBarTime    3                                  // opentime of the first bar of the timeseries (newest bar)
   #define ICB_LastBarTime     4                                  // opentime of the last bar of the timeseries (oldest bar)

   string keys[], key=StringConcatenate(symbol, ",", timeframe);  // mapping key
   int data[][5], size=ArraySize(keys);                           // TODO: reset data on account change and store it elsewhere to survive indicator init cycles

   for (int i=0; i < size; i++) {
      if (keys[i] == key) break;
   }
   if (i == size) {                                               // add the key if not found
      ArrayResize(keys, size+1); keys[i] = key;
      ArrayResize(data, size+1);
   }

   // return the same result for the same tick
   if (Ticks == data[i][ICB_Tick])
      return(data[i][ICB_ChangedBars]);

   /*
   - When a timeseries is accessed the first time iBars() typically sets the status ERS_HISTORY_UPDATE and new data may
     arrive later.
   - If an empty timeseries is re-accessed before new data has arrived iBars() sets the error ERR_SERIES_NOT_AVAILABLE.
     Here the error is suppressed and 0 is returned.
   - If an empty timeseries is accessed after recompilation or without a server connection no error may be set.
   - iBars() doesn't set an error if the timeseries is unknown (symbol or timeframe).
   */

   // get current number of bars
   int bars  = iBars(symbol, timeframe);
   int error = GetLastError();

   if (bars < 0) {                                                // never encountered
      return(_EMPTY(catch("iChangedBars(2)->iBars("+ symbol +","+ PeriodDescription(timeframe) +") => "+ bars, intOr(error, ERR_RUNTIME_ERROR))));
   }
   if (error && error!=ERS_HISTORY_UPDATE && error!=ERR_SERIES_NOT_AVAILABLE) {
      return(_EMPTY(catch("iChangedBars(3)->iBars("+ symbol +","+ PeriodDescription(timeframe) +") => "+ bars, error)));
   }

   datetime firstBarTime=0, lastBarTime=0;
   int changedBars = 0;

   // resolve the number of changed bars
   if (bars > 0) {
      firstBarTime = iTime(symbol, timeframe, 0);
      lastBarTime  = iTime(symbol, timeframe, bars-1);

      // first call for the timeseries
      if (!data[i][ICB_Tick]) {
         changedBars = bars;
      }

      // the number of bars is unchanged and the oldest bar is still the same
      else if (bars==data[i][ICB_Bars] && lastBarTime==data[i][ICB_LastBarTime]) {
         changedBars = 1;                                                                                // a regular tick
      }

      // the number of bars is unchanged but the oldest bar changed: the timeseries hit MAX_CHART_BARS and bars have been shifted off the end (e.g. in self-updating offline
      else if (bars==data[i][ICB_Bars]) {                                                                // charts when MAX_CHART_BARS is hit on each new bar)
         // find the bar stored in data[i][ICB_FirstBarTime]
         int offset = iBarShift(symbol, timeframe, data[i][ICB_FirstBarTime], true);
         if (offset == -1) changedBars = bars;                                                           // ICB_FirstBarTime not found: mark all bars as changed
         else              changedBars = offset + 1;                                                     // +1 to cover a simultaneous BarOpen event
      }

      // the number of bars changed
      else {
         if      (bars < data[i][ICB_Bars])                  changedBars = bars;                         // the account changed: mark all bars as changed
         else if (firstBarTime == data[i][ICB_FirstBarTime]) changedBars = bars;                         // a data gap was filled: ambiguous => mark all bars as changed
         else                                                changedBars = bars - data[i][ICB_Bars] + 1; // new bars at the beginning: +1 to cover BarOpen events
      }
   }

   // store all data
   data[i][ICB_Tick        ] = Ticks;
   data[i][ICB_Bars        ] = bars;
   data[i][ICB_ChangedBars ] = changedBars;
   data[i][ICB_FirstBarTime] = firstBarTime;
   data[i][ICB_LastBarTime ] = lastBarTime;

   return(changedBars);
}
