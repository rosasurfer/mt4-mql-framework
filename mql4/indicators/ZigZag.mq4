/**
 * ZigZag
 *
 * The ZigZag indicator provided by MetaQuotes is of little use. The algorythm is flawed and the indicator heavily repaints.
 * Furthermore it can't be used for automation. This version fixes those issues and does not repaint. Once a turning point is
 * drawn it will not change anymore. This version uses a Donchian channel for determining turning points and draws vertical
 * line segments if the range of a single large bar covers both the current upper and lower ZigZag deviation level.
 */
#include <stddefines.mqh>
int   __InitFlags[];
int __DeinitFlags[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern int  Periods     = 12;             // lookback periods of the Donchian channel                                         // MZ: 5
extern int  CrossSize   = 0;
extern int  ProcessBars = 0;              // 0: all bars
extern bool Debug       = false;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <rsfLibs.mqh>

#define MODE_ZIGZAG_O         0           // indicator buffer ids
#define MODE_ZIGZAG_C         1
#define MODE_UPPER_BAND       2
#define MODE_LOWER_BAND       3
#define MODE_UPPER_CROSS      4
#define MODE_LOWER_CROSS      5
#define MODE_TREND            6
#define MODE_NOTREND          7

#property indicator_chart_window
#property indicator_buffers   8

#property indicator_color1    Blue        // ZigZag line built from two buffers using the color of the first buffer
#property indicator_width1    2
#property indicator_color2    CLR_NONE

#property indicator_color3    DodgerBlue  // upper channel band
#property indicator_style3    STYLE_DOT   //
#property indicator_color4    Magenta     // lower channel band
#property indicator_style4    STYLE_DOT   //

#property indicator_color5    DodgerBlue  // upper channel band crossings
#property indicator_color6    Magenta     // lower channel band crossings
#property indicator_color7    CLR_NONE    // trend buffer
#property indicator_color8    CLR_NONE    // notrend buffer

double zigzagO   [];                      // ZigZag semaphores (open price of a vertical segment)
double zigzagC   [];                      // ...              (close price of a vertical segment)
double upperBand [];                      // upper channel band
double lowerBand [];                      // lower channel band
double upperCross[];                      // upper band crossings
double lowerCross[];                      // lower band crossings
double trend     [];                      // trend direction and length
double notrend   [];                      // periods with not yet known (unfinished) trend direction


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   SetIndexBuffer(MODE_ZIGZAG_O,    zigzagO   ); SetIndexEmptyValue(MODE_ZIGZAG_O,    0); SetIndexLabel(MODE_ZIGZAG_O,    NULL);
   SetIndexBuffer(MODE_ZIGZAG_C,    zigzagC   ); SetIndexEmptyValue(MODE_ZIGZAG_C,    0); SetIndexLabel(MODE_ZIGZAG_C,    NULL);
   SetIndexBuffer(MODE_UPPER_BAND,  upperBand ); SetIndexEmptyValue(MODE_UPPER_BAND,  0); SetIndexLabel(MODE_UPPER_BAND,  NULL);
   SetIndexBuffer(MODE_LOWER_BAND,  lowerBand ); SetIndexEmptyValue(MODE_LOWER_BAND,  0); SetIndexLabel(MODE_LOWER_BAND,  NULL);
   SetIndexBuffer(MODE_UPPER_CROSS, upperCross); SetIndexEmptyValue(MODE_UPPER_CROSS, 0); SetIndexLabel(MODE_UPPER_CROSS, NULL);
   SetIndexBuffer(MODE_LOWER_CROSS, lowerCross); SetIndexEmptyValue(MODE_LOWER_CROSS, 0); SetIndexLabel(MODE_LOWER_CROSS, NULL);
   SetIndexBuffer(MODE_TREND,       trend     ); SetIndexEmptyValue(MODE_TREND,       0); SetIndexLabel(MODE_TREND,       "ZigZag trend");
   SetIndexBuffer(MODE_NOTREND,     notrend   ); SetIndexEmptyValue(MODE_NOTREND,     0); SetIndexLabel(MODE_NOTREND,     "ZigZag no trend");

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
   if (!ArraySize(zigzagO)) return(logInfo("onTick(1)  size(zigzagO) = 0", SetLastError(ERS_TERMINAL_NOT_YET_READY)));

   // reset buffers before performing a full recalculation
   if (!ValidBars) {
      ArrayInitialize(zigzagO,    0);
      ArrayInitialize(zigzagC,    0);
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
      ShiftIndicatorBuffer(zigzagO,    Bars, ShiftedBars, 0);
      ShiftIndicatorBuffer(zigzagC,    Bars, ShiftedBars, 0);
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

   for (bar=startbar; /*!ValidBars &&*/ bar >= 0; bar--) {
      zigzagO[bar] = 0;
      zigzagC[bar] = 0;
      trend  [bar] = 0;
      notrend[bar] = 0;

      // -- trend is unknown ------------------------------------------------------------------------------------------------
      if (!upperCross[bar] && !lowerCross[bar]) {
         if (Debug) debug("onTick(0.1)  Bar["+ bar +"] "+ TimeToStr(Time[bar], TIME_FULL) +"  no cross");
         notrend[bar] = Round(notrend[bar+1] + 1);                   // increase unknown trend
      }

      // -- upper and lower band crossed by the same bar --------------------------------------------------------------------
      else if (upperCross[bar] && lowerCross[bar]) {
         if (Debug) debug("onTick(0.2)  Bar["+ bar +"] "+ TimeToStr(Time[bar], TIME_FULL) +"  both High and Low cross");

         if (IsUpperCrossFirst(bar)) {
            // first process the upper band cross
            prevOffset = bar + 1 + notrend[bar+1];
            prevTrend = trend[prevOffset];
            if (Debug) debug("onTick(0.3)  Bar["+ bar +"] "+ TimeToStr(Time[bar], TIME_FULL) +"  High cross first: prevOffset="+ prevOffset +", prevTrend="+ prevTrend);

            if (prevTrend > 0) {                                     // an uptrend continuation
               if (upperCross[bar] > upperCross[prevOffset]) {       // a trend extention
                  SetTrend(prevOffset, bar, prevTrend);              // reset unknown trend and update existing trend
                  if (zigzagO[prevOffset] == zigzagC[prevOffset]) {
                     zigzagO[prevOffset] = 0;
                     zigzagC[prevOffset] = 0;
                  }
                  else {
                     zigzagC[prevOffset] = zigzagO[prevOffset];
                  }
                  zigzagO[bar] = upperCross[bar];
                  zigzagC[bar] = upperCross[bar];
               }
               else {                                                // a trend continuation with a lower high
                  notrend[bar] = Round(notrend[bar+1] + 1);          // increase unknown trend
                  if (Debug) debug("onTick(0.4)  Bar["+ bar +"] "+ TimeToStr(Time[bar], TIME_FULL) +"  uptrend continuation with a lower high");
               }
            }
            else {                                                   // a new uptrend
               SetTrend(prevOffset-1, bar, 1);                       // reset unknown trend and mark a new uptrend
               zigzagO[bar] = upperCross[bar];
               zigzagC[bar] = upperCross[bar];
            }

            // then process the lower band cross
            if (!trend[bar]) {
               SetTrend(prevOffset-1, bar, -1);                      // mark a new downtrend
               zigzagO[bar] = lowerCross[bar];
            }
            else {
               SetTrend(bar, bar, -1);
            }
            zigzagC[bar] = lowerCross[bar];
         }
         else {
            // first process the lower band cross
            prevOffset = bar + 1 + notrend[bar+1];
            prevTrend = trend[prevOffset];
            if (Debug) debug("onTick(0.5)  Bar["+ bar +"] "+ TimeToStr(Time[bar], TIME_FULL) +"  Low cross first: prevOffset="+ prevOffset +", prevTrend="+ prevTrend);

            if (prevTrend < 0) {                                     // a downtrend continuation
               if (lowerCross[bar] < lowerCross[prevOffset]) {       // a trend extention
                  SetTrend(prevOffset, bar, prevTrend);              // reset unknown trend and update existing trend
                  if (zigzagO[prevOffset] == zigzagC[prevOffset]) {
                     zigzagO[prevOffset] = 0;
                     zigzagC[prevOffset] = 0;
                  }
                  else {
                     zigzagC[prevOffset] = zigzagO[prevOffset];
                  }
                  zigzagO[bar] = lowerCross[bar];
                  zigzagC[bar] = lowerCross[bar];
               }
               else {                                                // a trend continuation with a higher low
                  notrend[bar] = Round(notrend[bar+1] + 1);          // increase unknown trend
                  if (Debug) debug("onTick(0.6)  Bar["+ bar +"] "+ TimeToStr(Time[bar], TIME_FULL) +"  downtrend continuation with a higher low");
               }
            }
            else {                                                   // a new downtrend
               SetTrend(prevOffset-1, bar, -1);                      // reset unknown trend and mark a new downtrend
               zigzagO[bar] = lowerCross[bar];
               zigzagC[bar] = lowerCross[bar];
            }

            // then process the upper band cross
            if (!trend[bar]) {
               SetTrend(prevOffset-1, bar, 1);                       // mark a new uptrend
               zigzagO[bar] = upperCross[bar];
            }
            else {
               SetTrend(bar, bar, 1);
            }
            zigzagC[bar] = upperCross[bar];
         }
      }

      // -- upper band cross ------------------------------------------------------------------------------------------------
      else if (upperCross[bar] != 0) {
         prevOffset = bar + 1 + notrend[bar+1];
         prevTrend = trend[prevOffset];
         if (Debug) debug("onTick(0.7)  Bar["+ bar +"] "+ TimeToStr(Time[bar], TIME_FULL) +"  High cross: prevOffset="+ prevOffset +", prevTrend="+ prevTrend);

         if (prevTrend > 0) {                                        // an uptrend continuation
            if (upperCross[bar] > upperCross[prevOffset]) {          // a trend extention
               SetTrend(prevOffset, bar, prevTrend);                 // reset unknown trend and update existing trend
               if (zigzagO[prevOffset] == zigzagC[prevOffset]) {
                  zigzagO[prevOffset] = 0;
                  zigzagC[prevOffset] = 0;
               }
               else {
                  zigzagC[prevOffset] = zigzagO[prevOffset];
               }
               zigzagO[bar] = upperCross[bar];
               zigzagC[bar] = upperCross[bar];
            }
            else {                                                   // a trend continuation with a lower high
               notrend[bar] = Round(notrend[bar+1] + 1);             // increase unknown trend
               if (Debug) debug("onTick(0.8)  Bar["+ bar +"] "+ TimeToStr(Time[bar], TIME_FULL) +"  uptrend continuation with a lower high");
            }
         }
         else {                                                      // a new uptrend
            SetTrend(prevOffset-1, bar, 1);                          // reset unknown trend and mark a new uptrend
            zigzagO[bar] = upperCross[bar];
            zigzagC[bar] = upperCross[bar];
         }
      }

      // -- lower band cross ------------------------------------------------------------------------------------------------
      else {
         prevOffset = bar + 1 + notrend[bar+1];
         prevTrend = trend[prevOffset];
         if (Debug) debug("onTick(0.9)  Bar["+ bar +"] "+ TimeToStr(Time[bar], TIME_FULL) +"  Low cross: prevOffset="+ prevOffset +", prevTrend="+ prevTrend);

         if (prevTrend < 0) {                                        // a downtrend continuation
            if (lowerCross[bar] < lowerCross[prevOffset]) {          // a trend extention
               SetTrend(prevOffset, bar, prevTrend);                 // reset unknown trend and update existing trend
               if (zigzagO[prevOffset] == zigzagC[prevOffset]) {
                  zigzagO[prevOffset] = 0;
                  zigzagC[prevOffset] = 0;
               }
               else {
                  zigzagC[prevOffset] = zigzagO[prevOffset];
               }
               zigzagO[bar] = lowerCross[bar];
               zigzagC[bar] = lowerCross[bar];
            }
            else {                                                   // a trend continuation with a higher low
               notrend[bar] = Round(notrend[bar+1] + 1);             // increase unknown trend
               if (Debug) debug("onTick(0.a)  Bar["+ bar +"] "+ TimeToStr(Time[bar], TIME_FULL) +"  downtrend continuation with a higher low");
            }
         }
         else {                                                      // a new downtrend
            SetTrend(prevOffset-1, bar, -1);                         // reset unknown trend and mark a new downtrend
            zigzagO[bar] = lowerCross[bar];
            zigzagC[bar] = lowerCross[bar];
         }
      }

      int processed = startbar-bar+1;
      if (ProcessBars && processed >= ProcessBars) break;
   }
   return(catch("onTick(3)"));
}


/**
 * Whether a bar crossing both channel bands crossed the upper band first.
 *
 * @param  int bar - bar offset
 *
 * @return bool
 */
bool IsUpperCrossFirst(int bar) {
   double ho = High [bar] - Open [bar];
   double ol = Open [bar] - Low  [bar];
   double hc = High [bar] - Close[bar];
   double cl = Close[bar] - Low  [bar];

   double minOpen  = MathMin(ho, ol);
   double minClose = MathMin(hc, cl);

   if (minOpen < minClose)
      return(ho < ol);
   return(hc > cl);
}


/**
 * Set 'trend' and 'notrend' counters of the specified bar range.
 *
 * @param  int from  - start offset of the bar range
 * @param  int to    - end offset of the bar range
 * @param  int value - start trend value
 */
void SetTrend(int from, int to, int value) {
   for (int i=from; i >= to; i--) {
      trend  [i] = value;
      notrend[i] = 0;

      if (value > 0) value++;
      else           value--;
   }
}


/**
 * Workaround for various terminal bugs when setting indicator options. Usually options are set in init(). However after
 * recompilation options must be set in start() to not be ignored.
 */
void SetIndicatorOptions() {
   //SetIndexStyle(int index, int drawType, int lineStyle=EMPTY, int drawWidth=EMPTY, color drawColor=NULL);

   SetIndexStyle(MODE_ZIGZAG_O,    DRAW_ZIGZAG);
   SetIndexStyle(MODE_ZIGZAG_C,    DRAW_ZIGZAG);
   SetIndexStyle(MODE_UPPER_BAND,  DRAW_LINE,  STYLE_DOT, 1);
   SetIndexStyle(MODE_LOWER_BAND,  DRAW_LINE,  STYLE_DOT, 1);
   SetIndexStyle(MODE_UPPER_CROSS, DRAW_ARROW, EMPTY, CrossSize); SetIndexArrow(MODE_UPPER_CROSS, 161);  // an open circle
   SetIndexStyle(MODE_LOWER_CROSS, DRAW_ARROW, EMPTY, CrossSize); SetIndexArrow(MODE_LOWER_CROSS, 161);  // ...
   SetIndexStyle(MODE_TREND,       DRAW_NONE);
   SetIndexStyle(MODE_NOTREND,     DRAW_NONE);
}
