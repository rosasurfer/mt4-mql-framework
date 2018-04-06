/**
 * Calculate the weights of a NonLagMA.
 *
 * @param  double weights[]
 * @param  int    cycles
 * @param  int    cycleLengths
 *
 * @return bool - success status
 */
bool @NLMA.CalculateWeights(double &weights[], int cycles, int cycleLength) {
   int phase      = cycleLength - 1;
   int windowSize = cycles*cycleLength + phase;

   if (ArraySize(weights) != windowSize)
      ArrayResize(weights, windowSize);

   double weightsSum, t, g, coeff=3*Math.PI;

   // formula version 4
   for (int i=0; i < windowSize; i++) {
      if (t <= 0.5) g = 1;
      else          g = 1/(t*coeff + 1);

      weights[i]  = g * MathCos(t * Math.PI);
      weightsSum += weights[i];

      if      (t < 1)            t += 1/(phase-1.);
      else if (t < windowSize-1) t += (2*cycles - 1)/(cycles*cycleLength - 1.);
   }

   // normalize weights: sum = 1 (100%)
   for (i=0; i < windowSize; i++) {
      weights[i] /= weightsSum;
   }
   return(true);


   // formula version 7.1
   for (i=0; i < windowSize; i++) {
      if (i < phase) t = i/(phase-1.);
      else           t = 1 + (i-cycleLength)*(2*cycles - 1)/(cycles*cycleLength - 1.);

      if (t <= 0.5) g = 1;
      else          g = 1/(t*coeff + 1);

      weights[i]  = g * MathCos(t * Math.PI);
      weightsSum += weights[i];
   }

   // The MA resulting from the formula of version 7 reacts a tiny bit slower than the one from version 4 and is probably
   // more correct. However trend changes indicated by both formulas are identical in 99.9% of all cases.
}
