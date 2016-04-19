// https://www.forex-tsd.com/forum/exclusive-forum/advanced-elite/11502-adaptive-lookback-indicators?p=1803315#post1803315
//------------------------------------------------------------------
#property copyright "mladen"
#property link      "www.forex-tsd.com"
//------------------------------------------------------------------
#property indicator_separate_window
#property indicator_buffers    4
#property indicator_color1     clrLimeGreen
#property indicator_color2     clrOrange
#property indicator_color3     clrOrange
#property indicator_color4     clrRed
#property indicator_width1     2
#property indicator_width2     2
#property indicator_width3     2
#property indicator_style4     STYLE_DASH
#property indicator_minimum    0
#property indicator_maximum    100
#property indicator_levelcolor clrMediumOrchid

//
//
//
//
//

extern int            RsiPeriod    = 14;          // Rsi Period
extern double         FastEma      = 12;          // Fast Ema for Rsi Macd
extern double         SlowEma      = 26;          // Slow Ema for Rsi Macd
extern double         SignalPeriod = 9;           // Signal Ema for Rsi Macd
extern ENUM_MA_METHOD SignalMaMode = MODE_EMA;    // Signal average mode
extern int            Price        = PRICE_CLOSE; // Price to use
extern double         levelOb      = 70;          // Overbought level
extern double         levelOs      = 30;          // Oversold level


double rsi[];
double rsiUA[];
double rsiUB[];
double sig[];
double macd[];
double prices[];
double slope[];

//------------------------------------------------------------------
//
//------------------------------------------------------------------
int init()
{
   IndicatorBuffers(7);
   SetIndexBuffer(0,rsi);
   SetIndexBuffer(1,rsiUA);
   SetIndexBuffer(2,rsiUB);
   SetIndexBuffer(3,sig);
   SetIndexBuffer(4,macd);
   SetIndexBuffer(5,prices);
   SetIndexBuffer(6,slope);
   SetLevelValue(0,levelOb);
   SetLevelValue(1,levelOs);
return(0);
}
int deinit(){ return(0); }

//------------------------------------------------------------------
//
//------------------------------------------------------------------
//
//
//
//
//

int start()
{

    int i,counted_bars=IndicatorCounted();
      if(counted_bars<0) return(-1);
      if(counted_bars>0) counted_bars--;
         int limit = MathMin(Bars-counted_bars,Bars-1);

    //
    //
    //
    //
    //

    if (slope[limit] == 1) CleanPoint(limit,rsiUA,rsiUB);
    for(i = limit; i >= 0; i--)
    {
       prices[i] = iMA(NULL,0,1,0,MODE_SMA,Price,i);
       double noise = 0, vhf = 0, fastPeriod=FastEma;
       double max   = prices[i];
       double min   = prices[i];
       for (int k=0; k<FastEma && (i+k+1)<Bars; k++)
       {
           noise += MathAbs(prices[i+k]-prices[i+k+1]);
           max    = MathMax(prices[i+k],max);
           min    = MathMin(prices[i+k],min);
       }
       if (noise>0) vhf = (max-min)/noise;
       if (vhf>0) fastPeriod = -MathLog(vhf)*FastEma;

      //
      //
      //
      //

      noise = 0; vhf = 0; double slowPeriod=SlowEma;
      max   = prices[i];
      min   = prices[i];
         for (k=0; k<SlowEma && (i+k+1)<Bars; k++)
         {
               noise += MathAbs(prices[i+k]-prices[i+k+1]);
               max    = MathMax(prices[i+k],max);
               min    = MathMin(prices[i+k],min);
         }
         if (noise>0) vhf = (max-min)/noise;
         if (vhf>0) slowPeriod = -MathLog(vhf)*SlowEma;


      //
      //
      //
      //
      //

      macd[i] = iEma(prices[i],MathMin(fastPeriod,slowPeriod),i,0)-iEma(prices[i],MathMax(fastPeriod,slowPeriod),i,1);
   }
   for(i=limit; i>=0; i--) rsi[i] = iRSIOnArray(macd,0,RsiPeriod,i);
   for(i=limit; i>=0; i--)
   {
      sig[i]   = iMAOnArray(rsi,0,SignalPeriod,0,SignalMaMode,i);
      rsiUA[i] = EMPTY_VALUE;
      rsiUB[i] = EMPTY_VALUE;
      slope[i] = slope[i+1];
         if (rsi[i] > rsi[i+1]) slope[i] =  1;
         if (rsi[i] < rsi[i+1]) slope[i] = -1;
         if (slope[i]==-1) PlotPoint(i,rsiUA,rsiUB,rsi);
    }
return(0);
}

//-------------------------------------------------------------------
//
//-------------------------------------------------------------------
//
//
//
//
//

double workEma[][2];
double iEma(double price, double period, int r, int instanceNo=0)
{
   if (ArrayRange(workEma,0)!= Bars) ArrayResize(workEma,Bars); r=Bars-r-1;
   if (period<=1) { workEma[r][instanceNo]=price; return(price); }

   //
   //
   //
   //
   //

   workEma[r][instanceNo] = price;
   double alpha = 2.0 / (1.0+period);
   if (r>0)
          workEma[r][instanceNo] = workEma[r-1][instanceNo]+alpha*(price-workEma[r-1][instanceNo]);
   return(workEma[r][instanceNo]);
}

//-------------------------------------------------------------------
//
//-------------------------------------------------------------------
//
//
//
//
//

void CleanPoint(int i,double& first[],double& second[])
{
   if (i>=Bars-3) return;
   if ((second[i]  != EMPTY_VALUE) && (second[i+1] != EMPTY_VALUE))
        second[i+1] = EMPTY_VALUE;
   else
      if ((first[i] != EMPTY_VALUE) && (first[i+1] != EMPTY_VALUE) && (first[i+2] == EMPTY_VALUE))
          first[i+1] = EMPTY_VALUE;
}

void PlotPoint(int i,double& first[],double& second[],double& from[])
{
   if (i>=Bars-2) return;
   if (first[i+1] == EMPTY_VALUE)
      if (first[i+2] == EMPTY_VALUE)
            { first[i]  = from[i];  first[i+1]  = from[i+1]; second[i] = EMPTY_VALUE; }
      else  { second[i] =  from[i]; second[i+1] = from[i+1]; first[i]  = EMPTY_VALUE; }
   else     { first[i]  = from[i];                           second[i] = EMPTY_VALUE; }
}
