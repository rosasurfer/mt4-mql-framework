/**
 * ALMA: Arnaud Legoux Moving Average  (einzeln implementiert, um die ALMA-spezifischen Parameter anpassen zu können)
 *
 *
 *  From the author:
 *  ----------------
 *  In an attempt to create a new kind of moving average with some friends/colleagues (because I was tired of the classical set
 *  of MA's everybody used for the last 10 years) we've created this new one.
 *
 *  It removes small price fluctuations and enhances the trend by applying a moving average twice, one from left to right and
 *  one from right to left. At the end of this process the phase shift (price lag) commonly associated with moving averages is
 *  significantly reduced.
 *
 *  Zero-phase digital filtering reduces noise in the signal. Conventional filtering reduces noise in the signal but adds delay.
 *
 *  The ALMA can give some excellent results if you take the time to tweak the parameters (no need to explain this part, it will
 *  be easy for you to find the right settings in less than an hour).
 *
 *  Arnaud Legoux
 *  http://www.arnaudlegoux.com/
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <stdlib.mqh>

//////////////////////////////////////////////////////////////////////////////// Konfiguration ////////////////////////////////////////////////////////////////////////////////

extern string MA.Periods            = "200";                         // für einige Timeframes sind gebrochene Werte zulässig (z.B. 1.5 x D1)
extern string MA.Timeframe          = "current";                     // Timeframe: [M1|M5|M15|...], "" = aktueller Timeframe
extern string MA.AppliedPrice       = "Open | High | Low | Close* | Median | Typical | Weighted";

extern double GaussianOffset        = 0.85;                          // Gaussian distribution offset (0..1)
extern double Sigma                 = 6.0;                           // Sigma parameter

extern color  Color.UpTrend         = DodgerBlue;                    // Farbverwaltung hier, damit Code Zugriff hat
extern color  Color.DownTrend       = Orange;

extern int    Max.Values            = 2000;                          // Höchstanzahl darzustellender Werte: -1 = keine Begrenzung
extern int    Shift.Horizontal.Bars = 0;                             // horizontale Shift in Bars
extern int    Shift.Vertical.Pips   = 0;                             // vertikale Shift in Pips

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>

#define MovingAverage.MODE_MA          0        // Buffer-Identifier
#define MovingAverage.MODE_TREND       1
#define MovingAverage.MODE_UPTREND     2        // Bei Unterbrechung eines Down-Trends um eine einzige Bar wird dieser Up-Trend durch den sich fortsetzenden Down-Trend
#define MovingAverage.MODE_DOWNTREND   3        // verdeckt. Um solche kurzfristigen Up-Trends sichtbar zu machen, werden sie im Buffer MODE_UPTREND2 gespeichert, der
#define MovingAverage.MODE_UPTREND2    4        // MODE_DOWNTREND überlagert.

#property indicator_chart_window

#property indicator_buffers 5

#property indicator_width1  0
#property indicator_width2  0
#property indicator_width3  2
#property indicator_width4  2
#property indicator_width5  2

double bufferMA       [];                       // vollst. Indikator: unsichtbar (Anzeige im "Data Window")
double bufferTrend    [];                       // Trend: +/-         unsichtbar
double bufferUpTrend  [];                       // UpTrend-Linie 1:   sichtbar
double bufferDownTrend[];                       // DownTrend-Linie:   sichtbar (überlagert UpTrend 1)
double bufferUpTrend2 [];                       // UpTrend-Linie 2:   sichtbar (überlagert DownTrend, macht im DownTrend UpTrends mit Länge 1 sichtbar)

int    ma.periods;
int    ma.method;
int    ma.appliedPrice;
double alma.weights[];                          // Gewichtungen der einzelnen Bars des ALMA's
double shift.vertical;
string legendLabel, iDescription;


/**
 * Initialisierung
 *
 * @return int - Fehlerstatus
 */
int onInit() {
   // (1) Validierung
   // (1.1) MA.Timeframe zuerst, da Gültigkeit von MA.Periods davon abhängt
   MA.Timeframe = StringToUpper(StringTrim(MA.Timeframe));
   if (MA.Timeframe == "CURRENT")     MA.Timeframe = "";
   if (MA.Timeframe == ""       ) int ma.timeframe = Period();
   else                               ma.timeframe = StrToPeriod(MA.Timeframe);
   if (ma.timeframe == -1)           return(catch("onInit(1)   Invalid input parameter MA.Timeframe = \""+ MA.Timeframe +"\"", ERR_INVALID_INPUT_PARAMVALUE));

   // (1.2) MA.Periods
   string strValue = StringTrim(MA.Periods);
   if (!StringIsNumeric(strValue))   return(catch("onInit(2)   Invalid input parameter MA.Periods = "+ MA.Periods, ERR_INVALID_INPUT_PARAMVALUE));
   double dValue = StrToDouble(strValue);
   if (dValue <= 0)                  return(catch("onInit(3)   Invalid input parameter MA.Periods = "+ MA.Periods, ERR_INVALID_INPUT_PARAMVALUE));
   if (MathModFix(dValue, 0.5) != 0) return(catch("onInit(4)   Invalid input parameter MA.Periods = "+ MA.Periods, ERR_INVALID_INPUT_PARAMVALUE));
   strValue = NumberToStr(dValue, ".+");
   if (StringEndsWith(strValue, ".5")) {                                // gebrochene Perioden in ganze Bars umrechnen
      switch (ma.timeframe) {
         case PERIOD_M1 :
         case PERIOD_M5 :
         case PERIOD_M15:
         case PERIOD_MN1:              return(catch("onInit(5)   Illegal input parameter MA.Periods = "+ MA.Periods, ERR_INVALID_INPUT_PARAMVALUE));
         case PERIOD_M30: dValue *=  2; ma.timeframe = PERIOD_M15; break;
         case PERIOD_H1 : dValue *=  2; ma.timeframe = PERIOD_M30; break;
         case PERIOD_H4 : dValue *=  4; ma.timeframe = PERIOD_H1;  break;
         case PERIOD_D1 : dValue *=  6; ma.timeframe = PERIOD_H4;  break;
         case PERIOD_W1 : dValue *= 30; ma.timeframe = PERIOD_H4;  break;
      }
   }
   switch (ma.timeframe) {                                              // Timeframes > H1 auf H1 umrechnen
      case PERIOD_H4: dValue *=   4; ma.timeframe = PERIOD_H1; break;
      case PERIOD_D1: dValue *=  24; ma.timeframe = PERIOD_H1; break;
      case PERIOD_W1: dValue *= 120; ma.timeframe = PERIOD_H1; break;
   }
   ma.periods = MathRound(dValue);
   if (ma.periods < 2)               return(catch("onInit(6)   Invalid input parameter MA.Periods = "+ MA.Periods, ERR_INVALID_INPUT_PARAMVALUE));
   if (ma.timeframe != Period()) {                                      // angegebenen auf aktuellen Timeframe umrechnen
      double minutes = ma.timeframe * ma.periods;                       // Timeframe * Anzahl Bars = Range in Minuten
      ma.periods = MathRound(minutes/Period());
   }
   MA.Periods = strValue;

   // (1.3) MA.AppliedPrice
   string elems[];
   if (Explode(MA.AppliedPrice, "*", elems, 2) > 1) {
      int size = Explode(elems[0], "|", elems, NULL);
      strValue = elems[size-1];
   }
   else strValue = MA.AppliedPrice;
   ma.appliedPrice = StrToPriceType(strValue);
   if (ma.appliedPrice==-1 || ma.appliedPrice > PRICE_WEIGHTED)
                                     return(catch("onInit(7)   Invalid input parameter MA.AppliedPrice = \""+ MA.AppliedPrice +"\"", ERR_INVALID_INPUT_PARAMVALUE));
   MA.AppliedPrice = PriceTypeDescription(ma.appliedPrice);

   // (1.4) Max.Values
   if (Max.Values < -1)              return(catch("onInit(8)   Invalid input parameter Max.Values = "+ Max.Values, ERR_INVALID_INPUT_PARAMVALUE));

   // (1.5) Colors
   if (Color.UpTrend   == 0xFF000000) Color.UpTrend   = CLR_NONE;    // können vom Terminal falsch gesetzt worden sein
   if (Color.DownTrend == 0xFF000000) Color.DownTrend = CLR_NONE;


   // (2) Chart-Legende erzeugen
   string strTimeframe="", strAppliedPrice="";
   if (MA.Timeframe != "")             strTimeframe    = "x"+ MA.Timeframe;
   if (ma.appliedPrice != PRICE_CLOSE) strAppliedPrice = ", "+ PriceTypeDescription(ma.appliedPrice);
   iDescription = "ALMA("+ MA.Periods + strTimeframe + strAppliedPrice +")";
   legendLabel  = CreateLegendLabel(iDescription);
   PushObject(legendLabel);


   // (3) ALMA-Gewichtungen berechnen (Laufzeit ist vernachlässigbar, siehe Performancedaten in onTick())
   if (ma.periods > 1) {                                                // ma.periods < 2 ist möglich bei Umschalten auf zu großen Timeframe
      ArrayResize(alma.weights, ma.periods);
      double m = MathRound(GaussianOffset * (ma.periods-1));
      double s = ma.periods / Sigma;
      double wSum;
      for (int j, i=0; i < ma.periods; i++) {
         j = ma.periods-1-1;
         alma.weights[j] = MathExp(-(i-m)*(i-m)/(2*s*s));
         wSum           += alma.weights[j];
      }
      for (i=0; i < ma.periods; i++) {
         alma.weights[i] /= wSum;                                       // Summe aller Bars = 1 (100%)
      }
   }


   // (4.1) Bufferverwaltung
   SetIndexBuffer(MovingAverage.MODE_MA,        bufferMA       );       // vollst. Indikator: unsichtbar (Anzeige im "Data Window"
   SetIndexBuffer(MovingAverage.MODE_TREND,     bufferTrend    );       // Trend: +/-         unsichtbar
   SetIndexBuffer(MovingAverage.MODE_UPTREND,   bufferUpTrend  );       // UpTrend-Linie 1:   sichtbar
   SetIndexBuffer(MovingAverage.MODE_DOWNTREND, bufferDownTrend);       // DownTrend-Linie:   sichtbar
   SetIndexBuffer(MovingAverage.MODE_UPTREND2,  bufferUpTrend2 );       // UpTrend-Linie 2:   sichtbar

   // (4.2) Anzeigeoptionen
   IndicatorShortName(iDescription);                                    // Context Menu
   SetIndexLabel(MovingAverage.MODE_MA,        iDescription);           // Tooltip und "Data Window"
   SetIndexLabel(MovingAverage.MODE_TREND,     NULL);
   SetIndexLabel(MovingAverage.MODE_UPTREND,   NULL);
   SetIndexLabel(MovingAverage.MODE_DOWNTREND, NULL);
   SetIndexLabel(MovingAverage.MODE_UPTREND2,  NULL);
   IndicatorDigits(SubPipDigits);

   // (4.3) Zeichenoptionen
   int startDraw = Max(ma.periods-1, Bars-ifInt(Max.Values < 0, Bars, Max.Values)) + Shift.Horizontal.Bars;
   SetIndexDrawBegin(MovingAverage.MODE_MA,        0        ); SetIndexShift(MovingAverage.MODE_MA,        Shift.Horizontal.Bars);
   SetIndexDrawBegin(MovingAverage.MODE_TREND,     0        ); SetIndexShift(MovingAverage.MODE_TREND,     Shift.Horizontal.Bars);
   SetIndexDrawBegin(MovingAverage.MODE_UPTREND,   startDraw); SetIndexShift(MovingAverage.MODE_UPTREND,   Shift.Horizontal.Bars);
   SetIndexDrawBegin(MovingAverage.MODE_DOWNTREND, startDraw); SetIndexShift(MovingAverage.MODE_DOWNTREND, Shift.Horizontal.Bars);
   SetIndexDrawBegin(MovingAverage.MODE_UPTREND2,  startDraw); SetIndexShift(MovingAverage.MODE_UPTREND2,  Shift.Horizontal.Bars);

   shift.vertical = Shift.Vertical.Pips * Pip;                          // TODO: Digits/Point-Fehler abfangen

   // (4.4) Styles
   SetIndicatorStyles();                                                // Workaround um diverse Terminalbugs (siehe dort)

   return(catch("onInit(9)"));
}


/**
 * Deinitialisierung
 *
 * @return int - Fehlerstatus
 */
int onDeinit() {
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
   if (ArraySize(bufferMA) == 0)                                        // kann bei Terminal-Start auftreten
      return(SetLastError(ERS_TERMINAL_NOT_READY));

   // vor kompletter Neuberechnung Buffer zurücksetzen
   if (!ValidBars) {
      ArrayInitialize(bufferMA,        EMPTY_VALUE);
      ArrayInitialize(bufferTrend,               0);
      ArrayInitialize(bufferUpTrend,   EMPTY_VALUE);
      ArrayInitialize(bufferDownTrend, EMPTY_VALUE);
      ArrayInitialize(bufferUpTrend2,  EMPTY_VALUE);
      SetIndicatorStyles();                                             // Workaround um diverse Terminalbugs (siehe dort)
   }

   if (ma.periods < 2)                                                  // Abbruch bei ma.periods < 2 (möglich bei Umschalten auf zu großen Timeframe)
      return(NO_ERROR);


   // (1) Startbar der Berechnung ermitteln
   if (ChangedBars > Max.Values) /*&&*/ if (Max.Values >= 0)
      ChangedBars = Max.Values;
   int startBar = Min(ChangedBars-1, Bars-ma.periods);
   if (startBar < 0) {
      if (Indicator.IsSuperContext())
         return(catch("onTick(1)", ERR_HISTORY_INSUFFICIENT));
      SetLastError(ERR_HISTORY_INSUFFICIENT);                           // Signalisieren, falls Bars für Berechnung nicht ausreichen (keine Rückkehr)
   }


   // Laufzeit auf Laptop für ALMA(7xD1):
   // -----------------------------------
   // H1 ::ALMA::onTick()   weights(  168)=0.000 sec   buffer(2000)=0.110 sec   loops=   336.000
   // M30::ALMA::onTick()   weights(  336)=0.000 sec   buffer(2000)=0.250 sec   loops=   672.000
   // M15::ALMA::onTick()   weights(  672)=0.000 sec   buffer(2000)=0.453 sec   loops= 1.344.000
   // M5 ::ALMA::onTick()   weights( 2016)=0.016 sec   buffer(2000)=1.547 sec   loops= 4.032.000
   // M1 ::ALMA::onTick()   weights(10080)=0.000 sec   buffer(2000)=7.110 sec   loops=20.160.000 (20 Mill. Durchläufe!!!)
   //
   // Fazit: weights-Berechnung ist vernachlässigbar, Schwachpunkt ist die verschachtelte Schleife in bufferMA-Berechnung


   double curValue, prevValue;


   // (2) ungültige Bars neuberechnen
   for (int bar=startBar; bar >= 0; bar--) {
      // (2.1) der eigentliche Moving Average
      bufferMA[bar] = shift.vertical;
      for (int i=0; i < ma.periods; i++) {
         bufferMA[bar] += alma.weights[i] * iMA(NULL, NULL, 1, 0, MODE_SMA, ma.appliedPrice, bar+i);
      }


      // (2.2) Trend: minimale Reversal-Glättung um 0.1 pip durch Normalisierung
      curValue  = NormalizeDouble(bufferMA[bar  ], SubPipDigits);
      prevValue = NormalizeDouble(bufferMA[bar+1], SubPipDigits);

      if      (curValue > prevValue) bufferTrend[bar] =       Max(bufferTrend[bar+1], 0) + 1;
      else if (curValue < prevValue) bufferTrend[bar] =       Min(bufferTrend[bar+1], 0) - 1;
      else                           bufferTrend[bar] = MathRound(bufferTrend[bar+1] + Sign(bufferTrend[bar+1]));


      // (2.3) Trend coloring
      if (bufferTrend[bar] > 0) {
         bufferUpTrend  [bar] = bufferMA[bar];
         bufferDownTrend[bar] = EMPTY_VALUE;

         if (bufferTrend[bar+1] < 0) bufferUpTrend  [bar+1] = bufferMA[bar+1];
         else                        bufferDownTrend[bar+1] = EMPTY_VALUE;
      }
      else /*(bufferTrend[bar] < 0)*/ {
         bufferUpTrend  [bar] = EMPTY_VALUE;
         bufferDownTrend[bar] = bufferMA[bar];

         if (bufferTrend[bar+1] > 0) {                                  // Wenn vorher Up-Trend...
            bufferDownTrend[bar+1] = bufferMA[bar+1];
            if (Bars > bar+2) /*&&*/ if (bufferTrend[bar+2] < 0) {      // ...und Up-Trend nur eine Bar lang war, ...
               bufferUpTrend[bar+2] = bufferMA[bar+2];
               bufferUpTrend[bar+1] = bufferMA[bar+1];                  // ... dann Down-Trend mit Up-Trend 2 überlagern.
            }
         }
         else {
            bufferUpTrend[bar+1] = EMPTY_VALUE;
         }
      }
   }


   static int      lastTrend;                                           // Trend des vorherigen Ticks
   static double   lastValue;                                           // Value des vorherigen Ticks
   static bool     intrabarTrendChange;                                 // vorläufiger Trendwechsel innerhalb der aktuellen Bar
   static datetime lastBarOpenTime;


   // (3.1) Legende: bei Trendwechsel Farbe aktualisieren
   if (Sign(bufferTrend[0]) != Sign(lastTrend)) {
      ObjectSetText(legendLabel, ObjectDescription(legendLabel), 9, "Arial Fett", ifInt(bufferTrend[0]>0, Color.UpTrend, Color.DownTrend));
      int error = GetLastError();
      if (IsError(error)) /*&&*/ if (error!=ERR_OBJECT_DOES_NOT_EXIST)  // bei offenem Properties-Dialog oder Object::onDrag()
         return(catch("onTick(2)", error));
      if (lastTrend != 0)
         intrabarTrendChange = !intrabarTrendChange;
   }
   if (Time[0] > lastBarOpenTime) /*&&*/ if (Abs(bufferTrend[0])==2)    // onBarOpen vorläufigen Trendwechsel der vorherigen Bar deaktivieren
      intrabarTrendChange = false;


   // (3.2) Legende: bei Wertänderung Wert aktualisieren
   if (curValue!=lastValue || Time[0] > lastBarOpenTime) {
      ObjectSetText(legendLabel,
                    StringConcatenate(iDescription, ifString(intrabarTrendChange, "_i", ""), "    ", NumberToStr(curValue, SubPipPriceFormat)),
                    ObjectGet(legendLabel, OBJPROP_FONTSIZE));
   }
   lastTrend       = bufferTrend[0];
   lastValue       = curValue;
   lastBarOpenTime = Time[0];

   return(last_error);
}


/**
 * Indikator-Styles setzen. Workaround um diverse Terminalbugs (Farb-/Styleänderungen nach Recompile), die erfordern, daß die Styles
 * in der Regel in init(), nach Recompile jedoch in start() gesetzt werden müssen, um korrekt angezeigt zu werden.
 */
void SetIndicatorStyles() {
   SetIndexStyle(MovingAverage.MODE_MA,        DRAW_NONE, EMPTY, EMPTY, CLR_NONE       );
   SetIndexStyle(MovingAverage.MODE_TREND,     DRAW_NONE, EMPTY, EMPTY, CLR_NONE       );
   SetIndexStyle(MovingAverage.MODE_UPTREND,   DRAW_LINE, EMPTY, EMPTY, Color.UpTrend  );
   SetIndexStyle(MovingAverage.MODE_DOWNTREND, DRAW_LINE, EMPTY, EMPTY, Color.DownTrend);
   SetIndexStyle(MovingAverage.MODE_UPTREND2,  DRAW_LINE, EMPTY, EMPTY, Color.UpTrend  );
}


/**
 * String-Repräsentation der Input-Parameter fürs Logging bei Aufruf durch iCustom().
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("init()   inputs: ",

                            "MA.Periods=\"",          MA.Periods                        , "\"; ",
                            "MA.Timeframe=\"",        MA.Timeframe                      , "\"; ",
                            "MA.AppliedPrice=\"",     MA.AppliedPrice                   , "\"; ",

                            "GaussianOffset=",        NumberToStr(GaussianOffset, ".1+"), "; ",
                            "Sigma=",                 NumberToStr(Sigma, ".1+")         , "; ",

                            "Color.UpTrend=",         ColorToStr(Color.UpTrend)         , "; ",
                            "Color.DownTrend=",       ColorToStr(Color.DownTrend)       , "; ",

                            "Max.Values=",            Max.Values                        , "; ",
                            "Shift.Horizontal.Bars=", Shift.Horizontal.Bars             , "; ",
                            "Shift.Vertical.Pips=",   Shift.Vertical.Pips               , "; ")
   );
}
