/**
 * H1 Breakout
 *
 * A strategy for breakouts from a time range.
 *
 *  @see  https://www.forexfactory.com/thread/902048-london-open-breakout-strategy-for-gbpusd#         [London Open Breakout]
 *  @see  https://nexusfi.com/trading-journals/36245-london-session-opening-range-breakout-gbp.html# [Asian session breakout]
 *  @see  GBPAUD, GBPUSD FF Opening Range Breakout (07:00-08:00, 08:00-09:00)
 *
 *
 * TODO:
 *  - self-optimize the best bracket hour over the last few weeks
 */
#define STRATEGY_ID  111                     // unique strategy id (used for generation of magic order numbers)

#include <stddefines.mqh>
int   __InitFlags[] = {INIT_PIPVALUE, INIT_BUFFERED_LOG};
int __DeinitFlags[];
int __virtualTicks = 10000;                  // every 10 seconds to continue operation on a stalled data feed

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern string Instance.ID          = "";     // instance to load from a status file, format: "[T]123"

extern double Lots                 = 0.1;

extern int    Initial.TakeProfit   = 100;    // in punits (0: partial targets only or no TP)
extern int    Initial.StopLoss     = 50;     // in punits (0: moving stops only or no SL

extern int    Target1              = 0;      // in punits (0: no target)
extern int    Target1.ClosePercent = 0;      // size to close (0: nothing)
extern int    Target1.MoveStopTo   = 1;      // in punits (0: don't move stop)
extern int    Target2              = 0;      //
extern int    Target2.ClosePercent = 30;     //
extern int    Target2.MoveStopTo   = 0;      //
extern int    Target3              = 0;      //
extern int    Target3.ClosePercent = 30;     //
extern int    Target3.MoveStopTo   = 0;      //
extern int    Target4              = 0;      //
extern int    Target4.ClosePercent = 30;     //
extern int    Target4.MoveStopTo   = 0;      //

extern bool   ShowProfitInPercent  = false;  // whether PnL is displayed in money amounts or percent

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// framework
#include <core/expert.mqh>
#include <core/expert.recorder.mqh>
#include <stdfunctions.mqh>
#include <rsfLib.mqh>
#include <functions/HandleCommands.mqh>
#include <functions/InitializeByteBuffer.mqh>

// EA definitions
#include <ea/functions/instance/defines.mqh>
#include <ea/functions/metric/defines.mqh>
#include <ea/functions/status/defines.mqh>
#include <ea/functions/test/defines.mqh>
#include <ea/functions/trade/defines.mqh>
#include <ea/functions/trade/signal/defines.mqh>
#include <ea/functions/trade/stats/defines.mqh>

// EA functions
#include <ea/functions/instance/CreateInstanceId.mqh>
#include <ea/functions/instance/IsTestInstance.mqh>
#include <ea/functions/instance/RestoreInstance.mqh>
#include <ea/functions/instance/SetInstanceId.mqh>

#include <ea/functions/log/GetLogFilename.mqh>

#include <ea/functions/metric/GetMT4SymbolDefinition.mqh>
#include <ea/functions/metric/RecordMetrics.mqh>

#include <ea/functions/status/CreateStatusBox_6.mqh>
#include <ea/functions/status/ShowOpenOrders.mqh>
#include <ea/functions/status/ShowTradeHistory.mqh>
#include <ea/functions/status/ShowStatus.mqh>
#include <ea/functions/status/SS.All.mqh>
#include <ea/functions/status/SS.MetricDescription.mqh>
#include <ea/functions/status/SS.OpenLots.mqh>
#include <ea/functions/status/SS.ClosedTrades.mqh>
#include <ea/functions/status/SS.TotalProfit.mqh>
#include <ea/functions/status/SS.ProfitStats.mqh>
#include <ea/functions/status/StatusToStr.mqh>
#include <ea/functions/status/StatusDescription.mqh>

#include <ea/functions/status/file/FindStatusFile.mqh>
#include <ea/functions/status/file/GetStatusFilename.mqh>
#include <ea/functions/status/file/SetStatusFilename.mqh>
#include <ea/functions/status/file/ReadStatus.General.mqh>
#include <ea/functions/status/file/ReadStatus.Targets.mqh>
#include <ea/functions/status/file/ReadStatus.OpenPosition.mqh>
#include <ea/functions/status/file/ReadStatus.HistoryRecord.mqh>
#include <ea/functions/status/file/ReadStatus.TradeHistory.mqh>
#include <ea/functions/status/file/ReadStatus.TradeStats.mqh>
#include <ea/functions/status/file/SaveStatus.General.mqh>
#include <ea/functions/status/file/SaveStatus.Targets.mqh>
#include <ea/functions/status/file/SaveStatus.OpenPosition.mqh>
#include <ea/functions/status/file/SaveStatus.TradeHistory.mqh>
#include <ea/functions/status/file/SaveStatus.TradeStats.mqh>

#include <ea/functions/status/volatile/StoreVolatileStatus.mqh>
#include <ea/functions/status/volatile/RestoreVolatileStatus.mqh>
#include <ea/functions/status/volatile/RemoveVolatileStatus.mqh>
#include <ea/functions/status/volatile/ToggleOpenOrders.mqh>
#include <ea/functions/status/volatile/ToggleTradeHistory.mqh>
#include <ea/functions/status/volatile/ToggleMetrics.mqh>

#include <ea/functions/test/ReadTestConfiguration.mqh>

#include <ea/functions/trade/AddHistoryRecord.mqh>
#include <ea/functions/trade/CalculateMagicNumber.mqh>
#include <ea/functions/trade/HistoryRecordToStr.mqh>
#include <ea/functions/trade/IsMyOrder.mqh>

#include <ea/functions/trade/stats/CalculateStats.mqh>

#include <ea/functions/validation/ValidateInputs.ID.mqh>
#include <ea/functions/validation/ValidateInputs.Targets.mqh>
#include <ea/functions/validation/onInputError.mqh>

// init/deinit
#include <ea/init.mqh>
#include <ea/deinit.mqh>


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   if (!instance.status) return(catch("onTick(1)  illegal instance.status: "+ instance.status, ERR_ILLEGAL_STATE));
   double signal[3];

   if (__isChart) {
      if (!HandleCommands()) return(last_error);      // process incoming commands, may switch on/off the instance
   }

   if (instance.status != STATUS_STOPPED) {
      if (instance.status == STATUS_WAITING) {
         if (IsStartSignal(signal)) {
            StartTrading(signal);
         }
      }
      else if (instance.status == STATUS_TRADING) {
         UpdateStatus();

         if (IsStopSignal(signal)) {
            StopTrading(signal);
         }
         else {
            UpdateOpenOrders();
         }
      }
      RecordMetrics();
   }
   return(last_error);
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
      return(ToggleMetrics(direction, METRIC_NET_MONEY, METRIC_SIG_UNITS));
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
 * Whether an instance start condition evalutes to TRUE.
 *
 * @param  _Out_ double &signal[] - array receiving signal details
 *
 * @return bool
 */
bool IsStartSignal(double &signal[]) {
   if (last_error || instance.status!=STATUS_WAITING) return(false);
   return(!logNotice("IsStartSignal(1)  not implemented", ERR_NOT_IMPLEMENTED));
}


/**
 * Whether an instance stop condition evaluates to TRUE.
 *
 * @param  _Out_ double &signal[] - array receiving signal details
 *
 * @return bool
 */
bool IsStopSignal(double &signal[]) {
   if (last_error || (instance.status!=STATUS_WAITING && instance.status!=STATUS_TRADING)) return(false);
   return(!logNotice("IsStopSignal(1)  not implemented", ERR_NOT_IMPLEMENTED));
}


/**
 * Start/restart trading on a waiting or stopped instance.
 *
 * @param  double signal[] - signal infos causing the call
 *
 * @return bool - success status
 */
bool StartTrading(double signal[]) {
   if (last_error != NULL)                                                 return(false);
   if (instance.status!=STATUS_WAITING && instance.status!=STATUS_STOPPED) return(!catch("StartTrading(1)  "+ instance.name +" cannot start "+ StatusDescription(instance.status) +" instance", ERR_ILLEGAL_STATE));
   if (!signal[SIG_OP])                                                    return(!catch("StartTrading(2)  "+ instance.name +" invalid signal parameter SIG_OP: 0", ERR_INVALID_PARAMETER));

   return(SaveStatus());
}


/**
 * Stop trading and close open positions (if any).
 *
 * @param  double signal[] - signal infos causing the call
 *
 * @return bool - success status
 */
bool StopTrading(double signal[]) {
   if (last_error != NULL)                                                 return(false);
   if (instance.status!=STATUS_WAITING && instance.status!=STATUS_TRADING) return(!catch("StopTrading(1)  "+ instance.name +" cannot stop "+ StatusDescription(instance.status) +" instance", ERR_ILLEGAL_STATE));

   return(!logNotice("StopTrading(2)  not implemented", ERR_NOT_IMPLEMENTED));
}


/**
 * Update client-side order status and PnL.
 *
 * @return bool - success status
 */
bool UpdateStatus() {
   if (last_error || instance.status!=STATUS_TRADING) return(false);

   return(!catch("UpdateStatus(1)  not implemented", ERR_NOT_IMPLEMENTED));
}


/**
 * Manage server-side entry/exit limits, open positions and partial profits.
 *
 * @return bool - success status
 */
bool UpdateOpenOrders() {
   if (last_error != NULL) return(false);
   if (instance.status != STATUS_TRADING) return(!catch("UpdateOpenOrders(1)  "+ instance.name +" cannot update orders of "+ StatusDescription(instance.status) +" instance", ERR_ILLEGAL_STATE));

   return(!catch("UpdateOpenOrders(1)  not implemented", ERR_NOT_IMPLEMENTED));
}


/**
 * Read the status file of an instance and restore inputs and runtime variables. Called only from RestoreInstance().
 *
 * @return bool - success status
 */
bool ReadStatus() {
   if (IsLastError()) return(false);
   if (!instance.id)  return(!catch("ReadStatus(1)  "+ instance.name +" illegal value of instance.id: "+ instance.id, ERR_ILLEGAL_STATE));

   string section="", file=GetStatusFilename();
   if (file == "")                 return(!catch("ReadStatus(2)  "+ instance.name +" status file not found", ERR_RUNTIME_ERROR));
   if (!IsFile(file, MODE_SYSTEM)) return(!catch("ReadStatus(3)  "+ instance.name +" file \""+ file +"\" not found", ERR_FILE_NOT_FOUND));

   // [General]
   if (!ReadStatus.General(file)) return(false);

   // [Inputs]
   section = "Inputs";
   Instance.ID              = GetIniStringA(file, section, "Instance.ID",     "");           // string   Instance.ID         = T123
   Lots                     = GetIniDouble (file, section, "Lots"               );           // double   Lots                = 0.1
   if (!ReadStatus.Targets(file)) return(false);
   ShowProfitInPercent      = GetIniBool   (file, section, "ShowProfitInPercent");           // bool     ShowProfitInPercent = 1
   EA.Recorder              = GetIniStringA(file, section, "EA.Recorder",     "");           // string   EA.Recorder         = 1,2,4

   // [Runtime status]
   section = "Runtime status";
   instance.id              = GetIniInt    (file, section, "instance.id"      );             // int      instance.id              = 123
   instance.name            = GetIniStringA(file, section, "instance.name", "");             // string   instance.name            = ID.123
   instance.created         = GetIniInt    (file, section, "instance.created" );             // datetime instance.created         = 1624924800 (Mon, 2021.05.12 13:22:34)
   instance.isTest          = GetIniBool   (file, section, "instance.isTest"  );             // bool     instance.isTest          = 1
   instance.status          = GetIniInt    (file, section, "instance.status"  );             // int      instance.status          = 1 (waiting)
   recorder.stdEquitySymbol = GetIniStringA(file, section, "recorder.stdEquitySymbol", "");  // string   recorder.stdEquitySymbol = GBPJPY.001
   SS.InstanceName();

   // open/closed trades and stats
   if (!ReadStatus.TradeStats(file))   return(false);
   if (!ReadStatus.OpenPosition(file)) return(false);
   if (!ReadStatus.TradeHistory(file)) return(false);

   return(!catch("ReadStatus(4)"));
}


/**
 * Synchronize local status with current status on the trade server. Called from RestoreInstance() only.
 *
 * @return bool - success status
 */
bool SynchronizeStatus() {
   if (IsLastError()) return(false);

   // detect and handle orphaned open positions
   int orders = OrdersTotal();
   for (int i=0; i < orders; i++) {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) break;        // FALSE: an open order was closed/deleted in another thread
      if (IsMyOrder(instance.id)) {
         // TODO
      }
   }

   // detect and handle orphaned open positions
   orders = OrdersHistoryTotal();
   for (i=0; i < orders; i++) {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) break;       // FALSE: the visible history range was modified in another thread
      if (IsPendingOrderType(OrderType()))              continue;    // skip deleted pending orders

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
      if (test.reduceStatusWrites) {                           // in tester skip all writes except file creation, instance stop and test end
         static bool saved = false;
         if (saved && instance.status!=STATUS_STOPPED && __CoreFunction!=CF_DEINIT) return(true);
         saved = true;
      }
   }
   else if (IsTestInstance()) return(true);                    // don't modify the status file of a finished test

   string section="", separator="", file=GetStatusFilename();
   bool fileExists = IsFile(file, MODE_SYSTEM);
   if (!fileExists) separator = CRLF;                          // an empty line separator
   SS.All();                                                   // update trade stats and global string representations

   // [General]
   if (!SaveStatus.General(file, fileExists)) return(false);   // account and instrument infos

   // [Inputs]
   section = "Inputs";
   WriteIniString(file, section, "Instance.ID",                /*string  */ Instance.ID);
   WriteIniString(file, section, "Lots",                       /*double  */ NumberToStr(Lots, ".+"));
   if (!SaveStatus.Targets(file, fileExists)) return(false);   // StopLoss and TakeProfit targets
   WriteIniString(file, section, "ShowProfitInPercent",        /*bool    */ ShowProfitInPercent);
   WriteIniString(file, section, "EA.Recorder",                /*string  */ EA.Recorder + separator);

   // trade stats
   if (!SaveStatus.TradeStats(file, fileExists)) return(false);

   // [Runtime status]
   section = "Runtime status";
   WriteIniString(file, section, "instance.id",                /*int     */ instance.id);
   WriteIniString(file, section, "instance.name",              /*string  */ instance.name);
   WriteIniString(file, section, "instance.created",           /*datetime*/ instance.created + GmtTimeFormat(instance.created, " (%a, %Y.%m.%d %H:%M:%S)"));
   WriteIniString(file, section, "instance.isTest",            /*bool    */ instance.isTest);
   WriteIniString(file, section, "instance.status",            /*int     */ instance.status +" ("+ StatusDescription(instance.status) +")");
   WriteIniString(file, section, "recorder.stdEquitySymbol",   /*string  */ recorder.stdEquitySymbol + separator);

   // open/closed trades
   if (!SaveStatus.OpenPosition(file, fileExists)) return(false);
   if (!SaveStatus.TradeHistory(file, fileExists)) return(false);

   return(!catch("SaveStatus(2)"));
}


// backed-up input parameters
string   prev.Instance.ID = "";
double   prev.Lots;
bool     prev.ShowProfitInPercent;

// backed-up runtime variables affected by changing input parameters
int      prev.instance.id;
datetime prev.instance.created;
bool     prev.instance.isTest;
string   prev.instance.name = "";
int      prev.instance.status;


/**
 * When input parameters are changed at runtime, input errors must be handled gracefully. To enable the EA to continue in
 * case of input errors, it must be possible to restore previous valid inputs. This also applies to programmatic changes to
 * input parameters which do not survive init cycles. The previous input parameters are therefore backed up in deinit() and
 * can be restored in init() if necessary.
 *
 * Called in onDeinitParameters() and onDeinitChartChange().
 */
void BackupInputs() {
   // input parameters, used for comparison in ValidateInputs()
   prev.Instance.ID         = StringConcatenate(Instance.ID, "");    // string inputs are references to internal C literals
   prev.Lots                = Lots;
   prev.ShowProfitInPercent = ShowProfitInPercent;

   // affected runtime variables
   prev.instance.id      = instance.id;
   prev.instance.created = instance.created;
   prev.instance.isTest  = instance.isTest;
   prev.instance.name    = instance.name;
   prev.instance.status  = instance.status;

   BackupInputs.Targets();
   Recorder_BackupInputs();
}


/**
 * Restore backed-up input parameters and runtime variables. Called from onInitParameters() and onInitTimeframeChange().
 */
void RestoreInputs() {
   // input parameters
   Instance.ID         = prev.Instance.ID;
   Lots                = prev.Lots;
   ShowProfitInPercent = prev.ShowProfitInPercent;

   // affected runtime variables
   instance.id      = prev.instance.id;
   instance.created = prev.instance.created;
   instance.isTest  = prev.instance.isTest;
   instance.name    = prev.instance.name;
   instance.status  = prev.instance.status;

   RestoreInputs.Targets();
   Recorder_RestoreInputs();
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

   // Targets
   if (!ValidateInputs.Targets()) return(false);

   // EA.Recorder: on | off* | 1,2,3=1000,...
   if (!Recorder_ValidateInputs(IsTestInstance())) return(false);

   SS.All();
   return(!catch("ValidateInputs(4)"));
}


/**
 * ShowStatus: Update the string representation of the instance name.
 */
void SS.InstanceName() {
   instance.name = "HB."+ StrPadLeft(instance.id, 3, "0");
}


/**
 * Return a string representation of the input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("Instance.ID=",          DoubleQuoteStr(Instance.ID),    ";"+ NL +

                            "Lots=",                 NumberToStr(Lots, ".1+"),       ";"+ NL +
                            "Initial.TakeProfit=",   Initial.TakeProfit,             ";"+ NL +
                            "Initial.StopLoss=",     Initial.StopLoss,               ";"+ NL +
                            "Target1=",              Target1,                        ";"+ NL +
                            "Target1.ClosePercent=", Target1.ClosePercent,           ";"+ NL +
                            "Target1.MoveStopTo=",   Target1.MoveStopTo,             ";"+ NL +
                            "Target2=",              Target2,                        ";"+ NL +
                            "Target2.ClosePercent=", Target2.ClosePercent,           ";"+ NL +
                            "Target2.MoveStopTo=",   Target2.MoveStopTo,             ";"+ NL +
                            "Target3=",              Target3,                        ";"+ NL +
                            "Target3.ClosePercent=", Target3.ClosePercent,           ";"+ NL +
                            "Target3.MoveStopTo=",   Target3.MoveStopTo,             ";"+ NL +
                            "Target4=",              Target4,                        ";"+ NL +
                            "Target4.ClosePercent=", Target4.ClosePercent,           ";"+ NL +
                            "Target4.MoveStopTo=",   Target4.MoveStopTo,             ";"+ NL +

                            "ShowProfitInPercent=",  BoolToStr(ShowProfitInPercent), ";")
   );
}
