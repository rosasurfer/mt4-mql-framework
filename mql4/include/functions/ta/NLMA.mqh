/**
 * Calculate the weights of a NonLagMA.
 *
 * This indicator uses the formula of version 4. The MA using the formula of version 7 is a bit less responsive (and probably
 * more correct because more recent). However in 99.9% of the observed cases trend changes indicated by both formulas are
 * identical.
 *
 * @param  _Out_ double weights[]
 * @param  _In_  int    cycles
 * @param  _In_  int    cycleLength
 *
 * @return bool - success status
 *
 * @link  v4.0: https://www.forexfactory.com/showthread.php?t=571026
 * @link  v7.1: http://www.yellowfx.com/nonlagma-v7-1-mq4-indicator.htm
 */
bool NLMA.CalculateWeights(double &weights[], int cycles, int cycleLength) {
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
}
