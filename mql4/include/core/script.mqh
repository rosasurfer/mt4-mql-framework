
#define __lpSuperContext NULL
int     __WHEREAMI__   = NULL;                                       // current MQL core function: CF_INIT | CF_START | CF_DEINIT

// current price series
double rates[][6];


/**
 * Globale init()-Funktion für Scripte.
 *
 * @return int - Fehlerstatus
 */
int init() {
   if (__STATUS_OFF)
      return(__STATUS_OFF.reason);

   if (__WHEREAMI__ == NULL)                                         // init() called by the terminal, all variables are reset
      __WHEREAMI__ = CF_INIT;

   if (!IsDllsAllowed()) {
      ForceAlert("DLL function calls are not enabled. Please go to Tools -> Options -> Expert Advisors and allow DLL imports.");
      last_error          = ERR_DLL_CALLS_NOT_ALLOWED;
      __STATUS_OFF        = true;
      __STATUS_OFF.reason = last_error;
      return(last_error);
   }
   if (!IsLibrariesAllowed()) {
      ForceAlert("MQL library calls are not enabled. Please load the script with \"Allow imports of external experts\" enabled.");
      last_error          = ERR_EX4_CALLS_NOT_ALLOWED;
      __STATUS_OFF        = true;
      __STATUS_OFF.reason = last_error;
      return(last_error);
   }

   int error = SyncMainContext_init(__ExecutionContext, MT_SCRIPT, WindowExpertName(), UninitializeReason(), SumInts(__INIT_FLAGS__), SumInts(__DEINIT_FLAGS__), Symbol(), Period(), Digits, Point, false, false, IsTesting(), IsVisualMode(), IsOptimization(), __lpSuperContext, WindowHandle(Symbol(), NULL), WindowOnDropped(), WindowXOnDropped(), WindowYOnDropped());
   if (!error) error = GetLastError();                               // detect a DLL exception
   if (IsError(error)) {
      ForceAlert("ERROR:   "+ Symbol() +","+ PeriodDescription(Period()) +"  "+ WindowExpertName() +"::init(1)->SyncMainContext_init()  ["+ ErrorToStr(error) +"]");
      last_error          = error;
      __STATUS_OFF        = true;                                    // If SyncMainContext_init() failed the content of the EXECUTION_CONTEXT
      __STATUS_OFF.reason = last_error;                              // is undefined. We must not trigger loading of MQL libraries and return asap.
      return(last_error);
   }


   // (1) finish initialization
   if (!init.GlobalVars()) if (CheckErrors("init(2)")) return(last_error);


   // (2) user-spezifische Init-Tasks ausführen
   int initFlags = __ExecutionContext[EC.programInitFlags];

   if (initFlags & INIT_TIMEZONE && 1) {
      if (!StringLen(GetServerTimezone())) return(_last_error(CheckErrors("init(3)")));
   }
   if (initFlags & INIT_PIPVALUE && 1) {
      TickSize = MarketInfo(Symbol(), MODE_TICKSIZE);                // schlägt fehl, wenn kein Tick vorhanden ist
      if (IsError(catch("init(4)"))) if (CheckErrors("init(5)")) return( last_error);
      if (!TickSize)                                             return(_last_error(CheckErrors("init(6)  MarketInfo(MODE_TICKSIZE) = 0", ERR_INVALID_MARKET_DATA)));

      double tickValue = MarketInfo(Symbol(), MODE_TICKVALUE);
      if (IsError(catch("init(7)"))) if (CheckErrors("init(8)")) return( last_error);
      if (!tickValue)                                            return(_last_error(CheckErrors("init(9)  MarketInfo(MODE_TICKVALUE) = 0", ERR_INVALID_MARKET_DATA)));
   }
   if (initFlags & INIT_BARS_ON_HIST_UPDATE && 1) {}                 // not yet implemented
   if (initFlags & INIT_CUSTOMLOG           && 1) {}                 // not yet implemented


   // (3) Pre/Postprocessing-Hook
   error = onInit();                                                 // Preprocessing-Hook
   if (error != -1) {
      afterInit();                                                   // Postprocessing-Hook nur ausführen, wenn Preprocessing-Hook
   }                                                                 // nicht mit -1 zurückkehrt.

   CheckErrors("init(10)");
   return(last_error);
}


/**
 * Update global variables and the script's EXECUTION_CONTEXT.
 *
 * @return bool - success status
 */
bool init.GlobalVars() {
   ec_SetLogEnabled(__ExecutionContext, init.IsLogEnabled());        // TODO: move to Expander

   N_INF = MathLog(0);
   P_INF = -N_INF;
   NaN   =  N_INF - N_INF;

   PipDigits      = Digits & (~1);                                        SubPipDigits      = PipDigits+1;
   PipPoints      = MathRound(MathPow(10, Digits & 1));                   PipPoint          = PipPoints;
   Pips           = NormalizeDouble(1/MathPow(10, PipDigits), PipDigits); Pip               = Pips;
   PipPriceFormat = StringConcatenate(".", PipDigits);                    SubPipPriceFormat = StringConcatenate(PipPriceFormat, "'");
   PriceFormat    = ifString(Digits==PipDigits, PipPriceFormat, SubPipPriceFormat);

   __LOG_CUSTOM     = ec_SeparateLog(__ExecutionContext);            // supported by experts only
   __LOG_WARN.mail  = false;                                         // ...
   __LOG_WARN.sms   = false;                                         // ...
   __LOG_ERROR.mail = false;                                         // ...
   __LOG_ERROR.sms  = false;                                         // ...

   return(!catch("init.GlobalVars(1)"));
}


/**
 * Globale start()-Funktion für Scripte.
 *
 * @return int - Fehlerstatus
 */
int start() {
   if (__STATUS_OFF) {                                                        // init()-Fehler abfangen
      if (IsDllsAllowed() && IsLibrariesAllowed()) {
         string msg = WindowExpertName() +": switched off ("+ ifString(!__STATUS_OFF.reason, "unknown reason", ErrorToStr(__STATUS_OFF.reason)) +")";
         Comment(NL + NL + NL + msg);                                            // 3 Zeilen Abstand für Instrumentanzeige und ggf. vorhandene Legende
         debug("start(1)  "+ msg);
      }
      return(__STATUS_OFF.reason);
   }
   __WHEREAMI__   = CF_START;

   Tick++;                                                                    // einfache Zähler, die konkreten Werte haben keine Bedeutung
   Tick.Time      = MarketInfo(Symbol(), MODE_TIME);                          // TODO: !!! MODE_TIME ist im synthetischen Chart NULL               !!!
   Tick.isVirtual = true;                                                     // TODO: !!! MODE_TIME und TimeCurrent() sind im Tester-Chart falsch !!!
   ChangedBars    = -1;                                                       // in scripts not available
   UnchangedBars  = -1;                                                       // ...
   ShiftedBars    = -1;                                                       // ...

   ArrayCopyRates(rates);

   if (SyncMainContext_start(__ExecutionContext, rates, Bars, ChangedBars, Tick, Tick.Time, Bid, Ask) != NO_ERROR) {
      if (CheckErrors("start(2)")) return(last_error);
   }

   if (!Tick.Time) {
      int error = GetLastError();
      if (error && error!=ERR_SYMBOL_NOT_AVAILABLE)                           // ERR_SYMBOL_NOT_AVAILABLE vorerst ignorieren, da ein Offline-Chart beim ersten Tick
         if (CheckErrors("start(3)", error)) return(last_error);              // nicht sicher detektiert werden kann
   }


   // (1) init() war immer erfolgreich


   // (2) Abschluß der Chart-Initialisierung überprüfen
   if (!(__ExecutionContext[EC.programInitFlags] & INIT_NO_BARS_REQUIRED)) {  // Bars kann 0 sein, wenn das Script auf einem leeren Chart startet (Waiting for update...)
      if (!Bars)                                                              // oder der Chart beim Terminal-Start noch nicht vollständig initialisiert ist
         return(_last_error(CheckErrors("start(4)  Bars = 0", ERS_TERMINAL_NOT_YET_READY)));
   }


   // (3) Main-Funktion aufrufen
   onStart();


   // (4) check errors
   error = GetLastError();
   if (error || last_error|__ExecutionContext[EC.mqlError]|__ExecutionContext[EC.dllError])
      CheckErrors("start(5)", error);
   return(last_error);
}


/**
 * Globale deinit()-Funktion für Scripte.
 *
 * @return int - Fehlerstatus
 */
int deinit() {
   __WHEREAMI__ = CF_DEINIT;

   if (!IsDllsAllowed() || !IsLibrariesAllowed() || last_error==ERR_TERMINAL_INIT_FAILURE || last_error==ERR_DLL_EXCEPTION)
      return(last_error);

   int error = SyncMainContext_deinit(__ExecutionContext, UninitializeReason());
   if (IsError(error)) return(error|last_error|LeaveContext(__ExecutionContext));

   // Pre/Postprocessing-Hook
   error = onDeinit();                                               // Preprocessing-Hook
   if (error != -1) {
      afterDeinit();                                                 // Postprocessing-Hook nur ausführen, wenn Preprocessing-Hook
   }                                                                 // nicht mit -1 zurückkehrt.

   // User-spezifische Deinit-Tasks
   if (!error) {
      // ...
   }

   CheckErrors("deinit(2)");
   return(error|last_error|LeaveContext(__ExecutionContext));        // the very last statement
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
   MessageBox(message, "Script "+ __NAME() + location, MB_ICONERROR|MB_OK);

   return(SetLastError(error));
}


/**
 * Check and update the program's error status and activate the flag __STATUS_OFF accordingly.
 *
 * @param  string location - location of the check
 * @param  int    setError - error to enforce
 *
 * @return bool - whether the flag __STATUS_OFF is set
 */
bool CheckErrors(string location, int setError = NULL) {
   // (1) check and signal DLL errors
   int dll_error = __ExecutionContext[EC.dllError];                  // TODO: signal DLL errors
   if (dll_error && 1) {
      __STATUS_OFF        = true;                                    // all DLL errors are terminating errors
      __STATUS_OFF.reason = dll_error;
   }


   // (2) check MQL errors
   int mql_error = __ExecutionContext[EC.mqlError];
   switch (mql_error) {
      case NO_ERROR:
      case ERS_HISTORY_UPDATE:
    //case ERS_TERMINAL_NOT_YET_READY:                               // in scripts ERS_TERMINAL_NOT_YET_READY is a regular error
      case ERS_EXECUTION_STOPPING:
         break;
      default:
         __STATUS_OFF        = true;
         __STATUS_OFF.reason = mql_error;                            // MQL errors have higher severity than DLL errors
   }


   // (3) check last_error
   switch (last_error) {
      case NO_ERROR:
      case ERS_HISTORY_UPDATE:
    //case ERS_TERMINAL_NOT_YET_READY:                               // in scripts ERS_TERMINAL_NOT_YET_READY is a regular error
      case ERS_EXECUTION_STOPPING:
         break;
      default:
         __STATUS_OFF        = true;
         __STATUS_OFF.reason = last_error;                           // local errors have higher severity than library errors
   }


   // (4) check uncatched errors
   if (!setError) setError = GetLastError();
   if (setError && 1) {
      catch(location, setError);
      __STATUS_OFF        = true;
      __STATUS_OFF.reason = setError;                                // all uncatched errors are terminating errors
   }


   // (5) update variable last_error
   if (__STATUS_OFF) /*&&*/ if (!last_error)
      last_error = __STATUS_OFF.reason;

   return(__STATUS_OFF);

   // dummy calls to suppress compiler warnings
   __DummyCalls();
   HandleScriptError(NULL, NULL, NULL);
}


// --------------------------------------------------------------------------------------------------------------------------------------------------


#import "rsfLib1.ex4"
   string GetWindowText(int hWnd);

#import "rsfExpander.dll"
   bool   ec_SetLogEnabled      (int ec[], int status);
   int    SyncMainContext_init  (int ec[], int programType, string programName, int uninitReason, int initFlags, int deinitFlags, string symbol, int timeframe, int digits, double point, int extReporting, int recordEquity, int isTesting, int isVisualMode, int isOptimization, int lpSec, int hChart, int droppedOnChart, int droppedOnPosX, int droppedOnPosY);
   int    SyncMainContext_start (int ec[], double rates[][], int bars, int changedBars, int ticks, datetime time, double bid, double ask);
   int    SyncMainContext_deinit(int ec[], int uninitReason);

#import "user32.dll"
   int    GetParent(int hWnd);
#import
