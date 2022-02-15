/**
 * Error reporting and logging
 *
 * +----------------+--------------------------------------------------------------+------------------+
 * | Function       | Functionality                                                | Notes            |
 * +----------------+--------------------------------------------------------------+------------------+
 * | debug()        | send a message to the system debugger                        | no configuration |
 * | catch()        | if (GetLastError()) logFatal() + SetLastError() + STATUS_OFF | error trapping   |
 * +----------------+--------------------------------------------------------------+------------------+
 * | IsLog()        | whether any loglevel is active                               |                  |
 * | IsLogDebug()   | whether LOG_DEBUG is active                                  |                  |
 * | IsLogInfo()    | whether LOG_INFO is active                                   |                  |
 * | IsLogNotice()  | whether LOG_NOTICE is active                                 |                  |
 * | IsLogWarn()    | whether LOG_WARN is active                                   |                  |
 * | IsLogError()   | whether LOG_ERROR is active                                  |                  |
 * | IsLogFatal()   | whether LOG_FATAL is active                                  | always TRUE      |
 * +----------------+--------------------------------------------------------------+------------------+
 * | log()          | dispatch a message to active log appenders                   | configurable     |
 * | logDebug()     | alias of log(..., LOG_DEBUG)                                 |                  |
 * | logInfo()      | alias of log(..., LOG_INFO)                                  |                  |
 * | logNotice()    | alias of log(..., LOG_NOTICE)                                |                  |
 * | logWarn()      | alias of log(..., LOG_WARN)                                  |                  |
 * | logError()     | alias of log(..., LOG_ERROR)                                 |                  |
 * | logFatal()     | alias of log(..., LOG_FATAL)                                 | used by catch()  |
 * +----------------+--------------------------------------------------------------+------------------+
 * | log2Terminal() | TerminalLogAppender                                          | configurable     |
 * | log2Alert()    | TerminalAlertAppender                                        | configurable     |
 * | log2Debugger() | DebugOutputAppender                                          | configurable     |
 * | log2File()     | LogfileAppender                                              | configurable     |
 * | log2Mail()     | MailAppender                                                 | configurable     |
 * | log2SMS()      | SMSAppender                                                  | configurable     |
 * +----------------+--------------------------------------------------------------+------------------+
 * | SetLogfile()   | set a logfile for the LogfileAppender                        | per MQL program  |
 * +----------------+--------------------------------------------------------------+------------------+
 */


/**
 * Send a message to the system debugger.
 *
 * @param  string message             - message
 * @param  int    error    [optional] - error code (default: none)
 * @param  int    loglevel [optional] - loglevel to add to the message (default: debug)
 *
 * @return int - the same error
 */
int debug(string message, int error=NO_ERROR, int loglevel=LOG_DEBUG) {
   // Note: This function must not call MQL library functions. Using DLLs is ok.
   if (!IsDllsAllowed()) {
      Alert("debug(1)  DLLs are not enabled (", message, ", error: ", error, ")");                 // directly alert instead
      return(error);
   }
   static bool isRecursion = false; if (isRecursion) {
      Alert("debug(2)  recursion: ", message, ", error: ", error, ", ", LoglevelToStr(loglevel));  // should never happen
      return(error);
   }
   isRecursion = true;

   // DebugView uses the prefixes "Metatrader" and "Tester" as a message filter
   string sPrefix   = "MetaTrader"; if (This.IsTesting()) sPrefix = StringConcatenate("Tester ", GmtTimeFormat(TimeCurrent(), "%d.%m.%Y %H:%M:%S"));
   string sLoglevel = ""; if (loglevel != LOG_DEBUG) sLoglevel = LoglevelDescription(loglevel);
          sLoglevel = StrPadRight(sLoglevel, 6);
   string sError    = ""; if (error != NO_ERROR) sError = StringConcatenate("  [", ErrorToStr(error), "]");

   OutputDebugStringA(StringConcatenate(sPrefix, " ", sLoglevel, " ", Symbol(), ",", PeriodDescription(), "  ", FullModuleName(), "::", StrReplace(StrReplace(message, NL+NL, NL, true), NL, " "), sError));

   isRecursion = false;
   return(error);
}


/**
 * Check for and handle runtime errors. If an error occurred the error is logged and stored in the global var "last_error".
 * After return the internal MQL error as returned by GetLastError() is always reset.
 *
 * @param  string location            - a possible error's location identifier and/or an error message
 * @param  int    error    [optional] - trigger a specific error (default: no)
 * @param  bool   popOrder [optional] - whether the last order context on the order stack should be restored (default: no)
 *
 * @return int - the same error
 */
int catch(string location, int error=NO_ERROR, bool popOrder=false) {
   popOrder = popOrder!=0;
   if      (!error                  ) { error  =                      GetLastError(); }
   else if (error == ERR_WIN32_ERROR) { error += GetLastWin32Error(); GetLastError(); }
   else                               {                               GetLastError(); }
   static bool isRecursion = false;

   if (error != 0) {
      if (isRecursion) {
         Alert("catch(1)  recursion: ", location, ", error: ", error);        // should never happen
         return(debug("catch(1)  recursion: "+ location, error, LOG_ERROR));
      }
      isRecursion = true;

      logFatal(location, error);                                              // handle the error
      SetLastError(error);                                                    // set the error
   }

   if (popOrder) OrderPop(location);
   isRecursion = false;
   return(error);
}


/**
 * Whether logging is enabled for the current program. Fatal errors will always be logged, even if logging is disabled.
 *
 * @return bool
 */
bool IsLog() {
   int loglevel = __ExecutionContext[EC.loglevel];
   if (!loglevel) loglevel = log("", NULL, LOG_OFF);
   return(loglevel && loglevel < LOG_OFF);
}


/**
 * Whether the loglevel LOG_DEBUG is active for the current program.
 *
 * @return bool
 */
bool IsLogDebug() {
   int loglevel = __ExecutionContext[EC.loglevel];
   if (!loglevel) loglevel = log("", NULL, LOG_OFF);
   return(loglevel && loglevel <= LOG_DEBUG);
}


/**
 * Whether the loglevel LOG_INFO is active for the current program.
 *
 * @return bool
 */
bool IsLogInfo() {
   int loglevel = __ExecutionContext[EC.loglevel];
   if (!loglevel) loglevel = log("", NULL, LOG_OFF);
   return(loglevel && loglevel <= LOG_INFO);
}


/**
 * Whether the loglevel LOG_NOTICE is active for the current program.
 *
 * @return bool
 */
bool IsLogNotice() {
   int loglevel = __ExecutionContext[EC.loglevel];
   if (!loglevel) loglevel = log("", NULL, LOG_OFF);
   return(loglevel && loglevel <= LOG_NOTICE);
}


/**
 * Whether the loglevel LOG_WARN is active for the current program.
 *
 * @return bool
 */
bool IsLogWarn() {
   int loglevel = __ExecutionContext[EC.loglevel];
   if (!loglevel) loglevel = log("", NULL, LOG_OFF);
   return(loglevel && loglevel <= LOG_WARN);
}


/**
 * Whether the loglevel LOG_ERROR is active for the current program.
 *
 * @return bool
 */
bool IsLogError() {
   int loglevel = __ExecutionContext[EC.loglevel];
   if (!loglevel) loglevel = log("", NULL, LOG_OFF);
   return(loglevel && loglevel <= LOG_ERROR);
}


/**
 * Whether the loglevel LOG_FATAL is active for the current program.
 *
 * This function exists for API completeness only. Loglevel LOG_FATAL cannot be deactivated, even if logging is switched off.
 *
 * @return bool - always TRUE
 */
bool IsLogFatal() {
   return(true);
}


/**
 * Logger main function. Process a log message and dispatch it to the enabled log appenders.
 *
 * @param  string message - log message
 * @param  int    error   - error linked to the message (if any)
 * @param  int    level   - log level of the message
 *
 * @return int - the same error or the configured loglevel if parameter level is LOG_OFF
 */
int log(string message, int error, int level) {
   // read the configuration on first usage
   int configLevel = __ExecutionContext[EC.loglevel]; if (!configLevel) {
      if (IsExpert() && !IsTesting()) {
         configLevel = LOG_ALL;                                                                    // in online EAs: all
      }
      else {
         string key="", value="";
         if (This.IsTesting()) {
            key = "Tester";
            value = GetConfigString("Log", key, "off");                                            // tester default: off
         }
         else {
            key = ProgramName();
            if (!IsConfigKey("Log", key)) key = "Online";
            value = GetConfigString("Log", key, "all");                                            // online default: all
         }
         configLevel = StrToLogLevel(value, F_ERR_INVALID_PARAMETER);
         if (!configLevel) configLevel = _int(LOG_OFF, catch("log(1)  invalid loglevel configuration [Log]->"+ key +" = "+ value, ERR_INVALID_CONFIG_VALUE));
      }
      ec_SetLoglevel(__ExecutionContext, configLevel);
   }
   if (level == LOG_OFF)
      return(configLevel);

   // apply the configured loglevel filter
   if (level >= configLevel) {
      if (__ExecutionContext[EC.loglevelTerminal] != LOG_OFF) log2Terminal(message, error, level); // fast appenders first
      if (__ExecutionContext[EC.loglevelDebugger] != LOG_OFF) log2Debugger(message, error, level); // ...
      if (__ExecutionContext[EC.loglevelFile    ] != LOG_OFF) log2File    (message, error, level); // ...
      if (__ExecutionContext[EC.loglevelAlert   ] != LOG_OFF) log2Alert   (message, error, level); // after fast appenders as it may lock the UI thread in tester
      if (__ExecutionContext[EC.loglevelMail    ] != LOG_OFF) log2Mail    (message, error, level); // slow appenders last (launches a new process)
      if (__ExecutionContext[EC.loglevelSMS     ] != LOG_OFF) log2SMS     (message, error, level); // ...
   }
   else if (level >= LOG_FATAL) {
      if (__ExecutionContext[EC.loglevelTerminal] != LOG_OFF) log2Terminal(message, error, level); // built-in log appenders always process LOG_FATAL
      if (__ExecutionContext[EC.loglevelAlert   ] != LOG_OFF) log2Alert   (message, error, level);
   }
   return(error);
}


/**
 * Helper function to simplify logging of messages of level LOG_DEBUG.
 *
 * @param  string message          - location identifier and/or log message
 * @param  int    error [optional] - error linked to the message (default: none)
 *
 * @return int - the same error
 */
int logDebug(string message, int error = NO_ERROR) {
   return(log(message, error, LOG_DEBUG));
}


/**
 * Helper function to simplify logging of messages of level LOG_INFO.
 *
 * @param  string message          - location identifier and/or log message
 * @param  int    error [optional] - error linked to the message (default: none)
 *
 * @return int - the same error
 */
int logInfo(string message, int error = NO_ERROR) {
   return(log(message, error, LOG_INFO));
}


/**
 * Helper function to simplify logging of messages of level LOG_NOTICE.
 *
 * @param  string message          - location identifier and/or log message
 * @param  int    error [optional] - error linked to the message (default: none)
 *
 * @return int - the same error
 */
int logNotice(string message, int error = NO_ERROR) {
   return(log(message, error, LOG_NOTICE));
}


/**
 * Helper function to simplify logging of messages of level LOG_WARN.
 *
 * @param  string message          - location identifier and/or log message
 * @param  int    error [optional] - error linked to the message (default: none)
 *
 * @return int - the same error
 */
int logWarn(string message, int error = NO_ERROR) {
   return(log(message, error, LOG_WARN));
}


/**
 * Helper function to simplify logging of messages of level LOG_ERROR.
 *
 * @param  string message - location identifier and/or log message
 * @param  int    error   - error linked to the message
 *
 * @return int - the same error
 */
int logError(string message, int error) {
   return(log(message, error, LOG_ERROR));
}


/**
 * Helper function to simplify logging of messages of level LOG_FATAL. Used by catch() to log detected and otherwise
 * unhandled errors.
 *
 * @param  string message - location identifier and/or log message
 * @param  int    error   - error linked to the message
 *
 * @return int - the same error
 */
int logFatal(string message, int error) {
   return(log(message, error, LOG_FATAL));
}


/**
 * Send a log message to the terminal's alerting system.
 *
 * @param  string message - log message
 * @param  int    error   - error linked to the message (if any)
 * @param  int    level   - loglevel of the message
 *
 * @return int - the same error or the configured alert loglevel if parameter level is LOG_OFF
 */
int log2Alert(string message, int error, int level) {
   // read the configuration on first usage
   int configLevel = __ExecutionContext[EC.loglevelAlert]; if (!configLevel) {
      string sValue = GetConfigString("Log", "Log2Alert", "notice");                // default: notice
      configLevel = StrToLogLevel(sValue, F_ERR_INVALID_PARAMETER);
      if (!configLevel) configLevel = _int(LOG_OFF, catch("log2Alert(2)  invalid loglevel configuration [Log]->Log2Alert = "+ sValue, ERR_INVALID_CONFIG_VALUE));
      configLevel = Min(configLevel, LOG_FATAL);                                    // the alert appender cannot be fully switched off
      ec_SetLoglevelAlert(__ExecutionContext, configLevel);
   }
   if (level == LOG_OFF) return(configLevel);

   // apply the configured loglevel filter
   if (level >= configLevel) {
      static bool isRecursion = false; if (isRecursion) {                           // should never happen
         Alert("log2Alert(1)  recursion: ", message, ", error: ", error, ", ", LoglevelToStr(level));
         return(error);
      }
      isRecursion = true;
      ec_SetLoglevelAlert(__ExecutionContext, LOG_OFF);                             // prevent recursive calls

      if (IsTesting()) {                                                            // neither Alert() nor MessageBox() can be used
         string caption = "Strategy Tester "+ Symbol() +","+ PeriodDescription();
         int pos = StringFind(message, ") ");                                       // insert a line-wrap after the first closing function brace
         if (pos != -1) message = StrLeft(message, pos+1) + NL + StrTrim(StrSubstr(message, pos+2));
         message = TimeToStr(TimeLocal(), TIME_FULL) + NL + LoglevelDescription(level) +" in "+ FullModuleName() +"::"+ message + ifString(error, "  ["+ ErrorToStr(error) +"]", "");
         PlaySoundEx("alert.wav");
         MessageBoxEx(caption, message, MB_ICONERROR|MB_OK|MB_DONT_LOG);
      }
      else {
         Alert(LoglevelDescription(level), ":   ", Symbol(), ",", PeriodDescription(), "  ", FullModuleName(), "::", message, ifString(error, "  ["+ ErrorToStr(error) +"]", ""));
      }

      ec_SetLoglevelAlert(__ExecutionContext, configLevel);                         // restore the configuration
      isRecursion = false;
   }
   return(error);
}


/**
 * Send a log message to the system debugger.
 *
 * @param  string message - log message
 * @param  int    error   - error linked to the message (if any)
 * @param  int    level   - log level of the message
 *
 * @return int - the same error or the configured debugger loglevel if parameter level is LOG_OFF
 */
int log2Debugger(string message, int error, int level) {
   // read the configuration on first usage
   int configLevel = __ExecutionContext[EC.loglevelDebugger]; if (!configLevel) {
      string sValue = GetConfigString("Log", "Log2Debugger", "all");                // default: off
      configLevel = StrToLogLevel(sValue, F_ERR_INVALID_PARAMETER);
      if (!configLevel) configLevel = _int(LOG_OFF, catch("log2Debugger(2)  invalid loglevel configuration [Log]->Log2Debugger = "+ sValue, ERR_INVALID_CONFIG_VALUE));
      ec_SetLoglevelDebugger(__ExecutionContext, configLevel);
   }
   if (level == LOG_OFF) return(configLevel);

   // apply the configured loglevel filter
   if (level >= configLevel) {
      static bool isRecursion = false; if (isRecursion) {                           // should never happen
         Alert("log2Debugger(1)  recursion: ", message, ", error: ", error, ", ", LoglevelToStr(level));
         return(error);
      }
      isRecursion = true;
      ec_SetLoglevelDebugger(__ExecutionContext, LOG_OFF);                          // prevent recursive calls

      debug(message, error, level);

      ec_SetLoglevelDebugger(__ExecutionContext, configLevel);                      // restore the configuration
      isRecursion = false;
   }
   return(error);
}


/**
 * Send a log message to the custom logfile appender.
 *
 * @param  string message - log message
 * @param  int    error   - error linked to the message (if any)
 * @param  int    level   - log level of the message
 *
 * @return int - the same error or the configured logfile loglevel if parameter level is LOG_OFF
 */
int log2File(string message, int error, int level) {
   // read the configuration on first usage
   int configLevel = __ExecutionContext[EC.loglevelFile]; if (!configLevel) {
      if (IsExpert() && !IsTesting()) {
         configLevel = LOG_ALL;                                                     // in online EAs: all
      }
      else {
         string sValue = GetConfigString("Log", "Log2File", "off");                 // default: off
         configLevel = StrToLogLevel(sValue, F_ERR_INVALID_PARAMETER);
         if (!configLevel) configLevel = _int(LOG_OFF, catch("log2File(2)  invalid loglevel configuration [Log]->Log2File = "+ sValue, ERR_INVALID_CONFIG_VALUE));
      }
      ec_SetLoglevelFile(__ExecutionContext, configLevel);
   }
   if (level == LOG_OFF) return(configLevel);

   // apply the configured loglevel filter
   if (level >= configLevel) {
      static bool isRecursion = false; if (isRecursion) {                           // should never happen
         Alert("log2File(1)  recursion: ", message, ", error: ", error, ", ", LoglevelToStr(level));
         return(error);
      }
      isRecursion = true;
      ec_SetLoglevelFile(__ExecutionContext, LOG_OFF);                              // prevent recursive calls

      AppendLogMessageA(__ExecutionContext, TimeCurrent(), message, error, level);

      ec_SetLoglevelFile(__ExecutionContext, configLevel);                          // restore the configuration
      isRecursion = false;
   }
   return(error);
}


/**
 * Send a log message to the mail appender.
 *
 * @param  string message - log message
 * @param  int    error   - error linked to the message (if any)
 * @param  int    level   - log level of the message
 *
 * @return int - the same error or the configured mail loglevel if parameter level is LOG_OFF
 */
int log2Mail(string message, int error, int level) {
   // read the configuration on first usage
   int configLevel = __ExecutionContext[EC.loglevelMail]; if (!configLevel) {
      string sValue = GetConfigString("Log", "Log2Mail", "off");                    // default: off
      configLevel = StrToLogLevel(sValue, F_ERR_INVALID_PARAMETER);
      if (!configLevel) configLevel = _int(LOG_OFF, catch("log2Mail(1)  invalid loglevel configuration [Log]->Log2Mail = "+ sValue, ERR_INVALID_CONFIG_VALUE));
      ec_SetLoglevelMail(__ExecutionContext, configLevel);
   }
   if (level == LOG_OFF) return(configLevel);

   // apply the configured loglevel filter
   if (level >= configLevel) {
      static bool isRecursion = false; if (isRecursion) {                           // should never happen
         Alert("log2Mail(2)  recursion: ", message, ", error: ", error, ", ", LoglevelToStr(level));
         return(error);
      }
      isRecursion = true;
      ec_SetLoglevelMail(__ExecutionContext, LOG_OFF);                              // prevent recursive calls

      static string sender = ""; if (!StringLen(sender)) {
         sValue = GetConfigString("Mail", "Sender", "mt4@"+ GetHostName() +".localdomain");
         if (!StrIsEmailAddress(sValue)) return(_int(error, catch("log2Mail(3)  invalid mail sender address configuration [Mail]->Sender = "+ DoubleQuoteStr(sValue), ERR_INVALID_CONFIG_VALUE)));
         sender = sValue;
      }
      static string receiver = ""; if (!StringLen(receiver)) {
         sValue = GetConfigString("Mail", "Receiver");
         if (!StrIsEmailAddress(sValue)) return(_int(error, catch("log2Mail(4)  invalid mail receiver address configuration [Mail]->Receiver = "+ DoubleQuoteStr(sValue), ERR_INVALID_CONFIG_VALUE)));
         receiver = sValue;
      }
      message = LoglevelDescription(level) +":  "+ Symbol() +","+ PeriodDescription() +"  "+ FullModuleName() +"::"+ message + ifString(error, "  ["+ ErrorToStr(error) +"]", "");
      string subject = StrReplace(message, NL, " ");
      string body    = message + NL +"("+ TimeToStr(TimeLocal(), TIME_MINUTES|TIME_SECONDS) +", "+ GetAccountAlias() +")";

      if (SendEmail(sender, receiver, subject, body)) {
         ec_SetLoglevelMail(__ExecutionContext, configLevel);                       // restore the configuration or leave it disabled
      }
      isRecursion = false;
   }
   return(error);
}


/**
 * Send a log message to the SMS appender.
 *
 * @param  string message - log message
 * @param  int    error   - error linked to the message (if any)
 * @param  int    level   - log level of the message
 *
 * @return int - the same error or the configured SMS loglevel if parameter level is LOG_OFF
 */
int log2SMS(string message, int error, int level) {
   // read the configuration on first usage
   int configLevel = __ExecutionContext[EC.loglevelSMS]; if (!configLevel) {
      string sValue = GetConfigString("Log", "Log2SMS", "off");                     // default: off
      configLevel = StrToLogLevel(sValue, F_ERR_INVALID_PARAMETER);
      if (!configLevel) configLevel = _int(LOG_OFF, catch("log2SMS(1)  invalid loglevel configuration [Log]->Log2SMS = "+ sValue, ERR_INVALID_CONFIG_VALUE));
      ec_SetLoglevelSMS(__ExecutionContext, configLevel);
   }
   if (level == LOG_OFF) return(configLevel);

   // apply the configured loglevel filter
   if (level >= configLevel) {
      static bool isRecursion = false; if (isRecursion) {                           // should never happen
         Alert("log2SMS(2)  recursion: ", message, ", error: ", error, ", ", LoglevelToStr(level));
         return(error);
      }
      isRecursion = true;
      ec_SetLoglevelSMS(__ExecutionContext, LOG_OFF);                               // prevent recursive calls

      static string receiver = ""; if (!StringLen(receiver)) {
         sValue = GetConfigString("SMS", "Receiver");
         if (!StrIsPhoneNumber(sValue)) return(_int(error, catch("log2SMS(3)  invalid phone number configuration: [SMS]->Receiver = "+ DoubleQuoteStr(sValue), ERR_INVALID_CONFIG_VALUE)));
         receiver = sValue;
      }
      string text = LoglevelDescription(level) +":  "+ Symbol() +","+ PeriodDescription() +"  "+ FullModuleName() +"::"+ message + ifString(error, "  ["+ ErrorToStr(error) +"]", "") + NL
                  +"("+ TimeToStr(TimeLocal(), TIME_MINUTES|TIME_SECONDS) +", "+ GetAccountAlias() +")";

      if (SendSMS(receiver, text)) {
         ec_SetLoglevelSMS(__ExecutionContext, configLevel);                        // restore the configuration or leave it disabled
      }
      isRecursion = false;
   }
   return(error);
}


/**
 * Send a log message to the terminal's log system.
 *
 * @param  string message - log message
 * @param  int    error   - error linked to the message (if any)
 * @param  int    level   - log level of the message
 *
 * @return int - the same error or the configured terminal loglevel if parameter level is LOG_OFF
 */
int log2Terminal(string message, int error, int level) {
   // read the configuration on first usage
   int configLevel = __ExecutionContext[EC.loglevelTerminal]; if (!configLevel) {
      string sValue = GetConfigString("Log", "Log2Terminal", "all");                // default: all
      configLevel = StrToLogLevel(sValue, F_ERR_INVALID_PARAMETER);
      if (!configLevel) configLevel = _int(LOG_OFF, catch("log2Terminal(2)  invalid loglevel configuration [Log]->Log2Terminal = "+ sValue, ERR_INVALID_CONFIG_VALUE));
      configLevel = Min(configLevel, LOG_FATAL);                                    // the terminal appender cannot be fully switched off
      ec_SetLoglevelTerminal(__ExecutionContext, configLevel);
   }
   if (level == LOG_OFF) return(configLevel);

   // apply the configured loglevel filter
   if (level >= configLevel) {
      static bool isRecursion = false; if (isRecursion) {                           // should never happen
         Alert("log2Terminal(1)  recursion: ", message, ", error: ", error, ", ", LoglevelToStr(level));
         return(error);
      }
      isRecursion = true;
      ec_SetLoglevelTerminal(__ExecutionContext, LOG_OFF);                          // prevent recursive calls

      string sLoglevel = ""; if (level != LOG_DEBUG) sLoglevel = LoglevelDescription(level) +"  ";
      string sError    = ""; if (error != NO_ERROR)  sError    = " ["+ ErrorToStr(error) +"]";

      Print(sLoglevel, StrReplace(message, NL, " "), sError);

      ec_SetLoglevelTerminal(__ExecutionContext, configLevel);                      // restore the configuration
      isRecursion = false;
   }
   return(error);

   // dummy calls
   catch(NULL);
   debug(NULL);

   IsLog();
   IsLogDebug();
   IsLogInfo();
   IsLogNotice();
   IsLogWarn();
   IsLogError();
   IsLogFatal();

   log(NULL, NULL, NULL);
   logDebug (NULL);
   logInfo  (NULL);
   logNotice(NULL);
   logWarn  (NULL);
   logError (NULL, NULL);
   logFatal (NULL, NULL);

   log2Alert   (NULL, NULL, NULL);
   log2Debugger(NULL, NULL, NULL);
   log2File    (NULL, NULL, NULL);
   log2Mail    (NULL, NULL, NULL);
   log2SMS     (NULL, NULL, NULL);
   log2Terminal(NULL, NULL, NULL);

   SetLogfile(NULL);
}


/**
 * Configure the use of a custom logfile (simple wrapper for the MT4Expander function).
 *
 * @param  string filename - full filename to enable or an empty string to disable the custom logfile
 *
 * @return bool - success status
 */
bool SetLogfile(string filename) {
   int loglevel     = log(NULL, NULL, LOG_OFF);         // Make sure the configuration of the LogfileAppender is initialized
   int loglevelFile = log2File(NULL, NULL, LOG_OFF);    // as the Expander cannot yet read it.

   if (StringLen(filename) > 0) {
      if (loglevel!=LOG_OFF && loglevelFile!=LOG_OFF) {
         string prevName = ec_LogFilename(__ExecutionContext);
         if (filename != prevName) {
            if (IsLogDebug()) debug("SetLogfile(1)  \""+ filename +"\"");        // only to DebugView (for quick control)
         }
      }
      else {                                                                     // only to DebugView (for quick control)
         if (IsLogDebug()) debug("SetLogfile(2)  skipping ("+ ifString(loglevel==LOG_OFF, "log", "log2File") +"=off)");
      }
   }
   return(SetLogfileA(__ExecutionContext, filename));
}


#import "rsfMT4Expander.dll"
   string ec_LogFilename        (int ec[]);
   int    ec_SetLoglevel        (int ec[], int level);
   int    ec_SetLoglevelAlert   (int ec[], int level);
   int    ec_SetLoglevelDebugger(int ec[], int level);
   int    ec_SetLoglevelFile    (int ec[], int level);
   int    ec_SetLoglevelMail    (int ec[], int level);
   int    ec_SetLoglevelSMS     (int ec[], int level);
   int    ec_SetLoglevelTerminal(int ec[], int level);
   bool   AppendLogMessageA     (int ec[], datetime time, string message, int error, int level);
   bool   SetLogfileA           (int ec[], string file);
#import
