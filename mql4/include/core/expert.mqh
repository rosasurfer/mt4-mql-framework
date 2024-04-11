
#define __lpSuperContext NULL
int     __CoreFunction = NULL;                                    // currently executed MQL core function: CF_INIT|CF_START|CF_DEINIT
double  __rates[][6];                                             // current price series
int     __tickTimerId;                                            // timer id for virtual ticks
int     recorder.mode;                                            // EA recorder settings
double  _Bid;                                                     // normalized versions of predefined vars Bid/Ask
double  _Ask;                                                     // ...


/**
 * Global init() function for experts.
 *
 * @return int - error status
 */
int init() {
   __isSuperContext = false;

   if (__STATUS_OFF) {                                            // TODO: process ERR_INVALID_INPUT_PARAMETER (enable re-input)
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

   if (__CoreFunction != CF_START) {                              // init() is called by the terminal
      __CoreFunction = CF_INIT;
      prev_error   = last_error;
      ec_SetDllError(__ExecutionContext, SetLastError(NO_ERROR));
   }
   _Bid = NormalizeDouble(Bid, Digits);                           // normalized versions of Bid/Ask
   _Ask = NormalizeDouble(Ask, Digits);                           //

   // initialize the execution context
   int hChart = NULL; if (!IsTesting() || IsVisualMode()) {       // in tester WindowHandle() triggers ERR_FUNC_NOT_ALLOWED_IN_TESTER if VisualMode=Off
       hChart = WindowHandle(Symbol(), NULL);
   }
   int initFlags=SumInts(__InitFlags), deinitFlags=SumInts(__DeinitFlags), recorderMode=NULL;

   int error = SyncMainContext_init(__ExecutionContext, MT_EXPERT, WindowExpertName(), UninitializeReason(), initFlags, deinitFlags, Symbol(), Period(), Digits, Point, recorderMode, IsTesting(), IsVisualMode(), IsOptimization(), __lpSuperContext, hChart, WindowOnDropped(), WindowXOnDropped(), WindowYOnDropped());
   if (!error) error = GetLastError();                            // detect a DLL exception
   if (IsError(error)) {
      ForceAlert("ERROR:   "+ Symbol() +","+ PeriodDescription() +"  "+ WindowExpertName() +"::init(2)->SyncMainContext_init()  ["+ ErrorToStr(error) +"]");
      last_error          = error;
      __STATUS_OFF        = true;                                 // If SyncMainContext_init() failed the content of the EXECUTION_CONTEXT
      __STATUS_OFF.reason = last_error;                           // is undefined. We must not trigger loading of MQL libraries and return asap.
      return(last_error);
   }

   // finish initialization of global vars
   if (!initGlobals()) if (CheckErrors("init(3)")) return(last_error);

   // execute custom init tasks
   initFlags = __ExecutionContext[EC.programInitFlags];
   if (initFlags & INIT_TIMEZONE && 1) {
      if (!StringLen(GetServerTimezone()))  return(_last_error(CheckErrors("init(4)")));
   }
   if (initFlags & INIT_PIPVALUE && 1) {
      double tickSize = MarketInfo(Symbol(), MODE_TICKSIZE);      // fails if there is no tick yet
      error = GetLastError();
      if (IsError(error)) {                                       // symbol not yet subscribed (start, account/template change), it may appear later
         if (error == ERR_SYMBOL_NOT_AVAILABLE)                   // synthetic symbol in offline chart
            return(logInfo("init(5)  MarketInfo(MODE_TICKSIZE) => ERR_SYMBOL_NOT_AVAILABLE", SetLastError(ERS_TERMINAL_NOT_YET_READY)));
         if (CheckErrors("init(6)", error)) return(last_error);
      }
      if (!tickSize) return(logInfo("init(7)  MarketInfo(MODE_TICKSIZE=0)", SetLastError(ERS_TERMINAL_NOT_YET_READY)));

      double tickValue = MarketInfo(Symbol(), MODE_TICKVALUE);
      error = GetLastError();
      if (IsError(error)) /*&&*/ if (CheckErrors("init(8)", error)) return(last_error);
      if (!tickValue) return(logInfo("init(9)  MarketInfo(MODE_TICKVALUE=0)", SetLastError(ERS_TERMINAL_NOT_YET_READY)));
   }
   if (initFlags & INIT_BARS_ON_HIST_UPDATE && 1) {}              // not yet implemented

   // enable experts if they are disabled                         // @see  https://www.mql5.com/en/code/29022#    [Disable auto trading for one EA]
   int reasons1[] = {UR_UNDEFINED, UR_CHARTCLOSE, UR_REMOVE};
   if (!__isTesting) /*&&*/ if (!IsExpertEnabled()) /*&&*/ if (IntInArray(reasons1, UninitializeReason())) {
      error = Toolbar.Experts(true);                              // TODO: fails if multiple experts try it at the same time (e.g. at terminal start)
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

   if (__isTesting) {
      Test.GetStartDate();                                        // populate date caches to prevent UI deadlocks if called in deinit()
      Test.GetEndDate();
      if (IsLogInfo()) {                                          // log MarketInfo() data
         string title = " ::: TEST ("+ BarModelDescription(__Test.barModel) +") :::";
         string msg = initHandlers[initReason] +"(0)  MarketInfo: "+ initMarketInfo();
         string separator = StrRepeat(":", StringLen(msg));
         if (__isTesting) separator = title + StrRight(separator, -StringLen(title));
         logInfo(separator);
         logInfo(msg);
      }
   }
   else if (UninitializeReason() != UR_CHARTCHANGE) {             // log account infos (this becomes the first regular online log entry)
      if (IsLogInfo()) {
         msg = initHandlers[initReason] +"(0)  "+ GetAccountServer() +", account "+ account +" ("+ ifString(IsDemoFix(), "demo", "real") +")";
         logInfo(StrRepeat(":", StringLen(msg)));
         logInfo(msg);
      }
   }

   if (UninitializeReason() != UR_CHARTCHANGE) {                  // log input parameters
      if (IsLogInfo()) {
         string inputs = InputsToStr();
         if (inputs != "") {
            string inputRecorder = Recorder_GetInput();
            if (inputRecorder != "") inputRecorder = NL +"EA.Recorder=\""+ inputRecorder +"\";";
            logInfo(initHandlers[initReason] +"(0)  inputs: "+ inputs + inputRecorder);
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
   error = onInit();                                                       // preprocessing hook
                                                                           //
   if (!error && !__STATUS_OFF) {                                          //
      switch (initReason) {                                                //
         case IR_USER            : error = onInitUser();            break; // init reasons
         case IR_TEMPLATE        : error = onInitTemplate();        break; //
         case IR_PARAMETERS      : error = onInitParameters();      break; //
         case IR_TIMEFRAMECHANGE : error = onInitTimeframeChange(); break; //
         case IR_SYMBOLCHANGE    : error = onInitSymbolChange();    break; //
         case IR_RECOMPILE       : error = onInitRecompile();       break; //
         case IR_TERMINAL_FAILURE:                                         //
         default:                                                          //
            return(_last_error(CheckErrors("init(13)  unsupported initReaso"+ initReason, ERR_RUNTIME_ERROR)));
      }                                                                    //
   }                                                                       //
   if (error == ERS_TERMINAL_NOT_YET_READY) return(error);                 //
                                                                           //
   if (!error && !__STATUS_OFF)                                            //
      afterInit();                                                         // postprocessing hook

   if (CheckErrors("init(14)")) return(last_error);
   ShowStatus(last_error);

   // setup virtual ticks
   if (__virtualTicks && !__isTesting) {
      int hWnd = __ExecutionContext[EC.hChart];
      __tickTimerId = SetupTickTimer(hWnd, __virtualTicks, NULL);
      if (!__tickTimerId) return(catch("init(15)->SetupTickTimer(hWnd="+ IntToHexStr(hWnd) +") failed", ERR_RUNTIME_ERROR));
   }

   // immediately send a virtual tick, except on UR_CHARTCHANGE
   if (UninitializeReason() != UR_CHARTCHANGE)                             // At the very end, otherwise the window message queue may be processed
      Chart.SendTick();                                                    // before this function is left and the tick might get lost.
   return(last_error);
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
         if (__isTesting && !testerStopped) {                              // stop the tester in case of errors
            Tester.Stop("start(1)");                                       // covers errors in init(), too
            testerStopped = true;
         }
      }
      return(last_error);
   }
   _Bid = NormalizeDouble(Bid, Digits);                                    // normalized versions of Bid/Ask
   _Ask = NormalizeDouble(Ask, Digits);                                    //

   // resolve tick status
   Ticks++;                                                                // simple counter, the value is meaningless
   Tick.time = MarketInfo(Symbol(), MODE_TIME);
   static int lastVolume;
   if      (!Volume[0] || !lastVolume) Tick.isVirtual = true;
   else if ( Volume[0] ==  lastVolume) Tick.isVirtual = true;
   else                                Tick.isVirtual = false;
   lastVolume  = Volume[0];
   ChangedBars = -1;                                                       // in experts not available
   ValidBars   = -1;                                                       // ...
   ShiftedBars = -1;                                                       // ...

   // if called after init() check it's return value
   if (__CoreFunction == CF_INIT) {
      __CoreFunction = ec_SetProgramCoreFunction(__ExecutionContext, CF_START);

      // check initialization result: ERS_TERMINAL_NOT_YET_READY is the only error causing a repeated init() call
      if (last_error == ERS_TERMINAL_NOT_YET_READY) {
         logInfo("start(2)  init() returned ERS_TERMINAL_NOT_YET_READY, retrying...");
         prev_error = last_error;
         ec_SetDllError(__ExecutionContext, SetLastError(NO_ERROR));

         int error = init();                                               // call init() again
         if (__STATUS_OFF) return(last_error);

         if (error == ERS_TERMINAL_NOT_YET_READY) {                        // restore CF_INIT and wait for the next tick
            __CoreFunction = ec_SetProgramCoreFunction(__ExecutionContext, CF_INIT);
            return(ShowStatus(error));
         }
      }
      last_error = NO_ERROR;                                               // init() was successful => reset error
   }
   else {
      prev_error = last_error;                                             // a regular tick: backup last_error and reset it
      ec_SetDllError(__ExecutionContext, SetLastError(NO_ERROR));
   }

   // check a finished chart initialization (spurious issue which was observed on older terminals at terminal start)
   if (!Bars) return(ShowStatus(SetLastError(logInfo("start(3)  Bars=0", ERS_TERMINAL_NOT_YET_READY))));

   // check tick value if configured
   if (__ExecutionContext[EC.programInitFlags] & INIT_PIPVALUE && 1) {     // on "Market Watch" -> "Context menu" -> "Hide all" all symbols are unsubscribed
      if (!MarketInfo(Symbol(), MODE_TICKVALUE)) {                         // and the used ones re-subscribed (for a moment: tickvalue = 0 and no error)
         error = GetLastError();
         if (error != NO_ERROR) {
            if (CheckErrors("start(4)", error)) return(last_error);
         }
         return(ShowStatus(SetLastError(logInfo("start(5)  MarketInfo("+ Symbol() +", MODE_TICKVALUE=0)", ERS_TERMINAL_NOT_YET_READY))));
      }
   }

   ArrayCopyRates(__rates);

   if (SyncMainContext_start(__ExecutionContext, __rates, Bars, ChangedBars, Ticks, Tick.time, Bid, Ask) != NO_ERROR) {
      if (CheckErrors("start(6)->SyncMainContext_start()")) return(last_error);
   }

   // call the userland main function
   error = onTick();
   if (error && error!=last_error) CheckErrors("start(7)", error);

   // record performance metrics
   if (recorder.mode != NULL) {
      if (!Recorder_start()) {
         recorder.mode = NULL;
         return(_last_error(CheckErrors("start(8)->Recorder_start()")));
      }
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
 * functions "at will" without finishing them. This is different from the regular execution timeout of 3 seconds in init
 * cycles. The hard interruption may occur already after a few 100 milliseconds, Expert::afterDeinit() may not get executed.
 * The workaround is to not execute time-consuming tasks in deinit(). Instead move expensive work to the Expander (possibly
 * in its own thread). Always write status changes to disk as they happen to prevent data loss.
 */
int deinit() {
   __CoreFunction = CF_DEINIT;
   _Bid = NormalizeDouble(Bid, Digits);            // normalized versions of Bid/Ask
   _Ask = NormalizeDouble(Ask, Digits);            //

   if (!IsDllsAllowed() || !IsLibrariesAllowed() || last_error==ERR_TERMINAL_INIT_FAILURE || last_error==ERR_DLL_EXCEPTION)
      return(last_error);

   if (SyncMainContext_deinit(__ExecutionContext, UninitializeReason()) != NO_ERROR) {
      return(CheckErrors("deinit(1)->SyncMainContext_deinit()") + LeaveContext(__ExecutionContext));
   }

   int error = catch("deinit(2)");                 // detect errors causing a full execution stop, e.g. ERR_ZERO_DIVIDE

   // remove a virtual ticker
   if (__tickTimerId != NULL) {
      int tmp = __tickTimerId;
      __tickTimerId = NULL;
      if (!ReleaseTickTimer(tmp)) logError("deinit(3)->ReleaseTickTimer(timerId="+ tmp +") failed", ERR_RUNTIME_ERROR);
   }

   // close a running recorder
   if (recorder.mode != NULL) Recorder_deinit();

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
            catch("deinit(4)  unknown UninitializeReason: "+ UninitializeReason(), error);
      }                                                                 //
   }                                                                    //
   if (!error) error = afterDeinit();                                   // postprocessing hook

   if (!__isTesting) DeleteRegisteredObjects();

   return(CheckErrors("deinit(5)") + LeaveContext(__ExecutionContext));
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
 * @param  int    error [optional] - enforced error (default: none)
 *
 * @return bool - whether the flag __STATUS_OFF is set
 */
bool CheckErrors(string caller, int error = NULL) {
   // check DLL errors
   int dll_error = __ExecutionContext[EC.dllError];
   if (dll_error != NO_ERROR) {                             // all DLL errors are terminating errors
      if (dll_error != __STATUS_OFF.reason)                 // prevent recursion errors
         logFatal(caller +"  DLL error", dll_error);        // signal the error but don't overwrite MQL last_error
      __STATUS_OFF        = true;
      __STATUS_OFF.reason = dll_error;
   }

   // check the program's MQL error
   int mql_error = __ExecutionContext[EC.mqlError];         // may have bubbled up from an MQL library
   switch (mql_error) {
      case NO_ERROR:
      case ERS_HISTORY_UPDATE:
      case ERS_TERMINAL_NOT_YET_READY:
      case ERS_EXECUTION_STOPPING:
         break;
      default:
         __STATUS_OFF        = true;
         __STATUS_OFF.reason = mql_error;                   // MQL errors have higher severity than DLL errors
   }

   // check the module's MQL error (if set it should match EC.mqlError)
   switch (last_error) {
      case NO_ERROR:
      case ERS_HISTORY_UPDATE:
      case ERS_TERMINAL_NOT_YET_READY:
      case ERS_EXECUTION_STOPPING:
         break;
      default:
         __STATUS_OFF        = true;
         __STATUS_OFF.reason = last_error;                  // main module errors have higher severity than library errors
   }

   // check enforced or uncatched errors
   if (!error) error = GetLastError();
   switch (error) {
      case NO_ERROR:
         break;
      case ERS_HISTORY_UPDATE:
      case ERS_TERMINAL_NOT_YET_READY:
      case ERS_EXECUTION_STOPPING:
         logInfo(caller, error);                            // don't SetLastError()
         break;
      default:
         if (error != __STATUS_OFF.reason)                  // prevent recursion errors
            catch(caller, error);                           // catch() calls SetLastError()
         __STATUS_OFF        = true;
         __STATUS_OFF.reason = error;
   }

   // update variable last_error
   if (__STATUS_OFF) {
      if (!last_error) last_error = __STATUS_OFF.reason;
      ShowStatus(last_error);                               // on error show status once again
   }
   return(__STATUS_OFF);

   // suppress compiler warnings
   __DummyCalls();
}


/**
 * Initialize/update global variables. Called immediately after SyncMainContext_init().
 *
 * @return bool - success status
 */
bool initGlobals() {
   __isChart       = (__ExecutionContext[EC.hChart] != 0);
   __isTesting     = IsTesting();
   __Test.barModel = ec_TestBarModel(__ExecutionContext);

   int digits = MathMax(Digits, 2);                         // treat Digits=1 as 2 (for some indices)
   HalfPoint      = Point/2;
   PipDigits      = digits & (~1);
   Pip            = NormalizeDouble(1/MathPow(10, PipDigits), PipDigits);
   PipPriceFormat = ",'R."+ PipDigits;
   PriceFormat    = ifString(digits==PipDigits, PipPriceFormat, PipPriceFormat +"'");

   if (digits > 2 || Close[0] < 1000) {
      pUnit   = Pip;
      pDigits = 1;                                          // always represent pips with subpips
      spUnit  = "pip";
   }
   else {
      pUnit   = 1.00;
      pDigits = 2;
      spUnit  = "point";
   }

   // don't use MathLog() as in terminals (build > 509 && build < 603) it fails to produce NaN/-INF
   INF = Math_INF();                                        // positive infinity
   NaN = INF-INF;                                           // not-a-number

   return(!catch("initGlobals(1)"));
}


/**
 * Return current MarketInfo() data. Called during initialization of a test.
 *
 * @return string - MarketInfo() data or an empty string in case of errors
 */
string initMarketInfo() {
   string message = "";

   datetime time           = MarketInfo(Symbol(), MODE_TIME);                  message = message + "Time="        + GmtTimeFormat(time, "%a, %d.%m.%Y %H:%M") +";";
                                                                               message = message +" Bars="        + Bars                                      +";";
   double   spread         = MarketInfo(Symbol(), MODE_SPREAD)*Point/Pip;      message = message +" Spread="      + DoubleToStr(spread, 1)                    +";";
                                                                               message = message +" Digits="      + Digits                                    +";";
   double   minLot         = MarketInfo(Symbol(), MODE_MINLOT);                message = message +" MinLot="      + NumberToStr(minLot, ".+")                 +";";
   double   lotStep        = MarketInfo(Symbol(), MODE_LOTSTEP);               message = message +" LotStep="     + NumberToStr(lotStep, ".+")                +";";
   double   stopLevel      = MarketInfo(Symbol(), MODE_STOPLEVEL)*Point/Pip;   message = message +" StopLevel="   + NumberToStr(stopLevel, ".+")              +";";
   double   freezeLevel    = MarketInfo(Symbol(), MODE_FREEZELEVEL)*Point/Pip; message = message +" FreezeLevel=" + NumberToStr(freezeLevel, ".+")            +";";
   double   tickSize       = MarketInfo(Symbol(), MODE_TICKSIZE);
   double   tickValue      = MarketInfo(Symbol(), MODE_TICKVALUE);
   double   marginRequired = MarketInfo(Symbol(), MODE_MARGINREQUIRED);
   double   lotValue       = MathDiv(Close[0], tickSize) * tickValue;          message = message +" Account="     + NumberToStr(AccountBalance(), ",'.0R") +" "+ AccountCurrency() +";";
   double   leverage       = MathDiv(lotValue, marginRequired);                message = message +" Leverage=1:"  + Round(leverage) +";";
   int      stopoutLevel   = AccountStopoutLevel();                            message = message +" Stopout="     + ifString(AccountStopoutMode()==MSM_PERCENT, stopoutLevel +"%", NumberToStr(stopoutLevel, ",,.0") +" "+ AccountCurrency()) +";";
   double   lotSize        = MarketInfo(Symbol(), MODE_LOTSIZE);
   double   marginHedged   = MarketInfo(Symbol(), MODE_MARGINHEDGED);
            marginHedged   = MathDiv(marginHedged, lotSize) * 100;             message = message +" MarginHedged="+ ifString(!marginHedged, "none", Round(marginHedged) +"%") +";";
   double   pipValue       = MathDiv(tickValue, MathDiv(tickSize, Pip));       message = message +" PipValue="    + NumberToStr(pipValue, "R.2+") +";";
   double   commission     = GetCommission();                                  message = message +" Commission="  + ifString(!commission, "0.00;", DoubleToStr(commission, 2));
   if (NE(commission, 0)) {
      double commissionP = MathDiv(commission, MathDiv(tickValue, tickSize));  message = message +" ("            + DoubleToStr(commissionP/pUnit, pDigits) +" "+ spUnit +");";
   }
   double   swapLong       = MarketInfo(Symbol(), MODE_SWAPLONG );
   double   swapShort      = MarketInfo(Symbol(), MODE_SWAPSHORT);             message = message +" Swap="        + ifString(swapLong||swapShort, NumberToStr(swapLong, ".+") +"/"+ NumberToStr(swapShort, ".+"), "0") +";";

   if (!catch("initMarketInfo(1)"))
      return(message);
   return("");
}


/**
 * Get the test start date selected in the tester.
 *
 * @return datetime - start date or NaT (Not-a-Time) in case of errors
 */
datetime Test.GetStartDate() {
   // The date is cached to prevent UI deadlocks in expert::deinit() if VisualMode=On, caused by Tester_GetStartDate()
   // calling GetWindowText().
   if (!__isTesting) return(_NaT(catch("Test.GetStartDate(1)  test-only function", ERR_FUNC_NOT_ALLOWED)));

   static datetime startdate;
   if (!startdate) startdate = Tester_GetStartDate();
   return(startdate);
}


/**
 * Get the test end date selected in the tester.
 *
 * @return datetime - end date or NaT (Not-a-Time) in case of errors
 */
datetime Test.GetEndDate() {
   // The date is cached to prevent UI deadlocks in expert::deinit() if VisualMode=On, caused by Tester_GetStartDate()
   // calling GetWindowText().
   if (!__isTesting) return(_NaT(catch("Test.GetEndDate(1)  test-only function", ERR_FUNC_NOT_ALLOWED)));

   static datetime enddate;
   if (!enddate) enddate = Tester_GetEndDate();
   return(enddate);
}


#import "rsfLib.ex4"
   int    CreateRawSymbol(string name, string description, string group, int digits, string baseCurrency, string marginCurrency, string directory);
   bool   IntInArray(int haystack[], int needle);

#import "rsfHistory1.ex4"
   int    HistorySet1.Get    (string symbol, string directory = "");
   int    HistorySet1.Create (string symbol, string description, int digits, int format, string directory);
   bool   HistorySet1.AddTick(int hSet, datetime time, double value, int flags);
   bool   HistorySet1.Close  (int hSet);

#import "rsfHistory2.ex4"
   int    HistorySet2.Get    (string symbol, string directory = "");
   int    HistorySet2.Create (string symbol, string description, int digits, int format, string directory);
   bool   HistorySet2.AddTick(int hSet, datetime time, double value, int flags);
   bool   HistorySet2.Close  (int hSet);

#import "rsfHistory3.ex4"
   int    HistorySet3.Get    (string symbol, string directory = "");
   int    HistorySet3.Create (string symbol, string description, int digits, int format, string directory);
   bool   HistorySet3.AddTick(int hSet, datetime time, double value, int flags);
   bool   HistorySet3.Close  (int hSet);

#import "rsfMT4Expander.dll"
   int    ec_TestBarModel          (int ec[]);
   int    ec_SetDllError           (int ec[], int error   );
   int    ec_SetProgramCoreFunction(int ec[], int function);
   int    ec_SetRecorderMode       (int ec[], int mode    );

   string Recorder_GetInput();                                    // Recorder functions in the Expander are no-ops to make
   string Recorder_GetNextMetricSymbol();                         // inclusion of "core/expert.recorder.mqh" optional.
   bool   Recorder_start();
   bool   Recorder_deinit();
   int    RecordMetrics();

   string symbols_Name(int symbols[], int i);

   int    SyncMainContext_init  (int ec[], int programType, string programName, int uninitReason, int initFlags, int deinitFlags, string symbol, int timeframe, int digits, double point, int recorderMode, int isTesting, int isVisualMode, int isOptimization, int lpSec, int hChart, int droppedOnChart, int droppedOnPosX, int droppedOnPosY);
   int    SyncMainContext_start (int ec[], double rates[][], int bars, int changedBars, int ticks, datetime time, double bid, double ask);
   int    SyncMainContext_deinit(int ec[], int uninitReason);

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
