/**
 * MQL constants shared with the MT4Expander.
 *
 * When the MT4Expander is compiled definitions are read from directory "mql4/include/shared" and not from here.
 * Nevertheless, these constants exists in both MQL versions and in MT4Expander, and have everywhere the same values.
 *
 * Unlike in MQL4, the redefinition of constants with the same value is not allowed in MQL5.
 */

// in C++ already defined
#ifndef INT_MIN
#define INT_MIN   0x80000000                 // minimum signed int value (-2147483648)
#define INT_MAX   0x7FFFFFFF                 // maximum signed int value (+2147483647)
#endif


// mirror the file structure of "mql4/include/rsf/shared.mqh"
#include <rsf/expander/defines.h>
#include <rsf/expander/errors.h>


// in C++ defined with the same value but a different type
#define CLR_NONE  0xFFFFFFFF                 // 0xFFFFFFFFL


// MetaQuotes constants replaced by framework aliases (too long names or odd wording)
#ifndef ERR_DLLFUNC_CRITICALERROR
#define ERR_DLLFUNC_CRITICALERROR            ERR_DLL_EXCEPTION
#define ERR_EXTERNAL_CALLS_NOT_ALLOWED       ERR_EX4_CALLS_NOT_ALLOWED
#define ERR_FILE_BUFFER_ALLOCATION_ERROR     ERR_FILE_BUFFER_ALLOC_ERROR
#define ERR_FILE_CANNOT_CLEAN_DIRECTORY      ERR_FILE_CANT_CLEAN_DIRECTORY
#define ERR_FILE_CANNOT_DELETE_DIRECTORY     ERR_FILE_CANT_DELETE_DIRECTORY
#define ERR_FILE_NOT_EXIST                   ERR_FILE_NOT_FOUND
#define ERR_FILE_WRONG_HANDLE                ERR_FILE_UNKNOWN_HANDLE
#define ERR_FUNC_NOT_ALLOWED_IN_TESTING      ERR_FUNC_NOT_ALLOWED_IN_TESTER
#define ERR_HISTORY_WILL_UPDATED             ERS_HISTORY_UPDATE               // status code, not an error
#define ERR_INCORRECT_SERIESARRAY_USING      ERR_SERIES_NOT_AVAILABLE
#define ERR_INVALID_FUNCTION_PARAMVALUE      ERR_INVALID_PARAMETER
#define ERR_INVALID_STOPS                    ERR_INVALID_STOP
#define ERR_NOTIFICATION_ERROR               ERR_NOTIFICATION_SEND_ERROR
#define ERR_NO_ORDER_SELECTED                ERR_NO_TICKET_SELECTED
#define ERR_SOME_ARRAY_ERROR                 ERR_ARRAY_ERROR
#define ERR_SOME_FILE_ERROR                  ERR_FILE_ERROR
#define ERR_SOME_OBJECT_ERROR                ERR_OBJECT_ERROR
#define ERR_UNKNOWN_SYMBOL                   ERR_SYMBOL_NOT_AVAILABLE
#endif
