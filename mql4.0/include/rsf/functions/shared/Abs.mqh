/**
 * Returns the absolute value of an integer. Integer-Version von MathAbs().
 *
 * @param  int  value
 *
 * @return int
 */
int Abs(int value) {
   if (value == INT_MIN) return(INT_MAX);
   if (value < 0)        return(-value);
   return(value);
}
