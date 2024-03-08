/**
 * Parse the string representation of a closed order record and store the parsed data.
 *
 * @param  string key   - order key
 * @param  string value - order string to parse
 *
 * @return int - index the data record was inserted at or EMPTY (-1) in case of errors
 */
int ReadStatus.HistoryRecord(string key, string value) {
   if (IsLastError())                    return(EMPTY);
   if (!StrStartsWithI(key, "history.")) return(_EMPTY(catch("ReadStatus.HistoryRecord(1)  "+ instance.name +" illegal history record key \""+ key +"\"", ERR_INVALID_FILE_FORMAT)));

   // history.i=ticket,type,lots,openTime,openPrice,openPriceSig,stopLoss,takeProfit,closeTime,closePrice,closePriceSig,slippage,swap,commission,grossProfit,netProfit,netProfitP,runupP,drawdownP,sigProfitP,sigRunupP,sigDrawdownP
   string values[];
   string sId = StrRightFrom(key, ".", -1); if (!StrIsDigits(sId))  return(_EMPTY(catch("ReadStatus.HistoryRecord(2)  "+ instance.name +" illegal key of history record: \""+ key +"\"", ERR_INVALID_FILE_FORMAT)));
   if (Explode(value, ",", values, NULL) != ArrayRange(history, 1)) return(_EMPTY(catch("ReadStatus.HistoryRecord(3)  "+ instance.name +" illegal number of fields in history record: "+ ArraySize(values), ERR_INVALID_FILE_FORMAT)));

   int      ticket        = StrToInteger(values[H_TICKET        ]);
   int      type          = StrToInteger(values[H_TYPE          ]);
   double   lots          =  StrToDouble(values[H_LOTS          ]);
   datetime openTime      = StrToInteger(values[H_OPENTIME      ]);
   double   openPrice     =  StrToDouble(values[H_OPENPRICE     ]);
   double   openPriceSig  =  StrToDouble(values[H_OPENPRICE_SIG ]);
   double   stopLoss      =  StrToDouble(values[H_STOPLOSS      ]);
   double   takeProfit    =  StrToDouble(values[H_TAKEPROFIT    ]);
   datetime closeTime     = StrToInteger(values[H_CLOSETIME     ]);
   double   closePrice    =  StrToDouble(values[H_CLOSEPRICE    ]);
   double   closePriceSig =  StrToDouble(values[H_CLOSEPRICE_SIG]);
   double   slippage      =  StrToDouble(values[H_SLIPPAGE      ]);
   double   swap          =  StrToDouble(values[H_SWAP          ]);
   double   commission    =  StrToDouble(values[H_COMMISSION    ]);
   double   grossProfit   =  StrToDouble(values[H_GROSSPROFIT   ]);
   double   netProfit     =  StrToDouble(values[H_NETPROFIT     ]);
   double   netProfitP    =  StrToDouble(values[H_NETPROFIT_P   ]);
   double   runupP        =  StrToDouble(values[H_RUNUP_P       ]);
   double   drawdownP     =  StrToDouble(values[H_DRAWDOWN_P    ]);
   double   sigProfitP    =  StrToDouble(values[H_SIG_PROFIT_P  ]);
   double   sigRunupP     =  StrToDouble(values[H_SIG_RUNUP_P   ]);
   double   sigDrawdownP  =  StrToDouble(values[H_SIG_DRAWDOWN_P]);

   return(AddHistoryRecord(ticket, type, lots, openTime, openPrice, openPriceSig, stopLoss, takeProfit, closeTime, closePrice, closePriceSig, slippage, swap, commission, grossProfit, netProfit, netProfitP, runupP, drawdownP, sigProfitP, sigRunupP, sigDrawdownP));
}
