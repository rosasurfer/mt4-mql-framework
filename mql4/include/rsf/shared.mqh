/**
 * Built-in and custom MQL constants shared with the MT4Expander (C++).
 *
 * In MQL4 the redefinition of constants (with the same value) is allowed. Redefined entries exist for documentation
 * purposes only.
 */

// in C++ already defined
#define INT_MIN   0x80000000                 // minimum signed int value (-2147483648)
#define INT_MAX   0x7FFFFFFF                 // maximum signed int value (+2147483647)


// fully shared
#include <rsf/expander/defines.h>
#include <rsf/expander/errors.h>


// already defined in C++ with a different type, but the same value
#define NO_ERROR  ERR_NO_ERROR               // 0x0L
#define CLR_NONE  0xFFFFFFFF                 // 0xFFFFFFFFL


// MetaQuotes constants replaced by framework aliases and intentionally not shared (the wording is odd)
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
