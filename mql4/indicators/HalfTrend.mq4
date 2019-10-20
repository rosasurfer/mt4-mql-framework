/**
 * HalfTrend indicator
 */
#include <stddefines.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern int    Periods         = 3;

extern color  Color.UpTrend   = DodgerBlue;              // indicator style management in MQL
extern color  Color.DownTrend = Red;
extern color  Color.Channel   = CLR_NONE;
extern string Draw.Type       = "Line* | Dot";
extern int    Draw.LineWidth  = 3;

extern int    Max.Values      = 5000;                    // max. amount of values to calculate (-1: all)

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <rsfLibs.mqh>

#define MODE_MAIN             HalfTrend.MODE_MAIN        // indicator buffer ids
#define MODE_TREND            HalfTrend.MODE_TREND
#define MODE_UP               2
#define MODE_DOWN             3
#define MODE_UPPER_BAND       4
#define MODE_LOWER_BAND       5

#property indicator_chart_window
#property indicator_buffers   6

#property indicator_color1    CLR_NONE
#property indicator_color2    CLR_NONE
#property indicator_color3    CLR_NONE
#property indicator_color4    CLR_NONE
#property indicator_color5    CLR_NONE
#property indicator_color6    CLR_NONE

double mainLine [];                                      // all SR values:      invisible, displayed in "Data" window
double trend    [];                                      // trend direction:    invisible
double upLine   [];                                      // support line:       visible
double downLine [];                                      // resistance line:    visible
double upperBand[];                                      // upper channel band: visible
double lowerBand[];                                      // lower channel band: visible

int    maxValues;
int    drawType      = DRAW_LINE;                        // DRAW_LINE | DRAW_ARROW
int    drawArrowSize = 1;                                // default symbol size for Draw.Type="dot"

string indicator.shortName;
string chart.legendLabel;


/**
 * Initialization.
 *
 * @return int - error status
 */
int onInit() {
   if (ProgramInitReason() == IR_RECOMPILE) {
      if (!RestoreInputParameters()) return(last_error);
   }

   // validate inputs
   // Periods
   if (Periods < 2) return(catch("onInit(1)  Invalid input parameter Periods = "+ Periods, ERR_INVALID_INPUT_PARAMETER));

   // Colors: after deserialization the terminal might turn CLR_NONE (0xFFFFFFFF) into Black (0xFF000000)
   if (Color.UpTrend   == 0xFF000000) Color.UpTrend   = CLR_NONE;
   if (Color.DownTrend == 0xFF000000) Color.DownTrend = CLR_NONE;
   if (Color.Channel   == 0xFF000000) Color.Channel   = CLR_NONE;

   // Draw.Type
   string values[], sValue = StrToLower(Draw.Type);
   if (Explode(sValue, "*", values, 2) > 1) {
      int size = Explode(values[0], "|", values, NULL);
      sValue = values[size-1];
   }
   sValue = StrTrim(sValue);
   if      (StrStartsWith("line", sValue)) { drawType = DRAW_LINE;  Draw.Type = "Line"; }
   else if (StrStartsWith("dot",  sValue)) { drawType = DRAW_ARROW; Draw.Type = "Dot";  }
   else                    return(catch("onInit(2)  Invalid input parameter Draw.Type = "+ DoubleQuoteStr(Draw.Type), ERR_INVALID_INPUT_PARAMETER));

   // Draw.LineWidth
   if (Draw.LineWidth < 0) return(catch("onInit(3)  Invalid input parameter Draw.LineWidth = "+ Draw.LineWidth, ERR_INVALID_INPUT_PARAMETER));
   if (Draw.LineWidth > 5) return(catch("onInit(4)  Invalid input parameter Draw.LineWidth = "+ Draw.LineWidth, ERR_INVALID_INPUT_PARAMETER));

   // Max.Values
   if (Max.Values < -1)    return(catch("onInit(5)  Invalid input parameter Max.Values = "+ Max.Values, ERR_INVALID_INPUT_PARAMETER));
   maxValues = ifInt(Max.Values==-1, INT_MAX, Max.Values);


   // buffer management
   SetIndexBuffer(MODE_MAIN,       mainLine );           // all SR values:      invisible, displayed in "Data" window
   SetIndexBuffer(MODE_TREND,      trend    );           // trend direction:    invisible
   SetIndexBuffer(MODE_UP,         upLine   );           // support line:       visible
   SetIndexBuffer(MODE_DOWN,       downLine );           // resistance line:    visible
   SetIndexBuffer(MODE_UPPER_BAND, upperBand);           // upper channel band: visible
   SetIndexBuffer(MODE_LOWER_BAND, lowerBand);           // lower channel band: visible

   // chart legend
   indicator.shortName = __NAME() +"("+ Periods +")";
   if (!IsSuperContext()) {
      chart.legendLabel = CreateLegendLabel(indicator.shortName);
      ObjectRegister(chart.legendLabel);
   }

   // names, labels, styles and display options
   IndicatorShortName(indicator.shortName);              // chart context menu
   SetIndexLabel(MODE_MAIN,  indicator.shortName);       // chart tooltips and "Data" window
   SetIndexLabel(MODE_TREND, __NAME() +" length");
   SetIndexLabel(MODE_UP,    NULL);
   SetIndexLabel(MODE_DOWN,  NULL);
   IndicatorDigits(Digits);
   SetIndicatorOptions();

   return(catch("onInit(6)"));
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
   return(NO_ERROR);
}


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   // check for finished buffer initialization (needed on terminal start)
   if (!ArraySize(mainLine))
      return(log("onTick(1)  size(mainLine) = 0", SetLastError(ERS_TERMINAL_NOT_YET_READY)));

   // reset all buffers before doing a full recalculation
   if (!UnchangedBars) {
      ArrayInitialize(mainLine,  EMPTY_VALUE);
      ArrayInitialize(trend,     0);
      ArrayInitialize(upLine,    EMPTY_VALUE);
      ArrayInitialize(downLine,  EMPTY_VALUE);
      ArrayInitialize(upperBand, EMPTY_VALUE);
      ArrayInitialize(lowerBand, EMPTY_VALUE);
      SetIndicatorOptions();
   }

   // synchronize buffers with a shifted offline chart
   if (ShiftedBars > 0) {
      ShiftIndicatorBuffer(mainLine,  Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(trend,     Bars, ShiftedBars, 0          );
      ShiftIndicatorBuffer(upLine,    Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(downLine,  Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(upperBand, Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(lowerBand, Bars, ShiftedBars, EMPTY_VALUE);
   }

   // calculate start bar
   int bars     = Min(ChangedBars, maxValues);
   int startBar = Min(bars-1, Bars-Periods);
   if (startBar < 0) {
      if (IsSuperContext()) return(catch("onTick(2)", ERR_HISTORY_INSUFFICIENT));
      SetLastError(ERR_HISTORY_INSUFFICIENT);      // set error but continue to update the legend
   }

   // recalculate changed bars
   for (int i=startBar; i>=0; i--) {
      upperBand[i] = iMA(NULL, NULL, Periods, 0, MODE_SMA, PRICE_HIGH, i);
      lowerBand[i] = iMA(NULL, NULL, Periods, 0, MODE_SMA, PRICE_LOW,  i);

      double currentHigh = iHigh(NULL, NULL, iHighest(NULL, NULL, MODE_HIGH, Periods, i));
      double currentLow  = iLow (NULL, NULL, iLowest (NULL, NULL, MODE_LOW,  Periods, i));

      // update trend direction and main SR values
      if (trend[i+1] > 0) {
         mainLine[i] = MathMax(mainLine[i+1], currentLow);
         if (upperBand[i] < mainLine[i] && Close[i] < Low[i+1]) {
            trend   [i] = -1;
            mainLine[i] = MathMin(mainLine[i+1], currentHigh);
         }
         else trend[i] = trend[i+1] + 1;
      }
      else if (trend[i+1] < 0) {
         mainLine[i] = MathMin(mainLine[i+1], currentHigh);
         if (lowerBand[i] > mainLine[i] && Close[i] > High[i+1]) {
            trend   [i] = 1;
            mainLine[i] = MathMax(mainLine[i+1], currentLow);
         }
         else trend[i] = trend[i+1] - 1;
      }
      else {
         // initialize the first, left-most value
         if (Close[i] > Close[i+1]) {
            trend   [i] = 1;
            mainLine[i] = currentLow;
         }
         else {
            trend   [i] = -1;
            mainLine[i] = currentHigh;
         }
      }


      // update trend visualization and coloring
      if (trend[i] > 0) {
         upLine  [i] = mainLine[i];
         downLine[i] = EMPTY_VALUE;
         if (trend[i+1] < 0 && drawType==DRAW_LINE) {       // make sure the reversal is visible
            upLine[i+1] = downLine[i+1];
         }
      }
      else /* trend[i] < 0 */{
         upLine  [i] = EMPTY_VALUE;
         downLine[i] = mainLine[i];
         if (trend[i+1] > 0 && drawType==DRAW_LINE) {       // make sure the reversal is visible
            downLine[i+1] = upLine[i+1];
         }
      }
   }
   return(catch("onTick(3)"));
}


/**
 * Workaround for various terminal bugs when setting indicator options. Usually options are set in init(). However after
 * recompilation options must be set in start() to not get ignored.
 */
void SetIndicatorOptions() {
   IndicatorBuffers(indicator_buffers);

   int dType  = ifInt(drawType==DRAW_ARROW, DRAW_ARROW, ifInt(Draw.LineWidth, DRAW_LINE, DRAW_NONE));
   int dWidth = ifInt(drawType==DRAW_ARROW, drawArrowSize, Draw.LineWidth);

   SetIndexStyle(MODE_MAIN,       DRAW_NONE, EMPTY, EMPTY);
   SetIndexStyle(MODE_TREND,      DRAW_NONE, EMPTY, EMPTY);
   SetIndexStyle(MODE_UP,         dType,     EMPTY, dWidth, Color.UpTrend  ); SetIndexArrow(MODE_UP,   159);
   SetIndexStyle(MODE_DOWN,       dType,     EMPTY, dWidth, Color.DownTrend); SetIndexArrow(MODE_DOWN, 159);
   SetIndexStyle(MODE_UPPER_BAND, DRAW_LINE, EMPTY, EMPTY,  Color.Channel  );
   SetIndexStyle(MODE_LOWER_BAND, DRAW_LINE, EMPTY, EMPTY,  Color.Channel  );

   if (Color.Channel == CLR_NONE) {
      SetIndexLabel(MODE_UPPER_BAND, NULL);
      SetIndexLabel(MODE_LOWER_BAND, NULL);
   }
   else {
      SetIndexLabel(MODE_UPPER_BAND, __NAME() +" upper band");
      SetIndexLabel(MODE_LOWER_BAND, __NAME() +" lower band");
   }
}


/**
 * Store input parameters in the chart before recompilation.
 *
 * @return bool - success status
 */
bool StoreInputParameters() {
   string name = __NAME();
   Chart.StoreInt   (name +".input.Periods",         Periods        );
   Chart.StoreColor (name +".input.Color.UpTrend",   Color.UpTrend  );
   Chart.StoreColor (name +".input.Color.DownTrend", Color.DownTrend);
   Chart.StoreColor (name +".input.Color.Channel",   Color.Channel  );
   Chart.StoreString(name +".input.Draw.Type",       Draw.Type      );
   Chart.StoreInt   (name +".input.Draw.LineWidth",  Draw.LineWidth );
   Chart.StoreInt   (name +".input.Max.Values",      Max.Values     );
   return(!catch("StoreInputParameters(1)"));
}


/**
 * Restore input parameters found in the chart after recompilation.
 *
 * @return bool - success status
 */
bool RestoreInputParameters() {
   string name = __NAME();
   Chart.RestoreInt   (name +".input.Periods",         Periods        );
   Chart.RestoreColor (name +".input.Color.UpTrend",   Color.UpTrend  );
   Chart.RestoreColor (name +".input.Color.DownTrend", Color.DownTrend);
   Chart.RestoreColor (name +".input.Color.Channel",   Color.Channel  );
   Chart.RestoreString(name +".input.Draw.Type",       Draw.Type      );
   Chart.RestoreInt   (name +".input.Draw.LineWidth",  Draw.LineWidth );
   Chart.RestoreInt   (name +".input.Max.Values",      Max.Values     );
   return(!catch("RestoreInputParameters(1)"));
}


/**
 * Return a string representation of the input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("Periods=",         Periods,                     ";", NL,
                            "Color.UpTrend=",   ColorToStr(Color.UpTrend),   ";", NL,
                            "Color.DownTrend=", ColorToStr(Color.DownTrend), ";", NL,
                            "Color.Channel=",   ColorToStr(Color.Channel),   ";", NL,
                            "Draw.Type=",       DoubleQuoteStr(Draw.Type),   ";", NL,
                            "Draw.LineWidth=",  Draw.LineWidth,              ";", NL,
                            "Max.Values=",      Max.Values,                  ";")
   );
}
