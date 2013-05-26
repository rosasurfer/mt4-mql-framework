/**
 * Multi-Color/Multi-Timeframe Moving Average
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <stdlib.mqh>

//////////////////////////////////////////////////////////////// Externe Parameter ////////////////////////////////////////////////////////////////

extern string MA.Periods       = "200";
extern string MA.Timeframe     = "";                                 // Timeframe: [M1|M5|M15|...], default = aktueller Timeframe
extern string MA.Method        = "SMA | EMA | SMMA | LWMA | ALMA*";
extern string MA.AppliedPrice  = "Open | High | Low | Close* | Median | Typical | Weighted";

extern color  Color.UpTrend    = DodgerBlue;                         // Farbverwaltung hier, damit Code Zugriff hat
extern color  Color.DownTrend  = Orange;

extern int    Shift.Horizontal = 0;                                  // horizontale Shift in Bars
extern int    Shift.Vertical   = 0;                                  // vertikale Shift in Pips
extern int    Max.Values       = 2000;                               // Höchstanzahl darzustellender Werte: -1 = keine Begrenzung

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>

#define MovingAverage.MODE_MA          0                             // Buffer-Identifier
#define MovingAverage.MODE_TREND       1
#define MovingAverage.MODE_UPTREND     2
#define MovingAverage.MODE_DOWNTREND   3
#define MovingAverage.MODE_UPTREND2    4

#property indicator_chart_window

#property indicator_buffers 5

#property indicator_width1  0
#property indicator_width2  0
#property indicator_width3  2
#property indicator_width4  2
#property indicator_width5  2

double bufferMA         [];                                          // vollst. Indikator: unsichtbar (Anzeige im "Data Window")
double bufferTrend      [];                                          // Trend: +/-         unsichtbar
double bufferUpTrend    [];                                          // UpTrend-Linie 1:   sichtbar
double bufferDownTrend  [];                                          // DownTrend-Linie:   sichtbar (überlagert UpTrend 1)
double bufferUpTrend_2  [];                                          // UpTrend-Linie 2:   sichtbar (überlagert DownTrend, macht im DownTrend UpTrends mit Länge 1 sichtbar)

int    ma.periods;
int    ma.method;
int    ma.appliedPrice;
double wALMA[];                                                      // Gewichtungen der einzelnen Bars bei ALMA
double shift.vertical;
string legendLabel, indicatorName;


/**
 * Initialisierung
 *
 * @return int - Fehlerstatus
 */
int onInit() {
   // (1) Validierung
   // MA.Timeframe zuerst, da Gültigkeit von MA.Periods davon abhängt
   MA.Timeframe = StringToUpper(StringTrim(MA.Timeframe));
   if (MA.Timeframe == "") int ma.timeframe = Period();
   else                        ma.timeframe = PeriodToId(MA.Timeframe);
   if (ma.timeframe == -1)             return(catch("onInit(1)   Invalid input parameter MA.Timeframe = \""+ MA.Timeframe +"\"", ERR_INVALID_INPUT_PARAMVALUE));

   // MA.Periods
   string strValue = StringTrim(MA.Periods);
   if (!StringIsNumeric(strValue))     return(catch("onInit(2)   Invalid input parameter MA.Periods = "+ MA.Periods, ERR_INVALID_INPUT_PARAMVALUE));
   double dValue = StrToDouble(strValue);
   if (dValue <= 0)                    return(catch("onInit(3)   Invalid input parameter MA.Periods = "+ MA.Periods, ERR_INVALID_INPUT_PARAMVALUE));
   if (MathModFix(dValue, 0.5) != 0)   return(catch("onInit(4)   Invalid input parameter MA.Periods = "+ MA.Periods, ERR_INVALID_INPUT_PARAMVALUE));
   strValue = NumberToStr(dValue, ".+");
   if (StringEndsWith(strValue, ".5")) {                             // gebrochene Perioden in ganze Bars umrechnen
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
   switch (ma.timeframe) {                                           // Timeframes > H1 auf H1 umrechnen
      case PERIOD_H4: dValue *=   4; ma.timeframe = PERIOD_H1; break;
      case PERIOD_D1: dValue *=  24; ma.timeframe = PERIOD_H1; break;
      case PERIOD_W1: dValue *= 120; ma.timeframe = PERIOD_H1; break;
   }
   ma.periods = MathRound(dValue);
   if (ma.periods < 2)                 return(catch("onInit(6)   Invalid input parameter MA.Periods = "+ MA.Periods, ERR_INVALID_INPUT_PARAMVALUE));
   if (ma.timeframe != Period()) {                                   // angegebenen auf aktuellen Timeframe umrechnen
      double minutes = ma.timeframe * ma.periods;                    // Timeframe * Anzahl Bars = Range in Minuten
      ma.periods = MathRound(minutes/Period());
   }
   MA.Periods = strValue;

   // MA.Method
   string elems[];
   if (Explode(MA.Method, "*", elems, 2) > 1) {
      int size = Explode(elems[0], "|", elems, NULL);
      strValue = elems[size-1];
   }
   else strValue = MA.Method;
   strValue = StringToUpper(StringTrim(strValue));
   if      (strValue==        "SMA"
         || strValue==   "MODE_SMA"
         || strValue==""+ MODE_SMA)  ma.method = MODE_SMA;           // Es werden jeweils kurzer Name, langer Name oder numerische Darstellung akzeptiert.
   else if (strValue==        "EMA"
         || strValue==   "MODE_EMA"
         || strValue==""+ MODE_EMA)  ma.method = MODE_EMA;
   else if (strValue==        "SMMA"
         || strValue==   "MODE_SMMA"
         || strValue==""+ MODE_SMMA) ma.method = MODE_SMMA;
   else if (strValue==        "LWMA"
         || strValue==   "MODE_LWMA"
         || strValue==""+ MODE_LWMA) ma.method = MODE_LWMA;
   else if (strValue==        "ALMA"
         || strValue==   "MODE_ALMA"
         || strValue==""+ MODE_ALMA) ma.method = MODE_ALMA;
   else return(catch("onInit(7)   Invalid input parameter MA.Method = \""+ MA.Method +"\"", ERR_INVALID_INPUT_PARAMVALUE));
   MA.Method = MovingAverageMethodDescription(ma.method);

   // MA.AppliedPrice
   if (Explode(MA.AppliedPrice, "*", elems, 2) > 1) {
      size     = Explode(elems[0], "|", elems, NULL);
      strValue = StringTrim(elems[size-1]);
   }
   else strValue = StringTrim(MA.AppliedPrice);

   if (StringLen(strValue) >= 0) {
      string char = StringToUpper(StringLeft(strValue, 1));
      if      (char == "O") ma.appliedPrice = PRICE_OPEN;
      else if (char == "H") ma.appliedPrice = PRICE_HIGH;
      else if (char == "L") ma.appliedPrice = PRICE_LOW;
      else if (char == "C") ma.appliedPrice = PRICE_CLOSE;
      else if (char == "M") ma.appliedPrice = PRICE_MEDIAN;
      else if (char == "T") ma.appliedPrice = PRICE_TYPICAL;
      else if (char == "W") ma.appliedPrice = PRICE_WEIGHTED;
      else return(catch("onInit(8)   Invalid input parameter MA.AppliedPrice = \""+ MA.AppliedPrice +"\"", ERR_INVALID_INPUT_PARAMVALUE));
   }
   else ma.appliedPrice = PRICE_CLOSE;                               // Default bei fehlendem Parameter
   MA.AppliedPrice = AppliedPriceDescription(ma.appliedPrice);

   // Max.Values
   if (Max.Values < -1)                return(catch("onInit(9)   Invalid input parameter Max.Values = "+ Max.Values, ERR_INVALID_INPUT_PARAMVALUE));


   // (2.1) Bufferverwaltung
   SetIndexBuffer(MovingAverage.MODE_MA,        bufferMA       );    // vollst. Indikator: unsichtbar (Anzeige im "Data Window"
   SetIndexBuffer(MovingAverage.MODE_TREND,     bufferTrend    );    // Trend: +/-         unsichtbar
   SetIndexBuffer(MovingAverage.MODE_UPTREND,   bufferUpTrend  );    // UpTrend-Linie 1:   sichtbar
   SetIndexBuffer(MovingAverage.MODE_DOWNTREND, bufferDownTrend);    // DownTrend-Linie:   sichtbar
   SetIndexBuffer(MovingAverage.MODE_UPTREND2,  bufferUpTrend_2);    // UpTrend-Linie 2:   sichtbar

   // (2.2) Anzeigeoptionen
   string strTimeframe, strAppliedPrice;
   if (MA.Timeframe != "")             strTimeframe    = StringConcatenate("x", MA.Timeframe);
   if (ma.appliedPrice != PRICE_CLOSE) strAppliedPrice = StringConcatenate(" / ", AppliedPriceDescription(ma.appliedPrice));
   indicatorName = StringConcatenate(MA.Method, "(", MA.Periods, strTimeframe, strAppliedPrice, ")");

   IndicatorShortName(indicatorName);
   SetIndexLabel(MovingAverage.MODE_MA,        indicatorName);       // Anzeige im "Data Window"
   SetIndexLabel(MovingAverage.MODE_TREND,     NULL);
   SetIndexLabel(MovingAverage.MODE_UPTREND,   NULL);
   SetIndexLabel(MovingAverage.MODE_DOWNTREND, NULL);
   SetIndexLabel(MovingAverage.MODE_UPTREND2,  NULL);
   IndicatorDigits(SubPipDigits);

   // (2.3) Zeichenoptionen
   int startDraw = Max(ma.periods-1, Bars-ifInt(Max.Values < 0, Bars, Max.Values));
   SetIndexDrawBegin(MovingAverage.MODE_MA,        startDraw);
   SetIndexDrawBegin(MovingAverage.MODE_TREND,     startDraw);
   SetIndexDrawBegin(MovingAverage.MODE_UPTREND,   startDraw);
   SetIndexDrawBegin(MovingAverage.MODE_DOWNTREND, startDraw);
   SetIndexDrawBegin(MovingAverage.MODE_UPTREND2,  startDraw);

   SetIndexShift(MovingAverage.MODE_MA,        Shift.Horizontal);
   SetIndexShift(MovingAverage.MODE_TREND,     Shift.Horizontal);
   SetIndexShift(MovingAverage.MODE_UPTREND,   Shift.Horizontal);
   SetIndexShift(MovingAverage.MODE_DOWNTREND, Shift.Horizontal);
   SetIndexShift(MovingAverage.MODE_UPTREND2,  Shift.Horizontal);

   shift.vertical = Shift.Vertical * Pip;                            // TODO: Digits/Point-Fehler abfangen


   // (2.4) Styles
   SetIndicatorStyles();                                             // Workaround um diverse Terminalbugs (siehe dort)


   // (3) Chart-Legende erzeugen
   legendLabel = CreateLegendLabel(indicatorName);
   PushChartObject(legendLabel);


   // (4) ALMA-Gewichtungen berechnen
   if (ma.method==MODE_ALMA) /*&&*/ if (ma.periods > 1) {            // ma.periods < 2 ist möglich bei Umschalten auf zu großen Timeframe
      ArrayResize(wALMA, ma.periods);
      double wSum, gaussianOffset=0.85, sigma=6.0;
      double m = MathRound(gaussianOffset * (ma.periods-1));
      double s = ma.periods/sigma;
      for (int i=0; i < ma.periods; i++) {
         wALMA[i] = MathExp(-(i-m)*(i-m)/(2*s*s));
         wSum += wALMA[i];
      }
      for (i=0; i < ma.periods; i++) {
         wALMA[i] /= wSum;                                           // Summe aller Bars = 1 (100%)
      }
      ReverseDoubleArray(wALMA);                                     // Reihenfolge umkehren, um in onTick() Zugriff zu beschleunigen
   }

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

   // vor kompletter Neuberechnung alle Buffer zurücksetzen
   if (!ValidBars) {
      ArrayInitialize(bufferMA,        EMPTY_VALUE);
      ArrayInitialize(bufferTrend,               0);
      ArrayInitialize(bufferUpTrend,   EMPTY_VALUE);
      ArrayInitialize(bufferDownTrend, EMPTY_VALUE);
      ArrayInitialize(bufferUpTrend_2, EMPTY_VALUE);
      SetIndicatorStyles();                                             // Workaround um diverse Terminalbugs (siehe dort)
   }

   if (ma.periods < 2)                                                  // Abbruch bei ma.periods < 2 (möglich bei Umschalten auf zu großen Timeframe)
      return(NO_ERROR);


   // (1) Startbar für Neuberechnung ermitteln
   if (ChangedBars > Max.Values) /*&&*/ if (Max.Values >= 0)
      ChangedBars = Max.Values;
   int startBar = Min(ChangedBars-1, Bars-ma.periods);

   if (startBar < 0) {                                                  // Signalisieren, wenn Bars für Berechnung nicht ausreichen.
      if (Indicator.IsSuperContext())
         return(catch("onTick(1)", ERR_HISTORY_INSUFFICIENT));
      SetLastError(ERR_HISTORY_INSUFFICIENT);
   }


   double curValue, prevValue;


   // (2) geänderte Bars berechnen
   for (int i, bar=startBar; bar >= 0; bar--) {
      // (2.1) der eigentliche Moving Average
      if (ma.method != MODE_ALMA) {
         bufferMA[bar] = iMA(NULL, NULL, ma.periods, 0, ma.method, ma.appliedPrice, bar);
      }
      else {
         bufferMA[bar] = 0;                                             // ALMA
         switch (ma.appliedPrice) {                                     // der am häufigsten verwendete Fall (Close) wird zuerst geprüft
            case PRICE_CLOSE: for (i=0; i < ma.periods; i++) bufferMA[bar] += wALMA[i] *                                            Close[bar+i]; break;
            case PRICE_OPEN : for (i=0; i < ma.periods; i++) bufferMA[bar] += wALMA[i] *                                            Open [bar+i]; break;
            case PRICE_HIGH : for (i=0; i < ma.periods; i++) bufferMA[bar] += wALMA[i] *                                            High [bar+i]; break;
            case PRICE_LOW  : for (i=0; i < ma.periods; i++) bufferMA[bar] += wALMA[i] *                                            Low  [bar+i]; break;
            default:          for (i=0; i < ma.periods; i++) bufferMA[bar] += wALMA[i] * iMA(NULL, NULL, 1, 0, MODE_SMA, ma.appliedPrice, bar+i);
         }
      }
      bufferMA[bar] += shift.vertical;


      // (2.2) Trend: minimale Reversal-Glättung um 0.1 pip durch Normalisierung
      curValue  = NormalizeDouble(bufferMA[bar  ], SubPipDigits);
      prevValue = NormalizeDouble(bufferMA[bar+1], SubPipDigits);

      if      (curValue > prevValue) bufferTrend[bar] = MathRound(MathMax(bufferTrend[bar+1], 0) + 1);
      else if (curValue < prevValue) bufferTrend[bar] = MathRound(MathMin(bufferTrend[bar+1], 0) - 1);
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

         if (bufferTrend[bar+1] > 0) {                               // Wenn vorher Up-Trend...
            bufferDownTrend[bar+1] = bufferMA[bar+1];
            if (Bars > bar+2) /*&&*/ if (bufferTrend[bar+2] < 0) {   // ...und Up-Trend nur eine Bar lang war, ...
               bufferUpTrend_2[bar+2] = bufferMA[bar+2];
               bufferUpTrend_2[bar+1] = bufferMA[bar+1];             // ... dann Down-Trend mit Up-Trend 2 überlagern.
            }
         }
         else {
            bufferUpTrend[bar+1] = EMPTY_VALUE;
         }
      }
   }


   static double lastTrend, lastValue;                                     // Trend und Value des letzten Ticks


   // (3.1) Legende aktualisieren: Farbe bei Trendwechsel
   if (Sign(bufferTrend[0]) != Sign(lastTrend)) {
      ObjectSetText(legendLabel, ObjectDescription(legendLabel), 9, "Arial Fett", ifInt(bufferTrend[0]>0, Color.UpTrend, Color.DownTrend));
      int error = GetLastError();
      if (IsError(error)) /*&&*/ if (error!=ERR_OBJECT_DOES_NOT_EXIST)     // bei offenem Properties-Dialog oder Object::onDrag()
         return(catch("onTick(2)", error));
   }
   lastTrend = bufferTrend[0];


   // (3.2) Legende aktualisieren: Wert bei Änderung
   if (NE(curValue, lastValue)) {
      ObjectSetText(legendLabel,
                    StringConcatenate(indicatorName, "    ", NumberToStr(curValue, SubPipPriceFormat)),
                    ObjectGet(legendLabel, OBJPROP_FONTSIZE));
   }
   lastValue = curValue;

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
 * String-Repräsentation der Input-Parameter fürs Logging.
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("init()   inputs: ",

                            "MA.Periods=\"",      MA.Periods                 , "\"; ",
                            "MA.Timeframe=\"",    MA.Timeframe               , "\"; ",
                            "MA.Method=\"",       MA.Method                  , "\"; ",
                            "MA.AppliedPrice=\"", MA.AppliedPrice            , "\"; ",

                            "Color.UpTrend=",     ColorToStr(Color.UpTrend)  , "; ",
                            "Color.DownTrend=",   ColorToStr(Color.DownTrend), "; ",

                            "Shift.Horizontal=",  Shift.Horizontal           , "; ",
                            "Shift.Vertical=",    Shift.Vertical             , "; ",
                            "Max.Values=",        Max.Values                 , "; ")
   );
}
