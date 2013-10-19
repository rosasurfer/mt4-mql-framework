/**
 * Berechnet die Gewichtungen eines ALMAs.
 *
 * @param  double weights[]      - Array zur Aufnahme der Gewichtungen
 * @param  int    periods        - Anzahl der Perioden des ALMA
 * @param  double gaussianOffset - ALMA-Parameter (default: 0.85, see excel spread sheet)
 * @param  double sigma          - ALMA-Parameter (default: 6.0,  see excel spread sheet)
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
