/**
 * TMA Channel
 *
 * @see  https://user42.tuxfamily.org/chart/manual/Triangular-Moving-Average.html
 * @see  https://www.mql5.com/en/forum/181241
 * @see  https://forex-station.com/viewtopic.php?f=579496&t=8423458
 * @see  https://www.forexfactory.com/thread/922947-lazytma-trading
 */
#include <stddefines.mqh>
int   __InitFlags[];
int __DeinitFlags[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern int    HalfLength      = 55;
extern int    Price           = PRICE_WEIGHTED;
extern double BandsDeviations = 2.5;
extern bool   alertsOn        = false;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <rsfLibs.mqh>

#property indicator_chart_window
#property indicator_buffers 5
#property indicator_color1  Magenta
#property indicator_color2  LightPink
#property indicator_color3  PowderBlue
#property indicator_color4  Magenta
#property indicator_color5  Magenta
#property indicator_style1  STYLE_DOT
#property indicator_width1  1
#property indicator_width2  3
#property indicator_width3  3
#property indicator_width4  6
#property indicator_width5  6


double tma      [];
double upperBand[];
double lowerBand[];

double upperVariance[];
double lowerVariance[];

double upperSignal[];
double lowerSignal[];


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   HalfLength = MathMax(HalfLength, 1);
   IndicatorBuffers(7);
   SetIndexBuffer(0, tma          ); SetIndexDrawBegin(0, HalfLength);
   SetIndexBuffer(1, upperBand    ); SetIndexDrawBegin(1, HalfLength);
   SetIndexBuffer(2, lowerBand    ); SetIndexDrawBegin(2, HalfLength);
   SetIndexBuffer(3, upperSignal  ); SetIndexStyle(3, DRAW_ARROW); SetIndexArrow(3, 82);
   SetIndexBuffer(4, lowerSignal  ); SetIndexStyle(4, DRAW_ARROW); SetIndexArrow(4, 82);
   SetIndexBuffer(5, upperVariance);
   SetIndexBuffer(6, lowerVariance);
   IndicatorDigits(Digits);
   return(0);
}


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   int counted_bars = IndicatorCounted();
   if (counted_bars < 0) return(-1);
   if (counted_bars > 0) counted_bars--;
   int limit = MathMin(Bars-1, Bars-counted_bars+HalfLength);

   CalculateTMA(limit);

 	for (int i=limit; i >= 0; i--) {
      upperSignal[i] = EMPTY_VALUE;
      lowerSignal[i] = EMPTY_VALUE;

      if (High[i+1] > upperBand[i+1] && Close[i+1] > Open[i+1] && Close[i] < Open[i]) upperSignal[i] = High[i];
      if (Low [i+1] < lowerBand[i+1] && Close[i+1] < Open[i+1] && Close[i] > Open[i]) lowerSignal[i] = Low [i];
   }

   if (alertsOn) {
      if (Close[0] >= upperBand[0] && Close[1] < upperBand[1]) onSignal("upper channel band crossed");
      if (Close[0] <= lowerBand[0] && Close[1] > lowerBand[1]) onSignal("lower channel band crossed");
   }
   return(0);
}


/**
 *
 */
void CalculateTMA(int limit) {
   int j, k;
   double FullLength = 2*HalfLength + 1;

   for (int i=limit; i >= 0; i--) {
      double sum  = (HalfLength+1) * iMA(NULL, NULL, 1, 0, MODE_SMA, Price, i);
      double sumw = (HalfLength+1);

      for (j=1, k=HalfLength; j<=HalfLength; j++, k--) {
         sum  += k * iMA(NULL, NULL, 1, 0, MODE_SMA, Price, i+j);
         sumw += k;
         if (j <= i) {
            sum  += k * iMA(NULL, NULL, 1, 0, MODE_SMA, Price, i-j);
            sumw += k;
         }
      }
      tma[i] = sum/sumw;

      double diff = iMA(NULL, NULL, 1, 0, MODE_SMA, Price, i) - tma[i];

      if (i > Bars-HalfLength-1)
         continue;

      if (i == Bars-HalfLength-1) {
         if (diff >= 0) {
            upperVariance[i] = MathPow(diff, 2);
            lowerVariance[i] = 0;
         }
         else {
            upperVariance[i] = 0;
            lowerVariance[i] = MathPow(diff, 2);
         }
      }
      else {
         if (diff >= 0) {
            upperVariance[i] = (upperVariance[i+1] * (FullLength-1) + MathPow(diff, 2)) /FullLength;
            lowerVariance[i] = (lowerVariance[i+1] * (FullLength-1) + 0)                /FullLength;
         }
         else {
            upperVariance[i] = (upperVariance[i+1] * (FullLength-1) + 0)                /FullLength;
            lowerVariance[i] = (lowerVariance[i+1] * (FullLength-1) + MathPow(diff, 2)) /FullLength;
         }
      }
      upperBand[i] = tma[i] + BandsDeviations * MathSqrt(upperVariance[i]);
      lowerBand[i] = tma[i] - BandsDeviations * MathSqrt(lowerVariance[i]);
   }
}


/**
 *
 */
void onSignal(string msg) {
   static datetime lastTime;
   static string lastMsg = "";

   if (Time[0]!=lastTime || msg!=lastMsg) {
      lastTime = Time[0];
      lastMsg  = msg;
      logNotice("doAlert(1)  "+ msg);
   }
}
