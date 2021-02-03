/**
 * XMT-Scalper revisited
 *
 *
 * This EA is originally based on the famous "MillionDollarPips EA". A member of the "www.worldwide-invest.org" forum known
 * as Capella transformed it to "XMT-Scalper". In his own words: "Nothing remains from the original except the core idea of
 * the strategy: scalping based on a reversal from a channel breakout." Today various versions with different names circulate
 * in the internet (MDP-Plus, XMT, Assar). None is suitable for real trading. Main reasons are a high price feed sensitivity
 * (especially the number of received ticks) and the unaccounted effects of slippage/commission. Moreover test behavior
 * differs from online behavior to such a large degree that test results are unusable.
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
 *  - simplified input parameters
 *  - fixed input parameter validation
 *  - fixed position size calculation
 *  - fixed trading errors
 *  - rewrote status display
 *
 *  - renamed input parameter ReverseTrades to ReverseSignals
 */
#include <stddefines.mqh>
int   __InitFlags[] = {INIT_TIMEZONE, INIT_PIPVALUE, INIT_BUFFERED_LOG};
int __DeinitFlags[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern string ___a_____________________ = "=== Entry indicator: 1=MovingAverage, 2=BollingerBands, 3=Envelopes ===";
extern int    EntryIndicator            = 1;          // entry signal indicator for price channel calculation
extern int    Indicatorperiod           = 3;          // period in bars for indicator
extern double BBDeviation               = 2;          // deviation for the iBands indicator
extern double EnvelopesDeviation        = 0.07;       // deviation for the iEnvelopes indicator

extern string ___b_____________________ = "==== Entry bar conditions ====";
extern bool   UseDynamicVolatilityLimit = true;       // calculated based on (int)(spread * VolatilityMultiplier)
extern double VolatilityMultiplier      = 125;        // a multiplier that is used if UseDynamicVolatilityLimit is TRUE
extern double VolatilityLimit           = 180;        // a fix value that is used if UseDynamicVolatilityLimit is FALSE
extern double VolatilityPercentageLimit = 0;          // percentage of how much iHigh-iLow difference must differ from VolatilityLimit

extern string ___c_____________________ = "==== Trade settings ====";
extern bool   ReverseSignals            = false;      // Buy => Sell, Sell => Buy
extern int    TimeFrame                 = PERIOD_M1;  // trading timeframe must match the timeframe of the chart
extern int    StopLoss                  = 60;         // SL in point
extern int    TakeProfit                = 100;        // TP in point
extern double TrailingStart             = 20;         // start trailing profit from as so many points.
extern int    StopDistance.Points       = 0;          // pending entry order distance in point (0 = market order)
extern int    Slippage.Points           = 3;          // acceptable market order slippage in point
extern double MaxSpread                 = 30;         // max allowed spread in point
extern int    Magic                     = -1;         // if negative the MagicNumber is generated

extern string ___d_____________________ = "==== MoneyManagement ====";
extern bool   MoneyManagement           = true;       // if TRUE lots are calculated dynamically, if FALSE "ManualLotsize" is used
extern double Risk                      = 2;          // percent of equity to risk for each trade
extern double ManualLotsize             = 0.1;        // fix position size to use if "MoneyManagement" is FALSE

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/expert.mqh>
#include <stdfunctions.mqh>
#include <rsfLibs.mqh>
#include <functions/JoinStrings.mqh>
#include <structs/rsf/OrderExecution.mqh>

#define SIGNAL_LONG     1
#define SIGNAL_SHORT    2


// order tracking
int      tickets      [];
int      pendingTypes [];
double   pendingPrices[];
int      types        [];
datetime closeTimes   [];

// trade statistics
int    openPositions;            // number of open positions
double openLots;                 // total open lotsize
double openSwap;                 // total open swap
double openCommission;           // total open commissions
double openPl;                   // total open gross profit
double openPlNet;                // total open net profit

int    closedPositions;          // number of closed positions
double closedLots;               // total closed lotsize
double closedSwap;               // total closed swap
double closedCommission;         // total closed commission
double closedPl;                 // total closed gross profit
double closedPlNet;              // total closed net profit

double totalPlNet;               // openPlNet + closedPlNet

// other
double stopDistance;             // entry order stop distance in quote currency
string orderComment = "XMT-rsf";

// cache vars to speed-up ShowStatus()
string sUnitSize   = "";
string sStatusInfo = "\n\n\n";


// --- old ------------------------------------------------------------
int    tickCounter = 0;          // for calculating average spread
double spreads[30];              // store spreads for the last 30 ticks
double channelHigh;
double channelLow;


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   // validate inputs
   // StopLoss
   if (!StopLoss)                                                     return(!catch("onInit(1)  invalid input parameter StopLoss: "+ StopLoss +" (must be positive)", ERR_INVALID_INPUT_PARAMETER));
   if (LT(StopLoss, MarketInfo(Symbol(), MODE_STOPLEVEL)))            return(!catch("onInit(2)  invalid input parameter StopLoss: "+ StopLoss +" (smaller than MODE_STOPLEVEL)", ERR_INVALID_INPUT_PARAMETER));
   // TakeProfit
   if (LT(TakeProfit, MarketInfo(Symbol(), MODE_STOPLEVEL)))          return(!catch("onInit(3)  invalid input parameter TakeProfit: "+ TakeProfit +" (smaller than MODE_STOPLEVEL)", ERR_INVALID_INPUT_PARAMETER));
   // StopDistance
   if (LT(StopDistance.Points, MarketInfo(Symbol(), MODE_STOPLEVEL))) return(!catch("onInit(4)  invalid input parameter StopDistance.Points: "+ StopDistance.Points +" (smaller than MODE_STOPLEVEL)", ERR_INVALID_INPUT_PARAMETER));
   if (MoneyManagement) {
      // Risk
      if (LE(Risk, 0))                                                return(!catch("onInit(5)  invalid input parameter Risk: "+ NumberToStr(Risk, ".1+") +" (must be positive)", ERR_INVALID_INPUT_PARAMETER));
      double lotsPerTrade = CalculateLots(false); if (IsLastError())  return(last_error);
      if (LT(lotsPerTrade, MarketInfo(Symbol(), MODE_MINLOT)))        return(!catch("onInit(6)  invalid input parameter Risk: "+ NumberToStr(Risk, ".1+") +" (resulting position size smaller than MODE_MINLOT)", ERR_INVALID_INPUT_PARAMETER));
      if (GT(lotsPerTrade, MarketInfo(Symbol(), MODE_MAXLOT)))        return(!catch("onInit(7)  invalid input parameter Risk: "+ NumberToStr(Risk, ".1+") +" (resulting position size larger than MODE_MAXLOT)", ERR_INVALID_INPUT_PARAMETER));
   }
   else {
      // ManualLotsize
      if (LT(ManualLotsize, MarketInfo(Symbol(), MODE_MINLOT)))       return(!catch("onInit(8)  invalid input parameter ManualLotsize: "+ NumberToStr(ManualLotsize, ".1+") +" (smaller than MODE_MINLOT)", ERR_INVALID_INPUT_PARAMETER));
      if (GT(ManualLotsize, MarketInfo(Symbol(), MODE_MAXLOT)))       return(!catch("onInit(9)  invalid input parameter ManualLotsize: "+ NumberToStr(ManualLotsize, ".1+") +" (larger than MODE_MAXLOT)", ERR_INVALID_INPUT_PARAMETER));
   }




   // --- old ---------------------------------------------------------------------------------------------------------------
   if (!IsTesting() && Period()!=TimeFrame) {
      return(catch("onInit(10)  The EA has been set to run on timeframe: "+ TimeFrame +" but it has been attached to a chart with timeframe: "+ Period(), ERR_RUNTIME_ERROR));
   }

   // Check to confirm that indicator switch is valid choices, if not force to 1 (Moving Average)
   if (EntryIndicator < 1 || EntryIndicator > 3)
      EntryIndicator = 1;

   // Re-calculate variables
   VolatilityPercentageLimit = VolatilityPercentageLimit / 100 + 1;
   VolatilityMultiplier = VolatilityMultiplier / 10;
   ArrayInitialize(spreads, 0);
   VolatilityLimit = VolatilityLimit * Point;
   TrailingStart = TrailingStart * Point;
   stopDistance  = StopDistance.Points * Point;

   if (Magic < 0) Magic = CreateMagicNumber();

   UpdateTradeStats();
   return(catch("onInit(11)"));
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
   Trade();
   UpdateTradeStats();

   return(catch("onTick(1)"));
}


/**
 * Detect and track open/closed positions.
 *
 * @return bool - success status
 */
bool UpdateOrderStatus() {
   int orders = ArraySize(tickets);

   // update ticket status
   for (int i=0; i < orders; i++) {
      if (closeTimes[i] > 0) continue;                            // skip tickets already known as closed
      if (!SelectTicket(tickets[i], "UpdateOrderStatus(1)")) return(false);

      bool wasPending  = (types[i] == OP_UNDEFINED);
      bool isPending   = (OrderType() > OP_SELL);
      bool wasPosition = !wasPending;
      bool isOpen      = !OrderCloseTime();
      bool isClosed    = !isOpen;

      if (wasPending) {
         if (!isPending) {                                        // the pending order was filled
            types[i] = OrderType();
            onPositionOpen(i);
            wasPosition = true;                                   // mark as known open position
         }
         else if (isClosed) {                                     // the pending order was cancelled
            onOrderDelete(i);
            i--; orders--;
            continue;
         }
      }

      if (wasPosition) {
         if (!isOpen) {                                           // the open position was closed
            onPositionClose(i);
            i--; orders--;
            continue;
         }
      }
   }
   return(!catch("UpdateOrderStatus(2)"));
}


/**
 * Handle PositionOpen events.
 *
 * @param  int i - ticket index of the opened position
 *
 * @return bool - success status
 */
bool onPositionOpen(int i) {
   if (IsLogInfo()) {
      // #1 Stop Sell 0.1 GBPUSD at 1.5457'2[ "comment"] was filled[ at 1.5457'2] (market: Bid/Ask[, 0.3 pip [positive ]slippage])

      SelectTicket(tickets[i], "onPositionOpen(1)", /*push=*/true);
      int    pendingType  = pendingTypes [i];
      double pendingPrice = pendingPrices[i];

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
      OrderPop("onPositionOpen(2)");
      logInfo("onPositionOpen(3)  "+ message +" (market: "+ NumberToStr(Bid, PriceFormat) +"/"+ NumberToStr(Ask, PriceFormat) + sSlippage +")");
   }

   if (IsTesting() && __ExecutionContext[EC.extReporting]) {
      SelectTicket(tickets[i], "onPositionOpen(4)", /*push=*/true);
      Test_onPositionOpen(__ExecutionContext, OrderTicket(), OrderType(), OrderLots(), OrderSymbol(), OrderOpenTime(), OrderOpenPrice(), OrderStopLoss(), OrderTakeProfit(), OrderCommission(), OrderMagicNumber(), OrderComment());
      OrderPop("onPositionOpen(5)");
   }
   return(!catch("onPositionOpen(6)"));
}


/**
 * Handle PositionClose events.
 *
 * @param  int i - ticket index of the closed position
 *
 * @return bool - success status
 */
bool onPositionClose(int i) {
   if (IsLogInfo()) {
      // #1 Sell 0.1 GBPUSD at 1.5457'2[ "comment"] was closed at 1.5457'2 (market: Bid/Ask[, so: 47.7%/169.20/354.40])

      SelectTicket(tickets[i], "onPositionClose(1)", /*push=*/true);
      string sType       = OperationTypeDescription(OrderType());
      string sOpenPrice  = NumberToStr(OrderOpenPrice(), PriceFormat);
      string sClosePrice = NumberToStr(OrderClosePrice(), PriceFormat);
      string sComment    = ""; if (StringLen(OrderComment()) > 0) sComment = " "+ DoubleQuoteStr(OrderComment());
      string message     = "#"+ OrderTicket() +" "+ sType +" "+ NumberToStr(OrderLots(), ".+") +" "+ Symbol() +" at "+ sOpenPrice + sComment +" was closed at "+ sClosePrice;
      OrderPop("onPositionClose(2)");
      logInfo("onPositionClose(3)  "+ message +" (market: "+ NumberToStr(Bid, PriceFormat) +"/"+ NumberToStr(Ask, PriceFormat) +")");
   }

   if (IsTesting() && __ExecutionContext[EC.extReporting]) {
      SelectTicket(tickets[i], "onPositionClose(4)", /*push=*/true);
      Test_onPositionClose(__ExecutionContext, OrderTicket(), OrderCloseTime(), OrderClosePrice(), OrderSwap(), OrderProfit());
      OrderPop("onPositionClose(5)");
   }
   return(Orders.RemoveTicket(tickets[i]));
}


/**
 * Handle OrderDelete events.
 *
 * @param  int i - ticket index of the deleted order
 *
 * @return bool - success status
 */
bool onOrderDelete(int i) {
   if (IsLogInfo()) {
      // #1 Stop Sell 0.1 GBPUSD at 1.5457'2[ "comment"] was deleted

      SelectTicket(tickets[i], "onOrderDelete(1)", /*push=*/true);
      int    pendingType  = pendingTypes [i];
      double pendingPrice = pendingPrices[i];

      string sType         = OperationTypeDescription(pendingType);
      string sPendingPrice = NumberToStr(pendingPrice, PriceFormat);
      string sComment      = ""; if (StringLen(OrderComment()) > 0) sComment = " "+ DoubleQuoteStr(OrderComment());
      string message       = "#"+ OrderTicket() +" "+ sType +" "+ NumberToStr(OrderLots(), ".+") +" "+ Symbol() +" at "+ sPendingPrice + sComment +" was deleted";
      OrderPop("onOrderDelete(2)");

      logInfo("onOrderDelete(3)  "+ message);
   }
   return(Orders.RemoveTicket(tickets[i]));
}


/**
 * Add a new order record.
 *
 * @param  int      ticket
 * @param  int      pendingType
 * @param  double   pendingPrice
 * @param  int      type
 * @param  datetime closeTime
 *
 * @return bool - success status
 */
bool Orders.AddTicket(int ticket, int pendingType, double pendingPrice, int type, datetime closeTime) {
   int pos = SearchIntArray(tickets, ticket);
   if (pos >= 0) return(!catch("Orders.AddTicket(1)  invalid parameter ticket: "+ ticket +" (already exists)", ERR_INVALID_PARAMETER));

   ArrayPushInt   (tickets,       ticket      );
   ArrayPushInt   (pendingTypes,  pendingType );
   ArrayPushDouble(pendingPrices, pendingPrice);
   ArrayPushInt   (types,         type        );
   ArrayPushInt   (closeTimes,    closeTime   );

   return(!catch("Orders.AddTicket()"));
}


/**
 * Update the order record with the specified ticket.
 *
 * @param  int      ticket
 * @param  int      pendingType
 * @param  double   pendingPrice
 * @param  int      type
 * @param  datetime closeTime
 *
 * @return bool - success status
 */
bool Orders.UpdateTicket(int ticket, int pendingType, double pendingPrice, int type, datetime closeTime) {
   int pos = SearchIntArray(tickets, ticket);
   if (pos < 0) return(!catch("Orders.UpdateTicket(1)  invalid parameter ticket: "+ ticket +" (order not found)", ERR_INVALID_PARAMETER));

   pendingTypes [pos] = pendingType;
   pendingPrices[pos] = pendingPrice;
   types        [pos] = type;
   closeTimes   [pos] = closeTime;

   return(!catch("Orders.UpdateTicket(2)"));
}


/**
 * Remove the order record with the specified ticket.
 *
 * @param  int ticket
 *
 * @return bool - success status
 */
bool Orders.RemoveTicket(int ticket) {
   int pos = SearchIntArray(tickets, ticket);
   if (pos < 0) return(!catch("Orders.RemoveTicket(1)  invalid parameter ticket: "+ ticket +" (order not found)", ERR_INVALID_PARAMETER));

   ArraySpliceInts   (tickets,       pos, 1);
   ArraySpliceInts   (pendingTypes,  pos, 1);
   ArraySpliceDoubles(pendingPrices, pos, 1);
   ArraySpliceInts   (types,         pos, 1);
   ArraySpliceInts   (closeTimes,    pos, 1);

   return(!catch("Orders.RemoveTicket(2)"));
}


/**
 * Main trading routine
 */
void Trade() {
   bool   isChart = IsChart();
   string sIndicatorStatus = "";

   if (EntryIndicator == 1) {
      double iH = iMA(Symbol(), TimeFrame, Indicatorperiod, 0, MODE_LWMA, PRICE_HIGH, 0);
      double iL = iMA(Symbol(), TimeFrame, Indicatorperiod, 0, MODE_LWMA, PRICE_LOW,  0);
      double iM = (iH+iL)/2;
      if (isChart) sIndicatorStatus = "MovingAverage chHigh: "+ DoubleToStr(iH, Digits) +", chLow: " + DoubleToStr(iL, Digits) +", chMid: "+ DoubleToStr(iM, Digits);
   }
   else if (EntryIndicator == 2) {
      iH = iBands(Symbol(), TimeFrame, Indicatorperiod, BBDeviation, 0, PRICE_OPEN, MODE_UPPER, 0);
      iL = iBands(Symbol(), TimeFrame, Indicatorperiod, BBDeviation, 0, PRICE_OPEN, MODE_LOWER, 0);
      iM = (iH+iL)/2;
      if (isChart) sIndicatorStatus = "BollingerBands chHigh: "+ DoubleToStr(iH, Digits) +", chLow: "+ DoubleToStr(iL, Digits) +", chMid: "+ DoubleToStr(iM, Digits);
   }
   else if (EntryIndicator == 3) {
      iH = iEnvelopes(Symbol(), TimeFrame, Indicatorperiod, MODE_LWMA, 0, PRICE_OPEN, EnvelopesDeviation, MODE_UPPER, 0);
      iL = iEnvelopes(Symbol(), TimeFrame, Indicatorperiod, MODE_LWMA, 0, PRICE_OPEN, EnvelopesDeviation, MODE_LOWER, 0);
      iM = (iH+iL)/2;
      if (isChart) sIndicatorStatus = "Envelopes chHigh: "+ DoubleToStr(iH, Digits) +", chLow: "+ DoubleToStr(iL, Digits) +", chMid: "+ DoubleToStr(iM, Digits);
   }

   // Check if the price is outside of this channel
   bool isbidgreaterthanindy = false;
   if (Bid >= iM) {
      isbidgreaterthanindy = true;
      channelHigh = iH;
      channelLow  = iL;
   }

   // calculate the average spread of the last 30 ticks
   double sumSpreads, spread = Ask - Bid;
   ArrayCopy(spreads, spreads, 0, 1, 29);
   spreads[29] = spread;
   if (tickCounter < 30) tickCounter++;
   for (int i, n=29; i < tickCounter; i++) {
      sumSpreads += spreads[n];
      n--;
   }
   double avgSpread = sumSpreads/tickCounter;
   double currentBarSize = iHigh(Symbol(), TimeFrame, 0) - iLow(Symbol(), TimeFrame, 0);
   if (UseDynamicVolatilityLimit)
      VolatilityLimit = avgSpread * VolatilityMultiplier;

   // determine trade signals
   int oe[], tradeSignal = NULL;
   double orderprice, orderstoploss, ordertakeprofit, volatilitypercentage;

   // If the variables below have values it means we have enough market data.
   if (currentBarSize && VolatilityLimit && channelHigh && channelLow) {
      // We have a price breakout, as the Volatility is outside of the VolatilityLimit, so we can now open a trade
      if (currentBarSize > VolatilityLimit) {
         volatilitypercentage = currentBarSize / VolatilityLimit;

         // check if it differ enough from the specified limit
         if (volatilitypercentage > VolatilityPercentageLimit) {
            if      (Bid < channelLow)  tradeSignal = SIGNAL_LONG;      // 1 = 0001
            else if (Bid > channelHigh) tradeSignal = SIGNAL_SHORT;     // 2 = 0010
            if (tradeSignal && ReverseSignals) tradeSignal ^= 3;        // flip both bits: 3 = 0011
         }
      }
   }

   bool isOpenOrder = false;

   // Loop through all open orders to either modify or to delete them
   for (i=0; i < OrdersTotal(); i++) {
      OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
      if (OrderMagicNumber()!=Magic || OrderSymbol()!=Symbol())
         continue;

      isOpenOrder = true;
      RefreshRates();

      switch (OrderType()) {
         case OP_BUY:
            if (LT(OrderTakeProfit(), Ask+TakeProfit*Point) && Ask+TakeProfit*Point - OrderTakeProfit() > TrailingStart) {
               orderstoploss   = NormalizeDouble(Bid - StopLoss*Point, Digits);
               ordertakeprofit = NormalizeDouble(Ask + TakeProfit*Point, Digits);

               if (NE(orderstoploss, OrderStopLoss()) || NE(ordertakeprofit, OrderTakeProfit())) {
                  if (!OrderModifyEx(OrderTicket(), NULL, orderstoploss, ordertakeprofit, NULL, Lime, NULL, oe)) return(catch("Trade(1)"));
               }
            }
            break;

         case OP_SELL:
            if (GT(OrderTakeProfit(), Bid-TakeProfit*Point) && OrderTakeProfit() - Bid + TakeProfit*Point > TrailingStart) {
               orderstoploss   = NormalizeDouble(Ask + StopLoss*Point, Digits);
               ordertakeprofit = NormalizeDouble(Bid - TakeProfit*Point, Digits);

               if (NE(orderstoploss, OrderStopLoss()) || NE(ordertakeprofit, OrderTakeProfit())) {
                  if (!OrderModifyEx(OrderTicket(), NULL, orderstoploss, ordertakeprofit, NULL, Orange, NULL, oe)) return(catch("Trade(2)"));
               }
            }
            break;

         case OP_BUYSTOP:
            // Price must NOT be larger than indicator in order to modify the order, otherwise the order will be deleted
            if (!isbidgreaterthanindy) {
               // Calculate how much Price, SL and TP should be modified
               orderprice      = NormalizeDouble(Ask + stopDistance, Digits);
               orderstoploss   = NormalizeDouble(orderprice - spread - StopLoss*Point, Digits);
               ordertakeprofit = NormalizeDouble(orderprice + TakeProfit*Point, Digits);

               // Ok to modify the order if price is less than orderprice AND orderprice-price is greater than trailingstart
               if (orderprice < OrderOpenPrice() && OrderOpenPrice()-orderprice > TrailingStart) {

                  // Send an OrderModify command with adjusted Price, SL and TP
                  if (NE(orderstoploss, OrderStopLoss()) || NE(ordertakeprofit, OrderTakeProfit())) {
                     if (!OrderModifyEx(OrderTicket(), orderprice, orderstoploss, ordertakeprofit, NULL, Lime, NULL, oe)) return(catch("Trade(3)"));
                     Orders.UpdateTicket(OrderTicket(), OrderType(), orderprice, OP_UNDEFINED, OrderCloseTime());
                  }
               }
            }
            else {
               if (!OrderDeleteEx(OrderTicket(), CLR_NONE, NULL, oe)) return(catch("Trade(4)"));
               Orders.RemoveTicket(OrderTicket());
               isOpenOrder = false;
            }
            break;

         case OP_SELLSTOP:
            // Price must be larger than the indicator in order to modify the order, otherwise the order will be deleted
            if (isbidgreaterthanindy) {
               // Calculate how much Price, SL and TP should be modified
               orderprice      = NormalizeDouble(Bid - stopDistance, Digits);
               orderstoploss   = NormalizeDouble(orderprice + spread + StopLoss*Point, Digits);
               ordertakeprofit = NormalizeDouble(orderprice - TakeProfit*Point, Digits);

               // Ok to modify order if price is greater than orderprice AND price-orderprice is greater than trailingstart
               if (orderprice > OrderOpenPrice() && orderprice-OrderOpenPrice() > TrailingStart) {

                  // Send an OrderModify command with adjusted Price, SL and TP
                  if (NE(orderstoploss, OrderStopLoss()) || NE(ordertakeprofit, OrderTakeProfit())) {
                     if (!OrderModifyEx(OrderTicket(), orderprice, orderstoploss, ordertakeprofit, NULL, Orange, NULL, oe)) return(catch("Trade(5)"));
                     Orders.UpdateTicket(OrderTicket(), OrderType(), orderprice, OP_UNDEFINED, OrderCloseTime());
                  }
               }
            }
            else {
               if (!OrderDeleteEx(OrderTicket(), CLR_NONE, NULL, oe)) return(catch("Trade(6)"));
               Orders.RemoveTicket(OrderTicket());
               isOpenOrder = false;
            }
            break;
      }
   }


   // Open a new order if we have a signal and no open orders and average spread is less or equal to max allowed spread
   if (tradeSignal && !isOpenOrder && NormalizeDouble(avgSpread, Digits) <= NormalizeDouble(MaxSpread * Point, Digits)) {
      double lots = CalculateLots(true); if (!lots) return(last_error);

      if (tradeSignal == SIGNAL_LONG) {
         orderprice      = Ask + stopDistance;
         orderstoploss   = NormalizeDouble(orderprice - spread - StopLoss*Point, Digits);
         ordertakeprofit = NormalizeDouble(orderprice + TakeProfit*Point, Digits);

         if (GT(stopDistance, 0) || IsTesting()) {
            if (!OrderSendEx(Symbol(), OP_BUYSTOP, lots, orderprice, NULL, orderstoploss, ordertakeprofit, orderComment, Magic, NULL, Blue, NULL, oe)) return(catch("Trade(7)"));
            Orders.AddTicket(oe.Ticket(oe), OP_BUYSTOP, oe.OpenPrice(oe), OP_UNDEFINED, NULL);
         }
         else {
            if (!OrderSendEx(Symbol(), OP_BUY, lots, NULL, Slippage.Points, orderstoploss, ordertakeprofit, orderComment, Magic, NULL, Blue, NULL, oe)) return(catch("Trade(8)"));
            Orders.AddTicket(oe.Ticket(oe), OP_UNDEFINED, NULL, OP_BUY, NULL);
         }
      }
      if (tradeSignal == SIGNAL_SHORT) {
         orderprice      = Bid - stopDistance;
         orderstoploss   = NormalizeDouble(orderprice + spread + StopLoss*Point, Digits);
         ordertakeprofit = NormalizeDouble(orderprice - TakeProfit*Point, Digits);

         if (GT(stopDistance, 0) || IsTesting()) {
            if (!OrderSendEx(Symbol(), OP_SELLSTOP, lots, orderprice, NULL, orderstoploss, ordertakeprofit, orderComment, Magic, NULL, Red, NULL, oe)) return(catch("Trade(9)"));
            Orders.AddTicket(oe.Ticket(oe), OP_SELLSTOP, oe.OpenPrice(oe), OP_UNDEFINED, NULL);
         }
         else {
            if (!OrderSendEx(Symbol(), OP_SELL, lots, NULL, Slippage.Points, orderstoploss, ordertakeprofit, orderComment, Magic, NULL, Red, NULL, oe)) return(catch("Trade(10)"));
            Orders.AddTicket(oe.Ticket(oe), OP_UNDEFINED, NULL, OP_SELL, NULL);
         }
      }
   }

   // compose chart status messages
   if (isChart) {
      sStatusInfo = StringConcatenate("CurrentBar: ", DoubleToStr(currentBarSize/Pip, 1), " pip    VolatilityLimit: ", DoubleToStr(VolatilityLimit, Digits), "    VolatilityPercentage: ", DoubleToStr(volatilitypercentage, Digits), NL,
                                      sIndicatorStatus,                                                                                                                                                                               NL,
                                      "AvgSpread: ", DoubleToStr(avgSpread, Digits), "    Unitsize: ", sUnitSize,                                                                                                                     NL);

      if (NormalizeDouble(avgSpread, Digits) > NormalizeDouble(MaxSpread * Point, Digits)) {
         sStatusInfo = StringConcatenate(sStatusInfo, "The current avg spread (", DoubleToStr(avgSpread, Digits), ") is higher than the configured MaxSpread (", DoubleToStr(MaxSpread*Point, Digits), ") => trading disabled", NL);
      }
   }
   return(catch("Trade(11)"));
}


/**
 * Magic Number - calculated from a sum of account number + ASCII-codes from currency pair
 *
 * @return int
 */
int CreateMagicNumber() {
   string values = "EURUSDJPYCHFCADAUDNZDGBP";
   string base   = StrLeft(Symbol(), 3);
   string quote  = StringSubstr(Symbol(), 3, 3);

   int basePos  = StringFind(values, base, 0);
   int quotePos = StringFind(values, quote, 0);

   int result = INT_MAX - AccountNumber() - basePos - quotePos;

   if (IsLogDebug()) logDebug("MagicNumber: "+ result);
   return(result);
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
      double slPips       = StopLoss*Point/Pip;                         // SL in pip
      double riskPerPip   = riskPerTrade/slPips;                        // risked equity amount per pip

      lots = NormalizeLots(riskPerPip/PipValue(), NULL, MODE_FLOOR);    // resulting normalized position size
      if (IsEmptyValue(lots)) return(NULL);

      if (checkLimits) {
         if (LT(lots, MarketInfo(Symbol(), MODE_MINLOT)))
            return(!catch("CalculateLots(2)  equity: "+ DoubleToStr(equity, 2) +" (resulting position size smaller than MODE_MINLOT)", ERR_NOT_ENOUGH_MONEY));

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

   if (NE(lots, lastLots)) {
      SS.UnitSize(lots);
      lastLots = lots;
   }
   return(lots);
}


/**
 * Update trade statistics.
 */
void UpdateTradeStats() {
   bool isTesting = IsTesting();

   openPositions  = 0;
   openLots       = 0;
   openSwap       = 0;
   openCommission = 0;
   openPl         = 0;

   int orders = OrdersTotal();
   for (int pos=0; pos < orders; pos++) {
      if (OrderSelect(pos, SELECT_BY_POS, MODE_TRADES)) {
         if (OrderType() > OP_SELL) continue;

         if (isTesting) {
            openPositions++;
            openLots       += ifDouble(OrderType()==OP_BUY, OrderLots(), -OrderLots());
            openSwap       += OrderSwap();
            openCommission += OrderCommission();
            openPl         += OrderProfit();
         }
         else if (OrderMagicNumber()==Magic) /*&&*/ if (OrderSymbol()==Symbol()) {
            openPositions++;
            openLots       += OrderLots();
            openSwap       += OrderSwap();
            openCommission += OrderCommission();
            openPl         += OrderProfit();
         }
      }
   }
   openPlNet = openSwap + openCommission + openPl;

   closedPositions  = 0;
   closedLots       = 0;
   closedSwap       = 0;
   closedCommission = 0;
   closedPl         = 0;

   orders = OrdersHistoryTotal();
   for (pos=0; pos < orders; pos++) {
      if (OrderSelect(pos, SELECT_BY_POS, MODE_HISTORY)) {
         if (OrderType() > OP_SELL) continue;

         if (isTesting) {
            closedPositions++;
            closedLots       += OrderLots();
            closedSwap       += OrderSwap();
            closedCommission += OrderCommission();
            closedPl         += OrderProfit();
         }
         else if (OrderMagicNumber()==Magic) /*&&*/ if (OrderSymbol()==Symbol()) {
            closedPositions++;
            closedLots       += OrderLots();
            closedSwap       += OrderSwap();
            closedCommission += OrderCommission();
            closedPl         += OrderProfit();
         }
      }
   }
   closedPlNet = closedSwap + closedCommission + closedPl;
   totalPlNet  = openPlNet + closedPlNet;
}


/**
 * Display the current runtime status.
 *
 * @param  int error [optional] - error to display (default: none)
 *
 * @return int - the same error or the current error status if no error was passed
 */
int ShowStatus(int error = NO_ERROR) {
   if (!IsChart()) return(error);

   string sError = "";
   if      (__STATUS_INVALID_INPUT) sError = StringConcatenate("  [",                 ErrorDescription(ERR_INVALID_INPUT_PARAMETER), "]");
   else if (__STATUS_OFF          ) sError = StringConcatenate("  [switched off => ", ErrorDescription(__STATUS_OFF.reason),         "]");

   string msg = StringConcatenate(ProgramName(), "              ", sError,                                                                                      NL,
                                                                                                                                                                NL,
                                  sStatusInfo,                                                                                           // contains linebreaks NL,
                                                                                                                                                                NL,
                                  "Open:      ", openPositions,   " positions    ", NumberToStr(openLots, ".+"),   " lots    PLn: ", DoubleToStr(openPlNet, 2), NL,
                                  "Closed:    ", closedPositions, " positions    ", NumberToStr(closedLots, ".+"), " lots    PLg: ", DoubleToStr(closedPl, 2), "    Commission: ", DoubleToStr(closedCommission, 2), "    Swap: ", DoubleToStr(closedSwap, 2), NL,
                                                                                                                                                                NL,
                                  "Total PL:  ", DoubleToStr(totalPlNet, 2),                                                                                    NL
   );

   // 3 lines margin-top for potential indicator legends
   Comment(NL, NL, NL, msg);
   if (__CoreFunction == CF_INIT) WindowRedraw();

   if (!catch("ShowStatus(1)"))
      return(error);
   return(last_error);
}


/**
 * ShowStatus: Update the string representation of the unitsize.
 *
 * @param  double size
 */
void SS.UnitSize(double size) {
   if (IsChart()) {
      sUnitSize = NumberToStr(size, ".+") +" lot";
   }
}
