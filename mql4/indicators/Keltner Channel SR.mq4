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
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern string MA.Method       = "SMA* | LWMA | EMA | SMMA";
extern int    MA.Periods      = 10;
extern string MA.AppliedPrice = "Open | High | Low | Close* | Median | Typical | Weighted";
extern color  MA.Color        = CLR_NONE;

extern int    ATR.Periods     = 60;
extern double ATR.Multiplier  =  3;

       int    MA2.Method      = MODE_EMA;
extern int    MA2.Periods     = 10;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <rsfLibs.mqh>

#define MODE_MA               Bands.MODE_MA           // indicator buffer ids
#define MODE_UPPER_BAND       Bands.MODE_UPPER
#define MODE_LOWER_BAND       Bands.MODE_LOWER
#define MODE_LINE_DOWN        3
#define MODE_LINE_DOWNSTART   4
#define MODE_LINE_UP          5
#define MODE_LINE_UPSTART     6
#define MODE_ATR              7

#property indicator_chart_window
#property indicator_buffers   7                       // buffers visible in input dialog
int       terminal_buffers  = 8;                      // buffers managed by the terminal

#property indicator_color1    CLR_NONE
#property indicator_color2    CLR_NONE
#property indicator_color3    CLR_NONE
#property indicator_color4    Red
#property indicator_color5    Red
#property indicator_color6    Blue
#property indicator_color7    Blue

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

int    ma1Method;
int    ma1Periods;
int    ma1AppliedPrice;

int    atrPeriods;
double atrMultiplier;

int    ma2Method;
int    ma2Periods;


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
   sValue = StrTrim(sValue);
   ma1Method = StrToMaMethod(sValue, F_ERR_INVALID_PARAMETER);
   if (ma1Method == -1) return(catch("onInit(1)  Invalid input parameter MA.Method: "+ DoubleQuoteStr(MA.Method), ERR_INVALID_INPUT_PARAMETER));
   MA.Method = MaMethodDescription(ma1Method);
   // MA.Periods
   if (MA.Periods < 0)  return(catch("onInit(2)  Invalid input parameter MA.Periods: "+ MA.Periods, ERR_INVALID_INPUT_PARAMETER));
   ma1Periods = ifInt(!MA.Periods, 1, MA.Periods);
   // MA.AppliedPrice
   sValue = StrToLower(MA.AppliedPrice);
   if (Explode(sValue, "*", sValues, 2) > 1) {
      size = Explode(sValues[0], "|", sValues, NULL);
      sValue = sValues[size-1];
   }
   sValue = StrTrim(sValue);
   if (sValue == "") sValue = "close";                            // default price type
   ma1AppliedPrice = StrToPriceType(sValue, F_PARTIAL_ID|F_ERR_INVALID_PARAMETER);
   if (ma1AppliedPrice==-1 || ma1AppliedPrice > PRICE_WEIGHTED)
                        return(catch("onInit(3)  Invalid input parameter MA.AppliedPrice: "+ DoubleQuoteStr(MA.AppliedPrice), ERR_INVALID_INPUT_PARAMETER));
   MA.AppliedPrice = PriceTypeDescription(ma1AppliedPrice);





   SetIndexBuffer(MODE_MA,             ma           ); SetIndexEmptyValue(MODE_MA,             0); SetIndexLabel(MODE_MA,             NULL);
   SetIndexBuffer(MODE_ATR,            atr          ); SetIndexEmptyValue(MODE_ATR,            0); SetIndexLabel(MODE_ATR,            NULL);
   SetIndexBuffer(MODE_UPPER_BAND,     upperBand    ); SetIndexEmptyValue(MODE_UPPER_BAND,     0); SetIndexLabel(MODE_UPPER_BAND,     NULL);
   SetIndexBuffer(MODE_LOWER_BAND,     lowerBand    ); SetIndexEmptyValue(MODE_LOWER_BAND,     0); SetIndexLabel(MODE_LOWER_BAND,     NULL);
   SetIndexBuffer(MODE_LINE_UP,        lineUp       ); SetIndexEmptyValue(MODE_LINE_UP,        0); SetIndexLabel(MODE_LINE_UP,        "KCh Support");
   SetIndexBuffer(MODE_LINE_UPSTART,   lineUpStart  ); SetIndexEmptyValue(MODE_LINE_UPSTART,   0); SetIndexLabel(MODE_LINE_UPSTART,   NULL); SetIndexStyle(MODE_LINE_UPSTART,   DRAW_ARROW, EMPTY); SetIndexArrow(MODE_LINE_UPSTART,   159);
   SetIndexBuffer(MODE_LINE_DOWN,      lineDown     ); SetIndexEmptyValue(MODE_LINE_DOWN,      0); SetIndexLabel(MODE_LINE_DOWN,      "KCh Resistance");
   SetIndexBuffer(MODE_LINE_DOWNSTART, lineDownStart); SetIndexEmptyValue(MODE_LINE_DOWNSTART, 0); SetIndexLabel(MODE_LINE_DOWNSTART, NULL); SetIndexStyle(MODE_LINE_DOWNSTART, DRAW_ARROW, EMPTY); SetIndexArrow(MODE_LINE_DOWNSTART, 159);

   IndicatorShortName(WindowExpertName());
   IndicatorDigits(Digits);
   SetIndicatorOptions();

   return(catch("onInit(4)"));
}


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   // under undefined conditions on the first tick after terminal start buffers may not yet be initialized
   if (!ArraySize(ma)) return(log("onTick(1)  size(ma) = 0", SetLastError(ERS_TERMINAL_NOT_YET_READY)));

   // reset all buffers and delete garbage before doing a full recalculation
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


   // calculate ATR start bar
   int initBars = ATR.Periods;
   int bars     = Bars-initBars+1;
   int startBar = Min(ChangedBars, bars) - 1;
   if (startBar < 0) return(catch("onTick(2)", ERR_HISTORY_INSUFFICIENT));

   // recalculate changed ATR values
   for (int bar=startBar; bar >= 0; bar--) {
      ma [bar] = iMA(NULL, NULL, ma1Periods, 0, ma1Method, ma1AppliedPrice, bar);
      atr[bar] = iATR(NULL, NULL, ATR.Periods, bar) / Pip;
   }


   // calculate SR start bar
   initBars = ifInt(MA2.Method==MODE_EMA, Max(10, MA2.Periods*3), MA2.Periods);     // IIR filters need at least 10 bars for initialization
   bars     = bars-initBars;                                                        // one bar less as SR calculation looks back one bar
   startBar = Min(ChangedBars, bars) - 1;
   if (startBar < 0) return(catch("onTick(3)", ERR_HISTORY_INSUFFICIENT));

   double channelWidth, price, prevPrice = Open[startBar+1];
   double prevSR = lineUp[startBar+1] + lineDown[startBar+1];
   if (!prevSR) prevSR = prevPrice;

   // recalculate changed SR values
   for (int i=startBar; i >= 0; i--) {
      if (!atr[i]) continue;

      price        = Open[i];
      prevPrice    = Open[i+1];
      channelWidth = ATR.Multiplier * iMAOnArray(atr, WHOLE_ARRAY, MA2.Periods, 0, MA2.Method, i) * Pip;
      upperBand[i] = price + channelWidth;
      lowerBand[i] = price - channelWidth;

      if (prevPrice < prevSR) {
         if (price < prevSR) {
            lineUp  [i] = 0;
            lineDown[i] = MathMin(prevSR, upperBand[i]);
         }
         else {
            lineUp  [i] = lowerBand[i]; lineUpStart[i] = lineUp[i];
            lineDown[i] = 0;
         }
      }
      else /*prevPrice > prevSR*/{
         if (price > prevSR) {
            lineUp  [i] = MathMax(prevSR, lowerBand[i]);
            lineDown[i] = 0;
         }
         else {
            lineUp  [i] = 0;
            lineDown[i] = upperBand[i]; lineDownStart[i] = lineDown[i];
         }
      }
      prevSR = lineUp[i] + lineDown[i];
   }

   return(catch("onTick(4)"));
}


/**
 * Workaround for various terminal bugs when setting indicator options. Usually options are set in init(). However after
 * recompilation options must be set in start() to not be ignored.
 */
void SetIndicatorOptions() {
   IndicatorBuffers(terminal_buffers);
}


/**
 * Return a string representation of the input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("MA.Method=",       DoubleQuoteStr(MA.Method),         ";", NL,
                            "MA.Periods=",      MA.Periods,                        ";", NL,
                            "MA.AppliedPrice=", DoubleQuoteStr(MA.AppliedPrice),   ";", NL,
                            "MA.Color=",        ColorToStr(MA.Color),              ";")
   );
}
