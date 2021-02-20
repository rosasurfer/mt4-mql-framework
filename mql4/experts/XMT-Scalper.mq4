/**
 * XMT-Scalper revisited
 *
 *
 * This EA is originally based on the famous "MillionDollarPips EA". The core idea of the strategy is scalping based on a
 * reversal from a channel breakout. Over the years it has gone through multiple transformations. Today various versions with
 * different names circulate in the internet (MDP-Plus, XMT-Scalper, Assar). None of them can be used for real trading, mainly
 * due to lack of signal documentation and a significant amount of issues in the program logic.
 *
 * This version is a complete rewrite.
 *
 * Sources:
 *  @link  https://github.com/rosasurfer/mt4-mql/blob/a1b22d0/mql4/experts/mdp#             [MillionDollarPips v2 decompiled]
 *  @link  https://github.com/rosasurfer/mt4-mql/blob/36f494e/mql4/experts/mdp#                    [MDP-Plus v2.2 by Capella]
 *  @link  https://github.com/rosasurfer/mt4-mql/blob/41237e0/mql4/experts/mdp#               [XMT-Scalper v2.522 by Capella]
 *
 *
 * Changes:
 *  - removed MQL5 syntax and fixed compiler issues
 *  - added rosasurfer framework and the framework's test reporting
 *  - moved print output to the framework logger
 *  - added monitoring of PositionOpen and PositionClose events
 *  - removed obsolete functions and variables
 *  - removed obsolete order expiration, NDD and screenshot functionality
 *  - removed obsolete sending of fake orders and measuring of execution times
 *  - removed broken commission calculations
 *  - internal order management (huge speed improvement)
 *  - fixed input parameter validation
 *  - fixed position size calculation
 *  - fixed trade management issues
 *  - fixed signal detection and added new input parameter ChannelBug (for comparison)
 *  - fixed TakeProfit calculation and added new input parameter TakeProfitBug (for comparison)
 *  - rewrote status display
 *  - simplified input parameters
 *  - renamed input parameter Timeframe                 => IndicatorTimeframe
 *  - renamed input parameter UseDynamicVolatilityLimit => UseSpreadMultiplier
 *  - renamed input parameter VolatilityMultiplier      => SpreadMultiplier
 *  - renamed input parameter VolatilityLimit           => MinBarSize
 *  - renamed input parameter MinimumUseStopLevel       => BreakoutReversal
 *  - renamed input parameter ReverseTrades             => ReverseSignals
 *  - renamed input parameter TrailingStart             => TrailingStep
 */
#include <stddefines.mqh>
int   __InitFlags[] = {INIT_TIMEZONE, INIT_PIPVALUE, INIT_BUFFERED_LOG};
int __DeinitFlags[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern string ___a___________________________ = "=== Entry indicator: 1=MovingAverage, 2=BollingerBands, 3=Envelopes ===";
extern int    EntryIndicator                  = 1;          // entry signal indicator for price channel calculation
extern int    IndicatorTimeFrame              = PERIOD_M1;  // entry indicator timeframe
extern int    IndicatorPeriods                = 3;          // entry indicator bar periods
extern double BollingerBands.Deviation        = 2;          // standard deviations
extern double Envelopes.Deviation             = 0.07;       // in percent

extern string ___b___________________________ = "=== Entry bar size conditions ================";
extern bool   UseSpreadMultiplier             = true;       // use spread multiplier or fix min. bar size
extern double SpreadMultiplier                = 12.5;       // min. bar size = SpreadMultiplier * avgSpread
extern double MinBarSize                      = 18;         // min. bar size in {pip}
extern double MaxSpread                       = 3;          // max. acceptable spread in {pip}

extern string ___c___________________________ = "=== Trade settings ========================";
extern double BreakoutReversal                = 0;          // required reversal in {pip} (0: counter-trend trading w/o reversal)
extern double TakeProfit                      = 10;         // TP in {pip}
extern double StopLoss                        = 6;          // SL in {pip}
extern double TrailingStart                   = 0;          // start trailing after {pip} in profit
extern double TrailingStep                    = 2;          // trail limits every {pip} in profit
extern double Slippage                        = 0.3;        // acceptable order slippage in {pip}
extern int    Magic                           = 0;          // if zero the MagicNumber is generated
extern bool   ReverseSignals                  = false;      // Buy => Sell, Sell => Buy

extern string ___d___________________________ = "=== MoneyManagement ====================";
extern bool   MoneyManagement                 = true;       // if TRUE lots are calculated dynamically, if FALSE "ManualLotsize" is used
extern double Risk                            = 2;          // percent of equity to risk with each trade
extern double ManualLotsize                   = 0.01;       // fix position size used if "MoneyManagement" is FALSE

extern string ___e___________________________ = "=== Bugs =============================";
extern bool   ChannelBug                      = false;      // enable erroneous calculation of the breakout channel (for comparison)
extern bool   TakeProfitBug                   = true;       // enable erroneous calculation of TakeProfit targets (for comparison)

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/expert.mqh>
#include <stdfunctions.mqh>
#include <rsfLibs.mqh>
#include <functions/JoinStrings.mqh>
#include <structs/rsf/OrderExecution.mqh>

#define SIGNAL_LONG     1
#define SIGNAL_SHORT    2


// order log
int      orders.ticket      [];
double   orders.lots        [];        // order volume > 0
int      orders.pendingType [];        // pending order type if applicable or OP_UNDEFINED (-1)
double   orders.pendingPrice[];        // pending entry limit if applicable or 0
int      orders.openType    [];        // order open type of an opened position or OP_UNDEFINED (-1)
datetime orders.openTime    [];        // order open time of an opened position or 0
double   orders.openPrice   [];        // order open price of an opened position or 0
datetime orders.closeTime   [];        // order close time of a closed order or 0
double   orders.closePrice  [];        // order close price of a closed position or 0
double   orders.stopLoss    [];        // SL price or 0
double   orders.takeProfit  [];        // TP price or 0
double   orders.swap        [];        // order swap
double   orders.commission  [];        // order commission
double   orders.profit      [];        // order profit (gross)

// order statistics
int      openOrders;                   // number of open orders (max. 1)
int      openPositions;                // number of open positions (max. 1)
double   openLots;                     // total open lotsize
double   openSwap;                     // total open swap
double   openCommission;               // total open commissions
double   openPl;                       // total open gross profit
double   openPlNet;                    // total open net profit

int      closedPositions;              // number of closed positions
double   closedLots;                   // total closed lotsize
double   closedSwap;                   // total closed swap
double   closedCommission;             // total closed commission
double   closedPl;                     // total closed gross profit
double   closedPlNet;                  // total closed net profit

double   totalPlNet;                   // openPlNet + closedPlNet

// other
double   currentSpread;                // current spread in pip
double   avgSpread;                    // average spread in pip
double   minBarSize;                   // min. bar size in absolute terms
int      orderSlippage;                // order slippage in point
string   orderComment = "";

// cache vars to speed-up ShowStatus()
string   sCurrentSpread  = "-";
string   sAvgSpread      = "-";
string   sMaxSpread      = "-";
string   sCurrentBarSize = "-";
string   sMinBarSize     = "-";
string   sIndicator      = "-";
string   sUnitSize       = "-";


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   // validate inputs
   // EntryIndicator
   if (EntryIndicator < 1 || EntryIndicator > 3)             return(catch("onInit(1)  invalid input parameter EntryIndicator: "+ EntryIndicator +" (must be from 1-3)", ERR_INVALID_INPUT_PARAMETER));
   // IndicatorTimeframe
   if (IsTesting() && IndicatorTimeFrame!=Period())          return(catch("onInit(2)  illegal test on "+ PeriodDescription(Period()) +" for configured EA timeframe "+ PeriodDescription(IndicatorTimeFrame), ERR_RUNTIME_ERROR));
   // BreakoutReversal
   double stopLevel = MarketInfo(Symbol(), MODE_STOPLEVEL);
   if (LT(BreakoutReversal*Pip, stopLevel*Point))            return(catch("onInit(3)  invalid input parameter BreakoutReversal: "+ NumberToStr(BreakoutReversal, ".1+") +" (must be larger than MODE_STOPLEVEL)", ERR_INVALID_INPUT_PARAMETER));
   double minLots=MarketInfo(Symbol(), MODE_MINLOT), maxLots=MarketInfo(Symbol(), MODE_MAXLOT);
   if (MoneyManagement) {
      // Risk
      if (LE(Risk, 0))                                       return(catch("onInit(4)  invalid input parameter Risk: "+ NumberToStr(Risk, ".1+") +" (must be positive)", ERR_INVALID_INPUT_PARAMETER));
      double lots = CalculateLots(false); if (IsLastError()) return(last_error);
      if (LT(lots, minLots))                                 return(catch("onInit(5)  not enough money ("+ DoubleToStr(AccountEquity()-AccountCredit(), 2) +") for input parameter Risk="+ NumberToStr(Risk, ".1+") +" (resulting position size "+ NumberToStr(lots, ".1+") +" smaller than MODE_MINLOT="+ NumberToStr(minLots, ".1+") +")", ERR_NOT_ENOUGH_MONEY));
      if (GT(lots, maxLots))                                 return(catch("onInit(6)  too large input parameter Risk: "+ NumberToStr(Risk, ".1+") +" (resulting position size "+ NumberToStr(lots, ".1+") +" larger than MODE_MAXLOT="+  NumberToStr(maxLots, ".1+") +")", ERR_INVALID_INPUT_PARAMETER));
   }
   else {
      // ManualLotsize
      if (LT(ManualLotsize, minLots))                        return(catch("onInit(7)  too small input parameter ManualLotsize: "+ NumberToStr(ManualLotsize, ".1+") +" (smaller than MODE_MINLOT="+ NumberToStr(minLots, ".1+") +")", ERR_INVALID_INPUT_PARAMETER));
      if (GT(ManualLotsize, maxLots))                        return(catch("onInit(8)  too large input parameter ManualLotsize: "+ NumberToStr(ManualLotsize, ".1+") +" (larger than MODE_MAXLOT="+ NumberToStr(maxLots, ".1+") +")", ERR_INVALID_INPUT_PARAMETER));
   }

   // initialize global vars
   if (UseSpreadMultiplier) { minBarSize = 0;              sMinBarSize = "-";                                }
   else                     { minBarSize = MinBarSize*Pip; sMinBarSize = DoubleToStr(MinBarSize, 1) +" pip"; }
   sMaxSpread    = DoubleToStr(MaxSpread, 1);
   orderSlippage = Round(Slippage*Pip/Point);
   orderComment  = "XMT"+ ifString(ChannelBug, "-ChBug", "") + ifString(TakeProfitBug, "-TpBug", "");




   // --- old ---------------------------------------------------------------------------------------------------------------
   if (!Magic) Magic = GenerateMagicNumber();

   if (!ReadOrderLog()) return(last_error);

   SS.All();
   return(catch("onInit(9)"));
}


/**
 * Deinitialization
 *
 * @return int - error status
 */
int onDeinit() {
   return(catch("onDeinit(1)"));
}


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   UpdateOrderStatus();
   Strategy();
   return(catch("onTick(1)"));
}


/**
 * Track open/closed positions and update statistics.
 *
 * @return bool - success status
 */
bool UpdateOrderStatus() {
   // open trade statistics are fully recalculated
   openPositions  = 0;
   openLots       = 0;
   openSwap       = 0;
   openCommission = 0;
   openPl         = 0;
   openPlNet      = 0;

   int orders = ArraySize(orders.ticket);

   // update ticket status
   for (int i=orders-1; i >= 0; i--) {                            // iterate backwards and stop at the first closed ticket
      if (orders.closeTime[i] > 0) break;                         // to increase performance
      if (!SelectTicket(orders.ticket[i], "UpdateOrderStatus(1)")) return(false);

      bool wasPending  = (orders.openType[i] == OP_UNDEFINED);
      bool isPending   = (OrderType() > OP_SELL);
      bool wasPosition = !wasPending;
      bool isOpen      = !OrderCloseTime();
      bool isClosed    = !isOpen;

      if (wasPending) {
         if (!isPending) {                                        // the pending order was filled
            onPositionOpen(i);
            wasPosition = true;                                   // mark as known open position
         }
         else if (isClosed) {                                     // the pending order was cancelled
            onOrderDelete(i);
            orders--;
            continue;
         }
      }

      if (wasPosition) {
         orders.swap      [i] = OrderSwap();
         orders.commission[i] = OrderCommission();
         orders.profit    [i] = OrderProfit();

         if (isOpen) {
            openPositions++;
            openLots       += ifDouble(orders.openType[i]==OP_BUY, orders.lots[i], -orders.lots[i]);
            openSwap       += orders.swap      [i];
            openCommission += orders.commission[i];
            openPl         += orders.profit    [i];
         }
         else /*isClosed*/ {                                      // the open position was closed
            onPositionClose(i);
            closedPositions++;                                    // update closed trade statistics
            closedLots       += orders.lots      [i];
            closedSwap       += orders.swap      [i];
            closedCommission += orders.commission[i];
            closedPl         += orders.profit    [i];
         }
      }
   }

   openPlNet   = openSwap + openCommission + openPl;
   closedPlNet = closedSwap + closedCommission + closedPl;
   totalPlNet  = openPlNet + closedPlNet;

   return(!catch("UpdateOrderStatus(2)"));
}


/**
 * Handle a PositionOpen event. The opened ticket is already selected.
 *
 * @param  int i - ticket index of the opened position
 *
 * @return bool - success status
 */
bool onPositionOpen(int i) {
   // update order log
   orders.openType  [i] = OrderType();
   orders.openTime  [i] = OrderOpenTime();
   orders.openPrice [i] = OrderOpenPrice();
   orders.swap      [i] = OrderSwap();
   orders.commission[i] = OrderCommission();
   orders.profit    [i] = OrderProfit();

   if (IsLogInfo()) {
      // #1 Stop Sell 0.1 GBPUSD at 1.5457'2[ "comment"] was filled[ at 1.5457'2] (market: Bid/Ask[, 0.3 pip [positive ]slippage])
      int    pendingType  = orders.pendingType [i];
      double pendingPrice = orders.pendingPrice[i];

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
      logInfo("onPositionOpen(1)  "+ message +" (market: "+ NumberToStr(Bid, PriceFormat) +"/"+ NumberToStr(Ask, PriceFormat) + sSlippage +")");
   }

   if (IsTesting() && __ExecutionContext[EC.extReporting]) {
      Test_onPositionOpen(__ExecutionContext, OrderTicket(), OrderType(), OrderLots(), OrderSymbol(), OrderOpenTime(), OrderOpenPrice(), OrderStopLoss(), OrderTakeProfit(), OrderCommission(), OrderMagicNumber(), OrderComment());
   }
   return(!catch("onPositionOpen(2)"));
}


/**
 * Handle a PositionClose event. The closed ticket is already selected.
 *
 * @param  int i - ticket index of the closed position
 *
 * @return bool - success status
 */
bool onPositionClose(int i) {
   // update order log
   orders.closeTime [i] = OrderCloseTime();
   orders.closePrice[i] = OrderClosePrice();
   orders.swap      [i] = OrderSwap();
   orders.commission[i] = OrderCommission();
   orders.profit    [i] = OrderProfit();

   if (IsLogInfo()) {
      // #1 Sell 0.1 GBPUSD at 1.5457'2[ "comment"] was closed at 1.5457'2 (market: Bid/Ask[, so: 47.7%/169.20/354.40])
      string sType       = OperationTypeDescription(OrderType());
      string sOpenPrice  = NumberToStr(OrderOpenPrice(), PriceFormat);
      string sClosePrice = NumberToStr(OrderClosePrice(), PriceFormat);
      string sComment    = ""; if (StringLen(OrderComment()) > 0) sComment = " "+ DoubleQuoteStr(OrderComment());
      string message     = "#"+ OrderTicket() +" "+ sType +" "+ NumberToStr(OrderLots(), ".+") +" "+ Symbol() +" at "+ sOpenPrice + sComment +" was closed at "+ sClosePrice;
      logInfo("onPositionClose(1)  "+ message +" (market: "+ NumberToStr(Bid, PriceFormat) +"/"+ NumberToStr(Ask, PriceFormat) +")");
   }

   if (IsTesting() && __ExecutionContext[EC.extReporting]) {
      Test_onPositionClose(__ExecutionContext, OrderTicket(), OrderCloseTime(), OrderClosePrice(), OrderSwap(), OrderProfit());
   }
   return(!catch("onPositionClose(2)"));
}


/**
 * Handle an OrderDelete event. The deleted ticket is already selected.
 *
 * @param  int i - ticket index of the deleted order
 *
 * @return bool - success status
 */
bool onOrderDelete(int i) {
   if (IsLogInfo()) {
      // #1 Stop Sell 0.1 GBPUSD at 1.5457'2[ "comment"] was deleted
      int    pendingType  = orders.pendingType [i];
      double pendingPrice = orders.pendingPrice[i];

      string sType         = OperationTypeDescription(pendingType);
      string sPendingPrice = NumberToStr(pendingPrice, PriceFormat);
      string sComment      = ""; if (StringLen(OrderComment()) > 0) sComment = " "+ DoubleQuoteStr(OrderComment());
      string message       = "#"+ OrderTicket() +" "+ sType +" "+ NumberToStr(OrderLots(), ".+") +" "+ Symbol() +" at "+ sPendingPrice + sComment +" was deleted";
      logInfo("onOrderDelete(3)  "+ message);
   }
   return(Orders.RemoveTicket(orders.ticket[i]));
}


/**
 * Main strategy
 *
 * @return bool - success status
 */
bool Strategy() {
   currentSpread = (Ask-Bid)/Pip; if (__isChart) SS.CurrentSpread();
   avgSpread = GetAvgSpread();    if (!avgSpread) return(false);

   double channelHigh, channelLow, channelMean;
   if (!GetIndicatorValues(channelHigh, channelLow, channelMean)) return(false);

   int oe[];
   bool isOpenOrder;
   double price, stopprice, stoploss, takeprofit, newTakeProfit, newStopLoss;

   // manage open orders
   for (int i=0; i < OrdersTotal(); i++) {
      OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
      if (OrderMagicNumber()!=Magic || OrderSymbol()!=Symbol())
         continue;
      isOpenOrder = true;

      switch (OrderType()) {
         case OP_BUY:
            if      (TakeProfitBug)                               newTakeProfit = Ask + TakeProfit*Pip;                       // erroneous TP calculation
            else if (GE(Bid-OrderOpenPrice(), TrailingStart*Pip)) newTakeProfit = Bid + TakeProfit*Pip;                       // correct TP calculation, also check TrailingStart
            else                                                  newTakeProfit = INT_MIN;

            if (GE(newTakeProfit-OrderTakeProfit(), TrailingStep*Pip)) {
               newStopLoss = Bid - StopLoss*Pip;
               if (!OrderModifyEx(OrderTicket(), NULL, newStopLoss, newTakeProfit, NULL, Lime, NULL, oe)) return(false);      // TODO: Orders.UpdateTicket()
            }
            break;

         case OP_SELL:
            if      (TakeProfitBug)                               newTakeProfit = Bid - TakeProfit*Pip;                       // erroneous TP calculation
            else if (GE(OrderOpenPrice()-Ask, TrailingStart*Pip)) newTakeProfit = Ask - TakeProfit*Pip;                       // correct TP calculation, also check TrailingStart
            else                                                  newTakeProfit = INT_MAX;

            if (GE(OrderTakeProfit()-newTakeProfit, TrailingStep*Pip)) {
               newStopLoss = Ask + StopLoss*Pip;
               if (!OrderModifyEx(OrderTicket(), NULL, newStopLoss, newTakeProfit, NULL, Orange, NULL, oe)) return(false);    // TODO: Orders.UpdateTicket()
            }
            break;

         case OP_BUYSTOP:
            if (GE(Bid, channelMean)) {                                    // delete the order if price reached mid channel
               if (!OrderDeleteEx(OrderTicket(), CLR_NONE, NULL, oe)) return(false);
               Orders.RemoveTicket(OrderTicket());
               isOpenOrder = false;
            }
            else {
               stopprice = Ask + BreakoutReversal*Pip;                     // trail pending order in breakout direction

               if (LT(stopprice, OrderOpenPrice())) {
                  stoploss   = stopprice - currentSpread*Pip - StopLoss*Pip;
                  takeprofit = stopprice + TakeProfit*Pip;
                  if (!OrderModifyEx(OrderTicket(), price, stoploss, takeprofit, NULL, Lime, NULL, oe)) return(false);
                  Orders.UpdateTicket(oe.Ticket(oe), oe.OpenPrice(oe), oe.StopLoss(oe), oe.TakeProfit(oe));
               }
            }
            break;

         case OP_SELLSTOP:
            if (LE(Bid, channelMean)) {                                    // delete the order if price reached mid channel
               if (!OrderDeleteEx(OrderTicket(), CLR_NONE, NULL, oe)) return(false);
               Orders.RemoveTicket(OrderTicket());
               isOpenOrder = false;
            }
            else {
               stopprice = Bid - BreakoutReversal*Pip;                     // trail pending order in breakout direction

               if (GT(stopprice, OrderOpenPrice())) {
                  stoploss   = stopprice + currentSpread*Pip + StopLoss*Pip;
                  takeprofit = stopprice - TakeProfit*Pip;
                  if (!OrderModifyEx(OrderTicket(), stopprice, stoploss, takeprofit, NULL, Orange, NULL, oe)) return(false);
                  Orders.UpdateTicket(oe.Ticket(oe), oe.OpenPrice(oe), oe.StopLoss(oe), oe.TakeProfit(oe));
               }
            }
            break;
      }
   }

   // check for entry signals and open a new order
   int signal;
   if (!isOpenOrder) /*&&*/ if (IsEntrySignal(signal)) {
      OpenNewOrder(signal);
   }

   return(!catch("Strategy(1)"));
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
   if (last_error || openOrders) return(false);

   double barSize = iHigh(NULL, IndicatorTimeFrame, 0) - iLow(NULL, IndicatorTimeFrame, 0);
   if (__isChart) sCurrentBarSize = DoubleToStr(barSize/Pip, 1) +" pip";

   if (UseSpreadMultiplier) {
      if (!GetAvgSpread())                                                          return(false);
      if (currentSpread+0.00000001 > MaxSpread || avgSpread+0.00000001 > MaxSpread) return(false);

      minBarSize = avgSpread*Pip * SpreadMultiplier; if (__isChart) SS.MinBarSize();
   }

   if (barSize+0.00000001 >= minBarSize) {
      double channelHigh, channelLow, dNull;
      if (!GetIndicatorValues(channelHigh, channelLow, dNull)) return(false);

      if      (Bid < channelLow)    signal  = SIGNAL_LONG;
      else if (Bid > channelHigh)   signal  = SIGNAL_SHORT;
      if (signal && ReverseSignals) signal ^= 3;               // flip long and short bits (3 = 0011)
   }
   return(signal != NULL);
}


/**
 * Open a new order for the specified entry signal.
 *
 * @param  int signal - order entry signal: SIGNAL_LONG|SIGNAL_SHORT
 *
 * @return bool - success status
 */
bool OpenNewOrder(int signal) {
   if (last_error != 0) return(false);

   double lots   = CalculateLots(true); if (!lots) return(false);
   double spread = Ask-Bid, price, takeprofit, stoploss;
   int oe[];

   if (signal == SIGNAL_LONG) {
      price      = Ask + BreakoutReversal*Pip;
      takeprofit = price + TakeProfit*Pip;
      stoploss   = price - spread - StopLoss*Pip;

      if (!BreakoutReversal) OrderSendEx(Symbol(), OP_BUY,     lots, NULL,  orderSlippage, stoploss, takeprofit, orderComment, Magic, NULL, Blue, NULL, oe);
      else                   OrderSendEx(Symbol(), OP_BUYSTOP, lots, price, NULL,          stoploss, takeprofit, orderComment, Magic, NULL, Blue, NULL, oe);
   }
   else if (signal == SIGNAL_SHORT) {
      price      = Bid - BreakoutReversal*Pip;
      takeprofit = price - TakeProfit*Pip;
      stoploss   = price + spread + StopLoss*Pip;

      if (!BreakoutReversal) OrderSendEx(Symbol(), OP_SELL,     lots, NULL,  orderSlippage, stoploss, takeprofit, orderComment, Magic, NULL, Red, NULL, oe);
      else                   OrderSendEx(Symbol(), OP_SELLSTOP, lots, price, NULL,          stoploss, takeprofit, orderComment, Magic, NULL, Red, NULL, oe);
   }
   else return(!catch("OpenNewOrder(1)  invalid parameter signal: "+ signal, ERR_INVALID_PARAMETER));

   if (oe.IsError(oe)) return(false);

   return(Orders.AddTicket(oe.Ticket(oe), oe.Lots(oe), oe.Type(oe), oe.OpenTime(oe), oe.OpenPrice(oe), NULL, NULL, oe.StopLoss(oe), oe.TakeProfit(oe), NULL, NULL, NULL));
}


/**
 * Calculate and return the average spread. Online at least 30 ticks are collected before calculating an average.
 *
 * @return double - average spread in pip or NULL in case of errors or if the average is not yet available
 */
double GetAvgSpread() {
   static double avgSpread, lastAvgSpread;
   static int lastTick; if (Tick == lastTick) {
      return(lastAvgSpread);
   }
   lastTick = Tick;

   if (IsTesting()) {
      avgSpread = currentSpread; sAvgSpread = sCurrentSpread;
      lastAvgSpread = avgSpread;
      return(avgSpread);
   }

   double spreads[30];
   ArrayCopy(spreads, spreads, 0, 1);
   spreads[29] = currentSpread;

   static int ticks = 0;
   if (ticks < 29) {
      ticks++;
      avgSpread = NULL; sAvgSpread = "-";
      lastAvgSpread = avgSpread;
      return(avgSpread);
   }

   double sum = 0;
   for (int i=0; i < ticks; i++) {
      sum += spreads[i];
   }
   avgSpread = sum/ticks;
   if (avgSpread < 0.00000001)                           // make sure the average never gets zero (a special return value)
      avgSpread = 0.00000001; if (__isChart) SS.AvgSpread();
   lastAvgSpread = avgSpread;

   return(avgSpread);
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
   static double lastHigh, lastLow;

   if (EntryIndicator == 1) {
      channelHigh = iMA(Symbol(), IndicatorTimeFrame, IndicatorPeriods, 0, MODE_LWMA, PRICE_HIGH, 0);
      channelLow  = iMA(Symbol(), IndicatorTimeFrame, IndicatorPeriods, 0, MODE_LWMA, PRICE_LOW, 0);
      channelMean = (channelHigh + channelLow)/2;
      if (__isChart) sIndicator = "MovingAverage";
   }
   else if (EntryIndicator == 2) {
      channelHigh = iBands(Symbol(), IndicatorTimeFrame, IndicatorPeriods, BollingerBands.Deviation, 0, PRICE_OPEN, MODE_UPPER, 0);
      channelLow  = iBands(Symbol(), IndicatorTimeFrame, IndicatorPeriods, BollingerBands.Deviation, 0, PRICE_OPEN, MODE_LOWER, 0);
      channelMean = (channelHigh + channelLow)/2;
      if (__isChart) sIndicator = "BollingerBands";
   }
   else if (EntryIndicator == 3) {
      channelHigh = iEnvelopes(Symbol(), IndicatorTimeFrame, IndicatorPeriods, MODE_LWMA, 0, PRICE_OPEN, Envelopes.Deviation, MODE_UPPER, 0);
      channelLow  = iEnvelopes(Symbol(), IndicatorTimeFrame, IndicatorPeriods, MODE_LWMA, 0, PRICE_OPEN, Envelopes.Deviation, MODE_LOWER, 0);
      channelMean = (channelHigh + channelLow)/2;
      if (__isChart) sIndicator = "Envelopes";
   }
   else return(!catch("GetIndicatorValues(1)  illegal variable EntryIndicator: "+ EntryIndicator, ERR_ILLEGAL_STATE));

   if (ChannelBug) {                                     // reproduce Capella's channel calculation bug (for comparison only)
      if (!lastHigh || Bid > channelMean) {
         lastHigh = channelHigh;                         // return current values and store them
         lastLow  = channelLow;
      }
      else {
         channelHigh = lastHigh;                         // return expired values from storage
         channelLow  = lastLow;
      }
   }
   if (__isChart) sIndicator = StringConcatenate(sIndicator, "    ", NumberToStr(channelMean, PriceFormat), "  ±", DoubleToStr((channelHigh-channelLow)/Pip/2, 1) ,"  (", NumberToStr(channelHigh, PriceFormat), "/", NumberToStr(channelLow, PriceFormat) ,")", ifString(ChannelBug, "   ChannelBug=1", ""));

   int error = GetLastError();
   if (!error)                      return(true);
   if (error == ERS_HISTORY_UPDATE) return(false);
   return(!catch("GetIndicatorValues(2)", error));
}


/**
 * Generate a new magic number using parts of the current symbol.                         TODO: still contains various bugs
 *
 * @return int
 */
int GenerateMagicNumber() {
   string values = "EURUSDJPYCHFCADAUDNZDGBP";
   string base   = StrLeft(Symbol(), 3);
   string quote  = StringSubstr(Symbol(), 3, 3);

   int basePos  = StringFind(values, base, 0);
   int quotePos = StringFind(values, quote, 0);

   return(INT_MAX - AccountNumber() - basePos - quotePos);
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
      if (LE(equity, 0)) return(!catch("CalculateLots(1)  equity: "+ DoubleToStr(equity, 2), ERR_NOT_ENOUGH_MONEY));

      double riskPerTrade = Risk/100 * equity;                          // risked equity amount per trade
      double riskPerPip   = riskPerTrade/StopLoss;                      // risked equity amount per pip

      lots = NormalizeLots(riskPerPip/PipValue(), NULL, MODE_FLOOR);    // resulting normalized position size
      if (IsEmptyValue(lots)) return(NULL);

      if (checkLimits) {
         double minLots = MarketInfo(Symbol(), MODE_MINLOT);
         if (LT(lots, minLots)) return(!catch("CalculateLots(2)  equity: "+ DoubleToStr(equity, 2) +" (resulting position size smaller than MODE_MINLOT of "+ NumberToStr(minLots, ".1+") +")", ERR_NOT_ENOUGH_MONEY));

         double maxLots = MarketInfo(Symbol(), MODE_MAXLOT);
         if (GT(lots, maxLots)) {
            if (LT(lastLots, maxLots)) logNotice("CalculateLots(3)  limiting position size to MODE_MAXLOT: "+ NumberToStr(maxLots, ".+") +" lot");
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
   ArrayResize(orders.ticket,       0);
   ArrayResize(orders.lots,         0);
   ArrayResize(orders.pendingType,  0);
   ArrayResize(orders.pendingPrice, 0);
   ArrayResize(orders.openType,     0);
   ArrayResize(orders.openTime,     0);
   ArrayResize(orders.openPrice,    0);
   ArrayResize(orders.closeTime,    0);
   ArrayResize(orders.closePrice,   0);
   ArrayResize(orders.stopLoss,     0);
   ArrayResize(orders.takeProfit,   0);
   ArrayResize(orders.swap,         0);
   ArrayResize(orders.commission,   0);
   ArrayResize(orders.profit,       0);

   openPositions    = 0;
   openLots         = 0;
   openSwap         = 0;
   openCommission   = 0;
   openPl           = 0;
   openPlNet        = 0;
   closedPositions  = 0;
   closedLots       = 0;
   closedSwap       = 0;
   closedCommission = 0;
   closedPl         = 0;
   closedPlNet      = 0;
   totalPlNet       = 0;

   // all closed positions
   int orders = OrdersHistoryTotal();
   for (int i=0; i < orders; i++) {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) return(_false(catch("ReadOrderLog(1)")));
      if (OrderMagicNumber() != Magic) continue;
      if (OrderType() > OP_SELL)       continue;
      if (OrderSymbol() != Symbol())   continue;

      Orders.AddTicket(OrderTicket(), OrderLots(), OrderType(), OrderOpenTime(), OrderOpenPrice(), OrderCloseTime(), OrderClosePrice(), OrderStopLoss(), OrderTakeProfit(), OrderSwap(), OrderCommission(), OrderProfit());
   }

   // all open tickets
   orders = OrdersTotal();
   for (i=0; i < orders; i++) {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) return(_false(catch("ReadOrderLog(2)")));
      if (OrderMagicNumber() != Magic) continue;
      if (OrderSymbol() != Symbol())   continue;

      Orders.AddTicket(OrderTicket(), OrderLots(), OrderType(), OrderOpenTime(), OrderOpenPrice(), NULL, NULL, OrderStopLoss(), OrderTakeProfit(), OrderSwap(), OrderCommission(), OrderProfit());
   }
   return(!catch("ReadOrderLog(3)"));
}


/**
 * Add a new record to the order log and update statistics.
 *
 * @param  int      ticket
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
bool Orders.AddTicket(int ticket, double lots, int type, datetime openTime, double openPrice, datetime closeTime, double closePrice, double stopLoss, double takeProfit, double swap, double commission, double profit) {
   int pos = SearchIntArray(orders.ticket, ticket);
   if (pos >= 0) return(!catch("Orders.AddTicket(1)  invalid parameter ticket: #"+ ticket +" (exists)", ERR_INVALID_PARAMETER));

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

   int size=ArraySize(orders.ticket), newSize=size+1;
   ArrayResize(orders.ticket,       newSize); orders.ticket      [size] = ticket;
   ArrayResize(orders.lots,         newSize); orders.lots        [size] = lots;
   ArrayResize(orders.pendingType,  newSize); orders.pendingType [size] = pendingType;
   ArrayResize(orders.pendingPrice, newSize); orders.pendingPrice[size] = pendingPrice;
   ArrayResize(orders.openType,     newSize); orders.openType    [size] = openType;
   ArrayResize(orders.openTime,     newSize); orders.openTime    [size] = openTime;
   ArrayResize(orders.openPrice,    newSize); orders.openPrice   [size] = openPrice;
   ArrayResize(orders.closeTime,    newSize); orders.closeTime   [size] = closeTime;
   ArrayResize(orders.closePrice,   newSize); orders.closePrice  [size] = closePrice;
   ArrayResize(orders.stopLoss,     newSize); orders.stopLoss    [size] = stopLoss;
   ArrayResize(orders.takeProfit,   newSize); orders.takeProfit  [size] = takeProfit;
   ArrayResize(orders.swap,         newSize); orders.swap        [size] = swap;
   ArrayResize(orders.commission,   newSize); orders.commission  [size] = commission;
   ArrayResize(orders.profit,       newSize); orders.profit      [size] = profit;

   bool isPosition       = (openType != OP_UNDEFINED);
   bool isOpenPosition   = (isPosition && !closeTime);
   bool isClosedPosition = (isPosition && closeTime);
   bool isLong           = IsLongOrderType(type);

   if (isOpenPosition) {
      openPositions++;
      openLots       += ifDouble(isLong, lots, -lots);
      openSwap       += swap;
      openCommission += commission;
      openPl         += profit;
      openPlNet       = openSwap + openCommission + openPl;
   }
   if (isClosedPosition) {
      closedPositions++;
      closedLots       += lots;
      closedSwap       += swap;
      closedCommission += commission;
      closedPl         += profit;
      closedPlNet       = closedSwap + closedCommission + closedPl;
   }
   if (isPosition) {
      totalPlNet = openPlNet + closedPlNet;
   }
   return(!catch("Orders.AddTicket(2)"));
}


/**
 * Update the order record of the specified ticket.
 *
 * @param  int    ticket
 * @param  double pendingPrice
 * @param  double stopLoss
 * @param  double takeProfit
 *
 * @return bool - success status
 */
bool Orders.UpdateTicket(int ticket, double pendingPrice, double stopLoss, double takeProfit) {
   int pos = SearchIntArray(orders.ticket, ticket);
   if (pos < 0) return(!catch("Orders.UpdateTicket(1)  invalid parameter ticket: #"+ ticket +" (not found)", ERR_INVALID_PARAMETER));

   orders.pendingPrice[pos] = pendingPrice;
   orders.stopLoss    [pos] = stopLoss;
   orders.takeProfit  [pos] = takeProfit;

   return(!catch("Orders.UpdateTicket(2)"));
}


/**
 * Remove a record from the order log.
 *
 * @param  int ticket - ticket of the record
 *
 * @return bool - success status
 */
bool Orders.RemoveTicket(int ticket) {
   int pos = SearchIntArray(orders.ticket, ticket);
   if (pos < 0)                              return(!catch("Orders.RemoveTicket(1)  invalid parameter ticket: #"+ ticket +" (not found)", ERR_INVALID_PARAMETER));
   if (orders.openType[pos] != OP_UNDEFINED) return(!catch("Orders.RemoveTicket(2)  cannot remove an already opened position: #"+ ticket, ERR_ILLEGAL_STATE));

   ArraySpliceInts   (orders.ticket,       pos, 1);
   ArraySpliceDoubles(orders.lots,         pos, 1);
   ArraySpliceInts   (orders.pendingType,  pos, 1);
   ArraySpliceDoubles(orders.pendingPrice, pos, 1);
   ArraySpliceInts   (orders.openType,     pos, 1);
   ArraySpliceInts   (orders.openTime,     pos, 1);
   ArraySpliceDoubles(orders.openPrice,    pos, 1);
   ArraySpliceInts   (orders.closeTime,    pos, 1);
   ArraySpliceDoubles(orders.closePrice,   pos, 1);
   ArraySpliceDoubles(orders.stopLoss,     pos, 1);
   ArraySpliceDoubles(orders.takeProfit,   pos, 1);
   ArraySpliceDoubles(orders.swap,         pos, 1);
   ArraySpliceDoubles(orders.commission,   pos, 1);
   ArraySpliceDoubles(orders.profit,       pos, 1);

   return(!catch("Orders.RemoveTicket(3)"));
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

   string sError = "";
   if      (__STATUS_INVALID_INPUT) sError = StringConcatenate("  [",                 ErrorDescription(ERR_INVALID_INPUT_PARAMETER), "]");
   else if (__STATUS_OFF          ) sError = StringConcatenate("  [switched off => ", ErrorDescription(__STATUS_OFF.reason),         "]");

   string sSpreadInfo = "";
   if (currentSpread+0.00000001 > MaxSpread || avgSpread+0.00000001 > MaxSpread)
      sSpreadInfo = StringConcatenate("  =>  larger then MaxSpread of ", sMaxSpread);

   string msg = StringConcatenate(ProgramName(), "         ", sError,                                                                              NL,
                                                                                                                                                   NL,
                                  "BarSize:    ", sCurrentBarSize, "    MinBarSize: ", sMinBarSize,                                                NL,
                                  "Channel:   ",  sIndicator,                                                                                      NL,
                                  "Spread:    ",  sCurrentSpread, "    Avg: ", sAvgSpread, sSpreadInfo,                                            NL,
                                  "Unitsize:   ", sUnitSize,                                                                                       NL,
                                                                                                                                                   NL,
                                  "Open:      ", NumberToStr(openLots, "+.+"),   " lot                           PL: ", DoubleToStr(openPlNet, 2), NL,
                                  "Closed:    ", closedPositions, " trades    ", NumberToStr(closedLots, ".+"), " lot    PL: ", DoubleToStr(closedPl, 2), "    Commission: ", DoubleToStr(closedCommission, 2), "    Swap: ", DoubleToStr(closedSwap, 2), NL,
                                                                                                                                                   NL,
                                  "Total PL:  ", DoubleToStr(totalPlNet, 2),                                                                       NL
   );

   // 3 lines margin-top for potential indicator legends
   Comment(NL, NL, NL, msg);
   if (__CoreFunction == CF_INIT) WindowRedraw();

   if (!catch("ShowStatus(1)"))
      return(error);
   return(last_error);
}


/**
 * ShowStatus: Update all string representations.
 */
void SS.All() {
   if (__isChart) {
      SS.UnitSize();
      SS.AvgSpread();            // before SS.CurrentSpread()
      SS.CurrentSpread();
      SS.MinBarSize();
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
 * ShowStatus: Update the string representation of the current spread.
 */
void SS.CurrentSpread() {
   if (__isChart) {
      sCurrentSpread = DoubleToStr(currentSpread, 1);
      if (IsTesting()) {
         sAvgSpread = sCurrentSpread;
      }
   }
}


/**
 * ShowStatus: Update the string representation of the average spread.
 */
void SS.AvgSpread() {
   if (__isChart) {
      if (!avgSpread) sAvgSpread = "-";
      else            sAvgSpread = DoubleToStr(avgSpread, 2);
   }
}


/**
 * ShowStatus: Update the string representation of the min. bar size.
 */
void SS.MinBarSize() {
   if (__isChart) {
      sMinBarSize = DoubleToStr(RoundCeil(minBarSize/Pip, 1), 1) +" pip";
   }
}
