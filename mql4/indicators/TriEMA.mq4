/**
 * Triple Smoothed Exponential Moving Average
 *
 *
 * A three times applied exponential moving average (not to be confused with the TEMA moving average). This is the base of
 * the Trix indicator.
 *
 * Indicator buffers to use with iCustom():
 *  • MovingAverage.MODE_MA:    MA values
 *  • MovingAverage.MODE_TREND: trend direction and length
 *    - trend direction:        positive values denote an uptrend (+1...+n), negative values a downtrend (-1...-n)
 *    - trend length:           the absolute direction value is the length of the trend in bars since the last reversal
 */
#include <stddefines.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern int    MA.Periods      = 38;
extern string MA.AppliedPrice = "Open | High | Low | Close* | Median | Typical | Weighted";

extern color  Color.UpTrend   = Blue;                 // indicator style management in MQL
extern color  Color.DownTrend = Red;
extern string Draw.Type       = "Line* | Dot";
extern int    Draw.LineWidth  = 2;

extern int    Max.Values      = 5000;                 // max. number of values to display: -1 = all

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <rsfLibs.mqh>
#include <functions/@Trend.mqh>

#define MODE_MA               MovingAverage.MODE_MA      // indicator buffer ids
#define MODE_TREND            MovingAverage.MODE_TREND   //
#define MODE_UPTREND1         2                          // Draw.Type=Line: If a downtrend is interrupted by a one-bar uptrend
#define MODE_DOWNTREND        3                          // this uptrend is covered by the continuing downtrend. To make single-bar
#define MODE_UPTREND2         4                          // uptrends visible they are copied to buffer MODE_UPTREND2 which overlays
#define MODE_EMA_1            5                          // MODE_DOWNTREND.
#define MODE_EMA_2            6                          //
#define MODE_EMA_3            MODE_MA                    //

#property indicator_chart_window

#property indicator_buffers   5                          // configurable buffers (input dialog)
int       allocated_buffers = 7;                         // used buffers

#property indicator_width1    0
#property indicator_width2    0
#property indicator_width3    2
#property indicator_width4    2
#property indicator_width5    2

double firstEma       [];                                // first intermediate EMA buffer:  invisible
double secondEma      [];                                // second intermediate EMA buffer: invisible
double thirdEma       [];                                // TriEMA main value:              invisible, iCustom(), "Data" window
double bufferTrend    [];                                // trend direction:                invisible, iCustom()
double bufferUpTrend1 [];                                // uptrend values:                 visible
double bufferDownTrend[];                                // downtrend values:               visible, overlays uptrend values
double bufferUpTrend2 [];                                // single-bar uptrends:            visible, overlays downtrend values

int    ma.appliedPrice;
string ma.name;                                          // name for chart, "Data" window and context menues
string ma.legendLabel;

int    draw.type     = DRAW_LINE;                        // DRAW_LINE | DRAW_ARROW
int    draw.dot.size = 1;                                // default symbol size for Draw.Type = "Dot"


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   if (InitReason() == IR_RECOMPILE) {
      if (!RestoreInputParameters()) return(last_error);
   }

   // (1) validate inputs
   // MA.Periods
   if (MA.Periods < 1)     return(catch("onInit(1)  Invalid input parameter MA.Periods = "+ MA.Periods, ERR_INVALID_INPUT_PARAMETER));

   // MA.AppliedPrice
   string values[], sValue = StrToLower(MA.AppliedPrice);
   if (Explode(sValue, "*", values, 2) > 1) {
      int size = Explode(values[0], "|", values, NULL);
      sValue = values[size-1];
   }
   sValue = StrTrim(sValue);
   if (sValue == "") sValue = "close";                            // default price type
   ma.appliedPrice = StrToPriceType(sValue, F_ERR_INVALID_PARAMETER);
   if (IsEmpty(ma.appliedPrice)) {
      if      (StrStartsWith("open",     sValue)) ma.appliedPrice = PRICE_OPEN;
      else if (StrStartsWith("high",     sValue)) ma.appliedPrice = PRICE_HIGH;
      else if (StrStartsWith("low",      sValue)) ma.appliedPrice = PRICE_LOW;
      else if (StrStartsWith("close",    sValue)) ma.appliedPrice = PRICE_CLOSE;
      else if (StrStartsWith("median",   sValue)) ma.appliedPrice = PRICE_MEDIAN;
      else if (StrStartsWith("typical",  sValue)) ma.appliedPrice = PRICE_TYPICAL;
      else if (StrStartsWith("weighted", sValue)) ma.appliedPrice = PRICE_WEIGHTED;
      else                 return(catch("onInit(2)  Invalid input parameter MA.AppliedPrice = "+ DoubleQuoteStr(MA.AppliedPrice), ERR_INVALID_INPUT_PARAMETER));
   }
   MA.AppliedPrice = PriceTypeDescription(ma.appliedPrice);

   // Colors: after unserialization the terminal might turn CLR_NONE (0xFFFFFFFF) into Black (0xFF000000)
   if (Color.UpTrend   == 0xFF000000) Color.UpTrend   = CLR_NONE;
   if (Color.DownTrend == 0xFF000000) Color.DownTrend = CLR_NONE;

   // Draw.Type
   sValue = StrToLower(Draw.Type);
   if (Explode(sValue, "*", values, 2) > 1) {
      size = Explode(values[0], "|", values, NULL);
      sValue = values[size-1];
   }
   sValue = StrTrim(sValue);
   if      (StrStartsWith("line", sValue)) { draw.type = DRAW_LINE;  Draw.Type = "Line"; }
   else if (StrStartsWith("dot",  sValue)) { draw.type = DRAW_ARROW; Draw.Type = "Dot";  }
   else                    return(catch("onInit(3)  Invalid input parameter Draw.Type = "+ DoubleQuoteStr(Draw.Type), ERR_INVALID_INPUT_PARAMETER));

   // Draw.LineWidth
   if (Draw.LineWidth < 0) return(catch("onInit(4)  Invalid input parameter Draw.LineWidth = "+ Draw.LineWidth, ERR_INVALID_INPUT_PARAMETER));
   if (Draw.LineWidth > 5) return(catch("onInit(5)  Invalid input parameter Draw.LineWidth = "+ Draw.LineWidth, ERR_INVALID_INPUT_PARAMETER));

   // Max.Values
   if (Max.Values < -1)    return(catch("onInit(6)  Invalid input parameter Max.Values = "+ Max.Values, ERR_INVALID_INPUT_PARAMETER));


   // (2) setup buffer management
   SetIndexBuffer(MODE_EMA_1,     firstEma       );
   SetIndexBuffer(MODE_EMA_2,     secondEma      );
   SetIndexBuffer(MODE_EMA_3,     thirdEma       );
   SetIndexBuffer(MODE_TREND,     bufferTrend    );
   SetIndexBuffer(MODE_UPTREND1,  bufferUpTrend1 );
   SetIndexBuffer(MODE_UPTREND2,  bufferUpTrend2 );
   SetIndexBuffer(MODE_DOWNTREND, bufferDownTrend);


   // (3) data display configuration, names and labels
   string shortName="TriEMA("+ MA.Periods +")", strAppliedPrice="";
   if (ma.appliedPrice != PRICE_CLOSE) strAppliedPrice = ", "+ PriceTypeDescription(ma.appliedPrice);
   ma.name = "TriEMA("+ MA.Periods + strAppliedPrice +")";
   if (!IsSuperContext()) {                                    // no chart legend if called by iCustom()
       ma.legendLabel = CreateLegendLabel(ma.name);
       ObjectRegister(ma.legendLabel);
   }
   IndicatorShortName(shortName);                              // context menu
   SetIndexLabel(MODE_EMA_1,     NULL);
   SetIndexLabel(MODE_EMA_2,     NULL);
   SetIndexLabel(MODE_EMA_3,     shortName);                   // "Data" window and tooltips
   SetIndexLabel(MODE_TREND,     NULL);
   SetIndexLabel(MODE_UPTREND1,  NULL);
   SetIndexLabel(MODE_UPTREND2,  NULL);
   SetIndexLabel(MODE_DOWNTREND, NULL);
   IndicatorDigits(SubPipDigits);


   // (4) drawing options and styles
   int startDraw = 0;
   if (Max.Values >= 0) startDraw = Bars - Max.Values;
   if (startDraw  <  0) startDraw = 0;
   SetIndexDrawBegin(MODE_UPTREND1,  startDraw);
   SetIndexDrawBegin(MODE_UPTREND2,  startDraw);
   SetIndexDrawBegin(MODE_DOWNTREND, startDraw);
   SetIndicatorOptions();

   return(catch("onInit(7)"));
}


/**
 * Deinitialization
 *
 * @return int - error status
 */
int onDeinit() {
   DeleteRegisteredObjects(NULL);
   RepositionLegend();
   return(catch("onDeinit(1)"));
}


/**
 * Called before recompilation.
 *
 * @return int - error status
 */
int onDeinitRecompile() {
   StoreInputParameters();
   return(last_error);
}


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   // check for finished buffer initialization (needed on terminal start)
   if (!ArraySize(firstEma))
      return(log("onTick(1)  size(firstEma) = 0", SetLastError(ERS_TERMINAL_NOT_YET_READY)));

   // reset all buffers and delete garbage behind Max.Values before doing a full recalculation
   if (!ValidBars) {
      ArrayInitialize(firstEma,        EMPTY_VALUE);
      ArrayInitialize(secondEma,       EMPTY_VALUE);
      ArrayInitialize(thirdEma,        EMPTY_VALUE);
      ArrayInitialize(bufferTrend,               0);
      ArrayInitialize(bufferUpTrend1,  EMPTY_VALUE);
      ArrayInitialize(bufferUpTrend2,  EMPTY_VALUE);
      ArrayInitialize(bufferDownTrend, EMPTY_VALUE);
      SetIndicatorOptions();
   }

   // synchronize buffers with a shifted offline chart
   if (ShiftedBars > 0) {
      ShiftIndicatorBuffer(firstEma,        Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(secondEma,       Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(thirdEma,        Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(bufferTrend,     Bars, ShiftedBars,           0);
      ShiftIndicatorBuffer(bufferUpTrend1,  Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(bufferUpTrend2,  Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(bufferDownTrend, Bars, ShiftedBars, EMPTY_VALUE);
   }


   // (1) calculate start bar
   int changedBars = ChangedBars;
   if (Max.Values >= 0) /*&&*/ if (Max.Values < ChangedBars)         // Because EMA(EMA(EMA)) is used in the calculation, TriEMA needs
      changedBars = Max.Values;                                      // 3*<period>-2 samples to start producing values in contrast to
   int bar, startBar = Min(changedBars-1, Bars - (3*MA.Periods-2));  // <period> samples needed by a regular EMA.
   if (startBar < 0) return(catch("onTick(2)", ERR_HISTORY_INSUFFICIENT));


   // (2) recalculate invalid bars
   for (bar=ChangedBars-1; bar >= 0; bar--)   firstEma [bar] =        iMA(NULL,      NULL,        MA.Periods, 0, MODE_EMA, ma.appliedPrice, bar);
   for (bar=ChangedBars-1; bar >= 0; bar--)   secondEma[bar] = iMAOnArray(firstEma,  WHOLE_ARRAY, MA.Periods, 0, MODE_EMA,                  bar);
   for (bar=startBar;      bar >= 0; bar--) { thirdEma [bar] = iMAOnArray(secondEma, WHOLE_ARRAY, MA.Periods, 0, MODE_EMA,                  bar);
      // update trend and coloring
      @Trend.UpdateDirection(thirdEma, bar, bufferTrend, bufferUpTrend1, bufferDownTrend, bufferUpTrend2, draw.type, true, true, SubPipDigits);
   }


   // (3) update chart legend
   if (!IsSuperContext()) {
       @Trend.UpdateLegend(ma.legendLabel, ma.name, "", Color.UpTrend, Color.DownTrend, thirdEma[0], bufferTrend[0], Time[0]);
   }
   return(last_error);
}


/**
 * Workaround for various terminal bugs when setting indicator options. Usually options are set in init(). However after
 * recompilation options must be set in start() to not get ignored.
 */
void SetIndicatorOptions() {
   IndicatorBuffers(allocated_buffers);

   int drawWidth = ifInt(draw.type==DRAW_ARROW, draw.dot.size, Draw.LineWidth);
   int drawType  = ifInt(draw.type==DRAW_ARROW, DRAW_ARROW, ifInt(Draw.LineWidth, DRAW_LINE, DRAW_NONE));

   SetIndexStyle(MODE_MA,        DRAW_NONE, EMPTY, EMPTY);
   SetIndexStyle(MODE_TREND,     DRAW_NONE, EMPTY, EMPTY);
   SetIndexStyle(MODE_UPTREND1,  drawType,  EMPTY, drawWidth, Color.UpTrend  ); SetIndexArrow(MODE_UPTREND1,  159);
   SetIndexStyle(MODE_DOWNTREND, drawType,  EMPTY, drawWidth, Color.DownTrend); SetIndexArrow(MODE_DOWNTREND, 159);
   SetIndexStyle(MODE_UPTREND2,  drawType,  EMPTY, drawWidth, Color.UpTrend  ); SetIndexArrow(MODE_UPTREND2,  159);
}


/**
 * Store input parameters in the chart before recompilation.
 *
 * @return bool - success status
 */
bool StoreInputParameters() {
   Chart.StoreInt   (__NAME__ +".input.MA.Periods",      MA.Periods     );
   Chart.StoreString(__NAME__ +".input.MA.AppliedPrice", MA.AppliedPrice);
   Chart.StoreColor (__NAME__ +".input.Color.UpTrend",   Color.UpTrend  );
   Chart.StoreColor (__NAME__ +".input.Color.DownTrend", Color.DownTrend);
   Chart.StoreString(__NAME__ +".input.Draw.Type",       Draw.Type      );
   Chart.StoreInt   (__NAME__ +".input.Draw.LineWidth",  Draw.LineWidth );
   Chart.StoreInt   (__NAME__ +".input.Max.Values",      Max.Values     );
   return(!catch("StoreInputParameters(1)"));
}


/**
 * Restore input parameters found in the chart after recompilation.
 *
 * @return bool - success status
 */
bool RestoreInputParameters() {
   Chart.RestoreInt   ("MA.Periods",      MA.Periods     );
   Chart.RestoreString("MA.AppliedPrice", MA.AppliedPrice);
   Chart.RestoreColor ("Color.UpTrend",   Color.UpTrend  );
   Chart.RestoreColor ("Color.DownTrend", Color.DownTrend);
   Chart.RestoreString("Draw.Type",       Draw.Type      );
   Chart.RestoreInt   ("Draw.LineWidth",  Draw.LineWidth );
   Chart.RestoreInt   ("Max.Values",      Max.Values     );
   return(!catch("RestoreInputParameters(1)"));
}


/**
 * Return a string representation of the input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("MA.Periods=",      MA.Periods,                      ";", NL,
                            "MA.AppliedPrice=", DoubleQuoteStr(MA.AppliedPrice), ";", NL,

                            "Color.UpTrend=",   ColorToStr(Color.UpTrend),       ";", NL,
                            "Color.DownTrend=", ColorToStr(Color.DownTrend),     ";", NL,
                            "Draw.Type=",       DoubleQuoteStr(Draw.Type),       ";", NL,
                            "Draw.LineWidth=",  Draw.LineWidth,                  ";", NL,

                            "Max.Values=",      Max.Values,                      ";")
   );
}
