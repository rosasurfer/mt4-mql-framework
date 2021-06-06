/**
 * Configure signaling by email.
 *
 * @param  _In_  string configValue - configuration value
 * @param  _Out_ bool   enabled     - whether signaling by email is enabled
 * @param  _Out_ string sender      - the email sender address or the invalid value in case of errors
 * @param  _Out_ string receiver    - the email receiver address or the invalid value in case of errors
 *
 * @return bool - validation success status
 */
bool ConfigureSignalingByMail(string configValue, bool &enabled, string &sender, string &receiver) {
   enabled  = false;
   sender   = "";
   receiver = "";

   string signalSection = "Signals"+ ifString(This.IsTesting(), ".Tester", "");
   string signalKey     = "Signal.Mail";
   string mailSection   = "Mail";
   string senderKey     = "Sender";
   string receiverKey   = "Receiver";

   string defaultSender = "mt4@"+ GetHostName() +".localdomain";
   sender = GetConfigString(mailSection, senderKey, defaultSender);
   if (!StrIsEmailAddress(sender)) return(!catch("ConfigureSignalingByMail(1)  invalid email address: "+ ifString(IsConfigKey(mailSection, senderKey), "["+ mailSection +"]->"+ senderKey +" = "+ DoubleQuoteStr(sender), "defaultSender = "+ DoubleQuoteStr(defaultSender)), ERR_INVALID_CONFIG_VALUE));

   string sValue = StrToLower(configValue), values[], errorMsg;         // default: "on | off | auto*"
   if (Explode(sValue, "*", values, 2) > 1) {
      int size = Explode(values[0], "|", values, NULL);
      sValue = values[size-1];
   }
   sValue = StrTrim(sValue);

   // on
   if (sValue == "on") {
      receiver = GetConfigString(mailSection, receiverKey);
      if (!StrIsEmailAddress(receiver)) {
         sender = "";
         if (StringLen(receiver) > 0) catch("ConfigureSignalingByMail(2)  invalid email address: ["+ mailSection +"]->"+ receiverKey +" = "+ DoubleQuoteStr(receiver), ERR_INVALID_CONFIG_VALUE);
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
      receiver = GetConfigString(mailSection, receiverKey);
      if (!StrIsEmailAddress(receiver)) {
         sender = "";
         if (StringLen(receiver) > 0) catch("ConfigureSignalingByMail(3)  invalid email address: ["+ mailSection +"]->"+ receiverKey +" = "+ DoubleQuoteStr(receiver), ERR_INVALID_CONFIG_VALUE);
         return(false);
      }
      enabled = true;
      return(true);
   }

   receiver = configValue;
   return(!catch("ConfigureSignalingByMail(4)  invalid email configuration value: "+ DoubleQuoteStr(configValue), ERR_INVALID_PARAMETER));
}
