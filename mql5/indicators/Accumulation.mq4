//+------------------------------------------------------------------+
//|                                                 Accumulation.mq4 |
//|                   Copyright 2005-2014, MetaQuotes Software Corp. |
//|                                              http://www.mql4.com |
//+------------------------------------------------------------------+
#property copyright   "2005-2014, MetaQuotes Software Corp."
#property link        "http://www.mql4.com"
#property description "Accumulation/Distribution"
#property strict

//--- indicator settings
#property indicator_separate_window
#property indicator_buffers 1
#property indicator_color1  LightSeaGreen
//--- buffers
double ExtADbuffer[];
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
void OnInit(void)
  {
   IndicatorShortName("A/D");
   IndicatorDigits(0);
//--- indicators
   SetIndexStyle(0,DRAW_LINE);
   SetIndexBuffer(0,ExtADbuffer);
  }
//+------------------------------------------------------------------+
//| Accumulation/Distribution                                        |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
  {
//--- prevent total recalculation
   int i=rates_total-prev_calculated-1;
//--- current value should be recalculated
   if(i<0)
      i=0;
//---
   while(i>=0)
     {
      ExtADbuffer[i]=(close[i]-low[i])-(high[i]-close[i]);
      if(ExtADbuffer[i]!=0.0)
        {
         double diff=high[i]-low[i];
         if(diff<0.000000001)
            ExtADbuffer[i]=0.0;
         else
           {
            ExtADbuffer[i]/=diff;
            ExtADbuffer[i]*=(double)tick_volume[i];
           }
        }
      if(i<rates_total-1)
         ExtADbuffer[i]+=ExtADbuffer[i+1];
      i--;
     }
//---
   return(rates_total);
  }
//+------------------------------------------------------------------+
