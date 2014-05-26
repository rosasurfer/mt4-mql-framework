/**
 * MT4 structure SUBSCRIBED_SYMBOL (Dateiformat "symbols.sel")
 *                                  size        offset
 * struct SUBSCRIBED_SYMBOL {       ----        ------
 *   szchar symbol[12];              12            0        // Symbol, <NUL>-terminiert
 *   int    digits;                   4           12        // Digits
 *   int    index;                    4           16        // Index des Symbols in "symbols.raw"
 *   char   undocumented[12];        12           20        // ???
 *   double point;                    8           32        // Point
 *   int    spread;                   4           40        // Spread in Points (unzuverlässig, evt. NULL)
 *   char   undocumented[4];          4           44
 *   int    tick;                     4           48        // Direction: 0-Uptick, 1-Downtick, 2-n/a
 *   char   undocumented[4];          4           52
 *   int    time;                     4           56        // Time
 *   char   undocumented[4];          4           60        // ???
 *   double bid;                      8           64        // Bid
 *   double ask;                      8           72        // Ask
 *   double high;                     8           80        // Session High
 *   double low;                      8           88        // Session Low
 *   char   undocumented[8];          8           96        // ???
 *   char   undocumented[8];          8          104        // ???
 *   double bid;                      8          112        // Bid (Wiederholung)
 *   double ask;                      8          120        // Ask (Wiederholung)
 * } ss;                          = 128 byte
 */
