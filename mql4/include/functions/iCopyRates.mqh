/**
 * Assign the specified timeseries to the target array and return the number of bars changed since the last tick. Supports
 * loading of custom or non-standard timeseries.
 *
 * Extended version of the built-in function ArrayCopyRates() with a different return value and better error handling.
 * This function should be used when a timeseries is requested and IndicatorCounted() is not available, i.e. in experts or in
 * indicators with the requested timeseries different from the current chart timeseries.
 *
 * The first dimension of the target array holds the bar offset, the second dimension holds the elements:
 *   0 - open time
 *   1 - open price
 *   2 - low price
 *   3 - high price
 *   4 - close price
 *   5 - volume (tick count)
 *
 * @param  _Out_ double target[][6]          - array to assign rates to (read-only)
 * @param  _In_  string symbol    [optional] - symbol of the timeseries (default: the current chart symbol)
 * @param  _In_  int    timeframe [optional] - timeframe of the timeseries (default: the current chart timeframe)
 *
 * @return int - number of bars changed since the last tick or EMPTY (-1) in case of errors
 *
 * Notes: (1) No real copying is performed and no additional memory is allocated. Instead a delegating instance to the
 *            internal rates array is assigned and access is redirected.
 *        (2) When assigning to a local variable the target array doesn't act like a regular array. Static behavior needs to
 *            be explicitely declared if needed.
 *        (3) When a timeseries is accessed the first time typically the status ERS_HISTORY_UPDATE is set and new data may
 *            arrive later.
 *        (4) If the timeseries is empty 0 is returned and no error is set. This is different to the implementation of the
 *            built-in function ArrayCopyRates().
 *        (5) If the array is passed to a DLL the DLL receives a pointer to the internal data array of type HISTORY_BAR_400[]
 *            (MetaQuotes alias: RateInfo). This array is reverse-indexed (index 0 holds the oldest bar). As more rates
 *            arrive the array is dynamically extended.
 */
int iCopyRates(double &target[][], string symbol="0", int timeframe=NULL) {
   if (ArrayDimension(target) != 2)                            return(_EMPTY(catch("iCopyRates(1)  invalid parameter target[] (illegal number of dimensions: "+ ArrayDimension(target) +")", ERR_INCOMPATIBLE_ARRAY)));
   if (ArrayRange(target, 1) != 6)                             return(_EMPTY(catch("iCopyRates(2)  invalid size of parameter target: array["+ ArrayRange(target, 0) +"]["+ ArrayRange(target, 1) +"]", ERR_INCOMPATIBLE_ARRAY)));
   if (__ExecutionContext[EC.programCoreFunction] != CF_START) return(_EMPTY(catch("iCopyRates(3)  invalid calling context: "+ ProgramTypeDescription(__ExecutionContext[EC.programType]) +"::"+ CoreFunctionDescription(__ExecutionContext[EC.programCoreFunction]), ERR_ILLEGAL_STATE)));

   if (symbol == "0") symbol = Symbol();                       // (string) NULL
   if (!timeframe) timeframe = Period();

   #define TIME               0                                // rates array indexes
   #define OPEN               1
   #define LOW                2
   #define HIGH               3
   #define CLOSE              4
   #define VOLUME             5

   // maintain a map "symbol,timeframe" => data[] to enable parallel usage with multiple timeseries
   #define CR.Tick            0                                // last value of global var Tick for detecting multiple calls during the same price tick
   #define CR.Bars            1                                // last number of bars of the timeseries
   #define CR.ChangedBars     2                                // last returned value of ChangedBars
   #define CR.FirstBarTime    3                                // opentime of the first bar of the timeseries (newest bar)
   #define CR.LastBarTime     4                                // opentime of the last bar of the timeseries (oldest bar)

   string keys[];                                              // TODO: store all data elsewhere to survive indicator init cycles
   int    data[][5];                                           // TODO: reset data on account change
   int    size = ArraySize(keys);
   string key = StringConcatenate(symbol, ",", timeframe);     // mapping key

   for (int i=0; i < size; i++) {
      if (keys[i] == key) break;
   }
   if (i == size) {                                            // add the key if not found
      ArrayResize(keys, size+1); keys[i] = key;
      ArrayResize(data, size+1);
   }

   /*
   - When a timeseries is accessed the first time ArrayCopyRates() typically sets the status ERS_HISTORY_UPDATE and new data
     may arrive later.
   - If an empty timeseries is re-requested before new data has arrived ArrayCopyRates() returns -1 and sets the error
     ERR_ARRAY_ERROR (also in tester). Here the error is interpreted as ERR_SERIES_NOT_AVAILABLE, suppressed and 0 is returned.
   - If an empty timeseries is requested after recompilation or without a server connection no error may be set.
   - ArrayCopyRates() doesn't set an error if the timeseries is unknown (symbol or timeframe).
   */

   int bars = ArrayCopyRates(target, symbol, timeframe);
   int error = GetLastError();

   if (bars < 0) {
      if (error!=ERR_ARRAY_ERROR && error!=ERR_SERIES_NOT_AVAILABLE)
         return(_EMPTY(catch("iCopyRates(4)->ArrayCopyRates("+ symbol +", "+ PeriodDescription(timeframe) +") => "+ bars, intOr(error, ERR_RUNTIME_ERROR))));
      error = NO_ERROR;
      bars = 0;
   }
   if (error && error!=ERS_HISTORY_UPDATE)
      return(_EMPTY(catch("iCopyRates(5)->ArrayCopyRates("+ symbol +", "+ PeriodDescription(timeframe) +") => "+ bars, error)));
   error = NO_ERROR;

   // always return the same result for the same tick
   if (Ticks == data[i][CR.Tick])
      return(data[i][CR.ChangedBars]);

   datetime firstBarTime=0, lastBarTime=0;
   int changedBars = 0;

   // resolve the number of changed bars; uses the same logic as iChangedBars()
   if (bars > 0) {
      firstBarTime = target[     0][TIME];
      lastBarTime  = target[bars-1][TIME];

      if (!data[i][CR.Tick]) {                                                   // first call for the timeseries
         changedBars = bars;
      }
      else if (bars==data[i][CR.Bars] && lastBarTime==data[i][CR.LastBarTime]) { // number of bars is unchanged and last bar is still the same
         changedBars = 1;                                                        // a regular tick
      }
      else if (bars==data[i][CR.Bars]) {                                         // number of bars is unchanged but last bar changed: the timeseries hit MAX_CHART_BARS and bars have been shifted off the end
         if (IsLogInfo()) logInfo("iCopyRates(6)  number of bars unchanged but oldest bar differs, hit the timeseries MAX_CHART_BARS? (bars="+ bars +", lastBar="+ TimeToStr(lastBarTime, TIME_FULL) +", prevLastBar="+ TimeToStr(data[i][CR.LastBarTime], TIME_FULL) +")");
         // find the bar stored in data[i][CR.FirstBarTime]
         int offset = iBarShift(symbol, timeframe, data[i][CR.FirstBarTime], true);
         if (offset == -1) changedBars = bars;                                   // CR.FirstBarTime not found: mark all bars as changed
         else              changedBars = offset + 1;                             // +1 to cover a simultaneous BarOpen event
      }
      else {                                                                     // the number of bars changed
         if (bars < data[i][CR.Bars]) {
            changedBars = bars;                                                  // the account changed: mark all bars as changed
         }
         else if (firstBarTime == data[i][CR.FirstBarTime]) {
            changedBars = bars;                                                  // a data gap was filled: ambiguous => mark all bars as changed
         }
         else {
            changedBars = bars - data[i][CR.Bars] + 1;                           // new bars at the beginning: +1 to cover BarOpen events
         }
      }
   }

   // store all data
   data[i][CR.Tick        ] = Ticks;
   data[i][CR.Bars        ] = bars;
   data[i][CR.ChangedBars ] = changedBars;
   data[i][CR.FirstBarTime] = firstBarTime;
   data[i][CR.LastBarTime ] = lastBarTime;

   return(changedBars);
}
