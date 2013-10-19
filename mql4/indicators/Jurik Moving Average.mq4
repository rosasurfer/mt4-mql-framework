/**
 * Jurik Moving Average
 *
 * @link  http://www.jurikres.com/catalog/ms_ama.htm
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <stdlib.mqh>

//////////////////////////////////////////////////////////////////////////////// Konfiguration ////////////////////////////////////////////////////////////////////////////////

extern int Len      =  14;
extern int phase    =   0;
extern int BarCount = 300;

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>

#property indicator_chart_window

#property indicator_buffers 1

#property indicator_color1  Red

double ExtMapBuffer1[];


/**
 *
 */
int onInit() {
   SetIndexBuffer(0, ExtMapBuffer1);
   SetIndexStyle (0, DRAW_LINE    );
   return(catch("onInit()"));
}


/**
 *
 */
int onTick() {
   int counted_bars = IndicatorCounted();

   bool   firstTime     = true;
   int    AccountedBars = 0;
   int    jj            = 0;
   int    ii            = 0;
   int    shift         = 0;
   double series        = 0;

   double vv  = 0;
   double v1  = 0;
   double v2  = 0;
   double v3  = 0;
   double v4  = 0;
   double s8  = 0;
   double s10 = 0;
   double s18 = 0;
   double s20 = 0;
   int    v5  = 0;
   int    v6  = 0;
   double s28 = 0;
   double s30 = 0;
   int    s38 = 0;
   int    s40 = 0;
   int    s48 = 0;
   int    s50 = 0;
   int    s58 = 0;
   int    s60 = 0;
   double s68 = 0;
   double s70 = 0;
   double f8  = 0;
   double f10 = 0;
   double f18 = 0;
   double f20 = 0;
   double f28 = 0;
   double f30 = 0;
   double f38 = 0;
   double f40 = 0;
   double f48 = 0;
   double f50 = 0;
   double f58 = 0;
   double f60 = 0;
   double f68 = 0;
   double f70 = 0;
   double f78 = 0;
   double f80 = 0;
   double f88 = 0;
   double f90 = 0;
   double f98 = 0;
   double fA0 = 0;
   double fA8 = 0;
   double fB0 = 0;
   double fB8 = 0;
   double fC0 = 0;
   double fC8 = 0;
   double fD0 = 0;
   double f0  = 0;
   double fD8 = 0;
   double fE0 = 0;
   double fE8 = 0;
   int    fF0 = 0;
   double fF8 = 0;

   int    value2   = 0;
   double JMA      = 0;
   double prevtime = 0;

   double list  [127];
   double ring1 [127];
   double ring2 [ 10];
   double buffer[ 61];

   ArrayInitialize(list,   0);
   ArrayInitialize(ring1,  0);
   ArrayInitialize(ring2,  0);
   ArrayInitialize(buffer, 0);

   if (firstTime) {
      AccountedBars = Bars-BarCount;
      firstTime     = false;
   }

   if (CurTime()-prevtime < 30)
      return(-1);
   prevtime = CurTime();


   s28 = 63;
   s30 = 64;
   for (ii=1; ii <= s28; ii++) {
      list[ii] = -1000000;
   }
   for (ii=s30; ii <= 127; ii++) {
      list[ii] = 1000000;
   }
   f0 = 1;


   for (shift=BarCount; shift >= 0; shift--) {
      series = Close[shift];
      if (fF0 < 61) {
         fF0        += 1;
         buffer[fF0] = series;
      }

      // main cycle
      if (fF0 > 30) {
         if (Len < 1.0000000002) f80 = 0.0000000001;     // 1.0e-10
         else                    f80 = (Len-1)/2.0;

         if      (phase < -100) f10 = 0.5;
         else if (phase >  100) f10 = 2.5;
         else                   f10 = phase/100 + 1.5;

         v1 = MathLog(MathSqrt(f80));
         v2 = v1;
         if (v1/MathLog(2)+2 < 0) v3 = 0;
         else                     v3 = v2/MathLog(2) + 2;

         f98 = v3;
         if (0.5 <= f98-2) f88 = f98 - 2;
         else              f88 = 0.5;

         f78  = MathSqrt(f80) * f98;
         f90  = f78/(f78 + 1);
         f80 *= 0.9;
         f50  = f80/(f80 + 2);

         if (f0 != 0) {
            f0 = 0;
            v5 = 0;
            for (ii=1; ii <= 29; ii++) {
               if (buffer[ii+1] != buffer[ii])
                  v5 = 1;
            }

            fD8 = 30 * v5;
            if (fD8 == 0) f38 = series;
            else          f38 = buffer[1];
            f18 = f38;
            if (fD8 > 29)
               fD8 = 29;
         }
         else {
            fD8 = 0;
         }

         // another bigcycle...
         for (ii=fD8; ii >= 0; ii--) {
            value2 = 31-ii;
            if (ii == 0) f8 = series;
            else         f8 = buffer[value2];

            f28 = f8 - f18;
            f48 = f8 - f38;
            if (MathAbs(f28) > MathAbs(f48)) v2 = MathAbs(f28);
            else                             v2 = MathAbs(f48);
            fA0 = v2;
            vv  = fA0 + 0.0000000001; // 1.0e-10

            if (s48 <= 1) s48 = 127;
            else          s48--;
            if (s50 <= 1) s50 = 10;
            else          s50--;
            if (s70 < 128)
               s70 += 1;

            s8 += vv - ring2[s50];
            ring2[s50] = vv;

            if (s70 > 10) s20 = s8/10;
            else          s20 = s8/s70;

            if (s70 > 127) {
               s10        = ring1[s48];
               ring1[s48] = s20;
               s68 = 64;
               s58 = s68;
               while (s68 > 1) {
                  if (list[s58] < s10) {
                     s68 *= 0.5;
                     s58 += s68;
                  }
                  else if (list[s58] > s10) {
                     s68 *= 0.5;
                     s58 -= s68;
                  }
                  else {
                     s68 = 1;
                  }
               }
            }
            else {
               ring1[s48] = s20;
               if (s28+s30 > 127) {
                  s30 -= 1;
                  s58  = s30;
               }
               else {
                  s28 += 1;
                  s58  = s28;
               }
               if (s28 > 96) s38 = 96;
               else          s38 = s28;
               if (s30 < 32) s40 = 32;
               else          s40 = s30;
            }

            s68 = 64;
            s60 = s68;

            while (s68 > 1) {
               if (list[s60] >= s20) {
                  if (list[s60-1] <= s20) {
                     s68 = 1;
                  }
                  else {
                     s68 *= 0.5;
                     s60 -= s68;
                  }
               }
               else {
                  s68 *= 0.5;
                  s60 += s68;
               }
               if (s60==127) /*&&*/ if (s20 > list[127])
                  s60 = 128;
            }

            if (s70 > 127) {
               if (s58 >= s60) {
                  if      (s38+1 > s60 && s40-1 < s60) s18 += s20;
                  else if (s40   > s60 && s40-1 < s58) s18 += list[s40-1];
               }
               else if (s40 >= s60) {
                  if      (s38+1 < s60 && s38+1 > s58) s18 += list[s38+1];
               }
               else if    (s38+2 > s60               ) s18 += s20;
               else if    (s38+1 < s60 && s38+1 > s58) s18 += list[s38+1];

               if (s58 > s60) {
                  if      (s40-1 < s58 && s38+1 > s58) s18 -= list[s58];
                  else if (s38   < s58 && s38+1 > s60) s18 -= list[s38];
               }
               else if    (s38+1 > s58 && s40-1 < s58) s18 -= list[s58];
               else if    (s40   > s58 && s40   < s60) s18 -= list[s40];
            }

            if (s58 <= s60) {
               if (s58 >= s60) {
                  list[s60] = s20;
               }
               else {
                  for (jj=s58+1; jj <= s60-1; jj++) {
                     list[jj-1] = list[jj];
                  }
                  list[s60-1] = s20;
               }
            }
            else {
               for (jj=s58-1; jj >= s60; jj--) {
                  list[jj+1] = list[jj];
               }
               list[s60] = s20;
            }

            if (s70 <= 127) {
               s18 = 0;
               for (jj=s40; jj <= s38; jj++) {
                  s18 += list[jj];
               }
            }
            f60 = s18/(s38 - s40 + 1);

            if (fF8+1 > 31) fF8  = 31;
            else            fF8 += 1;

            if (fF8 <= 30) {
               if (f28 > 0) f18 = f8;
               else         f18 = f8 - f28 * f90;

               if (f48 < 0) f38 = f8;
               else         f38 = f8 - f48 * f90;

               fB8 = series;
               if (fF8 != 30)
                  continue;

               if (fF8 == 30) {
                  fC0 = series;
                  if (MathCeil(f78) >= 1) v4 = MathCeil(f78);
                  else                    v4 = 1;
                  fE8 = MathCeil(v4);

                  if (MathFloor(f78) >= 1) v2 = MathFloor(f78);
                  else                     v2 = 1;
                  fE0 = MathCeil(v2);

                  if (fE8 == fE0) {
                     f68 = 1;
                  }
                  else {
                     v4  =  fE8 - fE0;
                     f68 = (f78 - fE0)/v4;
                  }
                  if (fE0 <= 29) v5 = fE0;
                  else           v5 = 29;
                  if (fE8 <= 29) v6 = fE8;
                  else           v6 = 29;

                  fA8 = (series-buffer[fF0-v5]) * (1-f68)/fE0 + (series-buffer[fF0-v6]) * f68/fE8;
               }
            }
            else {
               if (f98 >= MathPow(fA0/f60, f88)) v1 = MathPow(fA0/f60, f88);
               else                              v1 = f98;
               if (v1 < 1) {
                  v2 = 1;
               }
               else {
                  if (f98 >= MathPow(fA0/f60, f88)) v3 = MathPow(fA0/f60, f88);
                  else                              v3 = f98;
                  v2 = v3;
               }

               f58 = v2;
               f70 = MathPow(f90, MathSqrt(f58));

               if (f28 > 0) f18 = f8;
               else         f18 = f8 - f28 * f70;
               if (f48 < 0) f38 = f8;
               else         f38 = f8 - f48 * f70;
            }
         }

         if (fF8 > 30) {
            f30  = MathPow(f50, f58);
            fC0  = (1-f30)*series + f30*fC0;
            fC8  = (series-fC0) * (1-f50) + f50*fC8;
            fD0  = f10 * fC8 + fC0;
            f20  = -f30 * 2;
            f40  = f30 * f30;
            fB0  = f20 + f40 + 1;
            fA8  = (fD0 - fB8) * fB0 + f40 * fA8;
            fB8 += fA8;
         }
         JMA = fB8;
      }
      if (fF0 <= 30)
         JMA = 0;
      //debug("onTick()   JMA="+ NumberToStr(JMA, SubPipPriceFormat) +"  shift="+ shift);

      ExtMapBuffer1[shift] = JMA;

      if (shift > 0)
         AccountedBars++;
   }


   int error = GetLastError();
   if (error != NO_ERROR) {
      if (error != ERR_ARRAY_INDEX_OUT_OF_RANGE)
         return(catch("onTick(1)", error));
      log("onTick(2)", SetLastError(error));
   }
   return(error);
}

