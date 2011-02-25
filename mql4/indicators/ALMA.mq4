/**
 * Arnaud Legoux Moving Average
 *
 * @see http://www.arnaudlegoux.com/
 */
#include <stdlib.mqh>


#property indicator_chart_window

#property indicator_buffers 3

#property indicator_color1  Yellow
#property indicator_color2  DodgerBlue    // LightBlue
#property indicator_color3  Orange        // Tomato

#property indicator_width1  2
#property indicator_width2  2
#property indicator_width3  2


//////////////////////////////////////////////////////////////// Externe Parameter ////////////////////////////////////////////////////////////////

extern int    MA.Period        = 9;             // averaging period
extern int    AppliedPrice     = PRICE_CLOSE;
extern string AppliedPrice.Hlp = "0: Close, 1: Open, 2: High, 3: Low, 4: Median, 5: Typical, 6: Weighted Close";
extern double Sigma            = 6.0;           // sigma parameter
extern double Offset           = 0.85;          // offset of Gaussian distribution (0...1)
extern double PctFilter        = 0;             // dynamic filter in decimal
extern int    BarShift         = 0;             // indicator forward/backward shift
extern bool   UpDownColoring   = true;          // alernate colors switch
extern int    ColorBarBack     = 1;
extern bool   WarningMode      = false;         // warning sound switch
extern bool   AlertMode        = false;         // alert sound switch

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


double iALMA[], iUpTrend[], iDownTrend[];    // sichtbare Indikatorbuffer
double wALMA[];                              // Gewichtung der einzelnen Bars (Summe = 1)

double iTrend[], iDel[];                     // intern (nicht sichtbar)

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
   SetIndexDrawBegin(0, MA.Period);
   SetIndexDrawBegin(1, MA.Period);
   SetIndexDrawBegin(2, MA.Period);
   SetIndexShift    (0, BarShift);
   SetIndexShift    (1, BarShift);
   SetIndexShift    (2, BarShift);

   // indicator names
   IndicatorShortName("ALMA("+ MA.Period +")");
   SetIndexLabel(0, "ALMA("+ MA.Period +")");
   SetIndexLabel(1, NULL);
   SetIndexLabel(2, NULL);
   IndicatorDigits(Digits);

   int    m = Offset * (MA.Period - 1);      // (int) double
   double s = MA.Period / Sigma;
   double wSum;

   ArrayResize(wALMA, MA.Period);

   for (int i=0; i < MA.Period; i++) {
      wALMA[i] = MathExp(-((i-m)*(i-m)) / (2*s*s));
      wSum += wALMA[i];
   }

   for (i=0; i < MA.Period; i++) {
      wALMA[i] /= wSum;                      // Gewichtungen der einzelnen Bars (Summe = 1)
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
   debug("start()   ChangedBars = "+ ChangedBars +"   execution time: "+ (GetTickCount()-tick) +" ms");

   Tick++;
   ValidBars   = IndicatorCounted();
   ChangedBars = Bars - ValidBars;
   stdlib_onTick(ValidBars);

   //----
   if (ValidBars == 0) {
      ArrayInitialize(iALMA,      EMPTY_VALUE);
      ArrayInitialize(iUpTrend,   EMPTY_VALUE);
      ArrayInitialize(iDownTrend, EMPTY_VALUE);
   }

   //----
   for (int bar=ChangedBars-1; bar >= 0; bar--) {
      if (bar > Bars-1 - MA.Period)
         continue;

      double sum  = 0;
      double wsum = 0;

      for (int i=0; i < MA.Period; i++) {
         if (i < MA.Period)
            sum += wALMA[i] * iMA(NULL, 0, 1, 0, 0, AppliedPrice, bar + (MA.Period-1-i));
      }

      //if(wsum != 0)
      iALMA[bar] = sum;

      if (PctFilter > 0) {
         iDel[bar] = MathAbs(iALMA[bar] - iALMA[bar+1]);

         double sumdel=0;
         for (int j=0; j <= MA.Period-1; j++) {
            sumdel += iDel[bar+j];
         }

         double AvgDel = sumdel/MA.Period;

         double sumpow = 0;
         for (j=0; j <= MA.Period-1; j++) {
            sumpow += MathPow(iDel[j+bar] - AvgDel, 2);
         }

         double StdDev = MathSqrt(sumpow/MA.Period);
         double Filter = PctFilter * StdDev;

         if (MathAbs(iALMA[bar]-iALMA[bar+1]) < Filter)
            iALMA[bar] = iALMA[bar+1];
      }
      else {
         Filter = 0;
      }

      if (UpDownColoring) {
         iTrend[bar] = iTrend[bar+1];
         if (iALMA[bar  ] - iALMA[bar+1] > Filter) iTrend[bar] =  1;
         if (iALMA[bar+1] - iALMA[bar  ] > Filter) iTrend[bar] = -1;

         if (iTrend[bar] > 0) {
            iUpTrend[bar] = iALMA[bar];
            if (iTrend[bar+ColorBarBack] < 0)
               iUpTrend[bar+ColorBarBack] = iALMA[bar+ColorBarBack];
            iDownTrend[bar] = EMPTY_VALUE;
            if (WarningMode) /*&&*/ if (iTrend[bar+1] < 0) /*&&*/ if (i == 0) {
               PlaySound("alert2.wav");
            }
         }
         else if (iTrend[bar] < 0) {
            iDownTrend[bar] = iALMA[bar];
            if (iTrend[bar+ColorBarBack] > 0)
               iDownTrend[bar+ColorBarBack] = iALMA[bar+ColorBarBack];
            iUpTrend[bar] = EMPTY_VALUE;
            if (WarningMode) /*&&*/ if (iTrend[bar+1] > 0) /*&&*/ if (i == 0) {
               PlaySound("alert2.wav");
            }
         }
      }
   }

   //----------
   if (AlertMode) {
      if (iTrend[2] < 0) /*&&*/ if (iTrend[1] > 0) /*&&*/ if (!UpTrendAlert) {
         Alert(Symbol(), " M", Period(), ": ALMA buy signal");
         UpTrendAlert   = true;
         DownTrendAlert = false;
      }
      if (iTrend[2] > 0) /*&&*/ if (iTrend[1] < 0) /*&&*/ if (!DownTrendAlert) {
         Alert(Symbol(), " M", Period(), ": ALMA sell signal");
         DownTrendAlert = true;
         UpTrendAlert   = false;
      }
   }

   debug("start()   ChangedBars = "+ ChangedBars +"   execution time: "+ (GetTickCount()-tick) +" ms");

   return(catch("start()"));
}
