/**
 * Berechnet die Gewichtungen eines ZLMAs.
 *
 * @param  double weights[]    -
 * @param  int    cycles       -
 * @param  int    cycleLengths -
 *
 * @see  "etc/mql/indicators/nonlagma/ZLMA Weighted Distribution.xls"
 */
void @ZLMA.CalculateWeights(double &weights4[], double &weights7[], int cycles, int cycleLength) {
   int phase      = cycleLength - 1;
   int windowSize = cycles*cycleLength + phase;

   if (ArraySize(weights4) != windowSize) ArrayResize(weights4, windowSize);
   if (ArraySize(weights7) != windowSize) ArrayResize(weights7, windowSize);

   double t, g, coeff=3*Math.PI, weightsSum;


   // ZLMA v4
   weightsSum = 0;
   for (int i=0; i < windowSize; i++) {
      if (t <= 0.5) g = 1;
      else          g = 1/(t*coeff + 1);

      weights4[i] = g * MathCos(t * Math.PI);
      weightsSum += weights4[i];

      if      (t < 1)            t += 1/(phase-1.);
      else if (t < windowSize-1) t += (2*cycles - 1)/(cycles*cycleLength - 1.);
   }
   for (i=0; i < windowSize; i++) {
      weights4[i] /= weightsSum;                                                 // Gewichtungen normalisieren: Summe = 1 (100%)
   }


   // ZLMA v7.1
   weightsSum = 0;
   for (i=0; i < windowSize; i++) {
      if (i < phase) t = i/(phase-1.);
      else           t = 1 + (i-cycleLength)*(2*cycles - 1)/(cycles*cycleLength - 1.);

      if (t <= 0.5) g = 1;
      else          g = 1/(t*coeff + 1);

      weights7[i] = g * MathCos(t * Math.PI);
      weightsSum += weights7[i];
   }
   for (i=0; i < windowSize; i++) {
      weights7[i] /= weightsSum;                                                 // Gewichtungen normalisieren: Summe = 1 (100%)
   }
}
