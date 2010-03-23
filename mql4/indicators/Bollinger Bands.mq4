/**
 * Bollinger-Bands-Indikator
 */

#include <stdlib.mqh>


#property indicator_chart_window

#property indicator_buffers 3

#property indicator_color1 C'102,135,232'
#property indicator_color2 C'102,135,232'
#property indicator_color3 C'102,135,232'

#property indicator_style1 STYLE_SOLID
#property indicator_style2 STYLE_DOT
#property indicator_style3 STYLE_SOLID


// indicator parameters
extern int    BB.Period    = 100;
extern double BB.Deviation = 2.0;


// indicator buffers
double UpperBand[];
double MovingAvg[];
double LowerBand[];


/**
 *
 */
int init() {
   SetIndexBuffer(0, UpperBand);
   SetIndexLabel (0, "UpperBand");
   SetIndexBuffer(1, MovingAvg);
   SetIndexLabel (1, "MiddleBand");
   SetIndexBuffer(2, LowerBand);
   SetIndexLabel (2, "LowerBand");

   IndicatorDigits(Digits);

   // während der Entwicklung Puffer jedesmal zurücksetzen
   if (UninitializeReason() == REASON_RECOMPILE) {
      ArrayInitialize(UpperBand, EMPTY_VALUE);
      ArrayInitialize(MovingAvg, EMPTY_VALUE);
      ArrayInitialize(LowerBand, EMPTY_VALUE);
   }

   // nach Parameteränderung sofort start() aufrufen und nicht auf den nächsten Tick warten
   if (UninitializeReason() == REASON_PARAMETERS) {
      start();
      WindowRedraw();
   }

   return(catch("init()"));
}


/**
 *
 */
int start() {
   if (Bars <= BB.Period) 
      return(0);

   int processedBars = IndicatorCounted(),
       bars          = Bars - processedBars,
       i, k;

   if (processedBars == 0) {
      for (i=1; i <= BB.Period; i++) {
         MovingAvg[Bars-i] = EMPTY_VALUE;
         UpperBand[Bars-i] = EMPTY_VALUE;
         LowerBand[Bars-i] = EMPTY_VALUE;
      }
   }
   else {
      bars++;
   }


   // MA berechnen
   for (i=0; i < bars; i++) {
      MovingAvg[i] = iMA(NULL, 0, BB.Period, 0, MODE_SMA, PRICE_MEDIAN, i);
   }


   // Bollinger-Bänder berechnen
   i = Bars - BB.Period + 1;
   if (processedBars > BB.Period-1)
      i = Bars - processedBars - 1;

   double ma, diff, sum, deviation;
   
   while (i >= 0) {
      ma  = MovingAvg[i];
      sum = 0;
      k   = i + BB.Period - 1;
      
      while (k >= i) {
         diff = (High[k]+Low[k])/2 - ma;     // entspricht PRICE_MEDIAN
         sum += diff * diff;
         k--;
      }
      deviation    = BB.Deviation * MathSqrt(sum/BB.Period);
      UpperBand[i] = ma + deviation;
      LowerBand[i] = ma - deviation;
      i--;
   }

   return(catch("start()"));
}

