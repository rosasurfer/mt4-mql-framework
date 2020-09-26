/**
 * FX Turbo Marksman
 *
 *
 * EURCHF: int gi_76 =  9;
 * EURGBP: int gi_76 = 16;
 * EURJPY: int gi_76 =  6;
 * EURUSD: int gi_76 = 15;
 * GBPCHF: int gi_76 = 15;
 * GBPJPY: int gi_76 = 10;
 * GBPUSD: int gi_76 =  5;
 * USDCAD: int gi_76 =  9;
 * USDCHF: int gi_76 = 20;
 * USDJPY: int gi_76 =  9;
 *
 * DAX:    int gi_76 =  2;
 * DJIA:   int gi_76 = 15;
 * SP500:  int gi_76 = 16;
 *
 * CRUDE:  int gi_76 =  4;
 * XAUUSD: int gi_76 = 10;
 */
#property indicator_chart_window
#property indicator_buffers 2
#property indicator_color1 Red
#property indicator_color2 Olive

extern bool SoundAlarm = true;

double g_ibuf_92[];
double g_ibuf_96[];

int    gi_76 = 6;             // EURJPY
int    gi_80 = 500;
bool   gi_100;
bool   gi_104;


/**
 *
 */
int init() {
   SetIndexBuffer(0, g_ibuf_92); SetIndexStyle(0, DRAW_ARROW); SetIndexArrow(0, 234);
   SetIndexBuffer(1, g_ibuf_96); SetIndexStyle(1, DRAW_ARROW); SetIndexArrow(1, 233);

   GlobalVariableSet("AlertTime"+ Symbol() + Period(), TimeCurrent());
   GlobalVariableSet("SignalType"+ Symbol() + Period(), 5);
   return(0);
}


/**
 *
 */
int deinit() {
   GlobalVariableDel("AlertTime"+ Symbol() + Period());
   GlobalVariableDel("SignalType"+ Symbol() + Period());
   return(0);
}


/**
 *
 */
int start() {
   int    li_12;
   double ld_52;
   double ld_60;
   double ld_76;
   double ld_84;
   double ld_92;
   double ld_100;
   double lda_108[1000];

   if (gi_80 >= 1000) gi_80 = 950;

   SetIndexDrawBegin(0, Bars - gi_80 + 12);
   SetIndexDrawBegin(1, Bars - gi_80 + 12);

   int    ind_counted_8 = IndicatorCounted();
   int    li_20 = gi_76 * 2 + 3;
   double ld_36 = gi_76 + 67;
   double ld_44 = 33 - gi_76;
   int    period_24 = li_20;

   if (Bars <= 12) return (0);

   for (int i=gi_80-12; i >= 0; i--) {
      li_12 = i;
      ld_76 = 0;
      ld_84 = 0;

      for (li_12=i; li_12 <= i+9; li_12++) {
         ld_84 += MathAbs(High[li_12] - Low[li_12]);
      }
      ld_76 = ld_84 / 10;
      li_12 = i;

      for (double ld_68=0; li_12 < i+9 && ld_68 < 1.0; li_12++) {
         if (MathAbs(Open[li_12] - (Close[li_12 + 1])) >= 2.0 * ld_76)
            ld_68 += 1;
      }

      if (ld_68 >= 1.0) ld_92 = li_12;
      else              ld_92 = -1;
      li_12 = i;

      for (ld_68=0; li_12 < i+6 && ld_68 < 1.0; li_12++) {
         if (MathAbs(Close[li_12 + 3] - Close[li_12]) >= 4.6 * ld_76)
            ld_68 += 1.0;
      }

      if (ld_68 >= 1)  ld_100 = li_12;
      else             ld_100 = -1;

      if (ld_92 > -1)  period_24 = 3;
      else             period_24 = li_20;

      if (ld_100 > -1) period_24 = 4;
      else             period_24 = li_20;

      ld_52 = 100 - MathAbs(iWPR(NULL, 0, period_24, i));

      lda_108[i]   = ld_52;
      g_ibuf_92[i] = 0;
      g_ibuf_96[i] = 0;
      ld_60        = 0;

      if (ld_52 < ld_44) {
         for (int li_16=1; lda_108[i+li_16] >= ld_44 && lda_108[i+li_16] <= ld_36; li_16++) {}

         if (lda_108[i+li_16] > ld_36) {
            ld_60 = High[i] + ld_76 / 2;
            if (i==1 && !gi_100) {
               gi_100 = true;
               gi_104 = false;
            }
            g_ibuf_92[i] = ld_60;
         }
      }

      if (ld_52 > ld_36) {
         for (li_16=1; lda_108[i+li_16] >= ld_44 && lda_108[i+li_16] <= ld_36; li_16++) {}

         if (lda_108[i+li_16] < ld_44) {
            ld_60 = Low[i] - ld_76 / 2;
            if (i==1 && !gi_104) {
               gi_100 = false;
               gi_104 = true;
            }
            g_ibuf_96[i] = ld_60;
         }
      }
   }

   if (gi_104 && TimeCurrent() > GlobalVariableGet("AlertTime" + Symbol() + Period()) && GlobalVariableGet("SignalType" + Symbol() + Period()) != 1) {
      if (SoundAlarm) Alert("Buy signal @ "+ Symbol() +" Period "+ Period());

      datetime time = TimeCurrent() + 60 * (Period() - MathMod(Minute(), Period()));
      GlobalVariableSet("AlertTime" + Symbol() + Period(), time);
      GlobalVariableSet("SignalType" + Symbol() + Period(), 1);
   }
   if (gi_100 && TimeCurrent() > GlobalVariableGet("AlertTime"+ Symbol() + Period()) && GlobalVariableGet("SignalType"+ Symbol() + Period()) != 0) {
      if (SoundAlarm) Alert("Sell signal @ "+ Symbol() +" Period "+ Period());

      time = TimeCurrent() + 60 * (Period() - MathMod(Minute(), Period()));
      GlobalVariableSet("AlertTime" + Symbol() + Period(), time);
      GlobalVariableSet("SignalType" + Symbol() + Period(), 0);
   }
   return (0);
}
