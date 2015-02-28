/**
 * MetaQuotes-Aliase
 */


/**
 * Die MetaQuotes-Funktion ist fehlerhaft.
 */
bool CompareDoubles(double double1, double double2) {
   return(EQ(double1, double2));

   DoubleToStrMorePrecision(NULL, NULL);
   IntegerToHexString(NULL);
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
