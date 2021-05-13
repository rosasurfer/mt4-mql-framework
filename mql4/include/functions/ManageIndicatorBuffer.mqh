/**
 * Manage an additional indicator buffer. In MQL4 the terminal manages a maximum of 8 indicator buffers. Additional buffers
 * can be used but must be managed by the framework. Such additional buffers are for internal calculations only, they can't
 * be drawn on the chart or accessed via iCustom().
 *
 * @param  int    id                    - buffer id
 * @param  double buffer[]              - buffer
 * @param  double emptyValue [optional] - buffer value interpreted as "no value" (default: 0)
 *
 * @return bool - success status
 */
bool ManageIndicatorBuffer(int id, double buffer[], double emptyValue = 0) {
   // TODO: At the moment the function reallocates memory each time the number of bars changes.
   //       Pre-allocate excess memory and use a dynamic offset to improve the performance of additional buffers.

   if (id < 0)                                                 return(!catch("ManageIndicatorBuffer(1)  invalid parameter id: "+ id, ERR_INVALID_PARAMETER));
   if (__ExecutionContext[EC.programCoreFunction] != CF_START) return(!catch("ManageIndicatorBuffer(2)  id="+ id +", invalid calling context: "+ ProgramTypeDescription(__ExecutionContext[EC.programType]) +"::"+ CoreFunctionDescription(__ExecutionContext[EC.programCoreFunction]), ERR_ILLEGAL_STATE));
   if (!Bars)                                                  return(!catch("ManageIndicatorBuffer(3)  id="+ id +", Tick="+ Tick +"  Bars=0", ERR_ILLEGAL_STATE));

   // maintain a metadata array {id => data[]} to support multiple buffers
   #define IB.Tick            0                                      // last Tick value for detecting multiple calls during the same tick
   #define IB.Bars            1                                      // last number of bars
   #define IB.NewestBarTime   2                                      // last opentime of the newest bar
   #define IB.OldestBarTime   3                                      // last opentime of the oldest bar

   int data[][4];                                                    // TODO: reset on account change
   if (ArrayRange(data, 0) <= id) ArrayResize(data, id+1);           // {id} is used as array key

   int      prevTick          = data[id][IB.Tick         ];
   int      prevBars          = data[id][IB.Bars         ];
   datetime prevNewestBarTime = data[id][IB.NewestBarTime];
   datetime prevOldestBarTime = data[id][IB.OldestBarTime];

   if (Tick == prevTick) return(true);                               // execute only once per tick

   if (Bars == prevBars) {
      // the number of Bars is unchanged
      if (Time[Bars-1] != prevOldestBarTime) {                       // the oldest bar changed and bars have been shifted off the end (e.g. in self-updating offline charts when MAX_CHART_BARS is hit on each new bar)
         if (!ShiftedBars || Time[ShiftedBars]!=prevNewestBarTime) {
            return(!catch("ManageIndicatorBuffer(4)  id="+ id +", Tick="+ Tick +", Bars unchanged but oldest bar changed, hit the timeseries MAX_CHART_BARS? (Bars="+ Bars +", ShiftedBars="+ ShiftedBars +", oldestBarTime="+ TimeToStr(Time[Bars-1], TIME_FULL) +", prevOldestBarTime="+ TimeToStr(prevOldestBarTime, TIME_FULL) +")", ERR_ILLEGAL_STATE));
         }
      }
   }
   else if (Bars > prevBars) {
      // the number of Bars increased                                // new bars have been inserted or appended (anywhere, all cases are covered by ChangedBars)
      if (prevBars && Time[Bars-1]!=prevOldestBarTime) {             // the oldest bar changed: bars have been added at the end (data pumping)
         if (UnchangedBars != 0) return(!catch("ManageIndicatorBuffer(5)  id="+ id +", Tick="+ Tick +", Bars increased and oldest bar changed but UnchangedBars != 0 (Bars="+ Bars +", prevBars="+ prevBars +", oldestBarTime="+ TimeToStr(Time[Bars-1], TIME_FULL) +", prevOldestBarTime="+ TimeToStr(prevOldestBarTime, TIME_FULL) +", UnchangedBars="+ UnchangedBars +")", ERR_ILLEGAL_STATE));
      }
      ManageIndicatorBuffer.Resize(buffer, Bars, emptyValue);
   }
   else /*Bars < prevBars*/ {
      // the number of Bars decreased (e.g. in online charts after MAX_CHART_BARS + ca. 1200 bars)
      for (int i=0; i < Bars; i++) {
         if (Time[i] == prevNewestBarTime) break;                    // find the index of previous Time[0] aka prevNewestBarTime
      }
      if (i == Bars) return(!catch("ManageIndicatorBuffer(6)  id="+ id +", Tick="+ Tick +", Bars decreased from "+ prevBars +" to "+ Bars +" but previous Time[0] not found", ERR_ILLEGAL_STATE));
      if (i > 0) {                                                   // manually shift the content according to the found Time[0] offset
         ManageIndicatorBuffer.Resize(buffer, ArraySize(buffer)+i, emptyValue);
      }
      ManageIndicatorBuffer.Resize(buffer, Bars);

      if (IsLogNotice()) logNotice("ManageIndicatorBuffer(6.1)  id="+ id +", Tick="+ Tick +", Bars decreased from "+ prevBars +" to "+ Bars +" (previous Time[0] bar found at offset "+ i +")");
   }

   data[id][IB.Tick         ] = Tick;
   data[id][IB.Bars         ] = Bars;
   data[id][IB.NewestBarTime] = Time[0];
   data[id][IB.OldestBarTime] = Time[Bars-1];

   // safety double-check (should never happen)
   if (ArraySize(buffer) != Bars) return(!catch("ManageIndicatorBuffer(7)  id="+ id +", Tick="+ Tick +", size(buffer)="+ ArraySize(buffer) +" doesn't match Bars="+ Bars, ERR_RUNTIME_ERROR));

   return(!catch("ManageIndicatorBuffer(8)"));
}


/**
 * Adjust the size of a managed timeseries buffer. If size increases new elements are appended at index 0. If size decreases
 * existing elements are removed from the end (the oldest elements).
 *
 * @param  double &buffer[]             - buffer
 * @param  int    newSize               - new buffer size
 * @param  double emptyValue [optional] - new buffer elements will be initialized with this value (default: NULL)
 *
 * @return bool - success status
 */
bool ManageIndicatorBuffer.Resize(double &buffer[], int newSize, double emptyValue = NULL) {
   int oldSize = ArraySize(buffer);

   if      (newSize > oldSize) ArraySetAsSeries(buffer, false);   // new elements are added at index 0
   else if (newSize < oldSize) ArraySetAsSeries(buffer, true);    // existing elements are removed from the end

   ArrayResize(buffer, newSize);                                  // reallocates memory and keeps existing content (does nothing if the size doesn't change)
   ArraySetAsSeries(buffer, true);

   if (newSize > oldSize && emptyValue) {
      if (!oldSize) {
         ArrayInitialize(buffer, emptyValue);
      }
      else {
         int newBars = newSize-oldSize;
         if (newBars == 1) {
            buffer[0] = emptyValue;                               // a single new bar after a regular BarOpen event
         }
         else {
            InitializeDoubleArray(buffer, newSize, emptyValue, oldSize, newBars);
         }
      }
   }
   return(!catch("ManageIndicatorBuffer.Resize(1)"));
}


#import "rsfMT4Expander.dll"
   bool InitializeDoubleArray(double values[], int size, double initValue, int from, int count);
#import
