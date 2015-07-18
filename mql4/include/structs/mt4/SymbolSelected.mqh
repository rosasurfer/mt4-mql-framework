/**
 * MT4 structure SYMBOL_SELECTED (Format der Datei "symbols.sel")
 *                                  size        offset
 * struct SYMBOL_SELECTED {         ----        ------
 *    szchar symbol[12];             12            0        // Symbol
 *    int    digits;                  4           12        // Digits
 *    int    index;                   4           16        // Index des Symbols in "symbols.raw"
 *    BYTE   undocumented[12];       12           20
 *    double point;                   8           32        // Point
 *    int    spread;                  4           40        // Spread in Points (unzuverlässig, evt. NULL)
 *    BYTE   undocumented[4];         4           44
 *    int    tick;                    4           48        // Direction: 0-Uptick, 1-Downtick, 2-n/a
 *    BYTE   undocumented[4];         4           52
 *    int    time;                    4           56        // Time
 *    BYTE   undocumented[4];         4           60
 *    double bid;                     8           64        // Bid
 *    double ask;                     8           72        // Ask
 *    double high;                    8           80        // Session High
 *    double low;                     8           88        // Session Low
 *    BYTE   undocumented[16];       16           96
 *    double bid;                     8          112        // Bid (Wiederholung)
 *    double ask;                     8          120        // Ask (Wiederholung)
 * } ss;                          = 128 byte
 */
