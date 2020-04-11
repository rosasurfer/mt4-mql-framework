/**
 * Signal BT System
 *
 * corresponds with Jagg's version 8
 */
#include <stddefines.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern int  SmaLength  = 96;                          // 100;
extern int  SRSILength = 96;                          // 100;
extern int  SmoothK    = 10;                          //  30;
extern int  SmoothD    = 6;                           //   6;

extern int  Max.Values = 10000;                       // max. amount of values to calculate (-1: all)

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <rsfLibs.mqh>

#property   indicator_chart_window
#property   indicator_buffers    9

#property   indicator_color1     YellowGreen
#property   indicator_color2     YellowGreen
#property   indicator_color3     LightSkyBlue
#property   indicator_color4     LightSkyBlue
#property   indicator_color5     CLR_NONE
#property   indicator_color6     CLR_NONE
#property   indicator_color7     CLR_NONE
#property   indicator_color8     Green
#property   indicator_color9     RoyalBlue

#property   indicator_width1     5
#property   indicator_width2     5
#property   indicator_width3     5
#property   indicator_width4     5
#property   indicator_width5     0
#property   indicator_width6     0
#property   indicator_width7     0
#property   indicator_width8     3
#property   indicator_width9     3

double buffer3[];          // positive bull hist
double buffer4[];          // negative bull hist
double buffer5[];          // positive bear hist
double buffer6[];          // negative bear hist

double stochBuffer1[];     // Stochastic(RSI) buffer
double stochBuffer2[];     // Stochastic(RSI) MA1 buffer
double stochBuffer3[];     // Stochastic(RSI) MA2 buffer

double MaBufferL[];        // MA long
double MaBufferS[];        // MA short


int      LastPeriod = -1;
datetime lastbar;
bool     LastStateIsBull = false;


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   IndicatorDigits(Digits);

   IndicatorShortName(WindowExpertName());
   SetIndexDrawBegin(0, SmaLength-1);

   SetIndexBuffer(0, buffer3);      SetIndexStyle(0, DRAW_HISTOGRAM, EMPTY);
   SetIndexBuffer(1, buffer4);      SetIndexStyle(1, DRAW_HISTOGRAM, EMPTY);
   SetIndexBuffer(2, buffer5);      SetIndexStyle(2, DRAW_HISTOGRAM, EMPTY);
   SetIndexBuffer(3, buffer6);      SetIndexStyle(3, DRAW_HISTOGRAM, EMPTY);

   SetIndexBuffer(4, stochBuffer1); SetIndexStyle(4, DRAW_NONE, EMPTY, EMPTY);
   SetIndexBuffer(5, stochBuffer2); SetIndexStyle(5, DRAW_NONE, EMPTY, EMPTY);
   SetIndexBuffer(6, stochBuffer3); SetIndexStyle(6, DRAW_NONE, EMPTY, EMPTY);

   SetIndexBuffer(7, MaBufferL);    SetIndexStyle(7, DRAW_LINE, EMPTY);
   SetIndexBuffer(8, MaBufferS);    SetIndexStyle(8, DRAW_LINE, EMPTY);

   return(catch("onInit(1)"));
}


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   int counted = IndicatorCounted();
   if (counted > 0) counted--;

   int limit = MathMin(Bars-counted, Bars-1);
   if (limit > Max.Values) limit = Max.Values;

   if (LastPeriod != Period()) {
      switch (Period()) {
         case PERIOD_H1:
            SmaLength  = 96;
            SRSILength = 96;
            SmoothK    = 10;
            SmoothD    = 6;
            break;

         case PERIOD_M5:
            SmaLength  = 96*12;
            SRSILength = 96*12;
            SmoothK    = 10*12;
            SmoothD    =  6*12;
            break;

         default: return(catch("onTick(2)"));
      }
      LastPeriod = Period();
      lastbar    = 0;
   }

   double rsi, rsiHigh, rsiLow, ma, price;

   for (int i=limit; i >= 0; i--) {
      rsi     = iRSI(NULL, NULL, SRSILength, PRICE_CLOSE, i);
      rsiHigh = rsi;
      rsiLow  = rsi;

      for (int x=0; x < SRSILength; x++) {
         rsiHigh = MathMax(rsiHigh, iRSI(NULL, NULL, SRSILength, PRICE_CLOSE, i+x));
         rsiLow  = MathMin(rsiLow,  iRSI(NULL, NULL, SRSILength, PRICE_CLOSE, i+x));
      }

      stochBuffer1[i] = (rsi-rsiLow) / (rsiHigh-rsiLow) * 100;
      stochBuffer2[i] = iMAOnArray(stochBuffer1, WHOLE_ARRAY, SmoothK, 0, MODE_SMA, i);
      stochBuffer3[i] = iMAOnArray(stochBuffer2, WHOLE_ARRAY, SmoothD, 0, MODE_SMA, i);

      ma    = iMA(NULL, NULL, SmaLength, 0, MODE_SMA, PRICE_CLOSE, i);
      price = Close[i];

      if (Close[i] > ma && Low[i] > ma) {
         price = Low[i];
      }
      else if (Close[i] < ma && High[i] < ma) {
         price = High[i];
      }
      else {
         price = ma;
      }

      buffer3[i] = EMPTY_VALUE;
      buffer4[i] = EMPTY_VALUE;
      buffer5[i] = EMPTY_VALUE;
      buffer6[i] = EMPTY_VALUE;

      if (Close[i] >= ma && stochBuffer3[i] >= 40) {
         LastStateIsBull = true;
      }
      else if (Close[i] < ma && stochBuffer3[i] < 60) {
         LastStateIsBull = false;
      }

      if (LastStateIsBull) {
         buffer3  [i] = ma;
         buffer4  [i] = price;
         MaBufferL[i] = ma;
         MaBufferS[i] = EMPTY_VALUE;
      }
      else {
         buffer5  [i] = ma;
         buffer6  [i] = price;
         MaBufferL[i] = EMPTY_VALUE;
         MaBufferS[i] = ma;
      }
   }
   return(catch("onTick(3)"));
}
