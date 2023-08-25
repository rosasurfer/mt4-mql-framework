/**
 * Broketrader Performance
 *
 * Visualizes the PL performance of the Broketrader system.
 *
 * @see   mql4/indicators/systems/Broketrader.mq4
 * @link  https://www.forexfactory.com/showthread.php?t=970975
 */
#include <stddefines.mqh>
int   __InitFlags[];
int __DeinitFlags[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern int    SMA.Periods            = 96;                  // Broketrader configuration
extern int    Stochastic.Periods     = 96;                  //
extern int    Stochastic.MA1.Periods = 10;                  //
extern int    Stochastic.MA2.Periods = 6;                   //
extern int    RSI.Periods            = 96;                  //
extern string ___a__________________________;               //

extern string Timeframe              = "H1";                // Broketrader timeframe
extern string StartDate              = "2019.01.01";        // Broketrader start date

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <rsfLib.mqh>
#include <functions/iBarShiftNext.mqh>
#include <functions/iBarShiftPrevious.mqh>
#include <functions/iChangedBars.mqh>
#include <functions/ParseDateTime.mqh>

#define MODE_OPEN            0                              // indicator buffer ids
#define MODE_CLOSED          1
#define MODE_TOTAL           2

#property indicator_separate_window
#property indicator_buffers  3

#property indicator_color1   CLR_NONE
#property indicator_color2   CLR_NONE
#property indicator_color3   Blue

#property indicator_level1   0

double   bufferOpenPL  [];                                  // open PL:   invisible
double   bufferClosedPL[];                                  // closed PL: invisible
double   bufferTotalPL [];                                  // total PL:  visible

int      smaPeriods;
int      stochPeriods;
int      stochMa1Periods;
int      stochMa2Periods;
int      rsiPeriods;

int      systemTimeframe;
datetime systemStartDate;


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   // validate inputs
   if (SMA.Periods < 1)            return(catch("onInit(1)  invalid input parameter SMA.Periods: "+ SMA.Periods, ERR_INVALID_INPUT_PARAMETER));
   if (Stochastic.Periods < 2)     return(catch("onInit(2)  invalid input parameter Stochastic.Periods: "+ Stochastic.Periods +" (min. 2)", ERR_INVALID_INPUT_PARAMETER));
   if (Stochastic.MA1.Periods < 1) return(catch("onInit(3)  invalid input parameter Stochastic.MA1.Periods: "+ Stochastic.MA1.Periods, ERR_INVALID_INPUT_PARAMETER));
   if (Stochastic.MA2.Periods < 1) return(catch("onInit(4)  invalid input parameter Stochastic.MA2.Periods: "+ Stochastic.MA2.Periods, ERR_INVALID_INPUT_PARAMETER));
   if (RSI.Periods < 2)            return(catch("onInit(5)  invalid input parameter RSI.Periods: "+ RSI.Periods +" (min. 2)", ERR_INVALID_INPUT_PARAMETER));
   smaPeriods      = SMA.Periods;
   stochPeriods    = Stochastic.Periods;
   stochMa1Periods = Stochastic.MA1.Periods;
   stochMa2Periods = Stochastic.MA2.Periods;
   rsiPeriods      = RSI.Periods;
   // Timeframe
   systemTimeframe = StrToTimeframe(Timeframe, F_ERR_INVALID_PARAMETER);
   if (systemTimeframe == -1)      return(catch("onInit(6)  invalid input parameter Timeframe: "+ DoubleQuoteStr(Timeframe), ERR_INVALID_INPUT_PARAMETER));
   Timeframe = TimeframeDescription(systemTimeframe);
   // StartDate
   int pt[];
   bool success = ParseDateTime(StartDate, DATE_YYYYMMDD|DATE_DDMMYYYY|TIME_OPTIONAL, pt);
   if (!success)                   return(catch("onInit(7)  invalid input parameter StartDate: "+ DoubleQuoteStr(StartDate), ERR_INVALID_INPUT_PARAMETER));
   systemStartDate = DateTime2(pt);

   // buffer management
   SetIndexBuffer(MODE_OPEN,   bufferOpenPL  );                               // open PL:   invisible
   SetIndexBuffer(MODE_CLOSED, bufferClosedPL);                               // closed PL: invisible
   SetIndexBuffer(MODE_TOTAL,  bufferTotalPL );                               // total PL:  visible

   // names, labels and display options
   IndicatorShortName("Broketrader("+ Timeframe +") open/closed/total PL  "); // chart subwindow and context menu
   SetIndexLabel(MODE_OPEN,   "Broketrader open PL"  );                       // chart tooltips and "Data" window
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
   // on the first tick after terminal start buffers may not yet be initialized (spurious issue)
   if (!ArraySize(bufferTotalPL)) return(logInfo("onTick(1)  sizeof(bufferTotalPL) = 0", SetLastError(ERS_TERMINAL_NOT_YET_READY)));

   // reset buffers before performing a full recalculation
   if (!ValidBars) {
      ArrayInitialize(bufferOpenPL,   EMPTY_VALUE);
      ArrayInitialize(bufferClosedPL, EMPTY_VALUE);
      ArrayInitialize(bufferTotalPL,  EMPTY_VALUE);
      SetIndicatorOptions();
   }

   // synchronize buffers with a shifted offline chart
   if (ShiftedBars > 0) {
      ShiftDoubleIndicatorBuffer(bufferOpenPL,   Bars, ShiftedBars, EMPTY_VALUE);
      ShiftDoubleIndicatorBuffer(bufferClosedPL, Bars, ShiftedBars, EMPTY_VALUE);
      ShiftDoubleIndicatorBuffer(bufferTotalPL,  Bars, ShiftedBars, EMPTY_VALUE);
   }

   // recalculate changed bars
   int changedBars = ComputeChangedBars(systemTimeframe);                  // changed bars considering two timeframes

   if (systemTimeframe == Period()) {
      // data timeframe == chart timeframe
      double openPL=EMPTY_VALUE, closedPL=EMPTY_VALUE;
      if (changedBars < Bars) closedPL = bufferClosedPL[changedBars];

      for (int i=changedBars-1; i >= 0; i--) {
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

         bufferOpenPL  [i] = openPL;
         bufferClosedPL[i] = closedPL;                                     // on EMPTY_VALUE trading hasn't yet started
         bufferTotalPL [i] = ifDouble(closedPL==EMPTY_VALUE, EMPTY_VALUE, closedPL + openPL);
      }
   }
   else {
      // data timeframe != chart timeframe
      int barLength = Period()*MINUTES - 1;

      for (i=changedBars-1; i >= 0; i--) {
         int offset = iBarShiftPrevious(NULL, systemTimeframe, Time[i]+barLength);
         bufferOpenPL  [i] = iMTF(MODE_OPEN,   offset); if (last_error != 0) return(last_error);
         bufferClosedPL[i] = iMTF(MODE_CLOSED, offset); if (last_error != 0) return(last_error);
         bufferTotalPL [i] = iMTF(MODE_TOTAL,  offset); if (last_error != 0) return(last_error);
      }
   }
   return(last_error);
}


/**
 * Compute the bars to update of the current timeframe when using data of the specified other timeframe.
 *
 * @param  int  timeframe      [optional] - data timeframe (default: the current timeframe)
 * @param  bool limitStartTime [optional] - whether to limit the result to a configured starttime (default: yes)
 *
 * @return int - changed bars or -1 in case of errors
 */
int ComputeChangedBars(int timeframe = NULL, bool limitStartTime = true) {
   int currentTimeframe = Period();
   if (!timeframe) timeframe = currentTimeframe;

   int changedBars, startbar;

   if (timeframe == currentTimeframe) {
      // the displayed timeframe equals the chart timeframe
      startbar = ChangedBars-1;
      if (Time[startbar]+currentTimeframe*MINUTES-1 < systemStartDate)
         startbar = iBarShiftNext(NULL, NULL, systemStartDate);
      changedBars = startbar + 1;
   }
   else {
      // the displayed timeframe is different from the chart timeframe
      // resolve startbar to update in the data timeframe
      changedBars = iChangedBars(NULL, timeframe);
      startbar    = changedBars-1;
      if (startbar < 0) return(_EMPTY(catch("ComputeChangedBars(1)  timeframe="+ TimeframeDescription(timeframe) +"  changedBars="+ changedBars +"  startbar="+ startbar, ERR_HISTORY_INSUFFICIENT)));

      // resolve corresponding bar offset in the current timeframe
      startbar = iBarShiftNext(NULL, NULL, iTime(NULL, timeframe, startbar));

      // cross-check the changed bars of the current timeframe against the data timeframe
      changedBars = Max(startbar+1, ComputeChangedBars(currentTimeframe, false));
      startbar    = changedBars - 1;
      if (Time[startbar]+currentTimeframe*MINUTES-1 < systemStartDate)
         startbar = iBarShiftNext(NULL, NULL, systemStartDate);
      changedBars = startbar + 1;
   }
   return(changedBars);
}


/**
 * Load the indicator again and return a value from another timeframe.
 *
 * @param  int iBuffer - indicator buffer index of the value to return
 * @param  int iBar    - bar index of the value to return
 *
 * @return double - indicator value or NULL in case of errors
 */
double iMTF(int iBuffer, int iBar) {
   static int lpSuperContext = 0; if (!lpSuperContext)
      lpSuperContext = GetIntsAddress(__ExecutionContext);

   double value = iCustom(NULL, systemTimeframe, ".attic/"+ WindowExpertName(),
                          SMA.Periods,                            // int    SMA.Periods
                          Stochastic.Periods,                     // int    Stochastic.Periods
                          Stochastic.MA1.Periods,                 // int    Stochastic.MA1.Periods
                          Stochastic.MA2.Periods,                 // int    Stochastic.MA2.Periods
                          RSI.Periods,                            // int    RSI.Periods
                          "",                                     // string ______________________
                          Timeframe,                              // string Timeframe
                          StartDate,                              // string StartDate
                          "",                                     // string ______________________
                          false,                                  // bool   AutoConfiguration
                          lpSuperContext,                         // int    __lpSuperContext

                          iBuffer, iBar);

   int error = GetLastError();
   if (error != NO_ERROR) {
      if (error != ERS_HISTORY_UPDATE)
         return(!catch("iMTF(1)", error));
      logWarn("iMTF(2)  "+ TimeframeDescription(systemTimeframe) +" (tick="+ Ticks +")", ERS_HISTORY_UPDATE);
   }

   error = __ExecutionContext[EC.mqlError];                       // TODO: synchronize execution contexts
   if (!error)
      return(value);
   return(!SetLastError(error));
}


/**
 * Return a Broketrader position value.
 *
 * @param  int bar - bar index of the value to return
 *
 * @return int - position value or NULL in case of errors
 */
int GetBroketraderPosition(int bar) {
   return(iBroketrader(systemTimeframe, smaPeriods, stochPeriods, stochMa1Periods, stochMa2Periods, rsiPeriods, Broketrader.MODE_TREND, bar));
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

   double value = iCustom(NULL, timeframe, ".attic/Broketrader",
                          smaPeriods,                             // int    SMA.Periods
                          stochasticPeriods,                      // int    Stochastic.Periods
                          stochasticMa1Periods,                   // int    Stochastic.MA1.Periods
                          stochasticMa2Periods,                   // int    Stochastic.MA2.Periods
                          rsiPeriods,                             // int    RSI.Periods
                          CLR_NONE,                               // color  Color.Long
                          CLR_NONE,                               // color  Color.Short
                          false,                                  // bool   FillSections
                          1,                                      // int    SMA.DrawWidth
                          StartDate,                              // string StartDate
                          -1,                                     // int    Max.Bars
                          "",                                     // string ____________________
                          "off",                                  // string Signal.onReversal
                          "off",                                  // string Signal.Sound
                          "off",                                  // string Signal.Mail
                          "off",                                  // string Signal.SMS
                          "",                                     // string ____________________
                          false,                                  // bool   AutoConfiguration
                          lpSuperContext,                         // int    __lpSuperContext

                          iBuffer, iBar);

   int error = GetLastError();
   if (error != NO_ERROR) {
      if (error != ERS_HISTORY_UPDATE)
         return(!catch("iBroketrader(1)", error));
      logWarn("iBroketrader(2)  "+ PeriodDescription(ifInt(!timeframe, Period(), timeframe)) +" (tick="+ Ticks +")", ERS_HISTORY_UPDATE);
   }

   error = __ExecutionContext[EC.mqlError];                       // TODO: synchronize execution contexts
   if (!error)
      return(value);
   return(!SetLastError(error));
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
 * Workaround for various terminal bugs when setting indicator options. Usually options are set in init(). However after
 * recompilation options must be set in start() to not be ignored.
 */
void SetIndicatorOptions() {
   SetIndexStyle(MODE_OPEN,   DRAW_NONE, STYLE_SOLID, 1, CLR_NONE);
   SetIndexStyle(MODE_CLOSED, DRAW_NONE, STYLE_SOLID, 1, CLR_NONE);
   SetIndexStyle(MODE_TOTAL,  DRAW_LINE, EMPTY, EMPTY);
}


/**
 * Return a string representation of the input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("SMA.Periods=",            SMA.Periods,               ";", NL,
                            "Stochastic.Periods=",     Stochastic.Periods,        ";", NL,
                            "Stochastic.MA1.Periods=", Stochastic.MA1.Periods,    ";", NL,
                            "Stochastic.MA2.Periods=", Stochastic.MA2.Periods,    ";", NL,
                            "RSI.Periods=",            RSI.Periods,               ";", NL,
                            "Timeframe=",              DoubleQuoteStr(Timeframe), ";", NL,
                            "StartDate=",              DoubleQuoteStr(StartDate), ";")
   );
}
