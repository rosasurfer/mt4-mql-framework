/**
 * XMT-Scalper revisited
 *
 *
 * This EA is originally based on the famous "MillionDollarPips EA". Credits for the initial transformation from MDP to
 * XMT-Scalper go to a Swedish guy named Capella. In his own words: "Nothing remains from the original except the core idea
 * of the strategy: scalping based on a reversal from a channel breakout."
 *
 * Today various versions of Capella's EA circulate in the internet by various names (MDP-Plus, XMT, Assar). None of them
 * was suitable for trading real money, mainly due to a very high datafeed sensitivity (especially the amount of sent ticks)
 * and the effect of slippage and commissions. This version is again a complete rewrite.
 *
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
 *  - fixed chart object errors
 *  - repositioned chart objects and removed status display configuration
 *  - removed obsolete order expiration, NDD and screenshot functionality
 *  - removed obsolete sending of fake orders and measuring of execution times
 *  - removed configuration of min. margin level
 *  - added monitoring of PositionOpen and PositionClose events and the framework's test reporting
 */
#include <stddefines.mqh>
int   __InitFlags[] = {INIT_TIMEZONE, INIT_BUFFERED_LOG};
int __DeinitFlags[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern string Configuration             = "==== Configuration ====";
extern bool   Debug                     = false; // Debug: Print huge log files with info, only for debugging purposes
extern bool   Verbose                   = false; // Verbose: Additional log information printed in the Expert tab
extern bool   ReverseTrade              = false; // ReverseTrade: If TRUE, then trade in opposite direction
extern int    Magic                     = -1; // Magic: If set to a number less than 0 it will calculate MagicNumber automatically
extern string OrderCmt                  = "XMT 2.522-rsf"; // OrderCmt. Trade comments that appears in the Trade and Account History tab
extern string TradingSettings           = "==== Trade settings ====";
extern int    TimeFrame                 = PERIOD_M1; // TimeFrame: Trading timeframe must matrch the timeframe of the chart
extern double MaxSpread                 = 30.0; // MaxSprea: Max allowed spread in points (1 / 10 pip)
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
extern double BBDeviation               = 2.0; // BBDeviation: Deviation for the iBands indicator only
extern double EnvelopesDeviation        = 0.07; // EnvelopesDeviation: Deviation for the iEnvelopes indicator only
extern string Money_Management          = "==== Money Management ====";
extern bool   MoneyManagement           = true; // MoneyManagement: If TRUE then calculate lotsize automaticallay based on Risk, if False then use ManualLotsize below
extern double MinLots                   = 0.01; // MinLots: Minimum lot-size to trade with
extern double MaxLots                   = 100.0; // MaxLots : Maximum allowed lot-size to trade with
extern double Risk                      = 2.0; // Risk: Risk setting in percentage, For 10.000 in Equity 10% Risk and 60 StopLoss lotsize = 16.66
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
int Leverage;              // Account Leverage in percentage
int Err_unchangedvalues;   // Error count for unchanged values (modify to the same values)
int Err_busyserver;        // Error count for busy server
int Err_lostconnection;    // Error count for lost connection
int Err_toomanyrequest;    // Error count for too many requests
int Err_invalidprice;      // Error count for invalid price
int Err_invalidstops;      // Error count for invalid SL and/or TP
int Err_invalidtradevolume;// Error count for invalid lot size
int Err_pricechange;       // Error count for change of price
int Err_brokerbuzy;        // Error count for broker is buzy
int Err_requotes;          // Error count for requotes
int Err_toomanyrequests;   // Error count for too many requests
int Err_trademodifydenied; // Error count for modify orders is denied
int Err_tradecontextbuzy;  // error count for trade context is buzy
int SkippedTicks = 0;      // Used for simulation of latency during backtests, how many tics that should be skipped
int Ticks_samples = 0;     // Used for simulation of latency during backtests, number of tick samples
int Tot_closed_pos;        // Number of closed positions for this EA
int Tot_Orders;            // Number of open orders disregarding of magic and pairs
int Tot_open_pos;          // Number of open positions for this EA

double LotBase;            // Amount of money in base currency for 1 lot
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
double StopOut;            // Broker stoput percentage
double LotStep;            // Broker LotStep
double MarginForOneLot;    // Margin required for 1 lot
double Avg_tickspermin;    // Used for simulation of latency during backtests
double MarginFree;         // Free margin in percentage


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

   // Get Leverage
   Leverage = AccountLeverage();

   // Calculate StopLevel as max of either STOPLEVEL or FREEZELEVEL
   StopLevel = MathMax ( MarketInfo ( Symbol(), MODE_FREEZELEVEL ), MarketInfo ( Symbol(), MODE_STOPLEVEL ) );
   // Then calculate the StopLevel as max of either this StopLevel or MinimumUseStopLevel
   StopLevel = MathMax ( MinimumUseStopLevel, StopLevel );

   // Get stoput level and re-calculate as fraction
   StopOut = AccountStopoutLevel();

   // Calculate LotStep
   LotStep = MarketInfo ( Symbol(), MODE_LOTSTEP );

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
   if ( MinLots < MarketInfo ( Symbol(), MODE_MINLOT ) )
      MinLots = MarketInfo ( Symbol(), MODE_MINLOT );
   if ( MaxLots > MarketInfo ( Symbol(), MODE_MAXLOT ) )
      MaxLots = MarketInfo ( Symbol(), MODE_MAXLOT );
   if ( MaxLots < MinLots )
      MaxLots = MinLots;

   // Fetch the margin required for 1 lot
   MarginForOneLot = MarketInfo ( Symbol(), MODE_MARGINREQUIRED );

   // Fetch the amount of money in base currency for 1 lot
   LotBase = MarketInfo ( Symbol(), MODE_LOTSIZE );

   // Also make sure that if the risk-percentage is too low or too high, that it's adjusted accordingly
   RecalculateWrongRisk();

   // Calculate intitial LotSize
   LotSize = CalculateLotsize();

   // If magic number is set to a value less than 0, then calculate MagicNumber automatically
   if ( Magic < 0 )
     Magic = CreateMagicNumber();

   // Print initial info
   PrintDetails();

   // Check through all closed and open orders to get stats
   CheckClosedOrders();
   CheckOpenOrders();

   // Show info in graphics
   ShowGraphInfo();

   return(catch("onInit(1)"));
}


/**
 * Deinitialization
 *
 * @return int - error status
 */
int onDeinit() {
   // Print summarize of broker errors
   PrintBrokerErrors();

   // Check through all closed orders
   CheckClosedOrders();

   // If we're running as backtest, then print some result
   if (IsTesting()) {
      Print ( "Total closed lots = ", DoubleToStr ( Tot_closed_lots, 2 ) );
      Print ( "Total closed swap = ", DoubleToStr ( Tot_closed_swap, 2 ) );
      Print ( "Total closed commission = ", DoubleToStr ( Tot_closed_comm, 2 ) );
   }
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

   // Get the Free Margin
   MarginFree = AccountFreeMargin();

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
                  else
                  {
                     // Add to errors
                     ErrorMessages();
                     // Print if debug or verbose
                     if ( Debug || Verbose )
                        Print ( "Order could not be modified because of ", ErrorDescription ( GetLastError() ) );
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
                  else
                  {
                     // Add to errors
                     ErrorMessages();
                     // Print if debug or verbose
                     if ( Debug || Verbose )
                        Print ( "Order could not be modified because of ", ErrorDescription ( GetLastError() ) );
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
                     else {
                        // Add to errors
                        ErrorMessages();
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
                     else {
                        // Add to errors
                        ErrorMessages();
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
            // Add to errors
            ErrorMessages();
         } // end if-else
      } // end if pricedirection == -1 or 2

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
            // Add to errors
            ErrorMessages();
         } // end if-else
      } // end pricedirection == 0 or 2
   } // end if execute new orders

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

   // Check for stray market orders without SL
   Check4StrayTrades();

   return(catch("Trade(5)"));
}


/**
 * Check for stray trades
 */
void Check4StrayTrades() {
   // Initiate some local variables
   int loop;
   int totals;
   bool modified = true;
   bool selected;
   double ordersl;
   double newsl;
   int oe[];

   // New SL to use for modifying stray market orders is max of either current SL or 10 points
   newsl = MathMax ( StopLoss, 10 );
   // Get number of open orders
   totals = OrdersTotal();

   // Loop through all open orders from first to last
   for ( loop = 0; loop < totals; loop ++ )
   {
      // Select on order
      if ( OrderSelect ( loop, SELECT_BY_POS, MODE_TRADES ) )
      {
         // Check if it matches the MagicNumber and chart symbol
         if ( OrderMagicNumber() == Magic && OrderSymbol() == Symbol() )    // If the orders are for this EA
         {
            ordersl = OrderStopLoss();
            // Continue as long as the SL for the order is 0.0
            while ( ordersl == 0.0 )
            {
               // We have found a Buy-order
               if ( OrderType() == OP_BUY )
               {
                  // Set new SL 10 points away from current price
                  newsl = Bid - newsl * Point;
                  modified = OrderModifyEx(OrderTicket(), OrderOpenPrice(), newsl, OrderTakeProfit(), NULL, Blue, NULL, oe);
               }
               // We have found a Sell-order
               else if ( OrderType() == OP_SELL )
               {
                  // Set new SL 10 points away from current price
                  newsl = Ask + newsl * Point;
                  modified = OrderModifyEx(OrderTicket(), OrderOpenPrice(), newsl, OrderTakeProfit(), NULL, Blue, NULL, oe);
               }
               // If the order without previous SL was modified wit a new SL
               if (modified) {
                  // Select that modified order, set while condition variable to that true value and exit while-loop
                  selected = OrderSelect ( modified, SELECT_BY_TICKET, MODE_TRADES );
                  ordersl = OrderStopLoss();
                  break;
               }
               // If the order could not be modified
               else // if ( modified == false )
               {
                  // Wait 1/10 second and then fetch new prices
                  Sleep ( 100 );
                  RefreshRates();
                  // Print debug info
                  if ( Debug || Verbose )
                     Print ( "Error trying to modify stray order with a SL!" );
                  // Add to errors
                  ErrorMessages();
               }
            }
         }
      }
   }
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
   if (Debug)
      Print ( "MagicNumber: ", i );
   return ( i );
}


/**
 * Calculate LotSize based on Equity, Risk (in %) and StopLoss in points
 */
double CalculateLotsize() {
   // initiate some local variables
   string textstring;
   double availablemoney;
   double lotsize;
   double maxlot;
   double minlot;
   int lotdigit = 0;

   // Adjust lot decimals to broker lotstep
   if ( LotStep ==  1)
      lotdigit = 0;
   if ( LotStep == 0.1 )
      lotdigit = 1;
   if ( LotStep == 0.01 )
      lotdigit = 2;

   // Get available money as Equity
   availablemoney = AccountEquity();

   // Maximum allowed Lot by the broker according to Equity. And we don't use 100% but 98%
   maxlot = MathMin ( MathFloor ( availablemoney * 0.98 / MarginForOneLot / LotStep ) * LotStep, MaxLots );
   // Minimum allowed Lot by the broker
   minlot = MinLots;

   // Lot according to Risk. Don't use 100% but 98% (= 102) to avoid
   lotsize = MathMin(MathFloor ( Risk / 102 * availablemoney / ( StopLoss + AddPriceGap ) / LotStep ) * LotStep, MaxLots );
   lotsize = lotsize * Multiplicator();
   lotsize = NormalizeDouble ( lotsize, lotdigit );

   // Empty textstring
   textstring = "";

   // Use manual fix LotSize, but if necessary adjust to within limits
   if (!MoneyManagement) {
      // Set LotSize to manual LotSize
      lotsize = ManualLotsize;

      // Check if ManualLotsize is greater than allowed LotSize
      if ( ManualLotsize > maxlot )
      {
         lotsize = maxlot;
         textstring = "Note: Manual LotSize is too high. It has been recalculated to maximum allowed " + DoubleToStr ( maxlot, 2 );
         Alert(textstring);
         ManualLotsize = maxlot;
      }
      // ManualLotSize is NOT greater than allowed LotSize
      else if ( ManualLotsize < minlot )
         lotsize = minlot;
   }

   return ( lotsize );
}


/**
 * Re-calculate a new Risk if the current one is too low or too high
 */
void RecalculateWrongRisk() {
   // Initiate some local variables
   string textstring;
   double availablemoney;
   double maxlot;
   double minlot;
   double maxrisk;
   double minrisk;

   // Get available amount of money as Equity
   availablemoney = AccountEquity();
   // Maximum allowed Lot by the broker according to Equity
   maxlot = MathFloor ( availablemoney / MarginForOneLot / LotStep ) * LotStep;
   // Maximum allowed Risk by the broker according to maximul allowed Lot and Equity
   maxrisk = MathFloor ( maxlot * ( StopLevel + StopLoss ) / availablemoney * 100 / 0.1 ) * 0.1;
   // Minimum allowed Lot by the broker
   minlot = MinLots;
   // Minimum allowed Risk by the broker according to minlots_broker
   minrisk = MathRound ( minlot * StopLoss / availablemoney * 100 / 0.1 ) * 0.1;
   // Empty textstring
   textstring = "";

   // If we use money management
   if (MoneyManagement) {
      // If Risk% is greater than the maximum risklevel the broker accept, then adjust Risk accordingly and print out changes
      if ( Risk > maxrisk ) {
         textstring = textstring + "Note: Risk has manually been set to " + DoubleToStr ( Risk, 1 ) + " but cannot be higher than " + DoubleToStr ( maxrisk, 1 ) + " according to ";
         textstring = textstring + "the broker, StopLoss and Equity. It has now been adjusted accordingly to " + DoubleToStr ( maxrisk, 1 ) + "%";
         Risk = maxrisk;
         Alert(textstring);
      }
      // If Risk% is less than the minimum risklevel the broker accept, then adjust Risk accordingly and print out changes
      if (Risk < minrisk) {
         textstring = textstring + "Note: Risk has manually been set to " + DoubleToStr ( Risk, 1 ) + " but cannot be lower than " + DoubleToStr ( minrisk, 1 ) + " according to ";
         textstring = textstring + "the broker, StopLoss, AddPriceGap and Equity. It has now been adjusted accordingly to " + DoubleToStr ( minrisk, 1 ) + "%";
         Risk = minrisk;
         Alert(textstring);
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
 * Print out broker details and other info
 */
void PrintDetails() {
   // Initiate some local variables
   string margintext;
   string stopouttext;
   string fixedlots;
   int type;
   int freemarginmode;
   int stopoutmode;
   double newsl;

   // Prepare some text strings
   newsl = MathMax ( StopLoss, 10 );
   type = IsDemo() + IsTesting();
   freemarginmode = AccountFreeMarginMode();
   stopoutmode = AccountStopoutMode();

   if ( freemarginmode == 0 )
      margintext = "that floating profit/loss is not used for calculation.";
   else if ( freemarginmode == 1 )
      margintext = "both floating profit and loss on open positions.";
   else if ( freemarginmode == 2 )
      margintext = "only profitable values, where current loss on open positions are not included.";
   else if ( freemarginmode == 3 )
      margintext = "only loss values are used for calculation, where current profitable open positions are not included.";

   if ( stopoutmode == 0 )
      stopouttext = "percentage ratio between margin and equity.";
   else if ( stopoutmode == 1 )
      stopouttext = "comparison of the free margin level to the absolute value.";

   if (MoneyManagement) fixedlots = " (automatically calculated lots).";
   else                 fixedlots = " (fixed manual lots).";

   Print ( "Broker name: ", AccountCompany() );
   Print ( "Broker server: ", AccountServer() );
   Print ( "Account type: ", StringSubstr ( "RealDemoTest", 4 * type, 4) );
   Print ( "Initial account equity: ", AccountEquity()," ", AccountCurrency() );
   Print ( "Broker digits: ", Digits);
   Print ( "Broker StopLevel / freezelevel (max): ", StopLevel );
   Print ( "Broker StopOut level: ", StopOut, "%" );
   Print ( "Broker Point: ", DoubleToStr ( Point, Digits )," on ", AccountCurrency() );
   Print ( "Broker account Leverage in percentage: ", Leverage );
   Print ( "Broker credit value on the account: ", AccountCredit() );
   Print ( "Broker account margin: ", AccountMargin() );
   Print ( "Broker calculation of free margin allowed to open positions considers " + margintext );
   Print ( "Broker calculates StopOut level as " + stopouttext );
   Print ( "Broker requires at least ", MarginForOneLot," ", AccountCurrency()," in margin for 1 lot." );
   Print ( "Broker set 1 lot to trade ", LotBase," ", AccountCurrency() );
   Print ( "Broker minimum allowed LotSize: ", MinLots );
   Print ( "Broker maximum allowed LotSize: ", MaxLots );
   Print ( "Broker allow lots to be resized in ", LotStep, " steps." );
   Print ( "Risk: ", Risk, "%" );
   Print ( "Risk adjusted LotSize: ", DoubleToStr ( LotSize, 2 ) + fixedlots );
}


/**
 * Summarize error messages that comes from the broker server
 */
void ErrorMessages() {
   // Initiate a local variable
   int error = GetLastError();

   // Depending on the value if the variable error, one case should match and the counter for that errtor should be increased with 1
   switch ( error )
   {
      // Unchanged values
      case 1: // ERR_SERVER_BUSY:
      {
         Err_unchangedvalues ++;
         break;
      }
      // Trade server is busy
      case 4: // ERR_SERVER_BUSY:
      {
         Err_busyserver ++;
         break;
      }
      case 6: // ERR_NO_CONNECTION:
      {
         Err_lostconnection ++;
         break;
      }
      case 8: // ERR_TOO_FREQUENT_REQUESTS:
      {
         Err_toomanyrequest ++;
         break;
      }
      case 129: // ERR_INVALID_PRICE:
      {
         Err_invalidprice ++;
         break;
      }
      case 130: // ERR_INVALID_STOPS:
      {
         Err_invalidstops ++;
         break;
      }
      case 131: // ERR_INVALID_TRADE_VOLUME:
      {
         Err_invalidtradevolume ++;
         break;
      }
      case 135: // ERR_PRICE_CHANGED:
      {
         Err_pricechange ++;
         break;
      }
      case 137: // ERR_BROKER_BUSY:
      {
         Err_brokerbuzy ++;
         break;
      }
      case 138: // ERR_REQUOTE:
      {
         Err_requotes ++;
         break;
      }
      case 141: // ERR_TOO_MANY_REQUESTS:
      {
         Err_toomanyrequests ++;
         break;
      }
      case 145: // ERR_TRADE_MODIFY_DENIED:
      {
         Err_trademodifydenied ++;
         break;
      }
      case 146: // ERR_TRADE_CONTEXT_BUSY:
      {
         Err_tradecontextbuzy ++;
         break;
      }
   }
}


/**
 * Print out and comment summarized messages from the broker
 */
void PrintBrokerErrors() {
   string txt = "Number of times the brokers server reported that ";

   // Sum up total errors
   int totalerrors = Err_unchangedvalues + Err_busyserver + Err_lostconnection + Err_toomanyrequest + Err_invalidprice
   + Err_invalidstops + Err_invalidtradevolume + Err_pricechange + Err_brokerbuzy + Err_requotes + Err_toomanyrequests
   + Err_trademodifydenied + Err_tradecontextbuzy;

   // Call print subroutine with text depending on found errors
   if (Err_unchangedvalues    > 0) Print(txt + "SL and TP was modified to existing values: " + DoubleToStr ( Err_unchangedvalues, 0 ) );
   if (Err_busyserver         > 0) Print(txt + "it was busy: " + DoubleToStr ( Err_busyserver, 0 ) );
   if (Err_lostconnection     > 0) Print(txt + "the connection was lost: " + DoubleToStr ( Err_lostconnection, 0 ) );
   if (Err_toomanyrequest     > 0) Print(txt + "there were too many requests: " + DoubleToStr ( Err_toomanyrequest, 0 ) );
   if (Err_invalidprice       > 0) Print(txt + "the price was invalid: " + DoubleToStr ( Err_invalidprice, 0 ) );
   if (Err_invalidstops       > 0) Print(txt + "invalid SL and/or TP: " + DoubleToStr ( Err_invalidstops, 0 ) );
   if (Err_invalidtradevolume > 0) Print(txt + "invalid lot size: " + DoubleToStr ( Err_invalidtradevolume, 0 ) );
   if (Err_pricechange        > 0) Print(txt + "the price had changed: " + DoubleToStr ( Err_pricechange, 0 ) );
   if (Err_brokerbuzy         > 0) Print(txt + "the broker was busy: " + DoubleToStr ( Err_brokerbuzy, 0 ) ) ;
   if (Err_requotes           > 0) Print(txt + "requotes " + DoubleToStr ( Err_requotes, 0 ) );
   if (Err_toomanyrequests    > 0) Print(txt + "too many requests " + DoubleToStr ( Err_toomanyrequests, 0 ) );
   if (Err_trademodifydenied  > 0) Print(txt + "modifying orders was denied " + DoubleToStr ( Err_trademodifydenied, 0 ) );
   if (Err_tradecontextbuzy   > 0) Print(txt + "trade context was busy: " + DoubleToStr ( Err_tradecontextbuzy, 0 ) );
   if (totalerrors           == 0) Print("There was no error reported from the broker server!" );
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
   string line5 = "Free margin: " + DoubleToStr ( MarginFree, 2 );

   int xPos = 3;
   int yPos = 100;

   Display("line1", line1, xPos, yPos); yPos += 20;
   Display("line2", line2, xPos, yPos); yPos += 20;
   Display("line3", line3, xPos, yPos); yPos += 20;
   Display("line4", line4, xPos, yPos); yPos += 20;
   Display("line5", line5, xPos, yPos); yPos += 20;

   return(catch("ShowGraphInfo(1)"));
}


/**
 * Subroutine for displaying graphics on the chart
 */
void Display(string obj_name, string object_text, int object_x_distance, int object_y_distance) {
   if (ObjectFind(obj_name) != 0) {
      ObjectCreate(obj_name, OBJ_LABEL, 0, 0, 0);
   }
   ObjectSet ( obj_name, OBJPROP_CORNER, 0);
   ObjectSet ( obj_name, OBJPROP_XDISTANCE, object_x_distance );
   ObjectSet ( obj_name, OBJPROP_YDISTANCE, object_y_distance );
   ObjectSetText ( obj_name, object_text, 10, "Tahoma", Blue);
}
