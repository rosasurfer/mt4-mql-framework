/**
 * Redefine the originally distributed MetaQuotes functions so they exist in case somebody wants to use them.
 */


/**
 * Compare two doubles for "equality".
 *
 * @param  double a - first value
 * @param  double b - second value
 *
 * @return bool
 */
bool CompareDoubles(double a, double b) {
   return(EQ(a, b));
}


/**
 * Convert a double to a string with up to 16 decimal digits.
 *
 * @param  double value     - value
 * @param  int    precision - number of decimals
 *
 * @return string
 */
string DoubleToStrMorePrecision(double value, int precision) {
   return(DoubleToStrEx(value, precision));
}


/**
 * Return the hexadecimale representation of an integer.
 *  e.g. IntegerToHexString(13465610) => "00CD780A"
 *
 * @param  int value - 4 byte integer value
 *
 * @return string - 8 character string value
 */
string IntegerToHexString(int integer) {
   return(IntToHexStr(integer));
}
