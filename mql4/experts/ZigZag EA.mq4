/**
 * ZigZag EA
 *
 *
 * TODO:
 *  - PL recording of system variants
 *     total PL in money
 *     daily PL in money
 *     total/daily PL in pips
 *     Sequence-IDs of all symbols and variants must be unique
 *
 *  - rename EA.ExternalReporting to Test.ExternalReporting
 *  - add EA.Recorder to SaveStatus()/ReadStatus()
 *
 *  - variants:
 *     ZigZag                                                  OK
 *     Reverse ZigZag
 *     full session (24h) with trade breaks
 *     partial session (e.g. 09:00-16:00) with trade breaks
 *
 *  - trade breaks
 *     - trading is disabled but the price feed is active
 *     - configuration:
 *        default: auto-config using the SYMBOL configuration
 *        manual override of times and behaviors (per instance => via input parameters)
 *     - default behavior:
 *        no trade commands
 *        synchronize-after if an opposite signal occurred
 *     - manual behavior configuration:
 *        close-before      (default: no)
 *        synchronize-after (default: yes; if no: wait for the next signal)
 *     - better parsing of struct SYMBOL
 *     - config support for session and trade breaks at specific day times
 *
 *  - parameter ZigZag.Timeframe
 *  - onInitTemplate error on VM restart
 *     INFO   ZigZag EA::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
 *            ZigZag EA::initTemplate(0)  inputs: Sequence.ID="6471";...
 *     FATAL  ZigZag EA::start(9)  [ERR_ILLEGAL_STATE]
 *
 *  - implement RestoreSequence()->SynchronizeStatus() to handle a lost/open position
 *  - reverse trading option "ZigZag.R" (and Turtle Soup)
 *  - stop condition "pip"
 *
 *  - two ZigZag reversals during the same bar are not recognized and ignored
 *  - track slippage and add to status display
 *  - reduce slippage on reversal: replace Close+Open by Hedge+CloseBy
 *  - display overall number of trades
 *  - display total transaction costs
 *  - input option to pick-up the last signal on start
 *  - improve handling of network outages (price and/or trade connection)
 *  - remove input Slippage and handle it dynamically (e.g. via framework config)
 *     https://www.mql5.com/en/forum/120795
 *     https://www.mql5.com/en/forum/289014#comment_9296322
 *     https://www.mql5.com/en/forum/146808#comment_3701979  [ECN restriction removed since build 500]
 *     https://www.mql5.com/en/forum/146808#comment_3701981  [query execution mode in MQL]
 *  - merge inputs TakeProfit and StopConditions
 *
 *  - permanent spread logging to a separate logfile
 *  - move all history functionality to the Expander
 *  - build script for all .ex4 files after deployment
 *  - ToggleOpenOrders() works only after ToggleHistory()
 *  - ChartInfos::onPositionOpen() doesn't log slippage
 *  - ChartInfos::CostumPosition() weekend configuration/timespans don't work
 *  - ChartInfos::CostumPosition() including/excluding a specific strategy is not supported
 *  - reverse sign of oe.Slippage() and fix unit in log messages (pip/money)
 *  - on restart delete dead screen sockets
 */
#include <stddefines.mqh>
int   __InitFlags[] = {INIT_BUFFERED_LOG};
int __DeinitFlags[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern string Sequence.ID         = "";                              // instance to load from a status file, format /T?[0-9]{4}/
extern int    ZigZag.Periods      = 40;

extern double Lots                = 0.1;
extern string StartConditions     = "";                              // @time(datetime|time)
extern string StopConditions      = "";                              // @time(datetime|time)
extern double TakeProfit          = 0;                               // TP value
extern string TakeProfit.Type     = "off* | money | percent | pip";  // may be shortened
extern int    Slippage            = 2;                               // in point

extern bool   ShowProfitInPercent = true;                            // whether PL is displayed in money or percentage terms

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/expert.mqh>
#include <stdfunctions.mqh>
#include <rsfLib.mqh>
#include <functions/ParseTime.mqh>
#include <structs/rsf/OrderExecution.mqh>

#define STRATEGY_ID               107           // unique strategy id between 101-1023 (10 bit)

#define STATUS_WAITING              1           // sequence status values
#define STATUS_PROGRESSING          2
#define STATUS_STOPPED              3

#define SIGNAL_LONG  TRADE_DIRECTION_LONG       // 1 start/stop/resume signal types
#define SIGNAL_SHORT TRADE_DIRECTION_SHORT      // 2
#define SIGNAL_TIME                 3
#define SIGNAL_TAKEPROFIT           4

#define HI_SIGNAL                   0           // order history indexes
#define HI_TICKET                   1
#define HI_LOTS                     2
#define HI_OPENTYPE                 3
#define HI_OPENTIME                 4
#define HI_OPENPRICE                5
#define HI_CLOSETIME                6
#define HI_CLOSEPRICE               7
#define HI_SLIPPAGE                 8
#define HI_SWAP                     9
#define HI_COMMISSION              10
#define HI_PROFIT                  11
#define HI_TOTALPROFIT             12

#define TP_TYPE_MONEY               1           // TakeProfit types
#define TP_TYPE_PERCENT             2
#define TP_TYPE_PIP                 3

// sequence data
int      sequence.id;
datetime sequence.created;
bool     sequence.isTest;                       // whether the sequence is a test (which can be loaded into an online chart)
string   sequence.name = "";
int      sequence.status;
double   sequence.startEquity;
double   sequence.openPL;                       // PL of all open positions (incl. commissions and swaps)
double   sequence.closedPL;                     // PL of all closed positions (incl. commissions and swaps)
double   sequence.totalPL;                      // total PL of the sequence: openPL + closedPL
double   sequence.maxProfit;                    // max. observed total profit:   0...+n
double   sequence.maxDrawdown;                  // max. observed total drawdown: -n...0

// order data
int      open.signal;                           // one open position
int      open.ticket;                           //
int      open.type;                             //
datetime open.time;                             //
double   open.price;                            //
double   open.slippage;                         //
double   open.swap;                             //
double   open.commission;                       //
double   open.profit;                           //
double   history[][13];                         // multiple closed positions

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

bool     stop.profitPip.condition;              // whether a takeprofit condition in pip is active
double   stop.profitPip.value;
string   stop.profitPip.description = "";

// caching vars to speed-up ShowStatus()
string   sLots                = "";
string   sStartConditions     = "";
string   sStopConditions      = "";
string   sSequenceTotalPL     = "";
string   sSequenceMaxProfit   = "";
string   sSequenceMaxDrawdown = "";
string   sSequencePlStats     = "";

// other
string tpTypeDescriptions[] = {"off", "money", "percent", "pip"};

// debug settings                                  // configurable via framework config, see afterInit()
bool     test.onStopPause    = false;              // whether to pause a test after StopSequence()
bool     test.optimizeStatus = true;               // whether to reduce status file writing in tester

#include <apps/zigzag-ea/init.mqh>
#include <apps/zigzag-ea/deinit.mqh>


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   if (!sequence.status) return(ERR_ILLEGAL_STATE);

   int startSignal, stopSignal, zigzagSignal;

   if (sequence.status != STATUS_STOPPED) {
      IsZigZagSignal(zigzagSignal);                                  // check ZigZag on every tick

      if (sequence.status == STATUS_WAITING) {
         if      (IsStopSignal(stopSignal))   StopSequence(stopSignal);
         else if (IsStartSignal(startSignal)) StartSequence(startSignal);
      }
      else if (sequence.status == STATUS_PROGRESSING) {
         if (UpdateStatus()) {                                       // update order status and PL
            if (IsStopSignal(stopSignal))  StopSequence(stopSignal);
            else if (zigzagSignal != NULL) ReverseSequence(zigzagSignal);
         }
      }
   }
   return(catch("onTick(1)"));
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

   if (Tick == lastTick) {
      signal = lastResult;
   }
   else {
      if (!GetZigZagData(0, trend, reversal)) return(false);
      if (Abs(trend) == reversal) {
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
         }
      }
      lastTick   = Tick;
      lastResult = signal;
   }
   return(signal != NULL);
}


/**
 * Get trend data of the ZigZag indicator at the specified bar offset.
 *
 * @param  _In_  int bar            - bar offset
 * @param  _Out_ int &combinedTrend - combined trend value at the bar offset
 * @param  _Out_ int &reversal      - reversal bar value at the bar offset
 *
 * @return bool - success status
 */
bool GetZigZagData(int bar, int &combinedTrend, int &reversal) {
   combinedTrend = Round(icZigZag(NULL, ZigZag.Periods, false, false, ZigZag.MODE_TREND,    bar));
   reversal      = Round(icZigZag(NULL, ZigZag.Periods, false, false, ZigZag.MODE_REVERSAL, bar));
   return(combinedTrend != 0);
}


/**
 * Whether a start condition is satisfied for a waiting sequence.
 *
 * @param  _Out_ int &signal - variable receiving the identifier of a satisfied condition
 *
 * @return bool
 */
bool IsStartSignal(int &signal) {
   signal = NULL;
   if (last_error || sequence.status!=STATUS_WAITING) return(false);

   // start.time: -----------------------------------------------------------------------------------------------------------
   if (start.time.condition) {
      datetime now = TimeServer();
      if (start.time.isDaily) /*&&*/ if (start.time.value < 1*DAY) {
         start.time.value += (now - (now % DAY));
         if (start.time.value < now) start.time.value += 1*DAY;      // set periodic value to the next time in the future
      }
      if (now < start.time.value) return(false);
   }

   // ZigZag signal: --------------------------------------------------------------------------------------------------------
   if (IsZigZagSignal(signal)) {
      if (IsLogNotice()) logNotice("IsStartSignal(1)  "+ sequence.name +" ZigZag "+ ifString(signal==SIGNAL_LONG, "long", "short") +" reversal (market: "+ NumberToStr(Bid, PriceFormat) +"/"+ NumberToStr(Ask, PriceFormat) +")");
      return(true);
   }
   return(false);
}


/**
 * Start a waiting sequence.
 *
 * @param  int signal - trade signal causing the call
 *
 * @return bool - success status
 */
bool StartSequence(int signal) {
   if (last_error != NULL)                          return(false);
   if (sequence.status != STATUS_WAITING)           return(!catch("StartSequence(1)  "+ sequence.name +" cannot start "+ StatusDescription(sequence.status) +" sequence", ERR_ILLEGAL_STATE));
   if (signal!=SIGNAL_LONG && signal!=SIGNAL_SHORT) return(!catch("StartSequence(2)  "+ sequence.name +" invalid parameter signal: "+ signal, ERR_INVALID_PARAMETER));

   SetLogfile(GetLogFilename());                               // flush the log on start
   if (IsLogInfo()) logInfo("StartSequence(3)  "+ sequence.name +" starting... ("+ SignalToStr(signal) +")");

   sequence.status = STATUS_PROGRESSING;
   if (!sequence.startEquity) sequence.startEquity = NormalizeDouble(AccountEquity() - AccountCredit() + GetExternalAssets(), 2);

   // open new position
   int      type        = ifInt(signal==SIGNAL_LONG, OP_BUY, OP_SELL);
   double   price       = NULL;
   double   stopLoss    = NULL;
   double   takeProfit  = NULL;
   datetime expires     = NULL;
   string   comment     = "ZigZag."+ sequence.name;
   int      magicNumber = CalculateMagicNumber();
   color    markerColor = ifInt(signal==SIGNAL_LONG, CLR_OPEN_LONG, CLR_OPEN_SHORT);
   int      oeFlags     = NULL, oe[];

   int ticket = OrderSendEx(Symbol(), type, Lots, price, Slippage, stopLoss, takeProfit, comment, magicNumber, expires, markerColor, oeFlags, oe);
   if (!ticket) return(!SetLastError(oe.Error(oe)));

   // store position data
   open.signal     = signal;
   open.ticket     = ticket;
   open.type       = oe.Type      (oe);
   open.time       = oe.OpenTime  (oe);
   open.price      = oe.OpenPrice (oe);
   open.slippage   = -oe.Slippage (oe);
   open.swap       = oe.Swap      (oe);
   open.commission = oe.Commission(oe);
   open.profit     = oe.Profit    (oe);

   // update PL numbers
   sequence.openPL      = NormalizeDouble(open.swap + open.commission + open.profit, 2);
   sequence.totalPL     = NormalizeDouble(sequence.openPL + sequence.closedPL, 2);
   sequence.maxProfit   = MathMax(sequence.maxProfit, sequence.totalPL);
   sequence.maxDrawdown = MathMin(sequence.maxDrawdown, sequence.totalPL);
   SS.TotalPL();
   SS.PLStats();

   // update start/stop conditions
   start.time.condition = false;
   stop.time.condition  = stop.time.isDaily;
   if (stop.time.isDaily) stop.time.value %= DAYS;
   SS.StartStopConditions();

   if (IsLogInfo()) logInfo("StartSequence(4)  "+ sequence.name +" sequence started ("+ SignalToStr(signal) +")");
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

   if (open.ticket > 0) {
      // either continue in the same direction...
      if ((open.type==OP_BUY && signal==SIGNAL_LONG) || (open.type==OP_SELL && signal==SIGNAL_SHORT)) {
         logWarn("ReverseSequence(3)  "+ sequence.name +" to "+ ifString(signal==SIGNAL_LONG, "long", "short") +": continuing with already open "+ ifString(signal==SIGNAL_LONG, "long", "short") +" position");
         return(true);
      }
      // ...or close the open position
      int oeFlags, oe[];
      if (!OrderCloseEx(open.ticket, NULL, Slippage, CLR_NONE, oeFlags, oe)) return(!SetLastError(oe.Error(oe)));
      if (!ArchiveClosedPosition(open.ticket, open.signal, NormalizeDouble(open.slippage-oe.Slippage(oe), 1))) return(false);
   }

   // open new position
   int      type        = ifInt(signal==SIGNAL_LONG, OP_BUY, OP_SELL);
   double   price       = NULL;
   double   stopLoss    = NULL;
   double   takeProfit  = NULL;
   datetime expires     = NULL;
   string   comment     = "ZigZag."+ sequence.name;
   int      magicNumber = CalculateMagicNumber();
   color    markerColor = ifInt(type==OP_BUY, CLR_OPEN_LONG, CLR_OPEN_SHORT);

   if (!OrderSendEx(Symbol(), type, Lots, price, Slippage, stopLoss, takeProfit, comment, magicNumber, expires, markerColor, oeFlags, oe)) return(!SetLastError(oe.Error(oe)));
   open.signal     = signal;
   open.ticket     = oe.Ticket    (oe);
   open.type       = oe.Type      (oe);
   open.time       = oe.OpenTime  (oe);
   open.price      = oe.OpenPrice (oe);
   open.slippage   = oe.Slippage  (oe);
   open.swap       = oe.Swap      (oe);
   open.commission = oe.Commission(oe);
   open.profit     = oe.Profit    (oe);

   // update PL numbers
   sequence.openPL      = NormalizeDouble(open.swap + open.commission + open.profit, 2);
   sequence.totalPL     = NormalizeDouble(sequence.openPL + sequence.closedPL, 2);
   sequence.maxProfit   = MathMax(sequence.maxProfit, sequence.totalPL);
   sequence.maxDrawdown = MathMin(sequence.maxDrawdown, sequence.totalPL);
   SS.TotalPL();
   SS.PLStats();

   return(SaveStatus());
}


/**
 * Add trade details of the specified ticket to the local history and reset open position data.
 *
 * @param int    ticket   - closed ticket
 * @param int    signal   - signal which caused opening of the trade
 * @param double slippage - cumulated open and close slippage of the trade
 *
 * @return bool - success status
 */
bool ArchiveClosedPosition(int ticket, int signal, double slippage) {
   if (last_error != NULL)                    return(false);
   if (sequence.status != STATUS_PROGRESSING) return(!catch("ArchiveClosedPosition(1)  "+ sequence.name +" cannot archive position of "+ StatusDescription(sequence.status) +" sequence", ERR_ILLEGAL_STATE));

   //if (!ArchiveClosedPosition(open.ticket, open.signal, NormalizeDouble(open.slippage - oe.Slippage(oe), 1))) return(false);

   int i = ArrayRange(history, 0);
   ArrayResize(history, i + 1);

   SelectTicket(ticket, "ArchiveClosedPosition(2)", /*push=*/true);
   history[i][HI_SIGNAL     ] = signal;
   history[i][HI_TICKET     ] = ticket;
   history[i][HI_LOTS       ] = OrderLots();
   history[i][HI_OPENTYPE   ] = OrderType();
   history[i][HI_OPENTIME   ] = OrderOpenTime();
   history[i][HI_OPENPRICE  ] = OrderOpenPrice();
   history[i][HI_CLOSETIME  ] = OrderCloseTime();
   history[i][HI_CLOSEPRICE ] = OrderClosePrice();
   history[i][HI_SLIPPAGE   ] = slippage;
   history[i][HI_SWAP       ] = OrderSwap();
   history[i][HI_COMMISSION ] = OrderCommission();
   history[i][HI_PROFIT     ] = OrderProfit();
   history[i][HI_TOTALPROFIT] = NormalizeDouble(history[i][HI_SWAP] + history[i][HI_COMMISSION] + history[i][HI_PROFIT], 2);
   OrderPop("ArchiveClosedPosition(3)");

   open.signal     = NULL;
   open.ticket     = NULL;
   open.type       = NULL;
   open.time       = NULL;
   open.price      = NULL;
   open.slippage   = NULL;
   open.swap       = NULL;
   open.commission = NULL;
   open.profit     = NULL;

   sequence.openPL   = 0;
   sequence.closedPL = NormalizeDouble(sequence.closedPL + history[i][HI_TOTALPROFIT], 2);
   sequence.totalPL  = sequence.closedPL;

   return(!catch("ArchiveClosedPosition(4)"));
}


/**
 * Whether a stop condition is satisfied for a progressing sequence.
 *
 * @param  _Out_ int &signal - variable receiving the identifier of a satisfied condition
 *
 * @return bool
 */
bool IsStopSignal(int &signal) {
   signal = NULL;
   if (last_error || (sequence.status!=STATUS_WAITING && sequence.status!=STATUS_PROGRESSING)) return(false);

   // stop.time: satisfied at/after the specified time ----------------------------------------------------------------------
   if (stop.time.condition) {
      datetime now = TimeServer();
      if (stop.time.isDaily) /*&&*/ if (stop.time.value < 1*DAY) {
         stop.time.value += (now - (now % DAY));
         if (stop.time.value < now) stop.time.value += 1*DAY;        // set periodic value to the next time in the future
      }
      if (now >= stop.time.value) {
         signal = SIGNAL_TIME;
         return(true);
      }
   }

   if (sequence.status == STATUS_PROGRESSING) {
      // stop.profitAbs: ----------------------------------------------------------------------------------------------------
      if (stop.profitAbs.condition) {
         if (sequence.totalPL >= stop.profitAbs.value) {
            if (IsLogNotice()) logNotice("IsStopSignal(2)  "+ sequence.name +" stop condition \"@"+ stop.profitAbs.description +"\" satisfied (market: "+ NumberToStr(Bid, PriceFormat) +"/"+ NumberToStr(Ask, PriceFormat) +")");
            signal = SIGNAL_TAKEPROFIT;
            return(true);
         }
      }

      // stop.profitPct: ----------------------------------------------------------------------------------------------------
      if (stop.profitPct.condition) {
         if (stop.profitPct.absValue == INT_MAX)
            stop.profitPct.absValue = stop.profitPct.AbsValue();

         if (sequence.totalPL >= stop.profitPct.absValue) {
            if (IsLogNotice()) logNotice("IsStopSignal(3)  "+ sequence.name +" stop condition \"@"+ stop.profitPct.description +"\" satisfied (market: "+ NumberToStr(Bid, PriceFormat) +"/"+ NumberToStr(Ask, PriceFormat) +")");
            signal = SIGNAL_TAKEPROFIT;
            return(true);
         }
      }

      // stop.profitPip: ----------------------------------------------------------------------------------------------------
      if (stop.profitPip.condition) {
         return(!catch("IsStopSignal(4)  stop.profitPip.condition not implemented", ERR_NOT_IMPLEMENTED));
      }
   }
   return(false);
}


/**
 * Return the absolute value of a percentage type TakeProfit condition.
 *
 * @return double - absolute value or INT_MAX if no percentage TakeProfit was configured
 */
double stop.profitPct.AbsValue() {
   if (stop.profitPct.condition) {
      if (stop.profitPct.absValue == INT_MAX) {
         double startEquity = sequence.startEquity;
         if (!startEquity) startEquity = AccountEquity() - AccountCredit() + GetExternalAssets();
         return(stop.profitPct.value/100 * startEquity);
      }
   }
   return(stop.profitPct.absValue);
}


/**
 * Stop a waiting or progressing sequence. Close open positions (if any).
 *
 * @param  int signal - signal which triggered the stop condition or NULL on explicit (i.e. manual) stop
 *
 * @return bool - success status
 */
bool StopSequence(int signal) {
   if (last_error != NULL)                                                     return(false);
   if (sequence.status!=STATUS_WAITING && sequence.status!=STATUS_PROGRESSING) return(!catch("StopSequence(1)  "+ sequence.name +" cannot stop "+ StatusDescription(sequence.status) +" sequence", ERR_ILLEGAL_STATE));

   if (sequence.status == STATUS_PROGRESSING) {
      if (open.ticket > 0) {                                // a progressing sequence may have an open position to close
         if (IsLogInfo()) logInfo("StopSequence(2)  "+ sequence.name +" stopping... ("+ SignalToStr(signal) +")");

         int oeFlags, oe[];
         if (!OrderCloseEx(open.ticket, NULL, Slippage, CLR_NONE, oeFlags, oe))                                     return(!SetLastError(oe.Error(oe)));
         if (!ArchiveClosedPosition(open.ticket, open.signal, NormalizeDouble(open.slippage - oe.Slippage(oe), 1))) return(false);

         sequence.maxProfit   = MathMax(sequence.maxProfit, sequence.totalPL);
         sequence.maxDrawdown = MathMin(sequence.maxDrawdown, sequence.totalPL);
         SS.TotalPL();
         SS.PLStats();
      }
   }

   // update stop conditions and status
   switch (signal) {
      case SIGNAL_TIME:
         start.time.condition = start.time.isDaily;
         if (start.time.isDaily) start.time.value %= DAYS;
         stop.time.condition  = false;
         sequence.status      = ifInt(start.time.isDaily, STATUS_WAITING, STATUS_STOPPED);
         break;

      case SIGNAL_TAKEPROFIT:
         stop.profitAbs.condition = false;
         stop.profitPct.condition = false;
         stop.profitPip.condition = false;
         sequence.status          = STATUS_STOPPED;
         break;

      case NULL:                                            // explicit stop (manual) or end of test
         break;

      default: return(!catch("StopSequence(3)  "+ sequence.name +" invalid parameter signal: "+ signal, ERR_INVALID_PARAMETER));
   }
   SS.StartStopConditions();

   if (IsLogInfo()) logInfo("StopSequence(4)  "+ sequence.name +" "+ ifString(IsTesting() && !signal, "test ", "") +"sequence stopped"+ ifString(!signal, "", " ("+ SignalToStr(signal) +")") +", profit: "+ sSequenceTotalPL +" "+ StrReplace(sSequencePlStats, " ", ""));
   SaveStatus();

   if (IsTesting() && sequence.status == STATUS_STOPPED) {  // pause or stop the tester according to the debug configuration
      if (!IsVisualMode())       Tester.Stop ("StopSequence(5)");
      else if (test.onStopPause) Tester.Pause("StopSequence(6)");
   }
   return(!catch("StopSequence(7)"));
}


/**
 * Update order status and PL.
 *
 * @return bool - success status
 */
bool UpdateStatus() {
   if (last_error != NULL)                    return(false);
   if (sequence.status != STATUS_PROGRESSING) return(!catch("UpdateStatus(1)  "+ sequence.name +" cannot update order status of "+ StatusDescription(sequence.status) +" sequence", ERR_ILLEGAL_STATE));
   int error;

   if (open.ticket > 0) {
      if (!SelectTicket(open.ticket, "UpdateStatus(2)")) return(false);
      bool isOpen   = !OrderCloseTime();
      bool isClosed = !isOpen;

      open.swap       = OrderSwap();
      open.commission = OrderCommission();
      open.profit     = OrderProfit();

      if (isOpen) {
         sequence.openPL = NormalizeDouble(open.swap + open.commission + open.profit, 2);
      }
      else {
         if (IsError(onPositionClose("UpdateStatus(3)  "+ sequence.name +" "+ UpdateStatus.PositionCloseMsg(error), error))) return(false);
         if (!ArchiveClosedPosition(open.ticket, open.signal, open.slippage)) return(false);
      }
      sequence.totalPL = NormalizeDouble(sequence.openPL + sequence.closedPL, 2); SS.TotalPL();

      if      (sequence.totalPL > sequence.maxProfit  ) { sequence.maxProfit   = sequence.totalPL; SS.PLStats(); }
      else if (sequence.totalPL < sequence.maxDrawdown) { sequence.maxDrawdown = sequence.totalPL; SS.PLStats(); }
   }
   return(!catch("UpdateStatus(4)"));
}


/**
 * Compose a log message for a closed open position. The ticket is  selected.
 *
 * @param  _Out_ int error - error code to be returned from the call (if any)
 *
 * @return string - log message or an empty string in case of errors
 */
string UpdateStatus.PositionCloseMsg(int &error) {
   // #1 Sell 0.1 GBPUSD at 1.5457'2 ("Z.8692") was [unexpectedly ]closed at 1.5457'2 (market: Bid/Ask[, so: 47.7%/169.20/354.40])
   error = NO_ERROR;

   int    ticket     = OrderTicket();
   int    type       = OrderType();
   double lots       = OrderLots();
   double openPrice  = OrderOpenPrice();
   double closePrice = OrderClosePrice();

   string sType       = OperationTypeDescription(type);
   string sOpenPrice  = NumberToStr(openPrice, PriceFormat);
   string sClosePrice = NumberToStr(closePrice, PriceFormat);
   string comment     = sequence.name;
   string unexpected  = ifString(!IsTesting() || __CoreFunction!=CF_DEINIT, "unexpectedly ", "");
   string message     = "#"+ ticket +" "+ sType +" "+ NumberToStr(lots, ".+") +" "+ OrderSymbol() +" at "+ sOpenPrice +" (\""+ comment +"\") was "+ unexpected +"closed at "+ sClosePrice;
   string sStopout    = "";

   if (StrStartsWithI(OrderComment(), "so:")) {
      sStopout = ", "+ OrderComment();
      error = ERR_MARGIN_STOPOUT;
   }
   else if (!IsTesting() || __CoreFunction!=CF_DEINIT) {
      error = ERR_CONCURRENT_MODIFICATION;
   }
   return(message +" (market: "+ NumberToStr(Bid, PriceFormat) +"/"+ NumberToStr(Ask, PriceFormat) + sStopout +")");
}


/**
 * Error handler for unexpected closing of the current position.
 *
 * @param  string message - error message
 * @param  int    error   - error code
 *
 * @return int - error status, i.e. whether to interrupt program execution
 */
int onPositionClose(string message, int error) {
   if (!error)      return(logInfo(message));         // no error
   if (IsTesting()) return(catch(message, error));    // treat everything as a terminating error

   logError(message, error);                          // online
   if (error == ERR_CONCURRENT_MODIFICATION)          // most probably manually closed
      return(NO_ERROR);                               // continue
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
   if (id < 1000 || id > 9999)                  return(!catch("CalculateMagicNumber(2)  "+ sequence.name +" illegal sequence id: "+ id, ERR_ILLEGAL_STATE));

   int strategy = STRATEGY_ID;                              //  101-1023 (10 bit)
   int sequence = id;                                       // 1000-9999 (14 bit)

   return((strategy<<22) + (sequence<<8));                  // the remaining 8 bit are not used in this strategy
}


/**
 * Generate a new sequence id. Must be unique for all instances of this strategy.
 *
 * @return int - sequence id in the range of 1000-9999 or NULL in case of errors
 */
int CreateSequenceId() {
   MathSrand(GetTickCount()-__ExecutionContext[EC.hChartWindow]);
   int sequenceId, magicNumber;

   while (!magicNumber) {
      while (sequenceId < SID_MIN || sequenceId > SID_MAX) {
         sequenceId = MathRand();                                 // TODO: generate consecutive ids in tester
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


// recorded PL metrics
#define METRIC_TOTAL_PL_MONEY    0
#define METRIC_TOTAL_PL_PIP      1
#define METRIC_DAILY_PL_MONEY    2
#define METRIC_DAILY_PL_PIP      3


/**
 * Return symbol definitions for metrics to be recorded by this instance.
 *
 * @param  _In_  int    i            - zero-based index of the timeseries (position in the recorder)
 * @param  _Out_ bool   enabled      - whether the metric is active and recorded
 * @param  _Out_ string symbol       - unique timeseries symbol
 * @param  _Out_ string symbolDescr  - timeseries description
 * @param  _Out_ string symbolGroup  - timeseries group (if empty recorder defaults are used)
 * @param  _Out_ int    symbolDigits - timeseries digits
 * @param  _Out_ string hstDirectory - history directory of the timeseries (if empty recorder defaults are used)
 * @param  _Out_ int    hstFormat    - history format of the timeseries (if empty recorder defaults are used)
 *
 * @return bool - whether to add a definition for the specified index
 */
bool Recorder_GetSymbolDefinitionA(int i, bool &enabled, string &symbol, string &symbolDescr, string &symbolGroup, int &symbolDigits, string &hstDirectory, int &hstFormat) {
   if (IsLastError())    return(false);
   if (!sequence.id)     return(!catch("Recorder_GetSymbolDefinitionA(1)  "+ sequence.name +" illegal sequence id: "+ sequence.id, ERR_ILLEGAL_STATE));
   if (IsTestSequence()) return(false);

   switch (i) {
      case METRIC_TOTAL_PL_MONEY:
         enabled      = true;
         symbol       = "ZigZg_"+ sequence.id +"A";
         symbolDescr  = Symbol() +", total PL in "+ AccountCurrency();
         symbolGroup  = "";
         symbolDigits = 2;
         hstDirectory = "";
         hstFormat    = NULL;
         break;

      default: return(false);
   }
   return(true);

   /*
   old: "ZigZag"+ sequence.id
   Duel_1234A
   Snow_1234A
   */
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
      string directory = "presets/"+ ifString(IsTestSequence(), "Tester", GetAccountCompany()) +"/";
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
 * Return a human-readable presentation of a signal constant.
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

   // in tester skip most status file writes, except at creation, sequence stop and test end
   if (IsTesting() && test.optimizeStatus) {
      static bool saved = false;
      if (saved && sequence.status!=STATUS_STOPPED && __CoreFunction!=CF_DEINIT) return(true);
      saved = true;
   }

   string section="", separator="", file=GetStatusFilename();
   if (!IsFile(file, MODE_SYSTEM)) separator = CRLF;             // an empty line as additional section separator

   // [General]
   section = "General";
   WriteIniString(file, section, "Account", GetAccountCompany() +":"+ GetAccountNumber());
   WriteIniString(file, section, "Symbol",  Symbol());
   WriteIniString(file, section, "Created", GmtTimeFormat(sequence.created, "%a, %Y.%m.%d %H:%M:%S") + separator);

   // [Inputs]
   section = "Inputs";
   WriteIniString(file, section, "Sequence.ID",                 /*string*/ Sequence.ID);
   WriteIniString(file, section, "ZigZag.Periods",              /*int   */ ZigZag.Periods);
   WriteIniString(file, section, "Lots",                        /*double*/ NumberToStr(Lots, ".+"));
   WriteIniString(file, section, "StartConditions",             /*string*/ SaveStatus.ConditionsToStr(sStartConditions));   // contains only active conditions
   WriteIniString(file, section, "StopConditions",              /*string*/ SaveStatus.ConditionsToStr(sStopConditions));    // contains only active conditions
   WriteIniString(file, section, "TakeProfit",                  /*double*/ NumberToStr(TakeProfit, ".+"));
   WriteIniString(file, section, "TakeProfit.Type",             /*string*/ TakeProfit.Type);
   WriteIniString(file, section, "Slippage",                    /*int   */ Slippage);
   WriteIniString(file, section, "ShowProfitInPercent",         /*bool  */ ShowProfitInPercent + separator);

   // [Runtime status]
   section = "Runtime status";                                  // On deletion of pending orders the number of stored order records decreases. To prevent
   EmptyIniSectionA(file, section);                             // orphaned status file records the section is emptied before writing to it.

   // sequence data
   WriteIniString(file, section, "sequence.id",                 /*int     */ sequence.id);
   WriteIniString(file, section, "sequence.created",            /*datetime*/ sequence.created + GmtTimeFormat(sequence.created, " (%a, %Y.%m.%d %H:%M:%S)"));
   WriteIniString(file, section, "sequence.isTest",             /*bool    */ sequence.isTest);
   WriteIniString(file, section, "sequence.name",               /*string  */ sequence.name);
   WriteIniString(file, section, "sequence.status",             /*int     */ sequence.status);
   WriteIniString(file, section, "sequence.startEquity",        /*double  */ DoubleToStr(sequence.startEquity, 2));
   WriteIniString(file, section, "sequence.openPL",             /*double  */ DoubleToStr(sequence.openPL, 2));
   WriteIniString(file, section, "sequence.closedPL",           /*double  */ DoubleToStr(sequence.closedPL, 2));
   WriteIniString(file, section, "sequence.totalPL",            /*double  */ DoubleToStr(sequence.totalPL, 2));
   WriteIniString(file, section, "sequence.maxProfit",          /*double  */ DoubleToStr(sequence.maxProfit, 2));
   WriteIniString(file, section, "sequence.maxDrawdown",        /*double  */ DoubleToStr(sequence.maxDrawdown, 2) + CRLF);

   // open order data
   WriteIniString(file, section, "open.signal",                 /*int     */ open.signal);
   WriteIniString(file, section, "open.ticket",                 /*int     */ open.ticket);
   WriteIniString(file, section, "open.type",                   /*int     */ open.type);
   WriteIniString(file, section, "open.time",                   /*datetime*/ open.time);
   WriteIniString(file, section, "open.price",                  /*double  */ DoubleToStr(open.price, Digits));
   WriteIniString(file, section, "open.slippage",               /*double  */ DoubleToStr(open.slippage, 1));
   WriteIniString(file, section, "open.swap",                   /*double  */ DoubleToStr(open.swap, 2));
   WriteIniString(file, section, "open.commission",             /*double  */ DoubleToStr(open.commission, 2));
   WriteIniString(file, section, "open.profit",                 /*double  */ DoubleToStr(open.profit, 2) + CRLF);

   // closed order data
   int size = ArrayRange(history, 0);
   for (int i=0; i < size; i++) {
      WriteIniString(file, section, "history."+ i, SaveStatus.HistoryToStr(i) + ifString(i+1 < size, "", CRLF));
   }

   // start/stop conditions
   WriteIniString(file, section, "start.time.condition",        /*bool    */ start.time.condition);
   WriteIniString(file, section, "start.time.value",            /*datetime*/ start.time.value);
   WriteIniString(file, section, "start.time.isDaily",          /*bool    */ start.time.isDaily);
   WriteIniString(file, section, "start.time.description",      /*string  */ start.time.description + CRLF);

   WriteIniString(file, section, "stop.time.condition",         /*bool    */ stop.time.condition);
   WriteIniString(file, section, "stop.time.value",             /*datetime*/ stop.time.value);
   WriteIniString(file, section, "stop.time.isDaily",           /*bool    */ stop.time.isDaily);
   WriteIniString(file, section, "stop.time.description",       /*string  */ stop.time.description + CRLF);

   WriteIniString(file, section, "stop.profitAbs.condition",    /*bool    */ stop.profitAbs.condition);
   WriteIniString(file, section, "stop.profitAbs.value",        /*double  */ DoubleToStr(stop.profitAbs.value, 2));
   WriteIniString(file, section, "stop.profitAbs.description",  /*string  */ stop.profitAbs.description);
   WriteIniString(file, section, "stop.profitPct.condition",    /*bool    */ stop.profitPct.condition);
   WriteIniString(file, section, "stop.profitPct.value",        /*double  */ NumberToStr(stop.profitPct.value, ".+"));
   WriteIniString(file, section, "stop.profitPct.absValue",     /*double  */ ifString(stop.profitPct.absValue==INT_MAX, INT_MAX, DoubleToStr(stop.profitPct.absValue, 2)));
   WriteIniString(file, section, "stop.profitPct.description",  /*string  */ stop.profitPct.description);
   WriteIniString(file, section, "stop.profitPip.condition",    /*bool    */ stop.profitPip.condition);
   WriteIniString(file, section, "stop.profitPip.value",        /*double  */ DoubleToStr(stop.profitPip.value, 1));
   WriteIniString(file, section, "stop.profitPip.description",  /*string  */ stop.profitPip.description + CRLF);

   return(!catch("SaveStatus(2)"));
}


/**
 * Return a string representation of only active start/stop conditions to be stored by SaveStatus().
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
      if (!StringLen(expr))              continue;              // skip empty conditions
      if (StringGetChar(expr, 0) == '!') continue;              // skip disabled conditions
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
   // result: signal,ticket,lots,openType,openTime,openPrice,closeTime,closePrice,slippage,swap,commission,profit,totalProfit

   int      signal      = history[index][HI_SIGNAL     ];
   int      ticket      = history[index][HI_TICKET     ];
   double   lots        = history[index][HI_LOTS       ];
   int      openType    = history[index][HI_OPENTYPE   ];
   datetime openTime    = history[index][HI_OPENTIME   ];
   double   openPrice   = history[index][HI_OPENPRICE  ];
   datetime closeTime   = history[index][HI_CLOSETIME  ];
   double   closePrice  = history[index][HI_CLOSEPRICE ];
   double   slippage    = history[index][HI_SLIPPAGE   ];
   double   swap        = history[index][HI_SWAP       ];
   double   commission  = history[index][HI_COMMISSION ];
   double   profit      = history[index][HI_PROFIT     ];
   double   totalProfit = history[index][HI_TOTALPROFIT];

   return(StringConcatenate(signal, ",", ticket, ",", DoubleToStr(lots, 2), ",", openType, ",", openTime, ",", DoubleToStr(openPrice, Digits), ",", closeTime, ",", DoubleToStr(closePrice, Digits), ",", DoubleToStr(slippage, 1), ",", DoubleToStr(swap, 2), ",", DoubleToStr(commission, 2), ",", DoubleToStr(profit, 2), ",", DoubleToStr(totalProfit, 2)));
}


/**
 * Restore the internal state of the EA from a status file. Requires 'sequence.id' and 'sequence.isTest' to be set.
 *
 * @return bool - success status
 */
bool RestoreSequence() {
   if (IsLastError())     return(false);
   if (!ReadStatus())     return(false);                 // read and apply the status file
   if (!ValidateInputs()) return(false);                 // validate restored input parameters
   //if (!SynchronizeStatus()) return(false);            // synchronize restored state with the trade server
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
   string sAccount     = GetIniStringA(file, section, "Account", "");                                 // string Account = ICMarkets:12345678
   string sSymbol      = GetIniStringA(file, section, "Symbol",  "");                                 // string Symbol  = EURUSD
   string sThisAccount = GetAccountCompany() +":"+ GetAccountNumber();
   if (!StrCompareI(sAccount, sThisAccount)) return(!catch("ReadStatus(3)  "+ sequence.name +" account mis-match: "+ DoubleQuoteStr(sThisAccount) +" vs. "+ DoubleQuoteStr(sAccount) +" in status file "+ DoubleQuoteStr(file), ERR_INVALID_CONFIG_VALUE));
   if (!StrCompareI(sSymbol, Symbol()))      return(!catch("ReadStatus(4)  "+ sequence.name +" symbol mis-match: "+ Symbol() +" vs. "+ sSymbol +" in status file "+ DoubleQuoteStr(file), ERR_INVALID_CONFIG_VALUE));

   // [Inputs]
   section = "Inputs";
   string sSequenceID          = GetIniStringA(file, section, "Sequence.ID",         "");             // string Sequence.ID         = T1234
   int    iZigZagPeriods       = GetIniInt    (file, section, "ZigZag.Periods"         );             // int    ZigZag.Periods      = 40
   string sLots                = GetIniStringA(file, section, "Lots",                "");             // double Lots                = 0.1
   string sStartConditions     = GetIniStringA(file, section, "StartConditions",     "");             // string StartConditions     = @time(datetime|time)
   string sStopConditions      = GetIniStringA(file, section, "StopConditions",      "");             // string StopConditions      = @time(datetime|time)
   string sTakeProfit          = GetIniStringA(file, section, "TakeProfit",          "");             // double TakeProfit          = 3.0
   string sTakeProfitType      = GetIniStringA(file, section, "TakeProfit.Type",     "");             // string TakeProfit.Type     = off* | money | percent | pip
   int    iSlippage            = GetIniInt    (file, section, "Slippage"               );             // int    Slippage            = 2
   string sShowProfitInPercent = GetIniStringA(file, section, "ShowProfitInPercent", "");             // bool   ShowProfitInPercent = 1

   if (!StrIsNumeric(sLots))                 return(!catch("ReadStatus(5)  "+ sequence.name +" invalid input parameter Lots "+ DoubleQuoteStr(sLots) +" in status file "+ DoubleQuoteStr(file), ERR_INVALID_FILE_FORMAT));
   if (!StrIsNumeric(sTakeProfit))           return(!catch("ReadStatus(6)  "+ sequence.name +" invalid input parameter TakeProfit "+ DoubleQuoteStr(sTakeProfit) +" in status file "+ DoubleQuoteStr(file), ERR_INVALID_FILE_FORMAT));

   Sequence.ID         = sSequenceID;
   Lots                = StrToDouble(sLots);
   ZigZag.Periods      = iZigZagPeriods;
   StartConditions     = sStartConditions;
   StopConditions      = sStopConditions;
   TakeProfit          = StrToDouble(sTakeProfit);
   TakeProfit.Type     = sTakeProfitType;
   Slippage            = iSlippage;
   ShowProfitInPercent = StrToBool(sShowProfitInPercent);

   // [Runtime status]
   section = "Runtime status";
   // sequence data
   sequence.id          = GetIniInt    (file, section, "sequence.id"         );                       // int      sequence.id          = 1234
   sequence.created     = GetIniInt    (file, section, "sequence.created"    );                       // datetime sequence.created     = 1624924800 (Mon, 2021.05.12 13:22:34)
   sequence.isTest      = GetIniBool   (file, section, "sequence.isTest"     );                       // bool     sequence.isTest      = 1
   sequence.name        = GetIniStringA(file, section, "sequence.name",    "");                       // string   sequence.name        = Z.1234
   sequence.status      = GetIniInt    (file, section, "sequence.status"     );                       // int      sequence.status      = 1
   sequence.startEquity = GetIniDouble (file, section, "sequence.startEquity");                       // double   sequence.startEquity = 1000.00
   sequence.openPL      = GetIniDouble (file, section, "sequence.openPL"     );                       // double   sequence.openPL      = 23.45
   sequence.closedPL    = GetIniDouble (file, section, "sequence.closedPL"   );                       // double   sequence.closedPL    = 45.67
   sequence.totalPL     = GetIniDouble (file, section, "sequence.totalPL"    );                       // double   sequence.totalPL     = 123.45
   sequence.maxProfit   = GetIniDouble (file, section, "sequence.maxProfit"  );                       // double   sequence.maxProfit   = 23.45
   sequence.maxDrawdown = GetIniDouble (file, section, "sequence.maxDrawdown");                       // double   sequence.maxDrawdown = -11.23
   SS.SequenceName();

   // open order data
   open.signal          = GetIniInt    (file, section, "open.signal"    );                            // int      open.signal     = 1
   open.ticket          = GetIniInt    (file, section, "open.ticket"    );                            // int      open.ticket     = 123456
   open.type            = GetIniInt    (file, section, "open.type"      );                            // int      open.type       = 0
   open.time            = GetIniInt    (file, section, "open.time"      );                            // datetime open.time       = 1624924800
   open.price           = GetIniDouble (file, section, "open.price"     );                            // double   open.price      = 1.24363
   open.slippage        = GetIniDouble (file, section, "open.slippage"  );                            // double   open.slippage   = 1.0
   open.swap            = GetIniDouble (file, section, "open.swap"      );                            // double   open.swap       = -1.23
   open.commission      = GetIniDouble (file, section, "open.commission");                            // double   open.commission = -5.50
   open.profit          = GetIniDouble (file, section, "open.profit"    );                            // double   open.profit     = 12.34

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

   stop.profitPip.condition   = GetIniBool   (file, section, "stop.profitPip.condition"        );     // bool     stop.profitPip.condition   = 1
   stop.profitPip.value       = GetIniDouble (file, section, "stop.profitPip.value"            );     // double   stop.profitPip.value       = 10.00
   stop.profitPip.description = GetIniStringA(file, section, "stop.profitPip.description",   "");     // string   stop.profitPip.description = text

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

   // history.i=signal,ticket,lots,openType,openTime,openPrice,closeTime,closePrice,slippage,swap,commission,profit,totalProfit
   string values[];
   string sId = StrRightFrom(key, ".", -1); if (!StrIsDigit(sId))   return(!catch("ReadStatus.ParseHistory(2)  "+ sequence.name +" illegal history record key "+ DoubleQuoteStr(key), ERR_INVALID_FILE_FORMAT));
   int index = StrToInteger(sId);
   if (Explode(value, ",", values, NULL) != ArrayRange(history, 1)) return(!catch("ReadStatus.ParseHistory(3)  "+ sequence.name +" illegal number of details ("+ ArraySize(values) +") in history record", ERR_INVALID_FILE_FORMAT));

   int      signal      = StrToInteger(values[HI_SIGNAL     ]);
   int      ticket      = StrToInteger(values[HI_TICKET     ]);
   double   lots        =  StrToDouble(values[HI_LOTS       ]);
   int      openType    = StrToInteger(values[HI_OPENTYPE   ]);
   datetime openTime    = StrToInteger(values[HI_OPENTIME   ]);
   double   openPrice   =  StrToDouble(values[HI_OPENPRICE  ]);
   datetime closeTime   = StrToInteger(values[HI_CLOSETIME  ]);
   double   closePrice  =  StrToDouble(values[HI_CLOSEPRICE ]);
   double   slippage    =  StrToDouble(values[HI_SLIPPAGE   ]);
   double   swap        =  StrToDouble(values[HI_SWAP       ]);
   double   commission  =  StrToDouble(values[HI_COMMISSION ]);
   double   profit      =  StrToDouble(values[HI_PROFIT     ]);
   double   totalProfit =  StrToDouble(values[HI_TOTALPROFIT]);

   return(History.AddRecord(index, signal, ticket, lots, openType, openTime, openPrice, closeTime, closePrice, slippage, swap, commission, profit, totalProfit));
}


/**
 * Add a record to the history array. Prevents existing data to be overwritten.
 *
 * @param  int index - array index to insert the record
 * @param  ...       - record details
 *
 * @return bool - success status
 */
int History.AddRecord(int index, int signal, int ticket, double lots, int openType, datetime openTime, double openPrice, datetime closeTime, double closePrice, double slippage, double swap, double commission, double profit, double totalProfit) {
   if (index < 0) return(!catch("History.AddRecord(1)  "+ sequence.name +" invalid parameter index: "+ index, ERR_INVALID_PARAMETER));

   int size = ArrayRange(history, 0);
   if (index >= size) ArrayResize(history, index+1);
   if (history[index][HI_TICKET] != 0) return(!catch("History.AddRecord(2)  "+ sequence.name +" invalid parameter index: "+ index +" (cannot overwrite history["+ index +"] record, ticket #"+ history[index][HI_TICKET] +")", ERR_INVALID_PARAMETER));

   history[index][HI_SIGNAL     ] = signal;
   history[index][HI_TICKET     ] = ticket;
   history[index][HI_LOTS       ] = lots;
   history[index][HI_OPENTYPE   ] = openType;
   history[index][HI_OPENTIME   ] = openTime;
   history[index][HI_OPENPRICE  ] = openPrice;
   history[index][HI_CLOSETIME  ] = closeTime;
   history[index][HI_CLOSEPRICE ] = closePrice;
   history[index][HI_SLIPPAGE   ] = slippage;
   history[index][HI_SWAP       ] = swap;
   history[index][HI_COMMISSION ] = commission;
   history[index][HI_PROFIT     ] = profit;
   history[index][HI_TOTALPROFIT] = totalProfit;

   return(!catch("History.AddRecord(3)"));
}


/**
 * Whether the current sequence was created in the tester. Considers that a test sequence can be loaded into an online
 * chart after the test (for visualization).
 *
 * @return bool
 */
bool IsTestSequence() {
   return(sequence.isTest || IsTesting());
}


// backed-up input parameters
string   prev.Sequence.ID = "";
int      prev.ZigZag.Periods;
double   prev.Lots;
string   prev.StartConditions = "";
string   prev.StopConditions = "";
double   prev.TakeProfit;
string   prev.TakeProfit.Type = "";
int      prev.Slippage;
bool     prev.ShowProfitInPercent;

// backed-up runtime variables affected by changing input parameters
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
bool     prev.stop.profitPip.condition;
double   prev.stop.profitPip.value;
string   prev.stop.profitPip.description = "";


/**
 * Programatically changed input parameters don't survive init cycles. Therefore inputs are backed-up in deinit() and can be
 * restored in init(). Called in onDeinitParameters() and onDeinitChartChange().
 */
void BackupInputs() {
   // backup input parameters, also accessed for comparison in ValidateInputs()
   prev.Sequence.ID         = StringConcatenate(Sequence.ID, "");    // string inputs are references to internal C literals and must be copied to break the reference
   prev.ZigZag.Periods      = ZigZag.Periods;
   prev.Lots                = Lots;
   prev.StartConditions     = StringConcatenate(StartConditions, "");
   prev.StopConditions      = StringConcatenate(StopConditions, "");
   prev.TakeProfit          = TakeProfit;
   prev.TakeProfit.Type     = StringConcatenate(TakeProfit.Type, "");
   prev.Slippage            = Slippage;
   prev.ShowProfitInPercent = ShowProfitInPercent;

   // backup runtime variables affected by changing input parameters
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
   prev.stop.profitPip.condition   = stop.profitPip.condition;
   prev.stop.profitPip.value       = stop.profitPip.value;
   prev.stop.profitPip.description = stop.profitPip.description;
}


/**
 * Restore backed-up input parameters and runtime variables. Called from onInitParameters() and onInitTimeframeChange().
 */
void RestoreInputs() {
   // restore input parameters
   Sequence.ID         = prev.Sequence.ID;
   ZigZag.Periods      = prev.ZigZag.Periods;
   Lots                = prev.Lots;
   StartConditions     = prev.StartConditions;
   StopConditions      = prev.StopConditions;
   TakeProfit          = prev.TakeProfit;
   TakeProfit.Type     = prev.TakeProfit.Type;
   Slippage            = prev.Slippage;
   ShowProfitInPercent = prev.ShowProfitInPercent;

   // restore runtime variables
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
   stop.profitPip.condition   = prev.stop.profitPip.condition;
   stop.profitPip.value       = prev.stop.profitPip.value;
   stop.profitPip.description = prev.stop.profitPip.description;
}


/**
 * Syntactically validate and restore a specified sequence id (format: /T?[0-9]{4}/). Called only from onInitUser().
 *
 * @return bool - whether the id was valid and 'sequence.id'/'sequence.isTest' were restored (the status file is not checked)
 */
bool ValidateInputs.SID() {
   string sValue = StrTrim(Sequence.ID);
   if (!StringLen(sValue)) return(false);

   if (StrStartsWith(sValue, "T")) {
      sequence.isTest = true;
      sValue = StrSubstr(sValue, 1);
   }
   if (!StrIsDigit(sValue))                  return(!onInputError("ValidateInputs.SID(1)  invalid input parameter Sequence.ID: "+ DoubleQuoteStr(Sequence.ID) +" (must be digits only)"));
   int iValue = StrToInteger(sValue);
   if (iValue < SID_MIN || iValue > SID_MAX) return(!onInputError("ValidateInputs.SID(2)  invalid input parameter Sequence.ID: "+ DoubleQuoteStr(Sequence.ID) +" (range error)"));

   sequence.id = iValue;
   Sequence.ID = ifString(IsTestSequence(), "T", "") + sequence.id;
   SS.SequenceName();
   return(true);
}


/**
 * Validate the input parameters. Parameters may have been entered through the input dialog, read from a status file or
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
   if (isInitParameters) {
      string sValues[], sValue=StrTrim(Sequence.ID);
      if (sValue == "") {                                         // the id was deleted or not yet set, re-apply the internal id
         Sequence.ID = prev.Sequence.ID;
      }
      else if (sValue != prev.Sequence.ID)                        return(!onInputError("ValidateInputs(1)  "+ sequence.name +" switching to another sequence is not supported (unload the EA first)"));
   } //else                                                       // the id was validated in ValidateInputs.SID()

   // ZigZag.Periods
   if (isInitParameters && ZigZag.Periods!=prev.ZigZag.Periods) {
      if (sequenceWasStarted)                                     return(!onInputError("ValidateInputs(2)  "+ sequence.name +" cannot change input parameter ZigZag.Periods of "+ StatusDescription(sequence.status) +" sequence"));
   }
   if (ZigZag.Periods < 2)                                        return(!onInputError("ValidateInputs(3)  "+ sequence.name +" invalid input parameter ZigZag.Periods: "+ ZigZag.Periods));

   // Lots
   if (isInitParameters && NE(Lots, prev.Lots)) {
      if (sequenceWasStarted)                                     return(!onInputError("ValidateInputs(4)  "+ sequence.name +" cannot change input parameter Lots of "+ StatusDescription(sequence.status) +" sequence"));
   }
   if (LT(Lots, 0))                                               return(!onInputError("ValidateInputs(5)  "+ sequence.name +" invalid input parameter Lots: "+ NumberToStr(Lots, ".1+") +" (too small)"));
   if (NE(Lots, NormalizeLots(Lots)))                             return(!onInputError("ValidateInputs(6)  "+ sequence.name +" invalid input parameter Lots: "+ NumberToStr(Lots, ".1+") +" (not a multiple of MODE_LOTSTEP="+ NumberToStr(MarketInfo(Symbol(), MODE_LOTSTEP), ".+") +")"));

   // StartConditions: @time(datetime|time)
   if (!isInitParameters || StartConditions!=prev.StartConditions) {
      start.time.condition = false;                               // on initParameters conditions are re-enabled on change only

      string exprs[], expr="", key="";                            // split conditions
      int sizeOfExprs = Explode(StartConditions, "|", exprs, NULL), iValue, time, sizeOfElems;

      for (int i=0; i < sizeOfExprs; i++) {                       // validate each expression
         expr = StrTrim(exprs[i]);
         if (!StringLen(expr))              continue;
         if (StringGetChar(expr, 0) == '!') continue;             // skip disabled conditions
         if (StringGetChar(expr, 0) != '@')                       return(!onInputError("ValidateInputs(7)  invalid input parameter StartConditions: "+ DoubleQuoteStr(StartConditions)));

         if (Explode(expr, "(", sValues, NULL) != 2)              return(!onInputError("ValidateInputs(8)  invalid input parameter StartConditions: "+ DoubleQuoteStr(StartConditions)));
         if (!StrEndsWith(sValues[1], ")"))                       return(!onInputError("ValidateInputs(9)  invalid input parameter StartConditions: "+ DoubleQuoteStr(StartConditions)));
         key = StrTrim(sValues[0]);
         sValue = StrTrim(StrLeft(sValues[1], -1));
         if (!StringLen(sValue))                                  return(!onInputError("ValidateInputs(10)  invalid input parameter StartConditions: "+ DoubleQuoteStr(StartConditions)));

         if (key == "@time") {
            if (start.time.condition)                             return(!onInputError("ValidateInputs(11)  invalid input parameter StartConditions: "+ DoubleQuoteStr(StartConditions) +" (multiple time conditions)"));
            int pt[];
            if (!ParseTime(sValue, NULL, pt))                     return(!onInputError("ValidateInputs(12)  invalid input parameter StartConditions: "+ DoubleQuoteStr(StartConditions)));
            start.time.value       = DateTime2(pt, DATE_OF_ERA);
            start.time.isDaily     = !pt[PT_HAS_DATE];
            start.time.description = "time("+ TimeToStr(start.time.value, ifInt(start.time.isDaily, TIME_MINUTES, TIME_DATE|TIME_MINUTES)) +")";
            start.time.condition   = true;
         }
         else                                                     return(!onInputError("ValidateInputs(13)  invalid input parameter StartConditions: "+ DoubleQuoteStr(StartConditions)));
      }
   }

   // StopConditions: @time(datetime|time)
   if (!isInitParameters || StartConditions!=prev.StartConditions) {
      stop.time.condition = false;                                // on initParameters conditions are re-enabled on change only

      sizeOfExprs = Explode(StopConditions, "|", exprs, NULL);    // split conditions

      for (i=0; i < sizeOfExprs; i++) {                           // validate each expression
         expr = StrTrim(exprs[i]);
         if (!StringLen(expr))              continue;
         if (StringGetChar(expr, 0) == '!') continue;             // skip disabled conditions
         if (StringGetChar(expr, 0) != '@')                       return(!onInputError("ValidateInputs(7)  invalid input parameter StopConditions: "+ DoubleQuoteStr(StopConditions)));

         if (Explode(expr, "(", sValues, NULL) != 2)              return(!onInputError("ValidateInputs(8)  invalid input parameter StopConditions: "+ DoubleQuoteStr(StopConditions)));
         if (!StrEndsWith(sValues[1], ")"))                       return(!onInputError("ValidateInputs(9)  invalid input parameter StopConditions: "+ DoubleQuoteStr(StopConditions)));
         key = StrTrim(sValues[0]);
         sValue = StrTrim(StrLeft(sValues[1], -1));
         if (!StringLen(sValue))                                  return(!onInputError("ValidateInputs(10)  invalid input parameter StopConditions: "+ DoubleQuoteStr(StopConditions)));

         if (key == "@time") {
            if (stop.time.condition)                              return(!onInputError("ValidateInputs(11)  invalid input parameter StopConditions: "+ DoubleQuoteStr(StopConditions) +" (multiple time conditions)"));
            if (!ParseTime(sValue, NULL, pt))                     return(!onInputError("ValidateInputs(12)  invalid input parameter StopConditions: "+ DoubleQuoteStr(StopConditions)));
            stop.time.value       = DateTime2(pt, DATE_OF_ERA);
            stop.time.isDaily     = !pt[PT_HAS_DATE];
            stop.time.description = "time("+ TimeToStr(stop.time.value, ifInt(stop.time.isDaily, TIME_MINUTES, TIME_DATE|TIME_MINUTES)) +")";
            stop.time.condition   = true;
         }
         else                                                     return(!onInputError("ValidateInputs(13)  invalid input parameter StopConditions: "+ DoubleQuoteStr(StopConditions)));
      }
   }

   // TakeProfit (nothing to do)
   // TakeProfit.Type
   sValue = StrToLower(TakeProfit.Type);
   if (Explode(sValue, "*", sValues, 2) > 1) {
      int size = Explode(sValues[0], "|", sValues, NULL), type;
      sValue = sValues[size-1];
   }
   sValue = StrTrim(sValue);
   if      (StrStartsWith("off",     sValue)) type = NULL;
   else if (StrStartsWith("money",   sValue)) type = TP_TYPE_MONEY;
   else if (StringLen(sValue) < 2)                                return(!onInputError("ValidateInputs(14)  invalid parameter TakeProfit.Type: "+ DoubleQuoteStr(TakeProfit.Type)));
   else if (StrStartsWith("percent", sValue)) type = TP_TYPE_PERCENT;
   else if (StrStartsWith("pip",     sValue)) type = TP_TYPE_PIP;
   else                                                           return(!onInputError("ValidateInputs(15)  invalid parameter TakeProfit.Type: "+ DoubleQuoteStr(TakeProfit.Type)));
   stop.profitAbs.condition   = false;
   stop.profitAbs.description = "";
   stop.profitPct.condition   = false;
   stop.profitPct.description = "";
   stop.profitPip.condition   = false;
   stop.profitPip.description = "";

   switch (type) {
      case TP_TYPE_MONEY:
         stop.profitAbs.condition   = true;
         stop.profitAbs.value       = NormalizeDouble(TakeProfit, 2);
         stop.profitAbs.description = "profit("+ DoubleToStr(stop.profitAbs.value, 2) +")";
         break;

      case TP_TYPE_PERCENT:
         stop.profitPct.condition   = true;
         stop.profitPct.value       = TakeProfit;
         stop.profitPct.absValue    = INT_MAX;
         stop.profitPct.description = "profit("+ NumberToStr(stop.profitPct.value, ".+") +"%)";
         break;

      case TP_TYPE_PIP:
         stop.profitPip.condition   = true;
         stop.profitPip.value       = NormalizeDouble(TakeProfit, 1);
         stop.profitPip.description = "profit("+ NumberToStr(stop.profitPip.value, ".+") +" pip)";
         break;
   }
   TakeProfit.Type = tpTypeDescriptions[type];

   return(!catch("ValidateInputs(16)"));
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
      return(logError(message, error));            // non-terminating
   return(catch(message, error));                  // terminating
}


/**
 * Store the current sequence id in the chart (for template changes, terminal restart, recompilation etc).
 *
 * @return bool - success status
 */
bool StoreSequenceId() {
   if (!__isChart) return(false);
   return(Chart.StoreString(ProgramName() +".Sequence.ID", sequence.id));
}


/**
 * Restore a sequence id found in the chart (for template changes, terminal restart, recompilation etc).
 *
 * @return bool - whether a sequence id was successfully restored
 */
bool FindSequenceId() {
   string sValue = "";

   if (Chart.RestoreString(ProgramName() +".Sequence.ID", sValue)) {
      bool isTest = false;

      if (StrStartsWith(sValue, "T")) {
         isTest = true;
         sValue = StrSubstr(sValue, 1);
      }
      if (StrIsDigit(sValue)) {
         int iValue = StrToInteger(sValue);
         if (iValue > 0) {
            sequence.id     = iValue;
            sequence.isTest = isTest;
            Sequence.ID     = ifString(isTest, "T", "") + sequence.id;
            SS.SequenceName();
            return(true);
         }
      }
   }
   return(false);
}


/**
 * Remove stored sequence data from the chart.
 *
 * @return bool - success status
 */
bool RemoveSequenceData() {
   if (!__isChart) return(false);

   string label = ProgramName() +".status";
   if (ObjectFind(label) != -1)
      ObjectDelete(label);
   Chart.RestoreString(ProgramName() +".Sequence.ID", label);
   return(true);
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
      if (stop.profitPip.description != "") {
         sValue = sValue + ifString(sValue=="", "", " | ") + ifString(stop.profitPip.condition, "@", "!") + stop.profitPip.description;
      }
      if (sValue == "") sStopConditions = "-";
      else              sStopConditions = sValue;
   }
}


/**
 * ShowStatus: Update the string representation of "sequence.totalPL".
 */
void SS.TotalPL() {
   if (__isChart) {
      // not before a position was opened
      if (!open.ticket && !ArrayRange(history, 0)) sSequenceTotalPL = "-";
      else if (ShowProfitInPercent)                sSequenceTotalPL = NumberToStr(MathDiv(sequence.totalPL, sequence.startEquity) * 100, "+.2") +"%";
      else                                         sSequenceTotalPL = NumberToStr(sequence.totalPL, "+.2");
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
         string sSequenceMaxProfit="", sSequenceMaxDrawdown="";
         if (ShowProfitInPercent) {
            sSequenceMaxProfit   = NumberToStr(MathDiv(sequence.maxProfit, sequence.startEquity) * 100, "+.2") +"%";
            sSequenceMaxDrawdown = NumberToStr(MathDiv(sequence.maxDrawdown, sequence.startEquity) * 100, "+.2") +"%";
         }
         else {
            sSequenceMaxProfit   = NumberToStr(sequence.maxProfit, "+.2");
            sSequenceMaxDrawdown = NumberToStr(sequence.maxDrawdown, "+.2");
         }
         sSequencePlStats = StringConcatenate("(", sSequenceMaxProfit, " / ", sSequenceMaxDrawdown, ")");
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

   string text = StringConcatenate(ProgramName(), "    ", sStatus, sError,                 NL,
                                                                                           NL,
                                  "Lots:      ", sLots,                                    NL,
                                  "Start:    ",  sStartConditions,                         NL,
                                  "Stop:     ",  sStopConditions,                          NL,
                                  "Profit:   ",  sSequenceTotalPL, "  ", sSequencePlStats, NL
   );

   // 3 lines margin-top for instrument and indicator legends
   Comment(NL, NL, NL, text);
   if (__CoreFunction == CF_INIT) WindowRedraw();

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
   return(StringConcatenate("Sequence.ID=",         DoubleQuoteStr(Sequence.ID),     ";", NL,
                            "ZigZag.Periods=",      ZigZag.Periods,                  ";", NL,
                            "Lots=",                NumberToStr(Lots, ".1+"),        ";", NL,
                            "StartConditions=",     DoubleQuoteStr(StartConditions), ";", NL,
                            "StopConditions=",      DoubleQuoteStr(StopConditions),  ";", NL,
                            "TakeProfit=",          NumberToStr(TakeProfit, ".1+"),  ";", NL,
                            "TakeProfit.Type=",     DoubleQuoteStr(TakeProfit.Type), ";", NL,
                            "Slippage=",            Slippage,                        ";", NL,
                            "ShowProfitInPercent=", BoolToStr(ShowProfitInPercent),  ";")
   );
}
