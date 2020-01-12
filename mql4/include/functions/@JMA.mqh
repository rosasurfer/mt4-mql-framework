/**
 * Calculate the JMA (Jurik Moving Average) of one or more timeseries.
 *
 * This function is a modified version of the JMA algorithm published by Nikolay Kositsin (see link below) with fixed bugs
 * and solved usage and design issues.
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
 * @return double - JMA value or NULL in case of errors                    TODO: or if iBar is greater than nJMA.MaxBar-30
 *
 * @see  "/etc/doc/jurik/Jurik Research Product Guide [2015.09].pdf"
 * @see  NK-Library, Nikolay Kositsin: https://www.mql5.com/en/articles/1450
 */
double JJMASeries(int h, int iDin, int iOldestBar, int iStartBar, int iPhase, int iPeriods, double dPrice, int iBar) {

   double   dJMA[], dList128A[][128], dList128B[][128], dList128C[][128], dList128D[][128], dList128E[][128], dRing11A[][11], dRing11B[][11];
   double   dMem8[][8], dPrices62[][62], dKg[], dPf[], dParamA[], dParamB[], dFa8[], dFc0[], dFc8[], dCycleDelta[], dS18[], dV1[], dV2[], dV3[], dF90[], dF78[], dF88[], dF98[];
   int      iMem7[][7], iMem11[][11], iS28[], iS30[], iCounterA[], iS38[], iS40[], iCounterB[], iCycleLimit[], iLoopParam[], iLp2[], iF0[];
   datetime iDatetime[];
   double   dFa0, dVv, dV4, dF70, dHighValue, dS10, dFb0, dFd0, dSValue, dF60, dF20, dSDiffParamA, dF30, dF40, dSDiffParamB, dF58, dF68;
   int      iV5, iV6, iFe0, iHighLimit, iFe8, iS58, iS60, iS68;

   // parameter validation
   if (h < 0) return(!catch("JJMASeries(1)  invalid parameter h: "+ h +" (must be non-negative)", ERR_INVALID_PARAMETER));

   // buffer initialization
   if (h > ArraySize(dJMA)-1) {
      if (!JJMASeries.InitBuffers(h+1, dJMA, dList128A, dList128B, dList128C, dList128D, dList128E, dRing11A, dRing11B, dMem8, dPrices62, dKg, dPf, dParamA, dParamB, dFa8, dFc0, dFc8, dCycleDelta, dS18, dV1, dV2, dV3, dF90, dF78, dF88, dF98, iMem7, iMem11, iS28, iS30, iCounterA, iS38, iS40, iCounterB, iCycleLimit, iLoopParam, iLp2, iF0, iDatetime))
         return(0);
   }
   //------------------------



   // validate bar parameters
   if (iStartBar>=iOldestBar && !iBar && iOldestBar>30 && !iDatetime[h])
      warn("JJMASeries(2)  h="+ h +": illegal bar parameters", ERR_INVALID_PARAMETER);
   if (iBar > iOldestBar)
      return(0);

   // calculate coefficients
   if (iBar==iOldestBar || iDin) {
      double dR, dS, dL;
      if (iPeriods < 1.0000000002) dR = 0.0000000001;
      else                         dR = (iPeriods-1)/2.;

      if (iPhase>=-100 && iPhase<=100) dPf[h] = iPhase/100. + 1.5;

      if (iPhase > +100) dPf[h] = 2.5;
      if (iPhase < -100) dPf[h] = 0.5;

      dR = dR * 0.9;
      dKg[h] = dR/(dR + 2.0);
      dS = MathSqrt(dR);
      dL = MathLog(dS);
      dV1[h] = dL;
      dV2[h] = dV1[h];

      if (dV1[h]/MathLog(2) + 2 < 0) dV3[h] = 0;
      else                           dV3[h] = dV2[h]/MathLog(2) + 2;

      dF98[h] = dV3[h];

      if (dF98[h] >= 2.5) dF88[h] = dF98[h] - 2;
      else                dF88[h] = 0.5;

      dF78[h] = dS * dF98[h];
      dF90[h] = dF78[h] / (dF78[h] + 1);
   }

   if (iBar==iStartBar && iStartBar < iOldestBar) {
      // restore values
      datetime dtNew = Time[iStartBar+1];
      datetime dTold = iDatetime[h];
      if (dtNew != dTold) return(!catch("JJMASeries(3)  h="+ h +": invalid parameter iStartBar = "+ iStartBar +" (too "+ ifString(dtNew > dTold, "small", "large") +")", ERR_INVALID_PARAMETER));

      for (int i=127; i >= 0; i--) dList128A[h][i] = dList128E[h][i];
      for (    i=127; i >= 0; i--) dList128B[h][i] = dList128D[h][i];
      for (    i=10;  i >= 0; i--) dRing11A [h][i] = dRing11B [h][i];

      dFc0[h]        = dMem8[h][0]; dFc8[h]      = dMem8[h][1]; dFa8[h]        = dMem8[h][2];
      dCycleDelta[h] = dMem8[h][3]; dParamA[h]   = dMem8[h][4]; dParamB[h]     = dMem8[h][5];
      dS18[h]        = dMem8[h][6]; dJMA[h]      = dMem8[h][7]; iS38[h]        = iMem7[h][0];
      iCounterA[h]   = iMem7[h][1]; iCounterB[h] = iMem7[h][2]; iLoopParam[h]  = iMem7[h][3];
      iLp2[h]        = iMem7[h][4]; iS40[h]      = iMem7[h][5]; iCycleLimit[h] = iMem7[h][6];
   }

   if (iBar == 1) {
      if (iStartBar!=1 || Time[iStartBar+2]==iDatetime[h]) {
         // store values
         for (i=127; i >= 0; i--) dList128E[h][i] = dList128A[h][i];
         for (i=127; i >= 0; i--) dList128D[h][i] = dList128B[h][i];
         for (i=10;  i >= 0; i--) dRing11B [h][i] = dRing11A [h][i];

         dMem8[h][0] = dFc0[h];        dMem8[h][1] = dFc8[h];      dMem8[h][2] = dFa8[h];
         dMem8[h][3] = dCycleDelta[h]; dMem8[h][4] = dParamA[h];   dMem8[h][5] = dParamB[h];
         dMem8[h][6] = dS18[h];        dMem8[h][7] = dJMA[h];      iMem7[h][0] = iS38[h];
         iMem7[h][1] = iCounterA[h];   iMem7[h][2] = iCounterB[h]; iMem7[h][3] = iLoopParam[h];
         iMem7[h][4] = iLp2[h];        iMem7[h][5] = iS40[h];      iMem7[h][6] = iCycleLimit[h];
         iDatetime[h] = Time[2];
      }
   }

   if (iLoopParam[h] < 61) {
      iLoopParam[h]++;
      dPrices62[h][iLoopParam[h]] = dPrice;
   }

   if (iLoopParam[h] > 30) {
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

         dCycleDelta[h]           += dVv - dRing11A[h][iCounterB[h]];
         dRing11A[h][iCounterB[h]] = dVv;

         if (iCycleLimit[h] > 10) dHighValue = dCycleDelta[h] / 10;
         else                     dHighValue = dCycleDelta[h] / iCycleLimit[h];

         if (iCycleLimit[h] > 127) {
            dS10 = dList128B[h][iCounterA[h]];
            dList128B[h][iCounterA[h]] = dHighValue;
            iS68 = 64;
            iS58 = iS68;

            while (iS68 > 1) {
               if (dList128A[h][iS58] < dS10) {
                  iS68 = iS68 * 0.5;
                  iS58 = iS58 + iS68;
               }
               else if (dList128A[h][iS58] <= dS10)
                  iS68 = 1;
               else {
                  iS68 = iS68 * 0.5;
                  iS58 = iS58 - iS68;
               }
            }
         }
         else {
            dList128B[h][iCounterA[h]] = dHighValue;
            if  (iS28[h]+iS30[h] > 127) {
               iS30[h] = iS30[h] - 1;
               iS58 = iS30[h];
            }
            else {
               iS28[h] = iS28[h] + 1;
               iS58 = iS28[h];
            }
            if (iS28[h] > 96) iS38[h] = 96;
            else              iS38[h] = iS28[h];
            if (iS30[h] < 32) iS40[h] = 32;
            else              iS40[h] = iS30[h];
         }

         iS68 = 64;
         iS60 = iS68;

         while (iS68 > 1) {
            if (dList128A[h][iS60] >= dHighValue) {
               if (dList128A[h][iS60-1] <= dHighValue) {
                  iS68 = 1;
               }
               else {
                  iS68 = iS68 * 0.5;
                  iS60 = iS60 - iS68;
               }
            }
            else {
               iS68 = iS68 * 0.5;
               iS60 = iS60 + iS68;
            }
            if (iS60==127 && dHighValue > dList128A[h][127])
               iS60 = 128;
         }

         if (iCycleLimit[h] > 127) {
            if (iS58 >= iS60) {
               if      (iS38[h]+1 > iS60 && iS40[h]-1 < iS60) dS18[h] = dS18[h] + dHighValue;
               else if (iS40[h]   > iS60 && iS40[h]-1 < iS58) dS18[h] = dS18[h] + dList128A[h][iS40[h]-1];
            }
            else if (iS40[h] >= iS60) {
               if (iS38[h]+1 < iS60 && iS38[h]+1 > iS58)      dS18[h] = dS18[h] + dList128A[h][iS38[h]+1];
            }
            else if (iS38[h]+2 > iS60)                        dS18[h] = dS18[h] + dHighValue;
            else if (iS38[h]+1 < iS60 && iS38[h]+1 > iS58)    dS18[h] = dS18[h] + dList128A[h][iS38[h]+1];

            if (iS58 > iS60) {
               if      (iS40[h]-1 < iS58 && iS38[h]+1 > iS58) dS18[h] = dS18[h] - dList128A[h][iS58];
               else if (iS38[h]   < iS58 && iS38[h]+1 > iS60) dS18[h] = dS18[h] - dList128A[h][iS38[h]];
            }
            else if (iS38[h]+1 > iS58 && iS40[h]-1 < iS58)    dS18[h] = dS18[h] - dList128A[h][iS58];
            else if (iS40[h]   > iS58 && iS40[h]   < iS60)    dS18[h] = dS18[h] - dList128A[h][iS40[h]];
         }

         if (iS58 <= iS60) {
            if (iS58 >= iS60) {
               dList128A[h][iS60] = dHighValue;
            }
            else {
               for (int j=iS58+1; j <= iS60-1; j++) dList128A[h][j-1] = dList128A[h][j];
               dList128A[h][iS60-1] = dHighValue;
            }
         }
         else {
            for (j=iS58-1; j >= iS60; j--) dList128A[h][j+1] = dList128A[h][j];
            dList128A[h][iS60] = dHighValue;
         }

         if (iCycleLimit[h] <= 127) {
            dS18[h] = 0;
            for (j=iS40[h]; j <= iS38[h]; j++) dS18[h] = dS18[h] + dList128A[h][j];
         }
         dF60 = dS18[h] / (iS38[h]-iS40[h]+1);

         if (iLp2[h]+1 > 31) iLp2[h] = 31;
         else                iLp2[h] = iLp2[h] + 1;

         if (iLp2[h] <= 30) {
            if (dSDiffParamA > 0) dParamA[h] = dSValue;
            else                  dParamA[h] = dSValue - dSDiffParamA * dF90[h];
            if (dSDiffParamB < 0) dParamB[h] = dSValue;
            else                  dParamB[h] = dSValue - dSDiffParamB * dF90[h];
            dJMA[h] = dPrice;

            if (iLp2[h] != 30)
               continue;

            if (iLp2[h] == 30) {
               dFc0[h] = dPrice;
               if (MathCeil(dF78[h]) >= 1) dV4 = MathCeil(dF78[h]);
               else                        dV4 = 1;

               if      (dV4 > 0) iFe8 = MathFloor(dV4);
               else if (dV4 < 0) iFe8 = MathCeil(dV4);
               else              iFe8 = 0;

               if (MathFloor(dF78[h]) >= 1) dV2[h] = MathFloor(dF78[h]);
               else                         dV2[h] = 1;

               if      (dV2[h] > 0) iFe0 = MathFloor(dV2[h]);
               else if (dV2[h] < 0) iFe0 = MathCeil(dV2[h]);
               else                 iFe0 = 0;

               if (iFe8 == iFe0) dF68 = 1;
               else {
                  dV4  = iFe8 - iFe0;
                  dF68 = (dF78[h]-iFe0) / dV4;
               }

               if (iFe0 <= 29) iV5 = iFe0;
               else            iV5 = 29;

               if (iFe8 <= 29) iV6 = iFe8;
               else            iV6 = 29;

               dFa8[h] = (dPrice-dPrices62[h][iLoopParam[h]-iV5]) * (1-dF68) / iFe0 + (dPrice-dPrices62[h][iLoopParam[h]-iV6]) * dF68 / iFe8;
            }
         }
         else {
            if (dF98[h] >= MathPow(dFa0/dF60, dF88[h])) dV1[h] = MathPow(dFa0/dF60, dF88[h]);
            else                                        dV1[h] = dF98[h];

            if (dV1[h] < 1) {
               dV2[h] = 1;
            }
            else {
               if (dF98[h] >= MathPow(dFa0/dF60, dF88[h])) dV3[h] = MathPow(dFa0/dF60, dF88[h]);
               else                                        dV3[h] = dF98[h];
               dV2[h] = dV3[h];
            }
            dF58 = dV2[h];
            dF70 = MathPow(dF90[h], MathSqrt(dF58));

            if (dSDiffParamA > 0) dParamA[h] = dSValue;
            else                  dParamA[h] = dSValue - dSDiffParamA * dF70;
            if (dSDiffParamB < 0) dParamB[h] = dSValue;
            else                  dParamB[h] = dSValue - dSDiffParamB * dF70;
         }
      }

      if (iLp2[h] > 30) {
         dF30    = MathPow(dKg[h], dF58);
         dFc0[h] = (1-dF30) * dPrice + dF30 * dFc0[h];
         dFc8[h] = (dPrice-dFc0[h]) * (1-dKg[h]) + dKg[h] * dFc8[h];
         dFd0    = dPf[h] * dFc8[h] + dFc0[h];
         dF20    = -2 * dF30;
         dF40    = dF30 * dF30;
         dFb0    = dF20 + dF40 + 1;
         dFa8[h] = (dFd0-dJMA[h]) * dFb0 + dF40 * dFa8[h];
         dJMA[h] = dJMA[h] + dFa8[h];
      }
   }
   if (iLoopParam[h] <= 30)
      dJMA[h] = 0;

   if (!catch("JJMASeries(4)  h="+ h))
      return(dJMA[h]);
   return(0);
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
bool JJMASeries.InitBuffers(int size, double dJMA[], double &dList128A[][], double dList128B[][], double dList128C[][], double dList128D[][], double dList128E[][], double dRing11A[][],
                                      double dRing11B[][], double dMem8[][], double dPrices62[][], double dKg[], double dPf[], double dParamA[], double dParamB[], double dFa8[], double dFc0[],
                                      double dFc8[], double dCycleDelta[], double dS18[], double dV1[], double dV2[], double dV3[], double dF90[], double dF78[], double dF88[], double dF98[],
                                      int iMem7[][], int iMem11[][], int &iS28[], int &iS30[], int iCounterA[], int iS38[], int iS40[], int iCounterB[], int iCycleLimit[], int iLoopParam[], int iLp2[], int &iF0[],
                                      datetime iDatetime[]) {
   if (size < 0) return(!catch("JJMASeries.InitBuffers(1)  invalid parameter size: "+ size +" (must be non-negative)", ERR_INVALID_PARAMETER));

   int oldSize = ArrayRange(dJMA, 0);

   if (!size || size > oldSize) {
      ArrayResize(dJMA,        size);
      ArrayResize(dList128A,   size);
      ArrayResize(dList128B,   size);
      ArrayResize(dRing11A,    size);
      ArrayResize(dPrices62,   size);
      ArrayResize(dMem8,       size);
      ArrayResize(iMem7,       size);
      ArrayResize(iMem11,      size);
      ArrayResize(dList128C,   size);
      ArrayResize(dList128E,   size);
      ArrayResize(dList128D,   size);
      ArrayResize(dRing11B,    size);
      ArrayResize(dKg,         size);
      ArrayResize(dPf,         size);
      ArrayResize(dParamA,     size);
      ArrayResize(dParamB,     size);
      ArrayResize(dFa8,        size);
      ArrayResize(dFc0,        size);
      ArrayResize(dFc8,        size);
      ArrayResize(dCycleDelta, size);
      ArrayResize(dS18,        size);
      ArrayResize(iCounterB,   size);
      ArrayResize(iCycleLimit, size);
      ArrayResize(iLp2,        size);
      ArrayResize(iLoopParam,  size);
      ArrayResize(iS38,        size);
      ArrayResize(iS40,        size);
      ArrayResize(iCounterA,   size);
      ArrayResize(dV1,         size);
      ArrayResize(dV2,         size);
      ArrayResize(dV3,         size);
      ArrayResize(dF90,        size);
      ArrayResize(dF78,        size);
      ArrayResize(dF88,        size);
      ArrayResize(dF98,        size);
      ArrayResize(iS28,        size);
      ArrayResize(iS30,        size);
      ArrayResize(iF0,         size);
      ArrayResize(iDatetime,   size);
   }
   if (size <= oldSize) return(!catch("JJMASeries.InitBuffers(2)"));

   for (int i=oldSize; i < size; i++) {
      iF0 [i] =  1;
      iS28[i] = 63;
      iS30[i] = 64;

      for (int j=0; j <=  63; j++) dList128A[i][j] = -1000000;
      for (j=64;    j <= 127; j++) dList128A[i][j] = +1000000;
   }
   return(!catch("JJMASeries.InitBuffers(3)"));
}



