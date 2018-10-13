/**
 * Ehlers' Two-Pole Super Smoother Filter
 *
 * as described in his book "Cybernetic Analysis for Stocks and Futures". Very similar to the ALMA. The Super Smoother is
 * a bit more smooth but also lags a bit more.
 *
 *
 * Indicator buffers to use with iCustom():
 *  • Filter.MODE_MAIN:  main line values
 *  • Filter.MODE_TREND: trend direction and length
 *    - direction: positive values denote an uptrend (+1...+n), negative values a downtrend (-1...-n)
 *    - length:    the absolute direction value is the length of the trend in bars since the last reversal
 *
 *
 * @see      [Ehlers](etc/doc/ehlers/Cybernetic Analysis for Stocks and Futures.pdf)
 * @credits  The original MQL implementation was provided by Witold Wozniak (http://www.mqlsoft.com/).
 *
 *
 * TODO:
 *    - implement PRICE_* types
 *    - implement Max.Values
 *    - check required run-up period
 */
#include <stddefines.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern int    Filter.Periods  = 38;

extern color  Color.UpTrend   = RoyalBlue;            // indicator style management in MQL
extern color  Color.DownTrend = Gold;
extern string Draw.Type       = "Line* | Dot";
extern int    Draw.LineWidth  = 3;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <rsfLibs.mqh>
#include <functions/@Trend.mqh>

#define MODE_MAIN             Filter.MODE_MAIN        // indicator buffer ids
#define MODE_TREND            Filter.MODE_TREND       //
#define MODE_UPTREND          2                       // Draw.Type=Line: If a downtrend is interrupted by a one-bar uptrend this
#define MODE_DOWNTREND        3                       // uptrend is covered by the continuing downtrend. To make single-bar uptrends
#define MODE_UPTREND1         MODE_UPTREND            // visible they are copied to buffer MODE_UPTREND2 which overlays MODE_DOWNTREND.
#define MODE_UPTREND2         4                       //

#property indicator_chart_window
#property indicator_buffers   5                       // configurable buffers (input dialog)
int       allocated_buffers = 5;                      // used buffers

double bufferMain     [];                             // all filter values:   invisible, displayed in "Data" window
double bufferTrend    [];                             // trend direction:     invisible
double bufferUpTrend1 [];                             // uptrend values:      visible
double bufferDownTrend[];                             // downtrend values:    visible, overlays uptrend values
double bufferUpTrend2 [];                             // single-bar uptrends: visible, overlays downtrend values

int    filter.periods;
string filter.longName;                               // name for chart legend
string filter.shortName;                              // name for "Data" window and context menues
string filter.legendLabel;

int    draw.type     = DRAW_LINE;                     // DRAW_LINE | DRAW_ARROW
int    draw.dot.size = 1;                             // default symbol size for Draw.Type="Dot"


double coef1, coef2, coef3;


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
   // Filter.Periods
   if (Filter.Periods < 1) return(catch("onInit(1)  Invalid input parameter Filter.Periods = "+ Filter.Periods, ERR_INVALID_INPUT_PARAMETER));

   // Colors: after unserialization the terminal might turn CLR_NONE (0xFFFFFFFF) into Black (0xFF000000)
   if (Color.UpTrend   == 0xFF000000) Color.UpTrend   = CLR_NONE;
   if (Color.DownTrend == 0xFF000000) Color.DownTrend = CLR_NONE;

   // Draw.Type
   string values[], sValue = StringToLower(Draw.Type);
   if (Explode(sValue, "*", values, 2) > 1) {
      int size = Explode(values[0], "|", values, NULL);
      sValue = values[size-1];
   }
   sValue = StringTrim(sValue);
   if      (StrStartsWith("line", sValue)) { draw.type = DRAW_LINE;  Draw.Type = "Line"; }
   else if (StrStartsWith("dot",  sValue)) { draw.type = DRAW_ARROW; Draw.Type = "Dot";  }
   else                    return(catch("onInit(2)  Invalid input parameter Draw.Type = "+ DoubleQuoteStr(Draw.Type), ERR_INVALID_INPUT_PARAMETER));

   // Draw.LineWidth
   if (Draw.LineWidth < 0) return(catch("onInit(3)  Invalid input parameter Draw.LineWidth = "+ Draw.LineWidth, ERR_INVALID_INPUT_PARAMETER));
   if (Draw.LineWidth > 5) return(catch("onInit(4)  Invalid input parameter Draw.LineWidth = "+ Draw.LineWidth, ERR_INVALID_INPUT_PARAMETER));


   // (2) setup buffer management
   SetIndexBuffer(MODE_MAIN,      bufferMain     );            // all filter values:   invisible, displayed in "Data" window
   SetIndexBuffer(MODE_TREND,     bufferTrend    );            // trend direction:     invisible
   SetIndexBuffer(MODE_UPTREND1,  bufferUpTrend1 );            // uptrend values:      visible
   SetIndexBuffer(MODE_DOWNTREND, bufferDownTrend);            // downtrend values:    visible, overlays uptrend values
   SetIndexBuffer(MODE_UPTREND2,  bufferUpTrend2 );            // single-bar uptrends: visible, overlays downtrend values


   // (3) data display configuration, names and labels
   filter.longName  = "2-Pole-SuperSmoother("+ Filter.Periods +")";
   filter.shortName = "2P-SuperSmoother("+ Filter.Periods +")";
   if (!IsSuperContext()) {                                    // no chart legend if called by iCustom()
       filter.legendLabel = CreateLegendLabel(filter.longName);
       ObjectRegister(filter.legendLabel);
   }
   IndicatorShortName(filter.shortName);                       // context menu
   SetIndexLabel(MODE_MAIN,      filter.shortName);            // "Data" window and tooltips
   SetIndexLabel(MODE_TREND,     NULL);
   SetIndexLabel(MODE_UPTREND1,  NULL);
   SetIndexLabel(MODE_UPTREND2,  NULL);
   SetIndexLabel(MODE_DOWNTREND, NULL);
   IndicatorDigits(SubPipDigits);


   // (4) drawing options and styles
   int startDraw = 4;                                          // calculation of the the first bars is not exact
   SetIndexDrawBegin(MODE_UPTREND1,  startDraw);
   SetIndexDrawBegin(MODE_UPTREND2,  startDraw);
   SetIndexDrawBegin(MODE_DOWNTREND, startDraw);
   SetIndicatorOptions();


   // (5) init indicator calculation
   double rad2Deg = 45.0 / MathArctan(1);
   double deg2Rad =  1.0 / rad2Deg;

   double a1 = MathExp(-MathSqrt(2.0) * Math.PI / Filter.Periods);
   double b1 = 2 * a1 * MathCos(deg2Rad * MathSqrt(2.0) * 180.0 / Filter.Periods);

   coef2 = b1;
   coef3 = -a1 * a1;
   coef1 = 1 - coef2 - coef3;

   return(catch("onInit(5)"));
}


/**
 * Deinitialization
 *
 * @return int - error status
 */
int onDeinit() {
   DeleteRegisteredObjects(NULL);
   RepositionLegend();
   return(last_error);
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
   if (!ArraySize(bufferMain))
      return(log("onTick(1)  size(buffeMain) = 0", SetLastError(ERS_TERMINAL_NOT_YET_READY)));

   // reset all buffers and delete garbage behind Max.Values before doing a full recalculation
   if (!ValidBars) {
      ArrayInitialize(bufferMain,      EMPTY_VALUE);
      ArrayInitialize(bufferTrend,               0);
      ArrayInitialize(bufferUpTrend1,  EMPTY_VALUE);
      ArrayInitialize(bufferUpTrend2,  EMPTY_VALUE);
      ArrayInitialize(bufferDownTrend, EMPTY_VALUE);
      SetIndicatorOptions();
   }

   // synchronize buffers with a shifted offline chart
   if (ShiftedBars > 0) {
      ShiftIndicatorBuffer(bufferMain,      Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(bufferTrend,     Bars, ShiftedBars,           0);
      ShiftIndicatorBuffer(bufferUpTrend1,  Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(bufferUpTrend2,  Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(bufferDownTrend, Bars, ShiftedBars, EMPTY_VALUE);
   }


   // (1) recalculate invalid bars
   for (int bar=ChangedBars-1; bar >= 0; bar--) {
      if (bar > Bars-3) bufferMain[bar] = Price(bar);                   // prevent index out of range errors
      else              bufferMain[bar] = coef1*Price(bar) + coef2*bufferMain[bar+1] + coef3*bufferMain[bar+2];

      // calculate trend direction and length
      @Trend.UpdateDirection(bufferMain, bar, bufferTrend, bufferUpTrend1, bufferDownTrend, bufferUpTrend2, draw.type, true, true, SubPipDigits);
   }


   // (2) update chart legend
   if (!IsSuperContext()) {
      @Trend.UpdateLegend(filter.legendLabel, filter.longName, "", Color.UpTrend, Color.DownTrend, bufferMain[0], bufferTrend[0], Time[0]);
   }
   return(last_error);
}


/**
 *
 */
double Price(int bar) {
   return((High[bar] + Low[bar]) / 2);
}


/**
 * Workaround for various terminal bugs when setting indicator options. Usually options are set in init(). However after
 * recompilation options must be set in start() to not get ignored.
 */
void SetIndicatorOptions() {
   IndicatorBuffers(allocated_buffers);

   int drawType  = ifInt(draw.type==DRAW_ARROW, DRAW_ARROW, ifInt(Draw.LineWidth, DRAW_LINE, DRAW_NONE));
   int drawWidth = ifInt(draw.type==DRAW_ARROW, draw.dot.size, Draw.LineWidth);

   SetIndexStyle(MODE_MAIN,      DRAW_NONE, EMPTY, EMPTY);
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
   Chart.StoreInt   (__NAME__ +".input.Filter.Periods",  Filter.Periods );
   Chart.StoreColor (__NAME__ +".input.Color.UpTrend",   Color.UpTrend  );
   Chart.StoreColor (__NAME__ +".input.Color.DownTrend", Color.DownTrend);
   Chart.StoreString(__NAME__ +".input.Draw.Type",       Draw.Type      );
   Chart.StoreInt   (__NAME__ +".input.Draw.LineWidth",  Draw.LineWidth );
   return(!catch("StoreInputParameters(1)"));
}


/**
 * Restore input parameters found in the chart after recompilation.
 *
 * @return bool - success status
 */
bool RestoreInputParameters() {
   Chart.RestoreInt   ("Filter.Periods",  Filter.Periods );
   Chart.RestoreColor ("Color.UpTrend",   Color.UpTrend  );
   Chart.RestoreColor ("Color.DownTrend", Color.DownTrend);
   Chart.RestoreString("Draw.Type",       Draw.Type      );
   Chart.RestoreInt   ("Draw.LineWidth",  Draw.LineWidth );
   return(!catch("RestoreInputParameters(1)"));
}


/**
 * Return a string representation of the input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("Filter.Periods=",  Filter.Periods,              ";", NL,

                            "Color.UpTrend=",   ColorToStr(Color.UpTrend),   ";", NL,
                            "Color.DownTrend=", ColorToStr(Color.DownTrend), ";", NL,
                            "Draw.Type=",       DoubleQuoteStr(Draw.Type),   ";", NL,
                            "Draw.LineWidth=",  Draw.LineWidth,              ";")
   );
}
