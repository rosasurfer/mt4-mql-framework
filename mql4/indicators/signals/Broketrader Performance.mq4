/**
 * Broketrader Performance
 *
 * Displays the performance of a Broketrader signal.
 *
 * @see  https://www.forexfactory.com/showthread.php?t=970975
 */
#include <stddefines.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern int   SMA.Periods            = 96;
extern int   Stochastic.Periods     = 96;
extern int   Stochastic.MA1.Periods = 10;
extern int   Stochastic.MA2.Periods = 6;
extern int   RSI.Periods            = 96;

extern int   Max.Values             = 10000;             //  max. amount of values to calculate (-1: all)

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <rsfLibs.mqh>

#define MODE_MAIN             0                          // indicator buffer ids

#property indicator_separate_window

#property indicator_buffers   1
#property indicator_color1    CLR_NONE
#property indicator_level1    0

double main[];                                           // PL line: visible

int smaPeriods;
int stochPeriods;
int stochMa1Periods;
int stochMa2Periods;
int rsiPeriods;

int maxValues;


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   // validate inputs
   if (SMA.Periods < 1)            return(catch("onInit(1)  Invalid input parameter SMA.Periods: "+ SMA.Periods, ERR_INVALID_INPUT_PARAMETER));
   if (Stochastic.Periods < 2)     return(catch("onInit(2)  Invalid input parameter Stochastic.Periods: "+ Stochastic.Periods +" (min. 2)", ERR_INVALID_INPUT_PARAMETER));
   if (Stochastic.MA1.Periods < 1) return(catch("onInit(3)  Invalid input parameter Stochastic.MA1.Periods: "+ Stochastic.MA1.Periods, ERR_INVALID_INPUT_PARAMETER));
   if (Stochastic.MA2.Periods < 1) return(catch("onInit(4)  Invalid input parameter Stochastic.MA2.Periods: "+ Stochastic.MA2.Periods, ERR_INVALID_INPUT_PARAMETER));
   if (RSI.Periods < 2)            return(catch("onInit(5)  Invalid input parameter RSI.Periods: "+ RSI.Periods +" (min. 2)", ERR_INVALID_INPUT_PARAMETER));
   smaPeriods      = SMA.Periods;
   stochPeriods    = Stochastic.Periods;
   stochMa1Periods = Stochastic.MA1.Periods;
   stochMa2Periods = Stochastic.MA2.Periods;
   rsiPeriods      = RSI.Periods;

   // Max.Values
   if (Max.Values < -1)            return(catch("onInit(6)  Invalid input parameter Max.Values: "+ Max.Values, ERR_INVALID_INPUT_PARAMETER));
   maxValues = ifInt(Max.Values==-1, INT_MAX, Max.Values);

   // buffer management
   SetIndexBuffer(MODE_MAIN, main);                      // PL line: visible

   // names, labels and display options
   IndicatorShortName("Broketrader performance   ");     // indicator subwindow and context menu
   SetIndexLabel(MODE_MAIN, "Broketrader perf.");        // "Data" window and tooltips
   IndicatorDigits(1);
   SetIndicatorOptions();

   return(catch("onInit(7)"));
}


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   // a not initialized buffer can happen on terminal start under specific circumstances
   if (!ArraySize(main)) return(log("onTick(1)  size(main) = 0", SetLastError(ERS_TERMINAL_NOT_YET_READY)));

   // reset all buffers and delete garbage behind Max.Values before doing a full recalculation
   if (!UnchangedBars) {
      ArrayInitialize(main, EMPTY_VALUE);
      SetIndicatorOptions();
   }

   // synchronize buffers with a shifted offline chart
   if (ShiftedBars > 0) {
      ShiftIndicatorBuffer(main, Bars, ShiftedBars, EMPTY_VALUE);
   }

   // calculate start bar
   int maxSMAValues   = Bars - smaPeriods + 1;                                                     // max. possible SMA values
   int maxStochValues = Bars - rsiPeriods - stochPeriods - stochMa1Periods - stochMa2Periods - 1;  // max. possible Stochastic values
   int requestedBars  = Min(ChangedBars, maxValues);
   int bars           = Min(requestedBars, Min(maxSMAValues, maxStochValues));                     // actual number of bars to be updated
   int startBar       = bars - 1;
   if (startBar < 0) return(catch("onTick(2)", ERR_HISTORY_INSUFFICIENT));

   double open, close, pl, lastPl;

   // recalculate changed bars
   for (int i=startBar; i >= 0; i--) {
      int position = GetBroketraderPosition(i); if (last_error || 0) return(last_error);

      if (position > 0) {                 // long
         lastPl = main[i+position]; if (lastPl == EMPTY_VALUE) lastPl = 0;
         open   = Open[i+position-1];
         close  = Close[i];
         pl     = (close - open) / Pip;   // PL of the current position
      }
      else if (position < 0) {            // short
         lastPl = main[i-position]; if (lastPl == EMPTY_VALUE) lastPl = 0;
         open   = Open[i-position-1];
         close  = Close[i];
         pl     = (open - close) / Pip;   // PL of the current position
      }
      else {
         lastPl = 0;
         pl     = 0;
      }
      main[i] = lastPl + pl;
   }
   return(catch("onTick(3)"));
}


/**
 * Return a Broketrader position value.
 *
 * @param  int iBar - bar index of the value to return
 *
 * @return int - position value or NULL in case of errors
 */
int GetBroketraderPosition(int iBar) {
   return(iBroketrader(NULL, smaPeriods, stochPeriods, stochMa1Periods, stochMa2Periods, rsiPeriods, Broketrader.MODE_POSITION, iBar));
}


/**
 * Load the "Broketrader Signal" indicator and return a value.
 *
 * @param  int timeframe            - timeframe to load the indicator (NULL: the current timeframe)
 * @param  int smaPeriods           - indicator parameter
 * @param  int stochasticPeriods    - indicator parameter
 * @param  int stochasticMa1Periods - indicator parameter
 * @param  int stochasticMa2Periods - indicator parameter
 * @param  int rsiPeriods           - indicator parameter
 * @param  int iBuffer              - indicator buffer index of the value to return
 * @param  int iBar                 - bar index of the value to return
 *
 * @return double - indicator value or NULL in case of errors
 */
double iBroketrader(int timeframe, int smaPeriods, int stochasticPeriods, int stochasticMa1Periods, int stochasticMa2Periods, int rsiPeriods, int iBuffer, int iBar) {
   static int lpSuperContext = 0; if (!lpSuperContext)
      lpSuperContext = GetIntsAddress(__ExecutionContext);

   double value = iCustom(NULL, timeframe, "signals/Broketrader Signal",
                          smaPeriods,                                      // int    SMA.Periods
                          stochasticPeriods,                               // int    Stochastic.Periods
                          stochasticMa1Periods,                            // int    Stochastic.MA1.Periods
                          stochasticMa2Periods,                            // int    Stochastic.MA2.Periods
                          rsiPeriods,                                      // int    RSI.Periods
                          CLR_NONE,                                        // color  Color.Long
                          CLR_NONE,                                        // color  Color.Short
                          false,                                           // bool   FillSections
                          1,                                               // int    SMA.DrawWidth
                          -1,                                              // int    Max.Values
                          "",                                              // string ______________________
                          lpSuperContext,                                  // int    __SuperContext__

                          iBuffer, iBar);

   int error = GetLastError();
   if (error != NO_ERROR) {
      if (error != ERS_HISTORY_UPDATE)
         return(!catch("iBroketrader(1)", error));
      warn("iBroketrader(2)  "+ PeriodDescription(ifInt(!timeframe, Period(), timeframe)) +" (tick="+ Tick +")", ERS_HISTORY_UPDATE);
   }

   error = __ExecutionContext[EC.mqlError];                                // TODO: synchronize execution contexts
   if (!error)
      return(value);
   return(!SetLastError(error));
}


/**
 * Workaround for various terminal bugs when setting indicator options. Usually options are set in init(). However after
 * recompilation options must be set in start() to not get ignored.
 */
void SetIndicatorOptions() {
   IndicatorBuffers(indicator_buffers);

   SetIndexStyle(MODE_MAIN, DRAW_LINE, EMPTY, EMPTY, Blue);
}


/**
 * Return a string representation of the input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("SMA.Periods=",            SMA.Periods,            ";", NL,
                            "Stochastic.Periods=",     Stochastic.Periods,     ";", NL,
                            "Stochastic.MA1.Periods=", Stochastic.MA1.Periods, ";", NL,
                            "Stochastic.MA2.Periods=", Stochastic.MA2.Periods, ";", NL,
                            "RSI.Periods=",            RSI.Periods,            ";", NL,
                            "Max.Values=",             Max.Values,             ";")
   );
}
