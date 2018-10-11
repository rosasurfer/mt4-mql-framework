//+------------------------------------------------------------------+
//|                                   Robby DSS Bressert Colored.mq4 |
//|                                                   Jaanus Jantson |
//|                          http://fx.jantson.ee; jaanus@jantson.ee |
//|                                                 Copyleft removed |
//|                                       http://www.metaquotes.net/ |
//+------------------------------------------------------------------+
#property copyright "Copyleft removed"
#property link      "http://www.metaquotes.net/"

#property indicator_separate_window
#property indicator_minimum 0
#property indicator_maximum 100
#property indicator_buffers 3
#property indicator_color1 OrangeRed
#property indicator_width1 3
#property indicator_color2 Blue
#property indicator_width2 2
#property indicator_color3 Red
#property indicator_width3 2
#property indicator_level1 20
#property indicator_level2 80


extern int       EMA_period=8;
extern int       Stochastic_period=13;


double DssBuffer[];
double MitBuffer[];
double DssBuffer_UP[];
double DssBuffer_DW[];


double smooth_coefficient;


int init()
{
   IndicatorBuffers(4);
   SetIndexBuffer(0,DssBuffer);
   SetIndexStyle(0,DRAW_LINE);
   SetIndexBuffer(1,DssBuffer_UP);
   SetIndexStyle(1,DRAW_ARROW);
   SetIndexArrow(1,159);
   SetIndexBuffer(2,DssBuffer_DW);
   SetIndexStyle(2,DRAW_ARROW);
   SetIndexArrow(2,159);

   SetIndexBuffer(3,MitBuffer);

   SetIndexEmptyValue(0, 0.0);
   SetIndexLabel(0, "DSS");
   SetIndexEmptyValue(1, 0.0);
   SetIndexLabel(1, "DSS Up");
   SetIndexEmptyValue(2, 0.0);
   SetIndexLabel(2, "DSS Down");

   IndicatorShortName ("DSS("+EMA_period+","+Stochastic_period+")");

   smooth_coefficient = 2.0 / (1.0 + EMA_period);
   return(0);
}


int start()
{
   int i, limit, counted_bars=IndicatorCounted(), Bar_OK;
   if (counted_bars == 0)   limit = Bars - Stochastic_period;
   if (counted_bars > 0)   limit = Bars - counted_bars;

   double HighRange, LowRange;
   double delta, MIT;
   for (i = limit; i >= 0; i--)
   {
      HighRange = High[iHighest(NULL,0,MODE_HIGH,Stochastic_period,i)];
      LowRange = Low[iLowest(NULL,0,MODE_LOW,Stochastic_period,i)];
      delta = Close[i] - LowRange;
      MIT = delta/(HighRange - LowRange)*100.0;
      MitBuffer[i] = smooth_coefficient * (MIT - MitBuffer[i+1]) + MitBuffer[i+1];
   }

   double DSS;
   for (i = limit; i >= 0; i--)
   {
      HighRange = MitBuffer[ArrayMaximum(MitBuffer, Stochastic_period, i)];
      LowRange = MitBuffer[ArrayMinimum(MitBuffer, Stochastic_period, i)];
      delta = MitBuffer[i] - LowRange;
      DSS = delta/(HighRange - LowRange)*100.0;
      DssBuffer[i] = smooth_coefficient * (DSS - DssBuffer[i+1]) + DssBuffer[i+1];
   }

   for (i = limit; i >= 0; i--)
   {
      //DssBuffer_UP[i]=EMPTY_VALUE;
      //DssBuffer_DW[i]=EMPTY_VALUE;
      Bar_OK=0;

      if(DssBuffer[i]>DssBuffer[i+1])
      {
         DssBuffer_UP[i]=DssBuffer[i];
         Bar_OK=1;
         DssBuffer_DW[i] = 0.0;
      }

      if(DssBuffer[i]<DssBuffer[i+1])
      {
         DssBuffer_DW[i]=DssBuffer[i];
         Bar_OK=1;
         DssBuffer_UP[i] = 0.0;
      }

      if(Bar_OK==0)
      {
         DssBuffer_UP[i]=DssBuffer_UP[i+1];
         DssBuffer_DW[i]=DssBuffer_DW[i+1];
      }
   }

   return(0);
}
