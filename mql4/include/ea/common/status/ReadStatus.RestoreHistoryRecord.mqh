/**
 * Parse the string representation of a closed order record and store the parsed data.
 *
 * @param  string key   - order key
 * @param  string value - order string to parse
 *
 * @return int - index the data record was inserted at or EMPTY (-1) in case of errors
 */
int ReadStatus.RestoreHistoryRecord(string key, string value) {
   if (IsLastError())                    return(EMPTY);
   if (!StrStartsWithI(key, "history.")) return(_EMPTY(catch("ReadStatus.RestoreHistoryRecord(1)  "+ instance.name +" illegal history record key "+ DoubleQuoteStr(key), ERR_INVALID_FILE_FORMAT)));

   // history.i=ticket,type,lots,openTime,openPrice,openPriceSynth,closeTime,closePrice,closePriceSynth,slippage,swap,commission,grossProfit,netProfit,netProfitP,runupP,drawdownP,synthProfitP,synthRunupP,synthDrawdownP
   string values[];
   string sId = StrRightFrom(key, ".", -1); if (!StrIsDigits(sId))  return(_EMPTY(catch("ReadStatus.RestoreHistoryRecord(2)  "+ instance.name +" illegal history record key "+ DoubleQuoteStr(key), ERR_INVALID_FILE_FORMAT)));
   if (Explode(value, ",", values, NULL) != ArrayRange(history, 1)) return(_EMPTY(catch("ReadStatus.RestoreHistoryRecord(3)  "+ instance.name +" illegal number of details ("+ ArraySize(values) +") in history record", ERR_INVALID_FILE_FORMAT)));

   int      ticket          = StrToInteger(values[H_TICKET          ]);
   int      type            = StrToInteger(values[H_TYPE            ]);
   double   lots            =  StrToDouble(values[H_LOTS            ]);
   datetime openTime        = StrToInteger(values[H_OPENTIME        ]);
   double   openPrice       =  StrToDouble(values[H_OPENPRICE       ]);
   double   openPriceSynth  =  StrToDouble(values[H_OPENPRICE_SYNTH ]);
   datetime closeTime       = StrToInteger(values[H_CLOSETIME       ]);
   double   closePrice      =  StrToDouble(values[H_CLOSEPRICE      ]);
   double   closePriceSynth =  StrToDouble(values[H_CLOSEPRICE_SYNTH]);
   double   slippage        =  StrToDouble(values[H_SLIPPAGE        ]);
   double   swap            =  StrToDouble(values[H_SWAP            ]);
   double   commission      =  StrToDouble(values[H_COMMISSION      ]);
   double   grossProfit     =  StrToDouble(values[H_GROSSPROFIT     ]);
   double   netProfit       =  StrToDouble(values[H_NETPROFIT       ]);
   double   netProfitP      =  StrToDouble(values[H_NETPROFIT_P     ]);
   double   runupP          =  StrToDouble(values[H_RUNUP_P         ]);
   double   drawdownP       =  StrToDouble(values[H_DRAWDOWN_P      ]);
   double   synthProfitP    =  StrToDouble(values[H_SYNTH_PROFIT_P  ]);
   double   synthRunupP     =  StrToDouble(values[H_SYNTH_RUNUP_P   ]);
   double   synthDrawdownP  =  StrToDouble(values[H_SYNTH_DRAWDOWN_P]);

   return(History.AddRecord(ticket, type, lots, openTime, openPrice, openPriceSynth, closeTime, closePrice, closePriceSynth, slippage, swap, commission, grossProfit, netProfit, netProfitP, runupP, drawdownP, synthProfitP, synthRunupP, synthDrawdownP));
}
