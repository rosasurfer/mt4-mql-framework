/**
 * Configure event signaling via sound.
 *
 * @param  _In_  string configValue - configuration value
 * @param  _Out_ bool   enabled     - whether or not signaling by sound is enabled
 *
 * @return bool - validation success status
 */
bool Configure.Signal.Sound(string configValue, bool &enabled) {
   enabled = false;

   string sValue = StrToLower(configValue), values[];                // preset: "auto* | off | on"
   if (Explode(sValue, "*", values, 2) > 1) {
      int size = Explode(values[0], "|", values, NULL);
      sValue = values[size-1];
   }
   sValue = StrTrim(sValue);

   // off
   if (sValue == "off")
      return(true);

   // on
   if (sValue == "on") {
      enabled = true;
      return(true);
   }

   // auto
   if (sValue == "auto") {
      string section = "Signals"+ ifString(This.IsTesting(), ".Tester", "");
      string key     = "Signal.Sound";
      enabled = GetConfigBool(section, key);
      return(true);
   }

   return(false);
}
