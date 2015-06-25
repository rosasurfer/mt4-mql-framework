
#define __TYPE__         MT_SCRIPT
#define __lpSuperContext NULL

extern string ___________________________;
extern string LogLevel = "inherit";


/**
 * Globale init()-Funktion für Scripte.
 *
 * @return int - Fehlerstatus
 */
int init() {
   if (__STATUS_OFF)
      return(last_error);

   SetMainExecutionContext(__ExecutionContext, WindowExpertName(), Symbol(), Period());   // noch bevor die erste Library geladen wird

   if (__WHEREAMI__ == NULL) {                                                            // Aufruf durch Terminal, alle Variablen sind zurückgesetzt
      __WHEREAMI__ = RF_INIT;
      prev_error   = NO_ERROR;
      last_error   = NO_ERROR;
   }


   // (1) EXECUTION_CONTEXT initialisieren
   if (!ec_ProgramType(__ExecutionContext)) /*&&*/ if (!InitExecutionContext()) {
      UpdateProgramStatus();
      if (__STATUS_OFF) return(last_error);
   }
   SetMainExecutionContext(__ExecutionContext, WindowExpertName(), Symbol(), Period());   // wiederholter Aufruf


   // (2) stdlib initialisieren
   int iNull[];
   int error = stdlib.init(__ExecutionContext, iNull);
   if (IsError(error)) {
      UpdateProgramStatus(SetLastError(error));
      if (__STATUS_OFF) return(last_error);
   }

                                                                                          // #define INIT_TIMEZONE               in stdlib.init()
   // (3) user-spezifische Init-Tasks ausführen                                           // #define INIT_PIPVALUE
   int initFlags = ec_InitFlags(__ExecutionContext);                                      // #define INIT_BARS_ON_HIST_UPDATE
                                                                                          // #define INIT_CUSTOMLOG
   if (initFlags & INIT_PIPVALUE && 1) {
      TickSize = MarketInfo(Symbol(), MODE_TICKSIZE);                                     // schlägt fehl, wenn kein Tick vorhanden ist
      if (IsError(catch("init(1)"))) {
         UpdateProgramStatus();
         if (__STATUS_OFF) return(last_error);
      }
      if (!TickSize)       return(UpdateProgramStatus(catch("init(2)  MarketInfo(MODE_TICKSIZE) = 0", ERR_INVALID_MARKET_DATA)));

      double tickValue = MarketInfo(Symbol(), MODE_TICKVALUE);
      if (IsError(catch("init(3)"))) {
         UpdateProgramStatus();
         if (__STATUS_OFF) return(last_error);
      }
      if (!tickValue)      return(UpdateProgramStatus(catch("init(4)  MarketInfo(MODE_TICKVALUE) = 0", ERR_INVALID_MARKET_DATA)));
   }
   if (initFlags & INIT_BARS_ON_HIST_UPDATE && 1) {}                                      // noch nicht implementiert


   // (4) User-spezifische init()-Routinen *können*, müssen aber nicht implementiert werden.
   //
   // Die User-Routinen werden ausgeführt, wenn der Preprocessing-Hook (falls implementiert) ohne Fehler zurückkehrt.
   // Der Postprocessing-Hook wird ausgeführt, wenn weder der Preprocessing-Hook (falls implementiert) noch die User-Routinen
   // (falls implementiert) -1 zurückgeben.
   error = onInit();                                                                      // Preprocessing-Hook
   if (!error) {                                                                          //
      switch (UninitializeReason()) {                                                     //
         case REASON_PARAMETERS : error = onInitParameterChange(); break;                 //
         case REASON_CHARTCHANGE: error = onInitChartChange();     break;                 //
         case REASON_ACCOUNT    : error = onInitAccountChange();   break;                 //
         case REASON_CHARTCLOSE : error = onInitChartClose();      break;                 //
         case REASON_UNDEFINED  : error = onInitUndefined();       break;                 //
         case REASON_REMOVE     : error = onInitRemove();          break;                 //
         case REASON_RECOMPILE  : error = onInitRecompile();       break;                 //
         // build > 509                                                                   //
         case REASON_TEMPLATE   : error = onInitTemplate();        break;                 //
         case REASON_INITFAILED : error = onInitFailed();          break;                 //
         case REASON_CLOSE      : error = onInitClose();           break;                 //
                                                                                          //
         default: return(UpdateProgramStatus(catch("init(5)  unknown UninitializeReason = "+ UninitializeReason(), ERR_RUNTIME_ERROR)));
      }                                                                                   //
   }                                                                                      //
   UpdateProgramStatus();                                                                 //
                                                                                          //
   if (error != -1) {                                                                     //
      afterInit();                                                                        // Postprocessing-Hook
      UpdateProgramStatus();                                                              //
   }                                                                                      //

   UpdateProgramStatus(catch("init(6)"));
   return(last_error);
}


/**
 * Globale start()-Funktion für Scripte.
 *
 * @return int - Fehlerstatus
 */
int start() {
   if (__STATUS_OFF) {                                                        // init()-Fehler abfangen
      string msg = WindowExpertName() +": switched off ("+ ifString(!__STATUS_OFF.reason, "unknown reason", ErrorToStr(__STATUS_OFF.reason)) +")";
      Comment(NL + NL + NL + msg);                                            // 3 Zeilen Abstand für Instrumentanzeige und ggf. vorhandene Legende
      debug("start(1)  "+ msg);
      return(last_error);
   }


   Tick++; zTick++;                                                           // einfache Zähler, die konkreten Werte haben keine Bedeutung
   Tick.prevTime = Tick.Time;
   Tick.Time     = MarketInfo(Symbol(), MODE_TIME);
   ValidBars     = -1;
   ChangedBars   = -1;


   if (!Tick.Time) {
      int error = GetLastError();
      if (error!=NO_ERROR) /*&&*/ if (error!=ERR_UNKNOWN_SYMBOL) {            // ERR_UNKNOWN_SYMBOL vorerst ignorieren, da ein Offline-Chart beim ersten Tick
         UpdateProgramStatus(catch("start(2)", error));                       // nicht sicher detektiert werden kann
         if (__STATUS_OFF) return(last_error);
      }
   }


   // (1) init() war immer erfolgreich
   __WHEREAMI__ = ec_setRootFunction(__ExecutionContext, RF_START);


   // (2) Abschluß der Chart-Initialisierung überprüfen (kann bei Terminal-Start auftreten)  //       Bars kann 0 sein, wenn das Script auf einem leeren Chart startet (Waiting for update...)
   if (!Bars)                                                                                // TODO: In Scripten in initFlags integrieren. Manche Scripte laufen nicht ohne Bars,
      return(UpdateProgramStatus(catch("start(3)  Bars = 0", ERS_TERMINAL_NOT_YET_READY)));  //       andere brauchen die aktuelle Zeitreihe nicht.


   SetMainExecutionContext(__ExecutionContext, WindowExpertName(), Symbol(), Period());


   // (3) stdLib benachrichtigen
   if (stdlib.start(__ExecutionContext, Tick, Tick.Time, ValidBars, ChangedBars) != NO_ERROR) {
      UpdateProgramStatus(SetLastError(stdlib.GetLastError()));
      if (__STATUS_OFF) return(last_error);
   }


   // (4) Main-Funktion aufrufen
   onStart();


   catch("start(4)");
   return(UpdateProgramStatus(last_error));
}


/**
 * Globale deinit()-Funktion für Scripte.
 *
 * @return int - Fehlerstatus
 */
int deinit() {
   __WHEREAMI__ =                               RF_DEINIT;
   ec_setRootFunction      (__ExecutionContext, RF_DEINIT           );
   ec_setUninitializeReason(__ExecutionContext, UninitializeReason());

   SetMainExecutionContext(__ExecutionContext, WindowExpertName(), Symbol(), Period());


   // (1) User-spezifische deinit()-Routinen *können*, müssen aber nicht implementiert werden.
   //
   // Die User-Routinen werden ausgeführt, wenn der Preprocessing-Hook (falls implementiert) ohne Fehler zurückkehrt.
   // Der Postprocessing-Hook wird ausgeführt, wenn weder der Preprocessing-Hook (falls implementiert) noch die User-Routinen
   // (falls implementiert) -1 zurückgeben.
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
      UpdateProgramStatus();                                                     //
   }                                                                             //


   // (2) User-spezifische Deinit-Tasks ausführen
   if (!error) {
      // ...
   }


   // (3) stdlib deinitialisieren
   error = stdlib.deinit(__ExecutionContext);
   if (IsError(error))
      SetLastError(error);


   UpdateProgramStatus(catch("deinit(2)"));
   return(last_error); __DummyCalls();
}


/**
 * Gibt die ID des aktuellen oder letzten Init()-Szenarios zurück. Kann außer in deinit() überall aufgerufen werden.
 *
 * @return int - ID oder NULL, falls ein Fehler auftrat
 */
int InitReason() {
   return(_NULL(catch("InitReason()", ERR_NOT_IMPLEMENTED)));
}


/**
 * Gibt die ID des aktuellen Deinit()-Szenarios zurück. Kann nur in deinit() aufgerufen werden.
 *
 * @return int - ID oder NULL, falls ein Fehler auftrat
 */
int DeinitReason() {
   return(_NULL(catch("DeinitReason()", ERR_NOT_IMPLEMENTED)));
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
   return(true);
}


/**
 * Ob das aktuell ausgeführte Programm ein Indikator ist.
 *
 * @return bool
 */
bool IsIndicator() {
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
 * Initialisiert den EXECUTION_CONTEXT des Scripts.
 *
 * @return bool - Erfolgsstatus
 */
bool InitExecutionContext() {
   if (ec_ProgramType(__ExecutionContext) != 0) return(!catch("InitExecutionContext(1)  unexpected EXECUTION_CONTEXT.programType = "+ ec_ProgramType(__ExecutionContext) +" (not NULL)", ERR_ILLEGAL_STATE));

   N_INF = MathLog(0);
   P_INF = -N_INF;
   NaN   =  N_INF - N_INF;


   // (1) globale Variablen initialisieren
   int    initFlags    = SumInts(__INIT_FLAGS__  );
   int    deinitFlags  = SumInts(__DEINIT_FLAGS__);
   int    hChart       = WindowHandleEx(NULL); if (!hChart) return(false);
   int    hChartWindow = GetParent(hChart);
   string logFile;

   __NAME__       = WindowExpertName();
   __CHART        = true;
   __LOG          = true;
   __LOG_CUSTOM   = false;                                                                      // Custom-Logging gibt es vorerst nur für Experts

   PipDigits      = Digits & (~1);                                        SubPipDigits      = PipDigits+1;
   PipPoints      = MathRound(MathPow(10, Digits & 1));                   PipPoint          = PipPoints;
   Pip            = NormalizeDouble(1/MathPow(10, PipDigits), PipDigits); Pips              = Pip;
   PipPriceFormat = StringConcatenate(".", PipDigits);                    SubPipPriceFormat = StringConcatenate(PipPriceFormat, "'");
   PriceFormat    = ifString(Digits==PipDigits, PipPriceFormat, SubPipPriceFormat);


   // (2) EXECUTION_CONTEXT initialisieren
 //ec_setProgramId         ...kein MQL-Setter
   ec_setProgramType       (__ExecutionContext, __TYPE__                                            );
   ec_setProgramName       (__ExecutionContext, WindowExpertName()                                  );
   ec_setLpSuperContext    (__ExecutionContext, NULL                                                );
   ec_setInitFlags         (__ExecutionContext, initFlags                                           );
   ec_setDeinitFlags       (__ExecutionContext, deinitFlags                                         );
   ec_setRootFunction      (__ExecutionContext, __WHEREAMI__                                        );
   ec_setUninitializeReason(__ExecutionContext, UninitializeReason()                                );

   ec_setSymbol            (__ExecutionContext, Symbol()                                            );
   ec_setTimeframe         (__ExecutionContext, Period()                                            );
   ec_setHChartWindow      (__ExecutionContext, hChartWindow                                        );
   ec_setHChart            (__ExecutionContext, hChart                                              );
   ec_setTestFlags         (__ExecutionContext, ifInt(Script.IsTesting(), TF_TESTING | TF_VISUAL, 0));

 //ec_setLastError         ...wird nicht überschrieben
   ec_setLogging           (__ExecutionContext, __LOG                                               );
   ec_setLogFile           (__ExecutionContext, logFile                                             );

   return(!catch("InitExecutionContext(2)"));
}


/**
 * Ob das aktuelle Programm durch ein anderes Programm ausgeführt wird.
 *
 * @return bool
 */
bool IsSuperContext() {
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
   MessageBox(message, "Script "+ __NAME__ + location, MB_ICONERROR|MB_OK);

   return(SetLastError(error));
}


/**
 * Setzt den internen Fehlercode des Scripts.
 *
 * @param  int error - Fehlercode
 *
 * @return int - derselbe Fehlercode (for chaining)
 *
 *
 * NOTE: Akzeptiert einen weiteren beliebigen Parameter, der bei der Verarbeitung jedoch ignoriert wird.
 */
int SetLastError(int error, int param=NULL) {
   last_error = ec_setLastError(__ExecutionContext, error);
   return(error);
}


/**
 * Überprüft und aktualisiert den aktuellen Programmstatus des Scripts. Setzt je nach Kontext das Flag __STATUS_OFF.
 *
 * @param  int value - der zurückzugebende Wert (default: NULL)
 *
 * @return int - der übergebene Wert
 */
int UpdateProgramStatus(int value=NULL) {
   switch (last_error) {
      case NO_ERROR                  :
      case ERS_HISTORY_UPDATE        :
    //case ERS_TERMINAL_NOT_YET_READY:                               // in Scripten ist ERS_TERMINAL_NOT_YET_READY kein Status, sondern normaler Fehler
      case ERS_EXECUTION_STOPPING    : break;

      default:
         __STATUS_OFF        = true;
         __STATUS_OFF.reason = last_error;
   }
   return(value);

   // Dummy-Calls: unterdrücken unnütze Compilerwarnungen
   HandleScriptError(NULL, NULL, NULL);
}



// --------------------------------------------------------------------------------------------------------------------------------------------------


#import "stdlib1.ex4"
   int    stdlib.init  (/*EXECUTION_CONTEXT*/int ec[], int tickData[]);
   int    stdlib.start (/*EXECUTION_CONTEXT*/int ec[], int tick, datetime tickTime, int validBars, int changedBars);
   int    stdlib.deinit(/*EXECUTION_CONTEXT*/int ec[]);
   int    stdlib.GetLastError();

   int    onInit();
   int    onInitAccountChange();
   int    onInitChartChange();
   int    onInitChartClose();
   int    onInitParameterChange();
   int    onInitRecompile();
   int    onInitRemove();
   int    onInitUndefined();
   // build > 509
   int    onInitTemplate();
   int    onInitFailed();
   int    onInitClose();
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

   string GetWindowText(int hWnd);

#import "Expander.dll"
   int    ec_InitFlags            (/*EXECUTION_CONTEXT*/int ec[]);

   int    ec_setDeinitFlags       (/*EXECUTION_CONTEXT*/int ec[], int    deinitFlags       );
   int    ec_setHChart            (/*EXECUTION_CONTEXT*/int ec[], int    hChart            );
   int    ec_setHChartWindow      (/*EXECUTION_CONTEXT*/int ec[], int    hChartWindow      );
   int    ec_setInitFlags         (/*EXECUTION_CONTEXT*/int ec[], int    initFlags         );
   int    ec_setLastError         (/*EXECUTION_CONTEXT*/int ec[], int    lastError         );
   bool   ec_setLogging           (/*EXECUTION_CONTEXT*/int ec[], bool   logging           );
   string ec_setLogFile           (/*EXECUTION_CONTEXT*/int ec[], string logFile           );
   int    ec_setLpSuperContext    (/*EXECUTION_CONTEXT*/int ec[], int    lpSuperContext    );
   string ec_setProgramName       (/*EXECUTION_CONTEXT*/int ec[], string programName       );
   int    ec_setProgramType       (/*EXECUTION_CONTEXT*/int ec[], int    programType       );
   int    ec_setRootFunction      (/*EXECUTION_CONTEXT*/int ec[], int    rootFunction      );
   string ec_setSymbol            (/*EXECUTION_CONTEXT*/int ec[], string symbol            );
   int    ec_setTestFlags         (/*EXECUTION_CONTEXT*/int ec[], int    testFlags         );
   int    ec_setTimeframe         (/*EXECUTION_CONTEXT*/int ec[], int    timeframe         );
   int    ec_setUninitializeReason(/*EXECUTION_CONTEXT*/int ec[], int    uninitializeReason);

   int    GetBufferAddress(int buffer[]);
   int    GetStringsAddress(string array[]);
   bool   SetMainExecutionContext(int ec[], string name, string symbol, int period);

#import "user32.dll"
   int    GetParent(int hWnd);

#import
