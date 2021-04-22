/**
 * Calculate the JMA (Jurik Moving Average) of a timeseries.
 *
 * A corrected (non-repainting) and improved version of Nikolay Kositsin's function JJMASeries(). Most important differences
 * are simplified usage, the removal of manual array initialization and improved error handling.
 *
 * @param  int    h         - handle (an array index >= 0) to separately address multiple simultaneous JMA calculations         OK
 *
 * @param  int    iMaxBar   - The maximum value parameter "bar" can take. Usually equals "Bars-1-periods" where "period" is
 *                            the number of bars on which the dJMA.series is not calculated.
 * @param  int    iStartBar - The number of bars not yet counted plus one or the number of the last uncounted bar. Must be
 *                            equal to "Bars-IndicatorCounted()-1" and non-zero.
 *
 * @param  int    length    - smoothing period in bars, may be variable for adaptive indicators                                 OK
 * @param  int    phase     - indicator overshooting: -100 (none)...+100 (max); may be variable for adaptive indicators         OK
 * @param  double series    - value of the timeseries to calculate the JMA value for                                            OK
 * @param  int    bar       - bar index to calculate the JMA for starting at "iMaxBar" counting downwards to 0 (zero)           OK
 *
 * @return double - JMA value or NULL in case of errors (see var last_error)  TODO: or if bar is greater than iMaxBar-30
 *
 * @links  https://www.mql5.com/en/articles/1450                                               [NK-Library, Nikolay Kositsin]
 */
double JMASeries(int h, int iMaxBar, int iStartBar, int length, int phase, double series, int bar) {

   double   dJMA[], dJMASum1[], dJMASum2[], dJMASum3[], dList128A[][128], dList128ABak[][128], dList128B[][128], dList128BBak[][128], dRing11[][11], dRing11Bak[][11];
   double   dSeries62[][62], dBak8[][8], dLengthDivider[], dPhaseParam[], dLogParamA[], dLogParamB[], dParamA[], dParamB[], dSqrtDivider[], dSqrtParam[], dCycleDelta[];
   double   dLowValue[], dSeries, dLengthParam, dPowerValue, dPowerParam, dSquareValue, dSqrtValue, dSDiffParamA, dSDiffParamB, dAbsValue, dHighValue, dValue;
   int      iLastLength[], iLastPhase[], iLimitValue[], iStartValue[], iCounterA[], iCounterB[], iLoopParamA[], iLoopParamB[], iCycleLimit[], i3[], i4[], iBak7[][7], iHighLimit;
   datetime dtTime[];
   bool     bInitialized[];

   // parameter validation
   if (h < 0)                return(!catch("JMASeries(1)  invalid parameter h = "+ h +" (must be non-negative)", ERR_INVALID_PARAMETER));
   if (length < 1)           return(!catch("JMASeries(2)  h="+ h +": invalid parameter length = "+ length +" (min. 1)", ERR_INVALID_PARAMETER));
   if (MathAbs(phase) > 100) return(!catch("JMASeries(3)  h="+ h +": invalid parameter phase = "+ phase +" (must be between -100...+100)", ERR_INVALID_PARAMETER));

   // buffer initialization
   if (h > ArraySize(dJMA)-1) {
      if (!JMASeries.InitBuffers(h+1, dJMA, dJMASum1, dJMASum2, dJMASum3, dList128A, dList128ABak, dList128B, dList128BBak, dRing11, dRing11Bak, dSeries62, dBak8,
                                      dLengthDivider, dPhaseParam, dLogParamA, dLogParamB, dParamA, dParamB, dSqrtDivider, dSqrtParam, dCycleDelta, dLowValue,
                                      iLastLength, iLastPhase, iLimitValue, iStartValue, iCounterA, iCounterB, iLoopParamA, iLoopParamB, iCycleLimit, i3, i4, iBak7,
                                      dtTime, bInitialized))
         return(0);
   }
   //------------------------


   // validate bar parameters
   if (iStartBar>=iMaxBar && !bar && iMaxBar>30 && !dtTime[h])
      logWarn("JMASeries(4)  h="+ h +": illegal bar parameters", ERR_INVALID_PARAMETER);
   if (bar > iMaxBar)
      return(0);

   // calculate coefficients
   if (bar==iMaxBar || length!=iLastLength[h] || phase!=iLastPhase[h]) {
      dLengthParam      = MathMax(0.0000000001, (length-1)/2.) * 0.9;
      dLengthDivider[h] = dLengthParam/(dLengthParam + 2);
      dSqrtValue        = MathSqrt(dLengthParam);
      dLogParamA[h]     = MathMax(0, MathLog(dSqrtValue)/MathLog(2) + 2);
      dLogParamB[h]     = MathMax(dLogParamA[h] - 2, 0.5);
      dSqrtParam[h]     = dSqrtValue * dLogParamA[h];
      dSqrtDivider[h]   = dSqrtParam[h] / (dSqrtParam[h] + 1);
      dPhaseParam[h]    = phase/100. + 1.5;
      iLastLength[h]    = length;
      iLastPhase[h]     = phase;
   }

   if (bar==iStartBar && iStartBar < iMaxBar) {
      // restore values
      //debug("JMASeries(0.2)  Tick="+ Tick +"  bar="+ bar +"  restore");
      datetime dtNew = Time[iStartBar+1];
      datetime dtOld = dtTime[h];
      if (dtNew != dtOld) return(!catch("JMASeries(5)  h="+ h +": invalid parameter iStartBar = "+ iStartBar +" (too "+ ifString(dtNew > dtOld, "small", "large") +")", ERR_INVALID_PARAMETER));

      for (int i=127; i >= 0; i--) dList128A[h][i] = dList128ABak[h][i];
      for (    i=127; i >= 0; i--) dList128B[h][i] = dList128BBak[h][i];
      for (    i=10;  i >= 0; i--) dRing11  [h][i] = dRing11Bak  [h][i];

      dParamA[h]     = dBak8[h][0]; iLoopParamA[h] = iBak7[h][0];
      dParamB[h]     = dBak8[h][1]; iLoopParamB[h] = iBak7[h][1];
      dCycleDelta[h] = dBak8[h][2]; iCycleLimit[h] = iBak7[h][2];
      dLowValue[h]   = dBak8[h][3]; iCounterA[h]   = iBak7[h][3];
      dJMASum1[h]    = dBak8[h][4]; iCounterB[h]   = iBak7[h][4];
      dJMASum2[h]    = dBak8[h][5]; i3[h]          = iBak7[h][5];
      dJMASum3[h]    = dBak8[h][6]; i4[h]          = iBak7[h][6];
      dJMA[h]        = dBak8[h][7];
   }

   if (bar == 1) {
      if (iStartBar!=1 || Time[iStartBar+2]==dtTime[h]) {
         // store values
         //debug("JMASeries(0.1)  Tick="+ Tick +"  bar="+ bar +"  backup");
         for (i=127; i >= 0; i--) dList128ABak[h][i] = dList128A[h][i];
         for (i=127; i >= 0; i--) dList128BBak[h][i] = dList128B[h][i];
         for (i=10;  i >= 0; i--) dRing11Bak  [h][i] = dRing11  [h][i];

         dBak8[h][0] = dParamA[h];     iBak7[h][0] = iLoopParamA[h];
         dBak8[h][1] = dParamB[h];     iBak7[h][1] = iLoopParamB[h];
         dBak8[h][2] = dCycleDelta[h]; iBak7[h][2] = iCycleLimit[h];
         dBak8[h][3] = dLowValue[h];   iBak7[h][3] = iCounterA[h];
         dBak8[h][4] = dJMASum1[h];    iBak7[h][4] = iCounterB[h];
         dBak8[h][5] = dJMASum2[h];    iBak7[h][5] = i3[h];
         dBak8[h][6] = dJMASum3[h];    iBak7[h][6] = i4[h];
         dBak8[h][7] = dJMA[h];        dtTime[h]   = Time[2];
      }
   }

   if (iLoopParamA[h] < 61) {
      iLoopParamA[h]++;
      dSeries62[h][iLoopParamA[h]] = series;
   }

   if (iLoopParamA[h] > 30) {
      iHighLimit = 0;
      if (!bInitialized[h]) {
         dParamA[h]      = dSeries62[h][1];
         dParamB[h]      = dSeries62[h][1];
         iHighLimit      = 29;
         bInitialized[h] = true;
      }

      // big for loop
      for (i=iHighLimit; i >= 0; i--) {
         if (i == 0) dSeries = series;
         else        dSeries = dSeries62[h][31-i];

         dSDiffParamA = dSeries - dParamA[h];
         dSDiffParamB = dSeries - dParamB[h];
         dAbsValue    = MathMax(MathAbs(dSDiffParamA), MathAbs(dSDiffParamB));
         dValue       = dAbsValue + 0.0000000001;
         dPowerParam  = dAbsValue;

         if (iCounterA[h] <= 1) iCounterA[h] = 127;
         else                   iCounterA[h]--;
         if (iCounterB[h] <= 1) iCounterB[h] = 10;
         else                   iCounterB[h]--;
         if (iCycleLimit[h] < 128)
            iCycleLimit[h]++;

         dCycleDelta[h]          += dValue - dRing11[h][iCounterB[h]];
         dRing11[h][iCounterB[h]] = dValue;

         if (iCycleLimit[h] > 10) dHighValue = dCycleDelta[h] / 10;
         else                     dHighValue = dCycleDelta[h] / iCycleLimit[h];

         int n, i1, i2;

         if (iCycleLimit[h] > 127) {
            dValue = dList128B[h][iCounterA[h]];
            dList128B[h][iCounterA[h]] = dHighValue;

            i1 = 64;
            n  = 64;
            while (n > 1) {
               if (dList128A[h][i1] == dValue)
                  break;
               n >>= 1;
               if (dList128A[h][i1] < dValue) i1 += n;
               else                           i1 -= n;
            }
         }
         else {
            dList128B[h][iCounterA[h]] = dHighValue;
            if  (iLimitValue[h] + iStartValue[h] > 127) {
               iStartValue[h]--;
               i1 = iStartValue[h];
            }
            else {
               iLimitValue[h]++;
               i1 = iLimitValue[h];
            }
            i3[h] = MathMin(iLimitValue[h], 96);
            i4[h] = MathMax(iStartValue[h], 32);
         }

         i2 = 64;
         n  = 64;
         while (n > 1) {
            n >>= 1;
            if      (dList128A[h][i2]   < dHighValue) i2 += n;
            else if (dList128A[h][i2-1] > dHighValue) i2 -= n;
            else                                      n = 1;
            if (i2==127 && dHighValue > dList128A[h][127])
               i2 = 128;
         }

         if (iCycleLimit[h] > 127) {
            if (i1 >= i2) {
               if      (i3[h]+1 > i2 && i4[h]-1 < i2) dLowValue[h] += dHighValue;
               else if (i4[h]   > i2 && i4[h]-1 < i1) dLowValue[h] += dList128A[h][i4[h]-1];
            }
            else if (i4[h] >= i2) {
               if (i3[h]+1 < i2 && i3[h]+1 > i1)      dLowValue[h] += dList128A[h][i3[h]+1];
            }
            else if (i3[h]+2 > i2)                    dLowValue[h] += dHighValue;
            else if (i3[h]+1 < i2 && i3[h]+1 > i1)    dLowValue[h] += dList128A[h][i3[h]+1];

            if (i1 > i2) {
               if      (i4[h]-1 < i1 && i3[h]+1 > i1) dLowValue[h] -= dList128A[h][i1];
               else if (i3[h]   < i1 && i3[h]+1 > i2) dLowValue[h] -= dList128A[h][i3[h]];
            }
            else if (i3[h]+1 > i1 && i4[h]-1 < i1)    dLowValue[h] -= dList128A[h][i1];
            else if (i4[h]   > i1 && i4[h]   < i2)    dLowValue[h] -= dList128A[h][i4[h]];
         }

         if      (i1 > i2) { for (int j=i1-1; j >= i2;   j--) dList128A[h][j+1] = dList128A[h][j]; dList128A[h][i2]   = dHighValue; }
         else if (i1 < i2) { for (    j=i1+1; j <= i2-1; j++) dList128A[h][j-1] = dList128A[h][j]; dList128A[h][i2-1] = dHighValue; }
         else              {                                                                       dList128A[h][i2]   = dHighValue; }

         if (iCycleLimit[h] <= 127) {
            dLowValue[h] = 0;
            for (j=i4[h]; j <= i3[h]; j++) {
               dLowValue[h] += dList128A[h][j];
            }
         }

         iLoopParamB[h]++;
         if (iLoopParamB[h] > 31) iLoopParamB[h] = 31;

         if (iLoopParamB[h] < 31) {
            if (dSDiffParamA > 0) dParamA[h] = dSeries;
            else                  dParamA[h] = dSeries - dSDiffParamA * dSqrtDivider[h];
            if (dSDiffParamB < 0) dParamB[h] = dSeries;
            else                  dParamB[h] = dSeries - dSDiffParamB * dSqrtDivider[h];
            dJMA[h] = series;

            if (iLoopParamB[h] < 30)
               continue;

            dJMASum1[h] = series;

            int iLeftInt=1, iRightPart=1;
            if (dSqrtParam[h] >  0) iLeftInt   = MathCeil(dSqrtParam[h]);
            if (dSqrtParam[h] >= 1) iRightPart = dSqrtParam[h];
            dPowerParam = iRightPart;

            int iUpShift=29, iDnShift=29;
            if (iRightPart <= 29) iUpShift = iRightPart;
            if (iLeftInt   <= 29) iDnShift = iLeftInt;

            dValue      = MathDiv(dSqrtParam[h]-iRightPart, iLeftInt-iRightPart, 1);
            dJMASum3[h] = (series-dSeries62[h][iLoopParamA[h]-iUpShift]) * (1-dValue)/iRightPart + (series-dSeries62[h][iLoopParamA[h]-iDnShift]) * dValue/iLeftInt;
         }
         else {
            dValue      = dLowValue[h] / (i3[h] - i4[h] + 1);
            dPowerParam = MathPow(dAbsValue/dValue, dLogParamB[h]);
            if (dPowerParam > dLogParamA[h]) dPowerParam = dLogParamA[h];
            if (dPowerParam < 1)             dPowerParam = 1;

            dPowerValue = MathPow(dSqrtDivider[h], MathSqrt(dPowerParam));

            if (dSDiffParamA > 0) dParamA[h] = dSeries;
            else                  dParamA[h] = dSeries - dSDiffParamA * dPowerValue;
            if (dSDiffParamB < 0) dParamB[h] = dSeries;
            else                  dParamB[h] = dSeries - dSDiffParamB * dPowerValue;
         }
      }
      // end of big for (i=iHighLimit; i >= 0; i--)

      if (iLoopParamB[h] > 30) {
         dPowerValue  = MathPow(dLengthDivider[h], dPowerParam);
         dSquareValue = MathPow(dPowerValue, 2);

         dJMASum1[h] = (1-dPowerValue) * series + dPowerValue * dJMASum1[h];
         dJMASum2[h] = (series-dJMASum1[h]) * (1-dLengthDivider[h]) + dLengthDivider[h] * dJMASum2[h];
         dJMASum3[h] = (dPhaseParam[h] * dJMASum2[h] + dJMASum1[h] - dJMA[h]) * (-2 * dPowerValue + dSquareValue + 1) + dSquareValue * dJMASum3[h];
         dJMA[h]    += dJMASum3[h];
      }
   }
   else /*iLoopParamA[h] <= 30*/ {
      dJMA[h] = 0;
   }

   int error = GetLastError();
   if (!error)
      return(dJMA[h]);
   return(!catch("JMASeries(6)  h="+ h, error));
}


/**
 * Initialize the specified number of JMA calculation buffers.
 *
 * @param  _In_  int    size   - number of timeseries to initialize buffers for; if 0 (zero) all buffers are released
 * @param  _Out_ double dJMA[] - buffer arrays
 * @param  _Out_ ...
 *
 * @return bool - success status
 */
bool JMASeries.InitBuffers(int size, double dJMA[], double dJMASum1[], double dJMASum2[], double dJMASum3[], double dList128A[][], double dList128ABak[][], double dList128B[][],
                                     double dList128BBak[][], double dRing11[][], double dRing11Bak[][], double dSeries62[][], double dBak8[][], double dLengthDivider[],
                                     double dPhaseParam[], double dLogParamA[], double dLogParamB[], double dParamA[], double dParamB[], double dSqrtDivider[], double dSqrtParam[],
                                     double dCycleDelta[], double dLowValue[], int iLastLength[], int &iLastPhase[], int &iLimitValue[], int &iStartValue[], int iCounterA[],
                                     int iCounterB[], int iLoopParamA[], int iLoopParamB[], int iCycleLimit[], int i3[], int i4[], int iBak7[][], datetime dtTime[], bool bInitialized[]) {

   if (size < 0) return(!catch("JMASeries.InitBuffers(1)  invalid parameter size: "+ size +" (must be non-negative)", ERR_INVALID_PARAMETER));

   int oldSize = ArrayRange(dJMA, 0);

   if (!size || size > oldSize) {
      ArrayResize(dJMA,           size);
      ArrayResize(dJMASum1,       size);
      ArrayResize(dJMASum2,       size);
      ArrayResize(dJMASum3,       size);
      ArrayResize(dList128A,      size);
      ArrayResize(dList128ABak,   size);
      ArrayResize(dList128B,      size);
      ArrayResize(dList128BBak,   size);
      ArrayResize(dRing11,        size);
      ArrayResize(dRing11Bak,     size);
      ArrayResize(dSeries62,      size);
      ArrayResize(dBak8,          size);
      ArrayResize(dLengthDivider, size);
      ArrayResize(dPhaseParam,    size);
      ArrayResize(dLogParamA,     size);
      ArrayResize(dLogParamB,     size);
      ArrayResize(dParamA,        size);
      ArrayResize(dParamB,        size);
      ArrayResize(dSqrtDivider,   size);
      ArrayResize(dSqrtParam,     size);
      ArrayResize(dCycleDelta,    size);
      ArrayResize(dLowValue,      size);
      ArrayResize(iLastLength,    size);
      ArrayResize(iLastPhase,     size);
      ArrayResize(iLimitValue,    size);
      ArrayResize(iStartValue,    size);
      ArrayResize(iCounterA,      size);
      ArrayResize(iCounterB,      size);
      ArrayResize(iLoopParamA,    size);
      ArrayResize(iLoopParamB,    size);
      ArrayResize(iCycleLimit,    size);
      ArrayResize(iBak7,          size);
      ArrayResize(i3,             size);
      ArrayResize(i4,             size);
      ArrayResize(dtTime,         size);
      ArrayResize(bInitialized,   size);
   }
   if (size <= oldSize) return(!catch("JMASeries.InitBuffers(2)"));

   double dMinus[1][128]; ArrayInitialize(dMinus, -1000000);
   double dPlus [1][128]; ArrayInitialize(dPlus,  +1000000);

   for (int i=oldSize; i < size; i++) {
      iLastPhase [i] = INT_MAX;
      iLimitValue[i] = 63;
      iStartValue[i] = 64;
      ArrayCopy(dList128A, dMinus, i*128,      0, 64);
      ArrayCopy(dList128A, dPlus,  i*128 + 64, 0, 64);
   }
   return(!catch("JMASeries.InitBuffers(3)"));
}
