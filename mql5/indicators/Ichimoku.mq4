//+------------------------------------------------------------------+
//|                                                     Ichimoku.mq4 |
//|                   Copyright 2005-2014, MetaQuotes Software Corp. |
//|                                              http://www.mql4.com |
//+------------------------------------------------------------------+
#property copyright   "2005-2014, MetaQuotes Software Corp."
#property link        "http://www.mql4.com"
#property description "Ichimoku Kinko Hyo"
#property strict

#property indicator_chart_window
#property indicator_buffers 7
#property indicator_color1 Red          // Tenkan-sen
#property indicator_color2 Blue         // Kijun-sen
#property indicator_color3 SandyBrown   // Up Kumo
#property indicator_color4 Thistle      // Down Kumo
#property indicator_color5 Lime         // Chikou Span
#property indicator_color6 SandyBrown   // Up Kumo bounding line
#property indicator_color7 Thistle      // Down Kumo bounding line
//--- input parameters
input int InpTenkan=9;   // Tenkan-sen
input int InpKijun=26;   // Kijun-sen
input int InpSenkou=52;  // Senkou Span B
//--- buffers
double ExtTenkanBuffer[];
double ExtKijunBuffer[];
double ExtSpanA_Buffer[];
double ExtSpanB_Buffer[];
double ExtChikouBuffer[];
double ExtSpanA2_Buffer[];
double ExtSpanB2_Buffer[];
//---
int    ExtBegin;
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
void OnInit(void)
  {
   IndicatorDigits(Digits);
//---
   SetIndexStyle(0,DRAW_LINE);
   SetIndexBuffer(0,ExtTenkanBuffer);
   SetIndexDrawBegin(0,InpTenkan-1);
   SetIndexLabel(0,"Tenkan Sen");
//---
   SetIndexStyle(1,DRAW_LINE);
   SetIndexBuffer(1,ExtKijunBuffer);
   SetIndexDrawBegin(1,InpKijun-1);
   SetIndexLabel(1,"Kijun Sen");
//---
   ExtBegin=InpKijun;
   if(ExtBegin<InpTenkan)
      ExtBegin=InpTenkan;
//---
   SetIndexStyle(2,DRAW_HISTOGRAM,STYLE_DOT);
   SetIndexBuffer(2,ExtSpanA_Buffer);
   SetIndexDrawBegin(2,InpKijun+ExtBegin-1);
   SetIndexShift(2,InpKijun);
   SetIndexLabel(2,NULL);
   SetIndexStyle(5,DRAW_LINE,STYLE_DOT);
   SetIndexBuffer(5,ExtSpanA2_Buffer);
   SetIndexDrawBegin(5,InpKijun+ExtBegin-1);
   SetIndexShift(5,InpKijun);
   SetIndexLabel(5,"Senkou Span A");
//---
   SetIndexStyle(3,DRAW_HISTOGRAM,STYLE_DOT);
   SetIndexBuffer(3,ExtSpanB_Buffer);
   SetIndexDrawBegin(3,InpKijun+InpSenkou-1);
   SetIndexShift(3,InpKijun);
   SetIndexLabel(3,NULL);
   SetIndexStyle(6,DRAW_LINE,STYLE_DOT);
   SetIndexBuffer(6,ExtSpanB2_Buffer);
   SetIndexDrawBegin(6,InpKijun+InpSenkou-1);
   SetIndexShift(6,InpKijun);
   SetIndexLabel(6,"Senkou Span B");
//---
   SetIndexStyle(4,DRAW_LINE);
   SetIndexBuffer(4,ExtChikouBuffer);
   SetIndexShift(4,-InpKijun);
   SetIndexLabel(4,"Chikou Span");
//--- initialization done
  }
//+------------------------------------------------------------------+
//| Ichimoku Kinko Hyo                                               |
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
   double high_value,low_value;
//---
   if(rates_total<=InpTenkan || rates_total<=InpKijun || rates_total<=InpSenkou)
      return(0);
//--- counting from 0 to rates_total
   ArraySetAsSeries(ExtTenkanBuffer,false);
   ArraySetAsSeries(ExtKijunBuffer,false);
   ArraySetAsSeries(ExtSpanA_Buffer,false);
   ArraySetAsSeries(ExtSpanB_Buffer,false);
   ArraySetAsSeries(ExtChikouBuffer,false);
   ArraySetAsSeries(ExtSpanA2_Buffer,false);
   ArraySetAsSeries(ExtSpanB2_Buffer,false);
   ArraySetAsSeries(open,false);
   ArraySetAsSeries(high,false);
   ArraySetAsSeries(low,false);
   ArraySetAsSeries(close,false);
//--- initial zero
   if(prev_calculated<1)
     {
      for(i=0; i<InpTenkan; i++)
         ExtTenkanBuffer[i]=0.0;
      for(i=0; i<InpKijun; i++)
         ExtKijunBuffer[i]=0.0;
      for(i=0; i<ExtBegin; i++)
        {
         ExtSpanA_Buffer[i]=0.0;
         ExtSpanA2_Buffer[i]=0.0;
        }
      for(i=0; i<InpSenkou; i++)
        {
         ExtSpanB_Buffer[i]=0.0;
         ExtSpanB2_Buffer[i]=0.0;
        }
     }
//--- Tenkan Sen
   pos=InpTenkan-1;
   if(prev_calculated>InpTenkan)
      pos=prev_calculated-1;
   for(i=pos; i<rates_total; i++)
     {
      high_value=high[i];
      low_value=low[i];
      k=i+1-InpTenkan;
      while(k<=i)
        {
         if(high_value<high[k])
            high_value=high[k];
         if(low_value>low[k])
            low_value=low[k];
         k++;
        }
      ExtTenkanBuffer[i]=(high_value+low_value)/2;
     }
//--- Kijun Sen
   pos=InpKijun-1;
   if(prev_calculated>InpKijun)
      pos=prev_calculated-1;
   for(i=pos; i<rates_total; i++)
     {
      high_value=high[i];
      low_value=low[i];
      k=i+1-InpKijun;
      while(k<=i)
        {
         if(high_value<high[k])
            high_value=high[k];
         if(low_value>low[k])
            low_value=low[k];
         k++;
        }
      ExtKijunBuffer[i]=(high_value+low_value)/2;
     }
//--- Senkou Span A
   pos=ExtBegin-1;
   if(prev_calculated>ExtBegin)
      pos=prev_calculated-1;
   for(i=pos; i<rates_total; i++)
     {
      ExtSpanA_Buffer[i]=(ExtKijunBuffer[i]+ExtTenkanBuffer[i])/2;
      ExtSpanA2_Buffer[i]=ExtSpanA_Buffer[i];
     }
//--- Senkou Span B
   pos=InpSenkou-1;
   if(prev_calculated>InpSenkou)
      pos=prev_calculated-1;
   for(i=pos; i<rates_total; i++)
     {
      high_value=high[i];
      low_value=low[i];
      k=i+1-InpSenkou;
      while(k<=i)
        {
         if(high_value<high[k])
            high_value=high[k];
         if(low_value>low[k])
            low_value=low[k];
         k++;
        }
      ExtSpanB_Buffer[i]=(high_value+low_value)/2;
      ExtSpanB2_Buffer[i]=ExtSpanB_Buffer[i];
     }
//--- Chikou Span
   pos=0;
   if(prev_calculated>1)
      pos=prev_calculated-1;
   for(i=pos; i<rates_total; i++)
      ExtChikouBuffer[i]=close[i];
//---
   return(rates_total);
  }
//+------------------------------------------------------------------+
