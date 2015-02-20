
#define __TYPE__ T_INDICATOR

extern string ___________________________;
extern int    __lpSuperContext;

#include <functions/IsTesting.mqh>


/**
 * Globale init()-Funktion für Indikatoren.
 *
 * Bei Aufruf durch das Terminal wird der letzte Errorcode 'last_error' in 'prev_error' gespeichert und vor Abarbeitung
 * zurückgesetzt.
 *
 * @return int - Fehlerstatus
 *
 * @throws ERS_TERMINAL_NOT_YET_READY
 */
int init() {
   if (__STATUS_OFF)
      return(last_error);

   if (__WHEREAMI__ == NULL) {                                             // Aufruf durch Terminal, alle Variablen sind zurückgesetzt
      __WHEREAMI__ = FUNC_INIT;
      prev_error   = NO_ERROR;
      last_error   = NO_ERROR;
   }


   // (1) EXECUTION_CONTEXT initialisieren
   if (!ec.Signature(__ExecutionContext)) /*&&*/ if (!InitExecutionContext()) {
      UpdateProgramStatus();
      if (__STATUS_OFF) return(last_error);
   }
   //Expander_init(__ExecutionContext);


   // (2) eigenes WindowHandle ermitteln, damit es in deinit() auf jeden Fall verfügbar ist
   if (!WindowHandleEx(NULL)) {
      UpdateProgramStatus();
      if (__STATUS_OFF) return(last_error);
   }


   // (3) stdlib initialisieren
   int tickData[3];
   int error = stdlib.init(__ExecutionContext, tickData);
   if (IsError(error)) {
      UpdateProgramStatus(SetLastError(error));
      if (__STATUS_OFF) return(last_error);
   }


   Tick          = tickData[0];
   Tick.Time     = tickData[1];
   Tick.prevTime = tickData[2];


   // (4) bei Aufruf durch iCustom() Indikatorkonfiguration loggen
   if (__LOG) /*&&*/ if (IsSuperContext())
      log(InputsToStr());


   // (5) user-spezifische Init-Tasks ausführen
   int initFlags = ec.InitFlags(__ExecutionContext);

   if (initFlags & INIT_PIPVALUE && 1) {
      TickSize = MarketInfo(Symbol(), MODE_TICKSIZE);                      // schlägt fehl, wenn kein Tick vorhanden ist
      error = GetLastError();
      if (IsError(error)) {                                                // - Symbol nicht subscribed (Start, Account-/Templatewechsel), Symbol kann noch "auftauchen"
         if (error == ERR_UNKNOWN_SYMBOL)                                  // - synthetisches Symbol im Offline-Chart
                           return(UpdateProgramStatus(debug("init(1)  MarketInfo() => ERR_UNKNOWN_SYMBOL", SetLastError(ERS_TERMINAL_NOT_YET_READY))));
         UpdateProgramStatus(catch("init(2)", error));
         if (__STATUS_OFF) return(last_error);
      }
      if (!TickSize)       return(UpdateProgramStatus(debug("init(3)  MarketInfo(MODE_TICKSIZE) = 0", SetLastError(ERS_TERMINAL_NOT_YET_READY))));

      double tickValue = MarketInfo(Symbol(), MODE_TICKVALUE);
      error = GetLastError();
      if (IsError(error)) {
         UpdateProgramStatus(catch("init(5)", error));
         if (__STATUS_OFF) return(last_error);
      }
      if (!tickValue)      return(UpdateProgramStatus(debug("init(6)  MarketInfo(MODE_TICKVALUE) = 0", SetLastError(ERS_TERMINAL_NOT_YET_READY))));
   }
   if (initFlags & INIT_BARS_ON_HIST_UPDATE && 1) {}                       // noch nicht implementiert


   /*
   (6) User-spezifische init()-Routinen aufrufen. Diese *können*, müssen aber nicht implementiert sein.

   Die vom Terminal bereitgestellten UninitializeReasons und ihre Bedeutung ändern sich in den einzelnen Terminalversionen
   und können nicht zur eindeutigen Unterscheidung der verschiedenen Init-Szenarien verwendet werden.
   Abhilfe: Expander-Funktion InitReason() und die neueingeführten Variablen INIT_REASON_*.

   Init-Szenario                   User-Routine                Beschreibung
   -------------                   ------------                ------------
   INIT_REASON_USER              - onInit.User()             - bei Laden durch den User                               -      Input-Dialog
   INIT_REASON_TEMPLATE          - onInit.Template()         - bei Laden durch ein Template (auch bei Terminal-Start) - kein Input-Dialog
   INIT_REASON_PROGRAM           - onInit.Program()          - bei Laden durch iCustom()                              - kein Input-Dialog
   INIT_REASON_PROGRAM_CLEARTEST - onInit.ProgramClearTest() - bei Laden durch iCustom() nach Testende                - kein Input-Dialog
   INIT_REASON_PARAMETERS        - onInit.Parameters()       - nach Änderung der Indikatorparameter                   -      Input-Dialog
   INIT_REASON_TIMEFRAMECHANGE   - onInit.TimeframeChange()  - nach Timeframewechsel des Charts                       - kein Input-Dialog
   INIT_REASON_SYMBOLCHANGE      - onInit.SymbolChange()     - nach Symbolwechsel des Charts                          - kein Input-Dialog
   INIT_REASON_RECOMPILE         - onInit.Recompile()        - bei Reload nach Recompilation                          - kein Input-Dialog

   Die User-Routinen werden ausgeführt, wenn der Preprocessing-Hook (falls implementiert) ohne Fehler zurückkehrt.
   Der Postprocessing-Hook wird ausgeführt, wenn weder der Preprocessing-Hook (falls implementiert) noch die User-Routinen
   (falls implementiert) -1 zurückgeben.
   */
   error = onInit();                                                                                              // Preprocessing-Hook
                                                                                                                  //
   if (!error) {                                                                                                  //
      int initReason = InitReason();                                                                              //
      if (!initReason) { UpdateProgramStatus(); if (__STATUS_OFF) return(last_error); }                           //
                                                                                                                  //
      switch (initReason) {                                                                                       //
         case INIT_REASON_USER             : error = onInit.User();             break;                            //
         case INIT_REASON_TEMPLATE         : error = onInit.Template();         break;                            // falsche Werte für Point und Digits in neuem Chartfenster
         case INIT_REASON_PROGRAM          : error = onInit.Program();          break;                            //
         case INIT_REASON_PROGRAM_CLEARTEST: error = onInit.ProgramClearTest(); break;                            //
         case INIT_REASON_PARAMETERS       : error = onInit.Parameters();       break;                            //
         case INIT_REASON_TIMEFRAMECHANGE  : error = onInit.TimeframeChange();  break;                            //
         case INIT_REASON_SYMBOLCHANGE     : error = onInit.SymbolChange();     break;                            //
         case INIT_REASON_RECOMPILE        : error = onInit.Recompile();        break;                            //
         default:                                                                                                 //
            return(UpdateProgramStatus(catch("init(7)  unknown initReason = "+ initReason, ERR_RUNTIME_ERROR)));  //
      }                                                                                                           //
   }                                                                                                              //
   if (error == ERS_TERMINAL_NOT_YET_READY) return(error);                                                        //
   UpdateProgramStatus();                                                                                         //
                                                                                                                  //
   if (error != -1) {                                                                                             //
      afterInit();                                                                                                // Postprocessing-Hook
      UpdateProgramStatus();                                                                                      //
   }                                                                                                              //
   if (__STATUS_OFF) return(last_error);                                                                          //


   // (7) nach Parameteränderung im "Indicators List"-Window nicht auf den nächsten Tick warten
   if (initReason == INIT_REASON_PARAMETERS) {
      error = Chart.SendTick(false);                                    // TODO: !!! Nur bei Existenz des "Indicators List"-Windows (nicht bei einzelnem Indikator)
      if (IsError(error)) {
         UpdateProgramStatus(SetLastError(error));
         if (__STATUS_OFF) return(last_error);
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
      string msg = WindowExpertName() +": switched off ("+ ifString(!__STATUS_OFF.reason, "unknown reason", ErrorToStr(__STATUS_OFF.reason)) +")";
      Comment(NL + NL + NL + msg);                                         // 3 Zeilen Abstand für Instrumentanzeige und ggf. vorhandene Legende
      return(last_error);
   }

   Tick++;                                                                 // einfacher Zähler, der konkrete Wert hat keine Bedeutung
   Tick.prevTime = Tick.Time;
   Tick.Time     = MarketInfo(Symbol(), MODE_TIME);                        // TODO: !!! MODE_TIME und TimeCurrent() sind im Tester-Chart immer falsch !!!
   ValidBars     = IndicatorCounted();

   if (!Tick.Time) {
      int error = GetLastError();
      if (error!=NO_ERROR) /*&&*/ if (error!=ERR_UNKNOWN_SYMBOL) {         // ERR_UNKNOWN_SYMBOL vorerst ignorieren, da ein Offline-Chart beim ersten Tick
         UpdateProgramStatus(catch("start(1)", error));                    // nicht sicher detektiert werden kann
         if (__STATUS_OFF) return(last_error);
      }
   }


   // (1) Falls wir aus init() kommen, dessen Ergebnis prüfen
   if (__WHEREAMI__ == FUNC_INIT) {
      __WHEREAMI__ = ec.setWhereami(__ExecutionContext, FUNC_START);       // __STATUS_OFF ist false: evt. ist jedoch ein Status gesetzt, siehe UpdateProgramStatus()

      if (last_error == ERS_TERMINAL_NOT_YET_READY) {                      // alle anderen Stati brauchen zur Zeit keine eigene Behandlung
         debug("start(2)  init() returned ERS_TERMINAL_NOT_YET_READY, retrying...");
         last_error = NO_ERROR;

         error = init();                                                   // init() erneut aufrufen
         if (__STATUS_OFF) return(last_error);

         if (error == ERS_TERMINAL_NOT_YET_READY) {                        // wenn überhaupt, kann wieder nur ein Status gesetzt sein
            __WHEREAMI__ = ec.setWhereami(__ExecutionContext, FUNC_INIT);  // __WHEREAMI__ zurücksetzen und auf den nächsten Tick warten
            return(error);
         }
      }
      last_error = NO_ERROR;                                               // init() war erfolgreich
      ValidBars  = 0;
   }
   else {
      // normaler Tick
      prev_error = last_error;
      SetLastError(NO_ERROR);

      if      (prev_error == ERS_TERMINAL_NOT_YET_READY) ValidBars = 0;
      else if (prev_error == ERS_HISTORY_UPDATE        ) ValidBars = 0;
      else if (prev_error == ERR_HISTORY_INSUFFICIENT  ) ValidBars = 0;
      if      (__STATUS_HISTORY_UPDATE                 ) ValidBars = 0;    // *_HISTORY_UPDATE und *_HISTORY_INSUFFICIENT können je nach Kontext Fehler und/oder Status sein.
      if      (__STATUS_HISTORY_INSUFFICIENT           ) ValidBars = 0;
   }


   // (2) Abschluß der Chart-Initialisierung überprüfen (kann bei Terminal-Start auftreten)
   if (!Bars)
      return(UpdateProgramStatus(SetLastError(debug("start(3)  Bars = 0", ERS_TERMINAL_NOT_YET_READY))));

   /*
   // (3) Werden Zeichenpuffer verwendet, muß in onTick() deren Initialisierung überprüft werden.
   if (ArraySize(buffer) == 0)
      return(SetLastError(ERS_TERMINAL_NOT_YET_READY));                    // kann bei Terminal-Start auftreten
   */

   __STATUS_HISTORY_UPDATE       = false;
   __STATUS_HISTORY_INSUFFICIENT = false;


   // (4) ChangedBars berechnen
   ChangedBars = Bars - ValidBars;


   //Expander_start(__ExecutionContext);


   // (5) stdLib benachrichtigen
   if (stdlib.start(__ExecutionContext, Tick, Tick.Time, ValidBars, ChangedBars) != NO_ERROR) {
      UpdateProgramStatus(SetLastError(stdlib.GetLastError()));
      if (__STATUS_OFF) return(last_error);
   }


   // (6) bei Bedarf Input-Dialog aufrufen
   if (__STATUS_RELAUNCH_INPUT) {
      __STATUS_RELAUNCH_INPUT = false;
      return(UpdateProgramStatus(start.RelaunchInputDialog()));
   }


   // (7) Main-Funktion aufrufen und auswerten
   onTick();

   error = GetLastError();
   if (error != NO_ERROR)
      catch("start(4)", error);

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
   __WHEREAMI__ =                               FUNC_DEINIT;
   ec.setWhereami          (__ExecutionContext, FUNC_DEINIT         );
   ec.setUninitializeReason(__ExecutionContext, UninitializeReason());
   Init.StoreSymbol(Symbol());                                                   // TODO: aktuelles Symbol im ExecutionContext speichern


   //Expander_deinit(__ExecutionContext);


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
         case REASON_PARAMETERS : error = onDeinitParameterChange(); break;      //
         case REASON_CHARTCHANGE: error = onDeinitChartChange();     break;      //
         case REASON_ACCOUNT    : error = onDeinitAccountChange();   break;      //
         case REASON_CHARTCLOSE : error = onDeinitChartClose();      break;      //
         case REASON_UNDEFINED  : error = onDeinitUndefined();       break;      //
         case REASON_REMOVE     : error = onDeinitRemove();          break;      //
         case REASON_RECOMPILE  : error = onDeinitRecompile();       break;      //
         // build > 509                                                          //
         case REASON_TEMPLATE   : error = onDeinitTemplate();        break;      //
         case REASON_INITFAILED : error = onDeinitFailed();          break;      //
         case REASON_CLOSE      : error = onDeinitClose();           break;      //
                                                                                 //
         default: return(UpdateProgramStatus(catch("deinit(1)  unknown UninitializeReason = "+ UninitializeReason(), ERR_RUNTIME_ERROR)));
      }                                                                          //
   }                                                                             //
   UpdateProgramStatus();                                                        //
                                                                                 //
   if (error != -1) {                                                            //
      error = afterDeinit();                                                     // Postprocessing-Hook
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
   return(last_error);
}


/**
 * Ob das aktuell ausgeführte Programm ein Expert Adviser ist.
 *
 * @return bool
 */
bool IsExpert() {
   return(false);
}


/**
 * Ob das aktuell ausgeführte Programm ein Script ist.
 *
 * @return bool
 */
bool IsScript() {
   return(false);
}


/**
 * Ob das aktuell ausgeführte Programm ein Indikator ist.
 *
 * @return bool
 */
bool IsIndicator() {
   return(true);
}


/**
 * Ob das aktuell ausgeführte Modul eine Library ist.
 *
 * @return bool
 */
bool IsLibrary() {
   return(false);
}


/**
 * Gibt die ID des aktuellen oder letzten Init()-Szenarios zurück. Kann nicht in deinit() aufgerufen werden.
 *
 * @return int - ID oder NULL, falls ein Fehler auftrat
 */
int InitReason() {
   /*
   Init-Szenarien:
   ---------------
   - onInit.User()             - bei Laden durch den User                               -      Input-Dialog
   - onInit.Template()         - bei Laden durch ein Template (auch bei Terminal-Start) - kein Input-Dialog
   - onInit.Program()          - bei Laden durch iCustom()                              - kein Input-Dialog
   - onInit.ProgramClearTest() - bei Laden durch iCustom() nach Testende                - kein Input-Dialog
   - onInit.Parameters()       - nach Änderung der Indikatorparameter                   -      Input-Dialog
   - onInit.TimeframeChange()  - nach Timeframewechsel des Charts                       - kein Input-Dialog
   - onInit.SymbolChange()     - nach Symbolwechsel des Charts                          - kein Input-Dialog
   - onInit.Recompile()        - bei Reload nach Recompilation                          - kein Input-Dialog

   History:
   --------------------------------------------------------------------------------------------------------------------------------------------------
   - Build 547-551: onInit.User()             - Broken: Wird zwei mal aufgerufen, beim zweiten mal ist der EXECUTION_CONTEXT ungültig.
   - Build  >= 654: onInit.User()             - UninitializeReason() ist REASON_UNDEFINED.
   --------------------------------------------------------------------------------------------------------------------------------------------------
   - Build 577-583: onInit.Template()         - Broken: Kein Aufruf bei Terminal-Start, der Indikator wird aber geladen.
   --------------------------------------------------------------------------------------------------------------------------------------------------
   - Build 556-569: onInit.Program()          - Broken: Wird in- und außerhalb des Testers bei jedem Tick aufgerufen.
   --------------------------------------------------------------------------------------------------------------------------------------------------
   - Build  <= 229: onInit.ProgramClearTest() - UninitializeReason() ist REASON_UNDEFINED.
   - Build     387: onInit.ProgramClearTest() - Broken: Wird nie aufgerufen.
   - Build 388-628: onInit.ProgramClearTest() - UninitializeReason() ist REASON_REMOVE.
   - Build  <= 577: onInit.ProgramClearTest() - Wird nur nach einem automatisiertem Test aufgerufen (VisualMode=Off), der Aufruf erfolgt vorm Start
                                                des nächsten Tests.
   - Build  >= 578: onInit.ProgramClearTest() - Wird auch nach einem manuellen Test aufgerufen (VisualMode=On), nur in diesem Fall erfolgt der Aufruf
                                                sofort nach Testende.
   - Build  >= 633: onInit.ProgramClearTest() - UninitializeReason() ist REASON_CHARTCLOSE.
   --------------------------------------------------------------------------------------------------------------------------------------------------
   - Build 577:     onInit.TimeframeChange()  - Broken: Bricht mit der Logmessage "WARN: expert stopped" ab.
   --------------------------------------------------------------------------------------------------------------------------------------------------
   */

   int uninitializeReason = UninitializeReason();
   int build              = GetTerminalBuild(); if (!build) return(_NULL(SetLastError(stdlib.GetLastError())));
   int uiThread           = GetUIThreadId();
   int currentThread      = GetCurrentThreadId();


   // (1) REASON_PARAMETERS
   if (uninitializeReason == REASON_PARAMETERS) {
      // innerhalb iCustom(): nie
      if (IsSuperContext()) return(!catch("InitReason(1)  unexpected UninitializeReason = "+ UninitializeReasonToStr(uninitializeReason) +" (SuperContext="+ IsSuperContext() +", Testing="+ IsTesting() +", VisualMode="+ IsVisualModeFix() +", IsUiThread="+ (currentThread==uiThread) +", build="+ build +")", ERR_RUNTIME_ERROR));
      // außerhalb iCustom(): erste Parameter-Eingabe bei neuem Indikator oder Parameter-Wechsel bei vorhandenem Indikator (auch im Tester bei VisualMode=On), Input-Dialog
      if (Init.IsNoTick())  return(INIT_REASON_USER      );                // erste Parameter-Eingabe eines manuell zum Chart hinzugefügten Indikators
      else                  return(INIT_REASON_PARAMETERS);                // Parameter-Wechsel eines vorhandenen Indikators
   }


   // (2) REASON_CHARTCHANGE
   if (uninitializeReason == REASON_CHARTCHANGE) {
      // innerhalb iCustom(): nie
      if (IsSuperContext())           return(!catch("InitReason(2)  unexpected UninitializeReason = "+ UninitializeReasonToStr(uninitializeReason) +" (SuperContext="+ IsSuperContext() +", Testing="+ IsTesting() +", VisualMode="+ IsVisualModeFix() +", IsUiThread="+ (currentThread==uiThread) +", build="+ build +")", ERR_RUNTIME_ERROR));
      // außerhalb iCustom(): nach Symbol- oder Timeframe-Wechsel bei vorhandenem Indikator, kein Input-Dialog
      if (Init.IsNewSymbol(Symbol())) return(INIT_REASON_SYMBOLCHANGE   );
      else                            return(INIT_REASON_TIMEFRAMECHANGE);
   }


   // (3) REASON_UNDEFINED
   if (uninitializeReason == REASON_UNDEFINED) {
      // außerhalb iCustom(): je nach Umgebung
      if (!IsSuperContext()) {
         if (build < 654)             return(INIT_REASON_TEMPLATE);        // wenn Template mit Indikator geladen wird (auch bei Terminal-Start und im Tester bei VisualMode=On|Off), kein Input-Dialog
         if (WindowOnDropped() >= 0)  return(INIT_REASON_TEMPLATE);
         else                         return(INIT_REASON_USER    );        // erste Parameter-Eingabe eines manuell zum Chart hinzugefügten Indikators, Input-Dialog
      }
      // innerhalb iCustom(): je nach Umgebung, kein Input-Dialog
      if (IsTesting() && !IsVisualModeFix() && currentThread==uiThread) {  // versionsunabhängig
         if (build <= 229)   return(INIT_REASON_PROGRAM_CLEARTEST);
                             return(!catch("InitReason(3)  unexpected UninitializeReason = "+ UninitializeReasonToStr(uninitializeReason) +" (SuperContext="+ IsSuperContext() +", Testing="+ IsTesting() +", VisualMode="+ IsVisualModeFix() +", IsUiThread="+ (currentThread==uiThread) +", build="+ build +")", ERR_RUNTIME_ERROR));
      }
      return(INIT_REASON_PROGRAM);
   }


   // (4) REASON_REMOVE
   if (uninitializeReason == REASON_REMOVE) {
      // außerhalb iCustom(): nie
      if (!IsSuperContext())                                  return(!catch("InitReason(4)  unexpected UninitializeReason = "+ UninitializeReasonToStr(uninitializeReason) +" (SuperContext="+ IsSuperContext() +", Testing="+ IsTesting() +", VisualMode="+ IsVisualModeFix() +", IsUiThread="+ (currentThread==uiThread) +", build="+ build +")", ERR_RUNTIME_ERROR));
      // innerhalb iCustom(): je nach Umgebung, kein Input-Dialog
      if (!IsTesting() || currentThread!=uiThread)            return(!catch("InitReason(5)  unexpected UninitializeReason = "+ UninitializeReasonToStr(uninitializeReason) +" (SuperContext="+ IsSuperContext() +", Testing="+ IsTesting() +", VisualMode="+ IsVisualModeFix() +", IsUiThread="+ (currentThread==uiThread) +", build="+ build +")", ERR_RUNTIME_ERROR));
      if (!IsVisualModeFix()) { if (388<=build && build<=628) return(INIT_REASON_PROGRAM_CLEARTEST); }
      else                    { if (578<=build && build<=628) return(INIT_REASON_PROGRAM_CLEARTEST); }
      return(!catch("InitReason(6)  unexpected UninitializeReason = "+ UninitializeReasonToStr(uninitializeReason) +" (SuperContext="+ IsSuperContext() +", Testing="+ IsTesting() +", VisualMode="+ IsVisualModeFix() +", IsUiThread="+ (currentThread==uiThread) +", build="+ build +")", ERR_RUNTIME_ERROR));
   }


   // (5) REASON_RECOMPILE
   if (uninitializeReason == REASON_RECOMPILE) {
      // innerhalb iCustom(): nie
      if (IsSuperContext())  return(!catch("InitReason(7)  unexpected UninitializeReason = "+ UninitializeReasonToStr(uninitializeReason) +" (SuperContext="+ IsSuperContext() +", Testing="+ IsTesting() +", VisualMode="+ IsVisualModeFix() +", IsUiThread="+ (currentThread==uiThread) +", build="+ build +")", ERR_RUNTIME_ERROR));
      // außerhalb iCustom(): bei Reload nach Recompilation, vorhandener Indikator, kein Input-Dialog
      return(INIT_REASON_RECOMPILE);
   }


   // (6) REASON_CHARTCLOSE
   if (uninitializeReason == REASON_CHARTCLOSE) {
      // außerhalb iCustom(): nie
      if (!IsSuperContext())  return(!catch("InitReason(8)  unexpected UninitializeReason = "+ UninitializeReasonToStr(uninitializeReason) +" (SuperContext="+ IsSuperContext() +", Testing="+ IsTesting() +", VisualMode="+ IsVisualModeFix() +", IsUiThread="+ (currentThread==uiThread) +", build="+ build +")", ERR_RUNTIME_ERROR));
      // innerhalb iCustom(): je nach Umgebung, kein Input-Dialog
      if (!IsTesting() || currentThread!=uiThread) return(!catch("InitReason(9)  unexpected UninitializeReason = "+ UninitializeReasonToStr(uninitializeReason) +" (SuperContext="+ IsSuperContext() +", Testing="+ IsTesting() +", VisualMode="+ IsVisualModeFix() +", IsUiThread="+ (currentThread==uiThread) +", build="+ build +")", ERR_RUNTIME_ERROR));
      if (build >= 633)                            return(INIT_REASON_PROGRAM_CLEARTEST);
      return(!catch("InitReason(10)  unexpected UninitializeReason = "+ UninitializeReasonToStr(uninitializeReason) +" (SuperContext="+ IsSuperContext() +", Testing="+ IsTesting() +", VisualMode="+ IsVisualModeFix() +", IsUiThread="+ (currentThread==uiThread) +", build="+ build +")", ERR_RUNTIME_ERROR));
   }


   switch (uninitializeReason) {
      case REASON_ACCOUNT:       // nie
      case REASON_TEMPLATE:      // build > 509
      case REASON_INITFAILED:    // ...
      case REASON_CLOSE:         // ...
         return(!catch("InitReason(11)  unexpected UninitializeReason = "+ UninitializeReasonToStr(uninitializeReason) +" (SuperContext="+ IsSuperContext() +", Testing="+ IsTesting() +", VisualMode="+ IsVisualModeFix() +", IsUiThread="+ (currentThread==uiThread) +", build="+ build +")", ERR_RUNTIME_ERROR));
   }
   return(!catch("InitReason(12)  unknown UninitializeReason = "+ uninitializeReason +" (SuperContext="+ IsSuperContext() +", Testing="+ IsTesting() +", VisualMode="+ IsVisualModeFix() +", IsUiThread="+ (currentThread==uiThread) +", build="+ build +")", ERR_RUNTIME_ERROR));
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
 * Initialisiert den EXECUTION_CONTEXT des Indikators.
 *
 * @return bool - Erfolgsstatus
 *
 *
 * NOTE: Der EXECUTION_CONTEXT im Hauptmodul *kann* nach jedem init-Cycle an einer anderen Adresse liegen (ec.Signature ist NICHT konstant).
 */
bool InitExecutionContext() {
   if (ec.Signature(__ExecutionContext) != 0) return(!catch("InitExecutionContext(1)  signature of EXECUTION_CONTEXT not NULL = "+ EXECUTION_CONTEXT.toStr(__ExecutionContext, false), ERR_ILLEGAL_STATE));

   N_INF = MathLog(0);
   P_INF = -N_INF;
   NaN   =  N_INF - N_INF;


   // (1) globale Variablen initialisieren (werden in (3) ggf. mit Werten aus restauriertem oder SuperContext überschrieben)
   int hChart       = WindowHandleEx(NULL); if (!hChart) return(false);
   int hChartWindow = 0;
      if (hChart == -1) hChart       = 0;
      else              hChartWindow = GetParent(hChart);
   int testFlags;
      if (This.IsTesting()) {
         testFlags              |= TF_TESTING;
         if (IsChart) testFlags |= TF_VISUAL;
      }

   __NAME__     = WindowExpertName();
   IsChart      = (hChart != 0);
   __LOG        = true;
   __LOG_CUSTOM = false;                                             // Custom-Logging gibt es vorerst nur für Experts


   // (2) in Library zwischengespeicherten letzten EXECUTION_CONTEXT zurückholen
   int error = Indicator.InitExecutionContext(__ExecutionContext);
   if (IsError(error)) return(!SetLastError(error));


   // (3) Context initialisieren, wenn er neu ist (also nicht aus dem letzten init-Cycle stammt)
   if (!ec.Signature(__ExecutionContext)) {

      // (3.1) Existiert ein SuperContext, die in (1) definierten lokalen Variablen mit denen aus dem SuperContext überschreiben
      if (__lpSuperContext != NULL) {
         if (__lpSuperContext < 0x00010000) return(!catch("InitExecutionContext(2)  invalid input parameter __lpSuperContext = 0x"+ IntToHexStr(__lpSuperContext) +" (not a valid pointer)", ERR_INVALID_INPUT_PARAMETER));
         int superCopy[EXECUTION_CONTEXT.intSize];
         CopyMemory(__lpSuperContext, GetBufferAddress(superCopy), EXECUTION_CONTEXT.size);

         hChart       = ec.hChart      (superCopy);
         hChartWindow = ec.hChartWindow(superCopy);
         testFlags    = ec.TestFlags   (superCopy);
         IsChart      = (hChart != 0);
         __LOG        = ec.Logging     (superCopy);
         ArrayResize(superCopy, 0);
      }

      // (3.2) Context-Variablen setzen
    //ec.setSignature          ...wird in (3.4) gesetzt
      ec.setName              (__ExecutionContext, __NAME__                 );
      ec.setType              (__ExecutionContext, __TYPE__                 );
      ec.setHChart            (__ExecutionContext, hChart                   );
      ec.setHChartWindow      (__ExecutionContext, hChartWindow             );
      ec.setTestFlags         (__ExecutionContext, testFlags                );
      ec.setLpSuperContext    (__ExecutionContext, __lpSuperContext         );
      ec.setInitFlags         (__ExecutionContext, SumInts(__INIT_FLAGS__  ));
      ec.setDeinitFlags       (__ExecutionContext, SumInts(__DEINIT_FLAGS__));
    //ec.setUninitializeReason ...wird in (3.4) gesetzt
    //ec.setWhereami           ...wird in (3.4) gesetzt
      ec.setLogging           (__ExecutionContext, __LOG                    );
    //ec.setLpLogFile         ...bereits gesetzt
    //ec.setLastError         ...bereits NULL
   }
   else {
      // (3.3) Context war bereits initialisiert, globale Variablen aktualisieren
      IsChart = ec.hChart (__ExecutionContext) && 1;
      __LOG   = ec.Logging(__ExecutionContext);
   }

   // (3.4) Signature und variable Context-Werte aktualisieren
   ec.setSignature         (__ExecutionContext, GetBufferAddress(__ExecutionContext));
   ec.setUninitializeReason(__ExecutionContext, UninitializeReason()                );
   ec.setWhereami          (__ExecutionContext, __WHEREAMI__                        );


   // (4) restliche globale Variablen initialisieren
   //
   // Bug 1: Die Variablen Digits und Point sind in init() beim Öffnen eines neuen Charts und beim Accountwechsel u.U. falsch gesetzt.
   //        Nur ein Reload des Templates korrigiert die falschen Werte.
   //
   // Bug 2: Die Variablen Digits und Point können vom Broker u.U. falsch gesetzt worden sein (z.B. S&P500 bei Forex Ltd).
   //
   PipDigits       = Digits & (~1);                                        SubPipDigits      = PipDigits+1;
   PipPoints       = MathRound(MathPow(10, Digits & 1));                   PipPoint          = PipPoints;
   Pip             = NormalizeDouble(1/MathPow(10, PipDigits), PipDigits); Pips              = Pip;
   PipPriceFormat  = StringConcatenate(".", PipDigits);                    SubPipPriceFormat = StringConcatenate(PipPriceFormat, "'");
   PriceFormat     = ifString(Digits==PipDigits, PipPriceFormat, SubPipPriceFormat);


   if (!catch("InitExecutionContext(4)"))
      return(true);

   ArrayInitialize(__ExecutionContext, 0);
   return(false);
}


/**
 * Ob das aktuelle Programm durch ein anderes Programm ausgeführt wird.
 *
 * @return bool
 */
bool IsSuperContext() {
   return(__lpSuperContext != 0);
}


/**
 * Setzt den internen Fehlercode des Indikators. Bei Indikatoraufruf aus iCustom() wird der Fehler zusätzlich an den Aufrufer weitergereicht.
 *
 * @param  int error - Fehlercode
 *
 * @return int - derselbe Fehlercode (for chaining)
 *
 *
 * NOTE: Akzeptiert einen weiteren beliebigen Parameter, der bei der Verarbeitung jedoch ignoriert wird.
 */
int SetLastError(int error, int param=NULL) {
   last_error = error;
   return(ec.setLastError(__ExecutionContext, last_error));
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


// --------------------------------------------------------------------------------------------------------------------------------------------------


#import "stdlib1.ex4"
   int    stdlib.init  (/*EXECUTION_CONTEXT*/int ec[], int tickData[]);
   int    stdlib.start (/*EXECUTION_CONTEXT*/int ec[], int tick, datetime tickTime, int validBars, int changedBars);
   int    stdlib.deinit(/*EXECUTION_CONTEXT*/int ec[]);
   int    stdlib.GetLastError();

   int    onInit();
   int    onInit.User();
   int    onInit.Template();
   int    onInit.Program();
   int    onInit.ProgramClearTest();
   int    onInit.Parameters();
   int    onInit.TimeframeChange();
   int    onInit.SymbolChange();
   int    onInit.Recompile();
   int    afterInit();

   int    onDeinit();
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
   int    afterDeinit();

   bool   Init.IsNoTick();
   bool   Init.IsNewSymbol(string symbol);
   void   Init.StoreSymbol(string symbol);
   int    Indicator.InitExecutionContext(/*EXECUTION_CONTEXT*/int ec[]);
   string InputsToStr();

   int    Chart.SendTick(bool sound);
   void   CopyMemory(int source, int destination, int bytes);
   int    GetUIThreadId();
   string InitReasonToStr(int reason);
   int    SumInts(int array[]);

#import "Expander.dll"
   int    GetBufferAddress(int buffer[]);

#import "struct.EXECUTION_CONTEXT.ex4"
   int    ec.hChart               (/*EXECUTION_CONTEXT*/int ec[]);
   int    ec.hChartWindow         (/*EXECUTION_CONTEXT*/int ec[]);
   int    ec.InitFlags            (/*EXECUTION_CONTEXT*/int ec[]);
   bool   ec.Logging              (/*EXECUTION_CONTEXT*/int ec[]);
   int    ec.Signature            (/*EXECUTION_CONTEXT*/int ec[]);

   int    ec.setDeinitFlags       (/*EXECUTION_CONTEXT*/int ec[], int    deinitFlags       );
   int    ec.setHChart            (/*EXECUTION_CONTEXT*/int ec[], int    hChart            );
   int    ec.setHChartWindow      (/*EXECUTION_CONTEXT*/int ec[], int    hChartWindow      );
   int    ec.setInitFlags         (/*EXECUTION_CONTEXT*/int ec[], int    initFlags         );
   int    ec.setLastError         (/*EXECUTION_CONTEXT*/int ec[], int    lastError         );
   bool   ec.setLogging           (/*EXECUTION_CONTEXT*/int ec[], bool   logging           );
   int    ec.setLpSuperContext    (/*EXECUTION_CONTEXT*/int ec[], int    lpSuperContext    );
   string ec.setName              (/*EXECUTION_CONTEXT*/int ec[], string name              );
   int    ec.setSignature         (/*EXECUTION_CONTEXT*/int ec[], int    signature         );
   int    ec.setType              (/*EXECUTION_CONTEXT*/int ec[], int    type              );
   int    ec.setUninitializeReason(/*EXECUTION_CONTEXT*/int ec[], int    uninitializeReason);
   int    ec.setTestFlags         (/*EXECUTION_CONTEXT*/int ec[], int    testFlags         );
   int    ec.setWhereami          (/*EXECUTION_CONTEXT*/int ec[], int    whereami          );

   string EXECUTION_CONTEXT.toStr (/*EXECUTION_CONTEXT*/int ec[], bool outputDebug);

#import "kernel32.dll"
   int    GetCurrentThreadId();
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
int onInit.User() {
   return(NO_ERROR);
}


/**
 * Nach Laden des Indikators innerhalb eines Templates, auch bei Terminal-Start und im Tester bei VisualMode=On|Off. Bei VisualMode=Off
 * werden bei jedem Teststart init() und deinit() der Indikatoren in Tester.tpl aufgerufen, nicht jedoch deren start()-Funktion.
 * Kein Input-Dialog.
 *
 * @return int - Fehlerstatus
 *
int onInit.Template() {
   return(NO_ERROR);
}


/**
 * Nach Laden des Indikators mittels iCustom(). Kein Input-Dialog.
 *
 * @return int - Fehlerstatus
 *
int onInit.Program() {
   return(NO_ERROR);
}


/**
 * Nach Testende bei Laden des Indikators mittels iCustom(). Der SuperContext des Indikators ist bei diesem Aufruf bereits nicht mehr gültig.
 * Kein Input-Dialog.
 *
 * @return int - Fehlerstatus
 *
int onInit.ProgramClearTest() {
   return(NO_ERROR);
}


/**
 * Nach manueller Änderung der Indikatorparameter. Input-Dialog.
 *
 * @return int - Fehlerstatus
 *
int onInit.Parameters() {
   return(NO_ERROR);
}


/**
 * Nach Änderung der aktuellen Chartperiode. Kein Input-Dialog.
 *
 * @return int - Fehlerstatus
 *
int onInit.TimeframeChange() {
   return(NO_ERROR);
}


/**
 * Nach Änderung des aktuellen Chartsymbols. Kein Input-Dialog.
 *
 * @return int - Fehlerstatus
 *
int onInit.SymbolChange() {
   return(NO_ERROR);
}


/**
 * Bei Reload des Indikators nach Neukompilierung. Kein Input-Dialog
 *
 * @return int - Fehlerstatus
 *
int onInit.Recompile() {
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
