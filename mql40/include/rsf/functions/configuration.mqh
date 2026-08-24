/**
 * Return the full name of the framework's trading account configuration file.
 *
 * - This configuration file is used if the terminal is logged-in to that trading account.
 * - The file is named "rsf-account-{number}-config.ini" and is located in the terminal's common data folder.
 * - No attempt is made to create a non-existing file.
 * - An existing legacy config file "{number}-config.ini" is renamed to the new name.
 *
 * @param  string company [optional] - account company as returned by GetAccountCompanyId() (default: the current company id)
 * @param  int    account [optional] - account number (default: the current account number)
 *
 * @return string - file name or an empty string in case of errors,
 *                  e.g. "%UserProfile%\AppData\Roaming\MetaQuotes\Terminal\Common\{AccountCompany}\rsf-account-123456-config.ini"
 */
string GetAccountConfigPath(string company = "", int account = NULL) {
   if (company=="" || company=="0") {
      company = GetAccountCompanyId();
      if (company == "") return("");
   }
   if (account < 0) return(_EMPTY_STR(catch("GetAccountConfigPath(2)  invalid parameter account: "+ account, ERR_INVALID_PARAMETER)));
   if (!account) account = GetAccountNumber();
   if (!account) return("");

   string commonDataPath = GetTerminalCommonDataPathA();
   if (commonDataPath == "") return("");

   string configPath = StringConcatenate(commonDataPath, "\\accounts\\", company, "\\rsf-account-", account, "-config.ini");

   if (!IsFile(configPath)) {
      string legacyPath = StringConcatenate(commonDataPath, "\\accounts\\", company, "\\", account, "-config.ini");

      if (IsFile(legacyPath)) {                       // rename legacy file to new name
         if (MoveFileExA(legacyPath, configPath, MOVEFILE_REPLACE_EXISTING|MOVEFILE_WRITE_THROUGH|MOVEFILE_FAIL_IF_NOT_TRACKABLE)) {
            logInfo("renamed \""+ StrRightFrom(legacyPath, "\\", -3) +"\" to \""+ StrRightFrom(configPath, "\\", -3) +"\"");
         }
         else {
            int error = GetLastWin32Error();
            if (error != ERROR_FILE_NOT_FOUND) {      // another thread may have been faster
               // don't use the logger, it may cause recursion
               debug("GetAccountConfigPath(3)  cannot rename \""+ legacyPath +"\" to \""+ configPath +"\"", ERR_WIN32_ERROR + error);
               configPath = legacyPath;               // keep using the legacy file
            }
         }
      }
   }
   return(configPath);
}


/**
 * Whether the specified key exists in the merged configuration.
 *
 * @param  string section - case-insensitive config section name
 * @param  string key     - case-insensitive config key
 *
 * @return bool
 */
bool IsConfigKey(string section, string key) {
   if (IsUserConfigKeyA    (section, key)) return(true);
   if (IsTerminalConfigKeyA(section, key)) return(true);
   if (IsAccountConfigKey  (section, key)) return(true);
   return(false);
}


/**
 * Whether the specified account config key exists.
 *
 * @param  string section - case-insensitive config section name
 * @param  string key     - case-insensitive config key
 *
 * @return bool
 */
bool IsAccountConfigKey(string section, string key) {
   string accountConfig = GetAccountConfigPath();
   if (accountConfig == "" ) return(false);
   return(IsIniKeyA(accountConfig, section, key));
}


/**
 * Return a config value as a boolean from all merged configurations. Supported boolean representations are "1" and "0",
 * "true" and "false", "on" and "off", "yes" and "no" (all case-insensitive). A numerical value evaluates to (value != 0),
 * all other values evaluate to FALSE. Trailing configuration comments are ignored.
 *
 * @param  string section                 - case-insensitive config section name
 * @param  string key                     - case-insensitive config key
 * @param  bool   defaultValue [optional] - value to return if the specified key does not exist (default: FALSE)
 *
 * @return bool - config value or the default value in case of errors
 */
bool GetConfigBool(string section, string key, bool defaultValue = false) {
   defaultValue = defaultValue!=0;

   bool value = GetUserConfigBool    (section, key, defaultValue);
        value = GetTerminalConfigBool(section, key, value);
        value = GetAccountConfigBool (section, key, value);
   return(value);
}


/**
 * Return a user config value as a boolean. Supported boolean representations are "1" and "0", "true" and "false",
 * "on" and "off", "yes" and "no" (all case-insensitive). A numerical value evaluates to (value != 0), all other values
 * evaluate to FALSE. Trailing configuration comments are ignored.
 *
 * @param  string section                 - case-insensitive config section name
 * @param  string key                     - case-insensitive config key
 * @param  bool   defaultValue [optional] - value to return if the specified key does not exist (default: FALSE)
 *
 * @return bool - config value or the default value in case of errors
 */
bool GetUserConfigBool(string section, string key, bool defaultValue = false) {
   defaultValue = defaultValue!=0;

   string userConfig = GetUserConfigPathA();
   if (userConfig == "") return(defaultValue);
   return(GetIniBool(userConfig, section, key, defaultValue));
}


/**
 * Return a terminal config value as a boolean. Supported boolean representations are "1" and "0", "true" and "false",
 * "on" and "off", "yes" and "no" (all case-insensitive). A numerical value evaluates to (value != 0), all other values
 * evaluate to FALSE. Trailing configuration comments are ignored.
 *
 * @param  string section                 - case-insensitive config section name
 * @param  string key                     - case-insensitive config key
 * @param  bool   defaultValue [optional] - value to return if the specified key does not exist (default: FALSE)
 *
 * @return bool - config value or the default value in case of errors
 */
bool GetTerminalConfigBool(string section, string key, bool defaultValue = false) {
   defaultValue = defaultValue!=0;

   string terminalConfig = GetTerminalConfigPathA();
   if (terminalConfig == "") return(defaultValue);
   return(GetIniBool(terminalConfig, section, key, defaultValue));
}


/**
 * Return an account config value as a boolean. Supported boolean representations are "1" and "0", "true" and "false",
 * "on" and "off", "yes" and "no" (all case-insensitive). A numerical value evaluates to (value != 0), all other values
 * evaluate to FALSE. Trailing configuration comments are ignored.
 *
 * @param  string section                 - case-insensitive config section name
 * @param  string key                     - case-insensitive config key
 * @param  bool   defaultValue [optional] - value to return if the specified key does not exist (default: FALSE)
 *
 * @return bool - config value or the default value in case of errors
 */
bool GetAccountConfigBool(string section, string key, bool defaultValue = false) {
   defaultValue = defaultValue!=0;

   string accountConfig = GetAccountConfigPath();
   if (accountConfig == "") return(defaultValue);
   return(GetIniBool(accountConfig, section, key, defaultValue));
}


/**
 * Return a config value as a color from all merged configurations.
 *
 * Supported color representations are:
 *  - web color names (case-insensitive, with and without the prefix "clr"), e.g. "DodgerBlue"
 *    @see  https://www.mql5.com/en/docs/constants/objectconstants/webcolors
 *  - numeric RGB triplets, e.g. "100,150,224"
 *  - trailing configuration comments are ignored
 *
 * @param  string section                 - case-insensitive config section name
 * @param  string key                     - case-insensitive config key
 * @param  color  defaultValue [optional] - value to return if the specified key does not exist (default: CLR_NONE)
 *
 * @return color - config value or the default value in case of errors
 */
color GetConfigColor(string section, string key, color defaultValue = CLR_NONE) {
   color value = GetUserConfigColor    (section, key, defaultValue);
         value = GetTerminalConfigColor(section, key, value);
         value = GetAccountConfigColor (section, key, value);
   return(value);
}


/**
 * Return a user config value as a color.
 *
 * Supported color representations are:
 *  - web color names (case-insensitive, with and without the prefix "clr"), e.g. "DodgerBlue"
 *    @see  https://www.mql5.com/en/docs/constants/objectconstants/webcolors
 *  - numeric RGB triplets, e.g. "100,150,224"
 *  - trailing configuration comments are ignored
 *
 * @param  string section                 - case-insensitive config section name
 * @param  string key                     - case-insensitive config key
 * @param  color  defaultValue [optional] - value to return if the specified key does not exist (default: CLR_NONE)
 *
 * @return color - config value or the default value in case of errors
 */
color GetUserConfigColor(string section, string key, color defaultValue = CLR_NONE) {
   string userConfig = GetUserConfigPathA();
   if (userConfig == "") return(defaultValue);
   return(GetIniColor(userConfig, section, key, defaultValue));
}


/**
 * Return a terminal config value as a color.
 *
 * Supported color representations are:
 *  - web color names (case-insensitive, with and without the prefix "clr"), e.g. "DodgerBlue"
 *    @see  https://www.mql5.com/en/docs/constants/objectconstants/webcolors
 *  - numeric RGB triplets, e.g. "100,150,224"
 *  - trailing configuration comments are ignored
 *
 * @param  string section                 - case-insensitive config section name
 * @param  string key                     - case-insensitive config key
 * @param  color  defaultValue [optional] - value to return if the specified key does not exist (default: CLR_NONE)
 *
 * @return color - config value or the default value in case of errors
 */
color GetTerminalConfigColor(string section, string key, color defaultValue = CLR_NONE) {
   string terminalConfig = GetTerminalConfigPathA();
   if (terminalConfig == "") return(defaultValue);
   return(GetIniColor(terminalConfig, section, key, defaultValue));
}


/**
 * Return an account config value as a color.
 *
 * Supported color representations are:
 *  - web color names (case-insensitive, with and without the prefix "clr"), e.g. "DodgerBlue"
 *    @see  https://www.mql5.com/en/docs/constants/objectconstants/webcolors
 *  - numeric RGB triplets, e.g. "100,150,224"
 *  - trailing configuration comments are ignored
 *
 * @param  string section                 - case-insensitive config section name
 * @param  string key                     - case-insensitive config key
 * @param  color  defaultValue [optional] - value to return if the specified key does not exist (default: CLR_NONE)
 *
 * @return color - config value or the default value in case of errors
 */
color GetAccountConfigColor(string section, string key, color defaultValue = CLR_NONE) {
   string accountConfig = GetAccountConfigPath();
   if (accountConfig == "") return(defaultValue);
   return(GetIniColor(accountConfig, section, key, defaultValue));
}


/**
 * Return a config value as an integer from all merged configurations. An empty value evaluates to 0 (zero).
 * Trailing non-digits and configuration comments are ignored.
 *
 * @param  string section                 - case-insensitive config section name
 * @param  string key                     - case-insensitive config key
 * @param  int    defaultValue [optional] - value to return if the specified key does not exist (default: 0)
 *
 * @return int - config value or the default value in case of errors
 */
int GetConfigInt(string section, string key, int defaultValue = 0) {
   int value = GetUserConfigInt    (section, key, defaultValue);
       value = GetTerminalConfigInt(section, key, value);
       value = GetAccountConfigInt (section, key, value);
   return(value);
}


/**
 * Return a user config value as an integer. An empty value evaluates to 0 (zero).
 * Trailing non-digits and configuration comments are ignored.
 *
 * @param  string section                 - case-insensitive config section name
 * @param  string key                     - case-insensitive config key
 * @param  int    defaultValue [optional] - value to return if the specified key does not exist (default: 0)
 *
 * @return int - config value or the default value in case of errors
 */
int GetUserConfigInt(string section, string key, int defaultValue = 0) {
   string userConfig = GetUserConfigPathA();
   if (userConfig == "") return(defaultValue);
   return(GetIniInt(userConfig, section, key, defaultValue));
}


/**
 * Return a terminal config value as an integer. An empty value evaluates to 0 (zero).
 * Trailing non-digits and configuration comments are ignored.
 *
 * @param  string section                 - case-insensitive config section name
 * @param  string key                     - case-insensitive config key
 * @param  int    defaultValue [optional] - value to return if the specified key does not exist (default: 0)
 *
 * @return int - config value or the default value in case of errors
 */
int GetTerminalConfigInt(string section, string key, int defaultValue = 0) {
   string terminalConfig = GetTerminalConfigPathA();
   if (terminalConfig == "") return(defaultValue);
   return(GetIniInt(terminalConfig, section, key, defaultValue));
}


/**
 * Return an account config value as an integer. An empty value evaluates to 0 (zero).
 * Trailing non-digits and configuration comments are ignored.
 *
 * @param  string section                 - case-insensitive config section name
 * @param  string key                     - case-insensitive config key
 * @param  int    defaultValue [optional] - value to return if the specified key does not exist (default: 0)
 *
 * @return int - config value or the default value in case of errors
 */
int GetAccountConfigInt(string section, string key, int defaultValue = 0) {
   string accountConfig = GetAccountConfigPath();
   if (accountConfig == "") return(defaultValue);
   return(GetIniInt(accountConfig, section, key, defaultValue));
}


/**
 * Return a config value as a double from all merged configurations. An empty value evaluates to 0 (zero).
 * Trailing non-numeric characters and configuration comments are ignored.
 *
 * @param  string section                 - case-insensitive config section name
 * @param  string key                     - case-insensitive config key
 * @param  double defaultValue [optional] - value to return if the specified key does not exist (default: 0)
 *
 * @return double - config value or the default value in case of errors
 */
double GetConfigDouble(string section, string key, double defaultValue = 0) {
   double value = GetUserConfigDouble    (section, key, defaultValue);
          value = GetTerminalConfigDouble(section, key, value);
          value = GetAccountConfigDouble (section, key, value);
   return(value);
}


/**
 * Return a user config value as a double. An empty value evaluates to 0 (zero).
 * Trailing non-numeric characters and configuration comments are ignored.
 *
 * @param  string section                 - case-insensitive config section name
 * @param  string key                     - case-insensitive config key
 * @param  double defaultValue [optional] - value to return if the specified key does not exist (default: 0)
 *
 * @return double - config value or the default value in case of errors
 */
double GetUserConfigDouble(string section, string key, double defaultValue = 0) {
   string userConfig = GetUserConfigPathA();
   if (userConfig == "") return(defaultValue);
   return(GetIniDouble(userConfig, section, key, defaultValue));
}


/**
 * Return a terminal config value as a double. An empty value evaluates to 0 (zero).
 * Trailing non-numeric characters and configuration comments are ignored.
 *
 * @param  string section                 - case-insensitive config section name
 * @param  string key                     - case-insensitive config key
 * @param  double defaultValue [optional] - value to return if the specified key does not exist (default: 0)
 *
 * @return double - config value or the default value in case of errors
 */
double GetTerminalConfigDouble(string section, string key, double defaultValue = 0) {
   string terminalConfig = GetTerminalConfigPathA();
   if (terminalConfig == "") return(defaultValue);
   return(GetIniDouble(terminalConfig, section, key, defaultValue));
}


/**
 * Return an account config value as a double. An empty value evaluates to 0 (zero).
 * Trailing non-numeric characters and configuration comments are ignored.
 *
 * @param  string section                 - case-insensitive config section name
 * @param  string key                     - case-insensitive config key
 * @param  double defaultValue [optional] - value to return if the specified key does not exist (default: 0)
 *
 * @return double - config value or the default value in case of errors
 */
double GetAccountConfigDouble(string section, string key, double defaultValue = 0) {
   string accountConfig = GetAccountConfigPath();
   if (accountConfig == "") return(defaultValue);
   return(GetIniDouble(accountConfig, section, key, defaultValue));
}


/**
 * Return a config value as a string from all merged configurations. Trailing configuration comments are ignored.
 *
 * @param  string section                 - case-insensitive config section name
 * @param  string key                     - case-insensitive config key
 * @param  string defaultValue [optional] - value to return if the specified key does not exist (default: empty string)
 *
 * @return string - config value without trailing white space or the default value in case of errors
 */
string GetConfigString(string section, string key, string defaultValue = "") {
   string value = GetUserConfigString    (section, key, defaultValue);
          value = GetTerminalConfigString(section, key, value);
          value = GetAccountConfigString (section, key, value);
   return(value);
}


/**
 * Return a user config value as a string. Trailing configuration comments are ignored.
 *
 * @param  string section                 - case-insensitive config section name
 * @param  string key                     - case-insensitive config key
 * @param  string defaultValue [optional] - value to return if the specified key does not exist (default: empty string)
 *
 * @return string - config value without trailing white space or the default value in case of errors
 */
string GetUserConfigString(string section, string key, string defaultValue = "") {
   string userConfig = GetUserConfigPathA();
   if (userConfig == "") return(defaultValue);
   return(GetIniStringA(userConfig, section, key, defaultValue));
}


/**
 * Return a terminal config value as a string. Trailing configuration comments are ignored.
 *
 * @param  string section                 - case-insensitive configuration section name
 * @param  string key                     - case-insensitive configuration key
 * @param  string defaultValue [optional] - value to return if the specified key does not exist (default: empty string)
 *
 * @return string - configuration value without trailing white space or the default value in case of errors
 */
string GetTerminalConfigString(string section, string key, string defaultValue = "") {
   string terminalConfig = GetTerminalConfigPathA();
   if (terminalConfig == "") return(defaultValue);
   return(GetIniStringA(terminalConfig, section, key, defaultValue));
}


/**
 * Return an account config value as a string. Trailing configuration comments are ignored.
 *
 * @param  string section                 - case-insensitive config section name
 * @param  string key                     - case-insensitive config key
 * @param  string defaultValue [optional] - value to return if the specified key does not exist (default: empty string)
 *
 * @return string - config value without trailing white space or the default value in case of errors
 */
string GetAccountConfigString(string section, string key, string defaultValue = "") {
   string accountConfig = GetAccountConfigPath();
   if (accountConfig == "") return(defaultValue);
   return(GetIniStringA(accountConfig, section, key, defaultValue));
}


/**
 * Return a config value as a raw string from all merged configurations. Trailing configuration comments are not ignored.
 *
 * @param  string section                 - case-insensitive config section name
 * @param  string key                     - case-insensitive config key
 * @param  string defaultValue [optional] - value to return if the specified key does not exist (default: empty string)
 *
 * @return string - config value without trailing white space or the default value in case of errors
 */
string GetConfigStringRaw(string section, string key, string defaultValue = "") {
   string value = GetUserConfigStringRaw    (section, key, defaultValue);
          value = GetTerminalConfigStringRaw(section, key, value);
          value = GetAccountConfigStringRaw (section, key, value);
   return(value);
}


/**
 * Return a user config value as a raw string. Trailing configuration comments are not ignored.
 *
 * @param  string section                 - case-insensitive config section name
 * @param  string key                     - case-insensitive config key
 * @param  string defaultValue [optional] - value to return if the specified key does not exist (default: empty string)
 *
 * @return string - config value without trailing white space or the default value in case of errors
 */
string GetUserConfigStringRaw(string section, string key, string defaultValue = "") {
   string userConfig = GetUserConfigPathA();
   if (userConfig == "") return(defaultValue);
   return(GetIniStringRawA(userConfig, section, key, defaultValue));
}


/**
 * Return a terminal config value as a raw string. Trailing configuration comments are not ignored.
 *
 * @param  string section                 - case-insensitive config section name
 * @param  string key                     - case-insensitive config key
 * @param  string defaultValue [optional] - value to return if the specified key does not exist (default: empty string)
 *
 * @return string - config value without trailing white space or the default value in case of errors
 */
string GetTerminalConfigStringRaw(string section, string key, string defaultValue = "") {
   string terminalConfig = GetTerminalConfigPathA();
   if (terminalConfig == "") return(defaultValue);
   return(GetIniStringRawA(terminalConfig, section, key, defaultValue));
}


/**
 * Return an account config value as a raw string. Trailing configuration comments are not ignored.
 *
 * @param  string section                 - case-insensitive config section name
 * @param  string key                     - case-insensitive config key
 * @param  string defaultValue [optional] - value to return if the specified key does not exist (default: empty string)
 *
 * @return string - config value without trailing white space or the default value in case of errors
 */
string GetAccountConfigStringRaw(string section, string key, string defaultValue = "") {
   string accountConfig = GetAccountConfigPath();
   if (accountConfig == "") return(defaultValue);
   return(GetIniStringRawA(accountConfig, section, key, defaultValue));
}


/**
 * Return a config value from an .ini file as a boolean. Supported boolean representations are "1" and "0", true" and "false",
 * "on" and "off", "yes" and "no" (all case-insensitive). A numerical value evaluates to (value != 0), all other values
 * evaluate to FALSE. If the configured value is empty the default value is returned.
 * Trailing configuration comments are ignored.
 *
 * @param  string fileName                - name of the .ini file
 * @param  string section                 - case-insensitive config section name
 * @param  string key                     - case-insensitive config key
 * @param  bool   defaultValue [optional] - value to return if the specified key does not exist (default: FALSE)
 *
 * @return bool - config value
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
 * Return a config value from an .ini file as a color. If the configured value is empty the default value is
 * returned. Trailing configuration comments are ignored.
 *
 * @param  string fileName                - name of the .ini file
 * @param  string section                 - case-insensitive config section name
 * @param  string key                     - case-insensitive config key
 * @param  color  defaultValue [optional] - value to return if the specified key does not exist (default: CLR_NONE)
 *
 * @return color - config value
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
 * Return a config value from an .ini file as an integer. If the configured value is empty the default value is
 * returned. Trailing non-digits and configuration comments are ignored.
 *
 * @param  string fileName                - name of the .ini file
 * @param  string section                 - case-insensitive config section name
 * @param  string key                     - case-insensitive config key
 * @param  int    defaultValue [optional] - value to return if the specified key does not exist (default: 0)
 *
 * @return int - config value
 */
int GetIniInt(string fileName, string section, string key, int defaultValue = 0) {
   return(GetPrivateProfileIntA(section, key, defaultValue, fileName));
}


/**
 * Return a config value from an .ini file as a double. If the configured value is empty the default value is
 * returned. Trailing non-numerical characters and configuration comments are ignored.
 *
 * @param  string fileName                - name of the .ini file
 * @param  string section                 - case-insensitive config section name
 * @param  string key                     - case-insensitive config key
 * @param  double defaultValue [optional] - value to return if the specified key does not exist (default: 0)
 *
 * @return double - config value
 */
double GetIniDouble(string fileName, string section, string key, double defaultValue = 0) {
   string value = GetIniStringA(fileName, section, key, "");
   if (value == "") return(defaultValue);
   return(StrToDouble(value));
}


/**
 * Write a config value to an .ini file. If the file does not exist an attempt is made to create it.
 *
 * @param  string fileName - name of the file (with any extension)
 * @param  string section  - case-insensitive config section name
 * @param  string key      - case-insensitive config key
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

         if (directory != name) /*&&*/ if (!IsDirectory(directory)) {
            error = CreateDirectoryA(directory, MODE_SYSTEM|MODE_MKPARENT);
            if (IsError(error)) return(!catch("WriteIniString(1)  cannot create directory \""+ directory +"\"", error));
            return(WriteIniString(fileName, section, key, value));
         }
      }
      return(!catch("WriteIniString(2)->WritePrivateProfileStringA(fileName=\""+ fileName +"\")", ERR_WIN32_ERROR+error));
   }
   return(true);
}


#import "kernel32.dll"
   bool MoveFileExA(string lpOldName, string lpNewName, int flags);
#import
