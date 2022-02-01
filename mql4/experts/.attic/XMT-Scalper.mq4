/**
 * !!! This code is unfinished work-in-progress. Use it only in demo accounts !!!
 *
 *
 * XMT-Scalper revisited
 *
 * This EA is originally based on the famous "MillionDollarPips EA". The core idea of the strategy is scalping based on a
 * reversal from a channel breakout. Over the years it has gone through multiple transformations. Today various versions with
 * different names circulate in the internet (MDP-Plus, XMT-Scalper, Assar). None of them is suitable for real trading, mainly
 * due to lack of signal documentation and a significant amount of issues in the program logic. This version is a full rewrite.
 *
 * Sources:
 *  @link  https://github.com/rosasurfer/mt4-mql/blob/a1b22d0/mql4/experts/mdp#             [MillionDollarPips v2 decompiled]
 *  @link  https://github.com/rosasurfer/mt4-mql/blob/36f494e/mql4/experts/mdp#                    [MDP-Plus v2.2 by Capella]
 *  @link  https://github.com/rosasurfer/mt4-mql/blob/23c51cc/mql4/experts/mdp#                   [MDP-Plus v2.23 by Capella]
 *  @link  https://github.com/rosasurfer/mt4-mql/blob/a0c2411/mql4/experts/mdp#                [XMT-Scalper v2.41 by Capella]
 *  @link  https://github.com/rosasurfer/mt4-mql/blob/8f5f29e/mql4/experts/mdp#                [XMT-Scalper v2.42 by Capella]
 *  @link  https://github.com/rosasurfer/mt4-mql/blob/513f52c/mql4/experts/mdp#                [XMT-Scalper v2.46 by Capella]
 *  @link  https://github.com/rosasurfer/mt4-mql/blob/b3be98e/mql4/experts/mdp#               [XMT-Scalper v2.461 by Capella]
 *  @link  https://github.com/rosasurfer/mt4-mql/blob/41237e0/mql4/experts/mdp#               [XMT-Scalper v2.522 by Capella]
 *
 * Changes:
 *  - removed MQL5 syntax
 *  - integrated the rosasurfer MQL4 framework
 *  - moved all print output to the framework logger
 *  - removed flawed commission calculations
 *  - removed obsolete order expiration, NDD and screenshot functionality
 *  - removed obsolete sending of fake orders and measuring of execution times
 *  - removed obsolete functions and variables
 *  - reorganized input parameters
 *  - fixed signal detection (added input parameter ChannelBug for comparison)
 *  - fixed TakeProfit calculation (added input parameter TakeProfitBug for comparison)
 *  - replaced position size calculation
 *  - replaced magic number calculation
 *  - replaced trade management
 *  - replaced status display
 *  - added monitoring of PositionOpen and PositionClose events
 *  - added total PL targets
 *  - added virtual trading mode with optional trade copier or trade mirror
 *  - added recording of performance metrics for real and virtual trading
 *  - open orders are closed during configurable session breaks
 *  - full status is continuously stored to a file and can be restored from it
 */
#include <stddefines.mqh>
int   __InitFlags[] = {INIT_TIMEZONE, INIT_PIPVALUE, INIT_BUFFERED_LOG};
int __DeinitFlags[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern string   Sequence.ID                    = "";                         // instance id in the range of 1000-9999
extern string   TradingMode                    = "Regular* | Virtual | Virtual-Copier | Virtual-Mirror";   // shortcuts: "R | V | VC | VM"

extern string   ___a__________________________ = "=== Entry indicator: 1=MovingAverage, 2=BollingerBands, 3=Envelopes ===";
extern int      EntryIndicator                 = 1;                          // entry signal indicator for price channel calculation
extern int      IndicatorTimeframe             = PERIOD_M1;                  // entry indicator timeframe
extern int      IndicatorPeriods               = 3;                          // entry indicator bar periods
extern double   BollingerBands.Deviation       = 2.0;                        // standard deviations
extern double   Envelopes.Deviation            = 0.07;                       // in percent

extern string   ___b__________________________ = "=== Entry bar size conditions ================";
extern bool     UseSpreadMultiplier            = true;                       // use spread multiplier or fixed min. bar size
extern double   SpreadMultiplier               = 12.5;                       // min. bar size = SpreadMultiplier * avgSpread
extern double   MinBarSize                     = 18;                         // min. bar size in {pip}

extern string   ___c__________________________ = "=== Signal settings ========================";
extern double   BreakoutReversal               = 0.0;                        // required price reversal in {pip} (0: counter-trend trading w/o reversal)
extern double   MaxSpread                      = 2.0;                        // max. acceptable current and average spread in {pip}
extern bool     ReverseSignals                 = false;                      // Buy => Sell, Sell => Buy

extern string   ___d__________________________ = "=== Money management ===================";
extern bool     UseMoneyManagement             = true;                       // TRUE: calculate lots dynamically; FALSE: use "ManualLotsize"
extern double   Risk                           = 2;                          // percent of equity to risk with each trade
extern double   ManualLotsize                  = 0.01;                       // fix position to use if "MoneyManagement" is FALSE

extern string   ___e__________________________ = "=== Trade settings ========================";
extern double   TakeProfit                     = 10;                         // TP in {pip}
extern double   StopLoss                       = 6;                          // SL in {pip}
extern double   TrailEntryStep                 = 1;                          // trail entry limits every {pip}
extern double   TrailExitStart                 = 0;                          // start trailing exit limits after {pip} in profit
extern double   TrailExitStep                  = 2;                          // trail exit limits every {pip} in profit
extern double   StopOnTotalProfit              = 0.00;                       // stop on overall profit in {money} (0: no stop on any profits)
extern double   StopOnTotalLoss                = 0.00;                       // stop on overall loss in {money} (0: no stop on any losses)
extern double   MaxSlippage                    = 0.3;                        // max. acceptable slippage in {pip}
extern datetime Sessionbreak.StartTime         = D'1970.01.01 23:56:00';     // server time (the date part is ignored)
extern datetime Sessionbreak.EndTime           = D'1970.01.01 00:02:10';     // server time (the date part is ignored)

extern string   ___f__________________________ = "=== Reporting ============================";
extern bool     RecordPerformanceMetrics       = false;                      // whether to enable recording of performance metrics
extern string   MetricsServerDirectory         = "{name} | {path} | auto*";  // history server directory to store performance metrics (auto: apply an existing configuration)

extern string   ___g__________________________ = "=== Bugs ================================";
extern bool     ChannelBug                     = false;                      // whether to enable the erroneous "Capella" calculation of the breakout channel (for comparison only)
extern bool     TakeProfitBug                  = true;                       // whether to enable the erroneous "Capella" calculation of TakeProfit targets (for comparison only)

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/expert.mqh>
#include <stdfunctions.mqh>
#include <rsfLib.mqh>
#include <rsfHistory.mqh>
#include <functions/HandleCommands.mqh>
#include <structs/rsf/OrderExecution.mqh>

#define STRATEGY_ID                  106        // unique strategy id between 101-1023 (10 bit)

#define TRADINGMODE_REGULAR            1
#define TRADINGMODE_VIRTUAL            2
#define TRADINGMODE_VIRTUAL_COPIER     3
#define TRADINGMODE_VIRTUAL_MIRROR     4

#define MODE_REAL    TRADINGMODE_REGULAR
#define MODE_VIRTUAL TRADINGMODE_VIRTUAL

#define SIGNAL_LONG                    1
#define SIGNAL_SHORT                   2

// system performance metrics
#define METRIC_RC1                     0        // real: cumulative PL in pip w/o commission
#define METRIC_RC2                     1        // real: cumulative PL in pip with commission
#define METRIC_RC3                     2        // real: cumulative PL in money w/o commission
#define METRIC_RC4                     3        // real: cumulative PL in money with commission
#define METRIC_RD1                     4        // real: daily PL in pip w/o commission
#define METRIC_RD2                     5        // real: daily PL in pip with commission
#define METRIC_RD3                     6        // real: daily PL in money w/o commission
#define METRIC_RD4                     7        // real: daily PL in money with commission

#define METRIC_VC1                     8        // virt: cumulative PL in pip w/o commission
#define METRIC_VC2                     9        // virt: cumulative PL in pip with commission
#define METRIC_VC3                    10        // virt: cumulative PL in money w/o commission
#define METRIC_VC4                    11        // virt: cumulative PL in money with commission
#define METRIC_VD1                    12        // virt: daily PL in pip w/o commission
#define METRIC_VD2                    13        // virt: daily PL in pip with commission
#define METRIC_VD3                    14        // virt: daily PL in money w/o commission
#define METRIC_VD4                    15        // virt: daily PL in money with commission


// general
int      tradingMode;
int      sequence.id;
string   sequence.name = "";                    // "R.1234" | "V.5678" | "VC.1234" | "VM.5678"

// real order log
int      real.ticket      [];
int      real.linkedTicket[];                   // linked virtual ticket (if any)
double   real.lots        [];                   // order volume > 0
int      real.pendingType [];                   // pending order type if applicable or OP_UNDEFINED (-1)
double   real.pendingPrice[];                   // pending entry limit if applicable or 0
int      real.openType    [];                   // order open type of an opened position or OP_UNDEFINED (-1)
datetime real.openTime    [];                   // order open time of an opened position or 0
double   real.openPrice   [];                   // order open price of an opened position or 0
datetime real.closeTime   [];                   // order close time of a closed order or 0
double   real.closePrice  [];                   // order close price of a closed position or 0
double   real.stopLoss    [];                   // SL price or 0
double   real.takeProfit  [];                   // TP price or 0
double   real.commission  [];                   // order commission
double   real.profit      [];                   // order profit (gross)

// real order statistics
bool     real.isSynchronized;                   // whether real and virtual trading are synchronized
bool     real.isOpenOrder;                      // whether an open order exists (max. 1 open order)
bool     real.isOpenPosition;                   // whether an open position exists (max. 1 open position)

double   real.openLots;                         // total open lotsize: -n...+n
double   real.openCommission;                   // total open commissions
double   real.openPl;                           // total open gross profit in money
double   real.openPlNet;                        // total open net profit in money
double   real.openPip;                          // total open gross profit in pip
double   real.openPipNet;                       // total open net profit in pip

int      real.closedPositions;                  // number of closed positions
double   real.closedLots;                       // total closed lotsize: 0...+n
double   real.closedCommission;                 // total closed commission
double   real.closedPl;                         // total closed gross profit in money
double   real.closedPlNet;                      // total closed net profit in money
double   real.closedPip;                        // total closed gross profit in pip
double   real.closedPipNet;                     // total closed net profit in pip

double   real.totalPl;                          // openPl     + closedPl
double   real.totalPlNet;                       // openPlNet  + closedPlNet
double   real.totalPip;                         // openPip    + closedPip
double   real.totalPipNet;                      // openPipNet + closedPipNet

// virtual order log
int      virt.ticket      [];
int      virt.linkedTicket[];                   // linked real ticket (if any)
double   virt.lots        [];
int      virt.pendingType [];
double   virt.pendingPrice[];
int      virt.openType    [];
datetime virt.openTime    [];
double   virt.openPrice   [];
datetime virt.closeTime   [];
double   virt.closePrice  [];
double   virt.stopLoss    [];
double   virt.takeProfit  [];
double   virt.commission  [];
double   virt.profit      [];

// virtual order statistics
bool     virt.isOpenOrder;
bool     virt.isOpenPosition;

double   virt.openLots;
double   virt.openCommission;
double   virt.openPl;
double   virt.openPlNet;
double   virt.openPip;
double   virt.openPipNet;

int      virt.closedPositions;
double   virt.closedLots;
double   virt.closedCommission;
double   virt.closedPl;
double   virt.closedPlNet;
double   virt.closedPip;
double   virt.closedPipNet;

double   virt.totalPl;                          // openPl     + closedPl
double   virt.totalPlNet;                       // openPlNet  + closedPlNet
double   virt.totalPip;                         // openPip    + closedPip
double   virt.totalPipNet;                      // openPipNet + closedPipNet

// other
double   currentSpread;                         // current spread in pip
double   avgSpread;                             // average spread in pip
double   minBarSize;                            // min. bar size in absolute terms
double   commissionPip;                         // commission in pip (independant of lotsize)
int      orderSlippage;                         // order slippage in point
int      orderMagicNumber;
string   tradingModeDescriptions[] = {"", "Regular", "Virtual", "Virtual-Copier", "Virtual-Mirror"};

// sessionbreak management
datetime sessionbreak.starttime;                // configurable via inputs and framework config
datetime sessionbreak.endtime;
bool     sessionbreak.active;

// management of system performance metrics
bool     metrics.initialized;                   // whether metrics metadata has been initialized
string   metrics.server = "XTrade-Testresults";
int      metrics.format = 400;

bool     metrics.enabled    [16];               // whether a specific metric is currently activated
string   metrics.symbol     [16];               // the symbol of a metric
string   metrics.description[16];               // the description of a metric
int      metrics.digits     [16];               // the digits value of a metric
bool     metrics.symbolOK   [16];               // whether the "symbols.raw" checkup of a metric was done
int      metrics.hSet       [16];               // the HistorySet handle of a metric
double   metrics.hShift     [16];               // horizontal shift added to the history of a metric to prevent negative values

// vars to speed-up status messages
string   sTradingModeStatus[] = {"", "", ": Virtual Trading", ": Virtual Trading + Copier", ": Virtual Trading + Mirror"};
string   sCurrentSpread       = "-";
string   sAvgSpread           = "-";
string   sMaxSpread           = "-";
string   sCurrentBarSize      = "-";
string   sMinBarSize          = "-";
string   sIndicator           = "-";
string   sUnitSize            = "-";

// debug settings                               // configurable via framework config, see afterInit()
bool     test.onPositionOpenPause = false;      // whether to pause a test on PositionOpen events
bool     test.optimizeStatus      = true;       // whether to minimize status file writing in tester


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   double dNull;
   if (ChannelBug) GetIndicatorValues(dNull, dNull, dNull);       // if the channel bug is enabled indicators must be tracked every tick
   if (__isChart)  CalculateSpreads();                            // for the visible spread status display

   sessionbreak.active = IsSessionBreak();

   if (tradingMode == TRADINGMODE_REGULAR) onTick.RegularTrading();
   else                                    onTick.VirtualTrading();

   // record metrics if configured
   if (RecordPerformanceMetrics) {
      if (!IsTesting() || !IsOptimization()) {
         RecordMetrics();
      }
   }
   return(last_error);
}


/**
 * Main function for regular trading.
 *
 * @return int - error status
 */
int onTick.RegularTrading() {
   if (!UpdateRealOrderStatus()) return(last_error);              // update real order status and PL

   if (StopOnTotalProfit || StopOnTotalLoss) {
      if (CheckRealTargets()) return(SetLastError(ERR_CANCELLED_BY_USER));
   }

   if (!last_error && real.isOpenOrder) {
      if (sessionbreak.active)      CloseRealOrders();
      else if (real.isOpenPosition) ManageRealPosition();         // trail exit limits
      else                          ManagePendingOrder();         // trail entry limits or delete order
   }

   if (!last_error && !real.isOpenOrder && !sessionbreak.active) {
      int signal;
      if (IsEntrySignal(signal)) OpenRealOrder(signal);           // monitor and handle new entry signals
   }
   return(last_error);
}


/**
 * Main function for virtual trading.
 *
 * @return int - error status
 */
int onTick.VirtualTrading() {
   if (__isChart) HandleCommands();                               // process chart commands

   // update virtual and real order status (if any)
   UpdateVirtualOrderStatus();

   if (tradingMode > TRADINGMODE_VIRTUAL) {
      if (!real.isSynchronized) {
         if (tradingMode == TRADINGMODE_VIRTUAL_COPIER) SynchronizeTradeCopier();
         if (tradingMode == TRADINGMODE_VIRTUAL_MIRROR) SynchronizeTradeMirror();
      }
      UpdateRealOrderStatus();

      if (StopOnTotalProfit || StopOnTotalLoss) {
         if (CheckRealTargets()) {
            tradingMode = TRADINGMODE_VIRTUAL;
            TradingMode = tradingModeDescriptions[tradingMode]; SS.SequenceName();
            InitMetrics();
            SaveStatus();
         }
      }
   }

   // manage virtual orders
   if (!last_error && virt.isOpenOrder) {
      if (sessionbreak.active)      CloseVirtualOrders();
      else if (virt.isOpenPosition) ManageVirtualPosition();      // trail exit limits
      else                          ManageVirtualOrder();         // trail entry limits or delete order
   }

   // manage real orders (if any)
   if (!last_error && real.isOpenOrder) {
      if (sessionbreak.active)      CloseRealOrders();
      else if (real.isOpenPosition) ManageRealPosition();         // trail exit limits
      else                          ManagePendingOrder();         // trail entry limits or delete order
   }

   // handle new entry signals
   if (!last_error && !virt.isOpenOrder && !sessionbreak.active) {
      int signal;
      if (IsEntrySignal(signal)) {
         OpenVirtualOrder(signal);

         if (tradingMode > TRADINGMODE_VIRTUAL) OpenRealOrder(signal);
      }
   }
   return(last_error);
}


/**
 * Called after the expert was manually loaded by the user. Also in tester with both "VisualMode=On|Off". There was an input
 * dialog.
 *
 * @return int - error status
 */
int onInitUser() {
   // check for and validate a specified sequence id
   if (ValidateInputs.SID()) {
      RestoreSequence();                                       // a valid sequence id was specified
   }
   else if (StrTrim(Sequence.ID) == "") {                      // no sequence id was specified
      if (ValidateInputs()) {
         sequence.id = CreateSequenceId();
         Sequence.ID = sequence.id;
         SS.SequenceName();
         logInfo("onInitUser(1)  sequence id "+ sequence.id +" created");
         SaveStatus();
      }
   }
   //else {}                                                   // an invalid sequence id was specified
   return(last_error);
}


/**
 * Called after the input parameters were changed through the input dialog.
 *
 * @return int - error status
 */
int onInitParameters() {
   if (!ValidateInputs()) {
      RestoreInputs();
      return(last_error);
   }
   SaveStatus();
   return(last_error);
}


/**
 * Called after the chart timeframe has changed. There was no input dialog.
 *
 * @return int - error status
 */
int onInitTimeframeChange() {
   RestoreInputs();
   return(last_error);
}


/**
 * Called after the chart symbol has changed. There was no input dialog.
 *
 * @return int - error status
 */
int onInitSymbolChange() {
   return(SetLastError(ERR_ILLEGAL_STATE));
}


/**
 * Called after the expert was loaded by a chart template. Also at terminal start. There was no input dialog.
 *
 * @return int - error status
 */
int onInitTemplate() {
   return(SetLastError(ERR_NOT_IMPLEMENTED));
}


/**
 * Initialization postprocessing. Called only if the reason-specific handler returned without error.
 *
 * @return int - error status
 */
int afterInit() {
   // initialize global vars
   if (UseSpreadMultiplier) { minBarSize = 0;              sMinBarSize = "-";                                }
   else                     { minBarSize = MinBarSize*Pip; sMinBarSize = DoubleToStr(MinBarSize, 1) +" pip"; }
   MaxSpread        = NormalizeDouble(MaxSpread, 1);
   sMaxSpread       = DoubleToStr(MaxSpread, 1);
   commissionPip    = GetCommission(1, MODE_MARKUP)/Pip;
   orderSlippage    = Round(MaxSlippage*Pip/Point);
   orderMagicNumber = CalculateMagicNumber();
   SS.All();

   if (!SetLogfile(GetLogFilename())) return(last_error);
   if (!InitMetrics())                return(last_error);

   if (IsTesting()) {                                       // read test configuration
      string section = ProgramName() +".Tester";
      test.onPositionOpenPause = GetConfigBool(section, "OnPositionOpenPause", false);
      test.optimizeStatus      = GetConfigBool(section, "OptimizeStatus", true);
   }
   return(catch("afterInit(1)"));
}


/**
 * Deinitialization
 *
 * @return int - error status
 */
int onDeinit() {
   int size = ArraySize(metrics.hSet);
   for (int i=0; i < size; i++) {
      CloseHistorySet(i);
   }

   if (IsTesting()) {
      if (!last_error || last_error==ERR_CANCELLED_BY_USER) {
         if (IsLogInfo()) {
            if (tradingMode!=TRADINGMODE_REGULAR || virt.closedPositions) logInfo("onDeinit(1)  "+ sequence.name +" test stop: "+ virt.closedPositions +" virtual trade"+ Pluralize(virt.closedPositions) +", pl="+ DoubleToStr(virt.closedPl, 2) +", plNet="+ DoubleToStr(virt.closedPlNet, 2));
            if (tradingMode!=TRADINGMODE_VIRTUAL || real.closedPositions) logInfo("onDeinit(2)  "+ sequence.name +" test stop: "+ real.closedPositions +" real trade"+ Pluralize(real.closedPositions) +", pl="+ DoubleToStr(real.closedPl, 2) +", plNet="+ DoubleToStr(real.closedPlNet, 2));
         }
         if (!SaveStatus()) return(last_error);
      }
   }
   return(catch("onDeinit(2)"));
}


/**
 * Called before input parameters change.
 *
 * @return int - error status
 */
int onDeinitParameters() {
   BackupInputs();
   return(-1);                                                    // -1: skip all other deinit tasks
}


/**
 * Called before the current chart symbol or timeframe change.
 *
 * @return int - error status
 */
int onDeinitChartChange() {
   BackupInputs();
   return(-1);                                                    // -1: skip all other deinit tasks
}


/**
 * Synchronize the trade copier with virtual trading.
 *
 * @return bool - success status
 */
bool SynchronizeTradeCopier() {
   if (real.isSynchronized) return(true);

   if (!virt.isOpenOrder) {
      if (real.isOpenOrder) return(!catch("SynchronizeTradeCopier(1)  "+ sequence.name +" virt.isOpenOrder=FALSE  real.isOpenOrder=TRUE", ERR_ILLEGAL_STATE));
      real.isSynchronized = true;
      return(true);
   }

   int iV = ArraySize(virt.ticket)-1;
   int iR = ArraySize(real.ticket)-1, oe[];

   if (virt.isOpenPosition) {
      if (real.isOpenPosition) {
         // an open position exists, check directions
         if (virt.openType[iV] != real.openType[iR])                            return(!catch("SynchronizeTradeCopier(2)  "+ sequence.name +" trade direction mis-match: virt.openType="+ OperationTypeDescription(virt.openType[iV]) +", real.openType="+ OperationTypeDescription(real.openType[iR]), ERR_ILLEGAL_STATE));
         // check tickets
         if (virt.linkedTicket[iV] && virt.linkedTicket[iV] != real.ticket[iR]) return(!catch("SynchronizeTradeCopier(3)  "+ sequence.name +" ticket mis-match: virt.linkedTicket="+ virt.linkedTicket[iV] +", real.ticket="+ real.ticket[iR], ERR_ILLEGAL_STATE));
         if (real.linkedTicket[iR] && real.linkedTicket[iR] != virt.ticket[iV]) return(!catch("SynchronizeTradeCopier(4)  "+ sequence.name +" ticket mis-match: real.linkedTicket="+ real.linkedTicket[iR] +", virt.ticket="+ virt.ticket[iV], ERR_ILLEGAL_STATE));
         // update the link
         virt.linkedTicket[iV] = real.ticket[iR];
         real.linkedTicket[iR] = virt.ticket[iV];
      }
      else if (real.isOpenOrder) return(!catch("SynchronizeTradeCopier(5)  "+ sequence.name +" virt.isOpenPosition=TRUE  real.isPendingOrder=TRUE", ERR_NOT_IMPLEMENTED));
      else {
         // an open position doesn't exist, open it
         double lots    = CalculateLots(true); if (!lots) return(false);
         string comment = "XMT."+ sequence.name + ifString(ChannelBug, ".ChBug", "") + ifString(TakeProfitBug, ".TpBug", "");
         color  marker  = ifInt(virt.openType[iV]==OP_LONG, Blue, Red);

         OrderSendEx(Symbol(), virt.openType[iV], lots, NULL, orderSlippage, virt.stopLoss[iV], virt.takeProfit[iV], comment, orderMagicNumber, NULL, marker, NULL, oe);
         if (oe.IsError(oe)) return(false);

         // update the link
         Orders.AddRealTicket(oe.Ticket(oe), virt.ticket[iV], oe.Lots(oe), OP_UNDEFINED, NULL, oe.Type(oe), oe.OpenTime(oe), oe.OpenPrice(oe), NULL, NULL, oe.StopLoss(oe), oe.TakeProfit(oe), NULL, NULL);
         virt.linkedTicket[iV] = oe.Ticket(oe);
      }
   }
   else return(!catch("SynchronizeTradeCopier(6)  "+ sequence.name +" virt.isPendingOrder=TRUE, synchronization not implemented", ERR_NOT_IMPLEMENTED));

   real.isSynchronized = true;
   return(SaveStatus());
}


/**
 * Synchronize the trade mirror with virtual trading.
 *
 * @return bool - success status
 */
bool SynchronizeTradeMirror() {
   if (real.isSynchronized) return(true);

   if (!virt.isOpenOrder) {
      if (real.isOpenOrder) return(!catch("SynchronizeTradeMirror(1)  "+ sequence.name +" virt.isOpenOrder=FALSE  real.isOpenOrder=TRUE", ERR_ILLEGAL_STATE));
      real.isSynchronized = true;
      return(true);
   }

   int iV = ArraySize(virt.ticket)-1;
   int iR = ArraySize(real.ticket)-1, oe[];

   if (virt.isOpenPosition) {
      if (real.isOpenPosition) {
         // an open position exists, check directions
         if (virt.openType[iV] == real.openType[iR])                            return(!catch("SynchronizeTradeMirror(2)  "+ sequence.name +" trade direction mis-match: virt.openType="+ OperationTypeDescription(virt.openType[iV]) +", real.openType="+ OperationTypeDescription(real.openType[iR]), ERR_ILLEGAL_STATE));
         // check tickets
         if (virt.linkedTicket[iV] && virt.linkedTicket[iV] != real.ticket[iR]) return(!catch("SynchronizeTradeMirror(3)  "+ sequence.name +" ticket mis-match: virt.linkedTicket="+ virt.linkedTicket[iV] +", real.ticket="+ real.ticket[iR], ERR_ILLEGAL_STATE));
         if (real.linkedTicket[iR] && real.linkedTicket[iR] != virt.ticket[iV]) return(!catch("SynchronizeTradeMirror(4)  "+ sequence.name +" ticket mis-match: real.linkedTicket="+ real.linkedTicket[iR] +", virt.ticket="+ virt.ticket[iV], ERR_ILLEGAL_STATE));
         // update the link
         virt.linkedTicket[iV] = real.ticket[iR];
         real.linkedTicket[iR] = virt.ticket[iV];
      }
      else if (real.isOpenOrder) return(!catch("SynchronizeTradeMirror(5)  "+ sequence.name +" virt.isOpenPosition=TRUE  real.isPendingOrder=TRUE", ERR_NOT_IMPLEMENTED));
      else {
         // an open position doesn't exist, open it
         int    type    = ifInt(virt.openType[iV]==OP_BUY, OP_SELL, OP_BUY);     // opposite direction
         double lots    = CalculateLots(true); if (!lots) return(false);
         string comment = "XMT."+ sequence.name + ifString(ChannelBug, ".ChBug", "") + ifString(TakeProfitBug, ".TpBug", "");
         color  marker  = ifInt(virt.openType[iV]==OP_LONG, Red, Blue);

         OrderSendEx(Symbol(), type, lots, NULL, orderSlippage, virt.takeProfit[iV], virt.stopLoss[iV], comment, orderMagicNumber, NULL, marker, NULL, oe);
         if (oe.IsError(oe)) return(false);

         // update the link
         Orders.AddRealTicket(oe.Ticket(oe), virt.ticket[iV], oe.Lots(oe), OP_UNDEFINED, NULL, oe.Type(oe), oe.OpenTime(oe), oe.OpenPrice(oe), NULL, NULL, oe.StopLoss(oe), oe.TakeProfit(oe), NULL, NULL);
         virt.linkedTicket[iV] = oe.Ticket(oe);
      }
   }
   else return(!catch("SynchronizeTradeMirror(6)  "+ sequence.name +" virt.isPendingOrder=TRUE, synchronization not implemented", ERR_NOT_IMPLEMENTED));

   real.isSynchronized = true;
   return(SaveStatus());
}


/**
 * Update real order status and PL statistics.
 *
 * @return bool - success status
 */
bool UpdateRealOrderStatus() {
   if (last_error != 0) return(false);

   // open PL statistics are fully recalculated
   real.isOpenOrder    = false;
   real.isOpenPosition = false;
   real.openLots       = 0;
   real.openCommission = 0;
   real.openPl         = 0;
   real.openPlNet      = 0;
   real.openPip        = 0;
   real.openPipNet     = 0;

   bool saveStatus = false;
   int orders = ArraySize(real.ticket);

   // update ticket status
   for (int i=orders-1; i >= 0; i--) {                            // iterate backwards and stop at the first closed ticket
      if (real.closeTime[i] > 0) break;                           // to increase performance
      if (!SelectTicket(real.ticket[i], "UpdateRealOrderStatus(1)")) return(false);

      bool wasPending     = (real.openType[i] == OP_UNDEFINED);
      bool isPending      = (OrderType() > OP_SELL);
      bool wasPosition    = !wasPending;
      bool isOpen         = !OrderCloseTime();
      bool isClosed       = !isOpen;
      real.isOpenOrder    = real.isOpenOrder || isOpen;
      real.isOpenPosition = real.isOpenPosition || (!isPending && isOpen);

      if (wasPending) {
         if (isClosed) {                                          // the pending order was cancelled (externally)
            onRealOrderDelete(i);                                 // removes the order record
            saveStatus = true;
            orders--;
            continue;
         }
         else {
            if (!isPending) {                                     // the pending order was filled
               onRealPositionOpen(i);                             // updates the order record
               wasPosition = true;                                // mark as a known open position
               saveStatus = true;
            }
         }
      }

      if (wasPosition) {
         real.commission[i] = OrderCommission();
         real.profit    [i] = OrderProfit();

         if (isOpen) {
            real.openLots       += ifDouble(real.openType[i]==OP_BUY, real.lots[i], -real.lots[i]);
            real.openCommission += real.commission[i];
            real.openPl         += real.profit    [i];
            real.openPip        += ifDouble(real.openType[i]==OP_BUY, Bid-real.openPrice[i], real.openPrice[i]-Ask)/Pip;
         }
         else /*isClosed*/ {                                      // the position was closed
            onRealPositionClose(i);                               // updates the order record
            real.closedPositions++;                               // update closed trade statistics
            real.closedLots       += real.lots      [i];
            real.closedCommission += real.commission[i];
            real.closedPl         += real.profit    [i];
            real.closedPip        += ifDouble(real.openType[i]==OP_BUY, real.closePrice[i]-real.openPrice[i], real.openPrice[i]-real.closePrice[i])/Pip;
            saveStatus = true;
         }
      }
   }

   real.openPlNet    = real.openPl     + real.openCommission;
   real.openPipNet   = real.openPip    - commissionPip;
   real.closedPlNet  = real.closedPl   + real.closedCommission;
   real.closedPipNet = real.closedPip  - commissionPip;
   real.totalPl      = real.openPl     + real.closedPl;
   real.totalPlNet   = real.openPlNet  + real.closedPlNet;
   real.totalPip     = real.openPip    + real.closedPip;
   real.totalPipNet  = real.openPipNet + real.closedPipNet;

   if (saveStatus) SaveStatus();
   return(!catch("UpdateRealOrderStatus(2)"));
}


/**
 * Update virtual order status PL statistics.
 *
 * @return bool - success status
 */
bool UpdateVirtualOrderStatus() {
   if (last_error != 0) return(false);

   // open order statistics are fully recalculated
   virt.isOpenOrder    = false;
   virt.isOpenPosition = false;
   virt.openLots       = 0;
   virt.openCommission = 0;
   virt.openPl         = 0;
   virt.openPlNet      = 0;
   virt.openPip        = 0;
   virt.openPipNet     = 0;

   bool saveStatus = false;
   int orders = ArraySize(virt.ticket);

   for (int i=orders-1; i >= 0; i--) {                            // iterate backwards and stop at the first closed ticket
      if (virt.closeTime[i] > 0) break;                           // to increase performance
      virt.isOpenOrder = true;

      bool wasPending = (virt.openType[i] == OP_UNDEFINED);
      bool isPending  = wasPending;
      if (wasPending) {
         if      (virt.pendingType[i] == OP_BUYLIMIT)  { if (LE(Ask, virt.pendingPrice[i])) isPending = false; }
         else if (virt.pendingType[i] == OP_BUYSTOP)   { if (GE(Ask, virt.pendingPrice[i])) isPending = false; }
         else if (virt.pendingType[i] == OP_SELLLIMIT) { if (GE(Bid, virt.pendingPrice[i])) isPending = false; }
         else if (virt.pendingType[i] == OP_SELLSTOP)  { if (LE(Bid, virt.pendingPrice[i])) isPending = false; }
      }
      bool wasPosition = !wasPending;

      if (wasPending) {
         if (!isPending) {                                        // the entry limit was triggered
            onVirtualPositionOpen(i);
            wasPosition = true;                                   // mark as a known open position (may be opened and closed on the same tick)
         }
      }

      if (wasPosition) {
         bool isOpen = true;
         if (virt.openType[i] == OP_BUY) {
            if (virt.takeProfit[i] && GE(Bid, virt.takeProfit[i])) { virt.closePrice[i] = virt.takeProfit[i]; isOpen = false; }
            if (virt.stopLoss  [i] && LE(Bid, virt.stopLoss  [i])) { virt.closePrice[i] = virt.stopLoss  [i]; isOpen = false; }
         }
         else /*virt.openType[i] == OP_SELL*/ {
            if (virt.takeProfit[i] && LE(Ask, virt.takeProfit[i])) { virt.closePrice[i] = virt.takeProfit[i]; isOpen = false; }
            if (virt.stopLoss  [i] && GE(Ask, virt.stopLoss  [i])) { virt.closePrice[i] = virt.stopLoss  [i]; isOpen = false; }
         }

         if (isOpen) {
            double openPip       = ifDouble(virt.openType[i]==OP_BUY, Bid-virt.openPrice[i], virt.openPrice[i]-Ask)/Pip;
            virt.isOpenPosition  = true;
            virt.profit[i]       = openPip * PipValue(virt.lots[i]);
            virt.openLots       += ifDouble(virt.openType[i]==OP_BUY, virt.lots[i], -virt.lots[i]);
            virt.openCommission += virt.commission[i];
            virt.openPl         += virt.profit    [i];
            virt.openPip        += openPip;
         }
         else /*isClosed*/ {                                      // an exit limit was triggered
            virt.isOpenOrder = false;                             // mark order status
            onVirtualPositionClose(i);                            // updates order record and PL
            virt.closedPositions++;                               // update closed trade statistics
            virt.closedLots       += virt.lots      [i];
            virt.closedCommission += virt.commission[i];
            virt.closedPl         += virt.profit    [i];
            virt.closedPip        += ifDouble(virt.openType[i]==OP_BUY, virt.closePrice[i]-virt.openPrice[i], virt.openPrice[i]-virt.closePrice[i])/Pip;
            saveStatus = true;
         }
      }
   }

   virt.openPlNet    = virt.openPl     + virt.openCommission;
   virt.openPipNet   = virt.openPip    - commissionPip;
   virt.closedPlNet  = virt.closedPl   + virt.closedCommission;
   virt.closedPipNet = virt.closedPip  - commissionPip;
   virt.totalPl      = virt.openPl     + virt.closedPl;
   virt.totalPlNet   = virt.openPlNet  + virt.closedPlNet;
   virt.totalPip     = virt.openPip    + virt.closedPip;
   virt.totalPipNet  = virt.openPipNet + virt.closedPipNet;

   if (saveStatus) SaveStatus();
   return(!catch("UpdateVirtualOrderStatus(2)"));
}


/**
 * Handle a real PositionOpen event. The referenced ticket is selected.
 *
 * @param  int i - ticket index of the opened position
 *
 * @return bool - success status
 */
bool onRealPositionOpen(int i) {
   // update order log
   real.openType  [i] = OrderType();
   real.openTime  [i] = OrderOpenTime();
   real.openPrice [i] = OrderOpenPrice();
   real.commission[i] = OrderCommission();
   real.profit    [i] = OrderProfit();

   if (IsLogDebug()) {
      // #1 Stop Sell 0.1 GBPUSD at 1.5457'2[ "comment"] was filled[ at 1.5457'2] ([slippage: +0.3 pip, ]market: Bid/Ask)
      int    pendingType  = real.pendingType [i];
      double pendingPrice = real.pendingPrice[i];

      string sType         = OperationTypeDescription(pendingType);
      string sPendingPrice = NumberToStr(pendingPrice, PriceFormat);
      string sComment      = ""; if (StringLen(OrderComment()) > 0) sComment = " "+ DoubleQuoteStr(OrderComment());
      string message       = "#"+ OrderTicket() +" "+ sType +" "+ NumberToStr(OrderLots(), ".+") +" "+ Symbol() +" at "+ sPendingPrice + sComment +" was filled";
      string sSlippage     = "";

      if (NE(OrderOpenPrice(), pendingPrice, Digits)) {
         double slippage = NormalizeDouble((pendingPrice-OrderOpenPrice())/Pip, 1);
         if (OrderType() == OP_SELL) slippage = -slippage;
         sSlippage = "slippage: "+ NumberToStr(slippage, "+."+ (Digits & 1)) +" pip, ";
         message = message +" at "+ NumberToStr(OrderOpenPrice(), PriceFormat);
      }
      logDebug("onRealPositionOpen(1)  "+ sequence.name +" "+ message +" ("+ sSlippage +"market: "+ NumberToStr(Bid, PriceFormat) +"/"+ NumberToStr(Ask, PriceFormat) +")");
   }

   if (IsTesting()) {
      if (__ExecutionContext[EC.extReporting] != 0) {
         Test_onPositionOpen(__ExecutionContext, OrderTicket(), OrderType(), OrderLots(), OrderSymbol(), OrderOpenTime(), OrderOpenPrice(), OrderStopLoss(), OrderTakeProfit(), OrderCommission(), OrderMagicNumber(), OrderComment());
      }
      // pause the test if configured
      if (IsVisualMode() && test.onPositionOpenPause) Tester.Pause("onRealPositionOpen(2)");
   }
   return(!catch("onRealPositionOpen(3)"));
}


/**
 * Handle a virtual PositionOpen event.
 *
 * @param  int i - ticket index of the opened position
 *
 * @return bool - success status
 */
bool onVirtualPositionOpen(int i) {
   return(!catch("onVirtualPositionOpen(1)  "+ sequence.name, ERR_NOT_IMPLEMENTED));
}


/**
 * Handle a real PositionClose event. The referenced ticket is selected.
 *
 * @param  int i - ticket index of the closed position
 *
 * @return bool - success status
 */
bool onRealPositionClose(int i) {
   // update order log
   real.closeTime [i] = OrderCloseTime();
   real.closePrice[i] = OrderClosePrice();
   real.commission[i] = OrderCommission();
   real.profit    [i] = OrderProfit();

   if (IsLogDebug()) {
      // #1 Sell 0.1 GBPUSD "comment" at 1.5457'2 was closed at 1.5457'2 (market: Bid/Ask)
      string sType       = OperationTypeDescription(OrderType());
      string sOpenPrice  = NumberToStr(OrderOpenPrice(), PriceFormat);
      string sClosePrice = NumberToStr(OrderClosePrice(), PriceFormat);
      string sComment    = ""; if (StringLen(OrderComment()) > 0) sComment = " "+ DoubleQuoteStr(OrderComment());
      string message     = "#"+ OrderTicket() +" "+ sType +" "+ NumberToStr(OrderLots(), ".+") +" "+ Symbol() + sComment +" at "+ sOpenPrice +" was closed at "+ sClosePrice;
      logDebug("onRealPositionClose(1)  "+ sequence.name +" "+ message +" (market: "+ NumberToStr(Bid, PriceFormat) +"/"+ NumberToStr(Ask, PriceFormat) +")");
   }

   if (IsTesting() && __ExecutionContext[EC.extReporting]) {
      Test_onPositionClose(__ExecutionContext, OrderTicket(), OrderCloseTime(), OrderClosePrice(), NULL, OrderProfit());
   }
   return(!catch("onRealPositionClose(2)"));
}


/**
 * Handle a virtual PositionClose event.
 *
 * @param  int i - ticket index of the closed position
 *
 * @return bool - success status
 */
bool onVirtualPositionClose(int i) {
   // update order log
   virt.closeTime[i] = Tick.time;
   virt.profit   [i] = ifDouble(virt.openType[i]==OP_BUY, virt.closePrice[i]-virt.openPrice[i], virt.openPrice[i]-virt.closePrice[i])/Pip * PipValue(virt.lots[i]);

   if (IsLogDebug()) {
      // virtual #1 Sell 0.1 GBPUSD "comment" at 1.5457'2 was closed at 1.5457'2 [tp|sl] (market: Bid/Ask)
      string sType       = OperationTypeDescription(virt.openType[i]);
      string sOpenPrice  = NumberToStr(virt.openPrice[i], PriceFormat);
      string sClosePrice = NumberToStr(virt.closePrice[i], PriceFormat);
      string sCloseType  = "";
         if      (EQ(virt.closePrice[i], virt.takeProfit[i])) sCloseType = " [tp]";
         else if (EQ(virt.closePrice[i], virt.stopLoss  [i])) sCloseType = " [sl]";
      string comment = "XMT."+ sequence.name;

      logDebug("onVirtualPositionClose(1)  "+ sequence.name +" virtual #"+ virt.ticket[i] +" "+ sType +" "+ NumberToStr(virt.lots[i], ".+") +" "+ Symbol() +" \""+ comment +"\" at "+ sOpenPrice +" was closed at "+ sClosePrice + sCloseType +" (market: "+ NumberToStr(Bid, PriceFormat) +"/"+ NumberToStr(Ask, PriceFormat) +")");
   }
   return(!catch("onVirtualPositionClose(2)"));
}


/**
 * Handle a real OrderDelete event. The referenced ticket is selected.
 *
 * @param  int i - ticket index of the deleted order
 *
 * @return bool - success status
 */
bool onRealOrderDelete(int i) {
   if (tradingMode != TRADINGMODE_REGULAR) return(!catch("onRealOrderDelete(1)  "+ sequence.name +" deletion of pending orders in "+ TradingModeToStr(tradingMode) +" not implemented", ERR_NOT_IMPLEMENTED));

   if (IsLogDebug()) {
      // #1 Stop Sell 0.1 GBPUSD at 1.5457'2[ "comment"] was deleted
      int    pendingType  = real.pendingType [i];
      double pendingPrice = real.pendingPrice[i];

      string sType         = OperationTypeDescription(pendingType);
      string sPendingPrice = NumberToStr(pendingPrice, PriceFormat);
      string sComment      = ""; if (StringLen(OrderComment()) > 0) sComment = " "+ DoubleQuoteStr(OrderComment());
      string message       = "#"+ OrderTicket() +" "+ sType +" "+ NumberToStr(OrderLots(), ".+") +" "+ Symbol() +" at "+ sPendingPrice + sComment +" was deleted";
      logDebug("onRealOrderDelete(2)  "+ sequence.name +" "+ message);
   }
   return(Orders.RemoveRealTicket(real.ticket[i]));
}


/**
 * Whether the conditions of an entry signal are satisfied.
 *
 * @param  _Out_ int signal - identifier of the detected signal or NULL
 *
 * @return bool
 */
bool IsEntrySignal(int &signal) {
   signal = NULL;
   if (last_error || real.isOpenOrder || sessionbreak.active) return(false);

   double high = iHigh(NULL, IndicatorTimeframe, 0);
   double low  =  iLow(NULL, IndicatorTimeframe, 0);

   int error = GetLastError();
   if (!high || error) {
      if (error == ERS_HISTORY_UPDATE) SetLastError(error);
      else if (!error)                 catch("IsEntrySignal(1)  "+ sequence.name +" invalid bar high: 0", ERR_INVALID_MARKET_DATA);
      else                             catch("IsEntrySignal(2)  "+ sequence.name, error);
      return(false);
   }
   double barSize = high - low;
   if (__isChart) sCurrentBarSize = DoubleToStr(barSize/Pip, 1);

   if (UseSpreadMultiplier) {
      if (!avgSpread) /*&&*/ if (!CalculateSpreads())         return(false);
      if (currentSpread > MaxSpread || avgSpread > MaxSpread) return(false);
      minBarSize = avgSpread*Pip * SpreadMultiplier; if (__isChart) SS.MinBarSize();
   }

   //if (GE(barSize, minBarSize)) {                            // TODO: move double comparators to DLL, 4'310'258 ticks processed in 0:00:07.675
   if (barSize+0.00000001 >= minBarSize) {                     //                                       4'310'258 ticks processed in 0:00:06.755
      double channelHigh, channelLow, dNull;
      if (!GetIndicatorValues(channelHigh, channelLow, dNull)) return(false);

      if      (Bid < channelLow)    signal  = SIGNAL_LONG;
      else if (Bid > channelHigh)   signal  = SIGNAL_SHORT;
      if (signal && ReverseSignals) signal ^= 3;               // flip long and short bits: dec(3) = bin(0011)

      if (signal != NULL) {
         if (IsLogInfo()) logInfo("IsEntrySignal(3)  "+ sequence.name +" "+ ifString(signal==SIGNAL_LONG, "LONG", "SHORT") +" signal (barSize="+ DoubleToStr(barSize/Pip, 1) +", minBarSize="+ sMinBarSize +", channel="+ NumberToStr(channelHigh, PriceFormat) +"/"+ NumberToStr(channelLow, PriceFormat) +", market: "+ NumberToStr(Bid, PriceFormat) +"/"+ NumberToStr(Ask, PriceFormat) +")");
         return(true);
      }
   }
   return(false);
}


/**
 * Whether the current server time falls into a sessionbreak. On function return the global vars sessionbreak.starttime
 * and sessionbreak.endtime are up-to-date.
 *
 * @return bool
 */
bool IsSessionBreak() {
   if (last_error != NO_ERROR) return(false);

   datetime serverTime = Max(TimeCurrentEx(), TimeServer());

   // check whether to recalculate sessionbreak times
   if (serverTime >= sessionbreak.endtime) {
      int startOffset = Sessionbreak.StartTime % DAYS;            // sessionbreak start time in seconds since Midnight
      int endOffset   = Sessionbreak.EndTime % DAYS;              // sessionbreak end time in seconds since Midnight
      if (!startOffset && !endOffset)
         return(false);                                           // skip session breaks if both values are set to Midnight

      // calculate today's sessionbreak end time
      datetime fxtNow  = ServerToFxtTime(serverTime);
      datetime today   = fxtNow - fxtNow%DAYS;                    // today's Midnight in FXT
      datetime fxtTime = today + endOffset;                       // today's sessionbreak end time in FXT

      // determine the next regular sessionbreak end time
      int dow = TimeDayOfWeekEx(fxtTime);
      while (fxtTime <= fxtNow || dow==SATURDAY || dow==SUNDAY) {
         fxtTime += 1*DAY;
         dow = TimeDayOfWeekEx(fxtTime);
      }
      datetime fxtResumeTime = fxtTime;
      sessionbreak.endtime = FxtToServerTime(fxtResumeTime);

      // determine the corresponding sessionbreak start time
      datetime resumeDay = fxtResumeTime - fxtResumeTime%DAYS;    // resume day's Midnight in FXT
      fxtTime = resumeDay + startOffset;                          // resume day's sessionbreak start time in FXT

      dow = TimeDayOfWeekEx(fxtTime);
      while (fxtTime >= fxtResumeTime || dow==SATURDAY || dow==SUNDAY) {
         fxtTime -= 1*DAY;
         dow = TimeDayOfWeekEx(fxtTime);
      }
      sessionbreak.starttime = FxtToServerTime(fxtTime);

      if (IsLogDebug()) logDebug("IsSessionBreak(1)  "+ sequence.name +" recalculated "+ ifString(serverTime >= sessionbreak.starttime, "current", "next") +" sessionbreak: from "+ GmtTimeFormat(sessionbreak.starttime, "%a, %Y.%m.%d %H:%M:%S") +" to "+ GmtTimeFormat(sessionbreak.endtime, "%a, %Y.%m.%d %H:%M:%S"));
   }

   // perform the actual check
   return(serverTime >= sessionbreak.starttime);                  // here sessionbreak.endtime is always in the future
}


/**
 * Open a real order for the specified entry signal.
 *
 * @param  int signal - order entry signal: SIGNAL_LONG|SIGNAL_SHORT
 *
 * @return bool - success status
 */
bool OpenRealOrder(int signal) {
   if (IsLastError())                               return(false);
   if (signal!=SIGNAL_LONG && signal!=SIGNAL_SHORT) return(!catch("OpenRealOrder(1)  "+ sequence.name +" invalid parameter signal: "+ signal, ERR_INVALID_PARAMETER));

   double lots    = CalculateLots(true); if (!lots) return(false);
   double spread  = Ask-Bid, price, takeProfit, stopLoss;
   string comment = "XMT."+ sequence.name + ifString(ChannelBug, ".ChBug", "") + ifString(TakeProfitBug, ".TpBug", "");
   int iV, virtualTicket, oe[];

   // regular trading
   if (tradingMode == TRADINGMODE_REGULAR) {
      if (signal == SIGNAL_LONG) {
         price      = Ask + BreakoutReversal*Pip;
         takeProfit = price + TakeProfit*Pip;
         stopLoss   = price - spread - StopLoss*Pip;

         if (!BreakoutReversal) OrderSendEx(Symbol(), OP_BUY,     lots, NULL,  orderSlippage, stopLoss, takeProfit, comment, orderMagicNumber, NULL, Blue, NULL, oe);
         else                   OrderSendEx(Symbol(), OP_BUYSTOP, lots, price, NULL,          stopLoss, takeProfit, comment, orderMagicNumber, NULL, Blue, NULL, oe);
      }
      else /*signal == SIGNAL_SHORT*/ {
         price      = Bid - BreakoutReversal*Pip;
         takeProfit = price - TakeProfit*Pip;
         stopLoss   = price + spread + StopLoss*Pip;

         if (!BreakoutReversal) OrderSendEx(Symbol(), OP_SELL,     lots, NULL,  orderSlippage, stopLoss, takeProfit, comment, orderMagicNumber, NULL, Red, NULL, oe);
         else                   OrderSendEx(Symbol(), OP_SELLSTOP, lots, price, NULL,          stopLoss, takeProfit, comment, orderMagicNumber, NULL, Red, NULL, oe);
      }
   }

   // virtual-copier
   else if (tradingMode == TRADINGMODE_VIRTUAL_COPIER) {
      iV = ArraySize(virt.ticket)-1;
      if (virt.openType[iV] == OP_UNDEFINED) return(!catch("OpenRealOrder(2)  "+ sequence.name +" opening of pending orders in "+ TradingModeToStr(tradingMode) +" not implemented", ERR_NOT_IMPLEMENTED));

      takeProfit    = virt.takeProfit[iV];
      stopLoss      = virt.stopLoss  [iV];
      virtualTicket = virt.ticket    [iV];
      virt.linkedTicket[iV] = OrderSendEx(Symbol(), virt.openType[iV], lots, NULL, orderSlippage, stopLoss, takeProfit, comment, orderMagicNumber, NULL, Red, NULL, oe);
   }

   // virtual-mirror
   else if (tradingMode == TRADINGMODE_VIRTUAL_MIRROR) {
      iV = ArraySize(virt.ticket)-1;
      if (virt.openType[iV] == OP_UNDEFINED) return(!catch("OpenRealOrder(3)  "+ sequence.name +" opening of pending orders in "+ TradingModeToStr(tradingMode) +" not implemented", ERR_NOT_IMPLEMENTED));

      int type      = ifInt(virt.openType[iV]==OP_BUY, OP_SELL, OP_BUY);
      takeProfit    = virt.stopLoss  [iV];
      stopLoss      = virt.takeProfit[iV];
      virtualTicket = virt.ticket    [iV];
      virt.linkedTicket[iV] = OrderSendEx(Symbol(), type, lots, NULL, orderSlippage, stopLoss, takeProfit, comment, orderMagicNumber, NULL, Red, NULL, oe);
   }

   if (oe.IsError(oe)) return(false);

   int pendingType=OP_UNDEFINED, openType=OP_UNDEFINED, openTime;
   double pendingPrice, openPrice;

   if (IsPendingOrderType(oe.Type(oe))) { pendingType = oe.Type(oe); pendingPrice = oe.OpenPrice(oe);                             }
   else                                 { openType    = oe.Type(oe); openPrice    = oe.OpenPrice(oe); openTime = oe.OpenTime(oe); }
   if (!Orders.AddRealTicket(oe.Ticket(oe), virtualTicket, oe.Lots(oe), pendingType, pendingPrice, openType, openTime, openPrice, NULL, NULL, oe.StopLoss(oe), oe.TakeProfit(oe), NULL, NULL)) return(false);

   if (IsTesting()) {                                   // pause the test if configured
      if (IsVisualMode() && test.onPositionOpenPause) Tester.Pause("OpenRealOrder(4)");
   }
   return(SaveStatus());
}


/**
 * Open a virtual order for the specified entry signal.
 *
 * @param  int signal - order entry signal: SIGNAL_LONG|SIGNAL_SHORT
 *
 * @return bool - success status
 */
bool OpenVirtualOrder(int signal) {
   if (IsLastError()) return(false);

   int ticket, type, pendingType=OP_UNDEFINED, openType=OP_UNDEFINED, openTime;
   double price, pendingPrice, openPrice, stopLoss, takeProfit, spread=Ask-Bid;

   if (signal == SIGNAL_LONG) {
      type       = ifInt(BreakoutReversal, OP_BUYSTOP, OP_BUY);
      price      = Ask + BreakoutReversal*Pip;
      takeProfit = price + TakeProfit*Pip;
      stopLoss   = price - spread - StopLoss*Pip;
   }
   else if (signal == SIGNAL_SHORT) {
      type       = ifInt(BreakoutReversal, OP_SELLSTOP, OP_SELL);
      price      = Bid - BreakoutReversal*Pip;
      takeProfit = price - TakeProfit*Pip;
      stopLoss   = price + spread + StopLoss*Pip;
   }
   else return(!catch("OpenVirtualOrder(1)  "+ sequence.name +" invalid parameter signal: "+ signal, ERR_INVALID_PARAMETER));

   double lots       = CalculateLots();      if (!lots)               return(false);
   double commission = GetCommission(-lots); if (IsEmpty(commission)) return(false);
   string comment    = "XMT."+ sequence.name;

   if (IsPendingOrderType(type)) { pendingType = type; pendingPrice = price;                       }
   else                          { openType    = type; openPrice    = price; openTime = Tick.time; }
   if (!Orders.AddVirtualTicket(ticket, NULL, lots, pendingType, pendingPrice, openType, openTime, openPrice, NULL, NULL, stopLoss, takeProfit, commission, NULL)) return(false);

   // opened virt. #1 Buy 0.5 GBPUSD "XMT" at 1.5524'8, sl=1.5500'0, tp=1.5600'0 (market: Bid/Ask)
   if (IsLogDebug()) logDebug("OpenVirtualOrder(2)  "+ sequence.name +" opened virtual #"+ ticket +" "+ OperationTypeDescription(type) +" "+ NumberToStr(lots, ".+") +" "+ Symbol() +" \""+ comment +"\" at "+ NumberToStr(price, PriceFormat) +", sl="+ NumberToStr(stopLoss, PriceFormat) +", tp="+ NumberToStr(takeProfit, PriceFormat) +" (market: "+ NumberToStr(Bid, PriceFormat) +"/"+ NumberToStr(Ask, PriceFormat) +")");

   if (IsTesting()) {                                   // pause the test if configured
      if (IsVisualMode() && test.onPositionOpenPause) Tester.Pause("OpenVirtualOrder(3)");
   }
   return(SaveStatus());
}


/**
 * Manage a real pending order (there can be only one).
 *
 * @return bool - success status
 */
bool ManagePendingOrder() {
   if (tradingMode != TRADINGMODE_REGULAR)       return(!catch("ManagePendingOrder(1)  "+ sequence.name +" managing of pending orders in "+ TradingModeToStr(tradingMode) +" not implemented", ERR_NOT_IMPLEMENTED));
   if (!real.isOpenOrder || real.isOpenPosition) return(true);

   int i = ArraySize(real.ticket)-1, oe[];
   if (real.openType[i] != OP_UNDEFINED) return(!catch("ManagePendingOrder(2)  "+ sequence.name +" illegal order type "+ OperationTypeToStr(real.openType[i]) +" of expected pending order #"+ real.ticket[i], ERR_ILLEGAL_STATE));

   double openprice, stoploss, takeprofit, spread=Ask-Bid, channelMean, dNull;
   if (!GetIndicatorValues(dNull, dNull, channelMean)) return(false);

   switch (real.pendingType[i]) {
      case OP_BUYSTOP:
         if (GE(Bid, channelMean)) {                                    // delete the order if price reached mid of channel
            if (!OrderDeleteEx(real.ticket[i], CLR_NONE, NULL, oe)) return(false);
            Orders.RemoveRealTicket(real.ticket[i]);
            return(SaveStatus());
         }
         openprice = Ask + BreakoutReversal*Pip;                        // trail order entry in breakout direction

         if (GE(real.pendingPrice[i]-openprice, TrailEntryStep*Pip)) {
            stoploss   = openprice - spread - StopLoss*Pip;
            takeprofit = openprice + TakeProfit*Pip;
            if (!OrderModifyEx(real.ticket[i], openprice, stoploss, takeprofit, NULL, Lime, NULL, oe)) return(false);
         }
         break;

      case OP_SELLSTOP:
         if (LE(Bid, channelMean)) {                                    // delete the order if price reached mid of channel
            if (!OrderDeleteEx(real.ticket[i], CLR_NONE, NULL, oe)) return(false);
            Orders.RemoveRealTicket(real.ticket[i]);
            return(SaveStatus());
         }
         openprice = Bid - BreakoutReversal*Pip;                        // trail order entry in breakout direction

         if (GE(openprice-real.pendingPrice[i], TrailEntryStep*Pip)) {
            stoploss   = openprice + spread + StopLoss*Pip;
            takeprofit = openprice - TakeProfit*Pip;
            if (!OrderModifyEx(real.ticket[i], openprice, stoploss, takeprofit, NULL, Orange, NULL, oe)) return(false);
         }
         break;

      default:
         return(!catch("ManagePendingOrder(3)  "+ sequence.name +" illegal order type "+ OperationTypeToStr(real.pendingType[i]) +" of expected pending order #"+ real.ticket[i], ERR_ILLEGAL_STATE));
   }

   if (stoploss > 0) {
      real.pendingPrice[i] = NormalizeDouble(openprice, Digits);
      real.stopLoss    [i] = NormalizeDouble(stoploss, Digits);
      real.takeProfit  [i] = NormalizeDouble(takeprofit, Digits);
      SaveStatus();
   }
   return(true);
}


/**
 * Manage a virtual pending order (there can be only one).
 *
 * @return bool - success status
 */
bool ManageVirtualOrder() {
   return(!catch("ManageVirtualOrder(1)  "+ sequence.name, ERR_NOT_IMPLEMENTED));
}


/**
 * Manage a real open position (there can be only one).
 *
 * @return bool - success status
 */
bool ManageRealPosition() {
   if (!real.isOpenPosition) return(true);

   int i=ArraySize(real.ticket)-1, iR=i, iV, oe[];
   double takeProfit, stopLoss;

   // regular trading
   if (tradingMode == TRADINGMODE_REGULAR) {
      switch (real.openType[i]) {
         case OP_BUY:
            if      (TakeProfitBug)                                 takeProfit = Ask + TakeProfit*Pip;   // erroneous TP calculation
            else if (GE(Bid-real.openPrice[i], TrailExitStart*Pip)) takeProfit = Bid + TakeProfit*Pip;   // correct TP calculation, also check trail-start
            else                                                    takeProfit = INT_MIN;

            if (GE(takeProfit-real.takeProfit[i], TrailExitStep*Pip)) {
               stopLoss = Bid - StopLoss*Pip;
               if (!OrderModifyEx(real.ticket[i], NULL, stopLoss, takeProfit, NULL, Lime, NULL, oe)) return(false);
            }
            break;

         case OP_SELL:
            if      (TakeProfitBug)                                 takeProfit = Bid - TakeProfit*Pip;   // erroneous TP calculation
            else if (GE(real.openPrice[i]-Ask, TrailExitStart*Pip)) takeProfit = Ask - TakeProfit*Pip;   // correct TP calculation, also check trail-start
            else                                                    takeProfit = INT_MAX;

            if (GE(real.takeProfit[i]-takeProfit, TrailExitStep*Pip)) {
               stopLoss = Ask + StopLoss*Pip;
               if (!OrderModifyEx(real.ticket[i], NULL, stopLoss, takeProfit, NULL, Orange, NULL, oe)) return(false);
            }
            break;

         default:
            return(!catch("ManageRealPosition(1)  "+ sequence.name +" illegal order type "+ OperationTypeToStr(real.openType[i]) +" of expected open position #"+ real.ticket[i], ERR_ILLEGAL_STATE));
      }
   }

   // virtual-copier
   else if (tradingMode == TRADINGMODE_VIRTUAL_COPIER) {
      iV = ArraySize(virt.ticket)-1;

      if (NE(real.takeProfit[iR], virt.takeProfit[iV]) || NE(real.stopLoss[iR], virt.stopLoss[iV])) {
         takeProfit = virt.takeProfit[iV];
         stopLoss   = virt.stopLoss  [iV];
         if (!OrderModifyEx(real.ticket[i], NULL, stopLoss, takeProfit, NULL, Lime, NULL, oe)) return(false);
      }
   }

   // virtual-mirror
   else if (tradingMode == TRADINGMODE_VIRTUAL_MIRROR) {
      iV = ArraySize(virt.ticket)-1;

      if (NE(real.takeProfit[iR], virt.stopLoss[iV]) || NE(real.stopLoss[iR], virt.takeProfit[iV])) {
         takeProfit = virt.stopLoss  [iV];
         stopLoss   = virt.takeProfit[iV];
         if (!OrderModifyEx(real.ticket[i], NULL, stopLoss, takeProfit, NULL, Lime, NULL, oe)) return(false);
      }
   }

   if (stopLoss > 0) {
      real.takeProfit[i] = NormalizeDouble(takeProfit, Digits);
      real.stopLoss  [i] = NormalizeDouble(stopLoss, Digits);
      SaveStatus();
   }
   return(true);
}


/**
 * Manage a virtual open position (there can be only one).
 *
 * @return bool - success status
 */
bool ManageVirtualPosition() {
   if (!virt.isOpenPosition) return(true);

   int i = ArraySize(virt.ticket)-1;
   double takeProfit, stopLoss;

   switch (virt.openType[i]) {
      case OP_BUY:
         if      (TakeProfitBug)                                   takeProfit = Ask + TakeProfit*Pip;    // erroneous TP calculation
         else if (GE(Bid-virt.openPrice[i], TrailExitStart*Pip))   takeProfit = Bid + TakeProfit*Pip;    // correct TP calculation, also check trail-start
         else                                                      takeProfit = INT_MIN;
         if (GE(takeProfit-virt.takeProfit[i], TrailExitStep*Pip)) stopLoss   = Bid - StopLoss*Pip;
         break;

      case OP_SELL:
         if      (TakeProfitBug)                                   takeProfit = Bid - TakeProfit*Pip;    // erroneous TP calculation
         else if (GE(virt.openPrice[i]-Ask, TrailExitStart*Pip))   takeProfit = Ask - TakeProfit*Pip;    // correct TP calculation, also check trail-start
         else                                                      takeProfit = INT_MAX;
         if (GE(virt.takeProfit[i]-takeProfit, TrailExitStep*Pip)) stopLoss   = Ask + StopLoss*Pip;
         break;

      default:
         return(!catch("ManageVirtualPosition(1)  "+ sequence.name +" illegal order type "+ OperationTypeToStr(virt.openType[i]) +" of expected virtual position #"+ virt.ticket[i], ERR_ILLEGAL_STATE));
   }

   if (stopLoss > 0) {
      virt.takeProfit[i] = NormalizeDouble(takeProfit, Digits);
      virt.stopLoss  [i] = NormalizeDouble(stopLoss, Digits);
      SaveStatus();
   }
   return(true);
}


/**
 * Check real profit targets and close all open orders if targets have been reached.
 *
 * @return bool - whether targets have been reached
 */
bool CheckRealTargets() {
   bool targetReached = false;
   string sCondition = "";

   if (StopOnTotalProfit != 0) {
      if (GE(real.totalPlNet, StopOnTotalProfit)) {
         targetReached = true;
         sCondition = "@totalProfit = "+ DoubleToStr(StopOnTotalProfit, 2);
      }
   }
   if (StopOnTotalLoss != 0) {
      if (LE(real.totalPlNet, StopOnTotalLoss)) {
         targetReached = true;
         sCondition = "@totalLoss = "+ DoubleToStr(StopOnTotalLoss, 2);
      }
   }
   if (targetReached) {
      if (IsLogNotice()) logNotice("CheckRealTargets(1)  "+ sequence.name +" stop condition "+ DoubleQuoteStr(sCondition) +" satisfied (market: "+ NumberToStr(Bid, PriceFormat) +"/"+ NumberToStr(Ask, PriceFormat) +")");
      CloseRealOrders();
   }
   return(targetReached);
}


/**
 * Close all real open orders.
 *
 * @return bool - success status
 */
bool CloseRealOrders() {
   if (IsLastError())     return(false);
   if (!real.isOpenOrder) return(true);

   int i = ArraySize(real.ticket)-1, oe[];

   if (real.isOpenPosition) {
      if (real.openType[i] == OP_UNDEFINED) return(!catch("CloseRealOrders(1)  "+ sequence.name +" illegal order type "+ OperationTypeToStr(real.openType[i]) +" of expected open position #"+ real.ticket[i], ERR_ILLEGAL_STATE));
      // close open position
      OrderCloseEx(real.ticket[i], NULL, NULL, CLR_NONE, NULL, oe);
   }
   else {
      if (real.openType[i] != OP_UNDEFINED) return(!catch("CloseRealOrders(2)  "+ sequence.name +" illegal order type "+ OperationTypeToStr(real.openType[i]) +" of expected pending order #"+ real.ticket[i], ERR_ILLEGAL_STATE));
      // delete pending order
      if (OrderDeleteEx(real.ticket[i], CLR_NONE, NULL, oe)) Orders.RemoveRealTicket(real.ticket[i]);
   }
   if (oe.IsError(oe)) return(false);

   UpdateRealOrderStatus();
   return(SaveStatus());
}


/**
 * Close all virtual open orders.
 *
 * @return bool - success status
 */
bool CloseVirtualOrders() {
   if (IsLastError())     return(false);
   if (!virt.isOpenOrder) return(true);

   int i = ArraySize(virt.ticket)-1;

   if (virt.isOpenPosition) {
      if (virt.openType[i] == OP_UNDEFINED) return(!catch("CloseVirtualOrders(1)  "+ sequence.name +" illegal order type "+ OperationTypeToStr(virt.openType[i]) +" of expected open position #"+ virt.ticket[i], ERR_ILLEGAL_STATE));
      // close virtual open position
      virt.closePrice[i] = ifDouble(virt.openType[i]==OP_BUY, Bid, Ask);
      onVirtualPositionClose(i);                         // updates virt.closeTime[i] and virt.profit[i]
      virt.closedPositions++;
      virt.closedLots       += virt.lots      [i];
      virt.closedCommission += virt.commission[i];
      virt.closedPl         += virt.profit    [i];
      virt.closedPip        += ifDouble(virt.openType[i]==OP_BUY, virt.closePrice[i]-virt.openPrice[i], virt.openPrice[i]-virt.closePrice[i])/Pip;
   }
   else {
      if (virt.openType[i] != OP_UNDEFINED) return(!catch("CloseVirtualOrders(1)  "+ sequence.name +" illegal order type "+ OperationTypeToStr(virt.openType[i]) +" of expected pending order #"+ virt.ticket[i], ERR_ILLEGAL_STATE));
      // delete virtual pending order
      return(!catch("CloseVirtualOrders(2)  "+ sequence.name +" deletion of virtual pending orders not implemented", ERR_NOT_IMPLEMENTED));

   }
   UpdateVirtualOrderStatus();
   return(SaveStatus());
}


/**
 * Calculate current and average spread. Online at least 30 ticks are collected before calculating an average.
 *
 * @return bool - success status; FALSE if the average is not yet available
 */
bool CalculateSpreads() {
   static bool lastResult = false;
   static int  lastTick; if (Tick == lastTick) {
      return(lastResult);
   }
   lastTick      = Tick;
   currentSpread = NormalizeDouble((Ask-Bid)/Pip, 1);

   if (IsTesting()) {
      avgSpread  = currentSpread; if (__isChart) SS.Spreads();
      lastResult = true;
      return(lastResult);
   }

   double spreads[30];
   ArrayCopy(spreads, spreads, 0, 1);
   spreads[29] = currentSpread;

   static int ticks = 0;
   if (ticks < 29) {
      ticks++;
      avgSpread  = NULL; if (__isChart) SS.Spreads();
      lastResult = false;
      return(lastResult);
   }

   double sum = 0;
   for (int i=0; i < ticks; i++) {
      sum += spreads[i];
   }
   avgSpread  = sum/ticks; if (__isChart) SS.Spreads();
   lastResult = true;

   return(lastResult);
}


/**
 * Return the indicator values forming the signal channel.
 *
 * @param  _Out_ double channelHigh - current upper channel band
 * @param  _Out_ double channelLow  - current lower channel band
 * @param  _Out_ double channelMean - current mid channel
 *
 * @return bool - success status
 */
bool GetIndicatorValues(double &channelHigh, double &channelLow, double &channelMean) {
   static double lastHigh, lastLow, lastMean;
   static int lastTick; if (Tick == lastTick) {
      channelHigh = lastHigh;                   // return cached values
      channelLow  = lastLow;
      channelMean = lastMean;
      return(true);
   }
   lastTick = Tick;

   if (EntryIndicator == 1) {
      channelHigh = iMA(Symbol(), IndicatorTimeframe, IndicatorPeriods, 0, MODE_LWMA, PRICE_HIGH, 0);
      channelLow  = iMA(Symbol(), IndicatorTimeframe, IndicatorPeriods, 0, MODE_LWMA, PRICE_LOW, 0);
      channelMean = (channelHigh + channelLow)/2;
   }
   else if (EntryIndicator == 2) {
      channelHigh = iBands(Symbol(), IndicatorTimeframe, IndicatorPeriods, BollingerBands.Deviation, 0, PRICE_OPEN, MODE_UPPER, 0);
      channelLow  = iBands(Symbol(), IndicatorTimeframe, IndicatorPeriods, BollingerBands.Deviation, 0, PRICE_OPEN, MODE_LOWER, 0);
      channelMean = (channelHigh + channelLow)/2;
   }
   else if (EntryIndicator == 3) {
      channelHigh = iEnvelopes(Symbol(), IndicatorTimeframe, IndicatorPeriods, MODE_LWMA, 0, PRICE_OPEN, Envelopes.Deviation, MODE_UPPER, 0);
      channelLow  = iEnvelopes(Symbol(), IndicatorTimeframe, IndicatorPeriods, MODE_LWMA, 0, PRICE_OPEN, Envelopes.Deviation, MODE_LOWER, 0);
      channelMean = (channelHigh + channelLow)/2;
   }
   else return(!catch("GetIndicatorValues(1)  "+ sequence.name +" illegal variable EntryIndicator: "+ EntryIndicator, ERR_ILLEGAL_STATE));

   if (ChannelBug) {                            // reproduce Capella's channel calculation bug (for comparison only)
      if (lastHigh && Bid < channelMean) {      // if enabled the function is called every tick
         channelHigh = lastHigh;
         channelLow  = lastLow;                 // return expired band values
      }
   }
   if (__isChart) {
      static string names[4] = {"", "MovingAverage", "BollingerBands", "Envelopes"};
      sIndicator = StringConcatenate(names[EntryIndicator], "    ", NumberToStr(channelMean, PriceFormat), "  ±", DoubleToStr((channelHigh-channelLow)/Pip/2, 1) ,"  (", NumberToStr(channelHigh, PriceFormat), "/", NumberToStr(channelLow, PriceFormat) ,")", ifString(ChannelBug, "   ChannelBug=1", ""));
   }

   lastHigh = channelHigh;                      // cache returned values
   lastLow  = channelLow;
   lastMean = channelMean;

   int error = GetLastError();
   if (!error)                      return(true);
   if (error == ERS_HISTORY_UPDATE) return(false);
   return(!catch("GetIndicatorValues(2)", error));
}


/**
 * Calculate the position size to use.
 *
 * @param  bool checkLimits [optional] - whether to check the symbol's lotsize contraints (default: no)
 *
 * @return double - position size or NULL in case of errors
 */
double CalculateLots(bool checkLimits = false) {
   checkLimits = checkLimits!=0;
   static double lots, lastLots;

   if (UseMoneyManagement) {
      double equity = AccountEquity() - AccountCredit();
      if (LE(equity, 0)) return(!catch("CalculateLots(1)  "+ sequence.name +" equity: "+ DoubleToStr(equity, 2), ERR_NOT_ENOUGH_MONEY));

      double riskPerTrade = Risk/100 * equity;                          // risked equity amount per trade
      double riskPerPip   = riskPerTrade/StopLoss;                      // risked equity amount per pip

      lots = NormalizeLots(riskPerPip/PipValue(), NULL, MODE_FLOOR);    // resulting normalized position size
      if (IsEmptyValue(lots)) return(NULL);

      if (checkLimits) {
         double minLots = MarketInfo(Symbol(), MODE_MINLOT);
         if (LT(lots, minLots)) return(!catch("CalculateLots(2)  "+ sequence.name +" equity: "+ DoubleToStr(equity, 2) +" (resulting position size smaller than MODE_MINLOT of "+ NumberToStr(minLots, ".1+") +")", ERR_NOT_ENOUGH_MONEY));

         double maxLots = MarketInfo(Symbol(), MODE_MAXLOT);
         if (GT(lots, maxLots)) {
            if (LT(lastLots, maxLots)) logNotice("CalculateLots(3)  "+ sequence.name +" limiting position size to MODE_MAXLOT: "+ NumberToStr(maxLots, ".+") +" lot");
            lots = maxLots;
         }
      }
   }
   else {
      lots = ManualLotsize;
   }
   lastLots = lots;

   if (__isChart) SS.UnitSize(lots);
   return(lots);
}


/**
 * Read and store the full order history.
 *
 * @return bool - success status
 */
bool ReadOrderLog() {
   int pendingType, openType, openTime;
   double pendingPrice, openPrice;

   ResetOrderLog(MODE_REAL);

   // all closed positions
   int orders = OrdersHistoryTotal();
   for (int i=0; i < orders; i++) {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) return(!catch("ReadOrderLog(1)", intOr(GetLastError(), ERR_RUNTIME_ERROR)));
      if (OrderMagicNumber() != orderMagicNumber) continue;
      if (OrderType() > OP_SELL)                  continue;
      if (OrderSymbol() != Symbol())              continue;

      if (!Orders.AddRealTicket(OrderTicket(), NULL, OrderLots(), OP_UNDEFINED, NULL, OrderType(), OrderOpenTime(), OrderOpenPrice(), OrderCloseTime(), OrderClosePrice(), OrderStopLoss(), OrderTakeProfit(), OrderCommission(), OrderProfit()))
         return(false);
   }

   // all open orders
   orders = OrdersTotal();
   for (i=0; i < orders; i++) {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) return(!catch("ReadOrderLog(2)", intOr(GetLastError(), ERR_RUNTIME_ERROR)));
      if (OrderMagicNumber() != orderMagicNumber) continue;
      if (OrderSymbol() != Symbol())              continue;

      if (IsPendingOrderType(OrderType())) {
         pendingType  = OrderType();
         pendingPrice = OrderOpenPrice();
         openType     = OP_UNDEFINED;
         openPrice    = NULL;
         openTime     = NULL;
      }
      else {
         pendingType  = OP_UNDEFINED;
         pendingPrice = NULL;
         openType     = OrderType();
         openPrice    = OrderOpenPrice();
         openTime     = OrderOpenTime();
      }
      if (!Orders.AddRealTicket(OrderTicket(), NULL, OrderLots(), pendingType, pendingPrice, openType, openTime, openPrice, NULL, NULL, OrderStopLoss(), OrderTakeProfit(), OrderCommission(), OrderProfit()))
         return(false);
   }
   return(!catch("ReadOrderLog(3)"));
}


/**
 * Reset the specified order log and statistics.
 *
 * @param  int mode - MODE_REAL:    real orders
 *                    MODE_VIRTUAL: virtual orders
 *
 * @return bool - success status
 */
bool ResetOrderLog(int mode) {
   if (mode == MODE_REAL) {
      ArrayResize(real.ticket,       0);
      ArrayResize(real.linkedTicket, 0);
      ArrayResize(real.lots,         0);
      ArrayResize(real.pendingType,  0);
      ArrayResize(real.pendingPrice, 0);
      ArrayResize(real.openType,     0);
      ArrayResize(real.openTime,     0);
      ArrayResize(real.openPrice,    0);
      ArrayResize(real.closeTime,    0);
      ArrayResize(real.closePrice,   0);
      ArrayResize(real.stopLoss,     0);
      ArrayResize(real.takeProfit,   0);
      ArrayResize(real.commission,   0);
      ArrayResize(real.profit,       0);

      real.isSynchronized   = false;
      real.isOpenOrder      = false;
      real.isOpenPosition   = false;

      real.openLots         = 0;
      real.openCommission   = 0;
      real.openPl           = 0;
      real.openPlNet        = 0;
      real.openPip          = 0;
      real.openPipNet       = 0;

      real.closedPositions  = 0;
      real.closedLots       = 0;
      real.closedCommission = 0;
      real.closedPl         = 0;
      real.closedPlNet      = 0;
      real.closedPip        = 0;
      real.closedPipNet     = 0;

      real.totalPl          = 0;
      real.totalPlNet       = 0;
      real.totalPip         = 0;
      real.totalPipNet      = 0;
      return(true);
   }

   if (mode == MODE_VIRTUAL) {
      ArrayResize(virt.ticket,       0);
      ArrayResize(virt.linkedTicket, 0);
      ArrayResize(virt.lots,         0);
      ArrayResize(virt.pendingType,  0);
      ArrayResize(virt.pendingPrice, 0);
      ArrayResize(virt.openType,     0);
      ArrayResize(virt.openTime,     0);
      ArrayResize(virt.openPrice,    0);
      ArrayResize(virt.closeTime,    0);
      ArrayResize(virt.closePrice,   0);
      ArrayResize(virt.stopLoss,     0);
      ArrayResize(virt.takeProfit,   0);
      ArrayResize(virt.commission,   0);
      ArrayResize(virt.profit,       0);

      virt.isOpenOrder      = false;
      virt.isOpenPosition   = false;

      virt.openLots         = 0;
      virt.openCommission   = 0;
      virt.openPl           = 0;
      virt.openPlNet        = 0;
      virt.openPip          = 0;
      virt.openPipNet       = 0;

      virt.closedPositions  = 0;
      virt.closedLots       = 0;
      virt.closedCommission = 0;
      virt.closedPl         = 0;
      virt.closedPlNet      = 0;
      virt.closedPip        = 0;
      virt.closedPipNet     = 0;

      virt.totalPl          = 0;
      virt.totalPlNet       = 0;
      virt.totalPip         = 0;
      virt.totalPipNet      = 0;
      return(true);
   }

   return(!catch("ResetOrderLog(1)  "+ sequence.name +" invalid parameter mode: "+ mode, ERR_INVALID_PARAMETER));
}


/**
 * Start the virtual trade copier.
 *
 * @return bool - success status
 */
bool StartTradeCopier() {
   if (IsLastError()) return(false);

   if (tradingMode == TRADINGMODE_VIRTUAL_MIRROR) {
      if (!StopTrading()) return(false);
   }

   if (tradingMode == TRADINGMODE_VIRTUAL) {
      tradingMode = TRADINGMODE_VIRTUAL_COPIER;
      TradingMode = tradingModeDescriptions[tradingMode]; SS.SequenceName();
      real.isSynchronized = false;
      InitMetrics();
      return(SaveStatus());
   }
   return(!catch("StartTradeCopier(1)  "+ sequence.name +" cannot start trade copier in "+ TradingModeToStr(tradingMode), ERR_ILLEGAL_STATE));
}


/**
 * Start the virtual trade mirror.
 *
 * @return bool - success status
 */
bool StartTradeMirror() {
   if (IsLastError()) return(false);

   if (tradingMode == TRADINGMODE_VIRTUAL_COPIER) {
      if (!StopTrading()) return(false);
   }

   if (tradingMode == TRADINGMODE_VIRTUAL) {
      tradingMode = TRADINGMODE_VIRTUAL_MIRROR;
      TradingMode = tradingModeDescriptions[tradingMode]; SS.SequenceName();
      real.isSynchronized = false;
      InitMetrics();
      return(SaveStatus());
   }
   return(!catch("StartTradeMirror(1)  "+ sequence.name +" cannot start trade mirror in "+ TradingModeToStr(tradingMode), ERR_ILLEGAL_STATE));
}


/**
 * Stop a running trade copier or mirror.
 *
 * @return bool - success status
 */
bool StopTrading() {
   if (IsLastError()) return(false);

   if (tradingMode==TRADINGMODE_VIRTUAL_COPIER || tradingMode==TRADINGMODE_VIRTUAL_MIRROR) {
      if (CloseRealOrders()) {
         tradingMode = TRADINGMODE_VIRTUAL;
         TradingMode = tradingModeDescriptions[tradingMode]; SS.SequenceName();
         InitMetrics();
         SaveStatus();
      }
      return(!last_error);
   }
   return(!catch("StopTrading(1)  "+ sequence.name +" cannot stop trading in "+ TradingModeToStr(tradingMode), ERR_ILLEGAL_STATE));
}


/**
 * Add a real order record to the order log and update statistics.
 *
 * @param  int      ticket
 * @param  int      linkedTicket
 * @param  double   lots
 * @param  int      pendingType
 * @param  double   pendingPrice
 * @param  int      openType
 * @param  datetime openTime
 * @param  double   openPrice
 * @param  datetime closeTime
 * @param  double   closePrice
 * @param  double   stopLoss
 * @param  double   takeProfit
 * @param  double   commission
 * @param  double   profit
 *
 * @return bool - success status
 */
bool Orders.AddRealTicket(int ticket, int linkedTicket, double lots, int pendingType, double pendingPrice, int openType, datetime openTime, double openPrice, datetime closeTime, double closePrice, double stopLoss, double takeProfit, double commission, double profit) {
   int pos = SearchIntArray(real.ticket, ticket);
   if (pos >= 0) return(!catch("Orders.AddRealTicket(1)  "+ sequence.name +" invalid parameter ticket: #"+ ticket +" (exists)", ERR_INVALID_PARAMETER));

   int i=ArraySize(real.ticket), newSize=i+1;
   ArrayResize(real.ticket,       newSize); real.ticket      [i] = ticket;
   ArrayResize(real.linkedTicket, newSize); real.linkedTicket[i] = linkedTicket;
   ArrayResize(real.lots,         newSize); real.lots        [i] = lots;
   ArrayResize(real.pendingType,  newSize); real.pendingType [i] = pendingType;
   ArrayResize(real.pendingPrice, newSize); real.pendingPrice[i] = NormalizeDouble(pendingPrice, Digits);
   ArrayResize(real.openType,     newSize); real.openType    [i] = openType;
   ArrayResize(real.openTime,     newSize); real.openTime    [i] = openTime;
   ArrayResize(real.openPrice,    newSize); real.openPrice   [i] = NormalizeDouble(openPrice, Digits);
   ArrayResize(real.closeTime,    newSize); real.closeTime   [i] = closeTime;
   ArrayResize(real.closePrice,   newSize); real.closePrice  [i] = NormalizeDouble(closePrice, Digits);
   ArrayResize(real.stopLoss,     newSize); real.stopLoss    [i] = NormalizeDouble(stopLoss, Digits);
   ArrayResize(real.takeProfit,   newSize); real.takeProfit  [i] = NormalizeDouble(takeProfit, Digits);
   ArrayResize(real.commission,   newSize); real.commission  [i] = commission;
   ArrayResize(real.profit,       newSize); real.profit      [i] = profit;

   bool isOpenOrder      = (!closeTime);
   bool isPosition       = (openType != OP_UNDEFINED);
   bool isOpenPosition   = (isPosition && !closeTime);
   bool isClosedPosition = (isPosition && closeTime);

   if (isOpenOrder) {
      if (real.isOpenOrder)    return(!catch("Orders.AddRealTicket(2)  "+ sequence.name +" cannot add open order #"+ ticket +" (another open order exists)", ERR_ILLEGAL_STATE));
      real.isOpenOrder = true;
   }
   if (isOpenPosition) {
      if (real.isOpenPosition) return(!catch("Orders.AddRealTicket(3)  "+ sequence.name +" cannot add open position #"+ ticket +" (another open position exists)", ERR_ILLEGAL_STATE));
      real.isOpenPosition = true;
      real.openLots       += ifDouble(IsLongOrderType(openType), lots, -lots);
      real.openCommission += commission;
      real.openPl         += profit;
      real.openPlNet       = real.openCommission + real.openPl;
      real.openPip        += ifDouble(IsLongOrderType(openType), Bid-real.openPrice[i], real.openPrice[i]-Ask)/Pip;
    //real.openPipNet      = ...
   }
   if (isClosedPosition) {
      real.closedPositions++;
      real.closedLots       += lots;
      real.closedCommission += commission;
      real.closedPl         += profit;
      real.closedPlNet       = real.closedCommission + real.closedPl;
      real.closedPip        += ifDouble(IsLongOrderType(openType), real.closePrice[i]-real.openPrice[i], real.openPrice[i]-real.closePrice[i])/Pip;
    //real.closedPipNet      = ...
   }
   if (isPosition) {
      real.totalPl     = real.openPl     + real.closedPl;
      real.totalPlNet  = real.openPlNet  + real.closedPlNet;
      real.totalPip    = real.openPip    + real.closedPip;
      real.totalPipNet = real.openPipNet + real.closedPipNet;
   }
   return(!catch("Orders.AddRealTicket(4)"));
}


/**
 * Add a virtual order record to the order log and update statistics.
 *
 * @param  _InOut_ int      &ticket - if 0 (NULL) a new ticket number is generated and assigned
 * @param  _In_    int      linkedTicket
 * @param  _In_    double   lots
 * @param  _In_    int      pendingType
 * @param  _In_    double   pendingPrice
 * @param  _In_    int      openType
 * @param  _In_    datetime openTime
 * @param  _In_    double   openPrice
 * @param  _In_    datetime closeTime
 * @param  _In_    double   closePrice
 * @param  _In_    double   stopLoss
 * @param  _In_    double   takeProfit
 * @param  _In_    double   commission
 * @param  _In_    double   profit
 *
 * @return bool - success status
 */
bool Orders.AddVirtualTicket(int &ticket, int linkedTicket, double lots, int pendingType, double pendingPrice, int openType, datetime openTime, double openPrice, datetime closeTime, double closePrice, double stopLoss, double takeProfit, double commission, double profit) {
   int pos = SearchIntArray(virt.ticket, ticket);
   if (pos >= 0) return(!catch("Orders.AddVirtualTicket(1)  "+ sequence.name +" invalid parameter ticket: #"+ ticket +" (exists)", ERR_INVALID_PARAMETER));

   int size=ArraySize(virt.ticket), newSize=size+1, i=size;
   if (!ticket) {
      if (!size) ticket = 1;
      else       ticket = virt.ticket[size-1] + 1;
   }
   ArrayResize(virt.ticket,       newSize); virt.ticket      [i] = ticket;
   ArrayResize(virt.linkedTicket, newSize); virt.linkedTicket[i] = linkedTicket;
   ArrayResize(virt.lots,         newSize); virt.lots        [i] = lots;
   ArrayResize(virt.pendingType,  newSize); virt.pendingType [i] = pendingType;
   ArrayResize(virt.pendingPrice, newSize); virt.pendingPrice[i] = NormalizeDouble(pendingPrice, Digits);
   ArrayResize(virt.openType,     newSize); virt.openType    [i] = openType;
   ArrayResize(virt.openTime,     newSize); virt.openTime    [i] = openTime;
   ArrayResize(virt.openPrice,    newSize); virt.openPrice   [i] = NormalizeDouble(openPrice, Digits);
   ArrayResize(virt.closeTime,    newSize); virt.closeTime   [i] = closeTime;
   ArrayResize(virt.closePrice,   newSize); virt.closePrice  [i] = NormalizeDouble(closePrice, Digits);
   ArrayResize(virt.stopLoss,     newSize); virt.stopLoss    [i] = NormalizeDouble(stopLoss, Digits);
   ArrayResize(virt.takeProfit,   newSize); virt.takeProfit  [i] = NormalizeDouble(takeProfit, Digits);
   ArrayResize(virt.commission,   newSize); virt.commission  [i] = commission;
   ArrayResize(virt.profit,       newSize); virt.profit      [i] = profit;

   bool isOpenOrder      = (!closeTime);
   bool isPosition       = (openType != OP_UNDEFINED);
   bool isOpenPosition   = (isPosition && !closeTime);
   bool isClosedPosition = (isPosition && closeTime);

   if (isOpenOrder) {
      if (virt.isOpenOrder)    return(!catch("Orders.AddVirtualTicket(2)  "+ sequence.name +" cannot add open order #"+ ticket +" (another open order exists)", ERR_ILLEGAL_STATE));
      virt.isOpenOrder = true;
   }
   if (isOpenPosition) {
      if (virt.isOpenPosition) return(!catch("Orders.AddVirtualTicket(3)  "+ sequence.name +" cannot add open position #"+ ticket +" (another open position exists)", ERR_ILLEGAL_STATE));
      virt.isOpenPosition = true;
      virt.openLots       += ifDouble(openType==OP_BUY, lots, -lots);
      virt.openCommission += commission;
      virt.openPl         += profit;
      virt.openPlNet       = virt.openCommission + virt.openPl;
      virt.openPip        += ifDouble(openType==OP_BUY, Bid-virt.openPrice[i], virt.openPrice[i]-Ask)/Pip;
    //virt.openPipNet      = ...
   }
   if (isClosedPosition) {
      virt.closedPositions++;
      virt.closedLots       += lots;
      virt.closedCommission += commission;
      virt.closedPl         += profit;
      virt.closedPlNet       = virt.closedCommission + virt.closedPl;
      virt.closedPip        += ifDouble(openType==OP_BUY, virt.closePrice[i]-virt.openPrice[i], virt.openPrice[i]-virt.closePrice[i])/Pip;
    //virt.closedPipNet      = ...
   }
   if (isPosition) {
      virt.totalPl     = virt.openPl     + virt.closedPl;
      virt.totalPlNet  = virt.openPlNet  + virt.closedPlNet;
      virt.totalPip    = virt.openPip    + virt.closedPip;
      virt.totalPipNet = virt.openPipNet + virt.closedPipNet;
   }
   return(!catch("Orders.AddVirtualTicket(4)"));
}


/**
 * Remove a record from the order log.
 *
 * @param  int ticket - ticket of the record
 *
 * @return bool - success status
 */
bool Orders.RemoveRealTicket(int ticket) {
   int pos = SearchIntArray(real.ticket, ticket);
   if (pos < 0)                            return(!catch("Orders.RemoveRealTicket(1)  "+ sequence.name +" invalid parameter ticket: #"+ ticket +" (not found)", ERR_INVALID_PARAMETER));
   if (real.openType[pos] != OP_UNDEFINED) return(!catch("Orders.RemoveRealTicket(2)  "+ sequence.name +" cannot remove an opened position: #"+ ticket, ERR_ILLEGAL_STATE));
   if (!real.isOpenOrder)                  return(!catch("Orders.RemoveRealTicket(3)  "+ sequence.name +" real.isOpenOrder is FALSE", ERR_ILLEGAL_STATE));

   ArraySpliceInts   (real.ticket,       pos, 1);
   ArraySpliceInts   (real.linkedTicket, pos, 1);
   ArraySpliceDoubles(real.lots,         pos, 1);
   ArraySpliceInts   (real.pendingType,  pos, 1);
   ArraySpliceDoubles(real.pendingPrice, pos, 1);
   ArraySpliceInts   (real.openType,     pos, 1);
   ArraySpliceInts   (real.openTime,     pos, 1);
   ArraySpliceDoubles(real.openPrice,    pos, 1);
   ArraySpliceInts   (real.closeTime,    pos, 1);
   ArraySpliceDoubles(real.closePrice,   pos, 1);
   ArraySpliceDoubles(real.stopLoss,     pos, 1);
   ArraySpliceDoubles(real.takeProfit,   pos, 1);
   ArraySpliceDoubles(real.commission,   pos, 1);
   ArraySpliceDoubles(real.profit,       pos, 1);

   real.isOpenOrder = false;

   return(!catch("Orders.RemoveRealTicket(4)"));
}


/**
 * Whether a chart command was sent to the expert. If true the command is retrieved and returned.
 *
 * @param  _InOut_ string &commands[] - array to add the received command to
 *
 * @return bool
 */
bool EventListener_ChartCommand(string &commands[]) {
   if (!__isChart) return(false);

   static string label="", mutex=""; if (!StringLen(label)) {
      label = ProgramName() +".command";
      mutex = "mutex."+ label;
   }

   // check for a command non-synchronized (read-only access) to prevent aquiring the lock on every tick
   if (ObjectFind(label) == 0) {
      // now aquire the lock for read-write access
      if (AquireLock(mutex, true)) {
         ArrayPushString(commands, ObjectDescription(label));
         ObjectDelete(label);
         return(ReleaseLock(mutex));
      }
   }
   return(false);
}


/**
 * Dispatch incoming commands.
 *
 * @param  string commands[] - received commands
 *
 * @return bool - success status of the executed command
 */
bool onCommand(string commands[]) {
   if (!ArraySize(commands)) return(!logWarn("onCommand(1)  "+ sequence.name +" empty parameter commands: {}"));
   string cmd = commands[0];
   if (IsLogInfo()) logInfo("onCommand(2)  "+ sequence.name +" "+ DoubleQuoteStr(cmd));

   if (cmd == "virtual") {
      switch (tradingMode) {
         case TRADINGMODE_VIRTUAL_COPIER:
         case TRADINGMODE_VIRTUAL_MIRROR:
            return(StopTrading());
      }
   }
   else if (cmd == "virtual-copier") {
      switch (tradingMode) {
         case TRADINGMODE_VIRTUAL:
         case TRADINGMODE_VIRTUAL_MIRROR:
            return(StartTradeCopier());
      }
   }
   else if (cmd == "virtual-mirror") {
      switch (tradingMode) {
         case TRADINGMODE_VIRTUAL:
         case TRADINGMODE_VIRTUAL_COPIER:
            return(StartTradeMirror());
      }
   }
   else return(_true(logWarn("onCommand(3)  "+ sequence.name +" unsupported command: "+ DoubleQuoteStr(cmd))));

   return(_true(logWarn("onCommand(4)  "+ sequence.name +" cannot execute "+ DoubleQuoteStr(cmd) +" command in "+ TradingModeToStr(tradingMode))));
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

   int strategy = STRATEGY_ID;                                 //  101-1023 (10 bit)
   int sequence = id;                                          // 1000-9999 (14 bit)

   return((strategy<<22) + (sequence<<8));                     // the remaining 8 bit are not used in this strategy
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
 * @return string - filename or an empty string in case of errors
 */
string GetStatusFilename() {
   if (!sequence.id) return(_EMPTY_STR(catch("GetStatusFilename(1)  "+ sequence.name +" illegal sequence.id: "+ sequence.id, ERR_ILLEGAL_STATE)));

   static string result = ""; if (!StringLen(result)) {
      string directory = "\\presets\\" + ifString(IsTesting(), "Tester", GetAccountCompany()) +"\\";
      string baseName  = StrToLower(Symbol()) +".XMT-Scalper."+ sequence.id +".set";
      result = GetMqlFilesPath() + directory + baseName;
   }
   return(result);
}


/**
 * Return a string representation of a virtual order record.
 *
 * @param  int  ticket
 *
 * @return string - string representation or an empty string in case of errors
 */
string DumpVirtualOrder(int ticket) {
   int i = SearchIntArray(virt.ticket, ticket);
   if (i < 0) return(_EMPTY_STR(catch("DumpVirtualOrder(1)  "+ sequence.name +" invalid parameter ticket: #"+ ticket +" (not found)", ERR_INVALID_PARAMETER)));

   string sLots         = NumberToStr(virt.lots[i], ".1+");
   string sPendingType  = ifString(virt.pendingType[i]==OP_UNDEFINED, "-", OrderTypeDescription(virt.pendingType[i]));
   string sPendingPrice = ifString(!virt.pendingPrice[i], "0", NumberToStr(virt.pendingPrice[i], PriceFormat));
   string sOpenType     = ifString(virt.openType[i]==OP_UNDEFINED, "-", OrderTypeDescription(virt.openType[i]));
   string sOpenTime     = ifString(!virt.openTime[i], "0", TimeToStr(virt.openTime[i], TIME_FULL));
   string sOpenPrice    = ifString(!virt.openPrice[i], "0", NumberToStr(virt.openPrice[i], PriceFormat));
   string sCloseTime    = ifString(!virt.closeTime[i], "0", TimeToStr(virt.closeTime[i], TIME_FULL));
   string sClosePrice   = ifString(!virt.closePrice[i], "0", NumberToStr(virt.closePrice[i], PriceFormat));
   string sTakeProfit   = ifString(!virt.takeProfit[i], "0", NumberToStr(virt.takeProfit[i], PriceFormat));
   string sStopLoss     = ifString(!virt.stopLoss[i], "0", NumberToStr(virt.stopLoss[i], PriceFormat));
   string sCommission   = DoubleToStr(virt.commission[i], 2);
   string sProfit       = DoubleToStr(virt.profit[i], 2);

   return("virtual #"+ ticket +": lots="+ sLots +", pendingType="+ sPendingType +", pendingPrice="+ sPendingPrice +", openType="+ sOpenType +", openTime="+ sOpenTime +", openPrice="+ sOpenPrice +", closeTime="+ sCloseTime +", closePrice="+ sClosePrice +", takeProfit="+ sTakeProfit +", stopLoss="+ sStopLoss +", commission="+ sCommission +", profit="+ sProfit);
}


/**
 * Return a readable version of a trading mode.
 *
 * @param  int mode - trading mode
 *
 * @return string
 */
string TradingModeToStr(int mode) {
   switch (mode) {
      case TRADINGMODE_REGULAR       : return("TRADINGMODE_REGULAR"       );
      case TRADINGMODE_VIRTUAL       : return("TRADINGMODE_VIRTUAL"       );
      case TRADINGMODE_VIRTUAL_COPIER: return("TRADINGMODE_VIRTUAL_COPIER");
      case TRADINGMODE_VIRTUAL_MIRROR: return("TRADINGMODE_VIRTUAL_MIRROR");
   }
   return(_EMPTY_STR(catch("TradingModeToStr(1)  "+ sequence.name +" invalid parameter mode: "+ mode, ERR_INVALID_PARAMETER)));
}


/**
 * Restore the internal state of the EA from a status file. Requires a valid sequence id.
 *
 * @return bool - success status
 */
bool RestoreSequence() {
   if (IsLastError())        return(false);
   if (!ReadStatus())        return(false);                 // read the status file
   if (!ValidateInputs())    return(false);                 // validate restored input parameters
 //if (!SynchronizeStatus()) return(false);                 // synchronize restored state with the trade server

   return(true);
   if (!ReadOrderLog()) return(false);                      // TODO: where does this go to?
}


/**
 * Read the status file of the sequence and set input parameters and internal variables. Called only from RestoreSequence().
 *
 * @return bool - success status
 */
bool ReadStatus() {
   if (IsLastError()) return(false);
   if (!sequence.id)  return(!catch("ReadStatus(1)  illegal value of sequence.id: "+ sequence.id, ERR_ILLEGAL_STATE));

   string section="", file=GetStatusFilename();
   if (!IsFile(file, MODE_OS)) return(!catch("ReadStatus(2)  status file "+ DoubleQuoteStr(file) +" not found", ERR_FILE_NOT_FOUND));

   // [General]
   section = "General";
   string sAccount = GetIniStringA(file, section, "Account", "");                                     // string Account = ICMarkets:12345678
   string sSymbol  = GetIniStringA(file, section, "Symbol",  "");                                     // string Symbol  = EURUSD
   string sThisAccount = GetAccountCompany() +":"+ GetAccountNumber();
   if (sAccount != sThisAccount) return(!catch("ReadStatus(3)  account mis-match: "+ DoubleQuoteStr(sThisAccount) +" vs. "+ DoubleQuoteStr(sAccount) +" in status file "+ DoubleQuoteStr(file), ERR_INVALID_CONFIG_VALUE));
   if (sSymbol  != Symbol())     return(!catch("ReadStatus(4)  symbol mis-match: "+ Symbol() +" vs. "+ sSymbol +" in status file "+ DoubleQuoteStr(file), ERR_INVALID_CONFIG_VALUE));

   // [Inputs]
   section = "Inputs";
   string sSequenceId               = GetIniStringA(file, section, "Sequence.ID",              "");    // string   Sequence.ID              = 1234
   string sTradingMode              = GetIniStringA(file, section, "TradingMode",              "");    // string   TradingMode              = Regular

   string sEntryIndicator           = GetIniStringA(file, section, "EntryIndicator",           "");    // int      EntryIndicator           = 1
   string sIndicatorTimeframe       = GetIniStringA(file, section, "IndicatorTimeframe",       "");    // int      IndicatorTimeframe       = 1
   string sIndicatorPeriods         = GetIniStringA(file, section, "IndicatorPeriods",         "");    // int      IndicatorPeriods         = 3
   string sBollingerBandsDeviation  = GetIniStringA(file, section, "BollingerBands.Deviation", "");    // double   BollingerBands.Deviation = 2.0
   string sEnvelopesDeviation       = GetIniStringA(file, section, "Envelopes.Deviation",      "");    // double   Envelopes.Deviation      = 0.07

   string sUseSpreadMultiplier      = GetIniStringA(file, section, "UseSpreadMultiplier",      "");    // bool     UseSpreadMultiplier      = 1
   string sSpreadMultiplier         = GetIniStringA(file, section, "SpreadMultiplier",         "");    // double   SpreadMultiplier         = 12.5
   string sMinBarSize               = GetIniStringA(file, section, "MinBarSize",               "");    // double   MinBarSize               = 18.0

   string sBreakoutReversal         = GetIniStringA(file, section, "BreakoutReversal",         "");    // double   BreakoutReversal         = 0.0
   string sMaxSpread                = GetIniStringA(file, section, "MaxSpread",                "");    // double   MaxSpread                = 2.0
   string sReverseSignals           = GetIniStringA(file, section, "ReverseSignals",           "");    // bool     ReverseSignals           = 0

   string sUseMoneyManagement       = GetIniStringA(file, section, "UseMoneyManagement",       "");    // bool     UseMoneyManagement       = 1
   string sRisk                     = GetIniStringA(file, section, "Risk",                     "");    // double   Risk                     = 2.0
   string sManualLotsize            = GetIniStringA(file, section, "ManualLotsize",            "");    // double   ManualLotsize            = 0.01

   string sTakeProfit               = GetIniStringA(file, section, "TakeProfit",               "");    // double   TakeProfit               = 10.0
   string sStopLoss                 = GetIniStringA(file, section, "StopLoss",                 "");    // double   StopLoss                 = 6.0
   string sTrailEntryStep           = GetIniStringA(file, section, "TrailEntryStep",           "");    // double   TrailEntryStep           = 1.0
   string sTrailExitStart           = GetIniStringA(file, section, "TrailExitStart",           "");    // double   TrailExitStart           = 0.0
   string sTrailExitStep            = GetIniStringA(file, section, "TrailExitStep",            "");    // double   TrailExitStep            = 2.0
   string sMaxSlippage              = GetIniStringA(file, section, "MaxSlippage",              "");    // double   MaxSlippage              = 0.3
   string sStopOnTotalProfit        = GetIniStringA(file, section, "StopOnTotalProfit",        "");    // double   StopOnTotalProfit        = 0.0
   string sStopOnTotalLoss          = GetIniStringA(file, section, "StopOnTotalLoss",          "");    // double   StopOnTotalLoss          = 0.0
   string sSessionbreakStartTime    = GetIniStringA(file, section, "Sessionbreak.StartTime",   "");    // datetime Sessionbreak.StartTime   = 86160
   string sSessionbreakEndTime      = GetIniStringA(file, section, "Sessionbreak.EndTime",     "");    // datetime Sessionbreak.EndTime     = 3730

   string sRecordPerformanceMetrics = GetIniStringA(file, section, "RecordPerformanceMetrics", "");    // bool     RecordPerformanceMetrics = 0
   string sMetricsServerDirectory   = GetIniStringA(file, section, "MetricsServerDirectory",   "");    // string   MetricsServerDirectory   = auto

   string sChannelBug               = GetIniStringA(file, section, "ChannelBug",               "");    // bool     ChannelBug               = 0
   string sTakeProfitBug            = GetIniStringA(file, section, "TakeProfitBug",            "");    // bool     TakeProfitBug            = 1

   if (sSequenceId != ""+ sequence.id)          return(!catch("ReadStatus(5)  "+ sequence.name +" invalid Sequence.ID "+ DoubleQuoteStr(sSequenceId) +" in status file "+ DoubleQuoteStr(file), ERR_INVALID_FILE_FORMAT));
   Sequence.ID = sSequenceId;
   if (sTradingMode == "")                      return(!catch("ReadStatus(6)  "+ sequence.name +" invalid TradingMode "+ DoubleQuoteStr(sTradingMode) +" in status file "+ DoubleQuoteStr(file), ERR_INVALID_FILE_FORMAT));
   TradingMode = sTradingMode;
   if (!StrIsDigit(sEntryIndicator))            return(!catch("ReadStatus(7)  "+ sequence.name +" invalid EntryIndicator "+ DoubleQuoteStr(sEntryIndicator) +" in status file "+ DoubleQuoteStr(file), ERR_INVALID_FILE_FORMAT));
   EntryIndicator = StrToInteger(sEntryIndicator);
   if (!StrIsDigit(sIndicatorTimeframe))        return(!catch("ReadStatus(8)  "+ sequence.name +" invalid IndicatorTimeframe "+ DoubleQuoteStr(sIndicatorTimeframe) +" in status file "+ DoubleQuoteStr(file), ERR_INVALID_FILE_FORMAT));
   IndicatorTimeframe = StrToInteger(sIndicatorTimeframe);
   if (!StrIsDigit(sIndicatorPeriods))          return(!catch("ReadStatus(9)  "+ sequence.name +" invalid IndicatorPeriods "+ DoubleQuoteStr(sIndicatorPeriods) +" in status file "+ DoubleQuoteStr(file), ERR_INVALID_FILE_FORMAT));
   IndicatorPeriods = StrToInteger(sIndicatorPeriods);
   if (!StrIsNumeric(sBollingerBandsDeviation)) return(!catch("ReadStatus(10)  "+ sequence.name +" invalid BollingerBands.Deviation "+ DoubleQuoteStr(sBollingerBandsDeviation) +" in status file "+ DoubleQuoteStr(file), ERR_INVALID_FILE_FORMAT));
   BollingerBands.Deviation = StrToDouble(sBollingerBandsDeviation);
   if (!StrIsNumeric(sEnvelopesDeviation))      return(!catch("ReadStatus(11)  "+ sequence.name +" invalid Envelopes.Deviation "+ DoubleQuoteStr(sEnvelopesDeviation) +" in status file "+ DoubleQuoteStr(file), ERR_INVALID_FILE_FORMAT));
   Envelopes.Deviation = StrToDouble(sEnvelopesDeviation);
   UseSpreadMultiplier = StrToBool(sUseSpreadMultiplier);
   if (!StrIsNumeric(sSpreadMultiplier))        return(!catch("ReadStatus(12)  "+ sequence.name +" invalid SpreadMultiplier "+ DoubleQuoteStr(sSpreadMultiplier) +" in status file "+ DoubleQuoteStr(file), ERR_INVALID_FILE_FORMAT));
   SpreadMultiplier = StrToDouble(sSpreadMultiplier);
   if (!StrIsNumeric(sMinBarSize))              return(!catch("ReadStatus(13)  "+ sequence.name +" invalid MinBarSize "+ DoubleQuoteStr(sMinBarSize) +" in status file "+ DoubleQuoteStr(file), ERR_INVALID_FILE_FORMAT));
   MinBarSize = StrToDouble(sMinBarSize);
   if (!StrIsNumeric(sBreakoutReversal))        return(!catch("ReadStatus(14)  "+ sequence.name +" invalid BreakoutReversal "+ DoubleQuoteStr(sBreakoutReversal) +" in status file "+ DoubleQuoteStr(file), ERR_INVALID_FILE_FORMAT));
   BreakoutReversal = StrToDouble(sBreakoutReversal);
   if (!StrIsNumeric(sMaxSpread))               return(!catch("ReadStatus(15)  "+ sequence.name +" invalid MaxSpread "+ DoubleQuoteStr(sMaxSpread) +" in status file "+ DoubleQuoteStr(file), ERR_INVALID_FILE_FORMAT));
   MaxSpread = StrToDouble(sMaxSpread);
   ReverseSignals = StrToBool(sReverseSignals);
   UseMoneyManagement = StrToBool(sUseMoneyManagement);
   if (!StrIsNumeric(sRisk))                    return(!catch("ReadStatus(16)  "+ sequence.name +" invalid Risk "+ DoubleQuoteStr(sRisk) +" in status file "+ DoubleQuoteStr(file), ERR_INVALID_FILE_FORMAT));
   Risk = StrToDouble(sRisk);
   if (!StrIsNumeric(sManualLotsize))           return(!catch("ReadStatus(17)  "+ sequence.name +" invalid ManualLotsize "+ DoubleQuoteStr(sManualLotsize) +" in status file "+ DoubleQuoteStr(file), ERR_INVALID_FILE_FORMAT));
   ManualLotsize = StrToDouble(sManualLotsize);
   if (!StrIsNumeric(sTakeProfit))              return(!catch("ReadStatus(18)  "+ sequence.name +" invalid TakeProfit "+ DoubleQuoteStr(sTakeProfit) +" in status file "+ DoubleQuoteStr(file), ERR_INVALID_FILE_FORMAT));
   TakeProfit = StrToDouble(sTakeProfit);
   if (!StrIsNumeric(sStopLoss))                return(!catch("ReadStatus(19)  "+ sequence.name +" invalid StopLoss "+ DoubleQuoteStr(sStopLoss) +" in status file "+ DoubleQuoteStr(file), ERR_INVALID_FILE_FORMAT));
   StopLoss = StrToDouble(sStopLoss);
   if (!StrIsNumeric(sTrailEntryStep))          return(!catch("ReadStatus(20)  "+ sequence.name +" invalid TrailEntryStep "+ DoubleQuoteStr(sTrailEntryStep) +" in status file "+ DoubleQuoteStr(file), ERR_INVALID_FILE_FORMAT));
   TrailEntryStep = StrToDouble(sTrailEntryStep);
   if (!StrIsNumeric(sTrailExitStart))          return(!catch("ReadStatus(21)  "+ sequence.name +" invalid TrailExitStart "+ DoubleQuoteStr(sTrailExitStart) +" in status file "+ DoubleQuoteStr(file), ERR_INVALID_FILE_FORMAT));
   TrailExitStart = StrToDouble(sTrailExitStart);
   if (!StrIsNumeric(sTrailExitStep))           return(!catch("ReadStatus(22)  "+ sequence.name +" invalid TrailExitStep "+ DoubleQuoteStr(sTrailExitStep) +" in status file "+ DoubleQuoteStr(file), ERR_INVALID_FILE_FORMAT));
   TrailExitStep = StrToDouble(sTrailExitStep);
   if (!StrIsNumeric(sMaxSlippage))             return(!catch("ReadStatus(23)  "+ sequence.name +" invalid MaxSlippage "+ DoubleQuoteStr(sMaxSlippage) +" in status file "+ DoubleQuoteStr(file), ERR_INVALID_FILE_FORMAT));
   MaxSlippage = StrToDouble(sMaxSlippage);
   if (!StrIsNumeric(sStopOnTotalProfit))       return(!catch("ReadStatus(24)  "+ sequence.name +" invalid StopOnTotalProfit "+ DoubleQuoteStr(sStopOnTotalProfit) +" in status file "+ DoubleQuoteStr(file), ERR_INVALID_FILE_FORMAT));
   StopOnTotalProfit = StrToDouble(sStopOnTotalProfit);
   if (!StrIsNumeric(sStopOnTotalLoss))         return(!catch("ReadStatus(25)  "+ sequence.name +" invalid StopOnTotalLoss "+ DoubleQuoteStr(sStopOnTotalLoss) +" in status file "+ DoubleQuoteStr(file), ERR_INVALID_FILE_FORMAT));
   StopOnTotalLoss = StrToDouble(sStopOnTotalLoss);
   if (!StrIsDigit(sSessionbreakStartTime))     return(!catch("ReadStatus(26)  "+ sequence.name +" invalid Sessionbreak.StartTime "+ DoubleQuoteStr(sSessionbreakStartTime) +" in status file "+ DoubleQuoteStr(file), ERR_INVALID_FILE_FORMAT));
   Sessionbreak.StartTime = StrToInteger(sSessionbreakStartTime);    // TODO: convert input to string and validate
   if (!StrIsDigit(sSessionbreakEndTime))       return(!catch("ReadStatus(27)  "+ sequence.name +" invalid Sessionbreak.EndTime "+ DoubleQuoteStr(sSessionbreakEndTime) +" in status file "+ DoubleQuoteStr(file), ERR_INVALID_FILE_FORMAT));
   Sessionbreak.EndTime = StrToInteger(sSessionbreakEndTime);        // TODO: convert input to string and validate
   RecordPerformanceMetrics = StrToBool(sRecordPerformanceMetrics);
   MetricsServerDirectory = sMetricsServerDirectory;
   ChannelBug = StrToBool(sChannelBug);
   TakeProfitBug = StrToBool(sTakeProfitBug);

   // [Runtime status]
   section = "Runtime status";
   string sKeys[], sOrder="";
   int size = ReadStatus.OrderKeys(file, section, sKeys, MODE_REAL); if (size < 0) return(false);
   ResetOrderLog(MODE_REAL);
   for (int i=0; i < size; i++) {
      sOrder = GetIniStringA(file, section, sKeys[i], "");           // real.order.{i}={data}
      if (!ReadStatus.ParseOrder(sOrder, MODE_REAL))    return(!catch("ReadStatus(28)  "+ sequence.name +" invalid order record in status file "+ DoubleQuoteStr(file) + NL + sKeys[i] +"="+ sOrder, ERR_INVALID_FILE_FORMAT));
   }
   size = ReadStatus.OrderKeys(file, section, sKeys, MODE_VIRTUAL); if (size < 0) return(false);
   ResetOrderLog(MODE_VIRTUAL);
   for (i=0; i < size; i++) {
      sOrder = GetIniStringA(file, section, sKeys[i], "");           // virt.order.{i}={data}
      if (!ReadStatus.ParseOrder(sOrder, MODE_VIRTUAL)) return(!catch("ReadStatus(29)  "+ sequence.name +" invalid order record in status file "+ DoubleQuoteStr(file) + NL + sKeys[i] +"="+ sOrder, ERR_INVALID_FILE_FORMAT));
   }
   return(!catch("ReadStatus(30)"));
}


/**
 * Read and return the keys of the specified order records found in the status file, sorted in ascending order.
 *
 * @param  _In_  string file    - status filename
 * @param  _In_  string section - status section
 * @param  _Out_ string keys[]  - array receiving the found keys
 * @param  _In_  int    mode    - MODE_REAL:    return real order records    (matching "real.order.{i}={data}")
 *                                MODE_VIRTUAL: return virtual order records (matching "virt.order.{i}={data}")
 *
 * @return int - number of found keys or EMPTY (-1) in case of errors
 */
int ReadStatus.OrderKeys(string file, string section, string &keys[], int mode) {
   if (mode!=MODE_REAL && mode!=MODE_VIRTUAL) return(_EMPTY(catch("ReadStatus.OrderKeys(1)  "+ sequence.name +" invalid parameter mode: "+ mode, ERR_INVALID_PARAMETER)));

   int size = GetIniKeys(file, section, keys);
   if (size < 0) return(EMPTY);

   string prefix = ifString(mode==MODE_REAL, "real.order.", "virt.order.");
   int prefixLen = StringLen(prefix);

   for (int i=size-1; i >= 0; i--) {
      if (StrStartsWithI(keys[i], prefix)) {
         if (StrIsDigit(StrSubstr(keys[i], prefixLen))) {
            continue;
         }
      }
      ArraySpliceStrings(keys, i, 1);                 // drop all non-matching keys
      size--;
   }
   if (!SortStrings(keys)) return(EMPTY);             // TODO: implement natural sorting
   return(size);
}


/**
 * Parse the string representation of an order and store the parsed data.
 *
 * @param  string value - string to parse
 * @param  int    mode  - MODE_REAL:    store in the real order log
 *                        MODE_VIRTUAL: store in the virtual order log
 *
 * @return bool - success status
 */
bool ReadStatus.ParseOrder(string value, int mode) {
   if (IsLastError()) return(false);
   /*
   [real|virt].order.1=3,0,3.33,-1,0.00000,1,1583254806,1.11536,1583254818,1.11550,1.11550,1.11380,-14.32,0.00,-46.62
   [real|virt].order.i=ticket,linkedTicket,lots,pendingType,pendingPrice,openType,openTime,openPrice,closeTime,closePrice,stopLoss,takeProfit,commission,profit
   ------------------------------------------------------------------------------------------------------------------------------------------------------------
   int      ticket       = values[ 0];
   int      linkedTicket = values[ 1];
   double   lots         = values[ 2];
   int      pendingType  = values[ 3];
   double   pendingPrice = values[ 4];
   int      openType     = values[ 5];
   datetime openTime     = values[ 6];
   double   openPrice    = values[ 7];
   datetime closeTime    = values[ 8];
   double   closePrice   = values[ 9];
   double   stopLoss     = values[10];
   double   takeProfit   = values[11];
   double   commission   = values[12];
   double   profit       = values[13];
   */
   string values[];
   if (Explode(value, ",", values, NULL) != 14)                       return(!catch("ReadStatus.ParseOrder(1)  "+ sequence.name +" illegal number of order details ("+ ArraySize(values) +") in order record", ERR_INVALID_FILE_FORMAT));

   // ticket
   string sTicket = StrTrim(values[0]);
   if (!StrIsDigit(sTicket))                                          return(!catch("ReadStatus.ParseOrder(2)  "+ sequence.name +" illegal ticket "+ DoubleQuoteStr(sTicket) +" in order record", ERR_INVALID_FILE_FORMAT));
   int ticket = StrToInteger(sTicket);
   if (!ticket)                                                       return(!catch("ReadStatus.ParseOrder(3)  "+ sequence.name +" illegal ticket #"+ ticket +" in order record", ERR_INVALID_FILE_FORMAT));

   // linkedTicket
   string sLinkedTicket = StrTrim(values[1]);
   if (!StrIsDigit(sLinkedTicket))                                    return(!catch("ReadStatus.ParseOrder(4)  "+ sequence.name +" illegal linked ticket "+ DoubleQuoteStr(sLinkedTicket) +" in order record", ERR_INVALID_FILE_FORMAT));
   int linkedTicket = StrToInteger(sLinkedTicket);

   // lots
   string sLots = StrTrim(values[2]);
   if (!StrIsNumeric(sLots))                                          return(!catch("ReadStatus.ParseOrder(5)  "+ sequence.name +" illegal order lots "+ DoubleQuoteStr(sLots) +" in order record", ERR_INVALID_FILE_FORMAT));
   double lots = StrToDouble(sLots);
   if (LE(lots, 0))                                                   return(!catch("ReadStatus.ParseOrder(6)  "+ sequence.name +" illegal order lots "+ NumberToStr(lots, ".1+") +" in order record", ERR_INVALID_FILE_FORMAT));

   // pendingType
   string sPendingType = StrTrim(values[3]);
   if (!StrIsInteger(sPendingType))                                   return(!catch("ReadStatus.ParseOrder(7)  "+ sequence.name +" illegal pending order type "+ DoubleQuoteStr(sPendingType) +" in order record", ERR_INVALID_FILE_FORMAT));
   int pendingType = StrToInteger(sPendingType);
   if (pendingType!=OP_UNDEFINED && !IsPendingOrderType(pendingType)) return(!catch("ReadStatus.ParseOrder(8)  "+ sequence.name +" illegal pending order type "+ DoubleQuoteStr(sPendingType) +" in order record", ERR_INVALID_FILE_FORMAT));

   // pendingPrice
   string sPendingPrice = StrTrim(values[4]);
   if (!StrIsNumeric(sPendingPrice))                                  return(!catch("ReadStatus.ParseOrder(9)  "+ sequence.name +" illegal pending order price "+ DoubleQuoteStr(sPendingPrice) +" in order record", ERR_INVALID_FILE_FORMAT));
   double pendingPrice = StrToDouble(sPendingPrice);
   if (LT(pendingPrice, 0))                                           return(!catch("ReadStatus.ParseOrder(10)  "+ sequence.name +" illegal pending order price "+ NumberToStr(pendingPrice, ".1+") +" in order record", ERR_INVALID_FILE_FORMAT));
   if (pendingType==OP_UNDEFINED && pendingPrice)                     return(!catch("ReadStatus.ParseOrder(11)  "+ sequence.name +" pending order type/price mis-match "+ OperationTypeToStr(pendingType) +"/"+ NumberToStr(pendingPrice, PriceFormat) +" in order record", ERR_INVALID_FILE_FORMAT));
   if (pendingType!=OP_UNDEFINED && !pendingPrice)                    return(!catch("ReadStatus.ParseOrder(12)  "+ sequence.name +" pending order type/price mis-match "+ OperationTypeToStr(pendingType) +"/"+ NumberToStr(pendingPrice, PriceFormat) +" in order record", ERR_INVALID_FILE_FORMAT));

   // openType
   string sOpenType = StrTrim(values[5]);
   if (!StrIsInteger(sOpenType))                                      return(!catch("ReadStatus.ParseOrder(13)  "+ sequence.name +" illegal order open type "+ DoubleQuoteStr(sOpenType) +" in order record", ERR_INVALID_FILE_FORMAT));
   int openType = StrToInteger(sOpenType);
   if (openType == OP_UNDEFINED) {
      if (pendingType == OP_UNDEFINED)                                return(!catch("ReadStatus.ParseOrder(14)  "+ sequence.name +" pending order type/open order type mis-match "+ OperationTypeToStr(pendingType) +"/"+ OperationTypeToStr(openType) +" in order record", ERR_INVALID_FILE_FORMAT));
   }
   else if (openType!=OP_BUY && openType!=OP_SELL)                    return(!catch("ReadStatus.ParseOrder(15)  "+ sequence.name +" illegal order open type "+ DoubleQuoteStr(sOpenType) +" in order record", ERR_INVALID_FILE_FORMAT));
   else if (pendingType != OP_UNDEFINED) {
      if (IsLongOrderType(pendingType)!=IsLongOrderType(openType))    return(!catch("ReadStatus.ParseOrder(16)  "+ sequence.name +" pending order type/open order type mis-match "+ OperationTypeToStr(pendingType) +"/"+ OperationTypeToStr(openType) +" in order record", ERR_INVALID_FILE_FORMAT));
   }

   // openTime
   string sOpenTime = StrTrim(values[6]);
   if (!StrIsDigit(sOpenTime))                                        return(!catch("ReadStatus.ParseOrder(17)  "+ sequence.name +" illegal order open time "+ DoubleQuoteStr(sOpenTime) +" in order record", ERR_INVALID_FILE_FORMAT));
   datetime openTime = StrToInteger(sOpenTime);
   if (openType==OP_UNDEFINED && openTime)                            return(!catch("ReadStatus.ParseOrder(18)  "+ sequence.name +" order open type/time mis-match "+ OperationTypeToStr(openType) +"/'"+ TimeToStr(openTime, TIME_FULL) +"' in order record", ERR_INVALID_FILE_FORMAT));
   if (openType!=OP_UNDEFINED && !openTime)                           return(!catch("ReadStatus.ParseOrder(19)  "+ sequence.name +" order open type/time mis-match "+ OperationTypeToStr(openType) +"/"+ openTime +" in order record", ERR_INVALID_FILE_FORMAT));

   // openPrice
   string sOpenPrice = StrTrim(values[7]);
   if (!StrIsNumeric(sOpenPrice))                                     return(!catch("ReadStatus.ParseOrder(20)  "+ sequence.name +" illegal order open price "+ DoubleQuoteStr(sOpenPrice) +" in order record", ERR_INVALID_FILE_FORMAT));
   double openPrice = StrToDouble(sOpenPrice);
   if (LT(openPrice, 0))                                              return(!catch("ReadStatus.ParseOrder(21)  "+ sequence.name +" illegal order open price "+ NumberToStr(openPrice, PriceFormat) +" in order record", ERR_INVALID_FILE_FORMAT));
   if (openType==OP_UNDEFINED && openPrice)                           return(!catch("ReadStatus.ParseOrder(22)  "+ sequence.name +" order open type/price mis-match "+ OperationTypeToStr(openType) +"/"+ NumberToStr(openPrice, PriceFormat) +" in order record", ERR_INVALID_FILE_FORMAT));
   if (openType!=OP_UNDEFINED && !openPrice)                          return(!catch("ReadStatus.ParseOrder(23)  "+ sequence.name +" order open type/price mis-match "+ OperationTypeToStr(openType) +"/"+ NumberToStr(openPrice, PriceFormat) +" in order record", ERR_INVALID_FILE_FORMAT));

   // closeTime
   string sCloseTime = StrTrim(values[8]);
   if (!StrIsDigit(sCloseTime))                                       return(!catch("ReadStatus.ParseOrder(24)  "+ sequence.name +" illegal order close time "+ DoubleQuoteStr(sCloseTime) +" in order record", ERR_INVALID_FILE_FORMAT));
   datetime closeTime = StrToInteger(sCloseTime);
   if (closeTime && closeTime < openTime)                             return(!catch("ReadStatus.ParseOrder(25)  "+ sequence.name +" order open/close time mis-match '"+ TimeToStr(openTime, TIME_FULL) +"'/'"+ TimeToStr(closeTime, TIME_FULL) +"' in order record", ERR_INVALID_FILE_FORMAT));

   // closePrice
   string sClosePrice = StrTrim(values[9]);
   if (!StrIsNumeric(sClosePrice))                                    return(!catch("ReadStatus.ParseOrder(26)  "+ sequence.name +" illegal order close price "+ DoubleQuoteStr(sClosePrice) +" in order record", ERR_INVALID_FILE_FORMAT));
   double closePrice = StrToDouble(sClosePrice);
   if (LT(closePrice, 0))                                             return(!catch("ReadStatus.ParseOrder(27)  "+ sequence.name +" illegal order close price "+ NumberToStr(closePrice, PriceFormat) +" in order record", ERR_INVALID_FILE_FORMAT));
   if (closeTime && !closePrice)                                      return(!catch("ReadStatus.ParseOrder(28)  "+ sequence.name +" order close time/price mis-match '"+ TimeToStr(closeTime, TIME_FULL) +"'/"+ NumberToStr(closePrice, PriceFormat) +" in order record", ERR_INVALID_FILE_FORMAT));
   if (!closeTime && closePrice)                                      return(!catch("ReadStatus.ParseOrder(29)  "+ sequence.name +" order close time/price mis-match '"+ TimeToStr(closeTime, TIME_FULL) +"'/"+ NumberToStr(closePrice, PriceFormat) +" in order record", ERR_INVALID_FILE_FORMAT));

   // stopLoss
   string sStopLoss = StrTrim(values[10]);
   if (!StrIsNumeric(sStopLoss))                                      return(!catch("ReadStatus.ParseOrder(30)  "+ sequence.name +" illegal order stoploss "+ DoubleQuoteStr(sStopLoss) +" in order record", ERR_INVALID_FILE_FORMAT));
   double stopLoss = StrToDouble(sStopLoss);
   if (LE(stopLoss, 0))                                               return(!catch("ReadStatus.ParseOrder(31)  "+ sequence.name +" illegal order stoploss "+ NumberToStr(stopLoss, PriceFormat) +" in order record", ERR_INVALID_FILE_FORMAT));

   // takeProfit
   string sTakeProfit = StrTrim(values[11]);
   if (!StrIsNumeric(sTakeProfit))                                    return(!catch("ReadStatus.ParseOrder(30)  "+ sequence.name +" illegal order takeprofit "+ DoubleQuoteStr(sTakeProfit) +" in order record", ERR_INVALID_FILE_FORMAT));
   double takeProfit = StrToDouble(sTakeProfit);
   if (LE(takeProfit, 0))                                             return(!catch("ReadStatus.ParseOrder(31)  "+ sequence.name +" illegal order takeprofit "+ NumberToStr(takeProfit, PriceFormat) +" in order record", ERR_INVALID_FILE_FORMAT));

   // commission
   string sCommission = StrTrim(values[12]);
   if (!StrIsNumeric(sCommission))                                    return(!catch("ReadStatus.ParseOrder(32)  "+ sequence.name +" illegal order commission "+ DoubleQuoteStr(sCommission) +" in order record", ERR_INVALID_FILE_FORMAT));
   double commission = StrToDouble(sCommission);
   if (openType==OP_UNDEFINED && commission)                          return(!catch("ReadStatus.ParseOrder(33)  "+ sequence.name +" pending order/commission mis-match "+ OperationTypeToStr(pendingType) +"/"+ DoubleToStr(commission, 2) +" in order record", ERR_INVALID_FILE_FORMAT));

   // profit
   string sProfit = StrTrim(values[13]);
   if (!StrIsNumeric(sProfit))                                        return(!catch("ReadStatus.ParseOrder(34)  "+ sequence.name +" illegal order profit "+ DoubleQuoteStr(sProfit) +" in order record", ERR_INVALID_FILE_FORMAT));
   double profit = StrToDouble(sProfit);
   if (openType==OP_UNDEFINED && profit)                              return(!catch("ReadStatus.ParseOrder(35)  "+ sequence.name +" pending order/profit mis-match "+ OperationTypeToStr(pendingType) +"/"+ DoubleToStr(profit, 2) +" in order record", ERR_INVALID_FILE_FORMAT));

   // store data in the order log
   if (mode == MODE_REAL)    return(Orders.AddRealTicket   (ticket, linkedTicket, lots, pendingType, pendingPrice, openType, openTime, openPrice, closeTime, closePrice, stopLoss, takeProfit, commission, profit));
   if (mode == MODE_VIRTUAL) return(Orders.AddVirtualTicket(ticket, linkedTicket, lots, pendingType, pendingPrice, openType, openTime, openPrice, closeTime, closePrice, stopLoss, takeProfit, commission, profit));

   return(!catch("ReadStatus.ParseOrder(36)  "+ sequence.name +" invalid parameter mode: "+ mode, ERR_INVALID_PARAMETER));
}


/**
 * Write the current sequence status to the status file.
 *
 * @return bool - success status
 */
bool SaveStatus() {
   if (last_error || !sequence.id) return(false);

   // In tester skip updating the status file except at the first call and at test end.
   if (IsTesting() && test.optimizeStatus) {
      static bool saved = false;
      if (saved && __CoreFunction!=CF_DEINIT) return(true);
      saved = true;
   }

   string section="", file=GetStatusFilename(), separator="";
   if (!IsFile(file, MODE_OS)) separator = CRLF;                     // an additional empty line as section separator

   section = "General";
   WriteIniString(file, section, "Account", GetAccountCompany() +":"+ GetAccountNumber());
   WriteIniString(file, section, "Symbol",  Symbol() + separator);   // conditional section separator

   section = "Inputs";
   WriteIniString(file, section, "Sequence.ID",              sequence.id);
   WriteIniString(file, section, "TradingMode",              TradingMode);

   WriteIniString(file, section, "EntryIndicator",           EntryIndicator);
   WriteIniString(file, section, "IndicatorTimeframe",       IndicatorTimeframe);
   WriteIniString(file, section, "IndicatorPeriods",         IndicatorPeriods);
   WriteIniString(file, section, "BollingerBands.Deviation", NumberToStr(BollingerBands.Deviation, ".1+"));
   WriteIniString(file, section, "Envelopes.Deviation",      NumberToStr(Envelopes.Deviation, ".1+"));

   WriteIniString(file, section, "UseSpreadMultiplier",      UseSpreadMultiplier);
   WriteIniString(file, section, "SpreadMultiplier",         NumberToStr(SpreadMultiplier, ".1+"));
   WriteIniString(file, section, "MinBarSize",               DoubleToStr(MinBarSize, 1));

   WriteIniString(file, section, "BreakoutReversal",         DoubleToStr(BreakoutReversal, 1));
   WriteIniString(file, section, "MaxSpread",                DoubleToStr(MaxSpread, 1));
   WriteIniString(file, section, "ReverseSignals",           ReverseSignals);

   WriteIniString(file, section, "UseMoneyManagement",       UseMoneyManagement);
   WriteIniString(file, section, "Risk",                     NumberToStr(Risk, ".1+"));
   WriteIniString(file, section, "ManualLotsize",            NumberToStr(ManualLotsize, ".1+"));

   WriteIniString(file, section, "TakeProfit",               DoubleToStr(TakeProfit, 1));
   WriteIniString(file, section, "StopLoss",                 DoubleToStr(StopLoss, 1));
   WriteIniString(file, section, "TrailEntryStep",           DoubleToStr(TrailEntryStep, 1));
   WriteIniString(file, section, "TrailExitStart",           DoubleToStr(TrailExitStart, 1));
   WriteIniString(file, section, "TrailExitStep",            DoubleToStr(TrailExitStep, 1));
   WriteIniString(file, section, "MaxSlippage",              DoubleToStr(MaxSlippage, 1));
   WriteIniString(file, section, "StopOnTotalProfit",        DoubleToStr(StopOnTotalProfit, 2));
   WriteIniString(file, section, "StopOnTotalLoss",          DoubleToStr(StopOnTotalLoss, 2));
   WriteIniString(file, section, "Sessionbreak.StartTime",   Sessionbreak.StartTime);
   WriteIniString(file, section, "Sessionbreak.EndTime",     Sessionbreak.EndTime);

   WriteIniString(file, section, "RecordPerformanceMetrics", RecordPerformanceMetrics);
   WriteIniString(file, section, "MetricsServerDirectory",   MetricsServerDirectory);

   WriteIniString(file, section, "ChannelBug",               ChannelBug);
   WriteIniString(file, section, "TakeProfitBug",            TakeProfitBug + separator);  // conditional section separator

   section = "Runtime status";
   // On deletion of pending orders the number of stored order records decreases. To prevent orphaned order records in the
   // status file the section is emptied before writing to it.
   EmptyIniSectionA(file, section);

   int size = ArraySize(real.ticket);
   for (int i=0; i < size; i++) {
      WriteIniString(file, section, "real.order."+ StrPadLeft(i, 4, "0"), SaveStatus.OrderToStr(i, TRADINGMODE_REGULAR));
   }
   size = ArraySize(virt.ticket);
   for (i=0; i < size; i++) {
      WriteIniString(file, section, "virt.order."+ StrPadLeft(i, 4, "0"), SaveStatus.OrderToStr(i, TRADINGMODE_VIRTUAL));
   }

   return(!catch("SaveStatus(1)"));
}


/**
 * Return a string representation of an order record to be stored by SaveStatus().
 *
 * @param  int index - index of the order record
 * @param  int mode  - one of MODE_REAL or MODE_VIRTUAL
 *
 * @return string - string representation or an empty string in case of errors
 */
string SaveStatus.OrderToStr(int index, int mode) {
   int      ticket, linkedTicket, pendingType, openType;
   datetime openTime, closeTime;
   double   lots, pendingPrice, openPrice, closePrice, stopLoss, takeProfit, commission, profit;

   // result: ticket,linkedTicket,lots,pendingType,pendingPrice,openType,openTime,openPrice,closeTime,closePrice,stopLoss,takeProfit,commission,profit

   if (mode == MODE_REAL) {
      ticket       = real.ticket      [index];
      linkedTicket = real.linkedTicket[index];
      lots         = real.lots        [index];
      pendingType  = real.pendingType [index];
      pendingPrice = real.pendingPrice[index];
      openType     = real.openType    [index];
      openTime     = real.openTime    [index];
      openPrice    = real.openPrice   [index];
      closeTime    = real.closeTime   [index];
      closePrice   = real.closePrice  [index];
      stopLoss     = real.stopLoss    [index];
      takeProfit   = real.takeProfit  [index];
      commission   = real.commission  [index];
      profit       = real.profit      [index];
   }
   else if (mode == MODE_VIRTUAL) {
      ticket       = virt.ticket      [index];
      linkedTicket = virt.linkedTicket[index];
      lots         = virt.lots        [index];
      pendingType  = virt.pendingType [index];
      pendingPrice = virt.pendingPrice[index];
      openType     = virt.openType    [index];
      openTime     = virt.openTime    [index];
      openPrice    = virt.openPrice   [index];
      closeTime    = virt.closeTime   [index];
      closePrice   = virt.closePrice  [index];
      stopLoss     = virt.stopLoss    [index];
      takeProfit   = virt.takeProfit  [index];
      commission   = virt.commission  [index];
      profit       = virt.profit      [index];
   }
   else return(_EMPTY_STR(catch("SaveStatus.OrderToStr(1)  "+ sequence.name +" invalid parameter mode: "+ mode, ERR_INVALID_PARAMETER)));

   return(StringConcatenate(ticket, ",", linkedTicket, ",", DoubleToStr(lots, 2), ",", pendingType, ",", DoubleToStr(pendingPrice, Digits), ",", openType, ",", openTime, ",", DoubleToStr(openPrice, Digits), ",", closeTime, ",", DoubleToStr(closePrice, Digits), ",", DoubleToStr(stopLoss, Digits), ",", DoubleToStr(takeProfit, Digits), ",", DoubleToStr(commission, 2), ",", DoubleToStr(profit, 2)));
}


/**
 * Display the current runtime status.
 *
 * @param  int error [optional] - error to display (default: none)
 *
 * @return int - the same error or the current error status if no error was passed
 */
int ShowStatus(int error = NO_ERROR) {
   if (!__isChart) return(error);

   static bool isRecursion = false;                   // to prevent recursive calls a specified error is displayed only once
   if (error != 0) {
      if (isRecursion) return(error);
      isRecursion = true;
   }

   string realStats="", virtStats="", sError="";
   if (__STATUS_OFF) sError = StringConcatenate(" [switched off => ", ErrorDescription(__STATUS_OFF.reason), "]");

   string sSpreadInfo = "";
   if (currentSpread > MaxSpread || avgSpread > MaxSpread)
      sSpreadInfo = StringConcatenate("  =>  larger then MaxSpread of ", sMaxSpread);

   string msg = StringConcatenate(ProgramName(), sTradingModeStatus[tradingMode], "  (sid: ", sequence.id, ")", "           ", sError,                          NL,
                                                                                                                                                                NL,
                                    "Spread:    ",  sCurrentSpread, "    Avg: ", sAvgSpread, sSpreadInfo,                                                       NL,
                                    "BarSize:    ", sCurrentBarSize, "    MinBarSize: ", sMinBarSize,                                                           NL,
                                    "Channel:   ",  sIndicator,                                                                                                 NL,
                                    "Unitsize:   ", sUnitSize,                                                                                                  NL);

   if (tradingMode != TRADINGMODE_VIRTUAL) {
      realStats = StringConcatenate("Open:       ", NumberToStr(real.openLots, "+.+"),   " lot                           PL: ", DoubleToStr(real.openPlNet, 2), NL,
                                    "Closed:     ", real.closedPositions, " trades    ", NumberToStr(real.closedLots, ".+"), " lot    PL: ", DoubleToStr(real.closedPl, 2), "    Commission: ", DoubleToStr(real.closedCommission, 2), NL,
                                    "Total PL:   ", DoubleToStr(real.totalPlNet, 2),                                                                            NL);
   }
   if (tradingMode != TRADINGMODE_REGULAR) {
      virtStats = StringConcatenate("Open:       ", NumberToStr(virt.openLots, "+.+"),   " lot                           PL: ", DoubleToStr(virt.openPlNet, 2), NL,
                                    "Closed:     ", virt.closedPositions, " trades    ", NumberToStr(virt.closedLots, ".+"), " lot    PL: ", DoubleToStr(virt.closedPl, 2), "    Commission: ", DoubleToStr(virt.closedCommission, 2), NL,
                                    "Total PL:   ", DoubleToStr(virt.totalPlNet, 2),                                                                            NL);
   }

   switch (tradingMode) {
      case TRADINGMODE_REGULAR:
         msg = StringConcatenate(msg,       NL,
                                 realStats, NL);
         break;

      case TRADINGMODE_VIRTUAL:
         msg = StringConcatenate(msg,       NL,
                                 virtStats, NL);
         break;

      case TRADINGMODE_VIRTUAL_COPIER:
         msg = StringConcatenate(msg,        NL,
                                 "Virtual",  NL,
                                 "--------", NL,
                                 virtStats,  NL,
                                 "Copier",   NL,
                                 "--------", NL,
                                 realStats,  NL);
         break;

      case TRADINGMODE_VIRTUAL_MIRROR:
         msg = StringConcatenate(msg,        NL,
                                 "Virtual",  NL,
                                 "--------", NL,
                                 virtStats,  NL,
                                 "Mirror",   NL,
                                 "-------",  NL,
                                 realStats,  NL);
         break;
   }

   // 3 lines margin-top for potential indicator legends
   Comment(NL, NL, NL, msg);
   if (__CoreFunction == CF_INIT) WindowRedraw();

   // store status in the chart to enable remote access by scripts
   string label = "XMT-Scalper.status";
   if (ObjectFind(label) != 0) {
      ObjectCreate(label, OBJ_LABEL, 0, 0, 0);
      ObjectSet(label, OBJPROP_TIMEFRAMES, OBJ_PERIODS_NONE);
      RegisterObject(label);
   }
   ObjectSetText(label, StringConcatenate(sequence.id, "|", TradingMode));

   error = intOr(catch("ShowStatus(1)"), error);
   isRecursion = false;
   return(error);
}


/**
 * ShowStatus: Update all string representations.
 */
void SS.All() {
   SS.SequenceName();

   if (__isChart) {
      SS.MinBarSize();
      SS.Spreads();
      SS.UnitSize();
   }
}


/**
 * ShowStatus: Update the string representation of the min. bar size.
 */
void SS.MinBarSize() {
   if (__isChart) {
      sMinBarSize = DoubleToStr(RoundCeil(minBarSize/Pip, 1), 1);
   }
}


/**
 * ShowStatus: Update the string representation of the sequence name.
 */
void SS.SequenceName() {
   switch (tradingMode) {
      case NULL:                       sequence.name = "?";  break;
      case TRADINGMODE_REGULAR:        sequence.name = "R";  break;
      case TRADINGMODE_VIRTUAL:        sequence.name = "V";  break;
      case TRADINGMODE_VIRTUAL_COPIER: sequence.name = "VC"; break;
      case TRADINGMODE_VIRTUAL_MIRROR: sequence.name = "VM"; break;
   }
   sequence.name = sequence.name +"."+ sequence.id;
}


/**
 * ShowStatus: Update the string representations of current and average spreads.
 */
void SS.Spreads() {
   if (__isChart) {
      sCurrentSpread = DoubleToStr(currentSpread, 1);

      if (IsTesting())     sAvgSpread = sCurrentSpread;
      else if (!avgSpread) sAvgSpread = "-";
      else                 sAvgSpread = DoubleToStr(avgSpread, 2);
   }
}


/**
 * ShowStatus: Update the string representation of the currently used lotsize.
 *
 * @param  double size [optional]
 */
void SS.UnitSize(double size = NULL) {
   if (__isChart) {
      static double lastSize = -1;

      if (size != lastSize) {
         if (!size) sUnitSize = "-";
         else       sUnitSize = NumberToStr(size, ".+") +" lot";
         lastSize = size;
      }
   }
}


string   prev.Sequence.ID = "";
string   prev.TradingMode = "";

int      prev.EntryIndicator;
int      prev.IndicatorTimeframe;
int      prev.IndicatorPeriods;
double   prev.BollingerBands.Deviation;
double   prev.Envelopes.Deviation;

bool     prev.UseSpreadMultiplier;
double   prev.SpreadMultiplier;
double   prev.MinBarSize;

double   prev.BreakoutReversal;
double   prev.MaxSpread;
bool     prev.ReverseSignals;

bool     prev.UseMoneyManagement;
double   prev.Risk;
double   prev.ManualLotsize;

double   prev.TakeProfit;
double   prev.StopLoss;
double   prev.TrailEntryStep;
double   prev.TrailExitStart;
double   prev.TrailExitStep;
double   prev.MaxSlippage;
double   prev.StopOnTotalProfit;
double   prev.StopOnTotalLoss;
datetime prev.Sessionbreak.StartTime;
datetime prev.Sessionbreak.EndTime;

bool     prev.RecordPerformanceMetrics;
string   prev.MetricsServerDirectory = "";

bool     prev.ChannelBug;
bool     prev.TakeProfitBug;


/**
 * Programatically changed input parameters don't survive init cycles. Therefore inputs are backed-up in deinit() and can be
 * restored in init(). Called from onDeinitParameters() and onDeinitChartChange().
 */
void BackupInputs() {
   // backed-up values are also accessed in ValidateInputs()
   prev.Sequence.ID              = StringConcatenate(Sequence.ID, "");     // string inputs are references to internal C literals
   prev.TradingMode              = StringConcatenate(TradingMode, "");     // and must be copied to break the reference

   prev.EntryIndicator           = EntryIndicator;
   prev.IndicatorTimeframe       = IndicatorTimeframe;
   prev.IndicatorPeriods         = IndicatorPeriods;
   prev.BollingerBands.Deviation = BollingerBands.Deviation;
   prev.Envelopes.Deviation      = Envelopes.Deviation;

   prev.UseSpreadMultiplier      = UseSpreadMultiplier;
   prev.SpreadMultiplier         = SpreadMultiplier;
   prev.MinBarSize               = MinBarSize;

   prev.BreakoutReversal         = BreakoutReversal;
   prev.MaxSpread                = MaxSpread;
   prev.ReverseSignals           = ReverseSignals;

   prev.UseMoneyManagement       = UseMoneyManagement;
   prev.Risk                     = Risk;
   prev.ManualLotsize            = ManualLotsize;

   prev.TakeProfit               = TakeProfit;
   prev.StopLoss                 = StopLoss;
   prev.TrailEntryStep           = TrailEntryStep;
   prev.TrailExitStart           = TrailExitStart;
   prev.TrailExitStep            = TrailExitStep;
   prev.MaxSlippage              = MaxSlippage;
   prev.StopOnTotalProfit        = StopOnTotalProfit;
   prev.StopOnTotalLoss          = StopOnTotalLoss;
   prev.Sessionbreak.StartTime   = Sessionbreak.StartTime;
   prev.Sessionbreak.EndTime     = Sessionbreak.EndTime;

   prev.RecordPerformanceMetrics = RecordPerformanceMetrics;
   prev.MetricsServerDirectory   = MetricsServerDirectory;

   prev.ChannelBug               = ChannelBug;
   prev.TakeProfitBug            = TakeProfitBug;
}


/**
 * Restore backed-up input parameters. Called from onInitParameters() and onInitTimeframeChange().
 */
void RestoreInputs() {
   Sequence.ID              = prev.Sequence.ID;
   TradingMode              = prev.TradingMode;

   EntryIndicator           = prev.EntryIndicator;
   IndicatorTimeframe       = prev.IndicatorTimeframe;
   IndicatorPeriods         = prev.IndicatorPeriods;
   BollingerBands.Deviation = prev.BollingerBands.Deviation;
   Envelopes.Deviation      = prev.Envelopes.Deviation;

   UseSpreadMultiplier      = prev.UseSpreadMultiplier;
   SpreadMultiplier         = prev.SpreadMultiplier;
   MinBarSize               = prev.MinBarSize;

   BreakoutReversal         = prev.BreakoutReversal;
   MaxSpread                = prev.MaxSpread;
   ReverseSignals           = prev.ReverseSignals;

   UseMoneyManagement       = prev.UseMoneyManagement;
   Risk                     = prev.Risk;
   ManualLotsize            = prev.ManualLotsize;

   TakeProfit               = prev.TakeProfit;
   StopLoss                 = prev.StopLoss;
   TrailEntryStep           = prev.TrailEntryStep;
   TrailExitStart           = prev.TrailExitStart;
   TrailExitStep            = prev.TrailExitStep;
   MaxSlippage              = prev.MaxSlippage;
   StopOnTotalProfit        = prev.StopOnTotalProfit;
   StopOnTotalLoss          = prev.StopOnTotalLoss;
   Sessionbreak.StartTime   = prev.Sessionbreak.StartTime;
   Sessionbreak.EndTime     = prev.Sessionbreak.EndTime;

   RecordPerformanceMetrics = prev.RecordPerformanceMetrics;
   MetricsServerDirectory   = prev.MetricsServerDirectory;

   ChannelBug               = prev.ChannelBug;
   TakeProfitBug            = prev.TakeProfitBug;
}


/**
 * Syntactically validate and restore a specified sequence id (format: /[1-9][0-9]{3}/). Called only from onInitUser().
 *
 * @return bool - whether the input sequence id is was valid and restored (the status file is not checked)
 */
bool ValidateInputs.SID() {
   string sValue = StrTrim(Sequence.ID);
   if (!StringLen(sValue))                   return(false);
   if (!StrIsDigit(sValue))                  return(!onInputError("ValidateInputs.SID(1)  invalid input parameter Sequence.ID: "+ DoubleQuoteStr(Sequence.ID) +" (must be digits only)"));
   int iValue = StrToInteger(sValue);
   if (iValue < SID_MIN || iValue > SID_MAX) return(!onInputError("ValidateInputs.SID(2)  invalid input parameter Sequence.ID: "+ DoubleQuoteStr(Sequence.ID) +" (range error)"));

   sequence.id = iValue;
   Sequence.ID = sequence.id;
   SS.SequenceName();
   return(true);
}


/**
 * Validate all input parameters. Parameters may have been entered through the input dialog or read and applied from
 * a status file.
 *
 * @return bool - whether input parameters are valid
 */
bool ValidateInputs() {
   if (IsLastError()) return(false);
   bool isParameterChange = (ProgramInitReason()==IR_PARAMETERS);

   // Sequence.ID
   string _Sequence.ID = Sequence.ID, values[];
   if (isParameterChange) {
      string sValue = StrTrim(Sequence.ID);
      if (sValue == "") {                                    // the id was deleted or not yet set, re-apply the internal id
         _Sequence.ID = prev.Sequence.ID;
      }
      else if (sValue != prev.Sequence.ID)                   return(!onInputError("ValidateInputs(1)  "+ sequence.name +" switching to another sequence is not supported (unload the EA first)"));
   } //else                                                  // onInitUser(): the id is empty (a new sequence) or validated (an existing sequence was reloaded)
   int _sequence.id = StrToInteger(_Sequence.ID);

   // TradingMode
   sValue = TradingMode;
   if (Explode(TradingMode, "*", values, 2) > 1) {
      int size = Explode(values[0], "|", values, NULL);
      sValue = values[size-1];
   }
   sValue = StrToLower(StrTrim(sValue));
   int _tradingMode;
   if      (sValue=="r"  || sValue=="regular"       ) _tradingMode = TRADINGMODE_REGULAR;
   else if (sValue=="v"  || sValue=="virtual"       ) _tradingMode = TRADINGMODE_VIRTUAL;
   else if (sValue=="vc" || sValue=="virtual-copier") _tradingMode = TRADINGMODE_VIRTUAL_COPIER;
   else if (sValue=="vm" || sValue=="virtual-mirror") _tradingMode = TRADINGMODE_VIRTUAL_MIRROR;
   else                                                                          return(!onInputError("ValidateInputs(2)  "+ sequence.name +" invalid input parameter TradingMode: "+ DoubleQuoteStr(TradingMode)));
   if (isParameterChange && _tradingMode!=tradingMode) {
      if (_tradingMode==TRADINGMODE_REGULAR || tradingMode==TRADINGMODE_REGULAR) return(!onInputError("ValidateInputs(3)  "+ sequence.name +" cannot change trading mode from "+ DoubleQuoteStr(tradingModeDescriptions[tradingMode]) +" to "+ DoubleQuoteStr(tradingModeDescriptions[_tradingMode])));
   }
   string _TradingMode = tradingModeDescriptions[_tradingMode];

   // EntryIndicator
   if (EntryIndicator < 1 || EntryIndicator > 3)             return(!onInputError("ValidateInputs(4)  "+ sequence.name +" invalid input parameter EntryIndicator: "+ EntryIndicator +" (must be from 1-3)"));
   int _EntryIndicator = EntryIndicator;

   // IndicatorTimeframe
   if (!IsStdTimeframe(IndicatorTimeframe))                  return(!onInputError("ValidateInputs(5)  "+ sequence.name +" invalid input parameter IndicatorTimeframe: "+ IndicatorTimeframe));
   if (IsTesting() && IndicatorTimeframe!=Period())          return(!onInputError("ValidateInputs(6)  "+ sequence.name +" invalid input parameter IndicatorTimeframe: "+ IndicatorTimeframe +" (for test on "+ PeriodDescription(Period()) +")"));
   int _IndicatorTimeframe = IndicatorTimeframe;

   // IndicatorPeriods
   if (IndicatorPeriods < 1)                                 return(!onInputError("ValidateInputs(7)  "+ sequence.name +" invalid input parameter IndicatorPeriods: "+ IndicatorPeriods +" (must be positive)"));
   int _IndicatorPeriods = IndicatorPeriods;

   // BollingerBands.Deviation
   if (_EntryIndicator==2 && BollingerBands.Deviation < 0)   return(!onInputError("ValidateInputs(8)  "+ sequence.name +" invalid input parameter BollingerBands.Deviation: "+ NumberToStr(BollingerBands.Deviation, ".1+") +" (can't be negative)"));
   double _BollingerBands.Deviation = BollingerBands.Deviation;

   // Envelopes.Deviation
   if (_EntryIndicator==3 && Envelopes.Deviation < 0)        return(!onInputError("ValidateInputs(9)  "+ sequence.name +" invalid input parameter Envelopes.Deviation: "+ NumberToStr(Envelopes.Deviation, ".1+") +" (can't be negative)"));
   double _Envelopes.Deviation = Envelopes.Deviation;
   // --- OK ----------------------------------------------------------------------------------------------------------------

   // apply validated inputs and status variables
   Sequence.ID              = _Sequence.ID;     sequence.id = _sequence.id;
   TradingMode              = _TradingMode;     tradingMode = _tradingMode; SS.SequenceName();
   EntryIndicator           = _EntryIndicator;
   IndicatorTimeframe       = _IndicatorTimeframe;
   IndicatorPeriods         = _IndicatorPeriods;
   BollingerBands.Deviation = _BollingerBands.Deviation;
   Envelopes.Deviation      = _Envelopes.Deviation;
   // -----------------------------------------------------------------------------------------------------------------------


   // BreakoutReversal
   double stopLevel = MarketInfo(Symbol(), MODE_STOPLEVEL);
   if (LT(BreakoutReversal*Pip, stopLevel*Point))            return(!onInputError("ValidateInputs(10)  "+ sequence.name +" invalid input parameter BreakoutReversal: "+ NumberToStr(BreakoutReversal, ".1+") +" (must be larger than MODE_STOPLEVEL)"));
   double minLots=MarketInfo(Symbol(), MODE_MINLOT), maxLots=MarketInfo(Symbol(), MODE_MAXLOT);
   if (UseMoneyManagement) {
      // Risk
      if (LE(Risk, 0))                                       return(!onInputError("ValidateInputs(11)  "+ sequence.name +" invalid input parameter Risk: "+ NumberToStr(Risk, ".1+") +" (must be positive)"));
      double lots = CalculateLots(false); if (IsLastError()) return(false);
      if (LT(lots, minLots))                                 return(!onInputError("ValidateInputs(12)  "+ sequence.name +" not enough money ("+ DoubleToStr(AccountEquity()-AccountCredit(), 2) +") for input parameter Risk="+ NumberToStr(Risk, ".1+") +" (resulting position size "+ NumberToStr(lots, ".1+") +" smaller than MODE_MINLOT="+ NumberToStr(minLots, ".1+") +")"));
      if (GT(lots, maxLots))                                 return(!onInputError("ValidateInputs(13)  "+ sequence.name +" too large input parameter Risk: "+ NumberToStr(Risk, ".1+") +" (resulting position size "+ NumberToStr(lots, ".1+") +" larger than MODE_MAXLOT="+  NumberToStr(maxLots, ".1+") +")"));
   }
   else {
      // ManualLotsize
      if (LT(ManualLotsize, minLots))                        return(!onInputError("ValidateInputs(14)  "+ sequence.name +" too small input parameter ManualLotsize: "+ NumberToStr(ManualLotsize, ".1+") +" (smaller than MODE_MINLOT="+ NumberToStr(minLots, ".1+") +")"));
      if (GT(ManualLotsize, maxLots))                        return(!onInputError("ValidateInputs(15)  "+ sequence.name +" too large input parameter ManualLotsize: "+ NumberToStr(ManualLotsize, ".1+") +" (larger than MODE_MAXLOT="+ NumberToStr(maxLots, ".1+") +")"));
   }

   // StopOnTotalProfit / StopOnTotalLoss
   if (StopOnTotalProfit && StopOnTotalLoss) {
      if (StopOnTotalProfit <= StopOnTotalLoss)              return(!onInputError("ValidateInputs(16)  "+ sequence.name +" input parameter mis-match StopOnTotalProfit="+ DoubleToStr(StopOnTotalProfit, 2) +" / StopOnTotalLoss="+ DoubleToStr(StopOnTotalLoss, 2) +" (profit must be larger than loss)"));
   }

   // Sessionbreak.StartTime/EndTime
   if (Sessionbreak.StartTime!=prev.Sessionbreak.StartTime || Sessionbreak.EndTime!=prev.Sessionbreak.EndTime) {
      sessionbreak.starttime = NULL;
      sessionbreak.endtime   = NULL;                         // real times are updated automatically on next use
      sessionbreak.active    = false;
   }

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
      return(logError(message, error));                      // non-terminating
   return(catch(message, error));
}


/**
 * (Re-)initialize metrics processing.
 *
 * @return bool - success status
 */
bool InitMetrics() {
   if (!metrics.initialized) {
      // metadata is initialized only once
      ArrayInitialize(metrics.enabled,   0);
      ArrayInitialize(metrics.symbolOK,  0);
      ArrayInitialize(metrics.hSet,      0);
      ArrayInitialize(metrics.hShift, 1000);

      // populate symbol metadata
      metrics.symbol[METRIC_RC1] = "XMT"+ sequence.id +".RC1"; metrics.digits[METRIC_RC1] = 1; metrics.description[METRIC_RC1] = "XMT."+ sequence.id +" real cumulative PL in pip w/o commission";
      metrics.symbol[METRIC_RC2] = "XMT"+ sequence.id +".RC2"; metrics.digits[METRIC_RC2] = 1; metrics.description[METRIC_RC2] = "XMT."+ sequence.id +" real cumulative PL in pip with commission";
      metrics.symbol[METRIC_RC3] = "XMT"+ sequence.id +".RC3"; metrics.digits[METRIC_RC3] = 2; metrics.description[METRIC_RC3] = "XMT."+ sequence.id +" real cumulative PL in "+ AccountCurrency() +" w/o commission";
      metrics.symbol[METRIC_RC4] = "XMT"+ sequence.id +".RC4"; metrics.digits[METRIC_RC4] = 2; metrics.description[METRIC_RC4] = "XMT."+ sequence.id +" real cumulative PL in "+ AccountCurrency() +" with commission";
      metrics.symbol[METRIC_RD1] = "XMT"+ sequence.id +".RC1"; metrics.digits[METRIC_RD1] = 1; metrics.description[METRIC_RD1] = "XMT."+ sequence.id +" real daily PL in pip w/o commission";
      metrics.symbol[METRIC_RD2] = "XMT"+ sequence.id +".RC2"; metrics.digits[METRIC_RD2] = 1; metrics.description[METRIC_RD2] = "XMT."+ sequence.id +" real daily PL in pip with commission";
      metrics.symbol[METRIC_RD3] = "XMT"+ sequence.id +".RC3"; metrics.digits[METRIC_RD3] = 2; metrics.description[METRIC_RD3] = "XMT."+ sequence.id +" real daily PL in "+ AccountCurrency() +" w/o commission";
      metrics.symbol[METRIC_RD4] = "XMT"+ sequence.id +".RC4"; metrics.digits[METRIC_RD4] = 2; metrics.description[METRIC_RD4] = "XMT."+ sequence.id +" real daily PL in "+ AccountCurrency() +" with commission";

      metrics.symbol[METRIC_VC1] = "XMT"+ sequence.id +".VC1"; metrics.digits[METRIC_VC1] = 1; metrics.description[METRIC_VC1] = "XMT."+ sequence.id +" virtual cumulative PL in pip w/o commission";
      metrics.symbol[METRIC_VC2] = "XMT"+ sequence.id +".VC2"; metrics.digits[METRIC_VC2] = 1; metrics.description[METRIC_VC2] = "XMT."+ sequence.id +" virtual cumulative PL in pip with commission";
      metrics.symbol[METRIC_VC3] = "XMT"+ sequence.id +".VC3"; metrics.digits[METRIC_VC3] = 2; metrics.description[METRIC_VC3] = "XMT."+ sequence.id +" virtual cumulative PL in "+ AccountCurrency() +" w/o commission";
      metrics.symbol[METRIC_VC4] = "XMT"+ sequence.id +".VC4"; metrics.digits[METRIC_VC4] = 2; metrics.description[METRIC_VC4] = "XMT."+ sequence.id +" virtual cumulative PL in "+ AccountCurrency() +" with commission";
      metrics.symbol[METRIC_VD1] = "XMT"+ sequence.id +".VC1"; metrics.digits[METRIC_VD1] = 1; metrics.description[METRIC_VD1] = "XMT."+ sequence.id +" virtual daily PL in pip w/o commission";
      metrics.symbol[METRIC_VD2] = "XMT"+ sequence.id +".VC2"; metrics.digits[METRIC_VD2] = 1; metrics.description[METRIC_VD2] = "XMT."+ sequence.id +" virtual daily PL in pip with commission";
      metrics.symbol[METRIC_VD3] = "XMT"+ sequence.id +".VC3"; metrics.digits[METRIC_VD3] = 2; metrics.description[METRIC_VD3] = "XMT."+ sequence.id +" virtual daily PL in "+ AccountCurrency() +" w/o commission";
      metrics.symbol[METRIC_VD4] = "XMT"+ sequence.id +".VC4"; metrics.digits[METRIC_VD4] = 2; metrics.description[METRIC_VD4] = "XMT."+ sequence.id +" virtual daily PL in "+ AccountCurrency() +" with commission";

      metrics.initialized = true;
   }

   // read the metrics configuration (on every call)
   string section = ProgramName() + ifString(IsTesting(), ".Tester", "");
   metrics.enabled[METRIC_RC1] = (tradingMode!=TRADINGMODE_VIRTUAL && RecordPerformanceMetrics && GetConfigBool(section, "Metric.RC1", true));
   metrics.enabled[METRIC_RC2] = (tradingMode!=TRADINGMODE_VIRTUAL && RecordPerformanceMetrics && GetConfigBool(section, "Metric.RC2", true));
   metrics.enabled[METRIC_RC3] = (tradingMode!=TRADINGMODE_VIRTUAL && RecordPerformanceMetrics && GetConfigBool(section, "Metric.RC3", true));
   metrics.enabled[METRIC_RC4] = (tradingMode!=TRADINGMODE_VIRTUAL && RecordPerformanceMetrics && GetConfigBool(section, "Metric.RC4", true));
   metrics.enabled[METRIC_RD1] = (tradingMode!=TRADINGMODE_VIRTUAL && RecordPerformanceMetrics && GetConfigBool(section, "Metric.RD1", true));
   metrics.enabled[METRIC_RD2] = (tradingMode!=TRADINGMODE_VIRTUAL && RecordPerformanceMetrics && GetConfigBool(section, "Metric.RD2", true));
   metrics.enabled[METRIC_RD3] = (tradingMode!=TRADINGMODE_VIRTUAL && RecordPerformanceMetrics && GetConfigBool(section, "Metric.RD3", true));
   metrics.enabled[METRIC_RD4] = (tradingMode!=TRADINGMODE_VIRTUAL && RecordPerformanceMetrics && GetConfigBool(section, "Metric.RD4", true));

   metrics.enabled[METRIC_VC1] = (tradingMode!=TRADINGMODE_REGULAR && RecordPerformanceMetrics && GetConfigBool(section, "Metric.VC1", true));
   metrics.enabled[METRIC_VC2] = (tradingMode!=TRADINGMODE_REGULAR && RecordPerformanceMetrics && GetConfigBool(section, "Metric.VC2", true));
   metrics.enabled[METRIC_VC3] = (tradingMode!=TRADINGMODE_REGULAR && RecordPerformanceMetrics && GetConfigBool(section, "Metric.VC3", true));
   metrics.enabled[METRIC_VC4] = (tradingMode!=TRADINGMODE_REGULAR && RecordPerformanceMetrics && GetConfigBool(section, "Metric.VC4", true));
   metrics.enabled[METRIC_VD1] = (tradingMode!=TRADINGMODE_REGULAR && RecordPerformanceMetrics && GetConfigBool(section, "Metric.VD1", true));
   metrics.enabled[METRIC_VD2] = (tradingMode!=TRADINGMODE_REGULAR && RecordPerformanceMetrics && GetConfigBool(section, "Metric.VD2", true));
   metrics.enabled[METRIC_VD3] = (tradingMode!=TRADINGMODE_REGULAR && RecordPerformanceMetrics && GetConfigBool(section, "Metric.VD3", true));
   metrics.enabled[METRIC_VD4] = (tradingMode!=TRADINGMODE_REGULAR && RecordPerformanceMetrics && GetConfigBool(section, "Metric.VD4", true));

   int size = ArraySize(metrics.enabled);
   for (int i=0; i < size; i++) {
      InitMetricHistory(i);
   }
   return(!catch("InitMetrics(1)"));
}


/**
 * Open/close the history of the specified metric according to the configuration.
 *
 * @param  int metric - metric identifier
 *
 * @return bool - success status
 */
bool InitMetricHistory(int metric) {
   if (!metrics.enabled[metric]) {
      CloseHistorySet(metric);                                       // make sure the history is closed
      return(true);
   }

   if (!metrics.symbolOK[metric]) {
      if (metrics.server != "") {
         if (!IsRawSymbol(metrics.symbol[metric], metrics.server)) { // create a new symbol if it doesn't yet exist
            string group = "System metrics";
            int sId = CreateRawSymbol(metrics.symbol[metric], metrics.description[metric], group, metrics.digits[metric], AccountCurrency(), AccountCurrency(), metrics.server);
            if (sId < 0) return(false);
         }
      }
      metrics.symbolOK[metric] = true;
   }

   if (!metrics.hSet[metric]) {
      metrics.hSet[metric] = GetHistorySet(metric);                  // open the history
   }

   return(metrics.hSet[metric] != NULL);
}


/**
 * Return a handle for the HistorySet of the specified metric.
 *
 * @param  int mId - metric identifier
 *
 * @return int - HistorySet handle or NULL in case of other errors
 */
int GetHistorySet(int mId) {
   int hSet;
   if      (mId <  6) hSet = HistorySet1.Get(metrics.symbol[mId], metrics.server);
   else if (mId < 12) hSet = HistorySet2.Get(metrics.symbol[mId], metrics.server);
   else               hSet = HistorySet3.Get(metrics.symbol[mId], metrics.server);

   if (hSet == -1) {
      if      (mId <  6) hSet = HistorySet1.Create(metrics.symbol[mId], metrics.description[mId], metrics.digits[mId], metrics.format, metrics.server);
      else if (mId < 12) hSet = HistorySet2.Create(metrics.symbol[mId], metrics.description[mId], metrics.digits[mId], metrics.format, metrics.server);
      else               hSet = HistorySet3.Create(metrics.symbol[mId], metrics.description[mId], metrics.digits[mId], metrics.format, metrics.server);
   }

   if (hSet > 0)
      return(hSet);
   return(NULL);
}


/**
 * Close the HistorySet of the specified metric.
 *
 * @param  int mId - metric identifier
 *
 * @return bool - success status
 */
bool CloseHistorySet(int mId) {
   if (!metrics.hSet[mId]) return(true);

   bool success = false;
   if      (mId <  6) success = HistorySet1.Close(metrics.hSet[mId]);
   else if (mId < 12) success = HistorySet2.Close(metrics.hSet[mId]);
   else               success = HistorySet3.Close(metrics.hSet[mId]);

   metrics.hSet[mId] = NULL;
   return(success);
}


/**
 * Record performance metrics of the sequence.
 *
 * @return bool - success status
 */
bool RecordMetrics() {
   double value;
   bool success = true;

   static int flags;
   static bool flagsInitialized = false; if (!flagsInitialized) {
      flags = ifInt(IsTesting(), HST_BUFFER_TICKS, NULL);      // buffer ticks in tester
      flagsInitialized = true;
   }

   // real metrics
   if (metrics.enabled[METRIC_RC1] && success) {               // cumulative PL in pip w/o commission
      value   = real.totalPip + metrics.hShift[METRIC_RC1];
      success = HistorySet1.AddTick(metrics.hSet[METRIC_RC1], Tick.time, value, flags);
   }
   if (metrics.enabled[METRIC_RC2] && success) {               // cumulative PL in pip with commission
      value   = real.totalPipNet + metrics.hShift[METRIC_RC2];
      success = HistorySet1.AddTick(metrics.hSet[METRIC_RC2], Tick.time, value, flags);
   }
   if (metrics.enabled[METRIC_RC3] && success) {               // cumulative PL in money w/o commission
      value   = real.totalPl + metrics.hShift[METRIC_RC3];
      success = HistorySet1.AddTick(metrics.hSet[METRIC_RC3], Tick.time, value, flags);
   }
   if (metrics.enabled[METRIC_RC4] && success) {               // cumulative PL in money with commission
      value   = real.totalPlNet + metrics.hShift[METRIC_RC4];
      success = HistorySet1.AddTick(metrics.hSet[METRIC_RC4], Tick.time, value, flags);
   }
 //if (metrics.enabled[METRIC_RD1] && success) {               // daily PL in pip w/o commission
 //   value   = AccountEquity()-AccountCredit();
 //   success = HistorySet1.AddTick(metrics.hSet[METRIC_RD1], Tick.time, value, flags);
 //}
 //if (metrics.enabled[METRIC_RD2] && success) {               // daily PL in pip with commission
 //   value   = AccountEquity()-AccountCredit();
 //   success = HistorySet1.AddTick(metrics.hSet[METRIC_RD2], Tick.time, value, flags);
 //}
 //if (metrics.enabled[METRIC_RD3] && success) {               // daily PL in money w/o commission
 //   value   = AccountEquity()-AccountCredit();
 //   success = HistorySet2.AddTick(metrics.hSet[METRIC_RD3], Tick.time, value, flags);
 //}
 //if (metrics.enabled[METRIC_RD4] && success) {               // daily PL in money with commission
 //   value   = AccountEquity()-AccountCredit();
 //   success = HistorySet2.AddTick(metrics.hSet[METRIC_RD4], Tick.time, value, flags);
 //}

   // virtual metrics
   if (metrics.enabled[METRIC_VC1] && success) {               // cumulative PL in pip w/o commission
      value   = virt.totalPip + metrics.hShift[METRIC_VC1];
      success = HistorySet2.AddTick(metrics.hSet[METRIC_VC1], Tick.time, value, flags);
   }
   if (metrics.enabled[METRIC_VC2] && success) {               // cumulative PL in pip with commission
      value   = virt.totalPipNet + metrics.hShift[METRIC_VC2];
      success = HistorySet2.AddTick(metrics.hSet[METRIC_VC2], Tick.time, value, flags);
   }
   if (metrics.enabled[METRIC_VC3] && success) {               // cumulative PL in money w/o commission
      value   = virt.totalPl + metrics.hShift[METRIC_VC3];
      success = HistorySet2.AddTick(metrics.hSet[METRIC_VC3], Tick.time, value, flags);
   }
   if (metrics.enabled[METRIC_VC4] && success) {               // cumulative PL in money with commission
      value   = virt.totalPlNet + metrics.hShift[METRIC_VC4];
      success = HistorySet2.AddTick(metrics.hSet[METRIC_VC4], Tick.time, value, flags);
   }
 //if (metrics.enabled[METRIC_VD1] && success) {               // daily PL in pip w/o commission
 //   value   = AccountEquity()-AccountCredit();
 //   success = HistorySet3.AddTick(metrics.hSet[METRIC_VD1], Tick.time, value, flags);
 //}
 //if (metrics.enabled[METRIC_VD2] && success) {               // daily PL in pip with commission
 //   value   = AccountEquity()-AccountCredit();
 //   success = HistorySet3.AddTick(metrics.hSet[METRIC_VD2], Tick.time, value, flags);
 //}
 //if (metrics.enabled[METRIC_VD3] && success) {               // daily PL in money w/o commission
 //   value   = AccountEquity()-AccountCredit();
 //   success = HistorySet3.AddTick(metrics.hSet[METRIC_VD3], Tick.time, value, flags);
 //}
 //if (metrics.enabled[METRIC_VD4] && success) {               // daily PL in money with commission
 //   value   = AccountEquity()-AccountCredit();
 //   success = HistorySet3.AddTick(metrics.hSet[METRIC_VD4], Tick.time, value, flags);
 //}
   return(success);
}


/**
 * Return a string representation of the input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return("Sequence.ID="             + DoubleQuoteStr(Sequence.ID)                  +";"+ NL
         +"TradingMode="             + DoubleQuoteStr(TradingMode)                  +";"+ NL

         +"EntryIndicator="          + EntryIndicator                               +";"+ NL
         +"IndicatorTimeframe="      + IndicatorTimeframe                           +";"+ NL
         +"IndicatorPeriods="        + IndicatorPeriods                             +";"+ NL
         +"BollingerBands.Deviation="+ NumberToStr(BollingerBands.Deviation, ".1+") +";"+ NL
         +"Envelopes.Deviation="     + NumberToStr(Envelopes.Deviation, ".1+")      +";"+ NL

         +"UseSpreadMultiplier="     + BoolToStr(UseSpreadMultiplier)               +";"+ NL
         +"SpreadMultiplier="        + NumberToStr(SpreadMultiplier, ".1+")         +";"+ NL
         +"MinBarSize="              + DoubleToStr(MinBarSize, 1)                   +";"+ NL

         +"BreakoutReversal="        + DoubleToStr(BreakoutReversal, 1)             +";"+ NL
         +"MaxSpread="               + DoubleToStr(MaxSpread, 1)                    +";"+ NL
         +"ReverseSignals="          + BoolToStr(ReverseSignals)                    +";"+ NL

         +"UseMoneyManagement="      + BoolToStr(UseMoneyManagement)                +";"+ NL
         +"Risk="                    + NumberToStr(Risk, ".1+")                     +";"+ NL
         +"ManualLotsize="           + NumberToStr(ManualLotsize, ".1+")            +";"+ NL

         +"TakeProfit="              + DoubleToStr(TakeProfit, 1)                   +";"+ NL
         +"StopLoss="                + DoubleToStr(StopLoss, 1)                     +";"+ NL
         +"TrailEntryStep="          + DoubleToStr(TrailEntryStep, 1)               +";"+ NL
         +"TrailExitStart="          + DoubleToStr(TrailExitStart, 1)               +";"+ NL
         +"TrailExitStep="           + DoubleToStr(TrailExitStep, 1)                +";"+ NL
         +"StopOnTotalProfit="       + DoubleToStr(StopOnTotalProfit, 2)            +";"+ NL
         +"StopOnTotalLoss="         + DoubleToStr(StopOnTotalLoss, 2)              +";"+ NL
         +"MaxSlippage="             + DoubleToStr(MaxSlippage, 1)                  +";"+ NL
         +"Sessionbreak.StartTime="  + TimeToStr(Sessionbreak.StartTime, TIME_FULL) +";"+ NL
         +"Sessionbreak.EndTime="    + TimeToStr(Sessionbreak.EndTime, TIME_FULL)   +";"+ NL

         +"RecordPerformanceMetrics="+ BoolToStr(RecordPerformanceMetrics)          +";"+ NL
         +"MetricsServerDirectory="  + DoubleQuoteStr(MetricsServerDirectory)       +";"+ NL

         +"ChannelBug="              + BoolToStr(ChannelBug)                        +";"+ NL
         +"TakeProfitBug="           + BoolToStr(TakeProfitBug)                     +";"
   );

   // prevent compiler warnings
   DumpVirtualOrder(NULL);
}
