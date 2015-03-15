/**
 * Die MQL-Fehlercodes sind einheitlich, die Datei "stderror.h" wird in MQL und in C++ gemeinsam verwendet.
 *
 *
 * NOTE: kompatibel zur Original-MetaQuotes-Version
 */
#include <shared/errors.h>


#define NO_ERROR  ERR_NO_ERROR      // außerhalb von stderror.h, da sonst in C++ Warnung: "warning C4005: 'NO_ERROR' : macro redefinition"
                                    //                                                    ">...\winerror.h(116): see previous definition of 'NO_ERROR'"
