/**
 * Arnaud Legoux Moving Average
 *
 * @see        http://www.arnaudlegoux.com/
 */
#include <stdlib.mqh>


#property indicator_chart_window

#property indicator_buffers 3

#property indicator_width1  2
#property indicator_width2  2
#property indicator_width3  2


//////////////////////////////////////////////////////////////// Externe Parameter ////////////////////////////////////////////////////////////////

extern int    MA.Periods        = 200;                // averaging period
extern string MA.Timeframe      = "";                 // zu verwendender Timeframe (M1, M5, M15 etc. oder "" = aktueller Timeframe)

extern string AppliedPrice      = "Close";            // price used for MA calculation: Median=(H+L)/2, Typical=(H+L+C)/3, Weighted=(H+L+C+C)/4
extern string AppliedPrice.Help = "Open | High | Low | Close | Median | Typical | Weighted";
extern double GaussianOffset    = 0.85;               // Gaussian distribution offset (0..1)
extern double Sigma             = 6.0;
extern double PctReversalFilter = 0.0;                // minimum percentage MA change to indicate a trend change
extern int    Max.Values        = 2000;               // maximum number of indicator values to display: -1 = all

extern color  Color.UpTrend     = DodgerBlue;         // Farben hier konfigurieren, damit Code zur Laufzeit Zugriff hat
extern color  Color.DownTrend   = Orange;
extern color  Color.Reversal    = Yellow;

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


double Pip;
int    PipDigits;
int    PipPoints;
string PriceFormat;

double iALMA[], iUpTrend[], iDownTrend[];                            // sichtbare Indikatorbuffer
double iSMA[], iTrend[], iBarDiff[];                                 // nicht sichtbare Buffer
double wALMA[];                                                      // Gewichtungen der einzelnen Bars des MA

int    appliedPrice;
string chartObjects[], legendLabel, indicatorName;


/**
 * Initialisierung
 *
 * @return int - Fehlerstatus
 */
int init() {
   init = true; init_error = NO_ERROR; __SCRIPT__ = WindowExpertName();
   stdlib_init(__SCRIPT__);

   PipDigits   = Digits & (~1);
   PipPoints   = MathPow(10, Digits-PipDigits) +0.1;                 // (int) double
   Pip         = 1/MathPow(10, PipDigits);
   PriceFormat = "."+ PipDigits + ifString(Digits==PipDigits, "", "'");


   // Konfiguration auswerten
   if (MA.Periods < 2)
      return(catch("init(1)  Invalid input parameter MA.Periods = "+ MA.Periods, ERR_INVALID_INPUT_PARAMVALUE));

   MA.Timeframe = StringToUpper(StringTrim(MA.Timeframe));
   if (MA.Timeframe == "") int maTimeframe = Period();
   else                        maTimeframe = PeriodToId(MA.Timeframe);
   if (maTimeframe == -1)
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
   SetIndexBuffer(0, iALMA     );      // nur für DataBox-Anzeige der aktuellen Werte (im Chart unsichtbar)
   SetIndexBuffer(1, iUpTrend  );
   SetIndexBuffer(2, iDownTrend);
   SetIndexBuffer(3, iSMA      );      // SMA-Zwischenspeicher für ALMA-Berechnung
   SetIndexBuffer(4, iTrend    );      // Trend (-1/+1) für jede einzelne Bar
   SetIndexBuffer(5, iBarDiff  );      // Änderung des ALMA-Values gegenüber der vorherigen Bar (absolut)

   // Anzeigeoptionen
   string strTimeframe="", strAppliedPrice="";
   if (MA.Timeframe!="")          strTimeframe    = StringConcatenate("x", MA.Timeframe);
   if (appliedPrice!=PRICE_CLOSE) strAppliedPrice = StringConcatenate(" / ", AppliedPriceDescription(appliedPrice));

   indicatorName = StringConcatenate("ALMA(", MA.Periods, strTimeframe, strAppliedPrice, ")");
   IndicatorShortName(indicatorName);
   SetIndexLabel(0, indicatorName);
   SetIndexLabel(1, NULL);
   SetIndexLabel(2, NULL);
   IndicatorDigits(Digits);

   // Legende
   legendLabel = CreateLegendLabel(indicatorName);
   ArrayPushString(chartObjects, legendLabel);

   // MA-Parameter nach Setzen der Label auf aktuellen Zeitrahmen umrechnen
   if (maTimeframe != Period()) {
      double minutes = maTimeframe * MA.Periods;               // Timeframe * Anzahl Bars = Range in Minuten
      MA.Periods = MathRound(minutes / Period());
   }

   // TODO: Meldung ausgeben, wenn Indikator wegen zu weniger Bars nicht berechnet werden kann (startDraw = 0)

   // Zeichenoptionen
   int startDraw = MathMax(MA.Periods-1, Bars-ifInt(Max.Values < 0, Bars, Max.Values));
   SetIndexDrawBegin(0, startDraw);
   SetIndexDrawBegin(1, startDraw);
   SetIndexDrawBegin(2, startDraw);
   SetIndicatorStyles();                                       // Workaround um diverse Terminalbugs (siehe dort)

   // Gewichtungen berechnen
   if (MA.Periods > 1) {                                       // MA.Periods < 2 ist möglich bei Umschalten auf zu großen Timeframe
      ArrayResize(wALMA, MA.Periods);
      int    m = MathRound(GaussianOffset * (MA.Periods-1));   // (int) double
      double s = MA.Periods / Sigma;
      double wSum;
      for (int i=0; i < MA.Periods; i++) {
         wALMA[i] = MathExp(-((i-m)*(i-m)) / (2*s*s));
         wSum += wALMA[i];
      }
      for (i=0; i < MA.Periods; i++) {
         wALMA[i] /= wSum;                                     // Gewichtungen der einzelnen Bars (Summe = 1)
      }
      ReverseDoubleArray(wALMA);                               // Reihenfolge umkehren, um in start() Zugriff zu beschleunigen
   }

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
   RemoveChartObjects(chartObjects);
   RepositionLegend();
   return(catch("deinit()"));
}


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int start() {
   Tick++;
   if      (init_error != NO_ERROR)                   UnchangedBars = 0;
   else if (last_error == ERR_TERMINAL_NOT_YET_READY) UnchangedBars = 0;
   else                                               UnchangedBars = IndicatorCounted();
   ChangedBars = Bars - UnchangedBars;
   stdlib_onTick(UnchangedBars);

   // init() nach ERR_TERMINAL_NOT_YET_READY nochmal aufrufen oder abbrechen
   if (init_error == ERR_TERMINAL_NOT_YET_READY) /*&&*/ if (!init)
      init();
   init = false;
   if (init_error != NO_ERROR)
      return(init_error);

   // Abschluß der Chart-Initialisierung überprüfen
   if (Bars == 0 || ArraySize(iALMA) == 0) {             // tritt u.U. bei Terminal-Start auf
      last_error = ERR_TERMINAL_NOT_YET_READY;
      return(last_error);
   }
   last_error = NO_ERROR;
   // -----------------------------------------------------------------------------


   // vor Neuberechnung alle Indikatorwerte zurücksetzen
   if (UnchangedBars == 0) {
      ArrayInitialize(iALMA,      EMPTY_VALUE);
      ArrayInitialize(iUpTrend,   EMPTY_VALUE);
      ArrayInitialize(iDownTrend, EMPTY_VALUE);
      ArrayInitialize(iSMA,       EMPTY_VALUE);
      ArrayInitialize(iTrend,               0);
      SetIndicatorStyles();                        // Workaround um diverse Terminalbugs (siehe dort)
   }

   if (MA.Periods < 2)                             // Abbruch bei MA.Periods < 2 (möglich bei Umschalten auf zu großen Timeframe)
      return(NO_ERROR);

   // Startbar ermitteln
   if (ChangedBars > Max.Values) /*&&*/ if (Max.Values >= 0)
      ChangedBars = Max.Values;
   int startBar = MathMin(ChangedBars-1, Bars-MA.Periods);

   // TODO: Meldung ausgeben, wenn Indikator wegen zu weniger Bars nicht berechnet werden kann (startDraw = 0)


   // Laufzeitverteilung:  Schleife          -  5%                                   5%    10%
   // -------------------  iMA()             - 80%  bei Verwendung von OHLC-Arrays  30% -> 60%
   //                      Rechenoperationen - 15%                                  15%    30%
   //
   // Laptop vor Optimierung:
   // M5 - ALMA(350xM30)::start()   ALMA(2100)    startBar=1999   loop passes= 4.197.900   time1=203 msec   time2= 3125 msec   time3= 3766 msec
   // M1 - ALMA(350xM30)::start()   ALMA(10500)   startBar=1999   loop passes=20.989.500   time1=953 msec   time2=16094 msec   time3=18969 msec


   static int    lastTrend;
   static double lastValue;


   // Schleife über alle zu berechnenden Bars
   for (int bar=startBar; bar >= 0; bar--) {
      // der eigentliche Moving Average
      iALMA[bar] = 0;
      switch (appliedPrice) {
         case PRICE_CLOSE: for (int i=0; i < MA.Periods; i++) iALMA[bar] += wALMA[i] * Close[bar+i]; break;
         case PRICE_OPEN:  for (    i=0; i < MA.Periods; i++) iALMA[bar] += wALMA[i] * Open [bar+i]; break;
         case PRICE_HIGH:  for (    i=0; i < MA.Periods; i++) iALMA[bar] += wALMA[i] * High [bar+i]; break;
         case PRICE_LOW:   for (    i=0; i < MA.Periods; i++) iALMA[bar] += wALMA[i] * Low  [bar+i]; break;
         default:
            for (i=0; i < MA.Periods; i++) {
               iALMA[bar] += wALMA[i] * iMA(NULL, NULL, 1, 0, MODE_SMA, appliedPrice, bar+i);
            }
      }

      // Percentage-Filter für Reversal-Smoothing (verdoppelt Laufzeit und ist unsinnig implementiert)
      if (PctReversalFilter > 0) {
         iBarDiff[bar] = MathAbs(iALMA[bar] - iALMA[bar+1]);               // ALMA-Änderung gegenüber der vorherigen Bar

         double sumDel = 0;
         for (int j=0; j < MA.Periods; j++) {
            sumDel += iBarDiff[bar+j];
         }
         double avgDel = sumDel/MA.Periods;                                // durchschnittliche ALMA-Änderung von Bar zu Bar

         double sumPow = 0;
         for (j=0; j < MA.Periods; j++) {
            sumPow += MathPow(iBarDiff[bar+j] - avgDel, 2);
         }
         double filter = PctReversalFilter * MathSqrt(sumPow/MA.Periods);  // PctReversalFilter * stdDev

         if (iBarDiff[bar] < filter)
            iALMA[bar] = iALMA[bar+1];
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

   // Trendanzeige aktualisieren
   if (iTrend[0] != lastTrend) {
      if      (iTrend[0] > 0) color fontColor = Color.UpTrend;
      else if (iTrend[0] < 0)       fontColor = Color.DownTrend;
      else                          fontColor = Color.Reversal;
      ObjectSetText(legendLabel, ObjectDescription(legendLabel), 9, "Arial Fett", fontColor);
      int error = GetLastError();
      if (error!=NO_ERROR) /*&&*/ if (error!=ERR_OBJECT_DOES_NOT_EXIST)    // bei offenem Properties-Dialog oder Object::onDrag()
         return(catch("start(1)", error));
   }
   lastTrend = iTrend[0];

   // Wertanzeige aktualisieren
   double normalizedValue = NormalizeDouble(iALMA[0], Digits);
   if (NE(normalizedValue, lastValue)) {
      ObjectSetText(legendLabel,
                    StringConcatenate(indicatorName, "    ", NumberToStr(normalizedValue, PriceFormat)),
                    ObjectGet(legendLabel, OBJPROP_FONTSIZE));
   }
   lastValue = normalizedValue;

   return(catch("start(2)"));
}


/**
 * Indikator-Styles setzen. Workaround um diverse Terminalbugs (Farbänderungen nach Recompile, Parameteränderung etc.), die erfordern,
 * daß die Styles manchmal in init() und manchmal in start() gesetzt werden müssen, um korrekt angezeigt zu werden.
 */
void SetIndicatorStyles() {
   SetIndexStyle(0, DRAW_NONE, EMPTY, EMPTY, CLR_NONE       );
   SetIndexStyle(1, DRAW_LINE, EMPTY, EMPTY, Color.UpTrend  );
   SetIndexStyle(2, DRAW_LINE, EMPTY, EMPTY, Color.DownTrend);
}
