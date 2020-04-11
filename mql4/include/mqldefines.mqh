/**
 * MQL constant definitions
 */
#include <shared/defines.h>            // constants shared by framework (MQL) and MT4Expander (C++)
#include <shared/errors.h>             // error codes shared by framework (MQL) and MT4Expander (C++)


// separately defined constants to prevent C++ warning "C4005: macro redefinition"
#define CLR_NONE  0xFFFFFFFF           // no color in contrast to White = 0x00FFFFFF (win32: 0xFFFFFFFFL)
#define clrNONE   CLR_NONE
#define NO_ERROR  ERR_NO_ERROR         // win32: 0x0L
