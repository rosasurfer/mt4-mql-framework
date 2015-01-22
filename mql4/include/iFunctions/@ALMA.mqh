/**
 * Berechnet die Gewichtungen eines ALMAs.
 *
 * @param  double weights[]  - Array zur Aufnahme der Gewichtungen
 * @param  int    periods    - Anzahl der Perioden des ALMA
 * @param  double distOffset - Verteilungsoffset der Gauss'schen Kurve (default: 0.85)
 * @param  double distSigma  - Verteilungs-Höhe der Gauss'schen Kurve (default: 6.0)
 *
 *
 *
 */
void @ALMA.CalculateWeights(double &weights[], int periods, double distOffset=0.85, double distSigma=6.0) {
   if (ArraySize(weights) != periods)
      ArrayResize(weights, periods);

   double m = MathRound(distOffset * (periods-1));
   double s = periods / distSigma;
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
