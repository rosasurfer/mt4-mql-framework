/**
 * ZigZag EA - a modified version of the system traded by the "Turtle Traders" of Richard Dennis
 *
 * The ZigZag indicator in this GitHub repository uses a Donchian channel for calculation. It can be used to implement the
 * Donchian channel system.
 *
 *
 * Input parameters
 * ----------------
 * • EA.Recorder: Metrics to record, @see https://github.com/rosasurfer/mt4-mql/blob/master/mql4/include/core/expert.mqh
 *
 *    "1":   Records a timeseries depicting theoretical PL with zero spread and no costs in quote units.                   OK
 *    "2":   Records a timeseries depicting PL after spread but before all other costs (gross) in quote units.             OK
 *    "3":   Records a timeseries depicting PL after all costs (net) in quote units.                                       OK
 *    "4":   Records a timeseries depicting PL after all costs (net) in account currency (like "on" except base value).    OK
 *
 *    "5":   Records a timeseries depicting theoretical daily PL with zero spread and no costs in quote units.
 *    "6":   Records a timeseries depicting daily PL after spread but before all other costs (gross) in quote units.
 *    "7":   Records a timeseries depicting daily PL after all costs (net) in quote units.
 *    "8":   Records a timeseries depicting daily PL after all costs (net) in account currency.
 *
 *    Timeseries in "quote units" are recorded in the best matching unit (pip for Forex, full quote points otherwise).
 *
 *
 * External control
 * ----------------
 * The EA can be controlled externally via execution of the following scripts (online and in tester):
 *
 *  • EA.Wait:  When a "wait" command is received a stopped EA starts waiting for new ZigZag signals. When the next signal
 *              arrives the EA starts trading. Nothing changes if the EA is already in status "waiting".
 *  • EA.Start: When a "start" command is received the EA immediately opens a position in direction of the current ZigZag
 *              trend and doesn't wait for the next signal. There are two sub-commands "start:long" and "start:short" to
 *              start the EA in a predefined direction. Nothing changes if a position is already open.
 *  • EA.Stop:  When a "stop" command is received the EA closes open positions and stops waiting for new ZigZag signals.
 *              Nothing changes if the EA is already stopped.
 *
 *
 *  @see  [Turtle Trading]  http://web.archive.org/web/20220417032905/https://vantagepointtrading.com/top-trader-richard-dennis-turtle-trading-strategy/
 *  @see  [Turtle Trading]  https://analyzingalpha.com/turtle-trading
 *
 *
 * TODO:
 *  - visible/audible alert at daily loss limit
 *  - visible alert at profit target
 *
 *  - time functions
 *      TimeCurrentEx()          check scripts/standalone-indicators in tester/offline charts in old/current terminals
 *      TimeLocalEx()            check scripts/standalone-indicators in tester/offline charts in old/current terminals
 *      TimeFXT()
 *      TimeGMT()                check scripts/standalone-indicators in tester/offline charts in old/current terminals
 *      TimeServer()             check scripts/standalone-indicators in tester/offline charts in old/current terminals
 *
 *      FxtToGmtTime
 *      FxtToLocalTime
 *      FxtToServerTime
 *
 *      GmtToFxtTime
 *      GmtToLocalTime     OK    finish unit tests
 *      GmtToServerTime
 *
 *      LocalToFxtTime
 *      LocalToGmtTime     OK    finish unit tests
 *      LocalToServerTime
 *
 *      ServerToFxtTime
 *      ServerToGmtTime
 *      ServerToLocalTime
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
 *  - on chart command
 *     NOTICE  BTCUSD,202  ChartInfos::rsfLib::AquireLock(6)  couldn't get lock on mutex "mutex.ChartInfos.command" after 1 sec, retrying...
 *     ...
 *     FATAL   BTCUSD,202  ChartInfos::rsfLib::AquireLock(5)  failed to get lock on mutex "mutex.ChartInfos.command" after 10 sec, giving up  [ERR_RUNTIME_ERROR]
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
 *     analyze PL differences DAX,M1 2022.01.04
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
 *     a chart profile per instrument
 *     rename groups/instruments/history descriptions
 *     ChartInfos: read/display symbol description as long name
 *
 *  - performance tracking
 *     realtime equity charts
 *     notifications for price feed outages
 *     daily metric variants
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
 *     FATAL  GBPJPY,M5  ZigZag::rsfHistory1::HistoryFile1.Open(12)->FileOpen("history/XTrade-Live/zGBPJP_581C30.hst", FILE_READ|FILE_WRITE) => -1 (zGBPJP_581C,M30)  [ERR_CANNOT_OPEN_FILE]
 *     ERROR  GBPJPY,M5  ZigZag::rsfHistory1::catch(1)  recursion: SendEmail(8)->FileOpen()  [ERR_CANNOT_OPEN_FILE]
 *            GBPJPY,M5  ZigZag::rsfHistory1::SendSMS(8)  SMS sent to +************: "FATAL:  GBPJPY,M5  ZigZag::rsfHistory1::HistoryFile1.Open(12)->FileOpen("history/XTrade-Live/zGBPJP_581C30.hst", FILE_READ|FILE_WRITE) => -1 (zGBPJP_581C,M30)  [ERR_CANNOT_OPEN_FILE] (12:59:52, ICM-DM-EUR)"
 *     btw: why not "ZigZag EA"?
 *
 *  - improve handling of network outages (price and/or trade connection)
 *  - "no connection" event, no price feed for 5 minutes, signals during this time are not detected => EA out of sync
 *
 *  - handle orders.acceptableSlippage dynamically (via framework config)
 *     https://www.mql5.com/en/forum/120795
 *     https://www.mql5.com/en/forum/289014#comment_9296322
 *     https://www.mql5.com/en/forum/146808#comment_3701979#  [ECN restriction removed since build 500]
 *     https://www.mql5.com/en/forum/146808#comment_3701981#  [Query execution mode in MQL]
 *  - merge inputs TakeProfit and StopConditions
 *  - add cache parameter to HistorySet.AddTick(), e.g. 30 sec.
 *
 *  - rewrite parameter stepping: remove commands from channel after processing
 *  - rewrite range bar generator
 *  - VPS: monitor and notify of incoming emails
 *  - CLI tools to rename/update/delete symbols
 *  - fix log messages in ValidateInputs (conditionally display the instance name)
 *  - move custom metric validation to EA
 *  - permanent spread logging to a separate logfile
 *  - move all history functionality to the Expander (fixes MQL max. open file limit of program=64/terminal=512)
 *  - pass input "EA.Recorder" to the Expander as a string
 *  - ChartInfos::CustomPosition() weekend configuration/timespans don't work
 *  - ChartInfos::CustomPosition() including/excluding a specific strategy is not supported
 *  - ChartInfos: don't recalculate unitsize on every tick (every few seconds is sufficient)
 *  - Superbars: ETH/RTH separation for Frankfurt session
 */
#include <stddefines.mqh>
int   __InitFlags[] = {INIT_PIPVALUE, INIT_BUFFERED_LOG};
int __DeinitFlags[];
int __virtualTicks  = 10000;                                // every 10 seconds to continue operation on a stalled data feed

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern string Instance.ID          = "";                    // instance to load from a status file, format "[T]123"
extern string TradingMode          = "regular* | virtual";  // may be shortened

extern int    ZigZag.Periods       = 30;
extern double Lots                 = 0.1;
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

#define H_TICKET                    0           // trade history indexes
#define H_LOTS                      1
#define H_OPENTYPE                  2
#define H_OPENTIME                  3
#define H_OPENBID                   4
#define H_OPENASK                   5
#define H_OPENPRICE                 6
#define H_CLOSETIME                 7
#define H_CLOSEBID                  8
#define H_CLOSEASK                  9
#define H_CLOSEPRICE               10
#define H_SLIPPAGE                 11
#define H_SWAP_M                   12           // M: in money (account currency)
#define H_COMMISSION_M             13           // U: in quote units
#define H_GROSSPROFIT_M            14
#define H_NETPROFIT_M              15

#define TP_TYPE_MONEY               1           // TakeProfit types
#define TP_TYPE_PERCENT             2
#define TP_TYPE_PIP                 3
#define TP_TYPE_QUOTEUNIT           4

#define METRIC_TOTAL_UNITS_ZERO     0           // cumulated PL metrics
#define METRIC_TOTAL_UNITS_GROSS    1
#define METRIC_TOTAL_UNITS_NET      2
#define METRIC_TOTAL_MONEY_NET      3

#define METRIC_DAILY_UNITS_ZERO     4           // daily PL metrics
#define METRIC_DAILY_UNITS_GROSS    5
#define METRIC_DAILY_UNITS_NET      6
#define METRIC_DAILY_MONEY_NET      7

// general
int      tradingMode;

// instance data
int      instance.id;                           // used for magic order numbers
datetime instance.created;
bool     instance.isTest;                       // whether the instance is a test
string   instance.name = "";
int      instance.status;
double   instance.startEquity;

double   instance.openZeroProfitU;              // theoretical PL with zero spread and zero transaction costs
double   instance.closedZeroProfitU;
double   instance.totalZeroProfitU;             // open + close

double   instance.openGrossProfitU;
double   instance.closedGrossProfitU;
double   instance.totalGrossProfitU;

double   instance.openNetProfitU;
double   instance.closedNetProfitU;
double   instance.totalNetProfitU;

double   instance.openNetProfit;
double   instance.closedNetProfit;
double   instance.totalNetProfit;
double   instance.maxNetProfit;                 // max. observed total net profit:   0...+n
double   instance.maxNetDrawdown;               // max. observed total net drawdown: -n...0

// order data
int      open.ticket;                           // one open position
int      open.type;
datetime open.time;
double   open.bid;
double   open.ask;
double   open.price;
double   open.stoploss;
double   open.slippage;
double   open.swap;
double   open.commission;
double   open.grossProfit;
double   open.grossProfitU;
double   open.netProfit;
double   open.netProfitU;
double   history[][16];                         // multiple closed positions

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

bool     stop.profitQu.condition;               // whether a takeprofit condition in quote units is active (full points or pip)
int      stop.profitQu.type;
double   stop.profitQu.value;
string   stop.profitQu.description = "";

// cache vars to speed-up ShowStatus()
string   sTradingModeStatus[] = {"", "", "Virtual "};
string   sLots                = "";
string   sStartConditions     = "";
string   sStopConditions      = "";
string   sInstanceTotalNetPL  = "";
string   sInstancePlStats     = "";

// other
string   tradingModeDescriptions[] = {"", "regular", "virtual"};
string   tpTypeDescriptions     [] = {"off", "money", "percent", "pip", "quote currency", "index points"};
int      orders.acceptableSlippage = 1;         // in MQL points

// debug settings, configurable via framework config, see afterInit()
bool     test.onReversalPause     = false;      // whether to pause a test after a ZigZag reversal
bool     test.onSessionBreakPause = false;      // whether to pause a test after StopInstance(SIGNAL_TIME)
bool     test.onStopPause         = false;      // whether to pause a test after a final StopInstance()
bool     test.reduceStatusWrites  = true;       // whether to reduce status file writes in tester

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
      string label = StringConcatenate("#", open.ticket, " ", orderTypes[open.type], " ", NumberToStr(Lots, ".+"), " at ", NumberToStr(open.price, PriceFormat));
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
 * Update recorder with current metric values.
 */
void RecordMetrics() {
   if (recordCustom) {
      if (recorder.enabled[METRIC_TOTAL_UNITS_ZERO ]) recorder.currValue[METRIC_TOTAL_UNITS_ZERO ] = instance.totalZeroProfitU;
      if (recorder.enabled[METRIC_TOTAL_UNITS_GROSS]) recorder.currValue[METRIC_TOTAL_UNITS_GROSS] = instance.totalGrossProfitU;
      if (recorder.enabled[METRIC_TOTAL_UNITS_NET  ]) recorder.currValue[METRIC_TOTAL_UNITS_NET  ] = instance.totalNetProfitU;
      if (recorder.enabled[METRIC_TOTAL_MONEY_NET  ]) recorder.currValue[METRIC_TOTAL_MONEY_NET  ] = instance.totalNetProfit;
   }
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

            if (IsVisualMode()) {                  // pause the tester according to the debug configuration
               if (test.onReversalPause) Tester.Pause("IsZigZagSignal(2)");
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


/**
 * Get a ZigZag channel value at the specified bar offset.
 *
 * @param  int bar  - bar offset
 * @param  int mode - one of: ZigZag.MODE_UPPER_BAND | ZigZag.MODE_LOWER_BAND
 *
 * @return double - channel value or NULL (0) in case of errors
 */
double GetZigZagChannel(int bar, int mode) {
   return(icZigZag(NULL, ZigZag.Periods, mode, bar));
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
 * Whether a start condition is satisfied for an instance.
 *
 * @param  _Out_ int &signal - variable receiving the signal identifier of a satisfied condition
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
      bool instanceWasStarted = (open.ticket || ArrayRange(history, 0));
      int loglevel = ifInt(instanceWasStarted, LOG_INFO, LOG_NOTICE);
      log("IsStartSignal(2)  "+ instance.name +" ZigZag "+ ifString(signal==SIGNAL_LONG, "long", "short") +" reversal (market: "+ NumberToStr(Bid, PriceFormat) +"/"+ NumberToStr(Ask, PriceFormat) +")", NULL, loglevel);
      return(true);
   }
   return(false);
}


/**
 * Whether a stop condition is satisfied for an instance.
 *
 * @param  _Out_ int &signal - variable receiving the identifier of a satisfied condition
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
            if (IsLogNotice()) logNotice("IsStopSignal(1)  "+ instance.name +" stop condition \"@"+ stop.profitAbs.description +"\" satisfied (market: "+ NumberToStr(Bid, PriceFormat) +"/"+ NumberToStr(Ask, PriceFormat) +")");
            return(true);
         }
      }

      // stop.profitPct: ----------------------------------------------------------------------------------------------------
      if (stop.profitPct.condition) {
         if (stop.profitPct.absValue == INT_MAX)
            stop.profitPct.absValue = stop.profitPct.AbsValue();

         if (instance.totalNetProfit >= stop.profitPct.absValue) {
            signal = SIGNAL_TAKEPROFIT;
            if (IsLogNotice()) logNotice("IsStopSignal(2)  "+ instance.name +" stop condition \"@"+ stop.profitPct.description +"\" satisfied (market: "+ NumberToStr(Bid, PriceFormat) +"/"+ NumberToStr(Ask, PriceFormat) +")");
            return(true);
         }
      }

      // stop.profitQu: -----------------------------------------------------------------------------------------------------
      if (stop.profitQu.condition) {
         if (instance.totalNetProfitU >= stop.profitQu.value) {
            signal = SIGNAL_TAKEPROFIT;
            if (IsLogNotice()) logNotice("IsStopSignal(3)  "+ instance.name +" stop condition \"@"+ stop.profitQu.description +"\" satisfied (market: "+ NumberToStr(Bid, PriceFormat) +"/"+ NumberToStr(Ask, PriceFormat) +")");
            return(true);
         }
      }
   }

   // stop.time: ------------------------------------------------------------------------------------------------------------
   if (stop.time.condition) {
      if (!IsTradingTime()) {
         signal = SIGNAL_TIME;
         if (IsLogInfo()) logInfo("IsStopSignal(4)  "+ instance.name +" stop condition \"@"+ stop.time.description +"\" satisfied (market: "+ NumberToStr(Bid, PriceFormat) +"/"+ NumberToStr(Ask, PriceFormat) +")");
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
   if (tradingMode == TRADINGMODE_VIRTUAL)                                 return(StartVirtualInstance(signal));

   if (IsLogInfo()) logInfo("StartInstance(3)  "+ instance.name +" starting ("+ SignalToStr(signal) +")");

   instance.status = STATUS_PROGRESSING;
   if (!instance.startEquity) instance.startEquity = NormalizeDouble(AccountEquity() - AccountCredit() + GetExternalAssets(), 2);

   // open a new position
   int      type        = ifInt(signal==SIGNAL_LONG, OP_BUY, OP_SELL);
   double   bid         = Bid;
   double   ask         = Ask;
   double   price       = NULL;
   double   stopLoss    = CalculateStopLoss(signal);
   double   takeProfit  = NULL;
   datetime expires     = NULL;
   string   comment     = "ZigZag."+ instance.id;
   int      magicNumber = CalculateMagicNumber();
   color    markerColor = ifInt(signal==SIGNAL_LONG, CLR_OPEN_LONG, CLR_OPEN_SHORT);
   int      oeFlags     = NULL, oe[];

   int ticket = OrderSendEx(Symbol(), type, Lots, price, orders.acceptableSlippage, stopLoss, takeProfit, comment, magicNumber, expires, markerColor, oeFlags, oe);
   if (!ticket) return(!SetLastError(oe.Error(oe)));

   // store the position data
   double currentBid = MarketInfo(Symbol(), MODE_BID), currentAsk = MarketInfo(Symbol(), MODE_ASK);
   open.ticket       = ticket;
   open.type         = type;
   open.bid          = bid;
   open.ask          = ask;
   open.time         = oe.OpenTime  (oe);
   open.price        = oe.OpenPrice (oe);
   open.stoploss     = oe.StopLoss  (oe);
   open.slippage     = oe.Slippage  (oe);
   open.swap         = oe.Swap      (oe);
   open.commission   = oe.Commission(oe);
   open.grossProfit  = oe.Profit    (oe);
   open.grossProfitU = ifDouble(!type, currentBid-open.price, open.price-currentAsk);
   open.netProfit    = open.grossProfit + open.swap + open.commission;
   open.netProfitU   = open.grossProfitU + (open.swap + open.commission)/QuoteUnitValue(Lots);

   // update PL numbers
   instance.openZeroProfitU  = ifDouble(!type, currentBid-open.bid, open.bid-currentBid);    // both directions use Bid prices
   instance.totalZeroProfitU = instance.openZeroProfitU + instance.closedZeroProfitU;

   instance.openGrossProfitU  = open.grossProfitU;
   instance.totalGrossProfitU = instance.openGrossProfitU + instance.closedGrossProfitU;

   instance.openNetProfitU  = open.netProfitU;
   instance.totalNetProfitU = instance.openNetProfitU + instance.closedNetProfitU;

   instance.openNetProfit  = open.netProfit;
   instance.totalNetProfit = instance.openNetProfit + instance.closedNetProfit;

   instance.maxNetProfit   = MathMax(instance.maxNetProfit,   instance.totalNetProfit);
   instance.maxNetDrawdown = MathMin(instance.maxNetDrawdown, instance.totalNetProfit);
   SS.TotalPL();
   SS.PLStats();

   // update start conditions
   if (start.time.condition) {
      if (!start.time.isDaily || !stop.time.condition) {                                     // see start/stop time variants
         start.time.condition = false;
      }
   }
   SS.StartStopConditions();

   if (IsLogInfo()) logInfo("StartInstance(5)  "+ instance.name +" instance started ("+ SignalToStr(signal) +")");
   return(SaveStatus());
}


/**
 * Start a waiting virtual instance.
 *
 * @param  int signal - trade signal causing the call
 *
 * @return bool - success status
 */
bool StartVirtualInstance(int signal) {
   if (IsLogInfo()) logInfo("StartVirtualInstance(1)  "+ instance.name +" starting ("+ SignalToStr(signal) +")");

   instance.status = STATUS_PROGRESSING;
   if (!instance.startEquity) instance.startEquity = NormalizeDouble(AccountEquity() - AccountCredit() + GetExternalAssets(), 2);

   // create a virtual position
   int type   = ifInt(signal==SIGNAL_LONG, OP_BUY, OP_SELL);
   int ticket = VirtualOrderSend(type);

   // store the position data
   open.ticket       = ticket;
   open.type         = type;
   open.bid          = Bid;
   open.ask          = Ask;
   open.time         = Tick.time;
   open.price        = ifDouble(type, Bid, Ask);
   open.stoploss     = 0;
   open.slippage     = 0;
   open.swap         = 0;
   open.commission   = 0;
   open.grossProfitU = Bid-Ask;
   open.grossProfit  = open.grossProfitU * QuoteUnitValue(Lots);
   open.netProfitU   = open.grossProfitU;
   open.netProfit    = open.grossProfit;

   // update PL numbers
   instance.openZeroProfitU  = 0;
   instance.totalZeroProfitU = instance.openZeroProfitU + instance.closedZeroProfitU;

   instance.openGrossProfitU  = open.grossProfitU;
   instance.totalGrossProfitU = instance.openGrossProfitU + instance.closedGrossProfitU;

   instance.openNetProfitU  = open.netProfitU;
   instance.totalNetProfitU = instance.openNetProfitU + instance.closedNetProfitU;

   instance.openNetProfit  = open.netProfit;
   instance.totalNetProfit = instance.openNetProfit + instance.closedNetProfit;

   instance.maxNetProfit   = MathMax(instance.maxNetProfit,   instance.totalNetProfit);
   instance.maxNetDrawdown = MathMin(instance.maxNetDrawdown, instance.totalNetProfit);
   SS.TotalPL();
   SS.PLStats();

   // update start conditions
   if (start.time.condition) {
      if (!start.time.isDaily || !stop.time.condition) {          // see start/stop time variants
         start.time.condition = false;
      }
   }
   SS.StartStopConditions();

   if (IsLogInfo()) logInfo("StartVirtualInstance(2)  "+ instance.name +" instance started ("+ SignalToStr(signal) +")");
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
   if (tradingMode == TRADINGMODE_VIRTUAL)          return(ReverseVirtualInstance(signal));

   double bid = Bid, ask = Ask;

   if (open.ticket > 0) {
      // continue in the same direction...
      if ((open.type==OP_BUY && signal==SIGNAL_LONG) || (open.type==OP_SELL && signal==SIGNAL_SHORT)) {
         logNotice("ReverseInstance(3)  "+ instance.name +" to "+ ifString(signal==SIGNAL_LONG, "long", "short") +": continuing with already open "+ ifString(signal==SIGNAL_LONG, "long", "short") +" position #"+ open.ticket);
         return(true);
      }
      // ...or close the open position
      int oe[], oeFlags=F_ERR_INVALID_TRADE_PARAMETERS | F_LOG_NOTICE;     // the SL may be triggered/position closed between UpdateStatus() and ReverseInstance()

      bool success = OrderCloseEx(open.ticket, NULL, orders.acceptableSlippage, CLR_NONE, oeFlags, oe);
      if (!success && oe.Error(oe)!=ERR_INVALID_TRADE_PARAMETERS) return(!SetLastError(oe.Error(oe)));

      if (!ArchiveClosedPosition(open.ticket, ifDouble(success, bid, 0), ifDouble(success, ask, 0), ifDouble(success, oe.Slippage(oe), 0))) return(false);
   }

   // open a new position
   int      type        = ifInt(signal==SIGNAL_LONG, OP_BUY, OP_SELL);
   double   price       = NULL;
   double   stopLoss    = CalculateStopLoss(signal);
   double   takeProfit  = NULL;
   datetime expires     = NULL;
   string   comment     = "ZigZag."+ instance.id;
   int      magicNumber = CalculateMagicNumber();
   color    markerColor = ifInt(type==OP_BUY, CLR_OPEN_LONG, CLR_OPEN_SHORT);

   if (!OrderSendEx(Symbol(), type, Lots, price, orders.acceptableSlippage, stopLoss, takeProfit, comment, magicNumber, expires, markerColor, oeFlags, oe)) return(!SetLastError(oe.Error(oe)));

   // store the new position data
   double currentBid = MarketInfo(Symbol(), MODE_BID), currentAsk = MarketInfo(Symbol(), MODE_ASK);
   open.bid          = bid;
   open.ask          = ask;
   open.ticket       = oe.Ticket    (oe);
   open.type         = oe.Type      (oe);
   open.time         = oe.OpenTime  (oe);
   open.price        = oe.OpenPrice (oe);
   open.stoploss     = oe.StopLoss  (oe);
   open.slippage     = oe.Slippage  (oe);
   open.swap         = oe.Swap      (oe);
   open.commission   = oe.Commission(oe);
   open.grossProfit  = oe.Profit    (oe);
   open.grossProfitU = ifDouble(!type, currentBid-open.price, open.price-currentAsk);
   open.netProfit    = open.grossProfit + open.swap + open.commission;
   open.netProfitU   = open.grossProfitU + (open.swap + open.commission)/QuoteUnitValue(Lots);

   // update PL numbers
   instance.openZeroProfitU  = ifDouble(!type, currentBid-open.bid, open.bid-currentBid); // both directions use Bid prices
   instance.totalZeroProfitU = instance.openZeroProfitU + instance.closedZeroProfitU;

   instance.openGrossProfitU  = open.grossProfitU;
   instance.totalGrossProfitU = instance.openGrossProfitU + instance.closedGrossProfitU;

   instance.openNetProfitU  = open.netProfitU;
   instance.totalNetProfitU = instance.openNetProfitU + instance.closedNetProfitU;

   instance.openNetProfit  = open.netProfit;
   instance.totalNetProfit = instance.openNetProfit + instance.closedNetProfit;

   instance.maxNetProfit   = MathMax(instance.maxNetProfit,   instance.totalNetProfit);
   instance.maxNetDrawdown = MathMin(instance.maxNetDrawdown, instance.totalNetProfit);
   SS.TotalPL();
   SS.PLStats();

   return(SaveStatus());
}


/**
 * Reverse a progressing virtual instance.
 *
 * @param  int signal - trade signal causing the call
 *
 * @return bool - success status
 */
bool ReverseVirtualInstance(int signal) {
   if (open.ticket > 0) {
      // continue in the same direction...
      if ((open.type==OP_BUY && signal==SIGNAL_LONG) || (open.type==OP_SELL && signal==SIGNAL_SHORT)) {
         logWarn("ReverseVirtualInstance(1)  "+ instance.name +" to "+ ifString(signal==SIGNAL_LONG, "long", "short") +": continuing with already open virtual "+ ifString(signal==SIGNAL_LONG, "long", "short") +" position");
         return(true);
      }
      // ...or close and archive the open position
      VirtualOrderClose(open.ticket);
      ArchiveClosedVirtualPosition(open.ticket);
   }

   // create a virtual position
   int type   = ifInt(signal==SIGNAL_LONG, OP_BUY, OP_SELL);
   int ticket = VirtualOrderSend(type);

   // store the position data
   open.ticket       = ticket;
   open.type         = type;
   open.bid          = Bid;
   open.ask          = Ask;
   open.time         = Tick.time;
   open.price        = ifDouble(type, Bid, Ask);
   open.stoploss     = 0;
   open.slippage     = 0;
   open.swap         = 0;
   open.commission   = 0;
   open.grossProfitU = Bid-Ask;
   open.grossProfit  = open.grossProfitU * QuoteUnitValue(Lots);
   open.netProfitU   = open.grossProfitU;
   open.netProfit    = open.grossProfit;

   // update PL numbers
   instance.openZeroProfitU  = 0;
   instance.totalZeroProfitU = instance.openZeroProfitU + instance.closedZeroProfitU;

   instance.openGrossProfitU  = open.grossProfitU;
   instance.totalGrossProfitU = instance.openGrossProfitU + instance.closedGrossProfitU;

   instance.openNetProfitU  = open.netProfitU;
   instance.totalNetProfitU = instance.openNetProfitU + instance.closedNetProfitU;

   instance.openNetProfit   = open.netProfit;
   instance.totalNetProfit  = instance.openNetProfit + instance.closedNetProfit;

   instance.maxNetProfit    = MathMax(instance.maxNetProfit,   instance.totalNetProfit);
   instance.maxNetDrawdown  = MathMin(instance.maxNetDrawdown, instance.totalNetProfit);
   SS.TotalPL();
   SS.PLStats();
   return(SaveStatus());
}


/**
 * Add trade details of the specified closed ticket to the local history and reset open position data.
 *
 * @param int    ticket   - closed ticket
 * @param double bid      - Bid price before the position was closed
 * @param double ask      - Ask price before the position was closed
 * @param double slippage - close slippage
 *
 * @return bool - success status
 */
bool ArchiveClosedPosition(int ticket, double bid, double ask, double slippage) {
   if (last_error != NULL)                    return(false);
   if (instance.status != STATUS_PROGRESSING) return(!catch("ArchiveClosedPosition(1)  "+ instance.name +" cannot archive position of "+ StatusDescription(instance.status) +" instance", ERR_ILLEGAL_STATE));

   SelectTicket(ticket, "ArchiveClosedPosition(2)", /*push=*/true);

   // update now closed position data
   open.swap        = OrderSwap();
   open.commission  = OrderCommission();
   open.grossProfit = OrderProfit();
   open.netProfit   = open.grossProfit + open.swap + open.commission;

   if (!OrderLots()) {                 // it may be a hedge counterpart with Lots=0.0 (#465291275 Buy 0.0 US500 at 4'522.30, closed...
      open.grossProfitU = NULL;        // ...at 4'522.30, commission=0.00, swap=0.00, profit=0.00, magicNumber=448817408, comment="close hedge by #465308924")
      open.netProfitU   = NULL;
   }
   else {
      open.grossProfitU = ifDouble(!OrderType(), OrderClosePrice()-OrderOpenPrice(), OrderOpenPrice()-OrderClosePrice());
      open.netProfitU   = open.grossProfitU + (open.swap + open.commission)/QuoteUnitValue(OrderLots());
   }

   // update history
   int i = ArrayRange(history, 0);
   ArrayResize(history, i+1);
   history[i][H_TICKET       ] = ticket;
   history[i][H_LOTS         ] = OrderLots();
   history[i][H_OPENTYPE     ] = OrderType();
   history[i][H_OPENTIME     ] = OrderOpenTime();
   history[i][H_OPENBID      ] = open.bid;
   history[i][H_OPENASK      ] = open.ask;
   history[i][H_OPENPRICE    ] = OrderOpenPrice();
   history[i][H_CLOSETIME    ] = OrderCloseTime();
   history[i][H_CLOSEBID     ] = doubleOr(bid, OrderClosePrice());
   history[i][H_CLOSEASK     ] = doubleOr(ask, OrderClosePrice());
   history[i][H_CLOSEPRICE   ] = OrderClosePrice();
   history[i][H_SLIPPAGE     ] = open.slippage + slippage;
   history[i][H_SWAP_M       ] = open.swap;
   history[i][H_COMMISSION_M ] = open.commission;
   history[i][H_GROSSPROFIT_M] = open.grossProfit;
   history[i][H_NETPROFIT_M  ] = open.netProfit;
   OrderPop("ArchiveClosedPosition(3)");

   // update PL numbers
   instance.openZeroProfitU    = 0;                                           // both directions use Bid prices
   instance.closedZeroProfitU += ifDouble(!open.type, history[i][H_CLOSEBID]-open.bid, open.bid-history[i][H_CLOSEBID]);
   instance.totalZeroProfitU   = instance.closedZeroProfitU;

   instance.openGrossProfitU    = 0;
   instance.closedGrossProfitU += open.grossProfitU;
   instance.totalGrossProfitU   = instance.closedGrossProfitU;

   instance.openNetProfitU    = 0;
   instance.closedNetProfitU += open.netProfitU;
   instance.totalNetProfitU   = instance.closedNetProfitU;

   instance.openNetProfit    = 0;
   instance.closedNetProfit += open.netProfit;
   instance.totalNetProfit   = instance.closedNetProfit;

   // reset open position data
   open.ticket       = NULL;
   open.type         = NULL;
   open.time         = NULL;
   open.bid          = NULL;
   open.ask          = NULL;
   open.price        = NULL;
   open.stoploss     = NULL;
   open.slippage     = NULL;
   open.swap         = NULL;
   open.commission   = NULL;
   open.grossProfit  = NULL;
   open.grossProfitU = NULL;
   open.netProfit    = NULL;
   open.netProfitU   = NULL;
   return(!catch("ArchiveClosedPosition(4)"));
}


/**
 * Add trade details of the specified virtual ticket to the local history and reset open position data.
 *
 * @param int ticket - closed ticket
 *
 * @return bool - success status
 */
bool ArchiveClosedVirtualPosition(int ticket) {
   if (last_error != NULL)                    return(false);
   if (instance.status != STATUS_PROGRESSING) return(!catch("ArchiveClosedVirtualPosition(1)  "+ instance.name +" cannot archive virtual position of "+ StatusDescription(instance.status) +" instance", ERR_ILLEGAL_STATE));
   if (ticket != open.ticket)                 return(!catch("ArchiveClosedVirtualPosition(2)  "+ instance.name +" ticket/open.ticket mis-match: "+ ticket +"/"+ open.ticket, ERR_ILLEGAL_STATE));

   // update now closed position data
   open.swap         = 0;
   open.commission   = 0;
   open.grossProfitU = ifDouble(!open.type, Bid-open.price, open.price-Ask);
   open.grossProfit  = open.grossProfitU * QuoteUnitValue(Lots);
   open.netProfitU   = open.grossProfitU;
   open.netProfit    = open.grossProfit;

   // update history
   int i = ArrayRange(history, 0);
   ArrayResize(history, i+1);
   history[i][H_TICKET       ] = ticket;
   history[i][H_LOTS         ] = Lots;
   history[i][H_OPENTYPE     ] = open.type;
   history[i][H_OPENTIME     ] = open.time;
   history[i][H_OPENBID      ] = open.bid;
   history[i][H_OPENASK      ] = open.ask;
   history[i][H_OPENPRICE    ] = open.price;
   history[i][H_CLOSETIME    ] = Tick.time;
   history[i][H_CLOSEBID     ] = Bid;
   history[i][H_CLOSEASK     ] = Ask;
   history[i][H_CLOSEPRICE   ] = ifDouble(!open.type, Bid, Ask);
   history[i][H_SLIPPAGE     ] = open.slippage;
   history[i][H_SWAP_M       ] = open.swap;
   history[i][H_COMMISSION_M ] = open.commission;
   history[i][H_GROSSPROFIT_M] = open.grossProfit;
   history[i][H_NETPROFIT_M  ] = open.netProfit;

   // update PL numbers
   instance.openZeroProfitU    = 0;                                           // both directions use Bid prices
   instance.closedZeroProfitU += ifDouble(!open.type, history[i][H_CLOSEBID]-open.bid, open.bid-history[i][H_CLOSEBID]);
   instance.totalZeroProfitU   = instance.closedZeroProfitU;

   instance.openGrossProfitU    = 0;
   instance.closedGrossProfitU += open.grossProfitU;
   instance.totalGrossProfitU   = instance.closedGrossProfitU;

   instance.openNetProfitU    = 0;
   instance.closedNetProfitU += open.netProfitU;
   instance.totalNetProfitU   = instance.closedNetProfitU;

   instance.openNetProfit    = 0;
   instance.closedNetProfit += open.netProfit;
   instance.totalNetProfit   = instance.closedNetProfit;

   // reset open position data
   open.ticket       = NULL;
   open.type         = NULL;
   open.time         = NULL;
   open.bid          = NULL;
   open.ask          = NULL;
   open.price        = NULL;
   open.slippage     = NULL;
   open.swap         = NULL;
   open.commission   = NULL;
   open.grossProfit  = NULL;
   open.grossProfitU = NULL;
   open.netProfit    = NULL;
   open.netProfitU   = NULL;

   return(!catch("ArchiveClosedVirtualPosition(3)"));
}


/**
 * Calculate a desaster stop for a position. The stop is put behind the Donchian channel band opposite to the trade direction.
 *
 * @param  int direction - trade direction
 *
 * @return double - SL value or NULL (0) in case of errors
 */
double CalculateStopLoss(int direction) {
   if (last_error != NULL)                                return(NULL);
   if (direction!=SIGNAL_LONG && direction!=SIGNAL_SHORT) return(!catch("CalculateStopLoss(1)  "+ instance.name +" invalid parameter direction: "+ direction, ERR_INVALID_PARAMETER));

   double channelBand = GetZigZagChannel(0, ifInt(direction==SIGNAL_LONG, ZigZag.MODE_LOWER_BAND, ZigZag.MODE_UPPER_BAND));
   if (!channelBand) return(NULL);

   // calculate a min. distance from the channel
   double dist1    = MathAbs(Bid-channelBand) * 0.2;        // that's min. 20% of the current price distance...
   double dist2    = 4 * (Ask-Bid);                         // and min. 4 times the current spread
   double minDist  = MathMax(dist1, dist2);

   // move stoploss this min. distance away
   if (direction == SIGNAL_LONG) double stoploss = channelBand - minDist;
   else                                 stoploss = channelBand + minDist;

   return(NormalizeDouble(stoploss, Digits));
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
   if (tradingMode == TRADINGMODE_VIRTUAL)                                     return(StopVirtualInstance(signal));

   // close an open position
   if (instance.status == STATUS_PROGRESSING) {
      if (open.ticket > 0) {
         if (IsLogInfo()) logInfo("StopInstance(2)  "+ instance.name +" stopping ("+ SignalToStr(signal) +")");

         double bid = Bid, ask = Ask;
         int oeFlags, oe[];

         if (!OrderCloseEx(open.ticket, NULL, orders.acceptableSlippage, CLR_NONE, oeFlags, oe)) return(!SetLastError(oe.Error(oe)));
         if (!ArchiveClosedPosition(open.ticket, bid, ask, oe.Slippage(oe)))                     return(false);

         instance.maxNetProfit   = MathMax(instance.maxNetProfit,   instance.totalNetProfit);
         instance.maxNetDrawdown = MathMin(instance.maxNetDrawdown, instance.totalNetProfit);
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
         stop.profitQu.condition  = false;
         instance.status          = STATUS_STOPPED;
         break;

      case NULL:                                            // explicit stop (manual) or end of test
         instance.status = STATUS_STOPPED;
         break;

      default: return(!catch("StopInstance(4)  "+ instance.name +" invalid parameter signal: "+ signal, ERR_INVALID_PARAMETER));
   }
   SS.StartStopConditions();

   if (IsLogInfo()) logInfo("StopInstance(5)  "+ instance.name +" "+ ifString(__isTesting && !signal, "test ", "") +"instance stopped"+ ifString(!signal, "", " ("+ SignalToStr(signal) +")") +", profit: "+ sInstanceTotalNetPL +" "+ sInstancePlStats);
   SaveStatus();

   // pause/stop the tester according to the debug configuration
   if (__isTesting) {
      if      (!IsVisualMode())       { if (instance.status == STATUS_STOPPED) Tester.Stop ("StopInstance(6)"); }
      else if (signal == SIGNAL_TIME) { if (test.onSessionBreakPause)          Tester.Pause("StopInstance(7)"); }
      else                            { if (test.onStopPause)                  Tester.Pause("StopInstance(8)"); }
   }
   return(!catch("StopInstance(9)"));
}


/**
 * Stop a waiting or progressing virtual instance. Close open positions (if any).
 *
 * @param  int signal - signal which triggered the stop condition or NULL on explicit (i.e. manual) stop
 *
 * @return bool - success status
 */
bool StopVirtualInstance(int signal) {
   // close open positions
   if (instance.status == STATUS_PROGRESSING) {
      if (open.ticket > 0) {
         VirtualOrderClose(open.ticket);
         ArchiveClosedVirtualPosition(open.ticket);

         instance.maxNetProfit   = MathMax(instance.maxNetProfit,   instance.totalNetProfit);
         instance.maxNetDrawdown = MathMin(instance.maxNetDrawdown, instance.totalNetProfit);
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
         stop.profitQu.condition  = false;
         instance.status          = STATUS_STOPPED;
         break;

      case NULL:                                            // explicit stop (manual) or end of test
         instance.status = STATUS_STOPPED;
         break;

      default: return(!catch("StopVirtualInstance(1)  "+ instance.name +" invalid parameter signal: "+ signal, ERR_INVALID_PARAMETER));
   }
   SS.StartStopConditions();

   if (IsLogInfo()) logInfo("StopVirtualInstance(2)  "+ instance.name +" "+ ifString(__isTesting && !signal, "test ", "") +"instance stopped"+ ifString(!signal, "", " ("+ SignalToStr(signal) +")") +", profit: "+ sInstanceTotalNetPL +" "+ sInstancePlStats);
   SaveStatus();

   // pause/stop the tester according to the debug configuration
   if (__isTesting) {
      if      (!IsVisualMode())       { if (instance.status == STATUS_STOPPED) Tester.Stop ("StopInstance(6)"); }
      else if (signal == SIGNAL_TIME) { if (test.onSessionBreakPause)          Tester.Pause("StopInstance(7)"); }
      else                            { if (test.onStopPause)                  Tester.Pause("StopInstance(8)"); }
   }
   return(!catch("StopVirtualInstance(3)"));
}


/**
 * Update order status and PL.
 *
 * @return bool - success status
 */
bool UpdateStatus() {
   if (last_error != NULL)                    return(false);
   if (instance.status != STATUS_PROGRESSING) return(!catch("UpdateStatus(1)  "+ instance.name +" cannot update order status of "+ StatusDescription(instance.status) +" instance", ERR_ILLEGAL_STATE));
   if (tradingMode == TRADINGMODE_VIRTUAL)    return(UpdateVirtualStatus());
   int error;

   if (open.ticket > 0) {
      if (!SelectTicket(open.ticket, "UpdateStatus(2)")) return(false);
      bool isOpen = !OrderCloseTime();

      open.swap        = OrderSwap();
      open.commission  = OrderCommission();
      open.grossProfit = OrderProfit();
      open.netProfit   = open.grossProfit + open.swap + open.commission;

      if (!OrderLots()) {                 // if already closed it may be a hedge counterpart with Lots=0.0 (#465291275 Buy 0.0 US500 at 4'522.30, closed...
         open.grossProfitU = 0;           // ...at 4'522.30, commission=0.00, swap=0.00, profit=0.00, magicNumber=448817408, comment="close hedge by #465308924")
         open.netProfitU   = 0;
      }
      else {
         open.grossProfitU = ifDouble(!open.type, Bid-open.price, open.price-Ask);
         open.netProfitU   = open.grossProfitU + (open.swap + open.commission)/QuoteUnitValue(OrderLots());
      }

      if (isOpen) {
         instance.openZeroProfitU  = ifDouble(!open.type, Bid-open.bid, open.bid-Bid);    // both directions use Bid prices
         instance.openGrossProfitU = open.grossProfitU;
         instance.openNetProfitU   = open.netProfitU;
         instance.openNetProfit    = open.netProfit;
      }
      else {
         if (IsError(onPositionClose("UpdateStatus(3)  "+ instance.name +" "+ UpdateStatus.PositionCloseMsg(error), error))) return(false);
         if (!ArchiveClosedPosition(open.ticket, NULL, NULL, NULL)) return(false);
      }
      instance.totalZeroProfitU  = instance.openZeroProfitU  + instance.closedZeroProfitU;
      instance.totalGrossProfitU = instance.openGrossProfitU + instance.closedGrossProfitU;
      instance.totalNetProfitU   = instance.openNetProfitU   + instance.closedNetProfitU;
      instance.totalNetProfit    = instance.openNetProfit    + instance.closedNetProfit; SS.TotalPL();

      if      (instance.totalNetProfit > instance.maxNetProfit  ) { instance.maxNetProfit   = instance.totalNetProfit; SS.PLStats(); }
      else if (instance.totalNetProfit < instance.maxNetDrawdown) { instance.maxNetDrawdown = instance.totalNetProfit; SS.PLStats(); }
   }
   return(!catch("UpdateStatus(4)"));
}


/**
 * Update virtual order status and PL.
 *
 * @return bool - success status
 */
bool UpdateVirtualStatus() {
   if (!open.ticket) return(!catch("UpdateVirtualStatus(1)  "+ instance.name +" no open ticket found", ERR_ILLEGAL_STATE));

   open.swap         = 0;
   open.commission   = 0;
   open.grossProfitU = ifDouble(!open.type, Bid-open.price, open.price-Ask);
   open.grossProfit  = open.grossProfitU * QuoteUnitValue(Lots);
   open.netProfitU   = open.grossProfitU;
   open.netProfit    = open.grossProfit;

   instance.openZeroProfitU  = ifDouble(!open.type, Bid-open.bid, open.bid-Bid);    // both directions use Bid prices
   instance.openGrossProfitU = open.grossProfitU;
   instance.openNetProfitU   = open.netProfitU;
   instance.openNetProfit    = open.netProfit;

   instance.totalZeroProfitU  = instance.openZeroProfitU  + instance.closedZeroProfitU;
   instance.totalGrossProfitU = instance.openGrossProfitU + instance.closedGrossProfitU;
   instance.totalNetProfitU   = instance.openNetProfitU   + instance.closedNetProfitU;
   instance.totalNetProfit    = instance.openNetProfit    + instance.closedNetProfit; SS.TotalPL();

   if      (instance.totalNetProfit > instance.maxNetProfit  ) { instance.maxNetProfit   = instance.totalNetProfit; SS.PLStats(); }
   else if (instance.totalNetProfit < instance.maxNetDrawdown) { instance.maxNetDrawdown = instance.totalNetProfit; SS.PLStats(); }

   return(!catch("UpdateVirtualStatus(2)"));
}


/**
 * Compose a log message for a closed position. The ticket is selected.
 *
 * @param  _Out_ int error - error code to be returned from the call (if any)
 *
 * @return string - log message or an empty string in case of errors
 */
string UpdateStatus.PositionCloseMsg(int &error) {
   // #1 Sell 0.1 GBPUSD at 1.5457'2 ("Z.869") was [unexpectedly ]closed [by SL ]at 1.5457'2 (market: Bid/Ask[, so: 47.7%/169.20/354.40])
   error = NO_ERROR;

   int    ticket     = OrderTicket();
   int    type       = OrderType();
   double lots       = OrderLots();
   double openPrice  = OrderOpenPrice();
   double closePrice = OrderClosePrice();
   bool   closedBySl = IsClosedBySL(open.stoploss);

   string sType       = OperationTypeDescription(type);
   string sOpenPrice  = NumberToStr(openPrice, PriceFormat);
   string sClosePrice = NumberToStr(closePrice, PriceFormat);
   string sUnexpected = ifString(closedBySl || __CoreFunction==CF_INIT || (__isTesting && __CoreFunction==CF_DEINIT), "", "unexpectedly ");
   string sBySL       = ifString(closedBySl, "by SL ", "");
   string message     = "#"+ ticket +" "+ sType +" "+ NumberToStr(lots, ".+") +" "+ OrderSymbol() +" at "+ sOpenPrice +" (\""+ instance.name +"\") was "+ sUnexpected +"closed "+ sBySL +"at "+ sClosePrice;

   string sStopout = "";
   if (StrStartsWithI(OrderComment(), "so:")) {       error = ERR_MARGIN_STOPOUT; sStopout = ", "+ OrderComment(); }
   else if (closedBySl)                               error = ERR_ORDER_CHANGED;
   else if (__CoreFunction==CF_INIT)                  error = NO_ERROR;
   else if (__isTesting && __CoreFunction==CF_DEINIT) error = NO_ERROR;
   else                                               error = ERR_CONCURRENT_MODIFICATION;

   return(message +" (market: "+ NumberToStr(Bid, PriceFormat) +"/"+ NumberToStr(Ask, PriceFormat) + sStopout +")");
}


/**
 * Whether the currently selected order was closed by the specified stoploss.
 *
 * @param  double stoploss - the stoploss price
 *
 * @return bool
 */
bool IsClosedBySL(double stoploss) {
   bool closedBySL = false;

   if (stoploss && OrderType()<=OP_SELL && OrderCloseTime()) {
      if      (StrEndsWithI(OrderComment(), "[sl]"))  closedBySL = true;
      else if (StrStartsWithI(OrderComment(), "so:")) closedBySL = false;
      else if (OrderType() == OP_BUY)                 closedBySL = LE(OrderClosePrice(), stoploss, Digits);
      else                                            closedBySL = GE(OrderClosePrice(), stoploss, Digits);
   }
   return(closedBySL);
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
 * Emulate opening of a virtual market position with the specified parameters.
 *
 * @param  int type - trade operation type
 *
 * @return int - virtual ticket or NULL in case of errors
 */
int VirtualOrderSend(int type) {
   int ticket = open.ticket;
   int size = ArrayRange(history, 0);
   if (size > 0) ticket = Max(ticket, history[size-1][H_TICKET]);
   ticket++;

   if (IsLogInfo()) {
      string sType  = OperationTypeDescription(type);
      string sLots  = NumberToStr(Lots, ".+");
      string sPrice = NumberToStr(ifDouble(type, Bid, Ask), PriceFormat);
      string sBid   = NumberToStr(Bid, PriceFormat);
      string sAsk   = NumberToStr(Ask, PriceFormat);
      logInfo("VirtualOrderSend(1)  "+ instance.name +" opened virtual #"+ ticket +" "+ sType +" "+ sLots +" "+ Symbol() +" \"ZigZag."+ instance.id +"\" at "+ sPrice +" (market: "+ sBid +"/"+ sAsk +")");
   }
   return(ticket);
}


/**
 * Emulate closing of a virtual position with the specified parameters.
 *
 * @param  int ticket - order ticket
 *
 * @return bool - success status
 */
bool VirtualOrderClose(int ticket) {
   if (ticket != open.ticket) return(!catch("VirtualOrderClose(1)  "+ instance.name +" ticket/open.ticket mis-match: "+ ticket +"/"+ open.ticket, ERR_ILLEGAL_STATE));

   if (IsLogInfo()) {
      string sType       = OperationTypeDescription(open.type);
      string sLots       = NumberToStr(Lots, ".+");
      string sOpenPrice  = NumberToStr(open.price, PriceFormat);
      double closePrice  = ifDouble(!open.type, Bid, Ask);
      string sClosePrice = NumberToStr(closePrice, PriceFormat);
      string sBid        = NumberToStr(Bid, PriceFormat);
      string sAsk        = NumberToStr(Ask, PriceFormat);
      logInfo("VirtualOrderClose(2)  "+ instance.name +" closed virtual #"+ ticket +" "+ sType +" "+ sLots +" "+ Symbol() +" \"ZigZag."+ instance.id +"\" from "+ sOpenPrice +" at "+ sClosePrice +" (market: "+ sBid +"/"+ sAsk +")");
   }
   return(true);
}


/**
 * Return symbol definitions for metrics to be recorded.
 *
 * @param  _In_  int    i             - zero-based index of the timeseries (position in the recorder)
 * @param  _Out_ bool   enabled       - whether the metric is active and should be recorded
 * @param  _Out_ string symbol        - unique timeseries symbol
 * @param  _Out_ string symbolDescr   - timeseries description
 * @param  _Out_ string symbolGroup   - timeseries group (if empty recorder defaults are used)
 * @param  _Out_ int    symbolDigits  - timeseries digits
 * @param  _Out_ double hstBase       - history base value (if zero recorder defaults are used)
 * @param  _Out_ int    hstMultiplier - multiplier applied to the recorded history values (if zero recorder defaults are used)
 * @param  _Out_ string hstDirectory  - history directory of the timeseries (if empty recorder defaults are used)
 * @param  _Out_ int    hstFormat     - history format of the timeseries (if empty recorder defaults are used)
 *
 * @return bool - whether to add a definition for the specified index
 */
bool Recorder_GetSymbolDefinition(int i, bool &enabled, string &symbol, string &symbolDescr, string &symbolGroup, int &symbolDigits, double &hstBase, int &hstMultiplier, string &hstDirectory, int &hstFormat) {
   enabled = false;
   if (IsLastError())                    return(false);
   if (!instance.id)                     return(!catch("Recorder_GetSymbolDefinition(1)  "+ instance.name +" illegal instance id: "+ instance.id, ERR_ILLEGAL_STATE));
   if (IsTestInstance() && !__isTesting) return(false);                       // never record anything in a stopped test

   string ids[];
   int size = Explode(EA.Recorder, ",", ids, NULL);
   for (int n=0; n < size; n++) {
      ids[n] = ""+ StrToInteger(ids[n]);                                      // cut-off a specified base value
   }

   enabled       = StringInArray(ids, ""+ (i+1));
   symbolGroup   = "";
   hstBase       = NULL;
   hstMultiplier = NULL;
   hstDirectory  = "";
   hstFormat     = NULL;

   int quoteUnitMultiplier = 1;                                               // original value: 1.23 => 1.23 point
   int digits = MathMax(Digits, 2);
   if (digits > 2) {
      quoteUnitMultiplier = MathRound(MathPow(10, digits & (~1)));            // convert to pip: 0.1234'5 => 1234.5 pip
   }

   static string sQuoteUnits = ""; if (!StringLen(sQuoteUnits)) {
      sQuoteUnits = ifString(quoteUnitMultiplier==1, "points", "pip");
   }

   switch (i) {
      // --------------------------------------------------------------------------------------------------------------------
      case METRIC_TOTAL_UNITS_ZERO:             // OK
         symbol        = "z"+ StrLeft(Symbol(), 5) +"_"+ instance.id +"A";    // "zUS500_123A"
         symbolDescr   = "ZigZag("+ ZigZag.Periods +","+ PeriodDescription() +") 1 "+ Symbol() +" in "+ sQuoteUnits +", zero spread";
         symbolDigits  = ifInt(quoteUnitMultiplier==1, digits, 1);            // "ZigZag(40,H1) 1 US500 in points, zero spread"
         hstMultiplier = quoteUnitMultiplier;
         return(true);

      case METRIC_TOTAL_UNITS_GROSS:            // OK
         symbol        = "z"+ StrLeft(Symbol(), 5) +"_"+ instance.id +"B";
         symbolDescr   = "ZigZag("+ ZigZag.Periods +","+ PeriodDescription() +") 1 "+ Symbol() +" in "+ sQuoteUnits +", gross";
         symbolDigits  = ifInt(quoteUnitMultiplier==1, digits, 1);
         hstMultiplier = quoteUnitMultiplier;
         return(true);

      case METRIC_TOTAL_UNITS_NET:              // OK
         symbol        = "z"+ StrLeft(Symbol(), 5) +"_"+ instance.id +"C";
         symbolDescr   = "ZigZag("+ ZigZag.Periods +","+ PeriodDescription() +") 1 "+ Symbol() +" in "+ sQuoteUnits +", net";
         symbolDigits  = ifInt(quoteUnitMultiplier==1, digits, 1);
         hstMultiplier = quoteUnitMultiplier;
         return(true);

      case METRIC_TOTAL_MONEY_NET:              // OK
         symbol        = "z"+ StrLeft(Symbol(), 5) +"_"+ instance.id +"D";
         symbolDescr   = "ZigZag("+ ZigZag.Periods +","+ PeriodDescription() +") 1 "+ Symbol() +" in "+ AccountCurrency() +", net";
         symbolDigits  = 2;
         hstMultiplier = 1;
         return(true);

      // --------------------------------------------------------------------------------------------------------------------
      case METRIC_DAILY_UNITS_ZERO:
         symbol        = "z"+ StrLeft(Symbol(), 5) +"_"+ instance.id +"E";    // "zEURUS_456A"
         symbolDescr   = "ZigZag("+ ZigZag.Periods +","+ PeriodDescription() +") 1 "+ Symbol() +" daily in "+ sQuoteUnits +", zero spread";
         symbolDigits  = ifInt(quoteUnitMultiplier==1, digits, 1);            // "ZigZag(40,H1) 3 EURUSD daily in pip, zero spread"
         hstMultiplier = quoteUnitMultiplier;
         return(true);

      case METRIC_DAILY_UNITS_GROSS:
         symbol        = "z"+ StrLeft(Symbol(), 5) +"_"+ instance.id +"F";
         symbolDescr   = "ZigZag("+ ZigZag.Periods +","+ PeriodDescription() +") 1 "+ Symbol() +" daily in "+ sQuoteUnits +", gross";
         symbolDigits  = ifInt(quoteUnitMultiplier==1, digits, 1);
         hstMultiplier = quoteUnitMultiplier;
         return(true);

      case METRIC_DAILY_UNITS_NET:
         symbol        = "z"+ StrLeft(Symbol(), 5) +"_"+ instance.id +"G";
         symbolDescr   = "ZigZag("+ ZigZag.Periods +","+ PeriodDescription() +") 1 "+ Symbol() +" daily in "+ sQuoteUnits +", net";
         symbolDigits  = ifInt(quoteUnitMultiplier==1, digits, 1);
         hstMultiplier = quoteUnitMultiplier;
         return(true);

      case METRIC_DAILY_MONEY_NET:
         symbol        = "z"+ StrLeft(Symbol(), 5) +"_"+ instance.id +"H";
         symbolDescr   = "ZigZag("+ ZigZag.Periods +","+ PeriodDescription() +") 1 "+ Symbol() +" daily in "+ AccountCurrency() +", net";
         symbolDigits  = 2;
         hstMultiplier = 1;
         return(true);
   }
   return(false);
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
      string baseName  = Symbol() +"."+ GmtTimeFormat(instance.created, "%Y.%m.%d %H.%M") +".ZigZag."+ instance.id +".set";
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
   string basePattern = Symbol() +".*.ZigZag."+ instanceId +".set";
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

   // general
   WriteIniString(file, section, "tradingMode",                 /*int     */ tradingMode + CRLF);

   // instance data
   WriteIniString(file, section, "instance.id",                 /*int     */ instance.id);
   WriteIniString(file, section, "instance.created",            /*datetime*/ instance.created + GmtTimeFormat(instance.created, " (%a, %Y.%m.%d %H:%M:%S)"));
   WriteIniString(file, section, "instance.isTest",             /*bool    */ instance.isTest);
   WriteIniString(file, section, "instance.name",               /*string  */ instance.name);
   WriteIniString(file, section, "instance.status",             /*int     */ instance.status);
   WriteIniString(file, section, "instance.startEquity",        /*double  */ DoubleToStr(instance.startEquity, 2) + CRLF);

   WriteIniString(file, section, "instance.openZeroProfitU",    /*double  */ DoubleToStr(instance.openZeroProfitU, Digits));
   WriteIniString(file, section, "instance.closedZeroProfitU",  /*double  */ DoubleToStr(instance.closedZeroProfitU, Digits));
   WriteIniString(file, section, "instance.totalZeroProfitU",   /*double  */ DoubleToStr(instance.totalZeroProfitU, Digits) + CRLF);

   WriteIniString(file, section, "instance.openGrossProfitU",   /*double  */ DoubleToStr(instance.openGrossProfitU, Digits));
   WriteIniString(file, section, "instance.closedGrossProfitU", /*double  */ DoubleToStr(instance.closedGrossProfitU, Digits));
   WriteIniString(file, section, "instance.totalGrossProfitU",  /*double  */ DoubleToStr(instance.totalGrossProfitU, Digits) + CRLF);

   WriteIniString(file, section, "instance.openNetProfitU",     /*double  */ DoubleToStr(instance.openNetProfitU, Digits));
   WriteIniString(file, section, "instance.closedNetProfitU",   /*double  */ DoubleToStr(instance.closedNetProfitU, Digits));
   WriteIniString(file, section, "instance.totalNetProfitU",    /*double  */ DoubleToStr(instance.totalNetProfitU, Digits) + CRLF);

   WriteIniString(file, section, "instance.openNetProfit",      /*double  */ DoubleToStr(instance.openNetProfit, 2));
   WriteIniString(file, section, "instance.closedNetProfit",    /*double  */ DoubleToStr(instance.closedNetProfit, 2));
   WriteIniString(file, section, "instance.totalNetProfit",     /*double  */ DoubleToStr(instance.totalNetProfit, 2) + CRLF);
   WriteIniString(file, section, "instance.maxNetProfit",       /*double  */ DoubleToStr(instance.maxNetProfit, 2));
   WriteIniString(file, section, "instance.maxNetDrawdown",     /*double  */ DoubleToStr(instance.maxNetDrawdown, 2) + CRLF);

   // open order data
   WriteIniString(file, section, "open.ticket",                 /*int     */ open.ticket);
   WriteIniString(file, section, "open.type",                   /*int     */ open.type);
   WriteIniString(file, section, "open.time",                   /*datetime*/ open.time + ifString(open.time, GmtTimeFormat(open.time, " (%a, %Y.%m.%d %H:%M:%S)"), ""));
   WriteIniString(file, section, "open.bid",                    /*double  */ DoubleToStr(open.bid, Digits));
   WriteIniString(file, section, "open.ask",                    /*double  */ DoubleToStr(open.ask, Digits));
   WriteIniString(file, section, "open.price",                  /*double  */ DoubleToStr(open.price, Digits));
   WriteIniString(file, section, "open.stoploss",               /*double  */ DoubleToStr(open.stoploss, Digits));
   WriteIniString(file, section, "open.slippage",               /*double  */ DoubleToStr(open.slippage, Digits));
   WriteIniString(file, section, "open.swap",                   /*double  */ DoubleToStr(open.swap, 2));
   WriteIniString(file, section, "open.commission",             /*double  */ DoubleToStr(open.commission, 2));
   WriteIniString(file, section, "open.grossProfit",            /*double  */ DoubleToStr(open.grossProfit, 2));
   WriteIniString(file, section, "open.grossProfitU",           /*double  */ DoubleToStr(open.grossProfitU, Digits));
   WriteIniString(file, section, "open.netProfit",              /*double  */ DoubleToStr(open.netProfit, 2));
   WriteIniString(file, section, "open.netProfitU",             /*double  */ DoubleToStr(open.netProfitU, Digits) + CRLF);

   // closed order data
   int size = ArrayRange(history, 0);
   for (int i=0; i < size; i++) {
      WriteIniString(file, section, "history."+ i, SaveStatus.HistoryToStr(i) + ifString(i+1 < size, "", CRLF));
   }

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
   WriteIniString(file, section, "stop.profitQu.condition",     /*bool    */ stop.profitQu.condition);
   WriteIniString(file, section, "stop.profitQu.type",          /*int     */ stop.profitQu.type);
   WriteIniString(file, section, "stop.profitQu.value",         /*double  */ NumberToStr(stop.profitQu.value, ".1+"));
   WriteIniString(file, section, "stop.profitQu.description",   /*string  */ stop.profitQu.description + CRLF);

   return(!catch("SaveStatus(2)"));
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
   // result: ticket,lots,openType,openTime,openBid,OpenAsk,openPrice,closeTime,closeBid,closeAsk,closePrice,slippage,swap,commission,grossProfit,netProfit

   int      ticket      = history[index][H_TICKET       ];
   double   lots        = history[index][H_LOTS         ];
   int      openType    = history[index][H_OPENTYPE     ];
   datetime openTime    = history[index][H_OPENTIME     ];
   double   openBid     = history[index][H_OPENBID      ];
   double   openAsk     = history[index][H_OPENASK      ];
   double   openPrice   = history[index][H_OPENPRICE    ];
   datetime closeTime   = history[index][H_CLOSETIME    ];
   double   closeBid    = history[index][H_CLOSEBID     ];
   double   closeAsk    = history[index][H_CLOSEASK     ];
   double   closePrice  = history[index][H_CLOSEPRICE   ];
   double   slippage    = history[index][H_SLIPPAGE     ];
   double   swap        = history[index][H_SWAP_M       ];
   double   commission  = history[index][H_COMMISSION_M ];
   double   grossProfit = history[index][H_GROSSPROFIT_M];
   double   netProfit   = history[index][H_NETPROFIT_M  ];

   return(StringConcatenate(ticket, ",", DoubleToStr(lots, 2), ",", openType, ",", openTime, ",", DoubleToStr(openBid, Digits), ",", DoubleToStr(openAsk, Digits), ",", DoubleToStr(openPrice, Digits), ",", closeTime, ",", DoubleToStr(closeBid, Digits), ",", DoubleToStr(closeAsk, Digits), ",", DoubleToStr(closePrice, Digits), ",", DoubleToStr(slippage, Digits), ",", DoubleToStr(swap, 2), ",", DoubleToStr(commission, 2), ",", DoubleToStr(grossProfit, 2), ",", DoubleToStr(netProfit, 2)));
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
   string sInstanceID          = GetIniStringA(file, section, "Instance.ID",          "");            // string Instance.ID          = T123
   string sTradingMode         = GetIniStringA(file, section, "TradingMode",          "");            // string TradingMode          = regular
   int    iZigZagPeriods       = GetIniInt    (file, section, "ZigZag.Periods"          );            // int    ZigZag.Periods       = 40
   string sLots                = GetIniStringA(file, section, "Lots",                 "");            // double Lots                 = 0.1
   string sStartConditions     = GetIniStringA(file, section, "StartConditions",      "");            // string StartConditions      = @time(datetime|time)
   string sStopConditions      = GetIniStringA(file, section, "StopConditions",       "");            // string StopConditions       = @time(datetime|time)
   string sTakeProfit          = GetIniStringA(file, section, "TakeProfit",           "");            // double TakeProfit           = 3.0
   string sTakeProfitType      = GetIniStringA(file, section, "TakeProfit.Type",      "");            // string TakeProfit.Type      = off* | money | percent | pip
   string sShowProfitInPercent = GetIniStringA(file, section, "ShowProfitInPercent",  "");            // bool   ShowProfitInPercent  = 1
   string sEaRecorder          = GetIniStringA(file, section, "EA.Recorder",          "");            // string EA.Recorder          = 1,2,4

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
   instance.created            = GetIniInt    (file, section, "instance.created"           );         // datetime instance.created            = 1624924800 (Mon, 2021.05.12 13:22:34)
   instance.isTest             = GetIniBool   (file, section, "instance.isTest"            );         // bool     instance.isTest             = 1
   instance.name               = GetIniStringA(file, section, "instance.name",           "");         // string   instance.name               = Z.123
   instance.status             = GetIniInt    (file, section, "instance.status"            );         // int      instance.status             = 1
   instance.startEquity        = GetIniDouble (file, section, "instance.startEquity"       );         // double   instance.startEquity        = 1000.00

   instance.openZeroProfitU    = GetIniDouble (file, section, "instance.openZeroProfitU"   );         // double   instance.openZeroProfitU    = 0.12345
   instance.closedZeroProfitU  = GetIniDouble (file, section, "instance.closedZeroProfitU" );         // double   instance.closedZeroProfitU  = -0.23456
   instance.totalZeroProfitU   = GetIniDouble (file, section, "instance.totalZeroProfitU"  );         // double   instance.totalZeroProfitU   = 1.23456

   instance.openGrossProfitU   = GetIniDouble (file, section, "instance.openGrossProfitU"  );         // double   instance.openGrossProfitU   = 0.12345
   instance.closedGrossProfitU = GetIniDouble (file, section, "instance.closedGrossProfitU");         // double   instance.closedGrossProfitU = -0.23456
   instance.totalGrossProfitU  = GetIniDouble (file, section, "instance.totalGrossProfitU" );         // double   instance.totalGrossProfitU  = 1.23456

   instance.openNetProfitU     = GetIniDouble (file, section, "instance.openNetProfitU"    );         // double   instance.openNetProfitU     = 0.12345
   instance.closedNetProfitU   = GetIniDouble (file, section, "instance.closedNetProfitU"  );         // double   instance.closedNetProfitU   = -0.23456
   instance.totalNetProfitU    = GetIniDouble (file, section, "instance.totalNetProfitU"   );         // double   instance.totalNetProfitU    = 1.23456

   instance.openNetProfit      = GetIniDouble (file, section, "instance.openNetProfit"     );         // double   instance.openNetProfit      = 23.45
   instance.closedNetProfit    = GetIniDouble (file, section, "instance.closedNetProfit"   );         // double   instance.closedNetProfit    = 45.67
   instance.totalNetProfit     = GetIniDouble (file, section, "instance.totalNetProfit"    );         // double   instance.totalNetProfit     = 123.45
   instance.maxNetProfit       = GetIniDouble (file, section, "instance.maxNetProfit"      );         // double   instance.maxNetProfit       = 23.45
   instance.maxNetDrawdown     = GetIniDouble (file, section, "instance.maxNetDrawdown"    );         // double   instance.maxNetDrawdown     = -11.23
   SS.InstanceName();

   // open order data
   open.ticket                 = GetIniInt    (file, section, "open.ticket"      );                   // int      open.ticket       = 123456
   open.type                   = GetIniInt    (file, section, "open.type"        );                   // int      open.type         = 1
   open.time                   = GetIniInt    (file, section, "open.time"        );                   // datetime open.time         = 1624924800 (Mon, 2021.05.12 13:22:34)
   open.bid                    = GetIniDouble (file, section, "open.bid"         );                   // double   open.bid          = 1.24363
   open.ask                    = GetIniDouble (file, section, "open.ask"         );                   // double   open.ask          = 1.24363
   open.price                  = GetIniDouble (file, section, "open.price"       );                   // double   open.price        = 1.24363
   open.stoploss               = GetIniDouble (file, section, "open.stoploss"    );                   // double   open.stoploss     = 1.24363
   open.slippage               = GetIniDouble (file, section, "open.slippage"    );                   // double   open.slippage     = 0.00002
   open.swap                   = GetIniDouble (file, section, "open.swap"        );                   // double   open.swap         = -1.23
   open.commission             = GetIniDouble (file, section, "open.commission"  );                   // double   open.commission   = -5.50
   open.grossProfit            = GetIniDouble (file, section, "open.grossProfit" );                   // double   open.grossProfit  = 12.34
   open.grossProfitU           = GetIniDouble (file, section, "open.grossProfitU");                   // double   open.grossProfitU = 0.12345
   open.netProfit              = GetIniDouble (file, section, "open.netProfit"   );                   // double   open.netProfit    = 12.56
   open.netProfitU             = GetIniDouble (file, section, "open.netProfitU"  );                   // double   open.netProfitU   = 0.12345

   // history data
   string sKeys[], sOrder="";
   int size = ReadStatus.HistoryKeys(file, section, sKeys); if (size < 0) return(false);
   for (int i=0; i < size; i++) {
      sOrder = GetIniStringA(file, section, sKeys[i], "");                                            // history.{i} = {data}
      if (!ReadStatus.ParseHistory(sKeys[i], sOrder)) return(!catch("ReadStatus(8)  "+ instance.name +" invalid history record in status file "+ DoubleQuoteStr(file) + NL + sKeys[i] +"="+ sOrder, ERR_INVALID_FILE_FORMAT));
   }

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

   stop.profitQu.condition    = GetIniBool   (file, section, "stop.profitQu.condition"      );        // bool     stop.profitQu.condition    = 1
   stop.profitQu.type         = GetIniInt    (file, section, "stop.profitQu.type"           );        // int      stop.profitQu.type         = 4
   stop.profitQu.value        = GetIniDouble (file, section, "stop.profitQu.value"          );        // double   stop.profitQu.value        = 1.23456
   stop.profitQu.description  = GetIniStringA(file, section, "stop.profitQu.description", "");        // string   stop.profitQu.description  = text

   return(!catch("ReadStatus(9)"));
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
 * @return bool - success status
 */
bool ReadStatus.ParseHistory(string key, string value) {
   if (IsLastError())                    return(false);
   if (!StrStartsWithI(key, "history.")) return(!catch("ReadStatus.ParseHistory(1)  "+ instance.name +" illegal history record key "+ DoubleQuoteStr(key), ERR_INVALID_FILE_FORMAT));

   // history.i=ticket,lots,openType,openTime,openBid,openAsk,openPrice,closeTime,closeBid,closeAsk,closePrice,slippage,swap,commission,grossProfit,netProfit
   string values[];
   string sId = StrRightFrom(key, ".", -1); if (!StrIsDigits(sId))  return(!catch("ReadStatus.ParseHistory(2)  "+ instance.name +" illegal history record key "+ DoubleQuoteStr(key), ERR_INVALID_FILE_FORMAT));
   if (Explode(value, ",", values, NULL) != ArrayRange(history, 1)) return(!catch("ReadStatus.ParseHistory(3)  "+ instance.name +" illegal number of details ("+ ArraySize(values) +") in history record", ERR_INVALID_FILE_FORMAT));

   int      ticket      = StrToInteger(values[H_TICKET       ]);
   double   lots        =  StrToDouble(values[H_LOTS         ]);
   int      openType    = StrToInteger(values[H_OPENTYPE     ]);
   datetime openTime    = StrToInteger(values[H_OPENTIME     ]);
   double   openBid     =  StrToDouble(values[H_OPENBID      ]);
   double   openAsk     =  StrToDouble(values[H_OPENASK      ]);
   double   openPrice   =  StrToDouble(values[H_OPENPRICE    ]);
   datetime closeTime   = StrToInteger(values[H_CLOSETIME    ]);
   double   closeBid    =  StrToDouble(values[H_CLOSEBID     ]);
   double   closeAsk    =  StrToDouble(values[H_CLOSEASK     ]);
   double   closePrice  =  StrToDouble(values[H_CLOSEPRICE   ]);
   double   slippage    =  StrToDouble(values[H_SLIPPAGE     ]);
   double   swap        =  StrToDouble(values[H_SWAP_M       ]);
   double   commission  =  StrToDouble(values[H_COMMISSION_M ]);
   double   grossProfit =  StrToDouble(values[H_GROSSPROFIT_M]);
   double   netProfit   =  StrToDouble(values[H_NETPROFIT_M  ]);

   return(!IsEmpty(History.AddRecord(ticket, lots, openType, openTime, openBid, openAsk, openPrice, closeTime, closeBid, closeAsk, closePrice, slippage, swap, commission, grossProfit, netProfit)));
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
int History.AddRecord(int ticket, double lots, int openType, datetime openTime, double openBid, double openAsk, double openPrice, datetime closeTime, double closeBid, double closeAsk, double closePrice, double slippage, double swap, double commission, double grossProfit, double netProfit) {
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
   history[i][H_TICKET       ] = ticket;
   history[i][H_LOTS         ] = lots;
   history[i][H_OPENTYPE     ] = openType;
   history[i][H_OPENTIME     ] = openTime;
   history[i][H_OPENBID      ] = openBid;
   history[i][H_OPENASK      ] = openAsk;
   history[i][H_OPENPRICE    ] = openPrice;
   history[i][H_CLOSETIME    ] = closeTime;
   history[i][H_CLOSEBID     ] = closeBid;
   history[i][H_CLOSEASK     ] = closeAsk;
   history[i][H_CLOSEPRICE   ] = closePrice;
   history[i][H_SLIPPAGE     ] = slippage;
   history[i][H_SWAP_M       ] = swap;
   history[i][H_COMMISSION_M ] = commission;
   history[i][H_GROSSPROFIT_M] = grossProfit;
   history[i][H_NETPROFIT_M  ] = netProfit;

   if (!catch("History.AddRecord(2)"))
      return(i);
   return(EMPTY);
}


/**
 * Synchronize restored state and runtime vars with current order status on the trade server.
 * Called only from RestoreInstance().
 *
 * @return bool - success status
 */
bool SynchronizeStatus() {
   if (IsLastError()) return(false);

   int prevOpenTicket  = open.ticket;
   int prevHistorySize = ArrayRange(history, 0);

   // detect & handle a dangling open position
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
            open.stoploss  = OrderStopLoss();
            open.bid       = open.price;
            open.ask       = open.price;
            open.slippage  = NULL;                                   // open PL numbers will auto-update in the following UpdateStatus() call
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

   // detect & handle dangling closed positions
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
            double   slippageP    = 0;
            double   swap         = OrderSwap();
            double   commission   = OrderCommission();
            double   grossProfit  = OrderProfit();
            double   netProfit    = grossProfit + swap + commission;
            double   grossProfitU = ifDouble(!openType, closePrice-openPrice, openPrice-closePrice);

            logWarn("SynchronizeStatus(4)  "+ instance.name +" dangling closed position found: #"+ ticket +", adding to instance...");
            if (IsEmpty(History.AddRecord(ticket, lots, openType, openTime, openPrice, openPrice, openPrice, closeTime, closePrice, closePrice, closePrice, slippageP, swap, commission, grossProfit, netProfit))) return(false);

            // update closed PL numbers
            instance.closedZeroProfitU  += grossProfitU;
            instance.closedGrossProfitU += grossProfitU;
            instance.closedNetProfitU   += grossProfitU + MathDiv(swap + commission, QuoteUnitValue(lots));
            instance.closedNetProfit    += netProfit;
         }
      }
   }

   // recalculate total PL numbers
   instance.totalZeroProfitU  = instance.openZeroProfitU  + instance.closedZeroProfitU;
   instance.totalGrossProfitU = instance.openGrossProfitU + instance.closedGrossProfitU;
   instance.totalNetProfitU   = instance.openNetProfitU   + instance.closedNetProfitU;
   instance.totalNetProfit    = instance.openNetProfit    + instance.closedNetProfit;

   instance.maxNetProfit   = MathMax(instance.maxNetProfit,   instance.totalNetProfit);
   instance.maxNetDrawdown = MathMin(instance.maxNetDrawdown, instance.totalNetProfit);
   SS.TotalPL();
   SS.PLStats();

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
string   prev.EA.Recorder = "";

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
bool     prev.stop.profitQu.condition;
int      prev.stop.profitQu.type;
double   prev.stop.profitQu.value;
string   prev.stop.profitQu.description = "";

int      prev.recordMode;
bool     prev.recordInternal;
bool     prev.recordCustom;


/**
 * Programatically changed input parameters don't survive init cycles. Therefore inputs are backed-up in deinit() and can be
 * restored in init(). Called in onDeinitParameters() and onDeinitChartChange().
 */
void BackupInputs() {
   // backup input parameters, used for comparison in ValidateInputs()
   prev.Instance.ID          = StringConcatenate(Instance.ID, "");   // string inputs are references to internal C literals and must be copied to break the reference
   prev.TradingMode          = StringConcatenate(TradingMode, "");
   prev.ZigZag.Periods       = ZigZag.Periods;
   prev.Lots                 = Lots;
   prev.StartConditions      = StringConcatenate(StartConditions, "");
   prev.StopConditions       = StringConcatenate(StopConditions, "");
   prev.TakeProfit           = TakeProfit;
   prev.TakeProfit.Type      = StringConcatenate(TakeProfit.Type, "");
   prev.ShowProfitInPercent  = ShowProfitInPercent;
   prev.EA.Recorder          = StringConcatenate(EA.Recorder, "");

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
   prev.stop.profitQu.condition    = stop.profitQu.condition;
   prev.stop.profitQu.type         = stop.profitQu.type;
   prev.stop.profitQu.value        = stop.profitQu.value;
   prev.stop.profitQu.description  = stop.profitQu.description;

   prev.recordMode                 = recordMode;
   prev.recordInternal             = recordInternal;
   prev.recordCustom               = recordCustom;
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
   stop.profitQu.condition    = prev.stop.profitQu.condition;
   stop.profitQu.type         = prev.stop.profitQu.type;
   stop.profitQu.value        = prev.stop.profitQu.value;
   stop.profitQu.description  = prev.stop.profitQu.description;

   recordMode                 = prev.recordMode;
   recordInternal             = prev.recordInternal;
   recordCustom               = prev.recordCustom;
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
 * Validate all input parameters. Parameters may have been entered through the input dialog, read from a status file or
 * deserialized and applied programmatically by the terminal (e.g. at terminal restart). Called from onInitUser(),
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
   if      (StrStartsWith("off",        sValue)) stop.profitQu.type = NULL;
   else if (StrStartsWith("money",      sValue)) stop.profitQu.type = TP_TYPE_MONEY;
   else if (StrStartsWith("quote-unit", sValue)) stop.profitQu.type = TP_TYPE_QUOTEUNIT;
   else if (StringLen(sValue) < 2)                       return(!onInputError("ValidateInputs(24)  "+ instance.name +" invalid parameter TakeProfit.Type: "+ DoubleQuoteStr(TakeProfit.Type)));
   else if (StrStartsWith("percent", sValue))    stop.profitQu.type = TP_TYPE_PERCENT;
   else if (StrStartsWith("pip",     sValue))    stop.profitQu.type = TP_TYPE_PIP;
   else                                                  return(!onInputError("ValidateInputs(25)  "+ instance.name +" invalid parameter TakeProfit.Type: "+ DoubleQuoteStr(TakeProfit.Type)));
   stop.profitAbs.condition   = false;
   stop.profitAbs.description = "";
   stop.profitPct.condition   = false;
   stop.profitPct.description = "";
   stop.profitQu.condition    = false;
   stop.profitQu.description  = "";

   switch (stop.profitQu.type) {
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
         stop.profitQu.condition    = true;
         stop.profitQu.value        = NormalizeDouble(TakeProfit*Pip, Digits);
         stop.profitQu.description  = "profit("+ NumberToStr(TakeProfit, ".+") +" pip)";
         break;

      case TP_TYPE_QUOTEUNIT:
         stop.profitQu.condition    = true;
         stop.profitQu.value        = NormalizeDouble(TakeProfit, Digits);
         stop.profitQu.description  = "profit("+ NumberToStr(stop.profitQu.value, PriceFormat) +" point)";
         break;
   }
   TakeProfit.Type = tpTypeDescriptions[stop.profitQu.type];

   // EA.Recorder
   if (!IsTestInstance() || __isTesting) {      // never init the recorder of a stopped test
      int metrics;
      if (!init_RecorderValidateInput(metrics)) return(false);
      if (recordCustom && metrics > 8)          return(!onInputError("ValidateInputs(26)  "+ instance.name +" invalid parameter EA.Recorder: "+ DoubleQuoteStr(EA.Recorder) +" (unsupported metric "+ metrics +")"));
   }

   SS.All();
   return(!catch("ValidateInputs(27)"));
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
 * Remove a stored instance id.
 *
 * @return bool - success status
 */
bool RemoveInstanceId() {
   if (__isChart) {
      // chart window
      string name = ProgramName() +".Instance.ID";
      RemoveWindowStringA(__ExecutionContext[EC.hChart], name);

      // chart
      Chart.RestoreString(name, name, true);

      // remove a chart status for chart commands
      name = "EA.status";
      if (ObjectFind(name) != -1) ObjectDelete(name);
   }
   return(!catch("RemoveInstanceId(1)"));
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
 * Return the quote unit value of the specified lot amount in account currency. Same as PipValue() but for a full quote unit.
 *
 * @param  double lots [optional] - lot amount (default: 1 lot)
 *
 * @return double - unit value or NULL (0) in case of errors (in tester the value may not be exact)
 */
double QuoteUnitValue(double lots = 1.0) {
   if (!lots) return(0);

   double tickValue = MarketInfo(Symbol(), MODE_TICKVALUE);
   int error = GetLastError();
   if (error || !tickValue)   return(!catch("QuoteUnitValue(1)  MarketInfo(MODE_TICKVALUE) = "+ tickValue, intOr(error, ERR_SYMBOL_NOT_AVAILABLE)));

   static double tickSize; if (!tickSize) {
      tickSize = MarketInfo(Symbol(), MODE_TICKSIZE);
      error = GetLastError();
      if (error || !tickSize) return(!catch("QuoteUnitValue(2)  MarketInfo(MODE_TICKSIZE) = "+ tickSize, intOr(error, ERR_SYMBOL_NOT_AVAILABLE)));
   }
   return(tickValue/tickSize * lots);
}


/**
 * ShowStatus: Update all string representations.
 */
void SS.All() {
   if (__isChart) {
      SS.InstanceName();
      SS.Lots();
      SS.StartStopConditions();
      SS.TotalPL();
      SS.PLStats();
   }
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
 * ShowStatus: Update the string representation of the lotsize.
 */
void SS.Lots() {
   if (__isChart) {
      sLots = NumberToStr(Lots, ".+");
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
      if (stop.profitQu.description != "") {
         sValue = sValue + ifString(sValue=="", "", " | ") + ifString(stop.profitQu.condition, "@", "!") + stop.profitQu.description;
      }
      if (sValue == "") sStopConditions = "-";
      else              sStopConditions = sValue;
   }
}


/**
 * ShowStatus: Update the string representation of "instance.netTotalPL".
 */
void SS.TotalPL() {
   if (__isChart) {
      // not before a position was opened
      if (!open.ticket && !ArrayRange(history, 0)) sInstanceTotalNetPL = "-";
      else if (ShowProfitInPercent)                sInstanceTotalNetPL = NumberToStr(MathDiv(instance.totalNetProfit, instance.startEquity) * 100, "R+.2") +"%";
      else                                         sInstanceTotalNetPL = NumberToStr(instance.totalNetProfit, "R+.2");
   }
}


/**
 * ShowStatus: Update the string representaton of the PL stats.
 */
void SS.PLStats() {
   if (__isChart) {
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
                                  "Lots:      ", sLots,                                                     NL,
                                  "Start:    ",  sStartConditions,                                          NL,
                                  "Stop:     ",  sStopConditions,                                           NL,
                                  "Profit:   ",  sInstanceTotalNetPL, "  ", sInstancePlStats,               NL
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
