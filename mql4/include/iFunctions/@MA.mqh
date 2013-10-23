/**
 * Aktualisiert Trend und Trend-Coloring eines Moving Average.
 */
void iMA.UpdateTrend(double bufferMA[], double &bufferTrend[], double &bufferUpTrend[], double &bufferDownTrend[], double &bufferUpTrend2[], int bar) {
   // (1) Trend: Reversal-Glättung um 0.1 pip durch Normalisierung
   double currentValue  = NormalizeDouble(bufferMA[bar  ], SubPipDigits);
   double previousValue = NormalizeDouble(bufferMA[bar+1], SubPipDigits);

   if      (currentValue > previousValue) bufferTrend[bar] =       Max(bufferTrend[bar+1], 0) + 1;
   else if (currentValue < previousValue) bufferTrend[bar] =       Min(bufferTrend[bar+1], 0) - 1;
   else                                   bufferTrend[bar] = MathRound(bufferTrend[bar+1] + Sign(bufferTrend[bar+1]));


   // (2) Trend-Coloring
   if (bufferTrend[bar] > 0) {                                       // Up-Trend
      bufferUpTrend  [bar] = bufferMA[bar];
      bufferDownTrend[bar] = EMPTY_VALUE;

      if (bufferTrend[bar+1] < 0) bufferUpTrend  [bar+1] = bufferMA[bar+1];
      else                        bufferDownTrend[bar+1] = EMPTY_VALUE;
   }
   else {                                                            // Down-Trend
      bufferUpTrend  [bar] = EMPTY_VALUE;
      bufferDownTrend[bar] = bufferMA[bar];

      if (bufferTrend[bar+1] > 0) {                                  // wenn vorher Up-Trend...
         bufferDownTrend[bar+1] = bufferMA[bar+1];
         if (Bars > bar+2) /*&&*/ if (bufferTrend[bar+2] < 0) {      // ...und Up-Trend war nur eine Bar lang, ...
            bufferUpTrend2[bar+2] = bufferMA[bar+2];
            bufferUpTrend2[bar+1] = bufferMA[bar+1];                 // ... dann Down-Trend mit Up-Trend 2 überlagern.
         }
      }
      else {
         bufferUpTrend[bar+1] = EMPTY_VALUE;
      }
   }
}


/**
 * Aktualisiert die Legende eines Moving Average.
 */
void iMA.UpdateLegend(string legendLabel, string legendDescription, color upTrendColor, color downTrendColor, double currentValue, int currentTrend, datetime currentBarOpenTime) {
   static double   lastValue;                                           // Value des vorherigen Ticks
   static int      lastTrend;                                           // Trend des vorherigen Ticks
   static datetime lastBarOpenTime;
   static bool     intrabarTrendChange;                                 // vorläufiger Trendwechsel innerhalb der aktuellen Bar

   // bei Trendwechsel Farbe aktualisieren
   if (Sign(currentTrend) != Sign(lastTrend)) {
      ObjectSetText(legendLabel, ObjectDescription(legendLabel), 9, "Arial Fett", ifInt(currentTrend>0, upTrendColor, downTrendColor));
      int error = GetLastError();
      if (IsError(error)) /*&&*/ if (error!=ERR_OBJECT_DOES_NOT_EXIST)  // bei offenem Properties-Dialog oder Object::onDrag()
         return(catch("iMA.UpdateLegend()", error));
      if (lastTrend != 0)
         intrabarTrendChange = !intrabarTrendChange;
   }
   if (currentBarOpenTime > lastBarOpenTime) /*&&*/ if (Abs(currentTrend)==2)
      intrabarTrendChange = false;                                      // onBarOpen vorläufigen Trendwechsel der vorherigen Bar deaktivieren


   // bei Wertänderung Wert aktualisieren
   currentValue = NormalizeDouble(currentValue, SubPipDigits);

   if (currentValue!=lastValue || currentBarOpenTime > lastBarOpenTime) {
      ObjectSetText(legendLabel,
                    StringConcatenate(legendDescription, ifString(intrabarTrendChange, "_i", ""), "    ", NumberToStr(currentValue, SubPipPriceFormat)),
                    ObjectGet(legendLabel, OBJPROP_FONTSIZE));
   }
   lastValue       = currentValue;
   lastTrend       = currentTrend;
   lastBarOpenTime = currentBarOpenTime;
}
