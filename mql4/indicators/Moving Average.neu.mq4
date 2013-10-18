/**
 * Multi-Color/Timeframe Moving Average
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <stdlib.mqh>

//////////////////////////////////////////////////////////////////////////////// Konfiguration ////////////////////////////////////////////////////////////////////////////////

extern string MA.Periods            = "200";                         // für einige Timeframes sind gebrochene Werte zulässig (z.B. 1.5 x D1)
extern string MA.Timeframe          = "current";                     // Timeframe: [M1|M5|M15|...], "" = aktueller Timeframe
extern string MA.Method             = "ALMA* | SMA | EMA | SMMA | LWMA | TMA";
extern string MA.AppliedPrice       = "Open | High | Low | Close* | Median | Typical | Weighted";

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
#define MovingAverage.MODE_TMASMA      5        //

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

double bufferTmaSma   [];                       // TMA-Hilfsbuffer

int    ma.periods;
int    ma.method;
int    ma.appliedPrice;

double alma.weights[];                          // Gewichtungen der einzelnen Bars eines ALMA

int    tma.sma1.periods;                        // Periode des ersten SMA eines TMA
int    tma.sma1.maxValues;
int    tma.sma2.periods;                        // Periode des zweiten SMA eines TMA

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
         case PERIOD_MN1:            return(catch("onInit(5)   Illegal input parameter MA.Periods = "+ MA.Periods, ERR_INVALID_INPUT_PARAMVALUE));
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
      double minutes = ma.timeframe * ma.periods;                       // Timeframe * Anzahl_Bars = Range_in_Minuten
      ma.periods = MathRound(minutes/Period());
   }
   MA.Periods = strValue;

   // (1.3) MA.Method
   string elems[];
   if (Explode(MA.Method, "*", elems, 2) > 1) {
      int size = Explode(elems[0], "|", elems, NULL);
      strValue = elems[size-1];
   }
   else strValue = MA.Method;
   ma.method = StrToMovAvgMethod(strValue);
   if (ma.method == -1)              return(catch("onInit(7)   Invalid input parameter MA.Method = \""+ MA.Method +"\"", ERR_INVALID_INPUT_PARAMVALUE));
   MA.Method = MovAvgMethodDescription(ma.method);

   // (1.4) MA.AppliedPrice
   if (Explode(MA.AppliedPrice, "*", elems, 2) > 1) {
      size     = Explode(elems[0], "|", elems, NULL);
      strValue = elems[size-1];
   }
   else strValue = MA.AppliedPrice;
   ma.appliedPrice = StrToPriceType(strValue);
   if (ma.appliedPrice==-1 || ma.appliedPrice > PRICE_WEIGHTED)
                                     return(catch("onInit(8)   Invalid input parameter MA.AppliedPrice = \""+ MA.AppliedPrice +"\"", ERR_INVALID_INPUT_PARAMVALUE));
   MA.AppliedPrice = PriceTypeDescription(ma.appliedPrice);

   // (1.5) Max.Values
   if (Max.Values < -1)              return(catch("onInit(9)   Invalid input parameter Max.Values = "+ Max.Values, ERR_INVALID_INPUT_PARAMVALUE));

   // (1.6) Colors
   if (Color.UpTrend   == 0xFF000000) Color.UpTrend   = CLR_NONE;       // können vom Terminal falsch gesetzt worden sein
   if (Color.DownTrend == 0xFF000000) Color.DownTrend = CLR_NONE;


   // (2) Chart-Legende erzeugen
   string strTimeframe="", strAppliedPrice="";
   if (MA.Timeframe != "")             strTimeframe    = "x"+ MA.Timeframe;
   if (ma.appliedPrice != PRICE_CLOSE) strAppliedPrice = ", "+ PriceTypeDescription(ma.appliedPrice);
   iDescription = MA.Method +"("+ MA.Periods + strTimeframe + strAppliedPrice +")";
   legendLabel  = CreateLegendLabel(iDescription);
   PushObject(legendLabel);


   // (3) ggf. ALMA-Gewichtungen berechnen
   if (ma.method==MODE_ALMA) /*&&*/ if (ma.periods > 1) {               // ma.periods < 2 ist möglich bei Umschalten auf zu großen Timeframe
      ArrayResize(alma.weights, ma.periods);
      double wSum, gaussianOffset=0.85, sigma=6.0;
      double m = MathRound(gaussianOffset * (ma.periods-1));
      double s = ma.periods/sigma;
      for (int j, i=0; i < ma.periods; i++) {
         j = ma.periods-1-i;
         alma.weights[j] = MathExp(-(i-m)*(i-m)/(2*s*s));
         wSum           += alma.weights[j];
      }
      for (i=0; i < ma.periods; i++) {
         alma.weights[i] /= wSum;                                       // Summe aller Bars = 1 (100%)
      }
   }


   // (4) ggf. TMA-Subperioden berechnen
   if (ma.method==MODE_TMA) {
      tma.sma1.periods   = ma.periods/2;                                // (int)
      tma.sma1.maxValues = Max.Values + tma.sma1.periods;
      tma.sma2.periods   = ma.periods - tma.sma1.periods;
   }


   // (5.1) Bufferverwaltung
   IndicatorBuffers(6);
   SetIndexBuffer(MovingAverage.MODE_MA,        bufferMA       );       // vollst. Indikator: unsichtbar (Anzeige im "Data Window"
   SetIndexBuffer(MovingAverage.MODE_TREND,     bufferTrend    );       // Trend: +/-         unsichtbar
   SetIndexBuffer(MovingAverage.MODE_UPTREND,   bufferUpTrend  );       // UpTrend-Linie 1:   sichtbar
   SetIndexBuffer(MovingAverage.MODE_DOWNTREND, bufferDownTrend);       // DownTrend-Linie:   sichtbar
   SetIndexBuffer(MovingAverage.MODE_UPTREND2,  bufferUpTrend2 );       // UpTrend-Linie 2:   sichtbar
   SetIndexBuffer(MovingAverage.MODE_TMASMA,    bufferTmaSma   );       // TMA-Hilfsbuffer

   // (5.2) Anzeigeoptionen
   IndicatorShortName(iDescription);                                    // Context Menu
   SetIndexLabel(MovingAverage.MODE_MA,        iDescription);           // Tooltip und "Data Window"
   SetIndexLabel(MovingAverage.MODE_TREND,     NULL);
   SetIndexLabel(MovingAverage.MODE_UPTREND,   NULL);
   SetIndexLabel(MovingAverage.MODE_DOWNTREND, NULL);
   SetIndexLabel(MovingAverage.MODE_UPTREND2,  NULL);
   IndicatorDigits(SubPipDigits);

   // (5.3) Zeichenoptionen
   int startDraw = Max(ma.periods-1, Bars-ifInt(Max.Values < 0, Bars, Max.Values)) + Shift.Horizontal.Bars;
   SetIndexDrawBegin(MovingAverage.MODE_MA,        0        ); SetIndexShift(MovingAverage.MODE_MA,        Shift.Horizontal.Bars);
   SetIndexDrawBegin(MovingAverage.MODE_TREND,     0        ); SetIndexShift(MovingAverage.MODE_TREND,     Shift.Horizontal.Bars);
   SetIndexDrawBegin(MovingAverage.MODE_UPTREND,   startDraw); SetIndexShift(MovingAverage.MODE_UPTREND,   Shift.Horizontal.Bars);
   SetIndexDrawBegin(MovingAverage.MODE_DOWNTREND, startDraw); SetIndexShift(MovingAverage.MODE_DOWNTREND, Shift.Horizontal.Bars);
   SetIndexDrawBegin(MovingAverage.MODE_UPTREND2,  startDraw); SetIndexShift(MovingAverage.MODE_UPTREND2,  Shift.Horizontal.Bars);

   shift.vertical = Shift.Vertical.Pips * Pip;                          // TODO: Digits/Point-Fehler abfangen

   // (5.4) Styles
   SetIndicatorStyles();                                                // Workaround um diverse Terminalbugs (siehe dort)

   return(catch("onInit(10)"));
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
      ArrayInitialize(bufferTmaSma,              0);
      SetIndicatorStyles();                                             // Workaround um diverse Terminalbugs (siehe dort)
   }

   if (ma.periods < 2)                                                  // Abbruch bei ma.periods < 2 (möglich bei Umschalten auf zu großen Timeframe)
      return(NO_ERROR);


   // (1) Startbar der Berechnung ermitteln
   int ma.ChangedBars = ChangedBars;
   if (ma.ChangedBars > Max.Values) /*&&*/ if (Max.Values >= 0)
      ma.ChangedBars = Max.Values;
   int ma.startBar = Min(ma.ChangedBars-1, Bars-ma.periods);
   if (ma.startBar < 0) {
      if (Indicator.IsSuperContext())
         return(catch("onTick(1)", ERR_HISTORY_INSUFFICIENT));
      SetLastError(ERR_HISTORY_INSUFFICIENT);                           // Signalisieren, falls Bars für Berechnung nicht ausreichen (keine Rückkehr)
   }


   double curValue, prevValue;                                          // 2 Schleifen, damit iMAOnArray() nicht bei jedem Durchlauf auf das geänderte
                                                                        // Ausgangsarray mit einer kompletten Neuberechnung des MA's reagiert.

   // (2) ungültige Bars neuberechnen
   if (ma.method == MODE_TMA) {
      // (2.1) TMA: erster SMA
      int sma.ChangedBars = ChangedBars;
      if (sma.ChangedBars > tma.sma1.maxValues) /*&&*/ if (Max.Values >= 0)
         sma.ChangedBars = tma.sma1.maxValues;
      int sma.startBar = Min(sma.ChangedBars-1, Bars-tma.sma1.periods);

      for (int bar=sma.startBar; bar >= 0; bar--) {
         bufferTmaSma[bar] = iMA(NULL, NULL, tma.sma1.periods, 0, MODE_SMA, ma.appliedPrice, bar);
      }
   }
   for (bar=ma.startBar; bar >= 0; bar--) {
      // (2.2) der eigentliche Moving Average
      if (ma.method == MODE_ALMA) {                                     // ALMA
         bufferMA[bar] = 0;
         for (int i=0; i < ma.periods; i++) {
            bufferMA[bar] += alma.weights[i] * iMA(NULL, NULL, 1, 0, MODE_SMA, ma.appliedPrice, bar+i);
         }
      }
      else if (ma.method == MODE_TMA) {                                 // TMA
         bufferMA[bar] = iMAOnArray(bufferTmaSma, WHOLE_ARRAY, tma.sma2.periods, 0, MODE_SMA, bar);
      }
      else {                                                            // alle übrigen MA's
         bufferMA[bar] = iMA(NULL, NULL, ma.periods, 0, ma.method, ma.appliedPrice, bar);
      }
      bufferMA[bar] += shift.vertical;


      // (2.3) Trend: minimale Reversal-Glättung um 0.1 pip durch Normalisierung
      curValue  = NormalizeDouble(bufferMA[bar  ], SubPipDigits);
      prevValue = NormalizeDouble(bufferMA[bar+1], SubPipDigits);

      if      (curValue > prevValue) bufferTrend[bar] =       Max(bufferTrend[bar+1], 0) + 1;
      else if (curValue < prevValue) bufferTrend[bar] =       Min(bufferTrend[bar+1], 0) - 1;
      else                           bufferTrend[bar] = MathRound(bufferTrend[bar+1] + Sign(bufferTrend[bar+1]));


      // (2.4) Trend coloring
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
               bufferUpTrend2[bar+2] = bufferMA[bar+2];
               bufferUpTrend2[bar+1] = bufferMA[bar+1];                 // ... dann Down-Trend mit Up-Trend 2 überlagern.
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


   // (3.1) Legende: Farbe bei Trendwechsel aktualisieren
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


   // (3.2) Legende: Wert bei Änderung aktualisieren
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
 * normalerweise in init(), nach Recompile jedoch in start() gesetzt werden müssen, um korrekt angezeigt zu werden.
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

                            "MA.Periods=\"",          MA.Periods                 , "\"; ",
                            "MA.Timeframe=\"",        MA.Timeframe               , "\"; ",
                            "MA.Method=\"",           MA.Method                  , "\"; ",
                            "MA.AppliedPrice=\"",     MA.AppliedPrice            , "\"; ",

                            "Color.UpTrend=",         ColorToStr(Color.UpTrend)  , "; ",
                            "Color.DownTrend=",       ColorToStr(Color.DownTrend), "; ",

                            "Max.Values=",            Max.Values                 , "; ",
                            "Shift.Horizontal.Bars=", Shift.Horizontal.Bars      , "; ",
                            "Shift.Vertical.Pips=",   Shift.Vertical.Pips        , "; ")
   );
}
