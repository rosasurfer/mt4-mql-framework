/**
 * ALMA (Arnaud Legoux Moving Average)
 *
 *
 * In an attempt to create a new kind of moving average with some friends/colleagues (because I was tired of the classical set
 * of MA's everybody used for the last 10 years) we've created this new one (ALMA).
 *
 * It removes small price fluctuations and enhances the trend by applying a moving average twice, one from left to right and
 * one from right to left. At the end of this process the phase shift (price lag) commonly associated with moving averages is
 * significantly reduced.
 *
 * Zero-phase digital filtering reduces noise in the signal. Conventional filtering reduces noise in the signal but adds delay.
 *
 * The ALMA can give some excellent results if you take the time to tweak the parameters (no need to explain this part, it will
 * be easy for you to find the right settings in less than an hour).
 *
 * Arnaud Legoux
 *
 *
 * @see  http://www.arnaudlegoux.com/
 */
#include <core/define.mqh>
#define     __TYPE__   T_INDICATOR
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <stddefine.mqh>
#include <stdlib.mqh>

//////////////////////////////////////////////////////////////// Externe Parameter ////////////////////////////////////////////////////////////////

extern string MA.Periods        = "200";              // averaging period
extern string MA.Timeframe      = "";                 // averaging timeframe [M1 | M5 | M15] etc.: "" = aktueller Timeframe
extern string AppliedPrice      = "Close";            // price used for MA calculation: Median=(H+L)/2, Typical=(H+L+C)/3, Weighted=(H+L+C+C)/4
extern string AppliedPrice.Help = "Open | High | Low | Close | Median | Typical | Weighted";
extern double GaussianOffset    = 0.85;               // Gaussian distribution offset (0..1)
extern double Sigma             = 6.0;                // Sigma parameter
extern int    Max.Values        = 2000;               // maximum number of indicator values to display: -1 = all

extern color  Color.UpTrend     = DodgerBlue;         // Farbverwaltung hier, damit Code Zugriff hat
extern color  Color.DownTrend   = Orange;

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>

#property indicator_chart_window

#property indicator_buffers 4

#property indicator_width1  0
#property indicator_width2  0
#property indicator_width3  2
#property indicator_width4  2


double bufferMA       [];                             // vollst. Indikator: Anzeige im "Data Window" (im Chart unsichtbar)
double bufferTrend    [];                             // Trend: +1/-1                                (im Chart unsichtbar)
double bufferUpTrend  [];                             // UpTrend-Linie                               (sichtbar)
double bufferDownTrend[];                             // DownTrendTrend-Linie                        (sichtbar)

int    ma.periods;
int    ma.method;
int    appliedPrice;
string legendLabel, indicatorName;

double wALMA[];                                       // Gewichtungen der einzelnen Bars des MA's


/**
 * Initialisierung
 *
 * @return int - Fehlerstatus
 */
int onInit() {
   // (1) Validierung
   // MA.Timeframe (zuerst, da Gültigkeit von MA.Periods davon abhängt)
   MA.Timeframe = StringToUpper(StringTrim(MA.Timeframe));
   if (MA.Timeframe == "") int ma.timeframe = Period();
   else                        ma.timeframe = PeriodToId(MA.Timeframe);
   if (ma.timeframe == -1)             return(catch("onInit(1)   Invalid input parameter MA.Timeframe = \""+ MA.Timeframe +"\"", ERR_INVALID_INPUT));

   // MA.Periods
   string strValue = StringTrim(MA.Periods);
   if (!StringIsNumeric(strValue))     return(catch("onInit(2)   Invalid input parameter MA.Periods = "+ MA.Periods, ERR_INVALID_INPUT));
   double dValue = StrToDouble(strValue);
   if (LT(dValue, 2))                  return(catch("onInit(3)   Invalid input parameter MA.Periods = "+ MA.Periods, ERR_INVALID_INPUT));
   if (NE(MathModFix(dValue, 0.5), 0)) return(catch("onInit(4)   Invalid input parameter MA.Periods = "+ MA.Periods, ERR_INVALID_INPUT));
   strValue = NumberToStr(dValue, ".+");
   if (StringEndsWith(strValue, ".5")) {                             // gebrochene Perioden in ganze Bars umrechnen
      switch (ma.timeframe) {
         case PERIOD_M1 :
         case PERIOD_M5 :
         case PERIOD_M15:
         case PERIOD_MN1:              return(catch("onInit(5)   Invalid input parameter MA.Periods = "+ MA.Periods, ERR_INVALID_INPUT));
         case PERIOD_M30: { ma.periods = Round(dValue* 2); ma.timeframe = PERIOD_M15; break; }
         case PERIOD_H1 : { ma.periods = Round(dValue* 2); ma.timeframe = PERIOD_M30; break; }
         case PERIOD_H4 : { ma.periods = Round(dValue* 4); ma.timeframe = PERIOD_H1;  break; }
         case PERIOD_D1 : { ma.periods = Round(dValue* 6); ma.timeframe = PERIOD_H4;  break; }
         case PERIOD_W1 : { ma.periods = Round(dValue*30); ma.timeframe = PERIOD_H4;  break; }
      }
   }
   else {
      ma.periods = Round(dValue);
   }
   if (ma.timeframe != Period()) {                                   // angegebenen auf aktuellen Timeframe umrechnen
      double minutes = ma.timeframe * ma.periods;                    // Timeframe * Anzahl Bars = Range in Minuten
      ma.periods = Round(minutes/Period());
   }
   MA.Periods = strValue;

   // AppliedPrice
   string char = StringToUpper(StringLeft(StringTrim(AppliedPrice), 1));
   if      (char == "O") appliedPrice = PRICE_OPEN;
   else if (char == "H") appliedPrice = PRICE_HIGH;
   else if (char == "L") appliedPrice = PRICE_LOW;
   else if (char == "C") appliedPrice = PRICE_CLOSE;
   else if (char == "M") appliedPrice = PRICE_MEDIAN;
   else if (char == "T") appliedPrice = PRICE_TYPICAL;
   else if (char == "W") appliedPrice = PRICE_WEIGHTED;
   else                    return(catch("onInit(3)   Invalid input parameter AppliedPrice = \""+ AppliedPrice +"\"", ERR_INVALID_INPUT));


   // (2.1) Bufferverwaltung
   SetIndexBuffer(0, bufferMA       );                               // vollst. Indikator: Anzeige im "Data Window" (im Chart unsichtbar)
   SetIndexBuffer(1, bufferTrend    );                               // Trendsignalisierung: +1/-1                  (im Chart unsichtbar)
   SetIndexBuffer(2, bufferUpTrend  );                               // UpTrend-Linie                               (sichtbar)
   SetIndexBuffer(3, bufferDownTrend);                               // DownTrendTrend-Linie                        (sichtbar)


   // (2.2) Anzeigeoptionen
   string strTimeframe, strAppliedPrice;
   if (MA.Timeframe != "")          strTimeframe    = StringConcatenate("x", MA.Timeframe);
   if (appliedPrice != PRICE_CLOSE) strAppliedPrice = StringConcatenate(" / ", AppliedPriceDescription(appliedPrice));
   indicatorName = StringConcatenate("ALMA(", MA.Periods, strTimeframe, strAppliedPrice, ")");

   IndicatorShortName(indicatorName);
   SetIndexLabel(0, indicatorName);
   SetIndexLabel(1, NULL);
   SetIndexLabel(2, NULL);
   SetIndexLabel(3, NULL);
   IndicatorDigits(Digits);

   // (2.3) Zeichenoptionen
   int startDraw = Max(ma.periods-1, Bars-ifInt(Max.Values < 0, Bars, Max.Values));
   SetIndexDrawBegin(0, startDraw);
   SetIndexDrawBegin(1, startDraw);
   SetIndexDrawBegin(2, startDraw);
   SetIndexDrawBegin(3, startDraw);

   // (2.4) Styles
   SetIndicatorStyles();                                             // Workaround um diverse Terminalbugs (siehe dort)


   // (3) Chart-Legende erzeugen
   legendLabel = CreateLegendLabel(indicatorName);
   ArrayPushString(objects, legendLabel);


   // (4) ALMA-Gewichtungen der einzelnen Bars berechnen (Laufzeit ist vernachlässigbar, siehe Performancedaten in onTick())
   if (ma.periods > 1) {                                             // ma.periods < 2 ist möglich bei Umschalten auf zu großen Timeframe
      ArrayResize(wALMA, ma.periods);
      int    m = Round(GaussianOffset * (ma.periods-1));
      double s = ma.periods / Sigma;
      double wSum;
      for (int i=0; i < ma.periods; i++) {
         wALMA[i] = MathExp(-((i-m)*(i-m)) / (2*s*s));
         wSum += wALMA[i];
      }
      for (i=0; i < ma.periods; i++) {
         wALMA[i] /= wSum;                                           // Summe aller Bars = 1 (100%)
      }
      ReverseDoubleArray(wALMA);                                     // Reihenfolge umkehren, um in onTick() Zugriff zu beschleunigen
   }

   return(catch("onInit(4)"));
}


/**
 * Deinitialisierung
 *
 * @return int - Fehlerstatus
 */
int onDeinit() {
   RemoveChartObjects(objects);
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
   if (ArraySize(bufferMA) == 0)                                        // kann bei Terminal-Start auftreten
      return(SetLastError(ERR_TERMINAL_NOT_YET_READY));

   // vor kompletter Neuberechnung alle Buffer zurücksetzen
   if (ValidBars == 0) {
      ArrayInitialize(bufferMA,        EMPTY_VALUE);
      ArrayInitialize(bufferTrend,               0);
      ArrayInitialize(bufferUpTrend,   EMPTY_VALUE);
      ArrayInitialize(bufferDownTrend, EMPTY_VALUE);
      SetIndicatorStyles();                                             // Workaround um diverse Terminalbugs (siehe dort)
   }

   if (ma.periods < 2)                                                  // Abbruch bei ma.periods < 2 (möglich bei Umschalten auf zu großen Timeframe)
      return(NO_ERROR);


   // (1) Startbar für Neuberechnung ermitteln
   if (ChangedBars > Max.Values) /*&&*/ if (Max.Values >= 0)
      ChangedBars = Max.Values;
   int startBar = Min(ChangedBars-1, Bars-ma.periods);


   // Laufzeit auf Laptop für ALMA(7xD1):
   // -----------------------------------
   // H1 ::ALMA::onTick()   wALMA(  168)=0.000 sec   buffer(2000)=0.110 sec   loops=   336.000
   // M30::ALMA::onTick()   wALMA(  336)=0.000 sec   buffer(2000)=0.250 sec   loops=   672.000
   // M15::ALMA::onTick()   wALMA(  672)=0.000 sec   buffer(2000)=0.453 sec   loops= 1.344.000
   // M5 ::ALMA::onTick()   wALMA( 2016)=0.016 sec   buffer(2000)=1.547 sec   loops= 4.032.000
   // M1 ::ALMA::onTick()   wALMA(10080)=0.000 sec   buffer(2000)=7.110 sec   loops=20.160.000 (20 Mill. Durchläufe!!!)
   //
   // Fazit: wALMA-Berechnung ist vernachlässigbar, Schwachpunkt ist die verschachtelte Schleife in bufferMA-Berechnung


   double curValue, prevValue;


   // (2) geänderte Bars (neu-)berechnen
   for (int bar=startBar; bar >= 0; bar--) {
      // der eigentliche Moving Average
      bufferMA[bar] = 0;
      switch (appliedPrice) {                                           // der am häufigsten verwendete Fall (Close) wird zuerst geprüft
         case PRICE_CLOSE: for (int i=0; i < ma.periods; i++) bufferMA[bar] += wALMA[i] *                                         Close[bar+i]; break;
         case PRICE_OPEN:  for (    i=0; i < ma.periods; i++) bufferMA[bar] += wALMA[i] *                                         Open [bar+i]; break;
         case PRICE_HIGH:  for (    i=0; i < ma.periods; i++) bufferMA[bar] += wALMA[i] *                                         High [bar+i]; break;
         case PRICE_LOW:   for (    i=0; i < ma.periods; i++) bufferMA[bar] += wALMA[i] *                                         Low  [bar+i]; break;
         default:          for (    i=0; i < ma.periods; i++) bufferMA[bar] += wALMA[i] * iMA(NULL, NULL, 1, 0, MODE_SMA, appliedPrice, bar+i);
      }

      // Trend coloring (minimalste Reversal-Glättung um 1 Point durch Normalisierung)
      curValue  = NormalizeDouble(bufferMA[bar  ], Digits);
      prevValue = NormalizeDouble(bufferMA[bar+1], Digits);

      if (curValue > prevValue) {
         bufferTrend    [bar] = 1;
         bufferUpTrend  [bar] = bufferMA[bar];
         bufferDownTrend[bar] = EMPTY_VALUE;

         if (bufferTrend[bar+1] < 0) bufferUpTrend  [bar+1] = bufferMA[bar+1];
         else                        bufferDownTrend[bar+1] = EMPTY_VALUE;
      }
      else if (curValue < prevValue) {
         bufferTrend    [bar] = -1;
         bufferUpTrend  [bar] = EMPTY_VALUE;
         bufferDownTrend[bar] = bufferMA[bar];

         if (bufferTrend[bar+1] > 0) bufferDownTrend[bar+1] = bufferMA[bar+1];
         else                        bufferUpTrend  [bar+1] = EMPTY_VALUE;
      }
      else /*(curValue == prevValue)*/ {
         bufferTrend[bar] = bufferTrend[bar+1];

         if (bufferTrend[bar] > 0) {
            bufferUpTrend  [bar  ] = bufferMA[bar];
            bufferDownTrend[bar  ] = EMPTY_VALUE;
            bufferDownTrend[bar+1] = EMPTY_VALUE;
         }
         else {
            bufferUpTrend  [bar  ] = EMPTY_VALUE;
            bufferDownTrend[bar  ] = bufferMA[bar];
            bufferUpTrend  [bar+1] = EMPTY_VALUE;
         }
      }
   }
   if (startBar < 0)                                                    // Signalisieren, wenn Bars für Berechnung nicht ausreichen.
      SetLastError(ERR_HISTORY_INSUFFICIENT);

   static double lastTrend, lastValue;                                  // Trend und Value des letzten Ticks


   // (3.1) Legende aktualisieren: Farbe bei Trendwechsel
   if (NE(bufferTrend[0], lastTrend)) {
      ObjectSetText(legendLabel, ObjectDescription(legendLabel), 9, "Arial Fett", ifInt(bufferTrend[0]>0, Color.UpTrend, Color.DownTrend));
      int error = GetLastError();
      if (IsError(error)) /*&&*/ if (error!=ERR_OBJECT_DOES_NOT_EXIST)  // bei offenem Properties-Dialog oder Object::onDrag()
         return(catch("onTick(1)", error));
   }
   lastTrend = bufferTrend[0];


   // (3.2) Wert in Legende aktualisieren
   if (NE(curValue, lastValue)) {
      ObjectSetText(legendLabel,
                    StringConcatenate(indicatorName, "    ", NumberToStr(curValue, PriceFormat)),
                    ObjectGet(legendLabel, OBJPROP_FONTSIZE));
   }
   lastValue = curValue;

   return(catch("onTick(2)"));
}


/**
 * Indikator-Styles setzen. Workaround um diverse Terminalbugs (Farb-/Styleänderungen nach Recompile), die erfordern, daß die Styles
 * in der Regel in init(), nach Recompile jedoch in start() gesetzt werden müssen, um korrekt angezeigt zu werden.
 */
void SetIndicatorStyles() {
   SetIndexStyle(0, DRAW_NONE, EMPTY, EMPTY, CLR_NONE       );
   SetIndexStyle(1, DRAW_NONE, EMPTY, EMPTY, CLR_NONE       );
   SetIndexStyle(2, DRAW_LINE, EMPTY, EMPTY, Color.UpTrend  );
   SetIndexStyle(3, DRAW_LINE, EMPTY, EMPTY, Color.DownTrend);
}
