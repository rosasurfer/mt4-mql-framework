/**
 * ZigZag EA
 *
 * A strategy inspired by the "Turtle Trading" system of Richard Dennis.
 *
 *
 * Requirements
 * ------------
 * - ZigZag indicator: @see  https://github.com/rosasurfer/mt4-mql/blob/master/mql4/indicators/ZigZag.mq4
 *
 *
 * Input parameters
 * ----------------
 * • EA.Recorder: Metrics to record, for syntax @see https://github.com/rosasurfer/mt4-mql/blob/master/mql4/include/core/expert.recorder.mqh
 *
 *    1:  Records PnL in account currency after all costs (net, same as EA.Recorder="on" but custom symbol).
 *    2:  Records PnL in price units without spread and any costs (virtual, assumes exact execution).
 *    3:  Records PnL in price units after spread but without any other costs (gross).
 *    4:  Records PnL in price units after all costs (net).
 *
 *    5:  Records daily PnL in account currency after all costs (net).                                                  TODO
 *    6:  Records daily PnL in price units without spread and any costs (virtual, assumes exact execution).             TODO
 *    7:  Records daily PnL in price units after spread but without any other costs (gross).                            TODO
 *    8:  Records daily PnL in price units after all costs (net).                                                       TODO
 *
 *    Metrics in price units are recorded in the best matching unit. That's pip for Forex and full points otherwise.
 *
 *
 * External control
 * ----------------
 * The EA status can be controlled via execution of the following scripts (online and in tester):
 *
 *  • EA.Start: When a "start" command is received the EA opens a position in direction of the current ZigZag leg. There are
 *              two sub-commands "start:long" and "start:short" to start the EA in a predefined direction. The command has
 *              no effect if the EA already manages an open position.
 *  • EA.Stop:  When a "stop" command is received the EA closes all open positions and stops waiting for trade signals.
 *              The command has no effect if the EA is already in status "stopped".
 *  • EA.Wait:  When a "wait" command is received a stopped EA will wait for a new trade signals and start trading.
 *              The command has no effect if the EA is already in status "waiting".
 *
 *
 *  @see  [Turtle Trading] https://analyzingalpha.com/turtle-trading
 *  @see  [Turtle Trading] http://web.archive.org/web/20220417032905/https://vantagepointtrading.com/top-trader-richard-dennis-turtle-trading-strategy/
 *
 *
 * TODO:
 *  - status: option to toggle between metrics
 *  - open/closed trades: option to toggle between variants
 *  - add var recorder.internalSymbol and store/restore value
 *  - tester: ZigZag EA cannot yet run with bar model MODE_BAROPEN
 *
 *  - time functions
 *     TimeCurrentEx()     check scripts/standalone-indicators in tester/offline charts in old/current terminals
 *     TimeLocalEx()       check scripts/standalone-indicators in tester/offline charts in old/current terminals
 *     TimeFXT()
 *     TimeGMT()           check scripts/standalone-indicators in tester/offline charts in old/current terminals
 *     TimeServer()        check scripts/standalone-indicators in tester/offline charts in old/current terminals
 *
 *     FxtToGmtTime
 *     FxtToLocalTime
 *     FxtToServerTime
 *
 *     GmtToFxtTime
 *     GmtToLocalTime      OK    finish unit tests
 *     GmtToServerTime
 *
 *     LocalToFxtTime
 *     LocalToGmtTime      OK    finish unit tests
 *     LocalToServerTime
 *
 *     ServerToFxtTime
 *     ServerToGmtTime
 *     ServerToLocalTime
 *
 *  - merge Get(Prev|Next)?SessionStartTime()
 *  - merge Get(Prev|Next)?SessionEndTime()
 *
 *  - implement Get(Prev|Next)?Session(Start|End)Time(..., TZ_LOCAL)
 *  - implement (Fxt|Gmt|Server)ToLocalTime() and LocalTo(Fxt|Gmt|Server)Time()
 *
 *  - AverageRange
 *     fix EMPTY_VALUE
 *     integrate required bars in startbar calculation
 *     MTF option for lower TF data on higher TFs (to display more data than a single screen)
 *     one more buffer for current range
 *
 *  - SuperBars
 *     fix gap between days/weeks if market is not open 24h
 *     implement more timeframes
 *
 *  - FATAL  BTCUSD,M5  ChartInfos::ParseDateTimeEx(5)  invalid history configuration in "Today 09:00"  [ERR_INVALID_CONFIG_VALUE]
 *
 *  - stop on reverse signal
 *  - signals MANUAL_LONG|MANUAL_SHORT
 *  - widen SL on manual positions in opposite direction
 *  - manage an existing manual order
 *  - track and display total slippage
 *  - reduce slippage on reversal: Close+Open => Hedge+CloseBy
 *  - reduce slippage on short reversal: enter market via StopSell
 *
 *  - virtual trading
 *     adjust virtual commissions
 *
 *  - trading functionality
 *     support command "wait" in status "progressing"
 *     rewrite and test all @profit() conditions
 *     breakeven stop
 *     trailing stop
 *     reverse trading and command EA.Reverse
 *     input parameter ZigZag.Timeframe
 *     support multiple units and targets (add new metrics)
 *
 *  - visualization
 *     rename groups/instruments/history descriptions
 *     ChartInfos: read/display symbol description as long name
 *
 *  - performance tracking
 *     realtime equity charts
 *     notifications for price feed outages
 *     daily metrics
 *
 *  - status display
 *     parameter: ZigZag.Periods
 *     current position
 *     current spread
 *     number of trades
 *     total commission
 *     recorded symbols with descriptions
 *
 *  - trade breaks
 *    - full session (24h) with trade breaks
 *    - partial session (e.g. 09:00-16:00) with trade breaks
 *    - trading is disabled but the price feed is active
 *    - configuration:
 *       default: auto-config using the SYMBOL configuration
 *       manual override of times and behaviors (per instance => via input parameters)
 *    - default behaviour:
 *       no trade commands
 *       synchronize-after if an opposite signal occurred
 *    - manual behaviour configuration:
 *       close-before      (default: no)
 *       synchronize-after (default: yes; if no: wait for the next signal)
 *    - better parsing of struct SYMBOL
 *    - config support for session and trade breaks at specific day times
 *
 *  - on exceeding the max. open file limit of the terminal (512)
 *     FATAL  GBPJPY,M5  ZigZag EA::rsfHistory1::HistoryFile1.Open(12)->FileOpen("history/XTrade-Live/zGBPJP_581C30.hst", FILE_READ|FILE_WRITE) => -1 (zGBPJP_581C,M30)  [ERR_CANNOT_OPEN_FILE]
 *     ERROR  GBPJPY,M5  ZigZag EA::rsfHistory1::catch(1)  recursion: SendEmail(8)->FileOpen()  [ERR_CANNOT_OPEN_FILE]
 *            GBPJPY,M5  ZigZag EA::rsfHistory1::SendSMS(8)  SMS sent to +************: "FATAL:  GBPJPY,M5  ZigZag::rsfHistory1::HistoryFile1.Open(12)->FileOpen("history/XTrade-Live/zGBPJP_581C30.hst", FILE_READ|FILE_WRITE) => -1 (zGBPJP_581C,M30)  [ERR_CANNOT_OPEN_FILE] (12:59:52, ICM-DM-EUR)"
 *  - add cache parameter to HistorySet.AddTick(), e.g. 30 sec.
 *  - move all history functionality to the Expander (fixes MQL max. open file limit of program=64/terminal=512)
 *
 *  - improve handling of network outages (price and/or trade connection)
 *  - "no connection" event, no price feed for 5 minutes, signals during this time are not detected => EA out of sync
 *
 *  - handle orders.acceptableSlippage dynamically (via framework config)
 *     https://www.mql5.com/en/forum/120795
 *     https://www.mql5.com/en/forum/289014#comment_9296322
 *     https://www.mql5.com/en/forum/146808#comment_3701979#  [ECN restriction removed since build 500]
 *     https://www.mql5.com/en/forum/146808#comment_3701981#  [Query execution mode in MQL]
 *
 *  - merge inputs TakeProfit and StopConditions
 *  - rewrite parameter stepping: remove commands from channel after processing
 *  - rewrite range bar generator
 *  - VPS: monitor and notify of incoming emails
 *  - CLI tools to rename/update/delete symbols
 *  - fix log messages in ValidateInputs (conditionally display the instance name)
 *  - pass input "EA.Recorder" to the Expander as a string
 *  - ChartInfos::CustomPosition() weekend configuration/timespans don't work
 *  - ChartInfos::CustomPosition() including/excluding a specific strategy is not supported
 *  - ChartInfos: don't recalculate unitsize on every tick (every few seconds is sufficient)
 *  - Superbars: ETH/RTH separation for Frankfurt session
 */
#include <stddefines.mqh>
int   __InitFlags[] = {INIT_PIPVALUE, INIT_BUFFERED_LOG};
int __DeinitFlags[];
int __virtualTicks = 10000;                                 // every 10 seconds to continue operation on a stalled data feed

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern string Instance.ID          = "";                    // instance to load from a status file, format "[T]123"
extern string TradingMode          = "regular* | virtual";  // may be shortened

extern int    ZigZag.Periods       = 30;
extern double Lots                 = 1.0;
extern string StartConditions      = "";                    // @time(datetime|time)
extern string StopConditions       = "";                    // @time(datetime|time)          // TODO: @signal([long|short]), @breakeven(on-profit), @trail([on-profit:]stepsize)
extern double TakeProfit           = 0;                     // TP value
extern string TakeProfit.Type      = "off* | money | percent | pip | quote-unit";            // can be shortened if distinct        // TODO: redefine point as index point

extern bool   ShowProfitInPercent  = true;                  // whether PL is displayed in money or percentage terms

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/expert.mqh>
#include <stdfunctions.mqh>
#include <rsfLib.mqh>
#include <functions/HandleCommands.mqh>
#include <functions/ParseDateTime.mqh>
#include <functions/iCustom/ZigZag.mqh>
#include <structs/rsf/OrderExecution.mqh>

#define STRATEGY_ID               107           // unique strategy id between 101-1023 (10 bit)

#define INSTANCE_ID_MIN           100           // range of valid instance ids
#define INSTANCE_ID_MAX           999           // ...

#define STATUS_WAITING              1           // instance status values
#define STATUS_PROGRESSING          2
#define STATUS_STOPPED              3

#define TRADINGMODE_REGULAR         1           // trading modes
#define TRADINGMODE_VIRTUAL         2

#define SIGNAL_LONG  TRADE_DIRECTION_LONG       // 1 start/stop/resume signal types
#define SIGNAL_SHORT TRADE_DIRECTION_SHORT      // 2
#define SIGNAL_TIME                 3
#define SIGNAL_TAKEPROFIT           4

#define TP_TYPE_MONEY               1           // TakeProfit types
#define TP_TYPE_PERCENT             2
#define TP_TYPE_PIP                 3
#define TP_TYPE_PRICEUNIT           4

#define H_TICKET                    0           // trade history indexes
#define H_OPENTYPE                  1
#define H_LOTS                      2
#define H_OPENTIME                  3
#define H_OPENPRICE                 4
#define H_OPENPRICE_VIRT            5
#define H_CLOSETIME                 6
#define H_CLOSEPRICE                7
#define H_CLOSEPRICE_VIRT           8
#define H_SLIPPAGE                  9
#define H_SWAP                     10
#define H_COMMISSION               11
#define H_GROSSPROFIT              12
#define H_GROSSPROFIT_P            13
#define H_NETPROFIT                14
#define H_NETPROFIT_P              15
#define H_VIRTPROFIT_P             16

#define METRIC_TOTAL_MONEY_NET      1           // cumulated PnL metrics
#define METRIC_TOTAL_UNITS_VIRT     2
#define METRIC_TOTAL_UNITS_GROSS    3
#define METRIC_TOTAL_UNITS_NET      4

#define METRIC_DAILY_MONEY_NET      5           // daily PnL metrics
#define METRIC_DAILY_UNITS_VIRT     6
#define METRIC_DAILY_UNITS_GROSS    7
#define METRIC_DAILY_UNITS_NET      8

#define METRIC_NEXT                 1           // directions for toggling between metrics
#define METRIC_PREVIOUS            -1

// general
int      tradingMode;

// instance data
int      instance.id;                           // used for magic order numbers
string   instance.name = "";
datetime instance.created;
bool     instance.isTest;                       // whether the instance is a test
int      instance.status;
double   instance.startEquity;

double   instance.openNetProfit;                // PnL in money (net)
double   instance.closedNetProfit;
double   instance.totalNetProfit;
double   instance.maxNetProfit;                 // max. observed profit:   0...+n
double   instance.maxNetDrawdown;               // max. observed drawdown: -n...0
double   instance.avgNetProfit = EMPTY_VALUE;

double   instance.openNetProfitP;               // PnL in point after all costs (net)
double   instance.closedNetProfitP;
double   instance.totalNetProfitP;
double   instance.maxNetProfitP;
double   instance.maxNetDrawdownP;
double   instance.avgNetProfitP = EMPTY_VALUE;

double   instance.openGrossProfitP;             // PnL in point after spread but without any other costs (gross)
double   instance.closedGrossProfitP;
double   instance.totalGrossProfitP;
double   instance.maxGrossProfitP;
double   instance.maxGrossDrawdownP;
double   instance.avgGrossProfitP = EMPTY_VALUE;

double   instance.openVirtProfitP;              // virtual PnL in point without any costs (assumes exact execution)
double   instance.closedVirtProfitP;
double   instance.totalVirtProfitP;
double   instance.maxVirtProfitP;
double   instance.maxVirtDrawdownP;
double   instance.avgVirtProfitP = EMPTY_VALUE;

// order data
int      open.ticket;                           // one open position
int      open.type;
double   open.lots;
datetime open.time;
double   open.price;
double   open.priceVirt;
double   open.slippage;
double   open.swap;
double   open.commission;
double   open.grossProfit;
double   open.grossProfitP;
double   open.netProfit;
double   open.netProfitP;
double   open.virtProfitP;
double   history[][17];                         // multiple closed positions

// start conditions
bool     start.time.condition;                  // whether a time condition is active
datetime start.time.value;
bool     start.time.isDaily;
string   start.time.description = "";

// stop conditions ("OR" combined)
bool     stop.time.condition;                   // whether a time condition is active
datetime stop.time.value;
bool     stop.time.isDaily;
string   stop.time.description = "";

bool     stop.profitAbs.condition;              // whether a takeprofit condition in money is active
double   stop.profitAbs.value;
string   stop.profitAbs.description = "";

bool     stop.profitPct.condition;              // whether a takeprofit condition in percent is active
double   stop.profitPct.value;
double   stop.profitPct.absValue    = INT_MAX;
string   stop.profitPct.description = "";

bool     stop.profitPun.condition;              // whether a takeprofit condition in price units is active (pip or full point)
int      stop.profitPun.type;
double   stop.profitPun.value;
string   stop.profitPun.description = "";

// volatile status data
int      status.activeMetric = METRIC_TOTAL_MONEY_NET;

// other
string   pUnit = "";
int      pDigits;
int      pMultiplier;
int      orders.acceptableSlippage = 1;         // in MQL points
string   tradingModeDescriptions[] = {"", "regular", "virtual"};
string   tpTypeDescriptions     [] = {"off", "money", "percent", "pip", "quote currency", "index points"};

// cache vars to speed-up ShowStatus()
string   sTradingModeStatus[] = {"", "", "Virtual "};
string   sOpenLots            = "";
string   sClosedTrades        = "";
string   sStartConditions     = "";
string   sStopConditions      = "";
string   sInstanceTotalNetPL  = "";
string   sInstancePlStats     = "";

// debug settings, configurable via framework config, see afterInit()
bool     test.onReversalPause     = false;      // whether to pause a test after a ZigZag reversal
bool     test.onSessionBreakPause = false;      // whether to pause a test after StopInstance(SIGNAL_TIME)
bool     test.onStopPause         = false;      // whether to pause a test after a final StopInstance()
bool     test.reduceStatusWrites  = true;       // whether to reduce status file I/O in tester

#include <apps/zigzag-ea/init.mqh>
#include <apps/zigzag-ea/deinit.mqh>


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   if (!instance.status) return(ERR_ILLEGAL_STATE);

   if (__isChart) HandleCommands();                            // process incoming commands

   if (instance.status != STATUS_STOPPED) {
      int signal, zzSignal;
      IsZigZagSignal(zzSignal);                                // check ZigZag on every tick (signals can occur anytime)

      if (instance.status == STATUS_WAITING) {
         if (IsStartSignal(signal)) StartInstance(signal);
      }
      else if (instance.status == STATUS_PROGRESSING) {
         if (UpdateStatus()) {
            if (IsStopSignal(signal))  StopInstance(signal);
            else if (zzSignal != NULL) ReverseInstance(zzSignal);
         }
      }
      RecordMetrics();
   }
   return(catch("onTick(1)"));
}


/**
 * Process an incoming command.
 *
 * @param  string cmd    - command name
 * @param  string params - command parameters
 * @param  int    keys   - combination of pressed modifier keys
 *
 * @return bool - success status of the executed command
 */
bool onCommand(string cmd, string params, int keys) {
   string fullCmd = cmd +":"+ params +":"+ keys;

   if (cmd == "start") {
      switch (instance.status) {
         case STATUS_WAITING:
         case STATUS_STOPPED:
            string sDetail = " ";
            int logLevel = LOG_INFO;

            if (params == "long") {
               int signal = SIGNAL_LONG;
            }
            else if (params == "short") {
               signal = SIGNAL_SHORT;
            }
            else {
               if (params != "") {
                  sDetail  = " skipping unsupported parameter in command ";
                  logLevel = LOG_NOTICE;
               }
               signal = ifInt(GetZigZagTrend(0) > 0, SIGNAL_LONG, SIGNAL_SHORT);
            }
            log("onCommand(1)  "+ instance.name + sDetail + DoubleQuoteStr(fullCmd), NO_ERROR, logLevel);
            return(StartInstance(signal));
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

   else if (cmd == "wait") {
      switch (instance.status) {
         case STATUS_STOPPED:
            logInfo("onCommand(3)  "+ instance.name +" "+ DoubleQuoteStr(fullCmd));
            instance.status = STATUS_WAITING;
            return(SaveStatus());
      }
   }

   else if (cmd == "toggle-metrics") {
      int direction = ifInt(keys & F_VK_SHIFT, METRIC_PREVIOUS, METRIC_NEXT);
      return(ToggleMetrics(direction));
   }

   else if (cmd == "toggle-open-orders") {
      return(ToggleOpenOrders());
   }

   else if (cmd == "toggle-trade-history") {
      return(ToggleTradeHistory());
   }
   else return(!logNotice("onCommand(4)  "+ instance.name +" unsupported command: "+ DoubleQuoteStr(fullCmd)));

   return(!logWarn("onCommand(5)  "+ instance.name +" cannot execute command "+ DoubleQuoteStr(fullCmd) +" in status "+ StatusToStr(instance.status)));
}


/**
 * Toggle EA status between displayed metrics.
 *
 * @param  int direction - METRIC_NEXT|METRIC_PREVIOUS
 *
 * @return bool - success status
 */
bool ToggleMetrics(int direction) {
   if (direction!=METRIC_NEXT && direction!=METRIC_PREVIOUS) return(!catch("ToggleMetrics(1)  invalid parameter direction: "+ direction, ERR_INVALID_PARAMETER));

   status.activeMetric += direction;
   if (status.activeMetric < 1) status.activeMetric = 4;    // valid metrics: 1-4
   if (status.activeMetric > 4) status.activeMetric = 1;
   StoreVolatileData();

   debug("ToggleMetrics(0.1)  "+ instance.name +"  new metric: "+ status.activeMetric);
   return(true);
}


/**
 * Toggle the display of open orders.
 *
 * @return bool - success status
 */
bool ToggleOpenOrders() {
   // read current status and toggle it
   bool showOrders = !GetOpenOrderDisplayStatus();

   // ON: display open orders
   if (showOrders) {
      int orders = ShowOpenOrders();
      if (orders == -1) return(false);
      if (!orders) {                                  // Without open orders status must be reset to have the "off" section
         showOrders = false;                          // remove any existing open order markers.
         PlaySoundEx("Plonk.wav");
      }
   }

   // OFF: remove open order markers
   if (!showOrders) {
      for (int i=ObjectsTotal()-1; i >= 0; i--) {
         string name = ObjectName(i);

         if (StringGetChar(name, 0) == '#') {
            if (ObjectType(name) == OBJ_ARROW) {
               int arrow = ObjectGet(name, OBJPROP_ARROWCODE);
               color clr = ObjectGet(name, OBJPROP_COLOR);

               if (arrow == SYMBOL_ORDEROPEN) {
                  if (clr!=CLR_OPEN_LONG && clr!=CLR_OPEN_SHORT) continue;
               }
               else if (arrow == SYMBOL_ORDERCLOSE) {
                  if (clr!=CLR_OPEN_TAKEPROFIT && clr!=CLR_OPEN_STOPLOSS) continue;
               }
               ObjectDelete(name);
            }
         }
      }
   }

   // store current status in the chart
   SetOpenOrderDisplayStatus(showOrders);

   if (__isTesting) WindowRedraw();
   return(!catch("ToggleOpenOrders(1)"));
}


/**
 * Resolve the current 'ShowOpenOrders' display status.
 *
 * @return bool - ON/OFF
 */
bool GetOpenOrderDisplayStatus() {
   bool status = false;

   // look-up a status stored in the chart
   string label = "rsf."+ ProgramName() +".ShowOpenOrders";
   if (ObjectFind(label) != -1) {
      string sValue = ObjectDescription(label);
      if (StrIsInteger(sValue))
         status = (StrToInteger(sValue) != 0);
   }
   return(status);
}


/**
 * Store the passed 'ShowOpenOrders' display status.
 *
 * @param  bool status - display status
 *
 * @return bool - success status
 */
bool SetOpenOrderDisplayStatus(bool status) {
   status = status!=0;

   // store status in the chart (for terminal restarts)
   string label = "rsf."+ ProgramName() +".ShowOpenOrders";
   if (ObjectFind(label) == -1) ObjectCreate(label, OBJ_LABEL, 0, 0, 0);
   ObjectSet    (label, OBJPROP_TIMEFRAMES, OBJ_PERIODS_NONE);
   ObjectSetText(label, ""+ status);

   return(!catch("SetOpenOrderDisplayStatus(1)"));
}


/**
 * Display the currently open orders.
 *
 * @return int - number of displayed orders or EMPTY (-1) in case of errors
 */
int ShowOpenOrders() {
   string orderTypes[] = {"buy", "sell"};
   color colors[] = {CLR_OPEN_LONG, CLR_OPEN_SHORT};
   int openOrders = 0;

   if (open.ticket != NULL) {
      string label = StringConcatenate("#", open.ticket, " ", orderTypes[open.type], " ", NumberToStr(open.lots, ".+"), " at ", NumberToStr(open.price, PriceFormat));
      if (ObjectFind(label) == -1) if (!ObjectCreate(label, OBJ_ARROW, 0, 0, 0)) return(EMPTY);
      ObjectSet    (label, OBJPROP_ARROWCODE, SYMBOL_ORDEROPEN);
      ObjectSet    (label, OBJPROP_COLOR,     colors[open.type]);
      ObjectSet    (label, OBJPROP_TIME1,     open.time);
      ObjectSet    (label, OBJPROP_PRICE1,    open.price);
      ObjectSetText(label, instance.name);
      openOrders++;
   }

   if (!catch("ShowOpenOrders(1)"))
      return(openOrders);
   return(EMPTY);
}


/**
 * Toggle the display of closed trades.
 *
 * @return bool - success status
 */
bool ToggleTradeHistory() {
   // read current status and toggle it
   bool showHistory = !GetTradeHistoryDisplayStatus();

   // ON: display closed trades
   if (showHistory) {
      int trades = ShowTradeHistory();
      if (trades == -1) return(false);
      if (!trades) {                                        // Without any closed trades the status must be reset to enable
         showHistory = false;                               // the "off" section to clear existing markers.
         PlaySoundEx("Plonk.wav");
      }
   }

   // OFF: remove all closed trade markers (from this EA or another program)
   if (!showHistory) {
      for (int i=ObjectsTotal()-1; i >= 0; i--) {
         string name = ObjectName(i);

         if (StringGetChar(name, 0) == '#') {
            if (ObjectType(name) == OBJ_ARROW) {
               int arrow = ObjectGet(name, OBJPROP_ARROWCODE);
               color clr = ObjectGet(name, OBJPROP_COLOR);

               if (arrow == SYMBOL_ORDEROPEN) {
                  if (clr!=CLR_CLOSED_LONG && clr!=CLR_CLOSED_SHORT) continue;
               }
               else if (arrow == SYMBOL_ORDERCLOSE) {
                  if (clr!=CLR_CLOSED) continue;
               }
            }
            else if (ObjectType(name) != OBJ_TREND) continue;
            ObjectDelete(name);
         }
      }
   }

   // store current status in the chart
   SetTradeHistoryDisplayStatus(showHistory);

   if (__isTesting) WindowRedraw();
   return(!catch("ToggleTradeHistory(1)"));
}


/**
 * Resolve the current "ShowTradeHistory" display status.
 *
 * @return bool - ON/OFF
 */
bool GetTradeHistoryDisplayStatus() {
   bool status = false;

   // look-up a status stored in the chart
   string label = "rsf."+ ProgramName() +".ShowTradeHistory";
   if (ObjectFind(label) != -1) {
      string sValue = ObjectDescription(label);
      if (StrIsInteger(sValue))
         status = (StrToInteger(sValue) != 0);
   }
   return(status);
}


/**
 * Store the passed "ShowTradeHistory" display status.
 *
 * @param  bool status - display status
 *
 * @return bool - success status
 */
bool SetTradeHistoryDisplayStatus(bool status) {
   status = status!=0;

   // store status in the chart
   string label = "rsf."+ ProgramName() +".ShowTradeHistory";
   if (ObjectFind(label) == -1)
      ObjectCreate(label, OBJ_LABEL, 0, 0, 0);
   ObjectSet    (label, OBJPROP_TIMEFRAMES, OBJ_PERIODS_NONE);
   ObjectSetText(label, ""+ status);

   return(!catch("SetTradeHistoryDisplayStatus(1)"));
}


/**
 * Display closed trades.
 *
 * @return int - number of displayed trades or EMPTY (-1) in case of errors
 */
int ShowTradeHistory() {
   string openLabel="", lineLabel="", closeLabel="", sOpenPrice="", sClosePrice="", sOperations[]={"buy", "sell"};
   int iOpenColors[]={CLR_CLOSED_LONG, CLR_CLOSED_SHORT}, iLineColors[]={Blue, Red};

   // process the local trade history
   int orders = ArrayRange(history, 0), closedTrades = 0;

   for (int i=0; i < orders; i++) {
      int      ticket     = history[i][H_TICKET    ];
      int      type       = history[i][H_OPENTYPE  ];
      double   lots       = history[i][H_LOTS      ];
      datetime openTime   = history[i][H_OPENTIME  ];
      double   openPrice  = history[i][H_OPENPRICE ];
      datetime closeTime  = history[i][H_CLOSETIME ];
      double   closePrice = history[i][H_CLOSEPRICE];

      if (!closeTime)                    continue;             // skip open tickets (should not happen)
      if (type!=OP_BUY && type!=OP_SELL) continue;             // skip non-trades   (should not happen)

      sOpenPrice  = NumberToStr(openPrice, PriceFormat);
      sClosePrice = NumberToStr(closePrice, PriceFormat);

      // open marker
      openLabel = StringConcatenate("#", ticket, " ", sOperations[type], " ", NumberToStr(lots, ".+"), " at ", sOpenPrice);
      if (ObjectFind(openLabel) == -1) ObjectCreate(openLabel, OBJ_ARROW, 0, 0, 0);
      ObjectSet    (openLabel, OBJPROP_ARROWCODE, SYMBOL_ORDEROPEN);
      ObjectSet    (openLabel, OBJPROP_COLOR,     iOpenColors[type]);
      ObjectSet    (openLabel, OBJPROP_TIME1,     openTime);
      ObjectSet    (openLabel, OBJPROP_PRICE1,    openPrice);
      ObjectSetText(openLabel, instance.name);

      // trend line
      lineLabel = StringConcatenate("#", ticket, " ", sOpenPrice, " -> ", sClosePrice);
      if (ObjectFind(lineLabel) == -1) ObjectCreate(lineLabel, OBJ_TREND, 0, 0, 0, 0, 0);
      ObjectSet(lineLabel, OBJPROP_RAY,    false);
      ObjectSet(lineLabel, OBJPROP_STYLE,  STYLE_DOT);
      ObjectSet(lineLabel, OBJPROP_COLOR,  iLineColors[type]);
      ObjectSet(lineLabel, OBJPROP_BACK,   true);
      ObjectSet(lineLabel, OBJPROP_TIME1,  openTime);
      ObjectSet(lineLabel, OBJPROP_PRICE1, openPrice);
      ObjectSet(lineLabel, OBJPROP_TIME2,  closeTime);
      ObjectSet(lineLabel, OBJPROP_PRICE2, closePrice);

      // close marker
      closeLabel = StringConcatenate(openLabel, " close at ", sClosePrice);
      if (ObjectFind(closeLabel) == -1) ObjectCreate(closeLabel, OBJ_ARROW, 0, 0, 0);
      ObjectSet    (closeLabel, OBJPROP_ARROWCODE, SYMBOL_ORDERCLOSE);
      ObjectSet    (closeLabel, OBJPROP_COLOR,     CLR_CLOSED);
      ObjectSet    (closeLabel, OBJPROP_TIME1,     closeTime);
      ObjectSet    (closeLabel, OBJPROP_PRICE1,    closePrice);
      ObjectSetText(closeLabel, instance.name);
      closedTrades++;
   }

   if (!catch("ShowTradeHistory(1)"))
      return(closedTrades);
   return(EMPTY);
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
            lastSignal = signal;

            if (IsVisualMode()) {                  // pause the tester according to the debug configuration
               if (test.onReversalPause) Tester.Pause("IsZigZagSignal(1)");
            }
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
   combinedTrend = MathRound(icZigZag(NULL, ZigZag.Periods, ZigZag.MODE_TREND,    bar));
   reversal      = MathRound(icZigZag(NULL, ZigZag.Periods, ZigZag.MODE_REVERSAL, bar));
   return(combinedTrend != 0);
}


/**
 * Get the length of the ZigZag trend at the specified bar offset.
 *
 * @param  int bar - bar offset
 *
 * @return int - trend length or NULL (0) in case of errors
 */
int GetZigZagTrend(int bar) {
   int trend, iNull;
   if (!GetZigZagTrendData(bar, trend, iNull)) return(NULL);
   return(trend % 100000);
}


#define MODE_TRADESERVER   1
#define MODE_STRATEGY      2


/**
 * Whether the current time is outside of the specified trading time range.
 *
 * @param  _In_    int      tradingFrom    - daily trading start time offset in seconds
 * @param  _In_    int      tradingTo      - daily trading stop time offset in seconds
 * @param  _InOut_ datetime &stopTime      - last stop time preceeding 'nextStartTime'
 * @param  _InOut_ datetime &nextStartTime - next start time in the future
 * @param  _In_    int      mode           - one of MODE_TRADESERVER | MODE_STRATEGY
 *
 * @return bool
 */
bool IsTradingBreak(int tradingFrom, int tradingTo, datetime &stopTime, datetime &nextStartTime, int mode) {
   if (mode!=MODE_TRADESERVER && mode!=MODE_STRATEGY) return(!catch("IsTradingBreak(1)  "+ instance.name +" invalid parameter mode: "+ mode, ERR_INVALID_PARAMETER));
   datetime srvNow = TimeServer();

   // check whether to recalculate start/stop times
   if (srvNow >= nextStartTime) {
      int startOffset = tradingFrom % DAYS;
      int stopOffset  = tradingTo % DAYS;

      // calculate today's theoretical start time in SRV and FXT
      datetime srvMidnight  = srvNow - srvNow % DAYS;                // today's Midnight in SRV
      datetime srvStartTime = srvMidnight + startOffset;             // today's theoretical start time in SRV
      datetime fxtNow       = ServerToFxtTime(srvNow);
      datetime fxtMidnight  = fxtNow - fxtNow % DAYS;                // today's Midnight in FXT
      datetime fxtStartTime = fxtMidnight + startOffset;             // today's theoretical start time in FXT

      // determine the next real start time in SRV
      bool skipWeekend = (Symbol() != "BTCUSD");                     // BTCUSD trades at weekends           // TODO: make configurable
      int dow = TimeDayOfWeekEx(fxtStartTime);
      bool isWeekend = (dow==SATURDAY || dow==SUNDAY);

      while (srvStartTime <= srvNow || (isWeekend && skipWeekend)) {
         srvStartTime += 1*DAY;
         fxtStartTime += 1*DAY;
         dow = TimeDayOfWeekEx(fxtStartTime);
         isWeekend = (dow==SATURDAY || dow==SUNDAY);
      }
      nextStartTime = srvStartTime;

      // determine the preceeding stop time
      srvMidnight          = srvStartTime - srvStartTime % DAYS;     // the start day's Midnight in SRV
      datetime srvStopTime = srvMidnight + stopOffset;               // the start day's theoretical stop time in SRV
      fxtMidnight          = fxtStartTime - fxtStartTime % DAYS;     // the start day's Midnight in FXT
      datetime fxtStopTime = fxtMidnight + stopOffset;               // the start day's theoretical stop time in FXT

      dow = TimeDayOfWeekEx(fxtStopTime);
      isWeekend = (dow==SATURDAY || dow==SUNDAY);

      while (srvStopTime > srvStartTime || (isWeekend && skipWeekend) || (dow==MONDAY && fxtStopTime==fxtMidnight)) {
         srvStopTime -= 1*DAY;
         fxtStopTime -= 1*DAY;
         dow = TimeDayOfWeekEx(fxtStopTime);
         isWeekend = (dow==SATURDAY || dow==SUNDAY);                 // BTCUSD trades at weekends           // TODO: make configurable
      }
      stopTime = srvStopTime;

      if (IsLogDebug()) logDebug("IsTradingBreak(2)  "+ instance.name +" recalculated "+ ifString(srvNow >= stopTime, "current", "next") + ifString(mode==MODE_TRADESERVER, " trade session", " strategy") +" stop \""+ TimeToStr(startOffset, TIME_MINUTES) +"-"+ TimeToStr(stopOffset, TIME_MINUTES) +"\" as "+ GmtTimeFormat(stopTime, "%a, %Y.%m.%d %H:%M:%S") +" to "+ GmtTimeFormat(nextStartTime, "%a, %Y.%m.%d %H:%M:%S"));
   }

   // perform the actual check
   return(srvNow >= stopTime);                                       // nextStartTime is in the future of stopTime
}


datetime tradeSession.startOffset = D'1970.01.01 00:05:00';
datetime tradeSession.stopOffset  = D'1970.01.01 23:55:00';
datetime tradeSession.startTime;
datetime tradeSession.stopTime;


/**
 * Whether the current time is outside of the broker's trade session.
 *
 * @return bool
 */
bool IsTradeSessionBreak() {
   return(IsTradingBreak(tradeSession.startOffset, tradeSession.stopOffset, tradeSession.stopTime, tradeSession.startTime, MODE_TRADESERVER));
}


datetime strategy.startTime;
datetime strategy.stopTime;


/**
 * Whether the current time is outside of the strategy's trading times.
 *
 * @return bool
 */
bool IsStrategyBreak() {
   return(IsTradingBreak(start.time.value, stop.time.value, strategy.stopTime, strategy.startTime, MODE_STRATEGY));
}


// start/stop time variants:
// +------+----------+----------+---------------------------------------------+----------------------+--------------------------------------------------+
// | case | startime | stoptime | behavior                                    | validation           | adjustment                                       |
// +------+----------+----------+---------------------------------------------+----------------------+--------------------------------------------------+
// |  1   | -        | -        | immediate start, never stop                 |                      |                                                  |
// |  2   | fix      | -        | defined start, never stop                   |                      | after start disable starttime condition          |
// |  3   | -        | fix      | immediate start, defined stop               |                      | after stop disable stoptime condition            |
// |  4   | fix      | fix      | defined start, defined stop                 | starttime < stoptime | after start/stop disable corresponding condition |
// +------+----------+----------+---------------------------------------------+----------------------+--------------------------------------------------+
// |  5   | daily    | -        | next start, never stop                      |                      | after start disable starttime condition          |
// |  6   | -        | daily    | immediate start, next stop after start      |                      |                                                  |
// |  7   | daily    | daily    | immediate|next start, next stop after start |                      |                                                  |
// +------+----------+----------+---------------------------------------------+----------------------+--------------------------------------------------+
// |  8   | fix      | daily    | defined start, next stop after start        |                      | after start disable starttime condition          |
// |  9   | daily    | fix      | next start if before stop, defined stop     |                      | after stop disable stoptime condition            |
// +------+----------+----------+---------------------------------------------+----------------------+--------------------------------------------------+


/**
 * Whether the expert is able and allowed to trade at the current time.
 *
 * @return bool
 */
bool IsTradingTime() {
   if (IsTradeSessionBreak()) return(false);

   if (!start.time.condition && !stop.time.condition) {     // case 1
      return(!catch("IsTradingTime(1)  start.time=(empty) + stop.time=(empty) not implemented", ERR_NOT_IMPLEMENTED));
   }
   else if (!stop.time.condition) {                         // case 2 or 5
      return(!catch("IsTradingTime(2)  stop.time=(empty) not implemented", ERR_NOT_IMPLEMENTED));
   }
   else if (!start.time.condition) {                        // case 3 or 6
      return(!catch("IsTradingTime(3)  start.time=(empty) not implemented", ERR_NOT_IMPLEMENTED));
   }
   else if (!start.time.isDaily && !stop.time.isDaily) {    // case 4
      return(!catch("IsTradingTime(4)  start.time=(fix) + stop.time=(fix) not implemented", ERR_NOT_IMPLEMENTED));
   }
   else if (start.time.isDaily && stop.time.isDaily) {      // case 7
      if (IsStrategyBreak()) return(false);
   }
   else if (stop.time.isDaily) {                            // case 8
      return(!catch("IsTradingTime(5)  start.time=(fix) + stop.time=(daily) not implemented", ERR_NOT_IMPLEMENTED));
   }
   else {                                                   // case 9
      return(!catch("IsTradingTime(6)  start.time=(daily) + stop.time=(fix) not implemented", ERR_NOT_IMPLEMENTED));
   }
   return(true);
}


/**
 * Whether a start condition is triggered.
 *
 * @param  _Out_ int &signal - variable receiving the signal identifier of a triggered condition
 *
 * @return bool
 */
bool IsStartSignal(int &signal) {
   signal = NULL;
   if (last_error || instance.status!=STATUS_WAITING) return(false);

   // start.time ------------------------------------------------------------------------------------------------------------
   if (!IsTradingTime()) {
      return(false);
   }

   // ZigZag signal ---------------------------------------------------------------------------------------------------------
   if (IsZigZagSignal(signal)) {
      logNotice("IsStartSignal(1)  "+ instance.name +" ZigZag "+ ifString(signal==SIGNAL_LONG, "long", "short") +" reversal (market: "+ NumberToStr(Bid, PriceFormat) +"/"+ NumberToStr(Ask, PriceFormat) +")");
      return(true);
   }
   return(false);
}


/**
 * Whether a stop condition is triggered.
 *
 * @param  _Out_ int &signal - variable receiving the identifier of a triggered condition
 *
 * @return bool
 */
bool IsStopSignal(int &signal) {
   signal = NULL;
   if (last_error || (instance.status!=STATUS_WAITING && instance.status!=STATUS_PROGRESSING)) return(false);

   if (instance.status == STATUS_PROGRESSING) {
      // stop.profitAbs: ----------------------------------------------------------------------------------------------------
      if (stop.profitAbs.condition) {
         if (instance.totalNetProfit >= stop.profitAbs.value) {
            signal = SIGNAL_TAKEPROFIT;
            logNotice("IsStopSignal(1)  "+ instance.name +" stop condition \"@"+ stop.profitAbs.description +"\" triggered (market: "+ NumberToStr(Bid, PriceFormat) +"/"+ NumberToStr(Ask, PriceFormat) +")");
            return(true);
         }
      }

      // stop.profitPct: ----------------------------------------------------------------------------------------------------
      if (stop.profitPct.condition) {
         if (stop.profitPct.absValue == INT_MAX)
            stop.profitPct.absValue = stop.profitPct.AbsValue();

         if (instance.totalNetProfit >= stop.profitPct.absValue) {
            signal = SIGNAL_TAKEPROFIT;
            logNotice("IsStopSignal(2)  "+ instance.name +" stop condition \"@"+ stop.profitPct.description +"\" triggered (market: "+ NumberToStr(Bid, PriceFormat) +"/"+ NumberToStr(Ask, PriceFormat) +")");
            return(true);
         }
      }

      // stop.profitPun: ----------------------------------------------------------------------------------------------------
      if (stop.profitPun.condition) {
         if (instance.totalNetProfitP >= stop.profitPun.value) {
            signal = SIGNAL_TAKEPROFIT;
            logNotice("IsStopSignal(3)  "+ instance.name +" stop condition \"@"+ stop.profitPun.description +"\" triggered (market: "+ NumberToStr(Bid, PriceFormat) +"/"+ NumberToStr(Ask, PriceFormat) +")");
            return(true);
         }
      }
   }

   // stop.time: ------------------------------------------------------------------------------------------------------------
   if (stop.time.condition) {
      if (!IsTradingTime()) {
         signal = SIGNAL_TIME;
         logNotice("IsStopSignal(4)  "+ instance.name +" stop condition \"@"+ stop.time.description +"\" triggered (market: "+ NumberToStr(Bid, PriceFormat) +"/"+ NumberToStr(Ask, PriceFormat) +")");
         return(true);
      }
   }
   return(false);
}


/**
 * Start a waiting or restart a stopped instance.
 *
 * @param  int signal - trade signal causing the call
 *
 * @return bool - success status
 */
bool StartInstance(int signal) {
   if (last_error != NULL)                                                 return(false);
   if (instance.status!=STATUS_WAITING && instance.status!=STATUS_STOPPED) return(!catch("StartInstance(1)  "+ instance.name +" cannot start "+ StatusDescription(instance.status) +" instance", ERR_ILLEGAL_STATE));
   if (signal!=SIGNAL_LONG && signal!=SIGNAL_SHORT)                        return(!catch("StartInstance(2)  "+ instance.name +" invalid parameter signal: "+ signal, ERR_INVALID_PARAMETER));

   instance.status = STATUS_PROGRESSING;
   if (!instance.startEquity) instance.startEquity = NormalizeDouble(AccountEquity() - AccountCredit() + GetExternalAssets(), 2);

   // open a new position
   int      type        = ifInt(signal==SIGNAL_LONG, OP_BUY, OP_SELL);
   double   price       = NULL;
   datetime expires     = NULL;
   string   comment     = "ZigZag."+ instance.id;
   int      magicNumber = CalculateMagicNumber();
   color    marker      = ifInt(!type, CLR_OPEN_LONG, CLR_OPEN_SHORT);

   int ticket, oeFlags, oe[];
   if (tradingMode == TRADINGMODE_VIRTUAL) ticket = VirtualOrderSend(type, Lots, NULL, NULL, marker, oe);
   else                                    ticket = OrderSendEx(Symbol(), type, Lots, price, orders.acceptableSlippage, NULL, NULL, comment, magicNumber, expires, marker, oeFlags, oe);
   if (!ticket) return(!SetLastError(oe.Error(oe)));

   // store the position data
   open.ticket       = ticket;
   open.type         = type;
   open.lots         = oe.Lots(oe); SS.OpenLots();
   open.time         = oe.OpenTime(oe);
   open.price        = oe.OpenPrice(oe);
   open.priceVirt    = Bid;
   open.slippage     = oe.Slippage(oe);
   open.swap         = oe.Swap(oe);
   open.commission   = oe.Commission(oe);
   open.grossProfit  = oe.Profit(oe);
   open.grossProfitP = ifDouble(!open.type, Bid-open.price, open.price-Ask);
   open.netProfit    = open.grossProfit + open.swap + open.commission;
   open.netProfitP   = open.grossProfitP + (open.swap + open.commission)/PointValue(open.lots);
   open.virtProfitP  = 0;

   // update PL numbers
   instance.openNetProfit  = open.netProfit;
   instance.totalNetProfit = instance.openNetProfit + instance.closedNetProfit;
   instance.maxNetProfit   = MathMax(instance.maxNetProfit,   instance.totalNetProfit);
   instance.maxNetDrawdown = MathMin(instance.maxNetDrawdown, instance.totalNetProfit);

   instance.openNetProfitP  = open.netProfitP;
   instance.totalNetProfitP = instance.openNetProfitP + instance.closedNetProfitP;
   instance.maxNetProfitP   = MathMax(instance.maxNetProfitP,   instance.totalNetProfitP);
   instance.maxNetDrawdownP = MathMin(instance.maxNetDrawdownP, instance.totalNetProfitP);

   instance.openGrossProfitP  = open.grossProfitP;
   instance.totalGrossProfitP = instance.openGrossProfitP + instance.closedGrossProfitP;
   instance.maxGrossProfitP   = MathMax(instance.maxGrossProfitP,   instance.totalGrossProfitP);
   instance.maxGrossDrawdownP = MathMin(instance.maxGrossDrawdownP, instance.totalGrossProfitP);

   instance.openVirtProfitP  = 0;
   instance.totalVirtProfitP = instance.closedVirtProfitP;
   instance.maxVirtProfitP   = MathMax(instance.maxVirtProfitP,   instance.totalVirtProfitP);
   instance.maxVirtDrawdownP = MathMin(instance.maxVirtDrawdownP, instance.totalVirtProfitP);
   SS.TotalPL();
   SS.PLStats();

   // update start conditions
   if (start.time.condition) {
      if (!start.time.isDaily || !stop.time.condition) {                   // see start/stop time variants
         start.time.condition = false;
      }
   }
   SS.StartStopConditions();

   if (IsLogInfo()) logInfo("StartInstance(3)  "+ instance.name +" instance started ("+ SignalToStr(signal) +")");
   return(SaveStatus());
}


/**
 * Reverse a progressing instance.
 *
 * @param  int signal - trade signal causing the call
 *
 * @return bool - success status
 */
bool ReverseInstance(int signal) {
   if (last_error != NULL)                          return(false);
   if (instance.status != STATUS_PROGRESSING)       return(!catch("ReverseInstance(1)  "+ instance.name +" cannot reverse "+ StatusDescription(instance.status) +" instance", ERR_ILLEGAL_STATE));
   if (signal!=SIGNAL_LONG && signal!=SIGNAL_SHORT) return(!catch("ReverseInstance(2)  "+ instance.name +" invalid parameter signal: "+ signal, ERR_INVALID_PARAMETER));
   int ticket, oeFlags, oe[];

   if (open.ticket > 0) {
      // continue with an already reversed position
      if ((open.type==OP_BUY && signal==SIGNAL_LONG) || (open.type==OP_SELL && signal==SIGNAL_SHORT)) {
         return(_true(logWarn("ReverseInstance(3)  "+ instance.name +" to "+ ifString(signal==SIGNAL_LONG, "long", "short") +": continuing with already open "+ ifString(tradingMode==TRADINGMODE_VIRTUAL, "virtual ", "") + ifString(signal==SIGNAL_LONG, "long", "short") +" position #"+ open.ticket)));
      }

      // close the existing position
      bool success;
      if (tradingMode == TRADINGMODE_VIRTUAL) success = VirtualOrderClose(open.ticket, open.lots, CLR_NONE, oe);
      else                                    success = OrderCloseEx(open.ticket, NULL, orders.acceptableSlippage, CLR_NONE, oeFlags, oe);
      if (!success) return(!SetLastError(oe.Error(oe)));

      open.slippage    += oe.Slippage(oe);
      open.swap         = oe.Swap(oe);
      open.commission   = oe.Commission(oe);
      open.grossProfit  = oe.Profit(oe);
      open.netProfit    = open.grossProfit + open.swap + open.commission;
      open.grossProfitP = ifDouble(!open.type, oe.ClosePrice(oe)-open.price, open.price-oe.ClosePrice(oe));
      open.netProfitP   = open.grossProfitP + (open.swap + open.commission)/PointValue(oe.Lots(oe));
      if (!MoveCurrentPositionToHistory(oe.CloseTime(oe), oe.ClosePrice(oe), Bid)) return(false);
   }

   // open a new position
   int      type        = ifInt(signal==SIGNAL_LONG, OP_BUY, OP_SELL);
   double   price       = NULL;
   datetime expires     = NULL;
   string   comment     = "ZigZag."+ instance.id;
   int      magicNumber = CalculateMagicNumber();
   color    marker      = ifInt(type==OP_BUY, CLR_OPEN_LONG, CLR_OPEN_SHORT);

   if (tradingMode == TRADINGMODE_VIRTUAL) ticket = VirtualOrderSend(type, Lots, NULL, NULL, marker, oe);
   else                                    ticket = OrderSendEx(Symbol(), type, Lots, price, orders.acceptableSlippage, NULL, NULL, comment, magicNumber, expires, marker, oeFlags, oe);
   if (!ticket) return(!SetLastError(oe.Error(oe)));

   // store the new position data
   open.ticket       = ticket;
   open.type         = type;
   open.lots         = oe.Lots(oe); SS.OpenLots();
   open.time         = oe.OpenTime(oe);
   open.price        = oe.OpenPrice(oe);
   open.priceVirt    = Bid;
   open.slippage     = oe.Slippage(oe);
   open.swap         = oe.Swap(oe);
   open.commission   = oe.Commission(oe);
   open.grossProfit  = oe.Profit(oe);
   open.grossProfitP = ifDouble(type==OP_BUY, oe.Bid(oe)-open.price, open.price-oe.Ask(oe));
   open.netProfit    = open.grossProfit + open.swap + open.commission;
   open.netProfitP   = open.grossProfitP + (open.swap + open.commission)/PointValue(open.lots);
   open.virtProfitP  = 0;

   // update PL numbers
   instance.openNetProfit  = open.netProfit;
   instance.totalNetProfit = instance.openNetProfit + instance.closedNetProfit;
   instance.maxNetProfit   = MathMax(instance.maxNetProfit,   instance.totalNetProfit);
   instance.maxNetDrawdown = MathMin(instance.maxNetDrawdown, instance.totalNetProfit);

   instance.openNetProfitP  = open.netProfitP;
   instance.totalNetProfitP = instance.openNetProfitP + instance.closedNetProfitP;
   instance.maxNetProfitP   = MathMax(instance.maxNetProfitP,   instance.totalNetProfitP);
   instance.maxNetDrawdownP = MathMin(instance.maxNetDrawdownP, instance.totalNetProfitP);

   instance.openGrossProfitP  = open.grossProfitP;
   instance.totalGrossProfitP = instance.openGrossProfitP + instance.closedGrossProfitP;
   instance.maxGrossProfitP   = MathMax(instance.maxGrossProfitP,   instance.totalGrossProfitP);
   instance.maxGrossDrawdownP = MathMin(instance.maxGrossDrawdownP, instance.totalGrossProfitP);

   instance.openVirtProfitP  = 0;
   instance.totalVirtProfitP = instance.closedVirtProfitP;
   instance.maxVirtProfitP   = MathMax(instance.maxVirtProfitP,   instance.totalVirtProfitP);
   instance.maxVirtDrawdownP = MathMin(instance.maxVirtDrawdownP, instance.totalVirtProfitP);
   SS.TotalPL();
   SS.PLStats();

   return(SaveStatus());
}


/**
 * Return the absolute value of a percentage type TakeProfit condition.
 *
 * @return double - absolute value or INT_MAX if no percentage TakeProfit was configured
 */
double stop.profitPct.AbsValue() {
   if (stop.profitPct.condition) {
      if (stop.profitPct.absValue == INT_MAX) {
         double startEquity = instance.startEquity;
         if (!startEquity) startEquity = AccountEquity() - AccountCredit() + GetExternalAssets();
         return(stop.profitPct.value/100 * startEquity);
      }
   }
   return(stop.profitPct.absValue);
}


/**
 * Stop a waiting or progressing instance and close open positions (if any).
 *
 * @param  int signal - signal which triggered the stop condition or NULL on explicit stop (e.g. manual)
 *
 * @return bool - success status
 */
bool StopInstance(int signal) {
   if (last_error != NULL)                                                     return(false);
   if (instance.status!=STATUS_WAITING && instance.status!=STATUS_PROGRESSING) return(!catch("StopInstance(1)  "+ instance.name +" cannot stop "+ StatusDescription(instance.status) +" instance", ERR_ILLEGAL_STATE));

   // close an open position
   if (instance.status == STATUS_PROGRESSING) {
      if (open.ticket > 0) {
         bool success;
         int oeFlags, oe[];
         if (tradingMode == TRADINGMODE_VIRTUAL) success = VirtualOrderClose(open.ticket, open.lots, CLR_NONE, oe);
         else                                    success = OrderCloseEx(open.ticket, NULL, orders.acceptableSlippage, CLR_NONE, oeFlags, oe);
         if (!success) return(!SetLastError(oe.Error(oe)));

         open.slippage    += oe.Slippage(oe);
         open.swap         = oe.Swap(oe);
         open.commission   = oe.Commission(oe);
         open.grossProfit  = oe.Profit(oe);
         open.netProfit    = open.grossProfit + open.swap + open.commission;
         open.grossProfitP = ifDouble(!open.type, oe.ClosePrice(oe)-open.price, open.price-oe.ClosePrice(oe));
         open.netProfitP   = open.grossProfitP + (open.swap + open.commission)/PointValue(oe.Lots(oe));
         if (!MoveCurrentPositionToHistory(oe.CloseTime(oe), oe.ClosePrice(oe), Bid)) return(false);

         instance.openNetProfit  = open.netProfit;
         instance.totalNetProfit = instance.openNetProfit + instance.closedNetProfit;
         instance.maxNetProfit   = MathMax(instance.maxNetProfit,   instance.totalNetProfit);
         instance.maxNetDrawdown = MathMin(instance.maxNetDrawdown, instance.totalNetProfit);

         instance.openNetProfitP  = open.netProfitP;
         instance.totalNetProfitP = instance.openNetProfitP + instance.closedNetProfitP;
         instance.maxNetProfitP   = MathMax(instance.maxNetProfitP,   instance.totalNetProfitP);
         instance.maxNetDrawdownP = MathMin(instance.maxNetDrawdownP, instance.totalNetProfitP);

         instance.openGrossProfitP  = open.grossProfitP;
         instance.totalGrossProfitP = instance.openGrossProfitP + instance.closedGrossProfitP;
         instance.maxGrossProfitP   = MathMax(instance.maxGrossProfitP,   instance.totalGrossProfitP);
         instance.maxGrossDrawdownP = MathMin(instance.maxGrossDrawdownP, instance.totalGrossProfitP);

         instance.openVirtProfitP  = open.virtProfitP;
         instance.totalVirtProfitP = instance.openVirtProfitP + instance.closedVirtProfitP;
         instance.maxVirtProfitP   = MathMax(instance.maxVirtProfitP,   instance.totalVirtProfitP);
         instance.maxVirtDrawdownP = MathMin(instance.maxVirtDrawdownP, instance.totalVirtProfitP);
         SS.TotalPL();
         SS.PLStats();
      }
   }

   // update stop conditions and status
   switch (signal) {
      case SIGNAL_TIME:
         if (!stop.time.isDaily) {
            stop.time.condition = false;                    // see start/stop time variants
         }
         instance.status = ifInt(start.time.condition && start.time.isDaily, STATUS_WAITING, STATUS_STOPPED);
         break;

      case SIGNAL_TAKEPROFIT:
         stop.profitAbs.condition = false;
         stop.profitPct.condition = false;
         stop.profitPun.condition = false;
         instance.status          = STATUS_STOPPED;
         break;

      case NULL:                                            // explicit stop (manual) or end of test
         instance.status = STATUS_STOPPED;
         break;

      default: return(!catch("StopInstance(2)  "+ instance.name +" invalid parameter signal: "+ signal, ERR_INVALID_PARAMETER));
   }
   SS.StartStopConditions();

   if (IsLogInfo()) logInfo("StopInstance(3)  "+ instance.name +" "+ ifString(__isTesting && !signal, "test ", "") +"instance stopped"+ ifString(!signal, "", " ("+ SignalToStr(signal) +")") +", profit: "+ sInstanceTotalNetPL +" "+ sInstancePlStats);
   SaveStatus();

   // pause/stop the tester according to the debug configuration
   if (__isTesting) {
      if      (!IsVisualMode())       { if (instance.status == STATUS_STOPPED) Tester.Stop ("StopInstance(4)"); }
      else if (signal == SIGNAL_TIME) { if (test.onSessionBreakPause)          Tester.Pause("StopInstance(5)"); }
      else                            { if (test.onStopPause)                  Tester.Pause("StopInstance(6)"); }
   }
   return(!catch("StopInstance(7)"));
}


/**
 * Update order status and PL.
 *
 * @return bool - success status
 */
bool UpdateStatus() {
   if (last_error != NULL)                    return(false);
   if (instance.status != STATUS_PROGRESSING) return(!catch("UpdateStatus(1)  "+ instance.name +" cannot update order status of "+ StatusDescription(instance.status) +" instance", ERR_ILLEGAL_STATE));
   if (!open.ticket)                          return(true);

   if (tradingMode == TRADINGMODE_VIRTUAL) {
      open.swap         = 0;
      open.commission   = 0;
      open.grossProfitP = ifDouble(!open.type, Bid-open.price, open.price-Ask);
      open.grossProfit  = open.grossProfitP * PointValue(open.lots);
      open.netProfit    = open.grossProfit;
      open.netProfitP   = open.grossProfitP;
      open.virtProfitP  = ifDouble(!open.type, Bid-open.priceVirt, open.priceVirt-Bid);
   }
   else {
      if (!SelectTicket(open.ticket, "UpdateStatus(2)")) return(false);
      open.swap         = NormalizeDouble(OrderSwap(), 2);
      open.commission   = OrderCommission();
      open.grossProfit  = OrderProfit();
      open.grossProfitP = ifDouble(!open.type, Bid-open.price, open.price-Ask);
      open.netProfit    = open.grossProfit + open.swap + open.commission;
      open.netProfitP   = open.grossProfitP; if (open.swap!=0 || open.commission!=0) open.netProfitP += (open.swap + open.commission)/PointValue(OrderLots());
      open.virtProfitP  = ifDouble(!open.type, Bid-open.priceVirt, open.priceVirt-Bid);

      if (OrderCloseTime() != NULL) {
         int error;
         if (IsError(onPositionClose("UpdateStatus(3)  "+ instance.name +" "+ UpdateStatus.PositionCloseMsg(error), error))) return(false);
         if (!MoveCurrentPositionToHistory(OrderCloseTime(), OrderClosePrice(), OrderClosePrice()))                          return(false);
      }
   }

   instance.openNetProfit    = open.netProfit;
   instance.openNetProfitP   = open.netProfitP;
   instance.openGrossProfitP = open.grossProfitP;
   instance.openVirtProfitP  = open.virtProfitP;

   instance.totalNetProfit    = instance.openNetProfit    + instance.closedNetProfit;
   instance.totalNetProfitP   = instance.openNetProfitP   + instance.closedNetProfitP;
   instance.totalGrossProfitP = instance.openGrossProfitP + instance.closedGrossProfitP;
   instance.totalVirtProfitP  = instance.openVirtProfitP  + instance.closedVirtProfitP;
   SS.TotalPL();

   bool updateStats = false;
   if      (instance.totalNetProfit    > instance.maxNetProfit     ) { instance.maxNetProfit      = instance.totalNetProfit;    updateStats = true; }
   else if (instance.totalNetProfit    < instance.maxNetDrawdown   ) { instance.maxNetDrawdown    = instance.totalNetProfit;    updateStats = true; }
   if      (instance.totalNetProfitP   > instance.maxNetProfitP    ) { instance.maxNetProfitP     = instance.totalNetProfitP;   updateStats = true; }
   else if (instance.totalNetProfitP   < instance.maxNetDrawdownP  ) { instance.maxNetDrawdownP   = instance.totalNetProfitP;   updateStats = true; }
   if      (instance.totalGrossProfitP > instance.maxGrossProfitP  ) { instance.maxGrossProfitP   = instance.totalGrossProfitP; updateStats = true; }
   else if (instance.totalGrossProfitP < instance.maxGrossDrawdownP) { instance.maxGrossDrawdownP = instance.totalGrossProfitP; updateStats = true; }
   if      (instance.totalVirtProfitP  > instance.maxVirtProfitP   ) { instance.maxVirtProfitP    = instance.totalVirtProfitP;  updateStats = true; }
   else if (instance.totalVirtProfitP  < instance.maxVirtDrawdownP ) { instance.maxVirtDrawdownP  = instance.totalVirtProfitP;  updateStats = true; }
   if (updateStats) SS.PLStats();

   return(!catch("UpdateStatus(4)"));
}


/**
 * Compose a log message for a closed position. The ticket must be selected.
 *
 * @param  _Out_ int error - error code to be returned from the call (if any)
 *
 * @return string - log message or an empty string in case of errors
 */
string UpdateStatus.PositionCloseMsg(int &error) {
   // #1 Sell 0.1 GBPUSD at 1.5457'2 ("Z.869") was [unexpectedly ]closed at 1.5457'2 (market: Bid/Ask[, so: 47.7%/169.20/354.40])
   error = NO_ERROR;

   int    ticket     = OrderTicket();
   int    type       = OrderType();
   double lots       = OrderLots();
   double openPrice  = OrderOpenPrice();
   double closePrice = OrderClosePrice();

   string sType       = OperationTypeDescription(type);
   string sOpenPrice  = NumberToStr(openPrice, PriceFormat);
   string sClosePrice = NumberToStr(closePrice, PriceFormat);
   string sUnexpected = ifString(__CoreFunction==CF_INIT || (__CoreFunction==CF_DEINIT && __isTesting), "", "unexpectedly ");
   string message     = "#"+ ticket +" "+ sType +" "+ NumberToStr(lots, ".+") +" "+ OrderSymbol() +" at "+ sOpenPrice +" (\""+ instance.name +"\") was "+ sUnexpected +"closed at "+ sClosePrice;

   string sStopout = "";
   if (StrStartsWithI(OrderComment(), "so:")) {       error = ERR_MARGIN_STOPOUT; sStopout = ", "+ OrderComment(); }
   else if (__CoreFunction==CF_INIT)                  error = NO_ERROR;
   else if (__CoreFunction==CF_DEINIT && __isTesting) error = NO_ERROR;
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
 * Move the current open position to the trade history. Assumes the position is closed.
 *
 * @param datetime closeTime      - close time
 * @param double   closePrice     - close price
 * @param double   closePriceVirt - virtual close price
 *
 * @return bool - success status
 */
bool MoveCurrentPositionToHistory(datetime closeTime, double closePrice, double closePriceVirt) {
   if (last_error != NULL)                    return(false);
   if (instance.status != STATUS_PROGRESSING) return(!catch("MoveCurrentPositionToHistory(1)  "+ instance.name +" cannot process current position of "+ StatusDescription(instance.status) +" instance", ERR_ILLEGAL_STATE));
   if (!open.ticket)                          return(!catch("MoveCurrentPositionToHistory(2)  "+ instance.name +" no open position found (open.ticket=NULL)", ERR_ILLEGAL_STATE));

   // update position data
   open.virtProfitP = ifDouble(!open.type, closePriceVirt-open.priceVirt, open.priceVirt-closePriceVirt);

   // add data to history
   int i = ArrayRange(history, 0);
   ArrayResize(history, i+1);
   history[i][H_TICKET         ] = open.ticket;
   history[i][H_OPENTYPE       ] = open.type;
   history[i][H_LOTS           ] = open.lots;
   history[i][H_OPENTIME       ] = open.time;
   history[i][H_OPENPRICE      ] = open.price;
   history[i][H_OPENPRICE_VIRT ] = open.priceVirt;
   history[i][H_CLOSETIME      ] = closeTime;
   history[i][H_CLOSEPRICE     ] = closePrice;
   history[i][H_CLOSEPRICE_VIRT] = closePriceVirt;
   history[i][H_SLIPPAGE       ] = open.slippage;
   history[i][H_SWAP           ] = open.swap;
   history[i][H_COMMISSION     ] = open.commission;
   history[i][H_GROSSPROFIT    ] = open.grossProfit;
   history[i][H_GROSSPROFIT_P  ] = open.grossProfitP;
   history[i][H_NETPROFIT      ] = open.netProfit;
   history[i][H_NETPROFIT_P    ] = open.netProfitP;
   history[i][H_VIRTPROFIT_P   ] = open.virtProfitP;

   // update PL numbers
   instance.openNetProfit    = 0;
   instance.openNetProfitP   = 0;
   instance.openGrossProfitP = 0;
   instance.openVirtProfitP  = 0;

   instance.closedNetProfit    += open.netProfit;
   instance.closedNetProfitP   += open.netProfitP;
   instance.closedGrossProfitP += open.grossProfitP;
   instance.closedVirtProfitP  += open.virtProfitP;

   // reset open position data
   open.ticket       = NULL;
   open.type         = NULL;
   open.lots         = NULL;
   open.time         = NULL;
   open.price        = NULL;
   open.priceVirt    = NULL;
   open.slippage     = NULL;
   open.swap         = NULL;
   open.commission   = NULL;
   open.grossProfit  = NULL;
   open.grossProfitP = NULL;
   open.netProfit    = NULL;
   open.netProfitP   = NULL;
   open.virtProfitP  = NULL;
   SS.OpenLots();

   // update trade stats
   CalculateTradeStats();
   SS.ClosedTrades();

   return(!catch("MoveCurrentPositionToHistory(3)"));
}


/**
 * Update trade statistics.
 */
void CalculateTradeStats() {
   static int lastSize = 0;
   static double sumNetProfit=0, sumNetProfitP=0, sumGrossProfitP=0, sumVirtProfitP=0;

   int size = ArrayRange(history, 0);

   if (!size || size < lastSize) {
      sumNetProfit    = 0;
      sumNetProfitP   = 0;
      sumGrossProfitP = 0;
      sumVirtProfitP  = 0;
      instance.avgNetProfit    = EMPTY_VALUE;
      instance.avgNetProfitP   = EMPTY_VALUE;
      instance.avgGrossProfitP = EMPTY_VALUE;
      instance.avgVirtProfitP  = EMPTY_VALUE;
      lastSize = 0;
   }

   if (size > lastSize) {
      for (int i=lastSize; i < size; i++) {                 // speed-up by processing only new history entries
         sumNetProfit    += history[i][H_NETPROFIT    ];
         sumNetProfitP   += history[i][H_NETPROFIT_P  ];
         sumGrossProfitP += history[i][H_GROSSPROFIT_P];
         sumVirtProfitP  += history[i][H_VIRTPROFIT_P ];
      }
      instance.avgNetProfit    = sumNetProfit/size;
      instance.avgNetProfitP   = sumNetProfitP/size;
      instance.avgGrossProfitP = sumGrossProfitP/size;
      instance.avgVirtProfitP  = sumVirtProfitP/size;
      lastSize = size;
   }
}


/**
 * Calculate a magic order number for the strategy.
 *
 * @param  int instanceId [optional] - instance to calculate the magic number for (default: the current instance)
 *
 * @return int - magic number or NULL in case of errors
 */
int CalculateMagicNumber(int instanceId = NULL) {
   if (STRATEGY_ID < 101 || STRATEGY_ID > 1023)      return(!catch("CalculateMagicNumber(1)  "+ instance.name +" illegal strategy id: "+ STRATEGY_ID, ERR_ILLEGAL_STATE));
   int id = intOr(instanceId, instance.id);
   if (id < INSTANCE_ID_MIN || id > INSTANCE_ID_MAX) return(!catch("CalculateMagicNumber(2)  "+ instance.name +" illegal instance id: "+ id, ERR_ILLEGAL_STATE));

   int strategy = STRATEGY_ID;                              // 101-1023 (10 bit)
   int instance = id;                                       // now 100-999 but was 1000-9999 (14 bit)

   return((strategy<<22) + (instance<<8));                  // the remaining 8 bit are not used in this strategy
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
 * @return int - instance id in the range of 100-999 or NULL in case of errors
 */
int CreateInstanceId() {
   MathSrand(GetTickCount()-__ExecutionContext[EC.hChartWindow]);
   int instanceId, magicNumber;

   while (!magicNumber) {
      while (instanceId < INSTANCE_ID_MIN || instanceId > INSTANCE_ID_MAX) {
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
         if (!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) return(!catch("CreateInstanceId(2)  "+ instance.name, intOr(GetLastError(), ERR_RUNTIME_ERROR)));
         if (OrderMagicNumber() == magicNumber) {
            magicNumber = NULL;
            break;
         }
      }
   }
   return(instanceId);
}


/**
 * Return a symbol definition for the specified metric to be recorded.
 *
 * @param  _In_  int    id           - metric id
 * @param  _Out_ bool   &ready       - whether metric details are complete and the metric is ready to be recorded
 * @param  _Out_ string &symbol      - unique MT4 timeseries symbol
 * @param  _Out_ string &description - symbol description as in the MT4 "Symbols" window
 * @param  _Out_ string &group       - symbol group name as in the MT4 "Symbols" window
 * @param  _Out_ int    &digits      - symbol digits value
 * @param  _Out_ double &baseValue   - quotes base value (if EMPTY recorder settings are used)
 * @param  _Out_ int    &multiplier  - quotes multiplier
 *
 * @return int - error status; especially ERR_INVALID_INPUT_PARAMETER if the passed metric id is unknown or not supported
 */
int Recorder_GetSymbolDefinition(int id, bool &ready, string &symbol, string &description, string &group, int &digits, double &baseValue, int &multiplier) {
   string sId = ifString(!instance.id, "???", instance.id);
   string descrSuffix = "";

   ready      = false;
   group      = "";
   baseValue  = EMPTY;
   digits     = pDigits;
   multiplier = pMultiplier;

   switch (id) {
      // --------------------------------------------------------------------------------------------------------------------
      case METRIC_TOTAL_MONEY_NET:              // OK
         symbol      = StrLeft(Symbol(), 6) +"."+ sId +"A";                      // "US500.123A"
         descrSuffix = ", "+ PeriodDescription() +", net PnL in "+ AccountCurrency() + LocalTimeFormat(GetGmtTime(), ", %d.%m.%Y %H:%M");
         digits      = 2;
         multiplier  = 1;
         break;

      case METRIC_TOTAL_UNITS_VIRT:             // OK
         symbol      = StrLeft(Symbol(), 6) +"."+ sId +"B";
         descrSuffix = ", "+ PeriodDescription() +", virtual PnL in "+ pUnit + LocalTimeFormat(GetGmtTime(), ", %d.%m.%Y %H:%M");
         break;

      case METRIC_TOTAL_UNITS_GROSS:            // OK
         symbol      = StrLeft(Symbol(), 6) +"."+ sId +"C";
         descrSuffix = ", "+ PeriodDescription() +", gross PnL in "+ pUnit + LocalTimeFormat(GetGmtTime(), ", %d.%m.%Y %H:%M");
         break;

      case METRIC_TOTAL_UNITS_NET:              // OK
         symbol      = StrLeft(Symbol(), 6) +"."+ sId +"D";
         descrSuffix = ", "+ PeriodDescription() +", net PnL in "+ pUnit + LocalTimeFormat(GetGmtTime(), ", %d.%m.%Y %H:%M");
         break;

      // --------------------------------------------------------------------------------------------------------------------
      case METRIC_DAILY_MONEY_NET:
         symbol      = StrLeft(Symbol(), 6) +"."+ sId +"E";
         descrSuffix = ", "+ PeriodDescription() +", daily net PnL in "+ AccountCurrency() + LocalTimeFormat(GetGmtTime(), ", %d.%m.%Y %H:%M");
         digits      = 2;
         multiplier  = 1;
         break;

      case METRIC_DAILY_UNITS_VIRT:
         symbol      = StrLeft(Symbol(), 6) +"."+ sId +"F";
         descrSuffix = ", "+ PeriodDescription() +", daily virtual PnL in "+ pUnit + LocalTimeFormat(GetGmtTime(), ", %d.%m.%Y %H:%M");
         break;

      case METRIC_DAILY_UNITS_GROSS:
         symbol      = StrLeft(Symbol(), 6) +"."+ sId +"G";
         descrSuffix = ", "+ PeriodDescription() +", daily gross PnL in "+ pUnit + LocalTimeFormat(GetGmtTime(), ", %d.%m.%Y %H:%M");
         break;

      case METRIC_DAILY_UNITS_NET:
         symbol      = StrLeft(Symbol(), 6) +"."+ sId +"H";
         descrSuffix = ", "+ PeriodDescription() +", daily net PnL in "+ pUnit + LocalTimeFormat(GetGmtTime(), ", %d.%m.%Y %H:%M");
         break;

      default:
         return(ERR_INVALID_INPUT_PARAMETER);
   }

   description = StrLeft(ProgramName(), 63-StringLen(descrSuffix )) + descrSuffix;
   ready = (instance.id > 0);

   return(NO_ERROR);
}


/**
 * Update the recorder with current metric values.
 */
void RecordMetrics() {
   if (recorder.mode == RECORDER_CUSTOM) {
      int size = ArraySize(metric.ready);
      if (size > METRIC_TOTAL_MONEY_NET  ) metric.currValue[METRIC_TOTAL_MONEY_NET  ] = instance.totalNetProfit;
      if (size > METRIC_TOTAL_UNITS_VIRT ) metric.currValue[METRIC_TOTAL_UNITS_VIRT ] = instance.totalVirtProfitP;
      if (size > METRIC_TOTAL_UNITS_GROSS) metric.currValue[METRIC_TOTAL_UNITS_GROSS] = instance.totalGrossProfitP;
      if (size > METRIC_TOTAL_UNITS_NET  ) metric.currValue[METRIC_TOTAL_UNITS_NET  ] = instance.totalNetProfitP;
   }
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
 * Return the name of the status file.
 *
 * @param  bool relative [optional] - whether to return an absolute path or a path relative to the MQL "files" directory
 *                                    (default: absolute path)
 *
 * @return string - filename or an empty string in case of errors
 */
string GetStatusFilename(bool relative = false) {
   relative = relative!=0;
   if (!instance.id)      return(_EMPTY_STR(catch("GetStatusFilename(1)  "+ instance.name +" illegal value of instance.id: 0", ERR_ILLEGAL_STATE)));
   if (!instance.created) return(_EMPTY_STR(catch("GetStatusFilename(2)  "+ instance.name +" illegal value of instance.created: 0", ERR_ILLEGAL_STATE)));

   static string filename = ""; if (!StringLen(filename)) {
      string directory = "presets/"+ ifString(IsTestInstance(), "Tester", GetAccountCompanyId()) +"/";
      string baseName  = ProgramName() +", "+ Symbol() +", "+ GmtTimeFormat(instance.created, "%Y-%m-%d %H.%M") +", id="+ instance.id +".set";
      filename = directory + baseName;
   }

   if (relative)
      return(filename);
   return(GetMqlSandboxPath() +"/"+ filename);
}


/**
 * Find an existing status file for the specified instance.
 *
 * @param  int  instanceId - instance id
 * @param  bool isTest     - whether the instance is a test instance
 *
 * @return string - absolute filename or an empty string in case of errors
 */
string FindStatusFile(int instanceId, bool isTest) {
   if (instanceId < INSTANCE_ID_MIN || instanceId > INSTANCE_ID_MAX) return(_EMPTY_STR(catch("FindStatusFile(1)  "+ instance.name +" invalid parameter instanceId: "+ instanceId, ERR_INVALID_PARAMETER)));
   isTest = isTest!=0;

   string sandboxDir  = GetMqlSandboxPath() +"/";
   string statusDir   = "presets/"+ ifString(isTest, "Tester", GetAccountCompanyId()) +"/";
   string basePattern = ProgramName() +", "+ Symbol() +",*id="+ instanceId +".set";
   string pathPattern = sandboxDir + statusDir + basePattern;

   string result[];
   int size = FindFileNames(pathPattern, result, FF_FILESONLY);

   if (size != 1) {
      if (size > 1) return(_EMPTY_STR(logError("FindStatusFile(2)  "+ instance.name +" multiple matching files found for pattern "+ DoubleQuoteStr(pathPattern), ERR_ILLEGAL_STATE)));
   }
   return(sandboxDir + statusDir + result[0]);
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
      case NULL              : return("(undefined)");
      case STATUS_WAITING    : return("waiting"    );
      case STATUS_PROGRESSING: return("progressing");
      case STATUS_STOPPED    : return("stopped"    );
   }
   return(_EMPTY_STR(catch("StatusDescription(1)  "+ instance.name +" invalid parameter status: "+ status, ERR_INVALID_PARAMETER)));
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
      case NULL             : return("no signal"        );
      case SIGNAL_LONG      : return("SIGNAL_LONG"      );
      case SIGNAL_SHORT     : return("SIGNAL_SHORT"     );
      case SIGNAL_TIME      : return("SIGNAL_TIME"      );
      case SIGNAL_TAKEPROFIT: return("SIGNAL_TAKEPROFIT");
   }
   return(_EMPTY_STR(catch("SignalToStr(1)  "+ instance.name +" invalid parameter signal: "+ signal, ERR_INVALID_PARAMETER)));
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
   WriteIniString(file, section, "Created", GmtTimeFormat(instance.created, "%a, %Y.%m.%d %H:%M:%S") + separator);         // conditional section separator

   if (__isTesting) {
      string sSpread = "";
      if (MathMax(Digits, 2) > 2) sSpread = DoubleToStr(MarketInfo(Symbol(), MODE_SPREAD)/PipPoints, 1);                   // transform Digits=1 to 2 (for some indices)
      else                        sSpread = DoubleToStr(MarketInfo(Symbol(), MODE_SPREAD)*Point, 2);
      WriteIniString(file, section, "Test.Range",    "?");
      WriteIniString(file, section, "Test.Period",   PeriodDescription());
      WriteIniString(file, section, "Test.BarModel", BarModelDescription(__Test.barModel));
      WriteIniString(file, section, "Test.Spread",   sSpread + separator);                                                 // conditional section separator
   }

   // [Inputs]
   section = "Inputs";
   WriteIniString(file, section, "Instance.ID",                 /*string*/ Instance.ID);
   WriteIniString(file, section, "TradingMode",                 /*string*/ TradingMode);
   WriteIniString(file, section, "ZigZag.Periods",              /*int   */ ZigZag.Periods);
   WriteIniString(file, section, "Lots",                        /*double*/ NumberToStr(Lots, ".+"));
   WriteIniString(file, section, "StartConditions",             /*string*/ SaveStatus.ConditionsToStr(sStartConditions));  // contains only active conditions
   WriteIniString(file, section, "StopConditions",              /*string*/ SaveStatus.ConditionsToStr(sStopConditions));   // contains only active conditions
   WriteIniString(file, section, "TakeProfit",                  /*double*/ NumberToStr(TakeProfit, ".+"));
   WriteIniString(file, section, "TakeProfit.Type",             /*string*/ TakeProfit.Type);
   WriteIniString(file, section, "ShowProfitInPercent",         /*bool  */ ShowProfitInPercent);
   WriteIniString(file, section, "EA.Recorder",                 /*string*/ EA.Recorder + separator);                       // conditional section separator

   // [Runtime status]
   section = "Runtime status";                                  // On deletion of pending orders the number of stored order records decreases. To prevent
   EmptyIniSectionA(file, section);                             // orphaned status file records the section is emptied before writing to it.

   WriteIniString(file, section, "tradingMode",                 /*int     */ tradingMode + CRLF);

   // instance data
   WriteIniString(file, section, "instance.id",                 /*int     */ instance.id);
   WriteIniString(file, section, "instance.name",               /*string  */ instance.name);
   WriteIniString(file, section, "instance.created",            /*datetime*/ instance.created + GmtTimeFormat(instance.created, " (%a, %Y.%m.%d %H:%M:%S)"));
   WriteIniString(file, section, "instance.isTest",             /*bool    */ instance.isTest);
   WriteIniString(file, section, "instance.status",             /*int     */ instance.status +" ("+ StatusDescription(instance.status) +")");
   WriteIniString(file, section, "instance.startEquity",        /*double  */ DoubleToStr(instance.startEquity, 2) + CRLF);

   WriteIniString(file, section, "instance.openNetProfit",      /*double  */ DoubleToStr(instance.openNetProfit, 2));
   WriteIniString(file, section, "instance.closedNetProfit",    /*double  */ DoubleToStr(instance.closedNetProfit, 2));
   WriteIniString(file, section, "instance.totalNetProfit",     /*double  */ StrPadRight(DoubleToStr(instance.totalNetProfit, 2), 16)         +" ; in "+ AccountCurrency() +" after all costs (net)");
   WriteIniString(file, section, "instance.maxNetProfit",       /*double  */ DoubleToStr(instance.maxNetProfit, 2));
   WriteIniString(file, section, "instance.maxNetDrawdown",     /*double  */ DoubleToStr(instance.maxNetDrawdown, 2));
   WriteIniString(file, section, "instance.avgNetProfit",       /*double  */ DoubleToStr(instance.avgNetProfit, 2) + CRLF);

   WriteIniString(file, section, "instance.openNetProfitP",     /*double  */ NumberToStr(instance.openNetProfitP, ".1+"));
   WriteIniString(file, section, "instance.closedNetProfitP",   /*double  */ NumberToStr(instance.closedNetProfitP, ".1+"));
   WriteIniString(file, section, "instance.totalNetProfitP",    /*double  */ StrPadRight(NumberToStr(instance.totalNetProfitP, ".1+"), 15)    +" ; in point after all costs (net)");
   WriteIniString(file, section, "instance.maxNetProfitP",      /*double  */ NumberToStr(instance.maxNetProfitP, ".1+"));
   WriteIniString(file, section, "instance.maxNetDrawdownP",    /*double  */ NumberToStr(instance.maxNetDrawdownP, ".1+"));
   WriteIniString(file, section, "instance.avgNetProfitP",      /*double  */ NumberToStr(instance.avgNetProfitP, ".1+") + CRLF);

   WriteIniString(file, section, "instance.openGrossProfitP",   /*double  */ DoubleToStr(instance.openGrossProfitP, Digits));
   WriteIniString(file, section, "instance.closedGrossProfitP", /*double  */ DoubleToStr(instance.closedGrossProfitP, Digits));
   WriteIniString(file, section, "instance.totalGrossProfitP",  /*double  */ StrPadRight(DoubleToStr(instance.totalGrossProfitP, Digits), 13) +" ; in point after spread but without any other costs (gross)");
   WriteIniString(file, section, "instance.maxGrossProfitP",    /*double  */ DoubleToStr(instance.maxGrossProfitP, Digits));
   WriteIniString(file, section, "instance.maxGrossDrawdownP",  /*double  */ DoubleToStr(instance.maxGrossDrawdownP, Digits));
   WriteIniString(file, section, "instance.avgGrossProfitP",    /*double  */ DoubleToStr(instance.avgGrossProfitP, Digits+1) + CRLF);

   WriteIniString(file, section, "instance.openVirtProfitP",    /*double  */ DoubleToStr(instance.openVirtProfitP, Digits));
   WriteIniString(file, section, "instance.closedVirtProfitP",  /*double  */ DoubleToStr(instance.closedVirtProfitP, Digits));
   WriteIniString(file, section, "instance.totalVirtProfitP",   /*double  */ StrPadRight(DoubleToStr(instance.totalVirtProfitP, Digits), 14)  +" ; virtual PnL in point without any costs (assumes exact execution)");
   WriteIniString(file, section, "instance.maxVirtProfitP",     /*double  */ DoubleToStr(instance.maxVirtProfitP, Digits));
   WriteIniString(file, section, "instance.maxVirtDrawdownP",   /*double  */ DoubleToStr(instance.maxVirtDrawdownP, Digits));
   WriteIniString(file, section, "instance.avgVirtProfitP",     /*double  */ DoubleToStr(instance.avgVirtProfitP, Digits+1) + CRLF);

   // open order data
   WriteIniString(file, section, "open.ticket",                 /*int     */ open.ticket);
   WriteIniString(file, section, "open.type",                   /*int     */ open.type);
   WriteIniString(file, section, "open.lots",                   /*double  */ NumberToStr(open.lots, ".+"));
   WriteIniString(file, section, "open.time",                   /*datetime*/ open.time + ifString(open.time, GmtTimeFormat(open.time, " (%a, %Y.%m.%d %H:%M:%S)"), ""));
   WriteIniString(file, section, "open.price",                  /*double  */ DoubleToStr(open.price, Digits));
   WriteIniString(file, section, "open.priceVirt",              /*double  */ DoubleToStr(open.priceVirt, Digits));
   WriteIniString(file, section, "open.slippage",               /*double  */ DoubleToStr(open.slippage, Digits));
   WriteIniString(file, section, "open.swap",                   /*double  */ DoubleToStr(open.swap, 2));
   WriteIniString(file, section, "open.commission",             /*double  */ DoubleToStr(open.commission, 2));
   WriteIniString(file, section, "open.grossProfit",            /*double  */ DoubleToStr(open.grossProfit, 2));
   WriteIniString(file, section, "open.grossProfitP",           /*double  */ DoubleToStr(open.grossProfitP, Digits));
   WriteIniString(file, section, "open.netProfit",              /*double  */ DoubleToStr(open.netProfit, 2));
   WriteIniString(file, section, "open.netProfitP",             /*double  */ NumberToStr(open.netProfitP, ".1+"));
   WriteIniString(file, section, "open.virtProfitP",            /*double  */ DoubleToStr(open.virtProfitP, Digits) + CRLF);

   // closed order data
   double netProfit, netProfitP, grossProfitP, virtProfitP;
   int size = ArrayRange(history, 0);

   for (int i=0; i < size; i++) {
      WriteIniString(file, section, "history."+ i, SaveStatus.HistoryToStr(i) + ifString(i+1 < size, "", CRLF));
      netProfit    += history[i][H_NETPROFIT    ];
      netProfitP   += history[i][H_NETPROFIT_P  ];
      grossProfitP += history[i][H_GROSSPROFIT_P];
      virtProfitP  += history[i][H_VIRTPROFIT_P ];
   }

   // cross-check stored stats
   int precision = MathMax(Digits, 2) + 1;                      // required precision for fractional point values
   if (NE(netProfit,    instance.closedNetProfit, 2))          return(!catch("SaveStatus(2)  "+ instance.name +" sum(history[H_NETPROFIT]) != instance.closedNetProfit ("       + NumberToStr(netProfit, ".2+")               +" != "+ NumberToStr(instance.closedNetProfit, ".2+")               +")", ERR_ILLEGAL_STATE));
   if (NE(netProfitP,   instance.closedNetProfitP, precision)) return(!catch("SaveStatus(3)  "+ instance.name +" sum(history[H_NETPROFIT_P]) != instance.closedNetProfitP ("    + NumberToStr(netProfitP, "."+ Digits +"+")   +" != "+ NumberToStr(instance.closedNetProfitP, "."+ Digits +"+")   +")", ERR_ILLEGAL_STATE));
   if (NE(grossProfitP, instance.closedGrossProfitP, Digits))  return(!catch("SaveStatus(4)  "+ instance.name +" sum(history[H_GROSSPROFIT_P]) != instance.closedGrossProfitP ("+ NumberToStr(grossProfitP, "."+ Digits +"+") +" != "+ NumberToStr(instance.closedGrossProfitP, "."+ Digits +"+") +")", ERR_ILLEGAL_STATE));
   if (NE(virtProfitP,  instance.closedVirtProfitP,  Digits))  return(!catch("SaveStatus(5)  "+ instance.name +" sum(history[H_VIRTPROFIT_P]) != instance.closedVirtProfitP ("  + NumberToStr(virtProfitP, "."+ Digits +"+")  +" != "+ NumberToStr(instance.closedVirtProfitP, "."+ Digits +"+")  +")", ERR_ILLEGAL_STATE));

   // start/stop conditions
   WriteIniString(file, section, "start.time.condition",        /*bool    */ start.time.condition);
   WriteIniString(file, section, "start.time.value",            /*datetime*/ start.time.value + ifString(start.time.value, ifString(start.time.isDaily, " ("+ TimeToStr(start.time.value, TIME_MINUTES) +")", GmtTimeFormat(start.time.value, " (%a, %Y.%m.%d %H:%M:%S)")), ""));
   WriteIniString(file, section, "start.time.isDaily",          /*bool    */ start.time.isDaily);
   WriteIniString(file, section, "start.time.description",      /*string  */ start.time.description + CRLF);

   WriteIniString(file, section, "stop.time.condition",         /*bool    */ stop.time.condition);
   WriteIniString(file, section, "stop.time.value",             /*datetime*/ stop.time.value + ifString(stop.time.value, ifString(stop.time.isDaily, " ("+ TimeToStr(stop.time.value, TIME_MINUTES) +")", GmtTimeFormat(stop.time.value, " (%a, %Y.%m.%d %H:%M:%S)")), ""));
   WriteIniString(file, section, "stop.time.isDaily",           /*bool    */ stop.time.isDaily);
   WriteIniString(file, section, "stop.time.description",       /*string  */ stop.time.description + CRLF);

   WriteIniString(file, section, "stop.profitAbs.condition",    /*bool    */ stop.profitAbs.condition);
   WriteIniString(file, section, "stop.profitAbs.value",        /*double  */ DoubleToStr(stop.profitAbs.value, 2));
   WriteIniString(file, section, "stop.profitAbs.description",  /*string  */ stop.profitAbs.description);
   WriteIniString(file, section, "stop.profitPct.condition",    /*bool    */ stop.profitPct.condition);
   WriteIniString(file, section, "stop.profitPct.value",        /*double  */ NumberToStr(stop.profitPct.value, ".1+"));
   WriteIniString(file, section, "stop.profitPct.absValue",     /*double  */ ifString(stop.profitPct.absValue==INT_MAX, INT_MAX, DoubleToStr(stop.profitPct.absValue, 2)));
   WriteIniString(file, section, "stop.profitPct.description",  /*string  */ stop.profitPct.description);
   WriteIniString(file, section, "stop.profitPun.condition",    /*bool    */ stop.profitPun.condition);
   WriteIniString(file, section, "stop.profitPun.type",         /*int     */ stop.profitPun.type);
   WriteIniString(file, section, "stop.profitPun.value",        /*double  */ NumberToStr(stop.profitPun.value, ".1+"));
   WriteIniString(file, section, "stop.profitPun.description",  /*string  */ stop.profitPun.description + CRLF);

   return(!catch("SaveStatus(6)"));
}


/**
 * Return a string representation of active start/stop conditions to be stored by SaveStatus().
 *
 * @param  string sConditions - active and inactive conditions
 *
 * @param  string - active conditions
 */
string SaveStatus.ConditionsToStr(string sConditions) {
   sConditions = StrTrim(sConditions);
   if (!StringLen(sConditions) || sConditions=="-") return("");

   string values[], expr="", result="";
   int size = Explode(sConditions, "|", values, NULL);

   for (int i=0; i < size; i++) {
      expr = StrTrim(values[i]);
      if (!StringLen(expr))               continue;            // skip empty conditions
      if (StringGetChar(expr, 0) == '!')  continue;            // skip disabled conditions
      if (StrStartsWith(expr, "@profit")) continue;            // skip TP condition          // TODO: integrate input TakeProfit into StopConditions
      result = StringConcatenate(result, " | ", expr);
   }
   if (StringLen(result) > 0) {
      result = StrRight(result, -3);
   }
   return(result);
}


/**
 * Return a string representation of a history record to be stored by SaveStatus().
 *
 * @param  int index - index of the history record
 *
 * @return string - string representation or an empty string in case of errors
 */
string SaveStatus.HistoryToStr(int index) {
   // result: ticket,openType,lots,openTime,openPrice,openPriceVirt,closeTime,closePrice,closePriceVirt,slippage,swap,commission,grossProfit,grossProfitP,netProfit,netProfiP,virtProfitP

   int      ticket         = history[index][H_TICKET         ];
   int      openType       = history[index][H_OPENTYPE       ];
   double   lots           = history[index][H_LOTS           ];
   datetime openTime       = history[index][H_OPENTIME       ];
   double   openPrice      = history[index][H_OPENPRICE      ];
   double   openPriceVirt  = history[index][H_OPENPRICE_VIRT ];
   datetime closeTime      = history[index][H_CLOSETIME      ];
   double   closePrice     = history[index][H_CLOSEPRICE     ];
   double   closePriceVirt = history[index][H_CLOSEPRICE_VIRT];
   double   slippage       = history[index][H_SLIPPAGE       ];
   double   swap           = history[index][H_SWAP           ];
   double   commission     = history[index][H_COMMISSION     ];
   double   grossProfit    = history[index][H_GROSSPROFIT    ];
   double   grossProfitP   = history[index][H_GROSSPROFIT_P  ];
   double   netProfit      = history[index][H_NETPROFIT      ];
   double   netProfitP     = history[index][H_NETPROFIT_P    ];
   double   virtProfitP    = history[index][H_VIRTPROFIT_P   ];

   return(StringConcatenate(ticket, ",", openType, ",", DoubleToStr(lots, 2), ",", openTime, ",", DoubleToStr(openPrice, Digits), ",", DoubleToStr(openPriceVirt, Digits), ",", closeTime, ",", DoubleToStr(closePrice, Digits), ",", DoubleToStr(closePriceVirt, Digits), ",", DoubleToStr(slippage, Digits), ",", DoubleToStr(swap, 2), ",", DoubleToStr(commission, 2), ",", DoubleToStr(grossProfit, 2), ",", DoubleToStr(grossProfitP, Digits), ",", DoubleToStr(netProfit, 2), ",", NumberToStr(netProfitP, ".1+"), ",", DoubleToStr(virtProfitP, Digits)));
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
   string sAccount     = GetIniStringA(file, section, "Account", "");                                 // string Account = ICMarkets:12345678 (demo)
   string sSymbol      = GetIniStringA(file, section, "Symbol",  "");                                 // string Symbol  = EURUSD
   string sThisAccount = GetAccountCompanyId() +":"+ GetAccountNumber();
   if (!StrCompareI(StrLeftTo(sAccount, " ("), sThisAccount)) return(!catch("ReadStatus(4)  "+ instance.name +" account mis-match: "+ DoubleQuoteStr(sThisAccount) +" vs. "+ DoubleQuoteStr(sAccount) +" in status file "+ DoubleQuoteStr(file), ERR_INVALID_CONFIG_VALUE));
   if (!StrCompareI(sSymbol, Symbol()))                       return(!catch("ReadStatus(5)  "+ instance.name +" symbol mis-match: "+ Symbol() +" vs. "+ sSymbol +" in status file "+ DoubleQuoteStr(file), ERR_INVALID_CONFIG_VALUE));

   // [Inputs]
   section = "Inputs";
   string sInstanceID          = GetIniStringA(file, section, "Instance.ID",         "");             // string Instance.ID         = T123
   string sTradingMode         = GetIniStringA(file, section, "TradingMode",         "");             // string TradingMode         = regular
   int    iZigZagPeriods       = GetIniInt    (file, section, "ZigZag.Periods"         );             // int    ZigZag.Periods      = 40
   string sLots                = GetIniStringA(file, section, "Lots",                "");             // double Lots                = 0.1
   string sStartConditions     = GetIniStringA(file, section, "StartConditions",     "");             // string StartConditions     = @time(datetime|time)
   string sStopConditions      = GetIniStringA(file, section, "StopConditions",      "");             // string StopConditions      = @time(datetime|time)
   string sTakeProfit          = GetIniStringA(file, section, "TakeProfit",          "");             // double TakeProfit          = 3.0
   string sTakeProfitType      = GetIniStringA(file, section, "TakeProfit.Type",     "");             // string TakeProfit.Type     = off* | money | percent | pip
   string sShowProfitInPercent = GetIniStringA(file, section, "ShowProfitInPercent", "");             // bool   ShowProfitInPercent = 1
   string sEaRecorder          = GetIniStringA(file, section, "EA.Recorder",         "");             // string EA.Recorder         = 1,2,4

   if (!StrIsNumeric(sLots))       return(!catch("ReadStatus(6)  "+ instance.name +" invalid input parameter Lots "+ DoubleQuoteStr(sLots) +" in status file "+ DoubleQuoteStr(file), ERR_INVALID_FILE_FORMAT));
   if (!StrIsNumeric(sTakeProfit)) return(!catch("ReadStatus(7)  "+ instance.name +" invalid input parameter TakeProfit "+ DoubleQuoteStr(sTakeProfit) +" in status file "+ DoubleQuoteStr(file), ERR_INVALID_FILE_FORMAT));

   Instance.ID          = sInstanceID;
   TradingMode          = sTradingMode;
   Lots                 = StrToDouble(sLots);
   ZigZag.Periods       = iZigZagPeriods;
   StartConditions      = sStartConditions;
   StopConditions       = sStopConditions;
   TakeProfit           = StrToDouble(sTakeProfit);
   TakeProfit.Type      = sTakeProfitType;
   ShowProfitInPercent  = StrToBool(sShowProfitInPercent);
   EA.Recorder          = sEaRecorder;

   // [Runtime status]
   section = "Runtime status";
   // general
   tradingMode                 = GetIniInt    (file, section, "tradingMode");                         // int      tradingMode                 = 1

   // instance data
   instance.id                 = GetIniInt    (file, section, "instance.id"                );         // int      instance.id                 = 123
   instance.name               = GetIniStringA(file, section, "instance.name",           "");         // string   instance.name               = Z.123
   instance.created            = GetIniInt    (file, section, "instance.created"           );         // datetime instance.created            = 1624924800 (Mon, 2021.05.12 13:22:34)
   instance.isTest             = GetIniBool   (file, section, "instance.isTest"            );         // bool     instance.isTest             = 1
   instance.status             = GetIniInt    (file, section, "instance.status"            );         // int      instance.status             = 1 (waiting)
   instance.startEquity        = GetIniDouble (file, section, "instance.startEquity"       );         // double   instance.startEquity        = 1000.00

   instance.openNetProfit      = GetIniDouble (file, section, "instance.openNetProfit"     );         // double   instance.openNetProfit      = 23.45
   instance.closedNetProfit    = GetIniDouble (file, section, "instance.closedNetProfit"   );         // double   instance.closedNetProfit    = 45.67
   instance.totalNetProfit     = GetIniDouble (file, section, "instance.totalNetProfit"    );         // double   instance.totalNetProfit     = 123.45
   instance.maxNetProfit       = GetIniDouble (file, section, "instance.maxNetProfit"      );         // double   instance.maxNetProfit       = 23.45
   instance.maxNetDrawdown     = GetIniDouble (file, section, "instance.maxNetDrawdown"    );         // double   instance.maxNetDrawdown     = -11.23

   instance.openNetProfitP     = GetIniDouble (file, section, "instance.openNetProfitP"    );         // double   instance.openNetProfitP     = 0.12345
   instance.closedNetProfitP   = GetIniDouble (file, section, "instance.closedNetProfitP"  );         // double   instance.closedNetProfitP   = -0.23456
   instance.totalNetProfitP    = GetIniDouble (file, section, "instance.totalNetProfitP"   );         // double   instance.totalNetProfitP    = 1.23456
   instance.maxNetProfitP      = GetIniDouble (file, section, "instance.maxNetProfitP"     );         // double   instance.maxNetProfitP      = 0.12345
   instance.maxNetDrawdownP    = GetIniDouble (file, section, "instance.maxNetDrawdownP"   );         // double   instance.maxNetDrawdownP    = -0.23456

   instance.openGrossProfitP   = GetIniDouble (file, section, "instance.openGrossProfitP"  );         // double   instance.openGrossProfitP   = 0.12345
   instance.closedGrossProfitP = GetIniDouble (file, section, "instance.closedGrossProfitP");         // double   instance.closedGrossProfitP = -0.23456
   instance.totalGrossProfitP  = GetIniDouble (file, section, "instance.totalGrossProfitP" );         // double   instance.totalGrossProfitP  = 1.23456
   instance.maxGrossProfitP    = GetIniDouble (file, section, "instance.maxGrossProfitP"   );         // double   instance.maxGrossProfitP    = 0.12345
   instance.maxGrossDrawdownP  = GetIniDouble (file, section, "instance.maxGrossDrawdownP" );         // double   instance.maxGrossDrawdownP  = -0.23456

   instance.openVirtProfitP    = GetIniDouble (file, section, "instance.openVirtProfitP"   );         // double   instance.openVirtProfitP    = 0.12345
   instance.closedVirtProfitP  = GetIniDouble (file, section, "instance.closedVirtProfitP" );         // double   instance.closedVirtProfitP  = -0.23456
   instance.totalVirtProfitP   = GetIniDouble (file, section, "instance.totalVirtProfitP"  );         // double   instance.totalVirtProfitP   = 1.23456
   instance.maxVirtProfitP     = GetIniDouble (file, section, "instance.maxVirtProfitP"    );         // double   instance.maxVirtProfitP     = 0.12345
   instance.maxVirtDrawdownP   = GetIniDouble (file, section, "instance.maxVirtDrawdownP"  );         // double   instance.maxVirtDrawdownP   = -0.23456
   SS.InstanceName();

   // open order data
   open.ticket                 = GetIniInt    (file, section, "open.ticket"      );                   // int      open.ticket       = 123456
   open.type                   = GetIniInt    (file, section, "open.type"        );                   // int      open.type         = 1
   open.lots                   = GetIniDouble (file, section, "open.lots"        );                   // double   open.lots         = 0.01
   open.time                   = GetIniInt    (file, section, "open.time"        );                   // datetime open.time         = 1624924800 (Mon, 2021.05.12 13:22:34)
   open.price                  = GetIniDouble (file, section, "open.price"       );                   // double   open.price        = 1.24363
   open.priceVirt              = GetIniDouble (file, section, "open.priceVirt"   );                   // double   open.priceVirt    = 1.24363
   open.slippage               = GetIniDouble (file, section, "open.slippage"    );                   // double   open.slippage     = 0.00002
   open.swap                   = GetIniDouble (file, section, "open.swap"        );                   // double   open.swap         = -1.23
   open.commission             = GetIniDouble (file, section, "open.commission"  );                   // double   open.commission   = -5.50
   open.grossProfit            = GetIniDouble (file, section, "open.grossProfit" );                   // double   open.grossProfit  = 12.34
   open.grossProfitP           = GetIniDouble (file, section, "open.grossProfitP");                   // double   open.grossProfitP = 0.12345
   open.netProfit              = GetIniDouble (file, section, "open.netProfit"   );                   // double   open.netProfit    = 12.56
   open.netProfitP             = GetIniDouble (file, section, "open.netProfitP"  );                   // double   open.netProfitP   = 0.12345
   open.virtProfitP            = GetIniDouble (file, section, "open.virtProfitP" );                   // double   open.virtProfitP  = 0.12345

   // history data
   string sKeys[], sOrder="";
   double netProfit, netProfitP, grossProfitP, virtProfitP;
   int size = ReadStatus.HistoryKeys(file, section, sKeys); if (size < 0) return(false);

   for (int i=0; i < size; i++) {
      sOrder = GetIniStringA(file, section, sKeys[i], "");                                            // history.{i} = {data}
      int n = ReadStatus.RestoreHistory(sKeys[i], sOrder);
      if (n < 0) return(!catch("ReadStatus(8)  "+ instance.name +" invalid history record in status file "+ DoubleQuoteStr(file) + NL + sKeys[i] +"="+ sOrder, ERR_INVALID_FILE_FORMAT));

      netProfit    += history[n][H_NETPROFIT    ];
      netProfitP   += history[n][H_NETPROFIT_P  ];
      grossProfitP += history[n][H_GROSSPROFIT_P];
      virtProfitP  += history[n][H_VIRTPROFIT_P ];
   }

   // cross-check restored stats
   int precision = MathMax(Digits, 2) + 1;                     // required precision for fractional point values
   if (NE(netProfit,    instance.closedNetProfit, 2))          return(!catch("ReadStatus(9)  "+  instance.name +" sum(history[H_NETPROFIT]) != instance.closedNetProfit ("       + NumberToStr(netProfit, ".2+")               +" != "+ NumberToStr(instance.closedNetProfit, ".2+")               +")", ERR_ILLEGAL_STATE));
   if (NE(netProfitP,   instance.closedNetProfitP, precision)) return(!catch("ReadStatus(10)  "+ instance.name +" sum(history[H_NETPROFIT_P]) != instance.closedNetProfitP ("    + NumberToStr(netProfitP, "."+ Digits +"+")   +" != "+ NumberToStr(instance.closedNetProfitP, "."+ Digits +"+")   +")", ERR_ILLEGAL_STATE));
   if (NE(grossProfitP, instance.closedGrossProfitP, Digits))  return(!catch("ReadStatus(11)  "+ instance.name +" sum(history[H_GROSSPROFIT_P]) != instance.closedGrossProfitP ("+ NumberToStr(grossProfitP, "."+ Digits +"+") +" != "+ NumberToStr(instance.closedGrossProfitP, "."+ Digits +"+") +")", ERR_ILLEGAL_STATE));
   if (NE(virtProfitP,  instance.closedVirtProfitP,  Digits))  return(!catch("ReadStatus(12)  "+ instance.name +" sum(history[H_VIRTPROFIT_P]) != instance.closedVirtProfitP ("  + NumberToStr(virtProfitP, "."+ Digits +"+")  +" != "+ NumberToStr(instance.closedVirtProfitP, "."+ Digits +"+")  +")", ERR_ILLEGAL_STATE));

   // other
   start.time.condition       = GetIniBool   (file, section, "start.time.condition"      );           // bool     start.time.condition       = 1
   start.time.value           = GetIniInt    (file, section, "start.time.value"          );           // datetime start.time.value           = 1624924800
   start.time.isDaily         = GetIniBool   (file, section, "start.time.isDaily"        );           // bool     start.time.isDaily         = 0
   start.time.description     = GetIniStringA(file, section, "start.time.description", "");           // string   start.time.description     = text

   stop.time.condition        = GetIniBool   (file, section, "stop.time.condition"      );            // bool     stop.time.condition        = 1
   stop.time.value            = GetIniInt    (file, section, "stop.time.value"          );            // datetime stop.time.value            = 1624924800
   stop.time.isDaily          = GetIniBool   (file, section, "stop.time.isDaily"        );            // bool     stop.time.isDaily          = 0
   stop.time.description      = GetIniStringA(file, section, "stop.time.description", "");            // string   stop.time.description      = text

   stop.profitAbs.condition   = GetIniBool   (file, section, "stop.profitAbs.condition"        );     // bool     stop.profitAbs.condition   = 1
   stop.profitAbs.value       = GetIniDouble (file, section, "stop.profitAbs.value"            );     // double   stop.profitAbs.value       = 10.00
   stop.profitAbs.description = GetIniStringA(file, section, "stop.profitAbs.description",   "");     // string   stop.profitAbs.description = text
   stop.profitPct.condition   = GetIniBool   (file, section, "stop.profitPct.condition"        );     // bool     stop.profitPct.condition   = 0
   stop.profitPct.value       = GetIniDouble (file, section, "stop.profitPct.value"            );     // double   stop.profitPct.value       = 0
   stop.profitPct.absValue    = GetIniDouble (file, section, "stop.profitPct.absValue", INT_MAX);     // double   stop.profitPct.absValue    = 0.00
   stop.profitPct.description = GetIniStringA(file, section, "stop.profitPct.description",   "");     // string   stop.profitPct.description = text

   stop.profitPun.condition   = GetIniBool   (file, section, "stop.profitPun.condition"      );       // bool     stop.profitPun.condition   = 1
   stop.profitPun.type        = GetIniInt    (file, section, "stop.profitPun.type"           );       // int      stop.profitPun.type        = 4
   stop.profitPun.value       = GetIniDouble (file, section, "stop.profitPun.value"          );       // double   stop.profitPun.value       = 1.23456
   stop.profitPun.description = GetIniStringA(file, section, "stop.profitPun.description", "");       // string   stop.profitPun.description = text

   return(!catch("ReadStatus(13)"));
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
int ReadStatus.RestoreHistory(string key, string value) {
   if (IsLastError())                    return(EMPTY);
   if (!StrStartsWithI(key, "history.")) return(_EMPTY(catch("ReadStatus.RestoreHistory(1)  "+ instance.name +" illegal history record key "+ DoubleQuoteStr(key), ERR_INVALID_FILE_FORMAT)));

   // history.i=ticket,openType,lots,openTime,openPrice,openPriceVirt,closeTime,closePrice,closePriceVirt,slippage,swap,commission,grossProfit,grossProfitP,netProfit,netProfitP,virtProfitP
   string values[];
   string sId = StrRightFrom(key, ".", -1); if (!StrIsDigits(sId))  return(_EMPTY(catch("ReadStatus.RestoreHistory(2)  "+ instance.name +" illegal history record key "+ DoubleQuoteStr(key), ERR_INVALID_FILE_FORMAT)));
   if (Explode(value, ",", values, NULL) != ArrayRange(history, 1)) return(_EMPTY(catch("ReadStatus.RestoreHistory(3)  "+ instance.name +" illegal number of details ("+ ArraySize(values) +") in history record", ERR_INVALID_FILE_FORMAT)));

   int      ticket         = StrToInteger(values[H_TICKET         ]);
   int      openType       = StrToInteger(values[H_OPENTYPE       ]);
   double   lots           =  StrToDouble(values[H_LOTS           ]);
   datetime openTime       = StrToInteger(values[H_OPENTIME       ]);
   double   openPrice      =  StrToDouble(values[H_OPENPRICE      ]);
   double   openPriceVirt  =  StrToDouble(values[H_OPENPRICE_VIRT ]);
   datetime closeTime      = StrToInteger(values[H_CLOSETIME      ]);
   double   closePrice     =  StrToDouble(values[H_CLOSEPRICE     ]);
   double   closePriceVirt =  StrToDouble(values[H_CLOSEPRICE_VIRT]);
   double   slippage       =  StrToDouble(values[H_SLIPPAGE       ]);
   double   swap           =  StrToDouble(values[H_SWAP           ]);
   double   commission     =  StrToDouble(values[H_COMMISSION     ]);
   double   grossProfit    =  StrToDouble(values[H_GROSSPROFIT    ]);
   double   grossProfitP   =  StrToDouble(values[H_GROSSPROFIT_P  ]);
   double   netProfit      =  StrToDouble(values[H_NETPROFIT      ]);
   double   netProfitP     =  StrToDouble(values[H_NETPROFIT_P    ]);
   double   virtProfitP    =  StrToDouble(values[H_VIRTPROFIT_P   ]);

   return(History.AddRecord(ticket, openType, lots, openTime, openPrice, openPriceVirt, closeTime, closePrice, closePriceVirt, slippage, swap, commission, grossProfit, grossProfitP, netProfit, netProfitP, virtProfitP));
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
int History.AddRecord(int ticket, int openType, double lots, datetime openTime, double openPrice, double openPriceVirt, datetime closeTime, double closePrice, double closePriceVirt, double slippage, double swap, double commission, double grossProfit, double grossProfitP, double netProfit, double netProfitP, double virtProfitP) {
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
   history[i][H_TICKET         ] = ticket;
   history[i][H_OPENTYPE       ] = openType;
   history[i][H_LOTS           ] = lots;
   history[i][H_OPENTIME       ] = openTime;
   history[i][H_OPENPRICE      ] = openPrice;
   history[i][H_OPENPRICE_VIRT ] = openPriceVirt;
   history[i][H_CLOSETIME      ] = closeTime;
   history[i][H_CLOSEPRICE     ] = closePrice;
   history[i][H_CLOSEPRICE_VIRT] = closePriceVirt;
   history[i][H_SLIPPAGE       ] = slippage;
   history[i][H_SWAP           ] = swap;
   history[i][H_COMMISSION     ] = commission;
   history[i][H_GROSSPROFIT    ] = grossProfit;
   history[i][H_GROSSPROFIT_P  ] = grossProfitP;
   history[i][H_NETPROFIT      ] = netProfit;
   history[i][H_NETPROFIT_P    ] = netProfitP;
   history[i][H_VIRTPROFIT_P   ] = virtProfitP;

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

   int prevOpenTicket  = open.ticket;
   int prevHistorySize = ArrayRange(history, 0);

   // detect dangling open positions
   for (int i=OrdersTotal()-1; i >= 0; i--) {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if (IsMyOrder(instance.id)) {
         if (IsPendingOrderType(OrderType())) {
            logWarn("SynchronizeStatus(1)  "+ instance.name +" unsupported pending order found: #"+ OrderTicket() +", ignoring it...");
            continue;
         }
         if (!open.ticket) {
            logWarn("SynchronizeStatus(2)  "+ instance.name +" dangling open position found: #"+ OrderTicket() +", adding to instance...");
            open.ticket    = OrderTicket();
            open.type      = OrderType();
            open.time      = OrderOpenTime();
            open.price     = OrderOpenPrice();
            open.priceVirt = open.price;
            open.slippage  = NULL;                                   // open PnL numbers will auto-update in the following UpdateStatus() call
         }
         else if (OrderTicket() != open.ticket) {
            return(!catch("SynchronizeStatus(3)  "+ instance.name +" dangling open position found: #"+ OrderTicket(), ERR_RUNTIME_ERROR));
         }
      }
   }

   // update open position status
   if (open.ticket > 0) {
      if (!UpdateStatus()) return(false);
   }

   // detect orphaned closed positions
   for (i=OrdersHistoryTotal()-1; i >= 0; i--) {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) continue;
      if (IsPendingOrderType(OrderType()))              continue;    // skip deleted pending orders (atm not supported)

      if (IsMyOrder(instance.id)) {
         if (!IsLocalClosedPosition(OrderTicket())) {
            int      ticket       = OrderTicket();
            double   lots         = OrderLots();
            int      openType     = OrderType();
            datetime openTime     = OrderOpenTime();
            double   openPrice    = OrderOpenPrice();
            datetime closeTime    = OrderCloseTime();
            double   closePrice   = OrderClosePrice();
            double   slippage     = 0;
            double   swap         = NormalizeDouble(OrderSwap(), 2);
            double   commission   = OrderCommission();
            double   grossProfit  = OrderProfit();
            double   grossProfitP = ifDouble(!openType, closePrice-openPrice, openPrice-closePrice);
            double   netProfit    = grossProfit + swap + commission;
            double   netProfitP   = grossProfitP + MathDiv(swap + commission, PointValue(lots));

            logWarn("SynchronizeStatus(4)  "+ instance.name +" dangling closed position found: #"+ ticket +", adding to instance...");
            if (IsEmpty(History.AddRecord(ticket, lots, openType, openTime, openPrice, openPrice, closeTime, closePrice, closePrice, slippage, swap, commission, grossProfit, grossProfitP, netProfit, netProfitP, grossProfitP))) return(false);

            // update closed PL numbers
            instance.closedNetProfit    += netProfit;
            instance.closedNetProfitP   += netProfitP;
            instance.closedGrossProfitP += grossProfitP;
            instance.closedVirtProfitP  += grossProfitP;             // for orphaned positions same as grossProfitP
         }
      }
   }

   // recalculate total PL numbers
   instance.totalNetProfit = instance.openNetProfit + instance.closedNetProfit;
   instance.maxNetProfit   = MathMax(instance.maxNetProfit,   instance.totalNetProfit);
   instance.maxNetDrawdown = MathMin(instance.maxNetDrawdown, instance.totalNetProfit);

   instance.totalNetProfitP = instance.openNetProfitP + instance.closedNetProfitP;
   instance.maxNetProfitP   = MathMax(instance.maxNetProfitP,   instance.totalNetProfitP);
   instance.maxNetDrawdownP = MathMin(instance.maxNetDrawdownP, instance.totalNetProfitP);

   instance.totalGrossProfitP = instance.openGrossProfitP + instance.closedGrossProfitP;
   instance.maxGrossProfitP   = MathMax(instance.maxGrossProfitP,   instance.totalGrossProfitP);
   instance.maxGrossDrawdownP = MathMin(instance.maxGrossDrawdownP, instance.totalGrossProfitP);

   instance.totalVirtProfitP = instance.openVirtProfitP + instance.closedVirtProfitP;
   instance.maxVirtProfitP   = MathMax(instance.maxVirtProfitP,   instance.totalVirtProfitP);
   instance.maxVirtDrawdownP = MathMin(instance.maxVirtDrawdownP, instance.totalVirtProfitP);
   SS.All();

   if (open.ticket!=prevOpenTicket || ArrayRange(history, 0)!=prevHistorySize)
      return(SaveStatus());                                          // immediately save status if orders changed
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


/**
 * Whether the current instance was created in the tester. Considers that a finished test may have been loaded into an online
 * chart for visualization and further analysis.
 *
 * @return bool
 */
bool IsTestInstance() {
   return(instance.isTest || __isTesting);
}


// backed-up input parameters
string   prev.Instance.ID = "";
string   prev.TradingMode = "";
int      prev.ZigZag.Periods;
double   prev.Lots;
string   prev.StartConditions = "";
string   prev.StopConditions = "";
double   prev.TakeProfit;
string   prev.TakeProfit.Type = "";
bool     prev.ShowProfitInPercent;

// backed-up runtime variables affected by changing input parameters
int      prev.tradingMode;

int      prev.instance.id;
datetime prev.instance.created;
bool     prev.instance.isTest;
string   prev.instance.name = "";
int      prev.instance.status;

bool     prev.start.time.condition;
datetime prev.start.time.value;
bool     prev.start.time.isDaily;
string   prev.start.time.description = "";

bool     prev.stop.time.condition;
datetime prev.stop.time.value;
bool     prev.stop.time.isDaily;
string   prev.stop.time.description = "";
bool     prev.stop.profitAbs.condition;
double   prev.stop.profitAbs.value;
string   prev.stop.profitAbs.description = "";
bool     prev.stop.profitPct.condition;
double   prev.stop.profitPct.value;
double   prev.stop.profitPct.absValue;
string   prev.stop.profitPct.description = "";
bool     prev.stop.profitPun.condition;
int      prev.stop.profitPun.type;
double   prev.stop.profitPun.value;
string   prev.stop.profitPun.description = "";


/**
 * Programatically changed input parameters don't survive init cycles. Therefore inputs are backed-up in deinit() and can be
 * restored in init(). Called in onDeinitParameters() and onDeinitChartChange().
 */
void BackupInputs() {
   // backup input parameters, used for comparison in ValidateInputs()
   prev.Instance.ID         = StringConcatenate(Instance.ID, "");       // string inputs are references to internal C literals
   prev.TradingMode         = StringConcatenate(TradingMode, "");       // and must be copied to break the reference
   prev.ZigZag.Periods      = ZigZag.Periods;
   prev.Lots                = Lots;
   prev.StartConditions     = StringConcatenate(StartConditions, "");
   prev.StopConditions      = StringConcatenate(StopConditions, "");
   prev.TakeProfit          = TakeProfit;
   prev.TakeProfit.Type     = StringConcatenate(TakeProfit.Type, "");
   prev.ShowProfitInPercent = ShowProfitInPercent;

   // backup runtime variables affected by changing input parameters
   prev.tradingMode                = tradingMode;

   prev.instance.id                = instance.id;
   prev.instance.created           = instance.created;
   prev.instance.isTest            = instance.isTest;
   prev.instance.name              = instance.name;
   prev.instance.status            = instance.status;

   prev.start.time.condition       = start.time.condition;
   prev.start.time.value           = start.time.value;
   prev.start.time.isDaily         = start.time.isDaily;
   prev.start.time.description     = start.time.description;

   prev.stop.time.condition        = stop.time.condition;
   prev.stop.time.value            = stop.time.value;
   prev.stop.time.isDaily          = stop.time.isDaily;
   prev.stop.time.description      = stop.time.description;
   prev.stop.profitAbs.condition   = stop.profitAbs.condition;
   prev.stop.profitAbs.value       = stop.profitAbs.value;
   prev.stop.profitAbs.description = stop.profitAbs.description;
   prev.stop.profitPct.condition   = stop.profitPct.condition;
   prev.stop.profitPct.value       = stop.profitPct.value;
   prev.stop.profitPct.absValue    = stop.profitPct.absValue;
   prev.stop.profitPct.description = stop.profitPct.description;
   prev.stop.profitPun.condition    = stop.profitPun.condition;
   prev.stop.profitPun.type         = stop.profitPun.type;
   prev.stop.profitPun.value        = stop.profitPun.value;
   prev.stop.profitPun.description  = stop.profitPun.description;

   Recorder.BackupInputs();
}


/**
 * Restore backed-up input parameters and runtime variables. Called from onInitParameters() and onInitTimeframeChange().
 */
void RestoreInputs() {
   // restore input parameters
   Instance.ID          = prev.Instance.ID;
   TradingMode          = prev.TradingMode;
   ZigZag.Periods       = prev.ZigZag.Periods;
   Lots                 = prev.Lots;
   StartConditions      = prev.StartConditions;
   StopConditions       = prev.StopConditions;
   TakeProfit           = prev.TakeProfit;
   TakeProfit.Type      = prev.TakeProfit.Type;
   ShowProfitInPercent  = prev.ShowProfitInPercent;
   EA.Recorder          = prev.EA.Recorder;

   // restore runtime variables
   tradingMode                = prev.tradingMode;

   instance.id                = prev.instance.id;
   instance.created           = prev.instance.created;
   instance.isTest            = prev.instance.isTest;
   instance.name              = prev.instance.name;
   instance.status            = prev.instance.status;

   start.time.condition       = prev.start.time.condition;
   start.time.value           = prev.start.time.value;
   start.time.isDaily         = prev.start.time.isDaily;
   start.time.description     = prev.start.time.description;

   stop.time.condition        = prev.stop.time.condition;
   stop.time.value            = prev.stop.time.value;
   stop.time.isDaily          = prev.stop.time.isDaily;
   stop.time.description      = prev.stop.time.description;
   stop.profitAbs.condition   = prev.stop.profitAbs.condition;
   stop.profitAbs.value       = prev.stop.profitAbs.value;
   stop.profitAbs.description = prev.stop.profitAbs.description;
   stop.profitPct.condition   = prev.stop.profitPct.condition;
   stop.profitPct.value       = prev.stop.profitPct.value;
   stop.profitPct.absValue    = prev.stop.profitPct.absValue;
   stop.profitPct.description = prev.stop.profitPct.description;
   stop.profitPun.condition   = prev.stop.profitPun.condition;
   stop.profitPun.type        = prev.stop.profitPun.type;
   stop.profitPun.value       = prev.stop.profitPun.value;
   stop.profitPun.description = prev.stop.profitPun.description;

   Recorder.RestoreInputs();
}


/**
 * Validate and apply input parameter "Instance.ID".
 *
 * @return bool - whether an instance id value was successfully restored (the status file is not checked)
 */
bool ValidateInputs.ID() {
   bool errorFlag = true;

   if (!SetInstanceId(Instance.ID, errorFlag, "ValidateInputs.ID(1)")) {
      if (errorFlag) onInputError("ValidateInputs.ID(2)  invalid input parameter Instance.ID: \""+ Instance.ID +"\"");
      return(false);
   }
   return(true);
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
   bool isInitParameters   = (ProgramInitReason()==IR_PARAMETERS);   // whether we validate manual or programatic input
   bool isInitUser         = (ProgramInitReason()==IR_USER);
   bool isInitTemplate     = (ProgramInitReason()==IR_TEMPLATE);
   bool instanceWasStarted = (open.ticket || ArrayRange(history, 0));

   // Instance.ID
   if (isInitParameters) {                               // otherwise the id was validated in ValidateInputs.ID()
      string sValues[], sValue=StrTrim(Instance.ID);
      if (sValue == "") {                                // the id was deleted or not yet set, re-apply the internal id
         Instance.ID = prev.Instance.ID;
      }
      else if (sValue != prev.Instance.ID)               return(!onInputError("ValidateInputs(1)  "+ instance.name +" switching to another instance is not supported (unload the EA first)"));
   }

   // TradingMode: "regular* | virtual"
   sValue = TradingMode;
   if (Explode(sValue, "*", sValues, 2) > 1) {
      int size = Explode(sValues[0], "|", sValues, NULL);
      sValue = sValues[size-1];
   }
   sValue = StrToLower(StrTrim(sValue));
   if      (StrStartsWith("regular", sValue)) tradingMode = TRADINGMODE_REGULAR;
   else if (StrStartsWith("virtual", sValue)) tradingMode = TRADINGMODE_VIRTUAL;
   else                                                  return(!onInputError("ValidateInputs(2)  "+ instance.name +" invalid input parameter TradingMode: "+ DoubleQuoteStr(TradingMode)));
   if (isInitParameters && tradingMode!=prev.tradingMode) {
      if (instanceWasStarted)                            return(!onInputError("ValidateInputs(3)  "+ instance.name +" cannot change input parameter TradingMode of "+ StatusDescription(instance.status) +" instance"));
   }
   TradingMode = tradingModeDescriptions[tradingMode];

   // ZigZag.Periods
   if (isInitParameters && ZigZag.Periods!=prev.ZigZag.Periods) {
      if (instanceWasStarted)                            return(!onInputError("ValidateInputs(4)  "+ instance.name +" cannot change input parameter ZigZag.Periods of "+ StatusDescription(instance.status) +" instance"));
   }
   if (ZigZag.Periods < 2)                               return(!onInputError("ValidateInputs(5)  "+ instance.name +" invalid input parameter ZigZag.Periods: "+ ZigZag.Periods));

   // Lots
   if (isInitParameters && NE(Lots, prev.Lots)) {
      if (instanceWasStarted)                            return(!onInputError("ValidateInputs(6)  "+ instance.name +" cannot change input parameter Lots of "+ StatusDescription(instance.status) +" instance"));
   }
   if (LT(Lots, 0))                                      return(!onInputError("ValidateInputs(7)  "+ instance.name +" invalid input parameter Lots: "+ NumberToStr(Lots, ".1+") +" (too small)"));
   if (NE(Lots, NormalizeLots(Lots)))                    return(!onInputError("ValidateInputs(8)  "+ instance.name +" invalid input parameter Lots: "+ NumberToStr(Lots, ".1+") +" (not a multiple of MODE_LOTSTEP="+ NumberToStr(MarketInfo(Symbol(), MODE_LOTSTEP), ".+") +")"));

   // StartConditions: @time(datetime|time)
   if (!isInitParameters || StartConditions!=prev.StartConditions) {
      start.time.condition = false;                      // on initParameters conditions are re-enabled on change only

      string exprs[], expr="", key="";                   // split conditions
      int sizeOfExprs = Explode(StartConditions, "|", exprs, NULL), iValue, time, sizeOfElems;

      for (int i=0; i < sizeOfExprs; i++) {              // validate each expression
         expr = StrTrim(exprs[i]);
         if (!StringLen(expr))              continue;
         if (StringGetChar(expr, 0) == '!') continue;    // skip disabled conditions
         if (StringGetChar(expr, 0) != '@')              return(!onInputError("ValidateInputs(9)  "+ instance.name +" invalid input parameter StartConditions: "+ DoubleQuoteStr(StartConditions)));

         if (Explode(expr, "(", sValues, NULL) != 2)     return(!onInputError("ValidateInputs(10)  "+ instance.name +" invalid input parameter StartConditions: "+ DoubleQuoteStr(StartConditions)));
         if (!StrEndsWith(sValues[1], ")"))              return(!onInputError("ValidateInputs(11)  "+ instance.name +" invalid input parameter StartConditions: "+ DoubleQuoteStr(StartConditions)));
         key = StrTrim(sValues[0]);
         sValue = StrTrim(StrLeft(sValues[1], -1));
         if (!StringLen(sValue))                         return(!onInputError("ValidateInputs(12)  "+ instance.name +" invalid input parameter StartConditions: "+ DoubleQuoteStr(StartConditions)));

         if (key == "@time") {
            if (start.time.condition)                    return(!onInputError("ValidateInputs(13)  "+ instance.name +" invalid input parameter StartConditions: "+ DoubleQuoteStr(StartConditions) +" (multiple time conditions)"));
            int pt[];
            if (!ParseDateTime(sValue, NULL, pt))        return(!onInputError("ValidateInputs(14)  "+ instance.name +" invalid input parameter StartConditions: "+ DoubleQuoteStr(StartConditions)));
            datetime dtValue = DateTime2(pt, DATE_OF_ERA);
            start.time.condition   = true;
            start.time.value       = dtValue;
            start.time.isDaily     = !pt[PT_HAS_DATE];
            start.time.description = "time("+ TimeToStr(start.time.value, ifInt(start.time.isDaily, TIME_MINUTES, TIME_DATE|TIME_MINUTES)) +")";
         }
         else                                            return(!onInputError("ValidateInputs(15)  "+ instance.name +" invalid input parameter StartConditions: "+ DoubleQuoteStr(StartConditions)));
      }
   }

   // StopConditions: @time(datetime|time)
   if (!isInitParameters || StopConditions!=prev.StopConditions) {
      stop.time.condition = false;                       // on initParameters conditions are re-enabled on change only
      sizeOfExprs = Explode(StopConditions, "|", exprs, NULL);

      for (i=0; i < sizeOfExprs; i++) {                  // validate each expression
         expr = StrTrim(exprs[i]);
         if (!StringLen(expr))              continue;
         if (StringGetChar(expr, 0) == '!') continue;    // skip disabled conditions
         if (StringGetChar(expr, 0) != '@')              return(!onInputError("ValidateInputs(16)  "+ instance.name +" invalid input parameter StopConditions: "+ DoubleQuoteStr(StopConditions)));

         if (Explode(expr, "(", sValues, NULL) != 2)     return(!onInputError("ValidateInputs(17)  "+ instance.name +" invalid input parameter StopConditions: "+ DoubleQuoteStr(StopConditions)));
         if (!StrEndsWith(sValues[1], ")"))              return(!onInputError("ValidateInputs(18)  "+ instance.name +" invalid input parameter StopConditions: "+ DoubleQuoteStr(StopConditions)));
         key = StrTrim(sValues[0]);
         sValue = StrTrim(StrLeft(sValues[1], -1));
         if (!StringLen(sValue))                         return(!onInputError("ValidateInputs(19)  "+ instance.name +" invalid input parameter StopConditions: "+ DoubleQuoteStr(StopConditions)));

         if (key == "@time") {
            if (stop.time.condition)                     return(!onInputError("ValidateInputs(20)  "+ instance.name +" invalid input parameter StopConditions: "+ DoubleQuoteStr(StopConditions) +" (multiple time conditions)"));
            if (!ParseDateTime(sValue, NULL, pt))        return(!onInputError("ValidateInputs(21)  "+ instance.name +" invalid input parameter StopConditions: "+ DoubleQuoteStr(StopConditions)));
            dtValue = DateTime2(pt, DATE_OF_ERA);
            stop.time.condition   = true;
            stop.time.value       = dtValue;
            stop.time.isDaily     = !pt[PT_HAS_DATE];
            stop.time.description = "time("+ TimeToStr(stop.time.value, ifInt(stop.time.isDaily, TIME_MINUTES, TIME_DATE|TIME_MINUTES)) +")";
            if (start.time.condition && !start.time.isDaily && !stop.time.isDaily) {
               if (start.time.value >= stop.time.value)  return(!onInputError("ValidateInputs(22)  "+ instance.name +" invalid times in Start/StopConditions: "+ start.time.description +" / "+ stop.time.description +" (start time must preceed stop time)"));
            }
         }
         else                                            return(!onInputError("ValidateInputs(23)  "+ instance.name +" invalid input parameter StopConditions: "+ DoubleQuoteStr(StopConditions)));
      }
   }

   // TakeProfit (nothing to do)

   // TakeProfit.Type: "off* | money | percent | pip | quote-unit"
   sValue = StrToLower(TakeProfit.Type);
   if (Explode(sValue, "*", sValues, 2) > 1) {
      size = Explode(sValues[0], "|", sValues, NULL);
      sValue = sValues[size-1];
   }
   sValue = StrTrim(sValue);
   if      (StrStartsWith("off",        sValue)) stop.profitPun.type = NULL;
   else if (StrStartsWith("money",      sValue)) stop.profitPun.type = TP_TYPE_MONEY;
   else if (StrStartsWith("quote-unit", sValue)) stop.profitPun.type = TP_TYPE_PRICEUNIT;
   else if (StringLen(sValue) < 2)                       return(!onInputError("ValidateInputs(24)  "+ instance.name +" invalid parameter TakeProfit.Type: "+ DoubleQuoteStr(TakeProfit.Type)));
   else if (StrStartsWith("percent", sValue))    stop.profitPun.type = TP_TYPE_PERCENT;
   else if (StrStartsWith("pip",     sValue))    stop.profitPun.type = TP_TYPE_PIP;
   else                                                  return(!onInputError("ValidateInputs(25)  "+ instance.name +" invalid parameter TakeProfit.Type: "+ DoubleQuoteStr(TakeProfit.Type)));
   stop.profitAbs.condition   = false;
   stop.profitAbs.description = "";
   stop.profitPct.condition   = false;
   stop.profitPct.description = "";
   stop.profitPun.condition   = false;
   stop.profitPun.description = "";

   switch (stop.profitPun.type) {
      case TP_TYPE_MONEY:
         stop.profitAbs.condition   = true;
         stop.profitAbs.value       = NormalizeDouble(TakeProfit, 2);
         stop.profitAbs.description = "profit("+ DoubleToStr(stop.profitAbs.value, 2) +" "+ AccountCurrency() +")";
         break;

      case TP_TYPE_PERCENT:
         stop.profitPct.condition   = true;
         stop.profitPct.value       = TakeProfit;
         stop.profitPct.absValue    = INT_MAX;
         stop.profitPct.description = "profit("+ NumberToStr(stop.profitPct.value, ".+") +"%)";
         break;

      case TP_TYPE_PIP:
         stop.profitPun.condition   = true;
         stop.profitPun.value       = NormalizeDouble(TakeProfit*Pip, Digits);
         stop.profitPun.description = "profit("+ NumberToStr(TakeProfit, ".+") +" pip)";
         break;

      case TP_TYPE_PRICEUNIT:
         stop.profitPun.condition   = true;
         stop.profitPun.value       = NormalizeDouble(TakeProfit, Digits);
         stop.profitPun.description = "profit("+ NumberToStr(stop.profitPun.value, PriceFormat) +" point)";
         break;
   }
   TakeProfit.Type = tpTypeDescriptions[stop.profitPun.type];

   // EA.Recorder: on | off* | 1,2,3=1000,...
   if (!Recorder.ValidateInputs(IsTestInstance())) return(false);

   SS.All();
   return(!catch("ValidateInputs(26)"));
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
      return(logError(message, error));            // non-terminating error
   return(catch(message, error));                  // terminating error
}


/**
 * Store volatile runtime vars in chart and chart window (for template reload, terminal restart, recompilation etc).
 *
 * @return bool - success status
 */
bool StoreVolatileData() {
   string name = ProgramName();

   // input Instance.ID
   string value = ifString(instance.isTest, "T", "") + instance.id;
   Instance.ID = value;
   if (__isChart) {
      string key = name +".Instance.ID";
      SetWindowStringA(__ExecutionContext[EC.hChart], key, value);
      Chart.StoreString(key, value);
   }

   // status.activeMetric
   if (__isChart) {
      key = name +".status.activeMetric";
      SetWindowIntegerA(__ExecutionContext[EC.hChart], key, status.activeMetric);
      Chart.StoreInt(key, status.activeMetric);
   }
   return(!catch("StoreVolatileData(1)"));
}


/**
 * Restore volatile runtime data from chart or chart window (for template reload, terminal restart, recompilation etc).
 *
 * @return bool - whether an instance id was successfully restored
 */
bool RestoreVolatileData() {
   string name = ProgramName();

   // input Instance.ID
   while (true) {
      bool error = false;
      if (SetInstanceId(Instance.ID, error, "RestoreVolatileData(1)")) break;
      if (error) return(false);

      if (__isChart) {
         string key = name +".Instance.ID";
         string sValue = GetWindowStringA(__ExecutionContext[EC.hChart], key);
         if (SetInstanceId(sValue, error, "RestoreVolatileData(2)")) break;
         if (error) return(false);

         Chart.RestoreString(key, sValue, false);
         if (SetInstanceId(sValue, error, "RestoreVolatileData(3)")) break;
         return(false);
      }
   }

   // status.activeMetric
   if (__isChart) {
      key = name +".status.activeMetric";
      while (true) {
         int iValue = GetWindowIntegerA(__ExecutionContext[EC.hChart], key);
         if (iValue != 0) {
            if (iValue > 0 && iValue <= METRIC_TOTAL_UNITS_NET) {
               status.activeMetric = iValue;
               break;
            }
         }
         if (Chart.RestoreInt(key, iValue, false)) {
            if (iValue > 0 && iValue <= METRIC_TOTAL_UNITS_NET) {
               status.activeMetric = iValue;
               break;
            }
         }
         status.activeMetric = METRIC_TOTAL_MONEY_NET;               // reset to default value
         break;
      }
   }
   return(true);
}


/**
 * Remove stored volatile runtime data from chart and chart window.
 *
 * @return bool - success status
 */
bool RemoveVolatileData() {
   string name = ProgramName();

   // input Instance.ID
   if (__isChart) {
      string key = name +".Instance.ID";
      string sValue = RemoveWindowStringA(__ExecutionContext[EC.hChart], key);
      Chart.RestoreString(key, sValue, true);
   }

   // status.activeMetric
   if (__isChart) {
      key = name +".status.activeMetric";
      int iValue = RemoveWindowIntegerA(__ExecutionContext[EC.hChart], key);
      Chart.RestoreInt(key, iValue, true);
   }

   // event object for chart commands
   if (__isChart) {
      key = "EA.status";
      if (ObjectFind(key) != -1) ObjectDelete(key);
   }
   return(!catch("RemoveVolatileData(1)"));
}


/**
 * Parse and set the passed instance id value. Format: "[T]123"
 *
 * @param  _In_    string value  - instance id value
 * @param  _InOut_ bool   error  - in:  mute parse errors (TRUE) or trigger a fatal error (FALSE)
 *                                 out: whether parse errors occurred (stored in last_error)
 * @param  _In_    string caller - caller identification (for error messages)
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
   Instance.ID     = ifString(IsTestInstance(), "T", "") + instance.id;
   SS.InstanceName();
   return(true);
}


/**
 * Virtual replacement for OrderSendEx().
 *
 * @param  _In_  int    type       - trade operation type
 * @param  _In_  double lots       - trade volume in lots
 * @param  _In_  double stopLoss   - stoploss price
 * @param  _In_  double takeProfit - takeprofit price
 * @param  _In_  color  marker     - color of the chart marker to set
 * @param  _Out_ int    &oe[]      - order execution details (struct ORDER_EXECUTION)
 *
 * @return int - resulting ticket or NULL in case of errors
 */
int VirtualOrderSend(int type, double lots, double stopLoss, double takeProfit, color marker, int &oe[]) {
   if (ArraySize(oe) != ORDER_EXECUTION_intSize) ArrayResize(oe, ORDER_EXECUTION_intSize);
   ArrayInitialize(oe, 0);

   if (type!=OP_BUY && type!=OP_SELL) return(!catch("VirtualOrderSend(1)  invalid parameter type: "+ type, oe.setError(oe, ERR_INVALID_PARAMETER)));
   double openPrice = ifDouble(type, Bid, Ask);
   string comment = "ZigZag."+ instance.id;

   // generate a new ticket
   int ticket = open.ticket;
   int size = ArrayRange(history, 0);
   if (size > 0) ticket = Max(ticket, history[size-1][H_TICKET]);
   ticket++;

   // populate oe[]
   oe.setTicket    (oe, ticket);
   oe.setSymbol    (oe, Symbol());
   oe.setDigits    (oe, Digits);
   oe.setBid       (oe, Bid);
   oe.setAsk       (oe, Ask);
   oe.setType      (oe, type);
   oe.setLots      (oe, lots);
   oe.setOpenTime  (oe, Tick.time);
   oe.setOpenPrice (oe, openPrice);
   oe.setStopLoss  (oe, stopLoss);
   oe.setTakeProfit(oe, takeProfit);

   if (IsLogDebug()) {
      string sType  = OperationTypeDescription(type);
      string sLots  = NumberToStr(lots, ".+");
      string sPrice = NumberToStr(openPrice, PriceFormat);
      string sBid   = NumberToStr(Bid, PriceFormat);
      string sAsk   = NumberToStr(Ask, PriceFormat);
      logDebug("VirtualOrderSend(2)  "+ instance.name +" opened virtual #"+ ticket +" "+ sType +" "+ sLots +" "+ Symbol() +" \"."+ comment +"\" at "+ sPrice +" (market: "+ sBid +"/"+ sAsk +")");
   }
   if (__isChart && marker!=CLR_NONE) ChartMarker.OrderSent_B(ticket, Digits, marker, type, lots, Symbol(), Tick.time, openPrice, stopLoss, takeProfit, comment);
   if (!__isTesting)                  PlaySoundEx("OrderOk.wav");

   return(ticket);
}


/**
 * Virtual replacement for OrderCloseEx().
 *
 * @param  _In_  int    ticket - order ticket of the position to close
 * @param  _In_  double lots   - order size to close
 * @param  _In_  color  marker - color of the chart marker to set
 * @param  _Out_ int    &oe[]  - execution details (struct ORDER_EXECUTION)
 *
 * @return bool - success status
 */
bool VirtualOrderClose(int ticket, double lots, color marker, int &oe[]) {
   if (ArraySize(oe) != ORDER_EXECUTION_intSize) ArrayResize(oe, ORDER_EXECUTION_intSize);
   ArrayInitialize(oe, 0);

   if (ticket != open.ticket) return(!catch("VirtualOrderClose(1)  "+ instance.name +" parameter ticket/open.ticket mis-match: "+ ticket +"/"+ open.ticket, oe.setError(oe, ERR_INVALID_PARAMETER)));
   double closePrice = ifDouble(!open.type, Bid, Ask);
   double profit = NormalizeDouble(ifDouble(!open.type, closePrice-open.price, open.price-closePrice) * PointValue(lots), 2);

   // populate oe[]
   oe.setTicket    (oe, ticket);
   oe.setSymbol    (oe, Symbol());
   oe.setDigits    (oe, Digits);
   oe.setBid       (oe, Bid);
   oe.setAsk       (oe, Ask);
   oe.setType      (oe, open.type);
   oe.setLots      (oe, lots);
   oe.setOpenTime  (oe, open.time);
   oe.setOpenPrice (oe, open.price);
   oe.setCloseTime (oe, Tick.time);
   oe.setClosePrice(oe, closePrice);
   oe.setProfit    (oe, profit);

   if (IsLogDebug()) {
      string sType       = OperationTypeDescription(open.type);
      string sLots       = NumberToStr(lots, ".+");
      string sOpenPrice  = NumberToStr(open.price, PriceFormat);
      string sClosePrice = NumberToStr(closePrice, PriceFormat);
      string sBid        = NumberToStr(Bid, PriceFormat);
      string sAsk        = NumberToStr(Ask, PriceFormat);
      logDebug("VirtualOrderClose(2)  "+ instance.name +" closed virtual #"+ ticket +" "+ sType +" "+ sLots +" "+ Symbol() +" \"ZigZag."+ instance.id +"\" from "+ sOpenPrice +" at "+ sClosePrice +" (market: "+ sBid +"/"+ sAsk +")");
   }
   if (__isChart && marker!=CLR_NONE) ChartMarker.PositionClosed_B(ticket, Digits, marker, open.type, lots, Symbol(), open.time, open.price, Tick.time, closePrice);
   if (!__isTesting)                  PlaySoundEx("OrderOk.wav");

   return(true);
}


/**
 * ShowStatus: Update all string representations.
 */
void SS.All() {
   SS.InstanceName();
   SS.OpenLots();
   SS.ClosedTrades();
   SS.StartStopConditions();
   SS.TotalPL();
   SS.PLStats();
}


/**
 * ShowStatus: Update the string representation of the instance name.
 */
void SS.InstanceName() {
   instance.name = "Z."+ instance.id;

   switch (tradingMode) {
      case TRADINGMODE_REGULAR:
         break;
      case TRADINGMODE_VIRTUAL:
         instance.name = "V"+ instance.name;
         break;
   }
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
      if (instance.avgVirtProfitP == EMPTY_VALUE) CalculateTradeStats();
      sClosedTrades = size +" trades    avg: "+ DoubleToStr(instance.avgVirtProfitP * pMultiplier, pDigits) +" "+ pUnit;
   }
}


/**
 * ShowStatus: Update the string representation of the configured start/stop conditions.
 */
void SS.StartStopConditions() {
   if (__isChart) {
      // start conditions
      string sValue = "";
      if (start.time.description != "") {
         sValue = sValue + ifString(sValue=="", "", " | ") + ifString(start.time.condition, "@", "!") + start.time.description;
      }
      if (sValue == "") sStartConditions = "-";
      else              sStartConditions = sValue;

      // stop conditions
      sValue = "";
      if (stop.time.description != "") {
         sValue = sValue + ifString(sValue=="", "", " | ") + ifString(stop.time.condition, "@", "!") + stop.time.description;
      }
      if (stop.profitAbs.description != "") {
         sValue = sValue + ifString(sValue=="", "", " | ") + ifString(stop.profitAbs.condition, "@", "!") + stop.profitAbs.description;
      }
      if (stop.profitPct.description != "") {
         sValue = sValue + ifString(sValue=="", "", " | ") + ifString(stop.profitPct.condition, "@", "!") + stop.profitPct.description;
      }
      if (stop.profitPun.description != "") {
         sValue = sValue + ifString(sValue=="", "", " | ") + ifString(stop.profitPun.condition, "@", "!") + stop.profitPun.description;
      }
      if (sValue == "") sStopConditions = "-";
      else              sStopConditions = sValue;
   }
}


/**
 * ShowStatus: Update the string representation of "instance.totalNetProfit".
 */
void SS.TotalPL() {
   // not before a position was opened
   if (!open.ticket && !ArrayRange(history, 0)) sInstanceTotalNetPL = "-";
   else if (ShowProfitInPercent)                sInstanceTotalNetPL = NumberToStr(MathDiv(instance.totalNetProfit, instance.startEquity) * 100, "R+.2") +"%";
   else                                         sInstanceTotalNetPL = NumberToStr(instance.totalNetProfit, "R+.2");
}


/**
 * ShowStatus: Update the string representaton of the PL stats.
 */
void SS.PLStats() {
   // not before a position was opened
   if (!open.ticket && !ArrayRange(history, 0)) {
      sInstancePlStats = "";
   }
   else {
      string sInstanceMaxNetProfit="", sInstanceMaxNetDrawdown="";
      if (ShowProfitInPercent) {
         sInstanceMaxNetProfit   = NumberToStr(MathDiv(instance.maxNetProfit,   instance.startEquity) * 100, "R+.2") +"%";
         sInstanceMaxNetDrawdown = NumberToStr(MathDiv(instance.maxNetDrawdown, instance.startEquity) * 100, "R+.2") +"%";
      }
      else {
         sInstanceMaxNetProfit   = NumberToStr(instance.maxNetProfit, "+.2");
         sInstanceMaxNetDrawdown = NumberToStr(instance.maxNetDrawdown, "+.2");
      }
      sInstancePlStats = StringConcatenate("(", sInstanceMaxNetDrawdown, "/", sInstanceMaxNetProfit, ")");
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

   string text = StringConcatenate(sTradingModeStatus[tradingMode], ProgramName(), "    ", sStatus, sError, NL,
                                                                                                            NL,
                                  "Start:    ",  sStartConditions,                                          NL,
                                  "Stop:     ",  sStopConditions,                                           NL,
                                  "Open:    ",   sOpenLots,                                                 NL,
                                  "Closed:  ",   sClosedTrades,                                             NL,
                                  "Profit:    ", sInstanceTotalNetPL, "  ", sInstancePlStats,               NL
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
   return(StringConcatenate("Instance.ID=",          DoubleQuoteStr(Instance.ID),     ";", NL,
                            "TradingMode=",          DoubleQuoteStr(TradingMode),     ";", NL,
                            "ZigZag.Periods=",       ZigZag.Periods,                  ";", NL,
                            "Lots=",                 NumberToStr(Lots, ".1+"),        ";", NL,
                            "StartConditions=",      DoubleQuoteStr(StartConditions), ";", NL,
                            "StopConditions=",       DoubleQuoteStr(StopConditions),  ";", NL,
                            "TakeProfit=",           NumberToStr(TakeProfit, ".1+"),  ";", NL,
                            "TakeProfit.Type=",      DoubleQuoteStr(TakeProfit.Type), ";", NL,
                            "ShowProfitInPercent=",  BoolToStr(ShowProfitInPercent),  ";")
   );
}
