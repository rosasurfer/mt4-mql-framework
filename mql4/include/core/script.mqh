
#define __TYPE__         T_SCRIPT
#define __lpSuperContext NULL


/**
 * Globale init()-Funktion f�r Scripte.
 *
 * @return int - Fehlerstatus
 */
int init() {
   if (__STATUS_OFF) return(last_error);

   __WHEREAMI__ = FUNC_INIT;


   // (1) EXECUTION_CONTEXT initialisieren
   if (!ec.Signature(__ExecutionContext)) /*&&*/ if (IsError(InitExecutionContext())) {
      UpdateProgramStatus();
      if (__STATUS_OFF) return(last_error);
   }


   // (2) stdlib initialisieren
   int iNull[];
   int error = stdlib.init(__ExecutionContext, iNull);
   if (IsError(error)) {
      UpdateProgramStatus(SetLastError(error));
      if (__STATUS_OFF) return(last_error);
   }

                                                                              // #define INIT_TIMEZONE               in stdlib.init()
   // (3) user-spezifische Init-Tasks ausf�hren                               // #define INIT_PIPVALUE
   int initFlags = ec.InitFlags(__ExecutionContext);                          // #define INIT_BARS_ON_HIST_UPDATE
                                                                              // #define INIT_CUSTOMLOG
   if (initFlags & INIT_PIPVALUE && 1) {
      TickSize = MarketInfo(Symbol(), MODE_TICKSIZE);                         // schl�gt fehl, wenn kein Tick vorhanden ist
      if (IsError(catch("init(1)"))) {
         UpdateProgramStatus();
         if (__STATUS_OFF) return(last_error);
      }
      if (!TickSize)       return(UpdateProgramStatus(catch("init(2)   MarketInfo(MODE_TICKSIZE) = 0", ERR_INVALID_MARKET_DATA)));

      double tickValue = MarketInfo(Symbol(), MODE_TICKVALUE);
      if (IsError(catch("init(3)"))) {
         UpdateProgramStatus();
         if (__STATUS_OFF) return(last_error);
      }
      if (!tickValue)      return(UpdateProgramStatus(catch("init(4)   MarketInfo(MODE_TICKVALUE) = 0", ERR_INVALID_MARKET_DATA)));
   }
   if (initFlags & INIT_BARS_ON_HIST_UPDATE && 1) {}                          // noch nicht implementiert


   // (4) user-spezifische init()-Routinen aufrufen                           // User-Routinen *k�nnen*, m�ssen aber nicht implementiert werden.
   if (onInit() == -1)                                                        //
      return(UpdateProgramStatus(last_error));                                // Preprocessing-Hook
                                                                              //
   switch (UninitializeReason()) {                                            // - gibt eine der Funktionen einen normalen Fehler zur�ck, bricht init() *nicht* ab
      case REASON_PARAMETERS : error = onInitParameterChange(); break;        // - gibt eine der Funktionen -1 zur�ck, bricht init() ab
      case REASON_CHARTCHANGE: error = onInitChartChange();     break;        //
      case REASON_ACCOUNT    : error = onInitAccountChange();   break;        //
      case REASON_CHARTCLOSE : error = onInitChartClose();      break;        //
      case REASON_UNDEFINED  : error = onInitUndefined();       break;        //
      case REASON_REMOVE     : error = onInitRemove();          break;        //
      case REASON_RECOMPILE  : error = onInitRecompile();       break;        //
      // build > 509
      case REASON_TEMPLATE   : error = onInitTemplate();        break;        //
      case REASON_INITFAILED : error = onInitFailed();          break;        //
      case REASON_CLOSE      : error = onInitClose();           break;        //

      default: return(UpdateProgramStatus(catch("init(5)   unknown UninitializeReason = "+ UninitializeReason(), ERR_RUNTIME_ERROR)));
   }                                                                          //
   if (error == -1)                                                           //
      return(UpdateProgramStatus(last_error));                                 //
                                                                              //
   afterInit();                                                               // Postprocessing-Hook
                                                                              //
   return(UpdateProgramStatus(catch("init(6)")));
}


/**
 * Globale start()-Funktion f�r Scripte.
 *
 * @return int - Fehlerstatus
 */
int start() {
   if (__STATUS_OFF) {                                                        // init()-Fehler abfangen
      string msg = WindowExpertName() +": switched off ("+ ifString(!__STATUS_OFF.reason, "unknown reason", ErrorToStr(__STATUS_OFF.reason)) +")";
      Comment(NL + NL + NL + msg);                                            // 3 Zeilen Abstand f�r Instrumentanzeige und ggf. vorhandene Legende
      debug("start(1)   "+ msg);
      return(last_error);
   }

   if (!__WND_HANDLE)                                                         // Workaround um WindowHandle()-Bug ab Build 418
      __WND_HANDLE = WindowHandle(Symbol(), NULL);


   Tick++;                                                                    // einfacher Z�hler, der konkrete Wert hat keine Bedeutung
   Tick.prevTime = Tick.Time;
   Tick.Time     = MarketInfo(Symbol(), MODE_TIME);
   ValidBars     = -1;
   ChangedBars   = -1;


   if (!Tick.Time) {
      int error = GetLastError();
      if (error!=NO_ERROR) /*&&*/ if (error!=ERR_UNKNOWN_SYMBOL) {            // ERR_UNKNOWN_SYMBOL vorerst ignorieren, da IsOfflineChart beim ersten Tick
         UpdateProgramStatus(catch("start(2)", error));                       // nicht sicher detektiert werden kann
         if (__STATUS_OFF) return(last_error);
      }
   }


   // (1) init() war immer erfolgreich
   __WHEREAMI__                    = FUNC_START;
   __ExecutionContext[EC_WHEREAMI] = FUNC_START;


   // (2) Abschlu� der Chart-Initialisierung �berpr�fen (kann bei Terminal-Start auftreten)
   if (!Bars)                                                                 // Bars kann 0 sein, wenn das Script auf einem leeren Chart gestartet wird (Waiting for update...)
      return(UpdateProgramStatus(catch("start(3)   Bars = 0", ERS_TERMINAL_NOT_YET_READY))); // TODO: In Scripten in initFlags integrieren. Manche Scripte laufen nicht ohne Bars,
                                                                                             //       andere brauchen die aktuelle Zeitreihe nicht.

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
 * Globale deinit()-Funktion f�r Scripte.
 *
 * @return int - Fehlerstatus
 */
int deinit() {
   __WHEREAMI__ =                               FUNC_DEINIT;
   ec.setWhereami          (__ExecutionContext, FUNC_DEINIT         );
   ec.setUninitializeReason(__ExecutionContext, UninitializeReason());


   // (1) User-spezifische deinit()-Routinen aufrufen                         // User-Routinen *k�nnen*, m�ssen aber nicht implementiert werden.
   int error = onDeinit();                                                    // Preprocessing-Hook
                                                                              //
   if (error != -1) {                                                         //
      switch (UninitializeReason()) {                                         //
         case REASON_PARAMETERS : error = onDeinitParameterChange(); break;   // - deinit() bricht *nicht* ab, falls eine der User-Routinen einen Fehler zur�ckgibt.
         case REASON_CHARTCHANGE: error = onDeinitChartChange();     break;   // - deinit() bricht ab, falls eine der User-Routinen -1 zur�ckgibt.
         case REASON_ACCOUNT    : error = onDeinitAccountChange();   break;   //
         case REASON_CHARTCLOSE : error = onDeinitChartClose();      break;   //
         case REASON_UNDEFINED  : error = onDeinitUndefined();       break;   //
         case REASON_REMOVE     : error = onDeinitRemove();          break;   //
         case REASON_RECOMPILE  : error = onDeinitRecompile();       break;   //
         // build > 509
         case REASON_TEMPLATE   : error = onDeinitTemplate();        break;   //
         case REASON_INITFAILED : error = onDeinitFailed();          break;   //
         case REASON_CLOSE      : error = onDeinitClose();           break;   //

         default: return(UpdateProgramStatus(catch("deinit(1)   unknown UninitializeReason = "+ UninitializeReason(), ERR_RUNTIME_ERROR)));
      }                                                                       //
   }                                                                          //
   if (error != -1)                                                           //
      error = afterDeinit();                                                  // Postprocessing-Hook


   // (2) User-spezifische Deinit-Tasks ausf�hren
   if (error != -1) {
      // ...
   }


   // (3) stdlib deinitialisieren
   error = stdlib.deinit(__ExecutionContext);
   if (IsError(error))
      SetLastError(error);

   return(UpdateProgramStatus(last_error));
}


/**
 * Gibt die ID des aktuellen oder letzten Init()-Szenarios zur�ck. Kann au�er in deinit() �berall aufgerufen werden.
 *
 * @return int - ID oder NULL, falls ein Fehler auftrat
 */
int InitReason() {
   return(_NULL(catch("InitReason()", ERR_NOT_IMPLEMENTED)));
}


/**
 * Gibt die ID des aktuellen Deinit()-Szenarios zur�ck. Kann nur in deinit() aufgerufen werden.
 *
 * @return int - ID oder NULL, falls ein Fehler auftrat
 */
int DeinitReason() {
   return(_NULL(catch("DeinitReason()", ERR_NOT_IMPLEMENTED)));
}


/**
 * Ob das aktuell ausgef�hrte Programm ein Expert Adviser ist.
 *
 * @return bool
 */
bool IsExpert() {
   return(false);
}


/**
 * Ob das aktuell ausgef�hrte Programm ein Script ist.
 *
 * @return bool
 */
bool IsScript() {
   return(true);
}


/**
 * Ob das aktuell ausgef�hrte Programm ein Indikator ist.
 *
 * @return bool
 */
bool IsIndicator() {
   return(false);
}


/**
 * Ob das aktuell ausgef�hrte Modul eine Library ist.
 *
 * @return bool
 */
bool IsLibrary() {
   return(false);
}


/**
 * Ob das aktuell ausgef�hrte Programm ein im Tester laufender Expert ist.
 *
 * @return bool
 */
bool Expert.IsTesting() {
   return(false);
}


/**
 * Ob das aktuell ausgef�hrte Programm ein im Tester laufendes Script ist.
 *
 * @return bool
 */
bool Script.IsTesting() {
   static bool static.resolved, static.result;
   if (static.resolved)
      return(static.result);

   int hWnd = WindowHandle(Symbol(), NULL); if (!hWnd) hWnd = __WND_HANDLE;
   if (!hWnd)
      return(!catch("Script.IsTesting()->WindowHandle() = 0 in context Script::"+ __whereamiDescription(__WHEREAMI__), ERR_RUNTIME_ERROR));

   static.result = StringEndsWith(GetWindowText(GetParent(hWnd)), "(visual)");   // "(visual)" ist nicht internationalisiert

   static.resolved = true;
   return(static.result);
}


/**
 * Ob das aktuell ausgef�hrte Programm ein im Tester laufender Indikator ist.
 *
 * @return int - TRUE (1), FALSE (0) oder EMPTY (-1), falls ein Fehler auftrat
 */
int Indicator.IsTesting() {
   return(false);                                                    // (int) bool
}


/**
 * Ob das aktuelle Programm im Tester ausgef�hrt wird.
 *
 * @return int - TRUE (1), FALSE (0) oder EMPTY (-1), falls ein Fehler auftrat
 */
int This.IsTesting() {
   return(Script.IsTesting());
}


/**
 * Initialisiert den EXECUTION_CONTEXT des Scripts.
 *
 * @return int - Fehlerstatus
 */
int InitExecutionContext() {
   if (ec.Signature(__ExecutionContext) != 0) return(catch("InitExecutionContext(1)   ec.Signature of EXECUTION_CONTEXT not NULL = "+ EXECUTION_CONTEXT.toStr(__ExecutionContext, false), ERR_ILLEGAL_STATE));


   // (1) Speicher f�r Programm- und LogFileName alloziieren
   string names[2]; names[0] = WindowExpertName();                                              // Programm-Name (L�nge konstant)
                    names[1] = CreateString(MAX_PATH);                                          // LogFileName   (L�nge variabel)

   int  lpNames[3]; CopyMemory(GetStringsAddress(names)+ 4, GetBufferAddress(lpNames),   4);    // Zeiger auf beide Strings holen
                    CopyMemory(GetStringsAddress(names)+12, GetBufferAddress(lpNames)+4, 4);

                    CopyMemory(GetBufferAddress(lpNames)+8, lpNames[1], 1);                     // LogFileName mit <NUL> initialisieren (lpNames[2] = <NUL>)


   // (2) globale Variablen initialisieren
   int initFlags   = SumInts(__INIT_FLAGS__  );
   int deinitFlags = SumInts(__DEINIT_FLAGS__);

   __NAME__        = names[0];
   IsChart         = !IsTesting() || IsVisualMode();
 //IsOfflineChart  = IsChart && ???
   __LOG           = true;
   __LOG_CUSTOM    = false;                                                                     // Custom-Logging gibt es nur f�r Strategien/Experts

   PipDigits       = Digits & (~1);                                        SubPipDigits      = PipDigits+1;
   PipPoints       = MathRound(MathPow(10, Digits & 1));                   PipPoint          = PipPoints;
   Pip             = NormalizeDouble(1/MathPow(10, PipDigits), PipDigits); Pips              = Pip;
   PipPriceFormat  = StringConcatenate(".", PipDigits);                    SubPipPriceFormat = StringConcatenate(PipPriceFormat, "'");
   PriceFormat     = ifString(Digits==PipDigits, PipPriceFormat, SubPipPriceFormat);


   // (3) EXECUTION_CONTEXT initialisieren
   ArrayInitialize(__ExecutionContext, 0);

   ec.setSignature         (__ExecutionContext, GetBufferAddress(__ExecutionContext)                                    );
   ec.setLpName            (__ExecutionContext, lpNames[0]                                                              );
   ec.setType              (__ExecutionContext, __TYPE__                                                                );
   ec.setChartProperties   (__ExecutionContext, ifInt(IsOfflineChart, CP_OFFLINE_CHART, 0) | ifInt(IsChart, CP_CHART, 0));
   ec.setInitFlags         (__ExecutionContext, initFlags                                                               );
   ec.setDeinitFlags       (__ExecutionContext, deinitFlags                                                             );
   ec.setUninitializeReason(__ExecutionContext, UninitializeReason()                                                    );
   ec.setWhereami          (__ExecutionContext, __WHEREAMI__                                                            );
   ec.setLogging           (__ExecutionContext, __LOG                                                                   );
   ec.setLpLogFile         (__ExecutionContext, lpNames[1]                                                              );


   if (IsError(catch("InitExecutionContext(2)")))
      ArrayInitialize(__ExecutionContext, 0);
   return(last_error);
}


/**
 * Ob das aktuelle Programm durch ein anderes Programm ausgef�hrt wird.
 *
 * @return bool
 */
bool IsSuperContext() {
   return(false);
}


/**
 * Handler f�r im Script auftretende Fehler. Zur Zeit wird der Fehler nur angezeigt.
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
   last_error = error;
   return(ec.setLastError(__ExecutionContext, last_error));
}


/**
 * �berpr�ft und aktualisiert den aktuellen Programmstatus des Scripts. Setzt je nach Kontext das Flag __STATUS_OFF.
 *
 * @param  int value - der zur�ckzugebende Wert (default: NULL)
 *
 * @return int - der �bergebene Wert
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

   // Dummy-Calls: unterdr�cken unn�tze Compilerwarnungen
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

   void   CopyMemory(int source, int destination, int bytes);
   string CreateString(int length);
   string GetWindowText(int hWnd);
   bool   StringEndsWith(string object, string postfix);
   int    SumInts(int array[]);
   string __whereamiDescription(int id);

#import "StdLib.dll"
   int    GetBufferAddress(int buffer[]);
   int    GetStringsAddress(string array[]);

#import "user32.dll"
   int    GetParent(int hWnd);

#import "struct.EXECUTION_CONTEXT.ex4"
   int    ec.InitFlags            (/*EXECUTION_CONTEXT*/int ec[]);
   int    ec.Signature            (/*EXECUTION_CONTEXT*/int ec[]);

   int    ec.setChartProperties   (/*EXECUTION_CONTEXT*/int ec[], int  chartProperties   );
   int    ec.setDeinitFlags       (/*EXECUTION_CONTEXT*/int ec[], int  deinitFlags       );
   int    ec.setInitFlags         (/*EXECUTION_CONTEXT*/int ec[], int  initFlags         );
   int    ec.setLastError         (/*EXECUTION_CONTEXT*/int ec[], int  lastError         );
   bool   ec.setLogging           (/*EXECUTION_CONTEXT*/int ec[], bool logging           );
   int    ec.setLpLogFile         (/*EXECUTION_CONTEXT*/int ec[], int  lpLogFile         );
   int    ec.setLpName            (/*EXECUTION_CONTEXT*/int ec[], int  lpName            );
   int    ec.setSignature         (/*EXECUTION_CONTEXT*/int ec[], int  signature         );
   int    ec.setType              (/*EXECUTION_CONTEXT*/int ec[], int  type              );
   int    ec.setUninitializeReason(/*EXECUTION_CONTEXT*/int ec[], int  uninitializeReason);
   int    ec.setWhereami          (/*EXECUTION_CONTEXT*/int ec[], int  whereami          );

   string EXECUTION_CONTEXT.toStr (/*EXECUTION_CONTEXT*/int ec[], bool debugger);
#import
