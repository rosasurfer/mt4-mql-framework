
#define __TYPE__         MT_EXPERT
#define __lpSuperContext NULL
int     __WHEREAMI__   = NULL;                                             // current MQL RootFunction: RF_INIT | RF_START | RF_DEINIT

extern string   _______________________________ = "";
extern datetime Tester.StartAtTime              = 0;                       // date/time to start
extern double   Tester.StartAtPrice             = 0;                       // price to start
extern bool     Tester.EnableReporting          = false;
extern bool     Tester.RecordEquity             = false;

#include <functions/InitializeByteBuffer.mqh>


// input tracking
string input.all      = "";
string input.modified = "";


// test metadata
string tester.reporting.server      = "XTrade-Testresults";
int    tester.reporting.id          = 0;
string tester.reporting.symbol      = "";
string tester.reporting.description = "";
int    tester.equity.hSet           = 0;
double tester.equity.value          = 0;                                   // may be preset by the program; default: AccountEquity()-AccountCredit()


/**
 * Global init() function for experts.
 *
 * @return int - error status
 *
 * @throws ERS_TERMINAL_NOT_YET_READY
 */
int init() {
   if (__STATUS_OFF)
      return(ShowStatus(__STATUS_OFF.reason));                             // TODO: process ERR_INVALID_INPUT_PARAMETER

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

   if (__WHEREAMI__ == NULL) {                                             // then init() is called by the terminal
      __WHEREAMI__ = RF_INIT;                                              // TODO: ??? does this work in experts ???
      prev_error   = last_error;
      zTick        = 0;
      ec_SetDllError(__ExecutionContext, SetLastError(NO_ERROR));
   }


   // (1) initialize the execution context
   int hChart = NULL; if (!IsTesting() || IsVisualMode())                  // in Tester WindowHandle() triggers ERR_FUNC_NOT_ALLOWED_IN_TESTER
       hChart = WindowHandle(Symbol(), NULL);                              // if VisualMode=Off
   SyncMainContext_init(__ExecutionContext, __TYPE__, WindowExpertName(), UninitializeReason(), SumInts(__INIT_FLAGS__), SumInts(__DEINIT_FLAGS__), Symbol(), Period(), __lpSuperContext, IsTesting(), IsVisualMode(), IsOptimization(), hChart, WindowOnDropped(), WindowXOnDropped(), WindowYOnDropped());


   // (2) finish initialization
   if (!UpdateGlobalVars()) if (CheckErrors("init(1)")) return(last_error);


   // (3) initialize stdlib
   int iNull[];
   int error = stdlib.init(iNull);                                         //throws ERS_TERMINAL_NOT_YET_READY
   if (IsError(error)) if (CheckErrors("init(2)")) return(last_error);

                                                                           // #define INIT_TIMEZONE               in stdlib.init()
   // (4) execute custom init tasks                                        // #define INIT_PIPVALUE
   int initFlags = ec_InitFlags(__ExecutionContext);                       // #define INIT_BARS_ON_HIST_UPDATE
                                                                           // #define INIT_CUSTOMLOG
   if (_bool(initFlags & INIT_PIPVALUE)) {
      TickSize = MarketInfo(Symbol(), MODE_TICKSIZE);                      // fails if there is no tick yet
      error = GetLastError();
      if (IsError(error)) {                                                // symbol not yet subscribed (start, account/template change), it may "show up" later
         if (error == ERR_SYMBOL_NOT_AVAILABLE)                            // synthetic symbol in offline chart
            return(log("init(3)  MarketInfo() => ERR_SYMBOL_NOT_AVAILABLE", SetLastError(ERS_TERMINAL_NOT_YET_READY)));
         if (CheckErrors("init(4)", error)) return(last_error);
      }
      if (!TickSize) return(log("init(5)  MarketInfo(MODE_TICKSIZE) = 0", SetLastError(ERS_TERMINAL_NOT_YET_READY)));

      double tickValue = MarketInfo(Symbol(), MODE_TICKVALUE);
      error = GetLastError();
      if (IsError(error)) /*&&*/ if (CheckErrors("init(6)", error)) return(last_error);
      if (!tickValue) return(log("init(7)  MarketInfo(MODE_TICKVALUE) = 0", SetLastError(ERS_TERMINAL_NOT_YET_READY)));
   }

   if (_bool(initFlags & INIT_BARS_ON_HIST_UPDATE)) {}                     // not yet implemented


   // (5) enable experts if disabled
   int reasons1[] = { UR_UNDEFINED, UR_CHARTCLOSE, UR_REMOVE };
   if (!IsTesting()) /*&&*/ if (!IsExpertEnabled()) /*&&*/ if (IntInArray(reasons1, UninitializeReason())) {
      error = Toolbar.Experts(true);                                       // TODO: fails if multiple experts try to do it at the same time (e.g. at terminal start)
      if (IsError(error)) /*&&*/ if (CheckErrors("init(8)")) return(last_error);
   }


   // (6) we must explicitely reset the order context after the expert was reloaded (see MQL.doc)
   int reasons2[] = { UR_UNDEFINED, UR_CHARTCLOSE, UR_REMOVE, UR_ACCOUNT };
   if (IntInArray(reasons2, UninitializeReason())) {
      OrderSelect(0, SELECT_BY_TICKET);
      error = GetLastError();
      if (error && error!=ERR_NO_TICKET_SELECTED) return(_last_error(CheckErrors("init(9)", error)));
   }


   // (7) reset the window title in the Tester (might have been modified by the previous test)
   if (IsTesting()) {                                                      // TODO: wait until done
      if (!SetWindowTextA(GetTesterWindow(), "Tester")) return(_last_error(CheckErrors("init(10)->user32::SetWindowTextA()", ERR_WIN32_ERROR)));
   }


   // (8) log input parameters before onInit() to see real input before validation
   if (UninitializeReason() != UR_CHARTCHANGE) {
      input.all = ""; input.all= InputsToStr();
      if (input.all != "") {                                               // skip intentional suppression
         if (input.all != "InputsToStr()  function not implemented") {
            input.all = StringConcatenate(input.all,
                                          ifString(!Tester.StartAtTime, "",  "Tester.StartAtTime="+     TimeToStr(Tester.StartAtTime, TIME_FULL) +"; "),
                                          ifString(!Tester.StartAtPrice, "", "Tester.StartAtPrice="+    NumberToStr(Tester.StartAtPrice, PriceFormat) +"; "),
                                                                             "Tester.EnableReporting=", BoolToStr(Tester.EnableReporting), "; ",
                                                                             "Tester.RecordEquity=",    BoolToStr(Tester.RecordEquity)   , "; ");
         }
         __LOG = true;
         log("init(11)  "+ input.all);
      }
      datetime _tester.StartAtTime     = Tester.StartAtTime;
      double   _tester.StartAtPrice    = Tester.StartAtPrice;
      bool     _tester.EnableReporting = Tester.EnableReporting;
      bool     _tester.RecordEquity    = Tester.RecordEquity;
   }


   // (9) Execute init() event handlers. The reason-specific event handlers are not executed if the pre-processing hook             //
   //     returns with an error. The post-processing hook is executed only if neither the pre-processing hook nor the reason-       //
   //     specific handlers return with -1 (which is a hard stop as opposite to a regular error).                                   //
   //                                                                                                                               //
   //     +-- init reason -------+-- description --------------------------------+-- ui -----------+-- applies --+                  //
   //     | IR_USER              | loaded by the user                            |    input dialog |   I, E, S   |   I = indicators //
   //     | IR_TEMPLATE          | loaded by a template (also at terminal start) | no input dialog |   I, E      |   E = experts    //
   //     | IR_PROGRAM           | loaded by iCustom()                           | no input dialog |   I         |   S = scripts    //
   //     | IR_PROGRAM_AFTERTEST | loaded by iCustom() after end of test         | no input dialog |   I         |                  //
   //     | IR_PARAMETERS        | input parameters changed                      |    input dialog |   I, E      |                  //
   //     | IR_TIMEFRAMECHANGE   | chart period changed                          | no input dialog |   I, E      |                  //
   //     | IR_SYMBOLCHANGE      | chart symbol changed                          | no input dialog |   I, E      |                  //
   //     | IR_RECOMPILE         | reloaded after recompilation                  | no input dialog |   I, E      |                  //
   //     +----------------------+-----------------------------------------------+-----------------+-------------+                  //
   //                                                                                                                               //
   ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

   // catch terminal bug #1 (https://github.com/rosasurfer/mt4-mql/issues/1)
   if (!IsTesting() && UninitializeReason()!=UR_CHARTCHANGE) {
      string message = "UninitReason="+ UninitReasonToStr(UninitializeReason()) +"  InitReason="+ InitReasonToStr(InitReason()) +"  Window="+ WindowOnDropped() +"  X="+ WindowXOnDropped() +"  Y="+ WindowYOnDropped() +"  ThreadID="+ GetCurrentThreadId() +" ("+ ifString(IsUIThread(), "GUI thread", "non-GUI thread") +")";
      log("init(12)  "+ message);
      if (_______________________________=="" && WindowXOnDropped()==-1 && WindowYOnDropped()==-1) {
         PlaySoundEx("Siren.wav");
         string caption = __NAME__ +" "+ Symbol() +","+ PeriodDescription(Period());
         int    button  = MessageBoxA(GetApplicationWindow(), "init(13)  "+ message, caption, MB_TOPMOST|MB_SETFOREGROUND|MB_ICONERROR|MB_OKCANCEL);
         if (button != IDOK) return(_last_error(CheckErrors("init(14)", ERR_RUNTIME_ERROR)));
      }
   }


   error = onInit();                                                       // pre-processing hook
                                                                           //
   if (!error && !__STATUS_OFF) {                                          //
      int initReason = InitReason();                                       //
      if (!initReason) if (CheckErrors("init(15)")) return(last_error);    //
                                                                           //
      switch (initReason) {                                                //
         case IR_USER           : error = onInit_User();            break; // init reasons
         case IR_TEMPLATE       : error = onInit_Template();        break; //
         case IR_PARAMETERS     : error = onInit_Parameters();      break; //
         case IR_TIMEFRAMECHANGE: error = onInit_TimeframeChange(); break; //
         case IR_SYMBOLCHANGE   : error = onInit_SymbolChange();    break; //
         case IR_RECOMPILE      : error = onInit_Recompile();       break; //
         default:                                                          //
            return(_last_error(CheckErrors("init(16)  unsupported initReason = "+ initReason, ERR_RUNTIME_ERROR)));
      }                                                                    //
   }                                                                       //
   if (error == ERS_TERMINAL_NOT_YET_READY) return(error);                 //
                                                                           //
   if (error != -1)                                                        //
      afterInit();                                                         // post-processing hook
   if (CheckErrors("init(17)")) return(last_error);


   // (10) log modified input parameters after onInit()
   if (UninitializeReason() != UR_CHARTCHANGE) {
      input.modified = InputsToStr();
      if (input.modified!="" && input.modified!="modified input: ") {      // skip intentional suppression and no modifications
         if (input.modified != "InputsToStr()  function not implemented") {
            if (Tester.StartAtTime     != _tester.StartAtTime    ) input.modified = StringConcatenate(input.modified, "Tester.StartAtTime=",     ifString(Tester.StartAtTime, TimeToStr(Tester.StartAtTime, TIME_FULL), ""),       "; ");
            if (Tester.StartAtPrice    != _tester.StartAtPrice   ) input.modified = StringConcatenate(input.modified, "Tester.StartAtPrice=",    ifString(Tester.StartAtPrice, NumberToStr(Tester.StartAtPrice, PriceFormat), ""), "; ");
            if (Tester.EnableReporting != _tester.EnableReporting) input.modified = StringConcatenate(input.modified, "Tester.EnableReporting=", BoolToStr(Tester.EnableReporting),                                                "; ");
            if (Tester.RecordEquity    != _tester.RecordEquity   ) input.modified = StringConcatenate(input.modified, "Tester.RecordEquity=",    BoolToStr(Tester.RecordEquity),                                                   "; ");
            log("init(18)  "+ input.modified);
         }
      }
      _tester.StartAtTime     = Tester.StartAtTime;
      _tester.StartAtPrice    = Tester.StartAtPrice;
      _tester.EnableReporting = Tester.EnableReporting;
      _tester.RecordEquity    = Tester.RecordEquity;
   }


   // (11) log critical MarketInfo() data if in Tester
   if (IsTesting())
      Tester.LogMarketInfo();


   if (CheckErrors("init(19)"))
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
      if (IsDllsAllowed() && IsLibrariesAllowed()) {
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


   // (4) Im Tester StartAtTime/StartAtPrice abwarten
   if (IsTesting()) {
      if (Tester.StartAtTime != 0) {
         if (Tick.Time < Tester.StartAtTime)
            return(last_error);
         Tester.StartAtTime = 0;
      }
      if (Tester.StartAtPrice != 0) {
         static double test.lastPrice; if (!test.lastPrice) {
            test.lastPrice = Bid;
            return(last_error);
         }
         if (LT(test.lastPrice, Tester.StartAtPrice)) /*&&*/ if (LT(Bid, Tester.StartAtPrice)) {
            test.lastPrice = Bid;
            return(last_error);
         }
         if (GT(test.lastPrice, Tester.StartAtPrice)) /*&&*/ if (GT(Bid, Tester.StartAtPrice)) {
            test.lastPrice = Bid;
            return(last_error);
         }
         Tester.StartAtPrice = 0;
      }
   }


   SyncMainContext_start(__ExecutionContext, Tick.Time, Bid, Ask, Volume[0]);


   // (5) stdLib benachrichtigen
   if (stdlib.start(__ExecutionContext, Tick, Tick.Time, ValidBars, ChangedBars) != NO_ERROR) {
      if (CheckErrors("start(4)")) return(last_error);
   }


   // (6) ggf. Test initialisieren
   if (IsTesting()) {
      static bool test.initialized = false; if (!test.initialized) {
         if (!Tester.InitReporting()) return(_last_error(CheckErrors("start(5)")));
         test.initialized = true;
      }
   }


   // (7) Main-Funktion aufrufen
   onTick();


   // (8) ggf. Equity aufzeichnen
   if (IsTesting()) /*&&*/ if (!IsOptimization()) /*&&*/ if (Tester.RecordEquity) {
      if (!Tester.RecordEquityGraph()) return(_last_error(CheckErrors("start(6)")));
   }


   // (9) check errors
   error = GetLastError();
   if (error || last_error || __ExecutionContext[I_EXECUTION_CONTEXT.mqlError] || __ExecutionContext[I_EXECUTION_CONTEXT.dllError])
      return(_last_error(CheckErrors("start(7)", error)));

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

   if (!IsDllsAllowed() || !IsLibrariesAllowed())
      return(last_error);

   SyncMainContext_deinit(__ExecutionContext, UninitializeReason());


   if (IsTesting()) {
      if (tester.equity.hSet != 0) {
         int tmp=tester.equity.hSet; tester.equity.hSet=NULL;
         if (!HistorySet.Close(tmp)) return(_last_error(CheckErrors("deinit(1)"), LeaveContext(__ExecutionContext)));
      }
      if (!__STATUS_OFF) /*&&*/ if (Tester.EnableReporting) {
         datetime endTime = MarketInfo(Symbol(), MODE_TIME);
         CollectTestData(__ExecutionContext, NULL, endTime, NULL, NULL, Bars, NULL, NULL);
      }
   }


   // (1) User-spezifische deinit()-Routinen *können*, müssen aber nicht implementiert werden.
   //
   // Die User-Routinen werden ausgeführt, wenn der Preprocessing-Hook (falls implementiert) ohne Fehler zurückkehrt.
   // Der Postprocessing-Hook wird ausgeführt, wenn weder der Preprocessing-Hook (falls implementiert) noch die User-Routinen
   // (falls implementiert) -1 zurückgeben.
   int error = onDeinit();                                                 // Preprocessing-Hook
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
            LeaveContext(__ExecutionContext);                              //
            return(last_error);                                            //
      }                                                                    //
   }                                                                       //
   if (error != -1)                                                        //
      error = afterDeinit();                                               // Postprocessing-Hook


   // (2) User-spezifische Deinit-Tasks ausführen
   if (!error) {
      // ...
   }


   CheckErrors("deinit(3)");
   LeaveContext(__ExecutionContext);
   return(last_error);
}


/**
 * Called on test start if reporting is enabled. Initialize the test's metadata and create a new report symbol.
 *
 * @return bool - success status
 */
bool Tester.InitReporting() {
   if (!IsTesting())
      return(false);

   if (Tester.RecordEquity) /*&&*/ if (!IsOptimization()) {
      // create a new report symbol
      int    id             = 0;
      string symbol         = "";
      string symbolGroup    = StringLeft(__NAME__, MAX_SYMBOL_GROUP_LENGTH);
      string description    = "";
      int    digits         = 2;
      string baseCurrency   = AccountCurrency();
      string marginCurrency = AccountCurrency();


      // (1) open "symbols.raw" and read the existing symbols
      string mqlFileName = ".history\\"+ tester.reporting.server +"\\symbols.raw";
      int hFile = FileOpen(mqlFileName, FILE_READ|FILE_BIN);
      int error = GetLastError();
      if (IsError(error) || hFile <= 0)                              return(!catch("Tester.InitReporting(1)->FileOpen(\""+ mqlFileName +"\", FILE_READ) => "+ hFile, ifInt(error, error, ERR_RUNTIME_ERROR)));

      int fileSize = FileSize(hFile);
      if (fileSize % SYMBOL.size != 0) { FileClose(hFile);           return(!catch("Tester.InitReporting(2)  invalid size of \""+ mqlFileName +"\" (not an even SYMBOL size, "+ (fileSize % SYMBOL.size) +" trailing bytes)", ifInt(SetLastError(GetLastError()), last_error, ERR_RUNTIME_ERROR))); }
      int symbolsSize = fileSize/SYMBOL.size;

      /*SYMBOL[]*/int symbols[]; InitializeByteBuffer(symbols, fileSize);
      if (fileSize > 0) {
         // read symbols
         int ints = FileReadArray(hFile, symbols, 0, fileSize/4);
         error = GetLastError();
         if (IsError(error) || ints!=fileSize/4) { FileClose(hFile); return(!catch("Tester.InitReporting(3)  error reading \""+ mqlFileName +"\" ("+ ints*4 +" of "+ fileSize +" bytes read)", ifInt(error, error, ERR_RUNTIME_ERROR))); }
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
   }


   // (5) report the test's start data
   if (Tester.EnableReporting) {
      datetime startTime       = MarketInfo(Symbol(), MODE_TIME);
      double   accountBalance  = AccountBalance();
      string   accountCurrency = AccountCurrency();
      CollectTestData(__ExecutionContext, startTime, NULL, Bid, Ask, Bars, tester.reporting.id, tester.reporting.symbol);
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
bool Tester.RecordEquityGraph() {
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
      //debug("RecordEquityGraph(1)  recording equity to \""+ symbol +"\""+ ifString(!flags, "", " ("+ HistoryFlagsToStr(flags) +")"));
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

   return(!catch("UpdateGlobalVars(1)"));
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
   if (!setError) setError = GetLastError();
   if (setError != NO_ERROR)
      catch(location, setError);                                     // catch() will update __STATUS_OFF accordingly


   // (5) update the variable last_error
   if (__STATUS_OFF) /*&&*/ if (!last_error)
      last_error = __STATUS_OFF.reason;


   // (6) call ShowStatus() if the status flag is enabled
   if (__STATUS_OFF)
   ShowStatus(last_error);
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


/**
 * Log critical MarketInfo() data.
 *
 * @return bool - success status
 */
bool Tester.LogMarketInfo() {
   // TODO: log commission and swap

   string message = "";

   datetime time           = MarketInfo(Symbol(), MODE_TIME);                  message = message +"  Time="        + DateTimeToStr(time, "w, D.M.Y H:I");
   double   spread         = MarketInfo(Symbol(), MODE_SPREAD)     /PipPoints; message = message +"  Spread="      + NumberToStr(spread, ".+");
   double   minLot         = MarketInfo(Symbol(), MODE_MINLOT);                message = message +"  MinLot="      + NumberToStr(minLot, ".+");
   double   lotStep        = MarketInfo(Symbol(), MODE_LOTSTEP);               message = message +"  LotStep="     + NumberToStr(lotStep, ".+");
   double   stopLevel      = MarketInfo(Symbol(), MODE_STOPLEVEL)  /PipPoints; message = message +"  StopLevel="   + NumberToStr(stopLevel, ".+");
   double   freezeLevel    = MarketInfo(Symbol(), MODE_FREEZELEVEL)/PipPoints; message = message +"  FreezeLevel=" + NumberToStr(freezeLevel, ".+");
   double   tickSize       = MarketInfo(Symbol(), MODE_TICKSIZE);
   double   tickValue      = MarketInfo(Symbol(), MODE_TICKVALUE);
   double   marginRequired = MarketInfo(Symbol(), MODE_MARGINREQUIRED);
   double   pointValue     = MathDiv(tickValue, MathDiv(tickSize, Point));
   double   pipValue       = PipPoints * pointValue;                           message = message +"  PipValue="    + NumberToStr(pipValue, ".2+R") +" "+ AccountCurrency();
   double   lotValue       = MathDiv(Close[0], tickSize) * tickValue;          message = message +"  Account="     + NumberToStr(AccountBalance(), ",,.0R") +" "+ AccountCurrency();
   double   leverage       = MathDiv(lotValue, marginRequired);                message = message +"  Leverage=1:"  + Round(leverage);
   int      stopoutLevel   = AccountStopoutLevel();                            message = message +"  Stopout="     + ifString(AccountStopoutMode()==MSM_PERCENT, stopoutLevel +"%", NumberToStr(stopoutLevel, ",,.0") +" "+ AccountCurrency());
   double   lotSize        = MarketInfo(Symbol(), MODE_LOTSIZE);
   double   marginHedged   = MarketInfo(Symbol(), MODE_MARGINHEDGED);
            marginHedged   = MathDiv(marginHedged, lotSize) * 100;             message = message +"  MarginHedged=" + ifString(!marginHedged, "none", Round(marginHedged) +"%");

   __LOG = true;
   log("MarketInfo()"+ message);
   return(!catch("Tester.LogMarketInfo(1)"));
}


// --------------------------------------------------------------------------------------------------------------------------


#import "rsfLib1.ex4"
   int    stdlib.init  (int tickData[]);
   int    stdlib.start (/*EXECUTION_CONTEXT*/int ec[], int tick, datetime tickTime, int validBars, int changedBars);

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

   int    Explode   (string value, string separator, string results[], int limit);
   bool   IntInArray(int haystack[], int needle);

#import "rsfExpander.dll"
   int    ec_DllError       (/*EXECUTION_CONTEXT*/int ec[]);
   int    ec_hChartWindow   (/*EXECUTION_CONTEXT*/int ec[]);
   int    ec_InitFlags      (/*EXECUTION_CONTEXT*/int ec[]);
   bool   ec_Logging        (/*EXECUTION_CONTEXT*/int ec[]);
   int    ec_MqlError       (/*EXECUTION_CONTEXT*/int ec[]);

   int    ec_SetDllError    (/*EXECUTION_CONTEXT*/int ec[], int error       );
   bool   ec_SetLogging     (/*EXECUTION_CONTEXT*/int ec[], int status      );
   int    ec_SetRootFunction(/*EXECUTION_CONTEXT*/int ec[], int rootFunction);

   string symbols_Name(/*SYMBOL*/int symbols[], int i);

   bool   SyncMainContext_init  (int ec[], int programType, string programName, int uninitReason, int initFlags, int deinitFlags, string symbol, int period, int lpSec, int isTesting, int isVisualMode, int isOptimization, int hChart, int droppedOnChart, int droppedOnPosX, int droppedOnPosY);
   bool   SyncMainContext_start (int ec[], datetime time, double bid, double ask, int volume);
   bool   SyncMainContext_deinit(int ec[], int uninitReason);

   bool   CollectTestData(int ec[], datetime from, datetime to, double bid, double ask, int bars, int reportingId, string reportingSymbol);
   bool   Test_OpenOrder (int ec[], int ticket, int type, double lots, string symbol, double openPrice, datetime openTime, double stopLoss, double takeProfit, double commission, int magicNumber, string comment);
   bool   Test_CloseOrder(int ec[], int ticket, double closePrice, datetime closeTime, double swap, double profit);

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
