/**
 * Stochastic Oscillator (was FX Turbo Marksman)
 *
 *
 * The Stochastic oscillator shows the relative position of current price compared to the price range of the lookback period,
 * normalized to a value from 0 to 100. The fast Stochastic is smoothed once, the slow Stochastic is smoothed twice.
 *
 * Indicator buffers for iCustom():
 *  • MODE_MAIN:   indicator main line (%K or slowed %K)
 *  • MODE_SIGNAL: indicator signal line (%D)
 */
#include <stddefines.mqh>
int   __InitFlags[];
int __DeinitFlags[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern int    StochMain.Periods     = 14;                // %K line                                                        // EURJPY: 15
extern int    SlowedMain.MA.Periods = 3;                 // slowed %K line (MA)                                            //         1
extern int    Signal.MA.Periods     = 3;                 // %D line (MA of resulting %K)                                   //         1
                                                                                                                           //
extern int    SignalLevel.Long      = 70;                // signal level to cross upwards to trigger a long signal         //         73
extern int    SignalLevel.Short     = 30;                // signal level to cross downwards to trigger a short signal      //         27

extern color  Main.Color            = DodgerBlue;
extern color  Signal.Color          = Red;

extern int    Max.Bars              = 10000;             // max. number of values to calculate (-1: all available)

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <rsfLibs.mqh>

#define MODE_MAIN             Stochastic.MODE_MAIN       // 0 indicator buffer ids
#define MODE_SIGNAL           Stochastic.MODE_SIGNAL     // 1
#define MODE_TREND            Stochastic.MODE_TREND      // 2

#define PRICERANGE_HIGHLOW    0                          // use all bar prices for range calculation
#define PRICERANGE_CLOSE      1                          // use close prices for range calculation

#property indicator_separate_window
#property indicator_buffers   3                          // buffers visible in input dialog
int       terminal_buffers  = 3;                         // buffers managed by the terminal

#property indicator_color1    CLR_NONE
#property indicator_color2    CLR_NONE
#property indicator_color3    CLR_NONE

#property indicator_minimum   0
#property indicator_maximum   100

double main  [];                                         // (slowed) %K line: visible
double signal[];                                         // %D line:          visible
double trend [];                                         // trend direction:  invisible, displayed in "Data" window

int stochPeriods;
int ma1Periods;
int ma2Periods;

int levelLong;
int levelShort;

int maxValues;


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   // validate inputs
   if (StochMain.Periods < 2)                            return(catch("onInit(1)  Invalid input parameter StochMain.Periods: "+ StochMain.Periods +" (min. 2)", ERR_INVALID_INPUT_PARAMETER));
   if (SlowedMain.MA.Periods < 0)                        return(catch("onInit(2)  Invalid input parameter SlowedMain.MA.Periods: "+ SlowedMain.MA.Periods, ERR_INVALID_INPUT_PARAMETER));
   if (Signal.MA.Periods < 0)                            return(catch("onInit(3)  Invalid input parameter Signal.MA.Periods: "+ Signal.MA.Periods, ERR_INVALID_INPUT_PARAMETER));
   stochPeriods = StochMain.Periods;
   ma1Periods   = ifInt(!SlowedMain.MA.Periods, 1, SlowedMain.MA.Periods);
   ma2Periods   = ifInt(!Signal.MA.Periods, 1, Signal.MA.Periods);
   // levels
   if (SignalLevel.Long  < 0 || SignalLevel.Long  > 100) return(catch("onInit(4)  Invalid input parameter SignalLevel.Long: "+ SignalLevel.Long +" (from 0..100)", ERR_INVALID_INPUT_PARAMETER));
   if (SignalLevel.Short < 0 || SignalLevel.Short > 100) return(catch("onInit(5)  Invalid input parameter SignalLevel.Short: "+ SignalLevel.Short +" (from 0..100)", ERR_INVALID_INPUT_PARAMETER));
   levelLong  = SignalLevel.Long;
   levelShort = SignalLevel.Short;
   // colors: after deserialization the terminal might turn CLR_NONE (0xFFFFFFFF) into Black (0xFF000000)
   if (Main.Color   == 0xFF000000) Main.Color   = CLR_NONE;
   if (Signal.Color == 0xFF000000) Signal.Color = CLR_NONE;
   // Max.Bars
   if (Max.Bars < -1)                                    return(catch("onInit(6)  Invalid input parameter Max.Bars: "+ Max.Bars, ERR_INVALID_INPUT_PARAMETER));
   maxValues = ifInt(Max.Bars==-1, INT_MAX, Max.Bars);

   // buffer management
   SetIndexBuffer(MODE_MAIN,   main);                    // (slowed) %K line: visible
   SetIndexBuffer(MODE_SIGNAL, signal);                  // %D line:          visible
   SetIndexBuffer(MODE_TREND,  trend);                   // trend direction:  invisible, displayed in "Data" window

   // names, labels and display options
   string sName=ifString(ma1Periods > 1, "SlowStochastic", "FastStochastic"), sMa1Periods="", sMa2Periods="";
   if (ma1Periods > 1) sMa1Periods = "-"+ ma1Periods;
   if (ma2Periods > 1) sMa2Periods = ", "+ ma2Periods;
   string indicatorName  = sName +"("+ stochPeriods + sMa1Periods + sMa2Periods +")";

   IndicatorShortName(indicatorName +"  ");              // chart subwindow and context menu
   SetIndexLabel(MODE_MAIN,   "StochMain");   if (Main.Color  ==CLR_NONE) SetIndexLabel(MODE_MAIN,   NULL);
   SetIndexLabel(MODE_SIGNAL, "StochSignal"); if (Signal.Color==CLR_NONE) SetIndexLabel(MODE_SIGNAL, NULL);
   SetIndexLabel(MODE_TREND,  "StochTrend");

   SetIndexEmptyValue(MODE_TREND, 0);
   IndicatorDigits(2);
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
   if (!ArraySize(main)) return(logInfo("onTick(1)  size(main) = 0", SetLastError(ERS_TERMINAL_NOT_YET_READY)));

   // reset all buffers and delete garbage behind Max.Bars before doing a full recalculation
   if (!UnchangedBars) {
      ArrayInitialize(main,   EMPTY_VALUE);
      ArrayInitialize(signal, EMPTY_VALUE);
      ArrayInitialize(trend,  0);
      SetIndicatorOptions();
   }

   // synchronize buffers with a shifted offline chart
   if (ShiftedBars > 0) {
      ShiftIndicatorBuffer(main,   Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(signal, Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(trend,  Bars, ShiftedBars, 0);
   }

   // calculate start bar
   // +------------------------------------------------------+----------------------------------------------------+
   // | Top down                                             | Bottom up                                          |
   // +------------------------------------------------------+----------------------------------------------------+
   // | RequestedBars   = 5000                               | ResultingBars   = startBar(MA2) + 1                |
   // | startBar(MA2)   = RequestedBars - 1                  | startBar(MA2)   = startBar(MA1)   - ma2Periods + 1 |
   // | startBar(MA1)   = startBar(MA2)   + ma2Periods   - 1 | startBar(MA1)   = startBar(Stoch) - ma1Periods + 1 |
   // | startBar(Stoch) = startBar(MA1)   + ma1Periods   - 1 | startBar(Stoch) = oldestBar - stochPeriods + 1     |
   // | firstBar        = startBar(Stoch) + stochPeriods - 1 | oldestBar       = AvailableBars - 1                |
   // | RequiredBars    = firstBar + 1                       | AvailableBars   = Bars                             |
   // +------------------------------------------------------+----------------------------------------------------+
   // |                 --->                                                ---^                                  |
   // +-----------------------------------------------------------------------------------------------------------+
   int requestedBars = Min(ChangedBars, maxValues);
   int resultingBars = Bars - stochPeriods - ma1Periods - ma2Periods + 3;  // max. resulting bars

   int bars          = Min(requestedBars, resultingBars);                  // actual number of bars to be updated
   int ma2StartBar   = bars - 1;
   int ma1StartBar   = ma2StartBar + ma2Periods - 1;
   int stochStartBar = ma1StartBar + ma1Periods - 1;

   // recalculate changed bars
   for (int bar=stochStartBar; bar >= 0; bar--) {
      main  [bar] = iStochastic(NULL, NULL, stochPeriods, ma2Periods, ma1Periods, MODE_SMA, PRICERANGE_HIGHLOW, MODE_MAIN, bar);
      signal[bar] = iStochastic(NULL, NULL, stochPeriods, ma2Periods, ma1Periods, MODE_SMA, PRICERANGE_HIGHLOW, MODE_SIGNAL, bar);

      UpdateTrend(signal, trend, bar);
   }

   return(catch("onTick(2)"));
}


/**
 * Update the buffer for the trend signals generated by the signal line crossing the configured indicator levels.
 *
 * @param  _In_  double signal[] - signal buffer
 * @param  _Out_ double trend[]  - trend buffer: -n...-1 ... +1...+n
 * @param  _In_  int    bar      - bar offset to update
 *
 * @return bool - success status
 */
bool UpdateTrend(double signal[], double &trend[], int bar) {
   if (bar >= Bars-1) {
      if (bar >= Bars) return(!catch("UpdateTrend(1)  illegal parameter bar: "+ bar, ERR_INVALID_PARAMETER));
      trend[bar] = 0;
      return(true);
   }

   int    prevTrend = trend[bar+1];
   double curValue  = signal[bar];
   double prevValue = signal[bar+1];

   if (prevTrend > 0) {
      // existing long trend
      if (curValue <= levelShort) trend[bar] = -1;                            // trend change short
      else                        trend[bar] = prevTrend + Sign(prevTrend);   // trend continuation
   }
   else if (prevTrend < 0) {
      // existing short trend
      if (curValue >= levelLong) trend[bar] = +1;                             // trend change long
      else                       trend[bar] = prevTrend + Sign(prevTrend);    // trend continuation
   }
   else {
      // no trend yet
      trend[bar] =  0;

      if (curValue >= levelLong) {
         for (int i=bar+1; i < Bars; i++) {
            if (signal[i] == EMPTY_VALUE) break;
            if (signal[i] <= levelShort) {                                    // look for a previous down cross
               trend[bar] = +1;                                               // found: first trend long
               break;
            }
         }
      }
      else if (curValue <= levelShort) {
         for (i=bar+1; i < Bars; i++) {
            if (signal[i] == EMPTY_VALUE) break;
            if (signal[i] >= levelLong) {                                     // look for a previous up cross
               trend[bar] = -1;                                               // found: first trend short
               break;
            }
         }
      }
   }
   return(true);
}


/**
 * Workaround for various terminal bugs when setting indicator options. Usually options are set in init(). However after
 * recompilation options must be set in start() to not be ignored.
 */
void SetIndicatorOptions() {
   IndicatorBuffers(terminal_buffers);

   int signalType = ifInt(Signal.Color==CLR_NONE, DRAW_NONE, DRAW_LINE);

   SetIndexStyle(MODE_MAIN,   DRAW_LINE,  EMPTY, EMPTY, Main.Color);
   SetIndexStyle(MODE_SIGNAL, signalType, EMPTY, EMPTY, Signal.Color);
   SetIndexStyle(MODE_TREND,  DRAW_NONE,  EMPTY, EMPTY, CLR_NONE);

   SetLevelValue(0, levelLong);
   SetLevelValue(1, levelShort);
}


/**
 * Return a string representation of the input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("StochMain.Periods=",     StochMain.Periods,        ";"+ NL,
                            "SlowedMain.MA.Periods=", SlowedMain.MA.Periods,    ";"+ NL,
                            "Signal.MA.Periods=",     Signal.MA.Periods,        ";"+ NL,
                            "SignalLevel.Long=",      SignalLevel.Long,         ";"+ NL,
                            "SignalLevel.Short=",     SignalLevel.Short,        ";"+ NL,
                            "Main.Color=",            ColorToStr(Main.Color),   ";"+ NL,
                            "Signal.Color=",          ColorToStr(Signal.Color), ";"+ NL,
                            "Max.Bars=",              Max.Bars,                 ";")
   );
}
