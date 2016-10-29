/**
 * One side of a Keltner Channel (an ATR channel) which is calculated around High and Low of the current bar, rather than around the usual Moving
 * Average. Depending on a SMA cross-over signal the upper or the lower channel band is used as indicator line. Additional criterias must be defined
 * to avoid chop (e.g. the Keltner channel), however no such information is given. Originally the calculation is done with a CCI but the CCI is not
 * used. Instead the CCI also uses a SMA(Typical).
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
 *       - Kl‰ren: Die Werte des Channels sind bis zum CCI-Wechsel auf das jeweils aufgetretene Channel-Minimum/-Maximum fixiert, die
 *         resultierende Linie kann im Aufw‰rtstrend nur steigen und im Abw‰rtstrend nur fallen.
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

extern string Line.Type             = "Line* | Dot";                 // line type of the channel bands
extern int    Line.Width            = 2;                             // line width of the channel bands

extern int    Max.Values            = 3000;                          // maximum indicator values to draw: -1 = all
extern int    Shift.Vertical.Pips   = 0;                             // vertical shift in pips
extern int    Shift.Horizontal.Bars = 0;                             // horizontal shift in bars

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <stdlib.mqh>
#include <iFunctions/@MA.mqh>

#define ST.MODE_MA          0                                        // MA index
#define ST.MODE_UPPER       1                                        // upper ATR channel band index
#define ST.MODE_LOWER       2                                        // lower ATR channel band index

#property indicator_chart_window

#property indicator_buffers 3

#property indicator_width1  1
#property indicator_width2  1
#property indicator_width2  1

double bufferMA       [];                                            // MA
double bufferUpperBand[];                                            // upper ATR channel band
double bufferLowerBand[];                                            // lower ATR channel band

int    ma.periods;
int    ma.appliedPrice;

string indicator.shortName;                                          // name for chart, chart context menu and "Data Window"
string chart.legendLabel;
int    maxValues;                                                    // maximum values to draw:  all values = INT_MAX
double shift.vertical;


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
   SetIndexBuffer(ST.MODE_MA,    bufferMA       );
   SetIndexBuffer(ST.MODE_UPPER, bufferUpperBand);
   SetIndexBuffer(ST.MODE_LOWER, bufferLowerBand);

   // Display options
   IndicatorShortName(indicator.shortName);                          // chart context menu
   SetIndexLabel(ST.MODE_MA,    indicator.shortName);                // chart tooltip and "Data Window"
   SetIndexLabel(ST.MODE_UPPER, indicator.shortName);
   SetIndexLabel(ST.MODE_LOWER, indicator.shortName);
   IndicatorDigits(SubPipDigits);

   // Drawing options
   int startDraw = Max(MA.Periods-1, Bars-ifInt(Max.Values < 0, Bars, Max.Values)) + Shift.Horizontal.Bars;
   SetIndexDrawBegin(ST.MODE_MA,    startDraw); SetIndexShift(ST.MODE_MA,    Shift.Horizontal.Bars);
   SetIndexDrawBegin(ST.MODE_UPPER, startDraw); SetIndexShift(ST.MODE_UPPER, Shift.Horizontal.Bars);
   SetIndexDrawBegin(ST.MODE_LOWER, startDraw); SetIndexShift(ST.MODE_LOWER, Shift.Horizontal.Bars);

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
      ArrayInitialize(bufferUpperBand, EMPTY_VALUE);
      ArrayInitialize(bufferLowerBand, EMPTY_VALUE);
      SetIndicatorStyles();                                          // work around various terminal bugs (see there)
   }

   // on ShiftedBars synchronize buffers accordingly
   if (ShiftedBars > 0) {
      ShiftIndicatorBuffer(bufferMA,        Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(bufferUpperBand, Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(bufferLowerBand, Bars, ShiftedBars, EMPTY_VALUE);
   }


   // (1) resolve start bar of calculation
   int bars     = Min(ChangedBars, maxValues);
   int startBar = Min(bars-1, Bars-ma.periods);
   if (startBar < 0) {
      if (IsSuperContext()) return(catch("onTick(2)", ERR_HISTORY_INSUFFICIENT));
      SetLastError(ERR_HISTORY_INSUFFICIENT);                        // set error but don't return to update the legend
   }

   //debug("onTick(0.1)  startBar="+ startBar +"  ma.periods="+ ma.periods);

   // (2) re-calculate invalid bars
   for (int bar=startBar; bar >= 0; bar--) {
      // Moving Average
      bufferMA[bar]  = iMA(NULL, NULL, ma.periods, 0, MODE_SMA, ma.appliedPrice, bar);
      bufferMA[bar] += shift.vertical;








      /*
      double currentCCI  = iCCI(NULL, NULL, CCI.Periods, PRICE_TYPICAL, i  );
      double previousCCI = iCCI(NULL, NULL, CCI.Periods, PRICE_TYPICAL, i+1);

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
   SetIndexStyle(ST.MODE_MA,    DRAW_LINE, EMPTY, Line.Width, Color.MA       );
   SetIndexStyle(ST.MODE_UPPER, DRAW_LINE, EMPTY, Line.Width, Color.UpperBand);
   SetIndexStyle(ST.MODE_LOWER, DRAW_LINE, EMPTY, Line.Width, Color.LowerBand);
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

                            "Line.Type=\"",                Line.Type             , "\"; ",
                            "Line.Width=",                 Line.Width            , "; ",

                            "Max.Values=",                 Max.Values            , "; ",
                            "Shift.Vertical.Pips=",        Shift.Vertical.Pips   , "; ",
                            "Shift.Horizontal.Bars=",      Shift.Horizontal.Bars , "; ")
   );
}