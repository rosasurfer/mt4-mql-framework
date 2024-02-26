/**
 * Move the position referenced in open.* to the trade history. Assumes the position is already closed.
 *
 * @param datetime closeTime       - close time
 * @param double   closePrice      - close price
 * @param double   closePriceSynth - synthetic close price
 *
 * @return bool - success status
 */
bool MovePositionToHistory(datetime closeTime, double closePrice, double closePriceSynth) {
   if (last_error != NULL)                    return(false);
   if (instance.status != STATUS_PROGRESSING) return(!catch("MovePositionToHistory(1)  "+ instance.name +" cannot process position of "+ StatusDescription(instance.status) +" instance", ERR_ILLEGAL_STATE));
   if (!open.ticket)                          return(!catch("MovePositionToHistory(2)  "+ instance.name +" no position found (open.ticket=NULL)", ERR_ILLEGAL_STATE));

   // add data to history
   int i = ArrayRange(history, 0);
   ArrayResize(history, i+1);
   history[i][H_TICKET          ] = open.ticket;
   history[i][H_TYPE            ] = open.type;
   history[i][H_LOTS            ] = open.lots;
   history[i][H_OPENTIME        ] = open.time;
   history[i][H_OPENPRICE       ] = open.price;
   history[i][H_OPENPRICE_SYNTH ] = open.priceSynth;
   history[i][H_CLOSETIME       ] = closeTime;
   history[i][H_CLOSEPRICE      ] = closePrice;
   history[i][H_CLOSEPRICE_SYNTH] = closePriceSynth;
   history[i][H_SLIPPAGE        ] = open.slippage;
   history[i][H_SWAP            ] = open.swap;
   history[i][H_COMMISSION      ] = open.commission;
   history[i][H_GROSSPROFIT     ] = open.grossProfit;
   history[i][H_NETPROFIT       ] = open.netProfit;
   history[i][H_NETPROFIT_P     ] = open.netProfitP;
   history[i][H_RUNUP_P         ] = open.runupP;
   history[i][H_DRAWDOWN_P      ] = open.drawdownP;
   history[i][H_SYNTH_PROFIT_P  ] = open.synthProfitP;
   history[i][H_SYNTH_RUNUP_P   ] = open.synthRunupP;
   history[i][H_SYNTH_DRAWDOWN_P] = open.synthDrawdownP;

   // update PL numbers
   instance.openNetProfit    = 0;
   instance.openNetProfitP   = 0;
   instance.openSynthProfitP = 0;

   instance.closedNetProfit    += open.netProfit;
   instance.closedNetProfitP   += open.netProfitP;
   instance.closedSynthProfitP += open.synthProfitP;

   // reset open position data
   open.ticket         = NULL;
   open.type           = NULL;
   open.lots           = NULL;
   open.time           = NULL;
   open.price          = NULL;
   open.priceSynth     = NULL;
   open.slippage       = NULL;
   open.swap           = NULL;
   open.commission     = NULL;
   open.grossProfit    = NULL;
   open.netProfit      = NULL;
   open.netProfitP     = NULL;
   open.runupP         = NULL;
   open.drawdownP      = NULL;
   open.synthProfitP   = NULL;
   open.synthRunupP    = NULL;
   open.synthDrawdownP = NULL;

   if (__isChart) {
      CalculateStats();                   // update trade stats
      SS.OpenLots();
      SS.ClosedTrades();
   }
   return(!catch("MovePositionToHistory(3)"));
}
