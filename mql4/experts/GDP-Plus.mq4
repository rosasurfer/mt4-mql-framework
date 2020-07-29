/**
 * "GazillionDollarPips" (GDP) is a "MillionDollarPips" EA revisited
 *
 *
 * An EA based on the probably single most famous MetaTrader EA ever written. Nothing remains from the original except the
 * core idea of the strategy: scalping based on a reversal from a channel breakout.
 *
 * Today various versions of the original EA circulate in the internet by various names (MDP-Plus, XMT, Assar). However all
 * known versions are so fundamentally flawed that they must never be run on a live account. This GDP version is fully
 * embedded in the rosasurfer MQL4 framework. It fixes the existing issues, replaces all parts with more robust or faster
 * components and adds major improvements for production use.
 *
 * Sources:
 *  The original versions are included in the repo and accessible via the Git history. Use ONLY for reference:
 *
 *  @link  https://github.com/rosasurfer/mt4-mql/blob/a1b22d0/mql4/experts/mdp              [MillionDollarPips v2 decompiled]
 *  @link  https://github.com/rosasurfer/mt4-mql/blob/36f494e/mql4/experts/mdp               [MDP-Plus v2.2 + PDF by Capella]
 *  @link  https://github.com/rosasurfer/mt4-mql/blob/41237e0/mql4/experts/mdp          [XMT-Scalper v2.522 + PDF by Capella]
 *
 *
 * Fixes/changes (wip):
 * - embedded in MQL4 framework
 * - moved all error tracking/handling to the framework
 * - moved all Print() output to the framework logger
 * - fixed validation of symbol digits
 * - fixed processing logic of open orders and removed redundant parts
 * - fixed stoploss calculations
 * - replaced invalid commission calculation by framework functionality and removed input parameter "Commission"
 * - removed input parameter "MinMarginLevel" to continue managing open positions during critical drawdowns
 * - removed obsolete NDD functionality
 * - removed obsolete order expiration time
 * - removed useless sending of speed test orders
 * - removed measuring execution times and trade suspension on delays (framework handling is better)
 * - removed screenshot functionality (framework logging is better)
 * - removed obsolete input parameter "UseVolatilityPercentage"
 * - removed obsolete input parameter "Verbose"
 *
 * - renamed input parameter UseDynamicVolatilityLimit => UseDynamicMinBarSize
 * - renamed input parameter VolatilityMultiplier      => DynamicMinBarSizeMultiplier
 * - reanmed input parameter VolatilityLimit           => FixMinBarSize
 * - reanmed input parameter VolatilityPercentageLimit => MinBarSizePercent
 * - renamed input parameter UseIndicatorSwitch        => EntryIndicator
 */
#include <stddefines.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern string  ___a_______________________ = "==== General ====";
extern bool    Debug                       = false;      //

extern string  ___b_______________________ = "==== MinBarSize settings ====";
extern bool    UseDynamicMinBarSize        = true;       // TRUE:  minBarSize = (DynamicMinBarSizeMultiplier * AvgSpreadPlusCommission)
extern double  DynamicMinBarSizeMultiplier = 12.5;       //
extern int     FixMinBarSize               = 180;        // FALSE: minBarSize = FixMinBarSize in point
extern int     MinBarSizePercent           = 0;          // by how many percent the bar size must exceed MinBarSize

extern string  ___c_______________________ = "=== Indicators: 1=Moving Average, 2=BollingerBand, 3=Envelopes";
extern int     EntryIndicator              = 1;          // indicator selection for channel calculation
extern int     TimeFrame                   = PERIOD_M1;  // must match the timeframe of the chart
extern int     Indicatorperiod             = 3;          // Period in bars for indicator
extern double  BBDeviation                 = 2;          // Deviation for the iBands indicator only
extern double  EnvelopesDeviation          = 0.07;       // Deviation for the iEnvelopes indicator only

extern string  ___d_______________________ = "==== MoneyManagement ====";
extern bool    MoneyManagement             = true;       // If TRUE calculate lotsize based on Risk, if FALSE use ManualLotsize
extern double  Risk                        = 2;          // Risk setting in percentage, for 10.000 in Equity 10% Risk and 60 StopLoss lotsize = 16.66
extern double  MinLots                     = 0.01;       // Minimum lotsize to trade with
extern double  MaxLots                     = 100;        // Maximum allowed lotsize to trade with
extern double  ManualLotsize               = 0.1;        // Fixed lotsize to trade with if MoneyManagement is set to FALSE

extern string  ___e_______________________ = "==== Trade settings ====";
extern bool    ReverseTrade                = false;      // If TRUE, then trade in opposite direction
extern double  StopLoss                    = 60;         // SL in points. Default 60 (= 6 pip)
extern double  TakeProfit                  = 100;        // TP in points. Default 100 (= 10 pip)
extern double  AddPriceGap                 = 0;          // Additional price gap in points added to SL and TP in order to avoid Error 130
extern double  TrailingStart               = 20;         // Start trailing profit from as so many points.
extern int     Slippage                    = 3;          // Maximum allowed Slippage of price in points
extern int     Magic                       = -1;         // If set to a number less than 0 it will calculate MagicNumber automatically
extern double  MinimumUseStopLevel         = 0;          // Stoplevel to use will be max value of either this value or broker stoplevel
extern double  MaxSpread                   = 30;         // Max allowed spread in points

extern string  ___f_______________________ = "=== Display Graphics ===";
extern int     StatusFontSize              = 10;         //
extern color   StatusFontColor             = Blue;       //

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/expert.mqh>
#include <stdfunctions.mqh>
#include <rsfLibs.mqh>

#define SIGNAL_LONG     1
#define SIGNAL_SHORT    2


// PL statistics
int    openPositions;            // number of open positions
double openLots;                 // open lotsize
double openPl;                   // floating PL
int    closedPositions;          // number of closed positions
double closedLots;               // closed lotsize
double closedPl;                 //
double totalPl;                  // openPl + closedPl

// order/trade data
string orderComment = "GDP";
double commissionMarkup;         // commission markup in quote currency, e.g. 0.0000'41


// --- old ------------------------------------------------------------------------------------------------------------------
double spreads[30];              // Store spreads for the last 30 tics
int    UpTo30Counter;            // For calculating average spread

double LotBase;                  // Amount of money in base currency for 1 lot
double highest;                  // Highest indicator value
double lowest;                   // Lowest indicator value
double StopLevel;                // Broker StopLevel
double LotStep;                  // Broker LotStep
double MarginForOneLot;          // Margin required for 1 lot


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   // validate inputs
   if (Period() != TimeFrame)                    return(catch("onInit(1)  Invalid input parameter TimeFrame: "+ TimeframeDescription(TimeFrame) +" (must match the chart timeframe "+ TimeframeDescription(Period()) +")", ERR_INVALID_INPUT_PARAMETER));
   if (UseDynamicMinBarSize) {
      if (DynamicMinBarSizeMultiplier <= 0)      return(catch("onInit(2)  Invalid input parameter DynamicMinBarSizeMultiplier: "+ DynamicMinBarSizeMultiplier +" (UseDynamicMinBarSize=On)", ERR_INVALID_INPUT_PARAMETER));
   }
   else {
      if (FixMinBarSize <= 0)                    return(catch("onInit(3)  Invalid input parameter FixMinBarSize: "+ FixMinBarSize +" (UseDynamicMinBarSize=Off)", ERR_INVALID_INPUT_PARAMETER));
   }
   if (MinBarSizePercent < 0)                    return(catch("onInit(4)  Invalid input parameter MinBarSizePercent: "+ MinBarSizePercent, ERR_INVALID_INPUT_PARAMETER));
   if (EntryIndicator < 1 || EntryIndicator > 3) return(catch("onInit(5)  Invalid input parameter EntryIndicator: "+ EntryIndicator +" (not from 1-3)", ERR_INVALID_INPUT_PARAMETER));


   // Calculate StopLevel as max of either STOPLEVEL or FREEZELEVEL
   StopLevel = MathMax ( MarketInfo ( Symbol(), MODE_FREEZELEVEL ), MarketInfo ( Symbol(), MODE_STOPLEVEL ) );
   // Then calculate the StopLevel as max of either this StopLevel or MinimumUseStopLevel
   StopLevel = MathMax ( MinimumUseStopLevel, StopLevel );

   // Calculate LotStep
   LotStep = MarketInfo ( Symbol(), MODE_LOTSTEP );

   // Adjust SL and TP to broker StopLevel if they are less than this StopLevel
   StopLoss = MathMax ( StopLoss, StopLevel );
   TakeProfit = MathMax ( TakeProfit, StopLevel );

   // initialize variables
   ArrayInitialize(spreads, 0);
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
   if (Magic < 0) Magic = GenerateMagicNumber();                  // If magic number is set to a value less than 0, then generate a new MagicNumber
   commissionMarkup = GetCommission(1, COMMISSION_MODE_MARKUP);

   UpdatePlStats();
   ShowStatus();

   return(catch("onInit(6)"));
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
 * @return int - error status
 */
int MainFunction() {
   int orderticket;

   double orderprice;
   double orderstoploss;
   double ordertakeprofit;
   double imalow = 0;
   double imahigh = 0;
   double imadiff;
   double ibandsupper = 0;
   double ibandslower = 0;
   double ibandsdiff;
   double envelopesupper = 0;
   double envelopeslower = 0;
   double envelopesdiff;

   bool isbidgreaterthanindy = false;  // reset indicator breakout variable
   string indy = "";                   // reset indicator log message

   if (EntryIndicator == 1) {
      // Calculate a channel on Moving Averages, and check if the price is outside of this channel.
      imalow = iMA ( Symbol(), TimeFrame, Indicatorperiod, 0, MODE_LWMA, PRICE_LOW, 0 );
      imahigh = iMA ( Symbol(), TimeFrame, Indicatorperiod, 0, MODE_LWMA, PRICE_HIGH, 0 );
      imadiff = imahigh - imalow;
      if (Bid >= imalow + imadiff/2) {
         isbidgreaterthanindy = true;
         highest = imahigh;
         lowest = imalow;
      }
      indy = "iMA_low: " + DoubleToStr(imalow, Digits) + ", iMA_high: " + DoubleToStr(imahigh, Digits) + ", iMA_diff: " + DoubleToStr(imadiff, Digits);
   }
   else if (EntryIndicator == 2) {
      // Calculate a channel on BollingerBands, and check if the price is outside of this channel
      ibandsupper = iBands ( Symbol(), TimeFrame, Indicatorperiod, BBDeviation, 0, PRICE_OPEN, MODE_UPPER, 0 );
      ibandslower = iBands ( Symbol(), TimeFrame, Indicatorperiod, BBDeviation, 0, PRICE_OPEN, MODE_LOWER, 0 );
      ibandsdiff = ibandsupper - ibandslower;
      if (Bid >= ibandslower + ibandsdiff/2) {
         isbidgreaterthanindy = true;
         highest = ibandsupper;
         lowest = ibandslower;
      }
      indy = "iBands_upper: " + DoubleToStr(ibandsupper, Digits) + ", iBands_lower: " + DoubleToStr(ibandslower, Digits) + ", iBands_diff: " + DoubleToStr(ibandsdiff, Digits);
   }
   else if (EntryIndicator == 3) {
      // Calculate a channel on Envelopes, and check if the price is outside of this channel
      envelopesupper = iEnvelopes ( Symbol(), TimeFrame, Indicatorperiod, MODE_LWMA, 0, PRICE_OPEN, EnvelopesDeviation, MODE_UPPER, 0 );
      envelopeslower = iEnvelopes ( Symbol(), TimeFrame, Indicatorperiod, MODE_LWMA, 0, PRICE_OPEN, EnvelopesDeviation, MODE_LOWER, 0 );
      envelopesdiff = envelopesupper - envelopeslower;
      if (Bid >= envelopeslower + envelopesdiff/2) {
         isbidgreaterthanindy = true;
         highest = envelopesupper;
         lowest = envelopeslower;
      }
      indy = "iEnvelopes_upper: " + DoubleToStr(envelopesupper, Digits) + ", iEnvelopes_lower: " + DoubleToStr(envelopeslower, Digits) + ", iEnvelopes_diff: " + DoubleToStr(envelopesdiff, Digits);
   }


   // Loop through open orders to either modify or delete them
   double bidMinusCommission = Bid - commissionMarkup;
   double askPlusCommission  = Ask + commissionMarkup;
   double spread             = Ask - Bid;
   int    openOrders         = 0;

   for (int i=0; i < OrdersTotal(); i++) {
      OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
      if (OrderMagicNumber()==Magic && OrderSymbol()==Symbol()) {

         switch (OrderType()) {
            case OP_BUY:
               orderstoploss   = OrderStopLoss();
               ordertakeprofit = OrderTakeProfit();
               // modify the order if its TP is less than the price+commission+StopLevel AND price+StopLevel-TP greater than trailingStart
               if (LT(ordertakeprofit, askPlusCommission + TakeProfit*Point + AddPriceGap, Digits) && GT(askPlusCommission + TakeProfit*Point + AddPriceGap - ordertakeprofit, TrailingStart, Digits)) {
                  // Set SL and TP
                  orderstoploss   = NormalizeDouble(Bid - StopLoss*Point - AddPriceGap, Digits);
                  ordertakeprofit = NormalizeDouble(askPlusCommission + TakeProfit*Point + AddPriceGap, Digits);
                  if (orderstoploss!=OrderStopLoss() && ordertakeprofit!=OrderTakeProfit()) {
                     if (!OrderModify(OrderTicket(), 0, orderstoploss, ordertakeprofit, NULL, Lime))
                        return(catch("MainFunction(1)->OrderModify()"));
                  }
               }
               openOrders++;
               RefreshRates();
               break;

            case OP_SELL:
               orderstoploss   = OrderStopLoss();
               ordertakeprofit = OrderTakeProfit();
               // modify the order if its TP is greater than price-commission-StopLevel AND TP-price-commission+StopLevel is greater than trailingstart
               if (GT(ordertakeprofit, bidMinusCommission-TakeProfit*Point-AddPriceGap, Digits) && GT(ordertakeprofit-bidMinusCommission+TakeProfit*Point-AddPriceGap, TrailingStart, Digits)) {
                  // set SL and TP
                  orderstoploss   = NormalizeDouble(Ask + StopLoss*Point + AddPriceGap, Digits);
                  ordertakeprofit = NormalizeDouble(bidMinusCommission - TakeProfit*Point - AddPriceGap, Digits);
                  if (orderstoploss!=OrderStopLoss() && ordertakeprofit!=OrderTakeProfit()) {
                     if (!OrderModify(OrderTicket(), 0, orderstoploss, ordertakeprofit, NULL, Orange))
                        return(catch("MainFunction(2)->OrderModify()"));
                  }
               }
               openOrders++;
               RefreshRates();
               break;

            case OP_BUYSTOP:
               // Price must NOT be larger than indicator in order to modify the order, otherwise the order will be deleted
               if (!isbidgreaterthanindy) {
                  // Calculate how much Price, SL and TP should be modified
                  orderprice      = NormalizeDouble(Ask + StopLevel + AddPriceGap, Digits);
                  orderstoploss   = NormalizeDouble(orderprice - spread - StopLoss*Point - AddPriceGap, Digits);
                  ordertakeprofit = NormalizeDouble(orderprice + commissionMarkup + TakeProfit*Point + AddPriceGap, Digits);
                  // modify the order if price+StopLevel is less than orderprice AND orderprice-price-StopLevel is greater than trailingstart
                  if (orderprice < OrderOpenPrice() && OrderOpenPrice()-orderprice > TrailingStart) {
                     if (orderstoploss!=OrderStopLoss() && ordertakeprofit!=OrderTakeProfit()) {
                        if (!OrderModify(OrderTicket(), orderprice, orderstoploss, ordertakeprofit, 0, Lime))
                           return(catch("MainFunction(3)->OrderModify()"));
                     }
                  }
                  openOrders++;
               }
               else if (!OrderDelete(OrderTicket())) return(catch("MainFunction(4)->OrderDelete()"));
               RefreshRates();
               break;

            case OP_SELLSTOP:
               // Price must be larger than the indicator in order to modify the order, otherwise the order will be deleted
               if (isbidgreaterthanindy) {
                  // Calculate how much Price, SL and TP should be modified
                  orderprice      = NormalizeDouble(Bid - StopLevel - AddPriceGap, Digits);
                  orderstoploss   = NormalizeDouble(orderprice + spread + StopLoss*Point + AddPriceGap, Digits);
                  ordertakeprofit = NormalizeDouble(orderprice - commissionMarkup - TakeProfit*Point - AddPriceGap, Digits);
                  // modify order if price-StopLevel is greater than orderprice AND price-StopLevel-orderprice is greater than trailingstart
                  if (orderprice > OrderOpenPrice() && orderprice-OrderOpenPrice() > TrailingStart) {
                     if (orderstoploss!=OrderStopLoss() && ordertakeprofit!=OrderTakeProfit()) {
                        if (!OrderModify(OrderTicket(), orderprice, orderstoploss, ordertakeprofit, 0, Orange))
                           return(catch("MainFunction(5)->OrderModify()"));
                     }
                  }
                  openOrders++;
               }
               else if (!OrderDelete(OrderTicket())) return(catch("MainFunction(6)->OrderDelete()"));
               RefreshRates();
               break;
         }
      }
   }


   // calculate the average spread
   RefreshRates();
   spread = Ask - Bid;
   ArrayCopy(spreads, spreads, 0, 1, 29);
   spreads[29] = spread;
   if (UpTo30Counter < 30)
      UpTo30Counter++;
   double sumofspreads = 0;
   int loopcount2 = 29;
   for (i=0; i < UpTo30Counter; i++) {
      sumofspreads += spreads[loopcount2];
      loopcount2--;
   }
   double avgspread     = sumofspreads / UpTo30Counter;
   double realavgspread = avgspread + commissionMarkup;


   // If we have no open orders check the bar size limit, the current spread and trade signals
   if (!openOrders) {
      int tradeSignal = 0;

      double minBarSize, barSize=High[0] - Low[0];
      if (UseDynamicMinBarSize) minBarSize = realavgspread * DynamicMinBarSizeMultiplier;
      else                      minBarSize = FixMinBarSize * Point;
      if (barSize > minBarSize) {
         if (barSize/minBarSize >= (1 + MinBarSizePercent/100.0)) {
            if      (Bid < lowest ) tradeSignal = ifInt(ReverseTrade, SIGNAL_SHORT, SIGNAL_LONG);
            else if (Bid > highest) tradeSignal = ifInt(ReverseTrade, SIGNAL_LONG, SIGNAL_SHORT);
         }
      }

      if (tradeSignal && LE(realavgspread, MaxSpread*Point, Digits)) {
         RefreshRates();
         double lotsize = CalculateLotsize();

         if (tradeSignal == SIGNAL_LONG) {
            orderprice      = Ask + StopLevel;
            orderstoploss   = NormalizeDouble(orderprice - spread - StopLoss*Point - AddPriceGap, Digits);
            ordertakeprofit = NormalizeDouble(orderprice + TakeProfit*Point + AddPriceGap, Digits);
            if (!OrderSend(Symbol(), OP_BUYSTOP, lotsize, orderprice, Slippage, orderstoploss, ordertakeprofit, orderComment, Magic, NULL, Lime))
               return(catch("MainFunction(7)->OrderSend()"));
            openOrders++;
         }

         if (tradeSignal == SIGNAL_SHORT) {
            orderprice      = Bid - StopLevel;
            orderstoploss   = NormalizeDouble(orderprice + spread + StopLoss*Point + AddPriceGap, Digits);
            ordertakeprofit = NormalizeDouble(orderprice - TakeProfit*Point - AddPriceGap, Digits);
            if (!OrderSend(Symbol(), OP_SELLSTOP, lotsize, orderprice, Slippage, orderstoploss, ordertakeprofit, orderComment, Magic, NULL, Orange))
               return(catch("MainFunction(8)->OrderSend()"));
            openOrders++;
         }
      }
   }


   // Print debug infos if we have open orders or a price breakout
   string signalDescriptions[] = {"-", "Long", "Short"};

   if (Debug && (openOrders || tradeSignal)) {
      string text = TimeToStr(TimeCurrent())
                  + ",  MinBarSize: "+ DoubleToStr(minBarSize/Pip, 2) +" pip,  current bar: "+ DoubleToStr(barSize/Pip, 1) +" pip"
                  + ",  TradeSignal: "+ signalDescriptions[tradeSignal] +",  open orders: "+ openOrders
                  +  ",  "+ indy
                  + ",  AvgSpread: "+ DoubleToStr(avgspread, Digits) +",  RealAvgSpread: "+ DoubleToStr(realavgspread, Digits);

      if (GT(realavgspread, MaxSpread*Point, Digits)) {
         text = text +", Current spread (" + DoubleToStr(realavgspread, Digits) +") is higher than the configured MaxSpread ("+ DoubleToStr(MaxSpread*Point, Digits) +"), trading is suspended.";
      }
      debug("MainFunction(9)  "+ text);
   }

   return(catch("MainFunction(10)"));
}


/**
 * Calculate lot multiplicator for Account Currency. Assumes that account currency is any of the 8 majors.
 * If the account currency is of any other currency, then calculate the multiplicator as follows:
 * If base-currency is USD then use the BID-price for the currency pair USDXXX; or if the
 * counter currency is USD the use 1 / BID-price for the currency pair XXXUSD,
 * where XXX is the abbreviation for the account currency. The calculated lot-size should
 * then be multiplied with this multiplicator.
 *
 * @return double - multiplier value or NULL in case of errors
 */
double GetLotsizeMultiplier() {
   double rate;
   string symbolSuffix = StrRight(Symbol(), -6);

   if      (AccountCurrency() == "USD") rate = 1;
   if      (AccountCurrency() == "EUR") rate = MarketInfo("EURUSD"+ symbolSuffix, MODE_BID);
   else if (AccountCurrency() == "GBP") rate = MarketInfo("GBPUSD"+ symbolSuffix, MODE_BID);
   else if (AccountCurrency() == "AUD") rate = MarketInfo("AUDUSD"+ symbolSuffix, MODE_BID);
   else if (AccountCurrency() == "NZD") rate = MarketInfo("NZDUSD"+ symbolSuffix, MODE_BID);
   else if (AccountCurrency() == "CHF") rate = MarketInfo("USDCHF"+ symbolSuffix, MODE_BID);
   else if (AccountCurrency() == "JPY") rate = MarketInfo("USDJPY"+ symbolSuffix, MODE_BID);
   else if (AccountCurrency() == "CAD") rate = MarketInfo("USDCAD"+ symbolSuffix, MODE_BID);
   else return(!catch("GetLotsizeMultiplier(1)  Unable to fetch Bid price for "+ AccountCurrency(), ERR_INVALID_MARKET_DATA));

   if (!rate) return(!catch("GetLotsizeMultiplier(2)  Unable to fetch Bid price for "+ AccountCurrency(), ERR_INVALID_MARKET_DATA));
   return(1/rate);
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

   catch("GenerateMagicNumber(2)");
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
   lotsize = lotsize * GetLotsizeMultiplier(); if (!lotsize) return(NULL);
   lotsize = NormalizeLots(lotsize);

   // Use manual fix LotSize, but if necessary adjust to within limits
   if (!MoneyManagement) {
      // Set LotSize to manual LotSize
      lotsize = ManualLotsize;

      // Check if ManualLotsize is greater than allowed LotSize
      if (ManualLotsize > maxlot) {
         lotsize = maxlot;
         warn("CalculateLotsize(1)  Manual LotSize is too high. It has been recalculated to maximum allowed "+ DoubleToStr(maxlot, 2));
         ManualLotsize = maxlot;
      }
      else if (ManualLotsize < minlot) {
         lotsize = minlot;
      }
   }

   if (!catch("CalculateLotsize(1)"))
      return(lotsize);
   return(NULL);
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
         warn("RecalculateRisk(1)  "+ textstring);
      }
      // If Risk% is less than the minimum risklevel the broker accept, then adjust Risk accordingly and print out changes
      if (Risk < minrisk)
      {
         textstring = textstring + "Note: Risk has manually been set to " + DoubleToStr ( Risk, 1 ) + " but cannot be lower than " + DoubleToStr ( minrisk, 1 ) + " according to ";
         textstring = textstring + "the broker, StopLoss, AddPriceGap and Equity. It has now been adjusted accordingly to " + DoubleToStr ( minrisk, 1 ) + "%";
         Risk = minrisk;
         warn("RecalculateRisk(2)  "+ textstring);
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
         warn("RecalculateRisk(3)  "+ textstring);
      }
      if ( ManualLotsize > MaxLots )
      {
         textstring = "Manual LotSize " + DoubleToStr ( ManualLotsize, 2 ) + " cannot be greater than " + DoubleToStr ( MaxLots, 2 ) + ". It has now been adjusted to " + DoubleToStr ( MinLots, 2 );
         ManualLotsize = MaxLots;
         warn("RecalculateRisk(4)  "+ textstring);
      }
      // Check to see that manual LotSize does not exceeds maximum allowed LotSize
      if ( ManualLotsize > maxlot )
      {
         textstring = "Manual LotSize " + DoubleToStr ( ManualLotsize, 2 ) + " cannot be greater than maximum allowed LotSize. It has now been adjusted to " + DoubleToStr ( maxlot, 2 );
         ManualLotsize = maxlot;
         warn("RecalculateRisk(5)  "+ textstring);
      }
   }
   catch("RecalculateRisk(6)");
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

   catch("UpdatePlStats(1)");
}


/**
 * Printout graphics on the chart
 *
 * @param  int error [optional] - error to display (default: none)
 *
 * @return int - the same error or the current error status if no error was passed
 */
int ShowStatus(int error = NO_ERROR) {
   if (!__CHART()) return(error);

   string sError = "";
   if      (__STATUS_INVALID_INPUT) sError = StringConcatenate("  [",                 ErrorDescription(ERR_INVALID_INPUT_PARAMETER), "]");
   else if (__STATUS_OFF          ) sError = StringConcatenate("  [switched off => ", ErrorDescription(__STATUS_OFF.reason        ), "]");

   string line1 = WindowExpertName() + sError;
   string line2 = "Open PL:   "+ openPositions   +" positions ("+ NumberToStr(openLots,   ".0+") +" lot)   PL="+ DoubleToStr(openPl, 2);
   string line3 = "Closed PL: "+ closedPositions +" positions ("+ NumberToStr(closedLots, ".0+") +" lot)   PL="+ DoubleToStr(closedPl, 2);
   string line4 = "Total PL:  "+ DoubleToStr(totalPl, 2);

   int spacing=20, x=3, y=10;
   ShowStatus.CreateLabel("line1", line1, x, y); y = spacing + StatusFontSize * 1 + 3 * 1;
   ShowStatus.CreateLabel("line2", line2, x, y); y = spacing + StatusFontSize * 2 + 3 * 2 + 20;
   ShowStatus.CreateLabel("line3", line3, x, y); y = spacing + StatusFontSize * 3 + 3 * 3 + 40;
   ShowStatus.CreateLabel("line4", line4, x, y);

   if (!catch("ShowStatus(1)"))
      return(error);
   return(last_error);
}


/**
 * Display graphics on the chart.
 */
void ShowStatus.CreateLabel(string label, string text, int x, int y) {
   label = WindowExpertName() +"."+ label;

   if (ObjectFind(label) != 0) {
      ObjectCreate(label, OBJ_LABEL, 0, 0, 0);
      RegisterObject(label);
   }
   ObjectSet    (label, OBJPROP_CORNER, CORNER_TOP_LEFT);
   ObjectSet    (label, OBJPROP_XDISTANCE, x);
   ObjectSet    (label, OBJPROP_YDISTANCE, y);
   ObjectSetText(label, text, StatusFontSize, "Tahoma", StatusFontColor);
}
