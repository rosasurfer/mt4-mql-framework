/**
 * JJMASeries - a function to calculate the JMA (Jurik Moving Average) of one or more timeseries
 *
 *
 * This function is a rewrite of the MQL4 port of the TradeStation JMA of 1998 by Nikolay Kositsin. This version fixes some
 * bugs and the most disturbing design and usage issues. Especially it removes all global variables and the need of additional
 * helper functions.
 *
 * @see     http://www.jurikres.com/catalog1/ms_ama.htm                    [Jurik Moving Average, Jurik Research]
 * @see     "/etc/doc/jurik/Jurik Research Product Guide [2015.09].pdf"
 * @source  https://www.mql5.com/en/articles/1450                          [NK_library, Nikolay Kositsin]
 */
double dList128A[1][128], dList128B[1][128], dList128C[1][128], dList128D[1][128], dList128E[1][128];
double dRing11A[1][11], dRing11B[1][11];
double dBuffer62[1][62];
double dMem8[1][8];

double dF18[1], dF38[1], dFa8[1], dFc0[1], dFc8[1], dS8[1], dS18[1], dV1[1], dV2[1], dV3[1];
double dF90[1], dF78[1], dF88[1], dF98[1], dJma[1], dKg[1], dPf[1];

double dFa0, dVv, dV4, dF70, dS20, dS10, dFb0, dFd0, dF8, dF60, dF20, dF28, dF30, dF40, dF48, dF58, dF68;

int    iMem7[1][7], iMem11[1][11];

int    iS28[1], iS30[1], iS38[1], iS40[1], iS48[1], iF0[1], iS50[1], iS70[1], iLp1[1], iLp2[1], iDatetime[1];

int    iV5, iV6, iFe0, iFd8, iFe8, iVal, iS58, iS60, iS68, iAa, iSize, iIi, iJj, iM, iN, iTnew, iTold, iError, iResize;


/**
 * Before the first call of the function (when the number of calculated bars is still 0) you must resize the internal buffer
 * variables according to the number of JMA price series you intend to calculate by calling JJMASeriesResize().
 * ---
 *
 *
 * The function does not work if the parameter nJMA.limit takes a value of zero.
 *
 * If nJMA.bar is larger than nJMA.MaxBar, then the function returns a value of zero on this bar. And therefore, such a
 * meaning cannot be present in the denominator of any fraction in the calculation of the indicator.
 *
 *
 * @param  _In_  int    iNumber - The sequence number of the function call (0, 1, 2, 3, etc. ...)
 * @param  _In_  int    iDin    - allows to change the iPeriods and iPhase parameters on each bar. 0 - change prohibition parameters,
 *                                any other value is resolution (see indicators "Lines/AMAJ.mq4" and "Lines/AMAJ2.mq4")
 * @param  _In_  int    MaxBar  - The maximum value that the calculated bar number (iBar) can take. Usually equals Bars-1-periods
 *                                where "period" is the number of bars on which the dJMA.series is not calculated.
 * @param  _In_  int    limit   - The number of bars not yet counted plus one or the number of the last uncounted bar. Must be
 *                                equal to Bars-IndicatorCounted()-1.
 * @param  _In_  int    Length  - smoothing period
 * @param  _In_  int    Phase   - varies between -100 ... +100 and affects the quality of the transition process
 * @param  _In_  double dPrice  - price for which the indicator value is calculated
 * @param  _In_  int    iBar    - Number of the bar to calculate counting downwards to zero. Its maximum value should always be
 *                                equal to the value of the parameter limit.
 * @param  _Out_ int    error   - variable receiving any errors occurred during the calculation
 *
 * @return double - JMA value or NULL if iBar is greater than nJMA.MaxBar-30
 */
double JJMASeries(int iNumber, int iDin, int iOldestBar, int iStartBar, int iPhase, int iPeriods, double dPrice, int iBar, int &error) {
   iN = iNumber;
   error = 1;

   // Проверки на ошибки
   if (iBar == iStartBar) {
      // проверка на инициализацию функции JJMASeries()
      if (iResize < 1) {
         Print("JJMASeries number ="+ iN +". Не было сделано изменение размеров буферных переменных функцией JJMASeriesResize()");
         if (iResize == 0) Print("JJMASeries number ="+ iN +". Следует дописать обращение к функции JJMASeriesResize() в блок инициализации");
         return(0);
      }

      // проверка на ошибку в исполнении программного кода, предшествовавшего функции JJMASeries()
      iError = GetLastError();
      if (iError > 4000) {
         Print("JJMASeries number ="+ iN +". В коде, предшествующем обращению к функции JJMASeries() number = "+ iN +" ошибка!!!");
         Print("JJMASeries number ="+ iN + ". ", ErrorToStr(iError));
      }

      // проверка на ошибку в задании переменных iNumber и nJMAResize.Number
      iSize = ArraySize(dJma);
      if (iSize < iN) {
         Print("JJMASeries number ="+ iN +". Ошибка!!! Неправильно задано значение переменной iNumber="+ iN +" функции JJMASeries()");
         Print("JJMASeries number ="+ iN +". Или неправильно задано значение  переменной nJJMAResize.Size="+ iSize +" функции JJMASeriesResize()");
         return(0);
      }
   }

   // проверка на ошибку в последовательности изменения переменной iBar
   if (iStartBar>=iOldestBar && !iBar && iOldestBar>30 && !iDatetime[iN]) {
      Print("JJMASeries number ="+ iN +". Ошибка!!! Нарушена правильная последовательность изменения параметра iBar внешним оператором цикла!!!");
   }

   if (iBar > iOldestBar) {
      error = NO_ERROR;
      return(0);
   }

   if (iBar==iOldestBar || iDin) {
      // Расчёт коэффициентов
      double dS, dL;

      if (iPeriods < 1.0000000002) double dR = 0.0000000001;
      else                                dR = (iPeriods-1)/2.;

      if (iPhase>=-100 && iPhase<=100) dPf[iN] = iPhase/100. + 1.5;

      if (iPhase > +100) dPf[iN] = 2.5;
      if (iPhase < -100) dPf[iN] = 0.5;

      dR = dR * 0.9;
      dKg[iN] = dR/(dR + 2.0);
      dS = MathSqrt(dR);
      dL = MathLog(dS);
      dV1[iN] = dL;
      dV2[iN] = dV1[iN];

      if (dV1[iN]/MathLog(2) + 2 < 0) dV3[iN] = 0;
      else                            dV3[iN] = dV2[iN]/MathLog(2) + 2;

      dF98[iN] = dV3[iN];

      if (dF98[iN] >= 2.5) dF88[iN] = dF98[iN] - 2;
      else                 dF88[iN] = 0.5;

      dF78[iN] = dS * dF98[iN];
      dF90[iN] = dF78[iN] / (dF78[iN] + 1);
   }

   if (iBar==iStartBar && iStartBar < iOldestBar) {
      // Восстановление значений переменных
      iTnew = Time[iStartBar+1];
      iTold = iDatetime[iN];

      if (iTnew == iTold) {
         for (iAa=127; iAa >= 0; iAa--) dList128A[iN][iAa] = dList128E[iN][iAa];
         for (iAa=127; iAa >= 0; iAa--) dList128B[iN][iAa] = dList128D[iN][iAa];
         for (iAa=10;  iAa >= 0; iAa--) dRing11A [iN][iAa] = dRing11B [iN][iAa];

         dFc0[iN] = dMem8[iN][0]; dFc8[iN] = dMem8[iN][1]; dFa8[iN] = dMem8[iN][2];
         dS8 [iN] = dMem8[iN][3]; dF18[iN] = dMem8[iN][4]; dF38[iN] = dMem8[iN][5];
         dS18[iN] = dMem8[iN][6]; dJma[iN] = dMem8[iN][7]; iS38[iN] = iMem7[iN][0];
         iS48[iN] = iMem7[iN][1]; iS50[iN] = iMem7[iN][2]; iLp1[iN] = iMem7[iN][3];
         iLp2[iN] = iMem7[iN][4]; iS40[iN] = iMem7[iN][5]; iS70[iN] = iMem7[iN][6];
      }

      // проверка на ошибки
      if (iTnew != iTold) {
         error=-1;
         // индикация ошибки в расчёте входного параметра iStartBar функции JJMASeries()
         if (iTnew > iTold) {
            Print("JJMASeries number ="+ iN +". Ошибка!!! Параметр iStartBar функции JJMASeries() меньше, чем необходимо");
         }
         else {
            int iLimitERROR = iStartBar +1 -iBarShift(NULL, 0, iTold, true);
            Print("JMASerries number ="+ iN +". Ошибка!!! Параметр iStartBar функции JJMASeries() больше, чем необходимо на "+ iLimitERROR);
         }
         // Возврат через error=-1; ошибки в расчёте функции JJMASeries
         return(0);
      }
   }

   if (iBar == 1) {
      if (iStartBar!=1 || Time[iStartBar+2]==iDatetime[iN]) {
         // Сохранение значений переменных
         for (iAa=127; iAa >= 0; iAa--) dList128E[iN][iAa] = dList128A[iN][iAa];
         for (iAa=127; iAa >= 0; iAa--) dList128D[iN][iAa] = dList128B[iN][iAa];
         for (iAa=10;  iAa >= 0; iAa--) dRing11B [iN][iAa] = dRing11A [iN][iAa];

         dMem8[iN][0] = dFc0[iN]; dMem8[iN][1] = dFc8[iN]; dMem8[iN][2] = dFa8[iN];
         dMem8[iN][3] = dS8 [iN]; dMem8[iN][4] = dF18[iN]; dMem8[iN][5] = dF38[iN];
         dMem8[iN][6] = dS18[iN]; dMem8[iN][7] = dJma[iN]; iMem7[iN][0] = iS38[iN];
         iMem7[iN][1] = iS48[iN]; iMem7[iN][2] = iS50[iN]; iMem7[iN][3] = iLp1[iN];
         iMem7[iN][4] = iLp2[iN]; iMem7[iN][5] = iS40[iN]; iMem7[iN][6] = iS70[iN];
         iDatetime[iN] = Time[2];
      }
   }

   if (iLp1[iN] < 61) {
      iLp1[iN]++;
      dBuffer62[iN][iLp1[iN]] = dPrice;
   }

   if (iLp1[iN] > 30) {
      if (iF0[iN] != 0) {
         iF0[iN] = 0;
         iV5 = 1;
         iFd8 = iV5 * 30;
         if (iFd8 == 0) dF38[iN] = dPrice;
         else           dF38[iN] = dBuffer62[iN][1];
         dF18[iN] = dF38[iN];
         if (iFd8 > 29) iFd8 = 29;
      }
      else iFd8 = 0;

      for (iIi=iFd8; iIi >= 0; iIi--) {
         iVal = 31 - iIi;
         if (iIi == 0) dF8 = dPrice;
         else          dF8 = dBuffer62[iN][iVal];

         dF28 = dF8 - dF18[iN];
         dF48 = dF8 - dF38[iN];

         if (MathAbs(dF28) > MathAbs(dF48)) dV2[iN] = MathAbs(dF28);
         else                               dV2[iN] = MathAbs(dF48);

         dFa0 = dV2[iN];
         dVv = dFa0 + 0.0000000001;

         if (iS48[iN] <= 1) iS48[iN] = 127;
         else               iS48[iN]--;

         if (iS50[iN] <= 1) iS50[iN] = 10;
         else               iS50[iN]--;

         if (iS70[iN] < 128) iS70[iN]++;

         dS8[iN] = dS8[iN] + dVv - dRing11A[iN][iS50[iN]];
         dRing11A[iN][iS50[iN]] = dVv;

         if (iS70[iN] > 10) dS20 = dS8[iN] / 10;
         else               dS20 = dS8[iN] / iS70[iN];

         if (iS70[iN] > 127) {
            dS10 = dList128B[iN][iS48[iN]];
            dList128B[iN][iS48[iN]] = dS20;
            iS68 = 64;
            iS58 = iS68;

            while (iS68 > 1) {
               if (dList128A[iN][iS58] < dS10) {
                  iS68 = iS68 *0.5;
                  iS58 = iS58 + iS68;
               }
               else if (dList128A[iN][iS58] <= dS10)
                  iS68 = 1;
               else {
                  iS68 = iS68 *0.5;
                  iS58 = iS58 - iS68;
               }
            }
         }
         else {
            dList128B[iN][iS48[iN]] = dS20;
            if  (iS28[iN]+iS30[iN] > 127) {
               iS30[iN] = iS30[iN] - 1;
               iS58 = iS30[iN];
            }
            else {
               iS28[iN] = iS28[iN] + 1;
               iS58 = iS28[iN];
            }
            if (iS28[iN] > 96) iS38[iN] = 96;
            else               iS38[iN] = iS28[iN];
            if (iS30[iN] < 32) iS40[iN] = 32;
            else               iS40[iN] = iS30[iN];
         }
// formatted
iS68 = 64; iS60 = iS68;
while (iS68 > 1)
{
if (dList128A[iN][iS60] >= dS20)
{
if (dList128A[iN][iS60 - 1] <= dS20) iS68 = 1; else {iS68 = iS68 *0.5; iS60 = iS60 - iS68; }
}
else{iS68 = iS68 *0.5; iS60 = iS60 + iS68;}
if ((iS60 == 127) && (dS20 > dList128A[iN][127])) iS60 = 128;
}
if (iS70[iN] > 127)
{
if (iS58 >= iS60)
{
if ((iS38[iN] + 1 > iS60) && (iS40[iN] - 1 < iS60)) dS18[iN] = dS18[iN] + dS20;
else
if ((iS40[iN] + 0 > iS60) && (iS40[iN] - 1 < iS58)) dS18[iN]
= dS18[iN] + dList128A[iN][iS40[iN] - 1];
}
else
if (iS40[iN] >= iS60) {if ((iS38[iN] + 1 < iS60) && (iS38[iN] + 1 > iS58)) dS18[iN]
= dS18[iN] + dList128A[iN][iS38[iN] + 1]; }
else if  (iS38[iN] + 2 > iS60) dS18[iN] = dS18[iN] + dS20;
else if ((iS38[iN] + 1 < iS60) && (iS38[iN] + 1 > iS58)) dS18[iN]
= dS18[iN] + dList128A[iN][iS38[iN] + 1];
if (iS58 > iS60)
{
if ((iS40[iN] - 1 < iS58) && (iS38[iN] + 1 > iS58)) dS18[iN] = dS18[iN] - dList128A[iN][iS58];
else
if ((iS38[iN]     < iS58) && (iS38[iN] + 1 > iS60)) dS18[iN] = dS18[iN] - dList128A[iN][iS38[iN]];
}
else
{
if ((iS38[iN] + 1 > iS58) && (iS40[iN] - 1 < iS58)) dS18[iN] = dS18[iN] - dList128A[iN][iS58];
else
if ((iS40[iN] + 0 > iS58) && (iS40[iN] - 0 < iS60)) dS18[iN] = dS18[iN] - dList128A[iN][iS40[iN]];
}
}
if (iS58 <= iS60)
{
if (iS58 >= iS60)
{
dList128A[iN][iS60] = dS20;
}
else
{
for( iJj = iS58 + 1; iJj<=iS60 - 1 ;iJj++)dList128A[iN][iJj - 1] = dList128A[iN][iJj];
dList128A[iN][iS60 - 1] = dS20;
}
}
else
{
for( iJj = iS58 - 1; iJj>=iS60 ;iJj--) dList128A[iN][iJj + 1] = dList128A[iN][iJj];
dList128A[iN][iS60] = dS20;
}
if (iS70[iN] <= 127)
{
dS18[iN] = 0;
for( iJj = iS40[iN] ; iJj<=iS38[iN] ;iJj++) dS18[iN] = dS18[iN] + dList128A[iN][iJj];
}
dF60 = dS18[iN] / (iS38[iN] - iS40[iN] + 1.0);
if (iLp2[iN] + 1 > 31) iLp2[iN] = 31; else iLp2[iN] = iLp2[iN] + 1;
if (iLp2[iN] <= 30)
{
if (dF28 > 0.0) dF18[iN] = dF8; else dF18[iN] = dF8 - dF28 * dF90[iN];
if (dF48 < 0.0) dF38[iN] = dF8; else dF38[iN] = dF8 - dF48 * dF90[iN];
dJma[iN] = dPrice;
if (iLp2[iN]!=30) continue;
if (iLp2[iN]==30)
{
dFc0[iN] = dPrice;
if ( MathCeil(dF78[iN]) >= 1) dV4 = MathCeil(dF78[iN]); else dV4 = 1.0;

if(dV4>0)iFe8 = MathFloor(dV4);else{if(dV4<0)iFe8 = MathCeil (dV4);else iFe8 = 0.0;}

if (MathFloor(dF78[iN]) >= 1) dV2[iN] = MathFloor(dF78[iN]); else dV2[iN] = 1.0;

if(dV2[iN]>0)iFe0 = MathFloor(dV2[iN]);else{if(dV2[iN]<0)iFe0 = MathCeil (dV2[iN]);else iFe0 = 0.0;}

if (iFe8== iFe0) dF68 = 1.0; else {dV4 = iFe8 - iFe0; dF68 = (dF78[iN] - iFe0) / dV4;}
if (iFe0 <= 29) iV5 = iFe0; else iV5 = 29;
if (iFe8 <= 29) iV6 = iFe8; else iV6 = 29;
dFa8[iN] = (dPrice - dBuffer62[iN][iLp1[iN] - iV5]) * (1.0 - dF68) / iFe0 + (dPrice
- dBuffer62[iN][iLp1[iN] - iV6]) * dF68 / iFe8;
}
}
else
{
if (dF98[iN] >= MathPow(dFa0/dF60, dF88[iN])) dV1[iN] = MathPow(dFa0/dF60, dF88[iN]);
else dV1[iN] = dF98[iN];
if (dV1[iN] < 1.0) dV2[iN] = 1.0;
else
{if(dF98[iN] >= MathPow(dFa0/dF60, dF88[iN])) dV3[iN] = MathPow(dFa0/dF60, dF88[iN]);
else dV3[iN] = dF98[iN]; dV2[iN] = dV3[iN];}
dF58 = dV2[iN]; dF70 = MathPow(dF90[iN], MathSqrt(dF58));
if (dF28 > 0.0) dF18[iN] = dF8; else dF18[iN] = dF8 - dF28 * dF70;
if (dF48 < 0.0) dF38[iN] = dF8; else dF38[iN] = dF8 - dF48 * dF70;
}
}
if (iLp2[iN] >30)
{
dF30 = MathPow(dKg[iN], dF58);
dFc0[iN] =(1.0 - dF30) * dPrice + dF30 * dFc0[iN];
dFc8[iN] =(dPrice - dFc0[iN]) * (1.0 - dKg[iN]) + dKg[iN] * dFc8[iN];
dFd0 = dPf[iN] * dFc8[iN] + dFc0[iN];
dF20 = dF30 *(-2.0);
dF40 = dF30 * dF30;
dFb0 = dF20 + dF40 + 1.0;
dFa8[iN] =(dFd0 - dJma[iN]) * dFb0 + dF40 * dFa8[iN];
dJma[iN] = dJma[iN] + dFa8[iN];
}
}

if (iLp1[iN] <=30)dJma[iN]=0.0;

//----++ проверка на ошибку в исполнении программного кода функции JJMASeries()
iError=GetLastError();
if(iError>4000)
  {
    Print("JJMASeries number ="+iN+". При исполнении функции JJMASeries() произошла ошибка!!!");
    Print("JJMASeries number ="+iN+ ". ", ErrorToStr(iError));
    return(0.0);
  }

error=0;
return(dJma[iN]);

   // suppress compiler warnings
   JJMASeriesAlert(NULL, NULL, NULL);
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
   if (size < 1) {
      iResize = -1;
      return(!catch("JJMASeriesResize(1)  invalid parameter size = "+ size +" (must be positive)", ERR_INVALID_PARAMETER));
   }

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

   if (IsError(catch("JJMASeriesResize(2)"))) {
      iResize = -2;
      return(false);
   }

   iResize = size;
   return(true);
}


/**
 *
 */
void JJMASeriesAlert(int id, string name, int value) {
   switch (id) {
      case 0: if (value < 1)                   Alert("Параметр "+ name +" должен быть не менее 1 Вы ввели недопустимое "+ value +" будет использовано 1");         break;
      case 1: if (value < -100 || value > 100) Alert("Параметр "+ name +" должен быть от -100 до +100 Вы ввели недопустимое "+ value +" будет использовано -100"); break;
   }
}
