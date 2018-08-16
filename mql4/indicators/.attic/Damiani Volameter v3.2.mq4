#property copyright "Copyright © 2006,2007 Luis Guilherme Damiani"
#property link      "http://www.damianifx.com.br"

#property indicator_separate_window
#property indicator_minimum 0.0
#property indicator_buffers 3
#property indicator_color1 Silver
#property indicator_color2 FireBrick
#property indicator_color3 Lime

extern int Vis_atr = 13;
extern int Vis_std = 20;
extern int Sed_atr = 40;
extern int Sed_std = 100;
extern double Threshold_level = 1.4;
extern bool lag_supressor = TRUE;
double gd_104 = 0.5;
extern int max_bars = 2000;
double g_ibuf_116[];
double g_ibuf_120[];
double g_ibuf_124[];

int init() {
   SetIndexStyle(0, DRAW_LINE);
   SetIndexBuffer(0, g_ibuf_116);
   SetIndexStyle(1, DRAW_LINE, STYLE_SOLID, 4);
   SetIndexBuffer(1, g_ibuf_120);
   SetIndexStyle(2, DRAW_LINE);
   SetIndexBuffer(2, g_ibuf_124);
   return (0);
}

int deinit() {
   return (0);
}

int start() {
   int li_16;
   double l_iatr_28;
   double ld_36;
   double ld_44;
   double ld_unused_52;
   double ld_60;
   double ld_unused_68;
   double ld_76;
   double ld_0 = 0;
   int li_8 = IndicatorCounted();
   if (li_8 < 0) return (-1);
   if (li_8 > 0) li_8--;
   int li_12 = Bars - li_8;
   int li_20 = MathMax(Sed_atr, Sed_std);
   if (li_12 > li_20 + 5) li_16 = li_12 - li_20;
   else li_16 = li_12;
   for (int li_24 = li_16; li_24 >= 0; li_24--) {
      l_iatr_28 = iATR(NULL, 0, Vis_atr, li_24);
      ld_36 = g_ibuf_124[li_24 + 1];
      ld_44 = g_ibuf_124[li_24 + 3];
      ld_unused_52 = NormalizeDouble(l_iatr_28, Digits);
      if (lag_supressor) ld_0 = l_iatr_28 / iATR(NULL, 0, Sed_atr, li_24) + gd_104 * (ld_36 - ld_44);
      else ld_0 = l_iatr_28 / iATR(NULL, 0, Sed_atr, li_24);
      ld_60 = iStdDev(NULL, 0, Vis_std, 0, MODE_LWMA, PRICE_TYPICAL, li_24);
      ld_unused_68 = NormalizeDouble(ld_60, Digits);
      ld_60 /= iStdDev(NULL, 0, Sed_std, 0, MODE_LWMA, PRICE_TYPICAL, li_24);
      ld_76 = Threshold_level;
      ld_76 -= ld_60;
      if (li_24 == 0) {
         if (ld_0 > ld_76) {
            IndicatorShortName("Damiani: TRADE " + " A(" + DoubleToStr(Vis_atr, 0) + "/" + DoubleToStr(Sed_atr, 0) + ")= " + DoubleToStr(ld_0, 2) + ", " + DoubleToStr(Threshold_level, 1) +
               " - S(" + DoubleToStr(Vis_std, 0) + "/" + DoubleToStr(Sed_std, 0) + ")= " + DoubleToStr(ld_76, 2) + " ");
         } else {
            IndicatorShortName("Damiani: DO NOT trade " + "A(" + DoubleToStr(Vis_atr, 0) + "/" + DoubleToStr(Sed_atr, 0) + ")= " + DoubleToStr(ld_0, 2) + ", " + DoubleToStr(Threshold_level, 1) +
               " - S(" + DoubleToStr(Vis_std, 0) + "/" + DoubleToStr(Sed_std, 0) + ")= " + DoubleToStr(ld_76, 2) + " ");
         }
      }
      if (ld_0 > ld_76) {
         g_ibuf_124[li_24] = ld_0;
         g_ibuf_120[li_24] = -1;
      } else {
         g_ibuf_124[li_24] = ld_0;
         g_ibuf_120[li_24] = 0.03;
      }
      g_ibuf_116[li_24] = ld_76;
   }
   return (0);
}
