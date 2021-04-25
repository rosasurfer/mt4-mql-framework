/**
 * Berechnet die Gewichtungen eines ALMAs.
 *
 * @param  double weights[]         - Array zur Aufnahme der Gewichtungen
 * @param  int    periods           - Anzahl der Perioden des ALMA
 * @param  double offset [optional] - Offset der Gauﬂ'schen Normalverteilung (default: 0.85)
 * @param  double sigma  [optional] - Steilheit der Gauﬂ'schen Normalverteilung (default: 6.0)
 *
 * @link  http://web.archive.org/web/20180307031850/http://www.arnaudlegoux.com/
 * @see   "/etc/doc/alma/ALMA Weighted Distribution.xls"
 */
void @ALMA.CalculateWeights(double &weights[], int periods, double offset=0.85, double sigma=6.0) {
   if (periods <= 0) {
      catch("@ALMA.CalculateWeights(1)  illegal parameter periods = "+ periods, ERR_INVALID_PARAMETER);
      return;
   }
   if (ArraySize(weights) != periods) {
      ArrayResize(weights, periods);
   }

   double dist = (periods-1) * offset;                      // m: Abstand des Scheitelpunkts der Glocke von der ‰ltesten Bar; im Original floor(value)
   double s    = periods / sigma;                           // s: Steilheit der Glocke
   double weightsSum;

   for (int j, i=0; i < periods; i++) {
      j = periods-1-i;
      weights[j]  = MathExp(-(i-dist)*(i-dist)/(2*s*s));
      weightsSum += weights[j];
   }
   for (i=0; i < periods; i++) {
      weights[i] /= weightsSum;                             // Summe der Gewichtungen aller Bars = 1 (100%)
   }
}
