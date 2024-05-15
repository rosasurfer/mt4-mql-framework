/**
 * Drop-in replacement for the badly designed built-in function StringSubstr().
 * Fix for StringSubstr(string, start, length = 0) in which case the built-in function returns the whole string.
 *
 * Additionally this implementation supports negative values for parameters "start" and "length".
 *
 * @param  string str    - string to process
 * @param  int    start  - start offset; if negative counted from the end of the string
 * @param  int    length - number of chars to return:
 *                         if positive chars on the right side of the start offset
 *                         if negative chars on the left side of the start offset
 * @return string
 */
string StrSubstr(string str, int start, int length = INT_MAX) {
   if (length == 0) return("");        // return an empty string if length is zero

   int _start = start;
   if (_start < 0) _start = Max(0, _start + StringLen(str));

   if (length < 0) {
      _start += 1 + length;
      length = Abs(length);
   }

   if (length == INT_MAX) {
      length = INT_MAX - _start;       // _start + length must not be larger than INT_MAX
   }

   return(StringSubstr(str, _start, length));
}
