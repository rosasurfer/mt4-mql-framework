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


/**
 * Return a configuration value as a boolean from any of the configurations. Supported boolean value representations are "1"
 * and "0", "true" and "false", "on" and "off", "yes" and "no" (all case-insensitive). A numerical value evaluates to
 * ({value} != 0), all other values evaluate to (FALSE). Trailing comments are ignored.
 *
 * @param  string section                 - configuration section name
 * @param  string key                     - configuration key
 * @param  bool   defaultValue [optional] - value to return if the specified key does not exist (default: FALSE)
 *
 * @return bool - configuration value
 */
bool GetConfigBool(string section, string key, bool defaultValue = false) {
   defaultValue = defaultValue!=0;

   bool globalResult  = GetGlobalConfigBool (section, key, defaultValue);
   bool localResult   = GetLocalConfigBool  (section, key, globalResult);
   bool accountResult = GetAccountConfigBool(section, key, localResult);

   return(accountResult);
}


/**
 * Return a global configuration value as a boolean. Supported boolean value representations are "1" and "0", "true" and
 * "false", "on" and "off", "yes" and "no" (all case-insensitive). A numerical value evaluates to ({value} != 0), all other
 * values evaluate to (FALSE). Trailing comments are ignored.
 *
 * @param  string section                 - configuration section name
 * @param  string key                     - configuration key
 * @param  bool   defaultValue [optional] - value to return if the specified key does not exist (default: FALSE)
 *
 * @return bool - configuration value
 */
bool GetGlobalConfigBool(string section, string key, bool defaultValue = false) {
   defaultValue = defaultValue!=0;

   string globalConfig = GetGlobalConfigPath();
   if (!StringLen(globalConfig))
      return(false);
   return(GetIniBool(globalConfig, section, key, defaultValue));
}


/**
 * Return a local configuration value as a boolean. Supported boolean value representations are "1" and "0", "true" and
 * "false", "on" and "off", "yes" and "no" (all case-insensitive). A numerical value evaluates to ({value} != 0), all other
 * values evaluate to (FALSE). Trailing comments are ignored.
 *
 * @param  string section                 - configuration section name
 * @param  string key                     - configuration key
 * @param  bool   defaultValue [optional] - value to return if the specified key does not exist (default: FALSE)
 *
 * @return bool - configuration value
 */
bool GetLocalConfigBool(string section, string key, bool defaultValue = false) {
   defaultValue = defaultValue!=0;

   string localConfig = GetLocalConfigPath();
   if (!StringLen(localConfig))
      return(false);
   return(GetIniBool(localConfig, section, key, defaultValue));
}


/**
 * Return an account configuration value as a boolean. Supported boolean value representations are "1" and "0", "true" and
 * "false", "on" and "off", "yes" and "no" (all case-insensitive). A numerical value evaluates to ({value} != 0), all other
 * values evaluate to (FALSE). Trailing comments are ignored.
 *
 * @param  string section                 - configuration section name
 * @param  string key                     - configuration key
 * @param  bool   defaultValue [optional] - value to return if the specified key does not exist (default: FALSE)
 *
 * @return bool - configuration value
 */
bool GetAccountConfigBool(string section, string key, bool defaultValue = false) {
   defaultValue = defaultValue!=0;

   string accountConfig = GetAccountConfigPath();
   if (!StringLen(accountConfig))
      return(false);
   return(GetIniBool(accountConfig, section, key, defaultValue));
}
