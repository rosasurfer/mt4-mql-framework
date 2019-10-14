/**
 * HalfTrend-v1.02.mq4
 * Copyright 2014, FxProSystems.com
 * Based on Ozymandias.mq4
 */
#property indicator_chart_window
#property indicator_buffers 4

#property indicator_color1 DodgerBlue     // up[]
#property indicator_width1 2
#property indicator_color2 Red            // down[]
#property indicator_width2 2
#property indicator_color3 DodgerBlue     // atrlo[]
#property indicator_width3 1
#property indicator_color4 Red            // atrhi[]
#property indicator_width4 1

extern int  Amplitude = 2;
extern bool ShowBars  = true;

bool   nextTrend;
double minHigh, maxLow;
double up[],
       down[],
       atrHigh[],
       atrLow[],
       trend[];


/**
 *
 */
int init() {
   IndicatorBuffers(5);             // +1 buffer for trend[]

   SetIndexBuffer(0, up  );  SetIndexEmptyValue(0, 0); SetIndexStyle(0, DRAW_LINE);
   SetIndexBuffer(1, down);  SetIndexEmptyValue(1, 0); SetIndexStyle(1, DRAW_LINE);
   SetIndexBuffer(2, atrLow);
   SetIndexBuffer(3, atrHigh);
   SetIndexBuffer(4, trend); SetIndexEmptyValue(4, 0);

   if (ShowBars) {
      SetIndexStyle(2, DRAW_HISTOGRAM, STYLE_SOLID);
      SetIndexStyle(3, DRAW_HISTOGRAM, STYLE_SOLID);
   }
   else {
      SetIndexStyle(2, DRAW_NONE);
      SetIndexStyle(3, DRAW_NONE);
   }

   nextTrend = 0;
   minHigh   = High[Bars-1];
   maxLow    = Low [Bars-1];
   return(0);
}


/**
 *
 */
int start() {

   for (int i=Bars-1; i>=0; i--) {
      double high   = iHigh(NULL, NULL, iHighest(NULL, NULL, MODE_HIGH, Amplitude, i));
      double low    = iLow (NULL, NULL,  iLowest(NULL, NULL, MODE_LOW,  Amplitude, i));
      double maHigh = iMA(NULL, NULL, Amplitude, 0, MODE_SMA, PRICE_HIGH, i);
      double maLow  = iMA(NULL, NULL, Amplitude, 0, MODE_SMA, PRICE_LOW,  i);
      double atr    = iATR(NULL, NULL, 100, i)/2;

      trend[i] = trend[i+1];

      if (nextTrend == 1) {
         maxLow = MathMax(low, maxLow);

         if (maHigh < maxLow && Close[i] < Low[i+1]) {
            trend[i]  = 1;
            nextTrend = 0;
            minHigh   = high;
         }
      }

      if (nextTrend == 0) {
         minHigh = MathMin(high, minHigh);

         if (maLow > minHigh && Close[i] > High[i+1]) {
            trend[i]  = 0;
            nextTrend = 1;
            maxLow    = low;
         }
      }

      if (trend[i] == 0) {
         if (trend[i+1] != 0) {
            up[i]   = down[i+1];
            up[i+1] = up[i];
         }
         else {
            up[i] = MathMax(maxLow, up[i+1]);
         }
         atrHigh[i] = up[i] - atr;
         atrLow [i] = up[i];
         down[i]    = 0;
      }
      else {
         if (trend[i+1] != 1) {
            down[i]   = up[i+1];
            down[i+1] = down[i];
         }
         else {
            down[i] = MathMin(minHigh, down[i+1]);
         }
         atrHigh[i] = down[i] + atr;
         atrLow [i] = down[i];
         up[i]      = 0;
      }
   }
   return(0);
}
