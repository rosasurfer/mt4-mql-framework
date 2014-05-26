//+------------------------------------------------------------------+
//|                                                Parabolic SAR.mq4 |
//|                      Copyright © 2012, MetaQuotes Software Corp. |
//|                                       http://www.metaquotes.net/ |
//+------------------------------------------------------------------+
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <stdlib.mqh>

//////////////////////////////////////////////////////////////////////////////// Konfiguration ////////////////////////////////////////////////////////////////////////////////

extern double StepSize    = 0.02;
extern double StepMaximum = 0.2;

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>

#property indicator_chart_window
#property indicator_buffers   1
#property indicator_color1    Lime


// buffer
double SarBuffer[];

int    save_lastreversal;
bool   save_dirlong;
double save_step;
double save_last_high;
double save_last_low;
double save_ep;
double save_sar;


/**
 *
 */
int onInit() {
   SetIndexBuffer(0, SarBuffer );
   SetIndexStyle (0, DRAW_ARROW);
   SetIndexArrow (0, 159       );
   IndicatorDigits(MarketInfo(Symbol(), MODE_DIGITS));
   return(0);
}


/**
 *
 */
void SaveLastReversal(int last, bool dir, double step, double low, double high, double ep, double sar) {
   save_lastreversal = last;
   save_dirlong      = dir;
   save_step         = step;
   save_last_low     = low;
   save_last_high    = high;
   save_ep           = ep;
   save_sar          = sar;
}


/**
 *
 */
int onTick() {
   bool   dirlong;
   double last_high, last_low, ep, step, sar, prevSar;
   int    i, counted_bars=IndicatorCounted();

   // nothing to calculate
   if (Bars < 3)
      return(0);

   // first calculation?
   if (!counted_bars) {
      // initial settings
      ArrayInitialize(SarBuffer, 0);
      i                 = Bars-2;
      dirlong           = true;
      step              = StepSize;
      last_high         = -10000000;
      last_low          =  10000000;
      save_lastreversal = 0;
      sar               = 0;

      while (i > 0) {
         save_lastreversal = i;
         if (last_low > Low[i])
            last_low = Low[i];
         if (last_high < High[i])
            last_high = High[i];
         if (High[i] > High[i+1] && Low[i] > Low[i+1]) {
            dirlong = true;
            break;
         }
         if (High[i] < High[i+1] && Low[i] < Low[i+1]) {
            dirlong = false;
            break;
         }
         i--;
      }

      // check further
      if (dirlong) { SarBuffer[i] = Low [i+1]; ep = High[i]; }
      else         { SarBuffer[i] = High[i+1]; ep = Low [i]; }
      i--;
   }
   else {
      // restore values from previous call to avoid full recalculation
      i         = save_lastreversal;
      step      = save_step;
      dirlong   = save_dirlong;
      last_high = save_last_high;
      last_low  = save_last_low;
      ep        = save_ep;
      sar       = save_sar;
   }



   debug("start()   i="+ i);


   // -----------------------
   for (; i >= 0; i--) {
      prevSar = SarBuffer[i+1];
      // check for reversal
      if (dirlong && Low[i] < prevSar) {
         SaveLastReversal(i+1, true, step, Low[i], last_high, ep, sar);
         step         = StepSize;
         dirlong      = false;
         ep           = Low[i];
         last_low     = Low[i];
         SarBuffer[i] = last_high;
         continue;
      }
      if (!dirlong && High[i] > prevSar) {
         SaveLastReversal(i+1, false, step, last_low, High[i], ep, sar);
         step         = StepSize;
         dirlong      = true;
         ep           = High[i];
         last_high    = High[i];
         SarBuffer[i] = last_low;
         continue;
      }

      // calculate indicator value
      sar = prevSar + step * (ep-prevSar);

      if (dirlong) {
         if (ep < High[i] && (step+StepSize)<=StepMaximum)
            step += StepSize;
         if (High[i] < High[i+1] && i==Bars-2)
            sar = prevSar;
         if (sar > Low[i+1]) sar = Low[i+1];
         if (sar > Low[i+2]) sar = Low[i+2];
         if (sar > Low[i]) {
            SaveLastReversal(i+1, true, step, Low[i], last_high, ep, sar);
            step         = StepSize;
            dirlong      = false;
            last_low     = Low[i];
            ep           = Low[i];
            SarBuffer[i] = last_high;
            continue;
         }
         if (ep < High[i]) {
            last_high = High[i];
            ep        = High[i];
         }
      }
      else {
         if (ep > Low[i] && (step+StepSize)<=StepMaximum)
            step += StepSize;
         if (Low[i] < Low[i+1] && i==Bars-2)
            sar = prevSar;
         if (sar < High[i+1]) sar = High[i+1];
         if (sar < High[i+2]) sar = High[i+2];
         if (sar < High[i]) {
            SaveLastReversal(i+1, false, step, last_low, High[i], ep, sar);
            step         = StepSize;
            dirlong      = true;
            last_high    = High[i];
            ep           = High[i];
            SarBuffer[i] = last_low;
            continue;
         }
         if (ep > Low[i]) {
            last_low = Low[i];
            ep       = Low[i];
         }
      }
      SarBuffer[i] = sar;
   }


   /*
   double iSar = iSAR(NULL, 0, StepSize, StepMaximum, 0);
   if (SarBuffer[0] != iSar)
      debug("start()   custom="+ NumberToStr(SarBuffer[0], PriceFormat) +"   iSAR="+ NumberToStr(iSar, PriceFormat) +"   ValidBars="+ ValidBars +"  ChangedBars="+ ChangedBars);
   */
   return(catch("start()"));
}
