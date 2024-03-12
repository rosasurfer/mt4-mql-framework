/**
 * Add an order record to the trade history array. Records are ordered ascending by {OpenTime, Ticket} and the new record is
 * inserted at the correct position. No data is overwritten.
 *
 * @param  int      ticket
 * @param  int      fromTicket
 * @param  int      toTicket
 * @param  int      type
 * @param  double   lots
 * @param  datetime openTime
 * @param  double   openPrice
 * @param  double   openPriceSig
 * @param  double   stopLoss
 * @param  double   takeProfit
 * @param  datetime closeTime
 * @param  double   closePrice
 * @param  double   closePriceSig
 * @param  double   slippage
 * @param  double   swap
 * @param  double   commission
 * @param  double   grossProfit
 * @param  double   netProfit
 * @param  double   netProfitP
 * @param  double   runupP
 * @param  double   drawdownP
 * @param  double   sigProfitP
 * @param  double   sigRunupP
 * @param  double   sigDrawdownP
 *
 * @return int - index the record was inserted at or EMPTY (-1) in case of errors
 */
int AddHistoryRecord(int ticket, int fromTicket, int toTicket, int type, double lots, datetime openTime, double openPrice, double openPriceSig, double stopLoss, double takeProfit, datetime closeTime, double closePrice, double closePriceSig, double slippage, double swap, double commission, double grossProfit, double netProfit, double netProfitP, double runupP, double drawdownP, double sigProfitP, double sigRunupP, double sigDrawdownP) {
   int size = ArrayRange(history, 0);

   // resolve the array index to insert at
   for (int i=size-1; i >= 0; i--) {                                 // iterate from the end (in most use cases faster)
      if (ticket == history[i][H_TICKET]) return(_EMPTY(catch("AddHistoryRecord(1)  "+ instance.name +" cannot add record, ticket #"+ ticket +" already exists (index "+ i +")", ERR_INVALID_PARAMETER)));

      if (openTime > history[i][H_OPENTIME]) {
         i++;
         break;
      }
      if (openTime == history[i][H_OPENTIME]) {                      // same openTime, compare tickets
         if (ticket > history[i][H_TICKET]) i++;
         break;
      }
   }
   if (i < 0) i = 0;

   // 'i' now holds the index to insert at
   if (i == size) {
      ArrayResize(history, size+1);                                  // append an empty slot or...
   }
   else {
      int dim2=ArrayRange(history, 1), from=i*dim2, to=from+dim2;    // free an existing slot by shifting existing data
      ArrayCopy(history, history, to, from);
   }

   // insert the new data
   history[i][H_TICKET        ] = ticket;
   history[i][H_FROM_TICKET   ] = fromTicket;
   history[i][H_TO_TICKET     ] = toTicket;
   history[i][H_TYPE          ] = type;
   history[i][H_LOTS          ] = lots;
   history[i][H_OPENTIME      ] = openTime;
   history[i][H_OPENPRICE     ] = openPrice;
   history[i][H_OPENPRICE_SIG ] = openPriceSig;
   history[i][H_STOPLOSS      ] = stopLoss;
   history[i][H_TAKEPROFIT    ] = takeProfit;
   history[i][H_CLOSETIME     ] = closeTime;
   history[i][H_CLOSEPRICE    ] = closePrice;
   history[i][H_CLOSEPRICE_SIG] = closePriceSig;
   history[i][H_SLIPPAGE      ] = slippage;
   history[i][H_SWAP          ] = swap;
   history[i][H_COMMISSION    ] = commission;
   history[i][H_GROSSPROFIT   ] = grossProfit;
   history[i][H_NETPROFIT     ] = netProfit;
   history[i][H_NETPROFIT_P   ] = netProfitP;
   history[i][H_RUNUP_P       ] = runupP;
   history[i][H_DRAWDOWN_P    ] = drawdownP;
   history[i][H_SIG_PROFIT_P  ] = sigProfitP;
   history[i][H_SIG_RUNUP_P   ] = sigRunupP;
   history[i][H_SIG_DRAWDOWN_P] = sigDrawdownP;

   if (!catch("AddHistoryRecord(2)"))
      return(i);
   return(EMPTY);
}
