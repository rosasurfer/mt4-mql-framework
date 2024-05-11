/**
 * Trim white space characters from both sides of a string.
 *
 * @param  string str
 *
 * @return string - trimmed string
 */
string StrTrim(string str) {
   return(StringTrimLeft(StringTrimRight(str)));
}
