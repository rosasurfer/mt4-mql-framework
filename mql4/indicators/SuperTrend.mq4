/**
 * Also known as Trend Magic Indicator
 *
 * Depending on a SMA cross-over signal the upper or the lower band of a Keltner Channel (an ATR channel) is used to calculate a supportive signal
 * line.  The Keltner Channel is calculated around High and Low of the current bar, rather than around the usual Moving Average.  The value of the
 * signal line is restricted to only rising or only falling values until (1) an opposite SMA cross-over signal occurres and (2) the opposite channel
 * band crosses the (former supportive) signal line. It means with the standard settings price has to move 2 * ATR + BarSize against the current
 * trend to trigger a change in market direction. This significant counter-move helps to avoid trading in choppy markets.
 *
 * Originally the calculation was done using a CCI (only the SMA part of the CCI was used).
 *
 *   SMA:          SMA(50, TypicalPrice)
 *   TypicalPrice: (H+L+C)/3
 *
 * @source http://www.forexfactory.com/showthread.php?t=214635 (Andrew Forex Trading System)
 * @see    http://www.forexfactory.com/showthread.php?t=268038 (Plateman's CCI aka SuperTrend)
 * @see    http://stockcharts.com/school/doku.php?id=chart_school:technical_indicators:keltner_channels
 *
 * TODO: - SuperTrend Channel per iCustom() hinzuladen
 *       - LineType konfigurierbar machen
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];

/////////////////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////////////////

extern int    SMA.Periods           = 50;
extern string SMA.PriceType         = "Close | Median | Typical* | Weighted";
extern int    ATR.Periods           = 5;

extern color  Color.Uptrend         = Blue;                          // color management here to allow access by the code
extern color  Color.Downtrend       = Red;
extern color  Color.Changing        = Yellow;
extern color  Color.MovingAverage   = Magenta;

extern string Line.Type             = "Line* | Dot";                 // signal line type
extern int    Line.Width            = 2;                             // signal line width

extern int    Max.Values            = 10000;                         // maximum indicator values to draw: -1 = all
extern int    Shift.Vertical.Pips   = 0;                             // vertical shift in pips
extern int    Shift.Horizontal.Bars = 0;                             // horizontal shift in bars

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <stdlib.mqh>
#include <iFunctions/@Trend.mqh>

#define ST.MODE_SIGNAL      0                                        // signal line index
#define ST.MODE_TREND       1                                        // signal trend index
#define ST.MODE_UPTREND     2                                        // signal uptrend line index
#define ST.MODE_DOWNTREND   3                                        // signal downtrend line index
#define ST.MODE_CIP         4                                        // signal change-in-progress index (no 1-bar-reversal buffer)
#define ST.MODE_MA          5                                        // MA index
#define ST.MODE_MA_SIDE     6                                        // price side index

#property indicator_chart_window

#property indicator_buffers 7

double bufferSignal   [];                                            // full signal line:               invisible, displayed in "Data Window"
double bufferTrend    [];                                            // signal trend line:              invisible, +/-
double bufferUptrend  [];                                            // signal uptrend line:            visible
double bufferDowntrend[];                                            // signal downtrend line:          visible
double bufferCip      [];                                            // signal change-in-progress line: visible
double bufferMa       [];                                            // MA
double bufferMaSide   [];                                            // whether price is above or below the MA

int    sma.periods;
int    sma.priceType;

int    maxValues;                                                    // maximum values to draw:  all values = INT_MAX
double shift.vertical;

string indicator.shortName;                                          // name for chart, chart context menu and "Data Window"
string chart.legendLabel;


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   // (1) Validation
   // SMA.Periods
   if (SMA.Periods < 2)    return(catch("onInit(1)  Invalid input parameter SMA.Periods = "+ SMA.Periods, ERR_INVALID_INPUT_PARAMETER));
   sma.periods = SMA.Periods;
   // SMA.PriceType
   string strValue, elems[];
   if (Explode(SMA.PriceType, "*", elems, 2) > 1) {
      int size = Explode(elems[0], "|", elems, NULL);
      strValue = elems[size-1];
   }
   else strValue = SMA.PriceType;
   sma.priceType = StrToPriceType(strValue);
   if (sma.priceType!=PRICE_CLOSE && (sma.priceType < PRICE_MEDIAN || sma.priceType > PRICE_WEIGHTED))
                           return(catch("onInit(2)  Invalid input parameter SMA.PriceType = \""+ SMA.PriceType +"\"", ERR_INVALID_INPUT_PARAMETER));
   SMA.PriceType = PriceTypeDescription(sma.priceType);

   // ATR
   if (ATR.Periods < 1)    return(catch("onInit(3)  Invalid input parameter ATR.Periods = "+ ATR.Periods, ERR_INVALID_INPUT_PARAMETER));

   // Colors
   if (Color.Uptrend       == 0xFF000000) Color.Uptrend       = CLR_NONE;     // at times after re-compilation or re-start the terminal convertes
   if (Color.Downtrend     == 0xFF000000) Color.Downtrend     = CLR_NONE;     // CLR_NONE (0xFFFFFFFF) to 0xFF000000 (which appears Black)
   if (Color.Changing      == 0xFF000000) Color.Changing      = CLR_NONE;
   if (Color.MovingAverage == 0xFF000000) Color.MovingAverage = CLR_NONE;

   // Line.Width
   if (Line.Width < 1)     return(catch("onInit(4)  Invalid input parameter Line.Width = "+ Line.Width, ERR_INVALID_INPUT_PARAMETER));
   if (Line.Width > 5)     return(catch("onInit(5)  Invalid input parameter Line.Width = "+ Line.Width, ERR_INVALID_INPUT_PARAMETER));

   // Max.Values
   if (Max.Values < -1)    return(catch("onInit(6)  Invalid input parameter Max.Values = "+ Max.Values, ERR_INVALID_INPUT_PARAMETER));
   maxValues = ifInt(Max.Values==-1, INT_MAX, Max.Values);


   // (2) Chart legend
   indicator.shortName = __NAME__ +"("+ SMA.Periods +")";
   chart.legendLabel   = CreateLegendLabel(indicator.shortName);
   ObjectRegister(chart.legendLabel);


   // (3) Buffer management
   SetIndexBuffer(ST.MODE_SIGNAL,    bufferSignal   );
   SetIndexBuffer(ST.MODE_TREND,     bufferTrend    );
   SetIndexBuffer(ST.MODE_UPTREND,   bufferUptrend  );
   SetIndexBuffer(ST.MODE_DOWNTREND, bufferDowntrend);
   SetIndexBuffer(ST.MODE_CIP,       bufferCip      );
   SetIndexBuffer(ST.MODE_MA,        bufferMa       );
   SetIndexBuffer(ST.MODE_MA_SIDE,   bufferMaSide   );

   // Drawing options
   int startDraw = Max(SMA.Periods-1, Bars-ifInt(Max.Values < 0, Bars, Max.Values)) + Shift.Horizontal.Bars;
   SetIndexDrawBegin(ST.MODE_SIGNAL,    startDraw); SetIndexShift(ST.MODE_SIGNAL,    Shift.Horizontal.Bars);
   SetIndexDrawBegin(ST.MODE_TREND,     startDraw); SetIndexShift(ST.MODE_TREND,     Shift.Horizontal.Bars);
   SetIndexDrawBegin(ST.MODE_UPTREND,   startDraw); SetIndexShift(ST.MODE_UPTREND,   Shift.Horizontal.Bars);
   SetIndexDrawBegin(ST.MODE_DOWNTREND, startDraw); SetIndexShift(ST.MODE_DOWNTREND, Shift.Horizontal.Bars);
   SetIndexDrawBegin(ST.MODE_CIP,       startDraw); SetIndexShift(ST.MODE_CIP,       Shift.Horizontal.Bars);
   SetIndexDrawBegin(ST.MODE_MA,        startDraw); SetIndexShift(ST.MODE_MA,        Shift.Horizontal.Bars);
   SetIndexDrawBegin(ST.MODE_MA_SIDE,   startDraw); SetIndexShift(ST.MODE_MA_SIDE,   Shift.Horizontal.Bars);

   shift.vertical = Shift.Vertical.Pips * Pips;                      // TODO: prevent Digits/Point errors


   // (4) Indicator styles and display options
   IndicatorDigits(SubPipDigits);
   IndicatorShortName(indicator.shortName);                          // chart context menu
   SetIndicatorStyles();                                             // work around various terminal bugs (see there)

   return(catch("onInit(7)"));
}


/**
 * De-initialization
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
   // make sure indicator buffers are initialized
   if (ArraySize(bufferSignal) == 0)                                 // may happen at terminal start
      return(debug("onTick(1)  size(bufferSignal) = 0", SetLastError(ERS_TERMINAL_NOT_YET_READY)));

   // reset buffers before doing a full re-calculation (clears garbage after Max.Values)
   if (!ValidBars) {
      ArrayInitialize(bufferSignal,    EMPTY_VALUE);
      ArrayInitialize(bufferTrend,               0);
      ArrayInitialize(bufferUptrend,   EMPTY_VALUE);
      ArrayInitialize(bufferDowntrend, EMPTY_VALUE);
      ArrayInitialize(bufferCip,       EMPTY_VALUE);
      ArrayInitialize(bufferMa,        EMPTY_VALUE);
      ArrayInitialize(bufferMaSide,              0);
      SetIndicatorStyles();                                          // work around various terminal bugs (see there)
   }

   // on ShiftedBars synchronize buffers accordingly
   if (ShiftedBars > 0) {
      ShiftIndicatorBuffer(bufferSignal,    Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(bufferTrend,     Bars, ShiftedBars,           0);
      ShiftIndicatorBuffer(bufferUptrend,   Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(bufferDowntrend, Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(bufferCip,       Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(bufferMa,        Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(bufferMaSide,    Bars, ShiftedBars,           0);
   }


   // (1) calculate the start bar
   int bars     = Min(ChangedBars, maxValues);
   int startBar = Min(bars-1, Bars-sma.periods);
   if (startBar < 0) {
      if (IsSuperContext()) return(catch("onTick(2)", ERR_HISTORY_INSUFFICIENT));
      SetLastError(ERR_HISTORY_INSUFFICIENT);                        // set error but don't return to update the legend
   }

   double dNull[];


   // (2) re-calculate invalid bars
   for (int bar=startBar; bar >= 0; bar--) {
      // price, MA, ATR, bands
      double price     =  iMA(NULL, NULL,           1, 0, MODE_SMA, sma.priceType, bar);
      bufferMa[bar]    =  iMA(NULL, NULL, sma.periods, 0, MODE_SMA, sma.priceType, bar);
      double atr       = iATR(NULL, NULL, ATR.Periods, bar);
      double upperBand = High[bar] + atr;
      double lowerBand = Low [bar] - atr;

      bool checkCipBuffer = false;

      if (price > bufferMa[bar]) {                                   // price is above the MA
         bufferMaSide[bar] = 1;

         bufferSignal[bar] = lowerBand;
         if (bufferMaSide[bar+1] != 0) {                             // limit the signal line to rising values
            if (bufferSignal[bar+1] > bufferSignal[bar]) {
               bufferSignal[bar] = bufferSignal[bar+1];
               checkCipBuffer    = true;
            }
         }
      }
      else /*price < bufferMa[bar]*/ {                               // price is below the MA
         bufferMaSide[bar] = -1;

         bufferSignal[bar] = upperBand;
         if (bufferMaSide[bar+1] != 0) {                             // limit the signal line to falling values
            if (bufferSignal[bar+1] < bufferSignal[bar]) {
               bufferSignal[bar] = bufferSignal[bar+1];
               checkCipBuffer    = true;
            }
         }
      }

      // update trend direction and colors (no uptrend2[] buffer as there can't be a 1-bar-reversal)
      @Trend.UpdateColors(bufferSignal, bar, bufferTrend, bufferUptrend, bufferDowntrend, DRAW_LINE, dNull);

      // update CIP buffer if flagged
      if (checkCipBuffer) {
         if (bufferTrend[bar] > 0) {                                 // up-trend
            if (bufferMaSide[bar] == -1) {                           // set "change" buffer if on opposite MA side
               bufferCip[bar]   = bufferSignal[bar];
               bufferCip[bar+1] = bufferSignal[bar+1];
            }
         }
         else /*downtrend*/{
            if (bufferMaSide[bar] == 1) {                            // set "change" buffer if on opposite MA side
               bufferCip[bar]   = bufferSignal[bar];
               bufferCip[bar+1] = bufferSignal[bar+1];
            }
         }
      }
   }


   // (4) update chart legend
   @Trend.UpdateLegend(chart.legendLabel, indicator.shortName, "", Color.Uptrend, Color.Downtrend, bufferSignal[0], NULL, Time[0]);
   return(catch("onTick(3)"));
}


/**
 * Set indicator styles. Works around various terminal bugs causing indicator color/style changes after re-compilation. Regularily styles must be
 * set in init(). However, after re-compilation styles must be set in start() to be displayed correctly.
 */
void SetIndicatorStyles() {
   SetIndexStyle(ST.MODE_SIGNAL,    DRAW_NONE, EMPTY,      EMPTY, CLR_NONE           );
   SetIndexStyle(ST.MODE_TREND,     DRAW_NONE, EMPTY,      EMPTY, CLR_NONE           );
   SetIndexStyle(ST.MODE_UPTREND,   DRAW_LINE, EMPTY, Line.Width, Color.Uptrend      );
   SetIndexStyle(ST.MODE_DOWNTREND, DRAW_LINE, EMPTY, Line.Width, Color.Downtrend    );
   SetIndexStyle(ST.MODE_CIP,       DRAW_LINE, EMPTY, Line.Width, Color.Changing     );
   SetIndexStyle(ST.MODE_MA,        DRAW_LINE, EMPTY,          1, Color.MovingAverage);
   SetIndexStyle(ST.MODE_MA_SIDE,   DRAW_NONE, EMPTY,      EMPTY, CLR_NONE           );

   SetIndexLabel(ST.MODE_SIGNAL,    indicator.shortName);            // chart tooltip and "Data Window"
   SetIndexLabel(ST.MODE_TREND,     "ST Trend"         );
   SetIndexLabel(ST.MODE_UPTREND,   "ST Uptrend"       );
   SetIndexLabel(ST.MODE_DOWNTREND, "ST Downtrend"     );
   SetIndexLabel(ST.MODE_CIP,       "ST Changing"      );
   SetIndexLabel(ST.MODE_MA,        "ST MA"            );
   SetIndexLabel(ST.MODE_MA_SIDE,   "ST MA-Side"       );
}


/**
 * String presentation of the input parameters for logging if called by iCustom().
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("init()  inputs: ",

                            "SMA.Periods=",                    SMA.Periods           , "; ",
                            "SMA.PriceType=",   DoubleQuoteStr(SMA.PriceType)        , "; ",
                            "ATR.Periods=",                    ATR.Periods           , "; ",

                            "Color.Uptrend=",       ColorToStr(Color.Uptrend)        , "; ",
                            "Color.Downtrend=",     ColorToStr(Color.Downtrend)      , "; ",
                            "Color.Changing=",      ColorToStr(Color.Changing)       , "; ",
                            "Color.MovingAverage=", ColorToStr(Color.MovingAverage)  , "; ",

                            "Line.Type=",       DoubleQuoteStr(Line.Type)            , "; ",
                            "Line.Width=",                     Line.Width            , "; ",

                            "Max.Values=",                     Max.Values            , "; ",
                            "Shift.Vertical.Pips=",            Shift.Vertical.Pips   , "; ",
                            "Shift.Horizontal.Bars=",          Shift.Horizontal.Bars , "; ")
   );
}
