/**
 * Signal related constants.
 */

//double signal[3];                                // always a local var

#define SIG_TYPE                 0                 // indexes of signal[]
#define SIG_PRICE                1
#define SIG_OP                   2

#define SIG_TYPE_TIME            1                 // signal types
#define SIG_TYPE_STOPLOSS        2
#define SIG_TYPE_TAKEPROFIT      3
#define SIG_TYPE_ZIGZAG          4
#define SIG_TYPE_TUNNEL          5

#define SIG_OP_LONG              1                 // signal trade flags, can be combined
#define SIG_OP_SHORT             2
#define SIG_OP_CLOSE_LONG        4
#define SIG_OP_CLOSE_SHORT       8
#define SIG_OP_CLOSE_ALL        12                 // SIG_OP_CLOSE_LONG | SIG_OP_CLOSE_SHORT
