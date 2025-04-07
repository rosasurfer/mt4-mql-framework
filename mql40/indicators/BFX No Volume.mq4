/**
 * BFX No Volume
 *
 * Wrapper for the "BankersFX Core Volume" indicator which displays an oscillator promoted as real "Trading Floor Volume",
 * feeded by institutional data. In fact the indicator is calculated client-side using price only (no external data source).
 *
 * Indicator buffers for iCustom():
 *  • MODE_MAIN:   indicator values
 *  • MODE_SIGNAL: signal direction and periods since last crossing of the opposite signal level
 *    - direction: positive values represent an indicator value above the negative signal level (+1...+n),
 *                 negative values represent an indicator value below the positive signal level (-1...-n)
 *    - length:    the absolute value is the period in bars since the last crossing of the opposite signal level
 *
 * @link  https://github.com/rosasurfer/bfx-core-volume
 */
#include <rsf/stddefines.mqh>
int   __InitFlags[];
int __DeinitFlags[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern string ___a__________________________ = "=== General ===";
extern string Symbol.Prefix                  = "";
extern string Symbol.Suffix                  = "";
extern string LicenseKey                     = "BANKERSSCAM";

extern string ___b__________________________ = "=== Display ===";
extern color  Histogram.Color.Long           = Blue;
extern color  Histogram.Color.Short          = Red;
extern int    Histogram.Style.Width          = 2;
extern int    MaxBarsBack                    = 10000;          // max. values to calculate (-1: all available)

extern string ___c__________________________ = "=== Signaling ===";
extern int    Signal.Level                   = 20;
extern bool   Signal.onCross                 = false;
extern string Signal.onCross.Types           = "sound* | alert | mail | sms";
extern string Signal.Sound.Up                = "Signal Up.wav";
extern string Signal.Sound.Down              = "Signal Down.wav";

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <rsf/core/indicator.mqh>
#include <rsf/stdfunctions.mqh>
#include <rsf/stdlib.mqh>
#include <rsf/functions/ConfigureSignals.mqh>
#include <rsf/functions/IsBarOpen.mqh>

#define MODE_CVI_LONG         0                                // the "Core Volume" indicator's buffer ids
#define MODE_CVI_SHORT        1
#define MODE_CVI_SIGNAL       2

#define MODE_MAIN             0                                // this indicator's buffer ids
#define MODE_SIGNAL           1
#define MODE_LONG             2
#define MODE_SHORT            3

#property indicator_separate_window
#property indicator_buffers   4

#property indicator_width1    0
#property indicator_width2    0
#property indicator_width3    2
#property indicator_width4    2

double bufferMain  [];                                         // all values:           invisible, displayed in "Data" window
double bufferSignal[];                                         // direction and length: invisible
double bufferLong  [];                                         // long values:          visible
double bufferShort [];                                         // short values:         visible

string bfxIndicatorName  = "BFX Core Volume v1.20.0";
string bfxLibraryName    = "BankersFX Lib";

bool   signal.sound;
bool   signal.alert;
bool   signal.mail;
bool   signal.sms;


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   string indicator = WindowExpertName();

   // validate inputs
   // Symbol.Prefix
   string sValue = StrTrim(Symbol.Prefix);
   if (AutoConfiguration) sValue = GetConfigString(indicator, "Symbol.Prefix", sValue);
   if (StringLen(sValue) > MAX_SYMBOL_LENGTH-1) return(catch("onInit(1)  invalid input parameter Symbol.Prefix: "+ DoubleQuoteStr(Symbol.Prefix) +" (max "+ (MAX_SYMBOL_LENGTH-1) +" chars)", ERR_INVALID_INPUT_PARAMETER));
   Symbol.Prefix = sValue;

   // Symbol.Suffix
   sValue = StrTrim(Symbol.Suffix);
   if (AutoConfiguration) sValue = GetConfigString(indicator, "Symbol.Suffix", sValue);
   if (StringLen(sValue) > MAX_SYMBOL_LENGTH-1) return(catch("onInit(2)  invalid input parameter Symbol.Suffix: "+ DoubleQuoteStr(Symbol.Suffix) +" (max "+ (MAX_SYMBOL_LENGTH-1) +" chars)", ERR_INVALID_INPUT_PARAMETER));
   Symbol.Suffix = sValue;

   // LicenseKey
   sValue = StrTrim(LicenseKey);
   if (AutoConfiguration) sValue = GetConfigString(indicator, "LicenseKey", sValue);
   if (StringLen(sValue) != 11) return(catch("onInit(3)  invalid input parameter LicenseKey: "+ DoubleQuoteStr(LicenseKey) +" (must be "+ (MAX_SYMBOL_LENGTH-1) +" chars)", ERR_INVALID_INPUT_PARAMETER));
   LicenseKey = sValue;

   // colors: after deserialization the terminal might turn CLR_NONE (0xFFFFFFFF) into Black (0xFF000000)
   if (Histogram.Color.Long  == 0xFF000000) Histogram.Color.Long  = CLR_NONE;
   if (Histogram.Color.Short == 0xFF000000) Histogram.Color.Short = CLR_NONE;

   // Histogram.Style.Width
   if (Histogram.Style.Width < 0) return(catch("onInit(4)  invalid input parameter Histogram.Style.Width: "+ Histogram.Style.Width, ERR_INVALID_INPUT_PARAMETER));
   if (Histogram.Style.Width > 5) return(catch("onInit(5)  invalid input parameter Histogram.Style.Width: "+ Histogram.Style.Width, ERR_INVALID_INPUT_PARAMETER));

   // MaxBarsBack
   if (MaxBarsBack < -1)          return(catch("onInit(6)  invalid input parameter MaxBarsBack: "+ MaxBarsBack, ERR_INVALID_INPUT_PARAMETER));
   if (MaxBarsBack == -1) MaxBarsBack = INT_MAX;

   // Signal.Level
   if (Signal.Level <    0)       return(catch("onInit(7)  invalid input parameter Signal.Level: "+ Signal.Level, ERR_INVALID_INPUT_PARAMETER));
   if (Signal.Level >= 100)       return(catch("onInit(8)  invalid input parameter Signal.Level: "+ Signal.Level, ERR_INVALID_INPUT_PARAMETER));

   // signal configuration
   string signalId = "Signal.onCross";
   if (!ConfigureSignals(signalId, AutoConfiguration, Signal.onCross)) return(last_error);
   if (Signal.onCross) {
      if (!ConfigureSignalTypes(signalId, Signal.onCross.Types, AutoConfiguration, signal.sound, signal.alert, signal.mail, signal.sms)) {
         return(catch("onInit(9)  invalid input parameter Signal.onCross.Types: "+ DoubleQuoteStr(Signal.onCross.Types), ERR_INVALID_INPUT_PARAMETER));
      }
      Signal.onCross = (signal.sound || signal.alert || signal.mail || signal.sms);
   }

   // Signal.Sound.*
   if (AutoConfiguration) Signal.Sound.Up   = GetConfigString(indicator, "Signal.Sound.Up",   Signal.Sound.Up);
   if (AutoConfiguration) Signal.Sound.Down = GetConfigString(indicator, "Signal.Sound.Down", Signal.Sound.Down);

   // find BFX indicator files
   if (!FindBfxIndicator()) return(last_error);

   SetIndicatorOptions();
   return(catch("onInit(10)"));
}


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   // wait for account number initialization (required for BFX license validation)
   if (!AccountNumber()) return(logInfo("onInit(1)  waiting for account number initialization", SetLastError(ERS_TERMINAL_NOT_YET_READY)));

   // reset buffers before performing a full recalculation
   if (!ValidBars) {
      ArrayInitialize(bufferMain,  EMPTY_VALUE);
      ArrayInitialize(bufferSignal,          0);
      ArrayInitialize(bufferLong,  EMPTY_VALUE);
      ArrayInitialize(bufferShort, EMPTY_VALUE);
      SetIndicatorOptions();
   }

   // synchronize buffers with a shifted offline chart
   if (ShiftedBars > 0) {
      ShiftDoubleIndicatorBuffer(bufferMain,   Bars, ShiftedBars, EMPTY_VALUE);
      ShiftDoubleIndicatorBuffer(bufferSignal, Bars, ShiftedBars,           0);
      ShiftDoubleIndicatorBuffer(bufferLong,   Bars, ShiftedBars, EMPTY_VALUE);
      ShiftDoubleIndicatorBuffer(bufferShort,  Bars, ShiftedBars, EMPTY_VALUE);
   }

   // calculate start bar
   int startbar = Min(MaxBarsBack-1, ChangedBars-1);
   if (startbar < 0 && MaxBarsBack) return(logInfo("onTick(3)  Tick="+ Ticks, ERR_HISTORY_INSUFFICIENT));

   // recalculate changed bars
   double value = 0;
   for (int bar=startbar; bar >= 0; bar--) {
      bufferLong [bar] = GetBfxValue(MODE_CVI_LONG, bar);  if (last_error != NO_ERROR) return(last_error);
      bufferShort[bar] = GetBfxValue(MODE_CVI_SHORT, bar); if (last_error != NO_ERROR) return(last_error);

      value = EMPTY_VALUE;
      if      (bufferLong [bar] != EMPTY_VALUE) value = bufferLong [bar];
      else if (bufferShort[bar] != EMPTY_VALUE) value = bufferShort[bar];
      bufferMain[bar] = value;

      // update signal level and duration since last crossing of the opposite level
      if (bar < Bars-1 && value != EMPTY_VALUE) {
         // if the last signal was up
         if (bufferSignal[bar+1] > 0) {
            if (value > -Signal.Level) bufferSignal[bar] = bufferSignal[bar+1] + 1; // continuation up
            else                       bufferSignal[bar] = -1;                      // opposite signal (down)
         }

         // if the last signal was down
         else if (bufferSignal[bar+1] < 0) {
            if (value < Signal.Level) bufferSignal[bar] = bufferSignal[bar+1] - 1;  // continuation down
            else                      bufferSignal[bar] = 1;                        // opposite signal (up)
         }

         // if there was no signal yet
         else /*(bufferSignal[bar+1] == 0)*/ {
            if      (value >=  Signal.Level) bufferSignal[bar] =  1;                // first signal up
            else if (value <= -Signal.Level) bufferSignal[bar] = -1;                // first signal down
            else                             bufferSignal[bar] =  0;                // still no signal
         }
      }
   }

   // signal zero line crossings
   if (!__isSuperContext) {
      if (Signal.onCross) /*&&*/ if (IsBarOpen()) {
         int iSignal = Round(bufferSignal[1]);
         if      (iSignal ==  1) onLevelCross(MODE_LONG);
         else if (iSignal == -1) onLevelCross(MODE_SHORT);
      }
   }
   return(last_error);
}


/**
 * Event handler called on BarOpen if the indicator crossed the signal level.
 *
 * @param  int direction - signal level identifier
 *
 * @return bool - success status
 */
bool onLevelCross(int direction) {
   if (direction!=MODE_LONG && direction!=MODE_SHORT) return(!catch("onLevelCross(1)  invalid parameter direction: "+ direction, ERR_INVALID_PARAMETER));
   string indicatorName = ProgramName();

   // skip the signal if it already has been signaled elsewhere
   int hWnd = ifInt(__isTesting, __ExecutionContext[EC.chart], GetDesktopWindow());
   string sPeriod = PeriodDescription();
   string sEvent  = "rsf::"+ StdSymbol() +","+ sPeriod +"."+ indicatorName +".onCross("+ ifInt(direction==MODE_LONG, Signal.Level, -Signal.Level) +")."+ TimeToStr(Time[0]);
   if (GetPropA(hWnd, sEvent) != 0) return(true);
   SetPropA(hWnd, sEvent, 1);                         // immediately mark as signaled (prevents duplicate signals on slow CPU)

   string message = indicatorName +" crossed level "+ ifInt(direction==MODE_LONG, Signal.Level, -Signal.Level);
   if (IsLogInfo()) logInfo("onLevelCross(2)  "+ message);

   message = Symbol() +","+ PeriodDescription() +": "+ message;
   string sAccount = "("+ TimeToStr(TimeLocalEx("onLevelCross(3)"), TIME_MINUTES|TIME_SECONDS) +", "+ GetAccountAlias() +")";

   if (signal.alert) Alert(message);
   if (signal.sound) PlaySoundEx(ifString(direction==MODE_LONG, Signal.Sound.Up, Signal.Sound.Down));
   if (signal.mail)  SendEmail("", "", message, message + NL + sAccount);
   if (signal.sms)   SendSMS("", message + NL + sAccount);
   return(!catch("onLevelCross(4)"));
}


/**
 * Check existence of BFX indicator and library.
 *
 * @return bool - success status
 */
bool FindBfxIndicator() {
   string mqlPath = GetMqlDirectoryA();
   string indicatorsPath = mqlPath +"/indicators/";
   string librariesPath  = mqlPath +"/libraries/";

   string indicatorFilepath = indicatorsPath + bfxIndicatorName +".ex4";
   if (!IsFile(indicatorFilepath, MODE_SYSTEM)) {
      indicatorFilepath = indicatorsPath +"MQL5/"+ bfxIndicatorName +".ex4";
      if (!IsFile(indicatorFilepath, MODE_SYSTEM)) {
         return(!catch("FindBfxIndicator(1)  BankersFX Core Volume indicator not found: "+ DoubleQuoteStr(bfxIndicatorName), ERR_FILE_NOT_FOUND));
      }
      bfxIndicatorName = "MQL5/"+ bfxIndicatorName;
   }

   string libraryFilepath = librariesPath + bfxLibraryName +".ex4";
   if (!IsFile(libraryFilepath, MODE_SYSTEM)) {
      return(!catch("FindBfxIndicator(2)  BankersFX Core Volume library not found: "+ DoubleQuoteStr(bfxLibraryName), ERR_FILE_NOT_FOUND));
   }
   return(true);
}


/**
 * Load the BFX Core Volume indicator and return an indicator value.
 *
 * @param  int buffer - buffer index of the value to return
 * @param  int bar    - bar index of the value to return
 *
 * @return double - indicator value or NULL in case of errors (short values are returned as negative values)
 */
double GetBfxValue(int buffer, int bar) {
   string separator      = "•••••••••••••••••••••••••••••••••••"; // title1         init() error if an empty string
   string bfxLicense     = LicenseKey;                            // UserID
   int    serverId       = 0;                                     // ServerURL
   int    loginTries     = 1;                                     // Retries        minimum = 1 (in fact tries, not retries)
   string symbolPrefix   = Symbol.Prefix;                         // Prefix
   string symbolSuffix   = Symbol.Suffix;                         // Suffix
   color  colorLong      = Red;                                   // PositiveState
   color  colorShort     = Green;                                 // NegativeState
   color  colorLevel     = Gray;                                  // Level
   int    histogramWidth = 2;                                     // WidthStateBars
   bool   signalAlert    = false;                                 // Alerts
   bool   signalPopup    = false;                                 // PopUp
   bool   signalSound    = false;                                 // Sound
   bool   signalMobile   = false;                                 // Mobile
   bool   signalEmail    = false;                                 // Email

   int error;

   // check indicator initialization with signal level on bar 0
   static bool initialized = false; if (!initialized) {
      double level = iCustom(NULL, NULL, bfxIndicatorName,
                             separator, bfxLicense, serverId, loginTries, symbolPrefix, symbolSuffix, colorLong, colorShort, colorLevel, histogramWidth, signalAlert, signalPopup, signalSound, signalMobile, signalEmail,
                             MODE_CVI_SIGNAL, 0);
      if (level == EMPTY_VALUE) {
         error = GetLastError();
         return(!catch("GetBfxValue(1)  initialization of indicator "+ DoubleQuoteStr(bfxIndicatorName) +" failed", intOr(error, ERR_CUSTOM_INDICATOR_ERROR)));
      }
      initialized = true;
   }

   // get the requested value
   double value = iCustom(NULL, NULL, bfxIndicatorName,
                          separator, bfxLicense, serverId, loginTries, symbolPrefix, symbolSuffix, colorLong, colorShort, colorLevel, histogramWidth, signalAlert, signalPopup, signalSound, signalMobile, signalEmail,
                          buffer, bar);

   if (buffer == MODE_CVI_SHORT) {
      if (value != EMPTY_VALUE)
         value = -value;                                          // convert short values to negative values
   }

   error = GetLastError();
   if (error != NO_ERROR)
      return(!catch("GetBfxValue(2)", error));
   return(value);
}


/**
 * Set indicator options. After recompilation the function must be called from start() for options not to be ignored.
 *
 * @param  bool redraw [optional] - whether to redraw the chart (default: no)
 *
 * @return bool - success status
 */
bool SetIndicatorOptions(bool redraw = false) {
   redraw = redraw!=0;

   IndicatorBuffers(indicator_buffers);
   SetIndexBuffer(MODE_MAIN,   bufferMain  );            // all values:           invisible, displayed in "Data" window
   SetIndexBuffer(MODE_SIGNAL, bufferSignal);            // direction and length: invisible
   SetIndexBuffer(MODE_LONG,   bufferLong  );            // long values:          visible
   SetIndexBuffer(MODE_SHORT,  bufferShort );            // short values:         visible

   int drawType = ifInt(Histogram.Style.Width, DRAW_HISTOGRAM, DRAW_NONE);
   SetIndexStyle(MODE_MAIN,   DRAW_NONE, EMPTY, EMPTY,                 CLR_NONE             );
   SetIndexStyle(MODE_SIGNAL, DRAW_NONE, EMPTY, EMPTY,                 CLR_NONE             );
   SetIndexStyle(MODE_LONG,   drawType,  EMPTY, Histogram.Style.Width, Histogram.Color.Long );
   SetIndexStyle(MODE_SHORT,  drawType,  EMPTY, Histogram.Style.Width, Histogram.Color.Short);

   string name = ProgramName();
   IndicatorShortName(name + ifString(Signal.onCross, "   signal=on", "") +"  ");
   SetIndexLabel(MODE_MAIN,   name);
   SetIndexLabel(MODE_SIGNAL, NULL);
   SetIndexLabel(MODE_LONG,   NULL);
   SetIndexLabel(MODE_SHORT,  NULL);

   SetLevelValue(0,  Signal.Level);
   SetLevelValue(1, -Signal.Level);

   IndicatorDigits(2);

   if (redraw) WindowRedraw();
   return(!catch("SetIndicatorOptions(1)"));
}


/**
 * Return a string representation of all input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("Symbol.Prefix=",         DoubleQuoteStr(Symbol.Prefix),        ";", NL,
                            "Symbol.Suffix=",         DoubleQuoteStr(Symbol.Suffix),        ";", NL,
                            "LicenseKey=",            DoubleQuoteStr(LicenseKey),           ";", NL,

                            "Histogram.Color.Long=",  ColorToStr(Histogram.Color.Long),     ";", NL,
                            "Histogram.Color.Short=", ColorToStr(Histogram.Color.Short),    ";", NL,
                            "Histogram.Style.Width=", Histogram.Style.Width,                ";", NL,
                            "MaxBarsBack=",           MaxBarsBack,                          ";", NL,

                            "Signal.Level=",          Signal.Level,                         ";", NL,
                            "Signal.onCross=",        BoolToStr(Signal.onCross),            ";"+ NL,
                            "Signal.onCross.Types=",  DoubleQuoteStr(Signal.onCross.Types), ";"+ NL,
                            "Signal.Sound.Up=",       DoubleQuoteStr(Signal.Sound.Up),      ";"+ NL,
                            "Signal.Sound.Down=",     DoubleQuoteStr(Signal.Sound.Down),    ";")
   );
}
