/**
 * Trade related constants and global vars.
 */

int order.slippage = 1;                // in MQL points


// open order data
int      open.ticket;
int      open.fromTicket;              // if a partial position: the partially closed ticket this ticket is a remainder from
int      open.toTicket;                // if a partial position: a remaining ticket from partially closing this ticket
int      open.type;
double   open.lots;
double   open.part = 1;                // if a partial position: the percentage size of the original size (between 0..1)
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
double   open.netProfitP;              // *P = price distance
double   open.runupP;                  // max runup distance
double   open.drawdownP;               //
double   open.sigProfitP;
double   open.sigRunupP;               // max signal runup distance
double   open.sigDrawdownP;            //

// If open.* fields are modified the following files must be updated:
//  ea/functions/status/file/ReadStatus.OpenPosition.mqh
//  ea/functions/status/file/SaveStatus.OpenPosition.mqh
//  ea/functions/trade/MovePositionToHistory.mqh
//  ea/functions/trade/OpenPositionDescr.mqh


// partially closed trades: when all parts of a position are closed a single aggregated trade is added to history[]
double partialClose[][25];

// fully closed trades
double history[][25];

#define H_TICKET            0          // indexes of partialClose[] and history[]
#define H_FROM_TICKET       1
#define H_TO_TICKET         2
#define H_TYPE              3
#define H_LOTS              4
#define H_PART              5
#define H_OPENTIME          6
#define H_OPENPRICE         7
#define H_OPENPRICE_SIG     8
#define H_STOPLOSS          9
#define H_TAKEPROFIT       10
#define H_CLOSETIME        11
#define H_CLOSEPRICE       12
#define H_CLOSEPRICE_SIG   13
#define H_SLIPPAGE         14
#define H_SWAP             15
#define H_COMMISSION       16
#define H_GROSSPROFIT      17
#define H_NETPROFIT        18
#define H_NETPROFIT_P      19          // *P = price distance
#define H_RUNUP_P          20
#define H_DRAWDOWN_P       21
#define H_SIG_PROFIT_P     22
#define H_SIG_RUNUP_P      23
#define H_SIG_DRAWDOWN_P   24

// If partialClose[] / history[] fields are modified the following files must be updated:
//  ea/functions/status/file/ReadStatus.HistoryRecord.mqh
//  ea/functions/trade/AddHistoryRecord.mqh + every usage of AddHistoryRecord() elsewhere
//  ea/functions/trade/HistoryRecordToStr.mqh
//  ea/functions/trade/HistoryRecordDescr.mqh
//  ea/functions/trade/MovePositionToHistory.mqh
