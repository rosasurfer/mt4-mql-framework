/**
 * Return the left part of a string.
 *
 * If 'n' is positive the function returns the 'n' left-most chars of the string.
 *   e.g.  StrLeft("ABCDEFG", 2) => "AB"
 *
 * If 'n' is negative the function returns all except the 'n' right-most chars of the string.
 *   e.g.  StrLeft("ABCDEFG", -2) => "ABCDE"
 *
 * @param  string str - string to process
 * @param  int    n
 *
 * @return string
 */
string StrLeft(string str, int n) {
   if (n > 0) return(StrSubstr(str, 0, n));
   if (n < 0) return(StrSubstr(str, 0, StringLen(str)+n));
   return("");
}
