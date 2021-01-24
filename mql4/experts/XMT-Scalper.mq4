/**
 * XMT-Scalper revisited
 *
 *
 * This EA is originally based on the famous "MillionDollarPips EA". Credits for the initial transformation from MDP to
 * XMT-Scalper go to a Swedish guy named Capella. In his own words: "Nothing remains from the original except the core idea of
 * the strategy: scalping based on a reversal from a channel breakout."
 *
 * Today various versions of his EA circulate in the internet by various names (MDP-Plus, XMT, Assar). None of them is suitable
 * for trading real money. Main reasons are a very high datafeed sensitivity (especially the number of received ticks) and the
 * unaccounted effects of slippage and commissions. Moreover the EA produces completely different results in tester and online
 * accounts. Profitable parameters found in tester can't be applied to online trading.
 *
 * This version is again a complete rewrite.
 *
 * Sources:
 *  @origin XMT-Scalper v2.522
 *  @link   https://github.com/rosasurfer/mt4-mql/blob/a1b22d0/mql4/experts/mdp#            [MillionDollarPips v2 decompiled]
 *  @link   https://github.com/rosasurfer/mt4-mql/blob/36f494e/mql4/experts/mdp#             [MDP-Plus v2.2 + PDF by Capella]
 *  @link   https://github.com/rosasurfer/mt4-mql/blob/41237e0/mql4/experts/mdp#        [XMT-Scalper v2.522 + PDF by Capella]
 *
 *
 * Changes:
 *  - removed MQL5 syntax and fixed compiler issues
 *  - added rosasurfer framework
 *  - repositioned chart objects, fixed chart object errors and removed status display configuration
 *  - moved Print() output to the framework logger
 *  - removed needless functions and variables
 *  - removed obsolete order expiration, NDD and screenshot functionality
 *  - removed obsolete sending of fake orders and measuring of execution times
 *  - removed configuration of the min. margin level
 *  - added monitoring of PositionOpen and PositionClose events
 *  - added the framework's test reporting
 *
 *  - renamed and reordered input parameters, removed needless ones
 */
#include <stddefines.mqh>
int   __InitFlags[] = {INIT_TIMEZONE, INIT_BUFFERED_LOG};
int __DeinitFlags[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern string ___a_____________________ = "=== Entry indicator: 1=MovingAverage, 2=BollingerBands, 3=Envelopes";
extern int    EntryIndicator            = 1;          // entry signal indicator for price channel calculation
extern int    Indicatorperiod           = 3;          // period in bars for indicator
extern double BBDeviation               = 2;          // deviation for the iBands indicator
extern double EnvelopesDeviation        = 0.07;       // deviation for the iEnvelopes indicator

extern string ___b_____________________ = "==== MinBarSize settings ====";
extern bool   UseDynamicVolatilityLimit = true;       // calculated based on (int)(spread * VolatilityMultiplier)
extern double VolatilityMultiplier      = 125;        // a multiplier that is used if UseDynamicVolatilityLimit is TRUE
extern double VolatilityLimit           = 180;        // a fix value that is used if UseDynamicVolatilityLimit is FALSE
extern double VolatilityPercentageLimit = 0;          // percentage of how much iHigh-iLow difference must differ from VolatilityLimit

extern string ___c_____________________ = "==== Trade settings ====";
extern int    TimeFrame                 = PERIOD_M1;  // trading timeframe must match the timeframe of the chart
extern double StopLoss                  = 60;         // SL from as many points. Default 60 (= 6 pips)
extern double TakeProfit                = 100;        // TP from as many points. Default 100 (= 10 pip)
extern double AddPriceGap               = 0;          // additional price gap in points added to SL and TP in order to avoid Error 130
extern double TrailingStart             = 20;         // start trailing profit from as so many points.
extern double MinimumUseStopLevel       = 0;          // stoplevel to use will be max value of either this value or broker stoplevel
extern int    Slippage                  = 3;          // maximum allowed Slippage of price in points
extern double Commission                = 0;          // some broker accounts charge commission in USD per 1.0 lot. Commission in dollar per lot
extern double MaxSpread                 = 30;         // max allowed spread in points (1/10 pip)
extern int    Magic                     = -1;         // if negative the MagicNumber is generated
extern bool   ReverseTrades             = false;      // if TRUE, then trade in opposite direction

extern string ___d_____________________ = "==== MoneyManagement ====";
extern bool   MoneyManagement           = true;       // if TRUE lotsize is calculated based on "Risk", if FALSE use "ManualLotsize"
extern double Risk                      = 2;          // risk setting in percentage, for equity=10'000, risk=10% and stoploss=60: lotsize = 16.66
extern double MinLots                   = 0.01;       // minimum lotsize to use
extern double MaxLots                   = 100;        // maximum lotsize to use
extern double ManualLotsize             = 0.1;        // fix lotsize to use if "MoneyManagement" is FALSE

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/expert.mqh>
#include <stdfunctions.mqh>
#include <rsfLibs.mqh>


int      GlobalError = 0;        // to keep track on number of added errors
int      UpTo30Counter = 0;      // for calculating average spread
int      Tot_closed_pos;         // number of closed positions for this EA
int      Tot_open_pos;           // number of open positions for this EA
double   Tot_open_profit;        // a summary of the current open profit/loss for this EA
double   Tot_open_lots;          // a summary of the current open lots for this EA
double   Tot_open_swap;          // a summary of the current charged swaps of the open positions for this EA
double   Tot_open_commission;    // a summary of the currebt charged commission of the open positions for this EA
double   G_equity;               // current equity for this EA
double   Tot_closed_lots;        // a summary of the current closed lots for this EA
double   Tot_closed_profit;      // a summary of the current closed profit/loss for this EA
double   Tot_closed_swap;        // a summary of the current closed swaps for this EA
double   Tot_closed_comm;        // a summary of the current closed commission for this EA
double   G_balance = 0;          // balance for this EA
double   Array_spread[30];       // store spreads for the last 30 ticks
double   LotSize;                // lotsize
double   highest;                // lotSize indicator value
double   lowest;                 // lowest indicator value
double   StopLevel;              // broker StopLevel

string   orderComment = "XMT-rsf";


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   // If we don't run a backtest
   if (!IsTesting()) {
   // Check if timeframe of chart matches timeframe of external setting
      if ( Period() != TimeFrame )
      {
         // The setting of timefram,e does not match the chart tiomeframe, so alert of this and exit
         Alert ("The EA has been set to run on timeframe: ", TimeFrame, " but it has been attached to a chart with timeframe: ", Period() );
      }
   }

   // Reset error variable
   GlobalError = -1;

   // Calculate StopLevel as max of either STOPLEVEL or FREEZELEVEL
   StopLevel = MathMax ( MarketInfo ( Symbol(), MODE_FREEZELEVEL ), MarketInfo ( Symbol(), MODE_STOPLEVEL ) );
   // Then calculate the StopLevel as max of either this StopLevel or MinimumUseStopLevel
   StopLevel = MathMax ( MinimumUseStopLevel, StopLevel );

   // Check to confirm that indicator switch is valid choices, if not force to 1 (Moving Average)
   if (EntryIndicator < 1 || EntryIndicator > 3)
      EntryIndicator = 1;

   // Adjust SL and TP to broker StopLevel if they are less than this StopLevel
   StopLoss = MathMax ( StopLoss, StopLevel );
   TakeProfit = MathMax ( TakeProfit, StopLevel );

   // Re-calculate variables
   VolatilityPercentageLimit = VolatilityPercentageLimit / 100 + 1;
   VolatilityMultiplier = VolatilityMultiplier / 10;
   ArrayInitialize ( Array_spread, 0 );
   VolatilityLimit = VolatilityLimit * Point;
   Commission = NormalizeDouble(Commission * Point, Digits);
   TrailingStart = TrailingStart * Point;
   StopLevel = StopLevel * Point;
   AddPriceGap = AddPriceGap * Point;

   // If we have set MaxLot and/or MinLots to more/less than what the broker allows, then adjust accordingly
   if (MinLots < MarketInfo(Symbol(), MODE_MINLOT)) MinLots = MarketInfo(Symbol(), MODE_MINLOT);
   if (MaxLots > MarketInfo(Symbol(), MODE_MAXLOT)) MaxLots = MarketInfo(Symbol(), MODE_MAXLOT);
   if (MaxLots < MinLots) MaxLots = MinLots;

   // Also make sure that if the risk-percentage is too low or too high, that it's adjusted accordingly
   RecalculateWrongRisk();

   // Calculate intitial LotSize
   LotSize = CalculateLotsize();

   // If magic number is set to a value less than 0, then calculate MagicNumber automatically
   if ( Magic < 0 )
     Magic = CreateMagicNumber();

   // Check through all closed and open orders to get stats
   CheckClosedOrders();
   CheckOpenOrders();

   ShowGraphInfo();

   return(catch("onInit(1)"));
}


/**
 * Deinitialization
 *
 * @return int - error status
 */
int onDeinit() {
   CheckClosedOrders();
   return(catch("onDeinit(1)"));
}


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   if (iBars(Symbol(), TimeFrame) <= Indicatorperiod) {
      Print("Please wait until enough of bar data has been gathered!");
   }
   else {
      UpdateOrderStatus();          // pewa: detect and track open/closed positions

      Trade();                      // Call the actual main subroutine
      CheckClosedOrders();          // Check all closed and open orders to get stats
      CheckOpenOrders();
      ShowGraphInfo();
   }
   return(catch("onTick(1)"));
}


// pewa: order management
int      tickets      [];
int      pendingTypes [];
double   pendingPrices[];
int      types        [];
datetime closeTimes   [];


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
   string textstring;
   string pair;

   bool wasordermodified = false;
   bool ordersenderror = false;
   bool isbidgreaterthanima = false;
   bool isbidgreaterthanibands = false;
   bool isbidgreaterthanenvelopes = false;
   bool isbidgreaterthanindy = false;

   int orderticket;
   int loopcount2;
   int loopcount1;
   int pricedirection;
   int counter1;
   int counter2;
   int askpart;
   int bidpart;

   double ask;
   double bid;
   double askplusdistance;
   double bidminusdistance;
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
   if ( AccountMargin() != 0 )
      am = AccountMargin();
   marginlevel = AccountEquity() / am * 100; // margin level in %

   if (marginlevel < 100) {
      Alert("Warning! Free Margin "+ DoubleToStr(marginlevel, 2) +" is lower than MinMarginLevel!");
      return(catch("Trade(1)"));
   }

   // Get Ask and Bid for the currency
   bid = Bid;
   ask = Ask;

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
      isbidgreaterthanima = bid >= imalow + imadiff / 2.0;
      indy = "iMA_low: " + DoubleToStr(imalow, Digits) + ", iMA_high: " + DoubleToStr(imahigh, Digits) + ", iMA_diff: " + DoubleToStr(imadiff, Digits);
   }

   // Calculate a channel on BollingerBands, and check if the price is outside of this channel
   if (EntryIndicator == 2) {
      ibandsupper = iBands ( Symbol(), TimeFrame, Indicatorperiod, BBDeviation, 0, PRICE_OPEN, MODE_UPPER, 0 );
      ibandslower = iBands ( Symbol(), TimeFrame, Indicatorperiod, BBDeviation, 0, PRICE_OPEN, MODE_LOWER, 0 );
      ibandsdiff = ibandsupper - ibandslower;
      isbidgreaterthanibands = bid >= ibandslower + ibandsdiff / 2.0;
      indy = "iBands_upper: " + DoubleToStr(ibandsupper, Digits) + ", iBands_lower: " + DoubleToStr(ibandslower, Digits) + ", iBands_diff: " + DoubleToStr(ibandsdiff, Digits);
   }

   // Calculate a channel on Envelopes, and check if the price is outside of this channel
   if (EntryIndicator == 3) {
      envelopesupper = iEnvelopes ( Symbol(), TimeFrame, Indicatorperiod, MODE_LWMA, 0, PRICE_OPEN, EnvelopesDeviation, MODE_UPPER, 0 );
      envelopeslower = iEnvelopes ( Symbol(), TimeFrame, Indicatorperiod, MODE_LWMA, 0, PRICE_OPEN, EnvelopesDeviation, MODE_LOWER, 0 );
      envelopesdiff = envelopesupper - envelopeslower;
      isbidgreaterthanenvelopes = bid >= envelopeslower + envelopesdiff / 2.0;
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

   // Calculate spread
   spread = ask - bid;

   // Calculate lot size
   LotSize = CalculateLotsize();

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
   avgspread = sumofspreads / UpTo30Counter;

   // Calculate price and spread considering commission
   askpluscommission = NormalizeDouble(ask + Commission, Digits);
   bidminuscommission = NormalizeDouble(bid - Commission, Digits);
   realavgspread = avgspread + Commission;

   // Recalculate the VolatilityLimit if it's set to dynamic. It's based on the average of spreads multiplied with the VolatilityMulitplier constant
   if (UseDynamicVolatilityLimit)
      VolatilityLimit = realavgspread * VolatilityMultiplier;

   // If the variables below have values it means that we have enough of data from broker server.
   if (volatility && VolatilityLimit && lowest && highest) {
      // We have a price breakout, as the Volatility is outside of the VolatilityLimit, so we can now open a trade
      if (volatility > VolatilityLimit) {
         // Calculate how much it differs
         volatilitypercentage = volatility / VolatilityLimit;

         // check if it differ enough from the specified limit
         if (volatilitypercentage > VolatilityPercentageLimit) {
            if (bid < lowest) {
               pricedirection = ifInt(ReverseTrades, 1, -1);   // -1=Long, 1=Short
            }
            else if (bid > highest) {
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
      return(catch("Trade(2)"));
   }

   // Reset counters
   counter1 = 0;
   counter2 = 0;

   // Loop through all open orders (if any) to either modify them or delete them
   for ( loopcount2 = 0; loopcount2 < OrdersTotal(); loopcount2 ++ )
   {
      // Select an order from the open orders
      OrderSelect ( loopcount2, SELECT_BY_POS, MODE_TRADES );
      // We've found an that matches the magic number and is open
      if ( OrderMagicNumber() == Magic && OrderCloseTime() == 0 )
      {
         // If the order doesn't match the currency pair from the chart then check next open order
         if ( OrderSymbol() != Symbol() )
         {
            // Increase counter
            counter2 ++;
            continue;
         }
         // Select order by type of order
         switch ( OrderType() )
         {
         // We've found a matching BUY-order
         case OP_BUY:
            // Start endless loop
            while (true) {
               // Update prices from the broker
               RefreshRates();
               // Set SL and TP
               orderstoploss = OrderStopLoss();
               ordertakeprofit = OrderTakeProfit();
               // Ok to modify the order if its TP is less than the price+commission+StopLevel AND price+StopLevel-TP greater than trailingStart
               if ( ordertakeprofit < NormalizeDouble(askpluscommission + TakeProfit * Point + AddPriceGap, Digits) && askpluscommission + TakeProfit * Point + AddPriceGap - ordertakeprofit > TrailingStart )
               {
                  // Set SL and TP
                  orderstoploss = NormalizeDouble(bid - StopLoss * Point - AddPriceGap, Digits);
                  ordertakeprofit = NormalizeDouble(askpluscommission + TakeProfit * Point + AddPriceGap, Digits);
                  // Send an OrderModify command with adjusted SL and TP
                  if ( orderstoploss != OrderStopLoss() && ordertakeprofit != OrderTakeProfit() )
                  {
                     // Try to modify order
                     wasordermodified = OrderModifyEx(OrderTicket(), NULL, orderstoploss, ordertakeprofit, NULL, Lime, NULL, oe);
                  }
                  // Order was modified with new SL and TP
                  if (wasordermodified) {
                     // Break out from while-loop since the order now has been modified
                     break;
                  }
                  // Order was not modified
                  else {
                     logWarn("Order could not be modified", GetLastError());

                     // Order has not been modified and it has no StopLoss
                     if (!orderstoploss) {
                        // Try to modify order with a safe hard SL that is 3 pip from current price
                        wasordermodified = OrderModifyEx(OrderTicket(), NULL, Bid-30, NULL, NULL, Red, NULL, oe);
                        return(catch("Trade(3)  invalid SL: "+ NumberToStr(Bid-30, ".+"), ERR_RUNTIME_ERROR));
                     }
                  }
               }
               // Break out from while-loop since the order now has been modified
               break;
            }
            // count 1 more up
            counter1 ++;
            // Break out from switch
            break;

         // We've found a matching SELL-order
         case OP_SELL:
            // Start endless loop
            while (true) {
               // Update broker prices
               RefreshRates();
               // Set SL and TP
               orderstoploss = OrderStopLoss();
               ordertakeprofit = OrderTakeProfit();
               // Ok to modify the order if its TP is greater than price-commission-StopLevel AND TP-price-commission+StopLevel is greater than trailingstart
               if ( ordertakeprofit > NormalizeDouble(bidminuscommission - TakeProfit * Point - AddPriceGap, Digits) && ordertakeprofit - bidminuscommission + TakeProfit * Point - AddPriceGap > TrailingStart )
               {
                  // set SL and TP
                  orderstoploss = NormalizeDouble(ask + StopLoss * Point + AddPriceGap, Digits);
                  ordertakeprofit = NormalizeDouble( bidminuscommission - TakeProfit * Point - AddPriceGap, Digits);
                  // Send an OrderModify command with adjusted SL and TP
                  if ( orderstoploss != OrderStopLoss() && ordertakeprofit != OrderTakeProfit() )
                  {
                     wasordermodified = OrderModifyEx(OrderTicket(), NULL, orderstoploss, ordertakeprofit, NULL, Orange, NULL, oe);
                  }
                  // Order was modiified with new SL and TP
                  if (wasordermodified) {
                     // Break out from while-loop since the order now has been modified
                     break;
                  }
                  // Order was not modified
                  else {
                     logWarn("Order could not be modified", GetLastError());
                     // Lets wait 1 second before we try to modify the order again
                     Sleep ( 1000 );

                     // Order has not been modified and it has no StopLoss
                     if (!orderstoploss) {
                        // Try to modify order with a safe hard SL that is 3 pip from current price
                        wasordermodified = OrderModifyEx(OrderTicket(), NULL, Ask+30, NULL, NULL, Red, NULL, oe);
                        return(catch("Trade(4)  invalid SL: "+ NumberToStr(Ask+30, ".+"), ERR_RUNTIME_ERROR));
                     }
                  }
               }
               // Break out from while-loop since the order now has been modified
               break;
            }
            // count 1 more up
            counter1 ++;
            // Break out from switch
            break;

         // We've found a matching BUYSTOP-order
         case OP_BUYSTOP:
            // Price must NOT be larger than indicator in order to modify the order, otherwise the order will be deleted
            if (!isbidgreaterthanindy) {
               // Calculate how much Price, SL and TP should be modified
               orderprice = NormalizeDouble( ask + StopLevel + AddPriceGap, Digits);
               orderstoploss = NormalizeDouble( orderprice - spread - StopLoss * Point - AddPriceGap, Digits);
               ordertakeprofit = NormalizeDouble(orderprice + Commission + TakeProfit * Point + AddPriceGap, Digits);
               // Start endless loop
               while (true) {
                  // Ok to modify the order if price+StopLevel is less than orderprice AND orderprice-price-StopLevel is greater than trailingstart
                  if ( orderprice < OrderOpenPrice() && OrderOpenPrice() - orderprice > TrailingStart )
                  {

                     // Send an OrderModify command with adjusted Price, SL and TP
                     if (orderstoploss!=OrderStopLoss() && ordertakeprofit!=OrderTakeProfit()) {
                        RefreshRates();
                        wasordermodified = OrderModifyEx(OrderTicket(), orderprice, orderstoploss, ordertakeprofit, NULL, Lime, NULL, oe);
                     }
                     if (wasordermodified) {
                        Orders.UpdateTicket(OrderTicket(), OrderType(), orderprice, OP_UNDEFINED, OrderCloseTime());
                     }
                  }
                  // Break out from endless loop
                  break;
               }
               // Increase counter
               counter1 ++;
            }
            // Price was larger than the indicator
            else {
               OrderDeleteEx(OrderTicket(), CLR_NONE, NULL, oe);
               Orders.RemoveTicket(OrderTicket());
            }
            // Break out from switch
            break;

         // We've found a matching SELLSTOP-order
         case OP_SELLSTOP:
            // Price must be larger than the indicator in order to modify the order, otherwise the order will be deleted
            if (isbidgreaterthanindy) {
               // Calculate how much Price, SL and TP should be modified
               orderprice = NormalizeDouble(bid - StopLevel - AddPriceGap, Digits);
               orderstoploss = NormalizeDouble(orderprice + spread + StopLoss * Point + AddPriceGap, Digits);
               ordertakeprofit = NormalizeDouble(orderprice - Commission - TakeProfit * Point - AddPriceGap, Digits);
               // Endless loop
               while (true) {
                  // Ok to modify order if price-StopLevel is greater than orderprice AND price-StopLevel-orderprice is greater than trailingstart
                  if ( orderprice > OrderOpenPrice() && orderprice - OrderOpenPrice() > TrailingStart)
                  {
                     // Send an OrderModify command with adjusted Price, SL and TP
                     if ( orderstoploss != OrderStopLoss() && ordertakeprofit != OrderTakeProfit() )
                     {
                        RefreshRates();
                        wasordermodified = OrderModifyEx(OrderTicket(), orderprice, orderstoploss, ordertakeprofit, NULL, Orange, NULL, oe);
                     }
                     if (wasordermodified) {
                        Orders.UpdateTicket(OrderTicket(), OrderType(), orderprice, OP_UNDEFINED, OrderCloseTime());
                     }
                  }
                  // Break out from endless loop
                  break;
               }
               counter1++;
            }
            // Price was NOT larger than the indicator, so delete the order
            else {
               OrderDeleteEx(OrderTicket(), CLR_NONE, NULL, oe);
               Orders.RemoveTicket(OrderTicket());
            }
         } // end of switch
      }  // end if OrderMagicNumber
   } // end for loopcount2 - end of loop through open orders

   // Calculate and keep track on global error number
   if ( GlobalError >= 0 || GlobalError == -2 )
   {
      bidpart = NormalizeDouble ( bid / Point, 0 );
      askpart = NormalizeDouble ( ask / Point, 0 );
      if ( bidpart % 10 != 0 || askpart % 10 != 0 )
         GlobalError = -1;
      else
      {
         if ( GlobalError >= 0 && GlobalError < 10 )
            GlobalError ++;
         else
            GlobalError = -2;
      }
   }

   // Reset error-variable
   ordersenderror = false;

   // Set default price adjustment
   askplusdistance = ask + StopLevel;
   bidminusdistance = bid - StopLevel;

   // If we have no open orders AND a price breakout AND average spread is less or equal to max allowed spread AND we have no errors THEN proceed
   if (!counter1 && pricedirection && NormalizeDouble(realavgspread, Digits) <= NormalizeDouble(MaxSpread * Point, Digits) && GlobalError == -1) {
      // If we have a price breakout downwards (Bearish) then send a BUYSTOP order
      if ( pricedirection == -1 || pricedirection == 2 ) // Send a BUYSTOP
      {
         // Calculate a new price to use
         orderprice = ask + StopLevel;

         RefreshRates();
         // Set prices for BUYSTOP order
         orderprice = askplusdistance;//ask+StopLevel
         orderstoploss =  NormalizeDouble(orderprice - spread - StopLoss * Point - AddPriceGap, Digits);
         ordertakeprofit = NormalizeDouble(orderprice + TakeProfit * Point + AddPriceGap, Digits);
         // Send a BUYSTOP order with SL and TP
         orderticket = OrderSendEx(Symbol(), OP_BUYSTOP, LotSize, orderprice, Slippage, orderstoploss, ordertakeprofit, orderComment, Magic, NULL, Lime, NULL, oe);

         if (orderticket > 0) {
            Orders.AddTicket(orderticket, OP_BUYSTOP, orderprice, OP_UNDEFINED, NULL);
         }
         else {
            ordersenderror = true;
         }
      }

      // If we have a price breakout upwards (Bullish) then send a SELLSTOP order
      if ( pricedirection == 1 || pricedirection == 2 )
      {
         // Set prices for SELLSTOP order with zero SL and TP
         orderprice = bidminusdistance;
         orderstoploss = 0;
         ordertakeprofit = 0;

         RefreshRates();
         // Set prices for SELLSTOP order with SL and TP
         orderprice = bidminusdistance;
         orderstoploss = NormalizeDouble(orderprice + spread + StopLoss * Point + AddPriceGap, Digits);
         ordertakeprofit = NormalizeDouble(orderprice - TakeProfit * Point - AddPriceGap, Digits);
         // Send a SELLSTOP order with SL and TP
         orderticket = OrderSendEx(Symbol(), OP_SELLSTOP, LotSize, orderprice, Slippage, orderstoploss, ordertakeprofit, orderComment, Magic, NULL, Orange, NULL, oe);

         if (orderticket > 0) {
            Orders.AddTicket(orderticket, OP_SELLSTOP, orderprice, OP_UNDEFINED, NULL);
         }
         else {
            // OrderSend was NOT executed successfully
            ordersenderror = true;
         }
      }
   }

   // Check initialization
   if (GlobalError < 0) {
      // Error
      if (GlobalError == -2) {
         Alert("ERROR -- Instrument "+ Symbol() +" prices should have "+  Digits +" fraction digits on broker account");
      }
      else {
         textstring = "Volatility: "+ DoubleToStr(volatility, Digits) +"   VolatilityLimit: "+ DoubleToStr(VolatilityLimit, Digits) +"   VolatilityPercentage: "+ DoubleToStr(volatilitypercentage, Digits)           + NL
                     +"PriceDirection: "+ StringSubstr("BUY NULLSELLBOTH", 4 * pricedirection + 4, 4) +"   Open orders: "+  counter1                                                                                  + NL
                     + indy                                                                                                                                                                                           + NL
                     +"AvgSpread: "+ DoubleToStr(avgspread, Digits) +"   RealAvgSpread: "+ DoubleToStr(realavgspread, Digits) +"   Commission: "+ DoubleToStr(Commission, 2) +"   LotSize: "+ DoubleToStr(LotSize, 2) + NL;

         if (NormalizeDouble(realavgspread, Digits) > NormalizeDouble(MaxSpread * Point, Digits)) {
            textstring = textstring + "The current avg spread ("+ DoubleToStr(realavgspread, Digits) +") is higher than the configured MaxSpread ("+ DoubleToStr(MaxSpread * Point, Digits) +") => trading disabled";
         }
         Comment(NL, textstring);
      }
   }
   return(catch("Trade(5)"));
}


/**
 * Calculate lot multiplicator for AccountCurrency. Assumes that account currency is any of the 8 majors.
 * The calculated lotsize should be multiplied with this multiplicator.
 */
double GetLotsizeMultiplier() {
   double rate;
   string suffix = StrRight(Symbol(), -6);

   if      (AccountCurrency() == "USD") rate = 1;
   else if (AccountCurrency() == "EUR") rate = MarketInfo("EURUSD"+ suffix, MODE_BID);
   else if (AccountCurrency() == "GBP") rate = MarketInfo("GBPUSD"+ suffix, MODE_BID);
   else if (AccountCurrency() == "AUD") rate = MarketInfo("AUDUSD"+ suffix, MODE_BID);
   else if (AccountCurrency() == "NZD") rate = MarketInfo("NZDUSD"+ suffix, MODE_BID);
   else if (AccountCurrency() == "CHF") rate = MarketInfo("USDCHF"+ suffix, MODE_BID);
   else if (AccountCurrency() == "JPY") rate = MarketInfo("USDJPY"+ suffix, MODE_BID);
   else if (AccountCurrency() == "CAD") rate = MarketInfo("USDCAD"+ suffix, MODE_BID);
   else return(!catch("GetLotsizeMultiplier(1)  Unable to fetch market price for account currency "+ DoubleQuoteStr(AccountCurrency()), ERR_INVALID_MARKET_DATA));

   if (!rate) return(!catch("GetLotsizeMultiplier(2)  Unable to fetch market price for account currency "+ DoubleQuoteStr(AccountCurrency()), ERR_INVALID_MARKET_DATA));
   return(1/rate);
}


/**
 * Magic Number - calculated from a sum of account number + ASCII-codes from currency pair
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
 * Calculate LotSize based on Equity, Risk (in %) and StopLoss in points
 */
double CalculateLotsize() {
   double lotStep      = MarketInfo(Symbol(), MODE_LOTSTEP);
   double marginPerLot = MarketInfo(Symbol(), MODE_MARGINREQUIRED);
   double minlot = MinLots;
   double maxlot = MathMin(MathFloor(AccountEquity() * 0.98/marginPerLot/lotStep) * lotStep, MaxLots);

   int lotdigit = 0;
   if (lotStep == 1)    lotdigit = 0;
   if (lotStep == 0.1)  lotdigit = 1;
   if (lotStep == 0.01) lotdigit = 2;

   // Lot according to Risk. Don't use 100% but 98% (= 102) to avoid
   double lotsize = MathMin(MathFloor(Risk/102 * AccountEquity() / (StopLoss + AddPriceGap) / lotStep) * lotStep, MaxLots);
   lotsize *= GetLotsizeMultiplier();
   lotsize  = NormalizeDouble(lotsize, lotdigit);

   // Use manual fix LotSize, but if necessary adjust to within limits
   if (!MoneyManagement) {
      lotsize = ManualLotsize;

      if (ManualLotsize > maxlot) {
         Alert("Note: Manual LotSize is too high. It has been recalculated to maximum allowed "+ DoubleToStr(maxlot, 2));
         lotsize = maxlot;
         ManualLotsize = maxlot;
      }
      else if (ManualLotsize < minlot) {
         lotsize = minlot;
      }
   }
   return(lotsize);
}


/**
 * Re-calculate a new Risk if the current one is too low or too high
 */
void RecalculateWrongRisk() {
   string textstring = "";
   double maxlot;
   double minlot;
   double maxrisk;
   double minrisk;

   double availablemoney = AccountEquity();

   double marginPerLot = MarketInfo(Symbol(), MODE_MARGINREQUIRED);
   double lotStep = MarketInfo(Symbol(), MODE_LOTSTEP);
   maxlot = MathFloor ( availablemoney / marginPerLot / lotStep ) * lotStep;

   // Maximum allowed Risk by the broker according to maximul allowed Lot and Equity
   maxrisk = MathFloor ( maxlot * ( StopLevel + StopLoss ) / availablemoney * 100 / 0.1 ) * 0.1;
   // Minimum allowed Lot by the broker
   minlot = MinLots;
   // Minimum allowed Risk by the broker according to minlots_broker
   minrisk = MathRound ( minlot * StopLoss / availablemoney * 100 / 0.1 ) * 0.1;

   // If we use money management
   if (MoneyManagement) {
      // If Risk% is greater than the maximum risklevel the broker accept, then adjust Risk accordingly and print out changes
      if ( Risk > maxrisk ) {
         textstring = textstring + "Note: Risk has manually been set to " + DoubleToStr ( Risk, 1 ) + " but cannot be higher than " + DoubleToStr ( maxrisk, 1 ) + " according to ";
         textstring = textstring + "the broker, StopLoss and Equity. It has now been adjusted accordingly to " + DoubleToStr ( maxrisk, 1 ) + "%";
         Alert(textstring);
         Risk = maxrisk;
      }
      // If Risk% is less than the minimum risklevel the broker accept, then adjust Risk accordingly and print out changes
      if (Risk < minrisk) {
         textstring = textstring + "Note: Risk has manually been set to " + DoubleToStr ( Risk, 1 ) + " but cannot be lower than " + DoubleToStr ( minrisk, 1 ) + " according to ";
         textstring = textstring + "the broker, StopLoss, AddPriceGap and Equity. It has now been adjusted accordingly to " + DoubleToStr ( minrisk, 1 ) + "%";
         Alert(textstring);
         Risk = minrisk;
      }
   }
   // If we don't use MoneyManagement, then use fixed manual LotSize
   else {
      // Check and if necessary adjust manual LotSize to external limits
      if ( ManualLotsize < MinLots ) {
         textstring = "Manual LotSize " + DoubleToStr ( ManualLotsize, 2 ) + " cannot be less than " + DoubleToStr ( MinLots, 2 ) + ". It has now been adjusted to " + DoubleToStr ( MinLots, 2);
         ManualLotsize = MinLots;
         Alert(textstring);
      }
      if ( ManualLotsize > MaxLots ) {
         textstring = "Manual LotSize " + DoubleToStr ( ManualLotsize, 2 ) + " cannot be greater than " + DoubleToStr ( MaxLots, 2 ) + ". It has now been adjusted to " + DoubleToStr ( MinLots, 2 );
         ManualLotsize = MaxLots;
         Alert(textstring);
      }
      // Check to see that manual LotSize does not exceeds maximum allowed LotSize
      if ( ManualLotsize > maxlot ) {
         textstring = "Manual LotSize " + DoubleToStr ( ManualLotsize, 2 ) + " cannot be greater than maximum allowed LotSize. It has now been adjusted to " + DoubleToStr ( maxlot, 2 );
         ManualLotsize = maxlot;
         Alert(textstring);
      }
   }
}


/**
 * Check through all open orders
 */
void CheckOpenOrders() {
   double tmp_order_lots, tmp_order_price;

   Tot_open_pos        = 0;
   Tot_open_profit     = 0;
   Tot_open_lots       = 0;
   Tot_open_swap       = 0;
   Tot_open_commission = 0;
   G_equity            = 0;
   int Tot_Orders      = OrdersTotal();

   for (int pos=0; pos < Tot_Orders; pos++) {
      if (OrderSelect(pos, SELECT_BY_POS, MODE_TRADES)) {
         if (OrderMagicNumber()==Magic && OrderSymbol()==Symbol()) {
            Tot_open_pos++;
            tmp_order_lots       = OrderLots();
            Tot_open_lots       += tmp_order_lots;
            tmp_order_price      = OrderOpenPrice();
            Tot_open_profit     += OrderProfit();
            Tot_open_swap       += OrderSwap();
            Tot_open_commission += OrderCommission();
         }
      }
   }
   G_equity = G_balance + Tot_open_profit + Tot_open_swap + Tot_open_commission;
}


/**
 * Check through all closed orders
 */
void CheckClosedOrders() {
   Tot_closed_pos    = 0;
   Tot_closed_lots   = 0;
   Tot_closed_profit = 0;
   Tot_closed_swap   = 0;
   Tot_closed_comm   = 0;
   G_balance         = 0;

   int openTotal = OrdersHistoryTotal();

   // Loop through all closed orders
   for (int pos=0; pos < openTotal; pos++) {
      if (OrderSelect(pos, SELECT_BY_POS, MODE_HISTORY)) {
         if (OrderMagicNumber()==Magic && OrderSymbol()==Symbol()) {
            Tot_closed_lots   += OrderLots();
            Tot_closed_profit += OrderProfit();
            Tot_closed_swap   += OrderSwap();
            Tot_closed_comm   += OrderCommission();
            Tot_closed_pos++;
         }
      }
   }
   G_balance = Tot_closed_profit + Tot_closed_swap + Tot_closed_comm;
}


/**
 * Printout graphics on the chart
 */
void ShowGraphInfo() {
   if (!IsChart()) return;

   string line1 = "Open: " + DoubleToStr ( Tot_open_pos, 0 ) + " positions, " + DoubleToStr ( Tot_open_lots, 2 ) + " lots with value: " + DoubleToStr ( Tot_open_profit, 2 );
   string line2 = "Closed: " + DoubleToStr ( Tot_closed_pos, 0 ) + " positions, " + DoubleToStr ( Tot_closed_lots, 2 ) + " lots with value: " + DoubleToStr ( Tot_closed_profit, 2 );
   string line3 = "EA Balance: " + DoubleToStr ( G_balance, 2 ) + ", Swap: " + DoubleToStr ( Tot_open_swap, 2 ) + ", Commission: " + DoubleToStr ( Tot_open_commission, 2 );
   string line4 = "EA Equity: " + DoubleToStr ( G_equity, 2 ) + ", Swap: " + DoubleToStr ( Tot_closed_swap, 2 ) + ", Commission: "  + DoubleToStr ( Tot_closed_comm, 2 );

   int xPos = 3;
   int yPos = 100;

   Display("line1", line1, xPos, yPos); yPos += 20;
   Display("line2", line2, xPos, yPos); yPos += 20;
   Display("line3", line3, xPos, yPos); yPos += 20;
   Display("line4", line4, xPos, yPos); yPos += 20;

   return(catch("ShowGraphInfo(1)"));
}


/**
 * Subroutine for displaying graphics on the chart
 */
void Display(string label, string text, int xPos, int yPos) {
   if (ObjectFind(label) != 0) {
      ObjectCreate(label, OBJ_LABEL, 0, 0, 0);
   }
   ObjectSet(label, OBJPROP_CORNER,    CORNER_TOP_LEFT);
   ObjectSet(label, OBJPROP_XDISTANCE, xPos);
   ObjectSet(label, OBJPROP_YDISTANCE, yPos);

   ObjectSetText(label, text, 10, "Tahoma", Blue);
}
