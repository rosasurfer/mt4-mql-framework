/**
 * Sadukey indicator - a filter with coefficients designed by the "Digital Filter Generator"
 *
 *
 * Coefficients are more than 10 years old, so the indicator should be taken with a grain of salt.
 *
 * @link  http://www.finware.com/generator.html
 * @link  http://fx.qrz.ru/
 */
#include <stddefines.mqh>
int   __InitFlags[];
int __DeinitFlags[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern color  Color.UpTrend   = Blue;
extern color  Color.DownTrend = Red;

extern string MTF.Timeframe   = "current* | M15 | M30 | H1 | ...";   // empty: current
extern string StartDate       = "yyyy.mm.dd";                        // start date of calculated values
extern int    Max.Bars        = 10000;                               // max. values to calculate (-1: all available)

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <rsfLib.mqh>
#include <functions/iBarShiftNext.mqh>
#include <functions/iBarShiftPrevious.mqh>
#include <functions/iChangedBars.mqh>
#include <functions/ParseTime.mqh>
#include <functions/legend.mqh>
#include <functions/trend.mqh>

#define MODE_BUFFER1         0                                       // indicator buffer ids
#define MODE_BUFFER2         1

#property indicator_chart_window
#property indicator_buffers  2

#property indicator_color1   CLR_NONE
#property indicator_width1   5
#property indicator_color2   CLR_NONE
#property indicator_width2   5

double   buffer1[];
double   buffer2[];

int      dataTimeframe;
datetime startTime;
int      maxValues;

string   indicatorName = "";
string   legendLabel   = "";


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   // validate inputs
   // colors: after deserialization the terminal might turn CLR_NONE (0xFFFFFFFF) into Black (0xFF000000)
   if (Color.UpTrend   == 0xFF000000) Color.UpTrend   = CLR_NONE;
   if (Color.DownTrend == 0xFF000000) Color.DownTrend = CLR_NONE;
   // MTF.Timeframe
   string sValues[], sValue = MTF.Timeframe;
   if (Explode(sValue, "*", sValues, 2) > 1) {
      int size = Explode(sValues[0], "|", sValues, NULL);
      sValue = sValues[size-1];
   }
   sValue = StrTrim(sValue);
   if (sValue=="" || sValue=="0" || sValue=="current") {
      dataTimeframe = Period();
      MTF.Timeframe = "current";
   }
   else {
      dataTimeframe = StrToTimeframe(sValue, F_ERR_INVALID_PARAMETER);
      if (dataTimeframe == -1) return(catch("onInit(1)  invalid input parameter MTF.Timeframe: "+ DoubleQuoteStr(MTF.Timeframe), ERR_INVALID_INPUT_PARAMETER));
      MTF.Timeframe = TimeframeDescription(dataTimeframe);
   }
   // StartDate
   sValue = StrTrim(StartDate);
   if (sValue!="" && sValue!="yyyy.mm.dd") {
      int pt[];
      bool success = ParseTime(sValue, DATE_YYYYMMDD|DATE_DDMMYYYY|TIME_OPTIONAL, pt);
      if (!success)            return(catch("onInit(2)  invalid input parameter StartDate: "+ DoubleQuoteStr(StartDate), ERR_INVALID_INPUT_PARAMETER));
      startTime = DateTime2(pt);
   }
   // Max.Bars
   if (Max.Bars < -1)          return(catch("onInit(2)  invalid input parameter Max.Bars: "+ Max.Bars, ERR_INVALID_INPUT_PARAMETER));
   maxValues = ifInt(Max.Bars==-1, INT_MAX, Max.Bars);

   // buffer management
   SetIndexBuffer(MODE_BUFFER1, buffer1);
   SetIndexBuffer(MODE_BUFFER2, buffer2);

   // names, labels and display options
   legendLabel = CreateLegend();
   indicatorName = ProgramName();
   IndicatorShortName(indicatorName);                 // chart tooltips and context menu
   SetIndexLabel(MODE_BUFFER1, indicatorName +" 1");  // chart tooltips and "Data" window
   SetIndexLabel(MODE_BUFFER2, indicatorName +" 2");
   IndicatorDigits(Digits);
   SetIndicatorOptions();
   return(catch("onInit(3)"));
}


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   // on the first tick after terminal start buffers may not yet be initialized (spurious issue)
   if (!ArraySize(buffer1)) return(logInfo("onTick(1)  sizeof(buffer1) = 0", SetLastError(ERS_TERMINAL_NOT_YET_READY)));

   // reset buffers before performing a full recalculation
   if (!ValidBars) {
      ArrayInitialize(buffer1, EMPTY_VALUE);
      ArrayInitialize(buffer2, EMPTY_VALUE);
      SetIndicatorOptions();
   }

   // synchronize buffers with a shifted offline chart
   if (ShiftedBars > 0) {
      ShiftDoubleIndicatorBuffer(buffer1, Bars, ShiftedBars, EMPTY_VALUE);
      ShiftDoubleIndicatorBuffer(buffer2, Bars, ShiftedBars, EMPTY_VALUE);
   }

   // recalculate changed bars
   int changedBars = ComputeChangedBars(dataTimeframe);                       // changed bars considering two timeframes

   if (dataTimeframe == Period()) {
      // data timeframe = chart timeframe

      for (int i=changedBars-1; i >= 0; i--) {
         // buffer1 = (PRICE_AVERAGE + Close)/2
         buffer1[i] = 0.11859648 * ((Open[i+ 0] + High[i+ 0] + Low[i+ 0] + Close[i+ 0])/4 + Close[i+ 0])/2
                    + 0.11781324 * ((Open[i+ 1] + High[i+ 1] + Low[i+ 1] + Close[i+ 1])/4 + Close[i+ 1])/2
                    + 0.11548308 * ((Open[i+ 2] + High[i+ 2] + Low[i+ 2] + Close[i+ 2])/4 + Close[i+ 2])/2
                    + 0.11166411 * ((Open[i+ 3] + High[i+ 3] + Low[i+ 3] + Close[i+ 3])/4 + Close[i+ 3])/2
                    + 0.10645106 * ((Open[i+ 4] + High[i+ 4] + Low[i+ 4] + Close[i+ 4])/4 + Close[i+ 4])/2
                    + 0.09997253 * ((Open[i+ 5] + High[i+ 5] + Low[i+ 5] + Close[i+ 5])/4 + Close[i+ 5])/2
                    + 0.09238688 * ((Open[i+ 6] + High[i+ 6] + Low[i+ 6] + Close[i+ 6])/4 + Close[i+ 6])/2
                    + 0.08387751 * ((Open[i+ 7] + High[i+ 7] + Low[i+ 7] + Close[i+ 7])/4 + Close[i+ 7])/2
                    + 0.07464713 * ((Open[i+ 8] + High[i+ 8] + Low[i+ 8] + Close[i+ 8])/4 + Close[i+ 8])/2
                    + 0.06491178 * ((Open[i+ 9] + High[i+ 9] + Low[i+ 9] + Close[i+ 9])/4 + Close[i+ 9])/2
                    + 0.05489443 * ((Open[i+10] + High[i+10] + Low[i+10] + Close[i+10])/4 + Close[i+10])/2
                    + 0.04481833 * ((Open[i+11] + High[i+11] + Low[i+11] + Close[i+11])/4 + Close[i+11])/2
                    + 0.03490071 * ((Open[i+12] + High[i+12] + Low[i+12] + Close[i+12])/4 + Close[i+12])/2
                    + 0.02534672 * ((Open[i+13] + High[i+13] + Low[i+13] + Close[i+13])/4 + Close[i+13])/2
                    + 0.01634375 * ((Open[i+14] + High[i+14] + Low[i+14] + Close[i+14])/4 + Close[i+14])/2
                    + 0.00805678 * ((Open[i+15] + High[i+15] + Low[i+15] + Close[i+15])/4 + Close[i+15])/2
                    + 0.00062421 * ((Open[i+16] + High[i+16] + Low[i+16] + Close[i+16])/4 + Close[i+16])/2
                    - 0.00584512 * ((Open[i+17] + High[i+17] + Low[i+17] + Close[i+17])/4 + Close[i+17])/2
                    - 0.01127391 * ((Open[i+18] + High[i+18] + Low[i+18] + Close[i+18])/4 + Close[i+18])/2
                    - 0.01561738 * ((Open[i+19] + High[i+19] + Low[i+19] + Close[i+19])/4 + Close[i+19])/2
                    - 0.01886307 * ((Open[i+20] + High[i+20] + Low[i+20] + Close[i+20])/4 + Close[i+20])/2
                    - 0.02102974 * ((Open[i+21] + High[i+21] + Low[i+21] + Close[i+21])/4 + Close[i+21])/2
                    - 0.02216516 * ((Open[i+22] + High[i+22] + Low[i+22] + Close[i+22])/4 + Close[i+22])/2
                    - 0.02234315 * ((Open[i+23] + High[i+23] + Low[i+23] + Close[i+23])/4 + Close[i+23])/2
                    - 0.02165992 * ((Open[i+24] + High[i+24] + Low[i+24] + Close[i+24])/4 + Close[i+24])/2
                    - 0.02022973 * ((Open[i+25] + High[i+25] + Low[i+25] + Close[i+25])/4 + Close[i+25])/2
                    - 0.01818026 * ((Open[i+26] + High[i+26] + Low[i+26] + Close[i+26])/4 + Close[i+26])/2
                    - 0.01564777 * ((Open[i+27] + High[i+27] + Low[i+27] + Close[i+27])/4 + Close[i+27])/2
                    - 0.01277219 * ((Open[i+28] + High[i+28] + Low[i+28] + Close[i+28])/4 + Close[i+28])/2
                    - 0.00969230 * ((Open[i+29] + High[i+29] + Low[i+29] + Close[i+29])/4 + Close[i+29])/2
                    - 0.00654127 * ((Open[i+30] + High[i+30] + Low[i+30] + Close[i+30])/4 + Close[i+30])/2
                    - 0.00344276 * ((Open[i+31] + High[i+31] + Low[i+31] + Close[i+31])/4 + Close[i+31])/2
                    - 0.00050728 * ((Open[i+32] + High[i+32] + Low[i+32] + Close[i+32])/4 + Close[i+32])/2
                    + 0.00217042 * ((Open[i+33] + High[i+33] + Low[i+33] + Close[i+33])/4 + Close[i+33])/2
                    + 0.00451354 * ((Open[i+34] + High[i+34] + Low[i+34] + Close[i+34])/4 + Close[i+34])/2
                    + 0.00646441 * ((Open[i+35] + High[i+35] + Low[i+35] + Close[i+35])/4 + Close[i+35])/2
                    + 0.00798513 * ((Open[i+36] + High[i+36] + Low[i+36] + Close[i+36])/4 + Close[i+36])/2
                    + 0.00905725 * ((Open[i+37] + High[i+37] + Low[i+37] + Close[i+37])/4 + Close[i+37])/2
                    + 0.00968091 * ((Open[i+38] + High[i+38] + Low[i+38] + Close[i+38])/4 + Close[i+38])/2
                    + 0.00987326 * ((Open[i+39] + High[i+39] + Low[i+39] + Close[i+39])/4 + Close[i+39])/2
                    + 0.00966639 * ((Open[i+40] + High[i+40] + Low[i+40] + Close[i+40])/4 + Close[i+40])/2
                    + 0.00910488 * ((Open[i+41] + High[i+41] + Low[i+41] + Close[i+41])/4 + Close[i+41])/2
                    + 0.00824306 * ((Open[i+42] + High[i+42] + Low[i+42] + Close[i+42])/4 + Close[i+42])/2
                    + 0.00714199 * ((Open[i+43] + High[i+43] + Low[i+43] + Close[i+43])/4 + Close[i+43])/2
                    + 0.00586655 * ((Open[i+44] + High[i+44] + Low[i+44] + Close[i+44])/4 + Close[i+44])/2
                    + 0.00448255 * ((Open[i+45] + High[i+45] + Low[i+45] + Close[i+45])/4 + Close[i+45])/2
                    + 0.00305396 * ((Open[i+46] + High[i+46] + Low[i+46] + Close[i+46])/4 + Close[i+46])/2
                    + 0.00164061 * ((Open[i+47] + High[i+47] + Low[i+47] + Close[i+47])/4 + Close[i+47])/2
                    + 0.00029596 * ((Open[i+48] + High[i+48] + Low[i+48] + Close[i+48])/4 + Close[i+48])/2
                    - 0.00093445 * ((Open[i+49] + High[i+49] + Low[i+49] + Close[i+49])/4 + Close[i+49])/2
                    - 0.00201426 * ((Open[i+50] + High[i+50] + Low[i+50] + Close[i+50])/4 + Close[i+50])/2
                    - 0.00291701 * ((Open[i+51] + High[i+51] + Low[i+51] + Close[i+51])/4 + Close[i+51])/2
                    - 0.00362661 * ((Open[i+52] + High[i+52] + Low[i+52] + Close[i+52])/4 + Close[i+52])/2
                    - 0.00413703 * ((Open[i+53] + High[i+53] + Low[i+53] + Close[i+53])/4 + Close[i+53])/2
                    - 0.00445206 * ((Open[i+54] + High[i+54] + Low[i+54] + Close[i+54])/4 + Close[i+54])/2
                    - 0.00458437 * ((Open[i+55] + High[i+55] + Low[i+55] + Close[i+55])/4 + Close[i+55])/2
                    - 0.00455457 * ((Open[i+56] + High[i+56] + Low[i+56] + Close[i+56])/4 + Close[i+56])/2
                    - 0.00439006 * ((Open[i+57] + High[i+57] + Low[i+57] + Close[i+57])/4 + Close[i+57])/2
                    - 0.00412379 * ((Open[i+58] + High[i+58] + Low[i+58] + Close[i+58])/4 + Close[i+58])/2
                    - 0.00379323 * ((Open[i+59] + High[i+59] + Low[i+59] + Close[i+59])/4 + Close[i+59])/2
                    - 0.00343966 * ((Open[i+60] + High[i+60] + Low[i+60] + Close[i+60])/4 + Close[i+60])/2
                    - 0.00310850 * ((Open[i+61] + High[i+61] + Low[i+61] + Close[i+61])/4 + Close[i+61])/2
                    - 0.00285188 * ((Open[i+62] + High[i+62] + Low[i+62] + Close[i+62])/4 + Close[i+62])/2
                    - 0.00273508 * ((Open[i+63] + High[i+63] + Low[i+63] + Close[i+63])/4 + Close[i+63])/2
                    - 0.00274361 * ((Open[i+64] + High[i+64] + Low[i+64] + Close[i+64])/4 + Close[i+64])/2
                    + 0.01018757 * ((Open[i+65] + High[i+65] + Low[i+65] + Close[i+65])/4 + Close[i+65])/2;

         // buffer2 = (PRICE_AVERAGE + Open)/2
         buffer2[i] = 0.11859648 * ((Open[i+ 0] + High[i+ 0] + Low[i+ 0] + Close[i+ 0])/4 + Open[i+ 0])/2
                    + 0.11781324 * ((Open[i+ 1] + High[i+ 1] + Low[i+ 1] + Close[i+ 1])/4 + Open[i+ 1])/2
                    + 0.11548308 * ((Open[i+ 2] + High[i+ 2] + Low[i+ 2] + Close[i+ 2])/4 + Open[i+ 2])/2
                    + 0.11166411 * ((Open[i+ 3] + High[i+ 3] + Low[i+ 3] + Close[i+ 3])/4 + Open[i+ 3])/2
                    + 0.10645106 * ((Open[i+ 4] + High[i+ 4] + Low[i+ 4] + Close[i+ 4])/4 + Open[i+ 4])/2
                    + 0.09997253 * ((Open[i+ 5] + High[i+ 5] + Low[i+ 5] + Close[i+ 5])/4 + Open[i+ 5])/2
                    + 0.09238688 * ((Open[i+ 6] + High[i+ 6] + Low[i+ 6] + Close[i+ 6])/4 + Open[i+ 6])/2
                    + 0.08387751 * ((Open[i+ 7] + High[i+ 7] + Low[i+ 7] + Close[i+ 7])/4 + Open[i+ 7])/2
                    + 0.07464713 * ((Open[i+ 8] + High[i+ 8] + Low[i+ 8] + Close[i+ 8])/4 + Open[i+ 8])/2
                    + 0.06491178 * ((Open[i+ 9] + High[i+ 9] + Low[i+ 9] + Close[i+ 9])/4 + Open[i+ 9])/2
                    + 0.05489443 * ((Open[i+10] + High[i+10] + Low[i+10] + Close[i+10])/4 + Open[i+10])/2
                    + 0.04481833 * ((Open[i+11] + High[i+11] + Low[i+11] + Close[i+11])/4 + Open[i+11])/2
                    + 0.03490071 * ((Open[i+12] + High[i+12] + Low[i+12] + Close[i+12])/4 + Open[i+12])/2
                    + 0.02534672 * ((Open[i+13] + High[i+13] + Low[i+13] + Close[i+13])/4 + Open[i+13])/2
                    + 0.01634375 * ((Open[i+14] + High[i+14] + Low[i+14] + Close[i+14])/4 + Open[i+14])/2
                    + 0.00805678 * ((Open[i+15] + High[i+15] + Low[i+15] + Close[i+15])/4 + Open[i+15])/2
                    + 0.00062421 * ((Open[i+16] + High[i+16] + Low[i+16] + Close[i+16])/4 + Open[i+16])/2
                    - 0.00584512 * ((Open[i+17] + High[i+17] + Low[i+17] + Close[i+17])/4 + Open[i+17])/2
                    - 0.01127391 * ((Open[i+18] + High[i+18] + Low[i+18] + Close[i+18])/4 + Open[i+18])/2
                    - 0.01561738 * ((Open[i+19] + High[i+19] + Low[i+19] + Close[i+19])/4 + Open[i+19])/2
                    - 0.01886307 * ((Open[i+20] + High[i+20] + Low[i+20] + Close[i+20])/4 + Open[i+20])/2
                    - 0.02102974 * ((Open[i+21] + High[i+21] + Low[i+21] + Close[i+21])/4 + Open[i+21])/2
                    - 0.02216516 * ((Open[i+22] + High[i+22] + Low[i+22] + Close[i+22])/4 + Open[i+22])/2
                    - 0.02234315 * ((Open[i+23] + High[i+23] + Low[i+23] + Close[i+23])/4 + Open[i+23])/2
                    - 0.02165992 * ((Open[i+24] + High[i+24] + Low[i+24] + Close[i+24])/4 + Open[i+24])/2
                    - 0.02022973 * ((Open[i+25] + High[i+25] + Low[i+25] + Close[i+25])/4 + Open[i+25])/2
                    - 0.01818026 * ((Open[i+26] + High[i+26] + Low[i+26] + Close[i+26])/4 + Open[i+26])/2
                    - 0.01564777 * ((Open[i+27] + High[i+27] + Low[i+27] + Close[i+27])/4 + Open[i+27])/2
                    - 0.01277219 * ((Open[i+28] + High[i+28] + Low[i+28] + Close[i+28])/4 + Open[i+28])/2
                    - 0.00969230 * ((Open[i+29] + High[i+29] + Low[i+29] + Close[i+29])/4 + Open[i+29])/2
                    - 0.00654127 * ((Open[i+30] + High[i+30] + Low[i+30] + Close[i+30])/4 + Open[i+30])/2
                    - 0.00344276 * ((Open[i+31] + High[i+31] + Low[i+31] + Close[i+31])/4 + Open[i+31])/2
                    - 0.00050728 * ((Open[i+32] + High[i+32] + Low[i+32] + Close[i+32])/4 + Open[i+32])/2
                    + 0.00217042 * ((Open[i+33] + High[i+33] + Low[i+33] + Close[i+33])/4 + Open[i+33])/2
                    + 0.00451354 * ((Open[i+34] + High[i+34] + Low[i+34] + Close[i+34])/4 + Open[i+34])/2
                    + 0.00646441 * ((Open[i+35] + High[i+35] + Low[i+35] + Close[i+35])/4 + Open[i+35])/2
                    + 0.00798513 * ((Open[i+36] + High[i+36] + Low[i+36] + Close[i+36])/4 + Open[i+36])/2
                    + 0.00905725 * ((Open[i+37] + High[i+37] + Low[i+37] + Close[i+37])/4 + Open[i+37])/2
                    + 0.00968091 * ((Open[i+38] + High[i+38] + Low[i+38] + Close[i+38])/4 + Open[i+38])/2
                    + 0.00987326 * ((Open[i+39] + High[i+39] + Low[i+39] + Close[i+39])/4 + Open[i+39])/2
                    + 0.00966639 * ((Open[i+40] + High[i+40] + Low[i+40] + Close[i+40])/4 + Open[i+40])/2
                    + 0.00910488 * ((Open[i+41] + High[i+41] + Low[i+41] + Close[i+41])/4 + Open[i+41])/2
                    + 0.00824306 * ((Open[i+42] + High[i+42] + Low[i+42] + Close[i+42])/4 + Open[i+42])/2
                    + 0.00714199 * ((Open[i+43] + High[i+43] + Low[i+43] + Close[i+43])/4 + Open[i+43])/2
                    + 0.00586655 * ((Open[i+44] + High[i+44] + Low[i+44] + Close[i+44])/4 + Open[i+44])/2
                    + 0.00448255 * ((Open[i+45] + High[i+45] + Low[i+45] + Close[i+45])/4 + Open[i+45])/2
                    + 0.00305396 * ((Open[i+46] + High[i+46] + Low[i+46] + Close[i+46])/4 + Open[i+46])/2
                    + 0.00164061 * ((Open[i+47] + High[i+47] + Low[i+47] + Close[i+47])/4 + Open[i+47])/2
                    + 0.00029596 * ((Open[i+48] + High[i+48] + Low[i+48] + Close[i+48])/4 + Open[i+48])/2
                    - 0.00093445 * ((Open[i+49] + High[i+49] + Low[i+49] + Close[i+49])/4 + Open[i+49])/2
                    - 0.00201426 * ((Open[i+50] + High[i+50] + Low[i+50] + Close[i+50])/4 + Open[i+50])/2
                    - 0.00291701 * ((Open[i+51] + High[i+51] + Low[i+51] + Close[i+51])/4 + Open[i+51])/2
                    - 0.00362661 * ((Open[i+52] + High[i+52] + Low[i+52] + Close[i+52])/4 + Open[i+52])/2
                    - 0.00413703 * ((Open[i+53] + High[i+53] + Low[i+53] + Close[i+53])/4 + Open[i+53])/2
                    - 0.00445206 * ((Open[i+54] + High[i+54] + Low[i+54] + Close[i+54])/4 + Open[i+54])/2
                    - 0.00458437 * ((Open[i+55] + High[i+55] + Low[i+55] + Close[i+55])/4 + Open[i+55])/2
                    - 0.00455457 * ((Open[i+56] + High[i+56] + Low[i+56] + Close[i+56])/4 + Open[i+56])/2
                    - 0.00439006 * ((Open[i+57] + High[i+57] + Low[i+57] + Close[i+57])/4 + Open[i+57])/2
                    - 0.00412379 * ((Open[i+58] + High[i+58] + Low[i+58] + Close[i+58])/4 + Open[i+58])/2
                    - 0.00379323 * ((Open[i+59] + High[i+59] + Low[i+59] + Close[i+59])/4 + Open[i+59])/2
                    - 0.00343966 * ((Open[i+60] + High[i+60] + Low[i+60] + Close[i+60])/4 + Open[i+60])/2
                    - 0.00310850 * ((Open[i+61] + High[i+61] + Low[i+61] + Close[i+61])/4 + Open[i+61])/2
                    - 0.00285188 * ((Open[i+62] + High[i+62] + Low[i+62] + Close[i+62])/4 + Open[i+62])/2
                    - 0.00273508 * ((Open[i+63] + High[i+63] + Low[i+63] + Close[i+63])/4 + Open[i+63])/2
                    - 0.00274361 * ((Open[i+64] + High[i+64] + Low[i+64] + Close[i+64])/4 + Open[i+64])/2
                    + 0.01018757 * ((Open[i+65] + High[i+65] + Low[i+65] + Close[i+65])/4 + Open[i+65])/2;
      }
   }
   else {
      // data timeframe != chart timeframe
      int barLength = Period()*MINUTES - 1;

      for (i=changedBars-1; i >= 0; i--) {
         int offset = iBarShiftPrevious(NULL, dataTimeframe, Time[i]+barLength);
         buffer1[i] = iMTF(MODE_BUFFER1, offset); if (last_error != 0) return(last_error);
         buffer2[i] = iMTF(MODE_BUFFER2, offset); if (last_error != 0) return(last_error);
      }
   }

   if (!__isSuperContext) {
      double value = (buffer1[0]+buffer2[0]) / 2;
      color  clr   = ifInt(buffer1[0] > buffer2[0], Color.UpTrend, Color.DownTrend);
      UpdateTrendLegend(legendLabel, indicatorName, "", clr, clr, value, Digits, NULL, Time[0]);
   }
   return(last_error);
}


/**
 * Compute the bars to update of the current timeframe when using data of the specified other timeframe.
 *
 * @param  int  timeframe      [optional] - data timeframe (default: the current timeframe)
 * @param  bool limitStartTime [optional] - whether to limit the result to a configured starttime (default: yes)
 *
 * @return int - changed bars or -1 in case of errors
 */
int ComputeChangedBars(int timeframe = NULL, bool limitStartTime = true) {
   limitStartTime = limitStartTime!=0;
   int currentTimeframe = Period();
   if (!timeframe) timeframe = currentTimeframe;

   int bars, changedBars, startbar, filterLength = 66;

   if (timeframe == currentTimeframe) {
      // the displayed timeframe equals the chart timeframe
      static int _maxValues = -1; if (_maxValues < 0) {
         _maxValues = Mul(maxValues, ifInt(dataTimeframe > currentTimeframe, dataTimeframe/currentTimeframe, 1), /*boundaryOnOverflow=*/true);
      }
      changedBars = Min(ChangedBars, _maxValues);
      startbar    = Min(changedBars-1, Bars-filterLength);
      if (startbar < 0) return(_EMPTY(catch("ComputeChangedBars(1)  timeframe="+ TimeframeDescription(timeframe) +"  Bars="+ Bars +"  ChangedBars="+ changedBars +"  startbar="+ startbar, ERR_HISTORY_INSUFFICIENT)));
      if (limitStartTime) /*&&*/ if (Time[startbar]+currentTimeframe*MINUTES-1 < startTime)
         startbar = iBarShiftNext(NULL, NULL, startTime);
      changedBars = startbar + 1;
   }
   else {
      // the displayed timeframe is different from the chart timeframe
      // resolve startbar to update in the data timeframe
      bars        = iBars(NULL, timeframe);
      changedBars = Min(iChangedBars(NULL, timeframe), maxValues);
      startbar    = Min(changedBars-1, bars-filterLength);
      if (startbar < 0) return(_EMPTY(catch("ComputeChangedBars(2)  timeframe="+ TimeframeDescription(timeframe) +"  bars="+ bars +"  changedBars="+ changedBars +"  startbar="+ startbar, ERR_HISTORY_INSUFFICIENT)));

      // resolve corresponding bar offset in the current timeframe
      startbar = iBarShiftNext(NULL, NULL, iTime(NULL, timeframe, startbar));

      // cross-check the changed bars of the current timeframe against the data timeframe
      changedBars = Max(startbar+1, ComputeChangedBars(currentTimeframe, false));
      startbar    = changedBars - 1;
      if (limitStartTime) /*&&*/ if (Time[startbar]+currentTimeframe*MINUTES-1 < startTime)
         startbar = iBarShiftNext(NULL, NULL, startTime);
      changedBars = startbar + 1;
   }
   return(changedBars);
}


/**
 * Load the indicator again and return a value from another timeframe.
 *
 * @param  int iBuffer - indicator buffer index of the value to return
 * @param  int iBar    - bar index of the value to return
 *
 * @return double - indicator value or NULL in case of errors
 */
double iMTF(int iBuffer, int iBar) {
   static int lpSuperContext = 0; if (!lpSuperContext)
      lpSuperContext = GetIntsAddress(__ExecutionContext);

   double value = iCustom(NULL, dataTimeframe, WindowExpertName(),
                          "current",                              // string Timeframe
                          CLR_NONE,                               // color  Color.UpTrend
                          CLR_NONE,                               // color  Color.DownTrend
                          StartDate,                              // string StartDate
                          Max.Bars,                               // int    Max.Bars
                          "",                                     // string ________________
                          false,                                  // bool   AutoConfiguration
                          lpSuperContext,                         // int    __lpSuperContext

                          iBuffer, iBar);

   int error = GetLastError();
   if (error != NO_ERROR) {
      if (error != ERS_HISTORY_UPDATE)
         return(!catch("iMTF(1)", error));
      logWarn("iMTF(2)  "+ TimeframeDescription(dataTimeframe) +" (tick="+ Ticks +")", ERS_HISTORY_UPDATE);
   }

   error = __ExecutionContext[EC.mqlError];                       // TODO: synchronize execution contexts
   if (!error)
      return(value);
   return(!SetLastError(error));
}


/**
 * Workaround for various terminal bugs when setting indicator options. Usually options are set in init(). However after
 * recompilation options must be set in start() to not be ignored.
 */
void SetIndicatorOptions() {
   SetIndexStyle(MODE_BUFFER1, DRAW_HISTOGRAM, EMPTY, 5, Color.UpTrend  );
   SetIndexStyle(MODE_BUFFER2, DRAW_HISTOGRAM, EMPTY, 5, Color.DownTrend);
}


/**
 * Return a string representation of the input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("Color.UpTrend=",   ColorToStr(Color.UpTrend),     ";", NL,
                            "Color.DownTrend=", ColorToStr(Color.DownTrend),   ";", NL,
                            "MTF.Timeframe=",   DoubleQuoteStr(MTF.Timeframe), ";", NL,
                            "StartDate=",       DoubleQuoteStr(StartDate),     ";", NL,
                            "Max.Bars=",        Max.Bars,                      ";")
   );
}
