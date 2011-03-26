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

extern int    MA.Periods        = 200;             // averaging period
extern string MA.Timeframe      = "";              // zu verwendender Timeframe (M1, M5, M15 etc. oder "" = aktueller Timeframe)
extern string AppliedPrice      = "Close";         // price used for MA calculation
extern string AppliedPrice.Help = "Open | High | Low | Close | Median | Typical | Weighted"; // Median = (H+L)/2, Typical = (H+L+C)/3, Weighted = (H+L+C+C)/4
extern double GaussianOffset    = 0.85;            // Gaussian distribution offset (0..1)
extern double Sigma             = 6.0;
extern double PctReversalFilter = 0.0;             // minimum percentage MA change to indicate a trend change
extern int    Max.Values        = -1;              // maximum number of indicator values to display: -1 = all
extern int    BarShift          = 0;               // indicator display shifting
extern bool   SoundAlerts       = false;           // enable/disable sound alerts on trend change (intra-bar too)

extern color  Color.UpTrend     = DodgerBlue;      // Farben hier konfigurieren, damit der Code zur Laufzeit Zugriff hat
extern color  Color.DownTrend   = Orange;
extern color  Color.Reversal    = Yellow;

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


double iUpTrend[], iDownTrend[], iReversal[];      // sichtbare Indikatorbuffer
double iALMA[], iTrend[], iDel[];                  // nicht sichtbare Buffer
double wALMA[];                                    // Gewichtung der einzelnen Bars des MA

int    appliedPrice = PRICE_CLOSE;
string objectLabels[], legendLabel, indicatorName;


/**
 * Initialisierung
 *
 * @return int - Fehlerstatus
 */
int init() {
   init = true; init_error = NO_ERROR; __SCRIPT__ = WindowExpertName();
   stdlib_init(__SCRIPT__);

   // Konfiguration auswerten
   if (MA.Periods < 2)
      return(catch("init(1)  Invalid input parameter MA.Periods = "+ MA.Periods, ERR_INVALID_INPUT_PARAMVALUE));

   MA.Timeframe = StringToUpper(StringTrim(MA.Timeframe));
   if (MA.Timeframe == "") int maTimeframe = Period();
   else                        maTimeframe = StringToPeriod(MA.Timeframe);
   if (maTimeframe == 0)
      return(catch("init(2)  Invalid input parameter MA.Timeframe = \""+ MA.Timeframe +"\"", ERR_INVALID_INPUT_PARAMVALUE));

   string price = StringToUpper(StringLeft(StringTrim(AppliedPrice), 1));
   if      (price == "O") appliedPrice = PRICE_OPEN;
   else if (price == "H") appliedPrice = PRICE_HIGH;
   else if (price == "L") appliedPrice = PRICE_LOW;
   else if (price == "C") appliedPrice = PRICE_CLOSE;
   else if (price == "M") appliedPrice = PRICE_MEDIAN;
   else if (price == "T") appliedPrice = PRICE_TYPICAL;
   else if (price == "W") appliedPrice = PRICE_WEIGHTED;
   else
      return(catch("init(3)  Invalid input parameter AppliedPrice = \""+ AppliedPrice +"\"", ERR_INVALID_INPUT_PARAMVALUE));

   // Buffer zuweisen
   IndicatorBuffers(6);
   SetIndexBuffer(0, iUpTrend  );
   SetIndexBuffer(1, iDownTrend);
   SetIndexBuffer(2, iReversal );
   SetIndexBuffer(3, iALMA     );
   SetIndexBuffer(4, iTrend    );
   SetIndexBuffer(5, iDel      );

   // Anzeigeoptionen
   if (MA.Timeframe != "")
      MA.Timeframe = StringConcatenate("x", MA.Timeframe);
   indicatorName = StringConcatenate("ALMA(", MA.Periods, MA.Timeframe, ")");
   IndicatorShortName(indicatorName);
   SetIndexLabel(0, indicatorName);
   SetIndexLabel(1, NULL);
   SetIndexLabel(2, NULL);
   IndicatorDigits(Digits);

   // Legende
   legendLabel = CreateLegendLabel(indicatorName);
   RegisterChartObject(legendLabel, objectLabels);

   // MA-Parameter nach Setzen der Label auf aktuellen Zeitrahmen umrechnen
   if (maTimeframe != Period()) {
      double minutes = maTimeframe * MA.Periods;      // Timeframe * Anzahl Bars = Range in Minuten
      MA.Periods = MathRound(minutes / Period());
   }

   // Zeichenoptionen
   int startDraw = MathMax(MA.Periods-1, Bars-ifInt(Max.Values < 0, Bars, Max.Values));
   SetIndexDrawBegin(0, startDraw);
   SetIndexDrawBegin(1, startDraw);
   SetIndexDrawBegin(2, startDraw);
   SetIndexShift(0, BarShift);
   SetIndexShift(1, BarShift);
   SetIndexShift(2, BarShift);
   SetIndicatorStyles();            // Workaround um die diversen Terminalbugs

   // Gewichtungen berechnen
   ArrayResize(wALMA, MA.Periods);
   int    m = NormalizeDouble(GaussianOffset * (MA.Periods-1), 8);   // (int) double
   double s = MA.Periods / Sigma;
   double wSum;
   for (int i=0; i < MA.Periods; i++) {
      wALMA[i] = MathExp(-((i-m)*(i-m)) / (2*s*s));
      wSum += wALMA[i];
   }
   for (i=0; i < MA.Periods; i++) {
      wALMA[i] /= wSum;                         // Gewichtungen der einzelnen Bars (Summe = 1)
   }
   ReverseDoubleArray(wALMA);                   // Reihenfolge umkehren, um in start() Zugriff zu beschleunigen

   // nach Parameteränderung nicht auf den nächsten Tick warten (nur im "Indicators List" window notwendig)
   if (UninitializeReason() == REASON_PARAMETERS)
      SendTick(false);

   return(catch("init(4)"));
}


/**
 * Deinitialisierung
 *
 * @return int - Fehlerstatus
 */
int deinit() {
   RemoveChartObjects(objectLabels);
   return(catch("deinit()"));
}


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int start() {
   Tick++;
   if      (init_error != NO_ERROR)                   ValidBars = 0;
   else if (last_error == ERR_TERMINAL_NOT_YET_READY) ValidBars = 0;
   else                                               ValidBars = IndicatorCounted();
   ChangedBars = Bars - ValidBars;
   stdlib_onTick(ValidBars);

   // init() nach ERR_TERMINAL_NOT_YET_READY nochmal aufrufen oder abbrechen
   if (init_error == ERR_TERMINAL_NOT_YET_READY) /*&&*/ if (!init)
      init();
   init = false;
   if (init_error != NO_ERROR)
      return(init_error);

   // nach Terminal-Start Abschluß der Initialisierung überprüfen
   if (Bars == 0 || ArraySize(iALMA) == 0) {
      last_error = ERR_TERMINAL_NOT_YET_READY;
      return(last_error);
   }
   last_error = 0;
   // -----------------------------------------------------------------------------


   int tick = GetTickCount();

   // vor Neuberechnung alle Indikatorwerte zurücksetzen
   if (ValidBars == 0) {
      ArrayInitialize(iALMA,      EMPTY_VALUE);
      ArrayInitialize(iUpTrend,   EMPTY_VALUE);
      ArrayInitialize(iDownTrend, EMPTY_VALUE);
      ArrayInitialize(iReversal,  EMPTY_VALUE);
      ArrayInitialize(iTrend,               0);
      SetIndicatorStyles();                        // Workaround um die diversen Terminalbugs
   }

   static int lastTrend;

   // Startbar ermitteln
   if (ChangedBars > Max.Values) /*&&*/ if (Max.Values >= 0)
      ChangedBars = Max.Values;
   int startBar = MathMin(ChangedBars-1, Bars-MA.Periods);

   // Schleife über alle zu berechnenden Bars
   for (int bar=startBar; bar >= 0; bar--) {
      // Moving Average
      iALMA[bar] = 0;
      for (int i=0; i < MA.Periods; i++) {
         iALMA[bar] += wALMA[i] * iMA(NULL, NULL, 1, 0, MODE_SMA, appliedPrice, bar+i);
      }

      // Percentage-Filter (verdoppelt die Laufzeit)
      if (PctReversalFilter > 0) {
         iDel[bar] = MathAbs(iALMA[bar] - iALMA[bar+1]);

         double sumDel = 0;
         for (int j=0; j < MA.Periods; j++) {
            sumDel += iDel[bar+j];
         }
         double avgDel = sumDel/MA.Periods;

         double sumPow = 0;
         for (j=0; j < MA.Periods; j++) {
            sumPow += MathPow(iDel[bar+j] - avgDel, 2);
         }
         double stdDev = MathSqrt(sumPow/MA.Periods);
         double filter = PctReversalFilter * stdDev;

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

   // Legende aktualisieren
   if (iTrend[0] != lastTrend) {
      if      (iTrend[0] > 0) color fontColor = Color.UpTrend;
      else if (iTrend[0] < 0)       fontColor = Color.DownTrend;
      else                          fontColor = Color.Reversal;
      ObjectSetText(legendLabel, indicatorName, 9, "Arial Fett", fontColor);
      int error = GetLastError();
      if (error!=NO_ERROR) /*&&*/ if (error!=ERR_OBJECT_DOES_NOT_EXIST)    // bei offenem Properties-Dialog oder Object::onDrag()
         return(catch("start(1)", error));
   }
   lastTrend = iTrend[0];

   // SoundAlerts bei Trendwechsel (bei jedem Tick möglich)
   if (SoundAlerts) /*&&*/ if (iTrend[1]!=iTrend[0])
      PlaySound("alert2.wav");

   //if (startBar > 1) debug("start()   ALMA("+ MA.Periods +")   startBar: "+ startBar +"    time: "+ (GetTickCount()-tick) +" msec");

   return(catch("start(2)"));
}


/**
 * IndexStyles hier setzen (Workaround um die diversen Terminalbugs)
 */
void SetIndicatorStyles() {
   SetIndexStyle(0, DRAW_LINE, EMPTY, EMPTY, Color.UpTrend  );
   SetIndexStyle(1, DRAW_LINE, EMPTY, EMPTY, Color.DownTrend);
   SetIndexStyle(2, DRAW_LINE, EMPTY, EMPTY, Color.Reversal );
}
