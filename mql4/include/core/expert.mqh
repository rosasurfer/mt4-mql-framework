
#define __lpSuperContext NULL
int     __CoreFunction = NULL;                                       // currently executed MQL core function: CF_INIT | CF_START | CF_DEINIT

extern string   _______________________________ = "";
extern bool     EA.CreateReport                 = false;
extern bool     EA.RecordEquity                 = false;
extern datetime Tester.StartTime                = 0;                 // time to start a test
extern double   Tester.StartPrice               = 0;                 // price to start a test

#include <functions/InitializeByteBuffer.mqh>


double __rates[][6];                                                 // current price series
int    tickTimerId;                                                  // timer id for virtual ticks

// test metadata
string tester.starttime         = "";
string tester.startprice        = "";
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
      ForceAlert("DLL function calls are not enabled. Please go to Tools -> Options -> Expert Advisors and allow DLL imports.");
      last_error          = ERR_DLL_CALLS_NOT_ALLOWED;
      __STATUS_OFF        = true;
      __STATUS_OFF.reason = last_error;
      return(last_error);
   }
   if (!IsLibrariesAllowed()) {
      ForceAlert("MQL library calls are not enabled. Please load the EA with \"Allow imports of external experts\" enabled.");
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

   int error = SyncMainContext_init(__ExecutionContext, MT_EXPERT, WindowExpertName(), UninitializeReason(), SumInts(__INIT_FLAGS__), SumInts(__DEINIT_FLAGS__), Symbol(), Period(), Digits, Point, EA.CreateReport, EA.RecordEquity, IsTesting(), IsVisualMode(), IsOptimization(), __lpSuperContext, hChart, WindowOnDropped(), WindowXOnDropped(), WindowYOnDropped());
   if (!error) error = GetLastError();                               // detect a DLL exception
   if (IsError(error)) {
      ForceAlert("ERROR:   "+ Symbol() +","+ PeriodDescription(Period()) +"  "+ WindowExpertName() +"::init(2)->SyncMainContext_init()  ["+ ErrorToStr(error) +"]");
      last_error          = error;
      __STATUS_OFF        = true;                                    // If SyncMainContext_init() failed the content of the EXECUTION_CONTEXT
      __STATUS_OFF.reason = last_error;                              // is undefined. We must not trigger loading of MQL libraries and return asap.
      __CoreFunction      = NULL;
      return(last_error);
   }

   // finish initialization of global vars
   if (!init.GlobalVars()) if (CheckErrors("init(3)")) return(last_error);

   // execute custom init tasks
   int initFlags = __ExecutionContext[EC.programInitFlags];
   if (initFlags & INIT_TIMEZONE && 1) {
      if (!StringLen(GetServerTimezone()))  return(_last_error(CheckErrors("init(4)")));
   }
   if (initFlags & INIT_PIPVALUE && 1) {
      TickSize = MarketInfo(Symbol(), MODE_TICKSIZE);                // fails if there is no tick yet
      error = GetLastError();
      if (IsError(error)) {                                          // symbol not yet subscribed (start, account/template change), it may "show up" later
         if (error == ERR_SYMBOL_NOT_AVAILABLE)                      // synthetic symbol in offline chart
            return(log("init(5)  MarketInfo() => ERR_SYMBOL_NOT_AVAILABLE", SetLastError(ERS_TERMINAL_NOT_YET_READY)));
         if (CheckErrors("init(6)", error)) return(last_error);
      }
      if (!TickSize) return(log("init(7)  MarketInfo(MODE_TICKSIZE) = 0", SetLastError(ERS_TERMINAL_NOT_YET_READY)));

      double tickValue = MarketInfo(Symbol(), MODE_TICKVALUE);
      error = GetLastError();
      if (IsError(error)) /*&&*/ if (CheckErrors("init(8)", error)) return(last_error);
      if (!tickValue) return(log("init(9)  MarketInfo(MODE_TICKVALUE) = 0", SetLastError(ERS_TERMINAL_NOT_YET_READY)));
   }
   if (initFlags & INIT_BARS_ON_HIST_UPDATE && 1) {}                 // not yet implemented

   // enable experts if disabled
   int reasons1[] = {UR_UNDEFINED, UR_CHARTCLOSE, UR_REMOVE};
   if (!IsTesting()) /*&&*/ if (!IsExpertEnabled()) /*&&*/ if (IntInArray(reasons1, UninitializeReason())) {
      error = Toolbar.Experts(true);                                 // TODO: fails if multiple experts try it at the same time (e.g. at terminal start)
      if (IsError(error)) /*&&*/ if (CheckErrors("init(10)")) return(last_error);
   }

   // we must explicitely reset the order context after the expert was reloaded
   int reasons2[] = {UR_UNDEFINED, UR_CHARTCLOSE, UR_REMOVE, UR_ACCOUNT};
   if (IntInArray(reasons2, UninitializeReason())) {
      OrderSelect(0, SELECT_BY_TICKET);
      error = GetLastError();
      if (error && error!=ERR_NO_TICKET_SELECTED) return(_last_error(CheckErrors("init(11)", error)));
   }

   // reset the window title in tester (might have been modified by the previous test)
   if (IsTesting()) {                                                // TODO: wait until done
      if (!SetWindowTextA(FindTesterWindow(), "Tester")) return(_last_error(CheckErrors("init(12)->user32::SetWindowTextA()", ERR_WIN32_ERROR)));
      // resolve the account number (optimistic: if called in deinit() it will deadlock the UI thread)
      if (!GetAccountNumber())                           return(_last_error(CheckErrors("init(13)")));
   }

   // log original input parameters
   string input1="", input2="", inputDiff="";
   if (UninitializeReason()!=UR_CHARTCHANGE && __LOG()) {
      input1 = InputsToStr();
      if (StringLen(input1) > 0) {
         input1 = StringConcatenate(input1,
            ifString(!EA.CreateReport,   "", NL+"EA.CreateReport=TRUE"                                            +";"),
            ifString(!EA.RecordEquity,   "", NL+"EA.RecordEquity=TRUE"                                            +";"),
            ifString(!Tester.StartTime,  "", NL+"Tester.StartTime="+  TimeToStr(Tester.StartTime, TIME_FULL)      +";"),
            ifString(!Tester.StartPrice, "", NL+"Tester.StartPrice="+ NumberToStr(Tester.StartPrice, PriceFormat) +";"));
         log("init()  input: "+ input1);
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
   error = onInit();                                                          // pre-processing hook
                                                                              //
   if (!error && !__STATUS_OFF) {                                             //
      int initReason = ProgramInitReason();                                   //
      if (!initReason) if (CheckErrors("init(14)")) return(last_error);       //
                                                                              //
      switch (initReason) {                                                   //
         case IR_USER            : error = onInitUser();            break;    // init reasons
         case IR_TEMPLATE        : error = onInitTemplate();        break;    //
         case IR_PARAMETERS      : error = onInitParameters();      break;    //
         case IR_TIMEFRAMECHANGE : error = onInitTimeframeChange(); break;    //
         case IR_SYMBOLCHANGE    : error = onInitSymbolChange();    break;    //
         case IR_RECOMPILE       : error = onInitRecompile();       break;    //
         case IR_TERMINAL_FAILURE:                                            //
         default:                                                             //
            return(_last_error(CheckErrors("init(15)  unsupported initReason = "+ initReason, ERR_RUNTIME_ERROR)));
      }                                                                       //
   }                                                                          //
   if (error == ERS_TERMINAL_NOT_YET_READY) return(error);                    //
                                                                              //
   if (!error && !__STATUS_OFF)                                               //
      afterInit();                                                            // post-processing hook
   if (CheckErrors("init(16)")) return(last_error);

   // log modified input parameters
   if (UninitializeReason()!=UR_CHARTCHANGE && __LOG()) {
      input2 = InputsToStr();
      if (StringLen(input2) > 0) {
         input2 = StringConcatenate(input2,
            ifString(!EA.CreateReport,   "", NL+"EA.CreateReport=TRUE"                                            +";"),
            ifString(!EA.RecordEquity,   "", NL+"EA.RecordEquity=TRUE"                                            +";"),
            ifString(!Tester.StartTime,  "", NL+"Tester.StartTime="+  TimeToStr(Tester.StartTime, TIME_FULL)      +";"),
            ifString(!Tester.StartPrice, "", NL+"Tester.StartPrice="+ NumberToStr(Tester.StartPrice, PriceFormat) +";"));
         inputDiff = InputParamsDiff(input1, input2);
         if (StringLen(inputDiff) > 0)
            log("init()  input: "+ inputDiff);
      }
   }

   // log MarketInfo() data if in tester
   if (IsTesting()) {
      Tester.LogMarketInfo();
      tester.starttime   = ifString(!Tester.StartTime, "", TimeToStr(Tester.StartTime, TIME_FULL));
      tester.startprice  = ifString(!Tester.StartPrice, "", NumberToStr(Tester.StartPrice, PriceFormat));
      tester.startEquity = NormalizeDouble(AccountEquity()-AccountCredit(), 2);
   }

   if (CheckErrors("init(17)"))
      return(last_error);
   ShowStatus(last_error);

   // setup virtual ticks to continue operation on a stalled data feed
   if (!IsTesting()) {
      int hWnd    = __ExecutionContext[EC.hChart];
      int millis  = 10 * 1000;                                             // every 10 seconds
      tickTimerId = SetupTickTimer(hWnd, millis, NULL);
      if (!tickTimerId) return(catch("init(18)->SetupTickTimer(hWnd="+ IntToHexStr(hWnd) +") failed", ERR_RUNTIME_ERROR));
   }

   // immediately send a virtual tick (except on UR_CHARTCHANGE)
   if (UninitializeReason() != UR_CHARTCHANGE)                             // At the very end, otherwise the Windows message
      Chart.SendTick();                                                    // queue may be processed before this function is
   return(last_error);                                                     // left and the tick gets lost.
}


/**
 * Update global variables and the expert's EXECUTION_CONTEXT. Called immediately after SyncMainContext_init().
 *
 * @return bool - success status
 */
bool init.GlobalVars() {
   PipDigits      = Digits & (~1);                                        SubPipDigits      = PipDigits+1;
   PipPoints      = MathRound(MathPow(10, Digits & 1));                   PipPoint          = PipPoints;
   Pips           = NormalizeDouble(1/MathPow(10, PipDigits), PipDigits); Pip               = Pips;
   PipPriceFormat = StringConcatenate(".", PipDigits);                    SubPipPriceFormat = StringConcatenate(PipPriceFormat, "'");
   PriceFormat    = ifString(Digits==PipDigits, PipPriceFormat, SubPipPriceFormat);

   ec_SetLogEnabled          (__ExecutionContext, init.IsLogEnabled());
   ec_SetLogToDebugEnabled   (__ExecutionContext, GetConfigBool("Logging", "LogToDebug", true));
   ec_SetLogToTerminalEnabled(__ExecutionContext, true);

   __LOG_WARN.mail  = init.LogWarningsToMail();
   __LOG_WARN.sms   = init.LogWarningsToSMS();
   __LOG_ERROR.mail = init.LogErrorsToMail();
   __LOG_ERROR.sms  = init.LogErrorsToSMS();

   N_INF = MathLog(0);
   P_INF = -N_INF;
   NaN   =  N_INF - N_INF;

   return(!catch("init.GlobalVars(1)"));
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
         if (__CHART()) ShowStatus(__STATUS_OFF.reason);
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
   ChangedBars   = -1;                                                              // in experts not available
   UnchangedBars = -1;                                                              // ...
   ShiftedBars   = -1;                                                              // ...

   // if called after init() check it's return value
   if (__CoreFunction == CF_INIT) {
      __CoreFunction = ec_SetProgramCoreFunction(__ExecutionContext, CF_START);     // __STATUS_OFF is FALSE here, but an error may be set

      if (last_error == ERS_TERMINAL_NOT_YET_READY) {
         log("start(2)  init() returned ERS_TERMINAL_NOT_YET_READY, retrying...");
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

   // relaunch input dialog if requested
   if (__STATUS_RELAUNCH_INPUT) {
      __STATUS_RELAUNCH_INPUT = false;
      start.RelaunchInputDialog();
      return(_last_error(CheckErrors("start(3)")));
   }

   // check a finished chart initialisation (may fail on terminal start)
   if (!Bars) return(ShowStatus(SetLastError(log("start(4)  Bars=0", ERS_TERMINAL_NOT_YET_READY))));

   // in tester wait until the configured start time/price is reached
   if (IsTesting()) {
      if (Tester.StartTime != 0) {
         if (Tick.Time < Tester.StartTime) {
            Comment(NL, NL, NL, "Tester: starting at ", tester.starttime);
            return(last_error);
         }
         Tester.StartTime = 0;
      }
      if (Tester.StartPrice != 0) {
         static double tester.lastPrice; if (!tester.lastPrice) {
            tester.lastPrice = Bid;
            Comment(NL, NL, NL, "Tester: starting at ", tester.startprice);
            return(last_error);
         }
         if (LT(tester.lastPrice, Tester.StartPrice)) /*&&*/ if (LT(Bid, Tester.StartPrice)) {
            tester.lastPrice = Bid;
            Comment(NL, NL, NL, "Tester: starting at ", tester.startprice);
            return(last_error);
         }
         if (GT(tester.lastPrice, Tester.StartPrice)) /*&&*/ if (GT(Bid, Tester.StartPrice)) {
            tester.lastPrice = Bid;
            Comment(NL, NL, NL, "Tester: starting at ", tester.startprice);
            return(last_error);
         }
         Tester.StartPrice = 0;
      }
   }

   ArrayCopyRates(__rates);

   if (SyncMainContext_start(__ExecutionContext, __rates, Bars, -1, Tick, Tick.Time, Bid, Ask) != NO_ERROR) {
      if (CheckErrors("start(5)")) return(last_error);
   }

   // initialize test reporting if configured
   if (IsTesting()) {
      static bool test.initialized = false; if (!test.initialized) {
         if (!Tester.InitReporting()) return(_last_error(CheckErrors("start(6)")));
         test.initialized = true;
      }
   }

   // call the userland main function
   onTick();

   // record equity if configured
   if (IsTesting()) /*&&*/ if (!IsOptimization()) /*&&*/ if (EA.RecordEquity) {
      if (!Tester.RecordEquity()) return(_last_error(CheckErrors("start(7)")));
   }

   // check all errors
   error = GetLastError();
   if (error || last_error|__ExecutionContext[EC.mqlError]|__ExecutionContext[EC.dllError])
      return(_last_error(CheckErrors("start(8)", error)));

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

   if (IsTesting()) {
      if (tester.hEquitySet != 0) {
         int tmp=tester.hEquitySet; tester.hEquitySet=NULL;
         if (!HistorySet.Close(tmp)) return(_last_error(CheckErrors("deinit(1)"))|LeaveContext(__ExecutionContext));
      }
      if (!__STATUS_OFF) /*&&*/ if (EA.CreateReport) {
         datetime time = MarketInfo(Symbol(), MODE_TIME);
         Test_StopReporting(__ExecutionContext, time, Bars);
      }
   }

   // reset the virtual tick timer
   if (tickTimerId != NULL) {
      int id = tickTimerId;
      tickTimerId = NULL;
      if (!RemoveTickTimer(id)) return(catch("deinit(2)->RemoveTickTimer(timerId="+ id +") failed", ERR_RUNTIME_ERROR));
   }

   // Execute user-specific deinit() handlers (if implemented). Handlers are executed as long as the previous handler doesn't
   // return with an error.
   error = onDeinit();                                                     // preprocessing hook
   if (!error) {                                                           //
      switch (UninitializeReason()) {                                      //
         case UR_PARAMETERS : error = onDeinitParameters();    break;      // reason-specific handlers
         case UR_CHARTCHANGE: error = onDeinitChartChange();   break;      //
         case UR_ACCOUNT    : error = onDeinitAccountChange(); break;      //
         case UR_CHARTCLOSE : error = onDeinitChartClose();    break;      //
         case UR_UNDEFINED  : error = onDeinitUndefined();     break;      //
         case UR_REMOVE     : error = onDeinitRemove();        break;      //
         case UR_RECOMPILE  : error = onDeinitRecompile();     break;      //
         // build > 509                                                    //
         case UR_TEMPLATE   : error = onDeinitTemplate();      break;      //
         case UR_INITFAILED : error = onDeinitFailed();        break;      //
         case UR_CLOSE      : error = onDeinitClose();         break;      //
                                                                           //
         default:                                                          //
            CheckErrors("deinit(3)  unknown UninitializeReason = "+ UninitializeReason(), ERR_RUNTIME_ERROR);
            return(last_error|LeaveContext(__ExecutionContext));           //
      }                                                                    //
   }                                                                       //
   if (!error) error = afterDeinit();                                      // postprocessing hook
   DeleteRegisteredObjects();

   CheckErrors("deinit(4)");
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
 * Check/update the program's error status and activate the flag __STATUS_OFF accordingly. Call ShowStatus() if the flag was
 * activated.
 *
 * @param  string location            - location of the check
 * @param  int    setError [optional] - error to enforce (default: none)
 *
 * @return bool - whether the flag __STATUS_OFF is set
 */
bool CheckErrors(string location, int setError = NULL) {
   // check and signal DLL errors
   int dll_error = __ExecutionContext[EC.dllError];                  // TODO: signal DLL errors
   if (dll_error && 1) {
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
   if (!setError) setError = GetLastError();
   if (setError != NO_ERROR)
      catch(location, setError);                                     // catch() calls SetLastError(error) which calls CheckErrors(error)
                                                                     // which updates __STATUS_OFF accordingly
   // update the variable last_error
   if (__STATUS_OFF) /*&&*/ if (!last_error)
      last_error = __STATUS_OFF.reason;

   if (__STATUS_OFF)
      ShowStatus(last_error);                                        // always show status if an error occurred
   return(__STATUS_OFF);

   // suppress compiler warnings
   __DummyCalls();
   SetCustomLog(NULL);
}


/**
 * Configure the use of a custom logfile.
 *
 * @param  string filename - name of a custom logfile or an empty string to disable custom logging
 *
 * @return bool - success status
 */
bool SetCustomLog(string filename) {
   return(SetCustomLogA(__ExecutionContext, filename));
}


/**
 * Called once at start of a test. If reporting is enabled the test's metadata is initialized.
 *
 * @return bool - success status
 */
bool Tester.InitReporting() {
   if (!IsTesting())
      return(false);

   // prepare environment to record the equity curve
   if (EA.RecordEquity) /*&&*/ if (!IsOptimization()) {
      // create a new report symbol
      int    id             = 0;
      string symbol         = "";
      string symbolGroup    = StrLeft(__NAME(), MAX_SYMBOL_GROUP_LENGTH);
      string description    = "";
      int    digits         = 2;
      string baseCurrency   = AccountCurrency();
      string marginCurrency = AccountCurrency();

      // open "symbols.raw" and read the existing symbols
      string mqlFileName = "history\\"+ tester.reportServer +"\\symbols.raw";
      int hFile = FileOpen(mqlFileName, FILE_READ|FILE_BIN);
      int error = GetLastError();
      if (IsError(error) || hFile <= 0)                              return(!catch("Tester.InitReporting(1)->FileOpen(\""+ mqlFileName +"\", FILE_READ) => "+ hFile, ifInt(error, error, ERR_RUNTIME_ERROR)));

      int fileSize = FileSize(hFile);
      if (fileSize % SYMBOL.size != 0) { FileClose(hFile);           return(!catch("Tester.InitReporting(2)  invalid size of \""+ mqlFileName +"\" (not an even SYMBOL size, "+ (fileSize % SYMBOL.size) +" trailing bytes)", ifInt(SetLastError(GetLastError()), last_error, ERR_RUNTIME_ERROR))); }
      int symbolsSize = fileSize/SYMBOL.size;

      int symbols[]; InitializeByteBuffer(symbols, fileSize);
      if (fileSize > 0) {
         // read symbols
         int ints = FileReadArray(hFile, symbols, 0, fileSize/4);
         error = GetLastError();
         if (IsError(error) || ints!=fileSize/4) { FileClose(hFile); return(!catch("Tester.InitReporting(3)  error reading \""+ mqlFileName +"\" ("+ (ints*4) +" of "+ fileSize +" bytes read)", ifInt(error, error, ERR_RUNTIME_ERROR))); }
      }
      FileClose(hFile);

      // iterate over existing symbols and determine the next available one matching "{ExpertName}.{001-xxx}"
      string suffix, name = StrLeft(StrReplace(__NAME(), " ", ""), 7) +".";

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
      description = StrLeft(__NAME(), 38) +" #"+ id;                                      // 38 + 2 +  3 = 43 chars
      description = description +" "+ LocalTimeFormat(GetGmtTime(), "%d.%m.%Y %H:%M:%S"); // 43 + 1 + 19 = 63 chars

      // create symbol
      if (CreateSymbol(symbol, description, symbolGroup, digits, baseCurrency, marginCurrency, tester.reportServer) < 0)
         return(false);

      tester.reportId          = id;
      tester.reportSymbol      = symbol;
      tester.reportDescription = description;
   }

   // prepare environment to collect data for reporting
   if (EA.CreateReport) {
      datetime time = MarketInfo(Symbol(), MODE_TIME);
      Test_StartReporting(__ExecutionContext, time, Bars, tester.reportId, tester.reportSymbol);
   }
   return(true);
}


/**
 * Log important MarketInfo() data.
 *
 * @return bool - success status
 */
bool Tester.LogMarketInfo() {
   if (!__LOG()) return(true);

   string message = "";

   datetime time           = MarketInfo(Symbol(), MODE_TIME);                  message = message +" Time="        + GmtTimeFormat(time, "%a, %d.%m.%Y %H:%M") +";";
                                                                               message = message +" Bars="        + Bars                                      +";";
   double   spread         = MarketInfo(Symbol(), MODE_SPREAD)/PipPoints;      message = message +" Spread="      + NumberToStr(spread, ".+")                 +";";
                                                                               message = message +" Digits="      + Digits                                    +";";
   double   minLot         = MarketInfo(Symbol(), MODE_MINLOT);                message = message +" MinLot="      + NumberToStr(minLot, ".+")                 +";";
   double   lotStep        = MarketInfo(Symbol(), MODE_LOTSTEP);               message = message +" LotStep="     + NumberToStr(lotStep, ".+")                +";";
   double   stopLevel      = MarketInfo(Symbol(), MODE_STOPLEVEL)/PipPoints;   message = message +" StopLevel="   + NumberToStr(stopLevel, ".+")              +";";
   double   freezeLevel    = MarketInfo(Symbol(), MODE_FREEZELEVEL)/PipPoints; message = message +" FreezeLevel=" + NumberToStr(freezeLevel, ".+")            +";";
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
   double   commission     = GetCommission();                                  message = message +" Commission="  + ifString(!commission, "0;", NumberToStr(commission, ".2R") +"/lot");
   if (NE(commission, 0)) {
      double commissionPip = MathDiv(commission, pipValue);                    message = message +" ("            + NumberToStr(commissionPip, "."+ (Digits+1-PipDigits) +"R") +" pip)"                                                       +";";
   }
   double   swapLong       = MarketInfo(Symbol(), MODE_SWAPLONG );
   double   swapShort      = MarketInfo(Symbol(), MODE_SWAPSHORT);             message = message +" Swap="        + ifString(swapLong||swapShort, NumberToStr(swapLong, ".+") +"/"+ NumberToStr(swapShort, ".+"), "0")                        +";";
   log("MarketInfo()"+ message);

   return(!catch("Tester.LogMarketInfo(1)"));
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
   int flags = HST_BUFFER_TICKS;

   // open HistorySet
   if (!tester.hEquitySet) {
      string symbol      = tester.reportSymbol;
      string description = tester.reportDescription;
      int    digits      = 2;
      int    format      = 400;
      string server      = tester.reportServer;

      // create HistorySet
      tester.hEquitySet = HistorySet.Create(symbol, description, digits, format, server);
      if (!tester.hEquitySet) return(false);
   }

   // resolve current equity value and store it
   if (!tester.equityValue) double value = AccountEquity()-AccountCredit();
   else                            value = tester.equityValue;
   if (!HistorySet.AddTick(tester.hEquitySet, Tick.Time, value, flags))
      return(false);
   return(true);
}


// --------------------------------------------------------------------------------------------------------------------------


#import "rsfLib1.ex4"
   bool   IntInArray(int haystack[], int needle);

#import "rsfExpander.dll"
   int    ec_SetDllError            (int ec[], int error   );
   bool   ec_SetLogEnabled          (int ec[], int status  );
   bool   ec_SetLogToDebugEnabled   (int ec[], int status  );
   bool   ec_SetLogToTerminalEnabled(int ec[], int status  );
   int    ec_SetProgramCoreFunction (int ec[], int function);
   bool   SetCustomLogA             (int ec[], string file );

   string symbols_Name(/*SYMBOL*/int symbols[], int i);

   int    SyncMainContext_init  (int ec[], int programType, string programName, int uninitReason, int initFlags, int deinitFlags, string symbol, int timeframe, int digits, double point, int extReporting, int recordEquity, int isTesting, int isVisualMode, int isOptimization, int lpSec, int hChart, int droppedOnChart, int droppedOnPosX, int droppedOnPosY);
   int    SyncMainContext_start (int ec[], double rates[][], int bars, int changedBars, int ticks, datetime time, double bid, double ask);
   int    SyncMainContext_deinit(int ec[], int uninitReason);

   bool   Test_StartReporting(int ec[], datetime from, int bars, int reportId, string reportSymbol);
   bool   Test_StopReporting (int ec[], datetime to,   int bars);

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


// -- init() event handler templates (opening curly braces are intentionally missing) ---------------------------------------


/**
 * Initialization pre-processing hook.
 *
 * @return int - error status
 *
int onInit()
   return(NO_ERROR);
}


/**
 * Called after the expert was manually loaded by the user. Also in Tester with both VisualMode=On|Off.
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
 * Called after the current chart period has changed. There was no input dialog.
 *
 * @return int - error status
 *
int onInitTimeframeChange()
   return(NO_ERROR);
}


/**
 * Called after the current chart symbol has changed. There was no input dialog.
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
 * Initialization post-processing hook.
 *
 * @return int - error status
 *
int afterInit()
   return(NO_ERROR);
}


// -- deinit() event handler templates (opening curly braces are intentionally missing) -------------------------------------


/**
 * Deinitialization pre-processing hook.
 *
 * @return int - error status
 *
int onDeinit()
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
 * Never encountered. Tracked in Expander::onDeinitAccountChange().
 *
 * @return int - error status
 *
int onDeinitAccountChange()
   return(NO_ERROR);
}


/**
 * Online:    - Called when another chart template is applied.
 *            - Called when the chart profile is changed.
 *            - Called when the chart is closed.
 *            - Called in terminal versions up to build 509 when the terminal shuts down.
 * In tester: - Called if the test was explicitly stopped by using the "Stop" button (manually or by code).
 *            - Called when the chart is closed (with VisualMode=On).
 *
 * @return int - error status
 *
int onDeinitChartClose()
   return(NO_ERROR);
}


/**
 * Online:    Called if an expert is manually removed (Chart->Expert->Remove) or replaced.
 * In tester: Never called.
 *
 * @return int - error status
 *
int onDeinitRemove()
   return(NO_ERROR);
}


/**
 * Online:    Never encountered. Tracked in Expander::onDeinitUndefined().
 * In tester: Called if a test finished regularily, i.e. the test period ended.
 *
 * @return int - error status
 *
int onDeinitUndefined()
   return(NO_ERROR);
}


/**
 * Called before an expert is reloaded after recompilation.
 *
 * @return int - error status
 *
int onDeinitRecompile()
   return(NO_ERROR);
}


/**
 * Called in terminal versions > build 509 when the terminal shuts down.
 *
 * @return int - error status
 *
int onDeinitClose()
   return(NO_ERROR);
}


/**
 * Deinitialization post-processing hook. Executed if neither the pre-processing hook (if implemented) nor the uninitialize
 * reason specific handlers (if implemented) returned -1.
 *
 * @return int - error status
 *
int afterDeinit()
   return(NO_ERROR);
}
*/
