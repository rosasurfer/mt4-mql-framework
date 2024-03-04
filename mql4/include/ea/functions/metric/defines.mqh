/**
 * Metric related constants and global vars.
 */

#define METRIC_NET_MONEY   1        // default metrics
#define METRIC_NET_UNITS   2
#define METRIC_SIG_UNITS   3

#define METRIC_NEXT        1        // directions for toggling between metrics
#define METRIC_PREVIOUS   -1

string pUnit = "";                  // "pip" or "point"
int    pDigits;                     // digits of pUnit
int    pMultiplier;                 // quote-price = multiplier * pUnit
