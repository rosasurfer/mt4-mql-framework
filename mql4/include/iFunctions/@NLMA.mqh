/**
 * Berechnet die Gewichtungen eines ZLMAs.
 *
 * @param  double weights[]    -
 * @param  int    cycles       -
 * @param  int    cycleLengths -
 * @param  int    version      - Formel nach Version 4 oder Version 7.1
 *
 * @return bool - Erfolgsstatus
 */
bool @ZLMA.CalculateWeights(double &weights[], int cycles, int cycleLength, int version) {
   int phase      = cycleLength - 1;
   int windowSize = cycles*cycleLength + phase;

   if (ArraySize(weights) != windowSize)
      ArrayResize(weights, windowSize);

   double t, g, coeff=3*Math.PI, weightsSum;

   // ZLMA v4
   if (version == 4) {
   weightsSum = 0;
      for (int i=0; i < windowSize; i++) {
         if (t <= 0.5) g = 1;
         else          g = 1/(t*coeff + 1);

         weights[i]  = g * MathCos(t * Math.PI);
         weightsSum += weights[i];

         if      (t < 1)            t += 1/(phase-1.);
         else if (t < windowSize-1) t += (2*cycles - 1)/(cycles*cycleLength - 1.);
      }
   }

   // ZLMA v7.1
   else if (version == 7) {
      weightsSum = 0;
      for (i=0; i < windowSize; i++) {
         if (i < phase) t = i/(phase-1.);
         else           t = 1 + (i-cycleLength)*(2*cycles - 1)/(cycles*cycleLength - 1.);

         if (t <= 0.5) g = 1;
         else          g = 1/(t*coeff + 1);

         weights[i]  = g * MathCos(t * Math.PI);
         weightsSum += weights[i];
      }
   }
   else return(!catch("@ZLMA.CalculateWeights(1)  invalid parameter version = "+ version +" (must be 4 or 7)", ERR_INVALID_PARAMETER));


   // Gewichtungen normalisieren: Summe = 1 (100%)
   for (i=0; i < windowSize; i++) {
      weights[i] /= weightsSum;
   }
   return(true);
}
