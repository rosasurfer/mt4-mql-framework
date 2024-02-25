/**
 ****************************************************************************************************************************
 *                                           WORK-IN-PROGRESS, DO NOT YET USE                                               *
 ****************************************************************************************************************************
 *
 * A combination of ideas from the "Vegas H1 Tunnel" system, the "Turtle Trading" system and a grid for scaling in/out.
 *
 *  @see [Vegas H1 Tunnel Method] https://www.forexfactory.com/thread/4365-all-vegas-documents-located-here
 *  @see [Turtle Trading]         https://analyzingalpha.com/turtle-trading
 *  @see [Turtle Trading]         http://web.archive.org/web/20220417032905/https://vantagepointtrading.com/top-trader-richard-dennis-turtle-trading-strategy/
 *
 *
 * Features
 * --------
 *  • A finished test can be loaded into an online chart for trade inspection and further analysis.
 *
 *  • The EA constantly writes a status file with complete runtime data and detailed trade statistics (more detailed than
 *    the built-in functionality). This status file can be used to move a running EA instance with all historic runtime data
 *    between different machines (e.g. from laptop to VPS).
 *
 *  • The EA supports a "virtual trading mode" in which all trades are only emulated. This makes it possible to hide all
 *    trading related deviations that impact test or real results (tester bugs, spread, slippage, swap, commission).
 *    It allows the EA to be tested and adjusted under idealised conditions.
 *
 *  • The EA contains a recorder that can record several performance graphs simultaneously at runtime (also in tester).
 *    These recordings are saved as regular chart symbols in the history directory of a second MT4 terminal. They can be
 *    displayed and analysed like regular MT4 symbols.
 *
 *
 * Requirements
 * ------------
 *  • MA Tunnel indicator: @see https://github.com/rosasurfer/mt4-mql/blob/master/mql4/indicators/MA%20Tunnel.mq4
 *  • ZigZag indicator:    @see https://github.com/rosasurfer/mt4-mql/blob/master/mql4/indicators/ZigZag.mq4
 *
 *
 * Input parameters
 * ----------------
 *  • Instance.ID:        ...
 *  • Tunnel.Definition:  ...
 *  • Donchian.Periods:   ...
 *  • Lots:               ...
 *  • EA.Recorder:        Metrics to record, for syntax @see https://github.com/rosasurfer/mt4-mql/blob/master/mql4/include/core/expert.recorder.mqh
 *
 *     1: Records real PnL after all costs in account currency (net).
 *     2: Records real PnL after all costs in price units (net).
 *     3: Records synthetic PnL before spread/any costs in price units (signal levels).
 *
 *     Metrics in price units are recorded in the best matching unit. That's pip for Forex or full points otherwise.
 *
 *
 * External control
 * ----------------
 * The EA can be controlled via execution of the following scripts (online and in tester):
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
 *  - track runup/down per position
 *  - convert signal constants to array
 *  - add entry strategies
 *  - add virtual trading
 *  - add input "TradingTimeframe"
 *  - document input params, control scripts and general usage
 */
#include <stddefines.mqh>
int   __InitFlags[] = {INIT_PIPVALUE, INIT_BUFFERED_LOG};
int __DeinitFlags[];
int __virtualTicks = 0;

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern string Instance.ID          = "";                             // instance to load from a status file, format "[T]123"
extern string Tunnel.Definition    = "EMA(9), EMA(36), EMA(144)";    // one or more MA definitions separated by comma
extern string Supported.MA.Methods = "SMA, LWMA, EMA, SMMA";
extern int    Donchian.Periods     = 30;
extern double Lots                 = 1.0;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/expert.mqh>
#include <stdfunctions.mqh>
#include <rsfLib.mqh>
#include <functions/HandleCommands.mqh>
#include <functions/IsBarOpen.mqh>
#include <functions/iCustom/MaTunnel.mqh>
#include <functions/iCustom/ZigZag.mqh>
#include <structs/rsf/OrderExecution.mqh>

#define STRATEGY_ID            108                 // unique strategy id (used for magic order numbers)

#define INSTANCE_ID_MIN          1                 // range of valid instance ids
#define INSTANCE_ID_MAX        999                 //

#define STATUS_WAITING           1                 // instance has no open positions and waits for trade signals
#define STATUS_PROGRESSING       2                 // instance manages open positions
#define STATUS_STOPPED           3                 // instance has no open positions and doesn't wait for trade signals

#define SIGNAL_LONG  TRADE_DIRECTION_LONG          // 1 signal types
#define SIGNAL_SHORT TRADE_DIRECTION_SHORT         // 2

#define METRIC_TOTAL_NET_MONEY   1                 // custom metrics
#define METRIC_TOTAL_NET_UNITS   2
#define METRIC_TOTAL_SYNTH_UNITS 3

#define METRIC_NEXT              1                 // directions for toggling between metrics
#define METRIC_PREVIOUS         -1

double history[][20];                              // trade history

#define H_TICKET                 0                 // indexes of trade history
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

double stats[4][47];                               // trade statistics

#define S_TRADES                 0                 // indexes of trade statistics
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
int      instance.id;                              // used for magic order numbers
string   instance.name = "";
datetime instance.created;
bool     instance.isTest;
int      instance.status;
double   instance.startEquity;

double   instance.openNetProfit;                   // real PnL after all costs in money (net)
double   instance.closedNetProfit;                 //
double   instance.totalNetProfit;                  //
double   instance.maxNetProfit;                    // max. observed profit:   0...+n
double   instance.maxNetDrawdown;                  // max. observed drawdown: -n...0

double   instance.openNetProfitP;                  // real PnL after all costs in point (net)
double   instance.closedNetProfitP;                //
double   instance.totalNetProfitP;                 //
double   instance.maxNetProfitP;                   //
double   instance.maxNetDrawdownP;                 //

double   instance.openSynthProfitP;                // synthetic PnL before spread/any costs in point (exact execution)
double   instance.closedSynthProfitP;              //
double   instance.totalSynthProfitP;               //
double   instance.maxSynthProfitP;                 //
double   instance.maxSynthDrawdownP;               //

// order data
int      open.ticket;                              // one open position
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
double   open.runupP;                              // max runup distance
double   open.drawdownP;                           // ...
double   open.synthProfitP;
double   open.synthRunupP;                         // max synhetic runup distance
double   open.synthDrawdownP;                      // ...

// volatile status data
int      status.activeMetric = 1;
bool     status.showOpenOrders;
bool     status.showTradeHistory;

// other
string   pUnit = "";
int      pDigits;
int      pMultiplier;
int      order.slippage = 1;                       // in MQL points

// cache vars to speed-up ShowStatus()
string   sMetricDescription = "";
string   sOpenLots          = "";
string   sClosedTrades      = "";
string   sTotalProfit       = "";
string   sProfitStats       = "";

// debug settings                                  // configurable via framework config, see afterInit()
bool     test.onStopPause        = false;          // whether to pause a test after StopInstance()
bool     test.reduceStatusWrites = true;           // whether to reduce status file I/O in tester

#include <ea/vegas-ea/init.mqh>
#include <ea/vegas-ea/deinit.mqh>

#include <ea/common/CalculateMagicNumber.mqh>
#include <ea/common/CreateInstanceId.mqh>
#include <ea/common/IsMyOrder.mqh>
#include <ea/common/IsTestInstance.mqh>
#include <ea/common/RestoreInstance.mqh>
#include <ea/common/SetInstanceId.mqh>
#include <ea/common/ValidateInputs.ID.mqh>
#include <ea/common/onInputError.mqh>

#include <ea/common/ShowTradeHistory.mqh>
#include <ea/common/ToggleOpenOrders.mqh>
#include <ea/common/ToggleTradeHistory.mqh>

#include <ea/common/file/FindStatusFile.mqh>
#include <ea/common/file/GetStatusFilename.mqh>
#include <ea/common/file/GetLogFilename.mqh>

#include <ea/common/metric/RecordMetrics.mqh>
#include <ea/common/metric/ToggleMetrics.mqh>

#include <ea/common/status/StatusToStr.mqh>
#include <ea/common/status/StatusDescription.mqh>
#include <ea/common/status/SS.InstanceName.mqh>
#include <ea/common/status/SS.MetricDescription.mqh>
#include <ea/common/status/SS.ClosedTrades.mqh>
#include <ea/common/status/SS.TotalProfit.mqh>

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

   if (__isChart) HandleCommands();                // process incoming commands

   if (instance.status != STATUS_STOPPED) {
      int signal;
      IsTradeSignal(signal);
      UpdateStatus(signal);
      RecordMetrics();
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

   if (cmd == "stop") {
      switch (instance.status) {
         case STATUS_WAITING:
         case STATUS_PROGRESSING:
            logInfo("onCommand(1)  "+ instance.name +" "+ DoubleQuoteStr(fullCmd));
            return(StopInstance());
      }
   }
   else if (cmd == "restart") {
      switch (instance.status) {
         case STATUS_STOPPED:
            logInfo("onCommand(2)  "+ instance.name +" "+ DoubleQuoteStr(fullCmd));
            return(RestartInstance());
      }
   }
   else if (cmd == "toggle-metrics") {
      int direction = ifInt(keys & F_VK_SHIFT, METRIC_PREVIOUS, METRIC_NEXT);
      return(ToggleMetrics(direction, METRIC_TOTAL_NET_MONEY, METRIC_TOTAL_SYNTH_UNITS));
   }
   else if (cmd == "toggle-open-orders") {
      return(ToggleOpenOrders());
   }
   else if (cmd == "toggle-trade-history") {
      return(ToggleTradeHistory());
   }
   else return(!logNotice("onCommand(3)  "+ instance.name +" unsupported command: "+ DoubleQuoteStr(fullCmd)));

   return(!logWarn("onCommand(4)  "+ instance.name +" cannot execute command "+ DoubleQuoteStr(fullCmd) +" in status "+ StatusToStr(instance.status)));
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
            if (IsLogNotice()) logNotice("IsMaTunnelSignal(1)  "+ instance.name +" "+ ifString(signal==SIGNAL_LONG, "long", "short") +" crossing (market: "+ NumberToStr(Bid, PriceFormat) +"/"+ NumberToStr(Ask, PriceFormat) +")");
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
            if (IsLogNotice()) logNotice("IsZigZagSignal(2)  "+ instance.name +" "+ ifString(signal==SIGNAL_LONG, "long", "short") +" reversal (market: "+ NumberToStr(Bid, PriceFormat) +"/"+ NumberToStr(Ask, PriceFormat) +")");
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
 * Update order status and PnL stats.
 *
 * @param  int signal [optional] - trade signal causing the call (default: none, update status only)
 *
 * @return bool - success status
 */
bool UpdateStatus(int signal = NULL) {
   if (last_error != NULL)                                                     return(false);
   if (instance.status!=STATUS_WAITING && instance.status!=STATUS_PROGRESSING) return(!catch("UpdateStatus(1)  "+ instance.name +" illegal instance status "+ StatusToStr(instance.status), ERR_ILLEGAL_STATE));
   bool positionClosed = false;

   // update open position
   if (open.ticket != NULL) {
      if (!SelectTicket(open.ticket, "UpdateStatus(2)")) return(false);
      bool isClosed = (OrderCloseTime() != NULL);
      if (isClosed) {
         double exitPrice=OrderClosePrice(), exitPriceSynth=exitPrice;
      }
      else {
         exitPrice = ifDouble(open.type==OP_BUY, Bid, Ask);
         exitPriceSynth = Bid;
      }
      open.swap           = NormalizeDouble(OrderSwap(), 2);
      open.commission     = OrderCommission();
      open.grossProfit    = OrderProfit();
      open.netProfit      = open.grossProfit + open.swap + open.commission;
      open.netProfitP     = ifDouble(open.type==OP_BUY, exitPrice-open.price, open.price-exitPrice);
      open.runupP         = MathMax(open.runupP, open.netProfitP);
      open.drawdownP      = MathMin(open.drawdownP, open.netProfitP); if (open.swap || open.commission) open.netProfitP += (open.swap + open.commission)/PointValue(open.lots);
      open.synthProfitP   = ifDouble(open.type==OP_BUY, exitPriceSynth-open.priceSynth, open.priceSynth-exitPriceSynth);
      open.synthRunupP    = MathMax(open.synthRunupP, open.synthProfitP);
      open.synthDrawdownP = MathMin(open.synthDrawdownP, open.synthProfitP);

      if (isClosed) {
         int error;
         if (IsError(onPositionClose("UpdateStatus(3)  "+ instance.name +" "+ UpdateStatus.PositionCloseMsg(error), error))) return(false);
         if (!MovePositionToHistory(OrderCloseTime(), exitPrice, exitPriceSynth))                                            return(false);
         positionClosed = true;
      }
   }

   // process signal
   if (signal != NULL) {
      instance.status = STATUS_PROGRESSING;

      // close an existing open position
      if (open.ticket != NULL) {
         if (open.type != ifInt(signal==SIGNAL_SHORT, OP_LONG, OP_SHORT)) return(!catch("UpdateStatus(4)  "+ instance.name +" cannot process "+ SignalToStr(signal) +" with open "+ OperationTypeToStr(open.type) +" position", ERR_ILLEGAL_STATE));

         int oeFlags, oe[];
         if (!OrderCloseEx(open.ticket, NULL, NULL, CLR_CLOSED, oeFlags, oe)) return(!SetLastError(oe.Error(oe)));

         double closePrice   = oe.ClosePrice(oe);
         open.slippage      += oe.Slippage(oe);
         open.swap           = oe.Swap(oe);
         open.commission     = oe.Commission(oe);
         open.grossProfit    = oe.Profit(oe);
         open.netProfit      = open.grossProfit + open.swap + open.commission;
         open.netProfitP     = ifDouble(open.type==OP_BUY, closePrice-open.price, open.price-closePrice);
         open.runupP         = MathMax(open.runupP, open.netProfitP);
         open.drawdownP      = MathMin(open.drawdownP, open.netProfitP); if (open.swap || open.commission) open.netProfitP += (open.swap + open.commission)/PointValue(open.lots);
         open.synthProfitP   = ifDouble(open.type==OP_BUY, Bid-open.priceSynth, open.priceSynth-Bid);
         open.synthRunupP    = MathMax(open.synthRunupP, open.synthProfitP);
         open.synthDrawdownP = MathMin(open.synthDrawdownP, open.synthProfitP);

         if (!MovePositionToHistory(oe.CloseTime(oe), closePrice, Bid)) return(false);
      }

      // open new position
      int      type        = ifInt(signal==SIGNAL_LONG, OP_BUY, OP_SELL);
      double   price       = NULL;
      double   stopLoss    = NULL;
      double   takeProfit  = NULL;
      string   comment     = "Vegas."+ StrPadLeft(instance.id, 3, "0");
      int      magicNumber = CalculateMagicNumber(instance.id);
      datetime expires     = NULL;
      color    markerColor = ifInt(signal==SIGNAL_LONG, CLR_OPEN_LONG, CLR_OPEN_SHORT);
               oeFlags     = NULL;

      int ticket = OrderSendEx(NULL, type, Lots, price, order.slippage, stopLoss, takeProfit, comment, magicNumber, expires, markerColor, oeFlags, oe);
      if (!ticket) return(!SetLastError(oe.Error(oe)));

      // store the new position
      open.ticket         = ticket;
      open.type           = type;
      open.lots           = oe.Lots(oe);
      open.time           = oe.OpenTime(oe);
      open.price          = oe.OpenPrice(oe);
      open.priceSynth     = Bid;
      open.slippage       = oe.Slippage(oe);
      open.swap           = oe.Swap(oe);
      open.commission     = oe.Commission(oe);
      open.grossProfit    = oe.Profit(oe);
      open.netProfit      = open.grossProfit + open.swap + open.commission;
      open.netProfitP     = ifDouble(open.type==OP_BUY, Bid-open.price, open.price-Ask); if (open.swap || open.commission) open.netProfitP += (open.swap + open.commission)/PointValue(open.lots);
      open.runupP         = ifDouble(open.type==OP_BUY, Bid-open.price, open.price-Ask);
      open.drawdownP      = open.runupP;
      open.synthProfitP   = 0;
      open.synthRunupP    = open.synthProfitP;
      open.synthDrawdownP = open.synthRunupP;
      if (__isChart) SS.OpenLots();
   }

   // update PL numbers
   instance.openNetProfit    = open.netProfit;
   instance.openNetProfitP   = open.netProfitP;
   instance.openSynthProfitP = open.synthProfitP;

   instance.totalNetProfit    = instance.openNetProfit    + instance.closedNetProfit;
   instance.totalNetProfitP   = instance.openNetProfitP   + instance.closedNetProfitP;
   instance.totalSynthProfitP = instance.openSynthProfitP + instance.closedSynthProfitP;
   if (__isChart) SS.TotalProfit();

   instance.maxNetProfit      = MathMax(instance.maxNetProfit,      instance.totalNetProfit);
   instance.maxNetDrawdown    = MathMin(instance.maxNetDrawdown,    instance.totalNetProfit);
   instance.maxNetProfitP     = MathMax(instance.maxNetProfitP,     instance.totalNetProfitP);
   instance.maxNetDrawdownP   = MathMin(instance.maxNetDrawdownP,   instance.totalNetProfitP);
   instance.maxSynthProfitP   = MathMax(instance.maxSynthProfitP,   instance.totalSynthProfitP);
   instance.maxSynthDrawdownP = MathMin(instance.maxSynthDrawdownP, instance.totalSynthProfitP);
   if (__isChart) SS.ProfitStats();

   if (positionClosed || signal)
      return(SaveStatus());
   return(!catch("UpdateStatus(5)"));
}


/**
 * Compose a log message for a closed position. The ticket must be selected.
 *
 * @param  _Out_ int error - error code to be returned from the call (if any)
 *
 * @return string - log message or an empty string in case of errors
 */
string UpdateStatus.PositionCloseMsg(int &error) {
   // #1 Sell 0.1 GBPUSD at 1.5457'2 ("V.869") was [unexpectedly ]closed [by SL ]at 1.5457'2 (market: Bid/Ask[, so: 47.7%/169.20/354.40])
   error = NO_ERROR;

   int    ticket      = OrderTicket();
   double lots        = OrderLots();
   string sType       = OperationTypeDescription(OrderType());
   string sOpenPrice  = NumberToStr(OrderOpenPrice(), PriceFormat);
   string sClosePrice = NumberToStr(OrderClosePrice(), PriceFormat);
   string sUnexpected = ifString(__isTesting && __CoreFunction==CF_DEINIT, "", "unexpectedly ");
   string message     = "#"+ ticket +" "+ sType +" "+ NumberToStr(lots, ".+") +" "+ OrderSymbol() +" at "+ sOpenPrice +" (\""+ instance.name +"\") was "+ sUnexpected +"closed at "+ sClosePrice;

   string sStopout = "";
   if (StrStartsWithI(OrderComment(), "so:")) {       error = ERR_MARGIN_STOPOUT; sStopout = ", "+ OrderComment(); }
   else if (__isTesting && __CoreFunction==CF_DEINIT) error = NO_ERROR;
   else                                               error = ERR_CONCURRENT_MODIFICATION;

   return(message +" (market: "+ NumberToStr(Bid, PriceFormat) +"/"+ NumberToStr(Ask, PriceFormat) + sStopout +")");
}


/**
 * Event handler for an unexpectedly closed position.
 *
 * @param  string message - error message
 * @param  int    error   - error code
 *
 * @return int - error status, i.e. whether to interrupt program execution
 */
int onPositionClose(string message, int error) {
   if (!error) return(logInfo(message));                    // no error

   if (error == ERR_ORDER_CHANGED)                          // expected in a fast market: a SL was triggered
      return(!logNotice(message, error));                   // continue

   if (__isTesting) return(catch(message, error));          // in tester treat everything else as terminating

   logWarn(message, error);                                 // online
   if (error == ERR_CONCURRENT_MODIFICATION)                // unexpected: most probably manually closed
      return(NO_ERROR);                                     // continue
   return(error);
}


/**
 * Stop a waiting or progressing instance and close open positions (if any).
 *
 * @return bool - success status
 */
bool StopInstance() {
   if (last_error != NULL)                                                     return(false);
   if (instance.status!=STATUS_WAITING && instance.status!=STATUS_PROGRESSING) return(!catch("StopInstance(1)  "+ instance.name +" cannot stop "+ StatusDescription(instance.status) +" instance", ERR_ILLEGAL_STATE));

   // close an open position
   if (instance.status == STATUS_PROGRESSING) {
      if (open.ticket > 0) {
         if (IsLogInfo()) logInfo("StopInstance(2)  "+ instance.name +" stopping");
         int oeFlags, oe[];
         if (!OrderCloseEx(open.ticket, NULL, NULL, CLR_CLOSED, oeFlags, oe)) return(!SetLastError(oe.Error(oe)));

         double closePrice   = oe.ClosePrice(oe);
         open.slippage      += oe.Slippage  (oe);
         open.swap           = oe.Swap      (oe);
         open.commission     = oe.Commission(oe);
         open.grossProfit    = oe.Profit    (oe);
         open.netProfit      = open.grossProfit + open.swap + open.commission;
         open.netProfitP     = ifDouble(open.type==OP_BUY, closePrice-open.price, open.price-closePrice);
         open.runupP         = MathMax(open.runupP, open.netProfitP);
         open.drawdownP      = MathMin(open.drawdownP, open.netProfitP); open.netProfitP += (open.swap + open.commission)/PointValue(open.lots);
         open.synthProfitP   = ifDouble(open.type==OP_BUY, Bid-open.priceSynth, open.priceSynth-Bid);
         open.synthRunupP    = MathMax(open.synthRunupP, open.synthProfitP);
         open.synthDrawdownP = MathMin(open.synthDrawdownP, open.synthProfitP);

         if (!MovePositionToHistory(oe.CloseTime(oe), closePrice, Bid)) return(false);

         // update PL numbers
         instance.openNetProfit  = open.netProfit;
         instance.totalNetProfit = instance.openNetProfit + instance.closedNetProfit;
         instance.maxNetProfit   = MathMax(instance.maxNetProfit,   instance.totalNetProfit);
         instance.maxNetDrawdown = MathMin(instance.maxNetDrawdown, instance.totalNetProfit);

         instance.openNetProfitP  = open.netProfitP;
         instance.totalNetProfitP = instance.openNetProfitP + instance.closedNetProfitP;
         instance.maxNetProfitP   = MathMax(instance.maxNetProfitP,   instance.totalNetProfitP);
         instance.maxNetDrawdownP = MathMin(instance.maxNetDrawdownP, instance.totalNetProfitP);

         instance.openSynthProfitP  = open.synthProfitP;
         instance.totalSynthProfitP = instance.openSynthProfitP + instance.closedSynthProfitP;
         instance.maxSynthProfitP   = MathMax(instance.maxSynthProfitP,   instance.totalSynthProfitP);
         instance.maxSynthDrawdownP = MathMin(instance.maxSynthDrawdownP, instance.totalSynthProfitP);
      }
   }

   // update status
   instance.status = STATUS_STOPPED;
   SS.TotalProfit();
   SS.ProfitStats();

   if (IsLogInfo()) logInfo("StopInstance(3)  "+ instance.name +" "+ ifString(__isTesting, "test ", "") +"instance stopped, profit: "+ sTotalProfit +" "+ sProfitStats);
   SaveStatus();

   // pause/stop the tester according to the debug configuration
   if (__isTesting) {
      if      (!IsVisualMode())  Tester.Stop ("StopInstance(4)");
      else if (test.onStopPause) Tester.Pause("StopInstance(5)");
   }
   return(!catch("StopInstance(6)"));
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
 * Move the position referenced in open.* to the trade history. Assumes the position is already closed.
 *
 * @param datetime closeTime       - close time
 * @param double   closePrice      - close price
 * @param double   closePriceSynth - synthetic close price
 *
 * @return bool - success status
 */
bool MovePositionToHistory(datetime closeTime, double closePrice, double closePriceSynth) {
   if (last_error != NULL)                    return(false);
   if (instance.status != STATUS_PROGRESSING) return(!catch("MovePositionToHistory(1)  "+ instance.name +" cannot process position of "+ StatusDescription(instance.status) +" instance", ERR_ILLEGAL_STATE));
   if (!open.ticket)                          return(!catch("MovePositionToHistory(2)  "+ instance.name +" no position found (open.ticket=NULL)", ERR_ILLEGAL_STATE));

   // add data to history
   int i = ArrayRange(history, 0);
   ArrayResize(history, i+1);
   history[i][H_TICKET          ] = open.ticket;
   history[i][H_TYPE            ] = open.type;
   history[i][H_LOTS            ] = open.lots;
   history[i][H_OPENTIME        ] = open.time;
   history[i][H_OPENPRICE       ] = open.price;
   history[i][H_OPENPRICE_SYNTH ] = open.priceSynth;
   history[i][H_CLOSETIME       ] = closeTime;
   history[i][H_CLOSEPRICE      ] = closePrice;
   history[i][H_CLOSEPRICE_SYNTH] = closePriceSynth;
   history[i][H_SLIPPAGE        ] = open.slippage;
   history[i][H_SWAP            ] = open.swap;
   history[i][H_COMMISSION      ] = open.commission;
   history[i][H_GROSSPROFIT     ] = open.grossProfit;
   history[i][H_NETPROFIT       ] = open.netProfit;
   history[i][H_NETPROFIT_P     ] = open.netProfitP;
   history[i][H_RUNUP_P         ] = open.runupP;
   history[i][H_DRAWDOWN_P      ] = open.drawdownP;
   history[i][H_SYNTH_PROFIT_P  ] = open.synthProfitP;
   history[i][H_SYNTH_RUNUP_P   ] = open.synthRunupP;
   history[i][H_SYNTH_DRAWDOWN_P] = open.synthDrawdownP;

   // update PL numbers
   instance.openNetProfit    = 0;
   instance.openNetProfitP   = 0;
   instance.openSynthProfitP = 0;

   instance.closedNetProfit    += open.netProfit;
   instance.closedNetProfitP   += open.netProfitP;
   instance.closedSynthProfitP += open.synthProfitP;

   // reset open position data
   open.ticket         = NULL;
   open.type           = NULL;
   open.lots           = NULL;
   open.time           = NULL;
   open.price          = NULL;
   open.priceSynth     = NULL;
   open.slippage       = NULL;
   open.swap           = NULL;
   open.commission     = NULL;
   open.grossProfit    = NULL;
   open.netProfit      = NULL;
   open.netProfitP     = NULL;
   open.runupP         = NULL;
   open.drawdownP      = NULL;
   open.synthProfitP   = NULL;
   open.synthRunupP    = NULL;
   open.synthDrawdownP = NULL;

   if (__isChart) {
      CalculateStats();             // update trade stats
      SS.OpenLots();
      SS.ClosedTrades();
   }
   return(!catch("MovePositionToHistory(3)"));
}


/**
 * Update trade statistics.
 */
void CalculateStats() {
   int trades = ArrayRange(history, 0);
   int prevTrades = stats[1][S_TRADES];

   if (!trades || trades < prevTrades) {
      ArrayInitialize(stats, 0);
      prevTrades = 0;
   }

   if (trades > prevTrades) {
      for (int i=prevTrades; i < trades; i++) {                   // speed-up by processing only new history entries
         // all metrics: all trades
         if (history[i][H_TYPE] == OP_LONG) {
            stats[METRIC_TOTAL_NET_MONEY  ][S_TRADES_LONG]++;
            stats[METRIC_TOTAL_NET_UNITS  ][S_TRADES_LONG]++;
            stats[METRIC_TOTAL_SYNTH_UNITS][S_TRADES_LONG]++;
         }
         else {
            stats[METRIC_TOTAL_NET_MONEY  ][S_TRADES_SHORT]++;
            stats[METRIC_TOTAL_NET_UNITS  ][S_TRADES_SHORT]++;
            stats[METRIC_TOTAL_SYNTH_UNITS][S_TRADES_SHORT]++;
         }
         stats[METRIC_TOTAL_NET_MONEY  ][S_TRADES_SUM_RUNUP   ] += history[i][H_RUNUP_P   ];
         stats[METRIC_TOTAL_NET_MONEY  ][S_TRADES_SUM_DRAWDOWN] += history[i][H_DRAWDOWN_P];
         stats[METRIC_TOTAL_NET_MONEY  ][S_TRADES_SUM_PROFIT  ] += history[i][H_NETPROFIT ];

         stats[METRIC_TOTAL_NET_UNITS  ][S_TRADES_SUM_RUNUP   ] += history[i][H_RUNUP_P    ];
         stats[METRIC_TOTAL_NET_UNITS  ][S_TRADES_SUM_DRAWDOWN] += history[i][H_DRAWDOWN_P ];
         stats[METRIC_TOTAL_NET_UNITS  ][S_TRADES_SUM_PROFIT  ] += history[i][H_NETPROFIT_P];

         stats[METRIC_TOTAL_SYNTH_UNITS][S_TRADES_SUM_RUNUP   ] += history[i][H_SYNTH_RUNUP_P   ];
         stats[METRIC_TOTAL_SYNTH_UNITS][S_TRADES_SUM_DRAWDOWN] += history[i][H_SYNTH_DRAWDOWN_P];
         stats[METRIC_TOTAL_SYNTH_UNITS][S_TRADES_SUM_PROFIT  ] += history[i][H_SYNTH_PROFIT_P  ];

         // METRIC_TOTAL_NET_MONEY
         if (GT(history[i][H_NETPROFIT_P], 0.5*Point)) {          // to simplify scratch limits we compare against H_NETPROFIT_P
            // winners
            stats[METRIC_TOTAL_NET_MONEY][S_WINNERS]++;
            if (history[i][H_TYPE] == OP_LONG) stats[METRIC_TOTAL_NET_MONEY][S_WINNERS_LONG ]++;
            else                               stats[METRIC_TOTAL_NET_MONEY][S_WINNERS_SHORT]++;
            stats[METRIC_TOTAL_NET_MONEY][S_WINNERS_SUM_RUNUP   ] += history[i][H_RUNUP_P   ];
            stats[METRIC_TOTAL_NET_MONEY][S_WINNERS_SUM_DRAWDOWN] += history[i][H_DRAWDOWN_P];
            stats[METRIC_TOTAL_NET_MONEY][S_WINNERS_SUM_PROFIT  ] += history[i][H_NETPROFIT ];
         }
         else if (LT(history[i][H_NETPROFIT_P], -0.5*Point)) {
            // losers
            stats[METRIC_TOTAL_NET_MONEY][S_LOSERS]++;
            if (history[i][H_TYPE] == OP_LONG) stats[METRIC_TOTAL_NET_MONEY][S_LOSERS_LONG ]++;
            else                               stats[METRIC_TOTAL_NET_MONEY][S_LOSERS_SHORT]++;
            stats[METRIC_TOTAL_NET_MONEY][S_LOSERS_SUM_RUNUP   ] += history[i][H_RUNUP_P   ];
            stats[METRIC_TOTAL_NET_MONEY][S_LOSERS_SUM_DRAWDOWN] += history[i][H_DRAWDOWN_P];
            stats[METRIC_TOTAL_NET_MONEY][S_LOSERS_SUM_PROFIT  ] += history[i][H_NETPROFIT ];
         }
         else {
            // scratch
            stats[METRIC_TOTAL_NET_MONEY][S_SCRATCH]++;
            if (history[i][H_TYPE] == OP_LONG) stats[METRIC_TOTAL_NET_MONEY][S_SCRATCH_LONG ]++;
            else                               stats[METRIC_TOTAL_NET_MONEY][S_SCRATCH_SHORT]++;
            stats[METRIC_TOTAL_NET_MONEY][S_SCRATCH_SUM_RUNUP   ] += history[i][H_RUNUP_P   ];
            stats[METRIC_TOTAL_NET_MONEY][S_SCRATCH_SUM_DRAWDOWN] += history[i][H_DRAWDOWN_P];
            stats[METRIC_TOTAL_NET_MONEY][S_SCRATCH_SUM_PROFIT  ] += history[i][H_NETPROFIT ];
         }

         // METRIC_TOTAL_NET_UNITS
         if (GT(history[i][H_NETPROFIT_P], 0.5*Point)) {
            // winners
            stats[METRIC_TOTAL_NET_UNITS][S_WINNERS]++;
            if (history[i][H_TYPE] == OP_LONG) stats[METRIC_TOTAL_NET_UNITS][S_WINNERS_LONG ]++;
            else                               stats[METRIC_TOTAL_NET_UNITS][S_WINNERS_SHORT]++;
            stats[METRIC_TOTAL_NET_UNITS][S_WINNERS_SUM_RUNUP   ] += history[i][H_RUNUP_P    ];
            stats[METRIC_TOTAL_NET_UNITS][S_WINNERS_SUM_DRAWDOWN] += history[i][H_DRAWDOWN_P ];
            stats[METRIC_TOTAL_NET_UNITS][S_WINNERS_SUM_PROFIT  ] += history[i][H_NETPROFIT_P];
         }
         else if (LT(history[i][H_NETPROFIT_P], -0.5*Point)) {
            // losers
            stats[METRIC_TOTAL_NET_UNITS][S_LOSERS]++;
            if (history[i][H_TYPE] == OP_LONG) stats[METRIC_TOTAL_NET_UNITS][S_LOSERS_LONG ]++;
            else                               stats[METRIC_TOTAL_NET_UNITS][S_LOSERS_SHORT]++;
            stats[METRIC_TOTAL_NET_UNITS][S_LOSERS_SUM_RUNUP   ] += history[i][H_RUNUP_P    ];
            stats[METRIC_TOTAL_NET_UNITS][S_LOSERS_SUM_DRAWDOWN] += history[i][H_DRAWDOWN_P ];
            stats[METRIC_TOTAL_NET_UNITS][S_LOSERS_SUM_PROFIT  ] += history[i][H_NETPROFIT_P];
         }
         else {
            // scratch
            stats[METRIC_TOTAL_NET_UNITS][S_SCRATCH]++;
            if (history[i][H_TYPE] == OP_LONG) stats[METRIC_TOTAL_NET_UNITS][S_SCRATCH_LONG ]++;
            else                               stats[METRIC_TOTAL_NET_UNITS][S_SCRATCH_SHORT]++;
            stats[METRIC_TOTAL_NET_UNITS][S_SCRATCH_SUM_RUNUP   ] += history[i][H_RUNUP_P    ];
            stats[METRIC_TOTAL_NET_UNITS][S_SCRATCH_SUM_DRAWDOWN] += history[i][H_DRAWDOWN_P ];
            stats[METRIC_TOTAL_NET_UNITS][S_SCRATCH_SUM_PROFIT  ] += history[i][H_NETPROFIT_P];
         }

         // METRIC_TOTAL_SYNTH_UNITS
         if (GT(history[i][H_SYNTH_PROFIT_P], 0.5*Point)) {
            // winners
            stats[METRIC_TOTAL_SYNTH_UNITS][S_WINNERS]++;
            if (history[i][H_TYPE] == OP_LONG) stats[METRIC_TOTAL_SYNTH_UNITS][S_WINNERS_LONG ]++;
            else                               stats[METRIC_TOTAL_SYNTH_UNITS][S_WINNERS_SHORT]++;
            stats[METRIC_TOTAL_SYNTH_UNITS][S_WINNERS_SUM_RUNUP   ] += history[i][H_SYNTH_RUNUP_P   ];
            stats[METRIC_TOTAL_SYNTH_UNITS][S_WINNERS_SUM_DRAWDOWN] += history[i][H_SYNTH_DRAWDOWN_P];
            stats[METRIC_TOTAL_SYNTH_UNITS][S_WINNERS_SUM_PROFIT  ] += history[i][H_SYNTH_PROFIT_P  ];
         }
         else if (LT(history[i][H_SYNTH_PROFIT_P], -0.5*Point)) {
            // losers
            stats[METRIC_TOTAL_SYNTH_UNITS][S_LOSERS]++;
            if (history[i][H_TYPE] == OP_LONG) stats[METRIC_TOTAL_SYNTH_UNITS][S_LOSERS_LONG ]++;
            else                               stats[METRIC_TOTAL_SYNTH_UNITS][S_LOSERS_SHORT]++;
            stats[METRIC_TOTAL_SYNTH_UNITS][S_LOSERS_SUM_RUNUP   ] += history[i][H_SYNTH_RUNUP_P   ];
            stats[METRIC_TOTAL_SYNTH_UNITS][S_LOSERS_SUM_DRAWDOWN] += history[i][H_SYNTH_DRAWDOWN_P];
            stats[METRIC_TOTAL_SYNTH_UNITS][S_LOSERS_SUM_PROFIT  ] += history[i][H_SYNTH_PROFIT_P  ];
         }
         else {
            // scratch
            stats[METRIC_TOTAL_SYNTH_UNITS][S_SCRATCH]++;
            if (history[i][H_TYPE] == OP_LONG) stats[METRIC_TOTAL_SYNTH_UNITS][S_SCRATCH_LONG ]++;
            else                               stats[METRIC_TOTAL_SYNTH_UNITS][S_SCRATCH_SHORT]++;
            stats[METRIC_TOTAL_SYNTH_UNITS][S_SCRATCH_SUM_RUNUP   ] += history[i][H_SYNTH_RUNUP_P   ];
            stats[METRIC_TOTAL_SYNTH_UNITS][S_SCRATCH_SUM_DRAWDOWN] += history[i][H_SYNTH_DRAWDOWN_P];
            stats[METRIC_TOTAL_SYNTH_UNITS][S_SCRATCH_SUM_PROFIT  ] += history[i][H_SYNTH_PROFIT_P  ];
         }
      }

      // total number of trades, percentages and averages
      for (i=ArrayRange(stats, 0)-1; i > 0; i--) {                // skip unused index 0
         stats[i][S_TRADES] = trades;

         stats[i][S_TRADES_LONG_PCT     ] = MathDiv(stats[i][S_TRADES_LONG         ], stats[i][S_TRADES ]);
         stats[i][S_TRADES_SHORT_PCT    ] = MathDiv(stats[i][S_TRADES_SHORT        ], stats[i][S_TRADES ]);
         stats[i][S_WINNERS_PCT         ] = MathDiv(stats[i][S_WINNERS             ], stats[i][S_TRADES ]);
         stats[i][S_WINNERS_LONG_PCT    ] = MathDiv(stats[i][S_WINNERS_LONG        ], stats[i][S_WINNERS]);
         stats[i][S_WINNERS_SHORT_PCT   ] = MathDiv(stats[i][S_WINNERS_SHORT       ], stats[i][S_WINNERS]);
         stats[i][S_LOSERS_PCT          ] = MathDiv(stats[i][S_LOSERS              ], stats[i][S_TRADES ]);
         stats[i][S_LOSERS_LONG_PCT     ] = MathDiv(stats[i][S_LOSERS_LONG         ], stats[i][S_LOSERS ]);
         stats[i][S_LOSERS_SHORT_PCT    ] = MathDiv(stats[i][S_LOSERS_SHORT        ], stats[i][S_LOSERS ]);
         stats[i][S_SCRATCH_PCT         ] = MathDiv(stats[i][S_SCRATCH             ], stats[i][S_TRADES ]);
         stats[i][S_SCRATCH_LONG_PCT    ] = MathDiv(stats[i][S_SCRATCH_LONG        ], stats[i][S_SCRATCH]);
         stats[i][S_SCRATCH_SHORT_PCT   ] = MathDiv(stats[i][S_SCRATCH_SHORT       ], stats[i][S_SCRATCH]);

         stats[i][S_TRADES_AVG_RUNUP    ] = MathDiv(stats[i][S_TRADES_SUM_RUNUP    ], stats[i][S_TRADES ]);
         stats[i][S_TRADES_AVG_DRAWDOWN ] = MathDiv(stats[i][S_TRADES_SUM_DRAWDOWN ], stats[i][S_TRADES ]);
         stats[i][S_TRADES_AVG_PROFIT   ] = MathDiv(stats[i][S_TRADES_SUM_PROFIT   ], stats[i][S_TRADES ]);

         stats[i][S_WINNERS_AVG_RUNUP   ] = MathDiv(stats[i][S_WINNERS_SUM_RUNUP   ], stats[i][S_WINNERS]);
         stats[i][S_WINNERS_AVG_DRAWDOWN] = MathDiv(stats[i][S_WINNERS_SUM_DRAWDOWN], stats[i][S_WINNERS]);
         stats[i][S_WINNERS_AVG_PROFIT  ] = MathDiv(stats[i][S_WINNERS_SUM_PROFIT  ], stats[i][S_WINNERS]);

         stats[i][S_LOSERS_AVG_RUNUP    ] = MathDiv(stats[i][S_LOSERS_SUM_RUNUP    ], stats[i][S_LOSERS ]);
         stats[i][S_LOSERS_AVG_DRAWDOWN ] = MathDiv(stats[i][S_LOSERS_SUM_DRAWDOWN ], stats[i][S_LOSERS ]);
         stats[i][S_LOSERS_AVG_PROFIT   ] = MathDiv(stats[i][S_LOSERS_SUM_PROFIT   ], stats[i][S_LOSERS ]);

         stats[i][S_SCRATCH_AVG_RUNUP   ] = MathDiv(stats[i][S_SCRATCH_SUM_RUNUP   ], stats[i][S_SCRATCH]);
         stats[i][S_SCRATCH_AVG_DRAWDOWN] = MathDiv(stats[i][S_SCRATCH_SUM_DRAWDOWN], stats[i][S_SCRATCH]);
         stats[i][S_SCRATCH_AVG_PROFIT  ] = MathDiv(stats[i][S_SCRATCH_SUM_PROFIT  ], stats[i][S_SCRATCH]);
      }
   }
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
   string sTunnelDefinition   = GetIniStringA(file, section, "Tunnel.Definition", "");          // string Tunnel.Definition = EMA(1), EMA(2), EMA(3)
   int    iDonchianPeriods    = GetIniInt    (file, section, "Donchian.Periods"     );          // int    Donchian.Periods  = 40
   string sLots               = GetIniStringA(file, section, "Lots",              "");          // double Lots              = 0.1
   string sEaRecorder         = GetIniStringA(file, section, "EA.Recorder",       "");          // string EA.Recorder       = 1,2,4

   if (!StrIsNumeric(sLots)) return(!catch("ReadStatus(7)  "+ instance.name +" invalid input parameter Lots "+ DoubleQuoteStr(sLots) +" in status file "+ DoubleQuoteStr(file), ERR_INVALID_FILE_FORMAT));

   Instance.ID       = sInstanceID;
   Tunnel.Definition = sTunnelDefinition;
   Donchian.Periods  = iDonchianPeriods;
   Lots              = StrToDouble(sLots);
   EA.Recorder       = sEaRecorder;

   // [Runtime status]
   section = "Runtime status";
   instance.id                 = GetIniInt    (file, section, "instance.id"      );             // int      instance.id              = 123
   instance.name               = GetIniStringA(file, section, "instance.name", "");             // string   instance.name            = V.123
   instance.created            = GetIniInt    (file, section, "instance.created" );             // datetime instance.created         = 1624924800 (Mon, 2021.05.12 13:22:34)
   instance.isTest             = GetIniBool   (file, section, "instance.isTest"  );             // bool     instance.isTest          = 1
   instance.status             = GetIniInt    (file, section, "instance.status"  );             // int      instance.status          = 1 (waiting)
   recorder.stdEquitySymbol    = GetIniStringA(file, section, "recorder.stdEquitySymbol", "");  // string   recorder.stdEquitySymbol = GBPJPY.001
   SS.InstanceName();

   // [Stats: net in money]
   section = "Stats: net in money";
   instance.openNetProfit      = GetIniDouble (file, section, "openProfit"  );                  // double   openProfit   = 23.45
   instance.closedNetProfit    = GetIniDouble (file, section, "closedProfit");                  // double   closedProfit = 45.67
   instance.totalNetProfit     = GetIniDouble (file, section, "totalProfit" );                  // double   totalProfit  = 123.45
   instance.maxNetDrawdown     = GetIniDouble (file, section, "minProfit"   );                  // double   minProfit    = -11.23
   instance.maxNetProfit       = GetIniDouble (file, section, "maxProfit"   );                  // double   maxProfit    = 23.45

   // [Stats: net in punits]
   section = "Stats: net in "+ pUnit;
   instance.openNetProfitP     = GetIniDouble (file, section, "openProfit"  )/pMultiplier;      // double   openProfit   = 1234.5
   instance.closedNetProfitP   = GetIniDouble (file, section, "closedProfit")/pMultiplier;      // double   closedProfit = -2345.6
   instance.totalNetProfitP    = GetIniDouble (file, section, "totalProfit" )/pMultiplier;      // double   totalProfit  = 12345.6
   instance.maxNetDrawdownP    = GetIniDouble (file, section, "minProfit"   )/pMultiplier;      // double   minProfit    = -2345.6
   instance.maxNetProfitP      = GetIniDouble (file, section, "maxProfit"   )/pMultiplier;      // double   maxProfit    = 1234.5

   // [Stats: synthetic in punits]
   section = "Stats: synthetic in "+ pUnit;
   instance.openSynthProfitP   = GetIniDouble (file, section, "openProfit"  )/pMultiplier;      // double   openProfit   = 1234.5
   instance.closedSynthProfitP = GetIniDouble (file, section, "closedProfit")/pMultiplier;      // double   closedProfit = -2345.6
   instance.totalSynthProfitP  = GetIniDouble (file, section, "totalProfit" )/pMultiplier;      // double   totalProfit  = 12345.6
   instance.maxSynthDrawdownP  = GetIniDouble (file, section, "minProfit"   )/pMultiplier;      // double   minProfit    = -2345.6
   instance.maxSynthProfitP    = GetIniDouble (file, section, "maxProfit"   )/pMultiplier;      // double   maxProfit    = 1234.5

   // [Open positions]
   section = "Open positions";
   open.ticket                 = GetIniInt    (file, section, "open.ticket"      );             // int      open.ticket       = 123456
   open.type                   = GetIniInt    (file, section, "open.type"        );             // int      open.type         = 1
   open.lots                   = GetIniDouble (file, section, "open.lots"        );             // double   open.lots         = 0.01
   open.time                   = GetIniInt    (file, section, "open.time"        );             // datetime open.time         = 1624924800 (Mon, 2021.05.12 13:22:34)
   open.price                  = GetIniDouble (file, section, "open.price"       );             // double   open.price        = 1.24363
   open.priceSynth             = GetIniDouble (file, section, "open.priceSynth"  );             // double   open.priceSynth   = 1.24363
   open.slippage               = GetIniDouble (file, section, "open.slippage"    );             // double   open.slippage     = 0.00003
   open.swap                   = GetIniDouble (file, section, "open.swap"        );             // double   open.swap         = -1.23
   open.commission             = GetIniDouble (file, section, "open.commission"  );             // double   open.commission   = -5.50
   open.grossProfit            = GetIniDouble (file, section, "open.grossProfit" );             // double   open.grossProfit  = 12.34
   open.netProfit              = GetIniDouble (file, section, "open.netProfit"   );             // double   open.netProfit    = 12.56
   open.netProfitP             = GetIniDouble (file, section, "open.netProfitP"  );             // double   open.netProfitP   = 0.12345
   open.synthProfitP           = GetIniDouble (file, section, "open.synthProfitP");             // double   open.synthProfitP = 0.12345

   // [Trade history]
   section = "Trade history";
   string sKeys[], sOrder="";
   double netProfit, netProfitP, synthProfitP;
   int size = ReadStatus.HistoryKeys(file, section, sKeys); if (size < 0) return(false);

   for (int i=0; i < size; i++) {
      sOrder = GetIniStringA(file, section, sKeys[i], "");                                      // history.{i} = {data}
      int n = ReadStatus.RestoreHistory(sKeys[i], sOrder);
      if (n < 0) return(!catch("ReadStatus(8)  "+ instance.name +" invalid history record in status file "+ DoubleQuoteStr(file) + NL + sKeys[i] +"="+ sOrder, ERR_INVALID_FILE_FORMAT));

      netProfit    += history[n][H_NETPROFIT     ];
      netProfitP   += history[n][H_NETPROFIT_P   ];
      synthProfitP += history[n][H_SYNTH_PROFIT_P];
   }

   // cross-check restored stats
   int precision = MathMax(Digits, 2) + 1;                      // required precision for fractional point values
   if (NE(netProfit,    instance.closedNetProfit, 2))           return(!catch("ReadStatus(9)  "+  instance.name +" sum(history[H_NETPROFIT]) != instance.closedNetProfit ("        + NumberToStr(netProfit, ".2+")               +" != "+ NumberToStr(instance.closedNetProfit, ".2+")               +")", ERR_ILLEGAL_STATE));
   if (NE(netProfitP,   instance.closedNetProfitP, precision))  return(!catch("ReadStatus(10)  "+ instance.name +" sum(history[H_NETPROFIT_P]) != instance.closedNetProfitP ("     + NumberToStr(netProfitP, "."+ Digits +"+")   +" != "+ NumberToStr(instance.closedNetProfitP, "."+ Digits +"+")   +")", ERR_ILLEGAL_STATE));
   if (NE(synthProfitP, instance.closedSynthProfitP, Digits))   return(!catch("ReadStatus(11)  "+ instance.name +" sum(history[H_SYNTH_PROFIT_P]) != instance.closedSynthProfitP ("+ NumberToStr(synthProfitP, "."+ Digits +"+") +" != "+ NumberToStr(instance.closedSynthProfitP, "."+ Digits +"+") +")", ERR_ILLEGAL_STATE));

   return(!catch("ReadStatus(12)"));
}


/**
 * Read and return the keys of all trade history records found in the status file (sorting order doesn't matter).
 *
 * @param  _In_  string file    - status filename
 * @param  _In_  string section - status section
 * @param  _Out_ string &keys[] - array receiving the found keys
 *
 * @return int - number of found keys or EMPTY (-1) in case of errors
 */
int ReadStatus.HistoryKeys(string file, string section, string &keys[]) {
   int size = GetIniKeys(file, section, keys);
   if (size < 0) return(EMPTY);

   for (int i=size-1; i >= 0; i--) {
      if (StrStartsWithI(keys[i], "history."))
         continue;
      ArraySpliceStrings(keys, i, 1);     // drop all non-order keys
      size--;
   }
   return(size);                          // no need to sort as records are inserted at the correct position
}


/**
 * Parse the string representation of a closed order record and store the parsed data.
 *
 * @param  string key   - order key
 * @param  string value - order string to parse
 *
 * @return int - index the data record was inserted at or EMPTY (-1) in case of errors
 */
bool ReadStatus.RestoreHistory(string key, string value) {
   if (IsLastError())                    return(EMPTY);
   if (!StrStartsWithI(key, "history.")) return(_EMPTY(catch("ReadStatus.RestoreHistory(1)  "+ instance.name +" illegal history record key "+ DoubleQuoteStr(key), ERR_INVALID_FILE_FORMAT)));

   // history.i=ticket,type,lots,openTime,openPrice,openPriceSynth,closeTime,closePrice,closePriceSynth,slippage,swap,commission,grossProfit,netProfit,netProfitP,runupP,drawdownP,synthProfitP,synthRunupP,synthDrawdownP
   string values[];
   string sId = StrRightFrom(key, ".", -1); if (!StrIsDigits(sId))  return(_EMPTY(catch("ReadStatus.RestoreHistory(2)  "+ instance.name +" illegal history record key "+ DoubleQuoteStr(key), ERR_INVALID_FILE_FORMAT)));
   if (Explode(value, ",", values, NULL) != ArrayRange(history, 1)) return(_EMPTY(catch("ReadStatus.RestoreHistory(3)  "+ instance.name +" illegal number of details ("+ ArraySize(values) +") in history record", ERR_INVALID_FILE_FORMAT)));

   int      ticket          = StrToInteger(values[H_TICKET          ]);
   int      type            = StrToInteger(values[H_TYPE            ]);
   double   lots            =  StrToDouble(values[H_LOTS            ]);
   datetime openTime        = StrToInteger(values[H_OPENTIME        ]);
   double   openPrice       =  StrToDouble(values[H_OPENPRICE       ]);
   double   openPriceSynth  =  StrToDouble(values[H_OPENPRICE_SYNTH ]);
   datetime closeTime       = StrToInteger(values[H_CLOSETIME       ]);
   double   closePrice      =  StrToDouble(values[H_CLOSEPRICE      ]);
   double   closePriceSynth =  StrToDouble(values[H_CLOSEPRICE_SYNTH]);
   double   slippage        =  StrToDouble(values[H_SLIPPAGE        ]);
   double   swap            =  StrToDouble(values[H_SWAP            ]);
   double   commission      =  StrToDouble(values[H_COMMISSION      ]);
   double   grossProfit     =  StrToDouble(values[H_GROSSPROFIT     ]);
   double   netProfit       =  StrToDouble(values[H_NETPROFIT       ]);
   double   netProfitP      =  StrToDouble(values[H_NETPROFIT_P     ]);
   double   runupP          =  StrToDouble(values[H_RUNUP_P         ]);
   double   drawdownP       =  StrToDouble(values[H_DRAWDOWN_P      ]);
   double   synthProfitP    =  StrToDouble(values[H_SYNTH_PROFIT_P  ]);
   double   synthRunupP     =  StrToDouble(values[H_SYNTH_RUNUP_P   ]);
   double   synthDrawdownP  =  StrToDouble(values[H_SYNTH_DRAWDOWN_P]);

   return(History.AddRecord(ticket, type, lots, openTime, openPrice, openPriceSynth, closeTime, closePrice, closePriceSynth, slippage, swap, commission, grossProfit, netProfit, netProfitP, runupP, drawdownP, synthProfitP, synthRunupP, synthDrawdownP));
}


/**
 * Add an order record to the history array. Records are ordered ascending by {OpenTime;Ticket} and the new record is inserted
 * at the correct position. No data is overwritten.
 *
 * @param  int ticket - order record details
 * @param  ...
 *
 * @return int - index the record was inserted at or EMPTY (-1) in case of errors
 */
int History.AddRecord(int ticket, int type, double lots, datetime openTime, double openPrice, double openPriceSynth, datetime closeTime, double closePrice, double closePriceSynth, double slippage, double swap, double commission, double grossProfit, double netProfit, double netProfitP, double runupP, double drawdownP, double synthProfitP, double synthRunupP, double synthDrawdownP) {
   int size = ArrayRange(history, 0);

   for (int i=0; i < size; i++) {
      if (EQ(ticket,   history[i][H_TICKET  ])) return(_EMPTY(catch("History.AddRecord(1)  "+ instance.name +" cannot add record, ticket #"+ ticket +" already exists (offset: "+ i +")", ERR_INVALID_PARAMETER)));
      if (GT(openTime, history[i][H_OPENTIME])) continue;
      if (LT(openTime, history[i][H_OPENTIME])) break;
      if (LT(ticket,   history[i][H_TICKET  ])) break;
   }

   // 'i' now holds the array index to insert at
   if (i == size) {
      ArrayResize(history, size+1);                                  // add a new empty slot or...
   }
   else {
      int dim2=ArrayRange(history, 1), from=i*dim2, to=from+dim2;    // ...free an existing slot by shifting existing data
      ArrayCopy(history, history, to, from);
   }

   // insert the new data
   history[i][H_TICKET          ] = ticket;
   history[i][H_TYPE            ] = type;
   history[i][H_LOTS            ] = lots;
   history[i][H_OPENTIME        ] = openTime;
   history[i][H_OPENPRICE       ] = openPrice;
   history[i][H_OPENPRICE_SYNTH ] = openPriceSynth;
   history[i][H_CLOSETIME       ] = closeTime;
   history[i][H_CLOSEPRICE      ] = closePrice;
   history[i][H_CLOSEPRICE_SYNTH] = closePriceSynth;
   history[i][H_SLIPPAGE        ] = slippage;
   history[i][H_SWAP            ] = swap;
   history[i][H_COMMISSION      ] = commission;
   history[i][H_GROSSPROFIT     ] = grossProfit;
   history[i][H_NETPROFIT       ] = netProfit;
   history[i][H_NETPROFIT_P     ] = netProfitP;
   history[i][H_RUNUP_P         ] = runupP;
   history[i][H_DRAWDOWN_P      ] = drawdownP;
   history[i][H_SYNTH_PROFIT_P  ] = synthProfitP;
   history[i][H_SYNTH_RUNUP_P   ] = synthRunupP;
   history[i][H_SYNTH_DRAWDOWN_P] = synthDrawdownP;

   if (!catch("History.AddRecord(2)"))
      return(i);
   return(EMPTY);
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
   WriteIniString(file, section, "Tunnel.Definition",        /*string  */ Tunnel.Definition);
   WriteIniString(file, section, "Donchian.Periods",         /*int     */ Donchian.Periods);
   WriteIniString(file, section, "Lots",                     /*double  */ NumberToStr(Lots, ".+"));
   WriteIniString(file, section, "EA.Recorder",              /*string  */ EA.Recorder + separator);

   // [Stats: net in money]
   section = "Stats: net in money";
   WriteIniString(file, section, "openProfit",               /*double  */ StrPadRight(DoubleToStr(instance.openNetProfit, 2), 21)                        +"; after all costs in "+ AccountCurrency());
   WriteIniString(file, section, "closedProfit",             /*double  */ DoubleToStr(instance.closedNetProfit, 2));
   WriteIniString(file, section, "totalProfit",              /*double  */ DoubleToStr(instance.totalNetProfit, 2));
   WriteIniString(file, section, "minProfit",                /*double  */ DoubleToStr(instance.maxNetDrawdown, 2));
   WriteIniString(file, section, "maxProfit",                /*double  */ DoubleToStr(instance.maxNetProfit, 2) + separator);

   // [Stats: net in punits]
   section = "Stats: net in "+ pUnit;
   WriteIniString(file, section, "openProfit",               /*double  */ StrPadRight(NumberToStr(instance.openNetProfitP * pMultiplier, ".1+"), 21)     +"; after all costs");
   WriteIniString(file, section, "closedProfit",             /*double  */ NumberToStr(instance.closedNetProfitP * pMultiplier, ".1+"));
   WriteIniString(file, section, "totalProfit",              /*double  */ NumberToStr(instance.totalNetProfitP * pMultiplier, ".1+"));
   WriteIniString(file, section, "minProfit",                /*double  */ NumberToStr(instance.maxNetDrawdownP * pMultiplier, ".1+"));
   WriteIniString(file, section, "maxProfit",                /*double  */ NumberToStr(instance.maxNetProfitP * pMultiplier, ".1+") + separator);

   WriteIniString(file, section, "trades",                   /*double  */ Round(stats[METRIC_TOTAL_NET_UNITS][S_TRADES]));
   WriteIniString(file, section, "trades.long",              /*double  */ StrPadRight(Round(stats[METRIC_TOTAL_NET_UNITS][S_TRADES_LONG ]), 19) + StrPadLeft("("+ DoubleToStr(100 * stats[METRIC_TOTAL_NET_UNITS][S_TRADES_LONG_PCT  ], 1) +"%)", 8));
   WriteIniString(file, section, "trades.short",             /*double  */ StrPadRight(Round(stats[METRIC_TOTAL_NET_UNITS][S_TRADES_SHORT]), 18) + StrPadLeft("("+ DoubleToStr(100 * stats[METRIC_TOTAL_NET_UNITS][S_TRADES_SHORT_PCT ], 1) +"%)", 8));
   WriteIniString(file, section, "trades.avgRunup",          /*double  */ DoubleToStr(stats[METRIC_TOTAL_NET_UNITS][S_TRADES_AVG_RUNUP   ] * pMultiplier, pDigits));
   WriteIniString(file, section, "trades.avgDrawdown",       /*double  */ DoubleToStr(stats[METRIC_TOTAL_NET_UNITS][S_TRADES_AVG_DRAWDOWN] * pMultiplier, pDigits));
   WriteIniString(file, section, "trades.avgProfit",         /*double  */ DoubleToStr(stats[METRIC_TOTAL_NET_UNITS][S_TRADES_AVG_PROFIT  ] * pMultiplier, pDigits) + separator);

   WriteIniString(file, section, "winners",                  /*double  */ StrPadRight(Round(stats[METRIC_TOTAL_NET_UNITS][S_WINNERS]),       23) + StrPadLeft("("+ DoubleToStr(100 * stats[METRIC_TOTAL_NET_UNITS][S_WINNERS_PCT      ], 1) +"%)", 8));
   WriteIniString(file, section, "winners.long",             /*double  */ StrPadRight(Round(stats[METRIC_TOTAL_NET_UNITS][S_WINNERS_LONG ]), 18) + StrPadLeft("("+ DoubleToStr(100 * stats[METRIC_TOTAL_NET_UNITS][S_WINNERS_LONG_PCT ], 1) +"%)", 8));
   WriteIniString(file, section, "winners.short",            /*double  */ StrPadRight(Round(stats[METRIC_TOTAL_NET_UNITS][S_WINNERS_SHORT]), 17) + StrPadLeft("("+ DoubleToStr(100 * stats[METRIC_TOTAL_NET_UNITS][S_WINNERS_SHORT_PCT], 1) +"%)", 8));
   WriteIniString(file, section, "winners.avgRunup",         /*double  */ DoubleToStr(stats[METRIC_TOTAL_NET_UNITS][S_WINNERS_AVG_RUNUP   ] * pMultiplier, pDigits));
   WriteIniString(file, section, "winners.avgDrawdown",      /*double  */ DoubleToStr(stats[METRIC_TOTAL_NET_UNITS][S_WINNERS_AVG_DRAWDOWN] * pMultiplier, pDigits));
   WriteIniString(file, section, "winners.avgProfit",        /*double  */ DoubleToStr(stats[METRIC_TOTAL_NET_UNITS][S_WINNERS_AVG_PROFIT  ] * pMultiplier, pDigits) + separator);

   WriteIniString(file, section, "losers",                   /*double  */ StrPadRight(Round(stats[METRIC_TOTAL_NET_UNITS][S_LOSERS]),       24) + StrPadLeft("("+ DoubleToStr(100 * stats[METRIC_TOTAL_NET_UNITS][S_LOSERS_PCT       ], 1) +"%)", 8));
   WriteIniString(file, section, "losers.long",              /*double  */ StrPadRight(Round(stats[METRIC_TOTAL_NET_UNITS][S_LOSERS_LONG ]), 19) + StrPadLeft("("+ DoubleToStr(100 * stats[METRIC_TOTAL_NET_UNITS][S_LOSERS_LONG_PCT  ], 1) +"%)", 8));
   WriteIniString(file, section, "losers.short",             /*double  */ StrPadRight(Round(stats[METRIC_TOTAL_NET_UNITS][S_LOSERS_SHORT]), 18) + StrPadLeft("("+ DoubleToStr(100 * stats[METRIC_TOTAL_NET_UNITS][S_LOSERS_SHORT_PCT ], 1) +"%)", 8));
   WriteIniString(file, section, "losers.avgRunup",          /*double  */ DoubleToStr(stats[METRIC_TOTAL_NET_UNITS][S_LOSERS_AVG_RUNUP   ] * pMultiplier, pDigits));
   WriteIniString(file, section, "losers.avgDrawdown",       /*double  */ DoubleToStr(stats[METRIC_TOTAL_NET_UNITS][S_LOSERS_AVG_DRAWDOWN] * pMultiplier, pDigits));
   WriteIniString(file, section, "losers.avgProfit",         /*double  */ DoubleToStr(stats[METRIC_TOTAL_NET_UNITS][S_LOSERS_AVG_PROFIT  ] * pMultiplier, pDigits) + separator);

   WriteIniString(file, section, "scratch",                  /*double  */ StrPadRight(Round(stats[METRIC_TOTAL_NET_UNITS][S_SCRATCH]),       23) + StrPadLeft("("+ DoubleToStr(100 * stats[METRIC_TOTAL_NET_UNITS][S_SCRATCH_PCT      ], 1) +"%)", 8));
   WriteIniString(file, section, "scratch.long",             /*double  */ StrPadRight(Round(stats[METRIC_TOTAL_NET_UNITS][S_SCRATCH_LONG ]), 18) + StrPadLeft("("+ DoubleToStr(100 * stats[METRIC_TOTAL_NET_UNITS][S_SCRATCH_LONG_PCT ], 1) +"%)", 8));
   WriteIniString(file, section, "scratch.short",            /*double  */ StrPadRight(Round(stats[METRIC_TOTAL_NET_UNITS][S_SCRATCH_SHORT]), 17) + StrPadLeft("("+ DoubleToStr(100 * stats[METRIC_TOTAL_NET_UNITS][S_SCRATCH_SHORT_PCT], 1) +"%)", 8));
   WriteIniString(file, section, "scratch.avgRunup",         /*double  */ DoubleToStr(stats[METRIC_TOTAL_NET_UNITS][S_SCRATCH_AVG_RUNUP   ] * pMultiplier, pDigits));
   WriteIniString(file, section, "scratch.avgDrawdown",      /*double  */ DoubleToStr(stats[METRIC_TOTAL_NET_UNITS][S_SCRATCH_AVG_DRAWDOWN] * pMultiplier, pDigits) + separator);

   // [Stats: synthetic in punits]
   section = "Stats: synthetic in "+ pUnit;
   WriteIniString(file, section, "openProfit",               /*double  */ StrPadRight(DoubleToStr(instance.openSynthProfitP * pMultiplier, pDigits), 21) +"; before spread/any costs (signal levels)");
   WriteIniString(file, section, "closedProfit",             /*double  */ DoubleToStr(instance.closedSynthProfitP * pMultiplier, pDigits));
   WriteIniString(file, section, "totalProfit",              /*double  */ DoubleToStr(instance.totalSynthProfitP * pMultiplier, pDigits));
   WriteIniString(file, section, "minProfit",                /*double  */ DoubleToStr(instance.maxSynthDrawdownP * pMultiplier, pDigits));
   WriteIniString(file, section, "maxProfit",                /*double  */ DoubleToStr(instance.maxSynthProfitP * pMultiplier, pDigits) + separator);

   WriteIniString(file, section, "trades",                   /*double  */ Round(stats[METRIC_TOTAL_SYNTH_UNITS][S_TRADES]));
   WriteIniString(file, section, "trades.long",              /*double  */ StrPadRight(Round(stats[METRIC_TOTAL_SYNTH_UNITS][S_TRADES_LONG ]), 19) + StrPadLeft("("+ DoubleToStr(100 * stats[METRIC_TOTAL_SYNTH_UNITS][S_TRADES_LONG_PCT  ], 1) +"%)", 8));
   WriteIniString(file, section, "trades.short",             /*double  */ StrPadRight(Round(stats[METRIC_TOTAL_SYNTH_UNITS][S_TRADES_SHORT]), 18) + StrPadLeft("("+ DoubleToStr(100 * stats[METRIC_TOTAL_SYNTH_UNITS][S_TRADES_SHORT_PCT ], 1) +"%)", 8));
   WriteIniString(file, section, "trades.avgRunup",          /*double  */ DoubleToStr(stats[METRIC_TOTAL_SYNTH_UNITS][S_TRADES_AVG_RUNUP   ] * pMultiplier, pDigits));
   WriteIniString(file, section, "trades.avgDrawdown",       /*double  */ DoubleToStr(stats[METRIC_TOTAL_SYNTH_UNITS][S_TRADES_AVG_DRAWDOWN] * pMultiplier, pDigits));
   WriteIniString(file, section, "trades.avgProfit",         /*double  */ DoubleToStr(stats[METRIC_TOTAL_SYNTH_UNITS][S_TRADES_AVG_PROFIT  ] * pMultiplier, pDigits) + separator);

   WriteIniString(file, section, "winners",                  /*double  */ StrPadRight(Round(stats[METRIC_TOTAL_SYNTH_UNITS][S_WINNERS]),       23) + StrPadLeft("("+ DoubleToStr(100 * stats[METRIC_TOTAL_SYNTH_UNITS][S_WINNERS_PCT      ], 1) +"%)", 8));
   WriteIniString(file, section, "winners.long",             /*double  */ StrPadRight(Round(stats[METRIC_TOTAL_SYNTH_UNITS][S_WINNERS_LONG ]), 18) + StrPadLeft("("+ DoubleToStr(100 * stats[METRIC_TOTAL_SYNTH_UNITS][S_WINNERS_LONG_PCT ], 1) +"%)", 8));
   WriteIniString(file, section, "winners.short",            /*double  */ StrPadRight(Round(stats[METRIC_TOTAL_SYNTH_UNITS][S_WINNERS_SHORT]), 17) + StrPadLeft("("+ DoubleToStr(100 * stats[METRIC_TOTAL_SYNTH_UNITS][S_WINNERS_SHORT_PCT], 1) +"%)", 8));
   WriteIniString(file, section, "winners.avgRunup",         /*double  */ DoubleToStr(stats[METRIC_TOTAL_SYNTH_UNITS][S_WINNERS_AVG_RUNUP   ] * pMultiplier, pDigits));
   WriteIniString(file, section, "winners.avgDrawdown",      /*double  */ DoubleToStr(stats[METRIC_TOTAL_SYNTH_UNITS][S_WINNERS_AVG_DRAWDOWN] * pMultiplier, pDigits));
   WriteIniString(file, section, "winners.avgProfit",        /*double  */ DoubleToStr(stats[METRIC_TOTAL_SYNTH_UNITS][S_WINNERS_AVG_PROFIT  ] * pMultiplier, pDigits) + separator);

   WriteIniString(file, section, "losers",                   /*double  */ StrPadRight(Round(stats[METRIC_TOTAL_SYNTH_UNITS][S_LOSERS]),       24) + StrPadLeft("("+ DoubleToStr(100 * stats[METRIC_TOTAL_SYNTH_UNITS][S_LOSERS_PCT       ], 1) +"%)", 8));
   WriteIniString(file, section, "losers.long",              /*double  */ StrPadRight(Round(stats[METRIC_TOTAL_SYNTH_UNITS][S_LOSERS_LONG ]), 19) + StrPadLeft("("+ DoubleToStr(100 * stats[METRIC_TOTAL_SYNTH_UNITS][S_LOSERS_LONG_PCT  ], 1) +"%)", 8));
   WriteIniString(file, section, "losers.short",             /*double  */ StrPadRight(Round(stats[METRIC_TOTAL_SYNTH_UNITS][S_LOSERS_SHORT]), 18) + StrPadLeft("("+ DoubleToStr(100 * stats[METRIC_TOTAL_SYNTH_UNITS][S_LOSERS_SHORT_PCT ], 1) +"%)", 8));
   WriteIniString(file, section, "losers.avgRunup",          /*double  */ DoubleToStr(stats[METRIC_TOTAL_SYNTH_UNITS][S_LOSERS_AVG_RUNUP   ] * pMultiplier, pDigits));
   WriteIniString(file, section, "losers.avgDrawdown",       /*double  */ DoubleToStr(stats[METRIC_TOTAL_SYNTH_UNITS][S_LOSERS_AVG_DRAWDOWN] * pMultiplier, pDigits));
   WriteIniString(file, section, "losers.avgProfit",         /*double  */ DoubleToStr(stats[METRIC_TOTAL_SYNTH_UNITS][S_LOSERS_AVG_PROFIT  ] * pMultiplier, pDigits) + separator);

   WriteIniString(file, section, "scratch",                  /*double  */ StrPadRight(Round(stats[METRIC_TOTAL_SYNTH_UNITS][S_SCRATCH]),       23) + StrPadLeft("("+ DoubleToStr(100 * stats[METRIC_TOTAL_SYNTH_UNITS][S_SCRATCH_PCT      ], 1) +"%)", 8));
   WriteIniString(file, section, "scratch.long",             /*double  */ StrPadRight(Round(stats[METRIC_TOTAL_SYNTH_UNITS][S_SCRATCH_LONG ]), 18) + StrPadLeft("("+ DoubleToStr(100 * stats[METRIC_TOTAL_SYNTH_UNITS][S_SCRATCH_LONG_PCT ], 1) +"%)", 8));
   WriteIniString(file, section, "scratch.short",            /*double  */ StrPadRight(Round(stats[METRIC_TOTAL_SYNTH_UNITS][S_SCRATCH_SHORT]), 17) + StrPadLeft("("+ DoubleToStr(100 * stats[METRIC_TOTAL_SYNTH_UNITS][S_SCRATCH_SHORT_PCT], 1) +"%)", 8));
   WriteIniString(file, section, "scratch.avgRunup",         /*double  */ DoubleToStr(stats[METRIC_TOTAL_SYNTH_UNITS][S_SCRATCH_AVG_RUNUP   ] * pMultiplier, pDigits));
   WriteIniString(file, section, "scratch.avgDrawdown",      /*double  */ DoubleToStr(stats[METRIC_TOTAL_SYNTH_UNITS][S_SCRATCH_AVG_DRAWDOWN] * pMultiplier, pDigits) + separator);

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
   WriteIniString(file, section, "open.priceSynth",          /*double  */ DoubleToStr(open.priceSynth, Digits));
   WriteIniString(file, section, "open.slippage",            /*double  */ DoubleToStr(open.slippage, Digits));
   WriteIniString(file, section, "open.swap",                /*double  */ DoubleToStr(open.swap, 2));
   WriteIniString(file, section, "open.commission",          /*double  */ DoubleToStr(open.commission, 2));
   WriteIniString(file, section, "open.grossProfit",         /*double  */ DoubleToStr(open.grossProfit, 2));
   WriteIniString(file, section, "open.netProfit",           /*double  */ DoubleToStr(open.netProfit, 2));
   WriteIniString(file, section, "open.netProfitP",          /*double  */ NumberToStr(open.netProfitP, ".1+"));
   WriteIniString(file, section, "open.synthProfitP",        /*double  */ DoubleToStr(open.synthProfitP, Digits) + separator);

   // [Trade history]
   section = "Trade history";
   double netProfit, netProfitP, synthProfitP;
   int size = ArrayRange(history, 0);

   for (int i=0; i < size; i++) {
      WriteIniString(file, section, "history."+ i, SaveStatus.HistoryToStr(i));
      netProfit    += history[i][H_NETPROFIT     ];
      netProfitP   += history[i][H_NETPROFIT_P   ];
      synthProfitP += history[i][H_SYNTH_PROFIT_P];
   }

   // cross-check stored stats
   int precision = MathMax(Digits, 2) + 1;                     // required precision for fractional point values
   if (NE(netProfit,    instance.closedNetProfit, 2))          return(!catch("SaveStatus(2)  "+ instance.name +" sum(history[H_NETPROFIT]) != instance.closedNetProfit ("        + NumberToStr(netProfit, ".2+")               +" != "+ NumberToStr(instance.closedNetProfit, ".2+")               +")", ERR_ILLEGAL_STATE));
   if (NE(netProfitP,   instance.closedNetProfitP, precision)) return(!catch("SaveStatus(3)  "+ instance.name +" sum(history[H_NETPROFIT_P]) != instance.closedNetProfitP ("     + NumberToStr(netProfitP, "."+ Digits +"+")   +" != "+ NumberToStr(instance.closedNetProfitP, "."+ Digits +"+")   +")", ERR_ILLEGAL_STATE));
   if (NE(synthProfitP, instance.closedSynthProfitP, Digits))  return(!catch("SaveStatus(4)  "+ instance.name +" sum(history[H_SYNTH_PROFIT_P]) != instance.closedSynthProfitP ("+ NumberToStr(synthProfitP, "."+ Digits +"+") +" != "+ NumberToStr(instance.closedSynthProfitP, "."+ Digits +"+") +")", ERR_ILLEGAL_STATE));

   return(!catch("SaveStatus(5)"));
}


/**
 * Return a string representation of a history record to be stored by SaveStatus().
 *
 * @param  int index - index of the history record
 *
 * @return string - string representation or an empty string in case of errors
 */
string SaveStatus.HistoryToStr(int index) {
   // result: ticket,type,lots,openTime,openPrice,openPriceSynth,closeTime,closePrice,closePriceSynth,slippage,swap,commission,grossProfit,netProfit,netProfitP,runupP,drawdownP,synthProfitP,synthRunupP,synthDrawdownP

   int      ticket          = history[index][H_TICKET          ];
   int      type            = history[index][H_TYPE            ];
   double   lots            = history[index][H_LOTS            ];
   datetime openTime        = history[index][H_OPENTIME        ];
   double   openPrice       = history[index][H_OPENPRICE       ];
   double   openPriceSynth  = history[index][H_OPENPRICE_SYNTH ];
   datetime closeTime       = history[index][H_CLOSETIME       ];
   double   closePrice      = history[index][H_CLOSEPRICE      ];
   double   closePriceSynth = history[index][H_CLOSEPRICE_SYNTH];
   double   slippage        = history[index][H_SLIPPAGE        ];
   double   swap            = history[index][H_SWAP            ];
   double   commission      = history[index][H_COMMISSION      ];
   double   grossProfit     = history[index][H_GROSSPROFIT     ];
   double   netProfit       = history[index][H_NETPROFIT       ];
   double   netProfitP      = history[index][H_NETPROFIT_P     ];
   double   runupP          = history[index][H_RUNUP_P         ];
   double   drawdownP       = history[index][H_DRAWDOWN_P      ];
   double   synthProfitP    = history[index][H_SYNTH_PROFIT_P  ];
   double   synthRunupP     = history[index][H_SYNTH_RUNUP_P   ];
   double   synthDrawdownP  = history[index][H_SYNTH_DRAWDOWN_P];

   return(StringConcatenate(ticket, ",", type, ",", DoubleToStr(lots, 2), ",", openTime, ",", DoubleToStr(openPrice, Digits), ",", DoubleToStr(openPriceSynth, Digits), ",", closeTime, ",", DoubleToStr(closePrice, Digits), ",", DoubleToStr(closePriceSynth, Digits), ",", DoubleToStr(slippage, Digits), ",", DoubleToStr(swap, 2), ",", DoubleToStr(commission, 2), ",", DoubleToStr(grossProfit, 2), ",", DoubleToStr(netProfit, 2), ",", NumberToStr(netProfitP, ".1+"), ",", DoubleToStr(runupP, Digits), ",", DoubleToStr(drawdownP, Digits), ",", DoubleToStr(synthProfitP, Digits), ",", DoubleToStr(synthRunupP, Digits), ",", DoubleToStr(synthDrawdownP, Digits)));
}


// backed-up input parameters
string   prev.Instance.ID = "";
string   prev.Tunnel.Definition = "";
int      prev.Donchian.Periods;
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
   prev.Instance.ID       = StringConcatenate(Instance.ID, "");         // string inputs are references to internal C literals
   prev.Tunnel.Definition = StringConcatenate(Tunnel.Definition, "");   // and must be copied to break the reference
   prev.Donchian.Periods  = Donchian.Periods;
   prev.Lots              = Lots;

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
   Instance.ID       = prev.Instance.ID;
   Tunnel.Definition = prev.Tunnel.Definition;
   Donchian.Periods  = prev.Donchian.Periods;
   Lots              = prev.Lots;

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

   // EA.Recorder: on | off* | 1,2,3=1000,...
   if (!Recorder.ValidateInputs(IsTestInstance())) return(false);

   SS.All();
   return(!catch("ValidateInputs(14)"));
}


/**
 * Return a symbol definition for the specified metric to be recorded.
 *
 * @param  _In_  int    id           - metric id; 0 = standard AccountEquity() symbol, positive integer for custom metrics
 * @param  _Out_ bool   &ready       - whether metric details are complete and the metric is ready to be recorded
 * @param  _Out_ string &symbol      - unique MT4 timeseries symbol
 * @param  _Out_ string &description - symbol description as in the MT4 "Symbols" window (if empty a description is generated)
 * @param  _Out_ string &group       - symbol group name as in the MT4 "Symbols" window (if empty a name is generated)
 * @param  _Out_ int    &digits      - symbol digits value
 * @param  _Out_ double &baseValue   - quotes base value (if EMPTY recorder default settings are used)
 * @param  _Out_ int    &multiplier  - quotes multiplier
 *
 * @return int - error status; especially ERR_INVALID_INPUT_PARAMETER if the passed metric id is unknown or not supported
 */
int Recorder_GetSymbolDefinition(int id, bool &ready, string &symbol, string &description, string &group, int &digits, double &baseValue, int &multiplier) {
   string sId = ifString(!instance.id, "???", StrPadLeft(instance.id, 3, "0"));
   string descrSuffix="", sBarModel="";
   switch (__Test.barModel) {
      case MODE_EVERYTICK:     sBarModel = "EveryTick"; break;
      case MODE_CONTROLPOINTS: sBarModel = "ControlP";  break;
      case MODE_BAROPEN:       sBarModel = "BarOpen";   break;
      default:                 sBarModel = "Live";      break;
   }

   ready     = false;
   group     = "";
   baseValue = EMPTY;

   switch (id) {
      // --- standard AccountEquity() symbol for recorder.mode = RECORDER_ON ------------------------------------------------
      case NULL:
         symbol      = recorder.stdEquitySymbol;
         description = "";
         digits      = 2;
         multiplier  = 1;
         ready       = true;
         return(NO_ERROR);

      // --- custom cumulated metrcis ---------------------------------------------------------------------------------------
      case METRIC_TOTAL_NET_MONEY:
         symbol      = StrLeft(Symbol(), 6) +"."+ sId +"A";       // "US500.123A"
         descrSuffix = ", "+ PeriodDescription() +", "+ sBarModel +", net PnL, "+ AccountCurrency() + LocalTimeFormat(GetGmtTime(), ", %d.%m.%Y %H:%M");
         digits      = 2;
         multiplier  = 1;
         break;

      case METRIC_TOTAL_NET_UNITS:
         symbol      = StrLeft(Symbol(), 6) +"."+ sId +"B";
         descrSuffix = ", "+ PeriodDescription() +", "+ sBarModel +", net PnL, "+ pUnit + LocalTimeFormat(GetGmtTime(), ", %d.%m.%Y %H:%M");
         digits      = pDigits;
         multiplier  = pMultiplier;
         break;

      case METRIC_TOTAL_SYNTH_UNITS:
         symbol      = StrLeft(Symbol(), 6) +"."+ sId +"C";
         descrSuffix = ", "+ PeriodDescription() +", "+ sBarModel +", synth PnL, "+ pUnit + LocalTimeFormat(GetGmtTime(), ", %d.%m.%Y %H:%M");
         digits      = pDigits;
         multiplier  = pMultiplier;
         break;

      default:
         return(ERR_INVALID_INPUT_PARAMETER);
   }

   description = StrLeft(ProgramName(), 63-StringLen(descrSuffix )) + descrSuffix;
   ready = (instance.id > 0);

   return(NO_ERROR);
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
 * ShowStatus: Update the string representation of the open position size.
 */
void SS.OpenLots() {
   if      (!open.lots)           sOpenLots = "-";
   else if (open.type == OP_LONG) sOpenLots = "+"+ NumberToStr(open.lots, ".+") +" lot";
   else                           sOpenLots = "-"+ NumberToStr(open.lots, ".+") +" lot";
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
      string sMaxProfit="", sMaxDrawdown="";

      switch (status.activeMetric) {
         case METRIC_TOTAL_NET_MONEY:
            sMaxProfit   = NumberToStr(instance.maxNetProfit,   "R+.2");
            sMaxDrawdown = NumberToStr(instance.maxNetDrawdown, "R+.2");
            break;
         case METRIC_TOTAL_NET_UNITS:
            sMaxProfit   = NumberToStr(instance.maxNetProfitP   * pMultiplier, "R+."+ pDigits);
            sMaxDrawdown = NumberToStr(instance.maxNetDrawdownP * pMultiplier, "R+."+ pDigits);
            break;
         case METRIC_TOTAL_SYNTH_UNITS:
            sMaxProfit   = NumberToStr(instance.maxSynthProfitP   * pMultiplier, "R+."+ pDigits);
            sMaxDrawdown = NumberToStr(instance.maxSynthDrawdownP * pMultiplier, "R+."+ pDigits);
            break;

         default: return(!catch("SS.ProfitStats(1)  "+ instance.name +" illegal value of status.activeMetric: "+ status.activeMetric, ERR_ILLEGAL_STATE));
      }
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
                                   sMetricDescription,                              NL,
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
   return(StringConcatenate("Instance.ID=",       DoubleQuoteStr(Instance.ID),       ";", NL,
                            "Tunnel.Definition=", DoubleQuoteStr(Tunnel.Definition), ";", NL,
                            "Donchian.Periods=",  Donchian.Periods,                  ";", NL,
                            "Lots=",              NumberToStr(Lots, ".1+"),          ";")
   );
}
