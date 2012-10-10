
//#ifndef __TYPE__
   #define __TYPE__ T_SCRIPT
//#endif


/**
 * Globale init()-Funktion für Scripte.
 *
 * Ist das Flag __STATUS__CANCELLED gesetzt, bricht init() ab.  Nur bei Aufruf durch das Terminal wird
 * der letzte Errorcode 'last_error' in 'prev_error' gespeichert und vor Abarbeitung zurückgesetzt.
 *
 * @return int - Fehlerstatus
 */
int init() { /*throws ERR_TERMINAL_NOT_YET_READY*/
   if (IsLibrary())
      return(NO_ERROR);                                                       // in Libraries vorerst nichts tun
   int error;

   __NAME__           = WindowExpertName();
     int initFlags    = SumInts(__INIT_FLAGS__);
   __LOG_INSTANCE_ID  = initFlags & LOG_INSTANCE_ID;
   __LOG_PER_INSTANCE = initFlags & LOG_PER_INSTANCE;

   if (__STATUS__CANCELLED) return(NO_ERROR);

   if (__WHEREAMI__ == NULL) {                                                // Aufruf durch Terminal: last_error sichern und zurücksetzen
      __WHEREAMI__ = FUNC_INIT;
      prev_error   = last_error;
      last_error   = NO_ERROR;
   }
   if (IsTesting())
      __LOG = Tester.IsLogging();


   // (1) globale Variablen re-initialisieren (Indikatoren setzen Variablen nach jedem deinit() zurück)
   PipDigits   = Digits & (~1);
   PipPoints   = Round(MathPow(10, Digits<<31>>31));                   PipPoint = PipPoints;
   Pip         = NormalizeDouble(1/MathPow(10, PipDigits), PipDigits); Pips     = Pip;
   PriceFormat = StringConcatenate(".", PipDigits, ifString(Digits==PipDigits, "", "'"));
   //TickSize  = ...


   // (2) stdlib re-initialisieren (Indikatoren setzen Variablen nach jedem deinit() zurück)
   error = stdlib_init(__TYPE__, __NAME__, __WHEREAMI__, initFlags, UninitializeReason());
   if (IsError(error))
      return(SetLastError(error));


   // (3) user-spezifische Init-Tasks ausführen
   if (_bool(initFlags & INIT_TIMEZONE)) {}                                   // Verarbeitung nicht hier, sondern in stdlib_init()

   if (_bool(initFlags & INIT_PIPVALUE)) {                                    // schlägt fehl, wenn kein Tick vorhanden ist
      TickSize = MarketInfo(Symbol(), MODE_TICKSIZE);
      error = GetLastError();
      if (IsError(error)) {                                                   // - Symbol nicht subscribed (Start, Account-/Templatewechsel), Symbol kann noch "auftauchen"
         if (error == ERR_UNKNOWN_SYMBOL)                                     // - synthetisches Symbol im Offline-Chart
            return(debug("init()   MarketInfo() => ERR_UNKNOWN_SYMBOL", SetLastError(ERR_TERMINAL_NOT_YET_READY)));
         return(catch("init(1)", error));
      }
      if (TickSize < 0.00000001) return(debug("init()   MarketInfo(TICKSIZE) = "+ NumberToStr(TickSize, ".+"), SetLastError(ERR_TERMINAL_NOT_YET_READY)));

      double tickValue = MarketInfo(Symbol(), MODE_TICKVALUE);
      error = GetLastError();
      if (IsError(error)) {
         if (error == ERR_UNKNOWN_SYMBOL)                                     // siehe oben bei MODE_TICKSIZE
            return(debug("init()   MarketInfo() => ERR_UNKNOWN_SYMBOL", SetLastError(ERR_TERMINAL_NOT_YET_READY)));
         return(catch("init(2)", error));
      }
      if (tickValue < 0.00000001) return(debug("init()   MarketInfo(TICKVALUE) = "+ NumberToStr(tickValue, ".+"), SetLastError(ERR_TERMINAL_NOT_YET_READY)));
   }

   if (_bool(initFlags & INIT_BARS_ON_HIST_UPDATE)) {}                        // noch nicht implementiert


   // (4) nur für EA's durchzuführende globale Initialisierungen
   if (IsExpert()) {                                                          // EA's ggf. aktivieren
      int reasons1[] = { REASON_UNDEFINED, REASON_CHARTCLOSE, REASON_REMOVE };
      if (!IsTesting()) /*&&*/ if (!IsExpertEnabled()) /*&&*/ if (IntInArray(reasons1, UninitializeReason())) {
         error = Toolbar.Experts(true);                                       // !!! TODO: Bug, wenn mehrere EA's den Modus gleichzeitig umschalten
         if (IsError(error))
            return(SetLastError(error));
      }
                                                                              // nach Neuladen Orderkontext explizit zurücksetzen (siehe MQL.doc)
      int reasons2[] = { REASON_UNDEFINED, REASON_CHARTCLOSE, REASON_REMOVE, REASON_ACCOUNT };
      if (IntInArray(reasons2, UninitializeReason()))
         OrderSelect(0, SELECT_BY_TICKET);
   }


   // (5) user-spezifische init()-Routinen aufrufen                           // User-Routinen *können*, müssen aber nicht implementiert werden.
   if (onInit() == -1)                                                        //
      return(last_error);                                                     // Preprocessing-Hook
                                                                              //
   switch (UninitializeReason()) {                                            // Gibt eine der Funktionen einen Fehler zurück oder setzt das Flag __STATUS__CANCELLED,
      case REASON_UNDEFINED  : error = onInitUndefined();       break;        // bricht init() *nicht* ab.
      case REASON_CHARTCLOSE : error = onInitChartClose();      break;        //
      case REASON_REMOVE     : error = onInitRemove();          break;        // Gibt eine der Funktionen -1 zurück, bricht init() ab.
      case REASON_RECOMPILE  : error = onInitRecompile();       break;        //
      case REASON_PARAMETERS : error = onInitParameterChange(); break;        //
      case REASON_CHARTCHANGE: error = onInitChartChange();     break;        //
      case REASON_ACCOUNT    : error = onInitAccountChange();   break;        //
   }                                                                          //
   if (error == -1)                                                           //
      return(last_error);                                                     //
                                                                              //
   afterInit();                                                               // Postprocessing-Hook
   if (IsLastError() || __STATUS__CANCELLED)                                  //
      return(last_error);                                                     //


   // (6) nur bei EA's: nicht auf den nächsten echten Tick warten, sondern selbst einen Tick schicken
   if (IsExpert()) {
      if (!IsTesting())
         if (UninitializeReason() != REASON_CHARTCHANGE)                      // außer bei REASON_CHARTCHANGE
            Chart.SendTick(false);                                            // Innerhalb von init() so spät wie möglich, da Ticks aus init() verloren gehen,
                                                                              // wenn die entsprechende Message vor Verlassen von init() vom UI-Thread verarbeitet wird.
   }


   // (7) nur bei Indikatoren: nach Parameteränderung im "Indicators List"-Window nicht auf den nächsten Tick warten
   if (IsIndicator()) {
      if (UninitializeReason() == REASON_PARAMETERS)
         Chart.SendTick(false);
   }

   catch("init(4)");
   return(last_error);
}


/**
 * Globale start()-Funktion für alle MQL-Programme.
 *
 * - Ist das Flag __STATUS__CANCELLED gesetzt, bricht start() ab.
 *
 * - Erfolgt der Aufruf nach einem vorherigem init()-Aufruf und init() kehrte mit dem Fehler ERR_TERMINAL_NOT_YET_READY zurück,
 *   wird versucht, init() erneut auszuführen. Bei erneutem init()-Fehler bricht start() ab.
 *   Wurde init() fehlerfrei ausgeführt, wird der letzte Errorcode 'last_error' vor Abarbeitung zurückgesetzt.
 *
 * - Der letzte Errorcode 'last_error' wird in 'prev_error' gespeichert und vor Abarbeitung zurückgesetzt.
 *
 * @return int - Fehlerstatus
 */
int start() {
   if (__STATUS__CANCELLED)
      return(NO_ERROR);


   // Time machine bug im Tester abfangen
   if (IsTesting()) {
      static datetime lastTime;
      if (TimeCurrent() < lastTime) {
         __STATUS__CANCELLED = true;
         return(catch("start(1)   Time is running backward here:   current tick='"+ TimeToStr(TimeCurrent(), TIME_FULL) +"'   last tick='"+ TimeToStr(lastTime, TIME_FULL) +"'", ERR_RUNTIME_ERROR));
      }
      lastTime = TimeCurrent();
   }


   int error;

   Tick++; Ticks = Tick;
   ValidBars = IndicatorCounted();


   // (1) Falls wir aus init() kommen, prüfen, ob es erfolgreich war und *nur dann* Flag zurücksetzen.
   if (__WHEREAMI__ == FUNC_INIT) {
      if (IsLastError()) {                                                       // init() ist mit Fehler zurückgekehrt
         if (IsScript() || last_error!=ERR_TERMINAL_NOT_YET_READY)
            return(last_error);
         __WHEREAMI__ = FUNC_START;
         error = init();                                                         // Indikatoren und EA's können init() erneut aufrufen
         if (IsError(error)) {                                                   // erneuter Fehler
            __WHEREAMI__ = FUNC_INIT;
            return(error);
         }
      }
      last_error = NO_ERROR;                                                     // init() war (ggf. nach erneutem Aufruf) erfolgreich
      ValidBars  = 0;
   }
   else {
      prev_error = last_error;                                                   // weiterer Tick: last_error sichern und zurücksetzen
      last_error = NO_ERROR;
      if (prev_error == ERR_TERMINAL_NOT_YET_READY)
         ValidBars = 0;                                                          // falls das Terminal beim vorherigen start()-Aufruf noch nicht bereit war
   }
   __WHEREAMI__ = FUNC_START;


   // (2) bei Bedarf Input-Dialog aufrufen
   if (__STATUS__RELAUNCH_INPUT) {
      __STATUS__RELAUNCH_INPUT = false;
      return(start.RelaunchInputDialog());
   }


   // (3) Abschluß der Chart-Initialisierung überprüfen (kann bei Terminal-Start auftreten)
   if (Bars == 0) {
      debug("start()   ERR_TERMINAL_NOT_YET_READY (Bars = 0)");
      return(SetLastError(ERR_TERMINAL_NOT_YET_READY));
   }


   /*
   // (4) Werden in Indikatoren Zeichenpuffer verwendet (indicator_buffers > 0), muß deren Initialisierung überprüft werden
   //     (kann nicht hier, sondern erst in onTick() erfolgen).
   if (ArraySize(iBuffer) == 0)
      return(SetLastError(ERR_TERMINAL_NOT_YET_READY));                          // kann bei Terminal-Start auftreten
   */


   // (5) ChangedBars berechnen
   ChangedBars = Bars - ValidBars;


   // (6) stdLib benachrichtigen
   if (stdlib_start(Tick, ValidBars, ChangedBars) != NO_ERROR)
      return(SetLastError(stdlib_PeekLastError()));


   // (7) neue Main-Funktion aufrufen
   if (IsScript()) error = onStart();
   else            error = onTick();


   // (8) EA-Fehlerbehandlung
   if (error != NO_ERROR)
      if (IsTesting())
         Tester.Stop();


   return(error);
   DummyCalls();                                                                 // DummyCalls unterdrücken unnütze Compilerwarnungen
}


/**
 * Globale deinit()-Funktion für alle MQL-Programme. Ist das Flag __STATUS__CANCELLED gesetzt, bricht deinit() *nicht* ab.
 * Es liegt in der Verantwortung des Users, diesen Status selbst auszuwerten.
 *
 * @return int - Fehlerstatus
 */
int deinit() {
   __WHEREAMI__ = FUNC_DEINIT;

   if (IsLibrary())                                                              // in Libraries vorerst nichts tun
      return(NO_ERROR);


   // (1) User-spezifische deinit()-Routinen aufrufen                            // User-Routinen *können*, müssen aber nicht implementiert werden.
   int error = onDeinit();                                                       // Preprocessing-Hook
                                                                                 //
   if (error != -1) {                                                            //
      switch (UninitializeReason()) {                                            //
         case REASON_UNDEFINED  : error = onDeinitUndefined();       break;      // - deinit() bricht *nicht* ab, falls eine der User-Routinen einen Fehler zurückgibt oder
         case REASON_CHARTCLOSE : error = onDeinitChartClose();      break;      //   das Flag __STATUS__CANCELLED setzt.
         case REASON_REMOVE     : error = onDeinitRemove();          break;      //
         case REASON_RECOMPILE  : error = onDeinitRecompile();       break;      // - deinit() bricht ab, falls eine der User-Routinen -1 zurückgibt.
         case REASON_PARAMETERS : error = onDeinitParameterChange(); break;      //
         case REASON_CHARTCHANGE: error = onDeinitChartChange();     break;      //
         case REASON_ACCOUNT    : error = onDeinitAccountChange();   break;      //
      }                                                                          //
   }                                                                             //
   if (error != -1)                                                              //
      error = afterDeinit();                                                     // Postprocessing-Hook


   // (2) User-spezifische Deinit-Tasks ausführen
   if (error != -1) {
      // do something...
   }


   // (3) stdlib deinitialisieren
   error = stdlib_deinit(SumInts(__DEINIT_FLAGS__), UninitializeReason());
   if (IsError(error))
      SetLastError(error);

   return(last_error);
}


/**
 * Ob das aktuelle ausgeführte Programm ein Expert Adviser ist.
 *
 * @return bool
 */
bool IsExpert() {
   return(false);
}


/**
 * Ob das aktuelle ausgeführte Programm ein Indikator ist.
 *
 * @return bool
 */
bool IsIndicator() {
   return(false);
}


/**
 * Ob das aktuelle ausgeführte Programm ein Script ist.
 *
 * @return bool
 */
bool IsScript() {
   return(true);
}


/**
 * Ob das aktuelle ausgeführte Programm eine Library ist.
 *
 * @return bool
 */
bool IsLibrary() {
   return(false);
}
