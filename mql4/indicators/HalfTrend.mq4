//+----------------------------------------------------------------------+
//|                                                  HalfTrend-v1.02.mq4 |
//|                                     Copyright 2014, FxProSystems.com |
//|                                              Based on Ozymandias.mq4 |
//+----------------------------------------------------------------------+
#property indicator_chart_window
#property indicator_buffers 6
#property indicator_color1 DodgerBlue  // up[]
#property indicator_width1 2
#property indicator_color2 Red       // down[]
#property indicator_width2 2
#property indicator_color3 DodgerBlue  // atrlo[]
#property indicator_width3 1
#property indicator_color4 Red       // atrhi[]
#property indicator_width4 1
#property indicator_color5 DodgerBlue  // arrup[]
#property indicator_width5 1
#property indicator_color6 Red      // arrdwn[]
#property indicator_width6 1


extern int    Amplitude        = 2;
extern bool   ShowBars         = true;
extern bool   ShowArrows       = true;
extern bool   alertsOn         = false;
extern bool   alertsOnCurrent  = false;
extern bool   alertsMessage    = false;
extern bool   alertsSound      = false;
extern bool   alertsEmail      = false;

bool nexttrend;
double minhighprice,maxlowprice;
double up[],down[],atrlo[],atrhi[],trend[];
double arrup[],arrdwn[];
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int init()
  {
   IndicatorBuffers(7); // +1 buffer - trend[]

   SetIndexBuffer(0,up);
   SetIndexStyle(0,DRAW_LINE);
   SetIndexBuffer(1,down);
   SetIndexStyle(1,DRAW_LINE);
   SetIndexBuffer(2,atrlo);
   SetIndexBuffer(3,atrhi);
   SetIndexBuffer(6,trend);
   SetIndexBuffer(4,arrup);
   SetIndexBuffer(5,arrdwn);
   SetIndexEmptyValue(0,0.0);
   SetIndexEmptyValue(1,0.0);
   SetIndexEmptyValue(6,0.0);

   if(ShowBars)
   {
      SetIndexStyle(2,DRAW_HISTOGRAM, STYLE_SOLID);
      SetIndexStyle(3,DRAW_HISTOGRAM, STYLE_SOLID);
   }
   else
   {
      SetIndexStyle(2,DRAW_NONE);
      SetIndexStyle(3,DRAW_NONE);
   }
   if(ShowArrows)
   {
     SetIndexStyle(4,DRAW_ARROW,STYLE_SOLID); SetIndexArrow(4,233);
     SetIndexStyle(5,DRAW_ARROW,STYLE_SOLID); SetIndexArrow(5,234);
   }
   else
   {
     SetIndexStyle(4,DRAW_NONE);
     SetIndexStyle(5,DRAW_NONE);
   }


   nexttrend=0;
   minhighprice= High[Bars-1];
   maxlowprice = Low[Bars-1];
   return (0);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int start()
  {
   double atr,lowprice_i,highprice_i,lowma,highma;
   int workbar=0;
   int counted_bars=IndicatorCounted();
      if(counted_bars<0) return(-1);
      if(counted_bars>0) counted_bars--;
         int limit = MathMin(Bars-counted_bars,Bars-1);

   for(int i=Bars-1; i>=0; i--)
     {
      lowprice_i=iLow(Symbol(),Period(),iLowest(Symbol(),Period(),MODE_LOW,Amplitude,i));
      highprice_i=iHigh(Symbol(),Period(),iHighest(Symbol(),Period(),MODE_HIGH,Amplitude,i));
      lowma=NormalizeDouble(iMA(NULL,0,Amplitude,0,MODE_SMA,PRICE_LOW,i),Digits);
      highma=NormalizeDouble(iMA(NULL,0,Amplitude,0,MODE_SMA,PRICE_HIGH,i),Digits);
      trend[i]=trend[i+1];
      atr=iATR(Symbol(),0,100,i)/2;

      arrup[i]  = EMPTY_VALUE;
      arrdwn[i] = EMPTY_VALUE;
      if(nexttrend==1)
        {
         maxlowprice=MathMax(lowprice_i,maxlowprice);

         if(highma<maxlowprice && Close[i]<Low[i+1])
           {
            trend[i]=1.0;
            nexttrend=0;
            minhighprice=highprice_i;
           }
        }
      if(nexttrend==0)
        {
         minhighprice=MathMin(highprice_i,minhighprice);

         if(lowma>minhighprice && Close[i]>High[i+1])
           {
            trend[i]=0.0;
            nexttrend=1;
            maxlowprice=lowprice_i;
           }
        }
      if(trend[i]==0.0)
        {
         if(trend[i+1]!=0.0)
           {
            up[i]=down[i+1];
            up[i+1]=up[i];
            arrup[i] = up[i] - 2*atr;
           }
         else
           {
            up[i]=MathMax(maxlowprice,up[i+1]);
           }
         atrhi[i] = up[i] - atr;
         atrlo[i] = up[i];
         down[i]=0.0;
        }
      else
        {
         if(trend[i+1]!=1.0)
           {
            down[i]=up[i+1];
            down[i+1]=down[i];
            arrdwn[i] = down[i] + 2*atr;
           }
         else
           {
            down[i]=MathMin(minhighprice,down[i+1]);
           }
         atrhi[i] = down[i] + atr;
         atrlo[i] = down[i];
         up[i]=0.0;
        }
     }
     manageAlerts();
   return (0);
  }
//+------------------------------------------------------------------+
//+-------------------------------------------------------------------
//|
//+-------------------------------------------------------------------
//
//
//
//
//

void manageAlerts()
{
   if (alertsOn)
   {
      if (alertsOnCurrent)
           int whichBar = 0;
      else     whichBar = 1;
         if (arrup[whichBar]  != EMPTY_VALUE) doAlert(whichBar,"up");
         if (arrdwn[whichBar] != EMPTY_VALUE) doAlert(whichBar,"down");
   }
}

//
//
//
//
//

void doAlert(int forBar, string doWhat)
{
   static string   previousAlert="nothing";
   static datetime previousTime;
   string message;

   if (previousAlert != doWhat || previousTime != Time[forBar]) {
       previousAlert  = doWhat;
       previousTime   = Time[forBar];

       //
       //
       //
       //
       //

       message =  StringConcatenate(Symbol()," at ",TimeToStr(TimeLocal(),TIME_SECONDS)," HalfTrend signal ",doWhat);
          if (alertsMessage) Alert(message);
          if (alertsEmail)   SendMail(StringConcatenate(Symbol(),"HalfTrend "),message);
          if (alertsSound)   PlaySound("alert2.wav");
   }
}
