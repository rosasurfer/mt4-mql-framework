/**
 * Add a trade record to history[] or partialClose[] array. Records are ordered ascending by {OpenTime, Ticket} and the record
 * is inserted  at the correct position. No data is overwritten.
 *
 * @param  int      ticket
 * @param  int      fromTicket
 * @param  int      toTicket
 * @param  int      type
 * @param  double   lots
 * @param  double   part
 * @param  datetime openTime
 * @param  double   openPrice
 * @param  double   openPriceSig
 * @param  double   stopLoss
 * @param  double   takeProfit
 * @param  datetime closeTime
 * @param  double   closePrice
 * @param  double   closePriceSig
 * @param  double   slippageP
 * @param  double   swapM
 * @param  double   commissionM
 * @param  double   grossProfitM
 * @param  double   netProfitM
 * @param  double   netProfitP
 * @param  double   runupP
 * @param  double   rundownP
 * @param  double   sigProfitP
 * @param  double   sigRunupP
 * @param  double   sigRundownP
 *
 * @return int - index the record was inserted at or EMPTY (-1) in case of errors
 */
int AddHistoryRecord(int ticket, int fromTicket, int toTicket, int type, double lots, double part, datetime openTime, double openPrice, double openPriceSig, double stopLoss, double takeProfit, datetime closeTime, double closePrice, double closePriceSig, double slippageP, double swapM, double commissionM, double grossProfitM, double netProfitM, double netProfitP, double runupP, double rundownP, double sigProfitP, double sigRunupP, double sigRundownP) {
   bool isPartial = NE(part, 1);

   if (isPartial) {
      // resolve the partialClose[] index to insert at
      int size = ArrayRange(partialClose, 0);
      for (int i=size-1; i >= 0; i--) {                        // iterate from the end (in most use cases faster)
         if (ticket == partialClose[i][H_TICKET]) return(_EMPTY(catch("AddHistoryRecord(1)  "+ instance.name +" cannot add record, ticket #"+ ticket +" already exists (partialClose["+ i +"])", ERR_INVALID_PARAMETER)));

         if (openTime > partialClose[i][H_OPENTIME]) {
            i++;
            break;
         }
         if (openTime == partialClose[i][H_OPENTIME]) {        // same openTime, compare tickets
            if (ticket > partialClose[i][H_TICKET]) i++;
            break;
         }
      }
      if (i < 0) i = 0;

      // 'i' now holds the index to insert at
      if (i == size) {
         ArrayResize(partialClose, size+1);                    // append an empty slot or...
      }
      else {
         int dim2 = ArrayRange(partialClose, 1);               // free an existing slot by shifting existing data
         int from = i * dim2;
         int to   = from + dim2;
         ArrayCopy(partialClose, partialClose, to, from);
      }

      // insert the new data
      partialClose[i][H_TICKET        ] = ticket;
      partialClose[i][H_FROM_TICKET   ] = fromTicket;
      partialClose[i][H_TO_TICKET     ] = toTicket;
      partialClose[i][H_TYPE          ] = type;
      partialClose[i][H_LOTS          ] = lots;
      partialClose[i][H_PART          ] = part;
      partialClose[i][H_OPENTIME      ] = openTime;
      partialClose[i][H_OPENPRICE     ] = openPrice;
      partialClose[i][H_OPENPRICE_SIG ] = openPriceSig;
      partialClose[i][H_STOPLOSS      ] = stopLoss;
      partialClose[i][H_TAKEPROFIT    ] = takeProfit;
      partialClose[i][H_CLOSETIME     ] = closeTime;
      partialClose[i][H_CLOSEPRICE    ] = closePrice;
      partialClose[i][H_CLOSEPRICE_SIG] = closePriceSig;
      partialClose[i][H_SLIPPAGE_P    ] = slippageP;
      partialClose[i][H_SWAP_M        ] = swapM;
      partialClose[i][H_COMMISSION_M  ] = commissionM;
      partialClose[i][H_GROSSPROFIT_M ] = grossProfitM;
      partialClose[i][H_NETPROFIT_M   ] = netProfitM;
      partialClose[i][H_NETPROFIT_P   ] = netProfitP;
      partialClose[i][H_RUNUP_P       ] = runupP;
      partialClose[i][H_RUNDOWN_P     ] = rundownP;
      partialClose[i][H_SIG_PROFIT_P  ] = sigProfitP;
      partialClose[i][H_SIG_RUNUP_P   ] = sigRunupP;
      partialClose[i][H_SIG_RUNDOWN_P ] = sigRundownP;
   }

   else {
      // resolve the history[] index to insert at
      size = ArrayRange(history, 0);
      for (i=size-1; i >= 0; i--) {                            // iterate from the end (in most use cases faster)
         if (ticket == history[i][H_TICKET]) return(_EMPTY(catch("AddHistoryRecord(2)  "+ instance.name +" cannot add record, ticket #"+ ticket +" already exists (history["+ i +"])", ERR_INVALID_PARAMETER)));

         if (openTime > history[i][H_OPENTIME]) {
            i++;
            break;
         }
         if (openTime == history[i][H_OPENTIME]) {             // same openTime, compare tickets
            if (ticket > history[i][H_TICKET]) i++;
            break;
         }
      }
      if (i < 0) i = 0;

      // 'i' now holds the index to insert at
      if (i == size) {
         ArrayResize(history, size+1);                         // append an empty slot or...
      }
      else {
         dim2 = ArrayRange(history, 1);
         from = i * dim2;
         to   = from + dim2;                                   // free an existing slot by shifting existing data
         ArrayCopy(history, history, to, from);
      }

      // insert the new data
      history[i][H_TICKET        ] = ticket;
      history[i][H_FROM_TICKET   ] = fromTicket;
      history[i][H_TO_TICKET     ] = toTicket;
      history[i][H_TYPE          ] = type;
      history[i][H_LOTS          ] = lots;
      history[i][H_PART          ] = part;
      history[i][H_OPENTIME      ] = openTime;
      history[i][H_OPENPRICE     ] = openPrice;
      history[i][H_OPENPRICE_SIG ] = openPriceSig;
      history[i][H_STOPLOSS      ] = stopLoss;
      history[i][H_TAKEPROFIT    ] = takeProfit;
      history[i][H_CLOSETIME     ] = closeTime;
      history[i][H_CLOSEPRICE    ] = closePrice;
      history[i][H_CLOSEPRICE_SIG] = closePriceSig;
      history[i][H_SLIPPAGE_P    ] = slippageP;
      history[i][H_SWAP_M        ] = swapM;
      history[i][H_COMMISSION_M  ] = commissionM;
      history[i][H_GROSSPROFIT_M ] = grossProfitM;
      history[i][H_NETPROFIT_M   ] = netProfitM;
      history[i][H_NETPROFIT_P   ] = netProfitP;
      history[i][H_RUNUP_P       ] = runupP;
      history[i][H_RUNDOWN_P     ] = rundownP;
      history[i][H_SIG_PROFIT_P  ] = sigProfitP;
      history[i][H_SIG_RUNUP_P   ] = sigRunupP;
      history[i][H_SIG_RUNDOWN_P ] = sigRundownP;
   }

   if (!catch("AddHistoryRecord(3)"))
      return(i);
   return(EMPTY);
}
