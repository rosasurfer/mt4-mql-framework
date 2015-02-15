/**
 * MQL-Fehlercodes sind einheitlich und werden in MQL und in C++ (im MT4Expander) gemeinsam verwendet.
 *
 *
 * NOTE: kompatibel zur Original-MetaQuotes-Version
 */
#include <stderror.h>

#define NO_ERROR  ERR_NO_ERROR      // außerhalb von stderror.h, da sonst in C: warning C4005: 'NO_ERROR' : macro redefinition
                                    //                    >...\winerror.h(116): see previous definition of 'NO_ERROR'
