/**
 * JMA - Adaptive Jurik Moving Average
 *
 *
 * The source of this indicator is the MQL4 port of the 1998's TradeStation version authored by "Weld, Jurik Research" (see
 * first two links below) which has some bugs and repaints, caused by a faulty code conversion from EasyLanguage to MQL4.
 * This indicator is a rewritten, fixed and optimized version.
 *
 * Indicator buffers for iCustom():
 *  • MovingAverage.MODE_MA:    MA values
 *  • MovingAverage.MODE_TREND: trend direction and length
 *    - trend direction:        positive values denote an uptrend (+1...+n), negative values a downtrend (-1...-n)
 *    - trend length:           the absolute direction value is the length of the trend in bars since the last reversal
 *
 * @source  http://web.archive.org/web/20150929062448/http://www.forex-tsd.com/digital-filters/198-jurik.html
 * @source  https://www.mql5.com/en/forum/173010
 * @see     http://www.jurikres.com/catalog1/ms_ama.htm
 * @see     "/etc/doc/jurik/Jurik Research Product Guide [2015.09].pdf"
 */
#include <stddefines.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern int Length = 14;
extern int Phase  = 0;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <rsfLibs.mqh>
#include <functions/@Trend.mqh>

#property indicator_chart_window
#property indicator_buffers   1

#property indicator_color1    Magenta
#property indicator_width1    2


// indicator buffers
double jmaBuffer[];
double iBuffer1 [];
double iBuffer2 [];
double iBuffer3 [];

// arrays
double dList128[128], dRing128[128], dRing11[11], dPrices62[62];

bool   bInitFlag;
int    iLimitValue, iStartValue, iLoopParam, iLoopCriteria;
int    iCycleLimit, iHighLimit, iCounterA, iCounterB;
double dCycleDelta, dLowValue, dHighValue, dAbsValue, dParamA, dParamB;
double dPhaseParam, dLogParam, dSqrtParam, dLengthDivider, dPrice, dSValue, dJMA, dJMATemp;

// temporary vars
int i3, iS4, iS5;

string indicatorName;
string chartLegendLabel;


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   double dLengthParam;
   // 3 additional buffers are used for counting
   IndicatorBuffers(4);

   // drawing settings
   SetIndexStyle(0, DRAW_LINE);
   SetIndexDrawBegin(0, 30);

   // 4 indicator buffers mapping
   SetIndexBuffer(0, jmaBuffer);
   SetIndexBuffer(1, iBuffer1);
   SetIndexBuffer(2, iBuffer2);
   SetIndexBuffer(3, iBuffer3);

   // name for DataWindow and indicator subwindow label
   IndicatorShortName("JMA("+ Length +", "+ Phase +")");
   SetIndexLabel(0, "JMA");

   // initial part
   iLimitValue = 63;
   iStartValue = 64;

   for (int i=0; i <= iLimitValue; i++) dList128[i] = -1000000;
   for (i=iStartValue; i <= 127; i++)   dList128[i] = +1000000;

   bInitFlag = true;
   if (Length < 1.0000000002) dLengthParam = 0.0000000001;
   else                       dLengthParam = (Length-1) / 2.;

   if      (Phase < -100) dPhaseParam = 0.5;
   else if (Phase > +100) dPhaseParam = 2.5;
   else                   dPhaseParam = Phase/100. + 1.5;

   dLogParam = MathLog(MathSqrt(dLengthParam)) / MathLog(2);
   if (dLogParam+2 < 0) dLogParam = 0;
   else                 dLogParam = dLogParam + 2;

   dSqrtParam     = MathSqrt(dLengthParam) * dLogParam;
   dLengthParam   = dLengthParam * 0.9;
   dLengthDivider = dLengthParam / (dLengthParam+2);


   // chart legend
   indicatorName = "JMA.weld("+ Length +")";
   if (!IsSuperContext()) {
      chartLegendLabel = CreateLegendLabel(indicatorName);
      ObjectRegister(chartLegendLabel);
   }
   return(catch("onInit(1)"));
}


/**
 * Deinitialization
 *
 * @return int - error status
 */
int onDeinit() {
   DeleteRegisteredObjects(NULL);
   RepositionLegend();
   return(catch("onDeinit(1)"));
}


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   // get already counted bars
   int counted_bars = IndicatorCounted();
   // check for possible errors
   if (counted_bars < 0) return(catch("onTick(1)"));
   int limit = Bars - counted_bars - 1;


   // main cycle
   for (int shift=limit; shift >= 0; shift--) {
      dPrice = Close[shift];

      if (iLoopParam < 61) {
         iLoopParam++;
         dPrices62[iLoopParam] = dPrice;
      }

      int i3;

      if (iLoopParam > 30) {
         if (bInitFlag) {
            bInitFlag = false;

            int iDiffFlag = 0;
            for (int i=1; i <= 29; i++) {
               if (dPrices62[i+1] != dPrices62[i]) iDiffFlag = 1;    // double comparison error
            }
            iHighLimit = iDiffFlag * 30;

            if (iHighLimit == 0) dParamB = dPrice;
            else                 dParamB = dPrices62[1];

            dParamA = dParamB;
            if (iHighLimit > 29) iHighLimit = 29;
         }
         else iHighLimit = 0;

         // big cycle
         for (i=iHighLimit; i >= 0; i--) {
            if (i == 0) dSValue = dPrice;
            else        dSValue = dPrices62[31-i];

            if (MathAbs(dSValue-dParamA) > MathAbs(dSValue-dParamB)) dAbsValue = MathAbs(dSValue-dParamA);
            else                                                     dAbsValue = MathAbs(dSValue-dParamB);
            double dValue = dAbsValue + 0.0000000001;                // 1.0e-10;

            if (iCounterA <= 1) iCounterA = 127;
            else                iCounterA--;
            if (iCounterB <= 1) iCounterB = 10;
            else                iCounterB--;

            if (iCycleLimit < 128) iCycleLimit++;

            dCycleDelta       += (dValue - dRing11[iCounterB]);
            dRing11[iCounterB] = dValue;

            if (iCycleLimit > 10) dHighValue = dCycleDelta / 10;
            else                  dHighValue = dCycleDelta / iCycleLimit;

            int i1 = 0;

            if (iCycleLimit > 127) {
               dValue            = dRing128[iCounterA];
               dRing128[iCounterA] = dHighValue;
               iS5 = 64;
               i1  = iS5;

               while (iS5 > 1) {
                  if (dList128[i1] < dValue) {
                     iS5 >>= 1;
                     i1 += iS5;
                  }
                  else if (dList128[i1] <= dValue) {
                     iS5 = 1;
                  }
                  else {
                     iS5 >>= 1;
                     i1 -= iS5;
                  }
               }
            }
            else {
               dRing128[iCounterA] = dHighValue;
               if (iLimitValue + iStartValue > 127) {
                  iStartValue--;
                  i1 = iStartValue;
               }
               else {
                  iLimitValue++;
                  i1 = iLimitValue;
               }
               if (iLimitValue > 96) iS4 = 96;
               else                  iS4 = iLimitValue;
               if (iStartValue < 32) i3  = 32;
               else                  i3  = iStartValue;
            }

            iS5    = 64;
            int i2 = iS5;

            while (iS5 > 1) {
               if (dList128[i2] >= dHighValue) {
                  if (dList128[i2-1] <= dHighValue) {
                     iS5 = 1;
                  }
                  else {
                     iS5 >>= 1;
                     i2 -= iS5;
                  }
               }
               else {
                  iS5 >>= 1;
                  i2 += iS5;
               }
               if (i2==127 && dHighValue > dList128[127]) i2 = 128;
            }

            if (iCycleLimit > 127) {
               if (i1 >= i2) {
                  if      (iS4+1 > i2 && i3-1 < i2) dLowValue += dHighValue;
                  else if (i3    > i2 && i3-1 < i1) dLowValue += dList128[i3-1];
               }
               else if (i3 >= i2) {
                  if (iS4+1 < i2 && iS4+1 > i1)     dLowValue += dList128[iS4+1];
               }
               else if (iS4+2 > i2)                 dLowValue += dHighValue;
               else if (iS4+1 < i2 && iS4+1 > i1)   dLowValue += dList128[iS4+1];

               if (i1 > i2) {
                  if      (i3-1 < i1 && iS4+1 > i1) dLowValue -= dList128[i1];
                  else if (iS4  < i1 && iS4+1 > i2) dLowValue -= dList128[iS4];
               }
               else {
                  if      (iS4+1 > i1 && i3-1 < i1) dLowValue -= dList128[i1];
                  else if (i3    > i1 && i3   < i2) dLowValue -= dList128[i3];
               }
            }

            if (i1 <= i2) {
               if (i1 >= i2) {
                  dList128[i2] = dHighValue;
               }
               else {
                  for (int j=i1+1; j <= i2-1; j++) {
                     dList128[j-1] = dList128[j];
                  }
                  dList128[i2-1] = dHighValue;
               }
            }
            else {
               for (j=i1-1; j >= i2; j--) {
                  dList128[j+1] = dList128[j];
               }
               dList128[i2] = dHighValue;
            }

            if (iCycleLimit <= 127) {
               dLowValue = 0;
               for (j=i3; j <= iS4; j++) {
                  dLowValue += dList128[j];
               }
            }

            iLoopCriteria++;
            if (iLoopCriteria > 31) iLoopCriteria = 31;

            double dSqrtDivider = dSqrtParam / (dSqrtParam+1);

            if (iLoopCriteria <= 30) {
               if (dSValue-dParamA > 0) dParamA = dSValue;
               else                     dParamA = dSValue - (dSValue-dParamA) * dSqrtDivider;
               if (dSValue-dParamB < 0) dParamB = dSValue;
               else                     dParamB = dSValue - (dSValue-dParamB) * dSqrtDivider;

               dJMATemp = dPrice;

               if (iLoopCriteria == 30) {
                 iBuffer1[shift] = dPrice;

                 int iLeftInt=1, iRightPart=1;
                 if (dSqrtParam >  0) iLeftInt   = dSqrtParam + 1;
                 if (dSqrtParam >= 1) iRightPart = dSqrtParam;

                 dValue = MathDiv(dSqrtParam-iRightPart, iLeftInt-iRightPart, 1);

                 int iUpShift=29, iDnShift=29;
                 if (iRightPart <= 29) iUpShift = iRightPart;
                 if (iLeftInt <= 29)   iDnShift = iLeftInt;

                 iBuffer3[shift] = (dPrice-dPrices62[iLoopParam-iUpShift]) * (1-dValue) / iRightPart + (dPrice-dPrices62[iLoopParam-iDnShift]) * dValue / iLeftInt;
               }
            }
            else {
               double dPowerValue, dSquareValue;

               dValue = dLowValue / (iS4 - i3 + 1);
               if (0.5 <= dLogParam-2.0) dPowerValue = dLogParam - 2.0;
               else                      dPowerValue = 0.5;

               if (dLogParam >= MathPow(dAbsValue/dValue, dPowerValue)) dValue = MathPow(dAbsValue/dValue, dPowerValue);
               else                                                     dValue = dLogParam;
               if (dValue < 1)                                          dValue = 1;

               dPowerValue = MathPow(dSqrtDivider, MathSqrt(dValue));
               if (dSValue-dParamA > 0) dParamA = dSValue;
               else                     dParamA = dSValue - (dSValue-dParamA) * dPowerValue;
               if (dSValue-dParamB < 0) dParamB = dSValue;
               else                     dParamB = dSValue - (dSValue-dParamB) * dPowerValue;
            }
         }
         // end of big cycle

         if (iLoopCriteria > 30) {
            dJMATemp     = jmaBuffer[shift+1];
            dPowerValue  = MathPow(dLengthDivider, dValue);
            dSquareValue = MathPow(dPowerValue, 2);

            iBuffer1[shift] = (1-dPowerValue) * dPrice + dPowerValue * iBuffer1[shift+1];
            iBuffer2[shift] = (dPrice-iBuffer1[shift]) * (1-dLengthDivider) + dLengthDivider * iBuffer2[shift+1];

            iBuffer3[shift] = (dPhaseParam * iBuffer2[shift] + iBuffer1[shift] - dJMATemp) * (-2.0 * dPowerValue + dSquareValue + 1) + dSquareValue * iBuffer3[shift+1];
            dJMATemp += iBuffer3[shift];
         }
         dJMA = dJMATemp;
      }
      if (iLoopParam <= 30) dJMA = 0;
      jmaBuffer[shift] = dJMA;
   }


   if (!IsSuperContext()) {
      @Trend.UpdateLegend(chartLegendLabel, indicatorName, "", indicator_color1, indicator_color1, jmaBuffer[0], SubPipDigits, NULL, NULL);
   }
   return(catch("onTick(2)"));
}
