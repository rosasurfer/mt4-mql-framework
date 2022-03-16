/**
 * ZigZag EA
 *
 *
 * Input parameters:
 * -----------------
 * • EA.Recorder:  Recorded metrics, one of "on", "off" or a combination of custom metric identifiers (separated by comma).
 *    "off": Nothing is recorded.
 *    "on":  Records a single timeseries depicting the EA's equity graph after all costs.
 *
 *    "1":   Records a timeseries depicting cumulated PL after all costs in account currency (same as "on" except base value).   OK
 *    "2":   Records a timeseries depicting cumulated PL before all costs (zero spread and slippage) in quote units.
 *    "3":   Records a timeseries depicting cumulated PL after spread but before all other costs in quote units.                 OK
 *    "4":   Records a timeseries depicting cumulated PL after all costs in quote units.                                         OK
 *
 *    "5":   Records a timeseries depicting daily PL after all costs in account currency.
 *    "6":   Records a timeseries depicting daily PL before all costs (zero spread and slippage) in quote units.
 *    "7":   Records a timeseries depicting daily PL after spread but before all other costs in quote units.
 *    "8":   Records a timeseries depicting daily PL after all costs in quote units.
 *
 *    The term "quote units" refers to the best matching unit. One of pip, quote currency (QC) or index point (IP).
 *
 *
 * TODO:
 *  - stable forward performance tracking
 *    - recording of PL variants
 *       daily PL in money w/costs
 *       cumulated/daily PL in pip with and w/o costs (spread, commission, swap, slippage)
 *       add quote unit multiplicator
 *    - move validation of custom "EA.Recorder" to EA
 *    - system variants:
 *       Reverse ZigZag
 *       full session (24h) with trade breaks
 *       partial session (e.g. 09:00-16:00) with trade breaks
 *    - reverse trading option "ZigZag.R" (and Turtle Soup)
 *
 *  - status display
 *     parameter: ZigZag.Periods
 *     current position
 *     current spread
 *     number of trades
 *     total commission
 *     track and display total slippage
 *     recorded symbols with descriptions
 *
 *  - input parameter ZigZag.Timeframe
 *  - ChartInfos: read/display symbol description as long name
 *  - ChartInfos: fix display of symbol with Digits=1 (pip)
 *
 *  - StopSequence(): shift periodic start time to the next trading session (not only to next day)
 *
 *  - implement RestoreSequence()->SynchronizeStatus() to handle a lost/open position
 *  - stop condition "pip"
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
 *  - onInitTemplate error on VM restart
 *     INFO   ZigZag EA::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
 *            ZigZag EA::initTemplate(0)  inputs: Sequence.ID="6471";...
 *     FATAL  ZigZag EA::start(9)  [ERR_ILLEGAL_STATE]
 *
 *  - improve handling of network outages (price and/or trade connection)
 *  - "no connection" event, no price feed for 5 minutes, a signal in this time was not detected => EA out of sync
 *
 *  - two ZigZag reversals during the same bar are not recognized and ignored
 *  - reduce slippage on reversal: replace Close+Open by Hedge+CloseBy
 *  - input option to pick-up the last signal on start
 *  - remove input Slippage and handle it dynamically (e.g. via framework config)
 *     https://www.mql5.com/en/forum/120795
 *     https://www.mql5.com/en/forum/289014#comment_9296322
 *     https://www.mql5.com/en/forum/146808#comment_3701979  [ECN restriction removed since build 500]
 *     https://www.mql5.com/en/forum/146808#comment_3701981  [query execution mode in MQL]
 *  - merge inputs TakeProfit and StopConditions
 *  - add cache parameter to HistorySet.AddTick(), e.g. 30 sec.
 *
 *  - fix log messages in ValidateInputs (conditionally display the sequence name)
 *  - CLI tools to rename/update/delete symbols
 *  - CLI tools to shift/scale histories
 *  - implement GetAccountCompany() and read the name from the server file if not connected
 *  - permanent spread logging to a separate logfile
 *  - move all history functionality to the Expander
 *  - pass EA.Recorder to the Expander as a string
 *  - build script for all .ex4 files after deployment
 *  - ToggleOpenOrders() works only after ToggleHistory()
 *  - ChartInfos::onPositionOpen() doesn't log slippage
 *  - ChartInfos::CostumPosition() weekend configuration/timespans don't work
 *  - ChartInfos::CostumPosition() including/excluding a specific strategy is not supported
 *  - reverse sign of oe.Slippage() and fix unit in log messages (pip/money)
 *  - on restart delete dead screen sockets
 */
#include <stddefines.mqh>
int   __InitFlags[] = {INIT_PIPVALUE, INIT_BUFFERED_LOG};
int __DeinitFlags[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern string Sequence.ID         = "";                              // instance to load from a status file, format /T?[0-9]{3}/
extern int    ZigZag.Periods      = 40;

extern double Lots                = 0.1;
extern string StartConditions     = "";                              // @time(datetime|time)
extern string StopConditions      = "";                              // @time(datetime|time)
extern double TakeProfit          = 0;                               // TP value
extern string TakeProfit.Type     = "off* | money | percent | pip";  // can be shortened as long as it's distinct
extern int    Slippage            = 2;                               // in point

extern bool   ShowProfitInPercent = true;                            // whether PL is displayed in money or percentage terms

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/expert.mqh>
#include <stdfunctions.mqh>
#include <rsfLib.mqh>
#include <functions/ParseTime.mqh>
#include <structs/rsf/OrderExecution.mqh>

#define STRATEGY_ID                  107        // unique strategy id between 101-1023 (10 bit)

#define SID_MIN                      100        // valid range of sequence id values
#define SID_MAX                      999

#define STATUS_WAITING                 1        // sequence status values
#define STATUS_PROGRESSING             2
#define STATUS_STOPPED                 3

#define SIGNAL_LONG  TRADE_DIRECTION_LONG       // 1 start/stop/resume signal types
#define SIGNAL_SHORT TRADE_DIRECTION_SHORT      // 2
#define SIGNAL_TIME                    3
#define SIGNAL_TAKEPROFIT              4

#define HI_SIGNAL                      0        // order history indexes
#define HI_TICKET                      1
#define HI_LOTS                        2
#define HI_OPENTYPE                    3
#define HI_OPENTIME                    4
#define HI_OPENPRICE                   5
#define HI_CLOSETIME                   6
#define HI_CLOSEPRICE                  7
#define HI_SLIPPAGE                    8
#define HI_SWAP                        9
#define HI_COMMISSION                 10
#define HI_GROSS_PROFIT               11
#define HI_NET_PROFIT                 12

#define TP_TYPE_MONEY                  1        // TakeProfit types
#define TP_TYPE_PERCENT                2
#define TP_TYPE_PIP                    3

#define METRIC_CUMULATED_MONEY_NET     0        // available PL metrics
#define METRIC_CUMULATED_UNITS_ZERO    1
#define METRIC_CUMULATED_UNITS_GROSS   2
#define METRIC_CUMULATED_UNITS_NET     3
#define METRIC_DAILY_MONEY_NET         4
#define METRIC_DAILY_UNITS_ZERO        5
#define METRIC_DAILY_UNITS_GROSS       6
#define METRIC_DAILY_UNITS_NET         7

// sequence data
int      sequence.id;                           // instance id between 100-999
datetime sequence.created;
bool     sequence.isTest;                       // whether the sequence is a test
string   sequence.name = "";
int      sequence.status;
double   sequence.startEquityM;                 // M: in account currency

double   sequence.openGrossProfitU;             // U: in quote units (price unit)
double   sequence.closedGrossProfitU;
double   sequence.totalGrossProfitU;            // openGrossProfitU + closedGrossProfitU

double   sequence.openNetProfitU;
double   sequence.closedNetProfitU;
double   sequence.totalNetProfitU;              // openNetProfitU + closedNetProfitU

double   sequence.openNetProfitM;
double   sequence.closedNetProfitM;
double   sequence.totalNetProfitM;              // openNetProfitM + closedNetProfitM

double   sequence.maxNetProfitM;                // max. observed total net profit in account currency:   0...+n
double   sequence.maxNetDrawdownM;              // max. observed total net drawdown in account currency: -n...0

// order data
int      open.signal;                           // one open position
int      open.ticket;
int      open.type;
datetime open.time;
double   open.price;
double   open.slippageP;                        // P: in pip
double   open.swapM;
double   open.commissionM;
double   open.grossProfitM;                     // M: in account currency
double   open.grossProfitU;                     // U: in quote units (price unit)
double   open.netProfitM;
double   open.netProfitU;
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

// other
double   _unitValue;                             // quote unit value of 1 lot in account currency
string   tpTypeDescriptions[] = {"off", "money", "percent", "pip"};

// caching vars to speed-up ShowStatus()
string   sLots               = "";
string   sStartConditions    = "";
string   sStopConditions     = "";
string   sSequenceTotalNetPL = "";
string   sSequencePlStats    = "";

// debug settings                               // configurable via framework config, see afterInit()
bool     test.onReversalPause     = false;      // whether to pause a test after a ZigZag reversal
bool     test.onSessionBreakPause = false;      // whether to pause a test after StopSequence(SIGNAL_TIME)
bool     test.onStopPause         = false;      // whether to pause a test after a final StopSequence()
bool     test.optimizeStatus      = true;       // whether to reduce status file writes in tester

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

      if (recordCustom) {                                            // update recorder values
         if (recorder.enabled[METRIC_CUMULATED_MONEY_NET  ]) recorder.currValue[METRIC_CUMULATED_MONEY_NET  ] = sequence.totalNetProfitM;
         if (recorder.enabled[METRIC_CUMULATED_UNITS_GROSS]) recorder.currValue[METRIC_CUMULATED_UNITS_GROSS] = sequence.totalGrossProfitU/Pip;
         if (recorder.enabled[METRIC_CUMULATED_UNITS_NET  ]) recorder.currValue[METRIC_CUMULATED_UNITS_NET  ] = sequence.totalNetProfitU  /Pip;
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

            if (IsVisualMode()) {        // pause the tester according to the debug configuration
               if (test.onReversalPause) Tester.Pause("IsZigZagSignal(2)");
            }
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
   if (start.time.condition) {
      datetime now = TimeServer();
      if (start.time.isDaily) /*&&*/ if (start.time.value < 1*DAY) {    // convert a relative start time to an absolute one
         start.time.value += (now - (now % DAY));                       // relative + Midnight (possibly in the past)
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
   if (IsLogInfo()) logInfo("StartSequence(3)  "+ sequence.name +" starting ("+ SignalToStr(signal) +")");

   sequence.status = STATUS_PROGRESSING;
   if (!sequence.startEquityM) sequence.startEquityM = NormalizeDouble(AccountEquity() - AccountCredit() + GetExternalAssets(), 2);

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
   open.signal       = signal;
   open.ticket       = ticket;
   open.type         = type;
   open.time         = oe.OpenTime  (oe);
   open.price        = oe.OpenPrice (oe);
   open.slippageP    = -oe.Slippage (oe);
   open.swapM        = oe.Swap      (oe);
   open.commissionM  = oe.Commission(oe);
   open.grossProfitM = oe.Profit    (oe);
   open.grossProfitU = ifDouble(type==OP_BUY, MarketInfo(Symbol(), MODE_BID)-open.price, open.price-MarketInfo(Symbol(), MODE_ASK));
   open.netProfitM   = open.grossProfitM + open.swapM + open.commissionM;
   open.netProfitU   = open.grossProfitU + (open.swapM + open.commissionM)/UnitValue(Lots);

   // update PL numbers
   sequence.openGrossProfitU  = open.grossProfitU;
   sequence.totalGrossProfitU = sequence.openGrossProfitU + sequence.closedGrossProfitU;

   sequence.openNetProfitM  = open.netProfitM;
   sequence.totalNetProfitM = sequence.openNetProfitM + sequence.closedNetProfitM;
   sequence.openNetProfitU  = open.netProfitU;
   sequence.totalNetProfitU = sequence.openNetProfitU + sequence.closedNetProfitU;

   sequence.maxNetProfitM   = MathMax(sequence.maxNetProfitM, sequence.totalNetProfitM);
   sequence.maxNetDrawdownM = MathMin(sequence.maxNetDrawdownM, sequence.totalNetProfitM);
   SS.TotalPL();
   SS.PLStats();

   // update start/stop conditions
   start.time.condition = false;
   stop.time.condition  = stop.time.isDaily;
   if (stop.time.isDaily) {
      datetime now = TimeServer();                          // convert a relative start time to the next absolute time in
      stop.time.value %= DAYS;                              // the future:
      stop.time.value += (now - (now % DAY));               // relative + Midnight (possibly in the past)
      if (stop.time.value < now) stop.time.value += 1*DAY;
   }
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
      if (!ArchiveClosedPosition(open.ticket, open.signal, NormalizeDouble(open.slippageP-oe.Slippage(oe), 1))) return(false);
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
   open.signal       = signal;
   open.ticket       = oe.Ticket    (oe);
   open.type         = oe.Type      (oe);
   open.time         = oe.OpenTime  (oe);
   open.price        = oe.OpenPrice (oe);
   open.slippageP    = oe.Slippage  (oe);
   open.swapM        = oe.Swap      (oe);
   open.commissionM  = oe.Commission(oe);
   open.grossProfitM = oe.Profit    (oe);
   open.grossProfitU = ifDouble(type==OP_BUY, MarketInfo(Symbol(), MODE_BID)-open.price, open.price-MarketInfo(Symbol(), MODE_ASK));
   open.netProfitM   = open.grossProfitM + open.swapM + open.commissionM;
   open.netProfitU   = open.grossProfitU + (open.swapM + open.commissionM)/UnitValue(Lots);

   // update PL numbers
   sequence.openGrossProfitU  = open.grossProfitU;
   sequence.totalGrossProfitU = sequence.openGrossProfitU + sequence.closedGrossProfitU;

   sequence.openNetProfitM  = open.netProfitM;
   sequence.totalNetProfitM = sequence.openNetProfitM + sequence.closedNetProfitM;
   sequence.openNetProfitU  = open.netProfitU;
   sequence.totalNetProfitU = sequence.openNetProfitU + sequence.closedNetProfitU;

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
 * @param int    signal   - signal which caused opening of the trade
 * @param double slippage - cumulated open and close slippage of the trade in pip
 *
 * @return bool - success status
 */
bool ArchiveClosedPosition(int ticket, int signal, double slippage) {
   if (last_error != NULL)                    return(false);
   if (sequence.status != STATUS_PROGRESSING) return(!catch("ArchiveClosedPosition(1)  "+ sequence.name +" cannot archive position of "+ StatusDescription(sequence.status) +" sequence", ERR_ILLEGAL_STATE));

   SelectTicket(ticket, "ArchiveClosedPosition(2)", /*push=*/true);

   // update now closed position data
   open.swapM        = OrderSwap();
   open.commissionM  = OrderCommission();
   open.grossProfitM = OrderProfit();
   open.grossProfitU = ifDouble(OrderType()==OP_BUY, OrderClosePrice()-OrderOpenPrice(), OrderOpenPrice()-OrderClosePrice());
   open.netProfitM   = open.grossProfitM + open.swapM + open.commissionM;
   open.netProfitU   = open.grossProfitU + (open.swapM + open.commissionM)/UnitValue(OrderLots());

   // update history
   int i = ArrayRange(history, 0);
   ArrayResize(history, i + 1);
   history[i][HI_SIGNAL      ] = signal;
   history[i][HI_TICKET      ] = ticket;
   history[i][HI_LOTS        ] = OrderLots();
   history[i][HI_OPENTYPE    ] = OrderType();
   history[i][HI_OPENTIME    ] = OrderOpenTime();
   history[i][HI_OPENPRICE   ] = OrderOpenPrice();
   history[i][HI_CLOSETIME   ] = OrderCloseTime();
   history[i][HI_CLOSEPRICE  ] = OrderClosePrice();
   history[i][HI_SLIPPAGE    ] = slippage;
   history[i][HI_SWAP        ] = open.swapM;
   history[i][HI_COMMISSION  ] = open.commissionM;
   history[i][HI_GROSS_PROFIT] = open.grossProfitM;
   history[i][HI_NET_PROFIT  ] = open.netProfitM;

   // update PL numbers
   sequence.openGrossProfitU    = 0;
   sequence.closedGrossProfitU += open.grossProfitU;
   sequence.totalGrossProfitU   = sequence.closedGrossProfitU;

   sequence.openNetProfitM    = 0;
   sequence.closedNetProfitM += open.netProfitM;
   sequence.totalNetProfitM   = sequence.closedNetProfitM;

   sequence.openNetProfitU    = 0;
   sequence.closedNetProfitU += open.netProfitU;
   sequence.totalNetProfitU   = sequence.closedNetProfitU;
   OrderPop("ArchiveClosedPosition(3)");

   // reset open position data
   open.signal       = NULL;
   open.ticket       = NULL;
   open.type         = NULL;
   open.time         = NULL;
   open.price        = NULL;
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
 * Whether a stop condition is satisfied for a sequence.
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
      if (stop.time.isDaily) /*&&*/ if (stop.time.value < 1*DAY) {      // convert a relative stop time to an absolute one
         stop.time.value += (now - (now % DAY));                        // relative + Midnight (possibly in the past)
      }
      if (now >= stop.time.value) {
         signal = SIGNAL_TIME;
         return(true);
      }
   }

   if (sequence.status == STATUS_PROGRESSING) {
      // stop.profitAbs: ----------------------------------------------------------------------------------------------------
      if (stop.profitAbs.condition) {
         if (sequence.totalNetProfitM >= stop.profitAbs.value) {
            if (IsLogNotice()) logNotice("IsStopSignal(2)  "+ sequence.name +" stop condition \"@"+ stop.profitAbs.description +"\" satisfied (market: "+ NumberToStr(Bid, PriceFormat) +"/"+ NumberToStr(Ask, PriceFormat) +")");
            signal = SIGNAL_TAKEPROFIT;
            return(true);
         }
      }

      // stop.profitPct: ----------------------------------------------------------------------------------------------------
      if (stop.profitPct.condition) {
         if (stop.profitPct.absValue == INT_MAX)
            stop.profitPct.absValue = stop.profitPct.AbsValue();

         if (sequence.totalNetProfitM >= stop.profitPct.absValue) {
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
         double startEquity = sequence.startEquityM;
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
      if (open.ticket > 0) {                                         // a progressing sequence may have an open position to close
         if (IsLogInfo()) logInfo("StopSequence(2)  "+ sequence.name +" stopping ("+ SignalToStr(signal) +")");

         int oeFlags, oe[];
         if (!OrderCloseEx(open.ticket, NULL, Slippage, CLR_NONE, oeFlags, oe))                                    return(!SetLastError(oe.Error(oe)));
         if (!ArchiveClosedPosition(open.ticket, open.signal, NormalizeDouble(open.slippageP-oe.Slippage(oe), 1))) return(false);

         sequence.maxNetProfitM   = MathMax(sequence.maxNetProfitM, sequence.totalNetProfitM);
         sequence.maxNetDrawdownM = MathMin(sequence.maxNetDrawdownM, sequence.totalNetProfitM);
         SS.TotalPL();
         SS.PLStats();
      }
   }

   // update stop conditions and status
   switch (signal) {
      case SIGNAL_TIME:
         start.time.condition = start.time.isDaily;
         if (start.time.isDaily) {
            datetime now = TimeServer();                             // convert a relative start time to the next absolute time in
            start.time.value %= DAYS;                                // the future:
            start.time.value += (now - (now % DAY));                 // relative + Midnight (possibly in the past)
            if (start.time.value < now) start.time.value += 1*DAY;   // TODO: 1 day is not enough, shift to next trading session
         }
         stop.time.condition  = false;
         sequence.status      = ifInt(start.time.isDaily, STATUS_WAITING, STATUS_STOPPED);
         break;

      case SIGNAL_TAKEPROFIT:
         stop.profitAbs.condition = false;
         stop.profitPct.condition = false;
         stop.profitPip.condition = false;
         sequence.status          = STATUS_STOPPED;
         break;

      case NULL:                                                     // explicit stop (manual) or end of test
         break;

      default: return(!catch("StopSequence(3)  "+ sequence.name +" invalid parameter signal: "+ signal, ERR_INVALID_PARAMETER));
   }
   SS.StartStopConditions();

   if (IsLogInfo()) logInfo("StopSequence(4)  "+ sequence.name +" "+ ifString(IsTesting() && !signal, "test ", "") +"sequence stopped"+ ifString(!signal, "", " ("+ SignalToStr(signal) +")") +", profit: "+ sSequenceTotalNetPL +" "+ StrReplace(sSequencePlStats, " ", ""));
   SaveStatus();

   if (IsTesting()) {                                                // pause or stop the tester according to the debug configuration
      if      (!IsVisualMode())       { if (sequence.status == STATUS_STOPPED) Tester.Stop ("StopSequence(5)"); }
      else if (signal == SIGNAL_TIME) { if (test.onSessionBreakPause)          Tester.Pause("StopSequence(6)"); }
      else                            { if (test.onStopPause)                  Tester.Pause("StopSequence(7)"); }
   }
   return(!catch("StopSequence(8)"));
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

      open.swapM        = OrderSwap();
      open.commissionM  = OrderCommission();
      open.grossProfitM = OrderProfit();
      open.grossProfitU = ifDouble(open.type==OP_BUY, Bid-open.price, open.price-Ask);
      open.netProfitM   = open.grossProfitM + open.swapM + open.commissionM;
      open.netProfitU   = open.grossProfitU; if (open.swapM || open.commissionM) open.netProfitU += (open.swapM + open.commissionM)/UnitValue(OrderLots());

      if (isOpen) {
         sequence.openGrossProfitU = open.grossProfitU;
         sequence.openNetProfitU   = open.netProfitU;
         sequence.openNetProfitM   = open.netProfitM;
      }
      else {
         if (IsError(onPositionClose("UpdateStatus(3)  "+ sequence.name +" "+ UpdateStatus.PositionCloseMsg(error), error))) return(false);
         if (!ArchiveClosedPosition(open.ticket, open.signal, open.slippageP)) return(false);
      }
      sequence.totalGrossProfitU = sequence.openGrossProfitU + sequence.closedGrossProfitU;
      sequence.totalNetProfitU   = sequence.openNetProfitU   + sequence.closedNetProfitU;
      sequence.totalNetProfitM   = sequence.openNetProfitM   + sequence.closedNetProfitM; SS.TotalPL();

      if      (sequence.totalNetProfitM > sequence.maxNetProfitM  ) { sequence.maxNetProfitM   = sequence.totalNetProfitM; SS.PLStats(); }
      else if (sequence.totalNetProfitM < sequence.maxNetDrawdownM) { sequence.maxNetDrawdownM = sequence.totalNetProfitM; SS.PLStats(); }
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
   if (id < SID_MIN || id > SID_MAX)            return(!catch("CalculateMagicNumber(2)  "+ sequence.name +" illegal sequence id: "+ id, ERR_ILLEGAL_STATE));

   int strategy = STRATEGY_ID;                              // 101-1023 (10 bit)
   int sequence = id;                                       // now 100-999 but was 1000-9999 (14 bit)

   return((strategy<<22) + (sequence<<8));                  // the remaining 8 bit are not used in this strategy
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
 * Return custom symbol definitions for metrics to be recorded by this instance.
 *
 * @param  _In_  int    i            - zero-based index of the timeseries (position in the recorder)
 * @param  _Out_ bool   enabled      - whether the metric is active and should be recorded
 * @param  _Out_ string symbol       - unique timeseries symbol
 * @param  _Out_ string symbolDescr  - timeseries description
 * @param  _Out_ string symbolGroup  - timeseries group (if empty recorder defaults are used)
 * @param  _Out_ int    symbolDigits - timeseries digits
 * @param  _Out_ double baseValue    - timeseries base value
 * @param  _Out_ string hstDirectory - history directory of the timeseries (if empty recorder defaults are used)
 * @param  _Out_ int    hstFormat    - history format of the timeseries (if empty recorder defaults are used)
 *
 * @return bool - whether to add a definition for the specified index
 */
bool Recorder_GetSymbolDefinitionA(int i, bool &enabled, string &symbol, string &symbolDescr, string &symbolGroup, int &symbolDigits, double &baseValue, string &hstDirectory, int &hstFormat) {
   if (IsLastError()) return(false);
   if (!sequence.id)  return(!catch("Recorder_GetSymbolDefinitionA(1)  "+ sequence.name +" illegal sequence id: "+ sequence.id, ERR_ILLEGAL_STATE));

   string sIds[];
   Explode(EA.Recorder, ",", sIds, NULL);

   enabled      = StringInArray(sIds, ""+ (i+1));
   symbolGroup  = "";
   baseValue    = 1000.0;
   hstDirectory = "";
   hstFormat    = NULL;

   switch (i) {
      case METRIC_CUMULATED_MONEY_NET:          // OK
         symbolDigits = 2;
         symbol       = "z"+ StrLeft(Symbol(), 5) +"_"+ sequence.id +"A";     // "zEURUS_123A"
         symbolDescr  = "ZigZag("+ ZigZag.Periods +","+ PeriodDescription() +") 1 x "+ Symbol() +", cum. "+ AccountCurrency() +", all costs";
         return(true);                                                        // "ZigZag(40,H1) 3 x EURUSD, cum. AUD, all costs"

      // --------------------------------------------------------------------------------------------------------------------
      case METRIC_CUMULATED_UNITS_ZERO:
         symbolDigits = 1;
         symbol       = "z"+ StrLeft(Symbol(), 5) +"_"+ sequence.id +"B";
         symbolDescr  = "ZigZag("+ ZigZag.Periods +","+ PeriodDescription() +") 1 x "+ Symbol() +", cum. pip, no spread/costs";
         return(true);

      case METRIC_CUMULATED_UNITS_GROSS:        // OK
         symbolDigits = 1;
         symbol       = "z"+ StrLeft(Symbol(), 5) +"_"+ sequence.id +"C";
         symbolDescr  = "ZigZag("+ ZigZag.Periods +","+ PeriodDescription() +") 1 x "+ Symbol() +", cum. pip, w/spread";
         return(true);

      case METRIC_CUMULATED_UNITS_NET:          // OK
         symbolDigits = 1;
         symbol       = "z"+ StrLeft(Symbol(), 5) +"_"+ sequence.id +"D";
         symbolDescr  = "ZigZag("+ ZigZag.Periods +","+ PeriodDescription() +") 1 x "+ Symbol() +", cum. pip, all costs";
         return(true);

      // --------------------------------------------------------------------------------------------------------------------
      case METRIC_DAILY_MONEY_NET:
         symbolDigits = 2;
         symbol       = "z"+ StrLeft(Symbol(), 5) +"_"+ sequence.id +"E";
         symbolDescr  = "ZigZag("+ ZigZag.Periods +","+ PeriodDescription() +") 1 x "+ Symbol() +", daily "+ AccountCurrency() +", all costs";
         return(true);

      // --------------------------------------------------------------------------------------------------------------------
      case METRIC_DAILY_UNITS_ZERO:
         symbolDigits = 1;
         symbol       = "z"+ StrLeft(Symbol(), 5) +"_"+ sequence.id +"F";
         symbolDescr  = "ZigZag("+ ZigZag.Periods +","+ PeriodDescription() +") 1 x "+ Symbol() +", daily pip, no spread/costs";
         return(true);

      case METRIC_DAILY_UNITS_GROSS:
         symbolDigits = 1;
         symbol       = "z"+ StrLeft(Symbol(), 5) +"_"+ sequence.id +"G";
         symbolDescr  = "ZigZag("+ ZigZag.Periods +","+ PeriodDescription() +") 1 x "+ Symbol() +", daily pip, w/spread";
         return(true);

      case METRIC_DAILY_UNITS_NET:
         symbolDigits = 1;
         symbol       = "z"+ StrLeft(Symbol(), 5) +"_"+ sequence.id +"H";
         symbolDescr  = "ZigZag("+ ZigZag.Periods +","+ PeriodDescription() +") 1 x "+ Symbol() +", daily pip, all costs";
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
   if (last_error != NULL)                        return(false);
   if (!sequence.id || StrTrim(Sequence.ID)=="")  return(!catch("SaveStatus(1)  illegal sequence id: "+ sequence.id +" (Sequence.ID="+ DoubleQuoteStr(Sequence.ID) +")", ERR_ILLEGAL_STATE));
   if (IsTestSequence()) /*&&*/ if (!IsTesting()) return(true);

   // in tester skip most status file writes, except file creation, sequence stop and test end
   if (IsTesting() && test.optimizeStatus) {
      static bool saved = false;
      if (saved && sequence.status!=STATUS_STOPPED && __CoreFunction!=CF_DEINIT) return(true);
      saved = true;
   }

   string section="", separator="", file=GetStatusFilename();
   if (!IsFile(file, MODE_SYSTEM)) separator = CRLF;             // an empty line as additional section separator

   // [General]
   section = "General";
   WriteIniString(file, section, "Account", GetAccountCompanyId() +":"+ GetAccountNumber());
   WriteIniString(file, section, "Symbol",  Symbol());
   WriteIniString(file, section, "Created", GmtTimeFormat(sequence.created, "%a, %Y.%m.%d %H:%M:%S") + separator);         // conditional section separator

   // [Inputs]
   section = "Inputs";
   WriteIniString(file, section, "Sequence.ID",                 /*string*/ Sequence.ID);
   WriteIniString(file, section, "ZigZag.Periods",              /*int   */ ZigZag.Periods);
   WriteIniString(file, section, "Lots",                        /*double*/ NumberToStr(Lots, ".+"));
   WriteIniString(file, section, "StartConditions",             /*string*/ SaveStatus.ConditionsToStr(sStartConditions));  // contains only active conditions
   WriteIniString(file, section, "StopConditions",              /*string*/ SaveStatus.ConditionsToStr(sStopConditions));   // contains only active conditions
   WriteIniString(file, section, "TakeProfit",                  /*double*/ NumberToStr(TakeProfit, ".+"));
   WriteIniString(file, section, "TakeProfit.Type",             /*string*/ TakeProfit.Type);
   WriteIniString(file, section, "Slippage",                    /*int   */ Slippage);
   WriteIniString(file, section, "ShowProfitInPercent",         /*bool  */ ShowProfitInPercent);
   WriteIniString(file, section, "EA.Recorder",                 /*string*/ EA.Recorder + separator);                       // conditional section separator

   // [Runtime status]
   section = "Runtime status";                                  // On deletion of pending orders the number of stored order records decreases. To prevent
   EmptyIniSectionA(file, section);                             // orphaned status file records the section is emptied before writing to it.

   // sequence data
   WriteIniString(file, section, "sequence.id",                 /*int     */ sequence.id);
   WriteIniString(file, section, "sequence.created",            /*datetime*/ sequence.created + GmtTimeFormat(sequence.created, " (%a, %Y.%m.%d %H:%M:%S)"));
   WriteIniString(file, section, "sequence.isTest",             /*bool    */ sequence.isTest);
   WriteIniString(file, section, "sequence.name",               /*string  */ sequence.name);
   WriteIniString(file, section, "sequence.status",             /*int     */ sequence.status);
   WriteIniString(file, section, "sequence.startEquityM",       /*double  */ DoubleToStr(sequence.startEquityM, 2));
   WriteIniString(file, section, "sequence.openGrossProfitU",   /*double  */ DoubleToStr(sequence.openGrossProfitU, 6));
   WriteIniString(file, section, "sequence.closedGrossProfitU", /*double  */ DoubleToStr(sequence.closedGrossProfitU, 6));
   WriteIniString(file, section, "sequence.totalGrossProfitU",  /*double  */ DoubleToStr(sequence.totalGrossProfitU, 6));
   WriteIniString(file, section, "sequence.openNetProfitU",     /*double  */ DoubleToStr(sequence.openNetProfitU, 6));
   WriteIniString(file, section, "sequence.closedNetProfitU",   /*double  */ DoubleToStr(sequence.closedNetProfitU, 6));
   WriteIniString(file, section, "sequence.totalNetProfitU",    /*double  */ DoubleToStr(sequence.totalNetProfitU, 6));
   WriteIniString(file, section, "sequence.openNetProfitM",     /*double  */ DoubleToStr(sequence.openNetProfitM, 2));
   WriteIniString(file, section, "sequence.closedNetProfitM",   /*double  */ DoubleToStr(sequence.closedNetProfitM, 2));
   WriteIniString(file, section, "sequence.totalNetProfitM",    /*double  */ DoubleToStr(sequence.totalNetProfitM, 2));
   WriteIniString(file, section, "sequence.maxNetProfitM",      /*double  */ DoubleToStr(sequence.maxNetProfitM, 2));
   WriteIniString(file, section, "sequence.maxNetDrawdownM",    /*double  */ DoubleToStr(sequence.maxNetDrawdownM, 2) + CRLF);

   // open order data
   WriteIniString(file, section, "open.signal",                 /*int     */ open.signal);
   WriteIniString(file, section, "open.ticket",                 /*int     */ open.ticket);
   WriteIniString(file, section, "open.type",                   /*int     */ open.type);
   WriteIniString(file, section, "open.time",                   /*datetime*/ open.time + ifString(open.time, GmtTimeFormat(open.time, " (%a, %Y.%m.%d %H:%M:%S)"), ""));
   WriteIniString(file, section, "open.price",                  /*double  */ DoubleToStr(open.price, Digits));
   WriteIniString(file, section, "open.slippageP",              /*double  */ DoubleToStr(open.slippageP, 1));
   WriteIniString(file, section, "open.swapM",                  /*double  */ DoubleToStr(open.swapM, 2));
   WriteIniString(file, section, "open.commissionM",            /*double  */ DoubleToStr(open.commissionM, 2));
   WriteIniString(file, section, "open.grossProfitM",           /*double  */ DoubleToStr(open.grossProfitM, 2));
   WriteIniString(file, section, "open.grossProfitU",           /*double  */ DoubleToStr(open.grossProfitU, 6));
   WriteIniString(file, section, "open.netProfitM",             /*double  */ DoubleToStr(open.netProfitM, 2));
   WriteIniString(file, section, "open.netProfitU",             /*double  */ DoubleToStr(open.netProfitU, 6) + CRLF);

   // closed order data
   int size = ArrayRange(history, 0);
   for (int i=0; i < size; i++) {
      WriteIniString(file, section, "history."+ i, SaveStatus.HistoryToStr(i) + ifString(i+1 < size, "", CRLF));
   }

   // start/stop conditions
   WriteIniString(file, section, "start.time.condition",        /*bool    */ start.time.condition);
   WriteIniString(file, section, "start.time.value",            /*datetime*/ start.time.value + ifString(start.time.value, GmtTimeFormat(start.time.value, " (%a, %Y.%m.%d %H:%M:%S)"), ""));
   WriteIniString(file, section, "start.time.isDaily",          /*bool    */ start.time.isDaily);
   WriteIniString(file, section, "start.time.description",      /*string  */ start.time.description + CRLF);

   WriteIniString(file, section, "stop.time.condition",         /*bool    */ stop.time.condition);
   WriteIniString(file, section, "stop.time.value",             /*datetime*/ stop.time.value + ifString(stop.time.value, GmtTimeFormat(stop.time.value, " (%a, %Y.%m.%d %H:%M:%S)"), ""));
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
   // result: signal,ticket,lots,openType,openTime,openPrice,closeTime,closePrice,slippage,swap,commission,grossProfit,netProfit

   int      signal      = history[index][HI_SIGNAL      ];
   int      ticket      = history[index][HI_TICKET      ];
   double   lots        = history[index][HI_LOTS        ];
   int      openType    = history[index][HI_OPENTYPE    ];
   datetime openTime    = history[index][HI_OPENTIME    ];
   double   openPrice   = history[index][HI_OPENPRICE   ];
   datetime closeTime   = history[index][HI_CLOSETIME   ];
   double   closePrice  = history[index][HI_CLOSEPRICE  ];
   double   slippage    = history[index][HI_SLIPPAGE    ];
   double   swap        = history[index][HI_SWAP        ];
   double   commission  = history[index][HI_COMMISSION  ];
   double   grossProfit = history[index][HI_GROSS_PROFIT];
   double   netProfit   = history[index][HI_NET_PROFIT  ];

   return(StringConcatenate(signal, ",", ticket, ",", DoubleToStr(lots, 2), ",", openType, ",", openTime, ",", DoubleToStr(openPrice, Digits), ",", closeTime, ",", DoubleToStr(closePrice, Digits), ",", DoubleToStr(slippage, 1), ",", DoubleToStr(swap, 2), ",", DoubleToStr(commission, 2), ",", DoubleToStr(grossProfit, 2), ",", DoubleToStr(netProfit, 2)));
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
   string sThisAccount = GetAccountCompanyId() +":"+ GetAccountNumber();
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
   string sEaRecorder          = GetIniStringA(file, section, "EA.Recorder",         "");             // string EA.Recorder         = 1,2,4

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
   EA.Recorder         = sEaRecorder;

   // [Runtime status]
   section = "Runtime status";
   // sequence data
   sequence.id                 = GetIniInt    (file, section, "sequence.id"                );         // int      sequence.id                 = 1234
   sequence.created            = GetIniInt    (file, section, "sequence.created"           );         // datetime sequence.created            = 1624924800 (Mon, 2021.05.12 13:22:34)
   sequence.isTest             = GetIniBool   (file, section, "sequence.isTest"            );         // bool     sequence.isTest             = 1
   sequence.name               = GetIniStringA(file, section, "sequence.name",           "");         // string   sequence.name               = Z.1234
   sequence.status             = GetIniInt    (file, section, "sequence.status"            );         // int      sequence.status             = 1
   sequence.startEquityM       = GetIniDouble (file, section, "sequence.startEquityM"      );         // double   sequence.startEquityM       = 1000.00
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
   open.signal                 = GetIniInt    (file, section, "open.signal"      );                   // int      open.signal       = 1
   open.ticket                 = GetIniInt    (file, section, "open.ticket"      );                   // int      open.ticket       = 123456
   open.type                   = GetIniInt    (file, section, "open.type"        );                   // int      open.type         = 0
   open.time                   = GetIniInt    (file, section, "open.time"        );                   // datetime open.time         = 1624924800
   open.price                  = GetIniDouble (file, section, "open.price"       );                   // double   open.price        = 1.24363
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

   // history.i=signal,ticket,lots,openType,openTime,openPrice,closeTime,closePrice,slippage,swap,commission,grossProfit,netProfit
   string values[];
   string sId = StrRightFrom(key, ".", -1); if (!StrIsDigit(sId))   return(!catch("ReadStatus.ParseHistory(2)  "+ sequence.name +" illegal history record key "+ DoubleQuoteStr(key), ERR_INVALID_FILE_FORMAT));
   int index = StrToInteger(sId);
   if (Explode(value, ",", values, NULL) != ArrayRange(history, 1)) return(!catch("ReadStatus.ParseHistory(3)  "+ sequence.name +" illegal number of details ("+ ArraySize(values) +") in history record", ERR_INVALID_FILE_FORMAT));

   int      signal      = StrToInteger(values[HI_SIGNAL      ]);
   int      ticket      = StrToInteger(values[HI_TICKET      ]);
   double   lots        =  StrToDouble(values[HI_LOTS        ]);
   int      openType    = StrToInteger(values[HI_OPENTYPE    ]);
   datetime openTime    = StrToInteger(values[HI_OPENTIME    ]);
   double   openPrice   =  StrToDouble(values[HI_OPENPRICE   ]);
   datetime closeTime   = StrToInteger(values[HI_CLOSETIME   ]);
   double   closePrice  =  StrToDouble(values[HI_CLOSEPRICE  ]);
   double   slippage    =  StrToDouble(values[HI_SLIPPAGE    ]);
   double   swap        =  StrToDouble(values[HI_SWAP        ]);
   double   commission  =  StrToDouble(values[HI_COMMISSION  ]);
   double   grossProfit =  StrToDouble(values[HI_GROSS_PROFIT]);
   double   netProfit   =  StrToDouble(values[HI_NET_PROFIT  ]);

   return(History.AddRecord(index, signal, ticket, lots, openType, openTime, openPrice, closeTime, closePrice, slippage, swap, commission, grossProfit, netProfit));
}


/**
 * Add a record to the history array. Prevents existing data to be overwritten.
 *
 * @param  int index - array index to insert the record
 * @param  ...       - record details
 *
 * @return bool - success status
 */
int History.AddRecord(int index, int signal, int ticket, double lots, int openType, datetime openTime, double openPrice, datetime closeTime, double closePrice, double slippage, double swap, double commission, double grossProfit, double netProfit) {
   if (index < 0) return(!catch("History.AddRecord(1)  "+ sequence.name +" invalid parameter index: "+ index, ERR_INVALID_PARAMETER));

   int size = ArrayRange(history, 0);
   if (index >= size) ArrayResize(history, index+1);
   if (history[index][HI_TICKET] != 0) return(!catch("History.AddRecord(2)  "+ sequence.name +" invalid parameter index: "+ index +" (cannot overwrite history["+ index +"] record, ticket #"+ history[index][HI_TICKET] +")", ERR_INVALID_PARAMETER));

   history[index][HI_SIGNAL      ] = signal;
   history[index][HI_TICKET      ] = ticket;
   history[index][HI_LOTS        ] = lots;
   history[index][HI_OPENTYPE    ] = openType;
   history[index][HI_OPENTIME    ] = openTime;
   history[index][HI_OPENPRICE   ] = openPrice;
   history[index][HI_CLOSETIME   ] = closeTime;
   history[index][HI_CLOSEPRICE  ] = closePrice;
   history[index][HI_SLIPPAGE    ] = slippage;
   history[index][HI_SWAP        ] = swap;
   history[index][HI_COMMISSION  ] = commission;
   history[index][HI_GROSS_PROFIT] = grossProfit;
   history[index][HI_NET_PROFIT  ] = netProfit;

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
string   prev.EA.Recorder = "";


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

int      prev.recordMode;
bool     prev.recordInternal;
bool     prev.recordCustom;


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
   prev.EA.Recorder         = StringConcatenate(EA.Recorder, "");

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

   prev.recordMode                 = recordMode;
   prev.recordInternal             = recordInternal;
   prev.recordCustom               = recordCustom;
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
   EA.Recorder         = prev.EA.Recorder;

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

   recordMode                 = prev.recordMode;
   recordInternal             = prev.recordInternal;
   recordCustom               = prev.recordCustom;
}


/**
 * Syntactically validate and restore a specified sequence id (format: /T?[0-9]{3}/). Called only from onInitUser().
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
      if (sValue == "") {                                // the id was deleted or not yet set, re-apply the internal id
         Sequence.ID = prev.Sequence.ID;
      }
      else if (sValue != prev.Sequence.ID)               return(!onInputError("ValidateInputs(1)  "+ sequence.name +" switching to another sequence is not supported (unload the EA first)"));
   } //else                                              // the id was validated in ValidateInputs.SID()

   // ZigZag.Periods
   if (isInitParameters && ZigZag.Periods!=prev.ZigZag.Periods) {
      if (sequenceWasStarted)                            return(!onInputError("ValidateInputs(2)  "+ sequence.name +" cannot change input parameter ZigZag.Periods of "+ StatusDescription(sequence.status) +" sequence"));
   }
   if (ZigZag.Periods < 2)                               return(!onInputError("ValidateInputs(3)  "+ sequence.name +" invalid input parameter ZigZag.Periods: "+ ZigZag.Periods));

   // Lots
   if (isInitParameters && NE(Lots, prev.Lots)) {
      if (sequenceWasStarted)                            return(!onInputError("ValidateInputs(4)  "+ sequence.name +" cannot change input parameter Lots of "+ StatusDescription(sequence.status) +" sequence"));
   }
   if (LT(Lots, 0))                                      return(!onInputError("ValidateInputs(5)  "+ sequence.name +" invalid input parameter Lots: "+ NumberToStr(Lots, ".1+") +" (too small)"));
   if (NE(Lots, NormalizeLots(Lots)))                    return(!onInputError("ValidateInputs(6)  "+ sequence.name +" invalid input parameter Lots: "+ NumberToStr(Lots, ".1+") +" (not a multiple of MODE_LOTSTEP="+ NumberToStr(MarketInfo(Symbol(), MODE_LOTSTEP), ".+") +")"));

   // StartConditions: @time(datetime|time)
   if (!isInitParameters || StartConditions!=prev.StartConditions) {
      start.time.condition = false;                      // on initParameters conditions are re-enabled on change only

      string exprs[], expr="", key="";                   // split conditions
      int sizeOfExprs = Explode(StartConditions, "|", exprs, NULL), iValue, time, sizeOfElems;

      for (int i=0; i < sizeOfExprs; i++) {              // validate each expression
         expr = StrTrim(exprs[i]);
         if (!StringLen(expr))              continue;
         if (StringGetChar(expr, 0) == '!') continue;    // skip disabled conditions
         if (StringGetChar(expr, 0) != '@')              return(!onInputError("ValidateInputs(7)  "+ sequence.name +" invalid input parameter StartConditions: "+ DoubleQuoteStr(StartConditions)));

         if (Explode(expr, "(", sValues, NULL) != 2)     return(!onInputError("ValidateInputs(8)  "+ sequence.name +" invalid input parameter StartConditions: "+ DoubleQuoteStr(StartConditions)));
         if (!StrEndsWith(sValues[1], ")"))              return(!onInputError("ValidateInputs(9)  "+ sequence.name +" invalid input parameter StartConditions: "+ DoubleQuoteStr(StartConditions)));
         key = StrTrim(sValues[0]);
         sValue = StrTrim(StrLeft(sValues[1], -1));
         if (!StringLen(sValue))                         return(!onInputError("ValidateInputs(10)  "+ sequence.name +" invalid input parameter StartConditions: "+ DoubleQuoteStr(StartConditions)));

         if (key == "@time") {
            if (start.time.condition)                    return(!onInputError("ValidateInputs(11)  "+ sequence.name +" invalid input parameter StartConditions: "+ DoubleQuoteStr(StartConditions) +" (multiple time conditions)"));
            int pt[];
            if (!ParseTime(sValue, NULL, pt))            return(!onInputError("ValidateInputs(12)  "+ sequence.name +" invalid input parameter StartConditions: "+ DoubleQuoteStr(StartConditions)));
            start.time.value       = DateTime2(pt, DATE_OF_ERA);
            start.time.isDaily     = !pt[PT_HAS_DATE];
            start.time.description = "time("+ TimeToStr(start.time.value, ifInt(start.time.isDaily, TIME_MINUTES, TIME_DATE|TIME_MINUTES)) +")";
            start.time.condition   = true;
         }
         else                                            return(!onInputError("ValidateInputs(13)  "+ sequence.name +" invalid input parameter StartConditions: "+ DoubleQuoteStr(StartConditions)));
      }
   }

   // StopConditions: @time(datetime|time)
   if (!isInitParameters || StartConditions!=prev.StartConditions) {
      stop.time.condition = false;                       // on initParameters conditions are re-enabled on change only
      sizeOfExprs = Explode(StopConditions, "|", exprs, NULL);

      for (i=0; i < sizeOfExprs; i++) {                  // validate each expression
         expr = StrTrim(exprs[i]);
         if (!StringLen(expr))              continue;
         if (StringGetChar(expr, 0) == '!') continue;    // skip disabled conditions
         if (StringGetChar(expr, 0) != '@')              return(!onInputError("ValidateInputs(7)  "+ sequence.name +" invalid input parameter StopConditions: "+ DoubleQuoteStr(StopConditions)));

         if (Explode(expr, "(", sValues, NULL) != 2)     return(!onInputError("ValidateInputs(8)  "+ sequence.name +" invalid input parameter StopConditions: "+ DoubleQuoteStr(StopConditions)));
         if (!StrEndsWith(sValues[1], ")"))              return(!onInputError("ValidateInputs(9)  "+ sequence.name +" invalid input parameter StopConditions: "+ DoubleQuoteStr(StopConditions)));
         key = StrTrim(sValues[0]);
         sValue = StrTrim(StrLeft(sValues[1], -1));
         if (!StringLen(sValue))                         return(!onInputError("ValidateInputs(10)  "+ sequence.name +" invalid input parameter StopConditions: "+ DoubleQuoteStr(StopConditions)));

         if (key == "@time") {
            if (stop.time.condition)                     return(!onInputError("ValidateInputs(11)  "+ sequence.name +" invalid input parameter StopConditions: "+ DoubleQuoteStr(StopConditions) +" (multiple time conditions)"));
            if (!ParseTime(sValue, NULL, pt))            return(!onInputError("ValidateInputs(12)  "+ sequence.name +" invalid input parameter StopConditions: "+ DoubleQuoteStr(StopConditions)));
            stop.time.value       = DateTime2(pt, DATE_OF_ERA);
            stop.time.isDaily     = !pt[PT_HAS_DATE];
            stop.time.description = "time("+ TimeToStr(stop.time.value, ifInt(stop.time.isDaily, TIME_MINUTES, TIME_DATE|TIME_MINUTES)) +")";
            stop.time.condition   = true;
         }
         else                                            return(!onInputError("ValidateInputs(13)  "+ sequence.name +" invalid input parameter StopConditions: "+ DoubleQuoteStr(StopConditions)));
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
   else if (StringLen(sValue) < 2)                       return(!onInputError("ValidateInputs(14)  "+ sequence.name +" invalid parameter TakeProfit.Type: "+ DoubleQuoteStr(TakeProfit.Type)));
   else if (StrStartsWith("percent", sValue)) type = TP_TYPE_PERCENT;
   else if (StrStartsWith("pip",     sValue)) type = TP_TYPE_PIP;
   else                                                  return(!onInputError("ValidateInputs(15)  "+ sequence.name +" invalid parameter TakeProfit.Type: "+ DoubleQuoteStr(TakeProfit.Type)));
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

   // EA.Recorder
   int metrics;
   if (!init_RecorderValidateInput(metrics))             return(false);
   if (recordCustom && metrics > 8)                      return(!onInputError("ValidateInputs(16)  "+ sequence.name +" invalid parameter EA.Recorder: "+ DoubleQuoteStr(EA.Recorder) +" (unsupported metric "+ metrics +")"));

   SS.All();
   return(!catch("ValidateInputs(17)"));
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
 * Return the quote unit value of the specified lot amount in account currency. As PipValue but for a full quote unit.
 *
 * @param  double lots [optional] - lot amount (default: 1 lot)
 *
 * @return double - unit value or NULL (0) in case of errors (in tester the value may be not exact)
 */
double UnitValue(double lots = 1.0) {
   double tickValue = MarketInfo(Symbol(), MODE_TICKVALUE);
   int error = GetLastError();
   if (error || !tickValue)   return(!catch("UnitValue(1)  MarketInfo(MODE_TICKVALUE) = "+ tickValue, intOr(error, ERR_INVALID_MARKET_DATA)));

   static double tickSize; if (!tickSize) {
      tickSize = MarketInfo(Symbol(), MODE_TICKSIZE);
      error = GetLastError();
      if (error || !tickSize) return(!catch("UnitValue(2)  MarketInfo(MODE_TICKSIZE) = "+ tickSize, intOr(error, ERR_INVALID_MARKET_DATA)));
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
         sValue = sValue + ifString(sValue=="", "", " | ") + ifString(start.time.condition || start.time.isDaily, "@", "!") + start.time.description;
      }
      if (sValue == "") sStartConditions = "-";
      else              sStartConditions = sValue;

      // stop conditions
      sValue = "";
      if (stop.time.description != "") {
         sValue = sValue + ifString(sValue=="", "", " | ") + ifString(stop.time.condition || stop.time.isDaily, "@", "!") + stop.time.description;
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

   string text = StringConcatenate(ProgramName(), "    ", sStatus, sError,                    NL,
                                                                                              NL,
                                  "Lots:      ", sLots,                                       NL,
                                  "Start:    ",  sStartConditions,                            NL,
                                  "Stop:     ",  sStopConditions,                             NL,
                                  "Profit:   ",  sSequenceTotalNetPL, "  ", sSequencePlStats, NL
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
