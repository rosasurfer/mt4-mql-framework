/**
 * Berechnet die Gewichtungen eines ALMAs.
 *
 * @param  double weights[]      - Array zur Aufnahme der Gewichtungen
 * @param  int    periods        - Anzahl der Perioden des ALMA
 * @param  double gaussianOffset - default: 0.85, Gauss'scher Verteilungsoffset, siehe Excel-Tabelle
 * @param  double sigma          - default: 6.0, siehe Excel-Tabelle
 *
 *
 *
 */
void iALMA.CalculateWeights(double &weights[], int periods, double gaussianOffset=0.85, double sigma=6.0) {
   if (ArraySize(weights) != periods)
      ArrayResize(weights, periods);

   double m = MathRound(gaussianOffset * (periods-1));
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
