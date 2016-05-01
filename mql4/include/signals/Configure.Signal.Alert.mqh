/**
 * Validiert Input-Parameter für und konfiguriert die optische Signalisierung.
 *
 * @param  _In_  string config  - manueller Konfigurationswert
 * @param  _Out_ bool   enabled - ob die optische Signalisierung aktiv ist
 *
 * @return bool - Erfolgsstatus
 */
bool Configure.Signal.Alert(string config, bool &enabled) {
   enabled = false;
   string sValue = StringToLower(StringTrim(config));                         // default: "on | off | account*"

   // (1) on
   if (sValue=="on" || sValue=="1" || sValue=="yes" || sValue=="true") {
      enabled = true;
   }

   // (2) off
   else if (sValue=="off" || sValue=="0" || sValue=="no" || sValue=="false") {
      enabled = false;
   }

   // (3) account
   else if (sValue=="account" || sValue=="on | off | account*") {
      int    account       = GetAccountNumber(); if (!account) return(!SetLastError(stdlib.GetLastError()));
      string accountConfig = GetAccountConfigPath(ShortAccountCompany(), account);
      string section       = ifString(This.IsTesting(), "Tester.", "") +"EventTracker";
      string key           = "Signal.Alert";
      enabled = GetIniBool(accountConfig, section, key);
   }
   else return(!catch("Configure.Signal.Alert(1)  Invalid input parameter Signal.Alert = "+ DoubleQuoteStr(config), ERR_INVALID_CONFIG_PARAMVALUE));

   return(true);
}
