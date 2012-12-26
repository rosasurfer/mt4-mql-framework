
#define __TYPE__    T_EXPERT
#define __iCustom__ NULL

#include <ChartInfos/functions.mqh>


/**
 * Globale init()-Funktion f�r Expert Adviser.
 *
 * Ist das Flag __STATUS_CANCELLED gesetzt, bricht init() ab.  Nur bei Aufruf durch das Terminal wird
 * der letzte Errorcode 'last_error' in 'prev_error' gespeichert und vor Abarbeitung zur�ckgesetzt.
 *
 * @return int - Fehlerstatus
 */
int init() { //throws ERR_TERMINAL_NOT_READY
   if (__STATUS_CANCELLED || __STATUS_ERROR)
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
   if (IsTesting())
      __LOG = Tester.IsLogging();


   // (1) globale Variablen re-initialisieren (Indikatoren setzen Variablen nach jedem deinit() zur�ck)
   PipDigits      = Digits & (~1);                                        SubPipDigits      = PipDigits+1;
   PipPoints      = Round(MathPow(10, Digits<<31>>31));                   PipPoint          = PipPoints;
   Pip            = NormalizeDouble(1/MathPow(10, PipDigits), PipDigits); Pips              = Pip;
   PipPriceFormat = StringConcatenate(".", PipDigits);                    SubPipPriceFormat = StringConcatenate(PipPriceFormat, "'");
   PriceFormat    = ifString(Digits==PipDigits, PipPriceFormat, SubPipPriceFormat);


   // (2) stdlib re-initialisieren (Indikatoren setzen Variablen nach jedem deinit() zur�ck)
   int error = stdlib_init(__TYPE__, __NAME__, __WHEREAMI__, __iCustom__, initFlags, UninitializeReason());
   if (IsError(error))
      return(SetLastError(error));


   // (3) user-spezifische Init-Tasks ausf�hren
   if (_bool(initFlags & INIT_TIMEZONE)) {}                                   // Verarbeitung nicht hier, sondern in stdlib_init()

   if (_bool(initFlags & INIT_PIPVALUE)) {                                    // schl�gt fehl, wenn kein Tick vorhanden ist
      TickSize = MarketInfo(Symbol(), MODE_TICKSIZE);
      error = GetLastError();
      if (IsError(error)) {                                                   // - Symbol nicht subscribed (Start, Account-/Templatewechsel), Symbol kann noch "auftauchen"
         if (error == ERR_UNKNOWN_SYMBOL)                                     // - synthetisches Symbol im Offline-Chart
            return(debug("init()   MarketInfo() => ERR_UNKNOWN_SYMBOL", SetLastError(ERR_TERMINAL_NOT_READY)));
         return(catch("init(1)", error));
      }
      if (TickSize == 0) return(debug("init()   MarketInfo(TICKSIZE) = "+ NumberToStr(TickSize, ".+"), SetLastError(ERR_TERMINAL_NOT_READY)));

      double tickValue = MarketInfo(Symbol(), MODE_TICKVALUE);
      error = GetLastError();
      if (IsError(error)) {
         if (error == ERR_UNKNOWN_SYMBOL)                                     // siehe oben bei MODE_TICKSIZE
            return(debug("init()   MarketInfo() => ERR_UNKNOWN_SYMBOL", SetLastError(ERR_TERMINAL_NOT_READY)));
         return(catch("init(2)", error));
      }
      if (tickValue == 0) return(debug("init()   MarketInfo(TICKVALUE) = "+ NumberToStr(tickValue, ".+"), SetLastError(ERR_TERMINAL_NOT_READY)));
   }

   if (_bool(initFlags & INIT_BARS_ON_HIST_UPDATE)) {}                        // noch nicht implementiert


   // (4)  EA's ggf. aktivieren
   int reasons1[] = { REASON_UNDEFINED, REASON_CHARTCLOSE, REASON_REMOVE };
   if (!IsTesting()) /*&&*/ if (!IsExpertEnabled()) /*&&*/ if (IntInArray(reasons1, UninitializeReason())) {
      error = Toolbar.Experts(true);                                          // !!! TODO: Bug, wenn mehrere EA's den Modus gleichzeitig umschalten
      if (IsError(error))
         return(SetLastError(error));
   }


   // (5) nach Neuladen Orderkontext explizit zur�cksetzen (siehe MQL.doc)
   int reasons2[] = { REASON_UNDEFINED, REASON_CHARTCLOSE, REASON_REMOVE, REASON_ACCOUNT };
   if (IntInArray(reasons2, UninitializeReason()))
      OrderSelect(0, SELECT_BY_TICKET);


   // (6) im Tester ChartInfo-Anzeige konfigurieren
   if (IsVisualMode()) {
      chartInfo.appliedPrice = PRICE_BID;                                     // PRICE_BID ist in EA's ausreichend und schneller (@see ChartInfos-Indikator)
      chartInfo.leverage     = GetGlobalConfigDouble("Leverage", "CurrencyPair", 1);
      if (LT(chartInfo.leverage, 1))
         return(catch("init(3)   invalid configuration value [Leverage] CurrencyPair = "+ NumberToStr(chartInfo.leverage, ".+"), ERR_INVALID_CONFIG_PARAMVALUE));
      if (IsError(ChartInfo.CreateLabels()))
         return(last_error);
   }


   // (7) user-spezifische init()-Routinen aufrufen                           // User-Routinen *k�nnen*, m�ssen aber nicht implementiert werden.
   if (onInit() == -1)                                                        //
      return(last_error);                                                     // Preprocessing-Hook
                                                                              //
   switch (UninitializeReason()) {                                            //
      case REASON_PARAMETERS : error = onInitParameterChange(); break;        // Gibt eine der Funktionen einen Fehler zur�ck oder setzt das Flag __STATUS_CANCELLED,
      case REASON_REMOVE     : error = onInitRemove();          break;        // bricht init() *nicht* ab.
      case REASON_CHARTCHANGE: error = onInitChartChange();     break;        //
      case REASON_ACCOUNT    : error = onInitAccountChange();   break;        // Gibt eine der Funktionen -1 zur�ck, bricht init() ab.
      case REASON_CHARTCLOSE : error = onInitChartClose();      break;        //
      case REASON_UNDEFINED  : error = onInitUndefined();       break;        //
      case REASON_RECOMPILE  : error = onInitRecompile();       break;        //
   }                                                                          //
   if (error == -1)                                                           //
      return(last_error);                                                     //
                                                                              //
   afterInit();                                                               // Postprocessing-Hook
   if (__STATUS_CANCELLED || __STATUS_ERROR)                                  //
      return(last_error);                                                     //


   // (8) au�er bei REASON_CHARTCHANGE nicht auf den n�chsten echten Tick warten, sondern sofort selbst einen Tick schicken
   if (!IsTesting())
      if (UninitializeReason() != REASON_CHARTCHANGE)
         Chart.SendTick(false);                                               // Ganz zum Schlu�, da Ticks aus init() verloren gehen, wenn die entsprechende Windows-Message
                                                                              // vor Verlassen von init() vom UI-Thread verarbeitet wird.

   catch("init(4)");
   return(last_error);
}


// --------------------------------------------------------------------------------------------------------------------------------------------------


/**
 * Nach Parameter�nderung
 *
 *  - altes Chartfenster, alter EA, Input-Dialog
 *
 * @return int - Fehlerstatus
int onInitParameterChange() {
   return(NO_ERROR);
}


/**
 * Vorheriger EA von Hand entfernt (Chart->Expert->Remove) oder neuer EA dr�bergeladen
 *
 * - altes Chartfenster, neuer EA, Input-Dialog
 *
 * @return int - Fehlerstatus
int onInitRemove() {
   return(NO_ERROR);
}


/**
 * Nach Symbol- oder Timeframe-Wechsel
 *
 * - altes Chartfenster, alter EA, kein Input-Dialog
 *
 * @return int - Fehlerstatus
int onInitChartChange() {
   return(NO_ERROR);
}


/**
 * Nach Accountwechsel (wann ???)                                    // TODO: Umst�nde ungekl�rt
 *
 * - wird in stdlib abgefangen (ERR_RUNTIME_ERROR)
 *
 * @return int - Fehlerstatus
int onInitAccountChange() {
   return(NO_ERROR);
}


/**
 * Altes Chartfenster mit neu geladenem Template
 *
 * - neuer EA, Input-Dialog
 *
 * @return int - Fehlerstatus
int onInitChartClose() {
   return(NO_ERROR);
}


/**
 * Kein UninitializeReason gesetzt
 *
 * - nach Terminal-Neustart:    neues Chartfenster, vorheriger EA, kein Input-Dialog
 * - nach File -> New -> Chart: neues Chartfenster, neuer EA, Input-Dialog
 *
 * @return int - Fehlerstatus
int onInitUndefined() {
   return(NO_ERROR);
}


/**
 * Nach Recompilation
 *
 * - altes Chartfenster, vorheriger EA, kein Input-Dialog
 *
 * @return int - Fehlerstatus
int onInitRecompile() {
   return(NO_ERROR);
}
 */


// --------------------------------------------------------------------------------------------------------------------------------------------------


/**
 * Globale start()-Funktion f�r Expert Adviser.
 *
 * - Ist das Flag __STATUS_CANCELLED gesetzt, bricht start() ab.
 *
 * - Erfolgt der Aufruf nach einem vorherigem init()-Aufruf und init() kehrte mit dem Fehler ERR_TERMINAL_NOT_READY zur�ck,
 *   wird versucht, init() erneut auszuf�hren. Bei erneutem init()-Fehler bricht start() ab.
 *   Wurde init() fehlerfrei ausgef�hrt, wird der letzte Errorcode 'last_error' vor Abarbeitung zur�ckgesetzt.
 *
 * - Der letzte Errorcode 'last_error' wird in 'prev_error' gespeichert und vor Abarbeitung zur�ckgesetzt.
 *
 * @return int - Fehlerstatus
 */
int start() {
   if (__STATUS_CANCELLED || __STATUS_ERROR) {
      ShowStatus();
      return(NO_ERROR);
   }


   // "Time machine"-Bug im Tester abfangen
   if (IsTesting()) {
      static datetime time, lastTime;
      time = TimeCurrent();
      if (time < lastTime) {
         catch("start()   Bug in TimeCurrent()/MarketInfo(MODE_TIME) testen !!!\nTime is running backward here:   previous='"+ TimeToStr(lastTime, TIME_FULL) +"'   current='"+ TimeToStr(time, TIME_FULL) +"'", ERR_RUNTIME_ERROR);
         ShowStatus();
         return(last_error);
      }
      lastTime = time;
   }


   int error;

   Tick++; Ticks = Tick;
   Tick.prevTime = Tick.Time;
   Tick.Time     = MarketInfo(Symbol(), MODE_TIME);                           // TODO: sicherstellen, da� Tick/Tick.Time in allen Szenarien statisch sind
   ValidBars     = -1;
   ChangedBars   = -1;


   // (1) Falls wir aus init() kommen, pr�fen, ob es erfolgreich war und *nur dann* Flag zur�cksetzen.
   if (__WHEREAMI__ == FUNC_INIT) {
      if (IsLastError()) {
         if (last_error != ERR_TERMINAL_NOT_READY) {                          // init() ist mit hartem Fehler zur�ckgekehrt
            ShowStatus();
            return(last_error);
         }
         __WHEREAMI__ = FUNC_START;
         if (IsError(init())) {                                               // init() erneut aufrufen
            __WHEREAMI__ = FUNC_INIT;                                         // erneuter Fehler (hart oder weich)
            ShowStatus();
            return(last_error);
         }
      }
      last_error                   = NO_ERROR;                                // init() war erfolgreich
   }
   else {
      prev_error = last_error;                                                // weiterer Tick: last_error sichern und zur�cksetzen
      last_error = NO_ERROR;
   }
   __WHEREAMI__ = FUNC_START;


   // (2) bei Bedarf Input-Dialog aufrufen
   if (__STATUS_RELAUNCH_INPUT) {
      __STATUS_RELAUNCH_INPUT = false;
      start.RelaunchInputDialog();
      ShowStatus();
      return(last_error);
   }


   // (3) Abschlu� der Chart-Initialisierung �berpr�fen (kann bei Terminal-Start auftreten)
   if (Bars == 0) {
      SetLastError(debug("start()   Bars = 0", ERR_TERMINAL_NOT_READY));
      ShowStatus();
      return(last_error);
   }


   // (4) stdLib benachrichtigen
   if (stdlib_start(Tick, Tick.Time, ValidBars, ChangedBars) != NO_ERROR) {
      SetLastError(stdlib_GetLastError());
      ShowStatus();
      return(last_error);
   }


   // (5) im Tester ChartInfos-Anzeige (@see ChartInfos-Indikator)
   if (IsVisualMode()) {
      error = NO_ERROR;
      chartInfo.positionChecked = false;
      error |= ChartInfo.UpdatePrice();
      error |= ChartInfo.UpdateSpread();
      error |= ChartInfo.UpdateUnitSize();
      error |= ChartInfo.UpdatePosition();
      error |= ChartInfo.UpdateTime();
      error |= ChartInfo.UpdateMarginLevels();
      if (error != NO_ERROR) {                                                // error ist hier die Summe aller in ChartInfo.* aufgetretenen Fehler
         ShowStatus();
         return(last_error);
      }
   }


   // (6) Main-Funktion aufrufen und auswerten
   onTick();


   if (last_error != NO_ERROR)
      if (IsTesting())
         Tester.Stop();
   ShowStatus();
   return(last_error);
}


/**
 * Globale deinit()-Funktion f�r Expert Adviser.
 *
 * @return int - Fehlerstatus
 *
 *
 * NOTE: 1) Ist das Flag __STATUS_CANCELLED gesetzt, bricht deinit() *nicht* ab. Es liegt in der Verantwortung des EA's, diesen Status
 *          selbst auszuwerten.
 *
 *       2) Bei VisualMode=Off und regul�rem Testende (Testperiode zu Ende = REASON_UNDEFINED) bricht das Terminal komplexere deinit()-Funktionen verfr�ht ab.
 *          In der Regel wird afterDeinit() schon nicht mehr ausgef�hrt. In diesem Fall werden die deinit()-Funktionen von geladenen Libraries auch nicht mehr
 *          ausgef�hrt.
 *
 *          TODO:       Testperiode auslesen und Test nach dem letzten Tick per Tester.Stop() beenden
 *          Workaround: Testende im EA direkt vors regul�re Testende der Historydatei setzen
 */
int deinit() {
   __WHEREAMI__ = FUNC_DEINIT;


   // (1) User-spezifische deinit()-Routinen aufrufen                            // User-Routinen *k�nnen*, m�ssen aber nicht implementiert werden.
   int error = onDeinit();                                                       // Preprocessing-Hook
                                                                                 //
   if (error != -1) {                                                            //
      switch (UninitializeReason()) {                                            //
         case REASON_PARAMETERS : error = onDeinitParameterChange(); break;      // - deinit() bricht *nicht* ab, falls eine der User-Routinen einen Fehler zur�ckgibt oder
         case REASON_REMOVE     : error = onDeinitRemove();          break;      //   das Flag __STATUS_CANCELLED setzt.
         case REASON_CHARTCHANGE: error = onDeinitChartChange();     break;      //
         case REASON_ACCOUNT    : error = onDeinitAccountChange();   break;      // - deinit() bricht ab, falls eine der User-Routinen -1 zur�ckgibt.
         case REASON_CHARTCLOSE : error = onDeinitChartClose();      break;      //
         case REASON_UNDEFINED  : error = onDeinitUndefined();       break;      //
         case REASON_RECOMPILE  : error = onDeinitRecompile();       break;      //
      }                                                                          //
   }                                                                             //
                                                                                 //
   if (error != -1)                                                              //
      error = afterDeinit();                                                     // Postprocessing-Hook


   // (2) User-spezifische Deinit-Tasks ausf�hren
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
 * Ob das aktuell ausgef�hrte Programm ein Expert Adviser ist.
 *
 * @return bool
 */
bool IsExpert() {
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
 * Ob der aktuelle Indikator via iCustom() ausgef�hrt wird.
 *
 * @return bool
 */
bool Indicator.IsICustom() {
   return(false);
}


/**
 * Ob das aktuell ausgef�hrte Programm ein Script ist.
 *
 * @return bool
 */
bool IsScript() {
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

   switch (error) {
      case NO_ERROR                 : break;
      case STATUS_HISTORY_UPDATE    : break;
      case STATUS_TERMINAL_NOT_READY: break;
      case STATUS_CANCELLED_BY_USER : break;
      case STATUS_EXECUTION_STOPPING: break;
      case STATUS_ORDER_CHANGED     : break;

      default:
         __STATUS_ERROR = true;
   }
   return(error);
}


/**
 * Pr�ft, ob der aktuelle Tick in den angegebenen Timeframes ein BarOpen-Event darstellt. Auch bei wiederholten Aufrufen w�hrend
 * desselben Ticks wird das Event korrekt erkannt.
 *
 * @param  int results[] - Array, das die IDs der Timeframes aufnimmt, in denen das Event aufgetreten ist (mehrere sind m�glich)
 * @param  int flags     - Flags ein oder mehrerer zu pr�fender Timeframes (default: der aktuelle Timeframe)
 *
 * @return bool - ob mindestens ein BarOpen-Event aufgetreten ist
 */
bool EventListener.BarOpen(int results[], int flags=NULL) {
   if (ArraySize(results) != 0)
      ArrayResize(results, 0);

   if (flags == NULL)
      flags = PeriodFlag(Period());

   // (1) Aufruf bei erstem Tick             // (2) oder Aufruf bei weiterem Tick
   //     Tick.prevTime = 0;                 //     Tick.prevTime = time[1];
   //     Tick.Time     = time[0];           //     Tick.Time     = time[0];

   static int sizeOfPeriods, periods    []={  PERIOD_M1,   PERIOD_M5,   PERIOD_M15,   PERIOD_M30,   PERIOD_H1,   PERIOD_H4,   PERIOD_D1,   PERIOD_W1},
                             periodFlags[]={F_PERIOD_M1, F_PERIOD_M5, F_PERIOD_M15, F_PERIOD_M30, F_PERIOD_H1, F_PERIOD_H4, F_PERIOD_D1, F_PERIOD_W1};
   static datetime bar.openTimes[], bar.closeTimes[];
   if (sizeOfPeriods == 0) {                                         // TODO: Listener f�r PERIOD_MN1 implementieren
      sizeOfPeriods = ArraySize(periods);
      ArrayResize(bar.openTimes,  F_PERIOD_W1+1);
      ArrayResize(bar.closeTimes, F_PERIOD_W1+1);
   }

   for (int pFlag, i=0; i < sizeOfPeriods; i++) {
      pFlag = periodFlags[i];
      if (flags & pFlag != 0) {
         // BarOpen/Close-Time des aktuellen Ticks ggf. neuberechnen
         if (Tick.Time >= bar.closeTimes[pFlag]) {
            bar.openTimes [pFlag] = Tick.Time - Tick.Time % (periods[i]*MINUTES);
            bar.closeTimes[pFlag] = bar.openTimes[pFlag] +  (periods[i]*MINUTES);
         }
         // vorherigen Tick auswerten
         if (Tick.prevTime < bar.openTimes[pFlag]) {
            //if (Tick.prevTime != 0) ArrayPushInt(results, periods[i]);
            //else if (IsTesting())   ArrayPushInt(results, periods[i]);

            if (Tick.prevTime == 0) {
               if (IsTesting()) {                                    // nur im Tester ist der 1. Tick BarOpen-Event
                  ArrayPushInt(results, periods[i]);                 // TODO: !!! nicht f�r alle Timeframes !!!
                  //debug("EventListener.BarOpen()   event("+ PeriodToStr(periods[i]) +")=1   tick="+ TimeToStr(Tick.Time, TIME_FULL) +"   tick="+ Tick);
               }
            }
            else {
               ArrayPushInt(results, periods[i]);
               //debug("EventListener.BarOpen()   event("+ PeriodToStr(periods[i]) +")=1   tick="+ TimeToStr(Tick.Time, TIME_FULL));
            }
         }
      }
   }

   if (IsError(catch("EventListener.BarOpen()")))
      return(false);
   return(ArraySize(results));                                       // (bool) int
}
