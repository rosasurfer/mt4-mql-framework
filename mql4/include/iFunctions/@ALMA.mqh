/**
 * Berechnet die Gewichtungen eines ALMAs.
 *
 * @param  double weights[] - Array zur Aufnahme der Gewichtungen
 * @param  int    periods   - Anzahl der Perioden des ALMA
 * @param  double offset    - Verteilungsoffset der Gauss'schen Kurve (default: 0.85)
 * @param  double sigma     - Steilheit der Gauss'schen Kurve (default: 6.0)
 *
 *
 * @see    "experts/indicators/etc/arnaudlegoux.com/Weighted Distribution.xls"
 */
void iALMA.CalculateWeights(double &weights[], int periods, double offset=0.85, double sigma=6.0) {
   if (ArraySize(weights) != periods)
      ArrayResize(weights, periods);

   double m = MathRound(offset * (periods-1));
   double s = periods / sigma;
   double wSum;

   for (int j, i=0; i < periods; i++) {
      j = periods-1-i;
      weights[j] = MathExp(-(i-m)*(i-m)/(2*s*s));
      wSum      += weights[j];
   }
   for (i=0; i < periods; i++) {
      weights[i] /= wSum;                                            // Summe der Gewichtungen aller Bars = 1 (100%)
   }
}
