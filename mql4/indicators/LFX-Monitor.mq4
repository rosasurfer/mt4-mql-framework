/**
 * LFX Monitor
 *
 * Calculates various synthetic indexes, records index history and processes trade limits of synthetic positions.
 * Index descriptions:
 *
 * @see  https://github.com/rosasurfer/mt4-tools/tree/master/app/lib/synthetic
 */
#include <stddefines.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern bool   Recording.Enabled = false;                             // default: recording disabled
extern string _1________________________;
extern bool   AUDLFX.Enabled    = true;                              // default: all indexes enabled
extern bool   CADLFX.Enabled    = true;
extern bool   CHFLFX.Enabled    = true;
extern bool   EURLFX.Enabled    = true;
extern bool   GBPLFX.Enabled    = true;
extern bool   JPYLFX.Enabled    = true;
extern bool   NZDLFX.Enabled    = true;
extern bool   USDLFX.Enabled    = true;
extern string _2________________________;
extern bool   NOKFX7.Enabled    = true;
extern bool   SEKFX7.Enabled    = true;
extern bool   SGDFX7.Enabled    = true;
extern bool   ZARFX7.Enabled    = true;
extern string _3________________________;
extern bool   EURX.Enabled      = true;
extern bool   USDX.Enabled      = true;
extern string _4________________________;
extern bool   XAUI.Enabled      = true;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <functions/InitializeByteBuffer.mqh>
#include <functions/JoinStrings.mqh>
#include <rsfLibs.mqh>
#include <rsfHistory.mqh>

#include <MT4iQuickChannel.mqh>
#include <lfx.mqh>
#include <structs/rsf/LFXOrder.mqh>

#property indicator_chart_window


string   symbols     [] = { "AUDLFX", "CADLFX", "CHFLFX", "EURLFX", "GBPLFX", "JPYLFX", "NZDLFX", "USDLFX", "NOKFX7", "SEKFX7", "SGDFX7", "ZARFX7", "EURX", "USDX", "XAUI" };
string   longNames   [] = { "LiteForex Australian Dollar index", "LiteForex Canadian Dollar index", "LiteForex Swiss Franc index", "LiteForex Euro index", "LiteForex Great Britain Pound index", "LiteForex Japanese Yen index", "LiteForex New Zealand Dollar index", "LiteForex US Dollar index", "Norwegian Krona vs Majors index", "Swedish Kronor vs Majors index", "Singapore Dollar vs Majors index", "South African Rand vs Majors index", "ICE Euro Futures index", "ICE US Dollar Futures index", "Gold vs Majors index" };
int      digits      [] = { 5       , 5       , 5       , 5       , 5       , 5       , 5       , 5       , 5       , 5       , 5       , 5       , 3     , 3     , 3      };
double   pipSizes    [] = { 0.0001  , 0.0001  , 0.0001  , 0.0001  , 0.0001  , 0.0001  , 0.0001  , 0.0001  , 0.0001  , 0.0001  , 0.0001  , 0.0001  , 0.01  , 0.01  , 0.01   };
string   priceFormats[] = { "R.4'"  , "R.4'"  , "R.4'"  , "R.4'"  , "R.4'"  , "R.4'"  , "R.4'"  , "R.4'"  , "R.4'"  , "R.4'"  , "R.4'"  , "R.4'"  , "R.2'", "R.2'", "R.2'" };

bool     isEnabled  [];                                        // whether calculation is enabled (equal to *.Enabled)
bool     isAvailable[];                                        // whether all prices for calculation are available
bool     isStale    [];                                        // whether some prices for calculation are stale (not current)
double   curr.bid   [];                                        // current calculated Bid value
double   curr.ask   [];                                        // current calculated Ask value
double   curr.median[];                                        // current calculated Median value
double   prev.median[];                                        // previous calculated Median value

bool     isRecording[];                                        // default: FALSE
int      hSet       [];                                        // HistorySet handles
string   serverName = "XTrade-Synthetic";                      // default server name for storing recorded history
datetime staleLimit;                                           // current time limit (server time) for stale quotes determination

int AUDLFX.orders[][LFX_ORDER.intSize];                        // array of LFX orders
int CADLFX.orders[][LFX_ORDER.intSize];
int CHFLFX.orders[][LFX_ORDER.intSize];
int EURLFX.orders[][LFX_ORDER.intSize];
int GBPLFX.orders[][LFX_ORDER.intSize];
int JPYLFX.orders[][LFX_ORDER.intSize];
int NZDLFX.orders[][LFX_ORDER.intSize];
int USDLFX.orders[][LFX_ORDER.intSize];
int NOKFX7.orders[][LFX_ORDER.intSize];
int SEKFX7.orders[][LFX_ORDER.intSize];
int SGDFX7.orders[][LFX_ORDER.intSize];
int ZARFX7.orders[][LFX_ORDER.intSize];
int   EURX.orders[][LFX_ORDER.intSize];
int   USDX.orders[][LFX_ORDER.intSize];
int   XAUI.orders[][LFX_ORDER.intSize];

#define I_AUDLFX     0                                         // array indexes
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


// text labels for various display elements
string labels[];
string label.tradeAccount;
string label.animation;                                        // animated ticker
string label.animation.chars[] = {"|", "/", "—", "\\"};

color  bgColor                = C'212,208,200';
color  fontColor.recordingOn  = Blue;
color  fontColor.recordingOff = Gray;
color  fontColor.notAvailable = Red;
string fontName               = "Tahoma";
int    fontSize               = 8;

int    tickTimerId;                                            // id of the tick timer registered for the chart


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   // initialize array sizes
   int size = ArraySize(symbols);
   ArrayResize(isEnabled  , size);
   ArrayResize(isAvailable, size);
   ArrayResize(isStale    , size); ArrayInitialize(isStale, true);
   ArrayResize(curr.bid   , size);
   ArrayResize(curr.ask   , size);
   ArrayResize(curr.median, size);
   ArrayResize(prev.median, size);
   ArrayResize(isRecording, size);
   ArrayResize(hSet       , size);
   ArrayResize(labels     , size);

   // process input parameters
   isEnabled[I_AUDLFX] = AUDLFX.Enabled;
   isEnabled[I_CADLFX] = CADLFX.Enabled;
   isEnabled[I_CHFLFX] = CHFLFX.Enabled;
   isEnabled[I_EURLFX] = EURLFX.Enabled;
   isEnabled[I_GBPLFX] = GBPLFX.Enabled;
   isEnabled[I_JPYLFX] = JPYLFX.Enabled;
   isEnabled[I_NZDLFX] = NZDLFX.Enabled;
   isEnabled[I_USDLFX] = USDLFX.Enabled;
   isEnabled[I_NOKFX7] = NOKFX7.Enabled;
   isEnabled[I_SEKFX7] = SEKFX7.Enabled;
   isEnabled[I_SGDFX7] = SGDFX7.Enabled;
   isEnabled[I_ZARFX7] = ZARFX7.Enabled;
   isEnabled[I_EURX  ] =   EURX.Enabled;
   isEnabled[I_USDX  ] =   USDX.Enabled;
   isEnabled[I_XAUI  ] =   XAUI.Enabled;

   if (Recording.Enabled) {
      int recordedSymbols;
      isRecording[I_AUDLFX] = AUDLFX.Enabled; recordedSymbols += AUDLFX.Enabled;
      isRecording[I_CADLFX] = CADLFX.Enabled; recordedSymbols += CADLFX.Enabled;
      isRecording[I_CHFLFX] = CHFLFX.Enabled; recordedSymbols += CHFLFX.Enabled;
      isRecording[I_EURLFX] = EURLFX.Enabled; recordedSymbols += EURLFX.Enabled;
      isRecording[I_GBPLFX] = GBPLFX.Enabled; recordedSymbols += GBPLFX.Enabled;
      isRecording[I_JPYLFX] = JPYLFX.Enabled; recordedSymbols += JPYLFX.Enabled;
      isRecording[I_NZDLFX] = NZDLFX.Enabled; recordedSymbols += NZDLFX.Enabled;
      isRecording[I_USDLFX] = USDLFX.Enabled; recordedSymbols += USDLFX.Enabled;
      isRecording[I_NOKFX7] = NOKFX7.Enabled; recordedSymbols += NOKFX7.Enabled;
      isRecording[I_SEKFX7] = SEKFX7.Enabled; recordedSymbols += SEKFX7.Enabled;
      isRecording[I_SGDFX7] = SGDFX7.Enabled; recordedSymbols += SGDFX7.Enabled;
      isRecording[I_ZARFX7] = ZARFX7.Enabled; recordedSymbols += ZARFX7.Enabled;
      isRecording[I_EURX  ] =   EURX.Enabled; recordedSymbols +=   EURX.Enabled;
      isRecording[I_USDX  ] =   USDX.Enabled; recordedSymbols +=   USDX.Enabled;
      isRecording[I_XAUI  ] =   XAUI.Enabled; recordedSymbols +=   XAUI.Enabled;

      // record max. 7 instruments (enforces limit of nax. 64 open files per MQL module)
      if (recordedSymbols > 7) {
         for (int i=ArraySize(isRecording)-1; i >= 0; i--) {
            if (isRecording[i]) {
               isRecording[i] = false;
               recordedSymbols--;
               if (recordedSymbols <= 7)
                  break;
            }
         }
      }
   }

   // initialize the display
   CreateLabels();

   // restore a previously stored status (including a set trade account)
   if (!RestoreRuntimeStatus())    return(last_error);

   // initialize trade account and limit processing (only if trade account was not yet set)
   if (!tradeAccount.number) {
      if (!InitTradeAccount())     return(last_error);
      if (!UpdateAccountDisplay()) return(last_error);
      if (!RefreshLfxOrders())     return(last_error);
   }

   // setup the chart ticker
   if (!This.IsTesting()) /*&&*/ if (!StrStartsWithI(GetServerName(), "XTrade-")) {
      int hWnd = __ExecutionContext[EC.hChart];
      int milliseconds = 500;
      int timerId = SetupTickTimer(hWnd, milliseconds, NULL);
      if (!timerId) return(catch("onInit(2)->SetupTickTimer(hWnd="+ IntToHexStr(hWnd) +") failed", ERR_RUNTIME_ERROR));
      tickTimerId = timerId;
   }

   // disable data in "Data" window
   SetIndexLabel(0, NULL);
   return(catch("onInit(3)"));
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
         if (!HistorySet.Close(hSet[i])) return(ERR_RUNTIME_ERROR);
         hSet[i] = NULL;
      }
   }

   // uninstall the chart ticker
   if (tickTimerId > NULL) {
      int id = tickTimerId;
      tickTimerId = NULL;
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
   HandleCommands();                                                 // process chart commands

   staleLimit = GetServerTime() - 10*MINUTES;                        // SGD|ZAR may need a few minutes for the first tick

   if (!CalculateIndices())   return(last_error);
   if (!ProcessAllLimits())   return(last_error);
   if (!UpdateIndexDisplay()) return(last_error);

   if (Recording.Enabled) {
      if (!RecordIndices())   return(last_error);
   }
   return(last_error);

   // TODO: check/detect if the limits to watch have been changed (but not on every tick)
}


/**
 * Handle incoming commands.
 *
 * @param  string commands[] - received external commands
 *
 * @return bool - success status
 *
 * Message format:
 *   "cmd=account:[{companyKey}:{accountKey}]"  => switch/select the current trade account
 */
bool onCommand(string commands[]) {
   int size = ArraySize(commands);
   if (!size) return(!warn("onCommand(1)  empty parameter commands = {}"));

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
      warn("onCommand(2)  unknown command = "+ DoubleQuoteStr(commands[i]));
   }
   return(!catch("onCommand(3)"));
}


/**
 * Read the LFX orders to watch for the current trade account.
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
   if (ArrayRange(AUDLFX.orders, 0) != 0) debug("RefreshLfxOrders()  AUDLFX limit orders: "+ ArrayRange(AUDLFX.orders, 0));
   if (ArrayRange(CADLFX.orders, 0) != 0) debug("RefreshLfxOrders()  CADLFX limit orders: "+ ArrayRange(CADLFX.orders, 0));
   if (ArrayRange(CHFLFX.orders, 0) != 0) debug("RefreshLfxOrders()  CHFLFX limit orders: "+ ArrayRange(CHFLFX.orders, 0));
   if (ArrayRange(EURLFX.orders, 0) != 0) debug("RefreshLfxOrders()  EURLFX limit orders: "+ ArrayRange(EURLFX.orders, 0));
   if (ArrayRange(GBPLFX.orders, 0) != 0) debug("RefreshLfxOrders()  GBPLFX limit orders: "+ ArrayRange(GBPLFX.orders, 0));
   if (ArrayRange(JPYLFX.orders, 0) != 0) debug("RefreshLfxOrders()  JPYLFX limit orders: "+ ArrayRange(JPYLFX.orders, 0));
   if (ArrayRange(NZDLFX.orders, 0) != 0) debug("RefreshLfxOrders()  NZDLFX limit orders: "+ ArrayRange(NZDLFX.orders, 0));
   if (ArrayRange(USDLFX.orders, 0) != 0) debug("RefreshLfxOrders()  USDLFX limit orders: "+ ArrayRange(USDLFX.orders, 0));
   if (ArrayRange(NOKFX7.orders, 0) != 0) debug("RefreshLfxOrders()  NOKFX7 limit orders: "+ ArrayRange(NOKFX7.orders, 0));
   if (ArrayRange(SEKFX7.orders, 0) != 0) debug("RefreshLfxOrders()  SEKFX7 limit orders: "+ ArrayRange(SEKFX7.orders, 0));
   if (ArrayRange(SGDFX7.orders, 0) != 0) debug("RefreshLfxOrders()  SGDFX7 limit orders: "+ ArrayRange(SGDFX7.orders, 0));
   if (ArrayRange(ZARFX7.orders, 0) != 0) debug("RefreshLfxOrders()  ZARFX7 limit orders: "+ ArrayRange(ZARFX7.orders, 0));
   if (ArrayRange(  EURX.orders, 0) != 0) debug("RefreshLfxOrders()    EURX limit orders: "+ ArrayRange(  EURX.orders, 0));
   if (ArrayRange(  USDX.orders, 0) != 0) debug("RefreshLfxOrders()    USDX limit orders: "+ ArrayRange(  USDX.orders, 0));
   if (ArrayRange(  XAUI.orders, 0) != 0) debug("RefreshLfxOrders()    XAUI limit orders: "+ ArrayRange(  XAUI.orders, 0));

   return(true);
}


/**
 * Create and initialize text objects for the various display elements.
 *
 * @return int - error status
 */
int CreateLabels() {
   // trade account
   label.tradeAccount = __NAME() +".TradeAccount";
   if (ObjectFind(label.tradeAccount) == 0)
      ObjectDelete(label.tradeAccount);
   if (ObjectCreate(label.tradeAccount, OBJ_LABEL, 0, 0, 0)) {
      ObjectSet    (label.tradeAccount, OBJPROP_CORNER, CORNER_BOTTOM_RIGHT);
      ObjectSet    (label.tradeAccount, OBJPROP_XDISTANCE, 6);
      ObjectSet    (label.tradeAccount, OBJPROP_YDISTANCE, 4);
      ObjectSetText(label.tradeAccount, " ", 1);
      RegisterObject(label.tradeAccount);
   }
   else GetLastError();

   // index display
   int counter = 10;                                     // a counter for creating unique labels (with at least 2 digits)
   // background rectangles
   string label = StringConcatenate(__NAME(), ".", counter, ".Background");
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
   label = StringConcatenate(__NAME(), ".", counter, ".Background");
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
   label = StringConcatenate(__NAME(), ".", counter, ".Header.animation");
   if (ObjectFind(label) == 0)
      ObjectDelete(label);
   if (ObjectCreate(label, OBJ_LABEL, 0, 0, 0)) {
      ObjectSet    (label, OBJPROP_CORNER, CORNER_TOP_RIGHT);
      ObjectSet    (label, OBJPROP_XDISTANCE, 165   );
      ObjectSet    (label, OBJPROP_YDISTANCE, yCoord);
      ObjectSetText(label, label.animation.chars[0], fontSize, fontName, fontColor);
      RegisterObject(label);
      label.animation = label;
   }
   else GetLastError();

   // recording status
   label = StringConcatenate(__NAME(), ".", counter, ".Recording.status");
   if (ObjectFind(label) == 0)
      ObjectDelete(label);
   if (ObjectCreate(label, OBJ_LABEL, 0, 0, 0)) {
      ObjectSet    (label, OBJPROP_CORNER, CORNER_TOP_RIGHT);
      ObjectSet    (label, OBJPROP_XDISTANCE, 10);
      ObjectSet    (label, OBJPROP_YDISTANCE, yCoord);
         string text = ifString(Recording.Enabled, "Recording to "+ serverName, "Recording:  off");
      ObjectSetText(label, text, fontSize, fontName, fontColor);
      RegisterObject(label);
   }
   else GetLastError();

   // data rows
   yCoord += 16;
   for (int i=0; i < ArraySize(symbols); i++) {
      fontColor = ifInt(isRecording[i], fontColor.recordingOn, fontColor.recordingOff);
      counter++;

      // symbol
      label = StringConcatenate(__NAME(), ".", counter, ".", symbols[i]);
      if (ObjectFind(label) == 0)
         ObjectDelete(label);
      if (ObjectCreate(label, OBJ_LABEL, 0, 0, 0)) {
         ObjectSet    (label, OBJPROP_CORNER, CORNER_TOP_RIGHT);
         ObjectSet    (label, OBJPROP_XDISTANCE, 129          );
         ObjectSet    (label, OBJPROP_YDISTANCE, yCoord + i*15);
         ObjectSetText(label, symbols[i] +":", fontSize, fontName, fontColor);
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
 * Calculate the configured synthetic instruments.
 *
 * @return bool - success status
 */
bool CalculateIndices() {
   double usdcad_Bid = MarketInfo("USDCAD", MODE_BID), usdcad_Ask = MarketInfo("USDCAD", MODE_ASK), usdcad = (usdcad_Bid + usdcad_Ask)/2; bool usdcad_stale = MarketInfo("USDCAD", MODE_TIME) < staleLimit;
   double usdchf_Bid = MarketInfo("USDCHF", MODE_BID), usdchf_Ask = MarketInfo("USDCHF", MODE_ASK), usdchf = (usdchf_Bid + usdchf_Ask)/2; bool usdchf_stale = MarketInfo("USDCHF", MODE_TIME) < staleLimit;
   double usdjpy_Bid = MarketInfo("USDJPY", MODE_BID), usdjpy_Ask = MarketInfo("USDJPY", MODE_ASK), usdjpy = (usdjpy_Bid + usdjpy_Ask)/2; bool usdjpy_stale = MarketInfo("USDJPY", MODE_TIME) < staleLimit;
   double audusd_Bid = MarketInfo("AUDUSD", MODE_BID), audusd_Ask = MarketInfo("AUDUSD", MODE_ASK), audusd = (audusd_Bid + audusd_Ask)/2; bool audusd_stale = MarketInfo("AUDUSD", MODE_TIME) < staleLimit;
   double eurusd_Bid = MarketInfo("EURUSD", MODE_BID), eurusd_Ask = MarketInfo("EURUSD", MODE_ASK), eurusd = (eurusd_Bid + eurusd_Ask)/2; bool eurusd_stale = MarketInfo("EURUSD", MODE_TIME) < staleLimit;
   double gbpusd_Bid = MarketInfo("GBPUSD", MODE_BID), gbpusd_Ask = MarketInfo("GBPUSD", MODE_ASK), gbpusd = (gbpusd_Bid + gbpusd_Ask)/2; bool gbpusd_stale = MarketInfo("GBPUSD", MODE_TIME) < staleLimit;
   double nzdusd_Bid = MarketInfo("NZDUSD", MODE_BID), nzdusd_Ask = MarketInfo("NZDUSD", MODE_ASK), nzdusd = (nzdusd_Bid + nzdusd_Ask)/2; bool nzdusd_stale = MarketInfo("NZDUSD", MODE_TIME) < staleLimit;
   double usdnok_Bid = MarketInfo("USDNOK", MODE_BID), usdnok_Ask = MarketInfo("USDNOK", MODE_ASK), usdnok = (usdnok_Bid + usdnok_Ask)/2; bool usdnok_stale = MarketInfo("USDNOK", MODE_TIME) < staleLimit;
   double usdsek_Bid = MarketInfo("USDSEK", MODE_BID), usdsek_Ask = MarketInfo("USDSEK", MODE_ASK), usdsek = (usdsek_Bid + usdsek_Ask)/2; bool usdsek_stale = MarketInfo("USDSEK", MODE_TIME) < staleLimit;
   double usdsgd_Bid = MarketInfo("USDSGD", MODE_BID), usdsgd_Ask = MarketInfo("USDSGD", MODE_ASK), usdsgd = (usdsgd_Bid + usdsgd_Ask)/2; bool usdsgd_stale = MarketInfo("USDSGD", MODE_TIME) < staleLimit;
   double usdzar_Bid = MarketInfo("USDZAR", MODE_BID), usdzar_Ask = MarketInfo("USDZAR", MODE_ASK), usdzar = (usdzar_Bid + usdzar_Ask)/2; bool usdzar_stale = MarketInfo("USDZAR", MODE_TIME) < staleLimit;
   double xauusd_Bid = MarketInfo("XAUUSD", MODE_BID), xauusd_Ask = MarketInfo("XAUUSD", MODE_ASK), xauusd = (xauusd_Bid + xauusd_Ask)/2; bool xauusd_stale = MarketInfo("XAUUSD", MODE_TIME) < staleLimit;

   // USDLFX first and always (calculation base for almost everything)
   if (true) {                                                       // USDLFX = ((USDCAD * USDCHF * USDJPY) / (AUDUSD * EURUSD * GBPUSD)) ^ 1/7
      isAvailable[I_USDLFX] = (usdcad_Bid && usdchf_Bid && usdjpy_Bid && audusd_Bid && eurusd_Bid && gbpusd_Bid);
      if (isAvailable[I_USDLFX]) {
         prev.median [I_USDLFX] = curr.median[I_USDLFX];
         curr.median [I_USDLFX] = MathPow((usdcad     * usdchf     * usdjpy    ) / (audusd     * eurusd     * gbpusd    ), 1/7.);
         curr.bid    [I_USDLFX] = MathPow((usdcad_Bid * usdchf_Bid * usdjpy_Bid) / (audusd_Ask * eurusd_Ask * gbpusd_Ask), 1/7.);
         curr.ask    [I_USDLFX] = MathPow((usdcad_Ask * usdchf_Ask * usdjpy_Ask) / (audusd_Bid * eurusd_Bid * gbpusd_Bid), 1/7.);
         isStale     [I_USDLFX] = usdcad_stale || usdchf_stale || usdjpy_stale || audusd_stale || eurusd_stale || gbpusd_stale;
      }
      else isStale   [I_USDLFX] = true;
   }

   if (AUDLFX.Enabled) {                                             //     AUDLFX = ((AUDCAD * AUDCHF * AUDJPY * AUDUSD) / (EURAUD * GBPAUD)) ^ 1/7
      isAvailable[I_AUDLFX] = isAvailable[I_USDLFX];                 // or: AUDLFX = USDLFX * AUDUSD
      if (isAvailable[I_AUDLFX]) {
         prev.median [I_AUDLFX] = curr.median[I_AUDLFX];
         curr.median [I_AUDLFX] = curr.median[I_USDLFX] * audusd;
         curr.bid    [I_AUDLFX] = MathPow((usdcad_Bid * usdchf_Bid * usdjpy_Bid) / (audusd_Bid * eurusd_Ask * gbpusd_Ask), 1/7.) * audusd_Bid;
         curr.ask    [I_AUDLFX] = MathPow((usdcad_Ask * usdchf_Ask * usdjpy_Ask) / (audusd_Ask * eurusd_Bid * gbpusd_Bid), 1/7.) * audusd_Ask;
         isStale     [I_AUDLFX] = isStale[I_USDLFX];
      }
      else isStale   [I_AUDLFX] = true;
   }

   if (CADLFX.Enabled) {                                             //     CADLFX = ((CADCHF * CADJPY) / (AUDCAD * EURCAD * GBPCAD * USDCAD)) ^ 1/7
      isAvailable[I_CADLFX] = isAvailable[I_USDLFX];                 // or: CADLFX = USDLFX / USDCAD
      if (isAvailable[I_CADLFX]) {
         prev.median [I_CADLFX] = curr.median[I_CADLFX];
         curr.median [I_CADLFX] = curr.median[I_USDLFX] / usdcad;
         curr.bid    [I_CADLFX] = MathPow((usdcad_Ask * usdchf_Bid * usdjpy_Bid) / (audusd_Ask * eurusd_Ask * gbpusd_Ask), 1/7.) / usdcad_Ask;
         curr.ask    [I_CADLFX] = MathPow((usdcad_Bid * usdchf_Ask * usdjpy_Ask) / (audusd_Bid * eurusd_Bid * gbpusd_Bid), 1/7.) / usdcad_Bid;
         isStale     [I_CADLFX] = isStale[I_USDLFX];
      }
      else isStale   [I_CADLFX] = true;
   }

   if (CHFLFX.Enabled) {                                             //     CHFLFX = (CHFJPY / (AUDCHF * CADCHF * EURCHF * GBPCHF * USDCHF)) ^ 1/7
      isAvailable[I_CHFLFX] = isAvailable[I_USDLFX];                 // or: CHFLFX = UDLFX / USDCHF
      if (isAvailable[I_CHFLFX]) {
         prev.median [I_CHFLFX] = curr.median[I_CHFLFX];
         curr.median [I_CHFLFX] = curr.median[I_USDLFX] / usdchf;
         curr.bid    [I_CHFLFX] = MathPow((usdcad_Bid * usdchf_Ask * usdjpy_Bid) / (audusd_Ask * eurusd_Ask * gbpusd_Ask), 1/7.) / usdchf_Ask;
         curr.ask    [I_CHFLFX] = MathPow((usdcad_Ask * usdchf_Bid * usdjpy_Ask) / (audusd_Bid * eurusd_Bid * gbpusd_Bid), 1/7.) / usdchf_Bid;
         isStale     [I_CHFLFX] = isStale[I_USDLFX];
      }
      else isStale   [I_CHFLFX] = true;
   }

   if (EURLFX.Enabled) {                                             //     EURLFX = (EURAUD * EURCAD * EURCHF * EURGBP * EURJPY * EURUSD) ^ 1/7
      isAvailable[I_EURLFX] = isAvailable[I_USDLFX];                 // or: EURLFX = USDLFX * EURUSD
      if (isAvailable[I_EURLFX]) {
         prev.median [I_EURLFX] = curr.median[I_EURLFX];
         curr.median [I_EURLFX] = curr.median[I_USDLFX] * eurusd;
         curr.bid    [I_EURLFX] = MathPow((usdcad_Bid * usdchf_Bid * usdjpy_Bid) / (audusd_Ask * eurusd_Bid * gbpusd_Ask), 1/7.) * eurusd_Bid;
         curr.ask    [I_EURLFX] = MathPow((usdcad_Ask * usdchf_Ask * usdjpy_Ask) / (audusd_Bid * eurusd_Ask * gbpusd_Bid), 1/7.) * eurusd_Ask;
         isStale     [I_EURLFX] = isStale[I_USDLFX];
      }
      else isStale   [I_EURLFX] = true;
   }

   if (GBPLFX.Enabled) {                                             //     GBPLFX = ((GBPAUD * GBPCAD * GBPCHF * GBPJPY * GBPUSD) / EURGBP) ^ 1/7
      isAvailable[I_GBPLFX] = isAvailable[I_USDLFX];                 // or: GBPLFX = USDLFX * GBPUSD
      if (isAvailable[I_GBPLFX]) {
         prev.median [I_GBPLFX] = curr.median[I_GBPLFX];
         curr.median [I_GBPLFX] = curr.median[I_USDLFX] * gbpusd;
         curr.bid    [I_GBPLFX] = MathPow((usdcad_Bid * usdchf_Bid * usdjpy_Bid) / (audusd_Ask * eurusd_Ask * gbpusd_Bid), 1/7.) * gbpusd_Bid;
         curr.ask    [I_GBPLFX] = MathPow((usdcad_Ask * usdchf_Ask * usdjpy_Ask) / (audusd_Bid * eurusd_Bid * gbpusd_Ask), 1/7.) * gbpusd_Ask;
         isStale     [I_GBPLFX] = isStale[I_USDLFX];
      }
      else isStale   [I_GBPLFX] = true;
   }

   if (JPYLFX.Enabled) {                                             //     JPYLFX = 100 * (1 / (AUDJPY * CADJPY * CHFJPY * EURJPY * GBPJPY * USDJPY)) ^ 1/7
      isAvailable[I_JPYLFX] = isAvailable[I_USDLFX];                 // or: JPYLFX = 100 * USDLFX / USDJPY
      if (isAvailable[I_JPYLFX]) {
         prev.median [I_JPYLFX] = curr.median[I_JPYLFX];
         curr.median [I_JPYLFX] = 100 * curr.median[I_USDLFX] / usdjpy;
         curr.bid    [I_JPYLFX] = 100 * MathPow((usdcad_Bid * usdchf_Bid * usdjpy_Ask) / (audusd_Ask * eurusd_Ask * gbpusd_Ask), 1/7.) / usdjpy_Ask;
         curr.ask    [I_JPYLFX] = 100 * MathPow((usdcad_Ask * usdchf_Ask * usdjpy_Bid) / (audusd_Bid * eurusd_Bid * gbpusd_Bid), 1/7.) / usdjpy_Bid;
         isStale     [I_JPYLFX] = isStale[I_USDLFX];
      }
      else isStale   [I_JPYLFX] = true;
   }

   if (NZDLFX.Enabled) {                                             //     NZDLFX = ((NZDCAD * NZDCHF * NZDJPY * NZDUSD) / (AUDNZD * EURNZD * GBPNZD)) ^ 1/7
      isAvailable[I_NZDLFX] = (isAvailable[I_USDLFX] && nzdusd_Bid); // or: NZDLFX = USDLFX * NZDUSD
      if (isAvailable[I_NZDLFX]) {
         prev.median [I_NZDLFX] = curr.median[I_NZDLFX];
         curr.median [I_NZDLFX] = curr.median[I_USDLFX] * nzdusd;
         curr.bid    [I_NZDLFX] = MathPow((usdcad_Bid * usdchf_Bid * usdjpy_Bid) / (audusd_Ask * eurusd_Ask * gbpusd_Ask), 1/7.) * nzdusd_Bid;
         curr.ask    [I_NZDLFX] = MathPow((usdcad_Ask * usdchf_Ask * usdjpy_Ask) / (audusd_Bid * eurusd_Bid * gbpusd_Bid), 1/7.) * nzdusd_Ask;
         isStale     [I_NZDLFX] = isStale[I_USDLFX] || nzdusd_stale;
      }
      else isStale   [I_NZDLFX] = true;
   }

   if (NOKFX7.Enabled) {                                             //     NOKFX7 = 10 * (NOKJPY / (AUDNOK * CADNOK * CHFNOK * EURNOK * GBPNOK * USDNOK)) ^ 1/7
      isAvailable[I_NOKFX7] = (isAvailable[I_USDLFX] && usdnok_Bid); // or: NOKFX7 = 10 * USDLFX / USDNOK
      if (isAvailable[I_NOKFX7]) {
         prev.median [I_NOKFX7] = curr.median[I_NOKFX7];
         curr.median [I_NOKFX7] = 10 * curr.median[I_USDLFX] / usdnok;
         curr.bid    [I_NOKFX7] = 10 * MathPow((usdcad_Bid * usdchf_Bid * usdjpy_Bid) / (audusd_Ask * eurusd_Ask * gbpusd_Ask), 1/7.) / usdnok_Ask;
         curr.ask    [I_NOKFX7] = 10 * MathPow((usdcad_Ask * usdchf_Ask * usdjpy_Ask) / (audusd_Bid * eurusd_Bid * gbpusd_Bid), 1/7.) / usdnok_Bid;
         isStale     [I_NOKFX7] = isStale[I_USDLFX] || usdnok_stale;
      }
      else isStale   [I_NOKFX7] = true;
   }

   if (SEKFX7.Enabled) {                                             //     SEKFX7 = 10 * (SEKJPY / (AUDSEK * CADSEK * CHFSEK * EURSEK * GBPSEK * USDSEK)) ^ 1/7
      isAvailable[I_SEKFX7] = (isAvailable[I_USDLFX] && usdsek_Bid); // or: SEKFX7 = 10 * USDLFX / USDSEK
      if (isAvailable[I_SEKFX7]) {
         prev.median [I_SEKFX7] = curr.median[I_SEKFX7];
         curr.median [I_SEKFX7] = 10 * curr.median[I_USDLFX] / usdsek;
         curr.bid    [I_SEKFX7] = 10 * MathPow((usdcad_Bid * usdchf_Bid * usdjpy_Bid) / (audusd_Ask * eurusd_Ask * gbpusd_Ask), 1/7.) / usdsek_Ask;
         curr.ask    [I_SEKFX7] = 10 * MathPow((usdcad_Ask * usdchf_Ask * usdjpy_Ask) / (audusd_Bid * eurusd_Bid * gbpusd_Bid), 1/7.) / usdsek_Bid;
         isStale     [I_SEKFX7] = isStale[I_USDLFX] || usdsek_stale;
      }
      else isStale   [I_SEKFX7] = true;
   }

   if (SGDFX7.Enabled) {                                             //     SGDFX7 = (SGDJPY / (AUDSGD * CADSGD * CHFSGD * EURSGD * GBPSGD * USDSGD)) ^ 1/7
      isAvailable[I_SGDFX7] = (isAvailable[I_USDLFX] && usdsgd_Bid); // or: SGDFX7 = USDLFX / USDSGD
      if (isAvailable[I_SGDFX7]) {
         prev.median [I_SGDFX7] = curr.median[I_SGDFX7];
         curr.median [I_SGDFX7] = curr.median[I_USDLFX] / usdsgd;
         curr.bid    [I_SGDFX7] = MathPow((usdcad_Bid * usdchf_Bid * usdjpy_Bid) / (audusd_Ask * eurusd_Ask * gbpusd_Ask), 1/7.) / usdsgd_Ask;
         curr.ask    [I_SGDFX7] = MathPow((usdcad_Ask * usdchf_Ask * usdjpy_Ask) / (audusd_Bid * eurusd_Bid * gbpusd_Bid), 1/7.) / usdsgd_Bid;
         isStale     [I_SGDFX7] = isStale[I_USDLFX] || usdsgd_stale;
      }
      else isStale   [I_SGDFX7] = true;
   }

   if (ZARFX7.Enabled) {                                             //     ZARFX7 = 10 * (ZARJPY / (AUDZAR * CADZAR * CHFZAR * EURZAR * GBPZAR * USDZAR)) ^ 1/7
      isAvailable[I_ZARFX7] = (isAvailable[I_USDLFX] && usdzar_Bid); // or: ZARFX7 = 10 * USDLFX / USDZAR
      if (isAvailable[I_ZARFX7]) {
         prev.median [I_ZARFX7] = curr.median[I_ZARFX7];
         curr.median [I_ZARFX7] = 10 * curr.median[I_USDLFX] / usdzar;
         curr.bid    [I_ZARFX7] = 10 * MathPow((usdcad_Bid * usdchf_Bid * usdjpy_Bid) / (audusd_Ask * eurusd_Ask * gbpusd_Ask), 1/7.) / usdzar_Ask;
         curr.ask    [I_ZARFX7] = 10 * MathPow((usdcad_Ask * usdchf_Ask * usdjpy_Ask) / (audusd_Bid * eurusd_Bid * gbpusd_Bid), 1/7.) / usdzar_Bid;
         isStale     [I_ZARFX7] = isStale[I_USDLFX] || usdzar_stale;
      }
      else isStale   [I_ZARFX7] = true;
   }

   if (EURX.Enabled) {                                               // EURX = 34.38805726 * EURUSD^0.3155 * EURGBP^0.3056 * EURJPY^0.1891 * EURCHF^0.1113 * EURSEK^0.0785
      isAvailable[I_EURX] = (usdchf_Bid && usdjpy_Bid && usdsek_Bid && eurusd_Bid && gbpusd_Bid);
      if (isAvailable[I_EURX]) {
         double eurchf = usdchf * eurusd;
         double eurgbp = eurusd / gbpusd;
         double eurjpy = usdjpy * eurusd;
         double eursek = usdsek * eurusd;
         prev.median [I_EURX] = curr.median[I_EURX];
         curr.median [I_EURX] = 34.38805726 * MathPow(eurusd, 0.3155) * MathPow(eurgbp, 0.3056) * MathPow(eurjpy, 0.1891) * MathPow(eurchf, 0.1113) * MathPow(eursek, 0.0785);
         curr.bid    [I_EURX] = 0;                  // TODO
         curr.ask    [I_EURX] = 0;                  // TODO
         isStale     [I_EURX] = usdchf_stale || usdjpy_stale || usdsek_stale || eurusd_stale || gbpusd_stale;
      }
      else isStale   [I_EURX] = true;
   }

   if (USDX.Enabled) {                                               // USDX = 50.14348112 * EURUSD^-0.576 * USDJPY^0.136 * GBPUSD^-0.119 * USDCAD^0.091 * USDSEK^0.042 * USDCHF^0.036
      isAvailable[I_USDX] = (usdcad_Bid && usdchf_Bid && usdjpy_Bid && usdsek_Bid && eurusd_Bid && gbpusd_Bid);
      if (isAvailable[I_USDX]) {
         prev.median [I_USDX] = curr.median[I_USDX];
         curr.median [I_USDX] = 50.14348112 * (MathPow(usdjpy    , 0.136) * MathPow(usdcad    , 0.091) * MathPow(usdsek    , 0.042) * MathPow(usdchf    , 0.036)) / (MathPow(eurusd    , 0.576) * MathPow(gbpusd    , 0.119));
         curr.bid    [I_USDX] = 50.14348112 * (MathPow(usdjpy_Bid, 0.136) * MathPow(usdcad_Bid, 0.091) * MathPow(usdsek_Bid, 0.042) * MathPow(usdchf_Bid, 0.036)) / (MathPow(eurusd_Ask, 0.576) * MathPow(gbpusd_Ask, 0.119));
         curr.ask    [I_USDX] = 50.14348112 * (MathPow(usdjpy_Ask, 0.136) * MathPow(usdcad_Ask, 0.091) * MathPow(usdsek_Ask, 0.042) * MathPow(usdchf_Ask, 0.036)) / (MathPow(eurusd_Bid, 0.576) * MathPow(gbpusd_Bid, 0.119));
         isStale     [I_USDX] = usdcad_stale || usdchf_stale || usdjpy_stale || usdsek_stale || eurusd_stale || gbpusd_stale;
      }
      else isStale   [I_USDX] = true;
   }

   if (XAUI.Enabled) {                                               //     XAUI = (XAUAUD * XAUCAD * XAUCHF * XAUEUR * XAUUSD * XAUGBP * XAUJPY) ^ 1/7
      isAvailable[I_XAUI] = (isAvailable[I_USDLFX] && xauusd_Bid);   // or: XAUI = USDLFX * XAUUSD
      if (isAvailable[I_XAUI]) {
         prev.median [I_XAUI] = curr.median[I_XAUI];
         curr.median [I_XAUI] = curr.median[I_USDLFX] * xauusd;
         curr.bid    [I_XAUI] = 0;                  // TODO
         curr.ask    [I_XAUI] = 0;                  // TODO
         isStale     [I_XAUI] = isStale[I_USDLFX] || xauusd_stale;
      }
      else isStale   [I_XAUI] = true;
   }

   int error = GetLastError(); if (!error) return(true);

   debug("CalculateIndices(1)", error);
   if (error == ERR_SYMBOL_NOT_AVAILABLE)  return(true);
   if (error == ERS_HISTORY_UPDATE      )  return(!SetLastError(error)); // = true

   return(!catch("CalculateIndices(2)", error));
}


/**
 * Check for symbol price changes and trigger limit processing of synthetic positions.
 *
 * @return bool - success status
 */
bool ProcessAllLimits() {
   // only check orders if the symbol's calculated price has changed

   if (!isStale[I_AUDLFX]) if (!EQ(curr.median[I_AUDLFX], prev.median[I_AUDLFX], digits[I_AUDLFX])) if (!ProcessLimits(AUDLFX.orders, curr.median[I_AUDLFX])) return(false);
   if (!isStale[I_CADLFX]) if (!EQ(curr.median[I_CADLFX], prev.median[I_CADLFX], digits[I_CADLFX])) if (!ProcessLimits(CADLFX.orders, curr.median[I_CADLFX])) return(false);
   if (!isStale[I_CHFLFX]) if (!EQ(curr.median[I_CHFLFX], prev.median[I_CHFLFX], digits[I_CHFLFX])) if (!ProcessLimits(CHFLFX.orders, curr.median[I_CHFLFX])) return(false);
   if (!isStale[I_EURLFX]) if (!EQ(curr.median[I_EURLFX], prev.median[I_EURLFX], digits[I_EURLFX])) if (!ProcessLimits(EURLFX.orders, curr.median[I_EURLFX])) return(false);
   if (!isStale[I_GBPLFX]) if (!EQ(curr.median[I_GBPLFX], prev.median[I_GBPLFX], digits[I_GBPLFX])) if (!ProcessLimits(GBPLFX.orders, curr.median[I_GBPLFX])) return(false);
   if (!isStale[I_JPYLFX]) if (!EQ(curr.median[I_JPYLFX], prev.median[I_JPYLFX], digits[I_JPYLFX])) if (!ProcessLimits(JPYLFX.orders, curr.median[I_JPYLFX])) return(false);
   if (!isStale[I_NZDLFX]) if (!EQ(curr.median[I_NZDLFX], prev.median[I_NZDLFX], digits[I_NZDLFX])) if (!ProcessLimits(NZDLFX.orders, curr.median[I_NZDLFX])) return(false);
   if (!isStale[I_USDLFX]) if (!EQ(curr.median[I_USDLFX], prev.median[I_USDLFX], digits[I_USDLFX])) if (!ProcessLimits(USDLFX.orders, curr.median[I_USDLFX])) return(false);

   if (!isStale[I_NOKFX7]) if (!EQ(curr.median[I_NOKFX7], prev.median[I_NOKFX7], digits[I_NOKFX7])) if (!ProcessLimits(NOKFX7.orders, curr.median[I_NOKFX7])) return(false);
   if (!isStale[I_SEKFX7]) if (!EQ(curr.median[I_SEKFX7], prev.median[I_SEKFX7], digits[I_SEKFX7])) if (!ProcessLimits(SEKFX7.orders, curr.median[I_SEKFX7])) return(false);
   if (!isStale[I_SGDFX7]) if (!EQ(curr.median[I_SGDFX7], prev.median[I_SGDFX7], digits[I_SGDFX7])) if (!ProcessLimits(SGDFX7.orders, curr.median[I_SGDFX7])) return(false);
   if (!isStale[I_ZARFX7]) if (!EQ(curr.median[I_ZARFX7], prev.median[I_ZARFX7], digits[I_ZARFX7])) if (!ProcessLimits(ZARFX7.orders, curr.median[I_ZARFX7])) return(false);

   if (!isStale[I_EURX  ]) if (!EQ(curr.median[I_EURX  ], prev.median[I_EURX  ], digits[I_EURX  ])) if (!ProcessLimits(EURX.orders,   curr.median[I_EURX  ])) return(false);
   if (!isStale[I_USDX  ]) if (!EQ(curr.median[I_USDX  ], prev.median[I_USDX  ], digits[I_USDX  ])) if (!ProcessLimits(USDX.orders,   curr.median[I_USDX  ])) return(false);

   if (!isStale[I_XAUI  ]) if (!EQ(curr.median[I_XAUI  ], prev.median[I_XAUI  ], digits[I_XAUI  ])) if (!ProcessLimits(XAUI.orders,   curr.median[I_XAUI  ])) return(false);

   return(true);
}


/**
 * Check active limits of the passed orders and send trade commands accordingly.
 *
 * @param  _In_Out_ LFX_ORDER orders[] - array of LFX_ORDERs
 * @param  _In_     double    price    - current price to check against
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
 * Update the chart display.
 *
 * @return bool - success status
 */
bool UpdateIndexDisplay() {
   //if (!IsChartVisible()) return(true);          // TODO: update only if the chart is visible

   // animation
   int   chars     = ArraySize(label.animation.chars);
   color fontColor = ifInt(Recording.Enabled, fontColor.recordingOn, fontColor.recordingOff);
   ObjectSetText(label.animation, label.animation.chars[Tick % chars], fontSize, fontName, fontColor);

   // calculated values
   int    size = ArraySize(symbols);
   string sIndex, sSpread;

   for (int i=0; i < size; i++) {
      if (isEnabled[i]) {
         fontColor = fontColor.recordingOff;
         if (isAvailable[i]) {
            sIndex  = NumberToStr(NormalizeDouble(curr.median[i], digits[i]), priceFormats[i]);
            sSpread = "("+ DoubleToStr((curr.ask[i]-curr.bid[i])/pipSizes[i], 1) +")";
            if (isRecording[i]) /*&&*/ if (!isStale[i])
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
   return(!catch("UpdateIndexDisplay(1)"));
}


/**
 * Record LFX index data.
 *
 * @return bool - success status
 */
bool RecordIndices() {
   datetime now.fxt = GetFxtTime();
   int size = ArraySize(symbols);

   for (int i=0; i < size; i++) {
      if (isRecording[i] && !isStale[i]) {
         double value     = NormalizeDouble(curr.median[i], digits[i]);
         double lastValue = prev.median[i];

         // Virtual ticks (about 120 each minute) are recorded only if the current price changed. Real ticks are always recorded.
         if (Tick.isVirtual) {
            if (EQ(value, lastValue, digits[i])) {       // The first tick (lastValue==NULL) can't be tested and is always recorded.
               //debug("RecordIndices(1)  Tick="+ Tick +"  skipping virtual "+ symbols[i] +" tick "+ NumberToStr(value, priceFormats[i]) +" (tick == lastTick)");
               continue;
            }
         }

         if (!hSet[i]) {
            hSet[i] = HistorySet.Get(symbols[i], serverName);
            if (hSet[i] == -1)
               hSet[i] = HistorySet.Create(symbols[i], longNames[i], digits[i], 400, serverName);     // format: 400
            if (!hSet[i]) return(false);
         }

         //debug("RecordIndices(2)  Tick="+ Tick +"  recording "+ symbols[i] +" tick="+ NumberToStr(value, priceFormats[i]));
         if (!HistorySet.AddTick(hSet[i], now.fxt, value, NULL)) return(false);
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
      ObjectSetText(label.tradeAccount, text, 8, "Arial Fett", ifInt(tradeAccount.type==ACCOUNT_TYPE_DEMO, LimeGreen, DarkOrange));
   }
   else {
      ObjectSetText(label.tradeAccount, " ", 1);
   }

   int error = GetLastError();
   if (!error || error==ERR_OBJECT_DOES_NOT_EXIST)                   // on Object::onDrag() or opened "Properties" dialog
      return(true);
   return(!catch("UpdateAccountDisplay(1)", error));
}


/**
 * Speichert die Laufzeitkonfiguration im Fenster (für init-Cycle und neue Templates) und im Chart (für Terminal-Restart).
 *
 *  (1) string tradeAccount.company, int tradeAccount.number
 *
 * @return bool - Erfolgsstatus
 */
bool StoreRuntimeStatus() {
   // (1) string tradeAccount.company, int tradeAccount.number
   // Company-ID im Fenster speichern
   int    hWnd = __ExecutionContext[EC.hChart];
   string key  = __NAME() +".runtime.tradeAccount.company";          // TODO: Schlüssel global verwalten und Instanz-ID des Indikators integrieren
   SetWindowIntegerA(hWnd, key, GetAccountCompanyId(tradeAccount.company));

   // Company-ID im Chart speichern
   if (ObjectFind(key) == 0)
      ObjectDelete(key);
   ObjectCreate (key, OBJ_LABEL, 0, 0, 0);
   ObjectSet    (key, OBJPROP_TIMEFRAMES, OBJ_PERIODS_NONE);
   ObjectSetText(key, ""+ GetAccountCompanyId(tradeAccount.company));

   // AccountNumber im Fenster speichern
   key = __NAME() +".runtime.tradeAccount.number";                   // TODO: Schlüssel global verwalten und Instanz-ID des Indikators integrieren
   SetWindowIntegerA(hWnd, key, tradeAccount.number);

   // AccountNumber im Chart speichern
   if (ObjectFind(key) == 0)
      ObjectDelete(key);
   ObjectCreate (key, OBJ_LABEL, 0, 0, 0);
   ObjectSet    (key, OBJPROP_TIMEFRAMES, OBJ_PERIODS_NONE);
   ObjectSetText(key, ""+ tradeAccount.number);

   return(!catch("StoreRuntimeStatus(1)"));
}


/**
 * Restauriert eine im Fenster oder im Chart gespeicherte Laufzeitkonfiguration.
 *
 *  (1) string tradeAccount.company, int tradeAccount.number
 *
 * @return bool - Erfolgsstatus
 */
bool RestoreRuntimeStatus() {
   // (1) string tradeAccount.company, int tradeAccount.number
   int companyId, accountNumber;
   // Company-ID im Fenster suchen
   int    hWnd    = __ExecutionContext[EC.hChart];
   string key     = __NAME() +".runtime.tradeAccount.company";          // TODO: Schlüssel global verwalten und Instanz-ID des Indikators integrieren
   int    value   = GetWindowIntegerA(hWnd, key);
   bool   success = (value != 0);
   // bei Mißerfolg Company-ID im Chart suchen
   if (!success) {
      if (ObjectFind(key) == 0) {
         value   = StrToInteger(ObjectDescription(key));
         success = (value != 0);
      }
   }
   if (success) companyId = value;

   // AccountNumber im Fenster suchen
   key     = __NAME() +".runtime.tradeAccount.number";                  // TODO: Schlüssel global verwalten und Instanz-ID des Indikators integrieren
   value   = GetWindowIntegerA(hWnd, key);
   success = (value != 0);
   // bei Mißerfolg AccountNumber im Chart suchen
   if (!success) {
      if (ObjectFind(key) == 0) {
         value   = StrToInteger(ObjectDescription(key));
         success = (value != 0);
      }
   }
   if (success) accountNumber = value;

   // Account restaurieren
   if (companyId && accountNumber) {
      string company = tradeAccount.company;
      int    number  = tradeAccount.number;

      if (!InitTradeAccount(companyId +":"+ accountNumber)) return(false);
      if (tradeAccount.company!=company || tradeAccount.number!=number) {
         if (!UpdateAccountDisplay())                       return(false);
         if (!RefreshLfxOrders())                           return(false);
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
   return(StringConcatenate("Recording.Enabled=", BoolToStr(Recording.Enabled), ";", NL,

                            "AUDLFX.Enabled=",    BoolToStr(AUDLFX.Enabled),    ";", NL,
                            "CADLFX.Enabled=",    BoolToStr(CADLFX.Enabled),    ";", NL,
                            "CHFLFX.Enabled=",    BoolToStr(CHFLFX.Enabled),    ";", NL,
                            "EURLFX.Enabled=",    BoolToStr(EURLFX.Enabled),    ";", NL,
                            "GBPLFX.Enabled=",    BoolToStr(GBPLFX.Enabled),    ";", NL,
                            "JPYLFX.Enabled=",    BoolToStr(JPYLFX.Enabled),    ";", NL,
                            "NZDLFX.Enabled=",    BoolToStr(NZDLFX.Enabled),    ";", NL,
                            "USDLFX.Enabled=",    BoolToStr(USDLFX.Enabled),    ";", NL,

                            "NOKFX7.Enabled=",    BoolToStr(NOKFX7.Enabled),    ";", NL,
                            "SEKFX7.Enabled=",    BoolToStr(SEKFX7.Enabled),    ";", NL,
                            "SGDFX7.Enabled=",    BoolToStr(SGDFX7.Enabled),    ";", NL,
                            "ZARFX7.Enabled=",    BoolToStr(ZARFX7.Enabled),    ";", NL,

                            "EURX.Enabled=",      BoolToStr(EURX.Enabled),      ";", NL,
                            "USDX.Enabled=",      BoolToStr(USDX.Enabled),      ";", NL,

                            "XAUI.Enabled=",      BoolToStr(XAUI.Enabled),      ";")
   );
}
