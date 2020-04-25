/**
 * Fractal Dimension Index (presumably Ehlers)
 *
 * @see  https://www.tradingview.com/script/GyR8LJq0-Fractal-Dimension-Index-FDI/
 * @see  https://www.forexfactory.com/showthread.php?t=716482&page=17                          [formulas & extensive details]
 */





//+------------------------------------------------------------------------------------------------------------------+
//|                                                                              fractal_dimension.mq4               |
//|                                                                              iliko [arcsin5@netscape.net]        |
//|                                                                                                                  |
//|                                                                                                                  |
//|  The Fractal Dimension Index determines the amount of market volatility. The easiest way to use this indicator is|
//|  to understand that a value of 1.5 suggests the market is acting in a completely random fashion.                 |
//|  As the market deviates from 1.5, the opportunity for earning profits is increased in proportion                 |
//|  to the amount of deviation.                                                                                     |
//|  But be carreful, the indicator does not show the direction of trends !!                                         |
//|                                                                                                                  |
//|  The indicator is RED when the market is in a trend. And it is blue when there is a high volatility.             |
//|  When the FDI changes its color from red to blue, it means that a trend is finishing, the market becomes         |
//|  erratic and a high volatility is present. Usually, these "blue times" do not go for a long time.They come before|
//|  a new trend.                                                                                                    |
//|                                                                                                                  |
//|  For more informations, see                                                                                      |
//|  http://www.forex-tsd.com/suggestions-trading-systems/6119-tasc-03-07-fractal-dimension-index.html               |
//|                                                                                                                  |
//|                                                                                                                  |
//|  HOW TO USE INPUT PARAMETERS :                                                                                   |
//|  -----------------------------                                                                                   |
//|                                                                                                                  |
//|      1) e_period [ integer >= 1 ]                                              =>  30                            |
//|                                                                                                                  |
//|         The indicator will compute the historical market volatility over this period.                            |
//|         Choose its value according to the average of trend lengths.                                              |
//|                                                                                                                  |
//|      2) e_type_data [ int = {PRICE_CLOSE = 0,                                                                    |
//|                              PRICE_OPEN  = 1,                                                                    |
//|                              PRICE_HIGH  = 2,                                                                    |
//|                              PRICE_LOW   = 3,                                                                    |
//|                              PRICE_MEDIAN    (high+low)/2              = 4,                                      |
//|                              PRICE_TYPICAL   (high+low+close)/3        = 5,                                      |
//|                              PRICE_WEIGHTED  (high+low+close+close)/4  = 6}     => PRICE_CLOSE                   |
//|                                                                                                                  |
//|         Defines on which price type the Fractal Dimension is computed.                                           |
//|                                                                                                                  |
//|      3) e_random_line [ 0.0 < double < 2.0 ]                                   => 1.5                            |
//|                                                                                                                  |
//|         Defines your separation betwen a trend market (red) and an erratic/high volatily one.                    |
//|                                                                                                                  |
//| v1.0 - February 2007                                                                                            |
//+------------------------------------------------------------------------------------------------------------------+
#property link      "arcsin5@netscape.net"
//----
#property indicator_separate_window
#property indicator_levelcolor LimeGreen
#property indicator_levelwidth 1
#property indicator_levelstyle STYLE_DASH
#property indicator_buffers 2
#property indicator_color1 Blue
#property indicator_color2 Red
#property indicator_width1 2
#property indicator_width2 2
//************************************************************
// Input parameters
//************************************************************
extern int    e_period      =30;
extern int    e_type_data   =PRICE_CLOSE;
extern double e_random_line =1.5;               // Indicator triggering is defined by the value of the following input parameter:
//************************************************************
// Constant
//************************************************************
string INDICATOR_NAME="FDI";
string FILENAME      ="___fractal_dimension.mq4";
double LOG_2;
//************************************************************
// Private vars
//************************************************************
//---- input buffer
double ExtInputBuffer[];
//---- output buffer
double ExtOutputBufferUp[];
double ExtOutputBufferDown[];
int g_period_minus_1;
//+-----------------------------------------------------------------------+
//| FUNCTION : init                                                       |
//| Initialization function                                               |
//| Check the user input parameters and convert them in appropriate types.|
//+-----------------------------------------------------------------------+
int init()
  {
// Check e_period input parameter
   if(e_period<2)
     {
      Alert("[ 10-ERROR  "+FILENAME+" ] input parameter \"e_period\" must be >= 1 ("+e_period+")");
      return(-1);
     }
   if(e_type_data<PRICE_CLOSE || e_type_data>PRICE_WEIGHTED)
     {
      Alert("[ 20-ERROR  "+FILENAME+" ] input parameter \"e_type_data\" unknown ("+e_type_data+")");
      return(-1);
     }
   if(e_random_line<0.0 || e_random_line>2.0)
     {
      Alert("[ 30-ERROR  "+FILENAME+" ] input parameter \"e_random_line\" = "+e_random_line+" out of range ( 0.0 < e_random_line < 2.0 )");
      return(-1);
     }
   IndicatorBuffers(3);
   SetIndexBuffer(0,ExtOutputBufferUp);
   SetIndexStyle(0,DRAW_LINE,STYLE_SOLID,2);
   SetIndexBuffer(1,ExtOutputBufferDown);
   SetIndexStyle(1,DRAW_LINE,STYLE_SOLID,2);
   SetIndexBuffer(2,ExtInputBuffer);
   SetLevelValue(0,e_random_line);
   IndicatorShortName(INDICATOR_NAME);
   SetIndexLabel(0,INDICATOR_NAME);
   SetIndexDrawBegin(0,2*e_period);
   g_period_minus_1=e_period-1;
   LOG_2=MathLog(2.0);
//----
   return(0);
  }
//+------------------------------------------------------------------+
//| FUNCTION : deinit                                                |
//| Custor indicator deinitialization function                       |
//+------------------------------------------------------------------+
int deinit()
  {
   return(0);
  }
//+------------------------------------------------------------------+
//| FUNCTION : start                                                 |
//| This callback is fired by metatrader for each tick               |
//+------------------------------------------------------------------+
int start()
  {
   int counted_bars=IndicatorCounted();
   if(counted_bars<0) return(-1);
   if(counted_bars>0) counted_bars--;
   int limit=Bars-counted_bars;
   if(counted_bars==0) limit-=1+e_period;

   _computeLastNbBars(limit);
//----
   return(0);
  }
//+================================================================================================================+
//+=== FUNCTION : _computeLastNbBars                                                                            ===+
//+===                                                                                                          ===+
//+===                                                                                                          ===+
//+=== This callback is fired by metatrader for each tick                                                       ===+
//+===                                                                                                          ===+
//+=== In :                                                                                                     ===+
//+===    - lastBars : these "n" last bars must be repainted                                                    ===+
//+===                                                                                                          ===+
//+================================================================================================================+
//+------------------------------------------------------------------+
//| FUNCTION : _computeLastNbBars                                    |
//| This callback is fired by metatrader for each tick                |
//| In : - lastBars : these "n" last bars must be repainted           |
//+------------------------------------------------------------------+
void _computeLastNbBars(int lastBars)
  {
   double tmp_close[],tmp_open[],tmp_high[],tmp_low[];
   ArrayCopy(tmp_close,Close);
   ArrayCopy(tmp_open,Open);
   ArrayCopy(tmp_high,High);
   ArrayCopy(tmp_low,Low);
   int pos;
   switch(e_type_data)
     {
      case PRICE_CLOSE    : _computeFdi( lastBars, tmp_close); break;
      case PRICE_OPEN     : _computeFdi( lastBars, tmp_open); break;
      case PRICE_HIGH     : _computeFdi( lastBars, tmp_high); break;
      case PRICE_LOW      : _computeFdi( lastBars, tmp_low); break;
      case PRICE_MEDIAN   :
         for(pos=lastBars; pos>=0; pos--)ExtInputBuffer[pos]=(tmp_high[pos]+tmp_low[pos])/2.0; _computeFdi(lastBars,ExtInputBuffer);
         break;
      case PRICE_TYPICAL  :
         for(pos=lastBars; pos>=0; pos--)ExtInputBuffer[pos]=(tmp_high[pos]+tmp_low[pos]+tmp_close[pos])/3.0; _computeFdi(lastBars,ExtInputBuffer);
         break;
      case PRICE_WEIGHTED :
         for(pos=lastBars; pos>=0; pos--)ExtInputBuffer[pos]=(tmp_high[pos]+tmp_low[pos]+tmp_close[pos]+tmp_close[pos])/4.0; _computeFdi(lastBars,ExtInputBuffer);
         break;
      default :
         Alert("[ 20-ERROR  "+FILENAME+" ] the imput parameter e_type_data <"+e_type_data+"> is unknown");
     }
  }
//+------------------------------------------------------------------+
//| FUNCTION : _computeFdi                                           |
//| Compute FDI values from input data.                              |
//| In :                                                             |
//|    - lastBars : these "n" last bars must be repainted            |
//|    - inputData : data array on which the FDI will be applied     |
//+------------------------------------------------------------------+
void _computeFdi(int lastBars,double &inputData[])
  {
   int    pos,iteration;
   double diff,priorDiff;
   double length;
   double priceMax,priceMin;
   double fdi;
//----
   for(pos=lastBars; pos>=0; pos--)
     {
      priceMax=_highest( e_period, pos, inputData );
      priceMin=_lowest( e_period, pos, inputData );
      length   =0.0;
      priorDiff=0.0;
      //----
      for(iteration=0; iteration<g_period_minus_1; iteration++)
        {
         if(( priceMax-priceMin)>0.0)
           {
            diff=(inputData[pos+iteration]-priceMin)/(priceMax-priceMin);
            if(iteration>0)
              {
               length+=MathSqrt(MathPow(diff-priorDiff,2.0)+(1.0/MathPow(e_period,2.0)));
              }
            priorDiff=diff;
           }
        }
      if(length>0.0)
        {
         fdi=1.0+(MathLog(length)+LOG_2)/MathLog(2*e_period);
        }
      else
        {
/*
         ** The FDI algorithm suggests in this case a zero value.
         ** I prefer to use the previous FDI value.
         */
         fdi=0.0;
        }
      if(fdi>e_random_line)
        {
         ExtOutputBufferUp[pos]  =fdi;
         ExtOutputBufferUp[pos+1]=MathMin( ExtOutputBufferUp[pos+1], ExtOutputBufferDown[pos+1] );
         ExtOutputBufferDown[pos]=EMPTY_VALUE;
        }
      else
        {
         ExtOutputBufferDown[pos]  =fdi;
         ExtOutputBufferDown[pos+1]=MathMin( ExtOutputBufferUp[pos+1], ExtOutputBufferDown[pos+1] );
         ExtOutputBufferUp[pos]=EMPTY_VALUE;
        }
     }
  }
//+------------------------------------------------------------------+
//| FUNCTION : _highest                                              |
//| Search for the highest value in an array data                    |
//| In :                                                             |
//|    - n : find the highest on these n data                        |
//|    - pos : begin to search for from this index                   |
//|    - inputData : data array on which the searching for is done   |
//|                                                                  |
//| Return : the highest value                                       |                                                 |
//+------------------------------------------------------------------+
double _highest(int n,int pos,double &inputData[])
  {
   int length=pos+n;
   double highest=0.0;
//----
   for(int i=pos; i<length; i++)
     {
      if(inputData[i]>highest)highest=inputData[i];
     }
   return(highest);
  }
//+------------------------------------------------------------------+
//| FUNCTION : _lowest                                               |                                                                                                          ===+
//| Search for the lowest value in an array data                     |
//| In :                                                             |
//|    - n : find the hihest on these n data                         |
//|    - pos : begin to search for from this index                   |
//|    - inputData : data array on which the searching for is done   |
//|                                                                  |
//| Return : the highest value                                       |
//+------------------------------------------------------------------+
double _lowest(int n,int pos,double &inputData[])
  {
   int length=pos+n;
   double lowest=9999999999.0;
//----
   for(int i=pos; i<length; i++)
     {
      if(inputData[i]<lowest)lowest=inputData[i];
     }
   return(lowest);
  }
//+------------------------------------------------------------------+
