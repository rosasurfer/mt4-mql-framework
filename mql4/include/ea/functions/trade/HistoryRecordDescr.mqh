/**
 * Return a human-readable representation of a history record.
 *
 * @param  int  index              - index of the record
 * @param  bool partial [optional] - whether the record is a partially closed position (default: no)
 *
 * @return string
 */
string HistoryRecordDescr(int index, bool partial = false) {
   partial = partial!=0;
   string str = HistoryRecordToStr(index, partial);
   string sValues[];
   if (Explode(str, ",", sValues, NULL) != ArrayRange(history, 1)) return(_EMPTY(catch("HistoryRecordDescr(1)  "+ instance.name +" illegal number of fields in history record: "+ ArraySize(sValues), ERR_RUNTIME_ERROR)));

   sValues[H_TICKET        ] = "ticket="       +                          sValues[H_TICKET        ];
   sValues[H_FROM_TICKET   ] = "fromTicket="   +                          sValues[H_FROM_TICKET   ];
   sValues[H_TO_TICKET     ] = "toTicket="     +                          sValues[H_TO_TICKET     ];
   sValues[H_TYPE          ] = "type="         + OperationTypeDescription(sValues[H_TYPE          ]);
   sValues[H_LOTS          ] = "lots="         +                          sValues[H_LOTS          ];
   sValues[H_PART          ] = "part="         +  NumberToStr(StrToDouble(sValues[H_PART          ]), ".1+");
   sValues[H_OPENTIME      ] = "openTime="     +   TimeToStr(StrToInteger(sValues[H_OPENTIME      ]), TIME_FULL);
   sValues[H_OPENPRICE     ] = "openPrice="    +  NumberToStr(StrToDouble(sValues[H_OPENPRICE     ]), PriceFormat);
   sValues[H_OPENPRICE_SIG ] = "openPriceSig=" +  NumberToStr(StrToDouble(sValues[H_OPENPRICE_SIG ]), PriceFormat);
   sValues[H_STOPLOSS      ] = "stopLoss="     +  NumberToStr(StrToDouble(sValues[H_STOPLOSS      ]), PriceFormat);
   sValues[H_TAKEPROFIT    ] = "takeProfit"    +  NumberToStr(StrToDouble(sValues[H_TAKEPROFIT    ]), PriceFormat);
   sValues[H_CLOSETIME     ] = "closeTime="    +   TimeToStr(StrToInteger(sValues[H_CLOSETIME     ]), TIME_FULL);
   sValues[H_CLOSEPRICE    ] = "closePrice="   +  NumberToStr(StrToDouble(sValues[H_CLOSEPRICE    ]), PriceFormat);
   sValues[H_CLOSEPRICE_SIG] = "closePriceSig="+  NumberToStr(StrToDouble(sValues[H_CLOSEPRICE_SIG]), PriceFormat);
   sValues[H_SLIPPAGE      ] = "slippage="     +  NumberToStr(StrToDouble(sValues[H_SLIPPAGE      ]), ".+");
   sValues[H_SWAP          ] = "swap="         +                          sValues[H_SWAP          ];
   sValues[H_COMMISSION    ] = "commission="   +                          sValues[H_COMMISSION    ];
   sValues[H_GROSSPROFIT   ] = "grossProfit="  +                          sValues[H_GROSSPROFIT   ];
   sValues[H_NETPROFIT     ] = "netProfit="    +                          sValues[H_NETPROFIT     ];
   sValues[H_NETPROFIT_P   ] = "netProfitP="   +                          sValues[H_NETPROFIT_P   ];
   sValues[H_RUNUP_P       ] = "runupP="       +                          sValues[H_RUNUP_P       ];
   sValues[H_DRAWDOWN_P    ] = "drawdownP="    +                          sValues[H_DRAWDOWN_P    ];
   sValues[H_SIG_PROFIT_P  ] = "sigProfitP="   +                          sValues[H_SIG_PROFIT_P  ];
   sValues[H_SIG_RUNUP_P   ] = "sigRunupP="    +                          sValues[H_SIG_RUNUP_P   ];
   sValues[H_SIG_DRAWDOWN_P] = "sigDrawdownP=" +                          sValues[H_SIG_DRAWDOWN_P];

   return("{"+ JoinStrings(sValues) +"}");
}
