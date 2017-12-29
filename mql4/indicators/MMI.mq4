/**
 * Market Meanness Index
 *
 *
 * @see    http://www.financial-hacker.com/the-market-meanness-index/
 * @source http://www.fxcodebase.com/code/viewtopic.php?f=38&t=64338
 */

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern int    Length          = 200;
extern double OverboughtLevel =  76;
extern double OversoldLevel   =  74;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#property indicator_separate_window
#property indicator_buffers 1
#property indicator_color1 Yellow


double MMI[];


/**
 *
 */
int init() {
   IndicatorShortName("Market-Meanness-Index");
   IndicatorDigits(Digits);
   SetIndexStyle(0,DRAW_LINE);
   SetIndexBuffer(0,MMI);

   SetLevelValue(0, OverboughtLevel);
   SetLevelValue(1, OversoldLevel);

   return(0);
}


/**
 *
 */
int deinit() {
   return(0);
}


/**
 *
 */
int start() {
   if (Bars <= 3)
      return(0);

   int ExtCountedBars = IndicatorCounted();
   if (ExtCountedBars < 0)
      return(-1);

   int limit = Bars-2;
   if (ExtCountedBars > 2)
      limit = Bars - ExtCountedBars - 1;

   int pos = limit;

   while (pos >= 0) {
      int nl = 0;
      int nh = 0;
      double m = mean(pos);
      for (int i=pos+1; i <= pos+Length; i++) {
         if (Open[i] > Close[i]) {
            if (Open[i]-Close[i] > m) {
               if (Open[i]-Close[i] > Open[i-1]-Close[i-1]) {
                  nl++;
               }
            }
         }
         else {
            if (Close[i]-Open[i] < m) {
               if (Close[i]-Open[i] < Close[i-1]-Open[i-1]) {
                  nh++;
               }
            }
         }
      }

      MMI[pos] = 100 - 100.*(nl+nh)/(Length-1);
      pos--;
   }
   return(0);
}


/**
 *
 */
double mean(int index) {
   double Sum = 0;

   for (int i=index; i < index+Length; i++) {
      Sum += MathAbs(Open[i] - Close[i]);
   }
   return (Sum/Length);
}
