
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

   __WHEREAMI__   = FUNC_INIT;
   __NAME__       = WindowExpertName();
   __InitFlags    = SumInts(__INIT_FLAGS__);
   IsChart        = true;
 //IsOfflineChart = IsChart && ???
   __LOG          = IsLoggingEnabled();
   __LOG_CUSTOM   = __InitFlags & INIT_CUSTOMLOG;


   // (1) globale Variablen initialisieren
   PipDigits      = Digits & (~1);                                        SubPipDigits      = PipDigits+1;
   PipPoints      = MathRound(MathPow(10, Digits<<31>>31));               PipPoint          = PipPoints;
   Pip            = NormalizeDouble(1/MathPow(10, PipDigits), PipDigits); Pips              = Pip;
   PipPriceFormat = StringConcatenate(".", PipDigits);                    SubPipPriceFormat = StringConcatenate(PipPriceFormat, "'");
   PriceFormat    = ifString(Digits==PipDigits, PipPriceFormat, SubPipPriceFormat);


   // (2) stdlib initialisieren
   int iNull[];
   int error = stdlib_init(__TYPE__, __NAME__, __WHEREAMI__, IsChart, IsOfflineChart, __LOG, __lpSuperContext, __InitFlags, UninitializeReason(), iNull);
   if (IsError(error))
      return(SetLastError(error));                                            // #define INIT_TIMEZONE               in stdlib_init()
                                                                              // #define INIT_PIPVALUE
                                                                              // #define INIT_BARS_ON_HIST_UPDATE
                                                                              // #define INIT_CUSTOMLOG
   // (3) user-spezifische Init-Tasks ausführen                               // #define INIT_HSTLIB
   if (_bool(__InitFlags & INIT_PIPVALUE)) {
      TickSize = MarketInfo(Symbol(), MODE_TICKSIZE);                         // schlägt fehl, wenn kein Tick vorhanden ist
      if (IsError(catch("init(1)"))) return(last_error);
      if (!TickSize)                 return(catch("init(2)   MarketInfo(TICKSIZE) = "+ NumberToStr(TickSize, ".+"), ERR_INVALID_MARKET_DATA));

      double tickValue = MarketInfo(Symbol(), MODE_TICKVALUE);
      if (IsError(catch("init(3)"))) return(last_error);
      if (!tickValue)                return(catch("init(4)   MarketInfo(TICKVALUE) = "+ NumberToStr(tickValue, ".+"), ERR_INVALID_MARKET_DATA));
   }

   if (_bool(__InitFlags & INIT_BARS_ON_HIST_UPDATE)) {}                      // noch nicht implementiert

   if (_bool(__InitFlags & INIT_HSTLIB)) {
      error = history_init(__TYPE__, __NAME__, __WHEREAMI__, IsChart, IsOfflineChart, __LOG, __lpSuperContext, __InitFlags, UninitializeReason());
      if (IsError(error))
         return(SetLastError(error));
   }


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
   __WHEREAMI__ = FUNC_START;


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
   __WHEREAMI__  = FUNC_DEINIT;
   __DeinitFlags = SumInts(__DEINIT_FLAGS__);

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
   error = stdlib_deinit(__DeinitFlags, UninitializeReason());
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
 * Ob das aktuell ausgeführte Programm ein via iCustom() ausgeführter Indikator ist.
 *
 * @return bool
 */
bool Indicator.IsICustom() {
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
      case NO_ERROR              : break;
      case ERS_HISTORY_UPDATE    : break;
    //case ERS_TERMINAL_NOT_READY: break;    // In Scripten ist ERS_TERMINAL_NOT_READY normaler Fehler
      case ERS_EXECUTION_STOPPING: break;

      default:
         __STATUS_ERROR = true;
   }
   return(error);
}
