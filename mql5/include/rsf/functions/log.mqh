
/**
 * Send a message to the system debugger.
 *
 * @param  string message             - message
 * @param  int    error    [optional] - error code (default: none)
 * @param  int    loglevel [optional] - loglevel to add to the message (default: LOG_DEBUG)
 *
 * @return int - the same error
 */
int debug(string message, int error=NO_ERROR, int loglevel=LOG_DEBUG) {
   // Note: This function MUST NOT call MQL library functions. Calling DLL functions is OK.
   if (!IsDllsAllowed()) {
      Alert("debug(1)  DLL calls are not enabled (", message, ", error: ", error, ")");
      return(error);
   }
   static bool isRecursion = false; if (isRecursion) {
      Alert("debug(2)  recursion: ", message, ", error: ", error, ", ", LoglevelToStrW(loglevel));
      return(error);
   }
   isRecursion = true;

   // compose message details
   string sPrefix = "MetaTrader";                              // add a prefix for message filtering by DebugView: "MetaTrader" or "T"
   if (IsTesting()) {                                          // if called very early global vars may not yet be set
      datetime time = TimeCurrent();                           // may be NULL, intentionally no error handling as it would cause recursion
      if (!time && Bars) time = Time[0];
      sPrefix = GmtTimeFormat(time, "T %d.%m.%Y %H:%M:%S");
   }

   string sLoglevel = "";
   if (loglevel != LOG_DEBUG) sLoglevel = LoglevelDescription(loglevel);
   sLoglevel = StrPadRight(sLoglevel, 6);

   string sError = "";
   if (error != NO_ERROR) sError = StringConcatenate("  [", ErrorToStr(error), "]");

   OutputDebugStringW(StringConcatenate(sPrefix, " ", sLoglevel, " ", Symbol(), ",", PeriodDescription(), "  ", ModuleName(true), "::", StrReplace(StrReplace(message, EOL_WINDOWS, " "), EOL_UNIX, " "), sError));

   isRecursion = false;
   return(error);
}


/**
 * Check for and handle runtime errors. If an error occurred the error is logged and stored in the global var "last_error".
 * After return the internal MQL error as returned by GetLastError() is always reset.
 *
 * @param  string caller           - location identifier of the caller
 * @param  int    error [optional] - trigger a custom error (default: no)
 *
 * @return int - the same error
 */
int catch(string caller, int error = NO_ERROR) {
   if      (!error                  ) { error  =                      GetLastError(); }
   else if (error == ERR_WIN32_ERROR) { error += GetLastWin32Error(); GetLastError(); }
   else                               {                               GetLastError(); }
   static bool isRecursion = false;

   if (error != 0) {
      if (isRecursion) {
         Alert("catch(1)  recursion: ", caller, ", error: ", error);
         return(debug("catch(1)  recursion: "+ caller, error, LOG_ERROR));
      }
      isRecursion = true;

      string message = caller;
      int level = LOG_FATAL;

      // TODO: log2Terminal(message, error, level);
      string sLoglevel = ""; if (level != LOG_DEBUG) sLoglevel = LoglevelDescription(level) +"  ";
      string sError    = ""; if (error != NO_ERROR)  sError    = " ["+ ErrorToStr(error) +"]";
      Print(sLoglevel, StrReplace(StrReplace(message, EOL_WINDOWS, " "), EOL_UNIX, " "), sError);

      // TODO: log2Debug(message, error, level);
      debug(message, error, level);

      // TODO: log2Alert(message, error, level);
      if (IsTesting()) {                                                            // neither Alert() nor MessageBox() can be used
         string caption = "Strategy Tester "+ Symbol() +","+ PeriodDescription();
         int pos = StringFind(message, ") ");                                       // insert a line-wrap after the first closing function brace
         if (pos != -1) message = StrLeft(message, pos+1) + NL + StrTrim(StrSubstr(message, pos+2));
         message = TimeToStr(TimeLocal(), TIME_FULL) + NL + LoglevelDescription(level) +" in "+ ModuleName(true) +"::"+ message + (error ? "  ["+ sError +"]" : "");
         PlaySoundEx("alert.wav");
         MessageBoxEx(caption, message, MB_ICONERROR|MB_OK|MB_DONT_LOG);
      }
      else {
         Alert(LoglevelDescription(level), ":   ", Symbol(), ",", PeriodDescription(), "  ", ModuleName(true), "::", message, (error ? "  ["+ sError +"]" : ""));
      }

      // set the error
      SetLastError(error);
   }

   isRecursion = false;
   return(error);
}
