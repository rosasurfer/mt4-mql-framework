/**
 * Verbindet die Werte eines Double-Arrays unter Verwendung des angegebenen Separators.
 *
 * @param  double values[]             - Array mit Ausgangswerten
 * @param  string separator [optional] - zu verwendender Separator (default: ", ")
 *
 * @return string - resultierender String oder Leerstring, falls ein Fehler auftrat
 */
string JoinDoubles(double values[], string separator = ", ") {
   if (ArrayDimension(values) > 1) return(_EMPTY_STR(catch("JoinDoubles(1)  too many dimensions of parameter values: "+ ArrayDimension(values), ERR_INCOMPATIBLE_ARRAY)));

   string strings[];

   int size = ArraySize(values);
   ArrayResize(strings, size);

   for (int i=0; i < size; i++) {
      if      (values[i] == EMPTY_VALUE) strings[i] = "EMPTY_VALUE";
      else if (values[i] == INT_MIN)     strings[i] = "INT_MIN";
      else                               strings[i] = NumberToStr(values[i], ".1+");
   }

   string result = JoinStrings(strings, separator);

   if (ArraySize(strings) > 0) {
      ArrayResize(strings, 0);
   }
   return(result);
}
