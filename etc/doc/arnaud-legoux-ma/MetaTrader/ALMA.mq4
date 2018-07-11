//+------------------------------------------------------------------+
//|                                                      ALMA_v1.mq4 |
//| ALMA by Arnaud Legoux / Dimitris Kouzis-Loukas / Anthony Cascino |
//|                                             www.arnaudlegoux.com |
//|                         Written by IgorAD,igorad2003@yahoo.co.uk |
//|            http://finance.groups.yahoo.com/group/TrendLaboratory |
//+------------------------------------------------------------------+
#property copyright "Copyright © 2010, TrendLaboratory"
#property link      "http://finance.groups.yahoo.com/group/TrendLaboratory"
//---- indicator settings
#property indicator_chart_window
#property indicator_buffers 3
#property indicator_color1 Yellow
#property indicator_color2 LightBlue
#property indicator_color3 Tomato
#property indicator_width1 2
#property indicator_width2 2
#property indicator_width3 2
//---- indicator parameters
extern int     Price             =   0;  //Price Mode (0...6)
extern int     WindowSize        =   9;  //Window Size
extern double  Sigma             = 6.0;  //Sigma parameter
extern double  Offset            =0.85;  //Offset of Gaussian distribution (0...1)
extern double  PctFilter         =   0;  //Dynamic filter in decimal
extern int     Shift             =   0;  //
extern int     ColorMode         =   0;  //0-on,1-off
extern int     ColorBarBack      =   1;  //
extern int     AlertMode         =   0;  //Sound Alert switch (0-off,1-on)
extern int     WarningMode       =   0;  //Sound Warning switch(0-off,1-on)
//---- indicator buffers
double     ALMA[];
double     Uptrend[];
double     Dntrend[];
double     trend[];
double     Del[];

int        draw_begin;
bool       UpTrendAlert=false, DownTrendAlert=false;
double     wALMA[];
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int init()
  {
//---- indicator buffers mapping
   IndicatorBuffers(5);
   SetIndexBuffer(0,ALMA);
   SetIndexBuffer(1,Uptrend);
   SetIndexBuffer(2,Dntrend);
   SetIndexBuffer(3,trend);
   SetIndexBuffer(4,Del);
//---- drawing settings
   SetIndexStyle(0,DRAW_LINE);
   SetIndexStyle(1,DRAW_LINE);
   SetIndexStyle(2,DRAW_LINE);
   draw_begin = WindowSize;
   SetIndexDrawBegin(0,draw_begin);
   SetIndexDrawBegin(1,draw_begin);
   SetIndexDrawBegin(2,draw_begin);
   SetIndexShift(0,Shift);
   SetIndexShift(1,Shift);
   SetIndexShift(2,Shift);
   IndicatorDigits(MarketInfo(Symbol(),MODE_DIGITS)+1);
//---- name for DataWindow and indicator subwindow label
   IndicatorShortName("ALMA("+WindowSize +")");
   SetIndexLabel(0,"ALMA");
   SetIndexLabel(1,"ALMA Uptrend");
   SetIndexLabel(2,"ALMA Dntrend");
//----

   double m = MathFloor(Offset * (WindowSize - 1));   // pewa: Baroffset mit dem Scheitelpunkt der Gewichtung
   double s = WindowSize/Sigma;

   ArrayResize(wALMA,WindowSize);
   double wsum = 0;
   for (int i=0;i < WindowSize;i++)
   {
   wALMA[i] = MathExp( -((i-m)*(i-m)) / (2*s*s));
   wsum += wALMA[i];
   }

   for (i=0;i < WindowSize;i++) wALMA[i] = wALMA[i]/wsum;

   return(0);
  }
//+------------------------------------------------------------------+
//| ALMA_v1                                                          |
//+------------------------------------------------------------------+
int start()
{
   int limit,shift,i;
   int counted_bars=IndicatorCounted();
//----
   if(counted_bars<1)
   {
      for(i=Bars-1;i>0;i--)
      {
      ALMA[i]=EMPTY_VALUE;
      Uptrend[i]=EMPTY_VALUE;
      Dntrend[i]=EMPTY_VALUE;
      }
   }
//----
   if(counted_bars>0) counted_bars--;
   limit=Bars-counted_bars;

//----
   for(shift=limit; shift>=0; shift--)
   {

   if (shift > Bars - WindowSize) continue;

   double sum  = 0;
   double wsum = 0;

      for(i=0;i < WindowSize;i++)
      {
         if (i < WindowSize)
         {
         sum += wALMA[i] * iMA(NULL,0,1,0,0,Price,shift + (WindowSize - 1 - i));

         }
      }

   //if(wsum != 0)
   ALMA[shift] = sum;

      if(PctFilter>0)
      {
      Del[shift] = MathAbs(ALMA[shift] - ALMA[shift+1]);

      double sumdel=0;
      for (int j=0;j<=WindowSize-1;j++) sumdel = sumdel+Del[shift+j];
      double AvgDel = sumdel/WindowSize;

      double sumpow = 0;
      for (j=0;j<=WindowSize-1;j++) sumpow+=MathPow(Del[j+shift]-AvgDel,2);
      double StdDev = MathSqrt(sumpow/WindowSize);

      double Filter = PctFilter * StdDev;

      if( MathAbs(ALMA[shift]-ALMA[shift+1]) < Filter ) ALMA[shift]=ALMA[shift+1];
      }
      else
      Filter=0;


      if (ColorMode>0)
      {
         trend[shift] = trend[shift+1];
         if (ALMA[shift] - ALMA[shift+1] > Filter) trend[shift] = 1;
         if (ALMA[shift+1] - ALMA[shift] > Filter) trend[shift] =-1;

         if (trend[shift]>0)
         {
            Uptrend[shift] = ALMA[shift];
            if (trend[shift+ColorBarBack]<0) Uptrend[shift+ColorBarBack]=ALMA[shift+ColorBarBack];
            Dntrend[shift] = EMPTY_VALUE;
            if (WarningMode>0 && trend[shift+1]<0 && i==0) PlaySound("alert2.wav");
         }
         else
         if (trend[shift]<0)
         {
            Dntrend[shift] = ALMA[shift];
            if (trend[shift+ColorBarBack]>0) Dntrend[shift+ColorBarBack]=ALMA[shift+ColorBarBack];
            Uptrend[shift] = EMPTY_VALUE;
            if (WarningMode>0 && trend[shift+1]>0 && i==0) PlaySound("alert2.wav");
         }
      }
   }
//----------
   string Message;

   if ( trend[2]<0 && trend[1]>0 && Volume[0]>1 && !UpTrendAlert)
   {
   Message = " "+Symbol()+" M"+Period()+": ALMA Signal for BUY";
   if ( AlertMode>0 ) Alert (Message);
   UpTrendAlert=true; DownTrendAlert=false;
   }

   if ( trend[2]>0 && trend[1]<0 && Volume[0]>1 && !DownTrendAlert)
   {
   Message = " "+Symbol()+" M"+Period()+": ALMA Signal for SELL";
   if ( AlertMode>0 ) Alert (Message);
   DownTrendAlert=true; UpTrendAlert=false;
   }



//---- done
   return(0);
}
