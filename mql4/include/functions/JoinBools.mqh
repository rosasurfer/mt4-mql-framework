/**
 * Verbindet die Werte eines Boolean-Arrays unter Verwendung des angegebenen Separators.
 *
 * @param  bool   values[]             - Array mit Ausgangswerten
 * @param  string separator [optional] - zu verwendender Separator (default: ", ")
 *
 * @return string - resultierender String oder Leerstring, falls ein Fehler auftrat
 */
string JoinBools(bool values[], string separator = ", ") {
   if (ArrayDimension(values) > 1) return(_EMPTY_STR(catch("JoinBools(1)  too many dimensions of parameter values: "+ ArrayDimension(values), ERR_INCOMPATIBLE_ARRAYS)));

   string strings[];

   int size = ArraySize(values);
   ArrayResize(strings, size);

   for (int i=0; i < size; i++) {
      if (values[i]) strings[i] = "true";
      else           strings[i] = "false";
   }

   string result = JoinStrings(strings, separator);

   if (ArraySize(strings) > 0)
      ArrayResize(strings, 0);

   return(result);
}
