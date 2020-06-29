/**
 * Broketrader Performance
 *
 * Visualizes the PL performance of the Broketrader system.
 *
 * @see  mql4/indicators/systems/Broketrader.mq4
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
extern string MTF                    = "H1* | current";  // empty: current

extern string StartDate              = "2020.01.01";     // "yyyy.mm.dd" start date of the indicator
extern int    Max.Bars               = 10000;            // max. number of bars to display (-1: all available)

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <rsfLibs.mqh>
#include <functions/iBarShiftNext.mqh>

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

int      currentTimeframe;
int      targetTimeframe;
datetime startDate;
int      maxValues;


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
      targetTimeframe = StrToTimeframe(sValue, F_ERR_INVALID_PARAMETER);
      if (targetTimeframe == -1)   return(catch("onInit(6)  Invalid input parameter MTF: "+ DoubleQuoteStr(MTF), ERR_INVALID_INPUT_PARAMETER));
      MTF = TimeframeDescription(targetTimeframe);
   }
   currentTimeframe = Period();
   // StartDate
   sValue = StrTrim(StartDate);
   if (StringLen(sValue) > 0) {
      startDate = ParseDate(sValue);
      if (IsNaT(startDate))        return(catch("onInit(7)  Invalid input parameter StartDate: "+ DoubleQuoteStr(StartDate), ERR_INVALID_INPUT_PARAMETER));
   }
   // Max.Bars
   if (Max.Bars < -1)              return(catch("onInit(8)  Invalid input parameter Max.Bars: "+ Max.Bars, ERR_INVALID_INPUT_PARAMETER));
   maxValues = ifInt(Max.Bars==-1, INT_MAX, Max.Bars);

   // buffer management
   SetIndexBuffer(MODE_OPEN,   bufferOpenPL  );                // open PL:   invisible
   SetIndexBuffer(MODE_CLOSED, bufferClosedPL);                // closed PL: invisible
   SetIndexBuffer(MODE_TOTAL,  bufferTotalPL );                // total PL:  visible

   // names, labels and display options
   IndicatorShortName("Broketrader open/closed/total PL  ");   // indicator subwindow and context menu
   SetIndexLabel(MODE_OPEN,   "Broketrader open PL"  );        // "Data" window
   SetIndexLabel(MODE_CLOSED, "Broketrader closed PL");
   SetIndexLabel(MODE_TOTAL,  "Broketrader total PL" );
   IndicatorDigits(1);
   SetIndicatorOptions();

   return(catch("onInit(9)"));
}


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   // a not initialized buffer can happen on terminal start under specific circumstances
   if (!ArraySize(bufferTotalPL)) return(log("onTick(1)  size(bufferTotalPL) = 0", SetLastError(ERS_TERMINAL_NOT_YET_READY)));

   // reset all buffers and delete garbage behind Max.Bars before doing a full recalculation
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
   int maxStochValues = Bars - rsiPeriods - stochPeriods - stochMa1Periods - stochMa2Periods - 1;  // max. possible Stochastic values (see Broketrader)
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

      bufferOpenPL  [i] = openPL;
      bufferClosedPL[i] = closedPL;                                     // on EMPTY_VALUE trading hasn't yet started
      bufferTotalPL [i] = ifDouble(closedPL==EMPTY_VALUE, EMPTY_VALUE, closedPL + openPL);
   }
   return(catch("onTick(3)"));
}


/**
 * MTF main function
 *
 * @return int - error status
 */
int onMTF() {
   debug("onMTF(1)  requested timeframe: "+ TimeframeDescription(targetTimeframe));

   if (targetTimeframe < currentTimeframe) {
      // e.g. Broketrader,H1 on Performance,H4

      // calculate start bar
      if (startDate > 0) {
         int startBar = iBarShiftNext(NULL, NULL, startDate);
         if (startBar >= maxValues)
            startBar = maxValues - 1;
      }
   }
   else {
      // e.g. Broketrader,H1 on Performance,M15
   }

   return(catch("onMTF(3)"));
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
                          -1,                                     // int    Max.Bars                  // all values to prevent MTF issues
                          "",                                     // string ____________________
                          "off",                                  // string Signal.onReversal
                          "off",                                  // string Signal.Sound
                          "off",                                  // string Signal.Mail.Receiver
                          "off",                                  // string Signal.SMS.Receiver
                          "",                                     // string ____________________
                          lpSuperContext,                         // int    __lpSuperContext

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
 * Parse the string representation of a date to a datetime value.
 *
 * @param  string value - string in format "YYYY.MM.DD"
 *
 * @return datetime - datetime value or NaT (not-a-time) in case of errors
 */
datetime ParseDate(string value) {
   string sValues[], origValue=value;
   value = StrTrim(value);
   if (!StringLen(value))                                  return(_NaT(catch("ParseDate(1)  invalid parameter value: "+ DoubleQuoteStr(origValue) +" (not a date)", ERR_INVALID_PARAMETER)));
   int sizeOfValues = Explode(value, ".", sValues, NULL);
   if (sizeOfValues != 3)                                  return(_NaT(catch("ParseDate(2)  invalid parameter value: "+ DoubleQuoteStr(origValue) +" (not a date)", ERR_INVALID_PARAMETER)));

   // parse year: YYYY
   string sYY = StrTrim(sValues[0]);
   if (StringLen(sYY)!=4 || !StrIsDigit(sYY))              return(_NaT(catch("ParseDate(3)  invalid parameter value: "+ DoubleQuoteStr(origValue) +" (not a date)", ERR_INVALID_PARAMETER)));
   int iYY = StrToInteger(sYY);
   if (iYY < 1970 || iYY > 2037)                           return(_NaT(catch("ParseDate(4)  invalid parameter value: "+ DoubleQuoteStr(origValue) +" (not a date)", ERR_INVALID_PARAMETER)));

   // parse month: MM
   string sMM = StrTrim(sValues[1]);
   if (StringLen(sMM) > 2 || !StrIsDigit(sMM))             return(_NaT(catch("ParseDate(5)  invalid parameter value: "+ DoubleQuoteStr(origValue) +" (not a date)", ERR_INVALID_PARAMETER)));
   int iMM = StrToInteger(sMM);
   if (iMM < 1 || iMM > 12)                                return(_NaT(catch("ParseDate(6)  invalid parameter value: "+ DoubleQuoteStr(origValue) +" (not a date)", ERR_INVALID_PARAMETER)));

   // parse day: DD
   string sDD = StrTrim(sValues[2]);
   if (StringLen(sDD) > 2 || !StrIsDigit(sDD))             return(_NaT(catch("ParseDate(7)  invalid parameter value: "+ DoubleQuoteStr(origValue) +" (not a date)", ERR_INVALID_PARAMETER)));
   int iDD = StrToInteger(sDD);
   if (iDD < 1 || iDD > 31)                                return(_NaT(catch("ParseDate(8)  invalid parameter value: "+ DoubleQuoteStr(origValue) +" (not a date)", ERR_INVALID_PARAMETER)));
   if (iDD > 28) {
      if (iMM == FEB) {
         if (iDD > 29 || !IsLeapYear(iYY))                 return(_NaT(catch("ParseDate(9)  invalid parameter value: "+ DoubleQuoteStr(origValue) +" (not a date)", ERR_INVALID_PARAMETER)));
      }
      else if (iDD == 31) {
         if (iMM==APR || iMM==JUN || iMM==SEP || iMM==NOV) return(_NaT(catch("ParseDate(10)  invalid parameter value: "+ DoubleQuoteStr(origValue) +" (not a date)", ERR_INVALID_PARAMETER)));
      }
   }
   return(DateTime(iYY, iMM, iDD));
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
                            "StartDate=",              StartDate,              ";", NL,
                            "Max.Bars=",               Max.Bars,               ";")
   );
}
