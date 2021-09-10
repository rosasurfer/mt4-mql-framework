/**
 * Non-repainting ZigZag indicator suitable for automated trading
 *
 * The ZigZag indicator provided by MetaQuotes is of little use. The algorythm is flawed and the indicator heavily repaints.
 * Furthermore it can't be used for automation. This version fixes these issues. Once a ZigZag reversal point is drawn it
 * will not change anymore. This ZigZag indicator uses a Donchian channel for determining reversals and draws vertical line
 * segments if a large bar crosses both the upper and the lower ZigZag deviation level.
 *
 * TODO:
 *  - implement Max.bars
 *  - fix IndicatorDigits()
 *  - add chart legend
 *  - add InputsToStr()
 *  - add and document iCustom() buffers (1 or 2)
 */
#include <stddefines.mqh>
int   __InitFlags[];
int __DeinitFlags[];

#property indicator_chart_window
#property indicator_buffers   8

#property indicator_color1    Blue                          // the ZigZag line is built from two buffers using the color of the first buffer
#property indicator_width1    1
#property indicator_color2    CLR_NONE

#property indicator_color3    DodgerBlue                    // upper channel band
#property indicator_style3    STYLE_DOT                     //
#property indicator_color4    Magenta                       // lower channel band
#property indicator_style4    STYLE_DOT                     //

#property indicator_color5    indicator_color3              // upper channel band crossings
#property indicator_color6    indicator_color4              // lower channel band crossings

#property indicator_color7    CLR_NONE                      // trend buffer
#property indicator_color8    CLR_NONE                      // notrend buffer

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern int    ZigZag.Periods       = 36;                    // 12 lookback periods of the Donchian channel
extern string ZigZag.Type          = "Line | Semaphores*";  // a ZigZag line or turning points, may be shortened to "l | s"
extern int    ZigZag.Width         = indicator_width1;
extern color  ZigZag.Color         = indicator_color1;

extern int    Semaphore.Symbol     = 108;                   // a closed circle (a dot)

extern bool   ShowChannel          = true;
extern bool   ShowChannelBreakouts = true;
extern color  UpperChannel.Color   = indicator_color3;
extern color  LowerChannel.Color   = indicator_color4;

extern int    Max.Bars             = 10000;                 // max. values to calculate (-1: all available)

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <rsfLibs.mqh>

#define MODE_ZIGZAG_OPEN   0     // indicator buffer ids
#define MODE_ZIGZAG_CLOSE  1
#define MODE_UPPER_BAND    2
#define MODE_LOWER_BAND    3
#define MODE_UPPER_CROSS   4
#define MODE_LOWER_CROSS   5
#define MODE_TREND         6
#define MODE_NOTREND       7

double zigzagOpen [];            // ZigZag semaphores (open price of a vertical segment)
double zigzagClose[];            // ZigZag semaphores (close price of a vertical segment)
double upperBand  [];            // upper channel band
double lowerBand  [];            // lower channel band
double upperCross [];            // upper band crossings
double lowerCross [];            // lower band crossings
double trend      [];            // trend direction and length in bars
double notrend    [];            // bar periods with not yet known (unfinished) trend direction

int    zigzagPeriods;
int    zigzagDrawType;
int    maxValues;

string legendLabel;


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   // validate inputs
   // ZigZag.Periods
   if (ZigZag.Periods < 2)     return(catch("onInit(1)  invalid input parameter ZigZag.Periods: "+ ZigZag.Periods, ERR_INVALID_INPUT_PARAMETER));
   zigzagPeriods = ZigZag.Periods;
   // ZigZag.Type
   string sValues[], sValue = StrToLower(ZigZag.Type);
   if (Explode(sValue, "*", sValues, 2) > 1) {
      int size = Explode(sValues[0], "|", sValues, NULL);
      sValue = sValues[size-1];
   }
   sValue = StrTrim(sValue);
   if      (StrStartsWith("line",       sValue)) { zigzagDrawType = DRAW_ZIGZAG; ZigZag.Type = "Line";        }
   else if (StrStartsWith("semaphores", sValue)) { zigzagDrawType = DRAW_ARROW;  ZigZag.Type = "Semaphores";  }
   else                        return(catch("onInit(2)  invalid input parameter ZigZag.Type: "+ DoubleQuoteStr(ZigZag.Type), ERR_INVALID_INPUT_PARAMETER));
   // ZigZag.Width
   if (ZigZag.Width < 0)       return(catch("onInit(3)  invalid input parameter ZigZag.Width: "+ ZigZag.Width, ERR_INVALID_INPUT_PARAMETER));
   // Semaphore.Symbol
   if (Semaphore.Symbol <  32) return(catch("onInit(4)  invalid input parameter Semaphore.Symbol: "+ Semaphore.Symbol, ERR_INVALID_INPUT_PARAMETER));
   if (Semaphore.Symbol > 255) return(catch("onInit(5)  invalid input parameter Semaphore.Symbol: "+ Semaphore.Symbol, ERR_INVALID_INPUT_PARAMETER));
   // Max.Bars
   if (Max.Bars < -1)          return(catch("onInit(6)  invalid input parameter Max.Bars: "+ Max.Bars, ERR_INVALID_INPUT_PARAMETER));
   maxValues = ifInt(Max.Bars==-1, INT_MAX, Max.Bars);
   // colors: after deserialization the terminal might turn CLR_NONE (0xFFFFFFFF) into Black (0xFF000000)
   if (ZigZag.Color       == 0xFF000000) ZigZag.Color       = CLR_NONE;
   if (UpperChannel.Color == 0xFF000000) UpperChannel.Color = CLR_NONE;
   if (LowerChannel.Color == 0xFF000000) LowerChannel.Color = CLR_NONE;

   // buffer management
   string shortName = ProgramName() +"("+ ZigZag.Periods +")";
   SetIndexBuffer(MODE_ZIGZAG_OPEN,  zigzagOpen ); SetIndexEmptyValue(MODE_ZIGZAG_OPEN,  0); SetIndexLabel(MODE_ZIGZAG_OPEN,  "O");
   SetIndexBuffer(MODE_ZIGZAG_CLOSE, zigzagClose); SetIndexEmptyValue(MODE_ZIGZAG_CLOSE, 0); SetIndexLabel(MODE_ZIGZAG_CLOSE, "C");
   SetIndexBuffer(MODE_UPPER_BAND,   upperBand  ); SetIndexEmptyValue(MODE_UPPER_BAND,   0); SetIndexLabel(MODE_UPPER_BAND,   NULL);
   SetIndexBuffer(MODE_LOWER_BAND,   lowerBand  ); SetIndexEmptyValue(MODE_LOWER_BAND,   0); SetIndexLabel(MODE_LOWER_BAND,   NULL);
   SetIndexBuffer(MODE_UPPER_CROSS,  upperCross ); SetIndexEmptyValue(MODE_UPPER_CROSS,  0); SetIndexLabel(MODE_UPPER_CROSS,  NULL);
   SetIndexBuffer(MODE_LOWER_CROSS,  lowerCross ); SetIndexEmptyValue(MODE_LOWER_CROSS,  0); SetIndexLabel(MODE_LOWER_CROSS,  NULL);
   SetIndexBuffer(MODE_TREND,        trend      ); SetIndexEmptyValue(MODE_TREND,        0); SetIndexLabel(MODE_TREND,        shortName +" trend");
   SetIndexBuffer(MODE_NOTREND,      notrend    ); SetIndexEmptyValue(MODE_NOTREND,      0); SetIndexLabel(MODE_NOTREND,      shortName +" unknown");

   // chart legend
   if (!IsSuperContext()) {
       legendLabel = CreateLegendLabel();
       RegisterObject(legendLabel);
   }

   // names, labels and display options
   IndicatorShortName(shortName);               // chart tooltips and context menu
   //IndicatorDigits(0);
   SetIndicatorOptions();

   return(catch("onInit(7)"));
}


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   // on the first tick after terminal start buffers may not yet be initialized (spurious issue)
   if (!ArraySize(zigzagOpen)) return(logInfo("onTick(1)  size(zigzagOpen) = 0", SetLastError(ERS_TERMINAL_NOT_YET_READY)));

   // reset buffers before performing a full recalculation
   if (!ValidBars) {
      ArrayInitialize(zigzagOpen,  0);
      ArrayInitialize(zigzagClose, 0);
      ArrayInitialize(upperBand,   0);
      ArrayInitialize(lowerBand,   0);
      ArrayInitialize(upperCross,  0);
      ArrayInitialize(lowerCross,  0);
      ArrayInitialize(trend,       0);
      ArrayInitialize(notrend,     0);
      SetIndicatorOptions();
   }

   // synchronize buffers with a shifted offline chart
   if (ShiftedBars > 0) {
      ShiftIndicatorBuffer(zigzagOpen,  Bars, ShiftedBars, 0);
      ShiftIndicatorBuffer(zigzagClose, Bars, ShiftedBars, 0);
      ShiftIndicatorBuffer(upperBand,   Bars, ShiftedBars, 0);
      ShiftIndicatorBuffer(lowerBand,   Bars, ShiftedBars, 0);
      ShiftIndicatorBuffer(upperCross,  Bars, ShiftedBars, 0);
      ShiftIndicatorBuffer(lowerCross,  Bars, ShiftedBars, 0);
      ShiftIndicatorBuffer(trend,       Bars, ShiftedBars, 0);
      ShiftIndicatorBuffer(notrend,     Bars, ShiftedBars, 0);
   }

   // calculate startbar
   int startbar = Min(ChangedBars-1, Bars-zigzagPeriods);
   if (startbar < 0) return(logInfo("onTick(2)  Tick="+ Tick, ERR_HISTORY_INSUFFICIENT));

   //startbar = Min(startbar, 1000);


   // recalculate Donchian channel and potential ZigZag turning points
   for (int bar=startbar; bar >= 0; bar--) {
      upperBand[bar] = High[iHighest(NULL, NULL, MODE_HIGH, zigzagPeriods, bar)];
      lowerBand[bar] =  Low[ iLowest(NULL, NULL, MODE_LOW,  zigzagPeriods, bar)];

      if (High[bar] == upperBand[bar]) upperCross[bar] = upperBand[bar];
      else                             upperCross[bar] = 0;

      if (Low[bar] == lowerBand[bar]) lowerCross[bar] = lowerBand[bar];
      else                            lowerCross[bar] = 0;
   }

   int prevZZ;                                                       // bar offset of the last previously drawn ZigZag point (same or opposite direction)

   // recalculate ZigZag
   for (bar=startbar; bar >= 0; bar--) {

      // -- if no cross (trend is unknown) ----------------------------------------------------------------------------------
      if (!upperCross[bar] && !lowerCross[bar]) {
         notrend[bar] = Round(notrend[bar+1] + 1);                   // increase unknown trend
      }

      // -- if double cross (upper and lower band crossed by the same bar) --------------------------------------------------
      else if (upperCross[bar] && lowerCross[bar]) {
         if (IsUpperCrossFirst(bar)) {
            prevZZ = ProcessUpperBandCross(bar);                     // first process the upper band cross

            if (!trend[bar]) {                                       // then process the lower band cross
               SetTrend(prevZZ-1, bar, -1);                          // mark a new downtrend
               zigzagOpen[bar] = lowerCross[bar];
            }
            else {
               SetTrend(bar, bar, -1);
            }
            zigzagClose[bar] = lowerCross[bar];
         }
         else {
            prevZZ = ProcessLowerBandCross(bar);                     // first process the lower band cross

            if (!trend[bar]) {                                       // then process the upper band cross
               SetTrend(prevZZ-1, bar, 1);                           // mark a new uptrend
               zigzagOpen[bar] = upperCross[bar];
            }
            else {
               SetTrend(bar, bar, 1);
            }
            zigzagClose[bar] = upperCross[bar];
         }
      }

      // -- if only upper band cross ----------------------------------------------------------------------------------------
      else if (upperCross[bar] != 0) {
         ProcessUpperBandCross(bar);
      }

      // -- if only lower band cross ----------------------------------------------------------------------------------------
      else {
         ProcessLowerBandCross(bar);
      }
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
 * Resolve the offset of the last previously drawn ZigZag point before the specified startbar.
 *
 * @param  int bar - startbar offset
 *
 * @return int - ZigZag point bar offset or the previous bar offset if no ZigZag point was yet drawn
 */
int GetPreviousZigZagPoint(int bar) {
   bar++;
   if      (notrend[bar] > 0) int zzOffset = bar + notrend[bar];
   else if (!zigzagClose[bar])    zzOffset = bar + Abs(trend[bar]);
   else                           zzOffset = bar;
   return(zzOffset);
}


/**
 * Process an upper channel band crossing at the specified bar offset.
 *
 * @param  int  bar - offset
 *
 * @return int - bar offset of the last previously drawn ZigZag point (same or opposite direction)
 */
int ProcessUpperBandCross(int bar) {
   int prevZZ    = GetPreviousZigZagPoint(bar);                // bar offset of the last previously drawn ZigZag point (same or opposite direction)
   int prevTrend = trend[prevZZ];                              // trend at the last drawn ZigZag point

   if (prevTrend > 0) {                                        // an uptrend continuation
      if (upperCross[bar] > upperCross[prevZZ]) {              // a new high
         SetTrend(prevZZ, bar, prevTrend);                     // update existing trend and mark new high
         if (zigzagOpen[prevZZ] == zigzagClose[prevZZ]) {
            zigzagOpen [prevZZ] = 0;
            zigzagClose[prevZZ] = 0;
         }
         else {
            zigzagClose[prevZZ] = zigzagOpen[prevZZ];
         }
         zigzagOpen [bar] = upperCross[bar];
         zigzagClose[bar] = upperCross[bar];
      }
      else {                                                   // a lower high
         notrend[bar] = Round(notrend[bar+1] + 1);             // increase unknown trend
      }
   }
   else {                                                      // start a new uptrend
      SetTrend(prevZZ-1, bar, 1);
      zigzagOpen [bar] = upperCross[bar];
      zigzagClose[bar] = upperCross[bar];
   }
   return(prevZZ);
}


/**
 * Process a lower channel band crossing at the specified bar offset.
 *
 * @param  int bar - offset
 *
 * @return int - bar offset of the last previously drawn ZigZag point (same or opposite direction)
 */
int ProcessLowerBandCross(int bar) {
   int prevZZ    = GetPreviousZigZagPoint(bar);                // bar offset of the last previously drawn ZigZag point (same or opposite direction)
   int prevTrend = trend[prevZZ];                              // trend at the last drawn ZigZag point

   if (prevTrend < 0) {                                        // a downtrend continuation
      if (lowerCross[bar] < lowerCross[prevZZ]) {              // a new low
         SetTrend(prevZZ, bar, prevTrend);                     // update existing trend and mark new low
         if (zigzagOpen[prevZZ] == zigzagClose[prevZZ]) {
            zigzagOpen [prevZZ] = 0;
            zigzagClose[prevZZ] = 0;
         }
         else {
            zigzagClose[prevZZ] = zigzagOpen[prevZZ];
         }
         zigzagOpen [bar] = lowerCross[bar];
         zigzagClose[bar] = lowerCross[bar];
      }
      else {                                                   // a higher low
         notrend[bar] = Round(notrend[bar+1] + 1);             // increase unknown trend
      }
   }
   else {                                                      // start a new downtrend
      SetTrend(prevZZ-1, bar, -1);
      zigzagOpen [bar] = lowerCross[bar];
      zigzagClose[bar] = lowerCross[bar];
   }
   return(prevZZ);
}


/**
 * Set the 'trend' counter and reset the 'notrend' counter of the specified bar range.
 *
 * @param  int from  - start offset of the bar range
 * @param  int to    - end offset of the bar range
 * @param  int value - trend start value
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

   int drawType  = ifInt(ZigZag.Width, zigzagDrawType, DRAW_NONE);
   int drawWidth = ifInt(zigzagDrawType==DRAW_ZIGZAG, ZigZag.Width, ZigZag.Width-1);

   SetIndexStyle(MODE_ZIGZAG_OPEN,  drawType, EMPTY, drawWidth, ZigZag.Color); SetIndexArrow(MODE_ZIGZAG_OPEN,  Semaphore.Symbol);
   SetIndexStyle(MODE_ZIGZAG_CLOSE, drawType, EMPTY, drawWidth, ZigZag.Color); SetIndexArrow(MODE_ZIGZAG_CLOSE, Semaphore.Symbol);

   drawType = ifInt(ShowChannel, DRAW_LINE, DRAW_NONE);
   SetIndexStyle(MODE_UPPER_BAND, drawType, EMPTY, EMPTY, UpperChannel.Color);
   SetIndexStyle(MODE_LOWER_BAND, drawType, EMPTY, EMPTY, LowerChannel.Color);

   drawType = ifInt(ShowChannelBreakouts, DRAW_ARROW, DRAW_NONE);
   SetIndexStyle(MODE_UPPER_CROSS, drawType, EMPTY, EMPTY, UpperChannel.Color); SetIndexArrow(MODE_UPPER_CROSS, 161);   // an open circle (dot)
   SetIndexStyle(MODE_LOWER_CROSS, drawType, EMPTY, EMPTY, LowerChannel.Color); SetIndexArrow(MODE_LOWER_CROSS, 161);   // ...

   SetIndexStyle(MODE_TREND,   DRAW_NONE);
   SetIndexStyle(MODE_NOTREND, DRAW_NONE);
}
