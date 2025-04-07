/**
 * Compute floating profit values of all open positions.
 *
 * @param  _Out_ string symbols[]                  - symbols of open positions
 * @param  _Out_ double profits[]                  - PnL value per symbol
 * @param  _In_  bool   includePendings [optional] - Whether to include symbols with pending orders, returned profit will be 0.00 (default: no).
 * @param  _In_  bool   ignoreSpread    [optional] - Whether not to track the spread of open positions. Not applied to hedged positions.
 *                                                   Use if spread widening shall not impact the result (default: no).
 * @return bool - success status
 */
bool ComputeFloatingProfits(string &symbols[], double &profits[], bool includePendings=false, bool ignoreSpread=false) {
   includePendings = includePendings!=0;
   ignoreSpread    = ignoreSpread!=0;
   string _symbols[]; ArrayResize(_symbols, 0);
   bool   _pending[]; ArrayResize(_pending, 0);                      // whether only pending orders exist for a symbol
   double _profits[]; ArrayResize(_profits, 0);

   // read open order data
   int orders = OrdersTotal();
   int    iSymbols    []; ArrayResize(iSymbols,     orders);         // iSymbols[] = symbol index in _symbols[]
   int    tickets     []; ArrayResize(tickets,      orders);
   int    types       []; ArrayResize(types,        orders);
   double lots        []; ArrayResize(lots,         orders);
   double openPrices  []; ArrayResize(openPrices,   orders);
   double commissions []; ArrayResize(commissions,  orders);
   double swaps       []; ArrayResize(swaps,        orders);
   double orderProfits[]; ArrayResize(orderProfits, orders);

   for (int n, si, i=0; i < orders; i++) {                           // si => current symbol index in _symbols[]
      if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) break;        // FALSE: an open order was closed/deleted in another thread
      if (OrderType() > OP_SELL) {
         if (!includePendings) continue;                             // skip pending orders or not
      }
      if (!n) {
         ArrayPushString(_symbols, OrderSymbol());
         ArrayPushBool  (_pending, true);
         si = ArraySize(_symbols) - 1;
      }
      else if (_symbols[si] != OrderSymbol()) {
         si = SearchStringArray(_symbols, OrderSymbol());
         if (si == -1) {
            ArrayPushString(_symbols, OrderSymbol());
            ArrayPushBool  (_pending, true);
            si = ArraySize(_symbols) - 1;
         }
      }
      iSymbols    [n] = si;
      tickets     [n] = OrderTicket();
      types       [n] = OrderType();
      lots        [n] = NormalizeDouble(OrderLots(), 2);
      openPrices  [n] = OrderOpenPrice();
      commissions [n] = OrderCommission();
      swaps       [n] = OrderSwap();
      orderProfits[n] = OrderProfit();

      if (OrderType() <= OP_SELL) _pending[si] = false;
      n++;
   }
   if (n < orders) {
      ArrayResize(iSymbols,     n);
      ArrayResize(tickets,      n);
      ArrayResize(types,        n);
      ArrayResize(lots,         n);
      ArrayResize(openPrices,   n);
      ArrayResize(commissions,  n);
      ArrayResize(swaps,        n);
      ArrayResize(orderProfits, n);
      orders = n;
   }

   // compute each symbol's PnL
   int sizeOfSymbols = ArraySize(_symbols);
   ArrayResize(_profits, sizeOfSymbols);

   for (i=0; i < sizeOfSymbols; i++) {
      if (_pending[i]) {
         _profits[i] = EMPTY_VALUE;          // empty PnL value for symbols with pending orders only (0.00 is a valid PnL)
      }
      else {
         _profits[i] = ComputeFloatingProfit(_symbols[i], i, iSymbols, tickets, types, lots, openPrices, commissions, swaps, orderProfits, ignoreSpread);
         _profits[i] = NormalizeDouble(_profits[i], 2);
         if (_profits[i] == EMPTY_VALUE) return(false);
      }
   }

   // finally modify passed parameters
   ArrayResize(symbols, 0);
   if (ArraySize(_symbols) > 0) ArrayCopy(symbols, _symbols);

   ArrayResize(profits, 0);
   if (ArraySize(_profits) > 0) ArrayCopy(profits, _profits);

   ArrayResize(_symbols, 0);
   ArrayResize(_profits, 0);
   ArrayResize(_pending, 0);
   return(!catch("ComputeFloatingProfits(1)"));
}


/**
 * Compute the floating profit of a single symbol. Profit of hedged positions is calculated in the most effective way,
 * ie. hedged positions are closed "one by another".
 *
 * Should be called from ComputeFloatingProfits() only.
 *
 * @param  _In_    string symbol                  - symbol
 * @param  _In_    int    symbolIndex             - symbol index in symbols[]
 * @param  _In_    int    iSymbols   []           - order data
 * @param  _InOut_ int    tickets    []           - ...
 * @param  _In_    int    types      []           - ...
 * @param  _InOut_ double lots       []           - ...
 * @param  _In_    double openPrices []           - ...
 * @param  _InOut_ double commissions[]           - ...
 * @param  _InOut_ double swaps      []           - ...
 * @param  _InOut_ double profits    []           - ...
 * @param  _In_    bool   ignoreSpread [optional] - Whether to not track the spread of open positions. Not applied to hedged positions.
 *                                                  Use if spread widening shall not impact the result (default: no).
 *
 * @return double - PnL value of the symbol or EMPTY_VALUE in case of errors
 */
double ComputeFloatingProfit(string symbol, int symbolIndex, int iSymbols[], int &tickets[], int types[], double &lots[], double openPrices[], double &commissions[], double &swaps[], double &profits[], bool ignoreSpread=false) {
   ignoreSpread = ignoreSpread!=0;
   double longPosition, shortPosition, totalPosition, hedgedLots, remainingLong, remainingShort, factor, openPrice, closePrice, commission, swap, floatingProfit, fullProfit, hedgedProfit, spread, spreadPips, spreadProfit, pipValue, pipDistance;
   int ticketsSize = ArraySize(tickets), error;

   // resolve the symbol's total position: hedged volume (constant PnL) + directional volume (variable PnL)
   for (int i=0; i < ticketsSize; i++) {
      if (iSymbols[i] != symbolIndex) continue;

      if      (types[i] == OP_BUY)  longPosition  += lots[i];                 // add-up total volume per market direction
      else if (types[i] == OP_SELL) shortPosition += lots[i];
   }
   longPosition  = NormalizeDouble(longPosition,  2);
   shortPosition = NormalizeDouble(shortPosition, 2);
   totalPosition = NormalizeDouble(longPosition-shortPosition, 2);

   // TODO: in indicators loaded in a new chart MarketInfo(MODE_DIGITS) may be erroneous
   int    digits    = MarketInfoEx(symbol, MODE_DIGITS, error, "ComputeFloatingProfit(1)"); if (error != NULL) return(EMPTY_VALUE);
   int    pipDigits = digits & (~1);
   double pipSize   = NormalizeDouble(1/MathPow(10, pipDigits), pipDigits);

   if (ignoreSpread) {
      spread     = MarketInfoEx(symbol, MODE_SPREAD, error, "ComputeFloatingProfit(2)"); if (error != NULL) return(EMPTY_VALUE);
      spreadPips = spread/MathPow(10, digits & 1);                            // spread in pip
   }

   // resolve the constant PnL of a hedged position
   if (longPosition && shortPosition) {
      hedgedLots     = MathMin(longPosition, shortPosition);
      remainingLong  = hedgedLots;
      remainingShort = hedgedLots;

      for (i=0; i < ticketsSize; i++) {
         if (iSymbols[i] != symbolIndex) continue;
         if (!tickets[i])                continue;

         if (types[i] == OP_BUY) {
            if (!remainingLong) continue;
            if (remainingLong >= lots[i]) {
               // apply all data and nullify ticket
               openPrice     = NormalizeDouble(openPrice + lots[i] * openPrices[i], 8);
               swap         += swaps      [i];
               commission   += commissions[i];
               remainingLong = NormalizeDouble(remainingLong - lots[i], 3);
               tickets[i]    = NULL;
            }
            else {
               // apply full swap and reduce the ticket's commission, PnL and lotsize
               factor        = remainingLong/lots[i];
               openPrice     = NormalizeDouble(openPrice + remainingLong * openPrices[i], 8);
               swap         += swaps[i];                swaps      [i]  = 0;
               commission   += factor * commissions[i]; commissions[i] -= factor * commissions[i];
                                                        profits    [i] -= factor * profits    [i];
                                                        lots       [i]  = NormalizeDouble(lots[i]-remainingLong, 3);
               remainingLong = 0;
            }
         }
         else if (types[i] == OP_SELL) {
            if (!remainingShort) continue;
            if (remainingShort >= lots[i]) {
               // apply all data and nullify ticket
               closePrice     = NormalizeDouble(closePrice + lots[i] * openPrices[i], 8);
               swap          += swaps      [i];
               //commission  += commissions[i];                                        // apply commission for the long leg only
               remainingShort = NormalizeDouble(remainingShort - lots[i], 3);
               tickets[i]     = NULL;
            }
            else {
               // apply full swap and reduce the ticket's commission, PnL and lotsize
               factor         = remainingShort/lots[i];
               closePrice     = NormalizeDouble(closePrice + remainingShort * openPrices[i], 8);
               swap          += swaps[i]; swaps      [i]  = 0;
                                          commissions[i] -= factor * commissions[i];   // apply commission for the long leg only
                                          profits    [i] -= factor * profits    [i];
                                          lots       [i]  = NormalizeDouble(lots[i]-remainingShort, 3);
               remainingShort = 0;
            }
         }
      }
      if (remainingLong  != 0) return(_EMPTY_VALUE(catch("ComputeFloatingProfit(3)  illegal remaining long position = "+ NumberToStr(remainingLong, ".+") +" of hedged position = "+ NumberToStr(hedgedLots, ".+"), ERR_RUNTIME_ERROR)));
      if (remainingShort != 0) return(_EMPTY_VALUE(catch("ComputeFloatingProfit(4)  illegal remaining short position = "+ NumberToStr(remainingShort, ".+") +" of hedged position = "+ NumberToStr(hedgedLots, ".+"), ERR_RUNTIME_ERROR)));

      // calculate BE distance and the resulting PnL
      pipValue     = PipValueEx(symbol, hedgedLots, error, "ComputeFloatingProfit(5)"); if (error != NULL) return(EMPTY_VALUE);
      pipDistance  = (closePrice-openPrice)/hedgedLots/pipSize + (commission+swap)/pipValue;
      hedgedProfit = pipDistance * pipValue;

      // without directional position return PnL of the hedged position only
      if (!totalPosition) {
         fullProfit = NormalizeDouble(hedgedProfit, 2);
         return(ifDouble(!catch("ComputeFloatingProfit(6)"), fullProfit, EMPTY_VALUE));
      }
   }

   // calculate PnL of a long position (if any)
   if (totalPosition > 0.005) {
      swap           = 0;
      commission     = 0;
      floatingProfit = 0;
      spreadProfit   = 0;

      for (i=0; i < ticketsSize; i++) {
         if (iSymbols[i] != symbolIndex) continue;
         if (!tickets[i])                continue;

         if (types[i] == OP_BUY) {
            swap           += swaps      [i];
            commission     += commissions[i];
            floatingProfit += profits    [i];
            tickets[i]      = NULL;
         }
      }
      // if enabled add the PnL value of the spread to ignore spread spikes/widening
      if (ignoreSpread) {
         spreadProfit = spreadPips * PipValueEx(symbol, totalPosition, error, "ComputeFloatingProfit(7)"); if (error != NULL) return(EMPTY_VALUE);
      }
      fullProfit = NormalizeDouble(hedgedProfit + floatingProfit + spreadProfit + swap + commission, 2);
      return(ifDouble(!catch("ComputeFloatingProfit(8)"), fullProfit, EMPTY_VALUE));
   }

   // calculate PnL of a short position (if any)
   if (totalPosition < -0.005) {
      swap           = 0;
      commission     = 0;
      floatingProfit = 0;
      spreadProfit   = 0;

      for (i=0; i < ticketsSize; i++) {
         if (iSymbols[i] != symbolIndex) continue;
         if (!tickets[i])                continue;

         if (types[i] == OP_SELL) {
            swap           += swaps      [i];
            commission     += commissions[i];
            floatingProfit += profits    [i];
            tickets[i]      = NULL;
         }
      }
      // if enabled add the PnL value of the spread to ignore spread spikes/widening
      if (ignoreSpread) {
         spreadProfit = spreadPips * PipValueEx(symbol, -totalPosition, error, "ComputeFloatingProfit(9)"); if (error != NULL) return(EMPTY_VALUE);
      }
      fullProfit = NormalizeDouble(hedgedProfit + floatingProfit + spreadProfit + swap + commission, 2);
      return(ifDouble(!catch("ComputeFloatingProfit(10)"), fullProfit, EMPTY_VALUE));
   }

   // no position (pending orders only)
   return(NULL);
}
