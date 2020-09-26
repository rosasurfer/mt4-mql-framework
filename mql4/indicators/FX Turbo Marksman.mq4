#property copyright "Copyright © 2010, FX Turbo Marksman EURJPY"
#property link      "http://www.fxturbomarksman.com"

#property indicator_chart_window
#property indicator_buffers 2
#property indicator_color1 Red
#property indicator_color2 Olive

int gi_76 = 6;
int gi_80 = 500;

/*
EURCHF: int gi_76 = 9;
EURGBP: int gi_76 = 16;
EURJPY: int gi_76 = 6;
EURUSD: int gi_76 = 15;
GBPCHF: int gi_76 = 15;
GBPJPY: int gi_76 = 10;
GBPUSD: int gi_76 = 5;
USDCAD: int gi_76 = 9;
USDCHF: int gi_76 = 20;
USDJPY: int gi_76 = 9;

DAX:    int gi_76 = 2;
DJIA:   int gi_76 = 15;
SP500:  int gi_76 = 16;

CRUDE:  int gi_76 = 4;
XAUUSD: int gi_76 = 10;
*/

extern bool SoundAlarm = TRUE;
extern bool EmailAlarm = FALSE;
double g_ibuf_92[];
double g_ibuf_96[];
bool gi_100 = FALSE;
bool gi_104 = FALSE;

int init() {
   IndicatorBuffers(2);
   SetIndexStyle(0, DRAW_ARROW);
   SetIndexArrow(0, 234);
   SetIndexStyle(1, DRAW_ARROW);
   SetIndexArrow(1, 233);
   SetIndexBuffer(0, g_ibuf_92);
   SetIndexBuffer(1, g_ibuf_96);
   GlobalVariableSet("AlertTime" + Symbol() + Period(), TimeCurrent());
   GlobalVariableSet("SignalType" + Symbol() + Period(), 5);
   return (0);
}

int deinit() {
   GlobalVariableDel("AlertTime" + Symbol() + Period());
   GlobalVariableDel("SignalType" + Symbol() + Period());
   return (0);
}

int start() {
   int li_12;
   double ld_52;
   double ld_60;
   double ld_76;
   double ld_84;
   double ld_92;
   double ld_100;
   double lda_108[1000];
   double ld_120;
   if (gi_80 >= 1000) gi_80 = 950;
   SetIndexDrawBegin(0, Bars - gi_80 + 11 + 1);
   SetIndexDrawBegin(1, Bars - gi_80 + 11 + 1);
   int ind_counted_8 = IndicatorCounted();
   double ld_112 = 0;
   int li_20 = gi_76 * 2 + 3;
   double ld_36 = gi_76 + 67;
   double ld_44 = 33 - gi_76;
   int period_24 = li_20;
   if (Bars <= 12) return (0);
   if (ind_counted_8 < 12) {
      for (int li_0 = 1; li_0 <= 0; li_0++) g_ibuf_92[gi_80 - li_0] = 0.0;
      for (li_0 = 1; li_0 <= 0; li_0++) g_ibuf_96[gi_80 - li_0] = 0.0;
   }
   for (int li_4 = gi_80 - 11 - 1; li_4 >= 0; li_4--) {
      li_12 = li_4;
      ld_76 = 0.0;
      ld_84 = 0.0;
      for (li_12 = li_4; li_12 <= li_4 + 9; li_12++) ld_84 += MathAbs(High[li_12] - Low[li_12]);
      ld_76 = ld_84 / 10.0;
      li_12 = li_4;
      for (double ld_68 = 0; li_12 < li_4 + 9 && ld_68 < 1.0; li_12++)
         if (MathAbs(Open[li_12] - (Close[li_12 + 1])) >= 2.0 * ld_76) ld_68 += 1.0;
      if (ld_68 >= 1.0) ld_92 = li_12;
      else ld_92 = -1;
      li_12 = li_4;
      for (ld_68 = 0; li_12 < li_4 + 6 && ld_68 < 1.0; li_12++)
         if (MathAbs(Close[li_12 + 3] - Close[li_12]) >= 4.6 * ld_76) ld_68 += 1.0;
      if (ld_68 >= 1.0) ld_100 = li_12;
      else ld_100 = -1;
      if (ld_92 > -1.0) period_24 = 3;
      else period_24 = li_20;
      if (ld_100 > -1.0) period_24 = 4;
      else period_24 = li_20;
      ld_52 = 100 - MathAbs(iWPR(NULL, 0, period_24, li_4));
      lda_108[li_4] = ld_52;
      g_ibuf_92[li_4] = 0;
      g_ibuf_96[li_4] = 0;
      ld_60 = 0;
      if (ld_52 < ld_44) {
         for (int li_16 = 1; lda_108[li_4 + li_16] >= ld_44 && lda_108[li_4 + li_16] <= ld_36; li_16++) {
         }
         if (lda_108[li_4 + li_16] > ld_36) {
            ld_60 = High[li_4] + ld_76 / 2.0;
            if (li_4 == 1 && gi_100 == FALSE) {
               gi_100 = TRUE;
               gi_104 = FALSE;
            }
            g_ibuf_92[li_4] = ld_60;
         }
      }
      if (ld_52 > ld_36) {
         for (li_16 = 1; lda_108[li_4 + li_16] >= ld_44 && lda_108[li_4 + li_16] <= ld_36; li_16++) {
         }
         if (lda_108[li_4 + li_16] < ld_44) {
            ld_60 = Low[li_4] - ld_76 / 2.0;
            if (li_4 == 1 && gi_104 == FALSE) {
               gi_104 = TRUE;
               gi_100 = FALSE;
            }
            g_ibuf_96[li_4] = ld_60;
         }
      }
   }

   // hier:  Low wird gecheckt, wenn gi_100 == TRUE, High wird gecheckt, wenn gi_104 == TRUE
   // Arrow: Low wird gecheckt, wenn gi_104 == TRUE, High wird gecheckt, wenn gi_100 == TRUE

   if (gi_100 == TRUE && TimeCurrent() > GlobalVariableGet("AlertTime" + Symbol() + Period()) && GlobalVariableGet("SignalType" + Symbol() + Period()) != 0.0) {
      ld_120 = Low[iLowest(Symbol(), 0, MODE_LOW, 3, 0)] - 5.0 * Point;
      if (SoundAlarm) Alert("Sell signal @ ", Symbol(), " Period ", Period(), " Stop Loss @", ld_120);
      if (EmailAlarm) SendMail("Sell Signal FX Marksman", "Sell signal @ " + Symbol() + " Period " + Period() + " Stop Loss @ " + ld_120);
      ld_112 = TimeCurrent() + 60.0 * (Period() - MathMod(Minute(), Period()));
      GlobalVariableSet("AlertTime" + Symbol() + Period(), ld_112);
      GlobalVariableSet("SignalType" + Symbol() + Period(), 0);
   }
   if (gi_104 == TRUE && TimeCurrent() > GlobalVariableGet("AlertTime" + Symbol() + Period()) && GlobalVariableGet("SignalType" + Symbol() + Period()) != 1.0) {
      ld_120 = High[iHighest(Symbol(), 0, MODE_HIGH, 3, 0)] + 5.0 * Point;
      if (SoundAlarm) Alert("Buy signal @ ", Symbol(), " Period ", Period(), " Stop Loss @", ld_120);
      if (EmailAlarm) SendMail("BUY Signal FX Marksman", "Buy signal @ " + Symbol() + " Period " + Period() + " Stop Loss @ " + ld_120);
      ld_112 = TimeCurrent() + 60.0 * (Period() - MathMod(Minute(), Period()));
      GlobalVariableSet("AlertTime" + Symbol() + Period(), ld_112);
      GlobalVariableSet("SignalType" + Symbol() + Period(), 1);
   }
   return (0);
}
