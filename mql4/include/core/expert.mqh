
#define __TYPE__         MT_EXPERT
#define __lpSuperContext NULL
int     __WHEREAMI__   = NULL;                                       // current MQL RootFunction: RF_INIT | RF_START | RF_DEINIT

extern string ____________Tester____________;
extern bool   Tester.ChartInfos   = false;
extern bool   Tester.RecordEquity = false;

#include <functions/InitializeByteBuffer.mqh>
#include <iCustom/icChartInfos.mqh>


// Tester.MetaData
string tester.reporting.server      = "MyFX-Testresults";
int    tester.reporting.id          = 0;
string tester.reporting.symbol      = "";
string tester.reporting.description = "";
int    tester.equity.hSet           = 0;
double tester.equity.value          = 0;                             // kann vom Programm gesetzt werden; default: AccountEquity()-AccountCredit()


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


   // (1) ExecutionContext initialisieren
   int hChart = NULL; if (!IsTesting() || IsVisualMode())            // In Tester WindowHandle() triggers ERR_FUNC_NOT_ALLOWED_IN_TESTER
       hChart = WindowHandle(Symbol(), NULL);                        // if VisualMode=Off.
   SyncMainContext_init(__ExecutionContext, __TYPE__, WindowExpertName(), UninitializeReason(), SumInts(__INIT_FLAGS__), SumInts(__DEINIT_FLAGS__), Symbol(), Period(), __lpSuperContext, IsTesting(), IsVisualMode(), IsOptimization(), hChart, WindowOnDropped());


   // (2) Initialisierung abschließen
   if (!UpdateExecutionContext()) if (CheckErrors("init(1)")) return(last_error);


   // (3) stdlib initialisieren
   int iNull[];
   int error = stdlib.init(iNull);                                   //throws ERS_TERMINAL_NOT_YET_READY
   if (IsError(error)) if (CheckErrors("init(2)")) return(last_error);

                                                                     // #define INIT_TIMEZONE               in stdlib.init()
   // (4) user-spezifische Init-Tasks ausführen                      // #define INIT_PIPVALUE
   int initFlags = ec_InitFlags(__ExecutionContext);                 // #define INIT_BARS_ON_HIST_UPDATE
                                                                     // #define INIT_CUSTOMLOG
   if (initFlags & INIT_PIPVALUE && 1) {
      TickSize = MarketInfo(Symbol(), MODE_TICKSIZE);                // schlägt fehl, wenn kein Tick vorhanden ist
      error = GetLastError();
      if (IsError(error)) {                                          // - Symbol nicht subscribed (Start, Account-/Templatewechsel), Symbol kann noch "auftauchen"
         if (error == ERR_SYMBOL_NOT_AVAILABLE)                      // - synthetisches Symbol im Offline-Chart
            return(debug("init(3)  MarketInfo() => ERR_SYMBOL_NOT_AVAILABLE", SetLastError(ERS_TERMINAL_NOT_YET_READY)));
         if (CheckErrors("init(4)", error)) return(last_error);
      }
      if (!TickSize) return(debug("init(5)  MarketInfo(MODE_TICKSIZE) = 0", SetLastError(ERS_TERMINAL_NOT_YET_READY)));

      double tickValue = MarketInfo(Symbol(), MODE_TICKVALUE);
      error = GetLastError();
      if (IsError(error)) /*&&*/ if (CheckErrors("init(6)", error)) return(last_error);
      if (!tickValue) return(debug("init(7)  MarketInfo(MODE_TICKVALUE) = 0", SetLastError(ERS_TERMINAL_NOT_YET_READY)));
   }
   if (initFlags & INIT_BARS_ON_HIST_UPDATE && 1) {}                 // noch nicht implementiert


   // (5) ggf. EA's aktivieren
   int reasons1[] = { UR_UNDEFINED, UR_CHARTCLOSE, UR_REMOVE };
   if (!IsTesting()) /*&&*/ if (!IsExpertEnabled()) /*&&*/ if (IntInArray(reasons1, UninitializeReason())) {
      error = Toolbar.Experts(true);                                 // TODO: Fehler, wenn bei Terminalstart mehrere EA's den Modus gleichzeitig umschalten wollen
      if (IsError(error)) /*&&*/ if (CheckErrors("init(8)")) return(last_error);
   }


   // (6) nach Neuladen explizit Orderkontext zurücksetzen (siehe MQL.doc)
   int reasons2[] = { UR_UNDEFINED, UR_CHARTCLOSE, UR_REMOVE, UR_ACCOUNT };
   if (IntInArray(reasons2, UninitializeReason()))
      OrderSelect(0, SELECT_BY_TICKET);


   // (7) Im Tester Titelzeile zurücksetzen (ist u.U. vom letzten Test modifiziert)
   if (IsTesting()) {                                                // TODO: Warten, bis Titelzeile gesetzt ist
      if (!SetWindowTextA(GetTesterWindow(), "Tester")) return(CheckErrors("init(9)->user32::SetWindowTextA()", ERR_WIN32_ERROR));
   }


   // (8) User-spezifische init()-Routinen *können*, müssen aber nicht implementiert werden.
   //
   // Die User-Routinen werden ausgeführt, wenn der Preprocessing-Hook (falls implementiert) ohne Fehler zurückkehrt.
   // Der Postprocessing-Hook wird ausgeführt, wenn weder der Preprocessing-Hook (falls implementiert) noch die User-Routinen
   // (falls implementiert) -1 zurückgeben.
   error = onInit();                                                          // Preprocessing-Hook
                                                                              //
   if (!error) {                                                              //
      switch (UninitializeReason()) {                                         //
         case UR_PARAMETERS : error = onInitParameterChange(); break;         //
         case UR_CHARTCHANGE: error = onInitChartChange();     break;         //
         case UR_ACCOUNT    : error = onInitAccountChange();   break;         //
         case UR_CHARTCLOSE : error = onInitChartClose();      break;         //
         case UR_UNDEFINED  : error = onInitUndefined();       break;         //
         case UR_REMOVE     : error = onInitRemove();          break;         //
         case UR_RECOMPILE  : error = onInitRecompile();       break;         //
         // build > 509                                                       //
         case UR_TEMPLATE   : error = onInitTemplate();        break;         //
         case UR_INITFAILED : error = onInitFailed();          break;         //
         case UR_CLOSE      : error = onInitClose();           break;         //
                                                                              //
         default: return(_last_error(CheckErrors("init(10)  unknown UninitializeReason = "+ UninitializeReason(), ERR_RUNTIME_ERROR)));
      }                                                                       //
   }                                                                          //
   if (error == ERS_TERMINAL_NOT_YET_READY) return(error);                    //
                                                                              //
   if (error != -1)                                                           //
      error = afterInit();                                                    // Postprocessing-Hook
   CheckErrors("init(11)");                                                   //
   ShowStatus(last_error);                                                    //
   if (__STATUS_OFF) return(last_error);                                      //


   // (9) Außer bei UR_CHARTCHANGE nicht auf den nächsten echten Tick warten, sondern sofort selbst einen Tick schicken.
   if (UninitializeReason() != UR_CHARTCHANGE) {                              // Ganz zum Schluß, da Ticks verloren gehen, wenn die entsprechende Windows-Message
      error = Chart.SendTick();                                               // vor Verlassen von init() verarbeitet wird.
   }

   CheckErrors("init(12)");
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
      if (__CHART) ShowStatus(last_error);

      static bool tester.stopped = false;
      if (IsTesting() && !tester.stopped) {                          // Im Fehlerfall Tester anhalten. Hier, da der Fehler schon in init() auftreten kann
         Tester.Stop();                                              // oder das Ende von start() evt. nicht mehr ausgeführt wird.
         tester.stopped = true;
      }
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
      __WHEREAMI__ = ec_SetRootFunction(__ExecutionContext, RF_START);              // __STATUS_OFF ist false: evt. ist jedoch ein Status gesetzt, siehe CheckErrors()

      if (last_error == ERS_TERMINAL_NOT_YET_READY) {                               // alle anderen Stati brauchen zur Zeit keine eigene Behandlung
         debug("start(1)  init() returned ERS_TERMINAL_NOT_YET_READY, retrying...");
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
      return(_last_error(CheckErrors("start(2)"), ShowStatus(last_error)));
   }


   // (3) Abschluß der Chart-Initialisierung überprüfen (kann bei Terminal-Start auftreten)
   if (!Bars) return(ShowStatus(SetLastError(debug("start(3)  Bars=0", ERS_TERMINAL_NOT_YET_READY))));


   SyncMainContext_start(__ExecutionContext);


   // (4) stdLib benachrichtigen
   if (stdlib.start(__ExecutionContext, Tick, Tick.Time, ValidBars, ChangedBars) != NO_ERROR)
      if (CheckErrors("start(4)")) return(ShowStatus(last_error));


   // (5) im Tester neues Reporting-Symbol erzeugen und Test initialisieren
   static bool test.initialized = false;
   if (!test.initialized) {
      if (IsTesting()) {
         if (!Test.InitializeReporting()) return(_last_error(CheckErrors("start(5)"), ShowStatus(last_error)));
         test.initialized = true;
      }
   }


   // (6) Main-Funktion aufrufen
   onTick();


   // (7) ggf. ChartInfos anzeigen
   if (Tester.ChartInfos) /*&&*/ if (IsVisualMode())
      icChartInfos();


   // (8) ggf. Equity aufzeichnen
   if (Tester.RecordEquity) /*&&*/ if (IsTesting()) {
      if (!Test.RecordEquity()) return(_last_error(CheckErrors("start(6)"), ShowStatus(last_error)));
   }


   // (9) check errors
   int currError = GetLastError();
   if (currError || last_error || __ExecutionContext[I_EXECUTION_CONTEXT.mqlError] || __ExecutionContext[I_EXECUTION_CONTEXT.dllError])
      CheckErrors("start(7)", currError);
   return(ShowStatus(last_error));
}


/**
 * Globale deinit()-Funktion für Expert Adviser.
 *
 * @return int - Fehlerstatus
 *
 *
 * NOTE: Bei VisualMode=Off und regulärem Testende (Testperiode zu Ende) bricht das Terminal komplexere deinit()-Funktionen
 *       verfrüht ab. Expert::afterDeinit() wird u.U. schon nicht mehr ausgeführt.
 *
 *       Workaround: Testperiode auslesen (Controls), letzten Tick ermitteln (Historydatei) und Test nach letztem Tick per
 *                   Tester.Stop() beenden. Alternativ bei EA's, die dies unterstützen, Testende vors reguläre Testende der
 *                   Historydatei setzen.
 *
 *       29.12.2016: Beides ist Nonsense. Tester.Stop() schickt eine Message in die Message-Loop, der Tester fährt jedoch für
 *                   etliche Ticks fort.
 *                   Prüfen, ob der Fehler nur auftritt, wenn die Historydatei das Ende erreicht oder auch, wenn das Testende
 *                   nicht mit dem Dateiende übereinstimmt.
 */
int deinit() {
   __WHEREAMI__ = RF_DEINIT;
   SyncMainContext_deinit(__ExecutionContext, UninitializeReason());


   if (IsTesting()) {
      if (tester.equity.hSet != 0) {
         int tmp=tester.equity.hSet; tester.equity.hSet=NULL;
         if (!HistorySet.Close(tmp)) return(_last_error(CheckErrors("deinit(1)"), LeaveContext(__ExecutionContext)));
      }
      if (!__STATUS_OFF) {
         datetime endTime = MarketInfo(Symbol(), MODE_TIME);
         CollectTestData(__ExecutionContext, NULL, endTime, NULL, NULL, Bars, NULL, NULL);
      }
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
         case UR_PARAMETERS : error = onDeinitParameterChange(); break;          //
         case UR_CHARTCHANGE: error = onDeinitChartChange();     break;          //
         case UR_ACCOUNT    : error = onDeinitAccountChange();   break;          //
         case UR_CHARTCLOSE : error = onDeinitChartClose();      break;          //
         case UR_UNDEFINED  : error = onDeinitUndefined();       break;          //
         case UR_REMOVE     : error = onDeinitRemove();          break;          //
         case UR_RECOMPILE  : error = onDeinitRecompile();       break;          //
         // build > 509                                                          //
         case UR_TEMPLATE   : error = onDeinitTemplate();        break;          //
         case UR_INITFAILED : error = onDeinitFailed();          break;          //
         case UR_CLOSE      : error = onDeinitClose();           break;          //
                                                                                 //
         default:                                                                //
            CheckErrors("deinit(2)  unknown UninitializeReason = "+ UninitializeReason(), ERR_RUNTIME_ERROR);
            LeaveContext(__ExecutionContext);                                    //
            return(last_error);                                                  //
      }                                                                          //
   }                                                                             //
   if (error != -1)                                                              //
      error = afterDeinit();                                                     // Postprocessing-Hook


   // (2) User-spezifische Deinit-Tasks ausführen
   if (!error) {
      // ...
   }


   CheckErrors("deinit(3)");
   LeaveContext(__ExecutionContext);
   return(last_error);
}


/**
 * Called when a new test starts. Create a new symbol and initialize the test's metadata.
 *
 * @return bool - success status
 */
bool Test.InitializeReporting() {
   // create a new reporting symbol
   int    id             = 0;
   string symbol         = "";
   string symbolGroup    = __NAME__;
   string description    = "";
   int    digits         = 2;
   string baseCurrency   = AccountCurrency();
   string marginCurrency = AccountCurrency();


   // (1) open "symbols.raw" and read the existing symbols
   string mqlFileName = ".history\\"+ tester.reporting.server +"\\symbols.raw";
   int hFile = FileOpen(mqlFileName, FILE_READ|FILE_BIN);
   int error = GetLastError();
   if (IsError(error) || hFile <= 0)                              return(!catch("Test.InitializeReporting(1)->FileOpen(\""+ mqlFileName +"\", FILE_READ) => "+ hFile, ifInt(error, error, ERR_RUNTIME_ERROR)));

   int fileSize = FileSize(hFile);
   if (fileSize % SYMBOL.size != 0) { FileClose(hFile);           return(!catch("Test.InitializeReporting(2)  invalid size of \""+ mqlFileName +"\" (not an even SYMBOL size, "+ (fileSize % SYMBOL.size) +" trailing bytes)", ifInt(SetLastError(GetLastError()), last_error, ERR_RUNTIME_ERROR))); }
   int symbolsSize = fileSize/SYMBOL.size;

   /*SYMBOL[]*/int symbols[]; InitializeByteBuffer(symbols, fileSize);
   if (fileSize > 0) {
      // read symbols
      int ints = FileReadArray(hFile, symbols, 0, fileSize/4);
      error = GetLastError();
      if (IsError(error) || ints!=fileSize/4) { FileClose(hFile); return(!catch("Test.InitializeReporting(3)  error reading \""+ mqlFileName +"\" ("+ ints*4 +" of "+ fileSize +" bytes read)", ifInt(error, error, ERR_RUNTIME_ERROR))); }
   }
   FileClose(hFile);


   // (2) iterate over existing symbols and determine the next available one matching "{ExpertName}.{001-xxx}"
   string suffix, name = StringLeft(StringReplace(__NAME__, " ", ""), 7) +".";

   for (int i, maxId=0; i < symbolsSize; i++) {
      symbol = symbols_Name(symbols, i);
      if (StringStartsWithI(symbol, name)) {
         suffix = StringRight(symbol, -StringLen(name));
         if (StringLen(suffix)==3) /*&&*/ if (StringIsDigit(suffix)) {
            maxId = Max(maxId, StrToInteger(suffix));
         }
      }
   }
   id     = maxId + 1;
   symbol = name + StringPadLeft(id, 3, "0");


   // (3) compose symbol description
   description = StringLeft(__NAME__, 38) +" #"+ id;                                // 38 + 2 +  3 = 43 chars
   description = description +" "+ DateTimeToStr(GetLocalTime(), "D.M.Y H:I:S");    // 43 + 1 + 19 = 63 chars


   // (4) create symbol
   if (CreateSymbol(symbol, description, symbolGroup, digits, baseCurrency, marginCurrency, tester.reporting.server) < 0)
      return(false);

   tester.reporting.id          = id;
   tester.reporting.symbol      = symbol;
   tester.reporting.description = description;


   // (5) initialize test metadata
   datetime startTime       = MarketInfo(Symbol(), MODE_TIME);
   double   accountBalance  = AccountBalance();
   string   accountCurrency = AccountCurrency();
   CollectTestData(__ExecutionContext, startTime, NULL, Bid, Ask, Bars, tester.reporting.id, tester.reporting.symbol);

   return(true);
}


/**
 * Record the test's equity graph.
 *
 * @return bool - success status
 */
bool Test.RecordEquity() {
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
   int flags = HST_BUFFER_TICKS;


   // (1) HistorySet öffnen
   if (!tester.equity.hSet) {
      string symbol      = tester.reporting.symbol;
      string description = tester.reporting.description;
      int    digits      = 2;
      int    format      = 400;
      string server      = tester.reporting.server;

      // HistorySet erzeugen
      tester.equity.hSet = HistorySet.Create(symbol, description, digits, format, server);
      if (!tester.equity.hSet) return(false);
      //debug("Test.RecordEquity(1)  recording equity to \""+ symbol +"\""+ ifString(!flags, "", " ("+ HistoryFlagsToStr(flags) +")"));
   }


   // (2) Equity-Value bestimmen und aufzeichnen
   if (!tester.equity.value) double value = AccountEquity()-AccountCredit();
   else                             value = tester.equity.value;
   if (!HistorySet.AddTick(tester.equity.hSet, Tick.Time, value, flags))
      return(false);
   return(true);
}


/**
 * Gibt die ID des aktuellen Deinit()-Szenarios zurück. Kann nur in deinit() aufgerufen werden.
 *
 * @return int - ID oder NULL, falls ein Fehler auftrat
 */
int DeinitReason() {
   return(!catch("DeinitReason(1)", ERR_NOT_IMPLEMENTED));
}


/**
 * Whether or not the current program is an expert.
 *
 * @return bool
 */
bool IsExpert() {
   return(true);
}


/**
 * Whether or not the current program is a script.
 *
 * @return bool
 */
bool IsScript() {
   return(false);
}


/**
 * Whether or not the current program is an indicator.
 *
 * @return bool
 */
bool IsIndicator() {
   return(false);
}


/**
 * Whether or not the current module is a library.
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
   ec_SetLogging(__ExecutionContext, IsLogging());                   // TODO: implement in DLL


   // (2) globale Variablen initialisieren
   __NAME__       = WindowExpertName();
   __CHART        =    _bool(ec_hChart   (__ExecutionContext));
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
 * Check and update the program's error status and activate the flag __STATUS_OFF accordingly.
 *
 * @param  string location  - location of the check
 * @param  int    currError - current not yet signaled local error
 *
 * @return bool - whether or not the flag __STATUS_OFF is activated
 */
bool CheckErrors(string location, int currError=NULL) {
   // (1) check and signal DLL errors
   int dll_error = ec_DllError(__ExecutionContext);                  // TODO: signal DLL errors
   if (dll_error && 1) {
      __STATUS_OFF        = true;                                    // all DLL errors are terminating errors
      __STATUS_OFF.reason = dll_error;
   }


   // (2) check MQL errors
   int mql_error = ec_MqlError(__ExecutionContext);
   switch (mql_error) {
      case NO_ERROR:
      case ERS_HISTORY_UPDATE:
      case ERS_TERMINAL_NOT_YET_READY:
      case ERS_EXECUTION_STOPPING:
         break;
      default:
         __STATUS_OFF        = true;
         __STATUS_OFF.reason = mql_error;                            // MQL errors have higher severity than DLL errors
   }


   // (3) check last_error
   switch (last_error) {
      case NO_ERROR:
      case ERS_HISTORY_UPDATE:
      case ERS_TERMINAL_NOT_YET_READY:
      case ERS_EXECUTION_STOPPING:
         break;
      default:
         __STATUS_OFF        = true;
         __STATUS_OFF.reason = last_error;                           // local errors have higher severity than library errors
   }


   // (4) check uncatched errors
   if (!currError) currError = GetLastError();
   if (currError && 1) {
      catch(location, currError);
      __STATUS_OFF        = true;
      __STATUS_OFF.reason = currError;                               // all uncatched errors are terminating errors
   }


   // (5) update variable last_error
   if (__STATUS_OFF) /*&&*/ if (!last_error)
      last_error = __STATUS_OFF.reason;

   return(__STATUS_OFF);

   // dummy calls to suppress compiler warnings
   __DummyCalls();
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
   int    stdlib.init  (int tickData[]);
   int    stdlib.start (/*EXECUTION_CONTEXT*/int ec[], int tick, datetime tickTime, int validBars, int changedBars);

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
   int    ec_DllError       (/*EXECUTION_CONTEXT*/int ec[]);
   int    ec_hChartWindow   (/*EXECUTION_CONTEXT*/int ec[]);
   int    ec_InitFlags      (/*EXECUTION_CONTEXT*/int ec[]);
   bool   ec_Logging        (/*EXECUTION_CONTEXT*/int ec[]);
   int    ec_MqlError       (/*EXECUTION_CONTEXT*/int ec[]);

   int    ec_SetDllError    (/*EXECUTION_CONTEXT*/int ec[], int error       );
   bool   ec_SetLogging     (/*EXECUTION_CONTEXT*/int ec[], int status      );
   int    ec_SetRootFunction(/*EXECUTION_CONTEXT*/int ec[], int rootFunction);

   string symbols_Name(/*SYMBOL*/int symbols[], int i);

   bool   SyncMainContext_init  (int ec[], int programType, string programName, int uninitReason, int initFlags, int deinitFlags, string symbol, int period, int lpSec, int isTesting, int isVisualMode, int isOptimization, int hChart, int subChartDropped);
   bool   SyncMainContext_start (int ec[]);
   bool   SyncMainContext_deinit(int ec[], int uninitReason);

   bool   CollectTestData(int ec[], datetime from, datetime to, double bid, double ask, int bars, int reportingId, string reportingSymbol);
   bool   Test_OpenOrder (int ec[], int ticket, int type, double lots, string symbol, double openPrice, datetime openTime, double stopLoss, double takeProfit, double commission, int magicNumber, string comment);
   bool   Test_CloseOrder(int ec[], int ticket, double closePrice, datetime closeTime, double swap, double profit);

#import "history.ex4"
   int    CreateSymbol(string name, string description, string group, int digits, string baseCurrency, string marginCurrency, string serverName);

   int    HistorySet.Get    (string symbol, string server);
   int    HistorySet.Create (string symbol, string description, int digits, int format, string server);
   bool   HistorySet.Close  (int hSet);
   bool   HistorySet.AddTick(int hSet, datetime time, double value, int flags);

#import "user32.dll"
   int  SendMessageA(int hWnd, int msg, int wParam, int lParam);
   bool SetWindowTextA(int hWnd, string lpString);
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
