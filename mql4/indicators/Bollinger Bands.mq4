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
 * - stdDev(PRICE_HIGH|PRICE_LOW) wäre die technisch exakter Methode, müßte aber für jede Bar manuell implementiert werden und ist am langsamsten.
 * - Es gilt: 1.65 * stdDev(PRICE_CLOSE) entspricht ca. 1.4 * stdDev(PRICE_HIGH|PRICE_LOW) (Übereinstimmung von 90-95%)
 */
#include <stdlib.mqh>

#property indicator_chart_window

#property indicator_buffers 7


//////////////////////////////////////////////////////////////// Externe Parameter ////////////////////////////////////////////////////////////////

extern int    MA.Periods        = 200;                         // Anzahl der zu verwendenden Perioden
extern string MA.Timeframe      = "";                          // zu verwendender Timeframe (M1, M5, M15 etc. oder "" = aktueller Timeframe)
extern string MA.Methods        = "SMA";                       // ein oder zwei MA-Methoden
extern string MA.Methods.Help   = "SMA | EMA | SMMA | LWMA | ALMA";
extern string AppliedPrice      = "Close";                     // price used for MA calculation: Median=(H+L)/2, Typical=(H+L+C)/3, Weighted=(H+L+C+C)/4
extern string AppliedPrice.Help = "Open | High | Low | Close | Median | Typical | Weighted";
extern string Deviations        = "2.0";                       // ein oder zwei Multiplikatoren für die Std.-Abweichung
extern int    Max.Values        = 2000;                        // Anzahl der maximal anzuzeigenden Werte: -1 = alle
extern color  Color.Bands       = RoyalBlue;                   // Farbe hier konfigurieren, damit Code zur Laufzeit Zugriff hat
extern string ___________________________;
extern string Per.Symbol.Configuration;                        // Label für symbolspezifische .ini-Konfiguration, ie. "Slow.{symbol}"

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


double iUpperBand1  [], iLowerBand1  [];                    // sichtbare Indikatorbuffer: erstes Band
double iUpperBand2  [], iLowerBand2  [];                    //                            zweites Band als Histogramm
double iUpperBand2_1[], iLowerBand2_1[];                    //                            zweites Band als Linie
double iMovAvg[];

int    maMethod1=-1, maMethod2=-1;
int    appliedPrice;
double deviation1, deviation2;
bool   ALMA = false;
double wALMA[], ALMA.GaussianOffset=0.85, ALMA.Sigma=6.0;   // ALMA-Parameter: Gewichtungen der einzelnen Bars etc.

string chartObjects[];


/**
 * Initialisierung
 *
 * @return int - Fehlerstatus
 */
int init() {
   if (IsError(onInit(T_INDICATOR)))
      return(last_error);

   // Konfiguration einlesen
   bool   externalConfig = false;
   string configSection, configLabel;

   // externe symbolspezifische Konfiguration?
   configLabel = StringToLower(StringTrim(Per.Symbol.Configuration));
   if (configLabel != "") {
      if (!StringContains(configLabel, "{symbol}"))
         return(catch("init(1)  Invalid input parameter Per.Symbol.Configuration = \""+ Per.Symbol.Configuration +"\"", ERR_INVALID_INPUT_PARAMVALUE));
      configSection  = WindowExpertName();
      configLabel    = StringReplace(configLabel, "{symbol}", GetStandardSymbol(Symbol()));
      externalConfig = true;
   }

   // Periodenanzahl
   if (externalConfig)
      MA.Periods = GetGlobalConfigInt(configSection, configLabel +".MA.Periods", MA.Periods);
   if (MA.Periods < 2)
      return(catch("init(2)  Invalid config/input parameter {"+ configLabel +"}.MA.Periods = "+ MA.Periods, ERR_INVALID_CONFIG_PARAMVALUE));

   // Timeframe
   MA.Timeframe = StringToUpper(StringTrim(MA.Timeframe));
   if (externalConfig)
      MA.Timeframe = GetGlobalConfigString(configSection, configLabel +".MA.Timeframe", MA.Timeframe);
   if (MA.Timeframe == "") int maTimeframe = Period();
   else                        maTimeframe = PeriodToId(MA.Timeframe);
   if (maTimeframe == -1)
      return(catch("init(3)  Invalid config/input parameter {"+ configLabel +"}.MA.Timeframe = \""+ MA.Timeframe +"\"", ERR_INVALID_CONFIG_PARAMVALUE));

   // MA-Methoden
   if (externalConfig)
      MA.Methods = GetGlobalConfigString(configSection, configLabel +".MA.Methods", MA.Methods);
   string values[];
   int size = Explode(StringToUpper(MA.Methods), ",", values, NULL);

   // MA-Methode 1
   string value = StringTrim(values[0]);
   if      (value == "SMA" )   maMethod1 = MODE_SMA;
   else if (value == "EMA" )   maMethod1 = MODE_EMA;
   else if (value == "SMMA")   maMethod1 = MODE_SMMA;
   else if (value == "LWMA")   maMethod1 = MODE_LWMA;
   else if (value == "ALMA") { maMethod1 = MODE_ALMA; ALMA = true; }
   else
      return(catch("init(4)  Invalid config/input parameter {"+ configLabel +"}.MA.Methods = \""+ MA.Methods +"\"", ERR_INVALID_CONFIG_PARAMVALUE));

   // MA-Methode 2
   if (size == 2) {
      value = StringTrim(values[1]);
      if      (value == "SMA" )   maMethod2 = MODE_SMA;
      else if (value == "EMA" )   maMethod2 = MODE_EMA;
      else if (value == "SMMA")   maMethod2 = MODE_SMMA;
      else if (value == "LWMA")   maMethod2 = MODE_LWMA;
      else if (value == "ALMA") { maMethod2 = MODE_ALMA; ALMA = true; }
      else
         return(catch("init(5)  Invalid config/input parameter {"+ configLabel +"}.MA.Methods = \""+ MA.Methods +"\"", ERR_INVALID_CONFIG_PARAMVALUE));
   }
   else if (size > 2)
      return(catch("init(6)  Invalid config/input parameter {"+ configLabel +"}.MA.Methods = \""+ MA.Methods +"\"", ERR_INVALID_CONFIG_PARAMVALUE));

   // AppliedPrice
   if (externalConfig)
      AppliedPrice = GetGlobalConfigString(configSection, configLabel +".AppliedPrice", AppliedPrice);
   string chr = StringToUpper(StringLeft(StringTrim(AppliedPrice), 1));
   if      (chr == "O") appliedPrice = PRICE_OPEN;
   else if (chr == "H") appliedPrice = PRICE_HIGH;
   else if (chr == "L") appliedPrice = PRICE_LOW;
   else if (chr == "C") appliedPrice = PRICE_CLOSE;
   else if (chr == "M") appliedPrice = PRICE_MEDIAN;
   else if (chr == "T") appliedPrice = PRICE_TYPICAL;
   else if (chr == "W") appliedPrice = PRICE_WEIGHTED;
   else
      return(catch("init(7)  Invalid config/input parameter {"+ configLabel +"}.AppliedPrice = \""+ AppliedPrice +"\"", ERR_INVALID_CONFIG_PARAMVALUE));

   // Deviations
   if (externalConfig)
      Deviations = GetGlobalConfigString(configSection, configLabel +".Deviations", Deviations);
   size = Explode(Deviations, ",", values, NULL);
   if (size > 2)
      return(catch("init(8)  Invalid config/input parameter {"+ configLabel +"}.Deviations = \""+ Deviations +"\"", ERR_INVALID_CONFIG_PARAMVALUE));

   // Deviation 1
   value = StringTrim(values[0]);
   if (!StringIsNumeric(value))
      return(catch("init(9)  Invalid config/input parameter {"+ configLabel +"}.Deviations = \""+ Deviations +"\"", ERR_INVALID_CONFIG_PARAMVALUE));
   deviation1 = StrToDouble(value);
   if (deviation1 <= 0)
      return(catch("init(10)  Invalid config/input parameter {"+ configLabel +"}.Deviations = \""+ Deviations +"\"", ERR_INVALID_CONFIG_PARAMVALUE));

   // Deviation 2
   if (maMethod2 != -1) {
      if (size == 2) {
         value = StringTrim(values[1]);
         if (!StringIsNumeric(value))
            return(catch("init(11)  Invalid config/input parameter {"+ configLabel +"}.Deviations = \""+ Deviations +"\"", ERR_INVALID_CONFIG_PARAMVALUE));
         deviation2 = StrToDouble(value);
         if (deviation2 <= 0)
            return(catch("init(12)  Invalid config/input parameter {"+ configLabel +"}.Deviations = \""+ Deviations +"\"", ERR_INVALID_CONFIG_PARAMVALUE));
      }
      else
         deviation2 = deviation1;
   }

   // TODO: Color.Bands überprüfen

   // Buffer zuweisen
   IndicatorBuffers(7);
   SetIndexBuffer(0, iUpperBand1  );   // gerade
   SetIndexBuffer(1, iUpperBand2  );   // ungerade
   SetIndexBuffer(2, iLowerBand1  );   // gerade
   SetIndexBuffer(3, iLowerBand2  );   // ungerade
   SetIndexBuffer(4, iUpperBand2_1);
   SetIndexBuffer(5, iLowerBand2_1);
   SetIndexBuffer(6, iMovAvg      );

   // Anzeigeoptionen
   if (StringLen(MA.Timeframe) > 0)
      MA.Timeframe = "x"+ MA.Timeframe;
   string indicatorShortName = "BollingerBands("+ MA.Periods + MA.Timeframe +")";
   string indicatorLongName  = "BollingerBands("+ MA.Periods + MA.Timeframe +" / "+ MovingAverageMethodDescription(maMethod1);
   if (maMethod2 != -1)
      indicatorLongName = indicatorLongName +","+ MovingAverageMethodDescription(maMethod2);
   if (appliedPrice != PRICE_CLOSE)                                     // AppliedPrice nur anzeigen, wenn != PRICE_CLOSE
      indicatorLongName = indicatorLongName +" / "+ AppliedPriceDescription(appliedPrice);
   if (EQ(deviation1, 2)) {                                             // Deviations nur anzeigen, wenn != 2.0
      if (maMethod2!=-1) /*&&*/ if (NE(deviation2, 2))
         indicatorLongName = indicatorLongName +" / "+ NumberToStr(deviation1, ".1+") +","+ NumberToStr(deviation2, ".1+");
   }
   else {
      indicatorLongName = indicatorLongName +" / "+ NumberToStr(deviation1, ".1+");
      if (maMethod2 != -1)
         indicatorLongName = indicatorLongName +","+ NumberToStr(deviation2, ".1+");
   }
   indicatorLongName = indicatorLongName +")";
   IndicatorShortName(indicatorShortName);

   if (maMethod2 == -1) {
      SetIndexLabel(0, "UpperBand("+ MA.Periods + MA.Timeframe +")");   // Daten-Anzeige von MA-1
      SetIndexLabel(1, NULL);
      SetIndexLabel(2, "LowerBand("+ MA.Periods + MA.Timeframe +")");
      SetIndexLabel(3, NULL);
   }
   else {
      SetIndexLabel(0, NULL);
      SetIndexLabel(1, "UpperBand("+ MA.Periods + MA.Timeframe +")");   // Daten-Anzeige von MA-2
      SetIndexLabel(2, NULL);
      SetIndexLabel(3, "LowerBand("+ MA.Periods + MA.Timeframe +")");
   }
   SetIndexLabel(4, NULL);
   SetIndexLabel(5, NULL);
   SetIndexLabel(6, NULL);
   IndicatorDigits(Digits);

   // Legende
   string legendLabel = CreateLegendLabel(indicatorLongName);
   ArrayPushString(chartObjects, legendLabel);
   ObjectSetText(legendLabel, indicatorLongName, 9, "Arial Fett", Color.Bands);
   int error = GetLastError();
   if (error!=NO_ERROR) /*&&*/ if (error!=ERR_OBJECT_DOES_NOT_EXIST) // bei offenem Properties-Dialog oder Object::onDrag()
      return(catch("init(13)", error));

   // MA-Parameter nach Setzen der Label auf aktuellen Zeitrahmen umrechnen
   if (maTimeframe != Period()) {
      double minutes = maTimeframe * MA.Periods;                     // Timeframe * Anzahl Bars = Range in Minuten
      MA.Periods = MathRound(minutes / Period());
   }

   // Zeichenoptionen
   int startDraw = MathMax(MA.Periods-1, Bars-ifInt(Max.Values < 0, Bars, Max.Values));
   SetIndexDrawBegin(0, startDraw);
   SetIndexDrawBegin(1, startDraw);
   SetIndexDrawBegin(2, startDraw);
   SetIndexDrawBegin(3, startDraw);
   SetIndexDrawBegin(4, startDraw);
   SetIndexDrawBegin(5, startDraw);
   SetIndexDrawBegin(6, startDraw);
   SetIndicatorStyles();                                             // Workaround um diverse Terminalbugs (siehe dort)

   // ALMA-Gewichtungen berechnen
   if (MA.Periods > 1) {                                             // MA.Periods < 2 ist möglich bei Umschalten auf zu großen Timeframe
      if (ALMA) {
         ArrayResize(wALMA, MA.Periods);
         int    m = MathRound(ALMA.GaussianOffset * (MA.Periods-1)); // (int) double
         double s = MA.Periods / ALMA.Sigma;
         double wSum;
         for (int i=0; i < MA.Periods; i++) {
            wALMA[i] = MathExp(-((i-m)*(i-m)) / (2*s*s));
            wSum += wALMA[i];
         }
         for (i=0; i < MA.Periods; i++) {
            wALMA[i] /= wSum;                                        // Gewichtungen der einzelnen Bars (Summe = 1)
         }
         ReverseDoubleArray(wALMA);                                  // Reihenfolge umkehren, um in start() Zugriff zu beschleunigen
      }
   }

   // nach Parameteränderung nicht auf den nächsten Tick warten (nur im "Indicators List" window notwendig)
   if (UninitializeReason() == REASON_PARAMETERS)
      SendTick(false);

   return(catch("init(14)"));
}


/**
 * Deinitialisierung
 *
 * @return int - Fehlerstatus
 */
int deinit() {

   // TODO: bei Parameteränderungen darf die vorhandene Legende nicht gelöscht werden

   RemoveChartObjects(chartObjects);
   RepositionLegend();
   return(catch("deinit()"));
}


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onTick() {
   // Abschluß der Buffer-Initialisierung überprüfen
   if (ArraySize(iUpperBand1) == 0)                                  // kann bei Terminal-Start auftreten
      return(SetLastError(ERR_TERMINAL_NOT_YET_READY));

   // vor Neuberechnung alle Indikatorwerte zurücksetzen
   if (ValidBars == 0) {
      ArrayInitialize(iUpperBand1,   EMPTY_VALUE);
      ArrayInitialize(iLowerBand1,   EMPTY_VALUE);
      ArrayInitialize(iUpperBand2,   EMPTY_VALUE);
      ArrayInitialize(iLowerBand2,   EMPTY_VALUE);
      ArrayInitialize(iUpperBand2_1, EMPTY_VALUE);
      ArrayInitialize(iLowerBand2_1, EMPTY_VALUE);
      ArrayInitialize(iMovAvg,       EMPTY_VALUE);
      SetIndicatorStyles();                                          // Workaround um diverse Terminalbugs (siehe dort)
   }

   if (MA.Periods < 2)                                               // Abbruch bei MA.Periods < 2 (möglich bei Umschalten auf zu großen Timeframe)
      return(NO_ERROR);

   // Startbar ermitteln
   if (ChangedBars > Max.Values) /*&&*/ if (Max.Values >= 0)
      ChangedBars = Max.Values;
   int startBar = MathMin(ChangedBars-1, Bars-MA.Periods);

   double dev;

   // Schleife über alle zu berechnenden Bars
   for (int bar=startBar; bar >= 0; bar--) {
      // erstes Band
      if (maMethod1 == MODE_ALMA) {
         iMovAvg[bar] = 0;
         for (int i=0; i < MA.Periods; i++) {
            iMovAvg[bar] += wALMA[i] * iMA(NULL, NULL, 1, 0, MODE_SMA, appliedPrice, bar+i);
         }
         dev = iStdDevOnArray(iMovAvg, WHOLE_ARRAY, MA.Periods, 0, MODE_SMA, bar) * deviation1;
      }
      else {
         iMovAvg[bar] = iMA    (NULL, NULL, MA.Periods, 0, maMethod1, appliedPrice, bar);
         dev          = iStdDev(NULL, NULL, MA.Periods, 0, maMethod1, appliedPrice, bar) * deviation1;
      }
      iUpperBand1[bar] = iMovAvg[bar] + dev;
      iLowerBand1[bar] = iMovAvg[bar] - dev;

      // zweites Band
      if (maMethod2 != -1) {
         iMovAvg[bar] = iMA    (NULL, NULL, MA.Periods, 0, maMethod2, appliedPrice, bar);
         dev          = iStdDev(NULL, NULL, MA.Periods, 0, maMethod2, appliedPrice, bar) * deviation2;
         iUpperBand2  [bar] = iMovAvg[bar] + dev;
         iLowerBand2  [bar] = iMovAvg[bar] - dev;
         iUpperBand2_1[bar] = iUpperBand2[bar];
         iLowerBand2_1[bar] = iLowerBand2[bar];
      }
   }

   if (startBar > 1) {
      /*
      double array1[]; ArrayResize(array1, startBar+1);
      double array2[]; ArrayResize(array2, startBar+1);

      ArrayCopy(array1, iMovAvg,     0, 0, startBar+1);
      ArrayCopy(array2, iUpperBand1, 0, 0, startBar+1);

      debug("onTick()  IsReverseIndexedDoubleArray(iMovAvg) = "+ IsReverseIndexedDoubleArray(iMovAvg));
      debug("onTick()  iMovAvg = "+ DoubleArrayToStr(array1, ", "));

      start()  iMovAvg     = {1.61582234, 1.61550427, 1.61522141, 1.61491031, 1.61461975, 1.61433817, 1.61409116, 1.61388254, 1.61369392, 1.61348614, 1.61329017, 1.61313936}
               iUpperBand1 = {302939849.67705119, 302939849.67673314, 302939849.67645031, 302939849.67613918, 302939849.6758486, 302939849.67556703, 302939849.67532003, 302939849.67511141, 302939849.67492276, 302939849.67471498, 302939849.674519, 302939849.6743682}
      */
   }

   return(catch("onTick()"));
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
      SetIndexStyle(4, DRAW_NONE, EMPTY, EMPTY, CLR_NONE   );
      SetIndexStyle(5, DRAW_NONE, EMPTY, EMPTY, CLR_NONE   );
   }
   else {
      static color histogramColor;
      if (histogramColor == 0) {
         double hsv[3]; RGBToHSVColor(Color.Bands, hsv);
         hsv[2] *= 4;                                    // Helligkeit des Histogramms erhöhen
         if (hsv[2] > 1) {
            hsv[1] /= hsv[2];
            hsv[2] = 1;
         }
         histogramColor = HSVToRGBColor(hsv);
      }
      SetIndexStyle(0, DRAW_HISTOGRAM, EMPTY, EMPTY, histogramColor);
      SetIndexStyle(1, DRAW_HISTOGRAM, EMPTY, EMPTY, histogramColor);
      SetIndexStyle(2, DRAW_HISTOGRAM, EMPTY, EMPTY, histogramColor);
      SetIndexStyle(3, DRAW_HISTOGRAM, EMPTY, EMPTY, histogramColor);
      SetIndexStyle(4, DRAW_LINE,      EMPTY, EMPTY, Color.Bands   );
      SetIndexStyle(5, DRAW_LINE,      EMPTY, EMPTY, Color.Bands   );
   }
   SetIndexStyle(6, DRAW_NONE, EMPTY, EMPTY, CLR_NONE);
   //SetIndexStyle(6, DRAW_LINE, EMPTY, EMPTY, Color.Bands);
}
