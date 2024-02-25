/**
 * Add an order record to the trade history array. Records are ordered ascending by {OpenTime;Ticket} and the new record is inserted
 * at the correct position. No data is overwritten.
 *
 * @param  int      ticket
 * @param  int      type
 * @param  double   lots
 * @param  datetime openTime
 * @param  double   openPrice
 * @param  double   openPriceSynth
 * @param  datetime closeTime
 * @param  double   closePrice
 * @param  double   closePriceSynth
 * @param  double   slippage
 * @param  double   swap
 * @param  double   commission
 * @param  double   grossProfit
 * @param  double   netProfit
 * @param  double   netProfitP
 * @param  double   runupP
 * @param  double   drawdownP
 * @param  double   synthProfitP
 * @param  double   synthRunupP
 * @param  double   synthDrawdownP
 *
 * @return int - index the record was inserted at or EMPTY (-1) in case of errors
 */
int History.AddRecord(int ticket, int type, double lots, datetime openTime, double openPrice, double openPriceSynth, datetime closeTime, double closePrice, double closePriceSynth, double slippage, double swap, double commission, double grossProfit, double netProfit, double netProfitP, double runupP, double drawdownP, double synthProfitP, double synthRunupP, double synthDrawdownP) {
   int size = ArrayRange(history, 0);

   for (int i=0; i < size; i++) {
      if (EQ(ticket,   history[i][H_TICKET  ])) return(_EMPTY(catch("History.AddRecord(1)  "+ instance.name +" cannot add record, ticket #"+ ticket +" already exists (offset: "+ i +")", ERR_INVALID_PARAMETER)));
      if (GT(openTime, history[i][H_OPENTIME])) continue;
      if (LT(openTime, history[i][H_OPENTIME])) break;
      if (LT(ticket,   history[i][H_TICKET  ])) break;
   }

   // 'i' now holds the array index to insert at
   if (i == size) {
      ArrayResize(history, size+1);                                  // add a new empty slot or...
   }
   else {
      int dim2=ArrayRange(history, 1), from=i*dim2, to=from+dim2;    // ...free an existing slot by shifting existing data
      ArrayCopy(history, history, to, from);
   }

   // insert the new data
   history[i][H_TICKET          ] = ticket;
   history[i][H_TYPE            ] = type;
   history[i][H_LOTS            ] = lots;
   history[i][H_OPENTIME        ] = openTime;
   history[i][H_OPENPRICE       ] = openPrice;
   history[i][H_OPENPRICE_SYNTH ] = openPriceSynth;
   history[i][H_CLOSETIME       ] = closeTime;
   history[i][H_CLOSEPRICE      ] = closePrice;
   history[i][H_CLOSEPRICE_SYNTH] = closePriceSynth;
   history[i][H_SLIPPAGE        ] = slippage;
   history[i][H_SWAP            ] = swap;
   history[i][H_COMMISSION      ] = commission;
   history[i][H_GROSSPROFIT     ] = grossProfit;
   history[i][H_NETPROFIT       ] = netProfit;
   history[i][H_NETPROFIT_P     ] = netProfitP;
   history[i][H_RUNUP_P         ] = runupP;
   history[i][H_DRAWDOWN_P      ] = drawdownP;
   history[i][H_SYNTH_PROFIT_P  ] = synthProfitP;
   history[i][H_SYNTH_RUNUP_P   ] = synthRunupP;
   history[i][H_SYNTH_DRAWDOWN_P] = synthDrawdownP;

   if (!catch("History.AddRecord(2)"))
      return(i);
   return(EMPTY);
}
