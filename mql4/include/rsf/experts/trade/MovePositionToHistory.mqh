/**
 * Move the position referenced in 'open.*' to the trade history. The position must be closed. If the position is fully
 * closed open order data is reset. If the position is partially closed open order data is not reset.
 *
 * @param  datetime closeTime     - close time
 * @param  double   closePrice    - close price
 * @param  double   closePriceSig - signal close price
 *
 * @return bool - success status
 */
bool MovePositionToHistory(datetime closeTime, double closePrice, double closePriceSig) {
   if (last_error != NULL)                return(false);
   if (instance.status != STATUS_TRADING) return(!catch("MovePositionToHistory(1)  "+ instance.name +" cannot process position of "+ StatusDescription(instance.status) +" instance", ERR_ILLEGAL_STATE));
   if (!open.ticket)                      return(!catch("MovePositionToHistory(2)  "+ instance.name +" position not found (open.ticket=NULL)", ERR_ILLEGAL_STATE));

   bool isPartialClose = (open.fromTicket || open.toTicket);

   if (isPartialClose) {
      // add trade to partialClose[]
      int i = ArrayRange(partialClose, 0);
      ArrayResize(partialClose, i+1);
      partialClose[i][H_TICKET        ] = open.ticket;
      partialClose[i][H_FROM_TICKET   ] = open.fromTicket;
      partialClose[i][H_TO_TICKET     ] = open.toTicket;
      partialClose[i][H_TYPE          ] = open.type;
      partialClose[i][H_LOTS          ] = open.lots;
      partialClose[i][H_PART          ] = open.part;
      partialClose[i][H_OPENTIME      ] = open.time;
      partialClose[i][H_OPENPRICE     ] = open.price;
      partialClose[i][H_OPENPRICE_SIG ] = open.priceSig;
      partialClose[i][H_STOPLOSS      ] = open.stopLoss;
      partialClose[i][H_TAKEPROFIT    ] = open.takeProfit;
      partialClose[i][H_CLOSETIME     ] = closeTime;
      partialClose[i][H_CLOSEPRICE    ] = closePrice;
      partialClose[i][H_CLOSEPRICE_SIG] = closePriceSig;
      partialClose[i][H_SLIPPAGE_P    ] = open.slippageP;
      partialClose[i][H_SWAP_M        ] = open.swapM;
      partialClose[i][H_COMMISSION_M  ] = open.commissionM;
      partialClose[i][H_GROSSPROFIT_M ] = open.grossProfitM;
      partialClose[i][H_NETPROFIT_M   ] = open.netProfitM;
      partialClose[i][H_NETPROFIT_P   ] = open.netProfitP;
      partialClose[i][H_RUNUP_P       ] = open.runupP;
      partialClose[i][H_RUNDOWN_P     ] = open.rundownP;
      partialClose[i][H_SIG_PROFIT_P  ] = open.sigProfitP;
      partialClose[i][H_SIG_RUNUP_P   ] = open.sigRunupP;
      partialClose[i][H_SIG_RUNDOWN_P ] = open.sigRundownP;

      //logNotice("MovePositionToHistory(0.1)  oc="+ DoubleToStr(ifDouble(!open.type, closePrice-open.price, open.price-closePrice)/pUnit, pDigits) +"  sig-oc="+ DoubleToStr(ifDouble(!open.type, closePriceSig-open.priceSig, open.priceSig-closePriceSig)/pUnit, pDigits) +"  part="+ HistoryRecordToStr(i, true, false));
   }
   else {
      // add trade to history[]
      i = ArrayRange(history, 0);
      ArrayResize(history, i+1);
      history[i][H_TICKET        ] = open.ticket;
      history[i][H_FROM_TICKET   ] = open.fromTicket;
      history[i][H_TO_TICKET     ] = open.toTicket;
      history[i][H_TYPE          ] = open.type;
      history[i][H_LOTS          ] = open.lots;
      history[i][H_PART          ] = open.part;
      history[i][H_OPENTIME      ] = open.time;
      history[i][H_OPENPRICE     ] = open.price;
      history[i][H_OPENPRICE_SIG ] = open.priceSig;
      history[i][H_STOPLOSS      ] = open.stopLoss;
      history[i][H_TAKEPROFIT    ] = open.takeProfit;
      history[i][H_CLOSETIME     ] = closeTime;
      history[i][H_CLOSEPRICE    ] = closePrice;
      history[i][H_CLOSEPRICE_SIG] = closePriceSig;
      history[i][H_SLIPPAGE_P    ] = open.slippageP;
      history[i][H_SWAP_M        ] = open.swapM;
      history[i][H_COMMISSION_M  ] = open.commissionM;
      history[i][H_GROSSPROFIT_M ] = open.grossProfitM;
      history[i][H_NETPROFIT_M   ] = open.netProfitM;
      history[i][H_NETPROFIT_P   ] = open.netProfitP;
      history[i][H_RUNUP_P       ] = open.runupP;
      history[i][H_RUNDOWN_P     ] = open.rundownP;
      history[i][H_SIG_PROFIT_P  ] = open.sigProfitP;
      history[i][H_SIG_RUNUP_P   ] = open.sigRunupP;
      history[i][H_SIG_RUNDOWN_P ] = open.sigRundownP;

      //logNotice("MovePositionToHistory(0.2)  oc="+ DoubleToStr(ifDouble(!open.type, closePrice-open.price, open.price-closePrice)/pUnit, pDigits) +"  sig-oc="+ DoubleToStr(ifDouble(!open.type, closePriceSig-open.priceSig, open.priceSig-closePriceSig)/pUnit, pDigits) +"  hist="+ HistoryRecordToStr(i, false, false));
   }

   // update PnL stats
   stats[METRIC_NET_MONEY][S_CLOSED_PROFIT] += open.netProfitM;
   stats[METRIC_NET_UNITS][S_CLOSED_PROFIT] += open.netProfitP;
   stats[METRIC_SIG_UNITS][S_CLOSED_PROFIT] += open.sigProfitP;

   if (!open.toTicket) {
      if (open.fromTicket > 0) {
         // iterate over partial closes and aggregate a single trade for history[]
         int      a.ticket;                                    // first ticket
         int      a.fromTicket    = open.ticket;               // first fromTicket (zero)
         int      a.toTicket;                                  // first toTicket, link between history[] and partialClose[]
         int      a.type          = open.type;
         double   a.lots;                                      // sum of all partials
         double   a.part;                                      // sum of all partials
         datetime a.openTime      = open.time;
         double   a.openPrice     = open.price;
         double   a.openPriceSig  = open.priceSig;
         double   a.stopLoss      = open.stopLoss;             // last stoploss
         double   a.takeProfit    = open.takeProfit;           // last takeprofit
         datetime a.closeTime     = closeTime;                 // last closeTime
         double   a.closePrice    = closePrice;                // last closePrice
         double   a.closePriceSig = closePriceSig;             // last closePriceSig
         double   a.slippageP;                                 // sum of all partials
         double   a.swapM;                                     // sum of all partials
         double   a.commissionM;                               // sum of all partials
         double   a.grossProfitM;                              // sum of all partials
         double   a.netProfitM;                                // sum of all partials
         double   a.netProfitP;                                // sum of all partials
         double   a.runupP        = open.runupP;               // last runupP
         double   a.rundownP      = open.rundownP;             // last rundownP
         double   a.sigProfitP;                                // sum of all partials
         double   a.sigRunupP     = open.sigRunupP;            // last sigRunupP
         double   a.sigRundownP   = open.sigRundownP;          // last sigRundownP

         // collect/aggregate values
         for (; i >= 0; i--) {                                 // start at the last part
            if (partialClose[i][H_TICKET] != a.fromTicket) continue;
            a.ticket        = partialClose[i][H_TICKET       ];
            a.fromTicket    = partialClose[i][H_FROM_TICKET  ];
            a.toTicket      = partialClose[i][H_TO_TICKET    ];
            a.lots         += partialClose[i][H_LOTS         ];
            a.part         += partialClose[i][H_PART         ];
            a.slippageP    += partialClose[i][H_SLIPPAGE_P   ];
            a.swapM        += partialClose[i][H_SWAP_M       ];
            a.commissionM  += partialClose[i][H_COMMISSION_M ];
            a.grossProfitM += partialClose[i][H_GROSSPROFIT_M];
            a.netProfitM   += partialClose[i][H_NETPROFIT_M  ];
            a.netProfitP   += partialClose[i][H_NETPROFIT_P  ];
            a.sigProfitP   += partialClose[i][H_SIG_PROFIT_P ];
            if (!a.fromTicket) break;                          // stop at the first part
         }

         // validate the aggregated record and add it to history[]
         if (a.fromTicket != 0) return(!catch("MovePositionToHistory(3)  "+ instance.name +" fromTicket #"+ a.fromTicket +" not found in partialClose[]", ERR_ILLEGAL_STATE));
         if (NE(a.part, 1, 2))  return(!catch("MovePositionToHistory(4)  "+ instance.name +" not all partial closes from ticket #"+ open.ticket +" found (found "+ NumberToStr(a.part, ".1+") +" of 1.0)", ERR_ILLEGAL_STATE));
         a.lots         = NormalizeDouble(a.lots, 2);           // normalize calculated fields
         a.part         = 1;
         a.slippageP    = NormalizeDouble(a.slippageP, Digits);
         a.swapM        = NormalizeDouble(a.swapM,        2);
         a.commissionM  = NormalizeDouble(a.commissionM,  2);
         a.grossProfitM = NormalizeDouble(a.grossProfitM, 2);
         a.netProfitM   = NormalizeDouble(a.netProfitM,   2);

         // we can't use AddHistoryRecord() as it invalidates the cache used by CalculateStats(), thus negatively impacting test speed
         i = ArrayRange(history, 0);
         ArrayResize(history, i+1);
         history[i][H_TICKET        ] = a.ticket;
         history[i][H_FROM_TICKET   ] = a.fromTicket;
         history[i][H_TO_TICKET     ] = a.toTicket;
         history[i][H_TYPE          ] = a.type;
         history[i][H_LOTS          ] = a.lots;
         history[i][H_PART          ] = a.part;
         history[i][H_OPENTIME      ] = a.openTime;
         history[i][H_OPENPRICE     ] = a.openPrice;
         history[i][H_OPENPRICE_SIG ] = a.openPriceSig;
         history[i][H_STOPLOSS      ] = a.stopLoss;
         history[i][H_TAKEPROFIT    ] = a.takeProfit;
         history[i][H_CLOSETIME     ] = a.closeTime;
         history[i][H_CLOSEPRICE    ] = a.closePrice;
         history[i][H_CLOSEPRICE_SIG] = a.closePriceSig;
         history[i][H_SLIPPAGE_P    ] = a.slippageP;
         history[i][H_SWAP_M        ] = a.swapM;
         history[i][H_COMMISSION_M  ] = a.commissionM;
         history[i][H_GROSSPROFIT_M ] = a.grossProfitM;
         history[i][H_NETPROFIT_M   ] = a.netProfitM;
         history[i][H_NETPROFIT_P   ] = a.netProfitP;
         history[i][H_RUNUP_P       ] = a.runupP;
         history[i][H_RUNDOWN_P     ] = a.rundownP;
         history[i][H_SIG_PROFIT_P  ] = a.sigProfitP;
         history[i][H_SIG_RUNUP_P   ] = a.sigRunupP;
         history[i][H_SIG_RUNDOWN_P ] = a.sigRundownP;

         //logNotice("MovePositionToHistory(0.3)  oc="+ DoubleToStr(ifDouble(!a.type, a.closePrice-a.openPrice, a.openPrice-a.closePrice)/pUnit, pDigits) +"  sig-oc="+ DoubleToStr(ifDouble(!a.type, a.closePriceSig-a.openPriceSig, a.openPriceSig-a.closePriceSig)/pUnit, pDigits) +"  hist="+ HistoryRecordToStr(i, false, false));
      }

      // reset open position data
      open.ticket       = NULL;
      open.fromTicket   = NULL;
      open.toTicket     = NULL;
      open.type         = NULL;
      open.lots         = NULL;
      open.part         = 1;
      open.time         = NULL;
      open.price        = NULL;
      open.priceSig     = NULL;
      open.stopLoss     = NULL;
      open.takeProfit   = NULL;
      open.slippageP    = NULL;
      open.swapM        = NULL;
      open.commissionM  = NULL;
      open.grossProfitM = NULL;
      open.netProfitM   = NULL;
      open.netProfitP   = NULL;
      open.runupP       = NULL;
      open.rundownP     = NULL;
      open.sigProfitP   = NULL;
      open.sigRunupP    = NULL;
      open.sigRundownP  = NULL;
   }

   if (__isChart) {
      CalculateStats();
      SS.OpenLots();
      SS.ClosedTrades();
   }
   return(!catch("MovePositionToHistory(5)"));
}
