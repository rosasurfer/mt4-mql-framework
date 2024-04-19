/**
 * Rewritten version of "Opto123 EA" v1.1 (aka USDBot).
 *
 *  @see  https://www.forexfactory.com/thread/210023-123-pattern-ea
 *
 * Rules
 * -----
 *  - Entry:      on 1-2-3 ZigZag breakout with ZigZag semaphore-3 between semaphore-1 and semaphore-2
 *  - StopLoss:   arbitrary, optionally on opposite ZigZag breakout (not necessarily an opposite entry signal)
 *  - TakeProfit: arbitrary, ensure that TakeProfit > StopLoss
 *
 * Notes
 * -----
 *  - Signals represent a basic bar pattern. The pattern is not related to the current market scheme/trend and there no
 *    distinction between micro and macro patterns. In effect signal outcome is random and results merely reflect the used
 *    exit management. Worse, signals are not able to catch big trends where exit management could play out its strengths.
 *
 *  - Solutions: One idea is to combine the signal with the "XARD 2nd Dot" system. By nesting two 1-2-3 signals into each
 *    other it would put signals into the context of the greater trend. Such a combination looks robust and reliable. Also
 *    it filters many of the easily mis-leading micro signals.
 *
 *
 * Changes
 * -------
 *  - replaced ZigZag.mq with ZigZag.rsf
 *  - added input option CloseOnOppositeBreakout
 *  - removed dynamic position sizing
 *  - removed TrailingStop
 *
 *
 * TODO:
 *  - test/optimize ProcessTargets()
 *     track processing status of levels
 *     implement open.nextTarget
 *
 *  - test results GBPJPY,M5 + ZigZag(20)
 *     Initial.TakeProfit=70; Initial.StopLoss=50; no targets:                            around breakeven
 *     Initial.TakeProfit=70; Initial.StopLoss=50; Target1=30; Target1.MoveStopTo=1:      choppy, always below breakeven (BE stop kicks in too early)
 *     Initial.TakeProfit=80; Initial.StopLoss=50; Target1=40; Target1.MoveStopTo=1:      significantly better (more room for TP and BE stop)
 */
#define STRATEGY_ID  109                     // unique strategy id (used for generation of magic order numbers)

#include <stddefines.mqh>
int   __InitFlags[] = {INIT_PIPVALUE, INIT_BUFFERED_LOG};
int __DeinitFlags[];
int __virtualTicks = 10000;                  // every 10 seconds to continue operation on a stalled data feed

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////
                                                                                                                           //
extern string Instance.ID                    = "";          // instance to load from a status file (format "[T]123")       //
                                                                                                                           //  +-------------+-------------+-------------+
extern string ___a__________________________ = "=== Signal settings ============";                                         //  |  @rraygun   | @matrixebiz |  @optojay   |
extern int    ZigZag.Periods                 = 6;                                                                          //  +-------------+-------------+-------------+
extern int    MinBreakoutDistance            = 0;           // in punits (0: breakout at semaphore level)                  //  |   off (0)   |   off (0)   |   off (0)   |
                                                                                                                           //  +-------------+-------------+-------------+
extern string ___b__________________________ = "=== Trade settings ============";                                          //  |             |             |             |
extern double Lots                           = 0.1;                                                                        //  |             |             |             |
                                                                                                                           //  +-------------+-------------+-------------+
extern int    Initial.TakeProfit             = 100;         // in punits (0: partial targets only or no TP)                //  |  off (60)   |  on (100)   |  on (400)   |
extern int    Initial.StopLoss               = 50;          // in punits (0: moving stops only or no SL                    //  |  on (100)   |  on (100)   |  on (100)   |
extern bool   CloseOnOppositeBreakout        = false;                                                                      //  |   off (0)   |   off (0)   |   off (0)   |
extern string ___c__________________________;                                                                              //  +-------------+-------------+-------------+
extern int    Target1                        = 0;           // in punits (0: no target)                                    //  |      50     |      10     |      20     |
extern int    Target1.ClosePercent           = 0;           // size to close (0: nothing)                                  //  |      0%     |     10%     |     25%     |
extern int    Target1.MoveStopTo             = 1;           // in punits (0: don't move stop)                              //  |       1     |       1     |     -50     | 1: Breakeven-Stop (OpenPrice + 1 pip)
extern string ___d__________________________;                                                                              //  +-------------+-------------+-------------+
extern int    Target2                        = 0;           // ...                                                         //  |             |      20     |      40     |
extern int    Target2.ClosePercent           = 25;          // ...                                                         //  |             |     10%     |     25%     |
extern int    Target2.MoveStopTo             = 0;           // ...                                                         //  |             |      -      |     -30     |
extern string ___e__________________________;                                                                              //  +-------------+-------------+-------------+
extern int    Target3                        = 0;           // ...                                                         //  |             |      40     |     100     |
extern int    Target3.ClosePercent           = 25;          // ...                                                         //  |             |     10%     |     20%     |
extern int    Target3.MoveStopTo             = 0;           // ...                                                         //  |             |      -      |      20     |
extern string ___f__________________________;                                                                              //  +-------------+-------------+-------------+
extern int    Target4                        = 0;           // ...                                                         //  |             |      60     |     200     |
extern int    Target4.ClosePercent           = 25;          // ...                                                         //  |             |     10%     |     20%     |
extern int    Target4.MoveStopTo             = 0;           // ...                                                         //  |             |      -      |      -      |
                                                                                                                           //  +-------------+-------------+-------------+
extern string ___g__________________________ = "=== Other settings ============";                                          //
extern bool   ShowProfitInPercent            = false;  // whether PnL is displayed in money amounts or percent             //
                                                                                                                           //
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// framework
#include <core/expert.mqh>
#include <core/expert.recorder.mqh>
#include <stdfunctions.mqh>
#include <rsfLib.mqh>
#include <functions/HandleCommands.mqh>
#include <functions/InitializeByteBuffer.mqh>
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
#include <ea/functions/onCommand.mqh>

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
#include <ea/functions/trade/OpenPositionToStr.mqh>

#include <ea/functions/trade/signal/SignalOperationToStr.mqh>
#include <ea/functions/trade/signal/SignalTypeToStr.mqh>

#include <ea/functions/trade/stats/CalculateStats.mqh>

#include <ea/functions/validation/ValidateInputs.ID.mqh>
#include <ea/functions/validation/ValidateInputs.Targets.mqh>
#include <ea/functions/validation/onInputError.mqh>

// init/deinit
#include <ea/init.mqh>
#include <ea/deinit.mqh>


// shorter metric aliases
#define NET_MONEY    METRIC_NET_MONEY
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
      if (!HandleCommands()) return(last_error);      // process incoming commands, may switch on/off the instance
   }

   if (instance.status != STATUS_STOPPED) {
      if (instance.status == STATUS_WAITING) {
         if (IsEntrySignal(signal)) {
            StartTrading(signal);
         }
      }
      else if (instance.status == STATUS_TRADING) {
         UpdateStatus();                              // update client-side status

         if (IsStopSignal(signal)) {
            StopTrading(signal);
         }
         else {
            UpdatePositions();                        // update server-side status
         }
      }
      RecordMetrics();
   }
   return(last_error);

   OpenPositionToStr();
}


/**
 * Whether a signal occurred to open a new position.
 *
 * @param  _Out_ double &signal[] - array receiving signal details
 *
 * @return bool
 */
bool IsEntrySignal(double &signal[]) {
   if (last_error != NULL) return(false);

   static int lastTick, lastOpenTicket=-1, lastResultType, lastResultOp;
   static double lastResultPrice;

   if (Ticks==lastTick && open.ticket==lastOpenTicket) {       // return the same result for the same tick
      signal[SIG_TYPE ] = lastResultType;
      signal[SIG_PRICE] = lastResultPrice;
      signal[SIG_OP   ] = lastResultOp;
   }
   else {
      signal[SIG_TYPE ] = 0;
      signal[SIG_PRICE] = 0;
      signal[SIG_OP   ] = 0;

      // find the previous 3 ZigZag semaphores
      int s1Bar, s2Bar, s3Bar, s2Type, iNull;
      double s1Level, s2Level, s3Level, entryLevel, dNull;
      if (!FindNextSemaphore(    0, s3Bar, iNull,  s3Level)) return(false);
      if (!FindNextSemaphore(s3Bar, s2Bar, s2Type, s2Level)) return(false);
      if (!FindNextSemaphore(s2Bar, s1Bar, iNull,  s1Level)) return(false);
      int trend = ifInt(s2Type==MODE_HIGH, OP_LONG, OP_SHORT);

      // check for entry signal for a new position
      if (!open.ticket) {
         if (trend == OP_LONG) {
            if (s1Level <= s3Level && _Bid == High[0] && _Bid > s2Level) {
               entryLevel = NormalizeDouble(s2Level + MinBreakoutDistance * pUnit, Digits);
               if (_Bid >= entryLevel) /*&&*/ if (High[iHighest(NULL, NULL, MODE_LOW, s3Bar-1, 1)] < entryLevel) {
                  signal[SIG_TYPE ] = SIG_TYPE_ZIGZAG;
                  signal[SIG_PRICE] = NormalizeDouble(entryLevel + 1*Point, Digits);
                  signal[SIG_OP   ] = SIG_OP_LONG;
               }
            }
         }
         else {
            if (s1Level >= s3Level && _Bid==Low[0] && _Bid < s2Level) {
               entryLevel = NormalizeDouble(s2Level - MinBreakoutDistance * pUnit, Digits);
               if (_Bid <= entryLevel) /*&&*/ if (Low[iLowest(NULL, NULL, MODE_LOW, s3Bar-1, 1)] > entryLevel) {
                  signal[SIG_TYPE ] = SIG_TYPE_ZIGZAG;
                  signal[SIG_PRICE] = NormalizeDouble(entryLevel - 1*Point, Digits);
                  signal[SIG_OP   ] = SIG_OP_SHORT;
               }
            }
         }
         if (signal[SIG_TYPE] != NULL) {
            int sigOp = signal[SIG_OP];
            if (IsLogNotice()) logNotice("IsEntrySignal(1)  "+ instance.name +" "+ ifString(sigOp & SIG_OP_LONG, "long", "short") +" signal at "+ NumberToStr(entryLevel, PriceFormat) +" (1-2-3 breakout, market: "+ NumberToStr(Bid, PriceFormat) +"/"+ NumberToStr(Ask, PriceFormat) +")");
         }
      }

      lastTick        = Ticks;
      lastOpenTicket  = open.ticket;
      lastResultType  = signal[SIG_TYPE ];
      lastResultPrice = signal[SIG_PRICE];
      lastResultOp    = signal[SIG_OP   ];
   }
   return(lastResultType != NULL);
}


/**
 * Whether a signal occurred to close an open position.
 *
 * @param  _Out_ double &signal[] - array receiving signal details
 *
 * @return bool
 */
bool IsExitSignal(double &signal[]) {
   if (last_error || !CloseOnOppositeBreakout) return(false);

   static int lastTick, lastOpenTicket=-1, lastResultType, lastResultOp;
   static double lastResultPrice;

   if (Ticks==lastTick && open.ticket==lastOpenTicket) {       // return the same result for the same tick
      signal[SIG_TYPE ] = lastResultType;
      signal[SIG_PRICE] = lastResultPrice;
      signal[SIG_OP   ] = lastResultOp;
   }
   else {
      signal[SIG_TYPE ] = 0;
      signal[SIG_PRICE] = 0;
      signal[SIG_OP   ] = 0;

      // find the previous 3 ZigZag semaphores
      int s1Bar, s2Bar, s3Bar, s2Type, iNull;
      double s1Level, s2Level, s3Level, entryLevel, dNull;
      if (!FindNextSemaphore(    0, s3Bar, iNull,  s3Level)) return(false);
      if (!FindNextSemaphore(s3Bar, s2Bar, s2Type, s2Level)) return(false);
      if (!FindNextSemaphore(s2Bar, s1Bar, iNull,  s1Level)) return(false);
      int trend = ifInt(s2Type==MODE_HIGH, OP_LONG, OP_SHORT);

      // check for a close signal for an open position
      if (open.ticket > 0) {
         if (open.type == OP_LONG) {
            if (trend == OP_SHORT) {
               if (_Bid < s2Level) {
                  signal[SIG_TYPE ] = SIG_TYPE_STOPLOSS;
                  signal[SIG_PRICE] = NormalizeDouble(s2Level - 1*Point, Digits);
                  signal[SIG_OP   ] = SIG_OP_CLOSE_LONG;
               }
            }
         }
         else if (trend == OP_LONG) {
            if (_Bid > s2Level) {                        // using Bid prevents the signal to be triggered by spread widening
               signal[SIG_TYPE ] = SIG_TYPE_STOPLOSS;
               signal[SIG_PRICE] = NormalizeDouble(s2Level + 1*Point, Digits);
               signal[SIG_OP   ] = SIG_OP_CLOSE_SHORT;
            }
         }
         if (signal[SIG_TYPE] != NULL) {
            int sigOp = signal[SIG_OP];
            if (IsLogNotice()) logNotice("IsExitSignal(1)  "+ instance.name +" close "+ ifString(sigOp & SIG_OP_CLOSE_LONG, "long", "short") +" signal at "+ NumberToStr(signal[SIG_PRICE], PriceFormat) +" (opposite breakout, market: "+ NumberToStr(Bid, PriceFormat) +"/"+ NumberToStr(Ask, PriceFormat) +")");
         }
      }
      lastTick        = Ticks;
      lastOpenTicket  = open.ticket;
      lastResultType  = signal[SIG_TYPE ];
      lastResultPrice = signal[SIG_PRICE];
      lastResultOp    = signal[SIG_OP   ];
   }
   return(lastResultType != NULL);
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
   return(false);
}


/**
 * Find the next ZigZag semaphore starting at the specified bar offset.
 *
 * @param  _In_  int    startbar - startbar to search from
 * @param  _Out_ int    &offset  - offset of the found ZigZag semaphore
 * @param  _Out_ int    &type    - type of the found semaphore: MODE_HIGH|MODE_LOW
 * @param  _Out_ double &price   - price level of the found semaphore
 *
 * @return bool - success status
 */
bool FindNextSemaphore(int startbar, int &offset, int &type, double &price) {
   int trend = MathRound(icZigZag(NULL, ZigZag.Periods, ZigZag.MODE_TREND, startbar));
   if (!trend) return(false);

   int absTrend = MathAbs(trend);
   offset = startbar + (absTrend % 100000) + (absTrend / 100000);

   if (trend < 0) {
      type = MODE_HIGH;
      price = High[offset];
   }
   else {
      type = MODE_LOW;
      price = Low[offset];
   }
   return(true);
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

   if (!instance.startEquity) instance.startEquity = NormalizeDouble(AccountEquity() - AccountCredit() + GetExternalAssets(), 2);
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
 * Stop trading on a running instance. Closes open positions (if any).
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
   if (instance.status==STATUS_TRADING && open.ticket) {
      ClosePosition(signal);
   }

   // update status
   instance.status = STATUS_STOPPED;
   instance.stopped = Tick.time;

   if (__isChart || IsLogInfo()) {
      SS.TotalProfit();
      SS.ProfitStats();
   }
   if (IsLogInfo()) logInfo("StopTrading(2)  "+ instance.name +" "+ ifString(__isTesting && !sigType, "test ", "") +"stopped"+ ifString(!sigType, "", " ("+ SignalTypeToStr(sigType) +")") +", profit: "+ status.totalProfit +" "+ status.profitStats);
   SaveStatus();

   // pause/stop the tester according to the debug configuration
   if (__isTesting) {
      if (!IsVisualMode())       Tester.Stop("StopTrading(3)");
      else if (test.onStopPause) Tester.Pause("StopTrading(4)");
   }
   return(!catch("StopTrading(5)"));
}


/**
 * Update client-side order status.
 *
 * @return bool - success status
 */
bool UpdateStatus() {
   if (last_error || instance.status!=STATUS_TRADING) return(false);
   if (!open.ticket)                                  return(true);

   // update open position
   if (!SelectTicket(open.ticket, "UpdateStatus(1)")) return(false);
   double closePrice, closePriceSig, openCloseRange;

   bool isClosed = (OrderCloseTime() != NULL);
   if (isClosed) {
      closePrice = OrderClosePrice();
      closePriceSig = closePrice;
   }
   else {
      closePrice = ifDouble(open.type==OP_BUY, _Bid, _Ask);
      closePriceSig = _Bid;
   }
   open.swapM        = NormalizeDouble(OrderSwap(), 2);
   open.commissionM  = OrderCommission();
   open.grossProfitM = OrderProfit();
   open.netProfitM   = open.grossProfitM + open.swapM + open.commissionM;
   openCloseRange    = ifDouble(open.type==OP_BUY, closePrice-open.price, open.price-closePrice);
   open.netProfitP   = open.part * openCloseRange; if (open.swapM || open.commissionM) open.netProfitP += open.part * (open.swapM + open.commissionM)/PointValue(open.lots);
   open.runupP       = MathMax(open.runupP, openCloseRange);
   open.rundownP     = MathMin(open.rundownP, openCloseRange);
   openCloseRange    = ifDouble(open.type==OP_BUY, closePriceSig-open.priceSig, open.priceSig-closePriceSig);
   open.sigProfitP   = open.part * openCloseRange;
   open.sigRunupP    = MathMax(open.sigRunupP, openCloseRange);
   open.sigRundownP  = MathMin(open.sigRundownP, openCloseRange);

   if (isClosed) {
      int error;
      if (IsError(onPositionClose("UpdateStatus(2)  "+ instance.name +" "+ ComposePositionCloseMsg(error), error))) return(false);
      if (!MovePositionToHistory(OrderCloseTime(), closePrice, closePriceSig))                                      return(false);
   }

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
   return(!catch("UpdateStatus(3)"));
}


/**
 * Update server-side order status.
 *
 * @return bool - success status
 */
bool UpdatePositions() {
   if (last_error || instance.status!=STATUS_TRADING) return(false);
   double signal[3];

   if (open.ticket > 0) {
      if (IsExitSignal(signal)) ClosePosition(signal);   // close an existing position or...
      else                      ProcessTargets();        // take partial profits and update stop limits
   }
   if (!open.ticket) {
      if (IsEntrySignal(signal)) OpenPosition(signal);   // open a new position
   }
   return(!catch("UpdatePositions(1)"));
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
   double stopLoss    = CalculateInitialStopLoss(type);
   double takeProfit  = CalculateInitialTakeProfit(type);
   string comment     = instance.name;
   int    magicNumber = CalculateMagicNumber(instance.id);
   color  marker      = ifInt(type==OP_BUY, CLR_OPEN_LONG, CLR_OPEN_SHORT);

   int ticket = OrderSendEx(Symbol(), type, Lots, NULL, order.slippage, stopLoss, takeProfit, comment, magicNumber, NULL, marker, NULL, oe);
   if (!ticket) return(!SetLastError(oe.Error(oe)));

   // store the position data
   open.ticket       = ticket;
   open.type         = type;
   open.lots         = oe.Lots(oe);
   open.part         = 1;
   open.time         = oe.OpenTime(oe);
   open.price        = oe.OpenPrice(oe);
   open.priceSig     = ifDouble(sigType==SIG_TYPE_ZIGZAG, sigPrice, _Bid);
   open.stopLoss     = stopLoss;
   open.takeProfit   = takeProfit;
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

   // close the position
   int oeFlags, oe[];
   if (!OrderCloseEx(open.ticket, NULL, order.slippage, CLR_CLOSED, oeFlags, oe)) return(!SetLastError(oe.Error(oe)));

   datetime closeTime     = oe.CloseTime(oe);
   double   closePrice    = oe.ClosePrice(oe);
   double   closePriceSig = ifDouble(sigType==SIG_TYPE_STOPLOSS || sigType==SIG_TYPE_ZIGZAG, sigPrice, _Bid), openCloseRange;

   open.slippageP   += oe.Slippage(oe);
   open.swapM        = oe.Swap(oe);
   open.commissionM  = oe.Commission(oe);
   open.grossProfitM = oe.Profit(oe);
   open.netProfitM   = open.grossProfitM + open.swapM + open.commissionM;
   openCloseRange    = ifDouble(open.type==OP_BUY, closePrice-open.price, open.price-closePrice);
   open.netProfitP   = open.part * (openCloseRange + (open.swapM + open.commissionM)/PointValue(open.lots));
   open.runupP       = MathMax(open.runupP, openCloseRange);
   open.rundownP     = MathMin(open.rundownP, openCloseRange);
   openCloseRange    = ifDouble(open.type==OP_BUY, closePriceSig-open.priceSig, open.priceSig-closePriceSig);
   open.sigProfitP   = open.part * openCloseRange;
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
 * Manage partial profits and stops of an open position.
 *
 * @return bool - success status
 */
bool ProcessTargets() {
   if (last_error != NULL)                return(false);
   if (instance.status != STATUS_TRADING) return(!catch("ProcessTargets(1)  "+ instance.name +" cannot manage positions of "+ StatusDescription(instance.status) +" instance", ERR_ILLEGAL_STATE));
   if (!open.ticket)                      return(true);

   double closeLots, remainingLots, stopPrice;
   int sizeTargets = ArrayRange(targets, 0), distance, moveStop;

   // process configured profit targets
   for (int i=sizeTargets-1; i >= 0; i--) {
      distance      = targets[i][T_DISTANCE ];
      remainingLots = targets[i][T_REMAINDER];

      if (distance && targets[i][T_CLOSE_PCT]) {
         if (open.lots <= remainingLots) break;
         closeLots = NormalizeDouble(open.lots - remainingLots, 2);

         if (open.type == OP_BUY) {
            if (_Bid >= open.price + distance * pUnit) {
               if (IsLogDebug()) logDebug("ProcessTargets(2)  "+ instance.name +" target "+ (i+1) +" (+"+ distance +") reached, taking "+ NumberToStr(closeLots, ".+")  +" lot partial profit");
               if (!TakePartialProfit(closeLots)) return(false);
               break;
            }
         }
         else if (_Ask <= open.price - distance * pUnit) {
            if (IsLogDebug()) logDebug("ProcessTargets(3)  "+ instance.name +" target "+ (i+1) +" (+"+ distance +") reached, taking "+ NumberToStr(closeLots, ".+")  +" lot partial profit");
            if (!TakePartialProfit(closeLots)) return(false);
            break;
         }
      }
   }
   bool saveStatus = (i >= 0);

   // process configured stops
   if (open.ticket > 0) {
      for (i=sizeTargets-1; i >= 0; i--) {
         distance = targets[i][T_DISTANCE ];
         moveStop = targets[i][T_MOVE_STOP];

         if (distance && moveStop) {
            if (open.type == OP_BUY) {
               if (_Bid >= open.price + distance * pUnit) {
                  stopPrice = NormalizeDouble(open.price + moveStop * pUnit, Digits);
                  if (open.stopLoss < stopPrice) {
                     if (IsLogDebug()) logDebug("ProcessTargets(4)  "+ instance.name +" target "+ (i+1) +" (+"+ distance +") reached, moving stop to "+ NumberToStr(stopPrice, PriceFormat));
                     if (!MoveStop(stopPrice)) return(false);
                  }
                  break;
               }
            }
            else if (_Ask <= open.price - distance * pUnit) {
               stopPrice = NormalizeDouble(open.price - moveStop * pUnit, Digits);
               if (open.stopLoss > stopPrice) {
                  if (IsLogDebug()) logDebug("ProcessTargets(5)  "+ instance.name +" target "+ (i+1) +" (+"+ distance +") reached, moving stop to "+ NumberToStr(stopPrice, PriceFormat));
                  if (!MoveStop(stopPrice)) return(false);
               }
               break;
            }
         }
      }
      saveStatus = saveStatus || (i >= 0);
   }

   if (saveStatus) SaveStatus();
   return(!catch("ProcessTargets(6)"));
}


/**
 * Close a partial amount of the open position.
 *
 * @param  double lots - lots to close
 *
 * @return bool - success status
 */
bool TakePartialProfit(double lots) {
   if (last_error != NULL) return(false);
   if (!open.ticket)       return(!catch("TakePartialProfit(1)  "+ instance.name +" no open position found: open.ticket=0", ERR_ILLEGAL_STATE));
   if (open.lots < lots)   return(!catch("TakePartialProfit(2)  "+ instance.name +" cannot close "+ NumberToStr(lots, ".+") +" lots of ticket #"+ open.ticket +" with "+ NumberToStr(open.lots, ".+") +" open lots", ERR_INVALID_PARAMETER));

   // close the specified lot size
   int oe[];
   if (!OrderCloseEx(open.ticket, lots, order.slippage, CLR_CLOSED, NULL, oe)) return(!SetLastError(oe.Error(oe)));

   datetime closeTime     = oe.CloseTime(oe);
   double   closePrice    = oe.ClosePrice(oe);
   double   closePriceSig = _Bid;
   double   origSlippageP = open.slippageP;

   // update the original ticket and move it to the history
   open.toTicket     = oe.RemainingTicket(oe);
   open.lots         = lots;
   open.part         = NormalizeDouble(open.lots/Lots, 8);
   open.slippageP   += oe.Slippage(oe);
   open.swapM        = oe.Swap(oe);
   open.commissionM  = oe.Commission(oe);
   open.grossProfitM = oe.Profit(oe);
   open.netProfitM   = open.grossProfitM + open.swapM + open.commissionM;
   open.netProfitP   = open.part * (ifDouble(open.type==OP_BUY, closePrice-open.price, open.price-closePrice) + (open.swapM + open.commissionM)/PointValue(open.lots));
   open.sigProfitP   = open.part * ifDouble(open.type==OP_BUY, closePriceSig-open.priceSig, open.priceSig-closePriceSig);
   if (!MovePositionToHistory(closeTime, closePrice, closePriceSig)) return(false);

   // track/update a remaining new ticket
   if (open.toTicket > 0) {
      SelectTicket(open.toTicket, "TakePartialProfit(3)", O_SAVE_CURRENT);
      open.fromTicket   = open.ticket;
      open.ticket       = open.toTicket;
      open.toTicket     = NULL;
      open.lots         = OrderLots();
      open.part         = NormalizeDouble(open.lots/Lots, 8);
      open.slippageP    = origSlippageP;
      open.swapM        = NormalizeDouble(OrderSwap(), 2);
      open.commissionM  = OrderCommission();
      open.grossProfitM = OrderProfit();
      open.netProfitM   = open.grossProfitM + open.swapM + open.commissionM;
      open.netProfitP   = open.part * (ifDouble(open.type==OP_BUY, _Bid-open.price, open.price-_Ask) + (open.swapM + open.commissionM)/PointValue(open.lots));
      open.sigProfitP   = open.part * ifDouble(open.type==OP_BUY, _Bid-open.priceSig, open.priceSig-_Bid);
      OrderPop("TakePartialProfit(4)");
   }

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
   if (test.onPartialClosePause) Tester.Pause("TakePartialProfit(5)");
   return(!catch("TakePartialProfit(6)"));
}


/**
 * Move the StopLoss of the open position.
 *
 * @param  int newStop - new StopLoss price
 *
 * @return bool - success status
 */
bool MoveStop(double newStop) {
   if (last_error != NULL) return(false);
   if (!open.ticket)       return(!catch("MoveStop(1)  "+ instance.name +" no open position found: open.ticket=0", ERR_ILLEGAL_STATE));

   int oe[];
   if (!OrderModifyEx(open.ticket, open.price, newStop, open.takeProfit, NULL, CLR_OPEN_STOPLOSS, NULL, oe)) return(!SetLastError(oe.Error(oe)));
   open.stopLoss = newStop;

   return(true);
}


/**
 * Calculate a position's initial StopLoss value.
 *
 * @param  int direction - trade direction
 *
 * @return double - StopLoss value or NULL if no initial StopLoss is configured
 */
double CalculateInitialStopLoss(int direction) {
   double sl = 0;

   if (Initial.StopLoss > 0) {
      if (direction == OP_LONG) sl = _Bid - Initial.StopLoss * pUnit;
      else                      sl = _Ask + Initial.StopLoss * pUnit;
   }
   return(NormalizeDouble(sl, Digits));
}


/**
 * Calculate a position's initial TakeProfit value.
 *
 * @param  int direction - trade direction
 *
 * @return double - TakeProfit value or NULL if no initial TakeProfit is configured
 */
double CalculateInitialTakeProfit(int direction) {
   double tp = 0;

   if (Initial.TakeProfit > 0) {
      if      (direction == OP_LONG)  tp = _Ask + Initial.TakeProfit * pUnit;
      else if (direction == OP_SHORT) tp = _Bid - Initial.TakeProfit * pUnit;
   }
   return(NormalizeDouble(tp, Digits));
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
   Instance.ID              = GetIniStringA(file, section, "Instance.ID",         "");       // string   Instance.ID             = T123
   ZigZag.Periods           = GetIniInt    (file, section, "ZigZag.Periods"         );       // int      ZigZag.Periods          = 6
   MinBreakoutDistance      = GetIniInt    (file, section, "MinBreakoutDistance"    );       // int      MinBreakoutDistance     = 1
   Lots                     = GetIniDouble (file, section, "Lots"                   );       // double   Lots                    = 0.1
   if (!ReadStatus.Targets(file)) return(false);
   CloseOnOppositeBreakout  = GetIniBool   (file, section, "CloseOnOppositeBreakout");       // bool     CloseOnOppositeBreakout = 0
   ShowProfitInPercent      = GetIniBool   (file, section, "ShowProfitInPercent"    );       // bool     ShowProfitInPercent     = 1
   EA.Recorder              = GetIniStringA(file, section, "EA.Recorder",         "");       // string   EA.Recorder             = 1,2,4

   // [Runtime status]
   section = "Runtime status";
   instance.id              = GetIniInt    (file, section, "instance.id"      );             // int      instance.id              = 123
   instance.name            = GetIniStringA(file, section, "instance.name", "");             // string   instance.name            = ID.123
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
         if (open.ticket > 0) return(!catch("SynchronizeStatus(1)  illegal second position detected: #"+ OrderTicket(), ERR_ILLEGAL_STATE));
         open.ticket     = OrderTicket();
         open.type       = OrderType();
         open.lots       = OrderLots();
         open.price      = OrderOpenPrice();
         open.stopLoss   = OrderStopLoss();
         open.takeProfit = OrderTakeProfit();
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
   return(!catch("SynchronizeStatus(2)"));
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
   WriteIniString(file, section, "ZigZag.Periods",             /*int     */ ZigZag.Periods);
   WriteIniString(file, section, "MinBreakoutDistance",        /*int     */ MinBreakoutDistance);
   WriteIniString(file, section, "Lots",                       /*double  */ NumberToStr(Lots, ".+"));
   if (!SaveStatus.Targets(file, fileExists)) return(false);   // StopLoss and TakeProfit targets
   WriteIniString(file, section, "CloseOnOppositeBreakout",    /*bool    */ CloseOnOppositeBreakout);
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
int      prev.ZigZag.Periods;
int      prev.MinBreakoutDistance;
double   prev.Lots;
bool     prev.CloseOnOppositeBreakout;
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
   prev.Instance.ID             = StringConcatenate(Instance.ID, "");   // string inputs are references to internal C literals
   prev.ZigZag.Periods          = ZigZag.Periods;                       // and must be copied to break the reference
   prev.MinBreakoutDistance     = MinBreakoutDistance;
   prev.Lots                    = Lots;
   prev.CloseOnOppositeBreakout = CloseOnOppositeBreakout;
   prev.ShowProfitInPercent     = ShowProfitInPercent;

   // affected runtime variables
   BackupInputs.Targets();
   Recorder_BackupInputs();
}


/**
 * Restore backed-up input parameters and runtime variables. Called from onInitParameters() and onInitTimeframeChange().
 */
void RestoreInputs() {
   // input parameters
   Instance.ID             = prev.Instance.ID;
   ZigZag.Periods          = prev.ZigZag.Periods;
   MinBreakoutDistance     = prev.MinBreakoutDistance;
   Lots                    = prev.Lots;
   CloseOnOppositeBreakout = prev.CloseOnOppositeBreakout;
   ShowProfitInPercent     = prev.ShowProfitInPercent;

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
      else if (Instance.ID != prev.Instance.ID)       return(!onInputError("ValidateInputs(1)  "+ instance.name +" switching to another instance is not supported (unload the EA first)"));
   }

   // ZigZag.Periods
   if (isInitParameters && ZigZag.Periods!=prev.ZigZag.Periods) {
      if (hasOpenOrders)                              return(!onInputError("ValidateInputs(2)  "+ instance.name +" cannot change input ZigZag.Periods with open orders"));
   }
   if (ZigZag.Periods < 2)                            return(!onInputError("ValidateInputs(3)  "+ instance.name +" invalid input ZigZag.Periods: "+ ZigZag.Periods +" (must be > 1)"));

   // MinBreakoutDistance
   if (MinBreakoutDistance < 0)                       return(!onInputError("ValidateInputs(4)  "+ instance.name +" invalid input MinBreakoutDistance: "+ MinBreakoutDistance +" (must be >= 0)"));

   // Lots
   if (LT(Lots, 0))                                   return(!onInputError("ValidateInputs(5)  "+ instance.name +" invalid input Lots: "+ NumberToStr(Lots, ".1+") +" (must be > 0)"));
   if (NE(Lots, NormalizeLots(Lots)))                 return(!onInputError("ValidateInputs(6)  "+ instance.name +" invalid input Lots: "+ NumberToStr(Lots, ".1+") +" (must be a multiple of MODE_LOTSTEP="+ NumberToStr(MarketInfo(Symbol(), MODE_LOTSTEP), ".+") +")"));

   // Targets
   if (!ValidateInputs.Targets())                     return(false);

   // CloseOnOppositeBreakout
   if (!CloseOnOppositeBreakout && !Initial.StopLoss) return(!onInputError("ValidateInputs(7)  "+ instance.name +" invalid combination Initial.StopLoss=0 and CloseOnOppositeBreakout=FALSE (one must be set)"));

   // ShowProfitInPercent (nothing to do)

   // EA.Recorder: on | off* | 1,2,3=1000,...
   if (!Recorder_ValidateInputs(IsTestInstance()))    return(false);

   SS.All();
   return(!catch("ValidateInputs(8)"));
}


/**
 * ShowStatus: Update the string representation of the instance name.
 */
void SS.InstanceName() {
   instance.name = "123T."+ StrPadLeft(instance.id, 3, "0");
}


/**
 * Return a string representation of the input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("Instance.ID=",             DoubleQuoteStr(Instance.ID),        ";"+ NL +

                            "ZigZag.Periods=",          ZigZag.Periods,                     ";"+ NL +
                            "MinBreakoutDistance=",     MinBreakoutDistance,                ";"+ NL +

                            "Lots=",                    NumberToStr(Lots, ".1+"),           ";"+ NL +
                            "Initial.TakeProfit=",      Initial.TakeProfit,                 ";"+ NL +
                            "Initial.StopLoss=",        Initial.StopLoss,                   ";"+ NL +
                            "CloseOnOppositeBreakout=", BoolToStr(CloseOnOppositeBreakout), ";"+ NL +

                            "Target1=",                 Target1,                            ";"+ NL +
                            "Target1.ClosePercent=",    Target1.ClosePercent,               ";"+ NL +
                            "Target1.MoveStopTo=",      Target1.MoveStopTo,                 ";"+ NL +
                            "Target2=",                 Target2,                            ";"+ NL +
                            "Target2.ClosePercent=",    Target2.ClosePercent,               ";"+ NL +
                            "Target2.MoveStopTo=",      Target2.MoveStopTo,                 ";"+ NL +
                            "Target3=",                 Target3,                            ";"+ NL +
                            "Target3.ClosePercent=",    Target3.ClosePercent,               ";"+ NL +
                            "Target3.MoveStopTo=",      Target3.MoveStopTo,                 ";"+ NL +
                            "Target4=",                 Target4,                            ";"+ NL +
                            "Target4.ClosePercent=",    Target4.ClosePercent,               ";"+ NL +
                            "Target4.MoveStopTo=",      Target4.MoveStopTo,                 ";"+ NL +

                            "ShowProfitInPercent=",     BoolToStr(ShowProfitInPercent),     ";")
   );
}
