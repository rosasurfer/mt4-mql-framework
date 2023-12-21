/**
 * Configure signaling.
 *
 * @param  _In_    string signalId   - case-insensitive signal identifier
 * @param  _In_    bool   autoConfig - input parameter AutoConfiguration
 * @param  _InOut_ bool   enabled    - input parameter (in) and final activation status (out)
 *
 * @return bool - success status
 */
bool ConfigureSignals(string signalId, bool autoConfig, bool &enabled) {
   autoConfig = autoConfig!=0;
   enabled = enabled!=0;

   if (autoConfig) {
      string section = ifString(__isTesting, "Tester.", "") + ProgramName();
      enabled = GetConfigBool(section, signalId, enabled);
   }
   return(true);

   // dummy calls
   bool bNull;
   ConfigureSignalsBySound(NULL, NULL, bNull);
   ConfigureSignalsByPopup(NULL, NULL, bNull);
   ConfigureSignalsByMail(NULL, NULL, bNull);
   ConfigureSignalsBySMS(NULL, NULL, bNull);
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
bool ConfigureSignalsBySound(string signalId, bool autoConfig, bool &enabled) {
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
bool ConfigureSignalsByMail(string signalId, bool autoConfig, bool &enabled) {
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
bool ConfigureSignalsBySMS(string signalId, bool autoConfig, bool &enabled) {
   autoConfig = autoConfig!=0;
   enabled = enabled!=0;

   if (autoConfig) {
      string section = ifString(__isTesting, "Tester.", "") + ProgramName();
      enabled = GetConfigBool(section, signalId +".SMS", enabled);
   }
   return(true);
}
