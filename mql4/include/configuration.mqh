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
 * Whether or not the specified key exists in the merged configuration.
 *
 * @param  string section - case-insensitive configuration section name
 * @param  string key     - case-insensitive configuration key
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
 * @param  string section - case-insensitive configuration section name
 * @param  string key     - case-insensitive configuration key
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
 * @param  string section - case-insensitive configuration section name
 * @param  string key     - case-insensitive configuration key
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
 * @param  string section - case-insensitive configuration section name
 * @param  string key     - case-insensitive configuration key
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
 * Return a configuration value as a boolean from the merged configuration. Supported boolean value representations are "1"
 * and "0", "true" and "false", "on" and "off", "yes" and "no" (all case-insensitive). A numerical value evaluates to
 * ({value} != 0), all other values evaluate to (FALSE). In-line comments are ignored.
 *
 * @param  string section                 - case-insensitive configuration section name
 * @param  string key                     - case-insensitive configuration key
 * @param  bool   defaultValue [optional] - value to return if the specified key does not exist (default: FALSE)
 *
 * @return bool - configuration value
 */
bool GetConfigBool(string section, string key, bool defaultValue = false) {
   defaultValue = defaultValue!=0;

   bool value = GetGlobalConfigBool (section, key, defaultValue);
        value = GetLocalConfigBool  (section, key, value);
        value = GetAccountConfigBool(section, key, value);
   return(value);
}


/**
 * Return a global configuration value as a boolean. Supported boolean value representations are "1" and "0", "true" and
 * "false", "on" and "off", "yes" and "no" (all case-insensitive). A numerical value evaluates to ({value} != 0), all other
 * values evaluate to (FALSE). In-line comments are ignored.
 *
 * @param  string section                 - case-insensitive configuration section name
 * @param  string key                     - case-insensitive configuration key
 * @param  bool   defaultValue [optional] - value to return if the specified key does not exist (default: FALSE)
 *
 * @return bool - configuration value
 */
bool GetGlobalConfigBool(string section, string key, bool defaultValue = false) {
   defaultValue = defaultValue!=0;

   string globalConfig = GetGlobalConfigPath();
   if (!StringLen(globalConfig))
      return(defaultValue);
   return(GetIniBool(globalConfig, section, key, defaultValue));
}


/**
 * Return a local configuration value as a boolean. Supported boolean value representations are "1" and "0", "true" and
 * "false", "on" and "off", "yes" and "no" (all case-insensitive). A numerical value evaluates to ({value} != 0), all other
 * values evaluate to (FALSE). In-line comments are ignored.
 *
 * @param  string section                 - case-insensitive configuration section name
 * @param  string key                     - case-insensitive configuration key
 * @param  bool   defaultValue [optional] - value to return if the specified key does not exist (default: FALSE)
 *
 * @return bool - configuration value
 */
bool GetLocalConfigBool(string section, string key, bool defaultValue = false) {
   defaultValue = defaultValue!=0;

   string localConfig = GetLocalConfigPath();
   if (!StringLen(localConfig))
      return(defaultValue);
   return(GetIniBool(localConfig, section, key, defaultValue));
}


/**
 * Return an account configuration value as a boolean. Supported boolean value representations are "1" and "0", "true" and
 * "false", "on" and "off", "yes" and "no" (all case-insensitive). A numerical value evaluates to ({value} != 0), all other
 * values evaluate to (FALSE). In-line comments are ignored.
 *
 * @param  string section                 - case-insensitive configuration section name
 * @param  string key                     - case-insensitive configuration key
 * @param  bool   defaultValue [optional] - value to return if the specified key does not exist (default: FALSE)
 *
 * @return bool - configuration value
 */
bool GetAccountConfigBool(string section, string key, bool defaultValue = false) {
   defaultValue = defaultValue!=0;

   string accountConfig = GetAccountConfigPath();
   if (!StringLen(accountConfig))
      return(defaultValue);
   return(GetIniBool(accountConfig, section, key, defaultValue));
}


/**
 * Return a configuration value as an integer from the merged configuration. An empty value evaluates to 0 (zero).
 * Trailing non-digits and in-line comments are ignored.
 *
 * @param  string section                 - case-insensitive configuration section name
 * @param  string key                     - case-insensitive configuration key
 * @param  int    defaultValue [optional] - value to return if the specified key does not exist (default: 0)
 *
 * @return int - configuration value
 */
int GetConfigInt(string section, string key, int defaultValue = 0) {
   int value = GetGlobalConfigInt (section, key, defaultValue);
       value = GetLocalConfigInt  (section, key, value);
       value = GetAccountConfigInt(section, key, value);
   return(value);
}


/**
 * Return a global configuration value as an integer. An empty value evaluates to 0 (zero). Trailing non-digits and in-line
 * comments are ignored.
 *
 * @param  string section                 - case-insensitive configuration section name
 * @param  string key                     - case-insensitive configuration key
 * @param  int    defaultValue [optional] - value to return if the specified key does not exist (default: 0)
 *
 * @return int - configuration value
 */
int GetGlobalConfigInt(string section, string key, int defaultValue = 0) {
   string globalConfig = GetGlobalConfigPath();
   if (!StringLen(globalConfig))
      return(defaultValue);
   return(GetIniInt(globalConfig, section, key, defaultValue));
}


/**
 * Return a local configuration value as an integer. An empty value evaluates to 0 (zero). Trailing non-digits and in-line
 * comments are ignored.
 *
 * @param  string section                 - case-insensitive configuration section name
 * @param  string key                     - case-insensitive configuration key
 * @param  int    defaultValue [optional] - value to return if the specified key does not exist (default: 0)
 *
 * @return int - configuration value
 */
int GetLocalConfigInt(string section, string key, int defaultValue = 0) {
   string localConfig = GetLocalConfigPath();
   if (!StringLen(localConfig))
      return(defaultValue);
   return(GetIniInt(localConfig, section, key, defaultValue));
}


/**
 * Return an account configuration value as an integer. An empty value evaluates to 0 (zero). Trailing non-digits and in-line
 * comments are ignored.
 *
 * @param  string section                 - case-insensitive configuration section name
 * @param  string key                     - case-insensitive configuration key
 * @param  int    defaultValue [optional] - value to return if the specified key does not exist (default: 0)
 *
 * @return int - configuration value
 */
int GetAccountConfigInt(string section, string key, int defaultValue = 0) {
   string accountConfig = GetAccountConfigPath();
   if (!StringLen(accountConfig))
      return(defaultValue);
   return(GetIniInt(accountConfig, section, key, defaultValue));
}


/**
 * Return a configuration value as a double from the merged configuration. An empty value evaluates to 0 (zero).
 * Trailing non-numeric characters and in-line comments are ignored.
 *
 * @param  string section                 - case-insensitive configuration section name
 * @param  string key                     - case-insensitive configuration key
 * @param  double defaultValue [optional] - value to return if the specified key does not exist (default: 0)
 *
 * @return double - configuration value
 */
double GetConfigDouble(string section, string key, double defaultValue = 0) {
   double value = GetGlobalConfigDouble (section, key, defaultValue);
          value = GetLocalConfigDouble  (section, key, value);
          value = GetAccountConfigDouble(section, key, value);
   return(value);
}


/**
 * Return a global configuration value as a double. An empty value evaluates to 0 (zero). Trailing non-numeric characters and
 * in-line comments are ignored.
 *
 * @param  string section                 - case-insensitive configuration section name
 * @param  string key                     - case-insensitive configuration key
 * @param  double defaultValue [optional] - value to return if the specified key does not exist (default: 0)
 *
 * @return double - configuration value
 */
double GetGlobalConfigDouble(string section, string key, double defaultValue = 0) {
   string globalConfig = GetGlobalConfigPath();
   if (!StringLen(globalConfig))
      return(defaultValue);
   return(GetIniDouble(globalConfig, section, key, defaultValue));
}


/**
 * Return a local configuration value as a double. An empty value evaluates to 0 (zero). Trailing non-numeric characters and
 * in-line comments are ignored.
 *
 * @param  string section                 - case-insensitive configuration section name
 * @param  string key                     - case-insensitive configuration key
 * @param  double defaultValue [optional] - value to return if the specified key does not exist (default: 0)
 *
 * @return double - configuration value
 */
double GetLocalConfigDouble(string section, string key, double defaultValue = 0) {
   string localConfig = GetLocalConfigPath();
   if (!StringLen(localConfig))
      return(defaultValue);
   return(GetIniDouble(localConfig, section, key, defaultValue));
}


/**
 * Return an account configuration value as a double. An empty value evaluates to 0 (zero). Trailing non-numeric characters
 * and in-line comments are ignored.
 *
 * @param  string section                 - case-insensitive configuration section name
 * @param  string key                     - case-insensitive configuration key
 * @param  double defaultValue [optional] - value to return if the specified key does not exist (default: 0)
 *
 * @return double - configuration value
 */
double GetAccountConfigDouble(string section, string key, double defaultValue = 0) {
   string accountConfig = GetAccountConfigPath();
   if (!StringLen(accountConfig))
      return(defaultValue);
   return(GetIniDouble(accountConfig, section, key, defaultValue));
}


/**
 * Return a configuration value as a string from the merged configuration. In-line comments are ignored.
 *
 * @param  string section                 - case-insensitive configuration section name
 * @param  string key                     - case-insensitive configuration key
 * @param  string defaultValue [optional] - value to return if the specified key does not exist (default: empty string)
 *
 * @return string - configuration value with trailing white space removed
 */
string GetConfigString(string section, string key, string defaultValue = "") {
   string value = GetGlobalConfigString (section, key, defaultValue);
          value = GetLocalConfigString  (section, key, value);
          value = GetAccountConfigString(section, key, value);
   return(value);
}


/**
 * Return a global configuration value as a string. In-line comments are ignored.
 *
 * @param  string section                 - case-insensitive configuration section name
 * @param  string key                     - case-insensitive configuration key
 * @param  string defaultValue [optional] - value to return if the specified key does not exist (default: empty string)
 *
 * @return string - configuration value with trailing white space removed
 */
string GetGlobalConfigString(string section, string key, string defaultValue = "") {
   string globalConfig = GetGlobalConfigPath();
   if (!StringLen(globalConfig))
      return(defaultValue);
   return(GetIniString(globalConfig, section, key, defaultValue));
}


/**
 * Return a local configuration value as a string. In-line comments are ignored.
 *
 * @param  string section                 - case-insensitive configuration section name
 * @param  string key                     - case-insensitive configuration key
 * @param  string defaultValue [optional] - value to return if the specified key does not exist (default: empty string)
 *
 * @return string - configuration value with trailing white space removed
 */
string GetLocalConfigString(string section, string key, string defaultValue = "") {
   string localConfig = GetLocalConfigPath();
   if (!StringLen(localConfig))
      return(defaultValue);
   return(GetIniString(localConfig, section, key, defaultValue));
}


/**
 * Return an account configuration value as a string. In-line comments are ignored.
 *
 * @param  string section                 - case-insensitive configuration section name
 * @param  string key                     - case-insensitive configuration key
 * @param  string defaultValue [optional] - value to return if the specified key does not exist (default: empty string)
 *
 * @return string - configuration value with trailing white space removed
 */
string GetAccountConfigString(string section, string key, string defaultValue = "") {
   string accountConfig = GetAccountConfigPath();
   if (!StringLen(accountConfig))
      return(defaultValue);
   return(GetIniString(accountConfig, section, key, defaultValue));
}


/**
 * Return a configuration value as a string from the merged configuration. In-line comments are not removed.
 *
 * @param  string section                 - case-insensitive configuration section name
 * @param  string key                     - case-insensitive configuration key
 * @param  string defaultValue [optional] - value to return if the specified key does not exist (default: empty string)
 *
 * @return string - configuration value with trailing white space removed
 */
string GetConfigStringRaw(string section, string key, string defaultValue = "") {
   string value = GetGlobalConfigStringRaw (section, key, defaultValue);
          value = GetLocalConfigStringRaw  (section, key, value);
          value = GetAccountConfigStringRaw(section, key, value);
   return(value);
}


/**
 * Return a global configuration value as a string. In-line comments are not removed.
 *
 * @param  string section                 - case-insensitive configuration section name
 * @param  string key                     - case-insensitive configuration key
 * @param  string defaultValue [optional] - value to return if the specified key does not exist (default: empty string)
 *
 * @return string - configuration value with trailing white space removed
 */
string GetGlobalConfigStringRaw(string section, string key, string defaultValue = "") {
   string globalConfig = GetGlobalConfigPath();
   if (!StringLen(globalConfig))
      return(defaultValue);
   return(GetIniStringRaw(globalConfig, section, key, defaultValue));
}


/**
 * Return a local configuration value as a string. In-line comments are not removed.
 *
 * @param  string section                 - case-insensitive configuration section name
 * @param  string key                     - case-insensitive configuration key
 * @param  string defaultValue [optional] - value to return if the specified key does not exist (default: empty string)
 *
 * @return string - configuration value with trailing white space removed
 */
string GetLocalConfigStringRaw(string section, string key, string defaultValue = "") {
   string localConfig = GetLocalConfigPath();
   if (!StringLen(localConfig))
      return(defaultValue);
   return(GetIniStringRaw(localConfig, section, key, defaultValue));
}


/**
 * Return an account configuration value as a string. In-line comments are not removed.
 *
 * @param  string section                 - case-insensitive configuration section name
 * @param  string key                     - case-insensitive configuration key
 * @param  string defaultValue [optional] - value to return if the specified key does not exist (default: empty string)
 *
 * @return string - configuration value with trailing white space removed
 */
string GetAccountConfigStringRaw(string section, string key, string defaultValue = "") {
   string accountConfig = GetAccountConfigPath();
   if (!StringLen(accountConfig))
      return(defaultValue);
   return(GetIniStringRaw(accountConfig, section, key, defaultValue));
}
