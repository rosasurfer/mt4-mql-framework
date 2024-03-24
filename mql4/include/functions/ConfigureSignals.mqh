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

   // suppress compiler warnings about unused functions
   bool bNull;
   ConfigureSignalsBySound(NULL, NULL, bNull);
   ConfigureSignalsByAlert(NULL, NULL, bNull);
   ConfigureSignalsByMail(NULL, NULL, bNull);
   ConfigureSignalsBySMS(NULL, NULL, bNull);
   ConfigureSignalTypes(NULL, NULL, NULL, bNull, bNull, bNull, bNull);
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
bool ConfigureSignalsByAlert(string signalId, bool autoConfig, bool &enabled) {
   autoConfig = autoConfig!=0;
   enabled = enabled!=0;

   if (autoConfig) {
      string section = ifString(__isTesting, "Tester.", "") + ProgramName();
      enabled = GetConfigBool(section, signalId +".Alert", enabled);
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


/**
 * Validate and configure the passed signal types.
 *
 * @param  _In_    string signalId     - case-insensitive signal identifier
 * @param  _In_    string signalTypes  - input paramter Signal.*.Types
 * @param  _In_    bool   autoConfig   - input parameter AutoConfiguration
 * @param  _InOut_ bool   soundEnabled - current (in) and final activation status (out) for signaling by sound
 * @param  _InOut_ bool   alertEnabled - current (in) and final activation status (out) for signaling by alert
 * @param  _InOut_ bool   mailEnabled  - current (in) and final activation status (out) for signaling by mail
 * @param  _InOut_ bool   smsEnabled   - current (in) and final activation status (out) for signaling by text message
 *
 * @return bool - validation success status
 */
bool ConfigureSignalTypes(string signalId, string signalTypes, bool autoConfig, bool &soundEnabled, bool &alertEnabled, bool &mailEnabled, bool &smsEnabled) {
   autoConfig = autoConfig!=0;                                             // supported syntax variants:
   soundEnabled = soundEnabled!=0;                                         //  "sound* | alert | mail | sms"
   alertEnabled = alertEnabled!=0;                                         //  "sound* | alert* | mail | sms"
   mailEnabled = mailEnabled!=0;                                           //  "sound | alert | mail | sms"
   smsEnabled = smsEnabled!=0;                                             //  "sound, alert, mail, sms"
                                                                           //  "sound alert mail sms"
   if (autoConfig) {
      string section = ifString(__isTesting, "Tester.", "") + ProgramName();
      signalTypes = GetConfigString(section, signalId +".Types", signalTypes);
   }

   string sValue = StrToLower(signalTypes), values1[], values2[];
   sValue = StrReplace(sValue, "|", " ");
   sValue = StrReplace(sValue, ",", " ");

   int size1 = Explode(sValue, "*", values1, NULL);
   if (size1 > 1) {
      size1 = ArrayResize(values1, size1-1);                               // discard the last element
      for (int i=0; i < size1; i++) {
         values1[i] = StrRightFrom(StrTrimRight(values1[i]), " ", -1);     // keep only the identifier preceding the asterisk
      }
   }

   for (i=0; i < size1; i++) {
      int size2 = Explode(values1[i], " ", values2, NULL);

      for (int n=0; n < size2; n++) {
         sValue = StrTrim(values2[n]);
         if (sValue == "") continue;

         if      (sValue == "sound") soundEnabled = true;
         else if (sValue == "alert") alertEnabled = true;
         else if (sValue == "mail" ) mailEnabled  = true;
         else if (sValue == "sms"  ) smsEnabled   = true;
         else                        return(false);
      }
   }
   return(!catch("ConfigureSignalTypes(1)"));
}
