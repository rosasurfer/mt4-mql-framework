/**
 * Read/validate account, symbol and test infos (if any) stored in the status file.
 *
 * @param  string file - status filename
 *
 * @return bool - success status
 */
bool ReadStatus.General(string file) {
   string section     = "General";
   string sAccount    = GetIniStringA(file, section, "Account", "");          // string Account     = ICMarkets:12345678 (demo)
   string sSymbol     = GetIniStringA(file, section, "Symbol",  "");          // string Symbol      = EURUSD
   string sTestSymbol = GetIniStringA(file, "Test", "Symbol",   "");          // string Test.Symbol = EURUSD

   if (sTestSymbol == "") {
      string sCurrentAccount = GetAccountCompanyId() +":"+ GetAccountNumber();
      if (!StrCompareI(StrLeftTo(sAccount, " ("), sCurrentAccount)) return(!catch("ReadStatus.General(1)  "+ instance.name +" account mis-match: current \""+ sCurrentAccount +"\" vs. \""+ sAccount +"\" in status file \""+ file +"\"", ERR_INVALID_CONFIG_VALUE));
      if (!StrCompareI(sSymbol, Symbol()))                          return(!catch("ReadStatus.General(2)  "+ instance.name +" symbol mis-match: current \""+ Symbol() +"\" vs. \""+ sSymbol +"\" in status file \""+ file +"\"", ERR_INVALID_CONFIG_VALUE));
   }
   else {
      if (!StrCompareI(sTestSymbol, Symbol()))                      return(!catch("ReadStatus.General(3)  "+ instance.name +" symbol mis-match: current \""+ Symbol() +"\" vs. \""+ sTestSymbol +"\" in status file \""+ file +"\"", ERR_INVALID_CONFIG_VALUE));
   }
   return(!catch("ReadStatus.General(4)"));
}
