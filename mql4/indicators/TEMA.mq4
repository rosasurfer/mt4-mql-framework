/**
 * Triple EMA
 *
 *
 * @see  https://www.tradingtechnologies.com/help/x-study/technical-indicator-definitions/triple-exponential-moving-average-tema/
 */

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern int EMA_period = 38;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#property indicator_chart_window

#property indicator_buffers 1

#property indicator_color1  Blue
#property indicator_width1  2

double bufferEMA1[];
double bufferEMA2[];
double bufferEMA3[];
double bufferTEMA[];


/**
 * Initialization
 *
 * @return int - error status
 */
int init() {
   IndicatorBuffers(4);
   SetIndexStyle (0, DRAW_LINE );
   SetIndexBuffer(0, bufferTEMA);
   SetIndexBuffer(1, bufferEMA1);
   SetIndexBuffer(2, bufferEMA2);
   SetIndexBuffer(3, bufferEMA3);

   IndicatorShortName("TEMA("+ EMA_period +")");
   return(0);
}


/**
 * Main function
 *
 * @return int - error status
 */
int start() {
   int i, limit1, limit2, limit3, counted_bars = IndicatorCounted();

   if (!counted_bars) {
      limit1 = Bars - 1;
      limit2 = limit1 - EMA_period;
      limit3 = limit2 - EMA_period;
   }

   if (counted_bars > 0) {
      limit1 = Bars - counted_bars - 1;
      limit2 = limit1;
      limit3 = limit2;
   }

   for (i=limit1; i >= 0; i--) bufferEMA1[i] =        iMA(NULL, 0,                 EMA_period, 0, MODE_EMA, PRICE_CLOSE, i);
   for (i=limit2; i >= 0; i--) bufferEMA2[i] = iMAOnArray(bufferEMA1, WHOLE_ARRAY, EMA_period, 0, MODE_EMA,              i);
   for (i=limit3; i >= 0; i--) bufferEMA3[i] = iMAOnArray(bufferEMA2, WHOLE_ARRAY, EMA_period, 0, MODE_EMA,              i);

   for (i=limit3; i >= 0; i--) bufferTEMA[i] = 3*bufferEMA1[i] - 3*bufferEMA2[i] + bufferEMA3[i];

   return(0);
}
