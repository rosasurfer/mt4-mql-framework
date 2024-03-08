/**
 * Trade related constants and global vars.
 */

int order.slippage = 1;                // in MQL points


// open order data
int      open.ticket;
int      open.type;
double   open.lots;
datetime open.time;
double   open.price;
double   open.priceSig;                // signal price
double   open.stopLoss;
double   open.takeProfit;
double   open.slippage;
double   open.swap;
double   open.commission;
double   open.grossProfit;
double   open.netProfit;
double   open.netProfitP;
double   open.runupP;                  // max runup distance
double   open.drawdownP;               //
double   open.sigProfitP;
double   open.sigRunupP;               // max signal runup distance
double   open.sigDrawdownP;            //


// trade history data
double history[][22];

#define H_TICKET            0          // indexes of history[]
#define H_TYPE              1
#define H_LOTS              2
#define H_OPENTIME          3
#define H_OPENPRICE         4
#define H_OPENPRICE_SIG     5
#define H_STOPLOSS          6
#define H_TAKEPROFIT        7
#define H_CLOSETIME         8
#define H_CLOSEPRICE        9
#define H_CLOSEPRICE_SIG   10
#define H_SLIPPAGE         11
#define H_SWAP             12
#define H_COMMISSION       13
#define H_GROSSPROFIT      14
#define H_NETPROFIT        15
#define H_NETPROFIT_P      16
#define H_RUNUP_P          17
#define H_DRAWDOWN_P       18
#define H_SIG_PROFIT_P     19
#define H_SIG_RUNUP_P      20
#define H_SIG_DRAWDOWN_P   21
