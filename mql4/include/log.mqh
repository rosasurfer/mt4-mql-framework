/**
 * Send a message to the system debugger.
 *
 * @param  string message             - message
 * @param  int    error    [optional] - error code (default: none)
 * @param  int    loglevel [optional] - loglevel to add to the message (default: none)
 *
 * @return int - the same error
 */
int debug(string message, int error=NO_ERROR, int loglevel=NULL) {
   // note: The function must not use MQL library functions. Using DLLs is ok.
   if (!IsDllsAllowed()) {
      Alert("debug(1)  DLLs are not enabled (", message, ", error: ", error, ")");  // directly alert instead
      return(error);
   }
   static bool isRecursion = false; if (isRecursion) {
      Alert("debug(2)  recursion (", message, ", error: ", error, ")");             // should never happen
      return(error);
   }
   isRecursion = true;

   string sLoglevel="", sApp="", sError="";
   if (loglevel != 0) sLoglevel = StringConcatenate(LogLevelDescription(loglevel), " ");
   if (error != 0)    sError    = StringConcatenate("  [", ErrorToStr(error), "]");

   if (This.IsTesting()) sApp = StringConcatenate(GmtTimeFormat(MarketInfo(Symbol(), MODE_TIME), "%d.%m.%Y %H:%M:%S"), " ", sLoglevel, "Tester::");
   else                  sApp = sLoglevel +"MetaTrader::";

   OutputDebugStringA(StringConcatenate(sApp, Symbol(), ",", PeriodDescription(Period()), "::", NAME(), "::", StrReplace(StrReplaceR(message, NL+NL, NL), NL, " "), sError));

   isRecursion = false;
   return(error);
}


/**
 * Check for and handle runtime errors. If an error occurred the error is signaled, logged and stored in the global var
 * "last_error". After return the internal MQL error as returned by GetLastError() is always reset.
 *
 * @param  string location            - a possible error's location identifier and/or an error message
 * @param  int    error    [optional] - trigger a specific error (default: no)
 * @param  bool   orderPop [optional] - whether the last order context on the order stack should be restored (default: no)
 *
 * @return int - the same error
 */
int logger_catch(string location, int error=NO_ERROR, bool orderPop=false) {
   orderPop = orderPop!=0;
   if      (!error                  ) { error  =                      GetLastError(); }
   else if (error == ERR_WIN32_ERROR) { error += GetLastWin32Error(); GetLastError(); }
   else                               {                               GetLastError(); }

   static bool isRecursion = false; if (isRecursion) {
      string msg = "catch(1)  recursion ("+ location +")";
      Alert(msg, ", error: ", error);                       // should never happen
      return(debug(msg, error, LOG_ERROR));
   }
   isRecursion = true;

   if (error != 0) {
      logger_log(location, error, LOG_ERROR);
      SetLastError(error);
   }

   if (orderPop) OrderPop(location);
   isRecursion = false;
   return(error);
}


/**
 * Logger main function. Process a log message and dispatch it to the enabled log appenders.
 *
 * @param  string message - log message
 * @param  int    error   - error linked to the message (if any)
 * @param  int    level   - log level of the message
 *
 * @return int - the same error
 */
int logger_log(string message, int error, int level) {
   if (__ExecutionContext[EC.loglevelTerminal] != LOG_OFF) log2Terminal(message, error, level);    // fast appenders first
   if (__ExecutionContext[EC.loglevelDebugger] != LOG_OFF) log2Debugger(message, error, level);    // ...
   if (__ExecutionContext[EC.loglevelFile    ] != LOG_OFF) log2File(message, error, level);        // ...
   if (__ExecutionContext[EC.loglevelAlert   ] != LOG_OFF) log2Alert(message, error, level);       // after fast appenders as it may dead-lock the thread in tester
   if (__ExecutionContext[EC.loglevelMail    ] != LOG_OFF) log2Mail(message, error, level);        // slow appenders last (launches a new process)
   if (__ExecutionContext[EC.loglevelSMS     ] != LOG_OFF) log2SMS(message, error, level);         // ...
   return(error);
}


/**
 * Helper function to simplify logging of a message of level LOG_DEBUG.
 *
 * @param  string message          - location identifier and/or log message
 * @param  int    error [optional] - error linked to the message (default: none)
 *
 * @return int - the same error
 */
int logDebug(string message, int error = NO_ERROR) {
   return(logger_log(message, error, LOG_DEBUG));
}


/**
 * Helper function to simplify logging of a message of level LOG_INFO.
 *
 * @param  string message          - location identifier and/or log message
 * @param  int    error [optional] - error linked to the message (default: none)
 *
 * @return int - the same error
 */
int logInfo(string message, int error = NO_ERROR) {
   return(logger_log(message, error, LOG_INFO));
}


/**
 * Helper function to simplify logging of a message of level LOG_NOTICE.
 *
 * @param  string message          - location identifier and/or log message
 * @param  int    error [optional] - error linked to the message (default: none)
 *
 * @return int - the same error
 */
int logNotice(string message, int error = NO_ERROR) {
   return(logger_log(message, error, LOG_NOTICE));
}


/**
 * Helper function to simplify logging of a message of level LOG_WARN.
 *
 * @param  string message          - location identifier and/or log message
 * @param  int    error [optional] - error linked to the message (default: none)
 *
 * @return int - the same error
 */
int logWarn(string message, int error = NO_ERROR) {
   return(logger_log(message, error, LOG_WARN));
}


/**
 * Helper function to simplify logging of a message of level LOG_ERROR.
 *
 * @param  string message          - location identifier and/or log message
 * @param  int    error [optional] - error linked to the message (default: none)
 *
 * @return int - the same error
 */
int logError(string message, int error = NO_ERROR) {
   return(logger_log(message, error, LOG_ERROR));
}


/**
 * Helper function to simplify logging of a message of level LOG_FATAL.
 *
 * @param  string message          - location identifier and/or log message
 * @param  int    error [optional] - error linked to the message (default: none)
 *
 * @return int - the same error
 */
int logFatal(string message, int error = NO_ERROR) {
   return(logger_log(message, error, LOG_FATAL));
}


/**
 * Send a log message to the terminal's alerting system.
 *
 * @param  string message - log message
 * @param  int    error   - error linked to the message (if any)
 * @param  int    level   - loglevel of the message
 *
 * @return int - the same error
 */
int log2Alert(string message, int error, int level) {
   // note: to only initialize the appender call it with level=LOG_OFF
   static bool isRecursion = false; if (isRecursion) {
      Alert("log2Alert(1)  recursion (", message, "error: ", error, ")");        // should never happen
      return(error);
   }
   isRecursion = true;

   // read the configuration on first usage
   int configLevel = __ExecutionContext[EC.loglevelAlert]; if (!configLevel) {
      string sValue = GetConfigString("Log", "Log2Alert", "notice");             // default: notice
      configLevel = StrToLogLevel(sValue, F_ERR_INVALID_PARAMETER);
      if (!configLevel) configLevel = _int(LOG_OFF, catch("log2Alert(2)  invalid loglevel configuration [Log]->Log2Alert = "+ sValue, ERR_INVALID_CONFIG_VALUE));
      ec_SetLoglevelAlert(__ExecutionContext, configLevel);
   }

   // apply the configured loglevel filter
   if (level >= configLevel && level!=LOG_OFF) {
      if (IsTesting()) {                                                         // neither Alert() nor MessageBox() can be used
         string caption = "Tester "+ Symbol() +","+ PeriodDescription(Period());
         int pos = StringFind(message, ") ");                                    // line-wrap message after the closing function brace
         if (pos != -1) message = StrLeft(message, pos+1) + NL + StrTrim(StrSubstr(message, pos+2));
         message = TimeToStr(TimeLocal(), TIME_FULL) + NL + LogLevelDescription(level) +" in "+ message;
         PlaySoundEx("alert.wav");
         MessageBoxEx(caption, message, MB_ICONERROR|MB_OK|MB_DONT_LOG);
      }
      else {
         Alert(LogLevelDescription(level), ":   ", Symbol(), ",", PeriodDescription(Period()), "  ", NAME(), "::", message, ifString(error, "  ["+ ErrorToStr(error) +"]", ""));
      }
   }

   isRecursion = false;
   return(error);
}


/**
 * Send a log message to the system debugger.
 *
 * @param  string message - log message
 * @param  int    error   - error linked to the message (if any)
 * @param  int    level   - log level of the message
 *
 * @return int - the same error
 */
int log2Debugger(string message, int error, int level) {
   // note: to only initialize the appender call it with level=LOG_OFF
   static bool isRecursion = false; if (isRecursion) {
      Alert("log2Debugger(1)  recursion (", message, "error: ", error, ")");  // should never happen
      return(error);
   }
   isRecursion = true;

   // read the configuration on first usage
   int configLevel = __ExecutionContext[EC.loglevelDebugger]; if (!configLevel) {
      string sValue = GetConfigString("Log", "Log2Debugger", "off");          // default: off
      configLevel = StrToLogLevel(sValue, F_ERR_INVALID_PARAMETER);
      if (!configLevel) configLevel = _int(LOG_OFF, catch("log2Debugger(2)  invalid loglevel configuration [Log]->Log2Debugger = "+ sValue, ERR_INVALID_CONFIG_VALUE));
      ec_SetLoglevelDebugger(__ExecutionContext, configLevel);
   }

   // apply the configured loglevel filter
   if (level >= configLevel && level!=LOG_OFF) {
      debug(message, error, level);
   }

   isRecursion = false;
   return(error);
}


/**
 * Send a log message to a custom logfile appender.
 *
 * @param  string message - log message
 * @param  int    error   - error linked to the message (if any)
 * @param  int    level   - log level of the message
 *
 * @return int - the same error
 */
int log2File(string message, int error, int level) {
   // note: to only initialize the appender call it with level=LOG_OFF
   static bool isRecursion = false; if (isRecursion) {
      Alert("log2File(1)  recursion (", message, "error: ", error, ")");                  // should never happen
      return(error);
   }
   isRecursion = true;

   int configLevel = __ExecutionContext[EC.loglevelFile]; if (!configLevel) {
      configLevel = ifInt(__ExecutionContext[EC.logToCustomEnabled], LOG_ALL, LOG_OFF);   // TODO
      ec_SetLoglevelFile(__ExecutionContext, configLevel);
   }

   // apply the configured loglevel filter
   if (level >= configLevel && level!=LOG_OFF) {
      LogMessageA(__ExecutionContext, message, error, level);
   }

   isRecursion = false;
   return(error);
}


/**
 * Send a log message to the mail appender.
 *
 * @param  string message - log message
 * @param  int    error   - error linked to the message (if any)
 * @param  int    level   - log level of the message
 *
 * @return int - the same error
 */
int log2Mail(string message, int error, int level) {
   // note: to only initialize the appender call it with level=LOG_OFF
   static bool isRecursion = false; if (isRecursion) {
      Alert("log2Mail(1)  recursion (", message, "error: ", error, ")");      // should never happen
      return(error);
   }
   isRecursion = true;
   string sender="", receiver="";

   // read the configuration on first usage
   int configLevel = __ExecutionContext[EC.loglevelMail]; if (!configLevel) {
      string sValue = GetConfigString("Log", "Log2Mail", "off");              // default: off
      configLevel = StrToLogLevel(sValue, F_ERR_INVALID_PARAMETER);

      if (configLevel != 0) {                                                 // logging to mail is enabled
         sender   = GetConfigString("Mail", "Sender", "mt4@"+ GetHostName() +".localdomain");
         receiver = GetConfigString("Mail", "Receiver");
         if (!StrIsEmailAddress(sender))   configLevel = _int(LOG_OFF, catch("log2Mail(2)  invalid mail sender address configuration [Mail]->Sender = "+ sender, ERR_INVALID_CONFIG_VALUE));
         if (!StrIsEmailAddress(receiver)) configLevel = _int(LOG_OFF, catch("log2Mail(3)  invalid mail receiver address configuration [Mail]->Receiver = "+ receiver, ERR_INVALID_CONFIG_VALUE));
      }
      else configLevel = _int(LOG_OFF, catch("log2Mail(4)  invalid loglevel configuration [Log]->Log2Mail = "+ sValue, ERR_INVALID_CONFIG_VALUE));
      ec_SetLoglevelMail(__ExecutionContext, configLevel);
   }

   // apply the configured loglevel filter
   if (level >= configLevel && level!=LOG_OFF) {
      message = LogLevelDescription(level) +":  "+ Symbol() +","+ PeriodDescription(Period()) +"  "+ NAME() +"::"+ message + ifString(error, "  ["+ ErrorToStr(error) +"]", "");
      string subject = message;
      string body = message + NL +"("+ TimeToStr(TimeLocal(), TIME_MINUTES|TIME_SECONDS) +", "+ GetAccountAlias() +")";

      if (!SendEmail(sender, receiver, subject, body)) {
         configLevel = LOG_OFF;                                               // disable the appender if sending failed
      }
   }

   isRecursion = false;
   return(error);
}


/**
 * Send a log message to the SMS appender.
 *
 * @param  string message - log message
 * @param  int    error   - error linked to the message (if any)
 * @param  int    level   - log level of the message
 *
 * @return int - the same error
 */
int log2SMS(string message, int error, int level) {
   // note: to only initialize the appender call it with level=LOG_OFF
   static bool isRecursion = false; if (isRecursion) {
      Alert("log2SMS(1)  recursion (", message, "error: ", error, ")");       // should never happen
      return(error);
   }
   isRecursion = true;
   string receiver = "";

   // read the configuration on first usage
   int configLevel = __ExecutionContext[EC.loglevelSMS]; if (!configLevel) {
      string sValue = GetConfigString("Log", "Log2SMS", "off");               // default: off
      configLevel = StrToLogLevel(sValue, F_ERR_INVALID_PARAMETER);

      if (configLevel != 0) {                                                 // logging to SMS is enabled
         receiver = GetConfigString("SMS", "Receiver");
         if (!StrIsPhoneNumber(receiver)) configLevel = _int(LOG_OFF, catch("log2SMS(2)  invalid phone number configuration: [SMS]->Receiver = "+ receiver, ERR_INVALID_CONFIG_VALUE));
      }
      else configLevel = _int(LOG_OFF, catch("log2SMS(3)  invalid loglevel configuration [Log]->Log2SMS = "+ sValue, ERR_INVALID_CONFIG_VALUE));
      ec_SetLoglevelSMS(__ExecutionContext, configLevel);
   }

   // apply the configured loglevel filter
   if (level >= configLevel && level!=LOG_OFF) {
      string text = LogLevelDescription(level) +":  "+ Symbol() +","+ PeriodDescription(Period()) +"  "+ NAME() +"::"+ message + ifString(error, "  ["+ ErrorToStr(error) +"]", "");
      string accountTime = "("+ TimeToStr(TimeLocal(), TIME_MINUTES|TIME_SECONDS) +", "+ GetAccountAlias() +")";

      if (!SendSMS(receiver, text + NL + accountTime)) {
         configLevel = LOG_OFF;                                               // disable the appender if sending failed
      }
   }

   isRecursion = false;
   return(error);
}


/**
 * Send a log message to the terminal's log system.
 *
 * @param  string message - log message
 * @param  int    error   - error linked to the message (if any)
 * @param  int    level   - log level of the message
 *
 * @return int - the same error
 */
int log2Terminal(string message, int error, int level) {
   // note: to only initialize the appender send a message of level=LOG_OFF
   static bool isRecursion = false; if (isRecursion) {
      Alert("log2Terminal(1)  recursion (", message, "error: ", error, ")");  // should never happen
      return(error);
   }
   isRecursion = true;

   // read the configuration on first usage
   int configLevel = __ExecutionContext[EC.loglevelTerminal]; if (!configLevel) {
      string sValue = GetConfigString("Log", "Log2Terminal", "all");          // default: all
      configLevel = StrToLogLevel(sValue, F_ERR_INVALID_PARAMETER);
      if (!configLevel) configLevel = _int(LOG_OFF, catch("log2Terminal(2)  invalid loglevel configuration [Log]->Log2Terminal = "+ sValue, ERR_INVALID_CONFIG_VALUE));
      ec_SetLoglevelTerminal(__ExecutionContext, configLevel);
   }

   // apply the configured loglevel filter
   if (level >= configLevel && level!=LOG_OFF) {
      Print("  ", LogLevelDescription(level), ":   ", message, ifString(error, "  ["+ ErrorToStr(error) +"]", ""));
   }

   isRecursion = false;
   return(error);
}


#import "rsfExpander.dll"
   int ec_SetLoglevel        (int ec[], int level);
   int ec_SetLoglevelAlert   (int ec[], int level);
   int ec_SetLoglevelDebugger(int ec[], int level);
   int ec_SetLoglevelFile    (int ec[], int level);
   int ec_SetLoglevelMail    (int ec[], int level);
   int ec_SetLoglevelSMS     (int ec[], int level);
   int ec_SetLoglevelTerminal(int ec[], int level);
#import
