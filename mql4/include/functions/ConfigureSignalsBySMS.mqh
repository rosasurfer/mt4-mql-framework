/**
 * Configure signaling by text message.
 *
 * @param  _In_  string configValue - configuration value
 * @param  _Out_ bool   enabled     - whether signaling by text message is enabled
 * @param  _Out_ string receiver    - the receiver's phone number or the invalid value in case of errors
 *
 * @return bool - validation success status
 */
bool ConfigureSignalsBySMS(string configValue, bool &enabled, string &receiver) {
   enabled  = false;
   receiver = "";

   string signalSection = "Signals"+ ifString(__isTesting, ".Tester", "");
   string signalKey     = "Signal.SMS";
   string smsSection    = "SMS";
   string receiverKey   = "Receiver";

   string sValue = StrToLower(configValue), values[], errorMsg;         // default: "on | off | auto*"
   if (Explode(sValue, "*", values, 2) > 1) {
      int size = Explode(values[0], "|", values, NULL);
      sValue = values[size-1];
   }
   sValue = StrTrim(sValue);

   // on
   if (sValue == "on") {
      receiver = GetConfigString(smsSection, receiverKey);
      if (!StrIsPhoneNumber(receiver)) {
         if (StringLen(receiver) > 0) catch("ConfigureSignalsBySMS(1)  invalid phone number: ["+ smsSection +"]->"+ receiverKey +" = "+ DoubleQuoteStr(receiver), ERR_INVALID_CONFIG_VALUE);
         return(false);
      }
      enabled = true;
      return(true);
   }

   // off
   if (sValue == "off") {
      return(true);
   }

   // auto
   if (sValue == "auto") {
      if (!GetConfigBool(signalSection, signalKey))
         return(true);
      receiver = GetConfigString(smsSection, receiverKey);
      if (!StrIsPhoneNumber(receiver)) {
         if (StringLen(receiver) > 0) catch("ConfigureSignalsBySMS(2)  invalid phone number: ["+ smsSection +"]->"+ receiverKey +" = "+ DoubleQuoteStr(receiver), ERR_INVALID_CONFIG_VALUE);
         return(false);
      }
      enabled = true;
      return(true);
   }

   receiver = configValue;
   return(!catch("ConfigureSignalsBySMS(3)  invalid configuration value: "+ DoubleQuoteStr(configValue), ERR_INVALID_CONFIG_VALUE));
}
