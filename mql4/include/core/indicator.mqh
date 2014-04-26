
#define __TYPE__ T_INDICATOR

extern string ___________________________;
extern int    __lpSuperContext;


/**
 * Globale init()-Funktion für Indikatoren.
 *
 * Bei Aufruf durch das Terminal wird der letzte Errorcode 'last_error' in 'prev_error' gespeichert und vor Abarbeitung
 * zurückgesetzt.
 *
 * @return int - Fehlerstatus
 */
int init() { // throws ERS_TERMINAL_NOT_READY
   if (__STATUS_ERROR)
      return(last_error);

   if (__WHEREAMI__ == NULL) {                                             // Aufruf durch Terminal
      __WHEREAMI__ = FUNC_INIT;
      prev_error   = last_error;
      last_error   = NO_ERROR;
   }


   // (1) EXECUTION_CONTEXT initialisieren
   if (!ec.Signature(__ExecutionContext))
      if (IsError(InitExecutionContext()))
         return(last_error);


   // (2) stdlib (re-)initialisieren
   int tickData[3];
   int error = stdlib_init(__ExecutionContext, tickData);
   if (IsError(error))
      return(SetLastError(error));

   Tick          = tickData[0]; Ticks = Tick;
   Tick.Time     = tickData[1];
   Tick.prevTime = tickData[2];


   // (3) user-spezifische Init-Tasks ausführen
   int initFlags = ec.InitFlags(__ExecutionContext);

   if (_bool(initFlags & INIT_PIPVALUE)) {
      TickSize = MarketInfo(Symbol(), MODE_TICKSIZE);                      // schlägt fehl, wenn kein Tick vorhanden ist
      error = GetLastError();
      if (IsError(error)) {                                                // - Symbol nicht subscribed (Start, Account-/Templatewechsel), Symbol kann noch "auftauchen"
         if (error == ERR_UNKNOWN_SYMBOL)                                  // - synthetisches Symbol im Offline-Chart
            return(debug("init()   MarketInfo() => ERR_UNKNOWN_SYMBOL", SetLastError(ERS_TERMINAL_NOT_READY)));
         return(catch("init(1)", error));
      }
      if (!TickSize) return(debug("init()   MarketInfo(MODE_TICKSIZE) = 0", SetLastError(ERS_TERMINAL_NOT_READY)));

      double tickValue = MarketInfo(Symbol(), MODE_TICKVALUE);
      error = GetLastError();
      if (IsError(error)) {
         if (error == ERR_UNKNOWN_SYMBOL)                                  // siehe oben bei MODE_TICKSIZE
            return(debug("init()   MarketInfo() => ERR_UNKNOWN_SYMBOL", SetLastError(ERS_TERMINAL_NOT_READY)));
         return(catch("init(2)", error));
      }
      if (!tickValue) return(debug("init()   MarketInfo(MODE_TICKVALUE) = 0", SetLastError(ERS_TERMINAL_NOT_READY)));
   }
   if (_bool(initFlags & INIT_BARS_ON_HIST_UPDATE)) {}                     // noch nicht implementiert


   // (4) user-spezifische init()-Routinen aufrufen                        // User-Routinen *können*, müssen aber nicht implementiert werden.
   if (onInit() == -1)                                                     //
      return(last_error);                                                  // Preprocessing-Hook
                                                                           //
   switch (UninitializeReason()) {                                         //
      case REASON_PARAMETERS : error = onInitParameterChange(); break;     // Gibt eine der Funktionen einen normalen Fehler zurück, bricht init() nicht ab
      case REASON_CHARTCHANGE: error = onInitChartChange();     break;     // (um Postprocessing-Hook auch bei Fehlern ausführen zu können).
      case REASON_ACCOUNT    : error = onInitAccountChange();   break;     //
      case REASON_CHARTCLOSE : error = onInitChartClose();      break;     //
      case REASON_UNDEFINED  : error = onInitUndefined();       break;     //
      case REASON_REMOVE     : error = onInitRemove();          break;     //
      case REASON_RECOMPILE  : error = onInitRecompile();       break;     //
   }                                                                       //
   if (error == -1)                                                        // Gibt eine der Funktionen jedoch -1 zurück, bricht init() ab.
      return(last_error);                                                  //
                                                                           //
   afterInit();                                                            // Postprocessing-Hook
                                                                           //

   // (5) bei Aufruf durch iCustom() Parameter loggen
   if (__LOG) /*&&*/ if (Indicator.IsSuperContext())
      log(InputsToStr());


   // (6) nach Parameteränderung im "Indicators List"-Window nicht auf den nächsten Tick warten
   if (!__STATUS_ERROR) /*&&*/ if (UninitializeReason()==REASON_PARAMETERS) {
      //debug("init()   calling Chart.SendTick()");
      Chart.SendTick(false);                                               // TODO: !!! Nur bei Existenz des "Indicators List"-Windows (nicht bei einzelnem Indikator)
   }

   catch("init(3)");
   return(last_error);
}


/**
 * Globale start()-Funktion für Indikatoren.
 *
 * - Erfolgt der Aufruf nach einem vorherigem init()-Aufruf und init() kehrte mit ERS_TERMINAL_NOT_READY zurück,
 *   wird versucht, init() erneut auszuführen. Bei erneutem init()-Fehler bricht start() ab.
 *   Wurde init() fehlerfrei ausgeführt, wird der letzte Errorcode 'last_error' vor Abarbeitung zurückgesetzt.
 *
 * - Der letzte Errorcode 'last_error' wird in 'prev_error' gespeichert und vor Abarbeitung zurückgesetzt.
 *
 * @return int - Fehlerstatus
 */
int start() {
   if (__STATUS_ERROR)
      return(last_error);

   int error;

   Tick++; Ticks = Tick;                                                   // einfacher Zähler, der konkrete Wert hat keine Bedeutung
   Tick.prevTime = Tick.Time;
   Tick.Time     = MarketInfo(Symbol(), MODE_TIME);                        // TODO: !!! MODE_TIME und TimeCurrent() sind im Tester-Chart immer falsch !!!
   ValidBars     = IndicatorCounted();

   if (!Tick.Time) {
      error = GetLastError();
      if (error!=NO_ERROR) /*&&*/ if (error!=ERR_UNKNOWN_SYMBOL)           // ERR_UNKNOWN_SYMBOL vorerst ignorieren, da IsOfflineChart beim ersten Tick
         return(catch("start(1)", error));                                 // nicht sicher detektiert werden kann
   }


   /*
   if (StringStartsWith(Symbol(), "_")) {
      error = GetLastError(); if (error != ERR_UNKNOWN_SYMBOL) catch("start(0.1)", error);

      int hWndChart = WindowHandle(Symbol(), NULL);                        // schlägt in etlichen Situationen fehl (init(), deinit(), in start() bei Programmstart, im Tester)

      debug("start()   Tick="+ Tick +"   hWndChart="+ hWndChart);

      if (!hWndChart) {
         int hWndMain, hWndMDI, hWndNext;

         hWndMain = GetApplicationWindow();
         if (hWndMain > 0)
            hWndMDI = GetDlgItem(hWndMain, IDD_MDI_CLIENT);
         debug("start()   hWndMain="+ hWndMain +"   hWndMDI="+ hWndMDI);


         if (hWndMDI > 0) {
            hWndNext = GetWindow(hWndMDI, GW_CHILD);
            while (hWndNext != 0) {
               debug("start()   hWndNext="+ hWndNext +"   title=\""+ GetWindowText(hWndNext) +"\"");
               hWndNext = GetWindow(hWndNext, GW_HWNDNEXT);
            }
         }
      }
   }
   */


   // (1.1) Aufruf nach init(): prüfen, ob es erfolgreich war und *nur dann* Flag zurücksetzen.
   if (__WHEREAMI__ == FUNC_INIT) {
      if (IsLastError()) {
         if (last_error != ERS_TERMINAL_NOT_READY)                         // init() ist mit Fehler zurückgekehrt
            return(SetLastError(last_error));
         __WHEREAMI__ = FUNC_START;
         if (IsError(init())) {                                            // init() erneut aufrufen (kann Neuaufruf an __WHEREAMI__ erkennen)
            __WHEREAMI__ = FUNC_INIT;                                      // erneuter Fehler, __WHEREAMI__ restaurieren und Abbruch
            return(SetLastError(last_error));
         }
      }
      last_error = NO_ERROR;                                               // init() war erfolgreich
      ValidBars  = 0;
   }
   // (1.2) Aufruf nach Tick
   else {
      prev_error = last_error;
      last_error = NO_ERROR;

      if      (prev_error == ERS_TERMINAL_NOT_READY  ) ValidBars = 0;
      else if (prev_error == ERS_HISTORY_UPDATE      ) ValidBars = 0;
      else if (prev_error == ERR_HISTORY_INSUFFICIENT) ValidBars = 0;
      if      (__STATUS_HISTORY_UPDATE               ) ValidBars = 0;      // "History update/insufficient" kann je nach Kontext Fehler und/oder Status sein.
      if      (__STATUS_HISTORY_INSUFFICIENT         ) ValidBars = 0;
   }


   // (2) Abschluß der Chart-Initialisierung überprüfen (kann bei Terminal-Start auftreten)
   if (!Bars)
      return(SetLastError(debug("start()   Bars = 0", ERS_TERMINAL_NOT_READY)));

   /*
   // (3) Werden Zeichenpuffer verwendet, muß in onTick() deren Initialisierung überprüft werden.
   if (ArraySize(buffer) == 0)
      return(SetLastError(ERS_TERMINAL_NOT_READY));                        // kann bei Terminal-Start auftreten
   */

   __WHEREAMI__                    = FUNC_START;
   __ExecutionContext[EC_WHEREAMI] = FUNC_START;
   __STATUS_HISTORY_UPDATE         = false;
   __STATUS_HISTORY_INSUFFICIENT   = false;


   // (4) ChangedBars berechnen
   ChangedBars = Bars - ValidBars;


   // (5) stdLib benachrichtigen
   if (stdlib_start(__ExecutionContext, Tick, Tick.Time, ValidBars, ChangedBars) != NO_ERROR)
      return(SetLastError(stdlib_GetLastError()));


   // (6) bei Bedarf Input-Dialog aufrufen
   if (__STATUS_RELAUNCH_INPUT) {
      __STATUS_RELAUNCH_INPUT = false;
      return(start.RelaunchInputDialog());
   }


   // (7) Main-Funktion aufrufen und auswerten
   onTick();

   error = GetLastError();
   if (error != NO_ERROR)
      catch("start(2)", error);

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
   __WHEREAMI__ =                               FUNC_DEINIT;
   ec.setWhereami          (__ExecutionContext, FUNC_DEINIT         );
   ec.setUninitializeReason(__ExecutionContext, UninitializeReason());


   // (1) User-spezifische deinit()-Routinen aufrufen                            // User-Routinen *können*, müssen aber nicht implementiert werden.
   int error = onDeinit();                                                       // Preprocessing-Hook
                                                                                 //
   if (error != -1) {                                                            //
      switch (UninitializeReason()) {                                            //
         case REASON_PARAMETERS : error = onDeinitParameterChange(); break;      // - deinit() bricht *nicht* ab, falls eine der User-Routinen einen Fehler zurückgibt.
         case REASON_CHARTCHANGE: error = onDeinitChartChange();     break;      // - deinit() bricht ab, falls eine der User-Routinen -1 zurückgibt.
         case REASON_ACCOUNT    : error = onDeinitAccountChange();   break;      //
         case REASON_CHARTCLOSE : error = onDeinitChartClose();      break;      //
         case REASON_UNDEFINED  : error = onDeinitUndefined();       break;      //
         case REASON_REMOVE     : error = onDeinitRemove();          break;      //
         case REASON_RECOMPILE  : error = onDeinitRecompile();       break;      //
      }                                                                          //
   }                                                                             //
   if (error != -1)                                                              //
      error = afterDeinit();                                                     // Postprocessing-Hook


   // (2) User-spezifische Deinit-Tasks ausführen
   if (error != -1) {
      // ...
   }


   // (3) stdlib deinitialisieren und Context speichern
   error = stdlib_deinit(__ExecutionContext);
   if (IsError(error))
      SetLastError(error);

   return(last_error);
}


#import "structs1.ex4"
   int    ec.Signature            (/*EXECUTION_CONTEXT*/int ec[]                           );
   int    ec.lpName               (/*EXECUTION_CONTEXT*/int ec[]                           );
   int    ec.Type                 (/*EXECUTION_CONTEXT*/int ec[]                           );
   int    ec.ChartProperties      (/*EXECUTION_CONTEXT*/int ec[]                           );
   int    ec.InitFlags            (/*EXECUTION_CONTEXT*/int ec[]                           );
   int    ec.Logging              (/*EXECUTION_CONTEXT*/int ec[]                           );

   int    ec.setSignature         (/*EXECUTION_CONTEXT*/int ec[], int    signature         );
   string ec.setName              (/*EXECUTION_CONTEXT*/int ec[], string name              );
   int    ec.setType              (/*EXECUTION_CONTEXT*/int ec[], int    type              );
   int    ec.setChartProperties   (/*EXECUTION_CONTEXT*/int ec[], int    chartProperties   );
   int    ec.setLpSuperContext    (/*EXECUTION_CONTEXT*/int ec[], int    lpContext         );
   int    ec.setInitFlags         (/*EXECUTION_CONTEXT*/int ec[], int    initFlags         );
   int    ec.setDeinitFlags       (/*EXECUTION_CONTEXT*/int ec[], int    deinitFlags       );
   int    ec.setUninitializeReason(/*EXECUTION_CONTEXT*/int ec[], int    uninitializeReason);
   int    ec.setWhereami          (/*EXECUTION_CONTEXT*/int ec[], int    whereami          );
   bool   ec.setLogging           (/*EXECUTION_CONTEXT*/int ec[], bool   logging           );
   int    ec.setLastError         (/*EXECUTION_CONTEXT*/int ec[], int    lastError         );
#import


/**
 * Initialisiert den EXECUTION_CONTEXT des Indikators.
 *
 * @return int - Fehlerstatus
 *
 *
 * NOTE: Der EXECUTION_CONTEXT im Hauptmodul *kann* nach jedem init-Cycle an einer neuen Adresse liegen (ec.Signature ist NICHT konstant).
 */
int InitExecutionContext() {
   if (ec.Signature(__ExecutionContext) != 0) return(catch("InitExecutionContext(1)   signature of EXECUTION_CONTEXT not NULL = "+ EXECUTION_CONTEXT.toStr(__ExecutionContext, false), ERR_ILLEGAL_STATE));


   // (1) globale Variablen initialisieren (werden später ggf. mit Werten aus restauriertem oder SuperContext überschrieben)
   __NAME__       = WindowExpertName();
   IsChart        = !IsTesting() || IsVisualMode();                  // TODO: Vorläufig ignorieren wir, daß ein Template-Indikator im Test bei VisualMode=Off
 //IsOfflineChart = IsChart && ???                                   //       in Indicator::init() IsChart=On signalisiert.
   __LOG          = true;
   __LOG_CUSTOM   = false;                                           // Custom-Logging gibt es nur für Strategien/Experts


   // (2) in Library gespeicherten EXECUTION_CONTEXT restaurieren
   int error = Indicator.InitExecutionContext(__ExecutionContext);
   if (IsError(error))
      return(SetLastError(error));


   // (3) Context ggf. initialisieren
   if (!ec.Signature(__ExecutionContext)) {
      // (3.1) temporäre Kopie eines existierenden SuperContexts erstellen und die betroffenen globalen Variablen überschreiben
      int super[EXECUTION_CONTEXT.intSize], chartProperties;
      if (__lpSuperContext != NULL) {
         if (__lpSuperContext < 0x00010000) return(catch("InitExecutionContext(2)   invalid input parameter __lpSuperContext = 0x"+ IntToHexStr(__lpSuperContext) +" (not a pointer)", ERR_INVALID_INPUT_PARAMVALUE));
         CopyMemory(GetBufferAddress(super), __lpSuperContext, EXECUTION_CONTEXT.size);

         IsChart        = _bool(ec.ChartProperties(super) & CP_CHART);
         IsOfflineChart =       ec.ChartProperties(super) & CP_OFFLINE && IsChart;
         __LOG          =       ec.Logging        (super);
      }

      // (3.2) Context-Variablen setzen
    //ec.setSignature          ...wird später gesetzt
      ec.setName              (__ExecutionContext, __NAME__);
      ec.setType              (__ExecutionContext, __TYPE__);
      ec.setChartProperties   (__ExecutionContext, ifInt(IsOfflineChart, CP_OFFLINE_CHART, 0) | ifInt(IsChart, CP_CHART, 0));
      ec.setLpSuperContext    (__ExecutionContext, __lpSuperContext         );
      ec.setInitFlags         (__ExecutionContext, SumInts(__INIT_FLAGS__  ));
      ec.setDeinitFlags       (__ExecutionContext, SumInts(__DEINIT_FLAGS__));
    //ec.setUninitializeReason ...wird später gesetzt
    //ec.setWhereami           ...wird später gesetzt
      ec.setLogging           (__ExecutionContext, __LOG                    );
    //ec.setLpLogFile         ...bereits gesetzt
    //ec.setLastError         ...bereits NULL
   }
   else {
      // (3.3) Context war bereits initialisiert, globale Variablen und variable Context-Werte aktualisieren
      IsChart        = _bool(ec.ChartProperties(__ExecutionContext) & CP_CHART);
      IsOfflineChart =       ec.ChartProperties(__ExecutionContext) & CP_OFFLINE && IsChart;
      __LOG          =       ec.Logging        (__ExecutionContext);

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
   PipPoints       = MathRound(MathPow(10, Digits<<31>>31));               PipPoint          = PipPoints;
   Pip             = NormalizeDouble(1/MathPow(10, PipDigits), PipDigits); Pips              = Pip;
   PipPriceFormat  = StringConcatenate(".", PipDigits);                    SubPipPriceFormat = StringConcatenate(PipPriceFormat, "'");
   PriceFormat     = ifString(Digits==PipDigits, PipPriceFormat, SubPipPriceFormat);


   if (IsError(catch("InitExecutionContext(4)")))
      ArrayInitialize(__ExecutionContext, 0);
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
 * Ob das aktuell ausgeführte Programm ein im Tester laufender Expert ist.
 *
 * @return bool
 */
bool Expert.IsTesting() {
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
 * Ob das aktuell ausgeführte Programm ein im Tester laufender Indikator ist.
 *
 * @return bool
 *
 *
 * NOTE: Nur in stdlib implementiert, damit das Ergebnis gecacht werden kann.
 *
bool Indicator.IsTesting() {
}
 */


/**
 * Ob das aktuelle Programm durch ein anderes Programm ausgeführt wird.
 *
 * @return bool
 */
bool Indicator.IsSuperContext() {
   return(__lpSuperContext != 0);
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
 * Ob das aktuell ausgeführte Programm ein im Tester laufendes Script ist.
 *
 * @return bool
 */
bool Script.IsTesting() {
   return(false);
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
 * Ob das aktuelle Programm im Tester ausgeführt wird.
 *
 * @return bool
 */
bool This.IsTesting() {
   return(Indicator.IsTesting());
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

   switch (error) {
      case NO_ERROR              :
      case ERS_HISTORY_UPDATE    :
      case ERS_TERMINAL_NOT_READY:
      case ERS_EXECUTION_STOPPING: break;

      default:
         __STATUS_ERROR = true;
   }
   return(ec.setLastError(__ExecutionContext, last_error));
}


// -- init()-Templates ------------------------------------------------------------------------------------------------------------------------------


/**
 * Initialisierung Preprocessing
 *
 * @return int - Fehlerstatus
 *
int onInit() {
   return(NO_ERROR);
}


/**
 * außerhalb iCustom(): erste Parameter-Eingabe bei neuem Indikator, Parameter-Wechsel bei vorhandenem Indikator (auch im Tester bei ViualMode=On), Input-Dialog
 * innerhalb iCustom(): nie
 *
 * @return int - Fehlerstatus
 *
int onInitParameterChange() {
   return(NO_ERROR);
}


/**
 * außerhalb iCustom(): nach Symbol- oder Timeframe-Wechsel bei vorhandenem Indikator, kein Input-Dialog
 * innerhalb iCustom(): ?
 *
 * @return int - Fehlerstatus
 *
int onInitChartChange() {
   return(NO_ERROR);
}


/**
 * Kein UninitializeReason gesetzt.
 *
 * außerhalb iCustom(): wenn Template mit Indikator darin geladen wird (auch bei Terminal-Start und im Tester bei VisualMode=On|Off), kein Input-Dialog
 * innerhalb iCustom(): in allen init()-Fällen, kein Input-Dialog
 *
 * @return int - Fehlerstatus
 *
int onInitUndefined() {
   return(NO_ERROR);
}


/**
 * außerhalb iCustom(): ?
 * innerhalb iCustom(): im Tester nach Test-Restart bei VisualMode=Off, kein Input-Dialog
 *
 * @return int - Fehlerstatus
 *
int onInitRemove() {
   return(NO_ERROR);
}


/**
 * außerhalb iCustom(): nach Recompile und Reload, vorhandener Indikator, kein Input-Dialog
 * innerhalb iCustom(): nie
 *
 * @return int - Fehlerstatus
 *
int onInitRecompile() {
   return(NO_ERROR);
}


/**
 * Initialisierung Postprocessing
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
 * außerhalb iCustom(): Indikator von Hand entfernt oder Chart geschlossen
 * innerhalb iCustom(): in allen deinit()-Fällen
 *
 * @return int - Fehlerstatus
 *
int onDeinitRemove() {
   return(NO_ERROR);
}


/**
 * außerhalb iCustom(): nach Recompilation, vor Reload
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

// ------------------------------------------------------------------------------------------------------------------------------------------------
