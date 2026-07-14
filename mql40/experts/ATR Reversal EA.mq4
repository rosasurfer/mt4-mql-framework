/**
 * ATR Reversal EA
 *
 *
 * DISCLAIMER:
 *  This strategy is work in progress and is provided for educational purposes only. Use it entirely at your own risk.
 *  It may contain bugs or logic errors that could result in financial loss. Do NOT use this strategy with real money
 *  until you have performed extensive testing and validation in a demo account.
 */
#define STRATEGY_ID  113                                             // unique strategy id

#include <rsf/stddefines.mqh>
int   __InitFlags[] = {INIT_PIPVALUE, INIT_BUFFERED_LOG};
int __DeinitFlags[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern string Instance.ID                    = "";                   // instance to load from a status file, format "[T]123"

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// framework
#include <rsf/core/expert.mqh>
#include <rsf/core/expert.recorder.mqh>
#include <rsf/stdfunctions.mqh>
#include <rsf/stdlib.mqh>
#include <rsf/functions/chartlegend.mqh>
#include <rsf/functions/HandleCommands.mqh>
#include <rsf/functions/InitializeByteBuffer.mqh>
#include <rsf/functions/ObjectCreateRegister.mqh>
#include <rsf/structs/OrderExecution.mqh>

// EA definitions
#include <rsf/experts/instance/defines.mqh>
#include <rsf/experts/metric/defines.mqh>
#include <rsf/experts/status/defines.mqh>
#include <rsf/experts/test/defines.mqh>
#include <rsf/experts/trade/defines.mqh>
#include <rsf/experts/trade/signal/defines.mqh>
#include <rsf/experts/trade/stats/defines.mqh>

// EA functions
#include <rsf/experts/instance/CreateInstanceId.mqh>
#include <rsf/experts/instance/IsTestInstance.mqh>
#include <rsf/experts/instance/RestoreInstance.mqh>
#include <rsf/experts/instance/SetInstanceId.mqh>

#include <rsf/experts/log/GetLogFileName.mqh>

#include <rsf/experts/metric/GetMT4SymbolDefinition.mqh>

#include <rsf/experts/status/ShowOpenOrders.mqh>
#include <rsf/experts/status/ShowTradeHistory.mqh>
#include <rsf/experts/status/SS.MetricDescription.mqh>
#include <rsf/experts/status/SS.OpenLots.mqh>
#include <rsf/experts/status/SS.ClosedTrades.mqh>
#include <rsf/experts/status/SS.TotalProfit.mqh>
#include <rsf/experts/status/SS.ProfitStats.mqh>
#include <rsf/experts/status/StatusToStr.mqh>
#include <rsf/experts/status/StatusDescription.mqh>

#include <rsf/experts/status/file/FindStatusFile.mqh>
#include <rsf/experts/status/file/GetStatusFileName.mqh>
#include <rsf/experts/status/file/SetStatusFileName.mqh>
#include <rsf/experts/status/file/ReadStatus.General.mqh>
#include <rsf/experts/status/file/ReadStatus.HistoryRecord.mqh>
#include <rsf/experts/status/file/ReadStatus.OpenPosition.mqh>
#include <rsf/experts/status/file/ReadStatus.TradeHistory.mqh>
#include <rsf/experts/status/file/ReadStatus.TradeStats.mqh>
#include <rsf/experts/status/file/SaveStatus.General.mqh>
#include <rsf/experts/status/file/SaveStatus.OpenPosition.mqh>
#include <rsf/experts/status/file/SaveStatus.TradeHistory.mqh>
#include <rsf/experts/status/file/SaveStatus.TradeStats.mqh>

#include <rsf/experts/status/volatile/StoreVolatileStatus.mqh>
#include <rsf/experts/status/volatile/RestoreVolatileStatus.mqh>
#include <rsf/experts/status/volatile/RemoveVolatileStatus.mqh>
#include <rsf/experts/status/volatile/ToggleOpenOrders.mqh>
#include <rsf/experts/status/volatile/ToggleTradeHistory.mqh>
#include <rsf/experts/status/volatile/ToggleMetrics.mqh>
#include <rsf/experts/status/volatile/ToggleProfitUnit.mqh>

#include <rsf/experts/test/ReadTestConfiguration.mqh>

#include <rsf/experts/trade/AddHistoryRecord.mqh>
#include <rsf/experts/trade/CalculateMagicNumber.mqh>
#include <rsf/experts/trade/ComposePositionCloseMsg.mqh>
#include <rsf/experts/trade/HistoryRecordToStr.mqh>
#include <rsf/experts/trade/IsMyOrder.mqh>
#include <rsf/experts/trade/MovePositionToHistory.mqh>
#include <rsf/experts/trade/onPositionClose.mqh>

#include <rsf/experts/trade/signal/SignalTypeToStr.mqh>

#include <rsf/experts/trade/stats/CalculateStats.mqh>

#include <rsf/experts/validation/ValidateInputs.ID.mqh>
#include <rsf/experts/validation/onInputError.mqh>

// init/deinit
#include <rsf/experts/init.mqh>
#include <rsf/experts/deinit.mqh>


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   if (!instance.status) return(catch("onTick(1)  illegal instance.status: "+ instance.status, ERR_ILLEGAL_STATE));

   return(last_error);
}


/**
 * Process an incoming command.
 *
 * @param  string cmd    - command name
 * @param  string params - command parameters
 * @param  int    keys   - flags of pressed modifier keys
 *
 * @return bool - success status of the executed command
 */
bool onCommand(string cmd, string params, int keys) {
   string fullCmd = cmd +":"+ params +":"+ keys;
   fullCmd = StrLeftTo(fullCmd, "::0");

   if (cmd == "start") {
      switch (instance.status) {
         case STATUS_STOPPED:
            logInfo("onCommand(1)  "+ instance.name +" command "+ DoubleQuoteStr(fullCmd));
            instance.status = STATUS_WAITING;
            return(SaveStatus());
      }
   }
   else if (cmd == "stop") {
      switch (instance.status) {
         case STATUS_WAITING:
         case STATUS_TRADING:
            logInfo("onCommand(2)  "+ instance.name +" command "+ DoubleQuoteStr(fullCmd));
            double dNull[] = {0,0,0};
            return(StopTrading(dNull));
      }
   }
   else if (cmd == "toggle-percent") {
      return(ToggleProfitUnit());
   }
   else if (cmd == "toggle-metrics") {
      int direction = ifInt(keys & F_VK_SHIFT, METRIC_PREVIOUS, METRIC_NEXT);
      return(ToggleMetrics(direction, METRIC_NET_MONEY, METRIC_SIG_UNITS));
   }
   else if (cmd == "toggle-open-orders") {
      return(ToggleOpenOrders());
   }
   else if (cmd == "toggle-trade-history") {
      return(ToggleTradeHistory());
   }
   else {
      return(!logNotice("onCommand(3)  "+ instance.name +" unsupported command: "+ DoubleQuoteStr(fullCmd)));
   }

   return(!logWarn("onCommand(4)  "+ instance.name +" cannot execute command "+ DoubleQuoteStr(fullCmd) +" in status "+ StatusToStr(instance.status)));
}


/**
 * Close open positions and stop trading. Depending on the passed trigger condition status changes to "waiting" or "stopped".
 *
 * @param  double trigger[] - trigger condition causing the call
 *
 * @return bool - success status
 */
bool StopTrading(double trigger[]) {
   if (last_error != NULL)                                                 return(false);
   if (instance.status!=STATUS_WAITING && instance.status!=STATUS_TRADING) return(!catch("StopTrading(1)  "+ instance.name +" cannot stop "+ StatusDescription(instance.status) +" instance", ERR_ILLEGAL_STATE));

   int    sigType  = trigger[SIG_TYPE];
   double sigPrice = trigger[SIG_PRICE];
   int    sigOp    = trigger[SIG_OP];

   // close an open position
   if (instance.status == STATUS_TRADING) {
      if (open.ticket > 0) {
         int oe[];
         if (!OrderCloseEx(open.ticket, NULL, order.slippage, CLR_CLOSED, NULL, oe)) return(!SetLastError(oe.Error(oe)));

         double closePrice = NormalizeDouble(oe.ClosePrice(oe), Digits), closePriceSig = ifDouble(sigType==SIG_TYPE_ZIGZAG, sigPrice, _Bid);
         open.slippageP    = NormalizeDouble(open.slippageP + oe.Slippage(oe), Digits);
         open.swapM        = NormalizeDouble(oe.Swap(oe), 2);
         open.commissionM  = NormalizeDouble(oe.Commission(oe), 2);
         open.grossProfitM = NormalizeDouble(oe.Profit(oe), 2);
         open.netProfitM   = NormalizeDouble(open.grossProfitM + open.swapM + open.commissionM, 2);
         open.netProfitP   = NormalizeDouble(ifDouble(open.type==OP_BUY, closePrice-open.price, open.price-closePrice), Digits);
         open.runupP       = MathMax(open.runupP, open.netProfitP);
         open.rundownP     = MathMin(open.rundownP, open.netProfitP); open.netProfitP = NormalizeDouble(open.netProfitP + (open.swapM + open.commissionM)/PointValue(open.lots), Digits);
         open.sigProfitP   = NormalizeDouble(ifDouble(open.type==OP_BUY, closePriceSig-open.priceSig, open.priceSig-closePriceSig), Digits);
         open.sigRunupP    = MathMax(open.sigRunupP, open.sigProfitP);
         open.sigRundownP  = MathMin(open.sigRundownP, open.sigProfitP);

         if (!MovePositionToHistory(oe.CloseTime(oe), closePrice, closePriceSig)) return(false);

         stats[METRIC_NET_MONEY][S_OPEN_PROFIT] = open.netProfitM;
         stats[METRIC_NET_UNITS][S_OPEN_PROFIT] = open.netProfitP;
         stats[METRIC_SIG_UNITS][S_OPEN_PROFIT] = open.sigProfitP;

         for (int i=1; i <= 3; i++) {
            stats[i][S_TOTAL_PROFIT    ] = stats[i][S_OPEN_PROFIT] + stats[i][S_CLOSED_PROFIT];
            stats[i][S_MAX_PROFIT      ] = MathMax(stats[i][S_MAX_PROFIT      ], stats[i][S_TOTAL_PROFIT]);
            stats[i][S_MAX_ABS_DRAWDOWN] = MathMin(stats[i][S_MAX_ABS_DRAWDOWN], stats[i][S_TOTAL_PROFIT]);
            stats[i][S_MAX_REL_DRAWDOWN] = MathMin(stats[i][S_MAX_REL_DRAWDOWN], stats[i][S_TOTAL_PROFIT] - stats[i][S_MAX_PROFIT]);

            stats[i][S_TOTAL_PROFIT    ] = NormalizeDouble(stats[i][S_TOTAL_PROFIT    ], 2);
            stats[i][S_MAX_REL_DRAWDOWN] = NormalizeDouble(stats[i][S_MAX_REL_DRAWDOWN], 2);
         }
      }
   }

   // update stop conditions and status
   switch (sigType) {
      case NULL:                                            // explicit stop (manual) or end of test
         instance.status = STATUS_STOPPED;
         break;

      default:
         return(!catch("StopTrading(2)  "+ instance.name +" invalid parameter SIG_TYPE: "+ sigType, ERR_INVALID_PARAMETER));
   }
   if (instance.status == STATUS_STOPPED) instance.stopped = Tick.time;

   bool isLogInfo = IsLogInfo();

   if (__isChart || isLogInfo) {
      SS.TotalProfit();
      SS.ProfitStats();

      string message = "StopTrading(3)  "+ instance.name +" "+ ifString(__isTesting && !sigType, "test ", "") +"stopped"+ ifString(!sigType, "", " ("+ SignalTypeToStr(sigType) +")") +", profit: "+ status.totalProfit +" "+ status.profitStats;
      if (isLogInfo) logInfo(message);
      message = Symbol() +","+ PeriodDescription() +": "+ WindowExpertName() +"::"+ message;
   }
   SaveStatus();

   // pause/stop the tester according to the debug configuration
   if (__isTesting) {
      if      (!IsVisualMode())          { if (instance.status == STATUS_STOPPED) Tester.Stop ("StopTrading(4)"); }
      else if (sigType == SIG_TYPE_TIME) { if (test.onSessionBreakPause)          Tester.Pause("StopTrading(5)"); }
      else                               { if (test.onStopPause)                  Tester.Pause("StopTrading(6)"); }
   }
   return(!catch("StopTrading(7)"));
}


/**
 * Update client-side order status and PnL.
 *
 * @return bool - success status
 */
bool UpdateStatus() {
   if (last_error || instance.status!=STATUS_TRADING) return(false);
   if (!open.ticket)                                  return(true);

   // update open position
   if (!SelectTicket(open.ticket, "UpdateStatus(1)")) return(false);
   bool isClosed = (OrderCloseTime() != NULL);
   if (isClosed) {
      double exitPrice=OrderClosePrice(), exitPriceSig=exitPrice;
   }
   else {
      exitPrice = ifDouble(open.type==OP_BUY, _Bid, _Ask);
      exitPriceSig = _Bid;
   }
   open.swapM        = NormalizeDouble(OrderSwap(), 2);
   open.commissionM  = NormalizeDouble(OrderCommission(), 2);
   open.grossProfitM = NormalizeDouble(OrderProfit(), 2);
   open.netProfitM   = NormalizeDouble(open.grossProfitM + open.swapM + open.commissionM, 2);
   open.netProfitP   = NormalizeDouble(ifDouble(open.type==OP_BUY, exitPrice-open.price, open.price-exitPrice), Digits);
   open.runupP       = MathMax(open.runupP, open.netProfitP);
   open.rundownP     = MathMin(open.rundownP, open.netProfitP); if (open.swapM || open.commissionM) open.netProfitP = NormalizeDouble(open.netProfitP + (open.swapM + open.commissionM)/PointValue(open.lots), Digits);
   open.sigProfitP   = NormalizeDouble(ifDouble(open.type==OP_BUY, exitPriceSig-open.priceSig, open.priceSig-exitPriceSig), Digits);
   open.sigRunupP    = MathMax(open.sigRunupP, open.sigProfitP);
   open.sigRundownP  = MathMin(open.sigRundownP, open.sigProfitP);

   if (isClosed) {
      int error;
      if (IsError(onPositionClose("UpdateStatus(2)  "+ instance.name +" "+ ComposePositionCloseMsg(error), error))) return(false);
      if (!MovePositionToHistory(OrderCloseTime(), exitPrice, exitPriceSig))                                        return(false);
      if (error == ERR_CONCURRENT_MODIFICATION) {
         SendChartCommand("EA.command", "stop");            // asynchronously stop the sequence
      }
   }

   // update PnL stats
   stats[METRIC_NET_MONEY][S_OPEN_PROFIT] = open.netProfitM;
   stats[METRIC_NET_UNITS][S_OPEN_PROFIT] = open.netProfitP;
   stats[METRIC_SIG_UNITS][S_OPEN_PROFIT] = open.sigProfitP;

   for (int i=1; i <= 3; i++) {
      stats[i][S_TOTAL_PROFIT    ] = stats[i][S_OPEN_PROFIT] + stats[i][S_CLOSED_PROFIT];
      stats[i][S_MAX_PROFIT      ] = MathMax(stats[i][S_MAX_PROFIT      ], stats[i][S_TOTAL_PROFIT]);
      stats[i][S_MAX_ABS_DRAWDOWN] = MathMin(stats[i][S_MAX_ABS_DRAWDOWN], stats[i][S_TOTAL_PROFIT]);
      stats[i][S_MAX_REL_DRAWDOWN] = MathMin(stats[i][S_MAX_REL_DRAWDOWN], stats[i][S_TOTAL_PROFIT] - stats[i][S_MAX_PROFIT]);

      stats[i][S_TOTAL_PROFIT    ] = NormalizeDouble(stats[i][S_TOTAL_PROFIT    ], 2);
      stats[i][S_MAX_REL_DRAWDOWN] = NormalizeDouble(stats[i][S_MAX_REL_DRAWDOWN], 2);
   }

   if (__isChart) {
      SS.TotalProfit();
      SS.ProfitStats();
   }
   return(!catch("UpdateStatus(3)"));
}


/**
 * Callback function invoked by the global error handler.
 */
void EmergencyStop() {
   logWarn("EmergencyStop(1)  "+ instance.name, ERR_NOT_IMPLEMENTED);
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

   string section="", separator="", file=GetStatusFileName();
   bool fileExists = IsFile(file, MODE_SYSTEM);
   if (!fileExists) separator = CRLF;                          // an empty line separator
   SS.All();                                                   // update trade stats and global string representations

   // [General]
   if (!SaveStatus.General(file, fileExists)) return(false);   // account, symbol and test infos

   // [Inputs]
   section = "Inputs";
   WriteIniString(file, section, "Instance.ID",                /*string  */ Instance.ID);
   WriteIniString(file, section, "EA.Recorder",                /*string  */ EA.Recorder + separator);

   // trade stats
   if (!SaveStatus.TradeStats(file, fileExists)) return(false);

   // [Runtime status]
   section = "Runtime status";
   WriteIniString(file, section, "instance.id",                /*int     */ instance.id);
   WriteIniString(file, section, "instance.name",              /*string  */ instance.name);
   WriteIniString(file, section, "instance.created",           /*datetime*/ instance.created + GmtTimeFormat(instance.created, " (%a, %Y.%m.%d %H:%M:%S)"));
   WriteIniString(file, section, "instance.started",           /*datetime*/ instance.started + ifString(!instance.started, "", GmtTimeFormat(instance.started, " (%a, %Y.%m.%d %H:%M:%S)")));
   WriteIniString(file, section, "instance.stopped",           /*datetime*/ instance.stopped + ifString(!instance.stopped, "", GmtTimeFormat(instance.stopped, " (%a, %Y.%m.%d %H:%M:%S)")));
   WriteIniString(file, section, "instance.isTest",            /*bool    */ instance.isTest);
   WriteIniString(file, section, "instance.status",            /*int     */ instance.status +" ("+ StatusDescription(instance.status) +")");
   WriteIniString(file, section, "instance.startEquity",       /*double  */ DoubleToStr(instance.startEquity, 2));
   WriteIniString(file, section, "recorder.stdEquitySymbol",   /*string  */ recorder.stdEquitySymbol + separator);

   // open/closed trades
   if (!SaveStatus.OpenPosition(file, fileExists)) return(false);
   if (!SaveStatus.TradeHistory(file, fileExists)) return(false);

   return(!catch("SaveStatus(2)"));
}


/**
 * Read the status file of an instance and restore inputs and runtime variables. Called only from RestoreInstance().
 *
 * @return bool - success status
 */
bool ReadStatus() {
   if (IsLastError()) return(false);
   if (!instance.id)  return(!catch("ReadStatus(1)  "+ instance.name +" illegal value of instance.id: "+ instance.id, ERR_ILLEGAL_STATE));

   string file = GetStatusFileName(), section = "";
   if (file == "")                 return(!catch("ReadStatus(2)  "+ instance.name +" error reading the status file", ERR_RUNTIME_ERROR));
   if (!IsFile(file, MODE_SYSTEM)) return(!catch("ReadStatus(3)  "+ instance.name +" file \""+ file +"\" not found", ERR_FILE_NOT_FOUND));

   // [General]
   if (!ReadStatus.General(file)) return(false);

   // [Inputs]
   section = "Inputs";
   Instance.ID              = GetIniStringA(file, section, "Instance.ID", "");                  // string   Instance.ID              = T123
   EA.Recorder              = GetIniStringA(file, section, "EA.Recorder", "");                  // string   EA.Recorder              = 1,2,4

   // [Runtime status]
   section = "Runtime status";
   instance.id              = GetIniInt    (file, section, "instance.id"         );             // int      instance.id              = 123
   instance.name            = GetIniStringA(file, section, "instance.name",    "");             // string   instance.name            = Z.123
   instance.created         = GetIniInt    (file, section, "instance.created"    );             // datetime instance.created         = 1624924800 (Mon, 2021.05.12 13:22:34)
   instance.started         = GetIniInt    (file, section, "instance.started"    );             // datetime instance.started         = 1624924800 (Mon, 2021.05.12 13:22:34)
   instance.stopped         = GetIniInt    (file, section, "instance.stopped"    );             // datetime instance.stopped         = 1624924800 (Mon, 2021.05.12 13:22:34)
   instance.isTest          = GetIniBool   (file, section, "instance.isTest"     );             // bool     instance.isTest          = 1
   instance.status          = GetIniInt    (file, section, "instance.status"     );             // int      instance.status          = 1 (waiting)
   instance.startEquity     = GetIniDouble (file, section, "instance.startEquity");             // double   instance.startEquity     = 1000.00
   recorder.stdEquitySymbol = GetIniStringA(file, section, "recorder.stdEquitySymbol", "");     // string   recorder.stdEquitySymbol = GBPJPY.001
   SS.InstanceName();

   // open/closed trades and stats
   if (!ReadStatus.OpenPosition(file)) return(false);
   if (!ReadStatus.TradeHistory(file)) return(false);
   if (!ReadStatus.TradeStats(file))   return(false);

   return(!catch("ReadStatus(4)"));
}


/**
 * Synchronize local status with current status on the trade server. Called from RestoreInstance() only.
 *
 * @return bool - success status
 */
bool SynchronizeStatus() {
   if (IsLastError()) return(false);

   int prevOpenTicket  = open.ticket;
   int prevHistorySize = ArrayRange(history, 0);

   // detect and handle orphaned open positions
   int orders = OrdersTotal();
   for (int i=0; i < orders; i++) {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) break;        // FALSE: an open order was closed/deleted in another thread
      if (IsMyOrder(instance.id)) {
         if (IsPendingOrderType(OrderType())) {
            logWarn("SynchronizeStatus(1)  "+ instance.name +" unsupported pending order found: #"+ OrderTicket() +", ignoring it...");
            continue;
         }
         if (!open.ticket) {
            logWarn("SynchronizeStatus(2)  "+ instance.name +" orphaned open position found: #"+ OrderTicket() +", adding to instance...");
            open.ticket    = OrderTicket();
            open.type      = OrderType();
            open.time      = OrderOpenTime();
            open.price     = OrderOpenPrice();
            open.priceSig  = open.price;
            open.slippageP = NULL;                                    // open PnL numbers will auto-update in the following UpdateStatus() call
         }
         else if (OrderTicket() != open.ticket) {
            return(!catch("SynchronizeStatus(3)  "+ instance.name +" orphaned open position found: #"+ OrderTicket(), ERR_RUNTIME_ERROR));
         }
      }
   }

   // update open position status
   if (open.ticket > 0) {
      if (!UpdateStatus()) return(false);
   }

   // detect and handle orphaned closed trades
   orders = OrdersHistoryTotal();
   for (i=0; i < orders; i++) {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) break;       // FALSE: the visible history range was modified in another thread
      if (IsPendingOrderType(OrderType()))              continue;    // skip deleted pending orders

      if (IsMyOrder(instance.id)) {
         if (!IsLocalClosedPosition(OrderTicket())) {
            int      ticket       = OrderTicket();
            double   lots         = OrderLots();
            int      openType     = OrderType();
            datetime openTime     = OrderOpenTime();
            double   openPrice    = OrderOpenPrice();
            double   stopLoss     = OrderStopLoss();
            double   takeProfit   = OrderTakeProfit();
            datetime closeTime    = OrderCloseTime();
            double   closePrice   = OrderClosePrice();
            double   slippageP    = 0;
            double   swapM        = NormalizeDouble(OrderSwap(), 2);
            double   commissionM  = OrderCommission();
            double   grossProfitM = OrderProfit();
            double   grossProfitP = NormalizeDouble(ifDouble(!openType, closePrice-openPrice, openPrice-closePrice), Digits);
            double   netProfitM   = NormalizeDouble(grossProfitM + swapM + commissionM, 2);
            double   netProfitP   = NormalizeDouble(grossProfitP + MathDiv(swapM + commissionM, PointValue(lots)), Digits);

            logWarn("SynchronizeStatus(4)  "+ instance.name +" orphaned closed position found: #"+ ticket +", adding to instance...");
            if (IsEmpty(AddHistoryRecord(ticket, 0, 0, openType, lots, 1, openTime, openPrice, openPrice, stopLoss, takeProfit, closeTime, closePrice, closePrice, slippageP, swapM, commissionM, grossProfitM, netProfitM, netProfitP, grossProfitP, grossProfitP, grossProfitP, grossProfitP, grossProfitP))) return(false);

            // update closed PL numbers
            stats[METRIC_NET_MONEY][S_CLOSED_PROFIT] += netProfitM;
            stats[METRIC_NET_UNITS][S_CLOSED_PROFIT] += netProfitP;
            stats[METRIC_SIG_UNITS][S_CLOSED_PROFIT] += grossProfitP;   // for orphaned positions same as grossProfitP

            stats[METRIC_NET_MONEY][S_CLOSED_PROFIT] = NormalizeDouble(stats[METRIC_NET_MONEY][S_CLOSED_PROFIT], 2);
            stats[METRIC_NET_UNITS][S_CLOSED_PROFIT] = NormalizeDouble(stats[METRIC_NET_UNITS][S_CLOSED_PROFIT], Digits);
            stats[METRIC_SIG_UNITS][S_CLOSED_PROFIT] = NormalizeDouble(stats[METRIC_SIG_UNITS][S_CLOSED_PROFIT], Digits);
         }
      }
   }

   // recalculate total PL numbers
   for (i=1; i <= 3; i++) {
      stats[i][S_TOTAL_PROFIT    ] = stats[i][S_OPEN_PROFIT] + stats[i][S_CLOSED_PROFIT];
      stats[i][S_MAX_PROFIT      ] = MathMax(stats[i][S_MAX_PROFIT      ], stats[i][S_TOTAL_PROFIT]);
      stats[i][S_MAX_ABS_DRAWDOWN] = MathMin(stats[i][S_MAX_ABS_DRAWDOWN], stats[i][S_TOTAL_PROFIT]);
      stats[i][S_MAX_REL_DRAWDOWN] = MathMin(stats[i][S_MAX_REL_DRAWDOWN], stats[i][S_TOTAL_PROFIT] - stats[i][S_MAX_PROFIT]);

      stats[i][S_TOTAL_PROFIT    ] = NormalizeDouble(stats[i][S_TOTAL_PROFIT    ], 2);
      stats[i][S_MAX_REL_DRAWDOWN] = NormalizeDouble(stats[i][S_MAX_REL_DRAWDOWN], 2);
   }
   SS.All();

   if (open.ticket != prevOpenTicket || ArrayRange(history, 0) != prevHistorySize) {
      CalculateStats(true);
      return(SaveStatus());                                             // immediately save status if orders changed
   }
   return(!catch("SynchronizeStatus(5)"));
}


/**
 * Whether the specified ticket exists in the local history of closed positions.
 *
 * @param  int ticket
 *
 * @return bool
 */
bool IsLocalClosedPosition(int ticket) {
   int size = ArrayRange(history, 0);
   for (int i=0; i < size; i++) {
      if (history[i][H_TICKET] == ticket) return(true);
   }
   return(false);
}


// backed-up input parameters
string prev.Instance.ID = "";


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
   prev.Instance.ID = StringConcatenate(Instance.ID, "");   // string inputs are references to internal C literals
   Recorder_BackupInputs();
}


/**
 * Restore backed-up input parameters and runtime variables. Called from onInitParameters() and onInitTimeframeChange().
 */
void RestoreInputs() {
   // input parameters
   Instance.ID = prev.Instance.ID;
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
   bool instanceWasStarted = (open.ticket || ArrayRange(history, 0));

   // Instance.ID
   if (isInitParameters) {                                        // otherwise the id was validated in ValidateInputs.ID()
      if (StrTrim(Instance.ID) == "") {                           // the id was deleted or not yet set, re-apply the internal id
         Instance.ID = prev.Instance.ID;
      }
      else if (Instance.ID != prev.Instance.ID) return(!onInputError("ValidateInputs(1)  "+ instance.name +" switching to another instance is not supported (unload the EA first)"));
   }

   // EA.Recorder: on | off* | 1,2,3=1000,...
   if (!Recorder_ValidateInputs(IsTestInstance())) return(false);

   SS.All();
   return(!catch("ValidateInputs(2)"));
}


/**
 * ShowStatus: Update all string representations.
 */
void SS.All() {
   SS.InstanceName();
   SS.MetricDescription();
   SS.OpenLots();
   SS.ClosedTrades();
   SS.TotalProfit();
   SS.ProfitStats();
}


/**
 * ShowStatus: Update the string representation of the instance name.
 */
void SS.InstanceName() {
   if (!instance.id) {
      // calling SS.All() and thus SS.InstanceName() before CreateInstanceId() is valid (e.g. after input validation of a new instance)
      instance.name = "ATRR.";
   }
   else {
      instance.name = "ATRR."+ StrPadLeft(instance.id, 3, "0");
   }
}


/**
 * Creates the status display box. Consists of overlapping rectangles made of font "Webdings", character "g".
 * Called from onInit() only.
 *
 * @return string - comment prefix to be used by composition of the status display (adapts to existing chart legends)
 */
string CreateStatusBox() {
   if (!__isChart) return("");

   int x[] = {2, 102};                                      // x-offset of the rectangles forming the status box
   int sizeofX = ArraySize(x);                              // number of used rectangles
   int legends = CountChartLegends();                       // number of existing chart legends
   int fontSize = 76;                                       // rectangle fontsize
   color bgColor = LemonChiffon;                            // rectangle color

   // comment line tops: 16, 28, 40, 52, 64 ... => x * 12 + 4
   // legend lines bottoms: 36, 55, 74, 93 ...  => x * 19 + 17

   // calculate the bottom offset of existing chart legends
   int legendsBottomOffset = 0;
   if (legends > 0) {
      legendsBottomOffset = legends * chartlegend.lineHeight + (chartlegend.lineHeight-chartlegend.lineDistance);
   }

   // add 1px statusbox distance + 1px statusbox padding (2px)
   int commentsOffset = legendsBottomOffset + 2;
   int firstLine = MathCeil((commentsOffset - 4)/12.0);
   firstLine = Max(firstLine, 2);                           // terminal comments start at offset of line 2
   int statusboxOffset = firstLine * 12 + 4 - 1;            // -1px padding top

   // create status box
   for (int i=0; i < sizeofX; i++) {
      string label = StringConcatenate(WindowExpertName(), ".statusbox.", i+1);
      if (ObjectFind(label) == -1) if (!ObjectCreateRegister(label, OBJ_LABEL)) return("");
      ObjectSet(label, OBJPROP_CORNER, CORNER_TOP_LEFT);
      ObjectSet(label, OBJPROP_XDISTANCE, x[i]);
      ObjectSet(label, OBJPROP_YDISTANCE, statusboxOffset);
      ObjectSetText(label, "g", fontSize, "Webdings", bgColor);
   }

   // return the resulting comment prefix/spacer
   return(StrRepeat(NL, firstLine-1));
}


/**
 * Return a string representation of all input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("Instance.ID=", DoubleQuoteStr(Instance.ID), ";"));
}
