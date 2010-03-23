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
   SetIndexLabel (0, StringConcatenate("UpperBand(", BB.Period, ")"));
   SetIndexBuffer(1, MovingAvg);
   SetIndexLabel (1, StringConcatenate("MiddleBand(", BB.Period, ")"));
   SetIndexBuffer(2, LowerBand);
   SetIndexLabel (2, StringConcatenate("LowerBand(", BB.Period, ")"));

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
   //BB.Period = 4;

   int unprocessedBars,                            // unprocessedBars ist Anzahl der neu zu berechnenden Bars
       processedBars = IndicatorCounted(),
       iLastValidBar = Bars - BB.Period,           // iLastValidBar ist Index der letzten gültigen Bar
       i, k;

   if (iLastValidBar < 0)                          // im Fall Bars < BB.Period
      iLastValidBar = -1;

   
   // ggf. Schwanz mit 0 überschreiben...
   if (processedBars == 0) {                       
      for (i=iLastValidBar+1; i < Bars; i++) {
         MovingAvg[i] = EMPTY_VALUE;
         UpperBand[i] = EMPTY_VALUE;
         LowerBand[i] = EMPTY_VALUE;
      }
      unprocessedBars = iLastValidBar + 1;         //... und alle Bars neuberechnen
   }
   else {
      unprocessedBars = Bars - processedBars + 1;  // die vorherige Bar wird jedesmal neuberechnet
   }

   if (iLastValidBar == -1)                        // im Fall Bars < BB.Period return erst nach Überschreiben des Schwanzes
      return(catch("start(1)"));


   // MA berechnen
   for (i=0; i < unprocessedBars; i++) {
      MovingAvg[i] = iMA(NULL, 0, BB.Period, 0, MODE_SMA, PRICE_MEDIAN, i);
   }


   // Bollinger-Bänder berechnen
   double ma, diff, sum, deviation;
   i = unprocessedBars - 1;

   while (i >= 0) {
      sum = 0;
      ma  = MovingAvg[i];
      k   = i + BB.Period - 1;

      while (k >= i) {
         diff = (High[k]+Low[k])/2 - ma;           // PRICE_MEDIAN: (HL)/2 = 
         sum += diff * diff;
         k--;
      }
      deviation    = BB.Deviation * MathSqrt(sum/BB.Period);
      UpperBand[i] = ma + deviation;
      LowerBand[i] = ma - deviation;
      i--;
   }
   //Print("start()   unprocessedBars: "+ unprocessedBars +"   loops: "+ ((unprocessedBars-1) * BB.Period));

   return(catch("start(2)"));
}

