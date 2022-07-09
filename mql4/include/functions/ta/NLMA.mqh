/**
 * Calculate the weights of a NonLagMA using a cosine wave function.
 *
 * @param  _In_  int    cycles       - number of wave cycles
 * @param  _In_  int    cyclePeriods - wave cycle length in bars
 * @param  _Out_ double &weights[]   - array receiving the resulting MA weights
 *
 * @return bool - success status
 *
 * @link  https://www.forexfactory.com/showthread.php?t=571026#                                 [NonLag Moving Average v4.0]
 * @link  http://www.yellowfx.com/nonlagma-v7-1-mq4-indicator.htm#                              [NonLag Moving Average v7.1]
 * @link  https://www.mql5.com/en/forum/175037/page62#comment_4583907                           [NonLag Moving Average v7.8]
 * @link  https://www.mql5.com/en/forum/175037/page74#comment_4584032                           [NonLag Moving Average v7.9]
 */
bool NLMA.CalculateWeights(int cycles, int cyclePeriods, double &weights[]) {
   if (cycles < 1)       return(!catch("NLMA.CalculateWeights(1)  invalid parameter cycles: "+ cycles +" (must be positive)", ERR_INVALID_PARAMETER));
   if (cyclePeriods < 3) return(!catch("NLMA.CalculateWeights(2)  invalid parameter cyclePeriods: "+ cyclePeriods +" (min. 3)", ERR_INVALID_PARAMETER));

   int phase, weightsSize;
   double weightsSum, t, g, coeff;

   // version 4
   // -----------------------------------------------------------------------------------------------------------------------
   if (false) {
      coeff       = 3 * Math.PI;
      phase       = cyclePeriods - 1;
      weightsSize = cycles * cyclePeriods + phase;
      weightsSum  = 0;
      ArrayResize(weights, weightsSize);

      for (int i=0; i < weightsSize; i++) {
         if (t <= 0.5) g = 1;
         else          g = 1/(t*coeff + 1);

         weights[i]  = g * MathCos(t * Math.PI);
         weightsSum += weights[i];

         if      (t < 1)             t += 1/(phase-1.);
         else if (t < weightsSize-1) t += (2*cycles-1)/(cycles*cyclePeriods-1.);
      }
      //debug("NLMA.CalculateWeights(0.1)  NonLagMA("+ cyclePeriods +") v4.0: sum("+ weightsSum +") = "+ DoublesToStr(weights, NULL));
      // NonLagMA(6)  v4.0: sum(1.56062181) = {1.0, 0.70710678, 0.0, -0.08763704, -0.0959253, -0.04338164, 0.0207207, 0.05059994, 0.03542316, -0.0027554, -0.03091775, -0.0300689, -0.0060966, 0.018834, 0.02533148, 0.01095985, -0.01025884, -0.02076295, -0.01349385, 0.00380641, 0.0162859, 0.01443575, 0.00109969, -0.01194788, -0.01420379, -0.00473922, 0.00784281, 0.01308931, 0.0072752}
      // NonLagMA(20) v4.0: sum(5.48966689) = {1.0, 0.98480775, 0.93969262, 0.8660254, 0.76604444, 0.64278761, 0.5, 0.34202014, 0.17364818, -0.0, -0.02784614, -0.05059779, -0.06865128, -0.08233705, -0.09195789, -0.09781197, -0.1002063, -0.09946368, -0.0959253, -0.08539207, -0.07019297, -0.05190203, -0.03207693, -0.01219138, 0.00643026, 0.02267068, 0.03566516, 0.04483185, 0.04988502, 0.05083072, 0.04794554, 0.04174031, 0.03291146, 0.02228343, 0.0107463, -0.00080751, -0.01154314, -0.0207363, -0.02781609, -0.03239538, -0.03428728, -0.03350716, -0.03026079, -0.02492001, -0.01798805, -0.0100574, -0.00176336, 0.0062633, 0.01344122, 0.01927795, 0.02340141, 0.02558148, 0.0257406, 0.02395298, 0.020433, 0.01551393, 0.00961899, 0.00322686, -0.00316538, -0.00907943, -0.0140902, -0.01785508, -0.02013633, -0.02081487, -0.01989507, -0.01750023, -0.0138595, -0.00928751, -0.00415827, 0.00112449, 0.00615817, 0.01057122, 0.01404988, 0.01635977, 0.01736106, 0.01701612, 0.01538949, 0.0126401, 0.00900684, 0.00478846, 0.00031964, -0.00405506, -0.00800724, -0.01124889, -0.01355291, -0.01476864, -0.01483125, -0.01376448, -0.01167669, -0.00875069, -0.00522822, -0.00139035, 0.00246457, 0.00604378, 0.00908204, 0.01136098, 0.01272453, 0.01308931, 0.01244935}
      // NonLagMA(30) v4.0: sum(8.22442197) = {1.0, 0.99371221, 0.97492791, 0.94388333, 0.90096887, 0.8467242, 0.78183148, 0.70710678, 0.6234898, 0.53203208, 0.43388374, 0.33027906, 0.22252093, 0.11196448, 0.0, -0.01850962, -0.03484737, -0.04913268, -0.06146719, -0.07194109, -0.08063775, -0.08763704, -0.09301779, -0.09685945, -0.09924334, -0.10025335, -0.09997641, -0.09850264, -0.0959253, -0.09234062, -0.08450317, -0.07465457, -0.06325605, -0.05076921, -0.03764737, -0.02432672, -0.01121773, 0.00130284, 0.01289921, 0.02328268, 0.03221648, 0.03951927, 0.04506717, 0.04879419, 0.05069126, 0.0508037, 0.04922741, 0.04610383, 0.04161375, 0.03597038, 0.02941169, 0.02219237, 0.01457559, 0.00682479, -0.00080413, -0.00807027, -0.01475439, -0.0206647, -0.02564166, -0.02956165, -0.03233939, -0.03392922, -0.03432501, -0.03355896, -0.03169927, -0.0288467, -0.02513034, -0.02070257, -0.01573347, -0.01040489, -0.00490425, 0.00058152, 0.00587202, 0.01079885, 0.01521066, 0.01897751, 0.02199439, 0.02418389, 0.02549786, 0.02591819, 0.02545649, 0.02415298, 0.02207432, 0.01931082, 0.01597283, 0.01218665, 0.00808999, 0.00382724, -0.00045545, -0.00461496, -0.00851582, -0.01203441, -0.01506276, -0.01751171, -0.01931336, -0.02042282, -0.02081919, -0.02050562, -0.01950875, -0.01787726, -0.0156798, -0.01300231, -0.00994478, -0.00661768, -0.0031381, 0.0003743, 0.00380121, 0.00702965, 0.00995552, 0.01248692, 0.0145469, 0.01607577, 0.01703268, 0.01739666, 0.01716693, 0.0163625, 0.01502122, 0.01319815, 0.01096341, 0.00839959, 0.00559876, 0.00265926, -0.00031769, -0.00323142, -0.00598513, -0.00848908, -0.0106634, -0.01244065, -0.0137678, -0.01460781, -0.01494055, -0.01476321, -0.01409013, -0.01295203, -0.0113947, -0.00947727, -0.00726999, -0.00485173, -0.00230721, 0.00027596, 0.00281018, 0.00521087, 0.00739918, 0.00930461, 0.01086718, 0.01203934, 0.01278733, 0.01309215, 0.01294995}
   }

   // version 7.1 (updated weights calculation, nearly identical results)
   // -----------------------------------------------------------------------------------------------------------------------
   if (true) {
      coeff       = 3 * Math.PI;
      phase       = cyclePeriods - 1;
      weightsSize = cycles * cyclePeriods + phase;
      weightsSum  = 0;
      ArrayResize(weights, weightsSize);

      for (i=0; i < weightsSize; i++) {            // fixed a typo (the last weight was never calculated)
         if (i < phase) t = i/(phase-1.);
         else           t = 1 + (i-phase+1) * (2*cycles-1)/(cycles*cyclePeriods-1.);

         if (t <= 0.5 ) g = 1;
         else           g = 1/(t*coeff+1);

         weights[i]  = g * MathCos(t * Math.PI);
         weightsSum += weights[i];
      }
      //debug("NLMA.CalculateWeights(0.2)  NonLagMA("+ cyclePeriods +") v7.1: sum("+ weightsSum +") = "+ DoublesToStr(weights, NULL));
      // matches v4.0:      NonLagMA(6)  v7.1: sum(1.56062181) = {1.0, 0.70710678, 0.0, -0.08763704, -0.0959253, -0.04338164, 0.0207207, 0.05059994, 0.03542316, -0.0027554, -0.03091775, -0.0300689, -0.0060966, 0.018834, 0.02533148, 0.01095985, -0.01025884, -0.02076295, -0.01349385, 0.00380641, 0.0162859, 0.01443575, 0.00109969, -0.01194788, -0.01420379, -0.00473922, 0.00784281, 0.01308931, 0.0072752}
      // matches v4.0:      NonLagMA(20) v7.1: sum(5.48966689) = {1.0, 0.98480775, 0.93969262, 0.8660254, 0.76604444, 0.64278761, 0.5, 0.34202014, 0.17364818, 0.0, -0.02784614, -0.05059779, -0.06865128, -0.08233705, -0.09195789, -0.09781197, -0.1002063, -0.09946368, -0.0959253, -0.08539207, -0.07019297, -0.05190203, -0.03207693, -0.01219138, 0.00643026, 0.02267068, 0.03566516, 0.04483185, 0.04988502, 0.05083072, 0.04794554, 0.04174031, 0.03291146, 0.02228343, 0.0107463, -0.00080751, -0.01154314, -0.0207363, -0.02781609, -0.03239538, -0.03428728, -0.03350716, -0.03026079, -0.02492001, -0.01798805, -0.0100574, -0.00176336, 0.0062633, 0.01344122, 0.01927795, 0.02340141, 0.02558148, 0.0257406, 0.02395298, 0.020433, 0.01551393, 0.00961899, 0.00322686, -0.00316538, -0.00907943, -0.0140902, -0.01785508, -0.02013633, -0.02081487, -0.01989507, -0.01750023, -0.0138595, -0.00928751, -0.00415827, 0.00112449, 0.00615817, 0.01057122, 0.01404988, 0.01635977, 0.01736106, 0.01701612, 0.01538949, 0.0126401, 0.00900684, 0.00478846, 0.00031964, -0.00405506, -0.00800724, -0.01124889, -0.01355291, -0.01476864, -0.01483125, -0.01376448, -0.01167669, -0.00875069, -0.00522822, -0.00139035, 0.00246457, 0.00604378, 0.00908204, 0.01136098, 0.01272453, 0.01308931, 0.01244935}
      // differs from v4.0: NonLagMA(30) v7.1: sum(8.26643861) = {1.0, 0.99371221, 0.97492791, 0.94388333, 0.90096887, 0.8467242, 0.78183148, 0.70710678, 0.6234898, 0.53203208, 0.43388374, 0.33027906, 0.22252093, 0.11196448, 0.0, -0.01850962, -0.03484737, -0.04913268, -0.06146719, -0.07194109, -0.08063775, -0.08763704, -0.09301779, -0.09685945, -0.09924334, -0.10025335, -0.09997641, -0.09850264, -0.0959253, -0.08953068, -0.0808485, -0.07033578, -0.05845492, -0.04566531, -0.03241458, -0.01912982, -0.00620919, 0.00598587, 0.01713739, 0.02697657, 0.03528809, 0.04191303, 0.04675026, 0.04975638, 0.05094403, 0.05037896, 0.04817562, 0.04449167, 0.03952154, 0.0334891, 0.02663985, 0.0192328, 0.0115322, 0.00379944, -0.00371464, -0.01077687, -0.01717818, -0.02273892, -0.0273133, -0.03079254, -0.03310685, -0.03422616, -0.03415962, -0.0329539, -0.03069046, -0.02748174, -0.02346661, -0.01880511, -0.01367265, -0.00825402, -0.00273716, 0.00269287, 0.00785974, 0.01260119, 0.01677381, 0.02025708, 0.02295656, 0.02480618, 0.02576958, 0.02584039, 0.02504166, 0.0234243, 0.02106463, 0.0180613, 0.01453143, 0.01060638, 0.00642705, 0.00213909, -0.00211195, -0.00618544, -0.00995007, -0.01328797, -0.0160982, -0.01829971, -0.01983347, -0.02066394, -0.0207797, -0.02019326, -0.0189401, -0.01707706, -0.01467992, -0.01184054, -0.00866348, -0.00526228, -0.00175552, 0.00173719, 0.0050992, 0.00822058, 0.01100167, 0.01335613, 0.01521356, 0.01652152, 0.01724688, 0.0173766, 0.01691775, 0.01589691, 0.0143589, 0.01236498, 0.00999052, 0.00732218, 0.00445491, 0.00148859, -0.00147539, -0.00433748, -0.00700328, -0.00938662, -0.01141223, -0.01301813, -0.0141574, -0.01479957, -0.01493129, -0.01455656, -0.01369626, -0.01238722, -0.0106807, -0.00864049, -0.00634053, -0.00386234, -0.00129212, 0.00128216, 0.00377375, 0.0061, 0.00818505, 0.00996229, 0.01137642, 0.01238517, 0.01296049, 0.01308931, 0.01277374}
   }

   // version 7.8 and v7.9: the implementation is broken
   // -----------------------------------------------------------------------------------------------------------------------

   // normalize weights: sum = 1 (100%)
   for (i=0; i < weightsSize; i++) {
      weights[i] /= weightsSum;
   }

   return(!catch("NLMA.CalculateWeights(3)"));
}
