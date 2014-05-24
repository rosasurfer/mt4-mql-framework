/**
 * MT4 structure TICK (Dateiformat "ticks.raw")
 *
 *                                  size        offset
 * struct TICK {                    ----        ------
 *   szchar symbol[12];              12            0        // Symbol, <NUL>-terminiert
 *   int    time;                     4           12        // Timestamp
 *   double bid;                      8           16
 *   double ask;                      8           24
 *   int    counter;                  4           32        // fortlaufender Zähler innerhalb der Datei
 *   int    reserved[1];              4           36
 * } t;                            = 40 byte
 */
