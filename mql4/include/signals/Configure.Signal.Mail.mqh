/**
 * Validiert Input-Parameter für und konfiguriert die Signalisierung per E-Mail
 *
 * @param  _In_  string config     - manueller Konfigurationswert
 * @param  _Out_ bool   enabled    - ob die Signalisierung per E-Mail aktiv ist
 * @param  _Out_ string sender     - bei Erfolg die E-Mailadresse des Senders, andererseits der fehlerhafte Konfigurationswert
 * @param  _Out_ string receiver   - bei Erfolg die E-Mailadresse des Empfängers, andererseits der fehlerhafte Konfigurationswert
 * @param  _In_  bool   muteErrors - für rekursive Aufrufe: ob die Anzeige von Fehlern unterdrückt werden soll (default: nein)
 *
 * @return bool - Erfolgsstatus
 */
bool Configure.Signal.Mail(string config, bool &enabled, string &sender, string &receiver, bool muteErrors=false) {
   enabled  = false;
   sender   = "";
   receiver = "";
   string sValue = StringToLower(StringTrim(config)), errorMsg;                           // default: "system | account | auto* | off | address"
   string defaultSender = "mt-"+ GetHostName() +"@localhost";


   // (1) system
   if (sValue == "system") {
      string section = ifString(This.IsTesting(), "Tester.", "") +"EventTracker";
      string key     = "Signal.Mail";
      sValue = StringToLower(GetConfigString(section, key));                              // system: "on | off"
      // on
      if (sValue=="on" || sValue=="1" || sValue=="yes" || sValue=="true") {
         section  = "Mail";
         key      = "Sender";
         sender   = GetConfigString(section, key, defaultSender);                         // system: "address"
         if (!StringIsEmailAddress(sender)) {
            if (!StringLen(sender)) errorMsg = "Configure.Signal.Mail(1)  Missing global/local configuration ["+ section +"]->"+ key;
            else                    errorMsg = "Configure.Signal.Mail(2)  Invalid global/local configuration ["+ section +"]->"+ key +" = "+ DoubleQuoteStr(sender);
            if (muteErrors) return(!SetLastError(   ERR_INVALID_CONFIG_PARAMVALUE));
            else            return(!catch(errorMsg, ERR_INVALID_CONFIG_PARAMVALUE));
         }
         key      = "Receiver";
         receiver = GetConfigString(section, key);                                        // system: "address"
         if (!StringIsEmailAddress(receiver)) {
            sender = "";
            if (!StringLen(receiver)) errorMsg = "Configure.Signal.Mail(3)  Missing global/local configuration ["+ section +"]->"+ key;
            else                      errorMsg = "Configure.Signal.Mail(4)  Invalid global/local configuration ["+ section +"]->"+ key +" = "+ DoubleQuoteStr(receiver);
            if (muteErrors) return(!SetLastError(   ERR_INVALID_CONFIG_PARAMVALUE));
            else            return(!catch(errorMsg, ERR_INVALID_CONFIG_PARAMVALUE));
         }
         enabled = true;
      }
      // off
      else if (sValue=="off" || sValue=="0" || sValue=="no" || sValue=="false") {
         enabled = false;
      }
      else {
         enabled  = false;
         receiver = GetConfigString(section, key);
         if (!StringLen(sValue)) errorMsg = "Configure.Signal.Mail(5)  Missing global/local configuration ["+ section +"]->"+ key;
         else                    errorMsg = "Configure.Signal.Mail(6)  Invalid global/local configuration ["+ section +"]->"+ key +" = "+ DoubleQuoteStr(receiver);
         if (muteErrors) return(!SetLastError(   ERR_INVALID_CONFIG_PARAMVALUE));
         else            return(!catch(errorMsg, ERR_INVALID_CONFIG_PARAMVALUE));
      }
   }


   // (2) account
   else if (sValue == "account") {
      int    account       = GetAccountNumber(); if (!account) return(!SetLastError(stdlib.GetLastError()));
      string accountConfig = GetAccountConfigPath(ShortAccountCompany(), account);
      section              = ifString(This.IsTesting(), "Tester.", "") +"EventTracker";
      key                  = "Signal.Mail";
      sValue  = StringToLower(GetIniString(accountConfig, section, key));                 // account: "on | off | address"
      // on
      if (sValue=="on" || sValue=="1" || sValue=="yes" || sValue=="true") {
         section  = "Mail";
         key      = "Sender";
         sender   = GetConfigString(section, key, defaultSender);                         // system: "address"
         if (!StringIsEmailAddress(sender)) {
            if (!StringLen(sender)) errorMsg = "Configure.Signal.Mail(7)  Missing global/local configuration ["+ section +"]->"+ key;
            else                    errorMsg = "Configure.Signal.Mail(8)  Invalid global/local configuration ["+ section +"]->"+ key +" = "+ DoubleQuoteStr(sender);
            if (muteErrors) return(!SetLastError(   ERR_INVALID_CONFIG_PARAMVALUE));
            else            return(!catch(errorMsg, ERR_INVALID_CONFIG_PARAMVALUE));
         }
         key      = "Receiver";
         receiver = GetConfigString(section, key);                                        // system: "address"
         if (!StringIsEmailAddress(receiver)) {
            sender = "";
            if (!StringLen(receiver)) errorMsg = "Configure.Signal.Mail(9)  Missing global/local configuration ["+ section +"]->"+ key;
            else                      errorMsg = "Configure.Signal.Mail(10)  Invalid global/local configuration ["+ section +"]->"+ key +" = "+ DoubleQuoteStr(receiver);
            if (muteErrors) return(!SetLastError(   ERR_INVALID_CONFIG_PARAMVALUE));
            else            return(!catch(errorMsg, ERR_INVALID_CONFIG_PARAMVALUE));
         }
         enabled = true;
      }
      // off
      else if (sValue=="off" || sValue=="0" || sValue=="no" || sValue=="false") {
         enabled = false;
      }
      // address
      else if (StringIsEmailAddress(sValue)) {
         receiver = sValue;
         section  = "Mail";
         key      = "Sender";
         sender   = GetConfigString(section, key, defaultSender);                         // system: "address"
         if (!StringIsEmailAddress(sender)) {
            receiver = "";
            if (!StringLen(sender)) errorMsg = "Configure.Signal.Mail(11)  Missing global/local configuration ["+ section +"]->"+ key;
            else                    errorMsg = "Configure.Signal.Mail(12)  Invalid global/local configuration ["+ section +"]->"+ key +" = "+ DoubleQuoteStr(sender);
            if (muteErrors) return(!SetLastError(   ERR_INVALID_CONFIG_PARAMVALUE));
            else            return(!catch(errorMsg, ERR_INVALID_CONFIG_PARAMVALUE));
         }
         enabled = true;
      }
      else {
         if (!StringLen(sValue)) errorMsg = "Configure.Signal.Mail(13)  Missing account configuration ["+ section +"]->"+ key;
         else                    errorMsg = "Configure.Signal.Mail(14)  Invalid account configuration ["+ section +"]->"+ key +" = "+ DoubleQuoteStr(GetIniString(accountConfig, section, key));
         if (muteErrors) return(!SetLastError(   ERR_INVALID_CONFIG_PARAMVALUE));
         else            return(!catch(errorMsg, ERR_INVALID_CONFIG_PARAMVALUE));
      }
   }


   // (3) auto
   else if (sValue=="auto" || sValue=="system | account | auto* | off | address") {
      // (3.1) account
      if (!Configure.Signal.Mail("account", enabled, sender, receiver, true)) {           // rekursiv: account...
         if (StringLen(sender) || StringLen(receiver)) {
            errorMsg = "Configure.Signal.Mail(15)  Invalid configuration";
            if (StringLen(sender)   > 0) errorMsg = errorMsg +" [Mail]->Sender = "  + DoubleQuoteStr(sender);
            if (StringLen(receiver) > 0) errorMsg = errorMsg +" [Mail]->Receiver = "+ DoubleQuoteStr(receiver);
            if (muteErrors) return(!SetLastError(   ERR_INVALID_CONFIG_PARAMVALUE));
            else            return(!catch(errorMsg, ERR_INVALID_CONFIG_PARAMVALUE));
         }
         if (last_error == ERR_INVALID_CONFIG_PARAMVALUE) SetLastError(NO_ERROR);
         // (3.2) system
         if (!Configure.Signal.Mail("system", enabled, sender, receiver)) return(false);  // rekursiv: system...
      }
   }


   // (4) off
   else if (sValue=="off" || sValue=="0" || sValue=="no" || sValue=="false") {
      enabled = false;
   }


   // (5) address
   else if (StringIsEmailAddress(sValue)) {
      receiver = sValue;
      section  = "Mail";
      key      = "Sender";
      sender   = GetConfigString(section, key, defaultSender);                            // system: "address"
      if (!StringIsEmailAddress(sender)) {
         receiver = "";
         if (!StringLen(sender)) errorMsg = "Configure.Signal.Mail(16)  Missing global/local configuration ["+ section +"]->"+ key;
         else                    errorMsg = "Configure.Signal.Mail(17)  Invalid global/local configuration ["+ section +"]->"+ key +" = "+ DoubleQuoteStr(sender);
         if (muteErrors) return(!SetLastError(   ERR_INVALID_CONFIG_PARAMVALUE));
         else            return(!catch(errorMsg, ERR_INVALID_CONFIG_PARAMVALUE));
      }
      enabled = true;
   }


   // (6)
   else {
      enabled  = false;
      receiver = config;
      errorMsg = "Configure.Signal.Mail(18)  Invalid input parameter Signal.Mail.Receiver = "+ DoubleQuoteStr(config);
      if (muteErrors) return(!SetLastError(   ERR_INVALID_CONFIG_PARAMVALUE));
      else            return(!catch(errorMsg, ERR_INVALID_CONFIG_PARAMVALUE));
   }
   return(true);
}
