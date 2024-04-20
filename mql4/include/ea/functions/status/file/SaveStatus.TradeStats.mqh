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
   WriteIniString(file, section, "OpenProfit",                   /*double  */ StrPadRight(DoubleToStr(stats[METRIC_NET_MONEY][S_OPEN_PROFIT], 2), 25) +"; after all costs in "+ AccountCurrency());
   WriteIniString(file, section, "ClosedProfit",                 /*double  */ DoubleToStr(stats[METRIC_NET_MONEY][S_CLOSED_PROFIT   ], 2));
   WriteIniString(file, section, "TotalProfit",                  /*double  */ DoubleToStr(stats[METRIC_NET_MONEY][S_TOTAL_PROFIT    ], 2));
   WriteIniString(file, section, "MaxProfit",                    /*double  */ DoubleToStr(stats[METRIC_NET_MONEY][S_MAX_PROFIT      ], 2));
   WriteIniString(file, section, "MaxAbsDrawdown",               /*double  */ DoubleToStr(stats[METRIC_NET_MONEY][S_MAX_ABS_DRAWDOWN], 2));
   WriteIniString(file, section, "MaxRelDrawdown",               /*double  */ DoubleToStr(stats[METRIC_NET_MONEY][S_MAX_REL_DRAWDOWN], 2));
   WriteIniString(file, section, "ProfitFactor",                 /*double  */ DoubleToStr(stats[METRIC_NET_MONEY][S_PROFIT_FACTOR   ], 2));
   WriteIniString(file, section, "SharpeRatio",                  /*double  */ DoubleToStr(stats[METRIC_NET_MONEY][S_SHARPE_RATIO    ], 2));
   WriteIniString(file, section, "SortinoRatio",                 /*double  */ DoubleToStr(stats[METRIC_NET_MONEY][S_SORTINO_RATIO   ], 2));
   WriteIniString(file, section, "CalmarRatio",                  /*double  */ DoubleToStr(stats[METRIC_NET_MONEY][S_CALMAR_RATIO    ], 2) + separator);

   // [Stats: net in punits]
   section = "Stats: net in "+ spUnit;
   WriteIniString(file, section, "OpenProfit",                   /*double  */ StrPadRight(DoubleToStr(stats[METRIC_NET_UNITS][S_OPEN_PROFIT]/pUnit, pDigits), 25) +"; after all costs in "+ spUnit);
   WriteIniString(file, section, "ClosedProfit",                 /*double  */ DoubleToStr(stats[METRIC_NET_UNITS][S_CLOSED_PROFIT   ]/pUnit, pDigits));
   WriteIniString(file, section, "TotalProfit",                  /*double  */ DoubleToStr(stats[METRIC_NET_UNITS][S_TOTAL_PROFIT    ]/pUnit, pDigits));
   WriteIniString(file, section, "MaxProfit",                    /*double  */ DoubleToStr(stats[METRIC_NET_UNITS][S_MAX_PROFIT      ]/pUnit, pDigits));
   WriteIniString(file, section, "MaxAbsDrawdown",               /*double  */ DoubleToStr(stats[METRIC_NET_UNITS][S_MAX_ABS_DRAWDOWN]/pUnit, pDigits));
   WriteIniString(file, section, "MaxRelDrawdown",               /*double  */ DoubleToStr(stats[METRIC_NET_UNITS][S_MAX_REL_DRAWDOWN]/pUnit, pDigits));
   WriteIniString(file, section, "ProfitFactor",                 /*double  */ DoubleToStr(stats[METRIC_NET_UNITS][S_PROFIT_FACTOR   ], 2));
   WriteIniString(file, section, "SharpeRatio",                  /*double  */ DoubleToStr(stats[METRIC_NET_UNITS][S_SHARPE_RATIO    ], 2));
   WriteIniString(file, section, "SortinoRatio",                 /*double  */ DoubleToStr(stats[METRIC_NET_UNITS][S_SORTINO_RATIO   ], 2));
   WriteIniString(file, section, "CalmarRatio",                  /*double  */ DoubleToStr(stats[METRIC_NET_UNITS][S_CALMAR_RATIO    ], 2) + separator);

   WriteIniString(file, section, "trades",                       /*int     */ Round(stats[METRIC_NET_UNITS][S_TRADES]));
   WriteIniString(file, section, "trades.long",                  /*int     */ StrPadRight(Round(stats[METRIC_NET_UNITS][S_TRADES_LONG ]), 23) + StrPadLeft("("+ DoubleToStr(100 * stats[METRIC_NET_UNITS][S_TRADES_LONG_PCT  ], 1) +"%)", 8));
   WriteIniString(file, section, "trades.short",                 /*int     */ StrPadRight(Round(stats[METRIC_NET_UNITS][S_TRADES_SHORT]), 22) + StrPadLeft("("+ DoubleToStr(100 * stats[METRIC_NET_UNITS][S_TRADES_SHORT_PCT ], 1) +"%)", 8));
   WriteIniString(file, section, "trades.avgProfit",             /*double  */ DoubleToStr(stats[METRIC_NET_UNITS][S_TRADES_AVG_PROFIT  ]/pUnit, pDigits));
   WriteIniString(file, section, "trades.avgRunup",              /*double  */ DoubleToStr(stats[METRIC_NET_UNITS][S_TRADES_AVG_RUNUP   ]/pUnit, pDigits));
   WriteIniString(file, section, "trades.avgRundown",            /*double  */ DoubleToStr(stats[METRIC_NET_UNITS][S_TRADES_AVG_DRAWDOWN]/pUnit, pDigits) + separator);

   WriteIniString(file, section, "winners",                      /*int     */ StrPadRight(Round(stats[METRIC_NET_UNITS][S_WINNERS]),       27) + StrPadLeft("("+ DoubleToStr(100 * stats[METRIC_NET_UNITS][S_WINNERS_PCT      ], 1) +"%)", 8));
   WriteIniString(file, section, "winners.long",                 /*int     */ StrPadRight(Round(stats[METRIC_NET_UNITS][S_WINNERS_LONG ]), 22) + StrPadLeft("("+ DoubleToStr(100 * stats[METRIC_NET_UNITS][S_WINNERS_LONG_PCT ], 1) +"%)", 8));
   WriteIniString(file, section, "winners.short",                /*int     */ StrPadRight(Round(stats[METRIC_NET_UNITS][S_WINNERS_SHORT]), 21) + StrPadLeft("("+ DoubleToStr(100 * stats[METRIC_NET_UNITS][S_WINNERS_SHORT_PCT], 1) +"%)", 8));
   WriteIniString(file, section, "winners.grossProfit",          /*double  */ DoubleToStr(stats[METRIC_NET_UNITS][S_WINNERS_GROSS_PROFIT]/pUnit, pDigits));
   WriteIniString(file, section, "winners.avgProfit",            /*double  */ DoubleToStr(stats[METRIC_NET_UNITS][S_WINNERS_AVG_PROFIT  ]/pUnit, pDigits));
   WriteIniString(file, section, "winners.avgRunup",             /*double  */ DoubleToStr(stats[METRIC_NET_UNITS][S_WINNERS_AVG_RUNUP   ]/pUnit, pDigits));
   WriteIniString(file, section, "winners.avgRundown",           /*double  */ DoubleToStr(stats[METRIC_NET_UNITS][S_WINNERS_AVG_DRAWDOWN]/pUnit, pDigits));
   WriteIniString(file, section, "winners.maxConsecutive",       /*int     */ StrPadRight(Round(stats[METRIC_NET_UNITS][S_WINNERS_MAX_CONS_COUNT]),                      13) +"("+ TimeToStr(stats[METRIC_NET_UNITS][S_WINNERS_MAX_CONS_COUNT_FROM ]) +"-"+ TimeToStr(stats[METRIC_NET_UNITS][S_WINNERS_MAX_CONS_COUNT_TO ]) +", profit="+ DoubleToStr(stats[METRIC_NET_UNITS][S_WINNERS_MAX_CONS_COUNT_PROFIT]/pUnit, pDigits) +")");
   WriteIniString(file, section, "winners.maxConsecutiveProfit", /*double  */ StrPadRight(DoubleToStr(stats[METRIC_NET_UNITS][S_WINNERS_MAX_CONS_PROFIT]/pUnit, pDigits), 7) +"("+ TimeToStr(stats[METRIC_NET_UNITS][S_WINNERS_MAX_CONS_PROFIT_FROM]) +"-"+ TimeToStr(stats[METRIC_NET_UNITS][S_WINNERS_MAX_CONS_PROFIT_TO]) +", "+ Round(stats[METRIC_NET_UNITS][S_WINNERS_MAX_CONS_PROFIT_COUNT]) +" winners)"+ separator);

   WriteIniString(file, section, "losers",                       /*int     */ StrPadRight(Round(stats[METRIC_NET_UNITS][S_LOSERS]),       28) + StrPadLeft("("+ DoubleToStr(100 * stats[METRIC_NET_UNITS][S_LOSERS_PCT       ], 1) +"%)", 8));
   WriteIniString(file, section, "losers.long",                  /*int     */ StrPadRight(Round(stats[METRIC_NET_UNITS][S_LOSERS_LONG ]), 23) + StrPadLeft("("+ DoubleToStr(100 * stats[METRIC_NET_UNITS][S_LOSERS_LONG_PCT  ], 1) +"%)", 8));
   WriteIniString(file, section, "losers.short",                 /*int     */ StrPadRight(Round(stats[METRIC_NET_UNITS][S_LOSERS_SHORT]), 22) + StrPadLeft("("+ DoubleToStr(100 * stats[METRIC_NET_UNITS][S_LOSERS_SHORT_PCT ], 1) +"%)", 8));
   WriteIniString(file, section, "losers.grossLoss",             /*double  */ DoubleToStr(stats[METRIC_NET_UNITS][S_LOSERS_GROSS_LOSS  ]/pUnit, pDigits));
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
   WriteIniString(file, section, "OpenProfit",                   /*double  */ StrPadRight(DoubleToStr(stats[METRIC_SIG_UNITS][S_OPEN_PROFIT]/pUnit, pDigits), 25) +"; before spread/any costs in "+ spUnit);
   WriteIniString(file, section, "ClosedProfit",                 /*double  */ DoubleToStr(stats[METRIC_SIG_UNITS][S_CLOSED_PROFIT   ]/pUnit, pDigits));
   WriteIniString(file, section, "TotalProfit",                  /*double  */ DoubleToStr(stats[METRIC_SIG_UNITS][S_TOTAL_PROFIT    ]/pUnit, pDigits));
   WriteIniString(file, section, "MaxProfit",                    /*double  */ DoubleToStr(stats[METRIC_SIG_UNITS][S_MAX_PROFIT      ]/pUnit, pDigits));
   WriteIniString(file, section, "MaxAbsDrawdown",               /*double  */ DoubleToStr(stats[METRIC_SIG_UNITS][S_MAX_ABS_DRAWDOWN]/pUnit, pDigits));
   WriteIniString(file, section, "MaxRelDrawdown",               /*double  */ DoubleToStr(stats[METRIC_SIG_UNITS][S_MAX_REL_DRAWDOWN]/pUnit, pDigits));
   WriteIniString(file, section, "ProfitFactor",                 /*double  */ DoubleToStr(stats[METRIC_SIG_UNITS][S_PROFIT_FACTOR   ], 2));
   WriteIniString(file, section, "SharpeRatio",                  /*double  */ DoubleToStr(stats[METRIC_SIG_UNITS][S_SHARPE_RATIO    ], 2));
   WriteIniString(file, section, "SortinoRatio",                 /*double  */ DoubleToStr(stats[METRIC_SIG_UNITS][S_SORTINO_RATIO   ], 2));
   WriteIniString(file, section, "CalmarRatio",                  /*double  */ DoubleToStr(stats[METRIC_SIG_UNITS][S_CALMAR_RATIO    ], 2) + separator);

   WriteIniString(file, section, "trades",                       /*int     */ Round(stats[METRIC_SIG_UNITS][S_TRADES]));
   WriteIniString(file, section, "trades.long",                  /*int     */ StrPadRight(Round(stats[METRIC_SIG_UNITS][S_TRADES_LONG ]), 23) + StrPadLeft("("+ DoubleToStr(100 * stats[METRIC_SIG_UNITS][S_TRADES_LONG_PCT  ], 1) +"%)", 8));
   WriteIniString(file, section, "trades.short",                 /*int     */ StrPadRight(Round(stats[METRIC_SIG_UNITS][S_TRADES_SHORT]), 22) + StrPadLeft("("+ DoubleToStr(100 * stats[METRIC_SIG_UNITS][S_TRADES_SHORT_PCT ], 1) +"%)", 8));
   WriteIniString(file, section, "trades.avgProfit",             /*double  */ DoubleToStr(stats[METRIC_SIG_UNITS][S_TRADES_AVG_PROFIT  ]/pUnit, pDigits));
   WriteIniString(file, section, "trades.avgRunup",              /*double  */ DoubleToStr(stats[METRIC_SIG_UNITS][S_TRADES_AVG_RUNUP   ]/pUnit, pDigits));
   WriteIniString(file, section, "trades.avgRundown",            /*double  */ DoubleToStr(stats[METRIC_SIG_UNITS][S_TRADES_AVG_DRAWDOWN]/pUnit, pDigits) + separator);

   WriteIniString(file, section, "winners",                      /*int     */ StrPadRight(Round(stats[METRIC_SIG_UNITS][S_WINNERS]),       27) + StrPadLeft("("+ DoubleToStr(100 * stats[METRIC_SIG_UNITS][S_WINNERS_PCT      ], 1) +"%)", 8));
   WriteIniString(file, section, "winners.long",                 /*int     */ StrPadRight(Round(stats[METRIC_SIG_UNITS][S_WINNERS_LONG ]), 22) + StrPadLeft("("+ DoubleToStr(100 * stats[METRIC_SIG_UNITS][S_WINNERS_LONG_PCT ], 1) +"%)", 8));
   WriteIniString(file, section, "winners.short",                /*int     */ StrPadRight(Round(stats[METRIC_SIG_UNITS][S_WINNERS_SHORT]), 21) + StrPadLeft("("+ DoubleToStr(100 * stats[METRIC_SIG_UNITS][S_WINNERS_SHORT_PCT], 1) +"%)", 8));
   WriteIniString(file, section, "winners.grossProfit",          /*double  */ DoubleToStr(stats[METRIC_SIG_UNITS][S_WINNERS_GROSS_PROFIT]/pUnit, pDigits));
   WriteIniString(file, section, "winners.avgProfit",            /*double  */ DoubleToStr(stats[METRIC_SIG_UNITS][S_WINNERS_AVG_PROFIT  ]/pUnit, pDigits));
   WriteIniString(file, section, "winners.avgRunup",             /*double  */ DoubleToStr(stats[METRIC_SIG_UNITS][S_WINNERS_AVG_RUNUP   ]/pUnit, pDigits));
   WriteIniString(file, section, "winners.avgRundown",           /*double  */ DoubleToStr(stats[METRIC_SIG_UNITS][S_WINNERS_AVG_DRAWDOWN]/pUnit, pDigits));
   WriteIniString(file, section, "winners.maxConsecutive",       /*int     */ StrPadRight(Round(stats[METRIC_SIG_UNITS][S_WINNERS_MAX_CONS_COUNT]),                      13) +"("+ TimeToStr(stats[METRIC_SIG_UNITS][S_WINNERS_MAX_CONS_COUNT_FROM ]) +"-"+ TimeToStr(stats[METRIC_SIG_UNITS][S_WINNERS_MAX_CONS_COUNT_TO ]) +", profit="+ DoubleToStr(stats[METRIC_SIG_UNITS][S_WINNERS_MAX_CONS_COUNT_PROFIT]/pUnit, pDigits) +")");
   WriteIniString(file, section, "winners.maxConsecutiveProfit", /*double  */ StrPadRight(DoubleToStr(stats[METRIC_SIG_UNITS][S_WINNERS_MAX_CONS_PROFIT]/pUnit, pDigits), 7) +"("+ TimeToStr(stats[METRIC_SIG_UNITS][S_WINNERS_MAX_CONS_PROFIT_FROM]) +"-"+ TimeToStr(stats[METRIC_SIG_UNITS][S_WINNERS_MAX_CONS_PROFIT_TO]) +", "+ Round(stats[METRIC_SIG_UNITS][S_WINNERS_MAX_CONS_PROFIT_COUNT]) +" winners)"+ separator);

   WriteIniString(file, section, "losers",                       /*int     */ StrPadRight(Round(stats[METRIC_SIG_UNITS][S_LOSERS]),       28) + StrPadLeft("("+ DoubleToStr(100 * stats[METRIC_SIG_UNITS][S_LOSERS_PCT       ], 1) +"%)", 8));
   WriteIniString(file, section, "losers.long",                  /*int     */ StrPadRight(Round(stats[METRIC_SIG_UNITS][S_LOSERS_LONG ]), 23) + StrPadLeft("("+ DoubleToStr(100 * stats[METRIC_SIG_UNITS][S_LOSERS_LONG_PCT  ], 1) +"%)", 8));
   WriteIniString(file, section, "losers.short",                 /*int     */ StrPadRight(Round(stats[METRIC_SIG_UNITS][S_LOSERS_SHORT]), 22) + StrPadLeft("("+ DoubleToStr(100 * stats[METRIC_SIG_UNITS][S_LOSERS_SHORT_PCT ], 1) +"%)", 8));
   WriteIniString(file, section, "losers.grossLoss",             /*double  */ DoubleToStr(stats[METRIC_SIG_UNITS][S_LOSERS_GROSS_LOSS  ]/pUnit, pDigits));
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
