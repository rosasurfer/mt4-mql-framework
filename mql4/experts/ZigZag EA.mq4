/**
 * A strategy inspired by the "Turtle Trading" system of Richard Dennis.
 *
 *  @see [Turtle Trading] https://analyzingalpha.com/turtle-trading
 *  @see [Turtle Trading] http://web.archive.org/web/20220417032905/https://vantagepointtrading.com/top-trader-richard-dennis-turtle-trading-strategy/
 *
 *
 * Features
 * --------
 *  � A finished test can be loaded into an online chart for trade inspection and further analysis.
 *
 *  � The EA constantly writes a status file with complete runtime data and detailed trade statistics (more detailed than
 *    the built-in functionality). This status file can be used to move a running EA instance with all historic runtime data
 *    between different machines (e.g. from laptop to VPS).
 *
 *  � The EA supports a "virtual trading mode" in which all trades are only emulated. This makes it possible to hide all
 *    trading related deviations that impact test or real results (tester bugs, spread, slippage, swap, commission).
 *    It allows the EA to be tested and adjusted under idealised conditions.
 *
 *  � The EA contains a recorder that can record several performance graphs simultaneously at runtime (also in tester).
 *    These recordings are saved as regular chart symbols in the history directory of a second MT4 terminal. They can be
 *    displayed and analysed like regular MT4 symbols.
 *
 *
 * Requirements
 * ------------
 *  � ZigZag indicator: @see https://github.com/rosasurfer/mt4-mql/blob/master/mql4/indicators/ZigZag.mq4
 *
 *
 * Input parameters
 * ----------------
 *  � EA.Recorder: Metrics to record, for syntax @see https://github.com/rosasurfer/mt4-mql/blob/master/mql4/include/core/expert.recorder.mqh
 *
 *     1: Records real PnL after all costs in account currency (net).
 *     2: Records real PnL after all costs in price units (net).
 *     3: Records signal level PnL before spread/any costs in price units.
 *
 *     4: Records daily real PnL after all costs in account currency (net).                                              TODO
 *     5: Records daily real PnL after all costs in price units (net).                                                   TODO
 *     6: Records daily signal level PnL before spread/any costs in price units.                                         TODO
 *
 *     Metrics in price units are recorded in the best matching unit. That's pip for Forex or full points otherwise.
 *
 *
 * External control
 * ----------------
 * The EA can be controlled via execution of the following scripts (online and in tester):
 *
 *  � EA.Start: When a "start" command is received the EA opens a position in direction of the current ZigZag leg. There are
 *              two sub-commands "start:long" and "start:short" to start the EA in a predefined direction. The command has no
 *              effect if the EA already manages an open position.
 *  � EA.Stop:  When a "stop" command is received the EA closes all open positions and stops waiting for trade signals. The
 *              command has no effect if the EA is already in status "stopped".
 *  � EA.Wait:  When a "wait" command is received a stopped EA will wait for new trade signals and start trading. The command
 *              has no effect if the EA is already in status "waiting".
 *  � EA.ToggleMetrics
 *  � Chart.ToggleOpenOrders
 *  � Chart.ToggleTradeHistory
 *
 *
 *
 * TODO:  *** Main objective is faster implementation and testing of new EAs. ***
 *
 *  - re-usable exit management
 *     breakeven stop
 *     partial profit taking
 *     1st: distances in static pips
 *     2nd: dynamic distances (multiples of range)
 *
 *      runtime:
 *       monitor executed limits
 *       process stops and targets
 *        handle limit execution during processing
 *
 *  - tests
 *     storage in folder per strategy
 *     more statistics: profit factor, sharp ratio, sortino ratio, calmar ratio
 *  - trailing stop
 *  - self-optimization
 *     13.07.2008: @tdion, inspiration for @rraygun   https://www.forexfactory.com/thread/95892-ma-cross-optimization-ea-very-cool#    statt MACD(16,18) MACD(ALMA(38,46))
 *     16.12.2009: @rraygun                           https://www.forexfactory.com/thread/211657-old-dog-with-new-tricks#
 *     16.11.2017: @john-davis, 100%/month on H1      https://www.mql5.com/en/blogs/post/714509#
 *                                                    https://www.mql5.com/en/market/product/26332#
 *                                                    https://www.mql5.com/en/code/19392#         (comments by @alphatrading)
 *  - money management
 *
 *
 *  -------------------------------------------------------------------------------------------------------------------------
 *  - reproduce/validate tests with original EAs
 *     terminal with Dukascopy data
 *     fast generation of old test data (e.g. 2007)
 *     visualize existing account statements
 *
 *
 *  -------------------------------------------------------------------------------------------------------------------------
 *  - rewrite loglevels to global vars
 *  - add ZigZag projections
 *  - input TradingTimeframe
 *  - fix virtual trading
 *  - on recorder restart the first recorded bar opens at instance.startEquity
 *  - rewrite Test_GetCommission()
 *  - document control scripts
 *  - block tests with bar model MODE_BAROPEN
 *
 *  - realtime metric charts
 *     on CreateRawSymbol() also create/update offline profile
 *     ChartInfos: read/display symbol description as long name
 *
 *  - performance (loglevel LOG_WARN)
 *     GBPJPY,M1 2024.01.15-2024.02.02, ZigZag(30), EveryTick:     21.5 sec, 432 trades, 1.737.000 ticks (on slowed down CPU: 30.0 sec)
 *     GBPJPY,M1 2024.01.15-2024.02.02, ZigZag(30), ControlPoints:  3.6 sec, 432 trades,   247.000 ticks
 *
 *     GBPJPY,M5 2024.01.15-2024.02.02, ZigZag(30), EveryTick:     20.4 sec,  93 trades, 1.732.000 ticks
 *     GBPJPY,M5 2024.01.15-2024.02.02, ZigZag(30), ControlPoints:  3.0 sec,  93 trades    243.000 ticks
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
 *     ETH/RTH separation for Frankfurt session
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
 *     support multiple units and targets (add new metrics)
 *
 *  - ChartInfos
 *     CustomPosition() weekend configuration/timespans don't work
 *     CustomPosition() including/excluding a specific strategy is not supported
 *     don't recalculate unitsize on every tick (every few seconds is sufficient)
 *
 *  - performance tracking
 *     notifications for price feed outages
 *     daily metrics
 *
 *  - status display
 *     parameter: ZigZag.Periods
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
 *  - fix log messages in ValidateInputs (conditionally display the instance name)
 *  - rewrite parameter stepping: remove commands from channel after processing
 *  - rewrite range bar generator
 *  - VPS: monitor and notify of incoming emails
 *  - CLI tools to rename/update/delete symbols
 */
#include <stddefines.mqh>
int   __InitFlags[] = {INIT_PIPVALUE, INIT_BUFFERED_LOG};
int __DeinitFlags[];
int __virtualTicks = 10000;         // every 10 seconds to continue operation on a stalled data feed

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern string Instance.ID                    = "";                      // instance to load from a status file, format "[T]123"
extern string TradingMode                    = "regular* | virtual";    // can be shortened

extern string ___a__________________________ = "=== Instance settings ===";
extern string StartConditions                = "";                      // @time(datetime|time)
extern string StopConditions                 = "";                      // @time(datetime|time)
extern double TakeProfit                     = 0;                       // TP value
extern string TakeProfit.Type                = "off* | percent | pip | quote-unit";  // can be shortened if distinct        // TODO: redefine point as punit

extern string ___b__________________________ = "=== Signal settings ===";
extern int    ZigZag.Periods                 = 30;

extern string ___c__________________________ = "=== Trade settings ===";
extern double Lots                           = 0.1;
extern int    Initial.TakeProfit             = 100;                     // in pip (0: partial targets only or no TP)
extern int    Initial.StopLoss               = 50;                      // in pip (0: moving stops only or no SL
extern int    Target1                        = 0;                       // in pip
extern int    Target1.ClosePercent           = 0;                       // size to close (0: nothing)
extern int    Target1.MoveStopTo             = 1;                       // in pip (0: don't move stop)
extern int    Target2                        = 0;                       // ...
extern int    Target2.ClosePercent           = 30;                      //
extern int    Target2.MoveStopTo             = 0;                       //
extern int    Target3                        = 0;                       //
extern int    Target3.ClosePercent           = 30;                      //
extern int    Target3.MoveStopTo             = 0;                       //
extern int    Target4                        = 0;                       //
extern int    Target4.ClosePercent           = 30;                      //
extern int    Target4.MoveStopTo             = 0;                       //

extern string ___d__________________________ = "=== Other ===";
extern bool   ShowProfitInPercent            = true;                    // whether PnL is displayed in money or percentage terms

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/expert.mqh>
#include <stdfunctions.mqh>
#include <rsfLib.mqh>
#include <functions/HandleCommands.mqh>
#include <functions/ParseDateTime.mqh>
#include <functions/iCustom/ZigZag.mqh>
#include <structs/rsf/OrderExecution.mqh>
#include <ea/functions/metric/defines.mqh>
#include <ea/functions/trade/defines.mqh>
#include <ea/functions/trade/stats/defines.mqh>

#define STRATEGY_ID               107              // unique strategy id between 101-1023 (10 bit)

#define INSTANCE_ID_MIN             1              // range of valid instance ids
#define INSTANCE_ID_MAX           999              //

#define STATUS_WAITING              1              // instance status values
#define STATUS_PROGRESSING          2
#define STATUS_STOPPED              3

#define TRADINGMODE_REGULAR         1              // trading modes
#define TRADINGMODE_VIRTUAL         2

#define SIGNAL_TYPE                 0              // signal object fields
#define SIGNAL_DIRECTION            1
#define SIGNAL_VALUE                2

#define SIGTYPE_MANUAL              1              // signal types
#define SIGTYPE_TIME                2
#define SIGTYPE_ZIGZAG              3
#define SIGTYPE_TAKEPROFIT          4

#define SIGDIRECTION_LONG  TRADE_DIRECTION_LONG    // 1 signal directions
#define SIGDIRECTION_SHORT TRADE_DIRECTION_SHORT   // 2

#define TP_TYPE_PERCENT             1              // instance stop-at-profit types
#define TP_TYPE_PIP                 2
#define TP_TYPE_PRICEUNIT           3

#define METRIC_DAILY_NET_MONEY      4              // non-standard PnL metrics
#define METRIC_DAILY_NET_UNITS      5
#define METRIC_DAILY_SIG_UNITS      6

// general
int      tradingMode;

// instance data
int      instance.id;                              // used for magic order numbers
string   instance.name = "";
datetime instance.created;
bool     instance.isTest;                          // whether the instance is a test
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

double   instance.openSigProfitP;                  // signal PnL before spread/any costs in point
double   instance.closedSigProfitP;                //
double   instance.totalSigProfitP;                 //
double   instance.maxSigProfitP;                   //
double   instance.maxSigDrawdownP;                 //

// order data
int      open.ticket;                              // one open position
int      open.type;
double   open.lots;
datetime open.time;
double   open.price;
double   open.priceSig;
double   open.slippage;
double   open.swap;
double   open.commission;
double   open.grossProfit;
double   open.netProfit;
double   open.netProfitP;
double   open.runupP;                              // max runup distance
double   open.drawdownP;                           // ...
double   open.sigProfitP;
double   open.sigRunupP;                           // max signal runup distance
double   open.sigDrawdownP;                        // ...

// instance start conditions
bool     start.time.condition;                     // whether a time condition is active
datetime start.time.value;
bool     start.time.isDaily;
string   start.time.description = "";

// instance stop conditions ("OR" combined)
bool     stop.time.condition;                      // whether a time condition is active
datetime stop.time.value;
bool     stop.time.isDaily;
string   stop.time.description = "";

bool     stop.profitPct.condition;                 // whether a takeprofit condition in percent is active
double   stop.profitPct.value;
double   stop.profitPct.absValue    = INT_MAX;
string   stop.profitPct.description = "";

bool     stop.profitPun.condition;                 // whether a takeprofit condition in price units is active (pip or full point)
int      stop.profitPun.type;
double   stop.profitPun.value;
string   stop.profitPun.description = "";

// volatile status data
int      status.activeMetric = 1;
bool     status.showOpenOrders;
bool     status.showTradeHistory;

// other
string   pUnit = "";
int      pDigits;
int      pMultiplier;
int      order.slippage = 1;                       // in MQL points
string   tradingModeDescriptions[] = {"", "regular", "virtual"};
string   tpTypeDescriptions     [] = {"off", "money", "percent", "pip", "quote currency", "index points"};

// cache vars to speed-up ShowStatus()
string   sTradingModeStatus[] = {"", "", "Virtual "};
string   sStartConditions     = "";
string   sStopConditions      = "";
string   sMetricDescription   = "";
string   sOpenLots            = "";
string   sClosedTrades        = "";
string   sTotalProfit         = "";
string   sProfitStats         = "";

// debug settings, configurable via framework config, see afterInit()
bool     test.onReversalPause     = false;         // whether to pause a test after a ZigZag reversal
bool     test.onSessionBreakPause = false;         // whether to pause a test after StopInstance(SIGNAL_TIME)
bool     test.onStopPause         = false;         // whether to pause a test after a final StopInstance()
bool     test.reduceStatusWrites  = true;          // whether to reduce status file I/O in tester

// initialization/deinitialization
#include <ea/zigzag-ea/init.mqh>
#include <ea/zigzag-ea/deinit.mqh>

// shared functions
#include <ea/functions/CalculateMagicNumber.mqh>
#include <ea/functions/CreateInstanceId.mqh>
#include <ea/functions/IsMyOrder.mqh>
#include <ea/functions/IsTestInstance.mqh>
#include <ea/functions/RestoreInstance.mqh>
#include <ea/functions/SetInstanceId.mqh>

#include <ea/functions/ShowTradeHistory.mqh>
#include <ea/functions/ToggleOpenOrders.mqh>
#include <ea/functions/ToggleTradeHistory.mqh>

#include <ea/functions/log/GetLogFilename.mqh>

#include <ea/functions/metric/RecordMetrics.mqh>
#include <ea/functions/metric/ToggleMetrics.mqh>

#include <ea/functions/status/StatusToStr.mqh>
#include <ea/functions/status/StatusDescription.mqh>
#include <ea/functions/status/SS.InstanceName.mqh>
#include <ea/functions/status/SS.MetricDescription.mqh>
#include <ea/functions/status/SS.OpenLots.mqh>
#include <ea/functions/status/SS.ClosedTrades.mqh>
#include <ea/functions/status/SS.TotalProfit.mqh>
#include <ea/functions/status/SS.ProfitStats.mqh>

#include <ea/functions/status/file/FindStatusFile.mqh>
#include <ea/functions/status/file/GetStatusFilename.mqh>
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

#include <ea/functions/status/volatile/StoreVolatileData.mqh>
#include <ea/functions/status/volatile/RestoreVolatileData.mqh>
#include <ea/functions/status/volatile/RemoveVolatileData.mqh>

#include <ea/functions/trade/AddHistoryRecord.mqh>
#include <ea/functions/trade/HistoryRecordToStr.mqh>
#include <ea/functions/trade/MovePositionToHistory.mqh>
#include <ea/functions/trade/stats/CalculateStats.mqh>

#include <ea/functions/validation/ValidateInputs.ID.mqh>
#include <ea/functions/validation/ValidateInputs.Targets.mqh>
#include <ea/functions/validation/onInputError.mqh>


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   if (!instance.status) return(catch("onTick(1)  illegal instance.status: "+ instance.status, ERR_ILLEGAL_STATE));

   if (__isChart) HandleCommands();                // process incoming commands

   if (instance.status != STATUS_STOPPED) {
      double signal[3];

      if (instance.status == STATUS_WAITING) {
         if (IsStartSignal(signal)) StartInstance(signal);
      }
      else if (instance.status == STATUS_PROGRESSING) {
         if (UpdateStatus()) {
            if      (IsStopSignal(signal))   StopInstance(signal);
            else if (IsZigZagSignal(signal)) ReverseInstance(signal);
         }
      }
      RecordMetrics();
   }
   return(catch("onTick(2)"));
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
            double signal[3];
            string sDetail = " ";
            int logLevel = LOG_INFO;

            signal[SIGNAL_TYPE ] = SIGTYPE_MANUAL;
            signal[SIGNAL_VALUE] = NULL;
            if      (params == "long")  signal[SIGNAL_DIRECTION] = SIGDIRECTION_LONG;
            else if (params == "short") signal[SIGNAL_DIRECTION] = SIGDIRECTION_SHORT;
            else {
               signal[SIGNAL_DIRECTION] = ifInt(GetZigZagTrend(0) > 0, SIGDIRECTION_LONG, SIGDIRECTION_SHORT);
               if (params != "") {
                  sDetail  = " skipping unsupported parameter in command ";
                  logLevel = LOG_NOTICE;
               }
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
            double manual[] = {SIGTYPE_MANUAL, 0, 0};
            return(StopInstance(manual));
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
      return(ToggleMetrics(direction, METRIC_NET_MONEY, METRIC_SIG_UNITS));
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
 * Whether a new ZigZag reversal occurred.
 *
 * @param  _Out_ double &signal[] - array receiving signal details
 *
 * @return bool
 */
bool IsZigZagSignal(double &signal[]) {
   if (last_error != NULL) return(false);

   static int lastTick, lastType, lastDirection, lastSigBar, lastSigDirection;
   static double lastValue, reversalPrice;
   int trend, reversalOffset;

   if (Ticks == lastTick) {
      signal[SIGNAL_TYPE     ] = lastType;
      signal[SIGNAL_DIRECTION] = lastDirection;
      signal[SIGNAL_VALUE    ] = lastValue;
   }
   else {
      signal[SIGNAL_TYPE] = NULL;

      if (!GetZigZagData(0, trend, reversalOffset, reversalPrice)) return(!logError("IsZigZagSignal(1)  "+ instance.name +" GetZigZagData(0) => FALSE", ERR_RUNTIME_ERROR));
      int absTrend = MathAbs(trend);
      bool isReversal = false;
      if      (absTrend == reversalOffset)     isReversal = true;             // regular reversal
      else if (absTrend==1 && !reversalOffset) isReversal = true;             // reversal after double crossing

      if (isReversal) {
         if (trend > 0) int direction = SIGDIRECTION_LONG;
         else               direction = SIGDIRECTION_SHORT;

         if (Time[0]!=lastSigBar || direction!=lastSigDirection) {
            signal[SIGNAL_TYPE     ] = SIGTYPE_ZIGZAG;
            signal[SIGNAL_DIRECTION] = direction;
            signal[SIGNAL_VALUE    ] = reversalPrice;

            if (IsLogNotice()) logNotice("IsZigZagSignal(2)  "+ instance.name +" "+ ifString(direction==SIGDIRECTION_LONG, "long", "short") +" reversal at "+ NumberToStr(reversalPrice, PriceFormat) +" (market: "+ NumberToStr(Bid, PriceFormat) +"/"+ NumberToStr(Ask, PriceFormat) +")");
            lastSigBar       = Time[0];
            lastSigDirection = direction;

            if (IsVisualMode()) {
               if (test.onReversalPause) Tester.Pause("IsZigZagSignal(3)");   // pause the tester according to the debug configuration
            }
         }
      }
      lastTick      = Ticks;
      lastType      = signal[SIGNAL_TYPE     ];
      lastDirection = signal[SIGNAL_DIRECTION];
      lastValue     = signal[SIGNAL_VALUE    ];
   }
   return(signal[SIGNAL_TYPE] != NULL);
}


/**
 * Get ZigZag buffer values at the specified bar offset. The returned values correspond to the documented indicator buffers.
 *
 * @param  _In_  int    bar             - bar offset
 * @param  _Out_ int    &trend          - MODE_TREND: combined buffers MODE_KNOWN_TREND + MODE_UNKNOWN_TREND
 * @param  _Out_ int    &reversalOffset - MODE_REVERSAL: bar offset of most recent ZigZag reversal to previous ZigZag semaphore
 * @param  _Out_ double &reversalPrice  - MODE_(UPPER|LOWER)_CROSS: reversal price if the bar denotes a ZigZag reversal; otherwise 0
 *
 * @return bool - success status
 */
bool GetZigZagData(int bar, int &trend, int &reversalOffset, double &reversalPrice) {
   trend          = MathRound(icZigZag(NULL, ZigZag.Periods, ZigZag.MODE_TREND,    bar));
   reversalOffset = MathRound(icZigZag(NULL, ZigZag.Periods, ZigZag.MODE_REVERSAL, bar));

   if (trend > 0) reversalPrice = icZigZag(NULL, ZigZag.Periods, ZigZag.MODE_UPPER_CROSS, bar);
   else           reversalPrice = icZigZag(NULL, ZigZag.Periods, ZigZag.MODE_LOWER_CROSS, bar);
   return(!last_error && trend);
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
   double dNull;
   if (!GetZigZagData(bar, trend, iNull, dNull)) return(NULL);
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
      return(!catch("IsTradingTime(1)  "+ instance.name +" start.time=(empty) + stop.time=(empty) not implemented", ERR_NOT_IMPLEMENTED));
   }
   else if (!stop.time.condition) {                         // case 2 or 5
      return(!catch("IsTradingTime(2)  "+ instance.name +" stop.time=(empty) not implemented", ERR_NOT_IMPLEMENTED));
   }
   else if (!start.time.condition) {                        // case 3 or 6
      return(!catch("IsTradingTime(3)  "+ instance.name +" start.time=(empty) not implemented", ERR_NOT_IMPLEMENTED));
   }
   else if (!start.time.isDaily && !stop.time.isDaily) {    // case 4
      return(!catch("IsTradingTime(4)  "+ instance.name +" start.time=(fix) + stop.time=(fix) not implemented", ERR_NOT_IMPLEMENTED));
   }
   else if (start.time.isDaily && stop.time.isDaily) {      // case 7
      if (IsStrategyBreak()) return(false);
   }
   else if (stop.time.isDaily) {                            // case 8
      return(!catch("IsTradingTime(5)  "+ instance.name +" start.time=(fix) + stop.time=(daily) not implemented", ERR_NOT_IMPLEMENTED));
   }
   else {                                                   // case 9
      return(!catch("IsTradingTime(6)  "+ instance.name +" start.time=(daily) + stop.time=(fix) not implemented", ERR_NOT_IMPLEMENTED));
   }
   return(true);
}


/**
 * Whether a start condition is triggered.
 *
 * @param  _Out_ double &signal[] - array receiving signal infos of a triggered condition
 *
 * @return bool
 */
bool IsStartSignal(double &signal[]) {
   if (last_error || instance.status!=STATUS_WAITING) return(false);
   signal[SIGNAL_TYPE] = NULL;

   // start.time ------------------------------------------------------------------------------------------------------------
   if (!IsTradingTime()) {
      return(false);
   }

   // ZigZag signal ---------------------------------------------------------------------------------------------------------
   if (IsZigZagSignal(signal)) {
      return(true);
   }
   return(false);
}


/**
 * Whether a stop condition is triggered.
 *
 * @param  _Out_ double &signal[] - array receiving the stop signal infos (if any)
 *
 * @return bool
 */
bool IsStopSignal(double &signal[]) {
   signal[SIGNAL_TYPE] = NULL;
   if (last_error || (instance.status!=STATUS_WAITING && instance.status!=STATUS_PROGRESSING)) return(false);

   if (instance.status == STATUS_PROGRESSING) {
      // stop.profitPct -----------------------------------------------------------------------------------------------------
      if (stop.profitPct.condition) {
         if (stop.profitPct.absValue == INT_MAX)
            stop.profitPct.absValue = stop.profitPct.AbsValue();

         if (instance.totalNetProfit >= stop.profitPct.absValue) {
            signal[SIGNAL_TYPE     ] = SIGTYPE_TAKEPROFIT;
            signal[SIGNAL_DIRECTION] = NULL;
            signal[SIGNAL_VALUE    ] = stop.profitPct.value;
            if (IsLogNotice()) logNotice("IsStopSignal(1)  "+ instance.name +" stop condition \"@"+ stop.profitPct.description +"\" triggered (market: "+ NumberToStr(Bid, PriceFormat) +"/"+ NumberToStr(Ask, PriceFormat) +")");
            return(true);
         }
      }

      // stop.profitPun -----------------------------------------------------------------------------------------------------
      if (stop.profitPun.condition) {
         if (instance.totalNetProfitP >= stop.profitPun.value) {
            signal[SIGNAL_TYPE     ] = SIGTYPE_TAKEPROFIT;
            signal[SIGNAL_DIRECTION] = NULL;
            signal[SIGNAL_VALUE    ] = stop.profitPun.value;
            if (IsLogNotice()) logNotice("IsStopSignal(2)  "+ instance.name +" stop condition \"@"+ stop.profitPun.description +"\" triggered (market: "+ NumberToStr(Bid, PriceFormat) +"/"+ NumberToStr(Ask, PriceFormat) +")");
            return(true);
         }
      }
   }

   // stop.time -------------------------------------------------------------------------------------------------------------
   if (stop.time.condition) {
      if (!IsTradingTime()) {
         signal[SIGNAL_TYPE     ] = SIGTYPE_TIME;
         signal[SIGNAL_DIRECTION] = NULL;
         signal[SIGNAL_VALUE    ] = NULL;
         if (IsLogNotice()) logNotice("IsStopSignal(3)  "+ instance.name +" stop condition \"@"+ stop.time.description +"\" triggered (market: "+ NumberToStr(Bid, PriceFormat) +"/"+ NumberToStr(Ask, PriceFormat) +")");
         return(true);
      }
   }
   return(false);
}


/**
 * Start a waiting or restart a stopped instance.
 *
 * @param  double signal[] - signal infos causing the call
 *
 * @return bool - success status
 */
bool StartInstance(double signal[]) {
   if (last_error != NULL)                                                 return(false);
   if (instance.status!=STATUS_WAITING && instance.status!=STATUS_STOPPED) return(!catch("StartInstance(1)  "+ instance.name +" cannot start "+ StatusDescription(instance.status) +" instance", ERR_ILLEGAL_STATE));
   if (!signal[SIGNAL_DIRECTION])                                          return(!catch("StartInstance(2)  "+ instance.name +" invalid parameter SIGNAL_DIRECTION: "+ _int(signal[SIGNAL_DIRECTION]), ERR_INVALID_PARAMETER));

   int sigType      = signal[SIGNAL_TYPE];
   int sigDirection = signal[SIGNAL_DIRECTION];
   double sigValue  = signal[SIGNAL_VALUE];

   instance.status = STATUS_PROGRESSING;
   if (!instance.startEquity) instance.startEquity = NormalizeDouble(AccountEquity() - AccountCredit() + GetExternalAssets(), 2);

   // open a new position
   int      type        = ifInt(sigDirection==SIGDIRECTION_LONG, OP_BUY, OP_SELL);
   double   price       = NULL;
   datetime expires     = NULL;
   string   comment     = "ZigZag."+ StrPadLeft(instance.id, 3, "0");
   int      magicNumber = CalculateMagicNumber(instance.id);
   color    marker      = ifInt(type==OP_BUY, CLR_OPEN_LONG, CLR_OPEN_SHORT);

   int ticket, oeFlags, oe[];
   if (tradingMode == TRADINGMODE_VIRTUAL) ticket = VirtualOrderSend(type, Lots, NULL, NULL, marker, oe);
   else                                    ticket = OrderSendEx(Symbol(), type, Lots, price, order.slippage, NULL, NULL, comment, magicNumber, expires, marker, oeFlags, oe);
   if (!ticket) return(!SetLastError(oe.Error(oe)));

   // store the position data
   open.ticket       = ticket;
   open.type         = type;
   open.lots         = oe.Lots(oe);
   open.time         = oe.OpenTime(oe);
   open.price        = oe.OpenPrice(oe);
   open.priceSig     = sigValue;
   open.slippage     = oe.Slippage(oe);
   open.swap         = oe.Swap(oe);
   open.commission   = oe.Commission(oe);
   open.grossProfit  = oe.Profit(oe);
   open.netProfit    = open.grossProfit + open.swap + open.commission;
   open.netProfitP   = ifDouble(type==OP_BUY, Bid-open.price, open.price-Ask) + (open.swap + open.commission)/PointValue(open.lots);
   open.runupP       = ifDouble(type==OP_BUY, Bid-open.price, open.price-Ask);
   open.drawdownP    = open.runupP;
   open.sigProfitP   = ifDouble(type==OP_BUY, Bid-open.priceSig, open.priceSig-Bid);
   open.sigRunupP    = open.sigProfitP;
   open.sigDrawdownP = open.sigRunupP;

   // update PL numbers
   instance.openNetProfit  = open.netProfit;
   instance.totalNetProfit = instance.openNetProfit + instance.closedNetProfit;
   instance.maxNetProfit   = MathMax(instance.maxNetProfit,   instance.totalNetProfit);
   instance.maxNetDrawdown = MathMin(instance.maxNetDrawdown, instance.totalNetProfit);

   instance.openNetProfitP  = open.netProfitP;
   instance.totalNetProfitP = instance.openNetProfitP + instance.closedNetProfitP;
   instance.maxNetProfitP   = MathMax(instance.maxNetProfitP,   instance.totalNetProfitP);
   instance.maxNetDrawdownP = MathMin(instance.maxNetDrawdownP, instance.totalNetProfitP);

   instance.openSigProfitP  = open.sigProfitP;
   instance.totalSigProfitP = instance.openSigProfitP + instance.closedSigProfitP;
   instance.maxSigProfitP   = MathMax(instance.maxSigProfitP,   instance.totalSigProfitP);
   instance.maxSigDrawdownP = MathMin(instance.maxSigDrawdownP, instance.totalSigProfitP);

   // update start conditions
   if (start.time.condition) {
      if (!start.time.isDaily || !stop.time.condition) {                   // see start/stop time variants
         start.time.condition = false;
      }
   }

   if (__isChart) {
      SS.OpenLots();
      SS.TotalProfit(ShowProfitInPercent);
      SS.ProfitStats(ShowProfitInPercent);
      SS.StartStopConditions();
   }
   if (IsLogInfo()) logInfo("StartInstance(3)  "+ instance.name +" instance started ("+ SignalDirectionToStr(sigDirection) +")");
   return(SaveStatus());
}


/**
 * Reverse a progressing instance.
 *
 * @param  double signal[] - signal infos causing the call
 *
 * @return bool - success status
 */
bool ReverseInstance(double signal[]) {
   if (last_error != NULL)                    return(false);
   if (instance.status != STATUS_PROGRESSING) return(!catch("ReverseInstance(1)  "+ instance.name +" cannot reverse "+ StatusDescription(instance.status) +" instance", ERR_ILLEGAL_STATE));
   if (!signal[SIGNAL_DIRECTION])             return(!catch("ReverseInstance(2)  "+ instance.name +" invalid parameter SIGNAL_DIRECTION: "+ _int(signal[SIGNAL_DIRECTION]), ERR_INVALID_PARAMETER));
   int ticket, oeFlags, oe[];

   int    sigType      = signal[SIGNAL_TYPE];
   int    sigDirection = signal[SIGNAL_DIRECTION];
   double sigValue     = signal[SIGNAL_VALUE];

   if (open.ticket != NULL) {
      // continue with an already reversed position
      if ((open.type==OP_BUY && sigDirection==SIGDIRECTION_LONG) || (open.type==OP_SELL && sigDirection==SIGDIRECTION_SHORT)) {
         return(_true(logWarn("ReverseInstance(3)  "+ instance.name +" to "+ ifString(sigDirection==SIGDIRECTION_LONG, "long", "short") +": continuing with already open "+ ifString(tradingMode==TRADINGMODE_VIRTUAL, "virtual ", "") + ifString(sigDirection==SIGDIRECTION_LONG, "long", "short") +" position #"+ open.ticket)));
      }

      // close the existing position
      bool success;
      if (tradingMode == TRADINGMODE_VIRTUAL) success = VirtualOrderClose(open.ticket, open.lots, CLR_NONE, oe);
      else                                    success = OrderCloseEx(open.ticket, NULL, order.slippage, CLR_NONE, oeFlags, oe);
      if (!success) return(!SetLastError(oe.Error(oe)));

      double closePrice = oe.ClosePrice(oe);
      open.slippage    += oe.Slippage(oe);
      open.swap         = oe.Swap(oe);
      open.commission   = oe.Commission(oe);
      open.grossProfit  = oe.Profit(oe);
      open.netProfit    = open.grossProfit + open.swap + open.commission;
      open.netProfitP   = ifDouble(open.type==OP_BUY, closePrice-open.price, open.price-closePrice);
      open.runupP       = MathMax(open.runupP, open.netProfitP);
      open.drawdownP    = MathMin(open.drawdownP, open.netProfitP); open.netProfitP += (open.swap + open.commission)/PointValue(open.lots);
      open.sigProfitP   = ifDouble(open.type==OP_BUY, sigValue-open.priceSig, open.priceSig-sigValue);
      open.sigRunupP    = MathMax(open.sigRunupP, open.sigProfitP);
      open.sigDrawdownP = MathMin(open.sigDrawdownP, open.sigProfitP);

      if (!MovePositionToHistory(oe.CloseTime(oe), closePrice, sigValue)) return(false);
   }

   // open a new position
   int      type        = ifInt(sigDirection==SIGDIRECTION_LONG, OP_BUY, OP_SELL);
   double   price       = NULL;
   datetime expires     = NULL;
   string   comment     = "ZigZag."+ StrPadLeft(instance.id, 3, "0");
   int      magicNumber = CalculateMagicNumber(instance.id);
   color    marker      = ifInt(type==OP_BUY, CLR_OPEN_LONG, CLR_OPEN_SHORT);

   if (tradingMode == TRADINGMODE_VIRTUAL) ticket = VirtualOrderSend(type, Lots, NULL, NULL, marker, oe);
   else                                    ticket = OrderSendEx(Symbol(), type, Lots, price, order.slippage, NULL, NULL, comment, magicNumber, expires, marker, oeFlags, oe);
   if (!ticket) return(!SetLastError(oe.Error(oe)));

   // store the new position data
   open.ticket       = ticket;
   open.type         = type;
   open.lots         = oe.Lots(oe);
   open.time         = oe.OpenTime(oe);
   open.price        = oe.OpenPrice(oe);
   open.priceSig     = sigValue;
   open.slippage     = oe.Slippage(oe);
   open.swap         = oe.Swap(oe);
   open.commission   = oe.Commission(oe);
   open.grossProfit  = oe.Profit(oe);
   open.netProfit    = open.grossProfit + open.swap + open.commission;
   open.netProfitP   = ifDouble(type==OP_BUY, Bid-open.price, open.price-Ask) + (open.swap + open.commission)/PointValue(open.lots);
   open.runupP       = ifDouble(type==OP_BUY, Bid-open.price, open.price-Ask);
   open.drawdownP    = open.runupP;
   open.sigProfitP   = ifDouble(type==OP_BUY, Bid-open.priceSig, open.priceSig-Bid);
   open.sigRunupP    = open.sigProfitP;
   open.sigDrawdownP = open.sigProfitP;

   // update PL numbers
   instance.openNetProfit  = open.netProfit;
   instance.totalNetProfit = instance.openNetProfit + instance.closedNetProfit;
   instance.maxNetProfit   = MathMax(instance.maxNetProfit,   instance.totalNetProfit);
   instance.maxNetDrawdown = MathMin(instance.maxNetDrawdown, instance.totalNetProfit);

   instance.openNetProfitP  = open.netProfitP;
   instance.totalNetProfitP = instance.openNetProfitP + instance.closedNetProfitP;
   instance.maxNetProfitP   = MathMax(instance.maxNetProfitP,   instance.totalNetProfitP);
   instance.maxNetDrawdownP = MathMin(instance.maxNetDrawdownP, instance.totalNetProfitP);

   instance.openSigProfitP  = open.sigProfitP;
   instance.totalSigProfitP = instance.openSigProfitP + instance.closedSigProfitP;
   instance.maxSigProfitP   = MathMax(instance.maxSigProfitP,   instance.totalSigProfitP);
   instance.maxSigDrawdownP = MathMin(instance.maxSigDrawdownP, instance.totalSigProfitP);

   if (__isChart) {
      SS.OpenLots();
      SS.TotalProfit(ShowProfitInPercent);
      SS.ProfitStats(ShowProfitInPercent);
   }
   if (IsLogInfo()) logInfo("ReverseInstance(4)  "+ instance.name +" instance reversed ("+ SignalDirectionToStr(sigDirection) +")");
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
 * @param  double signal[] - signal which triggered the stop condition
 *
 * @return bool - success status
 */
bool StopInstance(double signal[]) {
   if (last_error != NULL)                                                     return(false);
   if (instance.status!=STATUS_WAITING && instance.status!=STATUS_PROGRESSING) return(!catch("StopInstance(1)  "+ instance.name +" cannot stop "+ StatusDescription(instance.status) +" instance", ERR_ILLEGAL_STATE));

   int    sigType      = signal[SIGNAL_TYPE];
   int    sigDirection = signal[SIGNAL_DIRECTION];
   double sigValue     = signal[SIGNAL_VALUE];

   // close an open position
   if (instance.status == STATUS_PROGRESSING) {
      if (open.ticket > 0) {
         bool success;
         int oeFlags, oe[];
         if (tradingMode == TRADINGMODE_VIRTUAL) success = VirtualOrderClose(open.ticket, open.lots, CLR_NONE, oe);
         else                                    success = OrderCloseEx(open.ticket, NULL, order.slippage, CLR_NONE, oeFlags, oe);
         if (!success) return(!SetLastError(oe.Error(oe)));

         double closePrice = oe.ClosePrice(oe), closePriceSig = doubleOr(sigValue, Bid);
         open.slippage    += oe.Slippage(oe);
         open.swap         = oe.Swap(oe);
         open.commission   = oe.Commission(oe);
         open.grossProfit  = oe.Profit(oe);
         open.netProfit    = open.grossProfit + open.swap + open.commission;
         open.netProfitP   = ifDouble(open.type==OP_BUY, closePrice-open.price, open.price-closePrice);
         open.runupP       = MathMax(open.runupP, open.netProfitP);
         open.drawdownP    = MathMin(open.drawdownP, open.netProfitP); open.netProfitP += (open.swap + open.commission)/PointValue(open.lots);
         open.sigProfitP   = ifDouble(open.type==OP_BUY, closePriceSig-open.priceSig, open.priceSig-closePriceSig);
         open.sigRunupP    = MathMax(open.sigRunupP, open.sigProfitP);
         open.sigDrawdownP = MathMin(open.sigDrawdownP, open.sigProfitP);

         if (!MovePositionToHistory(oe.CloseTime(oe), closePrice, closePriceSig)) return(false);

         instance.openNetProfit  = open.netProfit;
         instance.totalNetProfit = instance.openNetProfit + instance.closedNetProfit;
         instance.maxNetProfit   = MathMax(instance.maxNetProfit,   instance.totalNetProfit);
         instance.maxNetDrawdown = MathMin(instance.maxNetDrawdown, instance.totalNetProfit);

         instance.openNetProfitP  = open.netProfitP;
         instance.totalNetProfitP = instance.openNetProfitP + instance.closedNetProfitP;
         instance.maxNetProfitP   = MathMax(instance.maxNetProfitP,   instance.totalNetProfitP);
         instance.maxNetDrawdownP = MathMin(instance.maxNetDrawdownP, instance.totalNetProfitP);

         instance.openSigProfitP  = open.sigProfitP;
         instance.totalSigProfitP = instance.openSigProfitP + instance.closedSigProfitP;
         instance.maxSigProfitP   = MathMax(instance.maxSigProfitP,   instance.totalSigProfitP);
         instance.maxSigDrawdownP = MathMin(instance.maxSigDrawdownP, instance.totalSigProfitP);
      }
   }

   // update stop conditions and status
   switch (sigType) {
      case SIGTYPE_TIME:
         if (!stop.time.isDaily) {
            stop.time.condition = false;                    // see start/stop time variants
         }
         instance.status = ifInt(start.time.condition && start.time.isDaily, STATUS_WAITING, STATUS_STOPPED);
         break;

      case SIGTYPE_TAKEPROFIT:
         stop.profitPct.condition = false;
         stop.profitPun.condition = false;
         instance.status          = STATUS_STOPPED;
         break;

      case SIGTYPE_MANUAL:                                  // explicit stop (manual) or end of test
         instance.status = STATUS_STOPPED;
         break;

      default: return(!catch("StopInstance(2)  "+ instance.name +" invalid parameter SIGNAL_TYPE: "+ sigType, ERR_INVALID_PARAMETER));
   }
   SS.StartStopConditions();
   SS.TotalProfit(ShowProfitInPercent);
   SS.ProfitStats(ShowProfitInPercent);

   if (IsLogInfo()) logInfo("StopInstance(3)  "+ instance.name +" "+ ifString(__isTesting && sigType==SIGTYPE_MANUAL, "test ", "") +"instance stopped"+ ifString(sigType==SIGTYPE_MANUAL, "", " ("+ SignalTypeToStr(sigType) +")") +", profit: "+ sTotalProfit +" "+ sProfitStats);
   SaveStatus();

   // pause/stop the tester according to the debug configuration
   if (__isTesting) {
      if      (!IsVisualMode())         { if (instance.status == STATUS_STOPPED) Tester.Stop ("StopInstance(4)"); }
      else if (sigType == SIGTYPE_TIME) { if (test.onSessionBreakPause)          Tester.Pause("StopInstance(5)"); }
      else                              { if (test.onStopPause)                  Tester.Pause("StopInstance(6)"); }
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
      open.netProfitP   = ifDouble(open.type==OP_BUY, Bid-open.price, open.price-Ask);
      open.runupP       = MathMax(open.runupP, open.netProfitP);
      open.drawdownP    = MathMin(open.drawdownP, open.netProfitP);
      open.netProfit    = open.netProfitP * PointValue(open.lots);
      open.grossProfit  = open.netProfit;
      open.sigProfitP   = ifDouble(open.type==OP_BUY, Bid-open.priceSig, open.priceSig-Bid);
      open.sigRunupP    = MathMax(open.sigRunupP, open.sigProfitP);
      open.sigDrawdownP = MathMin(open.sigDrawdownP, open.sigProfitP);
   }
   else {
      if (!SelectTicket(open.ticket, "UpdateStatus(2)")) return(false);
      bool isClosed = (OrderCloseTime() != NULL);
      if (isClosed) {
         double exitPrice=OrderClosePrice(), exitPriceSig=exitPrice;
      }
      else {
         exitPrice = ifDouble(open.type==OP_BUY, Bid, Ask);
         exitPriceSig = Bid;
      }
      open.swap         = NormalizeDouble(OrderSwap(), 2);
      open.commission   = OrderCommission();
      open.grossProfit  = OrderProfit();
      open.netProfit    = open.grossProfit + open.swap + open.commission;
      open.netProfitP   = ifDouble(open.type==OP_BUY, exitPrice-open.price, open.price-exitPrice);
      open.runupP       = MathMax(open.runupP, open.netProfitP);
      open.drawdownP    = MathMin(open.drawdownP, open.netProfitP); if (open.swap || open.commission) open.netProfitP += (open.swap + open.commission)/PointValue(open.lots);
      open.sigProfitP   = ifDouble(open.type==OP_BUY, exitPriceSig-open.priceSig, open.priceSig-exitPriceSig);
      open.sigRunupP    = MathMax(open.sigRunupP, open.sigProfitP);
      open.sigDrawdownP = MathMin(open.sigDrawdownP, open.sigProfitP);

      if (isClosed) {
         int error;
         if (IsError(onPositionClose("UpdateStatus(3)  "+ instance.name +" "+ UpdateStatus.PositionCloseMsg(error), error))) return(false);
         if (!MovePositionToHistory(OrderCloseTime(), exitPrice, exitPriceSig))                                              return(false);
      }
   }

   instance.openNetProfit  = open.netProfit;
   instance.openNetProfitP = open.netProfitP;
   instance.openSigProfitP = open.sigProfitP;

   instance.totalNetProfit  = instance.openNetProfit  + instance.closedNetProfit;
   instance.totalNetProfitP = instance.openNetProfitP + instance.closedNetProfitP;
   instance.totalSigProfitP = instance.openSigProfitP + instance.closedSigProfitP;
   if (__isChart) SS.TotalProfit(ShowProfitInPercent);

   instance.maxNetProfit    = MathMax(instance.maxNetProfit,    instance.totalNetProfit);
   instance.maxNetDrawdown  = MathMin(instance.maxNetDrawdown,  instance.totalNetProfit);
   instance.maxNetProfitP   = MathMax(instance.maxNetProfitP,   instance.totalNetProfitP);
   instance.maxNetDrawdownP = MathMin(instance.maxNetDrawdownP, instance.totalNetProfitP);
   instance.maxSigProfitP   = MathMax(instance.maxSigProfitP,   instance.totalSigProfitP);
   instance.maxSigDrawdownP = MathMin(instance.maxSigDrawdownP, instance.totalSigProfitP);
   if (__isChart) SS.ProfitStats(ShowProfitInPercent);

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

   ready      = false;
   group      = "";
   baseValue  = EMPTY;
   digits     = pDigits;
   multiplier = pMultiplier;

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
      case METRIC_NET_MONEY:              // OK
         symbol      = StrLeft(Symbol(), 6) +"."+ sId +"A";                      // "US500.123A"
         descrSuffix = ", "+ PeriodDescription() +", "+ sBarModel +", net PnL, "+ AccountCurrency() + LocalTimeFormat(GetGmtTime(), ", %d.%m.%Y %H:%M");
         digits      = 2;
         multiplier  = 1;
         break;

      case METRIC_NET_UNITS:              // OK
         symbol      = StrLeft(Symbol(), 6) +"."+ sId +"B";
         descrSuffix = ", "+ PeriodDescription() +", "+ sBarModel +", net PnL, "+ pUnit + LocalTimeFormat(GetGmtTime(), ", %d.%m.%Y %H:%M");
         break;

      case METRIC_SIG_UNITS:              // OK
         symbol      = StrLeft(Symbol(), 6) +"."+ sId +"C";
         descrSuffix = ", "+ PeriodDescription() +", "+ sBarModel +", signal PnL, "+ pUnit + LocalTimeFormat(GetGmtTime(), ", %d.%m.%Y %H:%M");
         break;

      // --- custom daily metrics -------------------------------------------------------------------------------------------
      case METRIC_DAILY_NET_MONEY:
         symbol      = StrLeft(Symbol(), 6) +"."+ sId +"D";
         descrSuffix = ", "+ PeriodDescription() +", "+ sBarModel +", net PnL/day, "+ AccountCurrency() + LocalTimeFormat(GetGmtTime(), ", %d.%m.%Y %H:%M");
         digits      = 2;
         multiplier  = 1;
         break;

      case METRIC_DAILY_NET_UNITS:
         symbol      = StrLeft(Symbol(), 6) +"."+ sId +"E";
         descrSuffix = ", "+ PeriodDescription() +", "+ sBarModel +", net PnL/day, "+ pUnit + LocalTimeFormat(GetGmtTime(), ", %d.%m.%Y %H:%M");
         break;

      case METRIC_DAILY_SIG_UNITS:
         symbol      = StrLeft(Symbol(), 6) +"."+ sId +"F";
         descrSuffix = ", "+ PeriodDescription() +", "+ sBarModel +", signal PnL/day, "+ pUnit + LocalTimeFormat(GetGmtTime(), ", %d.%m.%Y %H:%M");
         break;

      default:
         return(ERR_INVALID_INPUT_PARAMETER);
   }

   description = StrLeft(ProgramName(), 63-StringLen(descrSuffix )) + descrSuffix;
   ready = (instance.id > 0);

   return(NO_ERROR);
}


/**
 * Return a readable representation of a signal type constant.
 *
 * @param  int type
 *
 * @return string - readable constant or an empty string in case of errors
 */
string SignalTypeToStr(int type) {
   switch (type) {
      case NULL              : return("no type"           );
      case SIGTYPE_MANUAL    : return("SIGTYPE_MANUAL"    );
      case SIGTYPE_TIME      : return("SIGTYPE_TIME"      );
      case SIGTYPE_ZIGZAG    : return("SIGTYPE_ZIGZAG"    );
      case SIGTYPE_TAKEPROFIT: return("SIGTYPE_TAKEPROFIT");
   }
   return(_EMPTY_STR(catch("SignalTypeToStr(1)  "+ instance.name +" invalid parameter type: "+ type, ERR_INVALID_PARAMETER)));
}


/**
 * Return a readable representation of a signal direction constant.
 *
 * @param  int direction
 *
 * @return string - readable constant or an empty string in case of errors
 */
string SignalDirectionToStr(int direction) {
   switch (direction) {
      case NULL              : return("no direction"      );
      case SIGDIRECTION_LONG : return("SIGDIRECTION_LONG" );
      case SIGDIRECTION_SHORT: return("SIGDIRECTION_SHORT");
   }
   return(_EMPTY_STR(catch("SignalDirectionToStr(1)  "+ instance.name +" invalid parameter direction: "+ direction, ERR_INVALID_PARAMETER)));
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
   if (!SaveStatus.General(file, fileExists)) return(false);   // account and instrument infos

   // [Inputs]
   section = "Inputs";
   WriteIniString(file, section, "Instance.ID",                /*string  */ Instance.ID);
   WriteIniString(file, section, "TradingMode",                /*string  */ TradingMode);
   WriteIniString(file, section, "StartConditions",            /*string  */ StartConditions);
   WriteIniString(file, section, "StopConditions",             /*string  */ StopConditions);
   WriteIniString(file, section, "TakeProfit",                 /*double  */ NumberToStr(TakeProfit, ".+"));
   WriteIniString(file, section, "TakeProfit.Type",            /*string  */ TakeProfit.Type);
   WriteIniString(file, section, "ZigZag.Periods",             /*int     */ ZigZag.Periods);
   WriteIniString(file, section, "Lots",                       /*double  */ NumberToStr(Lots, ".+"));
   if (!SaveStatus.Targets(file, true)) return(false);         // StopLoss and TakeProfit targets
   WriteIniString(file, section, "ShowProfitInPercent",        /*bool    */ ShowProfitInPercent);
   WriteIniString(file, section, "EA.Recorder",                /*string  */ EA.Recorder + separator);

   // [Runtime status]
   section = "Runtime status";
   WriteIniString(file, section, "instance.id",                /*int     */ instance.id);
   WriteIniString(file, section, "instance.name",              /*string  */ instance.name);
   WriteIniString(file, section, "instance.created",           /*datetime*/ instance.created + GmtTimeFormat(instance.created, " (%a, %Y.%m.%d %H:%M:%S)"));
   WriteIniString(file, section, "instance.isTest",            /*bool    */ instance.isTest);
   WriteIniString(file, section, "instance.status",            /*int     */ instance.status +" ("+ StatusDescription(instance.status) +")");
   WriteIniString(file, section, "instance.startEquity",       /*double  */ DoubleToStr(instance.startEquity, 2) + separator);

   WriteIniString(file, section, "tradingMode",                /*int     */ tradingMode);
   WriteIniString(file, section, "recorder.stdEquitySymbol",   /*string  */ recorder.stdEquitySymbol + separator);

   WriteIniString(file, section, "start.time.condition",       /*bool    */ start.time.condition);
   WriteIniString(file, section, "start.time.value",           /*datetime*/ start.time.value);
   WriteIniString(file, section, "start.time.isDaily",         /*bool    */ start.time.isDaily);
   WriteIniString(file, section, "start.time.description",     /*string  */ start.time.description + separator);

   WriteIniString(file, section, "stop.time.condition",        /*bool    */ stop.time.condition);
   WriteIniString(file, section, "stop.time.value",            /*datetime*/ stop.time.value);
   WriteIniString(file, section, "stop.time.isDaily",          /*bool    */ stop.time.isDaily);
   WriteIniString(file, section, "stop.time.description",      /*string  */ stop.time.description + separator);

   WriteIniString(file, section, "stop.profitPct.condition",   /*bool    */ stop.profitPct.condition);
   WriteIniString(file, section, "stop.profitPct.value",       /*double  */ NumberToStr(stop.profitPct.value, ".1+"));
   WriteIniString(file, section, "stop.profitPct.absValue",    /*double  */ ifString(stop.profitPct.absValue==INT_MAX, INT_MAX, DoubleToStr(stop.profitPct.absValue, 2)));
   WriteIniString(file, section, "stop.profitPct.description", /*string  */ stop.profitPct.description);
   WriteIniString(file, section, "stop.profitPun.condition",   /*bool    */ stop.profitPun.condition);
   WriteIniString(file, section, "stop.profitPun.type",        /*int     */ stop.profitPun.type);
   WriteIniString(file, section, "stop.profitPun.value",       /*double  */ NumberToStr(stop.profitPun.value, ".1+"));
   WriteIniString(file, section, "stop.profitPun.description", /*string  */ stop.profitPun.description + separator);

   // open/closed trades and stats
   if (!SaveStatus.TradeStats  (file, fileExists)) return(false);
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

   string section="", file=FindStatusFile(instance.id, instance.isTest);
   if (file == "")                 return(!catch("ReadStatus(2)  "+ instance.name +" status file not found", ERR_RUNTIME_ERROR));
   if (!IsFile(file, MODE_SYSTEM)) return(!catch("ReadStatus(3)  "+ instance.name +" file "+ DoubleQuoteStr(file) +" not found", ERR_FILE_NOT_FOUND));

   // [General]
   if (!ReadStatus.General(file)) return(false);

   // [Inputs]
   section = "Inputs";
   Instance.ID                = GetIniStringA(file, section, "Instance.ID",     "");               // string   Instance.ID                = T123
   TradingMode                = GetIniStringA(file, section, "TradingMode",     "");               // string   TradingMode                = regular
   StartConditions            = GetIniStringA(file, section, "StartConditions", "");               // string   StartConditions            = @time(datetime|time)
   StopConditions             = GetIniStringA(file, section, "StopConditions",  "");               // string   StopConditions             = @time(datetime|time)
   TakeProfit                 = GetIniDouble (file, section, "TakeProfit"         );               // double   TakeProfit                 = 3.0
   TakeProfit.Type            = GetIniStringA(file, section, "TakeProfit.Type", "");               // string   TakeProfit.Type            = off* | money | percent | pip
   ZigZag.Periods             = GetIniInt    (file, section, "ZigZag.Periods"     );               // int      ZigZag.Periods             = 40
   Lots                       = GetIniDouble (file, section, "Lots"               );               // double   Lots                       = 0.1
   if (!ReadStatus.Targets(file)) return(false);
   ShowProfitInPercent        = GetIniBool   (file, section, "ShowProfitInPercent");               // bool     ShowProfitInPercent        = 1
   EA.Recorder                = GetIniStringA(file, section, "EA.Recorder",     "");               // string   EA.Recorder                = 1,2,4

   // [Runtime status]
   section = "Runtime status";
   instance.id                = GetIniInt    (file, section, "instance.id"         );              // int      instance.id                = 123
   instance.name              = GetIniStringA(file, section, "instance.name",    "");              // string   instance.name              = Z.123
   instance.created           = GetIniInt    (file, section, "instance.created"    );              // datetime instance.created           = 1624924800 (Mon, 2021.05.12 13:22:34)
   instance.isTest            = GetIniBool   (file, section, "instance.isTest"     );              // bool     instance.isTest            = 1
   instance.status            = GetIniInt    (file, section, "instance.status"     );              // int      instance.status            = 1 (waiting)
   instance.startEquity       = GetIniDouble (file, section, "instance.startEquity");              // double   instance.startEquity       = 1000.00
   SS.InstanceName();

   tradingMode                = GetIniInt    (file, section, "tradingMode");                       // int      tradingMode                = 1
   recorder.stdEquitySymbol   = GetIniStringA(file, section, "recorder.stdEquitySymbol", "");      // string   recorder.stdEquitySymbol   = GBPJPY.001

   start.time.condition       = GetIniBool   (file, section, "start.time.condition"      );        // bool     start.time.condition       = 1
   start.time.value           = GetIniInt    (file, section, "start.time.value"          );        // datetime start.time.value           = 1624924800
   start.time.isDaily         = GetIniBool   (file, section, "start.time.isDaily"        );        // bool     start.time.isDaily         = 0
   start.time.description     = GetIniStringA(file, section, "start.time.description", "");        // string   start.time.description     = text

   stop.time.condition        = GetIniBool   (file, section, "stop.time.condition"      );         // bool     stop.time.condition        = 1
   stop.time.value            = GetIniInt    (file, section, "stop.time.value"          );         // datetime stop.time.value            = 1624924800
   stop.time.isDaily          = GetIniBool   (file, section, "stop.time.isDaily"        );         // bool     stop.time.isDaily          = 0
   stop.time.description      = GetIniStringA(file, section, "stop.time.description", "");         // string   stop.time.description      = text

   stop.profitPct.condition   = GetIniBool   (file, section, "stop.profitPct.condition"        );  // bool     stop.profitPct.condition   = 0
   stop.profitPct.value       = GetIniDouble (file, section, "stop.profitPct.value"            );  // double   stop.profitPct.value       = 0
   stop.profitPct.absValue    = GetIniDouble (file, section, "stop.profitPct.absValue", INT_MAX);  // double   stop.profitPct.absValue    = 0.00
   stop.profitPct.description = GetIniStringA(file, section, "stop.profitPct.description",   "");  // string   stop.profitPct.description = text

   stop.profitPun.condition   = GetIniBool   (file, section, "stop.profitPun.condition"      );    // bool     stop.profitPun.condition   = 1
   stop.profitPun.type        = GetIniInt    (file, section, "stop.profitPun.type"           );    // int      stop.profitPun.type        = 4
   stop.profitPun.value       = GetIniDouble (file, section, "stop.profitPun.value"          );    // double   stop.profitPun.value       = 1.23456
   stop.profitPun.description = GetIniStringA(file, section, "stop.profitPun.description", "");    // string   stop.profitPun.description = text

   // open/closed trades and stats
   if (!ReadStatus.TradeStats(file))   return(false);
   if (!ReadStatus.OpenPosition(file)) return(false);
   if (!ReadStatus.TradeHistory(file)) return(false);

   return(!catch("ReadStatus(4)"));
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
      if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;      // FALSE: an open order was closed/deleted in another thread
      if (IsMyOrder(instance.id)) {
         if (IsPendingOrderType(OrderType())) {
            logWarn("SynchronizeStatus(1)  "+ instance.name +" unsupported pending order found: #"+ OrderTicket() +", ignoring it...");
            continue;
         }
         if (!open.ticket) {
            logWarn("SynchronizeStatus(2)  "+ instance.name +" dangling open position found: #"+ OrderTicket() +", adding to instance...");
            open.ticket   = OrderTicket();
            open.type     = OrderType();
            open.time     = OrderOpenTime();
            open.price    = OrderOpenPrice();
            open.priceSig = open.price;
            open.slippage = NULL;                                     // open PnL numbers will auto-update in the following UpdateStatus() call
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
            if (IsEmpty(AddHistoryRecord(ticket, lots, openType, openTime, openPrice, openPrice, closeTime, closePrice, closePrice, slippage, swap, commission, grossProfit, netProfit, netProfitP, grossProfitP, grossProfitP, grossProfitP, grossProfitP, grossProfitP))) return(false);

            // update closed PL numbers
            instance.closedNetProfit  += netProfit;
            instance.closedNetProfitP += netProfitP;
            instance.closedSigProfitP += grossProfitP;               // for orphaned positions same as grossProfitP
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

   instance.totalSigProfitP = instance.openSigProfitP + instance.closedSigProfitP;
   instance.maxSigProfitP   = MathMax(instance.maxSigProfitP,   instance.totalSigProfitP);
   instance.maxSigDrawdownP = MathMin(instance.maxSigDrawdownP, instance.totalSigProfitP);
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


// backed-up input parameters
string   prev.Instance.ID = "";
string   prev.TradingMode = "";
string   prev.StartConditions = "";
string   prev.StopConditions = "";
double   prev.TakeProfit;
string   prev.TakeProfit.Type = "";
int      prev.ZigZag.Periods;
double   prev.Lots;
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
bool     prev.stop.profitPct.condition;
double   prev.stop.profitPct.value;
double   prev.stop.profitPct.absValue;
string   prev.stop.profitPct.description = "";
bool     prev.stop.profitPun.condition;
int      prev.stop.profitPun.type;
double   prev.stop.profitPun.value;
string   prev.stop.profitPun.description = "";


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
   prev.TradingMode         = StringConcatenate(TradingMode, "");       // and must be copied to break the reference
   prev.StartConditions     = StringConcatenate(StartConditions, "");
   prev.StopConditions      = StringConcatenate(StopConditions, "");
   prev.TakeProfit          = TakeProfit;
   prev.TakeProfit.Type     = StringConcatenate(TakeProfit.Type, "");
   prev.ZigZag.Periods      = ZigZag.Periods;
   prev.Lots                = Lots;
   prev.ShowProfitInPercent = ShowProfitInPercent;

   // affected runtime variables
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
   prev.stop.profitPct.condition   = stop.profitPct.condition;
   prev.stop.profitPct.value       = stop.profitPct.value;
   prev.stop.profitPct.absValue    = stop.profitPct.absValue;
   prev.stop.profitPct.description = stop.profitPct.description;
   prev.stop.profitPun.condition   = stop.profitPun.condition;
   prev.stop.profitPun.type        = stop.profitPun.type;
   prev.stop.profitPun.value       = stop.profitPun.value;
   prev.stop.profitPun.description = stop.profitPun.description;

   BackupInputs.Targets();
   BackupInputs.Recorder();
}


/**
 * Restore backed-up input parameters and runtime variables. Called from onInitParameters() and onInitTimeframeChange().
 */
void RestoreInputs() {
   // input parameters
   Instance.ID         = prev.Instance.ID;
   TradingMode         = prev.TradingMode;
   StartConditions     = prev.StartConditions;
   StopConditions      = prev.StopConditions;
   TakeProfit          = prev.TakeProfit;
   TakeProfit.Type     = prev.TakeProfit.Type;
   ZigZag.Periods      = prev.ZigZag.Periods;
   Lots                = prev.Lots;
   ShowProfitInPercent = prev.ShowProfitInPercent;

   // affected runtime variables
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
   stop.profitPct.condition   = prev.stop.profitPct.condition;
   stop.profitPct.value       = prev.stop.profitPct.value;
   stop.profitPct.absValue    = prev.stop.profitPct.absValue;
   stop.profitPct.description = prev.stop.profitPct.description;
   stop.profitPun.condition   = prev.stop.profitPun.condition;
   stop.profitPun.type        = prev.stop.profitPun.type;
   stop.profitPun.value       = prev.stop.profitPun.value;
   stop.profitPun.description = prev.stop.profitPun.description;

   RestoreInputs.Targets();
   RestoreInputs.Recorder();
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
   if (isInitParameters) {                              // otherwise the id was validated in ValidateInputs.ID()
      if (StrTrim(Instance.ID) == "") {                 // the id was deleted or not yet set, re-apply the internal id
         Instance.ID = prev.Instance.ID;
      }
      else if (Instance.ID != prev.Instance.ID)         return(!onInputError("ValidateInputs(1)  "+ instance.name +" switching to another instance is not supported (unload the EA first)"));
   }

   // TradingMode: "regular* | virtual"
   string sValues[], sValue=TradingMode;
   if (Explode(sValue, "*", sValues, 2) > 1) {
      int size = Explode(sValues[0], "|", sValues, NULL);
      sValue = sValues[size-1];
   }
   sValue = StrToLower(StrTrim(sValue));
   if      (StrStartsWith("regular", sValue)) tradingMode = TRADINGMODE_REGULAR;
   else if (StrStartsWith("virtual", sValue)) tradingMode = TRADINGMODE_VIRTUAL;
   else                                                 return(!onInputError("ValidateInputs(2)  "+ instance.name +" invalid input parameter TradingMode: "+ DoubleQuoteStr(TradingMode)));
   if (isInitParameters && tradingMode!=prev.tradingMode) {
      if (instanceWasStarted)                           return(!onInputError("ValidateInputs(3)  "+ instance.name +" cannot change input parameter TradingMode of "+ StatusDescription(instance.status) +" instance"));
   }
   TradingMode = tradingModeDescriptions[tradingMode];

   // StartConditions: @time(datetime|time)
   if (!isInitParameters || StartConditions!=prev.StartConditions) {
      string exprs[], expr="", key="", descr="";        // split conditions
      int sizeOfExprs = Explode(StartConditions, "|", exprs, NULL), iValue, time, pt[];
      datetime dtValue;
      bool isDaily, containsTimeCondition = false;

      for (int i=0; i < sizeOfExprs; i++) {             // validate each expression
         expr = StrTrim(exprs[i]);
         if (!StringLen(expr)) continue;
         if (StringGetChar(expr, 0) != '@')             return(!onInputError("ValidateInputs(4)  "+ instance.name +" invalid input parameter StartConditions: "+ DoubleQuoteStr(StartConditions)));
         if (Explode(expr, "(", sValues, NULL) != 2)    return(!onInputError("ValidateInputs(5)  "+ instance.name +" invalid input parameter StartConditions: "+ DoubleQuoteStr(StartConditions)));
         if (!StrEndsWith(sValues[1], ")"))             return(!onInputError("ValidateInputs(6)  "+ instance.name +" invalid input parameter StartConditions: "+ DoubleQuoteStr(StartConditions)));
         key = StrTrim(sValues[0]);
         sValue = StrTrim(StrLeft(sValues[1], -1));
         if (!StringLen(sValue))                        return(!onInputError("ValidateInputs(7)  "+ instance.name +" invalid input parameter StartConditions: "+ DoubleQuoteStr(StartConditions)));

         if (key == "@time") {
            if (containsTimeCondition)                  return(!onInputError("ValidateInputs(8)  "+ instance.name +" invalid input parameter StartConditions: "+ DoubleQuoteStr(StartConditions) +" (multiple time conditions)"));
            containsTimeCondition = true;

            if (!ParseDateTime(sValue, NULL, pt))       return(!onInputError("ValidateInputs(9)  "+ instance.name +" invalid input parameter StartConditions: "+ DoubleQuoteStr(StartConditions)));
            dtValue = DateTime2(pt, DATE_OF_ERA);
            isDaily = !pt[PT_HAS_DATE];
            descr   = "time("+ TimeToStr(dtValue, ifInt(isDaily, TIME_MINUTES, TIME_DATE|TIME_MINUTES)) +")";

            if (descr != start.time.description) {      // enable condition only if changed
               start.time.condition   = true;
               start.time.value       = dtValue;
               start.time.isDaily     = isDaily;
               start.time.description = descr;
            }
         }
         else                                           return(!onInputError("ValidateInputs(10)  "+ instance.name +" invalid input parameter StartConditions: "+ DoubleQuoteStr(StartConditions)));
      }
      if (!containsTimeCondition && start.time.condition) {
         start.time.condition = false;
      }
   }

   // StopConditions: @time(datetime|time)
   if (!isInitParameters || StopConditions!=prev.StopConditions) {
      sizeOfExprs = Explode(StopConditions, "|", exprs, NULL);
      containsTimeCondition = false;

      for (i=0; i < sizeOfExprs; i++) {                 // validate each expression
         expr = StrTrim(exprs[i]);
         if (!StringLen(expr)) continue;
         if (StringGetChar(expr, 0) != '@')             return(!onInputError("ValidateInputs(11)  "+ instance.name +" invalid input parameter StopConditions: "+ DoubleQuoteStr(StopConditions)));
         if (Explode(expr, "(", sValues, NULL) != 2)    return(!onInputError("ValidateInputs(12)  "+ instance.name +" invalid input parameter StopConditions: "+ DoubleQuoteStr(StopConditions)));
         if (!StrEndsWith(sValues[1], ")"))             return(!onInputError("ValidateInputs(13)  "+ instance.name +" invalid input parameter StopConditions: "+ DoubleQuoteStr(StopConditions)));
         key = StrTrim(sValues[0]);
         sValue = StrTrim(StrLeft(sValues[1], -1));
         if (!StringLen(sValue))                        return(!onInputError("ValidateInputs(14)  "+ instance.name +" invalid input parameter StopConditions: "+ DoubleQuoteStr(StopConditions)));

         if (key == "@time") {
            if (containsTimeCondition)                  return(!onInputError("ValidateInputs(15)  "+ instance.name +" invalid input parameter StopConditions: "+ DoubleQuoteStr(StopConditions) +" (multiple time conditions)"));
            containsTimeCondition = true;

            if (!ParseDateTime(sValue, NULL, pt))       return(!onInputError("ValidateInputs(16)  "+ instance.name +" invalid input parameter StopConditions: "+ DoubleQuoteStr(StopConditions)));
            dtValue = DateTime2(pt, DATE_OF_ERA);
            isDaily = !pt[PT_HAS_DATE];
            descr   = "time("+ TimeToStr(dtValue, ifInt(isDaily, TIME_MINUTES, TIME_DATE|TIME_MINUTES)) +")";

            if (descr != stop.time.description) {       // enable condition only if changed
               stop.time.condition   = true;
               stop.time.value       = dtValue;
               stop.time.isDaily     = isDaily;
               stop.time.description = descr;
            }
            if (start.time.condition && !start.time.isDaily && !stop.time.isDaily) {
               if (start.time.value >= stop.time.value) return(!onInputError("ValidateInputs(17)  "+ instance.name +" invalid times in Start/StopConditions: "+ start.time.description +" / "+ stop.time.description +" (start time must preceed stop time)"));
            }
         }
         else                                           return(!onInputError("ValidateInputs(18)  "+ instance.name +" invalid input parameter StopConditions: "+ DoubleQuoteStr(StopConditions)));
      }
      if (!containsTimeCondition && stop.time.condition) {
         stop.time.condition = false;
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
   else if (StrStartsWith("quote-unit", sValue)) stop.profitPun.type = TP_TYPE_PRICEUNIT;
   else if (StringLen(sValue) < 2)                      return(!onInputError("ValidateInputs(19)  "+ instance.name +" invalid parameter TakeProfit.Type: "+ DoubleQuoteStr(TakeProfit.Type)));
   else if (StrStartsWith("percent", sValue))    stop.profitPun.type = TP_TYPE_PERCENT;
   else if (StrStartsWith("pip",     sValue))    stop.profitPun.type = TP_TYPE_PIP;
   else                                                 return(!onInputError("ValidateInputs(20)  "+ instance.name +" invalid parameter TakeProfit.Type: "+ DoubleQuoteStr(TakeProfit.Type)));
   stop.profitPct.condition   = false;
   stop.profitPct.description = "";
   stop.profitPun.condition   = false;
   stop.profitPun.description = "";

   switch (stop.profitPun.type) {
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

   // ZigZag.Periods
   if (isInitParameters && ZigZag.Periods!=prev.ZigZag.Periods) {
      if (instanceWasStarted)                           return(!onInputError("ValidateInputs(21)  "+ instance.name +" cannot change input parameter ZigZag.Periods of "+ StatusDescription(instance.status) +" instance"));
   }
   if (ZigZag.Periods < 2)                              return(!onInputError("ValidateInputs(22)  "+ instance.name +" invalid input parameter ZigZag.Periods: "+ ZigZag.Periods));

   // Lots
   if (isInitParameters && NE(Lots, prev.Lots)) {
      if (instanceWasStarted)                           return(!onInputError("ValidateInputs(23)  "+ instance.name +" cannot change input parameter Lots of "+ StatusDescription(instance.status) +" instance"));
   }
   if (LT(Lots, 0))                                     return(!onInputError("ValidateInputs(24)  "+ instance.name +" invalid input parameter Lots: "+ NumberToStr(Lots, ".1+") +" (too small)"));
   if (NE(Lots, NormalizeLots(Lots)))                   return(!onInputError("ValidateInputs(25)  "+ instance.name +" invalid input parameter Lots: "+ NumberToStr(Lots, ".1+") +" (not a multiple of MODE_LOTSTEP="+ NumberToStr(MarketInfo(Symbol(), MODE_LOTSTEP), ".+") +")"));

   // Targets
   if (!ValidateInputs.Targets()) return(false);

   // EA.Recorder: on | off* | 1,2,3=1000,...
   if (!Recorder.ValidateInputs(IsTestInstance())) return(false);

   SS.All();
   return(!catch("ValidateInputs(26)"));
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

   if (type!=OP_BUY && type!=OP_SELL) return(!catch("VirtualOrderSend(1)  "+ instance.name +" invalid parameter type: "+ type, oe.setError(oe, ERR_INVALID_PARAMETER)));
   double openPrice = ifDouble(type, Bid, Ask);
   string comment = "ZigZag."+ StrPadLeft(instance.id, 3, "0");

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
   double closePrice = ifDouble(open.type==OP_BUY, Bid, Ask);
   double profit = NormalizeDouble(ifDouble(open.type==OP_BUY, closePrice-open.price, open.price-closePrice) * PointValue(lots), 2);

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
      logDebug("VirtualOrderClose(2)  "+ instance.name +" closed virtual #"+ ticket +" "+ sType +" "+ sLots +" "+ Symbol() +" \"ZigZag."+ StrPadLeft(instance.id, 3, "0") +"\" from "+ sOpenPrice +" at "+ sClosePrice +" (market: "+ sBid +"/"+ sAsk +")");
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
   SS.StartStopConditions();
   SS.MetricDescription();
   SS.OpenLots();
   SS.ClosedTrades();
   SS.TotalProfit(ShowProfitInPercent);
   SS.ProfitStats(ShowProfitInPercent);
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
                                                                                                            NL,
                                   sMetricDescription,                                                      NL,
                                  "Open:    ",   sOpenLots,                                                 NL,
                                  "Closed:  ",   sClosedTrades,                                             NL,
                                  "Profit:    ", sTotalProfit, "  ", sProfitStats,                          NL
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
   return(StringConcatenate("Instance.ID=",          DoubleQuoteStr(Instance.ID),     ";"+ NL +
                            "TradingMode=",          DoubleQuoteStr(TradingMode),     ";"+ NL +
                            "ZigZag.Periods=",       ZigZag.Periods,                  ";"+ NL +
                            "Lots=",                 NumberToStr(Lots, ".1+"),        ";"+ NL +
                            "StartConditions=",      DoubleQuoteStr(StartConditions), ";"+ NL +
                            "StopConditions=",       DoubleQuoteStr(StopConditions),  ";"+ NL +
                            "TakeProfit=",           NumberToStr(TakeProfit, ".1+"),  ";"+ NL +
                            "TakeProfit.Type=",      DoubleQuoteStr(TakeProfit.Type), ";"+ NL +

                            "Initial.TakeProfit=",   Initial.TakeProfit,              ";"+ NL +
                            "Initial.StopLoss=",     Initial.StopLoss,                ";"+ NL +
                            "Target1=",              Target1,                         ";"+ NL +
                            "Target1.ClosePercent=", Target1.ClosePercent,            ";"+ NL +
                            "Target1.MoveStopTo=",   Target1.MoveStopTo,              ";"+ NL +
                            "Target2=",              Target2,                         ";"+ NL +
                            "Target2.ClosePercent=", Target2.ClosePercent,            ";"+ NL +
                            "Target2.MoveStopTo=",   Target2.MoveStopTo,              ";"+ NL +
                            "Target3=",              Target3,                         ";"+ NL +
                            "Target3.ClosePercent=", Target3.ClosePercent,            ";"+ NL +
                            "Target3.MoveStopTo=",   Target3.MoveStopTo,              ";"+ NL +
                            "Target4=",              Target4,                         ";"+ NL +
                            "Target4.ClosePercent=", Target4.ClosePercent,            ";"+ NL +
                            "Target4.MoveStopTo=",   Target4.MoveStopTo,              ";"+ NL +

                            "ShowProfitInPercent=",  BoolToStr(ShowProfitInPercent),  ";")
   );
}
