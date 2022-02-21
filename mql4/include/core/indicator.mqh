
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
   int hChart = NULL; if (!IsTesting() || IsVisualMode())            // in tester WindowHandle() triggers ERR_FUNC_NOT_ALLOWED_IN_TESTER
       hChart = WindowHandle(Symbol(), NULL);                        // if VisualMode=Off

   int error = SyncMainContext_init(__ExecutionContext, MT_INDICATOR, WindowExpertName(), UninitializeReason(), SumInts(__InitFlags), SumInts(__DeinitFlags), Symbol(), Period(), Digits, Point, false, false, IsTesting(), IsVisualMode(), IsOptimization(), __lpSuperContext, hChart, WindowOnDropped(), WindowXOnDropped(), WindowYOnDropped());
   if (!error) error = GetLastError();                               // detect a DLL exception
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

   Die User-Routinen werden ausgeführt, wenn der Preprocessing-Hook (falls implementiert) ohne Fehler zurückkehrt.
   Der Postprocessing-Hook wird ausgeführt, wenn weder der Preprocessing-Hook (falls implementiert) noch die User-Routinen
   (falls implementiert) -1 zurückgeben.
   */
   error = onInit();                                                                   // Preprocessing-Hook
   if (!error) {                                                                       //
      int initReason = ProgramInitReason();                                            //
      if (!initReason) if (CheckErrors("init(14)")) return(last_error);                //
                                                                                       //
      switch (initReason) {                                                            //
         case INITREASON_USER             : error = onInitUser();             break;   //
         case INITREASON_TEMPLATE         : error = onInitTemplate();         break;   // TODO: in neuem Chartfenster falsche Werte für Point und Digits
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
   if (error != -1)                                                                    //
      error = afterInit();                                                             // Postprocessing-Hook

   // nach Parameteränderung im "Indicators List"-Window nicht auf den nächsten Tick warten
   if (initReason == INITREASON_PARAMETERS) {
      Chart.SendTick();                         // TODO: Nur bei existierendem "Indicators List"-Window (nicht bei einzelnem Indikator).
   }                                            // TODO: Nicht im Tester-Chart. Oder nicht etwa doch?

   CheckErrors("init(16)");
   return(last_error);
}


/**
 * Update global variables. Called immediately after SyncMainContext_init().
 *
 * @return bool - success status
 */
bool init_Globals() {
   //
   // Terminal bug 1: On opening of a new chart window and on account change the global constants Digits and Point are in
   //                 init() always set to 5 and 0.00001, irrespective of the actual symbol. Only a reload of
   //                 the chart template fixes the wrong values.
   //
   // Terminal bug 2: Since terminal version ??? bug #1 can't be fixed anymore by reloading the chart template. The issue is
   //                 permanent and Digits and Point become unusable.
   //
   // It was observed that Digits and/or Point have been configured incorrectly by the broker (e.g. S&P500 on Forex Ltd).
   //
   // Workaround: On init() the true Digits and Point values must be read manually from the current symbol's properties in
   //             "symbols.raw". To work around broker configuration errors there should be a way to overwrite specific
   //             properties via the framework configuration.
   //
   // TODO: implement workaround in MT4Expander
   //
   __isChart      = (__ExecutionContext[EC.hChart] != 0);
   PipDigits      = Digits & (~1);                                        SubPipDigits      = PipDigits+1;
   PipPoints      = MathRound(MathPow(10, Digits & 1));                   PipPoint          = PipPoints;
   Pips           = NormalizeDouble(1/MathPow(10, PipDigits), PipDigits); Pip               = Pips;
   PipPriceFormat = StringConcatenate(",'R.", PipDigits);                 SubPipPriceFormat = StringConcatenate(PipPriceFormat, "'");
   PriceFormat    = ifString(Digits==PipDigits, PipPriceFormat, SubPipPriceFormat);
   Tick           = __ExecutionContext[EC.ticks       ];
   Tick.time      = __ExecutionContext[EC.currTickTime];

   N_INF = MathLog(0);                                               // negative infinity
   P_INF = -N_INF;                                                   // positive infinity
   NaN   =  N_INF - N_INF;                                           // not-a-number

   return(!catch("init_Globals(1)"));
}


/**
 * Globale start()-Funktion für Indikatoren.
 *
 * - Erfolgt der Aufruf nach einem vorherigem init()-Aufruf und init() kehrte mit ERS_TERMINAL_NOT_YET_READY zurück,
 *   wird versucht, init() erneut auszuführen. Bei erneutem init()-Fehler bricht start() ab.
 *   Wurde init() fehlerfrei ausgeführt, wird der letzte Errorcode 'last_error' vor Abarbeitung zurückgesetzt.
 *
 * - Der letzte Errorcode 'last_error' wird in 'prev_error' gespeichert und vor Abarbeitung zurückgesetzt.
 *
 * @return int - error status
 */
int start() {
   if (__STATUS_OFF) {
      if (IsDllsAllowed() && IsLibrariesAllowed()) {
         if (ProgramInitReason() == INITREASON_PROGRAM_AFTERTEST)
            return(__STATUS_OFF.reason);
         string msg = WindowExpertName() +" => switched off ("+ ifString(!__STATUS_OFF.reason, "unknown reason", ErrorToStr(__STATUS_OFF.reason)) +")";
         Comment(NL, NL, NL, NL, msg);                                              // 4 Zeilen Abstand für Instrumentanzeige und ggf. vorhandene Legende
      }
      return(__STATUS_OFF.reason);
   }

   Tick++;                                                                          // einfacher Zähler, der konkrete Werte hat keine Bedeutung
   Tick.time = MarketInfo(Symbol(), MODE_TIME);                                     // TODO: !!! MODE_TIME ist im synthetischen Chart NULL               !!!
                                                                                    // TODO: !!! MODE_TIME und TimeCurrent() sind im Tester-Chart falsch !!!
   if (!Tick.time) {
      int error = GetLastError();
      if (error!=NO_ERROR) /*&&*/ if (error!=ERR_SYMBOL_NOT_AVAILABLE)              // ERR_SYMBOL_NOT_AVAILABLE vorerst ignorieren, da ein Offline-Chart beim ersten Tick
         if (CheckErrors("start(1)", error)) return(last_error);                    // nicht sicher detektiert werden kann
   }


   // (1) UnchangedBars und ChangedBars ermitteln: die Originalwerte werden in (4) und (5) ggf. neu definiert
   UnchangedBars = IndicatorCounted(); ValidBars = UnchangedBars;
   ChangedBars   = Bars - UnchangedBars;
   ShiftedBars   = 0;


   // (2) Abschluß der Chart-Initialisierung überprüfen (Bars=0 kann bei Terminal-Start auftreten)
   if (!Bars) return(_last_error(logInfo("start(2)  Bars=0", SetLastError(ERS_TERMINAL_NOT_YET_READY)), CheckErrors("start(3)")));


   // (3) Tickstatus bestimmen
   static int lastVolume;
   if      (!Volume[0] || !lastVolume) Tick.isVirtual = true;
   else if ( Volume[0] ==  lastVolume) Tick.isVirtual = true;
   else                                Tick.isVirtual = (ChangedBars > 2);
   lastVolume = Volume[0];


   // (4) Valid/Changed/ShiftedBars in synthetischen Charts anhand der Zeitreihe selbst bestimmen. IndicatorCounted() signalisiert dort immer alle Bars als modifiziert.
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
   UnchangedBars         = Bars - ChangedBars; ValidBars = UnchangedBars;           // UnchangedBars neu definieren


   // (5) Falls wir aus init() kommen, dessen Ergebnis prüfen
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
      last_error    = NO_ERROR;                                                     // init() war erfolgreich
      UnchangedBars = 0; ValidBars = UnchangedBars;
   }
   else {
      // normaler Tick
      prev_error = last_error;
      ec_SetDllError(__ExecutionContext, SetLastError(NO_ERROR));

      if      (prev_error == ERS_TERMINAL_NOT_YET_READY) UnchangedBars = 0;
      else if (prev_error == ERR_HISTORY_INSUFFICIENT  ) UnchangedBars = 0;
      else if (prev_error == ERS_HISTORY_UPDATE        ) UnchangedBars = 0;
      if      (__STATUS_HISTORY_UPDATE                 ) UnchangedBars = 0;         // *_HISTORY_UPDATE kann je nach Kontext Fehler oder Status sein
      ValidBars = UnchangedBars;
   }
   if (!UnchangedBars) ShiftedBars = 0;
   ChangedBars = Bars - UnchangedBars;                                              // ChangedBars aktualisieren (UnchangedBars wurde evt. neu gesetzt)

   __STATUS_HISTORY_UPDATE = false;

   // Detect and handle account changes
   // ---------------------------------
   // If the account server changes due to an account change IndicatorCounted() = ValidBars will immediately return 0 (zero).
   // If the server doesn't change the new account will continue to use the same history and IndicatorCounted() will not immediately
   // return zero. However, in both cases after 2-3 ticks in the new account all bars will be indicated as changed again.
   // Summary: In both cases we can fully rely on the return value of IndicatorCounted().
   int accountNumber = AccountNumber();
   if (__lastAccountNumber && accountNumber!=__lastAccountNumber) {
      error = onAccountChange(__lastAccountNumber, accountNumber);
      //if (error) {}     // TODO: do something
      //else {}
   }
   __lastAccountNumber = accountNumber;

   ArrayCopyRates(__rates);

   if (SyncMainContext_start(__ExecutionContext, __rates, Bars, ChangedBars, Tick, Tick.time, Bid, Ask) != NO_ERROR) {
      if (CheckErrors("start(9)")) return(last_error);
   }

   // call the userland main function
   int uError = onTick();
   if (uError && uError!=last_error) catch("start(10)", uError);

   // check errors
   int lError = GetLastError();
   if (lError || last_error|__ExecutionContext[EC.mqlError]|__ExecutionContext[EC.dllError])
      CheckErrors("start(11)", lError);
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

   int error = SyncMainContext_deinit(__ExecutionContext, UninitializeReason());
   if (error != NULL) return(CheckErrors("deinit(1)") + LeaveContext(__ExecutionContext));

   error = catch("deinit(2)");                                          // detect errors causing a full execution stop, e.g. ERR_ZERO_DIVIDE

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
   if (!This.IsTesting()) DeleteRegisteredObjects();

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
 * @param  int    error [optional] - error to enforce (default: none)
 *
 * @return bool - whether the flag __STATUS_OFF is set
 */
bool CheckErrors(string caller, int error = NULL) {
   // check DLL errors
   int dll_error = __ExecutionContext[EC.dllError];                  // TODO: signal DLL errors
   if (dll_error != NO_ERROR) {
      __STATUS_OFF        = true;                                    // all DLL errors are terminating errors
      __STATUS_OFF.reason = dll_error;
   }

   // check MQL errors
   int mql_error = __ExecutionContext[EC.mqlError];
   switch (mql_error) {
      case NO_ERROR:
      case ERR_HISTORY_INSUFFICIENT:
      case ERS_HISTORY_UPDATE:
      case ERS_TERMINAL_NOT_YET_READY:
      case ERS_EXECUTION_STOPPING:
         break;
      default:
         __STATUS_OFF        = true;
         __STATUS_OFF.reason = mql_error;                            // MQL errors have higher severity than DLL errors
   }

   // check last_error
   switch (last_error) {
      case NO_ERROR:
      case ERR_HISTORY_INSUFFICIENT:
      case ERS_HISTORY_UPDATE:
      case ERS_TERMINAL_NOT_YET_READY:
      case ERS_EXECUTION_STOPPING:
         break;
      default:
         __STATUS_OFF        = true;
         __STATUS_OFF.reason = last_error;                           // local errors have higher severity than library errors
   }

   // check uncatched errors
   if (!error) error = GetLastError();
   if (error != NO_ERROR) {
      catch(caller, error);
      __STATUS_OFF        = true;
      __STATUS_OFF.reason = error;                                   // all uncatched errors are terminating errors
   }

   // update variable last_error
   if (__STATUS_OFF) /*&&*/ if (!last_error)
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
   int  ec_SetDllError           (int ec[], int error   );
   int  ec_SetProgramCoreFunction(int ec[], int function);

   bool ShiftDoubleIndicatorBuffer(double buffer[], int size, int count, double emptyValue);

   int  SyncMainContext_init  (int ec[], int programType, string programName, int unintReason, int initFlags, int deinitFlags, string symbol, int timeframe, int digits, double point, int eaExternalReporting, int eaRecorder, int isTesting, int isVisualMode, int isOptimization, int lpSec, int hChart, int droppedOnChart, int droppedOnPosX, int droppedOnPosY);
   int  SyncMainContext_start (int ec[], double rates[][], int bars, int changedBars, int ticks, datetime time, double bid, double ask);
   int  SyncMainContext_deinit(int ec[], int unintReason);
#import


// -- init() event handler templates ----------------------------------------------------------------------------------------


/**
 * Initialization preprocessing
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
 * VisualMode=On|Off if the indicator is loaded by the template "Tester.tpl". On VisualMode=Off for each indicator in the
 * tester template the functions init() and deinit() are called. On VisualMode=Off the function start() is not called.
 * There was no input dialog.
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
 * Called after the indicator was recompiled. There was no input dialog.
 * In older terminals (which ones exactly?) indicators are not automatically reloded if the terminal is disconnected.
 *
 * @return int - error status
 *
int onInitRecompile()
   return(NO_ERROR);
}


/**
 * Initialization postprocessing
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
