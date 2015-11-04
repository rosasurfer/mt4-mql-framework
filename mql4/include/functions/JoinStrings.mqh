/**
 * Verbindet die Werte eines Stringarrays unter Verwendung des angegebenen Separators.
 *
 * @param  string values[]  - Array mit Ausgangswerten
 * @param  string separator - zu verwendender Separator
 *
 * @return string - resultierender String oder Leerstring, falls ein Fehler auftrat
 */
string JoinStrings(string values[], string separator) {
   if (ArrayDimension(values) > 1)
      return(_EMPTY_STR(catch("JoinStrings(1)  too many dimensions of parameter values = "+ ArrayDimension(values), ERR_INCOMPATIBLE_ARRAYS)));

   string value, result="";
   int    error, size=ArraySize(values);

   for (int i=0; i < size; i++) {
      value = values[i];                                             // NPE provozieren

      error = GetLastError();
      if (!error) {
         result = StringConcatenate(result, value, separator);
         continue;
      }
      if (error != ERR_NOT_INITIALIZED_ARRAYSTRING)
         return(_EMPTY_STR(catch("JoinStrings(2)", error)));

      result = StringConcatenate(result, "NULL", separator);         // NULL
   }
   if (size > 0)
      result = StringLeft(result, -StringLen(separator));

   return(result);
}