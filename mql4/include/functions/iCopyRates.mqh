/**
 * Assign the specified timeseries to the target array and return the number of bars changed since the last tick. Supports
 * loading of custom and non-standard timeseries.
 *
 * Extended version of the built-in function ArrayCopyRates() with a different return value and better error handling.
 * This function should be used when a timeseries is requested and IndicatorCounted() is not available, i.e. in experts or in
 * indicators with the requested timeseries different then the current one.
 *
 * The first dimension of the target array holds the bar offset, the second dimension holds the elements:
 *   0 - open time
 *   1 - open price
 *   2 - low price
 *   3 - high price
 *   4 - close price
 *   5 - volume (tick count)
 *
 * @param  double target[][6]          - array to assign rates to (read-only)
 * @param  string symbol    [optional] - symbol of the timeseries (default: the current chart symbol)
 * @param  int    timeframe [optional] - timeframe of the timeseries (default: the current chart timeframe)
 *
 * @return int - number of bars changed since the last tick or -1 (EMPTY) in case of errors
 *
 * Notes: (1) No real copying is performed and no additional memory is allocated. Instead a delegating instance to the
 *            internal rates array is assigned and access is redirected.
 *        (2) When assigning to a local variable the target array doesn't act like a regular array. Static behavior needs to
 *            be explicitely declared if needed.
 *        (3) When a timeseries is accessed the first time typically the status ERS_HISTORY_UPDATE is set and new data may
 *            arrive later.
 *        (4) If the timeseries is empty the error ERR_SERIES_NOT_AVAILABLE is never set, instead 0 is returned. This is
 *            different to the implementation of the built-in function ArrayCopyRates().
 *        (5) If the array is passed to a DLL the DLL receives a pointer to the internal data array of type HISTORY_BAR_400[]
 *            (MetaQuotes alias: RateInfo). This array is reverse-indexed (index 0 points to the oldest bar). As more rates
 *            arrive it is dynamically extended up to a size of MAX_CHART_BARS.
 */
int iCopyRates(double target[][], string symbol="0", int timeframe=NULL) {
   if (ArrayDimension(target) != 2)                            return(_EMPTY(catch("iCopyRates(1)  invalid parameter target[] (illegal number of dimensions: "+ ArrayDimension(target) +")", ERR_INCOMPATIBLE_ARRAYS)));
   if (ArrayRange(target, 1) != 6)                             return(_EMPTY(catch("iCopyRates(2)  invalid size of parameter target: array["+ ArrayRange(target, 0) +"]["+ ArrayRange(target, 1) +"]", ERR_INCOMPATIBLE_ARRAYS)));
   if (__ExecutionContext[EC.programCoreFunction] != CF_START) return(_EMPTY(catch("iCopyRates(3)  invalid calling context: "+ ProgramTypeDescription(__ExecutionContext[EC.programType]) +"::"+ CoreFunctionDescription(__ExecutionContext[EC.programCoreFunction]), ERR_FUNC_NOT_ALLOWED)));

   if (symbol == "0") symbol = Symbol();                             // (string) NULL
   if (!timeframe) timeframe = Period();

   // maintain a map "symbol,timeframe" => data[] to enable parallel usage with multiple timeseries
   #define CR.Tick            0                                      // last value of global var Tick for detecting multiple calls during the same price tick
   #define CR.Bars            1                                      // last number of bars of the timeseries
   #define CR.ChangedBars     2                                      // last returned value of ChangedBars
   #define CR.FirstBarTime    3                                      // opentime of the first bar of the timeseries (newest bar)
   #define CR.LastBarTime     4                                      // opentime of the last bar of the timeseries (oldest bar)

   string keys[];                                                    // TODO: store all data elsewhere to survive indicator init cycles
   int    data[][5];                                                 // TODO: reset data on account change
   int    size = ArraySize(keys);
   string key = StringConcatenate(symbol, ",", timeframe);           // mapping key

   for (int i=0; i < size; i++) {
      if (keys[i] == key)
         break;
   }
   if (i == size) {                                                  // add the key if not found
      ArrayResize(keys, size+1); keys[i] = key;
      ArrayResize(data, size+1);
   }

   // return the same result for the same tick
   if (Tick == data[i][CR.Tick])
      return(data[i][CR.ChangedBars]);

   /*
   - When a timeseries is accessed the first time ArrayCopyRates() typically sets the status ERS_HISTORY_UPDATE and new data
     may arrive later.
   - If an empty timeseries is re-requested before new data has arrived ArrayCopyRates() returns -1 and sets the error
     ERR_ARRAY_ERROR (also in tester). Here the error is interpreted as ERR_SERIES_NOT_AVAILABLE, suppressed and 0 is returned.
   - If an empty timeseries is requested after recompilation or without a server connection no error may be set.
   - ArrayCopyRates() doesn't set an error if the timeseries (i.e. symbol or timeframe) is unknown.
   */



   return(-1);
}
