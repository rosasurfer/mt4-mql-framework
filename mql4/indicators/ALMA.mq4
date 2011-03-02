/**
 * Arnaud Legoux Moving Average
 *
 * @see http://www.arnaudlegoux.com/
 */
#include <stdlib.mqh>


#property indicator_chart_window

#property indicator_buffers 3

#property indicator_width1  2
#property indicator_width2  2
#property indicator_width3  2


//////////////////////////////////////////////////////////////// Externe Parameter ////////////////////////////////////////////////////////////////

extern int    MA.Period         = 200;             // averaging period
extern int    AppliedPrice      = PRICE_CLOSE;     // price used for MA calculation
extern string AppliedPrice.Help = "0=Close  1=Open  2=High  3=Low  4=Median  5=Typical  6=Weighted";
extern double GaussianOffset    = 0.85;            // Gaussian distribution offset (0...1)
extern double Sigma             = 6.0;
extern double ReversalPctFilter = 0.0;             // minimum percentage MA change to indicate a completed trend reversal
extern int    MaxValues         = -1;              // maximum number of indicator values to display
extern string MaxValues.Help    = "Max. ind. values to display (-1: all)";
extern int    BarShift          = 0;               // indicator display shifting
extern bool   SoundAlerts       = false;           // enable/disable sound alerts on trend changes (intra-bar too)
extern bool   TradeSignals      = false;           // enable/disable dialog box alerts on trend changes (only on bar-open)

extern color  Color.UpTrend     = DodgerBlue;      // Farbverwaltung im Code
extern color  Color.DownTrend   = Orange;
extern color  Color.Reversal    = Yellow;

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


double iUpTrend[], iDownTrend[], iReversal[];      // sichtbare Indikatorbuffer
double iALMA[], iTrend[], iDel[];                  // nicht sichtbare Buffer
double wALMA[];                                    // Gewichtung der einzelnen Bars des MA
bool   tradeSignalUp, tradeSignalDown;

string labels[], legendLabel;


/**
 * Initialisierung
 *
 * @return int - Fehlerstatus
 */
int init() {
   init = true; init_error = NO_ERROR; __SCRIPT__ = WindowExpertName();
   stdlib_init(__SCRIPT__);

   /*
   MaxValues       = 1200;
   Color.UpTrend   = ForestGreen;
   Color.DownTrend = Red;
   */

   // Buffer zuweisen
   IndicatorBuffers(6);
   SetIndexBuffer(0, iUpTrend  );
   SetIndexBuffer(1, iDownTrend);
   SetIndexBuffer(2, iReversal );
   SetIndexBuffer(3, iALMA     );
   SetIndexBuffer(4, iTrend    );
   SetIndexBuffer(5, iDel      );

   // Zeichenoptionen
   int startDraw = MathMax(MA.Period-1, Bars-ifInt(MaxValues < 0, Bars, MaxValues));
   SetIndexDrawBegin(0, startDraw);
   SetIndexDrawBegin(1, startDraw);
   SetIndexDrawBegin(2, startDraw);
   SetIndexShift(0, BarShift);
   SetIndexShift(1, BarShift);
   SetIndexShift(2, BarShift);
   SetIndexStyles();             // Workaround um die diversen Terminalbugs

   // Anzeigeoptionen
   IndicatorShortName("ALMA("+ MA.Period +")");
   SetIndexLabel(0, "ALMA("+ MA.Period +")");
   SetIndexLabel(1, NULL);
   SetIndexLabel(2, NULL);
   IndicatorDigits(Digits);

   /*
   // Legende
   legendLabel = StringConcatenate(WindowExpertName(), ".Legend");
   if (ObjectFind(legendLabel) >= 0)
      ObjectDelete(legendLabel);
   if (ObjectCreate(legendLabel, OBJ_LABEL, 0, 0, 0)) {
      ObjectSet(legendLabel, OBJPROP_CORNER, CORNER_TOP_LEFT);
      ObjectSet(legendLabel, OBJPROP_XDISTANCE,  4);
      ObjectSet(legendLabel, OBJPROP_YDISTANCE, 30);
      RegisterChartObject(legendLabel, labels);
   }
   else GetLastError();
   ObjectSetText(legendLabel, " ", 10);
   */

   // Gewichtungen berechnen
   ArrayResize(wALMA, MA.Period);
   int    m = GaussianOffset * (MA.Period-1);   // (int) double
   double s = MA.Period / Sigma;
   double wSum;
   for (int i=0; i < MA.Period; i++) {
      wALMA[i] = MathExp(-((i-m)*(i-m)) / (2*s*s));
      wSum += wALMA[i];
   }
   for (i=0; i < MA.Period; i++) {
      wALMA[i] /= wSum;                         // Gewichtungen der einzelnen Bars (Summe = 1)
   }
   ReverseDoubleArray(wALMA);                   // Reihenfolge umkehren, um in start() Zugriff zu beschleunigen

   // nach Parameteränderung nicht auf den nächsten Tick warten (nur im "Indicators List" window notwendig)
   if (UninitializeReason() == REASON_PARAMETERS)
      SendTick(false);

   return(catch("init()"));
}


/**
 * Deinitialisierung
 *
 * @return int - Fehlerstatus
 */
int deinit() {
   RemoveChartObjects(labels);
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

   // bei Neuberechnung alles zurücksetzen
   if (ValidBars == 0) {
      ArrayInitialize(iALMA,      EMPTY_VALUE);
      ArrayInitialize(iUpTrend,   EMPTY_VALUE);
      ArrayInitialize(iDownTrend, EMPTY_VALUE);
      ArrayInitialize(iReversal,  EMPTY_VALUE);
      ArrayInitialize(iTrend,               0);
      SetIndexStyles();                         // Workaround um die diversen Terminalbugs
   }

   // Startbar ermitteln
   if (ChangedBars > MaxValues) /*&&*/ if (MaxValues >= 0)
      ChangedBars = MaxValues;
   int startBar = MathMin(ChangedBars-1, Bars-MA.Period);


   // Schleife über alle zu berechnenden Bars
   for (int bar=startBar; bar >= 0; bar--) {
      // Moving Average
      iALMA[bar] = 0;
      for (int i=0; i < MA.Period; i++) {
         iALMA[bar] += wALMA[i] * iMA(NULL, NULL, 1, 0, MODE_SMA, AppliedPrice, bar+i);
      }

      // Percentage-Filter (verdoppelt die Laufzeit)
      if (ReversalPctFilter > 0) {
         iDel[bar] = MathAbs(iALMA[bar] - iALMA[bar+1]);

         double sumDel = 0;
         for (int j=0; j < MA.Period; j++) {
            sumDel += iDel[bar+j];
         }
         double avgDel = sumDel/MA.Period;

         double sumPow = 0;
         for (j=0; j < MA.Period; j++) {
            sumPow += MathPow(iDel[bar+j] - avgDel, 2);
         }
         double stdDev = MathSqrt(sumPow/MA.Period);
         double filter = ReversalPctFilter * stdDev;

         if (MathAbs(iALMA[bar]-iALMA[bar+1]) < filter)
            iALMA[bar] = iALMA[bar+1];
      }
      else {
         filter = 0;
      }

      // Trend coloring
      if      (iALMA[bar  ]-iALMA[bar+1] > filter) iTrend[bar] =  1;
      else if (iALMA[bar+1]-iALMA[bar  ] > filter) iTrend[bar] = -1;
      else                                         iTrend[bar] = iTrend[bar+1];

      if (iTrend[bar] > 0) {
         iUpTrend[bar] = iALMA[bar];
         if (iTrend[bar+1] < 0)
            iUpTrend[bar+1] = iALMA[bar+1];
      }
      else if (iTrend[bar] < 0) {
         iDownTrend[bar] = iALMA[bar];
         if (iTrend[bar+1] > 0)
            iDownTrend[bar+1] = iALMA[bar+1];
      }
      else {
         iUpTrend  [bar] = iALMA[bar];
         iDownTrend[bar] = iALMA[bar];
      }
   }

   /*
   // Legende aktualisieren
   if (iTrend[0] > 0) color fontColor = Color.UpTrend;
                            fontColor = Color.DownTrend;
   ObjectSetText(legendLabel, StringConcatenate(WindowExpertName(), "(", MA.Period, ")"), 10, "MS Sans Serif", fontColor);
   */

   // SoundAlerts (bei jedem Tick)
   if (SoundAlerts) /*&&*/ if (iTrend[1]!=iTrend[0]) {
      PlaySound("alert2.wav");
   }

   // TradeSignals (onBarOpen)
   if (TradeSignals) {
      if (iTrend[2] < 0) /*&&*/ if (iTrend[1] > 0) /*&&*/ if (!tradeSignalUp) {
         Alert(Symbol(), " M", Period(), ": ALMA trend change UP (buy signal)");
         tradeSignalUp   = true;
         tradeSignalDown = false;
      }
      if (iTrend[2] > 0) /*&&*/ if (iTrend[1] < 0) /*&&*/ if (!tradeSignalDown) {
         Alert(Symbol(), " M", Period(), ": ALMA trend change DOWN (sell signal)");
         tradeSignalDown = true;
         tradeSignalUp   = false;
      }
   }

   if (startBar > 1) {
      //log("start()   ALMA("+ MA.Period +")   startBar: "+ startBar +"    time: "+ (GetTickCount()-tick) +" msec");
   }
   return(catch("start()"));
}


/**
 * IndexStyles hier setzen (Workaround um die diversen Terminalbugs)
 */
void SetIndexStyles() {
   SetIndexStyle(0, DRAW_LINE, EMPTY, EMPTY, Color.UpTrend  );
   SetIndexStyle(1, DRAW_LINE, EMPTY, EMPTY, Color.DownTrend);
   SetIndexStyle(2, DRAW_LINE, EMPTY, EMPTY, Color.Reversal );
}
