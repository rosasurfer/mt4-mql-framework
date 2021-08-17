/**
 * ZigZag
 *
 * The ZigZag indicator provided by MetaQuotes is very much useless. The used algorythm has nothing in common with the real
 * ZigZag calculation formula, also the indicator heavily repaints. Furthermore it can't be used in automated trading.
 *
 * This version replaces the ZigZag deviation parameter by a Donchian channel to make the indicator more universal and
 * accurate. It's significantly faster and can be used for auto-trading.
 */
#include <stddefines.mqh>
int   __InitFlags[];
int __DeinitFlags[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern int Periods = 5;                   // lookback periods of the Donchian channel                                         // orig: 12, MZ: 5

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <rsfLibs.mqh>

#define MODE_ZIGZAG           0           // indicator buffer ids
#define MODE_ZIGZAG_HIGH      1
#define MODE_ZIGZAG_LOW       2
#define MODE_DONCHIAN_UPPER   3
#define MODE_DONCHIAN_LOWER   4

#property indicator_chart_window
#property indicator_buffers   5

#property indicator_color1    Gold        // SaddleBrown Blue, main ZigZag line
#property indicator_width1    2

#property indicator_color2    DodgerBlue  // potential ZigZag high turning points
#property indicator_width2    1

#property indicator_color3    Magenta     // potential ZigZag low turning points
#property indicator_width3    1

#property indicator_color4    DodgerBlue  // upper Donchian channel band
#property indicator_style4    STYLE_DOT

#property indicator_color5    Magenta     // lower Donchian channel band
#property indicator_style5    STYLE_DOT

double zigzag [];                         // actual ZigZag points
double zHighs [];                         // potential ZigZag high turning points
double zLows  [];                         // potential ZigZag low turning points
double dcUpper[];                         // upper Donchian channel band
double dcLower[];                         // lower Donchian channel band

#define ZZ_ANY       0                    // ids defining types of price extremes
#define ZZ_TOP       1
#define ZZ_BOTTOM    2


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   SetIndexBuffer(MODE_ZIGZAG,         zigzag ); SetIndexEmptyValue(MODE_ZIGZAG,         0); SetIndexLabel(MODE_ZIGZAG,         "ZigZag");
   SetIndexBuffer(MODE_ZIGZAG_HIGH,    zHighs ); SetIndexEmptyValue(MODE_ZIGZAG_HIGH,    0); SetIndexLabel(MODE_ZIGZAG_HIGH,    "zHighs");
   SetIndexBuffer(MODE_ZIGZAG_LOW,     zLows  ); SetIndexEmptyValue(MODE_ZIGZAG_LOW,     0); SetIndexLabel(MODE_ZIGZAG_LOW,     "zLows");
   SetIndexBuffer(MODE_DONCHIAN_UPPER, dcUpper); SetIndexEmptyValue(MODE_DONCHIAN_UPPER, 0); SetIndexLabel(MODE_DONCHIAN_UPPER, "Donchian upper");
   SetIndexBuffer(MODE_DONCHIAN_LOWER, dcLower); SetIndexEmptyValue(MODE_DONCHIAN_LOWER, 0); SetIndexLabel(MODE_DONCHIAN_LOWER, "Donchian lower");

   SetIndicatorOptions();
   IndicatorDigits(Digits);
   IndicatorShortName(ProgramName());
   return(0);
}


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   // on the first tick after terminal start buffers may not yet be initialized (spurious issue)
   if (!ArraySize(zigzag)) return(logInfo("onTick(1)  size(zigzag) = 0", SetLastError(ERS_TERMINAL_NOT_YET_READY)));

   // reset buffers before performing a full recalculation
   if (!ValidBars) {
      ArrayInitialize(zigzag,  0);
      ArrayInitialize(zHighs,  0);
      ArrayInitialize(zLows,   0);
      ArrayInitialize(dcUpper, 0);
      ArrayInitialize(dcLower, 0);
      SetIndicatorOptions();
   }

   // synchronize buffers with a shifted offline chart
   if (ShiftedBars > 0) {
      ShiftIndicatorBuffer(zigzag,  Bars, ShiftedBars, 0);
      ShiftIndicatorBuffer(zHighs,  Bars, ShiftedBars, 0);
      ShiftIndicatorBuffer(zLows,   Bars, ShiftedBars, 0);
      ShiftIndicatorBuffer(dcUpper, Bars, ShiftedBars, 0);
      ShiftIndicatorBuffer(dcLower, Bars, ShiftedBars, 0);
   }

   // calculate startbar
   int stdStartbar = Min(ChangedBars-1, Bars-Periods);
   if (stdStartbar < 0) return(logInfo("onTick(2)  Tick="+ Tick, ERR_HISTORY_INSUFFICIENT));

   // update Donchian channel and potential turning points
   for (int bar=stdStartbar; bar >= 0; bar--) {
      dcUpper[bar] = High[iHighest(NULL, NULL, MODE_HIGH, Periods, bar)];
      dcLower[bar] =  Low[ iLowest(NULL, NULL, MODE_LOW,  Periods, bar)];
   }



   // -- TODO ---------------------------------------------------------------------------------------------------------------
   // GBPUSD,M15 06.08.2021 10:15 broken: both bar High and Low crossed the Donchian channel
   // GBPUSD,M15 10.08.2021 01:00 broken: both bar High and Low crossed the Donchian channel
   // GBPUSD,M15 16.08.2021 14:15 broken: both bar High and Low crossed the Donchian channel
   //
   // old -------------------------------------------------------------------------------------------------------------------
   int zzStartbar, nextZigzag;
   double currentHigh, currentLow;

   // calculate startbar
   if (!ValidBars) {
      zzStartbar = Bars - Periods;
      nextZigzag = ZZ_ANY;
   }
   else {
      for (int i, count=0; count < 3 && i < 100; i++) {  // find the last 3 ZigZags over 100 bars
         if (zigzag[i] != 0) count++;
      }
      zzStartbar = i-1;                                  // on every tick: repaint 3 ZigZags or 100 bars, this is so wrong...

      if (zLows[zzStartbar] != 0) {
         currentLow = zLows[zzStartbar];
         nextZigzag = ZZ_TOP;
      }
      else {
         currentHigh = zHighs[zzStartbar];
         nextZigzag  = ZZ_BOTTOM;
      }

      for (i=zzStartbar-1; i >= 0; i--) {                // reset the range to repaint
         zigzag[i] = 0;
      }
   }


   // update potential turning points
   double high, prevHigh, low, prevLow;

   for (bar=zzStartbar; bar >= 0; bar--) {
      zHighs[bar] = 0;
      high = dcUpper[bar];
      if (high!=prevHigh && High[bar]==high) zHighs[bar] = high;
      prevHigh = high;

      zLows[bar] = 0;
      low = dcLower[bar];
      if (low!=prevLow && Low[bar]==low) zLows[bar] = low;
      prevLow = low;
   }


   // recalculate zigzag[] range
   double lastHigh = currentHigh;
   double lastLow  = currentLow;
   int iLastHigh, iLastLow;

   for (bar=zzStartbar; bar >= 0; bar--) {
      switch (nextZigzag) {
         case ZZ_ANY:                     // look for both a new top or bottom
            if (zHighs[bar] != 0) {
               lastHigh    = High[bar];
               iLastHigh   = bar;
               zigzag[bar] = lastHigh;
               nextZigzag  = ZZ_BOTTOM;
            }
            if (zLows[bar] != 0) {
               lastLow     = Low[bar];
               iLastLow    = bar;
               zigzag[bar] = lastLow;
               nextZigzag  = ZZ_TOP;
            }
            break;

         case ZZ_TOP:                     // look for a new top
            if (zLows[bar] && zLows[bar] < lastLow && !zHighs[bar]) {
               zigzag[iLastLow] = 0;
               lastLow          = zLows[bar];
               iLastLow         = bar;
               zigzag[bar]      = lastLow;
            }
            if (zHighs[bar] && !zLows[bar]) {
               lastHigh    = zHighs[bar];
               iLastHigh   = bar;
               zigzag[bar] = lastHigh;
               nextZigzag  = ZZ_BOTTOM;
            }
            break;

         case ZZ_BOTTOM:                  // look for a new bottom
            if (zHighs[bar] > lastHigh && !zLows[bar]) {
               zigzag[iLastHigh] = 0;
               lastHigh          = zHighs[bar];
               iLastHigh         = bar;
               zigzag[bar]       = lastHigh;
            }
            if (zLows[bar] && !zHighs[bar]) {
               lastLow     = zLows[bar];
               iLastLow    = bar;
               zigzag[bar] = lastLow;
               nextZigzag  = ZZ_TOP;
            }
            break;

         default:
            return(catch("onTick(2)  illegal value of var nextZigzag: "+ nextZigzag, ERR_ILLEGAL_STATE));
      }
   }
   return(catch("onTick(3)"));
}


/**
 * Workaround for various terminal bugs when setting indicator options. Usually options are set in init(). However after
 * recompilation options must be set in start() to not be ignored.
 */
void SetIndicatorOptions() {
   //SetIndexStyle(int index, int drawType, int lineStyle=EMPTY, int drawWidth=EMPTY, color drawColor=NULL);

   SetIndexStyle(MODE_ZIGZAG,      DRAW_SECTION); SetIndexArrow(MODE_ZIGZAG,      108);   // full circle
   SetIndexStyle(MODE_ZIGZAG_HIGH,   DRAW_ARROW); SetIndexArrow(MODE_ZIGZAG_HIGH, 161);   // open circle
   SetIndexStyle(MODE_ZIGZAG_LOW,    DRAW_ARROW); SetIndexArrow(MODE_ZIGZAG_LOW,  161);   // ...
   SetIndexStyle(MODE_DONCHIAN_UPPER, DRAW_LINE);
   SetIndexStyle(MODE_DONCHIAN_LOWER, DRAW_LINE);
}
