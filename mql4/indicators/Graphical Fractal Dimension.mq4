/**
 * Graphical Fractal Dimension Index
 *
 * @see  https://www.mql5.com/en/code/8844                                                  [Comparison to FDI, jppoton]
 * @see  http://fractalfinance.blogspot.com/2009/05/from-bollinger-to-fractal-bands.html    [Blog post, jppoton]
 *
 * @see  https://www.mql5.com/en/code/9604                                                  [Fractal Dispersion of FGDI, jppoton]
 * @see  http://fractalfinance.blogspot.com/2010/03/self-similarity-and-measure-of-it.html  [Blog post, jppoton]
 *
 * @see  https://www.mql5.com/en/code/8997                                                  [Modification for small Periods, LastViking]
 * @see  https://www.mql5.com/en/code/16916                                                 [MT5-Version, Nikolay Kositsin, based on jppoton]
 */


// @source  https://www.mql5.com/en/forum/176309/page4#comment_4308422
//+------------------------------------------------------------------+
//|                                                         FDGI.mq4 |
//|                             Copyright (c) 2016, Gehtsoft USA LLC |
//|                                            http://fxcodebase.com |
//|                                   Paypal: https://goo.gl/9Rj74e  |
//+------------------------------------------------------------------+
//|                                      Developed by : Mario Jemic  |
//|                                          mario.jemic@gmail.com   |
//|                   BitCoin : 15VCJTLaz12Amr7adHSBtL9v8XomURo9RF   |
//+------------------------------------------------------------------+

#property indicator_buffers 6
#property indicator_separate_window
#property indicator_levelcolor clrYellow

enum e_price{ CLOSE=PRICE_CLOSE, OPEN=PRICE_OPEN, LOW=PRICE_LOW, HIGH=PRICE_HIGH, MEDIAN=PRICE_MEDIAN, TYPICAL=PRICE_TYPICAL, WEIGHTED=PRICE_WEIGHTED };

extern int     Periods        = 30;
extern e_price Price_Type     = CLOSE;
extern double  Random_Line    = 1.5;
extern color   Color_buffUP   = clrLime;
extern color   Color_buffDN   = clrRed;
extern color   Color_UPbuffUP = clrLime;
extern color   Color_UPbuffDN = clrRed;
extern color   Color_DNbuffUP = clrLime;
extern color   Color_DNbuffDN = clrRed;

double buffUP[];
double buffDN[];
double UPbuffUP[];
double UPbuffDN[];
double DNbuffUP[];
double DNbuffDN[];
double Price[];

int init(){

   IndicatorShortName("FDGI");
   IndicatorBuffers(7);

   SetIndexStyle(0,DRAW_LINE,STYLE_SOLID,1,Color_buffUP);
   SetIndexBuffer(0,buffUP);
   SetIndexLabel(0,"buffUP");
   SetIndexStyle(1,DRAW_LINE,STYLE_SOLID,1,Color_buffDN);
   SetIndexBuffer(1,buffDN);
   SetIndexLabel(1,"buffDN");
   SetIndexStyle(2,DRAW_LINE,STYLE_SOLID,1,Color_UPbuffUP);
   SetIndexBuffer(2,UPbuffUP);
   SetIndexLabel(2,"UPbuffUP");
   SetIndexStyle(3,DRAW_LINE,STYLE_SOLID,1,Color_UPbuffDN);
   SetIndexBuffer(3,UPbuffDN);
   SetIndexLabel(3,"UPbuffDN");
   SetIndexStyle(4,DRAW_LINE,STYLE_SOLID,1,Color_DNbuffUP);
   SetIndexBuffer(4,DNbuffUP);
   SetIndexLabel(4,"DNbuffUP");
   SetIndexStyle(5,DRAW_LINE,STYLE_SOLID,1,Color_DNbuffDN);
   SetIndexBuffer(5,DNbuffDN);
   SetIndexLabel(5,"DNbuffDN");

   SetIndexBuffer(6,Price);

   SetLevelValue(0,1.5);
   SetLevelStyle(STYLE_DOT,1);

   return(0);
}

int start()
  {

   int i, j;
   int counted_bars=IndicatorCounted();
   int limit = Bars-counted_bars-1;

   for (i=limit-Periods+1; i>=0; i--){

      if (ENUM_APPLIED_PRICE(Price_Type)==PRICE_CLOSE)
         Price[i]=Close[i];
      else if (ENUM_APPLIED_PRICE(Price_Type)==PRICE_OPEN)
         Price[i]=Open[i];
      else if (ENUM_APPLIED_PRICE(Price_Type)==PRICE_HIGH)
         Price[i]=High[i];
      else if (ENUM_APPLIED_PRICE(Price_Type)==PRICE_LOW)
         Price[i]=Low[i];
      else if (ENUM_APPLIED_PRICE(Price_Type)==PRICE_MEDIAN)
         Price[i]=(High[i]+Low[i])/2;
      else if (ENUM_APPLIED_PRICE(Price_Type)==PRICE_TYPICAL)
         Price[i]=(High[i]+Low[i]+Close[i])/3;
      else
         Price[i]=(High[i]+Low[i]+(2*Close[i]))/4;

   }

   double priceMax, priceMin, length, priorDiff, diff, sum;
   double fdi, variance, mean, delta, stddev;

   for (i=limit-Periods+1; i>=0; i--){

      length=0;
      priorDiff=0;
      diff=0;
      sum=0;

      for (j=(i+Periods-1); j>=i; j--){
         if (j==(i+Periods-1))
            priceMax = priceMin = Price[j];
         else{
            if (Price[j]>priceMax) priceMax = Price[j];
            if (Price[j]<priceMin)  priceMin = Price[j];
         }
      }

      for (j=(i+Periods-1); j>=i; j--){
         if ((priceMax-priceMin) > 0){
            diff = (Price[j]-priceMin)/(priceMax-priceMin);
            if (j<(i+Periods-1)){
               length = length+MathSqrt(MathPow(diff-priorDiff,2)+(1/MathPow(Periods,2)));
            }
            priorDiff=diff;
         }
      }



      if (length > 0){
         fdi = 1+(MathLog(length)+MathLog(2)) / MathLog(2*(Periods-1));
         mean=length/(Periods-1);
         for (j=(i+Periods-1); j>=i; j--){
            if ((priceMax-priceMin) > 0){
               diff=(Price[j]-priceMin)/(priceMax-priceMin);
               if (j<(i+Periods-1)){
                  delta=MathSqrt(MathPow(diff-priorDiff,2)+(1/MathPow(Periods,2)));
                  sum=sum+MathPow((delta-length)/(Periods-1),2);
               }
               priorDiff=diff;
            }
         }
         variance=sum/((MathPow(length,2)*MathPow(MathLog(2*(Periods-1)),2)));
      }else{
         fdi = 0;
         variance = 0;
      }
      //buffUP[i]=fdi;
      stddev = MathSqrt(variance);
      if (i==1) Comment(fdi);

      if (fdi>Random_Line){
         buffUP[i]=fdi;
         buffUP[i+1]=MathMin(buffUP[i+1],buffDN[i+1]);
         buffDN[i]=EMPTY_VALUE;
         UPbuffUP[i]=fdi+stddev;
         UPbuffUP[i+1]=buffUP[i+1]+stddev;
         UPbuffDN[i]=EMPTY_VALUE;
         if (fdi-stddev>Random_Line){
            DNbuffUP[i]=fdi-stddev;
            DNbuffUP[i+1]=buffUP[i+1]-stddev;
            DNbuffDN[i]=EMPTY_VALUE;
         }else{
            DNbuffDN[i]=fdi-stddev;
            DNbuffDN[i+1]=buffUP[i+1]-stddev;
            DNbuffUP[i]=EMPTY_VALUE;
         }
      }
      else{
         buffDN[i]=fdi;
         buffDN[i+1]=MathMin(buffUP[i+1],buffDN[i+1]);
         buffUP[i]=EMPTY_VALUE;
         if (fdi+stddev>Random_Line){
            UPbuffUP[i]=fdi+stddev;
            UPbuffUP[i+1]=buffDN[i+1]+stddev;
            UPbuffDN[i]=EMPTY_VALUE;
         }else{
            UPbuffDN[i]=fdi+stddev;
            UPbuffDN[i+1]=buffDN[i+1]+stddev;
            UPbuffUP[i]=EMPTY_VALUE;
         }
         DNbuffDN[i]=fdi-stddev;
         DNbuffDN[i+1]=buffDN[i+1]-stddev;
         DNbuffUP[i]=EMPTY_VALUE;
      }

   }

//----
   return(0);
}
