/**
 * @see  http://www.damianifx.com.br/indicators1.php
 */
#property indicator_separate_window
#property indicator_buffers   2

#property indicator_color1    Tomato
#property indicator_width1    2
#property indicator_color2    LimeGreen
#property indicator_width2    2


// input parameters
extern int    Viscosity       = 7;
extern int    Sedimentation   = 50;
extern double Threshold_level = 1.1;
extern bool   lag_supressor   = true;
       double lag_s_K         = 0.5;

// buffers
double thresholdBuffer[];
double vol_t[];
double ind_c[];


/**
 *
 */
int init() {
   SetIndexBuffer(0, thresholdBuffer); SetIndexStyle(0, DRAW_LINE);
   SetIndexBuffer(1, vol_t);           SetIndexStyle(1, DRAW_LINE);

   ArrayResize(ind_c, Bars);
   ArrayInitialize(ind_c, 0);
   return(0);
}


/**
 *
 */
int start() {
   int changed_bars = IndicatorCounted();
   int limit = Bars - changed_bars;
   if (limit > Sedimentation+5)
      limit -= Sedimentation;

   double atr, vola, treshold;

   for (int i=limit; i >= 0; i--) {
      atr  =       iATR(NULL, 0, Viscosity, i);
      vola = atr / iATR(NULL, 0, Sedimentation, i);
      if (lag_supressor)
         vola += lag_s_K * (ind_c[i+1] - ind_c[i+3]);

      treshold = Threshold_level - iStdDev(NULL, 0, Viscosity,     0, MODE_LWMA, PRICE_TYPICAL, i)
                                 / iStdDev(NULL, 0, Sedimentation, 0, MODE_LWMA, PRICE_TYPICAL, i);

      vol_t[i]           = vola;
      ind_c[i]           = vola;
      thresholdBuffer[i] = treshold;
   }

   if (vola > treshold) string sTrade = "TRADE";
   else                        sTrade = "DON'T TRADE";
   IndicatorShortName(StringConcatenate("Damiani Signal/Noise:  ", sTrade, "    ATR=", DoubleToStr(atr, Digits), "    values="));

   return(0);
}
