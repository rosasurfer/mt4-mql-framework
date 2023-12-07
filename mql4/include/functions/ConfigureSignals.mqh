/**
 * Configure signaling.
 *
 * @param  _In_    string name        - program name to check signal configuration for, may differ from ProgramName()
 * @param  _InOut_ string configValue - configuration value
 * @param  _Out_   bool   enabled     - whether general event signaling is enabled
 *
 * @return bool - validation success status
 */
bool ConfigureSignals(string name, string &configValue, bool &enabled) {
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
      string section = "Signals" + ifString(__isTesting, ".Tester", "");
      string key     = name;
      configValue    = "auto";
      enabled        = GetConfigBool(section, key);
      return(true);
   }
   return(false);

   // dummy calls
   bool bNull;
   string sNull;
   ConfigureSignals2(NULL, NULL, bNull);
   ConfigureSignalsBySound2(NULL, NULL, bNull);
   ConfigureSignalsByPopup(NULL, NULL, bNull);
   ConfigureSignalsByMail2(NULL, NULL, bNull);
   ConfigureSignalsBySMS2(NULL, NULL, bNull);
}


/**
 * Configure signaling.
 *
 * @param  _In_    string signalId   - case-insensitive signal identifier
 * @param  _In_    bool   autoConfig - input parameter AutoConfiguration
 * @param  _InOut_ bool   enabled    - input parameter (in) and final activation status (out)
 *
 * @return bool - success status
 */
bool ConfigureSignals2(string signalId, bool autoConfig, bool &enabled) {
   autoConfig = autoConfig!=0;
   enabled = enabled!=0;

   if (autoConfig) {
      string section = ifString(__isTesting, "Tester.", "") + ProgramName();
      enabled = GetConfigBool(section, signalId, enabled);
   }
   return(true);

   // dummy calls
   bool bNull;
   string sNull;
   ConfigureSignals(NULL, sNull, bNull);
}


/**
 * Configure signaling by sound.
 *
 * @param  _In_    string signalId   - case-insensitive signal identifier
 * @param  _In_    bool   autoConfig - input parameter AutoConfiguration
 * @param  _InOut_ bool   enabled    - input parameter (in) and final activation status (out)
 *
 * @return bool - success status
 */
bool ConfigureSignalsBySound2(string signalId, bool autoConfig, bool &enabled) {
   autoConfig = autoConfig!=0;
   enabled = enabled!=0;

   if (autoConfig) {
      string section = ifString(__isTesting, "Tester.", "") + ProgramName();
      enabled = GetConfigBool(section, signalId +".Sound", enabled);
   }
   return(true);
}


/**
 * Configure signaling by an alert dialog.
 *
 * @param  _In_    string signalId   - case-insensitive signal identifier
 * @param  _In_    bool   autoConfig - input parameter AutoConfiguration
 * @param  _InOut_ bool   enabled    - input parameter (in) and final activation status (out)
 *
 * @return bool - success status
 */
bool ConfigureSignalsByPopup(string signalId, bool autoConfig, bool &enabled) {
   autoConfig = autoConfig!=0;
   enabled = enabled!=0;

   if (autoConfig) {
      string section = ifString(__isTesting, "Tester.", "") + ProgramName();
      enabled = GetConfigBool(section, signalId +".Popup", enabled);
   }
   return(true);
}


/**
 * Configure signaling by email.
 *
 * @param  _In_    string signalId   - case-insensitive signal identifier
 * @param  _In_    bool   autoConfig - input parameter AutoConfiguration
 * @param  _InOut_ bool   enabled    - input parameter (in) and final activation status (out)
 *
 * @return bool - success status
 */
bool ConfigureSignalsByMail2(string signalId, bool autoConfig, bool &enabled) {
   autoConfig = autoConfig!=0;
   enabled = enabled!=0;

   if (autoConfig) {
      string section = ifString(__isTesting, "Tester.", "") + ProgramName();
      enabled = GetConfigBool(section, signalId +".Mail", enabled);
   }
   return(true);
}


/**
 * Configure signaling by text message.
 *
 * @param  _In_    string signalId   - case-insensitive signal identifier
 * @param  _In_    bool   autoConfig - input parameter AutoConfiguration
 * @param  _InOut_ bool   enabled    - input parameter (in) and final activation status (out)
 *
 * @return bool - validation success status
 */
bool ConfigureSignalsBySMS2(string signalId, bool autoConfig, bool &enabled) {
   autoConfig = autoConfig!=0;
   enabled = enabled!=0;

   if (autoConfig) {
      string section = ifString(__isTesting, "Tester.", "") + ProgramName();
      enabled = GetConfigBool(section, signalId +".SMS", enabled);
   }
   return(true);
}
