/**
 * ZigZag
 *
 *
 * Input parameters:
 * -----------------
 * • Depth:  Minimum number of periods on which the ZigZag will not make the maximum and minimum if the conditions of the
 *    first number are necessary for the construction to happen.
 *    Defines how many periods to look back for highs and lows.
 *
 * • Deviation:  Minimum number of points expressed as a percentage between highs and lows of neighbouring candlesticks.
 *    "5" means that price changes of less than 5% are ignored.
 *    Minimum price change parameter determines the percentage for the price to move in order to form a new line leg.
 *
 * • Backstep:  Minimum number of periods between consecutive ZigZag highs and lows.
 *
 * @see  https://www.mql5.com/en/code/11094                                                    [ZigZagZug, Fernando Carreiro]
 * @see  https://www.mql5.com/en/code/10076                                                       [ZigZag-Orlov, Denis Orlov]
 */
#include <stddefines.mqh>
int   __InitFlags[];
int __DeinitFlags[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern int Depth     = 12;                   // MoneyZilla: 5
extern int Deviation = 5;
extern int Backstep  = 3;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <rsfLibs.mqh>

#property indicator_chart_window

#property indicator_buffers 1
#property indicator_color1  Blue
#property indicator_width1  1

double bufferZZ   [];
double bufferHighs[];
double bufferLows [];

int    level = 3;                            // recounting depth


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   IndicatorBuffers(3);
   SetIndexBuffer(0, bufferZZ   ); SetIndexStyle(0, DRAW_SECTION); SetIndexEmptyValue(0, 0);
   SetIndexBuffer(1, bufferHighs);
   SetIndexBuffer(2, bufferLows );
   IndicatorShortName("ZigZag("+ Depth +","+ Deviation +","+ Backstep +")");
   return(0);
}


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   // on the first tick after terminal start buffers may not yet be initialized (spurious issue)
   if (!ArraySize(bufferZZ)) return(logInfo("onTick(1)  size(bufferZZ) = 0", SetLastError(ERS_TERMINAL_NOT_YET_READY)));

   // reset buffers before performing a full recalculation
   if (!ValidBars) {
      ArrayInitialize(bufferZZ,              0);
      ArrayInitialize(bufferHighs, EMPTY_VALUE);
      ArrayInitialize(bufferLows,  EMPTY_VALUE);
      SetIndicatorOptions();
   }

   // synchronize buffers with a shifted offline chart
   if (ShiftedBars > 0) {
      ShiftIndicatorBuffer(bufferZZ,    Bars, ShiftedBars,           0);
      ShiftIndicatorBuffer(bufferHighs, Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(bufferLows,  Bars, ShiftedBars, EMPTY_VALUE);
   }



   // old
   int i, startbar, counterZ, whatlookfor, lasthighpos, lastlowpos;
   double val, res, curlow, curhigh, lasthigh, lastlow;

   if (!ValidBars) {
      startbar = Bars - Depth;
   }

   if (ValidBars > 0) {
      while (counterZ < level && i < 100) {
         res = bufferZZ[i];
         if (res != 0) counterZ++;
         i++;
      }
      i--;
      startbar = i;

      if (bufferLows[i] != 0) {
         curlow      = bufferLows[i];
         whatlookfor = 1;
      }
      else {
         curhigh     = bufferHighs[i];
         whatlookfor = -1;
      }

      for (i=startbar-1; i >= 0; i--) {
         bufferZZ   [i] = 0;
         bufferLows [i] = 0;
         bufferHighs[i] = 0;
      }
   }

   // recalculate highs and lows
   for (int bar=startbar; bar >= 0; bar--) {
      // lows
      val = Low[iLowest(NULL, NULL, MODE_LOW, Depth, bar)];
      if (val == lastlow) {
         val = 0;
      }
      else {
         lastlow = val;
         if (Low[bar]-val > Deviation*Point) {
            val = 0;
         }
         else {
            for (i=1; i <= Backstep; i++) {
               res = bufferLows[bar+i];
               if (res && res > val) bufferLows[bar+i] = 0;
            }
         }
      }
      if (Low[bar] == val) bufferLows[bar] = val;
      else                 bufferLows[bar] = 0;

      // highs
      val = High[iHighest(NULL, NULL, MODE_HIGH, Depth, bar)];
      if (val == lasthigh) {
         val = 0;
      }
      else {
         lasthigh = val;
         if (val-High[bar] > Deviation*Point) {
            val = 0;
         }
         else {
            for(i=1; i <= Backstep; i++) {
               res = bufferHighs[bar+i];
               if (res && res < val) bufferHighs[bar+i] = 0;
            }
         }
      }
      if (High[bar] == val) bufferHighs[bar] = val;
      else                  bufferHighs[bar] = 0;
   }

   // recalculate zigzag
   if (whatlookfor == 0) {
      lastlow  = 0;
      lasthigh = 0;
   }
   else {
      lastlow  = curlow;
      lasthigh = curhigh;
   }

   for (bar=startbar; bar >= 0; bar--) {
      switch (whatlookfor) {
         case 0:  // look for peak or lawn
            if (!lastlow && !lasthigh) {
               if (bufferHighs[bar] != 0) {
                  lasthigh      = High[bar];
                  lasthighpos   = bar;
                  whatlookfor   = -1;
                  bufferZZ[bar] = lasthigh;
               }
               if (bufferLows[bar] != 0) {
                  lastlow       = Low[bar];
                  lastlowpos    = bar;
                  whatlookfor   = 1;
                  bufferZZ[bar] = lastlow;
               }
            }
            break;

         case 1:  // look for peak
            if (bufferLows[bar] && bufferLows[bar] < lastlow && !bufferHighs[bar]) {
               bufferZZ[lastlowpos] = 0;
               lastlowpos           = bar;
               lastlow              = bufferLows[bar];
               bufferZZ[bar]        = lastlow;
            }
            if (bufferHighs[bar] && !bufferLows[bar]) {
               lasthigh      = bufferHighs[bar];
               lasthighpos   = bar;
               bufferZZ[bar] = lasthigh;
               whatlookfor   = -1;
            }
            break;

         case -1: // look for lawn
            if (bufferHighs[bar] && bufferHighs[bar] > lasthigh && !bufferLows[bar]) {
               bufferZZ[lasthighpos] = 0;
               lasthighpos           = bar;
               lasthigh              = bufferHighs[bar];
               bufferZZ[bar]         = lasthigh;
            }
            if (bufferLows[bar] && !bufferHighs[bar]) {
               lastlow       = bufferLows[bar];
               lastlowpos    = bar;
               bufferZZ[bar] = lastlow;
               whatlookfor   = 1;
            }
            break;

         default:
            return(0);
      }
   }
   return(0);
}


/**
 * Workaround for various terminal bugs when setting indicator options. Usually options are set in init(). However after
 * recompilation options must be set in start() to not be ignored.
 */
void SetIndicatorOptions() {
}
