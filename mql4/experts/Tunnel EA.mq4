/**
 * An EA for trading tunnel breakouts.
 *
 *
 * Rules
 * -----
 *  - Entry:      on breakout of the defined tunnel (by close of the current bar and/or meeting the defined filter condition)
 *  - StopLoss:   on opposite signal or on meeting the defined stop condition
 *  - TakeProfit: by following the defined target configuration
 *
 *
 * TODO:
 *  - entry management
 *
 *  - exit management
 *     break-even stop
 *     partial profit taking
 *
 *  - convert signal constants to array
 *  - add virtual trading
 *  - add input "TradingTimeframe"
 *  - document input params, control scripts and general usage
 */
#define STRATEGY_ID  108                     // unique strategy id

#include <rsf/stddefines.mqh>
int   __InitFlags[] = {INIT_PIPVALUE, INIT_BUFFERED_LOG};
int __DeinitFlags[];
int __virtualTicks = 10000;                  // every 10 seconds to continue operation on a stalled data feed

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern string Instance.ID                    = "";                            // instance to load from a status file, format: "[T]123"

extern string ___a__________________________ = "=== Signal settings ===========";
extern string Tunnel                         = "EMA(9), EMA(36), EMA(144)";   // tunnel definition as supported by the "Tunnel" indicator
extern string Filter.1                       = "";
extern string Filter.2                       = "";
extern string Filter.3                       = "";

extern string ___b__________________________ = "=== Trade settings ============";
extern double Lots                           = 0.1;

extern string ___c__________________________ = "=== Exit management ===========";
extern int    Initial.TakeProfit             = 100;                           // in punits (0: partial targets only)
extern int    Initial.StopLoss               = 50;                            // in punits (0: moving stops only)

extern int    Target1                        = 0;                             // in punits (0: no target)
extern int    Target1.ClosePercent           = 0;                             // size to close (0: nothing)
extern int    Target1.MoveStopTo             = 1;                             // in punits (0: don't move stop)
extern int    Target2                        = 0;                             // ...
extern int    Target2.ClosePercent           = 30;                            //
extern int    Target2.MoveStopTo             = 0;                             //
extern int    Target3                        = 0;                             //
extern int    Target3.ClosePercent           = 30;                            //
extern int    Target3.MoveStopTo             = 0;                             //
extern int    Target4                        = 0;                             //
extern int    Target4.ClosePercent           = 30;                            //
extern int    Target4.MoveStopTo             = 0;                             //

extern string ___d__________________________ = "=== Other settings ============";
extern bool   ShowProfitInPercent            = true;                          // whether PnL is displayed in percent or money amounts

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// framework
#include <rsf/core/expert.mqh>
#include <rsf/core/expert.recorder.mqh>
#include <rsf/stdfunctions.mqh>
#include <rsf/stdlib.mqh>
#include <rsf/functions/HandleCommands.mqh>
#include <rsf/functions/InitializeByteBuffer.mqh>
#include <rsf/functions/IsBarOpen.mqh>
#include <rsf/functions/iCustom/Tunnel.mqh>
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

#include <rsf/experts/log/GetLogFilename.mqh>

#include <rsf/experts/metric/GetMT4SymbolDefinition.mqh>
#include <rsf/experts/metric/RecordMetrics.mqh>

#include <rsf/experts/status/CreateStatusBox_6.mqh>
#include <rsf/experts/status/ShowOpenOrders.mqh>
#include <rsf/experts/status/ShowTradeHistory.mqh>
#include <rsf/experts/status/ShowStatus.mqh>
#include <rsf/experts/status/SS.All.mqh>
#include <rsf/experts/status/SS.MetricDescription.mqh>
#include <rsf/experts/status/SS.OpenLots.mqh>
#include <rsf/experts/status/SS.ClosedTrades.mqh>
#include <rsf/experts/status/SS.TotalProfit.mqh>
#include <rsf/experts/status/SS.ProfitStats.mqh>
#include <rsf/experts/status/StatusToStr.mqh>
#include <rsf/experts/status/StatusDescription.mqh>

#include <rsf/experts/status/file/FindStatusFile.mqh>
#include <rsf/experts/status/file/GetStatusFilename.mqh>
#include <rsf/experts/status/file/SetStatusFilename.mqh>
#include <rsf/experts/status/file/ReadStatus.General.mqh>
#include <rsf/experts/status/file/ReadStatus.Targets.mqh>
#include <rsf/experts/status/file/ReadStatus.OpenPosition.mqh>
#include <rsf/experts/status/file/ReadStatus.HistoryRecord.mqh>
#include <rsf/experts/status/file/ReadStatus.TradeHistory.mqh>
#include <rsf/experts/status/file/ReadStatus.TradeStats.mqh>
#include <rsf/experts/status/file/SaveStatus.General.mqh>
#include <rsf/experts/status/file/SaveStatus.Targets.mqh>
#include <rsf/experts/status/file/SaveStatus.OpenPosition.mqh>
#include <rsf/experts/status/file/SaveStatus.TradeHistory.mqh>
#include <rsf/experts/status/file/SaveStatus.TradeStats.mqh>

#include <rsf/experts/status/volatile/StoreVolatileStatus.mqh>
#include <rsf/experts/status/volatile/RestoreVolatileStatus.mqh>
#include <rsf/experts/status/volatile/RemoveVolatileStatus.mqh>
#include <rsf/experts/status/volatile/ToggleOpenOrders.mqh>
#include <rsf/experts/status/volatile/ToggleTradeHistory.mqh>
#include <rsf/experts/status/volatile/ToggleMetrics.mqh>

#include <rsf/experts/test/ReadTestConfiguration.mqh>

#include <rsf/experts/trade/AddHistoryRecord.mqh>
#include <rsf/experts/trade/CalculateMagicNumber.mqh>
#include <rsf/experts/trade/ComposePositionCloseMsg.mqh>
#include <rsf/experts/trade/HistoryRecordToStr.mqh>
#include <rsf/experts/trade/IsMyOrder.mqh>
#include <rsf/experts/trade/MovePositionToHistory.mqh>
#include <rsf/experts/trade/onPositionClose.mqh>

#include <rsf/experts/trade/signal/SignalOperationToStr.mqh>

#include <rsf/experts/trade/stats/CalculateStats.mqh>

#include <rsf/experts/validation/ValidateInputs.ID.mqh>
#include <rsf/experts/validation/ValidateInputs.Targets.mqh>
#include <rsf/experts/validation/onInputError.mqh>

// init/deinit
#include <rsf/experts/init.mqh>
#include <rsf/experts/deinit.mqh>

#define NET_MONEY    METRIC_NET_MONEY                 // shorter metric aliases
#define NET_UNITS    METRIC_NET_UNITS
#define SIG_UNITS    METRIC_SIG_UNITS


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   if (!instance.status) return(catch("onTick(1)  illegal instance.status: "+ instance.status, ERR_ILLEGAL_STATE));
   double signal[3];

   if (__isChart) {
      if (!HandleCommands()) return(last_error);      // process incoming commands (may switch on/off the instance)
   }

   if (instance.status != STATUS_STOPPED) {
      if (instance.status == STATUS_WAITING) {
         if (IsStartSignal(signal)) {
            StartTrading(signal);
         }
      }
      else if (instance.status == STATUS_TRADING) {
         UpdateStatus();                              // update client-side status

         if (IsStopSignal(signal)) {
            StopTrading(signal);
         }
         else {
            ManageOpenPositions();                    // update server-side status
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

   if (cmd == "stop") {
      switch (instance.status) {
         case STATUS_WAITING:
         case STATUS_TRADING:
            logInfo("onCommand(1)  "+ instance.name +" \""+ fullCmd +"\"");
            double dNull[] = {0,0,0};
            return(StopTrading(dNull));
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
 * Whether conditions are fullfilled to start trading.
 *
 * @param  _Out_ double &signal[] - array receiving entry signal details
 *
 * @return bool
 */
bool IsStartSignal(double &signal[]) {
   if (last_error || instance.status!=STATUS_WAITING) return(false);
   signal[SIG_TYPE ] = 0;
   signal[SIG_PRICE] = 0;
   signal[SIG_OP   ] = 0;

   if (IsEntrySignal(signal)) {
      return(true);
   }
   return(false);
}


/**
 * Whether conditions are fullfilled to stop trading.
 *
 * @param  _Out_ double &signal[] - array receiving exit signal details (if any)
 *
 * @return bool
 */
bool IsStopSignal(double &signal[]) {
   if (last_error || (instance.status!=STATUS_WAITING && instance.status!=STATUS_TRADING)) return(false);
   // TODO: check PnL conditions
   return(false);
}


/**
 * Whether a signal occurred to open a new position.
 *
 * @param  _Out_ double &signal[] - array receiving signal details
 *
 * @return bool
 */
bool IsEntrySignal(double &signal[]) {
   return(IsTunnelSignal(signal));
}


/**
 * Whether a signal occurred to close an open position.
 *
 * @param  _Out_ double &signal[] - array receiving signal details (if any)
 *
 * @return bool
 */
bool IsExitSignal(double &signal[]) {
   if (last_error || instance.status!=STATUS_TRADING) return(false);

   static int lastTick, lastSigType, lastSigOp;
   static double lastSigPrice;

   if (Ticks == lastTick) {                  // return the same result for the same tick
      signal[SIG_TYPE ] = lastSigType;
      signal[SIG_PRICE] = lastSigPrice;
      signal[SIG_OP   ] = lastSigOp;
   }
   else {
      signal[SIG_TYPE ] = 0;
      signal[SIG_PRICE] = 0;
      signal[SIG_OP   ] = 0;

      if (open.ticket > 0) {
         if (IsTunnelSignal(signal)) {
            int sigOp = signal[SIG_OP];
            if      (open.type==OP_LONG  && sigOp & SIG_OP_SHORT) sigOp |= SIG_OP_CLOSE_LONG;
            else if (open.type==OP_SHORT && sigOp & SIG_OP_LONG ) sigOp |= SIG_OP_CLOSE_SHORT;
            else                                                  sigOp = NULL;
            if (sigOp != NULL) {
               signal[SIG_OP] = sigOp;
               if (IsLogNotice()) logNotice("IsExitSignal(1)  "+ instance.name +" close "+ ifString(sigOp & SIG_OP_CLOSE_LONG, "long", "short") +" signal at "+ NumberToStr(signal[SIG_PRICE], PriceFormat) +" (opposite breakout, market: "+ NumberToStr(_Bid, PriceFormat) +"/"+ NumberToStr(_Ask, PriceFormat) +")");
            }
         }
      }
      lastTick     = Ticks;
      lastSigType  = signal[SIG_TYPE ];
      lastSigPrice = signal[SIG_PRICE];
      lastSigOp    = signal[SIG_OP   ];
   }
   return(lastSigType != NULL);
}


/**
 * Whether a tunnel crossing occurred.
 *
 * @param  _Out_ double &signal[] - array receiving signal details (if any)
 *
 * @return bool
 */
bool IsTunnelSignal(double &signal[]) {
   if (last_error != NULL) return(false);

   // TODO: 35% of the total runtime are spent in this function

   static int lastTick, lastSigType, lastSigOp;
   static double lastSigPrice;

   if (Ticks == lastTick) {                  // return the same result for the same tick
      signal[SIG_TYPE ] = lastSigType;
      signal[SIG_PRICE] = lastSigPrice;
      signal[SIG_OP   ] = lastSigOp;
   }
   else {
      signal[SIG_TYPE ] = 0;
      signal[SIG_PRICE] = 0;
      signal[SIG_OP   ] = 0;

      if (IsBarOpen()) {
         int trend = icTunnel(NULL, Tunnel, Tunnel.MODE_TREND, 1);
         if (Abs(trend) == 1) {
            signal[SIG_TYPE ] = SIG_TYPE_TUNNEL;
            signal[SIG_PRICE] = Close[1];
            signal[SIG_OP   ] = ifInt(trend==1, SIG_OP_LONG, SIG_OP_SHORT);

            if (IsLogNotice()) logNotice("IsTunnelSignal(1)  "+ instance.name +" "+ ifString(signal[SIG_OP]==SIG_OP_LONG, "long", "short") +" crossing (market: "+ NumberToStr(_Bid, PriceFormat) +"/"+ NumberToStr(_Ask, PriceFormat) +")");
         }
      }
      lastTick     = Ticks;
      lastSigType  = signal[SIG_TYPE ];
      lastSigPrice = signal[SIG_PRICE];
      lastSigOp    = signal[SIG_OP   ];
   }
   return(lastSigType != NULL);
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

   if (!instance.startEquity) instance.startEquity = NormalizeDouble(AccountEquity() - AccountCredit(), 2);
   if (!instance.started) instance.started = Tick.time;
   instance.stopped = NULL;
   instance.status = STATUS_TRADING;

   OpenPosition(signal);

   if (!last_error && IsLogInfo()) {
      int sigOp = signal[SIG_OP];
      logInfo("StartTrading(2)  "+ instance.name +" started ("+ SignalOperationToStr(sigOp & (SIG_OP_LONG|SIG_OP_SHORT)) +")");
   }
   return(!last_error);
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
         stats[NET_MONEY][S_OPEN_PROFIT] = open.netProfitM;
         stats[NET_UNITS][S_OPEN_PROFIT] = open.netProfitP;
         stats[SIG_UNITS][S_OPEN_PROFIT] = open.sigProfitP;
         for (int i=1; i <= 3; i++) {
            stats[i][S_TOTAL_PROFIT    ] = stats[i][S_OPEN_PROFIT] + stats[i][S_CLOSED_PROFIT];
            stats[i][S_MAX_PROFIT      ] = MathMax(stats[i][S_MAX_PROFIT      ], stats[i][S_TOTAL_PROFIT]);
            stats[i][S_MAX_ABS_DRAWDOWN] = MathMin(stats[i][S_MAX_ABS_DRAWDOWN], stats[i][S_TOTAL_PROFIT]);
            stats[i][S_MAX_REL_DRAWDOWN] = MathMin(stats[i][S_MAX_REL_DRAWDOWN], stats[i][S_TOTAL_PROFIT] - stats[i][S_MAX_PROFIT]);
         }
      }
   }

   // update status
   instance.status = STATUS_STOPPED;
   instance.stopped = Tick.time;

   if (__isChart || IsLogInfo()) {
      SS.TotalProfit();
      SS.ProfitStats();
   }
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
 * Update client-side order status.
 *
 * @return bool - success status
 */
bool UpdateStatus() {
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

   // update PnL numbers
   stats[NET_MONEY][S_OPEN_PROFIT] = open.netProfitM;
   stats[NET_UNITS][S_OPEN_PROFIT] = open.netProfitP;
   stats[SIG_UNITS][S_OPEN_PROFIT] = open.sigProfitP;
   for (int i=1; i <= 3; i++) {
      stats[i][S_TOTAL_PROFIT    ] = stats[i][S_OPEN_PROFIT] + stats[i][S_CLOSED_PROFIT];
      stats[i][S_MAX_PROFIT      ] = MathMax(stats[i][S_MAX_PROFIT      ], stats[i][S_TOTAL_PROFIT]);
      stats[i][S_MAX_ABS_DRAWDOWN] = MathMin(stats[i][S_MAX_ABS_DRAWDOWN], stats[i][S_TOTAL_PROFIT]);
      stats[i][S_MAX_REL_DRAWDOWN] = MathMin(stats[i][S_MAX_REL_DRAWDOWN], stats[i][S_TOTAL_PROFIT] - stats[i][S_MAX_PROFIT]);
   }
   if (__isChart) {
      SS.TotalProfit();
      SS.ProfitStats();
   }

   if (positionClosed) return(SaveStatus());
   return(!catch("UpdateStatus(3)"));
}


/**
 * Update server-side order status.
 *
 * @return bool - success status
 */
bool ManageOpenPositions() {
   if (last_error || instance.status!=STATUS_TRADING) return(false);
   double signal[3];

   if (open.ticket > 0) {
      if (IsExitSignal(signal)) ClosePosition(signal);   // close an existing position
   }
   if (!open.ticket) {
      if (IsEntrySignal(signal)) OpenPosition(signal);   // open a new position
   }
   return(!catch("ManageOpenPositions(1)"));
}


/**
 * Open a new position.
 *
 * @param  double signal[] - signal infos causing the call
 *
 * @return bool - success status
 */
bool OpenPosition(double signal[]) {
   if (last_error != NULL)                    return(false);
   if (instance.status != STATUS_TRADING)     return(!catch("OpenPosition(1)  "+ instance.name +" cannot open new position for "+ StatusDescription(instance.status) +" instance", ERR_ILLEGAL_STATE));
   int    sigType  = signal[SIG_TYPE ];
   double sigPrice = signal[SIG_PRICE];
   int    sigOp    = signal[SIG_OP   ];
   if (!(sigOp & (SIG_OP_LONG|SIG_OP_SHORT))) return(!catch("OpenPosition(2)  "+ instance.name +" invalid signal parameter SIG_OP: "+ sigOp, ERR_INVALID_PARAMETER));

   // open a new position
   int    type        = ifInt(sigOp & SIG_OP_LONG, OP_BUY, OP_SELL), oe[];
   string comment     = instance.name;
   int    magicNumber = CalculateMagicNumber(instance.id);
   color  markerColor = ifInt(type==OP_BUY, CLR_OPEN_LONG, CLR_OPEN_SHORT);

   int ticket = OrderSendEx(NULL, type, Lots, NULL, order.slippage, NULL, NULL, comment, magicNumber, NULL, markerColor, NULL, oe);
   if (!ticket) return(!SetLastError(oe.Error(oe)));

   // store the position data
   open.ticket       = ticket;
   open.type         = type;
   open.lots         = oe.Lots(oe);
   open.time         = oe.OpenTime(oe);
   open.price        = oe.OpenPrice(oe);
   open.priceSig     = ifDouble(sigType==SIG_TYPE_TUNNEL, sigPrice, _Bid);
   open.slippageP    = oe.Slippage(oe);
   open.swapM        = oe.Swap(oe);
   open.commissionM  = oe.Commission(oe);
   open.grossProfitM = oe.Profit(oe);
   open.netProfitM   = open.grossProfitM + open.swapM + open.commissionM;
   open.netProfitP   = ifDouble(open.type==OP_BUY, _Bid-open.price, open.price-_Ask) + (open.swapM + open.commissionM)/PointValue(open.lots);
   open.runupP       = ifDouble(open.type==OP_BUY, _Bid-open.price, open.price-_Ask);
   open.rundownP     = open.runupP;
   open.sigProfitP   = ifDouble(open.type==OP_BUY, _Bid-open.priceSig, open.priceSig-_Bid);
   open.sigRunupP    = open.sigProfitP;
   open.sigRundownP  = open.sigRunupP;

   // update PnL stats
   stats[NET_MONEY][S_OPEN_PROFIT] = open.netProfitM;
   stats[NET_UNITS][S_OPEN_PROFIT] = open.netProfitP;
   stats[SIG_UNITS][S_OPEN_PROFIT] = open.sigProfitP;
   for (int i=1; i <= 3; i++) {
      stats[i][S_TOTAL_PROFIT    ] = stats[i][S_OPEN_PROFIT] + stats[i][S_CLOSED_PROFIT];
      stats[i][S_MAX_PROFIT      ] = MathMax(stats[i][S_MAX_PROFIT      ], stats[i][S_TOTAL_PROFIT]);
      stats[i][S_MAX_ABS_DRAWDOWN] = MathMin(stats[i][S_MAX_ABS_DRAWDOWN], stats[i][S_TOTAL_PROFIT]);
      stats[i][S_MAX_REL_DRAWDOWN] = MathMin(stats[i][S_MAX_REL_DRAWDOWN], stats[i][S_TOTAL_PROFIT] - stats[i][S_MAX_PROFIT]);
   }
   if (__isChart) {
      SS.OpenLots();
      SS.TotalProfit();
      SS.ProfitStats();
   }

   if (test.onPositionOpenPause) Tester.Pause("OpenPosition(3)");
   return(SaveStatus());
}


/**
 * Close an existing open position.
 *
 * @param  double signal[] - signal infos causing the call
 *
 * @return bool - success status
 */
bool ClosePosition(double signal[]) {
   if (last_error != NULL)                return(false);
   if (instance.status != STATUS_TRADING) return(!catch("ClosePosition(1)  "+ instance.name +" cannot close position of "+ StatusDescription(instance.status) +" instance", ERR_ILLEGAL_STATE));
   if (!open.ticket)                      return(true);

   int    sigType  = signal[SIG_TYPE ];
   double sigPrice = signal[SIG_PRICE];
   int    sigOp    = signal[SIG_OP   ];

   int oeFlags, oe[];
   if (!OrderCloseEx(open.ticket, NULL, order.slippage, CLR_CLOSED, oeFlags, oe)) return(!SetLastError(oe.Error(oe)));

   datetime closeTime     = oe.CloseTime(oe);
   double   closePrice    = oe.ClosePrice(oe);
   double   closePriceSig = ifDouble(sigType==SIG_TYPE_TUNNEL, sigPrice, _Bid), openCloseRange;

   open.slippageP   += oe.Slippage(oe);
   open.swapM        = oe.Swap(oe);
   open.commissionM  = oe.Commission(oe);
   open.grossProfitM = oe.Profit(oe);
   open.netProfitM   = open.grossProfitM + open.swapM + open.commissionM;
   openCloseRange    = ifDouble(open.type==OP_BUY, closePrice-open.price, open.price-closePrice);
   open.netProfitP   = openCloseRange + (open.swapM + open.commissionM)/PointValue(open.lots);
   open.runupP       = MathMax(open.runupP, openCloseRange);
   open.rundownP     = MathMin(open.rundownP, openCloseRange);
   openCloseRange    = ifDouble(open.type==OP_BUY, closePriceSig-open.priceSig, open.priceSig-closePriceSig);
   open.sigProfitP   = openCloseRange;
   open.sigRunupP    = MathMax(open.sigRunupP, openCloseRange);
   open.sigRundownP  = MathMin(open.sigRundownP, openCloseRange);

   if (!MovePositionToHistory(closeTime, closePrice, closePriceSig)) return(false);

   // update PnL stats
   stats[NET_MONEY][S_OPEN_PROFIT] = open.netProfitM;
   stats[NET_UNITS][S_OPEN_PROFIT] = open.netProfitP;
   stats[SIG_UNITS][S_OPEN_PROFIT] = open.sigProfitP;
   for (int i=1; i <= 3; i++) {
      stats[i][S_TOTAL_PROFIT    ] = stats[i][S_OPEN_PROFIT] + stats[i][S_CLOSED_PROFIT];
      stats[i][S_MAX_PROFIT      ] = MathMax(stats[i][S_MAX_PROFIT      ], stats[i][S_TOTAL_PROFIT]);
      stats[i][S_MAX_ABS_DRAWDOWN] = MathMin(stats[i][S_MAX_ABS_DRAWDOWN], stats[i][S_TOTAL_PROFIT]);
      stats[i][S_MAX_REL_DRAWDOWN] = MathMin(stats[i][S_MAX_REL_DRAWDOWN], stats[i][S_TOTAL_PROFIT] - stats[i][S_MAX_PROFIT]);
   }
   if (__isChart) {
      SS.TotalProfit();
      SS.ProfitStats();
   }
   if (test.onPositionClosePause) Tester.Pause("ClosePosition(2)");
   return(SaveStatus());


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
   Instance.ID              = GetIniStringA(file, section, "Instance.ID", "");               // string   Instance.ID         = T123
   Tunnel                   = GetIniStringA(file, section, "Tunnel",      "");               // string   Tunnel              = EMA(1), EMA(2), EMA(3)
   Lots                     = GetIniDouble (file, section, "Lots"           );               // double   Lots                = 0.1
   if (!ReadStatus.Targets(file)) return(false);
   ShowProfitInPercent      = GetIniBool   (file, section, "ShowProfitInPercent");           // bool     ShowProfitInPercent = 1
   EA.Recorder              = GetIniStringA(file, section, "EA.Recorder",     "");           // string   EA.Recorder         = 1,2,4

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
   if (!SaveStatus.General(file, fileExists)) return(false);   // account, symbol and test infos

   // [Inputs]
   section = "Inputs";
   WriteIniString(file, section, "Instance.ID",                /*string  */ Instance.ID);
   WriteIniString(file, section, "Tunnel",                     /*string  */ Tunnel);
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
string   prev.Tunnel = "";
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
   prev.Instance.ID         = StringConcatenate(Instance.ID, "");    // string inputs are references to internal C literals
   prev.Tunnel              = StringConcatenate(Tunnel, "");         // and must be copied to break the reference
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
   Tunnel              = prev.Tunnel;
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

   // Tunnel
   if (isInitParameters && Tunnel!=prev.Tunnel) {
      if (hasOpenOrders)                           return(!onInputError("ValidateInputs(2)  "+ instance.name +" cannot change input parameter Tunnel with open orders"));
   }
   string sValue, sValues[], sMAs[];
   ArrayResize(sMAs, 0);
   int n=0, size=Explode(Tunnel, ",", sValues, NULL);
   for (int i=0; i < size; i++) {
      sValue = StrTrim(sValues[i]);
      if (sValue == "") continue;

      string sMethod = StrLeftTo(sValue, "(");
      if (sMethod == sValue)                       return(!onInputError("ValidateInputs(3)  "+ instance.name +" invalid value "+ DoubleQuoteStr(sValue) +" in input parameter Tunnel: "+ DoubleQuoteStr(Tunnel) +" (format not \"MaMethod(int)\")"));
      int iMethod = StrToMaMethod(sMethod, F_PARTIAL_ID|F_ERR_INVALID_PARAMETER);
      if (iMethod == -1)                           return(!onInputError("ValidateInputs(4)  "+ instance.name +" invalid MA method "+ DoubleQuoteStr(sMethod) +" in input parameter Tunnel: "+ DoubleQuoteStr(Tunnel)));
      if (iMethod > MODE_LWMA)                     return(!onInputError("ValidateInputs(5)  "+ instance.name +" unsupported MA method "+ DoubleQuoteStr(sMethod) +" in input parameter Tunnel: "+ DoubleQuoteStr(Tunnel)));

      string sPeriods = StrRightFrom(sValue, "(");
      if (!StrEndsWith(sPeriods, ")"))             return(!onInputError("ValidateInputs(6)  "+ instance.name +" invalid value "+ DoubleQuoteStr(sValue) +" in input parameter Tunnel: "+ DoubleQuoteStr(Tunnel) +" (format not \"MaMethod(int)\")"));
      sPeriods = StrTrim(StrLeft(sPeriods, -1));
      if (!StrIsDigits(sPeriods))                  return(!onInputError("ValidateInputs(7)  "+ instance.name +" invalid value "+ DoubleQuoteStr(sValue) +" in input parameter Tunnel: "+ DoubleQuoteStr(Tunnel) +" (format not \"MaMethod(int)\")"));
      int iPeriods = StrToInteger(sPeriods);
      if (iPeriods < 1)                            return(!onInputError("ValidateInputs(8)  "+ instance.name +" invalid MA periods "+ iPeriods +" in input parameter Tunnel: "+ DoubleQuoteStr(Tunnel) +" (must be > 0)"));

      ArrayResize(sMAs, n+1);
      sMAs[n]  = MaMethodDescription(iMethod) +"("+ iPeriods +")";
      n++;
   }
   if (!n)                                         return(!onInputError("ValidateInputs(9)  "+ instance.name +" missing input parameter Tunnel (empty)"));
   Tunnel = JoinStrings(sMAs);

   // Lots
   if (LT(Lots, 0))                                return(!onInputError("ValidateInputs(10)  "+ instance.name +" invalid input parameter Lots: "+ NumberToStr(Lots, ".1+") +" (must be > 0)"));
   if (NE(Lots, NormalizeLots(Lots)))              return(!onInputError("ValidateInputs(11)  "+ instance.name +" invalid input parameter Lots: "+ NumberToStr(Lots, ".1+") +" (must be a multiple of MODE_LOTSTEP="+ NumberToStr(MarketInfo(Symbol(), MODE_LOTSTEP), ".+") +")"));

   // Targets
   if (!ValidateInputs.Targets()) return(false);

   // EA.Recorder
   if (!Recorder_ValidateInputs(IsTestInstance())) return(false);

   SS.All();
   return(!catch("ValidateInputs(12)"));
}


/**
 * ShowStatus: Update the string representation of the instance name.
 */
void SS.InstanceName() {
   instance.name = "T."+ StrPadLeft(instance.id, 3, "0");
}


/**
 * Return a string representation of the input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("Instance.ID=",          DoubleQuoteStr(Instance.ID),    ";"+ NL +

                            "Tunnel=",               DoubleQuoteStr(Tunnel),         ";"+ NL +
                            "Filter.1=",             DoubleQuoteStr(Filter.1),       ";"+ NL +
                            "Filter.2=",             DoubleQuoteStr(Filter.2),       ";"+ NL +
                            "Filter.3=",             DoubleQuoteStr(Filter.3),       ";"+ NL +

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
