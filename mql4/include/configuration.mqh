/**
 * Functions for querying the application configuration.
 */


/**
 * Return the full filename of an account's configuration file.
 *
 * @param  string companyId [optional] - the account's company identifier (default: the current account's short company name)
 * @param  string accountId [optional] - the account's id; depending on the company an account number or an alias
 *                                       (default: the current account number)
 *
 * @return string - filename or an empty string in case of errors
 */
string GetAccountConfigPath(string companyId="", string accountId="") {
   if (!StringLen(companyId) && !StringLen(accountId)) {
      companyId = GetAccountCompanyAlias(); if (!StringLen(companyId)) return(EMPTY_STR);
      accountId = GetAccountNumber();       if (accountId == "0")      return(EMPTY_STR);
   }
   else {
      if (!StringLen(companyId)) return(_EMPTY_STR(catch("GetAccountConfigPath(1)  invalid parameter companyId = "+ DoubleQuoteStr(companyId), ERR_INVALID_PARAMETER)));
      if (!StringLen(accountId)) return(_EMPTY_STR(catch("GetAccountConfigPath(2)  invalid parameter accountId = "+ DoubleQuoteStr(accountId), ERR_INVALID_PARAMETER)));
   }
   return(StringConcatenate(GetTerminalCommonDataPathA(), "\\accounts\\", companyId, "\\", accountId, "-config.ini"));
}


/**
 * Whether the specified key exists in the merged configuration.
 *
 * @param  string section - case-insensitive configuration section name
 * @param  string key     - case-insensitive configuration key
 *
 * @return bool
 */
bool IsConfigKey(string section, string key) {
   if (IsGlobalConfigKeyA(section, key)) return(true);
   if (IsLocalConfigKeyA (section, key)) return(true);
   if (IsAccountConfigKey(section, key)) return(true);
   return(false);
}


/**
 * Whether the specified account configuration key exists.
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
   return(IsIniKeyA(accountConfig, section, key));
}


/**
 * Return a configuration value as a boolean from the merged configuration. Supported boolean value representations are "1"
 * and "0", "true" and "false", "on" and "off", "yes" and "no" (all case-insensitive). A numerical value evaluates to
 * ({value} != 0), all other values evaluate to (FALSE).
 *
 * Fuzzy spelling mistakes (small letter L instead of numeric 1 (one), big letter O instead of numeric 0 (zero) etc.) are
 * detected and interpreted accordingly.
 *
 * Trailing configuration comments are ignored.
 *
 * @param  string section                 - case-insensitive configuration section name
 * @param  string key                     - case-insensitive configuration key
 * @param  bool   defaultValue [optional] - value to return if the specified key does not exist (default: FALSE)
 *
 * @return bool - configuration value or the default value in case of errors
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
 * values evaluate to (FALSE).
 *
 * Fuzzy spelling mistakes (small letter L instead of numeric "one", big letter O instead of numeric "zero") are detected and
 * interpreted accordingly.
 *
 * Trailing configuration comments are ignored.
 *
 * @param  string section                 - case-insensitive configuration section name
 * @param  string key                     - case-insensitive configuration key
 * @param  bool   defaultValue [optional] - value to return if the specified key does not exist (default: FALSE)
 *
 * @return bool - configuration value or the default value in case of errors
 */
bool GetGlobalConfigBool(string section, string key, bool defaultValue = false) {
   defaultValue = defaultValue!=0;

   string globalConfig = GetGlobalConfigPathA();
   if (!StringLen(globalConfig))
      return(defaultValue);
   return(GetIniBool(globalConfig, section, key, defaultValue));
}


/**
 * Return a local configuration value as a boolean. Supported boolean value representations are "1" and "0", "true" and
 * "false", "on" and "off", "yes" and "no" (all case-insensitive). A numerical value evaluates to ({value} != 0), all other
 * values evaluate to (FALSE).
 *
 * Fuzzy spelling mistakes (small letter L instead of numeric "one", big letter O instead of numeric "zero") are detected and
 * interpreted accordingly.
 *
 * Trailing configuration comments are ignored.
 *
 * @param  string section                 - case-insensitive configuration section name
 * @param  string key                     - case-insensitive configuration key
 * @param  bool   defaultValue [optional] - value to return if the specified key does not exist (default: FALSE)
 *
 * @return bool - configuration value or the default value in case of errors
 */
bool GetLocalConfigBool(string section, string key, bool defaultValue = false) {
   defaultValue = defaultValue!=0;

   string localConfig = GetLocalConfigPathA();
   if (!StringLen(localConfig))
      return(defaultValue);
   return(GetIniBool(localConfig, section, key, defaultValue));
}


/**
 * Return an account configuration value as a boolean. Supported boolean value representations are "1" and "0", "true" and
 * "false", "on" and "off", "yes" and "no" (all case-insensitive). A numerical value evaluates to ({value} != 0), all other
 * values evaluate to (FALSE).
 *
 * Fuzzy spelling mistakes (small letter L instead of numeric "one", big letter O instead of numeric "zero") are detected and
 * interpreted accordingly.
 *
 * Trailing configuration comments are ignored.
 *
 * @param  string section                 - case-insensitive configuration section name
 * @param  string key                     - case-insensitive configuration key
 * @param  bool   defaultValue [optional] - value to return if the specified key does not exist (default: FALSE)
 *
 * @return bool - configuration value or the default value in case of errors
 */
bool GetAccountConfigBool(string section, string key, bool defaultValue = false) {
   defaultValue = defaultValue!=0;

   string accountConfig = GetAccountConfigPath();
   if (!StringLen(accountConfig))
      return(defaultValue);
   return(GetIniBool(accountConfig, section, key, defaultValue));
}


/**
 * Return a configuration value as a color from the merged configuration.
 *
 * Supported color representations are:
 *  - web color names (case-insensitive, with and without the prefix "clr"), e.g. "DodgerBlue"
 *    @see  https://www.mql5.com/en/docs/constants/objectconstants/webcolors
 *  - numeric RGB triplets, e.g. "100,150,224"
 *
 * Trailing configuration comments are ignored.
 *
 * @param  string section                 - case-insensitive configuration section name
 * @param  string key                     - case-insensitive configuration key
 * @param  color  defaultValue [optional] - value to return if the specified key does not exist (default: CLR_NONE)
 *
 * @return color - configuration value or the default value in case of errors
 */
color GetConfigColor(string section, string key, color defaultValue = CLR_NONE) {
   color value = GetGlobalConfigColor (section, key, defaultValue);
         value = GetLocalConfigColor  (section, key, value);
         value = GetAccountConfigColor(section, key, value);
   return(value);
}


/**
 * Return a global configuration value as a color.
 *
 * Supported color representations are:
 *  - web color names (case-insensitive, with and without the prefix "clr"), e.g. "DodgerBlue"
 *    @see  https://www.mql5.com/en/docs/constants/objectconstants/webcolors
 *  - numeric RGB triplets, e.g. "100,150,224"
 *
 * Trailing configuration comments are ignored.
 *
 * @param  string section                 - case-insensitive configuration section name
 * @param  string key                     - case-insensitive configuration key
 * @param  color  defaultValue [optional] - value to return if the specified key does not exist (default: CLR_NONE)
 *
 * @return color - configuration value or the default value in case of errors
 */
color GetGlobalConfigColor(string section, string key, color defaultValue = CLR_NONE) {
   string globalConfig = GetGlobalConfigPathA();
   if (!StringLen(globalConfig))
      return(defaultValue);
   return(GetIniColor(globalConfig, section, key, defaultValue));
}


/**
 * Return a local configuration value as a color.
 *
 * Supported color representations are:
 *  - web color names (case-insensitive, with and without the prefix "clr"), e.g. "DodgerBlue"
 *    @see  https://www.mql5.com/en/docs/constants/objectconstants/webcolors
 *  - numeric RGB triplets, e.g. "100,150,224"
 *
 * Trailing configuration comments are ignored.
 *
 * @param  string section                 - case-insensitive configuration section name
 * @param  string key                     - case-insensitive configuration key
 * @param  color  defaultValue [optional] - value to return if the specified key does not exist (default: CLR_NONE)
 *
 * @return color - configuration value or the default value in case of errors
 */
color GetLocalConfigColor(string section, string key, color defaultValue = CLR_NONE) {
   string localConfig = GetLocalConfigPathA();
   if (!StringLen(localConfig))
      return(defaultValue);
   return(GetIniColor(localConfig, section, key, defaultValue));
}


/**
 * Return an account configuration value as a color.
 *
 * Supported color representations are:
 *  - web color names (case-insensitive, with and without the prefix "clr"), e.g. "DodgerBlue"
 *    @see  https://www.mql5.com/en/docs/constants/objectconstants/webcolors
 *  - numeric RGB triplets, e.g. "100,150,224"
 *
 * Trailing configuration comments are ignored.
 *
 * @param  string section                 - case-insensitive configuration section name
 * @param  string key                     - case-insensitive configuration key
 * @param  color  defaultValue [optional] - value to return if the specified key does not exist (default: CLR_NONE)
 *
 * @return color - configuration value or the default value in case of errors
 */
color GetAccountConfigColor(string section, string key, color defaultValue = CLR_NONE) {
   string accountConfig = GetAccountConfigPath();
   if (!StringLen(accountConfig))
      return(defaultValue);
   return(GetIniColor(accountConfig, section, key, defaultValue));
}


/**
 * Return a configuration value as an integer from the merged configuration. An empty value evaluates to 0 (zero).
 *
 * Trailing non-digits and configuration comments are ignored.
 *
 * @param  string section                 - case-insensitive configuration section name
 * @param  string key                     - case-insensitive configuration key
 * @param  int    defaultValue [optional] - value to return if the specified key does not exist (default: 0)
 *
 * @return int - configuration value or the default value in case of errors
 */
int GetConfigInt(string section, string key, int defaultValue = 0) {
   int value = GetGlobalConfigInt (section, key, defaultValue);
       value = GetLocalConfigInt  (section, key, value);
       value = GetAccountConfigInt(section, key, value);
   return(value);
}


/**
 * Return a global configuration value as an integer. An empty value evaluates to 0 (zero). Trailing non-digits and line
 * comments are ignored.
 *
 * @param  string section                 - case-insensitive configuration section name
 * @param  string key                     - case-insensitive configuration key
 * @param  int    defaultValue [optional] - value to return if the specified key does not exist (default: 0)
 *
 * @return int - configuration value or the default value in case of errors
 */
int GetGlobalConfigInt(string section, string key, int defaultValue = 0) {
   string globalConfig = GetGlobalConfigPathA();
   if (!StringLen(globalConfig))
      return(defaultValue);
   return(GetIniInt(globalConfig, section, key, defaultValue));
}


/**
 * Return a local configuration value as an integer. An empty value evaluates to 0 (zero). Trailing non-digits and line
 * comments are ignored.
 *
 * @param  string section                 - case-insensitive configuration section name
 * @param  string key                     - case-insensitive configuration key
 * @param  int    defaultValue [optional] - value to return if the specified key does not exist (default: 0)
 *
 * @return int - configuration value or the default value in case of errors
 */
int GetLocalConfigInt(string section, string key, int defaultValue = 0) {
   string localConfig = GetLocalConfigPathA();
   if (!StringLen(localConfig))
      return(defaultValue);
   return(GetIniInt(localConfig, section, key, defaultValue));
}


/**
 * Return an account configuration value as an integer. An empty value evaluates to 0 (zero). Trailing non-digits and line
 * comments are ignored.
 *
 * @param  string section                 - case-insensitive configuration section name
 * @param  string key                     - case-insensitive configuration key
 * @param  int    defaultValue [optional] - value to return if the specified key does not exist (default: 0)
 *
 * @return int - configuration value or the default value in case of errors
 */
int GetAccountConfigInt(string section, string key, int defaultValue = 0) {
   string accountConfig = GetAccountConfigPath();
   if (!StringLen(accountConfig))
      return(defaultValue);
   return(GetIniInt(accountConfig, section, key, defaultValue));
}


/**
 * Return a configuration value as a double from the merged configuration. An empty value evaluates to 0 (zero).
 *
 * Trailing non-numeric characters and configuration comments are ignored.
 *
 * @param  string section                 - case-insensitive configuration section name
 * @param  string key                     - case-insensitive configuration key
 * @param  double defaultValue [optional] - value to return if the specified key does not exist (default: 0)
 *
 * @return double - configuration value or the default value in case of errors
 */
double GetConfigDouble(string section, string key, double defaultValue = 0) {
   double value = GetGlobalConfigDouble (section, key, defaultValue);
          value = GetLocalConfigDouble  (section, key, value);
          value = GetAccountConfigDouble(section, key, value);
   return(value);
}


/**
 * Return a global configuration value as a double. An empty value evaluates to 0 (zero).
 *
 * Trailing non-numeric characters and configuration comments are ignored.
 *
 * @param  string section                 - case-insensitive configuration section name
 * @param  string key                     - case-insensitive configuration key
 * @param  double defaultValue [optional] - value to return if the specified key does not exist (default: 0)
 *
 * @return double - configuration value or the default value in case of errors
 */
double GetGlobalConfigDouble(string section, string key, double defaultValue = 0) {
   string globalConfig = GetGlobalConfigPathA();
   if (!StringLen(globalConfig))
      return(defaultValue);
   return(GetIniDouble(globalConfig, section, key, defaultValue));
}


/**
 * Return a local configuration value as a double. An empty value evaluates to 0 (zero).
 *
 * Trailing non-numeric characters and configuration comments are ignored.
 *
 * @param  string section                 - case-insensitive configuration section name
 * @param  string key                     - case-insensitive configuration key
 * @param  double defaultValue [optional] - value to return if the specified key does not exist (default: 0)
 *
 * @return double - configuration value or the default value in case of errors
 */
double GetLocalConfigDouble(string section, string key, double defaultValue = 0) {
   string localConfig = GetLocalConfigPathA();
   if (!StringLen(localConfig))
      return(defaultValue);
   return(GetIniDouble(localConfig, section, key, defaultValue));
}


/**
 * Return an account configuration value as a double. An empty value evaluates to 0 (zero).
 *
 * Trailing non-numeric characters and configuration comments are ignored.
 *
 * @param  string section                 - case-insensitive configuration section name
 * @param  string key                     - case-insensitive configuration key
 * @param  double defaultValue [optional] - value to return if the specified key does not exist (default: 0)
 *
 * @return double - configuration value or the default value in case of errors
 */
double GetAccountConfigDouble(string section, string key, double defaultValue = 0) {
   string accountConfig = GetAccountConfigPath();
   if (!StringLen(accountConfig))
      return(defaultValue);
   return(GetIniDouble(accountConfig, section, key, defaultValue));
}


/**
 * Return a configuration value as a string from the merged configuration.
 *
 * Trailing configuration comments are ignored.
 *
 * @param  string section                 - case-insensitive configuration section name
 * @param  string key                     - case-insensitive configuration key
 * @param  string defaultValue [optional] - value to return if the specified key does not exist (default: empty string)
 *
 * @return string - configuration value without trailing white space or the default value in case of errors
 */
string GetConfigString(string section, string key, string defaultValue = "") {
   string value = GetGlobalConfigString (section, key, defaultValue);
          value = GetLocalConfigString  (section, key, value);
          value = GetAccountConfigString(section, key, value);
   return(value);
}


/**
 * Return a global configuration value as a string.
 *
 * Trailing configuration comments are ignored.
 *
 * @param  string section                 - case-insensitive configuration section name
 * @param  string key                     - case-insensitive configuration key
 * @param  string defaultValue [optional] - value to return if the specified key does not exist (default: empty string)
 *
 * @return string - configuration value without trailing white space or the default value in case of errors
 */
string GetGlobalConfigString(string section, string key, string defaultValue = "") {
   string globalConfig = GetGlobalConfigPathA();
   if (!StringLen(globalConfig))
      return(defaultValue);
   return(GetIniStringA(globalConfig, section, key, defaultValue));
}


/**
 * Return a local configuration value as a string.
 *
 * Trailing configuration comments are ignored.
 *
 * @param  string section                 - case-insensitive configuration section name
 * @param  string key                     - case-insensitive configuration key
 * @param  string defaultValue [optional] - value to return if the specified key does not exist (default: empty string)
 *
 * @return string - configuration value without trailing white space or the default value in case of errors
 */
string GetLocalConfigString(string section, string key, string defaultValue = "") {
   string localConfig = GetLocalConfigPathA();
   if (!StringLen(localConfig))
      return(defaultValue);
   return(GetIniStringA(localConfig, section, key, defaultValue));
}


/**
 * Return an account configuration value as a string.
 *
 * Trailing configuration comments are ignored.
 *
 * @param  string section                 - case-insensitive configuration section name
 * @param  string key                     - case-insensitive configuration key
 * @param  string defaultValue [optional] - value to return if the specified key does not exist (default: empty string)
 *
 * @return string - configuration value without trailing white space or the default value in case of errors
 */
string GetAccountConfigString(string section, string key, string defaultValue = "") {
   string accountConfig = GetAccountConfigPath();
   if (!StringLen(accountConfig))
      return(defaultValue);
   return(GetIniStringA(accountConfig, section, key, defaultValue));
}


/**
 * Return a configuration value as a string from the merged configuration.
 *
 * Trailing configuration comments are not removed.
 *
 * @param  string section                 - case-insensitive configuration section name
 * @param  string key                     - case-insensitive configuration key
 * @param  string defaultValue [optional] - value to return if the specified key does not exist (default: empty string)
 *
 * @return string - configuration value without trailing white space or the default value in case of errors
 */
string GetConfigStringRaw(string section, string key, string defaultValue = "") {
   string value = GetGlobalConfigStringRaw (section, key, defaultValue);
          value = GetLocalConfigStringRaw  (section, key, value);
          value = GetAccountConfigStringRaw(section, key, value);
   return(value);
}


/**
 * Return a global configuration value as a string.
 *
 * Trailing configuration comments are not removed.
 *
 * @param  string section                 - case-insensitive configuration section name
 * @param  string key                     - case-insensitive configuration key
 * @param  string defaultValue [optional] - value to return if the specified key does not exist (default: empty string)
 *
 * @return string - configuration value without trailing white space or the default value in case of errors
 */
string GetGlobalConfigStringRaw(string section, string key, string defaultValue = "") {
   string globalConfig = GetGlobalConfigPathA();
   if (!StringLen(globalConfig))
      return(defaultValue);
   return(GetIniStringRawA(globalConfig, section, key, defaultValue));
}


/**
 * Return a local configuration value as a string.
 *
 * Trailing configuration comments are not removed.
 *
 * @param  string section                 - case-insensitive configuration section name
 * @param  string key                     - case-insensitive configuration key
 * @param  string defaultValue [optional] - value to return if the specified key does not exist (default: empty string)
 *
 * @return string - configuration value without trailing white space or the default value in case of errors
 */
string GetLocalConfigStringRaw(string section, string key, string defaultValue = "") {
   string localConfig = GetLocalConfigPathA();
   if (!StringLen(localConfig))
      return(defaultValue);
   return(GetIniStringRawA(localConfig, section, key, defaultValue));
}


/**
 * Return an account configuration value as a string.
 *
 * Trailing configuration comments are not removed.
 *
 * @param  string section                 - case-insensitive configuration section name
 * @param  string key                     - case-insensitive configuration key
 * @param  string defaultValue [optional] - value to return if the specified key does not exist (default: empty string)
 *
 * @return string - configuration value without trailing white space or the default value in case of errors
 */
string GetAccountConfigStringRaw(string section, string key, string defaultValue = "") {
   string accountConfig = GetAccountConfigPath();
   if (!StringLen(accountConfig))
      return(defaultValue);
   return(GetIniStringRawA(accountConfig, section, key, defaultValue));
}


/**
 * Return a configuration value from an .ini file as a boolean. Supported boolean value representations are "1" and "0",
 " true" and "false", "on" and "off", "yes" and "no" (all case-insensitive). A numerical value evaluates to ({value} != 0),
 * all other values evaluate to (FALSE). If the configured value is empty the default value is returned.
 *
 * Trailing configuration comments are ignored.
 *
 * @param  string fileName                - name of the .ini file
 * @param  string section                 - case-insensitive configuration section name
 * @param  string key                     - case-insensitive configuration key
 * @param  bool   defaultValue [optional] - value to return if the specified key does not exist (default: FALSE)
 *
 * @return bool - configuration value
 */
bool GetIniBool(string fileName, string section, string key, bool defaultValue = false) {
   defaultValue = defaultValue!=0;

   string value = GetIniStringA(fileName, section, key, defaultValue);   // (string)(bool) defaultValue

   if (value == "")       return(defaultValue);

   if (value == "0")      return(false);
   if (value == "1")      return(true);

   string lValue = StrToLower(value);
   if (lValue == "on")    return(true);
   if (lValue == "off")   return(false);

   if (lValue == "true")  return(true);
   if (lValue == "false") return(false);

   if (lValue == "yes")   return(true);
   if (lValue == "no")    return(false);

   if (StrIsNumeric(value))
      return(StrToDouble(value) != 0);
   return(defaultValue);
}


/**
 * Return a configuration value from an .ini file as a color. If the configured value is empty the default value is
 * returned.
 *
 * Trailing configuration comments are ignored.
 *
 * @param  string fileName                - name of the .ini file
 * @param  string section                 - case-insensitive configuration section name
 * @param  string key                     - case-insensitive configuration key
 * @param  color  defaultValue [optional] - value to return if the specified key does not exist (default: CLR_NONE)
 *
 * @return color - configuration value
 */
color GetIniColor(string fileName, string section, string key, color defaultValue = CLR_NONE) {
   string value = GetIniStringA(fileName, section, key, "");

   if (value == "") return(defaultValue);

   color clr = NameToColor(value);
   if (clr != NaC) return(clr);

   clr = RGBStrToColor(value);
   if (clr != NaC) return(clr);

   return(defaultValue);
}


/**
 * Return a configuration value from an .ini file as an integer. If the configured value is empty the default value is
 * returned.
 *
 * Trailing non-digits and configuration comments are ignored.
 *
 * @param  string fileName                - name of the .ini file
 * @param  string section                 - case-insensitive configuration section name
 * @param  string key                     - case-insensitive configuration key
 * @param  int    defaultValue [optional] - value to return if the specified key does not exist (default: 0)
 *
 * @return int - configuration value
 */
int GetIniInt(string fileName, string section, string key, int defaultValue = 0) {
   return(GetPrivateProfileIntA(section, key, defaultValue, fileName));
}


/**
 * Return a configuration value from an .ini file as a double. If the configured value is empty the default value is
 * returned.
 *
 * Trailing non-numerical characters and configuration comments are ignored.
 *
 * @param  string fileName                - name of the .ini file
 * @param  string section                 - case-insensitive configuration section name
 * @param  string key                     - case-insensitive configuration key
 * @param  double defaultValue [optional] - value to return if the specified key does not exist (default: 0)
 *
 * @return double - configuration value
 */
double GetIniDouble(string fileName, string section, string key, double defaultValue = 0) {
   string value = GetIniStringA(fileName, section, key, "");
   if (value == "")
      return(defaultValue);
   return(StrToDouble(value));
}


/**
 * Write a configuration value to an .ini file. If the file does not exist an attempt is made to create it.
 *
 * @param  string fileName - name of the file (with any extension)
 * @param  string section  - case-insensitive configuration section name
 * @param  string key      - case-insensitive configuration key
 * @param  string value    - configuration value
 *
 * @return bool - success status
 */
bool WriteIniString(string fileName, string section, string key, string value) {
   if (!WritePrivateProfileStringA(section, key, value, fileName)) {
      int error = GetLastWin32Error();

      if (error == ERROR_PATH_NOT_FOUND) {
         string name = StrReplace(fileName, "\\", "/");
         string directory = StrLeftTo(name, "/", -1);

         if (directory!=name) /*&&*/ if (!IsDirectoryA(directory)) {
            error = CreateDirectoryA(directory, MKDIR_PARENT);
            if (IsError(error)) return(!catch("WriteIniString(1)  cannot create directory "+ DoubleQuoteStr(directory), ERR_WIN32_ERROR+error));
            return(WriteIniString(fileName, section, key, value));
         }
      }
      return(!catch("WriteIniString(2)->WritePrivateProfileString(fileName="+ DoubleQuoteStr(fileName) +")", ERR_WIN32_ERROR+error));
   }
   return(true);
}
