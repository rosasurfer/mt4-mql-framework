/**
 * Write trade statistics to the status file.
 *
 * @param  string file       - status filename
 * @param  bool   fileExists - whether the status file exists
 *
 * @return bool - success status
 */
bool SaveStatus.TradeStats(string file, bool fileExists) {
   fileExists = fileExists!=0;

   string separator = "";
   if (!fileExists) separator = CRLF;                            // an empty line separator

   // [Stats: net in money]
   string section = "Stats: net in money";
   WriteIniString(file, section, "openProfit",                   /*double  */ StrPadRight(DoubleToStr(instance.openNetProfit, 2), 25) +"; after all costs in "+ AccountCurrency());
   WriteIniString(file, section, "closedProfit",                 /*double  */ DoubleToStr(instance.closedNetProfit, 2));
   WriteIniString(file, section, "totalProfit",                  /*double  */ DoubleToStr(instance.totalNetProfit, 2));
   WriteIniString(file, section, "maxProfit",                    /*double  */ DoubleToStr(instance.maxNetProfit, 2));
   WriteIniString(file, section, "maxDrawdown",                  /*double  */ DoubleToStr(instance.maxNetDrawdown, 2));
   WriteIniString(file, section, "grossProfit",                  /*double  */ DoubleToStr(stats[METRIC_NET_MONEY][S_WINNERS_GROSS_PROFIT], 2));
   WriteIniString(file, section, "grossLoss",                    /*double  */ DoubleToStr(stats[METRIC_NET_MONEY][S_LOSERS_GROSS_LOSS   ], 2) + separator);

   // [Stats: net in punits]
   section = "Stats: net in "+ spUnit;
   WriteIniString(file, section, "openProfit",                   /*double  */ StrPadRight(DoubleToStr(instance.openNetProfitP/pUnit, pDigits), 25) +"; after all costs in "+ spUnit);
   WriteIniString(file, section, "closedProfit",                 /*double  */ DoubleToStr(instance.closedNetProfitP/pUnit, pDigits));
   WriteIniString(file, section, "totalProfit",                  /*double  */ DoubleToStr(instance.totalNetProfitP /pUnit, pDigits));
   WriteIniString(file, section, "maxProfit",                    /*double  */ DoubleToStr(instance.maxNetProfitP   /pUnit, pDigits));
   WriteIniString(file, section, "maxDrawdown",                  /*double  */ DoubleToStr(instance.maxNetDrawdownP /pUnit, pDigits));
   WriteIniString(file, section, "grossProfit",                  /*double  */ DoubleToStr(stats[METRIC_NET_UNITS][S_WINNERS_GROSS_PROFIT]/pUnit, pDigits));
   WriteIniString(file, section, "grossLoss",                    /*double  */ DoubleToStr(stats[METRIC_NET_UNITS][S_LOSERS_GROSS_LOSS   ]/pUnit, pDigits));
   WriteIniString(file, section, "profitFactor",                 /*double  */ ifString(stats[METRIC_NET_UNITS][S_TRADES_PROFIT_FACTOR]==INT_MAX, "-", DoubleToStr(stats[METRIC_NET_UNITS][S_TRADES_PROFIT_FACTOR], 2)) + separator);

   WriteIniString(file, section, "trades",                       /*int     */ Round(stats[METRIC_NET_UNITS][S_TRADES]));
   WriteIniString(file, section, "trades.long",                  /*int     */ StrPadRight(Round(stats[METRIC_NET_UNITS][S_TRADES_LONG ]), 23) + StrPadLeft("("+ DoubleToStr(100 * stats[METRIC_NET_UNITS][S_TRADES_LONG_PCT  ], 1) +"%)", 8));
   WriteIniString(file, section, "trades.short",                 /*int     */ StrPadRight(Round(stats[METRIC_NET_UNITS][S_TRADES_SHORT]), 22) + StrPadLeft("("+ DoubleToStr(100 * stats[METRIC_NET_UNITS][S_TRADES_SHORT_PCT ], 1) +"%)", 8));
   WriteIniString(file, section, "trades.avgProfit",             /*double  */ DoubleToStr(stats[METRIC_NET_UNITS][S_TRADES_AVG_PROFIT  ]/pUnit, pDigits));
   WriteIniString(file, section, "trades.avgRunup",              /*double  */ DoubleToStr(stats[METRIC_NET_UNITS][S_TRADES_AVG_RUNUP   ]/pUnit, pDigits));
   WriteIniString(file, section, "trades.avgRundown",            /*double  */ DoubleToStr(stats[METRIC_NET_UNITS][S_TRADES_AVG_DRAWDOWN]/pUnit, pDigits) + separator);

   WriteIniString(file, section, "winners",                      /*int     */ StrPadRight(Round(stats[METRIC_NET_UNITS][S_WINNERS]),       27) + StrPadLeft("("+ DoubleToStr(100 * stats[METRIC_NET_UNITS][S_WINNERS_PCT      ], 1) +"%)", 8));
   WriteIniString(file, section, "winners.long",                 /*int     */ StrPadRight(Round(stats[METRIC_NET_UNITS][S_WINNERS_LONG ]), 22) + StrPadLeft("("+ DoubleToStr(100 * stats[METRIC_NET_UNITS][S_WINNERS_LONG_PCT ], 1) +"%)", 8));
   WriteIniString(file, section, "winners.short",                /*int     */ StrPadRight(Round(stats[METRIC_NET_UNITS][S_WINNERS_SHORT]), 21) + StrPadLeft("("+ DoubleToStr(100 * stats[METRIC_NET_UNITS][S_WINNERS_SHORT_PCT], 1) +"%)", 8));
   WriteIniString(file, section, "winners.avgProfit",            /*double  */ DoubleToStr(stats[METRIC_NET_UNITS][S_WINNERS_AVG_PROFIT  ]/pUnit, pDigits));
   WriteIniString(file, section, "winners.avgRunup",             /*double  */ DoubleToStr(stats[METRIC_NET_UNITS][S_WINNERS_AVG_RUNUP   ]/pUnit, pDigits));
   WriteIniString(file, section, "winners.avgRundown",           /*double  */ DoubleToStr(stats[METRIC_NET_UNITS][S_WINNERS_AVG_DRAWDOWN]/pUnit, pDigits));
   WriteIniString(file, section, "winners.maxConsecutive",       /*int     */ StrPadRight(Round(stats[METRIC_NET_UNITS][S_WINNERS_MAX_CONS_COUNT]),                      13) +"("+ TimeToStr(stats[METRIC_NET_UNITS][S_WINNERS_MAX_CONS_COUNT_FROM ]) +"-"+ TimeToStr(stats[METRIC_NET_UNITS][S_WINNERS_MAX_CONS_COUNT_TO ]) +", profit="+ DoubleToStr(stats[METRIC_NET_UNITS][S_WINNERS_MAX_CONS_COUNT_PROFIT]/pUnit, pDigits) +")");
   WriteIniString(file, section, "winners.maxConsecutiveProfit", /*double  */ StrPadRight(DoubleToStr(stats[METRIC_NET_UNITS][S_WINNERS_MAX_CONS_PROFIT]/pUnit, pDigits), 7) +"("+ TimeToStr(stats[METRIC_NET_UNITS][S_WINNERS_MAX_CONS_PROFIT_FROM]) +"-"+ TimeToStr(stats[METRIC_NET_UNITS][S_WINNERS_MAX_CONS_PROFIT_TO]) +", "+ Round(stats[METRIC_NET_UNITS][S_WINNERS_MAX_CONS_PROFIT_COUNT]) +" winners)"+ separator);

   WriteIniString(file, section, "losers",                       /*int     */ StrPadRight(Round(stats[METRIC_NET_UNITS][S_LOSERS]),       28) + StrPadLeft("("+ DoubleToStr(100 * stats[METRIC_NET_UNITS][S_LOSERS_PCT       ], 1) +"%)", 8));
   WriteIniString(file, section, "losers.long",                  /*int     */ StrPadRight(Round(stats[METRIC_NET_UNITS][S_LOSERS_LONG ]), 23) + StrPadLeft("("+ DoubleToStr(100 * stats[METRIC_NET_UNITS][S_LOSERS_LONG_PCT  ], 1) +"%)", 8));
   WriteIniString(file, section, "losers.short",                 /*int     */ StrPadRight(Round(stats[METRIC_NET_UNITS][S_LOSERS_SHORT]), 22) + StrPadLeft("("+ DoubleToStr(100 * stats[METRIC_NET_UNITS][S_LOSERS_SHORT_PCT ], 1) +"%)", 8));
   WriteIniString(file, section, "losers.avgLoss",               /*double  */ DoubleToStr(stats[METRIC_NET_UNITS][S_LOSERS_AVG_LOSS    ]/pUnit, pDigits));
   WriteIniString(file, section, "losers.avgRunup",              /*double  */ DoubleToStr(stats[METRIC_NET_UNITS][S_LOSERS_AVG_RUNUP   ]/pUnit, pDigits));
   WriteIniString(file, section, "losers.avgRundown",            /*double  */ DoubleToStr(stats[METRIC_NET_UNITS][S_LOSERS_AVG_DRAWDOWN]/pUnit, pDigits));
   WriteIniString(file, section, "losers.maxConsecutive",        /*int     */ StrPadRight(Round(stats[METRIC_NET_UNITS][S_LOSERS_MAX_CONS_COUNT]),                     14) +"("+ TimeToStr(stats[METRIC_NET_UNITS][S_LOSERS_MAX_CONS_COUNT_FROM]) +"-"+ TimeToStr(stats[METRIC_NET_UNITS][S_LOSERS_MAX_CONS_COUNT_TO]) +", loss="+ DoubleToStr(stats[METRIC_NET_UNITS][S_LOSERS_MAX_CONS_COUNT_LOSS]/pUnit, pDigits) +")");
   WriteIniString(file, section, "losers.maxConsecutiveLoss",    /*double  */ StrPadRight(DoubleToStr(stats[METRIC_NET_UNITS][S_LOSERS_MAX_CONS_LOSS]/pUnit, pDigits), 10) +"("+ TimeToStr(stats[METRIC_NET_UNITS][S_LOSERS_MAX_CONS_LOSS_FROM ]) +"-"+ TimeToStr(stats[METRIC_NET_UNITS][S_LOSERS_MAX_CONS_LOSS_TO ]) +", "+ Round(stats[METRIC_NET_UNITS][S_LOSERS_MAX_CONS_LOSS_COUNT]) +" losers)"+ separator);

   int scratch = Round(stats[METRIC_NET_UNITS][S_SCRATCH]);
   if (!scratch) {
      WriteIniString(file, section, "scratch",                   /*int     */ scratch + separator);
   }
   else {
      WriteIniString(file, section, "scratch",                   /*int     */ StrPadRight(scratch,                                         27) + StrPadLeft("("+ DoubleToStr(100 * stats[METRIC_NET_UNITS][S_SCRATCH_PCT      ], 1) +"%)", 8));
      WriteIniString(file, section, "scratch.long",              /*int     */ StrPadRight(Round(stats[METRIC_NET_UNITS][S_SCRATCH_LONG ]), 22) + StrPadLeft("("+ DoubleToStr(100 * stats[METRIC_NET_UNITS][S_SCRATCH_LONG_PCT ], 1) +"%)", 8));
      WriteIniString(file, section, "scratch.short",             /*int     */ StrPadRight(Round(stats[METRIC_NET_UNITS][S_SCRATCH_SHORT]), 21) + StrPadLeft("("+ DoubleToStr(100 * stats[METRIC_NET_UNITS][S_SCRATCH_SHORT_PCT], 1) +"%)", 8) + separator);
   }

   // [Stats: signal in punits]
   section = "Stats: signal in "+ spUnit;
   WriteIniString(file, section, "openProfit",                   /*double  */ StrPadRight(DoubleToStr(instance.openSigProfitP/pUnit, pDigits), 25) +"; before spread/any costs in "+ spUnit);
   WriteIniString(file, section, "closedProfit",                 /*double  */ DoubleToStr(instance.closedSigProfitP/pUnit, pDigits));
   WriteIniString(file, section, "totalProfit",                  /*double  */ DoubleToStr(instance.totalSigProfitP /pUnit, pDigits));
   WriteIniString(file, section, "maxProfit",                    /*double  */ DoubleToStr(instance.maxSigProfitP   /pUnit, pDigits));
   WriteIniString(file, section, "maxDrawdown",                  /*double  */ DoubleToStr(instance.maxSigDrawdownP /pUnit, pDigits));
   WriteIniString(file, section, "grossProfit",                  /*double  */ DoubleToStr(stats[METRIC_SIG_UNITS][S_WINNERS_GROSS_PROFIT]/pUnit, pDigits));
   WriteIniString(file, section, "grossLoss",                    /*double  */ DoubleToStr(stats[METRIC_SIG_UNITS][S_LOSERS_GROSS_LOSS   ]/pUnit, pDigits));
   WriteIniString(file, section, "profitFactor",                 /*double  */ ifString(stats[METRIC_SIG_UNITS][S_TRADES_PROFIT_FACTOR]==INT_MAX, "-", DoubleToStr(stats[METRIC_SIG_UNITS][S_TRADES_PROFIT_FACTOR], 2)) + separator);

   WriteIniString(file, section, "trades",                       /*int     */ Round(stats[METRIC_SIG_UNITS][S_TRADES]));
   WriteIniString(file, section, "trades.long",                  /*int     */ StrPadRight(Round(stats[METRIC_SIG_UNITS][S_TRADES_LONG ]), 23) + StrPadLeft("("+ DoubleToStr(100 * stats[METRIC_SIG_UNITS][S_TRADES_LONG_PCT  ], 1) +"%)", 8));
   WriteIniString(file, section, "trades.short",                 /*int     */ StrPadRight(Round(stats[METRIC_SIG_UNITS][S_TRADES_SHORT]), 22) + StrPadLeft("("+ DoubleToStr(100 * stats[METRIC_SIG_UNITS][S_TRADES_SHORT_PCT ], 1) +"%)", 8));
   WriteIniString(file, section, "trades.avgProfit",             /*double  */ DoubleToStr(stats[METRIC_SIG_UNITS][S_TRADES_AVG_PROFIT  ]/pUnit, pDigits));
   WriteIniString(file, section, "trades.avgRunup",              /*double  */ DoubleToStr(stats[METRIC_SIG_UNITS][S_TRADES_AVG_RUNUP   ]/pUnit, pDigits));
   WriteIniString(file, section, "trades.avgRundown",            /*double  */ DoubleToStr(stats[METRIC_SIG_UNITS][S_TRADES_AVG_DRAWDOWN]/pUnit, pDigits) + separator);

   WriteIniString(file, section, "winners",                      /*int     */ StrPadRight(Round(stats[METRIC_SIG_UNITS][S_WINNERS]),       27) + StrPadLeft("("+ DoubleToStr(100 * stats[METRIC_SIG_UNITS][S_WINNERS_PCT      ], 1) +"%)", 8));
   WriteIniString(file, section, "winners.long",                 /*int     */ StrPadRight(Round(stats[METRIC_SIG_UNITS][S_WINNERS_LONG ]), 22) + StrPadLeft("("+ DoubleToStr(100 * stats[METRIC_SIG_UNITS][S_WINNERS_LONG_PCT ], 1) +"%)", 8));
   WriteIniString(file, section, "winners.short",                /*int     */ StrPadRight(Round(stats[METRIC_SIG_UNITS][S_WINNERS_SHORT]), 21) + StrPadLeft("("+ DoubleToStr(100 * stats[METRIC_SIG_UNITS][S_WINNERS_SHORT_PCT], 1) +"%)", 8));
   WriteIniString(file, section, "winners.avgProfit",            /*double  */ DoubleToStr(stats[METRIC_SIG_UNITS][S_WINNERS_AVG_PROFIT  ]/pUnit, pDigits));
   WriteIniString(file, section, "winners.avgRunup",             /*double  */ DoubleToStr(stats[METRIC_SIG_UNITS][S_WINNERS_AVG_RUNUP   ]/pUnit, pDigits));
   WriteIniString(file, section, "winners.avgRundown",           /*double  */ DoubleToStr(stats[METRIC_SIG_UNITS][S_WINNERS_AVG_DRAWDOWN]/pUnit, pDigits));
   WriteIniString(file, section, "winners.maxConsecutive",       /*int     */ StrPadRight(Round(stats[METRIC_SIG_UNITS][S_WINNERS_MAX_CONS_COUNT]),                      13) +"("+ TimeToStr(stats[METRIC_SIG_UNITS][S_WINNERS_MAX_CONS_COUNT_FROM ]) +"-"+ TimeToStr(stats[METRIC_SIG_UNITS][S_WINNERS_MAX_CONS_COUNT_TO ]) +", profit="+ DoubleToStr(stats[METRIC_SIG_UNITS][S_WINNERS_MAX_CONS_COUNT_PROFIT]/pUnit, pDigits) +")");
   WriteIniString(file, section, "winners.maxConsecutiveProfit", /*double  */ StrPadRight(DoubleToStr(stats[METRIC_SIG_UNITS][S_WINNERS_MAX_CONS_PROFIT]/pUnit, pDigits), 7) +"("+ TimeToStr(stats[METRIC_SIG_UNITS][S_WINNERS_MAX_CONS_PROFIT_FROM]) +"-"+ TimeToStr(stats[METRIC_SIG_UNITS][S_WINNERS_MAX_CONS_PROFIT_TO]) +", "+ Round(stats[METRIC_SIG_UNITS][S_WINNERS_MAX_CONS_PROFIT_COUNT]) +" winners)"+ separator);

   WriteIniString(file, section, "losers",                       /*int     */ StrPadRight(Round(stats[METRIC_SIG_UNITS][S_LOSERS]),       28) + StrPadLeft("("+ DoubleToStr(100 * stats[METRIC_SIG_UNITS][S_LOSERS_PCT       ], 1) +"%)", 8));
   WriteIniString(file, section, "losers.long",                  /*int     */ StrPadRight(Round(stats[METRIC_SIG_UNITS][S_LOSERS_LONG ]), 23) + StrPadLeft("("+ DoubleToStr(100 * stats[METRIC_SIG_UNITS][S_LOSERS_LONG_PCT  ], 1) +"%)", 8));
   WriteIniString(file, section, "losers.short",                 /*int     */ StrPadRight(Round(stats[METRIC_SIG_UNITS][S_LOSERS_SHORT]), 22) + StrPadLeft("("+ DoubleToStr(100 * stats[METRIC_SIG_UNITS][S_LOSERS_SHORT_PCT ], 1) +"%)", 8));
   WriteIniString(file, section, "losers.avgLoss",               /*double  */ DoubleToStr(stats[METRIC_SIG_UNITS][S_LOSERS_AVG_LOSS    ]/pUnit, pDigits));
   WriteIniString(file, section, "losers.avgRunup",              /*double  */ DoubleToStr(stats[METRIC_SIG_UNITS][S_LOSERS_AVG_RUNUP   ]/pUnit, pDigits));
   WriteIniString(file, section, "losers.avgRundown",            /*double  */ DoubleToStr(stats[METRIC_SIG_UNITS][S_LOSERS_AVG_DRAWDOWN]/pUnit, pDigits));
   WriteIniString(file, section, "losers.maxConsecutive",        /*int     */ StrPadRight(Round(stats[METRIC_SIG_UNITS][S_LOSERS_MAX_CONS_COUNT]),                     14) +"("+ TimeToStr(stats[METRIC_SIG_UNITS][S_LOSERS_MAX_CONS_COUNT_FROM]) +"-"+ TimeToStr(stats[METRIC_SIG_UNITS][S_LOSERS_MAX_CONS_COUNT_TO]) +", loss="+ DoubleToStr(stats[METRIC_SIG_UNITS][S_LOSERS_MAX_CONS_COUNT_LOSS]/pUnit, pDigits) +")");
   WriteIniString(file, section, "losers.maxConsecutiveLoss",    /*double  */ StrPadRight(DoubleToStr(stats[METRIC_SIG_UNITS][S_LOSERS_MAX_CONS_LOSS]/pUnit, pDigits), 10) +"("+ TimeToStr(stats[METRIC_SIG_UNITS][S_LOSERS_MAX_CONS_LOSS_FROM ]) +"-"+ TimeToStr(stats[METRIC_SIG_UNITS][S_LOSERS_MAX_CONS_LOSS_TO ]) +", "+ Round(stats[METRIC_SIG_UNITS][S_LOSERS_MAX_CONS_LOSS_COUNT]) +" losers)"+ separator);

   scratch = Round(stats[METRIC_SIG_UNITS][S_SCRATCH]);
   if (!scratch) {
      WriteIniString(file, section, "scratch",                   /*int     */ scratch + separator);
   }
   else {
      WriteIniString(file, section, "scratch",                   /*int     */ StrPadRight(scratch,                                         27) + StrPadLeft("("+ DoubleToStr(100 * stats[METRIC_SIG_UNITS][S_SCRATCH_PCT      ], 1) +"%)", 8));
      WriteIniString(file, section, "scratch.long",              /*int     */ StrPadRight(Round(stats[METRIC_SIG_UNITS][S_SCRATCH_LONG ]), 22) + StrPadLeft("("+ DoubleToStr(100 * stats[METRIC_SIG_UNITS][S_SCRATCH_LONG_PCT ], 1) +"%)", 8));
      WriteIniString(file, section, "scratch.short",             /*int     */ StrPadRight(Round(stats[METRIC_SIG_UNITS][S_SCRATCH_SHORT]), 21) + StrPadLeft("("+ DoubleToStr(100 * stats[METRIC_SIG_UNITS][S_SCRATCH_SHORT_PCT], 1) +"%)", 8) + separator);
   }
   return(!catch("SaveStatus.TradeStats(1)"));
}
