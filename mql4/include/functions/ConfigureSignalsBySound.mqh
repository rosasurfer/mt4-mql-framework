/**
 * Configure signaling by sound.
 *
 * @param  _In_  string configValue - configuration value
 * @param  _Out_ bool   enabled     - whether signaling by sound is enabled
 *
 * @return bool - validation success status
 */
bool ConfigureSignalsBySound(string configValue, bool &enabled) {
   enabled = false;

   string sValue = StrToLower(configValue), values[];                // default: "on | off | auto*"
   if (Explode(sValue, "*", values, 2) > 1) {
      int size = Explode(values[0], "|", values, NULL);
      sValue = values[size-1];
   }
   sValue = StrTrim(sValue);

   // on
   if (sValue == "on") {
      enabled = true;
      return(true);
   }

   // off
   if (sValue == "off") {
      return(true);
   }

   // auto
   if (sValue == "auto") {
      string section = "Signals"+ ifString(__isTesting, ".Tester", "");
      string key     = "Signal.Sound";
      enabled = GetConfigBool(section, key);
      return(true);
   }
   return(false);
}
