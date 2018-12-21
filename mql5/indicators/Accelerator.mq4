//+------------------------------------------------------------------+
//|                                                  Accelerator.mq4 |
//|                   Copyright 2005-2014, MetaQuotes Software Corp. |
//|                                              http://www.mql4.com |
//+------------------------------------------------------------------+
#property copyright   "2005-2014, MetaQuotes Software Corp."
#property link        "http://www.mql4.com"
#property description "Accelerator/Decelerator"
#property strict

#include <MovingAverages.mqh>

//--- indicator settings
#property  indicator_separate_window
#property  indicator_buffers 3
#property  indicator_color1  Black
#property  indicator_color2  Green
#property  indicator_color3  Red
//--- indicator buffers
double     ExtACBuffer[];
double     ExtUpBuffer[];
double     ExtDnBuffer[];
double     ExtMacdBuffer[];
double     ExtSignalBuffer[];
//---
#define PERIOD_FAST  5
#define PERIOD_SLOW 34
//--- bars minimum for calculation
#define DATA_LIMIT  38
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
void OnInit(void)
  {
   IndicatorShortName("AC");
//--- 2 additional buffers are used for counting.
   IndicatorBuffers(5);
//--- drawing settings
   SetIndexStyle(0,DRAW_NONE);
   SetIndexStyle(1,DRAW_HISTOGRAM);
   SetIndexStyle(2,DRAW_HISTOGRAM);
   IndicatorDigits(Digits+2);
   SetIndexDrawBegin(0,DATA_LIMIT);
   SetIndexDrawBegin(1,DATA_LIMIT);
   SetIndexDrawBegin(2,DATA_LIMIT);
//--- all indicator buffers mapping
   SetIndexBuffer(0,ExtACBuffer);
   SetIndexBuffer(1,ExtUpBuffer);
   SetIndexBuffer(2,ExtDnBuffer);
   SetIndexBuffer(3,ExtMacdBuffer);
   SetIndexBuffer(4,ExtSignalBuffer);
//--- name for DataWindow and indicator subwindow label
   SetIndexLabel(1,NULL);
   SetIndexLabel(2,NULL);
  }
//+------------------------------------------------------------------+
//| Accelerator/Decelerator Oscillator                               |
//+------------------------------------------------------------------+
int OnCalculate (const int rates_total,
                 const int prev_calculated,
                 const datetime& time[],
                 const double& open[],
                 const double& high[],
                 const double& low[],
                 const double& close[],
                 const long& tick_volume[],
                 const long& volume[],
                 const int& spread[])
  {
   int    i,limit;
   double prev=0.0,current;
//--- check for rates total
   if(rates_total<=DATA_LIMIT)
      return(0);
//--- last counted bar will be recounted
   limit=rates_total-prev_calculated;
   if(prev_calculated>0)
     {
      limit++;
      prev=ExtMacdBuffer[limit]-ExtSignalBuffer[limit];
     }
//--- macd counted in the 1-st additional buffer
   for(i=0; i<limit; i++)
      ExtMacdBuffer[i]=iMA(NULL,0,PERIOD_FAST,0,MODE_SMA,PRICE_MEDIAN,i)-
                       iMA(NULL,0,PERIOD_SLOW,0,MODE_SMA,PRICE_MEDIAN,i);
//--- signal line counted in the 2-nd additional buffer
   SimpleMAOnBuffer(rates_total,prev_calculated,0,5,ExtMacdBuffer,ExtSignalBuffer);
//--- dispatch values between 2 buffers
   bool up=true;
   for(i=limit-1; i>=0;)
     {
      current=ExtMacdBuffer[i]-ExtSignalBuffer[i];
      if(current>prev)
         up=true;
      if(current<prev)
         up=false;
      if(!up)
        {
         ExtUpBuffer[i]=0.0;
         ExtDnBuffer[i]=current;
        }
      else
        {
         ExtUpBuffer[i]=current;
         ExtDnBuffer[i]=0.0;
        }
      ExtACBuffer[i]=current;
      i--;
      prev=ExtMacdBuffer[i+1]-ExtSignalBuffer[i+1];
     }
//--- done
   return(rates_total);
  }
//+------------------------------------------------------------------+
