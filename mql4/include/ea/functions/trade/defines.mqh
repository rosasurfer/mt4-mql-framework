/**
 * Trade related constants and global vars.
 */

int order.slippage = 1;                // in MQL points


// open order data
int      open.ticket;
int      open.fromTicket;              // if partial position: the partially closed ticket this ticket is a remainder from
int      open.toTicket;                // if partial position: a remaining ticket from partially closing this ticket
int      open.type;
double   open.lots;
double   open.part = 1;                // if partial position: this part's fractional size of the original size (value between 0..1)
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


// fully closed trades
double history[][24];

// partially closed trades: when all parts of a position are closed a single aggregated trade is added to history[]
double partialClose[][24];

#define H_TICKET            0          // indexes of history[] and partialClose[]
#define H_FROM_TICKET       1
#define H_TO_TICKET         2
#define H_TYPE              3
#define H_LOTS              4
#define H_OPENTIME          5
#define H_OPENPRICE         6
#define H_OPENPRICE_SIG     7
#define H_STOPLOSS          8
#define H_TAKEPROFIT        9
#define H_CLOSETIME        10
#define H_CLOSEPRICE       11
#define H_CLOSEPRICE_SIG   12
#define H_SLIPPAGE         13
#define H_SWAP             14
#define H_COMMISSION       15
#define H_GROSSPROFIT      16
#define H_NETPROFIT        17
#define H_NETPROFIT_P      18
#define H_RUNUP_P          19
#define H_DRAWDOWN_P       20
#define H_SIG_PROFIT_P     21
#define H_SIG_RUNUP_P      22
#define H_SIG_DRAWDOWN_P   23
