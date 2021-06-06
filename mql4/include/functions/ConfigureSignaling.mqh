/**
 * Configure signaling.
 *
 * @param  _In_    string  name        - program name to check signal configuration for, may differ from ProgramName()
 * @param  _InOut_ string &configValue - configuration value
 * @param  _Out_   bool   &enabled     - whether general event signaling is enabled
 *
 * @return bool - validation success status
 */
bool ConfigureSignaling(string name, string &configValue, bool &enabled) {
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

   // dummy calls
   bool bNull;
   string sNull;
   ConfigureSignaling2(NULL, NULL, bNull);
   ConfigureSignalingByAlert2(NULL, NULL, bNull);
   ConfigureSignalingBySound2(NULL, NULL, bNull);
   ConfigureSignalingByMail2(NULL, NULL, bNull, sNull, sNull);
   ConfigureSignalingBySMS2(NULL, NULL, bNull, sNull);
}


/**
 * Configure general signaling.
 *
 * @param  _In_    string id         - signal id (case-insensitive)
 * @param  _In_    bool   autoConfig - whether auto-configuration is enabled
 * @param  _InOut_ bool   &enabled   - input config value and resulting final activation status
 *
 * @return bool - success status
 */
bool ConfigureSignaling2(string id, bool autoConfig, bool &enabled) {
   autoConfig = autoConfig!=0;
   enabled = enabled!=0;

   if (autoConfig) {
      string section = ifString(This.IsTesting(), "Tester.", "") + StrTrim(ProgramName());
      string key = id;
      enabled = GetConfigBool(section, key, enabled);
   }
   return(true);

   // dummy calls
   bool bNull;
   string sNull;
   ConfigureSignaling(NULL, sNull, bNull);
}


/**
 * Configure signaling by alert.
 *
 * @param  _In_    string id         - signal id (case-insensitive)
 * @param  _In_    bool   autoConfig - whether auto-configuration is enabled
 * @param  _InOut_ bool   &enabled   - input config value and resulting final activation status
 *
 * @return bool - success status
 */
bool ConfigureSignalingByAlert2(string id, bool autoConfig, bool &enabled) {
   autoConfig = autoConfig!=0;
   enabled = enabled!=0;

   if (autoConfig) {
      string section = ifString(This.IsTesting(), "Tester.", "") + StrTrim(ProgramName());
      string key = id;
      enabled = GetConfigBool(section, key, enabled);
   }
   return(true);
}


/**
 * Configure signaling by sound.
 *
 * @param  _In_    string id         - signal id (case-insensitive)
 * @param  _In_    bool   autoConfig - whether auto-configuration is enabled
 * @param  _InOut_ bool   &enabled   - input config value and resulting final activation status
 *
 * @return bool - success status
 */
bool ConfigureSignalingBySound2(string id, bool autoConfig, bool &enabled) {
   autoConfig = autoConfig!=0;
   enabled = enabled!=0;

   if (autoConfig) {
      string section = ifString(This.IsTesting(), "Tester.", "") + StrTrim(ProgramName());
      string key = id;
      enabled = GetConfigBool(section, key, enabled);
   }
   return(true);
}


/**
 * Configure signaling by email.
 *
 * @param  _In_    string id         - signal id (case-insensitive)
 * @param  _In_    bool   autoConfig - whether auto-configuration is enabled
 * @param  _InOut_ bool   &enabled   - input config value and resulting final activation status
 * @param  _Out_   string &sender    - the configured email sender address
 * @param  _Out_   string &receiver  - the configured email receiver address
 *
 * @return bool - success status
 */
bool ConfigureSignalingByMail2(string id, bool autoConfig, bool &enabled, string &sender, string &receiver) {
   autoConfig = autoConfig!=0;
   enabled = enabled!=0;
   sender = "";
   receiver = "";

   string signalSection = ifString(This.IsTesting(), "Tester.", "") + StrTrim(ProgramName());
   string signalKey     = id;
   string mailSection   = "Mail";
   string senderKey     = "Sender";
   string receiverKey   = "Receiver";
   string defaultSender = "mt4@"+ GetHostName() +".localdomain", _sender="", _receiver="";

   bool _enabled = enabled;
   enabled = false;

   if (autoConfig) {
      if (GetConfigBool(signalSection, signalKey, _enabled)) {
         _sender = GetConfigString(mailSection, senderKey, defaultSender);
         if (!StrIsEmailAddress(_sender))   return(!catch("ConfigureSignalingByMail2(1)  invalid email address: "+ ifString(IsConfigKey(mailSection, senderKey), "["+ mailSection +"]->"+ senderKey +" = "+ DoubleQuoteStr(_sender), "defaultSender = "+ DoubleQuoteStr(defaultSender)), ERR_INVALID_CONFIG_VALUE));

         _receiver = GetConfigString(mailSection, receiverKey);
         if (!StrIsEmailAddress(_receiver)) return(!catch("ConfigureSignalingByMail2(2)  invalid email address: ["+ mailSection +"]->"+ receiverKey +" = "+ DoubleQuoteStr(_receiver), ERR_INVALID_CONFIG_VALUE));
         enabled = true;
      }
   }
   else if (_enabled) {
      _sender = GetConfigString(mailSection, senderKey, defaultSender);
      if (!StrIsEmailAddress(_sender))   return(!catch("ConfigureSignalingByMail2(3)  invalid email address: "+ ifString(IsConfigKey(mailSection, senderKey), "["+ mailSection +"]->"+ senderKey +" = "+ DoubleQuoteStr(_sender), "defaultSender = "+ DoubleQuoteStr(defaultSender)), ERR_INVALID_CONFIG_VALUE));

      _receiver = GetConfigString(mailSection, receiverKey);
      if (!StrIsEmailAddress(_receiver)) return(!catch("ConfigureSignalingByMail2(4)  invalid email address: ["+ mailSection +"]->"+ receiverKey +" = "+ DoubleQuoteStr(_receiver), ERR_INVALID_CONFIG_VALUE));
      enabled = true;
   }

   sender = _sender;
   receiver = _receiver;
   return(true);
}


/**
 * Configure signaling by text message.
 *
 * @param  _In_    string id         - signal id (case-insensitive)
 * @param  _In_    bool   autoConfig - whether auto-configuration is enabled
 * @param  _InOut_ bool   &enabled   - input config value and resulting final activation status
 * @param  _Out_   string &receiver  - the configured receiver phone number
 *
 * @return bool - validation success status
 */
bool ConfigureSignalingBySMS2(string id, bool autoConfig, bool &enabled, string &receiver) {
   autoConfig = autoConfig!=0;
   enabled = enabled!=0;

   string signalSection = ifString(This.IsTesting(), "Tester.", "") + StrTrim(ProgramName());
   string signalKey     = id;
   string smsSection    = "SMS";
   string receiverKey   = "Receiver";

   bool _enabled = enabled;
   if (autoConfig) _enabled = GetConfigBool(signalSection, signalKey, _enabled);

   enabled = false;
   receiver = "";

   if (_enabled) {
      string sValue = GetConfigString(smsSection, receiverKey);
      if (!StrIsPhoneNumber(sValue)) return(!catch("ConfigureSignalingBySMS(1)  invalid phone number: ["+ smsSection +"]->"+ receiverKey +" = "+ DoubleQuoteStr(sValue), ERR_INVALID_CONFIG_VALUE));
      enabled  = true;
      receiver = sValue;
   }
   return(true);
}
