/**
 * Bollinger-Bands-Indikator
 *
 * Es können zwei MA-Methoden und zwei Multiplikatoren für die Standardabweichung angegeben werden (mit Komma getrennt). Die resultierenden vier Bänder
 * werden als zwei Histogramme gezeichnet.
 *
 * Im Falle einer Normalverteilung können folgenden Daumenregeln angewendet werden:
 *
 * (MA ± 1 * StdDev) enthält ungefähr 70% aller Beobachtungen
 * (MA ± 2 * StdDev) enthält ungefähr 95% aller Beobachtungen
 * (MA ± 3 * StdDev) enthält mehr als 99% aller Beobachtungen
 *
 * @see http://www.statistics4u.info/fundstat_germ/cc_standarddev.html
 *
 *
 * Zu den verschiedenen Berechnungsmethoden:
 * -----------------------------------------
 * - Default ist PRICE_CLOSE. Die Ergebnisse von stdDev(PRICE_CLOSE) und stdDev(PRICE_MEDIAN) stimmen nahezu 100%ig überein.
 *
 * - stdDev(PRICE_HIGH|PRICE_LOW) wäre die technisch exaktere Methode, müßte aber für jede Bar manuell implementiert werden und ist am langsamsten.
 *
 * - Es gilt: 1.65 * stdDev(PRICE_CLOSE) entspricht ca. 1.4 * stdDev(PRICE_HIGH|PRICE_LOW) (Übereinstimmung von 90-95%)
 */
#include <stdlib.mqh>


#property indicator_chart_window

#property indicator_buffers 4


//////////////////////////////////////////////////////////////// Externe Parameter ////////////////////////////////////////////////////////////////

extern int    MA.Periods        = 200;                         // Anzahl der zu verwendenden Perioden
extern string MA.Timeframe      = "";                          // zu verwendender Timeframe (M1, M5, M15 etc. oder "" = aktueller Timeframe)
extern string MA.Methods        = "SMA";                       // bis zu zwei MA-Methoden
extern string MA.Methods.Help   = "SMA | EMA | SMMA | LWMA";
extern string AppliedPrice      = "Close";                     // price used for MA calculation: Median=(H+L)/2, Typical=(H+L+C)/3, Weighted=(H+L+C+C)/4
extern string AppliedPrice.Help = "Open | High | Low | Close | Median | Typical | Weighted";
extern string Deviations        = "2.0";                       // bis zu zwei Multiplikatoren für die Std.-Abweichung
extern int    Max.Values        = -1;                          // Anzahl der maximal anzuzeigenden Werte: -1 = alle

extern color  Color.Bands       = RoyalBlue;                   // Farbe hier konfigurieren, damit Code zur Laufzeit Zugriff hat

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


double iUpperBand1[], iLowerBand1[];           // sichtbare Indikatorbuffer
double iUpperBand2[], iLowerBand2[];

int    maMethod1=-1, maMethod2=-1;
double deviation1,   deviation2;

int    appliedPrice;
string objectLabels[];


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

   // Timeframe
   MA.Timeframe = StringToUpper(StringTrim(MA.Timeframe));
   if (MA.Timeframe == "") int maTimeframe = Period();
   else                        maTimeframe = StringToPeriod(MA.Timeframe);
   if (maTimeframe == 0)
      return(catch("init(2)  Invalid input parameter MA.Timeframe = \""+ MA.Timeframe +"\"", ERR_INVALID_INPUT_PARAMVALUE));

   string values[];
   int size = Explode(StringToUpper(MA.Methods), ",", values);

   // MA-Methode 1
   string value = StringTrim(values[0]);
   if      (value == "SMA" ) maMethod1 = MODE_SMA;
   else if (value == "EMA" ) maMethod1 = MODE_EMA;
   else if (value == "SMMA") maMethod1 = MODE_SMMA;
   else if (value == "LWMA") maMethod1 = MODE_LWMA;
   else
      return(catch("init(3)  Invalid input parameter MA.Methods = \""+ MA.Methods +"\"", ERR_INVALID_INPUT_PARAMVALUE));

   // MA-Methode 2
   if (size == 2) {
      value = StringTrim(values[1]);
      if      (value == "SMA" ) maMethod2 = MODE_SMA;
      else if (value == "EMA" ) maMethod2 = MODE_EMA;
      else if (value == "SMMA") maMethod2 = MODE_SMMA;
      else if (value == "LWMA") maMethod2 = MODE_LWMA;
      else
         return(catch("init(4)  Invalid input parameter MA.Methods = \""+ MA.Methods +"\"", ERR_INVALID_INPUT_PARAMVALUE));
   }
   else if (size > 2)
      return(catch("init(5)  Invalid input parameter MA.Methods = \""+ MA.Methods +"\"", ERR_INVALID_INPUT_PARAMVALUE));

   // AppliedPrice
   string price = StringToUpper(StringLeft(StringTrim(AppliedPrice), 1));
   if      (price == "O") appliedPrice = PRICE_OPEN;
   else if (price == "H") appliedPrice = PRICE_HIGH;
   else if (price == "L") appliedPrice = PRICE_LOW;
   else if (price == "C") appliedPrice = PRICE_CLOSE;
   else if (price == "M") appliedPrice = PRICE_MEDIAN;
   else if (price == "T") appliedPrice = PRICE_TYPICAL;
   else if (price == "W") appliedPrice = PRICE_WEIGHTED;
   else
      return(catch("init(6)  Invalid input parameter AppliedPrice = \""+ AppliedPrice +"\"", ERR_INVALID_INPUT_PARAMVALUE));

   size = Explode(Deviations, ",", values);
   if (size > 2)
      return(catch("init(7)  Invalid input parameter Deviations = \""+ Deviations +"\"", ERR_INVALID_INPUT_PARAMVALUE));

   // Deviation 1
   value = StringTrim(values[0]);
   if (!StringIsNumeric(value))
      return(catch("init(8)  Invalid input parameter Deviations = \""+ Deviations +"\"", ERR_INVALID_INPUT_PARAMVALUE));
   deviation1 = StrToDouble(value);
   if (deviation1 <= 0)
      return(catch("init(9)  Invalid input parameter Deviations = \""+ Deviations +"\"", ERR_INVALID_INPUT_PARAMVALUE));

   // Deviation 2
   if (maMethod2 != -1) {
      if (size == 2) {
         value = StringTrim(values[1]);
         if (!StringIsNumeric(value))
            return(catch("init(10)  Invalid input parameter Deviations = \""+ Deviations +"\"", ERR_INVALID_INPUT_PARAMVALUE));
         deviation2 = StrToDouble(value);
         if (deviation2 <= 0)
            return(catch("init(11)  Invalid input parameter Deviations = \""+ Deviations +"\"", ERR_INVALID_INPUT_PARAMVALUE));
      }
      else
         deviation2 = deviation1;
   }

   // Buffer zuweisen
   SetIndexBuffer(0, iUpperBand1);
   SetIndexBuffer(2, iLowerBand1);
   if (maMethod2 != -1) {
      SetIndexBuffer(1, iUpperBand2);
      SetIndexBuffer(3, iLowerBand2);
   }

   // Anzeigeoptionen
   if (MA.Timeframe != "")
      MA.Timeframe = StringConcatenate("x", MA.Timeframe);
   string indicatorName = StringConcatenate("BollingerBands(", MA.Periods, MA.Timeframe, " / ", MovingAverageDescription(maMethod1));
   if (maMethod2 != -1)
      indicatorName = StringConcatenate(indicatorName, ",", MovingAverageDescription(maMethod2));
   indicatorName = StringConcatenate(indicatorName, " / ", AppliedPriceDescription(appliedPrice), " / ", NumberToStr(deviation1, ".1+"));
   if (maMethod2 != -1)
      indicatorName = StringConcatenate(indicatorName, ",", NumberToStr(deviation2, ".1+"));
   indicatorName = StringConcatenate(indicatorName, ")");
   IndicatorShortName(indicatorName);

   if (maMethod2 == -1) {
      SetIndexLabel(0, StringConcatenate("UpperBand(", MA.Periods, MA.Timeframe, ")"));
      SetIndexLabel(1, NULL);
      SetIndexLabel(2, StringConcatenate("LowerBand(", MA.Periods, MA.Timeframe, ")"));
      SetIndexLabel(3, NULL);
   }
   else {
      SetIndexLabel(0, NULL);
      SetIndexLabel(1, StringConcatenate("UpperBand(", MA.Periods, MA.Timeframe, ")"));
      SetIndexLabel(2, NULL);
      SetIndexLabel(3, StringConcatenate("LowerBand(", MA.Periods, MA.Timeframe, ")"));
   }
   IndicatorDigits(Digits);

   // Legende
   string legendLabel = CreateLegendLabel(indicatorName);
   RegisterChartObject(legendLabel, objectLabels);
   ObjectSetText(legendLabel, indicatorName, 9, "Arial Fett", Color.Bands);
   int error = GetLastError();
   if (error!=NO_ERROR) /*&&*/ if (error!=ERR_OBJECT_DOES_NOT_EXIST)    // bei offenem Properties-Dialog oder Object::onDrag()
      return(catch("init(12)", error));

   // MA-Parameter nach Setzen der Label auf aktuellen Zeitrahmen umrechnen
   if (maTimeframe != Period()) {
      double minutes = maTimeframe * MA.Periods;   // Timeframe * Anzahl Bars = Range in Minuten
      MA.Periods = MathRound(minutes / Period());
   }

   // Zeichenoptionen
   int startDraw = MathMax(MA.Periods-1, Bars-ifInt(Max.Values < 0, Bars, Max.Values));
   SetIndexDrawBegin(0, startDraw);
   SetIndexDrawBegin(1, startDraw);
   SetIndexDrawBegin(2, startDraw);
   SetIndexDrawBegin(3, startDraw);
   SetIndicatorStyles();                           // Workaround um diverse Terminalbugs (siehe dort)

   // nach Parameteränderung nicht auf den nächsten Tick warten (nur im "Indicators List" window notwendig)
   if (UninitializeReason() == REASON_PARAMETERS)
      SendTick(false);

   return(catch("init(13)"));
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
   if (Bars == 0 || ArraySize(iUpperBand1) == 0) {
      last_error = ERR_TERMINAL_NOT_YET_READY;
      return(last_error);
   }
   last_error = 0;
   // -----------------------------------------------------------------------------


   // vor Neuberechnung alle Indikatorwerte zurücksetzen
   if (ValidBars == 0) {
      ArrayInitialize(iUpperBand1, EMPTY_VALUE);
      ArrayInitialize(iLowerBand1, EMPTY_VALUE);
      if (maMethod2 != -1) {
         ArrayInitialize(iUpperBand2, EMPTY_VALUE);
         ArrayInitialize(iLowerBand2, EMPTY_VALUE);
      }
      SetIndicatorStyles();                     // Workaround um diverse Terminalbugs (siehe dort)
   }

   if (MA.Periods < 2)                          // Abbruch bei MA.Periods < 2 (möglich bei Umschalten auf zu großen Timeframe)
      return(NO_ERROR);

   // Startbar ermitteln
   if (ChangedBars > Max.Values) /*&&*/ if (Max.Values >= 0)
      ChangedBars = Max.Values;
   int startBar = MathMin(ChangedBars-1, Bars-MA.Periods);

   double ma, dev;

   // Bollinger-Bänder berechnen: Schleife über alle zu berechnenden Bars
   if (maMethod2 == -1) {
      for (int bar=startBar; bar >= 0; bar--) {
         ma  = iMA    (NULL, NULL, MA.Periods, 0, maMethod1, appliedPrice, bar);
         dev = iStdDev(NULL, NULL, MA.Periods, 0, maMethod1, appliedPrice, bar) * deviation1;
         iUpperBand1[bar] = ma + dev;
         iLowerBand1[bar] = ma - dev;
      }
   }
   else {
      for (bar=startBar; bar >= 0; bar--) {     // MA-1-Code doppelt, um Laufzeit zu verbessern
         ma  = iMA    (NULL, NULL, MA.Periods, 0, maMethod1, appliedPrice, bar);
         dev = iStdDev(NULL, NULL, MA.Periods, 0, maMethod1, appliedPrice, bar) * deviation1;
         iUpperBand1[bar] = ma + dev;
         iLowerBand1[bar] = ma - dev;

         ma  = iMA    (NULL, NULL, MA.Periods, 0, maMethod2, appliedPrice, bar);
         dev = iStdDev(NULL, NULL, MA.Periods, 0, maMethod2, appliedPrice, bar) * deviation2;
         iUpperBand2[bar] = ma + dev;
         iLowerBand2[bar] = ma - dev;
      }
   }

   return(catch("start()"));
}


/**
 * Indikator-Styles setzen. Workaround um diverse Terminalbugs (Farbänderungen nach Recompile, Parameteränderung etc.), die erfordern,
 * daß die Styles manchmal in init() und manchmal in start() gesetzt werden müssen, um korrekt angezeigt zu werden.
 */
void SetIndicatorStyles() {
   if (maMethod2 == -1) {
      SetIndexStyle(0, DRAW_LINE, EMPTY, EMPTY, Color.Bands);
      SetIndexStyle(1, DRAW_NONE, EMPTY, EMPTY, CLR_NONE   );
      SetIndexStyle(2, DRAW_LINE, EMPTY, EMPTY, Color.Bands);
      SetIndexStyle(3, DRAW_NONE, EMPTY, EMPTY, CLR_NONE   );
   }
   else {
      SetIndexStyle(0, DRAW_HISTOGRAM, EMPTY, EMPTY, Color.Bands);
      SetIndexStyle(1, DRAW_HISTOGRAM, EMPTY, EMPTY, Color.Bands);
      SetIndexStyle(2, DRAW_HISTOGRAM, EMPTY, EMPTY, Color.Bands);
      SetIndexStyle(3, DRAW_HISTOGRAM, EMPTY, EMPTY, Color.Bands);
   }
}
