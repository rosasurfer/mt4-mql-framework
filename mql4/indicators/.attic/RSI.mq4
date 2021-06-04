/**
 * RSI (Relative Strength Index) - an implementation supporting the display as histogram
 *
 *
 * The RSI (Relative Strength Index) is the EMA-smoothed ratio of gains to losses during a lookback period, again normalized
 * to a value from 0 to 100.
 *
 * Indicator buffers for iCustom():
 *  • RSI.MODE_MAIN:    RSI main values
 *  • RSI.MODE_SECTION: RSI section and section length since last crossing of level 50
 *    - section: positive values denote a RSI above 50 (+1...+n), negative values a RSI below 50 (-1...-n)
 *    - length:  the absolute value is the histogram section length (bars since the last crossing of level 50)
 */
#include <stddefines.mqh>
int   __InitFlags[];
int __DeinitFlags[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern int    RSI.Periods           = 14;
extern string RSI.AppliedPrice      = "Open | High | Low | Close* | Median | Typical | Weighted";

extern color  MainLine.Color        = Blue;
extern int    MainLine.Width        = 1;

extern color  Histogram.Color.Upper = Blue;
extern color  Histogram.Color.Lower = Red;
extern int    Histogram.Style.Width = 2;

extern int    Max.Bars              = 10000;                // max. values to calculate (-1: all available)

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <rsfLibs.mqh>

#define MODE_MAIN             MACD.MODE_MAIN                // indicator buffer ids
#define MODE_SECTION          MACD.MODE_SECTION
#define MODE_UPPER_SECTION    2
#define MODE_LOWER_SECTION    3

#property indicator_separate_window
#property indicator_buffers   4
#property indicator_level1    0

double bufferRSI    [];                                     // RSI main value:            visible, displayed in "Data" window
double bufferSection[];                                     // RSI section and length:    invisible
double bufferUpper  [];                                     // positive histogram values: visible
double bufferLower  [];                                     // negative histogram values: visible

int rsi.periods;
int rsi.appliedPrice;


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   if (ProgramInitReason() == IR_RECOMPILE) {
      if (!RestoreInputParameters()) return(last_error);
   }

   // (1) validate inputs
   // RSI.Periods
   if (RSI.Periods < 2)           return(catch("onInit(1)  Invalid input parameter RSI.Periods: "+ RSI.Periods, ERR_INVALID_INPUT_PARAMETER));
   rsi.periods = RSI.Periods;

   // RSI.AppliedPrice
   string values[], sValue=StrToLower(RSI.AppliedPrice);
   if (Explode(sValue, "*", values, 2) > 1) {
      int size = Explode(values[0], "|", values, NULL);
      sValue = values[size-1];
   }
   sValue = StrTrim(sValue);
   if (sValue == "") sValue = "close";                               // default price type
   rsi.appliedPrice = StrToPriceType(sValue, F_PARTIAL_ID|F_ERR_INVALID_PARAMETER);
   if (IsEmpty(rsi.appliedPrice) || rsi.appliedPrice > PRICE_WEIGHTED) {
                                  return(catch("onInit(2)  Invalid input parameter RSI.AppliedPrice: "+ DoubleQuoteStr(RSI.AppliedPrice), ERR_INVALID_INPUT_PARAMETER));
   }
   RSI.AppliedPrice = PriceTypeDescription(rsi.appliedPrice);

   // Colors: after deserialization the terminal might turn CLR_NONE (0xFFFFFFFF) into Black (0xFF000000)
   if (MainLine.Color        == 0xFF000000) MainLine.Color        = CLR_NONE;
   if (Histogram.Color.Upper == 0xFF000000) Histogram.Color.Upper = CLR_NONE;
   if (Histogram.Color.Lower == 0xFF000000) Histogram.Color.Lower = CLR_NONE;

   // Styles
   if (MainLine.Width < 0)        return(catch("onInit(3)  Invalid input parameter MainLine.Width: "+ MainLine.Width, ERR_INVALID_INPUT_PARAMETER));
   if (MainLine.Width > 5)        return(catch("onInit(4)  Invalid input parameter MainLine.Width: "+ MainLine.Width, ERR_INVALID_INPUT_PARAMETER));
   if (Histogram.Style.Width < 0) return(catch("onInit(5)  Invalid input parameter Histogram.Style.Width: "+ Histogram.Style.Width, ERR_INVALID_INPUT_PARAMETER));
   if (Histogram.Style.Width > 5) return(catch("onInit(6)  Invalid input parameter Histogram.Style.Width: "+ Histogram.Style.Width, ERR_INVALID_INPUT_PARAMETER));

   // Max.Bars
   if (Max.Bars < -1)             return(catch("onInit(7)  Invalid input parameter Max.Bars: "+ Max.Bars, ERR_INVALID_INPUT_PARAMETER));


   // (2) setup buffer management
   SetIndexBuffer(MODE_MAIN,          bufferRSI    );                // RSI main value:         visible, displayed in "Data" window
   SetIndexBuffer(MODE_SECTION,       bufferSection);                // RSI section and length: invisible
   SetIndexBuffer(MODE_UPPER_SECTION, bufferUpper  );                // positive values:        visible
   SetIndexBuffer(MODE_LOWER_SECTION, bufferLower  );                // negative values:        visible


   // (3) data display configuration, names and labels
   string strAppliedPrice = ifString(rsi.appliedPrice==PRICE_CLOSE, "", ","+ PriceTypeDescription(rsi.appliedPrice));
   string name = "RSI("+ rsi.periods + strAppliedPrice +")";
   IndicatorShortName(name +"  ");                                   // chart subwindow and context menu
   SetIndexLabel(MODE_MAIN,          name);                          // chart tooltips and "Data" window
   SetIndexLabel(MODE_SECTION,       NULL);
   SetIndexLabel(MODE_UPPER_SECTION, NULL);
   SetIndexLabel(MODE_LOWER_SECTION, NULL);
   IndicatorDigits(2);


   // (4) drawing options and styles
   int startDraw = 0;
   if (Max.Bars >= 0) startDraw += Bars - Max.Bars;
   if (startDraw < 0) startDraw  = 0;
   SetIndexDrawBegin(MODE_MAIN,          startDraw);
   SetIndexDrawBegin(MODE_SECTION,       INT_MAX  );                 // work around scaling bug in terminals <=509
   SetIndexDrawBegin(MODE_UPPER_SECTION, startDraw);
   SetIndexDrawBegin(MODE_LOWER_SECTION, startDraw);
   SetIndicatorOptions();
   return(catch("onInit(8)"));
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
   // on the first tick after terminal start buffers may not yet be initialized (spurious issue)
   if (!ArraySize(bufferRSI)) return(logInfo("onTick(1)  size(bufferRSI) = 0", SetLastError(ERS_TERMINAL_NOT_YET_READY)));

   // reset buffers before performing a full recalculation
   if (!ValidBars) {
      ArrayInitialize(bufferRSI,     EMPTY_VALUE);
      ArrayInitialize(bufferSection,           0);
      ArrayInitialize(bufferUpper,   EMPTY_VALUE);
      ArrayInitialize(bufferLower,   EMPTY_VALUE);
      SetIndicatorOptions();
   }

   // synchronize buffers with a shifted offline chart
   if (ShiftedBars > 0) {
      ShiftIndicatorBuffer(bufferRSI,     Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(bufferSection, Bars, ShiftedBars,           0);
      ShiftIndicatorBuffer(bufferUpper,   Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(bufferLower,   Bars, ShiftedBars, EMPTY_VALUE);
   }


   // (1) calculate start bar
   int changedBars = ChangedBars;
   if (Max.Bars >= 0) /*&&*/ if (ChangedBars > Max.Bars)
      changedBars = Max.Bars;
   int startbar = Min(changedBars-1, Bars-rsi.periods);
   if (startbar < 0) return(logInfo("onTick(2)  Tick="+ Tick, ERR_HISTORY_INSUFFICIENT));


   double fast.ma, slow.ma;


   // (2) recalculate changed bars
   for (int bar=startbar; bar >= 0; bar--) {
      // actual RSI
      bufferRSI[bar] = iRSI(NULL, NULL, rsi.periods, rsi.appliedPrice, bar);

      if (bufferRSI[bar] > 50) {
         bufferUpper[bar] = bufferRSI[bar];
         bufferLower[bar] = EMPTY_VALUE;
      }
      else {
         bufferUpper[bar] = EMPTY_VALUE;
         bufferLower[bar] = bufferRSI[bar];
      }

      // update section length (duration)
      if      (bufferSection[bar+1] > 0 && bufferRSI[bar] >= 50) bufferSection[bar] = bufferSection[bar+1] + 1;
      else if (bufferSection[bar+1] < 0 && bufferRSI[bar] <= 50) bufferSection[bar] = bufferSection[bar+1] - 1;
      else                                                       bufferSection[bar] = ifInt(bufferRSI[bar]>=50, +1, -1);
   }
   return(last_error);
}


/**
 * Workaround for various terminal bugs when setting indicator options. Usually options are set in init(). However after
 * recompilation options must be set in start() to not be ignored.
 */
void SetIndicatorOptions() {
   IndicatorBuffers(indicator_buffers);

   int mainType    = ifInt(MainLine.Width,        DRAW_LINE,      DRAW_NONE);
   int sectionType = ifInt(Histogram.Style.Width, DRAW_HISTOGRAM, DRAW_NONE);

   SetIndexStyle(MODE_MAIN,          mainType,    EMPTY, MainLine.Width,        MainLine.Color       );
   SetIndexStyle(MODE_SECTION,       DRAW_NONE,   EMPTY, EMPTY,                 CLR_NONE             );
   SetIndexStyle(MODE_UPPER_SECTION, sectionType, EMPTY, Histogram.Style.Width, Histogram.Color.Upper);
   SetIndexStyle(MODE_LOWER_SECTION, sectionType, EMPTY, Histogram.Style.Width, Histogram.Color.Lower);
}


/**
 * Store input parameters in the chart before recompilation.
 *
 * @return bool - success status
 */
bool StoreInputParameters() {
   string name = ProgramName();
   Chart.StoreInt   (name +".input.RSI.Periods",           RSI.Periods          );
   Chart.StoreString(name +".input.RSI.AppliedPrice",      RSI.AppliedPrice     );
   Chart.StoreColor (name +".input.MainLine.Color",        MainLine.Color       );
   Chart.StoreInt   (name +".input.MainLine.Width",        MainLine.Width       );
   Chart.StoreColor (name +".input.Histogram.Color.Upper", Histogram.Color.Upper);
   Chart.StoreColor (name +".input.Histogram.Color.Lower", Histogram.Color.Lower);
   Chart.StoreInt   (name +".input.Histogram.Style.Width", Histogram.Style.Width);
   Chart.StoreInt   (name +".input.Max.Bars",              Max.Bars             );
   return(!catch("StoreInputParameters(1)"));
}


/**
 * Restore input parameters found in the chart after recompilation.
 *
 * @return bool - success status
 */
bool RestoreInputParameters() {
   string name = ProgramName();
   Chart.RestoreInt   (name +".input.RSI.Periods",           RSI.Periods          );
   Chart.RestoreString(name +".input.RSI.AppliedPrice",      RSI.AppliedPrice     );
   Chart.RestoreColor (name +".input.MainLine.Color",        MainLine.Color       );
   Chart.RestoreInt   (name +".input.MainLine.Width",        MainLine.Width       );
   Chart.RestoreColor (name +".input.Histogram.Color.Upper", Histogram.Color.Upper);
   Chart.RestoreColor (name +".input.Histogram.Color.Lower", Histogram.Color.Lower);
   Chart.RestoreInt   (name +".input.Histogram.Style.Width", Histogram.Style.Width);
   Chart.RestoreInt   (name +".input.Max.Bars",              Max.Bars             );
   return(!catch("RestoreInputParameters(1)"));
}


/**
 * Return a string representation of the input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("RSI.Periods=",           RSI.Periods,                       ";"+ NL,
                            "RSI.AppliedPrice=",      DoubleQuoteStr(RSI.AppliedPrice),  ";"+ NL,
                            "MainLine.Color=",        ColorToStr(MainLine.Color),        ";"+ NL,
                            "MainLine.Width=",        MainLine.Width,                    ";"+ NL,
                            "Histogram.Color.Upper=", ColorToStr(Histogram.Color.Upper), ";"+ NL,
                            "Histogram.Color.Lower=", ColorToStr(Histogram.Color.Lower), ";"+ NL,
                            "Histogram.Style.Width=", Histogram.Style.Width,             ";"+ NL,
                            "Max.Bars=",              Max.Bars,                          ";"+ NL)
   );
}
