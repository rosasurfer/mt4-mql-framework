/**
 * Return the number of changed bars since the last tick for the specified timeseries. Equivalent to resolving the number of
 * changed bars in indicators for the current chart by computing:
 *
 *   UnchangedBars = IndicatorCounted()
 *   ChangedBars   = Bars - UnchangedBars
 *
 * This function can be used when IndicatorCounted() is not available, i.e. in experts or in indicators with a timeseries
 * different from the current one.
 *
 * @param  string symbol    [optional] - symbol of the timeseries (default: the current chart symbol)
 * @param  int    timeframe [optional] - timeframe of the timeseries (default: the current chart timeframe)
 *
 * @return int - number of changed bars or -1 (EMPTY) in case of errors
 */
int iChangedBars(string symbol="0", int timeframe=NULL) {
   if (__ExecutionContext[EC.programCoreFunction] != CF_START) return(_EMPTY(catch("iChangedBars(1)  invalid calling context: "+ ProgramTypeDescription(__ExecutionContext[EC.programType]) +"::"+ CoreFunctionDescription(__ExecutionContext[EC.programCoreFunction]), ERR_FUNC_NOT_ALLOWED)));

   if (symbol == "0") symbol = Symbol();                       // (string) NULL
   if (!timeframe) timeframe = Period();

   // maintain a map "symbol,timeframe" => data[] to enable parallel usage with multiple timeseries
   #define CB.Tick            0                                // last value of global var Tick for detecting multiple calls during the same price tick
   #define CB.Bars            1                                // last number of bars of the timeseries
   #define CB.ChangedBars     2                                // last returned value of ChangedBars
   #define CB.FirstBarTime    3                                // opentime of the first bar of the timeseries (newest bar)
   #define CB.LastBarTime     4                                // opentime of the last bar of the timeseries (oldest bar)

   string keys[];                                              // TODO: store all data elsewhere to survive indicator init cycles
   int    data[][5];                                           // TODO: reset data on account change
   int    size = ArraySize(keys);
   string key = StringConcatenate(symbol, ",", timeframe);     // mapping key

   for (int i=0; i < size; i++) {
      if (keys[i] == key)
         break;
   }
   if (i == size) {                                            // add the key if not found
      ArrayResize(keys, size+1); keys[i] = key;
      ArrayResize(data, size+1);
   }

   // always return the same result for the same tick
   if (Tick == data[i][CB.Tick])
      return(data[i][CB.ChangedBars]);

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

   if (bars < 0) {                                                               // never encountered
      return(_EMPTY(catch("iChangedBars(2)->iBars("+ symbol +","+ PeriodDescription(timeframe) +") => "+ bars, ifInt(error, error, ERR_RUNTIME_ERROR))));
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

      if (!data[i][CB.Tick]) {                                                   // first call for the timeseries
         changedBars = bars;
      }
      else if (bars==data[i][CB.Bars] && lastBarTime==data[i][CB.LastBarTime]) { // number of bars is unchanged and last bar is still the same
         changedBars = 1;                                                        // a regular tick
      }
      else if (bars==data[i][CB.Bars]) {                                         // number of bars is unchanged but last bar changed: the timeseries hit MAX_CHART_BARS and bars have been shifted off the end
         // find the bar stored in data[i][CB.FirstBarTime]
         int offset = iBarShift(symbol, timeframe, data[i][CB.FirstBarTime], true);
         if (offset == -1) changedBars = bars;                                   // CB.FirstBarTime not found: mark all bars as changed
         else              changedBars = offset + 1;                             // +1 to cover a simultaneous BarOpen event
      }
      else {                                                                     // the number of bars changed
         if (bars < data[i][CB.Bars]) {
            changedBars = bars;                                                  // the account changed: mark all bars as changed
         }
         else if (firstBarTime == data[i][CB.FirstBarTime]) {
            changedBars = bars;                                                  // a data gap was filled: ambiguous => mark all bars as changed
         }
         else {
            changedBars = bars - data[i][CB.Bars] + 1;                           // new bars at the beginning: +1 to cover BarOpen events
         }
      }
   }

   // store all data
   data[i][CB.Tick        ] = Tick;
   data[i][CB.Bars        ] = bars;
   data[i][CB.ChangedBars ] = changedBars;
   data[i][CB.FirstBarTime] = firstBarTime;
   data[i][CB.LastBarTime ] = lastBarTime;

   return(changedBars);
}
