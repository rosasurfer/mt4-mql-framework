/**
 * Calculate the JMA (Jurik Moving Average) of one or more timeseries.
 *
 * This function is a rewritten and improved version of JJMASeries() - the JMA algorithm published by Nikolay Kositsin (see
 * link below). Most significant changes for the user are the new function signature, the removal of manual initialization
 * with JJMASeriesResize() and improved error handling.
 *
 * @param  int    h       - non-negative value (pseudo handle) to separately address multiple simultaneous JMA calculations
 *
 *
 * TODO:
 * -----
 * @param  int    iDin    - allows to change the iPeriods and iPhase parameters on each bar. 0 - change prohibition parameters,
 *                          any other value is resolution (see indicators "nk/Lines/AMAJ.mq4" and "nk/Lines/AMAJ2.mq4")
 * @param  int    MaxBar  - The maximum value that the calculated bar number (iBar) can take. Usually equals Bars-1-periods
 *                          where "period" is the number of bars on which the dJMA.series is not calculated.
 * @param  int    limit   - The number of bars not yet counted plus one or the number of the last uncounted bar. Must be
 *                          equal to Bars-IndicatorCounted()-1. Must be non-zero.
 * @param  int    Length  - smoothing period
 * @param  int    Phase   - varies between -100 ... +100 and affects the quality of the transition process
 * @param  double dPrice  - price for which the indicator value is calculated
 * @param  int    iBar    - Number of the bar to calculate counting downwards to zero. Its maximum value should always be
 *                          equal to the value of the parameter limit.
 *
 * @return double - JMA value or NULL in case of errors (see last_error)      TODO: or if iBar is greater than nJMA.MaxBar-30
 *
 *
 * @see  NK-Library, Nikolay Kositsin: https://www.mql5.com/en/articles/1450
 */
double JMASeries(int h, int iDin, int iOldestBar, int iStartBar, int iPhase, int iPeriods, double dPrice, int iBar) {

   double   dJMA[], dList128A[][128], dList128B[][128], dList128C[][128], dList128D[][128], dRing11[][11], dRing11Bak[][11], dBak8[][8];
   double   dPrices62[][62], dLengthDivider[], dPhaseParam[], dParamA[], dParamB[], dCycleDelta[], dLowValue[], dJMATmp1[], dJMATmp2[], dJMATmp3[];
   double   dSqrtDivider[], dV2[], dV3[], dSqrtParam[], dF88[], dF98[];
   int      iLimitValue[], iStartValue[], iCounterA[], iCounterB[], iCycleLimit[], iLoopParamA[], iLoopParamB[], i3[], i4[], iBak7[][7], iF0[];
   datetime iDatetime[];
   double   dValue2, dPowerValue, dSquareValue, dHighValue, dSValue, dSDiffParamA, dSDiffParamB, dF60, dF68, dFa0, dVv, dV4, dS10, dFd0;
   int      iHighLimit, iV5, iV6, iFe0, iFe8;

   // parameter validation
   if (h < 0)                 return(!catch("JMASeries(1)  invalid parameter h = "+ h +" (must be non-negative)", ERR_INVALID_PARAMETER));
   if (iPeriods < 1)          return(!catch("JMASeries(2)  h="+ h +": invalid parameter iPeriods = "+ iPeriods +" (min. 1)", ERR_INVALID_PARAMETER));
   if (MathAbs(iPhase) > 100) return(!catch("JMASeries(3)  h="+ h +": invalid parameter iPhase = "+ iPhase +" (must be between -100...+100)", ERR_INVALID_PARAMETER));

   // buffer initialization
   if (h > ArraySize(dJMA)-1) {
      if (!JMASeries.InitBuffers(h+1, dJMA, dList128A, dList128B, dList128C, dList128D, dRing11, dRing11Bak, dBak8, dPrices62, dLengthDivider,
                                      dPhaseParam, dParamA, dParamB, dJMATmp1, dJMATmp2, dJMATmp3, dCycleDelta, dLowValue, dV2, dV3, dSqrtDivider,
                                      dSqrtParam, dF88, dF98, iBak7, iLimitValue, iStartValue, iCounterA, i3, i4, iCounterB, iCycleLimit, iLoopParamA, iLoopParamB, iF0, iDatetime))
         return(0);
   }
   //------------------------



   // validate bar parameters
   if (iStartBar>=iOldestBar && !iBar && iOldestBar>30 && !iDatetime[h])
      warn("JMASeries(4)  h="+ h +": illegal bar parameters", ERR_INVALID_PARAMETER);
   if (iBar > iOldestBar)
      return(0);

   // calculate coefficients
   if (iBar==iOldestBar || iDin) {
      double dLengthParam = MathMax(0.0000000001, (iPeriods-1)/2.) * 0.9;
      dLengthDivider[h]   = dLengthParam/(dLengthParam + 2);

      double dS = MathSqrt(dLengthParam);
      double dL = MathLog(dS);

      dV2[h] = dL;
      dV3[h] = MathMax(dL/MathLog(2) + 2, 0);

      dF98[h] = dV3[h];

      if (dF98[h] >= 2.5) dF88[h] = dF98[h] - 2;
      else                dF88[h] = 0.5;

      dSqrtParam[h]   = dS * dF98[h];
      dSqrtDivider[h] = dSqrtParam[h] / (dSqrtParam[h] + 1);

      dPhaseParam[h]  = iPhase/100. + 1.5;
   }

   if (iBar==iStartBar && iStartBar < iOldestBar) {
      // restore values
      datetime new = Time[iStartBar+1];
      datetime old = iDatetime[h];
      if (new != old) return(!catch("JMASeries(5)  h="+ h +": invalid parameter iStartBar = "+ iStartBar +" (too "+ ifString(new > old, "small", "large") +")", ERR_INVALID_PARAMETER));

      for (int i=127; i >= 0; i--) dList128A[h][i] = dList128C [h][i];
      for (    i=127; i >= 0; i--) dList128B[h][i] = dList128D [h][i];
      for (    i=10;  i >= 0; i--) dRing11  [h][i] = dRing11Bak[h][i];

      dParamA[h]     = dBak8[h][0]; iLoopParamA[h] = iBak7[h][0];
      dParamB[h]     = dBak8[h][1]; iLoopParamB[h] = iBak7[h][1];
      dCycleDelta[h] = dBak8[h][2]; iCycleLimit[h] = iBak7[h][2];
      dLowValue[h]   = dBak8[h][3]; iCounterA[h]   = iBak7[h][3];
      dJMATmp1[h]    = dBak8[h][4]; iCounterB[h]   = iBak7[h][4];
      dJMATmp2[h]    = dBak8[h][5]; i3[h]          = iBak7[h][5];
      dJMATmp3[h]    = dBak8[h][6]; i4[h]          = iBak7[h][6];
      dJMA[h]        = dBak8[h][7];
   }

   if (iBar == 1) {
      if (iStartBar!=1 || Time[iStartBar+2]==iDatetime[h]) {
         // store values
         for (i=127; i >= 0; i--) dList128C [h][i] = dList128A[h][i];
         for (i=127; i >= 0; i--) dList128D [h][i] = dList128B[h][i];
         for (i=10;  i >= 0; i--) dRing11Bak[h][i] = dRing11  [h][i];

         dBak8[h][0] = dParamA[h];     iBak7[h][0]  = iLoopParamA[h];
         dBak8[h][1] = dParamB[h];     iBak7[h][1]  = iLoopParamB[h];
         dBak8[h][2] = dCycleDelta[h]; iBak7[h][2]  = iCycleLimit[h];
         dBak8[h][3] = dLowValue[h];   iBak7[h][3]  = iCounterA[h];
         dBak8[h][4] = dJMATmp1[h];    iBak7[h][4]  = iCounterB[h];
         dBak8[h][5] = dJMATmp2[h];    iBak7[h][5]  = i3[h];
         dBak8[h][6] = dJMATmp3[h];    iBak7[h][6]  = i4[h];
         dBak8[h][7] = dJMA[h];        iDatetime[h] = Time[2];
      }
   }

   if (iLoopParamA[h] < 61) {
      iLoopParamA[h]++;
      dPrices62[h][iLoopParamA[h]] = dPrice;
   }

   if (iLoopParamA[h] > 30) {
      if (iF0[h] != 0) {
         iF0[h] = 0;
         iV5 = 1;
         iHighLimit = iV5 * 30;
         if (iHighLimit == 0) dParamB[h] = dPrice;
         else                 dParamB[h] = dPrices62[h][1];
         dParamA[h] = dParamB[h];
         if (iHighLimit > 29) iHighLimit = 29;
      }
      else iHighLimit = 0;

      // big cycle
      for (i=iHighLimit; i >= 0; i--) {
         if (i == 0) dSValue = dPrice;
         else        dSValue = dPrices62[h][31-i];

         dSDiffParamA = dSValue - dParamA[h];
         dSDiffParamB = dSValue - dParamB[h];
         dV2[h] = MathMax(MathAbs(dSDiffParamA), MathAbs(dSDiffParamB));

         dFa0 = dV2[h];
         dVv = dFa0 + 0.0000000001;

         if (iCounterA[h] <= 1) iCounterA[h] = 127;
         else                   iCounterA[h]--;
         if (iCounterB[h] <= 1) iCounterB[h] = 10;
         else                   iCounterB[h]--;
         if (iCycleLimit[h] < 128)
            iCycleLimit[h]++;

         dCycleDelta[h]          += dVv - dRing11[h][iCounterB[h]];
         dRing11[h][iCounterB[h]] = dVv;

         if (iCycleLimit[h] > 10) dHighValue = dCycleDelta[h] / 10;
         else                     dHighValue = dCycleDelta[h] / iCycleLimit[h];

         int n, i1, i2;

         if (iCycleLimit[h] > 127) {
            dS10 = dList128B[h][iCounterA[h]];
            dList128B[h][iCounterA[h]] = dHighValue;

            i1 = 64;
            n  = 64;
            while (n > 1) {
               if (dList128A[h][i1] == dS10)
                  break;
               n >>= 1;
               if (dList128A[h][i1] < dS10) i1 += n;
               else                         i1 -= n;
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
         dF60 = dLowValue[h] / (i3[h] - i4[h] + 1);

         iLoopParamB[h]++;
         if (iLoopParamB[h] > 31) iLoopParamB[h] = 31;

         if (iLoopParamB[h] < 31) {
            if (dSDiffParamA > 0) dParamA[h] = dSValue;
            else                  dParamA[h] = dSValue - dSDiffParamA * dSqrtDivider[h];
            if (dSDiffParamB < 0) dParamB[h] = dSValue;
            else                  dParamB[h] = dSValue - dSDiffParamB * dSqrtDivider[h];
            dJMA[h] = dPrice;

            if (iLoopParamB[h] < 30)
               continue;

            dJMATmp1[h] = dPrice;

            if (MathCeil(dSqrtParam[h]) >= 1) dV4 = MathCeil(dSqrtParam[h]);
            else                              dV4 = 1;

            if      (dV4 > 0) iFe8 = MathFloor(dV4);
            else if (dV4 < 0) iFe8 = MathCeil(dV4);
            else              iFe8 = 0;

            if (MathFloor(dSqrtParam[h]) >= 1) dV2[h] = MathFloor(dSqrtParam[h]);
            else                               dV2[h] = 1;

            if      (dV2[h] > 0) iFe0 = MathFloor(dV2[h]);
            else if (dV2[h] < 0) iFe0 = MathCeil(dV2[h]);
            else                 iFe0 = 0;

            dF68 = MathDiv(dSqrtParam[h]-iFe0, iFe8-iFe0, 1);

            if (iFe0 <= 29) iV5 = iFe0;
            else            iV5 = 29;

            if (iFe8 <= 29) iV6 = iFe8;
            else            iV6 = 29;

            dJMATmp3[h] = (dPrice-dPrices62[h][iLoopParamA[h]-iV5]) * (1-dF68) / iFe0 + (dPrice-dPrices62[h][iLoopParamA[h]-iV6]) * dF68 / iFe8;
         }
         else {
            double dValue1 = MathMin(dF98[h], MathPow(dFa0/dF60, dF88[h]));
            if (dValue1 < 1) {
               dV2[h] = 1;
            }
            else {
               if (dF98[h] >= MathPow(dFa0/dF60, dF88[h])) dV3[h] = MathPow(dFa0/dF60, dF88[h]);
               else                                        dV3[h] = dF98[h];
               dV2[h] = dV3[h];
            }
            dValue2     = dV2[h];
            dPowerValue = MathPow(dSqrtDivider[h], MathSqrt(dValue2));

            if (dSDiffParamA > 0) dParamA[h] = dSValue;
            else                  dParamA[h] = dSValue - dSDiffParamA * dPowerValue;
            if (dSDiffParamB < 0) dParamB[h] = dSValue;
            else                  dParamB[h] = dSValue - dSDiffParamB * dPowerValue;
         }
      }
      // end of big cycle

      if (iLoopParamB[h] > 30) {
         dPowerValue  = MathPow(dLengthDivider[h], dValue2);
         dSquareValue = MathPow(dPowerValue, 2);

         dJMATmp1[h] = (1-dPowerValue) * dPrice + dPowerValue * dJMATmp1[h];
         dJMATmp2[h] = (dPrice-dJMATmp1[h]) * (1-dLengthDivider[h]) + dLengthDivider[h] * dJMATmp2[h];
         dJMATmp3[h] = (dPhaseParam[h] * dJMATmp2[h] + dJMATmp1[h] - dJMA[h]) * (-2 * dPowerValue + dSquareValue + 1) + dSquareValue * dJMATmp3[h];
         dJMA[h]    += dJMATmp3[h];
      }
   }
   if (iLoopParamA[h] <= 30)
      dJMA[h] = 0;

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
bool JMASeries.InitBuffers(int size, double dJMA[], double &dList128A[][], double dList128B[][], double dList128C[][], double dList128D[][],
                                     double dRing11[][], double dRing11Bak[][], double dBak8[][], double dPrices62[][], double dLengthDivider[], double dPhaseParam[], double dParamA[],
                                     double dParamB[], double dJMATmp1[], double dJMATmp2[], double dJMATmp3[], double dCycleDelta[], double dLowValue[], double dV2[],
                                     double dV3[], double dSqrtDivider[], double dF78[], double dF88[], double dF98[],
                                     int iBak7[][], int &iLimitValue[], int &iStartValue[], int iCounterA[], int i3[], int i4[], int iCounterB[], int iCycleLimit[],
                                     int iLoopParamA[], int iLoopParamB[], int &iF0[],
                                     datetime iDatetime[]) {
   if (size < 0) return(!catch("JMASeries.InitBuffers(1)  invalid parameter size: "+ size +" (must be non-negative)", ERR_INVALID_PARAMETER));

   int oldSize = ArrayRange(dJMA, 0);

   if (!size || size > oldSize) {
      ArrayResize(dJMA,           size);
      ArrayResize(dList128A,      size);
      ArrayResize(dList128B,      size);
      ArrayResize(dList128C,      size);
      ArrayResize(dList128D,      size);
      ArrayResize(dRing11,        size);
      ArrayResize(dRing11Bak,     size);
      ArrayResize(dBak8,          size);
      ArrayResize(dPrices62,      size);
      ArrayResize(dLengthDivider, size);
      ArrayResize(dPhaseParam,    size);
      ArrayResize(dParamA,        size);
      ArrayResize(dParamB,        size);
      ArrayResize(dJMATmp1,       size);
      ArrayResize(dJMATmp2,       size);
      ArrayResize(dJMATmp3,       size);
      ArrayResize(dCycleDelta,    size);
      ArrayResize(dLowValue,      size);
      ArrayResize(dV2,            size);
      ArrayResize(dV3,            size);
      ArrayResize(dSqrtDivider,   size);
      ArrayResize(dF78,           size);
      ArrayResize(dF88,           size);
      ArrayResize(dF98,           size);
      ArrayResize(iBak7,          size);
      ArrayResize(iLimitValue,    size);
      ArrayResize(iStartValue,    size);
      ArrayResize(iCounterA,      size);
      ArrayResize(i3,             size);
      ArrayResize(i4,             size);
      ArrayResize(iCounterB,      size);
      ArrayResize(iCycleLimit,    size);
      ArrayResize(iLoopParamA,    size);
      ArrayResize(iLoopParamB,    size);
      ArrayResize(iF0,            size);
      ArrayResize(iDatetime,      size);
   }
   if (size <= oldSize) return(!catch("JMASeries.InitBuffers(2)"));

   for (int i=oldSize; i < size; i++) {
      iF0 [i] =  1;
      iLimitValue[i] = 63;
      iStartValue[i] = 64;

      for (int j=0; j <=  63; j++) dList128A[i][j] = -1000000;
      for (j=64;    j <= 127; j++) dList128A[i][j] = +1000000;
   }
   return(!catch("JMASeries.InitBuffers(3)"));
}
