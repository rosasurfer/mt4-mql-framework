/**
 * MetaQuotes-Aliase
 */


/**
 *
 */
bool CompareDoubles(double double1, double double2) {
   // Die MetaQuotes-Funktion ist fehlerhaft.
   return(EQ(double1, double2));
}


/**
 *
 */
string DoubleToStrMorePrecision(double value, int precision) {
   return(DoubleToStrEx(value, precision));
}


/**
 *
 */
string IntegerToHexString(int integer) {
   return(IntToHexStr(integer));
}
