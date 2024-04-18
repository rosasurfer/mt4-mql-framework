/**
 * A strategy trading tunnel breakouts.
 *
 *
 * Requirements
 * ------------
 *  • MA Tunnel indicator: @see https://github.com/rosasurfer/mt4-mql/blob/master/mql4/indicators/MA%20Tunnel.mq4
 *  • ZigZag indicator:    @see https://github.com/rosasurfer/mt4-mql/blob/master/mql4/indicators/ZigZag.mq4
 *
 *
 * External control
 * ----------------
 *  • EA.Stop
 *  • EA.Restart
 *  • EA.ToggleMetrics
 *  • Chart.ToggleOpenOrders
 *  • Chart.ToggleTradeHistory
 *
 *
 *
 * TODO:
 *  - implement partial profit taking
 *     manage/track partial open/closed positions
 *     add break-even stop
 *     add exit strategies
 *
 *  - convert signal constants to array
 *  - add entry strategies
 *  - add virtual trading
 *  - add input "TradingTimeframe"
 *  - document input params, control scripts and general usage
 */
#define STRATEGY_ID  108                     // unique strategy id (used for generation of magic order numbers)

#include <stddefines.mqh>
int   __InitFlags[] = {INIT_PIPVALUE, INIT_BUFFERED_LOG};
int __DeinitFlags[];
int __virtualTicks = 10000;                  // every 10 seconds to continue operation on a stalled data feed

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern string Instance.ID          = "";                             // instance to load from a status file, format: "[T]123"

extern string Tunnel.Definition    = "EMA(9), EMA(36), EMA(144)";    // one or more MA definitions separated by comma
extern string Supported.MA.Methods = "SMA, LWMA, EMA, SMMA";
extern int    Donchian.Periods     = 30;

extern double Lots                 = 0.1;

extern int    Initial.TakeProfit   = 100;                            // in punits (0: partial targets only or no TP)
extern int    Initial.StopLoss     = 50;                             // in punits (0: moving stops only or no SL

extern int    Target1              = 0;                              // in punits (0: no target)
extern int    Target1.ClosePercent = 0;                              // size to close (0: nothing)
extern int    Target1.MoveStopTo   = 1;                              // in punits (0: don't move stop)
extern int    Target2              = 0;                              // ...
extern int    Target2.ClosePercent = 30;                             //
extern int    Target2.MoveStopTo   = 0;                              //
extern int    Target3              = 0;                              //
extern int    Target3.ClosePercent = 30;                             //
extern int    Target3.MoveStopTo   = 0;                              //
extern int    Target4              = 0;                              //
extern int    Target4.ClosePercent = 30;                             //
extern int    Target4.MoveStopTo   = 0;                              //

extern bool   ShowProfitInPercent  = false;                          // whether PnL is displayed in money amounts or percent

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#define SIGNAL_LONG     1                    // signal types
#define SIGNAL_SHORT    2                    //


// framework
#include <core/expert.mqh>
#include <core/expert.recorder.mqh>
#include <stdfunctions.mqh>
#include <rsfLib.mqh>
#include <functions/HandleCommands.mqh>
#include <functions/InitializeByteBuffer.mqh>
#include <functions/IsBarOpen.mqh>
#include <functions/iCustom/MaTunnel.mqh>
#include <functions/iCustom/ZigZag.mqh>
#include <functions/ObjectCreateRegister.mqh>
#include <structs/rsf/OrderExecution.mqh>

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
#include <ea/functions/trade/ComposePositionCloseMsg.mqh>
#include <ea/functions/trade/HistoryRecordToStr.mqh>
#include <ea/functions/trade/IsMyOrder.mqh>
#include <ea/functions/trade/MovePositionToHistory.mqh>
#include <ea/functions/trade/onPositionClose.mqh>

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

   if (__isChart) {
      if (!HandleCommands()) return(last_error);   // process incoming commands, may switch on/off the instance
   }

   if (instance.status != STATUS_STOPPED) {
      int signal;
      IsTradeSignal(signal);
      UpdateStatus(signal);
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

   if (cmd == "stop") {
      switch (instance.status) {
         case STATUS_WAITING:
         case STATUS_TRADING:
            logInfo("onCommand(1)  "+ instance.name +" \""+ fullCmd +"\"");
            double dNull[] = {0,0,0};
            return(StopTrading(dNull));
      }
   }
   else if (cmd == "restart") {
      switch (instance.status) {
         case STATUS_STOPPED:
            logInfo("onCommand(2)  "+ instance.name +" \""+ fullCmd +"\"");
            return(RestartInstance());
      }
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
   else return(!logNotice("onCommand(3)  "+ instance.name +" unsupported command: \""+ fullCmd +"\""));

   return(!logWarn("onCommand(4)  "+ instance.name +" cannot execute command \""+ fullCmd +"\" in status "+ StatusToStr(instance.status)));
}


/**
 * Whether a trade signal occurred.
 *
 * @param  _Out_ int &signal - variable receiving the signal identifier of a triggered condition
 *
 * @return bool
 */
bool IsTradeSignal(int &signal) {
   signal = NULL;
   if (last_error != NULL) return(false);

   // MA Tunnel signal ------------------------------------------------------------------------------------------------------
   if (IsMaTunnelSignal(signal)) {
      return(true);
   }

   // ZigZag signal ---------------------------------------------------------------------------------------------------------
   if (false) /*&&*/ if (IsZigZagSignal(signal)) {
      return(true);
   }
   return(false);
}


/**
 * Whether a new MA tunnel crossing occurred.
 *
 * @param  _Out_ int &signal - variable receiving the signal identifier: SIGNAL_LONG | SIGNAL_SHORT
 *
 * @return bool
 */
bool IsMaTunnelSignal(int &signal) {
   if (last_error != NULL) return(false);
   signal = NULL;

   static int lastTick, lastResult;

   if (Ticks == lastTick) {
      signal = lastResult;
   }
   else {
      if (IsBarOpen()) {
         int trend = icMaTunnel(NULL, Tunnel.Definition, MaTunnel.MODE_BAR_TREND, 1);
         if      (trend == +1) signal = SIGNAL_LONG;
         else if (trend == -1) signal = SIGNAL_SHORT;

         if (signal != NULL) {
            if (IsLogNotice()) logNotice("IsMaTunnelSignal(1)  "+ instance.name +" "+ ifString(signal==SIGNAL_LONG, "long", "short") +" crossing (market: "+ NumberToStr(_Bid, PriceFormat) +"/"+ NumberToStr(_Ask, PriceFormat) +")");
         }
      }
      lastTick = Ticks;
      lastResult = signal;
   }
   return(signal != NULL);
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

   static int lastTick, lastResult, lastSignal, lastSignalBar;
   int trend, reversal;

   if (Ticks == lastTick) {
      signal = lastResult;
   }
   else {
      // TODO: error on triple-crossing at bar 0 or 1
      //  - extension down, then reversal up, then reversal down           e.g. ZigZag(20), GBPJPY,M5 2023.12.18 00:00
      if (!GetZigZagData(0, trend, reversal)) return(!logError("IsZigZagSignal(1)  "+ instance.name +" GetZigZagData(0) => FALSE", ERR_RUNTIME_ERROR));
      int absTrend = Abs(trend);

      // The same value denotes a regular reversal, reversal==0 && absTrend==1 denotes a double crossing.
      if (absTrend==reversal || (!reversal && absTrend==1)) {
         if (trend > 0) signal = SIGNAL_LONG;
         else           signal = SIGNAL_SHORT;

         if (Time[0]==lastSignalBar && signal==lastSignal) {
            signal = NULL;
         }
         else {
            if (IsLogNotice()) logNotice("IsZigZagSignal(2)  "+ instance.name +" "+ ifString(signal==SIGNAL_LONG, "long", "short") +" reversal (market: "+ NumberToStr(_Bid, PriceFormat) +"/"+ NumberToStr(_Ask, PriceFormat) +")");
            lastSignal = signal;
            lastSignalBar = Time[0];
         }
      }
      lastTick = Ticks;
      lastResult = signal;
   }
   return(signal != NULL);
}


/**
 * Get ZigZag data at the specified bar offset.
 *
 * @param  _In_  int bar       - bar offset
 * @param  _Out_ int &trend    - combined trend value (buffers MODE_KNOWN_TREND + MODE_UNKNOWN_TREND)
 * @param  _Out_ int &reversal - bar offset of current ZigZag reversal to previous ZigZag extreme
 *
 * @return bool - success status
 */
bool GetZigZagData(int bar, int &trend, int &reversal) {
   trend    = MathRound(icZigZag(NULL, Donchian.Periods, ZigZag.MODE_TREND,    bar));
   reversal = MathRound(icZigZag(NULL, Donchian.Periods, ZigZag.MODE_REVERSAL, bar));
   return(!last_error && trend);
}


/**
 * Update order status and PnL.
 *
 * @param  int signal [optional] - trade signal causing the call (default: none, update status only)
 *
 * @return bool - success status
 */
bool UpdateStatus(int signal = NULL) {
   if (last_error || instance.status!=STATUS_TRADING) return(false);
   bool positionClosed = false;

   // update open position
   if (open.ticket != NULL) {
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
      open.commissionM  = OrderCommission();
      open.grossProfitM = OrderProfit();
      open.netProfitM   = open.grossProfitM + open.swapM + open.commissionM;
      open.netProfitP   = ifDouble(open.type==OP_BUY, exitPrice-open.price, open.price-exitPrice);
      open.runupP       = MathMax(open.runupP, open.netProfitP);
      open.rundownP     = MathMin(open.rundownP, open.netProfitP); if (open.swapM || open.commissionM) open.netProfitP += (open.swapM + open.commissionM)/PointValue(open.lots);
      open.sigProfitP   = ifDouble(open.type==OP_BUY, exitPriceSig-open.priceSig, open.priceSig-exitPriceSig);
      open.sigRunupP    = MathMax(open.sigRunupP, open.sigProfitP);
      open.sigRundownP  = MathMin(open.sigRundownP, open.sigProfitP);

      if (isClosed) {
         int error;
         if (IsError(onPositionClose("UpdateStatus(2)  "+ instance.name +" "+ ComposePositionCloseMsg(error), error))) return(false);
         if (!MovePositionToHistory(OrderCloseTime(), exitPrice, exitPriceSig))                                        return(false);
         positionClosed = true;
      }
   }

   // process signal
   if (signal != NULL) {
      if (!instance.startEquity) instance.startEquity = NormalizeDouble(AccountEquity() - AccountCredit() + GetExternalAssets(), 2);
      if (!instance.started) instance.started = Tick.time;
      instance.stopped = NULL;
      instance.status = STATUS_TRADING;

      // close an existing open position
      if (open.ticket != NULL) {
         if (open.type != ifInt(signal==SIGNAL_SHORT, OP_LONG, OP_SHORT)) return(!catch("UpdateStatus(3)  "+ instance.name +" cannot process "+ SignalToStr(signal) +" with open "+ OperationTypeToStr(open.type) +" position", ERR_ILLEGAL_STATE));

         int oeFlags, oe[];
         if (!OrderCloseEx(open.ticket, NULL, NULL, CLR_CLOSED, oeFlags, oe)) return(!SetLastError(oe.Error(oe)));

         double closePrice = oe.ClosePrice(oe);
         open.slippageP   += oe.Slippage(oe);
         open.swapM        = oe.Swap(oe);
         open.commissionM  = oe.Commission(oe);
         open.grossProfitM = oe.Profit(oe);
         open.netProfitM   = open.grossProfitM + open.swapM + open.commissionM;
         open.netProfitP   = ifDouble(open.type==OP_BUY, closePrice-open.price, open.price-closePrice);
         open.runupP       = MathMax(open.runupP, open.netProfitP);
         open.rundownP     = MathMin(open.rundownP, open.netProfitP); if (open.swapM || open.commissionM) open.netProfitP += (open.swapM + open.commissionM)/PointValue(open.lots);
         open.sigProfitP   = ifDouble(open.type==OP_BUY, _Bid-open.priceSig, open.priceSig-_Bid);
         open.sigRunupP    = MathMax(open.sigRunupP, open.sigProfitP);
         open.sigRundownP  = MathMin(open.sigRundownP, open.sigProfitP);

         if (!MovePositionToHistory(oe.CloseTime(oe), closePrice, _Bid)) return(false);
      }

      // open new position
      int    type        = ifInt(signal==SIGNAL_LONG, OP_BUY, OP_SELL);
      string comment     = instance.name;
      int    magicNumber = CalculateMagicNumber(instance.id);
      color  markerColor = ifInt(signal==SIGNAL_LONG, CLR_OPEN_LONG, CLR_OPEN_SHORT);

      int ticket = OrderSendEx(NULL, type, Lots, NULL, order.slippage, NULL, NULL, comment, magicNumber, NULL, markerColor, NULL, oe);
      if (!ticket) return(!SetLastError(oe.Error(oe)));

      // store the new position
      open.ticket       = ticket;
      open.type         = type;
      open.lots         = oe.Lots(oe);
      open.time         = oe.OpenTime(oe);
      open.price        = oe.OpenPrice(oe);
      open.priceSig     = _Bid;
      open.slippageP    = oe.Slippage(oe);
      open.swapM        = oe.Swap(oe);
      open.commissionM  = oe.Commission(oe);
      open.grossProfitM = oe.Profit(oe);
      open.netProfitM   = open.grossProfitM + open.swapM + open.commissionM;
      open.netProfitP   = ifDouble(open.type==OP_BUY, _Bid-open.price, open.price-_Ask); if (open.swapM || open.commissionM) open.netProfitP += (open.swapM + open.commissionM)/PointValue(open.lots);
      open.runupP       = ifDouble(open.type==OP_BUY, _Bid-open.price, open.price-_Ask);
      open.rundownP     = open.runupP;
      open.sigProfitP   = 0;
      open.sigRunupP    = open.sigProfitP;
      open.sigRundownP  = open.sigRunupP;
      if (__isChart) SS.OpenLots();

      if (test.onPositionOpenPause) Tester.Pause("UpdateStatus(4)");
   }

   // update PnL numbers
   stats.openNetProfit     = open.netProfitM;
   stats.totalNetProfit    = stats.openNetProfit + stats.closedNetProfit;
   stats.maxNetProfit      = MathMax(stats.maxNetProfit,      stats.totalNetProfit);
   stats.maxNetAbsDrawdown = MathMin(stats.maxNetAbsDrawdown, stats.totalNetProfit);
   stats.maxNetRelDrawdown = MathMin(stats.maxNetRelDrawdown, stats.totalNetProfit - stats.maxNetProfit);

   stats.openNetProfitP     = open.netProfitP;
   stats.totalNetProfitP    = stats.openNetProfitP + stats.closedNetProfitP;
   stats.maxNetProfitP      = MathMax(stats.maxNetProfitP,      stats.totalNetProfitP);
   stats.maxNetAbsDrawdownP = MathMin(stats.maxNetAbsDrawdownP, stats.totalNetProfitP);
   stats.maxNetRelDrawdownP = MathMin(stats.maxNetRelDrawdownP, stats.totalNetProfitP - stats.maxNetProfitP);

   stats.openSigProfitP     = open.sigProfitP;
   stats.totalSigProfitP    = stats.openSigProfitP + stats.closedSigProfitP;
   stats.maxSigProfitP      = MathMax(stats.maxSigProfitP,      stats.totalSigProfitP);
   stats.maxSigAbsDrawdownP = MathMin(stats.maxSigAbsDrawdownP, stats.totalSigProfitP);
   stats.maxSigRelDrawdownP = MathMin(stats.maxSigRelDrawdownP, stats.totalSigProfitP - stats.maxSigProfitP);

   if (__isChart) {
      SS.TotalProfit();
      SS.ProfitStats();
   }

   if (positionClosed || signal)
      return(SaveStatus());
   return(!catch("UpdateStatus(5)"));
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

   int    sigType  = signal[SIG_TYPE];
   double sigPrice = signal[SIG_PRICE];
   int    sigOp    = signal[SIG_OP];

   // close an open position
   if (instance.status == STATUS_TRADING) {
      if (open.ticket > 0) {
         if (IsLogInfo()) logInfo("StopTrading(2)  "+ instance.name +" stopping");
         int oeFlags, oe[];
         if (!OrderCloseEx(open.ticket, NULL, NULL, CLR_CLOSED, oeFlags, oe)) return(!SetLastError(oe.Error(oe)));

         double closePrice = oe.ClosePrice(oe);
         open.slippageP   += oe.Slippage  (oe);
         open.swapM        = oe.Swap      (oe);
         open.commissionM  = oe.Commission(oe);
         open.grossProfitM = oe.Profit    (oe);
         open.netProfitM   = open.grossProfitM + open.swapM + open.commissionM;
         open.netProfitP   = ifDouble(open.type==OP_BUY, closePrice-open.price, open.price-closePrice);
         open.runupP       = MathMax(open.runupP, open.netProfitP);
         open.rundownP     = MathMin(open.rundownP, open.netProfitP); open.netProfitP += (open.swapM + open.commissionM)/PointValue(open.lots);
         open.sigProfitP   = ifDouble(open.type==OP_BUY, _Bid-open.priceSig, open.priceSig-_Bid);
         open.sigRunupP    = MathMax(open.sigRunupP, open.sigProfitP);
         open.sigRundownP  = MathMin(open.sigRundownP, open.sigProfitP);

         if (!MovePositionToHistory(oe.CloseTime(oe), closePrice, _Bid)) return(false);

         // update PL numbers
         stats.openNetProfit     = open.netProfitM;
         stats.totalNetProfit    = stats.openNetProfit + stats.closedNetProfit;
         stats.maxNetProfit      = MathMax(stats.maxNetProfit,      stats.totalNetProfit);
         stats.maxNetAbsDrawdown = MathMin(stats.maxNetAbsDrawdown, stats.totalNetProfit);
         stats.maxNetRelDrawdown = MathMin(stats.maxNetRelDrawdown, stats.totalNetProfit - stats.maxNetProfit);

         stats.openNetProfitP     = open.netProfitP;
         stats.totalNetProfitP    = stats.openNetProfitP + stats.closedNetProfitP;
         stats.maxNetProfitP      = MathMax(stats.maxNetProfitP,      stats.totalNetProfitP);
         stats.maxNetAbsDrawdownP = MathMin(stats.maxNetAbsDrawdownP, stats.totalNetProfitP);
         stats.maxNetRelDrawdownP = MathMin(stats.maxNetRelDrawdownP, stats.totalNetProfitP - stats.maxNetProfitP);

         stats.openSigProfitP     = open.sigProfitP;
         stats.totalSigProfitP    = stats.openSigProfitP + stats.closedSigProfitP;
         stats.maxSigProfitP      = MathMax(stats.maxSigProfitP,      stats.totalSigProfitP);
         stats.maxSigAbsDrawdownP = MathMin(stats.maxSigAbsDrawdownP, stats.totalSigProfitP);
         stats.maxSigRelDrawdownP = MathMin(stats.maxSigRelDrawdownP, stats.totalSigProfitP - stats.maxSigProfitP);
      }
   }

   // update status
   instance.status = STATUS_STOPPED;
   instance.stopped = Tick.time;
   SS.TotalProfit();
   SS.ProfitStats();

   if (IsLogInfo()) logInfo("StopTrading(3)  "+ instance.name +" "+ ifString(__isTesting && !sigType, "test ", "") +"stopped, profit: "+ status.totalProfit +" "+ status.profitStats);
   SaveStatus();

   // pause/stop the tester according to the debug configuration
   if (__isTesting) {
      if      (!IsVisualMode())  Tester.Stop ("StopTrading(4)");
      else if (test.onStopPause) Tester.Pause("StopTrading(5)");
   }
   return(!catch("StopTrading(6)"));
}


/**
 * Restart a stopped instance.
 *
 * @return bool - success status
 */
bool RestartInstance() {
   if (last_error != NULL)                return(false);
   if (instance.status != STATUS_STOPPED) return(!catch("RestartInstance(1)  "+ instance.name +" cannot restart "+ StatusDescription(instance.status) +" instance", ERR_ILLEGAL_STATE));
   return(!catch("RestartInstance(2)", ERR_NOT_IMPLEMENTED));
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
   Instance.ID              = GetIniStringA(file, section, "Instance.ID",       "");         // string   Instance.ID         = T123
   Tunnel.Definition        = GetIniStringA(file, section, "Tunnel.Definition", "");         // string   Tunnel.Definition   = EMA(1), EMA(2), EMA(3)
   Donchian.Periods         = GetIniInt    (file, section, "Donchian.Periods"     );         // int      Donchian.Periods    = 40
   Lots                     = GetIniDouble (file, section, "Lots"                 );         // double   Lots                = 0.1
   if (!ReadStatus.Targets(file)) return(false);
   ShowProfitInPercent      = GetIniBool   (file, section, "ShowProfitInPercent"  );         // bool     ShowProfitInPercent = 1
   EA.Recorder              = GetIniStringA(file, section, "EA.Recorder",       "");         // string   EA.Recorder         = 1,2,4

   // [Runtime status]
   section = "Runtime status";
   instance.id              = GetIniInt    (file, section, "instance.id"      );             // int      instance.id              = 123
   instance.name            = GetIniStringA(file, section, "instance.name", "");             // string   instance.name            = V.123
   instance.created         = GetIniInt    (file, section, "instance.created" );             // datetime instance.created         = 1624924800 (Mon, 2021.05.12 13:22:34)
   instance.started         = GetIniInt    (file, section, "instance.started" );             // datetime instance.started         = 1624924800 (Mon, 2021.05.12 13:22:34)
   instance.stopped         = GetIniInt    (file, section, "instance.stopped" );             // datetime instance.stopped         = 1624924800 (Mon, 2021.05.12 13:22:34)
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
   WriteIniString(file, section, "Tunnel.Definition",          /*string  */ Tunnel.Definition);
   WriteIniString(file, section, "Donchian.Periods",           /*int     */ Donchian.Periods);
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
   WriteIniString(file, section, "instance.started",           /*datetime*/ instance.started + ifString(!instance.started, "", GmtTimeFormat(instance.started, " (%a, %Y.%m.%d %H:%M:%S)")));
   WriteIniString(file, section, "instance.stopped",           /*datetime*/ instance.stopped + ifString(!instance.stopped, "", GmtTimeFormat(instance.stopped, " (%a, %Y.%m.%d %H:%M:%S)")));
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
string   prev.Tunnel.Definition = "";
int      prev.Donchian.Periods;
double   prev.Lots;
bool     prev.ShowProfitInPercent;


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
   prev.Instance.ID         = StringConcatenate(Instance.ID, "");       // string inputs are references to internal C literals
   prev.Tunnel.Definition   = StringConcatenate(Tunnel.Definition, ""); // and must be copied to break the reference
   prev.Donchian.Periods    = Donchian.Periods;
   prev.Lots                = Lots;
   prev.ShowProfitInPercent = ShowProfitInPercent;

   // affected runtime variables
   BackupInputs.Targets();
   Recorder_BackupInputs();
}


/**
 * Restore backed-up input parameters and runtime variables. Called from onInitParameters() and onInitTimeframeChange().
 */
void RestoreInputs() {
   // input parameters
   Instance.ID         = prev.Instance.ID;
   Tunnel.Definition   = prev.Tunnel.Definition;
   Donchian.Periods    = prev.Donchian.Periods;
   Lots                = prev.Lots;
   ShowProfitInPercent = prev.ShowProfitInPercent;

   // affected runtime variables
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

   // Tunnel.Definition
   if (isInitParameters && Tunnel.Definition!=prev.Tunnel.Definition) {
      if (hasOpenOrders)                           return(!onInputError("ValidateInputs(2)  "+ instance.name +" cannot change input parameter Tunnel.Definition with open orders"));
   }
   string sValue, sValues[], sMAs[];
   ArrayResize(sMAs, 0);
   int n=0, size=Explode(Tunnel.Definition, ",", sValues, NULL);
   for (int i=0; i < size; i++) {
      sValue = StrTrim(sValues[i]);
      if (sValue == "") continue;

      string sMethod = StrLeftTo(sValue, "(");
      if (sMethod == sValue)                       return(!onInputError("ValidateInputs(3)  "+ instance.name +" invalid value "+ DoubleQuoteStr(sValue) +" in input parameter Tunnel.Definition: "+ DoubleQuoteStr(Tunnel.Definition) +" (format not \"MaMethod(int)\")"));
      int iMethod = StrToMaMethod(sMethod, F_ERR_INVALID_PARAMETER);
      if (iMethod == -1)                           return(!onInputError("ValidateInputs(4)  "+ instance.name +" invalid MA method "+ DoubleQuoteStr(sMethod) +" in input parameter Tunnel.Definition: "+ DoubleQuoteStr(Tunnel.Definition)));
      if (iMethod > MODE_LWMA)                     return(!onInputError("ValidateInputs(5)  "+ instance.name +" unsupported MA method "+ DoubleQuoteStr(sMethod) +" in input parameter Tunnel.Definition: "+ DoubleQuoteStr(Tunnel.Definition)));

      string sPeriods = StrRightFrom(sValue, "(");
      if (!StrEndsWith(sPeriods, ")"))             return(!onInputError("ValidateInputs(6)  "+ instance.name +" invalid value "+ DoubleQuoteStr(sValue) +" in input parameter Tunnel.Definition: "+ DoubleQuoteStr(Tunnel.Definition) +" (format not \"MaMethod(int)\")"));
      sPeriods = StrTrim(StrLeft(sPeriods, -1));
      if (!StrIsDigits(sPeriods))                  return(!onInputError("ValidateInputs(7)  "+ instance.name +" invalid value "+ DoubleQuoteStr(sValue) +" in input parameter Tunnel.Definition: "+ DoubleQuoteStr(Tunnel.Definition) +" (format not \"MaMethod(int)\")"));
      int iPeriods = StrToInteger(sPeriods);
      if (iPeriods < 1)                            return(!onInputError("ValidateInputs(8)  "+ instance.name +" invalid MA periods "+ iPeriods +" in input parameter Tunnel.Definition: "+ DoubleQuoteStr(Tunnel.Definition) +" (must be > 0)"));

      ArrayResize(sMAs, n+1);
      sMAs[n]  = MaMethodDescription(iMethod) +"("+ iPeriods +")";
      n++;
   }
   if (!n)                                         return(!onInputError("ValidateInputs(9)  "+ instance.name +" missing input parameter Tunnel.Definition (empty)"));
   Tunnel.Definition = JoinStrings(sMAs);

   // Donchian.Periods
   if (isInitParameters && Donchian.Periods!=prev.Donchian.Periods) {
      if (hasOpenOrders)                           return(!onInputError("ValidateInputs(10)  "+ instance.name +" cannot change input parameter Donchian.Periods with open orders"));
   }
   if (Donchian.Periods < 2)                       return(!onInputError("ValidateInputs(11)  "+ instance.name +" invalid input parameter Donchian.Periods: "+ Donchian.Periods +" (must be > 1)"));

   // Lots
   if (LT(Lots, 0))                                return(!onInputError("ValidateInputs(12)  "+ instance.name +" invalid input parameter Lots: "+ NumberToStr(Lots, ".1+") +" (must be > 0)"));
   if (NE(Lots, NormalizeLots(Lots)))              return(!onInputError("ValidateInputs(13)  "+ instance.name +" invalid input parameter Lots: "+ NumberToStr(Lots, ".1+") +" (must be a multiple of MODE_LOTSTEP="+ NumberToStr(MarketInfo(Symbol(), MODE_LOTSTEP), ".+") +")"));

   // Targets
   if (!ValidateInputs.Targets()) return(false);

   // EA.Recorder: on | off* | 1,2,3=1000,...
   if (!Recorder_ValidateInputs(IsTestInstance())) return(false);

   SS.All();
   return(!catch("ValidateInputs(14)"));
}


/**
 * Return a readable representation of a signal constant.
 *
 * @param  int signal
 *
 * @return string - readable constant or an empty string in case of errors
 */
string SignalToStr(int signal) {
   switch (signal) {
      case NULL        : return("no signal"   );
      case SIGNAL_LONG : return("SIGNAL_LONG" );
      case SIGNAL_SHORT: return("SIGNAL_SHORT");
   }
   return(_EMPTY_STR(catch("SignalToStr(1)  "+ instance.name +" invalid parameter signal: "+ signal, ERR_INVALID_PARAMETER)));
}


/**
 * ShowStatus: Update the string representation of the instance name.
 */
void SS.InstanceName() {
   instance.name = "V."+ StrPadLeft(instance.id, 3, "0");
}


/**
 * Return a string representation of the input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("Instance.ID=",          DoubleQuoteStr(Instance.ID),       ";"+ NL +
                            "Tunnel.Definition=",    DoubleQuoteStr(Tunnel.Definition), ";"+ NL +
                            "Donchian.Periods=",     Donchian.Periods,                  ";"+ NL +

                            "Lots=",                 NumberToStr(Lots, ".1+"),          ";"+ NL +
                            "Initial.TakeProfit=",   Initial.TakeProfit,                ";"+ NL +
                            "Initial.StopLoss=",     Initial.StopLoss,                  ";"+ NL +
                            "Target1=",              Target1,                           ";"+ NL +
                            "Target1.ClosePercent=", Target1.ClosePercent,              ";"+ NL +
                            "Target1.MoveStopTo=",   Target1.MoveStopTo,                ";"+ NL +
                            "Target2=",              Target2,                           ";"+ NL +
                            "Target2.ClosePercent=", Target2.ClosePercent,              ";"+ NL +
                            "Target2.MoveStopTo=",   Target2.MoveStopTo,                ";"+ NL +
                            "Target3=",              Target3,                           ";"+ NL +
                            "Target3.ClosePercent=", Target3.ClosePercent,              ";"+ NL +
                            "Target3.MoveStopTo=",   Target3.MoveStopTo,                ";"+ NL +
                            "Target4=",              Target4,                           ";"+ NL +
                            "Target4.ClosePercent=", Target4.ClosePercent,              ";"+ NL +
                            "Target4.MoveStopTo=",   Target4.MoveStopTo,                ";"+ NL +

                            "ShowProfitInPercent=",  BoolToStr(ShowProfitInPercent),    ";")
   );
}
