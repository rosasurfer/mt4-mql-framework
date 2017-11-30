/**
 * Multi-color/multi-timeframe moving average
 *
 *
 * Supported MA types:
 *  • SMA  - Simple Moving Average:          equal bar weighting
 *  • TMA  - Triangular Moving Average:      SMA which has been averaged again: SMA(SMA(n/2)/2), more smooth but more lag
 *  • LWMA - Linear Weighted Moving Average: bar weighting using a linear function
 *  • EMA  - Exponential Moving Average:     bar weighting using an exponential function
 *  • ALMA - Arnaud Legoux Moving Average:   bar weighting using a Gaussian function
 *
 * Intentionally unsupported MA types:
 *  • SMMA - Smoothed Moving Average: an EMA of a different period (legacy approach to speed-up calculation)
 *
 * The indicator buffer MovingAverage.MODE_MA contains the MA values.
 * The indicator buffer MovingAverage.MODE_TREND contains trend direction and trend length values:
 *  • trend direction: positive values present an up-trend (+1...+n), negative values a down-trend (-1...-n)
 *  • trend length:    the absolute trend direction value is the length of the trend since the last trend reversal
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern int    MA.Periods            = 38;
extern string MA.Timeframe          = "current";            // M1|M5|M15|..., "" = current timeframe
extern string MA.Method             = "SMA* | TMA | LWMA | EMA | ALMA";
extern string MA.AppliedPrice       = "Open | High | Low | Close* | Median | Typical | Weighted";

extern color  Color.UpTrend         = Blue;                 // indicator style management in MQL
extern color  Color.DownTrend       = Red;
extern string Drawing.Type          = "Line* | Dot";
extern int    Drawing.Line.Width    = 2;

extern int    Max.Values            = 2000;                 // max. number of values to calculate (-1: all)
extern int    Shift.Vertical.Pips   = 0;                    // vertical indicator shift in pips
extern int    Shift.Horizontal.Bars = 0;                    // horizontal indicator shift in bars

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <stdlibs.mqh>
#include <iFunctions/@ALMA.mqh>
#include <iFunctions/@Trend.mqh>

#define MODE_MA             MovingAverage.MODE_MA           // indicator buffer ids
#define MODE_TREND          MovingAverage.MODE_TREND        //
#define MODE_UPTREND        2                               // Drawing.Type=Line: If a down-trend is interrupted by a one-bar up-trend this
#define MODE_DOWNTREND      3                               // up-trend is covered by the continuing down-trend. To make single-bar up-trends
#define MODE_UPTREND1       MODE_UPTREND                    // visible they are copied to buffer MODE_UPTREND2 which must overlay buffer
#define MODE_UPTREND2       4                               // MODE_DOWNTREND.
#define MODE_TMA_SMA        5                               //

#property indicator_chart_window

#property indicator_buffers 5

#property indicator_width1  0
#property indicator_width2  0
#property indicator_width3  2
#property indicator_width4  2
#property indicator_width5  2

double bufferMA       [];                                   // all MA values:        invisible, displayed in Data window
double bufferTrend    [];                                   // trend direction:      invisible
double bufferUpTrend1 [];                                   // up-trend values:      visible
double bufferDownTrend[];                                   // down-trend values:    visible, overlays up-trend values
double bufferUpTrend2 [];                                   // single-bar up-trends: visible, overlays down-trend values

int    ma.periods;
int    ma.method;
int    ma.appliedPrice;
string ma.shortName;                                        // name for chart, Data window and context menues

int    tma.periods.1;                                       // TMA sub periods
int    tma.periods.2;
double tma.bufferSMA[];                                     // TMA intermediate SMA buffer

double alma.weights[];                                      // ALMA weights

int    drawing.type       = DRAW_LINE;                      // DRAW_LINE | DRAW_ARROW
int    drawing.arrow.size = 1;                              // Drawing.Type="dot": default symbol size
double shift.vertical;
string legendLabel;


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   // (1) validate inputs
   // MA.Periods
   if (MA.Periods < 1)         return(catch("onInit(1)  Invalid input parameter MA.Periods = "+ MA.Periods, ERR_INVALID_INPUT_PARAMETER));
   ma.periods = MA.Periods;

   // MA.Timeframe
   string sValue = StringToUpper(StringTrim(MA.Timeframe));
   if (sValue == "CURRENT")     sValue = "";
   if (sValue == ""       ) int ma.timeframe = Period();
   else                         ma.timeframe = StrToPeriod(sValue, F_ERR_INVALID_PARAMETER);
   if (ma.timeframe == -1)     return(catch("onInit(2)  Invalid input parameter MA.Timeframe = "+ DoubleQuoteStr(MA.Timeframe), ERR_INVALID_INPUT_PARAMETER));
   if (ma.timeframe != Period()) {
      double minutes = ma.timeframe * ma.periods;                       // convert specified to current timeframe
      ma.periods = MathRound(minutes/Period());                         // Timeframe * Amount_Bars = Range_in_Minutes
   }
   MA.Timeframe = ifString(sValue=="", "", PeriodDescription(ma.timeframe));

   // MA.Method
   string strValue, elems[];
   if (Explode(MA.Method, "*", elems, 2) > 1) {
      int size = Explode(elems[0], "|", elems, NULL);
      strValue = elems[size-1];
   }
   else {
      strValue = StringTrim(MA.Method);
      if (strValue == "") strValue = "SMA";                             // default MA method
   }
   ma.method = StrToMaMethod(strValue, F_ERR_INVALID_PARAMETER);
   if (ma.method == -1)        return(catch("onInit(3)  Invalid input parameter MA.Method = "+ DoubleQuoteStr(MA.Method), ERR_INVALID_INPUT_PARAMETER));
   MA.Method = MaMethodDescription(ma.method);

   // MA.AppliedPrice
   if (Explode(MA.AppliedPrice, "*", elems, 2) > 1) {
      size     = Explode(elems[0], "|", elems, NULL);
      strValue = elems[size-1];
   }
   else {
      strValue = StringTrim(MA.AppliedPrice);
      if (strValue == "") strValue = "Close";                           // default price type
   }
   ma.appliedPrice = StrToPriceType(strValue, F_ERR_INVALID_PARAMETER);
   if (ma.appliedPrice==-1 || ma.appliedPrice > PRICE_WEIGHTED)
                               return(catch("onInit(4)  Invalid input parameter MA.AppliedPrice = "+ DoubleQuoteStr(MA.AppliedPrice), ERR_INVALID_INPUT_PARAMETER));
   MA.AppliedPrice = PriceTypeDescription(ma.appliedPrice);

   // Colors
   if (Color.UpTrend   == 0xFF000000) Color.UpTrend   = CLR_NONE;       // can be messed-up by the terminal after deserialization
   if (Color.DownTrend == 0xFF000000) Color.DownTrend = CLR_NONE;

   // Drawing.Type
   if (Explode(Drawing.Type, "*", elems, 2) > 1) {
      size     = Explode(elems[0], "|", elems, NULL);
      strValue = elems[size-1];
   }
   else strValue = Drawing.Type;
   strValue = StringToLower(StringTrim(strValue));
   if      (strValue == "line") drawing.type = DRAW_LINE;
   else if (strValue == "dot" ) drawing.type = DRAW_ARROW;
   else                        return(catch("onInit(5)  Invalid input parameter Drawing.Type = "+ DoubleQuoteStr(Drawing.Type), ERR_INVALID_INPUT_PARAMETER));
   Drawing.Type = StringCapitalize(strValue);

   // Drawing.Line.Width
   if (Drawing.Line.Width < 1) return(catch("onInit(6)  Invalid input parameter Drawing.Line.Width = "+ Drawing.Line.Width, ERR_INVALID_INPUT_PARAMETER));
   if (Drawing.Line.Width > 5) return(catch("onInit(7)  Invalid input parameter Drawing.Line.Width = "+ Drawing.Line.Width, ERR_INVALID_INPUT_PARAMETER));

   // Max.Values
   if (Max.Values < -1)        return(catch("onInit(8)  Invalid input parameter Max.Values = "+ Max.Values, ERR_INVALID_INPUT_PARAMETER));


   // (2) setup buffer management
   IndicatorBuffers(6);
   SetIndexBuffer(MODE_MA,        bufferMA       );                     // all MA values:        invisible, displayed in Data window
   SetIndexBuffer(MODE_TREND,     bufferTrend    );                     // trend direction:      invisible
   SetIndexBuffer(MODE_UPTREND1,  bufferUpTrend1 );                     // up-trend values:      visible
   SetIndexBuffer(MODE_DOWNTREND, bufferDownTrend);                     // down-trend values:    visible, overlays up-trend values
   SetIndexBuffer(MODE_UPTREND2,  bufferUpTrend2 );                     // single-bar up-trends: visible, overlays down-trend values
   SetIndexBuffer(MODE_TMA_SMA,   tma.bufferSMA  );                     // intermediate buffer:  invisible


   // (3) data display configuration
   // chart legend
   string strTimeframe="", strAppliedPrice="";
   if (MA.Timeframe != "")             strTimeframe    = "x"+ MA.Timeframe;
   if (ma.appliedPrice != PRICE_CLOSE) strAppliedPrice = ", "+ PriceTypeDescription(ma.appliedPrice);
   ma.shortName  = MA.Method +"("+ MA.Periods + strTimeframe + strAppliedPrice +")";
   if (!IsSuperContext()) {                                             // prevent chart modification if called by iCustom()
       legendLabel = CreateLegendLabel(ma.shortName);
       ObjectRegister(legendLabel);
   }

   // names and labels
   IndicatorShortName(ma.shortName);                                    // context menu
   string ma.dataName = MA.Method +"("+ MA.Periods + strTimeframe +")";
   SetIndexLabel(MODE_MA,        ma.dataName);                          // Data window and tooltips
   SetIndexLabel(MODE_TREND,     NULL);
   SetIndexLabel(MODE_UPTREND1,  NULL);
   SetIndexLabel(MODE_DOWNTREND, NULL);
   SetIndexLabel(MODE_UPTREND2,  NULL);
   SetIndexLabel(MODE_TMA_SMA,   NULL);
   IndicatorDigits(SubPipDigits);


   // (4) drawing options and styles
   int startDraw  = Max(ma.periods-1, Bars-ifInt(Max.Values < 0, Bars, Max.Values)) + Shift.Horizontal.Bars;
   shift.vertical = Shift.Vertical.Pips * Pips;                                                          // TODO: handle Digits/Point errors
   SetIndexDrawBegin(MODE_MA,        0        ); SetIndexShift(MODE_MA,        Shift.Horizontal.Bars);
   SetIndexDrawBegin(MODE_TREND,     0        ); SetIndexShift(MODE_TREND,     Shift.Horizontal.Bars);
   SetIndexDrawBegin(MODE_UPTREND1,  startDraw); SetIndexShift(MODE_UPTREND1,  Shift.Horizontal.Bars);
   SetIndexDrawBegin(MODE_DOWNTREND, startDraw); SetIndexShift(MODE_DOWNTREND, Shift.Horizontal.Bars);
   SetIndexDrawBegin(MODE_UPTREND2,  startDraw); SetIndexShift(MODE_UPTREND2,  Shift.Horizontal.Bars);
   SetIndexDrawBegin(MODE_TMA_SMA,   0        ); SetIndexShift(MODE_TMA_SMA,   Shift.Horizontal.Bars);
   SetIndicatorStyles();                                                // fix for various terminal bugs


   // (5) initialize indicator calculations where applicable
   if (ma.periods > 1) {                                                // can be < 2 when switching to a too long timeframe
      if (ma.method == MODE_TMA) {
         tma.periods.1 = MA.Periods / 2;
         tma.periods.2 = MA.Periods - tma.periods.1 + 1;                // sub periods overlap by one bar: TMA(2) = SMA(1) + SMA(2)
      }
      else if (ma.method == MODE_ALMA) {
         @ALMA.CalculateWeights(alma.weights, ma.periods);
      }
   }

   return(catch("onInit(9)"));
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
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   // check for finished buffer initialization
   if (ArraySize(bufferMA) == 0)                                        // can happen on terminal start
      return(debug("onTick(1)  size(bufferMA) = 0", SetLastError(ERS_TERMINAL_NOT_YET_READY)));

   // reset all buffers (and delete garbage behind Max.Values) before doing a full recalculation
   if (!ValidBars) {
      ArrayInitialize(bufferMA,        EMPTY_VALUE);
      ArrayInitialize(bufferTrend,               0);
      ArrayInitialize(bufferUpTrend1,  EMPTY_VALUE);
      ArrayInitialize(bufferDownTrend, EMPTY_VALUE);
      ArrayInitialize(bufferUpTrend2,  EMPTY_VALUE);
      ArrayInitialize(tma.bufferSMA,   EMPTY_VALUE);
      SetIndicatorStyles();                                             // fix for various terminal bugs
   }

   // synchronize buffers with a shifted offline chart (if applicable)
   if (ShiftedBars > 0) {
      ShiftIndicatorBuffer(bufferMA,        Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(bufferTrend,     Bars, ShiftedBars,           0);
      ShiftIndicatorBuffer(bufferUpTrend1,  Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(bufferDownTrend, Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(bufferUpTrend2,  Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(tma.bufferSMA,   Bars, ShiftedBars, EMPTY_VALUE);
   }

   if (ma.periods < 2)                                                  // abort when switching to a too long timeframe
      return(NO_ERROR);


   // (1) calculate start bar
   int changedBars = ChangedBars;
   if (Max.Values >= 0) /*&&*/ if (ChangedBars > Max.Values)
      changedBars = Max.Values;
   int ma.startBar = Min(changedBars-1, Bars-ma.periods);
   if (ma.startBar < 0) return(catch("onTick(2)", ERR_HISTORY_INSUFFICIENT));


   // (2) recalculate invalid bars
   if (ma.method == MODE_TMA) {
      // pre-calculate the TMA's intermediate SMA
      for (int bar=ma.startBar; bar >= 0; bar--) {
         tma.bufferSMA[bar] = iMA(NULL, NULL, tma.periods.1, 0, MODE_SMA, ma.appliedPrice, bar);
      }
   }

   for (bar=ma.startBar; bar >= 0; bar--) {
      // final moving average
      if (ma.method == MODE_TMA) {
         bufferMA[bar] = iMAOnArray(tma.bufferSMA, WHOLE_ARRAY, tma.periods.2, 0, MODE_SMA, bar);
      }
      else if (ma.method == MODE_ALMA) {
         bufferMA[bar] = 0;
         for (int i=0; i < ma.periods; i++) {
            bufferMA[bar] += alma.weights[i] * iMA(NULL, NULL, 1, 0, MODE_SMA, ma.appliedPrice, bar+i);
         }
      }
      else {                                                            // regular built-in MA
         bufferMA[bar] = iMA(NULL, NULL, ma.periods, 0, ma.method, ma.appliedPrice, bar);
      }
      bufferMA[bar] += shift.vertical;

      // trend direction and length
      @Trend.UpdateDirection(bufferMA, bar, bufferTrend, bufferUpTrend1, bufferDownTrend, drawing.type, bufferUpTrend2, true, SubPipDigits);
   }


   // (3) update legend
   if (!IsSuperContext()) {
       @Trend.UpdateLegend(legendLabel, ma.shortName, "", Color.UpTrend, Color.DownTrend, bufferMA[0], bufferTrend[0], Time[0]);
   }
   return(last_error);
}


/**
 * Set indicator styles. Moved to a separate function to fix various terminal bugs when setting styles. Usually styles must be applied in
 * init(). However after recompilation styles must be applied in start() to not get lost.
 */
void SetIndicatorStyles() {
   int width = ifInt(drawing.type==DRAW_ARROW, drawing.arrow.size, Drawing.Line.Width);

   SetIndexStyle(MODE_MA,        DRAW_NONE,    EMPTY, EMPTY, CLR_NONE       );
   SetIndexStyle(MODE_TREND,     DRAW_NONE,    EMPTY, EMPTY, CLR_NONE       );
   SetIndexStyle(MODE_UPTREND1,  drawing.type, EMPTY, width, Color.UpTrend  ); SetIndexArrow(MODE_UPTREND1,  159);
   SetIndexStyle(MODE_DOWNTREND, drawing.type, EMPTY, width, Color.DownTrend); SetIndexArrow(MODE_DOWNTREND, 159);
   SetIndexStyle(MODE_UPTREND2,  drawing.type, EMPTY, width, Color.UpTrend  ); SetIndexArrow(MODE_UPTREND2,  159);
}


/**
 * Return a string presentation of the input parameters (logging).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("input: ",

                            "MA.Periods=",            MA.Periods,                      "; ",
                            "MA.Timeframe=",          DoubleQuoteStr(MA.Timeframe),    "; ",
                            "MA.Method=",             DoubleQuoteStr(MA.Method),       "; ",
                            "MA.AppliedPrice=",       DoubleQuoteStr(MA.AppliedPrice), "; ",

                            "Color.UpTrend=",         ColorToStr(Color.UpTrend),       "; ",
                            "Color.DownTrend=",       ColorToStr(Color.DownTrend),     "; ",
                            "Drawing.Type=",          DoubleQuoteStr(Drawing.Type),    "; ",
                            "Drawing.Line.Width=",    Drawing.Line.Width,              "; ",


                            "Max.Values=",            Max.Values,                      "; ",
                            "Shift.Vertical.Pips=",   Shift.Vertical.Pips,             "; ",
                            "Shift.Horizontal.Bars=", Shift.Horizontal.Bars,           "; ",

                            "__lpSuperContext=0x",    IntToHexStr(__lpSuperContext),   "; ")
   );
}
