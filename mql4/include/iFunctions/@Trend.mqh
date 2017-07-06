/**
 * Update a trend line's indicator buffers for trend direction and coloring.
 *
 * @param  _In_  double  values[]        - Trend line values (a time series).
 * @param  _In_  int     bar             - Bar offset to update.
 * @param  _Out_ double &trend    []     - Resulting buffer with trend direction and length at bar offset: -n...-1 ... +1...+n
 * @param  _Out_ double &uptrend  []     - Resulting buffer with rising trend line values.
 * @param  _Out_ double &downtrend[]     - Resulting buffer with falling trend line values.
 * @param  _In_  int     lineStyle       - Trend line drawing style: If set to DRAW_LINE a line is drawn immediately at the start of a trend change.
 *                                         Otherwise MetaTrader needs at least two data points to draw a line.
 * @param  _Out_ double &uptrend2 []     - Additional buffer with 1-bar-uptrends. This buffer must overlay uptrend[] and downtrend[] to become visible.
 * @param  _In_  bool    uptrend2_enable - Whether or not to update the additional 1-bar-uptrends buffer. (default: no)
 * @param  _In_  int     normalizeDigits - If set values are normalized to the specified number of digits. (default: no normalization)
 */
void @Trend.UpdateDirection(double values[], int bar, double &trend[], double &uptrend[], double &downtrend[], int lineStyle, double &uptrend2[], bool uptrend2_enable=false, int normalizeDigits=EMPTY_VALUE) {
   uptrend2_enable = uptrend2_enable!=0;

   double currentValue  = values[bar  ];
   double previousValue = values[bar+1];

   // normalization has the affect of reversal smoothing and can prevent "jitter" of a seemingly flat line
   if (normalizeDigits != EMPTY_VALUE) {
      currentValue  = NormalizeDouble(currentValue,  normalizeDigits);
      previousValue = NormalizeDouble(previousValue, normalizeDigits);
   }

   // trend direction
   if      (currentValue > previousValue) trend[bar] =  Max(trend[bar+1], 0) + 1;
   else if (currentValue < previousValue) trend[bar] =  Min(trend[bar+1], 0) - 1;
   else                                   trend[bar] = _int(trend[bar+1]) + Sign(trend[bar+1]);

   // trend coloring
   if (trend[bar] > 0) {                                             // now up-trend
      uptrend  [bar] = values[bar];
      downtrend[bar] = EMPTY_VALUE;

      if (lineStyle == DRAW_LINE) {                                  // if DRAW_LINE...
         if (trend[bar+1] < 0) uptrend  [bar+1] = values[bar+1];     // ...and down-trend before, provide another data point to...
         else                  downtrend[bar+1] = EMPTY_VALUE;       // ...enable MetaTrader to draw the line
      }
   }
   else /*trend[bar] < 0*/ {                                         // now down-trend
      uptrend  [bar] = EMPTY_VALUE;
      downtrend[bar] = values[bar];

      if (lineStyle == DRAW_LINE) {                                  // if DRAW_LINE...
         if (trend[bar+1] > 0) {                                     // ...and up-trend before, provide another data point to...
            downtrend[bar+1] = values[bar+1];                        // ...enable MetaTrader to draw the line
            if (uptrend2_enable) {
               if (Bars > bar+2) /*&&*/ if (trend[bar+2] < 0) {      // if that up-trend was a 1-bar-reversal, copy it to uptrend2 (to overlay),
                  uptrend2[bar+2] = values[bar+2];                   // otherwise the visual gets lost through the just added data point
                  uptrend2[bar+1] = values[bar+1];
               }
            }
         }
         else {
            uptrend[bar+1] = EMPTY_VALUE;
         }
      }
   }
   return;

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
      if      (trend ==  1) sOnTrendChange = "turns up";                // intra-bar trend change
      else if (trend == -1) sOnTrendChange = "turns down";              // ...
      string text      = StringConcatenate(name, "    ", NumberToStr(value, SubPipPriceFormat), "    ", status, "    ", sOnTrendChange);
      color  textColor = ifInt(trend > 0, uptrendColor, downtrendColor);

      ObjectSetText(label, text, 9, "Arial Fett", textColor);
      int error = GetLastError();
      if (IsError(error)) /*&&*/ if (error!=ERR_OBJECT_DOES_NOT_EXIST)  // on open "Properties" dialog or on Object::onDrag()
         return(catch("@Trend.UpdateLegend(1)", error));
   }

   lastValue       = value;
   lastTrend       = trend;
   lastBarOpenTime = barOpenTime;
   return;

   /*
   debug("onTick()  trend: "+ _int(trend[3]) +"  "+ _int(trend[2]) +"  "+ _int(trend[1]) +"  "+ _int(trend[0]));
   onTick()  trend: -6  -7  -8  -9
   onTick()  trend: -6  -7  -8   1
   onTick()  trend: -7  -8   1   2
   onTick()  trend: -7  -8   1   2
   */

   // dummy call
   double dNull[];
   @Trend.UpdateDirection(dNull, NULL, dNull, dNull, dNull, NULL, dNull);
}
