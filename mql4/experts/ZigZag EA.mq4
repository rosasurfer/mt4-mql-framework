/**
 * ZigZag EA - a modified version of the system traded by the "Turtle traders" of Richard Dennis
 *
 *
 * The ZigZag indicator coming with MetaTrader internally uses a Donchian channel for it's calculation. Thus it can be used
 * to implement the Donchian channel system as traded by Richard Dennis in his "Turtle trading" program. This EA uses a custom
 * and greatly enhanced version of the ZigZag indicator (most signals are still the same).
 *
 *  @link  https://vantagepointtrading.com/top-trader-richard-dennis-turtle-trading-strategy/#             ["Turtle Trading"]
 *
 *
 * Input parameters
 * ----------------
 * • EA.Recorder: Recorded metrics, one of "on", "off" or one/more custom metric ids separated by comma. For the syntax of
 *                metric ids see the input parameter "EA.Recorder" in "mql4/include/core/expert.mqh".
 *    "off": Recording is disabled.
 *    "on":  Records a standard timeseries depicting the EA's regular equity graph after all costs.
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
 *    Timeseries in "quote units" are recorded in the best matching unit (one of pip, quote currency or index points).
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
 * TODO:
 *  - simplify
 *     datetime GetSessionStartTime.srv(datetime serverTime);
 *
 *     datetime GetSessionEndTime.fxt(datetime fxtTime);
 *     datetime GetSessionEndTime.gmt(datetime gmtTime);
 *     datetime GetSessionEndTime.srv(datetime serverTime);
 *
 *     datetime GetPrevSessionStartTime.fxt(datetime fxtTime);
 *     datetime GetPrevSessionStartTime.gmt(datetime gmtTime);
 *     datetime GetPrevSessionStartTime.srv(datetime serverTime);
 *
 *     datetime GetPrevSessionEndTime.fxt(datetime fxtTime);
 *     datetime GetPrevSessionEndTime.gmt(datetime gmtTime);
 *     datetime GetPrevSessionEndTime.srv(datetime serverTime);
 *
 *     datetime GetNextSessionStartTime.fxt(datetime fxtTime);
 *     datetime GetNextSessionStartTime.gmt(datetime gmtTime);
 *     datetime GetNextSessionStartTime.srv(datetime serverTime);
 *
 *     datetime GetNextSessionEndTime.fxt(datetime fxtTime);
 *     datetime GetNextSessionEndTime.gmt(datetime gmtTime);
 *     datetime GetNextSessionEndTime.srv(datetime serverTime);
 *
 *  - TimeServer() as replacement for TimeCurrent() adds nothing
 *  - time functions returning modeled time must log errors
 *
 *  - AverageRange
 *     fix EMPTY_VALUE
 *     integrate required bars in startbar calculation
 *     MTF option for lower TF data on higher TFs (to display more data than a single screen)
 *     one more buffer for current range
 *
 *  - SuperBars
 *     fix gap between days/weeks if market doesn't work 24h
 *     implement more timeframes
 *
 *  - move iCustom() to ta/includes
 *  - rename Max.Bars to MaxBarsBack
 *  - investigate an auto-updating global var MaxBarsBack to prevent possible integer overflows
 *  - implement global var indicator::CalculatedBars
 *  - support for M5 and 4BF scalping
 *  - Grid: fix price levels
 *
 *  - ChartInfos
 *     include current daily range in ADR calculation/display
 *     improve pending order markers (it's not visible whether a TP/SL covers the full position)
 *      if TP exists => mark partial TP
 *      if SL exists => mark partial SL
 *
 *  - FATAL  BTCUSD,M5  ChartInfos::ParseDateTimeEx(5)  invalid history configuration in "TODAY 09:00"  [ERR_INVALID_CONFIG_VALUE]
 *  - on chart command
 *     NOTICE  BTCUSD,202  ChartInfos::rsfLib::AquireLock(6)  couldn't get lock on mutex "mutex.ChartInfos.command" after 1 sec, retrying...
 *     NOTICE  BTCUSD,202  ChartInfos::rsfLib::AquireLock(6)  couldn't get lock on mutex "mutex.ChartInfos.command" after 2 sec, retrying...
 *     NOTICE  BTCUSD,202  ChartInfos::rsfLib::AquireLock(6)  couldn't get lock on mutex "mutex.ChartInfos.command" after 3 sec, retrying...
 *     NOTICE  BTCUSD,202  ChartInfos::rsfLib::AquireLock(6)  couldn't get lock on mutex "mutex.ChartInfos.command" after 4 sec, retrying...
 *     NOTICE  BTCUSD,202  ChartInfos::rsfLib::AquireLock(6)  couldn't get lock on mutex "mutex.ChartInfos.command" after 5 sec, retrying...
 *     NOTICE  BTCUSD,202  ChartInfos::rsfLib::AquireLock(6)  couldn't get lock on mutex "mutex.ChartInfos.command" after 6 sec, retrying...
 *     NOTICE  BTCUSD,202  ChartInfos::rsfLib::AquireLock(6)  couldn't get lock on mutex "mutex.ChartInfos.command" after 7 sec, retrying...
 *     NOTICE  BTCUSD,202  ChartInfos::rsfLib::AquireLock(6)  couldn't get lock on mutex "mutex.ChartInfos.command" after 8 sec, retrying...
 *     NOTICE  BTCUSD,202  ChartInfos::rsfLib::AquireLock(6)  couldn't get lock on mutex "mutex.ChartInfos.command" after 9 sec, retrying...
 *     FATAL   BTCUSD,202  ChartInfos::rsfLib::AquireLock(5)  failed to get lock on mutex "mutex.ChartInfos.command" after 10 sec, giving up  [ERR_RUNTIME_ERROR]
 *
 *  - stop on reverse signal
 *  - signals MANUAL_LONG|MANUAL_SHORT
 *  - widen SL on manual positions in opposite direction
 *  - manage an existing manual order
 *  - track and display total slippage
 *  - reduce slippage on reversal: Close+Open => Hedge+CloseBy
 *  - reduce slippage on short reversal: enter market via StopSell
 *  - rename to Turtle EA
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
 *     analyze channel contraction
 *
 *  - visualization
 *     a chart profile per instrument
 *     rename groups/instruments/history descriptions
 *     ChartInfos: read/display symbol description as long name
 *
 *  - performance tracking
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
 *    - DAX: Global Prime has a session break at 23:00-23:03 (trade and quotes)
 *    - full session (24h) with trade breaks
 *    - partial session (e.g. 09:00-16:00) with trade breaks
 *    - trading is disabled but the price feed is active
 *    - configuration:
 *       default: auto-config using the SYMBOL configuration
 *       manual override of times and behaviors (per instance => via input parameters)
 *    - default behavior:
 *       no trade commands
 *       synchronize-after if an opposite signal occurred
 *    - manual behavior configuration:
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
 *  - remove input Slippage and handle it dynamically (e.g. via framework config)
 *     https://www.mql5.com/en/forum/120795
 *     https://www.mql5.com/en/forum/289014#comment_9296322
 *     https://www.mql5.com/en/forum/146808#comment_3701979  [ECN restriction removed since build 500]
 *     https://www.mql5.com/en/forum/146808#comment_3701981  [query execution mode in MQL]
 *  - merge inputs TakeProfit and StopConditions
 *  - add cache parameter to HistorySet.AddTick(), e.g. 30 sec.
 *
 *  - realtime equity charts
 *  - TradeManager for custom positions
 *     close new|all hedges
 *     support M5 scalping: close at condition (4BF, Breakeven, Trailing stop, MA turn, Donchian cross)
 *  - rewrite parameter stepping: remove commands from channel after processing
 *  - rewrite range bar generator
 *  - receivers for SendEmail()/SendSMS() must not be cached and always read from the config
 *  - VPS: monitor and notify of incoming emails
 *  - visual/audible confirmation for manual orders (to detect execution errors)
 *  - notifications for open positions running into swap charges
 *  - CLI tools to rename/update/delete symbols
 *  - fix log messages in ValidateInputs (conditionally display the sequence name)
 *  - implement GetAccountCompany() and read the name from the server file if not connected
 *  - move custom metric validation to EA
 *  - permanent spread logging to a separate logfile
 *  - move all history functionality to the Expander (fixes MQL max. open file limit of program=64/terminal=512)
 *  - pass input "EA.Recorder" to the Expander as a string
 *  - build script for all .EX4 files after deployment
 *  - ChartInfos::CostumPosition() weekend configuration/timespans don't work
 *  - ChartInfos::CostumPosition() including/excluding a specific strategy is not supported
 *  - ChartInfos: don't recalculate unitsize on every tick (every few seconds is sufficient)
 *  - Superbars: ETH/RTH separation for Frankfurt session
 *  - reverse sign of oe.Slippage() and fix unit in log messages (pip/money)
 *  - ChartInfos: update unitsize positioning
 *  - in-chart news hints (to not forget untypical ones like press conferences), check Anuko clock again
 *  - on restart delete dead screen sockets
 */
#include <stddefines.mqh>
int   __InitFlags[] = {INIT_PIPVALUE, INIT_BUFFERED_LOG};
int __DeinitFlags[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern string Sequence.ID          = "";                    // instance to load from a status file, format /T?[0-9]{3}/
extern string TradingMode          = "regular* | virtual";  // can be shortened if distinct

extern int    ZigZag.Periods       = 40;
extern double Lots                 = 0.1;
extern string StartConditions      = "";                    // @time(datetime|time)
extern string StopConditions       = "";                    // @time(datetime|time)          // TODO: @signal([long|short]), @breakeven(on-profit), @trail([on-profit:]stepsize)
extern double TakeProfit           = 0;                     // TP value
extern string TakeProfit.Type      = "off* | money | percent | pip | quote-unit";            // can be shortened if distinct        // TODO: redefine point as index point
extern int    Slippage             = 2;                     // in point

extern bool   ShowProfitInPercent  = true;                  // whether PL is displayed in money or percentage terms
extern bool   EA.RecorderAutoScale = false;                 // use adaptive multiplier for metrics in quote units

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/expert.mqh>
#include <stdfunctions.mqh>
#include <rsfLib.mqh>
#include <functions/HandleCommands.mqh>
#include <functions/ParseTime.mqh>
#include <structs/rsf/OrderExecution.mqh>

#define STRATEGY_ID               107           // unique strategy id (between 101-1023, 10 bit)
#define SID_MIN                   100           // range of valid sequence id values
#define SID_MAX                   999

#define STATUS_WAITING              1           // sequence status values
#define STATUS_PROGRESSING          2
#define STATUS_STOPPED              3

#define TRADINGMODE_REGULAR         1           // trading modes
#define TRADINGMODE_VIRTUAL         2

#define SIGNAL_LONG  TRADE_DIRECTION_LONG       // 1 start/stop/resume signal types
#define SIGNAL_SHORT TRADE_DIRECTION_SHORT      // 2
#define SIGNAL_TIME                 3
#define SIGNAL_TAKEPROFIT           4

#define HI_TICKET                   0           // trade history indexes
#define HI_LOTS                     1
#define HI_OPENTYPE                 2
#define HI_OPENTIME                 3
#define HI_OPENBID                  4
#define HI_OPENASK                  5
#define HI_OPENPRICE                6
#define HI_CLOSETIME                7
#define HI_CLOSEBID                 8
#define HI_CLOSEASK                 9
#define HI_CLOSEPRICE              10
#define HI_SLIPPAGE_P              11           // P: in pip
#define HI_SWAP_M                  12           // M: in account currency (money)
#define HI_COMMISSION_M            13           // U: in quote units
#define HI_GROSS_PROFIT_M          14
#define HI_NET_PROFIT_M            15

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

// sequence data
int      sequence.id;                           // instance id between 100-999
datetime sequence.created;
bool     sequence.isTest;                       // whether the sequence is a test
string   sequence.name = "";
int      sequence.status;
double   sequence.startEquityM;

double   sequence.openZeroProfitU;              // theoretical PL with zero spread and zero transaction costs
double   sequence.closedZeroProfitU;
double   sequence.totalZeroProfitU;             // open + close

double   sequence.openGrossProfitU;
double   sequence.closedGrossProfitU;
double   sequence.totalGrossProfitU;

double   sequence.openNetProfitU;
double   sequence.closedNetProfitU;
double   sequence.totalNetProfitU;

double   sequence.openNetProfitM;
double   sequence.closedNetProfitM;
double   sequence.totalNetProfitM;

double   sequence.maxNetProfitM;                // max. observed total net profit in account currency:   0...+n
double   sequence.maxNetDrawdownM;              // max. observed total net drawdown in account currency: -n...0

// order data
int      open.ticket;                           // one open position
int      open.type;
datetime open.time;
double   open.bid;
double   open.ask;
double   open.price;
double   open.stoploss;
double   open.slippageP;
double   open.swapM;
double   open.commissionM;
double   open.grossProfitM;
double   open.grossProfitU;
double   open.netProfitM;
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

bool     stop.profitQu.condition;               // whether a takeprofit condition in quote units is active (pip, index point, quote currency)
int      stop.profitQu.type;
double   stop.profitQu.value;
string   stop.profitQu.description = "";

// other
string   tradingModeDescriptions[] = {"", "regular", "virtual"};
string   tpTypeDescriptions     [] = {"off", "money", "percent", "pip", "quote currency", "index points"};

// caching vars to speed-up ShowStatus()
string   sTradingModeStatus[] = {"", "", "Virtual "};
string   sLots                = "";
string   sStartConditions     = "";
string   sStopConditions      = "";
string   sSequenceTotalNetPL  = "";
string   sSequencePlStats     = "";

// debug settings                               // configurable via framework config, see afterInit()
bool     test.onReversalPause     = false;      // whether to pause a test after a ZigZag reversal
bool     test.onSessionBreakPause = false;      // whether to pause a test after StopSequence(SIGNAL_TIME)
bool     test.onStopPause         = false;      // whether to pause a test after a final StopSequence()
bool     test.reduceStatusWrites  = true;       // whether to reduce status file writes in tester

#include <apps/zigzag-ea/init.mqh>
#include <apps/zigzag-ea/deinit.mqh>


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   if (!sequence.status) return(ERR_ILLEGAL_STATE);

   if (__isChart) HandleCommands();                            // process incoming commands

   if (sequence.status != STATUS_STOPPED) {
      int signal, zzSignal;
      IsZigZagSignal(zzSignal);                                // check ZigZag on every tick (signals occur anytime)

      if (sequence.status == STATUS_WAITING) {
         if (IsStartSignal(signal)) StartSequence(signal);
      }
      else if (sequence.status == STATUS_PROGRESSING) {
         if (UpdateStatus()) {
            if (IsStopSignal(signal))  StopSequence(signal);
            else if (zzSignal != NULL) ReverseSequence(zzSignal);
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
      switch (sequence.status) {
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
            log("onCommand(1)  "+ sequence.name + sDetail + DoubleQuoteStr(fullCmd), NO_ERROR, logLevel);
            return(StartSequence(signal));
      }
   }

   else if (cmd == "stop") {
      switch (sequence.status) {
         case STATUS_WAITING:
         case STATUS_PROGRESSING:
            logInfo("onCommand(2)  "+ sequence.name +" "+ DoubleQuoteStr(fullCmd));
            return(StopSequence(NULL));
      }
   }

   else if (cmd == "wait") {
      switch (sequence.status) {
         case STATUS_STOPPED:
            logInfo("onCommand(3)  "+ sequence.name +" "+ DoubleQuoteStr(fullCmd));
            sequence.status = STATUS_WAITING;
            return(SaveStatus());
      }
   }

   else if (cmd == "toggle-open-orders") {
      return(ToggleOpenOrders());
   }

   else if (cmd == "toggle-trade-history") {
      return(ToggleTradeHistory());
   }
   else return(!logNotice("onCommand(4)  "+ sequence.name +" unsupported command: "+ DoubleQuoteStr(fullCmd)));

   return(!logWarn("onCommand(5)  "+ sequence.name +" cannot execute command "+ DoubleQuoteStr(fullCmd) +" in status "+ StatusToStr(sequence.status)));
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
      ObjectSetText(label, sequence.name);
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
      int      ticket     = history[i][HI_TICKET    ];
      int      type       = history[i][HI_OPENTYPE  ];
      double   lots       = history[i][HI_LOTS      ];
      datetime openTime   = history[i][HI_OPENTIME  ];
      double   openPrice  = history[i][HI_OPENPRICE ];
      datetime closeTime  = history[i][HI_CLOSETIME ];
      double   closePrice = history[i][HI_CLOSEPRICE];

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
      ObjectSetText(openLabel, sequence.name);

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
      ObjectSetText(closeLabel, sequence.name);
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
      if (recorder.enabled[METRIC_TOTAL_UNITS_ZERO ]) recorder.currValue[METRIC_TOTAL_UNITS_ZERO ] = sequence.totalZeroProfitU;
      if (recorder.enabled[METRIC_TOTAL_UNITS_GROSS]) recorder.currValue[METRIC_TOTAL_UNITS_GROSS] = sequence.totalGrossProfitU;
      if (recorder.enabled[METRIC_TOTAL_UNITS_NET  ]) recorder.currValue[METRIC_TOTAL_UNITS_NET  ] = sequence.totalNetProfitU;
      if (recorder.enabled[METRIC_TOTAL_MONEY_NET  ]) recorder.currValue[METRIC_TOTAL_MONEY_NET  ] = sequence.totalNetProfitM;
   }
}


/**
 * Whether a new ZigZag reversal occurred.
 *
 * @param  _Out_ int &signal - variable receiving the identifier of an occurred reversal
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

      if (Abs(trend)==reversal || !reversal) {     // reversal=0 describes a double crossing, trend is +1 or -1
         if (trend > 0) {
            if (lastSignal != SIGNAL_LONG)  signal = SIGNAL_LONG;
         }
         else {
            if (lastSignal != SIGNAL_SHORT) signal = SIGNAL_SHORT;
         }
         if (signal != NULL) {
            if (sequence.status == STATUS_PROGRESSING) {
               if (IsLogInfo()) logInfo("IsZigZagSignal(1)  "+ sequence.name +" "+ ifString(signal==SIGNAL_LONG, "long", "short") +" reversal (market: "+ NumberToStr(Bid, PriceFormat) +"/"+ NumberToStr(Ask, PriceFormat) +")");
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
 * @param  _Out_ int &reversal      - bar offset of the current ZigZag reversal to the previous ZigZag extreme
 *
 * @return bool - success status
 */
bool GetZigZagTrendData(int bar, int &combinedTrend, int &reversal) {
   combinedTrend = Round(icZigZag(NULL, ZigZag.Periods, ZigZag.MODE_TREND,    bar));
   reversal      = Round(icZigZag(NULL, ZigZag.Periods, ZigZag.MODE_REVERSAL, bar));
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
   if (mode!=MODE_TRADESERVER && mode!=MODE_STRATEGY) return(!catch("IsTradingBreak(1)  "+ sequence.name +" invalid parameter mode: "+ mode, ERR_INVALID_PARAMETER));
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

      if (IsLogDebug()) logDebug("IsTradingBreak(2)  "+ sequence.name +" recalculated "+ ifString(srvNow >= stopTime, "current", "next") + ifString(mode==MODE_TRADESERVER, " trade session", " strategy") +" stop \""+ TimeToStr(startOffset, TIME_MINUTES) +"-"+ TimeToStr(stopOffset, TIME_MINUTES) +"\" as "+ GmtTimeFormat(stopTime, "%a, %Y.%m.%d %H:%M:%S") +" to "+ GmtTimeFormat(nextStartTime, "%a, %Y.%m.%d %H:%M:%S"));
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
 * Whether a start condition is satisfied for a sequence.
 *
 * @param  _Out_ int &signal - variable receiving the identifier of a satisfied condition
 *
 * @return bool
 */
bool IsStartSignal(int &signal) {
   signal = NULL;
   if (last_error || sequence.status!=STATUS_WAITING) return(false);

   // start.time: -----------------------------------------------------------------------------------------------------------
   if (!IsTradingTime()) {
      return(false);
   }

   // ZigZag signal: --------------------------------------------------------------------------------------------------------
   if (IsZigZagSignal(signal)) {
      bool sequenceWasStarted = (open.ticket || ArrayRange(history, 0));
      int loglevel = ifInt(sequenceWasStarted, LOG_INFO, LOG_NOTICE);
      log("IsStartSignal(2)  "+ sequence.name +" ZigZag "+ ifString(signal==SIGNAL_LONG, "long", "short") +" reversal (market: "+ NumberToStr(Bid, PriceFormat) +"/"+ NumberToStr(Ask, PriceFormat) +")", NULL, loglevel);
      return(true);
   }
   return(false);
}


/**
 * Whether a stop condition is satisfied for a sequence.
 *
 * @param  _Out_ int &signal - variable receiving the identifier of a satisfied condition
 *
 * @return bool
 */
bool IsStopSignal(int &signal) {
   signal = NULL;
   if (last_error || (sequence.status!=STATUS_WAITING && sequence.status!=STATUS_PROGRESSING)) return(false);

   if (sequence.status == STATUS_PROGRESSING) {
      // stop.profitAbs: ----------------------------------------------------------------------------------------------------
      if (stop.profitAbs.condition) {
         if (sequence.totalNetProfitM >= stop.profitAbs.value) {
            signal = SIGNAL_TAKEPROFIT;
            if (IsLogNotice()) logNotice("IsStopSignal(1)  "+ sequence.name +" stop condition \"@"+ stop.profitAbs.description +"\" satisfied (market: "+ NumberToStr(Bid, PriceFormat) +"/"+ NumberToStr(Ask, PriceFormat) +")");
            return(true);
         }
      }

      // stop.profitPct: ----------------------------------------------------------------------------------------------------
      if (stop.profitPct.condition) {
         if (stop.profitPct.absValue == INT_MAX)
            stop.profitPct.absValue = stop.profitPct.AbsValue();

         if (sequence.totalNetProfitM >= stop.profitPct.absValue) {
            signal = SIGNAL_TAKEPROFIT;
            if (IsLogNotice()) logNotice("IsStopSignal(2)  "+ sequence.name +" stop condition \"@"+ stop.profitPct.description +"\" satisfied (market: "+ NumberToStr(Bid, PriceFormat) +"/"+ NumberToStr(Ask, PriceFormat) +")");
            return(true);
         }
      }

      // stop.profitQu: -----------------------------------------------------------------------------------------------------
      if (stop.profitQu.condition) {
         if (sequence.totalNetProfitU >= stop.profitQu.value) {
            signal = SIGNAL_TAKEPROFIT;
            if (IsLogNotice()) logNotice("IsStopSignal(3)  "+ sequence.name +" stop condition \"@"+ stop.profitQu.description +"\" satisfied (market: "+ NumberToStr(Bid, PriceFormat) +"/"+ NumberToStr(Ask, PriceFormat) +")");
            return(true);
         }
      }
   }

   // stop.time: ------------------------------------------------------------------------------------------------------------
   if (stop.time.condition) {
      if (!IsTradingTime()) {
         signal = SIGNAL_TIME;
         if (IsLogInfo()) logInfo("IsStopSignal(4)  "+ sequence.name +" stop condition \"@"+ stop.time.description +"\" satisfied (market: "+ NumberToStr(Bid, PriceFormat) +"/"+ NumberToStr(Ask, PriceFormat) +")");
         return(true);
      }
   }
   return(false);
}


/**
 * Start a waiting or restart a stopped sequence.
 *
 * @param  int signal - trade signal causing the call
 *
 * @return bool - success status
 */
bool StartSequence(int signal) {
   if (last_error != NULL)                                                 return(false);
   if (sequence.status!=STATUS_WAITING && sequence.status!=STATUS_STOPPED) return(!catch("StartSequence(1)  "+ sequence.name +" cannot start "+ StatusDescription(sequence.status) +" sequence", ERR_ILLEGAL_STATE));
   if (signal!=SIGNAL_LONG && signal!=SIGNAL_SHORT)                        return(!catch("StartSequence(2)  "+ sequence.name +" invalid parameter signal: "+ signal, ERR_INVALID_PARAMETER));
   if (tradingMode == TRADINGMODE_VIRTUAL)                                 return(StartVirtualSequence(signal));

   if (IsLogInfo()) logInfo("StartSequence(3)  "+ sequence.name +" starting ("+ SignalToStr(signal) +")");

   sequence.status = STATUS_PROGRESSING;
   if (!sequence.startEquityM) sequence.startEquityM = NormalizeDouble(AccountEquity() - AccountCredit() + GetExternalAssets(), 2);

   // open a new position
   int      type        = ifInt(signal==SIGNAL_LONG, OP_BUY, OP_SELL);
   double   bid         = Bid;
   double   ask         = Ask;
   double   price       = NULL;
   double   stopLoss    = CalculateStopLoss(signal);
   double   takeProfit  = NULL;
   datetime expires     = NULL;
   string   comment     = "ZigZag."+ sequence.name;
   int      magicNumber = CalculateMagicNumber();
   color    markerColor = ifInt(signal==SIGNAL_LONG, CLR_OPEN_LONG, CLR_OPEN_SHORT);
   int      oeFlags     = NULL, oe[];

   int ticket = OrderSendEx(Symbol(), type, Lots, price, Slippage, stopLoss, takeProfit, comment, magicNumber, expires, markerColor, oeFlags, oe);
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
   open.slippageP    = -oe.Slippage (oe);
   open.swapM        = oe.Swap      (oe);
   open.commissionM  = oe.Commission(oe);
   open.grossProfitM = oe.Profit    (oe);
   open.grossProfitU = ifDouble(!type, currentBid-open.price, open.price-currentAsk);
   open.netProfitM   = open.grossProfitM + open.swapM + open.commissionM;
   open.netProfitU   = open.grossProfitU + (open.swapM + open.commissionM)/QuoteUnitValue(Lots);

   // update PL numbers
   sequence.openZeroProfitU  = ifDouble(!type, currentBid-open.bid, open.bid-currentBid);    // both directions use Bid prices
   sequence.totalZeroProfitU = sequence.openZeroProfitU + sequence.closedZeroProfitU;

   sequence.openGrossProfitU  = open.grossProfitU;
   sequence.totalGrossProfitU = sequence.openGrossProfitU + sequence.closedGrossProfitU;

   sequence.openNetProfitU  = open.netProfitU;
   sequence.totalNetProfitU = sequence.openNetProfitU + sequence.closedNetProfitU;

   sequence.openNetProfitM  = open.netProfitM;
   sequence.totalNetProfitM = sequence.openNetProfitM + sequence.closedNetProfitM;

   sequence.maxNetProfitM   = MathMax(sequence.maxNetProfitM, sequence.totalNetProfitM);
   sequence.maxNetDrawdownM = MathMin(sequence.maxNetDrawdownM, sequence.totalNetProfitM);
   SS.TotalPL();
   SS.PLStats();

   // update start conditions
   if (start.time.condition) {
      if (!start.time.isDaily || !stop.time.condition) {                                     // see start/stop time variants
         start.time.condition = false;
      }
   }
   SS.StartStopConditions();

   if (IsLogInfo()) logInfo("StartSequence(5)  "+ sequence.name +" sequence started ("+ SignalToStr(signal) +")");
   return(SaveStatus());
}


/**
 * Start a waiting virtual sequence.
 *
 * @param  int signal - trade signal causing the call
 *
 * @return bool - success status
 */
bool StartVirtualSequence(int signal) {
   if (IsLogInfo()) logInfo("StartVirtualSequence(1)  "+ sequence.name +" starting ("+ SignalToStr(signal) +")");

   sequence.status = STATUS_PROGRESSING;
   if (!sequence.startEquityM) sequence.startEquityM = NormalizeDouble(AccountEquity() - AccountCredit() + GetExternalAssets(), 2);

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
   open.slippageP    = 0;
   open.swapM        = 0;
   open.commissionM  = 0;
   open.grossProfitU = Bid-Ask;
   open.grossProfitM = open.grossProfitU * QuoteUnitValue(Lots);
   open.netProfitU   = open.grossProfitU;
   open.netProfitM   = open.grossProfitM;

   // update PL numbers
   sequence.openZeroProfitU  = 0;
   sequence.totalZeroProfitU = sequence.openZeroProfitU + sequence.closedZeroProfitU;

   sequence.openGrossProfitU  = open.grossProfitU;
   sequence.totalGrossProfitU = sequence.openGrossProfitU + sequence.closedGrossProfitU;

   sequence.openNetProfitU  = open.netProfitU;
   sequence.totalNetProfitU = sequence.openNetProfitU + sequence.closedNetProfitU;

   sequence.openNetProfitM  = open.netProfitM;
   sequence.totalNetProfitM = sequence.openNetProfitM + sequence.closedNetProfitM;

   sequence.maxNetProfitM   = MathMax(sequence.maxNetProfitM, sequence.totalNetProfitM);
   sequence.maxNetDrawdownM = MathMin(sequence.maxNetDrawdownM, sequence.totalNetProfitM);
   SS.TotalPL();
   SS.PLStats();

   // update start conditions
   if (start.time.condition) {
      if (!start.time.isDaily || !stop.time.condition) {          // see start/stop time variants
         start.time.condition = false;
      }
   }
   SS.StartStopConditions();

   if (IsLogInfo()) logInfo("StartVirtualSequence(2)  "+ sequence.name +" sequence started ("+ SignalToStr(signal) +")");
   return(SaveStatus());
}


/**
 * Reverse a progressing sequence.
 *
 * @param  int signal - trade signal causing the call
 *
 * @return bool - success status
 */
bool ReverseSequence(int signal) {
   if (last_error != NULL)                          return(false);
   if (sequence.status != STATUS_PROGRESSING)       return(!catch("ReverseSequence(1)  "+ sequence.name +" cannot reverse "+ StatusDescription(sequence.status) +" sequence", ERR_ILLEGAL_STATE));
   if (signal!=SIGNAL_LONG && signal!=SIGNAL_SHORT) return(!catch("ReverseSequence(2)  "+ sequence.name +" invalid parameter signal: "+ signal, ERR_INVALID_PARAMETER));
   if (tradingMode == TRADINGMODE_VIRTUAL)          return(ReverseVirtualSequence(signal));

   double bid = Bid, ask = Ask;

   if (open.ticket > 0) {
      // continue in the same direction...
      if ((open.type==OP_BUY && signal==SIGNAL_LONG) || (open.type==OP_SELL && signal==SIGNAL_SHORT)) {
         logNotice("ReverseSequence(3)  "+ sequence.name +" to "+ ifString(signal==SIGNAL_LONG, "long", "short") +": continuing with already open "+ ifString(signal==SIGNAL_LONG, "long", "short") +" position #"+ open.ticket);
         return(true);
      }
      // ...or close the open position
      int oe[], oeFlags=F_ERR_INVALID_TRADE_PARAMETERS | F_LOG_NOTICE;     // the SL may be triggered/position closed between UpdateStatus() and ReverseSequence()

      bool success = OrderCloseEx(open.ticket, NULL, Slippage, CLR_NONE, oeFlags, oe);
      if (!success && oe.Error(oe)!=ERR_INVALID_TRADE_PARAMETERS) return(!SetLastError(oe.Error(oe)));

      if (!ArchiveClosedPosition(open.ticket, ifDouble(success, bid, 0), ifDouble(success, ask, 0), ifDouble(success, -oe.Slippage(oe), 0))) return(false);
   }

   // open a new position
   int      type        = ifInt(signal==SIGNAL_LONG, OP_BUY, OP_SELL);
   double   price       = NULL;
   double   stopLoss    = CalculateStopLoss(signal);
   double   takeProfit  = NULL;
   datetime expires     = NULL;
   string   comment     = "ZigZag."+ sequence.name;
   int      magicNumber = CalculateMagicNumber();
   color    markerColor = ifInt(type==OP_BUY, CLR_OPEN_LONG, CLR_OPEN_SHORT);

   if (!OrderSendEx(Symbol(), type, Lots, price, Slippage, stopLoss, takeProfit, comment, magicNumber, expires, markerColor, oeFlags, oe)) return(!SetLastError(oe.Error(oe)));

   // store the new position data
   double currentBid = MarketInfo(Symbol(), MODE_BID), currentAsk = MarketInfo(Symbol(), MODE_ASK);
   open.bid          = bid;
   open.ask          = ask;
   open.ticket       = oe.Ticket    (oe);
   open.type         = oe.Type      (oe);
   open.time         = oe.OpenTime  (oe);
   open.price        = oe.OpenPrice (oe);
   open.stoploss     = oe.StopLoss  (oe);
   open.slippageP    = oe.Slippage  (oe);
   open.swapM        = oe.Swap      (oe);
   open.commissionM  = oe.Commission(oe);
   open.grossProfitM = oe.Profit    (oe);
   open.grossProfitU = ifDouble(!type, currentBid-open.price, open.price-currentAsk);
   open.netProfitM   = open.grossProfitM + open.swapM + open.commissionM;
   open.netProfitU   = open.grossProfitU + (open.swapM + open.commissionM)/QuoteUnitValue(Lots);

   // update PL numbers
   sequence.openZeroProfitU  = ifDouble(!type, currentBid-open.bid, open.bid-currentBid); // both directions use Bid prices
   sequence.totalZeroProfitU = sequence.openZeroProfitU + sequence.closedZeroProfitU;

   sequence.openGrossProfitU  = open.grossProfitU;
   sequence.totalGrossProfitU = sequence.openGrossProfitU + sequence.closedGrossProfitU;

   sequence.openNetProfitU  = open.netProfitU;
   sequence.totalNetProfitU = sequence.openNetProfitU + sequence.closedNetProfitU;

   sequence.openNetProfitM  = open.netProfitM;
   sequence.totalNetProfitM = sequence.openNetProfitM + sequence.closedNetProfitM;

   sequence.maxNetProfitM   = MathMax(sequence.maxNetProfitM, sequence.totalNetProfitM);
   sequence.maxNetDrawdownM = MathMin(sequence.maxNetDrawdownM, sequence.totalNetProfitM);
   SS.TotalPL();
   SS.PLStats();

   return(SaveStatus());
}


/**
 * Reverse a progressing virtual sequence.
 *
 * @param  int signal - trade signal causing the call
 *
 * @return bool - success status
 */
bool ReverseVirtualSequence(int signal) {
   if (open.ticket > 0) {
      // continue in the same direction...
      if ((open.type==OP_BUY && signal==SIGNAL_LONG) || (open.type==OP_SELL && signal==SIGNAL_SHORT)) {
         logWarn("ReverseVirtualSequence(1)  "+ sequence.name +" to "+ ifString(signal==SIGNAL_LONG, "long", "short") +": continuing with already open virtual "+ ifString(signal==SIGNAL_LONG, "long", "short") +" position");
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
   open.slippageP    = 0;
   open.swapM        = 0;
   open.commissionM  = 0;
   open.grossProfitU = Bid-Ask;
   open.grossProfitM = open.grossProfitU * QuoteUnitValue(Lots);
   open.netProfitU   = open.grossProfitU;
   open.netProfitM   = open.grossProfitM;

   // update PL numbers
   sequence.openZeroProfitU  = 0;
   sequence.totalZeroProfitU = sequence.openZeroProfitU + sequence.closedZeroProfitU;

   sequence.openGrossProfitU  = open.grossProfitU;
   sequence.totalGrossProfitU = sequence.openGrossProfitU + sequence.closedGrossProfitU;

   sequence.openNetProfitU  = open.netProfitU;
   sequence.totalNetProfitU = sequence.openNetProfitU + sequence.closedNetProfitU;

   sequence.openNetProfitM  = open.netProfitM;
   sequence.totalNetProfitM = sequence.openNetProfitM + sequence.closedNetProfitM;

   sequence.maxNetProfitM   = MathMax(sequence.maxNetProfitM, sequence.totalNetProfitM);
   sequence.maxNetDrawdownM = MathMin(sequence.maxNetDrawdownM, sequence.totalNetProfitM);
   SS.TotalPL();
   SS.PLStats();
   return(SaveStatus());
}


/**
 * Add trade details of the specified ticket to the local history and reset open position data.
 *
 * @param int    ticket   - closed ticket
 * @param double bid      - Bid price before the position was closed
 * @param double ask      - Ask price before the position was closed
 * @param double slippage - close slippage in pip
 *
 * @return bool - success status
 */
bool ArchiveClosedPosition(int ticket, double bid, double ask, double slippage) {
   if (last_error != NULL)                    return(false);
   if (sequence.status != STATUS_PROGRESSING) return(!catch("ArchiveClosedPosition(1)  "+ sequence.name +" cannot archive position of "+ StatusDescription(sequence.status) +" sequence", ERR_ILLEGAL_STATE));

   SelectTicket(ticket, "ArchiveClosedPosition(2)", /*push=*/true);

   // update now closed position data
   open.swapM        = OrderSwap();
   open.commissionM  = OrderCommission();
   open.grossProfitM = OrderProfit();
   open.netProfitM   = open.grossProfitM + open.swapM + open.commissionM;

   if (!OrderLots()) {                 // it may be a hedge counterpart with Lots=0.0 (#465291275 Buy 0.0 US500 at 4'522.30, closed...
      open.grossProfitU = NULL;        // ...at 4'522.30, commission=0.00, swap=0.00, profit=0.00, magicNumber=448817408, comment="close hedge by #465308924")
      open.netProfitU   = NULL;
   }
   else {
      open.grossProfitU = ifDouble(!OrderType(), OrderClosePrice()-OrderOpenPrice(), OrderOpenPrice()-OrderClosePrice());
      open.netProfitU   = open.grossProfitU + (open.swapM + open.commissionM)/QuoteUnitValue(OrderLots());
   }

   // update history
   int i = ArrayRange(history, 0);
   ArrayResize(history, i + 1);
   history[i][HI_TICKET        ] = ticket;
   history[i][HI_LOTS          ] = OrderLots();
   history[i][HI_OPENTYPE      ] = OrderType();
   history[i][HI_OPENTIME      ] = OrderOpenTime();
   history[i][HI_OPENBID       ] = open.bid;
   history[i][HI_OPENASK       ] = open.ask;
   history[i][HI_OPENPRICE     ] = OrderOpenPrice();
   history[i][HI_CLOSETIME     ] = OrderCloseTime();
   history[i][HI_CLOSEBID      ] = doubleOr(bid, OrderClosePrice());
   history[i][HI_CLOSEASK      ] = doubleOr(ask, OrderClosePrice());
   history[i][HI_CLOSEPRICE    ] = OrderClosePrice();
   history[i][HI_SLIPPAGE_P    ] = open.slippageP + slippage;
   history[i][HI_SWAP_M        ] = open.swapM;
   history[i][HI_COMMISSION_M  ] = open.commissionM;
   history[i][HI_GROSS_PROFIT_M] = open.grossProfitM;
   history[i][HI_NET_PROFIT_M  ] = open.netProfitM;
   OrderPop("ArchiveClosedPosition(3)");

   // update PL numbers
   sequence.openZeroProfitU    = 0;                                           // both directions use Bid prices
   sequence.closedZeroProfitU += ifDouble(!open.type, history[i][HI_CLOSEBID]-open.bid, open.bid-history[i][HI_CLOSEBID]);
   sequence.totalZeroProfitU   = sequence.closedZeroProfitU;

   sequence.openGrossProfitU    = 0;
   sequence.closedGrossProfitU += open.grossProfitU;
   sequence.totalGrossProfitU   = sequence.closedGrossProfitU;

   sequence.openNetProfitU    = 0;
   sequence.closedNetProfitU += open.netProfitU;
   sequence.totalNetProfitU   = sequence.closedNetProfitU;

   sequence.openNetProfitM    = 0;
   sequence.closedNetProfitM += open.netProfitM;
   sequence.totalNetProfitM   = sequence.closedNetProfitM;

   // reset open position data
   open.ticket       = NULL;
   open.type         = NULL;
   open.time         = NULL;
   open.bid          = NULL;
   open.ask          = NULL;
   open.price        = NULL;
   open.stoploss     = NULL;
   open.slippageP    = NULL;
   open.swapM        = NULL;
   open.commissionM  = NULL;
   open.grossProfitM = NULL;
   open.grossProfitU = NULL;
   open.netProfitM   = NULL;
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
   if (sequence.status != STATUS_PROGRESSING) return(!catch("ArchiveClosedVirtualPosition(1)  "+ sequence.name +" cannot archive virtual position of "+ StatusDescription(sequence.status) +" sequence", ERR_ILLEGAL_STATE));
   if (ticket != open.ticket)                 return(!catch("ArchiveClosedVirtualPosition(2)  "+ sequence.name +" ticket/open.ticket mis-match: "+ ticket +"/"+ open.ticket, ERR_ILLEGAL_STATE));

   // update now closed position data
   open.swapM        = 0;
   open.commissionM  = 0;
   open.grossProfitU = ifDouble(!open.type, Bid-open.price, open.price-Ask);
   open.grossProfitM = open.grossProfitU * QuoteUnitValue(Lots);
   open.netProfitU   = open.grossProfitU;
   open.netProfitM   = open.grossProfitM;

   // update history
   int i = ArrayRange(history, 0);
   ArrayResize(history, i + 1);
   history[i][HI_TICKET        ] = ticket;
   history[i][HI_LOTS          ] = Lots;
   history[i][HI_OPENTYPE      ] = open.type;
   history[i][HI_OPENTIME      ] = open.time;
   history[i][HI_OPENBID       ] = open.bid;
   history[i][HI_OPENASK       ] = open.ask;
   history[i][HI_OPENPRICE     ] = open.price;
   history[i][HI_CLOSETIME     ] = Tick.time;
   history[i][HI_CLOSEBID      ] = Bid;
   history[i][HI_CLOSEASK      ] = Ask;
   history[i][HI_CLOSEPRICE    ] = ifDouble(!open.type, Bid, Ask);
   history[i][HI_SLIPPAGE_P    ] = open.slippageP;
   history[i][HI_SWAP_M        ] = open.swapM;
   history[i][HI_COMMISSION_M  ] = open.commissionM;
   history[i][HI_GROSS_PROFIT_M] = open.grossProfitM;
   history[i][HI_NET_PROFIT_M  ] = open.netProfitM;

   // update PL numbers
   sequence.openZeroProfitU    = 0;                                           // both directions use Bid prices
   sequence.closedZeroProfitU += ifDouble(!open.type, history[i][HI_CLOSEBID]-open.bid, open.bid-history[i][HI_CLOSEBID]);
   sequence.totalZeroProfitU   = sequence.closedZeroProfitU;

   sequence.openGrossProfitU    = 0;
   sequence.closedGrossProfitU += open.grossProfitU;
   sequence.totalGrossProfitU   = sequence.closedGrossProfitU;

   sequence.openNetProfitU    = 0;
   sequence.closedNetProfitU += open.netProfitU;
   sequence.totalNetProfitU   = sequence.closedNetProfitU;

   sequence.openNetProfitM    = 0;
   sequence.closedNetProfitM += open.netProfitM;
   sequence.totalNetProfitM   = sequence.closedNetProfitM;

   // reset open position data
   open.ticket       = NULL;
   open.type         = NULL;
   open.time         = NULL;
   open.bid          = NULL;
   open.ask          = NULL;
   open.price        = NULL;
   open.slippageP    = NULL;
   open.swapM        = NULL;
   open.commissionM  = NULL;
   open.grossProfitM = NULL;
   open.grossProfitU = NULL;
   open.netProfitM   = NULL;
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
   if (direction!=SIGNAL_LONG && direction!=SIGNAL_SHORT) return(!catch("CalculateStopLoss(1)  "+ sequence.name +" invalid parameter direction: "+ direction, ERR_INVALID_PARAMETER));

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
         double startEquity = sequence.startEquityM;
         if (!startEquity) startEquity = AccountEquity() - AccountCredit() + GetExternalAssets();
         return(stop.profitPct.value/100 * startEquity);
      }
   }
   return(stop.profitPct.absValue);
}


/**
 * Stop a waiting progressing sequence and close open positions (if any).
 *
 * @param  int signal - signal which triggered the stop condition or NULL on explicit stop (i.e. manual)
 *
 * @return bool - success status
 */
bool StopSequence(int signal) {
   if (last_error != NULL)                                                     return(false);
   if (sequence.status!=STATUS_WAITING && sequence.status!=STATUS_PROGRESSING) return(!catch("StopSequence(1)  "+ sequence.name +" cannot stop "+ StatusDescription(sequence.status) +" sequence", ERR_ILLEGAL_STATE));
   if (tradingMode == TRADINGMODE_VIRTUAL)                                     return(StopVirtualSequence(signal));

   // close open positions
   if (sequence.status == STATUS_PROGRESSING) {
      if (open.ticket > 0) {
         if (IsLogInfo()) logInfo("StopSequence(2)  "+ sequence.name +" stopping ("+ SignalToStr(signal) +")");

         double bid = Bid, ask = Ask;
         int oeFlags, oe[];

         if (!OrderCloseEx(open.ticket, NULL, Slippage, CLR_NONE, oeFlags, oe)) return(!SetLastError(oe.Error(oe)));
         if (!ArchiveClosedPosition(open.ticket, bid, ask, -oe.Slippage(oe)))   return(false);

         sequence.maxNetProfitM   = MathMax(sequence.maxNetProfitM, sequence.totalNetProfitM);
         sequence.maxNetDrawdownM = MathMin(sequence.maxNetDrawdownM, sequence.totalNetProfitM);
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
         sequence.status = ifInt(start.time.condition && start.time.isDaily, STATUS_WAITING, STATUS_STOPPED);
         break;

      case SIGNAL_TAKEPROFIT:
         stop.profitAbs.condition = false;
         stop.profitPct.condition = false;
         stop.profitQu.condition  = false;
         sequence.status          = STATUS_STOPPED;
         break;

      case NULL:                                            // explicit stop (manual) or end of test
         sequence.status = STATUS_STOPPED;
         break;

      default: return(!catch("StopSequence(4)  "+ sequence.name +" invalid parameter signal: "+ signal, ERR_INVALID_PARAMETER));
   }
   SS.StartStopConditions();

   if (IsLogInfo()) logInfo("StopSequence(5)  "+ sequence.name +" "+ ifString(__isTesting && !signal, "test ", "") +"sequence stopped"+ ifString(!signal, "", " ("+ SignalToStr(signal) +")") +", profit: "+ sSequenceTotalNetPL +" "+ StrReplace(sSequencePlStats, " ", ""));
   SaveStatus();

   // pause/stop the tester according to the debug configuration
   if (__isTesting) {
      if      (!IsVisualMode())       { if (sequence.status == STATUS_STOPPED) Tester.Stop ("StopSequence(6)"); }
      else if (signal == SIGNAL_TIME) { if (test.onSessionBreakPause)          Tester.Pause("StopSequence(7)"); }
      else                            { if (test.onStopPause)                  Tester.Pause("StopSequence(8)"); }
   }
   return(!catch("StopSequence(9)"));
}


/**
 * Stop a waiting or progressing virtual sequence. Close open positions (if any).
 *
 * @param  int signal - signal which triggered the stop condition or NULL on explicit (i.e. manual) stop
 *
 * @return bool - success status
 */
bool StopVirtualSequence(int signal) {
   // close open positions
   if (sequence.status == STATUS_PROGRESSING) {
      if (open.ticket > 0) {
         VirtualOrderClose(open.ticket);
         ArchiveClosedVirtualPosition(open.ticket);

         sequence.maxNetProfitM   = MathMax(sequence.maxNetProfitM, sequence.totalNetProfitM);
         sequence.maxNetDrawdownM = MathMin(sequence.maxNetDrawdownM, sequence.totalNetProfitM);
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
         sequence.status = ifInt(start.time.condition && start.time.isDaily, STATUS_WAITING, STATUS_STOPPED);
         break;

      case SIGNAL_TAKEPROFIT:
         stop.profitAbs.condition = false;
         stop.profitPct.condition = false;
         stop.profitQu.condition  = false;
         sequence.status          = STATUS_STOPPED;
         break;

      case NULL:                                            // explicit stop (manual) or end of test
         sequence.status = STATUS_STOPPED;
         break;

      default: return(!catch("StopVirtualSequence(1)  "+ sequence.name +" invalid parameter signal: "+ signal, ERR_INVALID_PARAMETER));
   }
   SS.StartStopConditions();

   if (IsLogInfo()) logInfo("StopVirtualSequence(2)  "+ sequence.name +" "+ ifString(__isTesting && !signal, "test ", "") +"sequence stopped"+ ifString(!signal, "", " ("+ SignalToStr(signal) +")") +", profit: "+ sSequenceTotalNetPL +" "+ StrReplace(sSequencePlStats, " ", ""));
   SaveStatus();

   // pause/stop the tester according to the debug configuration
   if (__isTesting) {
      if      (!IsVisualMode())       { if (sequence.status == STATUS_STOPPED) Tester.Stop ("StopSequence(6)"); }
      else if (signal == SIGNAL_TIME) { if (test.onSessionBreakPause)          Tester.Pause("StopSequence(7)"); }
      else                            { if (test.onStopPause)                  Tester.Pause("StopSequence(8)"); }
   }
   return(!catch("StopVirtualSequence(3)"));
}


/**
 * Update order status and PL.
 *
 * @return bool - success status
 */
bool UpdateStatus() {
   if (last_error != NULL)                    return(false);
   if (sequence.status != STATUS_PROGRESSING) return(!catch("UpdateStatus(1)  "+ sequence.name +" cannot update order status of "+ StatusDescription(sequence.status) +" sequence", ERR_ILLEGAL_STATE));
   if (tradingMode == TRADINGMODE_VIRTUAL)    return(UpdateVirtualStatus());
   int error;

   if (open.ticket > 0) {
      if (!SelectTicket(open.ticket, "UpdateStatus(2)")) return(false);
      bool isOpen = !OrderCloseTime();

      open.swapM        = OrderSwap();
      open.commissionM  = OrderCommission();
      open.grossProfitM = OrderProfit();
      open.netProfitM   = open.grossProfitM + open.swapM + open.commissionM;

      if (!OrderLots()) {                 // if already closed it may be a hedge counterpart with Lots=0.0 (#465291275 Buy 0.0 US500 at 4'522.30, closed...
         open.grossProfitU = 0;           // ...at 4'522.30, commission=0.00, swap=0.00, profit=0.00, magicNumber=448817408, comment="close hedge by #465308924")
         open.netProfitU   = 0;
      }
      else {
         open.grossProfitU = ifDouble(!open.type, Bid-open.price, open.price-Ask);
         open.netProfitU   = open.grossProfitU + (open.swapM + open.commissionM)/QuoteUnitValue(OrderLots());
      }

      if (isOpen) {
         sequence.openZeroProfitU  = ifDouble(!open.type, Bid-open.bid, open.bid-Bid);    // both directions use Bid prices
         sequence.openGrossProfitU = open.grossProfitU;
         sequence.openNetProfitU   = open.netProfitU;
         sequence.openNetProfitM   = open.netProfitM;
      }
      else {
         if (IsError(onPositionClose("UpdateStatus(3)  "+ sequence.name +" "+ UpdateStatus.PositionCloseMsg(error), error))) return(false);
         if (!ArchiveClosedPosition(open.ticket, NULL, NULL, NULL)) return(false);
      }
      sequence.totalZeroProfitU  = sequence.openZeroProfitU  + sequence.closedZeroProfitU;
      sequence.totalGrossProfitU = sequence.openGrossProfitU + sequence.closedGrossProfitU;
      sequence.totalNetProfitU   = sequence.openNetProfitU   + sequence.closedNetProfitU;
      sequence.totalNetProfitM   = sequence.openNetProfitM   + sequence.closedNetProfitM; SS.TotalPL();

      if      (sequence.totalNetProfitM > sequence.maxNetProfitM  ) { sequence.maxNetProfitM   = sequence.totalNetProfitM; SS.PLStats(); }
      else if (sequence.totalNetProfitM < sequence.maxNetDrawdownM) { sequence.maxNetDrawdownM = sequence.totalNetProfitM; SS.PLStats(); }
   }
   return(!catch("UpdateStatus(4)"));
}


/**
 * Update virtual order status and PL.
 *
 * @return bool - success status
 */
bool UpdateVirtualStatus() {
   if (!open.ticket) return(!catch("UpdateVirtualStatus(1)  "+ sequence.name +" no open ticket found", ERR_ILLEGAL_STATE));

   open.swapM        = 0;
   open.commissionM  = 0;
   open.grossProfitU = ifDouble(!open.type, Bid-open.price, open.price-Ask);
   open.grossProfitM = open.grossProfitU * QuoteUnitValue(Lots);
   open.netProfitU   = open.grossProfitU;
   open.netProfitM   = open.grossProfitM;

   sequence.openZeroProfitU  = ifDouble(!open.type, Bid-open.bid, open.bid-Bid);    // both directions use Bid prices
   sequence.openGrossProfitU = open.grossProfitU;
   sequence.openNetProfitU   = open.netProfitU;
   sequence.openNetProfitM   = open.netProfitM;

   sequence.totalZeroProfitU  = sequence.openZeroProfitU  + sequence.closedZeroProfitU;
   sequence.totalGrossProfitU = sequence.openGrossProfitU + sequence.closedGrossProfitU;
   sequence.totalNetProfitU   = sequence.openNetProfitU   + sequence.closedNetProfitU;
   sequence.totalNetProfitM   = sequence.openNetProfitM   + sequence.closedNetProfitM; SS.TotalPL();

   if      (sequence.totalNetProfitM > sequence.maxNetProfitM  ) { sequence.maxNetProfitM   = sequence.totalNetProfitM; SS.PLStats(); }
   else if (sequence.totalNetProfitM < sequence.maxNetDrawdownM) { sequence.maxNetDrawdownM = sequence.totalNetProfitM; SS.PLStats(); }

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
   // #1 Sell 0.1 GBPUSD at 1.5457'2 ("Z.8692") was [unexpectedly ]closed [by SL ]at 1.5457'2 (market: Bid/Ask[, so: 47.7%/169.20/354.40])
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
   string comment     = sequence.name;
   string sUnexpected = ifString(closedBySl || __CoreFunction==CF_INIT || (__isTesting && __CoreFunction==CF_DEINIT), "", "unexpectedly ");
   string sBySL       = ifString(closedBySl, "by SL ", "");
   string message     = "#"+ ticket +" "+ sType +" "+ NumberToStr(lots, ".+") +" "+ OrderSymbol() +" at "+ sOpenPrice +" (\""+ comment +"\") was "+ sUnexpected +"closed "+ sBySL +"at "+ sClosePrice;

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
 * Error handler for an unexpected close of the current position.
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

   if (__isTesting) return(catch(message, error));          // tester: treat everything else as terminating

   logWarn(message, error);                                 // online
   if (error == ERR_CONCURRENT_MODIFICATION)                // unexpected: most probably manually closed
      return(NO_ERROR);                                     // continue
   return(error);
}


/**
 * Calculate a magic order number for the strategy.
 *
 * @param  int sequenceId [optional] - sequence to calculate the magic number for (default: the current sequence)
 *
 * @return int - magic number or NULL in case of errors
 */
int CalculateMagicNumber(int sequenceId = NULL) {
   if (STRATEGY_ID < 101 || STRATEGY_ID > 1023) return(!catch("CalculateMagicNumber(1)  "+ sequence.name +" illegal strategy id: "+ STRATEGY_ID, ERR_ILLEGAL_STATE));
   int id = intOr(sequenceId, sequence.id);
   if (id < SID_MIN || id > SID_MAX)            return(!catch("CalculateMagicNumber(2)  "+ sequence.name +" illegal sequence id: "+ id, ERR_ILLEGAL_STATE));

   int strategy = STRATEGY_ID;                              // 101-1023 (10 bit)
   int sequence = id;                                       // now 100-999 but was 1000-9999 (14 bit)

   return((strategy<<22) + (sequence<<8));                  // the remaining 8 bit are not used in this strategy
}


/**
 * Whether the currently selected ticket belongs to the current strategy and/or instance.
 *
 * @param  int sequenceId [optional] - sequence to check the ticket against (default: check for matching strategy)
 *
 * @return bool
 */
bool IsMyOrder(int sequenceId = NULL) {
   if (OrderSymbol() == Symbol()) {
      int strategy = OrderMagicNumber() >> 22;
      if (strategy == STRATEGY_ID) {
         int sequence = OrderMagicNumber() >> 8 & 0x3FFF;   // 14 bit starting at bit 8: sequence id
         return(!sequenceId || sequenceId==sequence);
      }
   }
   return(false);
}


/**
 * Generate a new sequence id. Must be unique for all instances of this strategy.
 *
 * @return int - sequence id in the range of 100-999 or NULL in case of errors
 */
int CreateSequenceId() {
   MathSrand(GetTickCount()-__ExecutionContext[EC.hChartWindow]);
   int sequenceId, magicNumber;

   while (!magicNumber) {
      while (sequenceId < SID_MIN || sequenceId > SID_MAX) {
         sequenceId = MathRand();                           // TODO: generate consecutive ids in tester
      }
      magicNumber = CalculateMagicNumber(sequenceId); if (!magicNumber) return(NULL);

      // test for uniqueness against open orders
      int openOrders = OrdersTotal();
      for (int i=0; i < openOrders; i++) {
         if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) return(!catch("CreateSequenceId(1)  "+ sequence.name, intOr(GetLastError(), ERR_RUNTIME_ERROR)));
         if (OrderMagicNumber() == magicNumber) {
            magicNumber = NULL;
            break;
         }
      }
      if (!magicNumber) continue;

      // test for uniqueness against closed orders
      int closedOrders = OrdersHistoryTotal();
      for (i=0; i < closedOrders; i++) {
         if (!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) return(!catch("CreateSequenceId(2)  "+ sequence.name, intOr(GetLastError(), ERR_RUNTIME_ERROR)));
         if (OrderMagicNumber() == magicNumber) {
            magicNumber = NULL;
            break;
         }
      }
   }
   return(sequenceId);
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
   if (size > 0) ticket = Max(ticket, history[size-1][HI_TICKET]);
   ticket++;

   if (IsLogInfo()) {
      string sType  = OperationTypeDescription(type);
      string sLots  = NumberToStr(Lots, ".+");
      string sPrice = NumberToStr(ifDouble(type, Bid, Ask), PriceFormat);
      string sBid   = NumberToStr(Bid, PriceFormat);
      string sAsk   = NumberToStr(Ask, PriceFormat);
      logInfo("VirtualOrderSend(1)  opened virtual #"+ ticket +" "+ sType +" "+ sLots +" "+ Symbol() +" \"ZigZag."+ sequence.name +"\" at "+ sPrice +" (market: "+ sBid +"/"+ sAsk +")");
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
   if (ticket != open.ticket) return(!catch("VirtualOrderClose(1)  "+ sequence.name +" ticket/open.ticket mis-match: "+ ticket +"/"+ open.ticket, ERR_ILLEGAL_STATE));

   if (IsLogInfo()) {
      string sType       = OperationTypeDescription(open.type);
      string sLots       = NumberToStr(Lots, ".+");
      string sOpenPrice  = NumberToStr(open.price, PriceFormat);
      double closePrice  = ifDouble(!open.type, Bid, Ask);
      string sClosePrice = NumberToStr(closePrice, PriceFormat);
      string sBid        = NumberToStr(Bid, PriceFormat);
      string sAsk        = NumberToStr(Ask, PriceFormat);
      logInfo("VirtualOrderClose(2)  closed virtual #"+ ticket +" "+ sType +" "+ sLots +" "+ Symbol() +" \"ZigZag."+ sequence.name +"\" from "+ sOpenPrice +" at "+ sClosePrice +" (market: "+ sBid +"/"+ sAsk +")");
   }
   return(true);
}


/**
 * Return custom symbol definitions for metrics to be recorded by this instance.
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
bool Recorder_GetSymbolDefinitionA(int i, bool &enabled, string &symbol, string &symbolDescr, string &symbolGroup, int &symbolDigits, double &hstBase, int &hstMultiplier, string &hstDirectory, int &hstFormat) {
   enabled = false;
   if (IsLastError())                    return(false);
   if (!sequence.id)                     return(!catch("Recorder_GetSymbolDefinitionA(1)  "+ sequence.name +" illegal sequence id: "+ sequence.id, ERR_ILLEGAL_STATE));
   if (IsTestSequence() && !__isTesting) return(false);                       // never record anything in a stopped test

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

   int quoteUnitMultiplier = 1;                                               // use absolute value: e.g. 1.23 QU => 1.23 quote currency or index points
   if (!EA.RecorderAutoScale || Digits!=2 || Close[0] < 500) {
      quoteUnitMultiplier = Round(MathPow(10, Digits & (~1)));                // convert to pip:     e.g. 1.23 QU => 123.0 pip
   }

   static string sQuoteUnits = ""; if (!StringLen(sQuoteUnits)) {
      if (quoteUnitMultiplier != 1)                                          sQuoteUnits = "pip";
      else if (StrEndsWith(Symbol(), "EUR") || StrEndsWith(Symbol(), "USD")) sQuoteUnits = "QC";         // quote currency
      else                                                                   sQuoteUnits = "index points";
   }

   switch (i) {
      // --------------------------------------------------------------------------------------------------------------------
      case METRIC_TOTAL_UNITS_ZERO:             // OK
         symbol        = "z"+ StrLeft(Symbol(), 5) +"_"+ sequence.id +"A";    // "zUS500_123A"
         symbolDescr   = "ZigZag("+ ZigZag.Periods +","+ PeriodDescription() +") 1 "+ Symbol() +" in "+ sQuoteUnits +", zero spread";
         symbolDigits  = ifInt(quoteUnitMultiplier==1, Digits, 1);            // "ZigZag(40,H1) 1 US500 in index points, zero spread"
         hstMultiplier = quoteUnitMultiplier;
         return(true);

      case METRIC_TOTAL_UNITS_GROSS:            // OK
         symbol        = "z"+ StrLeft(Symbol(), 5) +"_"+ sequence.id +"B";
         symbolDescr   = "ZigZag("+ ZigZag.Periods +","+ PeriodDescription() +") 1 "+ Symbol() +" in "+ sQuoteUnits +", gross";
         symbolDigits  = ifInt(quoteUnitMultiplier==1, Digits, 1);
         hstMultiplier = quoteUnitMultiplier;
         return(true);

      case METRIC_TOTAL_UNITS_NET:              // OK
         symbol        = "z"+ StrLeft(Symbol(), 5) +"_"+ sequence.id +"C";
         symbolDescr   = "ZigZag("+ ZigZag.Periods +","+ PeriodDescription() +") 1 "+ Symbol() +" in "+ sQuoteUnits +", net";
         symbolDigits  = ifInt(quoteUnitMultiplier==1, Digits, 1);
         hstMultiplier = quoteUnitMultiplier;
         return(true);

      case METRIC_TOTAL_MONEY_NET:              // OK
         symbol        = "z"+ StrLeft(Symbol(), 5) +"_"+ sequence.id +"D";    // in account currency
         symbolDescr   = "ZigZag("+ ZigZag.Periods +","+ PeriodDescription() +") 1 "+ Symbol() +" in AC, net";
         symbolDigits  = 2;
         hstMultiplier = 1;
         return(true);

      // --------------------------------------------------------------------------------------------------------------------
      case METRIC_DAILY_UNITS_ZERO:
         symbol        = "z"+ StrLeft(Symbol(), 5) +"_"+ sequence.id +"E";    // "zEURUS_456A"
         symbolDescr   = "ZigZag("+ ZigZag.Periods +","+ PeriodDescription() +") 1 "+ Symbol() +" daily in "+ sQuoteUnits +", zero spread";
         symbolDigits  = ifInt(quoteUnitMultiplier==1, Digits, 1);            // "ZigZag(40,H1) 3 EURUSD daily in pip, zero spread"
         hstMultiplier = quoteUnitMultiplier;
         return(true);

      case METRIC_DAILY_UNITS_GROSS:
         symbol        = "z"+ StrLeft(Symbol(), 5) +"_"+ sequence.id +"F";
         symbolDescr   = "ZigZag("+ ZigZag.Periods +","+ PeriodDescription() +") 1 "+ Symbol() +" daily in "+ sQuoteUnits +", gross";
         symbolDigits  = ifInt(quoteUnitMultiplier==1, Digits, 1);
         hstMultiplier = quoteUnitMultiplier;
         return(true);

      case METRIC_DAILY_UNITS_NET:
         symbol        = "z"+ StrLeft(Symbol(), 5) +"_"+ sequence.id +"G";
         symbolDescr   = "ZigZag("+ ZigZag.Periods +","+ PeriodDescription() +") 1 "+ Symbol() +" daily in "+ sQuoteUnits +", net";
         symbolDigits  = ifInt(quoteUnitMultiplier==1, Digits, 1);
         hstMultiplier = quoteUnitMultiplier;
         return(true);

      case METRIC_DAILY_MONEY_NET:
         symbol        = "z"+ StrLeft(Symbol(), 5) +"_"+ sequence.id +"H";    // in account currency
         symbolDescr   = "ZigZag("+ ZigZag.Periods +","+ PeriodDescription() +") 1 "+ Symbol() +" daily in AC, net";
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
 * Return the full name of the instance status file.
 *
 * @param  bool relative [optional] - whether to return the absolute path or the path relative to the MQL "files" directory
 *                                    (default: the absolute path)
 *
 * @return string - filename or an empty string in case of errors
 */
string GetStatusFilename(bool relative = false) {
   relative = relative!=0;
   if (!sequence.id) return(_EMPTY_STR(catch("GetStatusFilename(1)  "+ sequence.name +" illegal value of sequence.id: "+ sequence.id, ERR_ILLEGAL_STATE)));

   static string filename = ""; if (!StringLen(filename)) {
      string directory = "presets/"+ ifString(IsTestSequence(), "Tester", GetAccountCompanyId()) +"/";
      string baseName  = StrToLower(Symbol()) +".ZigZag."+ sequence.id +".set";
      filename = StrReplace(directory, "\\", "/") + baseName;
   }

   if (relative)
      return(filename);
   return(GetMqlSandboxPath() +"/"+ filename);
}


/**
 * Return a description of a sequence status code.
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
   return(_EMPTY_STR(catch("StatusDescription(1)  "+ sequence.name +" invalid parameter status: "+ status, ERR_INVALID_PARAMETER)));
}


/**
 * Return a readable presentation of a sequence status code.
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
   return(_EMPTY_STR(catch("StatusToStr(1)  "+ sequence.name +" invalid parameter status: "+ status, ERR_INVALID_PARAMETER)));
}


/**
 * Return a readable presentation of a signal constant.
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
   return(_EMPTY_STR(catch("SignalToStr(1)  "+ sequence.name +" invalid parameter signal: "+ signal, ERR_INVALID_PARAMETER)));
}


/**
 * Write the current sequence status to a file.
 *
 * @return bool - success status
 */
bool SaveStatus() {
   if (last_error != NULL)                       return(false);
   if (!sequence.id || StrTrim(Sequence.ID)=="") return(!catch("SaveStatus(1)  illegal sequence id: "+ sequence.id +" (Sequence.ID="+ DoubleQuoteStr(Sequence.ID) +")", ERR_ILLEGAL_STATE));
   if (IsTestSequence() && !__isTesting)         return(true);  // don't change the status file of a finished test

   if (__isTesting && test.reduceStatusWrites) {                // in tester skip most writes except file creation, sequence stop and test end
      static bool saved = false;
      if (saved && sequence.status!=STATUS_STOPPED && __CoreFunction!=CF_DEINIT) return(true);
      saved = true;
   }

   string section="", separator="", file=GetStatusFilename();
   if (!IsFile(file, MODE_SYSTEM)) separator = CRLF;            // an empty line as additional section separator

   // [General]
   section = "General";
   WriteIniString(file, section, "Account", GetAccountCompanyId() +":"+ GetAccountNumber() +" ("+ ifString(IsDemoFix(), "demo", "real") +")");
   WriteIniString(file, section, "Symbol",  Symbol());
   WriteIniString(file, section, "Created", GmtTimeFormat(sequence.created, "%a, %Y.%m.%d %H:%M:%S") + separator);         // conditional section separator

   // [Inputs]
   section = "Inputs";
   WriteIniString(file, section, "Sequence.ID",                 /*string*/ Sequence.ID);
   WriteIniString(file, section, "TradingMode",                 /*string*/ TradingMode);
   WriteIniString(file, section, "ZigZag.Periods",              /*int   */ ZigZag.Periods);
   WriteIniString(file, section, "Lots",                        /*double*/ NumberToStr(Lots, ".+"));
   WriteIniString(file, section, "StartConditions",             /*string*/ SaveStatus.ConditionsToStr(sStartConditions));  // contains only active conditions
   WriteIniString(file, section, "StopConditions",              /*string*/ SaveStatus.ConditionsToStr(sStopConditions));   // contains only active conditions
   WriteIniString(file, section, "TakeProfit",                  /*double*/ NumberToStr(TakeProfit, ".+"));
   WriteIniString(file, section, "TakeProfit.Type",             /*string*/ TakeProfit.Type);
   WriteIniString(file, section, "Slippage",                    /*int   */ Slippage);
   WriteIniString(file, section, "ShowProfitInPercent",         /*bool  */ ShowProfitInPercent);
   WriteIniString(file, section, "EA.Recorder",                 /*string*/ EA.Recorder);
   WriteIniString(file, section, "EA.RecorderAutoScale",        /*bool  */ EA.RecorderAutoScale + separator);              // conditional section separator

   // [Runtime status]
   section = "Runtime status";                                  // On deletion of pending orders the number of stored order records decreases. To prevent
   EmptyIniSectionA(file, section);                             // orphaned status file records the section is emptied before writing to it.

   // general
   WriteIniString(file, section, "tradingMode",                 /*int     */ tradingMode + CRLF);

   // sequence data
   WriteIniString(file, section, "sequence.id",                 /*int     */ sequence.id);
   WriteIniString(file, section, "sequence.created",            /*datetime*/ sequence.created + GmtTimeFormat(sequence.created, " (%a, %Y.%m.%d %H:%M:%S)"));
   WriteIniString(file, section, "sequence.isTest",             /*bool    */ sequence.isTest);
   WriteIniString(file, section, "sequence.name",               /*string  */ sequence.name);
   WriteIniString(file, section, "sequence.status",             /*int     */ sequence.status);
   WriteIniString(file, section, "sequence.startEquityM",       /*double  */ DoubleToStr(sequence.startEquityM, 2) + CRLF);

   WriteIniString(file, section, "sequence.openZeroProfitU",    /*double  */ DoubleToStr(sequence.openZeroProfitU, Digits));
   WriteIniString(file, section, "sequence.closedZeroProfitU",  /*double  */ DoubleToStr(sequence.closedZeroProfitU, Digits));
   WriteIniString(file, section, "sequence.totalZeroProfitU",   /*double  */ DoubleToStr(sequence.totalZeroProfitU, Digits) + CRLF);

   WriteIniString(file, section, "sequence.openGrossProfitU",   /*double  */ DoubleToStr(sequence.openGrossProfitU, Digits));
   WriteIniString(file, section, "sequence.closedGrossProfitU", /*double  */ DoubleToStr(sequence.closedGrossProfitU, Digits));
   WriteIniString(file, section, "sequence.totalGrossProfitU",  /*double  */ DoubleToStr(sequence.totalGrossProfitU, Digits) + CRLF);

   WriteIniString(file, section, "sequence.openNetProfitU",     /*double  */ DoubleToStr(sequence.openNetProfitU, Digits));
   WriteIniString(file, section, "sequence.closedNetProfitU",   /*double  */ DoubleToStr(sequence.closedNetProfitU, Digits));
   WriteIniString(file, section, "sequence.totalNetProfitU",    /*double  */ DoubleToStr(sequence.totalNetProfitU, Digits) + CRLF);

   WriteIniString(file, section, "sequence.openNetProfitM",     /*double  */ DoubleToStr(sequence.openNetProfitM, 2));
   WriteIniString(file, section, "sequence.closedNetProfitM",   /*double  */ DoubleToStr(sequence.closedNetProfitM, 2));
   WriteIniString(file, section, "sequence.totalNetProfitM",    /*double  */ DoubleToStr(sequence.totalNetProfitM, 2) + CRLF);

   WriteIniString(file, section, "sequence.maxNetProfitM",      /*double  */ DoubleToStr(sequence.maxNetProfitM, 2));
   WriteIniString(file, section, "sequence.maxNetDrawdownM",    /*double  */ DoubleToStr(sequence.maxNetDrawdownM, 2) + CRLF);

   // open order data
   WriteIniString(file, section, "open.ticket",                 /*int     */ open.ticket);
   WriteIniString(file, section, "open.type",                   /*int     */ open.type);
   WriteIniString(file, section, "open.time",                   /*datetime*/ open.time + ifString(open.time, GmtTimeFormat(open.time, " (%a, %Y.%m.%d %H:%M:%S)"), ""));
   WriteIniString(file, section, "open.bid",                    /*double  */ DoubleToStr(open.bid, Digits));
   WriteIniString(file, section, "open.ask",                    /*double  */ DoubleToStr(open.ask, Digits));
   WriteIniString(file, section, "open.price",                  /*double  */ DoubleToStr(open.price, Digits));
   WriteIniString(file, section, "open.stoploss",               /*double  */ DoubleToStr(open.stoploss, Digits));
   WriteIniString(file, section, "open.slippageP",              /*double  */ DoubleToStr(open.slippageP, 1));
   WriteIniString(file, section, "open.swapM",                  /*double  */ DoubleToStr(open.swapM, 2));
   WriteIniString(file, section, "open.commissionM",            /*double  */ DoubleToStr(open.commissionM, 2));
   WriteIniString(file, section, "open.grossProfitM",           /*double  */ DoubleToStr(open.grossProfitM, 2));
   WriteIniString(file, section, "open.grossProfitU",           /*double  */ DoubleToStr(open.grossProfitU, Digits));
   WriteIniString(file, section, "open.netProfitM",             /*double  */ DoubleToStr(open.netProfitM, 2));
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

   int      ticket      = history[index][HI_TICKET        ];
   double   lots        = history[index][HI_LOTS          ];
   int      openType    = history[index][HI_OPENTYPE      ];
   datetime openTime    = history[index][HI_OPENTIME      ];
   double   openBid     = history[index][HI_OPENBID       ];
   double   openAsk     = history[index][HI_OPENASK       ];
   double   openPrice   = history[index][HI_OPENPRICE     ];
   datetime closeTime   = history[index][HI_CLOSETIME     ];
   double   closeBid    = history[index][HI_CLOSEBID      ];
   double   closeAsk    = history[index][HI_CLOSEASK      ];
   double   closePrice  = history[index][HI_CLOSEPRICE    ];
   double   slippage    = history[index][HI_SLIPPAGE_P    ];
   double   swap        = history[index][HI_SWAP_M        ];
   double   commission  = history[index][HI_COMMISSION_M  ];
   double   grossProfit = history[index][HI_GROSS_PROFIT_M];
   double   netProfit   = history[index][HI_NET_PROFIT_M  ];

   return(StringConcatenate(ticket, ",", DoubleToStr(lots, 2), ",", openType, ",", openTime, ",", DoubleToStr(openBid, Digits), ",", DoubleToStr(openAsk, Digits), ",", DoubleToStr(openPrice, Digits), ",", closeTime, ",", DoubleToStr(closeBid, Digits), ",", DoubleToStr(closeAsk, Digits), ",", DoubleToStr(closePrice, Digits), ",", DoubleToStr(slippage, 1), ",", DoubleToStr(swap, 2), ",", DoubleToStr(commission, 2), ",", DoubleToStr(grossProfit, 2), ",", DoubleToStr(netProfit, 2)));
}


/**
 * Restore the internal state of the EA from a status file. Requires 'sequence.id' and 'sequence.isTest' to be set.
 *
 * @return bool - success status
 */
bool RestoreSequence() {
   if (IsLastError())        return(false);
   if (!ReadStatus())        return(false);              // read and apply the status file
   if (!ValidateInputs())    return(false);              // validate restored input parameters
   if (!SynchronizeStatus()) return(false);              // synchronize restored state with the trade server
   return(true);
}


/**
 * Read the status file of a sequence and restore inputs and runtime variables. Called only from RestoreSequence().
 *
 * @return bool - success status
 */
bool ReadStatus() {
   if (IsLastError()) return(false);
   if (!sequence.id)  return(!catch("ReadStatus(1)  "+ sequence.name +" illegal value of sequence.id: "+ sequence.id, ERR_ILLEGAL_STATE));

   string section="", file=GetStatusFilename();
   if (!IsFile(file, MODE_SYSTEM)) return(!catch("ReadStatus(2)  "+ sequence.name +" status file "+ DoubleQuoteStr(file) +" not found", ERR_FILE_NOT_FOUND));

   // [General]
   section = "General";
   string sAccount     = GetIniStringA(file, section, "Account", "");                                 // string Account = ICMarkets:12345678 (demo)
   string sSymbol      = GetIniStringA(file, section, "Symbol",  "");                                 // string Symbol  = EURUSD
   string sThisAccount = GetAccountCompanyId() +":"+ GetAccountNumber();
   if (!StrCompareI(StrLeftTo(sAccount, " ("), sThisAccount)) return(!catch("ReadStatus(3)  "+ sequence.name +" account mis-match: "+ DoubleQuoteStr(sThisAccount) +" vs. "+ DoubleQuoteStr(sAccount) +" in status file "+ DoubleQuoteStr(file), ERR_INVALID_CONFIG_VALUE));
   if (!StrCompareI(sSymbol, Symbol()))                       return(!catch("ReadStatus(4)  "+ sequence.name +" symbol mis-match: "+ Symbol() +" vs. "+ sSymbol +" in status file "+ DoubleQuoteStr(file), ERR_INVALID_CONFIG_VALUE));

   // [Inputs]
   section = "Inputs";
   string sSequenceID          = GetIniStringA(file, section, "Sequence.ID",          "");            // string Sequence.ID          = T1234
   string sTradingMode         = GetIniStringA(file, section, "TradingMode",          "");            // string TradingMode          = regular
   int    iZigZagPeriods       = GetIniInt    (file, section, "ZigZag.Periods"          );            // int    ZigZag.Periods       = 40
   string sLots                = GetIniStringA(file, section, "Lots",                 "");            // double Lots                 = 0.1
   string sStartConditions     = GetIniStringA(file, section, "StartConditions",      "");            // string StartConditions      = @time(datetime|time)
   string sStopConditions      = GetIniStringA(file, section, "StopConditions",       "");            // string StopConditions       = @time(datetime|time)
   string sTakeProfit          = GetIniStringA(file, section, "TakeProfit",           "");            // double TakeProfit           = 3.0
   string sTakeProfitType      = GetIniStringA(file, section, "TakeProfit.Type",      "");            // string TakeProfit.Type      = off* | money | percent | pip
   int    iSlippage            = GetIniInt    (file, section, "Slippage"                );            // int    Slippage             = 2
   string sShowProfitInPercent = GetIniStringA(file, section, "ShowProfitInPercent",  "");            // bool   ShowProfitInPercent  = 1
   string sEaRecorder          = GetIniStringA(file, section, "EA.Recorder",          "");            // string EA.Recorder          = 1,2,4
   string sEaRecorderAutoScale = GetIniStringA(file, section, "EA.RecorderAutoScale", "");            // bool   EA.RecorderAutoScale = 0

   if (!StrIsNumeric(sLots))                 return(!catch("ReadStatus(5)  "+ sequence.name +" invalid input parameter Lots "+ DoubleQuoteStr(sLots) +" in status file "+ DoubleQuoteStr(file), ERR_INVALID_FILE_FORMAT));
   if (!StrIsNumeric(sTakeProfit))           return(!catch("ReadStatus(6)  "+ sequence.name +" invalid input parameter TakeProfit "+ DoubleQuoteStr(sTakeProfit) +" in status file "+ DoubleQuoteStr(file), ERR_INVALID_FILE_FORMAT));

   Sequence.ID          = sSequenceID;
   TradingMode          = sTradingMode;
   Lots                 = StrToDouble(sLots);
   ZigZag.Periods       = iZigZagPeriods;
   StartConditions      = sStartConditions;
   StopConditions       = sStopConditions;
   TakeProfit           = StrToDouble(sTakeProfit);
   TakeProfit.Type      = sTakeProfitType;
   Slippage             = iSlippage;
   ShowProfitInPercent  = StrToBool(sShowProfitInPercent);
   EA.Recorder          = sEaRecorder;
   EA.RecorderAutoScale = StrToBool(sEaRecorderAutoScale);

   // [Runtime status]
   section = "Runtime status";
   // general
   tradingMode                 = GetIniInt    (file, section, "tradingMode");                         // int      tradingMode                 = 1

   // sequence data
   sequence.id                 = GetIniInt    (file, section, "sequence.id"                );         // int      sequence.id                 = 1234
   sequence.created            = GetIniInt    (file, section, "sequence.created"           );         // datetime sequence.created            = 1624924800 (Mon, 2021.05.12 13:22:34)
   sequence.isTest             = GetIniBool   (file, section, "sequence.isTest"            );         // bool     sequence.isTest             = 1
   sequence.name               = GetIniStringA(file, section, "sequence.name",           "");         // string   sequence.name               = Z.1234
   sequence.status             = GetIniInt    (file, section, "sequence.status"            );         // int      sequence.status             = 1
   sequence.startEquityM       = GetIniDouble (file, section, "sequence.startEquityM"      );         // double   sequence.startEquityM       = 1000.00

   sequence.openZeroProfitU    = GetIniDouble (file, section, "sequence.openZeroProfitU"   );         // double   sequence.openZeroProfitU    = 0.12345
   sequence.closedZeroProfitU  = GetIniDouble (file, section, "sequence.closedZeroProfitU" );         // double   sequence.closedZeroProfitU  = -0.23456
   sequence.totalZeroProfitU   = GetIniDouble (file, section, "sequence.totalZeroProfitU"  );         // double   sequence.totalZeroProfitU   = 1.23456

   sequence.openGrossProfitU   = GetIniDouble (file, section, "sequence.openGrossProfitU"  );         // double   sequence.openGrossProfitU   = 0.12345
   sequence.closedGrossProfitU = GetIniDouble (file, section, "sequence.closedGrossProfitU");         // double   sequence.closedGrossProfitU = -0.23456
   sequence.totalGrossProfitU  = GetIniDouble (file, section, "sequence.totalGrossProfitU" );         // double   sequence.totalGrossProfitU  = 1.23456

   sequence.openNetProfitU     = GetIniDouble (file, section, "sequence.openNetProfitU"    );         // double   sequence.openNetProfitU     = 0.12345
   sequence.closedNetProfitU   = GetIniDouble (file, section, "sequence.closedNetProfitU"  );         // double   sequence.closedNetProfitU   = -0.23456
   sequence.totalNetProfitU    = GetIniDouble (file, section, "sequence.totalNetProfitU"   );         // double   sequence.totalNetProfitU    = 1.23456

   sequence.openNetProfitM     = GetIniDouble (file, section, "sequence.openNetProfitM"    );         // double   sequence.openNetProfitM     = 23.45
   sequence.closedNetProfitM   = GetIniDouble (file, section, "sequence.closedNetProfitM"  );         // double   sequence.closedNetProfitM   = 45.67
   sequence.totalNetProfitM    = GetIniDouble (file, section, "sequence.totalNetProfitM"   );         // double   sequence.totalNetProfitM    = 123.45

   sequence.maxNetProfitM      = GetIniDouble (file, section, "sequence.maxNetProfitM"     );         // double   sequence.maxNetProfitM      = 23.45
   sequence.maxNetDrawdownM    = GetIniDouble (file, section, "sequence.maxNetDrawdownM"   );         // double   sequence.maxNetDrawdownM    = -11.23
   SS.SequenceName();

   // open order data
   open.ticket                 = GetIniInt    (file, section, "open.ticket"      );                   // int      open.ticket       = 123456
   open.type                   = GetIniInt    (file, section, "open.type"        );                   // int      open.type         = 0
   open.time                   = GetIniInt    (file, section, "open.time"        );                   // datetime open.time         = 1624924800
   open.bid                    = GetIniDouble (file, section, "open.bid"         );                   // double   open.bid          = 1.24363
   open.ask                    = GetIniDouble (file, section, "open.ask"         );                   // double   open.ask          = 1.24363
   open.price                  = GetIniDouble (file, section, "open.price"       );                   // double   open.price        = 1.24363
   open.stoploss               = GetIniDouble (file, section, "open.stoploss"    );                   // double   open.stoploss     = 1.24363
   open.slippageP              = GetIniDouble (file, section, "open.slippageP"   );                   // double   open.slippageP    = 1.0
   open.swapM                  = GetIniDouble (file, section, "open.swapM"       );                   // double   open.swapM        = -1.23
   open.commissionM            = GetIniDouble (file, section, "open.commissionM" );                   // double   open.commissionM  = -5.50
   open.grossProfitM           = GetIniDouble (file, section, "open.grossProfitM");                   // double   open.grossProfitM = 12.34
   open.grossProfitU           = GetIniDouble (file, section, "open.grossProfitU");                   // double   open.grossProfitU = 0.12345
   open.netProfitM             = GetIniDouble (file, section, "open.netProfitM"  );                   // double   open.netProfitM   = 12.56
   open.netProfitU             = GetIniDouble (file, section, "open.netProfitU"  );                   // double   open.netProfitU   = 0.12345

   // history data
   string sKeys[], sOrder="";
   int size = ReadStatus.HistoryKeys(file, section, sKeys); if (size < 0) return(false);
   for (int i=0; i < size; i++) {
      sOrder = GetIniStringA(file, section, sKeys[i], "");                                            // history.{i} = {data}
      if (!ReadStatus.ParseHistory(sKeys[i], sOrder)) return(!catch("ReadStatus(7)  "+ sequence.name +" invalid history record in status file "+ DoubleQuoteStr(file) + NL + sKeys[i] +"="+ sOrder, ERR_INVALID_FILE_FORMAT));
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

   return(!catch("ReadStatus(8)"));
}


/**
 * Read and return the keys of the trade history records found in the status file (sorting order doesn't matter).
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
   if (!StrStartsWithI(key, "history.")) return(!catch("ReadStatus.ParseHistory(1)  "+ sequence.name +" illegal history record key "+ DoubleQuoteStr(key), ERR_INVALID_FILE_FORMAT));

   // history.i=ticket,lots,openType,openTime,openBid,openAsk,openPrice,closeTime,closeBid,closeAsk,closePrice,slippage,swap,commission,grossProfit,netProfit
   string values[];
   string sId = StrRightFrom(key, ".", -1); if (!StrIsDigits(sId))  return(!catch("ReadStatus.ParseHistory(2)  "+ sequence.name +" illegal history record key "+ DoubleQuoteStr(key), ERR_INVALID_FILE_FORMAT));
   if (Explode(value, ",", values, NULL) != ArrayRange(history, 1)) return(!catch("ReadStatus.ParseHistory(3)  "+ sequence.name +" illegal number of details ("+ ArraySize(values) +") in history record", ERR_INVALID_FILE_FORMAT));

   int      ticket      = StrToInteger(values[HI_TICKET        ]);
   double   lots        =  StrToDouble(values[HI_LOTS          ]);
   int      openType    = StrToInteger(values[HI_OPENTYPE      ]);
   datetime openTime    = StrToInteger(values[HI_OPENTIME      ]);
   double   openBid     =  StrToDouble(values[HI_OPENBID       ]);
   double   openAsk     =  StrToDouble(values[HI_OPENASK       ]);
   double   openPrice   =  StrToDouble(values[HI_OPENPRICE     ]);
   datetime closeTime   = StrToInteger(values[HI_CLOSETIME     ]);
   double   closeBid    =  StrToDouble(values[HI_CLOSEBID      ]);
   double   closeAsk    =  StrToDouble(values[HI_CLOSEASK      ]);
   double   closePrice  =  StrToDouble(values[HI_CLOSEPRICE    ]);
   double   slippage    =  StrToDouble(values[HI_SLIPPAGE_P    ]);
   double   swap        =  StrToDouble(values[HI_SWAP_M        ]);
   double   commission  =  StrToDouble(values[HI_COMMISSION_M  ]);
   double   grossProfit =  StrToDouble(values[HI_GROSS_PROFIT_M]);
   double   netProfit   =  StrToDouble(values[HI_NET_PROFIT_M  ]);

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
      if (EQ(ticket,   history[i][HI_TICKET  ])) return(_EMPTY(catch("History.AddRecord(1)  "+ sequence.name +" cannot add record, ticket #"+ ticket +" already exists (offset: "+ i +")", ERR_INVALID_PARAMETER)));
      if (GT(openTime, history[i][HI_OPENTIME])) continue;
      if (LT(openTime, history[i][HI_OPENTIME])) break;
      if (LT(ticket,   history[i][HI_TICKET  ])) break;
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
   history[i][HI_TICKET        ] = ticket;
   history[i][HI_LOTS          ] = lots;
   history[i][HI_OPENTYPE      ] = openType;
   history[i][HI_OPENTIME      ] = openTime;
   history[i][HI_OPENBID       ] = openBid;
   history[i][HI_OPENASK       ] = openAsk;
   history[i][HI_OPENPRICE     ] = openPrice;
   history[i][HI_CLOSETIME     ] = closeTime;
   history[i][HI_CLOSEBID      ] = closeBid;
   history[i][HI_CLOSEASK      ] = closeAsk;
   history[i][HI_CLOSEPRICE    ] = closePrice;
   history[i][HI_SLIPPAGE_P    ] = slippage;
   history[i][HI_SWAP_M        ] = swap;
   history[i][HI_COMMISSION_M  ] = commission;
   history[i][HI_GROSS_PROFIT_M] = grossProfit;
   history[i][HI_NET_PROFIT_M  ] = netProfit;

   if (!catch("History.AddRecord(2)"))
      return(i);
   return(EMPTY);
}


/**
 * Synchronize restored state and runtime vars with the trade server. Called only from RestoreSequence().
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
      if (IsMyOrder(sequence.id)) {
         if (IsPendingOrderType(OrderType())) {
            logWarn("SynchronizeStatus(1)  "+ sequence.name +" unsupported pending order found: #"+ OrderTicket() +", ignoring it...");
            continue;
         }
         if (!open.ticket) {
            logWarn("SynchronizeStatus(2)  "+ sequence.name +" dangling open position found: #"+ OrderTicket() +", adding to sequence...");
            open.ticket    = OrderTicket();
            open.type      = OrderType();
            open.time      = OrderOpenTime();
            open.price     = OrderOpenPrice();
            open.stoploss  = OrderStopLoss();
            open.bid       = open.price;
            open.ask       = open.price;
            open.slippageP = NULL;                                   // open PL numbers will auto-update in the following UpdateStatus() call
         }
         else if (OrderTicket() != open.ticket) {
            return(!catch("SynchronizeStatus(3)  "+ sequence.name +" dangling open position found: #"+ OrderTicket(), ERR_RUNTIME_ERROR));
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

      if (IsMyOrder(sequence.id)) {
         if (!IsLocalClosedPosition(OrderTicket())) {
            int      ticket       = OrderTicket();
            double   lots         = OrderLots();
            int      openType     = OrderType();
            datetime openTime     = OrderOpenTime();
            double   openPrice    = OrderOpenPrice();
            datetime closeTime    = OrderCloseTime();
            double   closePrice   = OrderClosePrice();
            double   slippageP    = 0;
            double   swapM        = OrderSwap();
            double   commissionM  = OrderCommission();
            double   grossProfitM = OrderProfit();
            double   netProfitM   = grossProfitM + swapM + commissionM;
            double   grossProfitU = ifDouble(!openType, closePrice-openPrice, openPrice-closePrice);

            logWarn("SynchronizeStatus(4)  "+ sequence.name +" dangling closed position found: #"+ ticket +", adding to sequence...");
            if (IsEmpty(History.AddRecord(ticket, lots, openType, openTime, openPrice, openPrice, openPrice, closeTime, closePrice, closePrice, closePrice, slippageP, swapM, commissionM, grossProfitM, netProfitM))) return(false);

            // update closed PL numbers
            sequence.closedZeroProfitU  += grossProfitU;
            sequence.closedGrossProfitU += grossProfitU;
            sequence.closedNetProfitU   += grossProfitU + MathDiv(swapM + commissionM, QuoteUnitValue(lots));
            sequence.closedNetProfitM   += netProfitM;
         }
      }
   }

   // recalculate total PL numbers
   sequence.totalZeroProfitU  = sequence.openZeroProfitU  + sequence.closedZeroProfitU;
   sequence.totalGrossProfitU = sequence.openGrossProfitU + sequence.closedGrossProfitU;
   sequence.totalNetProfitU   = sequence.openNetProfitU   + sequence.closedNetProfitU;
   sequence.totalNetProfitM   = sequence.openNetProfitM   + sequence.closedNetProfitM;

   sequence.maxNetProfitM   = MathMax(sequence.maxNetProfitM, sequence.totalNetProfitM);
   sequence.maxNetDrawdownM = MathMin(sequence.maxNetDrawdownM, sequence.totalNetProfitM);
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
      if (history[i][HI_TICKET] == ticket) return(true);
   }
   return(false);
}


/**
 * Whether the current sequence was created in the tester. Considers that a test sequence can be loaded into an online
 * chart after the test (for visualization and analysis).
 *
 * @return bool
 */
bool IsTestSequence() {
   return(sequence.isTest || __isTesting);
}


// backed-up input parameters
string   prev.Sequence.ID = "";
string   prev.TradingMode = "";
int      prev.ZigZag.Periods;
double   prev.Lots;
string   prev.StartConditions = "";
string   prev.StopConditions = "";
double   prev.TakeProfit;
string   prev.TakeProfit.Type = "";
int      prev.Slippage;
bool     prev.ShowProfitInPercent;
string   prev.EA.Recorder = "";
bool     prev.EA.RecorderAutoScale;

// backed-up runtime variables affected by changing input parameters
int      prev.tradingMode;

int      prev.sequence.id;
datetime prev.sequence.created;
bool     prev.sequence.isTest;
string   prev.sequence.name = "";
int      prev.sequence.status;

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
   // backup input parameters, also accessed for comparison in ValidateInputs()
   prev.Sequence.ID          = StringConcatenate(Sequence.ID, "");   // string inputs are references to internal C literals and must be copied to break the reference
   prev.TradingMode          = StringConcatenate(TradingMode, "");
   prev.ZigZag.Periods       = ZigZag.Periods;
   prev.Lots                 = Lots;
   prev.StartConditions      = StringConcatenate(StartConditions, "");
   prev.StopConditions       = StringConcatenate(StopConditions, "");
   prev.TakeProfit           = TakeProfit;
   prev.TakeProfit.Type      = StringConcatenate(TakeProfit.Type, "");
   prev.Slippage             = Slippage;
   prev.ShowProfitInPercent  = ShowProfitInPercent;
   prev.EA.Recorder          = StringConcatenate(EA.Recorder, "");
   prev.EA.RecorderAutoScale = EA.RecorderAutoScale;

   // backup runtime variables affected by changing input parameters
   prev.tradingMode                = tradingMode;

   prev.sequence.id                = sequence.id;
   prev.sequence.created           = sequence.created;
   prev.sequence.isTest            = sequence.isTest;
   prev.sequence.name              = sequence.name;
   prev.sequence.status            = sequence.status;

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
   Sequence.ID          = prev.Sequence.ID;
   TradingMode          = prev.TradingMode;
   ZigZag.Periods       = prev.ZigZag.Periods;
   Lots                 = prev.Lots;
   StartConditions      = prev.StartConditions;
   StopConditions       = prev.StopConditions;
   TakeProfit           = prev.TakeProfit;
   TakeProfit.Type      = prev.TakeProfit.Type;
   Slippage             = prev.Slippage;
   ShowProfitInPercent  = prev.ShowProfitInPercent;
   EA.Recorder          = prev.EA.Recorder;
   EA.RecorderAutoScale = prev.EA.RecorderAutoScale;

   // restore runtime variables
   tradingMode                = prev.tradingMode;

   sequence.id                = prev.sequence.id;
   sequence.created           = prev.sequence.created;
   sequence.isTest            = prev.sequence.isTest;
   sequence.name              = prev.sequence.name;
   sequence.status            = prev.sequence.status;

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
 * Validate and apply the input parameter "Sequence.ID".
 *
 * @return bool - whether a sequence id was successfully restored (the status file is not checked)
 */
bool ValidateInputs.SID() {
   bool errorFlag = true;

   if (!ApplySequenceId(Sequence.ID, errorFlag, "ValidateInputs.SID(1)")) {
      if (errorFlag) onInputError("ValidateInputs.SID(2)  invalid input parameter Sequence.ID: \""+ Sequence.ID +"\"");
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
   bool sequenceWasStarted = (open.ticket || ArrayRange(history, 0));

   // Sequence.ID
   if (isInitParameters) {                               // otherwise the id was validated in ValidateInputs.SID()
      string sValues[], sValue=StrTrim(Sequence.ID);
      if (sValue == "") {                                // the id was deleted or not yet set, re-apply the internal id
         Sequence.ID = prev.Sequence.ID;
      }
      else if (sValue != prev.Sequence.ID)               return(!onInputError("ValidateInputs(1)  "+ sequence.name +" switching to another sequence is not supported (unload the EA first)"));
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
   else                                                  return(!onInputError("ValidateInputs(2)  "+ sequence.name +" invalid input parameter TradingMode: "+ DoubleQuoteStr(TradingMode)));
   if (isInitParameters && tradingMode!=prev.tradingMode) {
      if (sequenceWasStarted)                            return(!onInputError("ValidateInputs(3)  "+ sequence.name +" cannot change input parameter TradingMode of "+ StatusDescription(sequence.status) +" sequence"));
   }
   TradingMode = tradingModeDescriptions[tradingMode];

   // ZigZag.Periods
   if (isInitParameters && ZigZag.Periods!=prev.ZigZag.Periods) {
      if (sequenceWasStarted)                            return(!onInputError("ValidateInputs(4)  "+ sequence.name +" cannot change input parameter ZigZag.Periods of "+ StatusDescription(sequence.status) +" sequence"));
   }
   if (ZigZag.Periods < 2)                               return(!onInputError("ValidateInputs(5)  "+ sequence.name +" invalid input parameter ZigZag.Periods: "+ ZigZag.Periods));

   // Lots
   if (isInitParameters && NE(Lots, prev.Lots)) {
      if (sequenceWasStarted)                            return(!onInputError("ValidateInputs(6)  "+ sequence.name +" cannot change input parameter Lots of "+ StatusDescription(sequence.status) +" sequence"));
   }
   if (LT(Lots, 0))                                      return(!onInputError("ValidateInputs(7)  "+ sequence.name +" invalid input parameter Lots: "+ NumberToStr(Lots, ".1+") +" (too small)"));
   if (NE(Lots, NormalizeLots(Lots)))                    return(!onInputError("ValidateInputs(8)  "+ sequence.name +" invalid input parameter Lots: "+ NumberToStr(Lots, ".1+") +" (not a multiple of MODE_LOTSTEP="+ NumberToStr(MarketInfo(Symbol(), MODE_LOTSTEP), ".+") +")"));

   // StartConditions: @time(datetime|time)
   if (!isInitParameters || StartConditions!=prev.StartConditions) {
      start.time.condition = false;                      // on initParameters conditions are re-enabled on change only

      string exprs[], expr="", key="";                   // split conditions
      int sizeOfExprs = Explode(StartConditions, "|", exprs, NULL), iValue, time, sizeOfElems;

      for (int i=0; i < sizeOfExprs; i++) {              // validate each expression
         expr = StrTrim(exprs[i]);
         if (!StringLen(expr))              continue;
         if (StringGetChar(expr, 0) == '!') continue;    // skip disabled conditions
         if (StringGetChar(expr, 0) != '@')              return(!onInputError("ValidateInputs(9)  "+ sequence.name +" invalid input parameter StartConditions: "+ DoubleQuoteStr(StartConditions)));

         if (Explode(expr, "(", sValues, NULL) != 2)     return(!onInputError("ValidateInputs(10)  "+ sequence.name +" invalid input parameter StartConditions: "+ DoubleQuoteStr(StartConditions)));
         if (!StrEndsWith(sValues[1], ")"))              return(!onInputError("ValidateInputs(11)  "+ sequence.name +" invalid input parameter StartConditions: "+ DoubleQuoteStr(StartConditions)));
         key = StrTrim(sValues[0]);
         sValue = StrTrim(StrLeft(sValues[1], -1));
         if (!StringLen(sValue))                         return(!onInputError("ValidateInputs(12)  "+ sequence.name +" invalid input parameter StartConditions: "+ DoubleQuoteStr(StartConditions)));

         if (key == "@time") {
            if (start.time.condition)                    return(!onInputError("ValidateInputs(13)  "+ sequence.name +" invalid input parameter StartConditions: "+ DoubleQuoteStr(StartConditions) +" (multiple time conditions)"));
            int pt[];
            if (!ParseTime(sValue, NULL, pt))            return(!onInputError("ValidateInputs(14)  "+ sequence.name +" invalid input parameter StartConditions: "+ DoubleQuoteStr(StartConditions)));
            datetime dtValue = DateTime2(pt, DATE_OF_ERA);
            start.time.condition   = true;
            start.time.value       = dtValue;
            start.time.isDaily     = !pt[PT_HAS_DATE];
            start.time.description = "time("+ TimeToStr(start.time.value, ifInt(start.time.isDaily, TIME_MINUTES, TIME_DATE|TIME_MINUTES)) +")";
         }
         else                                            return(!onInputError("ValidateInputs(15)  "+ sequence.name +" invalid input parameter StartConditions: "+ DoubleQuoteStr(StartConditions)));
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
         if (StringGetChar(expr, 0) != '@')              return(!onInputError("ValidateInputs(16)  "+ sequence.name +" invalid input parameter StopConditions: "+ DoubleQuoteStr(StopConditions)));

         if (Explode(expr, "(", sValues, NULL) != 2)     return(!onInputError("ValidateInputs(17)  "+ sequence.name +" invalid input parameter StopConditions: "+ DoubleQuoteStr(StopConditions)));
         if (!StrEndsWith(sValues[1], ")"))              return(!onInputError("ValidateInputs(18)  "+ sequence.name +" invalid input parameter StopConditions: "+ DoubleQuoteStr(StopConditions)));
         key = StrTrim(sValues[0]);
         sValue = StrTrim(StrLeft(sValues[1], -1));
         if (!StringLen(sValue))                         return(!onInputError("ValidateInputs(19)  "+ sequence.name +" invalid input parameter StopConditions: "+ DoubleQuoteStr(StopConditions)));

         if (key == "@time") {
            if (stop.time.condition)                     return(!onInputError("ValidateInputs(20)  "+ sequence.name +" invalid input parameter StopConditions: "+ DoubleQuoteStr(StopConditions) +" (multiple time conditions)"));
            if (!ParseTime(sValue, NULL, pt))            return(!onInputError("ValidateInputs(21)  "+ sequence.name +" invalid input parameter StopConditions: "+ DoubleQuoteStr(StopConditions)));
            dtValue = DateTime2(pt, DATE_OF_ERA);
            stop.time.condition   = true;
            stop.time.value       = dtValue;
            stop.time.isDaily     = !pt[PT_HAS_DATE];
            stop.time.description = "time("+ TimeToStr(stop.time.value, ifInt(stop.time.isDaily, TIME_MINUTES, TIME_DATE|TIME_MINUTES)) +")";
            if (start.time.condition && !start.time.isDaily && !stop.time.isDaily) {
               if (start.time.value >= stop.time.value)  return(!onInputError("ValidateInputs(22)  "+ sequence.name +" invalid times in Start/StopConditions: "+ start.time.description +" / "+ stop.time.description +" (start time must preceed stop time)"));
            }
         }
         else                                            return(!onInputError("ValidateInputs(23)  "+ sequence.name +" invalid input parameter StopConditions: "+ DoubleQuoteStr(StopConditions)));
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
   else if (StringLen(sValue) < 2)                       return(!onInputError("ValidateInputs(24)  "+ sequence.name +" invalid parameter TakeProfit.Type: "+ DoubleQuoteStr(TakeProfit.Type)));
   else if (StrStartsWith("percent", sValue))    stop.profitQu.type = TP_TYPE_PERCENT;
   else if (StrStartsWith("pip",     sValue))    stop.profitQu.type = TP_TYPE_PIP;
   else                                                  return(!onInputError("ValidateInputs(25)  "+ sequence.name +" invalid parameter TakeProfit.Type: "+ DoubleQuoteStr(TakeProfit.Type)));
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
   if (!IsTestSequence() || __isTesting) {      // never init the recorder of a stopped test
      int metrics;
      if (!init_RecorderValidateInput(metrics)) return(false);
      if (recordCustom && metrics > 8)          return(!onInputError("ValidateInputs(26)  "+ sequence.name +" invalid parameter EA.Recorder: "+ DoubleQuoteStr(EA.Recorder) +" (unsupported metric "+ metrics +")"));
   }

   // tmp. overwrite recorder.hstMultiplier of metrics 1,2,3,5,6,7 (remove together with input "EA.RecorderAutoScale")
   int hstMultiplier = 1;
   if (!EA.RecorderAutoScale || Digits!=2 || Close[0] < 500) {
      hstMultiplier = Round(MathPow(10, Digits & (~1)));
   }
   if (metrics > 0) recorder.hstMultiplier[0] = hstMultiplier;
   if (metrics > 1) recorder.hstMultiplier[1] = hstMultiplier;
   if (metrics > 2) recorder.hstMultiplier[2] = hstMultiplier;
   if (metrics > 4) recorder.hstMultiplier[4] = hstMultiplier;
   if (metrics > 5) recorder.hstMultiplier[5] = hstMultiplier;
   if (metrics > 6) recorder.hstMultiplier[6] = hstMultiplier;

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
 * Store the current sequence id in the terminal (for template changes, terminal restart, recompilation etc).
 *
 * @return bool - success status
 */
bool StoreSequenceId() {
   string name = ProgramName() +".Sequence.ID";
   string value = ifString(sequence.isTest, "T", "") + sequence.id;

   Sequence.ID = value;                                              // store in input parameter

   if (__isChart) {
      Chart.StoreString(name, value);                                // store in chart
      SetWindowStringA(__ExecutionContext[EC.hChart], name, value);  // store in chart window
   }
   return(!catch("StoreSequenceId(1)"));
}


/**
 * Find and restore a stored sequence id (for template changes, terminal restart, recompilation etc).
 *
 * @return bool - whether a sequence id was successfully restored
 */
bool RestoreSequenceId() {
   bool isError, muteErrors=false;

   // check input parameter
   string value = Sequence.ID;
   if (ApplySequenceId(value, muteErrors, "RestoreSequenceId(1)")) return(true);
   isError = muteErrors;
   if (isError) return(false);

   if (__isChart) {
      // check chart window
      string name = ProgramName() +".Sequence.ID";
      value = GetWindowStringA(__ExecutionContext[EC.hChart], name);
      muteErrors = false;
      if (ApplySequenceId(value, muteErrors, "RestoreSequenceId(2)")) return(true);
      isError = muteErrors;
      if (isError) return(false);

      // check chart
      if (Chart.RestoreString(name, value, false)) {
         muteErrors = false;
         if (ApplySequenceId(value, muteErrors, "RestoreSequenceId(3)")) return(true);
      }
   }
   return(false);
}


/**
 * Remove a stored sequence id.
 *
 * @return bool - success status
 */
bool RemoveSequenceId() {
   if (__isChart) {
      // chart window
      string name = ProgramName() +".Sequence.ID";
      RemoveWindowStringA(__ExecutionContext[EC.hChart], name);

      // chart
      Chart.RestoreString(name, name, true);

      // remove a chart status for chart commands
      name = "EA.status";
      if (ObjectFind(name) != -1) ObjectDelete(name);
   }
   return(!catch("RemoveSequenceId(1)"));
}


/**
 * Parse and apply the passed sequence id value (format: /T?[0-9]{3}/).
 *
 * @param  _In_    string value  - stringyfied sequence id
 * @param  _InOut_ bool   error  - in:  whether to mute a parse error (TRUE) or to trigger a fatal error (FALSE)
 *                                 out: whether a parsing error occurred (stored in last_error)
 * @param  _In_    string caller - caller identification (for error messages)
 *
 * @return bool - whether the sequence id was successfully applied
 */
bool ApplySequenceId(string value, bool &error, string caller) {
   string valueBak = value;
   bool muteErrors = error!=0;
   error = false;

   value = StrTrim(value);
   if (!StringLen(value)) return(false);

   bool isTest = false;
   int sequenceId = 0;

   if (StrStartsWith(value, "T")) {
      isTest = true;
      value = StrSubstr(value, 1);
   }

   if (!StrIsDigits(value)) {
      error = true;
      if (muteErrors) return(!SetLastError(ERR_INVALID_PARAMETER));
      return(!catch(caller +"->ApplySequenceId(1)  invalid sequence id value: \""+ valueBak +"\" (must be digits only)", ERR_INVALID_PARAMETER));
   }

   int iValue = StrToInteger(value);
   if (iValue < SID_MIN || iValue > SID_MAX) {
      error = true;
      if (muteErrors) return(!SetLastError(ERR_INVALID_PARAMETER));
      return(!catch(caller +"->ApplySequenceId(2)  invalid sequence id value: \""+ valueBak +"\" (range error)", ERR_INVALID_PARAMETER));
   }

   sequence.isTest = isTest;
   sequence.id     = iValue;
   Sequence.ID     = ifString(IsTestSequence(), "T", "") + sequence.id;
   SS.SequenceName();
   return(true);
}


/**
 * Return the quote unit value of the specified lot amount in account currency. Same as PipValue() but for a full quote unit.
 *
 * @param  double lots [optional] - lot amount (default: 1 lot)
 *
 * @return double - unit value or NULL (0) in case of errors (in tester the value may be not exact)
 */
double QuoteUnitValue(double lots = 1.0) {
   if (!lots) return(0);

   double tickValue = MarketInfo(Symbol(), MODE_TICKVALUE);
   int error = GetLastError();
   if (error || !tickValue)   return(!catch("QuoteUnitValue(1)  MarketInfo(MODE_TICKVALUE) = "+ tickValue, intOr(error, ERR_INVALID_MARKET_DATA)));

   static double tickSize; if (!tickSize) {
      tickSize = MarketInfo(Symbol(), MODE_TICKSIZE);
      error = GetLastError();
      if (error || !tickSize) return(!catch("QuoteUnitValue(2)  MarketInfo(MODE_TICKSIZE) = "+ tickSize, intOr(error, ERR_INVALID_MARKET_DATA)));
   }
   return(tickValue/tickSize * lots);
}


/**
 * ShowStatus: Update all string representations.
 */
void SS.All() {
   if (__isChart) {
      SS.SequenceName();
      SS.Lots();
      SS.StartStopConditions();
      SS.TotalPL();
      SS.PLStats();
   }
}


/**
 * ShowStatus: Update the string representation of the sequence name.
 */
void SS.SequenceName() {
   sequence.name = "Z."+ sequence.id;

   switch (tradingMode) {
      case TRADINGMODE_REGULAR:
         break;
      case TRADINGMODE_VIRTUAL:
         sequence.name = "V"+ sequence.name;
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
 * ShowStatus: Update the string representation of "sequence.netTotalPL".
 */
void SS.TotalPL() {
   if (__isChart) {
      // not before a position was opened
      if (!open.ticket && !ArrayRange(history, 0)) sSequenceTotalNetPL = "-";
      else if (ShowProfitInPercent)                sSequenceTotalNetPL = NumberToStr(MathDiv(sequence.totalNetProfitM, sequence.startEquityM) * 100, "R+.2") +"%";
      else                                         sSequenceTotalNetPL = NumberToStr(sequence.totalNetProfitM, "R+.2");
   }
}


/**
 * ShowStatus: Update the string representaton of the PL statistics.
 */
void SS.PLStats() {
   if (__isChart) {
      // not before a position was opened
      if (!open.ticket && !ArrayRange(history, 0)) {
         sSequencePlStats = "";
      }
      else {
         string sSequenceMaxNetProfit="", sSequenceMaxNetDrawdown="";
         if (ShowProfitInPercent) {
            sSequenceMaxNetProfit   = NumberToStr(MathDiv(sequence.maxNetProfitM, sequence.startEquityM) * 100, "R+.2") +"%";
            sSequenceMaxNetDrawdown = NumberToStr(MathDiv(sequence.maxNetDrawdownM, sequence.startEquityM) * 100, "R+.2") +"%";
         }
         else {
            sSequenceMaxNetProfit   = NumberToStr(sequence.maxNetProfitM, "+.2");
            sSequenceMaxNetDrawdown = NumberToStr(sequence.maxNetDrawdownM, "+.2");
         }
         sSequencePlStats = StringConcatenate("(", sSequenceMaxNetProfit, " / ", sSequenceMaxNetDrawdown, ")");
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

   switch (sequence.status) {
      case NULL:               sStatus = StringConcatenate(sequence.name, "  not initialized"); break;
      case STATUS_WAITING:     sStatus = StringConcatenate(sequence.name, "  waiting");         break;
      case STATUS_PROGRESSING: sStatus = StringConcatenate(sequence.name, "  progressing");     break;
      case STATUS_STOPPED:     sStatus = StringConcatenate(sequence.name, "  stopped");         break;
      default:
         return(catch("ShowStatus(1)  "+ sequence.name +" illegal sequence status: "+ sequence.status, ERR_ILLEGAL_STATE));
   }
   if (__STATUS_OFF) sError = StringConcatenate("  [switched off => ", ErrorDescription(__STATUS_OFF.reason), "]");

   string text = StringConcatenate(sTradingModeStatus[tradingMode], ProgramName(), "    ", sStatus, sError, NL,
                                                                                                            NL,
                                  "Lots:      ", sLots,                                                     NL,
                                  "Start:    ",  sStartConditions,                                          NL,
                                  "Stop:     ",  sStopConditions,                                           NL,
                                  "Profit:   ",  sSequenceTotalNetPL, "  ", sSequencePlStats,               NL
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
   ObjectSetText(label, StringConcatenate(Sequence.ID, "|", StatusDescription(sequence.status)));

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
   return(StringConcatenate("Sequence.ID=",          DoubleQuoteStr(Sequence.ID),     ";", NL,
                            "TradingMode=",          DoubleQuoteStr(TradingMode),     ";", NL,
                            "ZigZag.Periods=",       ZigZag.Periods,                  ";", NL,
                            "Lots=",                 NumberToStr(Lots, ".1+"),        ";", NL,
                            "StartConditions=",      DoubleQuoteStr(StartConditions), ";", NL,
                            "StopConditions=",       DoubleQuoteStr(StopConditions),  ";", NL,
                            "TakeProfit=",           NumberToStr(TakeProfit, ".1+"),  ";", NL,
                            "TakeProfit.Type=",      DoubleQuoteStr(TakeProfit.Type), ";", NL,
                            "Slippage=",             Slippage,                        ";", NL,
                            "ShowProfitInPercent=",  BoolToStr(ShowProfitInPercent),  ";", NL,
                            "EA.RecorderAutoScale=", BoolToStr(EA.RecorderAutoScale), ";")
   );
}
