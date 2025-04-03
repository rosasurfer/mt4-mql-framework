/**
 * Returns the largest of the specified integer values. Integer version of MathMax().
 *
 * @param  int a
 * @param  int b
 * @param  int c [optional]
 *
 * @return int
 */
int Max(int a, int b, int c = INT_MIN) {
   int result = a;
   if (b > result) result = b;
   if (c > result) result = c;
   return(result);
}
