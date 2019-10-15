/**
 * Free Scalper Indicator
 */
#property indicator_separate_window

#property indicator_buffers 2
#property indicator_color1 Green
#property indicator_color2 Red

#property indicator_minimum -1
#property indicator_maximum  1

extern int Length = 14;

int maxValues = 5000;
int Gi_84 = 1;
int Gi_88 = 1;
double G_ibuf_92[];
double G_ibuf_96[];
double Gda_100[];
double Gda_104[];
double Gda_108[];
double Gda_112[];
double Gd_116 = 1;
double Gd_124 = 2;


/**
 *
 */
int init() {
   IndicatorDigits(Digits);

   SetIndexBuffer(0, G_ibuf_92); SetIndexStyle(0, DRAW_HISTOGRAM); SetIndexDrawBegin(0, Length);
   SetIndexBuffer(1, G_ibuf_96); SetIndexStyle(1, DRAW_HISTOGRAM); SetIndexDrawBegin(1, Length);
   return(0);
}


/**
 *
 */
int start() {
   int Li_8;
   double Lda_12[25000];
   double Lda_16[25000];
   double Lda_20[25000];
   double Lda_24[25000];

   for (int bar=maxValues; bar >= 0; bar--) {
      G_ibuf_92[bar] = 0;
      G_ibuf_96[bar] = 0;
      Gda_100  [bar] = 0;
      Gda_104  [bar] = 0;
      Gda_108  [bar] = 0;
      Gda_112  [bar] = 0;
   }

   for (bar = maxValues - Length - 1; bar >= 0; bar--) {
      Lda_12[bar] = iBands(NULL, NULL, Length, Gd_124, 0, PRICE_CLOSE, MODE_UPPER, bar);
      Lda_16[bar] = iBands(NULL, NULL, Length, Gd_124, 0, PRICE_CLOSE, MODE_LOWER, bar);

      if (Close[bar] > Lda_12[bar + 1]) Li_8 =  1;
      if (Close[bar] < Lda_16[bar + 1]) Li_8 = -1;

      if (Li_8 > 0 && Lda_16[bar] < Lda_16[bar + 1]) Lda_16[bar] = Lda_16[bar + 1];
      if (Li_8 < 0 && Lda_12[bar] > Lda_12[bar + 1]) Lda_12[bar] = Lda_12[bar + 1];

      Lda_20[bar] = Lda_12[bar] + (Gd_116 - 1.0) / 2.0 * (Lda_12[bar] - Lda_16[bar]);
      Lda_24[bar] = Lda_16[bar] - (Gd_116 - 1.0) / 2.0 * (Lda_12[bar] - Lda_16[bar]);

      if (Li_8 > 0 && Lda_24[bar] < Lda_24[bar + 1]) Lda_24[bar] = Lda_24[bar + 1];
      if (Li_8 < 0 && Lda_20[bar] > Lda_20[bar + 1]) Lda_20[bar] = Lda_20[bar + 1];

      if (Li_8 > 0) {
         if (Gi_84 > 0 && G_ibuf_92[bar + 1] == -1) {
            Gda_100  [bar] = Lda_24[bar];
            G_ibuf_92[bar] = Lda_24[bar];
            if (Gi_88 > 0) {
               G_ibuf_92[bar] = 0.2;
               G_ibuf_96[bar] = EMPTY_VALUE;
            }
         }
         else {
            G_ibuf_92[bar] = Lda_24[bar];
            if (Gi_88 > 0) {
               G_ibuf_92[bar] = 0.2;
               G_ibuf_96[bar] = EMPTY_VALUE;
            }
            Gda_100[bar] = -1;
         }
         if (Gi_84 == 2) G_ibuf_92[bar] = 0;
         Gda_104  [bar] = -1;
         G_ibuf_96[bar] = -1;
         G_ibuf_96[bar] =  0;
         Gda_112  [bar] = EMPTY_VALUE;
      }

      if (Li_8 < 0) {
         if (Gi_84 > 0 && G_ibuf_96[bar + 1] == -1) {
            Gda_104  [bar] = Lda_20[bar];
            G_ibuf_96[bar] = Lda_20[bar];
            if (Gi_88 > 0) {
               G_ibuf_96[bar] = 0.2;
               G_ibuf_92[bar] = EMPTY_VALUE;
            }
         }
         else {
            G_ibuf_96[bar] = Lda_20[bar];
            if (Gi_88 > 0) {
               G_ibuf_96[bar] = 0.2;
               G_ibuf_92[bar] = EMPTY_VALUE;
            }
            Gda_104[bar] = -1;
         }
         if (Gi_84 == 2) G_ibuf_96[bar] = 0;
         Gda_100  [bar] = -1;
         G_ibuf_92[bar] = 0;
         Gda_108  [bar] = EMPTY_VALUE;
      }
   }
   return(0);
}
