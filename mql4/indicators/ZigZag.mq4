/**
 * Non-repainting ZigZag indicator suitable for automation
 *
 *
 * The ZigZag indicator provided by MetaQuotes is of little use. The algorythm is flawed and the indicator heavily repaints.
 * Also it can't be used for automation.
 *
 * This version fixes all those issues. Once a ZigZag reversal is drawn it will not change anymore. The indicator uses a
 * Donchian channel for determining possible reversals and draws vertical line segments if a large bar crosses both the upper
 * and the lower channel band. Additionally this indicator can display the trail of a new ZigZag leg as it developed over
 * time which is usefull especially for breakout strategies.
 *
 *
 * TODO:
 *  - remove trail markers not reaching a new high/low
 *  - add new leg up/down markers with price value
 *  - document two iCustom() buffers
 *  - add signals for new reversals and previous reversal breakouts
 *  - move indicator properties below input section (really?)
 *  - restore default values (hide channel and trail)
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

#property indicator_color5    indicator_color3              // potential upper reversal points (ZigZag trail)
#property indicator_color6    indicator_color4              // potential lower reversal points (ZigZag trail)

#property indicator_color7    CLR_NONE                      // trend buffer
#property indicator_color8    CLR_NONE                      // notrend buffer

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern int    ZigZag.Periods       = 10;                    // 12 lookback periods of the Donchian channel
extern string ZigZag.Type          = "Line | Semaphores*";  // a ZigZag line or reversal points, may be shortened to "l | s"
extern int    ZigZag.Width         = indicator_width1;
extern color  ZigZag.Color         = indicator_color1;

extern int    Semaphore.Symbol     = 108;                   // that's a small dot

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
double notrend    [];            // bar periods with not yet known trend direction

int    zigzagPeriods;
int    zigzagDrawType;
int    maxValues;
string indicatorName = "";
string legendLabel   = "";


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
   indicatorName = ProgramName() +"("+ ZigZag.Periods +")";
   SetIndexBuffer(MODE_ZIGZAG_OPEN,  zigzagOpen ); SetIndexEmptyValue(MODE_ZIGZAG_OPEN,  0); SetIndexLabel(MODE_ZIGZAG_OPEN,  NULL);
   SetIndexBuffer(MODE_ZIGZAG_CLOSE, zigzagClose); SetIndexEmptyValue(MODE_ZIGZAG_CLOSE, 0); SetIndexLabel(MODE_ZIGZAG_CLOSE, NULL);
   SetIndexBuffer(MODE_UPPER_BAND,   upperBand  ); SetIndexEmptyValue(MODE_UPPER_BAND,   0); SetIndexLabel(MODE_UPPER_BAND,   NULL);
   SetIndexBuffer(MODE_LOWER_BAND,   lowerBand  ); SetIndexEmptyValue(MODE_LOWER_BAND,   0); SetIndexLabel(MODE_LOWER_BAND,   NULL);
   SetIndexBuffer(MODE_UPPER_CROSS,  upperCross ); SetIndexEmptyValue(MODE_UPPER_CROSS,  0); SetIndexLabel(MODE_UPPER_CROSS,  NULL);
   SetIndexBuffer(MODE_LOWER_CROSS,  lowerCross ); SetIndexEmptyValue(MODE_LOWER_CROSS,  0); SetIndexLabel(MODE_LOWER_CROSS,  NULL);
   SetIndexBuffer(MODE_TREND,        trend      ); SetIndexEmptyValue(MODE_TREND,        0); SetIndexLabel(MODE_TREND,   indicatorName +" trend");
   SetIndexBuffer(MODE_NOTREND,      notrend    ); SetIndexEmptyValue(MODE_NOTREND,      0); SetIndexLabel(MODE_NOTREND, indicatorName +" waiting");

   // names, labels and display options
   IndicatorShortName(indicatorName);           // chart tooltips and context menu
   SetIndicatorOptions();
   IndicatorDigits(0);

   if (!IsSuperContext()) {
       legendLabel = CreateLegendLabel();
       RegisterObject(legendLabel);
   }
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

   // calculate start bar
   int bars     = Min(ChangedBars, maxValues);
   int startbar = Min(bars-1, Bars-zigzagPeriods);
   if (startbar < 0) return(logInfo("onTick(2)  Tick="+ Tick, ERR_HISTORY_INSUFFICIENT));

   // recalculate Donchian channel and crossings (potential ZigZag reversals)
   for (int bar=startbar; bar >= 0; bar--) {
      int iH = iHighest(NULL, NULL, MODE_HIGH, zigzagPeriods, bar);
      int iL =  iLowest(NULL, NULL, MODE_LOW,  zigzagPeriods, bar);

      upperBand[bar] = High[iH];
      lowerBand[bar] =  Low[iL];

      if (High[bar] == upperBand[bar]) upperCross[bar] = upperBand[bar];
      else                             upperCross[bar] = 0;
      if (Low[bar] == lowerBand[bar]) lowerCross[bar] = lowerBand[bar];
      else                            lowerCross[bar] = 0;
   }

   // recalculate ZigZag
   for (bar=startbar; bar >= 0; bar--) {
      // if no cross (trend is unknown)
      if (!upperCross[bar] && !lowerCross[bar]) {
         trend  [bar] = trend[bar+1];                                // keep known trend
         notrend[bar] = Round(notrend[bar+1] + 1);                   // increase unknown trend
      }

      // if double cross (upper and lower band crossed by the same bar)
      else if (upperCross[bar] && lowerCross[bar]) {
         if (IsUpperCrossFirst(bar)) {
            int prevZZ = ProcessUpperBandCross(bar);                 // first process the upper band cross

            if (notrend[bar] > 0) {                                  // then process the lower band cross
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

            if (notrend[bar] > 0) {                                  // then process the upper band cross
               SetTrend(prevZZ-1, bar, 1);                           // mark a new uptrend
               zigzagOpen[bar] = upperCross[bar];
            }
            else {
               SetTrend(bar, bar, 1);
            }
            zigzagClose[bar] = upperCross[bar];
         }
      }

      // if only upper band cross
      else if (upperCross[bar] != 0) {
         ProcessUpperBandCross(bar);
      }

      // if only lower band cross
      else {
         ProcessLowerBandCross(bar);
      }
   }

   if (!IsSuperContext()) UpdateLegend();

   return(catch("onTick(3)"));

   // notes:
   // new leg marker
   string label = "ZigZag("+ ZigZag.Periods +") new leg up at 15'863.90";
   if (ObjectFind(label) == 0)
      ObjectDelete(label);
   if (ObjectCreate(label, OBJ_ARROW, 0, D'2021.09.06 10:00', 15863.90)) {
      ObjectSet    (label, OBJPROP_ARROWCODE, 161);
      ObjectSet    (label, OBJPROP_COLOR,     UpperChannel.Color);
      ObjectSet    (label, OBJPROP_WIDTH,     0);
      RegisterObject(label);
   }
}


/**
 * Update the chart legend.
 */
void UpdateLegend() {
   static double lastTrend, lastNotrend;
   static datetime lastBarTime;

   // update if trend[0], notrend[0] or the current bar changed
   if (trend[0]!=lastTrend || notrend[0]!=lastNotrend || Time[0]!=lastBarTime) {
      int    iNotrend = notrend[0];
      string sTrend   = "  "+ NumberToStr(trend[0], "+.");
      string sNotrend = ifString(!iNotrend, "", " (waiting "+ iNotrend +")");

      string text = StringConcatenate(indicatorName, "    ", sTrend, sNotrend);
      color clr = ZigZag.Color;
      if      (clr == Aqua        ) clr = DeepSkyBlue;
      else if (clr == Gold        ) clr = Orange;
      else if (clr == LightSkyBlue) clr = C'94,174,255';
      else if (clr == Lime        ) clr = LimeGreen;
      else if (clr == Yellow      ) clr = Orange;

      ObjectSetText(legendLabel, text, 9, "Arial Fett", clr);
      int error = GetLastError();
      if (error && error!=ERR_OBJECT_DOES_NOT_EXIST) catch("UpdateLegend(1)", error);     // on Object::onDrag() or opened "Properties" dialog
   }

   lastTrend   = trend  [0];
   lastNotrend = notrend[0];
   lastBarTime = Time   [0];
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
 * Resolve the offset of the last previously drawn ZigZag point before the specified startbar. May be in same or opposite
 * trend direction.
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
         SetTrend(prevZZ, bar, prevTrend);                     // update existing trend
         if (zigzagOpen[prevZZ] == zigzagClose[prevZZ]) {      // mark new high
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
         trend  [bar] = trend[bar+1];                          // keep known trend
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
         SetTrend(prevZZ, bar, prevTrend);                     // update existing trend
         if (zigzagOpen[prevZZ] == zigzagClose[prevZZ]) {      // mark new low
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
         trend  [bar] = trend[bar+1];                          // keep known trend
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


/**
 * Return a string representation of the input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("ZigZag.Periods=",       ZigZag.Periods,                  ";", NL,
                            "ZigZag.Type=",          DoubleQuoteStr(ZigZag.Type),     ";", NL,
                            "ZigZag.Width=",         ZigZag.Width,                    ";", NL,
                            "ZigZag.Color=",         ColorToStr(ZigZag.Color),        ";", NL,
                            "Semaphore.Symbol=",     Semaphore.Symbol,                ";", NL,
                            "ShowChannel=",          BoolToStr(ShowChannel),          ";", NL,
                            "ShowChannelBreakouts=", BoolToStr(ShowChannelBreakouts), ";", NL,
                            "UpperChannel.Color=",   ColorToStr(UpperChannel.Color),  ";", NL,
                            "LowerChannel.Color=",   ColorToStr(LowerChannel.Color),  ";", NL,
                            "Max.Bars=",             Max.Bars,                        ";")
   );
}
