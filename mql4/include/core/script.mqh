
#define __TYPE__ T_SCRIPT


/**
 * Globale init()-Funktion für Scripte.
 *
 * @return int - Fehlerstatus
 *
 *
 * NOTE: In Scripten ist ERR_TERMINAL_NOT_YET_READY ein fataler Fehler.
 */
int init() {
   if (__STATUS__CANCELLED)
      return(NO_ERROR);

   __WHEREAMI__       = FUNC_INIT;
   __NAME__           = WindowExpertName();
     int initFlags    = SumInts(__INIT_FLAGS__);
   __LOG_INSTANCE_ID  = initFlags & LOG_INSTANCE_ID;
   __LOG_PER_INSTANCE = initFlags & LOG_PER_INSTANCE;


   // (1) globale Variablen initialisieren
   PipDigits   = Digits & (~1);
   PipPoints   = Round(MathPow(10, Digits<<31>>31));                   PipPoint = PipPoints;
   Pip         = NormalizeDouble(1/MathPow(10, PipDigits), PipDigits); Pips     = Pip;
   PriceFormat = StringConcatenate(".", PipDigits, ifString(Digits==PipDigits, "", "'"));


   // (2) stdlib initialisieren
   int error = stdlib_init(__TYPE__, __NAME__, __WHEREAMI__, initFlags, UninitializeReason());
   if (IsError(error))
      return(SetLastError(error));


   // (3) user-spezifische Init-Tasks ausführen
   if (_bool(initFlags & INIT_TIMEZONE)) {}                                   // Verarbeitung nicht hier, sondern in stdlib_init()

   if (_bool(initFlags & INIT_PIPVALUE)) {                                    // schlägt fehl, wenn kein Tick vorhanden ist
      TickSize = MarketInfo(Symbol(), MODE_TICKSIZE);
      if (IsError(catch("init(1)"))) return(last_error);
      if (TickSize == 0)             return(catch("init(2)   MarketInfo(TICKSIZE) = "+ NumberToStr(TickSize, ".+"), ERR_INVALID_MARKET_DATA));

      double tickValue = MarketInfo(Symbol(), MODE_TICKVALUE);
      if (IsError(catch("init(3)"))) return(last_error);
      if (tickValue == 0)            return(catch("init(4)   MarketInfo(TICKVALUE) = "+ NumberToStr(tickValue, ".+"), ERR_INVALID_MARKET_DATA));
   }

   if (_bool(initFlags & INIT_BARS_ON_HIST_UPDATE)) {}                        // noch nicht implementiert


   // (4) user-spezifische init()-Routinen aufrufen                           // User-Routinen *können*, müssen aber nicht implementiert werden.
   if (onInit() == -1)                                                        //
      return(last_error);                                                     // Preprocessing-Hook
                                                                              //
   switch (UninitializeReason()) {                                            //
      case REASON_PARAMETERS : error = onInitParameterChange(); break;        // Gibt eine der Funktionen einen Fehler zurück oder setzt das Flag __STATUS__CANCELLED,
      case REASON_REMOVE     : error = onInitRemove();          break;        // bricht init() *nicht* ab.
      case REASON_CHARTCHANGE: error = onInitChartChange();     break;        //
      case REASON_ACCOUNT    : error = onInitAccountChange();   break;        // Gibt eine der Funktionen -1 zurück, bricht init() ab.
      case REASON_CHARTCLOSE : error = onInitChartClose();      break;        //
      case REASON_UNDEFINED  : error = onInitUndefined();       break;        //
      case REASON_RECOMPILE  : error = onInitRecompile();       break;        //
   }                                                                          //
   if (error == -1)                                                           //
      return(last_error);                                                     //
                                                                              //
   afterInit();                                                               // Postprocessing-Hook
   if (IsLastError() || __STATUS__CANCELLED)                                  //
      return(last_error);                                                     //


   catch("init(5)");
   return(last_error);
}


/**
 * Globale start()-Funktion für Scripte.
 *
 * @return int - Fehlerstatus
 *
 *
 * NOTE: 1) Ist das Flag __STATUS__CANCELLED gesetzt, bricht start() ab.
 *       2) Ist die Variable last_error gesetzt oder kehrte init() mit einem Fehler zurück, bricht start() ab.
 *       3) In Scripten ist ERR_TERMINAL_NOT_YET_READY ein fataler Fehler.
 */
int start() {
   if (__STATUS__CANCELLED || IsLastError())                                  // init()-Fehler abfangen
      return(last_error);

   Tick++; Ticks = Tick;
   Tick.prevTime = Tick.Time;
   Tick.Time     = TimeCurrent();
   ValidBars     = -1;
   ChangedBars   = -1;


   // (1) init() war immer erfolgreich
   __WHEREAMI__ = FUNC_START;


   // (2) Abschluß der Chart-Initialisierung überprüfen (kann bei Terminal-Start auftreten)
   if (Bars == 0)                                                             // TODO: kann Bars bei Scripten 0 sein???
      return(catch("start()   ERR_TERMINAL_NOT_YET_READY (Bars = 0)", ERR_TERMINAL_NOT_YET_READY));


   // (3) stdLib benachrichtigen
   if (stdlib_start(Tick, Tick.Time, ValidBars, ChangedBars) != NO_ERROR)
      return(SetLastError(stdlib_PeekLastError()));


   // (4) Main-Funktion aufrufen
   onStart();

   return(last_error);
}


/**
 * Globale deinit()-Funktion für Scripte.
 *
 * @return int - Fehlerstatus
 *
 *
 * NOTE: Ist das Flag __STATUS__CANCELLED gesetzt, bricht deinit() *nicht* ab. Es liegt in der Verantwortung des Scripts,
 *       diesen Status selbst auszuwerten.
 */
int deinit() {
   __WHEREAMI__ = FUNC_DEINIT;

   // (1) User-spezifische deinit()-Routinen aufrufen                         // User-Routinen *können*, müssen aber nicht implementiert werden.
   int error = onDeinit();                                                    // Preprocessing-Hook
                                                                              //
   if (error != -1) {                                                         //
      switch (UninitializeReason()) {                                         //
         case REASON_PARAMETERS : error = onDeinitParameterChange(); break;   // - deinit() bricht *nicht* ab, falls eine der User-Routinen einen Fehler zurückgibt oder
         case REASON_REMOVE     : error = onDeinitRemove();          break;   //   das Flag __STATUS__CANCELLED setzt.
         case REASON_CHARTCHANGE: error = onDeinitChartChange();     break;   //
         case REASON_ACCOUNT    : error = onDeinitAccountChange();   break;   // - deinit() bricht ab, falls eine der User-Routinen -1 zurückgibt.
         case REASON_CHARTCLOSE : error = onDeinitChartClose();      break;   //
         case REASON_UNDEFINED  : error = onDeinitUndefined();       break;   //
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
   error = stdlib_deinit(SumInts(__DEINIT_FLAGS__), UninitializeReason());
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
 * Ob das aktuell ausgeführte Programm ein Indikator ist.
 *
 * @return bool
 */
bool IsIndicator() {
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
 * Ob das aktuell ausgeführte Modul eine Library ist.
 *
 * @return bool
 */
bool IsLibrary() {
   return(false);
}


/**
 * Setzt den internen Fehlercode des Moduls.
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
   return(error);
}
