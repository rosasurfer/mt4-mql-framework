/**
 * Validate and configure event signaling via sound.
 *
 * @param  _In_  string config  - configuration value
 * @param  _Out_ bool   enabled - whether or not signaling is to be enabled
 *
 * @return bool - validation success status
 */
bool Configure.Signal.Sound(string config, bool &enabled) {
   enabled = false;

   string elems[], sValue=StringToLower(config);                              // default: "on | off | account*"
   if (Explode(sValue, "*", elems, 2) > 1) {
      int size = Explode(elems[0], "|", elems, NULL);
      sValue = elems[size-1];
   }
   sValue = StringTrim(sValue);

   // (1) on
   if (sValue=="on" || sValue=="1" || sValue=="yes" || sValue=="true") {
      enabled = true;
   }

   // (2) off
   else if (sValue=="off" || sValue=="0" || sValue=="no" || sValue=="false") {
      enabled = false;
   }

   // (3) account
   else if (sValue=="account") {
      int    account       = GetAccountNumber(); if (!account) return(false);
      string accountConfig = GetAccountConfigPath(ShortAccountCompany(), account);
      string section       = ifString(This.IsTesting(), "Tester.", "") +"EventTracker";
      string key           = "Signal.Sound";
      enabled = GetIniBool(accountConfig, section, key);
   }
   else return(!catch("Configure.Signal.Sound(1)  Invalid input parameter Signal.Sound = "+ DoubleQuoteStr(config), ERR_INVALID_CONFIG_PARAMVALUE));

   return(true);
}
