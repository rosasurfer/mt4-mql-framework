/**
 * Assigns the specified timeseries to the target array and returns the number of changed bars since the last tick.
 *
 * This function is a wrapper around the built-in function ArrayCopyRates() with a different return value and better error
 * handling. It can be used to get timeseries and number of changed bars since last tick of any symbol or period, not only
 * from the current chart. It can also be used in contexts where IndicatorCounted() is not available (e.g. in experts).
 *
 * The function supports custom symbols and custom timeframes, as long as the history file exists.
 *
 * The first dimension of the target array (rows) holds the bar offset, the second dimension (columns) holds the elements:
 *  #define BAR400_TIME   (0) - bar open time
 *  #define BAR400_OPEN   (1) - bar open price
 *  #define BAR400_LOW    (2) - bar low price
 *  #define BAR400_HIGH   (3) - bar high price
 *  #define BAR400_CLOSE  (4) - bar close price
 *  #define BAR400_VOLUME (5) - bar volume (tick count)
 *
 * @param  _Out_ double target[][6]          - array to assign rates to (read-only, reverse-indexed)
 * @param  _In_  string symbol    [optional] - symbol of the timeseries (default: the current chart symbol)
 * @param  _In_  int    timeframe [optional] - timeframe of the timeseries (default: the current chart timeframe)
 *
 * @return int - number of bars changed since the last tick or EMPTY (-1) in case of errors
 *
 *
 * Notes: (1) No real copying is performed and no additional memory is allocated. Instead a delegate to the terminal's
 *            internal rates array is assigned and access is redirected.
 *        (2) The assigned array is reverse-indexed and read-only.
 *        (3) If assigning to a local array variable, the array stops behaving like a regular array and starts behaving like
 *            an integer (it's a pointer now). Thus static behavior needs to be explicitely declared if needed.
 *        (4) If a timeseries is accessed the first time, typically status ERS_HISTORY_UPDATE is set and new data may arrive
 *            later.
 *        (5) If the timeseries is empty, 0 (zero) is returned and no error is set. This differs from the implementation of
 *            the built-in function ArrayCopyRates().
 *        (6) If the array is passed to a DLL, the DLL receives a pointer to the terminal's internal rates array of type
 *            HISTORY_BAR_400[]. This array is reverse-indexed (index 0 holds the oldest bar). As more rates arrive the array
 *            dynamically grows.
 */
int iCopyRates(double &target[][], string symbol = "0", int timeframe = NULL) {
   if (ArrayDimension(target) != 2) return(_EMPTY(catch("iCopyRates(1)  invalid parameter target[] (illegal number of dimensions: "+ ArrayDimension(target) +")", ERR_INCOMPATIBLE_ARRAY)));
   if (ArrayRange(target, 1) != 6)  return(_EMPTY(catch("iCopyRates(2)  invalid size of parameter target: array["+ ArrayRange(target, 0) +"]["+ ArrayRange(target, 1) +"]", ERR_INCOMPATIBLE_ARRAY)));
   if (__CoreFunction != CF_START)  return(_EMPTY(catch("iCopyRates(3)  invalid calling context: "+ ProgramTypeDescription(__ExecutionContext[EC.programType]) +"::"+ CoreFunctionDescription(__CoreFunction), ERR_ILLEGAL_STATE)));

   if (symbol == "0") symbol = Symbol();                       // (string) NULL
   if (!timeframe) timeframe = Period();

   // maintain a map "symbol,timeframe" => data[] to enable parallel usage with multiple timeseries
   #define CR_Ticks           0                                // last value of global var Ticks for detecting multiple calls during the same price tick
   #define CR_Bars            1                                // last number of bars of the timeseries
   #define CR_ChangedBars     2                                // last returned value of ChangedBars
   #define CR_YoungestBarTime 3                                // opentime of the youngest bar of the timeseries
   #define CR_OldestBarTime   4                                // opentime of the oldest bar of the timeseries

   string keys[];                                              // TODO: store all data elsewhere to survive indicator init cycles
   int    data[][5];                                           // TODO: reset data on account change
   int    size = ArraySize(keys);
   string key = StringConcatenate(symbol, ",", timeframe);     // mapping key

   for (int i=0; i < size; i++) {
      if (keys[i] == key) break;
   }
   if (i == size) {                                            // add the key if not found
      ArrayResize(keys, size+1);
      ArrayResize(data, size+1);
      keys[i] = key;
   }

   /*
   - If a timeseries is accessed the first time, ArrayCopyRates() typically sets status ERS_HISTORY_UPDATE and new data may
     arrive later.
   - If an empty timeseries is re-requested and before new data has arrived, ArrayCopyRates() returns -1 and sets error
     ERR_ARRAY_ERROR (also in tester). Here the error is interpreted as ERR_SERIES_NOT_AVAILABLE, suppressed and 0 is returned.
   - If an empty timeseries is requested after recompilation or without a server connection no error may be set.
   - WARN: ArrayCopyRates() doesn't set an error if the timeseries is unknown (symbol or timeframe).
   */

   int bars = ArrayCopyRates(target, symbol, timeframe);
   int error = GetLastError();

   if (bars < 0) {
      if (error!=ERR_ARRAY_ERROR && error!=ERR_SERIES_NOT_AVAILABLE) {
         return(_EMPTY(catch("iCopyRates(4)->ArrayCopyRates("+ symbol +", "+ PeriodDescription(timeframe) +") => "+ bars, intOr(error, ERR_RUNTIME_ERROR))));
      }
      error = NO_ERROR;
      bars = 0;
   }
   if (error && error!=ERS_HISTORY_UPDATE) {
      return(_EMPTY(catch("iCopyRates(5)->ArrayCopyRates("+ symbol +", "+ PeriodDescription(timeframe) +") => "+ bars, error)));
   }
   error = NO_ERROR;

   // always return the same result for the same tick
   if (Ticks == data[i][CR_Ticks]) {
      return(data[i][CR_ChangedBars]);
   }

   datetime firstBarTime = 0, lastBarTime = 0;
   int changedBars = 0;

   // resolve the number of changed bars; uses the same logic as iChangedBars()
   if (bars > 0) {
      firstBarTime = target[     0][BAR400_TIME];
      lastBarTime  = target[bars-1][BAR400_TIME];

      if (!data[i][CR_Ticks]) {                                                     // first call for the timeseries
         changedBars = bars;
      }
      else if (bars==data[i][CR_Bars] && lastBarTime==data[i][CR_OldestBarTime]) {  // number of bars is unchanged and last bar is still the same
         changedBars = 1;                                                           // a regular tick
      }
      else if (bars==data[i][CR_Bars]) {                                            // number of bars is unchanged but last bar changed:
         // find the bar stored in data[i][CR_YoungestBarTime]                      // the timeseries hit MAX_CHART_BARS and bars have been shifted off the end
         int offset = iBarShift(symbol, timeframe, data[i][CR_YoungestBarTime], true);
         if (offset == -1) changedBars = bars;                                      // youngest bar not found: mark all bars as changed
         else              changedBars = offset + 1;                                // +1 to cover a simultaneous BarOpen event
      }
      else {                                                                        // the number of bars changed
         if (bars < data[i][CR_Bars]) {
            changedBars = bars;                                                     // the timeseries changed completely: mark all bars as changed
         }
         else if (firstBarTime == data[i][CR_YoungestBarTime]) {
            changedBars = bars;                                                     // a data gap was filled: ambiguous => mark all bars as changed
         }
         else {
            changedBars = bars - data[i][CR_Bars] + 1;                              // new bars at the beginning: +1 to cover BarOpen events
         }
      }
   }

   // store all data
   data[i][CR_Ticks          ] = Ticks;
   data[i][CR_Bars           ] = bars;
   data[i][CR_ChangedBars    ] = changedBars;
   data[i][CR_YoungestBarTime] = firstBarTime;
   data[i][CR_OldestBarTime  ] = lastBarTime;

   return(changedBars);
}
