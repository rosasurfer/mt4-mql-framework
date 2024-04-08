/**
 * Parse the string representation of a closed trade record and store the parsed data.
 *
 * @param  string key   - trade key
 * @param  string value - the string representation to parse
 *
 * @return int - index the record was inserted at or EMPTY (-1) in case of errors
 */
int ReadStatus.HistoryRecord(string key, string value) {
   if (last_error != NULL) return(EMPTY);

   bool isPartial;
   if      (StrStartsWith(key, "full.")) isPartial = false;
   else if (StrStartsWith(key, "part.")) isPartial = true;
   else return(_EMPTY(catch("ReadStatus.HistoryRecord(1)  "+ instance.name +" illegal history key \""+ key +"\"", ERR_INVALID_FILE_FORMAT)));

   // [full|part].i=ticket,fromTicket,toTicket,type,lots,part,openTime,openPrice,openPriceSig,stopLoss,takeProfit,closeTime,closePrice,closePriceSig,slippageP,swapM,commissionM,grossProfitM,netProfitM,netProfitP,runupP,rundownP,sigProfitP,sigRunupP,sigRundownP
   string values[];
   string sId = StrRightFrom(key, "."); if (!StrIsDigits(sId))      return(_EMPTY(catch("ReadStatus.HistoryRecord(2)  "+ instance.name +" illegal key format of history record: \""+ key +"\"", ERR_INVALID_FILE_FORMAT)));
   if (Explode(value, ",", values, NULL) != ArrayRange(history, 1)) return(_EMPTY(catch("ReadStatus.HistoryRecord(3)  "+ instance.name +" illegal number of fields in history record \""+ key +"\": "+ ArraySize(values) +" (expected "+ ArrayRange(history, 1) +")", ERR_INVALID_FILE_FORMAT)));

   int      ticket        = StrToInteger(values[H_TICKET        ]);
   int      fromTicket    = StrToInteger(values[H_FROM_TICKET   ]);
   int      toTicket      = StrToInteger(values[H_TO_TICKET     ]);
   int      type          = StrToInteger(values[H_TYPE          ]);
   double   lots          =  StrToDouble(values[H_LOTS          ]);
   double   part          =  StrToDouble(values[H_PART          ]);
   datetime openTime      = StrToInteger(values[H_OPENTIME      ]);
   double   openPrice     =  StrToDouble(values[H_OPENPRICE     ]);
   double   openPriceSig  =  StrToDouble(values[H_OPENPRICE_SIG ]);
   double   stopLoss      =  StrToDouble(values[H_STOPLOSS      ]);
   double   takeProfit    =  StrToDouble(values[H_TAKEPROFIT    ]);
   datetime closeTime     = StrToInteger(values[H_CLOSETIME     ]);
   double   closePrice    =  StrToDouble(values[H_CLOSEPRICE    ]);
   double   closePriceSig =  StrToDouble(values[H_CLOSEPRICE_SIG]);
   double   slippageP     =  StrToDouble(values[H_SLIPPAGE_P    ]);
   double   swapM         =  StrToDouble(values[H_SWAP_M        ]);
   double   commissionM   =  StrToDouble(values[H_COMMISSION_M  ]);
   double   grossProfitM  =  StrToDouble(values[H_GROSSPROFIT_M ]);
   double   netProfitM    =  StrToDouble(values[H_NETPROFIT_M   ]);
   double   netProfitP    =  StrToDouble(values[H_NETPROFIT_P   ]);
   double   runupP        =  StrToDouble(values[H_RUNUP_P       ]);
   double   rundownP      =  StrToDouble(values[H_RUNDOWN_P     ]);
   double   sigProfitP    =  StrToDouble(values[H_SIG_PROFIT_P  ]);
   double   sigRunupP     =  StrToDouble(values[H_SIG_RUNUP_P   ]);
   double   sigRundownP   =  StrToDouble(values[H_SIG_RUNDOWN_P ]);

   return(AddHistoryRecord(ticket, fromTicket, toTicket, type, lots, part, openTime, openPrice, openPriceSig, stopLoss, takeProfit, closeTime, closePrice, closePriceSig, slippageP, swapM, commissionM, grossProfitM, netProfitM, netProfitP, runupP, rundownP, sigProfitP, sigRunupP, sigRundownP));
}
