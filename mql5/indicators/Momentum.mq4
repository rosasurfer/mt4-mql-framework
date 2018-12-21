//+------------------------------------------------------------------+
//|                                                     Momentum.mq4 |
//|                   Copyright 2005-2014, MetaQuotes Software Corp. |
//|                                              http://www.mql4.com |
//+------------------------------------------------------------------+
#property copyright   "2005-2014, MetaQuotes Software Corp."
#property link        "http://www.mql4.com"
#property description "Momentum"
#property strict

#property indicator_separate_window
#property indicator_buffers 1
#property indicator_color1 DodgerBlue
//--- input parameter
input int InpMomPeriod=14;  // Momentum Period
//--- buffers
double ExtMomBuffer[];
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit(void)
  {
   string short_name;
//--- indicator line
   SetIndexStyle(0,DRAW_LINE);
   SetIndexBuffer(0,ExtMomBuffer);
//--- name for DataWindow and indicator subwindow label
   short_name="Mom("+IntegerToString(InpMomPeriod)+")";
   IndicatorShortName(short_name);
   SetIndexLabel(0,short_name);
//--- check for input parameter
   if(InpMomPeriod<=0)
     {
      Print("Wrong input parameter Momentum Period=",InpMomPeriod);
      return(INIT_FAILED);
     }
//---
   SetIndexDrawBegin(0,InpMomPeriod);
//--- initialization done
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Momentum                                                         |
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
   int i,limit;
//--- check for bars count and input parameter
   if(rates_total<=InpMomPeriod || InpMomPeriod<=0)
      return(0);
//--- counting from 0 to rates_total
   ArraySetAsSeries(ExtMomBuffer,false);
   ArraySetAsSeries(close,false);
//--- initial zero
   if(prev_calculated<=0)
     {
      for(i=0; i<InpMomPeriod; i++)
         ExtMomBuffer[i]=0.0;
      limit=InpMomPeriod;
     }
   else
      limit=prev_calculated-1;
//--- the main loop of calculations
   for(i=limit; i<rates_total; i++)
      ExtMomBuffer[i]=close[i]*100/close[i-InpMomPeriod];
//--- done
   return(rates_total);
  }
//+------------------------------------------------------------------+
