/**
 * NOTE: Für Wertzuweisungen an last_error muß in Indikatoren immer SetLastError() verwendet werden, wenn der Fehler
 *       bei Indikatoraufruf via iCustom() an den Aufrufer weitergereicht werden soll.
 */
#define __TYPE__ T_INDICATOR


extern string ___________________________;
extern int    __iCustom__;


/**
 * Globale init()-Funktion für Indikatoren.
 *
 * Ist das Flag __STATUS__CANCELLED gesetzt, bricht init() ab.  Nur bei Aufruf durch das Terminal wird
 * der letzte Errorcode 'last_error' in 'prev_error' gespeichert und vor Abarbeitung zurückgesetzt.
 *
 * @return int - Fehlerstatus
 */
int init() { /*throws ERR_TERMINAL_NOT_YET_READY*/
   if (__STATUS__CANCELLED)
      return(NO_ERROR);

   if (__WHEREAMI__ == NULL) {                                                // Aufruf durch Terminal
      __WHEREAMI__ = FUNC_INIT;
      prev_error   = last_error;
      last_error   = NO_ERROR;
   }

   __NAME__           = WindowExpertName();
     int initFlags    = SumInts(__INIT_FLAGS__);
   __LOG_INSTANCE_ID  = initFlags & LOG_INSTANCE_ID;
   __LOG_PER_INSTANCE = initFlags & LOG_PER_INSTANCE;



   // (1) globale Variablen re-initialisieren (Indikatoren setzen Variablen nach jedem deinit() zurück)
   //
   // Bug: Die Variablen Digits und Point sind in init() beim Öffnen eines neuen Charts und beim Accountwechsel u.U. falsch gesetzt.
   //      Nur ein Reload des Templates korrigiert die falschen Werte.
   //
   PipDigits   = Digits & (~1);
   PipPoints   = Round(MathPow(10, Digits<<31>>31));                   PipPoint = PipPoints;
   Pip         = NormalizeDouble(1/MathPow(10, PipDigits), PipDigits); Pips     = Pip;
   PriceFormat = StringConcatenate(".", PipDigits, ifString(Digits==PipDigits, "", "'"));


   // (2) stdlib re-initialisieren (Indikatoren setzen Variablen nach jedem deinit() zurück)
   int error = stdlib_init(__TYPE__, __NAME__, __WHEREAMI__, __iCustom__, initFlags, UninitializeReason());
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
      if (TickSize == 0) return(debug("init()   MarketInfo(TICKSIZE) = "+ NumberToStr(TickSize, ".+"), SetLastError(ERR_TERMINAL_NOT_YET_READY)));

      double tickValue = MarketInfo(Symbol(), MODE_TICKVALUE);
      error = GetLastError();
      if (IsError(error)) {
         if (error == ERR_UNKNOWN_SYMBOL)                                     // siehe oben bei MODE_TICKSIZE
            return(debug("init()   MarketInfo() => ERR_UNKNOWN_SYMBOL", SetLastError(ERR_TERMINAL_NOT_YET_READY)));
         return(catch("init(2)", error));
      }
      if (tickValue == 0) return(debug("init()   MarketInfo(TICKVALUE) = "+ NumberToStr(tickValue, ".+"), SetLastError(ERR_TERMINAL_NOT_YET_READY)));
   }

   if (_bool(initFlags & INIT_BARS_ON_HIST_UPDATE)) {}                        // noch nicht implementiert


   // (4) user-spezifische init()-Routinen aufrufen                           // User-Routinen *können*, müssen aber nicht implementiert werden.
   if (onInit() == -1)                                                        //
      return(last_error);                                                     // Preprocessing-Hook
                                                                              //
   switch (UninitializeReason()) {                                            //
      case REASON_PARAMETERS : error = onInitParameterChange(); break;        // Gibt eine der Funktionen einen Fehler zurück oder setzt das Flag __STATUS__CANCELLED,
      case REASON_REMOVE     : error = onInitRemove();          break;        // bricht init() *nicht* ab (um Postprocessing-Hook auch bei Fehlern ausführen zu können).
      case REASON_CHARTCHANGE: error = onInitChartChange();     break;        //
      case REASON_ACCOUNT    : error = onInitAccountChange();   break;        //
      case REASON_CHARTCLOSE : error = onInitChartClose();      break;        //
      case REASON_UNDEFINED  : error = onInitUndefined();       break;        //
      case REASON_RECOMPILE  : error = onInitRecompile();       break;        //
   }                                                                          //
   if (error == -1)                                                           // Gibt eine der Funktionen -1 zurück, bricht init() sofort ab.
      return(last_error);                                                     //
                                                                              //
   afterInit();                                                               // Postprocessing-Hook
   if (IsLastError() || __STATUS__CANCELLED)                                  //
      return(last_error);                                                     //


   // (5) nach Parameteränderung im "Indicators List"-Window nicht auf den nächsten Tick warten
   if (UninitializeReason() == REASON_PARAMETERS)
      Chart.SendTick(false);                                                  // TODO: Existenz des "Indicators List"-Windows ermitteln


   catch("init(3)");
   return(last_error);
}


/**
 * Globale start()-Funktion für Indikatoren.
 *
 * - Ist das Flag __STATUS__CANCELLED gesetzt, bricht start() ab.
 *
 * - Erfolgt der Aufruf nach einem vorherigem init()-Aufruf und init() kehrte mit ERR_TERMINAL_NOT_YET_READY zurück,
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

   int error;

   Tick++; Ticks = Tick;
   Tick.prevTime = Tick.Time;
   Tick.Time     = MarketInfo(Symbol(), MODE_TIME);                              // TODO: sicherstellen, daß Tick/Tick.Time in allen Szenarien statisch sind
   ValidBars     = IndicatorCounted();


   // (1.1) Aufruf nach init(): prüfen, ob es erfolgreich war und *nur dann* Flag zurücksetzen.
   if (__WHEREAMI__ == FUNC_INIT) {
      if (IsLastError()) {
         if (last_error != ERR_TERMINAL_NOT_YET_READY)                           // init() ist mit Fehler zurückgekehrt
            return(SetLastError(last_error));
         __WHEREAMI__ = FUNC_START;
         if (IsError(init())) {                                                  // init() erneut aufrufen (kann Neuaufruf an __WHEREAMI__ erkennen)
            __WHEREAMI__ = FUNC_INIT;                                            // erneuter Fehler, __WHEREAMI__ restaurieren und Abbruch
            return(SetLastError(last_error));
         }
      }
      last_error = NO_ERROR;                                                     // init() war erfolgreich
      ValidBars  = 0;
   }
   // (1.2) Aufruf nach Tick
   else {
      prev_error = last_error;
      last_error = NO_ERROR;

      if      (prev_error == ERR_TERMINAL_NOT_YET_READY) ValidBars = 0;
      else if (prev_error == ERR_HISTORY_UPDATE        ) ValidBars = 0;
      else if (prev_error == ERR_HISTORY_INSUFFICIENT  ) ValidBars = 0;
      if      (__STATUS__HISTORY_UPDATE                ) ValidBars = 0;          // "History update/insufficient" kann je nach Kontext Fehler und/oder Status sein.
      if      (__STATUS__HISTORY_INSUFFICIENT          ) ValidBars = 0;
   }


   // (2) Abschluß der Chart-Initialisierung überprüfen (kann bei Terminal-Start auftreten)
   if (Bars == 0) {
      debug("start()   ERR_TERMINAL_NOT_YET_READY (Bars = 0)");
      return(SetLastError(ERR_TERMINAL_NOT_YET_READY));
   }

   /*
   // (3) Werden Zeichenpuffer verwendet, muß in onTick() deren Initialisierung überprüft werden.
   if (ArraySize(buffer) == 0)
      return(SetLastError(ERR_TERMINAL_NOT_YET_READY));                          // kann bei Terminal-Start auftreten
   */

   __WHEREAMI__                   = FUNC_START;
   __STATUS__HISTORY_UPDATE       = false;
   __STATUS__HISTORY_INSUFFICIENT = false;


   // (4) ChangedBars berechnen
   ChangedBars = Bars - ValidBars;


   // (5) stdLib benachrichtigen
   if (stdlib_start(Tick, Tick.Time, ValidBars, ChangedBars) != NO_ERROR)
      return(SetLastError(stdlib_PeekLastError()));


   // (6) bei Bedarf Input-Dialog aufrufen
   if (__STATUS__RELAUNCH_INPUT) {
      __STATUS__RELAUNCH_INPUT = false;
      return(start.RelaunchInputDialog());
   }


   // (7) Main-Funktion aufrufen und auswerten
   onTick();

   if      (last_error == ERR_HISTORY_UPDATE      ) __STATUS__HISTORY_UPDATE       = true;
   else if (last_error == ERR_HISTORY_INSUFFICIENT) __STATUS__HISTORY_INSUFFICIENT = true;

   return(last_error);
}


/**
 * Globale deinit()-Funktion für Indikatoren. Ist das Flag __STATUS__CANCELLED gesetzt, bricht deinit() *nicht* ab.
 * Es liegt in der Verantwortung des Users, diesen Status selbst auszuwerten.
 *
 * @return int - Fehlerstatus
 */
int deinit() {
   __WHEREAMI__ = FUNC_DEINIT;

   // (1) User-spezifische deinit()-Routinen aufrufen                            // User-Routinen *können*, müssen aber nicht implementiert werden.
   int error = onDeinit();                                                       // Preprocessing-Hook
                                                                                 //
   if (error != -1) {                                                            //
      switch (UninitializeReason()) {                                            //
         case REASON_PARAMETERS : error = onDeinitParameterChange(); break;      // - deinit() bricht *nicht* ab, falls eine der User-Routinen einen Fehler zurückgibt oder
         case REASON_REMOVE     : error = onDeinitRemove();          break;      //   das Flag __STATUS__CANCELLED setzt.
         case REASON_CHARTCHANGE: error = onDeinitChartChange();     break;      //
         case REASON_ACCOUNT    : error = onDeinitAccountChange();   break;      // - deinit() bricht ab, falls eine der User-Routinen -1 zurückgibt.
         case REASON_CHARTCLOSE : error = onDeinitChartClose();      break;      //
         case REASON_UNDEFINED  : error = onDeinitUndefined();       break;      //
         case REASON_RECOMPILE  : error = onDeinitRecompile();       break;      //
      }                                                                          //
   }                                                                             //
   if (error != -1)                                                              //
      error = afterDeinit();                                                     // Postprocessing-Hook


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
   return(true);
}


/**
 * Ob der aktuelle Indikator via iCustom() ausgeführt wird.
 *
 * @return bool
 */
bool Indicator.IsICustom() {
   return(__iCustom__);
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
 * Ob das aktuell ausgeführte Modul eine Library ist.
 *
 * @return bool
 */
bool IsLibrary() {
   return(false);
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

   if (Indicator.IsICustom()) {                                               // Fehler an Aufrufer weiterreichen
      /*ICUSTOM*/int ic[]; error = InitializeICustom(ic, __iCustom__);

      if (IsError(error)) {
         __iCustom__ = NULL;
         last_error  = error;
      }
      else {
         ic[IC_LAST_ERROR] = last_error;
         CopyMemory(ic[IC_PTR], GetBufferAddress(ic), ICUSTOM.size);
      }
   }
   return(last_error);
}


// ------------------------------------------------------------------------------------------------------------------------------------------------


/**
 * Initialisierung Preprocessing
 *
 * @return int - Fehlerstatus
 *
int onInit() {
   return(NO_ERROR);
}


/**
 * nur extern: erste Parameter-Eingabe bei neuem Indikator, Parameter-Wechsel bei vorhandenem Indikator (auch im Tester bei ViualMode=On), Input-Dialog
 *
 * @return int - Fehlerstatus
 *
int onInitParameterChange() {
   return(NO_ERROR);
}


/**
 * nur extern: Symbol- oder Timeframe-Wechsel bei vorhandenem Indikator, kein Input-Dialog
 *
 * @return int - Fehlerstatus
 *
int onInitChartChange() {
   return(NO_ERROR);
}


/**
 * Kein UninitializeReason gesetzt.
 *
 * extern: wenn Indikator im Template (auch bei Terminal-Start und im Tester bei VisualMode=On|Off), kein Input-Dialog
 * intern: in allen init()-Fällen,                                                                   kein Input-Dialog
 *
 * @return int - Fehlerstatus
 *
int onInitUndefined() {
   return(NO_ERROR);
}


/**
 * nur extern: vorhandener Indikator, kein Input-Dialog
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


// ------------------------------------------------------------------------------------------------------------------------------------------------


/**
 * Deinitialisierung Preprocessing
 *
 * @return int - Fehlerstatus
 *
int onDeinit() {
   return(NO_ERROR);
}


/**
 * nur extern: Parameteränderung
 *
 * @return int - Fehlerstatus
 *
int onDeinitParameterChange() {
   return(NO_ERROR);
}


/**
 * nur extern: Symbol- oder Timeframewechsel
 *
 * @return int - Fehlerstatus
 *
int onDeinitChartChange() {
   return(NO_ERROR);
}


/**
 * extern: Indikator von Hand entfernt oder Chart geschlossen
 * intern: in allen deinit()-Fällen
 *
 * @return int - Fehlerstatus
 *
int onDeinitRemove() {
   return(NO_ERROR);
}


/**
 * nur extern: Recompilation
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
