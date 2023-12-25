/**
 * Vegas EA (work-in-progress, do not yet use)
 *
 * A hybrid strategy using ideas of the "Vegas H1 Tunnel" system, the system of the "Turtle Traders" and a grid.
 *
 *
 * Input parameters:
 * -----------------
 * • Instance.ID:  ...
 * • Donchian.Periods:  ...
 *
 *
 *  @see  [Vegas H1 Tunnel Method] https://www.forexfactory.com/thread/4365-all-vegas-documents-located-here
 *  @see  [Turtle Trading]         https://analyzingalpha.com/turtle-trading
 *  @see  [Duel Grid EA]           https://github.com/rosasurfer/mt4-mql/blob/master/mql4/experts/Duel.mq4
 */
#include <stddefines.mqh>
int   __InitFlags[] = {INIT_PIPVALUE, INIT_BUFFERED_LOG};
int __DeinitFlags[];
int __virtualTicks = 0;

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern string Instance.ID      = "";               // instance to load from a status file, format "T?[0-9]{3}"
extern int    Donchian.Periods = 30;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/expert.mqh>
#include <stdfunctions.mqh>
#include <rsfLib.mqh>
#include <functions/HandleCommands.mqh>
#include <functions/iCustom/MaTunnel.mqh>
#include <functions/iCustom/ZigZag.mqh>

#define STRATEGY_ID         108                    // unique strategy id (used for magic order numbers)
#define IID_MIN             100                    // min/max range of valid instance id values
#define IID_MAX             999

#define STATUS_WAITING        1                    // instance has no open positions and waits for trade signals
#define STATUS_PROGRESSING    2                    // instance manages open positions
#define STATUS_STOPPED        3                    // instance has no open positions and doesn't wait for trade signals

#define SIGNAL_LONG  TRADE_DIRECTION_LONG          // 1 signal types
#define SIGNAL_SHORT TRADE_DIRECTION_SHORT         // 2

// instance data
int      instance.id;                              // instance id (100-999, also used for magic order numbers)
datetime instance.created;
string   instance.name = "";
int      instance.status;
bool     instance.isTest;

// debug settings                                  // configurable via framework config, see afterInit()
bool     test.onStopPause        = false;          // whether to pause a test after a final StopInstance()
bool     test.reduceStatusWrites = true;           // whether to reduce status file writes in tester

#include <apps/vegas-ea/init.mqh>
#include <apps/vegas-ea/deinit.mqh>


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   if (!instance.status) return(ERR_ILLEGAL_STATE);

   if (__isChart) HandleCommands();                // process incoming commands

   if (instance.status != STATUS_STOPPED) {
      int zzSignal;
      IsZigZagSignal(zzSignal);                    // check on every tick (signals can occur anytime)

      if (instance.status == STATUS_WAITING) {
      }
      else if (instance.status == STATUS_PROGRESSING) {
      }
   }
   return(catch("onTick(1)"));
}


/**
 * Process an incoming command.
 *
 * @param  string cmd    - command name
 * @param  string params - command parameters
 * @param  int    keys   - pressed modifier keys
 *
 * @return bool - success status of the executed command
 */
bool onCommand(string cmd, string params, int keys) {
   string fullCmd = cmd +":"+ params +":"+ keys;

   if (cmd == "start") {
      switch (instance.status) {
         case STATUS_STOPPED:
            logInfo("onCommand(1)  "+ instance.name +" "+ DoubleQuoteStr(fullCmd));
            return(StartInstance(NULL));
      }
   }
   else if (cmd == "stop") {
      switch (instance.status) {
         case STATUS_WAITING:
         case STATUS_PROGRESSING:
            logInfo("onCommand(2)  "+ instance.name +" "+ DoubleQuoteStr(fullCmd));
            return(StopInstance(NULL));
      }
   }
   else return(!logNotice("onCommand(3)  "+ instance.name +" unsupported command: "+ DoubleQuoteStr(fullCmd)));

   return(!logWarn("onCommand(4)  "+ instance.name +" cannot execute command "+ DoubleQuoteStr(fullCmd) +" in status "+ StatusToStr(instance.status)));
}


/**
 * Whether a new ZigZag reversal occurred.
 *
 * @param  _Out_ int &signal - variable receiving the signal identifier: SIGNAL_LONG | SIGNAL_SHORT
 *
 * @return bool
 */
bool IsZigZagSignal(int &signal) {
   if (last_error != NULL) return(false);
   signal = NULL;

   static int lastTick, lastResult, lastSignal;
   int trend, reversal;

   if (Ticks == lastTick) {
      signal = lastResult;
   }
   else {
      if (!GetZigZagTrendData(0, trend, reversal)) return(false);

      if (Abs(trend)==reversal || !reversal) {     // reversal=0 denotes a double crossing, trend is +1 or -1
         if (trend > 0) {
            if (lastSignal != SIGNAL_LONG)  signal = SIGNAL_LONG;
         }
         else {
            if (lastSignal != SIGNAL_SHORT) signal = SIGNAL_SHORT;
         }
         if (signal != NULL) {
            if (instance.status == STATUS_PROGRESSING) {
               if (IsLogInfo()) logInfo("IsZigZagSignal(1)  "+ instance.name +" "+ ifString(signal==SIGNAL_LONG, "long", "short") +" reversal (market: "+ NumberToStr(Bid, PriceFormat) +"/"+ NumberToStr(Ask, PriceFormat) +")");
            }
            lastSignal = signal;
         }
      }
      lastTick   = Ticks;
      lastResult = signal;
   }
   return(signal != NULL);
}


/**
 * Get ZigZag trend data at the specified bar offset.
 *
 * @param  _In_  int bar            - bar offset
 * @param  _Out_ int &combinedTrend - combined trend value (MODE_KNOWN_TREND + MODE_UNKNOWN_TREND buffers)
 * @param  _Out_ int &reversal      - bar offset of current ZigZag reversal to the previous ZigZag extreme
 *
 * @return bool - success status
 */
bool GetZigZagTrendData(int bar, int &combinedTrend, int &reversal) {
   combinedTrend = MathRound(icZigZag(NULL, Donchian.Periods, ZigZag.MODE_TREND,    bar));
   reversal      = MathRound(icZigZag(NULL, Donchian.Periods, ZigZag.MODE_REVERSAL, bar));
   return(combinedTrend != 0);
}


/**
 * Restart a stopped instance.
 *
 * @param  int signal - trade signal causing the call or NULL on explicit start (i.e. manual)
 *
 * @return bool - success status
 */
bool StartInstance(int signal) {
   if (last_error != NULL)                return(false);
   if (instance.status != STATUS_STOPPED) return(!catch("StartInstance(1)  "+ instance.name +" cannot start "+ StatusDescription(instance.status) +" instance", ERR_ILLEGAL_STATE));
   return(true);
}


/**
 * Stop a waiting or progressing instance and close open positions (if any).
 *
 * @param  int signal - trade signal causing the call or NULL on explicit stop (i.e. manual)
 *
 * @return bool - success status
 */
bool StopInstance(int signal) {
   if (last_error != NULL)                                                     return(false);
   if (instance.status!=STATUS_WAITING && instance.status!=STATUS_PROGRESSING) return(!catch("StopInstance(1)  "+ instance.name +" cannot stop "+ StatusDescription(instance.status) +" instance", ERR_ILLEGAL_STATE));
   return(true);
}


/**
 * Whether the current instance was created in the tester. Considers that a test instance can be loaded into an online
 * chart after the test (for visualization and analysis).
 *
 * @return bool
 */
bool IsTestInstance() {
   return(instance.isTest || __isTesting);
}


/**
 * Calculate a magic order number for the strategy.
 *
 * @param  int instanceId [optional] - intance to calculate the magic number for (default: the current instance)
 *
 * @return int - magic number or NULL in case of errors
 */
int CalculateMagicNumber(int instanceId = NULL) {
   if (STRATEGY_ID < 101 || STRATEGY_ID > 1023) return(!catch("CalculateMagicNumber(1)  "+ instance.name +" illegal strategy id: "+ STRATEGY_ID, ERR_ILLEGAL_STATE));
   int id = intOr(instanceId, instance.id);
   if (id < IID_MIN || id > IID_MAX)            return(!catch("CalculateMagicNumber(2)  "+ instance.name +" illegal instance id: "+ id, ERR_ILLEGAL_STATE));

   int strategy = STRATEGY_ID;                              // 101-1023 (10 bit)
   int instance = id;                                       // 100-999  (14 bit, used to be 1000-9999)

   return((strategy<<22) + (instance<<8));                  // the remaining 8 bit are currently not used in this strategy
}


/**
 * Whether the currently selected ticket belongs to the current strategy and optionally instance.
 *
 * @param  int instanceId [optional] - instance to check the ticket against (default: check for matching strategy only)
 *
 * @return bool
 */
bool IsMyOrder(int instanceId = NULL) {
   if (OrderSymbol() == Symbol()) {
      int strategy = OrderMagicNumber() >> 22;
      if (strategy == STRATEGY_ID) {
         int instance = OrderMagicNumber() >> 8 & 0x3FFF;   // 14 bit starting at bit 8: instance id
         return(!instanceId || instanceId==instance);
      }
   }
   return(false);
}


/**
 * Generate a new instance id. Must be unique for all instances of this strategy.
 *
 * @return int - instances id in the range of 100-999 or NULL in case of errors
 */
int CreateInstanceId() {
   MathSrand(GetTickCount()-__ExecutionContext[EC.hChartWindow]);
   int instanceId, magicNumber;

   while (!magicNumber) {
      while (instanceId < IID_MIN || instanceId > IID_MAX) {
         instanceId = MathRand();                           // TODO: generate consecutive ids when in tester
      }
      magicNumber = CalculateMagicNumber(instanceId); if (!magicNumber) return(NULL);

      // test for uniqueness against open orders
      int openOrders = OrdersTotal();
      for (int i=0; i < openOrders; i++) {
         if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) return(!catch("CreateInstanceId(1)  "+ instance.name, intOr(GetLastError(), ERR_RUNTIME_ERROR)));
         if (OrderMagicNumber() == magicNumber) {
            magicNumber = NULL;
            break;
         }
      }
      if (!magicNumber) continue;

      // test for uniqueness against closed orders
      int closedOrders = OrdersHistoryTotal();
      for (i=0; i < closedOrders; i++) {
         if (!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) return(!catch("CreateInstanceIdId(2)  "+ instance.name, intOr(GetLastError(), ERR_RUNTIME_ERROR)));
         if (OrderMagicNumber() == magicNumber) {
            magicNumber = NULL;
            break;
         }
      }
   }
   return(instanceId);
}


/**
 * Parse and set the passed instance id value (format: "T?[0-9]{3}").
 *
 * @param  _In_    string value  - instance id value
 * @param  _InOut_ bool   error  - in:  mute parse errors (TRUE) or trigger a fatal error (FALSE)
 *                                 out: whether parse errors occurred (stored in last_error)
 * @param  _In_    string caller - caller identification for error messages
 *
 * @return bool - whether the instance id value was successfully set
 */
bool SetInstanceId(string value, bool &error, string caller) {
   string valueBak = value;
   bool muteErrors = error!=0;
   error = false;

   value = StrTrim(value);
   if (!StringLen(value)) return(false);

   bool isTest = false;
   int instanceId = 0;

   if (StrStartsWith(value, "T")) {
      isTest = true;
      value = StringTrimLeft(StrSubstr(value, 1));
   }

   if (!StrIsDigits(value)) {
      error = true;
      if (muteErrors) return(!SetLastError(ERR_INVALID_PARAMETER));
      return(!catch(caller +"->SetInstanceId(1)  invalid instance id value: \""+ valueBak +"\" (must be digits only)", ERR_INVALID_PARAMETER));
   }

   int iValue = StrToInteger(value);
   if (iValue < IID_MIN || iValue > IID_MAX) {
      error = true;
      if (muteErrors) return(!SetLastError(ERR_INVALID_PARAMETER));
      return(!catch(caller +"->SetInstanceId(2)  invalid instance id value: \""+ valueBak +"\" (range error)", ERR_INVALID_PARAMETER));
   }

   instance.isTest = isTest;
   instance.id     = iValue;
   Instance.ID     = ifString(IsTestInstance(), "T", "") + instance.id;
   SS.InstanceName();
   return(true);
}


/**
 * Restore the internal state of the EA from a status file. Requires 'instance.id' and 'instance.isTest' to be set.
 *
 * @return bool - success status
 */
bool RestoreInstance() {
   if (IsLastError())        return(false);
   if (!ReadStatus())        return(false);              // read and apply the status file
   if (!ValidateInputs())    return(false);              // validate restored input parameters
   if (!SynchronizeStatus()) return(false);              // synchronize restored state with current order state
   return(true);
}


/**
 * Read the status file of an instance and restore inputs and runtime variables. Called only from RestoreSequence().
 *
 * @return bool - success status
 */
bool ReadStatus() {
   if (IsLastError()) return(false);
   if (!instance.id)  return(!catch("ReadStatus(1)  "+ instance.name +" illegal value of instance.id: "+ instance.id, ERR_ILLEGAL_STATE));

   string section="", file=FindStatusFile(instance.id);
   if (file == "")                 return(!catch("ReadStatus(2)  "+ instance.name +" status file not found", ERR_RUNTIME_ERROR));
   if (!IsFile(file, MODE_SYSTEM)) return(!catch("ReadStatus(3)  "+ instance.name +" file "+ DoubleQuoteStr(file) +" not found", ERR_FILE_NOT_FOUND));

   // [General]
   section = "General";
   string sAccount     = GetIniStringA(file, section, "Account", "");                  // string Account = ICMarkets:12345678 (demo)
   string sSymbol      = GetIniStringA(file, section, "Symbol",  "");                  // string Symbol  = EURUSD
   string sThisAccount = GetAccountCompanyId() +":"+ GetAccountNumber();
   if (!StrCompareI(StrLeftTo(sAccount, " ("), sThisAccount)) return(!catch("ReadStatus(4)  "+ instance.name +" account mis-match: "+ DoubleQuoteStr(sThisAccount) +" vs. "+ DoubleQuoteStr(sAccount) +" in status file "+ DoubleQuoteStr(file), ERR_INVALID_CONFIG_VALUE));
   if (!StrCompareI(sSymbol, Symbol()))                       return(!catch("ReadStatus(5)  "+ instance.name +" symbol mis-match: "+ Symbol() +" vs. "+ sSymbol +" in status file "+ DoubleQuoteStr(file), ERR_INVALID_CONFIG_VALUE));

   // [Inputs]
   section = "Inputs";
   string sInstanceID      = GetIniStringA(file, section, "Instance.ID",  "");         // string Instance.ID      = T123
   int    iDonchianPeriods = GetIniInt    (file, section, "Donchian.Periods");         // int    Donchian.Periods = 40

   Instance.ID      = sInstanceID;
   Donchian.Periods = iDonchianPeriods;

   // [Runtime status]
   section = "Runtime status";
   instance.id             = GetIniInt    (file, section, "instance.id"      );        // int      instance.id      = 123
   instance.created        = GetIniInt    (file, section, "instance.created" );        // datetime instance.created = 1624924800 (Mon, 2021.05.12 13:22:34)
   instance.isTest         = GetIniBool   (file, section, "instance.isTest"  );        // bool     instance.isTest  = 1
   instance.name           = GetIniStringA(file, section, "instance.name", "");        // string   instance.name    = V.123
   instance.status         = GetIniInt    (file, section, "instance.status"  );        // int      instance.status  = 1
   SS.InstanceName();

   return(!catch("ReadStatus(6)"));
}


/**
 * Synchronize restored state and runtime vars with current order status on the trade server.
 * Called only from RestoreSequence().
 *
 * @return bool - success status
 */
bool SynchronizeStatus() {
   if (IsLastError()) return(false);

   // detect & handle dangling open positions
   for (int i=OrdersTotal()-1; i >= 0; i--) {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if (IsMyOrder(instance.id)) {
         // TODO
      }
   }

   // detect & handle dangling closed positions
   for (i=OrdersHistoryTotal()-1; i >= 0; i--) {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) continue;
      if (IsPendingOrderType(OrderType()))              continue;    // skip deleted pending orders (atm not supported)

      if (IsMyOrder(instance.id)) {
         // TODO
      }
   }
   return(!catch("SynchronizeStatus(1)"));
}


/**
 * Return the full name of the instance logfile.
 *
 * @return string - filename or an empty string in case of errors
 */
string GetLogFilename() {
   string name = GetStatusFilename();
   if (!StringLen(name)) return("");
   return(StrLeftTo(name, ".", -1) +".log");
}


/**
 * Return the full name of the instance status file.
 *
 * @param  bool relative [optional] - whether to return the absolute path or the path relative to the MQL "files" directory
 *                                    (default: the absolute path)
 *
 * @return string - filename or an empty string in case of errors
 */
string GetStatusFilename(bool relative = false) {
   relative = relative!=0;
   if (!instance.id)      return(_EMPTY_STR(catch("GetStatusFilename(1)  "+ instance.name +" illegal value of instance.id: 0", ERR_ILLEGAL_STATE)));
   if (!instance.created) return(_EMPTY_STR(catch("GetStatusFilename(2)  "+ instance.name +" illegal value of instance.created: 0", ERR_ILLEGAL_STATE)));

   static string filename = ""; if (!StringLen(filename)) {
      string directory = "presets/"+ ifString(IsTestInstance(), "Tester", GetAccountCompanyId()) +"/";
      string baseName  = Symbol() +"."+ GmtTimeFormat(instance.created, "%Y.%m.%d %H.%M") +".Vegas."+ instance.id +".set";
      filename = directory + baseName;
   }

   if (relative)
      return(filename);
   return(GetMqlSandboxPath() +"/"+ filename);
}


/**
 * Find the name of the status file for the specified instance.
 *
 * @param  int instanceId
 *
 * @return string - absolute filename or an empty string in case of errors
 */
string FindStatusFile(int instanceId) {
   if (instanceId < IID_MIN || instanceId > IID_MAX) return(_EMPTY_STR(catch("FindStatusFile(1)  "+ instance.name +" invalid parameter instanceId: "+ instanceId, ERR_INVALID_PARAMETER)));

   string sandboxDir  = GetMqlSandboxPath() +"/";
   string statusDir   = "presets/"+ GetAccountCompanyId() +"/";
   string basePattern = Symbol() +".*.Vegas."+ instanceId +".set";
   string pathPattern = sandboxDir + statusDir + basePattern;

   string result[];
   int size = FindFileNames(pathPattern, result, FF_FILESONLY);

   if (size != 1) {
      if (size > 1) logWarn("FindStatusFile(2)  "+ instance.name +" multiple matching files found for pattern "+ DoubleQuoteStr(pathPattern), ERR_ILLEGAL_STATE);
      return("");
   }
   return(sandboxDir + statusDir + result[0]);
}


/**
 * Write the current instance status to a file.
 *
 * @return bool - success status
 */
bool SaveStatus() {
   if (last_error != NULL)                       return(false);
   if (!instance.id || StrTrim(Instance.ID)=="") return(!catch("SaveStatus(1)  illegal instance id: "+ instance.id +" (Instance.ID="+ DoubleQuoteStr(Instance.ID) +")", ERR_ILLEGAL_STATE));
   if (IsTestInstance() && !__isTesting)         return(true);  // don't change the status file of a finished test

   if (__isTesting && test.reduceStatusWrites) {                // in tester skip most writes except file creation, instance stop and test end
      static bool saved = false;
      if (saved && instance.status!=STATUS_STOPPED && __CoreFunction!=CF_DEINIT) return(true);
      saved = true;
   }

   string section="", separator="", file=GetStatusFilename();
   if (!IsFile(file, MODE_SYSTEM)) separator = CRLF;            // an empty line as additional section separator

   // [General]
   section = "General";
   WriteIniString(file, section, "Account", GetAccountCompanyId() +":"+ GetAccountNumber() +" ("+ ifString(IsDemoFix(), "demo", "real") +")");
   WriteIniString(file, section, "Symbol",  Symbol());
   WriteIniString(file, section, "Created", GmtTimeFormat(instance.created, "%a, %Y.%m.%d %H:%M:%S") + separator);   // conditional section separator

   // [Inputs]
   section = "Inputs";
   WriteIniString(file, section, "Instance.ID",      /*string*/ Instance.ID);
   WriteIniString(file, section, "Donchian.Periods", /*int   */ Donchian.Periods + separator);                       // conditional section separator

   // [Runtime status]
   section = "Runtime status";                                  // On deletion of pending orders the number of stored order records decreases. To prevent
   EmptyIniSectionA(file, section);                             // orphaned status file records the section is emptied before writing to it.

   // instance data
   WriteIniString(file, section, "instance.id",      /*int     */ instance.id);
   WriteIniString(file, section, "instance.created", /*datetime*/ instance.created + GmtTimeFormat(instance.created, " (%a, %Y.%m.%d %H:%M:%S)"));
   WriteIniString(file, section, "instance.isTest",  /*bool    */ instance.isTest);
   WriteIniString(file, section, "instance.name",    /*string  */ instance.name);
   WriteIniString(file, section, "instance.status",  /*int     */ instance.status);

   return(!catch("SaveStatus(2)"));
}


// backed-up input parameters
string   prev.Instance.ID = "";
int      prev.Donchian.Periods;

// backed-up runtime variables affected by changing input parameters
int      prev.instance.id;
datetime prev.instance.created;
bool     prev.instance.isTest;
string   prev.instance.name = "";
int      prev.instance.status;


/**
 * Programatically changed input parameters don't survive init cycles. Therefore inputs are backed-up in deinit() and can be
 * restored in init(). Called in onDeinitParameters() and onDeinitChartChange().
 */
void BackupInputs() {
   // backup input parameters, also accessed for comparison in ValidateInputs()
   prev.Instance.ID      = StringConcatenate(Instance.ID, "");    // string inputs are references to internal C literals and must be copied to break the reference
   prev.Donchian.Periods = Donchian.Periods;

   // backup runtime variables affected by changing input parameters
   prev.instance.id      = instance.id;
   prev.instance.created = instance.created;
   prev.instance.isTest  = instance.isTest;
   prev.instance.name    = instance.name;
   prev.instance.status  = instance.status;
}


/**
 * Restore backed-up input parameters and runtime variables. Called from onInitParameters() and onInitTimeframeChange().
 */
void RestoreInputs() {
   // restore input parameters
   Instance.ID      = prev.Instance.ID;
   Donchian.Periods = prev.Donchian.Periods;

   // restore runtime variables
   instance.id      = prev.instance.id;
   instance.created = prev.instance.created;
   instance.isTest  = prev.instance.isTest;
   instance.name    = prev.instance.name;
   instance.status  = prev.instance.status;
}


/**
 * Validate and apply input parameter "Instance.ID".
 *
 * @return bool - whether an instance id value was successfully restored (the status file is not checked)
 */
bool ValidateInputs.IID() {
   bool errorFlag = true;

   if (!SetInstanceId(Instance.ID, errorFlag, "ValidateInputs.IID(1)")) {
      if (errorFlag) onInputError("ValidateInputs.IID(2)  invalid input parameter Instance.ID: \""+ Instance.ID +"\"");
      return(false);
   }
   return(true);
}


/**
 * Validate all input parameters. Parameters may have been entered through the input dialog, read from a status file or
 * deserialized and applied programmatically by the terminal (e.g. at terminal restart). Called from onInitUser(),
 * onInitParameters() or onInitTemplate().
 *
 * @return bool - whether input parameters are valid
 */
bool ValidateInputs() {
   if (IsLastError()) return(false);
   bool isInitParameters = (ProgramInitReason()==IR_PARAMETERS);  // whether we validate manual or programatic input
   bool isInitUser       = (ProgramInitReason()==IR_USER);
   bool isInitTemplate   = (ProgramInitReason()==IR_TEMPLATE);
   bool hasOpenOrders    = false;

   // Instance.ID
   if (isInitParameters) {                                        // otherwise the id was validated in ValidateInputs.IID()
      string sValue = StrTrim(Instance.ID);
      if (sValue == "") {                                         // the id was deleted or not yet set, restore the internal id
         Instance.ID = prev.Instance.ID;
      }
      else if (sValue != prev.Instance.ID) return(!onInputError("ValidateInputs(1)  "+ instance.name +" switching to another instance is not supported (unload the EA first)"));
   }

   // Donchian.Periods
   if (isInitParameters && Donchian.Periods!=prev.Donchian.Periods) {
      if (hasOpenOrders)                   return(!onInputError("ValidateInputs(2)  "+ instance.name +" cannot change input parameter Donchian.Periods with open orders"));
   }
   if (Donchian.Periods < 2)               return(!onInputError("ValidateInputs(3)  "+ instance.name +" invalid input parameter Donchian.Periods: "+ Donchian.Periods +" (must be > 1)"));

   SS.All();
   return(!catch("ValidateInputs(4)"));
}


/**
 * Error handler for invalid input parameters. Depending on the execution context a non-/terminating error is set.
 *
 * @param  string message - error message
 *
 * @return int - error status
 */
int onInputError(string message) {
   int error = ERR_INVALID_PARAMETER;

   if (ProgramInitReason() == IR_PARAMETERS)
      return(logError(message, error));                           // non-terminating error
   return(catch(message, error));                                 // terminating error
}


/**
 * Store the current instance id in the terminal (for template changes, terminal restart, recompilation etc).
 *
 * @return bool - success status
 */
bool StoreInstanceId() {
   string name = ProgramName() +".Instance.ID";
   string value = ifString(instance.isTest, "T", "") + instance.id;

   Instance.ID = value;                                              // store in input parameter

   if (__isChart) {
      Chart.StoreString(name, value);                                // store in chart
      SetWindowStringA(__ExecutionContext[EC.hChart], name, value);  // store in chart window
   }
   return(!catch("StoreInstanceId(1)"));
}


/**
 * Find and restore a stored instance id (for template changes, terminal restart, recompilation etc).
 *
 * @return bool - whether an instance id was successfully restored
 */
bool RestoreInstanceId() {
   bool isError, muteErrors=false;

   // check input parameter
   string value = Instance.ID;
   if (SetInstanceId(value, muteErrors, "RestoreInstanceId(1)")) return(true);
   isError = muteErrors;
   if (isError) return(false);

   if (__isChart) {
      // check chart window
      string name = ProgramName() +".Instance.ID";
      value = GetWindowStringA(__ExecutionContext[EC.hChart], name);
      muteErrors = false;
      if (SetInstanceId(value, muteErrors, "RestoreInstanceId(2)")) return(true);
      isError = muteErrors;
      if (isError) return(false);

      // check chart
      if (Chart.RestoreString(name, value, false)) {
         muteErrors = false;
         if (SetInstanceId(value, muteErrors, "RestoreInstanceId(3)")) return(true);
      }
   }
   return(false);
}


/**
 * Return a readable presentation of an instance status code.
 *
 * @param  int status
 *
 * @return string
 */
string StatusToStr(int status) {
   switch (status) {
      case NULL              : return("(NULL)"            );
      case STATUS_WAITING    : return("STATUS_WAITING"    );
      case STATUS_PROGRESSING: return("STATUS_PROGRESSING");
      case STATUS_STOPPED    : return("STATUS_STOPPED"    );
   }
   return(_EMPTY_STR(catch("StatusToStr(1)  "+ instance.name +" invalid parameter status: "+ status, ERR_INVALID_PARAMETER)));
}


/**
 * Return a description of an instance status code.
 *
 * @param  int status
 *
 * @return string - description or an empty string in case of errors
 */
string StatusDescription(int status) {
   switch (status) {
      case NULL              : return("undefined"  );
      case STATUS_WAITING    : return("waiting"    );
      case STATUS_PROGRESSING: return("progressing");
      case STATUS_STOPPED    : return("stopped"    );
   }
   return(_EMPTY_STR(catch("StatusDescription(1)  "+ instance.name +" invalid parameter status: "+ status, ERR_INVALID_PARAMETER)));
}


/**
 * ShowStatus: Update all string representations.
 */
void SS.All() {
   if (__isChart) {
      SS.InstanceName();
   }
}


/**
 * ShowStatus: Update the string representation of the instance name.
 */
void SS.InstanceName() {
   instance.name = "V."+ instance.id;
}


/**
 * Display the current runtime status.
 *
 * @param  int error [optional] - error to display (default: none)
 *
 * @return int - the same error or the current error status if no error was specified
 */
int ShowStatus(int error = NO_ERROR) {
   if (!__isChart) return(error);

   static bool isRecursion = false;                   // to prevent recursive calls a specified error is displayed only once
   if (error != 0) {
      if (isRecursion) return(error);
      isRecursion = true;
   }
   string sStatus="", sError="";

   switch (instance.status) {
      case NULL:               sStatus = StringConcatenate(instance.name, "  not initialized"); break;
      case STATUS_WAITING:     sStatus = StringConcatenate(instance.name, "  waiting");         break;
      case STATUS_PROGRESSING: sStatus = StringConcatenate(instance.name, "  progressing");     break;
      case STATUS_STOPPED:     sStatus = StringConcatenate(instance.name, "  stopped");         break;
      default:
         return(catch("ShowStatus(1)  "+ instance.name +" illegal instance status: "+ instance.status, ERR_ILLEGAL_STATE));
   }
   if (__STATUS_OFF) sError = StringConcatenate("  [switched off => ", ErrorDescription(__STATUS_OFF.reason), "]");

   string text = StringConcatenate(ProgramName(), "    ", sStatus, sError, NL,
                                                                           NL,
                                  "Profit:   ",                            NL
   );

   // 3 lines margin-top for instrument and indicator legends
   Comment(NL, NL, NL, text);
   if (__CoreFunction == CF_INIT) WindowRedraw();

   // store status in the chart to enable sending of chart commands
   string label = "EA.status";
   if (ObjectFind(label) != 0) {
      ObjectCreate(label, OBJ_LABEL, 0, 0, 0);
      ObjectSet(label, OBJPROP_TIMEFRAMES, OBJ_PERIODS_NONE);
   }
   ObjectSetText(label, StringConcatenate(Instance.ID, "|", StatusDescription(instance.status)));

   error = intOr(catch("ShowStatus(2)"), error);
   isRecursion = false;
   return(error);
}


/**
 * Return a string representation of the input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("Instance.ID=",      DoubleQuoteStr(Instance.ID), ";", NL,
                            "Donchian.Periods=", Donchian.Periods,            ";")
   );

   icMaTunnel(NULL, NULL, NULL, NULL);
}
