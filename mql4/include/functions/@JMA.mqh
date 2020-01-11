
double dList128A[1][128], dList128B[1][128], dList128C[1][128], dList128D[1][128], dList128E[1][128];
double dRing11A[1][11], dRing11B[1][11];
double dBuffer62[1][62];
double dMem8[1][8];

double dF18[1], dF38[1], dFa8[1], dFc0[1], dFc8[1], dS8[1], dS18[1], dV1[1], dV2[1], dV3[1];
double dF90[1], dF78[1], dF88[1], dF98[1], dJma[1], dKg[1], dPf[1];

double dFa0, dVv, dV4, dF70, dS20, dS10, dFb0, dFd0, dF8, dF60, dF20, dF28, dF30, dF40, dF48, dF58, dF68;

int    iMem7[1][7], iMem11[1][11];

int    iS28[1], iS30[1], iS38[1], iS40[1], iS48[1], iF0[1], iS50[1], iS70[1], iLp1[1], iLp2[1], iDatetime[1];

int    iV5, iV6, iFe0, iFd8, iFe8, iVal, iS58, iS60, iS68, iIi, iJj;


/**
 * Calculate the JMA (Jurik Moving Average) of one or more timeseries.
 *
 * This function is a complete rewrite of the JMA algorithm as provided by Nikolay Kositsin. It fixes some bugs and the most
 * annoying design and usage issues. Especially all global variables and the need of additional helper functions are removed.
 *
 *
 *
 * The function does not work if the parameter nJMA.limit takes a value of zero.
 *
 * @param  int    h       - non-negative value (a pseudo handle) to separately address multiple parallel JMA calculations
 * @param  int    iDin    - allows to change the iPeriods and iPhase parameters on each bar. 0 - change prohibition parameters,
 *                          any other value is resolution (see indicators "Lines/AMAJ.mq4" and "Lines/AMAJ2.mq4")
 * @param  int    MaxBar  - The maximum value that the calculated bar number (iBar) can take. Usually equals Bars-1-periods
 *                          where "period" is the number of bars on which the dJMA.series is not calculated.
 * @param  int    limit   - The number of bars not yet counted plus one or the number of the last uncounted bar. Must be
 *                          equal to Bars-IndicatorCounted()-1.
 * @param  int    Length  - smoothing period
 * @param  int    Phase   - varies between -100 ... +100 and affects the quality of the transition process
 * @param  double dPrice  - price for which the indicator value is calculated
 * @param  int    iBar    - Number of the bar to calculate counting downwards to zero. Its maximum value should always be
 *                          equal to the value of the parameter limit.
 *
 * @return double - JMA value or NULL in case of errors                    TODO: or if iBar is greater than nJMA.MaxBar-30
 *
 *
 * @source  https://www.mql5.com/en/articles/1450
 */
double JJMASeries(int h, int iDin, int iOldestBar, int iStartBar, int iPhase, int iPeriods, double dPrice, int iBar) {
   // initialization checks
   if (iBar == iStartBar) {
      if (ArraySize(dJma) < h+1) return(!catch("JJMASeries("+ h +")  JMA calculation buffer "+ h +" not initialized", ERR_NOT_INITIALIZED_ARRAY));
   }

   // validate bar parameters
   if (iStartBar>=iOldestBar && !iBar && iOldestBar>30 && !iDatetime[h])
      warn("JJMASeries("+ h +")  invalid bar parameters", ERR_INVALID_PARAMETER);
   if (iBar > iOldestBar)
      return(0);

   // coefficient calculation
   if (iBar==iOldestBar || iDin) {
      double dS, dL;

      if (iPeriods < 1.0000000002) double dR = 0.0000000001;
      else                                dR = (iPeriods-1)/2.;

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
      else                            dV3[h] = dV2[h]/MathLog(2) + 2;

      dF98[h] = dV3[h];

      if (dF98[h] >= 2.5) dF88[h] = dF98[h] - 2;
      else                 dF88[h] = 0.5;

      dF78[h] = dS * dF98[h];
      dF90[h] = dF78[h] / (dF78[h] + 1);
   }

   if (iBar==iStartBar && iStartBar < iOldestBar) {
      // restore values
      datetime dtNew = Time[iStartBar+1];
      datetime dTold = iDatetime[h];
      if (dtNew != dTold) return(!catch("JMASerries("+ h +")  invalid parameter iStartBar = "+ iStartBar +" (too "+ ifString(dtNew > dTold, "small", "large") +")", ERR_INVALID_PARAMETER));

      for (int i=127; i >= 0; i--) dList128A[h][i] = dList128E[h][i];
      for (    i=127; i >= 0; i--) dList128B[h][i] = dList128D[h][i];
      for (    i=10;  i >= 0; i--) dRing11A [h][i] = dRing11B [h][i];

      dFc0[h] = dMem8[h][0]; dFc8[h] = dMem8[h][1]; dFa8[h] = dMem8[h][2];
      dS8 [h] = dMem8[h][3]; dF18[h] = dMem8[h][4]; dF38[h] = dMem8[h][5];
      dS18[h] = dMem8[h][6]; dJma[h] = dMem8[h][7]; iS38[h] = iMem7[h][0];
      iS48[h] = iMem7[h][1]; iS50[h] = iMem7[h][2]; iLp1[h] = iMem7[h][3];
      iLp2[h] = iMem7[h][4]; iS40[h] = iMem7[h][5]; iS70[h] = iMem7[h][6];
   }

   if (iBar == 1) {
      if (iStartBar!=1 || Time[iStartBar+2]==iDatetime[h]) {
         // store values
         for (i=127; i >= 0; i--) dList128E[h][i] = dList128A[h][i];
         for (i=127; i >= 0; i--) dList128D[h][i] = dList128B[h][i];
         for (i=10;  i >= 0; i--) dRing11B [h][i] = dRing11A [h][i];

         dMem8[h][0] = dFc0[h]; dMem8[h][1] = dFc8[h]; dMem8[h][2] = dFa8[h];
         dMem8[h][3] = dS8 [h]; dMem8[h][4] = dF18[h]; dMem8[h][5] = dF38[h];
         dMem8[h][6] = dS18[h]; dMem8[h][7] = dJma[h]; iMem7[h][0] = iS38[h];
         iMem7[h][1] = iS48[h]; iMem7[h][2] = iS50[h]; iMem7[h][3] = iLp1[h];
         iMem7[h][4] = iLp2[h]; iMem7[h][5] = iS40[h]; iMem7[h][6] = iS70[h];
         iDatetime[h] = Time[2];
      }
   }

   if (iLp1[h] < 61) {
      iLp1[h]++;
      dBuffer62[h][iLp1[h]] = dPrice;
   }

   if (iLp1[h] > 30) {
      if (iF0[h] != 0) {
         iF0[h] = 0;
         iV5 = 1;
         iFd8 = iV5 * 30;
         if (iFd8 == 0) dF38[h] = dPrice;
         else           dF38[h] = dBuffer62[h][1];
         dF18[h] = dF38[h];
         if (iFd8 > 29) iFd8 = 29;
      }
      else iFd8 = 0;

      for (iIi=iFd8; iIi >= 0; iIi--) {
         iVal = 31 - iIi;
         if (iIi == 0) dF8 = dPrice;
         else          dF8 = dBuffer62[h][iVal];

         dF28 = dF8 - dF18[h];
         dF48 = dF8 - dF38[h];

         if (MathAbs(dF28) > MathAbs(dF48)) dV2[h] = MathAbs(dF28);
         else                               dV2[h] = MathAbs(dF48);

         dFa0 = dV2[h];
         dVv = dFa0 + 0.0000000001;

         if (iS48[h] <= 1) iS48[h] = 127;
         else               iS48[h]--;

         if (iS50[h] <= 1) iS50[h] = 10;
         else               iS50[h]--;

         if (iS70[h] < 128) iS70[h]++;

         dS8[h] = dS8[h] + dVv - dRing11A[h][iS50[h]];
         dRing11A[h][iS50[h]] = dVv;

         if (iS70[h] > 10) dS20 = dS8[h] / 10;
         else               dS20 = dS8[h] / iS70[h];

         if (iS70[h] > 127) {
            dS10 = dList128B[h][iS48[h]];
            dList128B[h][iS48[h]] = dS20;
            iS68 = 64;
            iS58 = iS68;

            while (iS68 > 1) {
               if (dList128A[h][iS58] < dS10) {
                  iS68 = iS68 *0.5;
                  iS58 = iS58 + iS68;
               }
               else if (dList128A[h][iS58] <= dS10)
                  iS68 = 1;
               else {
                  iS68 = iS68 *0.5;
                  iS58 = iS58 - iS68;
               }
            }
         }
         else {
            dList128B[h][iS48[h]] = dS20;
            if  (iS28[h]+iS30[h] > 127) {
               iS30[h] = iS30[h] - 1;
               iS58 = iS30[h];
            }
            else {
               iS28[h] = iS28[h] + 1;
               iS58 = iS28[h];
            }
            if (iS28[h] > 96) iS38[h] = 96;
            else               iS38[h] = iS28[h];
            if (iS30[h] < 32) iS40[h] = 32;
            else               iS40[h] = iS30[h];
         }
// formatted
iS68 = 64; iS60 = iS68;
while (iS68 > 1)
{
if (dList128A[h][iS60] >= dS20)
{
if (dList128A[h][iS60 - 1] <= dS20) iS68 = 1; else {iS68 = iS68 *0.5; iS60 = iS60 - iS68; }
}
else{iS68 = iS68 *0.5; iS60 = iS60 + iS68;}
if ((iS60 == 127) && (dS20 > dList128A[h][127])) iS60 = 128;
}
if (iS70[h] > 127)
{
if (iS58 >= iS60)
{
if ((iS38[h] + 1 > iS60) && (iS40[h] - 1 < iS60)) dS18[h] = dS18[h] + dS20;
else
if ((iS40[h] + 0 > iS60) && (iS40[h] - 1 < iS58)) dS18[h]
= dS18[h] + dList128A[h][iS40[h] - 1];
}
else
if (iS40[h] >= iS60) {if ((iS38[h] + 1 < iS60) && (iS38[h] + 1 > iS58)) dS18[h]
= dS18[h] + dList128A[h][iS38[h] + 1]; }
else if  (iS38[h] + 2 > iS60) dS18[h] = dS18[h] + dS20;
else if ((iS38[h] + 1 < iS60) && (iS38[h] + 1 > iS58)) dS18[h]
= dS18[h] + dList128A[h][iS38[h] + 1];
if (iS58 > iS60)
{
if ((iS40[h] - 1 < iS58) && (iS38[h] + 1 > iS58)) dS18[h] = dS18[h] - dList128A[h][iS58];
else
if ((iS38[h]     < iS58) && (iS38[h] + 1 > iS60)) dS18[h] = dS18[h] - dList128A[h][iS38[h]];
}
else
{
if ((iS38[h] + 1 > iS58) && (iS40[h] - 1 < iS58)) dS18[h] = dS18[h] - dList128A[h][iS58];
else
if ((iS40[h] + 0 > iS58) && (iS40[h] - 0 < iS60)) dS18[h] = dS18[h] - dList128A[h][iS40[h]];
}
}
if (iS58 <= iS60)
{
if (iS58 >= iS60)
{
dList128A[h][iS60] = dS20;
}
else
{
for( iJj = iS58 + 1; iJj<=iS60 - 1 ;iJj++)dList128A[h][iJj - 1] = dList128A[h][iJj];
dList128A[h][iS60 - 1] = dS20;
}
}
else
{
for( iJj = iS58 - 1; iJj>=iS60 ;iJj--) dList128A[h][iJj + 1] = dList128A[h][iJj];
dList128A[h][iS60] = dS20;
}
if (iS70[h] <= 127)
{
dS18[h] = 0;
for( iJj = iS40[h] ; iJj<=iS38[h] ;iJj++) dS18[h] = dS18[h] + dList128A[h][iJj];
}
dF60 = dS18[h] / (iS38[h] - iS40[h] + 1.0);
if (iLp2[h] + 1 > 31) iLp2[h] = 31; else iLp2[h] = iLp2[h] + 1;
if (iLp2[h] <= 30)
{
if (dF28 > 0.0) dF18[h] = dF8; else dF18[h] = dF8 - dF28 * dF90[h];
if (dF48 < 0.0) dF38[h] = dF8; else dF38[h] = dF8 - dF48 * dF90[h];
dJma[h] = dPrice;
if (iLp2[h]!=30) continue;
if (iLp2[h]==30)
{
dFc0[h] = dPrice;
if ( MathCeil(dF78[h]) >= 1) dV4 = MathCeil(dF78[h]); else dV4 = 1.0;

if(dV4>0)iFe8 = MathFloor(dV4);else{if(dV4<0)iFe8 = MathCeil (dV4);else iFe8 = 0.0;}

if (MathFloor(dF78[h]) >= 1) dV2[h] = MathFloor(dF78[h]); else dV2[h] = 1.0;

if(dV2[h]>0)iFe0 = MathFloor(dV2[h]);else{if(dV2[h]<0)iFe0 = MathCeil (dV2[h]);else iFe0 = 0.0;}

if (iFe8== iFe0) dF68 = 1.0; else {dV4 = iFe8 - iFe0; dF68 = (dF78[h] - iFe0) / dV4;}
if (iFe0 <= 29) iV5 = iFe0; else iV5 = 29;
if (iFe8 <= 29) iV6 = iFe8; else iV6 = 29;
dFa8[h] = (dPrice - dBuffer62[h][iLp1[h] - iV5]) * (1.0 - dF68) / iFe0 + (dPrice
- dBuffer62[h][iLp1[h] - iV6]) * dF68 / iFe8;
}
}
else
{
if (dF98[h] >= MathPow(dFa0/dF60, dF88[h])) dV1[h] = MathPow(dFa0/dF60, dF88[h]);
else dV1[h] = dF98[h];
if (dV1[h] < 1.0) dV2[h] = 1.0;
else
{if(dF98[h] >= MathPow(dFa0/dF60, dF88[h])) dV3[h] = MathPow(dFa0/dF60, dF88[h]);
else dV3[h] = dF98[h]; dV2[h] = dV3[h];}
dF58 = dV2[h]; dF70 = MathPow(dF90[h], MathSqrt(dF58));
if (dF28 > 0.0) dF18[h] = dF8; else dF18[h] = dF8 - dF28 * dF70;
if (dF48 < 0.0) dF38[h] = dF8; else dF38[h] = dF8 - dF48 * dF70;
}
}
if (iLp2[h] >30)
{
dF30 = MathPow(dKg[h], dF58);
dFc0[h] =(1.0 - dF30) * dPrice + dF30 * dFc0[h];
dFc8[h] =(dPrice - dFc0[h]) * (1.0 - dKg[h]) + dKg[h] * dFc8[h];
dFd0 = dPf[h] * dFc8[h] + dFc0[h];
dF20 = dF30 *(-2.0);
dF40 = dF30 * dF30;
dFb0 = dF20 + dF40 + 1.0;
dFa8[h] =(dFd0 - dJma[h]) * dFb0 + dF40 * dFa8[h];
dJma[h] = dJma[h] + dFa8[h];
}
}

if (iLp1[h] <=30)dJma[h]=0.0;

   if (!catch("JJMASeries(" +h +")"))
      return(dJma[h]);
   return(0);

   // suppress compiler warnings
   JJMASeriesResize(NULL);
}


/**
 * Resize JMA buffers to allow parallel calculation of multiple JMA series. Must be called before the first call of
 * JJMASeries().
 *
 * @param  int size - amount of timeseries to calculate in parallel
 *
 * @return bool - success status
 */
bool JJMASeriesResize(int size) {
   if (size < 1) return(!catch("JJMASeriesResize(1)  invalid parameter size = "+ size +" (must be positive)", ERR_INVALID_PARAMETER));

   ArrayResize(dList128A, size);
   ArrayResize(dList128B, size);
   ArrayResize(dRing11A,  size);
   ArrayResize(dBuffer62, size);
   ArrayResize(dMem8,     size);
   ArrayResize(iMem7,     size);
   ArrayResize(iMem11,    size);
   ArrayResize(dList128C, size);
   ArrayResize(dList128E, size);
   ArrayResize(dList128D, size);
   ArrayResize(dRing11B,  size);
   ArrayResize(dKg,       size);
   ArrayResize(dPf,       size);
   ArrayResize(dF18,      size);
   ArrayResize(dF38,      size);
   ArrayResize(dFa8,      size);
   ArrayResize(dFc0,      size);
   ArrayResize(dFc8,      size);
   ArrayResize(dS8,       size);
   ArrayResize(dS18,      size);
   ArrayResize(dJma,      size);
   ArrayResize(iS50,      size);
   ArrayResize(iS70,      size);
   ArrayResize(iLp2,      size);
   ArrayResize(iLp1,      size);
   ArrayResize(iS38,      size);
   ArrayResize(iS40,      size);
   ArrayResize(iS48,      size);
   ArrayResize(dV1,       size);
   ArrayResize(dV2,       size);
   ArrayResize(dV3,       size);
   ArrayResize(dF90,      size);
   ArrayResize(dF78,      size);
   ArrayResize(dF88,      size);
   ArrayResize(dF98,      size);
   ArrayResize(iS28,      size);
   ArrayResize(iS30,      size);
   ArrayResize(iF0,       size);
   ArrayResize(iDatetime, size);

   ArrayInitialize(iF0,   1);
   ArrayInitialize(iS28, 63);
   ArrayInitialize(iS30, 64);

   ArrayInitialize(dList128A, -1000000);
   for (int i=0; i < size; i++) {
      for (int j=64; j <= 127; j++) dList128A[i][j] = +1000000;
   }

   return(!catch("JJMASeriesResize(2)"));
}
