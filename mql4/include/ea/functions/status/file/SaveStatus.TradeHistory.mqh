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

   string section = "Trade history";
   int size = ArrayRange(history, 0);
   for (int i=0; i < size; i++) {
      WriteIniString(file, section, "full."+ i, HistoryRecordToStr(i, false));
      netProfit  += history[i][H_NETPROFIT   ];
      netProfitP += history[i][H_NETPROFIT_P ];
      sigProfitP += history[i][H_SIG_PROFIT_P];
   }

   size = ArrayRange(partialClose, 0);
   for (i=0; i < size; i++) {
      WriteIniString(file, section, "part."+ i, HistoryRecordToStr(i, true));
   }

   // cross-check stored 'close' stats
   if (NE(netProfit,  instance.closedNetProfit, 2))       return(!catch("SaveStatus.TradeHistory(1)  "+ instance.name +" sum(history[H_NETPROFIT]) != instance.closedNetProfit ("    + NumberToStr(netProfit, ".2+")             +" != "+ NumberToStr(instance.closedNetProfit, ".2+")             +")", ERR_ILLEGAL_STATE));
   if (NE(netProfitP, instance.closedNetProfitP, Digits)) return(!catch("SaveStatus.TradeHistory(2)  "+ instance.name +" sum(history[H_NETPROFIT_P]) != instance.closedNetProfitP (" + NumberToStr(netProfitP, "."+ Digits +"+") +" != "+ NumberToStr(instance.closedNetProfitP, "."+ Digits +"+") +")", ERR_ILLEGAL_STATE));
   if (NE(sigProfitP, instance.closedSigProfitP, Digits)) return(!catch("SaveStatus.TradeHistory(3)  "+ instance.name +" sum(history[H_SIG_PROFIT_P]) != instance.closedSigProfitP ("+ NumberToStr(sigProfitP, "."+ Digits +"+") +" != "+ NumberToStr(instance.closedSigProfitP, "."+ Digits +"+") +")", ERR_ILLEGAL_STATE));

   return(!catch("SaveStatus.TradeHistory(4)"));
}
