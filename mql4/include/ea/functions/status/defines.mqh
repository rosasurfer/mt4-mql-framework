/**
 * Status related constants and global vars.
 */

#define STATUS_WAITING  1                 // instance is switched on, has no open orders and waits for trade signals
#define STATUS_TRADING  2                 // instance is switched on and manages open orders
#define STATUS_STOPPED  3                 // instance is switched off (no open orders, no trading)

// volatile status vars
string status.filename = "";              // filepath relative to the MQL sandbox directory
int    status.activeMetric = 1;
bool   status.showOpenOrders;
bool   status.showTradeHistory;

// cache vars to speed-up ShowStatus()
string status.metricDescription = "";
string status.openLots = "";
string status.closedTrades = "";
string status.totalProfit = "";
string status.profitStats = "";
