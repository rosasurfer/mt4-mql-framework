/**
 * "GazillionDollarPips" (GDP) is a "MillionDollarPips" EA revisited
 *
 *
 * An EA based on the probably single most famous MetaTrader EA ever written. Nothing remains from the original except the
 * core idea of the strategy: tick scalping based on a reversal from a channel breakout.
 *
 * Today various versions of the original EA circulate in the internet by various names (MDP-Plus, XMT, Assar). However all
 * known versions - including the original - are so severly flawed that one should never run anyone of them on a live account.
 * The GDP version uses/is fully embedded in the rosasurfer MQL4 framework. It fixes the existing issues, replaces all parts
 * with more robust or faster components and adds major enhancements for production use.
 *
 * Sources:
 *  All original versions are included in the repo and accessible via the Git history. Some of them:
 *
 *  @link  https://github.com/rosasurfer/mt4-mql/blob/a1b22d0/mql4/experts/mdp              [MillionDollarPips v2 decompiled]
 *  @link  https://github.com/rosasurfer/mt4-mql/blob/36f494e/mql4/experts/mdp               [MDP-Plus v2.2 + PDF by Capella]
 *  @link  https://github.com/rosasurfer/mt4-mql/blob/41237e0/mql4/experts/mdp          [XMT-Scalper v2.522 + PDF by Capella]
 *
 *
 * Fixes/changes (wip):
 * - embedded in MQL4 framework
 * - fixed broken processing logic of open orders
 * - fixed invalid stoploss calculations
 * - replaced invalid commission calculation by framework functionality and removed input parameter "Commission"
 * - removed useless sending of speed test orders
 * - removed measuring execution times and trade suspension on delays (the framework handles this better)
 * - removed screenshot functionality (may be re-added later)
 * - removed input parameter "MinMarginLevel" to continue managing open positions during critical drawdowns
 * - removed unused input parameter "Verbose"
 */
#include <stddefines.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern string  ___a_____________________ = "==== General ====";
extern bool    Debug                     = false;        // Print debug information

extern string  ___b_____________________ = "=== Indicators: 1=Moving Average, 2=BollingerBand, 3=Envelopes";
extern int     UseIndicatorSwitch        = 1;            // indicator selection for channel creation
extern int     TimeFrame                 = PERIOD_M1;    // must match the timeframe of the chart
extern int     Indicatorperiod           = 3;            // Period in bars for indicator
extern double  BBDeviation               = 2;            // Deviation for the iBands indicator only
extern double  EnvelopesDeviation        = 0.07;         // Deviation for the iEnvelopes indicator only

extern string  ___c_____________________ = "==== Volatility Settings ====";
extern bool    UseDynamicVolatilityLimit = true;         // Calculated based on (int)(spread * VolatilityMultiplier)
extern double  VolatilityMultiplier      = 125;          // A multiplier that only is used if UseDynamicVolatilityLimit is set to TRUE
extern double  VolatilityLimit           = 180;          // A fix value that only is used if UseDynamicVolatilityLimit is set to FALSE
extern bool    UseVolatilityPercentage   = true;         // If TRUE, then price must break out more than a specific percentage
extern double  VolatilityPercentageLimit = 0;            // Percentage of how much iHigh-iLow difference must differ from VolatilityLimit.

extern string  ___d_____________________ = "==== MoneyManagement ====";
extern bool    MoneyManagement           = true;         // If TRUE calculate lotsize based on Risk, if FALSE use ManualLotsize
extern double  Risk                      = 2;            // Risk setting in percentage, for 10.000 in Equity 10% Risk and 60 StopLoss lotsize = 16.66
extern double  MinLots                   = 0.01;         // Minimum lotsize to trade with
extern double  MaxLots                   = 100;          // Maximum allowed lotsize to trade with
extern double  ManualLotsize             = 0.1;          // Fixed lotsize to trade with if MoneyManagement is set to FALSE

extern string  ___e_____________________ = "==== Trade settings ====";
extern bool    ReverseTrade              = false;        // If TRUE, then trade in opposite direction
extern bool    ECN_Mode                  = false;        // TRUE for brokers that don't accept SL and TP to be sent at the same time as the order
extern double  StopLoss                  = 60;           // SL in points. Default 60 (= 6 pip)
extern double  TakeProfit                = 100;          // TP in points. Default 100 (= 10 pip)
extern double  AddPriceGap               = 0;            // Additional price gap in points added to SL and TP in order to avoid Error 130
extern double  TrailingStart             = 20;           // Start trailing profit from as so many points.
extern int     Slippage                  = 3;            // Maximum allowed Slippage of price in points
extern int     Magic                     = -1;           // If set to a number less than 0 it will calculate MagicNumber automatically
extern int     OrderExpireSeconds        = 3600;         // Orders are deleted after so many seconds
extern double  MinimumUseStopLevel       = 0;            // Stoplevel to use will be max value of either this value or broker stoplevel
extern double  MaxSpread                 = 30;           // Max allowed spread in points

extern string  ___f_____________________ = "=== Display Graphics ===";
extern int     Heading_Size              = 13;           // Font size for headline
extern int     Text_Size                 = 12;           // Font size for texts
extern color   Color_Heading             = Lime;         // Color for text lines
extern color   Color_Section1            = Yellow;       // Color for text lines
extern color   Color_Section2            = Aqua;         // Color for text lines
extern color   Color_Section3            = Orange;       // Color for text lines
extern color   Color_Section4            = Magenta;      // Color for text lines

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/expert.mqh>
#include <stdfunctions.mqh>
#include <rsfLibs.mqh>


// PL statistics
int    openPositions;            // number of open positions
double openLots;                 // open lotsize
double openPl;                   // floating PL
int    closedPositions;          // number of closed positions
double closedLots;               // closed lotsize
double closedPl;                 //
double totalPl;                  // openPl + closedPl

// order defaults
string orderComment = "GDP";
double commissionMarkup;         // commission markup in price terms, e.g. 0.000045


// --- old ------------------------------------------------------------------------------------------------------------------
datetime StartTime;              // Initial time
datetime LastTime;               // For measuring tics
int      TickCounter;            // Counting tics
int      UpTo30Counter;          // For calculating average spread
double   spreads[30];            // Store spreads for the last 30 tics

double LotBase;                  // Amount of money in base currency for 1 lot
double LotSize;                  // Lotsize
double highest;                  // Highest indicator value
double lowest;                   // Lowest indicator value
double StopLevel;                // Broker StopLevel
double LotStep;                  // Broker LotStep
double MarginForOneLot;          // Margin required for 1 lot

int GlobalError;                 // To keep track on number of added errors
int Err_unchangedvalues;         // Error count for unchanged values (modify to the same values)
int Err_busyserver;              // Error count for busy server
int Err_lostconnection;          // Error count for lost connection
int Err_toomanyrequest;          // Error count for too many requests
int Err_invalidprice;            // Error count for invalid price
int Err_invalidstops;            // Error count for invalid SL and/or TP
int Err_invalidtradevolume;      // Error count for invalid lot size
int Err_pricechange;             // Error count for change of price
int Err_brokerbusy;              // Error count for broker is busy
int Err_requotes;                // Error count for requotes
int Err_toomanyrequests;         // Error count for too many requests
int Err_trademodifydenied;       // Error count for modify orders is denied
int Err_tradecontextbusy;        // error count for trade context is busy


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   if (!IsTesting() && Period()!=TimeFrame) {
      return(catch("onInit(1)  The EA has been set to run on timeframe "+ TimeframeDescription(TimeFrame) +" but it has been attached to a chart with timeframe "+ TimeframeDescription(Period()) +".", ERR_RUNTIME_ERROR));
   }

   DeleteRegisteredObjects();
   StartTime   = TimeLocal();    // Reset time for Execution control
   GlobalError = -1;             // Reset error variable

   // Calculate StopLevel as max of either STOPLEVEL or FREEZELEVEL
   StopLevel = MathMax ( MarketInfo ( Symbol(), MODE_FREEZELEVEL ), MarketInfo ( Symbol(), MODE_STOPLEVEL ) );
   // Then calculate the StopLevel as max of either this StopLevel or MinimumUseStopLevel
   StopLevel = MathMax ( MinimumUseStopLevel, StopLevel );

   // Calculate LotStep
   LotStep = MarketInfo ( Symbol(), MODE_LOTSTEP );

   // Check to confirm that indicator switch is valid choices, if not force to 1 (Moving Average)
   if ( UseIndicatorSwitch < 1 || UseIndicatorSwitch > 4 )
      UseIndicatorSwitch = 1;

   // If indicator switch is set to 4, using iATR, tben UseVolatilityPercentage cannot be used, so force it to false
   if ( UseIndicatorSwitch == 4 )
      UseVolatilityPercentage = false;

   // Adjust SL and TP to broker StopLevel if they are less than this StopLevel
   StopLoss = MathMax ( StopLoss, StopLevel );
   TakeProfit = MathMax ( TakeProfit, StopLevel );

   // Re-calculate variables
   VolatilityPercentageLimit = VolatilityPercentageLimit / 100 + 1;
   VolatilityMultiplier = VolatilityMultiplier / 10;
   ArrayInitialize(spreads, 0);
   VolatilityLimit = VolatilityLimit * Point;
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

   MarginForOneLot = MarketInfo(Symbol(), MODE_MARGINREQUIRED);   // Fetch the margin required for 1 lot
   LotBase         = MarketInfo(Symbol(), MODE_LOTSIZE);          // Fetch the amount of money in base currency for 1 lot
   RecalculateRisk();                                             // Make sure that if the risk-percentage is too low or too high, that it's adjusted accordingly
   LotSize = CalculateLotsize();                                  // Calculate intitial LotSize
   if (Magic < 0) Magic = GenerateMagicNumber();                  // If magic number is set to a value less than 0, then generate a new MagicNumber
   commissionMarkup = GetCommission(1, COMMISSION_MODE_MARKUP);

   UpdatePlStats();
   ShowStatus();

   return(catch("onInit(2)"));
}


/**
 * Deinitialization
 *
 * @return int - error status
 */
int onDeinit() {
   PrintErrors();
   return(catch("onDeinit(1)"));
}


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   if (iBars(Symbol(), TimeFrame) <= Indicatorperiod) {
      debug("onTick(1)  Please wait until enough of bar data has been gathered!");
   }
   else {
      MainFunction();
      UpdatePlStats();
      ShowStatus();
   }
   return(catch("onTick(2)"));
}


/**
 *
 */
void MainFunction() {
   string indy;

   datetime orderexpiretime;

   bool ordersenderror = false;
   bool isbidgreaterthanima = false;
   bool isbidgreaterthanibands = false;
   bool isbidgreaterthanenvelopes = false;
   bool isbidgreaterthanindy = false;

   int orderticket;
   int loopcount2;
   int pricedirection;
   int counter1;
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
   double sumofspreads;
   double askpluscommission;
   double bidminuscommission;

   // Previous time was less than current time, initiate tick counter
   if (LastTime < Time[0]) {
      LastTime    = Time[0];
      TickCounter = 0;
   }
   else {
      // Previous time was not less than current time, so increase tick counter
      TickCounter++;
   }

   bid = Bid;
   ask = Ask;

   // Calculate the channel of Volatility based on the difference of iHigh and iLow during current bar
   ihigh      = iHigh(Symbol(), TimeFrame, 0);
   ilow       = iLow (Symbol(), TimeFrame, 0);
   volatility = ihigh - ilow;

   indy = "";        // reset printout string

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

   // reset breakout variable
   isbidgreaterthanindy = false;

   // reset pricedirection for no indication of trading direction
   pricedirection = 0;

   // if we're using iMA as indicator, then set variables from it
   if (UseIndicatorSwitch==1 && isbidgreaterthanima) {
      isbidgreaterthanindy = true;
      highest = imahigh;
      lowest = imalow;
   }

   // if we're using iBands as indicator, then set variables from it
   else if (UseIndicatorSwitch==2 && isbidgreaterthanibands) {
      isbidgreaterthanindy = true;
      highest = ibandsupper;
      lowest = ibandslower;
   }

   // if we're using iEnvelopes as indicator, then set variables from it
   else if (UseIndicatorSwitch==3 && isbidgreaterthanenvelopes) {
      isbidgreaterthanindy = true;
      highest = envelopesupper;
      lowest = envelopeslower;
   }

   spread  = ask - bid;
   LotSize = CalculateLotsize();

   // calculatwe orderexpiretime, but only if it is set to a value
   if (OrderExpireSeconds != 0) orderexpiretime = TimeCurrent() + OrderExpireSeconds;
   else                         orderexpiretime = 0;

   // calculate average true spread, which is the average of the spread for the last 30 tics
   ArrayCopy(spreads, spreads, 0, 1, 29);
   spreads[29] = spread;
   if (UpTo30Counter < 30)
      UpTo30Counter++;
   sumofspreads = 0;
   loopcount2   = 29;

   for (int i=0; i < UpTo30Counter; i++) {
      sumofspreads += spreads[loopcount2];
      loopcount2--;
   }

   // Calculate the average spread over the last 30 ticks
   avgspread = sumofspreads / UpTo30Counter;

   // Calculate price and spread considering commission
   askpluscommission  = NormalizeDouble(ask + commissionMarkup, Digits);
   bidminuscommission = NormalizeDouble(bid - commissionMarkup, Digits);
   realavgspread      = avgspread + commissionMarkup;

   // Recalculate the VolatilityLimit if it's set to dynamic. It's based on the average of spreads multiplied with the VolatilityMulitplier constant
   if (UseDynamicVolatilityLimit)
      VolatilityLimit = realavgspread * VolatilityMultiplier;

   // If the variables below have values it means that we have enough of data from broker server.
   if ( volatility && VolatilityLimit && lowest && highest && UseIndicatorSwitch != 4 )
   {
      // We have a price breakout, as the Volatility is outside of the VolatilityLimit, so we can now open a trade
      if (volatility > VolatilityLimit) {
         // Calculate how much it differs
         volatilitypercentage = volatility / VolatilityLimit;

         // In case of UseVolatilityPercentage then also check if it differ enough of percentage
         if (!UseVolatilityPercentage || (UseVolatilityPercentage && volatilitypercentage > VolatilityPercentageLimit)) {
            if (bid < lowest) {
               if (!ReverseTrade) pricedirection = -1;   // BUY or BUYSTOP
               else               pricedirection =  1;   // SELL or SELLSTOP
            }
            else if (bid > highest) {
               if (!ReverseTrade) pricedirection =  1;   // SELL or SELLSTOP
               else               pricedirection = -1;   // BUY or BUYSTOP
            }
         }
      }
      else volatilitypercentage = 0;
   }

   // Check for out of money
   if (AccountEquity() <= 0) {
      Print("ERROR -- Account Equity is " + DoubleToStr(AccountEquity(), 2));
      return;
   }

   counter1 = 0;

   // Loop through all open orders to either modify or delete them
   for (i=0; i < OrdersTotal(); i++) {
      OrderSelect(i, SELECT_BY_POS, MODE_TRADES);

      if (OrderMagicNumber()==Magic && OrderSymbol()==Symbol() && !OrderCloseTime()) {

         switch (OrderType()) {
            case OP_BUY:
               while (true) {       // no loop but a block which can be left anywhere
                  RefreshRates();
                  orderstoploss   = OrderStopLoss();
                  ordertakeprofit = OrderTakeProfit();
                  // modify the order if its TP is less than the price+commission+StopLevel AND price+StopLevel-TP greater than trailingStart
                  if (LT(ordertakeprofit, askpluscommission + TakeProfit*Point + AddPriceGap, Digits) && GT(askpluscommission + TakeProfit*Point + AddPriceGap - ordertakeprofit, TrailingStart, Digits)) {
                     // Set SL and TP
                     orderstoploss   = NormalizeDouble(bid - StopLoss*Point - AddPriceGap, Digits);
                     ordertakeprofit = NormalizeDouble(askpluscommission + TakeProfit*Point + AddPriceGap, Digits);
                     if (orderstoploss!=OrderStopLoss() && ordertakeprofit!=OrderTakeProfit()) {
                        if (OrderModify(OrderTicket(), 0, orderstoploss, ordertakeprofit, orderexpiretime, Lime))
                           break;
                        int error = CheckLastError();
                        if (Debug) Print("Order could not be modified because of "+ ErrorDescription(error));
                     }
                  }
                  // Try to modify order with a safe hard SL that is 3 pip from current price
                  if (!orderstoploss) OrderModify(OrderTicket(), 0, NormalizeDouble(Bid-3*Pip, Digits), 0, 0, Red);
                  break;
               }
               counter1++;
               break;

            case OP_SELL:
               while (true) {       // no loop but a block which can be left anywhere
                  RefreshRates();
                  orderstoploss   = OrderStopLoss();
                  ordertakeprofit = OrderTakeProfit();
                  // modify the order if its TP is greater than price-commission-StopLevel AND TP-price-commission+StopLevel is greater than trailingstart
                  if (GT(ordertakeprofit, bidminuscommission-TakeProfit*Point-AddPriceGap, Digits) && GT(ordertakeprofit-bidminuscommission+TakeProfit*Point-AddPriceGap, TrailingStart, Digits)) {
                     // set SL and TP
                     orderstoploss   = NormalizeDouble(ask + StopLoss*Point + AddPriceGap, Digits);
                     ordertakeprofit = NormalizeDouble(bidminuscommission - TakeProfit*Point - AddPriceGap, Digits);
                     if (orderstoploss!=OrderStopLoss() && ordertakeprofit!=OrderTakeProfit()) {
                        if (OrderModify(OrderTicket(), 0, orderstoploss, ordertakeprofit, orderexpiretime, Orange))
                           break;
                     }
                     error = CheckLastError();
                     if (Debug) Print("Order could not be modified because of "+ ErrorDescription(error));
                  }
                  // Try to modify order with a safe hard SL that is 3 pip from current price
                  if (!orderstoploss) OrderModify(OrderTicket(), 0, NormalizeDouble(Ask + 3*Pip, Digits), 0, 0, Red);
                  break;
               }
               counter1++;
               break;

            case OP_BUYSTOP:
               // Price must NOT be larger than indicator in order to modify the order, otherwise the order will be deleted
               if (!isbidgreaterthanindy) {
                  // Calculate how much Price, SL and TP should be modified
                  orderprice      = NormalizeDouble(ask + StopLevel + AddPriceGap, Digits);
                  orderstoploss   = NormalizeDouble(orderprice - spread - StopLoss*Point - AddPriceGap, Digits);
                  ordertakeprofit = NormalizeDouble(orderprice + commissionMarkup + TakeProfit*Point + AddPriceGap, Digits);
                  // modify the order if price+StopLevel is less than orderprice AND orderprice-price-StopLevel is greater than trailingstart
                  if (orderprice < OrderOpenPrice() && OrderOpenPrice()-orderprice > TrailingStart) {
                     if (orderstoploss!=OrderStopLoss() && ordertakeprofit!=OrderTakeProfit()) {
                        RefreshRates();
                        if (!OrderModify(OrderTicket(), orderprice, orderstoploss, ordertakeprofit, 0, Lime))
                           CheckLastError();
                     }
                  }
                  counter1++;
               }
               else OrderDelete(OrderTicket()); // Price was larger than the indicator, delete the order
               break;

            case OP_SELLSTOP:
               // Price must be larger than the indicator in order to modify the order, otherwise the order will be deleted
               if (isbidgreaterthanindy) {
                  // Calculate how much Price, SL and TP should be modified
                  orderprice      = NormalizeDouble(bid - StopLevel - AddPriceGap, Digits);
                  orderstoploss   = NormalizeDouble(orderprice + spread + StopLoss*Point + AddPriceGap, Digits);
                  ordertakeprofit = NormalizeDouble(orderprice - commissionMarkup - TakeProfit*Point - AddPriceGap, Digits);
                  // modify order if price-StopLevel is greater than orderprice AND price-StopLevel-orderprice is greater than trailingstart
                  if (orderprice > OrderOpenPrice() && orderprice-OrderOpenPrice() > TrailingStart) {
                     if (orderstoploss!=OrderStopLoss() && ordertakeprofit!=OrderTakeProfit()) {
                        RefreshRates();
                        if (!OrderModify(OrderTicket(), orderprice, orderstoploss, ordertakeprofit, 0, Orange))
                           CheckLastError();
                     }
                  }
                  counter1++;
               }
               else OrderDelete(OrderTicket()); // Price was NOT larger than the indicator, so delete the order
               break;
         }
      }
   }

   // Calculate and keep track of global error number
   if (GlobalError >= 0 || GlobalError==-2) {
      bidpart = NormalizeDouble(bid/Point, 0);
      askpart = NormalizeDouble(ask/Point, 0);
      if      (bidpart % 10 || askpart % 10)         GlobalError = -1;
      else if (GlobalError >= 0 && GlobalError < 10) GlobalError++;
      else                                           GlobalError = -2;
   }

   // Reset error-variable
   ordersenderror = false;

   // Set default price adjustment
   askplusdistance = ask + StopLevel;
   bidminusdistance = bid - StopLevel;

   // If we have no open orders AND a price breakout AND average spread is less or equal to max allowed spread AND we have no errors THEN proceed
   if (!counter1 && pricedirection && LE(realavgspread, MaxSpread*Point, Digits) && GlobalError==-1) {
      // If we have a price breakout downwards (Bearish) then send a BUYSTOP order
      if (pricedirection==-1 || pricedirection==2 ) {    // Send a BUYSTOP
         // Calculate a new price to use
         orderprice = ask + StopLevel;

         // ECN_Mode: SL and TP is not sent with order, but added afterwords in a OrderModify command
         if (ECN_Mode) {
            // Set prices for OrderModify of BUYSTOP order
            orderprice = askplusdistance;
            orderstoploss =  0;
            ordertakeprofit = 0;
            // Send a BUYSTOP order without SL and TP
            orderticket = OrderSend(Symbol(), OP_BUYSTOP, LotSize, orderprice, Slippage, orderstoploss, ordertakeprofit, orderComment, Magic, 0, Lime);
            if (!orderticket) {
               ordersenderror = true;
               CheckLastError();
            }
            else {
               OrderSelect(orderticket, SELECT_BY_TICKET);
               RefreshRates();
               // Set prices for OrderModify of BUYSTOP order
               orderprice      = OrderOpenPrice();
               orderstoploss   = NormalizeDouble(orderprice - spread - StopLoss*Point - AddPriceGap, Digits);
               ordertakeprofit = NormalizeDouble(orderprice + TakeProfit*Point + AddPriceGap, Digits);
               // Send a modify order for BUYSTOP order with new SL and TP
               if (!OrderModify(OrderTicket(), orderprice, orderstoploss, ordertakeprofit, orderexpiretime, Lime)) {
                  ordersenderror = true;
                  CheckLastError();
               }
            }
         }

         // No ECN-mode, SL and TP can be sent directly
         else {
            RefreshRates();
            // Set prices for BUYSTOP order
            orderprice      = askplusdistance;//ask+StopLevel
            orderstoploss   = NormalizeDouble(orderprice - spread - StopLoss*Point - AddPriceGap, Digits);
            ordertakeprofit = NormalizeDouble(orderprice + TakeProfit*Point + AddPriceGap, Digits);
            // Send a BUYSTOP order with SL and TP
            if (!OrderSend(Symbol(), OP_BUYSTOP, LotSize, orderprice, Slippage, orderstoploss, ordertakeprofit, orderComment, Magic, orderexpiretime, Lime)) {
               ordersenderror = true;
               CheckLastError();
            }
         }
      }

      // If we have a price breakout upwards (Bullish) then send a SELLSTOP order
      if (pricedirection==1 || pricedirection==2) {
         // Set prices for SELLSTOP order with zero SL and TP
         orderprice      = bidminusdistance;
         orderstoploss   = 0;
         ordertakeprofit = 0;

         // ECN_Mode: SL and TP cannot be sent with order, but must be sent afterwords in a modify command
         if (ECN_Mode) {
            // Send a SELLSTOP order without SL and TP
            orderticket = OrderSend ( Symbol(), OP_SELLSTOP, LotSize, orderprice, Slippage, orderstoploss, ordertakeprofit, orderComment, Magic, 0, Orange );
            if (!orderticket) {
               ordersenderror = true;
               CheckLastError();
            }
            else {
               OrderSelect(orderticket, SELECT_BY_TICKET);
               RefreshRates();
               // Set prices for SELLSTOP order with modified SL and TP
               orderprice      = OrderOpenPrice();
               orderstoploss   = NormalizeDouble(orderprice + spread + StopLoss*Point + AddPriceGap, Digits);
               ordertakeprofit = NormalizeDouble(orderprice - TakeProfit*Point - AddPriceGap, Digits);
               // Send a modify order with adjusted SL and TP
               if (!OrderModify(OrderTicket(), OrderOpenPrice(), orderstoploss, ordertakeprofit, orderexpiretime, Orange)) {
                  ordersenderror = true;
                  CheckLastError();
               }
            }
         }

         // No ECN-mode, SL and TP can be sent directly
         else {
            RefreshRates();
            // Set prices for SELLSTOP order with SL and TP
            orderprice = bidminusdistance;
            orderstoploss = NormalizeDouble(orderprice + spread + StopLoss*Point + AddPriceGap, Digits);
            ordertakeprofit = NormalizeDouble(orderprice - TakeProfit*Point - AddPriceGap, Digits);
            if (!OrderSend(Symbol(), OP_SELLSTOP, LotSize, orderprice, Slippage, orderstoploss, ordertakeprofit, orderComment, Magic, orderexpiretime, Orange)) {
               ordersenderror = true;
               CheckLastError();
            }
         }
      }
   }

   // Check initialization
   if (GlobalError >= 0) {
      Print("Robot is initializing...");
   }
   else if (GlobalError == -2) {
      Print("ERROR -- Instrument "+ Symbol() +" prices should have "+ Digits +" fraction digits on broker account");
   }
   else if (Debug) {
      // Only print this if we have any orders or a price breakout
      if (counter1 || pricedirection)  {
         string text = TimeToStr(TimeCurrent()) +" Tick: "+ TickCounter                                                                                                                                    + NL
                     + "Currency pair: "+ Symbol()                                                                                                                                                         + NL
                     + "Volatility: "+ DoubleToStr(volatility, Digits) +", VolatilityLimit: "+ DoubleToStr(VolatilityLimit, Digits) +", VolatilityPercentage: "+ DoubleToStr(volatilitypercentage, Digits) + NL
                     + "PriceDirection: "+ StringSubstr("BUY NULLSELLBOTH", 4*pricedirection + 4, 4) +", Expire: "+ TimeToStr(orderexpiretime, TIME_MINUTES) +", Open orders: "+ counter1                  + NL
                     + "Bid: "+ NumberToStr(bid, PriceFormat) +", Ask: "+ NumberToStr(ask, PriceFormat) +", "+ indy                                                                                        + NL
                     + "AvgSpread: "+ DoubleToStr(avgspread, Digits) +", RealAvgSpread: "+ DoubleToStr(realavgspread, Digits)                                                                              + NL
                     + "Lots: "+ DoubleToStr(LotSize, 2)                                                                                                                                                   + NL;

         if (GT(realavgspread, MaxSpread*Point, Digits)) {
            text = text +"Current spread (" + DoubleToStr(realavgspread, Digits) +") is higher than the configured MaxSpread ("+ DoubleToStr(MaxSpread*Point, Digits) +"), trading is suspended."+ NL;
         }
         Print(StrTrim(text));
      }
   }

   // Check open positions without SL
   CheckMissingSL();
}


/**
 * Make sure all open positions have a stoploss.
 */
void CheckMissingSL() {
   // New SL for stray market orders is max of either current SL or 10 points
   double stoploss, slDistance = MathMax(StopLoss, 10);
   int totals = OrdersTotal();

   for (int loop=0; loop < totals; loop ++) {
      if (OrderSelect(loop, SELECT_BY_POS, MODE_TRADES)) {
         if (OrderMagicNumber()==Magic && OrderSymbol()==Symbol()) {

            while (!OrderStopLoss()) {
               if (OrderType() == OP_BUY) {
                  stoploss = NormalizeDouble(Bid - slDistance * Point, Digits);     // Set new SL 10 points away from current price
                  if (OrderModify(OrderTicket(), OrderOpenPrice(), stoploss, OrderTakeProfit(), 0, Blue)) break;
               }
               else if (OrderType() == OP_SELL) {
                  stoploss = NormalizeDouble(Ask + slDistance * Point, Digits);     // Set new SL 10 points away from current price
                  if (OrderModify(OrderTicket(), OrderOpenPrice(), stoploss, OrderTakeProfit(), 0, Blue)) break;
               }

               // Wait 100 msec and then fetch new prices
               Sleep(100);
               RefreshRates();
               if (Debug) Print("Error trying to modify order without a stoploss");
               CheckLastError();
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
 *
 * @return double
 */
double GetLotsizeMultiplier() {
   double multiplicator = 1;

   // If the account currency is USD
   if (AccountCurrency() == "USD")
      return(multiplicator);

   string symbolSuffix = StrRight(Symbol(), -6);
   double rate;

   if (AccountCurrency() == "EUR") {
      rate = MarketInfo("EURUSD"+ symbolSuffix, MODE_BID);
      if (!rate) {
         warn("Unable to fetch the Bid price for "+ AccountCurrency() +", will use the static value 1.0 instead!");
         multiplicator = 1;
      }
      else multiplicator = 1 / rate;
   }

   if (AccountCurrency() == "GBP") {
      rate = MarketInfo("GBPUSD"+ symbolSuffix, MODE_BID);
      if (!rate) {
         warn("Unable to fetch the Bid price for "+ AccountCurrency() +", will use the static value 1.5 instead!");
         multiplicator = 1.5;
      }
      else multiplicator = 1 / rate;
   }

   if (AccountCurrency() == "AUD") {
      rate = MarketInfo("AUDUSD"+ symbolSuffix, MODE_BID);
      if (!rate) {
         Print("Unable to fetch the Bid price for "+ AccountCurrency() +", will use the static value 0.7 instead!");
         multiplicator = 0.7;
      }
      else multiplicator = 1 / rate;
   }

   if (AccountCurrency() == "NZD") {
      rate = MarketInfo("NZDUSD"+ symbolSuffix, MODE_BID);
      if (!rate) {
         Print("Unable to fetch the Bid price for "+ AccountCurrency() +", will use the static value 0.65 instead!");
         multiplicator = 0.65;
      }
      else multiplicator = 1 / rate;
   }

   if (AccountCurrency() == "CHF") {
      rate = MarketInfo("USDCHF"+ symbolSuffix, MODE_BID);
      if (!rate) {
         Print("Unable to fetch the Bid price for "+ AccountCurrency() +", will use the static value 1.0 instead!");
         multiplicator = 1;
      }
      else multiplicator = 1 / rate;
   }

   if (AccountCurrency() == "JPY") {
      rate = MarketInfo("USDJPY"+ symbolSuffix, MODE_BID);
      if (!rate) {
         Print("Unable to fetch the Bid price for "+ AccountCurrency() +", will use the static value 120 instead!");
         multiplicator = 120;
      }
      else multiplicator = 1 / rate;
   }

   if (AccountCurrency() == "CAD") {
      rate = MarketInfo("USDCAD"+ symbolSuffix, MODE_BID);
      if (!rate) {
         Print("Unable to fetch the Bid price for "+ AccountCurrency() +", will use the static value 1.3 instead!");
         multiplicator = 1.3;
      }
      else multiplicator = 1 / rate;
   }

   // If account currency is something else we assumes it is USD
   if (!multiplicator) multiplicator = 1;

   return(multiplicator);
}


/**
 * Magic Number - calculated from a sum of account number + ASCII-codes from currency pair
 *
 * @return int
 */
int GenerateMagicNumber() {
   string par = "EURUSDJPYCHFCADAUDNZDGBP";
   string symbol = Symbol();

   string a = StringSubstr(symbol, 0, 3);
   string b = StringSubstr(symbol, 3, 3);
   int c = StringFind(par, a, 0);
   int d = StringFind(par, b, 0);

   int result = 999999999 - AccountNumber() - c - d;
   if (Debug) debug("GenerateMagicNumber(1)  MagicNumber="+ result);
   return(result);
}


/**
 * Calculate LotSize based on Equity, Risk (in %) and StopLoss in points
 */
double CalculateLotsize() {
   // Get available money as Equity
   double availablemoney = AccountEquity();

   // Maximum allowed Lot by the broker according to Equity. And we don't use 100% but 98%
   double maxlot = MathMin ( MathFloor ( availablemoney * 0.98 / MarginForOneLot / LotStep ) * LotStep, MaxLots );
   // Minimum allowed Lot by the broker
   double minlot = MinLots;

   // Lot according to Risk. Don't use 100% but 98% (= 102) to avoid
   double lotsize;
   lotsize = MathMin(MathFloor ( Risk / 102 * availablemoney / ( StopLoss + AddPriceGap ) / LotStep ) * LotStep, MaxLots );
   lotsize = lotsize * GetLotsizeMultiplier();
   lotsize = NormalizeLots(lotsize);

   // Use manual fix LotSize, but if necessary adjust to within limits
   if (!MoneyManagement) {
      // Set LotSize to manual LotSize
      lotsize = ManualLotsize;

      // Check if ManualLotsize is greater than allowed LotSize
      if (ManualLotsize > maxlot) {
         lotsize = maxlot;
         Print("Note: Manual LotSize is too high. It has been recalculated to maximum allowed "+ DoubleToStr(maxlot, 2));
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
void RecalculateRisk() {
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

   string textstring = "";

   // If we use money management
   if (MoneyManagement) {
      // If Risk% is greater than the maximum risklevel the broker accept, then adjust Risk accordingly and print out changes
      if ( Risk > maxrisk )
      {
         textstring = textstring + "Note: Risk has manually been set to " + DoubleToStr ( Risk, 1 ) + " but cannot be higher than " + DoubleToStr ( maxrisk, 1 ) + " according to ";
         textstring = textstring + "the broker, StopLoss and Equity. It has now been adjusted accordingly to " + DoubleToStr ( maxrisk, 1 ) + "%";
         Risk = maxrisk;
         Print(textstring);
      }
      // If Risk% is less than the minimum risklevel the broker accept, then adjust Risk accordingly and print out changes
      if (Risk < minrisk)
      {
         textstring = textstring + "Note: Risk has manually been set to " + DoubleToStr ( Risk, 1 ) + " but cannot be lower than " + DoubleToStr ( minrisk, 1 ) + " according to ";
         textstring = textstring + "the broker, StopLoss, AddPriceGap and Equity. It has now been adjusted accordingly to " + DoubleToStr ( minrisk, 1 ) + "%";
         Risk = minrisk;
         Print(textstring);
      }
   }
   // If we don't use MoneyManagement, then use fixed manual LotSize
   else // !MoneyManagement
   {
      // Check and if necessary adjust manual LotSize to external limits
      if ( ManualLotsize < MinLots )
      {
         textstring = "Manual LotSize " + DoubleToStr ( ManualLotsize, 2 ) + " cannot be less than " + DoubleToStr ( MinLots, 2 ) + ". It has now been adjusted to " + DoubleToStr ( MinLots, 2);
         ManualLotsize = MinLots;
         Print(textstring);
      }
      if ( ManualLotsize > MaxLots )
      {
         textstring = "Manual LotSize " + DoubleToStr ( ManualLotsize, 2 ) + " cannot be greater than " + DoubleToStr ( MaxLots, 2 ) + ". It has now been adjusted to " + DoubleToStr ( MinLots, 2 );
         ManualLotsize = MaxLots;
         Print(textstring);
      }
      // Check to see that manual LotSize does not exceeds maximum allowed LotSize
      if ( ManualLotsize > maxlot )
      {
         textstring = "Manual LotSize " + DoubleToStr ( ManualLotsize, 2 ) + " cannot be greater than maximum allowed LotSize. It has now been adjusted to " + DoubleToStr ( maxlot, 2 );
         ManualLotsize = maxlot;
         Print(textstring);
      }
   }
}


/**
 * Summarize error messages that comes from the broker server
 *
 * @return int - the detected error status
 */
int CheckLastError() {
   int error = GetLastError();

   switch (error) {
      case ERR_NO_RESULT:             Err_unchangedvalues++;    break;
      case ERR_SERVER_BUSY:           Err_busyserver++;         break;
      case ERR_NO_CONNECTION:         Err_lostconnection++;     break;
      case ERR_TOO_FREQUENT_REQUESTS: Err_toomanyrequest++;     break;
      case ERR_INVALID_PRICE:         Err_invalidprice++;       break;
      case ERR_INVALID_STOP:          Err_invalidstops++;       break;
      case ERR_INVALID_TRADE_VOLUME:  Err_invalidtradevolume++; break;
      case ERR_PRICE_CHANGED:         Err_pricechange++;        break;
      case ERR_BROKER_BUSY:           Err_brokerbusy++;         break;
      case ERR_REQUOTE:               Err_requotes++;           break;
      case ERR_TOO_MANY_REQUESTS:     Err_toomanyrequests++;    break;
      case ERR_TRADE_MODIFY_DENIED:   Err_trademodifydenied++;  break;
      case ERR_TRADE_CONTEXT_BUSY:    Err_tradecontextbusy++;   break;
   }
   return(error);
}


/**
 * Print out and comment summarized messages from the broker
 */
void PrintErrors() {
   int errors = Err_unchangedvalues
              + Err_busyserver
              + Err_lostconnection
              + Err_toomanyrequest
              + Err_invalidprice
              + Err_invalidstops
              + Err_invalidtradevolume
              + Err_pricechange
              + Err_brokerbusy
              + Err_requotes
              + Err_toomanyrequests
              + Err_trademodifydenied
              + Err_tradecontextbusy;

   string txt = "Number of times the brokers server reported that ";
   if (Err_unchangedvalues    > 0) Print(txt +"SL and TP was modified to existing values: "+ Err_unchangedvalues   );
   if (Err_busyserver         > 0) Print(txt +"it is busy: "+                                Err_busyserver        );
   if (Err_lostconnection     > 0) Print(txt +"the connection is lost: "+                    Err_lostconnection    );
   if (Err_toomanyrequest     > 0) Print(txt +"there was too many requests: "+               Err_toomanyrequest    );
   if (Err_invalidprice       > 0) Print(txt +"the price was invalid: "+                     Err_invalidprice      );
   if (Err_invalidstops       > 0) Print(txt +"invalid SL and/or TP: "+                      Err_invalidstops      );
   if (Err_invalidtradevolume > 0) Print(txt +"invalid lot size: "+                          Err_invalidtradevolume);
   if (Err_pricechange        > 0) Print(txt +"the price has changed: "+                     Err_pricechange       );
   if (Err_brokerbusy         > 0) Print(txt +"the broker is busy: "+                        Err_brokerbusy        );
   if (Err_requotes           > 0) Print(txt +"requotes "+                                   Err_requotes          );
   if (Err_toomanyrequests    > 0) Print(txt +"too many requests "+                          Err_toomanyrequests   );
   if (Err_trademodifydenied  > 0) Print(txt +"modifying orders is denied "+                 Err_trademodifydenied );
   if (Err_tradecontextbusy   > 0) Print(txt +"trade context is busy: "+                     Err_tradecontextbusy  );
   if (!errors)                    Print("No trade errors reported");
}


/**
 * Update PL stats of open and closed positions.
 */
void UpdatePlStats() {
   double openProfit, openSwap, openCommission, closedProfit, closedSwap, closedCommission;

   openPositions   = 0;
   openLots        = 0;
   closedPositions = 0;
   closedLots      = 0;

   int orders = OrdersTotal();
   for (int i=0; i < orders; i++) {
      if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) {
         if (OrderMagicNumber()==Magic && OrderSymbol()==Symbol()) {
            openPositions++;
            openLots       += OrderLots();
            openProfit     += OrderProfit();
            openSwap       += OrderSwap();
            openCommission += OrderCommission();
         }
      }
   }

   orders = OrdersHistoryTotal();
   for (i=0; i < orders; i++) {
      if (OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) {
         if (OrderMagicNumber()==Magic && OrderSymbol()==Symbol()) {
            closedPositions++;
            closedLots       += OrderLots();
            closedProfit     += OrderProfit();
            closedSwap       += OrderSwap();
            closedCommission += OrderCommission();
         }
      }
   }

   // calculate equity for the EA (not for the entire account)
   openPl   = openProfit + openSwap + openCommission;
   closedPl = closedProfit + closedSwap + closedCommission;
   totalPl  = openPl + closedPl;
}


/**
 * Printout graphics on the chart
 *
 * @param  int error [optional] - error to display (default: none)
 *
 * @return int - the same error or the current error status if no error was passed
 */
int ShowStatus(int error = NO_ERROR) {
   string line1 = WindowExpertName();
   string line2 = "Open PL:   "+ openPositions   +" positions ("+ NumberToStr(openLots,   ".0+") +" lot)   PL="+ DoubleToStr(openPl, 2);
   string line3 = "Closed PL: "+ closedPositions +" positions ("+ NumberToStr(closedLots, ".0+") +" lot)   PL="+ DoubleToStr(closedPl, 2);
   string line4 = "Total PL:  "+ DoubleToStr(totalPl, 2);

   int spacing=20, x=3, y=10;
   ShowStatus.CreateLabel("line1", line1, Heading_Size, x, y, Color_Heading ); y = spacing + Text_Size * 1 + 3 * 1;
   ShowStatus.CreateLabel("line2", line2, Text_Size,    x, y, Color_Section1); y = spacing + Text_Size * 2 + 3 * 2 + 20;
   ShowStatus.CreateLabel("line3", line3, Text_Size,    x, y, Color_Section2); y = spacing + Text_Size * 3 + 3 * 3 + 40;
   ShowStatus.CreateLabel("line4", line4, Text_Size,    x, y, Color_Section3);

   if (!error)
      return(last_error);
   return(error);
}


/**
 * Display graphics on the chart.
 */
void ShowStatus.CreateLabel(string label, string text, int fontSize, int x, int y, color fontColor) {
   label = WindowExpertName() +"."+ label;
   ObjectCreate (label, OBJ_LABEL, 0, 0, 0, 0, 0);
   ObjectSet    (label, OBJPROP_CORNER, CORNER_TOP_LEFT);
   ObjectSet    (label, OBJPROP_XDISTANCE, x);
   ObjectSet    (label, OBJPROP_YDISTANCE, y);
   ObjectSetText(label, text, fontSize, "Tahoma", fontColor);
   RegisterObject(label);
}
