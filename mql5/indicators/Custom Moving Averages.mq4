//+------------------------------------------------------------------+
//|                                       Custom Moving Averages.mq4 |
//|                   Copyright 2005-2015, MetaQuotes Software Corp. |
//|                                              http://www.mql4.com |
//+------------------------------------------------------------------+
#property copyright   "2005-2015, MetaQuotes Software Corp."
#property link        "http://www.mql4.com"
#property description "Moving Average"
#property strict

#property indicator_chart_window
#property indicator_buffers 1
#property indicator_color1 Red
//--- indicator parameters
input int            InpMAPeriod=13;        // Period
input int            InpMAShift=0;          // Shift
input ENUM_MA_METHOD InpMAMethod=MODE_SMA;  // Method
//--- indicator buffer
double ExtLineBuffer[];
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit(void)
  {
   string short_name;
   int    draw_begin=InpMAPeriod-1;
//--- indicator short name
   switch(InpMAMethod)
     {
      case MODE_SMA  : short_name="SMA(";                break;
      case MODE_EMA  : short_name="EMA(";  draw_begin=0; break;
      case MODE_SMMA : short_name="SMMA(";               break;
      case MODE_LWMA : short_name="LWMA(";               break;
      default :        return(INIT_FAILED);
     }
   IndicatorShortName(short_name+string(InpMAPeriod)+")");
   IndicatorDigits(Digits);
//--- check for input
   if(InpMAPeriod<2)
      return(INIT_FAILED);
//--- drawing settings
   SetIndexStyle(0,DRAW_LINE);
   SetIndexShift(0,InpMAShift);
   SetIndexDrawBegin(0,draw_begin);
//--- indicator buffers mapping
   SetIndexBuffer(0,ExtLineBuffer);
//--- initialization done
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//|  Moving Average                                                  |
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
//--- check for bars count
   if(rates_total<InpMAPeriod-1 || InpMAPeriod<2)
      return(0);
//--- counting from 0 to rates_total
   ArraySetAsSeries(ExtLineBuffer,false);
   ArraySetAsSeries(close,false);
//--- first calculation or number of bars was changed
   if(prev_calculated==0)
      ArrayInitialize(ExtLineBuffer,0);
//--- calculation
   switch(InpMAMethod)
     {
      case MODE_EMA:  CalculateEMA(rates_total,prev_calculated,close);        break;
      case MODE_LWMA: CalculateLWMA(rates_total,prev_calculated,close);       break;
      case MODE_SMMA: CalculateSmoothedMA(rates_total,prev_calculated,close); break;
      case MODE_SMA:  CalculateSimpleMA(rates_total,prev_calculated,close);   break;
     }
//--- return value of prev_calculated for next call
   return(rates_total);
  }
//+------------------------------------------------------------------+
//|   simple moving average                                          |
//+------------------------------------------------------------------+
void CalculateSimpleMA(int rates_total,int prev_calculated,const double &price[])
  {
   int i,limit;
//--- first calculation or number of bars was changed
   if(prev_calculated==0)
   
     {
      limit=InpMAPeriod;
      //--- calculate first visible value
      double firstValue=0;
      for(i=0; i<limit; i++)
         firstValue+=price[i];
      firstValue/=InpMAPeriod;
      ExtLineBuffer[limit-1]=firstValue;
     }
   else
      limit=prev_calculated-1;
//--- main loop
   for(i=limit; i<rates_total && !IsStopped(); i++)
      ExtLineBuffer[i]=ExtLineBuffer[i-1]+(price[i]-price[i-InpMAPeriod])/InpMAPeriod;
//---
  }
//+------------------------------------------------------------------+
//|  exponential moving average                                      |
//+------------------------------------------------------------------+
void CalculateEMA(int rates_total,int prev_calculated,const double &price[])
  {
   int    i,limit;
   double SmoothFactor=2.0/(1.0+InpMAPeriod);
//--- first calculation or number of bars was changed
   if(prev_calculated==0)
     {
      limit=InpMAPeriod;
      ExtLineBuffer[0]=price[0];
      for(i=1; i<limit; i++)
         ExtLineBuffer[i]=price[i]*SmoothFactor+ExtLineBuffer[i-1]*(1.0-SmoothFactor);
     }
   else
      limit=prev_calculated-1;
//--- main loop
   for(i=limit; i<rates_total && !IsStopped(); i++)
      ExtLineBuffer[i]=price[i]*SmoothFactor+ExtLineBuffer[i-1]*(1.0-SmoothFactor);
//---
  }
//+------------------------------------------------------------------+
//|  linear weighted moving average                                  |
//+------------------------------------------------------------------+
void CalculateLWMA(int rates_total,int prev_calculated,const double &price[])
  {
   int        i,limit;
   static int weightsum;
   double     sum;
//--- first calculation or number of bars was changed
   if(prev_calculated==0)
     {
      weightsum=0;
      limit=InpMAPeriod;
      //--- calculate first visible value
      double firstValue=0;
      for(i=0;i<limit;i++)
        {
         int k=i+1;
         weightsum+=k;
         firstValue+=k*price[i];
        }
      firstValue/=(double)weightsum;
      ExtLineBuffer[limit-1]=firstValue;
     }
   else
      limit=prev_calculated-1;
//--- main loop
   for(i=limit; i<rates_total && !IsStopped(); i++)
     {
      sum=0;
      for(int j=0;j<InpMAPeriod;j++)
         sum+=(InpMAPeriod-j)*price[i-j];
      ExtLineBuffer[i]=sum/weightsum;
     }
//---
  }
//+------------------------------------------------------------------+
//|  smoothed moving average                                         |
//+------------------------------------------------------------------+
void CalculateSmoothedMA(int rates_total,int prev_calculated,const double &price[])
  {
   int i,limit;
//--- first calculation or number of bars was changed
   if(prev_calculated==0)
     {
      limit=InpMAPeriod;
      double firstValue=0;
      for(i=0; i<limit; i++)
         firstValue+=price[i];
      firstValue/=InpMAPeriod;
      ExtLineBuffer[limit-1]=firstValue;
     }
   else
      limit=prev_calculated-1;
//--- main loop
   for(i=limit; i<rates_total && !IsStopped(); i++)
      ExtLineBuffer[i]=(ExtLineBuffer[i-1]*(InpMAPeriod-1)+price[i])/InpMAPeriod;
//---
  }
//+------------------------------------------------------------------+
