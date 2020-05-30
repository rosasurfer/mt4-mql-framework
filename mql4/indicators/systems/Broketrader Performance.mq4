/**
 * Broketrader Performance
 *
 * Visualizes the performance of the Broketrader system.
 *
 * @see  https://www.forexfactory.com/showthread.php?t=970975
 */
#include <stddefines.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern int    SMA.Periods            = 96;
extern int    Stochastic.Periods     = 96;
extern int    Stochastic.MA1.Periods = 10;
extern int    Stochastic.MA2.Periods = 6;
extern int    RSI.Periods            = 96;

extern string MTF                    = "M1 | M5 | M15 | ... | current*";   // timeframe to display (empty: current)
extern int    Max.Values             = 10000;                              //  max. amount of current bars to display (-1: all)

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <rsfLibs.mqh>

#define MODE_OPEN             0                          // indicator buffer ids
#define MODE_CLOSED           1
#define MODE_TOTAL            2

#property indicator_separate_window
#property indicator_buffers   3

#property indicator_color1    CLR_NONE
#property indicator_color2    CLR_NONE
#property indicator_color3    Blue

#property indicator_level1    0

double bufferOpenPL  [];                                 // open PL:   invisible
double bufferClosedPL[];                                 // closed PL: invisible
double bufferTotalPL [];                                 // total PL:  visible

int smaPeriods;
int stochPeriods;
int stochMa1Periods;
int stochMa2Periods;
int rsiPeriods;

int currentTimeframe;
int targetTimeframe;
int maxValues;


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   // validate inputs
   // std. indicator parameters
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
   // MTF
   string sValues[], sValue = MTF;
   if (Explode(sValue, "*", sValues, 2) > 1) {
      int size = Explode(sValues[0], "|", sValues, NULL);
      sValue = sValues[size-1];
   }
   sValue = StrTrim(sValue);
   if (sValue=="" || sValue=="current") {                      // default target timeframe
      targetTimeframe = Period();
      MTF = "current";
   }
   else {
      targetTimeframe = StrToPeriod(sValue, F_ERR_INVALID_PARAMETER);
      if (targetTimeframe == -1)   return(catch("onInit(6)  Invalid input parameter MTF: "+ DoubleQuoteStr(MTF), ERR_INVALID_INPUT_PARAMETER));
      MTF = PeriodDescription(targetTimeframe);
   }
   currentTimeframe = Period();
   // Max.Values
   if (Max.Values < -1)            return(catch("onInit(7)  Invalid input parameter Max.Values: "+ Max.Values, ERR_INVALID_INPUT_PARAMETER));
   maxValues = ifInt(Max.Values==-1, INT_MAX, Max.Values);

   // buffer management
   SetIndexBuffer(MODE_OPEN,   bufferOpenPL  );                // open PL:   invisible
   SetIndexBuffer(MODE_CLOSED, bufferClosedPL);                // closed PL: invisible
   SetIndexBuffer(MODE_TOTAL,  bufferTotalPL );                // total PL:  visible

   // names, labels and display options
   //IndicatorShortName("Broketrader performance  ");          // indicator subwindow and context menu
   IndicatorShortName("Broketrader open/closed/total PL  ");
   SetIndexLabel(MODE_OPEN,   "Broketrader open PL"  );        // "Data" window
   SetIndexLabel(MODE_CLOSED, "Broketrader closed PL");
   SetIndexLabel(MODE_TOTAL,  "Broketrader total PL" );
   IndicatorDigits(1);
   SetIndicatorOptions();

   return(catch("onInit(8)"));
}


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   // a not initialized buffer can happen on terminal start under specific circumstances
   if (!ArraySize(bufferTotalPL)) return(log("onTick(1)  size(bufferTotalPL) = 0", SetLastError(ERS_TERMINAL_NOT_YET_READY)));

   // reset all buffers and delete garbage behind Max.Values before doing a full recalculation
   if (!UnchangedBars) {
      ArrayInitialize(bufferOpenPL,   EMPTY_VALUE);
      ArrayInitialize(bufferClosedPL, EMPTY_VALUE);
      ArrayInitialize(bufferTotalPL,  EMPTY_VALUE);
      SetIndicatorOptions();
   }

   // synchronize buffers with a shifted offline chart
   if (ShiftedBars > 0) {
      ShiftIndicatorBuffer(bufferOpenPL,   Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(bufferClosedPL, Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(bufferTotalPL,  Bars, ShiftedBars, EMPTY_VALUE);
   }

   // process MTF condition
   if (targetTimeframe != currentTimeframe)
      return(onMTF());

   // calculate start bar
   int maxSMAValues   = Bars - smaPeriods + 1;                                                     // max. possible SMA values
   int maxStochValues = Bars - rsiPeriods - stochPeriods - stochMa1Periods - stochMa2Periods - 1;  // max. possible Stochastic values
   int requestedBars  = Min(ChangedBars, maxValues);
   int bars           = Min(requestedBars, Min(maxSMAValues, maxStochValues));                     // actual number of bars to be updated
   int startBar       = bars - 1;
   if (startBar < 0) return(catch("onTick(2)", ERR_HISTORY_INSUFFICIENT));

   double open, close, openPL=EMPTY_VALUE, closedPL=bufferClosedPL[startBar+1];

   // recalculate changed bars
   for (int i=startBar; i >= 0; i--) {
      int openPosition = GetBroketraderPosition(i); if (last_error != 0) return(last_error);

      if (openPosition > 0) {                                           // long
         if (openPosition == 1) {                                       // start or continue trading
            openPL = GetOpenPL(openPosition, i);
            if (closedPL == EMPTY_VALUE) closedPL  = 0;
            else                         closedPL += GetClosedPL(i);
         }
         else if (closedPL != EMPTY_VALUE) {                            // continue only if trading has started
            openPL = GetOpenPL(openPosition, i);
         }
      }

      else if (openPosition < 0) {                                      // short
         if (openPosition == -1) {                                      // start or continue trading
            openPL = GetOpenPL(openPosition, i);
            if (closedPL == EMPTY_VALUE) closedPL  = 0;
            else                         closedPL += GetClosedPL(i);
         }
         else if (closedPL != EMPTY_VALUE) {                            // continue only if trading has started
            openPL = GetOpenPL(openPosition, i);
         }
      }
      else if (closedPL != EMPTY_VALUE) {                               // no position but trading has started
         openPL = 0;
      }

      bufferOpenPL  [i]                              = openPL;
      bufferClosedPL[i]                              = closedPL;
      if (closedPL == EMPTY_VALUE) bufferTotalPL [i] = EMPTY_VALUE;     // trading hasn't yet started
      else                         bufferTotalPL [i] = closedPL + openPL;
   }
   return(catch("onTick(3)"));
}


/**
 * Compute the PL of an open position at the specified bar.
 *
 * @param  int position - direction and duration of the position
 * @param  int bar      - bar index of the position
 *
 * @return double - PL in pip
 */
double GetOpenPL(int position, int bar) {
   double open, close;

   if (position > 0) {                 // long
      open  = Open[bar+position-1];
      close = Close[bar];
      return((close-open) / Pip);
   }
   if (position < 0) {                 // short
      open  = Open[bar-position-1];
      close = Close[bar];
      return((open-close) / Pip);
   }
   return(0);
}


/**
 * Compute the PL of a position closed at the Open of the specified bar.
 *
 * @param  int bar - bar index of the position
 *
 * @return double - PL in pip
 */
double GetClosedPL(int bar) {
   double open, close;
   int position = GetBroketraderPosition(bar+1);

   if (position > 0) {                 // long
      open  = Open[bar+position];
      close = Open[bar];
      return((close-open) / Pip);
   }
   if (position < 0) {                 // short
      open  = Open[bar-position];
      close = Open[bar];
      return((open-close) / Pip);
   }
   return(0);
}


/**
 * Return a Broketrader position value.
 *
 * @param  int iBar - bar index of the value to return
 *
 * @return int - position value or NULL in case of errors
 */
int GetBroketraderPosition(int iBar) {
   return(iBroketrader(NULL, smaPeriods, stochPeriods, stochMa1Periods, stochMa2Periods, rsiPeriods, Broketrader.MODE_TREND, iBar));
}


/**
 * Load the "Broketrader" indicator and return a value.
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

   double value = iCustom(NULL, timeframe, "systems/Broketrader",
                          smaPeriods,                             // int    SMA.Periods
                          stochasticPeriods,                      // int    Stochastic.Periods
                          stochasticMa1Periods,                   // int    Stochastic.MA1.Periods
                          stochasticMa2Periods,                   // int    Stochastic.MA2.Periods
                          rsiPeriods,                             // int    RSI.Periods
                          CLR_NONE,                               // color  Color.Long
                          CLR_NONE,                               // color  Color.Short
                          false,                                  // bool   FillSections
                          1,                                      // int    SMA.DrawWidth
                          -1,                                     // int    Max.Values                // all values to prevent MTF issues
                          "",                                     // string ____________________
                          "off",                                  // string Signal.onReversal
                          "off",                                  // string Signal.Sound
                          "off",                                  // string Signal.Mail.Receiver
                          "off",                                  // string Signal.SMS.Receiver
                          "",                                     // string ____________________
                          lpSuperContext,                         // int    __SuperContext__

                          iBuffer, iBar);

   int error = GetLastError();
   if (error != NO_ERROR) {
      if (error != ERS_HISTORY_UPDATE)
         return(!catch("iBroketrader(1)", error));
      warn("iBroketrader(2)  "+ PeriodDescription(ifInt(!timeframe, Period(), timeframe)) +" (tick="+ Tick +")", ERS_HISTORY_UPDATE);
   }

   error = __ExecutionContext[EC.mqlError];                       // TODO: synchronize execution contexts
   if (!error)
      return(value);
   return(!SetLastError(error));
}


/**
 * MTF main function
 *
 * @return int - error status
 */
int onMTF() {
   return(catch("onMTF(1)"));
}


/**
 * Workaround for various terminal bugs when setting indicator options. Usually options are set in init(). However after
 * recompilation options must be set in start() to not get ignored.
 */
void SetIndicatorOptions() {
   //SetIndexStyle(int buffer, int drawType, int lineStyle=EMPTY, int drawWidth=EMPTY, color drawColor=NULL)

   SetIndexStyle(MODE_OPEN,   DRAW_NONE, STYLE_SOLID, 1, CLR_NONE);
   SetIndexStyle(MODE_CLOSED, DRAW_NONE, STYLE_SOLID, 1, CLR_NONE);
   SetIndexStyle(MODE_TOTAL,  DRAW_LINE, EMPTY,       EMPTY);
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
                            "MTF=",                    DoubleQuoteStr(MTF),    ";", NL,
                            "Max.Values=",             Max.Values,             ";")
   );
}
