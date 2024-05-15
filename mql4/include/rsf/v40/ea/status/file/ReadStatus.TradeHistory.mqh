/**
 * Read and restore the trade history from the status file.
 *
 * @param  string file - status filename
 *
 * @return bool - success status
 */
bool ReadStatus.TradeHistory(string file) {
   // read history keys
   string section = "Trade history", keys[], sTrade="";
   int size = GetIniKeys(file, section, keys), pos;
   if (size < 0) return(false);

   // restore found keys
   for (int i=0; i < size; i++) {
      sTrade = GetIniStringA(file, section, keys[i], "");      // [full|part].{i} = {data}
      pos = ReadStatus.HistoryRecord(keys[i], sTrade);
      if (pos < 0) return(!catch("ReadStatus.TradeHistory(1)  "+ instance.name +" invalid history record in status file \""+ file +"\", key: \""+ keys[i] +"\"", ERR_INVALID_FILE_FORMAT));
   }
   return(!catch("ReadStatus.TradeHistory(2)"));
}
