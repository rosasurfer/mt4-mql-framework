/**
 * A strategy trading Donchian channel breakouts.
 *
 *
 * Requirements
 * ------------
 *  • ZigZag indicator: @see https://github.com/rosasurfer/mt4-mql/blob/master/mql4/indicators/ZigZag.mq4
 *
 *
 * External control
 * ----------------
 *  • EA.Start: When a "start" command is received the EA opens a position in direction of the current ZigZag leg. There are
 *              two sub-commands "start:long" and "start:short" to start the EA in a predefined direction. The command has no
 *              effect if the EA already manages an open position.
 *  • EA.Stop:  When a "stop" command is received the EA closes all open positions and stops waiting for trade signals. The
 *              command has no effect if the EA is already in status "stopped".
 *  • EA.Wait:  When a "wait" command is received a stopped EA will wait for new trade signals and start trading. The command
 *              has no effect if the EA is already in status "waiting".
 *  • EA.ToggleMetrics
 *  • Chart.ToggleOpenOrders
 *  • Chart.ToggleTradeHistory
 *
 *
 *
 * TODO:  *** Main objective is faster implementation and testing of new EAs. ***
 *
 *
 *  - entry management
 *
 *  - exit management
 *     dynamic SL/TP distances (multiples of ranges)
 *     trailing stop
 *
 *  - more statistics: consecutive winners/profit/losers/loss, sharp ratio, sortino ratio, calmar ratio, z-score, recovery time
 *
 *  - optimization
 *     update status file content
 *     update status filename
 *     storage in separate directory
 *     generate consecutive instance ids
 *     optimization report
 *
 *     performance:
 *      empty tester template, 100 permutations:
 *       build 500:   4.8 sec
 *       build 1408:  4.3 sec (1.1 times faster than build 500)
 *      tester template with custom indicator and lib-calls, 100 permutations:
 *       build 500:   7.2 sec
 *       build 1408: 23.4 sec (3.2 times slower than build 500)
 *
 *  - partial close
 *     online: fix closedProfit after 1 partial-close (error loading status file)
 *     implement open.nextTarget
 *
 *  - money management
 *
 *  - tests
 *     storage in folder per strategy
 *     read enabled trade directions at test start
 *     on no connection/old terminal: indicator of the same name to load test into chart
 *
 *  - optimization/self-optimization
 *     04.10.2007 Automated re-optimization in MT4       https://www.mql5.com/en/articles/1467
 *     05.10.2018 Automated re-optimization in MT5       https://www.mql5.com/en/articles/4917
 *
 *     13.07.2008: @tdion, inspiration for @rraygun      https://www.forexfactory.com/thread/95892-ma-cross-optimization-ea-very-cool#    statt MACD(16,18) MACD(ALMA(38,46))
 *     16.12.2009: @rraygun                              https://www.forexfactory.com/thread/211657-old-dog-with-new-tricks#
 *
 *     01.08.2018 MACD Twister                           https://www.mql5.com/en/market/product/23557
 *
 *     heat maps: https://www.forexfactory.com/thread/post/13834307#post13834307
 *     ML:        https://www.forexfactory.com/thread/516785-machine-learning-with-algotraderjo
 *
 *     separate optimization of long|short trades
 *     consider max holding period
 *
 *
 *  -------------------------------------------------------------------------------------------------------------------------
 *  - ObjectCreateRegister()
 *     on terminal start with 7 charts 106.000 initial calls
 *     SuperBars in regular charts: permant non-stopping calls (after a few minutes more than 1.000.000)
 *     SuperBars in offline charts: 271 calls on every tick
 *
 *  - reproduce/validate tests with original EAs
 *     terminal with Dukascopy data
 *     fast generation of old test data (e.g. from 2007)
 *
 *  -------------------------------------------------------------------------------------------------------------------------
 *  - ZigZag Twister
 *  - add ZigZag projections
 *  - input TradingTimeframe
 *  - on recorder restart the first recorded bar opens at instance.startEquity
 *  - document control scripts
 *  - block tests with bar model MODE_BAROPEN
 *  - fatal error if a test starts with Instance.ID="T001" and EA.Recorder="off"
 *  - rewrite loglevels to global vars
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
 *  - sound.cpp::PlaySoundW(171)  ERROR: mciSendString(play "E:\Trading\MetaTrader\S5\sounds\MarginLow.wav" from 0) => MCIERR_WAVE_OUTPUTSINUSE  [ERR_RUNTIME_ERROR]
 *                                FATAL  US30,M5  ChartInfos::start(8)  DLL error  [ERR_RUNTIME_ERROR]
 *
 *  - stop on reverse signal
 *  - signals MANUAL_LONG|MANUAL_SHORT
 *  - track and display total slippage
 *  - reduce slippage on reversal: Close+Open => Hedge+CloseBy
 *  - reduce slippage on short reversal: enter market via StopSell
 *
 *  - trading functionality
 *     support command "wait" in status "progressing"
 *     reverse trading and command EA.Reverse
 *
 *  - ChartInfos
 *     CustomPosition() weekend configuration/timespans don't work
 *     CustomPosition() including/excluding a specific strategy is not supported
 *     don't recalculate unitsize on every tick (every few seconds is sufficient)
 *
 *  - performance tracking
 *     notifications for price feed outages
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
 *  - rewrite range bar generator
 *  - VPS: monitor and notify of incoming emails
 *  - CLI tools to rename/update/delete symbols
 */
#define STRATEGY_ID  107                     // unique strategy id (used for generation of magic order numbers)

#include <stddefines.mqh>
int   __InitFlags[] = {INIT_PIPVALUE, INIT_BUFFERED_LOG};
int __DeinitFlags[];
int __virtualTicks = 10000;                  // every 10 seconds to continue operation on a stalled data feed

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern string Instance.ID                    = "";                   // instance to load from a status file, format "[T]123"
extern string Instance.StartAt               = "";                   // @time(datetime|time)
extern string Instance.StopAt                = "";                   // @time(datetime|time) | @profit(numeric[%])

extern string ___a__________________________ = "=== Signal settings ===";
extern int    ZigZag.Periods                 = 30;

extern string ___b__________________________ = "=== Trade settings ===";
extern int    EntryOrder.Distance            = 0;                    // in punits: entry order distance from the signal level
extern double Lots                           = 0.1;

extern string ___c__________________________ = "=== Other ===";
extern bool   ShowProfitInPercent            = false;                // whether PnL is displayed in money amounts or percent

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


// instance start conditions
bool     start.time.condition;               // whether a time condition is active
datetime start.time.value;
bool     start.time.isDaily;
string   start.time.descr = "";

// instance stop conditions ("OR" combined)
bool     stop.time.condition;                // whether a time condition is active
datetime stop.time.value;
bool     stop.time.isDaily;
string   stop.time.descr = "";

bool     stop.profitPct.condition;           // whether a takeprofit condition in percent is active
double   stop.profitPct.value;
double   stop.profitPct.absValue = INT_MAX;
string   stop.profitPct.descr = "";

bool     stop.profitPunit.condition;         // whether a takeprofit condition in price units is active (pip or full point)
double   stop.profitPunit.value;
string   stop.profitPunit.descr = "";

// cache vars to speed-up ShowStatus()
string   status.startConditions = "";
string   status.stopConditions  = "";


// framework
#include <core/expert.mqh>
#include <core/expert.recorder.mqh>
#include <stdfunctions.mqh>
#include <rsfLib.mqh>
#include <functions/HandleCommands.mqh>
#include <functions/InitializeByteBuffer.mqh>
#include <functions/ObjectCreateRegister.mqh>
#include <functions/ParseDateTime.mqh>
#include <functions/iCustom/ZigZag.mqh>
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

#include <ea/functions/status/ShowOpenOrders.mqh>
#include <ea/functions/status/ShowTradeHistory.mqh>
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
#include <ea/functions/status/file/ReadStatus.HistoryRecord.mqh>
#include <ea/functions/status/file/ReadStatus.OpenPosition.mqh>
#include <ea/functions/status/file/ReadStatus.TradeHistory.mqh>
#include <ea/functions/status/file/ReadStatus.TradeStats.mqh>
#include <ea/functions/status/file/SaveStatus.General.mqh>
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

#include <ea/functions/trade/signal/SignalOperationToStr.mqh>
#include <ea/functions/trade/signal/SignalTypeToStr.mqh>

#include <ea/functions/trade/stats/CalculateStats.mqh>

#include <ea/functions/validation/ValidateInputs.ID.mqh>
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
      if (!HandleCommands()) return(last_error);         // process incoming commands, may switch on/off the instance
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
         else if (IsZigZagSignal(signal)) {
            ReversePosition(signal);
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

            double signal[3];
            signal[SIG_TYPE ] = 0;
            signal[SIG_PRICE] = 0;
            if      (params == "long")  signal[SIG_OP] = SIG_OP_LONG;
            else if (params == "short") signal[SIG_OP] = SIG_OP_SHORT;
            else {
               signal[SIG_OP] = ifInt(GetZigZagTrend(0) > 0, SIG_OP_LONG, SIG_OP_SHORT);
               if (params != "") {
                  sDetail  = " skipping unsupported parameter in command ";
                  logLevel = LOG_NOTICE;
               }
            }
            log("onCommand(1)  "+ instance.name + sDetail + DoubleQuoteStr(fullCmd), NO_ERROR, logLevel);
            return(StartTrading(signal));
      }
   }
   else if (cmd == "stop") {
      switch (instance.status) {
         case STATUS_WAITING:
         case STATUS_TRADING:
            logInfo("onCommand(2)  "+ instance.name +" "+ DoubleQuoteStr(fullCmd));
            double dNull[] = {0,0,0};
            return(StopTrading(dNull));
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

   static int lastTick, lastSigType, lastSigOp, lastSigBar, lastSigBarOp;
   static double lastSigPrice, reversalPrice;
   int trend, reversalOffset;

   if (Ticks == lastTick) {
      signal[SIG_TYPE ] = lastSigType;
      signal[SIG_PRICE] = lastSigPrice;
      signal[SIG_OP   ] = lastSigOp;
   }
   else {
      signal[SIG_TYPE ] = 0;
      signal[SIG_PRICE] = 0;
      signal[SIG_OP   ] = 0;

      if (!GetZigZagData(0, trend, reversalOffset, reversalPrice)) return(!logError("IsZigZagSignal(1)  "+ instance.name +" GetZigZagData(0) => FALSE", ERR_RUNTIME_ERROR));
      int absTrend = MathAbs(trend);
      bool isReversal = false;
      if      (absTrend == reversalOffset)     isReversal = true;             // regular reversal
      else if (absTrend==1 && !reversalOffset) isReversal = true;             // reversal after double crossing

      if (isReversal) {
         if (trend > 0) int sigOp = SIG_OP_CLOSE_SHORT|SIG_OP_LONG;
         else               sigOp = SIG_OP_CLOSE_LONG|SIG_OP_SHORT;

         if (Time[0]!=lastSigBar || sigOp!=lastSigBarOp) {
            signal[SIG_TYPE ] = SIG_TYPE_ZIGZAG;
            signal[SIG_PRICE] = reversalPrice;
            signal[SIG_OP   ] = sigOp;

            if (IsLogNotice()) logNotice("IsZigZagSignal(2)  "+ instance.name +" "+ ifString(sigOp & SIG_OP_LONG, "long", "short") +" reversal at "+ NumberToStr(reversalPrice, PriceFormat) +" (market: "+ NumberToStr(_Bid, PriceFormat) +"/"+ NumberToStr(_Ask, PriceFormat) +")");
            lastSigBar   = Time[0];
            lastSigBarOp = sigOp;
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
 * @param  _Out_ double &signal[] - array receiving signal details
 *
 * @return bool
 */
bool IsStartSignal(double &signal[]) {
   if (last_error || instance.status!=STATUS_WAITING) return(false);
   signal[SIG_TYPE ] = 0;
   signal[SIG_PRICE] = 0;
   signal[SIG_OP   ] = 0;

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
 * @param  _Out_ double &signal[] - array receiving signal details
 *
 * @return bool
 */
bool IsStopSignal(double &signal[]) {
   if (last_error || (instance.status!=STATUS_WAITING && instance.status!=STATUS_TRADING)) return(false);
   signal[SIG_TYPE ] = 0;
   signal[SIG_PRICE] = 0;
   signal[SIG_OP   ] = 0;

   if (instance.status == STATUS_TRADING) {
      // stop.profitPct -----------------------------------------------------------------------------------------------------
      if (stop.profitPct.condition) {
         if (stop.profitPct.absValue == INT_MAX)
            stop.profitPct.absValue = stop.profitPct.AbsValue();

         if (instance.totalNetProfit >= stop.profitPct.absValue) {
            signal[SIG_TYPE] = SIG_TYPE_TAKEPROFIT;
            signal[SIG_OP  ] = SIG_OP_CLOSE_ALL;
            if (IsLogNotice()) logNotice("IsStopSignal(1)  "+ instance.name +" stop condition \"@"+ stop.profitPct.descr +"\" triggered (market: "+ NumberToStr(_Bid, PriceFormat) +"/"+ NumberToStr(_Ask, PriceFormat) +")");
            return(true);
         }
      }

      // stop.profitPunit ---------------------------------------------------------------------------------------------------
      if (stop.profitPunit.condition) {
         if (instance.totalNetProfitP >= stop.profitPunit.value) {
            signal[SIG_TYPE] = SIG_TYPE_TAKEPROFIT;
            signal[SIG_OP  ] = SIG_OP_CLOSE_ALL;
            if (IsLogNotice()) logNotice("IsStopSignal(2)  "+ instance.name +" stop condition \"@"+ stop.profitPunit.descr +"\" triggered (market: "+ NumberToStr(_Bid, PriceFormat) +"/"+ NumberToStr(_Ask, PriceFormat) +")");
            return(true);
         }
      }
   }

   // stop.time -------------------------------------------------------------------------------------------------------------
   if (stop.time.condition) {
      if (!IsTradingTime()) {
         signal[SIG_TYPE] = SIG_TYPE_TIME;
         signal[SIG_OP  ] = SIG_OP_CLOSE_ALL;
         if (IsLogNotice()) logNotice("IsStopSignal(3)  "+ instance.name +" stop condition \"@"+ stop.time.descr +"\" triggered (market: "+ NumberToStr(_Bid, PriceFormat) +"/"+ NumberToStr(_Ask, PriceFormat) +")");
         return(true);
      }
   }
   return(false);
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

   int    sigType  = signal[SIG_TYPE ];
   double sigPrice = signal[SIG_PRICE];
   int    sigOp    = signal[SIG_OP   ]; sigOp &= (SIG_OP_LONG|SIG_OP_SHORT);

   instance.status = STATUS_TRADING;
   if (!instance.startEquity) instance.startEquity = NormalizeDouble(AccountEquity() - AccountCredit() + GetExternalAssets(), 2);

   // open a new position
   int      type        = ifInt(sigOp==SIG_OP_LONG, OP_BUY, OP_SELL), oeFlags, oe[];
   double   price       = NULL;
   datetime expires     = NULL;
   string   comment     = instance.name;
   int      magicNumber = CalculateMagicNumber(instance.id);
   color    marker      = ifInt(type==OP_BUY, CLR_OPEN_LONG, CLR_OPEN_SHORT);

   int ticket = OrderSendEx(Symbol(), type, Lots, price, order.slippage, NULL, NULL, comment, magicNumber, expires, marker, oeFlags, oe);
   if (!ticket) return(!SetLastError(oe.Error(oe)));

   // store the position data
   open.ticket       = ticket;
   open.type         = type;
   open.lots         = oe.Lots(oe);
   open.time         = oe.OpenTime(oe);
   open.price        = oe.OpenPrice(oe);
   open.priceSig     = ifDouble(sigType==SIG_TYPE_ZIGZAG, sigPrice, _Bid);
   open.slippageP    = oe.Slippage(oe);
   open.swapM        = oe.Swap(oe);
   open.commissionM  = oe.Commission(oe);
   open.grossProfitM = oe.Profit(oe);
   open.netProfitM   = open.grossProfitM + open.swapM + open.commissionM;
   open.netProfitP   = ifDouble(type==OP_BUY, _Bid-open.price, open.price-_Ask) + (open.swapM + open.commissionM)/PointValue(open.lots);
   open.runupP       = ifDouble(type==OP_BUY, _Bid-open.price, open.price-_Ask);
   open.rundownP     = open.runupP;
   open.sigProfitP   = ifDouble(type==OP_BUY, _Bid-open.priceSig, open.priceSig-_Bid);
   open.sigRunupP    = open.sigProfitP;
   open.sigRundownP  = open.sigRunupP;

   // update PnL stats
   instance.openNetProfit  = open.netProfitM;
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
      SS.TotalProfit();
      SS.ProfitStats();
      SS.StartStopConditions();
   }
   if (IsLogInfo()) logInfo("StartTrading(3)  "+ instance.name +" started ("+ SignalOperationToStr(sigOp) +")");

   if (test.onPositionOpenPause) Tester.Pause("StartTrading(4)");
   return(SaveStatus());
}


/**
 * Reverse the current position of the instance.
 *
 * @param  double signal[] - signal infos causing the call
 *
 * @return bool - success status
 */
bool ReversePosition(double signal[]) {
   if (last_error != NULL)                return(false);
   if (instance.status != STATUS_TRADING) return(!catch("ReversePosition(1)  "+ instance.name +" cannot reverse "+ StatusDescription(instance.status) +" instance", ERR_ILLEGAL_STATE));
   int    sigType  = signal[SIG_TYPE ];
   double sigPrice = signal[SIG_PRICE];
   int    sigOp    = signal[SIG_OP   ]; sigOp &= (SIG_OP_LONG|SIG_OP_SHORT);
   if (!sigPrice) return(!catch("ReversePosition(2)  "+ instance.name +" invalid signal parameter SIG_PRICE: 0", ERR_INVALID_PARAMETER));
   if (!sigOp)    return(!catch("ReversePosition(3)  "+ instance.name +" invalid signal parameter SIG_OP: 0", ERR_INVALID_PARAMETER));

   int ticket, oeFlags, oe[];

   if (open.ticket != NULL) {
      // continue with an already reversed position
      if ((open.type==OP_BUY && sigOp==SIG_OP_LONG) || (open.type==OP_SELL && sigOp==SIG_OP_SHORT)) {
         return(_true(logWarn("ReversePosition(4)  "+ instance.name +" to "+ ifString(sigOp==SIG_OP_LONG, "long", "short") +": continuing with already open "+ ifString(sigOp==SIG_OP_LONG, "long", "short") +" position #"+ open.ticket)));
      }

      // close the existing position
      if (!OrderCloseEx(open.ticket, NULL, order.slippage, CLR_CLOSED, oeFlags, oe)) return(!SetLastError(oe.Error(oe)));

      double closePrice = oe.ClosePrice(oe);
      open.slippageP   += oe.Slippage(oe);
      open.swapM        = oe.Swap(oe);
      open.commissionM  = oe.Commission(oe);
      open.grossProfitM = oe.Profit(oe);
      open.netProfitM   = open.grossProfitM + open.swapM + open.commissionM;
      open.netProfitP   = ifDouble(open.type==OP_BUY, closePrice-open.price, open.price-closePrice);
      open.runupP       = MathMax(open.runupP, open.netProfitP);
      open.rundownP     = MathMin(open.rundownP, open.netProfitP); open.netProfitP += (open.swapM + open.commissionM)/PointValue(open.lots);
      open.sigProfitP   = ifDouble(open.type==OP_BUY, sigPrice-open.priceSig, open.priceSig-sigPrice);
      open.sigRunupP    = MathMax(open.sigRunupP, open.sigProfitP);
      open.sigRundownP  = MathMin(open.sigRundownP, open.sigProfitP);

      if (!MovePositionToHistory(oe.CloseTime(oe), closePrice, sigPrice)) return(false);
   }

   // open a new position
   int      type        = ifInt(sigOp==SIG_OP_LONG, OP_BUY, OP_SELL);
   double   price       = NULL;
   datetime expires     = NULL;
   string   comment     = "ZigZag."+ StrPadLeft(instance.id, 3, "0");
   int      magicNumber = CalculateMagicNumber(instance.id);
   color    marker      = ifInt(type==OP_BUY, CLR_OPEN_LONG, CLR_OPEN_SHORT);

   ticket = OrderSendEx(Symbol(), type, Lots, price, order.slippage, NULL, NULL, comment, magicNumber, expires, marker, oeFlags, oe);
   if (!ticket) return(!SetLastError(oe.Error(oe)));

   // store the new position data
   open.ticket       = ticket;
   open.type         = type;
   open.lots         = oe.Lots(oe);
   open.time         = oe.OpenTime(oe);
   open.price        = oe.OpenPrice(oe);
   open.priceSig     = sigPrice;
   open.slippageP    = oe.Slippage(oe);
   open.swapM        = oe.Swap(oe);
   open.commissionM  = oe.Commission(oe);
   open.grossProfitM = oe.Profit(oe);
   open.netProfitM   = open.grossProfitM + open.swapM + open.commissionM;
   open.netProfitP   = ifDouble(type==OP_BUY, _Bid-open.price, open.price-_Ask) + (open.swapM + open.commissionM)/PointValue(open.lots);
   open.runupP       = ifDouble(type==OP_BUY, _Bid-open.price, open.price-_Ask);
   open.rundownP     = open.runupP;
   open.sigProfitP   = ifDouble(type==OP_BUY, _Bid-open.priceSig, open.priceSig-_Bid);
   open.sigRunupP    = open.sigProfitP;
   open.sigRundownP  = open.sigProfitP;

   // update PL numbers
   instance.openNetProfit  = open.netProfitM;
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
      SS.TotalProfit();
      SS.ProfitStats();
   }
   if (IsLogInfo()) logInfo("ReversePosition(5)  "+ instance.name +" position reversed ("+ SignalOperationToStr(sigOp) +")");

   if (test.onPositionOpenPause) Tester.Pause("ReversePosition(6)");
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
         int oe[];
         if (!OrderCloseEx(open.ticket, NULL, order.slippage, CLR_CLOSED, NULL, oe)) return(!SetLastError(oe.Error(oe)));

         double closePrice = oe.ClosePrice(oe), closePriceSig = ifDouble(sigType==SIG_TYPE_ZIGZAG, sigPrice, _Bid);
         open.slippageP   += oe.Slippage(oe);
         open.swapM        = oe.Swap(oe);
         open.commissionM  = oe.Commission(oe);
         open.grossProfitM = oe.Profit(oe);
         open.netProfitM   = open.grossProfitM + open.swapM + open.commissionM;
         open.netProfitP   = ifDouble(open.type==OP_BUY, closePrice-open.price, open.price-closePrice);
         open.runupP       = MathMax(open.runupP, open.netProfitP);
         open.rundownP     = MathMin(open.rundownP, open.netProfitP); open.netProfitP += (open.swapM + open.commissionM)/PointValue(open.lots);
         open.sigProfitP   = ifDouble(open.type==OP_BUY, closePriceSig-open.priceSig, open.priceSig-closePriceSig);
         open.sigRunupP    = MathMax(open.sigRunupP, open.sigProfitP);
         open.sigRundownP  = MathMin(open.sigRundownP, open.sigProfitP);

         if (!MovePositionToHistory(oe.CloseTime(oe), closePrice, closePriceSig)) return(false);

         instance.openNetProfit  = open.netProfitM;
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
      case SIG_TYPE_TIME:
         if (!stop.time.isDaily) {
            stop.time.condition = false;                    // see start/stop time variants
         }
         instance.status = ifInt(start.time.condition && start.time.isDaily, STATUS_WAITING, STATUS_STOPPED);
         break;

      case SIG_TYPE_TAKEPROFIT:
         stop.profitPct.condition   = false;
         stop.profitPunit.condition = false;
         instance.status            = STATUS_STOPPED;
         break;

      case NULL:                                            // explicit stop (manual) or end of test
         instance.status = STATUS_STOPPED;
         break;

      default: return(!catch("StopTrading(2)  "+ instance.name +" invalid parameter SIG_TYPE: "+ sigType, ERR_INVALID_PARAMETER));
   }
   SS.StartStopConditions();
   SS.TotalProfit();
   SS.ProfitStats();

   if (IsLogInfo()) logInfo("StopTrading(3)  "+ instance.name +" "+ ifString(__isTesting && !sigType, "test ", "") +"stopped"+ ifString(!sigType, "", " ("+ SignalTypeToStr(sigType) +")") +", profit: "+ status.totalProfit +" "+ status.profitStats);
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
   }

   // update PnL stats
   instance.openNetProfit  = open.netProfitM;
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
      SS.TotalProfit();
      SS.ProfitStats();
   }
   return(!catch("UpdateStatus(3)"));
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
   WriteIniString(file, section, "Instance.StartAt",           /*string  */ Instance.StartAt);
   WriteIniString(file, section, "Instance.StopAt",            /*string  */ Instance.StopAt);
   WriteIniString(file, section, "ZigZag.Periods",             /*int     */ ZigZag.Periods);
   WriteIniString(file, section, "Lots",                       /*double  */ NumberToStr(Lots, ".+"));
   WriteIniString(file, section, "EntryOrder.Distance",        /*int     */ EntryOrder.Distance);
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
   WriteIniString(file, section, "instance.startEquity",       /*double  */ DoubleToStr(instance.startEquity, 2));
   WriteIniString(file, section, "recorder.stdEquitySymbol",   /*string  */ recorder.stdEquitySymbol + separator);

   WriteIniString(file, section, "start.time.condition",       /*bool    */ start.time.condition);
   WriteIniString(file, section, "start.time.value",           /*datetime*/ start.time.value);
   WriteIniString(file, section, "start.time.isDaily",         /*bool    */ start.time.isDaily);
   WriteIniString(file, section, "start.time.descr",           /*string  */ start.time.descr + separator);

   WriteIniString(file, section, "stop.time.condition",        /*bool    */ stop.time.condition);
   WriteIniString(file, section, "stop.time.value",            /*datetime*/ stop.time.value);
   WriteIniString(file, section, "stop.time.isDaily",          /*bool    */ stop.time.isDaily);
   WriteIniString(file, section, "stop.time.descr",            /*string  */ stop.time.descr + separator);

   WriteIniString(file, section, "stop.profitPct.condition",   /*bool    */ stop.profitPct.condition);
   WriteIniString(file, section, "stop.profitPct.value",       /*double  */ NumberToStr(stop.profitPct.value, ".1+"));
   WriteIniString(file, section, "stop.profitPct.absValue",    /*double  */ ifString(stop.profitPct.absValue==INT_MAX, INT_MAX, DoubleToStr(stop.profitPct.absValue, 2)));
   WriteIniString(file, section, "stop.profitPct.descr",       /*string  */ stop.profitPct.descr + separator);

   WriteIniString(file, section, "stop.profitPunit.condition", /*bool    */ stop.profitPunit.condition);
   WriteIniString(file, section, "stop.profitPunit.value",     /*double  */ NumberToStr(stop.profitPunit.value, ".1+"));
   WriteIniString(file, section, "stop.profitPunit.descr",     /*string  */ stop.profitPunit.descr + separator);

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

   string section="", file=GetStatusFilename();
   if (file == "")                 return(!catch("ReadStatus(2)  "+ instance.name +" status file not found", ERR_RUNTIME_ERROR));
   if (!IsFile(file, MODE_SYSTEM)) return(!catch("ReadStatus(3)  "+ instance.name +" file \""+ file +"\" not found", ERR_FILE_NOT_FOUND));

   // [General]
   if (!ReadStatus.General(file)) return(false);

   // [Inputs]
   section = "Inputs";
   Instance.ID                = GetIniStringA(file, section, "Instance.ID",      "");              // string   Instance.ID                = T123
   Instance.StartAt           = GetIniStringA(file, section, "Instance.StartAt", "");              // string   Instance.StartAt           = @time(datetime|time)
   Instance.StopAt            = GetIniStringA(file, section, "Instance.StopAt",  "");              // string   Instance.StopAt            = @time(datetime|time) | @profit(numeric[%])
   ZigZag.Periods             = GetIniInt    (file, section, "ZigZag.Periods"      );              // int      ZigZag.Periods             = 40
   Lots                       = GetIniDouble (file, section, "Lots"                );              // double   Lots                       = 0.1
   EntryOrder.Distance        = GetIniInt    (file, section, "EntryOrder.Distance" );              // int      EntryOrder.Distance        = 12
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
   recorder.stdEquitySymbol   = GetIniStringA(file, section, "recorder.stdEquitySymbol", "");      // string   recorder.stdEquitySymbol   = GBPJPY.001
   SS.InstanceName();

   start.time.condition       = GetIniBool   (file, section, "start.time.condition");              // bool     start.time.condition       = 1
   start.time.value           = GetIniInt    (file, section, "start.time.value"    );              // datetime start.time.value           = 1624924800
   start.time.isDaily         = GetIniBool   (file, section, "start.time.isDaily"  );              // bool     start.time.isDaily         = 0
   start.time.descr           = GetIniStringA(file, section, "start.time.descr", "");              // string   start.time.descr           = text

   stop.time.condition        = GetIniBool   (file, section, "stop.time.condition");               // bool     stop.time.condition        = 1
   stop.time.value            = GetIniInt    (file, section, "stop.time.value"    );               // datetime stop.time.value            = 1624924800
   stop.time.isDaily          = GetIniBool   (file, section, "stop.time.isDaily"  );               // bool     stop.time.isDaily          = 0
   stop.time.descr            = GetIniStringA(file, section, "stop.time.descr", "");               // string   stop.time.descr            = text

   stop.profitPct.condition   = GetIniBool   (file, section, "stop.profitPct.condition"        );  // bool     stop.profitPct.condition   = 0
   stop.profitPct.value       = GetIniDouble (file, section, "stop.profitPct.value"            );  // double   stop.profitPct.value       = 0
   stop.profitPct.absValue    = GetIniDouble (file, section, "stop.profitPct.absValue", INT_MAX);  // double   stop.profitPct.absValue    = 0.00
   stop.profitPct.descr       = GetIniStringA(file, section, "stop.profitPct.descr",         "");  // string   stop.profitPct.descr       = text

   stop.profitPunit.condition = GetIniBool   (file, section, "stop.profitPunit.condition");        // bool     stop.profitPunit.condition = 1
   stop.profitPunit.value     = GetIniDouble (file, section, "stop.profitPunit.value"    );        // double   stop.profitPunit.value     = 1.23456
   stop.profitPunit.descr     = GetIniStringA(file, section, "stop.profitPunit.descr", "");        // string   stop.profitPunit.descr     = text

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
            logWarn("SynchronizeStatus(2)  "+ instance.name +" dangling open position found: #"+ OrderTicket() +", adding to instance...");
            open.ticket    = OrderTicket();
            open.type      = OrderType();
            open.time      = OrderOpenTime();
            open.price     = OrderOpenPrice();
            open.priceSig  = open.price;
            open.slippageP = NULL;                                    // open PnL numbers will auto-update in the following UpdateStatus() call
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
            double   grossProfitP = ifDouble(!openType, closePrice-openPrice, openPrice-closePrice);
            double   netProfitM   = grossProfitM + swapM + commissionM;
            double   netProfitP   = grossProfitP + MathDiv(swapM + commissionM, PointValue(lots));

            logWarn("SynchronizeStatus(4)  "+ instance.name +" orphaned closed position found: #"+ ticket +", adding to instance...");
            if (IsEmpty(AddHistoryRecord(ticket, 0, 0, lots, 1, openType, openTime, openPrice, openPrice, stopLoss, takeProfit, closeTime, closePrice, closePrice, slippageP, swapM, commissionM, grossProfitM, netProfitM, netProfitP, grossProfitP, grossProfitP, grossProfitP, grossProfitP, grossProfitP))) return(false);

            // update closed PL numbers
            instance.closedNetProfit  += netProfitM;
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
 * Return a distinctive instance detail to be inserted in the status/log filename.
 *
 * @return string
 */
string GetStatusFilenameData() {
   return("P="+ ZigZag.Periods);
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
string   prev.Instance.StartAt = "";
string   prev.Instance.StopAt = "";
int      prev.ZigZag.Periods;
double   prev.Lots;
int      prev.EntryOrder.Distance;
bool     prev.ShowProfitInPercent;

// backed-up runtime variables affected by changing input parameters
int      prev.instance.id;
string   prev.instance.name = "";
datetime prev.instance.created;
bool     prev.instance.isTest;
int      prev.instance.status;

bool     prev.start.time.condition;
datetime prev.start.time.value;
bool     prev.start.time.isDaily;
string   prev.start.time.descr = "";

bool     prev.stop.time.condition;
datetime prev.stop.time.value;
bool     prev.stop.time.isDaily;
string   prev.stop.time.descr = "";
bool     prev.stop.profitPct.condition;
double   prev.stop.profitPct.value;
double   prev.stop.profitPct.absValue;
string   prev.stop.profitPct.descr = "";
bool     prev.stop.profitPunit.condition;
double   prev.stop.profitPunit.value;
string   prev.stop.profitPunit.descr = "";


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
   prev.Instance.StartAt    = StringConcatenate(Instance.StartAt, "");  // and must be copied to break the reference
   prev.Instance.StopAt     = StringConcatenate(Instance.StopAt, "");
   prev.ZigZag.Periods      = ZigZag.Periods;
   prev.Lots                = Lots;
   prev.EntryOrder.Distance = EntryOrder.Distance;
   prev.ShowProfitInPercent = ShowProfitInPercent;

   // affected runtime variables
   prev.instance.id                = instance.id;
   prev.instance.name              = instance.name;
   prev.instance.created           = instance.created;
   prev.instance.isTest            = instance.isTest;
   prev.instance.status            = instance.status;

   prev.start.time.condition       = start.time.condition;
   prev.start.time.value           = start.time.value;
   prev.start.time.isDaily         = start.time.isDaily;
   prev.start.time.descr           = start.time.descr;

   prev.stop.time.condition        = stop.time.condition;
   prev.stop.time.value            = stop.time.value;
   prev.stop.time.isDaily          = stop.time.isDaily;
   prev.stop.time.descr            = stop.time.descr;
   prev.stop.profitPct.condition   = stop.profitPct.condition;
   prev.stop.profitPct.value       = stop.profitPct.value;
   prev.stop.profitPct.absValue    = stop.profitPct.absValue;
   prev.stop.profitPct.descr       = stop.profitPct.descr;
   prev.stop.profitPunit.condition = stop.profitPunit.condition;
   prev.stop.profitPunit.value     = stop.profitPunit.value;
   prev.stop.profitPunit.descr     = stop.profitPunit.descr;

   Recorder_BackupInputs();
}


/**
 * Restore backed-up input parameters and runtime variables. Called from onInitParameters() and onInitTimeframeChange().
 */
void RestoreInputs() {
   // input parameters
   Instance.ID         = prev.Instance.ID;
   Instance.StartAt    = prev.Instance.StartAt;
   Instance.StopAt     = prev.Instance.StopAt;
   ZigZag.Periods      = prev.ZigZag.Periods;
   Lots                = prev.Lots;
   EntryOrder.Distance = prev.EntryOrder.Distance;
   ShowProfitInPercent = prev.ShowProfitInPercent;

   // affected runtime variables
   instance.id                = prev.instance.id;
   instance.name              = prev.instance.name;
   instance.created           = prev.instance.created;
   instance.isTest            = prev.instance.isTest;
   instance.status            = prev.instance.status;

   start.time.condition       = prev.start.time.condition;
   start.time.value           = prev.start.time.value;
   start.time.isDaily         = prev.start.time.isDaily;
   start.time.descr           = prev.start.time.descr;

   stop.time.condition        = prev.stop.time.condition;
   stop.time.value            = prev.stop.time.value;
   stop.time.isDaily          = prev.stop.time.isDaily;
   stop.time.descr            = prev.stop.time.descr;
   stop.profitPct.condition   = prev.stop.profitPct.condition;
   stop.profitPct.value       = prev.stop.profitPct.value;
   stop.profitPct.absValue    = prev.stop.profitPct.absValue;
   stop.profitPct.descr       = prev.stop.profitPct.descr;
   stop.profitPunit.condition = prev.stop.profitPunit.condition;
   stop.profitPunit.value     = prev.stop.profitPunit.value;
   stop.profitPunit.descr     = prev.stop.profitPunit.descr;

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
   if (isInitParameters) {                              // otherwise the id was validated in ValidateInputs.ID()
      if (StrTrim(Instance.ID) == "") {                 // the id was deleted or not yet set, re-apply the internal id
         Instance.ID = prev.Instance.ID;
      }
      else if (Instance.ID != prev.Instance.ID)         return(!onInputError("ValidateInputs(1)  "+ instance.name +" switching to another instance is not supported (unload the EA first)"));
   }

   // Instance.StartAt: "@time(datetime|time)"
   if (!isInitParameters || Instance.StartAt!=prev.Instance.StartAt) {
      string sValue="", sValues[], exprs[], expr="", key="", descr="";
      int sizeOfExprs = Explode(Instance.StartAt, "|", exprs, NULL), iValue, time, pt[];
      datetime dtValue;
      bool isDaily, isTimeCondition = false;

      for (int i=0; i < sizeOfExprs; i++) {             // validate each expression
         expr = StrTrim(exprs[i]);
         if (!StringLen(expr)) continue;
         if (StringGetChar(expr, 0) != '@')             return(!onInputError("ValidateInputs(2)  "+ instance.name +" invalid input parameter Instance.StartAt: "+ DoubleQuoteStr(Instance.StartAt)));
         if (Explode(expr, "(", sValues, NULL) != 2)    return(!onInputError("ValidateInputs(3)  "+ instance.name +" invalid input parameter Instance.StartAt: "+ DoubleQuoteStr(Instance.StartAt)));
         if (!StrEndsWith(sValues[1], ")"))             return(!onInputError("ValidateInputs(4)  "+ instance.name +" invalid input parameter Instance.StartAt: "+ DoubleQuoteStr(Instance.StartAt)));
         key = StrTrim(sValues[0]);
         sValue = StrTrim(StrLeft(sValues[1], -1));
         if (!StringLen(sValue))                        return(!onInputError("ValidateInputs(5)  "+ instance.name +" invalid input parameter Instance.StartAt: "+ DoubleQuoteStr(Instance.StartAt)));

         if (key == "@time") {
            if (isTimeCondition)                        return(!onInputError("ValidateInputs(6)  "+ instance.name +" invalid input parameter Instance.StartAt: "+ DoubleQuoteStr(Instance.StartAt) +" (multiple time conditions)"));
            isTimeCondition = true;

            if (!ParseDateTime(sValue, NULL, pt))       return(!onInputError("ValidateInputs(7)  "+ instance.name +" invalid input parameter Instance.StartAt: "+ DoubleQuoteStr(Instance.StartAt)));
            dtValue = DateTime2(pt, DATE_OF_ERA);
            isDaily = !pt[PT_HAS_DATE];
            descr   = "time("+ TimeToStr(dtValue, ifInt(isDaily, TIME_MINUTES, TIME_DATE|TIME_MINUTES)) +")";

            if (descr != start.time.descr) {            // enable condition only if changed
               start.time.condition = true;
               start.time.value     = dtValue;
               start.time.isDaily   = isDaily;
               start.time.descr     = descr;
            }
         }
         else                                           return(!onInputError("ValidateInputs(8)  "+ instance.name +" invalid input parameter Instance.StartAt: "+ DoubleQuoteStr(Instance.StartAt)));
      }
      if (!isTimeCondition && start.time.condition) {
         start.time.condition = false;
      }
   }

   // Instance.StopAt: "@time(datetime|time) | @profit(numeric[%])"        // logical OR
   if (!isInitParameters || Instance.StopAt!=prev.Instance.StopAt) {
      sizeOfExprs = Explode(Instance.StopAt, "|", exprs, NULL);
      isTimeCondition = false;
      bool isProfitCondition = false;

      for (i=0; i < sizeOfExprs; i++) {                 // validate each expression
         expr = StrTrim(exprs[i]);
         if (!StringLen(expr)) continue;                // support both OR operators "||" and "|"
         if (StringGetChar(expr, 0) != '@')             return(!onInputError("ValidateInputs(9)  "+ instance.name +" invalid input parameter Instance.StopAt: "+ DoubleQuoteStr(Instance.StopAt)));
         if (Explode(expr, "(", sValues, NULL) != 2)    return(!onInputError("ValidateInputs(10)  "+ instance.name +" invalid input parameter Instance.StopAt: "+ DoubleQuoteStr(Instance.StopAt)));
         if (!StrEndsWith(sValues[1], ")"))             return(!onInputError("ValidateInputs(11)  "+ instance.name +" invalid input parameter Instance.StopAt: "+ DoubleQuoteStr(Instance.StopAt)));
         key = StrTrim(sValues[0]);
         sValue = StrTrim(StrLeft(sValues[1], -1));
         if (!StringLen(sValue))                        return(!onInputError("ValidateInputs(12)  "+ instance.name +" invalid input parameter Instance.StopAt: "+ DoubleQuoteStr(Instance.StopAt)));

         if (key == "@time") {
            if (isTimeCondition)                        return(!onInputError("ValidateInputs(13)  "+ instance.name +" invalid input parameter Instance.StopAt: "+ DoubleQuoteStr(Instance.StopAt) +" (multiple time conditions)"));
            isTimeCondition = true;

            if (!ParseDateTime(sValue, NULL, pt))       return(!onInputError("ValidateInputs(14)  "+ instance.name +" invalid input parameter Instance.StopAt: "+ DoubleQuoteStr(Instance.StopAt)));
            dtValue = DateTime2(pt, DATE_OF_ERA);
            isDaily = !pt[PT_HAS_DATE];
            descr   = "time("+ TimeToStr(dtValue, ifInt(isDaily, TIME_MINUTES, TIME_DATE|TIME_MINUTES)) +")";
            if (descr != stop.time.descr) {             // enable condition only if it changed
               stop.time.condition = true;
               stop.time.value     = dtValue;
               stop.time.isDaily   = isDaily;
               stop.time.descr     = descr;
            }
            if (start.time.condition && !start.time.isDaily && !stop.time.isDaily) {
               if (start.time.value >= stop.time.value) return(!onInputError("ValidateInputs(15)  "+ instance.name +" invalid times in Instance.Start/StopAt: "+ start.time.descr +" / "+ stop.time.descr +" (start time must preceed stop time)"));
            }
         }

         else if (key == "@profit") {
            if (isProfitCondition)                      return(!onInputError("ValidateInputs(16)  "+ instance.name +" invalid input parameter Instance.StopAt: "+ DoubleQuoteStr(Instance.StopAt) +" (multiple profit conditions)"));
            isProfitCondition = true;

            if (StrEndsWith(sValue, "%")) {
               sValue = StrTrim(StrLeft(sValue, -1));
               if (!StrIsNumeric(sValue))               return(!onInputError("ValidateInputs(17)  "+ instance.name +" invalid input parameter Instance.StopAt: "+ DoubleQuoteStr(Instance.StopAt)));
               double dValue = StrToDouble(sValue);
               descr  = "profit("+ NumberToStr(NormalizeDouble(dValue, 2), ".+") +"%)";
               if (descr != stop.profitPct.descr) {         // enable condition only if it changed
                  stop.profitPct.condition = true;
                  stop.profitPct.value     = dValue;
                  stop.profitPct.absValue  = INT_MAX;
                  stop.profitPct.descr     = descr;
               }
            }
            else {
               if (!StrIsNumeric(sValue))               return(!onInputError("ValidateInputs(18)  "+ instance.name +" invalid input parameter Instance.StopAt: "+ DoubleQuoteStr(Instance.StopAt)));
               dValue = StrToDouble(sValue);
               descr  = "profit("+ NumberToStr(dValue, "R+."+ pDigits) +" "+ spUnit +")";
               if (descr != stop.profitPunit.descr) {       // enable condition only if changed
                  stop.profitPunit.condition = true;
                  stop.profitPunit.value     = NormalizeDouble(dValue * pUnit, Digits);
                  stop.profitPunit.descr     = descr;
               }
            }
         }
         else                                           return(!onInputError("ValidateInputs(19)  "+ instance.name +" invalid input parameter Instance.StopAt: "+ DoubleQuoteStr(Instance.StopAt)));
      }
      if (!isTimeCondition && stop.time.condition) {
         stop.time.condition = false;
      }
   }

   // ZigZag.Periods
   if (isInitParameters && ZigZag.Periods!=prev.ZigZag.Periods) {
      if (instanceWasStarted)                           return(!onInputError("ValidateInputs(20)  "+ instance.name +" cannot change input parameter ZigZag.Periods of "+ StatusDescription(instance.status) +" instance"));
   }
   if (ZigZag.Periods < 2)                              return(!onInputError("ValidateInputs(21)  "+ instance.name +" invalid input parameter ZigZag.Periods: "+ ZigZag.Periods));

   // Lots
   if (isInitParameters && NE(Lots, prev.Lots)) {
      if (instanceWasStarted)                           return(!onInputError("ValidateInputs(22)  "+ instance.name +" cannot change input parameter Lots of "+ StatusDescription(instance.status) +" instance"));
   }
   if (LT(Lots, 0))                                     return(!onInputError("ValidateInputs(23)  "+ instance.name +" invalid input parameter Lots: "+ NumberToStr(Lots, ".1+") +" (too small)"));
   if (NE(Lots, NormalizeLots(Lots)))                   return(!onInputError("ValidateInputs(24)  "+ instance.name +" invalid input parameter Lots: "+ NumberToStr(Lots, ".1+") +" (not a multiple of MODE_LOTSTEP="+ NumberToStr(MarketInfo(Symbol(), MODE_LOTSTEP), ".+") +")"));

   // EntryOrder.Distance
   if (isInitParameters && EntryOrder.Distance!=prev.EntryOrder.Distance) {
      if (instanceWasStarted)                           return(!onInputError("ValidateInputs(25)  "+ instance.name +" cannot change input parameter EntryOrder.Distance of "+ StatusDescription(instance.status) +" instance"));
   }

   // EA.Recorder: on | off* | 1,2,3=1000,...
   if (!Recorder_ValidateInputs(IsTestInstance())) return(false);

   SS.All();
   return(!catch("ValidateInputs(26)"));
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
   SS.TotalProfit();
   SS.ProfitStats();
}


/**
 * ShowStatus: Update the string representation of the instance name.
 */
void SS.InstanceName() {
   instance.name = "Z."+ StrPadLeft(instance.id, 3, "0");
}


/**
 * ShowStatus: Update the string representation of the configured start/stop conditions.
 */
void SS.StartStopConditions() {
   if (__isChart) {
      // start conditions
      string sValue = "";
      if (start.time.descr != "") {
         sValue = sValue + ifString(sValue=="", "", " | ") + ifString(start.time.condition, "@", "!") + start.time.descr;
      }
      if (sValue == "") status.startConditions = "-";
      else              status.startConditions = sValue;

      // stop conditions
      sValue = "";
      if (stop.time.descr != "") {
         sValue = sValue + ifString(sValue=="", "", " | ") + ifString(stop.time.condition, "@", "!") + stop.time.descr;
      }
      if (stop.profitPct.descr != "") {
         sValue = sValue + ifString(sValue=="", "", " | ") + ifString(stop.profitPct.condition, "@", "!") + stop.profitPct.descr;
      }
      if (stop.profitPunit.descr != "") {
         sValue = sValue + ifString(sValue=="", "", " | ") + ifString(stop.profitPunit.condition, "@", "!") + stop.profitPunit.descr;
      }
      if (sValue == "") status.stopConditions = "-";
      else              status.stopConditions = sValue;
   }
}


/**
 * Display the current runtime status.
 *
 * @param  int error [optional] - error to display (default: none)
 *
 * @return int - the same error
 */
int ShowStatus(int error = NO_ERROR) {
   if (!__isChart) return(error);

   static bool isRecursion = false;                   // to prevent recursive calls a specified error is displayed only once
   if (error != 0) {
      if (isRecursion) return(error);
      isRecursion = true;
   }

   static string sInstanceId = "";
   if (sInstanceId == "") sInstanceId = StrPadLeft(instance.id, 3, "0");
   string sStatus="", sError="";

   switch (instance.status) {
      case NULL:           sStatus = "  not initialized"; break;
      case STATUS_WAITING: sStatus = "  waiting";         break;
      case STATUS_TRADING: sStatus = "  trading";         break;
      case STATUS_STOPPED: sStatus = "  stopped";         break;
      default:
         return(catch("ShowStatus(1)  "+ instance.name +" illegal instance status: "+ instance.status, ERR_ILLEGAL_STATE));
   }
   if (__STATUS_OFF) sError = StringConcatenate("  [switched off => ", ErrorDescription(__STATUS_OFF.reason), "]");

   string text = StringConcatenate(WindowExpertName(), "    ID: ", sInstanceId, sStatus, sError, NL,
                                                                                                 NL,
                                  "Start:    ",  status.startConditions,                         NL,
                                  "Stop:     ",  status.stopConditions,                          NL,
                                                                                                 NL,
                                  status.metricDescription,                                      NL,
                                  "Open:    ",   status.openLots,                                NL,
                                  "Closed:  ",   status.closedTrades,                            NL,
                                  "Profit:    ", status.totalProfit, "  ", status.profitStats,   NL
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
 * Create the status display box. Consists of overlapping rectangles made of font "Webdings", char "g".
 * Called from onInit() only.
 *
 * @return bool - success status
 */
bool CreateStatusBox() {
   if (!__isChart) return(true);

   int x[]={2, 102}, y=50, fontSize=76, sizeofX=ArraySize(x);
   color bgColor = LemonChiffon;

   for (int i=0; i < sizeofX; i++) {
      string label = ProgramName() +".statusbox."+ (i+1);
      if (ObjectFind(label) == -1) if (!ObjectCreateRegister(label, OBJ_LABEL, 0, 0, 0, 0, 0, 0, 0)) return(false);
      ObjectSet(label, OBJPROP_CORNER, CORNER_TOP_LEFT);
      ObjectSet(label, OBJPROP_XDISTANCE, x[i]);
      ObjectSet(label, OBJPROP_YDISTANCE, y);
      ObjectSetText(label, "g", fontSize, "Webdings", bgColor);
   }
   return(!catch("CreateStatusBox(1)"));
}


/**
 * Return a string representation of the input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("Instance.ID=",         DoubleQuoteStr(Instance.ID),      ";"+ NL +
                            "Instance.StartAt=",    DoubleQuoteStr(Instance.StartAt), ";"+ NL +
                            "Instance.StopAt=",     DoubleQuoteStr(Instance.StopAt),  ";"+ NL +

                            "ZigZag.Periods=",      ZigZag.Periods,                   ";"+ NL +
                            "Lots=",                NumberToStr(Lots, ".1+"),         ";"+ NL +
                            "EntryOrder.Distance=", EntryOrder.Distance,              ";"+ NL +

                            "ShowProfitInPercent=", BoolToStr(ShowProfitInPercent),   ";")
   );
}
