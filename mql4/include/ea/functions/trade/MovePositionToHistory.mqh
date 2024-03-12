/**
 * Move the position referenced in 'open.*' to the trade history. Assumes the position is now closed.
 *
 * @param  datetime closeTime            - close time
 * @param  double   closePrice           - close price
 * @param  double   closePriceSig        - signal close price
 * @param  bool     resetOpen [optional] - whether to reset open position data (default: yes)
 *
 * @return bool - success status
 */
bool MovePositionToHistory(datetime closeTime, double closePrice, double closePriceSig, bool resetOpen = true) {
   resetOpen = resetOpen!=0;
   if (last_error != NULL)                return(false);
   if (instance.status != STATUS_TRADING) return(!catch("MovePositionToHistory(1)  "+ instance.name +" cannot process position of "+ StatusDescription(instance.status) +" instance", ERR_ILLEGAL_STATE));
   if (!open.ticket)                      return(!catch("MovePositionToHistory(2)  "+ instance.name +" no position found (open.ticket=NULL)", ERR_ILLEGAL_STATE));

   // add data to history
   int i = ArrayRange(history, 0);
   ArrayResize(history, i+1);
   history[i][H_TICKET        ] = open.ticket;
   history[i][H_FROM_TICKET   ] = open.fromTicket;
   history[i][H_TO_TICKET     ] = open.toTicket;
   history[i][H_TYPE          ] = open.type;
   history[i][H_LOTS          ] = open.lots;
   history[i][H_OPENTIME      ] = open.time;
   history[i][H_OPENPRICE     ] = open.price;
   history[i][H_OPENPRICE_SIG ] = open.priceSig;
   history[i][H_STOPLOSS      ] = open.stopLoss;
   history[i][H_TAKEPROFIT    ] = open.takeProfit;
   history[i][H_CLOSETIME     ] = closeTime;
   history[i][H_CLOSEPRICE    ] = closePrice;
   history[i][H_CLOSEPRICE_SIG] = closePriceSig;
   history[i][H_SLIPPAGE      ] = open.slippage;
   history[i][H_SWAP          ] = open.swap;
   history[i][H_COMMISSION    ] = open.commission;
   history[i][H_GROSSPROFIT   ] = open.grossProfit;
   history[i][H_NETPROFIT     ] = open.netProfit;
   history[i][H_NETPROFIT_P   ] = open.netProfitP;
   history[i][H_RUNUP_P       ] = open.runupP;
   history[i][H_DRAWDOWN_P    ] = open.drawdownP;
   history[i][H_SIG_PROFIT_P  ] = open.sigProfitP;
   history[i][H_SIG_RUNUP_P   ] = open.sigRunupP;
   history[i][H_SIG_DRAWDOWN_P] = open.sigDrawdownP;

   // update PnL stats
   instance.closedNetProfit  += open.netProfit;
   instance.closedNetProfitP += open.netProfitP;
   instance.closedSigProfitP += open.sigProfitP;

   // reset open position data
   if (resetOpen) {
      instance.openNetProfit  = 0;
      instance.openNetProfitP = 0;
      instance.openSigProfitP = 0;

      open.ticket       = NULL;
      open.fromTicket   = NULL;
      open.toTicket     = NULL;
      open.type         = NULL;
      open.lots         = NULL;
      open.time         = NULL;
      open.price        = NULL;
      open.priceSig     = NULL;
      open.stopLoss     = NULL;
      open.takeProfit   = NULL;
      open.slippage     = NULL;
      open.swap         = NULL;
      open.commission   = NULL;
      open.grossProfit  = NULL;
      open.netProfit    = NULL;
      open.netProfitP   = NULL;
      open.runupP       = NULL;
      open.drawdownP    = NULL;
      open.sigProfitP   = NULL;
      open.sigRunupP    = NULL;
      open.sigDrawdownP = NULL;
   }

   if (__isChart) {
      if (resetOpen) SS.OpenLots();
      CalculateStats();
      SS.ClosedTrades();
   }
   return(!catch("MovePositionToHistory(3)"));
}
