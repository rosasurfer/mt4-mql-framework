
int __WHEREAMI__ = NULL;                                             // current MQL core function: CF_INIT|CF_START|CF_DEINIT

extern string ___________________________;
extern int    __lpSuperContext;

// current price series
double rates[][6];


/**
 * Global init() function for indicators.
 *
 * @return int - error status
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
      ForceAlert("MQL library calls are not enabled. Please load the indicator with \"Allow imports of external experts\" enabled.");
      last_error          = ERR_EX4_CALLS_NOT_ALLOWED;
      __STATUS_OFF        = true;
      __STATUS_OFF.reason = last_error;
      return(last_error);
   }


   // (1) initialize the execution context
   int hChart = NULL; if (!IsTesting() || IsVisualMode())            // in Tester WindowHandle() triggers ERR_FUNC_NOT_ALLOWED_IN_TESTER
       hChart = WindowHandle(Symbol(), NULL);                        // if VisualMode=Off

   int error = SyncMainContext_init(__ExecutionContext, MT_INDICATOR, WindowExpertName(), UninitializeReason(), SumInts(__INIT_FLAGS__), SumInts(__DEINIT_FLAGS__), Symbol(), Period(), Digits, Point, false, false, IsTesting(), IsVisualMode(), IsOptimization(), __lpSuperContext, hChart, WindowOnDropped(), WindowXOnDropped(), WindowYOnDropped());
   if (!error) error = GetLastError();                               // detect a DLL exception
   if (IsError(error)) {
      ForceAlert("ERROR:   "+ Symbol() +","+ PeriodDescription(Period()) +"  "+ WindowExpertName() +"::init(1)->SyncMainContext_init()  ["+ ErrorToStr(error) +"]");
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


   // (2) finish initialization
   if (!init.GlobalVars()) if (CheckErrors("init(2)")) return(last_error);


   // (3) execute custom init tasks
   int initFlags = __ExecutionContext[EC.programInitFlags];

   if (initFlags & INIT_TIMEZONE && 1) {                             // check timezone configuration
      if (!StringLen(GetServerTimezone())) return(_last_error(CheckErrors("init(3)")));
   }
   if (initFlags & INIT_PIPVALUE && 1) {
      TickSize = MarketInfo(Symbol(), MODE_TICKSIZE);                // fails if there is no tick yet
      error = GetLastError();
      if (IsError(error)) {                                          // - symbol not yet subscribed (start, account/template change), it may "show up" later
         if (error == ERR_SYMBOL_NOT_AVAILABLE)                      // - synthetic symbol in offline chart
            return(_last_error(log("init(4)  MarketInfo() => ERR_SYMBOL_NOT_AVAILABLE", SetLastError(ERS_TERMINAL_NOT_YET_READY)), CheckErrors("init(5)")));
         if (CheckErrors("init(6)", error)) return(last_error);
      }
      if (!TickSize) return(_last_error(log("init(7)  MarketInfo(MODE_TICKSIZE) = 0", SetLastError(ERS_TERMINAL_NOT_YET_READY)), CheckErrors("init(8)")));

      double tickValue = MarketInfo(Symbol(), MODE_TICKVALUE);
      error = GetLastError();
      if (IsError(error))
         if (CheckErrors("init(9)", error)) return( last_error);
      if (!tickValue)                       return(_last_error(log("init(10)  MarketInfo(MODE_TICKVALUE) = 0", SetLastError(ERS_TERMINAL_NOT_YET_READY)), CheckErrors("init(11)")));
   }
   if (initFlags & INIT_BARS_ON_HIST_UPDATE && 1) {}                 // not yet implemented


   // (4) before onInit(): if loaded by iCustom() log original input parameters
   string initialInput;
   if (IsSuperContext() && __LOG()) {
      //initialInput = InputsToStr();                                // un-comment for debugging only
      if (StringLen(initialInput) > 0) {
         initialInput = StringConcatenate(initialInput, NL, "__lpSuperContext=0x"+ IntToHexStr(__lpSuperContext), ";");
         log("init()  input: "+ initialInput);
      }
   }


   /*
   (5) User-spezifische init()-Routinen aufrufen. Diese können, müssen aber nicht implementiert sein.

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
      if (!initReason) if (CheckErrors("init(12)")) return(last_error);                //
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
            return(_last_error(CheckErrors("init(13)  unknown initReason = "+ initReason, ERR_RUNTIME_ERROR)));
      }                                                                                //
   }                                                                                   //
   if (error == ERS_TERMINAL_NOT_YET_READY) return(error);                             //
   if (error != -1)                                                                    //
      error = afterInit();                                                             // Postprocessing-Hook


   // (6) after onInit(): if loaded by iCustom() log modified input parameters
   if (IsSuperContext() && __LOG()) {
      string modifiedInput = InputsToStr();
      if (StringLen(modifiedInput) > 0) {
         modifiedInput = StringConcatenate(modifiedInput, NL, "__lpSuperContext=0x"+ IntToHexStr(__lpSuperContext), ";");
         modifiedInput = InputParamsDiff(initialInput, modifiedInput);
         if (StringLen(modifiedInput) > 0)
            log("init()  input: "+ modifiedInput);
      }
   }


   // (7) nach Parameteränderung im "Indicators List"-Window nicht auf den nächsten Tick warten
   if (initReason == INITREASON_PARAMETERS) {
      Chart.SendTick();                         // TODO: Nur bei existierendem "Indicators List"-Window (nicht bei einzelnem Indikator).
   }                                            // TODO: Nicht im Tester-Chart. Oder nicht etwa doch?

   CheckErrors("init(14)");
   return(last_error);
}


/**
 * Update global variables and the indicator's EXECUTION_CONTEXT.
 *
 * @return bool - success status
 *
 * Note: The memory location of an indicator's EXECUTION_CONTEXT changes with every init cycle.
 */
bool init.GlobalVars() {
   __lpSuperContext = __ExecutionContext[EC.superContext];
   if (!__lpSuperContext) {                                          // with a supercontext this indicator's context is already up-to-date
      ec_SetLogEnabled(__ExecutionContext, init.ReadLogConfig());    // TODO: move to Expander
   }

   N_INF = MathLog(0);
   P_INF = -N_INF;
   NaN   =  N_INF - N_INF;

   //
   // Terminal bug 1: On opening of a new chart window and on account change the global constants Digits and Point are in
   //                 init() always set to 5 and 0.00001, irrespective of the actual symbol's properties. Only a reload of
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
   // TODO: implement workaround in Expander
   //
   PipDigits      = Digits & (~1);                                        SubPipDigits      = PipDigits+1;
   PipPoints      = MathRound(MathPow(10, Digits & 1));                   PipPoint          = PipPoints;
   Pips           = NormalizeDouble(1/MathPow(10, PipDigits), PipDigits); Pip               = Pips;
   PipPriceFormat = StringConcatenate(".", PipDigits);                    SubPipPriceFormat = StringConcatenate(PipPriceFormat, "'");
   PriceFormat    = ifString(Digits==PipDigits, PipPriceFormat, SubPipPriceFormat);
   Tick           = __ExecutionContext[EC.ticks       ];
   Tick.Time      = __ExecutionContext[EC.lastTickTime];

   __LOG_WARN.mail  = false;
   __LOG_WARN.sms   = false;
   __LOG_ERROR.mail = false;
   __LOG_ERROR.sms  = false;

   return(!catch("init.GlobalVars(1)"));
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
 * @return int - Fehlerstatus
 */
int start() {
   if (__STATUS_OFF) {
      if (IsDllsAllowed() && IsLibrariesAllowed()) {
         if (ProgramInitReason() == INITREASON_PROGRAM_AFTERTEST)
            return(__STATUS_OFF.reason);
         string msg = WindowExpertName() +" => switched off ("+ ifString(!__STATUS_OFF.reason, "unknown reason", ErrorToStr(__STATUS_OFF.reason)) +")";
         Comment(NL, NL + NL + NL + msg);                                           // 4 Zeilen Abstand für Instrumentanzeige und ggf. vorhandene Legende
      }
      return(__STATUS_OFF.reason);
   }

   Tick++;                                                                          // einfacher Zähler, der konkrete Werte hat keine Bedeutung
   Tick.Time = MarketInfo(Symbol(), MODE_TIME);                                     // TODO: !!! MODE_TIME ist im synthetischen Chart NULL               !!!
                                                                                    // TODO: !!! MODE_TIME und TimeCurrent() sind im Tester-Chart falsch !!!
   if (!Tick.Time) {
      int error = GetLastError();
      if (error!=NO_ERROR) /*&&*/ if (error!=ERR_SYMBOL_NOT_AVAILABLE)              // ERR_SYMBOL_NOT_AVAILABLE vorerst ignorieren, da ein Offline-Chart beim ersten Tick
         if (CheckErrors("start(1)", error)) return(last_error);                    // nicht sicher detektiert werden kann
   }


   // (1) ChangedBars und UnchangedBars ermitteln: die Originalwerte werden in (4) und (5) ggf. neu definiert
   UnchangedBars = IndicatorCounted();
   ChangedBars   = Bars - UnchangedBars;
   ShiftedBars   = 0;


   // (2) Abschluß der Chart-Initialisierung überprüfen (Bars=0 kann bei Terminal-Start auftreten)
   if (!Bars) return(_last_error(log("start(2)  Bars=0", SetLastError(ERS_TERMINAL_NOT_YET_READY)), CheckErrors("start(3)")));


   // (3) Tickstatus bestimmen
   static int lastVolume;
   if      (!Volume[0] || !lastVolume) Tick.isVirtual = true;
   else if ( Volume[0] ==  lastVolume) Tick.isVirtual = true;
   else                                Tick.isVirtual = (ChangedBars > 2);
   lastVolume = Volume[0];


   // (4) Valid/Changed/ShiftedBars in synthetischen Charts anhand der Zeitreihe selbst bestimmen. IndicatorCounted() signalisiert dort immer alle Bars als modifiziert.
   static int      last.bars = -1;
   static datetime last.startBarOpenTime, last.endBarOpenTime;
   if (!UnchangedBars) /*&&*/ if (!IsConnected()) {                                 // detektiert Offline-Chart (regulär oder Pseudo-Online-Chart)
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
                  ShiftedBars =i;
                  ChangedBars = i+1;                                                // Bar[last.startBarOpenTime] wird ebenfalls invalidiert (onBarOpen ChangedBars=2)
               }
            }
         }
      }
   }
   last.bars             = Bars;
   last.startBarOpenTime = Time[0];
   last.endBarOpenTime   = Time[Bars-1];
   UnchangedBars         = Bars - ChangedBars;                                      // UnchangedBars neu definieren


   // (5) Falls wir aus init() kommen, dessen Ergebnis prüfen
   if (__WHEREAMI__ == CF_INIT) {
      __WHEREAMI__ = ec_SetProgramCoreFunction(__ExecutionContext, CF_START);       // __STATUS_OFF ist false: evt. ist jedoch ein Status gesetzt, siehe CheckErrors()

      if (last_error == ERS_TERMINAL_NOT_YET_READY) {                               // alle anderen Stati brauchen zur Zeit keine eigene Behandlung
         debug("start(7)  init() returned ERS_TERMINAL_NOT_YET_READY, retrying...");
         last_error = NO_ERROR;

         error = init();                                                            // init() erneut aufrufen
         if (__STATUS_OFF) return(last_error);

         if (error == ERS_TERMINAL_NOT_YET_READY) {                                 // wenn überhaupt, kann wieder nur ein Status gesetzt sein
            __WHEREAMI__ = ec_SetProgramCoreFunction(__ExecutionContext, CF_INIT);  // __WHEREAMI__ zurücksetzen und auf den nächsten Tick warten
            return(error);
         }
      }
      last_error    = NO_ERROR;                                                     // init() war erfolgreich
      UnchangedBars = 0;
   }
   else {
      // normaler Tick
      prev_error = last_error;
      ec_SetDllError(__ExecutionContext, SetLastError(NO_ERROR));

      if      (prev_error == ERS_TERMINAL_NOT_YET_READY) UnchangedBars = 0;
      else if (prev_error == ERS_HISTORY_UPDATE        ) UnchangedBars = 0;
      else if (prev_error == ERR_HISTORY_INSUFFICIENT  ) UnchangedBars = 0;
      if      (__STATUS_HISTORY_UPDATE                 ) UnchangedBars = 0;         // *_HISTORY_UPDATE und *_HISTORY_INSUFFICIENT können je nach Kontext Fehler und/oder Status sein.
      if      (__STATUS_HISTORY_INSUFFICIENT           ) UnchangedBars = 0;
   }
   if (!UnchangedBars) ShiftedBars = 0;
   ChangedBars = Bars - UnchangedBars;                                              // ChangedBars aktualisieren (UnchangedBars wurde evt. neu gesetzt)


   /*
   // (6) Werden Zeichenpuffer verwendet, muß in onTick() deren Initialisierung überprüft werden.
   if (ArraySize(buffer) == 0)
      return(SetLastError(ERS_TERMINAL_NOT_YET_READY));                             // kann bei Terminal-Start auftreten
   */

   __STATUS_HISTORY_UPDATE       = false;
   __STATUS_HISTORY_INSUFFICIENT = false;

   ArrayCopyRates(rates);

   if (SyncMainContext_start(__ExecutionContext, rates, Bars, ChangedBars, Tick, Tick.Time, Bid, Ask) != NO_ERROR) {
      if (CheckErrors("start(8)")) return(last_error);
   }


   // (7) bei Bedarf Input-Dialog aufrufen
   if (__STATUS_RELAUNCH_INPUT) {
      __STATUS_RELAUNCH_INPUT = false;
      return(_last_error(start.RelaunchInputDialog(), CheckErrors("start(9)")));
   }


   // (8) Main-Funktion aufrufen
   onTick();


   // (9) check errors
   error = GetLastError();
   if (error || last_error|__ExecutionContext[EC.mqlError]|__ExecutionContext[EC.dllError])
      CheckErrors("start(10)", error);
   if      (last_error == ERS_HISTORY_UPDATE      ) __STATUS_HISTORY_UPDATE       = true;
   else if (last_error == ERR_HISTORY_INSUFFICIENT) __STATUS_HISTORY_INSUFFICIENT = true;
   return(last_error);
}


/**
 * Globale deinit()-Funktion für Indikatoren.
 *
 * @return int - Fehlerstatus
 */
int deinit() {
   __WHEREAMI__ = CF_DEINIT;

   if (!IsDllsAllowed() || !IsLibrariesAllowed() || last_error==ERR_TERMINAL_INIT_FAILURE || last_error==ERR_DLL_EXCEPTION)
      return(last_error);

   int error = SyncMainContext_deinit(__ExecutionContext, UninitializeReason());
   if (IsError(error)) return(error|last_error|LeaveContext(__ExecutionContext));

   if (ProgramInitReason() == INITREASON_PROGRAM_AFTERTEST)
      return(error|last_error|LeaveContext(__ExecutionContext));


   // User-Routinen *können*, müssen aber nicht implementiert werden.
   //
   // Die User-Routinen werden ausgeführt, wenn der Preprocessing-Hook (falls implementiert) ohne Fehler zurückkehrt.
   // Der Postprocessing-Hook wird ausgeführt, wenn weder der Preprocessing-Hook (falls implementiert) noch die User-Routinen
   // (falls implementiert) -1 zurückgeben.


   // User-spezifische deinit()-Routinen aufrufen                                //
   error = onDeinit();                                                           // Preprocessing-Hook
                                                                                 //
   if (!error) {                                                                 //
      switch (UninitializeReason()) {                                            //
         case UR_PARAMETERS : error = onDeinitParameters();    break;            //
         case UR_CHARTCHANGE: error = onDeinitChartChange();   break;            //
         case UR_ACCOUNT    : error = onDeinitAccountChange(); break;            //
         case UR_CHARTCLOSE : error = onDeinitChartClose();    break;            //
         case UR_UNDEFINED  : error = onDeinitUndefined();     break;            //
         case UR_REMOVE     : error = onDeinitRemove();        break;            //
         case UR_RECOMPILE  : error = onDeinitRecompile();     break;            //
         // build > 509                                                          //
         case UR_TEMPLATE   : error = onDeinitTemplate();      break;            //
         case UR_INITFAILED : error = onDeinitFailed();        break;            //
         case UR_CLOSE      : error = onDeinitClose();         break;            //
                                                                                 //
         default:                                                                //
            CheckErrors("deinit(1)  unknown UninitializeReason = "+ UninitializeReason(), ERR_RUNTIME_ERROR);
            return(last_error|LeaveContext(__ExecutionContext));                 //
      }                                                                          //
   }                                                                             //
   if (error != -1)                                                              //
      error = afterDeinit();                                                     // Postprocessing-Hook


   // User-spezifische Deinit-Tasks ausführen
   if (!error) {
   }

   CheckErrors("deinit(2)");
   return(last_error|LeaveContext(__ExecutionContext));                          // the very last statement
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
      case ERS_TERMINAL_NOT_YET_READY:
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
      case ERS_TERMINAL_NOT_YET_READY:
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
}


/**
 * Whether a chart command was sent to the indicator. If so, the command is retrieved and stored.
 *
 * @param  string commands[] - array to store received commands in
 *
 * @return bool
 */
bool EventListener_ChartCommand(string &commands[]) {
   if (!__CHART()) return(false);

   static string label, mutex; if (!StringLen(label)) {
      label = __NAME() +".command";
      mutex = "mutex."+ label;
   }

   // check non-synchronized (read-only) for a command to prevent aquiring the lock on each tick
   if (ObjectFind(label) == 0) {
      // aquire the lock for write-access if there's indeed a command
      if (!AquireLock(mutex, true)) return(false);

      ArrayPushString(commands, ObjectDescription(label));
      ObjectDelete(label);
      return(ReleaseLock(mutex));
   }
   return(false);
}


// --------------------------------------------------------------------------------------------------------------------------------------------------


#import "rsfLib1.ex4"
   bool   AquireLock(string mutexName, bool wait);
   bool   ReleaseLock(string mutexName);

#import "rsfExpander.dll"
   int    ec_SetDllError           (/*EXECUTION_CONTEXT*/int ec[], int error       );
   bool   ec_SetLogEnabled         (/*EXECUTION_CONTEXT*/int ec[], int status      );
   int    ec_SetProgramCoreFunction(/*EXECUTION_CONTEXT*/int ec[], int coreFunction);

   bool   ShiftIndicatorBuffer(double buffer[], int bufferSize, int bars, double emptyValue);

   int    SyncMainContext_init  (int ec[], int programType, string programName, int unintReason, int initFlags, int deinitFlags, string symbol, int timeframe, int digits, double point, int extReporting, int recordEquity, int isTesting, int isVisualMode, int isOptimization, int lpSec, int hChart, int droppedOnChart, int droppedOnPosX, int droppedOnPosY);
   int    SyncMainContext_start (int ec[], double rates[][], int bars, int changedBars, int ticks, datetime time, double bid, double ask);
   int    SyncMainContext_deinit(int ec[], int unintReason);
#import


// -- init() event handler templates (opening curly braces are intentionally missing) ---------------------------------------


/**
 * Initialization pre-processing hook.
 *
 * @return int - error status; in case of errors reason-specific event handlers are not executed
 *
int onInit()
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
 * Called after the indicator was loaded by a chart template. Also at terminal start. Also in Tester with both
 * VisualMode=On|Off if the indicator is part of the tester template "Tester.tpl". On VisualMode=Off for each indicator in
 * the tester template the functions init() and deinit() are called. On VisualMode=Off the function start() is not called.
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
 * Called after the current chart period has changed. There was no input dialog.
 *
 * @return int - error status
 *
int onInitTimeframeChange()
   return(NO_ERROR);
}


/**
 * Called after the current chart symbol has changed. There was no input dialog.
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
 * Initialization post-processing hook. Called only if neither the pre-processing hook nor the reason-specific event handler
 * returned with -1 (which signals a hard stop as opposite to a regular error).
 *
 * @return int - error status
 *
int afterInit()
   return(NO_ERROR);
}


// -- deinit() event handler templates (opening curly braces are intentionally missing) -------------------------------------


/**
 * Deinitialization pre-processing hook.
 *
 * @return int - error status
 *
int onDeinit()
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
 * Never encountered. Tracked in Expander::onDeinitAccountChange().
 *
 * @return int - error status
 *
int onDeinitAccountChange()
   return(NO_ERROR);
}


/**
 * Standalone:   Called in terminals newer than build 509 when the terminal shuts down.
 * In iCustom(): Never called.
 *
 * @return int - error status
 *
int onDeinitClose()
   return(NO_ERROR);
}


/**
 * Standalone:   Called in newer terminals (since when exactly) when the chart profile is changed.
 * In iCustom(): Called in newer terminals (since when exactly) in tester after the end of a test.
 *
 * @return int - error status
 *
int onDeinitChartClose()
   return(NO_ERROR);
}


/**
 * Standalone:   - Called if an indicator is removed manually.
 *               - Called when another chart template is applied.
 *               - Called when the chart profile is changed.
 *               - Called when the chart is closed.
 *
 * In iCustom(): Called in all deinit() cases.
 *
 * @return int - error status
 *
int onDeinitRemove()
   return(NO_ERROR);
}


/**
 * Never encountered. Tracked in Expander::onDeinitChartClose().
 *
 * @return int - error status
 *
int onDeinitUndefined()
   return(NO_ERROR);
}


/**
 * Called before an indicator is reloaded after recompilation.
 *
 * @return int - error status
 *
int onDeinitRecompile()
   return(NO_ERROR);
}


/**
 * Deinitialization post-processing hook.
 *
 * @return int - error status
 *
int afterDeinit()
   return(NO_ERROR);
}
*/
