/**
 * Configure event signaling.
 *
 * @param  _In_    string  name        - program name to check signal configuration for, may differ from ProgramName()
 * @param  _InOut_ string &configValue - configuration value
 * @param  _Out_   bool   &enabled     - whether general event signaling is enabled
 *
 * @return bool - validation success status
 */
bool ConfigureSignal(string name, string &configValue, bool &enabled) {
   enabled = false;

   string sValue = StrToLower(configValue), values[];                // default: "on | off | auto*"
   if (Explode(sValue, "*", values, 2) > 1) {
      int size = Explode(values[0], "|", values, NULL);
      sValue = values[size-1];
   }
   sValue = StrTrim(sValue);

   // on
   if (sValue == "on") {
      configValue = "on";
      enabled     = true;
      return(true);
   }

   // off
   if (sValue == "off") {
      configValue = "off";
      enabled     = false;
      return(true);
   }

   // auto
   if (sValue == "auto") {
      string section = "Signals" + ifString(This.IsTesting(), ".Tester", "");
      string key     = name;
      configValue    = "auto";
      enabled        = GetConfigBool(section, key);
      return(true);
   }
   return(false);
}
