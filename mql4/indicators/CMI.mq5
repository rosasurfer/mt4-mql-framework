//+------------------------------------------------------------------+
//|                                          Choppy Market Index.mq5 |
//|                                                           Alextp |
//|                                 https://www.mql5.com/en/code/942 |
//+------------------------------------------------------------------+
#property copyright "Choppy Market Index"
#property link      "https://www.mql5.com/en/code/942"
#property version   "1.00"
#property indicator_separate_window
#include <MovingAverages.mqh>
#property indicator_buffers 3
#property indicator_plots 2
#property indicator_minimum 0
#property indicator_maximum 100
#property indicator_level1 60
#property indicator_level2 50
#property indicator_level3 40
#property indicator_levelcolor clrPurple
//-------------------------------------------------------------------------
#property indicator_type1 DRAW_LINE
#property indicator_color1 clrBlue
#property indicator_width1 2
#property indicator_label1 "Signal"
//-------------------------------------------------------------------------
#property indicator_type2 DRAW_COLOR_HISTOGRAM
#property indicator_color2 clrRed,clrYellow,clrGreen,
#property indicator_width2 2
#property indicator_label2 "Hist"
//------------------------------------------------------------------------
input int                  N_Period = 60;     //CMI Period
input int                  MA_Period = 10;    //MA Period
//-------------------------------------------------------------------------
double HistBuffer[];
double ColorBuffer[];
double MABuffer[];
int    ColorInd=0;
//+-------------------------------------------------------------------------
//| Custom indicator initialization function                                |
//+-------------------------------------------------------------------------
int OnInit()
  {
//---
   SetIndexBuffer(0,MABuffer,INDICATOR_DATA);
   SetIndexBuffer(1,HistBuffer,INDICATOR_DATA);
   SetIndexBuffer(2,ColorBuffer,INDICATOR_COLOR_INDEX);
//---
   PlotIndexSetDouble(0,PLOT_EMPTY_VALUE,0.0);
   PlotIndexSetDouble(1,PLOT_EMPTY_VALUE,0.0);
//---
   ArraySetAsSeries(HistBuffer,true);
   ArraySetAsSeries(ColorBuffer,true);
   ArraySetAsSeries(MABuffer,true);

   IndicatorSetString(INDICATOR_SHORTNAME,"(CMI"+", Period = "+string(N_Period)+", MA = "+string(MA_Period)+" )");
   IndicatorSetInteger(INDICATOR_DIGITS,_Digits+1);

   return(0);
  }
double Delta_hl,Delta_Close;
//+-------------------------------------------------------------------------+
//| Custom indicator iteration function                                     |
//+-------------------------------------------------------------------------+
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
   int offset=N_Period+1;
   if(rates_total<offset) return(0);
   ArraySetAsSeries(high,true);
   ArraySetAsSeries(low,true);
   ArraySetAsSeries(close,true);

   int start;
   if(prev_calculated<rates_total || prev_calculated<=0)
     {
      for(int i=rates_total-1; i>=0; i--)
        {
         HistBuffer[i]=0.0;
        }
      start=rates_total-offset;
     }
   else start=rates_total-prev_calculated;
// ---------------------------
   for(int i=start; i>=0; i--)
     {
      Delta_hl=high[ArrayMaximum(high,i,N_Period)]-low[ArrayMinimum(low,i,N_Period)];;
      Delta_Close=close[i]-close[i+N_Period];
      //----
      if(Delta_hl==0)
         HistBuffer[i]=0;
      else
         HistBuffer[i]=MathAbs(Delta_Close)/Delta_hl*100;

      if(Delta_Close>0)
        {
         if(ColorInd<2) ColorInd++;
         ColorBuffer[i]=ColorInd;
        }
      else if(Delta_Close<0)
        {
         if(ColorInd>0) ColorInd--;
         ColorBuffer[i]=ColorInd;
        }
      else   ColorBuffer[i]=1;
     }
   SimpleMAOnBuffer(rates_total,prev_calculated,N_Period,MA_Period,HistBuffer,MABuffer);

   return(rates_total);
  }
//+------------------------------------------------------------------
