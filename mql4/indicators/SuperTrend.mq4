/**
 * Depending on a SMA cross-over signal the upper or the lower band of a Keltner Channel (an ATR channel) is used to calculate a supportive signal
 * line.  The Keltner Channel is calculated around High and Low of the current bar, rather than around the usual Moving Average.  The value of the
 * signal line is restricted to only rising or only falling values until (1) an opposite SMA cross-over signal occurres and (2) the opposite channel
 * band crosses the (former supportive) signal line. It means with the standard settings price has to move 2 * ATR + BarSize against the current
 * trend to trigger a change in market direction. This significant counter-move helps to avoid trading in choppy markets.
 *
 * Originally the calculation was done by help of a CCI. However, only the SMA part of the CCI was used.
 *
 *   SMA:          SMA(50, TypicalPrice)
 *   TypicalPrice: (H+L+C)/3
 *
 * @source http://www.forexfactory.com/showthread.php?t=214635 (Andrew Forex Trading System)
 * @see    http://www.forexfactory.com/showthread.php?t=268038 (Plateman's CCI aka SuperTrend)
 * @see    http://stockcharts.com/school/doku.php?id=chart_school:technical_indicators:keltner_channels
 *
 *
 *
 *
 *
 *
 * TODO: - Keltner-Channel komplett zeichnen (muﬂ als Filter benutzt werden)
 *       - verwendeten PriceType im SMA konfigurierbar machen
 *       - LineType konfigurierbar machen: Non-repainting only with LINE_DOT
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];

/////////////////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////////////////

extern int    MA.Periods            = 50;
extern string MA.AppliedPrice       = "Close | Median | Typical* | Weighted";
extern int    ATR.Periods           = 5;
extern double ATR.Multiplier        = 1;

extern color  Color.MA              = Blue;                          // color management here to allow access by the code
extern color  Color.UpperBand       = Green;
extern color  Color.LowerBand       = Red;
extern color  Color.Signal          = RoyalBlue;

extern string Line.Type             = "Line* | Dot";                 // signal line type
extern int    Line.Width            = 2;                             // signal line width

extern int    Max.Values            = 10000;                         // maximum indicator values to draw: -1 = all
extern int    Shift.Vertical.Pips   = 0;                             // vertical shift in pips
extern int    Shift.Horizontal.Bars = 0;                             // horizontal shift in bars

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <stdlib.mqh>
#include <iFunctions/@MA.mqh>

#define ST.MODE_MA          0                                        // MA index
#define ST.MODE_SIDE        1                                        // price side index
#define ST.MODE_UPPER       2                                        // upper ATR channel band index
#define ST.MODE_LOWER       3                                        // lower ATR channel band index
#define ST.MODE_SIGNAL      4                                        // signal line index

#define ST.ABOVE_MA         1                                        // price is above the MA line
#define ST.BELOW_MA        -1                                        // price is below the MA line

#property indicator_chart_window

#property indicator_buffers 5

double bufferMA       [];                                            // MA
double bufferSide     [];                                            // whether price is above or below the MA
double bufferUpperBand[];                                            // upper ATR channel band
double bufferLowerBand[];                                            // lower ATR channel band
double bufferSignal   [];                                            // signal line

int    ma.periods;
int    ma.appliedPrice;

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
   // MA.AppliedPrice
   string strValue, elems[];
   if (Explode(MA.AppliedPrice, "*", elems, 2) > 1) {
      int size = Explode(elems[0], "|", elems, NULL);
      strValue = elems[size-1];
   }
   else strValue = MA.AppliedPrice;
   ma.appliedPrice = StrToPriceType(strValue);
   if (ma.appliedPrice!=PRICE_CLOSE && (ma.appliedPrice < PRICE_MEDIAN || ma.appliedPrice > PRICE_WEIGHTED))
                           return(catch("onInit(2)  Invalid input parameter MA.AppliedPrice = \""+ MA.AppliedPrice +"\"", ERR_INVALID_INPUT_PARAMETER));
   MA.AppliedPrice = PriceTypeDescription(ma.appliedPrice);

   // ATR
   if (ATR.Periods    < 1) return(catch("onInit(3)  Invalid input parameter ATR.Periods = "+ ATR.Periods, ERR_INVALID_INPUT_PARAMETER));
   if (ATR.Multiplier < 0) return(catch("onInit(4)  Invalid input parameter ATR.Multiplier = "+ NumberToStr(ATR.Multiplier, ".+"), ERR_INVALID_INPUT_PARAMETER));

   // Colors
   if (Color.MA        == 0xFF000000) Color.MA        = CLR_NONE;    // at times after re-compilation or re-start the terminal convertes
   if (Color.UpperBand == 0xFF000000) Color.UpperBand = CLR_NONE;    // CLR_NONE (0xFFFFFFFF) to 0xFF000000 (which appears Black)
   if (Color.LowerBand == 0xFF000000) Color.LowerBand = CLR_NONE;
   if (Color.Signal    == 0xFF000000) Color.Signal    = CLR_NONE;

   // Line.Width
   if (Line.Width < 1)     return(catch("onInit(5)  Invalid input parameter Line.Width = "+ Line.Width, ERR_INVALID_INPUT_PARAMETER));
   if (Line.Width > 5)     return(catch("onInit(6)  Invalid input parameter Line.Width = "+ Line.Width, ERR_INVALID_INPUT_PARAMETER));

   // Max.Values
   if (Max.Values < -1)    return(catch("onInit(7)  Invalid input parameter Max.Values = "+ Max.Values, ERR_INVALID_INPUT_PARAMETER));
   maxValues = ifInt(Max.Values==-1, INT_MAX, Max.Values);


   // (2) Chart legend
   indicator.shortName = __NAME__ +"("+ MA.Periods +")";
   chart.legendLabel   = CreateLegendLabel(indicator.shortName);
   ObjectRegister(chart.legendLabel);


   // (3) Buffer management
   SetIndexBuffer(ST.MODE_MA,     bufferMA       );
   SetIndexBuffer(ST.MODE_SIDE,   bufferSide     );
   SetIndexBuffer(ST.MODE_UPPER,  bufferUpperBand);
   SetIndexBuffer(ST.MODE_LOWER,  bufferLowerBand);
   SetIndexBuffer(ST.MODE_SIGNAL, bufferSignal   );

   // Display options
   IndicatorShortName(indicator.shortName);                          // chart context menu
   SetIndexLabel(ST.MODE_MA,     indicator.shortName);               // chart tooltip and "Data Window"
   SetIndexLabel(ST.MODE_SIDE,   "ST MA-Side"  );
   SetIndexLabel(ST.MODE_UPPER,  "ST UpperBand");
   SetIndexLabel(ST.MODE_LOWER,  "ST LowerBand");
   SetIndexLabel(ST.MODE_SIGNAL, "ST Signal"   );
   IndicatorDigits(SubPipDigits);

   // Drawing options
   int startDraw = Max(MA.Periods-1, Bars-ifInt(Max.Values < 0, Bars, Max.Values)) + Shift.Horizontal.Bars;
   SetIndexDrawBegin(ST.MODE_MA,     startDraw); SetIndexShift(ST.MODE_MA,     Shift.Horizontal.Bars);
   SetIndexDrawBegin(ST.MODE_SIDE,   startDraw); SetIndexShift(ST.MODE_SIDE,   Shift.Horizontal.Bars);
   SetIndexDrawBegin(ST.MODE_UPPER,  startDraw); SetIndexShift(ST.MODE_UPPER,  Shift.Horizontal.Bars);
   SetIndexDrawBegin(ST.MODE_LOWER,  startDraw); SetIndexShift(ST.MODE_LOWER,  Shift.Horizontal.Bars);
   SetIndexDrawBegin(ST.MODE_SIGNAL, startDraw); SetIndexShift(ST.MODE_SIGNAL, Shift.Horizontal.Bars);

   shift.vertical = Shift.Vertical.Pips * Pips;                      // TODO: prevent Digits/Point errors


   // (4) Indicator styles
   SetIndicatorStyles();                                             // work around various terminal bugs (see there)
   return(catch("onInit(8)"));
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
      ArrayInitialize(bufferMA,        EMPTY_VALUE);
      ArrayInitialize(bufferSide,                0);
      ArrayInitialize(bufferUpperBand, EMPTY_VALUE);
      ArrayInitialize(bufferLowerBand, EMPTY_VALUE);
      ArrayInitialize(bufferSignal,    EMPTY_VALUE);
      SetIndicatorStyles();                                          // work around various terminal bugs (see there)
   }

   // on ShiftedBars synchronize buffers accordingly
   if (ShiftedBars > 0) {
      ShiftIndicatorBuffer(bufferMA,        Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(bufferSide,      Bars, ShiftedBars,           0);
      ShiftIndicatorBuffer(bufferUpperBand, Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(bufferLowerBand, Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(bufferSignal,    Bars, ShiftedBars, EMPTY_VALUE);
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
      double price  =  iMA(NULL, NULL,           1, 0, MODE_SMA, ma.appliedPrice, bar);
      bufferMA[bar] =  iMA(NULL, NULL,  ma.periods, 0, MODE_SMA, ma.appliedPrice, bar);
      double atr    = iATR(NULL, NULL, ATR.Periods, bar) * ATR.Multiplier;

      bufferUpperBand[bar] = High[bar] + atr;
      bufferLowerBand[bar] = Low [bar] - atr;

      if (price > bufferMA[bar]) {                             // price is above the MA
         bufferSide  [bar] = ST.ABOVE_MA;
         bufferSignal[bar] = bufferLowerBand[bar];

         if (bufferSide[bar+1] != NULL) {                      // limit the signal line to rising values
            if (bufferSignal[bar+1] > bufferSignal[bar]) bufferSignal[bar] = bufferSignal[bar+1];
         }
      }

      else /*price < bufferMA[bar]*/ {                         // price is below the MA
         bufferSide  [bar] = ST.BELOW_MA;
         bufferSignal[bar] = bufferUpperBand[bar];

         if (bufferSide[bar+1] != NULL) {                      // limit the signal line to falling values
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
         if (TrendUp[i]  < TrendUp[i+1]) TrendUp[i  ] = TrendUp  [i+1];          // Werte auf das bisherige Maximum begrenzen
      }
      else {
         TrendDown[i] = High[i] + iATR(NULL, NULL, ATR.Periods, i);
         if (previousCCI  > 0             ) TrendDown[i+1] = TrendUp  [i+1];     // Farbe sofort wechseln (MetaTrader braucht min. zwei Datenpunkte)
         if (TrendDown[i] > TrendDown[i+1]) TrendDown[i  ] = TrendDown[i+1];     // Werte auf das bisherige Minimum begrenzen
      }
      */
   }


   // (4) update legend
   @MA.UpdateLegend(chart.legendLabel, indicator.shortName, "", Color.MA, Color.MA, bufferMA[0], NULL, Time[0]);
   return(catch("onTick(3)"));
}


/**
 * Set indicator styles. Works around various terminal bugs causing indicator color/style changes after re-compilation. Regularily styles must be
 * set in init(). However, after re-compilation styles must be set in start() to be displayed correctly.
 */
void SetIndicatorStyles() {
   SetIndexStyle(ST.MODE_MA,     DRAW_LINE, EMPTY,          1, Color.MA       );
   SetIndexStyle(ST.MODE_SIDE,   DRAW_NONE, EMPTY,      EMPTY, CLR_NONE       );
   SetIndexStyle(ST.MODE_UPPER,  DRAW_LINE, EMPTY,          1, Color.UpperBand);
   SetIndexStyle(ST.MODE_LOWER,  DRAW_LINE, EMPTY,          1, Color.LowerBand);
   SetIndexStyle(ST.MODE_SIGNAL, DRAW_LINE, EMPTY, Line.Width, Color.Signal   );

   SetIndexLabel(ST.MODE_MA,     indicator.shortName);
   SetIndexLabel(ST.MODE_SIDE,   "ST MA-Side"       );
   SetIndexLabel(ST.MODE_UPPER,  "ST UpperBand"     );
   SetIndexLabel(ST.MODE_LOWER,  "ST LowerBand"     );
   SetIndexLabel(ST.MODE_SIGNAL, "ST Signal"        );
}


/**
 * String presentation of the input parameters for logging if called by iCustom().
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("init()  inputs: ",

                            "MA.Periods=",                 MA.Periods            , "; ",
                            "MA.AppliedPrice=\"",          MA.AppliedPrice       , "\"; ",
                            "ATR.Periods=",                ATR.Periods           , "; ",
                            "ATR.Multiplier=", NumberToStr(ATR.Multiplier, ".1+"), "; ",

                            "Color.MA=",        ColorToStr(Color.MA)             , "; ",
                            "Color.UpperBand=", ColorToStr(Color.UpperBand)      , "; ",
                            "Color.LowerBand=", ColorToStr(Color.LowerBand)      , "; ",
                            "Color.Signal=",    ColorToStr(Color.Signal)         , "; ",

                            "Line.Type=\"",                Line.Type             , "\"; ",
                            "Line.Width=",                 Line.Width            , "; ",

                            "Max.Values=",                 Max.Values            , "; ",
                            "Shift.Vertical.Pips=",        Shift.Vertical.Pips   , "; ",
                            "Shift.Horizontal.Bars=",      Shift.Horizontal.Bars , "; ")
   );
}