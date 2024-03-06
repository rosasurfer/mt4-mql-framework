/**
 * DDL Monitor
 *
 * This EA's purpose is to protect the trading account and enforce adherence to a daily loss/drawdown limit (DDL). It monitors
 * open positions and PnL of all symbols (not only the symbol where the EA is attached).
 *
 * Positions of symbols without trade permission and positions opened outside the permitted time range are immediately closed.
 *
 * Permitted positions are monitored until a predefined drawdown limit is reached. Once the DDL is triggered the EA closes all
 * open positions and deletes all pending orders, and further trading is prohibited until the end of the day.
 *
 * The EA should run in a separate terminal connected 24/7 to the trade server. For best operation it's recommended to setup
 * a hosted environment (VM or dedicated server).
 *
 *
 * Input parameters:
 * -----------------
 * • PermittedSymbols:   Comma-separated list of symbols allowed to trade ("*" allows all available symbols).
 * • PermittedTimeRange: Time range when trading is allowed. Format: "00:00-23:59" in server time (empty: no limitation).
 * • DrawdownLimit:      Either an absolute money amount or a percentage value describing the drawdown limit of an open position.
 * • IgnoreSpread:       Whether to ignore the spread of floating positions when calculating PnL. Enabling this setting
 *                       prevents DDL triggering by spread widening/spikes.
 */
#include <stddefines.mqh>
int   __InitFlags[] = {INIT_TIMEZONE, INIT_BUFFERED_LOG, INIT_NO_EXTERNAL_REPORTING};
int __DeinitFlags[];
int __virtualTicks = 800;                             // milliseconds (must be short as the EA watches all symbols)

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern string PermittedSymbols   = "";                // symbols allowed to trade ("*": all symbols)
extern string PermittedTimeRange = "";                // time range trading is allowed (empty: no limitation)
extern string DrawdownLimit      = "200.00 | 5%*";    // absolute money amount or percentage drawdown limit
extern bool   IgnoreSpread       = true;              // whether to ignore the spread of floating positions

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/expert.mqh>
#include <stdfunctions.mqh>
#include <rsfLib.mqh>
#include <functions/ComputeFloatingPnL.mqh>
#include <functions/ParseDateTime.mqh>
#include <functions/ParseTimeRange.mqh>
#include <functions/SortClosedTickets.mqh>

double   prevEquity;                                  // equity value at the previous tick
bool     isPctLimit;                                  // whether a percent limit is configured
double   absLimit;                                    // configured absolute drawdown limit
double   pctLimit;                                    // configured percentage drawdown limit
datetime lastLiquidationTime;

datetime permittedFrom = -1;
datetime permittedTo   = -1;
bool     permitAllSymbols;
string   permittedSymbols[];
string   watchedSymbols  [];
double   watchedPositions[][5];

#define I_START_TIME       0                          // indexes of watchedPositions[]
#define I_START_EQUITY     1                          //
#define I_DRAWDOWN_LIMIT   2                          //
#define I_OPEN_PROFIT      3                          //
#define I_HISTORY          4                          //


/**
 * Initialization.
 *
 * @return int - error status
 */
int onInit() {
   // validate inputs
   // PermittedSymbols
   string sValue = StrTrim(PermittedSymbols), sValues[];
   permitAllSymbols = (sValue == "*");
   if (!permitAllSymbols) {
      int size = Explode(PermittedSymbols, ",", sValues, NULL);
      for (int i=0; i < size; i++) {
         sValue = StrTrim(sValues[i]);
         if (StringLen(sValue) > MAX_SYMBOL_LENGTH)                   return(catch("onInit(1)  invalid parameter PermittedSymbols: "+ DoubleQuoteStr(PermittedSymbols) +" (max symbol length = "+ MAX_SYMBOL_LENGTH +")", ERR_INVALID_PARAMETER));
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
   // get open positions
   string openSymbols[];
   double openProfits[];
   if (!ComputeFloatingPnLs(openSymbols, openProfits, IgnoreSpread)) return(last_error);

   // calculate current equity
   double equity = AccountBalance();
   int openSize = ArraySize(openSymbols);
   for (int i=0; i < openSize; i++) {
      equity += openProfits[i];
   }

   // synchronize watched positions
   int watchedSize = ArraySize(watchedSymbols);
   for (i=0; i < watchedSize; i++) {
      int n = SearchStringArray(openSymbols, watchedSymbols[i]);
      if (n == -1) {
         // position closed, remove it from watchlist
         logInfo("onTick(1)  "+ watchedSymbols[i] +" position closed");
         if (watchedSize > i+1) {
            int dim2 = ArrayRange(watchedPositions, 1);
            ArrayCopy(watchedSymbols,   watchedSymbols,   i,       i+1);
            ArrayCopy(watchedPositions, watchedPositions, i*dim2, (i+1)*dim2);
         }
         watchedSize--;
         ArrayResize(watchedSymbols,   watchedSize);
         ArrayResize(watchedPositions, watchedSize);
         i--;
      }
      else {
         // update watched position and remove processed open position
         watchedPositions[i][I_OPEN_PROFIT] = openProfits[n];
         watchedPositions[i][I_HISTORY    ] = CalculateHistory(watchedSymbols[i], watchedPositions[i][I_START_TIME]); if (!watchedPositions[i][I_HISTORY] && last_error) return(last_error);

         if (openSize > n+1) {
            ArrayCopy(openSymbols, openSymbols, n, n+1);
            ArrayCopy(openProfits, openProfits, n, n+1);
         }
         openSize--;
         ArrayResize(openSymbols, openSize);
         ArrayResize(openProfits, openSize);
      }
   }

   // liquidate new positions after a previous liquidation at the same day
   if (openSize > 0) {
      datetime today = TimeFXT();
      today -= (today % DAY);
      datetime lastLiquidation = lastLiquidationTime - lastLiquidationTime % DAY;
      if (lastLiquidation == today) {
         logWarn("onTick(2)  liquidating all new positions (auto-liquidation until end of day)");
         ArrayResize(watchedSymbols, 0);
         ArrayResize(watchedPositions, 0);
         CloseOpenOrders();
         return(catch("onTick(3)"));
      }
   }

   // process new positions
   for (i=0; prevEquity && i < openSize; i++) {
      // close non-permitted positions
      if (!permitAllSymbols) {
         if (SearchStringArrayI(permittedSymbols, openSymbols[i]) == -1) {
            logWarn("onTick(4)  closing non-permitted "+ openSymbols[i] +" position");
            CloseOpenOrders(openSymbols[i]);
            continue;
         }
      }
      int now = Tick.time % DAY;
      if (permittedFrom > -1) {
         if (now < permittedFrom*MINUTES) {
            logWarn("onTick(5)  closing non-permitted "+ openSymbols[i] +" position");
            CloseOpenOrders(openSymbols[i]);
            continue;
         }
      }
      if (permittedTo > -1) {
         if (now > permittedTo*MINUTES) {
            logWarn("onTick(6)  closing non-permitted "+ openSymbols[i] +" position");
            CloseOpenOrders(openSymbols[i]);
            continue;
         }
      }

      // add new position to watchlist
      ArrayResize(watchedSymbols,   watchedSize+1);
      ArrayResize(watchedPositions, watchedSize+1);
      watchedSymbols  [watchedSize]                   = openSymbols[i];
      watchedPositions[watchedSize][I_START_TIME    ] = GetPositionStartTime(openSymbols[i]);
      watchedPositions[watchedSize][I_START_EQUITY  ] = prevEquity;
      watchedPositions[watchedSize][I_DRAWDOWN_LIMIT] = ifDouble(isPctLimit, NormalizeDouble(prevEquity * pctLimit/100, 2), absLimit);
      watchedPositions[watchedSize][I_OPEN_PROFIT   ] = openProfits[i];
      watchedPositions[watchedSize][I_HISTORY       ] = CalculateHistory(watchedSymbols[watchedSize], watchedPositions[watchedSize][I_START_TIME]); if (!watchedPositions[watchedSize][I_HISTORY] && last_error) return(last_error);
      logInfo("onTick(7)  watching "+ watchedSymbols[watchedSize] +" position, ddl="+ DoubleToStr(watchedPositions[watchedSize][I_DRAWDOWN_LIMIT], 2));
      watchedSize++;
   }
   prevEquity = equity;

   // monitor drawdown limit
   for (i=0; i < watchedSize; i++) {
      double openProfit = watchedPositions[i][I_OPEN_PROFIT   ];
      double history    = watchedPositions[i][I_HISTORY       ];
      double ddl        = watchedPositions[i][I_DRAWDOWN_LIMIT];

      if (openProfit+history < ddl) {
         lastLiquidationTime = TimeFXT();
         logWarn("onTick(8)  "+ watchedSymbols[i] +": drawdown limit of "+ DrawdownLimit +" reached, liquidating positions...");
         ArrayResize(watchedSymbols, 0);
         ArrayResize(watchedPositions, 0);
         CloseOpenOrders();
         break;
      }
   }
   return(catch("onTick(9)"));
}


/**
 * Get the time of the oldest open position of the specified symbol.
 *
 * @param string symbol - order symbol
 *
 * @return datetime - order time or NULL in case of errors
 */
datetime GetPositionStartTime(string symbol) {
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
   return(!catch("GetPositionStartTime(1)  no open "+ symbol +" position found", ERR_RUNTIME_ERROR));
}


/**
 * Calculate historic PnL for the specified symbol and start time.
 *
 * @param string   symbol - trade symbol
 * @param datetime from   - history start time
 *
 * @return double - historic PnL or NULL in case of errors (check last_error)
 */
double CalculateHistory(string symbol, datetime from) {
   if (from <= NULL) return(!catch("CalculateHistory(1)  invalid parameter from: "+ from, ERR_INVALID_PARAMETER));

   static int    lastOrders = -1;
   static double lastProfit = 0;

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
   SortClosedTickets(sortKeys);

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
      if (!SelectTicket(sortKeys[i][2], "CalculateHistory(2)")) return(NULL);
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
   for (i=0; i < orders; i++) {
      if (!hst.tickets[i]) continue;                                 // skip discarded tickets

      if (EQ(hst.lotSizes[i], 0)) {                                  // lotSize = 0: hedging order
         // TODO: check behaviour if OrderComment() is a custom value
         if (!StrStartsWithI(hst.comments[i], "close hedge by #")) {
            return(!catch("CalculateHistory(3)  #"+ hst.tickets[i] +" - unknown comment for assumed hedging position "+ DoubleQuoteStr(hst.comments[i]), ERR_RUNTIME_ERROR));
         }

         // search counterpart ticket
         int ticket = StrToInteger(StringSubstr(hst.comments[i], 16));
         for (n=0; n < orders; n++) {
            if (hst.tickets[n] == ticket) break;
         }
         if (n == orders) return(!catch("CalculateHistory(4)  cannot find counterpart ticket for hedging position #"+ hst.tickets[i] +" "+ DoubleQuoteStr(hst.comments[i]), ERR_RUNTIME_ERROR));
         if (i == n     ) return(!catch("CalculateHistory(5)  both hedged and hedging position have the same ticket #"+ hst.tickets[i] +" "+ DoubleQuoteStr(hst.comments[i]), ERR_RUNTIME_ERROR));

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
 * Close open positions and pending orders.
 *
 * @param string symbol [optional] - symbol to close (default: all symbols)
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
