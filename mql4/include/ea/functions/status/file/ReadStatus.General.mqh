/**
 * Read/validate account and instrument infos stored in the status file.
 *
 * @param  string file - status filename
 *
 * @return bool - success status
 */
bool ReadStatus.General(string file) {
   string section      = "General";
   string sAccount     = GetIniStringA(file, section, "Account",     "");     // string Account     = ICMarkets:12345678 (demo)
   string sThisAccount = GetAccountCompanyId() +":"+ GetAccountNumber();
   string sRealSymbol  = GetIniStringA(file, section, "Symbol",      "");     // string Symbol      = EURUSD
   string sTestSymbol  = GetIniStringA(file, section, "Test.Symbol", "");     // string Test.Symbol = EURUSD
   if (sTestSymbol == "") {
      if (!StrCompareI(StrLeftTo(sAccount, " ("), sThisAccount)) return(!catch("ReadStatus.General(1)  "+ instance.name +" account mis-match: \""+ sThisAccount +"\" vs. \""+ sAccount +"\" in status file \""+ file +"\"", ERR_INVALID_CONFIG_VALUE));
      if (!StrCompareI(sRealSymbol, Symbol()))                   return(!catch("ReadStatus.General(2)  "+ instance.name +" symbol mis-match: \""+ Symbol() +"\" vs. \""+ sRealSymbol +"\" in status file \""+ file +"\"", ERR_INVALID_CONFIG_VALUE));
   }
   else {
      if (!StrCompareI(sTestSymbol, Symbol()))                   return(!catch("ReadStatus.General(3)  "+ instance.name +" symbol mis-match: \""+ Symbol() +"\" vs. \""+ sTestSymbol +"\" in status file \""+ file +"\"", ERR_INVALID_CONFIG_VALUE));
   }
   return(!catch("ReadStatus.General(4)"));
}
