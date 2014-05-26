/**
 * MT4 structure SYMBOL_GROUP (Dateiformat "symgroups.raw")
 *                                  size        offset
 * struct SYMBOL_GROUP {            ----        ------
 *   szchar name       [16];         16            0        // Name, <NUL>-terminiert
 *   szchar description[64];         64            4        // Beschreibung, <NUL>-terminiert
 * } sg;                           = 80 byte
 */
