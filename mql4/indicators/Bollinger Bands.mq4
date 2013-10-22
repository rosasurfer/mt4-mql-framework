/**
 * Multi-Timeframe Bollinger Bands
 *
 * Zum Vergleich ist es möglich, zwei Bollinger Bänder gleichzeitig anzuzeigen. Die resultierenden vier Bänder werden dann
 * als Histogramme gezeichnet.
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <stdlib.mqh>

//////////////////////////////////////////////////////////////////////////////// Konfiguration ////////////////////////////////////////////////////////////////////////////////

extern int    MA.Periods        = 200;                               // Anzahl der zu verwendenden Perioden
extern string MA.Timeframe      = "current";                         // zu verwendender Timeframe (M1, M5, M15 etc. oder "" = aktueller Timeframe)
extern string MA.Methods        = "SMA";                             // ein/zwei MA-Methoden (komma-getrennt)
extern string MA.Methods.Help   = "SMA | EMA | SMMA | LWMA | ALMA";
extern string AppliedPrice      = "Close";                           // Preis zur MA- und StdDev-Berechnung
extern string AppliedPrice.Help = "Open | High | Low | Close | Median | Typical | Weighted";
extern string Deviations        = "2.0";                             // ein/zwei Multiplikatoren für die Std.-Abweichung (komma-getrennt)
extern int    Max.Values        = 4000;                              // Anzahl der maximal anzuzeigenden Werte: -1 = alle
extern color  Color.Bands       = RoyalBlue;                         // Farbe hier konfigurieren, damit Code zur Laufzeit Zugriff hat

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <indicators/iALMA.mqh>

#property indicator_chart_window

#property indicator_buffers 7

double iUpperBand1  [], iLowerBand1  [];                             // erstes Band
double iUpperBand2  [], iLowerBand2  [];                             // zweites Band als Histogramm
double iUpperBand2_1[], iLowerBand2_1[];                             // zweites Band als Linie
double iMovAvg[];

int    maMethod1=-1, maMethod2=-1;
int    appliedPrice;
double deviation1, deviation2;
bool   ALMA = false;
double wALMA[];                                                      // ALMA-Gewichtungen


/**
 * Initialisierung
 *
 * @return int - Fehlerstatus
 */
int onInit() {
   // MA.Periods
   if (MA.Periods < 2)                return(catch("onInit(1)   Invalid input parameter MA.Periods = "+ MA.Periods, ERR_INVALID_CONFIG_PARAMVALUE));

   // MA.Timeframe
   MA.Timeframe = StringToUpper(StringTrim(MA.Timeframe));
   if (MA.Timeframe == "CURRENT")     MA.Timeframe = "";
   if (MA.Timeframe == ""       ) int maTimeframe = Period();
   else                               maTimeframe = StrToPeriod(MA.Timeframe);
   if (maTimeframe == -1)             return(catch("onInit(2)   Invalid config/input parameter MA.Timeframe = \""+ MA.Timeframe +"\"", ERR_INVALID_CONFIG_PARAMVALUE));

   // MA.Methods
   string values[];
   int size = Explode(StringToUpper(MA.Methods), ",", values, NULL);

   // MA.Method 1
   string value = StringTrim(values[0]);
   if      (value == "SMA" ) maMethod1 = MODE_SMA;
   else if (value == "EMA" ) maMethod1 = MODE_EMA;
   else if (value == "SMMA") maMethod1 = MODE_SMMA;
   else if (value == "LWMA") maMethod1 = MODE_LWMA;
   else if (value == "ALMA") maMethod1 = MODE_ALMA;
   else                               return(catch("onInit(3)   Invalid input parameter MA.Methods = \""+ MA.Methods +"\"", ERR_INVALID_CONFIG_PARAMVALUE));

   // MA.Method 2
   if (size == 2) {
      value = StringTrim(values[1]);
      if      (value == "SMA" ) maMethod2 = MODE_SMA;
      else if (value == "EMA" ) maMethod2 = MODE_EMA;
      else if (value == "SMMA") maMethod2 = MODE_SMMA;
      else if (value == "LWMA") maMethod2 = MODE_LWMA;
      else if (value == "ALMA") maMethod2 = MODE_ALMA;
      else                            return(catch("onInit(4)   Invalid input parameter MA.Methods = \""+ MA.Methods +"\"", ERR_INVALID_CONFIG_PARAMVALUE));
   }
   else if (size > 2)                 return(catch("onInit(5)   Invalid input parameter MA.Methods = \""+ MA.Methods +"\"", ERR_INVALID_CONFIG_PARAMVALUE));
   ALMA = (maMethod1==MODE_ALMA || maMethod2==MODE_ALMA);

   // AppliedPrice
   string chr = StringToUpper(StringLeft(StringTrim(AppliedPrice), 1));
   if      (chr == "O") appliedPrice = PRICE_OPEN;
   else if (chr == "H") appliedPrice = PRICE_HIGH;
   else if (chr == "L") appliedPrice = PRICE_LOW;
   else if (chr == "C") appliedPrice = PRICE_CLOSE;
   else if (chr == "M") appliedPrice = PRICE_MEDIAN;
   else if (chr == "T") appliedPrice = PRICE_TYPICAL;
   else if (chr == "W") appliedPrice = PRICE_WEIGHTED;
   else                               return(catch("onInit(6)   Invalid input parameter AppliedPrice = \""+ AppliedPrice +"\"", ERR_INVALID_CONFIG_PARAMVALUE));

   // Deviations
   size = Explode(Deviations, ",", values, NULL);
   if (size > 2)                      return(catch("onInit(7)   Invalid input parameter Deviations = \""+ Deviations +"\"", ERR_INVALID_CONFIG_PARAMVALUE));

   // Deviation 1
   value = StringTrim(values[0]);
   if (!StringIsNumeric(value))       return(catch("onInit(8)   Invalid input parameter Deviations = \""+ Deviations +"\"", ERR_INVALID_CONFIG_PARAMVALUE));
   deviation1 = StrToDouble(value);
   if (deviation1 <= 0)               return(catch("onInit(9)   Invalid input parameter Deviations = \""+ Deviations +"\"", ERR_INVALID_CONFIG_PARAMVALUE));

   // Deviation 2
   if (maMethod2 != -1) {
      if (size == 2) {
         value = StringTrim(values[1]);
         if (!StringIsNumeric(value)) return(catch("onInit(10)   Invalid input parameter Deviations = \""+ Deviations +"\"", ERR_INVALID_CONFIG_PARAMVALUE));
         deviation2 = StrToDouble(value);
         if (deviation2 <= 0)         return(catch("onInit(11)   Invalid input parameter Deviations = \""+ Deviations +"\"", ERR_INVALID_CONFIG_PARAMVALUE));
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
      indicatorLongName = indicatorLongName +" / "+ PriceTypeDescription(appliedPrice);
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
   PushObject(legendLabel);
   ObjectSetText(legendLabel, indicatorLongName, 9, "Arial Fett", Color.Bands);
   int error = GetLastError();
   if (error!=NO_ERROR) /*&&*/ if (error!=ERR_OBJECT_DOES_NOT_EXIST) // bei offenem Properties-Dialog oder Object::onDrag()
      return(catch("onInit(12)", error));

   // MA-Parameter nach Setzen der Label auf aktuellen Zeitrahmen umrechnen
   if (maTimeframe != Period()) {
      double minutes = maTimeframe * MA.Periods;                     // Timeframe * Anzahl Bars = Range in Minuten
      MA.Periods = MathRound(minutes / Period());
   }

   // Zeichenoptionen
   int startDraw = Max(MA.Periods-1, Bars-ifInt(Max.Values < 0, Bars, Max.Values));
   SetIndexDrawBegin(0, startDraw);
   SetIndexDrawBegin(1, startDraw);
   SetIndexDrawBegin(2, startDraw);
   SetIndexDrawBegin(3, startDraw);
   SetIndexDrawBegin(4, startDraw);
   SetIndexDrawBegin(5, startDraw);
   SetIndexDrawBegin(6, startDraw);
   SetIndicatorStyles();                                             // Workaround um diverse Terminalbugs (siehe dort)

   // ALMA-Gewichtungen berechnen
   if (ALMA) /*&&*/ if (MA.Periods > 1)                              // MA.Periods < 2 ist möglich bei Umschalten auf zu großen Timeframe
      iALMA.CalculateWeights(wALMA, MA.Periods);

   return(catch("onInit(13)"));
}


/**
 * Deinitialisierung
 *
 * @return int - Fehlerstatus
 */
int onDeinit() {

   // TODO: bei Parameteränderungen darf die vorhandene Legende nicht gelöscht werden

   RemoveChartObjects();
   RepositionLegend();
   return(catch("onDeinit()"));
}


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onTick() {
   // Abschluß der Buffer-Initialisierung überprüfen
   if (ArraySize(iUpperBand1) == 0)                                  // kann bei Terminal-Start auftreten
      return(SetLastError(ERS_TERMINAL_NOT_READY));

   // vor Neuberechnung alle Indikatorwerte zurücksetzen
   if (!ValidBars) {
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
   int startBar = Min(ChangedBars-1, Bars-MA.Periods);

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

      debug("onTick()   IsReverseIndexedDoubleArray(iMovAvg) = "+ IsReverseIndexedDoubleArray(iMovAvg));
      debug("onTick()   iMovAvg = "+ DoublesToStr(array1, ", "));

      start()  iMovAvg     = {1.61582234, 1.61550427, 1.61522141, 1.61491031, 1.61461975, 1.61433817, 1.61409116, 1.61388254, 1.61369392, 1.61348614, 1.61329017, 1.61313936}
               iUpperBand1 = {302939849.67705119, 302939849.67673314, 302939849.67645031, 302939849.67613918, 302939849.6758486, 302939849.67556703, 302939849.67532003, 302939849.67511141, 302939849.67492276, 302939849.67471498, 302939849.674519, 302939849.6743682}
      */
   }

   return(last_error);
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
      if (!histogramColor) {
         double hsv[3]; RGBToHSVColor(Color.Bands, hsv);
         hsv[2] *= 4;                                                // Helligkeit des Histogramms erhöhen
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
