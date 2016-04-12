//+------------------------------------------------------------------+
//|                                                  NonLagDOT.mq4 |
//|                                Copyright © 2006, TrendLaboratory |
//|            http://finance.groups.yahoo.com/group/TrendLaboratory |
//|                                   E-mail: igorad2003@yahoo.co.uk |
//+------------------------------------------------------------------+


#property indicator_chart_window
#property indicator_buffers 3
#property indicator_color1 Yellow
#property indicator_width1 1
#property indicator_color2 RoyalBlue
#property indicator_width2 1
#property indicator_color3 Red
#property indicator_width3 1


// input parameters
extern int MA.Periods = 20;

double Cycle = 4;

// indicator buffers
double MABuffer[];
double UpBuffer[];
double DnBuffer[];
double trend[];


//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int init() {
   // indicator line
   IndicatorBuffers(4);
   SetIndexBuffer(0, MABuffer);
   SetIndexBuffer(1, UpBuffer);
   SetIndexBuffer(2, DnBuffer);
   SetIndexBuffer(3, trend);

   SetIndexStyle(0, DRAW_ARROW);
   SetIndexStyle(1, DRAW_ARROW);
   SetIndexStyle(2, DRAW_ARROW);

   SetIndexArrow(0, 159);
   SetIndexArrow(1, 159);
   SetIndexArrow(2, 159);

   // name for DataWindow and indicator subwindow label
   IndicatorShortName("NonLagMA("+ MA.Periods +")");

   SetIndexLabel(0, "NLD" );
   SetIndexLabel(1, "Up"  );
   SetIndexLabel(2, "Down");

   SetIndexDrawBegin(0, (Cycle+1) * MA.Periods);
   SetIndexDrawBegin(1, (Cycle+1) * MA.Periods);
   SetIndexDrawBegin(2, (Cycle+1) * MA.Periods);

   IndicatorDigits(MarketInfo(Symbol(),MODE_DIGITS));
   return(0);
}


//+------------------------------------------------------------------+
//| NonLagMA_v4                                                     |
//+------------------------------------------------------------------+
int start() {
   int    limit, counted_bars=IndicatorCounted();
   double alpha, beta, t, Sum, Weight, step,g;
   double pi = 3.1415926535;

   double Coeff = 3*pi;
   int    Phase = MA.Periods - 1;
   double Len   = MA.Periods*Cycle + Phase;

   if (counted_bars > 0) limit = Bars-counted_bars;
   if (counted_bars < 0) return(0);
   if (counted_bars ==0) limit = Bars-Len-1;
   if (counted_bars < 1)

   for (int i=1; i < MA.Periods*Cycle+MA.Periods; i++) {
      MABuffer[Bars-i] = 0;
      UpBuffer[Bars-i] = 0;
      DnBuffer[Bars-i] = 0;
   }

   for (int shift=limit; shift >= 0; shift--) {
      Weight=0; Sum=0; t=0;

      for (i=0; i <= Len-1; i++) {
         g = 1/(Coeff*t + 1);
         if (t <= 0.5)
            g = 1;
         beta  = MathCos(pi*t);
         alpha = g * beta;

         Weight += alpha;
         Sum    += alpha * iMA(NULL, 0, 1, 0, MODE_SMA, PRICE_CLOSE, shift+i);

         if      (t < 1)     t += 1.0/(Phase-1);
         else if (t < Len-1) t += (2*Cycle-1)/(Cycle*MA.Periods-1);
      }
      if (Weight != 0) MABuffer[shift] = Sum/Weight;

      trend[shift] = trend[shift+1];

      if (MABuffer[shift]-MABuffer[shift+1] > 0) {
         trend   [shift] = 1;
         UpBuffer[shift] = MABuffer[shift];
         DnBuffer[shift] = 0;
      }
      if (MABuffer[shift]-MABuffer[shift+1] < 0) {
         trend   [shift] = -1;
         UpBuffer[shift] = 0;
         DnBuffer[shift] = MABuffer[shift];
      }
   }
	return(0);
}

