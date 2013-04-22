/**
 * Sadukey Moving Average
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <stdlib.mqh>

//////////////////////////////////////////////////////////////// Externe Parameter ////////////////////////////////////////////////////////////////

extern int CountBars = 1000;

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>

#property indicator_chart_window

#property indicator_buffers 2

#property indicator_color1  Blue
#property indicator_width1  5
#property indicator_color2  Red
#property indicator_width2  5


double Buffer1[];
double Buffer2[];


//+------------------------------------------------------------------+
//| Custom indicator initialization function |
//+------------------------------------------------------------------+
int onInit() {
   SetIndexStyle    (0, DRAW_HISTOGRAM, 2);          // DRAW_LINE
   SetIndexBuffer   (0, Buffer1          );
   SetIndexDrawBegin(0, CountBars        );

   SetIndexStyle    (1, DRAW_HISTOGRAM, 2);          // DRAW_LINE
   SetIndexBuffer   (1, Buffer2          );
   SetIndexDrawBegin(1, CountBars        );

   IndicatorDigits(Digits);
   return(0);
}


//+------------------------------------------------------------------+
//
//+------------------------------------------------------------------+
int onTick() {
   int shift;

   for (int i=Bars-CountBars; i<=Bars-1; i++) {
      shift = Bars-1-i;

      // Sadukey-Median = (O+H+L+C)/4

      // (Sadukey-Median + Close)/2
      Buffer1[shift] = 0.11859648 * ((Open[shift+ 0] + High[shift+ 0] + Low[shift+ 0] + Close[shift+ 0])/4 + Close[shift+ 0])/2
                     + 0.11781324 * ((Open[shift+ 1] + High[shift+ 1] + Low[shift+ 1] + Close[shift+ 1])/4 + Close[shift+ 1])/2
                     + 0.11548308 * ((Open[shift+ 2] + High[shift+ 2] + Low[shift+ 2] + Close[shift+ 2])/4 + Close[shift+ 2])/2
                     + 0.11166411 * ((Open[shift+ 3] + High[shift+ 3] + Low[shift+ 3] + Close[shift+ 3])/4 + Close[shift+ 3])/2
                     + 0.10645106 * ((Open[shift+ 4] + High[shift+ 4] + Low[shift+ 4] + Close[shift+ 4])/4 + Close[shift+ 4])/2
                     + 0.09997253 * ((Open[shift+ 5] + High[shift+ 5] + Low[shift+ 5] + Close[shift+ 5])/4 + Close[shift+ 5])/2
                     + 0.09238688 * ((Open[shift+ 6] + High[shift+ 6] + Low[shift+ 6] + Close[shift+ 6])/4 + Close[shift+ 6])/2
                     + 0.08387751 * ((Open[shift+ 7] + High[shift+ 7] + Low[shift+ 7] + Close[shift+ 7])/4 + Close[shift+ 7])/2
                     + 0.07464713 * ((Open[shift+ 8] + High[shift+ 8] + Low[shift+ 8] + Close[shift+ 8])/4 + Close[shift+ 8])/2
                     + 0.06491178 * ((Open[shift+ 9] + High[shift+ 9] + Low[shift+ 9] + Close[shift+ 9])/4 + Close[shift+ 9])/2
                     + 0.05489443 * ((Open[shift+10] + High[shift+10] + Low[shift+10] + Close[shift+10])/4 + Close[shift+10])/2
                     + 0.04481833 * ((Open[shift+11] + High[shift+11] + Low[shift+11] + Close[shift+11])/4 + Close[shift+11])/2
                     + 0.03490071 * ((Open[shift+12] + High[shift+12] + Low[shift+12] + Close[shift+12])/4 + Close[shift+12])/2
                     + 0.02534672 * ((Open[shift+13] + High[shift+13] + Low[shift+13] + Close[shift+13])/4 + Close[shift+13])/2
                     + 0.01634375 * ((Open[shift+14] + High[shift+14] + Low[shift+14] + Close[shift+14])/4 + Close[shift+14])/2
                     + 0.00805678 * ((Open[shift+15] + High[shift+15] + Low[shift+15] + Close[shift+15])/4 + Close[shift+15])/2
                     + 0.00062421 * ((Open[shift+16] + High[shift+16] + Low[shift+16] + Close[shift+16])/4 + Close[shift+16])/2
                     - 0.00584512 * ((Open[shift+17] + High[shift+17] + Low[shift+17] + Close[shift+17])/4 + Close[shift+17])/2
                     - 0.01127391 * ((Open[shift+18] + High[shift+18] + Low[shift+18] + Close[shift+18])/4 + Close[shift+18])/2
                     - 0.01561738 * ((Open[shift+19] + High[shift+19] + Low[shift+19] + Close[shift+19])/4 + Close[shift+19])/2
                     - 0.01886307 * ((Open[shift+20] + High[shift+20] + Low[shift+20] + Close[shift+20])/4 + Close[shift+20])/2
                     - 0.02102974 * ((Open[shift+21] + High[shift+21] + Low[shift+21] + Close[shift+21])/4 + Close[shift+21])/2
                     - 0.02216516 * ((Open[shift+22] + High[shift+22] + Low[shift+22] + Close[shift+22])/4 + Close[shift+22])/2
                     - 0.02234315 * ((Open[shift+23] + High[shift+23] + Low[shift+23] + Close[shift+23])/4 + Close[shift+23])/2
                     - 0.02165992 * ((Open[shift+24] + High[shift+24] + Low[shift+24] + Close[shift+24])/4 + Close[shift+24])/2
                     - 0.02022973 * ((Open[shift+25] + High[shift+25] + Low[shift+25] + Close[shift+25])/4 + Close[shift+25])/2
                     - 0.01818026 * ((Open[shift+26] + High[shift+26] + Low[shift+26] + Close[shift+26])/4 + Close[shift+26])/2
                     - 0.01564777 * ((Open[shift+27] + High[shift+27] + Low[shift+27] + Close[shift+27])/4 + Close[shift+27])/2
                     - 0.01277219 * ((Open[shift+28] + High[shift+28] + Low[shift+28] + Close[shift+28])/4 + Close[shift+28])/2
                     - 0.00969230 * ((Open[shift+29] + High[shift+29] + Low[shift+29] + Close[shift+29])/4 + Close[shift+29])/2
                     - 0.00654127 * ((Open[shift+30] + High[shift+30] + Low[shift+30] + Close[shift+30])/4 + Close[shift+30])/2
                     - 0.00344276 * ((Open[shift+31] + High[shift+31] + Low[shift+31] + Close[shift+31])/4 + Close[shift+31])/2
                     - 0.00050728 * ((Open[shift+32] + High[shift+32] + Low[shift+32] + Close[shift+32])/4 + Close[shift+32])/2
                     + 0.00217042 * ((Open[shift+33] + High[shift+33] + Low[shift+33] + Close[shift+33])/4 + Close[shift+33])/2
                     + 0.00451354 * ((Open[shift+34] + High[shift+34] + Low[shift+34] + Close[shift+34])/4 + Close[shift+34])/2
                     + 0.00646441 * ((Open[shift+35] + High[shift+35] + Low[shift+35] + Close[shift+35])/4 + Close[shift+35])/2
                     + 0.00798513 * ((Open[shift+36] + High[shift+36] + Low[shift+36] + Close[shift+36])/4 + Close[shift+36])/2
                     + 0.00905725 * ((Open[shift+37] + High[shift+37] + Low[shift+37] + Close[shift+37])/4 + Close[shift+37])/2
                     + 0.00968091 * ((Open[shift+38] + High[shift+38] + Low[shift+38] + Close[shift+38])/4 + Close[shift+38])/2
                     + 0.00987326 * ((Open[shift+39] + High[shift+39] + Low[shift+39] + Close[shift+39])/4 + Close[shift+39])/2
                     + 0.00966639 * ((Open[shift+40] + High[shift+40] + Low[shift+40] + Close[shift+40])/4 + Close[shift+40])/2
                     + 0.00910488 * ((Open[shift+41] + High[shift+41] + Low[shift+41] + Close[shift+41])/4 + Close[shift+41])/2
                     + 0.00824306 * ((Open[shift+42] + High[shift+42] + Low[shift+42] + Close[shift+42])/4 + Close[shift+42])/2
                     + 0.00714199 * ((Open[shift+43] + High[shift+43] + Low[shift+43] + Close[shift+43])/4 + Close[shift+43])/2
                     + 0.00586655 * ((Open[shift+44] + High[shift+44] + Low[shift+44] + Close[shift+44])/4 + Close[shift+44])/2
                     + 0.00448255 * ((Open[shift+45] + High[shift+45] + Low[shift+45] + Close[shift+45])/4 + Close[shift+45])/2
                     + 0.00305396 * ((Open[shift+46] + High[shift+46] + Low[shift+46] + Close[shift+46])/4 + Close[shift+46])/2
                     + 0.00164061 * ((Open[shift+47] + High[shift+47] + Low[shift+47] + Close[shift+47])/4 + Close[shift+47])/2
                     + 0.00029596 * ((Open[shift+48] + High[shift+48] + Low[shift+48] + Close[shift+48])/4 + Close[shift+48])/2
                     - 0.00093445 * ((Open[shift+49] + High[shift+49] + Low[shift+49] + Close[shift+49])/4 + Close[shift+49])/2
                     - 0.00201426 * ((Open[shift+50] + High[shift+50] + Low[shift+50] + Close[shift+50])/4 + Close[shift+50])/2
                     - 0.00291701 * ((Open[shift+51] + High[shift+51] + Low[shift+51] + Close[shift+51])/4 + Close[shift+51])/2
                     - 0.00362661 * ((Open[shift+52] + High[shift+52] + Low[shift+52] + Close[shift+52])/4 + Close[shift+52])/2
                     - 0.00413703 * ((Open[shift+53] + High[shift+53] + Low[shift+53] + Close[shift+53])/4 + Close[shift+53])/2
                     - 0.00445206 * ((Open[shift+54] + High[shift+54] + Low[shift+54] + Close[shift+54])/4 + Close[shift+54])/2
                     - 0.00458437 * ((Open[shift+55] + High[shift+55] + Low[shift+55] + Close[shift+55])/4 + Close[shift+55])/2
                     - 0.00455457 * ((Open[shift+56] + High[shift+56] + Low[shift+56] + Close[shift+56])/4 + Close[shift+56])/2
                     - 0.00439006 * ((Open[shift+57] + High[shift+57] + Low[shift+57] + Close[shift+57])/4 + Close[shift+57])/2
                     - 0.00412379 * ((Open[shift+58] + High[shift+58] + Low[shift+58] + Close[shift+58])/4 + Close[shift+58])/2
                     - 0.00379323 * ((Open[shift+59] + High[shift+59] + Low[shift+59] + Close[shift+59])/4 + Close[shift+59])/2
                     - 0.00343966 * ((Open[shift+60] + High[shift+60] + Low[shift+60] + Close[shift+60])/4 + Close[shift+60])/2
                     - 0.00310850 * ((Open[shift+61] + High[shift+61] + Low[shift+61] + Close[shift+61])/4 + Close[shift+61])/2
                     - 0.00285188 * ((Open[shift+62] + High[shift+62] + Low[shift+62] + Close[shift+62])/4 + Close[shift+62])/2
                     - 0.00273508 * ((Open[shift+63] + High[shift+63] + Low[shift+63] + Close[shift+63])/4 + Close[shift+63])/2
                     - 0.00274361 * ((Open[shift+64] + High[shift+64] + Low[shift+64] + Close[shift+64])/4 + Close[shift+64])/2
                     + 0.01018757 * ((Open[shift+65] + High[shift+65] + Low[shift+65] + Close[shift+65])/4 + Close[shift+65])/2;

      // (Sadukey-Median + Open)/2
      Buffer2[shift] = 0.11859648 * ((Open[shift+ 0] + High[shift+ 0] + Low[shift+ 0] + Close[shift+ 0])/4 + Open[shift+ 0])/2
                     + 0.11781324 * ((Open[shift+ 1] + High[shift+ 1] + Low[shift+ 1] + Close[shift+ 1])/4 + Open[shift+ 1])/2
                     + 0.11548308 * ((Open[shift+ 2] + High[shift+ 2] + Low[shift+ 2] + Close[shift+ 2])/4 + Open[shift+ 2])/2
                     + 0.11166411 * ((Open[shift+ 3] + High[shift+ 3] + Low[shift+ 3] + Close[shift+ 3])/4 + Open[shift+ 3])/2
                     + 0.10645106 * ((Open[shift+ 4] + High[shift+ 4] + Low[shift+ 4] + Close[shift+ 4])/4 + Open[shift+ 4])/2
                     + 0.09997253 * ((Open[shift+ 5] + High[shift+ 5] + Low[shift+ 5] + Close[shift+ 5])/4 + Open[shift+ 5])/2
                     + 0.09238688 * ((Open[shift+ 6] + High[shift+ 6] + Low[shift+ 6] + Close[shift+ 6])/4 + Open[shift+ 6])/2
                     + 0.08387751 * ((Open[shift+ 7] + High[shift+ 7] + Low[shift+ 7] + Close[shift+ 7])/4 + Open[shift+ 7])/2
                     + 0.07464713 * ((Open[shift+ 8] + High[shift+ 8] + Low[shift+ 8] + Close[shift+ 8])/4 + Open[shift+ 8])/2
                     + 0.06491178 * ((Open[shift+ 9] + High[shift+ 9] + Low[shift+ 9] + Close[shift+ 9])/4 + Open[shift+ 9])/2
                     + 0.05489443 * ((Open[shift+10] + High[shift+10] + Low[shift+10] + Close[shift+10])/4 + Open[shift+10])/2
                     + 0.04481833 * ((Open[shift+11] + High[shift+11] + Low[shift+11] + Close[shift+11])/4 + Open[shift+11])/2
                     + 0.03490071 * ((Open[shift+12] + High[shift+12] + Low[shift+12] + Close[shift+12])/4 + Open[shift+12])/2
                     + 0.02534672 * ((Open[shift+13] + High[shift+13] + Low[shift+13] + Close[shift+13])/4 + Open[shift+13])/2
                     + 0.01634375 * ((Open[shift+14] + High[shift+14] + Low[shift+14] + Close[shift+14])/4 + Open[shift+14])/2
                     + 0.00805678 * ((Open[shift+15] + High[shift+15] + Low[shift+15] + Close[shift+15])/4 + Open[shift+15])/2
                     + 0.00062421 * ((Open[shift+16] + High[shift+16] + Low[shift+16] + Close[shift+16])/4 + Open[shift+16])/2
                     - 0.00584512 * ((Open[shift+17] + High[shift+17] + Low[shift+17] + Close[shift+17])/4 + Open[shift+17])/2
                     - 0.01127391 * ((Open[shift+18] + High[shift+18] + Low[shift+18] + Close[shift+18])/4 + Open[shift+18])/2
                     - 0.01561738 * ((Open[shift+19] + High[shift+19] + Low[shift+19] + Close[shift+19])/4 + Open[shift+19])/2
                     - 0.01886307 * ((Open[shift+20] + High[shift+20] + Low[shift+20] + Close[shift+20])/4 + Open[shift+20])/2
                     - 0.02102974 * ((Open[shift+21] + High[shift+21] + Low[shift+21] + Close[shift+21])/4 + Open[shift+21])/2
                     - 0.02216516 * ((Open[shift+22] + High[shift+22] + Low[shift+22] + Close[shift+22])/4 + Open[shift+22])/2
                     - 0.02234315 * ((Open[shift+23] + High[shift+23] + Low[shift+23] + Close[shift+23])/4 + Open[shift+23])/2
                     - 0.02165992 * ((Open[shift+24] + High[shift+24] + Low[shift+24] + Close[shift+24])/4 + Open[shift+24])/2
                     - 0.02022973 * ((Open[shift+25] + High[shift+25] + Low[shift+25] + Close[shift+25])/4 + Open[shift+25])/2
                     - 0.01818026 * ((Open[shift+26] + High[shift+26] + Low[shift+26] + Close[shift+26])/4 + Open[shift+26])/2
                     - 0.01564777 * ((Open[shift+27] + High[shift+27] + Low[shift+27] + Close[shift+27])/4 + Open[shift+27])/2
                     - 0.01277219 * ((Open[shift+28] + High[shift+28] + Low[shift+28] + Close[shift+28])/4 + Open[shift+28])/2
                     - 0.00969230 * ((Open[shift+29] + High[shift+29] + Low[shift+29] + Close[shift+29])/4 + Open[shift+29])/2
                     - 0.00654127 * ((Open[shift+30] + High[shift+30] + Low[shift+30] + Close[shift+30])/4 + Open[shift+30])/2
                     - 0.00344276 * ((Open[shift+31] + High[shift+31] + Low[shift+31] + Close[shift+31])/4 + Open[shift+31])/2
                     - 0.00050728 * ((Open[shift+32] + High[shift+32] + Low[shift+32] + Close[shift+32])/4 + Open[shift+32])/2
                     + 0.00217042 * ((Open[shift+33] + High[shift+33] + Low[shift+33] + Close[shift+33])/4 + Open[shift+33])/2
                     + 0.00451354 * ((Open[shift+34] + High[shift+34] + Low[shift+34] + Close[shift+34])/4 + Open[shift+34])/2
                     + 0.00646441 * ((Open[shift+35] + High[shift+35] + Low[shift+35] + Close[shift+35])/4 + Open[shift+35])/2
                     + 0.00798513 * ((Open[shift+36] + High[shift+36] + Low[shift+36] + Close[shift+36])/4 + Open[shift+36])/2
                     + 0.00905725 * ((Open[shift+37] + High[shift+37] + Low[shift+37] + Close[shift+37])/4 + Open[shift+37])/2
                     + 0.00968091 * ((Open[shift+38] + High[shift+38] + Low[shift+38] + Close[shift+38])/4 + Open[shift+38])/2
                     + 0.00987326 * ((Open[shift+39] + High[shift+39] + Low[shift+39] + Close[shift+39])/4 + Open[shift+39])/2
                     + 0.00966639 * ((Open[shift+40] + High[shift+40] + Low[shift+40] + Close[shift+40])/4 + Open[shift+40])/2
                     + 0.00910488 * ((Open[shift+41] + High[shift+41] + Low[shift+41] + Close[shift+41])/4 + Open[shift+41])/2
                     + 0.00824306 * ((Open[shift+42] + High[shift+42] + Low[shift+42] + Close[shift+42])/4 + Open[shift+42])/2
                     + 0.00714199 * ((Open[shift+43] + High[shift+43] + Low[shift+43] + Close[shift+43])/4 + Open[shift+43])/2
                     + 0.00586655 * ((Open[shift+44] + High[shift+44] + Low[shift+44] + Close[shift+44])/4 + Open[shift+44])/2
                     + 0.00448255 * ((Open[shift+45] + High[shift+45] + Low[shift+45] + Close[shift+45])/4 + Open[shift+45])/2
                     + 0.00305396 * ((Open[shift+46] + High[shift+46] + Low[shift+46] + Close[shift+46])/4 + Open[shift+46])/2
                     + 0.00164061 * ((Open[shift+47] + High[shift+47] + Low[shift+47] + Close[shift+47])/4 + Open[shift+47])/2
                     + 0.00029596 * ((Open[shift+48] + High[shift+48] + Low[shift+48] + Close[shift+48])/4 + Open[shift+48])/2
                     - 0.00093445 * ((Open[shift+49] + High[shift+49] + Low[shift+49] + Close[shift+49])/4 + Open[shift+49])/2
                     - 0.00201426 * ((Open[shift+50] + High[shift+50] + Low[shift+50] + Close[shift+50])/4 + Open[shift+50])/2
                     - 0.00291701 * ((Open[shift+51] + High[shift+51] + Low[shift+51] + Close[shift+51])/4 + Open[shift+51])/2
                     - 0.00362661 * ((Open[shift+52] + High[shift+52] + Low[shift+52] + Close[shift+52])/4 + Open[shift+52])/2
                     - 0.00413703 * ((Open[shift+53] + High[shift+53] + Low[shift+53] + Close[shift+53])/4 + Open[shift+53])/2
                     - 0.00445206 * ((Open[shift+54] + High[shift+54] + Low[shift+54] + Close[shift+54])/4 + Open[shift+54])/2
                     - 0.00458437 * ((Open[shift+55] + High[shift+55] + Low[shift+55] + Close[shift+55])/4 + Open[shift+55])/2
                     - 0.00455457 * ((Open[shift+56] + High[shift+56] + Low[shift+56] + Close[shift+56])/4 + Open[shift+56])/2
                     - 0.00439006 * ((Open[shift+57] + High[shift+57] + Low[shift+57] + Close[shift+57])/4 + Open[shift+57])/2
                     - 0.00412379 * ((Open[shift+58] + High[shift+58] + Low[shift+58] + Close[shift+58])/4 + Open[shift+58])/2
                     - 0.00379323 * ((Open[shift+59] + High[shift+59] + Low[shift+59] + Close[shift+59])/4 + Open[shift+59])/2
                     - 0.00343966 * ((Open[shift+60] + High[shift+60] + Low[shift+60] + Close[shift+60])/4 + Open[shift+60])/2
                     - 0.00310850 * ((Open[shift+61] + High[shift+61] + Low[shift+61] + Close[shift+61])/4 + Open[shift+61])/2
                     - 0.00285188 * ((Open[shift+62] + High[shift+62] + Low[shift+62] + Close[shift+62])/4 + Open[shift+62])/2
                     - 0.00273508 * ((Open[shift+63] + High[shift+63] + Low[shift+63] + Close[shift+63])/4 + Open[shift+63])/2
                     - 0.00274361 * ((Open[shift+64] + High[shift+64] + Low[shift+64] + Close[shift+64])/4 + Open[shift+64])/2
                     + 0.01018757 * ((Open[shift+65] + High[shift+65] + Low[shift+65] + Close[shift+65])/4 + Open[shift+65])/2;
   }
   return(0);
}
