/**
 * Validiert Input-Parameter für und konfiguriert die akustische Signalisierung.
 *
 * @param  _In_  string config  - manueller Konfigurationswert
 * @param  _Out_ bool   enabled - ob die akustische Signalisierung aktiv ist
 *
 * @return bool - Erfolgsstatus
 */
bool Configure.Signal.Sound(string config, bool &enabled) {
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
      int    account       = GetAccountNumber(); if (!account) return(false);
      string accountConfig = GetAccountConfigPath(ShortAccountCompany(), account);
      string section       = ifString(This.IsTesting(), "Tester.", "") +"EventTracker";
      string key           = "Signal.Sound";
      enabled = GetIniBool(accountConfig, section, key);
   }
   else return(!catch("Configure.Signal.Sound(1)  Invalid input parameter Signal.Sound = "+ DoubleQuoteStr(config), ERR_INVALID_CONFIG_PARAMVALUE));

   return(true);
}
