
#define __TYPE__         MT_EXPERT
#define __lpSuperContext NULL
int     __WHEREAMI__   = NULL;                                             // the current MQL RootFunction: RF_INIT | RF_START | RF_DEINIT

extern string   _______________________________ = "";
extern bool     EA.ExtendedReporting            = false;
extern bool     EA.RecordEquity                 = false;
extern datetime Test.StartTime                  = 0;                       // time to start a test
extern double   Test.StartPrice                 = 0;                       // price to start a test

#include <functions/InitializeByteBuffer.mqh>

// current price series
double rates[][6];
bool   ratesCopied = false;

// test metadata
string test.report.server      = "XTrade-Testresults";
int    test.report.id          = 0;
string test.report.symbol      = "";
string test.report.description = "";
int    test.equity.hSet        = 0;
double test.equity.value       = 0;                                        // default: AccountEquity()-AccountCredit(), may be overridden


/**
 * Global init() function for experts.
 *
 * @return int - error status
 *
 * @throws ERS_TERMINAL_NOT_YET_READY
 */
int init() {
   if (__STATUS_OFF) {                                                     // TODO: process ERR_INVALID_INPUT_PARAMETER (enable re-input)
      if (__STATUS_OFF.reason == ERR_TERMINAL_FAILURE_INIT) {
         debug("init(1)  global state has been kept over the failed Expert::init() call  [ERR_TERMINAL_FAILURE_INIT]");
         Print("init(1)  global state has been kept over the failed Expert::init() call  [ERR_TERMINAL_FAILURE_INIT]");
      }
      else ShowStatus(__STATUS_OFF.reason);
      return(__STATUS_OFF.reason);
   }

   if (!IsDllsAllowed()) {
      Alert("DLL function calls are not enabled. Please go to Tools -> Options -> Expert Advisors and allow DLL imports.");
      last_error          = ERR_DLL_CALLS_NOT_ALLOWED;
      __STATUS_OFF        = true;
      __STATUS_OFF.reason = last_error;
      return(last_error);
   }
   if (!IsLibrariesAllowed()) {
      Alert("MQL library calls are not enabled. Please load the EA with \"Allow imports of external experts\" enabled.");
      last_error          = ERR_EX4_CALLS_NOT_ALLOWED;
      __STATUS_OFF        = true;
      __STATUS_OFF.reason = last_error;
      return(last_error);
   }

   if (__WHEREAMI__ == NULL) {                                             // init() is called by the terminal
      __WHEREAMI__ = RF_INIT;                                              // TODO: ??? does this work in experts ???
      prev_error   = last_error;
      zTick        = 0;
      ec_SetDllError(__ExecutionContext, SetLastError(NO_ERROR));
   }


   // (1) initialize the execution context
   int hChart = NULL; if (!IsTesting() || IsVisualMode())                  // in Tester WindowHandle() triggers ERR_FUNC_NOT_ALLOWED_IN_TESTER
       hChart = WindowHandle(Symbol(), NULL);                              // if VisualMode=Off
   int error = SyncMainContext_init(__ExecutionContext, __TYPE__, WindowExpertName(), UninitializeReason(), SumInts(__INIT_FLAGS__), SumInts(__DEINIT_FLAGS__), Symbol(), Period(), Digits, EA.ExtendedReporting, EA.RecordEquity, IsTesting(), IsVisualMode(), IsOptimization(), __lpSuperContext, hChart, WindowOnDropped(), WindowXOnDropped(), WindowYOnDropped());
   if (IsError(error)) {
      Alert("ERROR:   ", Symbol(), ",", PeriodDescription(Period()), "  ", WindowExpertName(), "::init(1)->SyncMainContext_init()  [", ErrorToStr(error), "]");
      PlaySoundEx("Siren.wav");
      last_error          = error;
      __STATUS_OFF        = true;                                          // If SyncMainContext_init() failed the content of the EXECUTION_CONTEXT
      __STATUS_OFF.reason = last_error;                                    // is undefined. We must not trigger loading of MQL libraries and return asap.
      __WHEREAMI__        = NULL;
      return(last_error);
   }


   // (2) finish initialization
   if (!UpdateGlobalVars()) if (CheckErrors("init(2)")) return(last_error);


   // (3) initialize rsfLib1
   int iNull[];
   error = _lib1.init(iNull);                                              // throws ERS_TERMINAL_NOT_YET_READY
   if (IsError(error)) if (CheckErrors("init(3)")) return(last_error);

                                                                           // #define INIT_TIMEZONE               in _lib1.init()
   // (4) execute custom init tasks                                        // #define INIT_PIPVALUE
   int initFlags = ec_InitFlags(__ExecutionContext);                       // #define INIT_BARS_ON_HIST_UPDATE
                                                                           // #define INIT_CUSTOMLOG
   if (initFlags & INIT_TIMEZONE && 1) {
      if (!StringLen(GetServerTimezone()))  return(_last_error(CheckErrors("init(4)")));
   }
   if (initFlags & INIT_PIPVALUE && 1) {
      TickSize = MarketInfo(Symbol(), MODE_TICKSIZE);                      // fails if there is no tick yet
      error = GetLastError();
      if (IsError(error)) {                                                // symbol not yet subscribed (start, account/template change), it may "show up" later
         if (error == ERR_SYMBOL_NOT_AVAILABLE)                            // synthetic symbol in offline chart
            return(log("init(5)  MarketInfo() => ERR_SYMBOL_NOT_AVAILABLE", SetLastError(ERS_TERMINAL_NOT_YET_READY)));
         if (CheckErrors("init(6)", error)) return(last_error);
      }
      if (!TickSize) return(log("init(7)  MarketInfo(MODE_TICKSIZE) = 0", SetLastError(ERS_TERMINAL_NOT_YET_READY)));

      double tickValue = MarketInfo(Symbol(), MODE_TICKVALUE);
      error = GetLastError();
      if (IsError(error)) /*&&*/ if (CheckErrors("init(8)", error)) return(last_error);
      if (!tickValue) return(log("init(9)  MarketInfo(MODE_TICKVALUE) = 0", SetLastError(ERS_TERMINAL_NOT_YET_READY)));
   }
   if (initFlags & INIT_BARS_ON_HIST_UPDATE && 1) {}                       // not yet implemented


   // (5) enable experts if disabled
   int reasons1[] = {UR_UNDEFINED, UR_CHARTCLOSE, UR_REMOVE};
   if (!IsTesting()) /*&&*/ if (!IsExpertEnabled()) /*&&*/ if (IntInArray(reasons1, UninitializeReason())) {
      error = Toolbar.Experts(true);                                       // TODO: fails if multiple experts try to do it at the same time (e.g. at terminal start)
      if (IsError(error)) /*&&*/ if (CheckErrors("init(10)")) return(last_error);
   }


   // (6) we must explicitely reset the order context after the expert was reloaded (see MQL.doc)
   int reasons2[] = {UR_UNDEFINED, UR_CHARTCLOSE, UR_REMOVE, UR_ACCOUNT};
   if (IntInArray(reasons2, UninitializeReason())) {
      OrderSelect(0, SELECT_BY_TICKET);
      error = GetLastError();
      if (error && error!=ERR_NO_TICKET_SELECTED) return(_last_error(CheckErrors("init(11)", error)));
   }


   // (7) reset the window title in the Tester (might have been modified by the previous test)
   if (IsTesting()) {                                                      // TODO: wait until done
      if (!SetWindowTextA(FindTesterWindow(), "Tester")) return(_last_error(CheckErrors("init(12)->user32::SetWindowTextA()", ERR_WIN32_ERROR)));
      // get account number on start as a later call may block the UI thread if in deinit()
      if (!GetAccountNumber())                           return(_last_error(CheckErrors("init(13)")));
   }


   // (8) before onInit(): log original input parameters
   if (UninitializeReason() != UR_CHARTCHANGE) {
      string initialInput/*=InputsToStr()*/, modifiedInput;                // un-comment for debugging only
      if (StringLen(initialInput) > 0) {
         initialInput = StringConcatenate(initialInput,
            ifString(!EA.ExtendedReporting, "", NL+"EA.ExtendedReporting=TRUE"                                   +";"),
            ifString(!EA.RecordEquity,      "", NL+"EA.RecordEquity=TRUE"                                        +";"),
            ifString(!Test.StartTime,       "", NL+"Test.StartTime="+  TimeToStr(Test.StartTime, TIME_FULL)      +";"),
            ifString(!Test.StartPrice,      "", NL+"Test.StartPrice="+ NumberToStr(Test.StartPrice, PriceFormat) +";"));
         __LOG = true;
         log("init()  input: "+ initialInput);
      }
   }


   // (9) Execute init() event handlers. The reason-specific event handlers are not executed if the pre-processing hook
   //     returns with an error. The post-processing hook is executed only if neither the pre-processing hook nor the reason-
   //     specific handlers return with -1 (which is a hard stop as opposite to a regular error).
   //
   // +-- init reason -------+-- description --------------------------------+-- ui -----------+-- applies --+
   // | IR_USER              | loaded by the user (also in tester)           |    input dialog |   I, E, S   |   I = indicators
   // | IR_TEMPLATE          | loaded by a template (also at terminal start) | no input dialog |   I, E      |   E = experts
   // | IR_PROGRAM           | loaded by iCustom()                           | no input dialog |   I         |   S = scripts
   // | IR_PROGRAM_AFTERTEST | loaded by iCustom() after end of test         | no input dialog |   I         |
   // | IR_PARAMETERS        | input parameters changed                      |    input dialog |   I, E      |
   // | IR_TIMEFRAMECHANGE   | chart period changed                          | no input dialog |   I, E      |
   // | IR_SYMBOLCHANGE      | chart symbol changed                          | no input dialog |   I, E      |
   // | IR_RECOMPILE         | reloaded after recompilation                  | no input dialog |   I, E      |
   // | IR_TERMINAL_FAILURE  | terminal failure                              |    input dialog |      E      |   @see https://github.com/rosasurfer/mt4-mql/issues/1
   // +----------------------+-----------------------------------------------+-----------------+-------------+
   //
   error = onInit();                                                          // pre-processing hook
                                                                              //
   if (!error && !__STATUS_OFF) {                                             //
      int initReason = InitReason();                                          //
      if (!initReason) if (CheckErrors("init(14)")) return(last_error);       //
                                                                              //
      switch (initReason) {                                                   //
         case IR_USER            : error = onInit_User();            break;   // init reasons
         case IR_TEMPLATE        : error = onInit_Template();        break;   //
         case IR_PARAMETERS      : error = onInit_Parameters();      break;   //
         case IR_TIMEFRAMECHANGE : error = onInit_TimeframeChange(); break;   //
         case IR_SYMBOLCHANGE    : error = onInit_SymbolChange();    break;   //
         case IR_RECOMPILE       : error = onInit_Recompile();       break;   //
         case IR_TERMINAL_FAILURE:                                            //
         default:                                                             //
            return(_last_error(CheckErrors("init(15)  unsupported initReason = "+ initReason, ERR_RUNTIME_ERROR)));
      }                                                                       //
   }                                                                          //
   if (error == ERS_TERMINAL_NOT_YET_READY) return(error);                    //
                                                                              //
   if (error != -1)                                                           //
      afterInit();                                                            // post-processing hook
   if (CheckErrors("init(16)")) return(last_error);


   // (10) after onInit(): log modified input parameters
   if (UninitializeReason() != UR_CHARTCHANGE) {
      modifiedInput = InputsToStr();
      if (StringLen(modifiedInput) > 0) {
         modifiedInput = StringConcatenate(modifiedInput,
            ifString(!EA.ExtendedReporting, "", NL+"EA.ExtendedReporting=TRUE"                                   +";"),
            ifString(!EA.RecordEquity,      "", NL+"EA.RecordEquity=TRUE"                                        +";"),
            ifString(!Test.StartTime,       "", NL+"Test.StartTime="+  TimeToStr(Test.StartTime, TIME_FULL)      +";"),
            ifString(!Test.StartPrice,      "", NL+"Test.StartPrice="+ NumberToStr(Test.StartPrice, PriceFormat) +";"));
         modifiedInput = InputParamsDiff(initialInput, modifiedInput);
         if (StringLen(modifiedInput) > 0) {
            __LOG = true;
            log("init()  input: "+ modifiedInput);
         }
      }
   }


   // (11) in Tester: log MarketInfo() data
   if (IsTesting())
      Test.LogMarketInfo();

   if (CheckErrors("init(17)"))
      return(last_error);


   // (12) don't wait and immediately send a fake tick (except on UR_CHARTCHANGE)
   if (UninitializeReason() != UR_CHARTCHANGE)                             // At the very end, otherwise the tick might get
      Chart.SendTick();                                                    // lost if the Windows message queue was processed
   return(last_error);                                                     // before init() is left.
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
      if (IsDllsAllowed() && IsLibrariesAllowed() && __STATUS_OFF.reason!=ERR_TERMINAL_FAILURE_INIT) {
         if (__CHART) ShowStatus(__STATUS_OFF.reason);
         static bool tester.stopped = false;
         if (IsTesting() && !tester.stopped) {                                      // Im Fehlerfall Tester anhalten. Hier, da der Fehler schon in init() auftreten kann
            Tester.Stop();                                                          // oder das Ende von start() evt. nicht mehr ausgeführt wird.
            tester.stopped = true;
         }
      }
      return(last_error);
   }

   Tick++; zTick++;                                                                 // einfache Zähler, die konkreten Werte haben keine Bedeutung
   Tick.prevTime  = Tick.Time;
   Tick.Time      = MarketInfo(Symbol(), MODE_TIME);
   Tick.isVirtual = true;
   ValidBars      = -1;                                                             // in experts not available
   ChangedBars    = -1;                                                             // ...
   ShiftedBars    = -1;                                                             // ...


   // (1) Falls wir aus init() kommen, dessen Ergebnis prüfen
   if (__WHEREAMI__ == RF_INIT) {
      __WHEREAMI__ = ec_SetRootFunction(__ExecutionContext, RF_START);              // __STATUS_OFF ist false: evt. ist jedoch ein Status gesetzt, siehe CheckErrors()

      if (last_error == ERS_TERMINAL_NOT_YET_READY) {                               // alle anderen Stati brauchen zur Zeit keine eigene Behandlung
         log("start(1)  init() returned ERS_TERMINAL_NOT_YET_READY, retrying...");
         last_error = NO_ERROR;

         int error = init();                                                        // init() erneut aufrufen
         if (__STATUS_OFF) return(last_error);

         if (error == ERS_TERMINAL_NOT_YET_READY) {                                 // wenn überhaupt, kann wieder nur ein Status gesetzt sein
            __WHEREAMI__ = ec_SetRootFunction(__ExecutionContext, RF_INIT);         // __WHEREAMI__ zurücksetzen und auf den nächsten Tick warten
            return(ShowStatus(error));
         }
      }
      last_error = NO_ERROR;                                                        // init() war erfolgreich, ein vorhandener Status wird überschrieben
   }
   else {
      prev_error = last_error;                                                      // weiterer Tick: last_error sichern und zurücksetzen
      ec_SetDllError(__ExecutionContext, SetLastError(NO_ERROR));
   }


   // (2) bei Bedarf Input-Dialog aufrufen
   if (__STATUS_RELAUNCH_INPUT) {
      __STATUS_RELAUNCH_INPUT = false;
      start.RelaunchInputDialog();
      return(_last_error(CheckErrors("start(2)")));
   }


   // (3) Abschluß der Chart-Initialisierung überprüfen (kann bei Terminal-Start auftreten)
   if (!Bars) return(ShowStatus(SetLastError(log("start(3)  Bars=0", ERS_TERMINAL_NOT_YET_READY))));


   // (4) Im Tester StartTime/StartPrice abwarten
   if (IsTesting()) {
      if (Test.StartTime != 0) {
         if (Tick.Time < Test.StartTime)
            return(last_error);
         Test.StartTime = 0;
      }
      if (Test.StartPrice != 0) {
         static double test.lastPrice; if (!test.lastPrice) {
            test.lastPrice = Bid;
            return(last_error);
         }
         if (LT(test.lastPrice, Test.StartPrice)) /*&&*/ if (LT(Bid, Test.StartPrice)) {
            test.lastPrice = Bid;
            return(last_error);
         }
         if (GT(test.lastPrice, Test.StartPrice)) /*&&*/ if (GT(Bid, Test.StartPrice)) {
            test.lastPrice = Bid;
            return(last_error);
         }
         Test.StartPrice = 0;
      }
   }

   if (!ratesCopied && Bars) {
      ArrayCopyRates(rates);
      ratesCopied = true;
   }

   if (SyncMainContext_start(__ExecutionContext, rates, Bars, Tick, Tick.Time, Bid, Ask) != NO_ERROR) {
      if (CheckErrors("start(4)")) return(last_error);
   }


   // (5) stdLib benachrichtigen
   if (_lib1.start(Tick, Tick.Time, ValidBars, ChangedBars) != NO_ERROR) {
      if (CheckErrors("start(5)")) return(last_error);
   }


   // (6) ggf. Test initialisieren
   if (IsTesting()) {
      static bool test.initialized = false; if (!test.initialized) {
         if (!Test.InitReporting()) return(_last_error(CheckErrors("start(6)")));
         test.initialized = true;
      }
   }


   // (7) Main-Funktion aufrufen
   onTick();


   // (8) ggf. Equity aufzeichnen
   if (IsTesting()) /*&&*/ if (!IsOptimization()) /*&&*/ if (EA.RecordEquity) {
      if (!Test.RecordEquityGraph()) return(_last_error(CheckErrors("start(7)")));
   }


   // (9) check errors
   error = GetLastError();
   if (error || last_error|__ExecutionContext[I_EXECUTION_CONTEXT.mqlError]|__ExecutionContext[I_EXECUTION_CONTEXT.dllError])
      return(_last_error(CheckErrors("start(8)", error)));

   return(ShowStatus(NO_ERROR));
}


/**
 * Globale deinit()-Funktion für Experts.
 *
 * @return int - Fehlerstatus
 *
 *
 * NOTE: Bei VisualMode=Off und regulärem Testende (Testperiode zu Ende) bricht das Terminal komplexere deinit()-Funktionen
 *       verfrüht ab. Expert::afterDeinit() wird u.U. schon nicht mehr ausgeführt.
 *
 *       Workaround: (1) Testperiode auslesen (Controls), letzten Tick ermitteln (Historydatei) und Test nach letztem Tick
 *                       per Tester.Stop() beenden.
 *                   (2) Alternativ bei EA's, die dies unterstützen, Testende vors reguläre Testende der Historydatei setzen.
 *
 *       29.12.2016: Beides ist Nonsense. Tester.Stop() schickt eine Message in die Message-Loop des UI-Threads, der Tester
 *                   (in einem anderen Thread) fährt jedoch für etliche Ticks fort. Statt dessen prüfen, ob der Fehler nur
 *                   auftritt, wenn die Historydatei das Ende erreicht oder auch, wenn das Testende nicht mit dem Dateiende
 *                   übereinstimmt. Je nach Ergebnis können kritische Endarbeiten im letzten Tick oder in deinit() in den
 *                   Expander (der vom Terminal nicht vorzeitig abgebrochen werden kann) delegiert werden.
 */
int deinit() {
   __WHEREAMI__ = RF_DEINIT;

   if (!IsDllsAllowed() || !IsLibrariesAllowed() || __STATUS_OFF.reason==ERR_TERMINAL_FAILURE_INIT)
      return(last_error);

   int error = SyncMainContext_deinit(__ExecutionContext, UninitializeReason());
   if (IsError(error)) return(error|last_error|LeaveContext(__ExecutionContext));

   if (IsTesting()) {
      if (test.equity.hSet != 0) {
         int tmp=test.equity.hSet; test.equity.hSet=NULL;
         if (!HistorySet.Close(tmp)) return(_last_error(CheckErrors("deinit(1)"))|LeaveContext(__ExecutionContext));
      }
      if (!__STATUS_OFF) /*&&*/ if (EA.ExtendedReporting) {
         datetime endTime = MarketInfo(Symbol(), MODE_TIME);
         Test_StopReporting(__ExecutionContext, endTime, Bars);
      }
   }


   // (1) User-spezifische deinit()-Routinen *können*, müssen aber nicht implementiert werden.
   //
   // Die User-Routinen werden ausgeführt, wenn der Preprocessing-Hook (falls implementiert) ohne Fehler zurückkehrt.
   // Der Postprocessing-Hook wird ausgeführt, wenn weder der Preprocessing-Hook (falls implementiert) noch die User-Routinen
   // (falls implementiert) -1 zurückgeben.
   error = onDeinit();                                                     // Preprocessing-Hook
   if (!error) {                                                           //
      switch (UninitializeReason()) {                                      //
         case UR_PARAMETERS : error = onDeinitParameterChange(); break;    //
         case UR_CHARTCHANGE: error = onDeinitChartChange();     break;    //
         case UR_ACCOUNT    : error = onDeinitAccountChange();   break;    //
         case UR_CHARTCLOSE : error = onDeinitChartClose();      break;    //
         case UR_UNDEFINED  : error = onDeinitUndefined();       break;    //
         case UR_REMOVE     : error = onDeinitRemove();          break;    //
         case UR_RECOMPILE  : error = onDeinitRecompile();       break;    //
         // build > 509                                                    //
         case UR_TEMPLATE   : error = onDeinitTemplate();        break;    //
         case UR_INITFAILED : error = onDeinitFailed();          break;    //
         case UR_CLOSE      : error = onDeinitClose();           break;    //
                                                                           //
         default:                                                          //
            CheckErrors("deinit(2)  unknown UninitializeReason = "+ UninitializeReason(), ERR_RUNTIME_ERROR);
            return(last_error|LeaveContext(__ExecutionContext));           //
      }                                                                    //
   }                                                                       //
   if (error != -1)                                                        //
      error = afterDeinit();                                               // Postprocessing-Hook


   // (2) User-spezifische Deinit-Tasks ausführen
   if (!error) {
      // ...
   }


   CheckErrors("deinit(3)");
   return(last_error|LeaveContext(__ExecutionContext));                    // must be the very last statement
}


/**
 * Called once at start of a test. If reporting is enabled the test's metadata is initialized.
 *
 * @return bool - success status
 */
bool Test.InitReporting() {
   if (!IsTesting())
      return(false);


   // (1) prepare environment to record the equity curve
   if (EA.RecordEquity) /*&&*/ if (!IsOptimization()) {
      // create a new report symbol
      int    id             = 0;
      string symbol         = "";
      string symbolGroup    = StrLeft(__NAME__, MAX_SYMBOL_GROUP_LENGTH);
      string description    = "";
      int    digits         = 2;
      string baseCurrency   = AccountCurrency();
      string marginCurrency = AccountCurrency();

      // (1.1) open "symbols.raw" and read the existing symbols
      string mqlFileName = "history\\"+ test.report.server +"\\symbols.raw";
      int hFile = FileOpen(mqlFileName, FILE_READ|FILE_BIN);
      int error = GetLastError();
      if (IsError(error) || hFile <= 0)                              return(!catch("Test.InitReporting(1)->FileOpen(\""+ mqlFileName +"\", FILE_READ) => "+ hFile, ifInt(error, error, ERR_RUNTIME_ERROR)));

      int fileSize = FileSize(hFile);
      if (fileSize % SYMBOL.size != 0) { FileClose(hFile);           return(!catch("Test.InitReporting(2)  invalid size of \""+ mqlFileName +"\" (not an even SYMBOL size, "+ (fileSize % SYMBOL.size) +" trailing bytes)", ifInt(SetLastError(GetLastError()), last_error, ERR_RUNTIME_ERROR))); }
      int symbolsSize = fileSize/SYMBOL.size;

      /*SYMBOL[]*/int symbols[]; InitializeByteBuffer(symbols, fileSize);
      if (fileSize > 0) {
         // read symbols
         int ints = FileReadArray(hFile, symbols, 0, fileSize/4);
         error = GetLastError();
         if (IsError(error) || ints!=fileSize/4) { FileClose(hFile); return(!catch("Test.InitReporting(3)  error reading \""+ mqlFileName +"\" ("+ ints*4 +" of "+ fileSize +" bytes read)", ifInt(error, error, ERR_RUNTIME_ERROR))); }
      }
      FileClose(hFile);

      // (1.2) iterate over existing symbols and determine the next available one matching "{ExpertName}.{001-xxx}"
      string suffix, name = StrLeft(StrReplace(__NAME__, " ", ""), 7) +".";

      for (int i, maxId=0; i < symbolsSize; i++) {
         symbol = symbols_Name(symbols, i);
         if (StrStartsWithI(symbol, name)) {
            suffix = StrRight(symbol, -StringLen(name));
            if (StringLen(suffix)==3) /*&&*/ if (StrIsDigit(suffix)) {
               maxId = Max(maxId, StrToInteger(suffix));
            }
         }
      }
      id     = maxId + 1;
      symbol = name + StrPadLeft(id, 3, "0");

      // (1.3) create a symbol description                                             // sizeof(SYMBOL.description) = 64
      description = StrLeft(__NAME__, 38) +" #"+ id;                                   // 38 + 2 +  3 = 43 chars
      description = description +" "+ DateTimeToStr(GetLocalTime(), "D.M.Y H:I:S");    // 43 + 1 + 19 = 63 chars

      // (1.4) create symbol
      if (CreateSymbol(symbol, description, symbolGroup, digits, baseCurrency, marginCurrency, test.report.server) < 0)
         return(false);

      test.report.id          = id;
      test.report.symbol      = symbol;
      test.report.description = description;
   }


   // (2) prepare environment to collect data for reporting
   if (EA.ExtendedReporting) {
      datetime startTime = MarketInfo(Symbol(), MODE_TIME);
      int      barModel  = Tester.GetBarModel();
      Test_StartReporting(__ExecutionContext, startTime, Bars, barModel, test.report.id, test.report.symbol);
   }
   return(true);
}


/**
 * Record the test's equity graph.
 *
 * @return bool - success status
 *
 * NOTE: Named like this to avoid confusion with the input parameter of the same name.
 */
bool Test.RecordEquityGraph() {
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
   if (!test.equity.hSet) {
      string symbol      = test.report.symbol;
      string description = test.report.description;
      int    digits      = 2;
      int    format      = 400;
      string server      = test.report.server;

      // HistorySet erzeugen
      test.equity.hSet = HistorySet.Create(symbol, description, digits, format, server);
      if (!test.equity.hSet) return(false);
      //debug("RecordEquityGraph(1)  recording equity to \""+ symbol +"\""+ ifString(!flags, "", " ("+ HistoryFlagsToStr(flags) +")"));
   }


   // (2) Equity-Value bestimmen und aufzeichnen
   if (!test.equity.value) double value = AccountEquity()-AccountCredit();
   else                           value = test.equity.value;
   if (!HistorySet.AddTick(test.equity.hSet, Tick.Time, value, flags))
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
bool UpdateGlobalVars() {
   // (1) EXECUTION_CONTEXT finalisieren
   ec_SetLogging(__ExecutionContext, IsLogging());                   // TODO: implement in DLL


   // (2) globale Variablen initialisieren
   __NAME__       = WindowExpertName();
   __CHART        =    _bool(ec_hChart   (__ExecutionContext));
   __LOG          =          ec_Logging  (__ExecutionContext);
   __LOG_CUSTOM   = __LOG && ec_InitFlags(__ExecutionContext) & INIT_CUSTOMLOG;

   PipDigits      = Digits & (~1);                                        SubPipDigits      = PipDigits+1;
   PipPoints      = MathRound(MathPow(10, Digits & 1));                   PipPoint          = PipPoints;
   Pips           = NormalizeDouble(1/MathPow(10, PipDigits), PipDigits); Pip               = Pips;
   PipPriceFormat = StringConcatenate(".", PipDigits);                    SubPipPriceFormat = StringConcatenate(PipPriceFormat, "'");
   PriceFormat    = ifString(Digits==PipDigits, PipPriceFormat, SubPipPriceFormat);

   N_INF = MathLog(0);
   P_INF = -N_INF;
   NaN   =  N_INF - N_INF;

   return(!CheckErrors("UpdateGlobalVars(1)"));
}


/**
 * Check/update the program's error status and activate the flag __STATUS_OFF accordingly. Call ShowStatus() if the flag was
 * activated.
 *
 * @param  string location - location of the check
 * @param  int    setError - error to enforce
 *
 * @return bool - whether or not the flag __STATUS_OFF is set
 */
bool CheckErrors(string location, int setError = NULL) {
   // (1) check and signal DLL errors
   int dll_error = __ExecutionContext[I_EXECUTION_CONTEXT.dllError]; // TODO: signal DLL errors
   if (dll_error && 1) {
      __STATUS_OFF        = true;                                    // all DLL errors are terminating errors
      __STATUS_OFF.reason = dll_error;
   }


   // (2) check MQL errors
   int mql_error = __ExecutionContext[I_EXECUTION_CONTEXT.mqlError];
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
   if (!setError) setError = GetLastError();
   if (setError != NO_ERROR)
      catch(location, setError);                                     // catch() will update __STATUS_OFF accordingly


   // (5) update the variable last_error
   if (__STATUS_OFF) /*&&*/ if (!last_error)
      last_error = __STATUS_OFF.reason;


   // (6) call ShowStatus() if the status flag is enabled
   if (__STATUS_OFF) ShowStatus(last_error);
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

   int hWnd = GetTerminalMainWindow();
   if (!hWnd) return(last_error);

   SendMessageA(hWnd, WM_COMMAND, IDC_TESTER_SETTINGS_STARTSTOP, 0);
   return(NO_ERROR);
}


/**
 * Log important MarketInfo() data.
 *
 * @return bool - success status
 */
bool Test.LogMarketInfo() {
   string message = "";

   datetime time           = MarketInfo(Symbol(), MODE_TIME);                  message = message +" Time="        + DateTimeToStr(time, "w, D.M.Y H:I") +";";
   double   spread         = MarketInfo(Symbol(), MODE_SPREAD)     /PipPoints; message = message +" Spread="      + NumberToStr(spread, ".+")           +";";
                                                                               message = message +" Digits="      + Digits                              +";";
   double   minLot         = MarketInfo(Symbol(), MODE_MINLOT);                message = message +" MinLot="      + NumberToStr(minLot, ".+")           +";";
   double   lotStep        = MarketInfo(Symbol(), MODE_LOTSTEP);               message = message +" LotStep="     + NumberToStr(lotStep, ".+")          +";";
   double   stopLevel      = MarketInfo(Symbol(), MODE_STOPLEVEL)  /PipPoints; message = message +" StopLevel="   + NumberToStr(stopLevel, ".+")        +";";
   double   freezeLevel    = MarketInfo(Symbol(), MODE_FREEZELEVEL)/PipPoints; message = message +" FreezeLevel=" + NumberToStr(freezeLevel, ".+")      +";";
   double   tickSize       = MarketInfo(Symbol(), MODE_TICKSIZE);
   double   tickValue      = MarketInfo(Symbol(), MODE_TICKVALUE);
   double   marginRequired = MarketInfo(Symbol(), MODE_MARGINREQUIRED);
   double   lotValue       = MathDiv(Close[0], tickSize) * tickValue;          message = message +" Account="     + NumberToStr(AccountBalance(), ",,.0R") +" "+ AccountCurrency()                                                            +";";
   double   leverage       = MathDiv(lotValue, marginRequired);                message = message +" Leverage=1:"  + Round(leverage)                                                                                                           +";";
   int      stopoutLevel   = AccountStopoutLevel();                            message = message +" Stopout="     + ifString(AccountStopoutMode()==MSM_PERCENT, stopoutLevel +"%", NumberToStr(stopoutLevel, ",,.0") +" "+ AccountCurrency()) +";";
   double   lotSize        = MarketInfo(Symbol(), MODE_LOTSIZE);
   double   marginHedged   = MarketInfo(Symbol(), MODE_MARGINHEDGED);
            marginHedged   = MathDiv(marginHedged, lotSize) * 100;             message = message +" MarginHedged="+ ifString(!marginHedged, "none", Round(marginHedged) +"%")                                                                 +";";
   double   pointValue     = MathDiv(tickValue, MathDiv(tickSize, Point));
   double   pipValue       = PipPoints * pointValue;                           message = message +" PipValue="    + NumberToStr(pipValue, ".2+R")                                                                                             +";";
   double   commission     = CommissionValue();                                message = message +" Commission="  + ifString(!commission, "0;", NumberToStr(commission, ".2R") +"/lot");
   if (NE(commission, 0)) {
      double commissionPip = MathDiv(commission, pipValue);                    message = message +" ("            + NumberToStr(commissionPip, "."+ (Digits+1-PipDigits) +"R") +" pip)"                                                       +";";
   }
   double   swapLong       = MarketInfo(Symbol(), MODE_SWAPLONG );
   double   swapShort      = MarketInfo(Symbol(), MODE_SWAPSHORT);             message = message +" Swap="        + NumberToStr(swapLong, ".+") +"/"+ NumberToStr(swapShort, ".+")                                                            +";";

   __LOG = true;
   log("MarketInfo()"+ message);
   return(!catch("Test.LogMarketInfo(1)"));
}


// --------------------------------------------------------------------------------------------------------------------------


#import "rsfLib1.ex4"
   int    _lib1.init (int tickData[]);
   int    _lib1.start(int tick, datetime tickTime, int validBars, int changedBars);

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

   bool   IntInArray(int haystack[], int needle);
   int    ShowStatus(int error);

#import "rsfExpander.dll"
   int    ec_hChartWindow   (/*EXECUTION_CONTEXT*/int ec[]);
   int    ec_InitFlags      (/*EXECUTION_CONTEXT*/int ec[]);
   bool   ec_Logging        (/*EXECUTION_CONTEXT*/int ec[]);

   int    ec_SetDllError    (/*EXECUTION_CONTEXT*/int ec[], int error       );
   bool   ec_SetLogging     (/*EXECUTION_CONTEXT*/int ec[], int status      );
   int    ec_SetRootFunction(/*EXECUTION_CONTEXT*/int ec[], int rootFunction);

   string symbols_Name(/*SYMBOL*/int symbols[], int i);

   int    SyncMainContext_init  (int ec[], int programType, string programName, int uninitReason, int initFlags, int deinitFlags, string symbol, int period, int digits, int ea.extReporting, int ea.recordEquity, int isTesting, int isVisualMode, int isOptimization, int lpSec, int hChart, int droppedOnChart, int droppedOnPosX, int droppedOnPosY);
   int    SyncMainContext_start (int ec[], double rates[][], int bars, int ticks, datetime time, double bid, double ask);
   int    SyncMainContext_deinit(int ec[], int uninitReason);

   bool   Test_StartReporting (int ec[], datetime from, int bars, int barModel, int reportingId, string reportingSymbol);
   bool   Test_StopReporting  (int ec[], datetime to,   int bars);
   bool   Test_onPositionOpen (int ec[], int ticket, int type, double lots, string symbol, double openPrice, datetime openTime, double stopLoss, double takeProfit, double commission, int magicNumber, string comment);
   bool   Test_onPositionClose(int ec[], int ticket, double closePrice, datetime closeTime, double swap, double profit);

#import "rsfHistory.ex4"
   int    CreateSymbol(string name, string description, string group, int digits, string baseCurrency, string marginCurrency, string serverName);

   int    HistorySet.Get    (string symbol, string server);
   int    HistorySet.Create (string symbol, string description, int digits, int format, string server);
   bool   HistorySet.Close  (int hSet);
   bool   HistorySet.AddTick(int hSet, datetime time, double value, int flags);

#import "user32.dll"
   int  SendMessageA(int hWnd, int msg, int wParam, int lParam);
   bool SetWindowTextA(int hWnd, string lpString);
#import


// -- init() event handler templates ----------------------------------------------------------------------------------------


/**
 * Initialization pre-processing hook. Always called.
 *
 * @return int - error status; in case of errors reason-specific event handlers are not executed
 *
int onInit() {
   return(NO_ERROR);
}


/**
 * InitReason-specific event handler. Called after the expert was manually loaded by the user via the input dialog.
 * Also in Tester with both VisualMode=On|Off.
 *
 * @return int - error status
 *
int onInit_User() {
   return(NO_ERROR);
}


/**
 * InitReason-specific event handler. Called after the expert was loaded by a chart template. Also at terminal start.
 * No input dialog.
 *
 * @return int - error status
 *
int onInit_Template() {
   return(NO_ERROR);
}


/**
 * InitReason-specific event handler. Called after the input parameters were changed via the input dialog.
 *
 * @return int - error status
 *
int onInit_Parameters() {
   return(NO_ERROR);
}


/**
 * InitReason-specific event handler. Called after the current chart period has changed. No input dialog.
 *
 * @return int - error status
 *
int onInit_TimeframeChange() {
   return(NO_ERROR);
}


/**
 * InitReason-specific event handler. Called after the current chart symbol has changed. No input dialog.
 *
 * @return int - error status
 *
int onInit_SymbolChange() {
   return(NO_ERROR);
}


/**
 * InitReason-specific event handler. Called after the expert was recompiled. No input dialog.
 *
 * @return int - error status
 *
int onInit_Recompile() {
   return(NO_ERROR);
}


/**
 * Initialization post-processing hook. Executed only if neither the pre-processing hook nor the reason-specific event
 * handlers returned with -1 (which is a hard stop as opposite to a regular error).
 *
 * @return int - error status
 *
int afterInit() {
   return(NO_ERROR);
}


// -- deinit() event handler templates --------------------------------------------------------------------------------------


/**
 * Preprocessing-Hook
 *
 * @return int - Fehlerstatus
 *
int onDeinit() {
   return(NO_ERROR);
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
 * TODO: Umstände ungeklärt, wird in rsfLib1 mit ERR_RUNTIME_ERROR abgefangen
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
