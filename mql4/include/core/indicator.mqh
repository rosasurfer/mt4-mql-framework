
//////////////////////////////////////////////// Additional Input Parameters ////////////////////////////////////////////////

extern string ______________________________;
extern bool   AutoConfiguration = true;
extern int    __lpSuperContext;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

int    __CoreFunction = NULL;                                        // currently executed MQL core function: CF_INIT|CF_START|CF_DEINIT
double __rates[][6];                                                 // current price series
int    __lastAccountNumber = 0;                                      // previously active account number


/**
 * Global init() function for indicators.
 *
 * @return int - error status
 */
int init() {
   if (__STATUS_OFF)
      return(__STATUS_OFF.reason);

   if (__CoreFunction == NULL)                                       // init() called by the terminal, all variables are reset
      __CoreFunction = CF_INIT;

   if (!IsDllsAllowed()) {
      ForceAlert("Please enable DLL function calls for this indicator.");
      last_error          = ERR_DLL_CALLS_NOT_ALLOWED;
      __STATUS_OFF        = true;
      __STATUS_OFF.reason = last_error;
      return(last_error);
   }
   if (!IsLibrariesAllowed()) {
      ForceAlert("Please enable MQL library calls for this indicator.");
      last_error          = ERR_EX4_CALLS_NOT_ALLOWED;
      __STATUS_OFF        = true;
      __STATUS_OFF.reason = last_error;
      return(last_error);
   }

   // initialize the execution context
   int hChart = NULL; if (!IsTesting() || IsVisualMode()) {          // in tester WindowHandle() triggers ERR_FUNC_NOT_ALLOWED_IN_TESTER
       hChart = WindowHandle(Symbol(), NULL);                        // if VisualMode=Off
   }
   int error = SyncMainContext_init(__ExecutionContext, MT_INDICATOR, WindowExpertName(), UninitializeReason(), SumInts(__InitFlags), SumInts(__DeinitFlags), Symbol(), Period(), Digits, Point, NULL, IsTesting(), IsVisualMode(), IsOptimization(), false, __lpSuperContext, hChart, WindowOnDropped(), WindowXOnDropped(), WindowYOnDropped());
   if (!error) error = GetLastError();                               // detect a DLL error
   if (IsError(error)) {
      ForceAlert("ERROR:   "+ Symbol() +","+ PeriodDescription() +"  "+ WindowExpertName() +"::init(1)->SyncMainContext_init()  ["+ ErrorToStr(error) +"]");
      last_error          = error;
      __STATUS_OFF        = true;                                    // If SyncMainContext_init() failed the content of the EXECUTION_CONTEXT
      __STATUS_OFF.reason = last_error;                              // is undefined. We must not trigger loading of MQL libraries and return asap.
      return(last_error);
   }
   if (ProgramInitReason() == IR_PROGRAM_AFTERTEST) {
      __STATUS_OFF        = true;
      __STATUS_OFF.reason = last_error;
      return(last_error);
   }

   // finish initialization
   if (!init_Globals()) if (CheckErrors("init(2)")) return(last_error);

   // execute custom init tasks
   int initFlags = __ExecutionContext[EC.programInitFlags];

   if (initFlags & INIT_TIMEZONE && 1) {                             // check timezone configuration
      if (!StringLen(GetServerTimezone())) return(_last_error(CheckErrors("init(3)")));
   }
   if (initFlags & INIT_PIPVALUE && 1) {
      double tickSize = MarketInfo(Symbol(), MODE_TICKSIZE);         // fails if there is no tick yet, e.g.
      error = GetLastError();                                        // - symbol not yet subscribed (on start or account/template change), it shows up later
      if (IsError(error)) {                                          // - synthetic symbol in offline chart
         if (error == ERR_SYMBOL_NOT_AVAILABLE)
            return(_last_error(logInfo("init(4)  MarketInfo(MODE_TICKSIZE) => ERR_SYMBOL_NOT_AVAILABLE", SetLastError(ERS_TERMINAL_NOT_YET_READY)), CheckErrors("init(5)")));
         if (CheckErrors("init(6)", error)) return(last_error);
      }
      if (!tickSize) return(_last_error(logInfo("init(7)  MarketInfo(MODE_TICKSIZE=0)", SetLastError(ERS_TERMINAL_NOT_YET_READY)), CheckErrors("init(8)")));

      double tickValue = MarketInfo(Symbol(), MODE_TICKVALUE);
      error = GetLastError();
      if (IsError(error))
         if (CheckErrors("init(9)", error)) return(last_error);
      if (!tickValue)                       return(_last_error(logInfo("init(10)  MarketInfo(MODE_TICKVALUE=0)", SetLastError(ERS_TERMINAL_NOT_YET_READY)), CheckErrors("init(11)")));
   }
   if (initFlags & INIT_BARS_ON_HIST_UPDATE && 1) {                  // not yet implemented
   }

   // before onInit(): log input parameters if loaded by iCustom()
   if (IsSuperContext()) /*&&*/ if (IsLogDebug()) {
      string sInputs = InputsToStr();
      if (StringLen(sInputs) > 0) {
         sInputs = StringConcatenate(sInputs,
            ifString(!AutoConfiguration, "", NL +"AutoConfiguration=TRUE;"),
                                             NL +"__lpSuperContext=0x"+ IntToHexStr(__lpSuperContext) +";");
         logDebug("init(13)  input: "+ sInputs);
      }
   }

   /*
   User-spezifische init()-Routinen aufrufen. Diese können, müssen aber nicht implementiert sein.

   Die vom Terminal bereitgestellten UninitializeReason-Codes und ihre Bedeutung ändern sich in den einzelnen Terminalversionen
   und sind zur eindeutigen Unterscheidung der verschiedenen Init-Szenarien nicht geeignet.
   Solution: Funktion ProgramInitReason() und die neu eingeführten Konstanten INITREASON_*.

   // Execute init() event handlers. The reason-specific handlers are executed only if onInit() returns without errors.
   //
   +-- init reason -------+-- description --------------------------------+-- ui -----------+-- applies --+
   | IR_USER              | loaded by the user (also in tester)           |    input dialog |   I, E, S   | I = indicators
   | IR_TEMPLATE          | loaded by a template (also at terminal start) | no input dialog |   I, E      | E = experts
   | IR_PROGRAM           | loaded by iCustom()                           | no input dialog |   I         | S = scripts
   | IR_PROGRAM_AFTERTEST | loaded by iCustom() after end of test         | no input dialog |   I         |
   | IR_PARAMETERS        | input parameters changed                      |    input dialog |   I, E      |
   | IR_TIMEFRAMECHANGE   | chart period changed                          | no input dialog |   I, E      |
   | IR_SYMBOLCHANGE      | chart symbol changed                          | no input dialog |   I, E      |
   | IR_RECOMPILE         | reloaded after recompilation                  | no input dialog |   I, E      |
   | IR_TERMINAL_FAILURE  | terminal failure                              |    input dialog |      E      | @see https://github.com/rosasurfer/mt4-mql/issues/1
   +----------------------+-----------------------------------------------+-----------------+-------------+
   */
   error = onInit();                                                                   // preprocessing hook
                                                                                       //
   if (!error && !__STATUS_OFF) {                                                      //
      int initReason = ProgramInitReason();                                            //
      if (!initReason) if (CheckErrors("init(14)")) return(last_error);                //
                                                                                       //
      switch (initReason) {                                                            //
         case INITREASON_USER             : error = onInitUser();             break;   // init reasons
         case INITREASON_TEMPLATE         : error = onInitTemplate();         break;   //
         case INITREASON_PROGRAM          : error = onInitProgram();          break;   //
         case INITREASON_PROGRAM_AFTERTEST: error = onInitProgramAfterTest(); break;   //
         case INITREASON_PARAMETERS       : error = onInitParameters();       break;   //
         case INITREASON_TIMEFRAMECHANGE  : error = onInitTimeframeChange();  break;   //
         case INITREASON_SYMBOLCHANGE     : error = onInitSymbolChange();     break;   //
         case INITREASON_RECOMPILE        : error = onInitRecompile();        break;   //
         default:                                                                      //
            return(_last_error(CheckErrors("init(15)  unknown initReason: "+ initReason, ERR_RUNTIME_ERROR)));
      }                                                                                //
   }                                                                                   //
   if (error == ERS_TERMINAL_NOT_YET_READY) return(error);                             //
   if (!error && !__STATUS_OFF) {                                                      //
      error = afterInit();                                                             // postprocessing hook
   }

   // nach Parameteränderung im "Indicators List"-Window nicht auf den nächsten Tick warten
   if (!error && !__STATUS_OFF) {
      if (initReason == INITREASON_PARAMETERS) {
         Chart.SendTick();                         // TODO: Nur bei existierendem "Indicators List"-Window (nicht bei einzelnem Indikator).
      }                                            // TODO: Nicht im Tester-Chart. Oder etwa doch?
   }

   CheckErrors("init(16)");
   return(last_error);
}


/**
 * Update global variables. Called immediately after SyncMainContext_init().
 *
 * @return bool - success status
 */
bool init_Globals() {
   // Terminal bug 1: On opening of a new chart window and on account change the global vars Digits and Point are set to the
   //                 values stored in the applied template, irrespective of the real symbol properties. This affects only
   //                 the first init() call, in start() corrected values have been applied.
   //
   // Terminal bug 2: In terminals build ???-??? above bug is permanent and the built-in vars Digits and Point are unusable.
   //
   // Workaround: In init() correct Digits and Point values must be read from "symbols.raw". To work around broker configura-
   //             tion errors there should be a way to overwrite specific properties via the framework configuration.
   //
   // TODO: implement workaround in MT4Expander
   //
   __isChart   = (__ExecutionContext[EC.hChart] != 0);
   __isTesting = (__ExecutionContext[EC.testing] || IsTesting());
   if (__isTesting) __Test.barModel = Tester.GetBarModel();

   PipDigits      = Digits & (~1);
   PipPoints      = MathRound(MathPow(10, Digits & 1));
   Pip            = NormalizeDouble(1/MathPow(10, PipDigits), PipDigits);
   PipPriceFormat = ",'R."+ PipDigits;
   PriceFormat    = ifString(Digits==PipDigits, PipPriceFormat, PipPriceFormat +"'");
   Ticks          = __ExecutionContext[EC.ticks       ];
   Tick.time      = __ExecutionContext[EC.currTickTime];

   N_INF = MathLog(0);                                               // negative infinity
   P_INF = -N_INF;                                                   // positive infinity
   NaN   =  N_INF - N_INF;                                           // not-a-number

   return(!catch("init_Globals(1)"));
}


/**
 * Core start() function for indicators.
 *
 * Before execution the global var 'last_error' is reset and an existing error is stored in var 'prev_error'. If indicator
 * initialization returned with ERS_TERMINAL_NOT_YET_READY an attempt is made to re-execute initialization. On repeated
 * initialization errors execution stops.
 *
 * @return int - error status
 */
int start() {
   if (__STATUS_OFF) {
      if (IsDllsAllowed() && IsLibrariesAllowed()) {
         if (ProgramInitReason() == INITREASON_PROGRAM_AFTERTEST)
            return(__STATUS_OFF.reason);
         string msg = WindowExpertName() +" => switched off ("+ ifString(!__STATUS_OFF.reason, "unknown reason", ErrorToStr(__STATUS_OFF.reason)) +")";
         Comment(NL, NL, NL, NL, msg);                                              // 4 lines margin for symbol display and optional chart legend
      }
      return(__STATUS_OFF.reason);
   }

   Ticks++;                                                                         // einfacher Zähler, der konkrete Werte hat keine Bedeutung
   Tick.time = MarketInfo(Symbol(), MODE_TIME);                                     // TODO: im synthetischen Chart sind MODE_TIME und TimeCurrent() NULL


   debug("start(0.1)  Tick="+ Ticks +"  Time[0]="+ TimeToStr(Time[0], TIME_FULL) +"  Bars="+ Bars +"  ValidBars="+ IndicatorCounted() +"  account="+ AccountNumber());


   if (!Tick.time) {
      int error = GetLastError();
      if (error && error!=ERR_SYMBOL_NOT_AVAILABLE)                                 // ERR_SYMBOL_NOT_AVAILABLE vorerst ignorieren, da ein Offline-Chart beim ersten Tick
         if (CheckErrors("start(1)", error)) return(last_error);                    // nicht sicher detektiert werden kann
   }

   // ValidBars und ChangedBars ermitteln: die Originalwerte werden später ggf. überschrieben
   ValidBars   = IndicatorCounted();
   ChangedBars = Bars - ValidBars;
   ShiftedBars = 0;

   // Abschluß der Chart-Initialisierung überprüfen (Bars=0 kann bei Terminal-Start auftreten)
   if (!Bars) return(_last_error(logInfo("start(2)  Bars=0", SetLastError(ERS_TERMINAL_NOT_YET_READY)), CheckErrors("start(3)")));

   // Tickstatus bestimmen
   static int lastVolume = NULL;
   if      (!Volume[0] || !lastVolume) Tick.isVirtual = true;
   else if ( Volume[0] ==  lastVolume) Tick.isVirtual = true;
   else                                Tick.isVirtual = (ChangedBars > 2);
   lastVolume = Volume[0];

   // TODO: on account change IsConnected() returns FALSE and the code goes into the branch for offline charts
   // FATAL  Grid::start(6)  Bar[last.startBarOpenTime]=2022.06.29 15:30:00 not found  [ERR_RUNTIME_ERROR]

   // Valid/Changed/ShiftedBars in synthetischen Charts anhand der Zeitreihe selbst bestimmen. IndicatorCounted() signalisiert dort immer alle Bars als modifiziert.
   static int      last.bars = -1;
   static datetime last.startBarOpenTime, last.endBarOpenTime;
   if (!ValidBars) /*&&*/ if (!IsConnected()) {                                     // detektiert Offline-Chart (regulär oder Pseudo-Online-Chart)
      // Initialisierung
      if (last.bars == -1) {
         ChangedBars = Bars;                                                        // erster Zugriff auf die Zeitreihe
      }

      // Baranzahl ist unverändert
      else if (Bars == last.bars) {
         if (Time[Bars-1] == last.endBarOpenTime) {                                 // älteste Bar ist noch dieselbe
            ChangedBars = 1;
         }
         else {                                                                     // älteste Bar ist verändert => Bars wurden hinten "hinausgeschoben"
            if (Time[0] == last.startBarOpenTime) {                                 // neue Bars wurden in Lücke eingefügt: uneindeutig => alle Bars invalidieren
               ChangedBars = Bars;
            }
            else {                                                                  // neue Bars zu Beginn hinzugekommen: Bar[last.startBarOpenTime] suchen
               for (int i=1; i < Bars; i++) {
                  if (Time[i] == last.startBarOpenTime) break;
               }
               if (i == Bars) return(_last_error(CheckErrors("start(4)  Bar[last.startBarOpenTime]="+ TimeToStr(last.startBarOpenTime, TIME_FULL) +" not found", ERR_RUNTIME_ERROR)));
               ShiftedBars = i;
               ChangedBars = i+1;                                                   // Bar[last.startBarOpenTime] wird ebenfalls invalidiert (onBarOpen ChangedBars=2)
            }
         }
      }

      // Baranzahl ist verändert (hat sich vergrößert)
      else {
         if (Time[Bars-1] == last.endBarOpenTime) {                                 // älteste Bar ist noch dieselbe
            if (Time[0] == last.startBarOpenTime) {                                 // neue Bars wurden in Lücke eingefügt: uneindeutig => alle Bars invalidieren
               ChangedBars = Bars;
            }
            else {                                                                  // neue Bars zu Beginn hinzugekommen: Bar[last.startBarOpenTime] suchen
               for (i=1; i < Bars; i++) {
                  if (Time[i] == last.startBarOpenTime) break;
               }
               if (i == Bars) return(_last_error(CheckErrors("start(5)  Bar[last.startBarOpenTime]="+ TimeToStr(last.startBarOpenTime, TIME_FULL) +" not found", ERR_RUNTIME_ERROR)));
               ShiftedBars = i;
               ChangedBars = i+1;                                                   // Bar[last.startBarOpenTime] wird ebenfalls invalidiert (onBarOpen ChangedBars=2)
            }
         }
         else {                                                                     // älteste Bar ist verändert
            if (Time[Bars-1] < last.endBarOpenTime) {                               // Bars hinten angefügt: alle Bars invalidieren
               ChangedBars = Bars;
            }
            else {                                                                  // Bars hinten "hinausgeschoben"
               if (Time[0] == last.startBarOpenTime) {                              // neue Bars wurden in Lücke eingefügt: uneindeutig => alle Bars invalidieren
                  ChangedBars = Bars;
               }
               else {                                                               // neue Bars zu Beginn hinzugekommen: Bar[last.startBarOpenTime] suchen
                  for (i=1; i < Bars; i++) {
                     if (Time[i] == last.startBarOpenTime) break;
                  }
                  if (i == Bars) return(_last_error(CheckErrors("start(6)  Bar[last.startBarOpenTime]="+ TimeToStr(last.startBarOpenTime, TIME_FULL) +" not found", ERR_RUNTIME_ERROR)));
                  ShiftedBars = i;
                  ChangedBars = i+1;                                                // Bar[last.startBarOpenTime] wird ebenfalls invalidiert (onBarOpen ChangedBars=2)
               }
            }
         }
      }
   }
   last.bars             = Bars;
   last.startBarOpenTime = Time[0];
   last.endBarOpenTime   = Time[Bars-1];
   ValidBars             = Bars - ChangedBars;                                      // ValidBars neu definieren

   // Falls wir aus init() kommen, dessen Ergebnis prüfen
   if (__CoreFunction == CF_INIT) {
      __CoreFunction = ec_SetProgramCoreFunction(__ExecutionContext, CF_START);     // __STATUS_OFF ist false: evt. ist jedoch ein Status gesetzt, siehe CheckErrors()

      if (last_error == ERS_TERMINAL_NOT_YET_READY) {                               // alle anderen Stati brauchen zur Zeit keine eigene Behandlung
         debug("start(7)  init() returned ERS_TERMINAL_NOT_YET_READY, retrying...");
         last_error = NO_ERROR;

         error = init();                                                            // init() erneut aufrufen
         if (__STATUS_OFF) return(last_error);

         if (error == ERS_TERMINAL_NOT_YET_READY) {                                 // wenn überhaupt, kann wieder nur ein Status gesetzt sein
            __CoreFunction = ec_SetProgramCoreFunction(__ExecutionContext, CF_INIT);// __CoreFunction zurücksetzen und auf den nächsten Tick warten
            return(error);
         }
      }
      last_error = NO_ERROR;                                                        // init() war erfolgreich
      ValidBars  = 0;
   }
   else {
      // normaler Tick
      prev_error = last_error;
      ec_SetDllError(__ExecutionContext, SetLastError(NO_ERROR));

      if      (prev_error == ERS_TERMINAL_NOT_YET_READY) ValidBars = 0;
      else if (prev_error == ERR_HISTORY_INSUFFICIENT  ) ValidBars = 0;
      else if (prev_error == ERS_HISTORY_UPDATE        ) ValidBars = 0;
      if      (__STATUS_HISTORY_UPDATE                 ) ValidBars = 0;             // *_HISTORY_UPDATE kann je nach Kontext Fehler oder Status sein
   }
   if (!ValidBars) ShiftedBars = 0;
   ChangedBars = Bars - ValidBars;                                                  // ChangedBars aktualisieren (ValidBars wurde evt. neu gesetzt)

   __STATUS_HISTORY_UPDATE = false;

   // Detect and handle account changes                                             // TODO: move before resolving of Valid/Changed/ShiftedBars
   // ---------------------------------
   // If the trade server changes as part of the account change IndicatorCounted() will return 0 on the first tick in the new account.
   // If the trade server doesn't change the program continues to use the same history and IndicatorCounted() will not return 0.
   // However in both cases 2-3 ticks later all bars will be indicated as changed again.
   // Summary: In both cases we can rely on the return value of IndicatorCounted().
   int accountNumber = AccountNumber();
   if (__lastAccountNumber && accountNumber!=__lastAccountNumber) {
      error = onAccountChange(__lastAccountNumber, accountNumber);                  // TODO: do something on error
   }
   __lastAccountNumber = accountNumber;

   ArrayCopyRates(__rates);

   if (SyncMainContext_start(__ExecutionContext, __rates, Bars, ChangedBars, Ticks, Tick.time, Bid, Ask) != NO_ERROR) {
      if (CheckErrors("start(9)->SyncMainContext_start()")) return(last_error);
   }

   // call the userland main function
   error = onTick();
   if (error && error!=last_error) CheckErrors("start(10)", error);

   // check all errors
   error = GetLastError();
   if (error || last_error|__ExecutionContext[EC.mqlError]|__ExecutionContext[EC.dllError])
      CheckErrors("start(11)", error);
   if (last_error == ERS_HISTORY_UPDATE) __STATUS_HISTORY_UPDATE = true;
   return(last_error);
}


/**
 * Globale deinit()-Funktion für Indikatoren.
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

   int error = catch("deinit(2)");                                      // detect errors causing a full execution stop, e.g. ERR_ZERO_DIVIDE

   if (ProgramInitReason() == INITREASON_PROGRAM_AFTERTEST)
      return(error|last_error|LeaveContext(__ExecutionContext));

   // Execute user-specific deinit() handlers. Execution stops if a handler returns with an error.
   //
   if (!error) error = onDeinit();                                      // preprocessing hook
   if (!error) {                                                        //
      switch (UninitializeReason()) {                                   //
         case UR_PARAMETERS : error = onDeinitParameters();  break;     //
         case UR_CHARTCHANGE: error = onDeinitChartChange(); break;     //
         case UR_CHARTCLOSE : error = onDeinitChartClose();  break;     //
         case UR_UNDEFINED  : error = onDeinitUndefined();   break;     //
         case UR_REMOVE     : error = onDeinitRemove();      break;     //
         case UR_RECOMPILE  : error = onDeinitRecompile();   break;     //
         // terminal builds > 509                                       //
         case UR_TEMPLATE   : error = onDeinitTemplate();    break;     //
         case UR_INITFAILED : error = onDeinitFailed();      break;     //
         case UR_CLOSE      : error = onDeinitClose();       break;     //
                                                                        //
         default:                                                       //
            CheckErrors("deinit(3)  unexpected UninitializeReason: "+ UninitializeReason(), ERR_RUNTIME_ERROR);
            return(last_error|LeaveContext(__ExecutionContext));        //
      }                                                                 //
   }                                                                    //
   if (!error) error = afterDeinit();                                   // postprocessing hook
   if (!__isTesting) DeleteRegisteredObjects();

   return(CheckErrors("deinit(4)") + LeaveContext(__ExecutionContext));
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
   return(false);
}


/**
 * Whether the current program is an indicator.
 *
 * @return bool
 */
bool IsIndicator() {
   return(true);
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
 * Gibt die ID des aktuellen Deinit()-Szenarios zurück. Kann nur in deinit() aufgerufen werden.
 *
 * @return int - ID oder NULL, falls ein Fehler auftrat
 */
int DeinitReason() {
   return(NULL);
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
      case ERR_HISTORY_INSUFFICIENT:
      case ERS_HISTORY_UPDATE:
      case ERS_TERMINAL_NOT_YET_READY:
      case ERS_EXECUTION_STOPPING:
         break;
      default:
         __STATUS_OFF        = true;
         __STATUS_OFF.reason = mql_error;                   // MQL errors have higher severity than DLL errors
   }

   // check the module's MQL error (if set it should match EC.mqlError)
   switch (last_error) {
      case NO_ERROR:
      case ERR_HISTORY_INSUFFICIENT:
      case ERS_HISTORY_UPDATE:
      case ERS_TERMINAL_NOT_YET_READY:
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
      case ERR_HISTORY_INSUFFICIENT:
      case ERS_HISTORY_UPDATE:
      case ERS_TERMINAL_NOT_YET_READY:
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


// --------------------------------------------------------------------------------------------------------------------------------------------------


#import "rsfLib.ex4"
   bool AquireLock(string mutexName, bool wait);
   bool ReleaseLock(string mutexName);

#import "rsfMT4Expander.dll"
   int  ec_SetDllError           (int ec[], int error);
   int  ec_SetProgramCoreFunction(int ec[], int function);

   bool ShiftDoubleIndicatorBuffer(double buffer[], int size, int count, double emptyValue);

   int  SyncMainContext_init  (int ec[], int programType, string programName, int unintReason, int initFlags, int deinitFlags, string symbol, int timeframe, int digits, double point, int recordMode, int isTesting, int isVisualMode, int isOptimization, int isExternalReporting, int lpSec, int hChart, int droppedOnChart, int droppedOnPosX, int droppedOnPosY);
   int  SyncMainContext_start (int ec[], double rates[][], int bars, int changedBars, int ticks, datetime time, double bid, double ask);
   int  SyncMainContext_deinit(int ec[], int unintReason);
#import


// -- init() event handler templates ----------------------------------------------------------------------------------------


/**
 * Initialization preprocessing.
 *
 * @return int - error status
 *
int onInit()                                                   // opening curly braces are intentionally missing (UEStudio)
   return(NO_ERROR);
}


/**
 * Called after the indicator was manually loaded by the user. There was an input dialog.
 *
 * @return int - error status
 *
int onInitUser()
   return(NO_ERROR);
}


/**
 * Called after the indicator was loaded by a chart template. Also at terminal start. Also in tester with both
 * VisualMode=On|Off if the indicator is loaded by template "Tester.tpl". There was no input dialog.
 *
 * @return int - error status
 *
int onInitTemplate()
   return(NO_ERROR);
}


/**
 * Called if the indicator is loaded via iCustom(). There was no input dialog.
 *
 * @return int - error status
 *
int onInitProgram()
   return(NO_ERROR);
}


/**
 * Called after a test if the indicator was loaded via iCustom(). There was no input dialog.
 *
 * @return int - error status
 *
int onInitProgramAfterTest()
   return(NO_ERROR);
}


/**
 * Called after the input parameters were changed via the input dialog.
 *
 * @return int - error status
 *
int onInitParameters()
   return(NO_ERROR);
}


/**
 * Called after the chart timeframe has changed. There was no input dialog.
 *
 * @return int - error status
 *
int onInitTimeframeChange()
   return(NO_ERROR);
}


/**
 * Called after the chart symbol has changed. There was no input dialog.
 *
 * @return int - error status
 *
int onInitSymbolChange()
   return(NO_ERROR);
}


/**
 * Called after the indicator was recompiled. In older terminals (which ones exactly?) indicators are not automatically
 * reloded if the terminal is disconnected. There was no input dialog.
 *
 * @return int - error status
 *
int onInitRecompile()
   return(NO_ERROR);
}


/**
 * Initialization postprocessing.
 *
 * @return int - error status
 *
int afterInit()
   return(NO_ERROR);
}


// -- deinit() event handler templates --------------------------------------------------------------------------------------


/**
 * Deinitialization preprocessing
 *
 * @return int - error status
 *
int onDeinit()                                                 // opening curly braces are intentionally missing (UEStudio)
   return(NO_ERROR);
}


/**
 * Standalone:   Called before the input parameters are changed.
 * In iCustom(): Never called.
 *
 * @return int - error status
 *
int onDeinitParameters()
   return(NO_ERROR);
}


/**
 * Standalone:   Called before the current chart symbol or period are changed.
 * In iCustom(): Never called.
 *
 * @return int - error status
 *
int onDeinitChartChange()
   return(NO_ERROR);
}


/**
 * Standalone:   Called in terminals builds > 509 when the terminal shuts down.
 * In iCustom(): Never called.
 *
 * @return int - error status
 *
int onDeinitClose()
   return(NO_ERROR);
}


/**
 * Standalone:   Called in newer terminals (since when exactly?) when the chart profile is changed.
 * In iCustom(): Called in newer terminals (since when exactly?) in tester after the end of a test.
 *
 * @return int - error status
 *
int onDeinitChartClose()
   return(NO_ERROR);
}


/**
 * Standalone: Called if an indicator is removed manually.
 *             Called when a new chart template is applied.
 *             Called when the chart profile changes.
 *             Called when the chart is closed.
 *
 * In iCustom(): Called in all deinit() cases.
 *
 * @return int - error status
 *
int onDeinitRemove()
   return(NO_ERROR);
}


/**
 * Never encountered. Monitored in MT4Expander::onDeinitChartClose().
 *
 * @return int - error status
 *
int onDeinitUndefined()
   return(NO_ERROR);
}


/**
 * Called after recompilation before the indicator is reloaded.
 *
 * @return int - error status
 *
int onDeinitRecompile()
   return(NO_ERROR);
}


/**
 * Deinitialization postprocessing
 *
 * @return int - error status
 *
int afterDeinit()
   return(NO_ERROR);
}
*/
