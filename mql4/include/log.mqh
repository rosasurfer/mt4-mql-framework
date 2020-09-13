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
      Alert(msg, "  [", ErrorToStr(error), "]");                  // send message to terminal log instead
      return(logger_debug(msg, error));
   }
   isRecursion = true;

   if (error != 0) {
      logError(location, error);
      SetLastError(error);
   }

   if (orderPop) OrderPop(location);
   isRecursion = false;
   return(error);
}


/**
 * Send a message to the system debugger.
 *
 * @param  string message          - message
 * @param  int    error [optional] - error code (default: none)
 *
 * @return int - the same error
 */
int logger_debug(string message, int error = NO_ERROR) {
   // This function must not use MQL library functions. Using DLLs is ok.
   if (!IsDllsAllowed()) {
      Alert("debug(1)  DLLs are not enabled (", message, ")");    // send to terminal log instead
      return(error);
   }
   string sApp="", sError="";
   if (error != 0) sError = StringConcatenate("  [", ErrorToStr(error), "]");

   static bool isRecursion = false; if (isRecursion) {
      Alert("debug(2)  recursion (", message, sError, ")");       // send to terminal log instead
      return(error);
   }
   isRecursion = true;

   if (This.IsTesting()) sApp = StringConcatenate(GmtTimeFormat(MarketInfo(Symbol(), MODE_TIME), "%d.%m.%Y %H:%M:%S"), " Tester::");
   else                  sApp = "MetaTrader::";
   OutputDebugStringA(StringConcatenate(sApp, Symbol(), ",", PeriodDescription(Period()), "::", __NAME(), "::", StrReplace(StrReplaceR(message, NL+NL, NL), NL, " "), sError));

   isRecursion = false;
   return(error);
}


/**
 * Process a log message and pass it to the configured log appenders.
 *
 * @param  string message          - log message
 * @param  int    error [optional] - error linked to the message (default: none)
 * @param  int    level [optional] - log level of the message (default: LOG_INFO)
 *
 * @return int - the same error
 */
int logger_log(string message, int error=NO_ERROR, int level=LOG_INFO) {
   log2Alert(message, error, level);

   // log2Terminal()
   // log2Custom()

   log2Mail(message, error, level);
   log2SMS(message, error, level);
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
 * @param  int    level   - log level of the message
 *
 * @return int - the same error
 */
int log2Alert(string message, int error, int level) {
   int alertLevel = LOG_WARN;

   if (level >= alertLevel) {
      Alert(message, error, level);
   }
   return(error);
}


/**
 * Send a log message to the debug output appender.
 *
 * @param  string message - log message
 * @param  int    error   - error linked to the message (if any)
 * @param  int    level   - log level of the message
 *
 * @return int - the same error
 */
int log2Debug(string message, int error, int level) {
   int debugLevel = LOG_WARN;

   if (level >= debugLevel) {
      //debug(message, error, level);
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
 * @return int - the same error
 */
int log2Mail(string message, int error, int level) {
   // note: to only initialize the appender you may send a message of level LOG_OFF
   static bool isRecursion = false; if (isRecursion) {
      Alert("log2Mail(1)  recursion (", message, "error: ", error, ")");   // send to terminal log instead
      return(error);
   }
   isRecursion = true;
   string sender="", receiver="";

   // read the configuration on first usage
   static int configLevel = EMPTY; if (configLevel == EMPTY) {
      string sValue = GetConfigString("Log", "Log2Mail", "off");           // default: off
      configLevel = StrToLogLevel(sValue, F_ERR_INVALID_PARAMETER);

      if (configLevel != EMPTY) {                                          // logging to mail is enabled
         sender   = GetConfigString("Mail", "Sender", "mt4@"+ GetHostName() +".localdomain");
         receiver = GetConfigString("Mail", "Receiver");
         if (!StrIsEmailAddress(sender))   configLevel = _int(LOG_OFF, catch("log2Mail(2)  invalid mail sender address configuration [Mail]->Sender = "+ sender, ERR_INVALID_CONFIG_VALUE));
         if (!StrIsEmailAddress(receiver)) configLevel = _int(LOG_OFF, catch("log2Mail(3)  invalid mail receiver address configuration [Mail]->Receiver = "+ receiver, ERR_INVALID_CONFIG_VALUE));
      }
      else configLevel = _int(LOG_OFF, catch("log2Mail(4)  invalid loglevel configuration [Log]->Log2Mail = "+ sValue, ERR_INVALID_CONFIG_VALUE));
   }

   // apply the configured loglevel filter
   if (level >= configLevel && level!=LOG_OFF) {
      message = LogLevelDescription(level) +":  "+ Symbol() +","+ PeriodDescription(Period()) +"  "+ __NAME() +"::"+ message + ifString(error, "  ["+ ErrorToStr(error) +"]", "");
      string subject = message;
      string body = message + NL +"("+ TimeToStr(TimeLocal(), TIME_MINUTES|TIME_SECONDS) +", "+ GetAccountAlias() +")";

      if (!SendEmail(sender, receiver, subject, body)) {
         configLevel = LOG_OFF;                                            // disable the appender if sending failed
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
   // note: to only initialize the appender you may send a message of level LOG_OFF
   static bool isRecursion = false; if (isRecursion) {
      Alert("log2SMS(1)  recursion (", message, "error: ", error, ")");    // send to terminal log instead
      return(error);
   }
   isRecursion = true;
   string receiver = "";

   // read the configuration on first usage
   static int configLevel = EMPTY; if (configLevel == EMPTY) {
      string sValue = GetConfigString("Log", "Log2SMS", "off");            // default: off
      configLevel = StrToLogLevel(sValue, F_ERR_INVALID_PARAMETER);

      if (configLevel != EMPTY) {                                          // logging to SMS is enabled
         receiver = GetConfigString("SMS", "Receiver");
         if (!StrIsPhoneNumber(receiver)) configLevel = _int(LOG_OFF, catch("log2SMS(2)  invalid phone number configuration: [SMS]->Receiver = "+ receiver, ERR_INVALID_CONFIG_VALUE));
      }
      else configLevel = _int(LOG_OFF, catch("log2SMS(3)  invalid loglevel configuration [Log]->Log2SMS = "+ sValue, ERR_INVALID_CONFIG_VALUE));
   }

   // apply the configured loglevel filter
   if (level >= configLevel && level!=LOG_OFF) {
      string text = LogLevelDescription(level) +":  "+ Symbol() +","+ PeriodDescription(Period()) +"  "+ __NAME() +"::"+ message + ifString(error, "  ["+ ErrorToStr(error) +"]", "");
      string accountTime = "("+ TimeToStr(TimeLocal(), TIME_MINUTES|TIME_SECONDS) +", "+ GetAccountAlias() +")";

      if (!SendSMS(receiver, text + NL + accountTime)) {
         configLevel = LOG_OFF;                                            // disable the appender if sending failed
      }
   }

   isRecursion = false;
   return(error);
}
