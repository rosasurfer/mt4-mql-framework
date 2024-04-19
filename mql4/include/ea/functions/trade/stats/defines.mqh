/**
 * Trade statistic related constants and global vars.
 */
double stats[4][77];                            // trade statistics with metric id as main index (index 0 is not used)

#define S_OPEN_PROFIT                      0    // statistic fields
#define S_CLOSED_PROFIT                    1
#define S_TOTAL_PROFIT                     2
#define S_MAX_PROFIT                       3    // 0...+n
#define S_MAX_ABS_DRAWDOWN                 4    // 0...-n
#define S_MAX_REL_DRAWDOWN                 5    // 0...-n

#define S_TRADES                           6    // all closed trades
#define S_TRADES_LONG                      7
#define S_TRADES_LONG_PCT                  8
#define S_TRADES_SHORT                     9
#define S_TRADES_SHORT_PCT                10
#define S_TRADES_TOTAL_PROFIT             11
#define S_TRADES_SUM_RUNUP                12
#define S_TRADES_SUM_DRAWDOWN             13
#define S_TRADES_AVG_PROFIT               14
#define S_TRADES_AVG_RUNUP                15
#define S_TRADES_AVG_DRAWDOWN             16
#define S_TRADES_PROFIT_FACTOR            17
#define S_TRADES_SHARPE_RATIO             18
#define S_TRADES_SORTINO_RATIO            19
#define S_TRADES_CALMAR_RATIO             20

#define S_WINNERS                         21
#define S_WINNERS_PCT                     22
#define S_WINNERS_LONG                    23
#define S_WINNERS_LONG_PCT                24
#define S_WINNERS_SHORT                   25
#define S_WINNERS_SHORT_PCT               26
#define S_WINNERS_GROSS_PROFIT            27
#define S_WINNERS_SUM_RUNUP               28
#define S_WINNERS_SUM_DRAWDOWN            29
#define S_WINNERS_AVG_PROFIT              30
#define S_WINNERS_AVG_RUNUP               31
#define S_WINNERS_AVG_DRAWDOWN            32
#define S_WINNERS_CUR_CONS_COUNT          33
#define S_WINNERS_CUR_CONS_FROM           34
#define S_WINNERS_CUR_CONS_TO             35
#define S_WINNERS_CUR_CONS_PROFIT         36
#define S_WINNERS_MAX_CONS_COUNT          37
#define S_WINNERS_MAX_CONS_COUNT_FROM     38
#define S_WINNERS_MAX_CONS_COUNT_TO       39
#define S_WINNERS_MAX_CONS_COUNT_PROFIT   40
#define S_WINNERS_MAX_CONS_PROFIT         41
#define S_WINNERS_MAX_CONS_PROFIT_FROM    42
#define S_WINNERS_MAX_CONS_PROFIT_TO      43
#define S_WINNERS_MAX_CONS_PROFIT_COUNT   44

#define S_LOSERS                          45
#define S_LOSERS_PCT                      46
#define S_LOSERS_LONG                     47
#define S_LOSERS_LONG_PCT                 48
#define S_LOSERS_SHORT                    49
#define S_LOSERS_SHORT_PCT                50
#define S_LOSERS_GROSS_LOSS               51
#define S_LOSERS_SUM_RUNUP                52
#define S_LOSERS_SUM_DRAWDOWN             53
#define S_LOSERS_AVG_LOSS                 54
#define S_LOSERS_AVG_RUNUP                55
#define S_LOSERS_AVG_DRAWDOWN             56
#define S_LOSERS_CUR_CONS_COUNT           57
#define S_LOSERS_CUR_CONS_FROM            58
#define S_LOSERS_CUR_CONS_TO              59
#define S_LOSERS_CUR_CONS_LOSS            60
#define S_LOSERS_MAX_CONS_COUNT           61
#define S_LOSERS_MAX_CONS_COUNT_FROM      62
#define S_LOSERS_MAX_CONS_COUNT_TO        63
#define S_LOSERS_MAX_CONS_COUNT_LOSS      64
#define S_LOSERS_MAX_CONS_LOSS            65
#define S_LOSERS_MAX_CONS_LOSS_FROM       66
#define S_LOSERS_MAX_CONS_LOSS_TO         67
#define S_LOSERS_MAX_CONS_LOSS_COUNT      68

#define S_SCRATCH                         69
#define S_SCRATCH_PCT                     70
#define S_SCRATCH_LONG                    71
#define S_SCRATCH_LONG_PCT                72
#define S_SCRATCH_SHORT                   73
#define S_SCRATCH_SHORT_PCT               74

#define S_LAST_TRADE_TYPE                 75    // type of last processed closed trade: winner|loser|scratch
#define S_WORKDAYS                        76    // number of workdays covered by the instance (used to annualize returns)
