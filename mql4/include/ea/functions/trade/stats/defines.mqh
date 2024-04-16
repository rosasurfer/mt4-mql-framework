/**
 * Trade statistic related constants and global vars.
 *
 *
 * TODO:
 *  - Sharp ratio
 *  - Sortino ratio
 *  - Calmar ratio
 *  - Z-score
 *  - recovery time
 *  - Zephyr Pain Index: https://investexcel.net/zephyr-pain-index/
 *  - Zephyr K-Ratio:    http://web.archive.org/web/20210116024652/https://www.styleadvisor.com/resources/statfacts/zephyr-k-ratio
 */

double stats[4][67];                            // trade statistic per metric with metric id as index (0 is unused)

#define S_TRADES                           0    // indexes of trade statistics
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
#define S_TRADES_LAST_TRADE_RESULT        12    // result type of last processed trade: winner|loser|scratch

#define S_WINNERS                         13
#define S_WINNERS_PCT                     14
#define S_WINNERS_LONG                    15
#define S_WINNERS_LONG_PCT                16
#define S_WINNERS_SHORT                   17
#define S_WINNERS_SHORT_PCT               18
#define S_WINNERS_GROSS_PROFIT            19
#define S_WINNERS_SUM_RUNUP               20
#define S_WINNERS_SUM_DRAWDOWN            21
#define S_WINNERS_AVG_PROFIT              22
#define S_WINNERS_AVG_RUNUP               23
#define S_WINNERS_AVG_DRAWDOWN            24
#define S_WINNERS_CUR_CONS_COUNT          25
#define S_WINNERS_CUR_CONS_FROM           26
#define S_WINNERS_CUR_CONS_TO             27
#define S_WINNERS_CUR_CONS_PROFIT         28
#define S_WINNERS_MAX_CONS_COUNT          29
#define S_WINNERS_MAX_CONS_COUNT_FROM     30
#define S_WINNERS_MAX_CONS_COUNT_TO       31
#define S_WINNERS_MAX_CONS_COUNT_PROFIT   32
#define S_WINNERS_MAX_CONS_PROFIT         33
#define S_WINNERS_MAX_CONS_PROFIT_FROM    34
#define S_WINNERS_MAX_CONS_PROFIT_TO      35
#define S_WINNERS_MAX_CONS_PROFIT_COUNT   36

#define S_LOSERS                          37
#define S_LOSERS_PCT                      38
#define S_LOSERS_LONG                     39
#define S_LOSERS_LONG_PCT                 40
#define S_LOSERS_SHORT                    41
#define S_LOSERS_SHORT_PCT                42
#define S_LOSERS_GROSS_LOSS               43
#define S_LOSERS_SUM_RUNUP                44
#define S_LOSERS_SUM_DRAWDOWN             45
#define S_LOSERS_AVG_LOSS                 46
#define S_LOSERS_AVG_RUNUP                47
#define S_LOSERS_AVG_DRAWDOWN             48
#define S_LOSERS_CUR_CONS_COUNT           49
#define S_LOSERS_CUR_CONS_FROM            50
#define S_LOSERS_CUR_CONS_TO              51
#define S_LOSERS_CUR_CONS_LOSS            52
#define S_LOSERS_MAX_CONS_COUNT           53
#define S_LOSERS_MAX_CONS_COUNT_FROM      54
#define S_LOSERS_MAX_CONS_COUNT_TO        55
#define S_LOSERS_MAX_CONS_COUNT_LOSS      56
#define S_LOSERS_MAX_CONS_LOSS            57
#define S_LOSERS_MAX_CONS_LOSS_FROM       58
#define S_LOSERS_MAX_CONS_LOSS_TO         59
#define S_LOSERS_MAX_CONS_LOSS_COUNT      60

#define S_SCRATCH                         61
#define S_SCRATCH_PCT                     62
#define S_SCRATCH_LONG                    63
#define S_SCRATCH_LONG_PCT                64
#define S_SCRATCH_SHORT                   65
#define S_SCRATCH_SHORT_PCT               66
