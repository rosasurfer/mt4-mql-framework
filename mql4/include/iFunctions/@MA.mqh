/**
 * Aktualisiert die Indikatorbuffer für den Trend und das Trend-Coloring eines Moving Average.
 *
 * @param  _IN_  double  ma[]        - Array mit den Werten des Moving Average
 * @param  _IN_  int     bar         - Offset der zu aktualisierenden Bar
 * @param  _OUT_ double &trend    [] - Trendrichtung und -länge der aktualisierten Bar (-n...-1 ... +1...+n)
 * @param  _OUT_ double &upTrend1 [] - steigende Indikatorwerte
 * @param  _OUT_ double &downTrend[] - fallende Indikatorwerte (liegt im Chart über der UpTrend-1-Linie)
 * @param  _OUT_ double &upTrend2 [] - steigende Indikatorwerte für Trendlängen von einer einzigen Bar (liegt im Chart über der DownTrend-Line)
 */
void iMA.UpdateTrend(double ma[], int bar, double &trend[], double &upTrend1[], double &downTrend[], double &upTrend2[]) {
   // (1) Trend: Reversal-Glättung um 0.1 pip durch Normalisierung
   double currentValue  = NormalizeDouble(ma[bar  ], SubPipDigits);
   double previousValue = NormalizeDouble(ma[bar+1], SubPipDigits);

   if      (currentValue > previousValue) trend[bar] =       Max(trend[bar+1], 0) + 1;
   else if (currentValue < previousValue) trend[bar] =       Min(trend[bar+1], 0) - 1;
   else                                   trend[bar] = MathRound(trend[bar+1] + Sign(trend[bar+1]));


   // (2) Trend-Coloring
   if (trend[bar] > 0) {                                             // (2.1) jetzt Up-Trend
      upTrend1 [bar] = ma[bar];
      downTrend[bar] = EMPTY_VALUE;

      if (trend[bar+1] < 0) upTrend1 [bar+1] = ma[bar+1];            // wenn vorher Down-Trend...
      else                  downTrend[bar+1] = EMPTY_VALUE;
   }
   else {                                                            // (2.2) jetzt Down-Trend
      upTrend1 [bar] = EMPTY_VALUE;
      downTrend[bar] = ma[bar];

      if (trend[bar+1] > 0) {                                        // wenn vorher Up-Trend...
         downTrend[bar+1] = ma[bar+1];
         if (Bars > bar+2) /*&&*/ if (trend[bar+2] < 0) {            // ...und dieser Up-Trend war nur eine Bar lang...
            upTrend2[bar+2] = ma[bar+2];
            upTrend2[bar+1] = ma[bar+1];                             // ...dann Down-Trend mit Up-Trend 2 überlagern.
         }
      }
      else {
         upTrend1[bar+1] = EMPTY_VALUE;
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
