
#define __TYPE__         MT_EXPERT
#define __lpSuperContext NULL

extern string ____________Tester____________;
extern bool   Record.Equity = false;

#include <iCustom/icChartInfos.mqh>


// RecordEquity()
int    equityChart.hSet        = 0;
string equityChart.symbol      = "";                                 // kann vom Programm gesetzt werden; default: StringLeft(__NAME__,6) +"~"+ {dreistelligerZähler} +"."
string equityChart.description = "";                                 // kann vom Programm gesetzt werden; default: __NAME__+" "+ {dreistelligerZähler} +" "+ {LocalStartTime}
double equityChart.value       = 0;                                  // kann vom Programm gesetzt werden; default: AccountEquity()-AccountCredit()


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

   if (__WHEREAMI__ == NULL) {                                       // then init() is called by the terminal
      __WHEREAMI__ = RF_INIT;
      prev_error   = last_error;
      zTick        = 0;
      SetLastError(NO_ERROR);
      ec_SetDllError(__ExecutionContext, NO_ERROR);
   }
   int hWnd = NULL; if (!IsTesting() || IsVisualMode())              // Under test WindowHandle() triggers ERR_FUNC_NOT_ALLOWED_IN_TESTER
       hWnd = WindowHandle(Symbol(), NULL);                          // if VisualMode=Off.


   // (1) ExecutionContext initialisieren
   SyncMainContext_init(__ExecutionContext, __TYPE__, WindowExpertName(), __WHEREAMI__, UninitializeReason(), SumInts(__INIT_FLAGS__), SumInts(__DEINIT_FLAGS__), Symbol(), Period(), __lpSuperContext, IsTesting(), IsVisualMode(), hWnd, WindowOnDropped());


   // (2) Initialisierung abschließen
   if (!UpdateExecutionContext()) {
      UpdateProgramStatus(); if (__STATUS_OFF) return(last_error);
   }


   // (3) stdlib initialisieren
   int iNull[];
   int error = stdlib.init(__ExecutionContext, iNull);//throws ERS_TERMINAL_NOT_YET_READY
   if (IsError(error)) {
      UpdateProgramStatus(SetLastError(error));
      if (__STATUS_OFF) return(last_error);
   }

                                                                              // #define INIT_TIMEZONE               in stdlib.init()
   // (4) user-spezifische Init-Tasks ausführen                               // #define INIT_PIPVALUE
   int initFlags = ec_InitFlags(__ExecutionContext);                          // #define INIT_BARS_ON_HIST_UPDATE
                                                                              // #define INIT_CUSTOMLOG
   if (initFlags & INIT_PIPVALUE && 1) {
      TickSize = MarketInfo(Symbol(), MODE_TICKSIZE);                         // schlägt fehl, wenn kein Tick vorhanden ist
      error = GetLastError();
      if (IsError(error)) {                                                   // - Symbol nicht subscribed (Start, Account-/Templatewechsel), Symbol kann noch "auftauchen"
         if (error == ERR_SYMBOL_NOT_AVAILABLE)                               // - synthetisches Symbol im Offline-Chart
            return(UpdateProgramStatus(debug("init(1)  MarketInfo() => ERR_SYMBOL_NOT_AVAILABLE", SetLastError(ERS_TERMINAL_NOT_YET_READY))));
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


   // (5) ggf. EA's aktivieren
   int reasons1[] = { REASON_UNDEFINED, REASON_CHARTCLOSE, REASON_REMOVE };
   if (!IsTesting()) /*&&*/ if (!IsExpertEnabled()) /*&&*/ if (IntInArray(reasons1, UninitializeReason())) {
      error = Toolbar.Experts(true);
      if (IsError(error)) {                                                   // TODO: Fehler, wenn bei Terminalstart mehrere EA's den Modus gleichzeitig umschalten wollen
         UpdateProgramStatus(SetLastError(error));
         if (__STATUS_OFF) return(last_error);
      }
   }


   // (6) nach Neuladen explizit Orderkontext zurücksetzen (siehe MQL.doc)
   int reasons2[] = { REASON_UNDEFINED, REASON_CHARTCLOSE, REASON_REMOVE, REASON_ACCOUNT };
   if (IntInArray(reasons2, UninitializeReason()))
      OrderSelect(0, SELECT_BY_TICKET);


   // (7) User-spezifische init()-Routinen *können*, müssen aber nicht implementiert werden.
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
   if (IsError(error)) SetLastError(error);                                   //
   if (error == ERS_TERMINAL_NOT_YET_READY) return(error);                    //
   UpdateProgramStatus();                                                     //
                                                                              //
   if (error != -1) {                                                         //
      error = afterInit();                                                    // Postprocessing-Hook
      if (IsError(error)) SetLastError(error);                                //
      UpdateProgramStatus();                                                  //
   }                                                                          //
   ShowStatus(last_error);                                                    //
   if (__STATUS_OFF) return(last_error);                                      //


   // (8) Außer bei REASON_CHARTCHANGE nicht auf den nächsten echten Tick warten, sondern sofort selbst einen Tick schicken.
   if (UninitializeReason() != REASON_CHARTCHANGE) {                          // Ganz zum Schluß, da Ticks verloren gehen, wenn die entsprechende Windows-Message
      error = Chart.SendTick();                                               // vor Verlassen von init() verarbeitet wird.
      if (IsError(error)) {
         UpdateProgramStatus(SetLastError(error));
         if (__STATUS_OFF) return(last_error);
      }
   }

   UpdateProgramStatus(catch("init(8)"));
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
      if (IsTesting())                                                              // Im Fehlerfall Tester anhalten. Hier, da der Fehler schon in init() auftreten kann
         Tester.Stop();                                                             // oder das Ende von start() evt. nicht mehr ausgeführt wird.
      return(last_error);
   }

   Tick++; zTick++;                                                                 // einfache Zähler, die konkreten Werte haben keine Bedeutung
   Tick.prevTime  = Tick.Time;
   Tick.Time      = MarketInfo(Symbol(), MODE_TIME);
   Tick.isVirtual = true;
   ValidBars      = -1;
   ChangedBars    = -1;


   // (1) Falls wir aus init() kommen, dessen Ergebnis prüfen
   if (__WHEREAMI__ == RF_INIT) {
      __WHEREAMI__ = ec_SetRootFunction(__ExecutionContext, RF_START);              // __STATUS_OFF ist false: evt. ist jedoch ein Status gesetzt, siehe UpdateProgramStatus()

      if (last_error == ERS_TERMINAL_NOT_YET_READY) {                               // alle anderen Stati brauchen zur Zeit keine eigene Behandlung
         debug("start(2)  init() returned ERS_TERMINAL_NOT_YET_READY, retrying...");
         last_error = NO_ERROR;

         int error = init();                                                        // init() erneut aufrufen
         if (__STATUS_OFF) return(ShowStatus(last_error));

         if (error == ERS_TERMINAL_NOT_YET_READY) {                                 // wenn überhaupt, kann wieder nur ein Status gesetzt sein
            __WHEREAMI__ = ec_SetRootFunction(__ExecutionContext, RF_INIT);         // __WHEREAMI__ zurücksetzen und auf den nächsten Tick warten
            return(ShowStatus(error));
         }
      }
      last_error = NO_ERROR;                                                        // init() war erfolgreich, ein vorhandener Status wird überschrieben
   }
   else {
      prev_error = last_error;                                                      // weiterer Tick: last_error sichern und zurücksetzen
      SetLastError(NO_ERROR);
      ec_SetDllError(__ExecutionContext, NO_ERROR);
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


   SyncMainContext_start(__ExecutionContext, __TYPE__, WindowExpertName(), __WHEREAMI__, UninitializeReason(), SumInts(__INIT_FLAGS__), SumInts(__DEINIT_FLAGS__), Symbol(), Period(), __lpSuperContext, IsTesting(), IsVisualMode(), NULL, WindowOnDropped());


   // (4) stdLib benachrichtigen
   if (stdlib.start(__ExecutionContext, Tick, Tick.Time, ValidBars, ChangedBars) != NO_ERROR) {
      UpdateProgramStatus(ShowStatus(SetLastError(stdlib.GetLastError())));
      if (__STATUS_OFF) return(last_error);
   }


   // (5) Main-Funktion aufrufen
   onTick();


   // (6) Fehler-Status auswerten
   error = ec_DllError(__ExecutionContext);
   if (error != NO_ERROR) catch("start(4)  DLL error", error);
   else if (!last_error) {
      error = ec_MqlError(__ExecutionContext);
      if (error != NO_ERROR) last_error = error;
   }
   error = GetLastError();
   if (error != NO_ERROR) catch("start(5)", error);


   // (7) im Tester
   //if (IsVisualMode())
   //   icChartInfos();                      // im Tester bei VisualMode=On: ChartInfos anzeigen


   // (8) Statusanzeige
   ShowStatus(last_error);


   // (9) Equity aufzeichnen
   if (Record.Equity) RecordEquity();


   if (last_error != NO_ERROR)
      UpdateProgramStatus(last_error);

   return(last_error);
   icChartInfos();                           // dummy call to suppress compiler warnings
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
   __WHEREAMI__ = RF_DEINIT;
   SyncMainContext_deinit(__ExecutionContext, __TYPE__, WindowExpertName(), __WHEREAMI__, UninitializeReason(), SumInts(__INIT_FLAGS__), SumInts(__DEINIT_FLAGS__), Symbol(), Period(), __lpSuperContext, IsTesting(), IsVisualMode(), NULL, WindowOnDropped());


   if (equityChart.hSet != 0) {
      int tmp=equityChart.hSet; equityChart.hSet=NULL;
      if (!HistorySet.Close(tmp)) return(!SetLastError(history.GetLastError()));
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
         default:                                                                //
            UpdateProgramStatus(catch("deinit(2)  unknown UninitializeReason = "+ UninitializeReason(), ERR_RUNTIME_ERROR));
            LeaveContext(__ExecutionContext);                                    //
            return(last_error);                                                  //
      }                                                                          //
   }                                                                             //
   if (IsError(error)) SetLastError(error);                                      //
   UpdateProgramStatus();                                                        //
                                                                                 //
   if (error != -1) {                                                            //
      error = afterDeinit();                                                     // Postprocessing-Hook
      if (IsError(error)) SetLastError(error);                                   //
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


   UpdateProgramStatus(catch("deinit(3)"));
   LeaveContext(__ExecutionContext);
   return(last_error); __DummyCalls();
}


/**
 * Zeichnet die aktuelle Equity-Kurve auf.
 *
 * @return bool - Erfolgsstatus
 */
bool RecordEquity() {
   /* Speedtest SnowRoller EURUSD,M15  04.10.2012, long, GridSize 18
   +-----------------------------+--------------+-----------+--------------+-------------+-------------+--------------+--------------+--------------+
   | Toshiba Satellite           |     alt      | optimiert | FindBar opt. | Arrays opt. |  Read opt.  |  Write opt.  |  Valid. opt. |  in Library  |
   +-----------------------------+--------------+-----------+--------------+-------------+-------------+--------------+--------------+--------------+
   | v419 - ohne RecordEquity()  | 17.613 t/sec |           |              |             |             |              |              |              |
   | v225 - HST_BUFFER_TICKS=Off |  6.426 t/sec |           |              |             |             |              |              |              |
   | v419 - HST_BUFFER_TICKS=Off |  5.871 t/sec | 6.877 t/s |   7.381 t/s  |  7.870 t/s  |  9.097 t/s  |   9.966 t/s  |  11.332 t/s  |              |
   | v419 - HST_BUFFER_TICKS=On  |              |           |              |             |             |              |  15.486 t/s  |  14.286 t/s  |
   +-----------------------------+--------------+-----------+--------------+-------------+-------------+--------------+--------------+--------------+
   */
   if (!IsTesting()) return(true);                                   // vorerst nur im Tester


   // (1) HistorySet öffnen
   if (!equityChart.hSet) {
      int    hSet;
      string symbol         = equityChart.symbol;
      string description    = equityChart.description;
      string symbolGroup    = __NAME__;
      int    digits         = 2;
      string baseCurrency   = AccountCurrency();
      string marginCurrency = AccountCurrency();
      int    format         = 400;
      string server         = "MyFX-Testresults";

      int flags = HST_BUFFER_TICKS;
      //flags = NULL;


      if (!StringLen(symbol)) {
         // Kein Symbol angegeben, dynamisch ein neues nicht existierendes Symbol erzeugen
         int counter = 0;
         while (true) {
            counter++;
            symbol = StringLeft(__NAME__, 7) +"."+ StringPadLeft(counter, 3, "0");
            symbol = StringReplace(symbol, " ", "_");
            hSet   = HistorySet.Get(symbol, server); if (!hSet) return(!SetLastError(history.GetLastError()));
            if (hSet > 0) {
               // Symbol existiert: Set schließen und nächstes Symbol testen
               if (!HistorySet.Close(hSet)) return(!SetLastError(history.GetLastError()));
               continue;
            }
            // Symbol existiert nicht
            break;
         }

         // Description erstellen oder um aktuelle Zeit erweitern
         if (!StringLen(description))                                            description = StringLeft(__NAME__, 39) +" "+ StringPadLeft(counter, 3, "0");          // 39 + 1 +  3 = 43
         string end = StringRight(description, 3);
         if (!StringStartsWith(end, ":") || !StringIsDigit(StringRight(end, 2))) description = StringLeft(description, 43) +" "+ TimeToStr(GetLocalTime(), TIME_FULL); // 43 + 1 + 19 = 63

         // Symbol erzeugen
         if (CreateSymbol(symbol, description, symbolGroup, digits, baseCurrency, marginCurrency, server) < 0) return(!SetLastError(history.GetLastError()));

         // HistorySet erzeugen
         hSet = HistorySet.Create(symbol, description, digits, format, server);

         equityChart.symbol      = symbol;
         equityChart.description = description;
      }
      else {
         // Symbol war angegeben
         hSet = HistorySet.Get(symbol, server); if (!hSet) return(!SetLastError(history.GetLastError()));
         if (hSet == -1) {
            // Description erstellen bzw. um aktuelle Zeit erweitern
            if (!StringLen(description))                                            description = StringLeft(__NAME__, 39) +" "+ StringPadLeft(counter, 3, "0");          // 39 + 1 +  3 = 43
            end = StringRight(description, 3);
            if (!StringStartsWith(end, ":") || !StringIsDigit(StringRight(end, 2))) description = StringLeft(description, 43) +" "+ TimeToStr(GetLocalTime(), TIME_FULL); // 43 + 1 + 19 = 63

            // HistorySet erzeugen
            hSet = HistorySet.Create(symbol, description, digits, format, server);

            equityChart.description = description;
         }
      }
      if (!hSet) return(!SetLastError(history.GetLastError()));

      equityChart.hSet = hSet;
      debug("RecordEquity(1)  recording equity to \""+ symbol +"\""+ ifString(!flags, "", " ("+ HistoryFlagsToStr(flags) +")"));
   }


   // (2) Equity-Value bestimmen
   if (!equityChart.value) double value = AccountEquity()-AccountCredit();
   else                           value = equityChart.value;


   // (3) Equity aufzeichnen
   if (!HistorySet.AddTick(equityChart.hSet, Tick.Time, value, flags)) return(!SetLastError(history.GetLastError()));

   return(true);
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
 * Update the expert's EXECUTION_CONTEXT.
 *
 * @return bool - success status
 */
bool UpdateExecutionContext() {
   // (1) EXECUTION_CONTEXT finalisieren
   int hChart = ec_hChart(__ExecutionContext);
   if (!hChart) {
      hChart = WindowHandleEx(NULL); if (!hChart) return(false);
      if (hChart == -1) hChart = 0;
      if (hChart != 0) {
         ec_SetHChart      (__ExecutionContext, hChart           );
         ec_SetHChartWindow(__ExecutionContext, GetParent(hChart));
      }
   }
   ec_SetTestFlags(__ExecutionContext, ifInt(IsTesting(), TF_TEST, 0) | ifInt(IsVisualMode(), TF_VISUAL_TEST, 0) | ifInt(IsOptimization(), TF_OPTIMIZING_TEST, 0));
   ec_SetLogging  (__ExecutionContext, IsLogging());
   ec_SetLogFile  (__ExecutionContext, ""         );


   // (2) globale Variablen initialisieren
   __NAME__       = WindowExpertName();
   __CHART        = hChart && 1;
   __LOG          =          ec_Logging  (__ExecutionContext);
   __LOG_CUSTOM   = __LOG && ec_InitFlags(__ExecutionContext) & INIT_CUSTOMLOG;

   PipDigits      = Digits & (~1);                                        SubPipDigits      = PipDigits+1;
   PipPoints      = MathRound(MathPow(10, Digits & 1));                   PipPoint          = PipPoints;
   Pip            = NormalizeDouble(1/MathPow(10, PipDigits), PipDigits); Pips              = Pip;
   PipPriceFormat = StringConcatenate(".", PipDigits);                    SubPipPriceFormat = StringConcatenate(PipPriceFormat, "'");
   PriceFormat    = ifString(Digits==PipDigits, PipPriceFormat, SubPipPriceFormat);

   N_INF = MathLog(0);
   P_INF = -N_INF;
   NaN   =  N_INF - N_INF;

   return(!catch("UpdateExecutionContext(1)"));
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


#define WM_COMMAND      0x0111


/**
 * Stoppt den Tester. Der Aufruf ist nur im Tester möglich.
 *
 * @return int - Fehlerstatus
 */
int Tester.Stop() {
   if (!IsTesting()) return(catch("Tester.Stop(1)  Tester only function", ERR_FUNC_NOT_ALLOWED));

   if (Tester.IsStopped())        return(NO_ERROR);                  // skipping
   if (__WHEREAMI__ == RF_DEINIT) return(NO_ERROR);                  // SendMessage() darf in deinit() nicht mehr benutzt werden

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

   int    ShowStatus(int error);

   bool   IntInArray(int haystack[], int needle);

#import "Expander.dll"
   int    ec_DllError         (/*EXECUTION_CONTEXT*/int ec[]);
   int    ec_hChartWindow     (/*EXECUTION_CONTEXT*/int ec[]);
   int    ec_InitFlags        (/*EXECUTION_CONTEXT*/int ec[]);
   bool   ec_Logging          (/*EXECUTION_CONTEXT*/int ec[]);
   int    ec_MqlError         (/*EXECUTION_CONTEXT*/int ec[]);

   int    ec_SetDllError      (/*EXECUTION_CONTEXT*/int ec[], int    error         );
   int    ec_SetHChart        (/*EXECUTION_CONTEXT*/int ec[], int    hChart        );
   int    ec_SetHChartWindow  (/*EXECUTION_CONTEXT*/int ec[], int    hChartWindow  );
   bool   ec_SetLogging       (/*EXECUTION_CONTEXT*/int ec[], int    logging       );
   string ec_SetLogFile       (/*EXECUTION_CONTEXT*/int ec[], string logFile       );
   int    ec_SetLpSuperContext(/*EXECUTION_CONTEXT*/int ec[], int    lpSuperContext);
   int    ec_SetRootFunction  (/*EXECUTION_CONTEXT*/int ec[], int    rootFunction  );
   int    ec_SetTestFlags     (/*EXECUTION_CONTEXT*/int ec[], int    testFlags     );

   bool   SyncMainContext_init  (int ec[], int programType, string programName, int rootFunction, int uninitReason, int initFlags, int deinitFlags, string symbol, int period, int lpSec, int isTesting, int isVisualMode, int hChart, int subChartDropped);
   bool   SyncMainContext_start (int ec[], int programType, string programName, int rootFunction, int uninitReason, int initFlags, int deinitFlags, string symbol, int period, int lpSec, int isTesting, int isVisualMode, int hChart, int subChartDropped);
   bool   SyncMainContext_deinit(int ec[], int programType, string programName, int rootFunction, int uninitReason, int initFlags, int deinitFlags, string symbol, int period, int lpSec, int isTesting, int isVisualMode, int hChart, int subChartDropped);

#import "history.ex4"
   int    CreateSymbol(string name, string description, string group, int digits, string baseCurrency, string marginCurrency, string serverName);

   int    HistorySet.Get    (string symbol, string server);
   int    HistorySet.Create (string symbol, string description, int digits, int format, string server);
   bool   HistorySet.Close  (int hSet);
   bool   HistorySet.AddTick(int hSet, datetime time, double value, int flags);
   int    history.GetLastError();

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
