/**
 * Calculate the weights of an ALMA using the formula of a Gaussian normal distribution.
 *
 * @param  _In_  int    periods    - number of MA periods
 * @param  _In_  double offset     - offset of the desired distribution, recommended value: 0.85
 * @param  _In_  double sigma      - sigma (steepness) of the desired distribution, recommended value: 6.0
 * @param  _Out_ double &weights[] - array receiving the resulting MA weights
 *
 * @return bool - success status
 *
 * @link  http://web.archive.org/web/20180307031850/http://www.arnaudlegoux.com/
 *
 */
bool ALMA.CalculateWeights(int periods, double offset, double sigma, double &weights[]) {
   if (periods <= 0)             return(!catch("ALMA.CalculateWeights(1)  invalid parameter periods: "+ periods +" (out of range)", ERR_INVALID_PARAMETER));
   if (offset < 0 || offset > 1) return(!catch("ALMA.CalculateWeights(2)  invalid parameter offset: "+ NumberToStr(offset, ".1+") +" (out of range)", ERR_INVALID_PARAMETER));
   if (sigma <= 0)               return(!catch("ALMA.CalculateWeights(3)  invalid parameter sigma: "+ NumberToStr(sigma, ".1+") +" (must be positive)", ERR_INVALID_PARAMETER));

   if (ArraySize(weights) != periods)
      ArrayResize(weights, periods);

   double dist = (periods-1) * offset;                // m: resulting distance of vertex from the oldest bar
   double s    = periods / sigma;                     // s: resulting steepness
   double weightsSum = 0;

   for (int j, i=0; i < periods; i++) {
      j = periods-1-i;
      weights[j]  = MathExp(-(i-dist)*(i-dist)/(2*s*s));
      weightsSum += weights[j];
   }
   for (i=0; i < periods; i++) {                      // normalize weights: sum = 1 (100%)
      weights[i] /= weightsSum;
   }

   return(!catch("ALMA.CalculateWeights(4)"));
}
