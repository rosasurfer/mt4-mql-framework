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
 *  • Stochastic.MODE_SIGNAL: indicator signal line (last moving average)
 *
 * If only one Moving Average is configured (MA1 or MA2) the indicator calculates the "Fast Stochastic" and MODE_MAIN contains
 * the raw Stochastic. If both Moving Averages are configured the indicator calculates the "Slow Stochastic" and MODE_MAIN
 * contains MA1(StochRaw). MODE_SIGNAL always contains the last configured Moving Average.
 */
#include <stddefines.mqh>
int   __InitFlags[];
int __DeinitFlags[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern int    Stoch.Main.Periods       = 96;             // %K line
extern int    Stoch.SlowedMain.Periods = 10;             // slowed %K line (MA)
extern int    Stoch.Signal.Periods     = 6;              // %D line (MA of resulting %K)
extern int    RSI.Periods              = 96;

extern color  Main.Color               = DodgerBlue;
extern color  Signal.Color             = Red;
extern string Signal.DrawType          = "Line* | Dot";
extern int    Signal.DrawWidth         = 1;

extern int    Max.Bars                 = 10000;          // max. number of values to calculate (-1: all available)

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
int       terminal_buffers  = 4;                         // buffers managed by the terminal

#property indicator_color1    CLR_NONE
#property indicator_color2    CLR_NONE

#property indicator_level1    40
#property indicator_level2    60

#property indicator_minimum   0
#property indicator_maximum   100

double bufferRsi  [];                                    // RSI value:      invisible
double bufferStoch[];                                    // raw %K line:    invisible
double bufferMa1  [];                                    // slowed %K line: visible
double bufferMa2  [];                                    // %D line:        visible, displayed in "Data" window

int stochPeriods;
int ma1Periods;
int ma2Periods;
int rsiPeriods;

int signalDrawType;
int signalDrawWidth;
int maxValues;


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   // validate inputs
   if (Stoch.Main.Periods < 2)       return(catch("onInit(1)  Invalid input parameter Stoch.Main.Periods: "+ Stoch.Main.Periods +" (min. 2)", ERR_INVALID_INPUT_PARAMETER));
   if (Stoch.SlowedMain.Periods < 0) return(catch("onInit(2)  Invalid input parameter Stoch.SlowedMain.Periods: "+ Stoch.SlowedMain.Periods, ERR_INVALID_INPUT_PARAMETER));
   if (Stoch.Signal.Periods < 0)     return(catch("onInit(3)  Invalid input parameter Stoch.Signal.Periods: "+ Stoch.Signal.Periods, ERR_INVALID_INPUT_PARAMETER));
   if (RSI.Periods < 2)              return(catch("onInit(4)  Invalid input parameter RSI.Periods: "+ RSI.Periods +" (min. 2)", ERR_INVALID_INPUT_PARAMETER));
   stochPeriods = Stoch.Main.Periods;
   ma1Periods   = ifInt(!Stoch.SlowedMain.Periods, 1, Stoch.SlowedMain.Periods);
   ma2Periods   = ifInt(!Stoch.Signal.Periods, 1, Stoch.Signal.Periods);
   rsiPeriods   = RSI.Periods;

   // colors: after deserialization the terminal might turn CLR_NONE (0xFFFFFFFF) into Black (0xFF000000)
   if (Main.Color   == 0xFF000000) Main.Color   = CLR_NONE;
   if (Signal.Color == 0xFF000000) Signal.Color = CLR_NONE;

   // Signal.DrawType
   string sValues[], sValue=StrToLower(Signal.DrawType);
   if (Explode(sValue, "*", sValues, 2) > 1) {
      int size = Explode(sValues[0], "|", sValues, NULL);
      sValue = sValues[size-1];
   }
   sValue = StrTrim(sValue);
   if      (StrStartsWith("line", sValue)) { signalDrawType = DRAW_LINE;  Signal.DrawType = "Line"; }
   else if (StrStartsWith("dot",  sValue)) { signalDrawType = DRAW_ARROW; Signal.DrawType = "Dot";  }
   else                            return(catch("onInit(5)  Invalid input parameter Signal.DrawType = "+ DoubleQuoteStr(Signal.DrawType), ERR_INVALID_INPUT_PARAMETER));

   // Signal.DrawWidth
   if (Signal.DrawWidth < 0)       return(catch("onInit(6)  Invalid input parameter Signal.DrawWidth = "+ Signal.DrawWidth, ERR_INVALID_INPUT_PARAMETER));
   if (Signal.DrawWidth > 5)       return(catch("onInit(7)  Invalid input parameter Signal.DrawWidth = "+ Signal.DrawWidth, ERR_INVALID_INPUT_PARAMETER));
   signalDrawWidth = Signal.DrawWidth;

   // Max.Bars
   if (Max.Bars < -1)              return(catch("onInit(8)  Invalid input parameter Max.Bars: "+ Max.Bars, ERR_INVALID_INPUT_PARAMETER));
   maxValues = ifInt(Max.Bars==-1, INT_MAX, Max.Bars);

   // buffer management
   SetIndexBuffer(MODE_RSI,       bufferRsi  );          // RSI value:      invisible
   SetIndexBuffer(MODE_STOCH_RAW, bufferStoch);          // raw %K line:    invisible
   SetIndexBuffer(MODE_STOCH_MA1, bufferMa1  );          // slowed %K line: visible
   SetIndexBuffer(MODE_STOCH_MA2, bufferMa2  );          // %D line:        visible, displayed in "Data" window

   // swap MA periods for fast Stochastic
   if (ma2Periods == 1) {
      int tmp = ma1Periods;
      ma1Periods = ma2Periods;
      ma2Periods = tmp;
   }

   // names, labels and display options
   string sStochMa1Periods="", sStochMa2Periods="";
   if (ma1Periods!=1) sStochMa1Periods = ", "+ ma1Periods;
   if (ma2Periods!=1) sStochMa2Periods = ", "+ ma2Periods;
   string indicatorName  = "Stochastic("+ stochPeriods +" x RSI("+ rsiPeriods +")"+ sStochMa1Periods + sStochMa2Periods +")";

   IndicatorShortName(indicatorName +"  ");              // chart subwindow and context menu
   SetIndexLabel(MODE_RSI,       NULL);                  // chart tooltips and "Data" window
   SetIndexLabel(MODE_STOCH_RAW, NULL);
   SetIndexLabel(MODE_STOCH_MA1, "Stoch(RSI) main"); if (Main.Color == CLR_NONE) SetIndexLabel(MODE_STOCH_MA1, NULL);
   SetIndexLabel(MODE_STOCH_MA2, "Stoch(RSI) signal");
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
   // on the first tick after terminal start buffers may not yet be initialized (spurious issue)
   if (!ArraySize(bufferRsi)) return(logInfo("onTick(1)  size(bufferRsi) = 0", SetLastError(ERS_TERMINAL_NOT_YET_READY)));

   // reset all buffers and delete garbage behind Max.Bars before doing a full recalculation
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
   int resultingBars = Bars - rsiPeriods - stochPeriods - ma1Periods - ma2Periods - 1; // max. resulting bars
   if (resultingBars < 1) return(catch("onTick(2)", ERR_HISTORY_INSUFFICIENT));

   int bars          = Min(requestedBars, resultingBars);                              // actual number of bars to be updated
   int ma2StartBar   = bars - 1;
   int ma1StartBar   = ma2StartBar + ma2Periods - 1;
   int stochStartBar = ma1StartBar + ma1Periods - 1;
   int rsiStartBar   = stochStartBar + stochPeriods - 1;

   // recalculate changed bars
   for (int i=rsiStartBar; i >= 0; i--) {
      bufferRsi[i] = iRSI(NULL, NULL, rsiPeriods, PRICE_CLOSE, i);
   }

   for (i=stochStartBar; i >= 0; i--) {
      double rsiHigh = bufferRsi[ArrayMaximum(bufferRsi, stochPeriods, i)];
      double rsiLow  = bufferRsi[ArrayMinimum(bufferRsi, stochPeriods, i)];
      bufferStoch[i] = MathDiv(bufferRsi[i]-rsiLow, rsiHigh-rsiLow, 0.5) * 100;        // raw Stochastic
   }

   for (i=ma1StartBar; i >= 0; i--) {
      bufferMa1[i] = iMAOnArray(bufferStoch, WHOLE_ARRAY, ma1Periods, 0, MODE_SMA, i); // SMA: no performance impact of WHOLE_ARRAY
   }

   for (i=ma2StartBar; i >= 0; i--) {
      bufferMa2[i] = iMAOnArray(bufferMa1, WHOLE_ARRAY, ma2Periods, 0, MODE_SMA, i);
   }

   return(catch("onTick(3)"));
}


/**
 * Workaround for various terminal bugs when setting indicator options. Usually options are set in init(). However after
 * recompilation options must be set in start() to not be ignored.
 */
void SetIndicatorOptions() {
   IndicatorBuffers(terminal_buffers);

   int ma2Type  = ifInt(signalDrawWidth, signalDrawType, DRAW_NONE);
   int ma2Width = signalDrawWidth;

   SetIndexStyle(MODE_STOCH_MA1, DRAW_LINE, EMPTY, EMPTY,    Main.Color);
   SetIndexStyle(MODE_STOCH_MA2, ma2Type,   EMPTY, ma2Width, Signal.Color); SetIndexArrow(MODE_STOCH_MA2, 158);
}


/**
 * Return a string representation of the input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("Stoch.Main.Periods=",       Stoch.Main.Periods,       ";"+ NL,
                            "Stoch.SlowedMain.Periods=", Stoch.SlowedMain.Periods, ";"+ NL,
                            "Stoch.Signal.Periods=",     Stoch.Signal.Periods,     ";"+ NL,
                            "RSI.Periods=",              RSI.Periods,              ";"+ NL,
                            "Main.Color=",               ColorToStr(Main.Color),   ";"+ NL,
                            "Signal.Color=",             ColorToStr(Signal.Color), ";"+ NL,
                            "Signal.DrawType=",          Signal.DrawType,          ";"+ NL,
                            "Signal.DrawWidth=",         Signal.DrawWidth,         ";"+ NL,
                            "Max.Bars=",                 Max.Bars,                 ";")
   );
}
