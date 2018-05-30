/**
 * Configure event signaling via email.
 *
 * @param  _In_  string configValue - configuration value
 * @param  _Out_ bool   enabled     - whether or not signaling by email is enabled
 * @param  _Out_ string sender      - the sender's email address or the invalid value in case of errors
 * @param  _Out_ string receiver    - the receiver's email address or the invalid value in case of errors
 *
 * @return bool - validation success status
 */
bool Configure.Signal.Mail(string configValue, bool &enabled, string &sender, string &receiver) {
   enabled  = false;
   sender   = "";
   receiver = "";

   string signalSection = "Signals"+ ifString(This.IsTesting(), ".Tester", "");
   string signalKey     = "Signal.Mail";
   string mailSection   = "Mail";
   string senderKey     = "Sender";
   string receiverKey   = "Receiver";

   string sValue = StringToLower(configValue), values[], errorMsg;      // preset: "auto* | off | on | {email-address}"
   if (Explode(sValue, "*", values, 2) > 1) {
      int size = Explode(values[0], "|", values, NULL);
      sValue = values[size-1];
   }
   sValue = StringTrim(sValue);

   // off
   if (sValue == "off")
      return(true);

   string defaultSender = "mt4@"+ GetHostName() +".localdomain";
   sender = GetConfigString(mailSection, senderKey, defaultSender);
   if (!StringIsEmailAddress(sender))
      return(false);

   // on
   if (sValue == "on") {
      receiver = GetConfigString(mailSection, receiverKey);
      if (!StringIsEmailAddress(receiver)) {
         sender = "";
         return(false);
      }
      enabled = true;
      return(true);
   }

   // auto
   if (sValue == "auto") {
      if (!GetConfigBool(signalSection, signalKey))
         return(true);
      receiver = GetConfigString(mailSection, receiverKey);
      if (!StringIsEmailAddress(receiver)) {
         sender = "";
         return(false);
      }
      enabled = true;
      return(true);
   }

   // {email-address}
   if (StringIsEmailAddress(sValue)) {
      receiver = sValue;
      enabled  = true;
      return(true);
   }

   receiver = configValue;
   return(false);
}
