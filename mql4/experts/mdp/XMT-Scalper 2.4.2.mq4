// -------------------------------------------------------------------------------------------------
//                                   XMT-Scalper v. 2.4.2
//
//                                       by Capella
//                             http://www.worldwide-invest.org
//                                  Copyright 2011 - 2013
//
//--------------------------------------------------------------------------------------------------
//   THIS EA IS SHAREWARE, WHICH MEANS THAT IT'S NOT A COMMERCIAL PRODUCT, BUT STILL COPYRIGHTED
// -------------------------------------------------------------------------------------------------
//
// About Capella:
//
// I'm a professional system analyst / computer programmer + fund manager and fx trader living
// in Sweden, with a background as a teacher in computer science, programming and mathematics, etc.
// I can be reached at the above financial forum.
//
// Editing:
//
// Note: For readability in MetaEditor, set Tools > Options > General, Tab size = 3 spaces and
// Font = Courier New 10. BTW, I use Notepad++ as the editor (highly recommended).
//
// Your suggestions:
//
// If you're a programmer and have suggestions for improvements, then please have the courtasy to
// share this and upload the new mq4-file to the above forum. Add a letter "a", "b", etc. to the
// version number to distinguish it from the official releases. Be sure to comment every line of
// code, and add your version comment at the end of the version list. Your contribution will be
// honored. All further releases will be posted on the above forum, as well as all feedback from
// users.
//
// Origin:
//
// The EA was originally based on the EA MillionDollarPips - but now totally rewritten from scratch.
// Not much remains from the original, except the core of the trading strategy.
//
//--------------------------------------------------------------------------------------------------
//
// Version history:
//
// Someone at a russian forum fixed a Stack Overflow problem, added NDD-mode (ECN-mode)
// and moved the DLL-functions in the mql4-code, and uploaded "MillionDollarPips -
// (ANY PAIR + NO DLL) - ver 1.1.0".
//
// Sept-2011 by Capella
// - Cleaned code from unused code, proper variable names and sub-names.
//
// Ver. 1.0 - 2011-09-24 by
// - Added Print lines for STOPLEVEL when errors (for debugging purposes)
// - Removed unused externals and variables
// - Moved dynamic TP/SL and trading signals constants to externals,
//   as VolatilityLimit and Scalpfactor.
// - Forced TrailingStop
//
// Ver. 2.0 - 2011-10-19 by Capella
// - Fixing bugs, and removed unused code.
// - Forced Trailing, as no-trailing cannot generate profit
// - Forced HighSpeed, as false mode cannot give good result
// - Added additional settings for scalping - UseMovingAverage,
//   UseBollingerBands, and OrderExpireSeconds
// - Automatic adjusted to broker STOPLEVEL, to avoid OrderSend error 130
// Ver 2.1 - 2011-11-91 by Capella
// - Added Indicatorperiod as external
// - Modified calculation of variable that triggers trade (local_pricedirection)
// - Removed Distance as an external, and automatically adjust Distance to be the same as stoplevel
// - Removed call for sub_moveandfillarrays as it doesn't make any difference
// Ver 2.1.1 - 2011-11-05 by Capella
// - Fixed a bug in the calculation of highest and lowest that caused wrong call for
//   OrderModify.
// - Changed the calculation of STOPLEVEL to also consider FREEZELEVEL
// Ver 2.1.2 - 2011-11-06 by Capella
// - Changed default settings according to optimized backtests
// - Added external parameter Deviation for iBands, default 0
// Ver 2.1.3 - 2011-11-07 by Capella
// - Fixed a bug for calculation of local_isbidgreaterthanindy
// Ver 2.1.4 - 2011-11-09 by Capella
// - Fixed a bug that only made the robot trade on SELL and SELLSTOP
// - Put back the call for the sub "sub_moveandfillarrays" except the last nonsense part of it.
// - Changed the default settings and re-ordered the global variables
// Ver 2.1.5 - 2011-11-10 by Capella
// - Fixed a bug that caused the robot to not trade for some brokers (if variable "local_scalpsize"
//   was 0.0)
// - Fixed a bug that could cause the lot-size to be calculated wrongly
// - Better output of debug information (more information)
// - Moved a fixed internal Max Spread to an external. The default internal value was 40 (4 pips),
//   which is too high IMHI
// - Renamed some local variables to more proper names in order to make the code more readable
// - Cleaaned code further by removing unused code, etc.
// Ver 2.1.5a - 2011-11-15 by blueprint1972
// - Added Execution time in log files, to measure how fast orders are executed at the broker server
//
// Ver 2.2 - 2011-11-17 by Capella
// - An option to calculate VelocityLimit dynamically based on the spread
// - Removed parameter Scalpfactor as it had no impact on the trading conditions, only on lotsize
// - Better lot calculation, now entirely based on FreeMargin, Risk and StopLoss
// - A new scalp factor called VolatilityPercentageLimit based on the difference between
//   VolatilityLimit and iHigh / iLow for triggering trades
// - Can now trade automatically on all currency pairs within spread limit from one single chart
// - Works on 4-digit brokers as well. Note: Performance on 4-digit brokers is worse than on
//   5-digit brokers, and there are much less trades
// Ver 2.2.1 - 2011-11-18 by Capella
// - Fixed a bug for calculation of Commission. The variables "local_commissionpips" and
//   "local_commissionfactor" moved from locals to globals.
// Ver 2.2.1.2 - 2011-11-18 by Sonik
// - Added Screenshot Functionality (Tested and Working So Far)
// Ver 2.2.2 - 2011-11-19 by Capella
// - Added automatic calculation of MagicNumber as an option
// - Adjust MinLot to broker minimum
// - Correction of lotsize calculation according to broker lotstep
// Ver 2.2.3 - 2011-11-21 by Capella
// - Fixed bug for calculation of lotsize calculation according to broker lotstep
// - Added broker Comission as an external parameter, and corected the calculation
// - Re-arrranged some code - moving parts to subroutines
// Ver 2.2.4 - 2011-11-23 by Capella
// - Improved performance for higher spreads
// - Cleaned code further and moved parts of code to subroutines
// Ver 2.2.4a - 2011-11-24 by blueprint
// - Added execution control
// Ver 2.2.4b - 2011-11-24 by Pannik
// - Added possibility to use manual fixed lots
// Ver 2.2.5 - 2011-11-25 by Capella
// - Fixed bug for too small lotsize and wrong Risk settings
// - Changed randomized execution time for backtests to be within 0 and MaxExecution
// - Cleaned the code further
// Ver 2.2.6 - 2011-11-25 by Capella
// - Fixed bug for too large lotsize.
// - Fixed the bug for TradeALLCurrencyPairs
// - Moved broker suffix from external parameter to automatically calculated in a subroutine
// - Removed unnecessary program code, cleaned and organized the code further
// Ver 2.2.7 - 2011-11-30 by Capella
// - Fixed a bug for the broker Commission
//
// Ver 2.3 - 2011-12-08 by Capella
// - Changed name of the EA (from MDP-Plus) as the thread in the forum once again was deleted.
//   This EA is now a copyrighted shareware – a non-commercial product free to use.
// - Removed TradeALLCurrencyPairs as it was too buggy and could not cope with the fast trades,
//   better attach on separate charts
// - Fixed bug where iMA was used instead of either/or iMA/iBands for modifying BUYSTOP and SELLSTOP
//   orders
// - Rewrote some of the code to make it easier to follow and understand.
// - Rewrote subs to check lotsize and risk settings, and adjust them accordingly
// - Added more comments to program code
// - Added time for how often fake orders should be sent in order to calculate execution speed
// - Removed unused variables and code
// - Added check so no trading can start before we have gathered enough of Bar-data
// - Moved Slippage to an external parameter so it can be changed
// - Added summation of broker error codes
// Ver 2.3.1 - 2011-12-08 by Capella
// - Fixed a bug that could cause lotsize to be greater than MaxLots
// Ver 2.3.2 - 2011-12-09 by blueprint1972
// - Added option for simulated latency during backtests
// Ver 2.3.2b - 2011-12-09 by derox
// - Added iEnvelopes and iATR as indicators
// Ver 2.3.2c - 2011-12-10 by Pannik
// - Added "UseIndicatorSwitch" for choosing indicator to use
// Ver 2.3.2d - 2011-12-12 by derox
// - Added AllAverages as indicator. Note: This requires external indicator
// Ver 2.3.3 - 2011-12-12 by Capella
// - Added AddPriceGap as an external parameter to increase SL and TP in order to decrease number of error 130
// - Replaced iMA with AllAverages
// - Removed iMA AND iBands combination
// - Fixed minor bugs
// - Cleaned up the code further
// Ver 2.3.4 - 2011-12-13 by Capella
// - Removed AllAverages as it didn't make any difference compared to standard Moving Average
// - Fixed bug for iATR indicator.
// - Added dual-trade as an option for iATR
//
// Ver 2.4 - 2012-09-06 by Capella
// - Removed some external settings incl. ATR and its settings
// - Added external setting MinumumUseStopLevel
// - Fixed bugs, so it works better with different brokers withhout error 130
// Ver 2.4.1 - 2012-10-23 by Capella
// - Added check for when ECN_Mode == TRUE and BUY/SELL orders have not yet been modified, to
//   prevent running orders without SL. Wait 1 second and then modify the order with a SL
//   that is 3 pip from current price.
// - Changed default settings after extensive backtests using 99% tick-data
// Ver 2.4.2 - 2013-07 by Capella
// - Added lot-size re-calculation if Account Currency is not USD but either EUR, GBP, CHF or JPY
// - Added ReverseTrade as an option
// - Changed algorithm for automatically calculation of magicnumber
// - Added printout info if there was no errors reported from the broker server
// -------------------------------------------------------------------------------------------------


#property copyright "Copyright 2011-2012 by Capella at http://www.worldwide-invest.org"
#property link      "http://www.worldwide-invest.org"
#property show_inputs

//----------------------- Include files ------------------------------------------------------------

#include <stdlib.mqh>
#include <stderror.mqh>

//----------------------- Externals ----------------------------------------------------------------
// All externals should here have their name starting with a CAPITAL character

extern string Configuration = "==== Configuration ====";
extern bool ReverseTrade = FALSE;            // If TRUE, then trade in opposite direction
extern int Magic = -1;                       // If set to a number less than 0 it will calculate MagicNumber automatically
extern string OrderCmt = "XMT-Scalper 2.4.2";// Trade comments that appears in the Trade and Account History tab
extern bool ECN_Mode = FALSE;                // True for brokers that don't accept SL and TP to be sent at the same time as the order
extern bool Debug = FALSE;                   // Print huge log files with info, only for debugging purposes
extern bool Verbose = FALSE;                 // Additional information printed in the chart
extern string TradingSettings = "==== Trade settings ====";
extern double MaxSpread = 30.0;              // Max allowed spread in points (1 / 10 pip)
extern int MaxExecution = 0;                 // Max allowed average execution time in ms (0 means no restrictions)
extern int MaxExecutionMinutes = 5;          // How often in minutes should fake orders be sent to measure execution speed
extern double StopLoss = 0.0;                // StopLoss from as many points. Default 60 (= 6 pips)
extern double TakeProfit = 100.0;            // TakeProfit from as many points. Default 100 (= 10 pip)
extern double AddPriceGap = 0;               // Additional price gap in points added to SL and TP in order to avoid Error 130
extern double TrailingStart = 23;            // Start trailing profit from as so many pips. Default 23
extern double Commission = 0;                // Some broker accounts charge commission in USD per 1.0 lot. Commission in points
extern int Slippage = 3;                     // Maximum allowed Slippage in points
extern double MinimumUseStopLevel = 10;      // Minimum stop level if broker has 0 point
extern string VolatilitySettings = "==== Volatility Settings ====";
extern bool UseDynamicVolatilityLimit = TRUE;// Calculate VolatilityLimit based on INT (spread * VolatilityMultiplier)
extern double VolatilityMultiplier = 125;    // Dynamic value, only used if UseDynamicVolatilityLimit is set to TRUE
extern double VolatilityLimit = 180;         // Fix value, only used if UseDynamicVolatilityLimit is set to FALSE
extern bool UseVolatilityPercentage = TRUE;  // If true, then price must break out more than a specific percentage
extern double VolatilityPercentageLimit = 0; // Percentage of how much iHigh-iLow difference must differ from VolatilityLimit. 0 is risky, 60 means a safe value
extern string UseIndicatorSet = "=== Indicators: 1 = Moving Average, 2 = BollingerBand, 3 = Envelopes";
extern int UseIndicatorSwitch = 3;           // Switch User indicators.
extern double BBDeviation = 1.50;            // Deviation for the iBands indicator
extern double EnvelopesDeviation = 0.07;     // Deviation for the iEnvelopes indicator
extern int OrderExpireSeconds = 3600;        // Orders are deleted after so many seconds
extern string Money_Management = "==== Money Management ====";
extern bool MoneyManagement = TRUE;          // If TRUE then calculate lotsize automaticallay based on Risk, if False then use ManualLotsize below
extern double MinLots = 0.01;                // Minimum lot-size to trade with
extern double MaxLots = 100.0;               // Maximum allowed lot-size to trade with
extern double Risk = 2.0;                    // Risk setting in percentage, For 10.000 in Balance 10% Risk and 60 StopLoss lotsize = 16.66
extern double ManualLotsize = 0.1;           // Manual lotsize to trade with if MoneyManagement above is set to FALSE
extern string Screen_Shooter = "==== Screen Shooter ====";
extern bool TakeShots = FALSE;               // Save screen shots on STOP orders?
extern int DelayTicks = 1;                   // Delay so many ticks after new bar
extern int ShotsPerBar = 1;                  // How many screen shots per bar

//--------------------------- Globals --------------------------------------------------------------
// All globals have their name written in lower case characters

string ea_version = "XMT-Scalper v. 2.4.2";

int indicatorperiod = 3;   // Period in bars for indicators
int brokerdigits = 0;      // Nnumber of digits that the broker uses for this currency pair
int globalerror = 0;       // To keep track on number of added errors
int lasttime = 0;          // For measuring tics
int tickcounter = 0;       // Counting tics
int upto30counter = 0;     // For calculating average spread
int execution = -1;        // For execution speed, -1 means no speed
int avg_execution = 0;     // Average execution speed
int execution_samples = 0; // For calculating average execution speed
int starttime;             // Initial time
int leverage;              // Account leverage in percentage
int lotbase;               // Amount of money in base currency for 1 lot
int err_unchangedvalues;   // Error count for unchanged values (modify to the same values)
int err_busyserver;        // Error count for busy server
int err_lostconnection;    // Error count for lost connection
int err_toomanyrequest;    // Error count for too many requests
int err_invalidprice;      // Error count for invalid price
int err_invalidstops;      // Error count for invalid SL and/or TP
int err_invalidtradevolume;// Error count for invalid lot size
int err_pricechange;       // Error count for change of price
int err_brokerbuzy;        // Error count for broker is buzy
int err_requotes;          // Error count for requotes
int err_toomanyrequests;   // Error count for too many requests
int err_trademodifydenied; // Error count for modify orders is denied
int err_tradecontextbuzy;  // error count for trade context is buzy
int skippedticks = 0;      // Used for simulation of latency during backtests, how many tics that should be skipped
int ticks_samples = 0;     // Used for simulation of latency during backtests, number of tick samples

double array_spread[30];   // Store spreads for the last 30 tics
double lotsize;            // Lotsize
double highest;            // Highest indicator value
double lowest;             // Lowest indicator value
double stoplevel;          // Broker stoplevel
double stopout;            // Broker stoput percentage
double lotstep;            // Broker lotstep
double multiplicator;      // Multiplicator for lot size based on Account Currency
double marginforonelot;    // Margin required for 1 lot
double avg_tickspermin = 0;// Used for simulation of latency during backtests

//======================= Program initialization ===================================================

int init()
{
   string local_appendix;  // local string variable used for possible currency pair appendix
   int local_length;  // local integer variable to store length of the currency pair string

   // Print short message at the start of initalization
   Print ("====== Initialization of ", ea_version, " ======");

   // Reset time for execution control
   starttime = TimeLocal();

   // Reset error variable
   globalerror = -1;

   // Get the broker decimals
   brokerdigits = Digits;

   // Get leverage
   leverage = AccountLeverage();

   // Calculate stoplevel as max of either STOPLEVEL or FREEZELEVEL
   stoplevel = MathMax(MarketInfo(Symbol(), MODE_FREEZELEVEL), MarketInfo(Symbol(), MODE_STOPLEVEL));

   // Get stoput level and re-calculate as fraction
   stopout = AccountStopoutLevel();

   // Calculate lotstep
   lotstep = MarketInfo(Symbol(), MODE_LOTSTEP);

   // Check to confirm that indicator switch is valid choices, if not force to 1 (Moving Average)
   if (UseIndicatorSwitch < 1 || UseIndicatorSwitch > 4)
      UseIndicatorSwitch = 1;

   // If indicator switch is set to 4, using iATR, tben UseVolatilityPercentage cannot be used, so force it to FALSE
   if (UseIndicatorSwitch == 4)
      UseVolatilityPercentage = FALSE;

   // If zero values for stoplevel and AddPriceGap, then force stoplevel to MinimumUseStopLevel
   if ((stoplevel == 0) && (AddPriceGap == 0))
      stoplevel = MinimumUseStopLevel;

   // Adjust SL and TP to broker stoplevel if they are less than this stoplevel
   StopLoss = MathMax(StopLoss, stoplevel);
   TakeProfit = MathMax(TakeProfit, stoplevel);

   // Re-calculate variables
   VolatilityPercentageLimit = VolatilityPercentageLimit / 100 + 1;
   VolatilityMultiplier = VolatilityMultiplier / 10;
   ArrayInitialize(array_spread, 0);
   VolatilityLimit = VolatilityLimit * Point;
   Commission = sub_normalizebrokerdigits(Commission * Point);
   TrailingStart = TrailingStart * Point;
   stoplevel = stoplevel * Point;
   AddPriceGap = AddPriceGap * Point;

   // If we have set MaxLot and/or MinLots to more/less than what the broker allows, then adjust it accordingly
   if (MinLots < MarketInfo(Symbol(), MODE_MINLOT))
      MinLots = MarketInfo(Symbol(), MODE_MINLOT);
   if (MaxLots > MarketInfo(Symbol(), MODE_MAXLOT))
      MaxLots = MarketInfo(Symbol(), MODE_MAXLOT);
   if (MaxLots < MinLots)
      MaxLots = MinLots;

   // Calculate margin required for 1 lot
   marginforonelot = MarketInfo(Symbol(), MODE_MARGINREQUIRED);

   // Amount of money in base currency for 1 lot
   lotbase = MarketInfo(Symbol(), MODE_LOTSIZE);

   // Calculate lot multiplicator for Account Currency. Assumes that account curreny is either USD, EUR, GBP, CHF or JPY
   // If the account currency is of any other currency, then calculate the multiplicator as follows:
   // If base-currency is USD then use the BID-price for the currency pair USDXXX; or if the
   // counter currency is USD the use 1 / BID-price for the currency pair XXXUSD,
   // where XXX is the abbreviation for the account currency. The calculated lot-size should
   // then be multiplied with this multiplicator.
   local_length = StringLen(Symbol());
   local_appendix = "";
   if (local_length != 6)
      local_appendix = StringSubstr(Symbol(),6,local_length - 6);
   if (AccountCurrency() == "EUR")
      multiplicator = 1.0 / MarketInfo("EURUSD" + local_appendix, MODE_BID);
   if (AccountCurrency() == "GBP")
      multiplicator = 1.0 / MarketInfo("GBPUSD" + local_appendix, MODE_BID);
   if (AccountCurrency() == "CHF")
      multiplicator = MarketInfo("USDCHF" + local_appendix, MODE_BID);
   if (AccountCurrency() == "JPY")
      multiplicator = MarketInfo("USDJPY" + local_appendix, MODE_BID);
   if (multiplicator == 0)
      multiplicator = 1.0; // If account currency is neither of EUR,GBP,CHF or JPY we assumes that it is USD

   // Also make sure that if the risk-percentage is too low or too high, that it's adjusted accordingly
   sub_recalculatewrongrisk();

   // Calculate intitial lotsize
   lotsize = sub_calculatelotsize();

   // If magic number is set to a value less than 0, then calculate MagicNumber automatically
   if (Magic < 0)
     sub_magicnumber();

   // If execution speed should be measured, then adjust maxexecution from minutes to seconds
   if (MaxExecution > 0)
      MaxExecutionMinutes = MaxExecution * 60;

   // Print initial info
   sub_printdetails();

   // Print short message at the end of initialization
   Print ("========== Initialization complete! ===========\n");

   // Finally call the main trading subroutine
   start();

   return (0);
}

//======================= Program deinitialization =================================================

int deinit()
{
   string local_text = "";

   // If we run backtests and simulate latency, then print result
   if (IsTesting() && MaxExecution > 0)
   {
      local_text = local_text + "During backtesting " + skippedticks + " number of ticks was ";
      local_text = local_text + "skipped to simulate latency of up to " + MaxExecution + " ms".;
      sub_printandcomment (local_text);
   }

   // Print summarize of broker errors
   sub_printsumofbrokererrors();

   // Print short message when EA has been deinitialized
   Print (ea_version, " has been deinitialized!");

   return(0);
}


//==================================== Program start ===============================================

int start()
{
   // We must wait til we have enough of bar data before we call trading routine
   if (iBars(Symbol(),PERIOD_M1) > indicatorperiod)
      sub_trade();
   else
      Print ("Please wait until enough of bar data has been gathered!");

   return (0);
}


//================================ Subroutines starts here =========================================
// All subroutines (aka functions) here have their names starting with sub_
// Exception are the standard routines init(), deinit() and start()
//
// Notation:
// All actual and formal parameters in subs have their names starting with par_
// All local variables in subs have their names starting with local_

// This is the main trading subroutine
void sub_trade()
{
   string local_textstring;
   string local_pair;
   string local_indy;

   bool local_wasordermodified;
   bool local_ordersenderror;
   bool local_isbidgreaterthanima;
   bool local_isbidgreaterthanibands;
   bool local_isbidgreaterthanenvelopes;
   bool local_isbidgreaterthanaa;
   bool local_isbidgreaterthanindy;

   int local_orderticket;
   int local_orderexpiretime;
   int local_lotstep;
   int local_loopcount2;
   int local_loopcount1;
   int local_pricedirection;
   int local_counter1;
   int local_counter2;
   int local_paircounter;
   int local_askpart;
   int local_bidpart;

   double local_ask;
   double local_bid;
   double local_askplusdistance;
   double local_bidminusdistance;
   double local_volatilitypercentage;
   double local_trailingdistance;
   double local_orderprice;
   double local_orderstoploss;
   double local_ordertakeprofit;
   double local_ihigh;
   double local_ilow;
   double local_imalow;
   double local_imahigh;
   double local_imadiff;
   double local_ibandsupper;
   double local_ibandslower;
   double local_ibandsdiff;
   double local_envelopesupper;
   double local_envelopeslower;
   double local_envelopesdiff;
   double local_aalower;
   double local_aahigher;
   double local_aadiff;
   double local_volatility;
   double local_spread;
   double local_avgspread;
   double local_realavgspread;
   double local_fakeprice;
   double local_sumofspreads;
   double local_askpluscommission;
   double local_bidminuscommission;
   double local_skipticks;

   // Previous time was less than current time, initiate tick counter
   if (lasttime < Time[0])
   {
      // For simulation of latency during backtests, consider only 10 samples at most.
      if (ticks_samples < 10)
         ticks_samples++;
      avg_tickspermin = avg_tickspermin + (tickcounter - avg_tickspermin) / ticks_samples;
      // Set previopus time to current time and reset tick counter
      lasttime = Time[0];
      tickcounter = 0;
   }
   // Previous time was NOT less than current time, so increase tick counter with 1
   else
      tickcounter++;

   // If backtesting and MaxExecution is set let's skip a proportional number of ticks them in order to
   // reproduce the effect of latency on this EA
   if (IsTesting() && MaxExecution != 0 && execution != -1)
   {
      local_skipticks = MathRound(avg_tickspermin * MaxExecution / (60 * 1000));
      if (skippedticks >= local_skipticks)
      {
         execution = -1;
         skippedticks = 0;
      }
      else
      {
         skippedticks++;
         return (0);
      }
   }

   // Get Ask and Bid for the currency
   local_ask = MarketInfo(Symbol(), MODE_ASK);
   local_bid = MarketInfo(Symbol(), MODE_BID);

   // Calculate the channel of Volatility based on the difference of iHigh and iLow during current bar
   local_ihigh = iHigh(Symbol(), PERIOD_M1, 0);
   local_ilow = iLow(Symbol(), PERIOD_M1, 0);
   local_volatility = local_ihigh - local_ilow;

   // Reset printout string
   local_indy = "";

   // Calculate a channel on Moving Averages, and check if the price is outside of this channel.
   if (UseIndicatorSwitch == 1 || UseIndicatorSwitch == 4)
   {
      local_imalow = iMA(Symbol(), PERIOD_M1, indicatorperiod, 0, MODE_LWMA, PRICE_LOW, 0);
      local_imahigh = iMA(Symbol(), PERIOD_M1, indicatorperiod, 0, MODE_LWMA, PRICE_HIGH, 0);
      local_imadiff = local_imahigh - local_imalow;
      local_isbidgreaterthanima = local_bid >= local_imalow + local_imadiff / 2.0;
      local_indy = "iMA_low: " + sub_dbl2strbrokerdigits(local_imalow) + ", iMA_high: " + sub_dbl2strbrokerdigits(local_imahigh) + ", iMA_diff: " + sub_dbl2strbrokerdigits(local_imadiff);
   }

   // Calculate a channel on BollingerBands, and check if the price is outside of this channel
   if (UseIndicatorSwitch == 2)
   {
      local_ibandsupper = iBands(Symbol(), PERIOD_M1, indicatorperiod, BBDeviation, 0, PRICE_OPEN, MODE_UPPER, 0);
      local_ibandslower = iBands(Symbol(), PERIOD_M1, indicatorperiod, BBDeviation, 0, PRICE_OPEN, MODE_LOWER, 0);
      local_ibandsdiff = local_ibandsupper - local_ibandslower;
      local_isbidgreaterthanibands = local_bid >= local_ibandslower + local_ibandsdiff / 2.0;
      local_indy = "iBands_upper: " + sub_dbl2strbrokerdigits(local_ibandslower) + ", iBands_lower: " + sub_dbl2strbrokerdigits(local_ibandslower) + ", iBands_diff: " + sub_dbl2strbrokerdigits(local_ibandsdiff);
   }

   // Calculate a channel on Envelopes, and check if the price is outside of this channel
   if (UseIndicatorSwitch == 3)
   {
      local_envelopesupper = iEnvelopes(Symbol(), PERIOD_M1, indicatorperiod, MODE_LWMA, 0, PRICE_OPEN, EnvelopesDeviation, MODE_UPPER, 0);
      local_envelopeslower = iEnvelopes(Symbol(), PERIOD_M1, indicatorperiod, MODE_LWMA, 0, PRICE_OPEN, EnvelopesDeviation, MODE_LOWER, 0);
      local_envelopesdiff = local_envelopesupper - local_envelopeslower;
      local_isbidgreaterthanenvelopes = local_bid >= local_envelopeslower + local_envelopesdiff / 2.0;
      local_indy = "iEnvelopes_upper: " + sub_dbl2strbrokerdigits(local_envelopesupper) + ", iEnvelopes_lower: " + sub_dbl2strbrokerdigits(local_envelopeslower) + ", iEnvelopes_diff: " + sub_dbl2strbrokerdigits(local_envelopesdiff);
   }

   // Reset breakout variable as FALSE
   local_isbidgreaterthanindy = FALSE;

   // Reset pricedirection for no indication of trading direction
   local_pricedirection = 0;

   // If we're using iMA as indicator, then check if there's a breakout
   if (UseIndicatorSwitch == 1 && local_isbidgreaterthanima == TRUE)
   {
      local_isbidgreaterthanindy = TRUE;
      highest = local_imahigh;
      lowest = local_imalow;
   }

   // If we're using iBands as indicator, then check if there's a breakout
   else if (UseIndicatorSwitch == 2 && local_isbidgreaterthanibands == TRUE)
   {
      local_isbidgreaterthanindy = TRUE;
      highest = local_ibandsupper;
      lowest = local_ibandslower;
   }

   // If we're using iEnvelopes as indicator, then check if there's a breakout
   else if (UseIndicatorSwitch == 3 && local_isbidgreaterthanenvelopes == TRUE)
   {
      local_isbidgreaterthanindy = TRUE;
      highest = local_envelopesupper;
      lowest = local_envelopeslower;
   }

   // Calculate spread, adjuststoplevel, orderexpiretime and lotsize
   local_spread = local_ask - local_bid;
   local_orderexpiretime = TimeCurrent() + OrderExpireSeconds;
   lotsize = sub_calculatelotsize();

   // Calculate average true spread, which is the average of the spread for the last 30 tics
   ArrayCopy(array_spread, array_spread, 0, 1, 29);
   array_spread[29] = local_spread;
   if (upto30counter < 30)
      upto30counter++;
   local_sumofspreads = 0;
   local_loopcount2 = 29;
   for (local_loopcount1 = 0; local_loopcount1 < upto30counter; local_loopcount1++)
   {
      local_sumofspreads += array_spread[local_loopcount2];
      local_loopcount2--;
   }

   // Calculate an average of spreads based on the spread from the last 30 tics
   local_avgspread = local_sumofspreads / upto30counter;

   // Calculate price and spread considering commission
   local_askpluscommission = sub_normalizebrokerdigits(local_ask + Commission);
   local_bidminuscommission = sub_normalizebrokerdigits(local_bid - Commission);
   local_realavgspread = local_avgspread + Commission;

   // Recalculate the VolatilityLimit if it's set to dynamic. It's based on the average of spreads + commission
   if (UseDynamicVolatilityLimit == TRUE)
      VolatilityLimit = local_realavgspread * VolatilityMultiplier;

   // If the variables below have values it means that we have enough of data from broker server.
   if (local_volatility && VolatilityLimit && lowest && highest && UseIndicatorSwitch != 4)
   {
      // The Volatility is outside of the VolatilityLimit, so we can now open a trade
      if (local_volatility > VolatilityLimit)
      {
         // Calculate how much it differs
         local_volatilitypercentage = local_volatility / VolatilityLimit;
         // In case of UseVolatilityPercentage == TRUE then also check if it differ enough of percentage
         if ((UseVolatilityPercentage == FALSE) || (UseVolatilityPercentage == TRUE && local_volatilitypercentage > VolatilityPercentageLimit))
         {
            if (local_bid < lowest)
              if (ReverseTrade == FALSE)
                local_pricedirection = -1; // BUY or BUYSTOP
              else // ReverseTrade == true
                local_pricedirection = 1; // SELL or SELLSTOP
            else if (local_bid > highest)
              if (ReverseTrade == FALSE)
                local_pricedirection = 1;  // SELL or SELLSTOP
              else // ReverseTrade == true
                local_pricedirection = -1; // BUY or BUYSTOP
         }
      }
      // The Volatility is less than the VolatilityLimit
      else
         local_volatilitypercentage = 0;
   }

   // Out of money
   if (AccountBalance() <= 0.0)
   {
      Comment("ERROR -- Account Balance is " + DoubleToStr(MathRound(AccountBalance()), 0));
      return;
   }

   // Reset execution time
   execution = -1;

   // Reset counters
   local_counter1 = 0;
   local_counter2 = 0;

   // Loop through all open orders (if any) to either modify them or delete them
   for (local_loopcount2 = 0; local_loopcount2 < OrdersTotal(); local_loopcount2++)
   {
      OrderSelect(local_loopcount2, SELECT_BY_POS, MODE_TRADES);
      // We've found an that matches the magic number and is open
      if (OrderMagicNumber() == Magic && OrderCloseTime() == 0)
      {
         // If the order doesn't match the currency pair from the chart then check next open order
         if (OrderSymbol() != Symbol())
         {
            // Increase counter
            local_counter2++;
            continue;
         }
         // Select order by type of order
         switch (OrderType())
         {
         // We've found a matching BUY-order
         case OP_BUY:
            // Start endless loop
            while (TRUE)
            {
               // Update prices from the broker
               RefreshRates();
               // Set SL and TP
               local_orderstoploss = OrderStopLoss();
               local_ordertakeprofit = OrderTakeProfit();
               // Ok to modify the order if its TP is less than the price+commission+stoplevel AND price+stoplevel-TP greater than trailingStart
               if (local_ordertakeprofit < sub_normalizebrokerdigits(local_askpluscommission + TakeProfit * Point + AddPriceGap) && local_askpluscommission + TakeProfit * Point + AddPriceGap - local_ordertakeprofit > TrailingStart)
               {
                  // Set SL and TP
                  local_orderstoploss = sub_normalizebrokerdigits(local_bid - StopLoss * Point - AddPriceGap);
                  local_ordertakeprofit = sub_normalizebrokerdigits(local_askpluscommission + TakeProfit * Point + AddPriceGap);
                  // Send an OrderModify command with adjusted SL and TP
                  if (local_orderstoploss != OrderStopLoss() && local_ordertakeprofit != OrderTakeProfit())
                  {
                     // Start execution timer
                     execution = GetTickCount();
                     // Try to modify order
                     local_wasordermodified = OrderModify(OrderTicket(), 0, local_orderstoploss, local_ordertakeprofit, local_orderexpiretime, Lime);
                  }
                  // Order was modified with new SL and TP
                  if (local_wasordermodified == TRUE)
                  {
                     // Calculate execution speed
                     execution = GetTickCount() - execution;
                     // If we have choosen to take snapshots and we're not backtesting, then do so
                     if (TakeShots && !IsTesting())
                        sub_takesnapshot();
                     // Break out from while-loop since the order now has been modified
                     break;
                  }
                  // Order was not modified
                  else
                  {
                     // Reset execution counter
                     execution = -1;
                     // Add to errors
                     sub_errormessages();
                     // Print if debug or verbose
                     if (Debug || Verbose)
                        Print ("Order could not be modified because of ", ErrorDescription(GetLastError()));
                     // Order has not been modified and it has no StopLoss
                     if (local_orderstoploss == 0)
                     // Try to modify order with a safe hard SL that is 3 pip from current price
                        local_wasordermodified = OrderModify (OrderTicket(), 0, NormalizeDouble (Bid - 30, brokerdigits), 0, 0, Red);
                  }
               }
               // Break out from while-loop since the order now has been modified
               break;
            }
            // count 1 more up
            local_counter1++;
            // Break out from switch
            break;

         // We've found a matching SELL-order
         case OP_SELL:
            // Start endless loop
            while (TRUE)
            {
               // Update broker prices
               RefreshRates();
               // Set SL and TP
               local_orderstoploss = OrderStopLoss();
               local_ordertakeprofit = OrderTakeProfit();
               // Ok to modify the order if its TP is greater than price-commission-stoplevel AND TP-price-commission+stoplevel is greater than trailingstart
               if (local_ordertakeprofit > sub_normalizebrokerdigits(local_bidminuscommission - TakeProfit * Point - AddPriceGap) && local_ordertakeprofit - local_bidminuscommission + TakeProfit * Point - AddPriceGap > TrailingStart)
               {
                  // set SL and TP
                  local_orderstoploss = sub_normalizebrokerdigits(local_ask + StopLoss * Point + AddPriceGap);
                  local_ordertakeprofit = sub_normalizebrokerdigits(local_bidminuscommission - TakeProfit * Point - AddPriceGap);
                  // Send an OrderModify command with adjusted SL and TP
                  if (local_orderstoploss != OrderStopLoss() && local_ordertakeprofit != OrderTakeProfit())
                  {
                     // Start execution timer
                     execution = GetTickCount();
                     local_wasordermodified = OrderModify(OrderTicket(), 0, local_orderstoploss, local_ordertakeprofit, local_orderexpiretime, Orange);
                  }
                  // Order was modiified with new SL and TP
                  if (local_wasordermodified == TRUE)
                  {
                     // Calculate execution speed
                     execution = GetTickCount() - execution;
                     // If we have choosen to take snapshots and we're not backtesting, then do so
                     if (TakeShots && !IsTesting())
                        sub_takesnapshot();
                     // Break out from while-loop since the order now has been modified
                     break;
                  }
                  // Order was not modified
                  else
                  {
                     // Reset execution counter
                     execution = -1;
                     // Add to errors
                     sub_errormessages();
                     // Print if debug or verbose
                     if (Debug || Verbose)
                        Print ("Order could not be modified because of ", ErrorDescription(GetLastError()));
                     // Lets wait 1 second before we try to modify the order again
                     Sleep (1000);
                     // Order has not been modified and it has no StopLoss
                     if (local_orderstoploss == 0)
                     // Try to modify order with a safe hard SL that is 3 pip from current price
                        local_wasordermodified = OrderModify (OrderTicket(), 0, NormalizeDouble (Ask + 30, brokerdigits), 0, 0, Red);
                  }
               }
               // Break out from while-loop since the order now has been modified
               break;
            }
            // count 1 more up
            local_counter1++;
            // Break out from switch
            break;

         // We've found a matching BUYSTOP-order
         case OP_BUYSTOP:
            // Price must NOT be larger than indicator in order to modify the order, otherwise the order will be deleted
            if (local_isbidgreaterthanindy == FALSE)
            {
               // Calculate how much Price, SL and TP should be modified
               local_orderprice = sub_normalizebrokerdigits(local_ask + stoplevel + AddPriceGap);
               local_orderstoploss = sub_normalizebrokerdigits(local_orderprice - local_spread - StopLoss * Point - AddPriceGap);
               local_ordertakeprofit = sub_normalizebrokerdigits(local_orderprice + Commission + TakeProfit * Point + AddPriceGap);
               // Start endless loop
               while (true)
               {
                  // Ok to modify the order if price+stoplevel is less than orderprice AND orderprice-price-stoplevel is greater than trailingstart
                  if (local_orderprice < OrderOpenPrice() && OrderOpenPrice() - local_orderprice > TrailingStart)
                  {

                     // Send an OrderModify command with adjusted Price, SL and TP
                     if(local_orderstoploss != OrderStopLoss() && local_ordertakeprofit != OrderTakeProfit())
                     {
                        RefreshRates();
                        // Start execution timer
                        execution = GetTickCount();
                        local_wasordermodified = OrderModify(OrderTicket(), local_orderprice, local_orderstoploss, local_ordertakeprofit, 0, Lime);
                     }
                     // Order was modified
                     if (local_wasordermodified == TRUE)
                     {
                        // Calculate execution speed
                        execution = GetTickCount() - execution;
                        // Print if debug or verbose
                        if (Debug || Verbose)
                           Print ("Order executed in " + execution + " ms");
                     }
                     // Order was not modified
                     else
                     {
                        // Reset execution counter
                        execution = -1;
                        // Add to errors
                        sub_errormessages();
                     }
                  }
                  // Break out from endless loop
                  break;
               }
               // Increase counter
               local_counter1++;
            }
            // Price was larger than the indicator
            else
               // Delete the order
               OrderDelete(OrderTicket());
            // Break out from switch
            break;

         // We've found a matching SELLSTOP-order
         case OP_SELLSTOP:
            // Price must be larger than the indicator in order to modify the order, otherwise the order will be deleted
            if (local_isbidgreaterthanindy == TRUE)
            {
               // Calculate how much Price, SL and TP should be modified
               local_orderprice = sub_normalizebrokerdigits(local_bid - stoplevel - AddPriceGap);
               local_orderstoploss = sub_normalizebrokerdigits(local_orderprice + local_spread + StopLoss * Point + AddPriceGap);
               local_ordertakeprofit = sub_normalizebrokerdigits(local_orderprice - Commission - TakeProfit * Point - AddPriceGap);
               // Endless loop
               while (true)
               {
                  // Ok to modify order if price-stoplevel is greater than orderprice AND price-stoplevel-orderprice is greater than trailingstart
                  if (local_orderprice > OrderOpenPrice() && local_orderprice - OrderOpenPrice() > TrailingStart)
                  {
                     // Send an OrderModify command with adjusted Price, SL and TP
                     if(local_orderstoploss != OrderStopLoss() && local_ordertakeprofit != OrderTakeProfit())
                     {
                        RefreshRates();
                        // Start execution counter
                        execution = GetTickCount();
                        local_wasordermodified = OrderModify(OrderTicket(), local_orderprice, local_orderstoploss, local_ordertakeprofit, 0, Orange);
                     }
                     // Order was modified
                     if (local_wasordermodified == TRUE)
                     {
                        // Calculate execution speed
                        execution = GetTickCount() - execution;
                        // Print if debug or verbose
                        if (Debug || Verbose)
                           Print ("Order executed in " + execution + " ms");
                     }
                     // Order was not modified
                     else
                     {
                        // Reset execution counter
                        execution = -1;
                        // Add to errors
                        sub_errormessages();
                     }
                  }
                  // Break out from endless loop
                  break;
               }
               // count 1 more up
               local_counter1++;
            }
            // Price was NOT larger than the indicator, so delete the order
            else
               OrderDelete(OrderTicket());
         } // end of switch
      }  // end if OrderMagicNumber
   } // end for loopcount2 - end of loop through open orders

   // Calculate and keep track on global error number
   if (globalerror >= 0 || globalerror == -2)
   {
      local_bidpart = NormalizeDouble(local_bid / Point, 0);
      local_askpart = NormalizeDouble(local_ask / Point, 0);
      if (local_bidpart % 10 != 0 || local_askpart % 10 != 0)
         globalerror = -1;
      else
      {
         if (globalerror >= 0 && globalerror < 10)
            globalerror++;
         else
            globalerror = -2;
      }
   }

   // Reset error-variable
   local_ordersenderror = FALSE;

   // Before executing new orders, lets check the average execution time.
   if (local_pricedirection != 0 && MaxExecution > 0 && avg_execution > MaxExecution)
   {
      local_pricedirection = 0; // Ignore the order opening triger
      if (Debug || Verbose)
         Print("Server is too Slow. Average Execution: " + avg_execution);
   }

   // Set default price adjustment
   local_askplusdistance = local_ask + stoplevel;
   local_bidminusdistance = local_bid - stoplevel;

   // If we have no open orders AND a price breakout AND average spread is less or equal to max allowed spread AND we have no errors THEN proceed
   if (local_counter1 == 0 && local_pricedirection != 0 && sub_normalizebrokerdigits(local_realavgspread) <= sub_normalizebrokerdigits(MaxSpread * Point) && globalerror == -1)
   {
      // If we have a price breakout downwards (Bearish) then send a BUYSTOP order
      if (local_pricedirection == -1 || local_pricedirection == 2) // Send a BUYSTOP
      {
         // Calculate a new price to use
         local_orderprice = local_ask + stoplevel;
         // SL and TP is not sent with order, but added afterwords in a OrderModify command
         if (ECN_Mode == TRUE)
         {
            // Set prices for OrderModify of BUYSTOP order
            local_orderprice = local_askplusdistance;
            local_orderstoploss =  0;
            local_ordertakeprofit = 0;
            // Start execution counter
            execution = GetTickCount();
            // Send a BUYSTOP order without SL and TP
            local_orderticket = OrderSend(Symbol(), OP_BUYSTOP, lotsize, local_orderprice, Slippage, local_orderstoploss, local_ordertakeprofit, OrderCmt, Magic, 0, Lime);
            // OrderSend was executed successfully
            if (local_orderticket > 0)
            {
               // Calculate execution speed
               execution = GetTickCount() - execution;
               if (Debug || Verbose)
                  Print ("Order executed in " + execution + " ms");
               // If we have choosen to take snapshots and we're not backtesting, then do so
               if (TakeShots && !IsTesting())
                  sub_takesnapshot();
            }  // end if ordersend
            // OrderSend was NOT executed
            else
            {
               local_ordersenderror = TRUE;
               execution = -1;
               // Add to errors
               sub_errormessages();
            }
            // OrderSend was executed successfully, so now modify it with SL and TP
            if (OrderSelect(local_orderticket, SELECT_BY_TICKET))
            {
               RefreshRates();
               // Set prices for OrderModify of BUYSTOP order
               local_orderprice = OrderOpenPrice();
               local_orderstoploss =  sub_normalizebrokerdigits(local_orderprice - local_spread - StopLoss * Point - AddPriceGap);
               local_ordertakeprofit = sub_normalizebrokerdigits(local_orderprice + TakeProfit * Point + AddPriceGap);
               // Start execution timer
               execution = GetTickCount();
               // Send a modify order for BUYSTOP order with new SL and TP
               local_wasordermodified = OrderModify(OrderTicket(), local_orderprice, local_orderstoploss, local_ordertakeprofit, local_orderexpiretime, Lime);
               // OrderModify was executed successfully
               if (local_wasordermodified == TRUE)
               {
                  // Calculate execution speed
                  execution = GetTickCount() - execution;
                  if (Debug || Verbose)
                     Print ("Order executed in " + execution + " ms");
                  // If we have choosen to take snapshots and we're not backtesting, then do so
                  if (TakeShots && !IsTesting())
                     sub_takesnapshot();
               } // end successful ordermodiify
               // Order was NOT modified
               else
               {
                  local_ordersenderror = TRUE;
                  execution = -1;
                  // Add to errors
                  sub_errormessages();
               } // end if-else
            }  // end if ordermodify
         } // end if ECN_Mode

         // No ECN-mode, SL and TP can be sent directly
         else
         {
            RefreshRates();
            // Set prices for BUYSTOP order
            local_orderprice = local_askplusdistance;//ask+stoplevel
            local_orderstoploss =  sub_normalizebrokerdigits(local_orderprice - local_spread - StopLoss * Point - AddPriceGap);
            local_ordertakeprofit = sub_normalizebrokerdigits(local_orderprice + TakeProfit * Point + AddPriceGap);
            // Start execution counter
            execution = GetTickCount();
            // Send a BUYSTOP order with SL and TP
            local_orderticket = OrderSend(Symbol(), OP_BUYSTOP, lotsize, local_orderprice, Slippage, local_orderstoploss, local_ordertakeprofit, OrderCmt, Magic, local_orderexpiretime, Lime);
            if (local_orderticket > 0) // OrderSend was executed suxxessfully
            {
               // Calculate execution speed
               execution = GetTickCount() - execution;
               if (Debug || Verbose)
                  Print ("Order executed in " + execution + " ms");
               // If we have choosen to take snapshots and we're not backtesting, then do so
               if (TakeShots && !IsTesting())
                  sub_takesnapshot();
            } // end successful ordersend
            // Order was NOT sent
            else
            {
               local_ordersenderror = TRUE;
               // Reset execution timer
               execution = -1;
               // Add to errors
               sub_errormessages();
            } // end if-else
         } // end no ECN-mode
      } // end if local_pricedirection == -1 or 2

      // If we have a price breakout upwards (Bullish) then send a SELLSTOP order
      if (local_pricedirection == 1 || local_pricedirection == 2)
      {
         // Set prices for SELLSTOP order with zero SL and TP
         local_orderprice = local_bidminusdistance;
         local_orderstoploss = 0;
         local_ordertakeprofit = 0;
         // SL and TP cannot be sent with order, but must be sent afterwords in a modify command
         if (ECN_Mode)
         {
            // Start execution timer
            execution = GetTickCount();
            // Send a SELLSTOP order without SL and TP
            local_orderticket = OrderSend(Symbol(), OP_SELLSTOP, lotsize, local_orderprice, Slippage, local_orderstoploss, local_ordertakeprofit, OrderCmt, Magic, 0, Orange);
            // OrderSend was executed successfully
            if (local_orderticket > 0)
            {
               // Calculate execution speed
               execution = GetTickCount() - execution;
               if (Debug || Verbose)
                  Print ("Order executed in " + execution + " ms");
               // If we have choosen to take snapshots and we're not backtesting, then do so
               if (TakeShots && !IsTesting())
                  sub_takesnapshot();
            }  // end if ordersend
            // OrderSend was NOT executed
            else
            {
               local_ordersenderror = TRUE;
               execution = -1;
               // Add to errors
               sub_errormessages();
            }
            // If the SELLSTOP order was executed successfully, then select that order
            if (OrderSelect(local_orderticket, SELECT_BY_TICKET))
            {
               RefreshRates();
               // Set prices for SELLSTOP order with modified SL and TP
               local_orderprice = OrderOpenPrice();
               local_orderstoploss = sub_normalizebrokerdigits(local_orderprice + local_spread + StopLoss * Point + AddPriceGap);
               local_ordertakeprofit = sub_normalizebrokerdigits(local_orderprice - TakeProfit * Point - AddPriceGap);
               // Start execution timer
               execution = GetTickCount();
               // Send a modify order with adjusted SL and TP
               local_wasordermodified = OrderModify(OrderTicket(), OrderOpenPrice(), local_orderstoploss, local_ordertakeprofit, local_orderexpiretime, Orange);
            }
            // OrderModify was executed successfully
            if (local_wasordermodified == TRUE)
            {
               // Calculate execution speed
               execution = GetTickCount() - execution;
               // Print debug info
               if (Debug || Verbose)
                  Print ("Order executed in " + execution + " ms");
               // If we have choosen to take snapshots and we're not backtesting, then do so
               if (TakeShots && !IsTesting())
                  sub_takesnapshot();
            } // end if ordermodify was executed successfully
            // Order was NOT executed
            else
            {
               local_ordersenderror = TRUE;
               // Reset execution timer
               execution = -1;
               // Add to errors
               sub_errormessages();
            }
         }
         else // No ECN-mode, SL and TP can be sent directly
         {
            RefreshRates();
            // Set prices for SELLSTOP order with SL and TP
            local_orderprice = local_bidminusdistance;
            local_orderstoploss = sub_normalizebrokerdigits(local_orderprice + local_spread + StopLoss * Point + AddPriceGap);
            local_ordertakeprofit = sub_normalizebrokerdigits(local_orderprice - TakeProfit * Point - AddPriceGap);
            // Start execution timer
            execution = GetTickCount();
            // Send a SELLSTOP order with SL and TP
            local_orderticket = OrderSend(Symbol(), OP_SELLSTOP, lotsize, local_orderprice, Slippage, local_orderstoploss, local_ordertakeprofit, OrderCmt, Magic, local_orderexpiretime, Orange);
            // If OrderSend was executed successfully
            if (local_orderticket > 0)
            {
               // Calculate exection speed for that order
               execution = GetTickCount() - execution;
               // Print debug info
               if (Debug || Verbose)
                  Print ("Order executed in " + execution + " ms");
               if (TakeShots && !IsTesting())
                  sub_takesnapshot();
            } // end successful ordersend
            // OrderSend was NOT executed successfully
            else
            {
               local_ordersenderror = TRUE;
               // Nullify execution timer
               execution = 0;
               // Add to errors
               sub_errormessages();
            } // end if-else
         } // end no ECN-mode
      } // end local_pricedirection == 0 or 2
   } // end if execute new orders

   // If we have no samples, every MaxExecutionMinutes a new OrderModify execution test is done
   if (MaxExecution && execution == -1 && (TimeLocal() - starttime) % MaxExecutionMinutes == 0)
   {
      // When backtesting, simulate random execution time based on the setting
      if (IsTesting() && MaxExecution)
      {
         MathSrand(TimeLocal());
         execution = MathRand() / (32767 / MaxExecution);
      }
      else
      {
         // Unless backtesting, lets send a fake order to check the OrderModify execution time,
         if (IsTesting() == FALSE)
         {
            // To be sure that the fake order never is executed, st the price to twice the current price
            local_fakeprice = local_ask * 2.0;
            // Send a BUYSTOP order
            local_orderticket = OrderSend(Symbol(), OP_BUYSTOP, lotsize, local_fakeprice, Slippage, 0, 0, OrderCmt, Magic, 0, Lime);
            execution = GetTickCount();
            // Send a modify command where we adjust the price with +1 pip
            local_wasordermodified = OrderModify(local_orderticket, local_fakeprice + 10 * Point, 0, 0, 0, Lime);
            // Calculate execution speed
            execution = GetTickCount() - execution;
            // Delete the order
            OrderDelete(local_orderticket);
         }
      }
   }

   // Do we have a valid execution sample? Update the average execution time.
   if (execution >= 0)
   {
      // Consider only 10 samples at most.
      if (execution_samples < 10)
         execution_samples++;
      // Calculate average execution speed
      avg_execution = avg_execution + (execution - avg_execution) / execution_samples;
   }

   // Check initialization
   if (globalerror >= 0)
      Comment("Robot is initializing...");
   else
   {
      // Error
      if (globalerror == -2)
         Comment("ERROR -- Instrument " + Symbol() + " prices should have " + brokerdigits + " fraction digits on broker account");
      // No errors, ready to print
      else
      {
         local_textstring = TimeToStr(TimeCurrent()) + " Tick: " + sub_adjust00instring(tickcounter);
         // Only show / print this if Debug OR Verbose are set to TRUE
         if (Debug || Verbose)
         {
            local_textstring = local_textstring + "\n*** DEBUG MODE *** \nCurrency pair: " + Symbol() + ", Volatility: " + sub_dbl2strbrokerdigits(local_volatility) + ", VolatilityLimit: " + sub_dbl2strbrokerdigits(VolatilityLimit) + ", VolatilityPercentage: " + sub_dbl2strbrokerdigits(local_volatilitypercentage);
            local_textstring = local_textstring + "\nPriceDirection: " + StringSubstr("BUY NULLSELLBOTH", 4 * local_pricedirection + 4, 4) +  ", Expire: " + TimeToStr(local_orderexpiretime, TIME_MINUTES) + ", Open orders: " + local_counter1;
            local_textstring = local_textstring + "\nBid: " + sub_dbl2strbrokerdigits(local_bid) + ", Ask: " + sub_dbl2strbrokerdigits(local_ask) + ", " + local_indy;
            local_textstring = local_textstring + "\nAvgSpread: " + sub_dbl2strbrokerdigits(local_avgspread) + ", RealAvgSpread: " + sub_dbl2strbrokerdigits(local_realavgspread) + ", Commission: " + sub_dbl2strbrokerdigits(Commission) + ", Lots: " + DoubleToStr(lotsize, 2) + ", Execution: " + execution + " ms";
            if (sub_normalizebrokerdigits(local_realavgspread) > sub_normalizebrokerdigits(MaxSpread * Point))
            {
               local_textstring = local_textstring + "\n" + "The current spread (" + sub_dbl2strbrokerdigits(local_realavgspread) +") is higher than what has been set as MaxSpread (" + sub_dbl2strbrokerdigits(MaxSpread * Point) + ") so no trading is allowed right now on this currency pair!";
            }
            if (MaxExecution > 0 && avg_execution > MaxExecution)
            {
               local_textstring = local_textstring + "\n" + "The current Avg Execution (" + avg_execution +") is higher than what has been set as MaxExecution (" + MaxExecution+ " ms), so no trading is allowed right now on this currency pair!";
            }
            Comment(local_textstring);
            // Only print this if we have a any orders  OR have a price breakout OR Verbode mode is set to TRUE
            if (local_counter1 != 0 || local_pricedirection != 0)
               sub_printformattedstring(local_textstring);
         }
      } // end if-else
   } // end check initialization
} // end sub

// Convert a decimal number to a text string
string sub_dbl2strbrokerdigits(double par_a)
{
   return (DoubleToStr(par_a, brokerdigits));
}

// Adjust numbers with as many decimals as the broker uses
double sub_normalizebrokerdigits(double par_a)
{
   return (NormalizeDouble(par_a, brokerdigits));
}

// Adjust textstring with zeros at the end
string sub_adjust00instring(int par_a)
{
   if (par_a < 10)
      return ("00" + par_a);
   if (par_a < 100)
      return ("0" + par_a);
   return ("" + par_a);
}

// Print out formatted textstring
void sub_printformattedstring(string par_a)
{
   int local_difference;
   int local_a = -1;

   while (local_a < StringLen(par_a))
   {
      local_difference = local_a + 1;
      local_a = StringFind(par_a, "\n", local_difference);
      if (local_a == -1)
      {
         Print(StringSubstr(par_a, local_difference));
         return;
      }
      Print(StringSubstr(par_a, local_difference, local_a - local_difference));
   }
}

// Magic Number - calculated from a sum of account number + ASCII-codes from currency pair
int sub_magicnumber ()
{
   string local_a;
   string local_b;
   int local_c;
   int local_d;
   int local_i;
   string local_par = "EURUSDJPYCHFCADAUDNZDGBP";
   string local_sym = Symbol();

   local_a = StringSubstr (local_sym, 0, 3);
   local_b = StringSubstr (local_sym, 3, 3);
   local_c = StringFind (local_par, local_a, 0);
   local_d = StringFind (local_par, local_b, 0);
   local_i = 999999999 - AccountNumber() - local_c - local_d;
   if (Debug == TRUE)
      Print ("MagicNumber: ", local_i);
   return (local_i);
}

// Main routine for making a screenshoot / printscreen
void sub_takesnapshot()
{
   static datetime local_lastbar;
   static int local_doshot = -1;
   static int local_oldphase = 3000000;
   int local_shotinterval;
   int local_phase;

   if (ShotsPerBar > 0)
      local_shotinterval = MathRound((60 * Period()) / ShotsPerBar);
   else
      local_shotinterval = 60 * Period();
   local_phase = MathFloor((CurTime() - Time[0]) / local_shotinterval);

   if (Time[0] != local_lastbar)
   {
      local_lastbar = Time[0];
      local_doshot = DelayTicks;
   }
   else if (local_phase > local_oldphase)
      sub_makescreenshot("i");

   local_oldphase = local_phase;

   if(local_doshot == 0)
      sub_makescreenshot("");
   if(local_doshot >= 0)
      local_doshot -= 1;

   return(0);
}

// add leading zeros that the resulting string has 'digits' length.
string sub_maketimestring(int par_number, int par_digits)
{
   string local_result;

   local_result = DoubleToStr(par_number, 0);
   while (StringLen(local_result) < par_digits)
      local_result = "0" + local_result;

   return (local_result);
}

// Make a screenshoot / printscreen
void sub_makescreenshot(string par_sx = "")
{
   static int local_no = 0;

   local_no++;
   string fn = "SnapShot"+Symbol()+Period()+"\\"+Year()+"-"+sub_maketimestring(Month(),2)+"-"+sub_maketimestring(Day(),2)+" "+sub_maketimestring(Hour(),2)+"_"+sub_maketimestring(Minute(),2)+"_"+sub_maketimestring(Seconds( ),2)+" "+local_no+par_sx+".gif";
   if (!ScreenShot(fn,640,480))
      Print("ScreenShot error: ", ErrorDescription(GetLastError()));
}

// Calculate lotsize based on Equity, Risk (in %) and StopLoss in points
double sub_calculatelotsize()
{
   string local_textstring;
   double local_availablemoney;
   double local_lotsize;
   double local_maxlot;
   double local_minlot;

   int local_lotdigit;

   if(lotstep == 1)
      local_lotdigit = 0;
   if(lotstep == 0.1)
      local_lotdigit = 1;
   if(lotstep == 0.01)
      local_lotdigit = 2;

   // Get available money as Equity
   local_availablemoney = AccountEquity();
   // Maximum allowed Lot by the broker according to Equity. And we don't use 100% but 98%
   local_maxlot = MathMin(MathFloor(local_availablemoney * 0.98 / marginforonelot / lotstep) * lotstep, MaxLots);
   // Minimum allowed Lot by the broker
   local_minlot = MinLots;
   // Lot according to Risk. Don't use 100% but 98% (= 102) to avoid
   local_lotsize = MathMin(MathFloor(Risk / 102 * local_availablemoney / (StopLoss + AddPriceGap) / lotstep) * lotstep, MaxLots);
   local_lotsize = local_lotsize * multiplicator;
   local_lotsize = NormalizeDouble(local_lotsize, local_lotdigit);

   // Empty textstring
   local_textstring = "";

   // Use manual fix lotsize, but if necessary adjust to within limits
   if (MoneyManagement == FALSE)
   {
      // Set lotsize to manual lotsize
      local_lotsize = ManualLotsize;
      // Check if ManualLotsize is greater than allowed lotsize
      if (ManualLotsize > local_maxlot)
      {
         local_lotsize = local_maxlot;
         local_textstring = "Note: Manual lotsize is too high. It has been recalculated to maximum allowed " + DoubleToStr(local_maxlot,2);
         Print (local_textstring);
         Comment (local_textstring);
         ManualLotsize = local_maxlot;
      }
      else if (ManualLotsize < local_minlot)
         local_lotsize = local_minlot;
   }
   return (local_lotsize);
}

// Re-calculate a new Risk if the current one is too low or too high
double sub_recalculatewrongrisk()
{
   string local_textstring;
   double local_availablemoney;
   double local_maxlot;
   double local_minlot;
   double local_lotsize;
   double local_maxrisk;
   double local_minrisk;

   // Get available amount of money as Equity
   local_availablemoney = AccountEquity();
   // Maximum allowed Lot by the broker according to Equity
   local_maxlot = MathFloor(local_availablemoney / marginforonelot / lotstep) * lotstep;
   // Maximum allowed Risk by the broker according to maximul allowed Lot and Equity
   local_maxrisk = MathFloor(local_maxlot * (stoplevel + StopLoss) / local_availablemoney * 100 / 0.1) * 0.1;
   // Minimum allowed Lot by the broker
   local_minlot = MinLots;
   // Minimum allowed Risk by the broker according to minlots_broker
   local_minrisk = MathRound(local_minlot * StopLoss / local_availablemoney * 100 / 0.1) * 0.1;
   // Empty textstring
   local_textstring = "";


   if (MoneyManagement == TRUE)
   {
      // If Risk% is greater than the maximum risklevel the broker accept, then adjust Risk accordingly and print out changes
      if (Risk > local_maxrisk)
      {
         local_textstring = local_textstring + "Note: Risk has manually been set to " + DoubleToStr(Risk,1) + " but cannot be higher than " + DoubleToStr(local_maxrisk,1) + " according to ";
         local_textstring = local_textstring + "the broker, StopLoss and Equity. It has now been adjusted accordingly to " + DoubleToStr(local_maxrisk,1) + "%";
         Risk = local_maxrisk;
         sub_printandcomment(local_textstring);
      }
      // If Risk% is less than the minimum risklevel the broker accept, then adjust Risk accordingly and print out changes
      if (Risk < local_minrisk)
      {
         local_textstring = local_textstring + "Note: Risk has manually been set to " + DoubleToStr(Risk,1) + " but cannot be lower than " + DoubleToStr(local_minrisk,1) + " according to ";
         local_textstring = local_textstring + "the broker, StopLoss, AddPriceGap and Equity. It has now been adjusted accordingly to " + DoubleToStr(local_minrisk,1) + "%";
         Risk = local_minrisk;
         sub_printandcomment(local_textstring);
      }
   }
   // Don't use MoneyManagement, use fixed manual lotsize
   else // MoneyManagement == FALSE
   {
      // Check and if necessary adjust manual lotsize to external limits
      if (ManualLotsize < MinLots)
      {
         local_textstring = "Manual lotsize " + DoubleToStr(ManualLotsize,2) + " cannot be less than " + DoubleToStr(MinLots,2) + ". It has now been adjusted to " + DoubleToStr(MinLots,2);
         ManualLotsize = MinLots;
         sub_printandcomment(local_textstring);
      }
      if (ManualLotsize > MaxLots)
      {
         local_textstring = "Manual lotsize " + DoubleToStr(ManualLotsize,2) + " cannot be greater than " + DoubleToStr(MaxLots,2) + ". It has now been adjusted to " + DoubleToStr(MinLots,2);
         ManualLotsize = MaxLots;
         sub_printandcomment(local_textstring);
      }
      // Check to see that manual lotsize does not exceeds maximum allowed lotsize
      if (ManualLotsize > local_maxlot)
      {
         local_textstring = "Manual lotsize " + DoubleToStr(ManualLotsize,2) + " cannot be greater than maximum allowed lotsize. It has now been adjusted to " + DoubleToStr(local_maxlot,2);
         ManualLotsize = local_maxlot;
         sub_printandcomment(local_textstring);
      }
   }
}

// Print out broker details and other info
void sub_printdetails()
{
   string local_margintext;
   string local_stopouttext;
   string local_fixedlots;
   int local_type;
   int local_freemarginmode;
   int local_stopoutmode;

   local_type = IsDemo() + IsTesting();
   local_freemarginmode = AccountFreeMarginMode();
   local_stopoutmode = AccountStopoutMode();

   if (local_freemarginmode == 0)
      local_margintext = "that floating profit/loss is not used for calculation.";
   else if (local_freemarginmode == 1)
      local_margintext = "both floating profit and loss on open positions.";
   else if (local_freemarginmode == 2)
      local_margintext = "only profitable values, where current loss on open positions are not included.";
   else if (local_freemarginmode == 3)
      local_margintext = "only loss values are used for calculation, where current profitable open positions are not included.";

   if (local_stopoutmode == 0)
      local_stopouttext = "percentage ratio between margin and equity.";
   else if (local_stopoutmode == 1)
      local_stopouttext = "comparison of the free margin level to the absolute value.";

   if (MoneyManagement == TRUE)
      local_fixedlots = " (automatically calculated lots).";
   if (MoneyManagement == FALSE)
      local_fixedlots = " (fixed manual lots).";

   Print ("Broker name: ", AccountCompany());
   Print ("Broker server: ", AccountServer());
   Print ("Account type: ", StringSubstr("RealDemoTest", 4 * local_type, 4));
   Print ("Initial account balance: ", AccountBalance()," ", AccountCurrency());
   Print ("Broker digits: ", brokerdigits);
   Print ("Broker stoplevel / freezelevel (max): ", stoplevel);
   Print ("Broker stopout level: ", stopout,"%");
   Print ("Broker Point: ", DoubleToStr (Point, brokerdigits)," on ", AccountCurrency());
   Print ("Broker account leverage in percentage: ", leverage);
   Print ("Broker credit value on the account: ", AccountCredit());
   Print ("Broker account margin: ", AccountMargin());
   Print ("Broker calculation of free margin allowed to open positions considers " + local_margintext);
   Print ("Broker calculates stopout level as " + local_stopouttext);
   Print ("Broker requires at least ", marginforonelot," ", AccountCurrency()," in margin for 1 lot.");
   Print ("Broker set 1 lot to trade ", lotbase," ", AccountCurrency());
   Print ("Broker minimum allowed lotsize: ", MinLots);
   Print ("Broker maximum allowed lotsize: ", MaxLots);
   Print ("Broker allow lots to be resized in ", lotstep, " steps.");
   Print ("Risk: ", Risk,"%");
   Print ("Risk adjusted lotsize: ", DoubleToStr(lotsize,2) + local_fixedlots);
}

// Print and show comment of text
void sub_printandcomment(string par_text)
{
   Print (par_text);
   Comment (par_text);
}

// Summarize error messages that comes from the broker server
void sub_errormessages()
{
   int local_error = GetLastError();

   switch (local_error)
   {
      // Unchanged values
      case 1: // ERR_SERVER_BUSY:
      {
         err_unchangedvalues++;
         break;
      }
      // Trade server is busy
      case 4: // ERR_SERVER_BUSY:
      {
         err_busyserver++;
         break;
      }
      case 6: // ERR_NO_CONNECTION:
      {
         err_lostconnection++;
         break;
      }
      case 8: // ERR_TOO_FREQUENT_REQUESTS:
      {
         err_toomanyrequest++;
         break;
      }
      case 129: // ERR_INVALID_PRICE:
      {
         err_invalidprice++;
         break;
      }
      case 130: // ERR_INVALID_STOPS:
      {
         err_invalidstops++;
         break;
      }
      case 131: // ERR_INVALID_TRADE_VOLUME:
      {
         err_invalidtradevolume++;
         break;
      }
      case 135: // ERR_PRICE_CHANGED:
      {
         err_pricechange++;
         break;
      }
      case 137: // ERR_BROKER_BUSY:
      {
         err_brokerbuzy++;
         break;
      }
      case 138: // ERR_REQUOTE:
      {
         err_requotes++;
         break;
      }
      case 141: // ERR_TOO_MANY_REQUESTS:
      {
         err_toomanyrequests++;
         break;
      }
      case 145: // ERR_TRADE_MODIFY_DENIED:
      {
         err_trademodifydenied++;
         break;
      }
      case 146: // ERR_TRADE_CONTEXT_BUSY:
      {
         err_tradecontextbuzy++;
         break;
      }
   }
}

// Print out and comment summarized messages from the broker
void sub_printsumofbrokererrors()
{
   string local_txt;
   int local_totalerrors;

   local_txt = "Number of times the brokers server reported that ";

   local_totalerrors = err_unchangedvalues + err_busyserver + err_lostconnection + err_toomanyrequest + err_invalidprice
   + err_invalidstops + err_invalidtradevolume + err_pricechange + err_brokerbuzy + err_requotes + err_toomanyrequests
   + err_trademodifydenied + err_tradecontextbuzy;

   if (err_unchangedvalues > 0)
      sub_printandcomment(local_txt + "SL and TP was modified to existing values: " + DoubleToStr(err_unchangedvalues,0));
   if (err_busyserver > 0)
      sub_printandcomment(local_txt + "it is buzy: " + DoubleToStr(err_busyserver,0));
   if (err_lostconnection > 0)
      sub_printandcomment(local_txt + "the connection is lost: " + DoubleToStr(err_lostconnection,0));
   if (err_toomanyrequest > 0)
      sub_printandcomment(local_txt + "there was too many requests: " + DoubleToStr(err_toomanyrequest,0));
   if (err_invalidprice > 0)
      sub_printandcomment(local_txt + "the price was invalid: " + DoubleToStr(err_invalidprice,0));
   if (err_invalidstops > 0)
      sub_printandcomment(local_txt + "invalid SL and/or TP: " + DoubleToStr(err_invalidstops,0));
   if (err_invalidtradevolume > 0)
      sub_printandcomment(local_txt + "invalid lot size: " + DoubleToStr(err_invalidtradevolume,0));
   if (err_pricechange > 0)
      sub_printandcomment(local_txt + "the price has changed: " + DoubleToStr(err_pricechange,0));
   if (err_brokerbuzy > 0)
      sub_printandcomment(local_txt + "the broker is buzy: " + DoubleToStr(err_brokerbuzy,0));
   if (err_requotes > 0)
      sub_printandcomment(local_txt + "requotes " + DoubleToStr(err_requotes,0));
   if (err_toomanyrequests > 0)
      sub_printandcomment(local_txt + "too many requests " + DoubleToStr(err_toomanyrequests,0));
   if (err_trademodifydenied > 0)
      sub_printandcomment(local_txt + "modifying orders is denied " + DoubleToStr(err_trademodifydenied,0));
   if (err_tradecontextbuzy > 0)
      sub_printandcomment(local_txt + "trade context is buzy: " + DoubleToStr(err_tradecontextbuzy,0));
   if (local_totalerrors == 0)
      sub_printandcomment ("There was no error reported from the broker server!");
}
