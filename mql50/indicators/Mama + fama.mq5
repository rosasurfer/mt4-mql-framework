//------------------------------------------------------------------
#property copyright   "© mladen, 2018"
#property link        "mladenfx@gmail.com"
#property description "Mama - fama"
//------------------------------------------------------------------
#property indicator_chart_window
#property indicator_buffers 4
#property indicator_plots   2
#property indicator_label1  "Fama"
#property indicator_type1   DRAW_COLOR_LINE
#property indicator_color1  clrDarkGray,clrSandyBrown,clrDodgerBlue
#property indicator_width1  2
#property indicator_label2  "Mama"
#property indicator_type2   DRAW_COLOR_LINE
#property indicator_color2  clrDarkGray,clrSandyBrown,clrDodgerBlue
#property indicator_width2  2
//--- input parameters
input double             inpFastLimit = 0.5;          // Fast limit
input double             inpSlowLimit = 0.05;         // Slow limit
input ENUM_APPLIED_PRICE inpPrice     = PRICE_MEDIAN; // Price
//--- indicator buffers
double valf[],valfc[],valm[],valmc[];
//+------------------------------------------------------------------+ 
//| Custom indicator initialization function                         | 
//+------------------------------------------------------------------+ 
int OnInit()
  {
//--- indicator buffers mapping
   SetIndexBuffer(0,valf,INDICATOR_DATA);
   SetIndexBuffer(1,valfc,INDICATOR_COLOR_INDEX);
   SetIndexBuffer(2,valm,INDICATOR_DATA);
   SetIndexBuffer(3,valmc,INDICATOR_COLOR_INDEX);
//--- indicator short name assignment
   IndicatorSetString(INDICATOR_SHORTNAME,"Mama - fama ("+(string)inpFastLimit+","+(string)inpSlowLimit+")");
//---
   return (INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Custom indicator de-initialization function                      |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
  }
//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,const int prev_calculated,const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
  {
   if(Bars(_Symbol,_Period)<rates_total) return(prev_calculated);
   for(int i=(int)MathMax(prev_calculated-1,0); i<rates_total && !IsStopped(); i++)
     {
      double _fama;
      valm[i] = iMama(getPrice(inpPrice,open,close,high,low,i,rates_total),inpFastLimit,inpSlowLimit,_fama,i,rates_total);
      valf[i] = _fama;
      valfc[i] = (valf[i]>valm[i]) ? 1 : (valf[i]<valm[i]) ? 2 : (i>0) ? valfc[i-1] : 0;
      valmc[i] = valfc[i];
     }
   return(rates_total);
  }
//+------------------------------------------------------------------+
//| Custom functions                                                 |
//+------------------------------------------------------------------+
#define _mamaInstances 1
#define _mamaInstancesSize 16
double workMama[][_mamaInstances*_mamaInstancesSize];
#define _price     0
#define _smooth    1
#define _detrender 2
#define _period    3
#define _phase     4
#define _Q1        5
#define _I1        6
#define _JI        7
#define _JQ        8
#define _Q2        9
#define _I2       10
#define _Re       11
#define _Im       12
#define _sa       13
#define _mama     14
#define _fama     15
//
//---
//
double iMama(double price,double fastLimit,double slowLimit,double &retFama,int r,int bars)
  {
   if(ArrayRange(workMama,0)!=bars) ArrayResize(workMama,bars);

//
//
//
//
//

#define rad2degree (180.0/M_PI)
#define calcComp(_i,_ind) (_i>5 ?(0.0962*workMama[_i][_ind]+0.5769*workMama[_i-2][_ind]-0.5769*workMama[_i-4][_ind]-0.0962*workMama[_i-6][_ind]) *(0.075*workMama[_i-1][_period]+0.54) : workMama[_i][_ind])

   workMama[r][_price]     = price;
   workMama[r][_smooth]    = (r>3) ? (4.0*workMama[r][_price]+3.0*workMama[r-1][_price]+2.0*workMama[r-2][_price]+workMama[r-3][_price])/10.0 : price;
   workMama[r][_detrender] = calcComp(r,_smooth);
   workMama[r][_Q1]        = calcComp(r,_detrender);
   workMama[r][_I1]        = (r>2) ? workMama[r-3][_detrender] :  workMama[r][_detrender];
   workMama[r][_JI]        = calcComp(r,_I1);
   workMama[r][_JQ]        = calcComp(r,_Q1);

//
//---
//

   workMama[r][_I2] = (r==0) ? workMama[r][_I1] : 0.2*(workMama[r][_I1]-workMama[r][_JQ])                                 + 0.8*workMama[r-1][_I2];
   workMama[r][_Q2] = (r==0) ? workMama[r][_Q1] : 0.2*(workMama[r][_Q1]+workMama[r][_JI])                                 + 0.8*workMama[r-1][_Q2];
   workMama[r][_Re] = (r==0) ? workMama[r][_I2] : 0.2*(workMama[r][_I2]*workMama[r-1][_I2] + workMama[r][_Q2]*workMama[r-1][_Q2]) + 0.8*workMama[r-1][_Re];
   workMama[r][_Im] = (r==0) ? workMama[r][_I2] : 0.2*(workMama[r][_I2]*workMama[r-1][_Q2] - workMama[r][_Q2]*workMama[r-1][_I2]) + 0.8*workMama[r-1][_Im];

   if(workMama[r][_Re]!=0 && workMama[r][_Im]!=0)
      workMama[r][_period] = 360.0/(MathArctan(workMama[r][_Im]/workMama[r][_Re])*rad2degree);
   workMama[r][_period] = (r==0) ? workMama[r][_period] : MathMin(workMama[r][_period],1.50*workMama[r-1][_period]);
   workMama[r][_period] = (r==0) ? workMama[r][_period] : MathMax(workMama[r][_period],0.67*workMama[r-1][_period]);
   workMama[r][_period] = MathMin(MathMax(workMama[r][_period],6),50);
   workMama[r][_period] = (r==0) ? workMama[r][_period] : 0.2*workMama[r][_period]+0.8*workMama[r-1][_period];

//
//---
//

   if(workMama[r][_I1]!=0) workMama[r][_phase]=MathArctan(workMama[r][_Q1]/workMama[r][_I1])*rad2degree;
   double DeltaPhase = (r==0) ? 0 : MathMax(workMama[r-1][_phase]-workMama[r][_phase],1);
   double Alpha      = (DeltaPhase!=0) ? MathMax(MathMin(fastLimit/DeltaPhase,fastLimit),slowLimit) : 1;
   workMama[r][_sa]=Alpha;

//
//---
//

   workMama[r][_mama] = (r==0) ? price :     workMama[r][_sa]*workMama[r][_price] + (1.0-    workMama[r][_sa])*workMama[r-1][_mama];
   workMama[r][_fama] = (r==0) ? price : 0.5*workMama[r][_sa]*workMama[r][_mama]  + (1.0-0.5*workMama[r][_sa])*workMama[r-1][_fama]; retFama = workMama[r][_fama];
   return(workMama[r][_mama]);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double getPrice(ENUM_APPLIED_PRICE tprice,const double &open[],const double &close[],const double &high[],const double &low[],int i,int _bars)
  {
   if(i>=0)
      switch(tprice)
        {
         case PRICE_CLOSE:     return(close[i]);
         case PRICE_OPEN:      return(open[i]);
         case PRICE_HIGH:      return(high[i]);
         case PRICE_LOW:       return(low[i]);
         case PRICE_MEDIAN:    return((high[i]+low[i])/2.0);
         case PRICE_TYPICAL:   return((high[i]+low[i]+close[i])/3.0);
         case PRICE_WEIGHTED:  return((high[i]+low[i]+close[i]+close[i])/4.0);
        }
   return(0);
  }
//+------------------------------------------------------------------+
