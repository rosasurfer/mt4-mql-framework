/**
 * Update a trendline's indicator buffers for trend direction and coloring.
 *
 * @param  _In_  double  values[]                   - Trend line values (a timeseries).
 * @param  _In_  int     bar                        - Bar offset to update.
 * @param  _Out_ double &trend[]                    - Buffer for trend direction and trend length: -n...-1 ... +1...+n.
 * @param  _Out_ double &uptrend[]                  - Buffer for rising trend line values.
 * @param  _Out_ double &downtrend[]                - Buffer for falling trend line values.
 * @param  _In_  int     lineStyle                  - Trend line drawing style: If set to DRAW_LINE a line is drawn imme-
 *                                                    diately at the start of a trend. Otherwise MetaTrader needs at least
 *                                                    two data points to draw a line.
 * @param  _Out_ double &uptrend2[]                 - Additional buffer for single-bar uptrends. Must overlay uptrend[] and
 *                                                    downtrend[] to become visible.
 * @param  _In_  bool    uptrend2_enable [optional] - Whether or not to update the single-bar uptrend buffer.
 *                                                    (default: no)
 * @param  _In_  int     digits          [optional] - If set values are normalized to the specified number of digits.
 *                                                    (default: no normalization).
 */
void @Trend.UpdateDirection(double values[], int bar, double &trend[], double &uptrend[], double &downtrend[], int lineStyle, double &uptrend2[], bool uptrend2_enable=false, int digits=EMPTY_VALUE) {
   uptrend2_enable = uptrend2_enable!=0;

   if (bar >= Bars-1) {
      if (bar >= Bars) return(catch("@Trend.UpdateDirection(1)  illegal parameter bar: "+ bar, ERR_INVALID_PARAMETER));
      trend    [bar] = 0;
      uptrend  [bar] = EMPTY_VALUE;
      downtrend[bar] = EMPTY_VALUE;
      if (uptrend2_enable)
         uptrend2[bar] = EMPTY_VALUE;
      return;
   }

   double curValue  = values[bar  ];
   double prevValue = values[bar+1];

   // normalization has the affect of reversal smoothing and can prevent "jitter" of a seemingly flat line
   if (digits != EMPTY_VALUE) {
      curValue  = NormalizeDouble(curValue,  digits);
      prevValue = NormalizeDouble(prevValue, digits);
   }


   // (1) trend direction
   if (prevValue == EMPTY_VALUE) {
      trend[bar] = 0;
   }
   else if (trend[bar+1] == 0) {
      trend[bar] = 0;

      if (bar < Bars-2) {
         double pre2Value = values[bar+2];
         if      (pre2Value == EMPTY_VALUE)                       trend[bar] =  0;
         else if (pre2Value <= prevValue && prevValue > curValue) trend[bar] = -1;  // curValue is a change of direction
         else if (pre2Value >= prevValue && prevValue < curValue) trend[bar] =  1;  // curValue is a change of direction
      }
   }
   else {
      if      (curValue > prevValue) trend[bar] =  Max(trend[bar+1], 0) + 1;
      else if (curValue < prevValue) trend[bar] =  Min(trend[bar+1], 0) - 1;
      else   /*curValue== prevValue*/trend[bar] = _int(trend[bar+1]) + Sign(trend[bar+1]);
   }


   // (2) trend coloring
   if (trend[bar] > 0) {                                                // now uptrend
      uptrend  [bar] = values[bar];
      downtrend[bar] = EMPTY_VALUE;

      if (lineStyle == DRAW_LINE) {                                     // if DRAW_LINE...
         if      (trend[bar+1] < 0) uptrend  [bar+1] = values[bar+1];   // and downtrend before, set another data point to make the terminal draw the line
         else if (trend[bar+1] > 0) downtrend[bar+1] = EMPTY_VALUE;
      }
   }
   else if (trend[bar] < 0) {                                           // now downtrend
      uptrend  [bar] = EMPTY_VALUE;
      downtrend[bar] = values[bar];

      if (lineStyle == DRAW_LINE) {                                     // if DRAW_LINE...
         if (trend[bar+1] > 0) {                                        // and uptrend before, set another data point to make the terminal draw the line
            downtrend[bar+1] = values[bar+1];
            if (uptrend2_enable) {
               if (Bars > bar+2) {
                  if (trend[bar+2] < 0) {                               // if that uptrend was a 1-bar reversal, copy it to uptrend2 (to overlay),
                     uptrend2[bar+2] = values[bar+2];                   // otherwise the visual gets lost through the just added data point
                     uptrend2[bar+1] = values[bar+1];
                  }
               }
            }
         }
         else if (trend[bar+1] < 0) {
            uptrend[bar+1] = EMPTY_VALUE;
         }
      }
   }
   else if (values[bar] != EMPTY_VALUE) {                               // trend length is 0 (still undefined during the first visible swing)
      if (prevValue == EMPTY_VALUE) {
         uptrend  [bar] = EMPTY_VALUE;
         downtrend[bar] = EMPTY_VALUE;
      }
      else if (curValue > prevValue) {
         uptrend  [bar] = values[bar];
         downtrend[bar] = EMPTY_VALUE;
      }
      else /*curValue < prevValue*/ {
         uptrend  [bar] = EMPTY_VALUE;
         downtrend[bar] = values[bar];
      }
   }
   return;

   /*                  [3] [2] [1] [0]
   onBarOpen()  trend: -6  -7  -8  -9
   onBarOpen()  trend: -6  -7  -8   1     after a downtrend of 8 bars trend turns up
   onBarOpen()  trend: -7  -8   1   2
   onBarOpen()  trend: -8   1   2   3
   onBarOpen()  trend:  1   2   3  -1     after an uptrend of 3 bars trend turns down
   */

   // dummy call
   @Trend.UpdateLegend(NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
}


/**
 * Update a trend line's chart legend.
 *
 * @param  string   label          - chart label of the legend object
 * @param  string   name           - the trend line's name (usually the indicator name)
 * @param  string   status         - additional status info (if any)
 * @param  color    uptrendColor   - the trend line's uptrend color
 * @param  color    downtrendColor - the trend line's downtrend color
 * @param  double   value          - current trend line value
 * @param  int      trend          - current trend line direction
 * @param  datetime barOpenTime    - current trend line bar opentime
 */
void @Trend.UpdateLegend(string label, string name, string status, color uptrendColor, color downtrendColor, double value, int trend, datetime barOpenTime) {
   static double   lastValue;
   static int      lastTrend;
   static datetime lastBarOpenTime;
   string sOnTrendChange;

   value = NormalizeDouble(value, SubPipDigits);

   // update if value, trend direction or bar changed
   if (value!=lastValue || trend!=lastTrend || barOpenTime!=lastBarOpenTime) {
      if (uptrendColor != downtrendColor) {
         if      (trend ==  1) sOnTrendChange = "turns up";             // intra-bar trend change
         else if (trend == -1) sOnTrendChange = "turns down";           // ...
      }
      string text      = StringConcatenate(name, "    ", NumberToStr(value, SubPipPriceFormat), "    ", status, "    ", sOnTrendChange);
      color  textColor = ifInt(trend > 0, uptrendColor, downtrendColor);
      if (textColor == Yellow)
         textColor = Orange;

      ObjectSetText(label, text, 9, "Arial Fett", textColor);
      int error = GetLastError();
      if (IsError(error)) /*&&*/ if (error!=ERR_OBJECT_DOES_NOT_EXIST)  // on open "Properties" dialog or on Object::onDrag()
         return(catch("@Trend.UpdateLegend(1)", error));
   }

   lastValue       = value;
   lastTrend       = trend;
   lastBarOpenTime = barOpenTime;
   return;

   /*                  [3] [2] [1] [0]
   onBarOpen()  trend: -6  -7  -8  -9
   onBarOpen()  trend: -6  -7  -8   1     after a downtrend of 8 bars trend turns up
   onBarOpen()  trend: -7  -8   1   2
   onBarOpen()  trend: -8   1   2   3
   onBarOpen()  trend:  1   2   3  -1     after an uptrend of 3 bars trend turns down
   */

   // dummy call
   double dNull[];
   @Trend.UpdateDirection(dNull, NULL, dNull, dNull, dNull, NULL, dNull);
}
