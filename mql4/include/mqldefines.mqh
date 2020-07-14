/**
 * MQL constants. Separately defined constants prevent C++ warnings "C4005: macro redefinition"
 */
#define INT_MIN   0x80000000                       // -2147483648: minimum signed int value
#define INT_MAX   0x7FFFFFFF                       //  2147483647: maximum signed int value

#include <shared/defines.h>                        // constants shared by MQL4 and MT4Expander
#include <shared/errors.h>                         // error codes shared by MQL4 and MT4Expander

#define CLR_NONE  0xFFFFFFFF                       // win32 api: 0xFFFFFFFFL
#define NO_ERROR  ERR_NO_ERROR                     // win32 api: 0x0L
