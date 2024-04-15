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
   if (!fileExists) separator = CRLF;                   // an empty line separator

   // [Stats: net in money]
   string section = "Stats: net in money";
   WriteIniString(file, section, "openProfit",          /*double  */ StrPadRight(DoubleToStr(instance.openNetProfit, 2), 21)              +"; after all costs in "+ AccountCurrency());
   WriteIniString(file, section, "closedProfit",        /*double  */ DoubleToStr(instance.closedNetProfit, 2));
   WriteIniString(file, section, "totalProfit",         /*double  */ DoubleToStr(instance.totalNetProfit, 2));
   WriteIniString(file, section, "maxProfit",           /*double  */ DoubleToStr(instance.maxNetProfit, 2));
   WriteIniString(file, section, "maxDrawdown",         /*double  */ DoubleToStr(instance.maxNetDrawdown, 2) + separator);

   // [Stats: net in punits]
   section = "Stats: net in "+ spUnit;
   WriteIniString(file, section, "openProfit",          /*double  */ StrPadRight(DoubleToStr(instance.openNetProfitP/pUnit, pDigits), 21) +"; after all costs in "+ spUnit);
   WriteIniString(file, section, "closedProfit",        /*double  */ DoubleToStr(instance.closedNetProfitP/pUnit, pDigits));
   WriteIniString(file, section, "totalProfit",         /*double  */ DoubleToStr(instance.totalNetProfitP /pUnit, pDigits));
   WriteIniString(file, section, "maxProfit",           /*double  */ DoubleToStr(instance.maxNetProfitP   /pUnit, pDigits));
   WriteIniString(file, section, "maxDrawdown",         /*double  */ DoubleToStr(instance.maxNetDrawdownP /pUnit, pDigits));
   WriteIniString(file, section, "profitFactor",        /*double  */ ifString(stats[METRIC_NET_UNITS][S_TRADES_PROFIT_FACTOR]==INT_MAX, "-", DoubleToStr(stats[METRIC_NET_UNITS][S_TRADES_PROFIT_FACTOR], 2)) + separator);

   WriteIniString(file, section, "trades",              /*double  */ Round(stats[METRIC_NET_UNITS][S_TRADES]));
   WriteIniString(file, section, "trades.long",         /*double  */ StrPadRight(Round(stats[METRIC_NET_UNITS][S_TRADES_LONG ]), 19) + StrPadLeft("("+ DoubleToStr(100 * stats[METRIC_NET_UNITS][S_TRADES_LONG_PCT  ], 1) +"%)", 8));
   WriteIniString(file, section, "trades.short",        /*double  */ StrPadRight(Round(stats[METRIC_NET_UNITS][S_TRADES_SHORT]), 18) + StrPadLeft("("+ DoubleToStr(100 * stats[METRIC_NET_UNITS][S_TRADES_SHORT_PCT ], 1) +"%)", 8));
   WriteIniString(file, section, "trades.avgProfit",    /*double  */ DoubleToStr(stats[METRIC_NET_UNITS][S_TRADES_AVG_PROFIT  ]/pUnit, pDigits));
   WriteIniString(file, section, "trades.avgRunup",     /*double  */ DoubleToStr(stats[METRIC_NET_UNITS][S_TRADES_AVG_RUNUP   ]/pUnit, pDigits));
   WriteIniString(file, section, "trades.avgRundown",   /*double  */ DoubleToStr(stats[METRIC_NET_UNITS][S_TRADES_AVG_DRAWDOWN]/pUnit, pDigits) + separator);

   WriteIniString(file, section, "winners",             /*double  */ StrPadRight(Round(stats[METRIC_NET_UNITS][S_WINNERS]),       23) + StrPadLeft("("+ DoubleToStr(100 * stats[METRIC_NET_UNITS][S_WINNERS_PCT      ], 1) +"%)", 8));
   WriteIniString(file, section, "winners.long",        /*double  */ StrPadRight(Round(stats[METRIC_NET_UNITS][S_WINNERS_LONG ]), 18) + StrPadLeft("("+ DoubleToStr(100 * stats[METRIC_NET_UNITS][S_WINNERS_LONG_PCT ], 1) +"%)", 8));
   WriteIniString(file, section, "winners.short",       /*double  */ StrPadRight(Round(stats[METRIC_NET_UNITS][S_WINNERS_SHORT]), 17) + StrPadLeft("("+ DoubleToStr(100 * stats[METRIC_NET_UNITS][S_WINNERS_SHORT_PCT], 1) +"%)", 8));
   WriteIniString(file, section, "winners.totalProfit", /*double  */ DoubleToStr(stats[METRIC_NET_UNITS][S_WINNERS_TOTAL_PROFIT]/pUnit, pDigits));
   WriteIniString(file, section, "winners.avgProfit",   /*double  */ DoubleToStr(stats[METRIC_NET_UNITS][S_WINNERS_AVG_PROFIT  ]/pUnit, pDigits));
   WriteIniString(file, section, "winners.avgRunup",    /*double  */ DoubleToStr(stats[METRIC_NET_UNITS][S_WINNERS_AVG_RUNUP   ]/pUnit, pDigits));
   WriteIniString(file, section, "winners.avgRundown",  /*double  */ DoubleToStr(stats[METRIC_NET_UNITS][S_WINNERS_AVG_DRAWDOWN]/pUnit, pDigits) + separator);

   WriteIniString(file, section, "losers",              /*double  */ StrPadRight(Round(stats[METRIC_NET_UNITS][S_LOSERS]),       24) + StrPadLeft("("+ DoubleToStr(100 * stats[METRIC_NET_UNITS][S_LOSERS_PCT       ], 1) +"%)", 8));
   WriteIniString(file, section, "losers.long",         /*double  */ StrPadRight(Round(stats[METRIC_NET_UNITS][S_LOSERS_LONG ]), 19) + StrPadLeft("("+ DoubleToStr(100 * stats[METRIC_NET_UNITS][S_LOSERS_LONG_PCT  ], 1) +"%)", 8));
   WriteIniString(file, section, "losers.short",        /*double  */ StrPadRight(Round(stats[METRIC_NET_UNITS][S_LOSERS_SHORT]), 18) + StrPadLeft("("+ DoubleToStr(100 * stats[METRIC_NET_UNITS][S_LOSERS_SHORT_PCT ], 1) +"%)", 8));
   WriteIniString(file, section, "losers.totalLoss",    /*double  */ DoubleToStr(stats[METRIC_NET_UNITS][S_LOSERS_TOTAL_LOSS  ]/pUnit, pDigits));
   WriteIniString(file, section, "losers.avgLoss",      /*double  */ DoubleToStr(stats[METRIC_NET_UNITS][S_LOSERS_AVG_LOSS    ]/pUnit, pDigits));
   WriteIniString(file, section, "losers.avgRunup",     /*double  */ DoubleToStr(stats[METRIC_NET_UNITS][S_LOSERS_AVG_RUNUP   ]/pUnit, pDigits));
   WriteIniString(file, section, "losers.avgRundown",   /*double  */ DoubleToStr(stats[METRIC_NET_UNITS][S_LOSERS_AVG_DRAWDOWN]/pUnit, pDigits) + separator);

   int scratch = Round(stats[METRIC_NET_UNITS][S_SCRATCH]);
   if (!scratch) {
      WriteIniString(file, section, "scratch",          /*int     */ scratch + separator);
   }
   else {
      WriteIniString(file, section, "scratch",          /*int     */ StrPadRight(scratch,                                         23) + StrPadLeft("("+ DoubleToStr(100 * stats[METRIC_NET_UNITS][S_SCRATCH_PCT      ], 1) +"%)", 8));
      WriteIniString(file, section, "scratch.long",     /*double  */ StrPadRight(Round(stats[METRIC_NET_UNITS][S_SCRATCH_LONG ]), 18) + StrPadLeft("("+ DoubleToStr(100 * stats[METRIC_NET_UNITS][S_SCRATCH_LONG_PCT ], 1) +"%)", 8));
      WriteIniString(file, section, "scratch.short",    /*double  */ StrPadRight(Round(stats[METRIC_NET_UNITS][S_SCRATCH_SHORT]), 17) + StrPadLeft("("+ DoubleToStr(100 * stats[METRIC_NET_UNITS][S_SCRATCH_SHORT_PCT], 1) +"%)", 8) + separator);
   }

   // [Stats: signal in punits]
   section = "Stats: signal in "+ spUnit;
   WriteIniString(file, section, "openProfit",          /*double  */ StrPadRight(DoubleToStr(instance.openSigProfitP/pUnit, pDigits), 21) +"; before spread/any costs in "+ spUnit);
   WriteIniString(file, section, "closedProfit",        /*double  */ DoubleToStr(instance.closedSigProfitP/pUnit, pDigits));
   WriteIniString(file, section, "totalProfit",         /*double  */ DoubleToStr(instance.totalSigProfitP /pUnit, pDigits));
   WriteIniString(file, section, "maxProfit",           /*double  */ DoubleToStr(instance.maxSigProfitP   /pUnit, pDigits));
   WriteIniString(file, section, "maxDrawdown",         /*double  */ DoubleToStr(instance.maxSigDrawdownP /pUnit, pDigits));
   WriteIniString(file, section, "profitFactor",        /*double  */ ifString(stats[METRIC_SIG_UNITS][S_TRADES_PROFIT_FACTOR]==INT_MAX, "-", DoubleToStr(stats[METRIC_SIG_UNITS][S_TRADES_PROFIT_FACTOR], 2)) + separator);

   WriteIniString(file, section, "trades",              /*double  */ Round(stats[METRIC_SIG_UNITS][S_TRADES]));
   WriteIniString(file, section, "trades.long",         /*double  */ StrPadRight(Round(stats[METRIC_SIG_UNITS][S_TRADES_LONG ]), 19) + StrPadLeft("("+ DoubleToStr(100 * stats[METRIC_SIG_UNITS][S_TRADES_LONG_PCT  ], 1) +"%)", 8));
   WriteIniString(file, section, "trades.short",        /*double  */ StrPadRight(Round(stats[METRIC_SIG_UNITS][S_TRADES_SHORT]), 18) + StrPadLeft("("+ DoubleToStr(100 * stats[METRIC_SIG_UNITS][S_TRADES_SHORT_PCT ], 1) +"%)", 8));
   WriteIniString(file, section, "trades.avgProfit",    /*double  */ DoubleToStr(stats[METRIC_SIG_UNITS][S_TRADES_AVG_PROFIT  ]/pUnit, pDigits));
   WriteIniString(file, section, "trades.avgRunup",     /*double  */ DoubleToStr(stats[METRIC_SIG_UNITS][S_TRADES_AVG_RUNUP   ]/pUnit, pDigits));
   WriteIniString(file, section, "trades.avgRundown",   /*double  */ DoubleToStr(stats[METRIC_SIG_UNITS][S_TRADES_AVG_DRAWDOWN]/pUnit, pDigits) + separator);

   WriteIniString(file, section, "winners",             /*double  */ StrPadRight(Round(stats[METRIC_SIG_UNITS][S_WINNERS]),       23) + StrPadLeft("("+ DoubleToStr(100 * stats[METRIC_SIG_UNITS][S_WINNERS_PCT      ], 1) +"%)", 8));
   WriteIniString(file, section, "winners.long",        /*double  */ StrPadRight(Round(stats[METRIC_SIG_UNITS][S_WINNERS_LONG ]), 18) + StrPadLeft("("+ DoubleToStr(100 * stats[METRIC_SIG_UNITS][S_WINNERS_LONG_PCT ], 1) +"%)", 8));
   WriteIniString(file, section, "winners.short",       /*double  */ StrPadRight(Round(stats[METRIC_SIG_UNITS][S_WINNERS_SHORT]), 17) + StrPadLeft("("+ DoubleToStr(100 * stats[METRIC_SIG_UNITS][S_WINNERS_SHORT_PCT], 1) +"%)", 8));
   WriteIniString(file, section, "winners.totalProfit", /*double  */ DoubleToStr(stats[METRIC_SIG_UNITS][S_WINNERS_TOTAL_PROFIT]/pUnit, pDigits));
   WriteIniString(file, section, "winners.avgProfit",   /*double  */ DoubleToStr(stats[METRIC_SIG_UNITS][S_WINNERS_AVG_PROFIT  ]/pUnit, pDigits));
   WriteIniString(file, section, "winners.avgRunup",    /*double  */ DoubleToStr(stats[METRIC_SIG_UNITS][S_WINNERS_AVG_RUNUP   ]/pUnit, pDigits));
   WriteIniString(file, section, "winners.avgRundown",  /*double  */ DoubleToStr(stats[METRIC_SIG_UNITS][S_WINNERS_AVG_DRAWDOWN]/pUnit, pDigits) + separator);

   WriteIniString(file, section, "losers",              /*double  */ StrPadRight(Round(stats[METRIC_SIG_UNITS][S_LOSERS]),       24) + StrPadLeft("("+ DoubleToStr(100 * stats[METRIC_SIG_UNITS][S_LOSERS_PCT       ], 1) +"%)", 8));
   WriteIniString(file, section, "losers.long",         /*double  */ StrPadRight(Round(stats[METRIC_SIG_UNITS][S_LOSERS_LONG ]), 19) + StrPadLeft("("+ DoubleToStr(100 * stats[METRIC_SIG_UNITS][S_LOSERS_LONG_PCT  ], 1) +"%)", 8));
   WriteIniString(file, section, "losers.short",        /*double  */ StrPadRight(Round(stats[METRIC_SIG_UNITS][S_LOSERS_SHORT]), 18) + StrPadLeft("("+ DoubleToStr(100 * stats[METRIC_SIG_UNITS][S_LOSERS_SHORT_PCT ], 1) +"%)", 8));
   WriteIniString(file, section, "losers.totalLoss",    /*double  */ DoubleToStr(stats[METRIC_SIG_UNITS][S_LOSERS_TOTAL_LOSS  ]/pUnit, pDigits));
   WriteIniString(file, section, "losers.avgLoss",      /*double  */ DoubleToStr(stats[METRIC_SIG_UNITS][S_LOSERS_AVG_LOSS    ]/pUnit, pDigits));
   WriteIniString(file, section, "losers.avgRunup",     /*double  */ DoubleToStr(stats[METRIC_SIG_UNITS][S_LOSERS_AVG_RUNUP   ]/pUnit, pDigits));
   WriteIniString(file, section, "losers.avgRundown",   /*double  */ DoubleToStr(stats[METRIC_SIG_UNITS][S_LOSERS_AVG_DRAWDOWN]/pUnit, pDigits) + separator);

   scratch = Round(stats[METRIC_SIG_UNITS][S_SCRATCH]);
   if (!scratch) {
      WriteIniString(file, section, "scratch",          /*int     */ scratch + separator);
   }
   else {
      WriteIniString(file, section, "scratch",          /*int     */ StrPadRight(scratch,                                         23) + StrPadLeft("("+ DoubleToStr(100 * stats[METRIC_SIG_UNITS][S_SCRATCH_PCT      ], 1) +"%)", 8));
      WriteIniString(file, section, "scratch.long",     /*double  */ StrPadRight(Round(stats[METRIC_SIG_UNITS][S_SCRATCH_LONG ]), 18) + StrPadLeft("("+ DoubleToStr(100 * stats[METRIC_SIG_UNITS][S_SCRATCH_LONG_PCT ], 1) +"%)", 8));
      WriteIniString(file, section, "scratch.short",    /*double  */ StrPadRight(Round(stats[METRIC_SIG_UNITS][S_SCRATCH_SHORT]), 17) + StrPadLeft("("+ DoubleToStr(100 * stats[METRIC_SIG_UNITS][S_SCRATCH_SHORT_PCT], 1) +"%)", 8) + separator);
   }
   return(!catch("SaveStatus.TradeStats(1)"));
}
