/**
 * LFX Monitor
 *
 * Calculates various synthetic indexes and optionally records the index history. If linked to an LFX charting terminal the
 * indicator can monitor and process order limits of synthetic positions. For index descriptions see the following link:
 *
 * @link  https://github.com/rosasurfer/mt4-tools/tree/master/app/lib/synthetic#
 *
 *
 * TODO:
 *  - make use of all history libraries
 *  - check display on different screen resolutions and consider additional auto-config values
 *  - should the ticktimer rate be an input?
 *  - document user requirements for "Recording.HistoryDirectory"
 *  - test history format 401
 *  - check timezone requirements
 *  - check trade account requirements: RestoreRuntimeStatus -> UpdateAccountDisplay -> RefreshLfxOrders
 *  - check conflicting history formats and document it
 *  - document symbol requirements
 *  - spreads for EURX, USDX and XAUI
 */
#include <stddefines.mqh>
int   __InitFlags[];
int __DeinitFlags[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern string ___a___________________________ = "=== Synthetic FX6 indexes (LiteForex) ===";
extern bool   AUDLFX.Enabled                  = true;                   // default: all indexes enabled
extern bool   CADLFX.Enabled                  = true;
extern bool   CHFLFX.Enabled                  = true;
extern bool   EURLFX.Enabled                  = true;
extern bool   GBPLFX.Enabled                  = true;
extern bool   JPYLFX.Enabled                  = true;
extern bool   NZDLFX.Enabled                  = true;
extern bool   USDLFX.Enabled                  = true;
extern string ___b___________________________ = "=== Synthetic FX7 indexes ===";
extern bool   NOKFX7.Enabled                  = true;
extern bool   SEKFX7.Enabled                  = true;
extern bool   SGDFX7.Enabled                  = true;
extern bool   ZARFX7.Enabled                  = true;
extern string ___c___________________________ = "=== ICE indexes ===";
extern bool   EURX.Enabled                    = true;
extern bool   USDX.Enabled                    = true;
extern string ___d___________________________ = "=== Synthetic Gold index ===";
extern bool   XAUI.Enabled                    = true;
extern string ___e___________________________ = "=== Recording settings ===";
extern bool   Recording.Enabled               = false;                  // default: disabled
extern string Recording.HistoryDirectory      = "Synthetic-History";    // name of the history directory to store recorded data
extern int    Recording.HistoryFormat         = 401;                    // created history format
extern string ___f___________________________ = "=== Broker settings ===";
extern string Broker.SymbolSuffix             = "";                     // symbol suffix for brokers with non-standard symbols

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <rsfLib.mqh>
#include <rsfHistory.mqh>
#include <functions/HandleCommands.mqh>
#include <functions/InitializeByteBuffer.mqh>
#include <functions/JoinStrings.mqh>
#include <MT4iQuickChannel.mqh>
#include <lfx.mqh>
#include <structs/rsf/LFXOrder.mqh>

#property indicator_chart_window

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

string   syntheticSymbols [] = {"AUDLFX", "CADLFX", "CHFLFX", "EURLFX", "GBPLFX", "JPYLFX", "NZDLFX", "USDLFX", "NOKFX7", "SEKFX7", "SGDFX7", "ZARFX7", "EURX", "USDX", "XAUI"};
string   symbolLongName   [] = {"LiteForex Australian Dollar index", "LiteForex Canadian Dollar index", "LiteForex Swiss Franc index", "LiteForex Euro index", "LiteForex Great Britain Pound index", "LiteForex Japanese Yen index", "LiteForex New Zealand Dollar index", "LiteForex US Dollar index", "Norwegian Krona vs Majors index", "Swedish Kronor vs Majors index", "Singapore Dollar vs Majors index", "South African Rand vs Majors index", "ICE Euro Futures index", "ICE US Dollar Futures index", "Gold vs Majors index" };
int      symbolDigits     [] = {5       , 5       , 5       , 5       , 5       , 5       , 5       , 5       , 5       , 5       , 5       , 5       , 3     , 3     , 3     };
double   symbolPipSize    [] = {0.0001  , 0.0001  , 0.0001  , 0.0001  , 0.0001  , 0.0001  , 0.0001  , 0.0001  , 0.0001  , 0.0001  , 0.0001  , 0.0001  , 0.01  , 0.01  , 0.01  };
string   symbolPriceFormat[] = {"R.4'"  , "R.4'"  , "R.4'"  , "R.4'"  , "R.4'"  , "R.4'"  , "R.4'"  , "R.4'"  , "R.4'"  , "R.4'"  , "R.4'"  , "R.4'"  , "R.2'", "R.2'", "R.2'"};

bool     isEnabled  [];                                  // whether calculation of a synthetic instrument is enabled (matches inputs *.Enabled)
bool     isAvailable[];                                  // whether all quotes for instrument calculation are available
double   currBid    [];                                  // current calculated Bid value
double   currAsk    [];                                  // current calculated Ask value
double   currMid    [];                                  // current calculated Median value: (Bid+Ask)/2
double   prevMid    [];                                  // previous calculated Median value
bool     isStale    [];                                  // whether prices for calculation are stale (not updated anymore)
datetime staleLimit;                                     // time limit (server time) for stale quotes determination

int      hSet            [];                             // HistorySet handles
bool     recordingEnabled[];                             // per symbol (default: FALSE)
string   recordingDirectory = "";                        // directory to store recorded history
int      recordingFormat;                                // format of new history files: 400 | 401

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

// text labels for display elements
string labels[];
string labelTradeAccount = "";
string labelAnimation    = "";                           // animated ticker
string animationChars[]  = {"|", "/", "—", "\\"};

color  bgColor                = C'212,208,200';
color  fontColor.recordingOn  = Blue;
color  fontColor.recordingOff = Gray;
color  fontColor.notAvailable = Red;
string fontName               = "Tahoma";
int    fontSize               = 8;

int    tickTimerId;                                      // id of the tick timer registered for the chart


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   // validate inputs
   // Recording.HistoryDirectory
   recordingDirectory = StrTrim(Recording.HistoryDirectory);
   if (recordingDirectory != Recording.HistoryDirectory)             return(catch("onInit(1)  invalid input parameter Recording.HistoryDirectory: "+ DoubleQuoteStr(Recording.HistoryDirectory) +" (must not contain trailing white space)", ERR_INVALID_INPUT_PARAMETER));
   if (IsAbsolutePath(recordingDirectory))                           return(catch("onInit(2)  illegal input parameter Recording.HistoryDirectory: "+ DoubleQuoteStr(Recording.HistoryDirectory) +" (not allowed directory name)", ERR_INVALID_INPUT_PARAMETER));
   int illegalChars[] = {':', '*', '?', '"', '<', '>', '|'};
   if (StrContainsChars(recordingDirectory, illegalChars))           return(catch("onInit(3)  invalid input parameter Recording.HistoryDirectory: "+ DoubleQuoteStr(Recording.HistoryDirectory) +" (not a valid directory name)", ERR_INVALID_INPUT_PARAMETER));
   recordingDirectory = StrReplace(recordingDirectory, "\\", "/");
   if (StrStartsWith(recordingDirectory, "/"))                       return(catch("onInit(4)  invalid input parameter Recording.HistoryDirectory: "+ DoubleQuoteStr(Recording.HistoryDirectory) +" (must not start with a slash)", ERR_INVALID_INPUT_PARAMETER));
   if (!CreateDirectory(recordingDirectory, MODE_MQL|MODE_MKPARENT)) return(catch("onInit(5)  cannot create directory "+ DoubleQuoteStr(Recording.HistoryDirectory), ERR_INVALID_INPUT_PARAMETER));
   // Recording.HistoryFormat
   if (Recording.HistoryFormat!=400 && Recording.HistoryFormat!=401) return(catch("onInit(6)  invalid input parameter Recording.HistoryFormat: "+ Recording.HistoryFormat +" (must be 400 or 401)", ERR_INVALID_INPUT_PARAMETER));
   recordingFormat = Recording.HistoryFormat;
   // Broker.SymbolSuffix
   brokerSuffix = StrTrim(Broker.SymbolSuffix);
   if (StringLen(brokerSuffix) > MAX_SYMBOL_LENGTH-1)                return(catch("onInit(7)  invalid input parameter Broker.SymbolSuffix: "+ DoubleQuoteStr(Broker.SymbolSuffix) +" (max. "+ (MAX_SYMBOL_LENGTH-1) +" chars)", ERR_INVALID_INPUT_PARAMETER));

   // initialize global arrays
   int sizeRequired=ArraySize(brokerSymbols), sizeSynthetics=ArraySize(syntheticSymbols);
   ArrayResize(isRequired,       sizeRequired  );
   ArrayResize(isEnabled,        sizeSynthetics);
   ArrayResize(isAvailable,      sizeSynthetics);
   ArrayResize(isStale,          sizeSynthetics); ArrayInitialize(isStale, true);
   ArrayResize(currBid,          sizeSynthetics);
   ArrayResize(currAsk,          sizeSynthetics);
   ArrayResize(currMid,          sizeSynthetics);
   ArrayResize(prevMid,          sizeSynthetics);
   ArrayResize(recordingEnabled, sizeSynthetics);
   ArrayResize(hSet,             sizeSynthetics);
   ArrayResize(labels,           sizeSynthetics);

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
   isEnabled[I_XAUI  ] =   XAUI.Enabled;        // USDLFX is a requirement for all following indexes
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

   // mark synthetic instruments to record
   if (Recording.Enabled) {
      int recordedSymbols;
      recordingEnabled[I_AUDLFX] = AUDLFX.Enabled; recordedSymbols += AUDLFX.Enabled;
      recordingEnabled[I_CADLFX] = CADLFX.Enabled; recordedSymbols += CADLFX.Enabled;
      recordingEnabled[I_CHFLFX] = CHFLFX.Enabled; recordedSymbols += CHFLFX.Enabled;
      recordingEnabled[I_EURLFX] = EURLFX.Enabled; recordedSymbols += EURLFX.Enabled;
      recordingEnabled[I_GBPLFX] = GBPLFX.Enabled; recordedSymbols += GBPLFX.Enabled;
      recordingEnabled[I_JPYLFX] = JPYLFX.Enabled; recordedSymbols += JPYLFX.Enabled;
      recordingEnabled[I_NZDLFX] = NZDLFX.Enabled; recordedSymbols += NZDLFX.Enabled;
      recordingEnabled[I_USDLFX] = USDLFX.Enabled; recordedSymbols += USDLFX.Enabled;
      recordingEnabled[I_NOKFX7] = NOKFX7.Enabled; recordedSymbols += NOKFX7.Enabled;
      recordingEnabled[I_SEKFX7] = SEKFX7.Enabled; recordedSymbols += SEKFX7.Enabled;
      recordingEnabled[I_SGDFX7] = SGDFX7.Enabled; recordedSymbols += SGDFX7.Enabled;
      recordingEnabled[I_ZARFX7] = ZARFX7.Enabled; recordedSymbols += ZARFX7.Enabled;
      recordingEnabled[I_EURX  ] =   EURX.Enabled; recordedSymbols +=   EURX.Enabled;
      recordingEnabled[I_USDX  ] =   USDX.Enabled; recordedSymbols +=   USDX.Enabled;
      recordingEnabled[I_XAUI  ] =   XAUI.Enabled; recordedSymbols +=   XAUI.Enabled;

      // record max. 7 instruments (enforces limit of max. 64 open files per MQL module)
      if (recordedSymbols > 7) {
         for (int i=ArraySize(recordingEnabled)-1; i >= 0; i--) {
            if (recordingEnabled[i]) {
               recordingEnabled[i] = false;
               recordedSymbols--;
               if (recordedSymbols <= 7)
                  break;
            }
         }
      }
   }

   // initialize display options
   CreateLabels();
   SetIndexLabel(0, NULL);

   // restore trade account, calls UpdateAccountDisplay() + RefreshLfxOrders() on success
   if (!RestoreRuntimeStatus())    return(last_error);

   // if trade account was not yet set: initialize trade account and order/limit monitoring
   if (!tradeAccount.number) {
      if (!InitTradeAccount())     return(last_error);
      if (!UpdateAccountDisplay()) return(last_error);
      if (!RefreshLfxOrders())     return(last_error);
   }

   // setup a chart ticker
   if (!This.IsTesting()) {
      int hWnd         = __ExecutionContext[EC.hChart];
      int milliseconds = 500;
      int timerId      = SetupTickTimer(hWnd, milliseconds, NULL);
      if (!timerId) return(catch("onInit(8)->SetupTickTimer(hWnd="+ IntToHexStr(hWnd) +") failed", ERR_RUNTIME_ERROR));
      tickTimerId = timerId;
   }
   return(catch("onInit(9)"));
}


/**
 * Deinitialization
 *
 * @return int - error status
 */
int onDeinit() {
   QC.StopChannels();
   StoreRuntimeStatus();

   int size = ArraySize(hSet);
   for (int i=0; i < size; i++) {
      if (hSet[i] != 0) {
         if (!HistorySet1.Close(hSet[i])) return(ERR_RUNTIME_ERROR);
         hSet[i] = NULL;
      }
   }

   // uninstall the chart ticker
   if (tickTimerId > NULL) {
      int id = tickTimerId; tickTimerId = NULL;
      if (!RemoveTickTimer(id)) return(catch("onDeinit(1)->RemoveTickTimer(timerId="+ id +") failed", ERR_RUNTIME_ERROR));
   }
   return(catch("onDeinit(2)"));
}


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   HandleCommands();                                        // process chart commands

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
 * Handle incoming commands.
 *
 * @param  string commands[] - received external commands
 *
 * @return bool - success status
 *
 * Message format: "cmd=account:[{company-key}:{account-key}]"  => switch the current trade account
 */
bool onCommand(string commands[]) {
   int size = ArraySize(commands);
   if (!size) return(!logWarn("onCommand(1)  empty parameter commands: {}"));

   for (int i=0; i < size; i++) {
      if (StrStartsWith(commands[i], "cmd=account:")) {
         string accountKey     = StrRightFrom(commands[i], ":");
         string accountCompany = tradeAccount.company;
         int    accountNumber  = tradeAccount.number;

         if (!InitTradeAccount(accountKey)) return(false);
         if (tradeAccount.company!=accountCompany || tradeAccount.number!=accountNumber) {
            if (!UpdateAccountDisplay())    return(false);     // update display and watched orders if
            if (!RefreshLfxOrders())        return(false);     // the trade account changed
         }
         continue;
      }
      logWarn("onCommand(2)  unknown command: "+ DoubleQuoteStr(commands[i]));
   }
   return(!catch("onCommand(3)"));
}


/**
 * Whether a chart command was sent to the indicator. If true the command is retrieved and returned.
 *
 * @param  _InOut_ string &commands[] - array to add received commands to
 *
 * @return bool
 */
bool EventListener_ChartCommand(string &commands[]) {
   if (!__isChart) return(false);

   static string label="", mutex=""; if (!StringLen(label)) {
      label = ProgramName() +".command";
      mutex = "mutex."+ label;
   }

   // check for a command non-synchronized (read-only access) to prevent aquiring the lock on every tick
   if (ObjectFind(label) == 0) {
      // now aquire the lock for read-write access
      if (AquireLock(mutex, true)) {
         ArrayPushString(commands, ObjectDescription(label));
         ObjectDelete(label);
         return(ReleaseLock(mutex));
      }
   }
   return(false);
}


/**
 * Read pending and open LFX orders from file into global vars.
 *
 * @return bool - success status
 */
bool RefreshLfxOrders() {
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
 * @return int - error status
 */
int CreateLabels() {
   // trade account
   labelTradeAccount = ProgramName() +".TradeAccount";
   if (ObjectFind(labelTradeAccount) == 0)
      ObjectDelete(labelTradeAccount);
   if (ObjectCreate(labelTradeAccount, OBJ_LABEL, 0, 0, 0)) {
      ObjectSet    (labelTradeAccount, OBJPROP_CORNER, CORNER_BOTTOM_RIGHT);
      ObjectSet    (labelTradeAccount, OBJPROP_XDISTANCE, 6);
      ObjectSet    (labelTradeAccount, OBJPROP_YDISTANCE, 4);
      ObjectSetText(labelTradeAccount, " ", 1);
      RegisterObject(labelTradeAccount);
   }
   else GetLastError();

   // index display
   int counter = 10;                                     // a counter for creating unique labels (with at least 2 digits)
   // background rectangles
   string label = StringConcatenate(ProgramName(), ".", counter, ".Background");
   if (ObjectFind(label) == 0)
      ObjectDelete(label);
   if (ObjectCreate(label, OBJ_LABEL, 0, 0, 0)) {
      ObjectSet    (label, OBJPROP_CORNER, CORNER_TOP_RIGHT);
      ObjectSet    (label, OBJPROP_XDISTANCE, 7);
      ObjectSet    (label, OBJPROP_YDISTANCE, 7);
      ObjectSetText(label, "g", 128, "Webdings", bgColor);
      RegisterObject(label);
   }
   else GetLastError();

   counter++;
   label = StringConcatenate(ProgramName(), ".", counter, ".Background");
   if (ObjectFind(label) == 0)
      ObjectDelete(label);
   if (ObjectCreate(label, OBJ_LABEL, 0, 0, 0)) {
      ObjectSet    (label, OBJPROP_CORNER, CORNER_TOP_RIGHT);
      ObjectSet    (label, OBJPROP_XDISTANCE,  7);
      ObjectSet    (label, OBJPROP_YDISTANCE, 81);
      ObjectSetText(label, "g", 128, "Webdings", bgColor);
      RegisterObject(label);
   }
   else GetLastError();

   int   yCoord    = 9;
   color fontColor = ifInt(Recording.Enabled, fontColor.recordingOn, fontColor.recordingOff);

   // animation
   counter++;
   label = StringConcatenate(ProgramName(), ".", counter, ".Header.animation");
   if (ObjectFind(label) == 0)
      ObjectDelete(label);
   if (ObjectCreate(label, OBJ_LABEL, 0, 0, 0)) {
      ObjectSet    (label, OBJPROP_CORNER, CORNER_TOP_RIGHT);
      ObjectSet    (label, OBJPROP_XDISTANCE, 203);
      ObjectSet    (label, OBJPROP_YDISTANCE, yCoord);
      ObjectSetText(label, animationChars[0], fontSize, fontName, fontColor);
      RegisterObject(label);
      labelAnimation = label;
   }
   else GetLastError();

   // recording status
   label = StringConcatenate(ProgramName(), ".", counter, ".Recording.status");
   if (ObjectFind(label) == 0)
      ObjectDelete(label);
   if (ObjectCreate(label, OBJ_LABEL, 0, 0, 0)) {
      ObjectSet    (label, OBJPROP_CORNER, CORNER_TOP_RIGHT);
      ObjectSet    (label, OBJPROP_XDISTANCE, 10);
      ObjectSet    (label, OBJPROP_YDISTANCE, yCoord);
      string directory = recordingDirectory;
      if (StrContains(directory, "/"))
         directory = "../"+ StrRightFrom(directory, "/", -1);
      string text = ifString(Recording.Enabled, "Recording to "+ directory, "Recording:  off");
      ObjectSetText(label, text, fontSize, fontName, fontColor);
      RegisterObject(label);
   }
   else GetLastError();

   // data rows
   yCoord += 16;
   for (int i=0; i < ArraySize(syntheticSymbols); i++) {
      fontColor = ifInt(recordingEnabled[i], fontColor.recordingOn, fontColor.recordingOff);
      counter++;

      // symbol
      label = StringConcatenate(ProgramName(), ".", counter, ".", syntheticSymbols[i]);
      if (ObjectFind(label) == 0)
         ObjectDelete(label);
      if (ObjectCreate(label, OBJ_LABEL, 0, 0, 0)) {
         ObjectSet    (label, OBJPROP_CORNER, CORNER_TOP_RIGHT);
         ObjectSet    (label, OBJPROP_XDISTANCE, 129          );
         ObjectSet    (label, OBJPROP_YDISTANCE, yCoord + i*15);
         ObjectSetText(label, syntheticSymbols[i] +":", fontSize, fontName, fontColor);
         RegisterObject(label);
         labels[i] = label;
      }
      else GetLastError();

      // price
      label = StringConcatenate(labels[i], ".quote");
      if (ObjectFind(label) == 0)
         ObjectDelete(label);
      if (ObjectCreate(label, OBJ_LABEL, 0, 0, 0)) {
         ObjectSet    (label, OBJPROP_CORNER, CORNER_TOP_RIGHT);
         ObjectSet    (label, OBJPROP_XDISTANCE, 64);
         ObjectSet    (label, OBJPROP_YDISTANCE, yCoord + i*15);
            text = ifString(!isEnabled[i], "off", "n/a");
         ObjectSetText(label, text, fontSize, fontName, fontColor.recordingOff);
         RegisterObject(label);
      }
      else GetLastError();

      // spread
      label = StringConcatenate(labels[i], ".spread");
      if (ObjectFind(label) == 0)
         ObjectDelete(label);
      if (ObjectCreate(label, OBJ_LABEL, 0, 0, 0)) {
         ObjectSet    (label, OBJPROP_CORNER, CORNER_TOP_RIGHT);
         ObjectSet    (label, OBJPROP_XDISTANCE, 15);
         ObjectSet    (label, OBJPROP_YDISTANCE, yCoord + i*15);
         ObjectSetText(label, " ");
         RegisterObject(label);
      }
      else GetLastError();
   }

   return(catch("CreateLabels(1)"));
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

   bid     = MarketInfo(symbol, MODE_BID);
   ask     = MarketInfo(symbol, MODE_ASK);
   median  = (bid + ask)/2;
   isStale = MarketInfo(symbol, MODE_TIME) < staleLimit;

   int error = GetLastError();
   if (!error) return(true);

   bid     = NULL;
   ask     = NULL;
   median  = NULL;
   isStale = true;

   if (error != ERR_SYMBOL_NOT_AVAILABLE)
      return(!catch("GetMarketData(1)  symbol=\""+ symbol +"\"", error));

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
         double eurchf = usdchf * eurusd;
         double eurgbp = eurusd / gbpusd;
         double eurjpy = usdjpy * eurusd;
         double eursek = usdsek * eurusd;
         prevMid[I_EURX] = currMid[I_EURX];
         currMid[I_EURX] = 34.38805726 * MathPow(eurusd, 0.3155) * MathPow(eurgbp, 0.3056) * MathPow(eurjpy, 0.1891) * MathPow(eurchf, 0.1113) * MathPow(eursek, 0.0785);
         currBid[I_EURX] = 0;                   // TODO
         currAsk[I_EURX] = 0;                   // TODO
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
         currBid[I_XAUI] = 0;                   // TODO
         currAsk[I_XAUI] = 0;                   // TODO
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
   //if (!IsChartVisible()) return(true);          // TODO: update only if the chart is visible

   // animation
   int   chars     = ArraySize(animationChars);
   color fontColor = ifInt(Recording.Enabled, fontColor.recordingOn, fontColor.recordingOff);
   ObjectSetText(labelAnimation, animationChars[Tick % chars], fontSize, fontName, fontColor);

   // calculated values
   int size = ArraySize(syntheticSymbols);
   string sIndex="", sSpread="";

   for (int i=0; i < size; i++) {
      if (isEnabled[i]) {
         fontColor = fontColor.recordingOff;
         if (isAvailable[i]) {
            sIndex  = NumberToStr(NormalizeDouble(currMid[i], symbolDigits[i]), symbolPriceFormat[i]);
            sSpread = "("+ DoubleToStr((currAsk[i]-currBid[i])/symbolPipSize[i], 1) +")";
            if (recordingEnabled[i]) /*&&*/ if (!isStale[i])
               fontColor = fontColor.recordingOn;
         }
         else {
            sIndex  = "n/a";
            sSpread = " ";
         }
         ObjectSetText(labels[i] +".quote",  sIndex,  fontSize, fontName, fontColor);
         ObjectSetText(labels[i] +".spread", sSpread, fontSize, fontName, fontColor);
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
   datetime nowFXT = GetFxtTime();
   int size = ArraySize(syntheticSymbols);

   for (int i=0; i < size; i++) {
      if (recordingEnabled[i] && !isStale[i]) {
         double value     = NormalizeDouble(currMid[i], symbolDigits[i]);
         double lastValue = prevMid[i];

         if (Tick.isVirtual) {                           // Virtual ticks (there are many) are recorded only if the calculated
            if (EQ(value, lastValue, symbolDigits[i]))   // price changed. Real ticks are always recorded.
               continue;
         }
         if (!hSet[i]) {
            hSet[i] = HistorySet1.Get(syntheticSymbols[i], recordingDirectory);
            if (hSet[i] == -1)
               hSet[i] = HistorySet1.Create(syntheticSymbols[i], symbolLongName[i], symbolDigits[i], recordingFormat, recordingDirectory);
            if (!hSet[i]) return(false);
         }
         if (!HistorySet1.AddTick(hSet[i], nowFXT, value, NULL)) return(false);
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
   if (mode.extern) {
      string text = "Limits:  "+ tradeAccount.name +", "+ tradeAccount.company +", "+ tradeAccount.number +", "+ tradeAccount.currency;
      ObjectSetText(labelTradeAccount, text, 8, "Arial Fett", ifInt(tradeAccount.type==ACCOUNT_TYPE_DEMO, LimeGreen, DarkOrange));
   }
   else {
      ObjectSetText(labelTradeAccount, " ", 1);
   }

   int error = GetLastError();
   if (!error || error==ERR_OBJECT_DOES_NOT_EXIST)                 // on ObjectDrag or opened "Properties" dialog
      return(true);
   return(!catch("UpdateAccountDisplay(1)", error));
}


/**
 * Store the runtime configuration in the chart window (init cycles and template reload) and in the chart (terminal restart).
 *
 * vars: string tradeAccount.company
 *       int    tradeAccount.number
 *
 * @return bool - success status
 */
bool StoreRuntimeStatus() {
   // store company alias in chart window
   int    hWnd = __ExecutionContext[EC.hChart];
   string key  = ProgramName() +".runtime.tradeAccount.company";   // TODO: add program pid and manage keys globally
   SetWindowStringA(hWnd, key, tradeAccount.company);

   // store company alias in chart
   if (ObjectFind(key) == 0)
      ObjectDelete(key);
   ObjectCreate (key, OBJ_LABEL, 0, 0, 0);
   ObjectSet    (key, OBJPROP_TIMEFRAMES, OBJ_PERIODS_NONE);
   ObjectSetText(key, tradeAccount.company);

   // store account number in chart window
   key = ProgramName() +".runtime.tradeAccount.number";            // TODO: add program pid and manage keys globally
   SetWindowIntegerA(hWnd, key, tradeAccount.number);

   // store account number in chart
   if (ObjectFind(key) == 0)
      ObjectDelete(key);
   ObjectCreate (key, OBJ_LABEL, 0, 0, 0);
   ObjectSet    (key, OBJPROP_TIMEFRAMES, OBJ_PERIODS_NONE);
   ObjectSetText(key, ""+ tradeAccount.number);

   return(!catch("StoreRuntimeStatus(1)"));
}


/**
 * Restore the runtime configuration from the chart and/or chart window.
 *
 * vars: string tradeAccount.company
 *       int    tradeAccount.number
 *
 * @return bool - success status
 */
bool RestoreRuntimeStatus() {
   // lookup company alias in chart window
   int hWnd = __ExecutionContext[EC.hChart];
   string key = ProgramName() +".runtime.tradeAccount.company";      // TODO: add program pid and manage keys globally
   string company = GetWindowStringA(hWnd, key);
   if (!StringLen(company)) {
      if (ObjectFind(key) == 0) company = ObjectDescription(key);    // on failure lookup company alias in chart
   }

   // lookup account number in chart window
   key = ProgramName() +".runtime.tradeAccount.number";             // TODO: add program pid and manage keys globally
   int accountNumber = GetWindowIntegerA(hWnd, key);
   if (!accountNumber) {
      if (ObjectFind(key) == 0)
         accountNumber = StrToInteger(ObjectDescription(key));       // on failure lookup account number in chart
   }

   // restore account data
   if (StringLen(company) && accountNumber) {
      string oldCompany    = tradeAccount.company;
      int oldAccountNumber = tradeAccount.number;

      if (!InitTradeAccount(company +":"+ accountNumber)) return(false);
      if (tradeAccount.company!=oldCompany || tradeAccount.number!=oldAccountNumber) {
         if (!UpdateAccountDisplay())                     return(false);
         if (!RefreshLfxOrders())                         return(false);
      }
   }
   return(!catch("RestoreRuntimeStatus(1)"));
}


/**
 * Return a string representation of the input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("AUDLFX.Enabled=",             BoolToStr(AUDLFX.Enabled),                  ";"+ NL,
                            "CADLFX.Enabled=",             BoolToStr(CADLFX.Enabled),                  ";"+ NL,
                            "CHFLFX.Enabled=",             BoolToStr(CHFLFX.Enabled),                  ";"+ NL,
                            "EURLFX.Enabled=",             BoolToStr(EURLFX.Enabled),                  ";"+ NL,
                            "GBPLFX.Enabled=",             BoolToStr(GBPLFX.Enabled),                  ";"+ NL,
                            "JPYLFX.Enabled=",             BoolToStr(JPYLFX.Enabled),                  ";"+ NL,
                            "NZDLFX.Enabled=",             BoolToStr(NZDLFX.Enabled),                  ";"+ NL,
                            "USDLFX.Enabled=",             BoolToStr(USDLFX.Enabled),                  ";"+ NL,
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
