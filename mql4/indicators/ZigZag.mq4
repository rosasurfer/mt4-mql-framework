/**
 * ZigZag
 *
 * The ZigZag indicator provided by MetaQuotes is very much useless. Not only is the computation broken but it also heavily
 * repaints. Furthermore it can't be used in automated trading. This implementation fixes those issues and is significantly
 * faster. The ZigZag deviation parameter is hardcoded to 0 (zero).
 */
#include <stddefines.mqh>
int   __InitFlags[];
int __DeinitFlags[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern int Periods           = 5;         // Lookback periods to build the ZigZag high/low channel (a Donchian channel).        // orig: 12, MoneyZilla: 5
extern int MinPeriodDistance = 3;         // Minimum number of periods between ZigZag highs/lows (horizontal distance).

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <rsfLibs.mqh>

#define MODE_ZIGZAG        0              // indicator buffer ids
#define MODE_ZIGZAG_TOP    1
#define MODE_ZIGZAG_BOTTOM 2
#define MODE_UPPER_BAND    3
#define MODE_LOWER_BAND    4

#property indicator_chart_window
#property indicator_buffers 5

#property indicator_color1  Blue          // main ZigZag line
#property indicator_width1  2
#property indicator_style1  STYLE_SOLID

#property indicator_color2  CLR_NONE
#property indicator_color3  CLR_NONE

#property indicator_color4  DodgerBlue    // upper Donchian channel band
#property indicator_width4  1
#property indicator_style4  STYLE_DOT

#property indicator_color5  Magenta       // lower Donchian channel band
#property indicator_width5  1
#property indicator_style5  STYLE_DOT

double zigzag   [];                       // actual ZigZag points (final result)
double zTops    [];                       // potential upper ZigZag turning points
double zBottoms [];                       // potential lower ZigZag turning points
double upperBand[];                       // upper Donchian channel band
double lowerBand[];                       // lower Donchian channel band

#define ZZ_ANY       0                    // ids defining types of price extremes
#define ZZ_TOP       1
#define ZZ_BOTTOM    2


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   SetIndexBuffer(MODE_ZIGZAG,        zigzag   ); SetIndexEmptyValue(MODE_ZIGZAG,        0); SetIndexLabel(MODE_ZIGZAG,        "ZigZag"    );
   SetIndexBuffer(MODE_ZIGZAG_TOP,    zTops    ); SetIndexEmptyValue(MODE_ZIGZAG_TOP,    0); SetIndexLabel(MODE_ZIGZAG_TOP,    "zTops"     );
   SetIndexBuffer(MODE_ZIGZAG_BOTTOM, zBottoms ); SetIndexEmptyValue(MODE_ZIGZAG_BOTTOM, 0); SetIndexLabel(MODE_ZIGZAG_BOTTOM, "zBottoms"  );
   SetIndexBuffer(MODE_UPPER_BAND,    upperBand); SetIndexEmptyValue(MODE_UPPER_BAND,    0); SetIndexLabel(MODE_UPPER_BAND,    "upper band");
   SetIndexBuffer(MODE_LOWER_BAND,    lowerBand); SetIndexEmptyValue(MODE_LOWER_BAND,    0); SetIndexLabel(MODE_LOWER_BAND,    "lower band");

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
      ArrayInitialize(zigzag,   0);
      ArrayInitialize(zTops,    0);
      ArrayInitialize(zBottoms, 0);
      SetIndicatorOptions();
   }

   // synchronize buffers with a shifted offline chart
   if (ShiftedBars > 0) {
      ShiftIndicatorBuffer(zigzag,   Bars, ShiftedBars, 0);
      ShiftIndicatorBuffer(zTops,    Bars, ShiftedBars, 0);
      ShiftIndicatorBuffer(zBottoms, Bars, ShiftedBars, 0);
   }

   // -- TODO ---------------------------------------------------------------------------------------------------------------
   // GBPUSD,M15 06.08.2021 10:15 broken: both bar High and Low crossed the Donchian channel
   // GBPUSD,M15 10.08.2021 01:00 broken: both bar High and Low crossed the Donchian channel
   // GBPUSD,M15 16.08.2021 14:15 broken: both bar High and Low crossed the Donchian channel
   // -----------------------------------------------------------------------------------------------------------------------





   // old -------------------------------------------------------------------------------------------------------------------
   int startbar, nextZigzag;
   double currentHigh, currentLow;

   // calculate startbar
   if (!ValidBars) {
      startbar    = Bars - Periods;
      currentHigh = 0;
      currentLow  = 0;
      nextZigzag  = ZZ_ANY;
   }
   else {
      for (int i, count=0; count < 3 && i < 100; i++) {  // find the last 3 ZigZags over 100 bars
         if (zigzag[i] != 0) count++;
      }
      startbar = i-1;                                    // on every tick: repaint 3 ZigZags or 100 bars, this is so wrong...

      if (zBottoms[startbar] != 0) {
         currentLow = zBottoms[startbar];
         nextZigzag = ZZ_TOP;
      }
      else {
         currentHigh = zTops[startbar];
         nextZigzag  = ZZ_BOTTOM;
      }

      for (i=startbar-1; i >= 0; i--) {                  // reset the range to repaint
         zigzag  [i] = 0;
         zTops   [i] = 0;
         zBottoms[i] = 0;
      }
   }

   double high, prevHigh, low, prevLow;
   int iH, iL;


   // update zTops[] buffer
   for (int bar=startbar; bar >= 0; bar--) {
      zTops[bar] = 0;
      high = High[iHighest(NULL, NULL, MODE_HIGH, Periods, bar)];
      upperBand[bar] = high;
      if (high == prevHigh) continue;
      if (high == High[bar]) zTops[bar] = high;

      for (i=1; i <= MinPeriodDistance; i++) {
         if (high > zTops[bar+i]) zTops[bar+i] = 0;
      }
      prevHigh = high;
   }


   // update zBottoms[] buffer
   for (bar=startbar; bar >= 0; bar--) {
      zBottoms[bar] = 0;
      low = Low[iLowest(NULL, NULL, MODE_LOW, Periods, bar)];
      lowerBand[bar] = low;
      if (low == prevLow) continue;
      if (low == Low[bar]) zBottoms[bar] = low;

      for (i=1; i <= MinPeriodDistance; i++) {
         if (zBottoms[bar+i] > low) zBottoms[bar+i] = 0;
      }
      prevLow = low;
   }


   // recalculate invalid zigzag[] range
   double lastHigh, lastLow;
   if (nextZigzag == ZZ_ANY) { lastHigh = 0;           lastLow = 0;          }
   else                      { lastHigh = currentHigh; lastLow = currentLow; }

   int iLastHigh, iLastLow;

   for (bar=startbar; bar >= 0; bar--) {
      switch (nextZigzag) {
         case ZZ_ANY:                     // look for both a new top or bottom
            if (!lastLow && !lastHigh) {
               if (zTops[bar] != 0) {
                  lastHigh    = High[bar];
                  iLastHigh   = bar;
                  zigzag[bar] = lastHigh;
                  nextZigzag  = ZZ_BOTTOM;
               }
               if (zBottoms[bar] != 0) {
                  lastLow     = Low[bar];
                  iLastLow    = bar;
                  zigzag[bar] = lastLow;
                  nextZigzag  = ZZ_TOP;
               }
            }
            break;

         case ZZ_TOP:                     // look for a new top
            if (zBottoms[bar] && zBottoms[bar] < lastLow && !zTops[bar]) {
               zigzag[iLastLow] = 0;
               lastLow          = zBottoms[bar];
               iLastLow         = bar;
               zigzag[bar]      = lastLow;
            }
            if (zTops[bar] && !zBottoms[bar]) {
               lastHigh    = zTops[bar];
               iLastHigh   = bar;
               zigzag[bar] = lastHigh;
               nextZigzag  = ZZ_BOTTOM;
            }
            break;

         case ZZ_BOTTOM:                  // look for a new bottom
            if (zTops[bar] > lastHigh && !zBottoms[bar]) {
               zigzag[iLastHigh] = 0;
               lastHigh          = zTops[bar];
               iLastHigh         = bar;
               zigzag[bar]       = lastHigh;
            }
            if (zBottoms[bar] && !zTops[bar]) {
               lastLow     = zBottoms[bar];
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

   SetIndexStyle(MODE_ZIGZAG,        DRAW_SECTION);
   SetIndexStyle(MODE_ZIGZAG_TOP,    DRAW_NONE);
   SetIndexStyle(MODE_ZIGZAG_BOTTOM, DRAW_NONE);
   SetIndexStyle(MODE_UPPER_BAND,    DRAW_LINE);
   SetIndexStyle(MODE_LOWER_BAND,    DRAW_LINE);
}
