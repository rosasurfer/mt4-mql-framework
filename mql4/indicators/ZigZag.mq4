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

extern int Periods     = 5;               // lookback periods of the Donchian channel                                         // orig: 12, MZ: 5
extern int CrossSize   = 0;
extern int ProcessBars = 645;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <rsfLibs.mqh>

#define MODE_ZIGZAG0          0           // indicator buffer ids
#define MODE_ZIGZAG1          1
#define MODE_UPPER_BAND       2
#define MODE_LOWER_BAND       3
#define MODE_UPPER_CROSS      4
#define MODE_LOWER_CROSS      5
#define MODE_TREND            6
#define MODE_NOTREND          7

#property indicator_chart_window
#property indicator_buffers   8

#property indicator_color1    Blue        // main ZigZag line built from two buffers using the color of the first buffer
#property indicator_width1    2           // ...
#property indicator_color2    CLR_NONE    // ...
#property indicator_width2    2           // ...

#property indicator_color3    DodgerBlue  // upper channel band
#property indicator_style3    STYLE_DOT

#property indicator_color4    Magenta     // lower channel band
#property indicator_style4    STYLE_DOT

#property indicator_color5    DodgerBlue  // potential high turning points
#property indicator_color6    Magenta     // potential low turning points

double zigzag0   [];                      // ZigZag turning points (open price of a vertical segment)
double zigzag1   [];                      // ...                  (close price of a vertical segment)
double upperBand [];                      // upper channel band
double lowerBand [];                      // lower channel band
double upperCross[];                      // upper band crosses
double lowerCross[];                      // lower band crosses
double trend     [];                      // trend direction and length
double notrend   [];                      // periods with unknown/unfinished trend direction


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   SetIndexBuffer(MODE_ZIGZAG0,     zigzag0   ); SetIndexLabel(MODE_ZIGZAG0,     "ZigZag-0"     ); SetIndexEmptyValue(MODE_ZIGZAG0,     0);
   SetIndexBuffer(MODE_ZIGZAG1,     zigzag1   ); SetIndexLabel(MODE_ZIGZAG1,     "ZigZag-1"     ); SetIndexEmptyValue(MODE_ZIGZAG1,     0);
   SetIndexBuffer(MODE_UPPER_BAND,  upperBand ); SetIndexLabel(MODE_UPPER_BAND,  "upper band"   ); SetIndexEmptyValue(MODE_UPPER_BAND,  0);
   SetIndexBuffer(MODE_LOWER_BAND,  lowerBand ); SetIndexLabel(MODE_LOWER_BAND,  "lower band"   ); SetIndexEmptyValue(MODE_LOWER_BAND,  0);
   SetIndexBuffer(MODE_UPPER_CROSS, upperCross); SetIndexLabel(MODE_UPPER_CROSS, "upper crosses"); SetIndexEmptyValue(MODE_UPPER_CROSS, 0);
   SetIndexBuffer(MODE_LOWER_CROSS, lowerCross); SetIndexLabel(MODE_LOWER_CROSS, "lower crosses"); SetIndexEmptyValue(MODE_LOWER_CROSS, 0);
   SetIndexBuffer(MODE_TREND,       trend     ); SetIndexLabel(MODE_TREND,       "Trend"        ); SetIndexEmptyValue(MODE_TREND,       0);
   SetIndexBuffer(MODE_NOTREND,     notrend   ); SetIndexLabel(MODE_NOTREND,     "NoTrend"      ); SetIndexEmptyValue(MODE_NOTREND,     0);

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
   if (!ArraySize(zigzag0)) return(logInfo("onTick(1)  size(zigzag0) = 0", SetLastError(ERS_TERMINAL_NOT_YET_READY)));

   // reset buffers before performing a full recalculation
   if (!ValidBars) {
      ArrayInitialize(zigzag0,    0);
      ArrayInitialize(zigzag1,    0);
      ArrayInitialize(upperBand,  0);
      ArrayInitialize(lowerBand,  0);
      ArrayInitialize(upperCross, 0);
      ArrayInitialize(lowerCross, 0);
      ArrayInitialize(trend,      0);
      ArrayInitialize(notrend,    0);
      SetIndicatorOptions();
   }

   // synchronize buffers with a shifted offline chart
   if (ShiftedBars > 0) {
      ShiftIndicatorBuffer(zigzag0,    Bars, ShiftedBars, 0);
      ShiftIndicatorBuffer(zigzag1,    Bars, ShiftedBars, 0);
      ShiftIndicatorBuffer(upperBand,  Bars, ShiftedBars, 0);
      ShiftIndicatorBuffer(lowerBand,  Bars, ShiftedBars, 0);
      ShiftIndicatorBuffer(upperCross, Bars, ShiftedBars, 0);
      ShiftIndicatorBuffer(lowerCross, Bars, ShiftedBars, 0);
      ShiftIndicatorBuffer(trend,      Bars, ShiftedBars, 0);
      ShiftIndicatorBuffer(notrend,    Bars, ShiftedBars, 0);
   }

   // calculate startbar
   int startbar = Min(ChangedBars-1, Bars-Periods);
   if (startbar < 0) return(logInfo("onTick(2)  Tick="+ Tick, ERR_HISTORY_INSUFFICIENT));


   // recalculate Donchian channel and potential ZigZag turning points
   for (int bar=startbar; bar >= 0; bar--) {
      upperBand[bar] = High[iHighest(NULL, NULL, MODE_HIGH, Periods, bar)];
      lowerBand[bar] =  Low[ iLowest(NULL, NULL, MODE_LOW,  Periods, bar)];

      if (High[bar] == upperBand[bar]) upperCross[bar] = upperBand[bar];
      else                             upperCross[bar] = 0;

      if (Low[bar] == lowerBand[bar]) lowerCross[bar] = lowerBand[bar];
      else                            lowerCross[bar] = 0;
   }


   // recalculate ZigZag
   int prevOffset, prevTrend;

   for (bar=startbar; !ValidBars && bar >= 0; bar--) {
      zigzag0[bar] = 0;
      zigzag1[bar] = 0;
      trend  [bar] = 0;
      notrend[bar] = 0;

      // -- trend is unknown ------------------------------------------------------------------------------------------------
      if (!upperCross[bar] && !lowerCross[bar]) {
         debug("onTick(0.1)  Bar["+ bar +"] "+ TimeToStr(Time[bar], TIME_FULL) +"  no cross");
         notrend[bar] = Round(notrend[bar+1] + 1);                                     // increase unknown trend
      }

      // -- upper and lower band crossed by the same bar --------------------------------------------------------------------
      else if (upperCross[bar] && lowerCross[bar]) {
         debug("onTick(0.2)  Bar["+ bar +"] "+ TimeToStr(Time[bar], TIME_FULL) +"  both High and Low cross");

         if (WasUpperCrossFirst(bar)) {
            // first process the upper band cross
            prevOffset = bar + 1 + notrend[bar+1];
            prevTrend = trend[prevOffset];
            debug("onTick(0.3)  Bar["+ bar +"] "+ TimeToStr(Time[bar], TIME_FULL) +"  High cross first: prevOffset="+ prevOffset +", prevTrend="+ prevTrend);

            if (prevTrend > 0) {                                                       // an uptrend continuation
               if (upperCross[bar] > upperCross[prevOffset]) {                         // a trend extention
                  SetTrend(prevOffset, bar, prevTrend, "onTick(0.4)  Bar["+ bar +"]"); // reset unknown trend and update existing trend
                  zigzag0[prevOffset] = 0; zigzag0[bar] = upperCross[bar];
                  zigzag1[prevOffset] = 0; zigzag1[bar] = upperCross[bar];
               }
               else {                                                                  // a trend continuation with a lower high
                  notrend[bar] = Round(notrend[bar+1] + 1);                            // increase unknown trend
                  debug("onTick(0.5)  Bar["+ bar +"] "+ TimeToStr(Time[bar], TIME_FULL) +"  uptrend continuation with a lower high, stopping after "+ (startbar-bar) +" bars...");
                  break;
               }
            }
            else {                                                                     // a new uptrend
               SetTrend(prevOffset-1, bar, 1, "onTick(0.6)  Bar["+ bar +"]");          // reset unknown trend and mark a new uptrend
               zigzag0[bar] = upperCross[bar];
               zigzag1[bar] = upperCross[bar];
            }

            // then process the lower band cross
            SetTrend(bar, bar, -1, "onTick(0.7)  Bar["+ bar +"]");                     // mark a new downtrend
            zigzag1[bar] = lowerCross[bar];
         }
         else {
            // first process the lower band cross
            prevOffset = bar + 1 + notrend[bar+1];
            prevTrend = trend[prevOffset];
            debug("onTick(0.8)  Bar["+ bar +"] "+ TimeToStr(Time[bar], TIME_FULL) +"  Low cross first: prevOffset="+ prevOffset +", prevTrend="+ prevTrend);

            if (prevTrend < 0) {                                                       // a downtrend continuation
               if (lowerCross[bar] < lowerCross[prevOffset]) {                         // a trend extention
                  SetTrend(prevOffset, bar, prevTrend, "onTick(0.9)  Bar["+ bar +"]"); // reset unknown trend and update existing trend
                  zigzag0[prevOffset] = 0; zigzag0[bar] = lowerCross[bar];
                  zigzag1[prevOffset] = 0; zigzag1[bar] = lowerCross[bar];
               }
               else {                                                                  // a trend continuation with a higher low
                  notrend[bar] = Round(notrend[bar+1] + 1);                            // increase unknown trend
                  debug("onTick(0.a)  Bar["+ bar +"] "+ TimeToStr(Time[bar], TIME_FULL) +"  downtrend continuation with a higher low, stopping after "+ (startbar-bar) +" bars...");
                  break;
               }
            }
            else {                                                                     // a new downtrend
               SetTrend(prevOffset-1, bar, -1, "onTick(0.b)  Bar["+ bar +"]");         // reset unknown trend and mark a new downtrend
               zigzag0[bar] = lowerCross[bar];
               zigzag1[bar] = lowerCross[bar];
            }

            // then process the upper band cross
            SetTrend(bar, bar, 1, "onTick(0.c)  Bar["+ bar +"]");                      // mark a new uptrend
            zigzag1[bar] = upperCross[bar];
         }
      }

      // -- upper band cross ------------------------------------------------------------------------------------------------
      else if (upperCross[bar] != 0) {
         prevOffset = bar + 1 + notrend[bar+1];
         prevTrend = trend[prevOffset];
         debug("onTick(0.d)  Bar["+ bar +"] "+ TimeToStr(Time[bar], TIME_FULL) +"  High cross: prevOffset="+ prevOffset +", prevTrend="+ prevTrend);

         if (prevTrend > 0) {                                                          // an uptrend continuation
            if (upperCross[bar] > upperCross[prevOffset]) {                            // a trend extention
               SetTrend(prevOffset, bar, prevTrend, "onTick(0.e)  Bar["+ bar +"]");    // reset unknown trend and update existing trend
               if (zigzag0[prevOffset] == zigzag1[prevOffset]) {
                  zigzag0[prevOffset] = 0;
                  zigzag1[prevOffset] = 0;
               }
               else {
                  zigzag1[prevOffset] = zigzag0[prevOffset];
               }
               zigzag0[bar] = upperCross[bar];
               zigzag1[bar] = upperCross[bar];
            }
            else {                                                                     // a trend continuation with a lower high
               notrend[bar] = Round(notrend[bar+1] + 1);                               // increase unknown trend
               debug("onTick(0.f)  Bar["+ bar +"] "+ TimeToStr(Time[bar], TIME_FULL) +"  uptrend continuation with a lower high");
            }
         }
         else {                                                                        // a new uptrend
            SetTrend(prevOffset-1, bar, 1, "onTick(0.g)  Bar["+ bar +"]");             // reset unknown trend and mark a new uptrend
            zigzag0[bar] = upperCross[bar];
            zigzag1[bar] = upperCross[bar];
         }
      }

      // -- lower band cross ------------------------------------------------------------------------------------------------
      else if (lowerCross[bar] != 0) {
         prevOffset = bar + 1 + notrend[bar+1];
         prevTrend = trend[prevOffset];
         debug("onTick(0.h)  Bar["+ bar +"] "+ TimeToStr(Time[bar], TIME_FULL) +"  Low cross: prevOffset="+ prevOffset +", prevTrend="+ prevTrend);

         if (prevTrend < 0) {                                                          // a downtrend continuation
            if (lowerCross[bar] < lowerCross[prevOffset]) {                            // a trend extention
               SetTrend(prevOffset, bar, prevTrend, "onTick(0.i)  Bar["+ bar +"]");    // reset unknown trend and update existing trend
               if (zigzag0[prevOffset] == zigzag1[prevOffset]) {
                  zigzag0[prevOffset] = 0;
                  zigzag1[prevOffset] = 0;
               }
               else {
                  zigzag1[prevOffset] = zigzag0[prevOffset];
               }
               zigzag0[bar] = lowerCross[bar];
               zigzag1[bar] = lowerCross[bar];
            }
            else {                                                                     // a trend continuation with a higher low
               notrend[bar] = Round(notrend[bar+1] + 1);                               // increase unknown trend
               debug("onTick(0.j)  Bar["+ bar +"] "+ TimeToStr(Time[bar], TIME_FULL) +"  downtrend continuation with a higher low");
            }
         }
         else {                                                                        // a new downtrend
            SetTrend(prevOffset-1, bar, -1, "onTick(0.k)  Bar["+ bar +"]");            // reset unknown trend and mark a new downtrend
            zigzag0[bar] = lowerCross[bar];
            zigzag1[bar] = lowerCross[bar];
         }
      }
      else return(catch("onTick(3)  illegal state", ERR_ILLEGAL_STATE));


      debug("onTick(0.x)  Bar["+ bar +"] "+ TimeToStr(Time[bar], TIME_FULL) +"  trend="+ _int(trend[bar]) +"  notrend="+ _int(notrend[bar]));
      int processed = startbar-bar+1;
      if (processed >= ProcessBars) break;
   }
   return(catch("onTick(4)"));
}


/**
 * Whether a bar crossing both channel bands crossed the upper band first.
 *
 * @param  int bar - bar offset
 *
 * @return bool
 */
bool WasUpperCrossFirst(int bar) {
   return(High[bar]-Open[bar] < Open[bar]-Low[bar]);
}


/**
 * Set 'trend' and 'notrend' counters of the specified bar range.
 *
 * @param  int from  - start offset of the bar range
 * @param  int to    - end offset of the bar range
 * @param  int value - start trend counter value
 */
void SetTrend(int from, int to, int value, string location) {
   int counter = value;

   for (int i=from; i >= to; i--) {
      trend  [i] = counter;
      notrend[i] = 0;

      if (value > 0) counter++;
      else           counter--;
   }

   debug(location +" set trend "+ from +"-"+ to +": "+ value +"..."+ _int(trend[to]));
   return;
}


/**
 * Workaround for various terminal bugs when setting indicator options. Usually options are set in init(). However after
 * recompilation options must be set in start() to not be ignored.
 */
void SetIndicatorOptions() {
   //SetIndexStyle(int index, int drawType, int lineStyle=EMPTY, int drawWidth=EMPTY, color drawColor=NULL);

   SetIndexStyle(MODE_ZIGZAG0,     DRAW_ZIGZAG);
   SetIndexStyle(MODE_ZIGZAG1,     DRAW_ZIGZAG);
   SetIndexStyle(MODE_UPPER_BAND,  DRAW_LINE);
   SetIndexStyle(MODE_LOWER_BAND,  DRAW_LINE);
   SetIndexStyle(MODE_UPPER_CROSS, DRAW_ARROW, EMPTY, CrossSize); SetIndexArrow(MODE_UPPER_CROSS, 161);  // an open circle
   SetIndexStyle(MODE_LOWER_CROSS, DRAW_ARROW, EMPTY, CrossSize); SetIndexArrow(MODE_LOWER_CROSS, 161);  // ...
   SetIndexStyle(MODE_TREND,       DRAW_NONE);
   SetIndexStyle(MODE_NOTREND,     DRAW_NONE);
}
