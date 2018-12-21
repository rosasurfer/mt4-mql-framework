//+------------------------------------------------------------------+
//|                                                      Awesome.mq4 |
//|                   Copyright 2005-2014, MetaQuotes Software Corp. |
//|                                              http://www.mql4.com |
//+------------------------------------------------------------------+
#property copyright   "2005-2014, MetaQuotes Software Corp."
#property link        "http://www.mql4.com"
#property description "Awesome Oscillator"
#property strict

//--- indicator settings
#property  indicator_separate_window
#property  indicator_buffers 3
#property  indicator_color1  Black
#property  indicator_color2  Green
#property  indicator_color3  Red
//--- buffers
double     ExtAOBuffer[];
double     ExtUpBuffer[];
double     ExtDnBuffer[];
//---
#define PERIOD_FAST  5
#define PERIOD_SLOW 34
//--- bars minimum for calculation
#define DATA_LIMIT  34
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
void OnInit(void)
  {
//--- drawing settings
   SetIndexStyle(0,DRAW_NONE);
   SetIndexStyle(1,DRAW_HISTOGRAM);
   SetIndexStyle(2,DRAW_HISTOGRAM);
   IndicatorDigits(Digits+1);
   SetIndexDrawBegin(0,DATA_LIMIT);
   SetIndexDrawBegin(1,DATA_LIMIT);
   SetIndexDrawBegin(2,DATA_LIMIT);
//--- 3 indicator buffers mapping
   SetIndexBuffer(0,ExtAOBuffer);
   SetIndexBuffer(1,ExtUpBuffer);
   SetIndexBuffer(2,ExtDnBuffer);
//--- name for DataWindow and indicator subwindow label
   IndicatorShortName("AO");
   SetIndexLabel(1,NULL);
   SetIndexLabel(2,NULL);
  }
//+------------------------------------------------------------------+
//| Awesome Oscillator                                               |
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
   int    i,limit=rates_total-prev_calculated;
   double prev=0.0,current;
//--- check for rates total
   if(rates_total<=DATA_LIMIT)
      return(0);
//--- last counted bar will be recounted
   if(prev_calculated>0)
     {
      limit++;
      prev=ExtAOBuffer[limit];
     }
//--- macd
   for(i=0; i<limit; i++)
      ExtAOBuffer[i]=iMA(NULL,0,PERIOD_FAST,0,MODE_SMA,PRICE_MEDIAN,i)-
                     iMA(NULL,0,PERIOD_SLOW,0,MODE_SMA,PRICE_MEDIAN,i);
//--- dispatch values between 2 buffers
   bool up=true;
   for(i=limit-1; i>=0; i--)
     {
      current=ExtAOBuffer[i];
      if(current>prev)
         up=true;
      if(current<prev)
         up=false;
      if(!up)
        {
         ExtDnBuffer[i]=current;
         ExtUpBuffer[i]=0.0;
        }
      else
        {
         ExtUpBuffer[i]=current;
         ExtDnBuffer[i]=0.0;
        }
      prev=current;
     }
//--- done
   return(rates_total);
  }
//+------------------------------------------------------------------+
