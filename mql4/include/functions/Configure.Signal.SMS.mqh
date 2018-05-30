/**
 * Configure event signaling via text message.
 *
 * @param  _In_  string configValue - configuration value
 * @param  _Out_ bool   enabled     - whether or not signaling by text message is enabled
 * @param  _Out_ string receiver    - the receiver's phone number or the invalid value in case of errors
 *
 * @return bool - validation success status
 */
bool Configure.Signal.SMS(string configValue, bool &enabled, string &receiver) {
   enabled  = false;
   receiver = "";

   string signalSection = "Signals"+ ifString(This.IsTesting(), ".Tester", "");
   string signalKey     = "Signal.SMS";
   string smsSection    = "SMS";
   string receiverKey   = "Receiver";

   string sValue = StringToLower(configValue), values[], errorMsg;      // preset: "auto* | off | on | {phone-number}"
   if (Explode(sValue, "*", values, 2) > 1) {
      int size = Explode(values[0], "|", values, NULL);
      sValue = values[size-1];
   }
   sValue = StringTrim(sValue);

   // off
   if (sValue == "off")
      return(true);

   // on
   if (sValue == "on") {
      receiver = GetConfigString(smsSection, receiverKey);
      if (!StringIsPhoneNumber(receiver))
         return(false);
      enabled = true;
      return(true);
   }

   // auto
   if (sValue == "auto") {
      if (!GetConfigBool(signalSection, signalKey))
         return(true);
      receiver = GetConfigString(smsSection, receiverKey);
      if (!StringIsPhoneNumber(receiver))
         return(false);
      enabled = true;
      return(true);
   }

   // {phone-number}
   if (StringIsPhoneNumber(sValue)) {
      receiver = sValue;
      enabled  = true;
      return(true);
   }

   receiver = configValue;
   return(false);
}
