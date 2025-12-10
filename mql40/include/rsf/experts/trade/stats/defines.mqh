/**
 * Trade statistic related constants and global vars.
 */
double stats[4][77];                            // trade statistics with metric id as main index (index 0 is not used)

#define S_OPEN_PROFIT                      0    // statistic fields
#define S_CLOSED_PROFIT                    1
#define S_TOTAL_PROFIT                     2
#define S_MAX_PROFIT                       3    // 0...+n
#define S_MAX_ABS_DRAWDOWN                 4    // -n...0
#define S_MAX_REL_DRAWDOWN                 5    // -n...0
#define S_PROFIT_FACTOR                    6
#define S_SHARPE_RATIO                     7
#define S_SORTINO_RATIO                    8
#define S_CALMAR_RATIO                     9
#define S_DAYS                            10    // number of calendar days the instance was running (for annualization)

#define S_TRADES                          11    // all closed trades
#define S_TRADES_LONG                     12
#define S_TRADES_LONG_PCT                 13
#define S_TRADES_SHORT                    14
#define S_TRADES_SHORT_PCT                15
#define S_TRADES_TOTAL_PROFIT             16
#define S_TRADES_SUM_RUNUP                17
#define S_TRADES_SUM_DRAWDOWN             18
#define S_TRADES_AVG_PROFIT               19
#define S_TRADES_AVG_RUNUP                20
#define S_TRADES_AVG_DRAWDOWN             21
#define S_TRADES_LAST_TYPE                22    // type of last processed trade: winner|loser|scratch

#define S_WINNERS                         23
#define S_WINNERS_PCT                     24
#define S_WINNERS_LONG                    25
#define S_WINNERS_LONG_PCT                26
#define S_WINNERS_SHORT                   27
#define S_WINNERS_SHORT_PCT               28
#define S_WINNERS_GROSS_PROFIT            29
#define S_WINNERS_SUM_RUNUP               30
#define S_WINNERS_SUM_DRAWDOWN            31
#define S_WINNERS_AVG_PROFIT              32
#define S_WINNERS_AVG_RUNUP               33
#define S_WINNERS_AVG_DRAWDOWN            34
#define S_WINNERS_CUR_CONS_COUNT          35
#define S_WINNERS_CUR_CONS_FROM           36
#define S_WINNERS_CUR_CONS_TO             37
#define S_WINNERS_CUR_CONS_PROFIT         38
#define S_WINNERS_MAX_CONS_COUNT          39
#define S_WINNERS_MAX_CONS_COUNT_FROM     40
#define S_WINNERS_MAX_CONS_COUNT_TO       41
#define S_WINNERS_MAX_CONS_COUNT_PROFIT   42
#define S_WINNERS_MAX_CONS_PROFIT         43
#define S_WINNERS_MAX_CONS_PROFIT_FROM    44
#define S_WINNERS_MAX_CONS_PROFIT_TO      45
#define S_WINNERS_MAX_CONS_PROFIT_COUNT   46

#define S_LOSERS                          47
#define S_LOSERS_PCT                      48
#define S_LOSERS_LONG                     49
#define S_LOSERS_LONG_PCT                 50
#define S_LOSERS_SHORT                    51
#define S_LOSERS_SHORT_PCT                52
#define S_LOSERS_GROSS_LOSS               53
#define S_LOSERS_SUM_RUNUP                54
#define S_LOSERS_SUM_DRAWDOWN             55
#define S_LOSERS_AVG_LOSS                 56
#define S_LOSERS_AVG_RUNUP                57
#define S_LOSERS_AVG_DRAWDOWN             58
#define S_LOSERS_CUR_CONS_COUNT           59
#define S_LOSERS_CUR_CONS_FROM            60
#define S_LOSERS_CUR_CONS_TO              61
#define S_LOSERS_CUR_CONS_LOSS            62
#define S_LOSERS_MAX_CONS_COUNT           63
#define S_LOSERS_MAX_CONS_COUNT_FROM      64
#define S_LOSERS_MAX_CONS_COUNT_TO        65
#define S_LOSERS_MAX_CONS_COUNT_LOSS      66
#define S_LOSERS_MAX_CONS_LOSS            67
#define S_LOSERS_MAX_CONS_LOSS_FROM       68
#define S_LOSERS_MAX_CONS_LOSS_TO         69
#define S_LOSERS_MAX_CONS_LOSS_COUNT      70

#define S_SCRATCH                         71
#define S_SCRATCH_PCT                     72
#define S_SCRATCH_LONG                    73
#define S_SCRATCH_LONG_PCT                74
#define S_SCRATCH_SHORT                   75
#define S_SCRATCH_SHORT_PCT               76
