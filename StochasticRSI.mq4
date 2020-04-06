/**
 * StochasticRSI v2
 */
extern int RsiLength   = 100;
extern int StochLength = 100;
extern int SmoothK     =  30;
extern int SmoothD     =   6;

#property indicator_separate_window
#property indicator_buffers    3

#property indicator_color3     DodgerBlue

#property indicator_maximum  100
#property indicator_minimum    0

#property indicator_level1    40
#property indicator_level2    60
#property indicator_levelcolor DodgerBlue
#property indicator_levelstyle STYLE_DOT

double Buffer1[];
double Buffer2[];
double Buffer3[];


/**
 *
 */
int init() {
   SetIndexBuffer(0, Buffer1); SetIndexStyle(0, DRAW_NONE, STYLE_SOLID, 1); SetIndexLabel(0, NULL);
   SetIndexBuffer(1, Buffer2); SetIndexStyle(1, DRAW_NONE, STYLE_SOLID, 1); SetIndexLabel(1, NULL);
   SetIndexBuffer(2, Buffer3); SetIndexStyle(2, DRAW_LINE, STYLE_SOLID, 2); SetIndexLabel(2, "StochasticRSI");
   return(0);
}


/**
 *
 */
int start() {
   double rsi, rsiHigh, rsiLow;
   int NumOfBars = MathMin(Bars, 6000) ;

   for (int i=NumOfBars-MathMax(RsiLength, StochLength)-1; i >= 0; i--) {     // all bars are recalculated on each tick
      rsi     = iRSI(NULL, 0, RsiLength, PRICE_CLOSE, i);
      rsiHigh = rsi;
      rsiLow  = rsi;

       for (int x=0; x < StochLength; x++) {
         rsiHigh = MathMax(rsiHigh, iRSI(NULL, 0, RsiLength, PRICE_CLOSE, i+x));
         rsiLow  = MathMin(rsiLow,  iRSI(NULL, 0, RsiLength, PRICE_CLOSE, i+x));
      }
      Buffer1[i] = (rsi-rsiLow) / (rsiHigh-rsiLow) * 100;                     // Stochastics
   }

   for (i=NumOfBars-MathMax(RsiLength, StochLength)-1; i >= 0; i--) {         // all bars are recalculated on each tick
      Buffer2[i] = iMAOnArray(Buffer1, 0, SmoothK, 0, MODE_SMA, i);           // MA 1
   }

   for (i=NumOfBars-MathMax(RsiLength, StochLength)-1; i >= 0; i--) {         // all bars are recalculated on each tick
      Buffer3[i] = iMAOnArray(Buffer2, 0, SmoothD, 0, MODE_SMA, i);           // MA 2
   }
   return(0);
}
