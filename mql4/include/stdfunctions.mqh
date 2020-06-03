/**
 * Globale Funktionen.
 */
#include <configuration.mqh>
#include <metaquotes.mqh>                                            // MetaQuotes-Aliase
#include <rsfExpander.mqh>


/**
 * Lädt den Input-Dialog des aktuellen Programms neu.
 *
 * @return int - Fehlerstatus
 */
int start.RelaunchInputDialog() {
   int error;

   if (IsExpert()) {
      if (!IsTesting())
         error = Chart.Expert.Properties();
   }
   else if (IsIndicator()) {
      //if (!IsTesting())
      //   error = Chart.Indicator.Properties();                     // TODO: implementieren
   }

   if (IsError(error))
      SetLastError(error, NULL);
   return(error);
}


/**
 * Send a message to the system debugger.
 *
 * @param  string message          - message
 * @param  int    error [optional] - error code
 *
 * @return int - the same error
 *
 * Notes:
 *  - No part of this function must load additional EX4 libaries.
 *  - The terminal must run with Administrator rights for OutputDebugString() to transport debug messages.
 */
int debug(string message, int error = NO_ERROR) {
   static bool recursiveCall = false;
   if (recursiveCall) {                               // prevent recursive calls
      Print("debug(1)  recursive call: ", message);
      return(error);
   }
   recursiveCall = true;

   if (error != NO_ERROR) message = StringConcatenate(message, "  [", ErrorToStr(error), "]");

   if (This.IsTesting()) string application = StringConcatenate(GmtTimeFormat(MarketInfo(Symbol(), MODE_TIME), "%d.%m.%Y %H:%M:%S"), " Tester::");
   else                         application = "MetaTrader::";

   OutputDebugStringA(StringConcatenate(application, Symbol(), ",", PeriodDescription(Period()), "::", __NAME(), "::", StrReplace(StrReplaceR(message, NL+NL, NL), NL, " ")));

   recursiveCall = false;
   return(error);
}


/**
 * Check if an error occurred and signal it. The error is stored in the global var "last_error". After the function returned
 * the internal MQL error code as returned by GetLastError() is always reset.
 *
 * @param  string location            - the error's location identifier incl. optional message
 * @param  int    error    [optional] - enforce a specific error (default: none)
 * @param  bool   orderPop [optional] - whether the last order context should be restored from the order context stack
 *                                      (default: no)
 *
 * @return int - the same error
 */
int catch(string location, int error=NO_ERROR, bool orderPop=false) {
   orderPop = orderPop!=0;

   if      (!error                  ) { error  =                      GetLastError(); }
   else if (error == ERR_WIN32_ERROR) { error += GetLastWin32Error(); GetLastError(); }
   else                               {                               GetLastError(); }

   static bool recursiveCall = false;

   if (error != NO_ERROR) {
      if (recursiveCall)                                                                              // prevent recursive calls
         return(debug("catch(1)  recursive call: "+ location, error));
      recursiveCall = true;

      // always send the error to the system debugger
      debug("ERROR: "+ location, error);

      // log the error
      string name    = __NAME();
      string message = location +"  ["+ ErrorToStr(error) +"]";
      bool logged, alerted;
      if (__ExecutionContext[EC.logToCustomEnabled] != 0)                                             // custom log, on error fall-back to terminal log
         logged = logged || LogMessageA(__ExecutionContext, "ERROR: "+ name +"::"+ message, error);
      if (!logged) {
         Alert("ERROR:   ", Symbol(), ",", PeriodDescription(Period()), "  ", name, "::", message);   // terminal log
         logged  = true;
         alerted = alerted || !IsExpert() || !IsTesting();
      }
      message = name +"::"+ message;

      // display the error
      if (IsTesting()) {
         // neither Alert() nor MessageBox() can be used
         string caption = "Strategy Tester "+ Symbol() +","+ PeriodDescription(Period());
         int pos = StringFind(message, ") ");
         if (pos == -1) message = "ERROR in "+ message;                                               // wrap message after the closing function brace
         else           message = "ERROR in "+ StrLeft(message, pos+1) + NL + StringTrimLeft(StrSubstr(message, pos+2));
                        message = TimeToStr(TimeCurrentEx("catch(2)"), TIME_FULL) + NL + message;
         PlaySoundEx("alert.wav");
         MessageBoxEx(caption, message, MB_ICONERROR|MB_OK|MB_DONT_LOG);
         alerted = true;
      }
      else {
         message = "ERROR:   "+ Symbol() +","+ PeriodDescription(Period()) +"  "+ message;
         if (!alerted) {
            Alert(message);
            alerted = true;
         }
         if (IsExpert()) {
            string accountTime = "("+ TimeToStr(TimeLocal(), TIME_MINUTES|TIME_SECONDS) +", "+ AccountAlias(ShortAccountCompany(), GetAccountNumber()) +")";
            if (__LOG_ERROR.mail) SendEmail(__LOG_ERROR.mail.sender, __LOG_ERROR.mail.receiver, message, message + NL + accountTime);
            if (__LOG_ERROR.sms)  SendSMS  (__LOG_ERROR.sms.receiver, message + NL + accountTime);
         }
      }

      // set last_error
      SetLastError(error, NULL);
      recursiveCall = false;
   }

   if (orderPop)
      OrderPop(location);
   return(error);
}


/**
 * Show a warning with an optional error but don't set the error.
 *
 * @param  string message          - message to display
 * @param  int    error [optional] - error to display
 *
 * @return int - the same error
 */
int warn(string message, int error = NO_ERROR) {
   static bool recursiveCall = false;
   if (recursiveCall)                                                                           // prevent recursive calls
      return(debug("warn(1)  recursive call: "+ message, error));
   recursiveCall = true;

   // always send the warning to the system debugger
   debug("WARN: "+ message, error);

   if (error != NO_ERROR) message = message +"  ["+ ErrorToStr(error) +"]";

   // log the warning
   string name = __NAME();
   bool logged, alerted;
   if (__ExecutionContext[EC.logToCustomEnabled] != 0)                                          // custom log, on error fall-back to terminal log
      logged = logged || LogMessageA(__ExecutionContext, "WARN: "+ name +"::"+ message, error);
   if (!logged) {
      Alert("WARN:   ", Symbol(), ",", PeriodDescription(Period()), "  ", name, "::", message); // terminal log
      logged  = true;
      alerted = !IsExpert() || !IsTesting();
   }
   message = name +"::"+ message;

   // display the warning
   if (IsTesting()) {
      // neither Alert() nor MessageBox() can be used
      string caption = "Strategy Tester "+ Symbol() +","+ PeriodDescription(Period());
      int pos = StringFind(message, ") ");
      if (pos == -1) message = "WARN in "+ message;                                             // wrap message after the closing function brace
      else           message = "WARN in "+ StrLeft(message, pos+1) + NL + StringTrimLeft(StrSubstr(message, pos+2));
                     message = TimeToStr(TimeCurrentEx("warn(1)"), TIME_FULL) + NL + message;

      PlaySoundEx("alert.wav");
      MessageBoxEx(caption, message, MB_ICONERROR|MB_OK|MB_DONT_LOG);
   }
   else {
      message = "WARN:   "+ Symbol() +","+ PeriodDescription(Period()) +"  "+ message;
      if (!alerted) {
         Alert(message);
         alerted = true;
      }
      if (IsExpert()) {
         string accountTime = "("+ TimeToStr(TimeLocal(), TIME_MINUTES|TIME_SECONDS) +", "+ AccountAlias(ShortAccountCompany(), GetAccountNumber()) +")";
         if (__LOG_WARN.mail) SendEmail(__LOG_WARN.mail.sender, __LOG_WARN.mail.receiver, message, message + NL + accountTime);
         if (__LOG_WARN.sms)  SendSMS  (__LOG_WARN.sms.receiver, message + NL + accountTime);
      }
   }

   recursiveCall = false;
   return(error);
}


/**
 * Log a message to the configured log appenders.
 *
 * @param  string message
 * @param  int    error [optional] - error to log (default: none)
 *
 * @return int - the same error
 */
int log(string message, int error = NO_ERROR) {
   if (!__ExecutionContext[EC.logEnabled]) return(error);         // skip logging if fully disabled

   static bool recursiveCall = false;
   if (recursiveCall)                                             // prevent recursive calls
      return(debug("log(1)  recursive call: "+ message, error));
   recursiveCall = true;

   if (__ExecutionContext[EC.logToDebugEnabled] != 0) {           // send the message to the system debugger
      debug(message, error);
   }
   if (__ExecutionContext[EC.logToTerminalEnabled] != 0) {        // send the message to the terminal log
      string sError = "";
      if (error != NO_ERROR) sError = "  ["+ ErrorToStr(error) +"]";
      Print(__NAME(), "::", StrReplace(message, NL, " "), sError);
   }
   if (__ExecutionContext[EC.logToCustomEnabled] != 0) {          // send the message to a custom logger
      LogMessageA(__ExecutionContext, message, error);
   }

   recursiveCall = false;
   return(error);
}


/**
 * Set the last error code of the module. If called in a library the error will bubble up to the program's main module.
 * If called in an indicator loaded by iCustom() the error will bubble up to the caller of iCustom(). The error code NO_ERROR
 * will never bubble up.
 *
 * @param  int error - error code
 * @param  int param - ignored, any other value (default: none)
 *
 * @return int - the same error code (for chaining)
 */
int SetLastError(int error, int param = NULL) {
   last_error = ec_SetMqlError(__ExecutionContext, error);

   if (error != NO_ERROR) /*&&*/ if (IsExpert())
      CheckErrors("SetLastError(1)");                             // update __STATUS_OFF in experts
   return(error);
}


/**
 * Gibt die Beschreibung eines Fehlercodes zurück.
 *
 * @param  int error - MQL- oder gemappter Win32-Fehlercode
 *
 * @return string
 */
string ErrorDescription(int error) {
   if (error >= ERR_WIN32_ERROR)                                                                                     // >=100000, for Win32 error descriptions @see
      return(ErrorToStr(error));                                                                                     // FormatMessage(FORMAT_MESSAGE_FROM_SYSTEM, NULL, GetLastWin32Error(), ...))

   switch (error) {
      case NO_ERROR                       : return("no error"                                                  );    //      0

      // trade server errors
      case ERR_NO_RESULT                  : return("no result"                                                 );    //      1
      case ERR_TRADESERVER_GONE           : return("trade server gone"                                         );    //      2
      case ERR_INVALID_TRADE_PARAMETERS   : return("invalid trade parameters"                                  );    //      3
      case ERR_SERVER_BUSY                : return("trade server busy"                                         );    //      4
      case ERR_OLD_VERSION                : return("old terminal version"                                      );    //      5
      case ERR_NO_CONNECTION              : return("no connection to trade server"                             );    //      6
      case ERR_NOT_ENOUGH_RIGHTS          : return("not enough rights"                                         );    //      7
      case ERR_TOO_FREQUENT_REQUESTS      : return("too frequent requests"                                     );    //      8
      case ERR_MALFUNCTIONAL_TRADE        : return("malfunctional trade operation"                             );    //      9
      case ERR_ACCOUNT_DISABLED           : return("account disabled"                                          );    //     64
      case ERR_INVALID_ACCOUNT            : return("invalid account"                                           );    //     65
      case ERR_TRADE_TIMEOUT              : return("trade timeout"                                             );    //    128
      case ERR_INVALID_PRICE              : return("invalid price"                                             );    //    129 price moves too fast (away)
      case ERR_INVALID_STOP               : return("invalid stop"                                              );    //    130
      case ERR_INVALID_TRADE_VOLUME       : return("invalid trade volume"                                      );    //    131
      case ERR_MARKET_CLOSED              : return("market closed"                                             );    //    132
      case ERR_TRADE_DISABLED             : return("trading disabled"                                          );    //    133
      case ERR_NOT_ENOUGH_MONEY           : return("not enough money"                                          );    //    134
      case ERR_PRICE_CHANGED              : return("price changed"                                             );    //    135
      case ERR_OFF_QUOTES                 : return("off quotes"                                                );    //    136 atm the broker cannot provide prices
      case ERR_BROKER_BUSY                : return("broker busy, automated trading disabled"                   );    //    137
      case ERR_REQUOTE                    : return("requote"                                                   );    //    138
      case ERR_ORDER_LOCKED               : return("order locked"                                              );    //    139
      case ERR_LONG_POSITIONS_ONLY_ALLOWED: return("long positions only allowed"                               );    //    140
      case ERR_TOO_MANY_REQUESTS          : return("too many requests"                                         );    //    141
      case ERR_ORDER_QUEUED               : return("order queued"                                              );    //    142
      case ERR_ORDER_ACCEPTED             : return("order accepted"                                            );    //    143
      case ERR_ORDER_DISCARDED            : return("order discarded"                                           );    //    144
      case ERR_TRADE_MODIFY_DENIED        : return("modification denied because too close to market"           );    //    145
      case ERR_TRADE_CONTEXT_BUSY         : return("trade context busy"                                        );    //    146
      case ERR_TRADE_EXPIRATION_DENIED    : return("expiration setting denied by broker"                       );    //    147
      case ERR_TRADE_TOO_MANY_ORDERS      : return("number of open orders reached the broker limit"            );    //    148
      case ERR_TRADE_HEDGE_PROHIBITED     : return("hedging prohibited"                                        );    //    149
      case ERR_TRADE_PROHIBITED_BY_FIFO   : return("prohibited by FIFO rules"                                  );    //    150

      // runtime errors
      case ERR_NO_MQLERROR                : return("no MQL error"                                              );    //   4000 never generated error
      case ERR_WRONG_FUNCTION_POINTER     : return("wrong function pointer"                                    );    //   4001
      case ERR_ARRAY_INDEX_OUT_OF_RANGE   : return("array index out of range"                                  );    //   4002
      case ERR_NO_MEMORY_FOR_CALL_STACK   : return("no memory for function call stack"                         );    //   4003
      case ERR_RECURSIVE_STACK_OVERFLOW   : return("recursive stack overflow"                                  );    //   4004
      case ERR_NOT_ENOUGH_STACK_FOR_PARAM : return("not enough stack for parameter"                            );    //   4005
      case ERR_NO_MEMORY_FOR_PARAM_STRING : return("no memory for parameter string"                            );    //   4006
      case ERR_NO_MEMORY_FOR_TEMP_STRING  : return("no memory for temp string"                                 );    //   4007
      case ERR_NOT_INITIALIZED_STRING     : return("uninitialized string"                                      );    //   4008
      case ERR_NOT_INITIALIZED_ARRAYSTRING: return("uninitialized string in array"                             );    //   4009
      case ERR_NO_MEMORY_FOR_ARRAYSTRING  : return("no memory for string in array"                             );    //   4010
      case ERR_TOO_LONG_STRING            : return("string too long"                                           );    //   4011
      case ERR_REMAINDER_FROM_ZERO_DIVIDE : return("remainder from division by zero"                           );    //   4012
      case ERR_ZERO_DIVIDE                : return("division by zero"                                          );    //   4013
      case ERR_UNKNOWN_COMMAND            : return("unknown command"                                           );    //   4014
      case ERR_WRONG_JUMP                 : return("wrong jump"                                                );    //   4015
      case ERR_NOT_INITIALIZED_ARRAY      : return("array not initialized"                                     );    //   4016
      case ERR_DLL_CALLS_NOT_ALLOWED      : return("DLL calls not allowed"                                     );    //   4017
      case ERR_CANNOT_LOAD_LIBRARY        : return("cannot load library"                                       );    //   4018
      case ERR_CANNOT_CALL_FUNCTION       : return("cannot call function"                                      );    //   4019
      case ERR_EX4_CALLS_NOT_ALLOWED      : return("EX4 library calls not allowed"                             );    //   4020
      case ERR_NO_MEMORY_FOR_RETURNED_STR : return("no memory for temp string returned from function"          );    //   4021
      case ERR_SYSTEM_BUSY                : return("system busy"                                               );    //   4022
      case ERR_DLL_EXCEPTION              : return("DLL exception"                                             );    //   4023
      case ERR_INTERNAL_ERROR             : return("internal error"                                            );    //   4024
      case ERR_OUT_OF_MEMORY              : return("out of memory"                                             );    //   4025
      case ERR_INVALID_POINTER            : return("invalid pointer"                                           );    //   4026
      case ERR_FORMAT_TOO_MANY_FORMATTERS : return("too many formatters in the format function"                );    //   4027
      case ERR_FORMAT_TOO_MANY_PARAMETERS : return("parameters count exceeds formatters count"                 );    //   4028
      case ERR_ARRAY_INVALID              : return("invalid array"                                             );    //   4029
      case ERR_CHART_NOREPLY              : return("no reply from chart"                                       );    //   4030
      case ERR_INVALID_FUNCTION_PARAMSCNT : return("invalid function parameter count"                          );    //   4050 invalid parameters count
      case ERR_INVALID_PARAMETER          : return("invalid parameter"                                         );    //   4051 invalid parameter
      case ERR_STRING_FUNCTION_INTERNAL   : return("internal string function error"                            );    //   4052
      case ERR_ARRAY_ERROR                : return("array error"                                               );    //   4053 array error
      case ERR_SERIES_NOT_AVAILABLE       : return("requested time series not available"                       );    //   4054 time series not available
      case ERR_CUSTOM_INDICATOR_ERROR     : return("custom indicator error"                                    );    //   4055 custom indicator error
      case ERR_INCOMPATIBLE_ARRAYS        : return("incompatible arrays"                                       );    //   4056 incompatible arrays
      case ERR_GLOBAL_VARIABLES_PROCESSING: return("global variables processing error"                         );    //   4057
      case ERR_GLOBAL_VARIABLE_NOT_FOUND  : return("global variable not found"                                 );    //   4058
      case ERR_FUNC_NOT_ALLOWED_IN_TESTER : return("function not allowed in tester"                            );    //   4059
      case ERR_FUNCTION_NOT_CONFIRMED     : return("function not confirmed"                                    );    //   4060
      case ERR_SEND_MAIL_ERROR            : return("send mail error"                                           );    //   4061
      case ERR_STRING_PARAMETER_EXPECTED  : return("string parameter expected"                                 );    //   4062
      case ERR_INTEGER_PARAMETER_EXPECTED : return("integer parameter expected"                                );    //   4063
      case ERR_DOUBLE_PARAMETER_EXPECTED  : return("double parameter expected"                                 );    //   4064
      case ERR_ARRAY_AS_PARAMETER_EXPECTED: return("array parameter expected"                                  );    //   4065
      case ERS_HISTORY_UPDATE             : return("requested history is updating"                             );    //   4066 requested history is updating      Status
      case ERR_TRADE_ERROR                : return("trade function error"                                      );    //   4067 trade function error
      case ERR_RESOURCE_NOT_FOUND         : return("resource not found"                                        );    //   4068
      case ERR_RESOURCE_NOT_SUPPORTED     : return("resource not supported"                                    );    //   4069
      case ERR_RESOURCE_DUPLICATED        : return("duplicate resource"                                        );    //   4070
      case ERR_INDICATOR_CANNOT_INIT      : return("custom indicator initialization error"                     );    //   4071
      case ERR_INDICATOR_CANNOT_LOAD      : return("custom indicator load error"                               );    //   4072
      case ERR_NO_HISTORY_DATA            : return("no history data"                                           );    //   4073
      case ERR_NO_MEMORY_FOR_HISTORY      : return("no memory for history data"                                );    //   4074
      case ERR_NO_MEMORY_FOR_INDICATOR    : return("not enough memory for indicator calculation"               );    //   4075
      case ERR_END_OF_FILE                : return("end of file"                                               );    //   4099 end of file
      case ERR_FILE_ERROR                 : return("file error"                                                );    //   4100 file error
      case ERR_WRONG_FILE_NAME            : return("wrong file name"                                           );    //   4101
      case ERR_TOO_MANY_OPENED_FILES      : return("too many opened files"                                     );    //   4102
      case ERR_CANNOT_OPEN_FILE           : return("cannot open file"                                          );    //   4103
      case ERR_INCOMPATIBLE_FILEACCESS    : return("incompatible file access"                                  );    //   4104
      case ERR_NO_TICKET_SELECTED         : return("no ticket selected"                                        );    //   4105
      case ERR_SYMBOL_NOT_AVAILABLE       : return("symbol not available"                                      );    //   4106
      case ERR_INVALID_PRICE_PARAM        : return("invalid price parameter for trade function"                );    //   4107
      case ERR_INVALID_TICKET             : return("invalid ticket"                                            );    //   4108
      case ERR_TRADE_NOT_ALLOWED          : return("automated trading disabled in terminal"                    );    //   4109
      case ERR_LONGS_NOT_ALLOWED          : return("long trades not enabled"                                   );    //   4110
      case ERR_SHORTS_NOT_ALLOWED         : return("short trades not enabled"                                  );    //   4111
      case ERR_AUTOMATED_TRADING_DISABLED : return("automated trading disabled by broker"                      );    //   4112
      case ERR_OBJECT_ALREADY_EXISTS      : return("object already exists"                                     );    //   4200
      case ERR_UNKNOWN_OBJECT_PROPERTY    : return("unknown object property"                                   );    //   4201
      case ERR_OBJECT_DOES_NOT_EXIST      : return("object doesn't exist"                                      );    //   4202
      case ERR_UNKNOWN_OBJECT_TYPE        : return("unknown object type"                                       );    //   4203
      case ERR_NO_OBJECT_NAME             : return("no object name"                                            );    //   4204
      case ERR_OBJECT_COORDINATES_ERROR   : return("object coordinates error"                                  );    //   4205
      case ERR_NO_SPECIFIED_SUBWINDOW     : return("no specified subwindow"                                    );    //   4206
      case ERR_OBJECT_ERROR               : return("object error"                                              );    //   4207 object error
      case ERR_CHART_PROP_INVALID         : return("unknown chart property"                                    );    //   4210
      case ERR_CHART_NOT_FOUND            : return("chart not found"                                           );    //   4211
      case ERR_CHARTWINDOW_NOT_FOUND      : return("chart subwindow not found"                                 );    //   4212
      case ERR_CHARTINDICATOR_NOT_FOUND   : return("chart indicator not found"                                 );    //   4213
      case ERR_SYMBOL_SELECT              : return("symbol select error"                                       );    //   4220
      case ERR_NOTIFICATION_SEND_ERROR    : return("error placing notification into sending queue"             );    //   4250
      case ERR_NOTIFICATION_PARAMETER     : return("notification parameter error"                              );    //   4251 empty string passed
      case ERR_NOTIFICATION_SETTINGS      : return("invalid notification settings"                             );    //   4252
      case ERR_NOTIFICATION_TOO_FREQUENT  : return("too frequent notifications"                                );    //   4253
      case ERR_FTP_NOSERVER               : return("FTP server is not specified"                               );    //   4260
      case ERR_FTP_NOLOGIN                : return("FTP login is not specified"                                );    //   4261
      case ERR_FTP_CONNECT_FAILED         : return("FTP connection failed"                                     );    //   4262
      case ERR_FTP_CLOSED                 : return("FTP connection closed"                                     );    //   4263
      case ERR_FTP_CHANGEDIR              : return("FTP path not found on server"                              );    //   4264
      case ERR_FTP_FILE_ERROR             : return("file not found to send to FTP server"                      );    //   4265
      case ERR_FTP_ERROR                  : return("common error during FTP data transmission"                 );    //   4266
      case ERR_FILE_TOO_MANY_OPENED       : return("too many opened files"                                     );    //   5001
      case ERR_FILE_WRONG_FILENAME        : return("wrong file name"                                           );    //   5002
      case ERR_FILE_TOO_LONG_FILENAME     : return("too long file name"                                        );    //   5003
      case ERR_FILE_CANNOT_OPEN           : return("cannot open file"                                          );    //   5004
      case ERR_FILE_BUFFER_ALLOC_ERROR    : return("text file buffer allocation error"                         );    //   5005
      case ERR_FILE_CANNOT_DELETE         : return("cannot delete file"                                        );    //   5006
      case ERR_FILE_INVALID_HANDLE        : return("invalid file handle, file already closed or wasn't opened" );    //   5007
      case ERR_FILE_UNKNOWN_HANDLE        : return("unknown file handle, handle index is out of handle table"  );    //   5008
      case ERR_FILE_NOT_TOWRITE           : return("file must be opened with FILE_WRITE flag"                  );    //   5009
      case ERR_FILE_NOT_TOREAD            : return("file must be opened with FILE_READ flag"                   );    //   5010
      case ERR_FILE_NOT_BIN               : return("file must be opened with FILE_BIN flag"                    );    //   5011
      case ERR_FILE_NOT_TXT               : return("file must be opened with FILE_TXT flag"                    );    //   5012
      case ERR_FILE_NOT_TXTORCSV          : return("file must be opened with FILE_TXT or FILE_CSV flag"        );    //   5013
      case ERR_FILE_NOT_CSV               : return("file must be opened with FILE_CSV flag"                    );    //   5014
      case ERR_FILE_READ_ERROR            : return("file read error"                                           );    //   5015
      case ERR_FILE_WRITE_ERROR           : return("file write error"                                          );    //   5016
      case ERR_FILE_BIN_STRINGSIZE        : return("string size must be specified for binary file"             );    //   5017
      case ERR_FILE_INCOMPATIBLE          : return("incompatible file, for string arrays-TXT, for others-BIN"  );    //   5018
      case ERR_FILE_IS_DIRECTORY          : return("file is a directory"                                       );    //   5019
      case ERR_FILE_NOT_FOUND             : return("file not found"                                            );    //   5020
      case ERR_FILE_CANNOT_REWRITE        : return("file cannot be rewritten"                                  );    //   5021
      case ERR_FILE_WRONG_DIRECTORYNAME   : return("wrong directory name"                                      );    //   5022
      case ERR_FILE_DIRECTORY_NOT_EXIST   : return("directory does not exist"                                  );    //   5023
      case ERR_FILE_NOT_DIRECTORY         : return("file is not a directory"                                   );    //   5024
      case ERR_FILE_CANT_DELETE_DIRECTORY : return("cannot delete directory"                                   );    //   5025
      case ERR_FILE_CANT_CLEAN_DIRECTORY  : return("cannot clean directory"                                    );    //   5026
      case ERR_FILE_ARRAYRESIZE_ERROR     : return("array resize error"                                        );    //   5027
      case ERR_FILE_STRINGRESIZE_ERROR    : return("string resize error"                                       );    //   5028
      case ERR_FILE_STRUCT_WITH_OBJECTS   : return("struct contains strings or dynamic arrays"                 );    //   5029
      case ERR_WEBREQUEST_INVALID_ADDRESS : return("invalid URL"                                               );    //   5200
      case ERR_WEBREQUEST_CONNECT_FAILED  : return("failed to connect"                                         );    //   5201
      case ERR_WEBREQUEST_TIMEOUT         : return("timeout exceeded"                                          );    //   5202
      case ERR_WEBREQUEST_REQUEST_FAILED  : return("HTTP request failed"                                       );    //   5203

      // user defined errors: 65536-99999 (0x10000-0x1869F)
      case ERR_USER_ERROR_FIRST           : return("first user error"                                          );    //  65536
      case ERR_CANCELLED_BY_USER          : return("cancelled by user"                                         );    //  65537
      case ERR_CONCURRENT_MODIFICATION    : return("concurrent modification"                                   );    //  65538
      case ERS_EXECUTION_STOPPING         : return("program execution stopping"                                );    //  65539   status
      case ERR_FUNC_NOT_ALLOWED           : return("function not allowed"                                      );    //  65540
      case ERR_HISTORY_INSUFFICIENT       : return("insufficient history for calculation"                      );    //  65541
      case ERR_ILLEGAL_STATE              : return("illegal runtime state"                                     );    //  65542
      case ERR_ACCESS_DENIED              : return("access denied"                                             );    //  65543
      case ERR_INVALID_COMMAND            : return("invalid or unknow command"                                 );    //  65544
      case ERR_INVALID_CONFIG_VALUE       : return("invalid configuration value"                               );    //  65545
      case ERR_INVALID_FILE_FORMAT        : return("invalid file format"                                       );    //  65546
      case ERR_INVALID_INPUT_PARAMETER    : return("invalid input parameter"                                   );    //  65547
      case ERR_INVALID_MARKET_DATA        : return("invalid market data"                                       );    //  65548
      case ERR_INVALID_TIMEZONE_CONFIG    : return("invalid or missing timezone configuration"                 );    //  65549
      case ERR_MIXED_SYMBOLS              : return("mixed symbols encountered"                                 );    //  65550
      case ERR_NOT_IMPLEMENTED            : return("feature not implemented"                                   );    //  65551
      case ERR_ORDER_CHANGED              : return("order status changed"                                      );    //  65552
      case ERR_RUNTIME_ERROR              : return("runtime error"                                             );    //  65553
      case ERR_TERMINAL_INIT_FAILURE      : return("multiple Expert::init() calls"                             );    //  65554
      case ERS_TERMINAL_NOT_YET_READY     : return("terminal not yet ready"                                    );    //  65555   status
      case ERR_TOTAL_POSITION_NOT_FLAT    : return("total position encountered when flat position was expected");    //  65556
      case ERR_UNDEFINED_STATE            : return("undefined state or behaviour"                              );    //  65557
   }
   return(StringConcatenate("unknown error (", error, ")"));
}


/**
 * Ersetzt in einem String alle Vorkommen eines Substrings durch einen anderen String (kein rekursives Ersetzen).
 *
 * @param  string value   - Ausgangsstring
 * @param  string search  - Suchstring
 * @param  string replace - Ersatzstring
 *
 * @return string - modifizierter String
 */
string StrReplace(string value, string search, string replace) {
   if (!StringLen(value))  return(value);
   if (!StringLen(search)) return(value);
   if (search == replace)  return(value);

   int from=0, found=StringFind(value, search);
   if (found == -1)
      return(value);

   string result = "";

   while (found > -1) {
      result = StringConcatenate(result, StrSubstr(value, from, found-from), replace);
      from   = found + StringLen(search);
      found  = StringFind(value, search, from);
   }
   result = StringConcatenate(result, StringSubstr(value, from));

   return(result);
}


/**
 * Ersetzt in einem String alle Vorkommen eines Substrings rekursiv durch einen anderen String. Die Funktion prüft nicht,
 * ob durch Such- und Ersatzstring eine Endlosschleife ausgelöst wird.
 *
 * @param  string value   - Ausgangsstring
 * @param  string search  - Suchstring
 * @param  string replace - Ersatzstring
 *
 * @return string - rekursiv modifizierter String
 */
string StrReplaceR(string value, string search, string replace) {
   if (!StringLen(value)) return(value);

   string lastResult="", result=value;

   while (result != lastResult) {
      lastResult = result;
      result     = StrReplace(result, search, replace);
   }
   return(lastResult);
}


/**
 * Drop-in replacement for the flawed built-in function StringSubstr()
 *
 * Bugfix für den Fall StringSubstr(string, start, length=0), in dem die MQL-Funktion Unfug zurückgibt.
 * Ermöglicht zusätzlich die Angabe negativer Werte für start und length.
 *
 * @param  string str
 * @param  int    start  - wenn negativ, Startindex vom Ende des Strings
 * @param  int    length - wenn negativ, Anzahl der zurückzugebenden Zeichen links vom Startindex
 *
 * @return string
 */
string StrSubstr(string str, int start, int length = INT_MAX) {
   if (length == 0)
      return("");

   if (start < 0)
      start = Max(0, start + StringLen(str));

   if (length < 0) {
      start += 1 + length;
      length = Abs(length);
   }

   if (length == INT_MAX) {
      length = INT_MAX - start;        // start + length must not be larger than INT_MAX
   }

   return(StringSubstr(str, start, length));
}


#define SND_ASYNC           0x01       // play asynchronously
#define SND_FILENAME  0x00020000       // parameter is a file name


/**
 * Dropin-replacement for the built-in function PlaySound().
 *
 * Asynchronously plays a sound (instead of synchronously and UI blocking as the terminal does). Also plays a sound if the
 * terminal doesn't support it (e.g. in Strategy Tester). If the specified sound file is not found a message is logged but
 * execution continues normally.
 *
 * @param  string soundfile
 * @param  int    flags
 *
 * @return bool - success status
 */
bool PlaySoundEx(string soundfile, int flags = NULL) {
   string filename = StrReplace(soundfile, "/", "\\");
   string fullName = StringConcatenate(TerminalPath(), "\\sounds\\", filename);

   if (!IsFileA(fullName)) {
      fullName = StringConcatenate(GetTerminalDataPathA(), "\\sounds\\", filename);
      if (!IsFileA(fullName)) {
         if (!(flags & MB_DONT_LOG))
            log("PlaySoundEx(1)  sound file not found: \""+ soundfile +"\"", ERR_FILE_NOT_FOUND);
         return(false);
      }
   }
   PlaySoundA(fullName, NULL, SND_FILENAME|SND_ASYNC);
   return(!catch("PlaySoundEx(2)"));
}


/**
 * Asynchronously plays a sound (instead of synchronously and UI blocking as the terminal does). Also plays a sound if the
 * terminal doesn't support it (e.g. in Strategy Tester). If the specified sound file is not found an error is triggered.
 *
 * @param  string soundfile
 *
 * @return bool - success status
 */
bool PlaySoundOrFail(string soundfile) {
   string filename = StrReplace(soundfile, "/", "\\");
   string fullName = StringConcatenate(TerminalPath(), "\\sounds\\", filename);

   if (!IsFileA(fullName)) {
      fullName = StringConcatenate(GetTerminalDataPathA(), "\\sounds\\", filename);
      if (!IsFileA(fullName))
         return(!catch("PlaySoundOrFail(1)  file not found: \""+ soundfile +"\"", ERR_FILE_NOT_FOUND));
   }

   PlaySoundA(fullName, NULL, SND_FILENAME|SND_ASYNC);
   return(!catch("PlaySoundOrFail(2)"));
}


/**
 * Return a pluralized string according to the specified number of items.
 *
 * @param  int    count               - number of items to determine the result from
 * @param  string singular [optional] - singular form of string
 * @param  string plural   [optional] - plural form of string
 *
 * @return string
 */
string Pluralize(int count, string singular="", string plural="s") {
    if (Abs(count) == 1)
        return(singular);
    return(plural);
}


/**
 * Dropin replacement for Alert().
 *
 * Display an alert even if not supported by the terminal in the current context (e.g. in tester).
 *
 * @param  string message
 */
void ForceAlert(string message) {
   // ForceAlert() is used when Kansas is going bye-bye. To be as robust as possible it must have little/no dependencies.
   // Especially it must NOT call any MQL library functions. DLL functions are OK.

   Alert(message);                                             // make sure the message shows up in the terminal log

   if (IsTesting()) {
      // Alert() prints to the log but is fully ignored otherwise
      string caption = "Strategy Tester "+ Symbol() +","+ PeriodDescription(Period());
      message = TimeToStr(TimeCurrent(), TIME_FULL) + NL + message;

      PlaySoundEx("alert.wav", MB_DONT_LOG);
      MessageBoxEx(caption, message, MB_ICONERROR|MB_OK|MB_DONT_LOG);
   }
}


/**
 * Dropin replacement for the MQL function MessageBox().
 *
 * Display a modal messagebox even if not supported by the terminal in the current context (e.g. in tester or in indicators).
 *
 * @param  string caption
 * @param  string message
 * @param  int    flags
 *
 * @return int - the pressed button's key code
 */
int MessageBoxEx(string caption, string message, int flags = MB_OK) {
   string prefix = StringConcatenate(Symbol(), ",", PeriodDescription(Period()));

   if (!StrContains(caption, prefix))
      caption = StringConcatenate(prefix, " - ", caption);

   bool win32 = false;
   if      (IsTesting())                                                                                   win32 = true;
   else if (IsIndicator())                                                                                 win32 = true;
   else if (__ExecutionContext[EC.programCoreFunction]==CF_INIT && UninitializeReason()==REASON_RECOMPILE) win32 = true;

   int button;
   if (!win32) button = MessageBox(message, caption, flags);
   else        button = MessageBoxA(GetTerminalMainWindow(), message, caption, flags|MB_TOPMOST|MB_SETFOREGROUND);

   if (!(flags & MB_DONT_LOG)) {
      log("MessageBoxEx(1)  "+ message);
      log("MessageBoxEx(2)  response: "+ MessageBoxButtonToStr(button));
   }
   return(button);
}


/**
 * Gibt den Klassennamen des angegebenen Fensters zurück.
 *
 * @param  int hWnd - Handle des Fensters
 *
 * @return string - Klassenname oder Leerstring, falls ein Fehler auftrat
 */
string GetClassName(int hWnd) {
   int    bufferSize = 255;
   string buffer[]; InitializeStringBuffer(buffer, bufferSize);

   int chars = GetClassNameA(hWnd, buffer[0], bufferSize);

   while (chars >= bufferSize-1) {                                   // GetClassNameA() gibt beim Abschneiden zu langer Klassennamen {bufferSize-1} zurück.
      bufferSize <<= 1;
      InitializeStringBuffer(buffer, bufferSize);
      chars = GetClassNameA(hWnd, buffer[0], bufferSize);
   }

   if (!chars)
      return(_EMPTY_STR(catch("GetClassName()->user32::GetClassNameA()", ERR_WIN32_ERROR)));

   return(buffer[0]);
}


/**
 * Ob das aktuelle Programm im Tester läuft und der VisualMode-Status aktiv ist.
 *
 * Bugfix für IsVisualMode(). IsVisualMode() wird in Libraries zwischen aufeinanderfolgenden Tests nicht zurückgesetzt und
 * gibt bis zur Neuinitialisierung der Library den Status des ersten Tests zurück.
 *
 * @return bool
 */
bool IsVisualModeFix() {
   return(__ExecutionContext[EC.visualMode] != 0);
}


/**
 * Ob der angegebene Wert einen Fehler darstellt.
 *
 * @param  int value
 *
 * @return bool
 */
bool IsError(int value) {
   return(value != NO_ERROR);
}


/**
 * Ob der interne Fehler-Code des aktuellen Moduls gesetzt ist.
 *
 * @return bool
 */
bool IsLastError() {
   return(last_error != NO_ERROR);
}


/**
 * Setzt den internen Fehlercode des aktuellen Moduls zurück.
 *
 * @return int - der vorm Zurücksetzen gesetzte Fehlercode
 */
int ResetLastError() {
   int error = last_error;
   SetLastError(NO_ERROR);
   return(error);
}


/**
 * Check for and call handlers for incoming commands.
 *
 * @return bool - success status
 */
bool HandleCommands() {
   string commands[]; ArrayResize(commands, 0);
   if (EventListener_ChartCommand(commands))
      return(onCommand(commands));
   return(true);
}


/**
 * Ob das angegebene Ticket existiert und erreichbar ist.
 *
 * @param  int ticket - Ticket-Nr.
 *
 * @return bool
 */
bool IsTicket(int ticket) {
   if (!OrderPush("IsTicket(1)")) return(false);

   bool result = OrderSelect(ticket, SELECT_BY_TICKET);

   GetLastError();
   if (!OrderPop("IsTicket(2)")) return(false);

   return(result);
}


/**
 * Select a ticket.
 *
 * @param  int    ticket                      - ticket id
 * @param  string label                       - label for potential error message
 * @param  bool   pushTicket       [optional] - whether to push the selection onto the order selection stack (default: no)
 * @param  bool   onErrorPopTicket [optional] - whether to restore the previously selected ticket in case of errors
 *                                              (default: yes on pushTicket=TRUE, no on pushTicket=FALSE)
 * @return bool - success status
 */
bool SelectTicket(int ticket, string label, bool pushTicket=false, bool onErrorPopTicket=false) {
   pushTicket       = pushTicket!=0;
   onErrorPopTicket = onErrorPopTicket!=0;

   if (pushTicket) {
      if (!OrderPush(label)) return(false);
      onErrorPopTicket = true;
   }

   if (OrderSelect(ticket, SELECT_BY_TICKET))
      return(true);                             // success

   if (onErrorPopTicket)                        // error
      if (!OrderPop(label)) return(false);

   int error = GetLastError();
   if (!error)
      error = ERR_INVALID_TICKET;
   return(!catch(label +"->SelectTicket()   ticket="+ ticket, error));
}


/**
 * Schiebt den aktuellen Orderkontext auf den Kontextstack (fügt ihn ans Ende an).
 *
 * @param  string location - Bezeichner für eine evt. Fehlermeldung
 *
 * @return bool - success status
 */
bool OrderPush(string location) {
   int ticket = OrderTicket();

   int error = GetLastError();
   if (error && error!=ERR_NO_TICKET_SELECTED)
      return(!catch(location +"->OrderPush(1)", error));

   ArrayPushInt(stack.OrderSelect, ticket);
   return(true);
}


/**
 * Entfernt den letzten Orderkontext vom Ende des Kontextstacks und restauriert ihn.
 *
 * @param  string location - Bezeichner für eine evt. Fehlermeldung
 *
 * @return bool - success status
 */
bool OrderPop(string location) {
   int ticket = ArrayPopInt(stack.OrderSelect);

   if (ticket > 0)
      return(SelectTicket(ticket, location +"->OrderPop(1)"));

   OrderSelect(0, SELECT_BY_TICKET);

   int error = GetLastError();
   if (error && error!=ERR_NO_TICKET_SELECTED)
      return(!catch(location +"->OrderPop(2)", error));

   return(true);
}


/**
 * Wait for a ticket to appear in the terminal's open order or history pool.
 *
 * @param  int  ticket            - ticket id
 * @param  bool select [optional] - whether the ticket is selected after function return (default: no)
 *
 * @return bool - success status
 */
bool WaitForTicket(int ticket, bool select = false) {
   select = select!=0;

   if (ticket <= 0)
      return(!catch("WaitForTicket(1)  illegal parameter ticket = "+ ticket, ERR_INVALID_PARAMETER));

   if (!select) {
      if (!OrderPush("WaitForTicket(2)")) return(false);
   }

   int i, delay=100;                                                 // je 0.1 Sekunden warten

   while (!OrderSelect(ticket, SELECT_BY_TICKET)) {
      if (IsTesting())       warn("WaitForTicket(3)  #"+ ticket +" not yet accessible");
      else if (i && !(i%10)) warn("WaitForTicket(4)  #"+ ticket +" not yet accessible after "+ DoubleToStr(i*delay/1000., 1) +" s");
      Sleep(delay);
      i++;
   }

   if (!select) {
      if (!OrderPop("WaitForTicket(5)")) return(false);
   }

   return(true);
}


/**
 * Gibt den PipValue des aktuellen Symbols für die angegebene Lotsize zurück.
 *
 * @param  double lots           [optional] - Lotsize (default: 1 lot)
 * @param  bool   suppressErrors [optional] - ob Laufzeitfehler unterdrückt werden sollen (default: nein)
 *
 * @return double - PipValue oder 0, falls ein Fehler auftrat
 */
double PipValue(double lots=1.0, bool suppressErrors=false) {
   suppressErrors = suppressErrors!=0;

   static double tickSize;
   if (!tickSize) {
      if (!TickSize) {
         TickSize = MarketInfo(Symbol(), MODE_TICKSIZE);             // schlägt fehl, wenn kein Tick vorhanden ist
         int error = GetLastError();                                 // Symbol (noch) nicht subscribed (Start, Account-/Templatewechsel), kann noch "auftauchen"
         if (error != NO_ERROR) {                                    // ERR_SYMBOL_NOT_AVAILABLE: synthetisches Symbol im Offline-Chart
            if (!suppressErrors) catch("PipValue(1)", error);
            return(0);
         }
         if (!TickSize) {
            if (!suppressErrors) catch("PipValue(2)  illegal TickSize: 0", ERR_INVALID_MARKET_DATA);
            return(0);
         }
      }
      tickSize = TickSize;
   }

   static double static.tickValue;
   static bool   isResolved, isConstant, isCorrect, isCalculatable, doWarn;

   if (!isResolved) {
      if (StrEndsWith(Symbol(), AccountCurrency())) {                // TickValue ist constant and kann gecacht werden
         static.tickValue = MarketInfo(Symbol(), MODE_TICKVALUE);
         error = GetLastError();
         if (error != NO_ERROR) {
            if (!suppressErrors) catch("PipValue(3)", error);
            return(0);
         }
         if (!static.tickValue) {
            if (!suppressErrors) catch("PipValue(4)  illegal TickValue: 0", ERR_INVALID_MARKET_DATA);
            return(0);
         }
         isConstant = true;
         isCorrect = true;
      }
      else {
         isConstant = false;                                         // TickValue ist dynamisch
         isCorrect = !IsTesting();                                   // MarketInfo() gibt im Tester statt des tatsächlichen den Online-Wert zurück (nur annähernd genau).
      }
      isCalculatable = StrStartsWith(Symbol(), AccountCurrency());   // Der tatsächliche Wert kann u.U. berechnet werden. Ist das nicht möglich,
      doWarn = (!isCorrect && !isCalculatable);                      // muß nach einmaliger Warnung der Online-Wert verwendet werden.
      isResolved = true;
   }

   // constant value
   if (isConstant)
      return(Pip/tickSize * static.tickValue * lots);

   // dynamic but correct value
   if (isCorrect) {
      double tickValue = MarketInfo(Symbol(), MODE_TICKVALUE);
      error = GetLastError();
      if (error != NO_ERROR) {
         if (!suppressErrors) catch("PipValue(5)", error);
         return(0);
      }
      if (!tickValue) {
         if (!suppressErrors) catch("PipValue(6)  illegal TickValue: 0", ERR_INVALID_MARKET_DATA);
         return(0);
      }
      return(Pip/tickSize * tickValue * lots);
   }

   // dynamic and incorrect value
   if (isCalculatable) {                                             // TickValue can be calculated
      if      (Symbol() == "EURAUD") tickValue =   1/Close[0];
      else if (Symbol() == "EURCAD") tickValue =   1/Close[0];
      else if (Symbol() == "EURCHF") tickValue =   1/Close[0];
      else if (Symbol() == "EURGBP") tickValue =   1/Close[0];
      else if (Symbol() == "EURUSD") tickValue =   1/Close[0];

      else if (Symbol() == "GBPAUD") tickValue =   1/Close[0];
      else if (Symbol() == "GBPCAD") tickValue =   1/Close[0];
      else if (Symbol() == "GBPCHF") tickValue =   1/Close[0];
      else if (Symbol() == "GBPUSD") tickValue =   1/Close[0];

      else if (Symbol() == "AUDJPY") tickValue = 100/Close[0];
      else if (Symbol() == "CADJPY") tickValue = 100/Close[0];
      else if (Symbol() == "CHFJPY") tickValue = 100/Close[0];
      else if (Symbol() == "EURJPY") tickValue = 100/Close[0];
      else if (Symbol() == "GBPJPY") tickValue = 100/Close[0];
      else if (Symbol() == "USDJPY") tickValue = 100/Close[0];
      else                           return(!catch("PipValue(7)  calculation of TickValue for "+ Symbol() +" in Strategy Tester not yet implemented", ERR_NOT_IMPLEMENTED));
      return(Pip/tickSize * tickValue * lots);                       // return the calculated value
   }

   // dynamic and incorrect value: we must live with the approximated online value
   tickValue = MarketInfo(Symbol(), MODE_TICKVALUE);
   error     = GetLastError();
   if (error != NO_ERROR) {
      if (!suppressErrors) catch("PipValue(8)", error);
      return(0);
   }
   if (!tickValue) {
      if (!suppressErrors) catch("PipValue(9)  illegal TickValue: 0", ERR_INVALID_MARKET_DATA);
      return(0);
   }

   // emit a single warning at test start
   if (doWarn) {
      string message = "Exact tickvalue not available."+ NL
                      +"The test will use the current online tickvalue ("+ tickValue +") which is an approximation. "
                      +"Test with another account currency if you need exact values.";
      warn("PipValue(10)  "+ message);
      doWarn = false;
   }
   return(Pip/tickSize * tickValue * lots);
}


/**
 * Gibt den PipValue eines beliebigen Symbols für die angegebene Lotsize zurück.
 *
 * @param  string symbol         - Symbol
 * @param  double lots           - Lotsize (default: 1 lot)
 * @param  bool   suppressErrors - ob Laufzeitfehler unterdrückt werden sollen (default: nein)
 *
 * @return double - PipValue oder 0, falls ein Fehler auftrat
 */
double PipValueEx(string symbol, double lots=1.0, bool suppressErrors=false) {
   suppressErrors = suppressErrors!=0;
   if (symbol == Symbol())
      return(PipValue(lots, suppressErrors));

   double tickSize = MarketInfo(symbol, MODE_TICKSIZE);              // schlägt fehl, wenn kein Tick vorhanden ist
   int error = GetLastError();                                       // - Symbol (noch) nicht subscribed (Start, Account-/Templatewechsel), kann noch "auftauchen"
   if (error != NO_ERROR) {                                          // - ERR_SYMBOL_NOT_AVAILABLE: synthetisches Symbol im Offline-Chart
      if (!suppressErrors) catch("PipValueEx(1)", error);
      return(0);
   }
   if (!tickSize) {
      if (!suppressErrors) catch("PipValueEx(2)  illegal TickSize = 0", ERR_INVALID_MARKET_DATA);
      return(0);
   }

   double tickValue = MarketInfo(symbol, MODE_TICKVALUE);            // TODO: wenn QuoteCurrency == AccountCurrency, ist dies nur ein einziges Mal notwendig
   error = GetLastError();
   if (error != NO_ERROR) {
      if (!suppressErrors) catch("PipValueEx(3)", error);
      return(0);
   }
   if (!tickValue) {
      if (!suppressErrors) catch("PipValueEx(4)  illegal TickValue = 0", ERR_INVALID_MARKET_DATA);
      return(0);
   }

   int digits = MarketInfo(symbol, MODE_DIGITS);                     // TODO: !!! digits ist u.U. falsch gesetzt !!!
   error = GetLastError();
   if (error != NO_ERROR) {
      if (!suppressErrors) catch("PipValueEx(5)", error);
      return(0);
   }

   int    pipDigits = digits & (~1);
   double pipSize   = NormalizeDouble(1/MathPow(10, pipDigits), pipDigits);

   return(pipSize/tickSize * tickValue * lots);
}


/**
 * Calculate the current symbol's commission value for the specified lot size.
 *
 * @param  double lots [optional] - lot size (default: 1 lot)
 *
 * @return double - commission value or EMPTY (-1) in case of errors
 */
double GetCommission(double lots = 1.0) {
   static double static.rate;
   static bool   resolved;

   if (!resolved) {
      double rate;

      if (This.IsTesting()) {
         rate = Test_GetCommission(__ExecutionContext, 1);
      }
      else {
         // TODO: if (is_CFD) rate = 0;
         string company  = ShortAccountCompany(); if (!StringLen(company)) return(EMPTY);
         string currency = AccountCurrency();
         int    account  = GetAccountNumber();    if (!account)            return(EMPTY);

         string section = "Commissions";
         string key     = company +"."+ currency +"."+ account;

         if (!IsGlobalConfigKeyA(section, key)) {
            key = company +"."+ currency;
            if (!IsGlobalConfigKeyA(section, key)) return(_EMPTY(catch("GetCommission(1)  missing configuration value ["+ section +"] "+ key, ERR_INVALID_CONFIG_VALUE)));
         }
         rate = GetGlobalConfigDouble(section, key);
         if (rate < 0) return(_EMPTY(catch("GetCommission(2)  invalid configuration value ["+ section +"] "+ key +" = "+ NumberToStr(rate, ".+"), ERR_INVALID_CONFIG_VALUE)));
      }
      static.rate = rate;
      resolved    = true;
   }

   if (lots == 1)
      return(static.rate);
   return(static.rate * lots);
}


/**
 * Whether logging in general is enabled (read from the configuration). By default online logging is enabled and offline
 * logging (tester) is disabled. Called only from init.GlobalVars().
 *
 * @return bool
 */
bool init.IsLogEnabled() {
   if (This.IsTesting())
      return(GetConfigBool("Logging", "LogInTester", false));                    // tester: default=off
   return(GetConfigBool("Logging", ec_ProgramName(__ExecutionContext), true));   // online: default=on
}


/**
 * Inlined conditional Boolean statement.
 *
 * @param  bool condition
 * @param  bool thenValue
 * @param  bool elseValue
 *
 * @return bool
 */
bool ifBool(bool condition, bool thenValue, bool elseValue) {
   if (condition != 0)
      return(thenValue != 0);
   return(elseValue != 0);
}


/**
 * Inlined conditional Integer statement.
 *
 * @param  bool condition
 * @param  int  thenValue
 * @param  int  elseValue
 *
 * @return int
 */
int ifInt(bool condition, int thenValue, int elseValue) {
   if (condition != 0)
      return(thenValue);
   return(elseValue);
}


/**
 * Inlined conditional Double statement.
 *
 * @param  bool   condition
 * @param  double thenValue
 * @param  double elseValue
 *
 * @return double
 */
double ifDouble(bool condition, double thenValue, double elseValue) {
   if (condition != 0)
      return(thenValue);
   return(elseValue);
}


/**
 * Inlined conditional String statement.
 *
 * @param  bool   condition
 * @param  string thenValue
 * @param  string elseValue
 *
 * @return string
 */
string ifString(bool condition, string thenValue, string elseValue) {
   if (condition != 0)
      return(thenValue);
   return(elseValue);
}


/**
 * Correct comparison of two doubles for "Lower-Than".
 *
 * @param  double double1           - first value
 * @param  double double2           - second value
 * @param  int    digits [optional] - number of decimal digits to consider (default: 8)
 *
 * @return bool
 */
bool LT(double double1, double double2, int digits = 8) {
   if (EQ(double1, double2, digits))
      return(false);
   return(double1 < double2);
}


/**
 * Correct comparison of two doubles for "Lower-Or-Equal".
 *
 * @param  double double1           - first value
 * @param  double double2           - second value
 * @param  int    digits [optional] - number of decimal digits to consider (default: 8)
 *
 * @return bool
 */
bool LE(double double1, double double2, int digits = 8) {
   if (double1 < double2)
      return(true);
   return(EQ(double1, double2, digits));
}


/**
 * Correct comparison of two doubles for "Equal".
 *
 * @param  double double1           - first value
 * @param  double double2           - second value
 * @param  int    digits [optional] - number of decimal digits to consider (default: 8)
 *
 * @return bool
 */
bool EQ(double double1, double double2, int digits = 8) {
   if (digits < 0 || digits > 8)
      return(!catch("EQ()  illegal parameter digits = "+ digits, ERR_INVALID_PARAMETER));

   double diff = NormalizeDouble(double1, digits) - NormalizeDouble(double2, digits);
   if (diff < 0)
      diff = -diff;
   return(diff < 0.000000000000001);

   /*
   switch (digits) {
      case  0: return(diff <= 0                 );
      case  1: return(diff <= 0.1               );
      case  2: return(diff <= 0.01              );
      case  3: return(diff <= 0.001             );
      case  4: return(diff <= 0.0001            );
      case  5: return(diff <= 0.00001           );
      case  6: return(diff <= 0.000001          );
      case  7: return(diff <= 0.0000001         );
      case  8: return(diff <= 0.00000001        );
      case  9: return(diff <= 0.000000001       );
      case 10: return(diff <= 0.0000000001      );
      case 11: return(diff <= 0.00000000001     );
      case 12: return(diff <= 0.000000000001    );
      case 13: return(diff <= 0.0000000000001   );
      case 14: return(diff <= 0.00000000000001  );
      case 15: return(diff <= 0.000000000000001 );
      case 16: return(diff <= 0.0000000000000001);
   }
   return(!catch("EQ()  illegal parameter digits = "+ digits, ERR_INVALID_PARAMETER));
   */
}


/**
 * Correct comparison of two doubles for "Not-Equal".
 *
 * @param  double double1           - first value
 * @param  double double2           - second value
 * @param  int    digits [optional] - number of decimal digits to consider (default: 8)
 *
 * @return bool
 */
bool NE(double double1, double double2, int digits = 8) {
   return(!EQ(double1, double2, digits));
}


/**
 * Correct comparison of two doubles for "Greater-Or-Equal".
 *
 * @param  double double1           - first value
 * @param  double double2           - second value
 * @param  int    digits [optional] - number of decimal digits to consider (default: 8)
 *
 * @return bool
 */
bool GE(double double1, double double2, int digits = 8) {
   if (double1 > double2)
      return(true);
   return(EQ(double1, double2, digits));
}


/**
 * Correct comparison of two doubles for "Greater-Than".
 *
 * @param  double double1           - first value
 * @param  double double2           - second value
 * @param  int    digits [optional] - number of decimal digits to consider (default: 8)
 *
 * @return bool
 */
bool GT(double double1, double double2, int digits = 8) {
   if (EQ(double1, double2, digits))
      return(false);
   return(double1 > double2);
}


/**
 * Ob der Wert eines Doubles NaN (Not-a-Number) ist.
 *
 * @param  double value
 *
 * @return bool
 */
bool IsNaN(double value) {
   // Bug Builds < 509: der Ausdruck (NaN==NaN) ist dort fälschlicherweise TRUE
   string s = value;
   return(s == "-1.#IND0000");
}


/**
 * Ob der Wert eines Doubles positiv oder negativ unendlich (Infinity) ist.
 *
 * @param  double value
 *
 * @return bool
 */
bool IsInfinity(double value) {
   if (!value)                               // 0
      return(false);
   return(value+value == value);             // 1.#INF oder -1.#INF
}


/**
 * Pseudo-Funktion, die nichts weiter tut, als boolean TRUE zurückzugeben. Kann zur Verbesserung der Übersichtlichkeit
 * und Lesbarkeit verwendet werden.
 *
 * @param  beliebige Parameter (werden ignoriert)
 *
 * @return bool - TRUE
 */
bool _true(int param1=NULL, int param2=NULL, int param3=NULL, int param4=NULL, int param5=NULL, int param6=NULL, int param7=NULL, int param8=NULL) {
   return(true);
}


/**
 * Pseudo-Funktion, die nichts weiter tut, als boolean FALSE zurückzugeben. Kann zur Verbesserung der Übersichtlichkeit
 * und Lesbarkeit verwendet werden.
 *
 * @param  beliebige Parameter (werden ignoriert)
 *
 * @return bool - FALSE
 */
bool _false(int param1=NULL, int param2=NULL, int param3=NULL, int param4=NULL, int param5=NULL, int param6=NULL, int param7=NULL, int param8=NULL) {
   return(false);
}


/**
 * Pseudo-Funktion, die nichts weiter tut, als NULL = 0 (int) zurückzugeben. Kann zur Verbesserung der Übersichtlichkeit
 * und Lesbarkeit verwendet werden.
 *
 * @param  beliebige Parameter (werden ignoriert)
 *
 * @return int - NULL
 */
int _NULL(int param1=NULL, int param2=NULL, int param3=NULL, int param4=NULL, int param5=NULL, int param6=NULL, int param7=NULL, int param8=NULL) {
   return(NULL);
}


/**
 * Pseudo-Funktion, die nichts weiter tut, als den Fehlerstatus NO_ERROR zurückzugeben. Kann zur Verbesserung der
 * Übersichtlichkeit und Lesbarkeit verwendet werden. Ist funktional identisch zu _NULL().
 *
 * @param  beliebige Parameter (werden ignoriert)
 *
 * @return int - NO_ERROR
 */
int _NO_ERROR(int param1=NULL, int param2=NULL, int param3=NULL, int param4=NULL, int param5=NULL, int param6=NULL, int param7=NULL, int param8=NULL) {
   return(NO_ERROR);
}


/**
 * Pseudo-Funktion, die nichts weiter tut, als den letzten Fehlercode zurückzugeben. Kann zur Verbesserung der
 * Übersichtlichkeit und Lesbarkeit verwendet werden.
 *
 * @param  beliebige Parameter (werden ignoriert)
 *
 * @return int - last_error
 */
int _last_error(int param1=NULL, int param2=NULL, int param3=NULL, int param4=NULL, int param5=NULL, int param6=NULL, int param7=NULL, int param8=NULL) {
   return(last_error);
}


/**
 * Pseudo-Funktion, die nichts weiter tut, als die Konstante EMPTY (0xFFFFFFFF = -1) zurückzugeben.
 * Kann zur Verbesserung der Übersichtlichkeit und Lesbarkeit verwendet werden.
 *
 * @param  beliebige Parameter (werden ignoriert)
 *
 * @return int - EMPTY (-1)
 */
int _EMPTY(int param1=NULL, int param2=NULL, int param3=NULL, int param4=NULL, int param5=NULL, int param6=NULL, int param7=NULL, int param8=NULL) {
   return(EMPTY);
}


/**
 * Ob der angegebene Wert die Konstante EMPTY darstellt (-1).
 *
 * @param  double value
 *
 * @return bool
 */
bool IsEmpty(double value) {
   return(value == EMPTY);
}


/**
 * Pseudo-Funktion, die nichts weiter tut, als die Konstante EMPTY_VALUE (0x7FFFFFFF = 2147483647 = INT_MAX) zurückzugeben.
 * Kann zur Verbesserung der Übersichtlichkeit und Lesbarkeit verwendet werden.
 *
 * @param  beliebige Parameter (werden ignoriert)
 *
 * @return int - EMPTY_VALUE
 */
int _EMPTY_VALUE(int param1=NULL, int param2=NULL, int param3=NULL, int param4=NULL, int param5=NULL, int param6=NULL, int param7=NULL, int param8=NULL) {
   return(EMPTY_VALUE);
}


/**
 * Ob der angegebene Wert die Konstante EMPTY_VALUE darstellt (0x7FFFFFFF = 2147483647 = INT_MAX).
 *
 * @param  double value
 *
 * @return bool
 */
bool IsEmptyValue(double value) {
   return(value == EMPTY_VALUE);
}


/**
 * Pseudo-Funktion, die nichts weiter tut, als einen Leerstring ("") zurückzugeben. Kann zur Verbesserung der
 * Übersichtlichkeit und Lesbarkeit verwendet werden.
 *
 * @param  beliebige Parameter (werden ignoriert)
 *
 * @return string - Leerstring
 */
string _EMPTY_STR(int param1=NULL, int param2=NULL, int param3=NULL, int param4=NULL, int param5=NULL, int param6=NULL, int param7=NULL, int param8=NULL) {
   return("");
}


/**
 * Ob der angegebene Wert einen Leerstring darstellt (keinen NULL-Pointer).
 *
 * @param  string value
 *
 * @return bool
 */
bool IsEmptyString(string value) {
   if (StrIsNull(value))
      return(false);
   return(value == "");
}


/**
 * Pseudo-Funktion, die die Konstante NaT (Not-A-Time: 0x80000000 = -2147483648 = INT_MIN = D'1901-12-13 20:45:52')
 * zurückgibt. Kann zur Verbesserung der Übersichtlichkeit und Lesbarkeit verwendet werden.
 *
 * @param  beliebige Parameter (werden ignoriert)
 *
 * @return datetime - NaT (Not-A-Time)
 */
datetime _NaT(int param1=NULL, int param2=NULL, int param3=NULL, int param4=NULL, int param5=NULL, int param6=NULL, int param7=NULL, int param8=NULL) {
   return(NaT);
}


/**
 * Ob der angegebene Wert die Konstante NaT (Not-A-Time) darstellt.
 *
 * @param  datetime value
 *
 * @return bool
 */
bool IsNaT(datetime value) {
   return(value == NaT);
}


/**
 * Pseudo-Funktion, die nichts weiter tut, als den ersten Parameter zurückzugeben. Kann zur Verbesserung der
 * Übersichtlichkeit und Lesbarkeit verwendet werden.
 *
 * @param  bool param1 - Boolean
 * @param  ...         - beliebige weitere Parameter (werden ignoriert)
 *
 * @return bool - der erste Parameter
 */
bool _bool(bool param1, int param2=NULL, int param3=NULL, int param4=NULL, int param5=NULL, int param6=NULL, int param7=NULL, int param8=NULL) {
   return(param1 != 0);
}


/**
 * Pseudo-Funktion, die nichts weiter tut, als den ersten Parameter zurückzugeben. Kann zur Verbesserung der
 * Übersichtlichkeit und Lesbarkeit verwendet werden.
 *
 * @param  int param1 - Integer
 * @param  ...        - beliebige weitere Parameter (werden ignoriert)
 *
 * @return int - der erste Parameter
 */
int _int(int param1, int param2=NULL, int param3=NULL, int param4=NULL, int param5=NULL, int param6=NULL, int param7=NULL, int param8=NULL) {
   return(param1);
}


/**
 * Pseudo-Funktion, die nichts weiter tut, als den ersten Parameter zurückzugeben. Kann zur Verbesserung der
 * Übersichtlichkeit und Lesbarkeit verwendet werden.
 *
 * @param  double param1 - Double
 * @param  ...           - beliebige weitere Parameter (werden ignoriert)
 *
 * @return double - der erste Parameter
 */
double _double(double param1, int param2=NULL, int param3=NULL, int param4=NULL, int param5=NULL, int param6=NULL, int param7=NULL, int param8=NULL) {
   return(param1);
}


/**
 * Pseudo-Funktion, die nichts weiter tut, als den ersten Parameter zurückzugeben. Kann zur Verbesserung der
 * Übersichtlichkeit und Lesbarkeit verwendet werden.
 *
 * @param  string param1 - String
 * @param  ...           - beliebige weitere Parameter (werden ignoriert)
 *
 * @return string - der erste Parameter
 */
string _string(string param1, int param2=NULL, int param3=NULL, int param4=NULL, int param5=NULL, int param6=NULL, int param7=NULL, int param8=NULL) {
   return(param1);
}


/**
 * Whether the current program runs on a visible chart. Can be FALSE only during testing if "VisualMode=Off" or
 * "Optimization=On".
 *
 * @return bool
 */
bool __CHART() {
   return(__ExecutionContext[EC.hChart] != 0);
}


/**
 * Whether logging is enabled for the current program.
 *
 * @return bool
 */
bool __LOG() {
   return(__ExecutionContext[EC.logEnabled] != 0);
}


/**
 * Return the current program's full name. For MQL main modules this value matches the return value of WindowExpertName().
 * For libraries this value includes the name of the main module, e.g. "{expert-name}::{library-name}".
 *
 * @return string
 */
string __NAME() {
   static string name = ""; if (!StringLen(name)) {
      string program = ec_ProgramName(__ExecutionContext);
      string module  = ec_ModuleName (__ExecutionContext);

      if (StringLen(program) && StringLen(module)) {
         name = program;
         if (IsLibrary()) name = StringConcatenate(name, "::", module);
      }
      else if (IsLibrary()) {
         if (!StringLen(program)) program = "???";
         if (!StringLen(module))  module = WindowExpertName();
         return(StringConcatenate(program, "::", module));
      }
      else {
         return(WindowExpertName());
      }
   }
   return(name);
}


/**
 * Integer-Version von MathMin()
 *
 * Ermittelt die kleinere mehrerer Ganzzahlen.
 *
 * @param  int value1
 * @param  int value2
 * @param      ...    - Insgesamt bis zu 8 Werte mit INT_MAX als Argumentbegrenzer. Kann einer der Werte selbst INT_MAX sein,
 *                      muß er innerhalb der ersten drei Argumente aufgeführt sein.
 * @return int
 */
int Min(int value1, int value2, int value3=INT_MAX, int value4=INT_MAX, int value5=INT_MAX, int value6=INT_MAX, int value7=INT_MAX, int value8=INT_MAX) {
   int result = value1;
   while (true) {
      if (value2 < result) result = value2;
      if (value3 < result) result = value3; if (value3 == INT_MAX) break;
      if (value4 < result) result = value4; if (value4 == INT_MAX) break;
      if (value5 < result) result = value5; if (value5 == INT_MAX) break;
      if (value6 < result) result = value6; if (value6 == INT_MAX) break;
      if (value7 < result) result = value7; if (value7 == INT_MAX) break;
      if (value8 < result) result = value8;
      break;
   }
   return(result);
}


/**
 * Integer-Version von MathMax()
 *
 * Ermittelt die größere mehrerer Ganzzahlen.
 *
 * @param  int value1
 * @param  int value2
 * @param      ...    - Insgesamt bis zu 8 Werte mit INT_MIN als Argumentbegrenzer. Kann einer der Werte selbst INT_MIN sein,
 *                      muß er innerhalb der ersten drei Argumente aufgeführt sein.
 * @return int
 */
int Max(int value1, int value2, int value3=INT_MIN, int value4=INT_MIN, int value5=INT_MIN, int value6=INT_MIN, int value7=INT_MIN, int value8=INT_MIN) {
   int result = value1;
   while (true) {
      if (value2 > result) result = value2;
      if (value3 > result) result = value3; if (value3 == INT_MIN) break;
      if (value4 > result) result = value4; if (value4 == INT_MIN) break;
      if (value5 > result) result = value5; if (value5 == INT_MIN) break;
      if (value6 > result) result = value6; if (value6 == INT_MIN) break;
      if (value7 > result) result = value7; if (value7 == INT_MIN) break;
      if (value8 > result) result = value8;
      break;
   }
   return(result);
}


/**
 * Integer-Version von MathAbs()
 *
 * Ermittelt den Absolutwert einer Ganzzahl.
 *
 * @param  int  value
 *
 * @return int
 */
int Abs(int value) {
   if (value < 0)
      return(-value);
   return(value);
}


/**
 * Gibt das Vorzeichen einer Zahl zurück.
 *
 * @param  double number - Zahl
 *
 * @return int - Vorzeichen (+1, 0, -1)
 */
int Sign(double number) {
   if (GT(number, 0)) return( 1);
   if (LT(number, 0)) return(-1);
   return(0);
}


/**
 * Integer version of MathRound()
 *
 * @param  double value
 *
 * @return int
 */
int Round(double value) {
   return(MathRound(value));
}


/**
 * Integer version of MathFloor()
 *
 * @param  double value
 *
 * @return int
 */
int Floor(double value) {
   return(MathFloor(value));
}


/**
 * Integer version of MathCeil()
 *
 * @param  double value
 *
 * @return int
 */
int Ceil(double value) {
   return(MathCeil(value));
}


/**
 * Extended version of MathRound(). Rounds to the specified amount of digits before or after the decimal separator.
 *
 * Examples:
 *  RoundEx(1234.5678,  3) => 1234.568
 *  RoundEx(1234.5678,  2) => 1234.57
 *  RoundEx(1234.5678,  1) => 1234.6
 *  RoundEx(1234.5678,  0) => 1235
 *  RoundEx(1234.5678, -1) => 1230
 *  RoundEx(1234.5678, -2) => 1200
 *  RoundEx(1234.5678, -3) => 1000
 *
 * @param  double number
 * @param  int    decimals [optional] - (default: 0)
 *
 * @return double - rounded value
 */
double RoundEx(double number, int decimals = 0) {
   if (decimals > 0) return(NormalizeDouble(number, decimals));
   if (!decimals)    return(      MathRound(number));

   // decimals < 0
   double factor = MathPow(10, decimals);
          number = MathRound(number * factor) / factor;
          number = MathRound(number);
   return(number);
}


/**
 * Extended version of MathFloor(). Rounds to the specified amount of digits before or after the decimal separator down.
 * That's the direction to zero.
 *
 * Examples:
 *  RoundFloor(1234.5678,  3) => 1234.567
 *  RoundFloor(1234.5678,  2) => 1234.56
 *  RoundFloor(1234.5678,  1) => 1234.5
 *  RoundFloor(1234.5678,  0) => 1234
 *  RoundFloor(1234.5678, -1) => 1230
 *  RoundFloor(1234.5678, -2) => 1200
 *  RoundFloor(1234.5678, -3) => 1000
 *
 * @param  double number
 * @param  int    decimals [optional] - (default: 0)
 *
 * @return double - rounded value
 */
double RoundFloor(double number, int decimals = 0) {
   if (decimals > 0) {
      double factor = MathPow(10, decimals);
             number = MathFloor(number * factor) / factor;
             number = NormalizeDouble(number, decimals);
      return(number);
   }

   if (decimals == 0)
      return(MathFloor(number));

   // decimals < 0
   factor = MathPow(10, decimals);
   number = MathFloor(number * factor) / factor;
   number = MathRound(number);
   return(number);
}


/**
 * Extended version of MathCeil(). Rounds to the specified amount of digits before or after the decimal separator up.
 * That's the direction from zero away.
 *
 * Examples:
 *  RoundCeil(1234.5678,  3) => 1234.568
 *  RoundCeil(1234.5678,  2) => 1234.57
 *  RoundCeil(1234.5678,  1) => 1234.6
 *  RoundCeil(1234.5678,  0) => 1235
 *  RoundCeil(1234.5678, -1) => 1240
 *  RoundCeil(1234.5678, -2) => 1300
 *  RoundCeil(1234.5678, -3) => 2000
 *
 * @param  double number
 * @param  int    decimals [optional] - (default: 0)
 *
 * @return double - rounded value
 */
double RoundCeil(double number, int decimals = 0) {
   if (decimals > 0) {
      double factor = MathPow(10, decimals);
             number = MathCeil(number * factor) / factor;
             number = NormalizeDouble(number, decimals);
      return(number);
   }

   if (decimals == 0)
      return(MathCeil(number));

   // decimals < 0
   factor = MathPow(10, decimals);
   number = MathCeil(number * factor) / factor;
   number = MathRound(number);
   return(number);
}


/**
 * Dividiert zwei Doubles und fängt dabei eine Division durch 0 ab.
 *
 * @param  double a                 - Divident
 * @param  double b                 - Divisor
 * @param  double onZero [optional] - Ergebnis für den Fall, daß der Divisor 0 ist (default: 0)
 *
 * @return double
 */
double MathDiv(double a, double b, double onZero = 0) {
   if (!b)
      return(onZero);
   return(a/b);
}


/**
 * Gibt den Divisionsrest zweier Doubles zurück (fehlerbereinigter Ersatz für MathMod()).
 *
 * @param  double a
 * @param  double b
 *
 * @return double - Divisionsrest
 */
double MathModFix(double a, double b) {
   double remainder = MathMod(a, b);
   if      (EQ(remainder, 0)) remainder = 0;                         // 0 normalisieren
   else if (EQ(remainder, b)) remainder = 0;
   return(remainder);
}


/**
 * Integer-Version von MathDiv(). Dividiert zwei Integers und fängt dabei eine Division durch 0 ab.
 *
 * @param  int a      - Divident
 * @param  int b      - Divisor
 * @param  int onZero - Ergebnis für den Fall, daß der Divisor 0 ist (default: 0)
 *
 * @return int
 */
int Div(int a, int b, int onZero=0) {
   if (!b)
      return(onZero);
   return(a/b);
}


/**
 * Gibt die Anzahl der Dezimal- bzw. Nachkommastellen eines Zahlenwertes zurück.
 *
 * @param  double number
 *
 * @return int - Anzahl der Nachkommastellen, höchstens jedoch 8
 */
int CountDecimals(double number) {
   string str = number;
   int dot    = StringFind(str, ".");

   for (int i=StringLen(str)-1; i > dot; i--) {
      if (StringGetChar(str, i) != '0')
         break;
   }
   return(i - dot);
}


/**
 * Gibt einen linken Teilstring eines Strings zurück.
 *
 * Ist N positiv, gibt StrLeft() die N am meisten links stehenden Zeichen des Strings zurück.
 *    z.B.  StrLeft("ABCDEFG",  2)  =>  "AB"
 *
 * Ist N negativ, gibt StrLeft() alle außer den N am meisten rechts stehenden Zeichen des Strings zurück.
 *    z.B.  StrLeft("ABCDEFG", -2)  =>  "ABCDE"
 *
 * @param  string value
 * @param  int    n
 *
 * @return string
 */
string StrLeft(string value, int n) {
   if (n > 0) return(StrSubstr(value, 0, n                 ));
   if (n < 0) return(StrSubstr(value, 0, StringLen(value)+n));
   return("");
}


/**
 * Gibt den linken Teil eines Strings bis zum Auftreten eines Teilstrings zurück. Das Ergebnis enthält den begrenzenden
 * Teilstring nicht.
 *
 * @param  string value     - Ausgangsstring
 * @param  string substring - der das Ergebnis begrenzende Teilstring
 * @param  int    count     - Anzahl der Teilstrings, deren Auftreten das Ergebnis begrenzt (default: das erste Auftreten)
 *                            Wenn größer als die Anzahl der im String existierenden Teilstrings, wird der gesamte String
 *                            zurückgegeben.
 *                            Wenn 0, wird ein Leerstring zurückgegeben.
 *                            Wenn negativ, wird mit dem Zählen statt von links von rechts begonnen.
 * @return string
 */
string StrLeftTo(string value, string substring, int count = 1) {
   int start=0, pos=-1;

   // positive Anzahl: von vorn zählen
   if (count > 0) {
      while (count > 0) {
         pos = StringFind(value, substring, pos+1);
         if (pos == -1)
            return(value);
         count--;
      }
      return(StrLeft(value, pos));
   }

   // negative Anzahl: von hinten zählen
   if (count < 0) {
      /*
      while(count < 0) {
         pos = StringFind(value, substring, 0);
         if (pos == -1)
            return("");
         count++;
      }
      */
      pos = StringFind(value, substring, 0);
      if (pos == -1)
         return(value);

      if (count == -1) {
         while (pos != -1) {
            start = pos+1;
            pos   = StringFind(value, substring, start);
         }
         return(StrLeft(value, start-1));
      }
      return(_EMPTY_STR(catch("StrLeftTo(1)->StringFindEx()", ERR_NOT_IMPLEMENTED)));

      //pos = StringFindEx(value, substring, count);
      //return(StrLeft(value, pos));
   }

   // Anzahl == 0
   return("");
}


/**
 * Gibt einen rechten Teilstring eines Strings zurück.
 *
 * Ist N positiv, gibt StrRight() die N am meisten rechts stehenden Zeichen des Strings zurück.
 *    z.B.  StrRight("ABCDEFG",  2)  =>  "FG"
 *
 * Ist N negativ, gibt StrRight() alle außer den N am meisten links stehenden Zeichen des Strings zurück.
 *    z.B.  StrRight("ABCDEFG", -2)  =>  "CDEFG"
 *
 * @param  string value
 * @param  int    n
 *
 * @return string
 */
string StrRight(string value, int n) {
   if (n > 0) return(StringSubstr(value, StringLen(value)-n));
   if (n < 0) return(StringSubstr(value, -n                ));
   return("");
}


/**
 * Gibt den rechten Teil eines Strings ab dem Auftreten eines Teilstrings zurück. Das Ergebnis enthält den begrenzenden
 * Teilstring nicht.
 *
 * @param  string value            - Ausgangsstring
 * @param  string substring        - der das Ergebnis begrenzende Teilstring
 * @param  int    count [optional] - Anzahl der Teilstrings, deren Auftreten das Ergebnis begrenzt (default: das erste Auftreten)
 *                                   Wenn 0 oder größer als die Anzahl der im String existierenden Teilstrings, wird ein Leerstring
 *                                   zurückgegeben.
 *                                   Wenn negativ, wird mit dem Zählen statt von links von rechts begonnen.
 *                                   Wenn negativ und absolut größer als die Anzahl der im String existierenden Teilstrings,
 *                                   wird der gesamte String zurückgegeben.
 * @return string
 */
string StrRightFrom(string value, string substring, int count = 1) {
   int start=0, pos=-1;

   // positive Anzahl: von vorn zählen
   if (count > 0) {
      while (count > 0) {
         pos = StringFind(value, substring, pos+1);
         if (pos == -1)
            return("");
         count--;
      }
      return(StrSubstr(value, pos+StringLen(substring)));
   }

   // negative Anzahl: von hinten zählen
   if (count < 0) {
      /*
      while(count < 0) {
         pos = StringFind(value, substring, 0);
         if (pos == -1)
            return("");
         count++;
      }
      */
      pos = StringFind(value, substring, 0);
      if (pos == -1)
         return(value);

      if (count == -1) {
         while (pos != -1) {
            start = pos+1;
            pos   = StringFind(value, substring, start);
         }
         return(StrSubstr(value, start-1 + StringLen(substring)));
      }

      return(_EMPTY_STR(catch("StringRightTo(1)->StringFindEx()", ERR_NOT_IMPLEMENTED)));
      //pos = StringFindEx(value, substring, count);
      //return(StrSubstr(value, pos + StringLen(substring)));
   }

   // Anzahl == 0
   return("");
}


/**
 * Ob ein String mit dem angegebenen Teilstring beginnt. Groß-/Kleinschreibung wird nicht beachtet.
 *
 * @param  string value  - zu prüfender String
 * @param  string prefix - Substring
 *
 * @return bool
 */
bool StrStartsWithI(string value, string prefix) {
   int error = GetLastError();
   if (error != NO_ERROR) {
      if (error == ERR_NOT_INITIALIZED_STRING) {
         if (StrIsNull(value))  return(false);
         if (StrIsNull(prefix)) return(!catch("StrStartsWithI(1)  invalid parameter prefix: (NULL)", error));
      }
      catch("StrStartsWithI(2)", error);
   }
   if (!StringLen(prefix))      return(!catch("StrStartsWithI(3)  illegal parameter prefix = \"\"", ERR_INVALID_PARAMETER));

   return(StringFind(StrToUpper(value), StrToUpper(prefix)) == 0);
}


/**
 * Ob ein String mit dem angegebenen Teilstring endet. Groß-/Kleinschreibung wird nicht beachtet.
 *
 * @param  string value  - zu prüfender String
 * @param  string suffix - Substring
 *
 * @return bool
 */
bool StrEndsWithI(string value, string suffix) {
   int error = GetLastError();
   if (error != NO_ERROR) {
      if (error == ERR_NOT_INITIALIZED_STRING) {
         if (StrIsNull(value))  return(false);
         if (StrIsNull(suffix)) return(!catch("StrEndsWithI(1)  invalid parameter suffix: (NULL)", error));
      }
      catch("StrEndsWithI(2)", error);
   }

   int lenValue = StringLen(value);
   int lenSuffix = StringLen(suffix);

   if (lenSuffix == 0)          return(!catch("StrEndsWithI(3)  illegal parameter suffix: \"\"", ERR_INVALID_PARAMETER));

   if (lenValue < lenSuffix)
      return(false);

   value = StrToUpper(value);
   suffix = StrToUpper(suffix);

   if (lenValue == lenSuffix)
      return(value == suffix);

   int start = lenValue-lenSuffix;
   return(StringFind(value, suffix, start) == start);
}


/**
 * Prüft, ob ein String nur Ziffern enthält.
 *
 * @param  string value - zu prüfender String
 *
 * @return bool
 */
bool StrIsDigit(string value) {
   int error = GetLastError();
   if (error != NO_ERROR) {
      if (error == ERR_NOT_INITIALIZED_STRING) {
         if (StrIsNull(value)) return(false);
      }
      catch("StrIsDigit(1)", error);
   }

   int chr, len=StringLen(value);

   if (len == 0)
      return(false);

   for (int i=0; i < len; i++) {
      chr = StringGetChar(value, i);
      if (chr < '0') return(false);
      if (chr > '9') return(false);
   }
   return(true);
}


/**
 * Prüft, ob ein String einen gültigen Integer darstellt.
 *
 * @param  string value - zu prüfender String
 *
 * @return bool
 */
bool StrIsInteger(string value) {
   int error = GetLastError();
   if (error != NO_ERROR) {
      if (error == ERR_NOT_INITIALIZED_STRING) {
         if (StrIsNull(value)) return(false);
      }
      catch("StrIsInteger(1)", error);
   }
   return(value == StringConcatenate("", StrToInteger(value)));
}


/**
 * Whether a string represents a valid numeric value (integer or float, characters "0123456789.+-").
 *
 * @param  string value - the string to check
 *
 * @return bool
 */
bool StrIsNumeric(string value) {
   int error = GetLastError();
   if (error != NO_ERROR) {
      if (error == ERR_NOT_INITIALIZED_STRING)
         if (StrIsNull(value)) return(false);
      catch("StrIsNumeric(1)", error);
   }

   int len = StringLen(value);
   if (!len)
      return(false);

   bool period = false;

   for (int i=0; i < len; i++) {
      int chr = StringGetChar(value, i);

      if (i == 0) {
         if (chr == '+') continue;
         if (chr == '-') continue;
      }
      if (chr == '.') {
         if (period) return(false);
         period = true;
         continue;
      }
      if (chr < '0') return(false);
      if (chr > '9') return(false);
   }
   return(true);
}


/**
 * Ob ein String eine gültige E-Mailadresse darstellt.
 *
 * @param  string value - zu prüfender String
 *
 * @return bool
 */
bool StrIsEmailAddress(string value) {
   int error = GetLastError();
   if (error != NO_ERROR) {
      if (error == ERR_NOT_INITIALIZED_STRING) {
         if (StrIsNull(value)) return(false);
      }
      catch("StrIsEmailAddress(1)", error);
   }

   string s = StrTrim(value);

   // Validierung noch nicht implementiert
   return(StringLen(s) > 0);
}


/**
 * Ob ein String eine gültige Telefonnummer darstellt.
 *
 * @param  string value - zu prüfender String
 *
 * @return bool
 */
bool StrIsPhoneNumber(string value) {
   int error = GetLastError();
   if (error != NO_ERROR) {
      if (error == ERR_NOT_INITIALIZED_STRING) {
         if (StrIsNull(value)) return(false);
      }
      catch("StrIsPhoneNumber(1)", error);
   }

   string s = StrReplace(StrTrim(value), " ", "");
   int char, length=StringLen(s);

   // Enthält die Nummer Bindestriche "-", müssen davor und danach Ziffern stehen.
   int pos = StringFind(s, "-");
   while (pos != -1) {
      if (pos   == 0     ) return(false);
      if (pos+1 == length) return(false);

      char = StringGetChar(s, pos-1);           // left char
      if (char < '0') return(false);
      if (char > '9') return(false);

      char = StringGetChar(s, pos+1);           // right char
      if (char < '0') return(false);
      if (char > '9') return(false);

      pos = StringFind(s, "-", pos+1);
   }
   if (char != 0) s = StrReplace(s, "-", "");

   // Beginnt eine internationale Nummer mit "+", darf danach keine 0 folgen.
   if (StrStartsWith(s, "+" )) {
      s = StrSubstr(s, 1);
      if (StrStartsWith(s, "0")) return(false);
   }

   return(StrIsDigit(s));
}


/**
 * Fügt ein Element am Beginn eines String-Arrays an.
 *
 * @param  string array[] - String-Array
 * @param  string value   - hinzuzufügendes Element
 *
 * @return int - neue Größe des Arrays oder -1 (EMPTY), falls ein Fehler auftrat
 *
 *
 * NOTE: Muß global definiert sein. Die intern benutzte Funktion ReverseStringArray() ruft ihrerseits ArraySetAsSeries() auf,
 *       dessen Verhalten mit einem String-Parameter fehlerhaft (offiziell: nicht unterstützt) ist. Unter ungeklärten
 *       Umständen wird das übergebene Array zerschossen, es enthält dann Zeiger auf andere im Programm existierende Strings.
 *       Dieser Fehler trat in Indikatoren auf, wenn ArrayUnshiftString() in einer MQL-Library definiert war und über Modul-
 *       grenzen aufgerufen wurde, nicht jedoch bei globaler Definition. Außerdem trat der Fehler nicht sofort, sondern erst
 *       nach Aufruf anderer Array-Funktionen auf, die mit völlig unbeteiligten Arrays/String arbeiteten.
 */
int ArrayUnshiftString(string array[], string value) {
   if (ArrayDimension(array) > 1) return(_EMPTY(catch("ArrayUnshiftString()  too many dimensions of parameter array = "+ ArrayDimension(array), ERR_INCOMPATIBLE_ARRAYS)));

   ReverseStringArray(array);
   int size = ArrayPushString(array, value);
   ReverseStringArray(array);
   return(size);
}


/**
 * Gibt die numerische Konstante einer MovingAverage-Methode zurück.
 *
 * @param  string value     - MA-Methode
 * @param  int    execFlags - Ausführungssteuerung: Flags der Fehler, die still gesetzt werden sollen (default: keine)
 *
 * @return int - MA-Konstante oder -1 (EMPTY), falls ein Fehler auftrat
 */
int StrToMaMethod(string value, int execFlags=NULL) {
   string str = StrToUpper(StrTrim(value));

   if (StrStartsWith(str, "MODE_"))
      str = StrSubstr(str, 5);

   if (str ==         "SMA" ) return(MODE_SMA );
   if (str == ""+ MODE_SMA  ) return(MODE_SMA );
   if (str ==         "LWMA") return(MODE_LWMA);
   if (str == ""+ MODE_LWMA ) return(MODE_LWMA);
   if (str ==         "EMA" ) return(MODE_EMA );
   if (str == ""+ MODE_EMA  ) return(MODE_EMA );
   if (str ==         "ALMA") return(MODE_ALMA);
   if (str == ""+ MODE_ALMA ) return(MODE_ALMA);

   if (!execFlags & F_ERR_INVALID_PARAMETER)
      return(_EMPTY(catch("StrToMaMethod(1)  invalid parameter value = "+ DoubleQuoteStr(value), ERR_INVALID_PARAMETER)));
   return(_EMPTY(SetLastError(ERR_INVALID_PARAMETER)));
}


/**
 * Alias
 */
int StrToMovingAverageMethod(string value, int execFlags=NULL) {
   return(StrToMaMethod(value, execFlags));
}


/**
 * Faßt einen String in einfache Anführungszeichen ein. Für einen nicht initialisierten String (NULL-Pointer)
 * wird der String "NULL" (ohne Anführungszeichen) zurückgegeben.
 *
 * @param  string value
 *
 * @return string - resultierender String
 */
string QuoteStr(string value) {
   if (StrIsNull(value)) {
      int error = GetLastError();
      if (error && error!=ERR_NOT_INITIALIZED_STRING)
         catch("QuoteStr(1)", error);
      return("NULL");
   }
   return(StringConcatenate("'", value, "'"));
}


/**
 * Tests whether a given year is a leap year.
 *
 * @param  int year
 *
 * @return bool
 */
bool IsLeapYear(int year) {
   if (year%  4 != 0) return(false);                                 // if      (year is not divisible by   4) then not leap year
   if (year%100 != 0) return(true);                                  // else if (year is not divisible by 100) then     leap year
   if (year%400 == 0) return(true);                                  // else if (year is     divisible by 400) then     leap year
   return(false);                                                    // else                                        not leap year
}


/**
 * Erzeugt einen datetime-Wert. Parameter, die außerhalb der gebräuchlichen Zeitgrenzen liegen, werden automatisch in die
 * entsprechende Periode übertragen. Der resultierende Zeitpunkt kann im Bereich von D'1901.12.13 20:45:52' (INT_MIN) bis
 * D'2038.01.19 03:14:07' (INT_MAX) liegen.
 *
 * Beispiel: DateTime(2012, 2, 32, 25, -2) => D'2012.03.04 00:58:00' (2012 war ein Schaltjahr)
 *
 * @param  int year    -
 * @param  int month   - default: Januar
 * @param  int day     - default: der 1. des Monats
 * @param  int hours   - default: 0 Stunden
 * @param  int minutes - default: 0 Minuten
 * @param  int seconds - default: 0 Sekunden
 *
 * @return datetime - datetime-Wert oder NaT (Not-a-Time), falls ein Fehler auftrat
 *
 * Note: Die internen MQL-Funktionen unterstützen nur datetime-Werte im Bereich von D'1970.01.01 00:00:00' bis
 *       D'2037.12.31 23:59:59'. Diese Funktion unterstützt eine größere datetime-Range.
 */
datetime DateTime(int year, int month=1, int day=1, int hours=0, int minutes=0, int seconds=0) {
   year += (Ceil(month/12.) - 1);
   month = (12 + month%12) % 12;
   if (!month)
      month = 12;

   string  sDate = StringConcatenate(StrRight("000"+year, 4), ".", StrRight("0"+month, 2), ".01");
   datetime date = StrToTime(sDate);
   if (date < 0) return(_NaT(catch("DateTime(1)  year="+ year +", month="+ month +", day="+ day +", hours="+ hours +", minutes="+ minutes +", seconds="+ seconds, ERR_INVALID_PARAMETER)));

   int time = (day-1)*DAYS + hours*HOURS + minutes*MINUTES + seconds*SECONDS;
   return(date + time);
}


/**
 * Fix für fehlerhafte interne Funktion TimeDay()
 *
 *
 * Gibt den Tag des Monats eines Zeitpunkts zurück (1-31).
 *
 * @param  datetime time
 *
 * @return int
 */
int TimeDayFix(datetime time) {
   if (!time)
      return(1);
   return(TimeDay(time));           // Fehler: 0 statt 1 für D'1970.01.01 00:00:00'
}


/**
 * Fix für fehlerhafte interne Funktion TimeDayOfWeek()
 *
 *
 * Gibt den Wochentag eines Zeitpunkts zurück (0=Sunday ... 6=Saturday).
 *
 * @param  datetime time
 *
 * @return int
 */
int TimeDayOfWeekFix(datetime time) {
   if (!time)
      return(3);
   return(TimeDayOfWeek(time));     // Fehler: 0 (Sunday) statt 3 (Thursday) für D'1970.01.01 00:00:00'
}


/**
 * Fix für fehlerhafte interne Funktion TimeYear()
 *
 *
 * Gibt das Jahr eines Zeitpunkts zurück (1970-2037).
 *
 * @param  datetime time
 *
 * @return int
 */
int TimeYearFix(datetime time) {
   if (!time)
      return(1970);
   return(TimeYear(time));          // Fehler: 1900 statt 1970 für D'1970.01.01 00:00:00'
}


/**
 * Kopiert einen Speicherbereich. Als MoveMemory() implementiert, die betroffenen Speicherblöcke können sich also überlappen.
 *
 * @param  int destination - Zieladresse
 * @param  int source      - Quelladdrese
 * @param  int bytes       - Anzahl zu kopierender Bytes
 *
 * @return int - Fehlerstatus
 */
void CopyMemory(int destination, int source, int bytes) {
   if (destination>=0 && destination<MIN_VALID_POINTER) return(catch("CopyMemory(1)  invalid parameter destination = 0x"+ IntToHexStr(destination) +" (not a valid pointer)", ERR_INVALID_POINTER));
   if (source     >=0 && source    < MIN_VALID_POINTER) return(catch("CopyMemory(2)  invalid parameter source = 0x"+ IntToHexStr(source) +" (not a valid pointer)", ERR_INVALID_POINTER));

   RtlMoveMemory(destination, source, bytes);
   return(NO_ERROR);
}


/**
 * Addiert die Werte eines Integer-Arrays.
 *
 * @param  int values[] - Array mit Ausgangswerten
 *
 * @return int - Summe der Werte oder 0, falls ein Fehler auftrat
 */
int SumInts(int values[]) {
   if (ArrayDimension(values) > 1) return(_NULL(catch("SumInts(1)  too many dimensions of parameter values = "+ ArrayDimension(values), ERR_INCOMPATIBLE_ARRAYS)));

   int sum, size=ArraySize(values);

   for (int i=0; i < size; i++) {
      sum += values[i];
   }
   return(sum);
}

/**
 * Gibt alle verfügbaren MarketInfo()-Daten des aktuellen Instruments aus.
 *
 * @param  string location - Aufruf-Bezeichner
 *
 * @return int - Fehlerstatus
 *
 *
 * NOTE: Erläuterungen zu den MODEs in include/stddefines.mqh
 */
int DebugMarketInfo(string location) {
   string symbol = Symbol();
   double value;
   int    error;

   debug(location +"   "+ StrRepeat("-", 23 + StringLen(symbol)));         //  -------------------------
   debug(location +"   Global variables for \""+ symbol +"\"");            //  Global variables "EURUSD"
   debug(location +"   "+ StrRepeat("-", 23 + StringLen(symbol)));         //  -------------------------

   debug(location +"   1 Pip       = "+ NumberToStr(Pip, PriceFormat));
   debug(location +"   PipDigits   = "+ PipDigits);
   debug(location +"   Digits  (b) = "+ Digits);
   debug(location +"   1 Point (b) = "+ NumberToStr(Point, PriceFormat));
   debug(location +"   PipPoints   = "+ PipPoints);
   debug(location +"   Bid/Ask (b) = "+ NumberToStr(Bid, PriceFormat) +"/"+ NumberToStr(Ask, PriceFormat));
   debug(location +"   Bars    (b) = "+ Bars);
   debug(location +"   PriceFormat = \""+ PriceFormat +"\"");

   debug(location +"   "+ StrRepeat("-", 19 + StringLen(symbol)));         //  -------------------------
   debug(location +"   MarketInfo() for \""+ symbol +"\"");                //  MarketInfo() for "EURUSD"
   debug(location +"   "+ StrRepeat("-", 19 + StringLen(symbol)));         //  -------------------------

   // Erläuterungen zu den Werten in include/stddefines.mqh
   value = MarketInfo(symbol, MODE_LOW              ); error = GetLastError();                 debug(location +"   MODE_LOW               = "+                    NumberToStr(value, ifString(error, ".+", PriceFormat))          , error);
   value = MarketInfo(symbol, MODE_HIGH             ); error = GetLastError();                 debug(location +"   MODE_HIGH              = "+                    NumberToStr(value, ifString(error, ".+", PriceFormat))          , error);
   value = MarketInfo(symbol, 3                     ); error = GetLastError(); if (value != 0) debug(location +"   3                      = "+                    NumberToStr(value, ".+")                                        , error);
   value = MarketInfo(symbol, 4                     ); error = GetLastError(); if (value != 0) debug(location +"   4                      = "+                    NumberToStr(value, ".+")                                        , error);
   value = MarketInfo(symbol, MODE_TIME             ); error = GetLastError();                 debug(location +"   MODE_TIME              = "+ ifString(value<=0, NumberToStr(value, ".+"), "'"+ TimeToStr(value, TIME_FULL) +"'"), error);
   value = MarketInfo(symbol, 6                     ); error = GetLastError(); if (value != 0) debug(location +"   6                      = "+                    NumberToStr(value, ".+")                                        , error);
   value = MarketInfo(symbol, 7                     ); error = GetLastError(); if (value != 0) debug(location +"   7                      = "+                    NumberToStr(value, ".+")                                        , error);
   value = MarketInfo(symbol, 8                     ); error = GetLastError(); if (value != 0) debug(location +"   8                      = "+                    NumberToStr(value, ".+")                                        , error);
   value = MarketInfo(symbol, MODE_BID              ); error = GetLastError();                 debug(location +"   MODE_BID               = "+                    NumberToStr(value, ifString(error, ".+", PriceFormat))          , error);
   value = MarketInfo(symbol, MODE_ASK              ); error = GetLastError();                 debug(location +"   MODE_ASK               = "+                    NumberToStr(value, ifString(error, ".+", PriceFormat))          , error);
   value = MarketInfo(symbol, MODE_POINT            ); error = GetLastError();                 debug(location +"   MODE_POINT             = "+                    NumberToStr(value, ifString(error, ".+", PriceFormat))          , error);
   value = MarketInfo(symbol, MODE_DIGITS           ); error = GetLastError();                 debug(location +"   MODE_DIGITS            = "+                    NumberToStr(value, ".+")                                        , error);
   value = MarketInfo(symbol, MODE_SPREAD           ); error = GetLastError();                 debug(location +"   MODE_SPREAD            = "+                    NumberToStr(value, ".+")                                        , error);
   value = MarketInfo(symbol, MODE_STOPLEVEL        ); error = GetLastError();                 debug(location +"   MODE_STOPLEVEL         = "+                    NumberToStr(value, ".+")                                        , error);
   value = MarketInfo(symbol, MODE_LOTSIZE          ); error = GetLastError();                 debug(location +"   MODE_LOTSIZE           = "+                    NumberToStr(value, ".+")                                        , error);
   value = MarketInfo(symbol, MODE_TICKVALUE        ); error = GetLastError();                 debug(location +"   MODE_TICKVALUE         = "+                    NumberToStr(value, ".+")                                        , error);
   value = MarketInfo(symbol, MODE_TICKSIZE         ); error = GetLastError();                 debug(location +"   MODE_TICKSIZE          = "+                    NumberToStr(value, ifString(error, ".+", PriceFormat))          , error);
   value = MarketInfo(symbol, MODE_SWAPLONG         ); error = GetLastError();                 debug(location +"   MODE_SWAPLONG          = "+                    NumberToStr(value, ".+")                                        , error);
   value = MarketInfo(symbol, MODE_SWAPSHORT        ); error = GetLastError();                 debug(location +"   MODE_SWAPSHORT         = "+                    NumberToStr(value, ".+")                                        , error);
   value = MarketInfo(symbol, MODE_STARTING         ); error = GetLastError();                 debug(location +"   MODE_STARTING          = "+ ifString(value<=0, NumberToStr(value, ".+"), "'"+ TimeToStr(value, TIME_FULL) +"'"), error);
   value = MarketInfo(symbol, MODE_EXPIRATION       ); error = GetLastError();                 debug(location +"   MODE_EXPIRATION        = "+ ifString(value<=0, NumberToStr(value, ".+"), "'"+ TimeToStr(value, TIME_FULL) +"'"), error);
   value = MarketInfo(symbol, MODE_TRADEALLOWED     ); error = GetLastError();                 debug(location +"   MODE_TRADEALLOWED      = "+                    NumberToStr(value, ".+")                                        , error);
   value = MarketInfo(symbol, MODE_MINLOT           ); error = GetLastError();                 debug(location +"   MODE_MINLOT            = "+                    NumberToStr(value, ".+")                                        , error);
   value = MarketInfo(symbol, MODE_LOTSTEP          ); error = GetLastError();                 debug(location +"   MODE_LOTSTEP           = "+                    NumberToStr(value, ".+")                                        , error);
   value = MarketInfo(symbol, MODE_MAXLOT           ); error = GetLastError();                 debug(location +"   MODE_MAXLOT            = "+                    NumberToStr(value, ".+")                                        , error);
   value = MarketInfo(symbol, MODE_SWAPTYPE         ); error = GetLastError();                 debug(location +"   MODE_SWAPTYPE          = "+                    NumberToStr(value, ".+")                                        , error);
   value = MarketInfo(symbol, MODE_PROFITCALCMODE   ); error = GetLastError();                 debug(location +"   MODE_PROFITCALCMODE    = "+                    NumberToStr(value, ".+")                                        , error);
   value = MarketInfo(symbol, MODE_MARGINCALCMODE   ); error = GetLastError();                 debug(location +"   MODE_MARGINCALCMODE    = "+                    NumberToStr(value, ".+")                                        , error);
   value = MarketInfo(symbol, MODE_MARGININIT       ); error = GetLastError();                 debug(location +"   MODE_MARGININIT        = "+                    NumberToStr(value, ".+")                                        , error);
   value = MarketInfo(symbol, MODE_MARGINMAINTENANCE); error = GetLastError();                 debug(location +"   MODE_MARGINMAINTENANCE = "+                    NumberToStr(value, ".+")                                        , error);
   value = MarketInfo(symbol, MODE_MARGINHEDGED     ); error = GetLastError();                 debug(location +"   MODE_MARGINHEDGED      = "+                    NumberToStr(value, ".+")                                        , error);
   value = MarketInfo(symbol, MODE_MARGINREQUIRED   ); error = GetLastError();                 debug(location +"   MODE_MARGINREQUIRED    = "+                    NumberToStr(value, ".+")                                        , error);
   value = MarketInfo(symbol, MODE_FREEZELEVEL      ); error = GetLastError();                 debug(location +"   MODE_FREEZELEVEL       = "+                    NumberToStr(value, ".+")                                        , error);

   return(catch("DebugMarketInfo(1)"));
}


/*
MarketInfo()-Fehler im Tester
=============================

// EA im Tester
M15::TestExpert::onTick()      ---------------------------------
M15::TestExpert::onTick()      Predefined variables for "EURUSD"
M15::TestExpert::onTick()      ---------------------------------
M15::TestExpert::onTick()      Pip         = 0.0001'0
M15::TestExpert::onTick()      PipDigits   = 4
M15::TestExpert::onTick()      Digits  (b) = 5
M15::TestExpert::onTick()      Point   (b) = 0.0000'1
M15::TestExpert::onTick()      PipPoints   = 10
M15::TestExpert::onTick()      Bid/Ask (b) = 1.2711'2/1.2713'1
M15::TestExpert::onTick()      Bars    (b) = 1001
M15::TestExpert::onTick()      PriceFormat = ".4'"
M15::TestExpert::onTick()      ---------------------------------
M15::TestExpert::onTick()      MarketInfo() for "EURUSD"
M15::TestExpert::onTick()      ---------------------------------
M15::TestExpert::onTick()      MODE_LOW               = 0.0000'0                 // falsch: nicht modelliert
M15::TestExpert::onTick()      MODE_HIGH              = 0.0000'0                 // falsch: nicht modelliert
M15::TestExpert::onTick()      MODE_TIME              = '2012.11.12 00:00:00'
M15::TestExpert::onTick()      MODE_BID               = 1.2711'2
M15::TestExpert::onTick()      MODE_ASK               = 1.2713'1
M15::TestExpert::onTick()      MODE_POINT             = 0.0000'1
M15::TestExpert::onTick()      MODE_DIGITS            = 5
M15::TestExpert::onTick()      MODE_SPREAD            = 19
M15::TestExpert::onTick()      MODE_STOPLEVEL         = 20
M15::TestExpert::onTick()      MODE_LOTSIZE           = 100000
M15::TestExpert::onTick()      MODE_TICKVALUE         = 1                        // falsch: online
M15::TestExpert::onTick()      MODE_TICKSIZE          = 0.0000'1
M15::TestExpert::onTick()      MODE_SWAPLONG          = -1.3
M15::TestExpert::onTick()      MODE_SWAPSHORT         = 0.5
M15::TestExpert::onTick()      MODE_STARTING          = 0
M15::TestExpert::onTick()      MODE_EXPIRATION        = 0
M15::TestExpert::onTick()      MODE_TRADEALLOWED      = 0                        // falsch modelliert
M15::TestExpert::onTick()      MODE_MINLOT            = 0.01
M15::TestExpert::onTick()      MODE_LOTSTEP           = 0.01
M15::TestExpert::onTick()      MODE_MAXLOT            = 2
M15::TestExpert::onTick()      MODE_SWAPTYPE          = 0
M15::TestExpert::onTick()      MODE_PROFITCALCMODE    = 0
M15::TestExpert::onTick()      MODE_MARGINCALCMODE    = 0
M15::TestExpert::onTick()      MODE_MARGININIT        = 0
M15::TestExpert::onTick()      MODE_MARGINMAINTENANCE = 0
M15::TestExpert::onTick()      MODE_MARGINHEDGED      = 50000
M15::TestExpert::onTick()      MODE_MARGINREQUIRED    = 254.25
M15::TestExpert::onTick()      MODE_FREEZELEVEL       = 0

// Indikator im Tester, via iCustom()
M15::TestIndicator::onTick()   ---------------------------------
M15::TestIndicator::onTick()   Predefined variables for "EURUSD"
M15::TestIndicator::onTick()   ---------------------------------
M15::TestIndicator::onTick()   Pip         = 0.0001'0
M15::TestIndicator::onTick()   PipDigits   = 4
M15::TestIndicator::onTick()   Digits  (b) = 5
M15::TestIndicator::onTick()   Point   (b) = 0.0000'1
M15::TestIndicator::onTick()   PipPoints   = 10
M15::TestIndicator::onTick()   Bid/Ask (b) = 1.2711'2/1.2713'1
M15::TestIndicator::onTick()   Bars    (b) = 1001
M15::TestIndicator::onTick()   PriceFormat = ".4'"
M15::TestIndicator::onTick()   ---------------------------------
M15::TestIndicator::onTick()   MarketInfo() for "EURUSD"
M15::TestIndicator::onTick()   ---------------------------------
M15::TestIndicator::onTick()   MODE_LOW               = 0.0000'0                 // falsch übernommen
M15::TestIndicator::onTick()   MODE_HIGH              = 0.0000'0                 // falsch übernommen
M15::TestIndicator::onTick()   MODE_TIME              = '2012.11.12 00:00:00'
M15::TestIndicator::onTick()   MODE_BID               = 1.2711'2
M15::TestIndicator::onTick()   MODE_ASK               = 1.2713'1
M15::TestIndicator::onTick()   MODE_POINT             = 0.0000'1
M15::TestIndicator::onTick()   MODE_DIGITS            = 5
M15::TestIndicator::onTick()   MODE_SPREAD            = 0                        // völlig falsch
M15::TestIndicator::onTick()   MODE_STOPLEVEL         = 20
M15::TestIndicator::onTick()   MODE_LOTSIZE           = 100000
M15::TestIndicator::onTick()   MODE_TICKVALUE         = 1                        // falsch übernommen
M15::TestIndicator::onTick()   MODE_TICKSIZE          = 0.0000'1
M15::TestIndicator::onTick()   MODE_SWAPLONG          = -1.3
M15::TestIndicator::onTick()   MODE_SWAPSHORT         = 0.5
M15::TestIndicator::onTick()   MODE_STARTING          = 0
M15::TestIndicator::onTick()   MODE_EXPIRATION        = 0
M15::TestIndicator::onTick()   MODE_TRADEALLOWED      = 1
M15::TestIndicator::onTick()   MODE_MINLOT            = 0.01
M15::TestIndicator::onTick()   MODE_LOTSTEP           = 0.01
M15::TestIndicator::onTick()   MODE_MAXLOT            = 2
M15::TestIndicator::onTick()   MODE_SWAPTYPE          = 0
M15::TestIndicator::onTick()   MODE_PROFITCALCMODE    = 0
M15::TestIndicator::onTick()   MODE_MARGINCALCMODE    = 0
M15::TestIndicator::onTick()   MODE_MARGININIT        = 0
M15::TestIndicator::onTick()   MODE_MARGINMAINTENANCE = 0
M15::TestIndicator::onTick()   MODE_MARGINHEDGED      = 50000
M15::TestIndicator::onTick()   MODE_MARGINREQUIRED    = 259.73                   // falsch: online
M15::TestIndicator::onTick()   MODE_FREEZELEVEL       = 0

// Indikator im Tester, standalone
M15::TestIndicator::onTick()   ---------------------------------
M15::TestIndicator::onTick()   Predefined variables for "EURUSD"
M15::TestIndicator::onTick()   ---------------------------------
M15::TestIndicator::onTick()   Pip         = 0.0001'0
M15::TestIndicator::onTick()   PipDigits   = 4
M15::TestIndicator::onTick()   Digits  (b) = 5
M15::TestIndicator::onTick()   Point   (b) = 0.0000'1
M15::TestIndicator::onTick()   PipPoints   = 10
M15::TestIndicator::onTick()   Bid/Ask (b) = 1.2983'9/1.2986'7                   // falsch: online
M15::TestIndicator::onTick()   Bars    (b) = 1001
M15::TestIndicator::onTick()   PriceFormat = ".4'"
M15::TestIndicator::onTick()   ---------------------------------
M15::TestIndicator::onTick()   MarketInfo() for "EURUSD"
M15::TestIndicator::onTick()   ---------------------------------
M15::TestIndicator::onTick()   MODE_LOW               = 1.2967'6                 // falsch: online
M15::TestIndicator::onTick()   MODE_HIGH              = 1.3027'3                 // falsch: online
M15::TestIndicator::onTick()   MODE_TIME              = '2012.11.30 23:59:52'    // falsch: online
M15::TestIndicator::onTick()   MODE_BID               = 1.2983'9                 // falsch: online
M15::TestIndicator::onTick()   MODE_ASK               = 1.2986'7                 // falsch: online
M15::TestIndicator::onTick()   MODE_POINT             = 0.0000'1
M15::TestIndicator::onTick()   MODE_DIGITS            = 5
M15::TestIndicator::onTick()   MODE_SPREAD            = 28                       // falsch: online
M15::TestIndicator::onTick()   MODE_STOPLEVEL         = 20
M15::TestIndicator::onTick()   MODE_LOTSIZE           = 100000
M15::TestIndicator::onTick()   MODE_TICKVALUE         = 1
M15::TestIndicator::onTick()   MODE_TICKSIZE          = 0.0000'1
M15::TestIndicator::onTick()   MODE_SWAPLONG          = -1.3
M15::TestIndicator::onTick()   MODE_SWAPSHORT         = 0.5
M15::TestIndicator::onTick()   MODE_STARTING          = 0
M15::TestIndicator::onTick()   MODE_EXPIRATION        = 0
M15::TestIndicator::onTick()   MODE_TRADEALLOWED      = 1
M15::TestIndicator::onTick()   MODE_MINLOT            = 0.01
M15::TestIndicator::onTick()   MODE_LOTSTEP           = 0.01
M15::TestIndicator::onTick()   MODE_MAXLOT            = 2
M15::TestIndicator::onTick()   MODE_SWAPTYPE          = 0
M15::TestIndicator::onTick()   MODE_PROFITCALCMODE    = 0
M15::TestIndicator::onTick()   MODE_MARGINCALCMODE    = 0
M15::TestIndicator::onTick()   MODE_MARGININIT        = 0
M15::TestIndicator::onTick()   MODE_MARGINMAINTENANCE = 0
M15::TestIndicator::onTick()   MODE_MARGINHEDGED      = 50000
M15::TestIndicator::onTick()   MODE_MARGINREQUIRED    = 259.73                   // falsch: online
M15::TestIndicator::onTick()   MODE_FREEZELEVEL       = 0
*/


/**
 * Pad a string left-side to a minimum length using another substring.
 *
 * @param  string input                - source string
 * @param  int    padLength            - minimum length of the resulting string
 * @param  string padString [optional] - substring used for padding (default: space chars)
 *
 * @return string
 */
string StrPadLeft(string input, int padLength, string padString = " ") {
   while (StringLen(input) < padLength) {
      input = StringConcatenate(padString, input);
   }
   return(input);
}


/**
 * Alias of StrPadLeft()
 *
 * Pad a string left-side to a minimum length using another substring.
 *
 * @param  string input                - source string
 * @param  int    padLength            - minimum length of the resulting string
 * @param  string padString [optional] - substring used for padding (default: space chars)
 *
 * @return string
 */
string StrLeftPad(string input, int padLength, string padString = " ") {
   return(StrPadLeft(input, padLength, padString));
}


/**
 * Pad a string right-side to a minimum length using another substring.
 *
 * @param  string input                - source string
 * @param  int    padLength            - minimum length of the resulting string
 * @param  string padString [optional] - substring used for padding (default: space chars)
 *
 * @return string
 */
string StrPadRight(string input, int padLength, string padString = " ") {
   while (StringLen(input) < padLength) {
      input = StringConcatenate(input, padString);
   }
   return(input);
}


/**
 * Alias of StrPadRight()
 *
 * Pad a string right-side to a minimum length using another substring.
 *
 * @param  string input                - source string
 * @param  int    padLength            - minimum length of the resulting string
 * @param  string padString [optional] - substring used for padding (default: space chars)
 *
 * @return string
 */
string StrRightPad(string input, int padLength, string padString = " ") {
   return(StrPadRight(input, padLength, padString));
}


/**
 * Whether the current program is executed in the tester or on a tester chart.
 *
 * @return bool
 */
bool This.IsTesting() {
   static bool result, resolved;
   if (!resolved) {
      if (IsTesting()) result = true;
      else             result = __ExecutionContext[EC.testing] != 0;
      resolved = true;
   }
   return(result);
}


/**
 * Whether the current program runs on a demo account. Workaround for a bug in terminal builds <= 509 where the built-in
 * function IsDemo() returns FALSE in the tester.
 *
 * @return bool
 */
bool IsDemoFix() {
   static bool result, resolved;
   if (!resolved) {
      if (IsDemo()) result = true;
      else          result = This.IsTesting();
      resolved = true;
   }
   return(result);
}


/**
 * Listet alle ChildWindows eines Parent-Windows auf und schickt die Ausgabe an die Debug-Ausgabe.
 *
 * @param  int  hWnd                 - Handle des Parent-Windows
 * @param  bool recursive [optional] - ob die ChildWindows rekursiv aufgelistet werden sollen (default: nein)
 *
 * @return bool - Erfolgsstatus
 */
bool EnumChildWindows(int hWnd, bool recursive = false) {
   recursive = recursive!=0;
   if (hWnd <= 0)       return(!catch("EnumChildWindows(1)  invalid parameter hWnd="+ hWnd , ERR_INVALID_PARAMETER));
   if (!IsWindow(hWnd)) return(!catch("EnumChildWindows(2)  not an existing window hWnd="+ IntToHexStr(hWnd), ERR_RUNTIME_ERROR));

   string padding, class, title;
   int ctrlId;

   static int sublevel;
   if (!sublevel) {
      class  = GetClassName(hWnd);
      title  = GetWindowText(hWnd);
      ctrlId = GetDlgCtrlID(hWnd);
      debug("EnumChildWindows(.)  "+ IntToHexStr(hWnd) +": "+ class +" \""+ title +"\""+ ifString(ctrlId, " ("+ ctrlId +")", ""));
   }
   sublevel++;
   padding = StrRepeat(" ", (sublevel-1)<<1);

   int i, hWndNext=GetWindow(hWnd, GW_CHILD);
   while (hWndNext != 0) {
      i++;
      class  = GetClassName(hWndNext);
      title  = GetWindowText(hWndNext);
      ctrlId = GetDlgCtrlID(hWndNext);
      debug("EnumChildWindows(.)  "+ padding +"-> "+ IntToHexStr(hWndNext) +": "+ class +" \""+ title +"\""+ ifString(ctrlId, " ("+ ctrlId +")", ""));

      if (recursive) {
         if (!EnumChildWindows(hWndNext, true)) {
            sublevel--;
            return(false);
         }
      }
      hWndNext = GetWindow(hWndNext, GW_HWNDNEXT);
   }
   if (!sublevel) /*&&*/ if (!i) debug("EnumChildWindows(.)  "+ padding +"-> (no child windows)");

   sublevel--;
   return(!catch("EnumChildWindows(3)"));
}


/**
 * Konvertiert einen String in einen Boolean.
 *
 * Ist der Parameter strict = TRUE, werden die Strings "1" und "0", "on" und "off", "true" und "false", "yes" and "no" ohne
 * Beachtung von Groß-/Kleinschreibung konvertiert und alle anderen Werte lösen einen Fehler aus.
 *
 * Ist der Parameter strict = FALSE (default), werden unscharfe Rechtschreibfehler automatisch korrigiert (z.B. Ziffer 0 statt
 * großem Buchstaben O und umgekehrt), numerische Werte ungleich "1" und "0" entsprechend interpretiert und alle Werte, die
 * nicht als TRUE interpretiert werden können, als FALSE interpretiert.
 *
 * Leading/trailing White-Space wird in allen Fällen ignoriert.
 *
 * @param  string value             - der zu konvertierende String
 * @param  bool   strict [optional] - default: inaktiv
 *
 * @return bool
 */
bool StrToBool(string value, bool strict = false) {
   strict = strict!=0;

   value = StrTrim(value);
   string lValue = StrToLower(value);

   if (value  == "1"    ) return(true );
   if (value  == "0"    ) return(false);
   if (lValue == "on"   ) return(true );
   if (lValue == "off"  ) return(false);
   if (lValue == "true" ) return(true );
   if (lValue == "false") return(false);
   if (lValue == "yes"  ) return(true );
   if (lValue == "no"   ) return(false);

   if (strict) return(!catch("StrToBool(1)  cannot convert string "+ DoubleQuoteStr(value) +" to boolean (strict mode enabled)", ERR_INVALID_PARAMETER));

   if (value  == ""   ) return( false);
   if (value  == "O"  ) return(_false(log("StrToBool(2)  string "+ DoubleQuoteStr(value) +" is capital letter O, assumed to be zero")));
   if (lValue == "0n" ) return(_true (log("StrToBool(3)  string "+ DoubleQuoteStr(value) +" starts with zero, assumed to be \"On\"")));
   if (lValue == "0ff") return(_false(log("StrToBool(4)  string "+ DoubleQuoteStr(value) +" starts with zero, assumed to be \"Off\"")));
   if (lValue == "n0" ) return(_false(log("StrToBool(5)  string "+ DoubleQuoteStr(value) +" ends with zero, assumed to be \"no\"")));

   if (StrIsNumeric(value))
      return(StrToDouble(value) != 0);
   return(false);
}


/**
 * Konvertiert die Großbuchstaben eines String zu Kleinbuchstaben (code-page: ANSI westlich).
 *
 * @param  string value
 *
 * @return string
 */
string StrToLower(string value) {
   string result = value;
   int char, len=StringLen(value);

   for (int i=0; i < len; i++) {
      char = StringGetChar(value, i);
      //logische Version
      //if      ( 65 <= char && char <=  90) result = StringSetChar(result, i, char+32);  // A-Z->a-z
      //else if (192 <= char && char <= 214) result = StringSetChar(result, i, char+32);  // À-Ö->à-ö
      //else if (216 <= char && char <= 222) result = StringSetChar(result, i, char+32);  // Ø-Þ->ø-þ
      //else if (char == 138)                result = StringSetChar(result, i, 154);      // Š->š
      //else if (char == 140)                result = StringSetChar(result, i, 156);      // Œ->œ
      //else if (char == 142)                result = StringSetChar(result, i, 158);      // Ž->ž
      //else if (char == 159)                result = StringSetChar(result, i, 255);      // Ÿ->ÿ

      // für MQL optimierte Version
      if (char > 64) {
         if (char < 91) {
            result = StringSetChar(result, i, char+32);                 // A-Z->a-z
         }
         else if (char > 191) {
            if (char < 223) {
               if (char != 215)
                  result = StringSetChar(result, i, char+32);           // À-Ö->à-ö, Ø-Þ->ø-þ
            }
         }
         else if (char == 138) result = StringSetChar(result, i, 154);  // Š->š
         else if (char == 140) result = StringSetChar(result, i, 156);  // Œ->œ
         else if (char == 142) result = StringSetChar(result, i, 158);  // Ž->ž
         else if (char == 159) result = StringSetChar(result, i, 255);  // Ÿ->ÿ
      }
   }
   return(result);
}


/**
 * Konvertiert einen String in Großschreibweise.
 *
 * @param  string value
 *
 * @return string
 */
string StrToUpper(string value) {
   string result = value;
   int char, len=StringLen(value);

   for (int i=0; i < len; i++) {
      char = StringGetChar(value, i);
      //logische Version
      //if      (96 < char && char < 123)             result = StringSetChar(result, i, char-32);
      //else if (char==154 || char==156 || char==158) result = StringSetChar(result, i, char-16);
      //else if (char==255)                           result = StringSetChar(result, i,     159);  // ÿ -> Ÿ
      //else if (char > 223)                          result = StringSetChar(result, i, char-32);

      // für MQL optimierte Version
      if      (char == 255)                 result = StringSetChar(result, i,     159);            // ÿ -> Ÿ
      else if (char  > 223)                 result = StringSetChar(result, i, char-32);
      else if (char == 158)                 result = StringSetChar(result, i, char-16);
      else if (char == 156)                 result = StringSetChar(result, i, char-16);
      else if (char == 154)                 result = StringSetChar(result, i, char-16);
      else if (char  >  96) if (char < 123) result = StringSetChar(result, i, char-32);
   }
   return(result);
}


/**
 * Trim white space characters from both sides of a string.
 *
 * @param  string value
 *
 * @return string - trimmed string
 */
string StrTrim(string value) {
   return(StringTrimLeft(StringTrimRight(value)));
}


/**
 * Trim white space characters from the left side of a string. Alias of the built-in function StringTrimLeft().
 *
 * @param  string value
 *
 * @return string - trimmed string
 */
string StrTrimLeft(string value) {
   return(StringTrimLeft(value));
}


/**
 * Trim white space characters from the right side of a string. Alias of the built-in function StringTrimRight().
 *
 * @param  string value
 *
 * @return string - trimmed string
 */
string StrTrimRight(string value) {
   return(StringTrimRight(value));
}


/**
 * URL-kodiert einen String.  Leerzeichen werden als "+"-Zeichen kodiert.
 *
 * @param  string value
 *
 * @return string - URL-kodierter String
 */
string UrlEncode(string value) {
   string strChar, result="";
   int    char, len=StringLen(value);

   for (int i=0; i < len; i++) {
      strChar = StringSubstr(value, i, 1);
      char    = StringGetChar(strChar, 0);

      if      (47 < char && char <  58) result = StringConcatenate(result, strChar);                  // 0-9
      else if (64 < char && char <  91) result = StringConcatenate(result, strChar);                  // A-Z
      else if (96 < char && char < 123) result = StringConcatenate(result, strChar);                  // a-z
      else if (char == ' ')             result = StringConcatenate(result, "+");
      else                              result = StringConcatenate(result, "%", CharToHexStr(char));
   }

   if (!catch("UrlEncode(1)"))
      return(result);
   return("");
}


/**
 * Whether the specified directory exists in the MQL "files\" directory.
 *
 * @param  string dirname - Directory name relative to "files/", may be a symbolic link or a junction. Supported directory
 *                          separators are forward and backward slash.
 * @return bool
 */
bool MQL.IsDirectory(string dirname) {
   // TODO: Prüfen, ob Scripte und Indikatoren im Tester tatsächlich auf "{terminal-directory}\tester\" zugreifen.

   string filesDirectory = GetMqlFilesPath();
   if (!StringLen(filesDirectory))
      return(false);
   return(IsDirectoryA(StringConcatenate(filesDirectory, "\\", dirname)));
}


/**
 * Whether the specified file exists in the MQL "files/" directory.
 *
 * @param  string filename - Filename relative to "files/", may be a symbolic link. Supported directory separators are
 *                           forward and backward slash.
 * @return bool
 */
bool MQL.IsFile(string filename) {
   // TODO: Prüfen, ob Scripte und Indikatoren im Tester tatsächlich auf "{terminal-directory}\tester\" zugreifen.

   string filesDirectory = GetMqlFilesPath();
   if (!StringLen(filesDirectory))
      return(false);
   return(IsFileA(StringConcatenate(filesDirectory, "\\", filename)));
}


/**
 * Return the full path of the MQL "files" directory. This is the directory accessible to MQL file functions.
 *
 * @return string - directory path not ending with a slash or an empty string in case of errors
 */
string GetMqlFilesPath() {
   static string filesDir;

   if (!StringLen(filesDir)) {
      if (IsTesting()) {
         string dataDirectory = GetTerminalDataPathA();
         if (!StringLen(dataDirectory))
            return(EMPTY_STR);
         filesDir = dataDirectory +"\\tester\\files";
      }
      else {
         string mqlDirectory = GetMqlDirectoryA();
         if (!StringLen(mqlDirectory))
            return(EMPTY_STR);
         filesDir = mqlDirectory  +"\\files";
      }
   }
   return(filesDir);
}


/**
 * Gibt die hexadezimale Repräsentation eines Strings zurück.
 *
 * @param  string value - Ausgangswert
 *
 * @return string - Hex-String
 */
string StrToHexStr(string value) {
   if (StrIsNull(value))
      return("(NULL)");

   string result = "";
   int len = StringLen(value);

   for (int i=0; i < len; i++) {
      result = StringConcatenate(result, CharToHexStr(StringGetChar(value, i)));
   }

   return(result);
}


/**
 * Konvertiert das erste Zeichen eines Strings in Großschreibweise.
 *
 * @param  string value
 *
 * @return string
 */
string StrCapitalize(string value) {
   if (!StringLen(value))
      return(value);
   return(StringConcatenate(StrToUpper(StrLeft(value, 1)), StrSubstr(value, 1)));
}


/**
 * Schickt dem aktuellen Chart eine Nachricht zum Öffnen des EA-Input-Dialogs.
 *
 * @return int - Fehlerstatus
 *
 *
 * NOTE: Es wird nicht überprüft, ob zur Zeit des Aufrufs ein EA läuft.
 */
int Chart.Expert.Properties() {
   if (This.IsTesting()) return(catch("Chart.Expert.Properties(1)", ERR_FUNC_NOT_ALLOWED_IN_TESTER));

   int hWnd = __ExecutionContext[EC.hChart];

   if (!PostMessageA(hWnd, WM_COMMAND, ID_CHART_EXPERT_PROPERTIES, 0))
      return(catch("Chart.Expert.Properties(3)->user32::PostMessageA() failed", ERR_WIN32_ERROR));

   return(NO_ERROR);
}


/**
 * Schickt dem aktuellen Chart einen künstlichen Tick.
 *
 * @param  bool sound - ob der Tick akustisch bestätigt werden soll oder nicht (default: nein)
 *
 * @return int - Fehlerstatus
 */
int Chart.SendTick(bool sound=false) {
   sound = sound!=0;

   int hWnd = __ExecutionContext[EC.hChart];

   if (!This.IsTesting()) {
      PostMessageA(hWnd, WM_MT4(), MT4_TICK, TICK_OFFLINE_EA);    // LPARAM lParam: 0 - Expert::start() wird in Offline-Charts nicht getriggert
   }                                                              //                1 - Expert::start() wird in Offline-Charts getriggert (bei bestehender Server-Connection)
   else if (Tester.IsPaused()) {
      SendMessageA(hWnd, WM_COMMAND, ID_TESTER_TICK, 0);
   }

   if (sound)
      PlaySoundEx("Tick.wav");

   return(NO_ERROR);
}


/**
 * Ruft den Hauptmenü-Befehl Charts->Objects-Unselect All auf.
 *
 * @return int - Fehlerstatus
 */
int Chart.Objects.UnselectAll() {
   int hWnd = __ExecutionContext[EC.hChart];
   PostMessageA(hWnd, WM_COMMAND, ID_CHART_OBJECTS_UNSELECTALL, 0);
   return(NO_ERROR);
}


/**
 * Ruft den Kontextmenü-Befehl Chart->Refresh auf.
 *
 * @return int - Fehlerstatus
 */
int Chart.Refresh() {
   int hWnd = __ExecutionContext[EC.hChart];
   PostMessageA(hWnd, WM_COMMAND, ID_CHART_REFRESH, 0);
   return(NO_ERROR);
}


/**
 * Store a boolean value under the specified key in the chart.
 *
 * @param  string key   - unique value identifier with a maximum length of 63 characters
 * @param  bool   value - boolean value to store
 *
 * @return bool - success status
 */
bool Chart.StoreBool(string key, bool value) {
   value = value!=0;
   if (!__CHART())  return(!catch("Chart.StoreBool(1)  illegal function call in the current context (no chart)", ERR_FUNC_NOT_ALLOWED));

   int keyLen = StringLen(key);
   if (!keyLen)     return(!catch("Chart.StoreBool(2)  invalid parameter key: "+ DoubleQuoteStr(key) +" (not a chart object identifier)", ERR_INVALID_PARAMETER));
   if (keyLen > 63) return(!catch("Chart.StoreBool(3)  invalid parameter key: "+ DoubleQuoteStr(key) +" (more than 63 characters)", ERR_INVALID_PARAMETER));

   if (ObjectFind(key) == 0)
      ObjectDelete(key);
   ObjectCreate (key, OBJ_LABEL, 0, 0, 0);
   ObjectSet    (key, OBJPROP_TIMEFRAMES, OBJ_PERIODS_NONE);
   ObjectSetText(key, ""+ value);                                 // (string)(int) bool

   return(!catch("Chart.StoreBool(4)"));
}


/**
 * Store an integer value under the specified key in the chart.
 *
 * @param  string key   - unique value identifier with a maximum length of 63 characters
 * @param  int    value - integer value to store
 *
 * @return bool - success status
 */
bool Chart.StoreInt(string key, int value) {
   if (!__CHART())  return(!catch("Chart.StoreInt(1)  illegal function call in the current context (no chart)", ERR_FUNC_NOT_ALLOWED));

   int keyLen = StringLen(key);
   if (!keyLen)     return(!catch("Chart.StoreInt(2)  invalid parameter key: "+ DoubleQuoteStr(key) +" (not a chart object identifier)", ERR_INVALID_PARAMETER));
   if (keyLen > 63) return(!catch("Chart.StoreInt(3)  invalid parameter key: "+ DoubleQuoteStr(key) +" (more than 63 characters)", ERR_INVALID_PARAMETER));

   if (ObjectFind(key) == 0)
      ObjectDelete(key);
   ObjectCreate (key, OBJ_LABEL, 0, 0, 0);
   ObjectSet    (key, OBJPROP_TIMEFRAMES, OBJ_PERIODS_NONE);
   ObjectSetText(key, ""+ value);                                 // (string) int

   return(!catch("Chart.StoreInt(4)"));
}


/**
 * Store a color value under the specified key in the chart.
 *
 * @param  string key   - unique value identifier with a maximum length of 63 characters
 * @param  color  value - color value to store
 *
 * @return bool - success status
 */
bool Chart.StoreColor(string key, color value) {
   if (!__CHART())  return(!catch("Chart.StoreColor(1)  illegal function call in the current context (no chart)", ERR_FUNC_NOT_ALLOWED));

   int keyLen = StringLen(key);
   if (!keyLen)     return(!catch("Chart.StoreColor(2)  invalid parameter key: "+ DoubleQuoteStr(key) +" (not a chart object identifier)", ERR_INVALID_PARAMETER));
   if (keyLen > 63) return(!catch("Chart.StoreColor(3)  invalid parameter key: "+ DoubleQuoteStr(key) +" (more than 63 characters)", ERR_INVALID_PARAMETER));

   if (ObjectFind(key) == 0)
      ObjectDelete(key);
   ObjectCreate (key, OBJ_LABEL, 0, 0, 0);
   ObjectSet    (key, OBJPROP_TIMEFRAMES, OBJ_PERIODS_NONE);
   ObjectSetText(key, ""+ value);                                 // (string) color

   return(!catch("Chart.StoreColor(4)"));
}


/**
 * Store a double value under the specified key in the chart.
 *
 * @param  string key   - unique value identifier with a maximum length of 63 characters
 * @param  double value - double value to store
 *
 * @return bool - success status
 */
bool Chart.StoreDouble(string key, double value) {
   if (!__CHART())  return(!catch("Chart.StoreDouble(1)  illegal function call in the current context (no chart)", ERR_FUNC_NOT_ALLOWED));

   int keyLen = StringLen(key);
   if (!keyLen)     return(!catch("Chart.StoreDouble(2)  invalid parameter key: "+ DoubleQuoteStr(key) +" (not a chart object identifier)", ERR_INVALID_PARAMETER));
   if (keyLen > 63) return(!catch("Chart.StoreDouble(3)  invalid parameter key: "+ DoubleQuoteStr(key) +" (more than 63 characters)", ERR_INVALID_PARAMETER));

   if (ObjectFind(key) == 0)
      ObjectDelete(key);
   ObjectCreate (key, OBJ_LABEL, 0, 0, 0);
   ObjectSet    (key, OBJPROP_TIMEFRAMES, OBJ_PERIODS_NONE);
   ObjectSetText(key, DoubleToStr(value, 8));                     // (string) double

   return(!catch("Chart.StoreDouble(4)"));
}


/**
 * Store a string value under the specified key in the chart.
 *
 * @param  string key   - unique value identifier with a maximum length of 63 characters
 * @param  string value - string value to store
 *
 * @return bool - success status
 */
bool Chart.StoreString(string key, string value) {
   if (!__CHART())    return(!catch("Chart.StoreString(1)  illegal function call in the current context (no chart)", ERR_FUNC_NOT_ALLOWED));

   int keyLen = StringLen(key);
   if (!keyLen)       return(!catch("Chart.StoreString(2)  invalid parameter key: "+ DoubleQuoteStr(key) +" (not a chart object identifier)", ERR_INVALID_PARAMETER));
   if (keyLen > 63)   return(!catch("Chart.StoreString(3)  invalid parameter key: "+ DoubleQuoteStr(key) +" (more than 63 characters)", ERR_INVALID_PARAMETER));

   int valueLen = StringLen(value);
   if (valueLen > 63) return(!catch("Chart.StoreString(4)  invalid parameter value: "+ DoubleQuoteStr(value) +" (more than 63 characters)", ERR_INVALID_PARAMETER));

   if (!valueLen) {                                               // mark empty strings as the terminal fails to restore them
      value = "…(empty)…";                                        // that's 0x85
   }

   if (ObjectFind(key) == 0)
      ObjectDelete(key);
   ObjectCreate (key, OBJ_LABEL, 0, 0, 0);
   ObjectSet    (key, OBJPROP_TIMEFRAMES, OBJ_PERIODS_NONE);
   ObjectSetText(key, value);                                     // string

   return(!catch("Chart.StoreString(5)"));
}


/**
 * Restore the value of a boolean variable from the chart. If no stored value is found the function does nothing.
 *
 * @param  _In_  string key - unique variable identifier with a maximum length of 63 characters
 * @param  _Out_ bool  &var - variable to restore
 *
 * @return bool - success status
 */
bool Chart.RestoreBool(string key, bool &var) {
   if (!__CHART())             return(!catch("Chart.RestoreBool(1)  illegal function call in the current context (no chart)", ERR_FUNC_NOT_ALLOWED));

   int keyLen = StringLen(key);
   if (!keyLen)                return(!catch("Chart.RestoreBool(2)  invalid parameter key: "+ DoubleQuoteStr(key) +" (not a chart object identifier)", ERR_INVALID_PARAMETER));
   if (keyLen > 63)            return(!catch("Chart.RestoreBool(3)  invalid parameter key: "+ DoubleQuoteStr(key) +" (more than 63 characters)", ERR_INVALID_PARAMETER));

   if (ObjectFind(key) == 0) {
      string sValue = StrTrim(ObjectDescription(key));
      if (!StrIsDigit(sValue)) return(!catch("Chart.RestoreBool(4)  illegal chart value "+ DoubleQuoteStr(key) +" = "+ DoubleQuoteStr(ObjectDescription(key)), ERR_RUNTIME_ERROR));
      int iValue = StrToInteger(sValue);
      if (iValue > 1)          return(!catch("Chart.RestoreBool(5)  illegal chart value "+ DoubleQuoteStr(key) +" = "+ DoubleQuoteStr(ObjectDescription(key)), ERR_RUNTIME_ERROR));
      ObjectDelete(key);
      var = (iValue!=0);                                          // (bool)(int)string
   }
   return(!catch("Chart.RestoreBool(6)"));
}


/**
 * Restore the value of an integer variale from the chart. If no stored value is found the function does nothing.
 *
 * @param  _In_  string key - unique variable identifier with a maximum length of 63 characters
 * @param  _Out_ int   &var - variable to restore
 *
 * @return bool - success status
 */
bool Chart.RestoreInt(string key, int &var) {
   if (!__CHART())             return(!catch("Chart.RestoreInt(1)  illegal function call in the current context (no chart)", ERR_FUNC_NOT_ALLOWED));

   int keyLen = StringLen(key);
   if (!keyLen)                return(!catch("Chart.RestoreInt(2)  invalid parameter key: "+ DoubleQuoteStr(key) +" (not a chart object identifier)", ERR_INVALID_PARAMETER));
   if (keyLen > 63)            return(!catch("Chart.RestoreInt(3)  invalid parameter key: "+ DoubleQuoteStr(key) +" (more than 63 characters)", ERR_INVALID_PARAMETER));

   if (ObjectFind(key) == 0) {
      string sValue = StrTrim(ObjectDescription(key));
      if (!StrIsDigit(sValue)) return(!catch("Chart.RestoreInt(4)  illegal chart value "+ DoubleQuoteStr(key) +" = "+ DoubleQuoteStr(ObjectDescription(key)), ERR_RUNTIME_ERROR));
      ObjectDelete(key);
      var = StrToInteger(sValue);                                 // (int)string
   }
   return(!catch("Chart.RestoreInt(5)"));
}


/**
 * Restore the value of a color variable from the chart. If no stored value is found the function does nothing.
 *
 * @param  _In_  string key - unique variable identifier with a maximum length of 63 characters
 * @param  _Out_ color &var - variable to restore
 *
 * @return bool - success status
 */
bool Chart.RestoreColor(string key, color &var) {
   if (!__CHART())               return(!catch("Chart.RestoreColor(1)  illegal function call in the current context (no chart)", ERR_FUNC_NOT_ALLOWED));

   int keyLen = StringLen(key);
   if (!keyLen)                  return(!catch("Chart.RestoreColor(2)  invalid parameter key: "+ DoubleQuoteStr(key) +" (not a chart object identifier)", ERR_INVALID_PARAMETER));
   if (keyLen > 63)              return(!catch("Chart.RestoreColor(3)  invalid parameter key: "+ DoubleQuoteStr(key) +" (more than 63 characters)", ERR_INVALID_PARAMETER));

   if (ObjectFind(key) == 0) {
      string sValue = StrTrim(ObjectDescription(key));
      if (!StrIsInteger(sValue)) return(!catch("Chart.RestoreColor(4)  illegal chart value "+ DoubleQuoteStr(key) +" = "+ DoubleQuoteStr(ObjectDescription(key)), ERR_RUNTIME_ERROR));
      int iValue = StrToInteger(sValue);
      if (iValue < CLR_NONE || iValue > C'255,255,255')
                                 return(!catch("Chart.RestoreColor(5)  illegal chart value "+ DoubleQuoteStr(key) +" = "+ DoubleQuoteStr(ObjectDescription(key)) +" (0x"+ IntToHexStr(iValue) +")", ERR_RUNTIME_ERROR));
      ObjectDelete(key);
      var = iValue;                                               // (color)(int)string
   }
   return(!catch("Chart.RestoreColor(6)"));
}


/**
 * Restore the value of a double variable from the chart. If no stored value is found the function does nothing.
 *
 * @param  _In_  string  key - unique variable identifier with a maximum length of 63 characters
 * @param  _Out_ double &var - variable to restore
 *
 * @return bool - success status
 */
bool Chart.RestoreDouble(string key, double &var) {
   if (!__CHART())               return(!catch("Chart.RestoreDouble(1)  illegal function call in the current context (no chart)", ERR_FUNC_NOT_ALLOWED));

   int keyLen = StringLen(key);
   if (!keyLen)                  return(!catch("Chart.RestoreDouble(2)  invalid parameter key: "+ DoubleQuoteStr(key) +" (not a chart object identifier)", ERR_INVALID_PARAMETER));
   if (keyLen > 63)              return(!catch("Chart.RestoreDouble(3)  invalid parameter key: "+ DoubleQuoteStr(key) +" (more than 63 characters)", ERR_INVALID_PARAMETER));

   if (ObjectFind(key) == 0) {
      string sValue = StrTrim(ObjectDescription(key));
      if (!StrIsNumeric(sValue)) return(!catch("Chart.RestoreDouble(4)  illegal chart value "+ DoubleQuoteStr(key) +" = "+ DoubleQuoteStr(ObjectDescription(key)), ERR_RUNTIME_ERROR));
      ObjectDelete(key);
      var = StrToDouble(sValue);                                  // (double)string
   }
   return(!catch("Chart.RestoreDouble(5)"));
}


/**
 * Restore the value of a string variable from the chart. If no stored value is found the function does nothing.
 *
 * @param  _In_  string  key - unique variable identifier with a maximum length of 63 characters
 * @param  _Out_ string &var - variable to restore
 *
 * @return bool - success status
 */
bool Chart.RestoreString(string key, string &var) {
   if (!__CHART())  return(!catch("Chart.RestoreString(1)  illegal function call in the current context (no chart)", ERR_FUNC_NOT_ALLOWED));

   int keyLen = StringLen(key);
   if (!keyLen)     return(!catch("Chart.RestoreString(2)  invalid parameter key: "+ DoubleQuoteStr(key) +" (not a chart object identifier)", ERR_INVALID_PARAMETER));
   if (keyLen > 63) return(!catch("Chart.RestoreString(3)  invalid parameter key: "+ DoubleQuoteStr(key) +" (more than 63 characters)", ERR_INVALID_PARAMETER));

   if (ObjectFind(key) == 0) {
      string sValue = ObjectDescription(key);
      ObjectDelete(key);

      if (sValue == "…(empty)…") var = "";         // restore marked empty strings as the terminal deserializes "" to the value "Text"
      else                       var = sValue;     // string
   }
   return(!catch("Chart.RestoreString(4)"));
}


/**
 * Delete the chart value stored under the specified key.
 *
 * @param  string key - chart object identifier with a maximum length of 63 characters
 *
 * @return bool - success status
 */
bool Chart.DeleteValue(string key) {
   if (!__CHART())  return(true);

   int keyLen = StringLen(key);
   if (!keyLen)     return(!catch("Chart.DeleteValue(1)  invalid parameter key: "+ DoubleQuoteStr(key) +" (not a chart object identifier)", ERR_INVALID_PARAMETER));
   if (keyLen > 63) return(!catch("Chart.DeleteValue(2)  invalid parameter key: "+ DoubleQuoteStr(key) +" (more than 63 characters)", ERR_INVALID_PARAMETER));

   if (ObjectFind(key) >= 0) {
      ObjectDelete(key);
   }
   return(!catch("Chart.DeleteValue(3)"));
}


/**
 * Get the bar model currently selected in the tester.
 *
 * @return int - bar model id or EMPTY (-1) if not called from within the tester
 */
int Tester.GetBarModel() {
   if (!This.IsTesting())
      return(_EMPTY(catch("Tester.GetBarModel(1)  Tester only function", ERR_FUNC_NOT_ALLOWED)));
   return(Tester_GetBarModel());
}


/**
 * Pause the tester. Must be called from within the tester.
 *
 * @param  string location [optional] - location identifier of the caller (default: none)
 *
 * @return int - error status
 */
int Tester.Pause(string location = "") {
   if (!This.IsTesting()) return(catch("Tester.Pause(1)  Tester only function", ERR_FUNC_NOT_ALLOWED));

   if (!IsVisualModeFix()) return(NO_ERROR);                            // skip if VisualMode=Off
   if (Tester.IsStopped()) return(NO_ERROR);                            // skip if already stopped
   if (Tester.IsPaused())  return(NO_ERROR);                            // skip if already paused

   int hWnd = GetTerminalMainWindow();
   if (!hWnd) return(last_error);

   if (__LOG()) log(location + ifString(StringLen(location), "->", "") +"Tester.Pause()");

   PostMessageA(hWnd, WM_COMMAND, IDC_TESTER_SETTINGS_PAUSERESUME, 0);
 //SendMessageA(hWnd, WM_COMMAND, IDC_TESTER_SETTINGS_PAUSERESUME, 0);  // in deinit() SendMessage() causes a thread lock which is
   return(NO_ERROR);                                                    // accounted for by Tester.IsStopped()
}


/**
 * Stop the tester. Must be called from within the tester.
 *
 * @param  string location [optional] - location identifier of the caller (default: none)
 *
 * @return int - error status
 */
int Tester.Stop(string location = "") {
   if (!IsTesting()) return(catch("Tester.Stop(1)  Tester only function", ERR_FUNC_NOT_ALLOWED));

   if (Tester.IsStopped()) return(NO_ERROR);                            // skip if already stopped

   if (__LOG()) log(location + ifString(StringLen(location), "->", "") +"Tester.Stop()");

   int hWnd = GetTerminalMainWindow();
   if (!hWnd) return(last_error);

   PostMessageA(hWnd, WM_COMMAND, IDC_TESTER_SETTINGS_STARTSTOP, 0);
 //SendMessageA(hWnd, WM_COMMAND, IDC_TESTER_SETTINGS_STARTSTOP, 0);    // in deinit() SendMessage() causes a thread lock which is
   return(NO_ERROR);                                                    // accounted for by Tester.IsStopped()
}


/**
 * Whether the tester currently pauses. Must be called from within the tester.
 *
 * @return bool
 */
bool Tester.IsPaused() {
   if (!This.IsTesting()) return(!catch("Tester.IsPaused(1)  Tester only function", ERR_FUNC_NOT_ALLOWED));

   if (!IsVisualModeFix()) return(false);
   if (Tester.IsStopped()) return(false);

   int hWndSettings = GetDlgItem(FindTesterWindow(), IDC_TESTER_SETTINGS);
   int hWnd = GetDlgItem(hWndSettings, IDC_TESTER_SETTINGS_PAUSERESUME);

   return(GetWindowText(hWnd) == ">>");
}


/**
 * Whether the tester was stopped. Must be called from within the tester.
 *
 * @return bool
 */
bool Tester.IsStopped() {
   if (!This.IsTesting()) return(!catch("Tester.IsStopped(1)  Tester only function", ERR_FUNC_NOT_ALLOWED));

   if (IsScript()) {
      int hWndSettings = GetDlgItem(FindTesterWindow(), IDC_TESTER_SETTINGS);
      return(GetWindowText(GetDlgItem(hWndSettings, IDC_TESTER_SETTINGS_STARTSTOP)) == "Start");
   }
   return(__ExecutionContext[EC.programCoreFunction] == CF_DEINIT);     // if in deinit() the tester was already stopped,
}                                                                       // no matter whether in an expert or an indicator


/**
 * Erzeugt einen neuen String der gewünschten Länge.
 *
 * @param  int length - Länge
 *
 * @return string
 */
string CreateString(int length) {
   if (length < 0)        return(_EMPTY_STR(catch("CreateString(1)  invalid parameter length = "+ length, ERR_INVALID_PARAMETER)));
   if (length == INT_MAX) return(_EMPTY_STR(catch("CreateString(2)  too large parameter length: INT_MAX", ERR_INVALID_PARAMETER)));

   if (!length) return(StringConcatenate("", ""));                   // Um immer einen neuen String zu erhalten (MT4-Zeigerproblematik), darf Ausgangsbasis kein Literal sein.
                                                                     // Daher wird auch beim Initialisieren der string-Variable StringConcatenate() verwendet (siehe MQL.doc).
   string newStr = StringConcatenate(MAX_STRING_LITERAL, "");
   int    strLen = StringLen(newStr);

   while (strLen < length) {
      newStr = StringConcatenate(newStr, MAX_STRING_LITERAL);
      strLen = StringLen(newStr);
   }

   if (strLen != length)
      newStr = StringSubstr(newStr, 0, length);
   return(newStr);
}


/**
 * Aktiviert bzw. deaktiviert den Aufruf der start()-Funktion von Expert Advisern bei Eintreffen von Ticks.
 * Wird üblicherweise aus der init()-Funktion aufgerufen.
 *
 * @param  bool enable - gewünschter Status: On/Off
 *
 * @return int - Fehlerstatus
 */
int Toolbar.Experts(bool enable) {
   enable = enable!=0;

   if (This.IsTesting()) return(debug("Toolbar.Experts(1)  skipping in Tester", NO_ERROR));

   // TODO: Lock implementieren, damit mehrere gleichzeitige Aufrufe sich nicht gegenseitig überschreiben
   // TODO: Vermutlich Deadlock bei IsStopped()=TRUE, dann PostMessage() verwenden

   int hWnd = GetTerminalMainWindow();
   if (!hWnd)
      return(last_error);

   if (enable) {
      if (!IsExpertEnabled())
         SendMessageA(hWnd, WM_COMMAND, ID_EXPERTS_ONOFF, 0);
   }
   else /*disable*/ {
      if (IsExpertEnabled())
         SendMessageA(hWnd, WM_COMMAND, ID_EXPERTS_ONOFF, 0);
   }
   return(NO_ERROR);
}


/**
 * Ruft den Kontextmenü-Befehl MarketWatch->Symbols auf.
 *
 * @return int - Fehlerstatus
 */
int MarketWatch.Symbols() {
   int hWnd = GetTerminalMainWindow();
   if (!hWnd)
      return(last_error);

   PostMessageA(hWnd, WM_COMMAND, ID_MARKETWATCH_SYMBOLS, 0);
   return(NO_ERROR);
}


/**
 * Prüft, ob der aktuelle Tick ein neuer Tick ist.
 *
 * @return bool - Ergebnis
 */
bool EventListener.NewTick() {
   int vol = Volume[0];
   if (!vol)                                                         // Tick ungültig (z.B. Symbol noch nicht subscribed)
      return(false);

   static bool lastResult;
   static int  lastTick, lastVol;

   // Mehrfachaufrufe während desselben Ticks erkennen
   if (Tick == lastTick)
      return(lastResult);

   // Es reicht immer, den Tick nur anhand des Volumens des aktuellen Timeframes zu bestimmen.
   bool result = (lastVol && vol!=lastVol);                          // wenn der letzte Tick gültig war und sich das aktuelle Volumen geändert hat
                                                                     // (Optimierung unnötig, da im Normalfall immer beide Bedingungen zutreffen)
   lastVol    = vol;
   lastResult = result;
   return(result);
}


/**
 * Gibt die aktuelle Server-Zeit des Terminals zurück (im Tester entsprechend der im Tester modellierten Zeit). Diese Zeit
 * muß nicht mit der Zeit des letzten Ticks übereinstimmen (z.B. am Wochenende oder wenn keine Ticks existieren).
 *
 * @return datetime - Server-Zeit oder NULL, falls ein Fehler auftrat
 */
datetime TimeServer() {
   datetime serverTime;

   if (This.IsTesting()) {
      // im Tester entspricht die Serverzeit immer der Zeit des letzten Ticks
      serverTime = TimeCurrentEx("TimeServer(1)"); if (!serverTime) return(NULL);
   }
   else {
      // Außerhalb des Testers darf TimeCurrent[Ex]() nicht verwendet werden. Der Rückgabewert ist in Kurspausen bzw. am Wochenende oder wenn keine
      // Ticks existieren (in Offline-Charts) falsch.
      serverTime = GmtToServerTime(GetGmtTime()); if (serverTime == NaT) return(NULL);
   }
   return(serverTime);
}


/**
 * Gibt die aktuelle GMT-Zeit des Terminals zurück (im Tester entsprechend der im Tester modellierten Zeit).
 *
 * @return datetime - GMT-Zeit oder NULL, falls ein Fehler auftrat
 */
datetime TimeGMT() {
   datetime gmt;

   if (This.IsTesting()) {
      // TODO: Scripte und Indikatoren sehen bei Aufruf von TimeLocal() im Tester u.U. nicht die modellierte, sondern die reale Zeit oder sogar NULL.
      datetime localTime = GetLocalTime(); if (!localTime) return(NULL);
      gmt = ServerToGmtTime(localTime);                              // TimeLocal() entspricht im Tester der Serverzeit
   }
   else {
      gmt = GetGmtTime();
   }
   return(gmt);
}


/**
 * Gibt die aktuelle FXT-Zeit des Terminals zurück (im Tester entsprechend der im Tester modellierten Zeit).
 *
 * @return datetime - FXT-Zeit oder NULL, falls ein Fehler auftrat
 */
datetime TimeFXT() {
   datetime gmt = TimeGMT();         if (!gmt)       return(NULL);
   datetime fxt = GmtToFxtTime(gmt); if (fxt == NaT) return(NULL);
   return(fxt);
}


/**
 * Gibt die aktuelle FXT-Zeit des Systems zurück (auch im Tester).
 *
 * @return datetime - FXT-Zeit oder NULL, falls ein Fehler auftrat
 */
datetime GetFxtTime() {
   datetime gmt = GetGmtTime();      if (!gmt)       return(NULL);
   datetime fxt = GmtToFxtTime(gmt); if (fxt == NaT) return(NULL);
   return(fxt);
}


/**
 * Gibt die aktuelle Serverzeit zurück (auch im Tester). Dies ist nicht der Zeitpunkt des letzten eingetroffenen Ticks wie
 * von TimeCurrent() zurückgegeben, sondern die auf dem Server tatsächlich gültige Zeit (in seiner Zeitzone).
 *
 * @return datetime - Serverzeit oder NULL, falls ein Fehler auftrat
 */
datetime GetServerTime() {
   datetime gmt  = GetGmtTime();         if (!gmt)        return(NULL);
   datetime time = GmtToServerTime(gmt); if (time == NaT) return(NULL);
   return(time);
}


/**
 * Gibt den Zeitpunkt des letzten Ticks aller selektierten Symbole zurück. Im Tester entspricht diese Zeit dem Zeitpunkt des
 * letzten Ticks des getesteten Symbols.
 *
 * @param  string location - Bezeichner für eine evt. Fehlermeldung
 *
 * @return datetime - Zeitpunkt oder NULL, falls ein Fehler auftrat
 *
 *
 * NOTE: Im Unterschied zur Originalfunktion meldet diese Funktion einen Fehler, wenn der Zeitpunkt des letzten Ticks nicht
 *       bekannt ist.
 */
datetime TimeCurrentEx(string location="") {
   datetime time = TimeCurrent();
   if (!time) return(!catch(location + ifString(!StringLen(location), "", "->") +"TimeCurrentEx(1)->TimeCurrent() = 0", ERR_RUNTIME_ERROR));
   return(time);
}


/**
 * Return a readable version of a module type flag.
 *
 * @param  int fType - combination of one or more module type flags
 *
 * @return string
 */
string ModuleTypesToStr(int fType) {
   string result = "";

   if (fType & MT_EXPERT    && 1) result = StringConcatenate(result, "|MT_EXPERT"   );
   if (fType & MT_SCRIPT    && 1) result = StringConcatenate(result, "|MT_SCRIPT"   );
   if (fType & MT_INDICATOR && 1) result = StringConcatenate(result, "|MT_INDICATOR");
   if (fType & MT_LIBRARY   && 1) result = StringConcatenate(result, "|MT_LIBRARY"  );

   if (!StringLen(result)) result = "(unknown module type "+ fType +")";
   else                    result = StringSubstr(result, 1);
   return(result);
}


/**
 * Gibt die Beschreibung eines UninitializeReason-Codes zurück (siehe UninitializeReason()).
 *
 * @param  int reason - Code
 *
 * @return string
 */
string UninitializeReasonDescription(int reason) {
   switch (reason) {
      case UR_UNDEFINED  : return("undefined"                          );
      case UR_REMOVE     : return("program removed from chart"         );
      case UR_RECOMPILE  : return("program recompiled"                 );
      case UR_CHARTCHANGE: return("chart symbol or timeframe changed"  );
      case UR_CHARTCLOSE : return("chart closed"                       );
      case UR_PARAMETERS : return("input parameters changed"           );
      case UR_ACCOUNT    : return("account or account settings changed");
      // ab Build > 509
      case UR_TEMPLATE   : return("template changed"                   );
      case UR_INITFAILED : return("OnInit() failed"                    );
      case UR_CLOSE      : return("terminal closed"                    );
   }
   return(_EMPTY_STR(catch("UninitializeReasonDescription()  invalid parameter reason = "+ reason, ERR_INVALID_PARAMETER)));
}


/**
 * Return the program's current init() reason code.
 *
 * @return int
 */
int ProgramInitReason() {
   return(__ExecutionContext[EC.programInitReason]);
}


/**
 * Gibt die Beschreibung eines InitReason-Codes zurück.
 *
 * @param  int reason - Code
 *
 * @return string
 */
string InitReasonDescription(int reason) {
   switch (reason) {
      case INITREASON_USER             : return("program loaded by user"    );
      case INITREASON_TEMPLATE         : return("program loaded by template");
      case INITREASON_PROGRAM          : return("program loaded by program" );
      case INITREASON_PROGRAM_AFTERTEST: return("program loaded after test" );
      case INITREASON_PARAMETERS       : return("input parameters changed"  );
      case INITREASON_TIMEFRAMECHANGE  : return("chart timeframe changed"   );
      case INITREASON_SYMBOLCHANGE     : return("chart symbol changed"      );
      case INITREASON_RECOMPILE        : return("program recompiled"        );
      case INITREASON_TERMINAL_FAILURE : return("terminal failure"          );
   }
   return(_EMPTY_STR(catch("InitReasonDescription(1)  invalid parameter reason: "+ reason, ERR_INVALID_PARAMETER)));
}


/**
 * Gibt den Wert der extern verwalteten Assets eines Accounts zurück.
 *
 * @param  string companyId - AccountCompany-Identifier
 * @param  string accountId - Account-Identifier
 *
 * @return double - Wert oder EMPTY_VALUE, falls ein Fehler auftrat
 */
double GetExternalAssets(string companyId, string accountId) {
   if (!StringLen(companyId)) return(_EMPTY_VALUE(catch("GetExternalAssets(1)  invalid parameter companyId = "+ DoubleQuoteStr(companyId), ERR_INVALID_PARAMETER)));
   if (!StringLen(accountId)) return(_EMPTY_VALUE(catch("GetExternalAssets(2)  invalid parameter accountId = "+ DoubleQuoteStr(accountId), ERR_INVALID_PARAMETER)));

   static string lastCompanyId;
   static string lastAccountId;
   static double lastAuM;

   if (companyId!=lastCompanyId || accountId!=lastAccountId) {
      double aum = RefreshExternalAssets(companyId, accountId);
      if (IsEmptyValue(aum))
         return(EMPTY_VALUE);

      lastCompanyId = companyId;
      lastAccountId = accountId;
      lastAuM       = aum;
   }
   return(lastAuM);
}


/**
 * Liest den Konfigurationswert der extern verwalteten Assets eines Acounts neu ein.  Der konfigurierte Wert kann negativ
 * sein, um die Accountgröße herunterzuskalieren (z.B. zum Testen einer Strategie im Real-Account).
 *
 * @param  string companyId - AccountCompany-Identifier
 * @param  string accountId - Account-Identifier
 *
 * @return double - Wert oder EMPTY_VALUE, falls ein Fehler auftrat
 */
double RefreshExternalAssets(string companyId, string accountId) {
   if (!StringLen(companyId)) return(_EMPTY_VALUE(catch("RefreshExternalAssets(1)  invalid parameter companyId = "+ DoubleQuoteStr(companyId), ERR_INVALID_PARAMETER)));
   if (!StringLen(accountId)) return(_EMPTY_VALUE(catch("RefreshExternalAssets(2)  invalid parameter accountId = "+ DoubleQuoteStr(accountId), ERR_INVALID_PARAMETER)));

   string file    = GetAccountConfigPath(companyId, accountId);
   string section = "General";
   string key     = "AuM.Value";
   double value   = GetIniDouble(file, section, key);

   return(value);
}


/**
 * Ermittelt den Kurznamen der Firma des aktuellen Accounts. Der Name wird vom Namen des Trade-Servers abgeleitet, nicht vom
 * Rückgabewert von AccountCompany().
 *
 * @return string - Kurzname oder Leerstring, falls ein Fehler auftrat
 */
string ShortAccountCompany() {
   // Da bei Accountwechsel der Rückgabewert von AccountServer() bereits wechselt, obwohl der aktuell verarbeitete Tick noch
   // auf Daten des alten Account-Servers arbeitet, kann die Funktion AccountServer() nicht direkt verwendet werden. Statt
   // dessen muß immer der Umweg über GetServerName() gegangen werden. Die Funktion gibt erst dann einen geänderten Servernamen
   // zurück, wenn tatsächlich ein Tick des neuen Servers verarbeitet wird.
   //
   string server = GetServerName(); if (!StringLen(server)) return("");
   string name = StrLeftTo(server, "-"), lName = StrToLower(name);

   if (lName == "alpari"            ) return(AC.Alpari          );
   if (lName == "alparibroker"      ) return(AC.Alpari          );
   if (lName == "alpariuk"          ) return(AC.Alpari          );
   if (lName == "alparius"          ) return(AC.Alpari          );
   if (lName == "apbgtrading"       ) return(AC.APBG            );
   if (lName == "atcbrokers"        ) return(AC.ATCBrokers      );
   if (lName == "atcbrokersest"     ) return(AC.ATCBrokers      );
   if (lName == "atcbrokersliq1"    ) return(AC.ATCBrokers      );
   if (lName == "axitrader"         ) return(AC.AxiTrader       );
   if (lName == "axitraderusa"      ) return(AC.AxiTrader       );
   if (lName == "broco"             ) return(AC.BroCo           );
   if (lName == "brocoinvestments"  ) return(AC.BroCo           );
   if (lName == "cmap"              ) return(AC.ICMarkets       );     // demo
   if (lName == "collectivefx"      ) return(AC.CollectiveFX    );
   if (lName == "dukascopy"         ) return(AC.Dukascopy       );
   if (lName == "easyforex"         ) return(AC.EasyForex       );
   if (lName == "finfx"             ) return(AC.FinFX           );
   if (lName == "forex"             ) return(AC.ForexLtd        );
   if (lName == "forexbaltic"       ) return(AC.FBCapital       );
   if (lName == "fxopen"            ) return(AC.FXOpen          );
   if (lName == "fxprimus"          ) return(AC.FXPrimus        );
   if (lName == "fxpro.com"         ) return(AC.FxPro           );
   if (lName == "fxdd"              ) return(AC.FXDD            );
   if (lName == "gci"               ) return(AC.GCI             );
   if (lName == "gcmfx"             ) return(AC.Gallant         );
   if (lName == "gftforex"          ) return(AC.GFT             );
   if (lName == "globalprime"       ) return(AC.GlobalPrime     );
   if (lName == "icmarkets"         ) return(AC.ICMarkets       );
   if (lName == "inovatrade"        ) return(AC.InovaTrade      );
   if (lName == "integral"          ) return(AC.GlobalPrime     );     // demo
   if (lName == "investorseurope"   ) return(AC.InvestorsEurope );
   if (lName == "jfd"               ) return(AC.JFDBrokers      );
   if (lName == "liteforex"         ) return(AC.LiteForex       );
   if (lName == "londoncapitalgr"   ) return(AC.LondonCapital   );
   if (lName == "londoncapitalgroup") return(AC.LondonCapital   );
   if (lName == "mbtrading"         ) return(AC.MBTrading       );
   if (lName == "metaquotes"        ) return(AC.MetaQuotes      );
   if (lName == "migbank"           ) return(AC.MIG             );
   if (lName == "oanda"             ) return(AC.Oanda           );
   if (lName == "pepperstone"       ) return(AC.Pepperstone     );
   if (lName == "primexm"           ) return(AC.PrimeXM         );
   if (lName == "sig"               ) return(AC.LiteForex       );
   if (lName == "sts"               ) return(AC.STS             );
   if (lName == "teletrade"         ) return(AC.TeleTrade       );
   if (lName == "teletradecy"       ) return(AC.TeleTrade       );
   if (lName == "tickmill"          ) return(AC.TickMill        );
   if (lName == "xtrade"            ) return(AC.XTrade          );

   debug("ShortAccountCompany(1)  unknown server name \""+ server +"\", using \""+ name +"\"");
   return(name);
}


/**
 * Gibt die ID einer Account-Company zurück.
 *
 * @param string shortName - Kurzname der Account-Company
 *
 * @return int - Company-ID oder NULL, falls der übergebene Wert keine bekannte Account-Company ist
 */
int AccountCompanyId(string shortName) {
   if (!StringLen(shortName))
      return(NULL);

   shortName = StrToUpper(shortName);

   switch (StringGetChar(shortName, 0)) {
      case 'A': if (shortName == StrToUpper(AC.Alpari         )) return(AC_ID.Alpari         );
                if (shortName == StrToUpper(AC.APBG           )) return(AC_ID.APBG           );
                if (shortName == StrToUpper(AC.ATCBrokers     )) return(AC_ID.ATCBrokers     );
                if (shortName == StrToUpper(AC.AxiTrader      )) return(AC_ID.AxiTrader      );
                break;

      case 'B': if (shortName == StrToUpper(AC.BroCo          )) return(AC_ID.BroCo          );
                break;

      case 'C': if (shortName == StrToUpper(AC.CollectiveFX   )) return(AC_ID.CollectiveFX   );
                break;

      case 'D': if (shortName == StrToUpper(AC.Dukascopy      )) return(AC_ID.Dukascopy      );
                break;

      case 'E': if (shortName == StrToUpper(AC.EasyForex      )) return(AC_ID.EasyForex      );
                break;

      case 'F': if (shortName == StrToUpper(AC.FBCapital      )) return(AC_ID.FBCapital      );
                if (shortName == StrToUpper(AC.FinFX          )) return(AC_ID.FinFX          );
                if (shortName == StrToUpper(AC.ForexLtd       )) return(AC_ID.ForexLtd       );
                if (shortName == StrToUpper(AC.FXPrimus       )) return(AC_ID.FXPrimus       );
                if (shortName == StrToUpper(AC.FXDD           )) return(AC_ID.FXDD           );
                if (shortName == StrToUpper(AC.FXOpen         )) return(AC_ID.FXOpen         );
                if (shortName == StrToUpper(AC.FxPro          )) return(AC_ID.FxPro          );
                break;

      case 'G': if (shortName == StrToUpper(AC.Gallant        )) return(AC_ID.Gallant        );
                if (shortName == StrToUpper(AC.GCI            )) return(AC_ID.GCI            );
                if (shortName == StrToUpper(AC.GFT            )) return(AC_ID.GFT            );
                if (shortName == StrToUpper(AC.GlobalPrime    )) return(AC_ID.GlobalPrime    );
                break;

      case 'H': break;

      case 'I': if (shortName == StrToUpper(AC.ICMarkets      )) return(AC_ID.ICMarkets      );
                if (shortName == StrToUpper(AC.InovaTrade     )) return(AC_ID.InovaTrade     );
                if (shortName == StrToUpper(AC.InvestorsEurope)) return(AC_ID.InvestorsEurope);
                break;

      case 'J': if (shortName == StrToUpper(AC.JFDBrokers     )) return(AC_ID.JFDBrokers     );
                break;

      case 'K': break;

      case 'L': if (shortName == StrToUpper(AC.LiteForex      )) return(AC_ID.LiteForex      );
                if (shortName == StrToUpper(AC.LondonCapital  )) return(AC_ID.LondonCapital  );
                break;

      case 'M': if (shortName == StrToUpper(AC.MBTrading      )) return(AC_ID.MBTrading      );
                if (shortName == StrToUpper(AC.MetaQuotes     )) return(AC_ID.MetaQuotes     );
                if (shortName == StrToUpper(AC.MIG            )) return(AC_ID.MIG            );
                break;

      case 'N': break;

      case 'O': if (shortName == StrToUpper(AC.Oanda          )) return(AC_ID.Oanda          );
                break;

      case 'P': if (shortName == StrToUpper(AC.Pepperstone    )) return(AC_ID.Pepperstone    );
                if (shortName == StrToUpper(AC.PrimeXM        )) return(AC_ID.PrimeXM        );
                break;

      case 'Q': break;
      case 'R': break;

      case 'S': if (shortName == StrToUpper(AC.SimpleTrader   )) return(AC_ID.SimpleTrader   );
                if (shortName == StrToUpper(AC.STS            )) return(AC_ID.STS            );
                break;

      case 'T': if (shortName == StrToUpper(AC.TeleTrade      )) return(AC_ID.TeleTrade      );
                if (shortName == StrToUpper(AC.TickMill       )) return(AC_ID.TickMill       );
                break;

      case 'U': break;
      case 'V': break;
      case 'W': break;

      case 'X': if (shortName == StrToUpper(AC.XTrade         )) return(AC_ID.XTrade         );
                break;

      case 'Y': break;
      case 'Z': break;
   }

   return(NULL);
}


/**
 * Gibt den Kurznamen der Firma mit der übergebenen Company-ID zurück.
 *
 * @param int id - Company-ID
 *
 * @return string - Kurzname oder Leerstring, falls die übergebene ID unbekannt ist
 */
string ShortAccountCompanyFromId(int id) {
   switch (id) {
      case AC_ID.Alpari         : return(AC.Alpari         );
      case AC_ID.APBG           : return(AC.APBG           );
      case AC_ID.ATCBrokers     : return(AC.ATCBrokers     );
      case AC_ID.AxiTrader      : return(AC.AxiTrader      );
      case AC_ID.BroCo          : return(AC.BroCo          );
      case AC_ID.CollectiveFX   : return(AC.CollectiveFX   );
      case AC_ID.Dukascopy      : return(AC.Dukascopy      );
      case AC_ID.EasyForex      : return(AC.EasyForex      );
      case AC_ID.FBCapital      : return(AC.FBCapital      );
      case AC_ID.FinFX          : return(AC.FinFX          );
      case AC_ID.ForexLtd       : return(AC.ForexLtd       );
      case AC_ID.FXPrimus       : return(AC.FXPrimus       );
      case AC_ID.FXDD           : return(AC.FXDD           );
      case AC_ID.FXOpen         : return(AC.FXOpen         );
      case AC_ID.FxPro          : return(AC.FxPro          );
      case AC_ID.Gallant        : return(AC.Gallant        );
      case AC_ID.GCI            : return(AC.GCI            );
      case AC_ID.GFT            : return(AC.GFT            );
      case AC_ID.GlobalPrime    : return(AC.GlobalPrime    );
      case AC_ID.ICMarkets      : return(AC.ICMarkets      );
      case AC_ID.InovaTrade     : return(AC.InovaTrade     );
      case AC_ID.InvestorsEurope: return(AC.InvestorsEurope);
      case AC_ID.JFDBrokers     : return(AC.JFDBrokers     );
      case AC_ID.LiteForex      : return(AC.LiteForex      );
      case AC_ID.LondonCapital  : return(AC.LondonCapital  );
      case AC_ID.MBTrading      : return(AC.MBTrading      );
      case AC_ID.MetaQuotes     : return(AC.MetaQuotes     );
      case AC_ID.MIG            : return(AC.MIG            );
      case AC_ID.Oanda          : return(AC.Oanda          );
      case AC_ID.Pepperstone    : return(AC.Pepperstone    );
      case AC_ID.PrimeXM        : return(AC.PrimeXM        );
      case AC_ID.SimpleTrader   : return(AC.SimpleTrader   );
      case AC_ID.STS            : return(AC.STS            );
      case AC_ID.TeleTrade      : return(AC.TeleTrade      );
      case AC_ID.TickMill       : return(AC.TickMill       );
      case AC_ID.XTrade         : return(AC.XTrade         );
   }
   return("");
}


/**
 * Ob der übergebene Wert einen bekannten Kurznamen einer AccountCompany darstellt.
 *
 * @param string value
 *
 * @return bool
 */
bool IsShortAccountCompany(string value) {
   return(AccountCompanyId(value) != 0);
}


/**
 * Gibt den Alias eines Accounts zurück.
 *
 * @param  string accountCompany
 * @param  int    accountNumber
 *
 * @return string - Alias oder Leerstring, falls der Account unbekannt ist
 */
string AccountAlias(string accountCompany, int accountNumber) {
   if (!StringLen(accountCompany)) return(_EMPTY_STR(catch("AccountAlias(1)  invalid parameter accountCompany = \"\"", ERR_INVALID_PARAMETER)));
   if (accountNumber <= 0)         return(_EMPTY_STR(catch("AccountAlias(2)  invalid parameter accountNumber = "+ accountNumber, ERR_INVALID_PARAMETER)));

   if (StrCompareI(accountCompany, AC.SimpleTrader)) {
      // SimpleTrader-Account
      switch (accountNumber) {
         case STA_ID.AlexProfit      : return(STA_ALIAS.AlexProfit      );
         case STA_ID.ASTA            : return(STA_ALIAS.ASTA            );
         case STA_ID.Caesar2         : return(STA_ALIAS.Caesar2         );
         case STA_ID.Caesar21        : return(STA_ALIAS.Caesar21        );
         case STA_ID.ConsistentProfit: return(STA_ALIAS.ConsistentProfit);
         case STA_ID.DayFox          : return(STA_ALIAS.DayFox          );
         case STA_ID.FXViper         : return(STA_ALIAS.FXViper         );
         case STA_ID.GCEdge          : return(STA_ALIAS.GCEdge          );
         case STA_ID.GoldStar        : return(STA_ALIAS.GoldStar        );
         case STA_ID.Kilimanjaro     : return(STA_ALIAS.Kilimanjaro     );
         case STA_ID.NovoLRfund      : return(STA_ALIAS.NovoLRfund      );
         case STA_ID.OverTrader      : return(STA_ALIAS.OverTrader      );
         case STA_ID.Ryan            : return(STA_ALIAS.Ryan            );
         case STA_ID.SmartScalper    : return(STA_ALIAS.SmartScalper    );
         case STA_ID.SmartTrader     : return(STA_ALIAS.SmartTrader     );
         case STA_ID.SteadyCapture   : return(STA_ALIAS.SteadyCapture   );
         case STA_ID.Twilight        : return(STA_ALIAS.Twilight        );
         case STA_ID.YenFortress     : return(STA_ALIAS.YenFortress     );
      }
   }
   else {
      // regulärer Account
      string section = "Accounts";
      string key     = accountNumber +".alias";
      string value   = GetGlobalConfigString(section, key);
      if (StringLen(value) > 0)
         return(value);
   }

   return("");
}


/**
 * Gibt die Account-Nummer eines Accounts anhand seines Aliasses zurück.
 *
 * @param  string accountCompany
 * @param  string accountAlias
 *
 * @return int - Account-Nummer oder NULL, falls der Account unbekannt ist oder ein Fehler auftrat
 */
int AccountNumberFromAlias(string accountCompany, string accountAlias) {
   if (!StringLen(accountCompany)) return(_NULL(catch("AccountNumberFromAlias(1)  invalid parameter accountCompany = \"\"", ERR_INVALID_PARAMETER)));
   if (!StringLen(accountAlias))   return(_NULL(catch("AccountNumberFromAlias(2)  invalid parameter accountAlias = \"\"", ERR_INVALID_PARAMETER)));

   if (StrCompareI(accountCompany, AC.SimpleTrader)) {
      // SimpleTrader-Account
      accountAlias = StrToLower(accountAlias);

      if (accountAlias == StrToLower(STA_ALIAS.AlexProfit      )) return(STA_ID.AlexProfit      );
      if (accountAlias == StrToLower(STA_ALIAS.ASTA            )) return(STA_ID.ASTA            );
      if (accountAlias == StrToLower(STA_ALIAS.Caesar2         )) return(STA_ID.Caesar2         );
      if (accountAlias == StrToLower(STA_ALIAS.Caesar21        )) return(STA_ID.Caesar21        );
      if (accountAlias == StrToLower(STA_ALIAS.ConsistentProfit)) return(STA_ID.ConsistentProfit);
      if (accountAlias == StrToLower(STA_ALIAS.DayFox          )) return(STA_ID.DayFox          );
      if (accountAlias == StrToLower(STA_ALIAS.FXViper         )) return(STA_ID.FXViper         );
      if (accountAlias == StrToLower(STA_ALIAS.GCEdge          )) return(STA_ID.GCEdge          );
      if (accountAlias == StrToLower(STA_ALIAS.GoldStar        )) return(STA_ID.GoldStar        );
      if (accountAlias == StrToLower(STA_ALIAS.Kilimanjaro     )) return(STA_ID.Kilimanjaro     );
      if (accountAlias == StrToLower(STA_ALIAS.NovoLRfund      )) return(STA_ID.NovoLRfund      );
      if (accountAlias == StrToLower(STA_ALIAS.OverTrader      )) return(STA_ID.OverTrader      );
      if (accountAlias == StrToLower(STA_ALIAS.Ryan            )) return(STA_ID.Ryan            );
      if (accountAlias == StrToLower(STA_ALIAS.SmartScalper    )) return(STA_ID.SmartScalper    );
      if (accountAlias == StrToLower(STA_ALIAS.SmartTrader     )) return(STA_ID.SmartTrader     );
      if (accountAlias == StrToLower(STA_ALIAS.SteadyCapture   )) return(STA_ID.SteadyCapture   );
      if (accountAlias == StrToLower(STA_ALIAS.Twilight        )) return(STA_ID.Twilight        );
      if (accountAlias == StrToLower(STA_ALIAS.YenFortress     )) return(STA_ID.YenFortress     );
   }
   else {
      // regulärer Account
      string file    = GetGlobalConfigPathA(); if (!StringLen(file)) return(NULL);
      string section = "Accounts";
      string keys[], value, sAccount;
      int keysSize = GetIniKeys(file, section, keys);

      for (int i=0; i < keysSize; i++) {
         if (StrEndsWithI(keys[i], ".alias")) {
            value = GetGlobalConfigString(section, keys[i]);
            if (StrCompareI(value, accountAlias)) {
               sAccount = StringTrimRight(StrLeft(keys[i], -6));
               value    = GetGlobalConfigString(section, sAccount +".company");
               if (StrCompareI(value, accountCompany)) {
                  if (StrIsDigit(sAccount))
                     return(StrToInteger(sAccount));
               }
            }
         }
      }
   }
   return(NULL);
}


/**
 * Vergleicht zwei Strings ohne Berücksichtigung von Groß-/Kleinschreibung.
 *
 * @param  string string1
 * @param  string string2
 *
 * @return bool
 */
bool StrCompareI(string string1, string string2) {
   int error = GetLastError();
   if (error != NO_ERROR) {
      if (error == ERR_NOT_INITIALIZED_STRING) {
         if (StrIsNull(string1)) return(StrIsNull(string2));
         if (StrIsNull(string2)) return(false);
      }
      catch("StrCompareI(1)", error);
   }
   return(StrToUpper(string1) == StrToUpper(string2));
}


/**
 * Prüft, ob ein String einen Substring enthält. Groß-/Kleinschreibung wird beachtet.
 *
 * @param  string value     - zu durchsuchender String
 * @param  string substring - zu suchender Substring
 *
 * @return bool
 */
bool StrContains(string value, string substring) {
   if (!StringLen(substring))
      return(!catch("StrContains()  illegal parameter substring = "+ DoubleQuoteStr(substring), ERR_INVALID_PARAMETER));
   return(StringFind(value, substring) != -1);
}


/**
 * Prüft, ob ein String einen Substring enthält. Groß-/Kleinschreibung wird nicht beachtet.
 *
 * @param  string value     - zu durchsuchender String
 * @param  string substring - zu suchender Substring
 *
 * @return bool
 */
bool StrContainsI(string value, string substring) {
   if (!StringLen(substring))
      return(!catch("StrContainsI()  illegal parameter substring = "+ DoubleQuoteStr(substring), ERR_INVALID_PARAMETER));
   return(StringFind(StrToUpper(value), StrToUpper(substring)) != -1);
}


/**
 * Durchsucht einen String vom Ende aus nach einem Substring und gibt dessen Position zurück.
 *
 * @param  string value  - zu durchsuchender String
 * @param  string search - zu suchender Substring
 *
 * @return int - letzte Position des Substrings oder -1, wenn der Substring nicht gefunden wurde
 */
int StrFindR(string value, string search) {
   int lenValue  = StringLen(value),
       lastFound = -1,
       result    =  0;

   for (int i=0; i < lenValue; i++) {
      result = StringFind(value, search, i);
      if (result == -1)
         break;
      lastFound = result;
   }
   return(lastFound);
}


/**
 * Konvertiert eine Farbe in ihre HTML-Repräsentation.
 *
 * @param  color value
 *
 * @return string - HTML-Farbwert
 *
 * Beispiel: ColorToHtmlStr(C'255,255,255') => "#FFFFFF"
 */
string ColorToHtmlStr(color value) {
   int red   = value & 0x0000FF;
   int green = value & 0x00FF00;
   int blue  = value & 0xFF0000;

   int iValue = red<<16 + green + blue>>16;   // rot und blau vertauschen, um IntToHexStr() benutzen zu können

   return(StringConcatenate("#", StrRight(IntToHexStr(iValue), 6)));
}


/**
 * Konvertiert eine Farbe in ihre MQL-String-Repräsentation, z.B. "Red" oder "0,255,255".
 *
 * @param  color value
 *
 * @return string - MQL-Farbcode oder RGB-String, falls der übergebene Wert kein bekannter MQL-Farbcode ist.
 */
string ColorToStr(color value) {
   if (value == 0xFF000000)                                          // aus CLR_NONE = 0xFFFFFFFF macht das Terminal nach Recompilation oder Deserialisierung
      value = CLR_NONE;                                              // u.U. 0xFF000000 (entspricht Schwarz)
   if (value < CLR_NONE || value > C'255,255,255')
      return(_EMPTY_STR(catch("ColorToStr(1)  invalid parameter value: "+ value +" (not a color)", ERR_INVALID_PARAMETER)));

   if (value == CLR_NONE) return("CLR_NONE"         );
   if (value == 0xFFF8F0) return("AliceBlue"        );
   if (value == 0xD7EBFA) return("AntiqueWhite"     );
   if (value == 0xFFFF00) return("Aqua"             );
   if (value == 0xD4FF7F) return("Aquamarine"       );
   if (value == 0xDCF5F5) return("Beige"            );
   if (value == 0xC4E4FF) return("Bisque"           );
   if (value == 0x000000) return("Black"            );
   if (value == 0xCDEBFF) return("BlanchedAlmond"   );
   if (value == 0xFF0000) return("Blue"             );
   if (value == 0xE22B8A) return("BlueViolet"       );
   if (value == 0x2A2AA5) return("Brown"            );
   if (value == 0x87B8DE) return("BurlyWood"        );
   if (value == 0xA09E5F) return("CadetBlue"        );
   if (value == 0x00FF7F) return("Chartreuse"       );
   if (value == 0x1E69D2) return("Chocolate"        );
   if (value == 0x507FFF) return("Coral"            );
   if (value == 0xED9564) return("CornflowerBlue"   );
   if (value == 0xDCF8FF) return("Cornsilk"         );
   if (value == 0x3C14DC) return("Crimson"          );
   if (value == 0x8B0000) return("DarkBlue"         );
   if (value == 0x0B86B8) return("DarkGoldenrod"    );
   if (value == 0xA9A9A9) return("DarkGray"         );
   if (value == 0x006400) return("DarkGreen"        );
   if (value == 0x6BB7BD) return("DarkKhaki"        );
   if (value == 0x2F6B55) return("DarkOliveGreen"   );
   if (value == 0x008CFF) return("DarkOrange"       );
   if (value == 0xCC3299) return("DarkOrchid"       );
   if (value == 0x7A96E9) return("DarkSalmon"       );
   if (value == 0x8BBC8F) return("DarkSeaGreen"     );
   if (value == 0x8B3D48) return("DarkSlateBlue"    );
   if (value == 0x4F4F2F) return("DarkSlateGray"    );
   if (value == 0xD1CE00) return("DarkTurquoise"    );
   if (value == 0xD30094) return("DarkViolet"       );
   if (value == 0x9314FF) return("DeepPink"         );
   if (value == 0xFFBF00) return("DeepSkyBlue"      );
   if (value == 0x696969) return("DimGray"          );
   if (value == 0xFF901E) return("DodgerBlue"       );
   if (value == 0x2222B2) return("FireBrick"        );
   if (value == 0x228B22) return("ForestGreen"      );
   if (value == 0xDCDCDC) return("Gainsboro"        );
   if (value == 0x00D7FF) return("Gold"             );
   if (value == 0x20A5DA) return("Goldenrod"        );
   if (value == 0x808080) return("Gray"             );
   if (value == 0x008000) return("Green"            );
   if (value == 0x2FFFAD) return("GreenYellow"      );
   if (value == 0xF0FFF0) return("Honeydew"         );
   if (value == 0xB469FF) return("HotPink"          );
   if (value == 0x5C5CCD) return("IndianRed"        );
   if (value == 0x82004B) return("Indigo"           );
   if (value == 0xF0FFFF) return("Ivory"            );
   if (value == 0x8CE6F0) return("Khaki"            );
   if (value == 0xFAE6E6) return("Lavender"         );
   if (value == 0xF5F0FF) return("LavenderBlush"    );
   if (value == 0x00FC7C) return("LawnGreen"        );
   if (value == 0xCDFAFF) return("LemonChiffon"     );
   if (value == 0xE6D8AD) return("LightBlue"        );
   if (value == 0x8080F0) return("LightCoral"       );
   if (value == 0xFFFFE0) return("LightCyan"        );
   if (value == 0xD2FAFA) return("LightGoldenrod"   );
   if (value == 0xD3D3D3) return("LightGray"        );
   if (value == 0x90EE90) return("LightGreen"       );
   if (value == 0xC1B6FF) return("LightPink"        );
   if (value == 0x7AA0FF) return("LightSalmon"      );
   if (value == 0xAAB220) return("LightSeaGreen"    );
   if (value == 0xFACE87) return("LightSkyBlue"     );
   if (value == 0x998877) return("LightSlateGray"   );
   if (value == 0xDEC4B0) return("LightSteelBlue"   );
   if (value == 0xE0FFFF) return("LightYellow"      );
   if (value == 0x00FF00) return("Lime"             );
   if (value == 0x32CD32) return("LimeGreen"        );
   if (value == 0xE6F0FA) return("Linen"            );
   if (value == 0xFF00FF) return("Magenta"          );
   if (value == 0x000080) return("Maroon"           );
   if (value == 0xAACD66) return("MediumAquamarine" );
   if (value == 0xCD0000) return("MediumBlue"       );
   if (value == 0xD355BA) return("MediumOrchid"     );
   if (value == 0xDB7093) return("MediumPurple"     );
   if (value == 0x71B33C) return("MediumSeaGreen"   );
   if (value == 0xEE687B) return("MediumSlateBlue"  );
   if (value == 0x9AFA00) return("MediumSpringGreen");
   if (value == 0xCCD148) return("MediumTurquoise"  );
   if (value == 0x8515C7) return("MediumVioletRed"  );
   if (value == 0x701919) return("MidnightBlue"     );
   if (value == 0xFAFFF5) return("MintCream"        );
   if (value == 0xE1E4FF) return("MistyRose"        );
   if (value == 0xB5E4FF) return("Moccasin"         );
   if (value == 0xADDEFF) return("NavajoWhite"      );
   if (value == 0x800000) return("Navy"             );
   if (value == 0xE6F5FD) return("OldLace"          );
   if (value == 0x008080) return("Olive"            );
   if (value == 0x238E6B) return("OliveDrab"        );
   if (value == 0x00A5FF) return("Orange"           );
   if (value == 0x0045FF) return("OrangeRed"        );
   if (value == 0xD670DA) return("Orchid"           );
   if (value == 0xAAE8EE) return("PaleGoldenrod"    );
   if (value == 0x98FB98) return("PaleGreen"        );
   if (value == 0xEEEEAF) return("PaleTurquoise"    );
   if (value == 0x9370DB) return("PaleVioletRed"    );
   if (value == 0xD5EFFF) return("PapayaWhip"       );
   if (value == 0xB9DAFF) return("PeachPuff"        );
   if (value == 0x3F85CD) return("Peru"             );
   if (value == 0xCBC0FF) return("Pink"             );
   if (value == 0xDDA0DD) return("Plum"             );
   if (value == 0xE6E0B0) return("PowderBlue"       );
   if (value == 0x800080) return("Purple"           );
   if (value == 0x0000FF) return("Red"              );
   if (value == 0x8F8FBC) return("RosyBrown"        );
   if (value == 0xE16941) return("RoyalBlue"        );
   if (value == 0x13458B) return("SaddleBrown"      );
   if (value == 0x7280FA) return("Salmon"           );
   if (value == 0x60A4F4) return("SandyBrown"       );
   if (value == 0x578B2E) return("SeaGreen"         );
   if (value == 0xEEF5FF) return("Seashell"         );
   if (value == 0x2D52A0) return("Sienna"           );
   if (value == 0xC0C0C0) return("Silver"           );
   if (value == 0xEBCE87) return("SkyBlue"          );
   if (value == 0xCD5A6A) return("SlateBlue"        );
   if (value == 0x908070) return("SlateGray"        );
   if (value == 0xFAFAFF) return("Snow"             );
   if (value == 0x7FFF00) return("SpringGreen"      );
   if (value == 0xB48246) return("SteelBlue"        );
   if (value == 0x8CB4D2) return("Tan"              );
   if (value == 0x808000) return("Teal"             );
   if (value == 0xD8BFD8) return("Thistle"          );
   if (value == 0x4763FF) return("Tomato"           );
   if (value == 0xD0E040) return("Turquoise"        );
   if (value == 0xEE82EE) return("Violet"           );
   if (value == 0xB3DEF5) return("Wheat"            );
   if (value == 0xFFFFFF) return("White"            );
   if (value == 0xF5F5F5) return("WhiteSmoke"       );
   if (value == 0x00FFFF) return("Yellow"           );
   if (value == 0x32CD9A) return("YellowGreen"      );

   return(ColorToRGBStr(value));
}


/**
 * Convert a MQL color value to its RGB string representation.
 *
 * @param  color value
 *
 * @return string
 */
string ColorToRGBStr(color value) {
   int red   = value       & 0xFF;
   int green = value >>  8 & 0xFF;
   int blue  = value >> 16 & 0xFF;
   return(StringConcatenate(red, ",", green, ",", blue));
}


/**
 * Convert a RGB color triplet to a numeric color value.
 *
 * @param  string value - RGB color triplet, e.g. "100,150,225"
 *
 * @return color - color or NaC (Not-a-Color) in case of errors
 */
color RGBStrToColor(string value) {
   if (!StringLen(value))
      return(NaC);

   string sValues[];
   if (Explode(value, ",", sValues, NULL) != 3)
      return(NaC);

   sValues[0] = StrTrim(sValues[0]); if (!StrIsDigit(sValues[0])) return(NaC);
   sValues[1] = StrTrim(sValues[1]); if (!StrIsDigit(sValues[1])) return(NaC);
   sValues[2] = StrTrim(sValues[2]); if (!StrIsDigit(sValues[2])) return(NaC);

   int r = StrToInteger(sValues[0]); if (r & 0xFFFF00 && 1) return(NaC);
   int g = StrToInteger(sValues[1]); if (g & 0xFFFF00 && 1) return(NaC);
   int b = StrToInteger(sValues[2]); if (b & 0xFFFF00 && 1) return(NaC);

   return(r + (g<<8) + (b<<16));
}


/**
 * Convert a web color name to a numeric color value.
 *
 * @param  string name - web color name
 *
 * @return color - color value or NaC (Not-a-Color) in case of errors
 */
color NameToColor(string name) {
   if (!StringLen(name))
      return(NaC);

   name = StrToLower(name);
   if (StrStartsWith(name, "clr"))
      name = StrSubstr(name, 3);

   if (name == "none"             ) return(CLR_NONE         );
   if (name == "aliceblue"        ) return(AliceBlue        );
   if (name == "antiquewhite"     ) return(AntiqueWhite     );
   if (name == "aqua"             ) return(Aqua             );
   if (name == "aquamarine"       ) return(Aquamarine       );
   if (name == "beige"            ) return(Beige            );
   if (name == "bisque"           ) return(Bisque           );
   if (name == "black"            ) return(Black            );
   if (name == "blanchedalmond"   ) return(BlanchedAlmond   );
   if (name == "blue"             ) return(Blue             );
   if (name == "blueviolet"       ) return(BlueViolet       );
   if (name == "brown"            ) return(Brown            );
   if (name == "burlywood"        ) return(BurlyWood        );
   if (name == "cadetblue"        ) return(CadetBlue        );
   if (name == "chartreuse"       ) return(Chartreuse       );
   if (name == "chocolate"        ) return(Chocolate        );
   if (name == "coral"            ) return(Coral            );
   if (name == "cornflowerblue"   ) return(CornflowerBlue   );
   if (name == "cornsilk"         ) return(Cornsilk         );
   if (name == "crimson"          ) return(Crimson          );
   if (name == "darkblue"         ) return(DarkBlue         );
   if (name == "darkgoldenrod"    ) return(DarkGoldenrod    );
   if (name == "darkgray"         ) return(DarkGray         );
   if (name == "darkgreen"        ) return(DarkGreen        );
   if (name == "darkkhaki"        ) return(DarkKhaki        );
   if (name == "darkolivegreen"   ) return(DarkOliveGreen   );
   if (name == "darkorange"       ) return(DarkOrange       );
   if (name == "darkorchid"       ) return(DarkOrchid       );
   if (name == "darksalmon"       ) return(DarkSalmon       );
   if (name == "darkseagreen"     ) return(DarkSeaGreen     );
   if (name == "darkslateblue"    ) return(DarkSlateBlue    );
   if (name == "darkslategray"    ) return(DarkSlateGray    );
   if (name == "darkturquoise"    ) return(DarkTurquoise    );
   if (name == "darkviolet"       ) return(DarkViolet       );
   if (name == "deeppink"         ) return(DeepPink         );
   if (name == "deepskyblue"      ) return(DeepSkyBlue      );
   if (name == "dimgray"          ) return(DimGray          );
   if (name == "dodgerblue"       ) return(DodgerBlue       );
   if (name == "firebrick"        ) return(FireBrick        );
   if (name == "forestgreen"      ) return(ForestGreen      );
   if (name == "gainsboro"        ) return(Gainsboro        );
   if (name == "gold"             ) return(Gold             );
   if (name == "goldenrod"        ) return(Goldenrod        );
   if (name == "gray"             ) return(Gray             );
   if (name == "green"            ) return(Green            );
   if (name == "greenyellow"      ) return(GreenYellow      );
   if (name == "honeydew"         ) return(Honeydew         );
   if (name == "hotpink"          ) return(HotPink          );
   if (name == "indianred"        ) return(IndianRed        );
   if (name == "indigo"           ) return(Indigo           );
   if (name == "ivory"            ) return(Ivory            );
   if (name == "khaki"            ) return(Khaki            );
   if (name == "lavender"         ) return(Lavender         );
   if (name == "lavenderblush"    ) return(LavenderBlush    );
   if (name == "lawngreen"        ) return(LawnGreen        );
   if (name == "lemonchiffon"     ) return(LemonChiffon     );
   if (name == "lightblue"        ) return(LightBlue        );
   if (name == "lightcoral"       ) return(LightCoral       );
   if (name == "lightcyan"        ) return(LightCyan        );
   if (name == "lightgoldenrod"   ) return(LightGoldenrod   );
   if (name == "lightgray"        ) return(LightGray        );
   if (name == "lightgreen"       ) return(LightGreen       );
   if (name == "lightpink"        ) return(LightPink        );
   if (name == "lightsalmon"      ) return(LightSalmon      );
   if (name == "lightseagreen"    ) return(LightSeaGreen    );
   if (name == "lightskyblue"     ) return(LightSkyBlue     );
   if (name == "lightslategray"   ) return(LightSlateGray   );
   if (name == "lightsteelblue"   ) return(LightSteelBlue   );
   if (name == "lightyellow"      ) return(LightYellow      );
   if (name == "lime"             ) return(Lime             );
   if (name == "limegreen"        ) return(LimeGreen        );
   if (name == "linen"            ) return(Linen            );
   if (name == "magenta"          ) return(Magenta          );
   if (name == "maroon"           ) return(Maroon           );
   if (name == "mediumaquamarine" ) return(MediumAquamarine );
   if (name == "mediumblue"       ) return(MediumBlue       );
   if (name == "mediumorchid"     ) return(MediumOrchid     );
   if (name == "mediumpurple"     ) return(MediumPurple     );
   if (name == "mediumseagreen"   ) return(MediumSeaGreen   );
   if (name == "mediumslateblue"  ) return(MediumSlateBlue  );
   if (name == "mediumspringgreen") return(MediumSpringGreen);
   if (name == "mediumturquoise"  ) return(MediumTurquoise  );
   if (name == "mediumvioletred"  ) return(MediumVioletRed  );
   if (name == "midnightblue"     ) return(MidnightBlue     );
   if (name == "mintcream"        ) return(MintCream        );
   if (name == "mistyrose"        ) return(MistyRose        );
   if (name == "moccasin"         ) return(Moccasin         );
   if (name == "navajowhite"      ) return(NavajoWhite      );
   if (name == "navy"             ) return(Navy             );
   if (name == "oldlace"          ) return(OldLace          );
   if (name == "olive"            ) return(Olive            );
   if (name == "olivedrab"        ) return(OliveDrab        );
   if (name == "orange"           ) return(Orange           );
   if (name == "orangered"        ) return(OrangeRed        );
   if (name == "orchid"           ) return(Orchid           );
   if (name == "palegoldenrod"    ) return(PaleGoldenrod    );
   if (name == "palegreen"        ) return(PaleGreen        );
   if (name == "paleturquoise"    ) return(PaleTurquoise    );
   if (name == "palevioletred"    ) return(PaleVioletRed    );
   if (name == "papayawhip"       ) return(PapayaWhip       );
   if (name == "peachpuff"        ) return(PeachPuff        );
   if (name == "peru"             ) return(Peru             );
   if (name == "pink"             ) return(Pink             );
   if (name == "plum"             ) return(Plum             );
   if (name == "powderblue"       ) return(PowderBlue       );
   if (name == "purple"           ) return(Purple           );
   if (name == "red"              ) return(Red              );
   if (name == "rosybrown"        ) return(RosyBrown        );
   if (name == "royalblue"        ) return(RoyalBlue        );
   if (name == "saddlebrown"      ) return(SaddleBrown      );
   if (name == "salmon"           ) return(Salmon           );
   if (name == "sandybrown"       ) return(SandyBrown       );
   if (name == "seagreen"         ) return(SeaGreen         );
   if (name == "seashell"         ) return(Seashell         );
   if (name == "sienna"           ) return(Sienna           );
   if (name == "silver"           ) return(Silver           );
   if (name == "skyblue"          ) return(SkyBlue          );
   if (name == "slateblue"        ) return(SlateBlue        );
   if (name == "slategray"        ) return(SlateGray        );
   if (name == "snow"             ) return(Snow             );
   if (name == "springgreen"      ) return(SpringGreen      );
   if (name == "steelblue"        ) return(SteelBlue        );
   if (name == "tan"              ) return(Tan              );
   if (name == "teal"             ) return(Teal             );
   if (name == "thistle"          ) return(Thistle          );
   if (name == "tomato"           ) return(Tomato           );
   if (name == "turquoise"        ) return(Turquoise        );
   if (name == "violet"           ) return(Violet           );
   if (name == "wheat"            ) return(Wheat            );
   if (name == "white"            ) return(White            );
   if (name == "whitesmoke"       ) return(WhiteSmoke       );
   if (name == "yellow"           ) return(Yellow           );
   if (name == "yellowgreen"      ) return(YellowGreen      );

   return(NaC);
}


/**
 * Repeats a string.
 *
 * @param  string input - The string to be repeated.
 * @param  int    times - Number of times the input string should be repeated.
 *
 * @return string - the repeated string
 */
string StrRepeat(string input, int times) {
   if (times < 0)
      return(_EMPTY_STR(catch("StrRepeat(1)  invalid parameter times = "+ times, ERR_INVALID_PARAMETER)));

   if (times ==  0)       return("");
   if (!StringLen(input)) return("");

   string output = input;
   for (int i=1; i < times; i++) {
      output = StringConcatenate(output, input);
   }
   return(output);
}


/**
 * Gibt die eindeutige ID einer Währung zurück.
 *
 * @param  string currency - 3-stelliger Währungsbezeichner
 *
 * @return int - Currency-ID oder 0, falls ein Fehler auftrat
 */
int GetCurrencyId(string currency) {
   string value = StrToUpper(currency);

   if (value == C_AUD) return(CID_AUD);
   if (value == C_CAD) return(CID_CAD);
   if (value == C_CHF) return(CID_CHF);
   if (value == C_CNY) return(CID_CNY);
   if (value == C_CZK) return(CID_CZK);
   if (value == C_DKK) return(CID_DKK);
   if (value == C_EUR) return(CID_EUR);
   if (value == C_GBP) return(CID_GBP);
   if (value == C_HKD) return(CID_HKD);
   if (value == C_HRK) return(CID_HRK);
   if (value == C_HUF) return(CID_HUF);
   if (value == C_INR) return(CID_INR);
   if (value == C_JPY) return(CID_JPY);
   if (value == C_LTL) return(CID_LTL);
   if (value == C_LVL) return(CID_LVL);
   if (value == C_MXN) return(CID_MXN);
   if (value == C_NOK) return(CID_NOK);
   if (value == C_NZD) return(CID_NZD);
   if (value == C_PLN) return(CID_PLN);
   if (value == C_RUB) return(CID_RUB);
   if (value == C_SAR) return(CID_SAR);
   if (value == C_SEK) return(CID_SEK);
   if (value == C_SGD) return(CID_SGD);
   if (value == C_THB) return(CID_THB);
   if (value == C_TRY) return(CID_TRY);
   if (value == C_TWD) return(CID_TWD);
   if (value == C_USD) return(CID_USD);
   if (value == C_ZAR) return(CID_ZAR);

   return(_NULL(catch("GetCurrencyId(1)  unknown currency = \""+ currency +"\"", ERR_RUNTIME_ERROR)));
}


/**
 * Gibt den 3-stelligen Bezeichner einer Währungs-ID zurück.
 *
 * @param  int id - Währungs-ID
 *
 * @return string - Währungsbezeichner
 */
string GetCurrency(int id) {
   switch (id) {
      case CID_AUD: return(C_AUD);
      case CID_CAD: return(C_CAD);
      case CID_CHF: return(C_CHF);
      case CID_CNY: return(C_CNY);
      case CID_CZK: return(C_CZK);
      case CID_DKK: return(C_DKK);
      case CID_EUR: return(C_EUR);
      case CID_GBP: return(C_GBP);
      case CID_HKD: return(C_HKD);
      case CID_HRK: return(C_HRK);
      case CID_HUF: return(C_HUF);
      case CID_INR: return(C_INR);
      case CID_JPY: return(C_JPY);
      case CID_LTL: return(C_LTL);
      case CID_LVL: return(C_LVL);
      case CID_MXN: return(C_MXN);
      case CID_NOK: return(C_NOK);
      case CID_NZD: return(C_NZD);
      case CID_PLN: return(C_PLN);
      case CID_RUB: return(C_RUB);
      case CID_SAR: return(C_SAR);
      case CID_SEK: return(C_SEK);
      case CID_SGD: return(C_SGD);
      case CID_THB: return(C_THB);
      case CID_TRY: return(C_TRY);
      case CID_TWD: return(C_TWD);
      case CID_USD: return(C_USD);
      case CID_ZAR: return(C_ZAR);
   }
   return(_EMPTY_STR(catch("GetCurrency(1)  unknown currency id = "+ id, ERR_RUNTIME_ERROR)));
}


/**
 * Ob ein String einen gültigen Währungsbezeichner darstellt.
 *
 * @param  string value - Wert
 *
 * @return bool
 */
bool IsCurrency(string value) {
   value = StrToUpper(value);

   if (value == C_AUD) return(true);
   if (value == C_CAD) return(true);
   if (value == C_CHF) return(true);
   if (value == C_CNY) return(true);
   if (value == C_CZK) return(true);
   if (value == C_DKK) return(true);
   if (value == C_EUR) return(true);
   if (value == C_GBP) return(true);
   if (value == C_HKD) return(true);
   if (value == C_HRK) return(true);
   if (value == C_HUF) return(true);
   if (value == C_INR) return(true);
   if (value == C_JPY) return(true);
   if (value == C_LTL) return(true);
   if (value == C_LVL) return(true);
   if (value == C_MXN) return(true);
   if (value == C_NOK) return(true);
   if (value == C_NZD) return(true);
   if (value == C_PLN) return(true);
   if (value == C_RUB) return(true);
   if (value == C_SAR) return(true);
   if (value == C_SEK) return(true);
   if (value == C_SGD) return(true);
   if (value == C_THB) return(true);
   if (value == C_TRY) return(true);
   if (value == C_TWD) return(true);
   if (value == C_USD) return(true);
   if (value == C_ZAR) return(true);

   return(false);
}


/**
 * Whether the specified value is an order type.
 *
 * @param  int value
 *
 * @return bool
 */
bool IsOrderType(int value) {
   switch (value) {
      case OP_BUY      :
      case OP_SELL     :
      case OP_BUYLIMIT :
      case OP_SELLLIMIT:
      case OP_BUYSTOP  :
      case OP_SELLSTOP :
         return(true);
   }
   return(false);
}


/**
 * Whether the specified value is a pendingg order type.
 *
 * @param  int value
 *
 * @return bool
 */
bool IsPendingOrderType(int value) {
   switch (value) {
      case OP_BUYLIMIT :
      case OP_SELLLIMIT:
      case OP_BUYSTOP  :
      case OP_SELLSTOP :
         return(true);
   }
   return(false);
}


/**
 * Whether the specified value is a long order type.
 *
 * @param  int value
 *
 * @return bool
 */
bool IsLongOrderType(int value) {
   switch (value) {
      case OP_BUY     :
      case OP_BUYLIMIT:
      case OP_BUYSTOP :
         return(true);
   }
   return(false);
}


/**
 * Whether the specified value is a short order type.
 *
 * @param  int value
 *
 * @return bool
 */
bool IsShortOrderType(int value) {
   switch (value) {
      case OP_SELL     :
      case OP_SELLLIMIT:
      case OP_SELLSTOP :
         return(true);
   }
   return(false);
}


/**
 * Whether the specified value is a stop order type.
 *
 * @param  int value
 *
 * @return bool
 */
bool IsStopOrderType(int value) {
   return(value==OP_BUYSTOP || value==OP_SELLSTOP);
}


/**
 * Whether the specified value is a limit order type.
 *
 * @param  int value
 *
 * @return bool
 */
bool IsLimitOrderType(int value) {
   return(value==OP_BUYLIMIT || value==OP_SELLLIMIT);
}


/**
 * Return a human-readable form of a MessageBox push button id.
 *
 * @param  int id - button id
 *
 * @return string
 */
string MessageBoxButtonToStr(int id) {
   switch (id) {
      case IDABORT   : return("IDABORT"   );
      case IDCANCEL  : return("IDCANCEL"  );
      case IDCONTINUE: return("IDCONTINUE");
      case IDIGNORE  : return("IDIGNORE"  );
      case IDNO      : return("IDNO"      );
      case IDOK      : return("IDOK"      );
      case IDRETRY   : return("IDRETRY"   );
      case IDTRYAGAIN: return("IDTRYAGAIN");
      case IDYES     : return("IDYES"     );
      case IDCLOSE   : return("IDCLOSE"   );
      case IDHELP    : return("IDHELP"    );
   }
   return(_EMPTY_STR(catch("MessageBoxButtonToStr(1)  unknown message box button = "+ id, ERR_RUNTIME_ERROR)));
}


/**
 * Gibt den Integer-Wert eines OperationType-Bezeichners zurück.
 *
 * @param  string value
 *
 * @return int - OperationType-Code oder -1, wenn der Bezeichner ungültig ist (OP_UNDEFINED)
 */
int StrToOperationType(string value) {
   string str = StrToUpper(StrTrim(value));

   if (StringLen(str) == 1) {
      switch (StrToInteger(str)) {
         case OP_BUY      :
            if (str == "0")    return(OP_BUY      ); break;          // OP_BUY = 0: Sonderfall
         case OP_SELL     :    return(OP_SELL     );
         case OP_BUYLIMIT :    return(OP_BUYLIMIT );
         case OP_SELLLIMIT:    return(OP_SELLLIMIT);
         case OP_BUYSTOP  :    return(OP_BUYSTOP  );
         case OP_SELLSTOP :    return(OP_SELLSTOP );
         case OP_BALANCE  :    return(OP_BALANCE  );
         case OP_CREDIT   :    return(OP_CREDIT   );
      }
   }
   else {
      if (StrStartsWith(str, "OP_"))
         str = StrSubstr(str, 3);
      if (str == "BUY"       ) return(OP_BUY      );
      if (str == "SELL"      ) return(OP_SELL     );
      if (str == "BUYLIMIT"  ) return(OP_BUYLIMIT );
      if (str == "BUY LIMIT" ) return(OP_BUYLIMIT );
      if (str == "SELLLIMIT" ) return(OP_SELLLIMIT);
      if (str == "SELL LIMIT") return(OP_SELLLIMIT);
      if (str == "BUYSTOP"   ) return(OP_BUYSTOP  );
      if (str == "STOP BUY"  ) return(OP_BUYSTOP  );
      if (str == "SELLSTOP"  ) return(OP_SELLSTOP );
      if (str == "STOP SELL" ) return(OP_SELLSTOP );
      if (str == "BALANCE"   ) return(OP_BALANCE  );
      if (str == "CREDIT"    ) return(OP_CREDIT   );
   }

   if (__LOG()) log("StrToOperationType(1)  invalid parameter value = \""+ value +"\" (not an operation type)", ERR_INVALID_PARAMETER);
   return(OP_UNDEFINED);
}


/**
 * Return the integer constant of a trade direction identifier.
 *
 * @param  string value     - trade directions: [TRADE_DIRECTION_][LONG|SHORT|BOTH]
 * @param  int    execFlags - execution control: error flags to set silently (default: none)
 *
 * @return int - trade direction constant or -1 (EMPTY) if the value is not recognized
 */
int StrToTradeDirection(string value, int execFlags=NULL) {
   string str = StrToUpper(StrTrim(value));

   if (StrStartsWith(str, "TRADE_DIRECTION_"))
      str = StrSubstr(str, 17);

   if (str ==                    "LONG" ) return(TRADE_DIRECTION_LONG);
   if (str == ""+ TRADE_DIRECTION_LONG  ) return(TRADE_DIRECTION_LONG);

   if (str ==                    "SHORT") return(TRADE_DIRECTION_SHORT);
   if (str == ""+ TRADE_DIRECTION_SHORT ) return(TRADE_DIRECTION_SHORT);

   if (str ==                    "BOTH" ) return(TRADE_DIRECTION_BOTH);
   if (str == ""+ TRADE_DIRECTION_BOTH  ) return(TRADE_DIRECTION_BOTH);

   if (!execFlags & F_ERR_INVALID_PARAMETER) return(_EMPTY(catch("StrToTradeDirection(1)  invalid parameter value = "+ DoubleQuoteStr(value), ERR_INVALID_PARAMETER)));
   else                                      return(_EMPTY(SetLastError(ERR_INVALID_PARAMETER)));
}


/**
 * Return a readable version of a trade command.
 *
 * @param  int cmd - trade command
 *
 * @return string
 */
string TradeCommandToStr(int cmd) {
   switch (cmd) {
      case TC_LFX_ORDER_CREATE : return("TC_LFX_ORDER_CREATE" );
      case TC_LFX_ORDER_OPEN   : return("TC_LFX_ORDER_OPEN"   );
      case TC_LFX_ORDER_CLOSE  : return("TC_LFX_ORDER_CLOSE"  );
      case TC_LFX_ORDER_CLOSEBY: return("TC_LFX_ORDER_CLOSEBY");
      case TC_LFX_ORDER_HEDGE  : return("TC_LFX_ORDER_HEDGE"  );
      case TC_LFX_ORDER_MODIFY : return("TC_LFX_ORDER_MODIFY" );
      case TC_LFX_ORDER_DELETE : return("TC_LFX_ORDER_DELETE" );
   }
   return(_EMPTY_STR(catch("TradeCommandToStr(1)  invalid parameter cmd = "+ cmd +" (not a trade command )", ERR_INVALID_PARAMETER)));
}


/**
 * Formatiert einen numerischen Wert im angegebenen Format und gibt den resultierenden String zurück.
 * The basic mask is "n" or "n.d" where n is the number of digits to the left and d is the number of digits to the right of
 * the decimal point.
 *
 * Mask parameters:
 *
 *   n        = number of digits to the left of the decimal point, e.g. NumberToStr(123.456, "5") => "123"
 *   n.d      = number of left and right digits, e.g. NumberToStr(123.456, "5.2") => "123.45"
 *   n.       = number of left and all right digits, e.g. NumberToStr(123.456, "2.") => "23.456"
 *    .d      = all left and number of right digits, e.g. NumberToStr(123.456, ".2") => "123.45"
 *    .d'     = all left and number of right digits plus 1 additional subpip digit,
 *              e.g. NumberToStr(123.45678, ".4'") => "123.4567'8"
 *    .d+     = + anywhere right of .d in mask: all left and minimum number of right digits,
 *              e.g. NumberToStr(123.456, ".2+") => "123.456"
 *  +n.d      = + anywhere left of n. in mask: plus sign for positive values
 *    R       = round result in the last displayed digit,
 *              e.g. NumberToStr(123.456, "R3.2") => "123.46" or NumberToStr(123.7, "R3") => "124"
 *    ;       = Separatoren tauschen (Europäisches Format), e.g. NumberToStr(123456.789, "6.2;") => "123456,78"
 *    ,       = Tausender-Separatoren einfügen, e.g. NumberToStr(123456.789, "6.2,") => "123,456.78"
 *    ,<char> = Tausender-Separatoren einfügen und auf <char> setzen, e.g. NumberToStr(123456.789, ", 6.2") => "123 456.78"
 *
 * @param  double value
 * @param  string mask
 *
 * @return string - formatierter Wert
 */
string NumberToStr(double value, string mask) {
   string sNumber = value;
   if (StringGetChar(sNumber, 3) == '#')                             // "-1.#IND0000" => NaN
      return(sNumber);                                               // "-1.#INF0000" => Infinite


   // --- Beginn Maske parsen -------------------------
   int maskLen = StringLen(mask);

   // zu allererst Separatorenformat erkennen
   bool swapSeparators = (StringFind(mask, ";") > -1);
      string sepThousand=",", sepDecimal=".";
      if (swapSeparators) {
         sepThousand = ".";
         sepDecimal  = ",";
      }
      int sepPos = StringFind(mask, ",");
   bool separators = (sepPos > -1);
      if (separators) /*&&*/ if (sepPos+1 < maskLen) {
         sepThousand = StringSubstr(mask, sepPos+1, 1);  // user-spezifischen 1000-Separator auslesen und aus Maske löschen
         mask        = StringConcatenate(StringSubstr(mask, 0, sepPos+1), StringSubstr(mask, sepPos+2));
      }

   // white space entfernen
   mask    = StrReplace(mask, " ", "");
   maskLen = StringLen(mask);

   // Position des Dezimalpunktes
   int  dotPos   = StringFind(mask, ".");
   bool dotGiven = (dotPos > -1);
   if (!dotGiven)
      dotPos = maskLen;

   // Anzahl der linken Stellen
   int char, nLeft;
   bool nDigit;
   for (int i=0; i < dotPos; i++) {
      char = StringGetChar(mask, i);
      if ('0' <= char) /*&&*/ if (char <= '9') {
         nLeft = 10*nLeft + char-'0';
         nDigit = true;
      }
   }
   if (!nDigit) nLeft = -1;

   // Anzahl der rechten Stellen
   int nRight, nSubpip;
   if (dotGiven) {
      nDigit = false;
      for (i=dotPos+1; i < maskLen; i++) {
         char = StringGetChar(mask, i);
         if ('0' <= char && char <= '9') {
            nRight = 10*nRight + char-'0';
            nDigit = true;
         }
         else if (nDigit && char==39) {      // 39 => '
            nSubpip = nRight;
            continue;
         }
         else {
            if  (char == '+') nRight = Max(nRight + (nSubpip>0), CountDecimals(value));   // (int) bool
            else if (!nDigit) nRight = CountDecimals(value);
            break;
         }
      }
      if (nDigit) {
         if (nSubpip >  0) nRight++;
         if (nSubpip == 8) nSubpip = 0;
         nRight = Min(nRight, 8);
      }
   }

   // Vorzeichen
   string leadSign = "";
   if (value < 0) {
      leadSign = "-";
   }
   else if (value > 0) {
      int pos = StringFind(mask, "+");
      if (-1 < pos) /*&&*/ if (pos < dotPos)
         leadSign = "+";
   }

   // übrige Modifier
   bool round = (StringFind(mask, "R") > -1);
   // --- Ende Maske parsen ---------------------------


   // --- Beginn Wertverarbeitung ---------------------
   // runden
   if (round)
      value = RoundEx(value, nRight);
   string outStr = value;

   // negatives Vorzeichen entfernen (ist in leadSign gespeichert)
   if (value < 0)
      outStr = StringSubstr(outStr, 1);

   // auf angegebene Länge kürzen
   int dLeft = StringFind(outStr, ".");
   if (nLeft == -1) nLeft = dLeft;
   else             nLeft = Min(nLeft, dLeft);
   outStr = StrSubstr(outStr, StringLen(outStr)-9-nLeft, nLeft+(nRight>0)+nRight);

   // Dezimal-Separator anpassen
   if (swapSeparators)
      outStr = StringSetChar(outStr, nLeft, StringGetChar(sepDecimal, 0));

   // 1000er-Separatoren einfügen
   if (separators) {
      string out1;
      i = nLeft;
      while (i > 3) {
         out1 = StrSubstr(outStr, 0, i-3);
         if (StringGetChar(out1, i-4) == ' ')
            break;
         outStr = StringConcatenate(out1, sepThousand, StringSubstr(outStr, i-3));
         i -= 3;
      }
   }

   // Subpip-Separator einfügen
   if (nSubpip > 0)
      outStr = StringConcatenate(StrLeft(outStr, nSubpip-nRight), "'", StrSubstr(outStr, nSubpip-nRight));

   // Vorzeichen etc. anfügen
   outStr = StringConcatenate(leadSign, outStr);

   //debug("NumberToStr(double="+ DoubleToStr(value, 8) +", mask="+ mask +")    nLeft="+ nLeft +"    dLeft="+ dLeft +"    nRight="+ nRight +"    nSubpip="+ nSubpip +"    outStr=\""+ outStr +"\"");
   catch("NumberToStr(1)");
   return(outStr);
}


/**
 * Gibt das Timeframe-Flag der angegebenen Chartperiode zurück.
 *
 * @param  int period - Timeframe-Identifier (default: Periode des aktuellen Charts)
 *
 * @return int - Timeframe-Flag
 */
int PeriodFlag(int period=NULL) {
   if (period == NULL)
      period = Period();

   switch (period) {
      case PERIOD_M1 : return(F_PERIOD_M1 );
      case PERIOD_M5 : return(F_PERIOD_M5 );
      case PERIOD_M15: return(F_PERIOD_M15);
      case PERIOD_M30: return(F_PERIOD_M30);
      case PERIOD_H1 : return(F_PERIOD_H1 );
      case PERIOD_H4 : return(F_PERIOD_H4 );
      case PERIOD_D1 : return(F_PERIOD_D1 );
      case PERIOD_W1 : return(F_PERIOD_W1 );
      case PERIOD_MN1: return(F_PERIOD_MN1);
      case PERIOD_Q1 : return(F_PERIOD_Q1 );
   }
   return(_NULL(catch("PeriodFlag(1)  invalid parameter period = "+ period, ERR_INVALID_PARAMETER)));
}


/**
 * Alias
 *
 * Gibt das Timeframe-Flag des angegebenen Timeframes zurück.
 *
 * @param  int timeframe - Timeframe-Identifier (default: Timeframe des aktuellen Charts)
 *
 * @return int - Timeframe-Flag
 */
int TimeframeFlag(int timeframe=NULL) {
   return(PeriodFlag(timeframe));
}


/**
 * Gibt die lesbare Version ein oder mehrerer Timeframe-Flags zurück.
 *
 * @param  int flags - Kombination verschiedener Timeframe-Flags
 *
 * @return string
 */
string PeriodFlagsToStr(int flags) {
   string result = "";

   if (!flags)                    result = StringConcatenate(result, "|NULL");
   if (flags & F_PERIOD_M1  && 1) result = StringConcatenate(result, "|M1"  );
   if (flags & F_PERIOD_M5  && 1) result = StringConcatenate(result, "|M5"  );
   if (flags & F_PERIOD_M15 && 1) result = StringConcatenate(result, "|M15" );
   if (flags & F_PERIOD_M30 && 1) result = StringConcatenate(result, "|M30" );
   if (flags & F_PERIOD_H1  && 1) result = StringConcatenate(result, "|H1"  );
   if (flags & F_PERIOD_H4  && 1) result = StringConcatenate(result, "|H4"  );
   if (flags & F_PERIOD_D1  && 1) result = StringConcatenate(result, "|D1"  );
   if (flags & F_PERIOD_W1  && 1) result = StringConcatenate(result, "|W1"  );
   if (flags & F_PERIOD_MN1 && 1) result = StringConcatenate(result, "|MN1" );
   if (flags & F_PERIOD_Q1  && 1) result = StringConcatenate(result, "|Q1"  );

   if (StringLen(result) > 0)
      result = StrSubstr(result, 1);
   return(result);
}


/**
 * Gibt die lesbare Version ein oder mehrerer History-Flags zurück.
 *
 * @param  int flags - Kombination verschiedener History-Flags
 *
 * @return string
 */
string HistoryFlagsToStr(int flags) {
   string result = "";

   if (!flags)                                result = StringConcatenate(result, "|NULL"                    );
   if (flags & HST_BUFFER_TICKS         && 1) result = StringConcatenate(result, "|HST_BUFFER_TICKS"        );
   if (flags & HST_SKIP_DUPLICATE_TICKS && 1) result = StringConcatenate(result, "|HST_SKIP_DUPLICATE_TICKS");
   if (flags & HST_FILL_GAPS            && 1) result = StringConcatenate(result, "|HST_FILL_GAPS"           );
   if (flags & HST_TIME_IS_OPENTIME     && 1) result = StringConcatenate(result, "|HST_TIME_IS_OPENTIME"    );

   if (StringLen(result) > 0)
      result = StrSubstr(result, 1);
   return(result);
}


/**
 * Return the integer constant of a price type identifier.
 *
 * @param  string value
 * @param  int    execFlags [optional] - control execution: errors to set silently (default: none)
 *
 * @return int - price type constant or -1 (EMPTY) if the value is not recognized
 */
int StrToPriceType(string value, int execFlags = NULL) {
   string str = StrToUpper(StrTrim(value));

   if (StringLen(str) == 1) {
      if (str == "O"               ) return(PRICE_OPEN    );      // capital letter O
      if (str == ""+ PRICE_OPEN    ) return(PRICE_OPEN    );
      if (str == "H"               ) return(PRICE_HIGH    );
      if (str == ""+ PRICE_HIGH    ) return(PRICE_HIGH    );
      if (str == "L"               ) return(PRICE_LOW     );
      if (str == ""+ PRICE_LOW     ) return(PRICE_LOW     );
      if (str == "C"               ) return(PRICE_CLOSE   );
      if (str == ""+ PRICE_CLOSE   ) return(PRICE_CLOSE   );
      if (str == "M"               ) return(PRICE_MEDIAN  );
      if (str == ""+ PRICE_MEDIAN  ) return(PRICE_MEDIAN  );
      if (str == "T"               ) return(PRICE_TYPICAL );
      if (str == ""+ PRICE_TYPICAL ) return(PRICE_TYPICAL );
      if (str == "W"               ) return(PRICE_WEIGHTED);
      if (str == ""+ PRICE_WEIGHTED) return(PRICE_WEIGHTED);
      if (str == "B"               ) return(PRICE_BID     );
      if (str == ""+ PRICE_BID     ) return(PRICE_BID     );
      if (str == "A"               ) return(PRICE_ASK     );
      if (str == ""+ PRICE_ASK     ) return(PRICE_ASK     );
   }
   else {
      if (StrStartsWith(str, "PRICE_"))
         str = StrSubstr(str, 6);

      if (str == "OPEN"            ) return(PRICE_OPEN    );
      if (str == "HIGH"            ) return(PRICE_HIGH    );
      if (str == "LOW"             ) return(PRICE_LOW     );
      if (str == "CLOSE"           ) return(PRICE_CLOSE   );
      if (str == "MEDIAN"          ) return(PRICE_MEDIAN  );
      if (str == "TYPICAL"         ) return(PRICE_TYPICAL );
      if (str == "WEIGHTED"        ) return(PRICE_WEIGHTED);
      if (str == "BID"             ) return(PRICE_BID     );
      if (str == "ASK"             ) return(PRICE_ASK     );
   }

   if (!execFlags & F_ERR_INVALID_PARAMETER)
      return(_EMPTY(catch("StrToPriceType(1)  invalid parameter value = "+ DoubleQuoteStr(value), ERR_INVALID_PARAMETER)));
   return(_EMPTY(SetLastError(ERR_INVALID_PARAMETER)));
}


/**
 * Gibt die lesbare Beschreibung einer MovingAverage-Methode zurück.
 *
 * @param  int type - MA-Methode
 *
 * @return string
 */
string MaMethodDescription(int method) {
   switch (method) {
      case MODE_SMA : return("SMA" );
      case MODE_LWMA: return("LWMA");
      case MODE_EMA : return("EMA" );
      case MODE_ALMA: return("ALMA");
   }
   return(_EMPTY_STR(catch("MaMethodDescription()  invalid paramter method = "+ method, ERR_INVALID_PARAMETER)));
}


/**
 * Alias
 */
string MovingAverageMethodDescription(int method) {
   return(MaMethodDescription(method));
}


/**
 * Return a readable version of a MovingAverage method.
 *
 * @param  int method
 *
 * @return string
 */
string MaMethodToStr(int method) {
   switch (method) {
      case MODE_SMA : return("MODE_SMA" );
      case MODE_LWMA: return("MODE_LWMA");
      case MODE_EMA : return("MODE_EMA" );
      case MODE_ALMA: return("MODE_ALMA");
   }
   return(_EMPTY_STR(catch("MaMethodToStr()  invalid paramter method = "+ method, ERR_INVALID_PARAMETER)));
}


/**
 * Alias
 */
string MovingAverageMethodToStr(int method) {
   return(MaMethodToStr(method));
}


/**
 * Return a readable version of a price type identifier.
 *
 * @param  int type - price type
 *
 * @return string
 */
string PriceTypeToStr(int type) {
   switch (type) {
      case PRICE_CLOSE   : return("PRICE_CLOSE"   );
      case PRICE_OPEN    : return("PRICE_OPEN"    );
      case PRICE_HIGH    : return("PRICE_HIGH"    );
      case PRICE_LOW     : return("PRICE_LOW"     );
      case PRICE_MEDIAN  : return("PRICE_MEDIAN"  );     // (High+Low)/2
      case PRICE_TYPICAL : return("PRICE_TYPICAL" );     // (High+Low+Close)/3
      case PRICE_WEIGHTED: return("PRICE_WEIGHTED");     // (High+Low+Close+Close)/4
      case PRICE_BID     : return("PRICE_BID"     );
      case PRICE_ASK     : return("PRICE_ASK"     );
   }
   return(_EMPTY_STR(catch("PriceTypeToStr(1)  invalid parameter type = "+ type, ERR_INVALID_PARAMETER)));
}


/**
 * Gibt die lesbare Version eines Price-Identifiers zurück.
 *
 * @param  int type - Price-Type
 *
 * @return string
 */
string PriceTypeDescription(int type) {
   switch (type) {
      case PRICE_CLOSE   : return("Close"   );
      case PRICE_OPEN    : return("Open"    );
      case PRICE_HIGH    : return("High"    );
      case PRICE_LOW     : return("Low"     );
      case PRICE_MEDIAN  : return("Median"  );     // (High+Low)/2
      case PRICE_TYPICAL : return("Typical" );     // (High+Low+Close)/3
      case PRICE_WEIGHTED: return("Weighted");     // (High+Low+Close+Close)/4
      case PRICE_BID     : return("Bid"     );
      case PRICE_ASK     : return("Ask"     );
   }
   return(_EMPTY_STR(catch("PriceTypeDescription(1)  invalid parameter type = "+ type, ERR_INVALID_PARAMETER)));
}


/**
 * Return the integer constant of a timeframe identifier.
 *
 * @param  string value     - M1, M5, M15, M30 etc.
 * @param  int    execFlags - execution control: errors to set silently (default: none)
 *
 * @return int - timeframe constant or -1 (EMPTY) if the value is not recognized
 */
int StrToPeriod(string value, int execFlags = NULL) {
   string str = StrToUpper(StrTrim(value));

   if (StrStartsWith(str, "PERIOD_"))
      str = StrSubstr(str, 7);

   if (str ==           "M1" ) return(PERIOD_M1 );    // 1 minute
   if (str == ""+ PERIOD_M1  ) return(PERIOD_M1 );    //
   if (str ==           "M5" ) return(PERIOD_M5 );    // 5 minutes
   if (str == ""+ PERIOD_M5  ) return(PERIOD_M5 );    //
   if (str ==           "M15") return(PERIOD_M15);    // 15 minutes
   if (str == ""+ PERIOD_M15 ) return(PERIOD_M15);    //
   if (str ==           "M30") return(PERIOD_M30);    // 30 minutes
   if (str == ""+ PERIOD_M30 ) return(PERIOD_M30);    //
   if (str ==           "H1" ) return(PERIOD_H1 );    // 1 hour
   if (str == ""+ PERIOD_H1  ) return(PERIOD_H1 );    //
   if (str ==           "H4" ) return(PERIOD_H4 );    // 4 hour
   if (str == ""+ PERIOD_H4  ) return(PERIOD_H4 );    //
   if (str ==           "D1" ) return(PERIOD_D1 );    // 1 day
   if (str == ""+ PERIOD_D1  ) return(PERIOD_D1 );    //
   if (str ==           "W1" ) return(PERIOD_W1 );    // 1 week
   if (str == ""+ PERIOD_W1  ) return(PERIOD_W1 );    //
   if (str ==           "MN1") return(PERIOD_MN1);    // 1 month
   if (str == ""+ PERIOD_MN1 ) return(PERIOD_MN1);    //
   if (str ==           "Q1" ) return(PERIOD_Q1 );    // 1 quarter
   if (str == ""+ PERIOD_Q1  ) return(PERIOD_Q1 );    //

   if (!execFlags & F_ERR_INVALID_PARAMETER)
      return(_EMPTY(catch("StrToPeriod(1)  invalid parameter value = "+ DoubleQuoteStr(value), ERR_INVALID_PARAMETER)));
   return(_EMPTY(SetLastError(ERR_INVALID_PARAMETER)));
}


/**
 * Alias
 */
int StrToTimeframe(string timeframe, int execFlags=NULL) {
   return(StrToPeriod(timeframe, execFlags));
}


/**
 * Gibt die lesbare Version eines FileAccess-Modes zurück.
 *
 * @param  int mode - Kombination verschiedener FileAccess-Modes
 *
 * @return string
 */
string FileAccessModeToStr(int mode) {
   string result = "";

   if (!mode)                  result = StringConcatenate(result, "|0"         );
   if (mode & FILE_CSV   && 1) result = StringConcatenate(result, "|FILE_CSV"  );
   if (mode & FILE_BIN   && 1) result = StringConcatenate(result, "|FILE_BIN"  );
   if (mode & FILE_READ  && 1) result = StringConcatenate(result, "|FILE_READ" );
   if (mode & FILE_WRITE && 1) result = StringConcatenate(result, "|FILE_WRITE");

   if (StringLen(result) > 0)
      result = StringSubstr(result, 1);
   return(result);
}


/**
 * Return a readable version of a swap calculation mode.
 *
 * @param  int mode
 *
 * @return string
 */
string SwapCalculationModeToStr(int mode) {
   switch (mode) {
      case SCM_POINTS         : return("SCM_POINTS"         );
      case SCM_BASE_CURRENCY  : return("SCM_BASE_CURRENCY"  );
      case SCM_INTEREST       : return("SCM_INTEREST"       );
      case SCM_MARGIN_CURRENCY: return("SCM_MARGIN_CURRENCY");       // Stringo: non-standard calculation (vom Broker abhängig)
   }
   return(_EMPTY_STR(catch("SwapCalculationModeToStr()  invalid paramter mode = "+ mode, ERR_INVALID_PARAMETER)));
}


/**
 * Gibt die lesbare Beschreibung eines ShellExecute()/ShellExecuteEx()-Fehlercodes zurück.
 *
 * @param  int error - ShellExecute-Fehlercode
 *
 * @return string
 */
string ShellExecuteErrorDescription(int error) {
   switch (error) {
      case 0                     : return("out of memory or resources"                        );   //  0
      case ERROR_BAD_FORMAT      : return("incorrect file format"                             );   // 11

      case SE_ERR_FNF            : return("file not found"                                    );   //  2
      case SE_ERR_PNF            : return("path not found"                                    );   //  3
      case SE_ERR_ACCESSDENIED   : return("access denied"                                     );   //  5
      case SE_ERR_OOM            : return("out of memory"                                     );   //  8
      case SE_ERR_SHARE          : return("a sharing violation occurred"                      );   // 26
      case SE_ERR_ASSOCINCOMPLETE: return("file association information incomplete or invalid");   // 27
      case SE_ERR_DDETIMEOUT     : return("DDE operation timed out"                           );   // 28
      case SE_ERR_DDEFAIL        : return("DDE operation failed"                              );   // 29
      case SE_ERR_DDEBUSY        : return("DDE operation is busy"                             );   // 30
      case SE_ERR_NOASSOC        : return("file association information not available"        );   // 31
      case SE_ERR_DLLNOTFOUND    : return("DLL not found"                                     );   // 32
   }
   return(StringConcatenate("unknown ShellExecute() error (", error, ")"));
}


/**
 * Log the order data of a ticket. Replacement for the limited built-in function OrderPrint().
 *
 * @param  int ticket
 *
 * @return bool - success status
 */
bool LogTicket(int ticket) {
   if (!SelectTicket(ticket, "LogTicket(1)", O_PUSH))
      return(false);

   int      type        = OrderType();
   double   lots        = OrderLots();
   string   symbol      = OrderSymbol();
   double   openPrice   = OrderOpenPrice();
   datetime openTime    = OrderOpenTime();
   double   stopLoss    = OrderStopLoss();
   double   takeProfit  = OrderTakeProfit();
   double   closePrice  = OrderClosePrice();
   datetime closeTime   = OrderCloseTime();
   double   commission  = OrderCommission();
   double   swap        = OrderSwap();
   double   profit      = OrderProfit();
   int      magic       = OrderMagicNumber();
   string   comment     = OrderComment();

   int      digits      = MarketInfo(symbol, MODE_DIGITS);
   int      pipDigits   = digits & (~1);
   string   priceFormat = "."+ pipDigits + ifString(digits==pipDigits, "", "'");
   string   message     = StringConcatenate("#", ticket, " ", OrderTypeDescription(type), " ", NumberToStr(lots, ".1+"), " ", symbol, " at ", NumberToStr(openPrice, priceFormat), " (", TimeToStr(openTime, TIME_FULL), "), sl=", ifString(stopLoss, NumberToStr(stopLoss, priceFormat), "0"), ", tp=", ifString(takeProfit, NumberToStr(takeProfit, priceFormat), "0"), ",", ifString(closeTime, " closed at "+ NumberToStr(closePrice, priceFormat) +" ("+ TimeToStr(closeTime, TIME_FULL) +"),", ""), " commission=", DoubleToStr(commission, 2), ", swap=", DoubleToStr(swap, 2), ", profit=", DoubleToStr(profit, 2), ", magicNumber=", magic, ", comment=", DoubleQuoteStr(comment));

   log("LogTicket()  "+ message);

   return(OrderPop("LogTicket(2)"));
}


/**
 * Send a chart command. Modifies the specified chart object using the specified mutex.
 *
 * @param  string cmdObject           - label of the chart object to use for transmitting the command
 * @param  string cmd                 - command to send
 * @param  string cmdMutex [optional] - label of the chart object to use for gaining synchronized write-access to cmdObject
 *                                      (default: generated from cmdObject)
 * @return bool - success status
 */
bool SendChartCommand(string cmdObject, string cmd, string cmdMutex = "") {
   if (!StringLen(cmdMutex))                                // generate default mutex if needed
      cmdMutex = StringConcatenate("mutex.", cmdObject);

   if (!AquireLock(cmdMutex, true))                         // aquire write-lock
      return(false);

   if (ObjectFind(cmdObject) != 0) {                        // create cmd object
      if (!ObjectCreate(cmdObject, OBJ_LABEL, 0, 0, 0))                return(_false(ReleaseLock(cmdMutex)));
      if (!ObjectSet(cmdObject, OBJPROP_TIMEFRAMES, OBJ_PERIODS_NONE)) return(_false(ReleaseLock(cmdMutex)));
   }

   ObjectSetText(cmdObject, cmd);                           // set command
   if (!ReleaseLock(cmdMutex))                              // release the lock
      return(false);
   Chart.SendTick();                                        // notify the chart

   return(!catch("SendChartCommand(1)"));
}


#define SW_SHOW      5     // Activates the window and displays it in its current size and position.
#define SW_HIDE      0     // Hides the window and activates another window.


/**
 * Verschickt eine E-Mail.
 *
 * @param  string sender   - E-Mailadresse des Senders    (default: der in der Konfiguration angegebene Standard-Sender)
 * @param  string receiver - E-Mailadresse des Empfängers (default: der in der Konfiguration angegebene Standard-Empfänger)
 * @param  string subject  - Subject der E-Mail
 * @param  string message  - Body der E-Mail
 *
 * @return bool - Erfolgsstatus: TRUE, wenn die E-Mail zum Versand akzeptiert wurde (nicht, ob sie versendet wurde);
 *                               FALSE andererseits
 */
bool SendEmail(string sender, string receiver, string subject, string message) {
   string filesDir = GetMqlFilesPath() +"\\";

   // (1) Validierung
   // Sender
   string _sender = StrTrim(sender);
   if (!StringLen(_sender)) {
      string section = "Mail";
      string key     = "Sender";
      _sender = GetConfigString(section, key);
      if (!StringLen(_sender))             return(!catch("SendEmail(1)  missing global/local configuration ["+ section +"]->"+ key,                                 ERR_INVALID_CONFIG_VALUE));
      if (!StrIsEmailAddress(_sender))     return(!catch("SendEmail(2)  invalid global/local configuration ["+ section +"]->"+ key +" = "+ DoubleQuoteStr(_sender), ERR_INVALID_CONFIG_VALUE));
   }
   else if (!StrIsEmailAddress(_sender))   return(!catch("SendEmail(3)  invalid parameter sender = "+ DoubleQuoteStr(sender), ERR_INVALID_PARAMETER));
   sender = _sender;

   // Receiver
   string _receiver = StrTrim(receiver);
   if (!StringLen(_receiver)) {
      section   = "Mail";
      key       = "Receiver";
      _receiver = GetConfigString(section, key);
      if (!StringLen(_receiver))           return(!catch("SendEmail(4)  missing global/local configuration ["+ section +"]->"+ key,                                   ERR_INVALID_CONFIG_VALUE));
      if (!StrIsEmailAddress(_receiver))   return(!catch("SendEmail(5)  invalid global/local configuration ["+ section +"]->"+ key +" = "+ DoubleQuoteStr(_receiver), ERR_INVALID_CONFIG_VALUE));
   }
   else if (!StrIsEmailAddress(_receiver)) return(!catch("SendEmail(6)  invalid parameter receiver = "+ DoubleQuoteStr(receiver), ERR_INVALID_PARAMETER));
   receiver = _receiver;

   // Subject
   string _subject = StrTrim(subject);
   if (!StringLen(_subject))               return(!catch("SendEmail(7)  invalid parameter subject = "+ DoubleQuoteStr(subject), ERR_INVALID_PARAMETER));
   _subject = StrReplace(StrReplace(StrReplace(_subject, "\r\n", "\n"), "\r", " "), "\n", " ");          // Linebreaks mit Leerzeichen ersetzen
   _subject = StrReplace(_subject, "\"", "\\\"");                                                        // Double-Quotes in email-Parametern escapen
   _subject = StrReplace(_subject, "'", "'\"'\"'");                                                      // Single-Quotes im bash-Parameter escapen
   // bash -lc 'email -subject "single-quote:'"'"' double-quote:\" pipe:|" ...'

   // (2) Message (kann leer sein): in temporärer Datei speichern, wenn nicht leer
   message = StrTrim(message);
   string message.txt = CreateTempFile(filesDir, "msg");
   if (StringLen(message) > 0) {
      int hFile = FileOpen(StrRightFrom(message.txt, filesDir), FILE_BIN|FILE_WRITE);                    // FileOpen() benötigt einen MQL-Pfad
      if (hFile < 0)  return(!catch("SendEmail(8)->FileOpen()"));
      int bytes = FileWriteString(hFile, message, StringLen(message));
      FileClose(hFile);
      if (bytes <= 0) return(!catch("SendEmail(9)->FileWriteString() => "+ bytes +" written"));
   }

   // (3) benötigte Binaries ermitteln: Bash und Mailclient
   string bash = GetConfigString("System", "Bash");
   if (!IsFileA(bash)) return(!catch("SendEmail(10)  bash executable not found: "+ DoubleQuoteStr(bash), ERR_FILE_NOT_FOUND));
   // (3.1) absoluter Pfad
   // (3.2) relativer Pfad: Systemverzeichnisse durchsuchen; Variable $PATH durchsuchen

   string sendmail = GetConfigString("Mail", "Sendmail");
   if (!StringLen(sendmail)) {
      // TODO: - kein Mailclient angegeben: Umgebungsvariable $SENDMAIL auswerten
      //       - sendmail suchen
      return(!catch("SendEmail(11)  missing global/local configuration [Mail]->Sendmail", ERR_INVALID_CONFIG_VALUE));
   }

   // (4) Befehlszeile für Shell-Aufruf zusammensetzen
   //
   //  • Redirection in der Befehlszeile ist ein Shell-Feature und erfordert eine Shell als ausführendes Programm (direkter
   //    Client-Aufruf mit Umleitung ist nicht möglich).
   //  • Redirection mit cmd.exe funktioniert nicht, wenn umgeleiteter Output oder übergebene Parameter Sonderzeichen
   //    enthalten: cmd /c echo hello \n world | {program} => Fehler
   //  • Bei Verwendung der Shell als ausführendem Programm steht jedoch der Exit-Code nicht zur Verfügung (muß vorerst in
   //    Kauf genommen werden).
   //  • Alternative ist die Verwendung von CreateProcess() und direktes Schreiben/Lesen von STDIN/STDOUT. In diesem Fall muß
   //    der Versand jedoch in einem eigenen Thread erfolgen, wenn er nicht blockieren soll.
   //
   // Cleancode.email:
   // ----------------
   //  • unterstützt keine Exit-Codes
   //  • validiert die übergebenen Adressen nicht
   //
   message.txt     = StrReplace(message.txt, "\\", "/");
   string mail.log = StrReplace(filesDir +"mail.log", "\\", "/");
   string cmdLine  = sendmail +" -subject \""+ _subject +"\" -from-addr \""+ sender +"\" \""+ receiver +"\" < \""+ message.txt +"\" >> \""+ mail.log +"\" 2>&1; rm -f \""+ message.txt +"\"";
          cmdLine  = bash +" -lc '"+ cmdLine +"'";

   // (5) Shell-Aufruf
   int result = WinExec(cmdLine, SW_HIDE);   // SW_SHOW | SW_HIDE
   if (result < 32) return(!catch("SendEmail(13)->kernel32::WinExec(cmdLine=\""+ cmdLine +"\")  "+ ShellExecuteErrorDescription(result), ERR_WIN32_ERROR+result));

   if (__LOG()) log("SendEmail(14)  Mail to "+ receiver +" transmitted: \""+ subject +"\"");
   return(!catch("SendEmail(15)"));
}


/**
 * Schickt eine SMS an die angegebene Telefonnummer.
 *
 * @param  string receiver - Telefonnummer des Empfängers (internationales Format: +49-123-456789)
 * @param  string message  - Text der SMS
 *
 * @return bool - Erfolgsstatus
 */
bool SendSMS(string receiver, string message) {
   string _receiver = StrReplaceR(StrReplace(StrTrim(receiver), "-", ""), " ", "");

   if      (StrStartsWith(_receiver, "+" )) _receiver = StrSubstr(_receiver, 1);
   else if (StrStartsWith(_receiver, "00")) _receiver = StrSubstr(_receiver, 2);
   if (!StrIsDigit(_receiver)) return(!catch("SendSMS(1)  invalid parameter receiver = "+ DoubleQuoteStr(receiver), ERR_INVALID_PARAMETER));

   // (1) Zugangsdaten für SMS-Gateway holen
   // Service-Provider
   string section  = "SMS";
   string key      = "Provider";
   string provider = GetGlobalConfigString(section, key);
   if (!StringLen(provider)) return(!catch("SendSMS(2)  missing global configuration ["+ section +"]->"+ key, ERR_INVALID_CONFIG_VALUE));

   // Username
   section = "SMS."+ provider;
   key     = "username";
   string username = GetGlobalConfigString(section, key);
   if (!StringLen(username)) return(!catch("SendSMS(3)  missing global configuration ["+ section +"]->"+ key, ERR_INVALID_CONFIG_VALUE));

   // Password
   key = "password";
   string password = GetGlobalConfigString(section, key);
   if (!StringLen(password)) return(!catch("SendSMS(4)  missing global configuration ["+ section +"]->"+ key, ERR_INVALID_CONFIG_VALUE));

   // API-ID
   key = "api_id";
   int api_id = GetGlobalConfigInt(section, key);
   if (api_id <= 0) {
      string value = GetGlobalConfigString(section, key);
      if (!StringLen(value)) return(!catch("SendSMS(5)  missing global configuration ["+ section +"]->"+ key,                       ERR_INVALID_CONFIG_VALUE));
                             return(!catch("SendSMS(6)  invalid global configuration ["+ section +"]->"+ key +" = \""+ value +"\"", ERR_INVALID_CONFIG_VALUE));
   }

   // (2) Befehlszeile für Shellaufruf zusammensetzen
   string url          = "https://api.clickatell.com/http/sendmsg?user="+ username +"&password="+ password +"&api_id="+ api_id +"&to="+ _receiver +"&text="+ UrlEncode(message);
   string filesDir     = GetMqlFilesPath();
   string responseFile = filesDir +"\\sms_"+ GmtTimeFormat(GetLocalTime(), "%Y-%m-%d %H.%M.%S") +"_"+ GetCurrentThreadId() +".response";
   string logFile      = filesDir +"\\sms.log";
   string cmd          = GetMqlDirectoryA() +"\\libraries\\wget.exe";
   string arguments    = "-b --no-check-certificate \""+ url +"\" -O \""+ responseFile +"\" -a \""+ logFile +"\"";
   string cmdLine      = cmd +" "+ arguments;

   // (3) Shellaufruf
   int result = WinExec(cmdLine, SW_HIDE);
   if (result < 32) return(!catch("SendSMS(7)->kernel32::WinExec(cmdLine="+ DoubleQuoteStr(cmdLine) +")  "+ ShellExecuteErrorDescription(result), ERR_WIN32_ERROR+result));

   /**
    * TODO: Fehlerauswertung nach dem Versand:
    *
    * --2011-03-23 08:32:06--  https://api.clickatell.com/http/sendmsg?user={user}&password={password}&api_id={api_id}&to={receiver}&text={text}
    * Resolving api.clickatell.com... failed: Unknown host.
    * wget: unable to resolve host address `api.clickatell.com'
    *
    *
    * --2014-06-15 22:44:21--  (try:20)  https://api.clickatell.com/http/sendmsg?user={user}&password={password}&api_id={api_id}&to={receiver}&text={text}
    * Connecting to api.clickatell.com|196.216.236.7|:443... failed: Permission denied.
    * Giving up.
    */
   log("SendSMS(8)  SMS sent to "+ receiver +": \""+ message +"\"");
   return(!catch("SendSMS(9)"));
}


/**
 * Whether the current program is executed by another one.
 *
 * @return bool
 */
bool IsSuperContext() {
   return(__lpSuperContext != 0);
}


/**
 * Round a lot size according to the specified symbol's lot step value (MODE_LOTSTEP).
 *
 * @param  double lots              - lot size
 * @param  string symbol [optional] - symbol (default: the current symbol)
 *
 * @return double - rounded lot size
 */
double NormalizeLots(double lots, string symbol = "") {
   if (!StringLen(symbol))
      symbol = Symbol();
   double lotstep = MarketInfo(symbol, MODE_LOTSTEP);
   return(NormalizeDouble(MathRound(lots/lotstep) * lotstep, 2));
}


/**
 * Initialize the status of logging warnings to email (available for experts only).
 *
 * @return bool - whether warning logging to email is enabled
 */
bool init.LogWarningsToMail() {
   __LOG_WARN.mail          = false;
   __LOG_WARN.mail.sender   = "";
   __LOG_WARN.mail.receiver = "";

   if (IsExpert()) /*&&*/ if (GetConfigBool("Logging", "WarnToMail")) {    // available for experts only
      // enabled
      string mailSection = "Mail";
      string senderKey   = "Sender";
      string receiverKey = "Receiver";

      string defaultSender = "mt4@"+ GetHostName() +".localdomain";
      string sender        = GetConfigString(mailSection, senderKey, defaultSender);
      if (!StrIsEmailAddress(sender))   return(!catch("init.LogWarningsToMail(1)  invalid email address: "+ ifString(IsConfigKey(mailSection, senderKey), "["+ mailSection +"]->"+ senderKey +" = "+ sender, "defaultSender = "+ defaultSender), ERR_INVALID_CONFIG_VALUE));

      string receiver = GetConfigString(mailSection, receiverKey);
      if (!StrIsEmailAddress(receiver)) return(!catch("init.LogWarningsToMail(2)  invalid email address: ["+ mailSection +"]->"+ receiverKey +" = "+ receiver, ERR_INVALID_CONFIG_VALUE));

      __LOG_WARN.mail          = true;
      __LOG_WARN.mail.sender   = sender;
      __LOG_WARN.mail.receiver = receiver;
      return(true);
   }
   return(false);
}


/**
 * Initialize the status of logging warnings to text message (available for experts only).
 *
 * @return bool - whether warning logging to text message is enabled
 */
bool init.LogWarningsToSMS() {
   __LOG_WARN.sms          = false;
   __LOG_WARN.sms.receiver = "";

   if (IsExpert()) /*&&*/ if (GetConfigBool("Logging", "WarnToSMS")) {     // available for experts only
      // enabled
      string smsSection  = "SMS";
      string receiverKey = "Receiver";

      string receiver = GetConfigString(smsSection, receiverKey);
      if (!StrIsPhoneNumber(receiver)) return(!catch("init.LogWarningsToSMS(1)  invalid phone number: ["+ smsSection +"]->"+ receiverKey +" = "+ receiver, ERR_INVALID_CONFIG_VALUE));

      __LOG_WARN.sms          = true;
      __LOG_WARN.sms.receiver = receiver;
      return(true);
   }
   return(false);
}


/**
 * Initialize the status of logging errors to email (available for experts only).
 *
 * @return bool - whether error logging to email is enabled
 */
bool init.LogErrorsToMail() {
   __LOG_ERROR.mail          = false;
   __LOG_ERROR.mail.sender   = "";
   __LOG_ERROR.mail.receiver = "";

   if (IsExpert()) /*&&*/ if (GetConfigBool("Logging", "ErrorToMail")) {   // available for experts only
      // enabled
      string mailSection = "Mail";
      string senderKey   = "Sender";
      string receiverKey = "Receiver";

      string defaultSender = "mt4@"+ GetHostName() +".localdomain";
      string sender        = GetConfigString(mailSection, senderKey, defaultSender);
      if (!StrIsEmailAddress(sender))   return(!catch("init.LogErrorsToMail(1)  invalid email address: "+ ifString(IsConfigKey(mailSection, senderKey), "["+ mailSection +"]->"+ senderKey +" = "+ sender, "defaultSender = "+ defaultSender), ERR_INVALID_CONFIG_VALUE));

      string receiver = GetConfigString(mailSection, receiverKey);
      if (!StrIsEmailAddress(receiver)) return(!catch("init.LogErrorsToMail(2)  invalid email address: ["+ mailSection +"]->"+ receiverKey +" = "+ receiver, ERR_INVALID_CONFIG_VALUE));

      __LOG_ERROR.mail          = true;
      __LOG_ERROR.mail.sender   = sender;
      __LOG_ERROR.mail.receiver = receiver;
      return(true);
   }
   return(false);
}


/**
 * Initialize the status of logging errors to text message (available for experts only).
 *
 * @return bool - whether error logging to text message is enabled
 */
bool init.LogErrorsToSMS() {
   __LOG_ERROR.sms          = false;
   __LOG_ERROR.sms.receiver = "";

   if (IsExpert()) /*&&*/ if (GetConfigBool("Logging", "ErrorToSMS")) {    // available for experts only
      // enabled
      string smsSection  = "SMS";
      string receiverKey = "Receiver";

      string receiver = GetConfigString(smsSection, receiverKey);
      if (!StrIsPhoneNumber(receiver)) return(!catch("init.LogErrorsToSMS(1)  invalid phone number: ["+ smsSection +"]->"+ receiverKey +" = "+ receiver, ERR_INVALID_CONFIG_VALUE));

      __LOG_ERROR.sms          = true;
      __LOG_ERROR.sms.receiver = receiver;
      return(true);
   }
   return(false);
}


/**
 * Load the "ALMA" indicator and return a value.
 *
 * @param  int    timeframe          - timeframe to load the indicator (NULL: the current timeframe)
 * @param  int    maPeriods          - indicator parameter
 * @param  string maAppliedPrice     - indicator parameter
 * @param  double distributionOffset - indicator parameter
 * @param  double distributionSigma  - indicator parameter
 * @param  int    iBuffer            - indicator buffer index of the value to return
 * @param  int    iBar               - bar index of the value to return
 *
 * @return double - indicator value or NULL in case of errors
 */
double iALMA(int timeframe, int maPeriods, string maAppliedPrice, double distributionOffset, double distributionSigma, int iBuffer, int iBar) {
   static int lpSuperContext = 0; if (!lpSuperContext)
      lpSuperContext = GetIntsAddress(__ExecutionContext);

   double value = iCustom(NULL, timeframe, "ALMA",
                          maPeriods,                                       // int    MA.Periods
                          maAppliedPrice,                                  // string MA.AppliedPrice
                          distributionOffset,                              // double Distribution.Offset
                          distributionSigma,                               // double Distribution.Sigma

                          Blue,                                            // color  Color.UpTrend
                          Red,                                             // color  Color.DownTrend
                          "Line",                                          // string Draw.Type
                          1,                                               // int    Draw.Width
                          -1,                                              // int    Max.Values
                          "",                                              // string ____________________
                          "off",                                           // string Signal.onTrendChange
                          "off",                                           // string Signal.Sound
                          "off",                                           // string Signal.Mail.Receiver
                          "off",                                           // string Signal.SMS.Receiver
                          "",                                              // string ____________________
                          lpSuperContext,                                  // int    __SuperContext__

                          iBuffer, iBar);

   int error = GetLastError();
   if (error != NO_ERROR) {
      if (error != ERS_HISTORY_UPDATE)
         return(!catch("iALMA(1)", error));
      warn("iALMA(2)  "+ PeriodDescription(ifInt(!timeframe, Period(), timeframe)) +" (tick="+ Tick +")", ERS_HISTORY_UPDATE);
   }

   error = __ExecutionContext[EC.mqlError];                                // TODO: synchronize execution contexts
   if (!error)
      return(value);
   return(!SetLastError(error));
}


/**
 * Load the "FATL" indicator and return a value.
 *
 * @param  int timeframe - timeframe to load the indicator (NULL: the current timeframe)
 * @param  int iBuffer   - indicator buffer index of the value to return
 * @param  int iBar      - bar index of the value to return
 *
 * @return double - indicator value or NULL in case of errors
 */
double iFATL(int timeframe, int iBuffer, int iBar) {
   static int lpSuperContext = 0; if (!lpSuperContext)
      lpSuperContext = GetIntsAddress(__ExecutionContext);

   double value = iCustom(NULL, timeframe, "FATL",
                          Blue,                                            // color  Color.UpTrend
                          Red,                                             // color  Color.DownTrend
                          "Line",                                          // string Draw.Type
                          1,                                               // int    Draw.Width
                          -1,                                              // int    Max.Values
                          "",                                              // string ____________________
                          "off",                                           // string Signal.onTrendChange
                          "off",                                           // string Signal.Sound
                          "off",                                           // string Signal.Mail.Receiver
                          "off",                                           // string Signal.SMS.Receiver
                          "",                                              // string ____________________
                          lpSuperContext,                                  // int    __SuperContext__

                          iBuffer, iBar);

   int error = GetLastError();
   if (error != NO_ERROR) {
      if (error != ERS_HISTORY_UPDATE)
         return(!catch("iFATL(1)", error));
      warn("iFATL(2)  "+ PeriodDescription(ifInt(!timeframe, Period(), timeframe)) +" (tick="+ Tick +")", ERS_HISTORY_UPDATE);
   }

   error = __ExecutionContext[EC.mqlError];                                // TODO: synchronize execution contexts
   if (!error)
      return(value);
   return(!SetLastError(error));
}


/**
 * Load the "HalfTrend" indicator and return a value.
 *
 * @param  int timeframe - timeframe to load the indicator (NULL: the current timeframe)
 * @param  int periods   - indicator parameter
 * @param  int iBuffer   - indicator buffer index of the value to return
 * @param  int iBar      - bar index of the value to return
 *
 * @return double - indicator value or NULL in case of errors
 */
double iHalfTrend(int timeframe, int periods, int iBuffer, int iBar) {
   static int lpSuperContext = 0; if (!lpSuperContext)
      lpSuperContext = GetIntsAddress(__ExecutionContext);

   double value = iCustom(NULL, timeframe, "HalfTrend",
                          periods,                                         // int    Periods

                          DodgerBlue,                                      // color  Color.UpTrend
                          Red,                                             // color  Color.DownTrend
                          CLR_NONE,                                        // color  Color.Channel
                          "Line",                                          // string Draw.Type
                          1,                                               // int    Draw.Width
                          -1,                                              // int    Max.Values
                          "",                                              // string ____________________
                          "off",                                           // string Signal.onTrendChange
                          "off",                                           // string Signal.Sound
                          "off",                                           // string Signal.Mail.Receiver
                          "off",                                           // string Signal.SMS.Receiver
                          "",                                              // string ____________________
                          lpSuperContext,                                  // int    __SuperContext__

                          iBuffer, iBar);

   int error = GetLastError();
   if (error != NO_ERROR) {
      if (error != ERS_HISTORY_UPDATE)
         return(!catch("iHalfTrend(1)", error));
      warn("iHalfTrend(2)  "+ PeriodDescription(ifInt(!timeframe, Period(), timeframe)) +" (tick="+ Tick +")", ERS_HISTORY_UPDATE);
   }

   error = __ExecutionContext[EC.mqlError];                                // TODO: synchronize execution contexts
   if (!error)
      return(value);
   return(!SetLastError(error));
}


/**
 * Load the "Jurik Moving Average" and return an indicator value.
 *
 * @param  int    timeframe    - timeframe to load the indicator (NULL: the current timeframe)
 * @param  int    periods      - indicator parameter
 * @param  int    phase        - indicator parameter
 * @param  string appliedPrice - indicator parameter
 * @param  int    iBuffer      - indicator buffer index of the value to return
 * @param  int    iBar         - bar index of the value to return
 *
 * @return double - indicator value or NULL in case of errors
 */
double iJMA(int timeframe, int periods, int phase, string appliedPrice, int iBuffer, int iBar) {
   static int lpSuperContext = 0; if (!lpSuperContext)
      lpSuperContext = GetIntsAddress(__ExecutionContext);

   double value = iCustom(NULL, timeframe, "Jurik Moving Average",
                          periods,                                         // int    Periods
                          phase,                                           // int    Phase
                          appliedPrice,                                    // string AppliedPrice

                          DodgerBlue,                                      // color  Color.UpTrend
                          Red,                                             // color  Color.DownTrend
                          "Line",                                          // string Draw.Type
                          1,                                               // int    Draw.Width
                          -1,                                              // int    Max.Values
                          "",                                              // string ____________________
                          "off",                                           // string Signal.onTrendChange
                          "off",                                           // string Signal.Sound
                          "off",                                           // string Signal.Mail.Receiver
                          "off",                                           // string Signal.SMS.Receiver
                          "",                                              // string ____________________
                          lpSuperContext,                                  // int    __SuperContext__

                          iBuffer, iBar);

   int error = GetLastError();
   if (error != NO_ERROR) {
      if (error != ERS_HISTORY_UPDATE)
         return(!catch("iJMA(1)", error));
      warn("iJMA(2)  "+ PeriodDescription(ifInt(!timeframe, Period(), timeframe)) +" (tick="+ Tick +")", ERS_HISTORY_UPDATE);
   }

   error = __ExecutionContext[EC.mqlError];                                // TODO: synchronize execution contexts
   if (!error)
      return(value);
   return(!SetLastError(error));
}


/**
 * Load the custom "MACD" indicator and return a value.
 *
 * @param  int    timeframe          - timeframe to load the indicator (NULL: the current timeframe)
 * @param  int    fastMaPeriods      - indicator parameter
 * @param  string fastMaMethod       - indicator parameter
 * @param  string fastMaAppliedPrice - indicator parameter
 * @param  int    slowMaPeriods      - indicator parameter
 * @param  string slowMaMethod       - indicator parameter
 * @param  string slowMaAppliedPrice - indicator parameter
 * @param  int    iBuffer            - indicator buffer index of the value to return
 * @param  int    iBar               - bar index of the value to return
 *
 * @return double - indicator value or NULL in case of errors
 */
double iMACDX(int timeframe, int fastMaPeriods, string fastMaMethod, string fastMaAppliedPrice, int slowMaPeriods, string slowMaMethod, string slowMaAppliedPrice, int iBuffer, int iBar) {
   static int lpSuperContext = 0; if (!lpSuperContext)
      lpSuperContext = GetIntsAddress(__ExecutionContext);

   double value = iCustom(NULL, timeframe, "MACDX",
                          fastMaPeriods,                                   // int    Fast.MA.Periods
                          fastMaMethod,                                    // string Fast.MA.Method
                          fastMaAppliedPrice,                              // string Fast.MA.AppliedPrice

                          slowMaPeriods,                                   // int    Slow.MA.Periods
                          slowMaMethod,                                    // string Slow.MA.Method
                          slowMaAppliedPrice,                              // string Slow.MA.AppliedPrice

                          DodgerBlue,                                      // color  MainLine.Color
                          1,                                               // int    MainLine.Width
                          LimeGreen,                                       // color  Histogram.Color.Upper
                          Red,                                             // color  Histogram.Color.Lower
                          2,                                               // int    Histogram.Style.Width
                          -1,                                              // int    Max.Values
                          "",                                              // string _____________________
                          "off",                                           // string Signal.onZeroCross
                          "off",                                           // string Signal.Sound
                          "off",                                           // string Signal.Mail.Receiver
                          "off",                                           // string Signal.SMS.Receiver
                          "",                                              // string _____________________
                          lpSuperContext,                                  // int    __SuperContext__

                          iBuffer, iBar);

   int error = GetLastError();
   if (error != NO_ERROR) {
      if (error != ERS_HISTORY_UPDATE)
         return(!catch("iMACDX(1)", error));
      warn("iMACDX(2)  "+ PeriodDescription(ifInt(!timeframe, Period(), timeframe)) +" (tick="+ Tick +")", ERS_HISTORY_UPDATE);
   }

   error = __ExecutionContext[EC.mqlError];                                // TODO: synchronize execution contexts
   if (!error)
      return(value);
   return(!SetLastError(error));
}


/**
 * Load the custom "Moving Average" and return an indicator value.
 *
 * @param  int    timeframe      - timeframe to load the indicator (NULL: the current timeframe)
 * @param  int    maPeriods      - indicator parameter
 * @param  string maMethod       - indicator parameter
 * @param  string maAppliedPrice - indicator parameter
 * @param  int    iBuffer        - indicator buffer index of the value to return
 * @param  int    iBar           - bar index of the value to return
 *
 * @return double - indicator value or NULL in case of errors
 */
double iMovingAverage(int timeframe, int maPeriods, string maMethod, string maAppliedPrice, int iBuffer, int iBar) {
   static int lpSuperContext = 0; if (!lpSuperContext)
      lpSuperContext = GetIntsAddress(__ExecutionContext);

   double value = iCustom(NULL, timeframe, "Moving Average",
                          maPeriods,                                       // int    MA.Periods
                          maMethod,                                        // string MA.Method
                          maAppliedPrice,                                  // string MA.AppliedPrice

                          Blue,                                            // color  Color.UpTrend
                          Orange,                                          // color  Color.DownTrend
                          "Line",                                          // string Draw.Type
                          1,                                               // int    Draw.Width
                          -1,                                              // int    Max.Values
                          "",                                              // string ____________________
                          "off",                                           // string Signal.onTrendChange
                          "off",                                           // string Signal.Sound
                          "off",                                           // string Signal.Mail.Receiver
                          "off",                                           // string Signal.SMS.Receiver
                          "",                                              // string ____________________
                          lpSuperContext,                                  // int    __SuperContext__

                          iBuffer, iBar);

   int error = GetLastError();
   if (error != NO_ERROR) {
      if (error != ERS_HISTORY_UPDATE)
         return(!catch("iMovingAverage(1)", error));
      warn("iMovingAverage(2)  "+ PeriodDescription(ifInt(!timeframe, Period(), timeframe)) +" (tick="+ Tick +")", ERS_HISTORY_UPDATE);
   }

   error = __ExecutionContext[EC.mqlError];                                // TODO: synchronize execution contexts
   if (!error)
      return(value);
   return(!SetLastError(error));
}


/**
 * Load the "NonLagMA" indicator and return a value.
 *
 * @param  int    timeframe    - timeframe to load the indicator (NULL: the current timeframe)
 * @param  int    cycleLength  - indicator parameter
 * @param  string appliedPrice - indicator parameter
 * @param  int    iBuffer      - indicator buffer index of the value to return
 * @param  int    iBar         - bar index of the value to return
 *
 * @return double - indicator value or NULL in case of errors
 */
double iNonLagMA(int timeframe, int cycleLength, string appliedPrice, int iBuffer, int iBar) {
   static int lpSuperContext = 0; if (!lpSuperContext)
      lpSuperContext = GetIntsAddress(__ExecutionContext);

   double value = iCustom(NULL, timeframe, "NonLagMA",
                          cycleLength,                                     // int    Cycle.Length
                          appliedPrice,                                    // string AppliedPrice

                          RoyalBlue,                                       // color  Color.UpTrend
                          Red,                                             // color  Color.DownTrend
                          "Dot",                                           // string Draw.Type
                          1,                                               // int    Draw.Width
                          -1,                                              // int    Max.Values
                          "",                                              // string ____________________
                          "off",                                           // string Signal.onTrendChange
                          "off",                                           // string Signal.Sound
                          "off",                                           // string Signal.Mail.Receiver
                          "off",                                           // string Signal.SMS.Receiver
                          "",                                              // string ____________________
                          lpSuperContext,                                  // int    __SuperContext__

                          iBuffer, iBar);

   int error = GetLastError();
   if (error != NO_ERROR) {
      if (error != ERS_HISTORY_UPDATE)
         return(!catch("iNonLagMA(1)", error));
      warn("iNonLagMA(2)  "+ PeriodDescription(ifInt(!timeframe, Period(), timeframe)) +" (tick="+ Tick +")", ERS_HISTORY_UPDATE);
   }

   error = __ExecutionContext[EC.mqlError];                                // TODO: synchronize execution contexts
   if (!error)
      return(value);
   return(!SetLastError(error));
}


/**
 * Load the custom "RSI" indicator and return a value.
 *
 * @param  int    timeframe    - timeframe to load the indicator (NULL: the current timeframe)
 * @param  int    periods      - indicator parameter
 * @param  string appliedPrice - indicator parameter
 * @param  int    iBuffer      - indicator buffer index of the value to return
 * @param  int    iBar         - bar index of the value to return
 *
 * @return double - indicator value or NULL in case of errors
 */
double iRSIX(int timeframe, int periods, string appliedPrice, int iBuffer, int iBar) {
   static int lpSuperContext = 0; if (!lpSuperContext)
      lpSuperContext = GetIntsAddress(__ExecutionContext);

   double value = iCustom(NULL, timeframe, ".attic/RSI",
                          periods,                                         // int    RSI.Periods
                          appliedPrice,                                    // string RSI.AppliedPrice

                          Blue,                                            // color  MainLine.Color
                          1,                                               // int    MainLine.Width
                          Blue,                                            // color  Histogram.Color.Upper
                          Red,                                             // color  Histogram.Color.Lower
                          0,                                               // int    Histogram.Style.Width
                          -1,                                              // int    Max.Values
                          "",                                              // string _____________________
                          lpSuperContext,                                  // int    __SuperContext__

                          iBuffer, iBar);

   int error = GetLastError();
   if (error != NO_ERROR) {
      if (error != ERS_HISTORY_UPDATE)
         return(!catch("iRSIX(1)", error));
      warn("iRSIX(2)  "+ PeriodDescription(ifInt(!timeframe, Period(), timeframe)) +" (tick="+ Tick +")", ERS_HISTORY_UPDATE);
   }

   error = __ExecutionContext[EC.mqlError];                                // TODO: synchronize execution contexts
   if (!error)
      return(value);
   return(!SetLastError(error));
}


/**
 * Load the "SATL" indicator and return a value.
 *
 * @param  int timeframe - timeframe to load the indicator (NULL: the current timeframe)
 * @param  int iBuffer   - indicator buffer index of the value to return
 * @param  int iBar      - bar index of the value to return
 *
 * @return double - indicator value or NULL in case of errors
 */
double iSATL(int timeframe, int iBuffer, int iBar) {
   static int lpSuperContext = 0; if (!lpSuperContext)
      lpSuperContext = GetIntsAddress(__ExecutionContext);

   double value = iCustom(NULL, timeframe, "SATL",
                          Blue,                                            // color  Color.UpTrend
                          Red,                                             // color  Color.DownTrend
                          "Line",                                          // string Draw.Type
                          1,                                               // int    Draw.Width
                          -1,                                              // int    Max.Values
                          "",                                              // string ____________________
                          "off",                                           // string Signal.onTrendChange
                          "off",                                           // string Signal.Sound
                          "off",                                           // string Signal.Mail.Receiver
                          "off",                                           // string Signal.SMS.Receiver
                          "",                                              // string ____________________
                          lpSuperContext,                                  // int    __SuperContext__

                          iBuffer, iBar);

   int error = GetLastError();
   if (error != NO_ERROR) {
      if (error != ERS_HISTORY_UPDATE)
         return(!catch("iSATL(1)", error));
      warn("iSATL(2)  "+ PeriodDescription(ifInt(!timeframe, Period(), timeframe)) +" (tick="+ Tick +")", ERS_HISTORY_UPDATE);
   }

   error = __ExecutionContext[EC.mqlError];                                // TODO: synchronize execution contexts
   if (!error)
      return(value);
   return(!SetLastError(error));
}


/**
 * Load the "Stochastic of RSI" indicator and return a value.
 *
 * @param  int timeframe            - timeframe to load the indicator (NULL: the current timeframe)
 * @param  int stochasticPeriods    - indicator parameter
 * @param  int stochasticMa1Periods - indicator parameter
 * @param  int stochasticMa2Periods - indicator parameter
 * @param  int rsiPeriods           - indicator parameter
 * @param  int iBuffer              - indicator buffer index of the value to return
 * @param  int iBar                 - bar index of the value to return
 *
 * @return double - indicator value or NULL in case of errors
 */
double iStochasticOfRSI(int timeframe, int stochasticPeriods, int stochasticMa1Periods, int stochasticMa2Periods, int rsiPeriods, int iBuffer, int iBar) {
   static int lpSuperContext = 0; if (!lpSuperContext)
      lpSuperContext = GetIntsAddress(__ExecutionContext);

   double value = iCustom(NULL, timeframe, "Stochastic of RSI",
                          stochasticPeriods,                               // int    Stochastic.Periods
                          stochasticMa1Periods,                            // int    Stochastic.MA1.Periods
                          stochasticMa2Periods,                            // int    Stochastic.MA2.Periods
                          rsiPeriods,                                      // int    RSI.Periods
                          CLR_NONE,                                        // color  Main.Color
                          DodgerBlue,                                      // color  Signal.Color
                          "Line",                                          // string Signal.DrawType
                          1,                                               // int    Signal.DrawWidth
                          -1,                                              // int    Max.Values
                          "",                                              // string ______________________
                          lpSuperContext,                                  // int    __SuperContext__

                          iBuffer, iBar);

   int error = GetLastError();
   if (error != NO_ERROR) {
      if (error != ERS_HISTORY_UPDATE)
         return(!catch("iStochasticOfRSI(1)", error));
      warn("iStochasticOfRSI(2)  "+ PeriodDescription(ifInt(!timeframe, Period(), timeframe)) +" (tick="+ Tick +")", ERS_HISTORY_UPDATE);
   }

   error = __ExecutionContext[EC.mqlError];                                // TODO: synchronize execution contexts
   if (!error)
      return(value);
   return(!SetLastError(error));
}


/**
 * Load "Ehlers 2-Pole-SuperSmoother" indicator and return a value.
 *
 * @param  int    timeframe    - timeframe to load the indicator (NULL: the current timeframe)
 * @param  int    periods      - indicator parameter
 * @param  string appliedPrice - indicator parameter
 * @param  int    iBuffer      - indicator buffer index of the value to return
 * @param  int    iBar         - bar index of the value to return
 *
 * @return double - indicator value or NULL in case of errors
 */
double iSuperSmoother(int timeframe, int periods, string appliedPrice, int iBuffer, int iBar) {
   static int lpSuperContext = 0; if (!lpSuperContext)
      lpSuperContext = GetIntsAddress(__ExecutionContext);

   double value = iCustom(NULL, timeframe, "Ehlers 2-Pole-SuperSmoother",
                          periods,                                         // int    Periods
                          appliedPrice,                                    // string AppliedPrice

                          Blue,                                            // color  Color.UpTrend
                          Orange,                                          // color  Color.DownTrend
                          "Line",                                          // string Draw.Type
                          1,                                               // int    Draw.Width
                          -1,                                              // int    Max.Values
                          "",                                              // string ____________________
                          "off",                                           // string Signal.onTrendChange
                          "off",                                           // string Signal.Sound
                          "off",                                           // string Signal.Mail.Receiver
                          "off",                                           // string Signal.SMS.Receiver
                          "",                                              // string ____________________
                          lpSuperContext,                                  // int    __SuperContext__

                          iBuffer, iBar);

   int error = GetLastError();
   if (error != NO_ERROR) {
      if (error != ERS_HISTORY_UPDATE)
         return(!catch("iSuperSmoother(1)", error));
      warn("iSuperSmoother(2)  "+ PeriodDescription(ifInt(!timeframe, Period(), timeframe)) +" (tick="+ Tick +")", ERS_HISTORY_UPDATE);
   }

   error = __ExecutionContext[EC.mqlError];                                // TODO: synchronize execution contexts
   if (!error)
      return(value);
   return(!SetLastError(error));
}


/**
 * Load the "SuperTrend" indicator and return a value.
 *
 * @param  int timeframe  - timeframe to load the indicator (NULL: the current timeframe)
 * @param  int atrPeriods - indicator parameter
 * @param  int smaPeriods - indicator parameter
 * @param  int iBuffer    - indicator buffer index of the value to return
 * @param  int iBar       - bar index of the value to return
 *
 * @return double - indicator value or NULL in case of errors
 */
double iSuperTrend(int timeframe, int atrPeriods, int smaPeriods, int iBuffer, int iBar) {
   static int lpSuperContext = 0; if (!lpSuperContext)
      lpSuperContext = GetIntsAddress(__ExecutionContext);

   double value = iCustom(NULL, timeframe, "SuperTrend",
                          atrPeriods,                                      // int    ATR.Periods
                          smaPeriods,                                      // int    SMA.Periods

                          Blue,                                            // color  Color.UpTrend
                          Red,                                             // color  Color.DownTrend
                          CLR_NONE,                                        // color  Color.Channel
                          CLR_NONE,                                        // color  Color.MovingAverage
                          "Line",                                          // string Draw.Type
                          1,                                               // int    Draw.Width
                          -1,                                              // int    Max.Values
                          "",                                              // string ____________________
                          "off",                                           // string Signal.onTrendChange
                          "off",                                           // string Signal.Sound
                          "off",                                           // string Signal.Mail.Receiver
                          "off",                                           // string Signal.SMS.Receiver
                          "",                                              // string ____________________
                          lpSuperContext,                                  // int    __SuperContext__

                          iBuffer, iBar);

   int error = GetLastError();
   if (error != NO_ERROR) {
      if (error != ERS_HISTORY_UPDATE)
         return(!catch("iSuperTrend(1)", error));
      warn("iSuperTrend(2)  "+ PeriodDescription(ifInt(!timeframe, Period(), timeframe)) +" (tick="+ Tick +")", ERS_HISTORY_UPDATE);
   }

   error = __ExecutionContext[EC.mqlError];                                // TODO: synchronize execution contexts
   if (!error)
      return(value);
   return(!SetLastError(error));
}


/**
 * Load the "TriEMA" indicator and return a value.
 *
 * @param  int    timeframe    - timeframe to load the indicator (NULL: the current timeframe)
 * @param  int    periods      - indicator parameter
 * @param  string appliedPrice - indicator parameter
 * @param  int    iBuffer      - indicator buffer index of the value to return
 * @param  int    iBar         - bar index of the value to return
 *
 * @return double - indicator value or NULL in case of errors
 */
double iTriEMA(int timeframe, int periods, string appliedPrice, int iBuffer, int iBar) {
   static int lpSuperContext = 0; if (!lpSuperContext)
      lpSuperContext = GetIntsAddress(__ExecutionContext);

   double value = iCustom(NULL, timeframe, "TriEMA",
                          periods,                                         // int    MA.Periods
                          appliedPrice,                                    // string MA.AppliedPrice

                          Blue,                                            // color  Color.UpTrend
                          Red,                                             // color  Color.DownTrend
                          "Line",                                          // string Draw.Type
                          1,                                               // int    Draw.Width
                          -1,                                              // int    Max.Values
                          "",                                              // string ____________________
                          "off",                                           // string Signal.onTrendChange
                          "off",                                           // string Signal.Sound
                          "off",                                           // string Signal.Mail.Receiver
                          "off",                                           // string Signal.SMS.Receiver
                          "",                                              // string ____________________
                          lpSuperContext,                                  // int    __SuperContext__

                          iBuffer, iBar);

   int error = GetLastError();
   if (error != NO_ERROR) {
      if (error != ERS_HISTORY_UPDATE)
         return(!catch("iTriEMA(1)", error));
      warn("iTriEMA(2)  "+ PeriodDescription(ifInt(!timeframe, Period(), timeframe)) +" (tick="+ Tick +")", ERS_HISTORY_UPDATE);
   }

   error = __ExecutionContext[EC.mqlError];                                // TODO: synchronize execution contexts
   if (!error)
      return(value);
   return(!SetLastError(error));
}


/**
 * Load the "Trix" indicator and return a value.
 *
 * @param  int    timeframe    - timeframe to load the indicator (NULL: the current timeframe)
 * @param  int    periods      - indicator parameter
 * @param  string appliedPrice - indicator parameter
 * @param  int    iBuffer      - indicator buffer index of the value to return
 * @param  int    iBar         - bar index of the value to return
 *
 * @return double - indicator value or NULL in case of errors
 */
double iTrix(int timeframe, int periods, string appliedPrice, int iBuffer, int iBar) {
   static int lpSuperContext = 0; if (!lpSuperContext)
      lpSuperContext = GetIntsAddress(__ExecutionContext);

   double value = iCustom(NULL, timeframe, "Trix",
                          periods,                                         // int    EMA.Periods
                          appliedPrice,                                    // string EMA.AppliedPrice

                          DodgerBlue,                                      // color  MainLine.Color
                          1,                                               // int    MainLine.Width
                          LimeGreen,                                       // color  Histogram.Color.Upper
                          Red,                                             // color  Histogram.Color.Lower
                          2,                                               // int    Histogram.Style.Width
                          -1,                                              // int    Max.Values
                          "",                                              // string _____________________
                          lpSuperContext,                                  // int    __SuperContext__

                          iBuffer, iBar);

   int error = GetLastError();
   if (error != NO_ERROR) {
      if (error != ERS_HISTORY_UPDATE)
         return(!catch("iTrix(1)", error));
      warn("iTrix(2)  "+ PeriodDescription(ifInt(!timeframe, Period(), timeframe)) +" (tick="+ Tick +")", ERS_HISTORY_UPDATE);
   }

   error = __ExecutionContext[EC.mqlError];                                // TODO: synchronize execution contexts
   if (!error)
      return(value);
   return(!SetLastError(error));
}


/**
 * Suppress compiler warnings.
 */
void __DummyCalls() {
   bool   bNull;
   int    iNull, iNulls[];
   double dNull;
   string sNull, sNulls[];

   __CHART();
   __LOG();
   __NAME();
   _bool(NULL);
   _double(NULL);
   _EMPTY();
   _EMPTY_STR();
   _EMPTY_VALUE();
   _false();
   _int(NULL);
   _last_error();
   _NaT();
   _NO_ERROR();
   _NULL();
   _string(NULL);
   _true();
   Abs(NULL);
   AccountAlias(NULL, NULL);
   AccountCompanyId(NULL);
   AccountNumberFromAlias(NULL, NULL);
   ArrayUnshiftString(sNulls, NULL);
   catch(NULL, NULL, NULL);
   Ceil(NULL);
   Chart.DeleteValue(NULL);
   Chart.Expert.Properties();
   Chart.Objects.UnselectAll();
   Chart.Refresh();
   Chart.RestoreBool(NULL, bNull);
   Chart.RestoreColor(NULL, iNull);
   Chart.RestoreDouble(NULL, dNull);
   Chart.RestoreInt(NULL, iNull);
   Chart.RestoreString(NULL, sNull);
   Chart.SendTick(NULL);
   Chart.StoreBool(NULL, NULL);
   Chart.StoreColor(NULL, NULL);
   Chart.StoreDouble(NULL, NULL);
   Chart.StoreInt(NULL, NULL);
   Chart.StoreString(NULL, NULL);
   ColorToHtmlStr(NULL);
   ColorToStr(NULL);
   CompareDoubles(NULL, NULL);
   CopyMemory(NULL, NULL, NULL);
   CountDecimals(NULL);
   CreateString(NULL);
   DateTime(NULL);
   debug(NULL);
   DebugMarketInfo(NULL);
   DeinitReason();
   Div(NULL, NULL);
   DoubleToStrMorePrecision(NULL, NULL);
   DummyCalls();
   EnumChildWindows(NULL);
   EQ(NULL, NULL);
   ErrorDescription(NULL);
   EventListener.NewTick();
   FileAccessModeToStr(NULL);
   Floor(NULL);
   ForceAlert(NULL);
   GE(NULL, NULL);
   GetAccountConfigPath(NULL, NULL);
   GetCommission();
   GetConfigBool(NULL, NULL);
   GetConfigColor(NULL, NULL);
   GetConfigDouble(NULL, NULL);
   GetConfigInt(NULL, NULL);
   GetConfigString(NULL, NULL);
   GetConfigStringRaw(NULL, NULL);
   GetCurrency(NULL);
   GetCurrencyId(NULL);
   GetExternalAssets(NULL, NULL);
   GetFxtTime();
   GetIniBool(NULL, NULL, NULL);
   GetIniColor(NULL, NULL, NULL);
   GetIniDouble(NULL, NULL, NULL);
   GetIniInt(NULL, NULL, NULL);
   GetMqlFilesPath();
   GetServerTime();
   GT(NULL, NULL);
   HandleCommands();
   HistoryFlagsToStr(NULL);
   iALMA(NULL, NULL, NULL, NULL, NULL, NULL, NULL);
   iFATL(NULL, NULL, NULL);
   ifBool(NULL, NULL, NULL);
   ifDouble(NULL, NULL, NULL);
   ifInt(NULL, NULL, NULL);
   ifString(NULL, NULL, NULL);
   iHalfTrend(NULL, NULL, NULL, NULL);
   iJMA(NULL, NULL, NULL, NULL, NULL, NULL);
   iMACDX(NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
   iMovingAverage(NULL, NULL, NULL, NULL, NULL, NULL);
   init.IsLogEnabled();
   init.LogErrorsToMail();
   init.LogErrorsToSMS();
   init.LogWarningsToMail();
   init.LogWarningsToSMS();
   InitReasonDescription(NULL);
   iNonLagMA(NULL, NULL, NULL, NULL, NULL);
   IntegerToHexString(NULL);
   iRSIX(NULL, NULL, NULL, NULL, NULL);
   IsAccountConfigKey(NULL, NULL);
   iSATL(NULL, NULL, NULL);
   IsConfigKey(NULL, NULL);
   IsCurrency(NULL);
   IsDemoFix();
   IsEmpty(NULL);
   IsEmptyString(NULL);
   IsEmptyValue(NULL);
   IsError(NULL);
   IsExpert();
   IsIndicator();
   IsInfinity(NULL);
   IsLastError();
   IsLeapYear(NULL);
   IsLibrary();
   IsLimitOrderType(NULL);
   IsLongOrderType(NULL);
   IsNaN(NULL);
   IsNaT(NULL);
   IsOrderType(NULL);
   IsPendingOrderType(NULL);
   IsScript();
   IsShortAccountCompany(NULL);
   IsShortOrderType(NULL);
   iStochasticOfRSI(NULL, NULL, NULL, NULL, NULL, NULL, NULL);
   IsStopOrderType(NULL);
   IsSuperContext();
   IsTicket(NULL);
   iSuperSmoother(NULL, NULL, NULL, NULL, NULL);
   iSuperTrend(NULL, NULL, NULL, NULL, NULL);
   iTriEMA(NULL, NULL, NULL, NULL, NULL);
   iTrix(NULL, NULL, NULL, NULL, NULL);
   LE(NULL, NULL);
   log(NULL);
   LogTicket(NULL);
   LT(NULL, NULL);
   MaMethodDescription(NULL);
   MaMethodToStr(NULL);
   MarketWatch.Symbols();
   MathDiv(NULL, NULL);
   MathModFix(NULL, NULL);
   Max(NULL, NULL);
   MessageBoxButtonToStr(NULL);
   Min(NULL, NULL);
   ModuleTypesToStr(NULL);
   MovingAverageMethodDescription(NULL);
   MovingAverageMethodToStr(NULL);
   MQL.IsDirectory(NULL);
   MQL.IsFile(NULL);
   NameToColor(NULL);
   NE(NULL, NULL);
   NormalizeLots(NULL);
   NumberToStr(NULL, NULL);
   OrderPop(NULL);
   OrderPush(NULL);
   PeriodFlag();
   PeriodFlagsToStr(NULL);
   PipValue();
   PipValueEx(NULL);
   PlaySoundEx(NULL);
   PlaySoundOrFail(NULL);
   Pluralize(NULL);
   PriceTypeDescription(NULL);
   PriceTypeToStr(NULL);
   ProgramInitReason();
   QuoteStr(NULL);
   RefreshExternalAssets(NULL, NULL);
   ResetLastError();
   RGBStrToColor(NULL);
   Round(NULL);
   RoundCeil(NULL);
   RoundEx(NULL);
   RoundFloor(NULL);
   SelectTicket(NULL, NULL);
   SendChartCommand(NULL, NULL, NULL);
   SendEmail(NULL, NULL, NULL, NULL);
   SendSMS(NULL, NULL);
   SetLastError(NULL, NULL);
   ShellExecuteErrorDescription(NULL);
   ShortAccountCompany();
   ShortAccountCompanyFromId(NULL);
   Sign(NULL);
   start.RelaunchInputDialog();
   StrCapitalize(NULL);
   StrCompareI(NULL, NULL);
   StrContains(NULL, NULL);
   StrContainsI(NULL, NULL);
   StrEndsWithI(NULL, NULL);
   StrFindR(NULL, NULL);
   StrIsDigit(NULL);
   StrIsEmailAddress(NULL);
   StrIsInteger(NULL);
   StrIsNumeric(NULL);
   StrIsPhoneNumber(NULL);
   StrLeft(NULL, NULL);
   StrLeftPad(NULL, NULL);
   StrLeftTo(NULL, NULL);
   StrPadLeft(NULL, NULL);
   StrPadRight(NULL, NULL);
   StrRepeat(NULL, NULL);
   StrReplace(NULL, NULL, NULL);
   StrReplaceR(NULL, NULL, NULL);
   StrRight(NULL, NULL);
   StrRightFrom(NULL, NULL);
   StrRightPad(NULL, NULL);
   StrStartsWithI(NULL, NULL);
   StrSubstr(NULL, NULL);
   StrToBool(NULL);
   StrToHexStr(NULL);
   StrToLower(NULL);
   StrToMaMethod(NULL);
   StrToMovingAverageMethod(NULL);
   StrToOperationType(NULL);
   StrToPeriod(NULL);
   StrToPriceType(NULL);
   StrToTimeframe(NULL);
   StrToTradeDirection(NULL);
   StrToUpper(NULL);
   StrTrim(NULL);
   StrTrimLeft(NULL);
   StrTrimRight(NULL);
   SumInts(iNulls);
   SwapCalculationModeToStr(NULL);
   Tester.GetBarModel();
   Tester.IsPaused();
   Tester.IsStopped();
   Tester.Pause();
   Tester.Stop();
   This.IsTesting();
   TimeCurrentEx();
   TimeDayFix(NULL);
   TimeDayOfWeekFix(NULL);
   TimeframeFlag();
   TimeFXT();
   TimeGMT();
   TimeServer();
   TimeYearFix(NULL);
   Toolbar.Experts(NULL);
   TradeCommandToStr(NULL);
   UninitializeReasonDescription(NULL);
   UrlEncode(NULL);
   WaitForTicket(NULL);
   warn(NULL);
   WriteIniString(NULL, NULL, NULL, NULL);
}


// --------------------------------------------------------------------------------------------------------------------------------------------------


#import "rsfLib1.ex4"
   bool     onBarOpen();
   bool     onCommand(string data[]);

   bool     AquireLock(string mutexName, bool wait);
   int      ArrayPopInt(int array[]);
   int      ArrayPushInt(int array[], int value);
   int      ArrayPushString(string array[], string value);
   string   CharToHexStr(int char);
   string   CreateTempFile(string path, string prefix);
   string   DoubleToStrEx(double value, int digits);
   int      Explode(string input, string separator, string results[], int limit);
   int      GetAccountNumber();
   string   GetHostName();
   int      GetIniKeys(string fileName, string section, string keys[]);
   string   GetServerName();
   string   GetServerTimezone();
   string   GetWindowText(int hWnd);
   datetime GmtToFxtTime(datetime gmtTime);
   datetime GmtToServerTime(datetime gmtTime);
   int      InitializeStringBuffer(string buffer[], int length);
   bool     ReleaseLock(string mutexName);
   bool     ReverseStringArray(string array[]);
   datetime ServerToGmtTime(datetime serverTime);
   string   StdSymbol();

#import "rsfExpander.dll"
   string   ec_ModuleName(int ec[]);
   string   ec_ProgramName(int ec[]);
   int      ec_SetMqlError(int ec[], int lastError);
   string   EXECUTION_CONTEXT_toStr(int ec[], int outputDebug);
   int      LeaveContext(int ec[]);

#import "kernel32.dll"
   int      GetCurrentProcessId();
   int      GetCurrentThreadId();
   int      GetPrivateProfileIntA(string lpSection, string lpKey, int nDefault, string lpFileName);
   void     OutputDebugStringA(string lpMessage);
   void     RtlMoveMemory(int destAddress, int srcAddress, int bytes);
   int      WinExec(string lpCmdLine, int cmdShow);
   bool     WritePrivateProfileStringA(string lpSection, string lpKey, string lpValue, string lpFileName);

#import "user32.dll"
   int      GetAncestor(int hWnd, int cmd);
   int      GetClassNameA(int hWnd, string lpBuffer, int bufferSize);
   int      GetDlgCtrlID(int hWndCtl);
   int      GetDlgItem(int hDlg, int itemId);
   int      GetParent(int hWnd);
   int      GetTopWindow(int hWnd);
   int      GetWindow(int hWnd, int cmd);
   int      GetWindowThreadProcessId(int hWnd, int lpProcessId[]);
   bool     IsWindow(int hWnd);
   int      MessageBoxA(int hWnd, string lpText, string lpCaption, int style);
   bool     PostMessageA(int hWnd, int msg, int wParam, int lParam);
   int      RegisterWindowMessageA(string lpString);
   int      SendMessageA(int hWnd, int msg, int wParam, int lParam);

#import "winmm.dll"
   bool     PlaySoundA(string lpSound, int hMod, int fSound);
#import
