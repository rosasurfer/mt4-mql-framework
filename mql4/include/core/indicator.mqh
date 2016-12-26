
#define __TYPE__       MT_INDICATOR
int     __WHEREAMI__ = NULL;                                         // current MQL RootFunction: RF_INIT | RF_START | RF_DEINIT

extern string ___________________________;
extern int    __lpSuperContext;


/**
 * Globale init()-Funktion für Indikatoren.
 *
 * @return int - Fehlerstatus
 *
 * @throws ERS_TERMINAL_NOT_YET_READY
 */
int init() {
   if (__STATUS_OFF)
      return(last_error);

   if (__WHEREAMI__ == NULL)                                         // init() called by the terminal, all variables are reset
      __WHEREAMI__ = RF_INIT;

   int hChart = NULL; if (!IsTesting() || IsVisualMode())            // Under test WindowHandle() triggers ERR_FUNC_NOT_ALLOWED_IN_TESTER
       hChart = WindowHandle(Symbol(), NULL);                        // if VisualMode=Off.


   // (1) ExecutionContext initialisieren
   SyncMainContext_init(__ExecutionContext, __TYPE__, WindowExpertName(), UninitializeReason(), SumInts(__INIT_FLAGS__), SumInts(__DEINIT_FLAGS__), Symbol(), Period(), __lpSuperContext, IsTesting(), IsVisualMode(), IsOptimization(), hChart, WindowOnDropped());
   __lpSuperContext = ec_lpSuperContext(__ExecutionContext);

   if (ec_InitReason(__ExecutionContext) == INIT_REASON_PROGRAM_AFTERTEST) {
      __STATUS_OFF        = true;
      __STATUS_OFF.reason = last_error;
      return(last_error);
   }


   // (2) Initialisierung abschließen
   if (!UpdateExecutionContext()) { UpdateProgramStatus(); if (__STATUS_OFF) return(last_error); }


   // (3) stdlib initialisieren
   int tickData[3];
   int error = stdlib.init(tickData);
   if (IsError(error)) {
      UpdateProgramStatus(SetLastError(error));
      if (__STATUS_OFF) return(last_error);
   }


   Tick          = tickData[0];
   Tick.Time     = tickData[1];
   Tick.prevTime = tickData[2];


   // (4) bei Aufruf durch iCustom() Input-Parameter loggen
   if (__LOG) /*&&*/ if (IsSuperContext())
      log(InputsToStr());


   // (5) user-spezifische Init-Tasks ausführen
   int initFlags = ec_InitFlags(__ExecutionContext);

   if (initFlags & INIT_PIPVALUE && 1) {
      TickSize = MarketInfo(Symbol(), MODE_TICKSIZE);                      // schlägt fehl, wenn kein Tick vorhanden ist
      error = GetLastError();
      if (IsError(error)) {                                                // - Symbol nicht subscribed (Start, Account-/Templatewechsel), Symbol kann noch "auftauchen"
         if (error == ERR_SYMBOL_NOT_AVAILABLE)                            // - synthetisches Symbol im Offline-Chart
                      return(UpdateProgramStatus(debug("init(1)  MarketInfo() => ERR_SYMBOL_NOT_AVAILABLE", SetLastError(ERS_TERMINAL_NOT_YET_READY))));
         UpdateProgramStatus(catch("init(2)", error)); if (__STATUS_OFF) return(last_error);
      }
      if (!TickSize)  return(UpdateProgramStatus(debug("init(3)  MarketInfo(MODE_TICKSIZE) = 0", SetLastError(ERS_TERMINAL_NOT_YET_READY))));

      double tickValue = MarketInfo(Symbol(), MODE_TICKVALUE);
      error = GetLastError();
      if (IsError(error)) {
         UpdateProgramStatus(catch("init(5)", error)); if (__STATUS_OFF) return(last_error);
      }
      if (!tickValue) return(UpdateProgramStatus(debug("init(6)  MarketInfo(MODE_TICKVALUE) = 0", SetLastError(ERS_TERMINAL_NOT_YET_READY))));
   }
   if (initFlags & INIT_BARS_ON_HIST_UPDATE && 1) {}                       // noch nicht implementiert


   /*
   (6) User-spezifische init()-Routinen aufrufen. Diese können, müssen aber nicht implementiert sein.

   Die vom Terminal bereitgestellten UninitializeReason-Codes und ihre Bedeutung ändern sich in den einzelnen Terminalversionen
   und sind zur eindeutigen Unterscheidung der verschiedenen Init-Szenarien nicht geeignet.
   Solution: Funktion ec_InitReason() und die neu eingeführten Variablen INIT_REASON_*.

   Init-Szenario                   User-Routine                Beschreibung
   -------------                   ------------                ------------
   INIT_REASON_USER              - onInit_User()             - bei Laden durch den User                               -      Input-Dialog
   INIT_REASON_TEMPLATE          - onInit_Template()         - bei Laden durch ein Template (auch bei Terminal-Start) - kein Input-Dialog
   INIT_REASON_PROGRAM           - onInit_Program()          - bei Laden durch iCustom()                              - kein Input-Dialog
   INIT_REASON_PROGRAM_AFTERTEST - onInit_ProgramAfterTest() - bei Laden durch iCustom() nach Testende                - kein Input-Dialog
   INIT_REASON_PARAMETERS        - onInit_Parameters()       - nach Änderung der Indikatorparameter                   -      Input-Dialog
   INIT_REASON_TIMEFRAMECHANGE   - onInit_TimeframeChange()  - nach Timeframewechsel des Charts                       - kein Input-Dialog
   INIT_REASON_SYMBOLCHANGE      - onInit_SymbolChange()     - nach Symbolwechsel des Charts                          - kein Input-Dialog
   INIT_REASON_RECOMPILE         - onInit_Recompile()        - bei Reload nach Recompilation                          - kein Input-Dialog

   Die User-Routinen werden ausgeführt, wenn der Preprocessing-Hook (falls implementiert) ohne Fehler zurückkehrt.
   Der Postprocessing-Hook wird ausgeführt, wenn weder der Preprocessing-Hook (falls implementiert) noch die User-Routinen
   (falls implementiert) -1 zurückgeben.
   */
   error = onInit();                                                                                              // Preprocessing-Hook
   if (!error) {                                                                                                  //
      int initReason = ec_InitReason(__ExecutionContext);                                                         //
      if (!initReason) { UpdateProgramStatus(); if (__STATUS_OFF) return(last_error); }                           //
                                                                                                                  //
      switch (initReason) {                                                                                       //
         case INIT_REASON_USER             : error = onInit_User();             break;                            //
         case INIT_REASON_TEMPLATE         : error = onInit_Template();         break;                            // TODO: in neuem Chartfenster falsche Werte für Point und Digits
         case INIT_REASON_PROGRAM          : error = onInit_Program();          break;                            //
         case INIT_REASON_PROGRAM_AFTERTEST: error = onInit_ProgramAfterTest(); break;                            //
         case INIT_REASON_PARAMETERS       : error = onInit_Parameters();       break;                            //
         case INIT_REASON_TIMEFRAMECHANGE  : error = onInit_TimeframeChange();  break;                            //
         case INIT_REASON_SYMBOLCHANGE     : error = onInit_SymbolChange();     break;                            //
         case INIT_REASON_RECOMPILE        : error = onInit_Recompile();        break;                            //
         default:                                                                                                 //
            return(UpdateProgramStatus(catch("init(7)  unknown initReason = "+ initReason, ERR_RUNTIME_ERROR)));  //
      }                                                                                                           //
   }                                                                                                              //
   if (IsError(error)) SetLastError(error);                                                                       //
   if (error == ERS_TERMINAL_NOT_YET_READY) return(error);                                                        //
   UpdateProgramStatus();                                                                                         //
                                                                                                                  //
   if (error != -1) {                                                                                             //
      error = afterInit();                                                                                        // Postprocessing-Hook
      if (IsError(error)) SetLastError(error);                                                                    //
      UpdateProgramStatus();                                                                                      //
   }                                                                                                              //
   if (__STATUS_OFF) return(last_error);                                                                          //


   // (7) nach Parameteränderung im "Indicators List"-Window nicht auf den nächsten Tick warten
   if (initReason == INIT_REASON_PARAMETERS) {
      error = Chart.SendTick();                                      // TODO: !!! Nur bei Existenz des "Indicators List"-Windows (nicht bei einzelnem Indikator)
      if (IsError(error)) {
         UpdateProgramStatus(SetLastError(error)); if (__STATUS_OFF) return(last_error);
      }
   }

   UpdateProgramStatus(catch("init(8)"));
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
      if (ec_InitReason(__ExecutionContext) == INIT_REASON_PROGRAM_AFTERTEST)
         return(last_error);
      string msg = WindowExpertName() +": switched off ("+ ifString(!__STATUS_OFF.reason, "unknown reason", ErrorToStr(__STATUS_OFF.reason)) +")";
      Comment(NL + NL + NL + msg);                                                  // 3 Zeilen Abstand für Instrumentanzeige und ggf. vorhandene Legende
      return(last_error);
   }

   Tick++; zTick++;                                                                 // einfache Zähler, die konkreten Werte haben keine Bedeutung
   Tick.prevTime = Tick.Time;
   Tick.Time     = MarketInfo(Symbol(), MODE_TIME);                                 // TODO: !!! MODE_TIME ist im synthetischen Chart NULL               !!!
                                                                                    // TODO: !!! MODE_TIME und TimeCurrent() sind im Tester-Chart falsch !!!
   if (!Tick.Time) {
      int error = GetLastError();
      if (error!=NO_ERROR) /*&&*/ if (error!=ERR_SYMBOL_NOT_AVAILABLE) {            // ERR_SYMBOL_NOT_AVAILABLE vorerst ignorieren, da ein Offline-Chart beim ersten Tick
         UpdateProgramStatus(catch("start(1)", error));                             // nicht sicher detektiert werden kann
         if (__STATUS_OFF) return(last_error);
      }
   }


   // (1) Valid- und ChangedBars berechnen: die Originalwerte werden in (4) und (5) ggf. neu definiert
   ValidBars   = IndicatorCounted();
   ChangedBars = Bars - ValidBars;
   ShiftedBars = 0;


   // (2) Abschluß der Chart-Initialisierung überprüfen (Bars=0 kann bei Terminal-Start auftreten)
   if (!Bars) return(UpdateProgramStatus(SetLastError(debug("start(2)  Bars = 0", ERS_TERMINAL_NOT_YET_READY))));


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
               if (i == Bars) return(UpdateProgramStatus(catch("start(3)  Bar[last.startBarOpenTime]="+ TimeToStr(last.startBarOpenTime, TIME_FULL) +" not found", ERR_RUNTIME_ERROR)));
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
               if (i == Bars) return(UpdateProgramStatus(catch("start(4)  Bar[last.startBarOpenTime]="+ TimeToStr(last.startBarOpenTime, TIME_FULL) +" not found", ERR_RUNTIME_ERROR)));
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
                  if (i == Bars) return(UpdateProgramStatus(catch("start(5)  Bar[last.startBarOpenTime]="+ TimeToStr(last.startBarOpenTime, TIME_FULL) +" not found", ERR_RUNTIME_ERROR)));
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
      __WHEREAMI__ = ec_SetRootFunction(__ExecutionContext, RF_START);              // __STATUS_OFF ist false: evt. ist jedoch ein Status gesetzt, siehe UpdateProgramStatus()

      if (last_error == ERS_TERMINAL_NOT_YET_READY) {                               // alle anderen Stati brauchen zur Zeit keine eigene Behandlung
         debug("start(6)  init() returned ERS_TERMINAL_NOT_YET_READY, retrying...");
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
      SetLastError(NO_ERROR);
      ec_SetDllError(__ExecutionContext, NO_ERROR);

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


   SyncMainContext_start(__ExecutionContext);


   // (7) stdLib benachrichtigen
   if (stdlib.start(__ExecutionContext, Tick, Tick.Time, ValidBars, ChangedBars) != NO_ERROR) {
      UpdateProgramStatus(SetLastError(stdlib.GetLastError()));
      if (__STATUS_OFF) return(last_error);
   }


   // (8) bei Bedarf Input-Dialog aufrufen
   if (__STATUS_RELAUNCH_INPUT) {
      __STATUS_RELAUNCH_INPUT = false;
      return(UpdateProgramStatus(start.RelaunchInputDialog()));
   }


   // (9) Main-Funktion aufrufen
   onTick();


   // (10) Fehler-Status auswerten
   error = ec_DllError(__ExecutionContext);
   if (error != NO_ERROR) catch("start(7)  DLL error", error);
   else if (!last_error) {
      error = ec_MqlError(__ExecutionContext);
      if (error != NO_ERROR) last_error = error;
   }
   error = GetLastError();
   if (error != NO_ERROR) catch("start(8)", error);

   if      (last_error == ERS_HISTORY_UPDATE      ) __STATUS_HISTORY_UPDATE       = true;
   else if (last_error == ERR_HISTORY_INSUFFICIENT) __STATUS_HISTORY_INSUFFICIENT = true;

   return(UpdateProgramStatus(last_error));
}


/**
 * Globale deinit()-Funktion für Indikatoren.
 *
 * @return int - Fehlerstatus
 */
int deinit() {
   __WHEREAMI__ = RF_DEINIT;
   if (ec_InitReason(__ExecutionContext) == INIT_REASON_PROGRAM_AFTERTEST) {
      LeaveContext(__ExecutionContext);
      return(last_error);
   }
   SyncMainContext_deinit(__ExecutionContext, UninitializeReason());


   // User-Routinen *können*, müssen aber nicht implementiert werden.
   //
   // Die User-Routinen werden ausgeführt, wenn der Preprocessing-Hook (falls implementiert) ohne Fehler zurückkehrt.
   // Der Postprocessing-Hook wird ausgeführt, wenn weder der Preprocessing-Hook (falls implementiert) noch die User-Routinen
   // (falls implementiert) -1 zurückgeben.


   // (1) User-spezifische deinit()-Routinen aufrufen                            //
   int error = onDeinit();                                                       // Preprocessing-Hook
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
            UpdateProgramStatus(catch("deinit(1)  unknown UninitializeReason = "+ UninitializeReason(), ERR_RUNTIME_ERROR));
            LeaveContext(__ExecutionContext);                                    //
            return(last_error);                                                  //
      }                                                                          //
   }                                                                             //
   if (IsError(error)) SetLastError(error);                                      //
   UpdateProgramStatus();                                                        //
                                                                                 //
   if (error != -1) {                                                            //
      error = afterDeinit();                                                     // Postprocessing-Hook
      if (IsError(error)) SetLastError(error);                                   //
      UpdateProgramStatus();
   }


   // (2) User-spezifische Deinit-Tasks ausführen
   if (!error) {
      // ...
   }


   // (3) stdlib deinitialisieren und Context speichern
   error = stdlib.deinit(__ExecutionContext);
   if (IsError(error))
      SetLastError(error);

   UpdateProgramStatus(catch("deinit(2)"));
   LeaveContext(__ExecutionContext);
   return(last_error); __DummyCalls();
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
bool UpdateExecutionContext() {
   // (1) Gibt es einen SuperContext, sind bereits alle Werte gesetzt
   if (!__lpSuperContext) {
      ec_SetLogging(__ExecutionContext, IsLogging());                         // TODO: implement in DLL
   }


   // (2) Globale Variablen aktualisieren.
   __NAME__     = WindowExpertName();
   __CHART      =              _bool(ec_hChart (__ExecutionContext));
   __LOG        =                    ec_Logging(__ExecutionContext);
   __LOG_CUSTOM = __LOG && StringLen(ec_LogFile(__ExecutionContext));


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
   Pip            = NormalizeDouble(1/MathPow(10, PipDigits), PipDigits); Pips              = Pip;
   PipPriceFormat = StringConcatenate(".", PipDigits);                    SubPipPriceFormat = StringConcatenate(PipPriceFormat, "'");
   PriceFormat    = ifString(Digits==PipDigits, PipPriceFormat, SubPipPriceFormat);

   N_INF = MathLog(0);
   P_INF = -N_INF;
   NaN   =  N_INF - N_INF;

   return(!catch("UpdateExecutionContext(1)"));
}


/**
 * Überprüft und aktualisiert den aktuellen Programmstatus des Indikators. Setzt je nach Kontext das Flag __STATUS_OFF.
 *
 * @param  int value - der zurückzugebende Wert (default: NULL)
 *
 * @return int - der übergebene Wert
 */
int UpdateProgramStatus(int value=NULL) {
   switch (last_error) {
      case NO_ERROR                  :
      case ERS_HISTORY_UPDATE        :
      case ERS_TERMINAL_NOT_YET_READY:
      case ERS_EXECUTION_STOPPING    : break;

      default:
         __STATUS_OFF        = true;
         __STATUS_OFF.reason = last_error;
   }
   return(value);
}


/**
 * Prüft, ob seit dem letzten Aufruf ein ChartCommand für diesen Indikator eingetroffen ist.
 *
 * @param  string commands[] - Array zur Aufnahme der eingetroffenen Commands
 * @param  int    flags      - zusätzliche eventspezifische Flags (default: keine)
 *
 * @return bool - Ergebnis
 */
bool EventListener.ChartCommand(string &commands[], int flags=NULL) {
   if (!__CHART) return(false);

   static string label, mutex; if (!StringLen(label)) {
      label = __NAME__ +".command";
      mutex = "mutex."+ label;
   }

   // (1) zuerst nur Lesezugriff (unsynchronisiert möglich), um nicht bei jedem Tick das Lock erwerben zu müssen
   if (ObjectFind(label) == 0) {

      // (2) erst, wenn ein Command eingetroffen ist, Lock für Schreibzugriff holen
      if (!AquireLock(mutex, true)) return(!SetLastError(stdlib.GetLastError()));

      // (3) Command auslesen und Command-Object löschen
      ArrayResize(commands, 1);
      commands[0] = ObjectDescription(label);
      ObjectDelete(label);

      // (4) Lock wieder freigeben
      if (!ReleaseLock(mutex)) return(!SetLastError(stdlib.GetLastError()));

      return(!catch("EventListener.ChartCommand(1)"));
   }
   return(false);
}


// --------------------------------------------------------------------------------------------------------------------------------------------------


#import "stdlib1.ex4"
   int    stdlib.init  (int tickData[]);
   int    stdlib.start (/*EXECUTION_CONTEXT*/int ec[], int tick, datetime tickTime, int validBars, int changedBars);
   int    stdlib.deinit(/*EXECUTION_CONTEXT*/int ec[]);

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

#import "Expander.dll"
   int    ec_DllError       (/*EXECUTION_CONTEXT*/int ec[]);
   int    ec_InitFlags      (/*EXECUTION_CONTEXT*/int ec[]);
   int    ec_InitReason     (/*EXECUTION_CONTEXT*/int ec[]);
   int    ec_lpSuperContext (/*EXECUTION_CONTEXT*/int ec[]);
   int    ec_MqlError       (/*EXECUTION_CONTEXT*/int ec[]);
   string ec_LogFile        (/*EXECUTION_CONTEXT*/int ec[]);
   bool   ec_Logging        (/*EXECUTION_CONTEXT*/int ec[]);

   int    ec_SetDllError    (/*EXECUTION_CONTEXT*/int ec[], int error       );
   bool   ec_SetLogging     (/*EXECUTION_CONTEXT*/int ec[], int status      );
   int    ec_SetRootFunction(/*EXECUTION_CONTEXT*/int ec[], int rootFunction);

   bool   ShiftIndicatorBuffer(double buffer[], int bufferSize, int bars, double emptyValue);

   bool   SyncMainContext_init  (int ec[], int programType, string programName, int unintReason, int initFlags, int deinitFlags, string symbol, int period, int lpSec, int isTesting, int isVisualMode, int isOptimization, int hChart, int subChartDropped);
   bool   SyncMainContext_start (int ec[]);
   bool   SyncMainContext_deinit(int ec[], int unintReason);
#import


// -- init()-Templates ------------------------------------------------------------------------------------------------------------------------------


/**
 * Initialisierung Preprocessing-Hook
 *
 * @return int - Fehlerstatus
 *
int onInit() {
   return(NO_ERROR);
}


/**
 * Nach manuellem Laden des Indikators durch den User. Input-Dialog.
 *
 * @return int - Fehlerstatus
 *
int onInit_User() {
   return(NO_ERROR);
}


/**
 * Nach Laden des Indikators innerhalb eines Templates, auch bei Terminal-Start und im Tester bei VisualMode=On|Off. Bei VisualMode=Off
 * werden bei jedem Teststart init() und deinit() der Indikatoren in Tester.tpl aufgerufen, nicht jedoch deren start()-Funktion.
 * Kein Input-Dialog.
 *
 * @return int - Fehlerstatus
 *
int onInit_Template() {
   return(NO_ERROR);
}


/**
 * Nach Laden des Indikators mittels iCustom(). Kein Input-Dialog.
 *
 * @return int - Fehlerstatus
 *
int onInit_Program() {
   return(NO_ERROR);
}


/**
 * Nach Testende bei Laden des Indikators mittels iCustom(). Der SuperContext des Indikators ist bei diesem Aufruf bereits nicht mehr gültig.
 * Kein Input-Dialog.
 *
 * @return int - Fehlerstatus
 *
int onInit_ProgramAfterTest() {
   return(NO_ERROR);
}


/**
 * Nach manueller Änderung der Indikatorparameter. Input-Dialog.
 *
 * @return int - Fehlerstatus
 *
int onInit_Parameters() {
   return(NO_ERROR);
}


/**
 * Nach Änderung der aktuellen Chartperiode. Kein Input-Dialog.
 *
 * @return int - Fehlerstatus
 *
int onInit_TimeframeChange() {
   return(NO_ERROR);
}


/**
 * Nach Änderung des aktuellen Chartsymbols. Kein Input-Dialog.
 *
 * @return int - Fehlerstatus
 *
int onInit_SymbolChange() {
   return(NO_ERROR);
}


/**
 * Bei Reload des Indikators nach Neukompilierung. Kein Input-Dialog
 *
 * @return int - Fehlerstatus
 *
int onInit_Recompile() {
   return(NO_ERROR);
}


/**
 * Initialisierung Postprocessing-Hook
 *
 * @return int - Fehlerstatus
 *
int afterInit() {
   return(NO_ERROR);
}


// -- deinit()-Templates ----------------------------------------------------------------------------------------------------------------------------


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
 * außerhalb iCustom(): bei Reload nach Recompilation
 * innerhalb iCustom(): nie
 *
 * @return int - Fehlerstatus
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
