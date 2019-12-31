/**
 * JMA - Adaptive multi-color Jurik Moving Average
 *
 *
 * @see  http://www.jurikres.com/catalog1/ms_ama.htm
 *
 */
#include <stddefines.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern int    MA.Periods      = 14;
extern string MA.AppliedPrice = "Open | High | Low | Close* | Median | Typical | Weighted";

extern int    Phase           = 0;                                   // -100..+100

extern color  Color.UpTrend   = Orange;  //DodgerBlue;                          // Farbverwaltung hier, damit Code Zugriff hat
extern color  Color.DownTrend = Orange; //Orange;

extern int    Max.Values      = 5000;                                // max. amount of values to calculate (-1: all)

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <rsfLibs.mqh>
#include <functions/@Trend.mqh>

#define MODE_MA               MovingAverage.MODE_MA                  // Buffer-ID's
#define MODE_TREND            MovingAverage.MODE_TREND               //
#define MODE_UPTREND1         2                                      // Bei Unterbrechung eines Down-Trends um nur eine Bar wird dieser Up-Trend durch den sich fortsetzenden
#define MODE_DOWNTREND        3                                      // Down-Trend optisch verdeckt. Um auch solche kurzen Trendwechsel sichtbar zu machen, werden sie zusätzlich
#define MODE_UPTREND2         4                                      // im Buffer MODE_UPTREND2 gespeichert, der im Chart den Buffer MODE_DOWNTREND optisch überlagert.

#property indicator_chart_window
#property indicator_buffers   5

#property indicator_width1    0
#property indicator_width2    0
#property indicator_width3    2
#property indicator_width4    2
#property indicator_width5    2
int       indicator_drawingType = DRAW_LINE;

double bufferJMA      [];                       // vollst. Indikator: unsichtbar (Anzeige im Data window)
double bufferTrend    [];                       // Trend: +/-         unsichtbar
double bufferUpTrend1 [];                       // UpTrend-Linie 1:   sichtbar
double bufferDownTrend[];                       // DownTrend-Linie:   sichtbar (überlagert UpTrend-Linie 1)
double bufferUpTrend2 [];                       // UpTrend-Linie 2:   sichtbar (überlagert DownTrend-Linie)

int    ma.periods;
int    ma.method;
int    ma.appliedPrice;

string legendLabel, legendName;


/**
 * Initialisierung
 *
 * @return int - Fehlerstatus
 */
int onInit() {
   // (1) Validierung
   // MA.Periods
   if (MA.Periods < 2)                                          return(catch("onInit(6)  Invalid input parameter MA.Periods = "+ MA.Periods, ERR_INVALID_INPUT_PARAMETER));
   ma.periods = MA.Periods;

   // MA.AppliedPrice
   string values[], sValue = StrToLower(MA.AppliedPrice);
   if (Explode(sValue, "*", values, 2) > 1) {
      int size = Explode(values[0], "|", values, NULL);
      sValue = values[size-1];
   }
   sValue = StrTrim(sValue);
   if (sValue == "") sValue = "close";                               // default price type
   ma.appliedPrice = StrToPriceType(sValue, F_ERR_INVALID_PARAMETER);
   if (IsEmpty(ma.appliedPrice)) {
      if      (StrStartsWith("open",     sValue)) ma.appliedPrice = PRICE_OPEN;
      else if (StrStartsWith("high",     sValue)) ma.appliedPrice = PRICE_HIGH;
      else if (StrStartsWith("low",      sValue)) ma.appliedPrice = PRICE_LOW;
      else if (StrStartsWith("close",    sValue)) ma.appliedPrice = PRICE_CLOSE;
      else if (StrStartsWith("median",   sValue)) ma.appliedPrice = PRICE_MEDIAN;
      else if (StrStartsWith("typical",  sValue)) ma.appliedPrice = PRICE_TYPICAL;
      else if (StrStartsWith("weighted", sValue)) ma.appliedPrice = PRICE_WEIGHTED;
      else                                                      return(catch("onInit(7)  Invalid input parameter MA.AppliedPrice = "+ DoubleQuoteStr(MA.AppliedPrice), ERR_INVALID_INPUT_PARAMETER));
   }
   MA.AppliedPrice = PriceTypeDescription(ma.appliedPrice);

   // Phase
   if (Phase < -100)                                            return(catch("onInit(8)  Invalid input parameter Phase = "+ Phase, ERR_INVALID_INPUT_PARAMETER));
   if (Phase > +100)                                            return(catch("onInit(9)  Invalid input parameter Phase = "+ Phase, ERR_INVALID_INPUT_PARAMETER));

   // Max.Values
   if (Max.Values < -1)                                         return(catch("onInit(10)  Invalid input parameter Max.Values = "+ Max.Values, ERR_INVALID_INPUT_PARAMETER));

   // Colors
   if (Color.UpTrend   == 0xFF000000) Color.UpTrend   = CLR_NONE;    // aus CLR_NONE = 0xFFFFFFFF macht das Terminal nach Recompilation oder Deserialisierung
   if (Color.DownTrend == 0xFF000000) Color.DownTrend = CLR_NONE;    // u.U. 0xFF000000 (entspricht Schwarz)


   // (2) Chart-Legende erzeugen
   string strAppliedPrice = "";
   if (ma.appliedPrice != PRICE_CLOSE) strAppliedPrice = ", "+ PriceTypeDescription(ma.appliedPrice);
   legendName  = "JMA.spiggy("+ MA.Periods + strAppliedPrice +")";
   if (!IsSuperContext()) {
       legendLabel = CreateLegendLabel(legendName);
       ObjectRegister(legendLabel);
   }


   // (3.1) Bufferverwaltung
   SetIndexBuffer(MODE_MA,        bufferJMA      );                     // vollst. Indikator: unsichtbar (Anzeige im Data window)
   SetIndexBuffer(MODE_TREND,     bufferTrend    );                     // Trend: +/-         unsichtbar
   SetIndexBuffer(MODE_UPTREND1,  bufferUpTrend1 );                     // UpTrend-Linie 1:   sichtbar
   SetIndexBuffer(MODE_DOWNTREND, bufferDownTrend);                     // DownTrend-Linie:   sichtbar
   SetIndexBuffer(MODE_UPTREND2,  bufferUpTrend2 );                     // UpTrend-Linie 2:   sichtbar

   // (3.2) Anzeigeoptionen
   IndicatorShortName(legendName);                                      // Context Menu
   string dataName  = "JMA("+ MA.Periods +")";
   SetIndexLabel(MODE_MA,        dataName);                             // Tooltip und Data window
   SetIndexLabel(MODE_TREND,     NULL);
   SetIndexLabel(MODE_UPTREND1,  NULL);
   SetIndexLabel(MODE_DOWNTREND, NULL);
   SetIndexLabel(MODE_UPTREND2,  NULL);
   IndicatorDigits(SubPipDigits);

   // (3.3) Zeichenoptionen
   int startDraw = 0;
   if (Max.Values >= 0) startDraw = Bars - Max.Values;
   if (startDraw  <  0) startDraw = 0;
   SetIndexDrawBegin(MODE_UPTREND1,  startDraw);
   SetIndexDrawBegin(MODE_DOWNTREND, startDraw);
   SetIndexDrawBegin(MODE_UPTREND2,  startDraw);
   SetIndicatorOptions();

   return(catch("onInit(11)"));
}


/**
 * Deinitialisierung
 *
 * @return int - Fehlerstatus
 */
int onDeinit() {
   DeleteRegisteredObjects(NULL);
   RepositionLegend();
   return(catch("onDeinit(1)"));
}


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onTick() {
   // Abschluß der Buffer-Initialisierung überprüfen
   if (!ArraySize(bufferJMA))
      return(log("onTick(1)  size(bufferJMA) = 0", SetLastError(ERS_TERMINAL_NOT_YET_READY)));

   // reset all buffers and delete garbage behind Max.Values before doing a full recalculation
   if (!UnchangedBars) {
      ArrayInitialize(bufferJMA,       EMPTY_VALUE);
      ArrayInitialize(bufferTrend,               0);
      ArrayInitialize(bufferUpTrend1,  EMPTY_VALUE);
      ArrayInitialize(bufferDownTrend, EMPTY_VALUE);
      ArrayInitialize(bufferUpTrend2,  EMPTY_VALUE);
      SetIndicatorOptions();
   }


   // (1) synchronize buffers with a shifted offline chart
   if (ShiftedBars > 0) {
      ShiftIndicatorBuffer(bufferJMA,       Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(bufferTrend,     Bars, ShiftedBars,           0);
      ShiftIndicatorBuffer(bufferUpTrend1,  Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(bufferDownTrend, Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(bufferUpTrend2,  Bars, ShiftedBars, EMPTY_VALUE);
   }


   if (ma.periods < 2)                                                  // Abbruch bei ma.periods < 2 (möglich bei Umschalten auf zu großen Timeframe)
      return(NO_ERROR);

   if (ChangedBars < 2)       // !!! Bug: vorübergehender Workaround bei Realtime-Update,
      return(NO_ERROR);       //          JMA wird jetzt nur bei onBarOpen aktualisiert
   if (ChangedBars == 2)
      ChangedBars = Bars;


   // (2) Startbar der Berechnung ermitteln
   if (ChangedBars > Max.Values) /*&&*/ if (Max.Values >= 0)
      ChangedBars = Max.Values;
   int startBar = Min(ChangedBars-1, Bars-ma.periods);
   if (startBar < 0) return(catch("onTick(2)", ERR_HISTORY_INSUFFICIENT));


   // (3) JMA-Initialisierung
   int    i01, i02, i03, i04, i05, i06, i07, i08, i09, i10, iLoopParam, iHighLimit, iLoopCriteria;
   double d02, d03, d04, d05, d06, d07, d08, dHighValue, dSValue, dParamA, dParamB, d13, d14, d15, d17, d18, dLengthDivider, d20, d21, d22, d24, d26, dSqrtDivider, d28, dAbsValue, d30, d31, d32, d33, d34;
   double dJMA, dPrice;

   double dList127 [127];
   double dRing127 [127];
   double dRing10  [ 10];
   double dPrices61[ 61];

   ArrayInitialize(dList127, -1000000);
   ArrayInitialize(dRing127,        0);
   ArrayInitialize(dRing10,         0);
   ArrayInitialize(dPrices61,       0);

   int iLimitValue = 63;
   int iStartValue = 64;

   for (int i=iLimitValue; i < 127; i++) {
      dList127[i] = 1000000;
   }

   double dLengthParam = (ma.periods-1) / 2.;
   double dPhaseParam  = Phase/100. + 1.5;
   bool   bInitFlag    = true;


   // (4) ungültige Bars neuberechnen

   // main cycle
   for (int bar=startBar; bar >= 0; bar--) {
      dPrice = iMA(NULL, NULL, 1, 0, MODE_SMA, ma.appliedPrice, bar);

      if (iLoopParam < 61) {
         dPrices61[iLoopParam] = dPrice;
         iLoopParam++;
      }

      if (iLoopParam > 30) {
         d02 = MathLog(MathSqrt(dLengthParam));
         d03 = d02;
         d04 = d02/MathLog(2) + 2;
         if (d04 < 0)
            d04 = 0;
         d28 = d04;
         d26 = d28 - 2;
         if (d26 < 0.5)
            d26 = 0.5;

         d24            = MathSqrt(dLengthParam) * d28;
         dSqrtDivider   = d24/(d24 + 1);
         dLengthDivider = dLengthParam*0.9 / (dLengthParam*0.9 + 2);

         if (bInitFlag) {
            bInitFlag = false;
            i01        = 0;
            iHighLimit = 0;
            dParamB = dPrice;
            for (i=0; i < 30; i++) {
               if (!EQ(dPrices61[i], dPrices61[i+1], Digits)) {
                  i01        = 1;
                  iHighLimit = 29;
                  dParamB = dPrices61[0];
                  break;
               }
            }
            dParamA = dParamB;
         }
         else {
            iHighLimit = 0;
         }

         // big cycle
         for (i=iHighLimit; i >= 0; i--) {
            if (i == 0) dSValue = dPrice;
            else        dSValue = dPrices61[30-i];

            d14 = dSValue - dParamA;
            d18 = dSValue - dParamB;
            if (MathAbs(d14) > MathAbs(d18)) d03 = MathAbs(d14);
            else                             d03 = MathAbs(d18);
            dAbsValue     = d03;
            double dValue = dAbsValue + 0.0000000001;

            if (i05 <= 1) i05 = 127;
            else          i05--;
            if (i06 <= 1) i06 = 10;
            else          i06--;
            if (i10 < 128)
               i10++;

            d06           += dValue - dRing10[i06-1];
            dRing10[i06-1] = dValue;

            if (i10 > 10) dHighValue = d06/10;
            else          dHighValue = d06/i10;

            if (i10 > 127) {
               d07             = dRing127[i05-1];
               dRing127[i05-1] = dHighValue;
               i09 = 64;
               i07 = i09;
               while (i09 > 1) {
                  if (dList127[i07-1] < d07) {
                     i09 >>= 1;
                     i07  += i09;
                  }
                  else if (dList127[i07-1] > d07) {
                     i09 >>= 1;
                     i07  -= i09;
                  }
                  else {
                     i09 = 1;
                  }
               }
            }
            else {
               dRing127[i05-1] = dHighValue;
               if (iLimitValue + iStartValue > 127) {
                  iStartValue--;
                  i07 = iStartValue;
               }
               else {
                  iLimitValue++;
                  i07 = iLimitValue;
               }
               if (iLimitValue > 96) i03 = 96;
               else                  i03 = iLimitValue;
               if (iStartValue < 32) i04 = 32;
               else                  i04 = iStartValue;
            }

            i09 = 64;
            i08 = i09;

            while (i09 > 1) {
               if (dList127[i08-1] < dHighValue) {
                  i09 >>= 1;
                  i08  += i09;
               }
               else if (dList127[i08-2] > dHighValue) {
                  i09 >>= 1;
                  i08  -= i09;
               }
               else {
                  i09 = 1;
               }
               if (i08==127 && dHighValue > dList127[126])
                  i08 = 128;
            }

            if (i10 > 127) {
               if (i07 >= i08) {
                  if      (i03+1 > i08 && i04-1 < i08) d08 += dHighValue;
                  else if (i04   > i08 && i04-1 < i07) d08 += dList127[i04-2];
               }
               else if (i04 >= i08) {
                  if      (i03+1 < i08 && i03+1 > i07) d08 += dList127[i03];
               }
               else if    (i03+2 > i08               ) d08 += dHighValue;
               else if    (i03+1 < i08 && i03+1 > i07) d08 += dList127[i03];

               if (i07 > i08) {
                  if      (i04-1 < i07 && i03+1 > i07) d08 -= dList127[i07-1];
                  else if (i03   < i07 && i03+1 > i08) d08 -= dList127[i03-1];
               }
               else if    (i03+1 > i07 && i04-1 < i07) d08 -= dList127[i07-1];
               else if    (i04   > i07 && i04   < i08) d08 -= dList127[i04-1];
            }

            if      (i07 > i08) { for (int j=i07-1; j >= i08;   j--) dList127[j  ] = dList127[j-1]; dList127[i08-1] = dHighValue; }
            else if (i07 < i08) { for (    j=i07+1; j <= i08-1; j++) dList127[j-2] = dList127[j-1]; dList127[i08-2] = dHighValue; }
            else                {                                                                   dList127[i08-1] = dHighValue; }

            if (i10 <= 127) {
               d08 = 0;
               for (j=i04; j <= i03; j++) {
                  d08 += dList127[j-1];
               }
            }
            d21 = d08/(i03 - i04 + 1);

            iLoopCriteria++;
            if (iLoopCriteria > 31) iLoopCriteria = 31;

            if (iLoopCriteria <= 30) {
               if (d14 > 0) dParamA = dSValue;
               else         dParamA = dSValue - d14 * dSqrtDivider;
               if (d18 < 0) dParamB = dSValue;
               else         dParamB = dSValue - d18 * dSqrtDivider;

               d32 = dPrice;

               if (iLoopCriteria == 30) {
                  d33 = dPrice;
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

                  d30 = (dPrice-dPrices61[iLoopParam-i01-1]) * (1-d22)/d03 + (dPrice-dPrices61[iLoopParam-i02-1]) * d22/d05;
               }
            }
            else {
               d02 = MathPow(dAbsValue/d21, d26);
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
               double dPowerValue1 = MathPow(dSqrtDivider, MathSqrt(d20));

               if (d14 > 0) dParamA = dSValue;
               else         dParamA = dSValue - d14 * dPowerValue1;
               if (d18 < 0) dParamB = dSValue;
               else         dParamB = dSValue - d18 * dPowerValue1;
            }
         }

         if (iLoopCriteria > 30) {
            d15  = MathPow(dLengthDivider, d20);
            d33  = (1-d15) * dPrice + d15 * d33;
            d34  = (dPrice-d33) * (1-dLengthDivider) + dLengthDivider * d34;
            d13  = -d15 * 2;
            d17  = d15 * d15;
            d31  = d13 + d17 + 1;
            d30  = (dPhaseParam * d34 + d33 - d32) * d31 + d17 * d30;
            d32 += d30;
         }
         dJMA = d32;
      }
      else {
         dJMA = EMPTY_VALUE;
      }
      bufferJMA[bar] = dJMA;

      // Trend aktualisieren
      @Trend.UpdateDirection(bufferJMA, bar, bufferTrend, bufferUpTrend1, bufferDownTrend, bufferUpTrend2, indicator_drawingType, true, true, SubPipDigits);
   }


   // (5) Legende aktualisieren
   if (!IsSuperContext()) {
      @Trend.UpdateLegend(legendLabel, legendName, "", Color.UpTrend, Color.DownTrend, bufferJMA[0], SubPipDigits+1, bufferTrend[0], Time[0]);
   }
   return(last_error);
}


/**
 * Workaround for various terminal bugs when setting indicator options. Usually options are set in init(). However after
 * recompilation options must be set in start() to not get ignored.
 */
void SetIndicatorOptions() {
   SetIndexStyle(MODE_MA,        DRAW_NONE,             EMPTY, EMPTY, CLR_NONE       );
   SetIndexStyle(MODE_TREND,     DRAW_NONE,             EMPTY, EMPTY, CLR_NONE       );
   SetIndexStyle(MODE_UPTREND1,  indicator_drawingType, EMPTY, EMPTY, Color.UpTrend  );
   SetIndexStyle(MODE_DOWNTREND, indicator_drawingType, EMPTY, EMPTY, Color.DownTrend);
   SetIndexStyle(MODE_UPTREND2,  indicator_drawingType, EMPTY, EMPTY, Color.UpTrend  );
}


/**
 * Return a string representation of the input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("MA.Periods=",      DoubleQuoteStr(MA.Periods),      ";", NL,
                            "MA.AppliedPrice=", DoubleQuoteStr(MA.AppliedPrice), ";", NL,

                            "Phase=",           Phase,                           ";", NL,

                            "Color.UpTrend=",   ColorToStr(Color.UpTrend),       ";", NL,
                            "Color.DownTrend=", ColorToStr(Color.DownTrend),     ";", NL,

                            "Max.Values=",      Max.Values,                      ";")
   );
}
