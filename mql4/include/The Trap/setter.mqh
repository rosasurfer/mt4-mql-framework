/**
 * Set sequence.pl, sequence.plMin and sequence.plMax and update their string representations.
 *
 * @param  double
 *
 * @return double - the same value
 */
double SetSequencePL(double value) {
   if (sequence.pl != value) {
      sequence.pl = value;

      bool newMin=false, newMax=false;

      if (value < sequence.plMin || sequence.plMin==EMPTY_VALUE) { sequence.plMin = value; newMin = true; }
      if (value > sequence.plMax || sequence.plMax==EMPTY_VALUE) { sequence.plMax = value; newMax = true; }

      if (__CHART) {
         if (value == EMPTY_VALUE) {
            str.sequence.pl    = "-";
            str.sequence.plMin = "-";
            str.sequence.plMax = "-";
         }
         else {
                        str.sequence.pl    = DoubleToStr(sequence.pl,    2);
            if (newMin) str.sequence.plMin = DoubleToStr(sequence.plMin, 2);
            if (newMax) str.sequence.plMax = DoubleToStr(sequence.plMax, 2);
         }
      }
   }
   return(value);
}


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
