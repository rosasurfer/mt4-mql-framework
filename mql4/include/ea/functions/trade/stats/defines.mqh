/**
 * Trade statistic related constants and global vars.
 */
double stats[4][71];                            // trade statistics with metric id as main index (index 0 is not used)

#define S_TRADES                           0    // stats[] fields
#define S_TRADES_LONG                      1
#define S_TRADES_LONG_PCT                  2
#define S_TRADES_SHORT                     3
#define S_TRADES_SHORT_PCT                 4
#define S_TRADES_TOTAL_PROFIT              5
#define S_TRADES_SUM_RUNUP                 6
#define S_TRADES_SUM_DRAWDOWN              7
#define S_TRADES_AVG_PROFIT                8
#define S_TRADES_AVG_RUNUP                 9
#define S_TRADES_AVG_DRAWDOWN             10
#define S_TRADES_PROFIT_FACTOR            11
#define S_TRADES_SHARPE_RATIO             12
#define S_TRADES_SORTINO_RATIO            13
#define S_TRADES_CALMAR_RATIO             14

#define S_WINNERS                         15
#define S_WINNERS_PCT                     16
#define S_WINNERS_LONG                    17
#define S_WINNERS_LONG_PCT                18
#define S_WINNERS_SHORT                   19
#define S_WINNERS_SHORT_PCT               20
#define S_WINNERS_GROSS_PROFIT            21
#define S_WINNERS_SUM_RUNUP               22
#define S_WINNERS_SUM_DRAWDOWN            23
#define S_WINNERS_AVG_PROFIT              24
#define S_WINNERS_AVG_RUNUP               25
#define S_WINNERS_AVG_DRAWDOWN            26
#define S_WINNERS_CUR_CONS_COUNT          27
#define S_WINNERS_CUR_CONS_FROM           28
#define S_WINNERS_CUR_CONS_TO             29
#define S_WINNERS_CUR_CONS_PROFIT         30
#define S_WINNERS_MAX_CONS_COUNT          31
#define S_WINNERS_MAX_CONS_COUNT_FROM     32
#define S_WINNERS_MAX_CONS_COUNT_TO       33
#define S_WINNERS_MAX_CONS_COUNT_PROFIT   34
#define S_WINNERS_MAX_CONS_PROFIT         35
#define S_WINNERS_MAX_CONS_PROFIT_FROM    36
#define S_WINNERS_MAX_CONS_PROFIT_TO      37
#define S_WINNERS_MAX_CONS_PROFIT_COUNT   38

#define S_LOSERS                          39
#define S_LOSERS_PCT                      40
#define S_LOSERS_LONG                     41
#define S_LOSERS_LONG_PCT                 42
#define S_LOSERS_SHORT                    43
#define S_LOSERS_SHORT_PCT                44
#define S_LOSERS_GROSS_LOSS               45
#define S_LOSERS_SUM_RUNUP                46
#define S_LOSERS_SUM_DRAWDOWN             47
#define S_LOSERS_AVG_LOSS                 48
#define S_LOSERS_AVG_RUNUP                49
#define S_LOSERS_AVG_DRAWDOWN             50
#define S_LOSERS_CUR_CONS_COUNT           51
#define S_LOSERS_CUR_CONS_FROM            52
#define S_LOSERS_CUR_CONS_TO              53
#define S_LOSERS_CUR_CONS_LOSS            54
#define S_LOSERS_MAX_CONS_COUNT           55
#define S_LOSERS_MAX_CONS_COUNT_FROM      56
#define S_LOSERS_MAX_CONS_COUNT_TO        57
#define S_LOSERS_MAX_CONS_COUNT_LOSS      58
#define S_LOSERS_MAX_CONS_LOSS            59
#define S_LOSERS_MAX_CONS_LOSS_FROM       60
#define S_LOSERS_MAX_CONS_LOSS_TO         61
#define S_LOSERS_MAX_CONS_LOSS_COUNT      62

#define S_SCRATCH                         63
#define S_SCRATCH_PCT                     64
#define S_SCRATCH_LONG                    65
#define S_SCRATCH_LONG_PCT                66
#define S_SCRATCH_SHORT                   67
#define S_SCRATCH_SHORT_PCT               68

#define S_LAST_TRADE_TYPE                 69    // type of last processed trade: winner|loser|scratch
#define S_WORKDAYS                        70    // number of workdays covered by the trades (used to annualize returns)


double instance.openNetProfit;                  // real PnL after all costs in money (net)
double instance.closedNetProfit;                //
double instance.totalNetProfit;                 //
double instance.maxNetProfit;                   // 0...+n
double instance.maxNetAbsDrawdown;              // -n...0
double instance.maxNetRelDrawdown;              // -n...0

double instance.openNetProfitP;                 // real PnL after all costs in full points (net)
double instance.closedNetProfitP;               //
double instance.totalNetProfitP;                //
double instance.maxNetProfitP;                  //
double instance.maxNetAbsDrawdownP;             //
double instance.maxNetRelDrawdownP;             //

double instance.openSigProfitP;                 // signal PnL before spread/any costs in full points
double instance.closedSigProfitP;               //
double instance.totalSigProfitP;                //
double instance.maxSigProfitP;                  //
double instance.maxSigAbsDrawdownP;             //
double instance.maxSigRelDrawdownP;             //
