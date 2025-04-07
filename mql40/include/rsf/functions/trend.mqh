/**
 * Update a trendline's indicator buffers for trend direction and coloring.
 *
 * @param  _In_  double values[]                  - trendline values (a timeseries)
 * @param  _In_  int    offset                    - bar offset to update
 * @param  _Out_ double trend[]                   - buffer for trend direction and length: -n...-1 ... +1...+n
 * @param  _Out_ double uptrend[]                 - buffer for rising trendline values
 * @param  _Out_ double downtrend[]               - buffer for falling trendline values
 * @param  _Out_ double uptrend2[]                - Additional buffer for single-bar uptrends. Must overlay uptrend[] and downtrend[] to be visible.
 * @param  _In_  bool   enableColoring [optional] - Whether to update the up/downtrend buffers for trend coloring (default: no).
 * @param  _In_  bool   enableUptrend2 [optional] - Whether to update the single-bar uptrend buffer (if enableColoring=On, default: no).
 * @param  _In_  int    lineStyle      [optional] - trendline drawing style: If set to DRAW_LINE a line is drawn immediately at the start of a trend.
 *                                                  Otherwise MetaTrader needs at least two data points to draw a line (default: draw data points only).
 * @param  _In_  int    digits         [optional] - Normalize trendline values to the specified number of digits (default: no normalization).
 *
 * @return bool - success status
 */
bool UpdateTrend(double values[], int offset, double &trend[], double &uptrend[], double &downtrend[], double &uptrend2[], bool enableColoring=false, bool enableUptrend2=false, int lineStyle=EMPTY, int digits=EMPTY_VALUE) {
   enableColoring = enableColoring!=0;
   enableUptrend2 = enableColoring && enableUptrend2!=0;

   if (offset >= Bars-1) {
      if (offset >= Bars) return(!catch("UpdateTrend(1)  illegal parameter offset: "+ offset +" (Bars="+ Bars +")", ERR_INVALID_PARAMETER));
      trend[offset] = 0;

      if (enableColoring) {
         uptrend  [offset] = EMPTY_VALUE;
         downtrend[offset] = EMPTY_VALUE;
         if (enableUptrend2) {
            uptrend2[offset] = EMPTY_VALUE;
         }
      }
      return(true);
   }

   double curValue  = values[offset];
   double prevValue = values[offset+1];

   // normalization has the affect of reversal smoothing and can prevent jitter of a seemingly flat line
   if (digits != EMPTY_VALUE) {
      curValue  = NormalizeDouble(curValue,  digits);
      prevValue = NormalizeDouble(prevValue, digits);
   }

   // trend direction
   if (prevValue == EMPTY_VALUE) {
      trend[offset] = 0;
   }
   else if (trend[offset+1] == 0) {
      trend[offset] = 0;

      if (offset < Bars-2) {
         double pre2Value = values[offset+2];
         if      (pre2Value == EMPTY_VALUE)                       trend[offset] =  0;
         else if (pre2Value <= prevValue && prevValue > curValue) trend[offset] = -1;  // curValue is a change of direction
         else if (pre2Value >= prevValue && prevValue < curValue) trend[offset] =  1;  // curValue is a change of direction
      }
   }
   else {
      int prevTrend = trend[offset+1];
      if      (curValue > prevValue) trend[offset] = Max(prevTrend, 0) + 1;
      else if (curValue < prevValue) trend[offset] = Min(prevTrend, 0) - 1;
      else   /*curValue== prevValue*/trend[offset] = prevTrend + Sign(prevTrend);
   }

   // trend coloring
   if (!enableColoring) return(true);

   if (trend[offset] > 0) {                                                      // now uptrend
      uptrend  [offset] = values[offset];
      downtrend[offset] = EMPTY_VALUE;

      if (lineStyle == DRAW_LINE) {                                              // if DRAW_LINE...
         if      (trend[offset+1] < 0) uptrend  [offset+1] = values[offset+1];   // and downtrend before, set another data point to make the terminal draw the line
         else if (trend[offset+1] > 0) downtrend[offset+1] = EMPTY_VALUE;
      }
   }
   else if (trend[offset] < 0) {                                                 // now downtrend
      uptrend  [offset] = EMPTY_VALUE;
      downtrend[offset] = values[offset];

      if (lineStyle == DRAW_LINE) {                                              // if DRAW_LINE...
         if (trend[offset+1] > 0) {                                              // and uptrend before, set another data point to make the terminal draw the line
            downtrend[offset+1] = values[offset+1];
            if (enableUptrend2) {
               if (Bars > offset+2) {
                  if (trend[offset+2] < 0) {                                     // if that uptrend was a 1-bar reversal, copy it to uptrend2 (to overlay),
                     uptrend2[offset+2] = values[offset+2];                      // otherwise the visual gets lost through the just added data point
                     uptrend2[offset+1] = values[offset+1];
                  }
               }
            }
         }
         else if (trend[offset+1] < 0) {
            uptrend[offset+1] = EMPTY_VALUE;
         }
      }
   }
   else if (values[offset] != EMPTY_VALUE) {                                     // trend length is 0 (still undefined during the first visible swing)
      if (prevValue == EMPTY_VALUE) {
         uptrend  [offset] = EMPTY_VALUE;
         downtrend[offset] = EMPTY_VALUE;
      }
      else if (curValue > prevValue) {
         uptrend  [offset] = values[offset];
         downtrend[offset] = EMPTY_VALUE;
      }
      else /*curValue < prevValue*/ {
         uptrend  [offset] = EMPTY_VALUE;
         downtrend[offset] = values[offset];
      }
   }
   return(true);
}
