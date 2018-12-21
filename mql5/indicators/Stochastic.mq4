//+------------------------------------------------------------------+
//|                                                   Stochastic.mq4 |
//|                   Copyright 2005-2014, MetaQuotes Software Corp. |
//|                                              http://www.mql4.com |
//+------------------------------------------------------------------+
#property copyright   "2005-2014, MetaQuotes Software Corp."
#property link        "http://www.mql4.com"
#property description "Stochastic Oscillator"
#property strict

#property indicator_separate_window
#property indicator_minimum    0
#property indicator_maximum    100
#property indicator_buffers    2
#property indicator_color1     LightSeaGreen
#property indicator_color2     Red
#property indicator_level1     20.0
#property indicator_level2     80.0
#property indicator_levelcolor clrSilver
#property indicator_levelstyle STYLE_DOT
//--- input parameters
input int InpKPeriod=5; // K Period
input int InpDPeriod=3; // D Period
input int InpSlowing=3; // Slowing
//--- buffers
double ExtMainBuffer[];
double ExtSignalBuffer[];
double ExtHighesBuffer[];
double ExtLowesBuffer[];
//---
int draw_begin1=0;
int draw_begin2=0;
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit(void)
  {
   string short_name;
//--- 2 additional buffers are used for counting.
   IndicatorBuffers(4);
   SetIndexBuffer(2, ExtHighesBuffer);
   SetIndexBuffer(3, ExtLowesBuffer);
//--- indicator lines
   SetIndexStyle(0,DRAW_LINE);
   SetIndexBuffer(0, ExtMainBuffer);
   SetIndexStyle(1,DRAW_LINE);
   SetIndexBuffer(1, ExtSignalBuffer);
//--- name for DataWindow and indicator subwindow label
   short_name="Sto("+IntegerToString(InpKPeriod)+","+IntegerToString(InpDPeriod)+","+IntegerToString(InpSlowing)+")";
   IndicatorShortName(short_name);
   SetIndexLabel(0,short_name);
   SetIndexLabel(1,"Signal");
//---
   draw_begin1=InpKPeriod+InpSlowing;
   draw_begin2=draw_begin1+InpDPeriod;
   SetIndexDrawBegin(0,draw_begin1);
   SetIndexDrawBegin(1,draw_begin2);
//--- initialization done
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Stochastic oscillator                                            |
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
//--- check for bars count
   if(rates_total<=InpKPeriod+InpDPeriod+InpSlowing)
      return(0);
//--- counting from 0 to rates_total
   ArraySetAsSeries(ExtMainBuffer,false);
   ArraySetAsSeries(ExtSignalBuffer,false);
   ArraySetAsSeries(ExtHighesBuffer,false);
   ArraySetAsSeries(ExtLowesBuffer,false);
   ArraySetAsSeries(low,false);
   ArraySetAsSeries(high,false);
   ArraySetAsSeries(close,false);
//---
   pos=InpKPeriod-1;
   if(pos+1<prev_calculated)
      pos=prev_calculated-2;
   else
     {
      for(i=0; i<pos; i++)
        {
         ExtLowesBuffer[i]=0.0;
         ExtHighesBuffer[i]=0.0;
        }
     }
//--- calculate HighesBuffer[] and ExtHighesBuffer[]
   for(i=pos; i<rates_total && !IsStopped(); i++)
     {
      double dmin=1000000.0;
      double dmax=-1000000.0;
      for(k=i-InpKPeriod+1; k<=i; k++)
        {
         if(dmin>low[k])
            dmin=low[k];
         if(dmax<high[k])
            dmax=high[k];
        }
      ExtLowesBuffer[i]=dmin;
      ExtHighesBuffer[i]=dmax;
     }
//--- %K line
   pos=InpKPeriod-1+InpSlowing-1;
   if(pos+1<prev_calculated)
      pos=prev_calculated-2;
   else
     {
      for(i=0; i<pos; i++)
         ExtMainBuffer[i]=0.0;
     }
//--- main cycle
   for(i=pos; i<rates_total && !IsStopped(); i++)
     {
      double sumlow=0.0;
      double sumhigh=0.0;
      for(k=(i-InpSlowing+1); k<=i; k++)
        {
         sumlow +=(close[k]-ExtLowesBuffer[k]);
         sumhigh+=(ExtHighesBuffer[k]-ExtLowesBuffer[k]);
        }
      if(sumhigh==0.0)
         ExtMainBuffer[i]=100.0;
      else
         ExtMainBuffer[i]=sumlow/sumhigh*100.0;
     }
//--- signal
   pos=InpDPeriod-1;
   if(pos+1<prev_calculated)
      pos=prev_calculated-2;
   else
     {
      for(i=0; i<pos; i++)
         ExtSignalBuffer[i]=0.0;
     }
   for(i=pos; i<rates_total && !IsStopped(); i++)
     {
      double sum=0.0;
      for(k=0; k<InpDPeriod; k++)
         sum+=ExtMainBuffer[i-k];
      ExtSignalBuffer[i]=sum/InpDPeriod;
     }
//--- OnCalculate done. Return new prev_calculated.
   return(rates_total);
  }
//+------------------------------------------------------------------+