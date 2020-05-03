/**
 * EquityRecorder
 *
 * Records the current account's equity curve. The actual value is adjusted for duplicated trading costs (fees and spreads).
 */
#include <stddefines.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////


/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <rsfLibs.mqh>
#include <rsfHistory.mqh>

#property indicator_chart_window
#property indicator_buffers      0
#property indicator_color1       CLR_NONE

#define I_ACCOUNT                0                                   // index of the adjusted equity value
#define I_ACCOUNT_PLUS_ASSETS    1                                   // index of the adjusted equity value plus external assets

double currentEquity[2];                                             // current equity values
double prevEquity   [2];                                             // previous equity values
int    hHstSet      [2];                                             // HistorySet handles

string symbolSuffixes    [] = { ".EA"                           , ".EX"                                                 };
string symbolDescriptions[] = { "Account {AccountNumber} equity", "Account {AccountNumber} equity plus external assets" };


/**
 * Deinitialization
 *
 * @return int - error status
 */
int onDeinit() {
   int size = ArraySize(hHstSet);
   for (int i=0; i < size; i++) {
      if (hHstSet[i] != 0) {
         int tmp = hHstSet[i];
         hHstSet[i] = NULL;
         if (!HistorySet.Close(tmp)) return(ERR_RUNTIME_ERROR);
      }
   }
   return(catch("onDeinit(1)"));
}


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   // skip old ticks (e.g. during session break or weekend)
   bool isStale = (Tick.Time < GetServerTime()-2*MINUTES);
   if (isStale) return(last_error);

   if (!CollectAccountData()) return(last_error);
   if (!RecordAccountData())  return(last_error);

   return(last_error);
}


/**
 * Calculate current equity values.
 *
 * @return bool - success status
 */
bool CollectAccountData() {
   string symbols      []; ArrayResize(symbols,       0);            // symbols with open positions
   double symbolProfits[]; ArrayResize(symbolProfits, 0);            // each symbol's total PL

   // read open positions
   int orders = OrdersTotal();
   int    symbolsIdx []; ArrayResize(symbolsIdx,  orders);           // an order's symbol index in symbols[]
   int    tickets    []; ArrayResize(tickets,     orders);
   int    types      []; ArrayResize(types,       orders);
   double lots       []; ArrayResize(lots,        orders);
   double openPrices []; ArrayResize(openPrices,  orders);
   double commissions[]; ArrayResize(commissions, orders);
   double swaps      []; ArrayResize(swaps,       orders);
   double profits    []; ArrayResize(profits,     orders);

   for (int n, si, i=0; i < orders; i++) {                           // si => actual symbol index
      if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) break;
      if (OrderType() > OP_SELL) continue;
      if (!n) {
         si = ArrayPushString(symbols, OrderSymbol()) - 1;
      }
      else if (symbols[si] != OrderSymbol()) {
         si = SearchStringArray(symbols, OrderSymbol());
         if (si == -1)
            si = ArrayPushString(symbols, OrderSymbol()) - 1;
      }
      symbolsIdx [n] = si;
      tickets    [n] = OrderTicket();
      types      [n] = OrderType();
      lots       [n] = NormalizeDouble(OrderLots(), 2);
      openPrices [n] = OrderOpenPrice();
      commissions[n] = OrderCommission();
      swaps      [n] = OrderSwap();
      profits    [n] = OrderProfit();
      n++;
   }
   if (n < orders) {
      ArrayResize(symbolsIdx , n);
      ArrayResize(tickets,     n);
      ArrayResize(types,       n);
      ArrayResize(lots,        n);
      ArrayResize(openPrices,  n);
      ArrayResize(commissions, n);
      ArrayResize(swaps,       n);
      ArrayResize(profits,     n);
      orders = n;
   }

   // determine each symbol's PL
   int symbolsSize = ArraySize(symbols);
   ArrayResize(symbolProfits, symbolsSize);

   for (i=0; i < symbolsSize; i++) {
      symbolProfits[i] = CalculateProfit(symbols[i], i, symbolsIdx, tickets, types, lots, openPrices, commissions, swaps, profits);
      if (IsEmptyValue(symbolProfits[i]))
         return(false);
      symbolProfits[i] = NormalizeDouble(symbolProfits[i], 2);
   }

   // calculate resulting equity values
   double fullPL          = SumDoubles(symbolProfits);
   double externalAssets  = GetExternalAssets(ShortAccountCompany(), GetAccountNumber()); if (IsEmptyValue(externalAssets)) return(false);

   currentEquity[I_ACCOUNT            ] = NormalizeDouble(AccountBalance()         + fullPL,         2);
   currentEquity[I_ACCOUNT_PLUS_ASSETS] = NormalizeDouble(currentEquity[I_ACCOUNT] + externalAssets, 2);

   return(!catch("CollectAccountData(3)"));
}


/**
 * Calculate the total PL of a single symbol.
 *
 * @param  string symbol        - symbol
 * @param  int    index         - symbol index in symbolsIdx[]
 * @param  int    symbolsIdx []
 * @param  int    tickets    []
 * @param  int    types      []
 * @param  double lots       []
 * @param  double openPrices []
 * @param  double commissions[]
 * @param  double swaps      []
 * @param  double profits    []
 *
 * @return double - P/L-Value oder EMPTY_VALUE, falls ein Fehler auftrat
 */
double CalculateProfit(string symbol, int index, int symbolsIdx[], int &tickets[], int types[], double &lots[], double openPrices[], double &commissions[], double &swaps[], double &profits[]) {
   double longPosition, shortPosition, totalPosition, hedgedLots, remainingLong, remainingShort, factor, openPrice, closePrice, commission, swap, floatingProfit, fullProfit, hedgedProfit, vtmProfit, pipValue, pipDistance;
   int    ticketsSize = ArraySize(tickets);

   // resolve the symbol's total position: hedged volume (constant PL) + directional volume (variable PL)
   for (int i=0; i < ticketsSize; i++) {
      if (symbolsIdx[i] != index) continue;

      if (types[i] == OP_BUY) longPosition  += lots[i];                          // add-up total volume per market direction
      else                    shortPosition += lots[i];
   }
   longPosition  = NormalizeDouble(longPosition,  2);
   shortPosition = NormalizeDouble(shortPosition, 2);
   totalPosition = NormalizeDouble(longPosition-shortPosition, 2);

   int    digits     = MarketInfo(symbol, MODE_DIGITS);                          // TODO: digits may be erroneous
   int    pipDigits  = digits & (~1);
   double pipSize    = NormalizeDouble(1/MathPow(10, pipDigits), pipDigits);
   double spreadPips = MarketInfo(symbol, MODE_SPREAD)/MathPow(10, digits & 1);  // spread in pip

   // resolve the constant PL of a hedged volume
   if (longPosition && shortPosition) {
      hedgedLots     = MathMin(longPosition, shortPosition);
      remainingLong  = hedgedLots;
      remainingShort = hedgedLots;

      for (i=0; i < ticketsSize; i++) {
         if (symbolsIdx[i] != index) continue;
         if (!tickets[i])            continue;

         if (types[i] == OP_BUY) {
            if (!remainingLong) continue;
            if (remainingLong >= lots[i]) {
               // take-over all data and nullify ticket
               openPrice     = NormalizeDouble(openPrice + lots[i] * openPrices[i], 8);
               swap         += swaps      [i];
               commission   += commissions[i];
               remainingLong = NormalizeDouble(remainingLong - lots[i], 3);
               tickets[i]    = NULL;
            }
            else {
               // take-over full swap and reduce the ticket's commission, PL and lotsize
               factor        = remainingLong/lots[i];
               openPrice     = NormalizeDouble(openPrice + remainingLong * openPrices[i], 8);
               swap         += swaps[i];                swaps      [i]  = 0;
               commission   += factor * commissions[i]; commissions[i] -= factor * commissions[i];
                                                        profits    [i] -= factor * profits    [i];
                                                        lots       [i]  = NormalizeDouble(lots[i]-remainingLong, 3);
               remainingLong = 0;
            }
         }
         else /*types[i] == OP_SELL*/ {
            if (!remainingShort) continue;
            if (remainingShort >= lots[i]) {
               // take-over all data and nullify ticket
               closePrice     = NormalizeDouble(closePrice + lots[i] * openPrices[i], 8);
               swap          += swaps      [i];
               //commission  += commissions[i];                                        // take-over commission only for the long leg
               remainingShort = NormalizeDouble(remainingShort - lots[i], 3);
               tickets[i]     = NULL;
            }
            else {
               // take-over full swap and reduce the ticket's commission, PL and lotsize
               factor         = remainingShort/lots[i];
               closePrice     = NormalizeDouble(closePrice + remainingShort * openPrices[i], 8);
               swap          += swaps[i]; swaps      [i]  = 0;
                                          commissions[i] -= factor * commissions[i];   // take-over commission only for the long leg
                                          profits    [i] -= factor * profits    [i];
                                          lots       [i]  = NormalizeDouble(lots[i]-remainingShort, 3);
               remainingShort = 0;
            }
         }
      }
      if (remainingLong  != 0) return(_EMPTY_VALUE(catch("CalculateProfit(1)  illegal remaining long position = "+ NumberToStr(remainingLong, ".+") +" of hedged position = "+ NumberToStr(hedgedLots, ".+"), ERR_RUNTIME_ERROR)));
      if (remainingShort != 0) return(_EMPTY_VALUE(catch("CalculateProfit(2)  illegal remaining short position = "+ NumberToStr(remainingShort, ".+") +" of hedged position = "+ NumberToStr(hedgedLots, ".+"), ERR_RUNTIME_ERROR)));

      // calculate BE distance and the resulting PL
      pipValue     = PipValueEx(symbol, hedgedLots); if (!pipValue) return(EMPTY_VALUE);
      pipDistance  = (closePrice-openPrice)/hedgedLots/pipSize + (commission+swap)/pipValue;
      hedgedProfit = pipDistance * pipValue;

      // without directional volume return the PL of the hedged volume only
      if (!totalPosition) {
         fullProfit = NormalizeDouble(hedgedProfit, 2);
         return(ifDouble(!catch("CalculateProfit(3)"), fullProfit, EMPTY_VALUE));
      }
   }

   // calculate PL of a long position (if any)
   if (totalPosition > 0) {
      swap           = 0;
      commission     = 0;
      floatingProfit = 0;

      for (i=0; i < ticketsSize; i++) {
         if (symbolsIdx[i] != index) continue;
         if (!tickets[i])            continue;

         if (types[i] == OP_BUY) {
            swap           += swaps      [i];
            commission     += commissions[i];
            floatingProfit += profits    [i];
            tickets[i]      = NULL;
         }
      }
      // add the PL value of half of the spread
      pipDistance = spreadPips/2;
      pipValue    = PipValueEx(symbol, totalPosition); if (!pipValue) return(EMPTY_VALUE);
      vtmProfit   = pipDistance * pipValue;
      fullProfit  = NormalizeDouble(hedgedProfit + floatingProfit + vtmProfit + swap + commission, 2);
      return(ifDouble(!catch("CalculateProfit(4)"), fullProfit, EMPTY_VALUE));
   }

   // calculate PL of a short position (if any)
   if (totalPosition < 0) {
      swap           = 0;
      commission     = 0;
      floatingProfit = 0;

      for (i=0; i < ticketsSize; i++) {
         if (symbolsIdx[i] != index) continue;
         if (!tickets[i])            continue;

         if (types[i] == OP_SELL) {
            swap           += swaps      [i];
            commission     += commissions[i];
            floatingProfit += profits    [i];
            tickets[i]      = NULL;
         }
      }
      // add the PL value of half of the spread
      pipDistance = spreadPips/2;
      pipValue    = PipValueEx(symbol, totalPosition); if (!pipValue) return(EMPTY_VALUE);
      vtmProfit   = pipDistance * pipValue;
      fullProfit  = NormalizeDouble(hedgedProfit + floatingProfit + vtmProfit + swap + commission, 2);
      return(ifDouble(!catch("CalculateProfit(5)"), fullProfit, EMPTY_VALUE));
   }

   return(_EMPTY_VALUE(catch("CalculateProfit(6)  unreachable code reached", ERR_RUNTIME_ERROR)));
}


/**
 * Record the calculated equity values.
 *
 * @return bool - success status
 */
bool RecordAccountData() {
   if (IsTesting())
      return(true);

   datetime now.fxt = GetFxtTime();
   int      size    = ArraySize(hHstSet);

   for (int i=0; i < size; i++) {
      double tickValue     = currentEquity[i];
      double lastTickValue = prevEquity   [i];

      // record virtual ticks only if the equity value changed
      if (Tick.isVirtual) {
         if (!lastTickValue || EQ(tickValue, lastTickValue, 2)) {
            if (symbolSuffixes[i]==".AB") debug("RecordAccountData(1)  Tick.isVirtual="+ Tick.isVirtual +"  skipping "+ symbolSuffixes[i] +" tick "+ DoubleToStr(tickValue, 2));
            continue;
         }
      }

      if (!hHstSet[i]) {
         string symbol      = GetAccountNumber() + symbolSuffixes[i];
         string description = StrReplace(symbolDescriptions[i], "{AccountNumber}", GetAccountNumber());
         int    digits      = 2;
         int    format      = 400;
         string server      = "XTrade-Synthetic";

         hHstSet[i] = HistorySet.Get(symbol, server);
         if (hHstSet[i] == -1)
            hHstSet[i] = HistorySet.Create(symbol, description, digits, format, server);
         if (!hHstSet[i]) return(false);
      }

      if (!HistorySet.AddTick(hHstSet[i], now.fxt, tickValue, NULL)) return(false);

      prevEquity[i] = tickValue;
   }
   return(true);
}
