/**
 * A "Million Dollar Pips" EA remake
 *
 * An EA based on the probably single most famous MetaTrader EA ever written. Not much remains from the original, except the
 * core idea of the strategy: tick scalping based on a reversal from a channel breakout.
 */
#include <stddefines.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern string  ___a______________________ = "==== Configuration ====";
extern bool    ReverseTrade               = false; // ReverseTrade: If true, then trade in opposite direction
extern int     Magic                      = -1; // Magic: If set to a number less than 0 it will calculate MagicNumber automatically
extern string  OrderCmt                   = "XMT-Scalper 2.522"; // OrderCmt. Trade comments that appears in the Trade and Account History tab
extern bool    ECN_Mode                   = false; // ECN_Mode: true for brokers that don't accept SL and TP to be sent at the same time as the order
extern bool    Debug                      = false; // Debug: Print huge log files with info, only for debugging purposes
extern bool    Verbose                    = false; // Verbose: Additional log information printed in the Expert tab

extern string  ___b______________________ = "==== Trade settings ====";
extern int     TimeFrame                  = PERIOD_M1; // TimeFrame: Trading timeframe must matrch the timeframe of the chart
extern double  MaxSpread                  = 30.0; // MaxSprea: Max allowed spread in points (1 / 10 pip)
extern int     MaxExecution               = 0; // MaxExecution: Max allowed average execution time in ms (0 means no restrictions)
extern int     MaxExecutionMinutes        = 5; // MaxExecutionMinutes: How often in minutes should fake orders be sent to measure execution speed
extern double  StopLoss                   = 60; // StopLoss: SL from as many points. Default 60 (= 6 pips)
extern double  TakeProfit                 = 100; // TakeProfit: TP from as many points. Default 100 (= 10 pip)
extern double  AddPriceGap                = 0; // AddPriceGap: Additional price gap in points added to SL and TP in order to avoid Error 130
extern double  TrailingStart              = 20; // TrailingStart: Start trailing profit from as so many points.
extern double  Commission                 = 0; // Commission: Some broker accounts charge commission in USD per 1.0 lot. Commission in dollar per lot
extern int     Slippage                   = 3; // Slippage: Maximum allowed Slippage of price in points
extern double  MinimumUseStopLevel        = 0; // MinimumUseStopLevel: Stoplevel to use will be max value of either this value or broker stoplevel

extern string  ___c______________________ = "==== Volatility Settings ====";
extern bool    UseDynamicVolatilityLimit  = true; // UseDynamicVolatilityLimit: Calculated based on INT (spread * VolatilityMultiplier)
extern double  VolatilityMultiplier       = 125; // VolatilityMultiplier: A multiplier that only is used if UseDynamicVolatilityLimit is set to true
extern double  VolatilityLimit            = 180; // VolatilityLimit: A fix value that only is used if UseDynamicVolatilityLimit is set to false
extern bool    UseVolatilityPercentage    = true; // UseVolatilityPercentage: If true, then price must break out more than a specific percentage
extern double  VolatilityPercentageLimit  = 0; // VolatilityPercentageLimit: Percentage of how much iHigh-iLow difference must differ from VolatilityLimit.

extern string  ___d______________________ = "=== Indicators: 1 = Moving Average, 2 = BollingerBand, 3 = Envelopes";
extern int     UseIndicatorSwitch         = 1; // UseIndicatorSwitch: Choose of indicator for price channel.
extern int     Indicatorperiod            = 3; // Indicatorperiod: Period in bars for indicator
extern double  BBDeviation                = 2.0; // BBDeviation: Deviation for the iBands indicator only
extern double  EnvelopesDeviation         = 0.07; // EnvelopesDeviation: Deviation for the iEnvelopes indicator only
extern int     OrderExpireSeconds         = 3600; // OrderExpireSeconds: Orders are deleted after so many seconds

extern string  ___e______________________ = "==== Money Management ====";
extern bool    MoneyManagement            = true; // MoneyManagement: If true then calculate lotsize automaticallay based on Risk, if false then use ManualLotsize below
extern double  MinLots                    = 0.01; // MinLots: Minimum lot-size to trade with
extern double  MaxLots                    = 100.0; // MaxLots : Maximum allowed lot-size to trade with
extern double  Risk                       = 2.0; // Risk: Risk setting in percentage, For 10.000 in Equity 10% Risk and 60 StopLoss lotsize = 16.66
extern double  ManualLotsize              = 0.1; // ManualLotsize: Fix lot size to trade with if MoneyManagement above is set to false
extern double  MinMarginLevel             = 100; // MinMarginLevel: Lowest allowed Margin level for new positions to be opened

extern string  ___f______________________ = "=== Display Graphics ==="; // Colors for sub_Display at upper left
extern int     Heading_Size               = 13;  // Heading_Size: Font size for headline
extern int     Text_Size                  = 12;  // Text_Size: Font size for texts
extern color   Color_Heading              = Lime;   // Color for text lines
extern color   Color_Section1             = Yellow; // Color for text lines
extern color   Color_Section2             = Aqua;   // Color for text lines
extern color   Color_Section3             = Orange; // Color for text lines
extern color   Color_Section4             = Magenta;// Color for text lines

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/expert.mqh>
#include <stdfunctions.mqh>
#include <rsfLibs.mqh>

//--------------------------- Globals --------------------------------------------------------------

string EA_version = "XMT-Scalper v2.522";

datetime StartTime;        // Initial time
datetime LastTime;         // For measuring tics

int GlobalError = 0;       // To keep track on number of added errors
int TickCounter = 0;       // Counting tics
int UpTo30Counter = 0;     // For calculating average spread
int Execution = -1;        // For Execution speed, -1 means no speed
int Avg_execution = 0;     // Average Execution speed
int Execution_samples = 0; // For calculating average Execution speed
int Err_unchangedvalues;   // Error count for unchanged values (modify to the same values)
int Err_busyserver;        // Error count for busy server
int Err_lostconnection;    // Error count for lost connection
int Err_toomanyrequest;    // Error count for too many requests
int Err_invalidprice;      // Error count for invalid price
int Err_invalidstops;      // Error count for invalid SL and/or TP
int Err_invalidtradevolume;// Error count for invalid lot size
int Err_pricechange;       // Error count for change of price
int Err_brokerbusy;        // Error count for broker is busy
int Err_requotes;          // Error count for requotes
int Err_toomanyrequests;   // Error count for too many requests
int Err_trademodifydenied; // Error count for modify orders is denied
int Err_tradecontextbusy;  // error count for trade context is busy
int SkippedTicks = 0;      // Used for simulation of latency during backtests, how many tics that should be skipped
int Ticks_samples = 0;     // Used for simulation of latency during backtests, number of tick samples
int Tot_closed_pos;        // Number of closed positions for this EA
int Tot_Orders;            // Number of open orders disregarding of magic and pairs
int Tot_open_pos;          // Number of open positions for this EA

double LotBase;            // Amount of money in base currency for 1 lot
double Tot_open_lots;      // A summary of the current open lots for this EA
double Tot_open_profit;    // A summary of the current open profit/loss for this EA
double Tot_open_swap;      // A summary of the current charged swaps of the open positions for this EA
double Tot_open_commission;// A summary of the currebt charged commission of the open positions for this EA
double Tot_closed_lots;    // A summary of the current closed lots for this EA
double Tot_closed_profit;  // A summary of the current closed profit/loss for this EA
double Tot_closed_swap;    // A summary of the current closed swaps for this EA
double Tot_closed_comm;    // A summary of the current closed commission for this EA
double G_balance = 0;      // Balance for this EA
double G_equity;           // Current equity for this EA
double Changedmargin;      // Free margin for this account
double Array_spread[30];   // Store spreads for the last 30 tics
double LotSize;            // Lotsize
double highest;            // Highest indicator value
double lowest;             // Lowest indicator value
double StopLevel;          // Broker StopLevel
double LotStep;            // Broker LotStep
double MarginForOneLot;    // Margin required for 1 lot
double Avg_tickspermin;    // Used for simulation of latency during backtests


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   if (!IsTesting() && Period()!=TimeFrame) {
      return(catch("onInit(1)  The EA has been set to run on timeframe "+ TimeframeDescription(TimeFrame) +" but it has been attached to a chart with timeframe "+ TimeframeDescription(Period()) +".", ERR_RUNTIME_ERROR));
   }

   RemoveObjects();
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

   MarginForOneLot = MarketInfo(Symbol(), MODE_MARGINREQUIRED);   // Fetch the margin required for 1 lot
   LotBase         = MarketInfo(Symbol(), MODE_LOTSIZE);          // Fetch the amount of money in base currency for 1 lot
   RecalculateRisk();                                             // Make sure that if the risk-percentage is too low or too high, that it's adjusted accordingly
   LotSize = CalculateLotsize();                                  // Calculate intitial LotSize
   if (Magic < 0)        Magic = GenerateMagicNumber();           // If magic number is set to a value less than 0, then generate a new MagicNumber
   if (MaxExecution > 0) MaxExecutionMinutes = MaxExecution * 60; // If Execution speed should be measured, then adjust maxexecution from minutes to seconds

   UpdateClosedOrderStats();                                      // Check through all closed and open orders to get stats and show status
   UpdateOpenOrderStats();
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
   RemoveObjects();
   UpdateClosedOrderStats();

   if (IsTesting()) {
      Print("Total lots: "+       DoubleToStr(Tot_closed_lots, 2));
      Print("Total swap: "+       DoubleToStr(Tot_closed_swap, 2));
      Print("Total commission: "+ DoubleToStr(Tot_closed_comm, 2));

      if (MaxExecution > 0)
         Print("During backtesting "+ SkippedTicks +" number of ticks were skipped to simulate latency of up to "+ MaxExecution +" ms.");
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
      debug("onTick(1)  Please wait until enough of bar data has been gathered!");
   }
   else {
      MainFunction();
      UpdateClosedOrderStats();
      UpdateOpenOrderStats();
      ShowStatus();
   }
   return(catch("onTick(2)"));
}


/**
 *
 */
void MainFunction() {
   string textstring;
   string pair;
   string indy;

   datetime orderexpiretime;

   bool select = false;
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
   double tmpexecution;

   // Calculate Margin level
   if ( AccountMargin() != 0 )
      am = AccountMargin();
   marginlevel = AccountEquity() / am * 100;

   // Free Margin is less than the value of MinMarginLevel, so no trading is allowed
   if ( marginlevel < MinMarginLevel )
   {
      Print ( "Warning! Free Margin " + DoubleToStr ( marginlevel, 2 ) + " is lower than MinMarginLevel!" );
      Alert ( "Warning! Free Margin " + DoubleToStr ( marginlevel, 2 ) + " is lower than MinMarginLevel!" );
      return;
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

   // If backtesting and MaxExecution is set let's skip a proportional number of ticks them in order to
   // reproduce the effect of latency on this EA
   if ( IsTesting() && MaxExecution != 0 && Execution != -1 )
   {
      skipticks = MathRound ( Avg_tickspermin * MaxExecution / ( 60 * 1000 ) );
      if ( SkippedTicks >= skipticks )
      {
         Execution = -1;
         SkippedTicks = 0;
      }
      else
      {
         SkippedTicks ++;
      }
   }

   bid = Bid;
   ask = Ask;

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

   // Reset breakout variable as false
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

   spread = ask - bid;
   LotSize = CalculateLotsize();

   // calculatwe orderexpiretime, but only if it is set to a value
   if (OrderExpireSeconds != 0) orderexpiretime = TimeCurrent() + OrderExpireSeconds;
   else                         orderexpiretime = 0;

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
   askpluscommission  = NormalizeDouble(ask + Commission, Digits);
   bidminuscommission = NormalizeDouble(bid - Commission, Digits);
   realavgspread      = avgspread + Commission;

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

         // In case of UseVolatilityPercentage then also check if it differ enough of percentage
         if (!UseVolatilityPercentage || (UseVolatilityPercentage && volatilitypercentage > VolatilityPercentageLimit)) {
            if ( bid < lowest )
            {
               if (!ReverseTrade)
                  pricedirection = -1; // BUY or BUYSTOP
               else // ReverseTrade
                  pricedirection = 1; // SELL or SELLSTOP
            }
            else if (bid > highest) {
               if (!ReverseTrade)
                  pricedirection = 1;  // SELL or SELLSTOP
               else // ReverseTrade
                  pricedirection = -1; // BUY or BUYSTOP
            }
         }
      }
      // The Volatility is less than the VolatilityLimit so we set the volatilitypercentage to zero
      else
         volatilitypercentage = 0;
   }

   // Check for out of money
   if ( AccountEquity() <= 0.0 )
   {
      Print ( "ERROR -- Account Equity is " + DoubleToStr ( MathRound ( AccountEquity() ), 0 ) );
      return;
   }

   // Reset Execution time
   Execution = -1;

   // Reset counters
   counter1 = 0;
   counter2 = 0;

   // Loop through all open orders (if any) to either modify them or delete them
   for ( loopcount2 = 0; loopcount2 < OrdersTotal(); loopcount2 ++ )
   {
      // Select an order from the open orders
      select = OrderSelect ( loopcount2, SELECT_BY_POS, MODE_TRADES );
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
               if (LT(ordertakeprofit, askpluscommission + TakeProfit*Point + AddPriceGap, Digits) && GT(askpluscommission + TakeProfit * Point + AddPriceGap - ordertakeprofit, TrailingStart, Digits)) {
                  // Set SL and TP
                  orderstoploss   = NormalizeDouble(bid - StopLoss*Point - AddPriceGap, Digits);
                  ordertakeprofit = NormalizeDouble(askpluscommission + TakeProfit*Point + AddPriceGap, Digits);
                  // Send an OrderModify command with adjusted SL and TP
                  if (orderstoploss!=OrderStopLoss() && ordertakeprofit!=OrderTakeProfit()) {
                     // Start Execution timer
                     Execution = GetTickCount();
                     // Try to modify order
                     wasordermodified = OrderModify ( OrderTicket(), 0, orderstoploss, ordertakeprofit, orderexpiretime, Lime );
                  }
                  // Order was modified with new SL and TP
                  if (wasordermodified) {
                     // Calculate Execution speed
                     Execution = GetTickCount() - Execution;
                     // Break out from while-loop since the order now has been modified
                     break;
                  }
                  else {
                     // Reset Execution counter
                     Execution = -1;
                     CheckLastError();
                     if (Debug || Verbose) Print("Order could not be modified because of ", ErrorDescription(GetLastError()));
                     // Try to modify order with a safe hard SL that is 3 pip from current price
                     if (!orderstoploss) wasordermodified = OrderModify(OrderTicket(), 0, NormalizeDouble(Bid-3*Pip, Digits), 0, 0, Red);
                  }
               }
               break;
            }
            counter1 ++;
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
               if (GT(ordertakeprofit, bidminuscommission-TakeProfit*Point-AddPriceGap, Digits) && GT(ordertakeprofit-bidminuscommission+TakeProfit*Point-AddPriceGap, TrailingStart, Digits)) {
                  // set SL and TP
                  orderstoploss   = NormalizeDouble(ask + StopLoss*Point + AddPriceGap, Digits);
                  ordertakeprofit = NormalizeDouble(bidminuscommission - TakeProfit*Point - AddPriceGap, Digits);
                  // Send an OrderModify command with adjusted SL and TP
                  if (orderstoploss!=OrderStopLoss() && ordertakeprofit!=OrderTakeProfit()) {
                     // Start Execution timer
                     Execution = GetTickCount();
                     wasordermodified = OrderModify ( OrderTicket(), 0, orderstoploss, ordertakeprofit, orderexpiretime, Orange );
                  }

                  // Order was modiified with new SL and TP
                  if (wasordermodified) {
                     Execution = GetTickCount() - Execution;
                     break;
                  }

                  // Reset Execution counter
                  Execution = -1;
                  CheckLastError();
                  if (Debug || Verbose) Print("Order could not be modified because of ", ErrorDescription(GetLastError()));
                  Sleep(1000);
                  // Try to modify order with a safe hard SL that is 3 pip from current price
                  if (!orderstoploss) wasordermodified = OrderModify(OrderTicket(), 0, NormalizeDouble(Ask + 3*Pip, Digits), 0, 0, Red);
               }
               break;
            }
            counter1 ++;
            break;

         // We've found a matching BUYSTOP-order
         case OP_BUYSTOP:
            // Price must NOT be larger than indicator in order to modify the order, otherwise the order will be deleted
            if (!isbidgreaterthanindy) {
               // Calculate how much Price, SL and TP should be modified
               orderprice      = NormalizeDouble(ask + StopLevel + AddPriceGap, Digits);
               orderstoploss   = NormalizeDouble(orderprice - spread - StopLoss*Point - AddPriceGap, Digits);
               ordertakeprofit = NormalizeDouble(orderprice + Commission + TakeProfit*Point + AddPriceGap, Digits);
               // Start endless loop
               while (true) {
                  // Ok to modify the order if price+StopLevel is less than orderprice AND orderprice-price-StopLevel is greater than trailingstart
                  if ( orderprice < OrderOpenPrice() && OrderOpenPrice() - orderprice > TrailingStart )
                  {

                     // Send an OrderModify command with adjusted Price, SL and TP
                     if ( orderstoploss != OrderStopLoss() && ordertakeprofit != OrderTakeProfit() )
                     {
                        RefreshRates();
                        // Start Execution timer
                        Execution = GetTickCount();
                        wasordermodified = OrderModify ( OrderTicket(), orderprice, orderstoploss, ordertakeprofit, 0, Lime );
                     }
                     // Order was modified
                     if (wasordermodified) {
                        Execution = GetTickCount() - Execution;
                        if (Debug || Verbose) Print("Order executed in "+ Execution +" ms");
                     }
                     else {
                        // Reset Execution counter
                        Execution = -1;
                        CheckLastError();
                     }
                  }
                  break;
               }
               counter1 ++;
            }
            // Price was larger than the indicator
            else {
               // Delete the order
               select = OrderDelete(OrderTicket());
            }
            break;

         // We've found a matching SELLSTOP-order
         case OP_SELLSTOP:
            // Price must be larger than the indicator in order to modify the order, otherwise the order will be deleted
            if (isbidgreaterthanindy) {
               // Calculate how much Price, SL and TP should be modified
               orderprice      = NormalizeDouble(bid - StopLevel - AddPriceGap, Digits);
               orderstoploss   = NormalizeDouble(orderprice + spread + StopLoss*Point + AddPriceGap, Digits);
               ordertakeprofit = NormalizeDouble(orderprice - Commission - TakeProfit*Point - AddPriceGap, Digits);
               // Endless loop
               while (true) {
                  // Ok to modify order if price-StopLevel is greater than orderprice AND price-StopLevel-orderprice is greater than trailingstart
                  if ( orderprice > OrderOpenPrice() && orderprice - OrderOpenPrice() > TrailingStart)
                  {
                     // Send an OrderModify command with adjusted Price, SL and TP
                     if ( orderstoploss != OrderStopLoss() && ordertakeprofit != OrderTakeProfit() )
                     {
                        RefreshRates();
                        // Start Execution counter
                        Execution = GetTickCount();
                        wasordermodified = OrderModify(OrderTicket(), orderprice, orderstoploss, ordertakeprofit, 0, Orange);
                     }
                     // Order was modified
                     if (wasordermodified) {
                        Execution = GetTickCount() - Execution;
                        if (Debug || Verbose) Print("Order executed in "+ Execution +" ms");
                     }
                     else {
                        Execution = -1;
                        CheckLastError();
                     }
                  }
                  break;
               }
               counter1++;
            }
            else {
               // Price was NOT larger than the indicator, so delete the order
               select = OrderDelete(OrderTicket());
            }
         }
      }
   }

   // Calculate and keep track on global error number
   if (GlobalError >= 0 || GlobalError==-2) {
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

   // Before executing new orders, lets check the average Execution time.
   if ( pricedirection != 0 && MaxExecution > 0 && Avg_execution > MaxExecution )
   {
      pricedirection = 0; // Ignore the order opening triger
      if ( Debug || Verbose )
         Print ( "Server is too Slow. Average Execution: " + Avg_execution );
   }

   // Set default price adjustment
   askplusdistance = ask + StopLevel;
   bidminusdistance = bid - StopLevel;

   // If we have no open orders AND a price breakout AND average spread is less or equal to max allowed spread AND we have no errors THEN proceed
   if (!counter1 && pricedirection && LE(realavgspread, MaxSpread*Point, Digits) && GlobalError==-1) {
      // If we have a price breakout downwards (Bearish) then send a BUYSTOP order
      if ( pricedirection == -1 || pricedirection == 2 ) // Send a BUYSTOP
      {
         // Calculate a new price to use
         orderprice = ask + StopLevel;
         // SL and TP is not sent with order, but added afterwords in a OrderModify command
         if (ECN_Mode) {
            // Set prices for OrderModify of BUYSTOP order
            orderprice = askplusdistance;
            orderstoploss =  0;
            ordertakeprofit = 0;
            // Start Execution counter
            Execution = GetTickCount();
            // Send a BUYSTOP order without SL and TP
            orderticket = OrderSend ( Symbol(), OP_BUYSTOP, LotSize, orderprice, Slippage, orderstoploss, ordertakeprofit, OrderCmt, Magic, 0, Lime );
            // OrderSend was executed successfully
            if (orderticket > 0) {
               // Calculate Execution speed
               Execution = GetTickCount() - Execution;
               if (Debug || Verbose) Print ("Order executed in "+ Execution +" ms");
            }
            else {
               ordersenderror = true;
               Execution = -1;
               CheckLastError();
            }
            // OrderSend was executed successfully, so now modify it with SL and TP
            if (OrderSelect(orderticket, SELECT_BY_TICKET)) {
               RefreshRates();
               // Set prices for OrderModify of BUYSTOP order
               orderprice      = OrderOpenPrice();
               orderstoploss   = NormalizeDouble(orderprice - spread - StopLoss*Point - AddPriceGap, Digits);
               ordertakeprofit = NormalizeDouble(orderprice + TakeProfit*Point + AddPriceGap, Digits);
               // Start Execution timer
               Execution = GetTickCount();
               // Send a modify order for BUYSTOP order with new SL and TP
               wasordermodified = OrderModify ( OrderTicket(), orderprice, orderstoploss, ordertakeprofit, orderexpiretime, Lime );
               // OrderModify was executed successfully
               if (wasordermodified) {
                  Execution = GetTickCount() - Execution;
                  if (Debug || Verbose) Print("Order executed in "+ Execution +" ms");
               }
               else {
                  ordersenderror = true;
                  Execution = -1;
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
            // Start Execution counter
            Execution = GetTickCount();
            // Send a BUYSTOP order with SL and TP
            orderticket = OrderSend ( Symbol(), OP_BUYSTOP, LotSize, orderprice, Slippage, orderstoploss, ordertakeprofit, OrderCmt, Magic, orderexpiretime, Lime );
            if (orderticket > 0) {
               Execution = GetTickCount() - Execution;
               if (Debug || Verbose) Print("Order executed in "+ Execution +" ms");
            }
            else {
               ordersenderror = true;
               Execution = -1;
               CheckLastError();
            }
         }
      }

      // If we have a price breakout upwards (Bullish) then send a SELLSTOP order
      if ( pricedirection == 1 || pricedirection == 2 )
      {
         // Set prices for SELLSTOP order with zero SL and TP
         orderprice = bidminusdistance;
         orderstoploss = 0;
         ordertakeprofit = 0;
         // SL and TP cannot be sent with order, but must be sent afterwords in a modify command
         if (ECN_Mode)
         {
            // Start Execution timer
            Execution = GetTickCount();
            // Send a SELLSTOP order without SL and TP
            orderticket = OrderSend ( Symbol(), OP_SELLSTOP, LotSize, orderprice, Slippage, orderstoploss, ordertakeprofit, OrderCmt, Magic, 0, Orange );
            if (orderticket > 0) {
               // Calculate Execution speed
               Execution = GetTickCount() - Execution;
               if ( Debug || Verbose )
                  Print ( "Order executed in " + Execution + " ms" );
            }
            else {
               ordersenderror = true;
               Execution = -1;
               CheckLastError();
            }

            // If the SELLSTOP order was executed successfully, then select that order
            if (OrderSelect(orderticket, SELECT_BY_TICKET)) {
               RefreshRates();
               // Set prices for SELLSTOP order with modified SL and TP
               orderprice      = OrderOpenPrice();
               orderstoploss   = NormalizeDouble(orderprice + spread + StopLoss*Point + AddPriceGap, Digits);
               ordertakeprofit = NormalizeDouble(orderprice - TakeProfit*Point - AddPriceGap, Digits);
               // Start Execution timer
               Execution = GetTickCount();
               // Send a modify order with adjusted SL and TP
               wasordermodified = OrderModify ( OrderTicket(), OrderOpenPrice(), orderstoploss, ordertakeprofit, orderexpiretime, Orange );
            }

            // OrderModify was executed successfully
            if (wasordermodified) {
               Execution = GetTickCount() - Execution;
               if (Debug || Verbose) Print("Order executed in "+ Execution +" ms");
            }
            else {
               ordersenderror = true;
               Execution = -1;
               CheckLastError();
            }
         }

         else {
            // No ECN-mode, SL and TP can be sent directly
            RefreshRates();
            // Set prices for SELLSTOP order with SL and TP
            orderprice = bidminusdistance;
            orderstoploss = NormalizeDouble(orderprice + spread + StopLoss*Point + AddPriceGap, Digits);
            ordertakeprofit = NormalizeDouble(orderprice - TakeProfit*Point - AddPriceGap, Digits);
            // Start Execution timer
            Execution = GetTickCount();
            // Send a SELLSTOP order with SL and TP
            orderticket = OrderSend ( Symbol(), OP_SELLSTOP, LotSize, orderprice, Slippage, orderstoploss, ordertakeprofit, OrderCmt, Magic, orderexpiretime, Orange );
            // If OrderSend was executed successfully
            if (orderticket > 0) {
               Execution = GetTickCount() - Execution;
               if (Debug || Verbose) Print("Order executed in "+ Execution +" ms");
            }
            else {
               ordersenderror = true;
               Execution = 0;
               CheckLastError();
            }
         }
      }
   }

   // If we have no samples, every MaxExecutionMinutes a new OrderModify Execution test is done
   if (MaxExecution && Execution==-1 && (TimeLocal()-StartTime) % MaxExecutionMinutes == 0) {
      // When backtesting, simulate random Execution time based on the setting
      if (IsTesting() && MaxExecution) {
         MathSrand(TimeLocal());
         Execution = MathRand() / (32767/MaxExecution);
      }
      else {
         // Unless backtesting, lets send a fake order to check the OrderModify Execution time,
         if (!IsTesting()) {
            // To be sure that the fake order never is executed, st the price to twice the current price
            fakeprice = ask * 2.0;
            // Send a BUYSTOP order
            orderticket = OrderSend ( Symbol(), OP_BUYSTOP, LotSize, fakeprice, Slippage, 0, 0, OrderCmt, Magic, 0, Lime );
            Execution = GetTickCount();
            // Send a modify command where we adjust the price with +1 pip
            wasordermodified = OrderModify(orderticket, fakeprice + 1*Pip, 0, 0, 0, Lime);
            Execution = GetTickCount() - Execution;
            // Delete the order
            select = OrderDelete(orderticket);
         }
      }
   }

   // Do we have a valid Execution sample? Update the average Execution time.
   if ( Execution >= 0 )
   {
      // Consider only 10 samples at most.
      if ( Execution_samples < 10 )
         Execution_samples ++;
      // Calculate average Execution speed
      Avg_execution = Avg_execution + ( Execution - Avg_execution ) / Execution_samples;
   }

   // Check initialization
   if ( GlobalError >= 0 )
      Print ( "Robot is initializing..." );
   else
   {
      // Error
      if ( GlobalError == -2 )
         Print ( "ERROR -- Instrument " + Symbol() + " prices should have " + Digits + " fraction digits on broker account" );
      // No errors, ready to print
      else
      {
         textstring = TimeToStr ( TimeCurrent() ) + " Tick: " + StrLeftPad(TickCounter, 3, "0");
         // Only show / print this if Debug OR Verbose are set to true
         if ( Debug || Verbose )
         {
            // In case Execution is -1 (not yet calculate dvalue, set it to 0 for printing
            tmpexecution = Execution;
            if ( Execution == -1 )
               tmpexecution = 0;
            // Prepare text string for printing
            textstring = textstring + "\n*** DEBUG MODE *** \nCurrency pair: " + Symbol() + ", Volatility: " + DoubleToStr(volatility, Digits)
            + ", VolatilityLimit: " + DoubleToStr(VolatilityLimit, Digits) + ", VolatilityPercentage: " + DoubleToStr(volatilitypercentage, Digits);
            textstring = textstring + "\nPriceDirection: " + StringSubstr ( "BUY NULLSELLBOTH", 4 * pricedirection + 4, 4 ) +  ", Expire: "
            + TimeToStr ( orderexpiretime, TIME_MINUTES ) + ", Open orders: " + counter1;
            textstring = textstring + "\nBid: " + NumberToStr(bid, PriceFormat) + ", Ask: "+ NumberToStr(ask, PriceFormat) + ", " + indy;
            textstring = textstring + "\nAvgSpread: " + DoubleToStr(avgspread, Digits) + ", RealAvgSpread: " + DoubleToStr(realavgspread, Digits)
            + ", Commission: " + DoubleToStr(Commission, 2) + ", Lots: " + DoubleToStr ( LotSize, 2 ) + ", Execution: " + tmpexecution + " ms";
            if (GT(realavgspread, MaxSpread*Point, Digits)) {
               textstring = textstring + "\n" + "The current spread (" + DoubleToStr(realavgspread, Digits)
               +") is higher than what has been set as MaxSpread (" + DoubleToStr(MaxSpread*Point, Digits) + ") so no trading is allowed right now on this currency pair!";
            }
            if ( MaxExecution > 0 && Avg_execution > MaxExecution )
            {
               textstring = textstring + "\n" + "The current Avg Execution (" + Avg_execution +") is higher than what has been set as MaxExecution ("
               + MaxExecution+ " ms), so no trading is allowed right now on this currency pair!";
            }
            Print ( textstring );
            // Only print this if we have a any orders  OR have a price breakout OR Verbode mode is set to true
            if ( counter1 != 0 || pricedirection != 0 )
               PrintLines(textstring);
         }
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
               if (Debug || Verbose) Print("Error trying to modify stray order with a SL!");
               CheckLastError();
            }
         }
      }
   }
}


/**
 * Print a multiline string line by line.
 */
void PrintLines(string str) {
   string values[];
   int size = Explode(str, NL, values, NULL);
   for (int i=0; i < size; i++) {
      Print(values[i]);
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
   double availablemoney;
   double lotsize;
   double maxlot;
   double minlot;

   // Get available money as Equity
   availablemoney = AccountEquity();

   // Maximum allowed Lot by the broker according to Equity. And we don't use 100% but 98%
   maxlot = MathMin ( MathFloor ( availablemoney * 0.98 / MarginForOneLot / LotStep ) * LotStep, MaxLots );
   // Minimum allowed Lot by the broker
   minlot = MinLots;

   // Lot according to Risk. Don't use 100% but 98% (= 102) to avoid
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
 */
void CheckLastError() {
   switch (GetLastError()) {
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
 * Check through all open orders
 */
void UpdateOpenOrderStats() {
   int pos;
   double tmp_order_lots;
   double tmp_order_price;

   // Get total number of open orders
   Tot_Orders = OrdersTotal();

   // Reset counters
   Tot_open_pos = 0;
   Tot_open_profit = 0;
   Tot_open_lots = 0;
   Tot_open_swap = 0;
   Tot_open_commission = 0;
   G_equity = 0;
   Changedmargin = 0;

   // Loop through all open orders from first to last
   for ( pos = 0; pos < Tot_Orders; pos ++ )
   {
      // Select on order
      if ( OrderSelect ( pos, SELECT_BY_POS, MODE_TRADES ) )
      {

         // Check if it matches the MagicNumber
         if ( OrderMagicNumber() == Magic && OrderSymbol() == Symbol() )    // If the orders are for this EA
         {
            // Calculate sum of open orders, open profit, swap and commission
            Tot_open_pos ++;
            tmp_order_lots = OrderLots();
            Tot_open_lots += tmp_order_lots;
            tmp_order_price = OrderOpenPrice();
            Tot_open_profit += OrderProfit();
            Tot_open_swap += OrderSwap();
            Tot_open_commission += OrderCommission();
            Changedmargin += tmp_order_lots * tmp_order_price;
         }
      }
   }
   // Calculate Balance and Equity for this EA and not for the entire account
   G_equity = G_balance + Tot_open_profit + Tot_open_swap + Tot_open_commission;

}


/**
 * Check through all closed orders
 */
void UpdateClosedOrderStats() {
   int openTotal = OrdersHistoryTotal();

   Tot_closed_pos    = 0;
   Tot_closed_lots   = 0;
   Tot_closed_profit = 0;
   Tot_closed_swap   = 0;
   Tot_closed_comm   = 0;
   G_balance         = 0;

   // Loop through all closed orders
   for (int pos=0; pos < openTotal; pos++) {
      // Select an order
      if (OrderSelect(pos, SELECT_BY_POS, MODE_HISTORY)) {                 // Loop through the order history
         // If the MagicNumber matches
         if (OrderMagicNumber()==Magic && OrderSymbol()==Symbol()) {       // If the orders are for this EA
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
 *
 * @param  int error [optional] - error to display (default: none)
 *
 * @return int - the same error or the current error status if no error was passed
 */
int ShowStatus(int error = NO_ERROR) {
   string line1 = EA_version;
   string line2 = "Open: " + DoubleToStr ( Tot_open_pos, 0 ) + " positions, " + DoubleToStr ( Tot_open_lots, 2 ) + " lots with value: " + DoubleToStr ( Tot_open_profit, 2 );
   string line3 = "Closed: " + DoubleToStr ( Tot_closed_pos, 0 ) + " positions, " + DoubleToStr ( Tot_closed_lots, 2 ) + " lots with value: " + DoubleToStr ( Tot_closed_profit, 2 );
   string line4 = "EA Balance: " + DoubleToStr ( G_balance, 2 ) + ", Swap: " + DoubleToStr ( Tot_open_swap, 2 ) + ", Commission: " + DoubleToStr ( Tot_open_commission, 2 );
   string line5 = "EA Equity: " + DoubleToStr ( G_equity, 2 ) + ", Swap: " + DoubleToStr ( Tot_closed_swap, 2 ) + ", Commission: "  + DoubleToStr ( Tot_closed_comm, 2 );
   string line6 = "                               ";
   string line7 = "Min allowed Margin level: " + DoubleToStr ( MinMarginLevel, 2 ) + "%";
   string line8 = "Margin value: " + DoubleToStr ( Changedmargin, 2 );

   int textspacing=10, x=3, y=10;
   CreateLabel("line1", line1, Heading_Size, x, y, Color_Heading ); y = textspacing * 2 + Text_Size * 1 + 3 * 1;
   CreateLabel("line2", line2, Text_Size,    x, y, Color_Section1); y = textspacing * 2 + Text_Size * 2 + 3 * 2 + 20;
   CreateLabel("line3", line3, Text_Size,    x, y, Color_Section2); y = textspacing * 2 + Text_Size * 3 + 3 * 3 + 40;
   CreateLabel("line4", line4, Text_Size,    x, y, Color_Section3); y = textspacing * 2 + Text_Size * 4 + 3 * 4 + 40;
   CreateLabel("line5", line5, Text_Size,    x, y, Color_Section3); y = textspacing * 2 + Text_Size * 5 + 3 * 5 + 40;
   CreateLabel("line6", line6, Text_Size,    x, y, Color_Section4); y = textspacing * 2 + Text_Size * 6 + 3 * 6 + 40;
   CreateLabel("line7", line7, Text_Size,    x, y, Color_Section4); y = textspacing * 2 + Text_Size * 7 + 3 * 7 + 40;
   CreateLabel("line8", line8, Text_Size,    x, y, Color_Section4);

   if (!error)
      return(last_error);
   return(error);
}


/**
 * Display graphics on the chart.
 */
void CreateLabel(string label, string text, int fontSize, int x, int y, color fontColor) {
   label = WindowExpertName() +"."+ label;
   ObjectCreate (label, OBJ_LABEL, 0, 0, 0, 0, 0);
   ObjectSet    (label, OBJPROP_CORNER, CORNER_TOP_LEFT);
   ObjectSet    (label, OBJPROP_XDISTANCE, x);
   ObjectSet    (label, OBJPROP_YDISTANCE, y);
   ObjectSetText(label, text, fontSize, "Tahoma", fontColor);
   RegisterObject(label);
}
