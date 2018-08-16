//+------------------------------------------------------------------+
//|                                                    ATR ratio.mq4 |
//|                         Copyright © 2005, Luis Guilherme Damiani |
//|                                      http://www.damianifx.com.br |
//+------------------------------------------------------------------+
#property copyright "Copyright © 2005, Luis Guilherme Damiani"
#property link      "http://www.damianifx.com.br"

#property indicator_separate_window
#property indicator_buffers 2
#property indicator_color1 Silver
#property indicator_color2 Violet
//---- input parameters
extern int       short_atr=7;
extern int       long_atr=49;
extern double    triglevel=1.00;
//---- buffers
double ExtMapBuffer1[];
double ExtMapBuffer2[];
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int init()
  {
//---- indicators
   SetIndexStyle(0,DRAW_LINE);
   SetIndexBuffer(0,ExtMapBuffer1);
   SetIndexStyle(1,DRAW_LINE);
   SetIndexBuffer(1,ExtMapBuffer2);
//----
   return(0);
  }
//+------------------------------------------------------------------+
//| Custor indicator deinitialization function                       |
//+------------------------------------------------------------------+
int deinit()
  {
//----

//----
   return(0);
  }
//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int start()
  {
   int    counted_bars=IndicatorCounted();
   //Comment("ATR ratio= "+short_atr+" / "+long_atr);
   for(int i=0;i<Bars-counted_bars;i++)
   {
      ExtMapBuffer1[i]=triglevel;
      double sa=iATR(NULL,0,short_atr,i);
      ExtMapBuffer2[i]= sa/iATR(NULL,0,long_atr,i);
   }
//----

//----
   return(0);
  }
//+------------------------------------------------------------------+
