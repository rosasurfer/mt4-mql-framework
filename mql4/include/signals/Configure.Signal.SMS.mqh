/**
 * Validiert Input-Parameter für und konfiguriert die Signalisierung per SMS.
 *
 * @param  _In_  string config     - manueller Konfigurationswert
 * @param  _Out_ bool   enabled    - ob die Signalisierung per SMS aktiv ist
 * @param  _Out_ string receiver   - bei Erfolg die Telefon-Nummer des Empfängers, andererseits der fehlerhafte Wert
 * @param  _In_  bool   muteErrors - für rekursive Aufrufe: ob die Anzeige von Fehlern unterdrückt werden soll
 *                                   (default: nein)
 *
 * @return bool - Erfolgsstatus
 */
bool Configure.Signal.SMS(string config, bool &enabled, string &receiver, bool muteErrors=false) {
   enabled  = false;
   receiver = "";
   string sValue = StringToLower(StringTrim(config)), errorMsg;                           // default: "system | account | auto* | off | {phone}"


   // (1) system
   if (sValue == "system") {
      string section = ifString(This.IsTesting(), "Tester.", "") +"EventTracker";
      string key     = "Signal.SMS";
      sValue = StringToLower(GetConfigString(section, key));                              // system: "on | off"
      // on
      if (sValue=="on" || sValue=="1" || sValue=="yes" || sValue=="true") {
         section  = "SMS";
         key      = "Receiver";
         receiver = GetConfigString(section, key);                                        // system: "{phone}"
         if (!StringIsPhoneNumber(receiver)) {
            if (!StringLen(receiver)) errorMsg = "Configure.Signal.SMS(1)  Missing global/local configuration ["+ section +"]->"+ key;
            else                      errorMsg = "Configure.Signal.SMS(2)  Invalid global/local configuration ["+ section +"]->"+ key +" = "+ DoubleQuoteStr(receiver);
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
         if (!StringLen(sValue)) errorMsg = "Configure.Signal.SMS(3)  Missing global/local configuration ["+ section +"]->"+ key;
         else                    errorMsg = "Configure.Signal.SMS(4)  Invalid global/local configuration ["+ section +"]->"+ key +" = "+ DoubleQuoteStr(receiver);
         if (muteErrors) return(!SetLastError(   ERR_INVALID_CONFIG_PARAMVALUE));
         else            return(!catch(errorMsg, ERR_INVALID_CONFIG_PARAMVALUE));
      }
   }


   // (2) account
   else if (sValue == "account") {
      int    account       = GetAccountNumber(); if (!account) return(false);
      string accountConfig = GetAccountConfigPath(ShortAccountCompany(), account);
      section              = ifString(This.IsTesting(), "Tester.", "") +"EventTracker";
      key                  = "Signal.SMS";
      sValue = StringToLower(GetIniString(accountConfig, section, key));                  // account: "on | off | {phone}"
      // on
      if (sValue=="on" || sValue=="1" || sValue=="yes" || sValue=="true") {
         section  = "SMS";
         key      = "Receiver";
         receiver = GetConfigString(section, key);                                        // system: "{phone}"
         if (!StringIsPhoneNumber(receiver)) {
            if (!StringLen(receiver)) errorMsg = "Configure.Signal.SMS(5)  Missing global/local configuration ["+ section +"]->"+ key;
            else                      errorMsg = "Configure.Signal.SMS(6)  Invalid global/local configuration ["+ section +"]->"+ key +" = "+ DoubleQuoteStr(receiver);
            if (muteErrors) return(!SetLastError(   ERR_INVALID_CONFIG_PARAMVALUE));
            else            return(!catch(errorMsg, ERR_INVALID_CONFIG_PARAMVALUE));
         }
         enabled = true;
      }
      // off
      else if (sValue=="off" || sValue=="0" || sValue=="no" || sValue=="false") {
         enabled = false;
      }
      // phone number
      else if (StringIsPhoneNumber(sValue)) {
         enabled  = true;
         receiver = sValue;
      }
      else {
         enabled  = false;
         receiver = GetIniString(accountConfig, section, key);
         if (!StringLen(sValue)) errorMsg = "Configure.Signal.SMS(7)  Missing account configuration ["+ section +"]->"+ key;
         else                    errorMsg = "Configure.Signal.SMS(8)  Invalid account configuration ["+ section +"]->"+ key +" = "+ DoubleQuoteStr(receiver);
         if (muteErrors) return(!SetLastError(  ERR_INVALID_CONFIG_PARAMVALUE));
         else            return(!catch(errorMsg,ERR_INVALID_CONFIG_PARAMVALUE));
      }
   }


   // (3) auto
   else if (sValue=="auto" || sValue=="system | account | auto* | off | {phone}") {
      // (3.1) account
      if (!Configure.Signal.SMS("account", enabled, receiver, true)) {                    // rekursiv: account...
         if (StringLen(receiver) > 0) {
            errorMsg = "Configure.Signal.SMS(9)  Invalid account configuration = "+ DoubleQuoteStr(receiver);
            if (muteErrors) return(!SetLastError(   ERR_INVALID_CONFIG_PARAMVALUE));
            else            return(!catch(errorMsg, ERR_INVALID_CONFIG_PARAMVALUE));
         }
         if (last_error == ERR_INVALID_CONFIG_PARAMVALUE) SetLastError(NO_ERROR);
         // (3.2) system
         if (!Configure.Signal.SMS("system", enabled, receiver)) return(false);           // rekursiv: system...
      }
   }


   // (4) off
   else if (sValue=="off" || sValue=="0" || sValue=="no" || sValue=="false") {
      enabled = false;
   }


   // (5) phone number
   else if (StringIsPhoneNumber(sValue)) {
      enabled  = true;
      receiver = sValue;
   }


   // (6)
   else {
      enabled  = false;
      receiver = config;
      errorMsg = "Configure.Signal.SMS(10)  Invalid input parameter Signal.SMS.Receiver = "+ DoubleQuoteStr(config);
      if (muteErrors) return(!SetLastError(   ERR_INVALID_CONFIG_PARAMVALUE));
      else            return(!catch(errorMsg, ERR_INVALID_CONFIG_PARAMVALUE));
   }
   return(true);
}
