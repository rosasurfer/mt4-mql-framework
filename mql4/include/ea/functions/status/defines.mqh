/**
 * Status constants.
 */

#define STATUS_WAITING  1        // instance is switched on, has no open orders and waits for trade signals
#define STATUS_TRADING  2        // instance is switched on and manages open orders
#define STATUS_STOPPED  3        // instance is switched off (no open orders, no trading)
