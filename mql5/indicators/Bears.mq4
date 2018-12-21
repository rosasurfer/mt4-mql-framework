//+------------------------------------------------------------------+
//|                                                        Bears.mq4 |
//|                   Copyright 2005-2014, MetaQuotes Software Corp. |
//|                                              http://www.mql4.com |
//+------------------------------------------------------------------+
#property copyright   "2005-2014, MetaQuotes Software Corp."
#property link        "http://www.mql4.com"
#property description "Bears Power"
#property strict

//--- indicator settings
#property indicator_separate_window
#property indicator_buffers 1
#property indicator_color1 Silver
//--- input parameter
input int InpBearsPeriod=13; // Bears Period
//--- buffers
double ExtBearsBuffer[];
double ExtTempBuffer[];
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
void OnInit(void)
  {
   string short_name;
//--- 1 additional buffer used for counting.
   IndicatorBuffers(2);
   IndicatorDigits(Digits);
//--- indicator line
   SetIndexStyle(0,DRAW_HISTOGRAM);
   SetIndexBuffer(0,ExtBearsBuffer);
   SetIndexBuffer(1,ExtTempBuffer);
//--- name for DataWindow and indicator subwindow label
   short_name="Bears("+IntegerToString(InpBearsPeriod)+")";
   IndicatorShortName(short_name);
   SetIndexLabel(0,short_name);
  }
//+------------------------------------------------------------------+
//| Bears Power                                                      |
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
   int limit=rates_total-prev_calculated;
//---
   if(rates_total<=InpBearsPeriod)
      return(0);
//---
   if(prev_calculated>0)
      limit++;
   for(int i=0; i<limit; i++)
     {
      ExtTempBuffer[i]=iMA(NULL,0,InpBearsPeriod,0,MODE_EMA,PRICE_CLOSE,i);
      ExtBearsBuffer[i]=low[i]-ExtTempBuffer[i];
     }
//---
   return(rates_total);
  }
//+------------------------------------------------------------------+
