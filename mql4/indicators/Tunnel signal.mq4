/**
 * Signal indicator for the "L'mas system"
 *
 *
 * TODO:
 *  - dynamic Grid
 *
 *  - merge bufferMain[] and bufferTrend[]
 *  - signaling
 *
 *  - MA Tunnel
 *     support MA method MODE_ALMA
 *     remove tick signaling?
 *
 *  - ALMA
 *     add Background.Color+Background.Width
 *     merge includes icALMA() and functions/ta/ALMA.mqh
 *     replace manual StdDev calculation
 *
 *  - Moving Average, MACD
 *     add parameter stepping
 *
 *  - Inside Bars
 *     prevent signaling of duplicated events
 *
 *  - ChartInfos
 *     fix positioning of UnitSize/PositionSize when in CORNER_TOP_LEFT
 *     on hotkey CustomPositions() the unitsize is not recalculated
 *     rewrite unitsize configuration
 *
 *  - iCustom(): limit calculated bars in online charts
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
extern color  Histogram.Color.Upper          = LimeGreen;
extern color  Histogram.Color.Lower          = Red;
extern int    Histogram.Style.Width          = 2;
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
#include <functions/ObjectCreateRegister.mqh>
#include <functions/iCustom/MACD.mqh>
#include <functions/iCustom/MaTunnel.mqh>
#include <functions/iCustom/MovingAverage.mqh>

#define MODE_MAIN             MACD.MODE_MAIN    // 0 indicator buffer ids
#define MODE_TREND            MACD.MODE_TREND   // 1
#define MODE_UPPER_SECTION    2
#define MODE_LOWER_SECTION    3

#define HINT_CLOSE            1                 // trend hint ids
#define HINT_MA               2
#define HINT_MACD             3

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

string indicatorName = "";

string trendHintCloseLabel = "";
string trendHintMaLabel    = "";
string trendHintMacdLabel  = "";
string trendHintFontName   = "Arial Black";
int    trendHintFontSize   = 8;
bool   trendHintsCreated   = false;


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
   // Histogram.Color.*: after deserialization the terminal might turn CLR_NONE (0xFFFFFFFF) into Black (0xFF000000)
   if (AutoConfiguration) Histogram.Color.Upper = GetConfigColor(indicator, "Histogram.Color.Upper", Histogram.Color.Upper);
   if (AutoConfiguration) Histogram.Color.Lower = GetConfigColor(indicator, "Histogram.Color.Lower", Histogram.Color.Lower);
   if (Histogram.Color.Upper == 0xFF000000) Histogram.Color.Upper = CLR_NONE;
   if (Histogram.Color.Lower == 0xFF000000) Histogram.Color.Lower = CLR_NONE;
   // Histogram.Style.Width
   if (AutoConfiguration) Histogram.Style.Width = GetConfigInt(indicator, "Histogram.Style.Width", Histogram.Style.Width);
   if (Histogram.Style.Width < 0)             return(catch("onInit(11)  invalid input parameter Histogram.Style.Width: "+ Histogram.Style.Width +" (valid range: 0-5)", ERR_INVALID_INPUT_PARAMETER));
   if (Histogram.Style.Width > 5)             return(catch("onInit(12)  invalid input parameter Histogram.Style.Width: "+ Histogram.Style.Width +" (valid range: 0-5)", ERR_INVALID_INPUT_PARAMETER));
   // MaxBarsBack
   if (AutoConfiguration) MaxBarsBack = GetConfigInt(indicator, "MaxBarsBack", MaxBarsBack);
   if (MaxBarsBack < -1)                      return(catch("onInit(13)  invalid input parameter MaxBarsBack: "+ MaxBarsBack, ERR_INVALID_INPUT_PARAMETER));
   if (MaxBarsBack == -1) MaxBarsBack = INT_MAX;
   // Signal.onEntry
   string signalId = "Signal.onEntry";
   ConfigureSignals(signalId, AutoConfiguration, Signal.onEntry);
   if (Signal.onEntry) {
      if (!ConfigureSignalTypes(signalId, Signal.onEntry.Types, AutoConfiguration, signal.onEntry.sound, signal.onEntry.alert, signal.onEntry.mail, signal.onEntry.sms)) {
         return(catch("onInit(14)  invalid input parameter Signal.onEntry.Types: "+ DoubleQuoteStr(Signal.onEntry.Types), ERR_INVALID_INPUT_PARAMETER));
      }
      Signal.onEntry = (signal.onEntry.sound || signal.onEntry.alert || signal.onEntry.mail || signal.onEntry.sms);
   }
   // Signal.onExit
   signalId = "Signal.onExit";
   ConfigureSignals(signalId, AutoConfiguration, Signal.onExit);
   if (Signal.onExit) {
      if (!ConfigureSignalTypes(signalId, Signal.onExit.Types, AutoConfiguration, signal.onExit.sound, signal.onExit.alert, signal.onExit.mail, signal.onExit.sms)) {
         return(catch("onInit(15)  invalid input parameter Signal.onExit.Types: "+ DoubleQuoteStr(Signal.onExit.Types), ERR_INVALID_INPUT_PARAMETER));
      }
      Signal.onExit = (signal.onExit.sound || signal.onExit.alert || signal.onExit.mail || signal.onExit.sms);
   }
   // Signal.Sound.*
   if (AutoConfiguration) Signal.Sound.EntryLong  = GetConfigString(indicator, "Signal.Sound.EntryLong",  Signal.Sound.EntryLong);
   if (AutoConfiguration) Signal.Sound.EntryShort = GetConfigString(indicator, "Signal.Sound.EntryShort", Signal.Sound.EntryShort);

   SetIndicatorOptions();
   return(catch("onInit(16)"));
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
      if (!trendHintsCreated) {
         if (!CreateTrendHints()) return(last_error);       // uses WindowFind() which cannot be called in CF_INIT
      }
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

   double upperBand, lowerBand, ma, macd;

   // recalculate changed bars
   for (int bar=startbar; bar >= 0; bar--) {
      upperBand = GetMaTunnel(MODE_UPPER, bar);
      lowerBand = GetMaTunnel(MODE_LOWER, bar);
      ma        = GetMovingAverage(bar);
      macd      = GetMACD(bar);

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

   if (!__isSuperContext) {
      // update trend hints
      if (__isChart) {
         int status = 0;
         if      (Close[0] > upperBand) status = +1;
         else if (Close[0] < lowerBand) status = -1;
         UpdateTrendHint(HINT_CLOSE, status);

         status = 0;
         if      (ma > upperBand) status = +1;
         else if (ma < lowerBand) status = -1;
         UpdateTrendHint(HINT_MA, status);

         status = 0;
         if      (macd > 0) status = +1;
         else if (macd < 0) status = -1;
         UpdateTrendHint(HINT_MACD, status);
      }

      // monitor signals
   }
   return(catch("onTick(4)"));
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
      static bool initialized = false;

      int starttime = GetTickCount();
      double value = icMovingAverage(NULL, ma.periods, "ALMA", "close", MovingAverage.MODE_MA, bar);

      if (!initialized) {
         int endtime = GetTickCount();
         //debug("GetMovingAverage(0.1)  1st execution: "+ DoubleToStr((endtime-starttime)/1000., 3) +" sec");
         initialized = true;
      }
      return(value);
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
 * Create chart objects for the trend hints.
 *
 * @return bool - success status
 */
bool CreateTrendHints() {
   if (__isSuperContext || !__isChart) return(true);

   string prefix = "rsf."+ WindowExpertName() +".";
   string suffix = "."+ __ExecutionContext[EC.pid] +"."+ __ExecutionContext[EC.hChart];
   int window = WindowFind(indicatorName);
   if (window == -1) return(!catch("CreateTrendHints(1)->WindowFind(\""+ indicatorName +"\") => -1", ERR_RUNTIME_ERROR));

   string label = prefix +"Close"+ suffix;
   if (ObjectFind(label) == -1) if (!ObjectCreateRegister(label, OBJ_LABEL, window, 0, 0)) return(false);
   ObjectSet    (label, OBJPROP_CORNER, CORNER_TOP_RIGHT);
   ObjectSet    (label, OBJPROP_XDISTANCE, 66);
   ObjectSet    (label, OBJPROP_YDISTANCE,  1);
   ObjectSetText(label, " ");
   trendHintCloseLabel = label;

   label = prefix +"MA"+ suffix;
   if (ObjectFind(label) == -1) if (!ObjectCreateRegister(label, OBJ_LABEL, window, 0, 0)) return(false);
   ObjectSet    (label, OBJPROP_CORNER, CORNER_TOP_RIGHT);
   ObjectSet    (label, OBJPROP_XDISTANCE, 34);
   ObjectSet    (label, OBJPROP_YDISTANCE,  1);
   ObjectSetText(label, " ");
   trendHintMaLabel = label;

   label = prefix +"MACD"+ suffix;
   if (ObjectFind(label) == -1) if (!ObjectCreateRegister(label, OBJ_LABEL, window, 0, 0)) return(false);
   ObjectSet    (label, OBJPROP_CORNER, CORNER_TOP_RIGHT);
   ObjectSet    (label, OBJPROP_XDISTANCE, 7);
   ObjectSet    (label, OBJPROP_YDISTANCE, 1);
   ObjectSetText(label, " ");
   trendHintMacdLabel = label;

   trendHintsCreated = true;
   return(!catch("CreateTrendHints(2)"));
}


/**
 * Update a trend hint.
 *
 * @param  int id     - trend hint id: HINT_CLOSE | HINT_MA | HINT_MACD
 * @param  int status - hint status, one of +1, 0 or -1
 */
void UpdateTrendHint(int id, int status) {
   if (__isSuperContext || !__isChart) return;

   if      (status > 0) color clr = Histogram.Color.Upper;
   else if (status < 0)       clr = Histogram.Color.Lower;
   else                       clr = Orange;

   switch (id) {
      case HINT_CLOSE: ObjectSetText(trendHintCloseLabel, "B",  trendHintFontSize, trendHintFontName, clr); break;
      case HINT_MA:    ObjectSetText(trendHintMaLabel,    "MA", trendHintFontSize, trendHintFontName, clr); break;
      case HINT_MACD:  ObjectSetText(trendHintMacdLabel,  "CD", trendHintFontSize, trendHintFontName, clr); break;

      default:
         return(!catch("UpdateTrendHint(1)  invalid parameter id: "+ id, ERR_INVALID_PARAMETER));
   }

   int error = GetLastError();               // on ObjectDrag or opened "Properties" dialog
   if (error && error!=ERR_OBJECT_DOES_NOT_EXIST) catch("UpdateTrendHint(2)", error);
}


/**
 * Workaround for various terminal bugs when setting indicator options. Usually options are set in init(). However after
 * recompilation options must be set in start() to not be ignored.
 */
void SetIndicatorOptions() {
   indicatorName = WindowExpertName();
   IndicatorShortName(indicatorName);

   IndicatorBuffers(indicator_buffers);
   SetIndexBuffer(MODE_MAIN,          bufferMain ); SetIndexEmptyValue(MODE_MAIN,          0); SetIndexLabel(MODE_MAIN,  indicatorName);
   SetIndexBuffer(MODE_TREND,         bufferTrend); SetIndexEmptyValue(MODE_TREND,         0); SetIndexLabel(MODE_TREND, "Tunnel trend");
   SetIndexBuffer(MODE_UPPER_SECTION, bufferUpper); SetIndexEmptyValue(MODE_UPPER_SECTION, 0); SetIndexLabel(MODE_UPPER_SECTION, NULL);
   SetIndexBuffer(MODE_LOWER_SECTION, bufferLower); SetIndexEmptyValue(MODE_LOWER_SECTION, 0); SetIndexLabel(MODE_LOWER_SECTION, NULL);
   IndicatorDigits(0);

   int drawType = ifInt(Histogram.Style.Width, DRAW_HISTOGRAM, DRAW_NONE);

   SetIndexStyle(MODE_MAIN,          DRAW_NONE);
   SetIndexStyle(MODE_TREND,         DRAW_NONE);
   SetIndexStyle(MODE_UPPER_SECTION, drawType, EMPTY, Histogram.Style.Width, Histogram.Color.Upper);
   SetIndexStyle(MODE_LOWER_SECTION, drawType, EMPTY, Histogram.Style.Width, Histogram.Color.Lower);
}


/**
 * Return a string representation of the input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("Tunnel.MA.Method=",        DoubleQuoteStr(Tunnel.MA.Method),        ";"+ NL,
                            "Tunnel.MA.Periods=",       Tunnel.MA.Periods,                       ";"+ NL,
                            "MA.Method=",               DoubleQuoteStr(MA.Method),               ";"+ NL,
                            "MA.Periods=",              MA.Periods,                              ";"+ NL,
                            "MACD.FastMA.Method=",      DoubleQuoteStr(MACD.FastMA.Method),      ";"+ NL,
                            "MACD.FastMA.Periods=",     MACD.FastMA.Periods,                     ";"+ NL,
                            "MACD.SlowMA.Method=",      DoubleQuoteStr(MACD.SlowMA.Method),      ";"+ NL,
                            "MACD.SlowMA.Periods=",     MACD.SlowMA.Periods,                     ";"+ NL,

                            "Histogram.Color.Upper=",   ColorToStr(Histogram.Color.Upper),       ";"+ NL,
                            "Histogram.Color.Lower=",   ColorToStr(Histogram.Color.Lower),       ";"+ NL,
                            "Histogram.Style.Width=",   Histogram.Style.Width,                   ";"+ NL,
                            "MaxBarsBack=",             MaxBarsBack,                             ";"+ NL,

                            "Signal.onEntry=",          BoolToStr(Signal.onEntry),               ";"+ NL,
                            "Signal.onEntry.Types=",    DoubleQuoteStr(Signal.onEntry.Types),    ";"+ NL,
                            "Signal.onExit=",           BoolToStr(Signal.onExit),                ";"+ NL,
                            "Signal.onExit.Types=",     DoubleQuoteStr(Signal.onExit.Types),     ";"+ NL,
                            "Signal.Sound.EntryLong=",  DoubleQuoteStr(Signal.Sound.EntryLong),  ";"+ NL,
                            "Signal.Sound.EntryShort=", DoubleQuoteStr(Signal.Sound.EntryShort), ";")
   );
}
