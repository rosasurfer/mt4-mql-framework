/**
 * Pad a string right-side to a minimum length using a pad string.
 *
 * @param  string str                  - source string
 * @param  int    padLength            - minimum length of the resulting string
 * @param  string padString [optional] - substring used for padding (default: space chars)
 *
 * @return string
 */
string StrPadRight(string str, int padLength, string padString = " ") {
   while (StringLen(str) < padLength) {
      str = StringConcatenate(str, padString);
   }
   return(str);
}
