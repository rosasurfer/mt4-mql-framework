
#define __lpSuperContext NULL
int     __CoreFunction = NULL;                                       // currently executed MQL core function: CF_INIT | CF_START | CF_DEINIT
double  __rates[][6];                                                // current price series


/**
 * Globale init()-Funktion für Scripte.
 *
 * @return int - error status
 */
int init() {
   if (__STATUS_OFF)
      return(__STATUS_OFF.reason);

   if (__CoreFunction == NULL)                                       // init() called by the terminal, all variables are reset
      __CoreFunction = CF_INIT;

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

   int error = SyncMainContext_init(__ExecutionContext, MT_SCRIPT, WindowExpertName(), UninitializeReason(), SumInts(__InitFlags), SumInts(__DeinitFlags), Symbol(), Period(), Digits, Point, false, false, IsTesting(), IsVisualMode(), IsOptimization(), __lpSuperContext, WindowHandle(Symbol(), NULL), WindowOnDropped(), WindowXOnDropped(), WindowYOnDropped());
   if (!error) error = GetLastError();                               // detect a DLL exception
   if (IsError(error)) {
      ForceAlert("ERROR:   "+ Symbol() +","+ PeriodDescription() +"  "+ WindowExpertName() +"::init(1)->SyncMainContext_init()  ["+ ErrorToStr(error) +"]");
      last_error          = error;
      __STATUS_OFF        = true;                                    // If SyncMainContext_init() failed the content of the EXECUTION_CONTEXT
      __STATUS_OFF.reason = last_error;                              // is undefined. We must not trigger loading of MQL libraries and return asap.
      return(last_error);
   }


   // (1) finish initialization
   if (!InitGlobals()) if (CheckErrors("init(2)")) return(last_error);


   // (2) user-spezifische Init-Tasks ausführen
   int initFlags = __ExecutionContext[EC.programInitFlags];

   if (initFlags & INIT_TIMEZONE && 1) {
      if (!StringLen(GetServerTimezone())) return(_last_error(CheckErrors("init(3)")));
   }
   if (initFlags & INIT_PIPVALUE && 1) {
      double tickSize = MarketInfo(Symbol(), MODE_TICKSIZE);         // schlägt fehl, wenn kein Tick vorhanden ist
      if (IsError(catch("init(4)"))) if (CheckErrors("init(5)")) return(last_error);
      if (!tickSize)                                             return(_last_error(CheckErrors("init(6)  MarketInfo(MODE_TICKSIZE): 0", ERR_INVALID_MARKET_DATA)));

      double tickValue = MarketInfo(Symbol(), MODE_TICKVALUE);
      if (IsError(catch("init(7)"))) if (CheckErrors("init(8)")) return(last_error);
      if (!tickValue)                                            return(_last_error(CheckErrors("init(9)  MarketInfo(MODE_TICKVALUE): 0", ERR_INVALID_MARKET_DATA)));
   }
   if (initFlags & INIT_BARS_ON_HIST_UPDATE && 1) {}                 // not yet implemented


   // (3) Pre/Postprocessing-Hook
   error = onInit();                                                 // Preprocessing-Hook
   if (error != -1) {
      afterInit();                                                   // Postprocessing-Hook nur ausführen, wenn Preprocessing-Hook
   }                                                                 // nicht mit -1 zurückkehrt.

   CheckErrors("init(10)");
   return(last_error);
}


/**
 * Update global variables. Called immediately after SyncMainContext_init().
 *
 * @return bool - success status
 */
bool InitGlobals() {
   __isChart      = (__ExecutionContext[EC.hChart] != 0);
   PipDigits      = Digits & (~1);                                        SubPipDigits      = PipDigits+1;
   PipPoints      = MathRound(MathPow(10, Digits & 1));                   PipPoint          = PipPoints;
   Pips           = NormalizeDouble(1/MathPow(10, PipDigits), PipDigits); Pip               = Pips;
   PipPriceFormat = StringConcatenate(",'R.", PipDigits);                 SubPipPriceFormat = StringConcatenate(PipPriceFormat, "'");
   PriceFormat    = ifString(Digits==PipDigits, PipPriceFormat, SubPipPriceFormat);

   N_INF = MathLog(0);                                               // negative infinity
   P_INF = -N_INF;                                                   // positive infinity
   NaN   =  N_INF - N_INF;                                           // not-a-number

   return(!catch("InitGlobals(1)"));
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
   __CoreFunction = CF_START;

   Tick++;                                                                    // einfache Zähler, die konkreten Werte haben keine Bedeutung
   Tick.Time      = MarketInfo(Symbol(), MODE_TIME);                          // TODO: !!! MODE_TIME ist im synthetischen Chart NULL               !!!
   Tick.isVirtual = true;                                                     // TODO: !!! MODE_TIME und TimeCurrent() sind im Tester-Chart falsch !!!
   ChangedBars    = -1;                                                       // in scripts not available
   UnchangedBars  = -1; ValidBars = UnchangedBars;                            // ...
   ShiftedBars    = -1;                                                       // ...

   ArrayCopyRates(__rates);

   if (SyncMainContext_start(__ExecutionContext, __rates, Bars, ChangedBars, Tick, Tick.Time, Bid, Ask) != NO_ERROR) {
      if (CheckErrors("start(2)")) return(last_error);
   }

   if (!Tick.Time) {
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
   onStart();

   // check errors
   error = GetLastError();
   if (error || last_error|__ExecutionContext[EC.mqlError]|__ExecutionContext[EC.dllError])
      CheckErrors("start(5)", error);
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

   int error = SyncMainContext_deinit(__ExecutionContext, UninitializeReason());
   if (IsError(error)) return(error|last_error|LeaveContext(__ExecutionContext));

   error = catch("deinit(1)");                        // detect errors causing a full execution stop, e.g. ERR_ZERO_DIVIDE

   if (!error) error = onDeinit();                    // preprocessing hook
   if (!error) error = afterDeinit();                 // postprocessing hook
   if (!This.IsTesting()) DeleteRegisteredObjects();

   CheckErrors("deinit(2)");
   return(error|last_error|LeaveContext(__ExecutionContext));
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
 * Handler für im Script auftretende Fehler. Zur Zeit wird der Fehler nur angezeigt.
 *
 * @param  string location - Ort, an dem der Fehler auftrat
 * @param  string message  - Fehlermeldung
 * @param  int    error    - zu setzender Fehlercode
 *
 * @return int - derselbe Fehlercode
 */
int HandleScriptError(string location, string message, int error) {
   if (StringLen(location) > 0)
      location = " :: "+ location;

   PlaySoundEx("Windows Chord.wav");
   MessageBox(message, "Script "+ ProgramName() + location, MB_ICONERROR|MB_OK);

   return(SetLastError(error));
}


/**
 * Check and update the program's error status and activate the flag __STATUS_OFF accordingly.
 *
 * @param  string location         - location of the check
 * @param  int    error [optional] - error to enforce (default: none)
 *
 * @return bool - whether the flag __STATUS_OFF is set
 */
bool CheckErrors(string location, int error = NULL) {
   // check and signal DLL errors
   int dll_error = __ExecutionContext[EC.dllError];                  // TODO: signal DLL errors
   if (dll_error != NO_ERROR) {
      __STATUS_OFF        = true;                                    // all DLL errors are terminating errors
      __STATUS_OFF.reason = dll_error;
   }

   // check MQL errors
   int mql_error = __ExecutionContext[EC.mqlError];
   switch (mql_error) {
      case NO_ERROR:
      case ERS_HISTORY_UPDATE:
    //case ERS_TERMINAL_NOT_YET_READY:                               // in scripts a terminating error
      case ERS_EXECUTION_STOPPING:
         break;
      default:
         __STATUS_OFF        = true;
         __STATUS_OFF.reason = mql_error;                            // MQL errors have higher severity than DLL errors
   }

   // check last_error
   switch (last_error) {
      case NO_ERROR:
      case ERS_HISTORY_UPDATE:
    //case ERS_TERMINAL_NOT_YET_READY:                               // in scripts a terminating error
      case ERS_EXECUTION_STOPPING:
         break;
      default:
         __STATUS_OFF        = true;
         __STATUS_OFF.reason = last_error;                           // local errors have higher severity than library errors
   }

   // check uncatched errors
   if (!error) error = GetLastError();
   if (error != NO_ERROR) {
      catch(location, error);
      __STATUS_OFF        = true;
      __STATUS_OFF.reason = error;                                   // all uncatched errors are terminating errors
   }

   // update variable last_error
   if (__STATUS_OFF) /*&&*/ if (!last_error)
      last_error = __STATUS_OFF.reason;
   return(__STATUS_OFF);

   // suppress compiler warnings
   __DummyCalls();
   HandleScriptError(NULL, NULL, NULL);
}


#import "rsfMT4Expander.dll"
   int SyncMainContext_init  (int ec[], int programType, string programName, int uninitReason, int initFlags, int deinitFlags, string symbol, int timeframe, int digits, double point, int extReporting, int recordEquity, int isTesting, int isVisualMode, int isOptimization, int lpSec, int hChart, int droppedOnChart, int droppedOnPosX, int droppedOnPosY);
   int SyncMainContext_start (int ec[], double rates[][], int bars, int changedBars, int ticks, datetime time, double bid, double ask);
   int SyncMainContext_deinit(int ec[], int uninitReason);

#import "user32.dll"
   int GetParent(int hWnd);
#import
