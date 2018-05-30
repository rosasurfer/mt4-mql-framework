/**
 * Functions for querying the application configuration.
 */
#import "stdlib1.ex4"
   string GetGlobalConfigPath();
   string GetLocalConfigPath();
#import


/**
 * Return the full filename of an account's configuration file.
 *
 * @param  string companyId [optional] - the account's company identifier (default: the current account's company)
 * @param  string accountId [optional] - the account's id; depending on the company an account number or an account alias
 *                                       (default: the current account's number)
 *
 * @return string - filename or empty string in case of errors
 */
string GetAccountConfigPath(string companyId="", string accountId="") {
   if (!StringLen(companyId) && !StringLen(accountId)) {
      companyId = ShortAccountCompany(); if (!StringLen(companyId)) return("");
      accountId = GetAccountNumber();    if (accountId == "0")      return("");
   }
   else {
      if (!StringLen(companyId)) return(_EMPTY_STR(catch("GetAccountConfigPath(1)  invalid parameter companyId = "+ DoubleQuoteStr(companyId), ERR_INVALID_PARAMETER)));
      if (!StringLen(accountId)) return(_EMPTY_STR(catch("GetAccountConfigPath(2)  invalid parameter accountId = "+ DoubleQuoteStr(accountId), ERR_INVALID_PARAMETER)));
   }
   string mqlDir   = ifString(GetTerminalBuild()<=509, "\\experts", "\\mql4");
   string filename = StringConcatenate(TerminalPath(), mqlDir, "\\files\\", companyId, "\\", accountId, "_config.ini");
   return(filename);
}


/**
 * Whether or not the specified key exists in any of the configurations.
 *
 * @param  string section - configuration section name
 * @param  string key     - configuration key
 *
 * @return bool
 */
bool IsConfigKey(string section, string key) {
   if (IsGlobalConfigKey (section, key)) return(true);
   if (IsLocalConfigKey  (section, key)) return(true);
   if (IsAccountConfigKey(section, key)) return(true);
   return(false);
}


/**
 * Whether or not the specified global configuration key exists.
 *
 * @param  string section - configuration section name
 * @param  string key     - configuration key
 *
 * @return bool
 */
bool IsGlobalConfigKey(string section, string key) {
   string globalConfig = GetGlobalConfigPath();
   if (!StringLen(globalConfig))
      return(false);
   return(IsIniKey(globalConfig, section, key));
}


/**
 * Whether or not the specified local configuration key exists.
 *
 * @param  string section - configuration section name
 * @param  string key     - configuration key
 *
 * @return bool
 */
bool IsLocalConfigKey(string section, string key) {
   string localConfig = GetLocalConfigPath();
   if (!StringLen(localConfig))
      return(false);
   return(IsIniKey(localConfig, section, key));
}


/**
 * Whether or not the specified account configuration key exists.
 *
 * @param  string section - configuration section name
 * @param  string key     - configuration key
 *
 * @return bool
 */
bool IsAccountConfigKey(string section, string key) {
   string accountConfig = GetAccountConfigPath();
   if (!StringLen(accountConfig))
      return(false);
   return(IsIniKey(accountConfig, section, key));
}


// bis hier OK



/**
 * Gibt einen Konfigurationswert als Boolean zurück.  Dabei werden die globale und die lokale Konfiguration der MetaTrader-
 * Installation durchsucht, wobei die lokale eine höhere Priorität als die globale Konfiguration hat.
 *
 * Der Wert kann als "0" oder "1", "On" oder "Off", "Yes" oder "No" und "true" oder "false" angegeben werden (ohne Beachtung
 * von Groß-/Kleinschreibung). Ein leerer Wert eines existierenden Schlüssels wird als FALSE und ein numerischer Wert als
 * TRUE interpretiert, wenn sein Zahlenwert ungleich 0 (zero) ist.
 *
 * @param  string section      - Name des Konfigurationsabschnittes
 * @param  string key          - Konfigurationsschlüssel
 * @param  bool   defaultValue - Rückgabewert, falls der angegebene Schlüssel nicht existiert
 *
 * @return bool - Konfigurationswert (der Konfiguration folgende Kommentare werden ignoriert)
 */
bool GetConfigBool(string section, string key, bool defaultValue=false) {
   defaultValue = defaultValue!=0;

   // Es ist schneller, immer globale und lokale Konfiguration auszuwerten (intern jeweils nur ein Aufruf von GetPrivateProfileString()).
   bool result = GetGlobalConfigBool(section, key, defaultValue);
        result = GetLocalConfigBool (section, key, result);
   return(result);
}


/**
 * Gibt einen globalen Konfigurationswert als Boolean zurück.
 *
 * Der Wert kann als "0" oder "1", "On" oder "Off", "Yes" oder "No" und "true" oder "false" angegeben werden (ohne Beachtung
 * von Groß-/Kleinschreibung). Ein leerer Wert eines existierenden Schlüssels wird als FALSE und ein numerischer Wert als
 * TRUE interpretiert, wenn sein Zahlenwert ungleich 0 (zero) ist.
 *
 * @param  string section      - Name des Konfigurationsabschnittes
 * @param  string key          - Konfigurationsschlüssel
 * @param  bool   defaultValue - Rückgabewert, falls der angegebene Schlüssel nicht existiert
 *
 * @return bool - Konfigurationswert (der Konfiguration folgende Kommentare werden ignoriert)
 */
bool GetGlobalConfigBool(string section, string key, bool defaultValue=false) {
   defaultValue = defaultValue!=0;

   string globalConfig = GetGlobalConfigPath();
      if (globalConfig == "") return(false);
   return(GetIniBool(globalConfig, section, key, defaultValue));
}


/**
 * Gibt einen lokalen Konfigurationswert als Boolean zurück.
 *
 * Der Wert kann als "0" oder "1", "On" oder "Off", "Yes" oder "No" und "true" oder "false" angegeben werden (ohne Beachtung
 * von Groß-/Kleinschreibung). Ein leerer Wert eines existierenden Schlüssels wird als FALSE und ein numerischer Wert als
 * TRUE interpretiert, wenn sein Zahlenwert ungleich 0 (zero) ist.
 *
 * @param  string section      - Name des Konfigurationsabschnittes
 * @param  string key          - Konfigurationsschlüssel
 * @param  bool   defaultValue - Rückgabewert, falls der angegebene Schlüssel nicht existiert
 *
 * @return bool - Konfigurationswert (der Konfiguration folgende Kommentare werden ignoriert)
 */
bool GetLocalConfigBool(string section, string key, bool defaultValue=false) {
   defaultValue = defaultValue!=0;

   string localConfig = GetLocalConfigPath();
      if (localConfig == "") return(false);
   return(GetIniBool(localConfig, section, key, defaultValue));
}
