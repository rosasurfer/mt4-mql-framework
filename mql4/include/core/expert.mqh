
//////////////////////////////////////////////// Additional Input Parameters ////////////////////////////////////////////////

extern string   ______________________________;
extern bool     EA.Recorder          = false;      // whether to record PL graphs
extern bool     EA.ExternalReporting = false;      // whether to send PositionOpen/Close events to the Expander

extern datetime Test.StartTime       = 0;          // time to start a test
extern double   Test.StartPrice      = 0;          // price to start a test

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <functions/InitializeByteBuffer.mqh>

#define __lpSuperContext NULL
int     __CoreFunction = NULL;                     // currently executed MQL core function: CF_INIT | CF_START | CF_DEINIT
double  __rates[][6];                              // current price series
int     __tickTimerId;                             // timer id for virtual ticks

// PL recorder
bool   recorder.initialized  = false;
string recorder.symbol      [1] = {""};            // all values can be overwritten by the EA
string recorder.symbolDescr [1] = {""};            // ...
string recorder.symbolGroup [1] = {""};            // ...
int    recorder.symbolDigits[1];                   // ...
double recorder.startValue  [1];                   // ...
double recorder.currValue   [1];                   // ...
string recorder.hstDirectory[1] = {""};            // ...
int    recorder.hstFormat   [1];                   // ...
int    recorder.hSet        [1];                   // except the history set handle

// test management
bool   test.initialized = false;


/**
 * Global init() function for experts.
 *
 * @return int - error status
 */
int init() {
   if (__STATUS_OFF) {                                         // TODO: process ERR_INVALID_INPUT_PARAMETER (enable re-input)
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

   if (__CoreFunction == NULL) {                               // init() is called by the terminal
      __CoreFunction = CF_INIT;                                // TODO: ??? does this work in experts ???
      prev_error   = last_error;
      ec_SetDllError(__ExecutionContext, SetLastError(NO_ERROR));
   }

   // initialize the execution context
   int hChart = NULL; if (!IsTesting() || IsVisualMode())      // in tester WindowHandle() triggers ERR_FUNC_NOT_ALLOWED_IN_TESTER if VisualMode=Off
       hChart = WindowHandle(Symbol(), NULL);
   int initFlags=SumInts(__InitFlags), deinitFlags=SumInts(__DeinitFlags);
   if (EA.ExternalReporting && initFlags & INIT_NO_EXTERNAL_REPORTING) {
      EA.ExternalReporting = false;                            // the input must be reset before SyncMainContext_init()
   }
   int error = SyncMainContext_init(__ExecutionContext, MT_EXPERT, WindowExpertName(), UninitializeReason(), initFlags, deinitFlags, Symbol(), Period(), Digits, Point, EA.ExternalReporting, EA.Recorder, IsTesting(), IsVisualMode(), IsOptimization(), __lpSuperContext, hChart, WindowOnDropped(), WindowXOnDropped(), WindowYOnDropped());
   if (!error) error = GetLastError();                         // detect a DLL exception
   if (IsError(error)) {
      ForceAlert("ERROR:   "+ Symbol() +","+ PeriodDescription() +"  "+ WindowExpertName() +"::init(2)->SyncMainContext_init()  ["+ ErrorToStr(error) +"]");
      last_error          = error;
      __STATUS_OFF        = true;                              // If SyncMainContext_init() failed the content of the EXECUTION_CONTEXT
      __STATUS_OFF.reason = last_error;                        // is undefined. We must not trigger loading of MQL libraries and return asap.
      __CoreFunction      = NULL;
      return(last_error);
   }

   // finish initialization of global vars
   if (!init_Globals()) if (CheckErrors("init(3)")) return(last_error);

   // execute custom init tasks
   initFlags = __ExecutionContext[EC.programInitFlags];
   if (initFlags & INIT_TIMEZONE && 1) {
      if (!StringLen(GetServerTimezone()))  return(_last_error(CheckErrors("init(4)")));
   }
   if (initFlags & INIT_PIPVALUE && 1) {
      double tickSize = MarketInfo(Symbol(), MODE_TICKSIZE);   // fails if there is no tick yet
      error = GetLastError();
      if (IsError(error)) {                                    // symbol not yet subscribed (start, account/template change), it may appear later
         if (error == ERR_SYMBOL_NOT_AVAILABLE)                // synthetic symbol in offline chart
            return(logInfo("init(5)  MarketInfo(MODE_TICKSIZE) => ERR_SYMBOL_NOT_AVAILABLE", SetLastError(ERS_TERMINAL_NOT_YET_READY)));
         if (CheckErrors("init(6)", error)) return(last_error);
      }
      if (!tickSize) return(logInfo("init(7)  MarketInfo(MODE_TICKSIZE=0)", SetLastError(ERS_TERMINAL_NOT_YET_READY)));

      double tickValue = MarketInfo(Symbol(), MODE_TICKVALUE);
      error = GetLastError();
      if (IsError(error)) /*&&*/ if (CheckErrors("init(8)", error)) return(last_error);
      if (!tickValue) return(logInfo("init(9)  MarketInfo(MODE_TICKVALUE=0)", SetLastError(ERS_TERMINAL_NOT_YET_READY)));
   }
   if (initFlags & INIT_BARS_ON_HIST_UPDATE && 1) {}           // not yet implemented

   // enable experts if they are disabled
   int reasons1[] = {UR_UNDEFINED, UR_CHARTCLOSE, UR_REMOVE};
   if (!IsTesting()) /*&&*/ if (!IsExpertEnabled()) /*&&*/ if (IntInArray(reasons1, UninitializeReason())) {
      error = Toolbar.Experts(true);                           // TODO: fails if multiple experts try it at the same time (e.g. at terminal start)
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
   string initHandlers[] = {"", "initUser", "initTemplate", "", "", "initParameters", "initTimeframeChange", "initSymbolChange", "initRecompile"};

   if (IsTesting()) {                                          // log MarketInfo() data
      if (IsLogInfo()) {
         string msg = initHandlers[initReason] +"(0)  MarketInfo: "+ init_MarketInfo();
         string separator = StrRepeat(":", StringLen(msg));
         if (IsTesting()) separator = "::: TEST :::"+ StrRight(separator, -12);
         logInfo(separator);
         logInfo(msg);
      }
   }
   else if (UninitializeReason() != UR_CHARTCHANGE) {          // log account infos (this becomes the first regular online log entry)
      if (IsLogInfo()) {
         msg = initHandlers[initReason] +"(0)  "+ GetAccountServerName() +", account "+ account +" ("+ ifString(IsDemoFix(), "demo", "real") +")";
         logInfo(StrRepeat(":", StringLen(msg)));
         logInfo(msg);
      }
   }

   if (UninitializeReason() != UR_CHARTCHANGE) {               // log input parameters
      if (IsLogDebug()) {
         string sInputs = InputsToStr();
         if (StringLen(sInputs) > 0) {
            sInputs = StringConcatenate(sInputs,
               ifString(!EA.Recorder,          "", NL +"EA.Recorder=TRUE"                                            +";"),
               ifString(!EA.ExternalReporting, "", NL +"EA.ExternalReporting=TRUE"                                   +";"),
               ifString(!Test.StartTime,       "", NL +"Test.StartTime="+ TimeToStr(Test.StartTime, TIME_FULL)       +";"),
               ifString(!Test.StartPrice,      "", NL +"Test.StartPrice="+ NumberToStr(Test.StartPrice, PriceFormat) +";"));
            logDebug(initHandlers[initReason] +"(0)  inputs: "+ sInputs);
         }
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
            return(_last_error(CheckErrors("init(13)  unsupported initReason: "+ initReason, ERR_RUNTIME_ERROR)));
      }                                                                       //
   }                                                                          //
   if (error == ERS_TERMINAL_NOT_YET_READY) return(error);                    //
                                                                              //
   if (!error && !__STATUS_OFF)                                               //
      afterInit();                                                            // postprocessing hook

   if (CheckErrors("init(14)")) return(last_error);
   ShowStatus(last_error);

   // setup virtual ticks to continue operation on a stalled data feed
   if (!IsTesting()) {
      int hWnd    = __ExecutionContext[EC.hChart];
      int millis  = 10 * 1000;                                                // every 10 seconds
      __tickTimerId = SetupTickTimer(hWnd, millis, NULL);
      if (!__tickTimerId) return(catch("init(15)->SetupTickTimer(hWnd="+ IntToHexStr(hWnd) +") failed", ERR_RUNTIME_ERROR));
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
bool init_Globals() {
   __isChart      = (__ExecutionContext[EC.hChart] != 0);
   PipDigits      = Digits & (~1);                                        SubPipDigits      = PipDigits+1;
   PipPoints      = MathRound(MathPow(10, Digits & 1));                   PipPoint          = PipPoints;
   Pips           = NormalizeDouble(1/MathPow(10, PipDigits), PipDigits); Pip               = Pips;
   PipPriceFormat = StringConcatenate(",'R.", PipDigits);                 SubPipPriceFormat = StringConcatenate(PipPriceFormat, "'");
   PriceFormat    = ifString(Digits==PipDigits, PipPriceFormat, SubPipPriceFormat);

   N_INF = MathLog(0);                                                        // negative infinity
   P_INF = -N_INF;                                                            // positive infinity
   NaN   =  N_INF - N_INF;                                                    // not-a-number

   return(!catch("init_Globals(1)"));
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
         static bool testerStopped = false;
         if (IsTesting() && !testerStopped) {                                    // stop the tester in case of errors
            Tester.Stop("start(1)");                                             // covers errors in init(), too
            testerStopped = true;
         }
      }
      return(last_error);
   }

   // resolve tick status
   Tick++;                                                                       // simple counter, the value is meaningless
   Tick.time = MarketInfo(Symbol(), MODE_TIME);
   static int lastVolume;
   if      (!Volume[0] || !lastVolume) Tick.isVirtual = true;
   else if ( Volume[0] ==  lastVolume) Tick.isVirtual = true;
   else                                Tick.isVirtual = false;
   lastVolume    = Volume[0];
   ChangedBars   = -1;                                                           // in experts not available
   UnchangedBars = -1; ValidBars = UnchangedBars;                                // ...
   ShiftedBars   = -1;                                                           // ...

   // if called after init() check it's return value
   if (__CoreFunction == CF_INIT) {
      __CoreFunction = ec_SetProgramCoreFunction(__ExecutionContext, CF_START);  // __STATUS_OFF is FALSE here, but an error may be set

      if (last_error == ERS_TERMINAL_NOT_YET_READY) {
         logInfo("start(2)  init() returned ERS_TERMINAL_NOT_YET_READY, retrying...");
         last_error = NO_ERROR;

         int error = init();                                                     // call init() again
         if (__STATUS_OFF) return(last_error);

         if (error == ERS_TERMINAL_NOT_YET_READY) {                              // again an error may be set, reset __CoreFunction and wait for the next tick
            __CoreFunction = ec_SetProgramCoreFunction(__ExecutionContext, CF_INIT);
            return(ShowStatus(error));
         }
      }
      last_error = NO_ERROR;                                                     // init() was successful => reset error
   }
   else {
      prev_error = last_error;                                                   // a regular tick: backup last_error and reset it
      ec_SetDllError(__ExecutionContext, SetLastError(NO_ERROR));
   }

   // check a finished chart initialization (may fail on terminal start)
   if (!Bars) return(ShowStatus(SetLastError(logInfo("start(3)  Bars=0", ERS_TERMINAL_NOT_YET_READY))));

   // tester: wait until a configured start time/price is reached
   if (IsTesting()) {
      if (Test.StartTime != 0) {
         static string startTime=""; if (!StringLen(startTime)) startTime = TimeToStr(Test.StartTime, TIME_FULL);
         if (Tick.time < Test.StartTime) {
            Comment(NL, NL, NL, "Test: starting at ", startTime);
            return(last_error);
         }
         Test.StartTime = 0;
      }
      if (Test.StartPrice != 0) {
         static string startPrice=""; if (!StringLen(startPrice)) startPrice = NumberToStr(Test.StartPrice, PriceFormat);
         static double test.lastPrice; if (!test.lastPrice) {
            test.lastPrice = Bid;
            Comment(NL, NL, NL, "Test: starting at ", startPrice);
            return(last_error);
         }
         if (LT(test.lastPrice, Test.StartPrice)) /*&&*/ if (LT(Bid, Test.StartPrice)) {
            test.lastPrice = Bid;
            Comment(NL, NL, NL, "Test: starting at ", startPrice);
            return(last_error);
         }
         if (GT(test.lastPrice, Test.StartPrice)) /*&&*/ if (GT(Bid, Test.StartPrice)) {
            test.lastPrice = Bid;
            Comment(NL, NL, NL, "Test: starting at ", startPrice);
            return(last_error);
         }
         Test.StartPrice = 0;
      }
   }

   // online: check tick value if INIT_PIPVALUE is configured
   else {
      if (__ExecutionContext[EC.programInitFlags] & INIT_PIPVALUE && 1) {  // on "Market Watch" -> "Context menu" -> "Hide all" all symbols are unsubscribed
         if (!MarketInfo(Symbol(), MODE_TICKVALUE)) {                      // and the used ones re-subscribed (for a moment: tickvalue = 0 and no error)
            error = GetLastError();
            if (error != NO_ERROR) {
               if (CheckErrors("start(4)", error)) return(last_error);
            }
            return(ShowStatus(SetLastError(logInfo("start(5)  MarketInfo("+ Symbol() +", MODE_TICKVALUE=0)", ERS_TERMINAL_NOT_YET_READY))));
         }
      }
   }

   ArrayCopyRates(__rates);

   if (SyncMainContext_start(__ExecutionContext, __rates, Bars, ChangedBars, Tick, Tick.time, Bid, Ask) != NO_ERROR) {
      if (CheckErrors("start(6)")) return(last_error);
   }

   // initialize PL recorder
   if (!recorder.initialized) {
      if (!init_Recorder()) return(_last_error(CheckErrors("start(7)")));
   }

   // initialize test
   if (!test.initialized) {
      if (!init_Test()) return(_last_error(CheckErrors("start(8)")));
   }

   // call the userland main function
   error = onTick();
   if (error && error!=last_error) catch("start(9)", error);

   // record PL
   if (EA.Recorder) {
      if (!start_Recorder()) return(_last_error(CheckErrors("start(10)")));
   }

   // check all errors
   error = GetLastError();
   if (error || last_error|__ExecutionContext[EC.mqlError]|__ExecutionContext[EC.dllError])
      return(_last_error(CheckErrors("start(11)", error)));
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
   if (error != NULL) return(CheckErrors("deinit(1)") + LeaveContext(__ExecutionContext));

   error = catch("deinit(2)");                     // detect errors causing a full execution stop, e.g. ERR_ZERO_DIVIDE

   // remove a virtual ticker
   if (__tickTimerId != NULL) {
      int tmp = __tickTimerId;
      __tickTimerId = NULL;
      if (!RemoveTickTimer(tmp)) logError("deinit(3)->RemoveTickTimer(timerId="+ tmp +") failed", ERR_RUNTIME_ERROR);
   }

   // close open history sets of the PL recorder
   int size = ArraySize(recorder.hSet);
   for (int i=0; i < size; i++) {
      if (recorder.hSet[i] > 0) {
         tmp = recorder.hSet[i];
         recorder.hSet[i] = NULL;
         if      (i <  7) { if (!HistorySet1.Close(tmp)) return(CheckErrors("deinit(4)") + LeaveContext(__ExecutionContext)); }
         else if (i < 14) { if (!HistorySet2.Close(tmp)) return(CheckErrors("deinit(5)") + LeaveContext(__ExecutionContext)); }
         else             { if (!HistorySet3.Close(tmp)) return(CheckErrors("deinit(6)") + LeaveContext(__ExecutionContext)); }
      }
   }

   // stop external reporting
   if (EA.ExternalReporting) {
      datetime time = MarketInfo(Symbol(), MODE_TIME);
      Test_StopReporting(__ExecutionContext, time, Bars);
   }

   // Execute user-specific deinit() handlers. Execution stops if a handler returns with an error.
   //
   if (!error) error = onDeinit();                                      // preprocessing hook
   if (!error) {                                                        //
      switch (UninitializeReason()) {                                   //
         case UR_PARAMETERS : error = onDeinitParameters();    break;   // reason-specific handlers
         case UR_CHARTCHANGE: error = onDeinitChartChange();   break;   //
         case UR_ACCOUNT    : error = onDeinitAccountChange(); break;   //
         case UR_CHARTCLOSE : error = onDeinitChartClose();    break;   //
         case UR_UNDEFINED  : error = onDeinitUndefined();     break;   //
         case UR_REMOVE     : error = onDeinitRemove();        break;   //
         case UR_RECOMPILE  : error = onDeinitRecompile();     break;   //
         // terminal builds > 509                                       //
         case UR_TEMPLATE   : error = onDeinitTemplate();      break;   //
         case UR_INITFAILED : error = onDeinitFailed();        break;   //
         case UR_CLOSE      : error = onDeinitClose();         break;   //
                                                                        //
         default:                                                       //
            error = ERR_ILLEGAL_STATE;                                  //
            catch("deinit(7)  unknown UninitializeReason: "+ UninitializeReason(), error);
      }                                                                 //
   }                                                                    //
   if (!error) error = afterDeinit();                                   // postprocessing hook

   if (!IsTesting()) DeleteRegisteredObjects();

   return(CheckErrors("deinit(8)") + LeaveContext(__ExecutionContext));
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
 * @param  string caller           - location identifier of the caller
 * @param  int    error [optional] - error to enforce (default: none)
 *
 * @return bool - whether the flag __STATUS_OFF is set
 */
bool CheckErrors(string caller, int error = NULL) {
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
   if (error != NO_ERROR) {
      catch(caller, error);                                          // catch() calls SetLastError() which calls CheckErrors() again
   }                                                                 // which updates __STATUS_OFF accordingly

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
 * Initialize the PL recorder. Called on the first tick.
 *
 * @return bool - success status
 */
bool init_Recorder() {
   if (EA.Recorder && !recorder.initialized && !IsOptimization()) {
      string symbol="", symbolDescr="", symbolGroup="", hstDirectory="", baseCurrency="", marginCurrency="";
      int symbolDigits, hstFormat, size, i=0;

      // fetch symbol definitions from the EA instance
      while (Recorder_GetSymbolDefinitionA(i, symbol, symbolDescr, symbolGroup, symbolDigits, hstDirectory, hstFormat)) {
         size = i + 1;
         ArrayResize(recorder.symbol,       size);
         ArrayResize(recorder.symbolDescr,  size);
         ArrayResize(recorder.symbolGroup,  size);
         ArrayResize(recorder.symbolDigits, size);
         ArrayResize(recorder.hstDirectory, size);
         ArrayResize(recorder.hstFormat,    size);
         ArrayResize(recorder.hSet,         size);
         ArrayResize(recorder.startValue,   size);
         ArrayResize(recorder.currValue,    size);

         recorder.symbol      [i] = symbol;
         recorder.symbolDescr [i] = symbolDescr;
         recorder.symbolGroup [i] = symbolGroup;
         recorder.symbolDigits[i] = symbolDigits;
         recorder.hstDirectory[i] = hstDirectory;
         recorder.hstFormat   [i] = hstFormat;
         recorder.hSet        [i] = NULL;
         recorder.startValue  [i] = NULL;
         recorder.currValue   [i] = NULL;
         i++;
      }

      // if no definitions received but the recorder is enabled: use default values for 1 equity symbol
      if (!i) {
         // read history directory configuration
         string section = ifString(IsTesting(), "Tester.", "") +"EA.Recorder";
         hstDirectory = GetConfigString(section, "HistoryDirectory", "");
         if (!StringLen(hstDirectory))                     return(!catch("init_Recorder(1)  missing config value ["+ section +"]->HistoryDirectory", ERR_INVALID_CONFIG_VALUE));
         if (IsAbsolutePath(hstDirectory))                 return(!catch("init_Recorder(2)  illegal config value ["+ section +"]->HistoryDirectory: "+ DoubleQuoteStr(hstDirectory) +" (not an allowed directory name)", ERR_INVALID_CONFIG_VALUE));
         int illegalChars[] = {':', '*', '?', '"', '<', '>', '|'};
         if (StrContainsChars(hstDirectory, illegalChars)) return(!catch("init_Recorder(3)  invalid config value ["+ section +"]->HistoryDirectory: "+ DoubleQuoteStr(hstDirectory) +" (not a valid directory name)", ERR_INVALID_CONFIG_VALUE));
         hstDirectory = StrReplace(hstDirectory, "\\", "/");
         if (StrStartsWith(hstDirectory, "/"))             return(!catch("init_Recorder(4)  invalid config value ["+ section +"]->HistoryDirectory: "+ DoubleQuoteStr(hstDirectory) +" (must not start with a slash)", ERR_INVALID_CONFIG_VALUE));

         // read history format configuration
         hstFormat = GetConfigInt(section, "HistoryFormat", 401);
         if (hstFormat!=400 && hstFormat!=401)             return(!catch("init_Recorder(5)  invalid config value ["+ section +"]->HistoryFormat: "+ hstFormat +" (must be 400 or 401)", ERR_INVALID_CONFIG_VALUE));

         // create a new symbol
         symbol         = init_RecorderSymbol(hstDirectory);
         symbolGroup    = StrLeft(ProgramName(), MAX_SYMBOL_GROUP_LENGTH);                        // sizeof(SYMBOL.description) = 64 chars
         symbolDescr    = StrLeft(ProgramName(), 43) +" "+ LocalTimeFormat(GetGmtTime(), "%d.%m.%Y %H:%M:%S");   // 43 + 1 + 19 = 63 chars
         symbolDigits   = 2;
         baseCurrency   = AccountCurrency();
         marginCurrency = AccountCurrency();

         if (CreateRawSymbol(symbol, symbolDescr, symbolGroup, symbolDigits, baseCurrency, marginCurrency, hstDirectory) < 0) return(false);

         recorder.symbol      [0] = symbol;
         recorder.symbolDescr [0] = symbolDescr;
         recorder.symbolGroup [0] = symbolGroup;
         recorder.symbolDigits[0] = symbolDigits;
         recorder.hstDirectory[0] = hstDirectory;
         recorder.hstFormat   [0] = hstFormat;
         recorder.hSet        [0] = NULL;
         recorder.startValue  [0] = NormalizeDouble(AccountEquity()-AccountCredit(), symbolDigits);
         recorder.currValue   [0] = NULL;
      }
   }
   else {
      EA.Recorder = false;
   }

   recorder.initialized = true;
   return(true);
}


/**
 * Create a default recorder symbol for this instance. Called from init_Recorder() if EA.Recorder is TRUE.
 *
 * @param  string hstDirectory - history directory to use
 *
 * @return string - symbol or an empty string in case of errors
 */
string init_RecorderSymbol(string hstDirectory) {
   // open "symbols.raw" and read symbols
   string filename = hstDirectory +"/symbols.raw";
   int hFile = FileOpen(filename, FILE_READ|FILE_BIN);
   int error = GetLastError();
   if (error || hFile <= 0)                              return(!catch("init_RecorderSymbol(1)->FileOpen(\""+ filename +"\", FILE_READ) => "+ hFile, intOr(error, ERR_RUNTIME_ERROR)));

   int fileSize = FileSize(hFile);
   if (fileSize % SYMBOL_size != 0) { FileClose(hFile);  return(!catch("init_RecorderSymbol(2)  invalid size of \""+ filename +"\" (not an even SYMBOL size, "+ (fileSize % SYMBOL_size) +" trailing bytes)", intOr(GetLastError(), ERR_RUNTIME_ERROR))); }
   int symbolsSize = fileSize/SYMBOL_size;

   int symbols[]; InitializeByteBuffer(symbols, fileSize);
   if (fileSize > 0) {
      int ints = FileReadArray(hFile, symbols, 0, fileSize/4);
      error = GetLastError();
      if (error || ints!=fileSize/4) { FileClose(hFile); return(!catch("init_RecorderSymbol(3)  error reading \""+ filename +"\" ("+ (ints*4) +" of "+ fileSize +" bytes read)", intOr(error, ERR_RUNTIME_ERROR))); }
   }
   FileClose(hFile);

   // iterate over all symbols and determine the next available one matching "{ExpertName}.{001-xxx}"
   string suffix="", name=StrLeft(StrReplace(ProgramName(), " ", ""), 7) +".";

   for (int i, maxId=0; i < symbolsSize; i++) {
      string symbol = symbols_Name(symbols, i);
      if (StrStartsWithI(symbol, name)) {
         suffix = StrSubstr(symbol, StringLen(name));
         if (StringLen(suffix)==3) /*&&*/ if (StrIsDigit(suffix)) {
            maxId = Max(maxId, StrToInteger(suffix));
         }
      }
   }
   return(name + StrPadLeft(""+ (maxId+1), 3, "0"));
}


/**
 * Called at the first tick of a test. Initializes external reporting.
 *
 * @return bool - success status
 */
bool init_Test() {
   if (EA.ExternalReporting && IsTesting()) {
      datetime time = MarketInfo(Symbol(), MODE_TIME);
      Test_InitReporting(__ExecutionContext, time, Bars);
   }
   else {
      EA.ExternalReporting = false;
   }
   test.initialized = true;
   return(true);
}


/**
 * Return current MarketInfo() data.
 *
 * @return string - MarketInfo() data or an empty string in case of errors
 */
string init_MarketInfo() {
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

   if (!catch("init_MarketInfo(1)"))
      return(message);
   return("");
}


/**
 * Record an expert's PL metrics.
 *
 * @return bool - success status
 */
bool start_Recorder() {
   /*
    Speed test SnowRoller EURUSD,M15  04.10.2012, long, GridSize 18
   +-----------------------------+--------------+-----------+--------------+-------------+-------------+--------------+--------------+--------------+
   | Toshiba Satellite           |     old      | optimized | FindBar opt. | Arrays opt. |  Read opt.  |  Write opt.  |  Valid. opt. |  in Library  |
   +-----------------------------+--------------+-----------+--------------+-------------+-------------+--------------+--------------+--------------+
   | v419 - w/o start_Recorder() | 17.613 t/sec |           |              |             |             |              |              |              |
   | v225 - HST_BUFFER_TICKS=Off |  6.426 t/sec |           |              |             |             |              |              |              |
   | v419 - HST_BUFFER_TICKS=Off |  5.871 t/sec | 6.877 t/s |   7.381 t/s  |  7.870 t/s  |  9.097 t/s  |   9.966 t/s  |  11.332 t/s  |              |
   | v419 - HST_BUFFER_TICKS=On  |              |           |              |             |             |              |  15.486 t/s  |  14.286 t/s  |
   +-----------------------------+--------------+-----------+--------------+-------------+-------------+--------------+--------------+--------------+
   */
   int size = ArraySize(recorder.hSet);

   for (int i=0; i < size; i++) {
      if (!recorder.hSet[i]) {
         if (i < 7) {
            recorder.hSet[i] = HistorySet1.Create(recorder.symbol[i], recorder.symbolDescr[i], recorder.symbolDigits[i], recorder.hstFormat[i], recorder.hstDirectory[i]); if (!recorder.hSet[i]) return(false);
            if (!i) /*&&*/ if (!recorder.currValue[i]) recorder.currValue[i] = AccountEquity()-AccountCredit();
            if (!HistorySet1.AddTick(recorder.hSet[i], Tick.time, recorder.currValue[i], HST_BUFFER_TICKS)) return(false);
         }
         else if (i < 14) {
            recorder.hSet[i] = HistorySet2.Create(recorder.symbol[i], recorder.symbolDescr[i], recorder.symbolDigits[i], recorder.hstFormat[i], recorder.hstDirectory[i]); if (!recorder.hSet[i]) return(false);
            if (!HistorySet2.AddTick(recorder.hSet[i], Tick.time, recorder.currValue[i], HST_BUFFER_TICKS)) return(false);
         }
         else {
            recorder.hSet[i] = HistorySet3.Create(recorder.symbol[i], recorder.symbolDescr[i], recorder.symbolDigits[i], recorder.hstFormat[i], recorder.hstDirectory[i]); if (!recorder.hSet[i]) return(false);
            if (!HistorySet3.AddTick(recorder.hSet[i], Tick.time, recorder.currValue[i], HST_BUFFER_TICKS)) return(false);
         }
      }
   }
   return(true);
}


#import "rsfLib.ex4"
   int    CreateRawSymbol(string name, string description, string group, int digits, string baseCurrency, string marginCurrency, string directory);
   bool   IntInArray(int haystack[], int needle);

#import "rsfMT4Expander.dll"
   int    ec_SetDllError           (int ec[], int error   );
   int    ec_SetProgramCoreFunction(int ec[], int function);

   string symbols_Name(/*SYMBOL*/int symbols[], int i);

   int    SyncMainContext_init  (int ec[], int programType, string programName, int uninitReason, int initFlags, int deinitFlags, string symbol, int timeframe, int digits, double point, int eaExternalReporting, int eaRecorder, int isTesting, int isVisualMode, int isOptimization, int lpSec, int hChart, int droppedOnChart, int droppedOnPosX, int droppedOnPosY);
   int    SyncMainContext_start (int ec[], double rates[][], int bars, int changedBars, int ticks, datetime time, double bid, double ask);
   int    SyncMainContext_deinit(int ec[], int uninitReason);

   bool   Test_InitReporting  (int ec[], datetime from, int bars);
   bool   Test_onPositionOpen (int ec[], int ticket, int type, double lots, string symbol, datetime openTime, double openPrice, double stopLoss, double takeProfit, double commission, int magicNumber, string comment);
   bool   Test_onPositionClose(int ec[], int ticket, datetime closeTime, double closePrice, double swap, double profit);
   bool   Test_StopReporting  (int ec[], datetime to, int bars);

#import "rsfHistory1.ex4"
   int    HistorySet1.Create (string symbol, string description, int digits, int format, string directory);
   bool   HistorySet1.AddTick(int hSet, datetime time, double value, int flags);
   bool   HistorySet1.Close  (int hSet);

#import "rsfHistory2.ex4"
   int    HistorySet2.Create (string symbol, string description, int digits, int format, string directory);
   bool   HistorySet2.AddTick(int hSet, datetime time, double value, int flags);
   bool   HistorySet2.Close  (int hSet);

#import "rsfHistory3.ex4"
   int    HistorySet3.Create (string symbol, string description, int digits, int format, string directory);
   bool   HistorySet3.AddTick(int hSet, datetime time, double value, int flags);
   bool   HistorySet3.Close  (int hSet);

#import "user32.dll"
   int    SendMessageA(int hWnd, int msg, int wParam, int lParam);
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
 * Online: Called in terminal builds <= 509 when a new chart template is applied.
 *         Called when the chart profile changes.
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
 * Online: Called in terminal builds > 509 when a new chart template is applied.
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
