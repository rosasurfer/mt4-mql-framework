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
   if (NE(netProfit,  instance.closedNetProfit, 2))       return(!catch("ReadStatus.TradeHistory(2)  "+ instance.name +" sum(history[H_NETPROFIT_M]) != instance.closedNetProfit ("  + NumberToStr(netProfit, ".2+")             +" != "+ NumberToStr(instance.closedNetProfit, ".2+")             +")", ERR_ILLEGAL_STATE));
   if (NE(netProfitP, instance.closedNetProfitP, Digits)) return(!catch("ReadStatus.TradeHistory(3)  "+ instance.name +" sum(history[H_NETPROFIT_P]) != instance.closedNetProfitP (" + NumberToStr(netProfitP, "."+ Digits +"+") +" != "+ NumberToStr(instance.closedNetProfitP, "."+ Digits +"+") +")", ERR_ILLEGAL_STATE));
   if (NE(sigProfitP, instance.closedSigProfitP, Digits)) return(!catch("ReadStatus.TradeHistory(4)  "+ instance.name +" sum(history[H_SIG_PROFIT_P]) != instance.closedSigProfitP ("+ NumberToStr(sigProfitP, "."+ Digits +"+") +" != "+ NumberToStr(instance.closedSigProfitP, "."+ Digits +"+") +")", ERR_ILLEGAL_STATE));
   instance.closedNetProfitP = netProfitP;
   instance.closedSigProfitP = sigProfitP;

   return(!catch("ReadStatus.TradeHistory(5)"));
}
