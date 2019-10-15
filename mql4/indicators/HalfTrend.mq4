/**
 * HalfTrend indicator
 */
#property indicator_chart_window
#property indicator_buffers 2

#property indicator_color1  DodgerBlue    // up[]
#property indicator_width1  2
#property indicator_color2  Red           // down[]
#property indicator_width2  2

extern int  Periods  = 2;
extern bool ShowBars = true;

double minHigh, maxLow;
double up[], down[], trend[];

#define TREND_UP    1
#define TREND_DOWN  0


/**
 *
 */
int init() {
   IndicatorBuffers(5);

   SetIndexBuffer(0, up  );  SetIndexEmptyValue(0, 0); SetIndexStyle(0, DRAW_LINE);
   SetIndexBuffer(1, down);  SetIndexEmptyValue(1, 0); SetIndexStyle(1, DRAW_LINE);
   SetIndexBuffer(2, trend); SetIndexEmptyValue(2, 0);

   minHigh = High[Bars-1];
   maxLow  = Low [Bars-1];
   return(0);
}


/**
 *
 */
int start() {

   for (int i=Bars-1; i>=0; i--) {
      double high   = iHigh(NULL, NULL, iHighest(NULL, NULL, MODE_HIGH, Periods, i));
      double low    = iLow (NULL, NULL,  iLowest(NULL, NULL, MODE_LOW,  Periods, i));
      double maHigh = iMA(NULL, NULL, Periods, 0, MODE_SMA, PRICE_HIGH, i);
      double maLow  = iMA(NULL, NULL, Periods, 0, MODE_SMA, PRICE_LOW,  i);

      trend[i] = trend[i+1];

      if (trend[i+1] == TREND_UP) {
         minHigh = MathMin(minHigh, high);
         if (maLow > minHigh && Close[i] > High[i+1]) {
            trend[i] = TREND_DOWN;
            maxLow   = low;
         }
      }
      else /* trend[i+1] == TREND_DOWN */ {
         maxLow = MathMax(maxLow, low);
         if (maHigh < maxLow && Close[i] < Low[i+1]) {
            trend[i] = TREND_UP;
            minHigh  = high;
         }
      }

      if (trend[i] == TREND_UP) {
         if (trend[i+1] == TREND_DOWN) {
            down[i]   = up[i+1];
            down[i+1] = down[i];
         }
         else {
            down[i] = MathMin(minHigh, down[i+1]);
         }
         up[i] = 0;
      }
      else /* trend[i] == TREND_DOWN */ {
         if (trend[i+1] == TREND_UP) {
            up[i]   = down[i+1];
            up[i+1] = up[i];
         }
         else {
            up[i] = MathMax(maxLow, up[i+1]);
         }
         down[i] = 0;
      }
   }
   return(0);
}
