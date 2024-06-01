
#define __lpSuperContext NULL
int     __CoreFunction = NULL;                                       // currently executed MQL core function: CF_INIT|CF_START|CF_DEINIT
double  __rates[][6];                                                // current price series
double  _Bid;                                                        // normalized versions of predefined vars Bid/Ask
double  _Ask;                                                        // ...


/**
 * Globale init()-Funktion für Scripte.
 *
 * @return int - error status
 */
int init() {
   __isSuperContext = false;
   if (__STATUS_OFF) return(__STATUS_OFF.reason);
   if (__CoreFunction != CF_START) __CoreFunction = CF_INIT;         // init() called by the terminal, all variables are reset

   if (!IsDllsAllowed()) {
      ForceAlert("Please enable DLL function calls for this script.");
      last_error          = ERR_DLL_CALLS_NOT_ALLOWED;
      __STATUS_OFF        = true;
      __STATUS_OFF.reason = last_error;
      return(last_error);
   }
   if (!IsLibrariesAllowed()) {
      ForceAlert("Please enable MQL library calls for this script.");
      last_error          = ERR_EX4_CALLS_NOT_ALLOWED;
      __STATUS_OFF        = true;
      __STATUS_OFF.reason = last_error;
      return(last_error);
   }

   // initialize the execution context
   int error = SyncMainContext_init(__ExecutionContext, MT_SCRIPT, WindowExpertName(), UninitializeReason(), SumInts(__InitFlags), SumInts(__DeinitFlags), Symbol(), Period(), Digits, Point, IsTesting(), IsVisualMode(), IsOptimization(), NULL, __lpSuperContext, WindowHandle(Symbol(), NULL), WindowOnDropped(), WindowXOnDropped(), WindowYOnDropped(), AccountServer(), AccountNumber());
   if (!error) error = GetLastError();                               // detect a DLL exception
   if (IsError(error)) {
      ForceAlert("ERROR:   "+ Symbol() +","+ PeriodDescription() +"  "+ WindowExpertName() +"::init(1)->SyncMainContext_init()  ["+ ErrorToStr(error) +"]");
      last_error          = error;
      __STATUS_OFF        = true;                                    // If SyncMainContext_init() failed the content of the EXECUTION_CONTEXT
      __STATUS_OFF.reason = last_error;                              // is undefined. We must not trigger loading of MQL libraries and return asap.
      return(last_error);
   }

   // immediately resolve a missing account server/number so the Expander can find the account configuration
   if (!__ExecutionContext[EC.accountServer]) GetAccountServer();
   if (!__ExecutionContext[EC.accountNumber]) GetAccountNumber();

   // finish initialization
   if (!initGlobals()) if (CheckErrors("init(2)")) return(last_error);

   // user-spezifische Init-Tasks ausführen
   int initFlags = __ExecutionContext[EC.programInitFlags];

   if (initFlags & INIT_TIMEZONE && 1) {
      if (!StringLen(GetServerTimezone())) return(_last_error(CheckErrors("init(3)")));
   }
   if (initFlags & INIT_PIPVALUE && 1) {
      double tickSize = MarketInfo(Symbol(), MODE_TICKSIZE);         // schlägt fehl, wenn kein Tick vorhanden ist
      if (IsError(catch("init(4)"))) if (CheckErrors("init(5)")) return(last_error);
      if (!tickSize)                                             return(_last_error(CheckErrors("init(6)  MarketInfo(MODE_TICKSIZE=0)", ERR_SYMBOL_NOT_AVAILABLE)));

      double tickValue = MarketInfo(Symbol(), MODE_TICKVALUE);
      if (IsError(catch("init(7)"))) if (CheckErrors("init(8)")) return(last_error);
      if (!tickValue)                                            return(_last_error(CheckErrors("init(9)  MarketInfo(MODE_TICKVALUE=0)", ERR_SYMBOL_NOT_AVAILABLE)));
   }
   if (initFlags & INIT_BARS_ON_HIST_UPDATE && 1) {}                 // not yet implemented

   // Pre/Postprocessing-Hook
   error = onInit();                                                 // Preprocessing-Hook
   if (error != -1) {
      afterInit();                                                   // Postprocessing-Hook nur ausführen, wenn Preprocessing-Hook
   }                                                                 // nicht mit -1 zurückkehrt.

   CheckErrors("init(10)");
   return(last_error);
}


/**
 * Initialize/update global variables. Called immediately after SyncMainContext_init().
 *
 * @return bool - success status
 */
bool initGlobals() {
   __isChart   = (__ExecutionContext[EC.chart  ] != 0);
   __isTesting = (__ExecutionContext[EC.testing] != 0);

   int digits  = MathMax(Digits, 2);                        // treat Digits=1 as 2 (for some indices)
   HalfPoint   = Point/2;
   PipDigits   = digits & (~1);
   Pip         = NormalizeDouble(1/MathPow(10, PipDigits), PipDigits);
   PriceFormat = ",'R."+ PipDigits + ifString(digits==PipDigits, "", "'");

   if (digits > 2 || Close[0] < 20) {
      pUnit   = Pip;
      pDigits = 1;                                          // always represent pips with subpips
      spUnit  = "pip";
   }
   else {
      pUnit   = 1.00;
      pDigits = 2;
      spUnit  = "point";
   }
   _Bid = NormalizeDouble(Bid, Digits);                     // normalized versions of Bid/Ask
   _Ask = NormalizeDouble(Ask, Digits);                     //

   // don't use MathLog() to produce special double values as in terminals (509 < build && build < 603) it fails
   INF = Math_INF();                                        // positive infinity
   NaN = INF-INF;                                           // not-a-number

   return(!catch("initGlobals(1)"));
}


/**
 * Globale start()-Funktion für Scripte.
 *
 * @return int - error status
 */
int start() {
   if (__STATUS_OFF) {                                                        // init()-Fehler abfangen
      if (IsDllsAllowed() && IsLibrariesAllowed()) {
         string msg = WindowExpertName() +": switched off ("+ ifString(!__STATUS_OFF.reason, "unknown reason", ErrorToStr(__STATUS_OFF.reason)) +")";
         Comment(NL, NL, NL, msg);                                            // 3 Zeilen Abstand für Instrumentanzeige und ggf. vorhandene Legende
         debug("start(1)  "+ msg);
      }
      return(__STATUS_OFF.reason);
   }
   __CoreFunction = ec_SetProgramCoreFunction(__ExecutionContext, CF_START);

   Ticks++;                                                                   // einfache Zähler, die konkreten Werte haben keine Bedeutung
   Tick.time      = MarketInfo(Symbol(), MODE_TIME);                          // TODO: !!! MODE_TIME ist im Tester- und Offline-Chart falsch !!!
   Tick.isVirtual = true;                                                     //
   ChangedBars    = -1;                                                       // in scripts not available
   ValidBars      = -1;                                                       // ...
   ShiftedBars    = -1;                                                       // ...

   // synchronize EXECUTION_CONTEXT
   ArrayCopyRates(__rates);
   _Bid = NormalizeDouble(Bid, Digits);                                       // normalized versions of Bid/Ask
   _Ask = NormalizeDouble(Ask, Digits);                                       //
   if (SyncMainContext_start(__ExecutionContext, __rates, Bars, ChangedBars, Ticks, Tick.time, _Bid, _Ask) != NO_ERROR) {
      if (CheckErrors("start(2)->SyncMainContext_start()")) return(last_error);
   }

   if (!Tick.time) {
      int error = GetLastError();
      if (error && error!=ERR_SYMBOL_NOT_AVAILABLE)                           // ERR_SYMBOL_NOT_AVAILABLE vorerst ignorieren, da ein Offline-Chart beim ersten Tick
         if (CheckErrors("start(3)", error)) return(last_error);              // nicht sicher detektiert werden kann
   }

   // Abschluß der Chart-Initialisierung überprüfen
   if (!(__ExecutionContext[EC.programInitFlags] & INIT_NO_BARS_REQUIRED)) {  // Bars kann 0 sein, wenn das Script auf einem leeren Chart startet (Waiting for update...)
      if (!Bars) {                                                            // oder der Chart beim Terminal-Start noch nicht vollständig initialisiert ist
         return(_last_error(CheckErrors("start(4)  Bars = 0", ERS_TERMINAL_NOT_YET_READY)));
      }
   }

   // call the userland main function
   error = onStart();
   if (error && error!=last_error) CheckErrors("start(5)", error);

   // check all errors
   error = GetLastError();
   if (error || last_error|__ExecutionContext[EC.mqlError]|__ExecutionContext[EC.dllError])
      CheckErrors("start(6)", error);
   return(last_error);
}


/**
 * Globale deinit()-Funktion für Scripte.
 *
 * @return int - error status
 */
int deinit() {
   __CoreFunction = CF_DEINIT;

   if (!IsDllsAllowed() || !IsLibrariesAllowed() || last_error==ERR_TERMINAL_INIT_FAILURE || last_error==ERR_DLL_EXCEPTION)
      return(last_error);

   if (SyncMainContext_deinit(__ExecutionContext, UninitializeReason()) != NO_ERROR) {
      return(CheckErrors("deinit(1)->SyncMainContext_deinit()") + LeaveContext(__ExecutionContext));
   }

   int error = catch("deinit(2)");                    // detect errors causing a full execution stop, e.g. ERR_ZERO_DIVIDE

   if (!error) error = onDeinit();                    // preprocessing hook
   if (!error) error = afterDeinit();                 // postprocessing hook
   if (!__isTesting) DeleteRegisteredObjects();

   return(CheckErrors("deinit(3)") + LeaveContext(__ExecutionContext));
}


/**
 * Gibt die ID des aktuellen Deinit()-Szenarios zurück. Kann nur in deinit() aufgerufen werden.
 *
 * @return int - ID oder NULL, falls ein Fehler auftrat
 */
int DeinitReason() {
   return(!catch("DeinitReason(1)", ERR_NOT_IMPLEMENTED));
}


/**
 * Whether the current program is an expert.
 *
 * @return bool
 */
bool IsExpert() {
   return(false);
}


/**
 * Whether the current program is a script.
 *
 * @return bool
 */
bool IsScript() {
   return(true);
}


/**
 * Whether the current program is an indicator.
 *
 * @return bool
 */
bool IsIndicator() {
   return(false);
}


/**
 * Whether the current module is a library.
 *
 * @return bool
 */
bool IsLibrary() {
   return(false);
}


/**
 * Check and update the program's error status and activate the flag __STATUS_OFF accordingly.
 *
 * @param  string caller           - location identifier of the caller
 * @param  int    error [optional] - enforced error (default: none)
 *
 * @return bool - whether the flag __STATUS_OFF is set
 */
bool CheckErrors(string caller, int error = NULL) {
   // check DLL errors
   int dll_error = __ExecutionContext[EC.dllError];
   if (dll_error != NO_ERROR) {                             // all DLL errors are terminating errors
      if (dll_error != __STATUS_OFF.reason)                 // prevent recursion errors
         logFatal(caller +"  DLL error", dll_error);        // signal the error but don't overwrite MQL last_error
      __STATUS_OFF        = true;
      __STATUS_OFF.reason = dll_error;
   }

   // check the program's MQL error
   int mql_error = __ExecutionContext[EC.mqlError];         // may have bubbled up from an MQL library
   switch (mql_error) {
      case NO_ERROR:
      case ERS_HISTORY_UPDATE:
      case ERS_EXECUTION_STOPPING:
         break;
      default:
         __STATUS_OFF        = true;
         __STATUS_OFF.reason = mql_error;                   // MQL errors have higher severity than DLL errors
   }

   // check the module's MQL error (if set it should match EC.mqlError)
   switch (last_error) {
      case NO_ERROR:
      case ERS_HISTORY_UPDATE:
      case ERS_EXECUTION_STOPPING:
         break;
      default:
         __STATUS_OFF        = true;
         __STATUS_OFF.reason = last_error;                  // main module errors have higher severity than library errors
   }

   // check enforced or uncatched errors
   if (!error) error = GetLastError();
   switch (error) {
      case NO_ERROR:
         break;
      case ERS_HISTORY_UPDATE:
      case ERS_EXECUTION_STOPPING:
         logInfo(caller, error);                            // don't SetLastError()
         break;
      default:
         if (error != __STATUS_OFF.reason)                  // prevent recursion errors
            catch(caller, error);                           // catch() calls SetLastError()
         __STATUS_OFF        = true;
         __STATUS_OFF.reason = error;
   }

   // update variable last_error
   if (__STATUS_OFF && !last_error)
      last_error = __STATUS_OFF.reason;
   return(__STATUS_OFF);

   // suppress compiler warnings
   __DummyCalls();
}


#import "rsfMT4Expander.dll"
   int ec_SetProgramCoreFunction(int ec[], int function);

   int SyncMainContext_init  (int ec[], int programType, string programName, int uninitReason, int initFlags, int deinitFlags, string symbol, int timeframe, int digits, double point, int isTesting, int isVisualMode, int isOptimization, int recorder, int lpSec, int hChart, int droppedOnChart, int droppedOnPosX, int droppedOnPosY, string accountServer, int accountNumber);
   int SyncMainContext_start (int ec[], double rates[][], int bars, int changedBars, int ticks, datetime time, double bid, double ask);
   int SyncMainContext_deinit(int ec[], int uninitReason);

#import "user32.dll"
   int GetParent(int hWnd);
#import

