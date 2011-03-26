/**
 * Bollinger-Bands-Indikator
 */
#include <stdlib.mqh>


#property indicator_chart_window

#property indicator_buffers 3

#property indicator_color1 C'102,135,232'
#property indicator_color2 C'163,183,241'
#property indicator_color3 C'102,135,232'

#property indicator_style1 STYLE_SOLID
#property indicator_style2 STYLE_DOT
#property indicator_style3 STYLE_SOLID


//////////////////////////////////////////////////////////////// Externe Parameter ////////////////////////////////////////////////////////////////

extern int    MA.Periods     = 200;                         // Anzahl der zu verwendenden Perioden
extern string MA.Timeframe   = "";                          // zu verwendender Timeframe (M1, M5, M15 etc. oder "" = aktueller Timeframe)
extern string MA.Method      = "SMA";                       // MA-Methode
extern string MA.Method.Help = "SMA | EMA | SMMA | LWMA";
extern double Deviation      = 1.65;                        // Abweichung der Bollinger-Bänder vom MA
extern int    Max.Values     = -1;                          // Anzahl der maximal anzuzeigenden Werte: -1 = alle

extern color  Color.Bands    = C'102,135,232';
extern color  Color.MA       = C'163,183,241';              // Farben hier konfigurieren, damit der Code zur Laufzeit Zugriff hat

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


double UpperBand[], MovingAvg[], LowerBand[];      // Indikatorpuffer
int    maMethod;
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

   if (Deviation <= 0)
      return(catch("init(4)  Invalid input parameter Deviation = "+ NumberToStr(Deviation, ".+"), ERR_INVALID_INPUT_PARAMVALUE));

   if (Max.Values < 0)
      Max.Values = Bars;

   // Puffer zuweisen
   SetIndexBuffer(0, UpperBand);
   SetIndexBuffer(1, MovingAvg);
   SetIndexBuffer(2, LowerBand);

   // Anzeigeoptionen
   if (MA.Timeframe != "")
      MA.Timeframe = StringConcatenate("x", MA.Timeframe);
   string indicatorName = StringConcatenate("BollingerBands(", MA.Periods, MA.Timeframe, ")");
   IndicatorShortName(indicatorName);
   SetIndexLabel(0, StringConcatenate("UpperBand(", MA.Periods, MA.Timeframe, ")"));
   SetIndexLabel(1, NULL);
   SetIndexLabel(2, StringConcatenate("LowerBand(", MA.Periods, MA.Timeframe, ")"));
   IndicatorDigits(Digits);

   // Legende
   string legendLabel = CreateLegendLabel(indicatorName);
   RegisterChartObject(legendLabel, objectLabels);
   ObjectSetText(legendLabel, indicatorName, 9, "Arial Fett", Color.Bands);
   int error = GetLastError();
   if (error!=NO_ERROR) /*&&*/ if (error!=ERR_OBJECT_DOES_NOT_EXIST)    // bei offenem Properties-Dialog oder Object::onDrag()
      return(catch("init(5)", error));

   // MA-Parameter nach Setzen der Label auf aktuellen Zeitrahmen umrechnen
   if (maTimeframe != Period()) {
      double minutes = maTimeframe * MA.Periods;      // Timeframe * Anzahl Bars = Range in Minuten
      MA.Periods = MathRound(minutes / Period());
   }

   // nach Parameteränderung nicht auf den nächsten Tick warten (nur im "Indicators List" window notwendig)
   if (UninitializeReason() == REASON_PARAMETERS)
      SendTick(false);

   return(catch("init(6)"));
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
   if (Bars == 0 || ArraySize(UpperBand) == 0) {
      last_error = ERR_TERMINAL_NOT_YET_READY;
      return(last_error);
   }
   last_error = 0;
   // -----------------------------------------------------------------------------


   // vor Neuberechnung alle Indikatorwerte zurücksetzen
   if (ValidBars == 0) {
      ArrayInitialize(UpperBand, EMPTY_VALUE);
      ArrayInitialize(MovingAvg, EMPTY_VALUE);
      ArrayInitialize(LowerBand, EMPTY_VALUE);
   }

   if (MA.Periods < 2)                          // Abbruch bei MA.Periods < 2 (möglich bei Umschalten auf zu großen Timeframe)
      return(0);

   int iLastIndBar = Bars - MA.Periods,         // Index der letzten Indikator-Bar
       bars,                                    // Anzahl der zu berechnenden Bars
       i, k;

   if (iLastIndBar < 0)
      return(0);                                // Abbruch im Falle Bars < Periods


   // Anzahl der zu berechnenden Bars bestimmen
   if (ValidBars == 0) {
      bars = iLastIndBar + 1;                   // alle
   }
   else {                                       // nur die fehlenden Bars
      bars = ChangedBars;
      if (bars > iLastIndBar + 1)
         bars = iLastIndBar + 1;
      // TODO: Eventhandler integrieren: Update nur bei onNewHigh|onNewLow
   }

   // zu berechnende Bars auf Max.Values begrenzen
   if (bars > Max.Values)
      bars = Max.Values;


   /**
    * MovingAverage und Bänder berechnen
    *
    * Folgende Beobachtungen und Schlußfolgerungen wurden für die verschiedenen MA-Methoden gemacht:
    * ----------------------------------------------------------------------------------------------
    * 1) Die Ergebnisse von stdDev(appliedPrice=Close) und stdDev(appliedPrice=Median) stimmen nahezu zu 100% überein.
    *
    * 2) Die Ergebnisse von stdDev(appliedPrice=Median) und stdDev(appliedPrice=High|Low) lassen sich durch Anpassung des Faktors Deviation zu 90-95%
    *    in Übereinstimmung bringen.  Der Wert von stdDev(appliedPrice=Close)*1.65 entspricht nahezu dem Wert von stdDev(appliedPrice=High|Low)*1.4.
    *
    * 3) Die Verwendung von appliedPrice=High|Low ist sehr langsam, die von appliedPrice=Close am schnellsten.
    *
    * 4) Zur Performancesteigerung wird appliedPrice=Median verwendet, auch wenn appliedPrice=High|Low geringfügig exakter scheint.  Denn was ist
    *    im Sinne dieses Indikators "exakt"?  Die einzelnen berechneten Werte haben keine tatsächliche Aussagekraft.  Aus diesem Grunde wird ein
    *    weiteres Bollinger-Band auf SMA-Basis verwendet (dessen einzelne Werte ebenfalls keine tatsächliche Aussagekraft haben).  Beide Indikatoren
    *    zusammen dienen zur Orientierung, "exakt messen" können beide nichts.
    */
   double ma, dev;

   for (i=bars-1; i >= 0; i--) {
      ma  = iMA    (NULL, 0, MA.Periods, 0, maMethod, PRICE_MEDIAN, i);
      dev = iStdDev(NULL, 0, MA.Periods, 0, maMethod, PRICE_MEDIAN, i) * Deviation;
      UpperBand[i] = ma + dev;
      MovingAvg[i] = ma;
      LowerBand[i] = ma - dev;
   }

   return(catch("start()"));
}
