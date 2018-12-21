//+------------------------------------------------------------------+
//|                                                          CCI.mq4 |
//|                   Copyright 2005-2014, MetaQuotes Software Corp. |
//|                                              http://www.mql4.com |
//+------------------------------------------------------------------+
#property copyright   "2005-2014, MetaQuotes Software Corp."
#property link        "http://www.mql4.com"
#property description "Commodity Channel Index"
#property strict

#include <MovingAverages.mqh>

#property indicator_separate_window
#property indicator_buffers    1
#property indicator_color1     LightSeaGreen
#property indicator_level1    -100.0
#property indicator_level2     100.0
#property indicator_levelcolor clrSilver
#property indicator_levelstyle STYLE_DOT
//--- input parameter
input int InpCCIPeriod=14; // CCI Period
//--- buffers
double ExtCCIBuffer[];
double ExtPriceBuffer[];
double ExtMovBuffer[];
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit(void)
  {
   string short_name;
//--- 2 additional buffers are used for counting.
   IndicatorBuffers(3);
   SetIndexBuffer(1,ExtPriceBuffer);
   SetIndexBuffer(2,ExtMovBuffer);
//--- indicator line
   SetIndexStyle(0,DRAW_LINE);
   SetIndexBuffer(0,ExtCCIBuffer);
//--- check for input parameter
   if(InpCCIPeriod<=1)
     {
      Print("Wrong input parameter CCI Period=",InpCCIPeriod);
      return(INIT_FAILED);
     }
//---
   SetIndexDrawBegin(0,InpCCIPeriod);
//--- name for DataWindow and indicator subwindow label
   short_name="CCI("+IntegerToString(InpCCIPeriod)+")";
   IndicatorShortName(short_name);
   SetIndexLabel(0,short_name);
//--- initialization done
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Commodity Channel Index                                          |
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
   int    i,k,pos;
   double dSum,dMul;
//---
   if(rates_total<=InpCCIPeriod || InpCCIPeriod<=1)
      return(0);
//--- counting from 0 to rates_total
   ArraySetAsSeries(ExtCCIBuffer,false);
   ArraySetAsSeries(ExtPriceBuffer,false);
   ArraySetAsSeries(ExtMovBuffer,false);
   ArraySetAsSeries(high,false);
   ArraySetAsSeries(low,false);
   ArraySetAsSeries(close,false);
//--- initial zero
   if(prev_calculated<1)
     {
      for(i=0; i<InpCCIPeriod; i++)
        {
         ExtCCIBuffer[i]=0.0;
         ExtPriceBuffer[i]=(high[i]+low[i]+close[i])/3;
         ExtMovBuffer[i]=0.0;
        }
     }
//--- calculate position
   pos=prev_calculated-1;
   if(pos<InpCCIPeriod)
      pos=InpCCIPeriod;
//--- typical price and its moving average
   for(i=pos; i<rates_total; i++)
     {
      ExtPriceBuffer[i]=(high[i]+low[i]+close[i])/3;
      ExtMovBuffer[i]=SimpleMA(i,InpCCIPeriod,ExtPriceBuffer);
     }
//--- standard deviations and cci counting
   dMul=0.015/InpCCIPeriod;
   pos=InpCCIPeriod-1;
   if(pos<prev_calculated-1)
      pos=prev_calculated-2;
   i=pos;
   while(i<rates_total)
     {
      dSum=0.0;
      k=i+1-InpCCIPeriod;
      while(k<=i)
        {
         dSum+=MathAbs(ExtPriceBuffer[k]-ExtMovBuffer[i]);
         k++;
        }
      dSum*=dMul;
      if(dSum==0.0)
         ExtCCIBuffer[i]=0.0;
      else
         ExtCCIBuffer[i]=(ExtPriceBuffer[i]-ExtMovBuffer[i])/dSum;
      i++;
     }
//---
   return(rates_total);
  }
//+------------------------------------------------------------------+
