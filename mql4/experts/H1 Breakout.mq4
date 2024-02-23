/**
 ****************************************************************************************************************************
 *                                           WORK-IN-PROGRESS, DO NOT YET USE                                               *
 ****************************************************************************************************************************
 *
 * H1 Morning Breakout
 *
 * A strategy for common H1 breakouts during Frankfurt or London Open (07:00-08:00, 08:00-09:00, 09:00-10:00).
 * Idea: Later the strategy could adjust itself by self-optimizing the best bracket hour (e.g. over the last few weeks).
 *
 *  @see  https://www.forexfactory.com/thread/902048-london-open-breakout-strategy-for-gbpusd#         [London Open Breakout]
 *  @see  https://nexusfi.com/trading-journals/36245-london-session-opening-range-breakout-gbp.html# [Asian session breakout]
 *  @see  GBPAUD, GBPUSD FF Opening Range Breakout (07:00-08:00, 08:00-09:00)
 */
#include <stddefines.mqh>
int   __InitFlags[] = {INIT_PIPVALUE, INIT_BUFFERED_LOG};
int __DeinitFlags[];
int __virtualTicks = 0;

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern string Instance.ID                    = "";          // instance to load from a status file (format "[T]123")
extern double Lots                           = 1.0;

extern int    Initial.TakeProfit             = 100;         // in pip (0: partial targets only or no TP)
extern int    Initial.StopLoss               = 50;          // in pip (0: moving stops only or no SL

extern int    Target1                        = 0;           // in pip
extern int    Target1.ClosePercent           = 0;           // size to close (0: nothing)
extern int    Target1.MoveStopTo             = 1;           // in pip (0: don't move stop)

extern int    Target2                        = 0;           // ...
extern int    Target2.ClosePercent           = 30;          // ...
extern int    Target2.MoveStopTo             = 0;           // ...

extern int    Target3                        = 0;           // ...
extern int    Target3.ClosePercent           = 30;          // ...
extern int    Target3.MoveStopTo             = 0;           // ...

extern int    Target4                        = 0;           // ...
extern int    Target4.ClosePercent           = 30;          // ...
extern int    Target4.MoveStopTo             = 0;           // ...

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/expert.mqh>
#include <stdfunctions.mqh>
#include <rsfLib.mqh>
#include <functions/HandleCommands.mqh>

#define STRATEGY_ID         111              // unique strategy id (used for magic order numbers)

#define INSTANCE_ID_MIN       1              // range of valid instance ids
#define INSTANCE_ID_MAX     999              //

#define STATUS_WAITING        1              // instance has no open positions and waits for signals
#define STATUS_PROGRESSING    2              // instance manages open positions
#define STATUS_STOPPED        3              // instance has no open positions and doesn't wait for signals

double history[][12];                        // trade history

#define H_TICKET              0              // indexes of trade history
#define H_TYPE                1
#define H_LOTS                2
#define H_OPENTIME            3
#define H_OPENPRICE           4
#define H_CLOSETIME           5
#define H_CLOSEPRICE          6
#define H_SLIPPAGE            7
#define H_SWAP                8
#define H_COMMISSION          9
#define H_GROSSPROFIT        10
#define H_NETPROFIT          11

// instance data
int      instance.id;                        // used for magic order numbers
string   instance.name = "";
datetime instance.created;
bool     instance.isTest;                    // whether the instance is a test
int      instance.status;
double   instance.startEquity;

double   instance.openNetProfit;             // real PnL after all costs in money (net)
double   instance.closedNetProfit;
double   instance.totalNetProfit;
double   instance.maxNetProfit;              // max. observed profit:   0...+n
double   instance.maxNetDrawdown;            // max. observed drawdown: -n...0

// order data
int      open.ticket;                        // one open position
int      open.type;
double   open.lots;
datetime open.time;
double   open.price;
double   open.slippage;
double   open.swap;
double   open.commission;
double   open.grossProfit;
double   open.netProfit;

// volatile status data
int      status.activeMetric = 1;
bool     status.showOpenOrders;
bool     status.showTradeHistory;

// other
string   pUnit = "";
int      pDigits;
int      pMultiplier;
int      order.slippage = 1;                 // in MQL points

// cache vars to speed-up ShowStatus()
string   sOpenLots     = "";
string   sClosedTrades = "";
string   sTotalProfit  = "";
string   sProfitStats  = "";

// debug settings                            // configurable via framework config, see afterInit()
bool     test.onStopPause        = false;    // whether to pause a test after StopInstance()
bool     test.reduceStatusWrites = true;     // whether to reduce status file I/O in tester

#include <apps/h1-breakout/init.mqh>
#include <apps/h1-breakout/deinit.mqh>

#include <ea/CalculateMagicNumber.mqh>
#include <ea/CreateInstanceId.mqh>
#include <ea/IsMyOrder.mqh>
#include <ea/IsTestInstance.mqh>
#include <ea/onInputError.mqh>
#include <ea/RestoreInstance.mqh>
#include <ea/ToggleTradeHistory.mqh>
#include <ea/ValidateInputs.ID.mqh>
#include <ea/file/FindStatusFile.mqh>
#include <ea/file/GetStatusFilename.mqh>
#include <ea/file/GetLogFilename.mqh>
#include <ea/volatile/StoreVolatileData.mqh>
#include <ea/volatile/RestoreVolatileData.mqh>
#include <ea/volatile/RemoveVolatileData.mqh>


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   if (!instance.status) return(catch("onTick(1)  illegal instance.status: "+ instance.status, ERR_ILLEGAL_STATE));

   if (__isChart) HandleCommands();          // process incoming commands

   if (instance.status != STATUS_STOPPED) {
      if (instance.status == STATUS_WAITING) {
      }
      else if (instance.status == STATUS_PROGRESSING) {
         UpdateStatus();
      }
   }
   return(catch("onTick(2)"));
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

   if (cmd == "toggle-open-orders") {
      return(ToggleOpenOrders());
   }
   else if (cmd == "toggle-trade-history") {
      return(ToggleTradeHistory());
   }
   else return(!logNotice("onCommand(1)  "+ instance.name +" unsupported command: "+ DoubleQuoteStr(fullCmd)));

   return(!logWarn("onCommand(2)  "+ instance.name +" cannot execute command "+ DoubleQuoteStr(fullCmd) +" in status "+ StatusToStr(instance.status)));
}


/**
 * Toggle the display of open orders.
 *
 * @param  bool soundOnNone [optional] - whether to play a sound if no open orders exist (default: yes)
 *
 * @return bool - success status
 */
bool ToggleOpenOrders(bool soundOnNone = true) {
   return(!catch("ToggleOpenOrders(1)  not implemented", ERR_NOT_IMPLEMENTED));
}


/**
 * Display closed trades.
 *
 * @return int - number of displayed trades or EMPTY (-1) in case of errors
 */
int ShowTradeHistory() {
   return(_EMPTY(catch("ShowTradeHistory(1)  not implemented", ERR_NOT_IMPLEMENTED)));
}


/**
 * Update order status and PnL stats.
 *
 * @param  int signal [optional] - trade signal causing the call (default: none, update status only)
 *
 * @return bool - success status
 */
bool UpdateStatus(int signal = NULL) {
   if (last_error != NULL)                                                     return(false);
   if (instance.status!=STATUS_WAITING && instance.status!=STATUS_PROGRESSING) return(!catch("UpdateStatus(1)  "+ instance.name +" illegal instance status "+ StatusToStr(instance.status), ERR_ILLEGAL_STATE));

   return(!catch("UpdateStatus(2)  not implemented", ERR_NOT_IMPLEMENTED));
}


/**
 * Stop a waiting or progressing instance and close open positions (if any).
 *
 * @return bool - success status
 */
bool StopInstance() {
   if (last_error != NULL)                                                     return(false);
   if (instance.status!=STATUS_WAITING && instance.status!=STATUS_PROGRESSING) return(!catch("StopInstance(1)  "+ instance.name +" cannot stop "+ StatusDescription(instance.status) +" instance", ERR_ILLEGAL_STATE));

   logNotice("StopInstance(0.1)  not implemented", ERR_NOT_IMPLEMENTED);

   return(!catch("StopInstance(2)"));
}


/**
 * Parse and set the passed instance id value. Format: "[T]123"
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
   if (iValue < INSTANCE_ID_MIN || iValue > INSTANCE_ID_MAX) {
      error = true;
      if (muteErrors) return(!SetLastError(ERR_INVALID_PARAMETER));
      return(!catch(caller +"->SetInstanceId(2)  invalid instance id value: \""+ valueBak +"\" (range error)", ERR_INVALID_PARAMETER));
   }

   instance.isTest = isTest;
   instance.id     = iValue;
   Instance.ID     = ifString(IsTestInstance(), "T", "") + StrPadLeft(instance.id, 3, "0");
   SS.InstanceName();
   return(true);
}


/**
 * Read the status file of an instance and restore inputs and runtime variables. Called only from RestoreInstance().
 *
 * @return bool - success status
 */
bool ReadStatus() {
   if (IsLastError()) return(false);
   if (!instance.id)  return(!catch("ReadStatus(1)  "+ instance.name +" illegal value of instance.id: "+ instance.id, ERR_ILLEGAL_STATE));

   string file = FindStatusFile(instance.id, instance.isTest);
   if (file == "")                 return(!catch("ReadStatus(2)  "+ instance.name +" status file not found", ERR_RUNTIME_ERROR));
   if (!IsFile(file, MODE_SYSTEM)) return(!catch("ReadStatus(3)  "+ instance.name +" file "+ DoubleQuoteStr(file) +" not found", ERR_FILE_NOT_FOUND));

   // [General]
   string section      = "General";
   string sAccount     = GetIniStringA(file, section, "Account",     "");                       // string Account     = ICMarkets:12345678 (demo)
   string sThisAccount = GetAccountCompanyId() +":"+ GetAccountNumber();
   string sRealSymbol  = GetIniStringA(file, section, "Symbol",      "");                       // string Symbol      = EURUSD
   string sTestSymbol  = GetIniStringA(file, section, "Test.Symbol", "");                       // string Test.Symbol = EURUSD
   if (sTestSymbol == "") {
      if (!StrCompareI(StrLeftTo(sAccount, " ("), sThisAccount)) return(!catch("ReadStatus(4)  "+ instance.name +" account mis-match: "+ DoubleQuoteStr(sThisAccount) +" vs. "+ DoubleQuoteStr(sAccount) +" in status file "+ DoubleQuoteStr(file), ERR_INVALID_CONFIG_VALUE));
      if (!StrCompareI(sRealSymbol, Symbol()))                   return(!catch("ReadStatus(5)  "+ instance.name +" symbol mis-match: "+ DoubleQuoteStr(Symbol()) +" vs. "+ DoubleQuoteStr(sRealSymbol) +" in status file "+ DoubleQuoteStr(file), ERR_INVALID_CONFIG_VALUE));
   }
   else {
      if (!StrCompareI(sTestSymbol, Symbol()))                   return(!catch("ReadStatus(6)  "+ instance.name +" symbol mis-match: "+ DoubleQuoteStr(Symbol()) +" vs. "+ DoubleQuoteStr(sTestSymbol) +" in status file "+ DoubleQuoteStr(file), ERR_INVALID_CONFIG_VALUE));
   }

   // [Inputs]
   section = "Inputs";
   string sInstanceID         = GetIniStringA(file, section, "Instance.ID",       "");          // string Instance.ID       = T123
   string sLots               = GetIniStringA(file, section, "Lots",              "");          // double Lots              = 0.1
   string sEaRecorder         = GetIniStringA(file, section, "EA.Recorder",       "");          // string EA.Recorder       = 1,2,4

   if (!StrIsNumeric(sLots)) return(!catch("ReadStatus(7)  "+ instance.name +" invalid input parameter Lots "+ DoubleQuoteStr(sLots) +" in status file "+ DoubleQuoteStr(file), ERR_INVALID_FILE_FORMAT));

   Instance.ID = sInstanceID;
   Lots        = StrToDouble(sLots);
   EA.Recorder = sEaRecorder;

   // [Runtime status]
   section = "Runtime status";
   instance.id                 = GetIniInt    (file, section, "instance.id"      );             // int      instance.id              = 123
   instance.name               = GetIniStringA(file, section, "instance.name", "");             // string   instance.name            = DJBO.123
   instance.created            = GetIniInt    (file, section, "instance.created" );             // datetime instance.created         = 1624924800 (Mon, 2021.05.12 13:22:34)
   instance.isTest             = GetIniBool   (file, section, "instance.isTest"  );             // bool     instance.isTest          = 1
   instance.status             = GetIniInt    (file, section, "instance.status"  );             // int      instance.status          = 1 (waiting)
   recorder.stdEquitySymbol    = GetIniStringA(file, section, "recorder.stdEquitySymbol", "");  // string   recorder.stdEquitySymbol = GBPJPY.001
   SS.InstanceName();

   // [Open positions]
   section = "Open positions";
   open.ticket                 = GetIniInt    (file, section, "open.ticket"      );             // int      open.ticket       = 123456
   open.type                   = GetIniInt    (file, section, "open.type"        );             // int      open.type         = 1
   open.lots                   = GetIniDouble (file, section, "open.lots"        );             // double   open.lots         = 0.01
   open.time                   = GetIniInt    (file, section, "open.time"        );             // datetime open.time         = 1624924800 (Mon, 2021.05.12 13:22:34)
   open.price                  = GetIniDouble (file, section, "open.price"       );             // double   open.price        = 1.24363
   open.slippage               = GetIniDouble (file, section, "open.slippage"    );             // double   open.slippage     = 0.00003
   open.swap                   = GetIniDouble (file, section, "open.swap"        );             // double   open.swap         = -1.23
   open.commission             = GetIniDouble (file, section, "open.commission"  );             // double   open.commission   = -5.50
   open.grossProfit            = GetIniDouble (file, section, "open.grossProfit" );             // double   open.grossProfit  = 12.34
   open.netProfit              = GetIniDouble (file, section, "open.netProfit"   );             // double   open.netProfit    = 12.56

   return(!catch("ReadStatus(8)"));
}


/**
 * Synchronize runtime state and vars with current order status on the trade server. Called only from RestoreInstance().
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

   SS.All();
   return(!catch("SynchronizeStatus(1)"));
}


/**
 * Write the current instance status to a file.
 *
 * @return bool - success status
 */
bool SaveStatus() {
   if (last_error != NULL)              return(false);
   if (!instance.id || Instance.ID=="") return(!catch("SaveStatus(1)  illegal instance id: "+ instance.id +" (Instance.ID="+ DoubleQuoteStr(Instance.ID) +")", ERR_ILLEGAL_STATE));
   if (__isTesting) {
      if (test.reduceStatusWrites) {                           // in tester skip most writes except file creation, instance stop and test end
         static bool saved = false;
         if (saved && instance.status!=STATUS_STOPPED && __CoreFunction!=CF_DEINIT) return(true);
         saved = true;
      }
   }
   else if (IsTestInstance()) return(true);                    // don't change the status file of a finished test

   string section="", separator="", file=GetStatusFilename();
   if (!IsFile(file, MODE_SYSTEM)) separator = CRLF;           // an empty line separator
   SS.All();                                                   // update trade stats and global string representations

   // [General]
   section = "General";
   WriteIniString(file, section, "Account", GetAccountCompanyId() +":"+ GetAccountNumber() +" ("+ ifString(IsDemoFix(), "demo", "real") +")"+ ifString(__isTesting, separator, ""));

   if (!__isTesting) {
      WriteIniString(file, section, "AccountCurrency", AccountCurrency());
      WriteIniString(file, section, "Symbol",          Symbol() + separator);
   }
   else {
      WriteIniString(file, section, "Test.Currency",   AccountCurrency());
      WriteIniString(file, section, "Test.Symbol",     Symbol());
      WriteIniString(file, section, "Test.TimeRange",  TimeToStr(Test.GetStartDate(), TIME_DATE) +"-"+ TimeToStr(Test.GetEndDate()-1*DAY, TIME_DATE));
      WriteIniString(file, section, "Test.Period",     PeriodDescription());
      WriteIniString(file, section, "Test.BarModel",   BarModelDescription(__Test.barModel));
      WriteIniString(file, section, "Test.Spread",     DoubleToStr((Ask-Bid) * pMultiplier, pDigits) +" "+ pUnit);
         double commission  = GetCommission();
         string sCommission = DoubleToStr(commission, 2);
         if (NE(commission, 0)) {
            double tickValue = MarketInfo(Symbol(), MODE_TICKVALUE);
            double tickSize  = MarketInfo(Symbol(), MODE_TICKSIZE);
            double units     = MathDiv(commission, MathDiv(tickValue, tickSize));
            sCommission = sCommission +" ("+ DoubleToStr(units * pMultiplier, pDigits) +" "+ pUnit +")";
         }
      WriteIniString(file, section, "Test.Commission", sCommission + separator);
   }

   // [Inputs]
   section = "Inputs";
   WriteIniString(file, section, "Instance.ID",              /*string  */ Instance.ID);
   WriteIniString(file, section, "Lots",                     /*double  */ NumberToStr(Lots, ".+"));
   WriteIniString(file, section, "EA.Recorder",              /*string  */ EA.Recorder + separator);

   // [Runtime status]
   section = "Runtime status";
   WriteIniString(file, section, "instance.id",              /*int     */ instance.id);
   WriteIniString(file, section, "instance.name",            /*string  */ instance.name);
   WriteIniString(file, section, "instance.created",         /*datetime*/ instance.created + GmtTimeFormat(instance.created, " (%a, %Y.%m.%d %H:%M:%S)"));
   WriteIniString(file, section, "instance.isTest",          /*bool    */ instance.isTest);
   WriteIniString(file, section, "instance.status",          /*int     */ instance.status +" ("+ StatusDescription(instance.status) +")"+ separator);

   WriteIniString(file, section, "recorder.stdEquitySymbol", /*string  */ recorder.stdEquitySymbol + separator);

   // [Open positions]
   section = "Open positions";
   WriteIniString(file, section, "open.ticket",              /*int     */ open.ticket);
   WriteIniString(file, section, "open.type",                /*int     */ open.type);
   WriteIniString(file, section, "open.lots",                /*double  */ NumberToStr(open.lots, ".+"));
   WriteIniString(file, section, "open.time",                /*datetime*/ open.time + ifString(open.time, GmtTimeFormat(open.time, " (%a, %Y.%m.%d %H:%M:%S)"), ""));
   WriteIniString(file, section, "open.price",               /*double  */ DoubleToStr(open.price, Digits));
   WriteIniString(file, section, "open.slippage",            /*double  */ DoubleToStr(open.slippage, Digits));
   WriteIniString(file, section, "open.swap",                /*double  */ DoubleToStr(open.swap, 2));
   WriteIniString(file, section, "open.commission",          /*double  */ DoubleToStr(open.commission, 2));
   WriteIniString(file, section, "open.grossProfit",         /*double  */ DoubleToStr(open.grossProfit, 2));
   WriteIniString(file, section, "open.netProfit",           /*double  */ DoubleToStr(open.netProfit, 2) + separator);

   return(!catch("SaveStatus(2)"));
}


// backed-up input parameters
string   prev.Instance.ID = "";
double   prev.Lots;

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
   // backup input parameters, used for comparison in ValidateInputs()
   prev.Instance.ID = StringConcatenate(Instance.ID, "");            // string inputs are references to internal C literals
   prev.Lots        = Lots;

   // backup runtime variables affected by changing input parameters
   prev.instance.id      = instance.id;
   prev.instance.created = instance.created;
   prev.instance.isTest  = instance.isTest;
   prev.instance.name    = instance.name;
   prev.instance.status  = instance.status;

   Recorder.BackupInputs();
}


/**
 * Restore backed-up input parameters and runtime variables. Called from onInitParameters() and onInitTimeframeChange().
 */
void RestoreInputs() {
   // restore input parameters
   Instance.ID = prev.Instance.ID;
   Lots        = prev.Lots;

   // restore runtime variables
   instance.id      = prev.instance.id;
   instance.created = prev.instance.created;
   instance.isTest  = prev.instance.isTest;
   instance.name    = prev.instance.name;
   instance.status  = prev.instance.status;

   Recorder.RestoreInputs();
}


/**
 * Validate all input parameters. Parameters may have been entered through the input dialog, read from a status file or were
 * deserialized and set programmatically by the terminal (e.g. at terminal restart). Called from onInitUser(),
 * onInitParameters() or onInitTemplate().
 *
 * @return bool - whether input parameters are valid
 */
bool ValidateInputs() {
   if (IsLastError()) return(false);
   bool isInitParameters = (ProgramInitReason()==IR_PARAMETERS);  // whether we validate manual or programatic input
   bool hasOpenOrders = false;

   // Instance.ID
   if (isInitParameters) {                                        // otherwise the id was validated in ValidateInputs.ID()
      if (StrTrim(Instance.ID) == "") {                           // the id was deleted or not yet set, restore the internal id
         Instance.ID = prev.Instance.ID;
      }
      else if (Instance.ID != prev.Instance.ID)    return(!onInputError("ValidateInputs(1)  "+ instance.name +" switching to another instance is not supported (unload the EA first)"));
   }

   // Lots
   if (LT(Lots, 0))                                return(!onInputError("ValidateInputs(2)  "+ instance.name +" invalid input parameter Lots: "+ NumberToStr(Lots, ".1+") +" (must be > 0)"));
   if (NE(Lots, NormalizeLots(Lots)))              return(!onInputError("ValidateInputs(3)  "+ instance.name +" invalid input parameter Lots: "+ NumberToStr(Lots, ".1+") +" (must be a multiple of MODE_LOTSTEP="+ NumberToStr(MarketInfo(Symbol(), MODE_LOTSTEP), ".+") +")"));

   // EA.Recorder: on | off* | 1,2,3=1000,...
   if (!Recorder.ValidateInputs(IsTestInstance())) return(false);

   SS.All();
   return(!catch("ValidateInputs(4)"));
}


/**
 * Return a readable representation of an instance status code.
 *
 * @param  int status
 *
 * @return string
 */
string StatusToStr(int status) {
   switch (status) {
      case NULL              : return("(null)"            );
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
   SS.InstanceName();
   SS.OpenLots();
   SS.ClosedTrades();
   SS.TotalProfit();
   SS.ProfitStats();
}


/**
 * ShowStatus: Update the string representation of the instance name.
 */
void SS.InstanceName() {
   instance.name = "ID."+ StrPadLeft(instance.id, 3, "0");
}


/**
 * ShowStatus: Update the string representation of the open position size.
 */
void SS.OpenLots() {
   if      (!open.lots)           sOpenLots = "-";
   else if (open.type == OP_LONG) sOpenLots = "+"+ NumberToStr(open.lots, ".+") +" lot";
   else                           sOpenLots = "-"+ NumberToStr(open.lots, ".+") +" lot";
}


/**
 * ShowStatus: Update the string summary of the closed trades.
 */
void SS.ClosedTrades() {
   int size = ArrayRange(history, 0);
   if (!size) {
      sClosedTrades = "-";
   }
   else {
      sClosedTrades = size +" trades    avg: ??? "+ AccountCurrency();
   }
}


/**
 * ShowStatus: Update the string representation of the total instance PnL.
 */
void SS.TotalProfit() {
   // not before a position was opened
   if (!open.ticket && !ArrayRange(history, 0)) {
      sTotalProfit = "-";
   }
   else {
      sTotalProfit = NumberToStr(instance.totalNetProfit, "R+.2") +" "+ AccountCurrency();
   }
}


/**
 * ShowStatus: Update the string representaton of the PnL statistics.
 */
void SS.ProfitStats() {
   // not before a position was opened
   if (!open.ticket && !ArrayRange(history, 0)) {
      sProfitStats = "";
   }
   else {
      string sMaxProfit   = NumberToStr(instance.maxNetProfit,   "R+.2");
      string sMaxDrawdown = NumberToStr(instance.maxNetDrawdown, "R+.2");
      sProfitStats = StringConcatenate("(", sMaxDrawdown, "/", sMaxProfit, ")");
   }
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

   string text = StringConcatenate(ProgramName(), "    ", sStatus, sError,          NL,
                                                                                    NL,
                                   "Open:    ",   sOpenLots,                        NL,
                                   "Closed:  ",   sClosedTrades,                    NL,
                                   "Profit:    ", sTotalProfit, "  ", sProfitStats, NL
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
   return(StringConcatenate("Instance.ID=",          DoubleQuoteStr(Instance.ID), ";"+ NL +
                            "Lots=",                 NumberToStr(Lots, ".1+"),    ";"+ NL +

                            "Initial.TakeProfit=",   Initial.TakeProfit,          ";"+ NL +
                            "Initial.StopLoss=",     Initial.StopLoss,            ";"+ NL +
                            "Target1=",              Target1,                     ";"+ NL +
                            "Target1.ClosePercent=", Target1.ClosePercent,        ";"+ NL +
                            "Target1.MoveStopTo=",   Target1.MoveStopTo,          ";"+ NL +
                            "Target2=",              Target2,                     ";"+ NL +
                            "Target2.ClosePercent=", Target2.ClosePercent,        ";"+ NL +
                            "Target2.MoveStopTo=",   Target2.MoveStopTo,          ";"+ NL +
                            "Target3=",              Target3,                     ";"+ NL +
                            "Target3.ClosePercent=", Target3.ClosePercent,        ";"+ NL +
                            "Target3.MoveStopTo=",   Target3.MoveStopTo,          ";"+ NL +
                            "Target4=",              Target4,                     ";"+ NL +
                            "Target4.ClosePercent=", Target4.ClosePercent,        ";"+ NL +
                            "Target4.MoveStopTo=",   Target4.MoveStopTo,          ";")
   );
}
