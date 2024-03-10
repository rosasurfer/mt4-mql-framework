/**
 * Metric related constants and global vars.
 */

#define METRIC_NET_MONEY   1           // default metrics
#define METRIC_NET_UNITS   2
#define METRIC_SIG_UNITS   3

#define METRIC_NEXT        1           // directions for toggling between metrics
#define METRIC_PREVIOUS   -1

// PnL stats
double instance.openNetProfit;         // real PnL after all costs in money (net)
double instance.closedNetProfit;       //
double instance.totalNetProfit;        //
double instance.maxNetProfit;          // 0...+n
double instance.maxNetDrawdown;        // -n...0

double instance.openNetProfitP;        // real PnL after all costs in point (net)
double instance.closedNetProfitP;      //
double instance.totalNetProfitP;       //
double instance.maxNetProfitP;         //
double instance.maxNetDrawdownP;       //

double instance.openSigProfitP;        // signal PnL before spread/any costs in point
double instance.closedSigProfitP;      //
double instance.totalSigProfitP;       //
double instance.maxSigProfitP;         //
double instance.maxSigDrawdownP;       //
