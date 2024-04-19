/**
 * Read and restore the trade history from the status file.
 *
 * @param  string file - status filename
 *
 * @return bool - success status
 */
bool ReadStatus.TradeHistory(string file) {
   double netProfit, netProfitP, sigProfitP;

   // read history keys
   string section = "Trade history", keys[], sTrade="";
   int size = GetIniKeys(file, section, keys), pos;
   if (size < 0) return(false);

   // restore found keys
   for (int i=0; i < size; i++) {
      sTrade = GetIniStringA(file, section, keys[i], "");    // [full|part].{i} = {data}
      pos = ReadStatus.HistoryRecord(keys[i], sTrade);
      if (pos < 0) return(!catch("ReadStatus.TradeHistory(1)  "+ instance.name +" invalid history record in status file \""+ file +"\", key: \""+ keys[i] +"\"", ERR_INVALID_FILE_FORMAT));

      if (StrStartsWith(keys[i], "full.")) {
         netProfit  += history[pos][H_NETPROFIT_M ];
         netProfitP += history[pos][H_NETPROFIT_P ];
         sigProfitP += history[pos][H_SIG_PROFIT_P];
      }
   }

   // restore exact 'closed' stats (for readability the stats section shows rounded pUnit values)
   if (NE(netProfit,  stats[METRIC_NET_MONEY][S_CLOSED_PROFIT], 2))      return(!catch("ReadStatus.TradeHistory(2)  "+ instance.name +" sum(history[NETPROFIT_M]) != stats[NET_MONEY][CLOSED_PROFIT] (" + NumberToStr(netProfit, ".2+")             +" != "+ NumberToStr(stats[METRIC_NET_MONEY][S_CLOSED_PROFIT], ".2+")            +")", ERR_ILLEGAL_STATE));
   if (NE(netProfitP, stats[METRIC_NET_UNITS][S_CLOSED_PROFIT], Digits)) return(!catch("ReadStatus.TradeHistory(3)  "+ instance.name +" sum(history[NETPROFIT_P]) != stats[NET_UNITS][CLOSED_PROFIT] (" + NumberToStr(netProfitP, "."+ Digits +"+") +" != "+ NumberToStr(stats[METRIC_NET_UNITS][S_CLOSED_PROFIT], "."+ Digits +"+") +")", ERR_ILLEGAL_STATE));
   if (NE(sigProfitP, stats[METRIC_SIG_UNITS][S_CLOSED_PROFIT], Digits)) return(!catch("ReadStatus.TradeHistory(4)  "+ instance.name +" sum(history[SIG_PROFIT_P]) != stats[SIG_UNITS][CLOSED_PROFIT] ("+ NumberToStr(sigProfitP, "."+ Digits +"+") +" != "+ NumberToStr(stats[METRIC_SIG_UNITS][S_CLOSED_PROFIT], "."+ Digits +"+") +")", ERR_ILLEGAL_STATE));

   stats[METRIC_NET_MONEY][S_CLOSED_PROFIT] = netProfit;
   stats[METRIC_NET_UNITS][S_CLOSED_PROFIT] = netProfitP;
   stats[METRIC_SIG_UNITS][S_CLOSED_PROFIT] = sigProfitP;

   return(!catch("ReadStatus.TradeHistory(5)"));
}
