/**
 * Return a string representation of a history record suitable for SaveStatus().
 *
 * @param  int index - index of the history record
 *
 * @return string
 */
string HistoryRecordToStr(int index) {
   // result: ticket,type,lots,openTime,openPrice,openPriceSynth,closeTime,closePrice,closePriceSynth,slippage,swap,commission,grossProfit,netProfit,netProfitP,runupP,drawdownP,synthProfitP,synthRunupP,synthDrawdownP

   int      ticket          = history[index][H_TICKET          ];
   int      type            = history[index][H_TYPE            ];
   double   lots            = history[index][H_LOTS            ];
   datetime openTime        = history[index][H_OPENTIME        ];
   double   openPrice       = history[index][H_OPENPRICE       ];
   double   openPriceSynth  = history[index][H_OPENPRICE_SYNTH ];
   datetime closeTime       = history[index][H_CLOSETIME       ];
   double   closePrice      = history[index][H_CLOSEPRICE      ];
   double   closePriceSynth = history[index][H_CLOSEPRICE_SYNTH];
   double   slippage        = history[index][H_SLIPPAGE        ];
   double   swap            = history[index][H_SWAP            ];
   double   commission      = history[index][H_COMMISSION      ];
   double   grossProfit     = history[index][H_GROSSPROFIT     ];
   double   netProfit       = history[index][H_NETPROFIT       ];
   double   netProfitP      = history[index][H_NETPROFIT_P     ];
   double   runupP          = history[index][H_RUNUP_P         ];
   double   drawdownP       = history[index][H_DRAWDOWN_P      ];
   double   synthProfitP    = history[index][H_SYNTH_PROFIT_P  ];
   double   synthRunupP     = history[index][H_SYNTH_RUNUP_P   ];
   double   synthDrawdownP  = history[index][H_SYNTH_DRAWDOWN_P];

   return(StringConcatenate(ticket, ",", type, ",", DoubleToStr(lots, 2), ",", openTime, ",", DoubleToStr(openPrice, Digits), ",", DoubleToStr(openPriceSynth, Digits), ",", closeTime, ",", DoubleToStr(closePrice, Digits), ",", DoubleToStr(closePriceSynth, Digits), ",", DoubleToStr(slippage, Digits), ",", DoubleToStr(swap, 2), ",", DoubleToStr(commission, 2), ",", DoubleToStr(grossProfit, 2), ",", DoubleToStr(netProfit, 2), ",", NumberToStr(netProfitP, ".1+"), ",", DoubleToStr(runupP, Digits), ",", DoubleToStr(drawdownP, Digits), ",", DoubleToStr(synthProfitP, Digits), ",", DoubleToStr(synthRunupP, Digits), ",", DoubleToStr(synthDrawdownP, Digits)));
}


