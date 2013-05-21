
#define __TYPE__         T_EXPERT
#define __lpSuperContext NULL

#include <history.mqh>
#include <ChartInfos/functions.mqh>


// Teststatistiken
datetime Test.fromDate,    Test.toDate;
int      Test.startMillis, Test.stopMillis;                          // in Millisekunden


/**
 * Globale init()-Funktion für Experts.
 *
 * Bei Aufruf durch das Terminal wird der letzte Errorcode 'last_error' in 'prev_error' gespeichert und vor Abarbeitung
 * zurückgesetzt.
 *
 * @return int - Fehlerstatus
 */
int init() { // throws ERS_TERMINAL_NOT_READY
   if (__STATUS_ERROR)
      return(last_error);

   if (__WHEREAMI__ == NULL) {                                       // Aufruf durch Terminal
      __WHEREAMI__ = FUNC_INIT;
      prev_error   = last_error;
      last_error   = NO_ERROR;
   }


   // (1) EXECUTION_CONTEXT initialisieren
   if (!__lpExecutionContext) {
      InitExecutionContext();
      //EXECUTION_CONTEXT.toStr(__ExecutionContext, true);
   }


   // (2) stdlib (re-)initialisieren
   int iNull[], initFlags=ec.InitFlags(__ExecutionContext);
   int error = stdlib_init(__TYPE__, __NAME__, __WHEREAMI__, IsChart, IsOfflineChart, __LOG, __lpSuperContext, initFlags, UninitializeReason(), iNull);
   if (IsError(error))
      return(SetLastError(error));


   // (3) in Experts auch die history-lib (re-)initialisieren
   error = history_init(__TYPE__, __NAME__, __WHEREAMI__, IsChart, IsOfflineChart, __LOG, __lpSuperContext, initFlags, UninitializeReason());
   if (IsError(error))
      return(SetLastError(error));                                            // #define INIT_TIMEZONE               in stdlib_init()
                                                                              // #define INIT_PIPVALUE
                                                                              // #define INIT_BARS_ON_HIST_UPDATE
   // (4) user-spezifische Init-Tasks ausführen                               // #define INIT_CUSTOMLOG
   if (_bool(initFlags & INIT_PIPVALUE)) {
      TickSize = MarketInfo(Symbol(), MODE_TICKSIZE);                         // schlägt fehl, wenn kein Tick vorhanden ist
      error = GetLastError();
      if (IsError(error)) {                                                   // - Symbol nicht subscribed (Start, Account-/Templatewechsel), Symbol kann noch "auftauchen"
         if (error == ERR_UNKNOWN_SYMBOL)                                     // - synthetisches Symbol im Offline-Chart
            return(debug("init()   MarketInfo() => ERR_UNKNOWN_SYMBOL", SetLastError(ERS_TERMINAL_NOT_READY)));
         return(catch("init(1)", error));
      }
      if (!TickSize) return(debug("init()   MarketInfo(TICKSIZE) = "+ NumberToStr(TickSize, ".+"), SetLastError(ERS_TERMINAL_NOT_READY)));

      double tickValue = MarketInfo(Symbol(), MODE_TICKVALUE);
      error = GetLastError();
      if (IsError(error)) {
         if (error == ERR_UNKNOWN_SYMBOL)                                     // siehe oben bei MODE_TICKSIZE
            return(debug("init()   MarketInfo() => ERR_UNKNOWN_SYMBOL", SetLastError(ERS_TERMINAL_NOT_READY)));
         return(catch("init(2)", error));
      }
      if (!tickValue) return(debug("init()   MarketInfo(TICKVALUE) = "+ NumberToStr(tickValue, ".+"), SetLastError(ERS_TERMINAL_NOT_READY)));
   }
   if (_bool(initFlags & INIT_BARS_ON_HIST_UPDATE)) {}                        // noch nicht implementiert


   // (5)  EA's ggf. aktivieren
   int reasons1[] = { REASON_UNDEFINED, REASON_CHARTCLOSE, REASON_REMOVE };
   if (!IsTesting()) /*&&*/ if (!IsExpertEnabled()) /*&&*/ if (IntInArray(reasons1, UninitializeReason())) {
      error = Toolbar.Experts(true);                                          // !!! TODO: Bug, wenn mehrere EA's den Modus gleichzeitig umschalten
      if (IsError(error))
         return(SetLastError(error));
   }


   // (6) nach Neuladen Orderkontext explizit zurücksetzen (siehe MQL.doc)
   int reasons2[] = { REASON_UNDEFINED, REASON_CHARTCLOSE, REASON_REMOVE, REASON_ACCOUNT };
   if (IntInArray(reasons2, UninitializeReason()))
      OrderSelect(0, SELECT_BY_TICKET);


   // (7) im Tester ChartInfo-Anzeige konfigurieren
   if (IsVisualMode()) {
      chartInfo.appliedPrice = PRICE_BID;                                     // PRICE_BID ist in EA's ausreichend und schneller (@see ChartInfos-Indikator)
      chartInfo.leverage     = GetGlobalConfigDouble("Leverage", "CurrencyPair", 1);
      if (LT(chartInfo.leverage, 1))
         return(catch("init(3)   invalid configuration value [Leverage] CurrencyPair = "+ NumberToStr(chartInfo.leverage, ".+"), ERR_INVALID_CONFIG_PARAMVALUE));
      if (IsError(ChartInfo.CreateLabels()))
         return(last_error);
   }

                                                                              // User-Routinen *können*, müssen aber nicht implementiert werden.
   // (8) user-spezifische init()-Routinen aufrufen                           //
   onInit();                                                                  // Preprocessing-Hook
                                                                              //
   if (!__STATUS_ERROR) {                                                     //
      switch (UninitializeReason()) {                                         //
         case REASON_PARAMETERS : error = onInitParameterChange(); break;     //
         case REASON_CHARTCHANGE: error = onInitChartChange();     break;     //
         case REASON_ACCOUNT    : error = onInitAccountChange();   break;     //
         case REASON_CHARTCLOSE : error = onInitChartClose();      break;     //
         case REASON_UNDEFINED  : error = onInitUndefined();       break;     //
         case REASON_REMOVE     : error = onInitRemove();          break;     //
         case REASON_RECOMPILE  : error = onInitRecompile();       break;     //
      }                                                                       //
   }                                                                          //
                                                                              //
   afterInit();                                                               // Postprocessing-Hook wird immer ausgeführt (auch bei __STATUS_ERROR)
   ShowStatus();                                                              //

   if (__STATUS_ERROR)
      return(last_error);


   // (9) Außer bei REASON_CHARTCHANGE nicht auf den nächsten echten Tick warten, sondern selbst einen Tick schicken.
   if (IsTesting()) {
      Test.fromDate    = TimeCurrent();
      Test.startMillis = GetTickCount();
   }
   else if (UninitializeReason() != REASON_CHARTCHANGE) {                     // Ganz zum Schluß, da Ticks verloren gehen, wenn die entsprechende Windows-Message
      error = Chart.SendTick(false);                                          // vor Verlassen von init() verarbeitet wird.
      if (IsError(error))
         SetLastError(error);
   }
   return(last_error|catch("init(4)"));
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
#import


/**
 * Initialisiert den EXECUTION_CONTEXT des Experts.
 *
 * @return int - Fehlerstatus
 *
 *
 * NOTE: In Experts liegt das Original des EXECUTION_CONTEXT im Expert, Libraries halten eine Kopie.
 */
int InitExecutionContext() {
   if (__lpExecutionContext != 0) return(catch("InitExecutionContext(1)   __lpExecutionContext not NULL: 0x"+ IntToHexStr(__lpExecutionContext), ERR_ILLEGAL_STATE));


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
   __LOG           = IsLogging();
   __LOG_CUSTOM    = initFlags & INIT_CUSTOMLOG;

   PipDigits       = Digits & (~1);                                        SubPipDigits      = PipDigits+1;
   PipPoints       = MathRound(MathPow(10, Digits<<31>>31));               PipPoint          = PipPoints;
   Pip             = NormalizeDouble(1/MathPow(10, PipDigits), PipDigits); Pips              = Pip;
   PipPriceFormat  = StringConcatenate(".", PipDigits);                    SubPipPriceFormat = StringConcatenate(PipPriceFormat, "'");
   PriceFormat     = ifString(Digits==PipDigits, PipPriceFormat, SubPipPriceFormat);


   // (3) EXECUTION_CONTEXT initialisieren
   ArrayResize    (__ExecutionContext, EXECUTION_CONTEXT.intSize);
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

   __lpExecutionContext = ec.Signature(__ExecutionContext);


   if (IsError(catch("InitExecutionContext(2)")))
      __lpExecutionContext = 0;
   return(last_error);
}


/**
 * Globale start()-Funktion für Expert Adviser.
 *
 * - Erfolgt der Aufruf nach einem vorherigem init()-Aufruf und init() kehrte mit dem Fehler ERS_TERMINAL_NOT_READY zurück,
 *   wird versucht, init() erneut auszuführen. Bei erneutem init()-Fehler bricht start() ab.
 *   Wurde init() fehlerfrei ausgeführt, wird der letzte Errorcode 'last_error' vor Abarbeitung zurückgesetzt.
 *
 * - Der letzte Errorcode 'last_error' wird in 'prev_error' gespeichert und vor Abarbeitung zurückgesetzt.
 *
 * @return int - Fehlerstatus
 */
int start() {
   if (__STATUS_ERROR) {
      ShowStatus();
      return(last_error);
   }


   // "Time machine"-Bug im Tester abfangen
   if (IsTesting()) {
      static datetime time, lastTime;
      time = TimeCurrent();
      if (time < lastTime) {
         catch("start(1)   Bug in TimeCurrent()/MarketInfo(MODE_TIME) testen !!!\nTime is running backward here:   previous='"+ TimeToStr(lastTime, TIME_FULL) +"'   current='"+ TimeToStr(time, TIME_FULL) +"'", ERR_RUNTIME_ERROR);
         ShowStatus();
         return(last_error);
      }
      lastTime = time;
   }


   int error;
                                                                     // einfacher Zähler, der konkrete Wert hat keine Bedeutung
   Tick++; Ticks = Tick;
   Tick.prevTime = Tick.Time;
   Tick.Time     = MarketInfo(Symbol(), MODE_TIME);
   ValidBars     = -1;
   ChangedBars   = -1;


   // (1) Falls wir aus init() kommen, prüfen, ob es erfolgreich war und *nur dann* Flag zurücksetzen.
   if (__WHEREAMI__ == FUNC_INIT) {
      if (IsLastError()) {
         if (last_error != ERS_TERMINAL_NOT_READY) {                 // init() ist mit hartem Fehler zurückgekehrt
            ShowStatus();
            return(last_error);
         }
         __WHEREAMI__ = FUNC_START;
         if (IsError(init())) {                                      // init() erneut aufrufen
            __WHEREAMI__ = FUNC_INIT;                                // erneuter Fehler (hart oder weich)
            ShowStatus();
            return(last_error);
         }
      }
      last_error = NO_ERROR;                                         // init() war erfolgreich
   }
   else {
      prev_error = last_error;                                       // weiterer Tick: last_error sichern und zurücksetzen
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


   // (3) Abschluß der Chart-Initialisierung überprüfen (kann bei Terminal-Start auftreten)
   if (!Bars) {
      SetLastError(debug("start()   Bars = 0", ERS_TERMINAL_NOT_READY));
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
      if (error != NO_ERROR) {                                       // error ist hier die Summe aller in ChartInfo.* aufgetretenen Fehler
         ShowStatus();
         return(last_error);
      }
   }


   // (6) Main-Funktion aufrufen und auswerten
   onTick();

   error = GetLastError();
   if (error != NO_ERROR)
      catch("start(2)", error);


   // (7) Tester nach Fehler anhalten
   if (last_error!=NO_ERROR) /*&&*/ if (IsTesting())
      Tester.Stop();


   ShowStatus();
   return(last_error);
}


/**
 * Globale deinit()-Funktion für Expert Adviser.
 *
 * @return int - Fehlerstatus
 *
 *
 * NOTE: Bei VisualMode=Off und regulärem Testende (Testperiode zu Ende = REASON_UNDEFINED) bricht das Terminal komplexere deinit()-Funktionen verfrüht ab.
 *       afterDeinit() und stdlib_deinit() werden u.U. schon nicht mehr ausgeführt.
 *
 *       Workaround: Testperiode auslesen (Controls), letzten Tick ermitteln (Historydatei) und Test nach letztem Tick per Tester.Stop() beenden.
 *                   Alternativ bei EA's, die dies unterstützen, Testende vors reguläre Testende der Historydatei setzen.
 */
int deinit() {
   __WHEREAMI__    = FUNC_DEINIT;
   int deinitFlags = SumInts(__DEINIT_FLAGS__);

   if (IsTesting()) {
      Test.toDate     = TimeCurrent();
      Test.stopMillis = GetTickCount();
   }


   // (1) User-spezifische deinit()-Routinen aufrufen                            // User-Routinen *können*, müssen aber nicht implementiert werden.
   int error = onDeinit();                                                       // Preprocessing-Hook
                                                                                 //
   if (error != -1) {                                                            // - deinit() bricht *nicht* ab, falls eine der User-Routinen einen Fehler zurückgibt.
      switch (UninitializeReason()) {                                            // - deinit() bricht ab, falls eine der User-Routinen -1 zurückgibt.
         case REASON_PARAMETERS : error = onDeinitParameterChange(); break;      //
         case REASON_CHARTCHANGE: error = onDeinitChartChange();     break;      //
         case REASON_ACCOUNT    : error = onDeinitAccountChange();   break;      //
         case REASON_CHARTCLOSE : error = onDeinitChartClose();      break;      //
         case REASON_UNDEFINED  : error = onDeinitUndefined();       break;      //
         case REASON_REMOVE     : error = onDeinitRemove();          break;      //
         case REASON_RECOMPILE  : error = onDeinitRecompile();       break;      //
      }                                                                          //
   }                                                                             //
                                                                                 //
   if (error != -1)                                                              //
      error = afterDeinit();                                                     // Postprocessing-Hook


   // (2) User-spezifische Deinit-Tasks ausführen
   if (error != -1) {
      // ...
   }


   // (3) stdlib deinitialisieren
   error = stdlib_deinit(deinitFlags, UninitializeReason());
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
   return(true);
}


/**
 * Ob das aktuell ausgeführte Programm ein im Tester laufender Expert ist.
 *
 * @return bool
 */
bool Expert.IsTesting() {
   return(IsTesting());
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
   return(IsTesting());
}


/**
 * Prüft, ob der aktuelle Tick in den angegebenen Timeframes ein BarOpen-Event darstellt. Auch bei wiederholten Aufrufen während
 * desselben Ticks wird das Event korrekt erkannt.
 *
 * @param  int results[] - Array, das nach Rückkehr die IDs der Timeframes enthält, in denen das Event aufgetreten ist (mehrere sind möglich)
 * @param  int flags     - Flags ein oder mehrerer zu prüfender Timeframes (default: der aktuelle Timeframe)
 *
 * @return bool - ob mindestens ein BarOpen-Event aufgetreten ist
 *
 *
 * NOTE: Diese Implementierung stimmt mit der Implementierung in ""libraries\stdlib.mq4"" für Indikatoren überein.
 */
bool EventListener.BarOpen(int results[], int flags=NULL) {
   if (ArraySize(results) != 0)
      ArrayResize(results, 0);

   if (flags == NULL)
      flags = PeriodFlag(Period());

   /*                                                                // TODO: Listener für PERIOD_MN1 implementieren
   +--------------------------+--------------------------+
   | Aufruf bei erstem Tick   | Aufruf bei weiterem Tick |
   +--------------------------+--------------------------+
   | Tick.prevTime = 0;       | Tick.prevTime = time[1]; |           // time[] stellt hier nur eine Pseudovariable dar (existiert nicht)
   | Tick.Time     = time[0]; | Tick.Time     = time[0]; |
   +--------------------------+--------------------------+
   */
   static datetime bar.openTimes[], bar.closeTimes[];                // OpenTimes/-CloseTimes der Bars der jeweiligen Perioden

                                                                     // die am häufigsten verwendeten Perioden zuerst (beschleunigt Ausführung)
   static int sizeOfPeriods, periods    []={  PERIOD_H1,   PERIOD_M30,   PERIOD_M15,   PERIOD_M5,   PERIOD_M1,   PERIOD_H4,   PERIOD_D1,   PERIOD_W1/*,   PERIOD_MN1*/},
                             periodFlags[]={F_PERIOD_H1, F_PERIOD_M30, F_PERIOD_M15, F_PERIOD_M5, F_PERIOD_M1, F_PERIOD_H4, F_PERIOD_D1, F_PERIOD_W1/*, F_PERIOD_MN1*/};
   if (sizeOfPeriods == 0) {
      sizeOfPeriods = ArraySize(periods);
      ArrayResize(bar.openTimes,  sizeOfPeriods);
      ArrayResize(bar.closeTimes, sizeOfPeriods);
   }

   int isEvent;

   for (int i=0; i < sizeOfPeriods; i++) {
      if (flags & periodFlags[i] != 0) {
         // BarOpen/Close-Time des aktuellen Ticks ggf. neuberechnen
         if (Tick.Time >= bar.closeTimes[i]) {                       // true sowohl bei Initialisierung als auch bei BarOpen
            bar.openTimes [i] = Tick.Time - Tick.Time % (periods[i]*MINUTES);
            bar.closeTimes[i] = bar.openTimes[i]      + (periods[i]*MINUTES);
         }

         // Event anhand des vorherigen Ticks bestimmen
         if (Tick.prevTime < bar.openTimes[i]) {
            if (!Tick.prevTime) {
               if (Expert.IsTesting())                               // im Tester ist der 1. Tick BarOpen-Event      TODO: !!! nicht für alle Timeframes !!!
                  isEvent = ArrayPushInt(results, periods[i]);
            }
            else {
               isEvent = ArrayPushInt(results, periods[i]);
            }
         }

         // Abbruch, wenn nur dieses einzelne Flag geprüft werden soll (die am häufigsten verwendeten Perioden sind zuerst angeordnet)
         if (flags == periodFlags[i])
            break;
      }
   }
   return(isEvent != 0);
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
 * Preprocessing-Hook
 *
 * @return int - Fehlerstatus
 *
int onInit() {
   return(NO_ERROR);
}


/**
 * Nach Parameteränderung
 *
 *  - altes Chartfenster, alter EA, Input-Dialog
 *
 * @return int - Fehlerstatus
 *
int onInitParameterChange() {
   return(NO_ERROR);
}


/**
 * Nach Symbol- oder Timeframe-Wechsel
 *
 * - altes Chartfenster, alter EA, kein Input-Dialog
 *
 * @return int - Fehlerstatus
 *
int onInitChartChange() {
   return(NO_ERROR);
}


/**
 * Nach Accountwechsel
 *
 * TODO: Umstände ungeklärt, wird in stdlib mit ERR_RUNTIME_ERROR abgefangen
 *
 * @return int - Fehlerstatus
 *
int onInitAccountChange() {
   return(NO_ERROR);
}


/**
 * Altes Chartfenster mit neu geladenem Template
 *
 * - neuer EA, Input-Dialog
 *
 * @return int - Fehlerstatus
 *
int onInitChartClose() {
   return(NO_ERROR);
}


/**
 * Kein UninitializeReason gesetzt
 *
 * - nach Terminal-Neustart: neues Chartfenster, vorheriger EA, kein Input-Dialog
 * - nach File->New->Chart:  neues Chartfenster, neuer EA, Input-Dialog
 * - im Tester:              neues Chartfenster bei VisualMode=On, neuer EA, kein Input-Dialog
 *
 * @return int - Fehlerstatus
 *
int onInitUndefined() {
   return(NO_ERROR);
}


/**
 * Vorheriger EA von Hand entfernt (Chart->Expert->Remove) oder neuer EA drübergeladen
 *
 * - altes Chartfenster, neuer EA, Input-Dialog
 *
 * @return int - Fehlerstatus
 *
int onInitRemove() {
   return(NO_ERROR);
}


/**
 * Nach Recompilation
 *
 * - altes Chartfenster, vorheriger EA, kein Input-Dialog
 *
 * @return int - Fehlerstatus
 *
int onInitRecompile() {
   return(NO_ERROR);
}


/**
 * Postprocessing-Hook
 *
 * @return int - Fehlerstatus
 *
int afterInit() {
   return(NO_ERROR);
}
 */


// -- deinit()-Templates ----------------------------------------------------------------------------------------------------------------------------


/**
 * Preprocessing-Hook
 *
 * @return int - Fehlerstatus
 *
int onDeinit() {
   double test.duration = (Test.stopMillis-Test.startMillis)/1000.0;
   double test.days     = (Test.toDate-Test.fromDate) * 1.0 /DAYS;
   debug("onDeinit()   time="+ DoubleToStr(test.duration, 1) +" sec   days="+ Round(test.days) +"   ("+ DoubleToStr(test.duration/test.days, 3) +" sec/day)");
   return(last_error);
}


/**
 * Parameteränderung
 *
 * @return int - Fehlerstatus
 *
int onDeinitParameterChange() {
   return(NO_ERROR);
}


/**
 * Symbol- oder Timeframewechsel
 *
 * @return int - Fehlerstatus
 *
int onDeinitChartChange() {
   return(NO_ERROR);
}


/**
 * Accountwechsel
 *
 * TODO: Umstände ungeklärt, wird in stdlib mit ERR_RUNTIME_ERROR abgefangen
 *
 * @return int - Fehlerstatus
 *
int onDeinitAccountChange() {
   return(NO_ERROR);
}


/**
 * Im Tester: - Nach Betätigen des "Stop"-Buttons oder nach Chart->Close. Der "Stop"-Button des Testers kann nach Fehler oder Testabschluß
 *              vom Code "betätigt" worden sein.
 *
 * Online:    - Chart wird geschlossen                  - oder -
 *            - Template wird neu geladen               - oder -
 *            - Terminal-Shutdown                       - oder -
 *
 * @return int - Fehlerstatus
 *
int onDeinitChartClose() {
   return(NO_ERROR);
}


/**
 * Kein UninitializeReason gesetzt: nur im Tester nach regulärem Ende (Testperiode zu Ende)
 *
 * @return int - Fehlerstatus
 *
int onDeinitUndefined() {
   return(NO_ERROR);
}


/**
 * Nur Online: EA von Hand entfernt (Chart->Expert->Remove) oder neuer EA drübergeladen
 *
 * @return int - Fehlerstatus
 *
int onDeinitRemove() {
   return(NO_ERROR);
}


/**
 * Recompilation
 *
 * @return int - Fehlerstatus
 *
int onDeinitRecompile() {
   return(NO_ERROR);
}


/**
 * Postprocessing-Hook
 *
 * @return int - Fehlerstatus
 *
int afterDeinit() {
   return(NO_ERROR);
}
 */
