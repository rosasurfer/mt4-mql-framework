/**
 * @source  Boris Armenteros [https://www.mql5.com/en/code/10188]
 */
#property indicator_separate_window
#property indicator_buffers   1
#property indicator_color1    Red


extern int  ERperiod  = 10;            // Efficiency ratio period: should be > 0. If not it will be autoset to default value
extern bool histogram = false;         // TRUE - histogram style on; FALSE - histogram style off
extern int  shift     = 0;             // Sets offset


double KVBfr[];


/**
 *
 */
int init() {
   // checking inputs
   if (ERperiod <= 0) {
      ERperiod = 10;
      Alert("ERperiod readjusted");
   }

   // drawing settings
   if (!histogram) SetIndexStyle(0, DRAW_LINE     );
   else            SetIndexStyle(0, DRAW_HISTOGRAM);
   SetIndexLabel(0, "KVolatility");
   SetIndexShift(0, shift);

   IndicatorDigits(Digits);
   IndicatorShortName("KVolatility("+ ERperiod +")");

   // mapping
   SetIndexBuffer(0, KVBfr);
   return(0);
}


/**
 *
 */
int start() {
   // optimization
   if (Bars < ERperiod+2) return(0);

   int counted_bars = IndicatorCounted();
   if (counted_bars < 0) return(-1);
   if (counted_bars > 0) counted_bars--;

   int limit  = Bars - counted_bars - 1;
   int maxbar = Bars - ERperiod - 1;
   if (limit > maxbar) limit = maxbar;

   double noise;

   // main cycle
   for (int i=limit; i >= 0; i--) {
      noise = Volatility(i);
      if (noise == EMPTY_VALUE) continue;
      KVBfr[i] = noise;
   }
   return(0);
}


/**
 *
 */
double Volatility(int bar) {
   if (bar > Bars-ERperiod-1)
      return(EMPTY_VALUE);
   double v = 0;

   for (int i=0; i < ERperiod; i++) {
      v += MathAbs(Close[bar+i] - Close[bar+i+1]);
   }
   return(v);
}

