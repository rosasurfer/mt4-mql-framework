/**
 * Verbindet die Werte eines Double-Arrays mit bis zu 16 Nachkommastellen unter Verwendung des angegebenen Separators.
 *
 * @param  double values[]             - Array mit Ausgangswerten
 * @param  int    digits               - Anzahl der Nachkommastellen (0-16)
 * @param  string separator [optional] - zu verwendender Separator (default: ", ")
 *
 * @return string - resultierender String oder Leerstring, falls ein Fehler auftrat
 */
string JoinDoublesEx(double values[], int digits, string separator = ", ") {
   if (ArrayDimension(values) > 1) return(_EMPTY_STR(catch("JoinDoublesEx(1)  too many dimensions of parameter values: "+ ArrayDimension(values), ERR_INCOMPATIBLE_ARRAY)));
   if (digits < 0 || digits > 16)  return(_EMPTY_STR(catch("JoinDoublesEx(2)  illegal parameter digits: "+ digits, ERR_INVALID_PARAMETER)));

   string strings[];

   int size = ArraySize(values);
   ArrayResize(strings, size);

   for (int i=0; i < size; i++) {
      strings[i] = DoubleToStrEx(values[i], digits);
      if (!StringLen(strings[i]))
         return("");
   }

   string result = JoinStrings(strings, separator);

   if (ArraySize(strings) > 0)
      ArrayResize(strings, 0);

   return(result);
}
