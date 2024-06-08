/**
 * Account Guard
 *
 * The EA monitors orders and positions of all symbols and enforces defined trading rules.
 *
 * Orders/positions of symbols without trade permission or outside of the permitted time range are immediately closed.
 *
 * Permitted positions are monitored until the specified drawdown limit is reached. If reached the EA closes all open positions
 * and pending orders. Further trading is prohibited until the end of the day. New orders/positions are immediately closed.
 *
 *
 * Input parameters:
 * -----------------
 * • PermittedSymbols:   Comma-separated list of symbols permitted to trade ("*" permits all available symbols).
 * • PermittedTimeRange: Time range when trading is permitted, format: "00:00-23:59" server time (empty: no restriction).
 * • DrawdownLimit:      Either an absolute money amount or a percentage value describing the drawdown limit of an open position.
 * • IgnoreSpread:       Whether to ignore the spread of floating positions when calculating PnL. Enabling this setting
 *                       prevents DDL triggering by spread widening.
 *
 *
 * TODO:
 *  - XAU: prohibit counter-trend trading on sudden volatility
 *     volatility: Donchian channel width
 *     trend: ALMA(10) crosses LWMA(55) tunnel (L'mas signal)
 *
 *  - XAU: prohibit trading between 15:00-17:30
 *  - XAU: prohibit trading from 30 minutes before until 60 minutes after major news
 *
 *  - display runtime status on screen
 *  - custom logfile per instance
 *  - log trade details to logfile (manual logging is too time consuming)
 *  - ComputeClosedProfit() freezes the terminal if the full history is visible => move to Expander
 *  - define major news per week and a time window around it where trading is prohibited
 *  - visual chart feedback when active (red dot when inactive, green dot when active)
 *  - enable trading if disabled
 *  - ERR_NOT_ENOUGH_MONEY when closing a basket
 *  - bug when a hedged position is closed elsewhere (sees a different position and may trigger DDL => error)
 *     local
 *      18:39:38.120  order buy market 0.02 BTCUSD sl: 0.00 tp: 0.00                                 (manual)
 *      18:39:38.415  order was opened : #561128139 buy 0.02 BTCUSD at 70323.78 sl: 0.00 tp: 0.00
 *      ...
 *      18:39:49.825  Script CloseOrders BTCUSD,M5: loaded successfully
 *      18:39:57.130  rsfStdlib: order #561127602 was closed by order #561128139
 *   -> 18:39:57.130  remainder of order #561127602 was opened : #561128149 buy 0.01 BTCUSD at 70323.78 sl: 0.00 tp: 0.00  => triggers remote error
 *     remote
 *   -> 18:39:57.252  WARN   Account Guard::onTick(8)  BTCUSD: drawdown limit of -23.8% reached, liquidating positions...
 *      18:39:57.268         Account Guard::rsfStdlib::OrdersCloseSameSymbol(16)  closing 2 BTCUSD positions {#561127605:-0.01, #561128149:+0.01}
 *      18:39:57.268         Account Guard::rsfStdlib::OrdersHedge(13)  2 BTCUSD positions {#561127605:-0.01, #561128149:+0.01} are already flat
 *      18:39:57.268         Account Guard::rsfStdlib::OrdersCloseHedged(15)  closing 2 hedged BTCUSD positions {#561127605:-0.01, #561128149:+0.01}
 *      18:39:57.487  FATAL  Account Guard::rsfStdlib::OrderCloseByEx(33)  error while trying to close #561127605 by #561128149 after 0.219 s  [ERR_INVALID_TRADE_PARAMETERS]
 */
#include <rsf/stddefines.mqh>
int   __InitFlags[] = {INIT_TIMEZONE, INIT_BUFFERED_LOG};
int __DeinitFlags[];
int __virtualTicks = 800;                             // milliseconds (must be short as the EA monitors all symbols)

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern string PermittedSymbols   = "";                // symbols allowed to trade ("*": all symbols)
extern string PermittedTimeRange = "";                // time range trading is allowed (empty: no time restriction)
extern string DrawdownLimit      = "200.00 | 5%*";    // absolute money amount or percentage drawdown limit
extern bool   IgnoreSpread       = true;              // whether to ignore the spread of floating positions

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <rsf/core/expert.mqh>
#include <rsf/stdfunctions.mqh>
#include <rsf/stdlib.mqh>
#include <rsf/functions/ComputeFloatingProfit.mqh>
#include <rsf/functions/ParseDateTime.mqh>
#include <rsf/functions/ParseTimeRange.mqh>
#include <rsf/functions/SortClosedTickets.mqh>

double   prevEquity;                                  // equity value at the previous tick
double   absLimit;                                    // configured absolute drawdown limit
double   pctLimit;                                    // configured percentage drawdown limit
bool     isPctLimit;                                  // whether a percent limit is configured
datetime lastLiquidationTime;

bool     allSymbolsPermitted;
string   permittedSymbols[];
datetime permittedFrom = -1;
datetime permittedTo   = -1;

string   trackedSymbols[];                            // currently tracked open positions
double   trackedData[][5];

#define I_OPEN_TIME        0                          // indexes of trackedData[]
#define I_OPEN_EQUITY      1                          //
#define I_OPEN_PROFIT      2                          //
#define I_CLOSED_PROFIT    3                          //
#define I_DRAWDOWN_LIMIT   4                          //


/**
 * Initialization.
 *
 * @return int - error status
 */
int onInit() {
   // validate inputs
   // PermittedSymbols
   string sValue = StrTrim(PermittedSymbols), sValues[];
   allSymbolsPermitted = (sValue == "*");
   if (!allSymbolsPermitted) {
      int size = Explode(PermittedSymbols, ",", sValues, NULL);
      for (int i=0; i < size; i++) {
         sValue = StrTrim(sValues[i]);
         if (StringLen(sValue) > MAX_SYMBOL_LENGTH)                   return(catch("onInit(1)  invalid symbol in parameter PermittedSymbols: "+ DoubleQuoteStr(sValue) +" (max symbol length: "+ MAX_SYMBOL_LENGTH +")", ERR_INVALID_PARAMETER));
         if (SearchStringArrayI(permittedSymbols, sValue) == -1) {
            ArrayPushString(permittedSymbols, sValue);
         }
      }
   }

   // PermittedTimeRange: 09:00-10:00
   permittedFrom = -1;
   permittedTo   = -1;
   sValue = StrTrim(PermittedTimeRange);
   if (StringLen(sValue) > 0) {
      int iNull;
      if (!ParseTimeRange(sValue, permittedFrom, permittedTo, iNull)) return(catch("onInit(2)  invalid input parameter PermittedTimeRange: \""+ PermittedTimeRange +"\"", ERR_INVALID_INPUT_PARAMETER));
      PermittedTimeRange = sValue;
   }

   // DrawdownLimit
   if (Explode(DrawdownLimit, "*", sValues, 2) > 1) {
      size = Explode(sValues[0], "|", sValues, NULL);
      sValue = StrTrim(sValues[size-1]);
   }
   else {
      sValue = StrTrim(DrawdownLimit);
   }
   isPctLimit = StrEndsWith(sValue, "%");
   if (isPctLimit) sValue = StrTrimRight(StrLeft(sValue, -1));
   if (!StrIsNumeric(sValue))                                         return(catch("onInit(3)  invalid parameter DrawdownLimit: "+ DoubleQuoteStr(DrawdownLimit), ERR_INVALID_PARAMETER));
   double dValue = NormalizeDouble(-MathAbs(StrToDouble(sValue)), 2);
   if (isPctLimit) {
      pctLimit = dValue;
      absLimit = NULL;
      if (!pctLimit)                                                  return(catch("onInit(4)  illegal parameter DrawdownLimit: "+ DoubleQuoteStr(DrawdownLimit) +" (must be != 0)", ERR_INVALID_PARAMETER));
      if (pctLimit <= -100)                                           return(catch("onInit(5)  illegal parameter DrawdownLimit: "+ DoubleQuoteStr(DrawdownLimit) +" (must be > -100)", ERR_INVALID_PARAMETER));
      DrawdownLimit = NumberToStr(pctLimit, ".+") +"%";
   }
   else {
      pctLimit = NULL;
      absLimit = dValue;
      if (!absLimit)                                                  return(catch("onInit(6)  illegal parameter DrawdownLimit: "+ DoubleQuoteStr(DrawdownLimit) +" (must be != 0)", ERR_INVALID_PARAMETER));
      DrawdownLimit = DoubleToStr(absLimit, 2);
   }
   return(catch("onInit(7)"));
}


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   // get open orders and floating profits
   string openSymbols[];
   double openProfits[];
   bool includePendings = true;
   if (!ComputeFloatingProfits(openSymbols, openProfits, includePendings, IgnoreSpread)) return(last_error);

   // calculate current equity value
   double equity = AccountBalance();
   int openSize = ArraySize(openSymbols);
   for (int i=0; i < openSize; i++) {
      equity += openProfits[i];
   }

   // synchronize tracked open orders
   int trackedSize = ArraySize(trackedSymbols);
   for (i=0; i < trackedSize; i++) {
      int n = SearchStringArray(openSymbols, trackedSymbols[i]);
      if (n == -1) {
         // tracked symbol has no open orders anymore, remove it from tracker
         logInfo("onTick(1)  "+ trackedSymbols[i] + ifString(trackedData[i][I_OPEN_TIME], " position closed", " orders deleted"));
         if (trackedSize > i+1) {
            int dim2 = ArrayRange(trackedData, 1);
            ArrayCopy(trackedSymbols, trackedSymbols, i,       i+1);
            ArrayCopy(trackedData,    trackedData,    i*dim2, (i+1)*dim2);
         }
         trackedSize--;
         ArrayResize(trackedSymbols, trackedSize);
         ArrayResize(trackedData,    trackedSize);
         i--;
      }
      else {
         // update tracked order data
         bool isPendingOrder = IsEmptyValue(openProfits[n]);

         if (!isPendingOrder && trackedData[i][I_OPEN_TIME]) {
            // normal open position
            trackedData[i][I_OPEN_PROFIT  ] = openProfits[n];
            trackedData[i][I_CLOSED_PROFIT] = ComputeClosedProfit(trackedSymbols[i], trackedData[i][I_OPEN_TIME]);
         }
         else if (!isPendingOrder || trackedData[i][I_OPEN_TIME]) {
            if (!trackedData[i][I_OPEN_TIME]) {
               // pendings executed, position opened
               trackedData[i][I_OPEN_TIME     ] = GetPositionOpenTime(trackedSymbols[i]);
               trackedData[i][I_OPEN_EQUITY   ] = prevEquity;     // equity value of the previous tick
               trackedData[i][I_OPEN_PROFIT   ] = openProfits[n];
               trackedData[i][I_CLOSED_PROFIT ] = ComputeClosedProfit(trackedSymbols[i], trackedData[i][I_OPEN_TIME]);
               trackedData[i][I_DRAWDOWN_LIMIT] = ifDouble(isPctLimit, NormalizeDouble(prevEquity * pctLimit/100, 2), absLimit);
               logInfo("onTick(2)  watching "+ trackedSymbols[i] +" position, ddl="+ DoubleToStr(trackedData[i][I_DRAWDOWN_LIMIT], 2));
            }
            else {
               // position closed, pendings remaining
               trackedData[i][I_OPEN_TIME     ] = NULL;
               trackedData[i][I_OPEN_EQUITY   ] = NULL;
               trackedData[i][I_OPEN_PROFIT   ] = NULL;
               trackedData[i][I_CLOSED_PROFIT ] = NULL;
               trackedData[i][I_DRAWDOWN_LIMIT] = NULL;
               logInfo("onTick(3)  "+ trackedSymbols[i] + " position closed");
            }
         }
         if (last_error != NULL) return(last_error);

         // remove symbol from open[Symbols|Profits]
         if (openSize > n+1) {
            ArrayCopy(openSymbols, openSymbols, n, n+1);
            ArrayCopy(openProfits, openProfits, n, n+1);
         }
         openSize--;
         ArrayResize(openSymbols, openSize);
         ArrayResize(openProfits, openSize);
      }
   }
   // on openSize > 0: all remaining open orders are new (unknown to the tracker)

   // close/delete new orders after a previous liquidation at the same day
   if (openSize > 0) {
      datetime today = TimeFXT();
      today -= (today % DAY);
      datetime lastLiquidation = lastLiquidationTime - lastLiquidationTime % DAY;
      if (lastLiquidation == today) {
         logWarn("onTick(4)  closing/deleting all new orders until end of day");
         ArrayResize(trackedSymbols, 0);
         ArrayResize(trackedData,    0);
         CloseOpenOrders();                                       // FIXME: closes all open tickets, not only new ones
         return(catch("onTick(5)"));
      }
   }

   // process new orders
   for (i=0; prevEquity && i < openSize; i++) {
      isPendingOrder = IsEmptyValue(openProfits[n]);
      string msg = ifString(isPendingOrder, "deleting", "closing") +" non-permitted "+ openSymbols[i] + ifString(isPendingOrder, " order", " position");

      // close/delete non-permitted orders
      if (!allSymbolsPermitted) {
         if (SearchStringArrayI(permittedSymbols, openSymbols[i]) == -1) {
            logWarn("onTick(6)  "+ msg);
            CloseOpenOrders(openSymbols[i]);
            continue;
         }
      }
      int now = Tick.time % DAY;
      if (permittedFrom > -1) {
         if (now < permittedFrom*MINUTES) {
            logWarn("onTick(7)  "+ msg);
            CloseOpenOrders(openSymbols[i]);
            continue;
         }
      }
      if (permittedTo > -1) {
         if (now > permittedTo*MINUTES) {
            logWarn("onTick(8)  "+ msg);
            CloseOpenOrders(openSymbols[i]);
            continue;
         }
      }

      // add new position to tracker
      ArrayResize(trackedSymbols, trackedSize+1);
      ArrayResize(trackedData,    trackedSize+1);
      trackedSymbols[trackedSize] = openSymbols[i];
      if (isPendingOrder) {
         trackedData[trackedSize][I_OPEN_TIME     ] = NULL;
         trackedData[trackedSize][I_OPEN_EQUITY   ] = NULL;
         trackedData[trackedSize][I_OPEN_PROFIT   ] = NULL;
         trackedData[trackedSize][I_CLOSED_PROFIT ] = NULL;
         trackedData[trackedSize][I_DRAWDOWN_LIMIT] = NULL;
      }
      else {
         trackedData[trackedSize][I_OPEN_TIME     ] = GetPositionOpenTime(openSymbols[i]);
         trackedData[trackedSize][I_OPEN_EQUITY   ] = prevEquity;       // equity value of the previous tick
         trackedData[trackedSize][I_OPEN_PROFIT   ] = openProfits[i];
         trackedData[trackedSize][I_CLOSED_PROFIT ] = ComputeClosedProfit(trackedSymbols[trackedSize], trackedData[trackedSize][I_OPEN_TIME]);
         trackedData[trackedSize][I_DRAWDOWN_LIMIT] = ifDouble(isPctLimit, NormalizeDouble(prevEquity * pctLimit/100, 2), absLimit);
         logInfo("onTick(9)  watching "+ trackedSymbols[trackedSize] +" position, ddl="+ DoubleToStr(trackedData[trackedSize][I_DRAWDOWN_LIMIT], 2));
      }
      if (last_error != NULL) return(last_error);
      trackedSize++;
   }

   // monitor drawdown limit
   for (i=0; i < trackedSize; i++) {
      if (!trackedData[i][I_OPEN_TIME]) continue;

      double openProfit   = trackedData[i][I_OPEN_PROFIT   ];
      double closedProfit = trackedData[i][I_CLOSED_PROFIT ];
      double ddl          = trackedData[i][I_DRAWDOWN_LIMIT];

      if (openProfit+closedProfit < ddl) {
         lastLiquidationTime = TimeFXT();
         logWarn("onTick(10)  "+ trackedSymbols[i] +": drawdown limit of "+ DrawdownLimit +" reached, closing positions...");
         ArrayResize(trackedSymbols, 0);
         ArrayResize(trackedData,    0);
         CloseOpenOrders();                                       // FIXME: closes all open tickets, not only the one hitting the DDL
         break;
      }
   }

   prevEquity = equity;
   return(catch("onTick(11)"));
}


/**
 * Get the open time of the oldest open position for the specified symbol.
 *
 * @param string symbol - order symbol
 *
 * @return datetime - position open time or NULL in case of errors
 */
datetime GetPositionOpenTime(string symbol) {
   int orders = OrdersTotal();
   datetime time = INT_MAX;

   for (int n, i=0; i < orders; i++) {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) break;     // FALSE: an open order was closed/deleted in another thread
      if (OrderType() > OP_SELL)                       continue;
      if (OrderSymbol() != symbol)                     continue;
      time = MathMin(time, OrderOpenTime());
   }

   if (time < INT_MAX)
      return(time);
   return(!catch("GetPositionOpenTime(1)  no open "+ symbol +" position found", ERR_RUNTIME_ERROR));
}


/**
 * Compute the closed profit value for the specified symbol and start time.
 *
 * @param string   symbol - symbol
 * @param datetime from   - history start time
 *
 * @return double - closed profit value or NULL in case of errors (check last_error)
 */
double ComputeClosedProfit(string symbol, datetime from) {
   if (from <= NULL) return(!catch("ComputeClosedProfit(1)  invalid parameter from: "+ from, ERR_INVALID_PARAMETER));

   static int    lastOrders = -1;
   static double lastProfit = 0;                                     // FIXME: static profit is not separated by symbol

   int orders = OrdersHistoryTotal(), _orders=orders;
   if (orders == lastOrders) return(lastProfit);                     // PnL is only recalculated if history size changes

   // sort closed positions by {CloseTime, OpenTime, Ticket}
   int sortKeys[][3], n=0;
   ArrayResize(sortKeys, orders);

   for (int i=0; i < orders; i++) {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) break;       // FALSE: the visible history range was modified in another thread
      if (OrderType() > OP_SELL)                        continue;    // intentionally ignore dividends and rollover adjustments
      if (OrderSymbol() != symbol)                      continue;

      sortKeys[n][0] = OrderCloseTime();
      sortKeys[n][1] = OrderOpenTime();
      sortKeys[n][2] = OrderTicket();
      n++;
   }
   orders = n;
   ArrayResize(sortKeys, orders);
   SortClosedTickets(sortKeys);                                      // TODO: move to Expander (bad performance)

   // read tickets sorted
   int      hst.tickets    []; ArrayResize(hst.tickets,     orders);
   int      hst.types      []; ArrayResize(hst.types,       orders);
   double   hst.lotSizes   []; ArrayResize(hst.lotSizes,    orders);
   datetime hst.openTimes  []; ArrayResize(hst.openTimes,   orders);
   datetime hst.closeTimes []; ArrayResize(hst.closeTimes,  orders);
   double   hst.openPrices []; ArrayResize(hst.openPrices,  orders);
   double   hst.closePrices[]; ArrayResize(hst.closePrices, orders);
   double   hst.commissions[]; ArrayResize(hst.commissions, orders);
   double   hst.swaps      []; ArrayResize(hst.swaps,       orders);
   double   hst.profits    []; ArrayResize(hst.profits,     orders);
   string   hst.comments   []; ArrayResize(hst.comments,    orders);

   for (i=0; i < orders; i++) {
      if (!SelectTicket(sortKeys[i][2], "ComputeClosedProfit(2)")) return(NULL);
      hst.tickets    [i] = OrderTicket();
      hst.types      [i] = OrderType();
      hst.lotSizes   [i] = OrderLots();
      hst.openTimes  [i] = OrderOpenTime();
      hst.closeTimes [i] = OrderCloseTime();
      hst.openPrices [i] = OrderOpenPrice();
      hst.closePrices[i] = OrderClosePrice();
      hst.commissions[i] = OrderCommission();
      hst.swaps      [i] = OrderSwap();
      hst.profits    [i] = OrderProfit();
      hst.comments   [i] = OrderComment();
   }

   // adjust hedges: apply all data to the first ticket and discard the hedging ticket
   // TODO: the nested loop freezes the terminal if the full history is visible => move to Expander
   for (i=0; i < orders; i++) {
      if (!hst.tickets[i]) continue;                                 // skip discarded tickets

      if (hst.lotSizes[i] < 0.005) {                                 // lotSize = 0: hedging order
         // TODO: check behaviour if OrderComment() is a custom value
         if (!StrStartsWith(hst.comments[i], "close hedge by #")) {
            return(!catch("ComputeClosedProfit(3)  #"+ hst.tickets[i] +" - unknown comment for assumed hedging position "+ DoubleQuoteStr(hst.comments[i]), ERR_RUNTIME_ERROR));
         }

         // search counterpart ticket
         int ticket = StrToInteger(StringSubstr(hst.comments[i], 16));
         for (n=0; n < orders; n++) {
            if (hst.tickets[n] == ticket) break;
         }
         if (n == orders) return(!catch("ComputeClosedProfit(4)  cannot find counterpart ticket for hedging position #"+ hst.tickets[i] +" "+ DoubleQuoteStr(hst.comments[i]), ERR_RUNTIME_ERROR));
         if (i == n     ) return(!catch("ComputeClosedProfit(5)  both hedged and hedging position have the same ticket #"+ hst.tickets[i] +" "+ DoubleQuoteStr(hst.comments[i]), ERR_RUNTIME_ERROR));

         int first  = Min(i, n);
         int second = Max(i, n);

         // adjust ticket data
         if (i == first) {
            hst.lotSizes   [first] = hst.lotSizes   [second];        // store all transaction data in the first ticket
            hst.commissions[first] = hst.commissions[second];
            hst.swaps      [first] = hst.swaps      [second];
            hst.profits    [first] = hst.profits    [second];
         }
         hst.closeTimes [first] = hst.openTimes [second];
         hst.closePrices[first] = hst.openPrices[second];
         hst.tickets   [second] = NULL;                              // mark hedging ticket as discarded
      }
   }

   // calculate total PnL
   double profit = 0;
   n=0;
   for (i=0; i < orders; i++) {
      if (!hst.tickets[i])          continue;                        // skip discarded tickets
      if (hst.closeTimes[i] < from) continue;
      profit += hst.commissions[i] + hst.swaps[i] + hst.profits[i];
      n++;
   }
   profit = NormalizeDouble(profit, 2);

   lastOrders = _orders;
   lastProfit = profit;
   return(profit);
}


/**
 * Close open positions and delete pending orders.
 *
 * @param string symbol [optional] - symbol (default: all symbols)
 *
 * @return bool - success status
 */
bool CloseOpenOrders(string symbol = "") {
   int orders = OrdersTotal(), pendings[], positions[];
   ArrayResize(pendings, 0);
   ArrayResize(positions, 0);

   for (int i=0; i < orders; i++) {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) break;           // FALSE: an open order was closed/deleted in another thread
      if (OrderType() > OP_SELLSTOP)                   continue;
      if (symbol != "") {
         if (!StrCompareI(OrderSymbol(), symbol))      continue;
      }
      if (OrderType() > OP_SELL) ArrayPushInt(pendings, OrderTicket());
      else                       ArrayPushInt(positions, OrderTicket());
   }

   int oe[], oes[][ORDER_EXECUTION_intSize], oeFlags=NULL;

   if (ArraySize(positions) > 0) {
      if (!OrdersClose(positions, 1, CLR_NONE, oeFlags, oes)) return(false);
   }
   for (i=ArraySize(pendings)-1; i >= 0; i--) {
      if (!OrderDeleteEx(pendings[i], CLR_NONE, oeFlags, oe)) return(false);
   }
   return(!catch("CloseOpenOrders(1)"));
}


/**
 * Return a string representation of the input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("PermittedSymbols=",   DoubleQuoteStr(PermittedSymbols),   ";", NL,
                            "PermittedTimeRange=", DoubleQuoteStr(PermittedTimeRange), ";", NL,
                            "DrawdownLimit=",      DoubleQuoteStr(DrawdownLimit),      ";", NL,
                            "IgnoreSpread=",       BoolToStr(IgnoreSpread),            ";"));
}
