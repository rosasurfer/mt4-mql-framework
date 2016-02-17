/**
 * Aktualisiert die Indikatorbuffer für den Trend und das Trend-Coloring eines Moving Average.
 *
 * @param  _In_  double  ma[]        - Array mit den Werten des Moving Average
 * @param  _In_  int     bar         - Offset der zu aktualisierenden Bar
 * @param  _Out_ double &trend    [] - Trendrichtung und -länge der aktualisierten Bar (-n...-1 ... +1...+n)
 * @param  _Out_ double &upTrend1 [] - steigende Indikatorwerte
 * @param  _Out_ double &downTrend[] - fallende Indikatorwerte (liegt im Chart über der UpTrend-1-Linie)
 * @param  _Out_ double &upTrend2 [] - steigende Indikatorwerte für Trendlängen von einer einzigen Bar (liegt im Chart über der DownTrend-Line)
 */
void @MA.UpdateTrend(double ma[], int bar, double &trend[], double &upTrend1[], double &downTrend[], double &upTrend2[]) {
   // (1) Trend: Reversal-Glättung um 0.1 pip durch Normalisierung
   double currentValue  = NormalizeDouble(ma[bar  ], SubPipDigits);
   double previousValue = NormalizeDouble(ma[bar+1], SubPipDigits);

   if      (currentValue > previousValue) trend[bar] =  Max(trend[bar+1], 0) + 1;
   else if (currentValue < previousValue) trend[bar] =  Min(trend[bar+1], 0) - 1;
   else                                   trend[bar] = _int(trend[bar+1]) + Sign(trend[bar+1]);


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
 *
 * @param  string   label              - Label des Legenden-Objects
 * @param  string   ma.description     - MA-Beschreibungstext (Kurzname)
 * @param  string   signal.description - Signal-Beschreibungstext (falls zutreffend)
 * @param  color    upTrendColor       - Farbe für Up-Trends
 * @param  color    downTrendColor     - Farbe für Down-Trends
 * @param  double   value              - aktueller Indikatorwert
 * @param  int      trend              - aktueller Trendwert
 * @param  datetime barOpenTime        - OpenTime der jüngsten Bar
 */
void @MA.UpdateLegend(string label, string ma.description, string signal.description, color upTrendColor, color downTrendColor, double value, int trend, datetime barOpenTime) {
   static double   lastValue;
   static int      lastTrend;
   static datetime lastBarOpenTime;

   value = NormalizeDouble(value, SubPipDigits);

   // Aktualisierung wenn sich Wert, Trend oder Bar geändert haben
   if (value!=lastValue || trend!=lastTrend || barOpenTime!=lastBarOpenTime) {
      string text      = StringConcatenate(ma.description, ifString(Abs(trend)==1, "_i", ""), "    ", NumberToStr(value, SubPipPriceFormat), "    ", signal.description);
      color  textColor = ifInt(trend > 0, upTrendColor, downTrendColor);

      ObjectSetText(label, text, 9, "Arial Fett", textColor);
      int error = GetLastError();
      if (IsError(error)) /*&&*/ if (error!=ERR_OBJECT_DOES_NOT_EXIST)  // bei offenem Properties-Dialog oder Object::onDrag()
         return(catch("@MA.UpdateLegend(1)", error));
   }

   lastValue       = value;
   lastTrend       = trend;
   lastBarOpenTime = barOpenTime;

   /*
   debug("onTick()  trend: "+ _int(trend[3]) +"  "+ _int(trend[2]) +"  "+ _int(trend[1]) +"  "+ _int(trend[0]));
   onTick()  trend: -6  -7  -8  -9
   onTick()  trend: -6  -7  -8   1
   onTick()  trend: -7  -8   1   2
   onTick()  trend: -7  -8   1   2
   */
}
