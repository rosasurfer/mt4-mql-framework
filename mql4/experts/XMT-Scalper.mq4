/**
 * XMT-Scalper revisited
 *
 *
 * This EA is originally based on the infamous "MillionDollarPips EA". The core idea of the strategy is scalping based on a
 * reversal from a channel breakout. Over the years it has gone through multiple transformations. Today various versions with
 * different names circulate in the internet (MDP-Plus, XMT-Scalper, Assar). None of them is suitable for real trading, mainly
 * due to lack of signal documentation and a significant amount of issues in the program logic.
 *
 * This version is a complete rewrite.
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
 *  - added virtual trading mode with optional trade copier or trade mirror
 *  - added recording of performance metrics for real and virtual trading
 */
#include <stddefines.mqh>
int   __InitFlags[] = {INIT_TIMEZONE, INIT_PIPVALUE, INIT_BUFFERED_LOG};
int __DeinitFlags[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern string Sequence.ID                     = "";         // instance id in the range of 1000-9999
extern string TradingMode                     = "Regular* | Virtual | Virtual-Copier | Virtual-Mirror";     // shortcuts: "R | V | VC | VM"

extern string ___a___________________________ = "=== Entry indicator: 1=MovingAverage, 2=BollingerBands, 3=Envelopes ===";
extern int    EntryIndicator                  = 1;          // entry signal indicator for price channel calculation
extern int    IndicatorTimeframe              = PERIOD_M1;  // entry indicator timeframe
extern int    IndicatorPeriods                = 3;          // entry indicator bar periods
extern double BollingerBands.Deviation        = 2;          // standard deviations
extern double Envelopes.Deviation             = 0.07;       // in percent

extern string ___b___________________________ = "=== Entry bar size conditions ================";
extern bool   UseSpreadMultiplier             = true;       // use spread multiplier or fixed min. bar size
extern double SpreadMultiplier                = 12.5;       // min. bar size = SpreadMultiplier * avgSpread
extern double MinBarSize                      = 18;         // min. bar size in {pip}

extern string ___c___________________________ = "=== Signal settings ========================";
extern double BreakoutReversal                = 0;          // required price reversal in {pip} (0: counter-trend trading w/o reversal)
extern double MaxSpread                       = 2;          // max. acceptable current and average spread in {pip}
extern bool   ReverseSignals                  = false;      // Buy => Sell, Sell => Buy

extern string ___d___________________________ = "=== Money management ===================";
extern bool   MoneyManagement                 = true;       // TRUE: calculate lots dynamically; FALSE: use "ManualLotsize"
extern double Risk                            = 2;          // percent of equity to risk with each trade
extern double ManualLotsize                   = 0.01;       // fix position to use if "MoneyManagement" is FALSE

extern string ___e___________________________ = "=== Trade settings ========================";
extern double TakeProfit                      = 10;         // TP in {pip}
extern double StopLoss                        = 6;          // SL in {pip}
extern double TrailEntryStep                  = 1;          // trail entry limits every {pip}
extern double TrailExitStart                  = 0;          // start trailing exit limits after {pip} in profit
extern double TrailExitStep                   = 2;          // trail exit limits every {pip} in profit
extern int    MagicNumber                     = 0;          // predefined magic order id, if zero a new one is generated
extern double MaxSlippage                     = 0.3;        // max. acceptable slippage in {pip}

extern string ___f___________________________ = "=== Overall targets & Reporting ==============";
extern double EA.StopOnProfit                 = 0;          // stop on overall profit in {money} (0: no stop on profits)
extern double EA.StopOnLoss                   = 0;          // stop on overall loss in {money} (0: no stop on losses)
extern bool   EA.RecordMetrics                = false;      // whether to enable recording of performance metrics

extern string ___g___________________________ = "=== Bugs ================================";
extern bool   ChannelBug                      = false;      // whether to enable erroneous calculation of the breakout channel (for comparison only)
extern bool   TakeProfitBug                   = true;       // whether to enable erroneous calculation of TakeProfit targets (for comparison only)

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/expert.mqh>
#include <stdfunctions.mqh>
#include <rsfLibs.mqh>
#include <rsfHistory.mqh>
#include <functions/JoinStrings.mqh>
#include <structs/rsf/OrderExecution.mqh>

#define STRATEGY_ID               106           // unique strategy id from 101-1023 (10 bit)

#define TRADINGMODE_REGULAR         1
#define TRADINGMODE_VIRTUAL         2
#define TRADINGMODE_VIRTUAL_COPIER  3
#define TRADINGMODE_VIRTUAL_MIRROR  4

#define SIGNAL_LONG                 1
#define SIGNAL_SHORT                2

#define METRIC_RC0                  0           // real: cumulative PL in pip w/o commission
#define METRIC_RC1                  1           // real: cumulative PL in pip with commission
#define METRIC_RC2                  2           // real: cumulative PL in money w/o commission
#define METRIC_RC3                  3           // real: cumulative PL in money with commission
#define METRIC_RD0                  4           // real: daily PL in pip w/o commission
#define METRIC_RD1                  5           // real: daily PL in pip with commission
#define METRIC_RD2                  6           // real: daily PL in money w/o commission
#define METRIC_RD3                  7           // real: daily PL in money with commission

#define METRIC_VC0                  8           // virt: cumulative PL in pip w/o commission
#define METRIC_VC1                  9           // virt: cumulative PL in pip with commission
#define METRIC_VC2                 10           // virt: cumulative PL in money w/o commission
#define METRIC_VC3                 11           // virt: cumulative PL in money with commission
#define METRIC_VD0                 12           // virt: daily PL in pip w/o commission
#define METRIC_VD1                 13           // virt: daily PL in pip with commission
#define METRIC_VD2                 14           // virt: daily PL in money w/o commission
#define METRIC_VD3                 15           // virt: daily PL in money with commission


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
double   real.swap        [];                   // order swap
double   real.profit      [];                   // order profit (gross)

// real order statistics
bool     real.isSynchronized;                   // whether real and virtual trading are synchronized
bool     real.isOpenOrder;                      // whether an open order exists (max. 1 open order)
bool     real.isOpenPosition;                   // whether an open position exists (max. 1 open position)

double   real.openLots;                         // total open lotsize: -n...+n
double   real.openSwap;                         // total open swap
double   real.openCommission;                   // total open commissions
double   real.openPl;                           // total open gross profit in money
double   real.openPlNet;                        // total open net profit in money
double   real.openPip;                          // total open gross profit in pip
double   real.openPipNet;                       // total open net profit in pip

int      real.closedPositions;                  // number of closed positions
double   real.closedLots;                       // total closed lotsize: 0...+n
double   real.closedCommission;                 // total closed commission
double   real.closedSwap;                       // total closed swap
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
double   virt.swap        [];
double   virt.profit      [];

// virtual order statistics
bool     virt.isOpenOrder;
bool     virt.isOpenPosition;

double   virt.openLots;
double   virt.openCommission;
double   virt.openSwap;
double   virt.openPl;
double   virt.openPlNet;
double   virt.openPip;
double   virt.openPipNet;

int      virt.closedPositions;
double   virt.closedLots;
double   virt.closedCommission;
double   virt.closedSwap;
double   virt.closedPl;
double   virt.closedPlNet;
double   virt.closedPip;
double   virt.closedPipNet;

double   virt.totalPl;                          // openPl     + closedPl
double   virt.totalPlNet;                       // openPlNet  + closedPlNet
double   virt.totalPip;                         // openPip    + closedPip
double   virt.totalPipNet;                      // openPipNet + closedPipNet

// metrics
bool     metrics.enabled[16];                   // activation status
int      metrics.hSet   [16];                   // vertical shift to prevent negative bar values (data is adjusted by this level)
double   metrics.vShift [16] = {1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000};

// other
double   currentSpread;                         // current spread in pip
double   avgSpread;                             // average spread in pip
double   minBarSize;                            // min. bar size in absolute terms
double   commissionPip;                         // commission in pip (independant of lotsize)
int      orderSlippage;                         // order slippage in point
int      orderMagicNumber;
string   orderComment = "";
string   tradingModeDescriptions[] = {"", "Regular", "Virtual", "Virtual-Copier", "Virtual-Mirror"};

// vars to speed-up status messages
string   sTradingModeStatus[] = {"", "", ": Virtual Trading", ": Virtual Trading + Copier", ": Virtual Trading + Mirror"};
string   sCurrentSpread       = "-";
string   sAvgSpread           = "-";
string   sMaxSpread           = "-";
string   sCurrentBarSize      = "-";
string   sMinBarSize          = "-";
string   sIndicator           = "-";
string   sUnitSize            = "-";

// debug settings                               // configurable via framework config, see ::afterInit()
bool     test.onPositionOpenPause = false;      // whether to pause a test on PositionOpen events
bool     test.reduceStatusWrites  = true;       // whether to minimize status file writing in tester


#include <apps/xmt-scalper/init.mqh>
#include <apps/xmt-scalper/deinit.mqh>


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   double dNull;
   if (ChannelBug) GetIndicatorValues(dNull, dNull, dNull);       // if the channel bug is enabled indicators must be tracked every tick
   if (__isChart)  CalculateSpreads();                            // for the visible spread status display

   if (tradingMode == TRADINGMODE_REGULAR) onTick.RegularTrading();
   else                                    onTick.VirtualTrading();

   // record metrics if configured
   if (EA.RecordMetrics) {
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
   UpdateRealOrderStatus();                                       // update real order status and PL

   if (EA.StopOnProfit || EA.StopOnLoss) {
      if (!CheckTotalTargets()) return(last_error);               // i.e. ERR_CANCELLED_BY_USER
   }

   if (real.isOpenOrder) {
      if (real.isOpenPosition) ManageRealPosition();              // trail exit limits
      else                     ManagePendingOrder();              // trail entry limits or delete order
   }

   if (!last_error && !real.isOpenOrder) {
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
   }

   // manage virtual orders
   if (!last_error && virt.isOpenOrder) {
      if (virt.isOpenPosition) ManageVirtualPosition();           // trail exit limits
      else                     ManageVirtualOrder();              // trail entry limits or delete order
   }

   // manage real orders (if any)
   if (!last_error && real.isOpenOrder) {
      if (real.isOpenPosition) ManageRealPosition();              // trail exit limits
      else                     ManagePendingOrder();              // trail entry limits or delete order
   }

   // handle new entry signals
   if (!last_error && !virt.isOpenOrder) {
      int signal;
      if (IsEntrySignal(signal)) {
         OpenVirtualOrder(signal);

         if (tradingMode > TRADINGMODE_VIRTUAL) {
            OpenRealOrder(signal);
         }
      }
   }
   return(last_error);
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
         double lots = CalculateLots(true); if (!lots) return(false);
         color markerColor = ifInt(virt.openType[iV]==OP_LONG, Blue, Red);

         OrderSendEx(Symbol(), virt.openType[iV], lots, NULL, orderSlippage, virt.stopLoss[iV], virt.takeProfit[iV], orderComment, orderMagicNumber, NULL, markerColor, NULL, oe);
         if (oe.IsError(oe)) return(false);

         // update the link
         Orders.AddRealTicket(oe.Ticket(oe), virt.ticket[iV], oe.Lots(oe), oe.Type(oe), oe.OpenTime(oe), oe.OpenPrice(oe), NULL, NULL, oe.StopLoss(oe), oe.TakeProfit(oe), NULL, NULL, NULL);
         virt.linkedTicket[iV] = oe.Ticket(oe);
      }
   }
   else return(!catch("SynchronizeTradeCopier(6)  "+ sequence.name +" virt.isPendingOrder=TRUE, synchronization not implemented", ERR_NOT_IMPLEMENTED));

   real.isSynchronized = true;
   return(true);
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
         int type = ifInt(virt.openType[iV]==OP_BUY, OP_SELL, OP_BUY);          // opposite direction
         double lots = CalculateLots(true); if (!lots) return(false);
         color markerColor = ifInt(virt.openType[iV]==OP_LONG, Red, Blue);

         OrderSendEx(Symbol(), type, lots, NULL, orderSlippage, virt.takeProfit[iV], virt.stopLoss[iV], orderComment, orderMagicNumber, NULL, markerColor, NULL, oe);
         if (oe.IsError(oe)) return(false);

         // update the link
         Orders.AddRealTicket(oe.Ticket(oe), virt.ticket[iV], oe.Lots(oe), oe.Type(oe), oe.OpenTime(oe), oe.OpenPrice(oe), NULL, NULL, oe.StopLoss(oe), oe.TakeProfit(oe), NULL, NULL, NULL);
         virt.linkedTicket[iV] = oe.Ticket(oe);
      }
   }
   else return(!catch("SynchronizeTradeMirror(6)  "+ sequence.name +" virt.isPendingOrder=TRUE, synchronization not implemented", ERR_NOT_IMPLEMENTED));

   real.isSynchronized = true;
   return(true);
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
   real.openSwap       = 0;
   real.openPl         = 0;
   real.openPlNet      = 0;
   real.openPip        = 0;
   real.openPipNet     = 0;

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
            onRealOrderDelete(i);                                 // logs and removes order record
            orders--;
            continue;
         }
         else {
            if (!isPending) {                                     // the pending order was filled
               onRealPositionOpen(i);                             // updates order record and logs
               wasPosition = true;                                // mark as a known open position
            }
         }
      }

      if (wasPosition) {
         real.commission[i] = OrderCommission();
         real.swap      [i] = OrderSwap();
         real.profit    [i] = OrderProfit();

         if (isOpen) {
            real.openLots       += ifDouble(real.openType[i]==OP_BUY, real.lots[i], -real.lots[i]);
            real.openCommission += real.commission[i];
            real.openSwap       += real.swap      [i];
            real.openPl         += real.profit    [i];
            real.openPip        += ifDouble(real.openType[i]==OP_BUY, Bid-real.openPrice[i], real.openPrice[i]-Ask)/Pip;
         }
         else /*isClosed*/ {                                      // the position was closed
            onRealPositionClose(i);                               // updates order record and logs
            real.closedPositions++;                               // update closed trade statistics
            real.closedLots       += real.lots      [i];
            real.closedCommission += real.commission[i];
            real.closedSwap       += real.swap      [i];
            real.closedPl         += real.profit    [i];
            real.closedPip        += ifDouble(real.openType[i]==OP_BUY, real.closePrice[i]-real.openPrice[i], real.openPrice[i]-real.closePrice[i])/Pip;
         }
      }
   }

   real.openPlNet    = real.openSwap   + real.openCommission   + real.openPl;
   real.openPipNet   = real.openPip    - commissionPip;           // swap can be ignored
   real.closedPlNet  = real.closedSwap + real.closedCommission + real.closedPl;
   real.closedPipNet = real.closedPip  - commissionPip;           // swap can be ignored
   real.totalPl      = real.openPl     + real.closedPl;
   real.totalPlNet   = real.openPlNet  + real.closedPlNet;
   real.totalPip     = real.openPip    + real.closedPip;
   real.totalPipNet  = real.openPipNet + real.closedPipNet;

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
   virt.openSwap       = 0;
   virt.openPl         = 0;
   virt.openPlNet      = 0;
   virt.openPip        = 0;
   virt.openPipNet     = 0;

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
            virt.openCommission += virt.commission[i];            // swap is ignored in virtual trading
            virt.openPl         += virt.profit    [i];
            virt.openPip        += openPip;
         }
         else /*isClosed*/ {                                      // an exit limit was triggered
            virt.isOpenOrder = false;                             // mark order status
            onVirtualPositionClose(i);                            // updates order record, exit PL and logs
            virt.closedPositions++;                               // update closed trade statistics
            virt.closedLots       += virt.lots      [i];
            virt.closedCommission += virt.commission[i];
            virt.closedPl         += virt.profit    [i];
            virt.closedPip        += ifDouble(virt.openType[i]==OP_BUY, virt.closePrice[i]-virt.openPrice[i], virt.openPrice[i]-virt.closePrice[i])/Pip;
         }
      }
   }

   virt.openPlNet    = virt.openSwap   + virt.openCommission   + virt.openPl;
   virt.openPipNet   = virt.openPip    - commissionPip;           // swap can be ignored
   virt.closedPlNet  = virt.closedSwap + virt.closedCommission + virt.closedPl;
   virt.closedPipNet = virt.closedPip  - commissionPip;           // swap can be ignored
   virt.totalPl      = virt.openPl     + virt.closedPl;
   virt.totalPlNet   = virt.openPlNet  + virt.closedPlNet;
   virt.totalPip     = virt.openPip    + virt.closedPip;
   virt.totalPipNet  = virt.openPipNet + virt.closedPipNet;

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
   real.swap      [i] = OrderSwap();
   real.profit    [i] = OrderProfit();

   if (IsLogDebug()) {
      // #1 Stop Sell 0.1 GBPUSD at 1.5457'2[ "comment"] was filled[ at 1.5457'2] (market: Bid/Ask[, 0.3 pip [positive ]slippage])
      int    pendingType  = real.pendingType [i];
      double pendingPrice = real.pendingPrice[i];

      string sType         = OperationTypeDescription(pendingType);
      string sPendingPrice = NumberToStr(pendingPrice, PriceFormat);
      string sComment      = ""; if (StringLen(OrderComment()) > 0) sComment = " "+ DoubleQuoteStr(OrderComment());
      string message       = "#"+ OrderTicket() +" "+ sType +" "+ NumberToStr(OrderLots(), ".+") +" "+ Symbol() +" at "+ sPendingPrice + sComment +" was filled";

      string sSlippage = "";
      if (NE(OrderOpenPrice(), pendingPrice, Digits)) {
         double slippage = NormalizeDouble((pendingPrice-OrderOpenPrice())/Pip, 1); if (OrderType() == OP_SELL) slippage = -slippage;
            if (slippage > 0) sSlippage = ", "+ DoubleToStr(slippage, Digits & 1) +" pip positive slippage";
            else              sSlippage = ", "+ DoubleToStr(-slippage, Digits & 1) +" pip slippage";
         message = message +" at "+ NumberToStr(OrderOpenPrice(), PriceFormat);
      }
      logDebug("onRealPositionOpen(1)  "+ sequence.name +" "+ message +" (market: "+ NumberToStr(Bid, PriceFormat) +"/"+ NumberToStr(Ask, PriceFormat) + sSlippage +")");
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
   real.swap      [i] = OrderSwap();
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
      Test_onPositionClose(__ExecutionContext, OrderTicket(), OrderCloseTime(), OrderClosePrice(), OrderSwap(), OrderProfit());
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
   virt.closeTime[i] = Tick.Time;
   virt.profit   [i] = ifDouble(virt.openType[i]==OP_BUY, virt.closePrice[i]-virt.openPrice[i], virt.openPrice[i]-virt.closePrice[i])/Pip * PipValue(virt.lots[i]);

   if (IsLogDebug()) {
      // virtual #1 Sell 0.1 GBPUSD "comment" at 1.5457'2 was closed at 1.5457'2 [tp|sl] (market: Bid/Ask)
      string sType       = OperationTypeDescription(virt.openType[i]);
      string sOpenPrice  = NumberToStr(virt.openPrice[i], PriceFormat);
      string sClosePrice = NumberToStr(virt.closePrice[i], PriceFormat);
      string sCloseType  = "";
         if      (EQ(virt.closePrice[i], virt.takeProfit[i])) sCloseType = " [tp]";
         else if (EQ(virt.closePrice[i], virt.stopLoss  [i])) sCloseType = " [sl]";
      logDebug("onVirtualPositionClose(1)  "+ sequence.name +" virtual #"+ virt.ticket[i] +" "+ sType +" "+ NumberToStr(virt.lots[i], ".+") +" "+ Symbol() +" \""+ orderComment +"\" at "+ sOpenPrice +" was closed at "+ sClosePrice + sCloseType +" (market: "+ NumberToStr(Bid, PriceFormat) +"/"+ NumberToStr(Ask, PriceFormat) +")");
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
   if (last_error || real.isOpenOrder) return(false);

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
         if (IsLogDebug()) logDebug("IsEntrySignal(3)  "+ sequence.name +" "+ ifString(signal==SIGNAL_LONG, "LONG", "SHORT") +" signal (barSize="+ DoubleToStr(barSize/Pip, 1) +", minBarSize="+ sMinBarSize +", channel="+ NumberToStr(channelHigh, PriceFormat) +"/"+ NumberToStr(channelLow, PriceFormat) +", Bid="+ NumberToStr(Bid, PriceFormat) +")");
         return(true);
      }
   }
   return(false);
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

   double lots   = CalculateLots(true); if (!lots) return(false);
   double spread = Ask-Bid, price, takeProfit, stopLoss;
   int iV, virtualTicket, oe[];

   // regular trading
   if (tradingMode == TRADINGMODE_REGULAR) {
      if (signal == SIGNAL_LONG) {
         price      = Ask + BreakoutReversal*Pip;
         takeProfit = price + TakeProfit*Pip;
         stopLoss   = price - spread - StopLoss*Pip;

         if (!BreakoutReversal) OrderSendEx(Symbol(), OP_BUY,     lots, NULL,  orderSlippage, stopLoss, takeProfit, orderComment, orderMagicNumber, NULL, Blue, NULL, oe);
         else                   OrderSendEx(Symbol(), OP_BUYSTOP, lots, price, NULL,          stopLoss, takeProfit, orderComment, orderMagicNumber, NULL, Blue, NULL, oe);
      }
      else /*signal == SIGNAL_SHORT*/ {
         price      = Bid - BreakoutReversal*Pip;
         takeProfit = price - TakeProfit*Pip;
         stopLoss   = price + spread + StopLoss*Pip;

         if (!BreakoutReversal) OrderSendEx(Symbol(), OP_SELL,     lots, NULL,  orderSlippage, stopLoss, takeProfit, orderComment, orderMagicNumber, NULL, Red, NULL, oe);
         else                   OrderSendEx(Symbol(), OP_SELLSTOP, lots, price, NULL,          stopLoss, takeProfit, orderComment, orderMagicNumber, NULL, Red, NULL, oe);
      }
   }

   // virtual-copier
   else if (tradingMode == TRADINGMODE_VIRTUAL_COPIER) {
      iV = ArraySize(virt.ticket)-1;
      if (virt.openType[iV] == OP_UNDEFINED) return(!catch("OpenRealOrder(2)  "+ sequence.name +" opening of pending orders in "+ TradingModeToStr(tradingMode) +" not implemented", ERR_NOT_IMPLEMENTED));

      takeProfit    = virt.takeProfit[iV];
      stopLoss      = virt.stopLoss  [iV];
      virtualTicket = virt.ticket    [iV];
      virt.linkedTicket[iV] = OrderSendEx(Symbol(), virt.openType[iV], lots, NULL, orderSlippage, stopLoss, takeProfit, orderComment, orderMagicNumber, NULL, Red, NULL, oe);
   }

   // virtual-mirror
   else if (tradingMode == TRADINGMODE_VIRTUAL_MIRROR) {
      iV = ArraySize(virt.ticket)-1;
      if (virt.openType[iV] == OP_UNDEFINED) return(!catch("OpenRealOrder(3)  "+ sequence.name +" opening of pending orders in "+ TradingModeToStr(tradingMode) +" not implemented", ERR_NOT_IMPLEMENTED));

      int type      = ifInt(virt.openType[iV]==OP_BUY, OP_SELL, OP_BUY);
      takeProfit    = virt.stopLoss  [iV];
      stopLoss      = virt.takeProfit[iV];
      virtualTicket = virt.ticket    [iV];
      virt.linkedTicket[iV] = OrderSendEx(Symbol(), type, lots, NULL, orderSlippage, stopLoss, takeProfit, orderComment, orderMagicNumber, NULL, Red, NULL, oe);
   }

   if (oe.IsError(oe)) return(false);

   if (IsTesting()) {                                   // pause the test if configured
      if (IsVisualMode() && test.onPositionOpenPause) Tester.Pause("OpenRealOrder(4)");
   }

   if (!Orders.AddRealTicket(oe.Ticket(oe), virtualTicket, oe.Lots(oe), oe.Type(oe), oe.OpenTime(oe), oe.OpenPrice(oe), NULL, NULL, oe.StopLoss(oe), oe.TakeProfit(oe), NULL, NULL, NULL)) return(false);
   if (!SaveStatus()) return(false);
   return(true);
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

   int ticket, orderType;
   double openPrice, stopLoss, takeProfit, spread=Ask-Bid;

   if (signal == SIGNAL_LONG) {
      orderType  = ifInt(BreakoutReversal, OP_BUYSTOP, OP_BUY);
      openPrice  = Ask + BreakoutReversal*Pip;
      takeProfit = openPrice + TakeProfit*Pip;
      stopLoss   = openPrice - spread - StopLoss*Pip;
   }
   else if (signal == SIGNAL_SHORT) {
      orderType  = ifInt(BreakoutReversal, OP_SELLSTOP, OP_SELL);
      openPrice  = Bid - BreakoutReversal*Pip;
      takeProfit = openPrice - TakeProfit*Pip;
      stopLoss   = openPrice + spread + StopLoss*Pip;
   }
   else return(!catch("OpenVirtualOrder(1)  "+ sequence.name +" invalid parameter signal: "+ signal, ERR_INVALID_PARAMETER));

   double lots       = CalculateLots();      if (!lots)               return(false);
   double commission = GetCommission(-lots); if (IsEmpty(commission)) return(false);
   if (!Orders.AddVirtualTicket(ticket, NULL, lots, orderType, Tick.Time, openPrice, NULL, NULL, stopLoss, takeProfit, NULL, commission, NULL)) return(false);

   // opened virt. #1 Buy 0.5 GBPUSD "XMT" at 1.5524'8, sl=1.5500'0, tp=1.5600'0 (market: Bid/Ask)
   if (IsLogDebug()) logDebug("OpenVirtualOrder(2)  "+ sequence.name +" opened virtual #"+ ticket +" "+ OperationTypeDescription(orderType) +" "+ NumberToStr(lots, ".+") +" "+ Symbol() +" \""+ orderComment +"\" at "+ NumberToStr(openPrice, PriceFormat) +", sl="+ NumberToStr(stopLoss, PriceFormat) +", tp="+ NumberToStr(takeProfit, PriceFormat) +" (market: "+ NumberToStr(Bid, PriceFormat) +"/"+ NumberToStr(Ask, PriceFormat) +")");

   if (IsTesting()) {                                   // pause the test if configured
      if (IsVisualMode() && test.onPositionOpenPause) Tester.Pause("OpenVirtualOrder(3)");
   }
   return(true);
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
            return(true);
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
            return(true);
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
   }
   return(true);
}


/**
 * Check total profit targets and stop the EA if targets have been reached.
 *
 * @return bool - whether the EA shall continue trading, i.e. FALSE on EA stop or in case of errors
 */
bool CheckTotalTargets() {
   bool stopEA = false;
   if (EA.StopOnProfit != 0) stopEA = stopEA || GE(real.totalPlNet, EA.StopOnProfit);
   if (EA.StopOnLoss   != 0) stopEA = stopEA || LE(real.totalPlNet, EA.StopOnProfit);

   if (stopEA) {
      if (!CloseOpenOrders())
         return(false);
      return(!SetLastError(ERR_CANCELLED_BY_USER));
   }
   return(true);
}


/**
 * Close all open orders.
 *
 * @return bool - success status
 */
bool CloseOpenOrders() {
   return(!catch("CloseOpenOrders(1)  "+ sequence.name, ERR_NOT_IMPLEMENTED));
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

   if (MoneyManagement) {
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
   ArrayResize(real.swap,         0);
   ArrayResize(real.profit,       0);

   real.isOpenOrder      = false;
   real.isOpenPosition   = false;
   real.openLots         = 0;
   real.openSwap         = 0;
   real.openCommission   = 0;
   real.openPl           = 0;
   real.openPlNet        = 0;
   real.openPip          = 0;
   real.openPipNet       = 0;
   real.closedPositions  = 0;
   real.closedLots       = 0;
   real.closedSwap       = 0;
   real.closedCommission = 0;
   real.closedPl         = 0;
   real.closedPlNet      = 0;
   real.closedPip        = 0;
   real.closedPipNet     = 0;
   real.totalPl          = 0;
   real.totalPlNet       = 0;
   real.totalPip         = 0;
   real.totalPipNet      = 0;

   // all closed positions
   int orders = OrdersHistoryTotal();
   for (int i=0; i < orders; i++) {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) return(!catch("ReadOrderLog(1)", ifIntOr(GetLastError(), ERR_RUNTIME_ERROR)));
      if (OrderMagicNumber() != orderMagicNumber) continue;
      if (OrderType() > OP_SELL)                  continue;
      if (OrderSymbol() != Symbol())              continue;

      if (!Orders.AddRealTicket(OrderTicket(), NULL, OrderLots(), OrderType(), OrderOpenTime(), OrderOpenPrice(), OrderCloseTime(), OrderClosePrice(), OrderStopLoss(), OrderTakeProfit(), OrderSwap(), OrderCommission(), OrderProfit()))
         return(false);
   }

   // all open orders
   orders = OrdersTotal();
   for (i=0; i < orders; i++) {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) return(!catch("ReadOrderLog(2)", ifIntOr(GetLastError(), ERR_RUNTIME_ERROR)));
      if (OrderMagicNumber() != orderMagicNumber) continue;
      if (OrderSymbol() != Symbol())              continue;

      if (!Orders.AddRealTicket(OrderTicket(), NULL, OrderLots(), OrderType(), OrderOpenTime(), OrderOpenPrice(), NULL, NULL, OrderStopLoss(), OrderTakeProfit(), OrderSwap(), OrderCommission(), OrderProfit()))
         return(false);
   }
   return(!catch("ReadOrderLog(3)"));
}


/**
 * Initialize performance metrics.
 *
 * @return bool - success status
 */
bool InitMetrics() {
   string section = ProgramName() + ifString(IsTesting(), ".Tester", "");

   // real
   metrics.enabled[METRIC_RC0] = (tradingMode!=TRADINGMODE_VIRTUAL && EA.RecordMetrics && GetConfigBool(section, "Metric_RC0", true));    // cumulative PL in pip w/o commission
   metrics.enabled[METRIC_RC1] = (tradingMode!=TRADINGMODE_VIRTUAL && EA.RecordMetrics && GetConfigBool(section, "Metric_RC1", true));    // cumulative PL in pip with commission
   metrics.enabled[METRIC_RC2] = (tradingMode!=TRADINGMODE_VIRTUAL && EA.RecordMetrics && GetConfigBool(section, "Metric_RC2", true));    // cumulative PL in money w/o commission
   metrics.enabled[METRIC_RC3] = (tradingMode!=TRADINGMODE_VIRTUAL && EA.RecordMetrics && GetConfigBool(section, "Metric_RC3", true));    // cumulative PL in money with commission
   metrics.enabled[METRIC_RD0] = (tradingMode!=TRADINGMODE_VIRTUAL && EA.RecordMetrics && GetConfigBool(section, "Metric_RD0", true));    // daily PL in pip w/o commission
   metrics.enabled[METRIC_RD1] = (tradingMode!=TRADINGMODE_VIRTUAL && EA.RecordMetrics && GetConfigBool(section, "Metric_RD1", true));    // daily PL in pip with commission
   metrics.enabled[METRIC_RD2] = (tradingMode!=TRADINGMODE_VIRTUAL && EA.RecordMetrics && GetConfigBool(section, "Metric_RD2", true));    // daily PL in money w/o commission
   metrics.enabled[METRIC_RD3] = (tradingMode!=TRADINGMODE_VIRTUAL && EA.RecordMetrics && GetConfigBool(section, "Metric_RD3", true));    // daily PL in money with commission

   // virtual
   metrics.enabled[METRIC_VC0] = (tradingMode!=TRADINGMODE_REGULAR && EA.RecordMetrics && GetConfigBool(section, "Metric_VC0", true));    // ...
   metrics.enabled[METRIC_VC1] = (tradingMode!=TRADINGMODE_REGULAR && EA.RecordMetrics && GetConfigBool(section, "Metric_VC1", true));    //
   metrics.enabled[METRIC_VC2] = (tradingMode!=TRADINGMODE_REGULAR && EA.RecordMetrics && GetConfigBool(section, "Metric_VC2", true));    //
   metrics.enabled[METRIC_VC3] = (tradingMode!=TRADINGMODE_REGULAR && EA.RecordMetrics && GetConfigBool(section, "Metric_VC3", true));    //
   metrics.enabled[METRIC_VD0] = (tradingMode!=TRADINGMODE_REGULAR && EA.RecordMetrics && GetConfigBool(section, "Metric_VD0", true));    //
   metrics.enabled[METRIC_VD1] = (tradingMode!=TRADINGMODE_REGULAR && EA.RecordMetrics && GetConfigBool(section, "Metric_VD1", true));    //
   metrics.enabled[METRIC_VD2] = (tradingMode!=TRADINGMODE_REGULAR && EA.RecordMetrics && GetConfigBool(section, "Metric_VD2", true));    //
   metrics.enabled[METRIC_VD3] = (tradingMode!=TRADINGMODE_REGULAR && EA.RecordMetrics && GetConfigBool(section, "Metric_VD3", true));    //

   string symbol, description, server="XTrade-Testresults";
   int digits, format=400;

   if (!metrics.hSet[METRIC_RC0]) {
      if (metrics.enabled[METRIC_RC0]) {
         symbol      = "XMT"+ sequence.id +"_RC0";
         description = ProgramName() +"."+ sequence.id +" real cumulative PL in pip w/o commission";
         digits      = 1;
         metrics.hSet[METRIC_RC0] = HistorySet1.Get(symbol, server);
         if (metrics.hSet[METRIC_RC0] == -1) metrics.hSet[METRIC_RC0] = HistorySet1.Create(symbol, description, digits, format, server);
         if (!metrics.hSet[METRIC_RC0]) return(false);
      }
   }
   else if (!metrics.enabled[METRIC_RC0]) {
      if (!HistorySet1.Close(metrics.hSet[METRIC_RC0])) return(false);
      metrics.hSet[METRIC_RC0] = NULL;
   }
   if (!metrics.hSet[METRIC_RC1]) {
      if (metrics.enabled[METRIC_RC1]) {
         symbol      = "XMT"+ sequence.id +"_RC1";
         description = ProgramName() +"."+ sequence.id +" real cumulative PL in pip with commission";
         digits      = 1;
         metrics.hSet[METRIC_RC1] = HistorySet1.Get(symbol, server);
         if (metrics.hSet[METRIC_RC1] == -1) metrics.hSet[METRIC_RC1] = HistorySet1.Create(symbol, description, digits, format, server);
         if (!metrics.hSet[METRIC_RC1]) return(false);
      }
   }
   else if (!metrics.enabled[METRIC_RC1]) {
      if (!HistorySet1.Close(metrics.hSet[METRIC_RC1])) return(false);
      metrics.hSet[METRIC_RC1] = NULL;
   }
   if (!metrics.hSet[METRIC_RC2]) {
      if (metrics.enabled[METRIC_RC2]) {
         symbol      = "XMT"+ sequence.id +"_RC2";
         description = ProgramName() +"."+ sequence.id +" real cumulative PL in "+ AccountCurrency() +" w/o commission";
         digits      = 2;
         metrics.hSet[METRIC_RC2] = HistorySet1.Get(symbol, server);
         if (metrics.hSet[METRIC_RC2] == -1) metrics.hSet[METRIC_RC2] = HistorySet1.Create(symbol, description, digits, format, server);
         if (!metrics.hSet[METRIC_RC2]) return(false);
      }
   }
   else if (!metrics.enabled[METRIC_RC2]) {
      if (!HistorySet1.Close(metrics.hSet[METRIC_RC2])) return(false);
      metrics.hSet[METRIC_RC2] = NULL;
   }
   if (!metrics.hSet[METRIC_RC3]) {
      if (metrics.enabled[METRIC_RC3]) {
         symbol      = "XMT"+ sequence.id +"_RC3";
         description = ProgramName() +"."+ sequence.id +" real cumulative PL in "+ AccountCurrency() +" with commission";
         digits      = 2;
         metrics.hSet[METRIC_RC3] = HistorySet1.Get(symbol, server);
         if (metrics.hSet[METRIC_RC3] == -1) metrics.hSet[METRIC_RC3] = HistorySet1.Create(symbol, description, digits, format, server);
         if (!metrics.hSet[METRIC_RC3]) return(false);
      }
   }
   else if (!metrics.enabled[METRIC_RC3]) {
      if (!HistorySet1.Close(metrics.hSet[METRIC_RC3])) return(false);
      metrics.hSet[METRIC_RC3] = NULL;
   }
   if (!metrics.hSet[METRIC_RD0]) {
      if (metrics.enabled[METRIC_RD0]) {
         symbol      = "XMT"+ sequence.id +"_RD0";
         description = ProgramName() +"."+ sequence.id +" real daily PL in pip w/o commission";
         digits      = 1;
         metrics.hSet[METRIC_RD0] = HistorySet1.Get(symbol, server);
         if (metrics.hSet[METRIC_RD0] == -1) metrics.hSet[METRIC_RD0] = HistorySet1.Create(symbol, description, digits, format, server);
         if (!metrics.hSet[METRIC_RD0]) return(false);
      }
   }
   else if (!metrics.enabled[METRIC_RD0]) {
      if (!HistorySet1.Close(metrics.hSet[METRIC_RD0])) return(false);
      metrics.hSet[METRIC_RD0] = NULL;
   }
   if (!metrics.hSet[METRIC_RD1]) {
      if (metrics.enabled[METRIC_RD1]) {
         symbol      = "XMT"+ sequence.id +"_RD1";
         description = ProgramName() +"."+ sequence.id +" real daily PL in pip with commission";
         digits      = 1;
         metrics.hSet[METRIC_RD1] = HistorySet1.Get(symbol, server);
         if (metrics.hSet[METRIC_RD1] == -1) metrics.hSet[METRIC_RD1] = HistorySet1.Create(symbol, description, digits, format, server);
         if (!metrics.hSet[METRIC_RD1]) return(false);
      }
   }
   else if (!metrics.enabled[METRIC_RD1]) {
      if (!HistorySet1.Close(metrics.hSet[METRIC_RD1])) return(false);
      metrics.hSet[METRIC_RD1] = NULL;
   }
   if (!metrics.hSet[METRIC_RD2]) {
      if (metrics.enabled[METRIC_RD2]) {
         symbol      = "XMT"+ sequence.id +"_RD2";
         description = ProgramName() +"."+ sequence.id +" real daily PL in "+ AccountCurrency() +" w/o commission";
         digits      = 2;
         metrics.hSet[METRIC_RD2] = HistorySet2.Get(symbol, server);
         if (metrics.hSet[METRIC_RD2] == -1) metrics.hSet[METRIC_RD2] = HistorySet2.Create(symbol, description, digits, format, server);
         if (!metrics.hSet[METRIC_RD2]) return(false);
      }
   }
   else if (!metrics.enabled[METRIC_RD2]) {
      if (!HistorySet2.Close(metrics.hSet[METRIC_RD2])) return(false);
      metrics.hSet[METRIC_RD2] = NULL;
   }
   if (!metrics.hSet[METRIC_RD3]) {
      if (metrics.enabled[METRIC_RD3]) {
         symbol      = "XMT"+ sequence.id +"_RD3";
         description = ProgramName() +"."+ sequence.id +" real daily PL in "+ AccountCurrency() +" with commission";
         digits      = 2;
         metrics.hSet[METRIC_RD3] = HistorySet2.Get(symbol, server);
         if (metrics.hSet[METRIC_RD3] == -1) metrics.hSet[METRIC_RD3] = HistorySet2.Create(symbol, description, digits, format, server);
         if (!metrics.hSet[METRIC_RD3]) return(false);
      }
   }
   else if (!metrics.enabled[METRIC_RD3]) {
      if (!HistorySet2.Close(metrics.hSet[METRIC_RD3])) return(false);
      metrics.hSet[METRIC_RD3] = NULL;
   }

   if (!metrics.hSet[METRIC_VC0]) {
      if (metrics.enabled[METRIC_VC0]) {
         symbol      = "XMT"+ sequence.id +"_VC0";
         description = ProgramName() +"."+ sequence.id +" virt. cumulative PL in pip w/o commission";
         digits      = 1;
         metrics.hSet[METRIC_VC0] = HistorySet2.Get(symbol, server);
         if (metrics.hSet[METRIC_VC0] == -1) metrics.hSet[METRIC_VC0] = HistorySet2.Create(symbol, description, digits, format, server);
         if (!metrics.hSet[METRIC_VC0]) return(false);
      }
   }
   else if (!metrics.enabled[METRIC_VC0]) {
      if (!HistorySet2.Close(metrics.hSet[METRIC_VC0])) return(false);
      metrics.hSet[METRIC_VC0] = NULL;
   }
   if (!metrics.hSet[METRIC_VC1]) {
      if (metrics.enabled[METRIC_VC1]) {
         symbol      = "XMT"+ sequence.id +"_VC1";
         description = ProgramName() +"."+ sequence.id +" virt. cumulative PL in pip with commission";
         digits      = 1;
         metrics.hSet[METRIC_VC1] = HistorySet2.Get(symbol, server);
         if (metrics.hSet[METRIC_VC1] == -1) metrics.hSet[METRIC_VC1] = HistorySet2.Create(symbol, description, digits, format, server);
         if (!metrics.hSet[METRIC_VC1]) return(false);
      }
   }
   else if (!metrics.enabled[METRIC_VC1]) {
      if (!HistorySet2.Close(metrics.hSet[METRIC_VC1])) return(false);
      metrics.hSet[METRIC_VC1] = NULL;
   }
   if (!metrics.hSet[METRIC_VC2]) {
      if (metrics.enabled[METRIC_VC2]) {
         symbol      = "XMT"+ sequence.id +"_VC2";
         description = ProgramName() +"."+ sequence.id +" virt. cumulative PL in "+ AccountCurrency() +" w/o commission";
         digits      = 2;
         metrics.hSet[METRIC_VC2] = HistorySet2.Get(symbol, server);
         if (metrics.hSet[METRIC_VC2] == -1) metrics.hSet[METRIC_VC2] = HistorySet2.Create(symbol, description, digits, format, server);
         if (!metrics.hSet[METRIC_VC2]) return(false);
      }
   }
   else if (!metrics.enabled[METRIC_VC2]) {
      if (!HistorySet2.Close(metrics.hSet[METRIC_VC2])) return(false);
      metrics.hSet[METRIC_VC2] = NULL;
   }
   if (!metrics.hSet[METRIC_VC3]) {
      if (metrics.enabled[METRIC_VC3]) {
         symbol      = "XMT"+ sequence.id +"_VC3";
         description = ProgramName() +"."+ sequence.id +" virt. cumulative PL in "+ AccountCurrency() +" with commission";
         digits      = 2;
         metrics.hSet[METRIC_VC3] = HistorySet2.Get(symbol, server);
         if (metrics.hSet[METRIC_VC3] == -1) metrics.hSet[METRIC_VC3] = HistorySet2.Create(symbol, description, digits, format, server);
         if (!metrics.hSet[METRIC_VC3]) return(false);
      }
   }
   else if (!metrics.enabled[METRIC_VC3]) {
      if (!HistorySet2.Close(metrics.hSet[METRIC_VC3])) return(false);
      metrics.hSet[METRIC_VC3] = NULL;
   }
   if (!metrics.hSet[METRIC_VD0]) {
      if (metrics.enabled[METRIC_VD0]) {
         symbol      = "XMT"+ sequence.id +"_VD0";
         description = ProgramName() +"."+ sequence.id +" virt. daily PL in pip w/o commission";
         digits      = 1;
         metrics.hSet[METRIC_VD0] = HistorySet3.Get(symbol, server);
         if (metrics.hSet[METRIC_VD0] == -1) metrics.hSet[METRIC_VD0] = HistorySet3.Create(symbol, description, digits, format, server);
         if (!metrics.hSet[METRIC_VD0]) return(false);
      }
   }
   else if (!metrics.enabled[METRIC_VD0]) {
      if (!HistorySet3.Close(metrics.hSet[METRIC_VD0])) return(false);
      metrics.hSet[METRIC_VD0] = NULL;
   }
   if (!metrics.hSet[METRIC_VD1]) {
      if (metrics.enabled[METRIC_VD1]) {
         symbol      = "XMT"+ sequence.id +"_VD1";
         description = ProgramName() +"."+ sequence.id +" virt. daily PL in pip with commission";
         digits      = 1;
         metrics.hSet[METRIC_VD1] = HistorySet3.Get(symbol, server);
         if (metrics.hSet[METRIC_VD1] == -1) metrics.hSet[METRIC_VD1] = HistorySet3.Create(symbol, description, digits, format, server);
         if (!metrics.hSet[METRIC_VD1]) return(false);
      }
   }
   else if (!metrics.enabled[METRIC_VD1]) {
      if (!HistorySet3.Close(metrics.hSet[METRIC_VD1])) return(false);
      metrics.hSet[METRIC_VD1] = NULL;
   }
   if (!metrics.hSet[METRIC_VD2]) {
      if (metrics.enabled[METRIC_VD2]) {
         symbol      = "XMT"+ sequence.id +"_VD2";
         description = ProgramName() +"."+ sequence.id +" virt. daily PL in "+ AccountCurrency() +" w/o commission";
         digits      = 2;
         metrics.hSet[METRIC_VD2] = HistorySet3.Get(symbol, server);
         if (metrics.hSet[METRIC_VD2] == -1) metrics.hSet[METRIC_VD2] = HistorySet3.Create(symbol, description, digits, format, server);
         if (!metrics.hSet[METRIC_VD2]) return(false);
      }
   }
   else if (!metrics.enabled[METRIC_VD2]) {
      if (!HistorySet3.Close(metrics.hSet[METRIC_VD2])) return(false);
      metrics.hSet[METRIC_VD2] = NULL;
   }
   if (!metrics.hSet[METRIC_VD3]) {
      if (metrics.enabled[METRIC_VD3]) {
         symbol      = "XMT"+ sequence.id +"_VD3";
         description = ProgramName() +"."+ sequence.id +" virt. daily PL in "+ AccountCurrency() +" with commission";
         digits      = 2;
         metrics.hSet[METRIC_VD3] = HistorySet3.Get(symbol, server);
         if (metrics.hSet[METRIC_VD3] == -1) metrics.hSet[METRIC_VD3] = HistorySet3.Create(symbol, description, digits, format, server);
         if (!metrics.hSet[METRIC_VD3]) return(false);
      }
   }
   else if (!metrics.enabled[METRIC_VD3]) {
      if (!HistorySet3.Close(metrics.hSet[METRIC_VD3])) return(false);
      metrics.hSet[METRIC_VD3] = NULL;
   }

   return(!catch("InitMetrics(1)"));
}


/**
 * Record performance metrics of the sequence.
 *
 * @return bool - success status
 */
bool RecordMetrics() {
   double value;
   bool success = true;

   // real metrics
   if (metrics.enabled[METRIC_RC0] && success) {               // C0: cumulative PL in pip w/o commission
      value   = real.totalPip + metrics.vShift[METRIC_RC0];
      success = HistorySet1.AddTick(metrics.hSet[METRIC_RC0], Tick.Time, value, HST_BUFFER_TICKS);
   }
   if (metrics.enabled[METRIC_RC1] && success) {               // C1: cumulative PL in pip with commission
      value   = real.totalPipNet + metrics.vShift[METRIC_RC1];
      success = HistorySet1.AddTick(metrics.hSet[METRIC_RC1], Tick.Time, value, HST_BUFFER_TICKS);
   }
   if (metrics.enabled[METRIC_RC2] && success) {               // C2: cumulative PL in money w/o commission
      value   = real.totalPl + metrics.vShift[METRIC_RC2];
      success = HistorySet1.AddTick(metrics.hSet[METRIC_RC2], Tick.Time, value, HST_BUFFER_TICKS);
   }
   if (metrics.enabled[METRIC_RC3] && success) {               // C3: cumulative PL in money with commission
      value   = real.totalPlNet + metrics.vShift[METRIC_RC3];
      success = HistorySet1.AddTick(metrics.hSet[METRIC_RC3], Tick.Time, value, HST_BUFFER_TICKS);
   }
 //if (metrics.enabled[METRIC_RD0] && success) {               // D0: daily PL in pip w/o commission
 //   value   = AccountEquity()-AccountCredit();
 //   success = HistorySet1.AddTick(metrics.hSet[METRIC_RD0], Tick.Time, value, HST_BUFFER_TICKS);
 //}
 //if (metrics.enabled[METRIC_RD1] && success) {               // D1: daily PL in pip with commission
 //   value   = AccountEquity()-AccountCredit();
 //   success = HistorySet1.AddTick(metrics.hSet[METRIC_RD1], Tick.Time, value, HST_BUFFER_TICKS);
 //}
 //if (metrics.enabled[METRIC_RD2] && success) {               // D2: daily PL in money w/o commission
 //   value   = AccountEquity()-AccountCredit();
 //   success = HistorySet2.AddTick(metrics.hSet[METRIC_RD2], Tick.Time, value, HST_BUFFER_TICKS);
 //}
 //if (metrics.enabled[METRIC_RD3] && success) {               // D3: daily PL in money with commission
 //   value   = AccountEquity()-AccountCredit();
 //   success = HistorySet2.AddTick(metrics.hSet[METRIC_RD3], Tick.Time, value, HST_BUFFER_TICKS);
 //}

   // virtual metrics
   if (metrics.enabled[METRIC_VC0] && success) {               // C0: cumulative PL in pip w/o commission
      value   = virt.totalPip + metrics.vShift[METRIC_VC0];
      success = HistorySet2.AddTick(metrics.hSet[METRIC_VC0], Tick.Time, value, HST_BUFFER_TICKS);
   }
   if (metrics.enabled[METRIC_VC1] && success) {               // C1: cumulative PL in pip with commission
      value   = virt.totalPipNet + metrics.vShift[METRIC_VC1];
      success = HistorySet2.AddTick(metrics.hSet[METRIC_VC1], Tick.Time, value, HST_BUFFER_TICKS);
   }
   if (metrics.enabled[METRIC_VC2] && success) {               // C2: cumulative PL in money w/o commission
      value   = virt.totalPl + metrics.vShift[METRIC_VC2];
      success = HistorySet2.AddTick(metrics.hSet[METRIC_VC2], Tick.Time, value, HST_BUFFER_TICKS);
   }
   if (metrics.enabled[METRIC_VC3] && success) {               // C3: cumulative PL in money with commission
      value   = virt.totalPlNet + metrics.vShift[METRIC_VC3];
      success = HistorySet2.AddTick(metrics.hSet[METRIC_VC3], Tick.Time, value, HST_BUFFER_TICKS);
   }
 //if (metrics.enabled[METRIC_VD0] && success) {               // D0: daily PL in pip w/o commission
 //   value   = AccountEquity()-AccountCredit();
 //   success = HistorySet3.AddTick(metrics.hSet[METRIC_VD0], Tick.Time, value, HST_BUFFER_TICKS);
 //}
 //if (metrics.enabled[METRIC_VD1] && success) {               // D1: daily PL in pip with commission
 //   value   = AccountEquity()-AccountCredit();
 //   success = HistorySet3.AddTick(metrics.hSet[METRIC_VD1], Tick.Time, value, HST_BUFFER_TICKS);
 //}
 //if (metrics.enabled[METRIC_VD2] && success) {               // D2: daily PL in money w/o commission
 //   value   = AccountEquity()-AccountCredit();
 //   success = HistorySet3.AddTick(metrics.hSet[METRIC_VD2], Tick.Time, value, HST_BUFFER_TICKS);
 //}
 //if (metrics.enabled[METRIC_VD3] && success) {               // D3: daily PL in money with commission
 //   value   = AccountEquity()-AccountCredit();
 //   success = HistorySet3.AddTick(metrics.hSet[METRIC_VD3], Tick.Time, value, HST_BUFFER_TICKS);
 //}
   return(success);
}


/**
 * Start the virtual trade copier.
 *
 * @return bool - success status
 */
bool StartTradeCopier() {
   if (IsLastError()) return(false);

   if (tradingMode == TRADINGMODE_VIRTUAL_MIRROR) {
      if (!CloseOpenOrders()) return(false);
      tradingMode = TRADINGMODE_VIRTUAL;
   }

   if (tradingMode == TRADINGMODE_VIRTUAL) {
      tradingMode = TRADINGMODE_VIRTUAL_COPIER;
      real.isSynchronized = false;
      return(!catch("StartTradeCopier(1)"));
   }

   return(!catch("StartTradeCopier(2)  "+ sequence.name +" cannot start trade copier in "+ TradingModeToStr(tradingMode), ERR_ILLEGAL_STATE));
}


/**
 * Start the virtual trade mirror.
 *
 * @return bool - success status
 */
bool StartTradeMirror() {
   if (IsLastError()) return(false);

   if (tradingMode == TRADINGMODE_VIRTUAL_COPIER) {
      if (!CloseOpenOrders()) return(false);
      tradingMode = TRADINGMODE_VIRTUAL;
   }

   if (tradingMode == TRADINGMODE_VIRTUAL) {
      tradingMode = TRADINGMODE_VIRTUAL_MIRROR;
      real.isSynchronized = false;
      return(!catch("StartTradeMirror(1)"));
   }

   return(!catch("StartTradeMirror(2)  "+ sequence.name +" cannot start trade mirror in "+ TradingModeToStr(tradingMode), ERR_ILLEGAL_STATE));
}


/**
 * Stop a running virtual trade copier/mirror.
 *
 * @return bool - success status
 */
bool StopVirtualTrading() {
   if (IsLastError()) return(false);

   if (tradingMode==TRADINGMODE_VIRTUAL_COPIER || tradingMode==TRADINGMODE_VIRTUAL_MIRROR) {
      if (!CloseOpenOrders()) return(false);
      tradingMode = TRADINGMODE_VIRTUAL;
      return(!catch("StopVirtualTrading(1)"));
   }

   return(!catch("StopVirtualTrading(2)  "+ sequence.name +" cannot stop virtual trading in "+ TradingModeToStr(tradingMode), ERR_ILLEGAL_STATE));
}


/**
 * Add a real order record to the order log and update statistics.
 *
 * @param  int      ticket
 * @param  int      linkedTicket
 * @param  double   lots
 * @param  int      type
 * @param  datetime openTime
 * @param  double   openPrice
 * @param  datetime closeTime
 * @param  double   closePrice
 * @param  double   stopLoss
 * @param  double   takeProfit
 * @param  double   swap
 * @param  double   commission
 * @param  double   profit
 *
 * @return bool - success status
 */
bool Orders.AddRealTicket(int ticket, int linkedTicket, double lots, int type, datetime openTime, double openPrice, datetime closeTime, double closePrice, double stopLoss, double takeProfit, double swap, double commission, double profit) {
   int pos = SearchIntArray(real.ticket, ticket);
   if (pos >= 0) return(!catch("Orders.AddRealTicket(1)  "+ sequence.name +" invalid parameter ticket: #"+ ticket +" (exists)", ERR_INVALID_PARAMETER));

   int pendingType, openType;
   double pendingPrice;

   if (IsPendingOrderType(type)) {
      pendingType  = type;
      pendingPrice = openPrice;
      openType     = OP_UNDEFINED;
      openTime     = NULL;
      openPrice    = NULL;
   }
   else {
      pendingType  = OP_UNDEFINED;
      pendingPrice = NULL;
      openType     = type;
   }

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
   ArrayResize(real.swap,         newSize); real.swap        [i] = swap;
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
      real.openLots       += ifDouble(IsLongOrderType(type), lots, -lots);
      real.openSwap       += swap;
      real.openCommission += commission;
      real.openPl         += profit;
      real.openPlNet       = real.openSwap + real.openCommission + real.openPl;
      real.openPip        += ifDouble(IsLongOrderType(type), Bid-real.openPrice[i], real.openPrice[i]-Ask)/Pip;
    //real.openPipNet      = ...
   }
   if (isClosedPosition) {
      real.closedPositions++;
      real.closedLots       += lots;
      real.closedSwap       += swap;
      real.closedCommission += commission;
      real.closedPl         += profit;
      real.closedPlNet       = real.closedSwap + real.closedCommission + real.closedPl;
      real.closedPip        += ifDouble(IsLongOrderType(type), real.closePrice[i]-real.openPrice[i], real.openPrice[i]-real.closePrice[i])/Pip;
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
 * @param  _In_    int      type
 * @param  _In_    datetime openTime
 * @param  _In_    double   openPrice
 * @param  _In_    datetime closeTime
 * @param  _In_    double   closePrice
 * @param  _In_    double   stopLoss
 * @param  _In_    double   takeProfit
 * @param  _In_    double   swap
 * @param  _In_    double   commission
 * @param  _In_    double   profit
 *
 * @return bool - success status
 */
bool Orders.AddVirtualTicket(int &ticket, int linkedTicket, double lots, int type, datetime openTime, double openPrice, datetime closeTime, double closePrice, double stopLoss, double takeProfit, double swap, double commission, double profit) {
   int pos = SearchIntArray(virt.ticket, ticket);
   if (pos >= 0) return(!catch("Orders.AddVirtualTicket(1)  "+ sequence.name +" invalid parameter ticket: #"+ ticket +" (exists)", ERR_INVALID_PARAMETER));

   int pendingType, openType;
   double pendingPrice;

   if (IsPendingOrderType(type)) {
      pendingType  = type;
      pendingPrice = openPrice;
      openType     = OP_UNDEFINED;
      openTime     = NULL;
      openPrice    = NULL;
   }
   else {
      pendingType  = OP_UNDEFINED;
      pendingPrice = NULL;
      openType     = type;
   }

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
   ArrayResize(virt.swap,         newSize); virt.swap        [i] = swap;
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
      virt.openLots       += ifDouble(IsLongOrderType(type), lots, -lots);
      virt.openSwap       += swap;
      virt.openCommission += commission;
      virt.openPl         += profit;
      virt.openPlNet       = virt.openSwap + virt.openCommission + virt.openPl;
      virt.openPip        += ifDouble(IsLongOrderType(type), Bid-virt.openPrice[i], virt.openPrice[i]-Ask)/Pip;
    //virt.openPipNet      = ...
   }
   if (isClosedPosition) {
      virt.closedPositions++;
      virt.closedLots       += lots;
      virt.closedSwap       += swap;
      virt.closedCommission += commission;
      virt.closedPl         += profit;
      virt.closedPlNet       = virt.closedSwap + virt.closedCommission + virt.closedPl;
      virt.closedPip        += ifDouble(IsLongOrderType(type), virt.closePrice[i]-virt.openPrice[i], virt.openPrice[i]-virt.closePrice[i])/Pip;
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

   real.isOpenOrder = false;

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
   ArraySpliceDoubles(real.swap,         pos, 1);
   ArraySpliceDoubles(real.profit,       pos, 1);

   return(!catch("Orders.RemoveRealTicket(4)"));
}


/**
 * Whether a chart command was sent to the expert. If the case, the command is retrieved and returned.
 *
 * @param  string commands[] - array to store received commands
 *
 * @return bool
 */
bool EventListener_ChartCommand(string &commands[]) {
   if (!__isChart) return(false);

   static string label, mutex; if (!StringLen(label)) {
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
   debug("onCommand(0.1)  "+ cmd);

   // virtual
   if (cmd == "virtual") {
      switch (tradingMode) {
         case TRADINGMODE_VIRTUAL_COPIER:
         case TRADINGMODE_VIRTUAL_MIRROR:
            return(StopVirtualTrading());

         default: logWarn("onCommand(2)  "+ sequence.name +" cannot execute "+ DoubleQuoteStr(cmd) +" command in "+ TradingModeToStr(tradingMode));
      }
      return(true);
   }

   // virtual-copier
   if (cmd == "virtual-copier") {
      switch (tradingMode) {
         case TRADINGMODE_VIRTUAL:
         case TRADINGMODE_VIRTUAL_MIRROR:
            return(StartTradeCopier());

         default: logWarn("onCommand(3)  "+ sequence.name +" cannot execute "+ DoubleQuoteStr(cmd) +" command in "+ TradingModeToStr(tradingMode));
      }
      return(true);
   }

   // virtual-mirror
   if (cmd == "virtual-mirror") {
      switch (tradingMode) {
         case TRADINGMODE_VIRTUAL:
         case TRADINGMODE_VIRTUAL_COPIER:
            return(StartTradeMirror());

         default: logWarn("onCommand(4)  "+ sequence.name +" cannot execute "+ DoubleQuoteStr(cmd) +" command in "+ TradingModeToStr(tradingMode));
      }
      return(true);
   }

   return(!logWarn("onCommand(5)  "+ sequence.name +" unsupported command: "+ DoubleQuoteStr(cmd)));
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
      magicNumber = GenerateMagicNumber(sequenceId); if (!magicNumber) return(NULL);

      // test for uniqueness against open orders
      int openOrders = OrdersTotal();
      for (int i=0; i < openOrders; i++) {
         if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) return(!catch("CreateSequenceId(1)  "+ sequence.name, ifIntOr(GetLastError(), ERR_RUNTIME_ERROR)));
         if (OrderMagicNumber() == magicNumber) {
            magicNumber = NULL;
            break;
         }
      }
      if (!magicNumber) continue;

      // test for uniqueness against closed orders
      int closedOrders = OrdersHistoryTotal();
      for (i=0; i < closedOrders; i++) {
         if (!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) return(!catch("CreateSequenceId(2)  "+ sequence.name, ifIntOr(GetLastError(), ERR_RUNTIME_ERROR)));
         if (OrderMagicNumber() == magicNumber) {
            magicNumber = NULL;
            break;
         }
      }
   }
   return(sequenceId);
}


/**
 * Generate a magic order number for the strategy.
 *
 * @param  int sequenceId [optional] - sequence to generate the magic number for (default: the current sequence)
 *
 * @return int - magic number or NULL in case of errors
 */
int GenerateMagicNumber(int sequenceId = NULL) {
   if (STRATEGY_ID < 101 || STRATEGY_ID > 1023) return(!catch("GenerateMagicNumber(1)  "+ sequence.name +" illegal strategy id: "+ STRATEGY_ID, ERR_ILLEGAL_STATE));
   int id = ifIntOr(sequenceId, sequence.id);
   if (id < 1000 || id > 9999)                  return(!catch("GenerateMagicNumber(2)  "+ sequence.name +" illegal sequence id: "+ id, ERR_ILLEGAL_STATE));

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
   return(StrLeft(name, -3) +"log");
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
   string sSwap         = DoubleToStr(virt.swap[i], 2);
   string sProfit       = DoubleToStr(virt.profit[i], 2);

   return("virtual #"+ ticket +": lots="+ sLots +", pendingType="+ sPendingType +", pendingPrice="+ sPendingPrice +", openType="+ sOpenType +", openTime="+ sOpenTime +", openPrice="+ sOpenPrice +", closeTime="+ sCloseTime +", closePrice="+ sClosePrice +", takeProfit="+ sTakeProfit +", stopLoss="+ sStopLoss +", commission="+ sCommission +", swap="+ sSwap +", profit="+ sProfit);
}


/**
 * Return a readable version of a trading mode.
 *
 * @param  int mode
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
 * Write the current sequence status to the status file.
 *
 * @return bool - success status
 */
bool SaveStatus() {
   if (last_error != 0) return(false);
   if (!sequence.id)    return(!catch("SaveStatus(1)  "+ sequence.name +" illegal value of sequence.id: "+ sequence.id, ERR_ILLEGAL_STATE));

   // In tester skip updating the status file except at the first call and at test end.
   if (IsTesting() && test.reduceStatusWrites) {
      static bool saved = false;
      if (saved && __CoreFunction!=CF_DEINIT) return(true);
      saved = true;
   }

   string section, file=GetStatusFilename();

   section = "General";
   WriteIniString(file, section, "Account", GetAccountCompany() +":"+ GetAccountNumber());
   WriteIniString(file, section, "Symbol",  Symbol());

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

   WriteIniString(file, section, "MoneyManagement",          MoneyManagement);
   WriteIniString(file, section, "Risk",                     NumberToStr(Risk, ".1+"));
   WriteIniString(file, section, "ManualLotsize",            NumberToStr(ManualLotsize, ".1+"));

   WriteIniString(file, section, "TakeProfit",               DoubleToStr(TakeProfit, 1));
   WriteIniString(file, section, "StopLoss",                 DoubleToStr(StopLoss, 1));
   WriteIniString(file, section, "TrailEntryStep",           DoubleToStr(TrailEntryStep, 1));
   WriteIniString(file, section, "TrailExitStart",           DoubleToStr(TrailExitStart, 1));
   WriteIniString(file, section, "TrailExitStep",            DoubleToStr(TrailExitStep, 1));
   WriteIniString(file, section, "MagicNumber",              MagicNumber);
   WriteIniString(file, section, "MaxSlippage",              DoubleToStr(MaxSlippage, 1));

   WriteIniString(file, section, "EA.StopOnProfit",          DoubleToStr(EA.StopOnProfit, 2));
   WriteIniString(file, section, "EA.StopOnLoss",            DoubleToStr(EA.StopOnLoss, 2));
   WriteIniString(file, section, "EA.RecordMetrics",         EA.RecordMetrics);

   WriteIniString(file, section, "ChannelBug",               ChannelBug);
   WriteIniString(file, section, "TakeProfitBug",            TakeProfitBug);

   section = "Runtime status";
   // On deletion of pending orders the number of order records to store decreases. To prevent orphaned order records in the
   // file the section is emptied before writing to it.
   EmptyIniSectionA(file, section);

   int size = ArraySize(real.ticket);
   for (int i=0; i < size; i++) {
      WriteIniString(file, section, "real.order."+ StrPadLeft(i, 4, "0"), SaveStatus.OrderToStr(i, TRADINGMODE_REGULAR));
   }
   size = ArraySize(virt.ticket);
   for (i=0; i < size; i++) {
      WriteIniString(file, section, "virt.order."+ StrPadLeft(i, 4, "0"), SaveStatus.OrderToStr(i, TRADINGMODE_VIRTUAL));
   }

   return(!catch("SaveStatus(2)"));
}


/**
 * Return a string representation of an order record as stored by SaveStatus().
 *
 * @param  int index - index of the order record
 * @param  int mode  - one of MODE_REAL or MODE_VIRTUAL
 *
 * @return string - string representation or an empty string in case of errors
 */
string SaveStatus.OrderToStr(int index, int mode) {
   /*
   real.order.i=ticket,linkedTicket,lots,pendingType,pendingPrice,openType,openTime,openPrice,closeTime,closePrice,stopLoss,takeProfit,commission,swap,profit
   */
   if (mode == TRADINGMODE_REGULAR) {
      int      ticket       = real.ticket      [index];
      int      linkedTicket = real.linkedTicket[index];
      double   lots         = real.lots        [index];
      int      pendingType  = real.pendingType [index];
      double   pendingPrice = real.pendingPrice[index];
      int      openType     = real.openType    [index];
      datetime openTime     = real.openTime    [index];
      double   openPrice    = real.openPrice   [index];
      datetime closeTime    = real.closeTime   [index];
      double   closePrice   = real.closePrice  [index];
      double   stopLoss     = real.stopLoss    [index];
      double   takeProfit   = real.takeProfit  [index];
      double   commission   = real.commission  [index];
      double   swap         = real.swap        [index];
      double   profit       = real.profit      [index];
   }
   else if (mode == TRADINGMODE_VIRTUAL) {
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
               swap         = virt.swap        [index];
               profit       = virt.profit      [index];
   }
   else return(_EMPTY_STR(catch("SaveStatus.OrderToStr(1)  "+ sequence.name +" invalid parameter mode: "+ mode, ERR_INVALID_PARAMETER)));

   return(StringConcatenate(ticket, ",", linkedTicket, ",", DoubleToStr(lots, 2), ",", pendingType, ",", DoubleToStr(pendingPrice, Digits), ",", openType, ",", openTime, ",", DoubleToStr(openPrice, Digits), ",", closeTime, ",", DoubleToStr(closePrice, Digits), ",", DoubleToStr(stopLoss, Digits), ",", DoubleToStr(takeProfit, Digits), ",", DoubleToStr(commission, 2), ",", DoubleToStr(swap, 2), ",", DoubleToStr(profit, 2)));
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

   string realStats="", virtStats="", copierStats="", mirrorStats="", sError="";
   if      (__STATUS_INVALID_INPUT) sError = StringConcatenate(" [",                 ErrorDescription(ERR_INVALID_INPUT_PARAMETER), "]");
   else if (__STATUS_OFF          ) sError = StringConcatenate(" [switched off => ", ErrorDescription(__STATUS_OFF.reason),         "]");

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
                                    "Closed:     ", real.closedPositions, " trades    ", NumberToStr(real.closedLots, ".+"), " lot    PL: ", DoubleToStr(real.closedPl, 2), "    Commission: ", DoubleToStr(real.closedCommission, 2), "    Swap: ", DoubleToStr(real.closedSwap, 2), NL,
                                    "Total PL:   ", DoubleToStr(real.totalPlNet, 2),                                                                            NL);
   }
   if (tradingMode != TRADINGMODE_REGULAR) {
      virtStats = StringConcatenate("Open:       ", NumberToStr(virt.openLots, "+.+"),   " lot                           PL: ", DoubleToStr(virt.openPlNet, 2), NL,
                                    "Closed:     ", virt.closedPositions, " trades    ", NumberToStr(virt.closedLots, ".+"), " lot    PL: ", DoubleToStr(virt.closedPl, 2), "    Commission: ", DoubleToStr(virt.closedCommission, 2), "    Swap: ", DoubleToStr(virt.closedSwap, 2), NL,
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

   // store status in chart to enable remote control by scripts
   string label = "XMT-Scalper.status";
   if (ObjectFind(label) != 0) {
      ObjectCreate(label, OBJ_LABEL, 0, 0, 0);
      ObjectSet(label, OBJPROP_TIMEFRAMES, OBJ_PERIODS_NONE);
   }
   ObjectSetText(label, StringConcatenate(sequence.id, "|", TradingMode));

   if (!catch("ShowStatus(1)"))
      return(error);
   return(last_error);
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
      case TRADINGMODE_REGULAR       : sequence.name = "R";  break;
      case TRADINGMODE_VIRTUAL       : sequence.name = "V";  break;
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


/**
 * Return a string representation of the input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return("Sequence.ID="             + DoubleQuoteStr(Sequence.ID)                  +";"+ NL
         +"TradingMode="             + TradingMode                                  +";"+ NL

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

         +"MoneyManagement="         + BoolToStr(MoneyManagement)                   +";"+ NL
         +"Risk="                    + NumberToStr(Risk, ".1+")                     +";"+ NL
         +"ManualLotsize="           + NumberToStr(ManualLotsize, ".1+")            +";"+ NL

         +"TakeProfit="              + DoubleToStr(TakeProfit, 1)                   +";"+ NL
         +"StopLoss="                + DoubleToStr(StopLoss, 1)                     +";"+ NL
         +"TrailEntryStep="          + DoubleToStr(TrailEntryStep, 1)               +";"+ NL
         +"TrailExitStart="          + DoubleToStr(TrailExitStart, 1)               +";"+ NL
         +"TrailExitStep="           + DoubleToStr(TrailExitStep, 1)                +";"+ NL
         +"MagicNumber="             + MagicNumber                                  +";"+ NL
         +"MaxSlippage="             + DoubleToStr(MaxSlippage, 1)                  +";"+ NL

         +"EA.StopOnProfit="         + DoubleToStr(EA.StopOnProfit, 2)              +";"+ NL
         +"EA.StopOnLoss="           + DoubleToStr(EA.StopOnLoss, 2)                +";"+ NL
         +"EA.RecordMetrics="        + BoolToStr(EA.RecordMetrics)                  +";"+ NL

         +"ChannelBug="              + BoolToStr(ChannelBug)                        +";"+ NL
         +"TakeProfitBug="           + BoolToStr(TakeProfitBug)                     +";"
   );

   // prevent compiler warnings
   DumpVirtualOrder(NULL);
}
