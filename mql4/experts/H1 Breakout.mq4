/**
 * H1 Morning Breakout
 *
 * A strategy for common H1 breakouts during Frankfurt or London Open (07:00-08:00, 08:00-09:00, 09:00-10:00).
 *
 *  @see  https://www.forexfactory.com/thread/902048-london-open-breakout-strategy-for-gbpusd#         [London Open Breakout]
 *  @see  https://nexusfi.com/trading-journals/36245-london-session-opening-range-breakout-gbp.html# [Asian session breakout]
 *  @see  GBPAUD, GBPUSD FF Opening Range Breakout (07:00-08:00, 08:00-09:00)
 *
 *
 * TODO:
 *  - self-optimize the best bracket hour over the last few weeks
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

#define STRATEGY_ID            111           // unique strategy id (used for magic order numbers)

#define INSTANCE_ID_MIN          1           // range of valid instance ids
#define INSTANCE_ID_MAX        999           //

#define STATUS_WAITING           1           // instance has no open positions and waits for signals
#define STATUS_PROGRESSING       2           // instance manages open positions
#define STATUS_STOPPED           3           // instance has no open positions and doesn't wait for signals

#define METRIC_TOTAL_NET_MONEY   1           // custom metrics
#define METRIC_TOTAL_NET_UNITS   2
#define METRIC_TOTAL_SYNTH_UNITS 3

#define METRIC_NEXT              1           // directions for toggling between metrics
#define METRIC_PREVIOUS         -1

double history[][20];                        // trade history

#define H_TICKET                 0           // indexes of trade history
#define H_TYPE                   1
#define H_LOTS                   2
#define H_OPENTIME               3
#define H_OPENPRICE              4
#define H_OPENPRICE_SYNTH        5
#define H_CLOSETIME              6
#define H_CLOSEPRICE             7
#define H_CLOSEPRICE_SYNTH       8
#define H_SLIPPAGE               9
#define H_SWAP                  10
#define H_COMMISSION            11
#define H_GROSSPROFIT           12
#define H_NETPROFIT             13
#define H_NETPROFIT_P           14
#define H_RUNUP_P               15
#define H_DRAWDOWN_P            16
#define H_SYNTH_PROFIT_P        17
#define H_SYNTH_RUNUP_P         18
#define H_SYNTH_DRAWDOWN_P      19

double stats[4][47];                         // trade statistics

#define S_TRADES                 0           // indexes of trade statistics
#define S_TRADES_LONG            1
#define S_TRADES_LONG_PCT        2
#define S_TRADES_SHORT           3
#define S_TRADES_SHORT_PCT       4
#define S_TRADES_SUM_RUNUP       5
#define S_TRADES_SUM_DRAWDOWN    6
#define S_TRADES_SUM_PROFIT      7
#define S_TRADES_AVG_RUNUP       8
#define S_TRADES_AVG_DRAWDOWN    9
#define S_TRADES_AVG_PROFIT     10

#define S_WINNERS               11
#define S_WINNERS_PCT           12
#define S_WINNERS_LONG          13
#define S_WINNERS_LONG_PCT      14
#define S_WINNERS_SHORT         15
#define S_WINNERS_SHORT_PCT     16
#define S_WINNERS_SUM_RUNUP     17
#define S_WINNERS_SUM_DRAWDOWN  18
#define S_WINNERS_SUM_PROFIT    19
#define S_WINNERS_AVG_RUNUP     20
#define S_WINNERS_AVG_DRAWDOWN  21
#define S_WINNERS_AVG_PROFIT    22

#define S_LOSERS                23
#define S_LOSERS_PCT            24
#define S_LOSERS_LONG           25
#define S_LOSERS_LONG_PCT       26
#define S_LOSERS_SHORT          27
#define S_LOSERS_SHORT_PCT      28
#define S_LOSERS_SUM_RUNUP      29
#define S_LOSERS_SUM_DRAWDOWN   30
#define S_LOSERS_SUM_PROFIT     31
#define S_LOSERS_AVG_RUNUP      32
#define S_LOSERS_AVG_DRAWDOWN   33
#define S_LOSERS_AVG_PROFIT     34

#define S_SCRATCH               35
#define S_SCRATCH_PCT           36
#define S_SCRATCH_LONG          37
#define S_SCRATCH_LONG_PCT      38
#define S_SCRATCH_SHORT         39
#define S_SCRATCH_SHORT_PCT     40
#define S_SCRATCH_SUM_RUNUP     41
#define S_SCRATCH_SUM_DRAWDOWN  42
#define S_SCRATCH_SUM_PROFIT    43
#define S_SCRATCH_AVG_RUNUP     44
#define S_SCRATCH_AVG_DRAWDOWN  45
#define S_SCRATCH_AVG_PROFIT    46

// instance data
int      instance.id;                        // used for magic order numbers
string   instance.name = "";
datetime instance.created;
bool     instance.isTest;                    // whether the instance is a test
int      instance.status;
double   instance.startEquity;

double   instance.openNetProfit;             // real PnL after all costs in money (net)
double   instance.closedNetProfit;           //
double   instance.totalNetProfit;            //
double   instance.maxNetProfit;              // max. observed profit:   0...+n
double   instance.maxNetDrawdown;            // max. observed drawdown: -n...0

double   instance.openNetProfitP;            // real PnL after all costs in point (net)
double   instance.closedNetProfitP;          //
double   instance.totalNetProfitP;           //
double   instance.maxNetProfitP;             //
double   instance.maxNetDrawdownP;           //

double   instance.openSynthProfitP;          // synthetic PnL before spread/any costs in point (exact execution)
double   instance.closedSynthProfitP;        //
double   instance.totalSynthProfitP;         //
double   instance.maxSynthProfitP;           //
double   instance.maxSynthDrawdownP;         //

// order data
int      open.ticket;                        // one open position
int      open.type;
double   open.lots;
datetime open.time;
double   open.price;
double   open.priceSynth;
double   open.slippage;
double   open.swap;
double   open.commission;
double   open.grossProfit;
double   open.netProfit;
double   open.netProfitP;
double   open.runupP;                        // max runup distance
double   open.drawdownP;                     // ...
double   open.synthProfitP;
double   open.synthRunupP;                   // max synthetic runup distance
double   open.synthDrawdownP;                // ...

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

#include <ea/h1-breakout/init.mqh>
#include <ea/h1-breakout/deinit.mqh>

#include <ea/common/CalculateMagicNumber.mqh>
#include <ea/common/CalculateStats.mqh>
#include <ea/common/CreateInstanceId.mqh>
#include <ea/common/GetLogFilename.mqh>
#include <ea/common/IsMyOrder.mqh>
#include <ea/common/IsTestInstance.mqh>
#include <ea/common/RestoreInstance.mqh>
#include <ea/common/SetInstanceId.mqh>
#include <ea/common/ValidateInputs.ID.mqh>
#include <ea/common/onInputError.mqh>

#include <ea/common/ShowTradeHistory.mqh>
#include <ea/common/ToggleOpenOrders.mqh>
#include <ea/common/ToggleTradeHistory.mqh>

#include <ea/common/metric/ToggleMetrics.mqh>

#include <ea/common/status/StatusToStr.mqh>
#include <ea/common/status/StatusDescription.mqh>
#include <ea/common/status/SS.InstanceName.mqh>
#include <ea/common/status/SS.OpenLots.mqh>
#include <ea/common/status/SS.ClosedTrades.mqh>
#include <ea/common/status/SS.TotalProfit.mqh>
#include <ea/common/status/SS.ProfitStats.mqh>

#include <ea/common/status/file/FindStatusFile.mqh>
#include <ea/common/status/file/GetStatusFilename.mqh>
#include <ea/common/status/file/ReadStatus.HistoryRecord.mqh>
#include <ea/common/status/file/ReadStatus.TradeHistory.mqh>
#include <ea/common/status/file/SaveStatus.OpenPosition.mqh>
#include <ea/common/status/file/SaveStatus.TradeHistory.mqh>

#include <ea/common/trade/AddHistoryRecord.mqh>
#include <ea/common/trade/HistoryRecordToStr.mqh>

#include <ea/common/volatile/StoreVolatileData.mqh>
#include <ea/common/volatile/RestoreVolatileData.mqh>
#include <ea/common/volatile/RemoveVolatileData.mqh>


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

   if (cmd == "toggle-metrics") {
      int direction = ifInt(keys & F_VK_SHIFT, METRIC_PREVIOUS, METRIC_NEXT);
      return(ToggleMetrics(direction, METRIC_TOTAL_NET_MONEY, METRIC_TOTAL_SYNTH_UNITS));
   }
   else if (cmd == "toggle-open-orders") {
      return(ToggleOpenOrders());
   }
   else if (cmd == "toggle-trade-history") {
      return(ToggleTradeHistory());
   }
   else return(!logNotice("onCommand(1)  "+ instance.name +" unsupported command: "+ DoubleQuoteStr(fullCmd)));

   return(!logWarn("onCommand(2)  "+ instance.name +" cannot execute command "+ DoubleQuoteStr(fullCmd) +" in status "+ StatusToStr(instance.status)));
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
   instance.name               = GetIniStringA(file, section, "instance.name", "");             // string   instance.name            = ID.123
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

   // [Trade history]
   return(ReadStatus.TradeHistory(file, "Trade history"));
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
   bool fileExists = IsFile(file, MODE_SYSTEM);
   if (!fileExists) separator = CRLF;                          // an empty line separator
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
   if (SaveStatus.OpenPosition(file, fileExists, "Open positions")) return(false);

   // [Trade history]
   return(SaveStatus.TradeHistory(file, fileExists, "Trade history"));
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
