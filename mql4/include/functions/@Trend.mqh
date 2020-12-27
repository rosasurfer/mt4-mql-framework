/**
 * Update a trendline's indicator buffers for trend direction and coloring.
 *
 * @param  _In_  double  values[]                  - Trendline values (a timeseries).
 * @param  _In_  int     bar                       - Bar offset to update.
 * @param  _Out_ double &trend[]                   - Buffer for trend direction and length: -n...-1 ... +1...+n.
 * @param  _Out_ double &uptrend[]                 - Buffer for rising trendline values.
 * @param  _Out_ double &downtrend[]               - Buffer for falling trendline values.
 * @param  _Out_ double &uptrend2[]                - Additional buffer for single-bar uptrends. Must overlay uptrend[] and
 *                                                   downtrend[] to be visible.
 * @param  _In_  bool    enableColoring [optional] - Whether to update the up/downtrend buffers for trend coloring.
 *                                                   (default: no)
 * @param  _In_  bool    enableUptrend2 [optional] - Whether to update the single-bar uptrend buffer (if enableColoring=On).
 *                                                   (default: no)
 * @param  _In_  int     lineStyle      [optional] - Trendline drawing style: If set to DRAW_LINE a line is drawn immediately
 *                                                   at the start of a trend. Otherwise MetaTrader needs at least two data
 *                                                   points to draw a line. (default: draw data points only)
 * @param  _In_  int     digits         [optional] - If set, trendline values are normalized to the specified number of digits.
 *                                                   (default: no normalization)
 *
 * @return bool - success status
 */
bool @Trend.UpdateDirection(double values[], int bar, double &trend[], double &uptrend[], double &downtrend[], double &uptrend2[], bool enableColoring=false, bool enableUptrend2=false, int lineStyle=EMPTY, int digits=EMPTY_VALUE) {
   enableColoring = enableColoring!=0;
   enableUptrend2 = enableColoring && enableUptrend2!=0;

   if (bar >= Bars-1) {
      if (bar >= Bars) return(!catch("@Trend.UpdateDirection(1)  illegal parameter bar: "+ bar, ERR_INVALID_PARAMETER));
      trend[bar] = 0;

      if (enableColoring) {
         uptrend  [bar] = EMPTY_VALUE;
         downtrend[bar] = EMPTY_VALUE;
         if (enableUptrend2)
            uptrend2[bar] = EMPTY_VALUE;
      }
      return(true);
   }

   double curValue  = values[bar  ];
   double prevValue = values[bar+1];

   // normalization has the affect of reversal smoothing and can prevent jitter of a seemingly flat line
   if (digits != EMPTY_VALUE) {
      curValue  = NormalizeDouble(curValue,  digits);
      prevValue = NormalizeDouble(prevValue, digits);
   }

   // trend direction
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

   // trend coloring
   if (!enableColoring) return(true);

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
            if (enableUptrend2) {
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
   return(true);

   /*                  [4] [3] [2] [1] [0]
   onBarOpen()  trend: -5  -6  -7  -8  -9
   onBarOpen()  trend: -5  -6  -7  -8   1     after a downtrend of 8 bars trend turns up
   onBarOpen()  trend: -6  -7  -8   1   2
   onBarOpen()  trend: -7  -8   1   2   3
   onBarOpen()  trend: -8   1   2   3  -1     after an uptrend of 3 bars trend turns down
   */

   // dummy call
   @Trend.UpdateLegend(NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
}


/**
 * Update a trendline's chart legend.
 *
 * @param  string   label          - chart label of the legend object
 * @param  string   name           - indicator name
 * @param  string   status         - additional status info (if any)
 * @param  color    uptrendColor   - the uptrend color
 * @param  color    downtrendColor - the downtrend color
 * @param  double   value          - indicator value to display
 * @param  int      digits         - digits of the value to display
 * @param  double   dTrend         - trend direction of the value to display (type double allows passing of non-normalized values)
 * @param  datetime barOpenTime    - bar opentime of the value to display
 */
void @Trend.UpdateLegend(string label, string name, string status, color uptrendColor, color downtrendColor, double value, int digits, double dTrend, datetime barOpenTime) {
   static double   lastValue;
   static int      lastTrend;
   static datetime lastBarOpenTime;
   string sValue="", sTrend="", sOnTrendChange="";

   value = NormalizeDouble(value, digits);
   int trend = MathRound(dTrend);

   // update if value, trend direction or bar changed
   if (value!=lastValue || trend!=lastTrend || barOpenTime!=lastBarOpenTime) {
      if      (digits == PipDigits)    sValue = NumberToStr(value, PipPriceFormat);
      else if (digits == SubPipDigits) sValue = NumberToStr(value, SubPipPriceFormat);
      else                             sValue = DoubleToStr(value, digits);

      if (trend != 0) sTrend = StringConcatenate("  (", trend, ")");

      if (status != "") status = StringConcatenate("  ", status);

      if (uptrendColor != downtrendColor) {
         if      (trend ==  1) sOnTrendChange = "  turns up";           // intra-bar trend change
         else if (trend == -1) sOnTrendChange = "  turns down";         // ...
      }

      string text = StringConcatenate(name, "    ", sValue, sTrend, status, sOnTrendChange);
      color  cColor = ifInt(trend > 0, uptrendColor, downtrendColor);
      if      (cColor == Aqua  ) cColor = DeepSkyBlue;
      else if (cColor == Gold  ) cColor = Orange;
      else if (cColor == Lime  ) cColor = LimeGreen;
      else if (cColor == Yellow) cColor = Orange;

      ObjectSetText(label, text, 9, "Arial Fett", cColor);
      int error = GetLastError();
      if (IsError(error)) /*&&*/ if (error!=ERR_OBJECT_DOES_NOT_EXIST)  // on Object::onDrag() or opened "Properties" dialog
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
   @Trend.UpdateDirection(dNull, NULL, dNull, dNull, dNull, dNull, NULL);
}
