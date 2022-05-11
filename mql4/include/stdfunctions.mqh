/**
 * Global functions
 */
#include <configuration.mqh>
#include <log.mqh>
#include <metaquotes.mqh>
#include <rsfMT4Expander.mqh>


/**
 * Set the last error code of the MQL module. If called in a library the error will bubble up to the program's main module.
 * If called in an indicator loaded by iCustom() the error will bubble up to the caller of iCustom(). The error code NO_ERROR
 * will not bubble up.
 *
 * @param  int error            - error code
 * @param  int param [optional] - any value (ignored)
 *
 * @return int - the same error
 */
int SetLastError(int error, int param = NULL) {
   last_error = ec_SetMqlError(__ExecutionContext, error);
   if (last_error && IsExpert())
      CheckErrors("SetLastError(1)");                             // update __STATUS_OFF in experts
   return(error);
}


/**
 * Return a readable version of an MQL error code.
 *
 * @param  int error - MQL error code or mapped Win32 error code
 *
 * @return string
 */
string ErrorToStr(int error) {
   return(ErrorToStrA(error));
}


/**
 * Return the description of an error code.
 *
 * @param  int error - MQL error code or mapped Win32 error code
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
      case ERR_NO_MQLERROR                : return("never generated error"                                     );    //   4000 never generated error
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
      case ERR_INCOMPATIBLE_ARRAY         : return("incompatible arrays"                                       );    //   4056 incompatible array
      case ERR_GLOBAL_VARIABLES_PROCESSING: return("global variables processing error"                         );    //   4057
      case ERR_GLOBAL_VARIABLE_NOT_FOUND  : return("global variable not found"                                 );    //   4058
      case ERR_FUNC_NOT_ALLOWED_IN_TESTER : return("function not allowed in tester"                            );    //   4059
      case ERR_FUNCTION_NOT_CONFIRMED     : return("function not confirmed"                                    );    //   4060
      case ERR_SEND_MAIL_ERROR            : return("send mail error"                                           );    //   4061
      case ERR_STRING_PARAMETER_EXPECTED  : return("string parameter expected"                                 );    //   4062
      case ERR_INTEGER_PARAMETER_EXPECTED : return("integer parameter expected"                                );    //   4063
      case ERR_DOUBLE_PARAMETER_EXPECTED  : return("double parameter expected"                                 );    //   4064
      case ERR_ARRAY_AS_PARAMETER_EXPECTED: return("array parameter expected"                                  );    //   4065
      case ERS_HISTORY_UPDATE             : return("requested history is updating"                             );    //   4066 non-terminating status
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
      case ERR_TERMINAL_AUTOTRADE_DISABLED: return("automated trading disabled in terminal"                    );    //   4109
      case ERR_PROGRAM_LONGS_DISABLED     : return("long trades disabled for program"                          );    //   4110
      case ERR_PROGRAM_SHORTS_DISABLED    : return("short trades disabled for program"                         );    //   4111
      case ERR_BROKER_AUTOTRADE_DISABLED  : return("automated trading disabled by broker"                      );    //   4112
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
      case ERS_EXECUTION_STOPPING         : return("program execution stopping"                                );    //  65539   non-terminating status
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
      case ERS_TERMINAL_NOT_YET_READY     : return("terminal not yet ready"                                    );    //  65555   non-terminating status
      case ERR_TOTAL_POSITION_NOT_FLAT    : return("total position encountered when flat position was expected");    //  65556
      case ERR_UNDEFINED_STATE            : return("undefined state or behavior"                               );    //  65557
      case ERR_STOP_DISTANCE_VIOLATED     : return("stop or limit price violate the broker's stop distance"    );    //  65558
      case ERR_MARGIN_STOPOUT             : return("margin stopout"                                            );    //  65559
   }
   return(StringConcatenate("unknown error (", error, ")"));
}


/**
 * Replace all occurences of a substring in a string by another string.
 *
 * @param  string value                - string to process
 * @param  string search               - search string
 * @param  string replace              - replacement string
 * @param  bool   recursive [optional] - whether to replace recursively (default: no)
 *
 * @return string - resulting string or an empty string in case of errors
 */
string StrReplace(string value, string search, string replace, bool recursive = false) {
   recursive = recursive!=0;
   if (!StringLen(value))  return(value);
   if (!StringLen(search)) return(value);
   if (search == replace)  return(value);

   string result="", lastResult="";

   if (!recursive) {
      int from=0, found=StringFind(value, search);

      while (found > -1) {
         result = StringConcatenate(result, StrSubstr(value, from, found-from), replace);
         from   = found + StringLen(search);
         found  = StringFind(value, search, from);
      }
      result = StringConcatenate(result, StrSubstr(value, from));
   }
   else {
      int counter = 0;
      result = value;

      while (result != lastResult) {
         lastResult = result;
         result = StrReplace(result, search, replace);
         counter++;
         if (counter >= 100) {
            catch("StrReplace(1)  more than 100 replacements, breaking assumed infinite loop (search="+ DoubleQuoteStr(search) +", replace="+ DoubleQuoteStr(replace) +")", ERR_RUNTIME_ERROR);
            result = "";
            break;
         }
      }
   }

   return(result);
}


/**
 * Drop-in replacement for the flawed built-in MQL function StringSubstr().
 *
 * Fixes the case StringSubstr(string, start, length=0) where the built-in function returns the whole string.
 * Additionally supports negative values for the parameters "start" and "length".
 *
 * @param  string str    - string to process
 * @param  int    start  - start index; if negative counted from the end of the string
 * @param  int    length - number of chars to return; if positive chars on the right side, if negative chars on the left side
 *                         of the start index
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
#define SND_FILENAME     0x20000       // parameter is a file name


/**
 * Dropin-replacement for the built-in MQL function PlaySound().
 *
 * Plays a sound asynchronously (instead of synchronously and UI blocking as the terminal does). Also plays a sound if the
 * terminal doesn't support it in the current context (e.g. in tester).
 *
 * @param  string soundfile
 *
 * @return bool - success status
 */
bool PlaySoundEx(string soundfile) {
   string filename = StrReplace(soundfile, "/", "\\");
   string fullName = TerminalPath() +"\\sounds\\"+ filename;

   if (!IsFile(fullName, MODE_SYSTEM)) {
      fullName = GetTerminalDataPathA() +"\\sounds\\"+ filename;
      if (!IsFile(fullName, MODE_SYSTEM)) {
         if (IsLogNotice()) logNotice("PlaySoundEx(1)  sound file not found: "+ DoubleQuoteStr(soundfile), ERR_FILE_NOT_FOUND);
         return(false);
      }
   }
   PlaySoundA(fullName, NULL, SND_FILENAME|SND_ASYNC);
   return(!catch("PlaySoundEx(2)"));
}


/**
 * Return a pluralized string corresponding to the specified number of items.
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
 * Display an alert even if not supported by the terminal in the current context (e.g. in tester).
 *
 * @param  string message
 *
 * Notes: This function must not call .EX4 library functions. Calling DLL functions is fine.
 */
void ForceAlert(string message) {
   debug(message);                                                          // send the message to the debug output

   string sPeriod = PeriodDescription();
   Alert(Symbol(), ",", sPeriod, ": ", FullModuleName(), ":  ", message);   // the message shows up in the terminal log

   if (IsTesting()) {
      // in tester no Alert() dialog was displayed
      string sCaption = "Strategy Tester "+ Symbol() +","+ sPeriod;
      string sMessage = TimeToStr(TimeCurrent(), TIME_FULL) + NL + message;

      PlaySoundEx("alert.wav");
      MessageBoxEx(sCaption, sMessage, MB_ICONERROR|MB_OK|MB_DONT_LOG);
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
   string prefix = Symbol() +","+ PeriodDescription();

   if (!StrContains(caption, prefix))
      caption = prefix +" - "+ caption;

   bool win32 = false;
   if      (IsTesting())                                                                                   win32 = true;
   else if (IsIndicator())                                                                                 win32 = true;
   else if (__ExecutionContext[EC.programCoreFunction]==CF_INIT && UninitializeReason()==REASON_RECOMPILE) win32 = true;

   if (!win32) int button = MessageBox(message, caption, flags);
   else            button = MessageBoxA(GetTerminalMainWindow(), message, caption, flags|MB_TOPMOST|MB_SETFOREGROUND);

   if (!(flags & MB_DONT_LOG)) {
      logDebug("MessageBoxEx(1)  "+ message +" (response: "+ MessageBoxButtonToStr(button) +")");
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
 * Whether the current program is executed in the tester or on a test chart with VisualMode=On.
 *
 * Replacement for IsVisualMode() in
 *  - indicators: not supported
 *  - scripts:    not supported
 *  - libraries:  broken (returns always the value of the first test, irrespective of changes)
 *
 * @return bool
 */
bool IsVisualModeFix() {
   return(__ExecutionContext[EC.visualMode] != 0);
}


/**
 * Whether the specified value represents an error.
 *
 * @param  int value
 *
 * @return bool
 */
bool IsError(int value) {
   return(value != NO_ERROR);
}


/**
 * Whether the internal error code of the current MQL module is set.
 *
 * @return bool
 */
bool IsLastError() {
   return(last_error != NO_ERROR);
}


/**
 * Reset the internal error code of the current MQL module.
 *
 * @return int - previous internal error code
 */
int ResetLastError() {
   int error = last_error;
   SetLastError(NO_ERROR);
   return(error);
}


/**
 * Whether the internal MQL error code of the program is set. Covers errors in all MQL modules.
 *
 * @return bool
 */
bool IsMQLError() {
   return(__ExecutionContext[EC.mqlError] != NO_ERROR);
}


/**
 * Whether the internal DLL error code of the program is set. Covers errors in the MT4Expander DLL module.
 *
 * @return bool
 */
bool IsDLLError() {
   return(__ExecutionContext[EC.dllError] != NO_ERROR);
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
 * @param  int    ticket                      - ticket
 * @param  string caller           [optional] - location identifier of the caller (default: none)
 * @param  bool   pushTicket       [optional] - whether to push the selection onto the order selection stack (default: no)
 * @param  bool   onErrorPopTicket [optional] - whether to restore the previously selected ticket in case of errors
 *                                              (default: yes if pushTicket=TRUE, no if pushTicket=FALSE)
 * @return bool - success status
 */
bool SelectTicket(int ticket, string caller="", bool pushTicket=false, bool onErrorPopTicket=false) {
   pushTicket       = pushTicket!=0;
   onErrorPopTicket = onErrorPopTicket!=0;
   if (caller != "") caller = caller +"->";

   if (pushTicket) {
      if (!OrderPush(caller +"SelectTicket(1)")) return(false);
      onErrorPopTicket = true;
   }

   if (OrderSelect(ticket, SELECT_BY_TICKET))
      return(true);                                   // success

   if (onErrorPopTicket)                              // error
      if (!OrderPop(caller +"SelectTicket(2)")) return(false);

   int error = GetLastError();
   if (!error)
      error = ERR_INVALID_TICKET;
   return(!catch(caller +"SelectTicket(3)   ticket="+ ticket, error));
}


/**
 * Generate a log message with all order data of a ticket. Replacement for the limited built-in function OrderPrint().
 *
 * @param  int  ticket
 *
 * @return string - log message or an empty string in case of errors
 */
string OrderLogMessage(int ticket) {
   if (!SelectTicket(ticket, "OrderLogMessage(1)", O_PUSH))
      return("");

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
   string   priceFormat = StringConcatenate(",'R.", pipDigits, ifString(digits==pipDigits, "", "'"));
   string   message     = StringConcatenate("#", ticket, " ", OrderTypeDescription(type), " ", NumberToStr(lots, ".1+"), " ", symbol, " at ", NumberToStr(openPrice, priceFormat), " (", TimeToStr(openTime, TIME_FULL), "), sl=", ifString(stopLoss!=0, NumberToStr(stopLoss, priceFormat), "0"), ", tp=", ifString(takeProfit!=0, NumberToStr(takeProfit, priceFormat), "0"), ",", ifString(closeTime, " closed at "+ NumberToStr(closePrice, priceFormat) +" ("+ TimeToStr(closeTime, TIME_FULL) +"),", ""), " commission=", DoubleToStr(commission, 2), ", swap=", DoubleToStr(swap, 2), ", profit=", DoubleToStr(profit, 2), ", magicNumber=", magic, ", comment=", DoubleQuoteStr(comment));

   if (OrderPop("OrderLogMessage(2)"))
      return(message);
   return("");
}


/**
 * Append the currently selected order ticket to the order stack.
 *
 * @param  string caller [optional] - location identifier of the caller (default: none)
 *
 * @return bool - success status
 */
bool OrderPush(string caller = "") {
   int ticket = OrderTicket();

   int error = GetLastError();
   if (error && error!=ERR_NO_TICKET_SELECTED)
      return(!catch(caller +"->OrderPush(1)", error));

   ArrayPushInt(__orderStack, ticket);
   return(true);
}


/**
 * Remove the last order ticket from the order stack and restore (i.e. select) it.
 *
 * @param  string caller [optional] - location identifier of the caller (default: none)
 *
 * @return bool - success status
 */
bool OrderPop(string caller = "") {
   int ticket = ArrayPopInt(__orderStack);
   if (ticket > 0)
      return(SelectTicket(ticket, caller +"->OrderPop(1)"));

   OrderSelect(0, SELECT_BY_TICKET);

   int error = GetLastError();
   if (error && error!=ERR_NO_TICKET_SELECTED)
      return(!catch(caller +"->OrderPop(2)", error));
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
      return(!catch("WaitForTicket(1)  illegal parameter ticket: "+ ticket, ERR_INVALID_PARAMETER));

   if (!select) {
      if (!OrderPush("WaitForTicket(2)")) return(false);
   }

   int i, delay=100;                                                 // je 0.1 Sekunden warten

   while (!OrderSelect(ticket, SELECT_BY_TICKET)) {
      if (IsTesting())       logWarn("WaitForTicket(3)  #"+ ticket +" not yet accessible");
      else if (i && !(i%10)) logWarn("WaitForTicket(4)  #"+ ticket +" not yet accessible after "+ DoubleToStr(i*delay/1000., 1) +" s");
      Sleep(delay);
      i++;
   }

   if (!select) {
      if (!OrderPop("WaitForTicket(5)")) return(false);
   }

   return(true);
}


/**
 * Concatenate the values of a string array using the specified separator.
 *
 * @param  string values[]             - string array
 * @param  string separator [optional] - separator (default: ", ")
 *
 * @return string - concatenated string or an empty string in case of errors
 */
string JoinStrings(string values[], string separator = ", ") {
   if (ArrayDimension(values) > 1) return(_EMPTY_STR(catch("JoinStrings(1)  too many dimensions of parameter values: "+ ArrayDimension(values), ERR_INCOMPATIBLE_ARRAY)));

   string result = "";
   int size = ArraySize(values);

   for (int i=0; i < size; i++) {
      if (StrIsNull(values[i])) result = StringConcatenate(result, "NULL",    separator);
      else                      result = StringConcatenate(result, values[i], separator);
   }
   if (size > 0)
      result = StrLeft(result, -StringLen(separator));

   return(result);
}


/**
 * Return the current symbol's pip value for the specified lot amount.
 *
 * @param  double lots           [optional] - lot amount (default: 1 lot)
 * @param  bool   suppressErrors [optional] - whether to suppress runtime errors (default: no)
 *
 * @return double - pip value or NULL (0) in case of errors
 */
double PipValue(double lots=1.0, bool suppressErrors=false) {
   suppressErrors = suppressErrors!=0;

   static double tickSize;
   if (!tickSize) {
      tickSize = MarketInfo(Symbol(), MODE_TICKSIZE);                // schlägt fehl, wenn kein Tick vorhanden ist
      int error = GetLastError();                                    // Symbol (noch) nicht subscribed (Start, Account-/Templatewechsel), kann noch "auftauchen"
      if (IsError(error)) {                                          // ERR_SYMBOL_NOT_AVAILABLE: synthetisches Symbol im Offline-Chart
         if (!suppressErrors) catch("PipValue(1)", error);
         return(0);
      }
      if (!tickSize) {
         if (!suppressErrors) catch("PipValue(2)  illegal MarketInfo(MODE_TICKSIZE=0)", ERR_INVALID_MARKET_DATA);
         return(0);
      }
   }

   static double staticTickValue;
   static bool   isResolved, isConstant, isCorrect, isCalculatable, doWarn;

   if (!isResolved) {
      if (StrEndsWith(Symbol(), AccountCurrency())) {                // TickValue ist constant and kann gecacht werden
         staticTickValue = MarketInfo(Symbol(), MODE_TICKVALUE);
         error = GetLastError();
         if (error != NO_ERROR) {
            if (!suppressErrors) catch("PipValue(3)", error);
            return(0);
         }
         if (!staticTickValue) {
            if (!suppressErrors) catch("PipValue(4)  illegal MarketInfo(MODE_TICKVALUE=0)", ERR_INVALID_MARKET_DATA);
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
      return(Pip/tickSize * staticTickValue * lots);

   // dynamic but correct value
   if (isCorrect) {
      double dynamicTickValue = MarketInfo(Symbol(), MODE_TICKVALUE);
      error = GetLastError();
      if (error != NO_ERROR) {
         if (!suppressErrors) catch("PipValue(5)", error);
         return(0);
      }
      if (!dynamicTickValue) {
         if (!suppressErrors) catch("PipValue(6)  illegal MarketInfo(MODE_TICKVALUE=0)", ERR_INVALID_MARKET_DATA);
         return(0);
      }
      return(Pip/tickSize * dynamicTickValue * lots);
   }

   // dynamic and incorrect value
   if (isCalculatable) {                                             // TickValue can be calculated
      if      (Symbol() == "EURAUD") dynamicTickValue =   1/Close[0];
      else if (Symbol() == "EURCAD") dynamicTickValue =   1/Close[0];
      else if (Symbol() == "EURCHF") dynamicTickValue =   1/Close[0];
      else if (Symbol() == "EURGBP") dynamicTickValue =   1/Close[0];
      else if (Symbol() == "EURUSD") dynamicTickValue =   1/Close[0];

      else if (Symbol() == "GBPAUD") dynamicTickValue =   1/Close[0];
      else if (Symbol() == "GBPCAD") dynamicTickValue =   1/Close[0];
      else if (Symbol() == "GBPCHF") dynamicTickValue =   1/Close[0];
      else if (Symbol() == "GBPUSD") dynamicTickValue =   1/Close[0];

      else if (Symbol() == "AUDJPY") dynamicTickValue = 100/Close[0];
      else if (Symbol() == "CADJPY") dynamicTickValue = 100/Close[0];
      else if (Symbol() == "CHFJPY") dynamicTickValue = 100/Close[0];
      else if (Symbol() == "EURJPY") dynamicTickValue = 100/Close[0];
      else if (Symbol() == "GBPJPY") dynamicTickValue = 100/Close[0];
      else if (Symbol() == "USDJPY") dynamicTickValue = 100/Close[0];
      else                           return(!catch("PipValue(7)  calculation of TickValue for "+ Symbol() +" in tester not yet implemented", ERR_NOT_IMPLEMENTED));
      return(Pip/tickSize * dynamicTickValue * lots);                // return the calculated value
   }

   // dynamic and incorrect value: we must live with the approximated online value
   dynamicTickValue = MarketInfo(Symbol(), MODE_TICKVALUE);
   error = GetLastError();
   if (error != NO_ERROR) {
      if (!suppressErrors) catch("PipValue(8)", error);
      return(0);
   }
   if (!dynamicTickValue) {
      if (!suppressErrors) catch("PipValue(9)  illegal MarketInfo(MODE_TICKVALUE=0)", ERR_INVALID_MARKET_DATA);
      return(0);
   }

   // emit a single warning at test start
   if (doWarn) {
      string message = "Exact tickvalue not available."+ NL
                      +"The test will use the current online tickvalue ("+ dynamicTickValue +") which is an approximation. "
                      +"Test with another account currency if you need exact values.";
      logWarn("PipValue(10)  "+ message);
      doWarn = false;
   }
   return(Pip/tickSize * dynamicTickValue * lots);
}


/**
 * Return a symbol's pip value for the specified lot amount. Errors are returned and optionally logged.
 *
 * @param  _In_  string symbol            - symbol
 * @param  _In_  double lots              - lot amount
 * @param  _Out_ int    &error            - variable receiving the error status
 * @param  _In_  string caller [optional] - location identifier of the caller, controls logging behavior:
 *                                           if specified errors are logged
 *                                           if not specified errors are not logged (default)
 *
 * @return double - pip value or NULL (0) in case of errors, check parameter 'error'
 */
double PipValueEx(string symbol, double lots, int &error, string caller = "") {
   double tickSize = MarketInfoEx(symbol, MODE_TICKSIZE, error, caller);
   if (error != NO_ERROR) {
      if (caller!="" && IsLogDebug()) logDebug(caller +"->PipValueEx(1)", error);
      return(NULL);
   }

   double tickValue = MarketInfoEx(symbol, MODE_TICKVALUE, error, caller);    // TODO: if (QuoteCurrency == AccountCurrency) { required-only-once }
   if (error != NO_ERROR) {
      if (caller!="" && IsLogDebug()) logDebug(caller +"->PipValueEx(2)", error);
      return(NULL);
   }

   int digits = MarketInfoEx(symbol, MODE_DIGITS, error, caller);             // TODO: the returned digits may be wrong
   if (error != NO_ERROR) {
      if (caller!="" && IsLogDebug()) logDebug(caller +"->PipValueEx(3)", error);
      return(NULL);
   }

   int    pipDigits = digits & (~1);
   double pipSize   = NormalizeDouble(1/MathPow(10, pipDigits), pipDigits);

   return(pipSize/tickSize * tickValue * lots);
}


/**
 * Calculate the current symbol's commission for the specified lotsize.
 *
 * - For tests the commission rate stored in the tester's FXT files is used (always correct).
 * - Online the commission rate configured by the user is used (subject to configuration errors).
 *
 * @param  double lots [optional] - lotsize (default: 1 lot)
 * @param  int    mode [optional] - MODE_MONEY:  in account currency (default)
 *                                  MODE_MARKUP: as price markup in quote currency (independant of lotsize)
 *
 * @return double - commission value or EMPTY (-1) in case of errors
 */
double GetCommission(double lots=1.0, int mode=MODE_MONEY) {
   static double baseCommission = EMPTY_VALUE;
   if (baseCommission == EMPTY_VALUE) {
      bool isCFD = false;
      double value = 0;

      if (This.IsTesting()) {
         value = Test_GetCommission(__ExecutionContext, 1);
      }
      else {
         string section="Commissions", key=Symbol();

         if (IsConfigKey(section, key)) {                         // check exact symbol
            value = GetConfigDouble(section, key);
            if (value < 0) return(_EMPTY(catch("GetCommission(1)  invalid config value ["+ section +"] "+ key +" = "+ NumberToStr(value, ".+"), ERR_INVALID_CONFIG_VALUE)));
         }
         else {
            key = StdSymbol();
            if (IsConfigKey(section, key)) {                      // check mapped symbol
               value = GetConfigDouble(section, key);
               if (value < 0) return(_EMPTY(catch("GetCommission(2)  invalid config value ["+ section +"] "+ key +" = "+ NumberToStr(value, ".+"), ERR_INVALID_CONFIG_VALUE)));
            }
            else if (isCFD) {
               value = 0;                                         // TODO: implement isCFD
            }
            else {
               // query global config
               string company  = GetAccountCompanyId(); if (!StringLen(company)) return(EMPTY);
               int    account  = GetAccountNumber();    if (!account)            return(EMPTY);
               string currency = AccountCurrency();

               if      (IsGlobalConfigKeyA(section, company +"."+ currency +"."+ account)) key = company +"."+ currency +"."+ account;
               else if (IsGlobalConfigKeyA(section, company +"."+ currency))               key = company +"."+ currency;
               else if (IsGlobalConfigKeyA(section, company))                              key = company;

               if (StringLen(key) > 0) {
                  value = GetGlobalConfigDouble(section, key);    // use global config
                  if (value < 0) return(_EMPTY(catch("GetCommission(3)  invalid global config value ["+ section +"] "+ key +" = "+ NumberToStr(value, ".+"), ERR_INVALID_CONFIG_VALUE)));
               }
               else if (IsLogInfo()) logInfo("GetCommission(4)  commission configuration for account \""+ company +"."+ currency +"."+ account +"\" not found, using default 0.00");
            }
         }
      }
      baseCommission = value;
   }

   switch (mode) {
      case MODE_MONEY:
         if (lots == 1)
            return(baseCommission);
         return(baseCommission * lots);

      case MODE_MARKUP:
         double pipValue = PipValue(); if (!pipValue) return(EMPTY);
         return(baseCommission/pipValue * Pip);
   }
   return(_EMPTY(catch("GetCommission(3)  invalid parameter mode: "+ mode, ERR_INVALID_PARAMETER)));
}


/**
 * Return the current standard symbol. Shortcut for FindStandardSymbol(Symbol(), strict=false).
 *
 * e.g.: Symbol() => "EURUSDm"; StdSymbol() => "EURUSD"
 *
 * @return string - standard symbol or the current symbol if the standard symbol is not known
 */
string StdSymbol() {
   static string lastSymbol="", lastResult="";

    if (lastResult != "") {
      if (Symbol() == lastSymbol) return(lastResult);
   }
   lastSymbol = Symbol();
   lastResult = FindStandardSymbol(Symbol());

   return(lastResult);
}


/**
 * Find the standard symbol of a broker-specific symbol.
 *
 * e.g.: FindStandardSymbol("EURUSDm") => "EURUSD"
 *
 * @param  string symbol            - broker-specific symbol
 * @param  bool   strict [optional] - value to return if a standard symbol is not known:
 *                                    TRUE  - an empty string
 *                                    FALSE - the same symbol (default)
 *
 * @return string - symbol or an empty string in case of errors
 */
string FindStandardSymbol(string symbol, bool strict = false) {
   strict = strict!=0;
   if (!StringLen(symbol)) return(_EMPTY_STR(catch("FindStandardSymbol(1)  invalid parameter symbol: "+ DoubleQuoteStr(symbol), ERR_INVALID_PARAMETER)));

   string _symbol = StrToUpper(symbol);
   if      (StrEndsWith(_symbol, "_ASK")) _symbol = StrLeft(_symbol, -4);
   else if (StrEndsWith(_symbol, "_AVG")) _symbol = StrLeft(_symbol, -4);

   string result = "";

   switch (StringGetChar(_symbol, 0)) {
      case '_': if      (_symbol=="_BRENT" )   result = "BRENT";
                else if (_symbol=="_DJI"   )   result = "DJIA";
                else if (_symbol=="_DJT"   )   result = "DJTA";
                else if (_symbol=="_N225"  )   result = "NIKKEI";
                else if (_symbol=="_NQ100" )   result = "NASDAQ";
                else if (_symbol=="_NQCOMP")   result = "NASCOMP";
                else if (_symbol=="_SP500" )   result = "SP500";
                else if (_symbol=="_WTI"   )   result = "WTI";
                break;

      case '#': if      (StrStartsWith(_symbol, "#DAX."))    result = "DAX";
                else if (StrStartsWith(_symbol, "#DJ30_"))   result = "DJIA";
                else if (StrStartsWith(_symbol, "#DJI."))    result = "DJIA";
                else if (StrStartsWith(_symbol, "#DJT."))    result = "DJTA";
                else if (StrStartsWith(_symbol, "#GER40_"))  result = "DAX";
                else if (StrStartsWith(_symbol, "#JP225_"))  result = "NIKKEI";
                else if (StrStartsWith(_symbol, "#SPX."))    result = "SP500";
                else if (StrStartsWith(_symbol, "#US100_"))  result = "NASDAQ";
                else if (StrStartsWith(_symbol, "#US2000_")) result = "RUSSEL";
                else if (StrStartsWith(_symbol, "#US500_"))  result = "SP500";
                break;

      case '0':
      case '1':
      case '2':
      case '3':
      case '4':
      case '5':
      case '6':
      case '7':
      case '8':
      case '9': break;

      case 'A': if      (StrStartsWith(_symbol, "AUDCAD"))     result = "AUDCAD";
                else if (StrStartsWith(_symbol, "AUDCHF"))     result = "AUDCHF";
                else if (StrStartsWith(_symbol, "AUDDKK"))     result = "AUDDKK";
                else if (StrStartsWith(_symbol, "AUDJPY"))     result = "AUDJPY";
                else if (StrStartsWith(_symbol, "AUDLFX"))     result = "AUDLFX";
                else if (StrStartsWith(_symbol, "AUDNZD"))     result = "AUDNZD";
                else if (StrStartsWith(_symbol, "AUDPLN"))     result = "AUDPLN";
                else if (StrStartsWith(_symbol, "AUDSGD"))     result = "AUDSGD";
                else if (StrStartsWith(_symbol, "AUDUSD"))     result = "AUDUSD";
                else if (              _symbol=="AUS200" )     result = "ASX200";
                break;

      case 'B': if      (StrStartsWith(_symbol, "BRENT_"))     result = "BRENT";
                break;

      case 'C': if      (StrStartsWith(_symbol, "CADCHF")  )   result = "CADCHF";
                else if (StrStartsWith(_symbol, "CADJPY")  )   result = "CADJPY";
                else if (StrStartsWith(_symbol, "CADLFX")  )   result = "CADLFX";
                else if (StrStartsWith(_symbol, "CADSGD")  )   result = "CADSGD";
                else if (StrStartsWith(_symbol, "CHFJPY")  )   result = "CHFJPY";
                else if (StrStartsWith(_symbol, "CHFLFX")  )   result = "CHFLFX";
                else if (StrStartsWith(_symbol, "CHFPLN")  )   result = "CHFPLN";
                else if (StrStartsWith(_symbol, "CHFSGD")  )   result = "CHFSGD";
                else if (StrStartsWith(_symbol, "CHFZAR")  )   result = "CHFZAR";
                else if (              _symbol=="CLX5"     )   result = "WTI";
                else if (              _symbol=="CRUDE_OIL")   result = "WTI";
                break;

      case 'D': if      (              _symbol=="DE30")        result = "DAX";
                else if (              _symbol=="DE40")        result = "DAX";
                else if (StrStartsWith(_symbol, "DXY_"))       result = "USDX";
                break;

      case 'E': if      (              _symbol=="ECX"   )      result = "EURX";
                else if (StrStartsWith(_symbol, "EURAUD"))     result = "EURAUD";
                else if (StrStartsWith(_symbol, "EURCAD"))     result = "EURCAD";
                else if (StrStartsWith(_symbol, "EURCCK"))     result = "EURCZK";
                else if (StrStartsWith(_symbol, "EURCZK"))     result = "EURCZK";
                else if (StrStartsWith(_symbol, "EURCHF"))     result = "EURCHF";
                else if (StrStartsWith(_symbol, "EURDKK"))     result = "EURDKK";
                else if (StrStartsWith(_symbol, "EURGBP"))     result = "EURGBP";
                else if (StrStartsWith(_symbol, "EURHKD"))     result = "EURHKD";
                else if (StrStartsWith(_symbol, "EURHUF"))     result = "EURHUF";
                else if (StrStartsWith(_symbol, "EURJPY"))     result = "EURJPY";
                else if (StrStartsWith(_symbol, "EURLFX"))     result = "EURLFX";
                else if (StrStartsWith(_symbol, "EURLVL"))     result = "EURLVL";
                else if (StrStartsWith(_symbol, "EURMXN"))     result = "EURMXN";
                else if (StrStartsWith(_symbol, "EURNOK"))     result = "EURNOK";
                else if (StrStartsWith(_symbol, "EURNZD"))     result = "EURNZD";
                else if (StrStartsWith(_symbol, "EURPLN"))     result = "EURPLN";
                else if (StrStartsWith(_symbol, "EURRUB"))     result = "EURRUB";
                else if (StrStartsWith(_symbol, "EURRUR"))     result = "EURRUB";
                else if (StrStartsWith(_symbol, "EURSEK"))     result = "EURSEK";
                else if (StrStartsWith(_symbol, "EURSGD"))     result = "EURSGD";
                else if (StrStartsWith(_symbol, "EURTRY"))     result = "EURTRY";
                else if (StrStartsWith(_symbol, "EURUSD"))     result = "EURUSD";
                else if (StrStartsWith(_symbol, "EURZAR"))     result = "EURZAR";
                else if (              _symbol=="EURX"  )      result = "EURX";
                break;

      case 'F': break;

      case 'G': if      (StrStartsWith(_symbol, "GBPAUD") )    result = "GBPAUD";
                else if (StrStartsWith(_symbol, "GBPCAD") )    result = "GBPCAD";
                else if (StrStartsWith(_symbol, "GBPCHF") )    result = "GBPCHF";
                else if (StrStartsWith(_symbol, "GBPDKK") )    result = "GBPDKK";
                else if (StrStartsWith(_symbol, "GBPJPY") )    result = "GBPJPY";
                else if (StrStartsWith(_symbol, "GBPLFX") )    result = "GBPLFX";
                else if (StrStartsWith(_symbol, "GBPNOK") )    result = "GBPNOK";
                else if (StrStartsWith(_symbol, "GBPNZD") )    result = "GBPNZD";
                else if (StrStartsWith(_symbol, "GBPPLN") )    result = "GBPPLN";
                else if (StrStartsWith(_symbol, "GBPRUB") )    result = "GBPRUB";
                else if (StrStartsWith(_symbol, "GBPRUR") )    result = "GBPRUB";
                else if (StrStartsWith(_symbol, "GBPSEK") )    result = "GBPSEK";
                else if (StrStartsWith(_symbol, "GBPUSD") )    result = "GBPUSD";
                else if (StrStartsWith(_symbol, "GBPZAR") )    result = "GBPZAR";
                else if (              _symbol=="GER30"   )    result = "DAX";
                else if (              _symbol=="GER40"   )    result = "DAX";
                else if (              _symbol=="GOLD"    )    result = "XAUUSD";
                else if (              _symbol=="GOLDEURO")    result = "XAUEUR";
                break;

      case 'H': if      (StrStartsWith(_symbol, "HKDJPY"))     result = "HKDJPY";
                break;

      case 'I': break;

      case 'J': if      (              _symbol=="JPN225" )     result = "NIKKEI";
                else if (StrStartsWith(_symbol, "JPYLFX"))     result = "JPYLFX";
                break;

      case 'K': break;

      case 'L': if      (StrStartsWith(_symbol, "LFXJPY"))     result = "LFXJPY";
                else if (              _symbol=="LCOX5"  )     result = "BRENT";
                break;

      case 'M': if      (StrStartsWith(_symbol, "MXNJPY"))     result = "MXNJPY";
                break;

      case 'N': if (                   _symbol=="NAS100" )     result = "NASDAQ";
                else if (StrStartsWith(_symbol, "NOKJPY"))     result = "NOKJPY";
                else if (StrStartsWith(_symbol, "NOKSEK"))     result = "NOKSEK";
                else if (StrStartsWith(_symbol, "NZDCAD"))     result = "NZDCAD";
                else if (StrStartsWith(_symbol, "NZDCHF"))     result = "NZDCHF";
                else if (StrStartsWith(_symbol, "NZDJPY"))     result = "NZDJPY";
                else if (StrStartsWith(_symbol, "NZDLFX"))     result = "NZDLFX";
                else if (StrStartsWith(_symbol, "NZDSGD"))     result = "NZDSGD";
                else if (StrStartsWith(_symbol, "NZDUSD"))     result = "NZDUSD";
                break;

      case 'O': break;

      case 'P': if      (StrStartsWith(_symbol, "PLNJPY"))     result = "PLNJPY";
                break;

      case 'Q': break;

      case 'R': if      (              _symbol=="RUSSEL_2000") result = "RUSSEL";
                break;

      case 'S': if      (              _symbol=="S&P_500"   )  result = "SP500";
                else if (StrStartsWith(_symbol, "SEKJPY")   )  result = "SEKJPY";
                else if (StrStartsWith(_symbol, "SGDJPY")   )  result = "SGDJPY";
                else if (              _symbol=="SILVER"    )  result = "XAGUSD";
                else if (              _symbol=="SILVEREURO")  result = "XAGEUR";
                break;

      case 'T': if      (StrStartsWith(_symbol, "TRYJPY"))     result = "TRYJPY";
                break;

      case 'U':
                if      (              _symbol=="UK100"  )     result = "FTSE";
                else if (              _symbol=="UKOIL"  )     result = "BRENT";
                else if (              _symbol=="US2000" )     result = "RUSSEL";
                else if (              _symbol=="US30"   )     result = "DJIA";
                else if (              _symbol=="US500"  )     result = "SP500";
                else if (StrStartsWith(_symbol, "USDCAD"))     result = "USDCAD";
                else if (StrStartsWith(_symbol, "USDCHF"))     result = "USDCHF";
                else if (StrStartsWith(_symbol, "USDCCK"))     result = "USDCZK";
                else if (StrStartsWith(_symbol, "USDCNY"))     result = "USDCNY";
                else if (StrStartsWith(_symbol, "USDCZK"))     result = "USDCZK";
                else if (StrStartsWith(_symbol, "USDDKK"))     result = "USDDKK";
                else if (StrStartsWith(_symbol, "USDHKD"))     result = "USDHKD";
                else if (StrStartsWith(_symbol, "USDHRK"))     result = "USDHRK";
                else if (StrStartsWith(_symbol, "USDHUF"))     result = "USDHUF";
                else if (StrStartsWith(_symbol, "USDINR"))     result = "USDINR";
                else if (StrStartsWith(_symbol, "USDJPY"))     result = "USDJPY";
                else if (StrStartsWith(_symbol, "USDLFX"))     result = "USDLFX";
                else if (StrStartsWith(_symbol, "USDLTL"))     result = "USDLTL";
                else if (StrStartsWith(_symbol, "USDLVL"))     result = "USDLVL";
                else if (StrStartsWith(_symbol, "USDMXN"))     result = "USDMXN";
                else if (StrStartsWith(_symbol, "USDNOK"))     result = "USDNOK";
                else if (StrStartsWith(_symbol, "USDPLN"))     result = "USDPLN";
                else if (StrStartsWith(_symbol, "USDRUB"))     result = "USDRUB";
                else if (StrStartsWith(_symbol, "USDRUR"))     result = "USDRUB";
                else if (StrStartsWith(_symbol, "USDSEK"))     result = "USDSEK";
                else if (StrStartsWith(_symbol, "USDSAR"))     result = "USDSAR";
                else if (StrStartsWith(_symbol, "USDSGD"))     result = "USDSGD";
                else if (StrStartsWith(_symbol, "USDTHB"))     result = "USDTHB";
                else if (StrStartsWith(_symbol, "USDTRY"))     result = "USDTRY";
                else if (StrStartsWith(_symbol, "USDTWD"))     result = "USDTWD";
                else if (              _symbol=="USDX"   )     result = "USDX";
                else if (StrStartsWith(_symbol, "USDZAR"))     result = "USDZAR";
                else if (              _symbol=="USTEC"  )     result = "NASDAQ";
                break;

      case 'V': if      (StrStartsWith(_symbol, "VIX_"))       result = "VIX";
                break;

      case 'W': if      (StrStartsWith(_symbol, "WTI_"))       result = "WTI";
                break;

      case 'X': if      (StrStartsWith(_symbol, "XAGEUR"))     result = "XAGEUR";
                else if (StrStartsWith(_symbol, "XAGJPY"))     result = "XAGJPY";
                else if (StrStartsWith(_symbol, "XAGUSD"))     result = "XAGUSD";
                else if (StrStartsWith(_symbol, "XAUEUR"))     result = "XAUEUR";
                else if (StrStartsWith(_symbol, "XAUJPY"))     result = "XAUJPY";
                else if (StrStartsWith(_symbol, "XAUUSD"))     result = "XAUUSD";
                else if (              _symbol=="XBRUSD")      result = "BRENT";
                else if (              _symbol=="XTIUSD")      result = "WTI";
                break;

      case 'Y': break;

      case 'Z': if      (StrStartsWith(_symbol, "ZARJPY"))     result = "ZARJPY";
                break;
   }

   if (result=="" && !strict) {
      result = symbol;
   }
   return(result);
}


/**
 * Inlined conditional boolean statement.
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
 * Inlined conditional integer statement.
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
 * Inlined conditional double statement.
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
 * Inlined conditional string statement.
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
 * Inlined integer OR statement. Returns the first parameter or the second parameter if the first parameter evaluates to NULL.
 *
 * @param  int value
 * @param  int altValue
 *
 * @return int
 */
int intOr(int value, int altValue) {
   if (value != NULL)
      return(value);
   return(altValue);
}


/**
 * Inlined double OR statement. Returns the first parameter or the second parameter if the first parameter evaluates to NULL.
 *
 * @param  double value
 * @param  double altValue
 *
 * @return double
 */
double doubleOr(double value, double altValue) {
   if (value != NULL)
      return(value);
   return(altValue);
}


/**
 * Inlined string OR statement. Returns the first parameter or the second parameter if the first parameter evaluates to empty.
 *
 * @param  string value
 * @param  string altValue
 *
 * @return string
 */
string stringOr(string value, string altValue) {
   if (StringLen(value) > 0)
      return(value);
   return(altValue);
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
      return(!catch("EQ()  illegal parameter digits: "+ digits, ERR_INVALID_PARAMETER));

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
   return(!catch("EQ()  illegal parameter digits: "+ digits, ERR_INVALID_PARAMETER));
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
 * Return the current MQL module's program name, i.e. the name of the program's main module.
 *
 * @return string
 */
string ProgramName() {
   static string name = ""; if (!StringLen(name)) {
      if (IsLibrary()) {
         if (!IsDllsAllowed()) return("???");
         name = ec_ProgramName(__ExecutionContext);
      }
      else {
         name = ModuleName();
      }
      if (!StringLen(name)) return("???");
   }
   return(name);
}


/**
 * Return the current MQL module's simple name. Alias of WindowExpertName().
 *
 * @return string
 */
string ModuleName() {
   return(WindowExpertName());
}


/**
 * Return the current MQL module's full name. For main modules this value matches the value of ProgramName(). For libraries
 * this value includes the name of the MQL main module, e.g. "{expert-name}::{library-name}".
 *
 * @return string
 */
string FullModuleName() {
   static string name = ""; if (!StringLen(name)) {
      string program = ProgramName();
      if (program == "???")
         return(program + ifString(IsLibrary(), "::"+ ModuleName(), ""));           // don't cache in static var
      name = StrTrim(program) + ifString(IsLibrary(), "::"+ ModuleName(), "");
   }
   return(name);
}


/**
 * Integer version of MathMin()
 *
 * Return the smallest of all specified values.
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
 * Integer version of MathMax()
 *
 * Return the largest of all specified values.
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
   if (value == INT_MIN)
      return(INT_MAX);
   if (value < 0)
      return(-value);
   return(value);
}


/**
 * Return the sign of a numerical value.
 *
 * @param  double value
 *
 * @return int - sign (+1, 0, -1)
 */
int Sign(double value) {
   if (value > 0) return( 1);
   if (value < 0) return(-1);
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
 * Multiply two integer values and detect an integer overflow.
 *
 * @param  int  a                             - first operand
 * @param  int  b                             - second operand
 * @param  bool boundaryOnOverflow [optional] - whether to return the boundary value (INT_MIN, INT_MAX) on an overflow
 *                                              (default: runtime error)
 *
 * @return int - result or NULL (0) if an integer overflow occurred and the boundary flag was not set
 */
int Mul(int a, int b, bool boundaryOnOverflow = false) {
   boundaryOnOverflow = boundaryOnOverflow!=0;

   // @see  https://www.geeksforgeeks.org/check-integer-overflow-multiplication/
   if ( !a  ||  !b ) return(0);
   if (a==1 || b==1) return(a * b);

   int result = a * b;

   if ((a > 0) == (b > 0)) {              // operands have the same sign: positive result
      if (result > 0) {
         if (result/a == b) return(result);
      }
      if (boundaryOnOverflow) return(INT_MAX);
   }
   else {                                 // operands have different signs: negative result
      if (result < 0) {
         if (result/a == b) return(result);
      }
      if (boundaryOnOverflow) return(INT_MIN);
   }

   return(!catch("Mul(1)  integer overflow caused by a * b", ERR_RUNTIME_ERROR));
}


/**
 * Divide two integers and prevent a division by 0 (zero).
 *
 * @param  int a                 - divident
 * @param  int b                 - divisor
 * @param  int onZero [optional] - value to return if the divisor is zero (default: 0)
 *
 * @return int
 */
int Div(int a, int b, int onZero = 0) {
   if (!b)
      return(onZero);
   return(a/b);
}


/**
 * Divide two doubles and prevent a division by 0 (zero).
 *
 * @param  double a                 - divident
 * @param  double b                 - divisor
 * @param  double onZero [optional] - value to return if the divisor is zero (default: 0)
 *
 * @return double
 */
double MathDiv(double a, double b, double onZero = 0) {
   if (!b)
      return(onZero);
   return(a/b);
}


/**
 * Return the division remainder of two double values. Replacement for the flawed built-in function MathMod().
 *
 * @param  double a
 * @param  double b
 *
 * @return double - remainder
 */
double MathModFix(double a, double b) {
   double remainder = MathMod(a, b);
   if      (EQ(remainder, 0)) remainder = 0;    // normalize 0
   else if (EQ(remainder, b)) remainder = 0;
   return(remainder);
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
 * @param  string value            - Ausgangsstring
 * @param  string substring        - der das Ergebnis begrenzende Teilstring
 * @param  int    count [optional] - Anzahl der Teilstrings, deren Auftreten das Ergebnis begrenzt (default: das erste Auftreten)
 *                                   Wenn größer als die Anzahl der im String existierenden Teilstrings, wird der gesamte String
 *                                   zurückgegeben.
 *                                   Wenn 0, wird ein Leerstring zurückgegeben.
 *                                   Wenn negativ, wird mit dem Zählen statt von links von rechts begonnen.
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
 *                                   Wenn negativ, wird mit dem Zählen anstatt von links von rechts begonnen.
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

      return(_EMPTY_STR(catch("StrRightFrom(1)->StringFindEx()", ERR_NOT_IMPLEMENTED)));
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
   if (!StringLen(prefix))      return(!catch("StrStartsWithI(3)  illegal parameter prefix: \"\"", ERR_INVALID_PARAMETER));

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
   if (!len) return(false);

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
   int chr, length=StringLen(s);

   // Enthält die Nummer Bindestriche "-", müssen davor und danach Ziffern stehen.
   int pos = StringFind(s, "-");
   while (pos != -1) {
      if (pos   == 0     ) return(false);
      if (pos+1 == length) return(false);

      chr = StringGetChar(s, pos-1);            // left char
      if (chr < '0') return(false);
      if (chr > '9') return(false);

      chr = StringGetChar(s, pos+1);            // right char
      if (chr < '0') return(false);
      if (chr > '9') return(false);

      pos = StringFind(s, "-", pos+1);
   }
   if (chr != 0) s = StrReplace(s, "-", "");

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
 * @param  _InOut_ string array[] - String-Array
 * @param  _In_    string value   - hinzuzufügendes Element
 *
 * @return int - neue Größe des Arrays oder EMPTY (-1), falls ein Fehler auftrat
 *
 *
 * NOTE: Muß global definiert sein. Die intern benutzte Funktion ReverseStringArray() ruft ihrerseits ArraySetAsSeries() auf,
 *       dessen Verhalten mit einem String-Parameter fehlerhaft (offiziell: nicht unterstützt) ist. Unter ungeklärten
 *       Umständen wird das übergebene Array zerschossen, es enthält dann Zeiger auf andere im Programm existierende Strings.
 *       Dieser Fehler trat in Indikatoren auf, wenn ArrayUnshiftString() in einer MQL-Library definiert war und über Modul-
 *       grenzen aufgerufen wurde, nicht jedoch bei globaler Definition. Außerdem trat der Fehler nicht sofort, sondern erst
 *       nach Aufruf anderer Array-Funktionen auf, die mit völlig unbeteiligten Arrays/String arbeiteten.
 */
int ArrayUnshiftString(string &array[], string value) {
   if (ArrayDimension(array) > 1) return(_EMPTY(catch("ArrayUnshiftString(1)  too many dimensions of parameter array: "+ ArrayDimension(array), ERR_INCOMPATIBLE_ARRAY)));

   ReverseStringArray(array);
   int size = ArrayPushString(array, value);
   ReverseStringArray(array);
   return(size);
}


/**
 * Return the integer constant of a loglevel identifier.
 *
 * @param  string value            - loglevel identifier: LOG_DEBUG | LOG_INFO | LOG_NOTICE...
 * @param  int    flags [optional] - execution control flags (default: none)
 *                                   F_ERR_INVALID_PARAMETER: silently handle ERR_INVALID_PARAMETER
 *
 * @return int - loglevel constant oder NULL in case of errors
 */
int StrToLogLevel(string value, int flags = NULL) {
   string str = StrToUpper(StrTrim(value));

   if (StrStartsWith(str, "LOG_"))
      str = StrSubstr(str, 4);

   if (str ==        "DEBUG" ) return(LOG_DEBUG );
   if (str == ""+ LOG_DEBUG  ) return(LOG_DEBUG );
   if (str ==        "INFO"  ) return(LOG_INFO  );
   if (str == ""+ LOG_INFO   ) return(LOG_INFO  );
   if (str ==        "NOTICE") return(LOG_NOTICE);
   if (str == ""+ LOG_NOTICE ) return(LOG_NOTICE);
   if (str ==        "WARN"  ) return(LOG_WARN  );
   if (str == ""+ LOG_WARN   ) return(LOG_WARN  );
   if (str ==        "ERROR" ) return(LOG_ERROR );
   if (str == ""+ LOG_ERROR  ) return(LOG_ERROR );
   if (str ==        "FATAL" ) return(LOG_FATAL );
   if (str == ""+ LOG_FATAL  ) return(LOG_FATAL );
   if (str ==        "ALL"   ) return(LOG_ALL   );       // alias for the lowest loglevel
   if (str == ""+ LOG_ALL    ) return(LOG_ALL   );       // unreachable
   if (str ==        "OFF"   ) return(LOG_OFF   );       //
   if (str == ""+ LOG_OFF    ) return(LOG_OFF   );       // not a loglevel

   if (flags & F_ERR_INVALID_PARAMETER && 1)
      return(!SetLastError(ERR_INVALID_PARAMETER));
   return(!catch("StrToLogLevel(1)  invalid parameter value: "+ DoubleQuoteStr(value), ERR_INVALID_PARAMETER));
}


/**
 * Return the integer constant of a Moving-Average type representation.
 *
 * @param  string value            - string representation of a Moving-Average type
 * @param  int    flags [optional] - execution control: errors to set silently (default: none)
 *
 * @return int - Moving-Average type constant oder EMPTY (-1) in case of errors
 */
int StrToMaMethod(string value, int flags = NULL) {
   string str = StrToUpper(StrTrim(value));

   if (StrStartsWith(str, "MODE_"))
      str = StrSubstr(str, 5);

   if (str ==         "SMA" ) return(MODE_SMA );
   if (str == ""+ MODE_SMA  ) return(MODE_SMA );
   if (str ==         "EMA" ) return(MODE_EMA );
   if (str == ""+ MODE_EMA  ) return(MODE_EMA );
   if (str ==         "SMMA") return(MODE_SMMA);
   if (str == ""+ MODE_SMMA ) return(MODE_SMMA);
   if (str ==         "LWMA") return(MODE_LWMA);
   if (str == ""+ MODE_LWMA ) return(MODE_LWMA);
   if (str ==         "ALMA") return(MODE_ALMA);
   if (str == ""+ MODE_ALMA ) return(MODE_ALMA);

   if (!flags & F_ERR_INVALID_PARAMETER)
      return(_EMPTY(catch("StrToMaMethod(1)  invalid parameter value: "+ DoubleQuoteStr(value), ERR_INVALID_PARAMETER)));
   return(_EMPTY(SetLastError(ERR_INVALID_PARAMETER)));
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
 * Create a datetime value from the specified parameters.
 *
 * Parameter, die außerhalb der üblichen Wertegrenzen liegen, werden in die resultierende Periode übertragen. Der
 * resultierende Zeitpunkt kann im Bereich von D'1901.12.13 20:45:52' (INT_MIN) bis D'2038.01.19 03:14:07' (INT_MAX) liegen.
 *
 * Beispiel: DateTime1(2012, 2, 32, 25, -2) => D'2012.03.04 00:58:00' (2012 war ein Schaltjahr)
 *
 * @param  int year    - year
 * @param  int month   - month   (default: January)
 * @param  int day     - day     (default: 1st of the month)
 * @param  int hours   - hour    (default: Midnight)
 * @param  int minutes - minutes (default: 0 minutes)
 * @param  int seconds - seconds (default: 0 seconds)
 *
 * @return datetime - datetime value or NaT (Not-a-Time) in case of errors
 *
 * Note: Die internen MQL-Funktionen unterstützen nur datetime-Werte im Bereich von D'1970.01.01 00:00:00' bis
 *       D'2037.12.31 23:59:59'. Diese Funktion unterstützt eine größere datetime-Range.
 */
datetime DateTime1(int year, int month=1, int day=1, int hours=0, int minutes=0, int seconds=0) {
   year += (Ceil(month/12.) - 1);
   month = (12 + month%12) % 12;
   if (!month) month = 12;

   string  sDate = StringConcatenate(StrRight("000"+year, 4), ".", StrRight("0"+month, 2), ".01");
   datetime date = StrToTime(sDate);
   if (date < 0) return(_NaT(catch("DateTime1(1)  year="+ year +", month="+ month +", day="+ day +", hours="+ hours +", minutes="+ minutes +", seconds="+ seconds, ERR_INVALID_PARAMETER)));

   int time = (day-1)*DAYS + hours*HOURS + minutes*MINUTES + seconds*SECONDS;
   return(date + time);
}


/**
 * Create a datetime value from a ParseTime() result array.
 *
 * @param  int parsed[]         - ParseTime() result array
 * @param  int flags [optional] - flags controling datetime creation (see notes)
 *
 * @return datetime - datetime value oder NaT (Not-a-Time) in case of erors
 *
 * Notes:
 * ------
 * - If the passed data contains no date part the returned datetime value is controled by parameter 'flags':
 *    DATE_OF_TODAY: a datetime value relative to Midnight of the current day (default)
 *    DATE_OF_ERA:   a datetime value relative to the start of the era (1970-01-01)
 * - If the passed data contains no time part the returned datetime value is set to Midnight (00:00:00).
 */
datetime DateTime2(int parsed[], int flags = DATE_OF_TODAY) {
   if (ArrayDimension(parsed) > 1)      return(_NaT(catch("DateTime2(1)  too many dimensions of parameter parsed: "+ ArrayDimension(parsed), ERR_INCOMPATIBLE_ARRAY)));
   if (ArraySize(parsed) != PT_ERROR+1) return(_NaT(catch("DateTime2(2)  invalid size of parameter parsed: "+ ArraySize(parsed), ERR_INCOMPATIBLE_ARRAY)));

   int pt[]; ArrayCopy(pt, parsed);

   if (!pt[PT_HAS_DATE]) {
      if (flags & DATE_OF_ERA == DATE_OF_ERA) {
         pt[PT_YEAR    ] = 1970;
         pt[PT_MONTH   ] = 1;
         pt[PT_DAY     ] = 1;
      }
      else {
         datetime now = TimeLocalEx();
         pt[PT_YEAR    ] = TimeYearEx(now);
         pt[PT_MONTH   ] = TimeMonth(now);
         pt[PT_DAY     ] = TimeDayEx(now);
      }
      pt[PT_HAS_DATE] = 1;
   }
   if (!pt[PT_HAS_TIME]) {
      pt[PT_HOUR    ] = 0;
      pt[PT_MINUTE  ] = 0;
      pt[PT_SECOND  ] = 0;
      pt[PT_HAS_TIME] = 1;
   }
   return(DateTime1(pt[PT_YEAR], pt[PT_MONTH], pt[PT_DAY], pt[PT_HOUR], pt[PT_MINUTE], pt[PT_SECOND]));
}


/**
 * Return the day of the month of the specified time: 1...31
 *
 * Fixes the broken built-in function TimeDay() which returns 0 instead of 1 for D'1970.01.01 00:00:00'.
 *
 * @param  datetime time
 *
 * @return int
 */
int TimeDayEx(datetime time) {
   if (!time) return(1);
   return(TimeDay(time));
}


/**
 * Return the zero-based weekday of the specified time: 0=Sunday...6=Saturday
 *
 * Fixes the broken built-in function TimeDayOfWeek() which returns 0 (Sunday) for D'1970.01.01 00:00:00' (a Thursday).
 *
 * @param  datetime time
 *
 * @return int
 */
int TimeDayOfWeekEx(datetime time) {
   if (!time) return(3);
   return(TimeDayOfWeek(time));
}


/**
 * Return the year of the specified time: 1970...2037
 *
 * Fixes the broken built-in function TimeYear() which returns 1900 instead of 1970 for D'1970.01.01 00:00:00'.
 *
 * @param  datetime time
 *
 * @return int
 */
int TimeYearEx(datetime time) {
   if (!time) return(1970);
   return(TimeYear(time));
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
   if (destination>=0 && destination<MIN_VALID_POINTER) return(catch("CopyMemory(1)  invalid parameter destination: 0x"+ IntToHexStr(destination) +" (not a valid pointer)", ERR_INVALID_POINTER));
   if (source     >=0 && source    < MIN_VALID_POINTER) return(catch("CopyMemory(2)  invalid parameter source: 0x"+ IntToHexStr(source) +" (not a valid pointer)", ERR_INVALID_POINTER));

   RtlMoveMemory(destination, source, bytes);
   return(NO_ERROR);
}


/**
 * Add all values of an integer array.
 *
 * @param  int values[] - array
 *
 * @return int - sum or NULL (0) in case of errors
 */
int SumInts(int values[]) {
   if (ArrayDimension(values) > 1) return(_NULL(catch("SumInts(1)  too many dimensions of parameter values: "+ ArrayDimension(values), ERR_INCOMPATIBLE_ARRAY)));

   int sum, size=ArraySize(values);

   for (int i=0; i < size; i++) {
      sum += values[i];
   }
   return(sum);
}


/**
 * Replacement for the built-in function MarketInfo() with better error handling. Errors are returned and optionally logged.
 *
 * @param  _In_  string symbol            - symbol
 * @param  _In_  int    type              - identifier of the MarketInfo data to query
 * @param  _Out_ int    &error            - variable receiving the error status
 * @param  _In_  string caller [optional] - location identifier of the caller, controls logging behavior:
 *                                           if specified errors are logged
 *                                           if not specified errors are not logged (default)
 *
 * @return double - result of the MarketInfo() call or NULL (0) in case of errors, check parameter 'error'
 */
double MarketInfoEx(string symbol, int type, int &error, string caller = "") {
   double value = MarketInfo(symbol, type);

   error = GetLastError();
   if (!error) {
      switch (type) {
         case MODE_TICKSIZE:
         case MODE_TICKVALUE:
            if (!value) error = ERR_INVALID_MARKET_DATA;
            break;
      }
   }
   if (!error) return(value);

   if (caller != "") {
      if (IsLogDebug()) logDebug(caller +"->MarketInfoEx(\""+ symbol +"\", "+ MarketInfoTypeToStr(type) +") => "+ NumberToStr(value, ".1+"), error);
   }
   return(NULL);
}


/**
 * Return a human-readable representation of a MarketInfo data identifier.
 *
 * @param  int type - MarketInfo() data type
 *
 * @return string
 */
string MarketInfoTypeToStr(int type) {
   switch (type) {
      case MODE_LOW              : return("MODE_LOW");
      case MODE_HIGH             : return("MODE_HIGH");
      case MODE_TIME             : return("MODE_TIME");
      case MODE_BID              : return("MODE_BID");
      case MODE_ASK              : return("MODE_ASK");
      case MODE_POINT            : return("MODE_POINT");
      case MODE_DIGITS           : return("MODE_DIGITS");
      case MODE_SPREAD           : return("MODE_SPREAD");
      case MODE_STOPLEVEL        : return("MODE_STOPLEVEL");
      case MODE_LOTSIZE          : return("MODE_LOTSIZE");
      case MODE_TICKVALUE        : return("MODE_TICKVALUE");
      case MODE_TICKSIZE         : return("MODE_TICKSIZE");
      case MODE_SWAPLONG         : return("MODE_SWAPLONG");
      case MODE_SWAPSHORT        : return("MODE_SWAPSHORT");
      case MODE_STARTING         : return("MODE_STARTING");
      case MODE_EXPIRATION       : return("MODE_EXPIRATION");
      case MODE_TRADEALLOWED     : return("MODE_TRADEALLOWED");
      case MODE_MINLOT           : return("MODE_MINLOT");
      case MODE_LOTSTEP          : return("MODE_LOTSTEP");
      case MODE_MAXLOT           : return("MODE_MAXLOT");
      case MODE_SWAPTYPE         : return("MODE_SWAPTYPE");
      case MODE_PROFITCALCMODE   : return("MODE_PROFITCALCMODE");
      case MODE_MARGINCALCMODE   : return("MODE_MARGINCALCMODE");
      case MODE_MARGININIT       : return("MODE_MARGININIT");
      case MODE_MARGINMAINTENANCE: return("MODE_MARGINMAINTENANCE");
      case MODE_MARGINHEDGED     : return("MODE_MARGINHEDGED");
      case MODE_MARGINREQUIRED   : return("MODE_MARGINREQUIRED");
      case MODE_FREEZELEVEL      : return("MODE_FREEZELEVEL");
   }
   return(""+ type);
}


/**
 * Dump major global vars and available MarketInfo() data to the system debugger.
 *
 * @param  string caller - location identifier of the caller
 *
 * @return int - error status
 */
int DebugMarketInfo(string caller = "") {
   string symbol = Symbol();
   double value;
   int error, len=21 + StringLen(symbol);

   debug(caller +"  "+ StrRepeat("-", len));                               //  ---------------------------
   debug(caller +"  Account");                                             //  Account
   debug(caller +"  "+ StrRepeat("-", len));                               //  ---------------------------

   debug(caller +"  server  = "+ DoubleQuoteStr(GetAccountServer()));
   debug(caller +"  company = "+ DoubleQuoteStr(AccountCompany()));
   debug(caller +"  name    = "+ DoubleQuoteStr(AccountName()));
   debug(caller +"  number  = "+ GetAccountNumber());

   debug(caller +"  "+ StrRepeat("-", len));                               //  ---------------------------
   debug(caller +"  Global variables (\""+ symbol +"\")");                 //  Global variables ("EURUSD")
   debug(caller +"  "+ StrRepeat("-", len));                               //  ---------------------------

   debug(caller +"  built-in: Digits      = "+ Digits);
   debug(caller +"  built-in: Point       = "+ NumberToStr(Point, PriceFormat));
   debug(caller +"  derived:  Pip         = "+ NumberToStr(Pip, PriceFormat));
   debug(caller +"  derived:  PipDigits   = "+ PipDigits);
   debug(caller +"  derived:  PipPoints   = "+ PipPoints);
   debug(caller +"  derived:  PriceFormat = \""+ PriceFormat +"\"");
   debug(caller +"  built-in: Bid/Ask     = "+ NumberToStr(Bid, PriceFormat) +"/"+ NumberToStr(Ask, PriceFormat));
   debug(caller +"  built-in: Bars        = "+ Bars);

   debug(caller +"  "+ StrRepeat("-", len));                               //  ---------------------------
   debug(caller +"  MarketInfo(\""+ symbol +"\")");                        //  MarketInfo("EURUSD")
   debug(caller +"  "+ StrRepeat("-", len));                               //  ---------------------------

   // see MODE explanations in "include/stddefines.mqh"
   value = MarketInfo(symbol, MODE_LOW              ); error = GetLastError();                 debug(caller +"  MODE_LOW               = "+                    NumberToStr(value, ifString(error, ".+", PriceFormat)), error);
   value = MarketInfo(symbol, MODE_HIGH             ); error = GetLastError();                 debug(caller +"  MODE_HIGH              = "+                    NumberToStr(value, ifString(error, ".+", PriceFormat)), error);
   value = MarketInfo(symbol, 3                     ); error = GetLastError(); if (value != 0) debug(caller +"  3                      = "+                    NumberToStr(value, ".+")                              , error);
   value = MarketInfo(symbol, 4                     ); error = GetLastError(); if (value != 0) debug(caller +"  4                      = "+                    NumberToStr(value, ".+")                              , error);
   value = MarketInfo(symbol, MODE_TIME             ); error = GetLastError();                 debug(caller +"  MODE_TIME              = "+ ifString(value<=0, NumberToStr(value, ".+"), TimeToStr(value, TIME_FULL)), error);
   value = MarketInfo(symbol, 6                     ); error = GetLastError(); if (value != 0) debug(caller +"  6                      = "+                    NumberToStr(value, ".+")                              , error);
   value = MarketInfo(symbol, 7                     ); error = GetLastError(); if (value != 0) debug(caller +"  7                      = "+                    NumberToStr(value, ".+")                              , error);
   value = MarketInfo(symbol, 8                     ); error = GetLastError(); if (value != 0) debug(caller +"  8                      = "+                    NumberToStr(value, ".+")                              , error);
   value = MarketInfo(symbol, MODE_BID              ); error = GetLastError();                 debug(caller +"  MODE_BID               = "+                    NumberToStr(value, ifString(error, ".+", PriceFormat)), error);
   value = MarketInfo(symbol, MODE_ASK              ); error = GetLastError();                 debug(caller +"  MODE_ASK               = "+                    NumberToStr(value, ifString(error, ".+", PriceFormat)), error);
   value = MarketInfo(symbol, MODE_POINT            ); error = GetLastError();                 debug(caller +"  MODE_POINT             = "+                    NumberToStr(value, ifString(error, ".+", PriceFormat)), error);
   value = MarketInfo(symbol, MODE_DIGITS           ); error = GetLastError();                 debug(caller +"  MODE_DIGITS            = "+                    NumberToStr(value, ".+")                              , error);
   value = MarketInfo(symbol, MODE_SPREAD           ); error = GetLastError();                 debug(caller +"  MODE_SPREAD            = "+                    NumberToStr(value, ".+")                              , error);
   value = MarketInfo(symbol, MODE_STOPLEVEL        ); error = GetLastError();                 debug(caller +"  MODE_STOPLEVEL         = "+                    NumberToStr(value, ".+")                              , error);
   value = MarketInfo(symbol, MODE_LOTSIZE          ); error = GetLastError();                 debug(caller +"  MODE_LOTSIZE           = "+                    NumberToStr(value, ".+")                              , error);
   value = MarketInfo(symbol, MODE_TICKVALUE        ); error = GetLastError();                 debug(caller +"  MODE_TICKVALUE         = "+                    NumberToStr(value, ".+")                              , error);
   value = MarketInfo(symbol, MODE_TICKSIZE         ); error = GetLastError();                 debug(caller +"  MODE_TICKSIZE          = "+                    NumberToStr(value, ifString(error, ".+", PriceFormat)), error);
   value = MarketInfo(symbol, MODE_SWAPLONG         ); error = GetLastError();                 debug(caller +"  MODE_SWAPLONG          = "+                    NumberToStr(value, ".+")                              , error);
   value = MarketInfo(symbol, MODE_SWAPSHORT        ); error = GetLastError();                 debug(caller +"  MODE_SWAPSHORT         = "+                    NumberToStr(value, ".+")                              , error);
   value = MarketInfo(symbol, MODE_STARTING         ); error = GetLastError();                 debug(caller +"  MODE_STARTING          = "+ ifString(value<=0, NumberToStr(value, ".+"), TimeToStr(value, TIME_FULL)), error);
   value = MarketInfo(symbol, MODE_EXPIRATION       ); error = GetLastError();                 debug(caller +"  MODE_EXPIRATION        = "+ ifString(value<=0, NumberToStr(value, ".+"), TimeToStr(value, TIME_FULL)), error);
   value = MarketInfo(symbol, MODE_TRADEALLOWED     ); error = GetLastError();                 debug(caller +"  MODE_TRADEALLOWED      = "+                    NumberToStr(value, ".+")                              , error);
   value = MarketInfo(symbol, MODE_MINLOT           ); error = GetLastError();                 debug(caller +"  MODE_MINLOT            = "+                    NumberToStr(value, ".+")                              , error);
   value = MarketInfo(symbol, MODE_LOTSTEP          ); error = GetLastError();                 debug(caller +"  MODE_LOTSTEP           = "+                    NumberToStr(value, ".+")                              , error);
   value = MarketInfo(symbol, MODE_MAXLOT           ); error = GetLastError();                 debug(caller +"  MODE_MAXLOT            = "+                    NumberToStr(value, ".+")                              , error);
   value = MarketInfo(symbol, MODE_SWAPTYPE         ); error = GetLastError();                 debug(caller +"  MODE_SWAPTYPE          = "+                    NumberToStr(value, ".+")                              , error);
   value = MarketInfo(symbol, MODE_PROFITCALCMODE   ); error = GetLastError();                 debug(caller +"  MODE_PROFITCALCMODE    = "+                    NumberToStr(value, ".+")                              , error);
   value = MarketInfo(symbol, MODE_MARGINCALCMODE   ); error = GetLastError();                 debug(caller +"  MODE_MARGINCALCMODE    = "+                    NumberToStr(value, ".+")                              , error);
   value = MarketInfo(symbol, MODE_MARGININIT       ); error = GetLastError();                 debug(caller +"  MODE_MARGININIT        = "+                    NumberToStr(value, ".+")                              , error);
   value = MarketInfo(symbol, MODE_MARGINMAINTENANCE); error = GetLastError();                 debug(caller +"  MODE_MARGINMAINTENANCE = "+                    NumberToStr(value, ".+")                              , error);
   value = MarketInfo(symbol, MODE_MARGINHEDGED     ); error = GetLastError();                 debug(caller +"  MODE_MARGINHEDGED      = "+                    NumberToStr(value, ".+")                              , error);
   value = MarketInfo(symbol, MODE_MARGINREQUIRED   ); error = GetLastError();                 debug(caller +"  MODE_MARGINREQUIRED    = "+                    NumberToStr(value, ".+")                              , error);
   value = MarketInfo(symbol, MODE_FREEZELEVEL      ); error = GetLastError();                 debug(caller +"  MODE_FREEZELEVEL       = "+                    NumberToStr(value, ".+")                              , error);

   return(catch("DebugMarketInfo(1)"));
}


/*
Invalid MarketInfo() data in tester
===================================

// EA in tester
TestExpert::onTick()      -----------------------------
TestExpert::onTick()      Global variables for "EURUSD"
TestExpert::onTick()      -----------------------------
TestExpert::onTick()      built-in: Digits      = 5
TestExpert::onTick()      built-in: Point       = 0.0000'1
TestExpert::onTick()      derived:  Pip         = 0.0001'0
TestExpert::onTick()      derived:  PipDigits   = 4
TestExpert::onTick()      derived:  PipPoints   = 10
TestExpert::onTick()      derived:  PriceFormat = "R.4'"
TestExpert::onTick()      built-in: Bid/Ask     = 1.2711'2/1.2713'1
TestExpert::onTick()      built-in: Bars        = 60007
TestExpert::onTick()      -------------------------
TestExpert::onTick()      MarketInfo() for "EURUSD"
TestExpert::onTick()      -------------------------
TestExpert::onTick()      MODE_LOW               = 0.0000'0                   // wrong (empty)
TestExpert::onTick()      MODE_HIGH              = 0.0000'0                   // wrong (empty)
TestExpert::onTick()      MODE_TIME              = 2012.11.12 00:00:00
TestExpert::onTick()      MODE_BID               = 1.2711'2
TestExpert::onTick()      MODE_ASK               = 1.2713'1
TestExpert::onTick()      MODE_POINT             = 0.0000'1
TestExpert::onTick()      MODE_DIGITS            = 5
TestExpert::onTick()      MODE_SPREAD            = 19
TestExpert::onTick()      MODE_STOPLEVEL         = 20
TestExpert::onTick()      MODE_LOTSIZE           = 100000
TestExpert::onTick()      MODE_TICKVALUE         = 1                          // wrong (online)
TestExpert::onTick()      MODE_TICKSIZE          = 0.0000'1
TestExpert::onTick()      MODE_SWAPLONG          = -1.3
TestExpert::onTick()      MODE_SWAPSHORT         = 0.5
TestExpert::onTick()      MODE_STARTING          = 0
TestExpert::onTick()      MODE_EXPIRATION        = 0
TestExpert::onTick()      MODE_TRADEALLOWED      = 0                          // wrong (empty)
TestExpert::onTick()      MODE_MINLOT            = 0.01
TestExpert::onTick()      MODE_LOTSTEP           = 0.01
TestExpert::onTick()      MODE_MAXLOT            = 2
TestExpert::onTick()      MODE_SWAPTYPE          = 0
TestExpert::onTick()      MODE_PROFITCALCMODE    = 0
TestExpert::onTick()      MODE_MARGINCALCMODE    = 0
TestExpert::onTick()      MODE_MARGININIT        = 0
TestExpert::onTick()      MODE_MARGINMAINTENANCE = 0
TestExpert::onTick()      MODE_MARGINHEDGED      = 50000
TestExpert::onTick()      MODE_MARGINREQUIRED    = 254.25
TestExpert::onTick()      MODE_FREEZELEVEL       = 0

// Indicator in tester via iCustom()
TestIndicator::onTick()   -----------------------------
TestIndicator::onTick()   Global variables for "EURUSD"
TestIndicator::onTick()   -----------------------------
TestIndicator::onTick()   built-in: Digits      = 5
TestIndicator::onTick()   built-in: Point       = 0.0000'1
TestIndicator::onTick()   derived:  Pip         = 0.0001'0
TestIndicator::onTick()   derived:  PipDigits   = 4
TestIndicator::onTick()   derived:  PipPoints   = 10
TestIndicator::onTick()   derived:  PriceFormat = "R.4'"
TestIndicator::onTick()   built-in: Bid/Ask     = 1.2711'2/1.2713'1
TestIndicator::onTick()   built-in: Bars        = 60007
TestIndicator::onTick()   -------------------------
TestIndicator::onTick()   MarketInfo() for "EURUSD"
TestIndicator::onTick()   -------------------------
TestIndicator::onTick()   MODE_LOW               = 0.0000'0                   // wrong (empty)
TestIndicator::onTick()   MODE_HIGH              = 0.0000'0                   // wrong (empty)
TestIndicator::onTick()   MODE_TIME              = 2012.11.12 00:00:00
TestIndicator::onTick()   MODE_BID               = 1.2711'2
TestIndicator::onTick()   MODE_ASK               = 1.2713'1
TestIndicator::onTick()   MODE_POINT             = 0.0000'1
TestIndicator::onTick()   MODE_DIGITS            = 5
TestIndicator::onTick()   MODE_SPREAD            = 0                          // wrong (empty)
TestIndicator::onTick()   MODE_STOPLEVEL         = 20
TestIndicator::onTick()   MODE_LOTSIZE           = 100000
TestIndicator::onTick()   MODE_TICKVALUE         = 1                          // wrong (online)
TestIndicator::onTick()   MODE_TICKSIZE          = 0.0000'1
TestIndicator::onTick()   MODE_SWAPLONG          = -1.3
TestIndicator::onTick()   MODE_SWAPSHORT         = 0.5
TestIndicator::onTick()   MODE_STARTING          = 0
TestIndicator::onTick()   MODE_EXPIRATION        = 0
TestIndicator::onTick()   MODE_TRADEALLOWED      = 1
TestIndicator::onTick()   MODE_MINLOT            = 0.01
TestIndicator::onTick()   MODE_LOTSTEP           = 0.01
TestIndicator::onTick()   MODE_MAXLOT            = 2
TestIndicator::onTick()   MODE_SWAPTYPE          = 0
TestIndicator::onTick()   MODE_PROFITCALCMODE    = 0
TestIndicator::onTick()   MODE_MARGINCALCMODE    = 0
TestIndicator::onTick()   MODE_MARGININIT        = 0
TestIndicator::onTick()   MODE_MARGINMAINTENANCE = 0
TestIndicator::onTick()   MODE_MARGINHEDGED      = 50000
TestIndicator::onTick()   MODE_MARGINREQUIRED    = 259.73                     // wrong (online)
TestIndicator::onTick()   MODE_FREEZELEVEL       = 0

// Indicator in tester standalone
TestIndicator::onTick()   -----------------------------
TestIndicator::onTick()   Global variables for "EURUSD"
TestIndicator::onTick()   -----------------------------
TestIndicator::onTick()   built-in: Digits      = 5
TestIndicator::onTick()   built-in: Point       = 0.0000'1
TestIndicator::onTick()   derived:  Pip         = 0.0001'0
TestIndicator::onTick()   derived:  PipDigits   = 4
TestIndicator::onTick()   derived:  PipPoints   = 10
TestIndicator::onTick()   derived:  PriceFormat = "R.4'"
TestIndicator::onTick()   built-in: Bid/Ask     = 1.2983'9/1.2986'7           // wrong (online)
TestIndicator::onTick()   built-in: Bars        = 60007
TestIndicator::onTick()   -------------------------
TestIndicator::onTick()   MarketInfo() for "EURUSD"
TestIndicator::onTick()   -------------------------
TestIndicator::onTick()   MODE_LOW               = 1.2967'6                   // wrong (online)
TestIndicator::onTick()   MODE_HIGH              = 1.3027'3                   // wrong (online)
TestIndicator::onTick()   MODE_TIME              = 2012.11.30 23:59:52        // wrong (online)
TestIndicator::onTick()   MODE_BID               = 1.2983'9                   // wrong (online)
TestIndicator::onTick()   MODE_ASK               = 1.2986'7                   // wrong (online)
TestIndicator::onTick()   MODE_POINT             = 0.0000'1
TestIndicator::onTick()   MODE_DIGITS            = 5
TestIndicator::onTick()   MODE_SPREAD            = 28                         // wrong (online)
TestIndicator::onTick()   MODE_STOPLEVEL         = 20
TestIndicator::onTick()   MODE_LOTSIZE           = 100000
TestIndicator::onTick()   MODE_TICKVALUE         = 1
TestIndicator::onTick()   MODE_TICKSIZE          = 0.0000'1
TestIndicator::onTick()   MODE_SWAPLONG          = -1.3
TestIndicator::onTick()   MODE_SWAPSHORT         = 0.5
TestIndicator::onTick()   MODE_STARTING          = 0
TestIndicator::onTick()   MODE_EXPIRATION        = 0
TestIndicator::onTick()   MODE_TRADEALLOWED      = 1
TestIndicator::onTick()   MODE_MINLOT            = 0.01
TestIndicator::onTick()   MODE_LOTSTEP           = 0.01
TestIndicator::onTick()   MODE_MAXLOT            = 2
TestIndicator::onTick()   MODE_SWAPTYPE          = 0
TestIndicator::onTick()   MODE_PROFITCALCMODE    = 0
TestIndicator::onTick()   MODE_MARGINCALCMODE    = 0
TestIndicator::onTick()   MODE_MARGININIT        = 0
TestIndicator::onTick()   MODE_MARGINMAINTENANCE = 0
TestIndicator::onTick()   MODE_MARGINHEDGED      = 50000
TestIndicator::onTick()   MODE_MARGINREQUIRED    = 259.73                     // wrong (online)
TestIndicator::onTick()   MODE_FREEZELEVEL       = 0
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
   static bool result = -1;
   if (result == -1) {
      if (IsTesting()) result = true;
      else             result = (__ExecutionContext[EC.testing] != 0);
   }
   return(result);
}


/**
 * Whether the current program runs on a demo account. Workaround for a bug in terminal builds <= 509 where the built-in
 * function IsDemo() returns FALSE in tester.
 *
 * @return bool
 */
bool IsDemoFix() {
   static bool result = -1;
   if (result == -1) {
      if (IsDemo()) result = true;
      else          result = This.IsTesting();
   }
   return(result);
}


/**
 * Enumerate all child windows of a window and send output to the system debugger.
 *
 * @param  int  hWnd                 - Handle of the window. If this parameter is NULL all top-level windows are enumerated.
 * @param  bool recursive [optional] - Whether to enumerate child windows recursively (default: no).
 *
 * @return bool - success status
 */
bool EnumChildWindows(int hWnd, bool recursive = false) {
   recursive = recursive!=0;
   if      (!hWnd)           hWnd = GetDesktopWindow();
   else if (hWnd < 0)        return(!catch("EnumChildWindows(1)  invalid parameter hWnd: "+ hWnd , ERR_INVALID_PARAMETER));
   else if (!IsWindow(hWnd)) return(!catch("EnumChildWindows(2)  not an existing window hWnd: "+ IntToHexStr(hWnd), ERR_INVALID_PARAMETER));

   string padding="", wndTitle="", wndClass="";
   int ctrlId;

   static int sublevel;
   if (!sublevel) {
      wndClass = GetClassName(hWnd);
      wndTitle = GetInternalWindowTextA(hWnd);
      ctrlId   = GetDlgCtrlID(hWnd);
      debug("EnumChildWindows()  "+ IntToHexStr(hWnd) +": "+ wndClass +" \""+ wndTitle +"\""+ ifString(ctrlId, " ("+ ctrlId +")", ""));
   }
   sublevel++;
   padding = StrRepeat(" ", (sublevel-1)<<1);

   int i, hWndNext=GetWindow(hWnd, GW_CHILD);
   while (hWndNext != 0) {
      i++;
      wndClass = GetClassName(hWndNext);
      wndTitle = GetInternalWindowTextA(hWndNext);
      ctrlId   = GetDlgCtrlID(hWndNext);
      debug("EnumChildWindows()  "+ padding +"-> "+ IntToHexStr(hWndNext) +": "+ wndClass +" \""+ wndTitle +"\""+ ifString(ctrlId, " ("+ ctrlId +")", ""));

      if (recursive) {
         if (!EnumChildWindows(hWndNext, true)) {
            sublevel--;
            return(false);
         }
      }
      hWndNext = GetWindow(hWndNext, GW_HWNDNEXT);
   }
   if (!sublevel && !i) debug("EnumChildWindows()  "+ padding +"-> (no child windows)");

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
   if (value  == "O"  ) return(_false(logNotice("StrToBool(2)  string "+ DoubleQuoteStr(value) +" is capital letter O, assumed to be zero")));
   if (lValue == "0n" ) return(_true (logNotice("StrToBool(3)  string "+ DoubleQuoteStr(value) +" starts with zero, assumed to be \"On\"")));
   if (lValue == "0ff") return(_false(logNotice("StrToBool(4)  string "+ DoubleQuoteStr(value) +" starts with zero, assumed to be \"Off\"")));
   if (lValue == "n0" ) return(_false(logNotice("StrToBool(5)  string "+ DoubleQuoteStr(value) +" ends with zero, assumed to be \"no\"")));

   if (StrIsNumeric(value))
      return(StrToDouble(value) != 0);
   return(false);
}


/**
 * Convert a string to lower case.
 *
 * @param  string value
 *
 * @return string
 */
string StrToLower(string value) {
   string result = value;
   int chr, len=StringLen(value);

   for (int i=0; i < len; i++) {
      chr = StringGetChar(value, i);
      // logical version
      //if      ( 65 <= chr && chr <=  90) result = StringSetChar(result, i, chr+32);     // A-Z->a-z
      //else if (192 <= chr && chr <= 214) result = StringSetChar(result, i, chr+32);     // À-Ö->à-ö
      //else if (216 <= chr && chr <= 222) result = StringSetChar(result, i, chr+32);     // Ø-Þ->ø-þ
      //else if (chr == 138)               result = StringSetChar(result, i, 154);        // Š->š
      //else if (chr == 140)               result = StringSetChar(result, i, 156);        // Œ->œ
      //else if (chr == 142)               result = StringSetChar(result, i, 158);        // Ž->ž
      //else if (chr == 159)               result = StringSetChar(result, i, 255);        // Ÿ->ÿ

      // MQL4 version
      if (chr > 64) {
         if (chr < 91) {
            result = StringSetChar(result, i, chr+32);                  // A-Z->a-z
         }
         else if (chr > 191) {
            if (chr < 223) {
               if (chr != 215)
                  result = StringSetChar(result, i, chr+32);            // À-Ö->à-ö, Ø-Þ->ø-þ
            }
         }
         else if (chr == 138) result = StringSetChar(result, i, 154);   // Š->š
         else if (chr == 140) result = StringSetChar(result, i, 156);   // Œ->œ
         else if (chr == 142) result = StringSetChar(result, i, 158);   // Ž->ž
         else if (chr == 159) result = StringSetChar(result, i, 255);   // Ÿ->ÿ
      }
   }
   return(result);
}


/**
 * Convert a string to upper case.
 *
 * @param  string value
 *
 * @return string
 */
string StrToUpper(string value) {
   string result = value;
   int chr, len=StringLen(value);

   for (int i=0; i < len; i++) {
      chr = StringGetChar(value, i);
      // logical version
      //if      (96 < chr && chr < 123)            result = StringSetChar(result, i, chr-32);
      //else if (chr==154 || chr==156 || chr==158) result = StringSetChar(result, i, chr-16);
      //else if (chr==255)                         result = StringSetChar(result, i,    159);   // ÿ -> Ÿ
      //else if (chr > 223)                        result = StringSetChar(result, i, chr-32);

      // MQL4 version
      if      (chr == 255)                result = StringSetChar(result, i,    159);            // ÿ -> Ÿ
      else if (chr  > 223)                result = StringSetChar(result, i, chr-32);
      else if (chr == 158)                result = StringSetChar(result, i, chr-16);
      else if (chr == 156)                result = StringSetChar(result, i, chr-16);
      else if (chr == 154)                result = StringSetChar(result, i, chr-16);
      else if (chr  >  96) if (chr < 123) result = StringSetChar(result, i, chr-32);
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
   string strChar="", result="";
   int chr, len=StringLen(value);

   for (int i=0; i < len; i++) {
      strChar = StringSubstr(value, i, 1);
      chr     = StringGetChar(strChar, 0);

      if      (47 < chr && chr <  58) result = StringConcatenate(result, strChar);                  // 0-9
      else if (64 < chr && chr <  91) result = StringConcatenate(result, strChar);                  // A-Z
      else if (96 < chr && chr < 123) result = StringConcatenate(result, strChar);                  // a-z
      else if (chr == ' ')            result = StringConcatenate(result, "+");
      else                            result = StringConcatenate(result, "%", CharToHexStr(chr));
   }

   if (!catch("UrlEncode(1)"))
      return(result);
   return("");
}


/**
 * Whether the specified file exists.
 *
 * @param  string path - file path (may be a symbolic link); supports both forward and backward slashes
 * @param  int    mode - MODE_MQL:    restrict the function's operation to the MQL sandbox
 *                       MODE_SYSTEM: allow the function to operate outside of the MQL sandbox
 * @return bool
 */
bool IsFile(string path, int mode) {
   // TODO: check whether scripts and indicators in tester indeed access "{data-directory}/tester/"
   if (!(~mode & (MODE_MQL|MODE_SYSTEM))) return(!catch("IsFile(1)  invalid parameter mode: only one of MODE_MQL or MODE_SYSTEM can be specified", ERR_INVALID_PARAMETER));
   if (!( mode & (MODE_MQL|MODE_SYSTEM))) return(!catch("IsFile(2)  invalid parameter mode: one of MODE_MQL or MODE_SYSTEM must be specified", ERR_INVALID_PARAMETER));

   if (mode & MODE_MQL && 1) {
      string filesDirectory = GetMqlSandboxPath();
      if (!StringLen(filesDirectory))
         return(false);
      path = StringConcatenate(filesDirectory, "/", path);
   }
   return(IsFileA(path, MODE_SYSTEM));
}


/**
 * Whether the specified directory exists.
 *
 * @param  string path - directory path (may be a symbolic link or a junction), supports both forward and backward slashes
 * @param  int    mode - MODE_MQL:    restrict the function's operation to the MQL sandbox
 *                       MODE_SYSTEM: allow the function to operate outside of the MQL sandbox
 * @return bool
 */
bool IsDirectory(string path, int mode) {
   // TODO: check whether scripts and indicators in tester indeed access "{data-directory}/tester/"
   if (!(~mode & (MODE_MQL|MODE_SYSTEM))) return(!catch("IsDirectory(1)  invalid parameter mode: only one of MODE_MQL or MODE_SYSTEM can be specified", ERR_INVALID_PARAMETER));
   if (!( mode & (MODE_MQL|MODE_SYSTEM))) return(!catch("IsDirectory(2)  invalid parameter mode: one of MODE_MQL or MODE_SYSTEM must be specified", ERR_INVALID_PARAMETER));

   if (mode & MODE_MQL && 1) {
      string filesDirectory = GetMqlSandboxPath();
      if (!StringLen(filesDirectory))
         return(false);
      path = StringConcatenate(filesDirectory, "/", path);
   }
   return(IsDirectoryA(path, MODE_SYSTEM));
}


/**
 * Create a directory.
 *
 * @param  string path  - directory path
 * @param  int    flags - MODE_MQL:      restrict the function's operation to the MQL sandbox
 *                        MODE_SYSTEM:   allow the function to operate outside of the MQL sandbox
 *                        MODE_MKPARENT: create parent directories as needed and report no error on an existing directory;
 *                                       otherwise create only the final directory and report an error if it exists
 * @return bool - success status
 */
bool CreateDirectory(string path, int flags) {
   if (!(~flags & (MODE_MQL|MODE_SYSTEM))) return(!catch("CreateDirectory(1)  invalid parameter flag: only one of MODE_MQL or MODE_SYSTEM can be specified", ERR_INVALID_PARAMETER));
   if (!( flags & (MODE_MQL|MODE_SYSTEM))) return(!catch("CreateDirectory(2)  invalid parameter flag: one of MODE_MQL or MODE_SYSTEM must be specified", ERR_INVALID_PARAMETER));

   if (flags & MODE_MQL && 1) {
      string filesDirectory = GetMqlSandboxPath();
      if (!StringLen(filesDirectory))
         return(false);
      path = StringConcatenate(filesDirectory, "/", path);
      flags &= ~MODE_MQL;
   }
   return(!CreateDirectoryA(path, flags|MODE_SYSTEM));
}


/**
 * Return the full path of the MQL sandbox directory. This is the only directory accessible to MQL file functions.
 *
 * @return string - directory path or an empty string in case of errors
 */
string GetMqlSandboxPath() {
   static string path = ""; if (!StringLen(path)) {
      if (IsTesting()) {
         string dataDirectory = GetTerminalDataPathA();
         if (!StringLen(dataDirectory)) return(EMPTY_STR);

         path = dataDirectory +"/tester/files";
      }
      else {
         string mqlDirectory = GetMqlDirectoryA();
         if (!StringLen(mqlDirectory)) return(EMPTY_STR);

         path = mqlDirectory +"/files";
      }
      path = StrReplace(path, "\\", "/");
   }
   return(path);
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
 * Send a virtual tick to the current chart.
 *
 * @param  bool sound [optional] - whether to audibly confirm the tick (default: no)
 *
 * @return int - error status
 */
int Chart.SendTick(bool sound = false) {
   sound = sound!=0;

   int hWnd = __ExecutionContext[EC.hChart];

   if (!This.IsTesting()) {
      PostMessageA(hWnd, WM_MT4(), MT4_TICK, TICK_OFFLINE_EA);    // LPARAM lParam: 0 - doesn't trigger Expert::start() in offline charts
   }                                                              //                1 - triggers Expert::start() in offline charts (if a server connection is established)
   else if (Tester.IsPaused()) {
      SendMessageA(hWnd, WM_COMMAND, ID_TESTER_TICK, 0);
   }

   if (sound)
      PlaySoundEx("Tick.wav");

   return(NO_ERROR);
}


/**
 * Ruft den Hauptmenü-Befehl Charts->Objects->Unselect All auf.
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
 * Store a named boolean value in the chart.
 *
 * @param  string key   - value identifier (max. 63 chars)
 * @param  bool   value - value to store
 *
 * @return bool - success status
 */
bool Chart.StoreBool(string key, bool value) {
   value = value!=0;
   if (!__isChart) return(!catch("Chart.StoreBool(1)  illegal calling context (no chart)", ERR_RUNTIME_ERROR));

   int len = StringLen(key);
   if (!len)       return(!catch("Chart.StoreBool(2)  invalid parameter key: "+ DoubleQuoteStr(key) +" (not a valid chart object identifier)", ERR_INVALID_PARAMETER));
   if (len > 63)   return(!catch("Chart.StoreBool(3)  invalid parameter key: "+ DoubleQuoteStr(key) +" (more than 63 chars)", ERR_INVALID_PARAMETER));

   if (ObjectFind(key) == 0)
      ObjectDelete(key);
   ObjectCreate (key, OBJ_LABEL, 0, 0, 0);
   ObjectSet    (key, OBJPROP_TIMEFRAMES, OBJ_PERIODS_NONE);
   ObjectSetText(key, ""+ value);                                 // (string)(int) bool

   return(!catch("Chart.StoreBool(4)"));
}


/**
 * Store a named integer value in the chart.
 *
 * @param  string key   - value identifier (max. 63 chars)
 * @param  int    value - value to store
 *
 * @return bool - success status
 */
bool Chart.StoreInt(string key, int value) {
   if (!__isChart) return(!catch("Chart.StoreInt(1)  illegal calling context (no chart)", ERR_RUNTIME_ERROR));

   int len = StringLen(key);
   if (!len)       return(!catch("Chart.StoreInt(2)  invalid parameter key: "+ DoubleQuoteStr(key) +" (not a valid chart object identifier)", ERR_INVALID_PARAMETER));
   if (len > 63)   return(!catch("Chart.StoreInt(3)  invalid parameter key: "+ DoubleQuoteStr(key) +" (more than 63 chars)", ERR_INVALID_PARAMETER));

   if (ObjectFind(key) == 0)
      ObjectDelete(key);
   ObjectCreate (key, OBJ_LABEL, 0, 0, 0);
   ObjectSet    (key, OBJPROP_TIMEFRAMES, OBJ_PERIODS_NONE);
   ObjectSetText(key, ""+ value);                                 // (string) int

   return(!catch("Chart.StoreInt(4)"));
}


/**
 * Store a named color value in the chart.
 *
 * @param  string key   - value identifier (max. 63 chars)
 * @param  color  value - value to store
 *
 * @return bool - success status
 */
bool Chart.StoreColor(string key, color value) {
   if (!__isChart) return(!catch("Chart.StoreColor(1)  illegal calling context (no chart)", ERR_RUNTIME_ERROR));

   int len = StringLen(key);
   if (!len)       return(!catch("Chart.StoreColor(2)  invalid parameter key: "+ DoubleQuoteStr(key) +" (not a valid chart object identifier)", ERR_INVALID_PARAMETER));
   if (len > 63)   return(!catch("Chart.StoreColor(3)  invalid parameter key: "+ DoubleQuoteStr(key) +" (more than 63 chars)", ERR_INVALID_PARAMETER));

   if (ObjectFind(key) == 0)
      ObjectDelete(key);
   ObjectCreate (key, OBJ_LABEL, 0, 0, 0);
   ObjectSet    (key, OBJPROP_TIMEFRAMES, OBJ_PERIODS_NONE);
   ObjectSetText(key, ""+ value);                                 // (string) color

   return(!catch("Chart.StoreColor(4)"));
}


/**
 * Store a named double value in the chart.
 *
 * @param  string key   - value identifier (max. 63 chars)
 * @param  double value - value to store
 *
 * @return bool - success status
 */
bool Chart.StoreDouble(string key, double value) {
   if (!__isChart) return(!catch("Chart.StoreDouble(1)  illegal calling context (no chart)", ERR_RUNTIME_ERROR));

   int len = StringLen(key);
   if (!len)       return(!catch("Chart.StoreDouble(2)  invalid parameter key: "+ DoubleQuoteStr(key) +" (not a valid chart object identifier)", ERR_INVALID_PARAMETER));
   if (len > 63)   return(!catch("Chart.StoreDouble(3)  invalid parameter key: "+ DoubleQuoteStr(key) +" (more than 63 chars)", ERR_INVALID_PARAMETER));

   if (ObjectFind(key) == 0)
      ObjectDelete(key);
   ObjectCreate (key, OBJ_LABEL, 0, 0, 0);
   ObjectSet    (key, OBJPROP_TIMEFRAMES, OBJ_PERIODS_NONE);
   ObjectSetText(key, NumberToStr(value, ".+"));                  // (string) double

   return(!catch("Chart.StoreDouble(4)"));
}


/**
 * Store a named string in the chart.
 *
 * @param  string key   - value identifier (max. 63 chars)
 * @param  string value - value to store (max. 63 chars)
 *
 * @return bool - success status
 */
bool Chart.StoreString(string key, string value) {
   if (!__isChart) return(!catch("Chart.StoreString(1)  illegal calling context (no chart)", ERR_RUNTIME_ERROR));

   int len = StringLen(key);
   if (!len)       return(!catch("Chart.StoreString(2)  invalid parameter key: "+ DoubleQuoteStr(key) +" (not a valid chart object identifier)", ERR_INVALID_PARAMETER));
   if (len > 63)   return(!catch("Chart.StoreString(3)  invalid parameter key: "+ DoubleQuoteStr(key) +" (more than 63 chars)", ERR_INVALID_PARAMETER));

   len = StringLen(value);
   if (len > 63)   return(!catch("Chart.StoreString(4)  invalid parameter value: "+ DoubleQuoteStr(value) +" (more than 63 chars)", ERR_INVALID_PARAMETER));

   if (!len) value = "…(empty)…";                                 // mark empty string with magic value (0x85) as the terminal fails to restore them

   if (ObjectFind(key) == 0)
      ObjectDelete(key);
   ObjectCreate (key, OBJ_LABEL, 0, 0, 0);
   ObjectSet    (key, OBJPROP_TIMEFRAMES, OBJ_PERIODS_NONE);
   ObjectSetText(key, value);                                     // string

   return(!catch("Chart.StoreString(5)"));
}


/**
 * Restore a named boolean value from the chart.
 *
 * @param  _In_  string key               - value identifier (max. 63 chars)
 * @param  _Out_ bool   var               - variable to restore
 * @param  _In_  bool   remove [optional] - whether to remove the stored value (default: yes)
 *
 * @return bool - whether the value was found and successfully restored
 */
bool Chart.RestoreBool(string key, bool &var, bool remove = true) {
   remove = remove!=0;
   if (!__isChart)  return(!catch("Chart.RestoreBool(1)  illegal calling context (no chart)", ERR_RUNTIME_ERROR));

   int keyLen = StringLen(key);
   if (!keyLen)     return(!catch("Chart.RestoreBool(2)  invalid parameter key: "+ DoubleQuoteStr(key) +" (not a valid chart object identifier)", ERR_INVALID_PARAMETER));
   if (keyLen > 63) return(!catch("Chart.RestoreBool(3)  invalid parameter key: "+ DoubleQuoteStr(key) +" (more than 63 chars)", ERR_INVALID_PARAMETER));

   if (ObjectFind(key) == 0) {
      string sValue = ObjectDescription(key);
      if (sValue!="0" && sValue!="1") return(!catch("Chart.RestoreBool(4)  illegal chart value "+ DoubleQuoteStr(key) +" = "+ DoubleQuoteStr(sValue), ERR_RUNTIME_ERROR));
      if (remove) ObjectDelete(key);
      var = (sValue == "1");                               // (bool) string

      return(!catch("Chart.RestoreBool(5)"));
   }
   return(false);
}


/**
 * Restore a named integer value from the chart.
 *
 * @param  _In_  string key               - value identifier (max. 63 chars)
 * @param  _Out_ int    var               - variable to restore
 * @param  _In_  bool   remove [optional] - whether to remove the stored value (default: yes)
 *
 * @return bool - whether the value was found and successfully restored
 */
bool Chart.RestoreInt(string key, int &var, bool remove = true) {
   remove = remove!=0;
   if (!__isChart)  return(!catch("Chart.RestoreInt(1)  illegal calling context (no chart)", ERR_RUNTIME_ERROR));

   int keyLen = StringLen(key);
   if (!keyLen)     return(!catch("Chart.RestoreInt(2)  invalid parameter key: "+ DoubleQuoteStr(key) +" (not a valid chart object identifier)", ERR_INVALID_PARAMETER));
   if (keyLen > 63) return(!catch("Chart.RestoreInt(3)  invalid parameter key: "+ DoubleQuoteStr(key) +" (more than 63 chars)", ERR_INVALID_PARAMETER));

   if (ObjectFind(key) == 0) {
      string sValue = ObjectDescription(key);
      if (!StrIsInteger(sValue)) return(!catch("Chart.RestoreInt(4)  illegal chart value "+ DoubleQuoteStr(key) +" = "+ DoubleQuoteStr(sValue), ERR_RUNTIME_ERROR));
      if (remove) ObjectDelete(key);
      var = StrToInteger(sValue);                          // (int) string

      return(!catch("Chart.RestoreInt(5)"));
   }
   return(false);
}


/**
 * Restore a named color value from the chart.
 *
 * @param  _In_  string key               - value identifier (max. 63 chars)
 * @param  _Out_ color  var               - variable to restore
 * @param  _In_  bool   remove [optional] - whether to remove the stored value (default: yes)
 *
 * @return bool - whether the value was found and successfully restored
 */
bool Chart.RestoreColor(string key, color &var, bool remove = true) {
   remove = remove!=0;
   if (!__isChart)               return(!catch("Chart.RestoreColor(1)  illegal calling context (no chart)", ERR_RUNTIME_ERROR));

   int keyLen = StringLen(key);
   if (!keyLen)                  return(!catch("Chart.RestoreColor(2)  invalid parameter key: "+ DoubleQuoteStr(key) +" (not a valid chart object identifier)", ERR_INVALID_PARAMETER));
   if (keyLen > 63)              return(!catch("Chart.RestoreColor(3)  invalid parameter key: "+ DoubleQuoteStr(key) +" (more than 63 chars)", ERR_INVALID_PARAMETER));

   if (ObjectFind(key) == 0) {
      string sValue = ObjectDescription(key);
      if (!StrIsInteger(sValue)) return(!catch("Chart.RestoreColor(4)  illegal chart value "+ DoubleQuoteStr(key) +" = "+ DoubleQuoteStr(sValue), ERR_RUNTIME_ERROR));
      int iValue = StrToInteger(sValue);
      if (iValue < CLR_NONE || iValue > C'255,255,255')
                                 return(!catch("Chart.RestoreColor(5)  illegal chart value "+ DoubleQuoteStr(key) +" = "+ DoubleQuoteStr(sValue) +" (0x"+ IntToHexStr(iValue) +")", ERR_RUNTIME_ERROR));
      if (remove) ObjectDelete(key);
      var = iValue;                                        // (color)(int) string

      return(!catch("Chart.RestoreColor(6)"));
   }
   return(false);
}


/**
 * Restore a named double value from the chart.
 *
 * @param  _In_  string key               - value identifier (max. 63 chars)
 * @param  _Out_ double var               - variable to restore
 * @param  _In_  bool   remove [optional] - whether to remove the stored value (default: yes)
 *
 * @return bool - whether the value was found and successfully restored
 */
bool Chart.RestoreDouble(string key, double &var, bool remove = true) {
   remove = remove!=0;
   if (!__isChart)               return(!catch("Chart.RestoreDouble(1)  illegal calling context (no chart)", ERR_RUNTIME_ERROR));

   int keyLen = StringLen(key);
   if (!keyLen)                  return(!catch("Chart.RestoreDouble(2)  invalid parameter key: "+ DoubleQuoteStr(key) +" (not a valid chart object identifier)", ERR_INVALID_PARAMETER));
   if (keyLen > 63)              return(!catch("Chart.RestoreDouble(3)  invalid parameter key: "+ DoubleQuoteStr(key) +" (more than 63 chars)", ERR_INVALID_PARAMETER));

   if (ObjectFind(key) == 0) {
      string sValue = ObjectDescription(key);
      if (!StrIsNumeric(sValue)) return(!catch("Chart.RestoreDouble(4)  illegal chart value "+ DoubleQuoteStr(key) +" = "+ DoubleQuoteStr(sValue), ERR_RUNTIME_ERROR));
      if (remove) ObjectDelete(key);
      var = StrToDouble(sValue);                            // (double) string

      return(!catch("Chart.RestoreDouble(5)"));
   }
   return(false);
}


/**
 * Restore a named string from the chart.
 *
 * @param  _In_  string key               - value identifier (max. 63 chars)
 * @param  _Out_ string var               - variable to restore
 * @param  _In_  bool   remove [optional] - whether to remove the stored value (default: yes)
 *
 * @return bool - whether the value was found and successfully restored
 */
bool Chart.RestoreString(string key, string &var, bool remove = true) {
   remove = remove!=0;
   if (!__isChart)  return(!catch("Chart.RestoreString(1)  illegal calling context (no chart)", ERR_RUNTIME_ERROR));

   int keyLen = StringLen(key);
   if (!keyLen)     return(!catch("Chart.RestoreString(2)  invalid parameter key: "+ DoubleQuoteStr(key) +" (not a valid chart object identifier)", ERR_INVALID_PARAMETER));
   if (keyLen > 63) return(!catch("Chart.RestoreString(3)  invalid parameter key: "+ DoubleQuoteStr(key) +" (more than 63 chars)", ERR_INVALID_PARAMETER));

   if (ObjectFind(key) == 0) {
      string sValue = ObjectDescription(key);
      if (remove) ObjectDelete(key);
      if (sValue == "…(empty)…") var = "";                  // convert magic value to empty string as the terminal deserializes "" to the value "Text"
      else                       var = sValue;              // string

      return(!catch("Chart.RestoreString(4)"));
   }
   return(false);
}


/**
 * Get the bar model currently selected in the tester.
 *
 * @return int - bar model id or EMPTY (-1) if not called in the tester
 */
int Tester.GetBarModel() {
   if (!This.IsTesting())
      return(_EMPTY(catch("Tester.GetBarModel(1)  tester only function", ERR_FUNC_NOT_ALLOWED)));
   return(Tester_GetBarModel());
}


/**
 * Pause the tester. Can be used only in the tester.
 *
 * @param  string caller [optional] - location identifier of the caller (default: none)
 *
 * @return int - error status
 */
int Tester.Pause(string caller = "") {
   if (!This.IsTesting()) return(catch("Tester.Pause(1)  tester only function", ERR_FUNC_NOT_ALLOWED));

   if (!__isChart)         return(NO_ERROR);                            // skip if VisualMode=Off
   if (Tester.IsStopped()) return(NO_ERROR);                            // skip if already stopped
   if (Tester.IsPaused())  return(NO_ERROR);                            // skip if already paused

   int hWnd = GetTerminalMainWindow();
   if (!hWnd) return(last_error);

   if (IsLogDebug()) logDebug(caller + ifString(StringLen(caller), "->", "") +"Tester.Pause()");

   PostMessageA(hWnd, WM_COMMAND, IDC_TESTER_SETTINGS_PAUSERESUME, 0);  // SendMessage() would cause a UI thread dead-lock if called in deinit()
   return(NO_ERROR);
}


/**
 * Stop the tester. Can be used only in the tester.
 *
 * @param  string caller [optional] - location identifier of the caller (default: none)
 *
 * @return int - error status
 */
int Tester.Stop(string caller = "") {
   if (!IsTesting()) return(catch("Tester.Stop(1)  tester only function", ERR_FUNC_NOT_ALLOWED));

   if (Tester.IsStopped()) return(NO_ERROR);                            // skip if already stopped

   if (IsLogDebug()) logDebug(caller + ifString(StringLen(caller), "->", "") +"Tester.Stop()");

   int hWnd = GetTerminalMainWindow();
   if (!hWnd) return(last_error);

   PostMessageA(hWnd, WM_COMMAND, IDC_TESTER_SETTINGS_STARTSTOP, 0);    // SendMessage() causes a UI thread dead-lock if called in deinit()
   return(NO_ERROR);
}


/**
 * Whether the tester currently pauses. Can be used only in the tester.
 *
 * @return bool
 */
bool Tester.IsPaused() {
   if (!This.IsTesting())  return(!catch("Tester.IsPaused(1)  tester only function", ERR_FUNC_NOT_ALLOWED));
   if (!__isChart)         return(false);
   if (Tester.IsStopped()) return(false);

   int hWndTesterSettings = GetDlgItem(FindTesterWindow(), IDC_TESTER_SETTINGS);
   int hWndPauseResumeBtn = GetDlgItem(hWndTesterSettings, IDC_TESTER_SETTINGS_PAUSERESUME);

   return(GetInternalWindowTextA(hWndPauseResumeBtn) == ">>");
}


/**
 * Whether the tester is stopped. Can be used only in the tester.
 *
 * @return bool
 */
bool Tester.IsStopped() {
   if (!This.IsTesting()) return(!catch("Tester.IsStopped(1)  tester only function", ERR_FUNC_NOT_ALLOWED));

   if (IsScript()) {
      int hWndTesterSettings = GetDlgItem(FindTesterWindow(), IDC_TESTER_SETTINGS);
      int hWndStartStopBtn   = GetDlgItem(hWndTesterSettings, IDC_TESTER_SETTINGS_STARTSTOP);
      // TODO: because of i18n we can't rely on the control's text
      return(GetInternalWindowTextA(hWndStartStopBtn) == "Start");
   }
   return(__ExecutionContext[EC.programCoreFunction] == CF_DEINIT);     // if in deinit() the tester was already stopped,
}                                                                       // no matter whether in an expert or an indicator


/**
 * Create a new chart legend object for the current program. An existing legend object is reused.
 *
 * @return string - label name
 */
string CreateLegendLabel() {
   if (IsSuperContext())
      return("");

   string label = "rsf.Legend."+ __ExecutionContext[EC.pid];
   int xDistance =  5;
   int yDistance = 21;

   if (ObjectFind(label) >= 0) {
      // reuse the existing label
   }
   else {
      // create a new label
      int objects=ObjectsTotal(), labels=ObjectsTotal(OBJ_LABEL);

      for (int i=0; i < objects && labels; i++) {
         string name = ObjectName(i);
         if (ObjectType(name) == OBJ_LABEL) {
            if (StrStartsWith(name, "rsf.Legend."))
               yDistance += 19;
            labels--;
         }
      }
      if (ObjectCreate(label, OBJ_LABEL, 0, 0, 0)) {
         ObjectSet(label, OBJPROP_CORNER, CORNER_TOP_LEFT);
         ObjectSet(label, OBJPROP_XDISTANCE, xDistance);
         ObjectSet(label, OBJPROP_YDISTANCE, yDistance);
      }
      else GetLastError();
   }
   ObjectSetText(label, " ");

   return(ifString(catch("CreateLegendLabel(1)"), "", label));
}


/**
 * Erzeugt einen neuen String der gewünschten Länge.
 *
 * @param  int length - Länge
 *
 * @return string
 */
string CreateString(int length) {
   if (length < 0)        return(_EMPTY_STR(catch("CreateString(1)  invalid parameter length: "+ length, ERR_INVALID_PARAMETER)));
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
   if (Ticks == lastTick)
      return(lastResult);

   // Es reicht immer, den Tick nur anhand des Volumens des aktuellen Timeframes zu bestimmen.
   bool result = (lastVol && vol!=lastVol);                          // wenn der letzte Tick gültig war und sich das aktuelle Volumen geändert hat
                                                                     // (Optimierung unnötig, da im Normalfall immer beide Bedingungen zutreffen)
   lastVol    = vol;
   lastResult = result;
   return(result);
}


/**
 * Return the current trade server time. In tester this time is modeled. Different from the last known tick time which is only
 * updated on new ticks.
 *
 * @param  bool watchLastTick [optional] - account for a server clock being fast wich happens quite often (default: yes)
 *
 * @return datetime - the larger one of last tick time and trade server time or NULL (0) in case of errors
 */
datetime TimeServer(bool watchLastTick = true) {
   watchLastTick = watchLastTick!=0;         // (bool) int

   static bool isLibrary = -1;
   if (isLibrary == -1) isLibrary = IsLibrary();

   if (This.IsTesting())
      return(TimeCurrent());

   datetime serverTime = GmtToServerTime(GetGmtTime());
   if (serverTime == NaT) return(NULL);

   if (watchLastTick) {
      datetime lastTickTime = TimeCurrent();
      if (lastTickTime > serverTime)
         return(lastTickTime);
   }
   return(serverTime);
}


/**
 * Return the current trade server time in GMT. In tester the time is modeled.
 *
 * @return datetime - trade server time in GMT or NULL (0) in case of errors
 */
datetime TimeGMT() {
   datetime gmt;

   if (This.IsTesting()) {
      // TODO: Scripte und Indikatoren sehen bei Aufruf von TimeLocal() im Tester u.U. nicht die modellierte, sondern die reale Zeit oder sogar NULL.
      datetime localTime = Tick.time;
      gmt = ServerToGmtTime(localTime);            // the last tick time entspricht im Tester der Serverzeit
   }
   else {
      gmt = GetGmtTime();
   }
   return(gmt);
}


/**
 * Return the current trade server time in FXT. In tester the time is modeled.
 *
 * @return datetime - trade server time in FXT or NULL (0) in case of errors
 */
datetime TimeFXT() {
   datetime gmt = TimeGMT();         if (!gmt)       return(NULL);
   datetime fxt = GmtToFxtTime(gmt); if (fxt == NaT) return(NULL);
   return(fxt);
}


/**
 * Return the current system time in FXT (also in tester).
 *
 * @return datetime - system time in FXT or NULL in case of errors
 *
 * @see  TimeFXT() to return the modeled FXT time in tester
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
 * Drop-in replacement for the flawed built-in function TimeLocal().
 *
 * Returns the system's local time. In tester the time is modeled and the same as trade server time. This means during testing
 * the local timezone is set to the trade server's timezone.
 *
 * @param  string caller [optional] - location identifier of the caller (default: none)
 *
 * @return datetime - time or NULL (0) in case of errors
 *
 * NOTE: This function signals an error if TimeLocal() returns an invalid value.
 */
datetime TimeLocalEx(string caller = "") {
   datetime time = TimeLocal();
   if (!time) return(!catch(caller + ifString(!StringLen(caller), "", "->") +"TimeLocalEx(1)->TimeLocal() = 0", ERR_RUNTIME_ERROR));
   return(time);
}


/**
 * Format a timestamp as a string representing GMT time. MQL wrapper for the ANSI function of the MT4Expander.
 *
 * @param  datetime timestamp - Unix timestamp (GMT)
 * @param  string   format    - format control string supported by strftime()
 *
 * @return string - GMT time string or an empty string in case of errors
 *
 * @link  http://www.cplusplus.com/reference/ctime/strftime/
 * @link  ms-help://MS.VSCC.v90/MS.MSDNQTR.v90.en/dv_vccrt/html/6330ff20-4729-4c4a-82af-932915d893ea.htm
 */
string GmtTimeFormat(datetime timestamp, string format) {
   return(GmtTimeFormatA(timestamp, format));
}


/**
 * Format a timestamp as a string representing local time. MQL wrapper for the ANSI function of the MT4Expander.
 *
 * @param  datetime timestamp - Unix timestamp (GMT)
 * @param  string   format    - format control string supported by strftime()
 *
 * @return string - local time string or an empty string in case of errors
 *
 * @link  http://www.cplusplus.com/reference/ctime/strftime/
 * @link  ms-help://MS.VSCC.v90/MS.MSDNQTR.v90.en/dv_vccrt/html/6330ff20-4729-4c4a-82af-932915d893ea.htm
 */
string LocalTimeFormat(datetime timestamp, string format) {
   return(LocalTimeFormatA(timestamp, format));
}


/**
 * Generate a random integer value between the specified minimum and maximum values.
 *
 * @param  int min - minimum value
 * @param  int max - maximum value
 *
 * @return int
 */
int GetRandomValue(int min, int max) {
   static bool seeded = false; if (!seeded) {
      MathSrand(GetTickCount()-__ExecutionContext[EC.hChartWindow]);
      seeded = true;
   }
   int    value = MathRand();                   // pseudo-random value from 0 to 32767
   double percent = value/32767.0;
   double result = min + (max-min) * percent;

   return(MathRound(result));
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
      // terminal builds > 509
      case UR_TEMPLATE   : return("template changed"                   );
      case UR_INITFAILED : return("OnInit() failed"                    );
      case UR_CLOSE      : return("terminal closed"                    );
   }
   return(_EMPTY_STR(catch("UninitializeReasonDescription()  invalid parameter reason: "+ reason, ERR_INVALID_PARAMETER)));
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
 * Get the configured value of an account's externally hold assets. The returned value can be negative to scale-down the
 * account size (e.g. for testing in a real account).
 *
 * @param  string company [optional] - account company as returned by GetAccountCompanyId() (default: the current company id)
 * @param  int    account [optional] - account number (default: the current account number)
 * @param  bool   refresh [optional] - whether to refresh a cached value (default: no)
 *
 * @return double - asset value in account currency or EMPTY_VALUE in case of errors
 */
double GetExternalAssets(string company="", int account=NULL, bool refresh=false) {
   refresh = refresh!=0;

   if (!StringLen(company) || company=="0") {
      company = GetAccountCompanyId();
      if (!StringLen(company)) return(EMPTY_VALUE);
   }
   if (account <= 0) {
      if (account < 0) return(_EMPTY_VALUE(catch("GetExternalAssets(1)  invalid parameter account: "+ account, ERR_INVALID_PARAMETER)));
      account = GetAccountNumber();
      if (!account) return(EMPTY_VALUE);
   }

   static string lastCompany = "";
   static int    lastAccount = 0;
   static double lastResult;

   if (refresh || company!=lastCompany || account!=lastAccount) {
      string file = GetAccountConfigPath(company, account);
      if (!StringLen(file)) return(EMPTY_VALUE);

      double value = GetIniDouble(file, "General", "ExternalAssets");
      if (IsEmptyValue(value)) return(EMPTY_VALUE);

      lastCompany = company;
      lastAccount = account;
      lastResult  = value;
   }
   return(lastResult);
}


/**
 * Return the full path of the current account/trade server directory. The function doesn't check whether the directory exists.
 *
 * @return string - directory name or an empty string in case of errors
 */
string GetAccountServerPath() {
   string directory  = GetHistoryRootPathA(); if (directory == "")  return("");
   string serverName = GetAccountServer();    if (serverName == "") return("");
   return(StringConcatenate(directory, "\\", serverName));
}


/**
 * Return the identifier of the current account company. The identifier is case-insensitive and consists of alpha-numerical
 * characters only. By default the identifier matches the first word of the current tradeserver name. It can be mapped to a
 * different company identifier via section [AccountCompanies] of the framework configuration.
 *
 * @return string - original or mapped company identifier or an empty string in case of errors
 *
 * Example:
 * +--------------------+--------------------+
 * | Tradeserver        | Default identifier |
 * +--------------------+--------------------+
 * | Alpari-Standard1   | Alpari             | Without name mapping all servers have different company identifiers.
 * | AlpariBroker-Demo  | AlpariBroker       |
 * | AlpariUK-Classic-1 | AlpariUK           |
 * | AlpariUK-Live2     | AlpariUK           |
 * +--------------------+--------------------+
 *
 * Mapping via framework configuration:
 * [AccountCompanies]
 *  alparibroker   = Alpari                  ; With name mapping different servers can be grouped together.
 *  alpariuk       = Alpari
 *  alpariuk-live2 = AlpariLive              ; A mapped full server name precedes a mapping for a default identifier.
 */
string GetAccountCompanyId() {
   // Da bei Accountwechsel der Rückgabewert von AccountServer() bereits wechselt, obwohl der aktuell verarbeitete Tick noch
   // auf Daten des alten Account-Servers arbeitet, kann die Funktion AccountServer() nicht direkt verwendet werden. Statt
   // dessen muß immer der Umweg über GetAccountServer() gegangen werden. Die Funktion gibt erst dann einen geänderten
   // Servernamen zurück, wenn tatsächlich ein Tick des neuen Servers verarbeitet wird.
   static string lastServer="", lastId="";

   string server = GetAccountServer(); if (!StringLen(server)) return("");
   if (server == lastServer)
      return(lastId);

   string mapping = GetGlobalConfigString("AccountCompanies", server);     // global only to prevent recursion
   if (StringLen(mapping) > 0) {
      lastServer = server;
      lastId = mapping;
      return(lastId);
   }

   string word1 = StrLeftTo(server, "-");
   lastId = GetGlobalConfigString("AccountCompanies", word1, word1);
   lastServer = server;
   return(lastId);
}


/**
 * Return the alias of an account. The alias is used in outbound messages (SMS, email, chat) to obfuscate the actual account
 * number and is configurable via the framework configuration. If no alias is configured the function returns the account
 * number with all characters except the last 4 replaced by wildcards.
 *
 * @param  string company [optional] - account company as returned by GetAccountCompanyId() (default: the current company id)
 * @param  int    account [optional] - account number (default: the current account number)
 *
 * @return string - account alias or an empty string in case of errors
 */
string GetAccountAlias(string company="", int account=NULL) {
   if (!StringLen(company) || company=="0") {
      company = GetAccountCompanyId();
      if (!StringLen(company)) return(EMPTY_STR);
   }
   if (account <= 0) {
      if (account < 0) return(_EMPTY_STR(catch("GetAccountAlias(1)  invalid parameter account: "+ account, ERR_INVALID_PARAMETER)));
      account = GetAccountNumber();
      if (!account) return(EMPTY_STR);
   }

   string result = GetGlobalConfigString("Accounts", account +".alias");
   if (!StringLen(result)) {
      logNotice("GetAccountAlias(2)  no account alias found for account "+ DoubleQuoteStr(company +":"+ account));
      result = account;
      result = StrRepeat("*", StringLen(result)-4) + StrRight(result, 4);
   }
   return(result);
}


/**
 * Return the account number of an account alias.
 *
 * @param  string company - account company
 * @param  string alias   - account alias
 *
 * @return int - account number or NULL in case of errors or if the account alias is unknown
 */
int GetAccountNumberFromAlias(string company, string alias) {
   if (!StringLen(company)) return(!catch("GetAccountNumberFromAlias(1)  invalid parameter company: \"\"", ERR_INVALID_PARAMETER));
   if (!StringLen(alias))   return(!catch("GetAccountNumberFromAlias(2)  invalid parameter alias: \"\"", ERR_INVALID_PARAMETER));

   string file = GetGlobalConfigPathA(); if (!StringLen(file)) return(NULL);
   string section = "Accounts";
   string keys[], value="", sAccount="";
   int keysSize = GetIniKeys(file, section, keys);

   for (int i=0; i < keysSize; i++) {
      if (StrEndsWithI(keys[i], ".alias")) {
         value = GetGlobalConfigString(section, keys[i]);
         if (StrCompareI(value, alias)) {
            sAccount = StringTrimRight(StrLeft(keys[i], -6));
            value    = GetGlobalConfigString(section, sAccount +".company");
            if (StrCompareI(value, company)) {
               if (StrIsDigit(sAccount))
                  return(StrToInteger(sAccount));
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
      return(!catch("StrContains(1)  illegal parameter substring: "+ DoubleQuoteStr(substring), ERR_INVALID_PARAMETER));
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
      return(!catch("StrContainsI(1)  illegal parameter substring: "+ DoubleQuoteStr(substring), ERR_INVALID_PARAMETER));
   return(StringFind(StrToUpper(value), StrToUpper(substring)) != -1);
}


/**
 * Whether a string contains at least one of the specified characters.
 *
 * @param  string value   - string to inspect
 * @param  int    chars[] - character values
 *
 * @return bool
 */
bool StrContainsChars(string value, int chars[]) {
   if (StringLen(value) > 0) {
      int size = ArraySize(chars);
      for (int i=0; i < size; i++) {
         if (chars[i] < 0 || chars[i] > 255) {
            return(!catch("StrContainsChars(1)  illegal character value chars["+ i +"]: "+ chars[i], ERR_INVALID_PARAMETER));
         }
         if (StringFind(value, CharToStr(chars[i])) >= 0) {
            return(true);
         }
      }
   }
   return(false);
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
 * @param  string input - string to be repeated
 * @param  int    times - number of times to repeat the string
 *
 * @return string - the repeated string or an empty string in case of errors
 */
string StrRepeat(string input, int times) {
   if (times < 0)         return(_EMPTY_STR(catch("StrRepeat(1)  invalid parameter times: "+ times, ERR_INVALID_PARAMETER)));
   if (!times)            return("");
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

   return(_NULL(catch("GetCurrencyId(1)  unknown currency: \""+ currency +"\"", ERR_RUNTIME_ERROR)));
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
   return(_EMPTY_STR(catch("GetCurrency(1)  unknown currency id: "+ id, ERR_RUNTIME_ERROR)));
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
 * Whether the specified value is considered an absolute path.
 *
 * @param  string path
 *
 * @return bool
 */
bool IsAbsolutePath(string path) {
   int len = StringLen(path);

   if (len > 1) {
      int chr = StringGetChar(path, 0);
      if ((chr >= 'a' && chr <= 'z') || (chr >= 'A' && chr <= 'Z'))
         return(StringGetChar(path, 1) == ':');
   }
   return(false);
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
 * @return int - OperationType-Code oder OP_UNDEFINED (-1), wenn der Bezeichner ungültig ist
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

   if (IsLogDebug()) logDebug("StrToOperationType(1)  invalid parameter value: \""+ value +"\" (not an operation type)", ERR_INVALID_PARAMETER);
   return(OP_UNDEFINED);
}


/**
 * Return the integer constant of a trade direction identifier.
 *
 * @param  string value            - string representation of a trade direction: [TRADE_DIRECTION_](LONG|SHORT|BOTH)
 * @param  int    flags [optional] - execution control flags (default: none)
 *                                   F_PARTIAL_ID:            recognize partial but unique identifiers, e.g. "L" = "Long"
 *                                   F_ERR_INVALID_PARAMETER: set ERR_INVALID_PARAMETER silently
 *
 * @return int - trade direction constant or EMPTY (-1) if the value is not recognized
 */
int StrToTradeDirection(string value, int flags = NULL) {
   string str = StrToUpper(StrTrim(value));

   if (StrStartsWith(str, "TRADE_DIRECTION_")) {
      flags &= (~F_PARTIAL_ID);                                // TRADE_DIRECTION_* doesn't support the F_PARTIAL_ID flag
      if (str == "TRADE_DIRECTION_LONG" ) return(TRADE_DIRECTION_LONG );
      if (str == "TRADE_DIRECTION_SHORT") return(TRADE_DIRECTION_SHORT);
      if (str == "TRADE_DIRECTION_BOTH" ) return(TRADE_DIRECTION_BOTH );
   }
   else if (StringLen(str) > 0) {
      if (str == ""+ TRADE_DIRECTION_LONG ) return(TRADE_DIRECTION_LONG );
      if (str == ""+ TRADE_DIRECTION_SHORT) return(TRADE_DIRECTION_SHORT);
      if (str == ""+ TRADE_DIRECTION_BOTH ) return(TRADE_DIRECTION_BOTH );

      if (flags & F_PARTIAL_ID && 1) {
         if (StrStartsWith("LONG",  str)) return(TRADE_DIRECTION_LONG );
         if (StrStartsWith("SHORT", str)) return(TRADE_DIRECTION_SHORT);
         if (StrStartsWith("BOTH",  str)) return(TRADE_DIRECTION_BOTH );
      }
      else {
         if (str == "LONG" ) return(TRADE_DIRECTION_LONG );
         if (str == "SHORT") return(TRADE_DIRECTION_SHORT);
         if (str == "BOTH" ) return(TRADE_DIRECTION_BOTH );
      }
   }

   if (flags & F_ERR_INVALID_PARAMETER && 1) SetLastError(ERR_INVALID_PARAMETER);
   else                                      catch("StrToTradeDirection(1)  invalid parameter value: "+ DoubleQuoteStr(value), ERR_INVALID_PARAMETER);
   return(-1);
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
   return(_EMPTY_STR(catch("TradeCommandToStr(1)  invalid parameter cmd: "+ cmd +" (not a trade command )", ERR_INVALID_PARAMETER)));
}


/**
 * Formatiert einen numerischen Wert im angegebenen Format und gibt den resultierenden String zurück.
 * The basic mask is "n" or "n.d" where n is the number of digits to the left and d is the number of digits to the right of
 * the decimal point.
 *
 * Mask parameters:
 *
 *   n        = specified number of digits left of the decimal point, e.g. NumberToStr(123.456, "5") => "123"
 *   n.d      = specified number of left and right digits, e.g. NumberToStr(123.456, "5.2") => "123.45"
 *   n.       = specified number of left and all right digits, e.g. NumberToStr(123.456, "2.") => "23.456"
 *    .d      = all left and specified number of right digits, e.g. NumberToStr(123.456, ".2") => "123.45"
 *    .d'     = all left and specified number of right digits plus 1 separate subpip digit,
 *              e.g. NumberToStr(123.45678, ".4'") => "123.4567'8"
 *    .d+     = "+" char anywhere right of .d: all left and minimum number of right digits,
 *              e.g. NumberToStr(123.45, ".3+") => "123.450"
 *  +n.d      = "+" char anywhere left of n.: plus sign for positive values
 *    R       = "R" char anywhere: round result at the last displayed digit,
 *              e.g. NumberToStr(123.456, "R3.2") => "123.46" or NumberToStr(123.7, "R3") => "124"
 *    ;       = switch thousands and decimal separators (European format), e.g. NumberToStr(123456.789, "6.2;") => "123456,78"
 *    ,       = insert thousands separators, e.g. NumberToStr(123456.789, "6.2,") => "123,456.78"
 *    ,<char> = insert thousands separators using <char>, e.g. NumberToStr(123456.789, ",'6.2") => "123'456.78"
 *
 * @param  double value
 * @param  string mask
 *
 * @return string - formatierter Wert
 */
string NumberToStr(double value, string mask) {
   string sNumber = value;
   if (StringGetChar(sNumber, 3) == '#')                    // "-1.#IND0000" => NaN
      return(sNumber);                                      // "-1.#INF0000" => Infinite

   int error = GetLastError();
   if (error != NO_ERROR) catch("NumberToStr(1)  unhandled error (value="+ value +", mask=\""+ mask +"\")", error);

   // --- Beginn Maske parsen -------------------------
   int maskLen = StringLen(mask);

   // zu allererst Separatorenformat erkennen
   string sepThousand=",", sepDecimal=".";
   bool swapSeparators = (StringFind(mask, ";") > -1);
   if (swapSeparators) {
      sepThousand = "."; sepDecimal  = ",";
   }
   int sepPos = StringFind(mask, ",");
   bool separators = (sepPos > -1);
   if (separators) /*&&*/ if (sepPos+1 < maskLen) {
      sepThousand = StringSubstr(mask, sepPos+1, 1);        // user-spezifischen 1000-Separator auslesen und aus Maske löschen
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
   int chr, nLeft;
   bool nDigit;
   for (int i=0; i < dotPos; i++) {
      chr = StringGetChar(mask, i);
      if ('0' <= chr) /*&&*/ if (chr <= '9') {
         nLeft = 10*nLeft + chr-'0';
         nDigit = true;
      }
   }
   if (!nDigit) nLeft = -1;

   // Anzahl der rechten Stellen und Position des Subpip-Separators
   int nRight, nSubpip=-1;
   if (dotGiven) {
      nDigit = false;
      for (i=dotPos+1; i < maskLen; i++) {
         chr = StringGetChar(mask, i);
         if ('0' <= chr && chr <= '9') {
            nRight = 10*nRight + chr-'0';
            nDigit = true;
         }
         else if (nDigit && chr==39) {                      // 39 => '
            nSubpip = nRight;
            continue;
         }
         else {
            if  (chr == '+')  nRight = Max(nRight + (nSubpip > -1), CountDecimals(value));
            else if (!nDigit) nRight = CountDecimals(value);
            break;
         }
      }
      if (nDigit) {
         if (nSubpip > -1) nRight++;
         if (nSubpip == 0) nSubpip = -1;     // no subpip separator directly after the decimal point
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
      string out1 = "";
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
   if (nSubpip > -1) {
      outStr = StringConcatenate(StrLeft(outStr, nSubpip-nRight), "'", StrSubstr(outStr, nSubpip-nRight));
   }

   // Vorzeichen etc. anfügen
   outStr = StringConcatenate(leadSign, outStr);

   error = GetLastError();
   if (error != NO_ERROR) catch("NumberToStr(2)  value="+ value +", mask=\""+ mask +"\"", error);
   return(outStr);
}


/**
 * Format a value representing a pip distance of the current symbol. Depending on symbol and symbol price the resulting
 * string is the pip amount converted to pips, subpips or quote units (e.g. index points).
 *
 * @param  double value                         - pip distance
 * @param  bool   thousandsSeparator [optional] - whether to use the thousands separator "'" (default: no)
 * @param  bool   appendSuffix       [optional] - whether to append the suffix " pip" to the formatted value (default: no)
 *
 * @return string
 */
string PipToStr(double value, bool thousandsSeparator=false, bool appendSuffix=false) {
   thousandsSeparator = thousandsSeparator!=0;
   appendSuffix       = appendSuffix!=0;
   string sSeparator="", sValue=value;
   if (thousandsSeparator) sSeparator = ",'";

   if (StringGetChar(sValue, 3) == '#')                              // "-1.#IND0000" => NaN
      return(sValue);                                                // "-1.#INF0000" => Infinite

   if (Digits==2 && Close[0]>=500) {
      sValue = NumberToStr(value/100, sSeparator +"R.2");            // 123 pip => 1.23 quote units/index points
   }
   else {
      sValue = NumberToStr(value, sSeparator +"R."+ (Digits & 1));   // 123 pip
      if (appendSuffix) sValue = StringConcatenate(sValue, " pip");
   }
   return(sValue);
}


/**
 * Return the description of a loglevel constant.
 *
 * @param  int level - loglevel
 *
 * @return string
 */
string LoglevelDescription(int level) {
   switch (level) {
      case LOG_DEBUG : return("DEBUG" );
      case LOG_INFO  : return("INFO"  );
      case LOG_NOTICE: return("NOTICE");
      case LOG_WARN  : return("WARN"  );
      case LOG_ERROR : return("ERROR" );
      case LOG_FATAL : return("FATAL" );
      case LOG_OFF   : return("OFF"   );        // not a regular loglevel
   }
   return(""+ level);
}


/**
 * Return the description of a timeframe identifier. Supports custom timeframes.
 *
 * @param  int period [optional] - timeframe identifier or number of minutes per period (default: the current chart period)
 *
 * @return string
 *
 * Note: As DLL calls may be disabled we need an MQL implementation. This one should match the one in the MT4Expander.
 */
string PeriodDescription(int period = NULL) {
   if (!period) period = Period();

   switch (period) {
      case PERIOD_M1 : return("M1" );     // 1 minute
      case PERIOD_M5 : return("M5" );     // 5 minutes
      case PERIOD_M15: return("M15");     // 15 minutes
      case PERIOD_M30: return("M30");     // 30 minutes
      case PERIOD_H1 : return("H1" );     // 1 hour
      case PERIOD_H2 : return("H2" );     // 2 hours (custom timeframe)
      case PERIOD_H3 : return("H3" );     // 3 hours (custom timeframe)
      case PERIOD_H4 : return("H4" );     // 4 hours
      case PERIOD_H6 : return("H6" );     // 6 hours (custom timeframe)
      case PERIOD_H8 : return("H8" );     // 8 hours (custom timeframe)
      case PERIOD_D1 : return("D1" );     // 1 day
      case PERIOD_W1 : return("W1" );     // 1 week
      case PERIOD_MN1: return("MN1");     // 1 month
      case PERIOD_Q1 : return("Q1" );     // 1 quarter (custom timeframe)
   }
   return(""+ period);
}


/**
 * Alias of PeriodDescription().
 *
 * Return the description of a timeframe identifier. Supports custom timeframes.
 *
 * @param  int period [optional] - timeframe identifier or number of minutes per period (default: the current chart period)
 *
 * @return string
 */
string TimeframeDescription(int timeframe = NULL) {
   return(PeriodDescription(timeframe));
}


/**
 * Return the flag for the specified timeframe identifier. Supports custom timeframes.
 *
 * @param  int period [optional] - timeframe identifier (default: timeframe of the current chart)
 *
 * @return int - timeframe flag
 */
int PeriodFlag(int period = NULL) {
   if (period == NULL)
      period = Period();

   switch (period) {
      case PERIOD_M1 : return(F_PERIOD_M1 );
      case PERIOD_M5 : return(F_PERIOD_M5 );
      case PERIOD_M15: return(F_PERIOD_M15);
      case PERIOD_M30: return(F_PERIOD_M30);
      case PERIOD_H1 : return(F_PERIOD_H1 );
      case PERIOD_H2 : return(F_PERIOD_H2 );
      case PERIOD_H3 : return(F_PERIOD_H3 );
      case PERIOD_H4 : return(F_PERIOD_H4 );
      case PERIOD_H6 : return(F_PERIOD_H6 );
      case PERIOD_H8 : return(F_PERIOD_H8 );
      case PERIOD_D1 : return(F_PERIOD_D1 );
      case PERIOD_W1 : return(F_PERIOD_W1 );
      case PERIOD_MN1: return(F_PERIOD_MN1);
      case PERIOD_Q1 : return(F_PERIOD_Q1 );
   }
   return(_NULL(catch("PeriodFlag(1)  invalid parameter period: "+ period, ERR_INVALID_PARAMETER)));
}


/**
 * Alias of PeriodFlag()
 *
 * Return the flag for the specified timeframe identifier. Supports custom timeframes.
 *
 * @param  int period [optional] - timeframe identifier (default: timeframe of the current chart)
 *
 * @return int - timeframe flag
 */
int TimeframeFlag(int timeframe = NULL) {
   return(PeriodFlag(timeframe));
}


/**
 * Return a human-readable representation of a timeframe flag. Supports custom timeframes.
 *
 * @param  int flag - combination of timeframe flags
 *
 * @return string
 */
string PeriodFlagToStr(int flag) {
   string result = "";

   if (!flag)                    result = StringConcatenate(result, "|NULL");
   if (flag & F_PERIOD_M1  && 1) result = StringConcatenate(result, "|F_PERIOD_M1"  );
   if (flag & F_PERIOD_M5  && 1) result = StringConcatenate(result, "|F_PERIOD_M5"  );
   if (flag & F_PERIOD_M15 && 1) result = StringConcatenate(result, "|F_PERIOD_M15" );
   if (flag & F_PERIOD_M30 && 1) result = StringConcatenate(result, "|F_PERIOD_M30" );
   if (flag & F_PERIOD_H1  && 1) result = StringConcatenate(result, "|F_PERIOD_H1"  );
   if (flag & F_PERIOD_H2  && 1) result = StringConcatenate(result, "|F_PERIOD_H2"  );
   if (flag & F_PERIOD_H3  && 1) result = StringConcatenate(result, "|F_PERIOD_H3"  );
   if (flag & F_PERIOD_H4  && 1) result = StringConcatenate(result, "|F_PERIOD_H4"  );
   if (flag & F_PERIOD_H6  && 1) result = StringConcatenate(result, "|F_PERIOD_H6"  );
   if (flag & F_PERIOD_H8  && 1) result = StringConcatenate(result, "|F_PERIOD_H8"  );
   if (flag & F_PERIOD_D1  && 1) result = StringConcatenate(result, "|F_PERIOD_D1"  );
   if (flag & F_PERIOD_W1  && 1) result = StringConcatenate(result, "|F_PERIOD_W1"  );
   if (flag & F_PERIOD_MN1 && 1) result = StringConcatenate(result, "|F_PERIOD_MN1" );
   if (flag & F_PERIOD_Q1  && 1) result = StringConcatenate(result, "|F_PERIOD_Q1"  );

   if (StringLen(result) > 0)
      result = StrSubstr(result, 1);
   return(result);
}


/**
 * Alias of PeriodFlagToStr()
 *
 * Return a human-readable representation of a timeframe flag. Supports custom timeframes.
 *
 * @param  int flag - combination of timeframe flags
 *
 * @return string
 */
string TimeframeFlagToStr(int flag) {
   return(PeriodFlagToStr(flag));
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
 * @param  int    flags [optional] - execution control flags (default: none)
 *                                   F_PARTIAL_ID:            recognize partial but unique identifiers, e.g. "Med" = "Median"
 *                                   F_ERR_INVALID_PARAMETER: don't trigger an internal error on unsupported parameters
 *
 * @return int - price type constant or EMPTY (-1) if the value is not recognized
 */
int StrToPriceType(string value, int flags = NULL) {
   string str = StrToUpper(StrTrim(value));

   if (StrStartsWith(str, "PRICE_")) {
      flags &= (~F_PARTIAL_ID);                                // PRICE_* doesn't support the F_PARTIAL_ID flag
      if (str == "PRICE_OPEN"    ) return(PRICE_OPEN    );
      if (str == "PRICE_HIGH"    ) return(PRICE_HIGH    );
      if (str == "PRICE_LOW"     ) return(PRICE_LOW     );
      if (str == "PRICE_CLOSE"   ) return(PRICE_CLOSE   );
      if (str == "PRICE_MEDIAN"  ) return(PRICE_MEDIAN  );
      if (str == "PRICE_TYPICAL" ) return(PRICE_TYPICAL );
      if (str == "PRICE_WEIGHTED") return(PRICE_WEIGHTED);
      if (str == "PRICE_AVERAGE" ) return(PRICE_AVERAGE );
      if (str == "PRICE_BID"     ) return(PRICE_BID     );
      if (str == "PRICE_ASK"     ) return(PRICE_ASK     );
   }
   else if (StringLen(str) > 0) {
      if (str == ""+ PRICE_OPEN    ) return(PRICE_OPEN    );   // check for numeric identifiers
      if (str == ""+ PRICE_HIGH    ) return(PRICE_HIGH    );
      if (str == ""+ PRICE_LOW     ) return(PRICE_LOW     );
      if (str == ""+ PRICE_CLOSE   ) return(PRICE_CLOSE   );
      if (str == ""+ PRICE_MEDIAN  ) return(PRICE_MEDIAN  );
      if (str == ""+ PRICE_TYPICAL ) return(PRICE_TYPICAL );
      if (str == ""+ PRICE_WEIGHTED) return(PRICE_WEIGHTED);
      if (str == ""+ PRICE_AVERAGE ) return(PRICE_AVERAGE );
      if (str == ""+ PRICE_BID     ) return(PRICE_BID     );
      if (str == ""+ PRICE_ASK     ) return(PRICE_ASK     );

      if (flags & F_PARTIAL_ID && 1) {
         if (StrStartsWith("OPEN",     str))   return(PRICE_OPEN    );
         if (StrStartsWith("HIGH",     str))   return(PRICE_HIGH    );
         if (StrStartsWith("LOW",      str))   return(PRICE_LOW     );
         if (StrStartsWith("CLOSE",    str))   return(PRICE_CLOSE   );
         if (StrStartsWith("MEDIAN",   str))   return(PRICE_MEDIAN  );
         if (StrStartsWith("TYPICAL",  str))   return(PRICE_TYPICAL );
         if (StrStartsWith("WEIGHTED", str))   return(PRICE_WEIGHTED);
         if (StrStartsWith("BID",      str))   return(PRICE_BID     );
         if (StringLen(str) > 1) {
            if (StrStartsWith("ASK",     str)) return(PRICE_ASK     );
            if (StrStartsWith("AVERAGE", str)) return(PRICE_AVERAGE );
         }
      }
      else {
         if (str == "O"       ) return(PRICE_OPEN    );
         if (str == "H"       ) return(PRICE_HIGH    );
         if (str == "L"       ) return(PRICE_LOW     );
         if (str == "C"       ) return(PRICE_CLOSE   );
         if (str == "M"       ) return(PRICE_MEDIAN  );
         if (str == "T"       ) return(PRICE_TYPICAL );
         if (str == "W"       ) return(PRICE_WEIGHTED);
         if (str == "A"       ) return(PRICE_AVERAGE );
         if (str == "OPEN"    ) return(PRICE_OPEN    );
         if (str == "HIGH"    ) return(PRICE_HIGH    );
         if (str == "LOW"     ) return(PRICE_LOW     );
         if (str == "CLOSE"   ) return(PRICE_CLOSE   );
         if (str == "MEDIAN"  ) return(PRICE_MEDIAN  );
         if (str == "TYPICAL" ) return(PRICE_TYPICAL );
         if (str == "WEIGHTED") return(PRICE_WEIGHTED);
         if (str == "AVERAGE" ) return(PRICE_AVERAGE );
         if (str == "BID"     ) return(PRICE_BID     );        // no single letter id
         if (str == "ASK"     ) return(PRICE_ASK     );        // no single letter id
      }
   }

   if (!(flags & F_ERR_INVALID_PARAMETER))
      catch("StrToPriceType(1)  invalid parameter value: "+ DoubleQuoteStr(value), ERR_INVALID_PARAMETER);
   return(-1);
}


/**
 * Return a readable version of a Moving-Average method type constant.
 *
 * @param  int type - MA method type
 *
 * @return string
 */
string MaMethodToStr(int type) {
   switch (type) {
      case MODE_SMA : return("MODE_SMA" );
      case MODE_LWMA: return("MODE_LWMA");
      case MODE_EMA : return("MODE_EMA" );
      case MODE_SMMA: return("MODE_SMMA");
      case MODE_ALMA: return("MODE_ALMA");
   }
   return(_EMPTY_STR(catch("MaMethodToStr(1)  invalid parameter type: "+ type, ERR_INVALID_PARAMETER)));
}


/**
 * Return a description of a Moving-Average method type constant.
 *
 * @param  int  type              - MA method type
 * @param  bool strict [optional] - whether to trigger an error if the passed value is invalid (default: yes)
 *
 * @return string - description or an empty string in case of errors
 */
string MaMethodDescription(int type, bool strict = true) {
   strict = strict!=0;

   switch (type) {
      case MODE_SMA : return("SMA" );
      case MODE_LWMA: return("LWMA");
      case MODE_EMA : return("EMA" );
      case MODE_SMMA: return("SMMA");
      case MODE_ALMA: return("ALMA");
   }
   if (strict)
      return(_EMPTY_STR(catch("MaMethodDescription(1)  invalid parameter type: "+ type, ERR_INVALID_PARAMETER)));
   return("");
}


/**
 * Return a readable version of a price type constant.
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
      case PRICE_AVERAGE:  return("PRICE_AVERAGE" );     // (O+H+L+C)/4
      case PRICE_BID     : return("PRICE_BID"     );
      case PRICE_ASK     : return("PRICE_ASK"     );
   }
   return(_EMPTY_STR(catch("PriceTypeToStr(1)  invalid parameter type: "+ type, ERR_INVALID_PARAMETER)));
}


/**
 * Return a description of a price type constant.
 *
 * @param  int type - price type
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
      case PRICE_AVERAGE:  return("Average" );     // (O+H+L+C)/4
      case PRICE_BID     : return("Bid"     );
      case PRICE_ASK     : return("Ask"     );
   }
   return(_EMPTY_STR(catch("PriceTypeDescription(1)  invalid parameter type: "+ type, ERR_INVALID_PARAMETER)));
}


/**
 * Return the integer constant of a timeframe identifier. Supports custom timeframes.
 *
 * @param  string value            - M1, M5, M15, M30 etc.
 * @param  int    flags [optional] - execution control flags (default: none)
 *                                   F_CUSTOM_TIMEFRAME:      enable support of custom timeframes
 *                                   F_ERR_INVALID_PARAMETER: silently handle ERR_INVALID_PARAMETER
 *
 * @return int - timeframe constant or EMPTY (-1) if the value is not recognized
 */
int StrToPeriod(string value, int flags = NULL) {
   string str = StrToUpper(StrTrim(value));

   if (StrStartsWith(str, "PERIOD_"))
      str = StrSubstr(str, 7);

   if (str ==           "M1" ) return(PERIOD_M1 );
   if (str == ""+ PERIOD_M1  ) return(PERIOD_M1 );
   if (str ==           "M5" ) return(PERIOD_M5 );
   if (str == ""+ PERIOD_M5  ) return(PERIOD_M5 );
   if (str ==           "M15") return(PERIOD_M15);
   if (str == ""+ PERIOD_M15 ) return(PERIOD_M15);
   if (str ==           "M30") return(PERIOD_M30);
   if (str == ""+ PERIOD_M30 ) return(PERIOD_M30);
   if (str ==           "H1" ) return(PERIOD_H1 );
   if (str == ""+ PERIOD_H1  ) return(PERIOD_H1 );
   if (str ==           "H4" ) return(PERIOD_H4 );
   if (str == ""+ PERIOD_H4  ) return(PERIOD_H4 );
   if (str ==           "D1" ) return(PERIOD_D1 );
   if (str == ""+ PERIOD_D1  ) return(PERIOD_D1 );
   if (str ==           "W1" ) return(PERIOD_W1 );
   if (str == ""+ PERIOD_W1  ) return(PERIOD_W1 );
   if (str ==           "MN1") return(PERIOD_MN1);
   if (str == ""+ PERIOD_MN1 ) return(PERIOD_MN1);

   if (flags & F_CUSTOM_TIMEFRAME && 1) {
      if (str ==           "H2" ) return(PERIOD_H2 );
      if (str == ""+ PERIOD_H2  ) return(PERIOD_H2 );
      if (str ==           "H3" ) return(PERIOD_H3 );
      if (str == ""+ PERIOD_H3  ) return(PERIOD_H3 );
      if (str ==           "H6" ) return(PERIOD_H6 );
      if (str == ""+ PERIOD_H6  ) return(PERIOD_H6 );
      if (str ==           "H8" ) return(PERIOD_H8 );
      if (str == ""+ PERIOD_H8  ) return(PERIOD_H8 );
      if (str ==           "Q1" ) return(PERIOD_Q1 );
      if (str == ""+ PERIOD_Q1  ) return(PERIOD_Q1 );
   }

   if (flags & F_ERR_INVALID_PARAMETER && 1)
      return(_EMPTY(SetLastError(ERR_INVALID_PARAMETER)));
   return(_EMPTY(catch("StrToPeriod(1)  invalid parameter value: "+ DoubleQuoteStr(value), ERR_INVALID_PARAMETER)));
}


/**
 * Alias of StrToPeriod()
 */
int StrToTimeframe(string timeframe, int flags = NULL) {
   return(StrToPeriod(timeframe, flags));
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
   return(_EMPTY_STR(catch("SwapCalculationModeToStr()  invalid parameter mode: "+ mode, ERR_INVALID_PARAMETER)));
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
   string filesDir = GetMqlSandboxPath() +"/";

   // Validierung
   // Sender
   string _sender = StrTrim(sender);
   if (!StringLen(_sender)) {
      string section = "Mail";
      string key     = "Sender";
      _sender = GetConfigString(section, key);
      if (!StringLen(_sender))             return(!catch("SendEmail(1)  missing global/terminal configuration ["+ section +"]->"+ key,                                 ERR_INVALID_CONFIG_VALUE));
      if (!StrIsEmailAddress(_sender))     return(!catch("SendEmail(2)  invalid global/terminal configuration ["+ section +"]->"+ key +" = "+ DoubleQuoteStr(_sender), ERR_INVALID_CONFIG_VALUE));
   }
   else if (!StrIsEmailAddress(_sender))   return(!catch("SendEmail(3)  invalid parameter sender: "+ DoubleQuoteStr(sender), ERR_INVALID_PARAMETER));
   sender = _sender;

   // Receiver
   string _receiver = StrTrim(receiver);
   if (!StringLen(_receiver)) {
      section   = "Mail";
      key       = "Receiver";
      _receiver = GetConfigString(section, key);
      if (!StringLen(_receiver))           return(!catch("SendEmail(4)  missing global/terminal configuration ["+ section +"]->"+ key,                                   ERR_INVALID_CONFIG_VALUE));
      if (!StrIsEmailAddress(_receiver))   return(!catch("SendEmail(5)  invalid global/terminal configuration ["+ section +"]->"+ key +" = "+ DoubleQuoteStr(_receiver), ERR_INVALID_CONFIG_VALUE));
   }
   else if (!StrIsEmailAddress(_receiver)) return(!catch("SendEmail(6)  invalid parameter receiver: "+ DoubleQuoteStr(receiver), ERR_INVALID_PARAMETER));
   receiver = _receiver;

   // Subject
   string _subject = StrTrim(subject);
   if (!StringLen(_subject))               return(!catch("SendEmail(7)  invalid parameter subject: "+ DoubleQuoteStr(subject), ERR_INVALID_PARAMETER));
   _subject = StrReplace(StrReplace(StrReplace(_subject, "\r\n", "\n"), "\r", " "), "\n", " ");          // Linebreaks mit Leerzeichen ersetzen
   _subject = StrReplace(_subject, "\"", "\\\"");                                                        // Double-Quotes in email-Parametern escapen
   _subject = StrReplace(_subject, "'", "'\"'\"'");                                                      // Single-Quotes im bash-Parameter escapen
   // bash -lc 'email -subject "single-quote:'"'"' double-quote:\" pipe:|" ...'

   // Message (kann leer sein): in temporärer Datei speichern, wenn nicht leer
   message = StrTrim(message);
   string message.txt = CreateTempFile(filesDir, "msg");
   if (StringLen(message) > 0) {
      int hFile = FileOpen(StrRightFrom(message.txt, filesDir), FILE_BIN|FILE_WRITE);                    // FileOpen() benötigt einen MQL-Pfad
      if (hFile < 0)  return(!catch("SendEmail(8)->FileOpen()"));
      int bytes = FileWriteString(hFile, message, StringLen(message));
      FileClose(hFile);
      if (bytes <= 0) return(!catch("SendEmail(9)->FileWriteString() => "+ bytes +" written"));
   }

   // benötigte Executables ermitteln: Bash und Mailclient
   string bash = GetConfigString("System", "Bash");
   if (!IsFile(bash, MODE_SYSTEM)) return(!catch("SendEmail(10)  bash executable not found: "+ DoubleQuoteStr(bash), ERR_FILE_NOT_FOUND));
   // TODO: absoluter Pfad => direkt testen
   // TODO: relativer Pfad => Systemverzeichnisse und $PATH durchsuchen

   string sendmail = GetConfigString("Mail", "Sendmail");
   if (!StringLen(sendmail)) {
      // TODO: - kein Mailclient angegeben: Umgebungsvariable $SENDMAIL auswerten
      //       - sendmail suchen
      return(!catch("SendEmail(11)  missing global/terminal configuration [Mail]->Sendmail", ERR_INVALID_CONFIG_VALUE));
   }

   // Notes:
   // ------
   //  - Redirection in der Befehlszeile ist ein Shell-Feature und erfordert eine Shell als ausführendes Programm (direkter
   //    Client-Aufruf mit Umleitung ist nicht möglich).
   //  - Redirection mit cmd.exe funktioniert nicht, wenn umgeleiteter Output oder übergebene Parameter Sonderzeichen
   //    enthalten: cmd /c echo hello \n world | {program} => Fehler
   //  - Bei Verwendung der Shell als ausführendem Programm steht jedoch der Exit-Code nicht zur Verfügung (muß vorerst in
   //    Kauf genommen werden).
   //  - Alternative ist die Verwendung von CreateProcess() und direktes Schreiben/Lesen von STDIN/STDOUT. In diesem Fall muß
   //    der Versand jedoch in einem eigenen Thread erfolgen, wenn er nicht blockieren soll.
   //
   // Cleancode email
   // ---------------
   //  - https://github.com/deanproxy/eMail
   //  - gibt keinen Exit-Code zurück
   //  - validiert die übergebenen Adressen nicht
   //

   // Befehlszeile für Shell-Aufruf zusammensetzen
   message.txt     = StrReplace(message.txt, "\\", "/");
   string mail.log = StrReplace(filesDir +"mail.log", "\\", "/");
   string cmdLine  = sendmail +" -subject \""+ _subject +"\" -from-addr \""+ sender +"\" \""+ receiver +"\" < \""+ message.txt +"\" >> \""+ mail.log +"\" 2>&1; rm -f \""+ message.txt +"\"";
          cmdLine  = bash +" -lc '"+ cmdLine +"'";

   // (5) Shell-Aufruf
   int result = WinExec(cmdLine, SW_HIDE);   // SW_SHOW | SW_HIDE
   if (result < 32) return(!catch("SendEmail(13)->kernel32::WinExec(cmdLine=\""+ cmdLine +"\")  "+ ShellExecuteErrorDescription(result), ERR_WIN32_ERROR+result));

   if (IsLogDebug()) logDebug("SendEmail(14)  Mail to "+ receiver +" transmitted: \""+ subject +"\"");
   return(!catch("SendEmail(15)"));
}


/**
 * Send a text message to the specified phone number.
 *
 * @param  string receiver - phone number (international format: +49-123-456789)
 * @param  string message  - text
 *
 * @return bool - success status
 */
bool SendSMS(string receiver, string message) {
   string _receiver = StrReplace(StrReplace(StrTrim(receiver), "-", ""), " ", "", true);

   if      (StrStartsWith(_receiver, "+" )) _receiver = StrSubstr(_receiver, 1);
   else if (StrStartsWith(_receiver, "00")) _receiver = StrSubstr(_receiver, 2);
   if (!StrIsDigit(_receiver)) return(!catch("SendSMS(1)  invalid parameter receiver: "+ DoubleQuoteStr(receiver), ERR_INVALID_PARAMETER));

   // get SMS gateway details
   // service
   string section  = "SMS";
   string key      = "Provider";
   string provider = GetConfigString(section, key);
   if (!StringLen(provider)) return(!catch("SendSMS(2)  missing configuration ["+ section +"]->"+ key, ERR_INVALID_CONFIG_VALUE));
   // user
   section = "SMS."+ provider;
   key     = "username";
   string username = GetConfigString(section, key);
   if (!StringLen(username)) return(!catch("SendSMS(3)  missing configuration ["+ section +"]->"+ key, ERR_INVALID_CONFIG_VALUE));
   // password
   key = "password";
   string password = GetConfigString(section, key);
   if (!StringLen(password)) return(!catch("SendSMS(4)  missing configuration ["+ section +"]->"+ key, ERR_INVALID_CONFIG_VALUE));
   // API id
   key = "api_id";
   int api_id = GetConfigInt(section, key);
   if (api_id <= 0) {
      string value = GetConfigString(section, key);
      if (!StringLen(value)) return(!catch("SendSMS(5)  missing configuration ["+ section +"]->"+ key,                      ERR_INVALID_CONFIG_VALUE));
                             return(!catch("SendSMS(6)  invalid config value ["+ section +"]->"+ key +" = \""+ value +"\"", ERR_INVALID_CONFIG_VALUE));
   }

   // compose shell command line
   string url          = "https://api.clickatell.com/http/sendmsg?user="+ username +"&password="+ password +"&api_id="+ api_id +"&to="+ _receiver +"&text="+ UrlEncode(message);
   string filesDir     = GetMqlSandboxPath();
   string responseFile = filesDir +"/sms_"+ GmtTimeFormat(TimeLocalEx(), "%Y-%m-%d %H.%M.%S") +"_"+ GetCurrentThreadId() +".response";
   string logFile      = filesDir +"/sms.log";
   string cmd          = GetMqlDirectoryA() +"/libraries/wget.exe";
   string arguments    = "-b --no-check-certificate \""+ url +"\" -O \""+ responseFile +"\" -a \""+ logFile +"\"";
   string cmdLine      = cmd +" "+ arguments;

   // execute shell command
   int result = WinExec(cmdLine, SW_HIDE);
   if (result < 32) return(!catch("SendSMS(7)->kernel32::WinExec(cmdLine="+ DoubleQuoteStr(cmdLine) +")  "+ ShellExecuteErrorDescription(result), ERR_WIN32_ERROR+result));

   // TODO: analyse the response
   // --------------------------
   // --2011-03-23 08:32:06--  https://api.clickatell.com/http/sendmsg?user={user}&password={pass}&api_id={id}&to={receiver}&text={text}
   // Resolving api.clickatell.com... failed: Unknown host.
   // wget: unable to resolve host address `api.clickatell.com'
   //
   // --2014-06-15 22:44:21--  (try:20)  https://api.clickatell.com/http/sendmsg?user={user}&password={pass}&api_id={id}&to={receiver}&text={text}
   // Connecting to api.clickatell.com|196.216.236.7|:443... failed: Permission denied.
   // Giving up.

   if (IsLogDebug()) logDebug("SendSMS(8)  SMS sent to "+ receiver +": \""+ message +"\"");
   return(!catch("SendSMS(9)"));
}


/**
 * Whether the current program is an indicator loaded by iCustom().
 *
 * @return bool
 */
bool IsSuperContext() {
   return(__lpSuperContext != 0);
}


/**
 * Round a lot value according to the specified symbol's lot step value (MODE_LOTSTEP).
 *
 * @param  double lots              - lot size
 * @param  string symbol [optional] - symbol (default: the current symbol)
 * @param  int    mode   [optional] - rounding mode: MODE_FLOOR   - normalize down to the next smallest absolute value
 *                                                   MODE_DEFAULT - normalize according to standard rounding rules
 *                                                   MODE_CEIL    - normalize up to the next largest absolute value
 *
 * @return double - rounded lot value or EMPTY_VALUE (INT_MAX) in case of errors
 */
double NormalizeLots(double lots, string symbol="", int mode=MODE_DEFAULT) {
   if (!StringLen(symbol)) symbol = Symbol();
   else if (symbol == "0") symbol = Symbol();            // (string) NULL

   double lotstep = MarketInfo(symbol, MODE_LOTSTEP);
   if (!lotstep) {
      int error = GetLastError();
      return(_EMPTY_VALUE(catch("NormalizeLots(1)  MarketInfo("+ symbol +", MODE_LOTSTEP) not available: 0", intOr(error, ERR_INVALID_MARKET_DATA))));
   }

   switch (mode) {
      case MODE_FLOOR:   return(NormalizeDouble(MathFloor(lots/lotstep) * lotstep, 2));
      case MODE_DEFAULT: return(NormalizeDouble(MathRound(lots/lotstep) * lotstep, 2));
      case MODE_CEIL:    return(NormalizeDouble(MathCeil (lots/lotstep) * lotstep, 2));
   }
   return(_EMPTY_VALUE(catch("NormalizeLots(2)  invalid parameter mode: "+ mode, ERR_INVALID_PARAMETER)));
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
double icALMA(int timeframe, int maPeriods, string maAppliedPrice, double distributionOffset, double distributionSigma, int iBuffer, int iBar) {
   static int lpSuperContext = 0; if (!lpSuperContext)
      lpSuperContext = GetIntsAddress(__ExecutionContext);

   double value = iCustom(NULL, timeframe, "ALMA",
                          maPeriods,                        // int    MA.Periods
                          maAppliedPrice,                   // string MA.AppliedPrice
                          distributionOffset,               // double Distribution.Offset
                          distributionSigma,                // double Distribution.Sigma

                          Blue,                             // color  Color.UpTrend
                          Red,                              // color  Color.DownTrend
                          "Line",                           // string Draw.Type
                          1,                                // int    Draw.Width
                          -1,                               // int    Max.Bars
                          "",                               // string ____________________
                          "off",                            // string Signal.onTrendChange
                          "off",                            // string Signal.Sound
                          "off",                            // string Signal.Mail
                          "off",                            // string Signal.SMS
                          "",                               // string ____________________
                          false,                            // bool   AutoConfiguration
                          lpSuperContext,                   // int    __lpSuperContext

                          iBuffer, iBar);

   int error = GetLastError();
   if (error != NO_ERROR) {
      if (error != ERS_HISTORY_UPDATE)
         return(!catch("icALMA(1)", error));
      logWarn("icALMA(2)  "+ PeriodDescription(ifInt(!timeframe, Period(), timeframe)) +" (tick="+ Ticks +")", ERS_HISTORY_UPDATE);
   }

   error = __ExecutionContext[EC.mqlError];                 // TODO: synchronize execution contexts
   if (!error)
      return(value);
   return(!SetLastError(error));
}


/**
 * Load and execute the "ChartInfos" indicator.
 *
 * @return bool - success status
 */
bool icChartInfos() {
   static int lpSuperContext = 0; if (!lpSuperContext)
      lpSuperContext = GetIntsAddress(__ExecutionContext);

   iCustom(NULL, NULL, "ChartInfos",
           "off",                                           // string Track.Orders
           false,                                           // bool   Offline.Ticker
           "",                                              // string ____________________
           "off",                                           // string Signal.Sound
           "off",                                           // string Signal.Mail
           "off",                                           // string Signal.SMS
           "",                                              // string ____________________
           false,                                           // bool   AutoConfiguration
           lpSuperContext,                                  // int    __lpSuperContext

           0, 0);

   int error = GetLastError();
   if (error != NO_ERROR) {
      if (error != ERS_HISTORY_UPDATE)
         return(!catch("icChartInfos(1)", error));
      logWarn("icChartInfos(2)  "+ PeriodDescription() +" (tick="+ Ticks +")", ERS_HISTORY_UPDATE);
   }

   error = __ExecutionContext[EC.mqlError];                 // TODO: synchronize execution contexts
   if (!error)
      return(true);
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
double icFATL(int timeframe, int iBuffer, int iBar) {
   static int lpSuperContext = 0; if (!lpSuperContext)
      lpSuperContext = GetIntsAddress(__ExecutionContext);

   double value = iCustom(NULL, timeframe, "FATL",
                          Blue,                             // color  Color.UpTrend
                          Red,                              // color  Color.DownTrend
                          "Line",                           // string Draw.Type
                          1,                                // int    Draw.Width
                          -1,                               // int    Max.Bars
                          "",                               // string ____________________
                          "off",                            // string Signal.onTrendChange
                          "off",                            // string Signal.Sound
                          "off",                            // string Signal.Mail
                          "off",                            // string Signal.SMS
                          "",                               // string ____________________
                          false,                            // bool   AutoConfiguration
                          lpSuperContext,                   // int    __lpSuperContext

                          iBuffer, iBar);

   int error = GetLastError();
   if (error != NO_ERROR) {
      if (error != ERS_HISTORY_UPDATE)
         return(!catch("icFATL(1)", error));
      logWarn("icFATL(2)  "+ PeriodDescription(ifInt(!timeframe, Period(), timeframe)) +" (tick="+ Ticks +")", ERS_HISTORY_UPDATE);
   }

   error = __ExecutionContext[EC.mqlError];                 // TODO: synchronize execution contexts
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
double icHalfTrend(int timeframe, int periods, int iBuffer, int iBar) {
   static int lpSuperContext = 0; if (!lpSuperContext)
      lpSuperContext = GetIntsAddress(__ExecutionContext);

   double value = iCustom(NULL, timeframe, "HalfTrend",
                          periods,                          // int    Periods

                          Blue,                             // color  Color.UpTrend
                          Red,                              // color  Color.DownTrend
                          CLR_NONE,                         // color  Color.Channel
                          "Line",                           // string Draw.Type
                          1,                                // int    Draw.Width
                          -1,                               // int    Max.Bars
                          "",                               // string ____________________
                          "off",                            // string Signal.onTrendChange
                          "off",                            // string Signal.Sound
                          "off",                            // string Signal.Mail
                          "off",                            // string Signal.SMS
                          "",                               // string ____________________
                          false,                            // bool   AutoConfiguration
                          lpSuperContext,                   // int    __lpSuperContext

                          iBuffer, iBar);

   int error = GetLastError();
   if (error != NO_ERROR) {
      if (error != ERS_HISTORY_UPDATE)
         return(!catch("icHalfTrend(1)", error));
      logWarn("icHalfTrend(2)  "+ PeriodDescription(ifInt(!timeframe, Period(), timeframe)) +" (tick="+ Ticks +")", ERS_HISTORY_UPDATE);
   }

   error = __ExecutionContext[EC.mqlError];                 // TODO: synchronize execution contexts
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
double icJMA(int timeframe, int periods, int phase, string appliedPrice, int iBuffer, int iBar) {
   static int lpSuperContext = 0; if (!lpSuperContext)
      lpSuperContext = GetIntsAddress(__ExecutionContext);

   double value = iCustom(NULL, timeframe, "Jurik Moving Average",
                          periods,                          // int    Periods
                          phase,                            // int    Phase
                          appliedPrice,                     // string AppliedPrice

                          Blue,                             // color  Color.UpTrend
                          Red,                              // color  Color.DownTrend
                          "Line",                           // string Draw.Type
                          1,                                // int    Draw.Width
                          -1,                               // int    Max.Bars
                          "",                               // string ____________________
                          "off",                            // string Signal.onTrendChange
                          "off",                            // string Signal.Sound
                          "off",                            // string Signal.Mail
                          "off",                            // string Signal.SMS
                          "",                               // string ____________________
                          false,                            // bool   AutoConfiguration
                          lpSuperContext,                   // int    __lpSuperContext

                          iBuffer, iBar);

   int error = GetLastError();
   if (error != NO_ERROR) {
      if (error != ERS_HISTORY_UPDATE)
         return(!catch("icJMA(1)", error));
      logWarn("icJMA(2)  "+ PeriodDescription(ifInt(!timeframe, Period(), timeframe)) +" (tick="+ Ticks +")", ERS_HISTORY_UPDATE);
   }

   error = __ExecutionContext[EC.mqlError];                 // TODO: synchronize execution contexts
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
double icMACD(int timeframe, int fastMaPeriods, string fastMaMethod, string fastMaAppliedPrice, int slowMaPeriods, string slowMaMethod, string slowMaAppliedPrice, int iBuffer, int iBar) {
   static int lpSuperContext = 0; if (!lpSuperContext)
      lpSuperContext = GetIntsAddress(__ExecutionContext);

   double value = iCustom(NULL, timeframe, "MACD",
                          fastMaPeriods,                    // int    Fast.MA.Periods
                          fastMaMethod,                     // string Fast.MA.Method
                          fastMaAppliedPrice,               // string Fast.MA.AppliedPrice

                          slowMaPeriods,                    // int    Slow.MA.Periods
                          slowMaMethod,                     // string Slow.MA.Method
                          slowMaAppliedPrice,               // string Slow.MA.AppliedPrice

                          Blue,                             // color  MainLine.Color
                          1,                                // int    MainLine.Width
                          Green,                            // color  Histogram.Color.Upper
                          Red,                              // color  Histogram.Color.Lower
                          2,                                // int    Histogram.Style.Width
                          -1,                               // int    Max.Bars
                          "",                               // string _____________________
                          "off",                            // string Signal.onZeroCross
                          "off",                            // string Signal.Sound
                          "off",                            // string Signal.Mail
                          "off",                            // string Signal.SMS
                          "",                               // string _____________________
                          false,                            // bool   AutoConfiguration
                          lpSuperContext,                   // int    __lpSuperContext

                          iBuffer, iBar);

   int error = GetLastError();
   if (error != NO_ERROR) {
      if (error != ERS_HISTORY_UPDATE)
         return(!catch("icMACD(1)", error));
      logWarn("icMACD(2)  "+ PeriodDescription(ifInt(!timeframe, Period(), timeframe)) +" (tick="+ Ticks +")", ERS_HISTORY_UPDATE);
   }

   error = __ExecutionContext[EC.mqlError];                 // TODO: synchronize execution contexts
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
double icMovingAverage(int timeframe, int maPeriods, string maMethod, string maAppliedPrice, int iBuffer, int iBar) {
   static int lpSuperContext = 0; if (!lpSuperContext)
      lpSuperContext = GetIntsAddress(__ExecutionContext);

   double value = iCustom(NULL, timeframe, "Moving Average",
                          maPeriods,                        // int    MA.Periods
                          maMethod,                         // string MA.Method
                          maAppliedPrice,                   // string MA.AppliedPrice

                          Blue,                             // color  Color.UpTrend
                          Blue,                             // color  Color.DownTrend
                          "Line",                           // string Draw.Type
                          0,                                // int    Draw.Width
                          -1,                               // int    Max.Bars
                          "",                               // string ____________________
                          "off",                            // string Signal.onTrendChange
                          "off",                            // string Signal.Sound
                          "off",                            // string Signal.Mail
                          "off",                            // string Signal.SMS
                          "",                               // string ____________________
                          false,                            // bool   AutoConfiguration
                          lpSuperContext,                   // int    __lpSuperContext

                          iBuffer, iBar);

   int error = GetLastError();
   if (error != NO_ERROR) {
      if (error != ERS_HISTORY_UPDATE)
         return(!catch("icMovingAverage(1)", error));
      logWarn("icMovingAverage(2)  "+ PeriodDescription(ifInt(!timeframe, Period(), timeframe)) +" (tick="+ Ticks +")", ERS_HISTORY_UPDATE);
   }

   error = __ExecutionContext[EC.mqlError];                 // TODO: synchronize execution contexts
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
double icNonLagMA(int timeframe, int cycleLength, string appliedPrice, int iBuffer, int iBar) {
   static int lpSuperContext = 0; if (!lpSuperContext)
      lpSuperContext = GetIntsAddress(__ExecutionContext);

   double value = iCustom(NULL, timeframe, "NonLagMA",
                          cycleLength,                      // int    Cycle.Length
                          appliedPrice,                     // string AppliedPrice

                          Blue,                             // color  Color.UpTrend
                          Red,                              // color  Color.DownTrend
                          "Dot",                            // string Draw.Type
                          1,                                // int    Draw.Width
                          -1,                               // int    Max.Bars
                          "",                               // string ____________________
                          "off",                            // string Signal.onTrendChange
                          "off",                            // string Signal.Sound
                          "off",                            // string Signal.Mail
                          "off",                            // string Signal.SMS
                          "",                               // string ____________________
                          false,                            // bool   AutoConfiguration
                          lpSuperContext,                   // int    __lpSuperContext

                          iBuffer, iBar);

   int error = GetLastError();
   if (error != NO_ERROR) {
      if (error != ERS_HISTORY_UPDATE)
         return(!catch("icNonLagMA(1)", error));
      logWarn("icNonLagMA(2)  "+ PeriodDescription(ifInt(!timeframe, Period(), timeframe)) +" (tick="+ Ticks +")", ERS_HISTORY_UPDATE);
   }

   error = __ExecutionContext[EC.mqlError];                 // TODO: synchronize execution contexts
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
double icRSI(int timeframe, int periods, string appliedPrice, int iBuffer, int iBar) {
   static int lpSuperContext = 0; if (!lpSuperContext)
      lpSuperContext = GetIntsAddress(__ExecutionContext);

   double value = iCustom(NULL, timeframe, ".attic/RSI",
                          periods,                          // int    RSI.Periods
                          appliedPrice,                     // string RSI.AppliedPrice

                          Blue,                             // color  MainLine.Color
                          1,                                // int    MainLine.Width
                          Blue,                             // color  Histogram.Color.Upper
                          Red,                              // color  Histogram.Color.Lower
                          0,                                // int    Histogram.Style.Width
                          -1,                               // int    Max.Bars
                          "",                               // string _____________________
                          false,                            // bool   AutoConfiguration
                          lpSuperContext,                   // int    __lpSuperContext

                          iBuffer, iBar);

   int error = GetLastError();
   if (error != NO_ERROR) {
      if (error != ERS_HISTORY_UPDATE)
         return(!catch("icRSI(1)", error));
      logWarn("icRSI(2)  "+ PeriodDescription(ifInt(!timeframe, Period(), timeframe)) +" (tick="+ Ticks +")", ERS_HISTORY_UPDATE);
   }

   error = __ExecutionContext[EC.mqlError];                 // TODO: synchronize execution contexts
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
double icSATL(int timeframe, int iBuffer, int iBar) {
   static int lpSuperContext = 0; if (!lpSuperContext)
      lpSuperContext = GetIntsAddress(__ExecutionContext);

   double value = iCustom(NULL, timeframe, "SATL",
                          Blue,                             // color  Color.UpTrend
                          Red,                              // color  Color.DownTrend
                          "Line",                           // string Draw.Type
                          1,                                // int    Draw.Width
                          -1,                               // int    Max.Bars
                          "",                               // string ____________________
                          "off",                            // string Signal.onTrendChange
                          "off",                            // string Signal.Sound
                          "off",                            // string Signal.Mail
                          "off",                            // string Signal.SMS
                          "",                               // string ____________________
                          false,                            // bool   AutoConfiguration
                          lpSuperContext,                   // int    __lpSuperContext

                          iBuffer, iBar);

   int error = GetLastError();
   if (error != NO_ERROR) {
      if (error != ERS_HISTORY_UPDATE)
         return(!catch("icSATL(1)", error));
      logWarn("icSATL(2)  "+ PeriodDescription(ifInt(!timeframe, Period(), timeframe)) +" (tick="+ Ticks +")", ERS_HISTORY_UPDATE);
   }

   error = __ExecutionContext[EC.mqlError];                 // TODO: synchronize execution contexts
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
double icSuperSmoother(int timeframe, int periods, string appliedPrice, int iBuffer, int iBar) {
   static int lpSuperContext = 0; if (!lpSuperContext)
      lpSuperContext = GetIntsAddress(__ExecutionContext);

   double value = iCustom(NULL, timeframe, "Ehlers 2-Pole-SuperSmoother",
                          periods,                          // int    Periods
                          appliedPrice,                     // string AppliedPrice

                          Blue,                             // color  Color.UpTrend
                          Red,                              // color  Color.DownTrend
                          "Line",                           // string Draw.Type
                          1,                                // int    Draw.Width
                          -1,                               // int    Max.Bars
                          "",                               // string ____________________
                          "off",                            // string Signal.onTrendChange
                          "off",                            // string Signal.Sound
                          "off",                            // string Signal.Mail
                          "off",                            // string Signal.SMS
                          "",                               // string ____________________
                          false,                            // bool   AutoConfiguration
                          lpSuperContext,                   // int    __lpSuperContext

                          iBuffer, iBar);

   int error = GetLastError();
   if (error != NO_ERROR) {
      if (error != ERS_HISTORY_UPDATE)
         return(!catch("icSuperSmoother(1)", error));
      logWarn("icSuperSmoother(2)  "+ PeriodDescription(ifInt(!timeframe, Period(), timeframe)) +" (tick="+ Ticks +")", ERS_HISTORY_UPDATE);
   }

   error = __ExecutionContext[EC.mqlError];                 // TODO: synchronize execution contexts
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
double icSuperTrend(int timeframe, int atrPeriods, int smaPeriods, int iBuffer, int iBar) {
   static int lpSuperContext = 0; if (!lpSuperContext)
      lpSuperContext = GetIntsAddress(__ExecutionContext);

   double value = iCustom(NULL, timeframe, "SuperTrend",
                          atrPeriods,                       // int    ATR.Periods
                          smaPeriods,                       // int    SMA.Periods

                          Blue,                             // color  Color.UpTrend
                          Red,                              // color  Color.DownTrend
                          CLR_NONE,                         // color  Color.Channel
                          CLR_NONE,                         // color  Color.MovingAverage
                          "Line",                           // string Draw.Type
                          1,                                // int    Draw.Width
                          -1,                               // int    Max.Bars
                          "",                               // string ____________________
                          "off",                            // string Signal.onTrendChange
                          "off",                            // string Signal.Sound
                          "off",                            // string Signal.Mail
                          "off",                            // string Signal.SMS
                          "",                               // string ____________________
                          false,                            // bool   AutoConfiguration
                          lpSuperContext,                   // int    __lpSuperContext

                          iBuffer, iBar);

   int error = GetLastError();
   if (error != NO_ERROR) {
      if (error != ERS_HISTORY_UPDATE)
         return(!catch("icSuperTrend(1)", error));
      logWarn("icSuperTrend(2)  "+ PeriodDescription(ifInt(!timeframe, Period(), timeframe)) +" (tick="+ Ticks +")", ERS_HISTORY_UPDATE);
   }

   error = __ExecutionContext[EC.mqlError];                 // TODO: synchronize execution contexts
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
double icTriEMA(int timeframe, int periods, string appliedPrice, int iBuffer, int iBar) {
   static int lpSuperContext = 0; if (!lpSuperContext)
      lpSuperContext = GetIntsAddress(__ExecutionContext);

   double value = iCustom(NULL, timeframe, "TriEMA",
                          periods,                          // int    MA.Periods
                          appliedPrice,                     // string MA.AppliedPrice

                          Blue,                             // color  Color.UpTrend
                          Red,                              // color  Color.DownTrend
                          "Line",                           // string Draw.Type
                          1,                                // int    Draw.Width
                          -1,                               // int    Max.Bars
                          "",                               // string ____________________
                          "off",                            // string Signal.onTrendChange
                          "off",                            // string Signal.Sound
                          "off",                            // string Signal.Mail
                          "off",                            // string Signal.SMS
                          "",                               // string ____________________
                          false,                            // bool   AutoConfiguration
                          lpSuperContext,                   // int    __lpSuperContext

                          iBuffer, iBar);

   int error = GetLastError();
   if (error != NO_ERROR) {
      if (error != ERS_HISTORY_UPDATE)
         return(!catch("icTriEMA(1)", error));
      logWarn("icTriEMA(2)  "+ PeriodDescription(ifInt(!timeframe, Period(), timeframe)) +" (tick="+ Ticks +")", ERS_HISTORY_UPDATE);
   }

   error = __ExecutionContext[EC.mqlError];                 // TODO: synchronize execution contexts
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
double icTrix(int timeframe, int periods, string appliedPrice, int iBuffer, int iBar) {
   static int lpSuperContext = 0; if (!lpSuperContext)
      lpSuperContext = GetIntsAddress(__ExecutionContext);

   double value = iCustom(NULL, timeframe, "Trix",
                          periods,                          // int    EMA.Periods
                          appliedPrice,                     // string EMA.AppliedPrice

                          Blue,                             // color  MainLine.Color
                          1,                                // int    MainLine.Width
                          Green,                            // color  Histogram.Color.Upper
                          Red,                              // color  Histogram.Color.Lower
                          2,                                // int    Histogram.Style.Width
                          -1,                               // int    Max.Bars
                          "",                               // string _____________________
                          false,                            // bool   AutoConfiguration
                          lpSuperContext,                   // int    __lpSuperContext

                          iBuffer, iBar);

   int error = GetLastError();
   if (error != NO_ERROR) {
      if (error != ERS_HISTORY_UPDATE)
         return(!catch("icTrix(1)", error));
      logWarn("icTrix(2)  "+ PeriodDescription(ifInt(!timeframe, Period(), timeframe)) +" (tick="+ Ticks +")", ERS_HISTORY_UPDATE);
   }

   error = __ExecutionContext[EC.mqlError];                 // TODO: synchronize execution contexts
   if (!error)
      return(value);
   return(!SetLastError(error));
}


/**
 * Load the custom "ZigZag" indicator and return a value.
 *
 * @param  int  timeframe               - timeframe to load the indicator (NULL: the current timeframe)
 * @param  int  periods                 - indicator parameter
 * @param  bool calcAllChannelCrossings - indicator parameter
 * @param  bool markFirstCrossing       - indicator parameter
 * @param  int  iBuffer                 - indicator buffer index of the value to return
 * @param  int  iBar                    - bar index of the value to return
 *
 * @return double - indicator value or NULL in case of errors
 */
double icZigZag(int timeframe, int periods, bool calcAllChannelCrossings, bool markFirstCrossing, int iBuffer, int iBar) {
   static int lpSuperContext = 0; if (!lpSuperContext)
      lpSuperContext = GetIntsAddress(__ExecutionContext);

   double value = iCustom(NULL, timeframe, "ZigZag",
                          "",                               // string ____________________
                          periods,                          // int    ZigZag.Periods
                          "Line",                           // string ZigZag.Type
                          1,                                // int    ZigZag.Width
                          Blue,                             // color  ZigZag.Color
                          false,                            // bool   ZigZag.ShowTrail

                          "",                               // string ____________________
                          true,                             // bool   Donchian.ShowFullChannel
                          false,                            // bool   Donchian.ShowStopSegments
                          calcAllChannelCrossings,          // bool   Donchian.ShowAllCrossings
                          markFirstCrossing,                // bool   Donchian.MarkFirstCrossing
                          DodgerBlue,                       // color  Donchian.UpperBand.Color
                          DodgerBlue,                       // color  Donchian.LowerBand.Color

                          "",                               // string ____________________
                          108,                              // int    Semaphores.WingDingsSymbol
                          161,                              // int    Crossings.WingDingsSymbol
                          0,                                // int    PeriodStepper.StepSize
                          -1,                               // int    Max.Bars

                          "",                               // string ____________________
                          false,                            // bool   Signal.onReversal
                          false,                            // bool   Signal.onReversal.Sound
                          false,                            // bool   Signal.onReversal.Popup
                          false,                            // bool   Signal.onReversal.Mail
                          false,                            // bool   Signal.onReversal.SMS

                          "",                               // string ____________________
                          false,                            // bool   AutoConfiguration
                          lpSuperContext,                   // int    __lpSuperContext

                          iBuffer, iBar);

   int error = GetLastError();
   if (error != NO_ERROR) {
      if (error != ERS_HISTORY_UPDATE)
         return(!catch("icZigZag(1)", error));
      logWarn("icZigZag(2)  "+ PeriodDescription(ifInt(!timeframe, Period(), timeframe)) +" (tick="+ Ticks +")", ERS_HISTORY_UPDATE);
   }

   error = __ExecutionContext[EC.mqlError];                 // TODO: synchronize execution contexts
   if (!error)
      return(value);
   return(!SetLastError(error));
}


/**
 * Check a trade server path for safe usage. If the path was not used before a notice is emitted and the path is marked.
 *
 * @param  string path              - if a relative path:  relative to the MQL sandbox/files directory
 *                                    if an absolute path: as is
 * @param  string caller [optional] - location identifier of the caller (default: none)
 *
 * @return bool - whether it's safe to use the path
 */
bool UseTradeServerPath(string path, string caller = "") {
   int fsMode = ifInt(IsAbsolutePath(path), MODE_SYSTEM, MODE_MQL);
   string symbolsFile = path +"/symbols.raw";
   string groupsFile  = path +"/symgroups.raw";

   if (!IsFile(symbolsFile, fsMode)) /*&&*/ if (!IsFile(groupsFile, fsMode)) {
      if (caller == "0") caller = "";                       // (string) NULL
      if (caller != "")  caller = caller +"->";
      logNotice(caller +"UseTradeServerPath(1)  \""+ path +"\" doesn't seem to be a regular trade server directory (file \"symbols.raw\" not found)");

      // make sure the directory exists
      if (!CreateDirectory(path, fsMode|MODE_MKPARENT)) return(!catch(caller +"UseTradeServerPath(2)  cannot create directory \""+ path +"\"", ERR_INVALID_PARAMETER));

      // make sure "symbols.raw" exists
      if (!IsFile(symbolsFile, fsMode)) {
         if (fsMode == MODE_MQL) symbolsFile = GetMqlSandboxPath() +"/"+ symbolsFile;
         int hFile = CreateFileA(symbolsFile,               // file name
                                 GENERIC_READ,              // desired access
                                 FILE_SHARE_READ,           // share mode
                                 NULL,                      // default security
                                 CREATE_NEW,                // create file only if it doesn't exist
                                 FILE_ATTRIBUTE_NORMAL,     // flags and attributes: normal file
                                 NULL);                     // no template file handle
         if (hFile == INVALID_HANDLE_VALUE) {
            int error = GetLastWin32Error();
            if (error != ERROR_FILE_EXISTS) return(!catch(caller +"UseTradeServerPath(3)->CreateFileA(\""+ symbolsFile +"\")", ERR_WIN32_ERROR+error));
         }
         else CloseHandle(hFile);
      }
   }
   return(true);
}


/**
 * Suppress compiler warnings.
 */
void __DummyCalls() {
   bool   bNull;
   int    iNull, iNulls[];
   double dNull;
   string sNull, sNulls[];

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
   ArrayUnshiftString(sNulls, NULL);
   Ceil(NULL);
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
   CreateDirectory(NULL, NULL);
   CreateLegendLabel();
   CreateString(NULL);
   DateTime1(NULL);
   DateTime2(iNulls);
   DebugMarketInfo(NULL);
   DeinitReason();
   Div(NULL, NULL);
   doubleOr(NULL, NULL);
   DoubleToStrMorePrecision(NULL, NULL);
   DummyCalls();
   EnumChildWindows(NULL);
   EQ(NULL, NULL);
   ErrorDescription(NULL);
   EventListener.NewTick();
   FileAccessModeToStr(NULL);
   FindStandardSymbol(NULL);
   Floor(NULL);
   ForceAlert(NULL);
   FullModuleName();
   GE(NULL, NULL);
   GetAccountAlias();
   GetAccountCompanyId();
   GetAccountConfigPath(NULL, NULL);
   GetAccountNumberFromAlias(NULL, NULL);
   GetAccountServerPath();
   GetCommission();
   GetConfigBool(NULL, NULL);
   GetConfigColor(NULL, NULL);
   GetConfigDouble(NULL, NULL);
   GetConfigInt(NULL, NULL);
   GetConfigString(NULL, NULL);
   GetConfigStringRaw(NULL, NULL);
   GetCurrency(NULL);
   GetCurrencyId(NULL);
   GetExternalAssets();
   GetFxtTime();
   GetIniBool(NULL, NULL, NULL);
   GetIniColor(NULL, NULL, NULL);
   GetIniDouble(NULL, NULL, NULL);
   GetIniInt(NULL, NULL, NULL);
   GetMqlSandboxPath();
   GetRandomValue(NULL, NULL);
   GetServerTime();
   GmtTimeFormat(NULL, NULL);
   GT(NULL, NULL);
   HistoryFlagsToStr(NULL);
   icALMA(NULL, NULL, NULL, NULL, NULL, NULL, NULL);
   icChartInfos();
   icFATL(NULL, NULL, NULL);
   icHalfTrend(NULL, NULL, NULL, NULL);
   icJMA(NULL, NULL, NULL, NULL, NULL, NULL);
   icMACD(NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
   icMovingAverage(NULL, NULL, NULL, NULL, NULL, NULL);
   icNonLagMA(NULL, NULL, NULL, NULL, NULL);
   icRSI(NULL, NULL, NULL, NULL, NULL);
   icSATL(NULL, NULL, NULL);
   icSuperSmoother(NULL, NULL, NULL, NULL, NULL);
   icSuperTrend(NULL, NULL, NULL, NULL, NULL);
   icTriEMA(NULL, NULL, NULL, NULL, NULL);
   icTrix(NULL, NULL, NULL, NULL, NULL);
   icZigZag(NULL, NULL, NULL, NULL, NULL, NULL);
   ifBool(NULL, NULL, NULL);
   ifDouble(NULL, NULL, NULL);
   ifInt(NULL, NULL, NULL);
   ifString(NULL, NULL, NULL);
   InitReasonDescription(NULL);
   IntegerToHexString(NULL);
   intOr(NULL, NULL);
   IsAbsolutePath(NULL);
   IsAccountConfigKey(NULL, NULL);
   IsConfigKey(NULL, NULL);
   IsCurrency(NULL);
   IsDemoFix();
   IsDirectory(NULL, NULL);
   IsDLLError();
   IsEmpty(NULL);
   IsEmptyString(NULL);
   IsEmptyValue(NULL);
   IsError(NULL);
   IsExpert();
   IsFile(NULL, NULL);
   IsIndicator();
   IsInfinity(NULL);
   IsLastError();
   IsLeapYear(NULL);
   IsLibrary();
   IsLimitOrderType(NULL);
   IsLog();
   IsLongOrderType(NULL);
   IsMQLError();
   IsNaN(NULL);
   IsNaT(NULL);
   IsOrderType(NULL);
   IsPendingOrderType(NULL);
   IsScript();
   IsShortOrderType(NULL);
   IsStopOrderType(NULL);
   IsSuperContext();
   IsTicket(NULL);
   IsVisualModeFix();
   JoinStrings(sNulls);
   LE(NULL, NULL);
   LocalTimeFormat(NULL, NULL);
   LoglevelDescription(NULL);
   LT(NULL, NULL);
   MaMethodDescription(NULL);
   MaMethodToStr(NULL);
   MarketInfoEx(NULL, NULL, iNull);
   MarketInfoTypeToStr(NULL);
   MarketWatch.Symbols();
   MathDiv(NULL, NULL);
   MathModFix(NULL, NULL);
   Max(NULL, NULL);
   MessageBoxButtonToStr(NULL);
   Min(NULL, NULL);
   ModuleName();
   ModuleTypesToStr(NULL);
   Mul(NULL, NULL);
   NameToColor(NULL);
   NE(NULL, NULL);
   NormalizeLots(NULL);
   NumberToStr(NULL, NULL);
   OrderLogMessage(NULL);
   OrderPop(NULL);
   OrderPush(NULL);
   PeriodDescription();
   PeriodFlag();
   PeriodFlagToStr(NULL);
   PipToStr(NULL);
   PipValue();
   PipValueEx(NULL, NULL, iNull);
   PlaySoundEx(NULL);
   Pluralize(NULL);
   PriceTypeDescription(NULL);
   PriceTypeToStr(NULL);
   ProgramInitReason();
   ProgramName();
   QuoteStr(NULL);
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
   Sign(NULL);
   StdSymbol();
   StrCapitalize(NULL);
   StrCompareI(NULL, NULL);
   StrContains(NULL, NULL);
   StrContainsChars(NULL, iNulls);
   StrContainsI(NULL, NULL);
   StrEndsWithI(NULL, NULL);
   StrFindR(NULL, NULL);
   stringOr(NULL, NULL);
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
   StrRight(NULL, NULL);
   StrRightFrom(NULL, NULL);
   StrRightPad(NULL, NULL);
   StrStartsWithI(NULL, NULL);
   StrSubstr(NULL, NULL);
   StrToBool(NULL);
   StrToHexStr(NULL);
   StrToLogLevel(NULL);
   StrToLower(NULL);
   StrToMaMethod(NULL);
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
   TimeDayEx(NULL);
   TimeDayOfWeekEx(NULL);
   TimeframeDescription();
   TimeframeFlag();
   TimeframeFlagToStr(NULL);
   TimeFXT();
   TimeGMT();
   TimeLocalEx();
   TimeServer();
   TimeYearEx(NULL);
   Toolbar.Experts(NULL);
   TradeCommandToStr(NULL);
   UninitializeReasonDescription(NULL);
   UrlEncode(NULL);
   UseTradeServerPath(NULL);
   WaitForTicket(NULL);
   WriteIniString(NULL, NULL, NULL, NULL);
}


// --------------------------------------------------------------------------------------------------------------------------------------------------


#import "rsfLib.ex4"
   bool     AquireLock(string mutexName, bool wait);
   int      ArrayPopInt(int array[]);
   int      ArrayPushInt(int array[], int value);
   int      ArrayPushString(string array[], string value);
   string   CharToHexStr(int chr);
   string   CreateTempFile(string path, string prefix);
   int      DeleteRegisteredObjects();
   string   DoubleToStrEx(double value, int digits);
   int      Explode(string input, string separator, string results[], int limit);
   int      GetAccountNumber();
   string   GetHostName();
   int      GetIniKeys(string fileName, string section, string keys[]);
   string   GetAccountServer();
   string   GetServerTimezone();
   datetime GmtToFxtTime(datetime gmtTime);
   datetime GmtToServerTime(datetime gmtTime);
   int      InitializeStringBuffer(string buffer[], int length);
   bool     ReleaseLock(string mutexName);
   bool     ReverseStringArray(string array[]);
   datetime ServerToGmtTime(datetime serverTime);

#import "rsfMT4Expander.dll"
   string   ec_ProgramName(int ec[]);
   int      ec_SetMqlError(int ec[], int lastError);
   string   EXECUTION_CONTEXT_toStr(int ec[]);
   int      LeaveContext(int ec[]);

#import "kernel32.dll"
   bool     CloseHandle(int hObject);
   int      CreateFileA(string lpFileName, int dwDesiredAccess, int dwShareMode, int lpSecurityAttributes, int dwCreationDisposition, int dwFlagsAndAttributes, int hTemplateFile);
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
   int      GetDesktopWindow();
   int      GetDlgCtrlID(int hWndCtl);
   int      GetDlgItem(int hDlg, int itemId);
   int      GetParent(int hWnd);
   int      GetTopWindow(int hWnd);
   int      GetWindow(int hWnd, int cmd);
   bool     IsWindow(int hWnd);
   int      MessageBoxA(int hWnd, string lpText, string lpCaption, int style);
   bool     PostMessageA(int hWnd, int msg, int wParam, int lParam);
   int      RegisterWindowMessageA(string lpString);
   int      SendMessageA(int hWnd, int msg, int wParam, int lParam);

#import "winmm.dll"
   bool     PlaySoundA(string lpSound, int hMod, int fSound);
#import
