/**
 * Returns the smallest of the specified integer values. Integer version of MathMin().
 *
 * @param  int a
 * @param  int b
 * @param  int c [optional]
 *
 * @return int
 */
int Min(int a, int b, int c = INT_MAX) {
   int result = a;
   if (b < result) result = b;
   if (c < result) result = c;
   return(result);
}
