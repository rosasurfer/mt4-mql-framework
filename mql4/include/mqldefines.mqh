/**
 * MQL constant definitions
 */
#include <shared/defines.h>            // constants shared between MQL and C++
#include <shared/errors.h>             // error codes shared between MQL and C++


// separately defined constants to prevent C++ warning "C4005: macro redefinition"
#define CLR_NONE  0xFFFFFFFF           // no color in contrast to White = 0x00FFFFFF (win32: 0xFFFFFFFFL)
#define NO_ERROR  ERR_NO_ERROR         // win32: 0x0L
