/**
 * SuperTrend Channel
 *
 * This indicator is just the visual presentation of the invisible Keltner Channel part in the SuperTrend indicator. It's a separate indicator because
 * the SuperTrend indicator would have to manage more than the maximum of 8 indicator buffers to display this channel. When SuperTrend is configured
 * to display it this indicator is loaded via iCustom(). For calculating the channel in SuperTrend this indicator is not needed.
 *
 * @see  documentation in SuperTrend
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];

/////////////////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////////////////

extern int    MA.Periods            = 50;
extern string MA.PriceType          = "Close | Median | Typical* | Weighted";
extern int    ATR.Periods           = 5;

extern color  Color.Signal          = CLR_NONE;                      // color management here to allow access by the code
extern color  Color.MovingAverage   = CLR_NONE;
extern color  Color.Channel         = Red;

extern string Line.Type             = "Line* | Dot";                 // signal line type
extern int    Line.Width            = 2;                             // signal line width

extern int    Max.Values            = 6000;                          // maximum indicator values to draw: -1 = all
extern int    Shift.Vertical.Pips   = 0;                             // vertical shift in pips
extern int    Shift.Horizontal.Bars = 0;                             // horizontal shift in bars

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <stdlib.mqh>
#include <iFunctions/@Trend.mqh>

#define ST.MODE_SIGNAL      0                                        // signal line index
#define ST.MODE_MA          1                                        // MA index
#define ST.MODE_MA_SIDE     2                                        // price side index
#define ST.MODE_UPPER       3                                        // upper ATR channel band index
#define ST.MODE_LOWER       4                                        // lower ATR channel band index

#property indicator_chart_window

#property indicator_buffers 5

double bufferSignal   [];                                            // signal line
double bufferMA       [];                                            // MA
double bufferMaSide   [];                                            // whether price is above or below the MA
double bufferUpperBand[];                                            // upper ATR channel band
double bufferLowerBand[];                                            // lower ATR channel band

int    ma.periods;
int    ma.priceType;

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
   // MA.Periods
   if (MA.Periods < 2)     return(catch("onInit(1)  Invalid input parameter MA.Periods = "+ MA.Periods, ERR_INVALID_INPUT_PARAMETER));
   ma.periods = MA.Periods;
   // MA.PriceType
   string strValue, elems[];
   if (Explode(MA.PriceType, "*", elems, 2) > 1) {
      int size = Explode(elems[0], "|", elems, NULL);
      strValue = elems[size-1];
   }
   else strValue = MA.PriceType;
   ma.priceType = StrToPriceType(strValue);
   if (ma.priceType!=PRICE_CLOSE && (ma.priceType < PRICE_MEDIAN || ma.priceType > PRICE_WEIGHTED))
                           return(catch("onInit(2)  Invalid input parameter MA.PriceType = \""+ MA.PriceType +"\"", ERR_INVALID_INPUT_PARAMETER));
   MA.PriceType = PriceTypeDescription(ma.priceType);

   // ATR
   if (ATR.Periods < 1)    return(catch("onInit(3)  Invalid input parameter ATR.Periods = "+ ATR.Periods, ERR_INVALID_INPUT_PARAMETER));

   // Colors
   if (Color.Signal        == 0xFF000000) Color.Signal        = CLR_NONE;     // at times after re-compilation or re-start the terminal convertes
   if (Color.MovingAverage == 0xFF000000) Color.MovingAverage = CLR_NONE;     // CLR_NONE (0xFFFFFFFF) to 0xFF000000 (which appears Black)
   if (Color.Channel       == 0xFF000000) Color.Channel       = CLR_NONE;

   // Line.Width
   if (Line.Width < 1)     return(catch("onInit(4)  Invalid input parameter Line.Width = "+ Line.Width, ERR_INVALID_INPUT_PARAMETER));
   if (Line.Width > 5)     return(catch("onInit(5)  Invalid input parameter Line.Width = "+ Line.Width, ERR_INVALID_INPUT_PARAMETER));

   // Max.Values
   if (Max.Values < -1)    return(catch("onInit(6)  Invalid input parameter Max.Values = "+ Max.Values, ERR_INVALID_INPUT_PARAMETER));
   maxValues = ifInt(Max.Values==-1, INT_MAX, Max.Values);


   // (2) Chart legend
   indicator.shortName = __NAME__ +"("+ MA.Periods +")";
   chart.legendLabel   = CreateLegendLabel(indicator.shortName);
   ObjectRegister(chart.legendLabel);


   // (3) Buffer management
   SetIndexBuffer(ST.MODE_SIGNAL,  bufferSignal   );
   SetIndexBuffer(ST.MODE_MA,      bufferMA       );
   SetIndexBuffer(ST.MODE_MA_SIDE, bufferMaSide   );
   SetIndexBuffer(ST.MODE_UPPER,   bufferUpperBand);
   SetIndexBuffer(ST.MODE_LOWER,   bufferLowerBand);

   // Display options
   IndicatorShortName(indicator.shortName);                          // chart context menu
   SetIndexLabel(ST.MODE_SIGNAL,  indicator.shortName);              // chart tooltip and "Data Window"
   SetIndexLabel(ST.MODE_MA,      "ST MA"            );
   SetIndexLabel(ST.MODE_MA_SIDE, "ST MA-Side"       );
   SetIndexLabel(ST.MODE_UPPER,   "ST UpperBand"     );
   SetIndexLabel(ST.MODE_LOWER,   "ST LowerBand"     );
   IndicatorDigits(SubPipDigits);

   // Drawing options
   int startDraw = Max(MA.Periods-1, Bars-ifInt(Max.Values < 0, Bars, Max.Values)) + Shift.Horizontal.Bars;
   SetIndexDrawBegin(ST.MODE_SIGNAL,  startDraw); SetIndexShift(ST.MODE_SIGNAL,  Shift.Horizontal.Bars);
   SetIndexDrawBegin(ST.MODE_MA,      startDraw); SetIndexShift(ST.MODE_MA,      Shift.Horizontal.Bars);
   SetIndexDrawBegin(ST.MODE_MA_SIDE, startDraw); SetIndexShift(ST.MODE_MA_SIDE, Shift.Horizontal.Bars);
   SetIndexDrawBegin(ST.MODE_UPPER,   startDraw); SetIndexShift(ST.MODE_UPPER,   Shift.Horizontal.Bars);
   SetIndexDrawBegin(ST.MODE_LOWER,   startDraw); SetIndexShift(ST.MODE_LOWER,   Shift.Horizontal.Bars);

   shift.vertical = Shift.Vertical.Pips * Pips;                      // TODO: prevent Digits/Point errors


   // (4) Indicator styles
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
   if (ArraySize(bufferMA) == 0)                                     // may happen at terminal start
      return(debug("onTick(1)  size(bufferMA) = 0", SetLastError(ERS_TERMINAL_NOT_YET_READY)));

   // reset buffers before doing a full re-calculation (clears garbage after Max.Values)
   if (!ValidBars) {
      ArrayInitialize(bufferSignal,    EMPTY_VALUE);
      ArrayInitialize(bufferMA,        EMPTY_VALUE);
      ArrayInitialize(bufferMaSide,              0);
      ArrayInitialize(bufferUpperBand, EMPTY_VALUE);
      ArrayInitialize(bufferLowerBand, EMPTY_VALUE);
      SetIndicatorStyles();                                          // work around various terminal bugs (see there)
   }

   // on ShiftedBars synchronize buffers accordingly
   if (ShiftedBars > 0) {
      ShiftIndicatorBuffer(bufferSignal,    Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(bufferMA,        Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(bufferMaSide,    Bars, ShiftedBars,           0);
      ShiftIndicatorBuffer(bufferUpperBand, Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(bufferLowerBand, Bars, ShiftedBars, EMPTY_VALUE);
   }


   // (1) calculate the start bar
   int bars     = Min(ChangedBars, maxValues);
   int startBar = Min(bars-1, Bars-ma.periods);
   if (startBar < 0) {
      if (IsSuperContext()) return(catch("onTick(2)", ERR_HISTORY_INSUFFICIENT));
      SetLastError(ERR_HISTORY_INSUFFICIENT);                        // set error but don't return to update the legend
   }


   // (2) re-calculate invalid bars
   for (int bar=startBar; bar >= 0; bar--) {
      // Price, MA, ATR
      double price  =  iMA(NULL, NULL,           1, 0, MODE_SMA, ma.priceType, bar);
      bufferMA[bar] =  iMA(NULL, NULL,  ma.periods, 0, MODE_SMA, ma.priceType, bar);
      double atr    = iATR(NULL, NULL, ATR.Periods, bar);

      bufferUpperBand[bar] = High[bar] + atr;
      bufferLowerBand[bar] = Low [bar] - atr;

      if (price > bufferMA[bar]) {                                   // price is above the MA
         bufferMaSide[bar] = 1;
         bufferSignal[bar] = bufferLowerBand[bar];

         if (bufferMaSide[bar+1] != 0) {                             // limit the signal line to rising values
            if (bufferSignal[bar+1] > bufferSignal[bar]) bufferSignal[bar] = bufferSignal[bar+1];
         }
      }
      else /*price < bufferMA[bar]*/ {                               // price is below the MA
         bufferMaSide[bar] = -1;
         bufferSignal[bar] = bufferUpperBand[bar];

         if (bufferMaSide[bar+1] != 0) {                             // limit the signal line to falling values
            if (bufferSignal[bar+1] < bufferSignal[bar]) bufferSignal[bar] = bufferSignal[bar+1];
         }
      }



      /*
      if (Time[bar] == D'2016.10.19 15:00:00') {
         debug("onTick(0.1)  2016.10.19 15:00  upperBand="+ NumberToStr(bufferUpperBand[bar], PriceFormat) +"  lowerBand="+ NumberToStr(bufferLowerBand[bar], PriceFormat));
      }
      */

      /*
      if (currentCCI > 0) {
         TrendUp[i] = Low[i] - iATR(NULL, NULL, ATR.Periods, i);
         if (previousCCI < 0           ) TrendUp[i+1] = TrendDown[i+1];          // Farbe sofort wechseln (MetaTrader braucht min. zwei Datenpunkte)
      }
      else {
         TrendDown[i] = High[i] + iATR(NULL, NULL, ATR.Periods, i);
         if (previousCCI  > 0             ) TrendDown[i+1] = TrendUp  [i+1];     // Farbe sofort wechseln (MetaTrader braucht min. zwei Datenpunkte)
      }
      */
   }


   // (4) update legend
   @Trend.UpdateLegend(chart.legendLabel, indicator.shortName, "", RoyalBlue, RoyalBlue, bufferSignal[0], NULL, Time[0]);
   return(catch("onTick(3)"));
}


/**
 * Set indicator styles. Works around various terminal bugs causing indicator color/style changes after re-compilation. Regularily styles must be
 * set in init(). However, after re-compilation styles must be set in start() to be displayed correctly.
 */
void SetIndicatorStyles() {
   SetIndexStyle(ST.MODE_SIGNAL,  DRAW_LINE, EMPTY, Line.Width, Color.Signal       );
   SetIndexStyle(ST.MODE_MA,      DRAW_LINE, EMPTY,          1, Color.MovingAverage);
   SetIndexStyle(ST.MODE_MA_SIDE, DRAW_NONE, EMPTY,      EMPTY, CLR_NONE           );
   SetIndexStyle(ST.MODE_UPPER,   DRAW_LINE, EMPTY,          1, Color.Channel      );
   SetIndexStyle(ST.MODE_LOWER,   DRAW_LINE, EMPTY,          1, Color.Channel      );

   SetIndexLabel(ST.MODE_SIGNAL,  indicator.shortName);
   SetIndexLabel(ST.MODE_MA,      "ST MA"            );
   SetIndexLabel(ST.MODE_MA_SIDE, "ST MA-Side"       );
   SetIndexLabel(ST.MODE_UPPER,   "ST UpperBand"     );
   SetIndexLabel(ST.MODE_LOWER,   "ST LowerBand"     );
}


/**
 * String presentation of the input parameters for logging if called by iCustom().
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("init()  inputs: ",

                            "MA.Periods=",                     MA.Periods            , "; ",
                            "MA.PriceType=",    DoubleQuoteStr(MA.PriceType)         , "; ",
                            "ATR.Periods=",                    ATR.Periods           , "; ",

                            "Color.Signal=",        ColorToStr(Color.Signal)         , "; ",
                            "Color.MovingAverage=", ColorToStr(Color.MovingAverage)  , "; ",
                            "Color.Channel=",       ColorToStr(Color.Channel)        , "; ",

                            "Line.Type=",       DoubleQuoteStr(Line.Type)            , "; ",
                            "Line.Width=",                     Line.Width            , "; ",

                            "Max.Values=",                     Max.Values            , "; ",
                            "Shift.Vertical.Pips=",            Shift.Vertical.Pips   , "; ",
                            "Shift.Horizontal.Bars=",          Shift.Horizontal.Bars , "; ")
   );
}
