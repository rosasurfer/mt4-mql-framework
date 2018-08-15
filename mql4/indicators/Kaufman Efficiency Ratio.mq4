/**
 * @source  Boris Armenteros [https://www.mql5.com/en/code/10187]
 */
#property indicator_separate_window
#property indicator_minimum   0
#property indicator_maximum   1
#property indicator_buffers   1
#property indicator_color1    Red


extern int  ERperiod  = 10;                  // Efficiency ratio period; should be > 0. If not it will be autoset to default value
extern bool histogram = false;               // TRUE - histogram style on; FALSE - histogram style off
extern int  shift     = 0;                   // Sets offset


double ERBfr[];


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
   SetIndexLabel(0, "KEffRatio");
   SetIndexShift(0, shift);

   IndicatorDigits(Digits);
   IndicatorShortName("KEffRatio("+ ERperiod +")");

   // mapping
   SetIndexBuffer(0, ERBfr);
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

   double direction, noise;

   // main cycle
   for (int i=limit; i >= 0; i--) {
      direction = NetPriceMovement(i);
      noise     = Volatility(i);
      if (direction==EMPTY_VALUE || noise==EMPTY_VALUE) continue;
      if (!noise) noise = 0.000000001;
      ERBfr[i] = direction/noise;
   }
   return(0);
}


/**
 *
 */
double NetPriceMovement(int bar) {
   if (bar > Bars-ERperiod-1)
      return(EMPTY_VALUE);
   return(MathAbs(Close[bar]-Close[bar+ERperiod]));
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

