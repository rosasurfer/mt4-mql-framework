/**
 * Bressert Double-Stochastic Oszillator
 *
 * The standard Stochastic Oszillator displays dominant up/down cycles of the underlying price series and is calculated as
 * EMA(EMA(Stochastics(N))). The Double-Stochastic Oszillator by Walter Bressert calculates a second stochastics from the
 * standard Stochastic Oszillator. The formula is Stochastics(Stochastics(N)).
 */
#include <stddefines.mqh>
int   __InitFlags[];
int __DeinitFlags[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern int EMA.Periods        =  8;
extern int Stochastic.Periods = 13;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <rsfLib.mqh>

#property indicator_separate_window
#property indicator_minimum   0
#property indicator_maximum   100
#property indicator_buffers   2
#property indicator_color1    Red
#property indicator_color2    DarkBlue
#property indicator_level1    20
#property indicator_level2    80


double DssBuffer[];
double MitBuffer[];
double smooth_coefficient;


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   SetIndexStyle(0, DRAW_LINE);
   SetIndexBuffer(0, DssBuffer);
   SetIndexStyle(1, DRAW_LINE);
   SetIndexBuffer(1, MitBuffer);

   SetIndexEmptyValue(0, 0);
   SetIndexLabel(0, "DSS");
   SetIndexEmptyValue(1, 0);
   SetIndexLabel(1, "MIT");

   IndicatorShortName("DSS("+ EMA.Periods +","+ Stochastic.Periods +")");

   smooth_coefficient = 2.0/(1 + EMA.Periods);
   return(0);
}


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   int limit, counted_bars = IndicatorCounted();

   if (counted_bars == 0) limit = Bars - Stochastic.Periods;
   if (counted_bars > 0)  limit = Bars - counted_bars;

   double HighRange, LowRange;
   double delta, MIT;
   for (int i=limit; i >= 0; i--) {
      HighRange = High[iHighest(NULL, 0, MODE_HIGH, Stochastic.Periods, i)];
      LowRange  = Low [iLowest (NULL, 0, MODE_LOW,  Stochastic.Periods, i)];
      delta = Close[i] - LowRange;
      MIT = delta/(HighRange - LowRange)*100.0;
      MitBuffer[i] = smooth_coefficient * (MIT - MitBuffer[i+1]) + MitBuffer[i+1];
   }

   double DSS;
   for (i = limit; i >= 0; i--) {
      HighRange = MitBuffer[ArrayMaximum(MitBuffer, Stochastic.Periods, i)];
      LowRange  = MitBuffer[ArrayMinimum(MitBuffer, Stochastic.Periods, i)];
      delta = MitBuffer[i] - LowRange;
      DSS = delta/(HighRange - LowRange)*100.0;
      DssBuffer[i] = smooth_coefficient * (DSS - DssBuffer[i+1]) + DssBuffer[i+1];
   }
   return(0);
}
