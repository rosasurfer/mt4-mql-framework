/**
 * Stochastic of RSI
 *
 *
 * The Stochastic oscillator shows the relative position of current price compared to the price range of the lookback period,
 * normalized to a value from 0 to 100. The fast Stochastic is smoothed once, the slow Stochastic is smoothed twice.
 *
 * The RSI (Relative Strength Index) is the EMA-smoothed ratio of gains to losses during the lookback period, again normalized
 * to a value from 0 to 100.
 *
 * Indicator buffers for iCustom():
 *  • Stochastic.MODE_MAIN:   indicator base line (fast Stochastic) or first moving average (slow Stochastic)
 *  • Stochastic.MODE_SIGNAL: indicator signal line (the last moving average)
 */
#include <stddefines.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern int Stochastic.Periods     = 96;
extern int Stochastic.MA1.Periods = 10;                  // first moving average periods
extern int Stochastic.MA2.Periods = 6;                   // second moving average periods
extern int RSI.Periods            = 96;

extern int Max.Values             = 5000;                // max. amount of values to calculate (-1: all)

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <rsfLibs.mqh>

#define MODE_STOCH_MA1        Stochastic.MODE_MAIN       // indicator buffer ids
#define MODE_STOCH_MA2        Stochastic.MODE_SIGNAL
#define MODE_STOCH_RAW        2
#define MODE_RSI              3

#property indicator_separate_window
#property indicator_buffers   2                          // buffers visible in input dialog
int       allocated_buffers = 4;

#property indicator_color1    CLR_NONE
#property indicator_color2    DodgerBlue

#property indicator_level1    40
#property indicator_level2    60

#property indicator_minimum   0
#property indicator_maximum   100

double bufferRsi  [];                                    // RSI value:            invisible
double bufferStoch[];                                    // Stochastic raw value: invisible
double bufferMa1  [];                                    // first MA(Stoch):      visible
double bufferMa2  [];                                    // second MA(MA1):       visible, displayed in "Data" window

int stochPeriods;
int ma1Periods;
int ma2Periods;
int rsiPeriods;

int maxValues;


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   // validate inputs
   if (Stochastic.Periods < 2)     return(catch("onInit(1)  Invalid input parameter Stochastic.Periods: "+ Stochastic.Periods +" (min. 2)", ERR_INVALID_INPUT_PARAMETER));
   if (Stochastic.MA1.Periods < 1) return(catch("onInit(2)  Invalid input parameter Stochastic.MA1.Periods: "+ Stochastic.MA1.Periods, ERR_INVALID_INPUT_PARAMETER));
   if (Stochastic.MA2.Periods < 1) return(catch("onInit(3)  Invalid input parameter Stochastic.MA2.Periods: "+ Stochastic.MA2.Periods, ERR_INVALID_INPUT_PARAMETER));
   if (RSI.Periods < 2)            return(catch("onInit(4)  Invalid input parameter RSI.Periods: "+ RSI.Periods +" (min. 2)", ERR_INVALID_INPUT_PARAMETER));
   if (Max.Values < -1)            return(catch("onInit(5)  Invalid input parameter Max.Values: "+ Max.Values, ERR_INVALID_INPUT_PARAMETER));
   stochPeriods = Stochastic.Periods;
   ma1Periods   = Stochastic.MA1.Periods;
   ma2Periods   = Stochastic.MA2.Periods;
   rsiPeriods   = RSI.Periods;
   maxValues    = ifInt(Max.Values==-1, INT_MAX, Max.Values);

   // buffer management
   SetIndexBuffer(MODE_RSI,       bufferRsi  );          // RSI value:            invisible
   SetIndexBuffer(MODE_STOCH_RAW, bufferStoch);          // Stochastic raw value: invisible
   SetIndexBuffer(MODE_STOCH_MA1, bufferMa1  );          // first MA(Stoch):      visible
   SetIndexBuffer(MODE_STOCH_MA2, bufferMa2  );          // second MA(MA1):       visible, displayed in "Data" window

   // names, labels and display options
   string sStochMa1Periods = ifString(stochPeriods==1, "", ", "+ ma1Periods);
   string sStochMa2Periods = ifString(ma2Periods==1, "", ", "+ ma2Periods);
   string indicatorName    = "Stochastic(RSI("+ rsiPeriods +"), "+ stochPeriods + sStochMa1Periods + sStochMa2Periods +")";

   IndicatorShortName(indicatorName +"    ");            // indicator subwindow and context menu
   SetIndexLabel(MODE_RSI,       NULL);
   SetIndexLabel(MODE_STOCH_RAW, NULL);
   SetIndexLabel(MODE_STOCH_MA1, NULL);
   SetIndexLabel(MODE_STOCH_MA2, "Stoch(RSI) signal");   // "Data" window and tooltips
   IndicatorDigits(2);
   SetIndicatorOptions();

   return(catch("onInit(6)"));
}


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   // a not initialized buffer can happen on terminal start under specific circumstances
   if (!ArraySize(bufferRsi)) return(log("onTick(1)  size(bufferRsi) = 0", SetLastError(ERS_TERMINAL_NOT_YET_READY)));

   // reset all buffers and delete garbage behind Max.Values before doing a full recalculation
   if (!UnchangedBars) {
      ArrayInitialize(bufferRsi,   EMPTY_VALUE);
      ArrayInitialize(bufferStoch, EMPTY_VALUE);
      ArrayInitialize(bufferMa1,   EMPTY_VALUE);
      ArrayInitialize(bufferMa2,   EMPTY_VALUE);
      SetIndicatorOptions();
   }

   // synchronize buffers with a shifted offline chart
   if (ShiftedBars > 0) {
      ShiftIndicatorBuffer(bufferRsi,   Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(bufferStoch, Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(bufferMa1,   Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(bufferMa2,   Bars, ShiftedBars, EMPTY_VALUE);
   }

   // +------------------------------------------------------+----------------------------------------------------+
   // | Top down                                             | Bottom up                                          |
   // +------------------------------------------------------+----------------------------------------------------+
   // | RequestedBars   = 5000                               | ResultingBars   = startBar(MA2) + 1                |
   // | startBar(MA2)   = RequestedBars - 1                  | startBar(MA2)   = startBar(MA1)   - ma2Periods + 1 |
   // | startBar(MA1)   = startBar(MA2)   + ma2Periods   - 1 | startBar(MA1)   = startBar(Stoch) - ma1Periods + 1 |
   // | startBar(Stoch) = startBar(MA1)   + ma1Periods   - 1 | startBar(Stoch) = startBar(RSI) - stochPeriods + 1 |
   // | startBar(RSI)   = startBar(Stoch) + stochPeriods - 1 | startBar(RSI)   = oldestBar - 5 - rsiPeriods   + 1 | RSI requires at least 5 more bars to initialize the integrated EMA.
   // | firstBar        = startBar(RSI) + rsiPeriods + 5 - 1 | oldestBar       = AvailableBars - 1                |
   // | RequiredBars    = firstBar + 1                       | AvailableBars   = Bars                             |
   // +------------------------------------------------------+----------------------------------------------------+
   // |                 --->                                                ---^                                  |
   // +-----------------------------------------------------------------------------------------------------------+

   // calculate start bars
   int requestedBars = Min(ChangedBars, maxValues);
   int maxBars = Bars - rsiPeriods - stochPeriods - ma1Periods - ma2Periods - 1;    // max. possible resulting bars
   if (maxBars < 1) return(catch("onTick(2)", ERR_HISTORY_INSUFFICIENT));

   int bars          = Min(requestedBars, maxBars);                                 // actual bars to be updated
   int ma2StartBar   = bars - 1;
   int ma1StartBar   = ma2StartBar + ma2Periods - 1;
   int stochStartBar = ma1StartBar + ma1Periods - 1;
   int rsiStartBar   = stochStartBar + stochPeriods - 1;

   // recalculate changed bars
   for (int i=rsiStartBar; i >= 0; i--) {
      bufferRsi[i] = iRSI(NULL, NULL, rsiPeriods, PRICE_CLOSE, i);
   }

   for (i=stochStartBar; i >= 0; i--) {
      double rsi     = bufferRsi[i];
      double rsiHigh = rsi;
      double rsiLow  = rsi;

      for (int n=0; n < stochPeriods; n++) {
         if (bufferRsi[i+n] > rsiHigh) rsiHigh = bufferRsi[i+n];
         if (bufferRsi[i+n] < rsiLow)  rsiLow  = bufferRsi[i+n];
      }
      bufferStoch[i] = MathDiv(rsi-rsiLow, rsiHigh-rsiLow, 0.5) * 100;  // raw Stochastic
   }

   for (i=ma1StartBar; i >= 0; i--) {
      bufferMa1[i] = iMAOnArray(bufferStoch, WHOLE_ARRAY, ma1Periods, 0, MODE_SMA, i);
   }

   for (i=ma2StartBar; i >= 0; i--) {
      bufferMa2[i] = iMAOnArray(bufferMa1, WHOLE_ARRAY, ma2Periods, 0, MODE_SMA, i);
   }

   return(catch("onTick(3)"));
}


/**
 * Workaround for various terminal bugs when setting indicator options. Usually options are set in init(). However after
 * recompilation options must be set in start() to not get ignored.
 */
void SetIndicatorOptions() {
   IndicatorBuffers(allocated_buffers);
   //SetIndexStyle(int buffer, int drawType, int lineStyle=EMPTY, int drawWidth=EMPTY, color drawColor=NULL)

   SetIndexStyle(MODE_STOCH_MA1, DRAW_NONE, EMPTY,       EMPTY);
   SetIndexStyle(MODE_STOCH_MA2, DRAW_LINE, STYLE_SOLID, EMPTY); SetIndexArrow(MODE_STOCH_MA2, 159);
}


/**
 * Return a string representation of the input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("Stochastic.Periods=",     Stochastic.Periods,     ";"+ NL,
                            "Stochastic.MA1.Periods=", Stochastic.MA1.Periods, ";"+ NL,
                            "Stochastic.MA2.Periods=", Stochastic.MA2.Periods, ";"+ NL,
                            "RSI.Periods=",            RSI.Periods,            ";"+ NL,
                            "Max.Values=",             Max.Values,             ";"+ NL)
   );
}
