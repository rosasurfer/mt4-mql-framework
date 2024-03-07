/**
 * Signal related constants.
 */

//double signal[3];                                // local var

#define SIG_TYPE                    0              // indexes of signal[]
#define SIG_VALUE                   1
#define SIG_TRADE                   2

#define SIG_TYPE_TIME               1              // signal types
#define SIG_TYPE_STOPLOSS           2
#define SIG_TYPE_TAKEPROFIT         3
#define SIG_TYPE_ZIGZAG             4

#define SIG_TRADE_LONG              1              // signal trade flags, can be combined
#define SIG_TRADE_SHORT             2
#define SIG_TRADE_CLOSE_LONG        4
#define SIG_TRADE_CLOSE_SHORT       8
#define SIG_TRADE_CLOSE_ALL        12              // SIG_TRADE_CLOSE_LONG | SIG_TRADE_CLOSE_SHORT
