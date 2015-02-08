
#define __TYPE__         T_EXPERT
#define __lpSuperContext NULL

#include <functions/IsTesting.mqh>
#include <history.mqh>
#include <iCustom/ChartInfos.mqh>


// Variablen für Teststatistiken
datetime Test.fromDate,    Test.toDate;
int      Test.startMillis, Test.stopMillis;                          // in Millisekunden


/**
 * Globale init()-Funktion für Expert Adviser.
 *
 * Bei Aufruf durch das Terminal wird der letzte Errorcode 'last_error' in 'prev_error' gespeichert und vor Abarbeitung
 * zurückgesetzt.
 *
 * @return int - Fehlerstatus
 *
 * @throws ERS_TERMINAL_NOT_YET_READY
 */
int init() {
   if (__STATUS_OFF)
      return(last_error);

   if (__WHEREAMI__ == NULL) {                                       // Aufruf durch Terminal
      __WHEREAMI__ = FUNC_INIT;
      prev_error   = last_error;
      SetLastError(NO_ERROR);
   }


   // (1) EXECUTION_CONTEXT initialisieren
   if (!ec.Signature(__ExecutionContext)) /**/ if (!InitExecutionContext()) {
      UpdateProgramStatus();
      if (__STATUS_OFF) return(last_error);
   }


   // (2) eigenes WindowHandle ermitteln, damit es in deinit() auf jeden Fall verfügbar ist
   if (!WindowHandleEx(NULL)) {
      UpdateProgramStatus();
      if (__STATUS_OFF) return(last_error);
   }


   // (3) stdlib initialisieren
   int iNull[];
   int error = stdlib.init(__ExecutionContext, iNull);//throws ERS_TERMINAL_NOT_YET_READY
   if (IsError(error)) {
      UpdateProgramStatus(SetLastError(error));
      if (__STATUS_OFF) return(last_error);
   }


   // (4) in Experts immer auch die HistoryLib initialisieren
   error = history.init(__ExecutionContext);
   if (IsError(error)) {
      UpdateProgramStatus(SetLastError(error));
      if (__STATUS_OFF) return(last_error);
   }

                                                                              // #define INIT_TIMEZONE               in stdlib.init()
   // (5) user-spezifische Init-Tasks ausführen                               // #define INIT_PIPVALUE
   int initFlags = ec.InitFlags(__ExecutionContext);                          // #define INIT_BARS_ON_HIST_UPDATE
                                                                              // #define INIT_CUSTOMLOG
   if (initFlags & INIT_PIPVALUE && 1) {
      TickSize = MarketInfo(Symbol(), MODE_TICKSIZE);                         // schlägt fehl, wenn kein Tick vorhanden ist
      error = GetLastError();
      if (IsError(error)) {                                                   // - Symbol nicht subscribed (Start, Account-/Templatewechsel), Symbol kann noch "auftauchen"
         if (error == ERR_UNKNOWN_SYMBOL)                                     // - synthetisches Symbol im Offline-Chart
            return(UpdateProgramStatus(debug("init(1)  MarketInfo() => ERR_UNKNOWN_SYMBOL", SetLastError(ERS_TERMINAL_NOT_YET_READY))));
         UpdateProgramStatus(catch("init(2)", error));
         if (__STATUS_OFF) return(last_error);
      }
      if (!TickSize)       return(UpdateProgramStatus(debug("init(3)  MarketInfo(MODE_TICKSIZE) = 0", SetLastError(ERS_TERMINAL_NOT_YET_READY))));

      double tickValue = MarketInfo(Symbol(), MODE_TICKVALUE);
      error = GetLastError();
      if (IsError(error)) {
         UpdateProgramStatus(catch("init(4)", error));
         if (__STATUS_OFF) return(last_error);
      }
      if (!tickValue)      return(UpdateProgramStatus(debug("init(5)  MarketInfo(MODE_TICKVALUE) = 0", SetLastError(ERS_TERMINAL_NOT_YET_READY))));
   }
   if (initFlags & INIT_BARS_ON_HIST_UPDATE && 1) {}                          // noch nicht implementiert


   // (6) ggf. EA's aktivieren
   int reasons1[] = { REASON_UNDEFINED, REASON_CHARTCLOSE, REASON_REMOVE };
   if (!IsTesting()) /*&&*/ if (!IsExpertEnabled()) /*&&*/ if (IntInArray(reasons1, UninitializeReason())) {
      error = Toolbar.Experts(true);
      if (IsError(error)) {                                                   // TODO: Fehler, wenn bei Terminalstart mehrere EA's den Modus gleichzeitig umschalten wollen
         UpdateProgramStatus(SetLastError(error));
         if (__STATUS_OFF) return(last_error);
      }
   }


   // (7) nach Neuladen explizit Orderkontext zurücksetzen (siehe MQL.doc)
   int reasons2[] = { REASON_UNDEFINED, REASON_CHARTCLOSE, REASON_REMOVE, REASON_ACCOUNT };
   if (IntInArray(reasons2, UninitializeReason()))
      OrderSelect(0, SELECT_BY_TICKET);


   // (8) User-spezifische init()-Routinen *können*, müssen aber nicht implementiert werden.
   //
   // Die User-Routinen werden ausgeführt, wenn der Preprocessing-Hook (falls implementiert) ohne Fehler zurückkehrt.
   // Der Postprocessing-Hook wird ausgeführt, wenn weder der Preprocessing-Hook (falls implementiert) noch die User-Routinen
   // (falls implementiert) -1 zurückgeben.
   error = onInit();                                                          // Preprocessing-Hook
                                                                              //
   if (!error) {                                                              //
      switch (UninitializeReason()) {                                         //
         case REASON_PARAMETERS : error = onInitParameterChange(); break;     //
         case REASON_CHARTCHANGE: error = onInitChartChange();     break;     //
         case REASON_ACCOUNT    : error = onInitAccountChange();   break;     //
         case REASON_CHARTCLOSE : error = onInitChartClose();      break;     //
         case REASON_UNDEFINED  : error = onInitUndefined();       break;     //
         case REASON_REMOVE     : error = onInitRemove();          break;     //
         case REASON_RECOMPILE  : error = onInitRecompile();       break;     //
         // build > 509                                                       //
         case REASON_TEMPLATE   : error = onInitTemplate();        break;     //
         case REASON_INITFAILED : error = onInitFailed();          break;     //
         case REASON_CLOSE      : error = onInitClose();           break;     //
                                                                              //
         default: return(UpdateProgramStatus(catch("init(6)  unknown UninitializeReason = "+ UninitializeReason(), ERR_RUNTIME_ERROR)));
      }                                                                       //
   }                                                                          //
   if (error == ERS_TERMINAL_NOT_YET_READY) return(error);                    //
   UpdateProgramStatus();                                                     //
                                                                              //
   if (error != -1) {                                                         //
      afterInit();                                                            // Postprocessing-Hook
      UpdateProgramStatus();                                                  //
   }                                                                          //
   ShowStatus(last_error);                                                    //
   if (__STATUS_OFF) return(last_error);                                      //


   // (9) Außer bei REASON_CHARTCHANGE nicht auf den nächsten echten Tick warten, sondern sofort selbst einen Tick schicken.
   if (IsTesting()) {
      Test.fromDate    = TimeCurrent();                                       // für Teststatistiken
      Test.startMillis = GetTickCount();
   }
   else if (UninitializeReason() != REASON_CHARTCHANGE) {                     // Ganz zum Schluß, da Ticks verloren gehen, wenn die entsprechende Windows-Message
      error = Chart.SendTick(false);                                          // vor Verlassen von init() verarbeitet wird.
      if (IsError(error)) {
         UpdateProgramStatus(SetLastError(error));
         if (__STATUS_OFF) return(last_error);
      }
   }

   UpdateProgramStatus(catch("init(7)"));
   return(last_error);
}


/**
 * Globale start()-Funktion für Expert Adviser.
 *
 * Erfolgt der Aufruf nach einem init()-Cycle und init() kehrte mit dem Fehler ERS_TERMINAL_NOT_YET_READY zurück,
 * wird init() solange erneut ausgeführt, bis das Terminal bereit ist
 *
 * @return int - Fehlerstatus
 */
int start() {
   if (__STATUS_OFF) {
      string msg = WindowExpertName() +": switched off ("+ ifString(!__STATUS_OFF.reason, "unknown reason", ErrorToStr(__STATUS_OFF.reason)) +")";
      ShowStatus(last_error);
      if (IsTesting())                                                     // Im Fehlerfall Tester anhalten. Hier, da der Fehler schon in init() auftreten kann
         Tester.Stop();                                                    // oder das Ende von start() evt. nicht mehr ausgeführt wird.
      return(last_error);
   }

   Tick++;                                                                 // einfacher Zähler, der konkrete Wert hat keine Bedeutung
   Tick.prevTime = Tick.Time;
   Tick.Time     = MarketInfo(Symbol(), MODE_TIME);
   ValidBars     = -1;
   ChangedBars   = -1;


   // (1) Falls wir aus init() kommen, dessen Ergebnis prüfen
   if (__WHEREAMI__ == FUNC_INIT) {
      __WHEREAMI__ = ec.setWhereami(__ExecutionContext, FUNC_START);       // __STATUS_OFF ist false: evt. ist jedoch ein Status gesetzt, siehe UpdateProgramStatus()

      if (last_error == ERS_TERMINAL_NOT_YET_READY) {                      // alle anderen Stati brauchen zur Zeit keine eigene Behandlung
         debug("start(2)  init() returned ERS_TERMINAL_NOT_YET_READY, retrying...");
         last_error = NO_ERROR;

         int error = init();                                               // init() erneut aufrufen
         if (__STATUS_OFF) return(ShowStatus(last_error));

         if (error == ERS_TERMINAL_NOT_YET_READY) {                        // wenn überhaupt, kann wieder nur ein Status gesetzt sein
            __WHEREAMI__ = ec.setWhereami(__ExecutionContext, FUNC_INIT);  // __WHEREAMI__ zurücksetzen und auf den nächsten Tick warten
            return(ShowStatus(error));
         }
      }
      last_error = NO_ERROR;                                               // init() war erfolgreich, ein vorhandener Status wird überschrieben
   }
   else {
      prev_error = last_error;                                             // weiterer Tick: last_error sichern und zurücksetzen
      SetLastError(NO_ERROR);
   }


   // (2) bei Bedarf Input-Dialog aufrufen
   if (__STATUS_RELAUNCH_INPUT) {
      __STATUS_RELAUNCH_INPUT = false;
      start.RelaunchInputDialog();
      return(UpdateProgramStatus(ShowStatus(last_error)));
   }


   // (3) Abschluß der Chart-Initialisierung überprüfen (kann bei Terminal-Start auftreten)
   if (!Bars)
      return(UpdateProgramStatus(ShowStatus(SetLastError(debug("start(3)  Bars=0", ERS_TERMINAL_NOT_YET_READY)))));


   // (4) stdLib benachrichtigen
   if (stdlib.start(__ExecutionContext, Tick, Tick.Time, ValidBars, ChangedBars) != NO_ERROR) {
      UpdateProgramStatus(ShowStatus(SetLastError(stdlib.GetLastError())));
      if (__STATUS_OFF) return(last_error);
   }


   // (5) Main-Funktion aufrufen und auswerten
   onTick();

   error = GetLastError();
   if (error != NO_ERROR)
      catch("start(4)", error);


   // (6) im Tester
   if (IsVisualMode())
      icChartInfos(PERIOD_H1);                                             // nur bei Tester::VisualMode=On ChartInfos per iCustom() anzeigen (ist Online nicht notwendig)


   // (7) Statusanzeige
   return(UpdateProgramStatus(ShowStatus(last_error)));
}


/**
 * Globale deinit()-Funktion für Expert Adviser.
 *
 * @return int - Fehlerstatus
 *
 *
 * NOTE: Bei VisualMode=Off und regulärem Testende (Testperiode zu Ende = REASON_UNDEFINED) bricht das Terminal komplexere deinit()-Funktionen verfrüht ab.
 *       afterDeinit() und stdlib.deinit() werden u.U. schon nicht mehr ausgeführt.
 *
 *       Workaround: Testperiode auslesen (Controls), letzten Tick ermitteln (Historydatei) und Test nach letztem Tick per Tester.Stop() beenden.
 *                   Alternativ bei EA's, die dies unterstützen, Testende vors reguläre Testende der Historydatei setzen.
 */
int deinit() {
   __WHEREAMI__ =                               FUNC_DEINIT;
   ec.setWhereami          (__ExecutionContext, FUNC_DEINIT         );
   ec.setUninitializeReason(__ExecutionContext, UninitializeReason());


   if (IsTesting()) {
      Test.toDate     = TimeCurrent();
      Test.stopMillis = GetTickCount();
   }


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
   return(last_error);
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
   return(true);
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
 * Initialisiert den EXECUTION_CONTEXT des Experts.
 *
 * @return bool - Erfolgsstatus
 */
bool InitExecutionContext() {
   if (ec.Signature(__ExecutionContext) != 0) return(!catch("InitExecutionContext(1)  signature of EXECUTION_CONTEXT not NULL = "+ EXECUTION_CONTEXT.toStr(__ExecutionContext, false), ERR_ILLEGAL_STATE));

   N_INF = MathLog(0);
   P_INF = -N_INF;
   NaN   =  N_INF - N_INF;


   // (1) Speicher für Programm- und LogFileName alloziieren
   string names[2]; names[0] = WindowExpertName();                                              // Programm-Name (Länge konstant)
                    names[1] = CreateString(MAX_PATH);                                          // LogFileName   (Länge variabel)

   int  lpNames[3]; CopyMemory(GetStringsAddress(names)+ 4, GetBufferAddress(lpNames),   4);    // Zeiger auf beide Strings holen
                    CopyMemory(GetStringsAddress(names)+12, GetBufferAddress(lpNames)+4, 4);

                    CopyMemory(GetBufferAddress(lpNames)+8, lpNames[1], 1);                     // LogFileName mit <NUL> initialisieren (lpNames[2] = <NUL>)


   // (2) globale Variablen initialisieren
   int initFlags    = SumInts(__INIT_FLAGS__  );
   int deinitFlags  = SumInts(__DEINIT_FLAGS__);
   int hChart       = WindowHandleEx(NULL); if (!hChart) return(false);
   int hChartWindow = 0;
      if (hChart == -1) hChart       = 0;
      else              hChartWindow = GetParent(hChart);

   __NAME__       = names[0];
   IsChart        = !IsTesting() || IsVisualMode();
   __LOG          = IsLogging();
   __LOG_CUSTOM   = initFlags & INIT_CUSTOMLOG;

   PipDigits      = Digits & (~1);                                        SubPipDigits      = PipDigits+1;
   PipPoints      = MathRound(MathPow(10, Digits & 1));                   PipPoint          = PipPoints;
   Pip            = NormalizeDouble(1/MathPow(10, PipDigits), PipDigits); Pips              = Pip;
   PipPriceFormat = StringConcatenate(".", PipDigits);                    SubPipPriceFormat = StringConcatenate(PipPriceFormat, "'");
   PriceFormat    = ifString(Digits==PipDigits, PipPriceFormat, SubPipPriceFormat);


   // (3) EXECUTION_CONTEXT initialisieren
   ArrayInitialize(__ExecutionContext, 0);

   ec.setSignature         (__ExecutionContext, GetBufferAddress(__ExecutionContext)                                                                                 );
   ec.setLpName            (__ExecutionContext, lpNames[0]                                                                                                           );
   ec.setType              (__ExecutionContext, __TYPE__                                                                                                             );
   ec.setHChart            (__ExecutionContext, hChart                                                                                                               );
   ec.setHChartWindow      (__ExecutionContext, hChartWindow                                                                                                         );
   ec.setTestFlags         (__ExecutionContext, ifInt(IsTesting(), TF_TESTING, 0) | ifInt(IsVisualMode(), TF_VISUAL, 0) | ifInt(IsOptimization(), TF_OPTIMIZATION, 0));
 //ec.setLpSuperContext    ...bereits initialisiert
   ec.setInitFlags         (__ExecutionContext, initFlags                                                                                                            );
   ec.setDeinitFlags       (__ExecutionContext, deinitFlags                                                                                                          );
   ec.setUninitializeReason(__ExecutionContext, UninitializeReason()                                                                                                 );
   ec.setWhereami          (__ExecutionContext, __WHEREAMI__                                                                                                         );
   ec.setLogging           (__ExecutionContext, __LOG                                                                                                                );
   ec.setLpLogFile         (__ExecutionContext, lpNames[1]                                                                                                           );
 //ec.setLastError         ...bereits initialisiert


   if (!catch("InitExecutionContext(2)"))
      return(true);

   ArrayInitialize(__ExecutionContext, 0);
   return(false);
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
 * Setzt den internen Fehlercode des EA's.
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
 * Überprüft und aktualisiert den aktuellen Programmstatus des EA's. Setzt je nach Kontext das Flag __STATUS_OFF.
 *
 * @param  int value - der zurückzugebende Wert (default: NULL)
 *
 * @return int - der übergebene Wert
 */
int UpdateProgramStatus(int value=NULL) {
   switch (last_error) {
      case NO_ERROR                  :
      case ERS_HISTORY_UPDATE        :
      case ERS_TERMINAL_NOT_YET_READY:
      case ERS_EXECUTION_STOPPING    : break;

      default:
         __STATUS_OFF        = true;
         __STATUS_OFF.reason = last_error;
   }
   return(value);
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
 * NOTE: Diese Implementierung stimmt mit der Implementierung in ""libraries\stdlib1.mq4"" für Indikatoren überein.
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


#define WM_COMMAND      0x0111


/**
 * Stoppt den Tester. Der Aufruf ist nur im Tester möglich.
 *
 * @return int - Fehlerstatus
 */
int Tester.Stop() {
   if (!IsTesting()) return(catch("Tester.Stop(1)  Tester only function", ERR_FUNC_NOT_ALLOWED));

   if (Tester.IsStopped())          return(NO_ERROR);                // skipping
   if (__WHEREAMI__ == FUNC_DEINIT) return(NO_ERROR);                // SendMessage() darf in deinit() nicht mehr benutzt werden

   int hWnd = GetApplicationWindow();
   if (!hWnd) return(last_error);

   SendMessageA(hWnd, WM_COMMAND, IDC_TESTER_SETTINGS_STARTSTOP, 0);
   return(NO_ERROR);
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

   int    ShowStatus(int error);

   int    Chart.SendTick(bool sound);
   void   CopyMemory(int source, int destination, int bytes);
   string CreateString(int length);
   int    GetApplicationWindow();
   bool   IntInArray(int haystack[], int needle);
   int    PeriodFlag(int period);
   int    SumInts(int array[]);
   bool   Tester.IsStopped();
   int    Toolbar.Experts(bool enable);

#import "Expander.dll"
   int    GetBufferAddress(int buffer[]);
   int    GetStringsAddress(string array[]);

#import "struct.EXECUTION_CONTEXT.ex4"
   int    ec.InitFlags            (/*EXECUTION_CONTEXT*/int ec[]);
   int    ec.Signature            (/*EXECUTION_CONTEXT*/int ec[]);

   int    ec.setDeinitFlags       (/*EXECUTION_CONTEXT*/int ec[], int  deinitFlags       );
   int    ec.setHChart            (/*EXECUTION_CONTEXT*/int ec[], int  hChart            );
   int    ec.setHChartWindow      (/*EXECUTION_CONTEXT*/int ec[], int  hChartWindow      );
   int    ec.setInitFlags         (/*EXECUTION_CONTEXT*/int ec[], int  initFlags         );
   int    ec.setLastError         (/*EXECUTION_CONTEXT*/int ec[], int  lastError         );
   bool   ec.setLogging           (/*EXECUTION_CONTEXT*/int ec[], bool logging           );
   int    ec.setLpLogFile         (/*EXECUTION_CONTEXT*/int ec[], int  lpLogFile         );
   int    ec.setLpName            (/*EXECUTION_CONTEXT*/int ec[], int  lpName            );
   int    ec.setSignature         (/*EXECUTION_CONTEXT*/int ec[], int  signature         );
   int    ec.setType              (/*EXECUTION_CONTEXT*/int ec[], int  type              );
   int    ec.setUninitializeReason(/*EXECUTION_CONTEXT*/int ec[], int  uninitializeReason);
   int    ec.setTestFlags         (/*EXECUTION_CONTEXT*/int ec[], int  testFlags         );
   int    ec.setWhereami          (/*EXECUTION_CONTEXT*/int ec[], int  whereami          );

   string EXECUTION_CONTEXT.toStr (/*EXECUTION_CONTEXT*/int ec[], bool outputDebug);

#import "user32.dll"
   int  SendMessageA(int hWnd, int msg, int wParam, int lParam);
#import


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
   double test.duration = (Test.stopMillis-Test.startMillis)/1000.;
   double test.days     = (Test.toDate-Test.fromDate) * 1. /DAYS;
   debug("onDeinit()  time="+ DoubleToStr(test.duration, 1) +" sec   days="+ Round(test.days) +"   ("+ DoubleToStr(test.duration/test.days, 3) +" sec/day)");
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
