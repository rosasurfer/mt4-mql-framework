/**
 * RSI (Relative Strength Index) - an implementation supporting the display as histogram
 *
 *
 * The RSI (Relative Strength Index) is the EMA-smoothed ratio of gains to losses during a lookback period, again normalized
 * to a value from 0 to 100.
 *
 * Indicator buffers for iCustom():
 *  � RSI.MODE_MAIN:    RSI main values
 *  � RSI.MODE_SECTION: RSI section and section length since last crossing of level 50
 *    - section: positive values denote a RSI above 50 (+1...+n), negative values a RSI below 50 (-1...-n)
 *    - length:  the absolute value is the histogram section length (bars since the last crossing of level 50)
 */
#include <rsf/stddefines.mqh>
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

extern int    MaxBarsBack           = 10000;          // max. values to calculate (-1: all available)

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <rsf/core/indicator.mqh>
#include <rsf/stdfunctions.mqh>
#include <rsf/stdlib.mqh>

#define MODE_MAIN             0                       // indicator buffer ids
#define MODE_SECTION          1
#define MODE_UPPER_SECTION    2
#define MODE_LOWER_SECTION    3

#property indicator_separate_window
#property indicator_buffers   4
#property indicator_level1    0

double bufferRSI    [];                               // RSI main value:            visible, displayed in "Data" window
double bufferSection[];                               // RSI section and length:    invisible
double bufferUpper  [];                               // positive histogram values: visible
double bufferLower  [];                               // negative histogram values: visible

int rsi.periods;
int rsi.appliedPrice;


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   // (1) validate inputs
   // RSI.Periods
   if (RSI.Periods < 2)           return(catch("onInit(1)  invalid input parameter RSI.Periods: "+ RSI.Periods, ERR_INVALID_INPUT_PARAMETER));
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
   if (rsi.appliedPrice == -1)    return(catch("onInit(2)  invalid input parameter RSI.AppliedPrice: "+ DoubleQuoteStr(RSI.AppliedPrice), ERR_INVALID_INPUT_PARAMETER));
   RSI.AppliedPrice = PriceTypeDescription(rsi.appliedPrice);

   // Colors: after deserialization the terminal might turn CLR_NONE (0xFFFFFFFF) into Black (0xFF000000)
   if (MainLine.Color        == 0xFF000000) MainLine.Color        = CLR_NONE;
   if (Histogram.Color.Upper == 0xFF000000) Histogram.Color.Upper = CLR_NONE;
   if (Histogram.Color.Lower == 0xFF000000) Histogram.Color.Lower = CLR_NONE;

   // Styles
   if (MainLine.Width < 0)        return(catch("onInit(3)  invalid input parameter MainLine.Width: "+ MainLine.Width, ERR_INVALID_INPUT_PARAMETER));
   if (Histogram.Style.Width < 0) return(catch("onInit(4)  invalid input parameter Histogram.Style.Width: "+ Histogram.Style.Width, ERR_INVALID_INPUT_PARAMETER));
   if (Histogram.Style.Width > 5) return(catch("onInit(5)  invalid input parameter Histogram.Style.Width: "+ Histogram.Style.Width, ERR_INVALID_INPUT_PARAMETER));

   // MaxBarsBack
   if (MaxBarsBack < -1)          return(catch("onInit(6)  invalid input parameter MaxBarsBack: "+ MaxBarsBack, ERR_INVALID_INPUT_PARAMETER));
   if (MaxBarsBack == -1) MaxBarsBack = INT_MAX;


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
   int startDraw = Bars - MaxBarsBack;
   SetIndexDrawBegin(MODE_MAIN,          startDraw);
   SetIndexDrawBegin(MODE_SECTION,       INT_MAX  );                 // work around scaling bug in terminal builds <= 509
   SetIndexDrawBegin(MODE_UPPER_SECTION, startDraw);
   SetIndexDrawBegin(MODE_LOWER_SECTION, startDraw);
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
   if (!ArraySize(bufferRSI)) return(logInfo("onTick(1)  sizeof(bufferRSI) = 0", SetLastError(ERS_TERMINAL_NOT_YET_READY)));

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
      ShiftDoubleIndicatorBuffer(bufferRSI,     Bars, ShiftedBars, EMPTY_VALUE);
      ShiftDoubleIndicatorBuffer(bufferSection, Bars, ShiftedBars,           0);
      ShiftDoubleIndicatorBuffer(bufferUpper,   Bars, ShiftedBars, EMPTY_VALUE);
      ShiftDoubleIndicatorBuffer(bufferLower,   Bars, ShiftedBars, EMPTY_VALUE);
   }


   // (1) calculate start bar
   int startbar = Min(MaxBarsBack-1, ChangedBars-1, Bars-rsi.periods);
   if (startbar < 0 && MaxBarsBack) return(logInfo("onTick(2)  Tick="+ Ticks, ERR_HISTORY_INSUFFICIENT));

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
 * Set indicator options. After recompilation the function must be called from start() for options not to be ignored.
 *
 * @param  bool redraw [optional] - whether to redraw the chart (default: no)
 *
 * @return bool - success status
 */
bool SetIndicatorOptions(bool redraw = false) {
   redraw = redraw!=0;
   IndicatorBuffers(indicator_buffers);

   int mainType    = ifInt(MainLine.Width,        DRAW_LINE,      DRAW_NONE);
   int sectionType = ifInt(Histogram.Style.Width, DRAW_HISTOGRAM, DRAW_NONE);

   SetIndexStyle(MODE_MAIN,          mainType,    EMPTY, MainLine.Width,        MainLine.Color       );
   SetIndexStyle(MODE_SECTION,       DRAW_NONE,   EMPTY, EMPTY,                 CLR_NONE             );
   SetIndexStyle(MODE_UPPER_SECTION, sectionType, EMPTY, Histogram.Style.Width, Histogram.Color.Upper);
   SetIndexStyle(MODE_LOWER_SECTION, sectionType, EMPTY, Histogram.Style.Width, Histogram.Color.Lower);

   if (redraw) WindowRedraw();
   return(!catch("SetIndicatorOptions(1)"));
}


/**
 * Return a string representation of all input parameters (for logging purposes).
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
                            "MaxBarsBack=",           MaxBarsBack,                       ";"+ NL)
   );
}
