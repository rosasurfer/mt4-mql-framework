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

double bufferJMA[];


/**
 *
 */
int onInit() {
   SetIndexBuffer(0, bufferJMA);
   SetIndexStyle (0, DRAW_LINE);
   return(catch("onInit()"));
}


/**
 *
 */
int onTick() {
   double d_vv  = 0;
   double d_v1  = 0;
   double d_v2  = 0;
   double d_v3  = 0;
   double d_v4  = 0;
   double d_s8  = 0;
   double d_s10 = 0;
   double d_s18 = 0;
   double d_s20 = 0;

   int    i_v5  = 0;
   int    i_v6  = 0;
   int    i_s38 = 0;
   int    i_s40 = 0;
   int    i_s48 = 0;
   int    i_s50 = 0;
   int    i_s58 = 0;
   int    i_s60 = 0;
   int    i_s68 = 0;
   int    i_s70 = 0;
   int    i_fF0 = 0;
   int    i_fD8 = 0;
   int    i_fF8 = 0;

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
   double fE0 = 0;
   double fE8 = 0;

   double price = 0;
   double JMA   = 0;

   double list  [127];
   double ring1 [127];
   double ring2 [ 10];
   double buffer[ 61];

   ArrayInitialize(list,   0);
   ArrayInitialize(ring1,  0);
   ArrayInitialize(ring2,  0);
   ArrayInitialize(buffer, 0);


   int i_s28 = 63, i_s30 = 64;
   for (int j, i=1; i <= i_s28; i++) {
      list[i] = -1000000;
   }
   for (i=i_s30; i <= 127; i++) {
      list[i] = +1000000;
   }


   if      (phase < -100) f10 = 0.5;
   else if (phase >  100) f10 = 2.5;
   else                   f10 = phase/100. + 1.5;

   bool b_f0 = true;


   for (int bar=BarCount; bar >= 0; bar--) {
      price = Close[bar];
      if (i_fF0 < 61) {
         i_fF0++;
         buffer[i_fF0] = price;
      }

      // main cycle
      if (i_fF0 > 30) {
         if (Len < 1.0000000002) f80 = 0.0000000001;
         else                    f80 = (Len-1)/2.0;

         d_v1 = MathLog(MathSqrt(f80));
         d_v2 = d_v1;
         d_v3 = d_v1/MathLog(2) + 2;
         if (d_v3 < 0)
            d_v3 = 0;

         f98 = d_v3;
         if (0.5 <= f98-2) f88 = f98 - 2;
         else              f88 = 0.5;

         f78  = MathSqrt(f80) * f98;
         f90  = f78/(f78 + 1);
         f80 *= 0.9;
         f50  = f80/(f80 + 2);

         if (b_f0) {
            b_f0 = false;
            i_v5  = 0;
            i_fD8 = 0;
            f38   = price;
            for (i=1; i <= 29; i++) {
               if (buffer[i+1] != buffer[i]) {
                  i_v5  = 1;
                  i_fD8 = 29;
                  f38   = buffer[1];
                  break;
               }
            }
            f18 = f38;
         }
         else {
            i_fD8 = 0;
         }

         // another big cycle...
         for (i=i_fD8; i >= 0; i--) {
            if (i == 0) f8 = price;
            else        f8 = buffer[31-i];

            f28 = f8 - f18;
            f48 = f8 - f38;
            if (MathAbs(f28) > MathAbs(f48)) d_v2 = MathAbs(f28);
            else                             d_v2 = MathAbs(f48);
            fA0 = d_v2;
            d_vv = fA0 + 0.0000000001;

            if (i_s48 <= 1) i_s48 = 127;
            else            i_s48--;
            if (i_s50 <= 1) i_s50 = 10;
            else            i_s50--;
            if (i_s70 < 128)
               i_s70++;

            d_s8        += d_vv - ring2[i_s50];
            ring2[i_s50] = d_vv;

            if (i_s70 > 10) d_s20 = d_s8/10;
            else            d_s20 = d_s8/i_s70;

            if (i_s70 > 127) {
               d_s10        = ring1[i_s48];
               ring1[i_s48] = d_s20;
               i_s68 = 64;
               i_s58 = i_s68;
               while (i_s68 > 1) {
                  if (list[i_s58] < d_s10) {
                     i_s68 >>= 1;
                     i_s58  += i_s68;
                  }
                  else if (list[i_s58] > d_s10) {
                     i_s68 >>= 1;
                     i_s58  -= i_s68;
                  }
                  else {
                     i_s68 = 1;
                  }
               }
            }
            else {
               ring1[i_s48] = d_s20;
               if (i_s28+i_s30 > 127) {
                  i_s30--;
                  i_s58 = i_s30;
               }
               else {
                  i_s28++;
                  i_s58 = i_s28;
               }
               if (i_s28 > 96) i_s38 = 96;
               else            i_s38 = i_s28;
               if (i_s30 < 32) i_s40 = 32;
               else            i_s40 = i_s30;
            }

            i_s68 = 64;
            i_s60 = i_s68;

            while (i_s68 > 1) {
               if (list[i_s60] < d_s20) {
                  i_s68 >>= 1;
                  i_s60  += i_s68;
               }
               else if (list[i_s60-1] > d_s20) {
                  i_s68 >>= 1;
                  i_s60  -= i_s68;
               }
               else {
                  i_s68 = 1;
               }
               if (i_s60==127) /*&&*/ if (d_s20 > list[127])
                  i_s60 = 128;
            }

            if (i_s70 > 127) {
               if (i_s58 >= i_s60) {
                  if      (i_s38+1 > i_s60 && i_s40-1 < i_s60) d_s18 += d_s20;
                  else if (i_s40   > i_s60 && i_s40-1 < i_s58) d_s18 += list[i_s40-1];
               }
               else if (i_s40 >= i_s60) {
                  if      (i_s38+1 < i_s60 && i_s38+1 > i_s58) d_s18 += list[i_s38+1];
               }
               else if    (i_s38+2 > i_s60               ) d_s18 += d_s20;
               else if    (i_s38+1 < i_s60 && i_s38+1 > i_s58) d_s18 += list[i_s38+1];

               if (i_s58 > i_s60) {
                  if      (i_s40-1 < i_s58 && i_s38+1 > i_s58) d_s18 -= list[i_s58];
                  else if (i_s38   < i_s58 && i_s38+1 > i_s60) d_s18 -= list[i_s38];
               }
               else if    (i_s38+1 > i_s58 && i_s40-1 < i_s58) d_s18 -= list[i_s58];
               else if    (i_s40   > i_s58 && i_s40   < i_s60) d_s18 -= list[i_s40];
            }

            if      (i_s58 > i_s60) { for (j=i_s58-1; j >= i_s60;   j--) list[j+1] = list[j]; list[i_s60  ] = d_s20; }
            else if (i_s58 < i_s60) { for (j=i_s58+1; j <= i_s60-1; j++) list[j-1] = list[j]; list[i_s60-1] = d_s20; }
            else                    {                                                         list[i_s60  ] = d_s20; }

            if (i_s70 <= 127) {
               d_s18 = 0;
               for (j=i_s40; j <= i_s38; j++) {
                  d_s18 += list[j];
               }
            }
            f60 = d_s18/(i_s38 - i_s40 + 1);

            if (i_fF8 >= 31) i_fF8 = 31;
            else             i_fF8++;

            if (i_fF8 <= 30) {
               if (f28 > 0) f18 = f8;
               else         f18 = f8 - f28 * f90;

               if (f48 < 0) f38 = f8;
               else         f38 = f8 - f48 * f90;

               fB8 = price;
               if (i_fF8 != 30)
                  continue;

               fC0 = price;
               if (MathCeil(f78) >= 1) d_v4 = MathCeil(f78);
               else                    d_v4 = 1;
               fE8 = MathCeil(d_v4);

               if (MathFloor(f78) >= 1) d_v2 = MathFloor(f78);
               else                     d_v2 = 1;
               fE0 = MathCeil(d_v2);

               if (fE8 == fE0) {
                  f68 = 1;
               }
               else {
                  d_v4  =  fE8 - fE0;
                  f68   = (f78 - fE0)/d_v4;
               }
               if (fE0 <= 29) i_v5 = fE0;
               else           i_v5 = 29;
               if (fE8 <= 29) i_v6 = fE8;
               else           i_v6 = 29;

               fA8 = (price-buffer[i_fF0-i_v5]) * (1-f68)/fE0 + (price-buffer[i_fF0-i_v6]) * f68/fE8;
            }
            else {
               if (f98 >= MathPow(fA0/f60, f88)) d_v1 = MathPow(fA0/f60, f88);
               else                              d_v1 = f98;
               if (d_v1 < 1) {
                  d_v2 = 1;
               }
               else {
                  if (f98 >= MathPow(fA0/f60, f88)) d_v3 = MathPow(fA0/f60, f88);
                  else                              d_v3 = f98;
                  d_v2 = d_v3;
               }

               f58 = d_v2;
               f70 = MathPow(f90, MathSqrt(f58));

               if (f28 > 0) f18 = f8;
               else         f18 = f8 - f28 * f70;
               if (f48 < 0) f38 = f8;
               else         f38 = f8 - f48 * f70;
            }
         }

         if (i_fF8 > 30) {
            f30  = MathPow(f50, f58);
            fC0  = (1-f30)*price + f30*fC0;
            fC8  = (price-fC0) * (1-f50) + f50*fC8;
            fD0  = f10 * fC8 + fC0;
            f20  = -f30 * 2;
            f40  = f30 * f30;
            fB0  = f20 + f40 + 1;
            fA8  = (fD0 - fB8) * fB0 + f40 * fA8;
            fB8 += fA8;
         }
         JMA = fB8;
      }
      if (i_fF0 <= 30)
         JMA = 0;

      bufferJMA[bar] = JMA;
      //debug("onTick()   JMA("+ bar +")="+ NumberToStr(JMA, SubPipPriceFormat));
   }


   int error = GetLastError();
   if (error != NO_ERROR) {
      if (error != ERR_ARRAY_INDEX_OUT_OF_RANGE)
         return(catch("onTick(1)", error));
      log("onTick(2)", SetLastError(error));
   }
   return(error);
}

