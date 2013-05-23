
#define __TYPE__         T_SCRIPT
#define __lpSuperContext NULL


/**
 * Globale init()-Funktion für Scripte.
 *
 * @return int - Fehlerstatus
 */
int init() {
   if (__STATUS_ERROR)
      return(last_error);

   __WHEREAMI__ = FUNC_INIT;


   // (1) EXECUTION_CONTEXT initialisieren
   if (!ec.Signature(__ExecutionContext))
      if (IsError(InitExecutionContext()))
         return(last_error);


   // (2) stdlib initialisieren
   int iNull[];
   int error = stdlib_init(__ExecutionContext, iNull);
   if (IsError(error))
      return(SetLastError(error));                                            // #define INIT_TIMEZONE               in stdlib_init()
                                                                              // #define INIT_PIPVALUE
                                                                              // #define INIT_BARS_ON_HIST_UPDATE
   // (3) user-spezifische Init-Tasks ausführen                               // #define INIT_CUSTOMLOG
   int initFlags = ec.InitFlags(__ExecutionContext);

   if (_bool(initFlags & INIT_PIPVALUE)) {
      TickSize = MarketInfo(Symbol(), MODE_TICKSIZE);                         // schlägt fehl, wenn kein Tick vorhanden ist
      if (IsError(catch("init(1)"))) return(last_error);
      if (!TickSize)                 return(catch("init(2)   MarketInfo(TICKSIZE) = "+ NumberToStr(TickSize, ".+"), ERR_INVALID_MARKET_DATA));

      double tickValue = MarketInfo(Symbol(), MODE_TICKVALUE);
      if (IsError(catch("init(3)"))) return(last_error);
      if (!tickValue)                return(catch("init(4)   MarketInfo(TICKVALUE) = "+ NumberToStr(tickValue, ".+"), ERR_INVALID_MARKET_DATA));
   }
   if (_bool(initFlags & INIT_BARS_ON_HIST_UPDATE)) {}                        // noch nicht implementiert


   // (4) user-spezifische init()-Routinen aufrufen                           // User-Routinen *können*, müssen aber nicht implementiert werden.
   if (onInit() == -1)                                                        //
      return(last_error);                                                     // Preprocessing-Hook
                                                                              //
   switch (UninitializeReason()) {                                            //
      case REASON_PARAMETERS : error = onInitParameterChange(); break;        // Gibt eine der Funktionen einen Fehler zurück, bricht init() *nicht* ab.
      case REASON_CHARTCHANGE: error = onInitChartChange();     break;        //
      case REASON_ACCOUNT    : error = onInitAccountChange();   break;        // Gibt eine der Funktionen -1 zurück, bricht init() ab.
      case REASON_CHARTCLOSE : error = onInitChartClose();      break;        //
      case REASON_UNDEFINED  : error = onInitUndefined();       break;        //
      case REASON_REMOVE     : error = onInitRemove();          break;        //
      case REASON_RECOMPILE  : error = onInitRecompile();       break;        //
   }                                                                          //
   if (error == -1)                                                           //
      return(last_error);                                                     //
                                                                              //
   afterInit();                                                               // Postprocessing-Hook
                                                                              //
   if (__STATUS_ERROR)
      return(last_error);

   catch("init(5)");
   return(last_error);
}


#import "structs1.ex4"
   int  ec.Signature            (/*EXECUTION_CONTEXT*/int ec[]                         );
   int  ec.ChartProperties      (/*EXECUTION_CONTEXT*/int ec[]                         );
   int  ec.InitFlags            (/*EXECUTION_CONTEXT*/int ec[]                         );

   int  ec.setSignature         (/*EXECUTION_CONTEXT*/int ec[], int  signature         );
   int  ec.setLpName            (/*EXECUTION_CONTEXT*/int ec[], int  lpName            );
   int  ec.setType              (/*EXECUTION_CONTEXT*/int ec[], int  type              );
   int  ec.setChartProperties   (/*EXECUTION_CONTEXT*/int ec[], int  chartProperties   );
   int  ec.setInitFlags         (/*EXECUTION_CONTEXT*/int ec[], int  initFlags         );
   int  ec.setDeinitFlags       (/*EXECUTION_CONTEXT*/int ec[], int  deinitFlags       );
   int  ec.setUninitializeReason(/*EXECUTION_CONTEXT*/int ec[], int  uninitializeReason);
   int  ec.setWhereami          (/*EXECUTION_CONTEXT*/int ec[], int  whereami          );
   bool ec.setLogging           (/*EXECUTION_CONTEXT*/int ec[], bool logging           );
   int  ec.setLpLogFile         (/*EXECUTION_CONTEXT*/int ec[], int  lpLogFile         );
   int  ec.setLastError         (/*EXECUTION_CONTEXT*/int ec[], int  lastError         );
#import


/**
 * Initialisiert den EXECUTION_CONTEXT des Scripts.
 *
 * @return int - Fehlerstatus
 */
int InitExecutionContext() {
   if (ec.Signature(__ExecutionContext) != 0) return(catch("InitExecutionContext(1)   ec.Signature of EXECUTION_CONTEXT not NULL = "+ EXECUTION_CONTEXT.toStr(__ExecutionContext, false), ERR_ILLEGAL_STATE));


   // (1) Speicher für Programm- und LogFileName alloziieren
   string names[2]; names[0] = WindowExpertName();                                              // Programm-Name (Länge konstant)
                    names[1] = CreateString(MAX_PATH);                                          // LogFileName   (Länge variabel)

   int  lpNames[3]; CopyMemory(GetBufferAddress(lpNames),   GetStringsAddress(names)+ 4, 4);    // Zeiger auf beide Strings holen
                    CopyMemory(GetBufferAddress(lpNames)+4, GetStringsAddress(names)+12, 4);

                    CopyMemory(lpNames[1], GetBufferAddress(lpNames)+8, 1);                     // LogFileName mit <NUL> initialisieren (lpNames[2] = <NUL>)


   // (2) globale Variablen initialisieren
   int initFlags   = SumInts(__INIT_FLAGS__  );
   int deinitFlags = SumInts(__DEINIT_FLAGS__);

   __NAME__        = names[0];
   IsChart         = !IsTesting() || IsVisualMode();
 //IsOfflineChart  = IsChart && ???
   __LOG           = true;
   __LOG_CUSTOM    = false;                                                                     // Custom-Logging gibt es nur für Strategien/Experts

   PipDigits       = Digits & (~1);                                        SubPipDigits      = PipDigits+1;
   PipPoints       = MathRound(MathPow(10, Digits<<31>>31));               PipPoint          = PipPoints;
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
 * Globale start()-Funktion für Scripte.
 *
 * @return int - Fehlerstatus
 */
int start() {
   if (__STATUS_ERROR)                                                        // init()-Fehler abfangen
      return(last_error);

   int error;

   Tick++; Ticks = Tick;                                                      // einfacher Zähler, der konkrete Wert hat keine Bedeutung
   Tick.prevTime = Tick.Time;
   Tick.Time     = MarketInfo(Symbol(), MODE_TIME);
   ValidBars     = -1;
   ChangedBars   = -1;


   if (!Tick.Time) {
      error = GetLastError();
      if (error!=NO_ERROR) /*&&*/ if (error!=ERR_UNKNOWN_SYMBOL)              // ERR_UNKNOWN_SYMBOL vorerst ignorieren, da IsOfflineChart beim ersten Tick
         return(catch("start(1)", error));                                    // nicht sicher detektiert werden kann
   }


   // (1) init() war immer erfolgreich
   __WHEREAMI__                    = FUNC_START;
   __ExecutionContext[EC_WHEREAMI] = FUNC_START;


   // (2) Abschluß der Chart-Initialisierung überprüfen (kann bei Terminal-Start auftreten)
   if (!Bars)                                                                 // TODO: kann Bars bei Scripten 0 sein???
      return(catch("start(2)   Bars = 0", ERS_TERMINAL_NOT_READY));


   // (3) stdLib benachrichtigen
   if (stdlib_start(Tick, Tick.Time, ValidBars, ChangedBars) != NO_ERROR)
      return(SetLastError(stdlib_GetLastError()));


   // (4) Main-Funktion aufrufen
   onStart();

   error = GetLastError();
   if (error != NO_ERROR)
      catch("start(3)", error);

   return(last_error);
}


/**
 * Globale deinit()-Funktion für Scripte.
 *
 * @return int - Fehlerstatus
 */
int deinit() {
   __WHEREAMI__ =                               FUNC_DEINIT;
   ec.setWhereami          (__ExecutionContext, FUNC_DEINIT         );
   ec.setUninitializeReason(__ExecutionContext, UninitializeReason());


   // (1) User-spezifische deinit()-Routinen aufrufen                         // User-Routinen *können*, müssen aber nicht implementiert werden.
   int error = onDeinit();                                                    // Preprocessing-Hook
                                                                              //
   if (error != -1) {                                                         //
      switch (UninitializeReason()) {                                         //
         case REASON_PARAMETERS : error = onDeinitParameterChange(); break;   // - deinit() bricht *nicht* ab, falls eine der User-Routinen einen Fehler zurückgibt.
         case REASON_CHARTCHANGE: error = onDeinitChartChange();     break;   // - deinit() bricht ab, falls eine der User-Routinen -1 zurückgibt.
         case REASON_ACCOUNT    : error = onDeinitAccountChange();   break;   //
         case REASON_CHARTCLOSE : error = onDeinitChartClose();      break;   //
         case REASON_UNDEFINED  : error = onDeinitUndefined();       break;   //
         case REASON_REMOVE     : error = onDeinitRemove();          break;   //
         case REASON_RECOMPILE  : error = onDeinitRecompile();       break;   //
      }                                                                       //
   }                                                                          //
   if (error != -1)                                                           //
      error = afterDeinit();                                                  // Postprocessing-Hook


   // (2) User-spezifische Deinit-Tasks ausführen
   if (error != -1) {
      // ...
   }


   // (3) stdlib deinitialisieren
   error = stdlib_deinit(__ExecutionContext);
   if (IsError(error))
      SetLastError(error);

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
   return(false);
}


/**
 * Ob das aktuell ausgeführte Programm ein im Tester laufender Indikator ist.
 *
 * @return bool
 */
bool Indicator.IsTesting() {
   return(false);
}


/**
 * Ob das aktuelle Programm durch ein anderes Programm ausgeführt wird.
 *
 * @return bool
 */
bool Indicator.IsSuperContext() {
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


#import "user32.dll"
   int  GetParent(int hWnd);
#import


/**
 * Ob das aktuell ausgeführte Programm ein im Tester laufendes Script ist.
 *
 * @return bool
 */
bool Script.IsTesting() {
   static bool static.resolved, static.result;
   if (static.resolved)
      return(static.result);

   int hChart = WindowHandle(Symbol(), NULL);
   if (!hChart) {
      string function;
      switch (__WHEREAMI__) {
         case FUNC_INIT  : function = "init()";   break;
         case FUNC_START : function = "start()";  break;
         case FUNC_DEINIT: function = "deinit()"; break;
      }
      return(_false(catch("Script.IsTesting()->WindowHandle() = 0 in context Script::"+ function, ERR_RUNTIME_ERROR)));
   }

   static.result = StringEndsWith(GetWindowText(GetParent(hChart)), "(visual)");  // "(visual)" ist nicht internationalisiert

   static.resolved = true;
   return(static.result);
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
   return(Script.IsTesting());
}


/**
 * Setzt den internen Fehlercode des Scriptes.
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
    //case ERS_TERMINAL_NOT_READY:           // in Scripten ist ERS_TERMINAL_NOT_READY normaler Fehler
      case ERS_EXECUTION_STOPPING: break;

      default:
         __STATUS_ERROR = true;
   }
   return(ec.setLastError(__ExecutionContext, last_error));
}
