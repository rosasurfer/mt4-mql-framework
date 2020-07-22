//             P L E A S E   -   D O    N O T    D E L E T E    A N Y T H I N G ! ! !
// -------------------------------------------------------------------------------------------------
//                                   XMT-Scalper v. 2.46
//
//                                       by Capella
//                             http://www.worldwide-invest.org
//                                  Copyright 2011 - 2014
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
// If you're a programmer and have suggestions for improvements, then please have the courtesy to
// share this and upload the new mq4-file to the above forum. Add a letter "a", "b", etc. to the
// version number to distinguish it from the official releases. Be sure to comment every line of
// code, and add your version comment at the end of the version list. Your contribution will be
// honored. All further releases will be posted on the above forum, as well as all feedback from
// users. All block code should have { and } in own lines without other code, this to enhance readability.
//
// Origin:
//
// The EA was originally based on the EA MillionDollarPips - but now totally rewritten from scratch.
// Not much remains from the original, except the core idea of the trading strategy.
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
// Ver. 1.0 - 2011-09-24 by Capella
// - Added Print lines for STOPLEVEL when errors (for debugging purposes)
// - Removed unused externals and variables
// - Moved dynamic TP/SL and trading signals constants to externals,
//   as VolatilityLimit and Scalpfactor.
// - Forced TrailingStop
//
// Ver. 2.0 - 2011-10-19  by Capella
// - Fixing bugs, and removed unused code.
// - Forced Trailing, as no-trailing cannot generate profit
// - Forced HighSpeed, as false mode cannot give good result
// - Added additional settings for scalping - UseMovingAverage,
//   UseBollingerBands, and OrderExpireSeconds
// - Automatic adjusted to broker STOPLEVEL, to avoid OrderSend error 130
//
// Ver 2.1 - 2011-11-91 by Capella
// - Added Indicatorperiod as external
// - Modified calculation of variable that triggers trade (pricedirection)
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
// - Fixed a bug for calculation of isbidgreaterthanindy
// Ver 2.1.4 - 2011-11-09 by Capella
// - Fixed a bug that only made the robot trade on SELL and SELLSTOP
// - Put back the call for the sub "sub_moveandfillarrays" except the last nonsense part of it.
// - Changed the default settings and re-ordered the global variables
// Ver 2.1.5 - 2011-11-10 by Capella
// - Fixed a bug that caused the robot to not trade for some brokers (if variable "scalpsize"
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
// - Fixed a bug for calculation of Commission. The variables "commissionpips" and
//   "commissionfactor" moved from locals to globals.
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
// Ver 2.4.3 - 2014-05 by Capella
// - Fixed bug - BBDeviation is INT not Double (wrong fix, see 2.461 below)
// - Moved IndicatorPeriod to externals
// - Minor bugs fixed
// - Compilation test on both MT4 Build 509 as well as on latest MT4 Build (currently 670)
// - Changed calculations from Balance to Equity (2014-08-05)
// Ver 2.44 - 2014-08/09 by Capella
// - Changed version presentation to only one point ( . ), i.e. 2.4.4. becomes 2.44
// - Added control of stray trades (trades without SL and TP).
//   If it finds a stray order it will try to add a SL 10 points from current price.
// - Changed how MinimumUseStopLevel is calculated and used. Now the StopLevel is the highest value of
//   either this value or the Broker StopLevel. This StopLevel is then added/substracted from the current
//   price for BuyStop and SellStop orders. The value expressed in Points.
// - Added spaces around ( and ) and after commas , to enhance readability
// - Added AUD and NZD as possible account currencies for calculation of multiplicator (used to correct lotsize),
//   and moved it to a subroutine.
// Ver 2.45 - 2014-09-30 by Capella
// - Fixed a bug for OrderExpireSeconds
// Ver 2.451 - 2014-11-14 by Capella
// - Fixed a bug for printout of BBands in Debug mode
// Ver 2.452 - 2014-11-15 by Capella
// - Fixed a bug for Magic (did not return a calculated value)
// Ver 2.46 - 2014-11-24 by Capella
// - Added the setting MinMarginLevel. No trading is allowed if free margin is below this percentage.
// - Added graphic trading presentation
// - Renamed variables names (globals starting with upper case, locals in lower case)
// - Adding spaced within parenthesis ( ... ) to enhance readability
// Ver 2.461 - 2015-01-09 by Capella
// - Fixed bug for BBDeviation, which is a double and not int
//---------------------------------------------------------------------------------------------------

#property copyright     "Copyright 2011-2014 by Capella at http://www.worldwide-invest.org"
#property version       "2.46"
#property link          "http://www.worldwide-invest.org"
#property description   "This is a FREE Shareware Expert Advisor for MetaTrader 4."
#property description   "Please do not remove the property section and version history."
#property description   "XMT-Scalper is a Tick Scalper for EURUSD M1, but can also work on other pairs, Gold and CFD's"
#property description   "It's extremely broker sensitive and requires tight spread."
#property description   "Read the PDF-file for explanations and settings."

//----------------------- Include files ------------------------------------------------------------

// Note: If the below files are stored in the installation directory of MT4 then the files should be
// written with " " around their names. If you however prefer to have the include files in the same
// directory as this EA, then the files below shoul be surropunded by < > instead.
#include "stdlib.mqh"        // "stdlib.mqh" or "<sdlib.mqh>
#include "stderror.mqh"      // "stderror.mqh" or <stderror.mqh>

//----------------------- External Globals ----------------------------------------------------------------
// All globals should here have their name starting with a CAPITAL character

extern string  Configuration              = "==== Configuration ====";
extern bool    ReverseTrade               = FALSE; // If TRUE, then trade in opposite direction
extern int     Magic                      = -1; // If set to a number less than 0 it will calculate MagicNumber automatically
extern string  OrderCmt                   = "XMT-Scalper 2.46"; // Trade comments that appears in the Trade and Account History tab
extern bool    ECN_Mode                   = FALSE; // True for brokers that don't accept SL and TP to be sent at the same time as the order
extern bool    Debug                      = FALSE; // Print huge log files with info, only for debugging purposes
extern bool    Verbose                    = FALSE; // Additional information printed in the chart
extern string  TradingSettings            = "==== Trade settings ====";
extern double  MaxSpread                  = 30.0; // Max allowed spread in points (1 / 10 pip)
extern int     MaxExecution               = 0; // Max allowed average execution time in ms (0 means no restrictions)
extern int     MaxExecutionMinutes        = 5; // How often in minutes should fake orders be sent to measure execution speed
extern double  StopLoss                   = 60; // StopLoss from as many points. Default 60 (= 6 pips)
extern double  TakeProfit                 = 100; // TakeProfit from as many points. Default 100 (= 10 pip)
extern double  AddPriceGap                = 0; // Additional price gap in points added to SL and TP in order to avoid Error 130
extern double  TrailingStart              = 20; // Start trailing profit from as so many points.
extern double  Commission                 = 0; // Some broker accounts charge commission in USD per 1.0 lot. Commission in dollar
extern int     Slippage                   = 3; // Maximum allowed Slippage in points
extern double  MinimumUseStopLevel        = 0; // Minimum stop level. Stoplevel to use will be max value of either this value or broker stoplevel
extern string  VolatilitySettings         = "==== Volatility Settings ====";
extern bool    UseDynamicVolatilityLimit  = TRUE; // Calculate VolatilityLimit based on INT (spread * VolatilityMultiplier)
extern double  VolatilityMultiplier       = 125; // Dynamic value, only used if UseDynamicVolatilityLimit is set to TRUE
extern double  VolatilityLimit            = 180; // Fix value, only used if UseDynamicVolatilityLimit is set to FALSE
extern bool    UseVolatilityPercentage    = TRUE; // If true, then price must break out more than a specific percentage
extern double  VolatilityPercentageLimit  = 0; // Percentage of how much iHigh-iLow difference must differ from VolatilityLimit. 0 is risky, 60 means a safe value
extern string  UseIndicatorSet            = "=== Indicators: 1 = Moving Average, 2 = BollingerBand, 3 = Envelopes";
extern int     UseIndicatorSwitch         = 1; // Switch User indicators.
extern int     Indicatorperiod            = 3; // Period in bars for indicators
extern double  BBDeviation                = 2.0; // Deviation for the iBands indicator
extern double  EnvelopesDeviation         = 0.07; // Deviation for the iEnvelopes indicator
extern int     OrderExpireSeconds         = 3600; // Orders are deleted after so many seconds
extern string  Money_Management           = "==== Money Management ====";
extern bool    MoneyManagement            = TRUE; // If TRUE then calculate lotsize automaticallay based on Risk, if False then use ManualLotsize below
extern double  MinLots                    = 0.01; // Minimum lot-size to trade with
extern double  MaxLots                    = 100.0; // Maximum allowed lot-size to trade with
extern double  Risk                       = 2.0; // Risk setting in percentage, For 10.000 in Equity 10% Risk and 60 StopLoss lotsize = 16.66
extern double  ManualLotsize              = 0.1; // Manual lotsize to trade with if MoneyManagement above is set to FALSE
extern double  MinMarginLevel             = 100; // Lowest allowed Margin level for new positions to be opened.
extern string  Screen_Shooter             = "==== Screen Shooter ====";
extern bool    TakeShots                  = FALSE; // Save screen shots on STOP orders?
extern int     DelayTicks                 = 1; // Delay so many ticks after new bar
extern int     ShotsPerBar                = 1; // How many screen shots per bar
extern string  DisplayGraphics            = "=== Display Graphics ==="; // Colors for sub_Display at upper left
extern int     Heading_Size               = 13;  // Font size for headline
extern int     Text_Size                  = 12;  // Font size for texts
extern color   Color_Heading              = Lime;  // Color for text lines
extern color   Color_Section1             = Yellow;          // -"-
extern color   Color_Section2             = Aqua;            // -"-
extern color   Color_Section3             = Orange;          // -"-
extern color   Color_Section4             = Magenta;         // -"-

//--------------------------- Globals --------------------------------------------------------------
// All globals should here have their name starting with a CAPITAL character

string EA_version = "XMT-Scalper v. 2.46";

int BrokerDigits = 0;      // Nnumber of digits that the broker uses for this currency pair
int GlobalError = 0;       // To keep track on number of added errors
int LastTime = 0;          // For measuring tics
int TickCounter = 0;       // Counting tics
int UpTo30Counter = 0;     // For calculating average spread
int Execution = -1;        // For Execution speed, -1 means no speed
int Avg_execution = 0;     // Average Execution speed
int Execution_samples = 0; // For calculating average Execution speed
int StartTime;             // Initial time
int Leverage;              // Account Leverage in percentage
int LotBase;               // Amount of money in base currency for 1 lot
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

double Tot_open_profit;    // A summary of the current open profit/loss for this EA
double Tot_open_lots;      // A summary of the current open lots for this EA
double Tot_open_swap;      // A summary of the current charged swaps of the open positions for this EA
double Tot_open_commission;// A summary of the currebt charged commission of the open positions for this EA
double G_equity;           // Current equity for this EA
double Changedmargin;      // Free margin for this account
double Tot_closed_lots;    // A summary of the current closed lots for this EA
double Tot_closed_profit;  // A summary of the current closed profit/loss for this EA
double Tot_closed_swap;    // A summary of the current closed swaps for this EA
double Tot_closed_comm;    // A summary of the current closed commission for this EA
double G_balance = 0;      // Balance for this EA
double Array_spread[30];   // Store spreads for the last 30 tics
double LotSize;            // Lotsize
double Highest;            // LotSize indicator value
double Lowest;             // Lowest indicator value
double StopLevel;          // Broker StopLevel
double StopOut;            // Broker stoput percentage
double LotStep;            // Broker LotStep
double MarginForOneLot;    // Margin required for 1 lot
double Avg_tickspermin;    // Used for simulation of latency during backtests
double MarginFree;          // Free margin in percentage

//======================= Program initialization ===================================================

int init()
{
   // Print short message at the start of initalization
   Print ("====== Initialization of ", EA_version, " ======");

   // If we have any objects on the screen then clear the screen
   sub_DeleteDisplay();   // clear the chart
   Comment ( "" );    // clear the chart

   // Reset time for Execution control
   StartTime = TimeLocal();

   // Reset error variable
   GlobalError = -1;

   // Get the broker decimals
   BrokerDigits = Digits;

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
      UseVolatilityPercentage = FALSE;

   // Adjust SL and TP to broker StopLevel if they are less than this StopLevel
   StopLoss = MathMax ( StopLoss, StopLevel );
   TakeProfit = MathMax ( TakeProfit, StopLevel );

   // Re-calculate variables
   VolatilityPercentageLimit = VolatilityPercentageLimit / 100 + 1;
   VolatilityMultiplier = VolatilityMultiplier / 10;
   ArrayInitialize ( Array_spread, 0 );
   VolatilityLimit = VolatilityLimit * Point;
   Commission = sub_normalizebrokerdigits ( Commission * Point );
   TrailingStart = TrailingStart * Point;
   StopLevel = StopLevel * Point;
   AddPriceGap = AddPriceGap * Point;

   // If we have set MaxLot and/or MinLots to more/less than what the broker allows, then adjust it accordingly
   if ( MinLots < MarketInfo ( Symbol(), MODE_MINLOT ) )
      MinLots = MarketInfo ( Symbol(), MODE_MINLOT );
   if ( MaxLots > MarketInfo ( Symbol(), MODE_MAXLOT ) )
      MaxLots = MarketInfo ( Symbol(), MODE_MAXLOT );
   if ( MaxLots < MinLots )
      MaxLots = MinLots;

   // Calculate margin required for 1 lot
   MarginForOneLot = MarketInfo ( Symbol(), MODE_MARGINREQUIRED );

   // Amount of money in base currency for 1 lot
   LotBase = MarketInfo ( Symbol(), MODE_LOTSIZE );

   // Also make sure that if the risk-percentage is too low or too high, that it's adjusted accordingly
   sub_recalculatewrongrisk();

   // Calculate intitial LotSize
   LotSize = sub_calculatelotsize();

   // If magic number is set to a value less than 0, then calculate MagicNumber automatically
   if ( Magic < 0 )
     Magic = sub_magicnumber();

   // If Execution speed should be measured, then adjust maxexecution from minutes to seconds
   if ( MaxExecution > 0 )
      MaxExecutionMinutes = MaxExecution * 60;

   // Print initial info
   sub_printdetails();

   // Check through all closed and open orders to get stats
   sub_CheckThroughAllClosedOrders();
   sub_CheckThroughAllOpenOrders();
   // Show info in graphics
   sub_ShowGraphInfo();

   // Print short message at the end of initialization
   Print ( "========== Initialization complete! ===========\n" );

   // Finally call the main trading subroutine
   start();

   return ( 0 );
}

//======================= Program deinitialization =================================================

int deinit()
{
   string text = "";

   // Print summarize of broker errors
   sub_printsumofbrokererrors();

   // Delete all objects on the screen
   sub_DeleteDisplay();
   //( Check through all closed orders
   sub_CheckThroughAllClosedOrders();
   // If we're running as backtest, then print some result
   if ( IsTesting ( ) == TRUE )
   {
      Print ( "Total closed lots = ", DoubleToStr ( Tot_closed_lots, 2 ) );
      Print ( "Total closed swap = ", DoubleToStr ( Tot_closed_swap, 2 ) );
      Print ( "Total closed commission = ", DoubleToStr ( Tot_closed_comm, 2 ) );

      // If we run backtests and simulate latency, then print result
      if ( MaxExecution > 0 )
      {
         text = text + "During backtesting " + SkippedTicks + " number of ticks was ";
         text = text + "skipped to simulate latency of up to " + MaxExecution + " ms";
         sub_printandcomment ( text );
      }
   }

   // Print short message when EA has been deinitialized
   Print ( EA_version, " has been deinitialized!" );

   return ( 0 );
}


//==================================== Program start ===============================================

int start()
{
   // We must wait til we have enough of bar data before we call trading routine
   if ( iBars ( Symbol(), PERIOD_M1 ) > Indicatorperiod )
   {
      sub_trade();
      // Check through all closed and open orders to get stats
      sub_CheckThroughAllClosedOrders();
      sub_CheckThroughAllOpenOrders();
      sub_ShowGraphInfo();
   }
   else
      Print ( "Please wait until enough of bar data has been gathered!" );

   return ( 0 );
}


//================================ Subroutines (aka function) starts here =========================================
// Notation:
// All actual and formal parameters in subs have their names starting with par_
// All local variables in subs have their names written in lower case
// All subroutines (aka function) except start(), init() and deinit() have their names starting with sub_ to

// This is the main trading subroutine
void sub_trade()
{
   string textstring;
   string pair;
   string indy;

   bool select;
   bool wasordermodified;
   bool ordersenderror;
   bool isbidgreaterthanima;
   bool isbidgreaterthanibands;
   bool isbidgreaterthanenvelopes;
   bool isbidgreaterthanindy;

   int orderticket;
   int orderexpiretime;
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
   double volatilitypercentage;
   double orderprice;
   double orderstoploss;
   double ordertakeprofit;
   double ihigh;
   double ilow;
   double imalow;
   double imahigh;
   double imadiff;
   double ibandsupper;
   double ibandslower;
   double ibandsdiff;
   double envelopesupper;
   double envelopeslower;
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

   // Get the Free Margin
   MarginFree = AccountFreeMargin();
   // Calculate Margin level
   if ( AccountMargin() != 0 )
      am = AccountMargin();
   marginlevel = AccountEquity() / am * 100;

   // Free Margin is less than the value of MinMarginLevel, so no trading is allowed
   if ( marginlevel < MinMarginLevel )
   {
      Comment ( "Warning! Free Margin " + DoubleToStr ( marginlevel, 2 ) + " is lower than MinMarginLevel!" );
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

   // Get Ask and Bid for the currency
   ask = MarketInfo ( Symbol(), MODE_ASK );
   bid = MarketInfo ( Symbol(), MODE_BID );

   // Calculate the channel of Volatility based on the difference of iHigh and iLow during current bar
   ihigh = iHigh ( Symbol(), PERIOD_M1, 0 );
   ilow = iLow ( Symbol(), PERIOD_M1, 0 );
   volatility = ihigh - ilow;

   // Reset printout string
   indy = "";

   // Calculate a channel on Moving Averages, and check if the price is outside of this channel.
   if ( UseIndicatorSwitch == 1 || UseIndicatorSwitch == 4 )
   {
      imalow = iMA ( Symbol(), PERIOD_M1, Indicatorperiod, 0, MODE_LWMA, PRICE_LOW, 0 );
      imahigh = iMA ( Symbol(), PERIOD_M1, Indicatorperiod, 0, MODE_LWMA, PRICE_HIGH, 0 );
      imadiff = imahigh - imalow;
      isbidgreaterthanima = bid >= imalow + imadiff / 2.0;
      indy = "iMA_low: " + sub_dbl2strbrokerdigits ( imalow ) + ", iMA_high: " + sub_dbl2strbrokerdigits ( imahigh ) + ", iMA_diff: " + sub_dbl2strbrokerdigits ( imadiff );
   }

   // Calculate a channel on BollingerBands, and check if the price is outside of this channel
   if ( UseIndicatorSwitch == 2 )
   {
      ibandsupper = iBands ( Symbol(), PERIOD_M1, Indicatorperiod, BBDeviation, 0, PRICE_OPEN, MODE_UPPER, 0 );
      ibandslower = iBands ( Symbol(), PERIOD_M1, Indicatorperiod, BBDeviation, 0, PRICE_OPEN, MODE_LOWER, 0 );
      ibandsdiff = ibandsupper - ibandslower;
      isbidgreaterthanibands = bid >= ibandslower + ibandsdiff / 2.0;
      indy = "iBands_upper: " + sub_dbl2strbrokerdigits ( ibandsupper ) + ", iBands_lower: " + sub_dbl2strbrokerdigits ( ibandslower ) + ", iBands_diff: " + sub_dbl2strbrokerdigits ( ibandsdiff );
   }

   // Calculate a channel on Envelopes, and check if the price is outside of this channel
   if ( UseIndicatorSwitch == 3 )
   {
      envelopesupper = iEnvelopes ( Symbol(), PERIOD_M1, Indicatorperiod, MODE_LWMA, 0, PRICE_OPEN, EnvelopesDeviation, MODE_UPPER, 0 );
      envelopeslower = iEnvelopes ( Symbol(), PERIOD_M1, Indicatorperiod, MODE_LWMA, 0, PRICE_OPEN, EnvelopesDeviation, MODE_LOWER, 0 );
      envelopesdiff = envelopesupper - envelopeslower;
      isbidgreaterthanenvelopes = bid >= envelopeslower + envelopesdiff / 2.0;
      indy = "iEnvelopes_upper: " + sub_dbl2strbrokerdigits ( envelopesupper ) + ", iEnvelopes_lower: " + sub_dbl2strbrokerdigits ( envelopeslower ) + ", iEnvelopes_diff: " + sub_dbl2strbrokerdigits ( envelopesdiff) ;
   }

   // Reset breakout variable as FALSE
   isbidgreaterthanindy = FALSE;

   // Reset pricedirection for no indication of trading direction
   pricedirection = 0;

   // If we're using iMA as indicator, then check if there's a breakout
   if ( UseIndicatorSwitch == 1 && isbidgreaterthanima == TRUE )
   {
      isbidgreaterthanindy = TRUE;
      Highest = imahigh;
      Lowest = imalow;
   }

   // If we're using iBands as indicator, then check if there's a breakout
   else if ( UseIndicatorSwitch == 2 && isbidgreaterthanibands == TRUE )
   {
      isbidgreaterthanindy = TRUE;
      Highest = ibandsupper;
      Lowest = ibandslower;
   }

   // If we're using iEnvelopes as indicator, then check if there's a breakout
   else if ( UseIndicatorSwitch == 3 && isbidgreaterthanenvelopes == TRUE )
   {
      isbidgreaterthanindy = TRUE;
      Highest = envelopesupper;
      Lowest = envelopeslower;
   }

   // Calculate spread
   spread = ask - bid;
   // Calculate lot size
   LotSize = sub_calculatelotsize();
   // calculatwe orderexpiretime
   if ( OrderExpireSeconds != 0 )
      orderexpiretime = TimeCurrent() + OrderExpireSeconds;
   else
      orderexpiretime = 0;

   // Calculate average true spread, which is the average of the spread for the last 30 tics
   ArrayCopy ( Array_spread, Array_spread, 0, 1, 29 );
   Array_spread[29] = spread;
   if ( UpTo30Counter < 30 )
      UpTo30Counter++;
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
   askpluscommission = sub_normalizebrokerdigits ( ask + Commission );
   bidminuscommission = sub_normalizebrokerdigits ( bid - Commission );
   realavgspread = avgspread + Commission;

   // Recalculate the VolatilityLimit if it's set to dynamic. It's based on the average of spreads + commission
   if ( UseDynamicVolatilityLimit == TRUE )
      VolatilityLimit = realavgspread * VolatilityMultiplier;

   // If the variables below have values it means that we have enough of data from broker server.
   if ( volatility && VolatilityLimit && Lowest && Highest && UseIndicatorSwitch != 4 )
   {
      // The Volatility is outside of the VolatilityLimit, so we can now open a trade
      if ( volatility > VolatilityLimit )
      {
         // Calculate how much it differs
         volatilitypercentage = volatility / VolatilityLimit;
         // In case of UseVolatilityPercentage == TRUE then also check if it differ enough of percentage
         if ( ( UseVolatilityPercentage == FALSE ) || ( UseVolatilityPercentage == TRUE && volatilitypercentage > VolatilityPercentageLimit ) )
         {
            if ( bid < Lowest )
              if ( ReverseTrade == FALSE )
                pricedirection = -1; // BUY or BUYSTOP
              else // ReverseTrade == true
                pricedirection = 1; // SELL or SELLSTOP
            else if ( bid > Highest )
              if ( ReverseTrade == FALSE )
                pricedirection = 1;  // SELL or SELLSTOP
              else // ReverseTrade == true
                pricedirection = -1; // BUY or BUYSTOP
         }
      }
      // The Volatility is less than the VolatilityLimit
      else
         volatilitypercentage = 0;
   }

   // Out of money
   if ( AccountEquity() <= 0.0 )
   {
      Comment ( "ERROR -- Account Equity is " + DoubleToStr ( MathRound ( AccountEquity() ), 0 ) );
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
            while ( TRUE )
            {
               // Update prices from the broker
               RefreshRates();
               // Set SL and TP
               orderstoploss = OrderStopLoss();
               ordertakeprofit = OrderTakeProfit();
               // Ok to modify the order if its TP is less than the price+commission+StopLevel AND price+StopLevel-TP greater than trailingStart
               if ( ordertakeprofit < sub_normalizebrokerdigits ( askpluscommission + TakeProfit * Point + AddPriceGap ) && askpluscommission + TakeProfit * Point + AddPriceGap - ordertakeprofit > TrailingStart )
               {
                  // Set SL and TP
                  orderstoploss = sub_normalizebrokerdigits ( bid - StopLoss * Point - AddPriceGap );
                  ordertakeprofit = sub_normalizebrokerdigits ( askpluscommission + TakeProfit * Point + AddPriceGap );
                  // Send an OrderModify command with adjusted SL and TP
                  if ( orderstoploss != OrderStopLoss() && ordertakeprofit != OrderTakeProfit() )
                  {
                     // Start Execution timer
                     Execution = GetTickCount();
                     // Try to modify order
                     wasordermodified = OrderModify ( OrderTicket(), 0, orderstoploss, ordertakeprofit, orderexpiretime, Lime );
                  }
                  // Order was modified with new SL and TP
                  if ( wasordermodified == TRUE )
                  {
                     // Calculate Execution speed
                     Execution = GetTickCount() - Execution;
                     // If we have choosen to take snapshots and we're not backtesting, then do so
                     if ( TakeShots && !IsTesting() )
                        sub_takesnapshot();
                     // Break out from while-loop since the order now has been modified
                     break;
                  }
                  // Order was not modified
                  else
                  {
                     // Reset Execution counter
                     Execution = -1;
                     // Add to errors
                     sub_errormessages();
                     // Print if debug or verbose
                     if ( Debug || Verbose )
                        Print ( "Order could not be modified because of ", ErrorDescription ( GetLastError() ) );
                     // Order has not been modified and it has no StopLoss
                     if ( orderstoploss == 0 )
                     // Try to modify order with a safe hard SL that is 3 pip from current price
                        wasordermodified = OrderModify ( OrderTicket(), 0, NormalizeDouble ( Bid - 30, BrokerDigits ), 0, 0, Red );
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
            while ( TRUE )
            {
               // Update broker prices
               RefreshRates();
               // Set SL and TP
               orderstoploss = OrderStopLoss();
               ordertakeprofit = OrderTakeProfit();
               // Ok to modify the order if its TP is greater than price-commission-StopLevel AND TP-price-commission+StopLevel is greater than trailingstart
               if ( ordertakeprofit > sub_normalizebrokerdigits ( bidminuscommission - TakeProfit * Point - AddPriceGap ) && ordertakeprofit - bidminuscommission + TakeProfit * Point - AddPriceGap > TrailingStart )
               {
                  // set SL and TP
                  orderstoploss = sub_normalizebrokerdigits ( ask + StopLoss * Point + AddPriceGap );
                  ordertakeprofit = sub_normalizebrokerdigits ( bidminuscommission - TakeProfit * Point - AddPriceGap );
                  // Send an OrderModify command with adjusted SL and TP
                  if ( orderstoploss != OrderStopLoss() && ordertakeprofit != OrderTakeProfit() )
                  {
                     // Start Execution timer
                     Execution = GetTickCount();
                     wasordermodified = OrderModify ( OrderTicket(), 0, orderstoploss, ordertakeprofit, orderexpiretime, Orange );
                  }
                  // Order was modiified with new SL and TP
                  if ( wasordermodified == TRUE )
                  {
                     // Calculate Execution speed
                     Execution = GetTickCount() - Execution;
                     // If we have choosen to take snapshots and we're not backtesting, then do so
                     if ( TakeShots && !IsTesting() )
                        sub_takesnapshot();
                     // Break out from while-loop since the order now has been modified
                     break;
                  }
                  // Order was not modified
                  else
                  {
                     // Reset Execution counter
                     Execution = -1;
                     // Add to errors
                     sub_errormessages();
                     // Print if debug or verbose
                     if ( Debug || Verbose )
                        Print ( "Order could not be modified because of ", ErrorDescription ( GetLastError() ) );
                     // Lets wait 1 second before we try to modify the order again
                     Sleep ( 1000 );
                     // Order has not been modified and it has no StopLoss
                     if ( orderstoploss == 0 )
                     // Try to modify order with a safe hard SL that is 3 pip from current price
                        wasordermodified = OrderModify ( OrderTicket(), 0, NormalizeDouble ( Ask + 30, BrokerDigits), 0, 0, Red );
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
            if ( isbidgreaterthanindy == FALSE )
            {
               // Calculate how much Price, SL and TP should be modified
               orderprice = sub_normalizebrokerdigits ( ask + StopLevel + AddPriceGap );
               orderstoploss = sub_normalizebrokerdigits ( orderprice - spread - StopLoss * Point - AddPriceGap );
               ordertakeprofit = sub_normalizebrokerdigits ( orderprice + Commission + TakeProfit * Point + AddPriceGap );
               // Start endless loop
               while ( TRUE )
               {
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
                     if ( wasordermodified == TRUE )
                     {
                        // Calculate Execution speed
                        Execution = GetTickCount() - Execution;
                        // Print if debug or verbose
                        if ( Debug || Verbose )
                           Print ( "Order executed in " + Execution + " ms" );
                     }
                     // Order was not modified
                     else
                     {
                        // Reset Execution counter
                        Execution = -1;
                        // Add to errors
                        sub_errormessages();
                     }
                  }
                  // Break out from endless loop
                  break;
               }
               // Increase counter
               counter1 ++;
            }
            // Price was larger than the indicator
            else
               // Delete the order
               select = OrderDelete ( OrderTicket() );
            // Break out from switch
            break;

         // We've found a matching SELLSTOP-order
         case OP_SELLSTOP:
            // Price must be larger than the indicator in order to modify the order, otherwise the order will be deleted
            if ( isbidgreaterthanindy == TRUE )
            {
               // Calculate how much Price, SL and TP should be modified
               orderprice = sub_normalizebrokerdigits ( bid - StopLevel - AddPriceGap );
               orderstoploss = sub_normalizebrokerdigits ( orderprice + spread + StopLoss * Point + AddPriceGap );
               ordertakeprofit = sub_normalizebrokerdigits ( orderprice - Commission - TakeProfit * Point - AddPriceGap );
               // Endless loop
               while ( TRUE )
               {
                  // Ok to modify order if price-StopLevel is greater than orderprice AND price-StopLevel-orderprice is greater than trailingstart
                  if ( orderprice > OrderOpenPrice() && orderprice - OrderOpenPrice() > TrailingStart)
                  {
                     // Send an OrderModify command with adjusted Price, SL and TP
                     if ( orderstoploss != OrderStopLoss() && ordertakeprofit != OrderTakeProfit() )
                     {
                        RefreshRates();
                        // Start Execution counter
                        Execution = GetTickCount();
                        wasordermodified = OrderModify ( OrderTicket(), orderprice, orderstoploss, ordertakeprofit, 0, Orange );
                     }
                     // Order was modified
                     if ( wasordermodified == TRUE )
                     {
                        // Calculate Execution speed
                        Execution = GetTickCount() - Execution;
                        // Print if debug or verbose
                        if ( Debug || Verbose )
                           Print ( "Order executed in " + Execution + " ms" );
                     }
                     // Order was not modified
                     else
                     {
                        // Reset Execution counter
                        Execution = -1;
                        // Add to errors
                        sub_errormessages();
                     }
                  }
                  // Break out from endless loop
                  break;
               }
               // count 1 more up
               counter1 ++;
            }
            // Price was NOT larger than the indicator, so delete the order
            else
               select = OrderDelete ( OrderTicket() );
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
   ordersenderror = FALSE;

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
   if ( counter1 == 0 && pricedirection != 0 && sub_normalizebrokerdigits ( realavgspread) <= sub_normalizebrokerdigits ( MaxSpread * Point ) && GlobalError == -1 )
   {
      // If we have a price breakout downwards (Bearish) then send a BUYSTOP order
      if ( pricedirection == -1 || pricedirection == 2 ) // Send a BUYSTOP
      {
         // Calculate a new price to use
         orderprice = ask + StopLevel;
         // SL and TP is not sent with order, but added afterwords in a OrderModify command
         if ( ECN_Mode == TRUE )
         {
            // Set prices for OrderModify of BUYSTOP order
            orderprice = askplusdistance;
            orderstoploss =  0;
            ordertakeprofit = 0;
            // Start Execution counter
            Execution = GetTickCount();
            // Send a BUYSTOP order without SL and TP
            orderticket = OrderSend ( Symbol(), OP_BUYSTOP, LotSize, orderprice, Slippage, orderstoploss, ordertakeprofit, OrderCmt, Magic, 0, Lime );
            // OrderSend was executed successfully
            if ( orderticket > 0 )
            {
               // Calculate Execution speed
               Execution = GetTickCount() - Execution;
               if ( Debug || Verbose )
                  Print ( "Order executed in " + Execution + " ms" );
               // If we have choosen to take snapshots and we're not backtesting, then do so
               if ( TakeShots && !IsTesting() )
                  sub_takesnapshot();
            }  // end if ordersend
            // OrderSend was NOT executed
            else
            {
               ordersenderror = TRUE;
               Execution = -1;
               // Add to errors
               sub_errormessages();
            }
            // OrderSend was executed successfully, so now modify it with SL and TP
            if ( OrderSelect ( orderticket, SELECT_BY_TICKET ) )
            {
               RefreshRates();
               // Set prices for OrderModify of BUYSTOP order
               orderprice = OrderOpenPrice();
               orderstoploss =  sub_normalizebrokerdigits ( orderprice - spread - StopLoss * Point - AddPriceGap );
               ordertakeprofit = sub_normalizebrokerdigits ( orderprice + TakeProfit * Point + AddPriceGap );
               // Start Execution timer
               Execution = GetTickCount();
               // Send a modify order for BUYSTOP order with new SL and TP
               wasordermodified = OrderModify ( OrderTicket(), orderprice, orderstoploss, ordertakeprofit, orderexpiretime, Lime );
               // OrderModify was executed successfully
               if ( wasordermodified == TRUE )
               {
                  // Calculate Execution speed
                  Execution = GetTickCount() - Execution;
                  if ( Debug || Verbose )
                     Print ( "Order executed in " + Execution + " ms" );
                  // If we have choosen to take snapshots and we're not backtesting, then do so
                  if ( TakeShots && !IsTesting() )
                     sub_takesnapshot();
               } // end successful ordermodiify
               // Order was NOT modified
               else
               {
                  ordersenderror = TRUE;
                  Execution = -1;
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
            orderprice = askplusdistance;//ask+StopLevel
            orderstoploss =  sub_normalizebrokerdigits ( orderprice - spread - StopLoss * Point - AddPriceGap );
            ordertakeprofit = sub_normalizebrokerdigits ( orderprice + TakeProfit * Point + AddPriceGap );
            // Start Execution counter
            Execution = GetTickCount();
            // Send a BUYSTOP order with SL and TP
            orderticket = OrderSend ( Symbol(), OP_BUYSTOP, LotSize, orderprice, Slippage, orderstoploss, ordertakeprofit, OrderCmt, Magic, orderexpiretime, Lime );
            if ( orderticket > 0 ) // OrderSend was executed suxxessfully
            {
               // Calculate Execution speed
               Execution = GetTickCount() - Execution;
               if ( Debug || Verbose )
                  Print ( "Order executed in " + Execution + " ms" );
               // If we have choosen to take snapshots and we're not backtesting, then do so
               if ( TakeShots && !IsTesting() )
                  sub_takesnapshot();
            } // end successful ordersend
            // Order was NOT sent
            else
            {
               ordersenderror = TRUE;
               // Reset Execution timer
               Execution = -1;
               // Add to errors
               sub_errormessages();
            } // end if-else
         } // end no ECN-mode
      } // end if pricedirection == -1 or 2

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
            // OrderSend was executed successfully
            if ( orderticket > 0 )
            {
               // Calculate Execution speed
               Execution = GetTickCount() - Execution;
               if ( Debug || Verbose )
                  Print ( "Order executed in " + Execution + " ms" );
               // If we have choosen to take snapshots and we're not backtesting, then do so
               if ( TakeShots && !IsTesting() )
                  sub_takesnapshot();
            }  // end if ordersend
            // OrderSend was NOT executed
            else
            {
               ordersenderror = TRUE;
               Execution = -1;
               // Add to errors
               sub_errormessages();
            }
            // If the SELLSTOP order was executed successfully, then select that order
            if ( OrderSelect(orderticket, SELECT_BY_TICKET ) )
            {
               RefreshRates();
               // Set prices for SELLSTOP order with modified SL and TP
               orderprice = OrderOpenPrice();
               orderstoploss = sub_normalizebrokerdigits ( orderprice + spread + StopLoss * Point + AddPriceGap );
               ordertakeprofit = sub_normalizebrokerdigits ( orderprice - TakeProfit * Point - AddPriceGap );
               // Start Execution timer
               Execution = GetTickCount();
               // Send a modify order with adjusted SL and TP
               wasordermodified = OrderModify ( OrderTicket(), OrderOpenPrice(), orderstoploss, ordertakeprofit, orderexpiretime, Orange );
            }
            // OrderModify was executed successfully
            if ( wasordermodified == TRUE )
            {
               // Calculate Execution speed
               Execution = GetTickCount() - Execution;
               // Print debug info
               if ( Debug || Verbose )
                  Print ( "Order executed in " + Execution + " ms" );
               // If we have choosen to take snapshots and we're not backtesting, then do so
               if ( TakeShots && !IsTesting() )
                  sub_takesnapshot();
            } // end if ordermodify was executed successfully
            // Order was NOT executed
            else
            {
               ordersenderror = TRUE;
               // Reset Execution timer
               Execution = -1;
               // Add to errors
               sub_errormessages();
            }
         }
         else // No ECN-mode, SL and TP can be sent directly
         {
            RefreshRates();
            // Set prices for SELLSTOP order with SL and TP
            orderprice = bidminusdistance;
            orderstoploss = sub_normalizebrokerdigits ( orderprice + spread + StopLoss * Point + AddPriceGap );
            ordertakeprofit = sub_normalizebrokerdigits ( orderprice - TakeProfit * Point - AddPriceGap );
            // Start Execution timer
            Execution = GetTickCount();
            // Send a SELLSTOP order with SL and TP
            orderticket = OrderSend ( Symbol(), OP_SELLSTOP, LotSize, orderprice, Slippage, orderstoploss, ordertakeprofit, OrderCmt, Magic, orderexpiretime, Orange );
            // If OrderSend was executed successfully
            if ( orderticket > 0 )
            {
               // Calculate exection speed for that order
               Execution = GetTickCount() - Execution;
               // Print debug info
               if ( Debug || Verbose )
                  Print ( "Order executed in " + Execution + " ms" );
               if ( TakeShots && !IsTesting() )
                  sub_takesnapshot();
            } // end successful ordersend
            // OrderSend was NOT executed successfully
            else
            {
               ordersenderror = TRUE;
               // Nullify Execution timer
               Execution = 0;
               // Add to errors
               sub_errormessages();
            } // end if-else
         } // end no ECN-mode
      } // end pricedirection == 0 or 2
   } // end if execute new orders

   // If we have no samples, every MaxExecutionMinutes a new OrderModify Execution test is done
   if ( MaxExecution && Execution == -1 && ( TimeLocal() - StartTime ) % MaxExecutionMinutes == 0 )
   {
      // When backtesting, simulate random Execution time based on the setting
      if ( IsTesting() && MaxExecution )
      {
         MathSrand ( TimeLocal( ));
         Execution = MathRand() / ( 32767 / MaxExecution );
      }
      else
      {
         // Unless backtesting, lets send a fake order to check the OrderModify Execution time,
         if ( IsTesting() == FALSE )
         {
            // To be sure that the fake order never is executed, st the price to twice the current price
            fakeprice = ask * 2.0;
            // Send a BUYSTOP order
            orderticket = OrderSend ( Symbol(), OP_BUYSTOP, LotSize, fakeprice, Slippage, 0, 0, OrderCmt, Magic, 0, Lime );
            Execution = GetTickCount();
            // Send a modify command where we adjust the price with +1 pip
            wasordermodified = OrderModify ( orderticket, fakeprice + 10 * Point, 0, 0, 0, Lime );
            // Calculate Execution speed
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
      Comment ( "Robot is initializing..." );
   else
   {
      // Error
      if ( GlobalError == -2 )
         Comment ( "ERROR -- Instrument " + Symbol() + " prices should have " + BrokerDigits + " fraction digits on broker account" );
      // No errors, ready to print
      else
      {
         textstring = TimeToStr ( TimeCurrent() ) + " Tick: " + sub_adjust00instring ( TickCounter );
         // Only show / print this if Debug OR Verbose are set to TRUE
         if ( Debug || Verbose )
         {
            textstring = textstring + "\n*** DEBUG MODE *** \nCurrency pair: " + Symbol() + ", Volatility: " + sub_dbl2strbrokerdigits ( volatility )
            + ", VolatilityLimit: " + sub_dbl2strbrokerdigits ( VolatilityLimit ) + ", VolatilityPercentage: " + sub_dbl2strbrokerdigits ( volatilitypercentage );
            textstring = textstring + "\nPriceDirection: " + StringSubstr ( "BUY NULLSELLBOTH", 4 * pricedirection + 4, 4 ) +  ", Expire: "
            + TimeToStr ( orderexpiretime, TIME_MINUTES ) + ", Open orders: " + counter1;
            textstring = textstring + "\nBid: " + sub_dbl2strbrokerdigits ( bid ) + ", Ask: " + sub_dbl2strbrokerdigits ( ask ) + ", " + indy;
            textstring = textstring + "\nAvgSpread: " + sub_dbl2strbrokerdigits ( avgspread ) + ", RealAvgSpread: " + sub_dbl2strbrokerdigits ( realavgspread )
            + ", Commission: " + sub_dbl2strbrokerdigits ( Commission ) + ", Lots: " + DoubleToStr ( LotSize, 2 ) + ", Execution: " + Execution + " ms";
            if ( sub_normalizebrokerdigits ( realavgspread ) > sub_normalizebrokerdigits ( MaxSpread * Point ) )
            {
               textstring = textstring + "\n" + "The current spread (" + sub_dbl2strbrokerdigits ( realavgspread )
               +") is higher than what has been set as MaxSpread (" + sub_dbl2strbrokerdigits ( MaxSpread * Point ) + ") so no trading is allowed right now on this currency pair!";
            }
            if ( MaxExecution > 0 && Avg_execution > MaxExecution )
            {
               textstring = textstring + "\n" + "The current Avg Execution (" + Avg_execution +") is higher than what has been set as MaxExecution ("
               + MaxExecution+ " ms), so no trading is allowed right now on this currency pair!";
            }
            Comment ( textstring );
            // Only print this if we have a any orders  OR have a price breakout OR Verbode mode is set to TRUE
            if ( counter1 != 0 || pricedirection != 0 )
               sub_printformattedstring ( textstring );
         }
      } // end if-else
   } // end check initialization

   // Check for stray market orders without SL
   sub_Check4StrayTrades();

} // end sub

void sub_Check4StrayTrades()
{
   int loop;
   int totals;
   bool modified = TRUE;
   bool selected;
   double ordersl;
   double newsl;

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
               if ( OrderType() == OP_BUY )
               {
                  // Set new SL 10 points away from current price
                  newsl = Bid - newsl * Point;
                  modified = OrderModify ( OrderTicket(), OrderOpenPrice(), NormalizeDouble ( newsl, Digits ), OrderTakeProfit(), 0, Blue );
               }
               else if ( OrderType() == OP_SELL )
               {
                  // Set new SL 10 points away from current price
                  newsl = Ask + newsl * Point;
                  modified = OrderModify ( OrderTicket(), OrderOpenPrice(), NormalizeDouble ( newsl, Digits ), OrderTakeProfit(), 0, Blue );
               } // If the order without previous SL was modified wit a new SL
               if ( modified == TRUE )
               {
                  // Select that modified order, set while condition variable to that true value and exit while-loop
                  selected = OrderSelect ( modified, SELECT_BY_TICKET, MODE_TRADES );
                  ordersl = OrderStopLoss();
                  break;
               }
               // If the order could not be modified
               else // if ( modified == FALSE )
               {
                  // Wait 1/10 second and then fetch new prices
                  Sleep ( 100 );
                  RefreshRates();
                  // Print debug info
                  if ( Debug || Verbose )
                     Print ( "Error trying to modify stray order with a SL!" );
                  // Add to errors
                  sub_errormessages();
               }
            }
         }
      }
   }
}

// Convert a decimal number to a text string
string sub_dbl2strbrokerdigits ( double par_a )
{
   return ( DoubleToStr ( par_a, BrokerDigits ) );
}

// Adjust numbers with as many decimals as the broker uses
double sub_normalizebrokerdigits ( double par_a )
{
   return ( NormalizeDouble ( par_a, BrokerDigits ) );
}

// Adjust textstring with zeros at the end
string sub_adjust00instring ( int par_a )
{
   if ( par_a < 10 )
      return ( "00" + par_a );
   if ( par_a < 100 )
      return ( "0" + par_a );
   return ( "" + par_a );
}

// Print out formatted textstring
void sub_printformattedstring ( string par_a )
{
   int difference;
   int a = -1;

   while ( a < StringLen ( par_a ) )
   {
      difference = a + 1;
      a = StringFind ( par_a, "\n", difference );
      if ( a == -1 )
      {
         Print ( StringSubstr ( par_a, difference ) );
         return;
      }
      Print ( StringSubstr ( par_a, difference, a - difference ) );
   }
}

double sub_multiplicator()
{
   // Calculate lot multiplicator for Account Currency. Assumes that account currency is any of the 8 majors.
   // If the account currency is of any other currency, then calculate the multiplicator as follows:
   // If base-currency is USD then use the BID-price for the currency pair USDXXX; or if the
   // counter currency is USD the use 1 / BID-price for the currency pair XXXUSD,
   // where XXX is the abbreviation for the account currency. The calculated lot-size should
   // then be multiplied with this multiplicator.
   double multiplicator = 1.0;
   int length;
   string appendix = "";

   if ( AccountCurrency() == "USD" )
      return ( multiplicator );
   length = StringLen ( Symbol() );
   if ( length != 6 )
      appendix = StringSubstr ( Symbol(), 6, length - 6 );
   if ( AccountCurrency() == "EUR" )
      multiplicator = 1.0 / MarketInfo ( "EURUSD" + appendix, MODE_BID );
   if ( AccountCurrency() == "GBP" )
      multiplicator = 1.0 / MarketInfo ( "GBPUSD" + appendix, MODE_BID );
   if ( AccountCurrency() == "AUD" )
      multiplicator = 1.0 / MarketInfo ( "AUDUSD" + appendix, MODE_BID );
   if ( AccountCurrency() == "NZD" )
      multiplicator = 1.0 / MarketInfo ( "NZDUSD" + appendix, MODE_BID );
   if ( AccountCurrency() == "CHF" )
      multiplicator = MarketInfo ( "USDCHF" + appendix, MODE_BID );
   if ( AccountCurrency() == "JPY" )
      multiplicator = MarketInfo ( "USDJPY" + appendix, MODE_BID );
   if ( AccountCurrency() == "CAD" )
      multiplicator = MarketInfo ( "USDCAD" + appendix, MODE_BID );
   if ( multiplicator == 0 )
      multiplicator = 1.0; // If account currency is neither of EUR, GBP, AUD, NZD, CHF, JPY or CAD we assumes that it is USD
   return ( multiplicator );
}

// Magic Number - calculated from a sum of account number + ASCII-codes from currency pair
int sub_magicnumber ()
{
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
   if ( Debug == TRUE )
      Print ( "MagicNumber: ", i );
   return ( i );
}

// Main routine for making a screenshoot / printscreen
void sub_takesnapshot()
{
   static datetime lastbar;
   static int doshot = -1;
   static int oldphase = 3000000;
   int shotinterval;
   int phase;

   if ( ShotsPerBar > 0 )
      shotinterval = MathRound ( ( 60 * Period() )  / ShotsPerBar );
   else
      shotinterval = 60 * Period();
   phase = MathFloor ( ( CurTime() - Time[0] ) / shotinterval );

   if ( Time[0] != lastbar )
   {
      lastbar = Time[0];
      doshot = DelayTicks;
   }
   else if ( phase > oldphase )
      sub_makescreenshot ( "i" );

   oldphase = phase;

   if ( doshot == 0 )
      sub_makescreenshot ( "" );
   if ( doshot >= 0 )
      doshot -= 1;
}

// add leading zeros that the resulting string has 'digits' length.
string sub_maketimestring ( int par_number, int par_digits )
{
   string result;

   result = DoubleToStr ( par_number, 0 );
   while ( StringLen ( result ) < par_digits )
      result = "0" + result;

   return ( result );
}

// Make a screenshoot / printscreen
void sub_makescreenshot ( string par_sx = "" )
{
   static int no = 0;

   no ++;
   string fn = "SnapShot" + Symbol() + Period() + "\\"+Year() + "-" + sub_maketimestring ( Month(), 2 ) + "-" + sub_maketimestring ( Day(), 2 )
   + " " + sub_maketimestring ( Hour(), 2 ) + "_" + sub_maketimestring ( Minute(), 2 ) + "_" + sub_maketimestring ( Seconds( ), 2 ) + " " + no + par_sx + ".gif";
   if ( !ScreenShot ( fn, 640, 480 ) )
      Print ( "ScreenShot error: ", ErrorDescription ( GetLastError() ) );
}

// Calculate LotSize based on Equity, Risk (in %) and StopLoss in points
double sub_calculatelotsize()
{
   string textstring;
   double availablemoney;
   double lotsize;
   double maxlot;
   double minlot;

   int lotdigit;

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
   lotsize = lotsize * sub_multiplicator();
   lotsize = NormalizeDouble ( lotsize, lotdigit );

   // Empty textstring
   textstring = "";

   // Use manual fix LotSize, but if necessary adjust to within limits
   if ( MoneyManagement == FALSE )
   {
      // Set LotSize to manual LotSize
      lotsize = ManualLotsize;
      // Check if ManualLotsize is greater than allowed LotSize
      if ( ManualLotsize > maxlot )
      {
         lotsize = maxlot;
         textstring = "Note: Manual LotSize is too high. It has been recalculated to maximum allowed " + DoubleToStr ( maxlot, 2 );
         Print ( textstring );
         Comment ( textstring );
         ManualLotsize = maxlot;
      }
      else if ( ManualLotsize < minlot )
         lotsize = minlot;
   }
   return ( lotsize );
}

// Re-calculate a new Risk if the current one is too low or too high
void sub_recalculatewrongrisk()
{
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

   if ( MoneyManagement == TRUE )
   {
      // If Risk% is greater than the maximum risklevel the broker accept, then adjust Risk accordingly and print out changes
      if ( Risk > maxrisk )
      {
         textstring = textstring + "Note: Risk has manually been set to " + DoubleToStr ( Risk, 1 ) + " but cannot be higher than " + DoubleToStr ( maxrisk, 1 ) + " according to ";
         textstring = textstring + "the broker, StopLoss and Equity. It has now been adjusted accordingly to " + DoubleToStr ( maxrisk, 1 ) + "%";
         Risk = maxrisk;
         sub_printandcomment ( textstring );
      }
      // If Risk% is less than the minimum risklevel the broker accept, then adjust Risk accordingly and print out changes
      if (Risk < minrisk)
      {
         textstring = textstring + "Note: Risk has manually been set to " + DoubleToStr ( Risk, 1 ) + " but cannot be lower than " + DoubleToStr ( minrisk, 1 ) + " according to ";
         textstring = textstring + "the broker, StopLoss, AddPriceGap and Equity. It has now been adjusted accordingly to " + DoubleToStr ( minrisk, 1 ) + "%";
         Risk = minrisk;
         sub_printandcomment ( textstring );
      }
   }
   // Don't use MoneyManagement, use fixed manual LotSize
   else // MoneyManagement == FALSE
   {
      // Check and if necessary adjust manual LotSize to external limits
      if ( ManualLotsize < MinLots )
      {
         textstring = "Manual LotSize " + DoubleToStr ( ManualLotsize, 2 ) + " cannot be less than " + DoubleToStr ( MinLots, 2 ) + ". It has now been adjusted to " + DoubleToStr ( MinLots, 2);
         ManualLotsize = MinLots;
         sub_printandcomment ( textstring );
      }
      if ( ManualLotsize > MaxLots )
      {
         textstring = "Manual LotSize " + DoubleToStr ( ManualLotsize, 2 ) + " cannot be greater than " + DoubleToStr ( MaxLots, 2 ) + ". It has now been adjusted to " + DoubleToStr ( MinLots, 2 );
         ManualLotsize = MaxLots;
         sub_printandcomment ( textstring );
      }
      // Check to see that manual LotSize does not exceeds maximum allowed LotSize
      if ( ManualLotsize > maxlot )
      {
         textstring = "Manual LotSize " + DoubleToStr ( ManualLotsize, 2 ) + " cannot be greater than maximum allowed LotSize. It has now been adjusted to " + DoubleToStr ( maxlot, 2 );
         ManualLotsize = maxlot;
         sub_printandcomment ( textstring );
      }
   }
}

// Print out broker details and other info
void sub_printdetails()
{
   string margintext;
   string stopouttext;
   string fixedlots;
   int type;
   int freemarginmode;
   int stopoutmode;
   double newsl;

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

   if ( MoneyManagement == TRUE )
      fixedlots = " (automatically calculated lots).";
   if ( MoneyManagement == FALSE )
      fixedlots = " (fixed manual lots).";

   Print ( "Broker name: ", AccountCompany() );
   Print ( "Broker server: ", AccountServer() );
   Print ( "Account type: ", StringSubstr ( "RealDemoTest", 4 * type, 4) );
   Print ( "Initial account equity: ", AccountEquity()," ", AccountCurrency() );
   Print ( "Broker digits: ", BrokerDigits);
   Print ( "Broker StopLevel / freezelevel (max): ", StopLevel );
   Print ( "Broker StopOut level: ", StopOut, "%" );
   Print ( "Broker Point: ", DoubleToStr ( Point, BrokerDigits )," on ", AccountCurrency() );
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

// Print and show comment of text
void sub_printandcomment ( string par_text )
{
   Print ( par_text );
   Comment ( par_text );
}

// Summarize error messages that comes from the broker server
void sub_errormessages()
{
   int error = GetLastError();

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

// Print out and comment summarized messages from the broker
void sub_printsumofbrokererrors()
{
   string txt;
   int totalerrors;

   txt = "Number of times the brokers server reported that ";

   totalerrors = Err_unchangedvalues + Err_busyserver + Err_lostconnection + Err_toomanyrequest + Err_invalidprice
   + Err_invalidstops + Err_invalidtradevolume + Err_pricechange + Err_brokerbuzy + Err_requotes + Err_toomanyrequests
   + Err_trademodifydenied + Err_tradecontextbuzy;

   if ( Err_unchangedvalues > 0 )
      sub_printandcomment ( txt + "SL and TP was modified to existing values: " + DoubleToStr ( Err_unchangedvalues, 0 ) );
   if ( Err_busyserver > 0 )
      sub_printandcomment ( txt + "it is buzy: " + DoubleToStr ( Err_busyserver, 0 ) );
   if ( Err_lostconnection > 0 )
      sub_printandcomment ( txt + "the connection is lost: " + DoubleToStr ( Err_lostconnection, 0 ) );
   if ( Err_toomanyrequest > 0 )
      sub_printandcomment ( txt + "there was too many requests: " + DoubleToStr ( Err_toomanyrequest, 0 ) );
   if ( Err_invalidprice > 0 )
      sub_printandcomment ( txt + "the price was invalid: " + DoubleToStr ( Err_invalidprice, 0 ) );
   if ( Err_invalidstops > 0 )
      sub_printandcomment ( txt + "invalid SL and/or TP: " + DoubleToStr ( Err_invalidstops, 0 ) );
   if ( Err_invalidtradevolume > 0 )
      sub_printandcomment ( txt + "invalid lot size: " + DoubleToStr ( Err_invalidtradevolume, 0 ) );
   if ( Err_pricechange > 0 )
      sub_printandcomment(txt + "the price has changed: " + DoubleToStr ( Err_pricechange, 0 ) );
   if ( Err_brokerbuzy > 0 )
      sub_printandcomment(txt + "the broker is buzy: " + DoubleToStr ( Err_brokerbuzy, 0 ) ) ;
   if ( Err_requotes > 0 )
      sub_printandcomment ( txt + "requotes " + DoubleToStr ( Err_requotes, 0 ) );
   if ( Err_toomanyrequests > 0 )
      sub_printandcomment ( txt + "too many requests " + DoubleToStr ( Err_toomanyrequests, 0 ) );
   if ( Err_trademodifydenied > 0 )
      sub_printandcomment ( txt + "modifying orders is denied " + DoubleToStr ( Err_trademodifydenied, 0 ) );
   if ( Err_tradecontextbuzy > 0)
      sub_printandcomment ( txt + "trade context is buzy: " + DoubleToStr ( Err_tradecontextbuzy, 0 ) );
   if ( totalerrors == 0 )
      sub_printandcomment ( "There was no error reported from the broker server!" );
}

void sub_CheckThroughAllOpenOrders()
{
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

void sub_CheckThroughAllClosedOrders()
{
   int pos;
   int openTotal = OrdersHistoryTotal();

   // Reset counters
   Tot_closed_pos = 0;
   Tot_closed_lots = 0;
   Tot_closed_profit = 0;
   Tot_closed_swap = 0;
   Tot_closed_comm = 0;
   G_balance = 0;

   // Loop through all closed orders
   for ( pos = 0; pos < openTotal; pos ++ )
   {
      // Select one order
      if ( OrderSelect ( pos, SELECT_BY_POS, MODE_HISTORY ) )    // Loop through the history pool of closed and deleted orders
      {
         // If the MagicNumber matches
         if ( OrderMagicNumber() == Magic && OrderSymbol() == Symbol() )    // If the orders are for this EA
         {
            // Fetch order info
            Tot_closed_lots += OrderLots();
            Tot_closed_profit += OrderProfit();
            Tot_closed_swap += OrderSwap();
            Tot_closed_comm += OrderCommission();
            // Count number of closed total orders for this EA
            Tot_closed_pos ++;
         }
      }
   }
   G_balance = Tot_closed_profit + Tot_closed_swap + Tot_closed_comm;
}

void sub_ShowGraphInfo()
{
   string line1;
   string line2;
   string line3;
   string line4;
   string line5;
// string line6;
   string line7;
// string line8;
   string line9;
   string line10;
   int textspacing = 10;
   int linespace;

   // Prepare for sub_Display
   line1 = EA_version;
   line2 = "Open: " + DoubleToStr ( Tot_open_pos, 0 ) + " positions, " + DoubleToStr ( Tot_open_lots, 2 ) + " lots with value: " + DoubleToStr ( Tot_open_profit, 2 );
   line3 = "Closed: " + DoubleToStr ( Tot_closed_pos, 0 ) + " positions, " + DoubleToStr ( Tot_closed_lots, 2 ) + " lots with value: " + DoubleToStr ( Tot_closed_profit, 2 );
   line4 = "EA Balance: " + DoubleToStr ( G_balance, 2 ) + ", Swap: " + DoubleToStr ( Tot_open_swap, 2 ) + ", Commission: " + DoubleToStr ( Tot_open_commission, 2 );
   line5 = "EA Equity: " + DoubleToStr ( G_equity, 2 ) + ", Swap: " + DoubleToStr ( Tot_closed_swap, 2 ) + ", Commission: "  + DoubleToStr ( Tot_closed_comm, 2 );
// line6
   line7 = "                               ";
// line8 = "";
   line9 = "Free margin: " + DoubleToStr ( MarginFree, 2 ) + ", Min allowed Margin level: " + DoubleToStr ( MinMarginLevel, 2 ) + "%";
   line10 = "Margin value: " + DoubleToStr ( Changedmargin, 2 );

   // sub_Display graphic information on the chart
   linespace = textspacing;
   sub_Display ( "line1", line1, Heading_Size, 3, linespace, Color_Heading, 0 );
   linespace = textspacing * 2 + Text_Size * 1 + 3 * 1;
   // linespace = textspacing * 2 + Text_Size * 2 + 3 * 2;  // Next line should look like this
   sub_Display ( "line2", line2, Text_Size, 3, linespace, Color_Section1, 0 );
   linespace = textspacing * 2 + Text_Size * 2 + 3 * 2 + 20;
   sub_Display ( "line3", line3, Text_Size, 3, linespace, Color_Section2, 0 );
   linespace = textspacing * 2 + Text_Size * 3 + 3 * 3 + 40;
   sub_Display ( "line4", line4, Text_Size, 3, linespace, Color_Section3, 0 );
   linespace = textspacing * 2 + Text_Size * 4 + 3 * 4 + 40;
   sub_Display ( "line5", line5, Text_Size, 3, linespace, Color_Section3, 0 );
// linespace = textspacing * 2 + Text_Size * 5 + 3 * 5 + 60;
// sub_Display ( "line6", line6, Text_Size, 3, linespace, Color_Section4, 0 );
   linespace = textspacing * 2 + Text_Size * 5 + 3 * 5 + 40;
   sub_Display ( "line7", line7, Text_Size, 3, linespace, Color_Section4, 0 );
// linespace = textspacing * 2 + Text_Size * 7 + 3 * 7 + 60;
// sub_Display ( "line8", line8, Text_Size, 3, linespace, Color_Section4, 0 );
   linespace = textspacing * 2 + Text_Size * 6 + 3 * 6 + 40;
   sub_Display ( "line9", line9, Text_Size, 3, linespace, Color_Section4, 0 );
   linespace = textspacing * 2 + Text_Size * 7 + 3 * 7 + 40;
   sub_Display ( "line10", line10, Text_Size, 3, linespace, Color_Section4, 0 );
}

void sub_Display ( string obj_name, string object_text, int object_text_fontsize, int object_x_distance, int object_y_distance, color object_textcolor, int object_corner_value )
{
   ObjectCreate ( obj_name, OBJ_LABEL, 0, 0, 0, 0, 0 );
   ObjectSet ( obj_name, OBJPROP_CORNER, object_corner_value );
   ObjectSet ( obj_name, OBJPROP_XDISTANCE, object_x_distance );
   ObjectSet ( obj_name, OBJPROP_YDISTANCE, object_y_distance );
   ObjectSetText ( obj_name, object_text, object_text_fontsize, "Tahoma", object_textcolor );
}

void sub_DeleteDisplay()
{
   ObjectsDeleteAll();
}
