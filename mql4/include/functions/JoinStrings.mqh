/**
 * Verbindet die Werte eines Stringarrays unter Verwendung des angegebenen Separators.
 *
 * @param  string values[]             - Array mit Ausgangswerten
 * @param  string separator [optional] - zu verwendender Separator (default: ", ")
 *
 * @return string - resultierender String oder Leerstring, falls ein Fehler auftrat
 */
string JoinStrings(string values[], string separator = ", ") {
   if (ArrayDimension(values) > 1) return(_EMPTY_STR(catch("JoinStrings(1)  too many dimensions of parameter values: "+ ArrayDimension(values), ERR_INCOMPATIBLE_ARRAYS)));

   string result = "";
   int size = ArraySize(values);

   for (int i=0; i < size; i++) {
      if (StrIsNull(values[i])) result = StringConcatenate(result, "NULL",    separator);
      else                      result = StringConcatenate(result, values[i], separator);
   }
   if (size > 0)
      result = StrLeft(result, -StringLen(separator));

   return(result);
}
