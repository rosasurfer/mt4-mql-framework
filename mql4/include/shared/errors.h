/**
 * MQL error codes (shared between MQL and C++)
 *
 * @see  https://docs.mql4.com/constants/errorswarnings/errorcodes
 */
#define ERR_NO_ERROR                                                  0
//define NO_ERROR                                          ERR_NO_ERROR
// To prevent the C++ warning "C4005: macro redefinition" this constant is define in "include/mqldefines.mqh"

// Trading errors
#define ERR_NO_RESULT                                                 1
//      No status returned, the result is unknown. OrderModify() attempted to replace values already set. One or more values
//      must be changed, then modification attempt can be repeated. May also happen if the trade server changes during
//      OrderModify().
#define ERR_TRADESERVER_GONE                                          2
#define ERR_COMMON_ERROR                           ERR_TRADESERVER_GONE    // MetaQuotes alias
//      The trade request failed. A trade server related execution error.
#define ERR_INVALID_TRADE_PARAMETERS                                  3
//      Invalid parameters were passed, e.g. wrong symbol, unknown trade operation, negative slippage, non-existing ticket.
#define ERR_SERVER_BUSY                                               4
//      The trade server is busy. The attempt can be repeated after a rather long period of time (more than several minutes).
#define ERR_OLD_VERSION                                               5    // too old version of the client terminal
#define ERR_NO_CONNECTION                                             6    // no connection to the trade server
#define ERR_NOT_ENOUGH_RIGHTS                                         7
#define ERR_TOO_FREQUENT_REQUESTS                                     8    // trade requests are too frequent
#define ERR_MALFUNCTIONAL_TRADE                                       9    // malfunctional trade operation
#define ERR_ACCOUNT_DISABLED                                         64
#define ERR_INVALID_ACCOUNT                                          65
#define ERR_TRADE_TIMEOUT                                           128
//      The timeout for the trade request has been reached. Before retrying (after at least 1 minute) make sure the trade
//      operation has not yet succeeded (a new position has not been opened, or an existing order has not been modified or
//      deleted, or an existing position has not been closed).
#define ERR_INVALID_PRICE                                           129
//      Invalid bid or ask price, perhaps unnormalized price or price moves too fast (away).
#define ERR_INVALID_STOP                                            130
//      Stops are too close or prices are mis-calculated or not normalized.
#define ERR_INVALID_TRADE_VOLUME                                    131
//      Invalid trade volume, error in the volume granularity.
#define ERR_MARKET_CLOSED                                           132
#define ERR_TRADE_DISABLED                                          133
#define ERR_NOT_ENOUGH_MONEY                                        134
#define ERR_PRICE_CHANGED                                           135    // Price has changed and a retry can be made immediately.
#define ERR_OFF_QUOTES                                              136    // The broker cannot provide prices (backend or liquidity issue).
#define ERR_BROKER_BUSY                                             137    // Automated trading is disabled (manual trading is not affected).
#define ERR_REQUOTE                                                 138    // The offered price has become stale and expired.
#define ERR_ORDER_LOCKED                                            139    // The order has been locked and is under processing.
#define ERR_LONG_POSITIONS_ONLY_ALLOWED                             140
#define ERR_TOO_MANY_REQUESTS                                       141    // The number of trade requests has reached the broker limit.
#define ERR_ORDER_QUEUED                                            142
//      The order has been enqueued. This is an interaction code between client terminal and trade server. It can appear if a
//      reconnection occures during execution of a trade request. It should be processed similar to ERR_TRADE_TIMEOUT.
#define ERR_ORDER_ACCEPTED                                          143
//      The order was accepted for execution. This is an interaction code between client terminal and trade server. It can
//      appear for the same reason as ERR_ORDER_QUEUED and should be processed similar to ERR_TRADE_TIMEOUT.
#define ERR_ORDER_DISCARDED                                         144
//      The order was discarded by the broker during manual confirmation. Interaction code between client terminal and trade server.
#define ERR_TRADE_MODIFY_DENIED                                     145    // modification denied because order is too close to market (MODE_FREEZELEVEL)
#define ERR_TRADE_CONTEXT_BUSY                                      146
#define ERR_TRADE_EXPIRATION_DENIED                                 147    // trade expirations are not supported
#define ERR_TRADE_TOO_MANY_ORDERS                                   148    // The number of open orders has reached the broker limit.
#define ERR_TRADE_HEDGE_PROHIBITED                                  149    // hedging is not supported
#define ERR_TRADE_PROHIBITED_BY_FIFO                                150

// Errors causing a temporary execution stop, the error code is available at the next call of start() or deinit()
#define ERR_WRONG_FUNCTION_POINTER                                 4001
#define ERR_NO_MEMORY_FOR_CALL_STACK                               4003
#define ERR_RECURSIVE_STACK_OVERFLOW                               4004    // stack overflow
#define ERR_NO_MEMORY_FOR_PARAM_STRING                             4006
#define ERR_NO_MEMORY_FOR_TEMP_STRING                              4007
#define ERR_NO_MEMORY_FOR_ARRAYSTRING                              4010
#define ERR_TOO_LONG_STRING                                        4011
#define ERR_REMAINDER_FROM_ZERO_DIVIDE                             4012
#define ERR_UNKNOWN_COMMAND                                        4014

// Errors causing a full execution stop until the program is re-initialized, start() or deinit() will not get called
#define ERR_ZERO_DIVIDE                                            4013
#define ERR_DLL_CALLS_NOT_ALLOWED                                  4017    // imported DLL functions
#define ERR_CANNOT_LOAD_LIBRARY                                    4018
#define ERR_CANNOT_CALL_FUNCTION                                   4019
#define ERR_EX4_CALLS_NOT_ALLOWED                                  4020    // imported MQL library functions

// Runtime errors
#define ERR_NO_MQLERROR                                            4000    // never generated error
#define ERR_ARRAY_INDEX_OUT_OF_RANGE                               4002
#define ERR_NOT_ENOUGH_STACK_FOR_PARAM                             4005
#define ERR_NOT_INITIALIZED_STRING                                 4008
#define ERR_NOT_INITIALIZED_ARRAYSTRING                            4009
#define ERR_WRONG_JUMP                                             4015
#define ERR_NOT_INITIALIZED_ARRAY                                  4016
#define ERR_NO_MEMORY_FOR_RETURNED_STR                             4021
#define ERR_SYSTEM_BUSY                                            4022
#define ERR_DLL_EXCEPTION                                          4023    // DLL function call exception
#define ERR_INTERNAL_ERROR                                         4024
#define ERR_OUT_OF_MEMORY                                          4025    // out of memory
#define ERR_INVALID_POINTER                                        4026    // invalid pointer
#define ERR_FORMAT_TOO_MANY_FORMATTERS                             4027    // too many formatters in the format function
#define ERR_FORMAT_TOO_MANY_PARAMETERS                             4028    // parameters count exceeds formatters count
#define ERR_ARRAY_INVALID                                          4029    // invalid array
#define ERR_CHART_NOREPLY                                          4030    // no reply from chart
#define ERR_INVALID_FUNCTION_PARAMSCNT                             4050    // invalid parameters count
#define ERR_INVALID_PARAMETER                                      4051    // invalid parameter
#define ERR_STRING_FUNCTION_INTERNAL                               4052    // internal string function error
#define ERR_ARRAY_ERROR                                            4053
#define ERR_SERIES_NOT_AVAILABLE                                   4054    // requested time series not available
#define ERR_CUSTOM_INDICATOR_ERROR                                 4055
#define ERR_INCOMPATIBLE_ARRAYS                                    4056
#define ERR_GLOBAL_VARIABLES_PROCESSING                            4057    // global variables processing error
#define ERR_GLOBAL_VARIABLE_NOT_FOUND                              4058
#define ERR_FUNC_NOT_ALLOWED_IN_TESTER                             4059
#define ERR_FUNCTION_NOT_CONFIRMED                                 4060
#define ERR_SEND_MAIL_ERROR                                        4061
#define ERR_STRING_PARAMETER_EXPECTED                              4062
#define ERR_INTEGER_PARAMETER_EXPECTED                             4063
#define ERR_DOUBLE_PARAMETER_EXPECTED                              4064
#define ERR_ARRAY_AS_PARAMETER_EXPECTED                            4065
#define ERS_HISTORY_UPDATE                                         4066    // temporary state (not an error)
#define ERR_TRADE_ERROR                                            4067    // error in trade function
#define ERR_RESOURCE_NOT_FOUND                                     4068    // resource not found
#define ERR_RESOURCE_NOT_SUPPORTED                                 4069    // resource not supported
#define ERR_RESOURCE_DUPLICATED                                    4070    // duplicate resource
#define ERR_INDICATOR_CANNOT_INIT                                  4071    // custom indicator initialization error
#define ERR_INDICATOR_CANNOT_LOAD                                  4072    // custom indicator load error
#define ERR_NO_HISTORY_DATA                                        4073    // no history data for time series
#define ERR_NO_MEMORY_FOR_HISTORY                                  4074    // no memory for history data
#define ERR_NO_MEMORY_FOR_INDICATOR                                4075    // not enough memory for indicator calculation
#define ERR_END_OF_FILE                                            4099    // end of file
#define ERR_FILE_ERROR                                             4100    // file error
#define ERR_WRONG_FILE_NAME                                        4101
#define ERR_TOO_MANY_OPENED_FILES                                  4102
#define ERR_CANNOT_OPEN_FILE                                       4103
#define ERR_INCOMPATIBLE_FILEACCESS                                4104
#define ERR_NO_TICKET_SELECTED                                     4105
#define ERR_SYMBOL_NOT_AVAILABLE                                   4106
#define ERR_INVALID_PRICE_PARAM                                    4107
#define ERR_INVALID_TICKET                                         4108
#define ERR_TRADE_NOT_ALLOWED                                      4109    // automated trading disabled in the terminal
#define ERR_LONGS_NOT_ALLOWED                                      4110
#define ERR_SHORTS_NOT_ALLOWED                                     4111
#define ERR_AUTOMATED_TRADING_DISABLED                             4112    // automated trading disabled by the broker
#define ERR_OBJECT_ALREADY_EXISTS                                  4200
#define ERR_UNKNOWN_OBJECT_PROPERTY                                4201
#define ERR_OBJECT_DOES_NOT_EXIST                                  4202
#define ERR_UNKNOWN_OBJECT_TYPE                                    4203
#define ERR_NO_OBJECT_NAME                                         4204
#define ERR_OBJECT_COORDINATES_ERROR                               4205
#define ERR_NO_SPECIFIED_SUBWINDOW                                 4206
#define ERR_OBJECT_ERROR                                           4207
#define ERR_CHART_PROP_INVALID                                     4210    // unknown chart property
#define ERR_CHART_NOT_FOUND                                        4211    // chart not found
#define ERR_CHARTWINDOW_NOT_FOUND                                  4212    // chart subwindow not found
#define ERR_CHARTINDICATOR_NOT_FOUND                               4213    // chart indicator not found
#define ERR_SYMBOL_SELECT                                          4220    // symbol select error
#define ERR_NOTIFICATION_SEND_ERROR                                4250    // error placing notification into sending queue
#define ERR_NOTIFICATION_PARAMETER                                 4251    // notification parameter error (empty string passed)
#define ERR_NOTIFICATION_SETTINGS                                  4252    // invalid notification settings
#define ERR_NOTIFICATION_TOO_FREQUENT                              4253    //
#define ERR_FTP_NOSERVER                                           4260    // FTP server is not specified
#define ERR_FTP_NOLOGIN                                            4261    // FTP login is not specified
#define ERR_FTP_CONNECT_FAILED                                     4262    // FTP connection failed
#define ERR_FTP_CLOSED                                             4263    // FTP connection closed
#define ERR_FTP_CHANGEDIR                                          4264    // FTP path not found on server
#define ERR_FTP_FILE_ERROR                                         4265    // file not found to send to FTP server
#define ERR_FTP_ERROR                                              4266    // common error during FTP data transmission
#define ERR_FILE_TOO_MANY_OPENED                                   5001    // too many opened files
#define ERR_FILE_WRONG_FILENAME                                    5002    // wrong file name
#define ERR_FILE_TOO_LONG_FILENAME                                 5003    // too long file name
#define ERR_FILE_CANNOT_OPEN                                       5004    // cannot open file
#define ERR_FILE_BUFFER_ALLOC_ERROR                                5005    // text file buffer allocation error
#define ERR_FILE_CANNOT_DELETE                                     5006    // cannot delete file
#define ERR_FILE_INVALID_HANDLE                                    5007    // invalid file handle (file already closed or wasn't opened)
#define ERR_FILE_UNKNOWN_HANDLE                                    5008    // unknown file handle (handle index is out of handle table)
#define ERR_FILE_NOT_TOWRITE                                       5009    // file must be opened with FILE_WRITE flag
#define ERR_FILE_NOT_TOREAD                                        5010    // file must be opened with FILE_READ flag
#define ERR_FILE_NOT_BIN                                           5011    // file must be opened with FILE_BIN flag
#define ERR_FILE_NOT_TXT                                           5012    // file must be opened with FILE_TXT flag
#define ERR_FILE_NOT_TXTORCSV                                      5013    // file must be opened with FILE_TXT or FILE_CSV flag
#define ERR_FILE_NOT_CSV                                           5014    // file must be opened with FILE_CSV flag
#define ERR_FILE_READ_ERROR                                        5015    // file read error
#define ERR_FILE_WRITE_ERROR                                       5016    // file write error
#define ERR_FILE_BIN_STRINGSIZE                                    5017    // string size must be specified for binary file
#define ERR_FILE_INCOMPATIBLE                                      5018    // incompatible file (for string arrays-TXT, for others-BIN)
#define ERR_FILE_IS_DIRECTORY                                      5019    // file is a directory
#define ERR_FILE_NOT_FOUND                                         5020    // file not found
#define ERR_FILE_NOT_EXIST                           ERR_FILE_NOT_FOUND    // MetaQuotes alias
#define ERR_FILE_CANNOT_REWRITE                                    5021    // file cannot be rewritten
#define ERR_FILE_WRONG_DIRECTORYNAME                               5022    // wrong directory name
#define ERR_FILE_DIRECTORY_NOT_EXIST                               5023    // directory does not exist
#define ERR_FILE_NOT_DIRECTORY                                     5024    // file is not a directory
#define ERR_FILE_CANT_DELETE_DIRECTORY                             5025    // cannot delete directory
#define ERR_FILE_CANT_CLEAN_DIRECTORY                              5026    // cannot clean directory
#define ERR_FILE_ARRAYRESIZE_ERROR                                 5027    // array resize error
#define ERR_FILE_STRINGRESIZE_ERROR                                5028    // string resize error
#define ERR_FILE_STRUCT_WITH_OBJECTS                               5029    // struct contains strings or dynamic arrays
#define ERR_WEBREQUEST_INVALID_ADDRESS                             5200    // invalid URL
#define ERR_WEBREQUEST_CONNECT_FAILED                              5201    // failed to connect
#define ERR_WEBREQUEST_TIMEOUT                                     5202    // timeout exceeded
#define ERR_WEBREQUEST_REQUEST_FAILED                              5203    // HTTP request failed

// user defined errors: 65536-99999 (0x10000-0x1869F)
#define ERR_USER_ERROR_FIRST                                      65536    // MetaQuotes definition
#define ERR_CANCELLED_BY_USER                                     65537    // execution cancelled by user
#define ERR_CONCURRENT_MODIFICATION                               65538    // concurrent modification
#define ERS_EXECUTION_STOPPING                                    65539    // IsStopped() returned TRUE (state, not an error)
#define ERR_FUNC_NOT_ALLOWED                                      65540    // function not allowed
#define ERR_HISTORY_INSUFFICIENT                                  65541    // history insufficient for calculation
#define ERR_ILLEGAL_STATE                                         65542    // illegal state
#define ERR_ACCESS_DENIED                                         65543    // access denied
#define ERR_INVALID_COMMAND                                       65544    // invalid or unknown command
#define ERR_INVALID_CONFIG_VALUE                                  65545    // invalid configuration parameter
#define ERR_INVALID_FILE_FORMAT                                   65546    // invalid file format
#define ERR_INVALID_INPUT_PARAMETER                               65547    // invalid input parameter
#define ERR_INVALID_MARKET_DATA                                   65548    // invalid MarketInfo() data
#define ERR_INVALID_TIMEZONE_CONFIG                               65549    // invalid or missing timezone configuration
#define ERR_MIXED_SYMBOLS                                         65550    // mixed symbols encountered when only one was expected
#define ERR_NOT_IMPLEMENTED                                       65551    // feature not implemented
#define ERR_ORDER_CHANGED                                         65552    // order status changed
#define ERR_RUNTIME_ERROR                                         65553    // runtime error
#define ERR_TERMINAL_INIT_FAILURE                                 65554    // multiple Expert::init() calls
#define ERS_TERMINAL_NOT_YET_READY                                65555    // terminal not yet ready (temporary state; in scripts treated as error)
#define ERR_TOTAL_POSITION_NOT_FLAT                               65556    // total position encountered when flat position was expected
#define ERR_UNDEFINED_STATE                                       65557    // undefined state or behavior

// user defined errors >=100000 are mapped Win32 errors: win32-error + 100000 = mql-error
#define ERR_WIN32_ERROR                                          100000    // 100000 => win32:0 => ERROR_SUCCESS
