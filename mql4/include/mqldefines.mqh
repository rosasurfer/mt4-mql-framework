/**
 * MQL constant definitions
 */
#include <shared/defines.h>                           // constants shared by MQL framework and MT4Expander
#include <shared/errors.h>                            // error codes shared by MQL framework and MT4Expander


// separately defined constants to prevent the C++ warning "C4005: macro redefinition"
#define CLR_NONE  0xFFFFFFFF                          // win32 api: 0xFFFFFFFFL
#define NO_ERROR  ERR_NO_ERROR                        // win32 api: 0x0L
