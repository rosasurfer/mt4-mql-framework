// -------------------------------------------------------------------------------------------------
// MDP-Plus v. 2.2
//
// Based on MillionDollarPips - (ANY PAIR + NO DLL) - ver 1.1.0
//
// Someone at a russian forum fixed a Stack Overflow problem, added NDD-mode (ECN-mode)
// and moved the DLL-functions in the mql4-code.
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
// - Fixed a bug that caused the robot to not trade for some brokers (if variable "local_scalpsize" was 0.0)
// - Fixed a bug that could cause the lot-size to be calculated wrongly
// - Better output of debug information (more information)
// - Moved a fixed internal Max Spread to an external. The default internal value was 40 (4 pips), which is too high IMHI
// - Renamed some local variables to more proper names in order to make the code more readable
// - Cleaaned code further by removing unused code, etc.
// Ver 2.1.5a - 2011-11-15 by blueprint1972
// - Added Execution time in log files, to measure how fast orders are executed at the broker server
//
// Ver 2.2 - 2011-11-17 by Capella
// - An option to calculate VelocityLimit dynamically based on the spread
// - Removed parameter Scalpfactor as it had no impact on the trading conditions, only on lotsize
// - Better lot calculation, now entirely based on FreeMargin, Risk and StopLoss
// - A new scalp factor called VolatilityPercentageLimit based on the difference between VolatilityLimit and iHigh / iLow for triggering trades
// - Can now trade automatically on all currency pairs within spread limit from one single chart
// - Works on 4-digit brokers as well. Note: Performance on 4-digit brokers is worse than on 5-digit brokers, and there are much less trades

// -------------------------------------------------------------------------------------------------

#property show_inputs

#include <stdlib.mqh>

//----------------------- Externals ----------------------------------------------------------------
// All externals here have their name starting with a CAPITAL character

extern string Configuration = "==== Configuration ====";
extern int Magic = 0;                               // Any number that differs from other EA's numbers running at the same time
extern string OrderCmt = "";                        // Trade comments that appears in the Trade and Account History tab
extern string Suffix = "";                      // Common (broker specific) suffix for currencypair symbols (e.g.: "m" for "EURUSDm", "ifx", for "EURUSDifx" etc.)
extern bool NDDmode = FALSE;                        // For brokers that don't accept SL and TP to be sent at the same time as the order
extern bool Show_Debug = FALSE;                 // Print huge log files with info, only for debugging purposes
extern bool Verbose = FALSE;                        // Additional information printed in the chart
extern string TradingSettings = "==== Trade settings ====";
extern bool TradeALLCurrencyPairs = FALSE;  // If set to TRUE it weill trade on all pairs automatically, otherwise only on the chart pair
extern double MaxSpread = 26.0;             // Max allowed spread in points (1 / 10 pip)
extern double TakeProfit = 10.0;                    // TakeProfit from as many points. Default 10 (= 1 pip)
extern double StopLoss = 60.0;                  // StopLoss from as many points. Default 60 (= 6 pips)
extern double TrailingStart = 0;                    // Start trailing profit from as so many pips. Default 0
extern bool UseDynamicVolatilityLimit = TRUE;// Calculate VolatilityLimit based on INT (spread * VolatilityMultiplier)
extern double VolatilityMultiplier = 125;    // Only used if UseDynamicVolatilityLimit is set to TRUE
extern double VolatilityLimit = 180;            // Only used if UseDynamicVolatilityLimit is set to FALSE
extern bool UseVolatilityPercentage = FALSE;    // If true, then price must break out more than a specific percentage
extern double VolatilityPercentageLimit = 60;// Percentage of how much iHigh-iLow difference must differ from VolatilityLimit
extern bool UseMovingAverage = TRUE;            // User two iMA as channel
extern bool UseBollingerBands = TRUE;       // Use iBands as channel
//extern int IndicatorPeriod = 3;               // Period for iMA and iBands
extern double Deviation = 1.50;                     // Deviation for iBands
extern int OrderExpireSeconds = 3600;           // Orders are deleted after so many seconds
extern string Money_Management = "==== Money Management ====";
extern double MinLots = 0.01;                       // Minimum lot-size to trade with
extern double MaxLots = 1000.0;                 // Maximum allowed lot-size to trade with
extern double Risk = 2.0;                           // Risk setting in percentage, For 10.000 in Balance 10% Risk and 60 StopLoss lotsize = 16.66

//--------------------------- Globals --------------------------------------------------------------
// All globals have their name written in lower case characters

string allpairs[26] = {"EURUSD","USDJPY","GBPUSD","USDCHF","USDCAD","AUDUSD","NZDUSD","EURJPY","GBPJPY","CHFJPY","CADJPY","AUDJPY","NZDJPY","EURCHF","EURGBP","EURCAD","EURAUD","EURNZD","GBPCHF","GBPAUD","GBPCAD","GBPNZD","AUDCHF","AUDCAD","AUDNZD","NZDCHF","NZDCAD","CADCHF"};                                                                                    // Currency pairs to be watched
string tradablepairs[];  // Of the above 27 possible pairs, store all pairs that the broker support for trading here

bool condition5;
bool condition2 = FALSE;
bool trailingstop = TRUE;

int indicatorperiod = 3;
int distance = 0;
int brokerdigits = 0;
int slippage = 3;
int array_tickcounts[30];
int globalerror = 0;
int lasttime = 0;
int tickcounter = 0;
int upto30counter = 0;
int execution = 0;
int paircount = 0;          // number of currency pairs 27 (0 - 26)

double zero = 0.0;
double pipette = 0.0;
double maxamount = 0.0;
double minmaxlot = 0.1;
double zeropointfour = 0.4;
double one = 1.0;
double five = 5.0;
double ten = 10.0;
double twenty = 20.0;
double array_bid[30];
double array_ask[30];
double array_spread[30];
double highest;
double lowest;

//======================= Program initialization ===================================================

int init()
{
   int stoplevel;

    VolatilityPercentageLimit = VolatilityPercentageLimit / 100 + 1;
   VolatilityMultiplier = VolatilityMultiplier / 10;
   ArrayInitialize(array_spread, 0);
    VolatilityLimit = VolatilityLimit * Point;
   brokerdigits = Digits;
   pipette = Point;

    // Adjust TP, ST and distance to boker stoplevel if they are less than this stoplevel
    stoplevel = MathMax(MarketInfo(Symbol(), MODE_FREEZELEVEL), MarketInfo(Symbol(), MODE_STOPLEVEL));
    if (TakeProfit < stoplevel)
        TakeProfit = stoplevel;
    if (StopLoss < stoplevel)
        StopLoss = stoplevel;
    if (distance < stoplevel)
        distance = stoplevel;

    if (MathMod(Digits, 2) == 0)
        slippage = 0;
   else
        globalerror = -1;

    // If we have set MaxLot to more than what the broker allows, then adjust it accordingly
    if (MaxLots > MarketInfo(Symbol(), MODE_MAXLOT))
        MaxLots = MarketInfo(Symbol(), MODE_MAXLOT);

    // If we should trade on all currency pairs, then pick out the ones trhat the broker supports
    if (TradeALLCurrencyPairs == TRUE)
        sub_preparecurrencypairs();

    // Finally call the main trading subroutine
   start();

   return (0);
}

//==================================== Program start ===============================================

int start()
{
   if (brokerdigits == 0)
    {
      init();
      return;
   }
    sub_moveandfillarrays(array_bid, array_ask, array_tickcounts, one);
    sub_trade();
   return (0);
}


//================================ Subroutines starts here =========================================
// All subs have their names starting with sub_
// Exception are the standard routines init() and start()
//
// Notation:
// All actual and formal parameters in subs have their names starting with par_
// All local variables in subs have thewir names starting with local_

void sub_trade()
{
   string local_textstring;
    string local_pair;

   bool local_wasordermodified;
   bool local_usestoporders;
    bool local_ordersenderror;
    bool local_isbidgreaterthanima;
    bool local_isbidgreaterthanibands;
    bool local_isbidgreaterthanindy;

   int local_orderticket;
   int local_orderexpiretime;
   int local_lotstep;
   int local_bidpart;
   int local_askpart;
    int local_loopcount2;
    int local_loopcount1;
    int local_pricedirection;
   int local_counter1;
   int local_counter2;
    int local_paircounter;

   double local_askplusdistance;
   double local_bidminusdistance;
    double local_commissionpips;
   double local_commissionfactor;
    double local_volatilitypercentage;
   double local_trailingdistance;
   double local_c;
   double local_scalpsize;
   double local_d;
   double local_orderstoploss;
   double local_ordertakeprofit;
   double local_tpadjust;
    double local_ihigh;
   double local_ilow;
    double local_imalow;
   double local_imahigh;
   double local_imadiff;
   double local_ibandsupper;
   double local_ibandslower;
   double local_ibandsdiff;
   double local_volatility;
    double local_stoplevel;
   double local_spread;
   double local_adjuststoplevel;
    double local_e;
   double local_avgspread;
    double local_f;
   double local_g;
   double local_realavgspread;
    double local_i;

   if (lasttime < Time[0])
    {
      lasttime = Time[0];
      tickcounter = 0;
   }
    else
        tickcounter++;

    // If we only are going to trade on this chart currency pair, then reset the counter to 0, meaning EURUSD
    if (TradeALLCurrencyPairs == FALSE)
    {
        paircount = 1;
        local_pair = Symbol();
    }

    for (local_paircounter = 0; local_paircounter != paircount; local_paircounter++)
    {
        local_pair = tradablepairs[local_counter1];
        // Calculate the channel of Volatility based on the difference of iHigh and iLow during current bar
        local_ihigh = iHigh(local_pair, PERIOD_M1, 0);
        local_ilow = iLow(local_pair, PERIOD_M1, 0);
        local_volatility = local_ihigh - local_ilow;

        // Calculate a channel on MovingAverage, and check if the price is outside of this channel
        local_imalow = iMA(local_pair, PERIOD_M1, indicatorperiod, 0, MODE_LWMA, PRICE_LOW, 0);
        local_imahigh = iMA(local_pair, PERIOD_M1, indicatorperiod, 0, MODE_LWMA, PRICE_HIGH, 0);
        local_imadiff = local_imahigh - local_imalow;
        local_isbidgreaterthanima = Bid >= local_imalow + local_imadiff / 2.0;

        // Calculate a channel on BollingerBands, and check if the prcice is outside of this channel
        local_ibandsupper = iBands(local_pair, PERIOD_M1, indicatorperiod, Deviation, 0, PRICE_OPEN, MODE_UPPER, 0);
        local_ibandslower = iBands(local_pair, PERIOD_M1, indicatorperiod, Deviation, 0, PRICE_OPEN, MODE_LOWER, 0);

        local_ibandsdiff = local_ibandsupper - local_ibandslower;
        local_isbidgreaterthanibands = Bid >= local_ibandslower + local_ibandsdiff / 2.0;

        // Calculate the highest and lowest values depending on which indicators to be used
        local_isbidgreaterthanindy = FALSE;
        if (UseMovingAverage == FALSE && UseBollingerBands == TRUE && local_isbidgreaterthanibands == TRUE)
        {
            local_isbidgreaterthanindy = TRUE;
            highest = local_ibandsupper;
            lowest = local_ibandslower;
        }
        else if (UseMovingAverage == TRUE && UseBollingerBands == FALSE && local_isbidgreaterthanima == TRUE)
        {
            local_isbidgreaterthanindy = TRUE;
            highest = local_imahigh;
            lowest = local_imalow;
        }
        else if (UseMovingAverage == TRUE && UseBollingerBands == TRUE && local_isbidgreaterthanima == TRUE && local_isbidgreaterthanibands == TRUE)
        {
            local_isbidgreaterthanindy = TRUE;
            highest = MathMax(local_ibandsupper, local_imahigh);
            lowest = MathMin(local_ibandslower, local_imalow);
        }

        if (!condition2)
        {
            for (local_loopcount2 = OrdersTotal() - 1; local_loopcount2 >= 0; local_loopcount2--)
            {
                OrderSelect(local_loopcount2, SELECT_BY_POS, MODE_TRADES);
                if (OrderSymbol() == local_pair && OrderCloseTime() != 0 && OrderClosePrice() != OrderOpenPrice() && OrderProfit() != 0.0 && OrderComment() != "partial close" && StringFind(OrderComment(), "[sl]from #") == -1 && StringFind(OrderComment(), "[tp]from #") == -1)
                {
                    condition2 = TRUE;
                    local_commissionfactor = MathAbs(OrderProfit() / (OrderClosePrice() - OrderOpenPrice()));
                    local_commissionpips = (-OrderCommission()) / local_commissionfactor;
                    Print("Commission_Rate : " + sub_dbl2strbrokerdigits(local_commissionpips));
                    break;
                }
            }
        }

        if (!condition2)
        {
            for (local_loopcount2 = OrdersHistoryTotal() - 1; local_loopcount2 >= 0; local_loopcount2--)
            {
                OrderSelect(local_loopcount2, SELECT_BY_POS, MODE_HISTORY);
                if (OrderSymbol() == local_pair && OrderCloseTime() != 0 && OrderClosePrice() != OrderOpenPrice() && OrderProfit() != 0.0 && OrderComment() != "partial close" && StringFind(OrderComment(), "[sl]from #") == -1 &&
                    StringFind(OrderComment(), "[tp]from #") == -1)
                {
                    condition2 = TRUE;
                    local_commissionfactor = MathAbs(OrderProfit() / (OrderClosePrice() - OrderOpenPrice()));
                    local_commissionpips = (-OrderCommission()) / local_commissionfactor;
                    Print("Commission_Rate : " + sub_dbl2strbrokerdigits(local_commissionpips));
                    break;
                }
            }
        }

        local_stoplevel = MathMax(MarketInfo(local_pair, MODE_FREEZELEVEL), MarketInfo(local_pair, MODE_STOPLEVEL) ) * Point;
        local_spread = Ask - Bid;

        local_adjuststoplevel = 0.5;
        if (local_adjuststoplevel < local_stoplevel - 5.0 * pipette)
        {
            local_usestoporders = FALSE;
            local_trailingdistance = MaxSpread * pipette;
            local_adjuststoplevel = ten * pipette;
            local_c = five * pipette;
        }
        else
        {
            local_usestoporders = TRUE;
            local_trailingdistance = twenty * pipette;
            local_adjuststoplevel = zero * pipette;
            local_c = TrailingStart * pipette;
        }

        local_trailingdistance = MathMax(local_trailingdistance, local_stoplevel);
        if (local_usestoporders)
            local_adjuststoplevel = MathMax(local_adjuststoplevel, local_stoplevel);
        ArrayCopy(array_spread, array_spread, 0, 1, 29);
        array_spread[29] = local_spread;
        if (upto30counter < 30)
            upto30counter++;
        local_e = 0;
        local_loopcount2 = 29;
        for (local_loopcount1 = 0; local_loopcount1 < upto30counter; local_loopcount1++)
        {
            local_e += array_spread[local_loopcount2];
            local_loopcount2--;
        }

        // Calculate an average of spreads based on the spread from the last 30 tics
        local_avgspread = local_e / upto30counter;

        // Calculate price and spread considering commission
        local_f = sub_normalizebrokerdigits(Ask + local_commissionpips);
        local_g = sub_normalizebrokerdigits(Bid - local_commissionpips);
        local_realavgspread = local_avgspread + local_commissionpips;

        // Recalculate the VolatilityLimit if it's set to dynamic. It's based on the average of spreads + commission
        if (UseDynamicVolatilityLimit == TRUE)
            VolatilityLimit = local_realavgspread * VolatilityMultiplier;

        local_pricedirection = 0;

        // If the variables below have values it means that we have enough of data from broker server
        if(local_volatility && VolatilityLimit && lowest && highest)
        {
            // The Volatility is outside of the VolatilityLimit, so we now have  to open a trade
            if (local_volatility > VolatilityLimit)
            {
                // Calculate how much it differs
                local_volatilitypercentage = local_volatility / VolatilityLimit;
                // In case of UseVolatilityPercentage == TRUE then also check if it differ enough of percentage
                if ((UseVolatilityPercentage == FALSE) || (UseVolatilityPercentage == TRUE && local_volatilitypercentage > VolatilityPercentageLimit))
                {
                    if (Bid < lowest)
                        local_pricedirection = -1; // BUY or BUYSTOP
                    else if (Bid > highest)
                        local_pricedirection = 1;  // SELL or SELLSTOP
                }
            }
            else
                local_volatilitypercentage = 0;
        }

        local_scalpsize = MathMax(local_stoplevel, local_scalpsize);

        if (Bid == 0.0 || MarketInfo(local_pair, MODE_LOTSIZE) == 0.0)
            local_scalpsize = 0;

        local_orderexpiretime = TimeCurrent() + OrderExpireSeconds;

        if (MarketInfo(local_pair, MODE_LOTSTEP) == 0.0)
            local_lotstep = 5;
        else
            local_lotstep = sub_logarithm(0.1, MarketInfo(local_pair, MODE_LOTSTEP));

        if (Risk < 0.001 || Risk > 100.0)
        {
            Comment("ERROR -- Invalid Risk Value.");
            return;
        }

        if (AccountBalance() <= 0.0)
        {
            Comment("ERROR -- Account Balance is " + DoubleToStr(MathRound(AccountBalance()), 0));
            return;
        }

        // Calculate lotsize based on FreeMargin, Risk in % and StopLoss
        minmaxlot = NormalizeDouble(AccountFreeMargin() * Risk / 100 / StopLoss, 2);

        // Lotsize is higher that the max allowed lotsized, so reduce lotsize to maximum allowed lotsize
        if (minmaxlot > MaxLots)
            minmaxlot = MaxLots;

        // Reset counters
        local_counter1 = 0;
        local_counter2 = 0;
        // Loop through all open orders (if any)
        for (local_loopcount2 = 0; local_loopcount2 < OrdersTotal(); local_loopcount2++)
        {
            OrderSelect(local_loopcount2, SELECT_BY_POS, MODE_TRADES);
            if (OrderMagicNumber() == Magic && OrderCloseTime() == 0)
            {
                if (OrderSymbol() != local_pair)
                {
                    local_counter2++;
                    continue;
                }
                switch (OrderType())
                {
                case OP_BUY:
                    while (trailingstop)
                    {
                        local_orderstoploss = OrderStopLoss();
                        local_ordertakeprofit = OrderTakeProfit();
                        if (!(local_ordertakeprofit < sub_normalizebrokerdigits(local_f + local_trailingdistance) && local_f + local_trailingdistance - local_ordertakeprofit > local_c))
                            break;
                        local_orderstoploss = sub_normalizebrokerdigits(Bid - local_trailingdistance);
                        local_ordertakeprofit = sub_normalizebrokerdigits(local_f + local_trailingdistance);
                        execution = GetTickCount();
                        local_wasordermodified = OrderModify(OrderTicket(), 0, local_orderstoploss, local_ordertakeprofit, local_orderexpiretime, Lime);
                        execution = GetTickCount() - execution;
                        break;
                    }
                    local_counter1++;
                    break;
                case OP_SELL:
                    while (trailingstop)
                    {
                        local_orderstoploss = OrderStopLoss();
                        local_ordertakeprofit = OrderTakeProfit();
                        if (!(local_ordertakeprofit > sub_normalizebrokerdigits(local_g - local_trailingdistance) && local_ordertakeprofit - local_g + local_trailingdistance > local_c))
                            break;
                        local_orderstoploss = sub_normalizebrokerdigits(Ask + local_trailingdistance);
                        local_ordertakeprofit = sub_normalizebrokerdigits(local_g - local_trailingdistance);
                        execution = GetTickCount();
                        local_wasordermodified = OrderModify(OrderTicket(), 0, local_orderstoploss, local_ordertakeprofit, local_orderexpiretime, Orange);
                        execution = GetTickCount() - execution;
                        break;
                    }
                    local_counter1++;
                    break;
                case OP_BUYSTOP:
                    if (!local_isbidgreaterthanima)
                    {
                        local_tpadjust = OrderTakeProfit() - OrderOpenPrice() - local_commissionpips;
                        while (true)
                        {
                            if (!(sub_normalizebrokerdigits(Ask + local_adjuststoplevel) < OrderOpenPrice() && OrderOpenPrice() - Ask - local_adjuststoplevel > local_c))
                                break;
                            execution = GetTickCount();
                            local_wasordermodified = OrderModify(OrderTicket(), sub_normalizebrokerdigits(Ask + local_adjuststoplevel), sub_normalizebrokerdigits(Bid + local_adjuststoplevel - local_tpadjust), sub_normalizebrokerdigits(local_f + local_adjuststoplevel + local_tpadjust), 0, Lime);
                            execution = GetTickCount() - execution;
                            break;
                        }
                        local_counter1++;
                    }
                    else
                        OrderDelete(OrderTicket());
                    break;
                case OP_SELLSTOP:
                    if (local_isbidgreaterthanima)
                    {
                        local_tpadjust = OrderOpenPrice() - OrderTakeProfit() - local_commissionpips;
                        while (true)
                        {
                            if (!(sub_normalizebrokerdigits(Bid - local_adjuststoplevel) > OrderOpenPrice() && Bid - local_adjuststoplevel - OrderOpenPrice() > local_c))
                                break;
                            execution = GetTickCount();
                            local_wasordermodified = OrderModify(OrderTicket(), sub_normalizebrokerdigits(Bid - local_adjuststoplevel), sub_normalizebrokerdigits(Ask - local_adjuststoplevel + local_tpadjust), sub_normalizebrokerdigits(local_g - local_adjuststoplevel - local_tpadjust), 0, Orange);
                            execution = GetTickCount() - execution;
                            break;
                        }
                        local_counter1++;
                    }
                    else
                        OrderDelete(OrderTicket());
                } // end of switch
            }  // end if OrderMagicNumber
        } // end for loopcount2
        local_ordersenderror = FALSE;
        if (globalerror >= 0 || globalerror == -2)
        {
            local_bidpart = NormalizeDouble(Bid / pipette, 0);
            local_askpart = NormalizeDouble(Ask / pipette, 0);
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
        if (local_counter1 == 0 && local_pricedirection != 0 && sub_normalizebrokerdigits(local_realavgspread) <= sub_normalizebrokerdigits(MaxSpread * pipette) && globalerror == -1)
        {
            if (local_pricedirection < 0)
            {
                execution = GetTickCount();
                if (local_usestoporders)
                {
                local_askplusdistance = Ask + distance * Point;
                    if (NDDmode)
                    {
                        local_orderticket = OrderSend(local_pair, OP_BUYSTOP, minmaxlot, local_askplusdistance, slippage, 0, 0, OrderCmt, Magic, 0, Lime);
                        if (OrderSelect(local_orderticket, SELECT_BY_TICKET))
                            OrderModify(OrderTicket(), OrderOpenPrice(), local_askplusdistance - StopLoss * Point, local_askplusdistance + TakeProfit * Point, local_orderexpiretime, Lime);
                    }
                    else
                        local_orderticket = OrderSend(local_pair, OP_BUYSTOP, minmaxlot, local_askplusdistance, slippage, local_askplusdistance - StopLoss * Point, local_askplusdistance + TakeProfit * Point, OrderCmt, Magic, local_orderexpiretime, Lime);
                    if (local_orderticket < 0)
                    {
                        local_ordersenderror = TRUE;
                        Print("ERROR BUYSTOP : " + sub_dbl2strbrokerdigits(Ask + local_adjuststoplevel) + " SL:" + sub_dbl2strbrokerdigits(Bid + local_adjuststoplevel - local_scalpsize) + " TP:" + sub_dbl2strbrokerdigits(local_f + local_adjuststoplevel + local_scalpsize));
                        execution = 0;
                    }
                    else
                    {
                        execution = GetTickCount() - execution;
                        PlaySound("news.wav");
                        Print("BUYSTOP : " + sub_dbl2strbrokerdigits(Ask + local_adjuststoplevel) + " SL:" + sub_dbl2strbrokerdigits(Bid + local_adjuststoplevel - local_scalpsize) + " TP:" + sub_dbl2strbrokerdigits(local_f + local_adjuststoplevel + local_scalpsize));
                    }
                }
                else
                {
                    if (Bid - local_ilow > 0.0)
                    {
                        local_orderticket = OrderSend(local_pair, OP_BUY, minmaxlot, Ask, slippage, 0, 0, OrderCmt, Magic, local_orderexpiretime, Lime);
                        if (local_orderticket < 0)
                        {
                            local_ordersenderror = TRUE;
                            Print("ERROR BUY Ask:" + sub_dbl2strbrokerdigits(Ask) + " SL:" + sub_dbl2strbrokerdigits(Bid - local_scalpsize) + " TP:" + sub_dbl2strbrokerdigits(local_f + local_scalpsize));
                            execution = 0;
                        }
                        else
                        {
                            while (true)
                            {
                                local_wasordermodified = OrderModify(local_orderticket, 0, sub_normalizebrokerdigits(Bid - local_scalpsize), sub_normalizebrokerdigits(local_f + local_scalpsize), local_orderexpiretime, Lime);
                                break;
                            }
                            execution = GetTickCount() - execution;
                            PlaySound("news.wav");
                            Print("BUY Ask:" + sub_dbl2strbrokerdigits(Ask) + " SL:" + sub_dbl2strbrokerdigits(Bid - local_scalpsize) + " TP:" + sub_dbl2strbrokerdigits(local_f + local_scalpsize));
                        }
                    }
                }
            }
            else
            {
                if (local_pricedirection > 0)
                {
                    if (local_usestoporders)
                    {
                        local_bidminusdistance = Bid - distance * Point;
                        execution = GetTickCount();
                        if (NDDmode)
                        {
                            local_orderticket = OrderSend(local_pair, OP_SELLSTOP, minmaxlot, local_bidminusdistance, slippage, 0, 0, OrderCmt, Magic, 0, Orange);
                            if (OrderSelect(local_orderticket, SELECT_BY_TICKET))
                                OrderModify(OrderTicket(), OrderOpenPrice(), local_bidminusdistance + StopLoss * Point, local_bidminusdistance - TakeProfit * Point, local_orderexpiretime, Orange);
                        }
                        else
                            local_orderticket = OrderSend(local_pair, OP_SELLSTOP, minmaxlot, local_bidminusdistance, slippage, local_bidminusdistance + StopLoss * Point, local_bidminusdistance - TakeProfit * Point, OrderCmt, Magic, local_orderexpiretime, Orange);
                        if (local_orderticket < 0)
                        {
                            local_ordersenderror = TRUE;
                            Print("ERROR SELLSTOP : " + sub_dbl2strbrokerdigits(Bid - local_adjuststoplevel) + " SL:" + sub_dbl2strbrokerdigits(Ask - local_adjuststoplevel + local_scalpsize) + " TP:" + sub_dbl2strbrokerdigits(local_g - local_adjuststoplevel - local_scalpsize));
                            execution = 0;
                        }
                        else
                        {
                            execution = GetTickCount() - execution;
                            PlaySound("news.wav");
                            Print("SELLSTOP : " + sub_dbl2strbrokerdigits(Bid - local_adjuststoplevel) + " SL:" + sub_dbl2strbrokerdigits(Ask - local_adjuststoplevel + local_scalpsize) + " TP:" + sub_dbl2strbrokerdigits(local_g - local_adjuststoplevel - local_scalpsize));
                        }
                    }
                    else
                    {
                        if (local_ihigh - Bid < 0.0)
                        {
                            local_orderticket = OrderSend(local_pair, OP_SELL, minmaxlot, Bid, slippage, 0, 0, OrderCmt, Magic, local_orderexpiretime, Orange);
                            if (local_orderticket < 0)
                            {
                                local_ordersenderror = TRUE;
                                Print("ERROR SELL Bid:" + sub_dbl2strbrokerdigits(Bid) + " SL:" + sub_dbl2strbrokerdigits(Ask + local_scalpsize) + " TP:" + sub_dbl2strbrokerdigits(local_g - local_scalpsize));
                                execution = 0;
                            }
                            else
                            {
                                while (true)
                                {
                                    local_wasordermodified = OrderModify(local_orderticket, 0, sub_normalizebrokerdigits(Ask + local_scalpsize), sub_normalizebrokerdigits(local_g - local_scalpsize), local_orderexpiretime, Orange);
                                    break;
                                }
                                execution = GetTickCount() - execution;
                                PlaySound("news.wav");
                                Print("SELL Bid:" + sub_dbl2strbrokerdigits(Bid) + " SL:" + sub_dbl2strbrokerdigits(Ask + local_scalpsize) + " TP:" + sub_dbl2strbrokerdigits(local_g - local_scalpsize));
                            }
                        }
                    }
                }
            }
        }

        if (globalerror >= 0)
            Comment("Robot is initializing...");
        else
        {
            if (globalerror == -2)
                Comment("ERROR -- Instrument " + local_pair + " prices should have " + brokerdigits + " fraction digits on broker account");
            else
            {
                local_textstring = TimeToStr(TimeCurrent()) + " Tick: " + sub_adjust00instring(tickcounter);
                if (Show_Debug || Verbose)
                {
                    local_textstring = local_textstring + "\n*** DEBUG MODE *** \nVolatility: " + sub_dbl2strbrokerdigits(local_volatility) + ", VolatilityLimit: " + sub_dbl2strbrokerdigits(VolatilityLimit) + ", VolatilityPercentage: " + sub_dbl2strbrokerdigits(local_volatilitypercentage);
                    local_textstring = local_textstring + "\nPriceDirection: " + StringSubstr("BUY NULLSELL", 5 * local_pricedirection, 4) + ", ImaHigh: " + sub_dbl2strbrokerdigits(local_imahigh) + ", ImaLow: " + sub_dbl2strbrokerdigits(local_imalow) + ", BBandUpper: " + sub_dbl2strbrokerdigits(local_ibandsupper);
                    local_textstring = local_textstring + ", BBandLower: " + sub_dbl2strbrokerdigits(local_ibandslower) + ", Expire: " + TimeToStr(local_orderexpiretime, TIME_MINUTES) + ", NnumOrders: " + local_counter1;
                    local_textstring = local_textstring + "\nTrailingLimit: " + sub_dbl2strbrokerdigits(local_adjuststoplevel) + ", TrailingDist: " + sub_dbl2strbrokerdigits(local_trailingdistance) + "; TrailingStart: " + sub_dbl2strbrokerdigits(local_c) + ", UseStopOrders: " + local_usestoporders;
                }
                local_textstring = local_textstring + "\nBid: " + sub_dbl2strbrokerdigits(Bid) + ", Ask: " + sub_dbl2strbrokerdigits(Ask) + ", AvgSpread: " + sub_dbl2strbrokerdigits(local_avgspread) + ", Commission: " + sub_dbl2strbrokerdigits(local_commissionpips) + ", RealAvgSpread: " + sub_dbl2strbrokerdigits(local_realavgspread) + ", Lots: " + sub_dbl2strparb(minmaxlot, local_lotstep) + ", Execution: " + execution + " ms";
                if (sub_normalizebrokerdigits(local_realavgspread) > sub_normalizebrokerdigits(MaxSpread * pipette))
                {
                    local_textstring = local_textstring + "\n" + "The current spread (" + sub_dbl2strbrokerdigits(local_realavgspread) +") is higher than what has been set as MaxSpread (" + sub_dbl2strbrokerdigits(MaxSpread * pipette) + ") so no trading is allowed right now on this currency pair!";
                }
                Comment(local_textstring);
                if (local_counter1 != 0 || local_pricedirection != 0 || Verbose)
                    sub_printformattedstring(local_textstring);
            }
        } // end else
    }   // end for
} // end sub

void sub_moveandfillarrays (double& par_reference_a[30], double& par_reference_b[30], int& par_reference_c[30], double par_d)
{
    int local_counter;

   if (par_reference_c[0] == 0 || MathAbs (Bid - par_reference_a[0]) >= par_d * pipette)
    {
      for (local_counter = 29; local_counter > 0; local_counter--)
        {
         par_reference_a[local_counter] = par_reference_a[local_counter - 1];
         par_reference_b[local_counter] = par_reference_b[local_counter - 1];
         par_reference_c[local_counter] = par_reference_c[local_counter - 1];
      }
      par_reference_a[0] = Bid;
      par_reference_b[0] = Ask;
      par_reference_c[0] = GetTickCount();
   }
}

string sub_dbl2strbrokerdigits(double par_a)
{
   return (DoubleToStr(par_a, brokerdigits));
}

string sub_dbl2strparb(double par_a, int par_b)
{
   return (DoubleToStr(par_a, par_b));
}

double sub_normalizebrokerdigits(double par_a)
{
   return (NormalizeDouble(par_a, brokerdigits));
}

string sub_adjust00instring(int par_a)
{
   if (par_a < 10)
        return ("00" + par_a);
   if (par_a < 100)
        return ("0" + par_a);
   return ("" + par_a);
}

double sub_logarithm(double par_a, double par_b)
{
   return (MathLog(par_b) / MathLog(par_a));
}

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

void sub_preparecurrencypairs()
{
   string local_list;
   string local_pair;

    int local_counter1;
    int local_counter2;
   int local_position;

    double local_price;

    // Loop through all 27 possible currency pairs to pick out the ones that the broker offers
    paircount = 0;
   for (local_counter1 = 0; local_counter1 != paircount; local_counter1++)
    {
      local_pair = allpairs[local_counter1];
        local_price = MarketInfo(local_pair + Suffix, MODE_ASK);
      if (local_price != 0)     //  Check if broker support this pair
        {
         paircount++;
         ArrayResize(tradablepairs, paircount);
         tradablepairs[paircount - 1] = local_pair;
      }
        else
           Print ("The broker does not support ", local_pair);
    }

}
