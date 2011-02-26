/**
 * Arnaud Legoux Moving Average
 *
 * @see http://www.arnaudlegoux.com/
 */
#include <stdlib.mqh>


#property indicator_chart_window

#property indicator_buffers 3

#property indicator_color1  Yellow
#property indicator_color2  DodgerBlue          // LightBlue
#property indicator_color3  Orange              // Tomato

#property indicator_width1  2
#property indicator_width2  2
#property indicator_width3  2


//////////////////////////////////////////////////////////////// Externe Parameter ////////////////////////////////////////////////////////////////

extern int    MA.Period        = 9;             // averaging period
extern int    AppliedPrice     = PRICE_CLOSE;
extern string AppliedPrice.Hlp = "0=Close  1=Open  2=High  3=Low  4=Median  5=Typical  6=Weighted Close";
extern double GaussianOffset   = 0.85;          // Gaussian distribution offset (0...1)
extern double Sigma            = 6.0;
extern double PctFilter        = 0.0;           // minimum percentage change of ALMA
extern int    BarShift         = 0;             // indicator display shift
extern bool   TrendColoring    = true;          // enable/disable alternate trend colors
extern bool   SoundAlerts      = false;         // enable/disable sound alerts on trend changes (intra-bar too)
extern bool   TradeSignals     = false;         // enable/disable dialog box alerts on trend changes (only on bar-open)

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


double iALMA[], iUpTrend[], iDownTrend[];       // sichtbare Indikatorbuffer
double iTrend[], iDel[];                        // intern (nicht sichtbar)
double wALMA[];                                 // Gewichtung der einzelnen Bars
bool   UpTrendAlert, DownTrendAlert;


/**
 * Initialisierung
 *
 * @return int - Fehlerstatus
 */
int init() {
   init = true; init_error = NO_ERROR; __SCRIPT__ = WindowExpertName();
   stdlib_init(__SCRIPT__);

   // indicator buffers
   IndicatorBuffers(5);
   SetIndexBuffer(0, iALMA     );
   SetIndexBuffer(1, iUpTrend  );
   SetIndexBuffer(2, iDownTrend);
   SetIndexBuffer(3, iTrend    );
   SetIndexBuffer(4, iDel      );

   // drawing settings
   SetIndexStyle    (0, DRAW_LINE);
   SetIndexStyle    (1, DRAW_LINE);
   SetIndexStyle    (2, DRAW_LINE);
   SetIndexDrawBegin(0, MA.Period-1);
   SetIndexDrawBegin(1, MA.Period-1);
   SetIndexDrawBegin(2, MA.Period-1);
   SetIndexShift    (0, BarShift);
   SetIndexShift    (1, BarShift);
   SetIndexShift    (2, BarShift);

   // indicator names
   IndicatorShortName("ALMA("+ MA.Period +")");
   SetIndexLabel(0, "ALMA("+ MA.Period +")");
   SetIndexLabel(1, NULL);
   SetIndexLabel(2, NULL);
   IndicatorDigits(Digits);

   // Gewichtungen berechnen
   ArrayResize(wALMA, MA.Period);

   int    m = GaussianOffset * (MA.Period-1);   // (int) double
   double s = MA.Period / Sigma;

   double wSum;
   for (int i=0; i < MA.Period; i++) {
      wALMA[MA.Period-1-i] = MathExp(-((i-m)*(i-m)) / (2*s*s));
      wSum += wALMA[MA.Period-1-i];             // Reihenfolge der Gewichte von rechts nach links (im Chart), um Zugriff in start() zu beschleunigen
   }
   for (i=0; i < MA.Period; i++) {
      wALMA[i] /= wSum;                         // Gewichtungen der einzelnen Bars (Summe = 1)
   }

   return(catch("init()"));
}


/**
 * Deinitialisierung
 *
 * @return int - Fehlerstatus
 */
int deinit() {
   return(catch("deinit()"));
}


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int start() {
   int tick = GetTickCount();

   Tick++;
   ValidBars   = IndicatorCounted();
   ChangedBars = Bars - ValidBars;
   stdlib_onTick(ValidBars);

   // ----
   if (ValidBars == 0) {
      ArrayInitialize(iALMA,      EMPTY_VALUE);
      ArrayInitialize(iTrend,               0);
      ArrayInitialize(iUpTrend,   EMPTY_VALUE);
      ArrayInitialize(iDownTrend, EMPTY_VALUE);
   }

   // ----
   int bar = ChangedBars-1;
   if (bar > Bars - MA.Period)
      bar = Bars - MA.Period;

   for (; bar >= 0; bar--) {
      iALMA[bar] = 0;

      for (int i=0; i < MA.Period; i++) {
         iALMA[bar] += wALMA[i] * iMA(NULL, NULL, 1, 0, MODE_SMA, AppliedPrice, bar+i);
      }

      // ----------
      if (PctFilter > 0) {                               // funktioniert nur mit TrendColoring und verdoppelt die Laufzeit
         iDel[bar] = MathAbs(iALMA[bar] - iALMA[bar+1]);

         double sumDel = 0;
         for (int j=0; j <= MA.Period-1; j++) {
            sumDel += iDel[bar+j];
         }
         double avgDel = sumDel/MA.Period;

         double sumPow = 0;
         for (j=0; j <= MA.Period-1; j++) {
            sumPow += MathPow(iDel[bar+j] - avgDel, 2);
         }

         double stdDev = MathSqrt(sumPow/MA.Period);
         double filter = PctFilter * stdDev;

         if (MathAbs(iALMA[bar]-iALMA[bar+1]) < filter)
            iALMA[bar] = iALMA[bar+1];
      }
      else {
         filter = 0;
      }

      // ----------
      if (TrendColoring) {
       //if (iALMA[bar+1] != EMPTY_VALUE) {     // wenn nicht erste Bar
       //   if (iTrend[bar+1] == 0)             // wenn zweite Bar
       //      filter = 0;
            if      (iALMA[bar  ]-iALMA[bar+1] > filter) iTrend[bar] =  1;
            else if (iALMA[bar+1]-iALMA[bar  ] > filter) iTrend[bar] = -1;
            else                                         iTrend[bar] = iTrend[bar+1];
       //}

         if (iTrend[bar] > 0) {
            iUpTrend[bar] = iALMA[bar];
            if (iTrend[bar+1] < 0) {
               iUpTrend[bar+1] = iALMA[bar+1];
               if (SoundAlerts) /*&&*/ if (bar==0) PlaySound("alert2.wav");
            }
         }
         else if (iTrend[bar] < 0) {
            iDownTrend[bar] = iALMA[bar];
            if (iTrend[bar+1] > 0) {
               iDownTrend[bar+1] = iALMA[bar+1];
               if (SoundAlerts) /*&&*/ if (bar==0) PlaySound("alert2.wav");
            }
         }
         else {
            iUpTrend  [bar] = iALMA[bar];
            iDownTrend[bar] = iALMA[bar];
         }
      }
   }

   // ----------
   if (TradeSignals) {                 // funktioniert nur mit TrendColoring
      if (iTrend[2] < 0) /*&&*/ if (iTrend[1] > 0) /*&&*/ if (!UpTrendAlert) {
         Alert(Symbol(), " M", Period(), ": ALMA trend change UP (buy signal)");
         UpTrendAlert   = true;
         DownTrendAlert = false;
      }
      if (iTrend[2] > 0) /*&&*/ if (iTrend[1] < 0) /*&&*/ if (!DownTrendAlert) {
         Alert(Symbol(), " M", Period(), ": ALMA trend change DOWN (sell signal)");
         DownTrendAlert = true;
         UpTrendAlert   = false;
      }
   }

   log("start()   ALMA("+ MA.Period +")   time: "+ (GetTickCount()-tick) +" msec");
   return(catch("start()"));
}
