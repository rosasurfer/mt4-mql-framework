/**
 * Signal related constants.
 */

// indexes of var signal[] as MQL4.0 doesn't support structs
#define SIG_TYPE                 0
#define SIG_PRICE                1
#define SIG_OP                   2

// signal types                  0     // typically used to mark manual execution
#define SIG_TYPE_TIME            1     //
#define SIG_TYPE_STOPLOSS        2     //
#define SIG_TYPE_TAKEPROFIT      3     //
#define SIG_TYPE_ZIGZAG          4     // The user may define additional custom types.
#define SIG_TYPE_CHANNEL         5     // In this case SignalTypeToStr() must be reimplemented.

// operation type flags, can be combined
#define SIG_OP_LONG              1     //
#define SIG_OP_SHORT             2     //
#define SIG_OP_CLOSE_LONG        4     //
#define SIG_OP_CLOSE_SHORT       8     // The user may define additional custom types.
#define SIG_OP_CLOSE_ALL        12     // In this case SignalOperationToStr() and SignalOperationDescr() must be reimplemented.
