
#define __lpSuperContext NULL
int     __CoreFunction = NULL;                                       // currently executed MQL core function: CF_INIT | CF_START | CF_DEINIT

extern string   ______________________________;
extern bool     EA.RecordEquity   = false;
extern bool     EA.CreateReport   = false;
extern datetime Tester.StartTime  = 0;                               // time to start a test
extern double   Tester.StartPrice = 0;                               // price to start a test

#include <functions/InitializeByteBuffer.mqh>


double __rates[][6];                                                 // current price series (passed to the Expander on every tick)
int    tickTimerId;                                                  // timer id for virtual ticks

// test metadata
double tester.startEquity       = 0;
string tester.reportServer      = "XTrade-Testresults";
int    tester.reportId          = 0;
string tester.reportSymbol      = "";
string tester.reportDescription = "";
double tester.equityValue       = 0;                                 // default: AccountEquity()-AccountCredit(), may be overridden
int    tester.hEquitySet        = 0;                                 // handle of the equity's history set


/**
 * Global init() function for experts.
 *
 * @return int - error status
 */
int init() {
   if (__STATUS_OFF) {                                               // TODO: process ERR_INVALID_INPUT_PARAMETER (enable re-input)
      if (__STATUS_OFF.reason != ERR_TERMINAL_INIT_FAILURE)
         ShowStatus(__STATUS_OFF.reason);
      return(__STATUS_OFF.reason);
   }

   if (!IsDllsAllowed()) {
      ForceAlert("Please enable DLL function calls for this expert.");
      last_error          = ERR_DLL_CALLS_NOT_ALLOWED;
      __STATUS_OFF        = true;
      __STATUS_OFF.reason = last_error;
      return(last_error);
   }
   if (!IsLibrariesAllowed()) {
      ForceAlert("Please enable MQL library calls for this expert.");
      last_error          = ERR_EX4_CALLS_NOT_ALLOWED;
      __STATUS_OFF        = true;
      __STATUS_OFF.reason = last_error;
      return(last_error);
   }

   if (__CoreFunction == NULL) {                                     // init() is called by the terminal
      __CoreFunction = CF_INIT;                                      // TODO: ??? does this work in experts ???
      prev_error   = last_error;
      ec_SetDllError(__ExecutionContext, SetLastError(NO_ERROR));
   }

   // initialize the execution context
   int hChart = NULL; if (!IsTesting() || IsVisualMode())            // in tester WindowHandle() triggers ERR_FUNC_NOT_ALLOWED_IN_TESTER if VisualMode=Off
       hChart = WindowHandle(Symbol(), NULL);

   int error = SyncMainContext_init(__ExecutionContext, MT_EXPERT, WindowExpertName(), UninitializeReason(), SumInts(__InitFlags), SumInts(__DeinitFlags), Symbol(), Period(), Digits, Point, EA.CreateReport, EA.RecordEquity, IsTesting(), IsVisualMode(), IsOptimization(), __lpSuperContext, hChart, WindowOnDropped(), WindowXOnDropped(), WindowYOnDropped());
   if (!error) error = GetLastError();                               // detect a DLL exception
   if (IsError(error)) {
      ForceAlert("ERROR:   "+ Symbol() +","+ PeriodDescription() +"  "+ WindowExpertName() +"::init(2)->SyncMainContext_init()  ["+ ErrorToStr(error) +"]");
      last_error          = error;
      __STATUS_OFF        = true;                                    // If SyncMainContext_init() failed the content of the EXECUTION_CONTEXT
      __STATUS_OFF.reason = last_error;                              // is undefined. We must not trigger loading of MQL libraries and return asap.
      __CoreFunction      = NULL;
      return(last_error);
   }

   // finish initialization of global vars
   if (!InitGlobals()) if (CheckErrors("init(3)")) return(last_error);

   // execute custom init tasks
   int initFlags = __ExecutionContext[EC.programInitFlags];
   if (initFlags & INIT_TIMEZONE && 1) {
      if (!StringLen(GetServerTimezone()))  return(_last_error(CheckErrors("init(4)")));
   }
   if (initFlags & INIT_PIPVALUE && 1) {
      TickSize = MarketInfo(Symbol(), MODE_TICKSIZE);                // fails if there is no tick yet
      error = GetLastError();
      if (IsError(error)) {                                          // symbol not yet subscribed (start, account/template change), it may appear later
         if (error == ERR_SYMBOL_NOT_AVAILABLE)                      // synthetic symbol in offline chart
            return(logInfo("init(5)  MarketInfo("+ Symbol() +", ...) => ERR_SYMBOL_NOT_AVAILABLE", SetLastError(ERS_TERMINAL_NOT_YET_READY)));
         if (CheckErrors("init(6)", error)) return(last_error);
      }
      if (!TickSize) return(logInfo("init(7)  MarketInfo("+ Symbol() +", MODE_TICKSIZE) = 0", SetLastError(ERS_TERMINAL_NOT_YET_READY)));

      double tickValue = MarketInfo(Symbol(), MODE_TICKVALUE);
      error = GetLastError();
      if (IsError(error)) /*&&*/ if (CheckErrors("init(8)", error)) return(last_error);
      if (!tickValue) return(logInfo("init(9)  MarketInfo(MODE_TICKVALUE) = 0", SetLastError(ERS_TERMINAL_NOT_YET_READY)));
   }
   if (initFlags & INIT_BARS_ON_HIST_UPDATE && 1) {}                 // not yet implemented

   // enable experts if they are disabled
   int reasons1[] = {UR_UNDEFINED, UR_CHARTCLOSE, UR_REMOVE};
   if (!IsTesting()) /*&&*/ if (!IsExpertEnabled()) /*&&*/ if (IntInArray(reasons1, UninitializeReason())) {
      error = Toolbar.Experts(true);                                 // TODO: fails if multiple experts try it at the same time (e.g. at terminal start)
      if (IsError(error)) /*&&*/ if (CheckErrors("init(10)")) return(last_error);
   }

   // reset the order context after the expert was reloaded (to prevent the bug when the previously active context is not reset)
   int reasons2[] = {UR_UNDEFINED, UR_CHARTCLOSE, UR_REMOVE, UR_ACCOUNT};
   if (IntInArray(reasons2, UninitializeReason())) {
      OrderSelect(0, SELECT_BY_TICKET);
      error = GetLastError();
      if (error && error!=ERR_NO_TICKET_SELECTED) return(_last_error(CheckErrors("init(11)", error)));
   }

   // resolve init reason and account number
   int initReason = ProgramInitReason();
   int account = GetAccountNumber(); if (!account) return(_last_error(CheckErrors("init(12)")));

   if (IsTesting()) {                     // log MarketInfo() data
      if (IsLogInfo()) logInfo("init(13)  MarketInfo: "+ Tester.GetMarketInfo());
      tester.startEquity = NormalizeDouble(AccountEquity()-AccountCredit(), 2);
   }
   else if (initReason == IR_USER) {      // log account infos (becomes the first regular online log entry)
      if (IsLogInfo()) logInfo("init(14)  "+ GetAccountServer() +", account "+ account +" ("+ ifString(IsDemoFix(), "demo", "real") +")");
   }

   // log input parameters
   if (UninitializeReason()!=UR_CHARTCHANGE) /*&&*/ if (IsLogDebug()) {
      string sInputs = InputsToStr();
      if (StringLen(sInputs) > 0) {
         sInputs = StringConcatenate(sInputs,
            ifString(!EA.RecordEquity,   "", NL +"EA.RecordEquity=TRUE"                                            +";"),
            ifString(!EA.CreateReport,   "", NL +"EA.CreateReport=TRUE"                                            +";"),
            ifString(!Tester.StartTime,  "", NL +"Tester.StartTime="+ TimeToStr(Tester.StartTime, TIME_FULL)       +";"),
            ifString(!Tester.StartPrice, "", NL +"Tester.StartPrice="+ NumberToStr(Tester.StartPrice, PriceFormat) +";"));
         logDebug("init(15)  inputs: "+ sInputs);
      }
   }

   // Execute init() event handlers. The reason-specific handlers are executed only if onInit() returns without errors.
   //
   // +-- init reason -------+-- description --------------------------------+-- ui -----------+-- applies --+
   // | IR_USER              | loaded by the user (also in tester)           |    input dialog |   I, E, S   | I = indicators
   // | IR_TEMPLATE          | loaded by a template (also at terminal start) | no input dialog |   I, E      | E = experts
   // | IR_PROGRAM           | loaded by iCustom()                           | no input dialog |   I         | S = scripts
   // | IR_PROGRAM_AFTERTEST | loaded by iCustom() after end of test         | no input dialog |   I         |
   // | IR_PARAMETERS        | input parameters changed                      |    input dialog |   I, E      |
   // | IR_TIMEFRAMECHANGE   | chart period changed                          | no input dialog |   I, E      |
   // | IR_SYMBOLCHANGE      | chart symbol changed                          | no input dialog |   I, E      |
   // | IR_RECOMPILE         | reloaded after recompilation                  | no input dialog |   I, E      |
   // | IR_TERMINAL_FAILURE  | terminal failure                              |    input dialog |      E      | @see https://github.com/rosasurfer/mt4-mql/issues/1
   // +----------------------+-----------------------------------------------+-----------------+-------------+
   //
   error = onInit();                                                          // preprocessing hook
                                                                              //
   if (!error && !__STATUS_OFF) {                                             //
      switch (initReason) {                                                   //
         case IR_USER            : error = onInitUser();            break;    // init reasons
         case IR_TEMPLATE        : error = onInitTemplate();        break;    //
         case IR_PARAMETERS      : error = onInitParameters();      break;    //
         case IR_TIMEFRAMECHANGE : error = onInitTimeframeChange(); break;    //
         case IR_SYMBOLCHANGE    : error = onInitSymbolChange();    break;    //
         case IR_RECOMPILE       : error = onInitRecompile();       break;    //
         case IR_TERMINAL_FAILURE:                                            //
         default:                                                             //
            return(_last_error(CheckErrors("init(17)  unsupported initReason: "+ initReason, ERR_RUNTIME_ERROR)));
      }                                                                       //
   }                                                                          //
   if (error == ERS_TERMINAL_NOT_YET_READY) return(error);                    //
                                                                              //
   if (!error && !__STATUS_OFF)                                               //
      afterInit();                                                            // postprocessing hook
   if (CheckErrors("init(18)")) return(last_error);

   ShowStatus(last_error);

   // setup virtual ticks to continue operation on a stalled data feed
   if (!IsTesting()) {
      int hWnd    = __ExecutionContext[EC.hChart];
      int millis  = 10 * 1000;                                                // every 10 seconds
      tickTimerId = SetupTickTimer(hWnd, millis, NULL);
      if (!tickTimerId) return(catch("init(19)->SetupTickTimer(hWnd="+ IntToHexStr(hWnd) +") failed", ERR_RUNTIME_ERROR));
   }

   // immediately send a virtual tick, except on UR_CHARTCHANGE
   if (UninitializeReason() != UR_CHARTCHANGE)                                // At the very end, otherwise the window message
      Chart.SendTick();                                                       // queue may be processed before this function
   return(last_error);                                                        // is left and the tick might get lost.
}


/**
 * Update global variables. Called immediately after SyncMainContext_init().
 *
 * @return bool - success status
 */
bool InitGlobals() {
   __isChart      = (__ExecutionContext[EC.hChart] != 0);
   PipDigits      = Digits & (~1);                                        SubPipDigits      = PipDigits+1;
   PipPoints      = MathRound(MathPow(10, Digits & 1));                   PipPoint          = PipPoints;
   Pips           = NormalizeDouble(1/MathPow(10, PipDigits), PipDigits); Pip               = Pips;
   PipPriceFormat = StringConcatenate(",'R.", PipDigits);                 SubPipPriceFormat = StringConcatenate(PipPriceFormat, "'");
   PriceFormat    = ifString(Digits==PipDigits, PipPriceFormat, SubPipPriceFormat);

   N_INF = MathLog(0);                                                        // negative infinity
   P_INF = -N_INF;                                                            // positive infinity
   NaN   =  N_INF - N_INF;                                                    // not-a-number

   return(!catch("InitGlobals(1)"));
}


/**
 * Global main function. If called after an init() cycle and init() returned with ERS_TERMINAL_NOT_YET_READY, init() is
 * called again until the terminal is "ready".
 *
 * @return int - error status
 */
int start() {
   if (__STATUS_OFF) {
      if (IsDllsAllowed() && IsLibrariesAllowed() && __STATUS_OFF.reason!=ERR_TERMINAL_INIT_FAILURE) {
         if (__isChart) ShowStatus(__STATUS_OFF.reason);
         static bool tester.stopped = false;
         if (IsTesting() && !tester.stopped) {                                      // ctop the tester in case of errors
            Tester.Stop("start(1)");                                                // covers errors in init(), too
            tester.stopped = true;
         }
      }
      return(last_error);
   }

   // resolve tick status
   Tick++;                                                                          // simple counter, the value is meaningless
   Tick.Time = MarketInfo(Symbol(), MODE_TIME);
   static int lastVolume;
   if      (!Volume[0] || !lastVolume) Tick.isVirtual = true;
   else if ( Volume[0] ==  lastVolume) Tick.isVirtual = true;
   else                                Tick.isVirtual = false;
   lastVolume = Volume[0];
   ValidBars   = -1;                                                                // in experts not available
   ChangedBars = -1;                                                                // ...
   ShiftedBars = -1;                                                                // ...

   // if called after init() check it's return value
   if (__CoreFunction == CF_INIT) {
      __CoreFunction = ec_SetProgramCoreFunction(__ExecutionContext, CF_START);     // __STATUS_OFF is FALSE here, but an error may be set

      if (last_error == ERS_TERMINAL_NOT_YET_READY) {
         logInfo("start(2)  init() returned ERS_TERMINAL_NOT_YET_READY, retrying...");
         last_error = NO_ERROR;

         int error = init();                                                        // call init() again
         if (__STATUS_OFF) return(last_error);

         if (error == ERS_TERMINAL_NOT_YET_READY) {                                 // again an error may be set
            __CoreFunction = ec_SetProgramCoreFunction(__ExecutionContext, CF_INIT);// reset __CoreFunction and wait for the next tick
            return(ShowStatus(error));
         }
      }
      last_error = NO_ERROR;                                                        // init() was successful => reset error
   }
   else {
      prev_error = last_error;                                                      // a regular tick: backup last_error and reset it
      ec_SetDllError(__ExecutionContext, SetLastError(NO_ERROR));
   }

   // check a finished chart initialization (may fail on terminal start)
   if (!Bars) return(ShowStatus(SetLastError(logInfo("start(3)  Bars=0", ERS_TERMINAL_NOT_YET_READY))));

   // tester: wait until the configured start time/price is reached
   if (IsTesting()) {
      if (Tester.StartTime != 0) {
         static string startTime; if (!StringLen(startTime)) startTime = TimeToStr(Tester.StartTime, TIME_FULL);
         if (Tick.Time < Tester.StartTime) {
            Comment(NL, NL, NL, "Tester: starting at ", startTime);
            return(last_error);
         }
         Tester.StartTime = 0;
      }
      if (Tester.StartPrice != 0) {
         static string startPrice; if (!StringLen(startPrice)) startPrice = NumberToStr(Tester.StartPrice, PriceFormat);
         static double tester.lastPrice; if (!tester.lastPrice) {
            tester.lastPrice = Bid;
            Comment(NL, NL, NL, "Tester: starting at ", startPrice);
            return(last_error);
         }
         if (LT(tester.lastPrice, Tester.StartPrice)) /*&&*/ if (LT(Bid, Tester.StartPrice)) {
            tester.lastPrice = Bid;
            Comment(NL, NL, NL, "Tester: starting at ", startPrice);
            return(last_error);
         }
         if (GT(tester.lastPrice, Tester.StartPrice)) /*&&*/ if (GT(Bid, Tester.StartPrice)) {
            tester.lastPrice = Bid;
            Comment(NL, NL, NL, "Tester: starting at ", startPrice);
            return(last_error);
         }
         Tester.StartPrice = 0;
      }
   }

   // online: check tick value if INIT_PIPVALUE is configured
   else {
      if (__ExecutionContext[EC.programInitFlags] & INIT_PIPVALUE && 1) {     // on "Market Watch" -> "Context menu" -> "Hide all" all symbols are unsubscribed
         if (!MarketInfo(Symbol(), MODE_TICKVALUE)) {                         // and the used ones re-subscribed (for a moment: tickvalue = 0 and no error)
            error = GetLastError();
            if (error != NO_ERROR) {
               if (CheckErrors("start(4)", error)) return(last_error);
            }
            return(ShowStatus(SetLastError(logInfo("start(5)  MarketInfo("+ Symbol() +", MODE_TICKVALUE) = 0", ERS_TERMINAL_NOT_YET_READY))));
         }
      }
   }

   ArrayCopyRates(__rates);

   if (SyncMainContext_start(__ExecutionContext, __rates, Bars, -1, Tick, Tick.Time, Bid, Ask) != NO_ERROR) {
      if (CheckErrors("start(6)")) return(last_error);
   }

   // initialize test reporting if configured
   if (IsTesting()) {
      static bool test.initialized = false; if (!test.initialized) {
         if (!Tester.InitReporting()) return(_last_error(CheckErrors("start(7)")));
         test.initialized = true;
      }
   }

   // call the userland main function
   onTick();

   // record equity if configured
   if (IsTesting()) /*&&*/ if (!IsOptimization()) /*&&*/ if (EA.RecordEquity) {
      if (!Tester.RecordEquity()) return(_last_error(CheckErrors("start(8)")));
   }

   // check all errors
   error = GetLastError();
   if (error || last_error|__ExecutionContext[EC.mqlError]|__ExecutionContext[EC.dllError])
      return(_last_error(CheckErrors("start(9)", error)));

   return(ShowStatus(NO_ERROR));
}


/**
 * Expert deinitialization
 *
 * @return int - error status
 *
 *
 * Terminal bug
 * ------------
 * At a regular end of test (testing period ended) with VisualMode=Off the terminal may interrupt more complex deinit()
 * functions "at will", without finishing them. This must not be confused with the regular execution time check of max. 3 sec.
 * in init cycles. The interruption may occur already after a few 100 millisec. and Expert::afterDeinit() may not get executed
 * at all. The only workaround is to no put consuming tasks into deinit(), or to move such tasks to the MT4Expander (possibly
 * to its own thread). Writing status changes to disk as they happen avoids this issue in the first place.
 */
int deinit() {
   __CoreFunction = CF_DEINIT;

   if (!IsDllsAllowed() || !IsLibrariesAllowed() || last_error==ERR_TERMINAL_INIT_FAILURE || last_error==ERR_DLL_EXCEPTION)
      return(last_error);

   int error = SyncMainContext_deinit(__ExecutionContext, UninitializeReason());
   if (IsError(error)) return(error|last_error|LeaveContext(__ExecutionContext));

   error = catch("deinit(1)");                                             // detect errors causing a full execution stop, e.g. ERR_ZERO_DIVIDE

   if (IsTesting()) {
      if (tester.hEquitySet != 0) {
         int tmp=tester.hEquitySet; tester.hEquitySet=NULL;
         if (!HistorySet1.Close(tmp)) return(_last_error(CheckErrors("deinit(2)"))|LeaveContext(__ExecutionContext));
      }
      if (EA.CreateReport) {
         datetime time = MarketInfo(Symbol(), MODE_TIME);
         Test_StopReporting(__ExecutionContext, time, Bars);
      }
   }

   // reset the virtual tick timer
   if (tickTimerId != NULL) {
      int id = tickTimerId;
      tickTimerId = NULL;
      if (!RemoveTickTimer(id)) return(catch("deinit(3)->RemoveTickTimer(timerId="+ id +") failed", ERR_RUNTIME_ERROR));
   }

   // Execute user-specific deinit() handlers. Execution stops if a handler returns with an error.
   //
   if (!error) error = onDeinit();                                         // preprocessing hook
   if (!error) {                                                           //
      switch (UninitializeReason()) {                                      //
         case UR_PARAMETERS : error = onDeinitParameters();    break;      // reason-specific handlers
         case UR_CHARTCHANGE: error = onDeinitChartChange();   break;      //
         case UR_ACCOUNT    : error = onDeinitAccountChange(); break;      //
         case UR_CHARTCLOSE : error = onDeinitChartClose();    break;      //
         case UR_UNDEFINED  : error = onDeinitUndefined();     break;      //
         case UR_REMOVE     : error = onDeinitRemove();        break;      //
         case UR_RECOMPILE  : error = onDeinitRecompile();     break;      //
         // terminal builds > 509                                          //
         case UR_TEMPLATE   : error = onDeinitTemplate();      break;      //
         case UR_INITFAILED : error = onDeinitFailed();        break;      //
         case UR_CLOSE      : error = onDeinitClose();         break;      //
                                                                           //
         default:                                                          //
            CheckErrors("deinit(4)  unknown UninitializeReason = "+ UninitializeReason(), ERR_RUNTIME_ERROR);
            return(last_error|LeaveContext(__ExecutionContext));           //
      }                                                                    //
   }                                                                       //
   if (!error) error = afterDeinit();                                      // postprocessing hook
   if (!IsTesting()) DeleteRegisteredObjects();

   CheckErrors("deinit(5)");
   return(last_error|LeaveContext(__ExecutionContext));
}


/**
 * Return the current deinitialize reason code. Must be called only from deinit().
 *
 * @return int - id or NULL in case of errors
 */
int DeinitReason() {
   return(!catch("DeinitReason(1)", ERR_NOT_IMPLEMENTED));
}


/**
 * Whether the current program is an expert.
 *
 * @return bool
 */
bool IsExpert() {
   return(true);
}


/**
 * Whether the current program is a script.
 *
 * @return bool
 */
bool IsScript() {
   return(false);
}


/**
 * Whether the current program is an indicator.
 *
 * @return bool
 */
bool IsIndicator() {
   return(false);
}


/**
 * Whether the current module is a library.
 *
 * @return bool
 */
bool IsLibrary() {
   return(false);
}


/**
 * Check and update the program's error status and activate the flag __STATUS_OFF accordingly.
 *
 * @param  string location         - location of the check
 * @param  int    error [optional] - error to enforce (default: none)
 *
 * @return bool - whether the flag __STATUS_OFF is set
 */
bool CheckErrors(string location, int error = NULL) {
   // check and signal DLL errors
   int dll_error = __ExecutionContext[EC.dllError];                  // TODO: signal DLL errors
   if (dll_error != NO_ERROR) {
      __STATUS_OFF        = true;                                    // all DLL errors are terminating errors
      __STATUS_OFF.reason = dll_error;
   }

   // check MQL errors
   int mql_error = __ExecutionContext[EC.mqlError];
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

   // check last_error
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

   // check uncatched errors
   if (!error) error = GetLastError();
   if (error != NO_ERROR)
      catch(location, error);                                        // catch() calls SetLastError() which calls CheckErrors()
                                                                     // which updates __STATUS_OFF accordingly
   // update the variable last_error
   if (__STATUS_OFF) {
      if (!last_error) last_error = __STATUS_OFF.reason;
      ShowStatus(last_error);                                        // show status once again if an error occurred
   }
   return(__STATUS_OFF);

   // suppress compiler warnings
   __DummyCalls();
}


/**
 * Called once at start of a test. If reporting is enabled the test's metadata is initialized.
 *
 * @return bool - success status
 */
bool Tester.InitReporting() {
   if (!IsTesting())
      return(false);

   // prepare the EA to record the equity curve
   if (EA.RecordEquity) /*&&*/ if (!IsOptimization()) {
      // create a new report symbol
      int    id             = 0;
      string symbol         = "";
      string symbolGroup    = StrLeft(ProgramName(), MAX_SYMBOL_GROUP_LENGTH);
      string description    = "";
      int    digits         = 2;
      string baseCurrency   = AccountCurrency();
      string marginCurrency = AccountCurrency();

      // open "symbols.raw" and read the existing symbols
      string mqlFileName = "history\\"+ tester.reportServer +"\\symbols.raw";
      int hFile = FileOpen(mqlFileName, FILE_READ|FILE_BIN);
      int error = GetLastError();
      if (IsError(error) || hFile <= 0)                              return(!catch("Tester.InitReporting(1)->FileOpen(\""+ mqlFileName +"\", FILE_READ) => "+ hFile, ifIntOr(error, ERR_RUNTIME_ERROR)));

      int fileSize = FileSize(hFile);
      if (fileSize % SYMBOL.size != 0) { FileClose(hFile);           return(!catch("Tester.InitReporting(2)  invalid size of \""+ mqlFileName +"\" (not an even SYMBOL size, "+ (fileSize % SYMBOL.size) +" trailing bytes)", ifIntOr(GetLastError(), ERR_RUNTIME_ERROR))); }
      int symbolsSize = fileSize/SYMBOL.size;

      int symbols[]; InitializeByteBuffer(symbols, fileSize);
      if (fileSize > 0) {
         // read symbols
         int ints = FileReadArray(hFile, symbols, 0, fileSize/4);
         error = GetLastError();
         if (IsError(error) || ints!=fileSize/4) { FileClose(hFile); return(!catch("Tester.InitReporting(3)  error reading \""+ mqlFileName +"\" ("+ (ints*4) +" of "+ fileSize +" bytes read)", ifIntOr(error, ERR_RUNTIME_ERROR))); }
      }
      FileClose(hFile);

      // iterate over existing symbols and determine the next available one matching "{ExpertName}.{001-xxx}"
      string suffix, name = StrLeft(StrReplace(ProgramName(), " ", ""), 7) +".";

      for (int i, maxId=0; i < symbolsSize; i++) {
         symbol = symbols_Name(symbols, i);
         if (StrStartsWithI(symbol, name)) {
            suffix = StrSubstr(symbol, StringLen(name));
            if (StringLen(suffix)==3) /*&&*/ if (StrIsDigit(suffix)) {
               maxId = Max(maxId, StrToInteger(suffix));
            }
         }
      }
      id     = maxId + 1;
      symbol = name + StrPadLeft(id, 3, "0");

      // create a symbol description                                                      // sizeof(SYMBOL.description) = 64
      description = StrLeft(ProgramName(), 38) +" #"+ id;                                 // 38 + 2 +  3 = 43 chars
      description = description +" "+ LocalTimeFormat(GetGmtTime(), "%d.%m.%Y %H:%M:%S"); // 43 + 1 + 19 = 63 chars

      // create symbol
      if (CreateRawSymbol(symbol, description, symbolGroup, digits, baseCurrency, marginCurrency, tester.reportServer) < 0)
         return(false);

      tester.reportId          = id;
      tester.reportSymbol      = symbol;
      tester.reportDescription = description;
   }

   // prepare the Expander to collect data for external reporting
   if (EA.CreateReport) {
      datetime time = MarketInfo(Symbol(), MODE_TIME);
      Test_StartReporting(__ExecutionContext, time, Bars, tester.reportId, tester.reportSymbol);
   }
   return(true);
}


/**
 * Return current MarketInfo() data.
 *
 * @return string - MarketInfo() data or an empty string in case of errors
 */
string Tester.GetMarketInfo() {
   string message = "";

   datetime time           = MarketInfo(Symbol(), MODE_TIME);                  message = message + "Time="        + GmtTimeFormat(time, "%a, %d.%m.%Y %H:%M") +";";
                                                                               message = message +" Bars="        + Bars                                      +";";
   double   spread         = MarketInfo(Symbol(), MODE_SPREAD)/PipPoints;      message = message +" Spread="      + DoubleToStr(spread, 1)                    +";";
                                                                               message = message +" Digits="      + Digits                                    +";";
   double   minLot         = MarketInfo(Symbol(), MODE_MINLOT);                message = message +" MinLot="      + NumberToStr(minLot, ".+")                 +";";
   double   lotStep        = MarketInfo(Symbol(), MODE_LOTSTEP);               message = message +" LotStep="     + NumberToStr(lotStep, ".+")                +";";
   double   stopLevel      = MarketInfo(Symbol(), MODE_STOPLEVEL)/PipPoints;   message = message +" StopLevel="   + NumberToStr(stopLevel, ".+")              +";";
   double   freezeLevel    = MarketInfo(Symbol(), MODE_FREEZELEVEL)/PipPoints; message = message +" FreezeLevel=" + NumberToStr(freezeLevel, ".+")            +";";
   double   tickSize       = MarketInfo(Symbol(), MODE_TICKSIZE);
   double   tickValue      = MarketInfo(Symbol(), MODE_TICKVALUE);
   double   marginRequired = MarketInfo(Symbol(), MODE_MARGINREQUIRED);
   double   lotValue       = MathDiv(Close[0], tickSize) * tickValue;          message = message +" Account="     + NumberToStr(AccountBalance(), ",'.0R") +" "+ AccountCurrency()                                                            +";";
   double   leverage       = MathDiv(lotValue, marginRequired);                message = message +" Leverage=1:"  + Round(leverage)                                                                                                           +";";
   int      stopoutLevel   = AccountStopoutLevel();                            message = message +" Stopout="     + ifString(AccountStopoutMode()==MSM_PERCENT, stopoutLevel +"%", NumberToStr(stopoutLevel, ",,.0") +" "+ AccountCurrency()) +";";
   double   lotSize        = MarketInfo(Symbol(), MODE_LOTSIZE);
   double   marginHedged   = MarketInfo(Symbol(), MODE_MARGINHEDGED);
            marginHedged   = MathDiv(marginHedged, lotSize) * 100;             message = message +" MarginHedged="+ ifString(!marginHedged, "none", Round(marginHedged) +"%")                                                                 +";";
   double   pointValue     = MathDiv(tickValue, MathDiv(tickSize, Point));
   double   pipValue       = PipPoints * pointValue;                           message = message +" PipValue="    + NumberToStr(pipValue, ".2+R")                                                                                             +";";
   double   commission     = GetCommission();                                  message = message +" Commission="  + ifString(!commission, "0;", DoubleToStr(commission, 2) +"/lot");
   if (NE(commission, 0)) {
      double commissionPip = MathDiv(commission, pipValue);                    message = message +" ("            + NumberToStr(commissionPip, "."+ (Digits+1-PipDigits) +"R") +" pip)"                                                       +";";
   }
   double   swapLong       = MarketInfo(Symbol(), MODE_SWAPLONG );
   double   swapShort      = MarketInfo(Symbol(), MODE_SWAPSHORT);             message = message +" Swap="        + ifString(swapLong||swapShort, NumberToStr(swapLong, ".+") +"/"+ NumberToStr(swapShort, ".+"), "0")                        +";";

   if (!catch("Tester.GetMarketInfo(1)"))
      return(message);
   return("");
}


/**
 * Record the test's equity graph.
 *
 * @return bool - success status
 */
bool Tester.RecordEquity() {
   /*
    Speedtest SnowRoller EURUSD,M15  04.10.2012, long, GridSize 18
   +-----------------------------+--------------+-----------+--------------+-------------+-------------+--------------+--------------+--------------+
   | Toshiba Satellite           |     old      | optimized | FindBar opt. | Arrays opt. |  Read opt.  |  Write opt.  |  Valid. opt. |  in Library  |
   +-----------------------------+--------------+-----------+--------------+-------------+-------------+--------------+--------------+--------------+
   | v419 - w/o RecordEquity()   | 17.613 t/sec |           |              |             |             |              |              |              |
   | v225 - HST_BUFFER_TICKS=Off |  6.426 t/sec |           |              |             |             |              |              |              |
   | v419 - HST_BUFFER_TICKS=Off |  5.871 t/sec | 6.877 t/s |   7.381 t/s  |  7.870 t/s  |  9.097 t/s  |   9.966 t/s  |  11.332 t/s  |              |
   | v419 - HST_BUFFER_TICKS=On  |              |           |              |             |             |              |  15.486 t/s  |  14.286 t/s  |
   +-----------------------------+--------------+-----------+--------------+-------------+-------------+--------------+--------------+--------------+
   */
   if (!tester.hEquitySet) {
      // open HistorySet
      string symbol      = tester.reportSymbol;
      string description = tester.reportDescription;
      int    digits      = 2;
      int    format      = 400;
      string server      = tester.reportServer;

      // create HistorySet
      tester.hEquitySet = HistorySet1.Create(symbol, description, digits, format, server);
      if (!tester.hEquitySet) return(false);
   }

   if (!tester.equityValue) double value = AccountEquity()-AccountCredit();
   else                            value = tester.equityValue;

   return(HistorySet1.AddTick(tester.hEquitySet, Tick.Time, value, HST_BUFFER_TICKS));
}


#import "rsfLib1.ex4"
   int    CreateRawSymbol(string name, string description, string group, int digits, string baseCurrency, string marginCurrency, string serverName);
   bool   IntInArray(int haystack[], int needle);

#import "rsfMT4Expander.dll"
   int    ec_SetDllError           (int ec[], int error   );
   int    ec_SetProgramCoreFunction(int ec[], int function);

   string symbols_Name(/*SYMBOL*/int symbols[], int i);

   int    SyncMainContext_init  (int ec[], int programType, string programName, int uninitReason, int initFlags, int deinitFlags, string symbol, int timeframe, int digits, double point, int extReporting, int recordEquity, int isTesting, int isVisualMode, int isOptimization, int lpSec, int hChart, int droppedOnChart, int droppedOnPosX, int droppedOnPosY);
   int    SyncMainContext_start (int ec[], double rates[][], int bars, int changedBars, int ticks, datetime time, double bid, double ask);
   int    SyncMainContext_deinit(int ec[], int uninitReason);

   bool   Test_StartReporting (int ec[], datetime from, int bars, int reportId, string reportSymbol);
   bool   Test_StopReporting  (int ec[], datetime to,   int bars);
   bool   Test_onPositionOpen (int ec[], int ticket, int type, double lots, string symbol, datetime openTime, double openPrice, double stopLoss, double takeProfit, double commission, int magicNumber, string comment);
   bool   Test_onPositionClose(int ec[], int ticket, datetime closeTime, double closePrice, double swap, double profit);


#import "rsfHistory1.ex4"
   int    HistorySet1.Get    (string symbol, string server);
   int    HistorySet1.Create (string symbol, string description, int digits, int format, string server);
   bool   HistorySet1.Close  (int hSet);
   bool   HistorySet1.AddTick(int hSet, datetime time, double value, int flags);

#import "user32.dll"
   int  SendMessageA(int hWnd, int msg, int wParam, int lParam);
#import


// -- init() event handler templates ----------------------------------------------------------------------------------------


/**
 * Initialization preprocessing
 *
 * @return int - error status
 *
int onInit()                                                   // opening curly braces are intentionally missing (UEStudio)
   return(NO_ERROR);
}


/**
 * Called after the expert was manually loaded by the user. Also in tester with both VisualMode=On|Off.
 * There was an input dialog.
 *
 * @return int - error status
 *
int onInitUser()
   return(NO_ERROR);
}


/**
 * Called after the expert was loaded by a chart template. Also at terminal start. There was no input dialog.
 *
 * @return int - error status
 *
int onInitTemplate()
   return(NO_ERROR);
}


/**
 * Called after the input parameters were changed via the input dialog.
 *
 * @return int - error status
 *
int onInitParameters()
   return(NO_ERROR);
}


/**
 * Called after the chart timeframe has changed. There was no input dialog.
 *
 * @return int - error status
 *
int onInitTimeframeChange()
   return(NO_ERROR);
}


/**
 * Called after the chart symbol has changed. There was no input dialog.
 *
 * @return int - error status
 *
int onInitSymbolChange()
   return(NO_ERROR);
}


/**
 * Called after the expert was recompiled. There was no input dialog.
 *
 * @return int - error status
 *
int onInitRecompile()
   return(NO_ERROR);
}


/**
 * Initialization postprocessing
 *
 * @return int - error status
 *
int afterInit()
   return(NO_ERROR);
}


// -- deinit() event handler templates --------------------------------------------------------------------------------------


/**
 * Deinitialization preprocessing
 *
 * @return int - error status
 *
int onDeinit()                                                 // opening curly braces are intentionally missing (UEStudio)
   return(NO_ERROR);
}


/**
 * Called before the input parameters are changed.
 *
 * @return int - error status
 *
int onDeinitParameters()
   return(NO_ERROR);
}


/**
 * Called before the current chart symbol or period are changed.
 *
 * @return int - error status
 *
int onDeinitChartChange()
   return(NO_ERROR);
}


/**
 * Never encountered. Tracked in MT4Expander::onDeinitAccountChange().
 *
 * @return int - error status
 *
int onDeinitAccountChange()
   return(NO_ERROR);
}


/**
 * Online: Called in terminal builds <= 509 when another chart template is applied.
 *         Called when the chart profile is changed.
 *         Called when the chart is closed.
 *         Called in terminal builds <= 509 when the terminal shuts down.
 * Tester: Called when the chart is closed with VisualMode="On".
 *         Called if the test was explicitly stopped by using the "Stop" button (manually or by code). Global scalar variables
 *          may contain invalid values (strings are ok).
 *
 * @return int - error status
 *
int onDeinitChartClose()
   return(NO_ERROR);
}


/**
 * Online: Called in terminal builds > 509 when another chart template is applied.
 * Tester: ???
 *
 * @return int - error status
 *
int onDeinitTemplate()
   return(NO_ERROR);
}


/**
 * Online: Called when the expert is manually removed (Chart->Expert->Remove) or replaced.
 * Tester: Never called.
 *
 * @return int - error status
 *
int onDeinitRemove()
   return(NO_ERROR);
}


/**
 * Online: Never encountered. Tracked in MT4Expander::onDeinitUndefined().
 * Tester: Called if a test finished regularily, i.e. the test period ended.
 *         Called if a test prematurely stopped because of a margin stopout (enforced by the tester).
 *
 * @return int - error status
 *
int onDeinitUndefined()
   return(NO_ERROR);
}


/**
 * Online: Called before the expert is reloaded after recompilation. May happen on refresh of the "Navigator" window.
 * Tester: Never called.
 *
 * @return int - error status
 *
int onDeinitRecompile()
   return(NO_ERROR);
}


/**
 * Called in terminal builds > 509 when the terminal shuts down.
 *
 * @return int - error status
 *
int onDeinitClose()
   return(NO_ERROR);
}


/**
 * Deinitialization postprocessing
 *
 * @return int - error status
 *
int afterDeinit()
   return(NO_ERROR);
}
*/
