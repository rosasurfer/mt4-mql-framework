/**
 * LFX Monitor
 *
 * Calculates various synthetic indexes and optionally records the index history. If linked to an LFX charting terminal the
 * indicator can monitor and process order limits of synthetic positions. For index descriptions see the following link:
 *
 * @see  https://github.com/rosasurfer/mt4-tools/tree/master/app/lib/synthetic
 * @see  https://www.forexfactory.com/thread/post/13783504#post13783504
 *
 *
 * Input parameters:
 * -----------------
 * • USDLFX.Enabled:  Whether calculation of the USDLFX index is enabled.
 * • AUDLFX.Enabled:  Whether calculation of the AUDLFX index is enabled.
 * • CADLFX.Enabled:  Whether calculation of the CADLFX index is enabled.
 * • CHFLFX.Enabled:  Whether calculation of the CHFLFX index is enabled.
 * • EURLFX.Enabled:  Whether calculation of the EURLFX index is enabled.
 * • GBPLFX.Enabled:  Whether calculation of the GBPLFX index is enabled.
 * • JPYLFX.Enabled:  Whether calculation of the JPYLFX index is enabled.
 * • NZDLFX.Enabled:  Whether calculation of the NZDLFX index is enabled.
 *
 * • NOKFX7.Enabled:  Whether calculation of the NOKFX7 index is enabled.
 * • SEKFX7.Enabled:  Whether calculation of the SEKFX7 index is enabled.
 * • SGDFX7.Enabled:  Whether calculation of the SGDFX7 index is enabled.
 * • ZARFX7.Enabled:  Whether calculation of the ZARFX7 index is enabled.
 *
 * • EURX.Enabled:  Whether calculation of the ICE EURX index is enabled.
 * • USDX.Enabled:  Whether calculation of the ICE USDX index is enabled.
 *
 * • XAUI.Enabled:  Whether calculation of the Gold index is enabled.
 *
 * • Recording.Enabled:  Whether recording of active indexes is enabled. If FALSE indexes active indexes are only calculated
 *    and displayed.
 *
 * • Recording.HistoryDirectory:  Name of the history directory to store recorded data. Must be a located in the "MQL4/files"
 *    directory. If the directory doesn't exist it is created. The name may contain subdirectories and supports both forward
 *    and backward slashes.
 *
 * • Recording.HistoryFormat:  Created history format if an history file doesn't yet exist. If an history file already exists
 *    it's re-used (in any format) and the format is not changed.
 *
 * • Broker.SymbolSuffix:  Symbol suffix for brokers with non-standard symbols.
 *
 * • AutoConfiguration:  For simplicity all manual inputs may also be specified in the MetaTrader framework configuration.
 *    If "AutoConfiguration" is enabled configuration settings found in the configuration files override manual settings in
 *    the indicator's input dialog. Additional auto-config settings not available in the input dialog:
 *
 *    [LFX-Monitor]
 *     Status.xDistance          = {int}                 ; horizontal offset from right in pixels
 *     Status.yDistance          = {int}                 ; vertical offset from top in pixels
 *     Status.BgColor            = {color}               ; background color (web color name, integer or RGB triplet)
 *     Status.FontName           = {string}              ; font family
 *     Status.FontSize           = {int}                 ; font size
 *     Status.FontColor.Active   = {color}               ; font color of active indexes
 *     Status.FontColor.Inactive = {color}               ; font color of inactive indexes
 *     Status.LineHeight         = {int}                 ; line height of status rows
 *
 *
 * TODO:
 *  - documentation
 *     auto-configuration
 *     symbol requirements
 *     timezone configuration for detection of stale quotes
 *     requirements for "Recording.HistoryDirectory"
 *     handling of different history formats
 *
 *  - improve cache flushing for the different timeframes
 *  - move history libraries to MT4Expander
 */
#include <stddefines.mqh>
int   __InitFlags[] = {INIT_TIMEZONE};
int __DeinitFlags[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern string ___a__________________________ = "=== Synthetic FX6 indexes (LiteForex) ===";
extern bool   USDLFX.Enabled                 = true;
extern bool   AUDLFX.Enabled                 = false;
extern bool   CADLFX.Enabled                 = false;
extern bool   CHFLFX.Enabled                 = false;
extern bool   EURLFX.Enabled                 = false;
extern bool   GBPLFX.Enabled                 = false;
extern bool   JPYLFX.Enabled                 = false;
extern bool   NZDLFX.Enabled                 = false;                  // in fact an FX7 index
extern string ___b__________________________ = "=== Synthetic FX7 indexes ===";
extern bool   NOKFX7.Enabled                 = false;
extern bool   SEKFX7.Enabled                 = false;
extern bool   SGDFX7.Enabled                 = false;
extern bool   ZARFX7.Enabled                 = false;
extern string ___c__________________________ = "=== ICE indexes ===";
extern bool   EURX.Enabled                   = false;
extern bool   USDX.Enabled                   = true;
extern string ___d__________________________ = "=== Synthetic Gold index ===";
extern bool   XAUI.Enabled                   = false;
extern string ___e__________________________ = "=== Recording settings ===";
extern bool   Recording.Enabled              = false;
extern string Recording.HistoryDirectory     = "Synthetic-History";    // name of the directory to store recorded data
extern int    Recording.HistoryFormat        = 401;                    // written history format
extern string ___f__________________________ = "=== Broker settings ===";
extern string Broker.SymbolSuffix            = "";                     // symbol suffix for brokers with non-standard symbols

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <rsfLib.mqh>
#include <rsfHistory.mqh>
#include <functions/HandleCommands.mqh>
#include <functions/InitializeByteBuffer.mqh>
#include <MT4iQuickChannel.mqh>
#include <lfx.mqh>
#include <structs/rsf/LFXOrder.mqh>

#property indicator_chart_window
#property indicator_buffers      1                       // there's a minimum of 1 buffer
#property indicator_color1       CLR_NONE

#define I_AUDUSD     0                                   // broker symbol array indexes
#define I_EURUSD     1
#define I_GBPUSD     2
#define I_NZDUSD     3
#define I_USDCAD     4
#define I_USDCHF     5
#define I_USDJPY     6
#define I_USDNOK     7
#define I_USDSEK     8
#define I_USDSGD     9
#define I_USDZAR    10
#define I_XAUUSD    11

#define I_AUDLFX     0                                   // synthetic instrument array indexes
#define I_CADLFX     1
#define I_CHFLFX     2
#define I_EURLFX     3
#define I_GBPLFX     4
#define I_JPYLFX     5
#define I_NZDLFX     6
#define I_USDLFX     7
#define I_NOKFX7     8
#define I_SEKFX7     9
#define I_SGDFX7    10
#define I_ZARFX7    11
#define I_EURX      12
#define I_USDX      13
#define I_XAUI      14

string   brokerSuffix = "";                              // suffix for broker symbols
string   brokerSymbols    [] = {"AUDUSD", "EURUSD", "GBPUSD", "NZDUSD", "USDCAD", "USDCHF", "USDJPY", "USDNOK", "USDSEK", "USDSGD", "USDZAR", "XAUUSD"};
bool     isRequired       [];                            // whether a broker symbol is required for synthetic index calculation
string   missingSymbols   [];                            // not subscribed broker symbols (not available in "Market Watch" window)

string   syntheticSymbols [] = {"AUDLFX", "CADLFX", "CHFLFX", "EURLFX", "GBPLFX", "JPYLFX", "NZDLFX", "USDLFX", "NOKFX7", "SEKFX7", "SGDFX7", "ZARFX7", "EURX"  , "USDX"  , "XAUI" };
string   symbolLongName   [] = {"LiteForex Australian Dollar index", "LiteForex Canadian Dollar index", "LiteForex Swiss Franc index", "LiteForex Euro index", "LiteForex Great Britain Pound index", "LiteForex Japanese Yen index", "LiteForex New Zealand Dollar index", "LiteForex US Dollar index", "Norwegian Krona vs Majors index", "Swedish Kronor vs Majors index", "Singapore Dollar vs Majors index", "South African Rand vs Majors index", "ICE Euro Futures index", "ICE US Dollar Futures index", "Gold vs Majors index" };
int      symbolDigits     [] = {5       , 5       , 5       , 5       , 5       , 5       , 5       , 5       , 5       , 5       , 5       , 5       , 3       , 3       , 2      };
double   symbolPipSize    [] = {0.0001  , 0.0001  , 0.0001  , 0.0001  , 0.0001  , 0.0001  , 0.0001  , 0.0001  , 0.0001  , 0.0001  , 0.0001  , 0.0001  , 0.01    , 0.01    , 0.01   };
string   symbolPriceFormat[] = {",'R.4'", ",'R.4'", ",'R.4'", ",'R.4'", ",'R.4'", ",'R.4'", ",'R.4'", ",'R.4'", ",'R.4'", ",'R.4'", ",'R.4'", ",'R.4'", ",'R.2'", ",'R.2'", ",'R.2"};

bool     isEnabled  [];                                  // whether calculation of a synthetic instrument is enabled (matches inputs *.Enabled)
bool     isAvailable[];                                  // whether all quotes for instrument calculation are available
double   currBid    [];                                  // current calculated Bid value
double   currAsk    [];                                  // current calculated Ask value
double   currMid    [];                                  // current calculated Median value: (Bid+Ask)/2
double   prevMid    [];                                  // previous calculated Median value
bool     isStale    [];                                  // whether prices for calculation are stale (not updated anymore)
datetime staleLimit;                                     // time limit (server time) for stale quotes determination

int      hSet[];                                         // HistorySet handles
string   recordingDirectory = "";                        // directory to store recorded history
int      recordingFormat;                                // format of new history files: 400 | 401
int      tickTimerId;                                    // id of the tick timer registered for the chart

int AUDLFX.orders[][LFX_ORDER_intSize];                  // array of LFX orders
int CADLFX.orders[][LFX_ORDER_intSize];
int CHFLFX.orders[][LFX_ORDER_intSize];
int EURLFX.orders[][LFX_ORDER_intSize];
int GBPLFX.orders[][LFX_ORDER_intSize];
int JPYLFX.orders[][LFX_ORDER_intSize];
int NZDLFX.orders[][LFX_ORDER_intSize];
int USDLFX.orders[][LFX_ORDER_intSize];
int NOKFX7.orders[][LFX_ORDER_intSize];
int SEKFX7.orders[][LFX_ORDER_intSize];
int SGDFX7.orders[][LFX_ORDER_intSize];
int ZARFX7.orders[][LFX_ORDER_intSize];
int   EURX.orders[][LFX_ORDER_intSize];
int   USDX.orders[][LFX_ORDER_intSize];
int   XAUI.orders[][LFX_ORDER_intSize];

// status display vars
string statusLabels[];
string statusLabelTradeAccount  = "";
string statusLabelAnimation     = "";                    // animated ticker
string animationChars[]         = {"|", "/", "—", "\\"};

int    status_xDistance         = 7;
int    status_yDistance         = 60;
color  statusBgColor            = C'212,208,200';
color  statusFontColor.active   = Blue;
color  statusFontColor.inactive = Gray;
string statusFontName           = "Tahoma";
int    statusFontSize           = 8;                     // 8 matches the menu font size
int    statusLineHeight         = 15;


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   // read auto-configuration
   string indicator = ProgramName();
   if (AutoConfiguration) {
      // manual indicator inputs
      AUDLFX.Enabled             = GetConfigBool  (indicator, "AUDLFX.Enabled",             AUDLFX.Enabled);
      CADLFX.Enabled             = GetConfigBool  (indicator, "CADLFX.Enabled",             CADLFX.Enabled);
      CHFLFX.Enabled             = GetConfigBool  (indicator, "CHFLFX.Enabled",             CHFLFX.Enabled);
      EURLFX.Enabled             = GetConfigBool  (indicator, "EURLFX.Enabled",             EURLFX.Enabled);
      GBPLFX.Enabled             = GetConfigBool  (indicator, "GBPLFX.Enabled",             GBPLFX.Enabled);
      JPYLFX.Enabled             = GetConfigBool  (indicator, "JPYLFX.Enabled",             JPYLFX.Enabled);
      NZDLFX.Enabled             = GetConfigBool  (indicator, "NZDLFX.Enabled",             NZDLFX.Enabled);
      NOKFX7.Enabled             = GetConfigBool  (indicator, "NOKFX7.Enabled",             NOKFX7.Enabled);
      SEKFX7.Enabled             = GetConfigBool  (indicator, "SEKFX7.Enabled",             SEKFX7.Enabled);
      SGDFX7.Enabled             = GetConfigBool  (indicator, "SGDFX7.Enabled",             SGDFX7.Enabled);
      ZARFX7.Enabled             = GetConfigBool  (indicator, "ZARFX7.Enabled",             ZARFX7.Enabled);
      EURX.Enabled               = GetConfigBool  (indicator, "EURX.Enabled",               EURX.Enabled);
      USDX.Enabled               = GetConfigBool  (indicator, "USDX.Enabled",               USDX.Enabled);
      XAUI.Enabled               = GetConfigBool  (indicator, "XAUI.Enabled",               XAUI.Enabled);
      Recording.Enabled          = GetConfigBool  (indicator, "Recording.Enabled",          Recording.Enabled);
      Recording.HistoryDirectory = GetConfigString(indicator, "Recording.HistoryDirectory", Recording.HistoryDirectory);
      Recording.HistoryFormat    = GetConfigInt   (indicator, "Recording.HistoryFormat",    Recording.HistoryFormat);
      Broker.SymbolSuffix        = GetConfigString(indicator, "Broker.SymbolSuffix",        Broker.SymbolSuffix);

      // additional auto-config values for status display
      int iValue; color cValue; string sValue;
      iValue = GetConfigInt   (indicator, "Status.xDistance",          -1);                       status_xDistance         = ifInt(iValue >= 0, iValue, status_xDistance);
      iValue = GetConfigInt   (indicator, "Status.yDistance",          -1);                       status_yDistance         = ifInt(iValue >= 0, iValue, status_yDistance);
      cValue = GetConfigColor (indicator, "Status.BgColor",            statusBgColor);            statusBgColor            = cValue;
      sValue = GetConfigString(indicator, "Status.FontName",           statusFontName);           statusFontName           = sValue;
      iValue = GetConfigInt   (indicator, "Status.FontSize",           -1);                       statusFontSize           = ifInt(iValue > 0, iValue, statusFontSize);
      cValue = GetConfigColor (indicator, "Status.FontColor.Active",   statusFontColor.active);   statusFontColor.active   = cValue;
      cValue = GetConfigColor (indicator, "Status.FontColor.Inactive", statusFontColor.inactive); statusFontColor.inactive = cValue;
      iValue = GetConfigInt   (indicator, "Status.LineHeight",         -1);                       statusLineHeight         = ifInt(iValue > 0, iValue, statusLineHeight);
   }

   // validate inputs
   // Recording.Enabled
   if (__isTesting) Recording.Enabled = false;
   // Recording.HistoryDirectory
   recordingDirectory = StrTrim(Recording.HistoryDirectory);
   if (IsAbsolutePath(recordingDirectory))                           return(catch("onInit(1)  illegal input parameter Recording.HistoryDirectory: "+ DoubleQuoteStr(Recording.HistoryDirectory) +" (not an allowed directory name)", ERR_INVALID_INPUT_PARAMETER));
   int illegalChars[] = {':', '*', '?', '"', '<', '>', '|'};
   if (StrContainsChars(recordingDirectory, illegalChars))           return(catch("onInit(2)  invalid input parameter Recording.HistoryDirectory: "+ DoubleQuoteStr(Recording.HistoryDirectory) +" (not a valid directory name)", ERR_INVALID_INPUT_PARAMETER));
   recordingDirectory = StrReplace(recordingDirectory, "\\", "/");
   if (StrStartsWith(recordingDirectory, "/"))                       return(catch("onInit(3)  invalid input parameter Recording.HistoryDirectory: "+ DoubleQuoteStr(Recording.HistoryDirectory) +" (must not start with a slash)", ERR_INVALID_INPUT_PARAMETER));
   if (!UseTradeServerPath(recordingDirectory, "onInit(4)"))         return(last_error);
   // Recording.HistoryFormat
   if (Recording.HistoryFormat!=400 && Recording.HistoryFormat!=401) return(catch("onInit(5)  invalid input parameter Recording.HistoryFormat: "+ Recording.HistoryFormat +" (must be 400 or 401)", ERR_INVALID_INPUT_PARAMETER));
   recordingFormat = Recording.HistoryFormat;
   // Broker.SymbolSuffix
   brokerSuffix = StrTrim(Broker.SymbolSuffix);
   if (StringLen(brokerSuffix) > MAX_SYMBOL_LENGTH-1)                return(catch("onInit(6)  invalid input parameter Broker.SymbolSuffix: "+ DoubleQuoteStr(Broker.SymbolSuffix) +" (max. "+ (MAX_SYMBOL_LENGTH-1) +" chars)", ERR_INVALID_INPUT_PARAMETER));

   // initialize global arrays
   int sizeRequired=ArraySize(brokerSymbols), sizeSynthetics=ArraySize(syntheticSymbols);
   ArrayResize(isRequired,   sizeRequired  );
   ArrayResize(isEnabled,    sizeSynthetics);
   ArrayResize(isAvailable,  sizeSynthetics);
   ArrayResize(isStale,      sizeSynthetics); ArrayInitialize(isStale, true);
   ArrayResize(currBid,      sizeSynthetics);
   ArrayResize(currAsk,      sizeSynthetics);
   ArrayResize(currMid,      sizeSynthetics);
   ArrayResize(prevMid,      sizeSynthetics);
   ArrayResize(hSet,         sizeSynthetics);
   ArrayResize(statusLabels, sizeSynthetics);

   // mark synthetic instruments to calculate
   isEnabled[I_AUDLFX] = AUDLFX.Enabled;
   isEnabled[I_CADLFX] = CADLFX.Enabled;
   isEnabled[I_CHFLFX] = CHFLFX.Enabled;
   isEnabled[I_EURLFX] = EURLFX.Enabled;
   isEnabled[I_GBPLFX] = GBPLFX.Enabled;
   isEnabled[I_JPYLFX] = JPYLFX.Enabled;
   isEnabled[I_NZDLFX] = NZDLFX.Enabled;
   isEnabled[I_NOKFX7] = NOKFX7.Enabled;
   isEnabled[I_SEKFX7] = SEKFX7.Enabled;
   isEnabled[I_SGDFX7] = SGDFX7.Enabled;
   isEnabled[I_ZARFX7] = ZARFX7.Enabled;
   isEnabled[I_EURX  ] =   EURX.Enabled;
   isEnabled[I_USDX  ] =   USDX.Enabled;
   isEnabled[I_XAUI  ] =   XAUI.Enabled;                 // USDLFX is a requirement for the following indexes
   isEnabled[I_USDLFX] = USDLFX.Enabled || AUDLFX.Enabled || CADLFX.Enabled || CHFLFX.Enabled || EURLFX.Enabled || GBPLFX.Enabled || JPYLFX.Enabled || NZDLFX.Enabled || NOKFX7.Enabled || SEKFX7.Enabled || SGDFX7.Enabled || ZARFX7.Enabled || XAUI.Enabled;

   // mark required broker symbols
   isRequired[I_AUDUSD] = isEnabled[I_AUDLFX] || isEnabled[I_USDLFX];
   isRequired[I_EURUSD] = isEnabled[I_EURLFX] || isEnabled[I_USDLFX] || isEnabled[I_USDX] || isEnabled[I_EURX];
   isRequired[I_GBPUSD] = isEnabled[I_GBPLFX] || isEnabled[I_USDLFX] || isEnabled[I_USDX] || isEnabled[I_EURX];
   isRequired[I_NZDUSD] = isEnabled[I_NZDLFX];
   isRequired[I_USDCAD] = isEnabled[I_CADLFX] || isEnabled[I_USDLFX] || isEnabled[I_USDX];
   isRequired[I_USDCHF] = isEnabled[I_CHFLFX] || isEnabled[I_USDLFX] || isEnabled[I_USDX] || isEnabled[I_EURX];
   isRequired[I_USDJPY] = isEnabled[I_JPYLFX] || isEnabled[I_USDLFX] || isEnabled[I_USDX] || isEnabled[I_EURX];
   isRequired[I_USDNOK] = isEnabled[I_NOKFX7];
   isRequired[I_USDSEK] = isEnabled[I_SEKFX7]                        || isEnabled[I_USDX] || isEnabled[I_EURX];
   isRequired[I_USDSGD] = isEnabled[I_SGDFX7];
   isRequired[I_USDZAR] = isEnabled[I_ZARFX7];
   isRequired[I_XAUUSD] = isEnabled[I_XAUI  ];

   // initialize display options
   CreateLabels();
   SetIndicatorOptions();

   // only online
   if (!__isTesting) {
      // restore a configured trade account and initialize order/limit monitoring
      string accountId = GetStoredTradeAccount();
      if (!InitTradeAccount(accountId)) return(last_error);
      if (!UpdateAccountDisplay())      return(last_error);
      if (!RefreshLfxOrders())          return(last_error);

      // setup a chart ticker
      int hWnd         = __ExecutionContext[EC.hChart];
      int milliseconds = 500;                            // a virtual tick every 500 milliseconds
      int timerId      = SetupTickTimer(hWnd, milliseconds, NULL);
      if (!timerId) return(catch("onInit(7)->SetupTickTimer(hWnd="+ IntToHexStr(hWnd) +") failed", ERR_RUNTIME_ERROR));
      tickTimerId = timerId;
   }
   return(catch("onInit(8)"));
}


/**
 * Deinitialization
 *
 * @return int - error status
 */
int onDeinit() {
   QC.StopChannels();
   StoreTradeAccount();

   // close all open history sets
   int size = ArraySize(hSet);
   for (int i=0; i < size; i++) {
      if (hSet[i] != 0) {
         if      (i <  7) { if (!HistorySet1.Close(hSet[i])) return(ERR_RUNTIME_ERROR); }
         else if (i < 13) { if (!HistorySet2.Close(hSet[i])) return(ERR_RUNTIME_ERROR); }
         else             { if (!HistorySet3.Close(hSet[i])) return(ERR_RUNTIME_ERROR); }
         hSet[i] = NULL;
      }
   }

   // uninstall the chart ticker
   if (tickTimerId > NULL) {
      int id = tickTimerId; tickTimerId = NULL;
      if (!ReleaseTickTimer(id)) return(catch("onDeinit(1)->ReleaseTickTimer(timerId="+ id +") failed", ERR_RUNTIME_ERROR));
   }
   return(catch("onDeinit(2)"));
}


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   if (!ValidBars) SetIndicatorOptions();                   // reset indicator options

   HandleCommands();                                        // process incoming commands

   ArrayResize(missingSymbols, 0);
   staleLimit = GetServerTime() - 10*MINUTES;               // exotic instruments may show rather large pauses between ticks

   if (!CalculateIndexes()) return(last_error);
   if (!ProcessAllLimits()) return(last_error);             // TODO: detect when monitored limits have been changed
   if (!ShowStatus(NULL))   return(last_error);

   if (Recording.Enabled) {
      if (!RecordIndexes()) return(last_error);
   }
   return(last_error);
}


/**
 * Process an incoming command.
 *
 * @param  string cmd                  - command name
 * @param  string params [optional]    - command parameters (default: none)
 * @param  string modifiers [optional] - command modifiers (default: none)
 *
 * @return bool - success status of the executed command
 */
bool onCommand(string cmd, string params="", string modifiers="") {
   string fullCmd = cmd +":"+ params +":"+ modifiers;

   if (cmd == "trade-account") {
      string accountKey = params +":"+ modifiers;
      if (accountKey == ":") accountKey = "";
      string accountCompany = tradeAccount.company;
      int    accountNumber  = tradeAccount.number;

      if (!InitTradeAccount(accountKey)) return(false);

      if (tradeAccount.company!=accountCompany || tradeAccount.number!=accountNumber) {
         if (!UpdateAccountDisplay()) return(false);        // if the trade account changed
         if (!RefreshLfxOrders())     return(false);        // update display and monitored orders
      }
      return(!catch("onCommand(1)"));
   }

   return(!logNotice("onCommand(2)  unsupported command: "+ DoubleQuoteStr(fullCmd)));
}


/**
 * Read pending and open LFX orders from file into global vars.
 *
 * @return bool - success status
 */
bool RefreshLfxOrders() {
   if (IsLastError()) return(false);

   // read pending orders
   if (AUDLFX.Enabled) if (LFX.GetOrders(C_AUD, OF_PENDINGORDER|OF_PENDINGPOSITION, AUDLFX.orders) < 0) return(false);
   if (CADLFX.Enabled) if (LFX.GetOrders(C_CAD, OF_PENDINGORDER|OF_PENDINGPOSITION, CADLFX.orders) < 0) return(false);
   if (CHFLFX.Enabled) if (LFX.GetOrders(C_CHF, OF_PENDINGORDER|OF_PENDINGPOSITION, CHFLFX.orders) < 0) return(false);
   if (EURLFX.Enabled) if (LFX.GetOrders(C_EUR, OF_PENDINGORDER|OF_PENDINGPOSITION, EURLFX.orders) < 0) return(false);
   if (GBPLFX.Enabled) if (LFX.GetOrders(C_GBP, OF_PENDINGORDER|OF_PENDINGPOSITION, GBPLFX.orders) < 0) return(false);
   if (JPYLFX.Enabled) if (LFX.GetOrders(C_JPY, OF_PENDINGORDER|OF_PENDINGPOSITION, JPYLFX.orders) < 0) return(false);
   if (NZDLFX.Enabled) if (LFX.GetOrders(C_NZD, OF_PENDINGORDER|OF_PENDINGPOSITION, NZDLFX.orders) < 0) return(false);
   if (USDLFX.Enabled) if (LFX.GetOrders(C_USD, OF_PENDINGORDER|OF_PENDINGPOSITION, USDLFX.orders) < 0) return(false);
 //if (NOKFX7.Enabled) if (LFX.GetOrders(C_???, OF_PENDINGORDER|OF_PENDINGPOSITION, NOKFX7.orders) < 0) return(false);
 //if (SEKFX7.Enabled) if (LFX.GetOrders(C_???, OF_PENDINGORDER|OF_PENDINGPOSITION, SEKFX7.orders) < 0) return(false);
 //if (SGDFX7.Enabled) if (LFX.GetOrders(C_???, OF_PENDINGORDER|OF_PENDINGPOSITION, SGDFX7.orders) < 0) return(false);
 //if (ZARFX7.Enabled) if (LFX.GetOrders(C_???, OF_PENDINGORDER|OF_PENDINGPOSITION, ZARFX7.orders) < 0) return(false);
 //if (  EURX.Enabled) if (LFX.GetOrders(C_???, OF_PENDINGORDER|OF_PENDINGPOSITION,   EURX.orders) < 0) return(false);
 //if (  USDX.Enabled) if (LFX.GetOrders(C_???, OF_PENDINGORDER|OF_PENDINGPOSITION,   USDX.orders) < 0) return(false);
 //if (  XAUI.Enabled) if (LFX.GetOrders(C_???, OF_PENDINGORDER|OF_PENDINGPOSITION,   XAUI.orders) < 0) return(false);

   // initialize limit processing
   if (ArrayRange(AUDLFX.orders, 0) > 0) debug("RefreshLfxOrders()  AUDLFX limit orders: "+ ArrayRange(AUDLFX.orders, 0));
   if (ArrayRange(CADLFX.orders, 0) > 0) debug("RefreshLfxOrders()  CADLFX limit orders: "+ ArrayRange(CADLFX.orders, 0));
   if (ArrayRange(CHFLFX.orders, 0) > 0) debug("RefreshLfxOrders()  CHFLFX limit orders: "+ ArrayRange(CHFLFX.orders, 0));
   if (ArrayRange(EURLFX.orders, 0) > 0) debug("RefreshLfxOrders()  EURLFX limit orders: "+ ArrayRange(EURLFX.orders, 0));
   if (ArrayRange(GBPLFX.orders, 0) > 0) debug("RefreshLfxOrders()  GBPLFX limit orders: "+ ArrayRange(GBPLFX.orders, 0));
   if (ArrayRange(JPYLFX.orders, 0) > 0) debug("RefreshLfxOrders()  JPYLFX limit orders: "+ ArrayRange(JPYLFX.orders, 0));
   if (ArrayRange(NZDLFX.orders, 0) > 0) debug("RefreshLfxOrders()  NZDLFX limit orders: "+ ArrayRange(NZDLFX.orders, 0));
   if (ArrayRange(USDLFX.orders, 0) > 0) debug("RefreshLfxOrders()  USDLFX limit orders: "+ ArrayRange(USDLFX.orders, 0));
   if (ArrayRange(NOKFX7.orders, 0) > 0) debug("RefreshLfxOrders()  NOKFX7 limit orders: "+ ArrayRange(NOKFX7.orders, 0));
   if (ArrayRange(SEKFX7.orders, 0) > 0) debug("RefreshLfxOrders()  SEKFX7 limit orders: "+ ArrayRange(SEKFX7.orders, 0));
   if (ArrayRange(SGDFX7.orders, 0) > 0) debug("RefreshLfxOrders()  SGDFX7 limit orders: "+ ArrayRange(SGDFX7.orders, 0));
   if (ArrayRange(ZARFX7.orders, 0) > 0) debug("RefreshLfxOrders()  ZARFX7 limit orders: "+ ArrayRange(ZARFX7.orders, 0));
   if (ArrayRange(  EURX.orders, 0) > 0) debug("RefreshLfxOrders()    EURX limit orders: "+ ArrayRange(  EURX.orders, 0));
   if (ArrayRange(  USDX.orders, 0) > 0) debug("RefreshLfxOrders()    USDX limit orders: "+ ArrayRange(  USDX.orders, 0));
   if (ArrayRange(  XAUI.orders, 0) > 0) debug("RefreshLfxOrders()    XAUI limit orders: "+ ArrayRange(  XAUI.orders, 0));

   return(true);
}


/**
 * Create and initialize text objects for the various display elements.
 *
 * @return bool - success status
 */
bool CreateLabels() {
   string indicatorName = ProgramName();

   // trade account
   statusLabelTradeAccount = indicatorName +".TradeAccount";
   if (ObjectFind(statusLabelTradeAccount) == -1) if (!ObjectCreateRegister(statusLabelTradeAccount, OBJ_LABEL, 0, 0, 0, 0, 0, 0, 0)) return(false);
   ObjectSet    (statusLabelTradeAccount, OBJPROP_CORNER, CORNER_BOTTOM_RIGHT);
   ObjectSet    (statusLabelTradeAccount, OBJPROP_XDISTANCE, 6);
   ObjectSet    (statusLabelTradeAccount, OBJPROP_YDISTANCE, 4);
   ObjectSetText(statusLabelTradeAccount, " ", 1);

   // index display
   int xCoord  = status_xDistance;                       // horizontal display position
   int yCoord  = status_yDistance;                       // vertical display position
   int counter = 10;                                     // a counter for creating unique labels with min. 2 digits

   // background rectangles
   string label = StringConcatenate(indicatorName, ".", counter, ".Background");
   if (ObjectFind(label) == -1) if (!ObjectCreateRegister(label, OBJ_LABEL, 0, 0, 0, 0, 0, 0, 0)) return(false);
   ObjectSet    (label, OBJPROP_CORNER, CORNER_TOP_RIGHT);
   ObjectSet    (label, OBJPROP_XDISTANCE, xCoord);
   ObjectSet    (label, OBJPROP_YDISTANCE, yCoord);
   ObjectSetText(label, "g", 128, "Webdings", statusBgColor);

   counter++;
   yCoord += 74;
   label = StringConcatenate(indicatorName, ".", counter, ".Background");
   if (ObjectFind(label) == -1) if (!ObjectCreateRegister(label, OBJ_LABEL, 0, 0, 0, 0, 0, 0, 0)) return(false);
   ObjectSet    (label, OBJPROP_CORNER, CORNER_TOP_RIGHT);
   ObjectSet    (label, OBJPROP_XDISTANCE, xCoord);
   ObjectSet    (label, OBJPROP_YDISTANCE, yCoord);
   ObjectSetText(label, "g", 128, "Webdings", statusBgColor);

   color fontColor = ifInt(Recording.Enabled, statusFontColor.active, statusFontColor.inactive);

   // animation
   counter++;
   yCoord -= 72;
   label = StringConcatenate(indicatorName, ".", counter, ".Header.animation");
   if (ObjectFind(label) == -1) if (!ObjectCreateRegister(label, OBJ_LABEL, 0, 0, 0, 0, 0, 0, 0)) return(false);
   ObjectSet    (label, OBJPROP_CORNER, CORNER_TOP_RIGHT);
   ObjectSet    (label, OBJPROP_XDISTANCE, xCoord + 3);
   ObjectSet    (label, OBJPROP_YDISTANCE, yCoord);
   ObjectSetText(label, animationChars[0], statusFontSize, statusFontName, fontColor);
   statusLabelAnimation = label;

   // recording status
   label = StringConcatenate(indicatorName, ".", counter, ".Recording.status");
   if (ObjectFind(label) == -1) if (!ObjectCreateRegister(label, OBJ_LABEL, 0, 0, 0, 0, 0, 0, 0)) return(false);
   ObjectSet    (label, OBJPROP_CORNER, CORNER_TOP_RIGHT);
   ObjectSet    (label, OBJPROP_XDISTANCE, xCoord + 23);
   ObjectSet    (label, OBJPROP_YDISTANCE, yCoord);
   string text = ifString(Recording.Enabled, "Recording to: "+ StrRightFrom(recordingDirectory, "/", -1), "Recording:  off");
   ObjectSetText(label, text, statusFontSize, statusFontName, fontColor);

   // data rows
   yCoord += statusLineHeight + 1;
   for (int i=0; i < ArraySize(syntheticSymbols); i++) {
      fontColor = ifInt(isEnabled[i] && Recording.Enabled, statusFontColor.active, statusFontColor.inactive);
      counter++;

      // symbol
      label = StringConcatenate(indicatorName, ".", counter, ".", syntheticSymbols[i]);
      if (ObjectFind(label) == -1) if (!ObjectCreateRegister(label, OBJ_LABEL, 0, 0, 0, 0, 0, 0, 0)) return(false);
      ObjectSet    (label, OBJPROP_CORNER, CORNER_TOP_RIGHT);
      ObjectSet    (label, OBJPROP_XDISTANCE, xCoord + 122);
      ObjectSet    (label, OBJPROP_YDISTANCE, yCoord + i*statusLineHeight);
      ObjectSetText(label, syntheticSymbols[i] +":", statusFontSize, statusFontName, fontColor);
      statusLabels[i] = label;

      // price
      label = StringConcatenate(statusLabels[i], ".quote");
      if (ObjectFind(label) == -1) if (!ObjectCreateRegister(label, OBJ_LABEL, 0, 0, 0, 0, 0, 0, 0)) return(false);
      ObjectSet    (label, OBJPROP_CORNER, CORNER_TOP_RIGHT);
      ObjectSet    (label, OBJPROP_XDISTANCE, xCoord + 57);
      ObjectSet    (label, OBJPROP_YDISTANCE, yCoord + i*statusLineHeight);
      text = ifString(!isEnabled[i], "off", "n/a");
      ObjectSetText(label, text, statusFontSize, statusFontName, statusFontColor.inactive);

      // spread
      label = StringConcatenate(statusLabels[i], ".spread");
      if (ObjectFind(label) == -1) if (!ObjectCreateRegister(label, OBJ_LABEL, 0, 0, 0, 0, 0, 0, 0)) return(false);
      ObjectSet    (label, OBJPROP_CORNER, CORNER_TOP_RIGHT);
      ObjectSet    (label, OBJPROP_XDISTANCE, xCoord + 8);
      ObjectSet    (label, OBJPROP_YDISTANCE, yCoord + i*statusLineHeight);
      ObjectSetText(label, " ");
   }

   return(!catch("CreateLabels(1)"));
}


/**
 * Calculate and return all required data for the specified market symbol.
 *
 * @param  _In_  string symbol  - broker symbol
 * @param  _Out_ double median  - current Median price: (Bid+Ask)/2
 * @param  _Out_ double bid     - current Bid price
 * @param  _Out_ double ask     - current Ask price
 * @param  _Out_ bool   isStale - whether the price feed of the symbol is stale (no ticks received since some time)
 *
 * @return bool - success status
 */
bool GetMarketData(string symbol, double &median, double &bid, double &ask, bool &isStale) {
   if (StringLen(brokerSuffix) > 0)
      symbol = StringConcatenate(symbol, brokerSuffix);

   if (!__isTesting || symbol==Symbol()) {
      bid     = MarketInfo(symbol, MODE_BID);
      ask     = MarketInfo(symbol, MODE_ASK);
      median  = (bid + ask)/2;
      isStale = MarketInfo(symbol, MODE_TIME) < staleLimit;

      int error = GetLastError();
      if (!error)                            return(true);
      if (error != ERR_SYMBOL_NOT_AVAILABLE) return(!catch("GetMarketData(1)  symbol=\""+ symbol +"\"", error));
   }

   bid     = NULL;
   ask     = NULL;
   median  = NULL;
   isStale = true;

   int size = ArraySize(missingSymbols);
   ArrayResize(missingSymbols, size+1);
   missingSymbols[size] = symbol;
   return(true);
}


/**
 * Calculate the configured synthetic instruments.
 *
 * @return bool - success status
 */
bool CalculateIndexes() {
   double audusd, audusd_Bid, audusd_Ask; bool audusd_stale;
   double eurusd, eurusd_Bid, eurusd_Ask; bool eurusd_stale;
   double gbpusd, gbpusd_Bid, gbpusd_Ask; bool gbpusd_stale;
   double nzdusd, nzdusd_Bid, nzdusd_Ask; bool nzdusd_stale;
   double usdcad, usdcad_Bid, usdcad_Ask; bool usdcad_stale;
   double usdchf, usdchf_Bid, usdchf_Ask; bool usdchf_stale;
   double usdjpy, usdjpy_Bid, usdjpy_Ask; bool usdjpy_stale;
   double usdnok, usdnok_Bid, usdnok_Ask; bool usdnok_stale;
   double usdsek, usdsek_Bid, usdsek_Ask; bool usdsek_stale;
   double usdsgd, usdsgd_Bid, usdsgd_Ask; bool usdsgd_stale;
   double usdzar, usdzar_Bid, usdzar_Ask; bool usdzar_stale;
   double xauusd, xauusd_Bid, xauusd_Ask; bool xauusd_stale;

   // get required market data
   if (isRequired[I_AUDUSD]) GetMarketData("AUDUSD", audusd, audusd_Bid, audusd_Ask, audusd_stale);
   if (isRequired[I_EURUSD]) GetMarketData("EURUSD", eurusd, eurusd_Bid, eurusd_Ask, eurusd_stale);
   if (isRequired[I_GBPUSD]) GetMarketData("GBPUSD", gbpusd, gbpusd_Bid, gbpusd_Ask, gbpusd_stale);
   if (isRequired[I_NZDUSD]) GetMarketData("NZDUSD", nzdusd, nzdusd_Bid, nzdusd_Ask, nzdusd_stale);
   if (isRequired[I_USDCAD]) GetMarketData("USDCAD", usdcad, usdcad_Bid, usdcad_Ask, usdcad_stale);
   if (isRequired[I_USDCHF]) GetMarketData("USDCHF", usdchf, usdchf_Bid, usdchf_Ask, usdchf_stale);
   if (isRequired[I_USDJPY]) GetMarketData("USDJPY", usdjpy, usdjpy_Bid, usdjpy_Ask, usdjpy_stale);
   if (isRequired[I_USDNOK]) GetMarketData("USDNOK", usdnok, usdnok_Bid, usdnok_Ask, usdnok_stale);
   if (isRequired[I_USDSEK]) GetMarketData("USDSEK", usdsek, usdsek_Bid, usdsek_Ask, usdsek_stale);
   if (isRequired[I_USDSGD]) GetMarketData("USDSGD", usdsgd, usdsgd_Bid, usdsgd_Ask, usdsgd_stale);
   if (isRequired[I_USDZAR]) GetMarketData("USDZAR", usdzar, usdzar_Bid, usdzar_Ask, usdzar_stale);
   if (isRequired[I_XAUUSD]) GetMarketData("XAUUSD", xauusd, xauusd_Bid, xauusd_Ask, xauusd_stale);

   // calculate indexes
   // USDLFX first as it's needed for many other calculations     // USDLFX = ((USDCAD * USDCHF * USDJPY) / (AUDUSD * EURUSD * GBPUSD)) ^ 1/7
   if (isEnabled[I_USDLFX]) {
      isAvailable[I_USDLFX] = (usdcad && usdchf && usdjpy && audusd && eurusd && gbpusd);
      if (isAvailable[I_USDLFX]) {
         prevMid[I_USDLFX] = currMid[I_USDLFX];
         currMid[I_USDLFX] = MathPow((usdcad     * usdchf     * usdjpy    ) / (audusd     * eurusd     * gbpusd    ), 1/7.);
         currBid[I_USDLFX] = MathPow((usdcad_Bid * usdchf_Bid * usdjpy_Bid) / (audusd_Ask * eurusd_Ask * gbpusd_Ask), 1/7.);
         currAsk[I_USDLFX] = MathPow((usdcad_Ask * usdchf_Ask * usdjpy_Ask) / (audusd_Bid * eurusd_Bid * gbpusd_Bid), 1/7.);
         isStale[I_USDLFX] = usdcad_stale || usdchf_stale || usdjpy_stale || audusd_stale || eurusd_stale || gbpusd_stale;
      }
      else isStale[I_USDLFX] = true;
   }

   if (isEnabled[I_AUDLFX]) {                                     //    AUDLFX = ((AUDCAD * AUDCHF * AUDJPY * AUDUSD) / (EURAUD * GBPAUD)) ^ 1/7
      isAvailable[I_AUDLFX] = isAvailable[I_USDLFX];              // or AUDLFX = USDLFX * AUDUSD
      if (isAvailable[I_AUDLFX]) {
         prevMid[I_AUDLFX] = currMid[I_AUDLFX];
         currMid[I_AUDLFX] = currMid[I_USDLFX] * audusd;
         currBid[I_AUDLFX] = MathPow((usdcad_Bid * usdchf_Bid * usdjpy_Bid) / (audusd_Bid * eurusd_Ask * gbpusd_Ask), 1/7.) * audusd_Bid;
         currAsk[I_AUDLFX] = MathPow((usdcad_Ask * usdchf_Ask * usdjpy_Ask) / (audusd_Ask * eurusd_Bid * gbpusd_Bid), 1/7.) * audusd_Ask;
         isStale[I_AUDLFX] = isStale[I_USDLFX];
      }
      else isStale[I_AUDLFX] = true;
   }

   if (isEnabled[I_CADLFX]) {                                     //    CADLFX = ((CADCHF * CADJPY) / (AUDCAD * EURCAD * GBPCAD * USDCAD)) ^ 1/7
      isAvailable[I_CADLFX] = isAvailable[I_USDLFX];              // or CADLFX = USDLFX / USDCAD
      if (isAvailable[I_CADLFX]) {
         prevMid[I_CADLFX] = currMid[I_CADLFX];
         currMid[I_CADLFX] = currMid[I_USDLFX] / usdcad;
         currBid[I_CADLFX] = MathPow((usdcad_Ask * usdchf_Bid * usdjpy_Bid) / (audusd_Ask * eurusd_Ask * gbpusd_Ask), 1/7.) / usdcad_Ask;
         currAsk[I_CADLFX] = MathPow((usdcad_Bid * usdchf_Ask * usdjpy_Ask) / (audusd_Bid * eurusd_Bid * gbpusd_Bid), 1/7.) / usdcad_Bid;
         isStale[I_CADLFX] = isStale[I_USDLFX];
      }
      else isStale[I_CADLFX] = true;
   }

   if (isEnabled[I_CHFLFX]) {                                     //    CHFLFX = (CHFJPY / (AUDCHF * CADCHF * EURCHF * GBPCHF * USDCHF)) ^ 1/7
      isAvailable[I_CHFLFX] = isAvailable[I_USDLFX];              // or CHFLFX = UDLFX / USDCHF
      if (isAvailable[I_CHFLFX]) {
         prevMid[I_CHFLFX] = currMid[I_CHFLFX];
         currMid[I_CHFLFX] = currMid[I_USDLFX] / usdchf;
         currBid[I_CHFLFX] = MathPow((usdcad_Bid * usdchf_Ask * usdjpy_Bid) / (audusd_Ask * eurusd_Ask * gbpusd_Ask), 1/7.) / usdchf_Ask;
         currAsk[I_CHFLFX] = MathPow((usdcad_Ask * usdchf_Bid * usdjpy_Ask) / (audusd_Bid * eurusd_Bid * gbpusd_Bid), 1/7.) / usdchf_Bid;
         isStale[I_CHFLFX] = isStale[I_USDLFX];
      }
      else isStale[I_CHFLFX] = true;
   }

   if (isEnabled[I_EURLFX]) {                                     //    EURLFX = (EURAUD * EURCAD * EURCHF * EURGBP * EURJPY * EURUSD) ^ 1/7
      isAvailable[I_EURLFX] = isAvailable[I_USDLFX];              // or EURLFX = USDLFX * EURUSD
      if (isAvailable[I_EURLFX]) {
         prevMid[I_EURLFX] = currMid[I_EURLFX];
         currMid[I_EURLFX] = currMid[I_USDLFX] * eurusd;
         currBid[I_EURLFX] = MathPow((usdcad_Bid * usdchf_Bid * usdjpy_Bid) / (audusd_Ask * eurusd_Bid * gbpusd_Ask), 1/7.) * eurusd_Bid;
         currAsk[I_EURLFX] = MathPow((usdcad_Ask * usdchf_Ask * usdjpy_Ask) / (audusd_Bid * eurusd_Ask * gbpusd_Bid), 1/7.) * eurusd_Ask;
         isStale[I_EURLFX] = isStale[I_USDLFX];
      }
      else isStale[I_EURLFX] = true;
   }

   if (isEnabled[I_GBPLFX]) {                                     //    GBPLFX = ((GBPAUD * GBPCAD * GBPCHF * GBPJPY * GBPUSD) / EURGBP) ^ 1/7
      isAvailable[I_GBPLFX] = isAvailable[I_USDLFX];              // or GBPLFX = USDLFX * GBPUSD
      if (isAvailable[I_GBPLFX]) {
         prevMid[I_GBPLFX] = currMid[I_GBPLFX];
         currMid[I_GBPLFX] = currMid[I_USDLFX] * gbpusd;
         currBid[I_GBPLFX] = MathPow((usdcad_Bid * usdchf_Bid * usdjpy_Bid) / (audusd_Ask * eurusd_Ask * gbpusd_Bid), 1/7.) * gbpusd_Bid;
         currAsk[I_GBPLFX] = MathPow((usdcad_Ask * usdchf_Ask * usdjpy_Ask) / (audusd_Bid * eurusd_Bid * gbpusd_Ask), 1/7.) * gbpusd_Ask;
         isStale[I_GBPLFX] = isStale[I_USDLFX];
      }
      else isStale[I_GBPLFX] = true;
   }

   if (isEnabled[I_JPYLFX]) {                                     //    JPYLFX = 100 * (1 / (AUDJPY * CADJPY * CHFJPY * EURJPY * GBPJPY * USDJPY)) ^ 1/7
      isAvailable[I_JPYLFX] = isAvailable[I_USDLFX];              // or JPYLFX = 100 * USDLFX / USDJPY
      if (isAvailable[I_JPYLFX]) {
         prevMid[I_JPYLFX] = currMid[I_JPYLFX];
         currMid[I_JPYLFX] = 100 * currMid[I_USDLFX] / usdjpy;
         currBid[I_JPYLFX] = 100 * MathPow((usdcad_Bid * usdchf_Bid * usdjpy_Ask) / (audusd_Ask * eurusd_Ask * gbpusd_Ask), 1/7.) / usdjpy_Ask;
         currAsk[I_JPYLFX] = 100 * MathPow((usdcad_Ask * usdchf_Ask * usdjpy_Bid) / (audusd_Bid * eurusd_Bid * gbpusd_Bid), 1/7.) / usdjpy_Bid;
         isStale[I_JPYLFX] = isStale[I_USDLFX];
      }
      else isStale[I_JPYLFX] = true;
   }

   if (isEnabled[I_NZDLFX]) {                                     //    NZDLFX = ((NZDCAD * NZDCHF * NZDJPY * NZDUSD) / (AUDNZD * EURNZD * GBPNZD)) ^ 1/7
      isAvailable[I_NZDLFX] = (isAvailable[I_USDLFX] && nzdusd);  // or NZDLFX = USDLFX * NZDUSD
      if (isAvailable[I_NZDLFX]) {
         prevMid[I_NZDLFX] = currMid[I_NZDLFX];
         currMid[I_NZDLFX] = currMid[I_USDLFX] * nzdusd;
         currBid[I_NZDLFX] = MathPow((usdcad_Bid * usdchf_Bid * usdjpy_Bid) / (audusd_Ask * eurusd_Ask * gbpusd_Ask), 1/7.) * nzdusd_Bid;
         currAsk[I_NZDLFX] = MathPow((usdcad_Ask * usdchf_Ask * usdjpy_Ask) / (audusd_Bid * eurusd_Bid * gbpusd_Bid), 1/7.) * nzdusd_Ask;
         isStale[I_NZDLFX] = isStale[I_USDLFX] || nzdusd_stale;
      }
      else isStale[I_NZDLFX] = true;
   }

   if (isEnabled[I_NOKFX7]) {                                     //    NOKFX7 = 10 * (NOKJPY / (AUDNOK * CADNOK * CHFNOK * EURNOK * GBPNOK * USDNOK)) ^ 1/7
      isAvailable[I_NOKFX7] = (isAvailable[I_USDLFX] && usdnok);  // or NOKFX7 = 10 * USDLFX / USDNOK
      if (isAvailable[I_NOKFX7]) {
         prevMid[I_NOKFX7] = currMid[I_NOKFX7];
         currMid[I_NOKFX7] = 10 * currMid[I_USDLFX] / usdnok;
         currBid[I_NOKFX7] = 10 * MathPow((usdcad_Bid * usdchf_Bid * usdjpy_Bid) / (audusd_Ask * eurusd_Ask * gbpusd_Ask), 1/7.) / usdnok_Ask;
         currAsk[I_NOKFX7] = 10 * MathPow((usdcad_Ask * usdchf_Ask * usdjpy_Ask) / (audusd_Bid * eurusd_Bid * gbpusd_Bid), 1/7.) / usdnok_Bid;
         isStale[I_NOKFX7] = isStale[I_USDLFX] || usdnok_stale;
      }
      else isStale[I_NOKFX7] = true;
   }

   if (isEnabled[I_SEKFX7]) {                                     //    SEKFX7 = 10 * (SEKJPY / (AUDSEK * CADSEK * CHFSEK * EURSEK * GBPSEK * USDSEK)) ^ 1/7
      isAvailable[I_SEKFX7] = (isAvailable[I_USDLFX] && usdsek);  // or SEKFX7 = 10 * USDLFX / USDSEK
      if (isAvailable[I_SEKFX7]) {
         prevMid[I_SEKFX7] = currMid[I_SEKFX7];
         currMid[I_SEKFX7] = 10 * currMid[I_USDLFX] / usdsek;
         currBid[I_SEKFX7] = 10 * MathPow((usdcad_Bid * usdchf_Bid * usdjpy_Bid) / (audusd_Ask * eurusd_Ask * gbpusd_Ask), 1/7.) / usdsek_Ask;
         currAsk[I_SEKFX7] = 10 * MathPow((usdcad_Ask * usdchf_Ask * usdjpy_Ask) / (audusd_Bid * eurusd_Bid * gbpusd_Bid), 1/7.) / usdsek_Bid;
         isStale[I_SEKFX7] = isStale[I_USDLFX] || usdsek_stale;
      }
      else isStale[I_SEKFX7] = true;
   }

   if (isEnabled[I_SGDFX7]) {                                     //    SGDFX7 = (SGDJPY / (AUDSGD * CADSGD * CHFSGD * EURSGD * GBPSGD * USDSGD)) ^ 1/7
      isAvailable[I_SGDFX7] = (isAvailable[I_USDLFX] && usdsgd);  // or SGDFX7 = USDLFX / USDSGD
      if (isAvailable[I_SGDFX7]) {
         prevMid[I_SGDFX7] = currMid[I_SGDFX7];
         currMid[I_SGDFX7] = currMid[I_USDLFX] / usdsgd;
         currBid[I_SGDFX7] = MathPow((usdcad_Bid * usdchf_Bid * usdjpy_Bid) / (audusd_Ask * eurusd_Ask * gbpusd_Ask), 1/7.) / usdsgd_Ask;
         currAsk[I_SGDFX7] = MathPow((usdcad_Ask * usdchf_Ask * usdjpy_Ask) / (audusd_Bid * eurusd_Bid * gbpusd_Bid), 1/7.) / usdsgd_Bid;
         isStale[I_SGDFX7] = isStale[I_USDLFX] || usdsgd_stale;
      }
      else isStale[I_SGDFX7] = true;
   }

   if (isEnabled[I_ZARFX7]) {                                     //    ZARFX7 = 10 * (ZARJPY / (AUDZAR * CADZAR * CHFZAR * EURZAR * GBPZAR * USDZAR)) ^ 1/7
      isAvailable[I_ZARFX7] = (isAvailable[I_USDLFX] && usdzar);  // or ZARFX7 = 10 * USDLFX / USDZAR
      if (isAvailable[I_ZARFX7]) {
         prevMid[I_ZARFX7] = currMid[I_ZARFX7];
         currMid[I_ZARFX7] = 10 * currMid[I_USDLFX] / usdzar;
         currBid[I_ZARFX7] = 10 * MathPow((usdcad_Bid * usdchf_Bid * usdjpy_Bid) / (audusd_Ask * eurusd_Ask * gbpusd_Ask), 1/7.) / usdzar_Ask;
         currAsk[I_ZARFX7] = 10 * MathPow((usdcad_Ask * usdchf_Ask * usdjpy_Ask) / (audusd_Bid * eurusd_Bid * gbpusd_Bid), 1/7.) / usdzar_Bid;
         isStale[I_ZARFX7] = isStale[I_USDLFX] || usdzar_stale;
      }
      else isStale[I_ZARFX7] = true;
   }

   if (isEnabled[I_EURX]) {                                       // EURX = 34.38805726 * EURUSD^0.3155 * EURGBP^0.3056 * EURJPY^0.1891 * EURCHF^0.1113 * EURSEK^0.0785
      isAvailable[I_EURX] = (usdchf && usdjpy && usdsek && eurusd && gbpusd);
      if (isAvailable[I_EURX]) {
         double eurgbp = eurusd/gbpusd, eurgbp_Bid = eurusd_Bid/gbpusd_Bid, eurgbp_Ask = eurusd_Ask/gbpusd_Ask;
         double eurjpy = eurusd*usdjpy, eurjpy_Bid = eurusd_Bid*usdjpy_Bid, eurjpy_Ask = eurusd_Ask*usdjpy_Ask;
         double eurchf = eurusd*usdchf, eurchf_Bid = eurusd_Bid*usdchf_Bid, eurchf_Ask = eurusd_Ask*usdchf_Ask;
         double eursek = eurusd*usdsek, eursek_Bid = eurusd_Bid*usdsek_Bid, eursek_Ask = eurusd_Ask*usdsek_Ask;
         prevMid[I_EURX] = currMid[I_EURX];
         currMid[I_EURX] = 34.38805726 * MathPow(eurusd,     0.3155) * MathPow(eurgbp,     0.3056) * MathPow(eurjpy,     0.1891) * MathPow(eurchf,     0.1113) * MathPow(eursek,     0.0785);
         currBid[I_EURX] = 34.38805726 * MathPow(eurusd_Bid, 0.3155) * MathPow(eurgbp_Bid, 0.3056) * MathPow(eurjpy_Bid, 0.1891) * MathPow(eurchf_Bid, 0.1113) * MathPow(eursek_Bid, 0.0785);
         currAsk[I_EURX] = 34.38805726 * MathPow(eurusd_Ask, 0.3155) * MathPow(eurgbp_Ask, 0.3056) * MathPow(eurjpy_Ask, 0.1891) * MathPow(eurchf_Ask, 0.1113) * MathPow(eursek_Ask, 0.0785);
         isStale[I_EURX] = usdchf_stale || usdjpy_stale || usdsek_stale || eurusd_stale || gbpusd_stale;
      }
      else isStale[I_EURX] = true;
   }

   if (isEnabled[I_USDX]) {                                       // USDX = 50.14348112 * EURUSD^-0.576 * USDJPY^0.136 * GBPUSD^-0.119 * USDCAD^0.091 * USDSEK^0.042 * USDCHF^0.036
      isAvailable[I_USDX] = (usdcad && usdchf && usdjpy && usdsek && eurusd && gbpusd);
      if (isAvailable[I_USDX]) {
         prevMid[I_USDX] = currMid[I_USDX];
         currMid[I_USDX] = 50.14348112 * (MathPow(usdjpy,     0.136) * MathPow(usdcad,     0.091) * MathPow(usdsek,     0.042) * MathPow(usdchf,     0.036)) / (MathPow(eurusd,     0.576) * MathPow(gbpusd,     0.119));
         currBid[I_USDX] = 50.14348112 * (MathPow(usdjpy_Bid, 0.136) * MathPow(usdcad_Bid, 0.091) * MathPow(usdsek_Bid, 0.042) * MathPow(usdchf_Bid, 0.036)) / (MathPow(eurusd_Ask, 0.576) * MathPow(gbpusd_Ask, 0.119));
         currAsk[I_USDX] = 50.14348112 * (MathPow(usdjpy_Ask, 0.136) * MathPow(usdcad_Ask, 0.091) * MathPow(usdsek_Ask, 0.042) * MathPow(usdchf_Ask, 0.036)) / (MathPow(eurusd_Bid, 0.576) * MathPow(gbpusd_Bid, 0.119));
         isStale[I_USDX] = usdcad_stale || usdchf_stale || usdjpy_stale || usdsek_stale || eurusd_stale || gbpusd_stale;
      }
      else isStale[I_USDX] = true;
   }

   if (isEnabled[I_XAUI]) {                                       //    XAUI = (XAUAUD * XAUCAD * XAUCHF * XAUEUR * XAUUSD * XAUGBP * XAUJPY) ^ 1/7
      isAvailable[I_XAUI] = (isAvailable[I_USDLFX] && xauusd);    // or XAUI = USDLFX * XAUUSD
      if (isAvailable[I_XAUI]) {
         prevMid[I_XAUI] = currMid[I_XAUI];
         currMid[I_XAUI] = currMid[I_USDLFX] * xauusd;
         currBid[I_XAUI] = currBid[I_USDLFX] * xauusd_Bid;
         currAsk[I_XAUI] = currAsk[I_USDLFX] * xauusd_Ask;
         isStale[I_XAUI] = isStale[I_USDLFX] || xauusd_stale;
      }
      else isStale[I_XAUI] = true;
   }

   int error = GetLastError();
   if (!error) return(true);

   if (error == ERS_HISTORY_UPDATE)
      return(!SetLastError(error));
   return(!catch("CalculateIndexes(1)", error));
}


/**
 * Check for symbol price changes and trigger limit processing of synthetic positions.
 *
 * @return bool - success status
 */
bool ProcessAllLimits() {
   if (__isTesting) return(true);

   // only check orders if the symbol's calculated price has changed
   if (!isStale[I_AUDLFX]) if (!EQ(currMid[I_AUDLFX], prevMid[I_AUDLFX], symbolDigits[I_AUDLFX])) if (!ProcessLimits(AUDLFX.orders, currMid[I_AUDLFX])) return(false);
   if (!isStale[I_CADLFX]) if (!EQ(currMid[I_CADLFX], prevMid[I_CADLFX], symbolDigits[I_CADLFX])) if (!ProcessLimits(CADLFX.orders, currMid[I_CADLFX])) return(false);
   if (!isStale[I_CHFLFX]) if (!EQ(currMid[I_CHFLFX], prevMid[I_CHFLFX], symbolDigits[I_CHFLFX])) if (!ProcessLimits(CHFLFX.orders, currMid[I_CHFLFX])) return(false);
   if (!isStale[I_EURLFX]) if (!EQ(currMid[I_EURLFX], prevMid[I_EURLFX], symbolDigits[I_EURLFX])) if (!ProcessLimits(EURLFX.orders, currMid[I_EURLFX])) return(false);
   if (!isStale[I_GBPLFX]) if (!EQ(currMid[I_GBPLFX], prevMid[I_GBPLFX], symbolDigits[I_GBPLFX])) if (!ProcessLimits(GBPLFX.orders, currMid[I_GBPLFX])) return(false);
   if (!isStale[I_JPYLFX]) if (!EQ(currMid[I_JPYLFX], prevMid[I_JPYLFX], symbolDigits[I_JPYLFX])) if (!ProcessLimits(JPYLFX.orders, currMid[I_JPYLFX])) return(false);
   if (!isStale[I_NZDLFX]) if (!EQ(currMid[I_NZDLFX], prevMid[I_NZDLFX], symbolDigits[I_NZDLFX])) if (!ProcessLimits(NZDLFX.orders, currMid[I_NZDLFX])) return(false);
   if (!isStale[I_USDLFX]) if (!EQ(currMid[I_USDLFX], prevMid[I_USDLFX], symbolDigits[I_USDLFX])) if (!ProcessLimits(USDLFX.orders, currMid[I_USDLFX])) return(false);

   if (!isStale[I_NOKFX7]) if (!EQ(currMid[I_NOKFX7], prevMid[I_NOKFX7], symbolDigits[I_NOKFX7])) if (!ProcessLimits(NOKFX7.orders, currMid[I_NOKFX7])) return(false);
   if (!isStale[I_SEKFX7]) if (!EQ(currMid[I_SEKFX7], prevMid[I_SEKFX7], symbolDigits[I_SEKFX7])) if (!ProcessLimits(SEKFX7.orders, currMid[I_SEKFX7])) return(false);
   if (!isStale[I_SGDFX7]) if (!EQ(currMid[I_SGDFX7], prevMid[I_SGDFX7], symbolDigits[I_SGDFX7])) if (!ProcessLimits(SGDFX7.orders, currMid[I_SGDFX7])) return(false);
   if (!isStale[I_ZARFX7]) if (!EQ(currMid[I_ZARFX7], prevMid[I_ZARFX7], symbolDigits[I_ZARFX7])) if (!ProcessLimits(ZARFX7.orders, currMid[I_ZARFX7])) return(false);

   if (!isStale[I_EURX  ]) if (!EQ(currMid[I_EURX  ], prevMid[I_EURX  ], symbolDigits[I_EURX  ])) if (!ProcessLimits(EURX.orders,   currMid[I_EURX  ])) return(false);
   if (!isStale[I_USDX  ]) if (!EQ(currMid[I_USDX  ], prevMid[I_USDX  ], symbolDigits[I_USDX  ])) if (!ProcessLimits(USDX.orders,   currMid[I_USDX  ])) return(false);

   if (!isStale[I_XAUI  ]) if (!EQ(currMid[I_XAUI  ], prevMid[I_XAUI  ], symbolDigits[I_XAUI  ])) if (!ProcessLimits(XAUI.orders,   currMid[I_XAUI  ])) return(false);

   return(true);
}


/**
 * Check active limits of the passed orders and send trade commands accordingly.
 *
 * @param  _InOut_ LFX_ORDER orders[] - array of LFX_ORDERs
 * @param  _In_    double    price    - current price to check against
 *
 * @return bool - success status
 */
bool ProcessLimits(/*LFX_ORDER*/int orders[][], double price) {
   int size = ArrayRange(orders, 0);

   for (int i=0; i < size; i++) {
      // On initialization orders[] contains only pending orders. After limit execution it also contains open and/or closed positions.
      if (!los.IsPendingOrder(orders, i)) /*&&*/ if (!los.IsPendingPosition(orders, i))
         continue;

      // test limit prices against the passed Median price (don't test PL limits)
      int result = LFX.CheckLimits(orders, i, price, price, EMPTY_VALUE); if (!result) return(false);
      if (result == NO_LIMIT_TRIGGERED)
         continue;

      if (!LFX.SendTradeCommand(orders, i, result)) return(false);
   }
   return(true);
}


/**
 * Display the current runtime status.
 *
 * @param  int error [optional] - ignored
 *
 * @return int - success status or NULL (0) in case of errors
 */
int ShowStatus(int error = NO_ERROR) {
   if (!__isChart) return(true);

   // animation
   int   chars     = ArraySize(animationChars);
   color fontColor = ifInt(Recording.Enabled, statusFontColor.active, statusFontColor.inactive);
   ObjectSetText(statusLabelAnimation, animationChars[Ticks % chars], statusFontSize, statusFontName, fontColor);

   // calculated values
   int size = ArraySize(syntheticSymbols);
   string sQuote="", sSpread="";

   for (int i=0; i < size; i++) {
      if (isEnabled[i]) {
         fontColor = statusFontColor.inactive;
         if (isAvailable[i]) {
            sQuote  = NumberToStr(currMid[i], symbolPriceFormat[i]);
            sSpread = "("+ SpreadToStr(i, (currAsk[i]-currBid[i])/symbolPipSize[i]) +")";
            if (Recording.Enabled && isEnabled[i] && !isStale[i]) {
               fontColor = statusFontColor.active;
            }
         }
         else {
            sQuote  = "n/a";
            sSpread = " ";
         }
         ObjectSetText(statusLabels[i] +".quote",  sQuote,  statusFontSize, statusFontName, fontColor);
         ObjectSetText(statusLabels[i] +".spread", sSpread, statusFontSize, statusFontName, fontColor);
      }
   }

   // show missing broker symbols
   static int lastMissingSymbols = 0;
   size = ArraySize(missingSymbols);
   if (size > 0) {
      string msg = "";
      for (i=0; i < size; i++) {
         msg = StringConcatenate(msg, missingSymbols[i], ", ");
      }
      Comment(NL, NL, NL, NL, WindowExpertName(), "  => missing broker symbols: ", StrLeft(msg, -2));
   }
   else if (lastMissingSymbols > 0) {
      Comment("");                                 // reset last comment but keep comments of other programs
   }
   lastMissingSymbols = size;

   return(!catch("ShowStatus(1)"));
}


/**
 * Record LFX index data.
 *
 * @return bool - success status
 */
bool RecordIndexes() {
   datetime now = GetFxtTime();
   int size = ArraySize(syntheticSymbols);

   for (int i=0; i < size; i++) {
      if (isEnabled[i] && !isStale[i]) {
         double value     = NormalizeDouble(currMid[i], symbolDigits[i]);
         double lastValue = prevMid[i];

         if (Tick.isVirtual) {                                    // Virtual ticks (there are plenty) are recorded only if the
            if (EQ(value, lastValue, symbolDigits[i])) continue;  // resulting price changed. Real ticks are always recorded.
         }

         if (!hSet[i]) {
            if      (i <  7) hSet[i] = HistorySet1.Get(syntheticSymbols[i], recordingDirectory);
            else if (i < 13) hSet[i] = HistorySet2.Get(syntheticSymbols[i], recordingDirectory);
            else             hSet[i] = HistorySet3.Get(syntheticSymbols[i], recordingDirectory);
            if (hSet[i] == -1) {
               if      (i <  7) hSet[i] = HistorySet1.Create(syntheticSymbols[i], symbolLongName[i], symbolDigits[i], recordingFormat, recordingDirectory);
               else if (i < 13) hSet[i] = HistorySet2.Create(syntheticSymbols[i], symbolLongName[i], symbolDigits[i], recordingFormat, recordingDirectory);
               else             hSet[i] = HistorySet3.Create(syntheticSymbols[i], symbolLongName[i], symbolDigits[i], recordingFormat, recordingDirectory);
            }
            if (!hSet[i]) return(false);
         }
         if      (i <  7) { if (!HistorySet1.AddTick(hSet[i], now, value, NULL)) return(false); }
         else if (i < 13) { if (!HistorySet2.AddTick(hSet[i], now, value, NULL)) return(false); }
         else             { if (!HistorySet3.AddTick(hSet[i], now, value, NULL)) return(false); }
      }
   }
   return(true);
}


/**
 * Update the chart display of the currently used trade account.
 *
 * @return bool - success status
 */
bool UpdateAccountDisplay() {
   if (IsLastError()) return(false);

   if (mode.extern) {
      string text = "Limits:  "+ tradeAccount.name +", "+ tradeAccount.company +", "+ tradeAccount.number +", "+ tradeAccount.currency;
      ObjectSetText(statusLabelTradeAccount, text, 8, "Arial Fett", ifInt(tradeAccount.type==ACCOUNT_TYPE_DEMO, LimeGreen, DarkOrange));
   }
   else {
      ObjectSetText(statusLabelTradeAccount, " ", 1);
   }

   int error = GetLastError();
   if (!error || error==ERR_OBJECT_DOES_NOT_EXIST)                 // on ObjectDrag or opened "Properties" dialog
      return(true);
   return(!catch("UpdateAccountDisplay(1)", error));
}


/**
 * Store the current trade account (if any) in the chart and the chart window (to survive init cycles and/or terminal restart).
 *
 * @return bool - success status
 */
bool StoreTradeAccount() {
   // account company id
   int    hWnd = __ExecutionContext[EC.hChart];
   string key  = ProgramName() +".runtime.tradeAccount.company";   // TODO: add program pid and manage keys globally
   SetWindowStringA(hWnd, key, tradeAccount.company);

   if (ObjectFind(key) == -1) ObjectCreate(key, OBJ_LABEL, 0, 0, 0);
   ObjectSet    (key, OBJPROP_TIMEFRAMES, OBJ_PERIODS_NONE);
   ObjectSetText(key, tradeAccount.company);

   // account number
   key = ProgramName() +".runtime.tradeAccount.number";            // TODO: add program pid and manage keys globally
   SetWindowIntegerA(hWnd, key, tradeAccount.number);

   if (ObjectFind(key) == -1) ObjectCreate(key, OBJ_LABEL, 0, 0, 0);
   ObjectSet    (key, OBJPROP_TIMEFRAMES, OBJ_PERIODS_NONE);
   ObjectSetText(key, ""+ tradeAccount.number);

   return(!catch("StoreTradeAccount(1)"));
}


/**
 * Retrieve a trade account stored in the chart or chart window.
 *
 * @return string - trade account identifier or an empty string if no data was stored or in case of errors
 */
string GetStoredTradeAccount() {
   // account company id
   int hWnd = __ExecutionContext[EC.hChart];
   string key = ProgramName() +".runtime.tradeAccount.company";
   string company = GetWindowStringA(hWnd, key);
   if (!StringLen(company)) {
      if (ObjectFind(key) != -1) company = ObjectDescription(key);
   }

   // account number
   key = ProgramName() +".runtime.tradeAccount.number";
   int accountNumber = GetWindowIntegerA(hWnd, key);
   if (!accountNumber) {
      if (ObjectFind(key) != -1) accountNumber = StrToInteger(ObjectDescription(key));
   }

   string result = "";
   if (StringLen(company) && accountNumber)
      result = company +":"+ accountNumber;
   return(ifString(catch("GetStoredTradeAccount(1)"), "", result));
}


/**
 * Format a value representing a pip range of the specified symbol. Depending on the symbol's quote price and the value the
 * returned string is in money or subpip notation.
 *
 * @param  int    index - synthetic instrument index
 * @param  double value - price range in pip
 *
 * @return string
 */
string SpreadToStr(int index, double value) {
   int    digits = symbolDigits[index];
   double price  = currMid[index];
   string result = "";

   if (digits==2 && price >= 500) result = NumberToStr(value/100, "R.2");              // 123 pip => 1.23
   else                           result = NumberToStr(value, "R."+ (digits & 1));     // 123 pip => 123 | 123.4
   return(result);
}


/**
 * Workaround for various terminal bugs when setting indicator options. Usually options are set in init(). However after
 * recompilation options must be set in start() to not be ignored.
 */
void SetIndicatorOptions() {
   SetIndexStyle(0, DRAW_NONE, EMPTY, EMPTY, CLR_NONE);
   SetIndexLabel(0, NULL);
}


/**
 * Return a string representation of the input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("USDLFX.Enabled=",             BoolToStr(USDLFX.Enabled),                  ";"+ NL,
                            "AUDLFX.Enabled=",             BoolToStr(AUDLFX.Enabled),                  ";"+ NL,
                            "CADLFX.Enabled=",             BoolToStr(CADLFX.Enabled),                  ";"+ NL,
                            "CHFLFX.Enabled=",             BoolToStr(CHFLFX.Enabled),                  ";"+ NL,
                            "EURLFX.Enabled=",             BoolToStr(EURLFX.Enabled),                  ";"+ NL,
                            "GBPLFX.Enabled=",             BoolToStr(GBPLFX.Enabled),                  ";"+ NL,
                            "JPYLFX.Enabled=",             BoolToStr(JPYLFX.Enabled),                  ";"+ NL,
                            "NZDLFX.Enabled=",             BoolToStr(NZDLFX.Enabled),                  ";"+ NL,
                            "NOKFX7.Enabled=",             BoolToStr(NOKFX7.Enabled),                  ";"+ NL,
                            "SEKFX7.Enabled=",             BoolToStr(SEKFX7.Enabled),                  ";"+ NL,
                            "SGDFX7.Enabled=",             BoolToStr(SGDFX7.Enabled),                  ";"+ NL,
                            "ZARFX7.Enabled=",             BoolToStr(ZARFX7.Enabled),                  ";"+ NL,
                            "EURX.Enabled=",               BoolToStr(EURX.Enabled),                    ";"+ NL,
                            "USDX.Enabled=",               BoolToStr(USDX.Enabled),                    ";"+ NL,
                            "XAUI.Enabled=",               BoolToStr(XAUI.Enabled),                    ";"+ NL,

                            "Recording.Enabled=",          BoolToStr(Recording.Enabled),               ";"+ NL,
                            "Recording.HistoryDirectory=", DoubleQuoteStr(Recording.HistoryDirectory), ";"+ NL,
                            "Recording.HistoryFormat=",    Recording.HistoryFormat,                    ";"+ NL,

                            "Broker.SymbolSuffix=",        DoubleQuoteStr(Broker.SymbolSuffix),        ";")
   );
}
