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

#define TREND_UP    0
#define TREND_DOWN  1


/**
 *
 */
int init() {
   IndicatorBuffers(3);
   SetIndexBuffer(0, up);    SetIndexEmptyValue(0, 0); SetIndexStyle(0, DRAW_LINE);
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
      double maHighs     = iMA(NULL, NULL, Periods, 0, MODE_SMA, PRICE_HIGH, i);
      double maLows      = iMA(NULL, NULL, Periods, 0, MODE_SMA, PRICE_LOW,  i);
      double highestHigh = iHigh(NULL, NULL, iHighest(NULL, NULL, MODE_HIGH, Periods, i));
      double lowestLow   = iLow (NULL, NULL, iLowest (NULL, NULL, MODE_LOW,  Periods, i));

      trend[i] = trend[i+1];

      // trend calculation
      if (trend[i+1] == TREND_UP) {
         maxLow = MathMax(maxLow, lowestLow);
         if (maHighs < maxLow && Close[i] < Low[i+1]) {
            trend[i] = TREND_DOWN;
            minHigh  = highestHigh;
         }
      }
      else /* trend[i+1] == TREND_DOWN */ {
         minHigh = MathMin(minHigh, highestHigh);
         if (maLows > minHigh && Close[i] > High[i+1]) {
            trend[i] = TREND_UP;
            maxLow   = lowestLow;
         }
      }

      // visualization + coloring
      if (trend[i] == TREND_UP) {
         if (trend[i+1] == TREND_DOWN) {
            up[i]   = down[i+1];
            up[i+1] = up[i];
         }
         else {
            up[i] = MathMax(maxLow, up[i+1]);
         }
         down[i] = 0;
      }
      else /* trend[i] == TREND_DOWN */ {
         if (trend[i+1] == TREND_UP) {
            down[i]   = up[i+1];
            down[i+1] = down[i];
         }
         else {
            down[i] = MathMin(minHigh, down[i+1]);
         }
         up[i] = 0;
      }
   }
   return(0);
}
