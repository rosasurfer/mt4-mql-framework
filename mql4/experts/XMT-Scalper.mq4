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
 * pewa:
 *  - removed MQL5 syntax and fixed compiler issues
 *  - added rosasurfer framework
 *  - repositioned chart objects, fixed chart object errors and removed status display configuration
 *  - moved Print() output to the framework logger
 *  - removed obsolete functions and variables
 *  - removed obsolete order expiration, NDD and screenshot functionality
 *  - removed obsolete sending of fake orders and measuring of execution times
 *  - removed configuration of the min. margin level
 *  - added monitoring of PositionOpen and PositionClose events
 *  - added the framework's test reporting
 */
#include <stddefines.mqh>
int   __InitFlags[] = {INIT_TIMEZONE, INIT_BUFFERED_LOG};
int __DeinitFlags[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern string Configuration             = "==== Configuration ====";
extern bool   ReverseTrade              = false; // ReverseTrade: If TRUE, then trade in opposite direction
extern int    Magic                     = -1; // Magic: If set to a number less than 0 it will calculate MagicNumber automatically
extern string OrderCmt                  = "XMT 2.522-rsf"; // OrderCmt. Trade comments that appears in the Trade and Account History tab
extern string TradingSettings           = "==== Trade settings ====";
extern int    TimeFrame                 = PERIOD_M1; // TimeFrame: Trading timeframe must matrch the timeframe of the chart
extern double MaxSpread                 = 30; // MaxSprea: Max allowed spread in points (1 / 10 pip)
extern double StopLoss                  = 60; // StopLoss: SL from as many points. Default 60 (= 6 pips)
extern double TakeProfit                = 100; // TakeProfit: TP from as many points. Default 100 (= 10 pip)
extern double AddPriceGap               = 0; // AddPriceGap: Additional price gap in points added to SL and TP in order to avoid Error 130
extern double TrailingStart             = 20; // TrailingStart: Start trailing profit from as so many points.
extern double Commission                = 0; // Commission: Some broker accounts charge commission in USD per 1.0 lot. Commission in dollar per lot
extern int    Slippage                  = 3; // Slippage: Maximum allowed Slippage of price in points
extern double MinimumUseStopLevel       = 0; // MinimumUseStopLevel: Stoplevel to use will be max value of either this value or broker stoplevel
extern string VolatilitySettings        = "==== Volatility Settings ====";
extern bool   UseDynamicVolatilityLimit = true; // UseDynamicVolatilityLimit: Calculated based on INT (spread * VolatilityMultiplier)
extern double VolatilityMultiplier      = 125; // VolatilityMultiplier: A multiplier that only is used if UseDynamicVolatilityLimit is set to TRUE
extern double VolatilityLimit           = 180; // VolatilityLimit: A fix value that only is used if UseDynamicVolatilityLimit is set to FALSE
extern bool   UseVolatilityPercentage   = true; // UseVolatilityPercentage: If true, then price must break out more than a specific percentage
extern double VolatilityPercentageLimit = 0; // VolatilityPercentageLimit: Percentage of how much iHigh-iLow difference must differ from VolatilityLimit.
extern string UseIndicatorSet           = "=== Indicators: 1 = Moving Average, 2 = BollingerBand, 3 = Envelopes";
extern int    UseIndicatorSwitch        = 1; // UseIndicatorSwitch: Choose of indicator for price channel.
extern int    Indicatorperiod           = 3; // Indicatorperiod: Period in bars for indicator
extern double BBDeviation               = 2; // BBDeviation: Deviation for the iBands indicator only
extern double EnvelopesDeviation        = 0.07; // EnvelopesDeviation: Deviation for the iEnvelopes indicator only
extern string Money_Management          = "==== Money Management ====";
extern bool   MoneyManagement           = true; // MoneyManagement: If TRUE then calculate lotsize automaticallay based on Risk, if False then use ManualLotsize below
extern double MinLots                   = 0.01; // MinLots: Minimum lot-size to trade with
extern double MaxLots                   = 100; // MaxLots : Maximum allowed lot-size to trade with
extern double Risk                      = 2; // Risk: Risk setting in percentage, For 10.000 in Equity 10% Risk and 60 StopLoss lotsize = 16.66
extern double ManualLotsize             = 0.1; // ManualLotsize: Fix lot size to trade with if MoneyManagement above is set to FALSE

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/expert.mqh>
#include <stdfunctions.mqh>
#include <rsfLibs.mqh>


string EA_version = "XMT-Scalper 2.522-rsf";

datetime StartTime;        // Initial time
datetime LastTime;         // For measuring tics

int GlobalError = 0;       // To keep track on number of added errors
int TickCounter = 0;       // Counting tics
int UpTo30Counter = 0;     // For calculating average spread
int Ticks_samples = 0;     // Used for simulation of latency during backtests, number of tick samples
int Tot_closed_pos;        // Number of closed positions for this EA
int Tot_Orders;            // Number of open orders disregarding of magic and pairs
int Tot_open_pos;          // Number of open positions for this EA

double Tot_open_profit;    // A summary of the current open profit/loss for this EA
double Tot_open_lots;      // A summary of the current open lots for this EA
double Tot_open_swap;      // A summary of the current charged swaps of the open positions for this EA
double Tot_open_commission;// A summary of the currebt charged commission of the open positions for this EA
double G_equity;           // Current equity for this EA
double Tot_closed_lots;    // A summary of the current closed lots for this EA
double Tot_closed_profit;  // A summary of the current closed profit/loss for this EA
double Tot_closed_swap;    // A summary of the current closed swaps for this EA
double Tot_closed_comm;    // A summary of the current closed commission for this EA
double G_balance = 0;      // Balance for this EA
double Array_spread[30];   // Store spreads for the last 30 tics
double LotSize;            // Lotsize
double highest;            // LotSize indicator value
double lowest;             // Lowest indicator value
double StopLevel;          // Broker StopLevel
double Avg_tickspermin;    // Used for simulation of latency during backtests


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

   // Reset time for Execution control
   StartTime = TimeLocal();

   // Reset error variable
   GlobalError = -1;

   // Calculate StopLevel as max of either STOPLEVEL or FREEZELEVEL
   StopLevel = MathMax ( MarketInfo ( Symbol(), MODE_FREEZELEVEL ), MarketInfo ( Symbol(), MODE_STOPLEVEL ) );
   // Then calculate the StopLevel as max of either this StopLevel or MinimumUseStopLevel
   StopLevel = MathMax ( MinimumUseStopLevel, StopLevel );

   // Check to confirm that indicator switch is valid choices, if not force to 1 (Moving Average)
   if ( UseIndicatorSwitch < 1 || UseIndicatorSwitch > 4 )
      UseIndicatorSwitch = 1;

   // If indicator switch is set to 4, using iATR, tben UseVolatilityPercentage cannot be used, so force it to FALSE
   if ( UseIndicatorSwitch == 4 )
      UseVolatilityPercentage = false;

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
   string indy;

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

   // Previous time was less than current time, initiate tick counter
   if ( LastTime < Time[0] )
   {
      // For simulation of latency during backtests, consider only 10 samples at most.
      if ( Ticks_samples < 10 )
         Ticks_samples ++;
      Avg_tickspermin = Avg_tickspermin + ( TickCounter - Avg_tickspermin ) / Ticks_samples;
      // Set previopus time to current time and reset tick counter
      LastTime = Time[0];
      TickCounter = 0;
   }
   // Previous time was NOT less than current time, so increase tick counter with 1
   else
      TickCounter ++;

   // Get Ask and Bid for the currency
   ask = MarketInfo ( Symbol(), MODE_ASK );
   bid = MarketInfo ( Symbol(), MODE_BID );

   // Calculate the channel of Volatility based on the difference of iHigh and iLow during current bar
   ihigh = iHigh ( Symbol(), TimeFrame, 0 );
   ilow = iLow ( Symbol(), TimeFrame, 0 );
   volatility = ihigh - ilow;

   // Reset printout string
   indy = "";

   // Calculate a channel on Moving Averages, and check if the price is outside of this channel.
   if ( UseIndicatorSwitch == 1 || UseIndicatorSwitch == 4 )
   {
      imalow = iMA ( Symbol(), TimeFrame, Indicatorperiod, 0, MODE_LWMA, PRICE_LOW, 0 );
      imahigh = iMA ( Symbol(), TimeFrame, Indicatorperiod, 0, MODE_LWMA, PRICE_HIGH, 0 );
      imadiff = imahigh - imalow;
      isbidgreaterthanima = bid >= imalow + imadiff / 2.0;
      indy = "iMA_low: " + DoubleToStr(imalow, Digits) + ", iMA_high: " + DoubleToStr(imahigh, Digits) + ", iMA_diff: " + DoubleToStr(imadiff, Digits);
   }

   // Calculate a channel on BollingerBands, and check if the price is outside of this channel
   if ( UseIndicatorSwitch == 2 )
   {
      ibandsupper = iBands ( Symbol(), TimeFrame, Indicatorperiod, BBDeviation, 0, PRICE_OPEN, MODE_UPPER, 0 );
      ibandslower = iBands ( Symbol(), TimeFrame, Indicatorperiod, BBDeviation, 0, PRICE_OPEN, MODE_LOWER, 0 );
      ibandsdiff = ibandsupper - ibandslower;
      isbidgreaterthanibands = bid >= ibandslower + ibandsdiff / 2.0;
      indy = "iBands_upper: " + DoubleToStr(ibandsupper, Digits) + ", iBands_lower: " + DoubleToStr(ibandslower, Digits) + ", iBands_diff: " + DoubleToStr(ibandsdiff, Digits);
   }

   // Calculate a channel on Envelopes, and check if the price is outside of this channel
   if ( UseIndicatorSwitch == 3 )
   {
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
   if (UseIndicatorSwitch==1 && isbidgreaterthanima) {
      isbidgreaterthanindy = true;
      highest = imahigh;
      lowest = imalow;
   }

   // If we're using iBands as indicator, then set variables from it
   else if (UseIndicatorSwitch==2 && isbidgreaterthanibands) {
      isbidgreaterthanindy = true;
      highest = ibandsupper;
      lowest = ibandslower;
   }

   // If we're using iEnvelopes as indicator, then set variables from it
   else if (UseIndicatorSwitch==3 && isbidgreaterthanenvelopes) {
      isbidgreaterthanindy = true;
      highest = envelopesupper;
      lowest = envelopeslower;
   }

   // Calculate spread
   spread = ask - bid;

   // Calculate lot size
   LotSize = CalculateLotsize();

   // Calculate average true spread, which is the average of the spread for the last 30 tics
   ArrayCopy ( Array_spread, Array_spread, 0, 1, 29 );
   Array_spread[29] = spread;
   if ( UpTo30Counter < 30 )
      UpTo30Counter ++;
   sumofspreads = 0;
   loopcount2 = 29;
   for ( loopcount1 = 0; loopcount1 < UpTo30Counter; loopcount1 ++ )
   {
      sumofspreads += Array_spread[loopcount2];
      loopcount2 --;
   }

   // Calculate an average of spreads based on the spread from the last 30 tics
   avgspread = sumofspreads / UpTo30Counter;

   // Calculate price and spread considering commission
   askpluscommission = NormalizeDouble(ask + Commission, Digits);
   bidminuscommission = NormalizeDouble(bid - Commission, Digits);
   realavgspread = avgspread + Commission;

   // Recalculate the VolatilityLimit if it's set to dynamic. It's based on the average of spreads multiplied with the VolatilityMulitplier constant
   if (UseDynamicVolatilityLimit)
      VolatilityLimit = realavgspread * VolatilityMultiplier;

   // If the variables below have values it means that we have enough of data from broker server.
   if ( volatility && VolatilityLimit && lowest && highest && UseIndicatorSwitch != 4 )
   {
      // We have a price breakout, as the Volatility is outside of the VolatilityLimit, so we can now open a trade
      if ( volatility > VolatilityLimit )
      {
         // Calculate how much it differs
         volatilitypercentage = volatility / VolatilityLimit;

         // In case of UseVolatilityPercentage == TRUE then also check if it differ enough of percentage
         if (!UseVolatilityPercentage || (UseVolatilityPercentage && volatilitypercentage > VolatilityPercentageLimit)) {
            if ( bid < lowest )
            {
               if (!ReverseTrade)
                  pricedirection = -1; // BUY or BUYSTOP
               else // ReverseTrade == true
                  pricedirection = 1; // SELL or SELLSTOP
            }
            else if ( bid > highest )
            {
               if (!ReverseTrade)
                  pricedirection = 1;  // SELL or SELLSTOP
               else // ReverseTrade == true
                  pricedirection = -1; // BUY or BUYSTOP
            }
         }
      }
      // The Volatility is less than the VolatilityLimit so we set the volatilitypercentage to zero
      else
         volatilitypercentage = 0;
   }

   // Check for out of money
   if (AccountEquity() <= 0) {
      Alert("ERROR -- Account Equity is "+ DoubleToStr(MathRound(AccountEquity()), 0));
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
         orderticket = OrderSendEx(Symbol(), OP_BUYSTOP, LotSize, orderprice, Slippage, orderstoploss, ordertakeprofit, OrderCmt, Magic, NULL, Lime, NULL, oe);

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
         orderticket = OrderSendEx(Symbol(), OP_SELLSTOP, LotSize, orderprice, Slippage, orderstoploss, ordertakeprofit, OrderCmt, Magic, NULL, Orange, NULL, oe);

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
 * Calculate lot multiplicator for Account Currency. Assumes that account currency is any of the 8 majors.
 * If the account currency is of any other currency, then calculate the multiplicator as follows:
 * If base-currency is USD then use the BID-price for the currency pair USDXXX; or if the
 * counter currency is USD the use 1 / BID-price for the currency pair XXXUSD,
 * where XXX is the abbreviation for the account currency. The calculated lot-size should
 * then be multiplied with this multiplicator.
 */
double Multiplicator() {
   // Initiate some local variables
   double marketbid = 0;
   double multiplicator = 1.0;
   int length;
   string appendix = "";

   // If the account currency is USD
   if ( AccountCurrency() == "USD" )
      return ( multiplicator );
   length = StringLen ( Symbol() );
   if ( length != 6 )
      appendix = StringSubstr ( Symbol(), 6, length - 6 );

   // If the account currency is EUR
   if ( AccountCurrency() == "EUR" )
   {
      marketbid = MarketInfo ( "EURUSD" + appendix, MODE_BID );
      if ( marketbid != 0 )
         multiplicator = 1.0 / marketbid;
      else
      {
         Print ( "WARNING! Unable to fetch the market Bid price for " + AccountCurrency() + ", will use the static value 1.0 instead!" );
         multiplicator = 1.0;
      }
   }

   // If the account currency is GBP
   if ( AccountCurrency() == "GBP" )
   {
      marketbid = MarketInfo ( "GBPUSD" + appendix, MODE_BID );
      if ( marketbid != 0 )
         multiplicator = 1.0 / marketbid;
      else
      {
         Print ( "WARNING! Unable to fetch the market Bid price for " + AccountCurrency() + ", will use the static value 1.5 instead!" );
         multiplicator = 1.5;
      }
   }

   // If the account currenmmcy is AUD
   if ( AccountCurrency() == "AUD" )
   {
      marketbid = MarketInfo ( "AUDUSD" + appendix, MODE_BID );
      if ( marketbid != 0 )
         multiplicator = 1.0 / marketbid;
      else
      {
         Print ( "WARNING! Unable to fetch the market Bid price for " + AccountCurrency() + ", will use the static value 0.7 instead!" );
         multiplicator = 0.7;
      }
   }

   // If the account currency is NZD
   if ( AccountCurrency() == "NZD" )
   {
      marketbid = MarketInfo ( "NZDUSD" + appendix, MODE_BID );
      if ( marketbid != 0 )
         multiplicator = 1.0 / marketbid;
      else
      {
         Print ( "WARNING! Unable to fetch the market Bid price for " + AccountCurrency() + ", will use the static value 0.65 instead!" );
         multiplicator = 0.65;
      }
   }

   // If the account currency is CHF
   if ( AccountCurrency() == "CHF" )
   {
      marketbid = MarketInfo ( "USDCHF" + appendix, MODE_BID );
      if ( marketbid != 0 )
         multiplicator = 1.0 / marketbid;
      else
      {
         Print ( "WARNING! Unable to fetch the market Bid price for " + AccountCurrency() + ", will use the static value 1.0 instead!" );
         multiplicator = 1.0;
      }
   }

   // If the account currenmmcy is JPY
   if ( AccountCurrency() == "JPY" )
   {
      marketbid = MarketInfo ( "USDJPY" + appendix, MODE_BID );
      if ( marketbid != 0 )
         multiplicator = 1.0 / marketbid;
      else
      {
         Print ( "WARNING! Unable to fetch the market Bid price for " + AccountCurrency() + ", will use the static value 120 instead!" );
         multiplicator = 120;
      }
   }

   // If the account currenmcy is CAD
   if ( AccountCurrency() == "CAD" )
   {
      marketbid = MarketInfo ( "USDCAD" + appendix, MODE_BID );
      if ( marketbid != 0 )
         multiplicator = 1.0 / marketbid;
      else
      {
         Print ( "WARNING! Unable to fetch the market Bid price for " + AccountCurrency() + ", will use the static value 1.3 instead!" );
         multiplicator = 1.3;
      }
   }

   // If account currency is neither of EUR, GBP, AUD, NZD, CHF, JPY or CAD we assumes that it is USD
   if ( multiplicator == 0 )
      multiplicator = 1.0;

   // Return the calculated multiplicator value for the account currency
   return ( multiplicator );
}


/**
 * Magic Number - calculated from a sum of account number + ASCII-codes from currency pair
 */
int CreateMagicNumber() {
   // Initiate some local variables
   string a;
   string b;
   int c;
   int d;
   int i;
   string par = "EURUSDJPYCHFCADAUDNZDGBP";
   string sym = Symbol();

   a = StringSubstr ( sym, 0, 3 );
   b = StringSubstr ( sym, 3, 3 );
   c = StringFind ( par, a, 0 );
   d = StringFind ( par, b, 0 );
   i = 999999999 - AccountNumber() - c - d;

   if (IsLogDebug()) logDebug("MagicNumber: "+ i);
   return ( i );
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
   double lotsize = MathMin(MathFloor ( Risk / 102 * AccountEquity()/ ( StopLoss + AddPriceGap ) / lotStep ) * lotStep, MaxLots );
   lotsize = lotsize * Multiplicator();
   lotsize = NormalizeDouble(lotsize, lotdigit);

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
   // Initiate some local variables
   double tmp_order_lots;
   double tmp_order_price;

   // Reset counters
   Tot_open_pos        = 0;
   Tot_open_profit     = 0;
   Tot_open_lots       = 0;
   Tot_open_swap       = 0;
   Tot_open_commission = 0;
   G_equity            = 0;

   Tot_Orders = OrdersTotal();

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
   // Reset counters
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
            Tot_closed_lots   += OrderLots();                        // pewa: wrong
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
