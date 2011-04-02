/**
 * Bollinger-Bands-Indikator. Im Falle einer Normalverteilung können folgenden Daumenregeln angewendet werden:
 *
 * (ma ± 1*stdDev) enthält ungefähr 70% der Beobachtungen
 * (ma ± 2*stdDev) enthält ungefähr 95% der Beobachtungen
 * (ma ± 3*stdDev) enthält mehr als 99% der Beobachtungen
 *
 * @see http://www.statistics4u.info/fundstat_germ/cc_standarddev.html
 */
#include <stdlib.mqh>


#property indicator_chart_window

#property indicator_buffers 2


//////////////////////////////////////////////////////////////// Externe Parameter ////////////////////////////////////////////////////////////////

extern int    MA.Periods        = 200;                         // Anzahl der zu verwendenden Perioden
extern string MA.Timeframe      = "";                          // zu verwendender Timeframe (M1, M5, M15 etc. oder "" = aktueller Timeframe)
extern string MA.Method         = "SMA";                       // MA-Methode
extern string MA.Method.Help    = "SMA | EMA | SMMA | LWMA";
extern string AppliedPrice      = "Median";                    // price used for MA calculation: Median=(H+L)/2, Typical=(H+L+C)/3, Weighted=(H+L+C+C)/4
extern string AppliedPrice.Help = "Open | High | Low | Close | Median | Typical | Weighted";
extern double Deviation         = 1.65;                        // Faktor der Std.-Abweichung der Bollinger-Bänder
extern int    Max.Values        = -1;                          // Anzahl der maximal anzuzeigenden Werte: -1 = alle

extern color  Color.Bands       = RoyalBlue;                   // Farbe hier konfigurieren, damit Code zur Laufzeit Zugriff hat

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


double iUpperBand[], iLowerBand[];     // sichtbare Indikatorbuffer
string objectLabels[];

int maMethod     = MODE_SMA;           // Defaults (wenn in Parametern nicht anderes angegeben)
int appliedPrice = PRICE_MEDIAN;


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

   string method = StringToUpper(StringTrim(MA.Method));
   if      (method == "SMA" ) maMethod = MODE_SMA;
   else if (method == "EMA" ) maMethod = MODE_EMA;
   else if (method == "SMMA") maMethod = MODE_SMMA;
   else if (method == "LWMA") maMethod = MODE_LWMA;
   else
      return(catch("init(3)  Invalid input parameter MA.Method = \""+ MA.Method +"\"", ERR_INVALID_INPUT_PARAMVALUE));

   string price = StringToUpper(StringLeft(StringTrim(AppliedPrice), 1));
   if      (price == "O") appliedPrice = PRICE_OPEN;
   else if (price == "H") appliedPrice = PRICE_HIGH;
   else if (price == "L") appliedPrice = PRICE_LOW;
   else if (price == "C") appliedPrice = PRICE_CLOSE;
   else if (price == "M") appliedPrice = PRICE_MEDIAN;
   else if (price == "T") appliedPrice = PRICE_TYPICAL;
   else if (price == "W") appliedPrice = PRICE_WEIGHTED;
   else
      return(catch("init(4)  Invalid input parameter AppliedPrice = \""+ AppliedPrice +"\"", ERR_INVALID_INPUT_PARAMVALUE));

   if (Deviation <= 0)
      return(catch("init(5)  Invalid input parameter Deviation = "+ NumberToStr(Deviation, ".+"), ERR_INVALID_INPUT_PARAMVALUE));

   // Buffer zuweisen
   SetIndexBuffer(0, iUpperBand);
   SetIndexBuffer(1, iLowerBand);

   // Anzeigeoptionen
   if (MA.Timeframe != "")
      MA.Timeframe = StringConcatenate("x", MA.Timeframe);
   string indicatorName = StringConcatenate("BollingerBands(", MA.Periods, MA.Timeframe, " / ", MovingAverageDescription(maMethod), " / ", AppliedPriceDescription(appliedPrice), " / ", NumberToStr(Deviation, ".1+"), ")");
   IndicatorShortName(indicatorName);
   SetIndexLabel(0, StringConcatenate("UpperBand(", MA.Periods, MA.Timeframe, ")"));
   SetIndexLabel(1, StringConcatenate("LowerBand(", MA.Periods, MA.Timeframe, ")"));
   IndicatorDigits(Digits);

   // Legende
   string legendLabel = CreateLegendLabel(indicatorName);
   RegisterChartObject(legendLabel, objectLabels);
   ObjectSetText(legendLabel, indicatorName, 9, "Arial Fett", Color.Bands);
   int error = GetLastError();
   if (error!=NO_ERROR) /*&&*/ if (error!=ERR_OBJECT_DOES_NOT_EXIST)    // bei offenem Properties-Dialog oder Object::onDrag()
      return(catch("init(6)", error));

   // MA-Parameter nach Setzen der Label auf aktuellen Zeitrahmen umrechnen
   if (maTimeframe != Period()) {
      double minutes = maTimeframe * MA.Periods;   // Timeframe * Anzahl Bars = Range in Minuten
      MA.Periods = MathRound(minutes / Period());
   }

   // Zeichenoptionen
   int startDraw = MathMax(MA.Periods-1, Bars-ifInt(Max.Values < 0, Bars, Max.Values));
   SetIndexDrawBegin(0, startDraw);
   SetIndexDrawBegin(1, startDraw);
   SetIndicatorStyles();                           // Workaround um diverse Terminalbugs (siehe dort)

   // nach Parameteränderung nicht auf den nächsten Tick warten (nur im "Indicators List" window notwendig)
   if (UninitializeReason() == REASON_PARAMETERS)
      SendTick(false);

   return(catch("init(7)"));
}


/**
 * Deinitialisierung
 *
 * @return int - Fehlerstatus
 */
int deinit() {
   RemoveChartObjects(objectLabels);
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
   if (Bars == 0 || ArraySize(iUpperBand) == 0) {
      last_error = ERR_TERMINAL_NOT_YET_READY;
      return(last_error);
   }
   last_error = 0;
   // -----------------------------------------------------------------------------


   // vor Neuberechnung alle Indikatorwerte zurücksetzen
   if (ValidBars == 0) {
      ArrayInitialize(iUpperBand, EMPTY_VALUE);
      ArrayInitialize(iLowerBand, EMPTY_VALUE);
      SetIndicatorStyles();                     // Workaround um diverse Terminalbugs (siehe dort)
   }

   if (MA.Periods < 2)                          // Abbruch bei MA.Periods < 2 (möglich bei Umschalten auf zu großen Timeframe)
      return(NO_ERROR);

   // Startbar ermitteln
   if (ChangedBars > Max.Values) /*&&*/ if (Max.Values >= 0)
      ChangedBars = Max.Values;
   int startBar = MathMin(ChangedBars-1, Bars-MA.Periods);

   /**
    * Bollinger-Bänder berechnen
    *
    * Beobachtungen und Schlußfolgerungen für die verschiedenen Berechnungsmethoden:
    * ------------------------------------------------------------------------------
    * 1) Die Ergebnisse von stdDev(PRICE_CLOSE) und stdDev(PRICE_MEDIAN) stimmen nahezu zu 100% überein.
    *
    * 2) Die Ergebnisse von stdDev(PRICE_MEDIAN) und stdDev(PRICE_HIGH|PRICE_LOW) lassen sich durch Anpassung des Faktors Deviation zu 90-95%
    *    in Übereinstimmung bringen.  Der Wert von stdDev(PRICE_CLOSE)*1.65 entspricht nahezu dem Wert von stdDev(PRICE_HIGH|PRICE_LOW)*1.4.
    *
    * 3) Die Verwendung von PRICE_HIGH|PRICE_LOW ist sehr langsam (High|Low muß manuell ermittelt werden), die von PRICE_CLOSE am schnellsten.
    *
    * 4) Es wird PRICE_MEDIAN verwendet, auch wenn PRICE_HIGH|PRICE_LOW geringfügig exakter wäre.  Doch was ist im Sinne dieses Indikators
    *    "exakt"?  Die einzelnen Werte haben keine tatsächliche Relevanz.  Deshalb kann zusätzlich ein weiteres Bollinger-Band auf Basis einer
    *    anderen MA-Methode angezeigt werden.  Beide Bänder zusammen dienen zur Orientierung, "exakt" messen können sie nichts.
    */
   double ma, dev;

   // Schleife über alle zu berechnenden Bars
   for (int bar=startBar; bar >= 0; bar--) {
      ma  = iMA    (NULL, NULL, MA.Periods, 0, maMethod, appliedPrice, bar);
      dev = iStdDev(NULL, NULL, MA.Periods, 0, maMethod, appliedPrice, bar) * Deviation;
      iUpperBand[bar] = ma + dev;
      iLowerBand[bar] = ma - dev;
   }

   return(catch("start()"));
}


/**
 * Indikator-Styles setzen. Workaround um diverse Terminalbugs (Farbänderungen nach Recompile, Parameteränderung etc.), die erfordern,
 * daß die Styles manchmal in init() und manchmal in start() gesetzt werden müssen, um korrekt angezeigt zu werden.
 */
void SetIndicatorStyles() {
   SetIndexStyle(0, DRAW_LINE, EMPTY, EMPTY, Color.Bands);
   SetIndexStyle(1, DRAW_LINE, EMPTY, EMPTY, Color.Bands);
}
