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
   if (level >= LOG_WARN) Alert(message, error, level);

   // ...

   if (level == LOG_WARN) {
      //if (isWarn2Mail) MailAppender(message, error, level);
      //if (isWarn2SMS)  SMSAppender(message, error, level);
   }
   else if (level == LOG_ERROR) {
      //if (isError2Mail) MailAppender(message, error, level);
      //if (isError2SMS)  SMSAppender(message, error, level);
   }
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
 * Send a log message to the mail appender.
 *
 * @param  string message          - log message
 * @param  int    error [optional] - error linked to the message (default: none)
 * @param  int    level [optional] - log level of the message (default: LOG_INFO)
 *
 * @return int - the same error
 */
int log2Mail(string message, int error=NO_ERROR, int level=LOG_INFO) {

   // ERROR:   GBPJPY,M5  Duel::rsfLib1::OrderSendEx(27)  error while trying to Stop Buy 0.01 GBPJPY "Duel.L.2911.+17" at 136.08'8, stop distance=0 pip (market: 136.11'0/136.11'5) after 0.609 s  [ERR_INVALID_STOP]
   // (13:29:01, ICM-DM-EUR)

   return(error);
}
