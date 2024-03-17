/**
 * Return a string representation of a history record.
 *
 * @param  int  index              - index of the record
 * @param  bool partial [optional] - whether the record is a partially closed position (default: no)
 * @param  bool compact [optional] - whether to return the record in compact format suitable for SaveStatus() (default: yes)
 *
 * @return string
 */
string HistoryRecordToStr(int index, bool partial=false, bool compact=true) {
   partial = partial!=0;
   compact = compact!=0;
   // result: ticket,fromTicket,toTicket,type,lots,part,openTime,openPrice,openPriceSig,stopLoss,takeProfit,closeTime,closePrice,closePriceSig,slippageP,swapM,commissionM,grossProfitM,netProfitM,netProfitP,runupP,rundownP,sigProfitP,sigRunupP,sigRundownP

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
      double   slippageP     = partialClose[index][H_SLIPPAGE_P    ];
      double   swapM         = partialClose[index][H_SWAP_M        ];
      double   commissionM   = partialClose[index][H_COMMISSION_M  ];
      double   grossProfitM  = partialClose[index][H_GROSSPROFIT_M ];
      double   netProfitM    = partialClose[index][H_NETPROFIT_M   ];
      double   netProfitP    = partialClose[index][H_NETPROFIT_P   ];
      double   runupP        = partialClose[index][H_RUNUP_P       ];
      double   rundownP      = partialClose[index][H_RUNDOWN_P     ];
      double   sigProfitP    = partialClose[index][H_SIG_PROFIT_P  ];
      double   sigRunupP     = partialClose[index][H_SIG_RUNUP_P   ];
      double   sigRundownP   = partialClose[index][H_SIG_RUNDOWN_P ];
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
      slippageP     = history[index][H_SLIPPAGE_P    ];
      swapM         = history[index][H_SWAP_M        ];
      commissionM   = history[index][H_COMMISSION_M  ];
      grossProfitM  = history[index][H_GROSSPROFIT_M ];
      netProfitM    = history[index][H_NETPROFIT_M   ];
      netProfitP    = history[index][H_NETPROFIT_P   ];
      runupP        = history[index][H_RUNUP_P       ];
      rundownP      = history[index][H_RUNDOWN_P     ];
      sigProfitP    = history[index][H_SIG_PROFIT_P  ];
      sigRunupP     = history[index][H_SIG_RUNUP_P   ];
      sigRundownP   = history[index][H_SIG_RUNDOWN_P ];
   }

   string sTicket        = ticket;
   string sFromTicket    = fromTicket;
   string sToTicket      = toTicket;
   string sType          = type;
   string sLots          = NumberToStr(lots, ".+");
   string sPart          = NumberToStr(part, ".+");
   string sOpenTime      = openTime;
   string sOpenPrice     = DoubleToStr(openPrice, Digits);
   string sOpenPriceSig  = DoubleToStr(openPriceSig, Digits);
   string sStopLoss      = DoubleToStr(stopLoss, Digits);
   string sTakeProfit    = DoubleToStr(takeProfit, Digits);
   string sCloseTime     = closeTime;
   string sClosePrice    = DoubleToStr(closePrice, Digits);
   string sClosePriceSig = DoubleToStr(closePriceSig, Digits);
   string sSlippageP     = DoubleToStr(slippageP, Digits);
   string sSwapM         = DoubleToStr(swapM, 2);
   string sCommissionM   = DoubleToStr(commissionM, 2);
   string sGrossProfitM  = DoubleToStr(grossProfitM, 2);
   string sNetProfitM    = DoubleToStr(netProfitM, 2);
   string sNetProfitP    = NumberToStr(netProfitP, ".1+");
   string sRunupP        = DoubleToStr(runupP, Digits);
   string sRundownP      = DoubleToStr(rundownP, Digits);
   string sSigProfitP    = NumberToStr(sigProfitP, ".1+");
   string sSigRunupP     = DoubleToStr(sigRunupP, Digits);
   string sSigRundownP   = DoubleToStr(sigRundownP, Digits);

   if (!compact) {
      string pUnitFormat = "."+ pDigits +"+";
      sTicket        = "{ticket="      + sTicket;
      sFromTicket    = "fromTicket="   + sFromTicket;
      sToTicket      = "toTicket="     + sToTicket;
      sType          = "type="         + OperationTypeDescription(type);
      sLots          = "lots="         + sLots;
      sPart          = "part="         + sPart;
      sOpenTime      = "openTime="     +   TimeToStr(openTime, TIME_FULL);
      sOpenPrice     = "openPrice="    + NumberToStr(openPrice,    PriceFormat);
      sOpenPriceSig  = "openPriceSig=" + NumberToStr(openPriceSig, PriceFormat);
      sStopLoss      = "stopLoss="     + NumberToStr(stopLoss,     PriceFormat);
      sTakeProfit    = "takeProfit="   + NumberToStr(takeProfit,   PriceFormat);
      sCloseTime     = "closeTime="    +   TimeToStr(closeTime, TIME_FULL);
      sClosePrice    = "closePrice="   + NumberToStr(closePrice,    PriceFormat);
      sClosePriceSig = "closePriceSig="+ NumberToStr(closePriceSig, PriceFormat);
      sSlippageP     = "slippageP="    + ifString(!slippageP,   "0", NumberToStr(slippageP/pUnit, pUnitFormat));
      sSwapM         = "swapM="        + ifString(!swapM,       "0", sSwapM);
      sCommissionM   = "commissionM="  + ifString(!commissionM, "0", sCommissionM);
      sGrossProfitM  = "grossProfitM=" + sGrossProfitM;
      sNetProfitM    = "netProfitM="   + sNetProfitM;
      sNetProfitP    = "netProfitP="   + NumberToStr(netProfitP /pUnit, pUnitFormat);
      sRunupP        = "runupP="       + NumberToStr(runupP     /pUnit, pUnitFormat);
      sRundownP      = "rundownP="     + NumberToStr(rundownP   /pUnit, pUnitFormat);
      sSigProfitP    = "sigProfitP="   + NumberToStr(sigProfitP /pUnit, pUnitFormat);
      sSigRunupP     = "sigRunupP="    + NumberToStr(sigRunupP  /pUnit, pUnitFormat);
      sSigRundownP   = "sigRundownP="  + NumberToStr(sigRundownP/pUnit, pUnitFormat) +"}";
   }

   return(StringConcatenate(sTicket, ",", sFromTicket, ",", sToTicket, ",", sType, ",", sLots, ",", sPart, ",", sOpenTime, ",",
                            sOpenPrice, ",", sOpenPriceSig, ",", sStopLoss, ",", sTakeProfit, ",", sCloseTime, ",", sClosePrice, ",",
                            sClosePriceSig, ",", sSlippageP, ",", sSwapM, ",", sCommissionM, ",", sGrossProfitM, ",", sNetProfitM, ",",
                            sNetProfitP, ",", sRunupP, ",", sRundownP, ",", sSigProfitP, ",",sSigRunupP, ",", sSigRundownP)
   );
}
