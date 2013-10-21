/**
 * Multi-Color/Timeframe Jurik Moving Average (adaptiv)
 *
 *
 *
 * @link  http://www.jurikres.com/catalog/ms_ama.htm
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <stdlib.mqh>

//////////////////////////////////////////////////////////////////////////////// Konfiguration ////////////////////////////////////////////////////////////////////////////////

extern string MA.Periods            = "14";                          // für einige Timeframes sind gebrochene Werte zulässig (z.B. 1.5 x D1)
extern string MA.Timeframe          = "current";                     // Timeframe: [M1|M5|M15|...], "" = aktueller Timeframe
extern string MA.AppliedPrice       = "Open | High | Low | Close* | Median | Typical | Weighted";

extern int    PhaseShift            = 0;                             // Phasenverschiebung: -100..+100

extern color  Color.UpTrend         = DodgerBlue;                    // Farbverwaltung hier, damit Code Zugriff hat
extern color  Color.DownTrend       = Orange;

extern int    Max.Values            = 2000;                          // Höchstanzahl darzustellender Werte: -1 = keine Begrenzung
extern int    Shift.Horizontal.Bars = 0;                             // horizontale Shift in Bars
extern int    Shift.Vertical.Pips   = 0;                             // vertikale Shift in Pips

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>

#define MovingAverage.MODE_MA          0        // Buffer-Identifier
#define MovingAverage.MODE_TREND       1
#define MovingAverage.MODE_UPTREND     2        // Bei Unterbrechung eines Down-Trends um nur eine Bar wird dieser Up-Trend durch den sich fortsetzenden Down-Trend
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
double bufferDownTrend[];                       // DownTrend-Linie:   sichtbar (überlagert UpTrend-Linie 1)
double bufferUpTrend2 [];                       // UpTrend-Linie 2:   sichtbar (überlagert DownTrend-Linie)

int    ma.periods;
int    ma.method;
int    ma.appliedPrice;

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

   // (1.4) PhaseShift
   if (PhaseShift < -100)            return(catch("onInit(8)   Invalid input parameter PhaseShift = "+ PhaseShift, ERR_INVALID_INPUT_PARAMVALUE));
   if (PhaseShift > +100)            return(catch("onInit(9)   Invalid input parameter PhaseShift = "+ PhaseShift, ERR_INVALID_INPUT_PARAMVALUE));

   // (1.5) Max.Values
   if (Max.Values < -1)              return(catch("onInit(10)   Invalid input parameter Max.Values = "+ Max.Values, ERR_INVALID_INPUT_PARAMVALUE));

   // (1.6) Colors
   if (Color.UpTrend   == 0xFF000000) Color.UpTrend   = CLR_NONE;    // können vom Terminal falsch gesetzt worden sein
   if (Color.DownTrend == 0xFF000000) Color.DownTrend = CLR_NONE;


   // (2) Chart-Legende erzeugen
   string strTimeframe="", strAppliedPrice="";
   if (MA.Timeframe != "")             strTimeframe    = "x"+ MA.Timeframe;
   if (ma.appliedPrice != PRICE_CLOSE) strAppliedPrice = ", "+ PriceTypeDescription(ma.appliedPrice);
   iDescription = "JMA("+ MA.Periods + strTimeframe + strAppliedPrice +")";
   legendLabel  = CreateLegendLabel(iDescription);
   PushObject(legendLabel);


   // (3.1) Bufferverwaltung
   SetIndexBuffer(MovingAverage.MODE_MA,        bufferMA       );       // vollst. Indikator: unsichtbar (Anzeige im "Data Window"
   SetIndexBuffer(MovingAverage.MODE_TREND,     bufferTrend    );       // Trend: +/-         unsichtbar
   SetIndexBuffer(MovingAverage.MODE_UPTREND,   bufferUpTrend  );       // UpTrend-Linie 1:   sichtbar
   SetIndexBuffer(MovingAverage.MODE_DOWNTREND, bufferDownTrend);       // DownTrend-Linie:   sichtbar
   SetIndexBuffer(MovingAverage.MODE_UPTREND2,  bufferUpTrend2 );       // UpTrend-Linie 2:   sichtbar

   // (3.2) Anzeigeoptionen
   IndicatorShortName(iDescription);                                    // Context Menu
   SetIndexLabel(MovingAverage.MODE_MA,        iDescription);           // Tooltip und "Data Window"
   SetIndexLabel(MovingAverage.MODE_TREND,     NULL);
   SetIndexLabel(MovingAverage.MODE_UPTREND,   NULL);
   SetIndexLabel(MovingAverage.MODE_DOWNTREND, NULL);
   SetIndexLabel(MovingAverage.MODE_UPTREND2,  NULL);
   IndicatorDigits(SubPipDigits);

   // (3.3) Zeichenoptionen
   int startDraw = Max(ma.periods-1, Bars-ifInt(Max.Values < 0, Bars, Max.Values)) + Shift.Horizontal.Bars;
   SetIndexDrawBegin(MovingAverage.MODE_MA,        0        ); SetIndexShift(MovingAverage.MODE_MA,        Shift.Horizontal.Bars);
   SetIndexDrawBegin(MovingAverage.MODE_TREND,     0        ); SetIndexShift(MovingAverage.MODE_TREND,     Shift.Horizontal.Bars);
   SetIndexDrawBegin(MovingAverage.MODE_UPTREND,   startDraw); SetIndexShift(MovingAverage.MODE_UPTREND,   Shift.Horizontal.Bars);
   SetIndexDrawBegin(MovingAverage.MODE_DOWNTREND, startDraw); SetIndexShift(MovingAverage.MODE_DOWNTREND, Shift.Horizontal.Bars);
   SetIndexDrawBegin(MovingAverage.MODE_UPTREND2,  startDraw); SetIndexShift(MovingAverage.MODE_UPTREND2,  Shift.Horizontal.Bars);

   shift.vertical = Shift.Vertical.Pips * Pip;                          // TODO: Digits/Point-Fehler abfangen

   // (3.4) Styles
   SetIndicatorStyles();                                                // Workaround um diverse Terminalbugs (siehe dort)

   return(catch("onInit(11)"));
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

   if (ChangedBars < 2)       // !!! Bug: vorübergehender Workaround bei Realtime-Update,
      return(NO_ERROR);       //          JMA wird jetzt nur bei onBarOpen aktualisiert
   if (ChangedBars == 2)
      ChangedBars = Bars;


   // (1) Startbar der Berechnung ermitteln
   if (ChangedBars > Max.Values) /*&&*/ if (Max.Values >= 0)
      ChangedBars = Max.Values;
   int startBar = Min(ChangedBars-1, Bars-ma.periods);
   if (startBar < 0) {
      if (Indicator.IsSuperContext())
         return(catch("onTick(1)", ERR_HISTORY_INSUFFICIENT));
      SetLastError(ERR_HISTORY_INSUFFICIENT);                           // Signalisieren, falls Bars für Berechnung nicht ausreichen (keine Rückkehr)
   }


   // (2) JMA-Initialisierung
   int    i01, i02, i03, i04, i05, i06, i07, i08, i09, i10, i11, i12, i13, j;
   double d01, d02, d03, d04, d05, d06, d07, d08, d09, d10, d12, d13, d14, d15, d16, d17, d18, d19, d20, d21, d22, d23, d24, d26, d27, d28, d29, d30, d31, d32, d33, d34, d35;
   double jma, curValue, prevValue, price;

   double list127 [127];
   double ring127 [127];
   double ring10  [ 10];
   double prices61[ 61];

   ArrayInitialize(list127, -1000000);
   ArrayInitialize(ring127,        0);
   ArrayInitialize(ring10,         0);
   ArrayInitialize(prices61,       0);

   int i14 = 63;
   int i15 = 64;

   for (int i=i14; i < 127; i++) {
      list127[i] = 1000000;
   }

   double d25 = (ma.periods-1) / 2.0;
   double d11 = PhaseShift/100. + 1.5;
   bool bInit = true;


   // (3) ungültige Bars neuberechnen
   for (int bar=startBar; bar >= 0; bar--) {
      // (3.1) der eigentliche Moving Average
      price = iMA(NULL, NULL, 1, 0, MODE_SMA, ma.appliedPrice, bar);
      if (i11 < 61) {
         prices61[i11] = price;
         i11++;
      }

      if (i11 > 30) {
         d02 = MathLog(MathSqrt(d25));
         d03 = d02;
         d04 = d02/MathLog(2) + 2;
         if (d04 < 0)
            d04 = 0;
         d28 = d04;
         d26 = d28 - 2;
         if (d26 < 0.5)
            d26 = 0.5;

         d24  = MathSqrt(d25) * d28;
         d27  = d24/(d24 + 1);
         d19  = d25*0.9/(d25*0.9 + 2);

         if (bInit) {
            bInit = false;
            i01 = 0;
            i12 = 0;
            d16 = price;
            for (i=0; i < 30; i++) {
               if (NE(prices61[i], prices61[i+1], Digits)) {
                  i01 = 1;
                  i12 = 29;
                  d16 = prices61[0];
                  break;
               }
            }
            d12 = d16;
         }
         else {
            i12 = 0;
         }

         for (i=i12; i >= 0; i--) {
            if (i == 0) d10 = price;
            else        d10 = prices61[30-i];

            d14 = d10 - d12;
            d18 = d10 - d16;
            if (MathAbs(d14) > MathAbs(d18)) d03 = MathAbs(d14);
            else                             d03 = MathAbs(d18);
            d29 = d03;
            d01 = d29 + 0.0000000001;

            if (i05 <= 1) i05 = 127;
            else          i05--;
            if (i06 <= 1) i06 = 10;
            else          i06--;
            if (i10 < 128)
               i10++;

            d06        += d01 - ring10[i06-1];
            ring10[i06-1] = d01;

            if (i10 > 10) d09 = d06/10;
            else          d09 = d06/i10;

            if (i10 > 127) {
               d07            = ring127[i05-1];
               ring127[i05-1] = d09;
               i09 = 64;
               i07 = i09;
               while (i09 > 1) {
                  if (list127[i07-1] < d07) {
                     i09 >>= 1;
                     i07  += i09;
                  }
                  else if (list127[i07-1] > d07) {
                     i09 >>= 1;
                     i07  -= i09;
                  }
                  else {
                     i09 = 1;
                  }
               }
            }
            else {
               ring127[i05-1] = d09;
               if (i14 + i15 > 127) {
                  i15--;
                  i07 = i15;
               }
               else {
                  i14++;
                  i07 = i14;
               }
               if (i14 > 96) i03 = 96;
               else          i03 = i14;
               if (i15 < 32) i04 = 32;
               else          i04 = i15;
            }

            i09 = 64;
            i08 = i09;

            while (i09 > 1) {
               if (list127[i08-1] < d09) {
                  i09 >>= 1;
                  i08  += i09;
               }
               else if (list127[i08-2] > d09) {
                  i09 >>= 1;
                  i08  -= i09;
               }
               else {
                  i09 = 1;
               }
               if (i08 == 127) /*&&*/ if (d09 > list127[126])
                  i08 = 128;
            }

            if (i10 > 127) {
               if (i07 >= i08) {
                  if      (i03+1 > i08 && i04-1 < i08) d08 += d09;
                  else if (i04   > i08 && i04-1 < i07) d08 += list127[i04-2];
               }
               else if (i04 >= i08) {
                  if      (i03+1 < i08 && i03+1 > i07) d08 += list127[i03];
               }
               else if    (i03+2 > i08               ) d08 += d09;
               else if    (i03+1 < i08 && i03+1 > i07) d08 += list127[i03];

               if (i07 > i08) {
                  if      (i04-1 < i07 && i03+1 > i07) d08 -= list127[i07-1];
                  else if (i03   < i07 && i03+1 > i08) d08 -= list127[i03-1];
               }
               else if    (i03+1 > i07 && i04-1 < i07) d08 -= list127[i07-1];
               else if    (i04   > i07 && i04   < i08) d08 -= list127[i04-1];
            }

            if      (i07 > i08) { for (j=i07-1; j >= i08;   j--) list127[j  ] = list127[j-1]; list127[i08-1] = d09; }
            else if (i07 < i08) { for (j=i07+1; j <= i08-1; j++) list127[j-2] = list127[j-1]; list127[i08-2] = d09; }
            else                {                                                             list127[i08-1] = d09; }

            if (i10 <= 127) {
               d08 = 0;
               for (j=i04; j <= i03; j++) {
                  d08 += list127[j-1];
               }
            }
            d21 = d08/(i03 - i04 + 1);

            if (i13 < 31) i13++;
            else          i13 = 31;

            if (i13 <= 30) {
               if (d14 > 0) d12 = d10;
               else         d12 = d10 - d14 * d27;
               if (d18 < 0) d16 = d10;
               else         d16 = d10 - d18 * d27;

               d32 = price;

               if (i13 == 30) {
                  d33 = price;
                  if (d24 > 0)  d05 = MathCeil(d24);
                  else          d05 = 1;
                  if (d24 >= 1) d03 = MathFloor(d24);
                  else          d03 = 1;

                  if (d03 == d05) d22 = 1;
                  else            d22 = (d24-d03) / (d05-d03);

                  if (d03 <= 29) i01 = d03;
                  else           i01 = 29;
                  if (d05 <= 29) i02 = d05;
                  else           i02 = 29;

                  d30 = (price-prices61[i11-i01-1]) * (1-d22)/d03 + (price-prices61[i11-i02-1]) * d22/d05;
               }
            }
            else {
               d02 = MathPow(d29/d21, d26);
               if (d02 > d28)
                  d02 = d28;

               if (d02 < 1) {
                  d03 = 1;
               }
               else {
                  d03 = d02;
                  d04 = d02;
               }
               d20 = d03;
               d23 = MathPow(d27, MathSqrt(d20));

               if (d14 > 0) d12 = d10;
               else         d12 = d10 - d14 * d23;
               if (d18 < 0) d16 = d10;
               else         d16 = d10 - d18 * d23;
            }
         }

         if (i13 > 30) {
            d15  = MathPow(d19, d20);
            d33  = (1-d15) * price + d15 * d33;
            d34  = (price-d33) * (1-d19) + d19 * d34;
            d35  = d11 * d34 + d33;
            d13  = -d15 * 2;
            d17  = d15 * d15;
            d31  = d13 + d17 + 1;
            d30  = (d35-d32) * d31 + d17 * d30;
            d32 += d30;
         }
         jma = d32;
      }
      else {
         jma = EMPTY_VALUE;
      }
      bufferMA[bar] = jma;


      // (3.2) Trend: minimale Reversal-Glättung um 0.1 pip durch Normalisierung
      curValue  = NormalizeDouble(bufferMA[bar  ], SubPipDigits);
      prevValue = NormalizeDouble(bufferMA[bar+1], SubPipDigits);

      if      (curValue > prevValue) bufferTrend[bar] =       Max(bufferTrend[bar+1], 0) + 1;
      else if (curValue < prevValue) bufferTrend[bar] =       Min(bufferTrend[bar+1], 0) - 1;
      else                           bufferTrend[bar] = MathRound(bufferTrend[bar+1] + Sign(bufferTrend[bar+1]));


      // (3.3) Trend coloring
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


   // (4.1) Legende: bei Trendwechsel Farbe aktualisieren
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


   // (4.2) Legende: bei Wertänderung Wert aktualisieren
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

                            "MA.Periods=\"",          MA.Periods                 , "\"; ",
                            "MA.Timeframe=\"",        MA.Timeframe               , "\"; ",
                            "MA.AppliedPrice=\"",     MA.AppliedPrice            , "\"; ",

                            "PhaseShift=",            PhaseShift                 , "; ",

                            "Color.UpTrend=",         ColorToStr(Color.UpTrend)  , "; ",
                            "Color.DownTrend=",       ColorToStr(Color.DownTrend), "; ",

                            "Max.Values=",            Max.Values                 , "; ",
                            "Shift.Horizontal.Bars=", Shift.Horizontal.Bars      , "; ",
                            "Shift.Vertical.Pips=",   Shift.Vertical.Pips        , "; ")
   );
}
