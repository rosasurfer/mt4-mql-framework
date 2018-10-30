
int __WHEREAMI__ = NULL;                                             // current MQL RootFunction: RF_INIT|RF_START|RF_DEINIT

extern string ___________________________;
extern int    __lpSuperContext;

// current price series
double rates[][6];
bool   ratesCopied = false;


/**
 * Global init() function for indicators.
 *
 * @return int - error status
 *
 * @throws ERS_TERMINAL_NOT_YET_READY
 */
int init() {
   if (__STATUS_OFF)
      return(__STATUS_OFF.reason);

   if (__WHEREAMI__ == NULL)                                         // init() called by the terminal, all variables are reset
      __WHEREAMI__ = RF_INIT;

   if (!IsDllsAllowed()) {
      Alert("DLL function calls are not enabled. Please go to Tools -> Options -> Expert Advisors and allow DLL imports.");
      last_error          = ERR_DLL_CALLS_NOT_ALLOWED;
      __STATUS_OFF        = true;
      __STATUS_OFF.reason = last_error;
      return(last_error);
   }
   if (!IsLibrariesAllowed()) {
      Alert("MQL library calls are not enabled. Please load the indicator with \"Allow imports of external experts\" enabled.");
      last_error          = ERR_EX4_CALLS_NOT_ALLOWED;
      __STATUS_OFF        = true;
      __STATUS_OFF.reason = last_error;
      return(last_error);
   }


   // (1) initialize the execution context
   int hChart = NULL; if (!IsTesting() || IsVisualMode())            // in Tester WindowHandle() triggers ERR_FUNC_NOT_ALLOWED_IN_TESTER
       hChart = WindowHandle(Symbol(), NULL);                        // if VisualMode=Off
   int error = SyncMainContext_init(__ExecutionContext, MT_INDICATOR, WindowExpertName(), UninitializeReason(), SumInts(__INIT_FLAGS__), SumInts(__DEINIT_FLAGS__), Symbol(), Period(), Digits, Point, false, false, IsTesting(), IsVisualMode(), IsOptimization(), __lpSuperContext, hChart, WindowOnDropped(), WindowXOnDropped(), WindowYOnDropped());
   if (IsError(error)) {
      Alert("ERROR:   ", Symbol(), ",", PeriodDescription(Period()), "  ", WindowExpertName(), "::init(1)->SyncMainContext_init()  [", ErrorToStr(error), "]");
      last_error          = error;
      __STATUS_OFF        = true;                                    // If SyncMainContext_init() failed the content of the EXECUTION_CONTEXT
      __STATUS_OFF.reason = last_error;                              // is undefined. We must not trigger loading of MQL libraries and return asap.
      return(last_error);
   }

   __lpSuperContext = ec_lpSuperContext(__ExecutionContext);

   if (InitReason() == IR_PROGRAM_AFTERTEST) {
      __STATUS_OFF        = true;
      __STATUS_OFF.reason = last_error;
      return(last_error);
   }


   // (2) finish initialization
   if (!UpdateGlobalVars()) if (CheckErrors("init(2)")) return(last_error);


   // (3) initialize rsfLib1
   int tickData[3];
   error = _lib1.init(tickData);
   if (IsError(error)) if (CheckErrors("init(3)")) return(last_error);

   Tick          = tickData[0];
   Tick.Time     = tickData[1];
   Tick.prevTime = tickData[2];


   // (4) execute custom init tasks
   int initFlags = ec_InitFlags(__ExecutionContext);

   if (initFlags & INIT_TIMEZONE && 1) {                             // check timezone configuration
      if (!StringLen(GetServerTimezone()))  return(_last_error(CheckErrors("init(4)")));
   }
   if (initFlags & INIT_PIPVALUE && 1) {
      TickSize = MarketInfo(Symbol(), MODE_TICKSIZE);                // fails if there is no tick yet
      error = GetLastError();
      if (IsError(error)) {                                          // - symbol not yet subscribed (start, account/template change), it may "show up" later
         if (error == ERR_SYMBOL_NOT_AVAILABLE)                      // - synthetic symbol in offline chart
            return(_last_error(log("init(5)  MarketInfo() => ERR_SYMBOL_NOT_AVAILABLE", SetLastError(ERS_TERMINAL_NOT_YET_READY)), CheckErrors("init(6)")));
         if (CheckErrors("init(7)", error)) return(last_error);
      }
      if (!TickSize) return(_last_error(log("init(8)  MarketInfo(MODE_TICKSIZE) = 0", SetLastError(ERS_TERMINAL_NOT_YET_READY)), CheckErrors("init(9)")));

      double tickValue = MarketInfo(Symbol(), MODE_TICKVALUE);
      error = GetLastError();
      if (IsError(error))
         if (CheckErrors("init(10)", error)) return( last_error);
      if (!tickValue)                       return(_last_error(log("init(11)  MarketInfo(MODE_TICKVALUE) = 0", SetLastError(ERS_TERMINAL_NOT_YET_READY)), CheckErrors("init(12)")));
   }
   if (initFlags & INIT_BARS_ON_HIST_UPDATE && 1) {}                 // not yet implemented


   // (5) before onInit(): if loaded by iCustom() log original input parameters
   if (IsSuperContext()) {
      string initialInput/*=InputsToStr()*/, modifiedInput;          // enable for debugging only
      if (StringLen(initialInput) > 0) {
         initialInput = StringConcatenate(initialInput, NL, "__lpSuperContext=0x"+ IntToHexStr(__lpSuperContext), ";");
         __LOG = true;
         log("init()  input: "+ initialInput);
      }
   }


   /*
   (6) User-spezifische init()-Routinen aufrufen. Diese können, müssen aber nicht implementiert sein.

   Die vom Terminal bereitgestellten UninitializeReason-Codes und ihre Bedeutung ändern sich in den einzelnen Terminalversionen
   und sind zur eindeutigen Unterscheidung der verschiedenen Init-Szenarien nicht geeignet.
   Solution: Funktion InitReason() und die neu eingeführten Konstanten INITREASON_*.

   +-- init reason -------+-- description --------------------------------+-- ui -----------+-- applies --+
   | IR_USER              | loaded by the user (also in tester)           |    input dialog |   I, E, S   |   I = indicators
   | IR_TEMPLATE          | loaded by a template (also at terminal start) | no input dialog |   I, E      |   E = experts
   | IR_PROGRAM           | loaded by iCustom()                           | no input dialog |   I         |   S = scripts
   | IR_PROGRAM_AFTERTEST | loaded by iCustom() after end of test         | no input dialog |   I         |
   | IR_PARAMETERS        | input parameters changed                      |    input dialog |   I, E      |
   | IR_TIMEFRAMECHANGE   | chart period changed                          | no input dialog |   I, E      |
   | IR_SYMBOLCHANGE      | chart symbol changed                          | no input dialog |   I, E      |
   | IR_RECOMPILE         | reloaded after recompilation                  | no input dialog |   I, E      |
   | IR_TERMINAL_FAILURE  | terminal failure                              |    input dialog |      E      |   @see https://github.com/rosasurfer/mt4-mql/issues/1
   +----------------------+-----------------------------------------------+-----------------+-------------+

   Die User-Routinen werden ausgeführt, wenn der Preprocessing-Hook (falls implementiert) ohne Fehler zurückkehrt.
   Der Postprocessing-Hook wird ausgeführt, wenn weder der Preprocessing-Hook (falls implementiert) noch die User-Routinen
   (falls implementiert) -1 zurückgeben.
   */
   error = onInit();                                                                   // Preprocessing-Hook
   if (!error) {                                                                       //
      int initReason = InitReason();                                                   //
      if (!initReason) if (CheckErrors("init(13)")) return(last_error);                //
                                                                                       //
      switch (initReason) {                                                            //
         case INITREASON_USER             : error = onInit_User();             break;  //
         case INITREASON_TEMPLATE         : error = onInit_Template();         break;  // TODO: in neuem Chartfenster falsche Werte für Point und Digits
         case INITREASON_PROGRAM          : error = onInit_Program();          break;  //
         case INITREASON_PROGRAM_AFTERTEST: error = onInit_ProgramAfterTest(); break;  //
         case INITREASON_PARAMETERS       : error = onInit_Parameters();       break;  //
         case INITREASON_TIMEFRAMECHANGE  : error = onInit_TimeframeChange();  break;  //
         case INITREASON_SYMBOLCHANGE     : error = onInit_SymbolChange();     break;  //
         case INITREASON_RECOMPILE        : error = onInit_Recompile();        break;  //
         default:                                                                      //
            return(_last_error(CheckErrors("init(14)  unknown initReason = "+ initReason, ERR_RUNTIME_ERROR)));
      }                                                                                //
   }                                                                                   //
   if (error == ERS_TERMINAL_NOT_YET_READY) return(error);                             //
   if (error != -1)                                                                    //
      error = afterInit();                                                             // Postprocessing-Hook


   // (7) after onInit(): if loaded by iCustom() log modified input parameters
   if (IsSuperContext()) {
      modifiedInput = InputsToStr();
      if (StringLen(modifiedInput) > 0) {
         modifiedInput = StringConcatenate(modifiedInput, NL, "__lpSuperContext=0x"+ IntToHexStr(__lpSuperContext), ";");
         modifiedInput = InputParamsDiff(initialInput, modifiedInput);
         if (StringLen(modifiedInput) > 0) {
            __LOG = true;
            log("init()  input: "+ modifiedInput);
         }
      }
   }


   // (8) nach Parameteränderung im "Indicators List"-Window nicht auf den nächsten Tick warten
   if (initReason == INITREASON_PARAMETERS) {
      Chart.SendTick();                         // TODO: Nur bei existierendem "Indicators List"-Window (nicht bei einzelnem Indikator).
   }                                            // TODO: Nicht im Tester-Chart. Oder nicht etwa doch?

   CheckErrors("init(15)");
   return(last_error);
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
 *
 * @throws ERS_TERMINAL_NOT_YET_READY
 */
int start() {
   if (__STATUS_OFF) {
      if (IsDllsAllowed() && IsLibrariesAllowed()) {
         if (InitReason() == INITREASON_PROGRAM_AFTERTEST)
            return(__STATUS_OFF.reason);
         string msg = WindowExpertName() +" => switched off ("+ ifString(!__STATUS_OFF.reason, "unknown reason", ErrorToStr(__STATUS_OFF.reason)) +")";
         Comment(NL, NL + NL + NL + msg);                                           // 4 Zeilen Abstand für Instrumentanzeige und ggf. vorhandene Legende
      }
      return(__STATUS_OFF.reason);
   }

   Tick++; zTick++;                                                                 // einfache Zähler, die konkreten Werte haben keine Bedeutung
   Tick.prevTime = Tick.Time;
   Tick.Time     = MarketInfo(Symbol(), MODE_TIME);                                 // TODO: !!! MODE_TIME ist im synthetischen Chart NULL               !!!
                                                                                    // TODO: !!! MODE_TIME und TimeCurrent() sind im Tester-Chart falsch !!!
   if (!Tick.Time) {
      int error = GetLastError();
      if (error!=NO_ERROR) /*&&*/ if (error!=ERR_SYMBOL_NOT_AVAILABLE)              // ERR_SYMBOL_NOT_AVAILABLE vorerst ignorieren, da ein Offline-Chart beim ersten Tick
         if (CheckErrors("start(1)", error)) return(last_error);                    // nicht sicher detektiert werden kann
   }


   // (1) Valid- und ChangedBars berechnen: die Originalwerte werden in (4) und (5) ggf. neu definiert
   ValidBars   = IndicatorCounted();
   ChangedBars = Bars - ValidBars;
   ShiftedBars = 0;


   // (2) Abschluß der Chart-Initialisierung überprüfen (Bars=0 kann bei Terminal-Start auftreten)
   if (!Bars) return(_last_error(log("start(2)  Bars=0", SetLastError(ERS_TERMINAL_NOT_YET_READY)), CheckErrors("start(3)")));


   // (3) Tickstatus bestimmen
   int vol = Volume[0];
   static int last.vol;
   if      (!vol || !last.vol) Tick.isVirtual = true;
   else if ( vol ==  last.vol) Tick.isVirtual = true;
   else                        Tick.isVirtual = (ChangedBars > 2);
   last.vol = vol;


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
   ValidBars             = Bars - ChangedBars;                                      // ValidBars neu definieren


   // (5) Falls wir aus init() kommen, dessen Ergebnis prüfen
   if (__WHEREAMI__ == RF_INIT) {
      __WHEREAMI__ = ec_SetRootFunction(__ExecutionContext, RF_START);              // __STATUS_OFF ist false: evt. ist jedoch ein Status gesetzt, siehe CheckErrors()

      if (last_error == ERS_TERMINAL_NOT_YET_READY) {                               // alle anderen Stati brauchen zur Zeit keine eigene Behandlung
         debug("start(7)  init() returned ERS_TERMINAL_NOT_YET_READY, retrying...");
         last_error = NO_ERROR;

         error = init();                                                            // init() erneut aufrufen
         if (__STATUS_OFF) return(last_error);

         if (error == ERS_TERMINAL_NOT_YET_READY) {                                 // wenn überhaupt, kann wieder nur ein Status gesetzt sein
            __WHEREAMI__ = ec_SetRootFunction(__ExecutionContext, RF_INIT);         // __WHEREAMI__ zurücksetzen und auf den nächsten Tick warten
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
      else if (prev_error == ERS_HISTORY_UPDATE        ) ValidBars = 0;
      else if (prev_error == ERR_HISTORY_INSUFFICIENT  ) ValidBars = 0;
      if      (__STATUS_HISTORY_UPDATE                 ) ValidBars = 0;             // *_HISTORY_UPDATE und *_HISTORY_INSUFFICIENT können je nach Kontext Fehler und/oder Status sein.
      if      (__STATUS_HISTORY_INSUFFICIENT           ) ValidBars = 0;
   }
   if (!ValidBars) ShiftedBars = 0;
   ChangedBars = Bars - ValidBars;                                                  // ChangedBars aktualisieren (ValidBars wurde evt. neu gesetzt)


   /*
   // (6) Werden Zeichenpuffer verwendet, muß in onTick() deren Initialisierung überprüft werden.
   if (ArraySize(buffer) == 0)
      return(SetLastError(ERS_TERMINAL_NOT_YET_READY));                             // kann bei Terminal-Start auftreten
   */

   __STATUS_HISTORY_UPDATE       = false;
   __STATUS_HISTORY_INSUFFICIENT = false;

   if (!ratesCopied && Bars) {
      ArrayCopyRates(rates);
      ratesCopied = true;
   }

   if (SyncMainContext_start(__ExecutionContext, rates, Bars, Tick, Tick.Time, Bid, Ask) != NO_ERROR) {
      if (CheckErrors("start(8)")) return(last_error);
   }


   // (7) stdLib benachrichtigen
   if (_lib1.start(Tick, Tick.Time, ValidBars, ChangedBars) != NO_ERROR)
      if (CheckErrors("start(9)")) return(last_error);


   // (8) bei Bedarf Input-Dialog aufrufen
   if (__STATUS_RELAUNCH_INPUT) {
      __STATUS_RELAUNCH_INPUT = false;
      return(_last_error(start.RelaunchInputDialog(), CheckErrors("start(10)")));
   }


   // (9) Main-Funktion aufrufen
   onTick();


   // (10) check errors
   error = GetLastError();
   if (error || last_error|__ExecutionContext[I_EXECUTION_CONTEXT.mqlError]|__ExecutionContext[I_EXECUTION_CONTEXT.dllError])
      CheckErrors("start(11)", error);
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
   __WHEREAMI__ = RF_DEINIT;

   if (!IsDllsAllowed() || !IsLibrariesAllowed())
      return(last_error);

   if (InitReason() == INITREASON_PROGRAM_AFTERTEST)
      return(last_error|LeaveContext(__ExecutionContext));

   int error = SyncMainContext_deinit(__ExecutionContext, UninitializeReason());
   if (IsError(error)) return(error|last_error|LeaveContext(__ExecutionContext));


   // User-Routinen *können*, müssen aber nicht implementiert werden.
   //
   // Die User-Routinen werden ausgeführt, wenn der Preprocessing-Hook (falls implementiert) ohne Fehler zurückkehrt.
   // Der Postprocessing-Hook wird ausgeführt, wenn weder der Preprocessing-Hook (falls implementiert) noch die User-Routinen
   // (falls implementiert) -1 zurückgeben.


   // (1) User-spezifische deinit()-Routinen aufrufen                            //
   error = onDeinit();                                                           // Preprocessing-Hook
                                                                                 //
   if (!error) {                                                                 //
      switch (UninitializeReason()) {                                            //
         case UR_PARAMETERS : error = onDeinitParameterChange(); break;          //
         case UR_CHARTCHANGE: error = onDeinitChartChange();     break;          //
         case UR_ACCOUNT    : error = onDeinitAccountChange();   break;          //
         case UR_CHARTCLOSE : error = onDeinitChartClose();      break;          //
         case UR_UNDEFINED  : error = onDeinitUndefined();       break;          //
         case UR_REMOVE     : error = onDeinitRemove();          break;          //
         case UR_RECOMPILE  : error = onDeinitRecompile();       break;          //
         // build > 509                                                          //
         case UR_TEMPLATE   : error = onDeinitTemplate();        break;          //
         case UR_INITFAILED : error = onDeinitFailed();          break;          //
         case UR_CLOSE      : error = onDeinitClose();           break;          //
                                                                                 //
         default:                                                                //
            CheckErrors("deinit(1)  unknown UninitializeReason = "+ UninitializeReason(), ERR_RUNTIME_ERROR);
            return(last_error|LeaveContext(__ExecutionContext));                 //
      }                                                                          //
   }                                                                             //
   if (error != -1)                                                              //
      error = afterDeinit();                                                     // Postprocessing-Hook


   // (2) User-spezifische Deinit-Tasks ausführen
   if (!error) {
      // ...
   }


   CheckErrors("deinit(2)");
   return(last_error|LeaveContext(__ExecutionContext));                          // the very last statement
}


/**
 * Whether or not the current program is an expert.
 *
 * @return bool
 */
bool IsExpert() {
   return(false);
}


/**
 * Whether or not the current program is a script.
 *
 * @return bool
 */
bool IsScript() {
   return(false);
}


/**
 * Whether or not the current program is an indicator.
 *
 * @return bool
 */
bool IsIndicator() {
   return(true);
}


/**
 * Whether or not the current module is a library.
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
 * Update the indicator's EXECUTION_CONTEXT.
 *
 * @return bool - success status
 *
 *
 * Note: In Indikatoren liegt der EXECUTION_CONTEXT des Hauptmoduls nach jedem init-Cycle an einer neuen Adresse.
 */
bool UpdateGlobalVars() {
   // (1) Gibt es einen SuperContext, sind bereits alle Werte gesetzt
   if (!__lpSuperContext) {
      ec_SetLogging(__ExecutionContext, IsLogging());                         // TODO: implement in DLL
   }

   // (2) Globale Variablen aktualisieren.
   __NAME__     = WindowExpertName();
   __CHART      =              _bool(ec_hChart       (__ExecutionContext));
   __LOG        =                    ec_Logging      (__ExecutionContext);
   __LOG_CUSTOM = __LOG && StringLen(ec_CustomLogFile(__ExecutionContext));


   // (3) restliche globale Variablen initialisieren
   //
   // Bug 1: Die Variablen Digits und Point sind in init() beim Öffnen eines neuen Charts und beim Accountwechsel u.U. falsch gesetzt.
   //        Nur ein Reload des Templates korrigiert die falschen Werte.
   //
   // Bug 2: Die Variablen Digits und Point sind in Offline-Charts ab Terminalversion ??? permanent auf 5 und 0.00001 gesetzt.
   //
   // Bug 3: Die Variablen Digits und Point können vom Broker u.U. falsch gesetzt worden sein (z.B. S&P500 bei Forex Ltd).
   //
   PipDigits      = Digits & (~1);                                        SubPipDigits      = PipDigits+1;
   PipPoints      = MathRound(MathPow(10, Digits & 1));                   PipPoint          = PipPoints;
   Pips           = NormalizeDouble(1/MathPow(10, PipDigits), PipDigits); Pip               = Pips;
   PipPriceFormat = StringConcatenate(".", PipDigits);                    SubPipPriceFormat = StringConcatenate(PipPriceFormat, "'");
   PriceFormat    = ifString(Digits==PipDigits, PipPriceFormat, SubPipPriceFormat);

   N_INF = MathLog(0);
   P_INF = -N_INF;
   NaN   =  N_INF - N_INF;

   return(!CheckErrors("UpdateGlobalVars(1)"));
}


/**
 * Check and update the program's error status and activate the flag __STATUS_OFF accordingly.
 *
 * @param  string location - location of the check
 * @param  int    setError - error to enforce
 *
 * @return bool - whether or not the flag __STATUS_OFF is set
 */
bool CheckErrors(string location, int setError = NULL) {
   // (1) check and signal DLL errors
   int dll_error = __ExecutionContext[I_EXECUTION_CONTEXT.dllError]; // TODO: signal DLL errors
   if (dll_error && 1) {
      __STATUS_OFF        = true;                                    // all DLL errors are terminating errors
      __STATUS_OFF.reason = dll_error;
   }


   // (2) check MQL errors
   int mql_error = __ExecutionContext[I_EXECUTION_CONTEXT.mqlError];
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
 * Prüft, ob seit dem letzten Aufruf ein ChartCommand für diesen Indikator eingetroffen ist.
 *
 * @param  string commands[] - Array zur Aufnahme der eingetroffenen Commands
 *
 * @return bool - Ergebnis
 */
bool EventListener.ChartCommand(string &commands[]) {
   if (!__CHART) return(false);

   static string label, mutex; if (!StringLen(label)) {
      label = __NAME__ +".command";
      mutex = "mutex."+ label;
   }

   // (1) zuerst nur Lesezugriff (unsynchronisiert möglich), um nicht bei jedem Tick das Lock erwerben zu müssen
   if (ObjectFind(label) == 0) {

      // (2) erst, wenn ein Command eingetroffen ist, Lock für Schreibzugriff holen
      if (!AquireLock(mutex, true)) return(false);

      // (3) Command auslesen und Command-Object löschen
      ArrayResize(commands, 1);
      commands[0] = ObjectDescription(label);
      ObjectDelete(label);

      // (4) Lock wieder freigeben
      if (!ReleaseLock(mutex)) return(false);

      return(!catch("EventListener.ChartCommand(1)"));
   }
   return(false);
}


// --------------------------------------------------------------------------------------------------------------------------------------------------


#import "rsfLib1.ex4"
   int    _lib1.init (int tickData[]);
   int    _lib1.start(int tick, datetime tickTime, int validBars, int changedBars);

   int    onDeinitAccountChange();
   int    onDeinitChartChange();
   int    onDeinitChartClose();
   int    onDeinitParameterChange();
   int    onDeinitRecompile();
   int    onDeinitRemove();
   int    onDeinitUndefined();
   // build > 509
   int    onDeinitTemplate();
   int    onDeinitFailed();
   int    onDeinitClose();

   string InputsToStr();

   bool   AquireLock(string mutexName, bool wait);
   bool   ReleaseLock(string mutexName);

#import "rsfExpander.dll"
   string ec_CustomLogFile  (/*EXECUTION_CONTEXT*/int ec[]);
   int    ec_InitFlags      (/*EXECUTION_CONTEXT*/int ec[]);
   int    ec_lpSuperContext (/*EXECUTION_CONTEXT*/int ec[]);
   bool   ec_Logging        (/*EXECUTION_CONTEXT*/int ec[]);

   int    ec_SetDllError    (/*EXECUTION_CONTEXT*/int ec[], int error       );
   bool   ec_SetLogging     (/*EXECUTION_CONTEXT*/int ec[], int status      );
   int    ec_SetRootFunction(/*EXECUTION_CONTEXT*/int ec[], int rootFunction);

   bool   ShiftIndicatorBuffer(double buffer[], int bufferSize, int bars, double emptyValue);

   int    SyncMainContext_init  (int ec[], int programType, string programName, int unintReason, int initFlags, int deinitFlags, string symbol, int period, int digits, double point, int extReporting, int recordEquity, int isTesting, int isVisualMode, int isOptimization, int lpSec, int hChart, int droppedOnChart, int droppedOnPosX, int droppedOnPosY);
   int    SyncMainContext_start (int ec[], double rates[][], int bars, int ticks, datetime time, double bid, double ask);
   int    SyncMainContext_deinit(int ec[], int unintReason);
#import


// -- init()-Templates ------------------------------------------------------------------------------------------------------


/**
 * Initialisierung Preprocessing-Hook
 *
 * @return int - error status
 *
int onInit() {
   return(NO_ERROR);
}


/**
 * Nach manuellem Laden des Indikators durch den User. Input-Dialog.
 *
 * @return int - error status
 *
int onInit_User() {
   return(NO_ERROR);
}


/**
 * Nach Laden des Indikators innerhalb eines Templates, auch bei Terminal-Start und im Tester bei VisualMode=On|Off. Bei
 * VisualMode=Off werden bei jedem Teststart init() und deinit() der Indikatoren in Tester.tpl aufgerufen, nicht jedoch deren
 * start()-Funktion. Kein Input-Dialog.
 *
 * @return int - error status
 *
int onInit_Template() {
   return(NO_ERROR);
}


/**
 * Nach Laden des Indikators mittels iCustom(). Kein Input-Dialog.
 *
 * @return int - error status
 *
int onInit_Program() {
   return(NO_ERROR);
}


/**
 * Nach Testende bei Laden des Indikators mittels iCustom(). Der SuperContext des Indikators ist bei diesem Aufruf bereits
 * nicht mehr gültig. Kein Input-Dialog.
 *
 * @return int - error status
 *
int onInit_ProgramAfterTest() {
   return(NO_ERROR);
}


/**
 * Nach manueller Änderung der Indikatorparameter. Input-Dialog.
 *
 * @return int - error status
 *
int onInit_Parameters() {
   return(NO_ERROR);
}


/**
 * Nach Änderung der aktuellen Chartperiode. Kein Input-Dialog.
 *
 * @return int - error status
 *
int onInit_TimeframeChange() {
   return(NO_ERROR);
}


/**
 * Nach Änderung des aktuellen Chartsymbols. Kein Input-Dialog.
 *
 * @return int - error status
 *
int onInit_SymbolChange() {
   return(NO_ERROR);
}


/**
 * Called at reload after recompilation. Indicators are not automatically reloded if the terminal is disconnected.
 * No input dialog.
 *
 * @return int - error status
 *
int onInit_Recompile() {
   return(NO_ERROR);
}


/**
 * Initialisierung Postprocessing-Hook
 *
 * @return int - error status
 *
int afterInit() {
   return(NO_ERROR);
}


// -- deinit()-Templates ----------------------------------------------------------------------------------------------------


/**
 * Deinitialisierung Preprocessing
 *
 * @return int - Fehlerstatus
 *
int onDeinit() {
   return(NO_ERROR);
}


/**
 * außerhalb iCustom(): vor Parameteränderung
 * innerhalb iCustom(): nie
 *
 * @return int - Fehlerstatus
 *
int onDeinitParameterChange() {
   return(NO_ERROR);
}


/**
 * außerhalb iCustom(): vor Symbol- oder Timeframewechsel
 * innerhalb iCustom(): nie
 *
 * @return int - Fehlerstatus
 *
int onDeinitChartChange() {
   return(NO_ERROR);
}


/**
 * außerhalb iCustom(): ???
 * innerhalb iCustom(): ???
 *
 * @return int - Fehlerstatus
 *
int onDeinitAccountChange() {
   return(NO_ERROR);
}


/**
 * außerhalb iCustom(): ???
 * innerhalb iCustom(): ???
 *
 * @return int - Fehlerstatus
 *
int onDeinitChartClose() {
   return(NO_ERROR);
}


/**
 * außerhalb iCustom(): ???
 * innerhalb iCustom(): ???
 *
 * @return int - Fehlerstatus
 *
int onDeinitUndefined() {
   return(NO_ERROR);
}


/**
 * außerhalb iCustom(): Indikator von Hand entfernt oder Chart geschlossen, auch vorm Laden eines Profils oder Templates
 * innerhalb iCustom(): in allen deinit()-Fällen
 *
 * @return int - Fehlerstatus
 *
int onDeinitRemove() {
   return(NO_ERROR);
}


/**
 * Called before recompilation.
 *
 * @return int - error status
 *
int onDeinitRecompile() {
   return(NO_ERROR);
}


/**
 * Deinitialisierung Postprocessing
 *
 * @return int - Fehlerstatus
 *
int afterDeinit() {
   return(NO_ERROR);
}
*/
