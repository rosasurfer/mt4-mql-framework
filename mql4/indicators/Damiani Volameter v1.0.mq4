/**
 * @see  http://www.damianifx.com.br/indicators1.php
 */
#property indicator_separate_window
#property indicator_buffers 3
#property indicator_color1 Silver
#property indicator_color2 FireBrick
#property indicator_color3 Lime

// input parameters
extern int    Viscosity       = 7;
extern int    Sedimentation   = 50;
extern double Threshold_level = 1.1;
extern bool   lag_supressor   = true;
       double lag_s_K         = 0.5;

// buffers
double thresholdBuffer[];
double vol_m[];
double vol_t[];
double ind_c[];


/**
 *
 */
int init() {
   SetIndexStyle(0,DRAW_LINE);
   SetIndexBuffer(0,thresholdBuffer);
   SetIndexStyle(1,DRAW_SECTION);
   SetIndexBuffer(1,vol_m);
   SetIndexStyle(2,DRAW_LINE);
   SetIndexBuffer(2,vol_t);

   ArrayResize(ind_c,Bars);
   ArrayInitialize(ind_c,0.0);
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

   for (int i=limit; i >= 0; i--) {
      double atr   =      iATR(NULL, 0, Viscosity, i);
      double vola = atr / iATR(NULL, 0, Sedimentation, i);
      if (lag_supressor)
         vola += lag_s_K * (ind_c[i+1] - ind_c[i+3]);

      double anti_thres = iStdDev(NULL, 0, Viscosity,     0, MODE_LWMA, PRICE_TYPICAL, i)
                        / iStdDev(NULL, 0, Sedimentation, 0, MODE_LWMA, PRICE_TYPICAL, i);
      double treshold = Threshold_level - anti_thres;
      vol_t[i]           = vola;
      ind_c[i]           = vola;
      thresholdBuffer[i] = treshold;

      if (vola > treshold) {
         vol_m[i] = vola;
         IndicatorShortName("DAMIANI Signal/Noise: TRADE  /  ATR= "+ DoubleToStr(atr, Digits) +"    values:");
      }
      else {
         vol_m[i] = EMPTY_VALUE;
         IndicatorShortName("DAMIANI Signal/Noise: DON'T TRADE  /  ATR= "+ DoubleToStr(atr, Digits) +"    values:");
      }
   }
   return(0);
}
