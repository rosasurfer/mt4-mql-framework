/**
 * Fractal Dimension Index
 *
 * @source  https://www.mql5.com/en/code/7758                                    [iliko]
 * @see     https://www.forexfactory.com/showthread.php?p=11504048#post11504048  [source: JohnLast]
 */


/*
@see  https://www.tradingview.com/script/GyR8LJq0-Fractal-Dimension-Index-FDI/

int    Periods   = 30;
double rangeHigh = highest(Close, Periods);
double rangeLow  = lowest(Close, Periods);

double length = 0;

for (int i=1; i <= Periods-1, i++) {
    double diff = (Close[i]-rangeLow) / (rangeHigh-rangeLow);
    length     += Sqrt(Pow(diff[i]-diff[i+1], 2) + (1/Pow(Periods, 2)));
}

double FDI = 1 + (log(length)+log(2)) / log(2*Periods);
*/


// @source  https://www.mql5.com/en/code/7758
//+------------------------------------------------------------------------------------------------------------------+
//|                                                                              fractal_dimension.mq4               |
//|                                                                              iliko [arcsin5@netscape.net]        |
//|                                                                                                                  |
//|                                                                                                                  |
//|  The Fractal Dimension Index determines the amount of market volatility. The easiest way to use this indicator is|
//|  to understand that a value of 1.5 suggests the market is acting in a completely random fashion.                 |
//|  As the market deviates from 1.5, the opportunity for earning profits is increased in proportion                 |
//|  to the amount of deviation.                                                                                     |
//|  But be carreful, the indicator does not show the direction of trends !!                                         |
//|                                                                                                                  |
//|  The indicator is RED when the market is in a trend. And it is blue when there is a high volatility.             |
//|  When the FDI changes its color from red to blue, it means that a trend is finishing, the market becomes         |
//|  erratic and a high volatility is present. Usually, these "blue times" do not go for a long time.They come before|
//|  a new trend.                                                                                                    |
//|                                                                                                                  |
//|  For more informations, see                                                                                      |
//|  http://www.forex-tsd.com/suggestions-trading-systems/6119-tasc-03-07-fractal-dimension-index.html               |
//|                                                                                                                  |
//|                                                                                                                  |
//|  HOW TO USE INPUT PARAMETERS :                                                                                   |
//|  -----------------------------                                                                                   |
//|                                                                                                                  |
//|      1) e_period [ integer >= 1 ]                                              =>  30                            |
//|                                                                                                                  |
//|         The indicator will compute the historical market volatility over this period.                            |
//|         Choose its value according to the average of trend lengths.                                              |
//|                                                                                                                  |
//|      2) e_type_data [ int = {PRICE_CLOSE = 0,                                                                    |
//|                              PRICE_OPEN  = 1,                                                                    |
//|                              PRICE_HIGH  = 2,                                                                    |
//|                              PRICE_LOW   = 3,                                                                    |
//|                              PRICE_MEDIAN    (high+low)/2              = 4,                                      |
//|                              PRICE_TYPICAL   (high+low+close)/3        = 5,                                      |
//|                              PRICE_WEIGHTED  (high+low+close+close)/4  = 6}     => PRICE_CLOSE                   |
//|                                                                                                                  |
//|         Defines on which price type the Fractal Dimension is computed.                                           |
//|                                                                                                                  |
//|      3) e_random_line [ 0.0 < double < 2.0 ]                                   => 1.5                            |
//|                                                                                                                  |
//|         Defines your separation betwen a trend market (red) and an erratic/high volatily one.                    |
//|                                                                                                                  |
//| v1.0 - February 2007                                                                                            |
//+------------------------------------------------------------------------------------------------------------------+
#property indicator_separate_window
#property indicator_levelcolor LimeGreen
#property indicator_levelwidth 1
#property indicator_levelstyle STYLE_DASH
#property indicator_buffers 2
#property indicator_color1 Blue
#property indicator_color2 Red
#property indicator_width1 2
#property indicator_width2 2

// input parameters
extern int    e_period      = 30;
extern int    e_type_data   = PRICE_CLOSE;
extern double e_random_line = 1.5;              // Indicator triggering is defined by the value of the following input parameter:

double LOG_2;

double ExtInputBuffer[];         // input buffer
double ExtOutputBufferUp[];      // output buffer
double ExtOutputBufferDown[];

int g_period_minus_1;


/**
 * Initialization
 *
 * @return int - error status
 */
int init() {
   // Check e_period input parameter
   if (e_period < 2) {
      Alert("input parameter e_period must be >= 1 ("+ e_period +")");
      return(-1);
   }
   if (e_type_data < PRICE_CLOSE || e_type_data > PRICE_WEIGHTED) {
      Alert("input parameter e_type_data unknown ("+ e_type_data +")");
      return(-1);
   }
   if (e_random_line < 0 || e_random_line > 2) {
      Alert("input parameter e_random_line = " +e_random_line +" out of range (0.0 < e_random_line < 2.0)");
      return(-1);
   }
   IndicatorBuffers(3);
   SetIndexBuffer(0, ExtOutputBufferUp  ); SetIndexStyle(0, DRAW_LINE, STYLE_SOLID, 2); SetIndexLabel(0, "FDI"); SetIndexDrawBegin(0, 2*e_period);
   SetIndexBuffer(1, ExtOutputBufferDown); SetIndexStyle(1, DRAW_LINE, STYLE_SOLID, 2);
   SetIndexBuffer(2, ExtInputBuffer     );

   SetLevelValue(0,e_random_line);
   IndicatorShortName("FDI");
   g_period_minus_1 = e_period-1;
   LOG_2 = MathLog(2.0);

   return(0);
}


/**
 * Main function
 *
 * @return int - error status
 */
int start() {
   int counted_bars = IndicatorCounted();
   if (counted_bars > 0) counted_bars--;

   int limit = Bars-counted_bars;
   if (!counted_bars) limit -= 1+e_period;

   computeLastNbBars(limit);
   return(0);
}


/**
 * @param int lastBars - these "n" last bars must be repainted
 */
void computeLastNbBars(int lastBars) {
   int pos;
   double tmp_close[], tmp_open[], tmp_high[], tmp_low[];

   ArrayCopy(tmp_open,  Open );
   ArrayCopy(tmp_high,  High );
   ArrayCopy(tmp_low,   Low  );
   ArrayCopy(tmp_close, Close);

   switch (e_type_data) {
      case PRICE_OPEN : computeFdi(lastBars, tmp_open ); break;
      case PRICE_HIGH : computeFdi(lastBars, tmp_high ); break;
      case PRICE_LOW  : computeFdi(lastBars, tmp_low  ); break;
      case PRICE_CLOSE: computeFdi(lastBars, tmp_close); break;

      case PRICE_MEDIAN:
         for (pos=lastBars; pos >= 0; pos--) {
            ExtInputBuffer[pos] = (tmp_high[pos]+tmp_low[pos]) / 2;
         }
         computeFdi(lastBars, ExtInputBuffer);
         break;

      case PRICE_TYPICAL:
         for (pos=lastBars; pos >= 0; pos--) {
            ExtInputBuffer[pos] = (tmp_high[pos]+tmp_low[pos]+tmp_close[pos]) / 3;
         }
         computeFdi(lastBars, ExtInputBuffer);
         break;

      case PRICE_WEIGHTED:
         for (pos=lastBars; pos >= 0; pos--) {
            ExtInputBuffer[pos] = (tmp_high[pos]+tmp_low[pos]+tmp_close[pos]+tmp_close[pos]) / 4;
         }
         computeFdi(lastBars, ExtInputBuffer);
         break;

      default :
         Alert("input parameter e_type_data "+ e_type_data +" is unknown");
   }
}


/**
 * Compute FDI values from input data.
 *
 * @param int    lastBars  - these "n" last bars must be repainted
 * @param double inputData - data array on which the FDI will be applied
 *
 */
void computeFdi(int lastBars, double inputData[]) {
   double diff, priorDiff, length, priceMax, priceMin, fdi;

   for (int pos=lastBars; pos >= 0; pos--) {
      priceMax = highest(e_period, pos, inputData);
      priceMin = lowest (e_period, pos, inputData);
      length   = 0;
      priorDiff = 0;

      for (int iteration=0; iteration < g_period_minus_1; iteration++) {
         if (priceMax-priceMin > 0) {
            diff = (inputData[pos+iteration]-priceMin) / (priceMax-priceMin);
            if (iteration > 0) {
               length += MathSqrt(MathPow(diff-priorDiff, 2) + 1/MathPow(e_period, 2));
            }
            priorDiff = diff;
         }
      }

      if (length > 0) {
         fdi = 1 + (MathLog(length)+LOG_2) / MathLog(2*e_period);
      }
      else {
         // The FDI algorithm suggests a zero value. I prefer to use the previous FDI value.
         fdi = 0;
      }

      if (fdi > e_random_line) {
         ExtOutputBufferUp  [pos]   = fdi;
         ExtOutputBufferUp  [pos+1] = MathMin(ExtOutputBufferUp[pos+1], ExtOutputBufferDown[pos+1]);
         ExtOutputBufferDown[pos]   = EMPTY_VALUE;
      }
      else {
         ExtOutputBufferDown[pos]   = fdi;
         ExtOutputBufferDown[pos+1] = MathMin(ExtOutputBufferUp[pos+1], ExtOutputBufferDown[pos+1]);
         ExtOutputBufferUp  [pos]   = EMPTY_VALUE;
      }
   }
}


/**
 * Search for the highest value in an array data
 *
 * @param int    n         - find the highest on these n data
 * @param int    pos       - begin to search for from this index
 * @param double inputData - data array on which the searching for is done
 *
 * @return double - the highest value
 */
double highest(int n, int pos, double inputData[]) {
   int length = pos+n;
   double highest = 0;

   for (int i=pos; i<length; i++) {
      if (inputData[i] > highest) highest = inputData[i];
   }
   return(highest);
}


/**
 * Search for the lowest value in an array data
 *
 * @param int    n         - find the lowest on these n data
 * @param int    pos       - begin to search for from this index
 * @param double inputData - data array on which the searching for is done
 *
 * @return double - the lowest value
 */
double lowest(int n, int pos, double inputData[]) {
   int length = pos+n;
   double lowest = 9999999999;

   for (int i=pos; i<length; i++) {
      if (inputData[i] < lowest) lowest = inputData[i];
   }
   return(lowest);
}

