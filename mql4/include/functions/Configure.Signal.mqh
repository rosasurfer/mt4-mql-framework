/**
 * Configure event signaling.
 *
 * @param  _In_    string  name        - indicator name to check signal configuration for (may differ from __NAME__)
 * @param  _InOut_ string &configValue - configuration value
 * @param  _Out_   bool   &enabled     - whether or not signaling is enabled
 *
 * @return bool - validation success status
 */
bool Configure.Signal(string name, string &configValue, bool &enabled) {
   enabled = false;

   string sValue = StringToLower(configValue), values[];             // preset: "auto* | off | on"
   if (Explode(sValue, "*", values, 2) > 1) {
      int size = Explode(values[0], "|", values, NULL);
      sValue = values[size-1];
   }
   sValue = StringTrim(sValue);

   // off
   if (sValue == "off") {
      configValue = "off";
      enabled     = false;
      return(true);
   }

   // on
   if (sValue == "on") {
      configValue = "on";
      enabled     = true;
      return(true);
   }

   // auto
   if (sValue == "auto") {
      string section = "Signals" + ifString(This.IsTesting(), ".Tester", "");
      string key     = name;
      configValue = "auto";
      enabled     = GetConfigBool(section, key);
      return(true);
   }
   return(false);
}
