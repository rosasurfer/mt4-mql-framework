/**
 * Write account, symbol and test infos (if any) to the status file.
 *
 * @param  string file       - status filename
 * @param  bool   fileExists - whether the status file exists
 *
 * @return bool - success status
 */
bool SaveStatus.General(string file, bool fileExists) {
   fileExists = fileExists!=0;

   string separator = "";
   if (!fileExists) separator = CRLF;                   // an empty line separator

   string section = "General";
   WriteIniString(file, section, "Account", GetAccountCompanyId() +":"+ GetAccountNumber() +" ("+ ifString(IsDemoFix(), "demo", "real") +")"+ ifString(__isTesting, separator, ""));

   if (!__isTesting) {
      WriteIniString(file, section, "AccountCurrency", AccountCurrency());
      WriteIniString(file, section, "Symbol",          Symbol() + separator);
   }
   else {
      section = "Test";
      WriteIniString(file, section, "Currency",  AccountCurrency());
      WriteIniString(file, section, "Symbol",    Symbol());
      WriteIniString(file, section, "TimeRange", TimeToStr(Test.GetStartDate(), TIME_DATE) +"-"+ TimeToStr(Test.GetEndDate()-1*DAY, TIME_DATE));
      WriteIniString(file, section, "Period",    PeriodDescription());
      WriteIniString(file, section, "BarModel",  BarModelDescription(__Test.barModel));
      WriteIniString(file, section, "Spread",    DoubleToStr((_Ask-_Bid)/pUnit, pDigits) +" "+ spUnit);
         double commission  = GetCommission();
         string sCommission = DoubleToStr(commission, 2);
         if (NE(commission, 0)) {
            double tickValue = MarketInfo(Symbol(), MODE_TICKVALUE);
            double tickSize  = MarketInfo(Symbol(), MODE_TICKSIZE);
            double price     = MathDiv(commission, MathDiv(tickValue, tickSize));
            sCommission = sCommission +" ("+ DoubleToStr(price/pUnit, pDigits) +" "+ spUnit +")";
         }
      WriteIniString(file, section, "Commission", sCommission + separator);
   }
   return(!catch("SaveStatus.General(1)"));
}
