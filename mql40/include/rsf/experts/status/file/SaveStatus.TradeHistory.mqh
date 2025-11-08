/**
 * Write the trade history to the status file.
 *
 * @param  string file       - status filename
 * @param  bool   fileExists - whether the status file exists
 *
 * @return bool - success status
 */
bool SaveStatus.TradeHistory(string file, bool fileExists) {
   fileExists = fileExists!=0;

   string separator = "";
   if (!fileExists) separator = CRLF;                        // an empty line separator

   double netProfit, netProfitP, sigProfitP;
   int sizeHistory = ArrayRange(history, 0), sizePartials = ArrayRange(partialClose, 0);

   string section = "Trade history", suffix = "";
   for (int i=0; i < sizeHistory; i++) {
      if (sizePartials && i == sizeHistory-1) {
         suffix = separator;
      }
      WriteIniString(file, section, "full."+ i, HistoryRecordToStr(i, false) + suffix);
      netProfit  += history[i][H_NETPROFIT_M ];
      netProfitP += history[i][H_NETPROFIT_P ];
      sigProfitP += history[i][H_SIG_PROFIT_P];
   }

   for (i=0; i < sizePartials; i++) {
      WriteIniString(file, section, "part."+ i, HistoryRecordToStr(i, true));
   }

   // cross-check stored 'close' stats
   if (NE(netProfit,  stats[METRIC_NET_MONEY][S_CLOSED_PROFIT], 2))      return(!catch("SaveStatus.TradeHistory(1)  "+ instance.name +" sum(history[NETPROFIT_M]) != stats.closedNetProfit ("  + NumberToStr(netProfit, ".2+")             +" != "+ NumberToStr(stats[METRIC_NET_MONEY][S_CLOSED_PROFIT], ".2+")            +")", ERR_ILLEGAL_STATE));
   if (NE(netProfitP, stats[METRIC_NET_UNITS][S_CLOSED_PROFIT], Digits)) return(!catch("SaveStatus.TradeHistory(2)  "+ instance.name +" sum(history[NETPROFIT_P]) != stats.closedNetProfitP (" + NumberToStr(netProfitP, "."+ Digits +"+") +" != "+ NumberToStr(stats[METRIC_NET_UNITS][S_CLOSED_PROFIT], "."+ Digits +"+") +")", ERR_ILLEGAL_STATE));
   if (NE(sigProfitP, stats[METRIC_SIG_UNITS][S_CLOSED_PROFIT], Digits)) return(!catch("SaveStatus.TradeHistory(3)  "+ instance.name +" sum(history[SIG_PROFIT_P]) != stats.closedSigProfitP ("+ NumberToStr(sigProfitP, "."+ Digits +"+") +" != "+ NumberToStr(stats[METRIC_SIG_UNITS][S_CLOSED_PROFIT], "."+ Digits +"+") +")", ERR_ILLEGAL_STATE));

   return(!catch("SaveStatus.TradeHistory(4)"));
}
