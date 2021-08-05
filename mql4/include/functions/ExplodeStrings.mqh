/**
 * Convert a memory buffer containing null terminated strings into an MQL string array. Conversion stops when the end of the
 * buffer is reached or a string terminator is followed by a second null character, whichever comes first. The resulting MQL
 * string array will always contain at least one (possibly empty) string element.
 *
 * @param  int    buffer[]  - memory buffer containing null terminated strings
 * @param  string results[] - resulting MQL string array
 *
 * @return int - number of converted string elements (at least one) or NULL in case of errors
 */
int ExplodeStrings(int buffer[], string &results[]) {
   string sValue = "";
   int resultsSize = ArrayResize(results, 0);
   int length;
   int fromAddr = GetIntsAddress(buffer);                // memory start address
   int toAddr   = fromAddr + ArraySize(buffer)*4;        // first address after memory end address (must not be accessed)

   for (int addr=fromAddr; addr < toAddr; addr+=(length+1)) {
      sValue = GetStringA(addr);
      length = StringLen(sValue);

      if (!length && resultsSize)
         break;

      resultsSize            = ArrayResize(results, resultsSize+1);
      results[resultsSize-1] = StringSubstr(sValue, 0, toAddr-addr);
   }

   if (!catch("ExplodeStrings(1)"))
      return(resultsSize);
   return(0);
}
