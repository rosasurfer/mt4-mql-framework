/**
 * Set long.tpCompensation and update the modified range's string representation.
 *
 * @param  double
 *
 * @return double - the same value
 */
double SetLongTPCompensation(double value) {
   if (long.tpCompensation != value) {
      long.tpCompensation = value;

      if (__CHART) {
         if (long.tpCompensation==EMPTY_VALUE && short.tpCompensation==EMPTY_VALUE) {
            str.range.tpCompensation = "";
         }
         else {
            string sLong  = "+"+ ifString(long.tpCompensation ==EMPTY_VALUE, "0.0", DoubleToStr(RoundCeil(long.tpCompensation,  1), 1));
            string sShort = "+"+ ifString(short.tpCompensation==EMPTY_VALUE, "0.0", DoubleToStr(RoundCeil(short.tpCompensation, 1), 1));
            str.range.tpCompensation = sLong +"/"+ sShort;
         }
      }
   }
   return(value);
}


/**
 * Set short.tpCompensation and update the modified range's string representation.
 *
 * @param  double
 *
 * @return double - the same value
 */
double SetShortTPCompensation(double value) {
   if (short.tpCompensation != value) {
      short.tpCompensation = value;

      if (__CHART) {
         if (long.tpCompensation==EMPTY_VALUE && short.tpCompensation==EMPTY_VALUE) {
            str.range.tpCompensation = "";
         }
         else {
            string sLong  = "+"+ ifString(long.tpCompensation ==EMPTY_VALUE, "0.0", DoubleToStr(RoundCeil(long.tpCompensation,  1), 1));
            string sShort = "+"+ ifString(short.tpCompensation==EMPTY_VALUE, "0.0", DoubleToStr(RoundCeil(short.tpCompensation, 1), 1));
            str.range.tpCompensation = sLong +"/"+ sShort;
         }
      }
   }
   return(value);
}
