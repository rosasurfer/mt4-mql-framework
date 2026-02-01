//+------------------------------------------------------------------+
//|                                                  mama - smoothed |
//+------------------------------------------------------------------+
#property copyright "mladen"
#property link      "www.forex-whereever.com"

#property indicator_chart_window
#property indicator_buffers  6
#property indicator_plots    6
#property strict

//
//
//

enum enPrices
         {
            pr_close,      // Close
            pr_open,       // Open
            pr_high,       // High
            pr_low,        // Low
            pr_median,     // Median
            pr_typical,    // Typical
            pr_weighted,   // Weighted
            pr_average,    // Average (high+low+open+close)/4
            pr_medianb,    // Average median body (open+close)/2
            pr_tbiased,    // Trend biased price
            pr_tbiased2,   // Trend biased (extreme) price
            pr_haclose,    // Heiken ashi close
            pr_haopen ,    // Heiken ashi open
            pr_hahigh,     // Heiken ashi high
            pr_halow,      // Heiken ashi low
            pr_hamedian,   // Heiken ashi median
            pr_hatypical,  // Heiken ashi typical
            pr_haweighted, // Heiken ashi weighted
            pr_haaverage,  // Heiken ashi average
            pr_hamedianb,  // Heiken ashi median body
            pr_hatbiased,  // Heiken ashi trend biased price
            pr_hatbiased2, // Heiken ashi trend biased (extreme) price
            pr_habclose,   // Heiken ashi (better formula) close
            pr_habopen ,   // Heiken ashi (better formula) open
            pr_habhigh,    // Heiken ashi (better formula) high
            pr_hablow,     // Heiken ashi (better formula) low
            pr_habmedian,  // Heiken ashi (better formula) median
            pr_habtypical, // Heiken ashi (better formula) typical
            pr_habweighted,// Heiken ashi (better formula) weighted
            pr_habaverage, // Heiken ashi (better formula) average
            pr_habmedianb, // Heiken ashi (better formula) median body
            pr_habtbiased, // Heiken ashi (better formula) trend biased price
            pr_habtbiased2 // Heiken ashi (better formula) trend biased (extreme) price
         };
input enPrices        inpPrice           = pr_median;      // Mama Price
input double          inpSlowLimit       = 0.05;           // Mama slow limit  
input double          inpFastLimit       = 0.5;            // Mama fast limit 
input double          inpSmthAlpha       = 10;             // Mama + Fama smoothing period
input string          __ma1__00          = "";             //.Mama settings
input int             inpMa1LineWidth    = 2;              // Line width
input color           inpMa1ColorUp      = clrSpringGreen; // Bullish color
input color           inpMa1ColorDn      = clrCrimson;     // Bearish color
input string          __ma2__00          = "";             //.Fama settings
input int             inpMa2LineWidth    = 2;              // Line width
input color           inpMa2ColorUp      = clrSpringGreen; // Bullish color
input color           inpMa2ColorDn      = clrCrimson;     // Bearish color

double ma1[],ma1Da[],ma1Db[],ma2[],ma2Da[],ma2Db[];
struct sGloStruct
{
   double alp,alpSmth,dphase,_max,_min;
   int    lim;
};
sGloStruct glo;

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

int OnInit()
{
   SetIndexBuffer(0,ma1  ,INDICATOR_DATA); SetIndexStyle(0,DRAW_LINE,EMPTY,inpMa1LineWidth,inpMa1ColorUp);
   SetIndexBuffer(1,ma1Da,INDICATOR_DATA); SetIndexStyle(1,DRAW_LINE,EMPTY,inpMa1LineWidth,inpMa1ColorDn);
   SetIndexBuffer(2,ma1Db,INDICATOR_DATA); SetIndexStyle(2,DRAW_LINE,EMPTY,inpMa1LineWidth,inpMa1ColorDn);
   SetIndexBuffer(3,ma2  ,INDICATOR_DATA); SetIndexStyle(3,DRAW_LINE,EMPTY,inpMa2LineWidth,inpMa2ColorUp);
   SetIndexBuffer(4,ma2Da,INDICATOR_DATA); SetIndexStyle(4,DRAW_LINE,EMPTY,inpMa2LineWidth,inpMa2ColorDn);
   SetIndexBuffer(5,ma2Db,INDICATOR_DATA); SetIndexStyle(5,DRAW_LINE,EMPTY,inpMa2LineWidth,inpMa2ColorDn);
   
   glo.alpSmth = (2.0/(1.0+fmax(inpSmthAlpha,1.0)));
return(INIT_SUCCEEDED);
}

//------------------------------------------------------------------------------------------------
//
//------------------------------------------------------------------------------------------------

int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime& time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
   glo.lim = (prev_calculated>0) ? rates_total-prev_calculated : rates_total-1;

   //
   //
   //
   
   struct sWrkStruct
   {
      double _prc;     
      double _smth;    
      double _detr; 
      double _per;    
      double _pha;     
      double _Q1;        
      double _I1;        
      double _JI;        
      double _JQ;        
      double _Q2;        
      double _I2;       
      double _Re;       
      double _Im;       
      double _sa;
      double cMa1;
      double cMa2;      
   };
   static sWrkStruct wrk[];
   static int        wrkSize = -1;
                 if (wrkSize<=rates_total) wrkSize = ArrayResize(wrk,rates_total+500,2000);
   
   //
   //
   //

   if (wrk[rates_total-glo.lim-1].cMa1==-1) iCleanPoint(glo.lim,rates_total,ma1Da,ma1Db);      
   if (wrk[rates_total-glo.lim-1].cMa2==-1) iCleanPoint(glo.lim,rates_total,ma2Da,ma2Db);      
   for (int i=glo.lim, r=rates_total-i-1; i>=0 && !_StopFlag; i--, r++)
   {
      #define rad2degree (180.0/M_PI)
      #define calcComp(_ind) (r>6 ?(0.0962*wrk[r]._ind+0.5769*wrk[r-2]._ind-0.5769*wrk[r-4]._ind-0.0962*wrk[r-6]._ind) *(0.075*wrk[r-1]._per+0.54) : wrk[r]._ind)
      wrk[r]._prc  = iGetPrice(inpPrice,open,high,low,close,i,rates_total);
      wrk[r]._smth = (r>3) ? (4.0*wrk[r]._prc+3.0*wrk[r-1]._prc+2.0*wrk[r-2]._prc+wrk[r-3]._prc)/10.0 : wrk[r]._prc;
      wrk[r]._detr = calcComp(_smth);
      wrk[r]._Q1   = calcComp(_detr);
      wrk[r]._I1   = (r>2) ? wrk[r-3]._detr :  wrk[r]._detr;
      wrk[r]._JI   = calcComp(_I1);
      wrk[r]._JQ   = calcComp(_Q1);
      
      //
      //
      //
      
      wrk[r]._I2 = (r==0) ? wrk[r]._I1 : 0.2*(wrk[r]._I1-wrk[r]._JQ)                             + 0.8*wrk[r-1]._I2;
      wrk[r]._Q2 = (r==0) ? wrk[r]._Q1 : 0.2*(wrk[r]._Q1+wrk[r]._JI)                             + 0.8*wrk[r-1]._Q2;
      wrk[r]._Re = (r==0) ? wrk[r]._I2 : 0.2*(wrk[r]._I2*wrk[r-1]._I2 + wrk[r]._Q2*wrk[r-1]._Q2) + 0.8*wrk[r-1]._Re;
      wrk[r]._Im = (r==0) ? wrk[r]._I2 : 0.2*(wrk[r]._I2*wrk[r-1]._Q2 - wrk[r]._Q2*wrk[r-1]._I2) + 0.8*wrk[r-1]._Im;

      if(wrk[r]._Re!=0 && wrk[r]._Im!=0)
        wrk[r]._per = 360.0/(MathArctan(wrk[r]._Im/wrk[r]._Re)*rad2degree);
        wrk[r]._per = (r==0) ?  wrk[r]._per : fmin(wrk[r]._per,1.50*wrk[r-1]._per);
        wrk[r]._per = (r==0) ?  wrk[r]._per : fmax(wrk[r]._per,0.67*wrk[r-1]._per);
        wrk[r]._per = fmin(fmax(wrk[r]._per,6),50);
        wrk[r]._per = (r==0) ?  wrk[r]._per : 0.2*wrk[r]._per+0.8*wrk[r-1]._per;
      
      if(wrk[r]._I1!=0) wrk[r]._pha = MathArctan(wrk[r]._Q1/wrk[r]._I1)*rad2degree;
        glo.dphase = (r==0) ? 0 : fmax(wrk[r-1]._pha-wrk[r]._pha,1);
        glo.alp    = (glo.dphase!=0) ? fmax(fmin(inpFastLimit/glo.dphase,inpFastLimit),inpSlowLimit) : 1;
        wrk[r]._sa = (r>0) ? wrk[r-1]._sa+glo.alpSmth*(glo.alp-wrk[r-1]._sa) : 0;
   
        ma1[i] = (r==0) ? wrk[r]._prc : wrk[r]._sa*wrk[r]._prc + (1.0- wrk[r]._sa)*ma1[i+1];    //MAMA
        ma2[i] = (r==0) ? wrk[r]._prc : 0.5*wrk[r]._sa*ma1[i]  + (1.0-0.5*wrk[r]._sa)*ma2[i+1]; //FAMA
        wrk[r].cMa1 = (ma1[i]>ma2[i]) ? 1 : (ma1[i]<ma2[i]) ? -1 : (r>0) ? wrk[r-1].cMa2 : 0;
        wrk[r].cMa2 = wrk[r].cMa1;
        if (wrk[r].cMa1==-1) iPlotPoint(i,rates_total,ma1Da,ma1Db,ma1); else ma1Da[i] = ma1Db[i] = EMPTY_VALUE;
        if (wrk[r].cMa2==-1) iPlotPoint(i,rates_total,ma2Da,ma2Db,ma2); else ma2Da[i] = ma2Db[i] = EMPTY_VALUE;
   }
return(rates_total);
}

//--------------------------------------------------------------------------------------------------------------------------------------
//                                                                  
//--------------------------------------------------------------------------------------------------------------------------------------

template <typename T>
double iGetPrice(int tprice, T& open[], T& high[], T& low[], T& close[], int i, int bars)
{
   if (tprice>=pr_haclose)
   {
      struct sHaStruct
      {
         double open;
         double high;
         double low;
         double close;
      };
      static sHaStruct m_array[];
      static int       m_arraySize = -1;
                   if (m_arraySize<bars) m_arraySize = ArrayResize(m_array,bars+500);
                   
         //
         //
         //
                            
         #ifdef __MQL4__                  
            int r = bars-i-1;
         #else            
            int r = i;
         #endif            
         
         //
         //
         //
         
         double haOpen  = (r>0) ? (m_array[r-1].open + m_array[r-1].close)/2.0 : (open[i]+close[i])/2;;
         double haClose = (open[i]+high[i]+low[i]+close[i]) / 4.0;
         #define _prHABF(_prtype) (_prtype>=pr_habclose && _prtype<=pr_habtbiased2)
            if (_prHABF(tprice))
                  if (high[i]!=low[i])
                        haClose = (open[i]+close[i])/2.0+(((close[i]-open[i])/(high[i]-low[i]))*MathAbs((close[i]-open[i])/2.0));
                  else  haClose = (open[i]+close[i])/2.0; 
         #undef  _prHABF                  
         double haHigh  = fmax(high[i], fmax(haOpen,haClose));
         double haLow   = fmin(low[i] , fmin(haOpen,haClose));

         //
         //
         //
         
         if(haOpen<haClose) { m_array[r].high  = haLow;  m_array[r].low = haHigh; } 
         else               { m_array[r].high  = haHigh; m_array[r].low = haLow;  } 
                              m_array[r].open  = haOpen;
                              m_array[r].close = haClose;
         //
         //
         //
         
         switch (tprice)
         {
            case pr_haclose:
            case pr_habclose:    return(haClose);
            case pr_haopen:   
            case pr_habopen:     return(haOpen);
            case pr_hahigh: 
            case pr_habhigh:     return(haHigh);
            case pr_halow:    
            case pr_hablow:      return(haLow);
            case pr_hamedian:
            case pr_habmedian:   return((haHigh+haLow)/2.0);
            case pr_hamedianb:
            case pr_habmedianb:  return((haOpen+haClose)/2.0);
            case pr_hatypical:
            case pr_habtypical:  return((haHigh+haLow+haClose)/3.0);
            case pr_haweighted:
            case pr_habweighted: return((haHigh+haLow+haClose+haClose)/4.0);
            case pr_haaverage:  
            case pr_habaverage:  return((haHigh+haLow+haClose+haOpen)/4.0);
            case pr_hatbiased:
            case pr_habtbiased:
               if (haClose>haOpen)
                     return((haHigh+haClose)/2.0);
               else  return((haLow+haClose)/2.0);        
            case pr_hatbiased2:
            case pr_habtbiased2:
               if (haClose>haOpen)  return(haHigh);
               if (haClose<haOpen)  return(haLow);
                                    return(haClose);        
         }
   }
   
   //
   //
   //

   switch (tprice)
   {
      case pr_close:     return(close[i]);
      case pr_open:      return(open[i]);
      case pr_high:      return(high[i]);
      case pr_low:       return(low[i]);
      case pr_median:    return((high[i]+low[i])/2.0);
      case pr_medianb:   return((open[i]+close[i])/2.0);
      case pr_typical:   return((high[i]+low[i]+close[i])/3.0);
      case pr_weighted:  return((high[i]+low[i]+close[i]+close[i])/4.0);
      case pr_average:   return((high[i]+low[i]+close[i]+open[i])/4.0);
      case pr_tbiased:   
               if (close[i]>open[i])
                     return((high[i]+close[i])/2.0);
               else  return((low[i]+close[i])/2.0);        
      case pr_tbiased2:   
               if (close[i]>open[i]) return(high[i]);
               if (close[i]<open[i]) return(low[i]);
                                     return(close[i]);        
   }
   return(0);
}

//-------------------------------------------------------------------
//                                                                  
//-------------------------------------------------------------------

void iCleanPoint(int i, int bars,double& first[],double& second[])
{
   if (i>=bars-3) return;
   if ((second[i]  != EMPTY_VALUE) && (second[i+1] != EMPTY_VALUE))
        second[i+1] = EMPTY_VALUE;
   else
      if ((first[i]  != EMPTY_VALUE) && (first[i+1] != EMPTY_VALUE) && (first[i+2] == EMPTY_VALUE))
           first[i+1] = EMPTY_VALUE;
}

void iPlotPoint(int i, int bars,double& first[],double& second[],double& from[])
{
   if (i>=bars-2) return;
   if (first[i+1] == EMPTY_VALUE)
      if (first[i+2] == EMPTY_VALUE) 
            { first[i]  = from[i]; first[i+1]  = from[i+1]; second[i] = EMPTY_VALUE; }
      else  { second[i] = from[i]; second[i+1] = from[i+1]; first[i]  = EMPTY_VALUE; }
   else     { first[i]  = from[i];                          second[i] = EMPTY_VALUE; }
}
