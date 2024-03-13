/**
 * Return a string representation of a history record suitable for SaveStatus().
 *
 * @param  int  index              - index of the record
 * @param  bool partial [optional] - whether the record is a partially closed position (default: no)
 *
 * @return string
 */
string HistoryRecordToStr(int index, bool partial = false) {
   partial = partial!=0;
   // result: ticket,fromTicket,toTicket,type,lots,part,openTime,openPrice,openPriceSig,stopLoss,takeProfit,closeTime,closePrice,closePriceSig,slippage,swap,commission,grossProfit,netProfit,netProfitP,runupP,drawdownP,sigProfitP,sigRunupP,sigDrawdownP

   if (partial) {
      int      ticket        = partialClose[index][H_TICKET        ];
      int      fromTicket    = partialClose[index][H_FROM_TICKET   ];
      int      toTicket      = partialClose[index][H_TO_TICKET     ];
      int      type          = partialClose[index][H_TYPE          ];
      double   lots          = partialClose[index][H_LOTS          ];
      double   part          = partialClose[index][H_PART          ];
      datetime openTime      = partialClose[index][H_OPENTIME      ];
      double   openPrice     = partialClose[index][H_OPENPRICE     ];
      double   openPriceSig  = partialClose[index][H_OPENPRICE_SIG ];
      double   stopLoss      = partialClose[index][H_STOPLOSS      ];
      double   takeProfit    = partialClose[index][H_TAKEPROFIT    ];
      datetime closeTime     = partialClose[index][H_CLOSETIME     ];
      double   closePrice    = partialClose[index][H_CLOSEPRICE    ];
      double   closePriceSig = partialClose[index][H_CLOSEPRICE_SIG];
      double   slippage      = partialClose[index][H_SLIPPAGE      ];
      double   swap          = partialClose[index][H_SWAP          ];
      double   commission    = partialClose[index][H_COMMISSION    ];
      double   grossProfit   = partialClose[index][H_GROSSPROFIT   ];
      double   netProfit     = partialClose[index][H_NETPROFIT     ];
      double   netProfitP    = partialClose[index][H_NETPROFIT_P   ];
      double   runupP        = partialClose[index][H_RUNUP_P       ];
      double   drawdownP     = partialClose[index][H_DRAWDOWN_P    ];
      double   sigProfitP    = partialClose[index][H_SIG_PROFIT_P  ];
      double   sigRunupP     = partialClose[index][H_SIG_RUNUP_P   ];
      double   sigDrawdownP  = partialClose[index][H_SIG_DRAWDOWN_P];
   }
   else {
      ticket        = history[index][H_TICKET        ];
      fromTicket    = history[index][H_FROM_TICKET   ];
      toTicket      = history[index][H_TO_TICKET     ];
      type          = history[index][H_TYPE          ];
      lots          = history[index][H_LOTS          ];
      part          = history[index][H_PART          ];
      openTime      = history[index][H_OPENTIME      ];
      openPrice     = history[index][H_OPENPRICE     ];
      openPriceSig  = history[index][H_OPENPRICE_SIG ];
      stopLoss      = history[index][H_STOPLOSS      ];
      takeProfit    = history[index][H_TAKEPROFIT    ];
      closeTime     = history[index][H_CLOSETIME     ];
      closePrice    = history[index][H_CLOSEPRICE    ];
      closePriceSig = history[index][H_CLOSEPRICE_SIG];
      slippage      = history[index][H_SLIPPAGE      ];
      swap          = history[index][H_SWAP          ];
      commission    = history[index][H_COMMISSION    ];
      grossProfit   = history[index][H_GROSSPROFIT   ];
      netProfit     = history[index][H_NETPROFIT     ];
      netProfitP    = history[index][H_NETPROFIT_P   ];
      runupP        = history[index][H_RUNUP_P       ];
      drawdownP     = history[index][H_DRAWDOWN_P    ];
      sigProfitP    = history[index][H_SIG_PROFIT_P  ];
      sigRunupP     = history[index][H_SIG_RUNUP_P   ];
      sigDrawdownP  = history[index][H_SIG_DRAWDOWN_P];
   }
   return(StringConcatenate(ticket, ",", fromTicket, ",", toTicket, ",", type, ",", DoubleToStr(lots, 2), ",", NumberToStr(part, ".+"), ",", openTime, ",", DoubleToStr(openPrice, Digits), ",", DoubleToStr(openPriceSig, Digits), ",", DoubleToStr(stopLoss, Digits), ",", DoubleToStr(takeProfit, Digits), ",", closeTime, ",", DoubleToStr(closePrice, Digits), ",", DoubleToStr(closePriceSig, Digits), ",", DoubleToStr(slippage, Digits), ",", DoubleToStr(swap, 2), ",", DoubleToStr(commission, 2), ",", DoubleToStr(grossProfit, 2), ",", DoubleToStr(netProfit, 2), ",", NumberToStr(netProfitP, ".1+"), ",", DoubleToStr(runupP, Digits), ",", DoubleToStr(drawdownP, Digits), ",", NumberToStr(sigProfitP, ".1+"), ",", DoubleToStr(sigRunupP, Digits), ",", DoubleToStr(sigDrawdownP, Digits)));
}
