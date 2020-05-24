/**
 * Configure event signaling via text message.
 *
 * @param  _In_  string configValue - configuration value
 * @param  _Out_ bool   enabled     - whether signaling by text message is enabled
 * @param  _Out_ string receiver    - the receiver's phone number or the invalid value in case of errors
 *
 * @return bool - validation success status
 */
bool ConfigureSignalSMS(string configValue, bool &enabled, string &receiver) {
   enabled  = false;
   receiver = "";

   string signalSection = "Signals"+ ifString(This.IsTesting(), ".Tester", "");
   string signalKey     = "Signal.SMS";
   string smsSection    = "SMS";
   string receiverKey   = "Receiver";

   string sValue = StrToLower(configValue), values[], errorMsg;         // default: "on | off | auto* | {phone-number}"
   if (Explode(sValue, "*", values, 2) > 1) {
      int size = Explode(values[0], "|", values, NULL);
      sValue = values[size-1];
   }
   sValue = StrTrim(sValue);

   // on
   if (sValue == "on") {
      receiver = GetConfigString(smsSection, receiverKey);
      if (!StrIsPhoneNumber(receiver)) {
         if (StringLen(receiver) > 0) catch("ConfigureSignalSMS(1)  invalid phone number: ["+ smsSection +"]->"+ receiverKey +" = "+ receiver, ERR_INVALID_CONFIG_VALUE);
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
         if (StringLen(receiver) > 0) catch("ConfigureSignalSMS(2)  invalid phone number: ["+ smsSection +"]->"+ receiverKey +" = "+ receiver, ERR_INVALID_CONFIG_VALUE);
         return(false);
      }
      enabled = true;
      return(true);
   }

   // {phone-number}
   if (StrIsPhoneNumber(sValue)) {
      receiver = sValue;
      enabled  = true;
      return(true);
   }

   catch("ConfigureSignalSMS(3)  invalid phone number for parameter configValue: "+ DoubleQuoteStr(configValue), ERR_INVALID_PARAMETER);
   receiver = configValue;
   return(false);
}
