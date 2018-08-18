/**
 * @origin  http://www.damianifx.com.br/indicators1.php
 */
#property indicator_separate_window
#property indicator_buffers   2

#property indicator_color1       LimeGreen
#property indicator_width1       2
#property indicator_color2       Tomato
#property indicator_width2       2


// input parameters
extern int    Fast.Periods    = 7;
extern int    Slow.Periods    = 50;
extern double Threshold_level = 1.1;
extern bool   NonLag          = true;
       double NonLag.K        = 0.5;


#define MODE_ATR_RATIO     0
#define MODE_TRESHOLD      1


// buffers
double bufferAtrRatio [];
double bufferThreshold[];


/**
 *
 */
int init() {
   SetIndexBuffer(MODE_ATR_RATIO, bufferAtrRatio );
   SetIndexBuffer(MODE_TRESHOLD,  bufferThreshold);

   SetIndexLabel(MODE_ATR_RATIO, "Damiani ATR ratio");
   SetIndexLabel(MODE_TRESHOLD,  "Damiani StdDev ratio");
   return(0);
}


/**
 *
 */
int start() {
   int changed_bars = IndicatorCounted();
   int limit = Bars - changed_bars;
   if (limit > Slow.Periods+5)
      limit -= Slow.Periods;

   double fastAtr, slowAtr, atrRatio, fastStdDev, slowStdDev, stdDevRatio;

   for (int i=limit; i >= 0; i--) {
      fastAtr  = iATR(NULL, NULL, Fast.Periods, i);
      slowAtr  = iATR(NULL, NULL, Slow.Periods, i);
      atrRatio = fastAtr/slowAtr;
      if (NonLag)
         atrRatio += NonLag.K * (bufferAtrRatio[i+1] - bufferAtrRatio[i+3]);
      bufferAtrRatio[i] = atrRatio;

      fastStdDev  = iStdDev(NULL, NULL, Fast.Periods, 0, MODE_LWMA, PRICE_TYPICAL, i);
      slowStdDev  = iStdDev(NULL, NULL, Slow.Periods, 0, MODE_LWMA, PRICE_TYPICAL, i);
      stdDevRatio = fastStdDev/slowStdDev;

      bufferThreshold[i] = Threshold_level - stdDevRatio;
   }

   if (NonLag) string sNonLag = "NonLag=TRUE";
   else               sNonLag = "NonLag=FALSE";
   //IndicatorShortName(StringConcatenate("Damiani Volameter    ", sNonLag, "  ATR ratio: ", DoubleToStr(atrRatio, 3), " StdDev ratio: ", DoubleToStr(stdDevRatio, 3)));
   IndicatorShortName("Damiani Volameter    "+ sNonLag +"    ");
   return(0);
}
