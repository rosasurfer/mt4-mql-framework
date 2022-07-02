/**
 * Trix - Slope of Triple Smoothed Exponential Moving Average
 *
 *
 * The Trix calculates the 1-period percent change (aka rate of change) of a triple smoothed EMA (TriEMA).
 * The display unit is "base points" (1 bps = 1/100th %).
 *
 * Example:
 *  Trix[0] = TriEMA[0]/TriEMA[1] * 100 * 100
 *
 * Indicator buffers for iCustom():
 *  • Slope.MODE_MAIN:   Trix main value
 *  • Slope.MODE_TREND:  trend direction and length
 *    - trend direction: positive values denote an uptrend (+1...+n), negative values a downtrend (-1...-n)
 *    - trend length:    the absolute direction value is the length of the trend in bars since the last reversal
 *
 * To detect a crossing of the zero line use MovingAverage.MODE_TREND of the underlying TriEMA.
 */
#include <stddefines.mqh>
int   __InitFlags[];
int __DeinitFlags[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern int    EMA.Periods           = 38;
extern string EMA.AppliedPrice      = "Open | High | Low | Close* | Median | Typical | Weighted";

extern color  MainLine.Color        = DodgerBlue;
extern int    MainLine.Width        = 1;

extern color  Histogram.Color.Upper = LimeGreen;
extern color  Histogram.Color.Lower = Red;
extern int    Histogram.Style.Width = 2;

extern int    Max.Bars              = 10000;                // max. values to calculate (-1: all available)

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <rsfLib.mqh>
#include <functions/@Trend.mqh>

#property indicator_separate_window
#property indicator_buffers   4                             // buffers visible to the user
int       terminal_buffers  = 7;                            // buffers managed by the terminal

#property indicator_width1    1
#property indicator_width2    0
#property indicator_width3    2
#property indicator_width4    2

#property indicator_level1    0

#define MODE_MAIN             Slope.MODE_MAIN               // indicator buffer ids
#define MODE_TREND            Slope.MODE_TREND
#define MODE_UPPER_SECTION    2
#define MODE_LOWER_SECTION    3
#define MODE_EMA_1            4
#define MODE_EMA_2            5
#define MODE_EMA_3            6

double trixMain [];                                         // Trix main line:                 visible, "Data" window
double trixTrend[];                                         // trend direction and length:     invisible
double trixUpper[];                                         // positive histogram values:      visible
double trixLower[];                                         // negative histogram values:      visible
double firstEma [];                                         // first intermediate EMA buffer:  invisible
double secondEma[];                                         // second intermediate EMA buffer: invisible
double thirdEma [];                                         // third intermediate EMA buffer:  invisible

int ema.appliedPrice;


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   // (1) validate inputs
   // EMA.Periods
   if (EMA.Periods < 1)           return(catch("onInit(1)  invalid input parameter EMA.Periods: "+ EMA.Periods, ERR_INVALID_INPUT_PARAMETER));

   // EMA.AppliedPrice
   string values[], sValue = StrToLower(EMA.AppliedPrice);
   if (Explode(sValue, "*", values, 2) > 1) {
      int size = Explode(values[0], "|", values, NULL);
      sValue = values[size-1];
   }
   sValue = StrTrim(sValue);
   if (sValue == "") sValue = "close";                                           // default price type
   ema.appliedPrice = StrToPriceType(sValue, F_PARTIAL_ID|F_ERR_INVALID_PARAMETER);
   if (ema.appliedPrice==-1 || ema.appliedPrice > PRICE_WEIGHTED)
                                  return(catch("onInit(2)  invalid input parameter EMA.AppliedPrice: "+ DoubleQuoteStr(EMA.AppliedPrice), ERR_INVALID_INPUT_PARAMETER));
   EMA.AppliedPrice = PriceTypeDescription(ema.appliedPrice);

   // Colors: after deserialization the terminal might turn CLR_NONE (0xFFFFFFFF) into Black (0xFF000000)
   if (MainLine.Color        == 0xFF000000) MainLine.Color        = CLR_NONE;
   if (Histogram.Color.Upper == 0xFF000000) Histogram.Color.Upper = CLR_NONE;
   if (Histogram.Color.Lower == 0xFF000000) Histogram.Color.Lower = CLR_NONE;

   // Styles
   if (MainLine.Width < 0)        return(catch("onInit(3)  invalid input parameter MainLine.Width: "+ MainLine.Width, ERR_INVALID_INPUT_PARAMETER));
   if (Histogram.Style.Width < 0) return(catch("onInit(4)  invalid input parameter Histogram.Style.Width: "+ Histogram.Style.Width, ERR_INVALID_INPUT_PARAMETER));
   if (Histogram.Style.Width > 5) return(catch("onInit(5)  invalid input parameter Histogram.Style.Width: "+ Histogram.Style.Width, ERR_INVALID_INPUT_PARAMETER));

   // Max.Bars
   if (Max.Bars < -1)             return(catch("onInit(6)  invalid input parameter Max.Bars: "+ Max.Bars, ERR_INVALID_INPUT_PARAMETER));


   // (2) setup buffer management
   SetIndexBuffer(MODE_EMA_1,         firstEma );
   SetIndexBuffer(MODE_EMA_2,         secondEma);
   SetIndexBuffer(MODE_EMA_3,         thirdEma );
   SetIndexBuffer(MODE_MAIN,          trixMain );
   SetIndexBuffer(MODE_UPPER_SECTION, trixUpper);
   SetIndexBuffer(MODE_LOWER_SECTION, trixLower);
   SetIndexBuffer(MODE_TREND,         trixTrend);


   // (3) data display configuration and names
   string sAppliedPrice = ""; if (ema.appliedPrice != PRICE_CLOSE) sAppliedPrice = ", "+ PriceTypeDescription(ema.appliedPrice);
   string shortName = "Trix("+ EMA.Periods + sAppliedPrice +")";
   string dataName = "Trix("+ EMA.Periods +")";
   IndicatorShortName(shortName +"  ");                           // chart subwindow and context menus
   SetIndexLabel(MODE_EMA_1,         NULL    );
   SetIndexLabel(MODE_EMA_2,         NULL    );
   SetIndexLabel(MODE_EMA_3,         NULL    );
   SetIndexLabel(MODE_MAIN,          dataName);                   // chart tooltips and "Data" window
   SetIndexLabel(MODE_UPPER_SECTION, NULL    );
   SetIndexLabel(MODE_LOWER_SECTION, NULL    );
   SetIndexLabel(MODE_TREND,         NULL    );
   IndicatorDigits(3);


   // (4) drawing options and styles
   int startDraw = 0;
   if (Max.Bars >= 0) startDraw += Bars - Max.Bars;
   if (startDraw < 0) startDraw  = 0;
   SetIndexDrawBegin(MODE_MAIN,          startDraw);
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
   if (!ArraySize(trixMain)) return(logInfo("onTick(1)  sizeof(trixMain) = 0", SetLastError(ERS_TERMINAL_NOT_YET_READY)));

   // reset buffers before performing a full recalculation
   if (!ValidBars) {
      ArrayInitialize(firstEma,  EMPTY_VALUE);
      ArrayInitialize(secondEma, EMPTY_VALUE);
      ArrayInitialize(thirdEma,  EMPTY_VALUE);
      ArrayInitialize(trixMain,  EMPTY_VALUE);
      ArrayInitialize(trixUpper, EMPTY_VALUE);
      ArrayInitialize(trixLower, EMPTY_VALUE);
      ArrayInitialize(trixTrend,           0);
      SetIndicatorOptions();
   }

   // synchronize buffers with a shifted offline chart
   if (ShiftedBars > 0) {
      ShiftDoubleIndicatorBuffer(firstEma,  Bars, ShiftedBars, EMPTY_VALUE);
      ShiftDoubleIndicatorBuffer(secondEma, Bars, ShiftedBars, EMPTY_VALUE);
      ShiftDoubleIndicatorBuffer(thirdEma,  Bars, ShiftedBars, EMPTY_VALUE);
      ShiftDoubleIndicatorBuffer(trixMain,  Bars, ShiftedBars, EMPTY_VALUE);
      ShiftDoubleIndicatorBuffer(trixUpper, Bars, ShiftedBars, EMPTY_VALUE);
      ShiftDoubleIndicatorBuffer(trixLower, Bars, ShiftedBars, EMPTY_VALUE);
      ShiftDoubleIndicatorBuffer(trixTrend, Bars, ShiftedBars,           0);
   }


   // (1) calculate start bar
   int changedBars = ChangedBars;
   if (Max.Bars >= 0) /*&&*/ if (Max.Bars < ChangedBars)             // Because EMA(EMA(EMA)) is used in the calculation, TriEMA needs
      changedBars = Max.Bars;                                        // 3*<period>-2 samples to start producing values in contrast to
   int bar, startbar = Min(changedBars-1, Bars - (3*EMA.Periods-2)); // <period> samples needed by a regular EMA.
   if (startbar < 0) return(logInfo("onTick(2)  Tick="+ Ticks, ERR_HISTORY_INSUFFICIENT));


   // (2) recalculate changed bars
   double dNull[];
   for (bar=ChangedBars-1; bar >= 0; bar--) firstEma [bar] =        iMA(NULL,      NULL,        EMA.Periods, 0, MODE_EMA, ema.appliedPrice, bar);
   for (bar=ChangedBars-1; bar >= 0; bar--) secondEma[bar] = iMAOnArray(firstEma,  WHOLE_ARRAY, EMA.Periods, 0, MODE_EMA,                   bar);
   for (bar=ChangedBars-1; bar >= 0; bar--) thirdEma [bar] = iMAOnArray(secondEma, WHOLE_ARRAY, EMA.Periods, 0, MODE_EMA,                   bar);

   for (bar=startbar; bar >= 0; bar--) {
      if (!thirdEma[bar+1]) {
         debug("onTick(0."+ Ticks +")  thirdEma["+ (bar+1) +"]=NULL  ShiftedBars="+ ShiftedBars +"  ChangedBars="+ ChangedBars +"  startbar="+ startbar);
         continue;
      }
      // Trix main value
      trixMain[bar] = (thirdEma[bar] - thirdEma[bar+1]) / thirdEma[bar+1] * 10000;              // convert to bps

      // histogram sections
      if (trixMain[bar] > 0) { trixUpper[bar] = trixMain[bar]; trixLower[bar] = EMPTY_VALUE;   }
      else                   { trixUpper[bar] = EMPTY_VALUE;   trixLower[bar] = trixMain[bar]; }

      // trend direction and length
      @Trend.UpdateDirection(trixMain, bar, trixTrend, dNull, dNull, dNull);
   }
   return(last_error);
}


/**
 * Workaround for various terminal bugs when setting indicator options. Usually options are set in init(). However after
 * recompilation options must be set in start() to not be ignored.
 */
void SetIndicatorOptions() {
   IndicatorBuffers(terminal_buffers);

   int mainType    = ifInt(MainLine.Width,        DRAW_LINE,      DRAW_NONE);
   int sectionType = ifInt(Histogram.Style.Width, DRAW_HISTOGRAM, DRAW_NONE);

   SetIndexStyle(MODE_MAIN,          mainType,    EMPTY, MainLine.Width,        MainLine.Color       );
   SetIndexStyle(MODE_UPPER_SECTION, sectionType, EMPTY, Histogram.Style.Width, Histogram.Color.Upper);
   SetIndexStyle(MODE_LOWER_SECTION, sectionType, EMPTY, Histogram.Style.Width, Histogram.Color.Lower);
   SetIndexStyle(MODE_TREND,         DRAW_NONE,   EMPTY, EMPTY,                 CLR_NONE             );
}


/**
 * Return a string representation of the input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("EMA.Periods=",           EMA.Periods,                       ";", NL,
                            "EMA.AppliedPrice=",      DoubleQuoteStr(EMA.AppliedPrice),  ";", NL,
                            "MainLine.Color=",        ColorToStr(MainLine.Color),        ";", NL,
                            "MainLine.Width=",        MainLine.Width,                    ";", NL,
                            "Histogram.Color.Upper=", ColorToStr(Histogram.Color.Upper), ";", NL,
                            "Histogram.Color.Lower=", ColorToStr(Histogram.Color.Lower), ";", NL,
                            "Histogram.Style.Width=", Histogram.Style.Width,             ";", NL,
                            "Max.Bars=",              Max.Bars,                          ";")
   );
}
