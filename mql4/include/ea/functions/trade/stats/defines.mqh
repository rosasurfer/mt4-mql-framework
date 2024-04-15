/**
 * Trade statistic related constants and global vars.
 */
/**
 * Statistic related constants and global vars.
 *
 *
 * TODO:
 *  - consecutive winners/profit/losers/loss
 *  - Sharp ratio
 *  - Sortino ratio
 *  - Calmar ratio
 *  - Z-score
 *  - recovery time
 *  - Zephyr Pain Index: https://investexcel.net/zephyr-pain-index/
 *  - Zephyr K-Ratio:    http://web.archive.org/web/20210116024652/https://www.styleadvisor.com/resources/statfacts/zephyr-k-ratio
 */

double stats[4][42];                         // trade statistic per metric with metric id as index (0 is unused)

#define S_TRADES                    0        // indexes of trade statistics
#define S_TRADES_LONG               1
#define S_TRADES_LONG_PCT           2
#define S_TRADES_SHORT              3
#define S_TRADES_SHORT_PCT          4
#define S_TRADES_TOTAL_PROFIT       5
#define S_TRADES_SUM_RUNUP          6
#define S_TRADES_SUM_DRAWDOWN       7
#define S_TRADES_AVG_PROFIT         8
#define S_TRADES_AVG_RUNUP          9
#define S_TRADES_AVG_DRAWDOWN      10
#define S_TRADES_PROFIT_FACTOR     11

#define S_WINNERS                  12
#define S_WINNERS_PCT              13
#define S_WINNERS_LONG             14
#define S_WINNERS_LONG_PCT         15
#define S_WINNERS_SHORT            16
#define S_WINNERS_SHORT_PCT        17
#define S_WINNERS_TOTAL_PROFIT     18
#define S_WINNERS_SUM_RUNUP        19
#define S_WINNERS_SUM_DRAWDOWN     20
#define S_WINNERS_AVG_PROFIT       21
#define S_WINNERS_AVG_RUNUP        22
#define S_WINNERS_AVG_DRAWDOWN     23

#define S_LOSERS                   24
#define S_LOSERS_PCT               25
#define S_LOSERS_LONG              26
#define S_LOSERS_LONG_PCT          27
#define S_LOSERS_SHORT             28
#define S_LOSERS_SHORT_PCT         29
#define S_LOSERS_TOTAL_LOSS        30
#define S_LOSERS_SUM_RUNUP         31
#define S_LOSERS_SUM_DRAWDOWN      32
#define S_LOSERS_AVG_LOSS          33
#define S_LOSERS_AVG_RUNUP         34
#define S_LOSERS_AVG_DRAWDOWN      35

#define S_SCRATCH                  36
#define S_SCRATCH_PCT              37
#define S_SCRATCH_LONG             38
#define S_SCRATCH_LONG_PCT         39
#define S_SCRATCH_SHORT            40
#define S_SCRATCH_SHORT_PCT        41
