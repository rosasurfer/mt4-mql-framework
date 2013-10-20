/**
 * Multi-Color/Timeframe Jurik Moving Average
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

extern int Len      =  14;
extern int phase    =   0;
extern int BarCount = 300;

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>

#property indicator_chart_window

#property indicator_buffers 1

#property indicator_color1  Blue

double bufferJMA[];


/**
 *
 */
int onInit() {
   SetIndexBuffer    (0, bufferJMA);
   SetIndexEmptyValue(0, 0        );
   SetIndexStyle     (0, DRAW_LINE);

   IndicatorDigits(SubPipDigits);
   return(catch("onInit()"));
}


/**
 *
 */
int onTick() {
   int    i01, i02, i03, i04, i05, i06, i07, i08, i09, i10, i11, i12, i13, j;
   double d01, d02, d03, d04, d05, d06, d07, d08, d09, d10, d11, d12, d13, d14, d15, d16, d17, d18, d19, d20, d21, d22, d23, d24, d25, d26, d27, d28, d29, d30, d31, d32, d33, d34, d35;

   double price;
   double jma;

   double list127 [127];
   double ring127 [127];
   double ring10  [ 10];
   double buffer61[ 61];

   ArrayInitialize(list127, -1000000);
   ArrayInitialize(ring127,        0);
   ArrayInitialize(ring10,         0);
   ArrayInitialize(buffer61,       0);

   int i14 = 63;
   int i15 = 64;

   for (int i=i14; i < 127; i++) {
      list127[i] = 1000000;
   }

   if      (phase < -100) d11 = 0.5;
   else if (phase >  100) d11 = 2.5;
   else                   d11 = phase/100. + 1.5;


   bool bInit = true;


   for (int bar=BarCount; bar >= 0; bar--) {
      price = Close[bar];
      if (i11 < 61) {
         i11++;
         buffer61[i11-1] = price;
      }

      if (i11 > 30) {
         if (Len < 1.0000000002) d25 = 0.0000000001;
         else                    d25 = (Len-1)/2.0;

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
         d25 *= 0.9;
         d19  = d25/(d25 + 2);

         if (bInit) {
            bInit = false;
            i01 = 0;
            i12 = 0;
            d16 = price;
            for (i=0; i < 30; i++) {
               if (NE(buffer61[i], buffer61[i+1], Digits)) {
                  i01 = 1;
                  i12 = 29;
                  d16 = buffer61[0];
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
            else        d10 = buffer61[30-i];

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

                  d30 = (price-buffer61[i11-i01-1]) * (1-d22)/d03 + (price-buffer61[i11-i02-1]) * d22/d05;
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
      if (i11 <= 30)
         jma = 0;

      bufferJMA[bar] = jma;
   }

   return(last_error);
}
