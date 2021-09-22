/**
 * Keltner Channel SR
 *
 * A support/resistance line of only rising or only falling values formed by a Keltner channel (an ATR channel around a
 * Moving Average). The SR line changes direction when it's crossed by the Moving Average. ATR values can be smoothed by a
 * second Moving Average.
 *
 * Supported Moving Average types:
 *  • SMA  - Simple Moving Average:          equal bar weighting
 *  • LWMA - Linear Weighted Moving Average: bar weighting using a linear function
 *  • EMA  - Exponential Moving Average:     bar weighting using an exponential function
 *  • SMMA - Smoothed Moving Average:        same as EMA, it holds: SMMA(n) = EMA(2*n-1)
 */
#include <stddefines.mqh>
int   __InitFlags[];
int __DeinitFlags[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern color  Support.Color         = Blue;
extern color  Resistance.Color      = Red;

extern string MA.Method             = "SMA* | LWMA | EMA | SMMA";
extern int    MA.Periods            = 1;                                                           // Nix: 1
extern string MA.AppliedPrice       = "Open* | High | Low | Close | Median | Typical | Weighted";  // Nix: Open
extern color  MA.Color              = CLR_NONE;

extern int    ATR.Periods           = 60;
extern double ATR.Multiplier        =  3;
extern string ATR.Smoothing.Method  = "none | SMA | LWMA | EMA* | SMMA";                           // Nix: EMA
extern int    ATR.Smoothing.Periods = 10;                                                          // Nix: 10
extern color  ATR.Channel.Color     = CLR_NONE;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <rsfLibs.mqh>
#include <functions/@Trend.mqh>

#define MODE_MA               Bands.MODE_MA           // indicator buffer ids
#define MODE_UPPER_BAND       Bands.MODE_UPPER
#define MODE_LOWER_BAND       Bands.MODE_LOWER
#define MODE_LINE_DOWN        3
#define MODE_LINE_DOWNSTART   4
#define MODE_LINE_UP          5
#define MODE_LINE_UPSTART     6
#define MODE_ATR              7

#property indicator_chart_window
#property indicator_buffers   7                       // buffers visible to the user
int       terminal_buffers  = 8;                      // buffers managed by the terminal

#property indicator_color1    CLR_NONE
#property indicator_color2    CLR_NONE
#property indicator_color3    CLR_NONE
#property indicator_color4    CLR_NONE
#property indicator_color5    CLR_NONE
#property indicator_color6    CLR_NONE
#property indicator_color7    CLR_NONE

#property indicator_style1    STYLE_DOT
#property indicator_style2    STYLE_DOT
#property indicator_style3    STYLE_DOT
#property indicator_style4    STYLE_SOLID
#property indicator_style5    STYLE_SOLID
#property indicator_style6    STYLE_DOT
#property indicator_style7    STYLE_DOT

#property indicator_width1    1
#property indicator_width2    1
#property indicator_width3    1
#property indicator_width4    2
#property indicator_width5    2
#property indicator_width6    2
#property indicator_width7    2

double ma           [];
double atr          [];
double upperBand    [];
double lowerBand    [];
double lineUp       [];
double lineUpStart  [];
double lineDown     [];
double lineDownStart[];

int    maMethod;
int    maPeriods;
int    maAppliedPrice;

int    atrPeriods;
double atrMultiplier;
int    atrSmoothingMethod;
int    atrSmoothingPeriods;

string indicatorName = "";
string legendLabel   = "";


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   // validate inputs
   // MA.Method
   string sValues[], sValue = MA.Method;
   if (Explode(sValue, "*", sValues, 2) > 1) {
      int size = Explode(sValues[0], "|", sValues, NULL);
      sValue = sValues[size-1];
   }
   maMethod = StrToMaMethod(sValue, F_ERR_INVALID_PARAMETER);
   if (maMethod == -1)              return(catch("onInit(1)  invalid input parameter MA.Method: "+ DoubleQuoteStr(MA.Method), ERR_INVALID_INPUT_PARAMETER));
   MA.Method = MaMethodDescription(maMethod);
   // MA.Periods
   if (MA.Periods < 0)              return(catch("onInit(2)  invalid input parameter MA.Periods: "+ MA.Periods, ERR_INVALID_INPUT_PARAMETER));
   maPeriods = ifInt(!MA.Periods, 1, MA.Periods);
   if (maPeriods == 1) maMethod = MODE_SMA;
   // MA.AppliedPrice
   sValue = StrToLower(MA.AppliedPrice);
   if (Explode(sValue, "*", sValues, 2) > 1) {
      size = Explode(sValues[0], "|", sValues, NULL);
      sValue = sValues[size-1];
   }
   sValue = StrTrim(sValue);
   if (sValue == "") sValue = "close";                            // default price type
   maAppliedPrice = StrToPriceType(sValue, F_PARTIAL_ID|F_ERR_INVALID_PARAMETER);
   if (maAppliedPrice==-1 || maAppliedPrice > PRICE_WEIGHTED)
                                    return(catch("onInit(3)  invalid input parameter MA.AppliedPrice: "+ DoubleQuoteStr(MA.AppliedPrice), ERR_INVALID_INPUT_PARAMETER));
   MA.AppliedPrice = PriceTypeDescription(maAppliedPrice);

   // ATR.Periods
   if (ATR.Periods < 1)             return(catch("onInit(4)  invalid input parameter ATR.Periods: "+ ATR.Periods, ERR_INVALID_INPUT_PARAMETER));
   atrPeriods = ATR.Periods;
   // ATR.Multiplier
   if (ATR.Multiplier < 0)          return(catch("onInit(5)  invalid input parameter ATR.Multiplier: "+ NumberToStr(ATR.Multiplier, ".+"), ERR_INVALID_INPUT_PARAMETER));
   atrMultiplier = ATR.Multiplier;
   // ATR.Smoothing.Method
   sValue = ATR.Smoothing.Method;
   if (Explode(sValue, "*", sValues, 2) > 1) {
      size = Explode(sValues[0], "|", sValues, NULL);
      sValue = sValues[size-1];
   }
   sValue= StrTrim(sValue);
   if (!StringLen(sValue) || StrCompareI(sValue, "none")) {
      atrSmoothingMethod = EMPTY;
      ATR.Smoothing.Method = "none";
   }
   else {
      atrSmoothingMethod = StrToMaMethod(sValue, F_ERR_INVALID_PARAMETER);
      if (atrSmoothingMethod == -1) return(catch("onInit(6)  invalid input parameter ATR.Smoothing.Method: "+ DoubleQuoteStr(ATR.Smoothing.Method), ERR_INVALID_INPUT_PARAMETER));
      ATR.Smoothing.Method = MaMethodDescription(atrSmoothingMethod);
   }
   // ATR.Smoothing.Periods
   if (ATR.Smoothing.Periods < 0)   return(catch("onInit(7)  invalid input parameter ATR.Smoothing.Periods: "+ ATR.Smoothing.Periods, ERR_INVALID_INPUT_PARAMETER));
   atrSmoothingPeriods = ifInt(atrSmoothingMethod==EMPTY || !ATR.Smoothing.Periods, 1, ATR.Smoothing.Periods);
   if (atrSmoothingPeriods == 1) atrSmoothingMethod = MODE_SMA;

   // colors: after deserialization the terminal might turn CLR_NONE (0xFFFFFFFF) into Black (0xFF000000)
   if (Support.Color     == 0xFF000000) Support.Color     = CLR_NONE;
   if (Resistance.Color  == 0xFF000000) Resistance.Color  = CLR_NONE;
   if (MA.Color          == 0xFF000000) MA.Color          = CLR_NONE;
   if (ATR.Channel.Color == 0xFF000000) ATR.Channel.Color = CLR_NONE;

   // buffer management
   SetIndexBuffer(MODE_MA,             ma           ); SetIndexEmptyValue(MODE_MA,             0);
   SetIndexBuffer(MODE_ATR,            atr          );                                                // invisible
   SetIndexBuffer(MODE_UPPER_BAND,     upperBand    ); SetIndexEmptyValue(MODE_UPPER_BAND,     0);
   SetIndexBuffer(MODE_LOWER_BAND,     lowerBand    ); SetIndexEmptyValue(MODE_LOWER_BAND,     0);
   SetIndexBuffer(MODE_LINE_UP,        lineUp       ); SetIndexEmptyValue(MODE_LINE_UP,        0);
   SetIndexBuffer(MODE_LINE_UPSTART,   lineUpStart  ); SetIndexEmptyValue(MODE_LINE_UPSTART,   0);
   SetIndexBuffer(MODE_LINE_DOWN,      lineDown     ); SetIndexEmptyValue(MODE_LINE_DOWN,      0);
   SetIndexBuffer(MODE_LINE_DOWNSTART, lineDownStart); SetIndexEmptyValue(MODE_LINE_DOWNSTART, 0);

   // chart legend
   if (!IsSuperContext()) {
       legendLabel = CreateLegendLabel();
       RegisterObject(legendLabel);
   }

   // names, labels and display options
   indicatorName = WindowExpertName();
   IndicatorShortName(indicatorName);                                                                                               // chart tooltips and context menu
   SetIndexLabel(MODE_MA,         "KCh MA"   );      if (MA.Color          == CLR_NONE) SetIndexLabel(MODE_MA,             NULL);   // chart tooltips and "Data" window
   SetIndexLabel(MODE_UPPER_BAND, "KCh Upper");      if (ATR.Channel.Color == CLR_NONE) SetIndexLabel(MODE_UPPER_BAND,     NULL);
   SetIndexLabel(MODE_LOWER_BAND, "KCh Lower");      if (ATR.Channel.Color == CLR_NONE) SetIndexLabel(MODE_LOWER_BAND,     NULL);
   SetIndexLabel(MODE_LINE_UP,    "KCh Support");    if (Support.Color     == CLR_NONE) SetIndexLabel(MODE_LINE_UP,        NULL);
                                                                                        SetIndexLabel(MODE_LINE_UPSTART,   NULL);
   SetIndexLabel(MODE_LINE_DOWN,  "KCh Resistance"); if (Resistance.Color  == CLR_NONE) SetIndexLabel(MODE_LINE_DOWN,      NULL);
                                                                                        SetIndexLabel(MODE_LINE_DOWNSTART, NULL);
   IndicatorDigits(Digits);
   SetIndicatorOptions();

   return(catch("onInit(4)"));
}


/**
 * Deinitialization
 *
 * @return int - error status
 */
int onDeinit() {
   RepositionLegend();
   return(catch("onDeinit(1)"));
}


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   // on the first tick after terminal start buffers may not yet be initialized (spurious issue)
   if (!ArraySize(ma)) return(logInfo("onTick(1)  size(ma) = 0", SetLastError(ERS_TERMINAL_NOT_YET_READY)));

   // reset buffers before performing a full recalculation
   if (!UnchangedBars) {
      ArrayInitialize(ma,            0);
      ArrayInitialize(atr,           0);
      ArrayInitialize(upperBand,     0);
      ArrayInitialize(lowerBand,     0);
      ArrayInitialize(lineUp,        0);
      ArrayInitialize(lineUpStart,   0);
      ArrayInitialize(lineDown,      0);
      ArrayInitialize(lineDownStart, 0);
      SetIndicatorOptions();
   }

   // synchronize buffers with a shifted offline chart
   if (ShiftedBars > 0) {
      ShiftIndicatorBuffer(ma,            Bars, ShiftedBars, 0);
      ShiftIndicatorBuffer(atr,           Bars, ShiftedBars, 0);
      ShiftIndicatorBuffer(upperBand,     Bars, ShiftedBars, 0);
      ShiftIndicatorBuffer(lowerBand,     Bars, ShiftedBars, 0);
      ShiftIndicatorBuffer(lineUp,        Bars, ShiftedBars, 0);
      ShiftIndicatorBuffer(lineUpStart,   Bars, ShiftedBars, 0);
      ShiftIndicatorBuffer(lineDown,      Bars, ShiftedBars, 0);
      ShiftIndicatorBuffer(lineDownStart, Bars, ShiftedBars, 0);
   }

   // recalculate changed MA values
   int initBars = maPeriods-1;
   if (maMethod==MODE_EMA || maMethod==MODE_SMMA)
      initBars = Max(10, maPeriods*3);                // IIR filters need at least 10 bars for initialization
   int maBars = Bars-initBars;
   int maStartbar = Min(ChangedBars, maBars) - 1;

   for (int bar=maStartbar; bar >= 0; bar--) {
      ma[bar] = iMA(NULL, NULL, maPeriods, 0, maMethod, maAppliedPrice, bar);
   }

   // recalculate changed ATR values
   initBars = atrPeriods-1;
   int atrBars = Bars-initBars;
   int atrStartbar = Min(ChangedBars, atrBars) - 1;

   for (bar=atrStartbar; bar >= 0; bar--) {
      atr[bar] = iATR(NULL, NULL, atrPeriods, bar);
   }

   // recalculate changed ATR channel values
   initBars = atrSmoothingPeriods-1;
   if (atrSmoothingMethod==MODE_EMA || atrSmoothingMethod==MODE_SMMA)
      initBars = Max(10, atrSmoothingPeriods*3);      // IIR filters need at least 10 bars for initialization
   int channelBars = Min(maBars, atrBars)-initBars;
   int channelStartbar = Min(ChangedBars, channelBars) - 1;

   for (bar=channelStartbar; bar >= 0; bar--) {
      double channelWidth = atrMultiplier * iMAOnArray(atr, WHOLE_ARRAY, atrSmoothingPeriods, 0, atrSmoothingMethod, bar);
      upperBand[bar] = ma[bar] + channelWidth;
      lowerBand[bar] = ma[bar] - channelWidth;
   }

   // recalculate changed SR values
   initBars = 1;                                      // 1 bar for comparison with the previous value
   int srBars = Min(maBars, channelBars)-initBars;
   int srStartbar = Min(ChangedBars, srBars) - 1;
   if (srStartbar < 0) return(logInfo("onTick(2)  Tick="+ Tick, ERR_HISTORY_INSUFFICIENT));

   double prevSR = lineUp[srStartbar+1] + lineDown[srStartbar+1];
   if (!prevSR) prevSR = ma[srStartbar+1];

   for (bar=srStartbar; bar >= 0; bar--) {
      if (ma[bar+1] < prevSR) {
         if (ma[bar] < prevSR) {
            lineUp  [bar] = 0;
            lineDown[bar] = MathMin(prevSR, upperBand[bar]);
         }
         else {
            lineUp  [bar] = lowerBand[bar]; lineUpStart[bar] = lineUp[bar];
            lineDown[bar] = 0;
         }
      }
      else /*ma[bar+1] > prevSR*/{
         if (ma[bar] > prevSR) {
            lineUp  [bar] = MathMax(prevSR, lowerBand[bar]);
            lineDown[bar] = 0;
         }
         else {
            lineUp  [bar] = 0;
            lineDown[bar] = upperBand[bar]; lineDownStart[bar] = lineDown[bar];
         }
      }
      prevSR = lineUp[bar] + lineDown[bar];
   }

   if (!IsSuperContext()) {
      color trendColor = ifInt(lineUp[0]!=0, Support.Color, Resistance.Color);
      @Trend.UpdateLegend(legendLabel, indicatorName, "", trendColor, trendColor, prevSR, Digits, NULL, Time[0]);
   }
   return(last_error);
}


/**
 * Workaround for various terminal bugs when setting indicator options. Usually options are set in init(). However after
 * recompilation options must be set in start() to not be ignored.
 */
void SetIndicatorOptions() {
   IndicatorBuffers(terminal_buffers);

   int drawType = ifInt(MA.Color==CLR_NONE, DRAW_NONE, DRAW_LINE);
   SetIndexStyle(MODE_MA, drawType, EMPTY, EMPTY, MA.Color);

   drawType = ifInt(ATR.Channel.Color==CLR_NONE, DRAW_NONE, DRAW_LINE);
   SetIndexStyle(MODE_UPPER_BAND, drawType, EMPTY, EMPTY, ATR.Channel.Color);
   SetIndexStyle(MODE_LOWER_BAND, drawType, EMPTY, EMPTY, ATR.Channel.Color);

   if (Support.Color == CLR_NONE) {
      SetIndexStyle(MODE_LINE_UP,      DRAW_NONE);
      SetIndexStyle(MODE_LINE_UPSTART, DRAW_NONE);
   }
   else {
      SetIndexStyle(MODE_LINE_UP,      DRAW_LINE,  EMPTY, EMPTY, Support.Color);
      SetIndexStyle(MODE_LINE_UPSTART, DRAW_ARROW, EMPTY, EMPTY, Support.Color); SetIndexArrow(MODE_LINE_UPSTART, 159);
   }

   if (Resistance.Color == CLR_NONE) {
      SetIndexStyle(MODE_LINE_DOWN,      DRAW_NONE);
      SetIndexStyle(MODE_LINE_DOWNSTART, DRAW_NONE);
   }
   else {
      SetIndexStyle(MODE_LINE_DOWN,      DRAW_LINE,  EMPTY, EMPTY, Resistance.Color);
      SetIndexStyle(MODE_LINE_DOWNSTART, DRAW_ARROW, EMPTY, EMPTY, Resistance.Color); SetIndexArrow(MODE_LINE_DOWNSTART, 159);
   }
}


/**
 * Return a string representation of the input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("Support.Color=",         ColorToStr(Support.Color),            ";", NL,
                            "Resistance.Color=",      ColorToStr(Resistance.Color),         ";", NL,
                            "MA.Method=",             DoubleQuoteStr(MA.Method),            ";", NL,
                            "MA.Periods=",            MA.Periods,                           ";", NL,
                            "MA.AppliedPrice=",       DoubleQuoteStr(MA.AppliedPrice),      ";", NL,
                            "MA.Color=",              ColorToStr(MA.Color),                 ";", NL,
                            "ATR.Smoothing.Method=",  DoubleQuoteStr(ATR.Smoothing.Method), ";", NL,
                            "ATR.Smoothing.Periods=", ATR.Smoothing.Periods,                ";", NL,
                            "ATR.Channel.Color=",     ColorToStr(ATR.Channel.Color),        ";")
   );
}
