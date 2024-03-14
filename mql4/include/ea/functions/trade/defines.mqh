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
double   open.price;                   // price
double   open.priceSig;                // signal price
double   open.stopLoss;                // price
double   open.takeProfit;              // price
double   open.slippageP;               // full points
double   open.swapM;                   // money amount
double   open.commissionM;             // money amount
double   open.grossProfitM;            // money amount
double   open.netProfitM;              // money amount
double   open.netProfitP;              // full points
double   open.runupP;                  // full points: max runup distance
double   open.rundownP;                // full points: max rundown distance
double   open.sigProfitP;              // full points
double   open.sigRunupP;               // full points: max signal runup distance
double   open.sigRundownP;             // full points: max signal rundown distance

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
#define H_OPENPRICE         7          // price
#define H_OPENPRICE_SIG     8          // signal price
#define H_STOPLOSS          9          // price
#define H_TAKEPROFIT       10          // price
#define H_CLOSETIME        11
#define H_CLOSEPRICE       12          // price
#define H_CLOSEPRICE_SIG   13          // signal price
#define H_SLIPPAGE_P       14          // full points
#define H_SWAP_M           15          // money amount
#define H_COMMISSION_M     16          // money amount
#define H_GROSSPROFIT_M    17          // money amount
#define H_NETPROFIT_M      18          // money amount
#define H_NETPROFIT_P      19          // full points
#define H_RUNUP_P          20          // full points
#define H_RUNDOWN_P        21          // full points
#define H_SIG_PROFIT_P     22          // full points
#define H_SIG_RUNUP_P      23          // full points
#define H_SIG_RUNDOWN_P    24          // full points

// If partialClose[] / history[] fields are modified the following files must be updated:
//  ea/functions/status/file/ReadStatus.HistoryRecord.mqh
//  ea/functions/trade/AddHistoryRecord.mqh + every usage of AddHistoryRecord() elsewhere
//  ea/functions/trade/HistoryRecordToStr.mqh
//  ea/functions/trade/HistoryRecordDescr.mqh
//  ea/functions/trade/MovePositionToHistory.mqh
