/**
 * Die MQL-Fehlercodes sind einheitlich, die Datei "stderror.h" wird in MQL und in C++ gemeinsam verwendet.
 *
 *
 * NOTE: kompatibel zur Original-MetaQuotes-Version
 */
#include <stderror.h>

                                    // außerhalb von stderror.h, da sonst in C: warning C4005: 'NO_ERROR' : macro redefinition
#define NO_ERROR  ERR_NO_ERROR      //                    >...\winerror.h(116): see previous definition of 'NO_ERROR'

