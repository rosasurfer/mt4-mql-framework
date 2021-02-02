/**
 * XMT-Scalper revisited
 *
 *
 * This EA is originally based on the famous "MillionDollarPips EA". A member of the "www.worldwide-invest.org" forum known
 * as Capella transformed it to "XMT-Scalper". In his own words: "Nothing remains from the original except the core idea of
 * the strategy: scalping based on a reversal from a channel breakout." Today various versions circulate in the internet
 * going by different names (MDP-Plus, XMT, Assar). None is suitable for real trading. Main reasons are a very high price
 * feed sensitivity (especially the number of received ticks) and the unaccounted effects of slippage/commission. Moreover
 * test behavior differs from online behavior to such a large degree that testing is meaningless in general.
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
 *  - simplified input parameters
 *  - fixed input parameter validation
 *  - fixed position size calculation
 *  - fixed trading errors
 *  - rewrote status display
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
extern int    TimeFrame                 = PERIOD_M1;  // trading timeframe must match the timeframe of the chart
extern int    StopLoss                  = 60;         // SL in point
extern int    TakeProfit                = 100;        // TP in point
extern double TrailingStart             = 20;         // start trailing profit from as so many points.
extern int    StopDistance.Points       = 0;          // pending entry order distance in point (0 = market order)
extern int    Slippage.Points           = 3;          // acceptable market order slippage in point
extern double Commission                = 0;          // commission per lot
extern double MaxSpread                 = 30;         // max allowed spread in point
extern int    Magic                     = -1;         // if negative the MagicNumber is generated
extern bool   ReverseTrades             = false;      // if TRUE, then trade in opposite direction

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
string sStatusInfo = "\n\n\n\n";

// --- old ------------------------------------------------------------
int    UpTo30Counter = 0;        // for calculating average spread
double Array_spread[30];         // store spreads for the last 30 ticks
double highest;                  // lotSize indicator value
double lowest;                   // lowest indicator value


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
   ArrayInitialize ( Array_spread, 0 );
   VolatilityLimit = VolatilityLimit * Point;
   Commission = NormalizeDouble(Commission * Point, Digits);
   TrailingStart = TrailingStart * Point;
   stopDistance  = StopDistance.Points * Point;

   if (Magic < 0) Magic = CreateMagicNumber();

   UpdateTradeStats();
   return(catch("onInit(11)"));
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
 * pewa: Detect and track open/closed positions.
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
 * pewa: Handle PositionOpen events.
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
 * pewa: Handle PositionClose events.
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
 * pewa: Handle OrderDelete events.
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
 * pewa: Add a new order record.
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
 * pewa: Update the order record of the specified ticket.
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
 * pewa: Remove the order record with the specified ticket.
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
 * Main trading subroutine
 */
void Trade() {
   bool wasordermodified = false;
   bool isbidgreaterthanima = false;
   bool isbidgreaterthanibands = false;
   bool isbidgreaterthanenvelopes = false;
   bool isbidgreaterthanindy = false;

   int loopcount2;
   int loopcount1;
   int pricedirection;

   double volatilitypercentage = 0;
   double orderprice;
   double orderstoploss;
   double ordertakeprofit;
   double ihigh;
   double ilow;
   double imalow = 0;
   double imahigh = 0;
   double imadiff;
   double ibandsupper = 0;
   double ibandslower = 0;
   double ibandsdiff;
   double envelopesupper = 0;
   double envelopeslower = 0;
   double envelopesdiff;
   double volatility;
   double spread;
   double avgspread;
   double realavgspread;
   double fakeprice;
   double sumofspreads;
   double askpluscommission;
   double bidminuscommission;
   double skipticks;
   double am = 0.000000001;  // Set variable to a very small number
   double marginlevel;
   int oe[];

   // Calculate Margin level
   if (AccountMargin() != 0)
      am = AccountMargin();
   if (!am) return(catch("Trade(1)  am = 0", ERR_ZERO_DIVIDE));
   marginlevel = AccountEquity() / am * 100; // margin level in %

   if (marginlevel < 100) {
      Alert("Warning! Free Margin "+ DoubleToStr(marginlevel, 2) +" is lower than MinMarginLevel!");
      return(catch("Trade(2)"));
   }

   // Calculate the channel of Volatility based on the difference of iHigh and iLow during current bar
   ihigh = iHigh ( Symbol(), TimeFrame, 0 );
   ilow = iLow ( Symbol(), TimeFrame, 0 );
   volatility = ihigh - ilow;

   // Reset printout string
   string indy = "";

   // Calculate a channel on Moving Averages, and check if the price is outside of this channel.
   if (EntryIndicator == 1) {
      imalow = iMA ( Symbol(), TimeFrame, Indicatorperiod, 0, MODE_LWMA, PRICE_LOW, 0 );
      imahigh = iMA ( Symbol(), TimeFrame, Indicatorperiod, 0, MODE_LWMA, PRICE_HIGH, 0 );
      imadiff = imahigh - imalow;
      isbidgreaterthanima = Bid >= imalow + imadiff / 2.0;
      indy = "iMA_low: " + DoubleToStr(imalow, Digits) + ", iMA_high: " + DoubleToStr(imahigh, Digits) + ", iMA_diff: " + DoubleToStr(imadiff, Digits);
   }

   // Calculate a channel on BollingerBands, and check if the price is outside of this channel
   if (EntryIndicator == 2) {
      ibandsupper = iBands ( Symbol(), TimeFrame, Indicatorperiod, BBDeviation, 0, PRICE_OPEN, MODE_UPPER, 0 );
      ibandslower = iBands ( Symbol(), TimeFrame, Indicatorperiod, BBDeviation, 0, PRICE_OPEN, MODE_LOWER, 0 );
      ibandsdiff = ibandsupper - ibandslower;
      isbidgreaterthanibands = Bid >= ibandslower + ibandsdiff / 2.0;
      indy = "iBands_upper: " + DoubleToStr(ibandsupper, Digits) + ", iBands_lower: " + DoubleToStr(ibandslower, Digits) + ", iBands_diff: " + DoubleToStr(ibandsdiff, Digits);
   }

   // Calculate a channel on Envelopes, and check if the price is outside of this channel
   if (EntryIndicator == 3) {
      envelopesupper = iEnvelopes ( Symbol(), TimeFrame, Indicatorperiod, MODE_LWMA, 0, PRICE_OPEN, EnvelopesDeviation, MODE_UPPER, 0 );
      envelopeslower = iEnvelopes ( Symbol(), TimeFrame, Indicatorperiod, MODE_LWMA, 0, PRICE_OPEN, EnvelopesDeviation, MODE_LOWER, 0 );
      envelopesdiff = envelopesupper - envelopeslower;
      isbidgreaterthanenvelopes = Bid >= envelopeslower + envelopesdiff / 2.0;
      indy = "iEnvelopes_upper: " + DoubleToStr(envelopesupper, Digits) + ", iEnvelopes_lower: " + DoubleToStr(envelopeslower, Digits) + ", iEnvelopes_diff: " + DoubleToStr(envelopesdiff, Digits) ;
   }

   // Reset breakout variable as FALSE
   isbidgreaterthanindy = false;

   // Reset pricedirection for no indication of trading direction
   pricedirection = 0;

   // If we're using iMA as indicator, then set variables from it
   if (EntryIndicator==1 && isbidgreaterthanima) {
      isbidgreaterthanindy = true;
      highest = imahigh;
      lowest = imalow;
   }

   // If we're using iBands as indicator, then set variables from it
   else if (EntryIndicator==2 && isbidgreaterthanibands) {
      isbidgreaterthanindy = true;
      highest = ibandsupper;
      lowest = ibandslower;
   }

   // If we're using iEnvelopes as indicator, then set variables from it
   else if (EntryIndicator==3 && isbidgreaterthanenvelopes) {
      isbidgreaterthanindy = true;
      highest = envelopesupper;
      lowest = envelopeslower;
   }

   spread = Ask - Bid;

   // calculate average spread of the last 30 ticks
   ArrayCopy(Array_spread, Array_spread, 0, 1, 29);
   Array_spread[29] = spread;
   if (UpTo30Counter < 30) UpTo30Counter++;
   sumofspreads = 0;
   loopcount2 = 29;
   for (loopcount1=0; loopcount1 < UpTo30Counter; loopcount1++) {
      sumofspreads += Array_spread[loopcount2];
      loopcount2 --;
   }
   if (!UpTo30Counter) return(catch("Trade(3)  UpTo30Counter = 0", ERR_ZERO_DIVIDE));
   avgspread = sumofspreads / UpTo30Counter;

   // Calculate price and spread considering commission
   askpluscommission  = NormalizeDouble(Ask + Commission, Digits);
   bidminuscommission = NormalizeDouble(Bid - Commission, Digits);
   realavgspread      = avgspread + Commission;

   // Recalculate the VolatilityLimit if it's set to dynamic. It's based on the average of spreads multiplied with the VolatilityMulitplier constant
   if (UseDynamicVolatilityLimit)
      VolatilityLimit = realavgspread * VolatilityMultiplier;

   // If the variables below have values it means that we have enough of data from broker server.
   if (volatility && VolatilityLimit && lowest && highest) {
      // We have a price breakout, as the Volatility is outside of the VolatilityLimit, so we can now open a trade
      if (volatility > VolatilityLimit) {
         // Calculate how much it differs
         if (!VolatilityLimit) return(catch("Trade(4)  VolatilityLimit = 0", ERR_ZERO_DIVIDE));
         volatilitypercentage = volatility / VolatilityLimit;

         // check if it differ enough from the specified limit
         if (volatilitypercentage > VolatilityPercentageLimit) {
            if (Bid < lowest) {
               pricedirection = ifInt(ReverseTrades, 1, -1);   // -1=Long, 1=Short
            }
            else if (Bid > highest) {
               pricedirection = ifInt(ReverseTrades, -1, 1);   // -1=Long, 1=Short
            }
         }
      }
      else {
         // The Volatility is less than the VolatilityLimit so we set the volatilitypercentage to zero
         volatilitypercentage = 0;
      }
   }

   // Check for out of money
   if (AccountEquity() <= 0) {
      Alert("ERROR: AccountEquity = "+ DoubleToStr(AccountEquity(), 2));
      return(catch("Trade(5)"));
   }

   bool isOpenOrder = false;

   // Loop through all open orders to either modify or to delete them
   for (int i=0; i < OrdersTotal(); i++) {
      OrderSelect(i, SELECT_BY_POS, MODE_TRADES);

      if (OrderMagicNumber()==Magic && OrderSymbol()==Symbol()) {
         isOpenOrder = true;
         RefreshRates();

         switch (OrderType()) {
            case OP_BUY:
               // Modify the order if its TP is less than the price+commission+StopLevel AND the TrailingStart condition is satisfied
               ordertakeprofit = OrderTakeProfit();

               if (ordertakeprofit < NormalizeDouble(askpluscommission + TakeProfit*Point, Digits) && askpluscommission + TakeProfit*Point - ordertakeprofit > TrailingStart) {
                  orderstoploss   = NormalizeDouble(Bid - StopLoss*Point, Digits);
                  ordertakeprofit = NormalizeDouble(askpluscommission + TakeProfit*Point, Digits);

                  if (NE(orderstoploss, OrderStopLoss()) || NE(ordertakeprofit, OrderTakeProfit())) {
                     if (!OrderModifyEx(OrderTicket(), NULL, orderstoploss, ordertakeprofit, NULL, Lime, NULL, oe)) return(catch("Trade(6)"));
                  }
               }
               break;

            case OP_SELL:
               // Modify the order if its TP is greater than price-commission-StopLevel AND the TrailingStart condition is satisfied
               ordertakeprofit = OrderTakeProfit();

               if (ordertakeprofit > NormalizeDouble(bidminuscommission - TakeProfit*Point, Digits) && ordertakeprofit - bidminuscommission + TakeProfit*Point > TrailingStart) {
                  orderstoploss   = NormalizeDouble(Ask + StopLoss*Point, Digits);
                  ordertakeprofit = NormalizeDouble(bidminuscommission - TakeProfit*Point, Digits);

                  if (NE(orderstoploss, OrderStopLoss()) || NE(ordertakeprofit, OrderTakeProfit())) {
                     if (!OrderModifyEx(OrderTicket(), NULL, orderstoploss, ordertakeprofit, NULL, Orange, NULL, oe)) return(catch("Trade(7)"));
                  }
               }
               break;

            case OP_BUYSTOP:
               // Price must NOT be larger than indicator in order to modify the order, otherwise the order will be deleted
               if (!isbidgreaterthanindy) {
                  // Calculate how much Price, SL and TP should be modified
                  orderprice      = NormalizeDouble(Ask + stopDistance, Digits);
                  orderstoploss   = NormalizeDouble(orderprice - spread - StopLoss * Point, Digits);
                  ordertakeprofit = NormalizeDouble(orderprice + Commission + TakeProfit * Point, Digits);
                  // Start endless loop
                  while (true) {
                     // Ok to modify the order if price+StopLevel is less than orderprice AND orderprice-price-StopLevel is greater than trailingstart
                     if ( orderprice < OrderOpenPrice() && OrderOpenPrice() - orderprice > TrailingStart )
                     {

                        // Send an OrderModify command with adjusted Price, SL and TP
                        if (orderstoploss!=OrderStopLoss() && ordertakeprofit!=OrderTakeProfit()) {
                           if (!OrderModifyEx(OrderTicket(), orderprice, orderstoploss, ordertakeprofit, NULL, Lime, NULL, oe)) return(catch("Trade(8)"));
                           wasordermodified = true;
                        }
                        if (wasordermodified) {
                           Orders.UpdateTicket(OrderTicket(), OrderType(), orderprice, OP_UNDEFINED, OrderCloseTime());
                        }
                     }
                     break;
                  }
               }
               else {
                  if (!OrderDeleteEx(OrderTicket(), CLR_NONE, NULL, oe)) return(catch("Trade(9)"));
                  Orders.RemoveTicket(OrderTicket());
                  isOpenOrder = false;
               }
               break;

         case OP_SELLSTOP:
            // Price must be larger than the indicator in order to modify the order, otherwise the order will be deleted
            if (isbidgreaterthanindy) {
               // Calculate how much Price, SL and TP should be modified
               orderprice      = NormalizeDouble(Bid - stopDistance, Digits);
               orderstoploss   = NormalizeDouble(orderprice + spread + StopLoss * Point, Digits);
               ordertakeprofit = NormalizeDouble(orderprice - Commission - TakeProfit * Point, Digits);
               // Endless loop
               while (true) {
                  // Ok to modify order if price-StopLevel is greater than orderprice AND price-StopLevel-orderprice is greater than trailingstart
                  if ( orderprice > OrderOpenPrice() && orderprice - OrderOpenPrice() > TrailingStart)
                  {
                     // Send an OrderModify command with adjusted Price, SL and TP
                     if (orderstoploss!=OrderStopLoss() && ordertakeprofit!=OrderTakeProfit()) {
                        if (!OrderModifyEx(OrderTicket(), orderprice, orderstoploss, ordertakeprofit, NULL, Orange, NULL, oe)) return(catch("Trade(10)"));
                        wasordermodified = true;
                     }
                     if (wasordermodified) {
                        Orders.UpdateTicket(OrderTicket(), OrderType(), orderprice, OP_UNDEFINED, OrderCloseTime());
                     }
                  }
                  break;
               }
            }
            else {
               if (!OrderDeleteEx(OrderTicket(), CLR_NONE, NULL, oe)) return(catch("Trade(11)"));
               Orders.RemoveTicket(OrderTicket());
               isOpenOrder = false;
            }
            break;
         }
      }
   }


   // Open a new order if we have no open orders AND a price breakout AND average spread is less or equal to max allowed spread
   if (!isOpenOrder && pricedirection && NormalizeDouble(realavgspread, Digits) <= NormalizeDouble(MaxSpread * Point, Digits)) {
      double lots = CalculateLots(true); if (!lots) return(last_error);

      if (pricedirection==-1 || pricedirection==2 ) {
         orderprice      = Ask + stopDistance;
         orderstoploss   = NormalizeDouble(orderprice - spread - StopLoss*Point, Digits);
         ordertakeprofit = NormalizeDouble(orderprice + TakeProfit*Point, Digits);

         if (GT(stopDistance, 0) || IsTesting()) {
            if (!OrderSendEx(Symbol(), OP_BUYSTOP, lots, orderprice, NULL, orderstoploss, ordertakeprofit, orderComment, Magic, NULL, Lime, NULL, oe)) return(catch("Trade(12)"));
            Orders.AddTicket(oe.Ticket(oe), OP_BUYSTOP, oe.OpenPrice(oe), OP_UNDEFINED, NULL);
         }
         else {
            if (!OrderSendEx(Symbol(), OP_BUY, lots, NULL, Slippage.Points, orderstoploss, ordertakeprofit, orderComment, Magic, NULL, Lime, NULL, oe)) return(catch("Trade(13)"));
            Orders.AddTicket(oe.Ticket(oe), OP_UNDEFINED, NULL, OP_BUY, NULL);
         }
      }
      if (pricedirection==1 || pricedirection==2) {
         orderprice      = Bid - stopDistance;
         orderstoploss   = NormalizeDouble(orderprice + spread + StopLoss*Point, Digits);
         ordertakeprofit = NormalizeDouble(orderprice - TakeProfit*Point, Digits);

         if (GT(stopDistance, 0) || IsTesting()) {
            if (!OrderSendEx(Symbol(), OP_SELLSTOP, lots, orderprice, NULL, orderstoploss, ordertakeprofit, orderComment, Magic, NULL, Orange, NULL, oe)) return(catch("Trade(14)"));
            Orders.AddTicket(oe.Ticket(oe), OP_SELLSTOP, oe.OpenPrice(oe), OP_UNDEFINED, NULL);
         }
         else {
            if (!OrderSendEx(Symbol(), OP_SELL, lots, NULL, Slippage.Points, orderstoploss, ordertakeprofit, orderComment, Magic, NULL, Orange, NULL, oe)) return(catch("Trade(15)"));
            Orders.AddTicket(oe.Ticket(oe), OP_UNDEFINED, NULL, OP_SELL, NULL);
         }
      }
   }

   // compose chart status messages
   if (IsChart()) {
      sStatusInfo = StringConcatenate("Volatility: ", DoubleToStr(volatility, Digits), "    VolatilityLimit: ", DoubleToStr(VolatilityLimit, Digits), "    VolatilityPercentage: ", DoubleToStr(volatilitypercentage, Digits), NL,
                                      "PriceDirection: ", StringSubstr("BUY NULLSELLBOTH", 4*pricedirection + 4, 4),                                                                                                           NL,
                                      indy,                                                                                                                                                                                    NL,
                                      "AvgSpread: ", DoubleToStr(avgspread, Digits), "    RealAvgSpread: ", DoubleToStr(realavgspread, Digits), "    Unitsize: ", sUnitSize,                                                   NL);

      if (NormalizeDouble(realavgspread, Digits) > NormalizeDouble(MaxSpread * Point, Digits)) {
         sStatusInfo = StringConcatenate(sStatusInfo, "The current avg spread (", DoubleToStr(realavgspread, Digits), ") is higher than the configured MaxSpread (", DoubleToStr(MaxSpread*Point, Digits), ") => trading disabled", NL);
      }
   }

   return(catch("Trade(16)"));
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
         if (isTesting) {
            openPositions++;
            openLots       += OrderLots();
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
