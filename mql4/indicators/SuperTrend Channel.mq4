/**
 * SuperTrend Channel
 *
 * Visualization of the otherwise invisible Keltner Channel part in the SuperTrend indicator. Implemented separately because
 * the SuperTrend indicator would have to manage more than the maximum of 8 indicator buffers to visualize this channel.
 * When SuperTrend is asked to draw the channel this indicator is loaded via iCustom(). For calculating the channel in
 * SuperTrend this indicator is not needed.
 *
 * @see  documentation in SuperTrend
 */
#include <stddefines.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern int    SMA.Periods   = 50;
extern string SMA.PriceType = "Close | Median | Typical* | Weighted";
extern int    ATR.Periods   = 1;

extern color  Color.Channel = Blue;                                  // color management here to allow access by the code

extern int    Max.Values    = 5000;                                  // max. number of values to calculate: -1 = all

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <rsfLibs.mqh>

#property indicator_chart_window
#property indicator_buffers   2                                      // configurable buffers (input dialog)
int       allocated_buffers = 2;                                     // used buffers

#property indicator_style1    STYLE_SOLID                            // STYLE_DOT
#property indicator_style2    STYLE_SOLID                            // STYLE_DOT

#define ST.MODE_UPPER         0                                      // upper ATR channel band index
#define ST.MODE_LOWER         1                                      // lower ATR channel band index

double bufferUpperBand[];                                            // upper ATR channel band
double bufferLowerBand[];                                            // lower ATR channel band

int    sma.periods;
int    sma.priceType;

int    maxValues;                                                    // maximum values to draw:  all values = INT_MAX

string indicator.shortName;                                          // name for chart, chart context menu and Data window
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
   else {
      strValue = StrTrim(SMA.PriceType);
      if (strValue == "") strValue = "Typical";                            // default price type
   }
   sma.priceType = StrToPriceType(strValue, F_ERR_INVALID_PARAMETER);
   if (sma.priceType!=PRICE_CLOSE && (sma.priceType < PRICE_MEDIAN || sma.priceType > PRICE_WEIGHTED))
                           return(catch("onInit(2)  Invalid input parameter SMA.PriceType = \""+ SMA.PriceType +"\"", ERR_INVALID_INPUT_PARAMETER));
   SMA.PriceType = PriceTypeDescription(sma.priceType);

   // ATR
   if (ATR.Periods < 1)    return(catch("onInit(3)  Invalid input parameter ATR.Periods = "+ ATR.Periods, ERR_INVALID_INPUT_PARAMETER));

   // Colors
   if (Color.Channel == 0xFF000000) Color.Channel = CLR_NONE;

   // Max.Values
   if (Max.Values < -1)    return(catch("onInit(4)  Invalid input parameter Max.Values = "+ Max.Values, ERR_INVALID_INPUT_PARAMETER));
   maxValues = ifInt(Max.Values==-1, INT_MAX, Max.Values);


   // (2) Chart legend
   indicator.shortName = __NAME__ +"("+ SMA.Periods +")";
   if (!IsSuperContext()) {
       chart.legendLabel   = CreateLegendLabel(indicator.shortName);
       ObjectRegister(chart.legendLabel);
   }


   // (3) Buffer management
   SetIndexBuffer(ST.MODE_UPPER, bufferUpperBand);
   SetIndexBuffer(ST.MODE_LOWER, bufferLowerBand);

   // Drawing options
   int startDraw = 0;
   if (Max.Values >= 0) startDraw = Bars - Max.Values;
   if (startDraw  <  0) startDraw = 0;
   SetIndexDrawBegin(ST.MODE_UPPER, startDraw);
   SetIndexDrawBegin(ST.MODE_LOWER, startDraw);


   // (4) Indicator styles
   IndicatorDigits(SubPipDigits);
   IndicatorShortName(indicator.shortName);                          // chart context menu and tooltip
   SetIndicatorOptions();

   return(catch("onInit(5)"));
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
   if (!ArraySize(bufferUpperBand))                                  // may happen at terminal start
      return(log("onTick(1)  size(bufferMa) = 0", SetLastError(ERS_TERMINAL_NOT_YET_READY)));

   // reset all buffers and delete garbage behind Max.Values before doing a full recalculation
   if (!UnchangedBars) {
      ArrayInitialize(bufferUpperBand, EMPTY_VALUE);
      ArrayInitialize(bufferLowerBand, EMPTY_VALUE);
      SetIndicatorOptions();
   }

   // on ShiftedBars synchronize buffers accordingly
   if (ShiftedBars > 0) {
      ShiftIndicatorBuffer(bufferUpperBand, Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(bufferLowerBand, Bars, ShiftedBars, EMPTY_VALUE);
   }


   // (1) calculate the start bar
   int bars     = Min(ChangedBars, maxValues);
   int startBar = Min(bars-1, Bars-sma.periods);
   if (startBar < 0) {
      if (IsSuperContext()) return(catch("onTick(2)", ERR_HISTORY_INSUFFICIENT));
      SetLastError(ERR_HISTORY_INSUFFICIENT);                        // set error but don't return to update the legend
   }


   // (2) re-calculate changed bars
   for (int bar=startBar; bar >= 0; bar--) {
      double atr = iATR(NULL, NULL, ATR.Periods, bar);
      if (bar == 0) {                                                // suppress ATR jitter at the progressing bar 0
         double  tr0 = iATR(NULL, NULL,           1, 0);             // TrueRange of the progressing bar 0
         double atr1 = iATR(NULL, NULL, ATR.Periods, 1);             // ATR(Periods) of the previous closed bar 1
         if (tr0 < atr1)                                             // use the previous ATR as long as the progressing bar's range does not exceed it
            atr = atr1;
      }
      bufferUpperBand[bar] = High[bar] + atr;
      bufferLowerBand[bar] = Low [bar] - atr;
   }
   return(catch("onTick(3)"));
}


/**
 * Workaround for various terminal bugs when setting indicator options. Usually options are set in init(). However after
 * recompilation options must be set in start() to not get ignored.
 */
void SetIndicatorOptions() {
   SetIndexStyle(ST.MODE_UPPER, DRAW_LINE, EMPTY, EMPTY, Color.Channel);
   SetIndexStyle(ST.MODE_LOWER, DRAW_LINE, EMPTY, EMPTY, Color.Channel);

   SetIndexLabel(ST.MODE_UPPER, "ST UpperBand");                     // Data window
   SetIndexLabel(ST.MODE_LOWER, "ST LowerBand");
}


/**
 * Return a string representation of the input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("SMA.Periods=",   SMA.Periods,                   ";", NL,
                            "SMA.PriceType=", DoubleQuoteStr(SMA.PriceType), ";", NL,
                            "ATR.Periods=",   ATR.Periods,                   ";", NL,

                            "Color.Channel=", ColorToStr(Color.Channel),     ";", NL,

                            "Max.Values=",    Max.Values,                    ";")
   );
}
