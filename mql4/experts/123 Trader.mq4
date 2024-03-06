/**
 * Rewritten version of "Opto123 EA" v1.1 (aka USDBot).
 *
 *  @source  https://www.forexfactory.com/thread/210023-123-pattern-ea
 *
 *
 * Rules
 * -----
 *  - Entry:      on 1-2-3 ZigZag breakout with ZigZag semaphore-3 between semaphore-1 and semaphore-2
 *  - StopLoss:   arbitrary, latest on opposite ZigZag breakout (not necessarily an entry signal)
 *  - TakeProfit: arbitrary, ensure that TakeProfit > StopLoss
 *
 *
 * Changes
 * -------
 *  - replaced MetaQuotes ZigZag with rosasurfer version
 *  - removed dynamic lot sizing
 *  - removed TrailingStop (to be re-added later)
 *  - replaced BreakevenStop by MovingStop configuration
 *  - restored close on opposite breakout
 *
 *
 * TODO:
 *  - optimize ManagePosition(): track processing status of levels
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
extern string ___a__________________________ = "=== Signal settings ===";                                                  //  |  @rraygun   | @matrixebiz |  @optojay   |
extern int    ZigZag.Periods                 = 6;                                                                          //  +-------------+-------------+-------------+
extern int    MinBreakoutDistance            = 0;           // in pip (0: breakout at semaphore level)                     //  |   off (0)   |   off (0)   |   off (0)   |
                                                                                                                           //  +-------------+-------------+-------------+
extern string ___b__________________________ = "=== Trade settings ===";                                                   //  |             |             |             |
extern double Lots                           = 0.1;                                                                        //  |             |             |             |
                                                                                                                           //  +-------------+-------------+-------------+
extern int    Initial.TakeProfit             = 100;         // in pip (0: partial targets only or no TP)                   //  |  off (60)   |  on (100)   |  on (400)   |
extern int    Initial.StopLoss               = 50;          // in pip (0: moving stops only or no SL                       //  |  on (100)   |  on (100)   |  on (100)   |
                                                                                                                           //  +-------------+-------------+-------------+
extern int    Target1                        = 0;           // in pip (0: no target)                                       //  |      50     |      10     |      20     |
extern int    Target1.ClosePercent           = 0;           // size to close (0: nothing)                                  //  |      0%     |     10%     |     25%     |
extern int    Target1.MoveStopTo             = 1;           // in pip (0: don't move stop)                                 //  |       1     |       1     |     -50     | 1: Breakeven-Stop (OpenPrice + 1 pip)
                                                                                                                           //  +-------------+-------------+-------------+
extern int    Target2                        = 0;           // ...                                                         //  |             |      20     |      40     |
extern int    Target2.ClosePercent           = 30;          // ...                                                         //  |             |     10%     |     25%     |
extern int    Target2.MoveStopTo             = 0;           // ...                                                         //  |             |      -      |     -30     |
                                                                                                                           //  +-------------+-------------+-------------+
extern int    Target3                        = 0;           // ...                                                         //  |             |      40     |     100     |
extern int    Target3.ClosePercent           = 30;          // ...                                                         //  |             |     10%     |     20%     |
extern int    Target3.MoveStopTo             = 0;           // ...                                                         //  |             |      -      |      20     |
                                                                                                                           //  +-------------+-------------+-------------+
extern int    Target4                        = 0;           // ...                                                         //  |             |      60     |     200     |
extern int    Target4.ClosePercent           = 30;          // ...                                                         //  |             |     10%     |     20%     |
extern int    Target4.MoveStopTo             = 0;           // ...                                                         //  |             |      -      |      -      |
                                                                                                                           //  +-------------+-------------+-------------+
extern bool   ShowProfitInPercent            = false;  // whether PnL is displayed in money amounts or percent             //
                                                                                                                           //
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#define SIGNAL_LONG        1                 // signal flags, can be combined
#define SIGNAL_SHORT       2
#define SIGNAL_CLOSE       4


// framework
#include <core/expert.mqh>
#include <stdfunctions.mqh>
#include <rsfLib.mqh>
#include <functions/HandleCommands.mqh>
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

#include <ea/functions/metric/RecordMetrics.mqh>

#include <ea/functions/status/StatusToStr.mqh>
#include <ea/functions/status/StatusDescription.mqh>
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

#include <ea/functions/status/volatile/StoreVolatileStatus.mqh>
#include <ea/functions/status/volatile/RestoreVolatileStatus.mqh>
#include <ea/functions/status/volatile/RemoveVolatileStatus.mqh>

#include <ea/functions/test/ReadTestConfiguration.mqh>

#include <ea/functions/trade/AddHistoryRecord.mqh>
#include <ea/functions/trade/CalculateMagicNumber.mqh>
#include <ea/functions/trade/ComposePositionCloseMsg.mqh>
#include <ea/functions/trade/HistoryRecordToStr.mqh>
#include <ea/functions/trade/IsMyOrder.mqh>
#include <ea/functions/trade/MovePositionToHistory.mqh>
#include <ea/functions/trade/onPositionClose.mqh>

#include <ea/functions/trade/signal/SignalTradeToStr.mqh>
#include <ea/functions/trade/signal/SignalTypeToStr.mqh>

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
   double signal[3];

   if (__isChart) HandleCommands();                   // process incoming commands, may switch on/off the instance

   if (instance.status != STATUS_STOPPED) {
      if (instance.status == STATUS_WAITING) {
         if (IsEntrySignal(signal)) {
            StartInstance(signal);
         }
      }
      else if (instance.status == STATUS_TRADING) {
         UpdateStatus();                              // update client-side status

         if (IsStopSignal(signal)) {
            StopInstance(signal);
         }
         else {
            UpdateOpenPositions();                    // update server-side status
         }
      }
      RecordMetrics();
   }
   return(last_error);





   // --- old ---------------------------------------------------------------------------------------------------------------
   // manage an open position
   if (open.ticket > 0) {
      if (IsExitSignal()) {
         if (!OrderClose(open.ticket, NULL, order.slippage, CLR_CLOSED)) return(last_error);
         open.ticket = NULL;
      }
      else if (!ManagePosition()) return(last_error);
   }

   // check for entry signal and open a new position
   if (!open.ticket) {
      //if (IsEntrySignal()) {
      //   open new position
      //}
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

   if (cmd == "toggle-open-orders") {
      return(ToggleOpenOrders());
   }
   else return(!logNotice("onCommand(1)  "+ instance.name +" unsupported command: "+ DoubleQuoteStr(fullCmd)));

   return(!logWarn("onCommand(2)  "+ instance.name +" cannot execute command "+ DoubleQuoteStr(fullCmd) +" in status "+ StatusToStr(instance.status)));
}


/**
 * Toggle the display of open orders.
 *
 * @param  bool soundOnNone [optional] - whether to play a sound if no open orders exist (default: yes)
 *
 * @return bool - success status
 */
bool ToggleOpenOrders(bool soundOnNone = true) {
   return(!catch("ToggleOpenOrders(1)  not implemented", ERR_NOT_IMPLEMENTED));
}


/**
 * Whether a new entry signal occurred.
 *
 * @param  _Out_ double &signal[] - array receiving signal details
 *
 * @return bool
 */
bool IsEntrySignal(double &signal[]) {
   if (last_error != NULL) return(false);

   static int lastTick, lastResultType, lastResultTrade;
   static double lastResultValue;

   if (Ticks == lastTick) {                           // return the same result for the same tick
      signal[SIG_TYPE ] = lastResultType;
      signal[SIG_VALUE] = lastResultValue;
      signal[SIG_TRADE] = lastResultTrade;
   }
   else {
      signal[SIG_TYPE ] = 0;
      signal[SIG_VALUE] = 0;
      signal[SIG_TRADE] = 0;

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
            entryLevel = s2Level + MinBreakoutDistance*Pip;
            if (s1Level < s3Level && Bid > entryLevel) {
               signal[SIG_TYPE ] = SIG_TYPE_ZIGZAG;
               signal[SIG_VALUE] = NormalizeDouble(entryLevel + 1*Point, Digits);
               signal[SIG_TRADE] = SIG_TRADE_LONG;
            }
         }
         else {
            entryLevel = s2Level - MinBreakoutDistance*Pip;
            if (s1Level > s3Level && Bid < entryLevel) {
               signal[SIG_TYPE ] = SIG_TYPE_ZIGZAG;
               signal[SIG_VALUE] = NormalizeDouble(entryLevel - 1*Point, Digits);
               signal[SIG_TRADE] = SIG_TRADE_SHORT;
            }
         }
         if (signal[SIG_TYPE] != NULL) {
            if (IsLogNotice()) logNotice("IsEntrySignal(1)  "+ instance.name +" "+ ifString(signal[SIG_TRADE]==SIG_TRADE_LONG, "long", "short") +" signal at "+ NumberToStr(entryLevel, PriceFormat) +" (market: "+ NumberToStr(Bid, PriceFormat) +"/"+ NumberToStr(Ask, PriceFormat) +")");
         }
      }

      lastTick        = Ticks;
      lastResultType  = signal[SIG_TYPE ];
      lastResultValue = signal[SIG_VALUE];
      lastResultTrade = signal[SIG_TRADE];
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
   return(false);                                              // TODO
}


/**
 * Whether a signal occurred to close an open position.
 *
 * @return bool
 */
bool IsExitSignal() {
   int signal;
   if (IsTradeSignal(signal)) {
      return(signal & SIGNAL_CLOSE != 0);
   }
   return(false);
}


/**
 * Whether a trade signal occurred.
 *
 * @param  _Out_ int &signal - variable receiving a combination of signal flags of triggered conditions
 *
 * @return bool
 */
bool IsTradeSignal(int &signal) {
   signal = NULL;
   static int lastTick, lastResult;

   if (Ticks == lastTick) {                              // return the same result for the same tick
      signal = lastResult;
   }
   else {
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
               if (Bid < s2Level) signal = SIGNAL_CLOSE;
            }
         }
         else if (trend == OP_LONG) {
            if (Bid > s2Level) signal = SIGNAL_CLOSE;    // Bid prevents the close signal to be triggered by spread widening
         }
      }

      // check for an open signal for a new position
      if (!open.ticket || signal==SIGNAL_CLOSE) {
         if (trend == OP_LONG) {
            entryLevel = s2Level + MinBreakoutDistance*Pip;
            if (s1Level < s3Level && Bid > entryLevel) signal |= SIGNAL_LONG;
         }
         else {
            entryLevel = s2Level - MinBreakoutDistance*Pip;
            if (s1Level > s3Level && Bid < entryLevel) signal |= SIGNAL_SHORT;
         }
      }

      if (signal != NULL) {
         if (IsLogNotice()) {
            if (signal & SIGNAL_CLOSE               != 0) logNotice("IsTradeSignal(1)  close signal at "+ NumberToStr(s2Level, PriceFormat) +" (market: "+ NumberToStr(Bid, PriceFormat) +"/"+ NumberToStr(Ask, PriceFormat) +")");
            if (signal & (SIGNAL_LONG|SIGNAL_SHORT) != 0) logNotice("IsTradeSignal(2)  "+ ifString(signal & SIGNAL_LONG, "long", "short") +" signal at "+ NumberToStr(entryLevel, PriceFormat) +" (market: "+ NumberToStr(Bid, PriceFormat) +"/"+ NumberToStr(Ask, PriceFormat) +")");
         }
      }
      lastTick = Ticks;
      lastResult = signal;
   }
   return(signal != NULL);
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
   //debug("FindNextSemaphore(1)  Tick="+ Ticks +"  startbar="+ startbar +"  trend="+ trend +"  semaphore["+ offset +"]="+ TimeToStr(Time[offset], TIME_DATE|TIME_MINUTES) +"  "+ PriceTypeDescription(type));
   return(true);
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
   int    sigType  = signal[SIG_TYPE ];
   double sigValue = signal[SIG_VALUE];
   int    sigTrade = signal[SIG_TRADE];
   if (!(sigTrade & (SIG_TRADE_LONG|SIG_TRADE_SHORT)))                     return(!catch("StartInstance(2)  "+ instance.name +" invalid parameter SIG_TRADE: "+ sigTrade, ERR_INVALID_PARAMETER));

   instance.status = STATUS_TRADING;
   if (!instance.startEquity) instance.startEquity = NormalizeDouble(AccountEquity() - AccountCredit() + GetExternalAssets(), 2);

   // open a new position
   int    type        = ifInt(sigTrade==SIG_TRADE_LONG, OP_BUY, OP_SELL), oe[];
   double stoploss    = CalculateInitialStopLoss(type);
   double takeprofit  = CalculateInitialTakeProfit(type);
   string comment     = instance.name;
   int    magicNumber = CalculateMagicNumber(instance.id);
   color  marker      = ifInt(type==OP_BUY, CLR_OPEN_LONG, CLR_OPEN_SHORT);

   int ticket = OrderSendEx(Symbol(), type, Lots, NULL, order.slippage, stoploss, takeprofit, comment, magicNumber, NULL, marker, NULL, oe);
   if (!ticket) return(!SetLastError(oe.Error(oe)));

   // store the position data
   open.ticket       = ticket;
   open.type         = type;
   open.lots         = oe.Lots(oe);
   open.time         = oe.OpenTime(oe);
   open.price        = oe.OpenPrice(oe);
   open.priceSig     = ifDouble(sigType==SIG_TYPE_ZIGZAG, sigValue, Bid);
   open.stoploss     = stoploss;
   open.takeprofit   = takeprofit;
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

   // update PnL stats
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
      SS.TotalProfit();
      SS.ProfitStats();
   }
   if (IsLogInfo()) logInfo("StartInstance(3)  "+ instance.name +" instance started ("+ SignalTradeToStr(sigTrade) +")");
   return(SaveStatus());
}


/**
 * Stop a running instance and close open positions (if any).
 *
 * @param  double signal[] - signal infos causing the call
 *
 * @return bool - success status
 */
bool StopInstance(double signal[]) {
   if (last_error != NULL)                                                 return(false);
   if (instance.status!=STATUS_WAITING && instance.status!=STATUS_TRADING) return(!catch("StopInstance(1)  "+ instance.name +" cannot stop "+ StatusDescription(instance.status) +" instance", ERR_ILLEGAL_STATE));

   int    sigType  = signal[SIG_TYPE ];
   double sigValue = signal[SIG_VALUE];
   int    sigTrade = signal[SIG_TRADE];

   // close an open position
   if (instance.status == STATUS_TRADING) {
      if (open.ticket > 0) {
         int oeFlags, oe[];
         bool success = OrderCloseEx(open.ticket, NULL, order.slippage, CLR_NONE, oeFlags, oe);
         if (!success) return(!SetLastError(oe.Error(oe)));

         double closePrice = oe.ClosePrice(oe), closePriceSig = ifDouble(sigType==SIG_TYPE_ZIGZAG, sigValue, Bid);
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

         SS.TotalProfit();
         SS.ProfitStats();
      }
   }

   // update status
   instance.status = STATUS_STOPPED;
   if (IsLogInfo()) logInfo("StopInstance(2)  "+ instance.name +" "+ ifString(__isTesting && !sigType, "test ", "") +"instance stopped"+ ifString(!sigType, "", " ("+ SignalTypeToStr(sigType) +")") +", profit: "+ status.totalProfit +" "+ status.profitStats);
   SaveStatus();

   // pause/stop the tester according to the debug configuration
   if (__isTesting) {
      if (!IsVisualMode())       Tester.Stop("StopInstance(3)");
      else if (test.onStopPause) Tester.Pause("StopInstance(4)");
   }
   return(!catch("StopInstance(5)"));
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
      if (IsError(onPositionClose("UpdateStatus(2)  "+ instance.name +" "+ ComposePositionCloseMsg(error), error))) return(false);
      if (!MovePositionToHistory(OrderCloseTime(), exitPrice, exitPriceSig))                                        return(false);
   }

   // update PnL stats
   instance.openNetProfit  = open.netProfit;
   instance.totalNetProfit = instance.openNetProfit + instance.closedNetProfit;
   instance.maxNetProfit   = MathMax(instance.maxNetProfit,    instance.totalNetProfit);
   instance.maxNetDrawdown = MathMin(instance.maxNetDrawdown,  instance.totalNetProfit);

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
 * Update server-side order status.
 *
 * @return bool - success status
 */
bool UpdateOpenPositions() {
   if (last_error || instance.status!=STATUS_TRADING) return(false);
   return(!catch("UpdateOpenPositions(1)  not implemented", ERR_NOT_IMPLEMENTED));
}


/**
 * Manage partial profits and moving stops of an open position.
 *
 * @return bool - success status
 */
bool ManagePosition() {
   if (!open.ticket) return(!catch("ManagePosition(1)  no open position found: open.ticket=0", ERR_ILLEGAL_STATE));

   int sizeTargets = ArrayRange(targets, 0);

   // process configured profit targets
   for (int i=sizeTargets-1; i >= 0; i--) {
      if (targets[i][T_CLOSE_PCT] > 0) {
         if (open.type == OP_BUY) {
            if (Bid >= open.price + targets[i][T_LEVEL]*Pip) {
               if (!TakePartialProfit(targets[i][T_REMAINDER])) return(false);
               break;
            }
         }
         else if (Ask <= open.price - targets[i][T_LEVEL]*Pip) {
            if (!TakePartialProfit(targets[i][T_REMAINDER])) return(false);
            break;
         }
      }
   }

   // process configured stops
   if (open.ticket > 0) {
      for (i=sizeTargets-1; i >= 0; i--) {
         if (targets[i][T_MOVE_STOP] != 0) {
            if (open.type == OP_BUY) {
               if (Bid >= open.price + targets[i][T_LEVEL]*Pip) {
                  if (!MoveStop(targets[i][T_MOVE_STOP])) return(false);
                  break;
               }
            }
            else if (Ask <= open.price - targets[i][T_LEVEL]*Pip) {
               if (!MoveStop(targets[i][T_MOVE_STOP])) return(false);
               break;
            }
         }
      }
   }
   return(!catch("ManagePosition(2)"));
}


/**
 * Close a partial amount of the open position. If the position is smaller then the required open lotsize after profit
 * taking, then this function does nothing.
 *
 * @param  double remainder - required remaining open lotsize
 *
 * @return bool - success status
 */
bool TakePartialProfit(double remainder) {
   if (!open.ticket) return(!catch("TakePartialProfit(1)  no open position found: open.ticket=0", ERR_ILLEGAL_STATE));

   if (open.lots > remainder) {
      int oe[];
      if (!OrderCloseEx(open.ticket, open.lots-remainder, order.slippage, CLR_CLOSED, NULL, oe)) return(!SetLastError(oe.Error(oe)));

      open.ticket = oe.RemainingTicket(oe);
      if (open.ticket > 0) {
         open.lots = oe.RemainingLots(oe);
      }
   }
   return(true);
}


/**
 * Move the StopLoss of the open position the specified distance away from the open price.
 *
 * @param  int distFromOpen - distance from open price in pip
 *
 * @return bool - success status
 */
bool MoveStop(int distFromOpen) {
   if (!open.ticket) return(!catch("MoveStop(1)  no open position found: open.ticket=0", ERR_ILLEGAL_STATE));

   if (open.type == OP_BUY) double newStop = open.price + distFromOpen*Pip;
   else                            newStop = open.price - distFromOpen*Pip;

   if (NE(newStop, open.stoploss, Digits)) {
      int oe[];
      if (!OrderModifyEx(open.ticket, open.price, newStop, open.takeprofit, NULL, CLR_OPEN_STOPLOSS, NULL, oe)) return(!SetLastError(oe.Error(oe)));
      open.stoploss = newStop;
   }
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
      if (direction == OP_LONG) sl = Bid - Initial.StopLoss*Pip;
      else                      sl = Ask + Initial.StopLoss*Pip;
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
      if      (direction == OP_LONG)  tp = Ask + Initial.TakeProfit*Pip;
      else if (direction == OP_SHORT) tp = Bid - Initial.TakeProfit*Pip;
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

   string section="", file=FindStatusFile(instance.id, instance.isTest);
   if (file == "")                 return(!catch("ReadStatus(2)  "+ instance.name +" status file not found", ERR_RUNTIME_ERROR));
   if (!IsFile(file, MODE_SYSTEM)) return(!catch("ReadStatus(3)  "+ instance.name +" file "+ DoubleQuoteStr(file) +" not found", ERR_FILE_NOT_FOUND));

   // [General]
   if (!ReadStatus.General(file)) return(false);

   // [Inputs]
   section = "Inputs";
   Instance.ID              = GetIniStringA(file, section, "Instance.ID",     "");           // string   Instance.ID         = T123
   ZigZag.Periods           = GetIniInt    (file, section, "ZigZag.Periods"     );           // int      ZigZag.Periods      = 6
   MinBreakoutDistance      = GetIniInt    (file, section, "MinBreakoutDistance");           // int      MinBreakoutDistance = 1
   Lots                     = GetIniDouble (file, section, "Lots"               );           // double   Lots                = 0.1
   if (!ReadStatus.Targets(file)) return(false);
   ShowProfitInPercent      = GetIniBool   (file, section, "ShowProfitInPercent");           // bool     ShowProfitInPercent = 1
   EA.Recorder              = GetIniStringA(file, section, "EA.Recorder",     "");           // string   EA.Recorder         = 1,2,4

   // [Runtime status]
   section = "Runtime status";
   instance.id              = GetIniInt    (file, section, "instance.id"      );             // int      instance.id              = 123
   instance.name            = GetIniStringA(file, section, "instance.name", "");             // string   instance.name            = ID.123
   instance.created         = GetIniInt    (file, section, "instance.created" );             // datetime instance.created         = 1624924800 (Mon, 2021.05.12 13:22:34)
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
         open.stoploss   = OrderStopLoss();
         open.takeprofit = OrderTakeProfit();
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
   WriteIniString(file, section, "ZigZag.Periods",             /*int     */ ZigZag.Periods);
   WriteIniString(file, section, "MinBreakoutDistance",        /*int     */ MinBreakoutDistance);
   WriteIniString(file, section, "Lots",                       /*double  */ NumberToStr(Lots, ".+"));
   if (!SaveStatus.Targets(file, true)) return(false);         // StopLoss and TakeProfit targets
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
   WriteIniString(file, section, "instance.status",            /*int     */ instance.status +" ("+ StatusDescription(instance.status) +")" + separator);

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
bool     prev.ShowProfitInPercent;

// backed-up runtime variables affected by changing input parameters
int      prev.instance.id;
string   prev.instance.name = "";
datetime prev.instance.created;
bool     prev.instance.isTest;
int      prev.instance.status;


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
   prev.ZigZag.Periods      = ZigZag.Periods;                           // and must be copied to break the reference
   prev.MinBreakoutDistance = MinBreakoutDistance;
   prev.Lots                = Lots;
   prev.ShowProfitInPercent = ShowProfitInPercent;

   // affected runtime variables
   prev.instance.id      = instance.id;
   prev.instance.name    = instance.name;
   prev.instance.created = instance.created;
   prev.instance.isTest  = instance.isTest;
   prev.instance.status  = instance.status;

   BackupInputs.Targets();
   BackupInputs.Recorder();
}


/**
 * Restore backed-up input parameters and runtime variables. Called from onInitParameters() and onInitTimeframeChange().
 */
void RestoreInputs() {
   // input parameters
   Instance.ID         = prev.Instance.ID;
   ZigZag.Periods      = prev.ZigZag.Periods;
   MinBreakoutDistance = prev.MinBreakoutDistance;
   Lots                = prev.Lots;
   ShowProfitInPercent = prev.ShowProfitInPercent;

   // affected runtime variables
   instance.id      = prev.instance.id;
   instance.name    = prev.instance.name;
   instance.created = prev.instance.created;
   instance.isTest  = prev.instance.isTest;
   instance.status  = prev.instance.status;

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
   bool hasOpenOrders = false;

   // Instance.ID
   if (isInitParameters) {                                        // otherwise the id was validated in ValidateInputs.ID()
      if (StrTrim(Instance.ID) == "") {                           // the id was deleted or not yet set, restore the internal id
         Instance.ID = prev.Instance.ID;
      }
      else if (Instance.ID != prev.Instance.ID)    return(!onInputError("ValidateInputs(1)  "+ instance.name +" switching to another instance is not supported (unload the EA first)"));
   }

   // ZigZag.Periods
   if (isInitParameters && ZigZag.Periods!=prev.ZigZag.Periods) {
      if (hasOpenOrders)                           return(!onInputError("ValidateInputs(2)  "+ instance.name +" cannot change input parameter ZigZag.Periods with open orders"));
   }
   if (ZigZag.Periods < 2)                         return(!onInputError("ValidateInputs(3)  "+ instance.name +" invalid input parameter ZigZag.Periods: "+ ZigZag.Periods +" (must be > 1)"));

   // MinBreakoutDistance
   if (MinBreakoutDistance < 0)                    return(!onInputError("ValidateInputs(4)  "+ instance.name +" invalid input parameter MinBreakoutDistance: "+ MinBreakoutDistance +" (must be >= 0)"));

   // Lots
   if (LT(Lots, 0))                                return(!onInputError("ValidateInputs(5)  "+ instance.name +" invalid input parameter Lots: "+ NumberToStr(Lots, ".1+") +" (must be > 0)"));
   if (NE(Lots, NormalizeLots(Lots)))              return(!onInputError("ValidateInputs(6)  "+ instance.name +" invalid input parameter Lots: "+ NumberToStr(Lots, ".1+") +" (must be a multiple of MODE_LOTSTEP="+ NumberToStr(MarketInfo(Symbol(), MODE_LOTSTEP), ".+") +")"));

   // Targets
   if (!ValidateInputs.Targets()) return(false);

   // EA.Recorder: on | off* | 1,2,3=1000,...
   if (!Recorder.ValidateInputs(IsTestInstance())) return(false);

   SS.All();
   return(!catch("ValidateInputs(7)"));
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
   instance.name = "One."+ StrPadLeft(instance.id, 3, "0");
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

   static bool isRecursion = false;          // to prevent recursive calls a specified error is displayed only once
   if (error != 0) {
      if (isRecursion) return(error);
      isRecursion = true;
   }
   string sStatus="", sError="";

   switch (instance.status) {
      case NULL: sStatus = StringConcatenate(instance.name, "  not initialized");          break;
      case -1:   sStatus = StringConcatenate(instance.name, "  (status not implemented)"); break;
      default:
         return(catch("ShowStatus(1)  "+ instance.name +" illegal instance status: "+ instance.status, ERR_ILLEGAL_STATE));
   }
   if (__STATUS_OFF) sError = StringConcatenate("  [switched off => ", ErrorDescription(__STATUS_OFF.reason), "]");

   string text = StringConcatenate(ProgramName(), "    ", sStatus, sError, NL);

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

   int x[]={2, 66, 136}, y=50, fontSize=54, sizeofX=ArraySize(x);
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
   return(StringConcatenate("Instance.ID=",          DoubleQuoteStr(Instance.ID),    ";"+ NL +

                            "ZigZag.Periods=",       ZigZag.Periods,                 ";"+ NL +
                            "MinBreakoutDistance=",  MinBreakoutDistance,            ";"+ NL +

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
