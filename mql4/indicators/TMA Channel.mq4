/**
 * TMA Channel
 *
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
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1
#property indicator_width2  3
#property indicator_width3  3
#property indicator_width4  6
#property indicator_width5  6


double tmBuffer[];
double upBuffer[];
double dnBuffer[];
double wuBuffer[];
double wdBuffer[];
double upArrow[];
double dnArrow[];


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   HalfLength = MathMax(HalfLength, 1);
   IndicatorBuffers(7);
   SetIndexBuffer(0, tmBuffer); SetIndexDrawBegin(0, HalfLength);
   SetIndexBuffer(1, upBuffer); SetIndexDrawBegin(1, HalfLength);
   SetIndexBuffer(2, dnBuffer); SetIndexDrawBegin(2, HalfLength);
   SetIndexBuffer(3, dnArrow ); SetIndexStyle(3, DRAW_ARROW); SetIndexArrow(3, 82);
   SetIndexBuffer(4, upArrow ); SetIndexStyle(4, DRAW_ARROW); SetIndexArrow(4, 82);
   SetIndexBuffer(5, wuBuffer);
   SetIndexBuffer(6, wdBuffer);
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

   calculateTma(limit);

 	for (int i=limit; i >= 0; i--) {
      upArrow[i] = EMPTY_VALUE;
      dnArrow[i] = EMPTY_VALUE;

      if (High[i+1] > upBuffer[i+1] && Close[i+1] > Open[i+1] && Close[i] < Open[i]) upArrow[i] = High[i];
      if (Low [i+1] < dnBuffer[i+1] && Close[i+1] < Open[i+1] && Close[i] > Open[i]) dnArrow[i] = Low [i];
   }

   if (alertsOn) {
      if (Close[0] > upBuffer[0] && Close[1] < upBuffer[1]) doAlert("price crossed upper channel band");
      if (Close[0] < dnBuffer[0] && Close[1] > dnBuffer[1]) doAlert("price crossed lower channel band");
   }
   return(0);
}


/**
 *
 */
void calculateTma(int limit) {
   int j, k;
   double FullLength = 2.0*HalfLength + 1;

   for (int i=limit; i >= 0; i--) {
      double sum  = (HalfLength+1) * iMA(NULL, 0, 1, 0, MODE_SMA, Price, i);
      double sumw = (HalfLength+1);

      for (j=1, k=HalfLength; j<=HalfLength; j++, k--) {
         sum  += k * iMA(NULL, 0, 1, 0, MODE_SMA, Price, i+j);
         sumw += k;
         if (j <= i) {
            sum  += k * iMA(NULL, 0, 1, 0, MODE_SMA, Price, i-j);
            sumw += k;
         }
      }
      tmBuffer[i] = sum/sumw;
      double diff = iMA(NULL, 0, 1, 0, MODE_SMA, Price, i) - tmBuffer[i];

      if (i > (Bars-HalfLength-1)) continue;

      if (i == (Bars-HalfLength-1)) {
         upBuffer[i] = tmBuffer[i];
         dnBuffer[i] = tmBuffer[i];
         if (diff >= 0) {
            wuBuffer[i] = MathPow(diff,2);
            wdBuffer[i] = 0;
         }
         else {
            wdBuffer[i] = MathPow(diff,2);
            wuBuffer[i] = 0;
         }
         continue;
      }

      if (diff >= 0) {
         wuBuffer[i] = (wuBuffer[i+1]*(FullLength-1)+MathPow(diff,2))/FullLength;
         wdBuffer[i] =  wdBuffer[i+1]*(FullLength-1)/FullLength;
      }
      else {
         wdBuffer[i] = (wdBuffer[i+1]*(FullLength-1)+MathPow(diff,2))/FullLength;
         wuBuffer[i] =  wuBuffer[i+1]*(FullLength-1)/FullLength;
      }
      upBuffer[i] = tmBuffer[i] + BandsDeviations*MathSqrt(wuBuffer[i]);
      dnBuffer[i] = tmBuffer[i] - BandsDeviations*MathSqrt(wdBuffer[i]);
   }
}


/**
 *
 */
void doAlert(string msg) {
   static datetime lastTime;
   static string lastMsg = "";

   if (Time[0]!=lastTime || msg!=lastMsg) {
      lastTime = Time[0];
      lastMsg  = msg;
      logNotice("doAlert(1)  "+ msg);
   }
}
