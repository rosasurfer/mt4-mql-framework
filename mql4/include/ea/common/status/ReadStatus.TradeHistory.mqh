/**
 * Read and restore the trade history stored in the status file.
 *
 * @param  string file    - status filename
 * @param  string section - status section
 *
 * @return bool - success status
 */
bool ReadStatus.TradeHistory(string file, string section) {
   // read history keys
   string keys[];
   int size = GetIniKeys(file, section, keys);
   if (size < 0) return(false);

   for (int i=size-1; i >= 0; i--) {
      if (StrStartsWithI(keys[i], "history."))
         continue;
      ArraySpliceStrings(keys, i, 1);                                // drop all non-order keys
      size--;
   }

   double netProfit, netProfitP, synthProfitP;

   // restore found keys
   for (i=0; i < size; i++) {
      string sOrder = GetIniStringA(file, section, keys[i], "");     // history.{i} = {data}
      int pos = ReadStatus.RestoreHistoryRecord(keys[i], sOrder);
      if (pos < 0) return(!catch("ReadStatus.TradeHistory(1)  "+ instance.name +" invalid history record in status file "+ DoubleQuoteStr(file) + NL + keys[i] +"="+ sOrder, ERR_INVALID_FILE_FORMAT));

      netProfit    += history[pos][H_NETPROFIT     ];
      netProfitP   += history[pos][H_NETPROFIT_P   ];
      synthProfitP += history[pos][H_SYNTH_PROFIT_P];
   }

   // cross-check restored stats
   int precision = MathMax(Digits, 2) + 1;                     // required precision for fractional point values
   if (NE(netProfit,    instance.closedNetProfit, 2))          return(!catch("ReadStatus.TradeHistory(2)  "+ instance.name +" sum(history[H_NETPROFIT]) != instance.closedNetProfit ("        + NumberToStr(netProfit, ".2+")               +" != "+ NumberToStr(instance.closedNetProfit, ".2+")               +")", ERR_ILLEGAL_STATE));
   if (NE(netProfitP,   instance.closedNetProfitP, precision)) return(!catch("ReadStatus.TradeHistory(3)  "+ instance.name +" sum(history[H_NETPROFIT_P]) != instance.closedNetProfitP ("     + NumberToStr(netProfitP, "."+ Digits +"+")   +" != "+ NumberToStr(instance.closedNetProfitP, "."+ Digits +"+")   +")", ERR_ILLEGAL_STATE));
   if (NE(synthProfitP, instance.closedSynthProfitP, Digits))  return(!catch("ReadStatus.TradeHistory(4)  "+ instance.name +" sum(history[H_SYNTH_PROFIT_P]) != instance.closedSynthProfitP ("+ NumberToStr(synthProfitP, "."+ Digits +"+") +" != "+ NumberToStr(instance.closedSynthProfitP, "."+ Digits +"+") +")", ERR_ILLEGAL_STATE));

   return(!catch("ReadStatus.TradeHistory(5)"));
}
