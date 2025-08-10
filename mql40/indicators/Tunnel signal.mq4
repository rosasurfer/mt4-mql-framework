/**
 * Signal indicator for the "L'mas system"
 *
 * The indicator changes direction if Close of the current bar and MovingAverage are above/below the tunnel.
 *
 *
 * TODO:
 *  - merge bufferMain[] and bufferTrend[]
 *
 *
 *
 * --------------------------------------------------------------------------------------------------------------------------
 *  - MACD + Tunnel signal
 *     invalid signals at terminal startup
 *
 *  - Inside Bars
 *     prevent double-signaling of parallel events
 *
 *  - ChartInfos
 *     unitsize configuration: manual leverage doesn't work (limits to 10% risk)
 *     unitsize configuration is not read if custom positions are reloaded per hotkey
 *     rewrite and better document unitsize configuration (remove "Default.")
 *     fix positioning of UnitSize/PositionSize when in CORNER_TOP_LEFT
 *     option to display 100% margin level
 *     high spread marker (BTCUSD suddenly has an average spread of 70-100 points)
 *
 *  - ALMA
 *     merge includes icALMA() and functions/ta/ALMA.mqh
 *     replace manual StdDev calculation
 *
 *  - Tunnel
 *     support MA method MODE_ALMA
 *
 *  - MACD
 *     add period stepping
 *
 *  - SuperBars
 *     detect weekend sessions and remove config [SuperBars]->Weekend.Symbols
 *
 *  - iCustom(): limit calculated bars in online charts
 *  - Bybit: adjust slippage to prevent ERR_OFF_QUOTES (dealing desk)
 *  - rewrite stdfunctions::GetCommission()
 */
#include <rsf/stddefines.mqh>
int   __InitFlags[];
int __DeinitFlags[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern string Tunnel.MA.Method               = "SMA | LWMA* | EMA | SMMA | ALMA";   // required
extern int    Tunnel.MA.Periods              = 55;

extern string MA.Method                      = "SMA | LWMA | EMA | SMMA | ALMA*";
extern int    MA.Periods                     = 10;                                  // optional, original EMA(5)

extern string ___a__________________________ = "=== Display settings ===";
extern color  Histogram.Color.Upper          = LimeGreen;
extern color  Histogram.Color.Lower          = Red;
extern int    Histogram.Width                = 2;
extern int    MaxBarsBack                    = 10000;                               // max. values to calculate (-1: all available)

extern string ___b__________________________ = "=== Signaling ===";
extern bool   Signal.onTrendChange           = false;
extern string Signal.onTrendChange.Types     = "sound* | alert | mail";
extern string Signal.Sound.Up                = "Signal Up.wav";
extern string Signal.Sound.Down              = "Signal Down.wav";

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <rsf/core/indicator.mqh>
#include <rsf/stdfunctions.mqh>
#include <rsf/stdlib.mqh>
#include <rsf/functions/ConfigureSignals.mqh>
#include <rsf/functions/IsBarOpen.mqh>
#include <rsf/functions/ObjectCreateRegister.mqh>
#include <rsf/functions/iCustom/MovingAverage.mqh>
#include <rsf/functions/iCustom/Tunnel.mqh>
#include <rsf/win32api.mqh>

#define MODE_MAIN             0                 // indicator buffer ids
#define MODE_TREND            1
#define MODE_UPTREND          2
#define MODE_DOWNTREND        3

#define HINT_CLOSE            1                 // trend hint ids
#define HINT_MA               2

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
string tunnel.definition = "";

int    ma.method;
int    ma.periods;

int    longestPeriod;

bool   signal.sound;
bool   signal.alert;
bool   signal.mail;

string indicatorName = "";

string trendHintCloseLabel = "";                // colored display of current bar and MA status (green/yellow/red)
string trendHintMaLabel    = "";
string trendHintFontName   = "Arial Black";
int    trendHintFontSize   = 8;
bool   trendHintsCreated   = false;


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   string indicator = WindowExpertName();

   // validate inputs
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
   longestPeriod = Max(tunnel.periods, ma.periods);
   // Histogram.Color.*: after deserialization the terminal might turn CLR_NONE (0xFFFFFFFF) into Black (0xFF000000)
   if (AutoConfiguration) Histogram.Color.Upper = GetConfigColor(indicator, "Histogram.Color.Upper", Histogram.Color.Upper);
   if (AutoConfiguration) Histogram.Color.Lower = GetConfigColor(indicator, "Histogram.Color.Lower", Histogram.Color.Lower);
   if (Histogram.Color.Upper == 0xFF000000) Histogram.Color.Upper = CLR_NONE;
   if (Histogram.Color.Lower == 0xFF000000) Histogram.Color.Lower = CLR_NONE;
   // Histogram.Width
   if (AutoConfiguration) Histogram.Width = GetConfigInt(indicator, "Histogram.Width", Histogram.Width);
   if (Histogram.Width < 0)                   return(catch("onInit(11)  invalid input parameter Histogram.Width: "+ Histogram.Width +" (valid range: 0-5)", ERR_INVALID_INPUT_PARAMETER));
   if (Histogram.Width > 5)                   return(catch("onInit(12)  invalid input parameter Histogram.Width: "+ Histogram.Width +" (valid range: 0-5)", ERR_INVALID_INPUT_PARAMETER));
   // MaxBarsBack
   if (AutoConfiguration) MaxBarsBack = GetConfigInt(indicator, "MaxBarsBack", MaxBarsBack);
   if (MaxBarsBack < -1)                      return(catch("onInit(13)  invalid input parameter MaxBarsBack: "+ MaxBarsBack, ERR_INVALID_INPUT_PARAMETER));
   if (MaxBarsBack == -1) MaxBarsBack = INT_MAX;
   // Signal.onTrendChange
   string signalId = "Signal.onTrendChange";
   ConfigureSignals(signalId, AutoConfiguration, Signal.onTrendChange);
   if (Signal.onTrendChange) {
      if (!ConfigureSignalTypes(signalId, Signal.onTrendChange.Types, AutoConfiguration, signal.sound, signal.alert, signal.mail)) {
         return(catch("onInit(14)  invalid input parameter Signal.onTrendChange.Types: "+ DoubleQuoteStr(Signal.onTrendChange.Types), ERR_INVALID_INPUT_PARAMETER));
      }
      Signal.onTrendChange = (signal.sound || signal.alert || signal.mail);
   }
   // Signal.Sound.*
   if (AutoConfiguration) Signal.Sound.Up   = GetConfigString(indicator, "Signal.Sound.Up",   Signal.Sound.Up);
   if (AutoConfiguration) Signal.Sound.Down = GetConfigString(indicator, "Signal.Sound.Down", Signal.Sound.Down);

   SetIndicatorOptions();
   return(catch("onInit(16)"));
}


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   // reset buffers before performing a full recalculation
   if (!ValidBars) {
      ArrayInitialize(bufferMain,  0);
      ArrayInitialize(bufferTrend, 0);
      ArrayInitialize(bufferUpper, 0);
      ArrayInitialize(bufferLower, 0);
      SetIndicatorOptions();
      if (!trendHintsCreated) {
         if (!CreateTrendHints()) return(last_error);       // calls WindowFind(self) which can't be used in CF_INIT
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
   int startbar = Min(MaxBarsBack-1, ChangedBars-1, Bars-longestPeriod);
   if (startbar < 0 && MaxBarsBack) return(logInfo("onTick(1)  Tick="+ Ticks, ERR_HISTORY_INSUFFICIENT));

   double upperBand, lowerBand, ma;

   // recalculate changed bars
   for (int bar=startbar; bar >= 0; bar--) {
      upperBand = GetTunnel(MODE_UPPER, bar);
      lowerBand = GetTunnel(MODE_LOWER, bar);
      ma = GetMovingAverage(bar);

      if (Close[bar] > upperBand && ma > upperBand) {
         bufferMain [bar] = 1;
         bufferUpper[bar] = bufferMain[bar];
         bufferLower[bar] = 0;
      }
      else if (Close[bar] < lowerBand && ma < lowerBand) {
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
      }

      // monitor signals
      if (Signal.onTrendChange) /*&&*/ if (IsBarOpen()) {
         int trend     = Round(bufferMain[1]);
         int prevTrend = Round(bufferMain[2]);

         if (Sign(trend) != Sign(prevTrend)) {
            if      (trend > 0) onTrendChange(MODE_UPTREND);
            else if (trend < 0) onTrendChange(MODE_DOWNTREND);
         }
      }
   }
   return(catch("onTick(2)"));
}


/**
 * Event handler called on BarOpen if direction of the trend changed.
 *
 * @param  int direction
 *
 * @return bool - success status
 */
bool onTrendChange(int direction) {
   if (direction!=MODE_UPTREND && direction!=MODE_DOWNTREND) return(!catch("onTrendChange(1)  invalid parameter direction: "+ direction, ERR_INVALID_PARAMETER));

   // skip the signal if it was already processed elsewhere
   int hWnd = ifInt(__isTesting, __ExecutionContext[EC.chart], GetDesktopWindow());
   string sPeriod = PeriodDescription();
   string sEvent  = "rsf::"+ StdSymbol() +","+ sPeriod +"."+ indicatorName +".onTrendChange("+ direction +")."+ TimeToStr(Time[0]);
   if (GetWindowPropertyA(hWnd, sEvent) != 0) return(true);
   SetWindowPropertyA(hWnd, sEvent, 1);                        // mark immediately to prevent duplicates from other instances

   string message = "Tunnel signal "+ ifString(direction==MODE_UPTREND, "up", "down") +" (bid: "+ NumberToStr(_Bid, PriceFormat) +")";
   if (IsLogInfo()) logInfo("onTrendChange(2)  "+ message);

   message = Symbol() +","+ PeriodDescription() +": "+ message;
   string sAccount = "("+ TimeToStr(TimeLocalEx("onTrendChange(3)"), TIME_MINUTES|TIME_SECONDS) +", "+ GetAccountAlias() +")";

   if (signal.alert) Alert(message);
   if (signal.sound) PlaySoundEx(ifString(direction==MODE_UPTREND, Signal.Sound.Up, Signal.Sound.Down));
   if (signal.mail)  SendEmail("", "", message, message + NL + sAccount);
   return(!catch("onTrendChange(4)"));
}


/**
 * Get a band value of the "Tunnel" indicator.
 *
 * @param  int mode - band identifier: MODE_UPPER | MODE_LOWER
 * @param  int bar  - bar offset
 *
 * @return double - band value or NULL in case of errors
 */
double GetTunnel(int mode, int bar) {
   if (tunnel.method == MODE_ALMA) {
      static int buffers[] = {0, Tunnel.MODE_UPPER_BAND, Tunnel.MODE_LOWER_BAND};
      return(icTunnel(NULL, tunnel.definition, buffers[mode], bar));
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
      double value = icMovingAverage(NULL, "ALMA", ma.periods, "close", MovingAverage.MODE_MA, bar);

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
 * Create chart objects for the trend hints.
 *
 * @return bool - success status
 */
bool CreateTrendHints() {
   if (__isSuperContext || !__isChart) return(true);

   string prefix = "rsf."+ WindowExpertName() +".";
   string sPid = "["+ __ExecutionContext[EC.pid] +"]";
   int window = WindowFind(indicatorName);
   if (window == -1) return(!catch("CreateTrendHints(1)->WindowFind(\""+ indicatorName +"\") => -1", ERR_RUNTIME_ERROR));

   string label = prefix +"Close"+ sPid;
   if (ObjectFind(label) == -1) if (!ObjectCreateRegister(label, OBJ_LABEL, window)) return(false);
   ObjectSet    (label, OBJPROP_CORNER, CORNER_TOP_RIGHT);
   ObjectSet    (label, OBJPROP_XDISTANCE, 37);
   ObjectSet    (label, OBJPROP_YDISTANCE,  1);
   ObjectSetText(label, " ");
   trendHintCloseLabel = label;

   label = prefix +"MA"+ sPid;
   if (ObjectFind(label) == -1) if (!ObjectCreateRegister(label, OBJ_LABEL, window)) return(false);
   ObjectSet    (label, OBJPROP_CORNER, CORNER_TOP_RIGHT);
   ObjectSet    (label, OBJPROP_XDISTANCE, 7);
   ObjectSet    (label, OBJPROP_YDISTANCE, 1);
   ObjectSetText(label, " ");
   trendHintMaLabel = label;

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
      default:
         return(!catch("UpdateTrendHint(1)  invalid parameter id: "+ id, ERR_INVALID_PARAMETER));
   }

   int error = GetLastError();               // on ObjectDrag or opened "Properties" dialog
   if (error && error!=ERR_OBJECT_DOES_NOT_EXIST) catch("UpdateTrendHint(2)", error);
}


/**
 * Set indicator options. After recompilation the function must be called from start() for options not to be ignored.
 *
 * @param  bool redraw [optional] - whether to redraw the chart (default: no)
 *
 * @return bool - success status
 */
bool SetIndicatorOptions(bool redraw = false) {
   indicatorName = WindowExpertName();
   IndicatorShortName(indicatorName);

   IndicatorBuffers(indicator_buffers);
   SetIndexBuffer(MODE_MAIN,      bufferMain ); SetIndexEmptyValue(MODE_MAIN,      0); SetIndexLabel(MODE_MAIN,      indicatorName);
   SetIndexBuffer(MODE_TREND,     bufferTrend); SetIndexEmptyValue(MODE_TREND,     0); SetIndexLabel(MODE_TREND,     "Tunnel trend");
   SetIndexBuffer(MODE_UPTREND,   bufferUpper); SetIndexEmptyValue(MODE_UPTREND,   0); SetIndexLabel(MODE_UPTREND,   NULL);
   SetIndexBuffer(MODE_DOWNTREND, bufferLower); SetIndexEmptyValue(MODE_DOWNTREND, 0); SetIndexLabel(MODE_DOWNTREND, NULL);
   IndicatorDigits(0);

   int drawType = ifInt(Histogram.Width, DRAW_HISTOGRAM, DRAW_NONE);
   SetIndexStyle(MODE_MAIN,      DRAW_NONE);
   SetIndexStyle(MODE_TREND,     DRAW_NONE);
   SetIndexStyle(MODE_UPTREND,   drawType, EMPTY, Histogram.Width, Histogram.Color.Upper);
   SetIndexStyle(MODE_DOWNTREND, drawType, EMPTY, Histogram.Width, Histogram.Color.Lower);

   if (redraw) WindowRedraw();
   return(!catch("SetIndicatorOptions(1)"));
}


/**
 * Return a string representation of all input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("Tunnel.MA.Method=",           DoubleQuoteStr(Tunnel.MA.Method),           ";"+ NL,
                            "Tunnel.MA.Periods=",          Tunnel.MA.Periods,                          ";"+ NL,

                            "MA.Method=",                  DoubleQuoteStr(MA.Method),                  ";"+ NL,
                            "MA.Periods=",                 MA.Periods,                                 ";"+ NL,

                            "Histogram.Color.Upper=",      ColorToStr(Histogram.Color.Upper),          ";"+ NL,
                            "Histogram.Color.Lower=",      ColorToStr(Histogram.Color.Lower),          ";"+ NL,
                            "Histogram.Width=",            Histogram.Width,                            ";"+ NL,
                            "MaxBarsBack=",                MaxBarsBack,                                ";"+ NL,

                            "Signal.onTrendChange=",       BoolToStr(Signal.onTrendChange),            ";"+ NL,
                            "Signal.onTrendChange.Types=", DoubleQuoteStr(Signal.onTrendChange.Types), ";"+ NL,
                            "Signal.Sound.Up=",            DoubleQuoteStr(Signal.Sound.Up),            ";"+ NL,
                            "Signal.Sound.Down=",          DoubleQuoteStr(Signal.Sound.Down),          ";")
   );
}
