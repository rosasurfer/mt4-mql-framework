/**
 * Signal indicator for the "L'mas system"
 *
 * - long:
 *    entry onBarClose: Close > UpperTunnel && MA > UpperTunnel && MACD > 0
 *    stop  onTick:     Close < LowerTunnel && MA < LowerTunnel
 *
 * - short:
 *    entry onBarClose: Close < LowerTunnel && MA < LowerTunnel && MACD < 0
 *    stop  onTick:     Close > UpperTunnel && MA > UpperTunnel
 *
 *
 * TODO:
 *  - MA Tunnel
 *     support MA method MODE_ALMA
 *
 *  - ALMA
 *     add Background.Color+Background.Width
 *     merge includes icALMA() and functions/ta/ALMA.mqh
 *     replace manual StdDev calculation
 *
 *  - Moving Average
 *     add parameter stepping
 *
 *  - MACD
 *     add parameter stepping
 */
#include <stddefines.mqh>
int   __InitFlags[];
int __DeinitFlags[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern string Tunnel.MA.Method               = "SMA | LWMA* | EMA | SMMA | ALMA";
extern int    Tunnel.MA.Periods              = 55;

extern string MA.Method                      = "SMA | LWMA | EMA | SMMA | ALMA*";
extern int    MA.Periods                     = 10;                                  // original: EMA(5)

extern string MACD.FastMA.Method             = "SMA | LWMA | EMA* | SMMA | ALMA";
extern int    MACD.FastMA.Periods            = 12;
extern string MACD.SlowMA.Method             = "SMA | LWMA | EMA* | SMMA | ALMA";
extern int    MACD.SlowMA.Periods            = 26;

extern string ___a__________________________ = "=== Display settings ===";
extern int    MaxBarsBack                    = 10000;                               // max. values to calculate (-1: all available)

extern string ___b__________________________ = "=== Signaling ===";
extern bool   Signal.onEntry                 = false;
extern string Signal.onEntry.Types           = "sound* | alert | mail | sms";
extern bool   Signal.onExit                  = false;
extern string Signal.onExit.Types            = "sound* | alert | mail | sms";

extern string Signal.Sound.EntryLong         = "Signal Up.wav";
extern string Signal.Sound.EntryShort        = "Signal Down.wav";

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <rsfLib.mqh>
#include <functions/ConfigureSignals.mqh>
#include <functions/iCustom/MACD.mqh>
#include <functions/iCustom/MaTunnel.mqh>
#include <functions/iCustom/MovingAverage.mqh>

#define MODE_MAIN             MACD.MODE_MAIN    // 0 indicator buffer ids
#define MODE_TREND            MACD.MODE_TREND   // 1
#define MODE_UPPER_SECTION    2
#define MODE_LOWER_SECTION    3

#property indicator_separate_window
#property indicator_buffers   4

#property indicator_color1    CLR_NONE
#property indicator_color2    CLR_NONE
#property indicator_color3    CLR_NONE
#property indicator_color4    CLR_NONE

#property indicator_maximum   1
#property indicator_minimum  -1

double bufferMain [];                           // all histogram values:      invisible, displayed in "Data" window
double bufferTrend[];                           // trend and trend length:    invisible, displayed in "Data" window
double bufferUpper[];                           // positive histogram values: visible
double bufferLower[];                           // negative histogram values: visible

int    tunnel.method;
int    tunnel.periods;
string tunnel.definition;

int    ma.method;
int    ma.periods;

int    macd.fastMethod;
int    macd.fastPeriods;
int    macd.slowMethod;
int    macd.slowPeriods;

int    longestPeriods;

bool   signal.onEntry.sound;
bool   signal.onEntry.alert;
bool   signal.onEntry.mail;
bool   signal.onEntry.sms;

bool   signal.onExit.sound;
bool   signal.onExit.alert;
bool   signal.onExit.mail;
bool   signal.onExit.sms;


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   // validate inputs
   string indicator = WindowExpertName();

   // Tunnel.MA.Method
   string sValues[], sValue = Tunnel.MA.Method;
   if (AutoConfiguration) sValue = GetConfigString(indicator, "Tunnel.MA.Method", sValue);
   if (Explode(sValue, "*", sValues, 2) > 1) {
      int size = Explode(sValues[0], "|", sValues, NULL);
      sValue = sValues[size-1];
   }
   tunnel.method = StrToMaMethod(sValue, F_PARTIAL_ID|F_ERR_INVALID_PARAMETER);
   if (tunnel.method == -1)                   return(catch("onInit(1)  invalid input parameter Tunnel.MA.Method: "+ DoubleQuoteStr(Tunnel.MA.Method), ERR_INVALID_INPUT_PARAMETER));
   Tunnel.MA.Method = MaMethodDescription(tunnel.method);
   // Tunnel.MA.Periods
   if (AutoConfiguration) Tunnel.MA.Periods = GetConfigInt(indicator, "Tunnel.MA.Periods", Tunnel.MA.Periods);
   if (Tunnel.MA.Periods < 1)                 return(catch("onInit(2)  invalid input parameter Tunnel.MA.Periods: "+ Tunnel.MA.Periods, ERR_INVALID_INPUT_PARAMETER));
   tunnel.periods = Tunnel.MA.Periods;
   tunnel.definition = Tunnel.MA.Method +"("+ tunnel.periods+")";
   // MA.Method
   sValue = MA.Method;
   if (AutoConfiguration) sValue = GetConfigString(indicator, "MA.Method", sValue);
   if (Explode(sValue, "*", sValues, 2) > 1) {
      size = Explode(sValues[0], "|", sValues, NULL);
      sValue = sValues[size-1];
   }
   ma.method = StrToMaMethod(sValue, F_PARTIAL_ID|F_ERR_INVALID_PARAMETER);
   if (ma.method == -1)                       return(catch("onInit(3)  invalid input parameter MA.Method: "+ DoubleQuoteStr(MA.Method), ERR_INVALID_INPUT_PARAMETER));
   MA.Method = MaMethodDescription(ma.method);
   // MA.Periods
   if (AutoConfiguration) MA.Periods = GetConfigInt(indicator, "MA.Periods", MA.Periods);
   if (MA.Periods < 1)                        return(catch("onInit(4)  invalid input parameter MA.Periods: "+ MA.Periods, ERR_INVALID_INPUT_PARAMETER));
   ma.periods = MA.Periods;
   // MACD.FastMA.Method
   sValue = MACD.FastMA.Method;
   if (AutoConfiguration) sValue = GetConfigString(indicator, "MACD.FastMA.Method", sValue);
   if (Explode(sValue, "*", sValues, 2) > 1) {
      size = Explode(sValues[0], "|", sValues, NULL);
      sValue = sValues[size-1];
   }
   macd.fastMethod = StrToMaMethod(sValue, F_PARTIAL_ID|F_ERR_INVALID_PARAMETER);
   if (macd.fastMethod == -1)                 return(catch("onInit(5)  invalid input parameter MACD.FastMA.Method: "+ DoubleQuoteStr(MACD.FastMA.Method), ERR_INVALID_INPUT_PARAMETER));
   MACD.FastMA.Method = MaMethodDescription(macd.fastMethod);
   // MACD.FastMA.Periods
   if (AutoConfiguration) MACD.FastMA.Periods = GetConfigInt(indicator, "MACD.FastMA.Periods", MACD.FastMA.Periods);
   if (MACD.FastMA.Periods < 1)               return(catch("onInit(6)  invalid input parameter MACD.FastMA.Periods: "+ MACD.FastMA.Periods, ERR_INVALID_INPUT_PARAMETER));
   macd.fastPeriods = MACD.FastMA.Periods;
   // MACD.SlowMA.Method
   sValue = MACD.SlowMA.Method;
   if (AutoConfiguration) sValue = GetConfigString(indicator, "MACD.SlowMA.Method", sValue);
   if (Explode(sValue, "*", sValues, 2) > 1) {
      size = Explode(sValues[0], "|", sValues, NULL);
      sValue = sValues[size-1];
   }
   macd.slowMethod = StrToMaMethod(sValue, F_PARTIAL_ID|F_ERR_INVALID_PARAMETER);
   if (macd.slowMethod == -1)                 return(catch("onInit(7)  invalid input parameter MACD.SlowMA.Method: "+ DoubleQuoteStr(MACD.SlowMA.Method), ERR_INVALID_INPUT_PARAMETER));
   MACD.SlowMA.Method = MaMethodDescription(macd.slowMethod);
   // MACD.SlowMA.Periods
   if (AutoConfiguration) MACD.SlowMA.Periods = GetConfigInt(indicator, "MACD.SlowMA.Periods", MACD.SlowMA.Periods);
   if (MACD.SlowMA.Periods < 1)               return(catch("onInit(8)  invalid input parameter MACD.SlowMA.Periods: "+ MACD.SlowMA.Periods, ERR_INVALID_INPUT_PARAMETER));
   macd.slowPeriods = MACD.SlowMA.Periods;
   if (macd.fastPeriods > macd.slowPeriods)   return(catch("onInit(9)  MACD parameter mis-match (fast MA periods must be smaller than slow MA periods)", ERR_INVALID_INPUT_PARAMETER));
   if (macd.fastPeriods == macd.slowPeriods) {
      if (macd.fastMethod == macd.slowMethod) return(catch("onInit(10)  MACD parameter mis-match (fast MA must differ from slow MA)", ERR_INVALID_INPUT_PARAMETER));
   }
   longestPeriods = Max(tunnel.periods, ma.periods, macd.slowPeriods);
   // MaxBarsBack
   if (AutoConfiguration) MaxBarsBack = GetConfigInt(indicator, "MaxBarsBack", MaxBarsBack);
   if (MaxBarsBack < -1)                      return(catch("onInit(11)  invalid input parameter MaxBarsBack: "+ MaxBarsBack, ERR_INVALID_INPUT_PARAMETER));
   if (MaxBarsBack == -1) MaxBarsBack = INT_MAX;
   // Signal.onEntry
   string signalId = "Signal.onEntry";
   ConfigureSignals(signalId, AutoConfiguration, Signal.onEntry);
   if (Signal.onEntry) {
      if (!ConfigureSignalTypes(signalId, Signal.onEntry.Types, AutoConfiguration, signal.onEntry.sound, signal.onEntry.alert, signal.onEntry.mail, signal.onEntry.sms)) {
         return(catch("onInit(12)  invalid input parameter Signal.onEntry.Types: "+ DoubleQuoteStr(Signal.onEntry.Types), ERR_INVALID_INPUT_PARAMETER));
      }
      Signal.onEntry = (signal.onEntry.sound || signal.onEntry.alert || signal.onEntry.mail || signal.onEntry.sms);
   }
   // Signal.onExit
   signalId = "Signal.onExit";
   ConfigureSignals(signalId, AutoConfiguration, Signal.onExit);
   if (Signal.onExit) {
      if (!ConfigureSignalTypes(signalId, Signal.onExit.Types, AutoConfiguration, signal.onExit.sound, signal.onExit.alert, signal.onExit.mail, signal.onExit.sms)) {
         return(catch("onInit(13)  invalid input parameter Signal.onExit.Types: "+ DoubleQuoteStr(Signal.onExit.Types), ERR_INVALID_INPUT_PARAMETER));
      }
      Signal.onExit = (signal.onExit.sound || signal.onExit.alert || signal.onExit.mail || signal.onExit.sms);
   }
   // Signal.Sound.*
   if (AutoConfiguration) Signal.Sound.EntryLong  = GetConfigString(indicator, "Signal.Sound.EntryLong",  Signal.Sound.EntryLong);
   if (AutoConfiguration) Signal.Sound.EntryShort = GetConfigString(indicator, "Signal.Sound.EntryShort", Signal.Sound.EntryShort);

   // buffer management
   SetIndexBuffer(MODE_MAIN,          bufferMain ); SetIndexEmptyValue(MODE_MAIN,          0);
   SetIndexBuffer(MODE_TREND,         bufferTrend); SetIndexEmptyValue(MODE_TREND,         0);
   SetIndexBuffer(MODE_UPPER_SECTION, bufferUpper); SetIndexEmptyValue(MODE_UPPER_SECTION, 0);
   SetIndexBuffer(MODE_LOWER_SECTION, bufferLower); SetIndexEmptyValue(MODE_LOWER_SECTION, 0);

   // display options
   IndicatorShortName("Tunnel signal");                     // chart subwindow and context menu
   SetIndexLabel(MODE_MAIN,  "Tunnel entry signal");
   SetIndexLabel(MODE_TREND, "Tunnel trend");
   SetIndexLabel(MODE_UPPER_SECTION, NULL);
   SetIndexLabel(MODE_LOWER_SECTION, NULL);
   IndicatorDigits(0);
   SetIndicatorOptions();

   return(catch("onInit(14)"));
}


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   // on the first tick after terminal start buffers may not yet be initialized (spurious issue)
   if (!ArraySize(bufferMain)) return(logInfo("onTick(1)  sizeof(bufferMain) = 0", SetLastError(ERS_TERMINAL_NOT_YET_READY)));

   // reset buffers before performing a full recalculation
   if (!ValidBars) {
      ArrayInitialize(bufferMain,  0);
      ArrayInitialize(bufferTrend, 0);
      ArrayInitialize(bufferUpper, 0);
      ArrayInitialize(bufferLower, 0);
      SetIndicatorOptions();
   }

   // synchronize buffers with a shifted offline chart
   if (ShiftedBars > 0) {
      ShiftDoubleIndicatorBuffer(bufferMain,  Bars, ShiftedBars, 0);
      ShiftDoubleIndicatorBuffer(bufferTrend, Bars, ShiftedBars, 0);
      ShiftDoubleIndicatorBuffer(bufferUpper, Bars, ShiftedBars, 0);
      ShiftDoubleIndicatorBuffer(bufferLower, Bars, ShiftedBars, 0);
   }

   // calculate start bar
   int startbar = Min(MaxBarsBack-1, ChangedBars-1, Bars-longestPeriods);
   if (startbar < 0 && MaxBarsBack) return(logInfo("onTick(2)  Tick="+ Ticks, ERR_HISTORY_INSUFFICIENT));

   // recalculate changed bars
   for (int bar=startbar; bar >= 0; bar--) {
      // collect data
      double upperBand = GetMaTunnel(MODE_UPPER, bar);
      double lowerBand = GetMaTunnel(MODE_LOWER, bar);
      double ma        = GetMovingAverage(bar);
      double macd      = GetMACD(bar);

      // calculate indicator
      if (Close[bar] > upperBand && ma > upperBand && macd > 0) {
         bufferMain [bar] = 1;
         bufferUpper[bar] = bufferMain[bar];
         bufferLower[bar] = 0;
      }
      else if (Close[bar] < lowerBand && ma < lowerBand && macd < 0) {
         bufferMain [bar] = -1;
         bufferUpper[bar] = 0;
         bufferLower[bar] = bufferMain[bar];
      }
      else {
         bufferMain [bar] = bufferMain [bar+1];
         bufferUpper[bar] = bufferUpper[bar+1];
         bufferLower[bar] = bufferLower[bar+1];
      }
   }
   return(catch("onTick(3)"));
}


/**
 * Get a band value of the "MA Tunnel" indicator.
 *
 * @param  int mode - band identifier: MODE_UPPER | MODE_LOWER
 * @param  int bar  - bar offset
 *
 * @return double - band value or NULL in case of errors
 */
double GetMaTunnel(int mode, int bar) {
   if (tunnel.method == MODE_ALMA) {
      static int buffers[] = {0, MaTunnel.MODE_UPPER_BAND, MaTunnel.MODE_LOWER_BAND};
      return(icMaTunnel(NULL, tunnel.definition, buffers[mode], bar));
   }
   static int prices[] = {0, PRICE_HIGH, PRICE_LOW};
   return(iMA(NULL, NULL, tunnel.periods, 0, tunnel.method, prices[mode], bar));
}


/**
 * Get a value of the "Moving Average" indicator.
 *
 * @param  int bar  - bar offset
 *
 * @return double - MA value or NULL in case of errors
 */
double GetMovingAverage(int bar) {
   if (ma.method == MODE_ALMA) {
      return(icMovingAverage(NULL, ma.periods, "ALMA", "close", MovingAverage.MODE_MA, bar));
   }
   return(iMA(NULL, NULL, ma.periods, 0, ma.method, PRICE_CLOSE, bar));
}


/**
 * Get a value of the "MACD" indicator.
 *
 * @param  int bar  - bar offset
 *
 * @return double - MACD value or NULL in case of errors
 */
double GetMACD(int bar) {
   if (macd.fastMethod==MODE_EMA && macd.slowMethod==MODE_EMA) {
      return(iMACD(NULL, NULL, macd.fastPeriods, macd.slowPeriods, 1, PRICE_CLOSE, MACD.MODE_MAIN, bar));
   }
   return(icMACD(NULL, macd.fastPeriods, MACD.FastMA.Method, "close", macd.slowPeriods, MACD.SlowMA.Method, "close", MACD.MODE_MAIN, bar));
}


/**
 * Workaround for various terminal bugs when setting indicator options. Usually options are set in init(). However after
 * recompilation options must be set in start() to not be ignored.
 */
void SetIndicatorOptions() {
   //SetIndexStyle(int buffer, int drawType, int lineStyle=EMPTY, int drawWidth=EMPTY, color drawColor=NULL)
   IndicatorBuffers(indicator_buffers);

   SetIndexStyle(MODE_MAIN,          DRAW_NONE);
   SetIndexStyle(MODE_TREND,         DRAW_NONE);
   SetIndexStyle(MODE_UPPER_SECTION, DRAW_HISTOGRAM, EMPTY, EMPTY, LimeGreen);
   SetIndexStyle(MODE_LOWER_SECTION, DRAW_HISTOGRAM, EMPTY, EMPTY, Red);
}


/**
 * Return a string representation of the input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("Tunnel.MA.Method=",        DoubleQuoteStr(Tunnel.MA.Method),        ";", NL,
                            "Tunnel.MA.Periods=",       Tunnel.MA.Periods,                       ";", NL,
                            "MA.Method=",               DoubleQuoteStr(MA.Method),               ";", NL,
                            "MA.Periods=",              MA.Periods,                              ";", NL,
                            "MACD.FastMA.Method=",      DoubleQuoteStr(MACD.FastMA.Method),      ";", NL,
                            "MACD.FastMA.Periods=",     MACD.FastMA.Periods,                     ";", NL,
                            "MACD.SlowMA.Method=",      DoubleQuoteStr(MACD.SlowMA.Method),      ";", NL,
                            "MACD.SlowMA.Periods=",     MACD.SlowMA.Periods,                     ";", NL,
                            "MaxBarsBack=",             MaxBarsBack,                             ";", NL,

                            "Signal.onEntry=",          BoolToStr(Signal.onEntry),               ";", NL,
                            "Signal.onEntry.Types=",    DoubleQuoteStr(Signal.onEntry.Types),    ";", NL,
                            "Signal.onExit=",           BoolToStr(Signal.onExit),                ";", NL,
                            "Signal.onExit.Types=",     DoubleQuoteStr(Signal.onExit.Types),     ";", NL,
                            "Signal.Sound.EntryLong=",  DoubleQuoteStr(Signal.Sound.EntryLong),  ";", NL,
                            "Signal.Sound.EntryShort=", DoubleQuoteStr(Signal.Sound.EntryShort), ";")
   );
}
