/**
 * Update/re-calculate trade statistics. Most important numbers:
 *
 *  - Profit factor       = GrossProfit / GrossLoss
 *  - MaxRelativeDrawdown = Max(EquityPeak - EquityValley)
 *  - Sharpe ratio        = AnnualizedReturn / TotalVolatility
 *  - Sortino ratio       = AnnualizedReturn / DownsideVolatility
 *  - Calmar ratio        = AnnualizedReturn / MaxRelativeDrawdown
 *
 * @param  bool fullRecalculation [optional] - whether to process new history entries only or to perform a full recalculation
 *                                             (default: new history entries only)
 * @return bool - success status
 *
 *
 * TODO:
 *  - MaxRecoveryTime = MaxTime(equity high to new high)
 *  - Z-score:             http://web.archive.org/web/20120429061838/http://championship.mql4.com/2007/news/203
 *  - Zephyr Pain Index:   https://investexcel.net/zephyr-pain-index/
 *  - Zephyr K-Ratio:      http://web.archive.org/web/20210116024652/https://www.styleadvisor.com/resources/statfacts/zephyr-k-ratio
 *
 *  @link  https://www.youtube.com/watch?v=GhrxgbQnEEU#   [Linear Regression by Hand]
 */
bool CalculateStats(bool fullRecalculation = false) {
   int hstTrades = ArrayRange(history, 0);
   int processedTrades = stats[1][S_TRADES];

   if (!hstTrades || hstTrades < processedTrades || fullRecalculation) {
      processedTrades = 0;
   }
   if (processedTrades >= hstTrades) return(true);

   int metrics = ArrayRange(stats, 0) - 1;
   int profitFields     [] = {0, H_NETPROFIT_M, H_NETPROFIT_P, H_SIG_PROFIT_P }, iProfitField;
   int profitComparators[] = {0, H_NETPROFIT_P, H_NETPROFIT_P, H_SIG_PROFIT_P }, iProfitCmp;    // always using price units simplifies processing of scratch limits (to be implemented later)
   int runupFields      [] = {0, H_RUNUP_P,     H_RUNUP_P,     H_SIG_RUNUP_P  }, iRunupField;
   int rundownFields    [] = {0, H_RUNDOWN_P,   H_RUNDOWN_P,   H_SIG_RUNDOWN_P}, iRundownField;
   bool prevIsWinner, prevIsLoser;

   // process new history entries only (performance)
   for (int i=processedTrades; i < hstTrades; i++) {
      for (int m=1; m <= metrics; m++) {                                                        // skip unused metric/index 0
         iProfitField  = profitFields     [m];
         iProfitCmp    = profitComparators[m];
         iRunupField   = runupFields      [m];
         iRundownField = rundownFields    [m];

         // long/short
         if (history[i][H_TYPE] == OP_LONG) stats[m][S_TRADES_LONG ]++;
         else                               stats[m][S_TRADES_SHORT]++;

         stats[m][S_TRADES_TOTAL_PROFIT] += history[i][iProfitField ];
         stats[m][S_TRADES_SUM_RUNUP   ] += history[i][iRunupField  ];
         stats[m][S_TRADES_SUM_DRAWDOWN] += history[i][iRundownField];

         // type of the previous trade
         if (i == 0) {
            prevIsWinner = true;
            prevIsLoser = true;
            stats[m][S_WINNERS_CUR_CONS_FROM] = INT_MAX;
            stats[m][S_LOSERS_CUR_CONS_FROM ] = INT_MAX;
         }
         else if (stats[m][S_TRADES_LAST_TYPE] > 0) {
            prevIsWinner = true;
            prevIsLoser = false;
         }
         else if (stats[m][S_TRADES_LAST_TYPE] < 0) {
            prevIsWinner = false;
            prevIsLoser = true;
         }
         else {
            prevIsWinner = true;
            prevIsLoser = true;
         }

         // winners
         if (history[i][iProfitCmp] > HalfPoint) {
            stats[m][S_WINNERS]++;
            if (history[i][H_TYPE] == OP_LONG) stats[m][S_WINNERS_LONG ]++;
            else                               stats[m][S_WINNERS_SHORT]++;
            stats[m][S_WINNERS_GROSS_PROFIT] += history[i][iProfitField ];
            stats[m][S_WINNERS_SUM_RUNUP   ] += history[i][iRunupField  ];
            stats[m][S_WINNERS_SUM_DRAWDOWN] += history[i][iRundownField];

            if (prevIsLoser) {
               stats[m][S_WINNERS_CUR_CONS_COUNT ] = 0;
               stats[m][S_WINNERS_CUR_CONS_FROM  ] = INT_MAX;
               stats[m][S_WINNERS_CUR_CONS_TO    ] = 0;
               stats[m][S_WINNERS_CUR_CONS_PROFIT] = 0;
            }
            stats[m][S_WINNERS_CUR_CONS_COUNT ]++;
            stats[m][S_WINNERS_CUR_CONS_FROM  ] = MathMin(stats[m][S_WINNERS_CUR_CONS_FROM], history[i][H_OPENTIME ]);
            stats[m][S_WINNERS_CUR_CONS_TO    ] = MathMax(stats[m][S_WINNERS_CUR_CONS_TO  ], history[i][H_CLOSETIME]);
            stats[m][S_WINNERS_CUR_CONS_PROFIT] += history[i][iProfitField];

            if (stats[m][S_WINNERS_CUR_CONS_COUNT] > stats[m][S_WINNERS_MAX_CONS_COUNT]) {
               stats[m][S_WINNERS_MAX_CONS_COUNT       ] = stats[m][S_WINNERS_CUR_CONS_COUNT ];
               stats[m][S_WINNERS_MAX_CONS_COUNT_FROM  ] = stats[m][S_WINNERS_CUR_CONS_FROM  ];
               stats[m][S_WINNERS_MAX_CONS_COUNT_TO    ] = stats[m][S_WINNERS_CUR_CONS_TO    ];
               stats[m][S_WINNERS_MAX_CONS_COUNT_PROFIT] = stats[m][S_WINNERS_CUR_CONS_PROFIT];
            }
            if (stats[m][S_WINNERS_CUR_CONS_PROFIT] > stats[m][S_WINNERS_MAX_CONS_PROFIT]) {
               stats[m][S_WINNERS_MAX_CONS_PROFIT      ] = stats[m][S_WINNERS_CUR_CONS_PROFIT];
               stats[m][S_WINNERS_MAX_CONS_PROFIT_FROM ] = stats[m][S_WINNERS_CUR_CONS_FROM  ];
               stats[m][S_WINNERS_MAX_CONS_PROFIT_TO   ] = stats[m][S_WINNERS_CUR_CONS_TO    ];
               stats[m][S_WINNERS_MAX_CONS_PROFIT_COUNT] = stats[m][S_WINNERS_CUR_CONS_COUNT ];
            }
            stats[m][S_TRADES_LAST_TYPE] = 1;
         }

         // losers
         else if (history[i][iProfitCmp] < -HalfPoint) {
            stats[m][S_LOSERS]++;
            if (history[i][H_TYPE] == OP_LONG) stats[m][S_LOSERS_LONG ]++;
            else                               stats[m][S_LOSERS_SHORT]++;
            stats[m][S_LOSERS_GROSS_LOSS  ] += history[i][iProfitField ];
            stats[m][S_LOSERS_SUM_RUNUP   ] += history[i][iRunupField  ];
            stats[m][S_LOSERS_SUM_DRAWDOWN] += history[i][iRundownField];

            if (prevIsWinner) {
               stats[m][S_LOSERS_CUR_CONS_COUNT] = 0;
               stats[m][S_LOSERS_CUR_CONS_FROM ] = INT_MAX;
               stats[m][S_LOSERS_CUR_CONS_TO   ] = 0;
               stats[m][S_LOSERS_CUR_CONS_LOSS ] = 0;
            }
            stats[m][S_LOSERS_CUR_CONS_COUNT]++;
            stats[m][S_LOSERS_CUR_CONS_FROM ] = MathMin(stats[m][S_LOSERS_CUR_CONS_FROM], history[i][H_OPENTIME ]);
            stats[m][S_LOSERS_CUR_CONS_TO   ] = MathMax(stats[m][S_LOSERS_CUR_CONS_TO  ], history[i][H_CLOSETIME]);
            stats[m][S_LOSERS_CUR_CONS_LOSS ] += history[i][iProfitField];

            if (stats[m][S_LOSERS_CUR_CONS_COUNT] > stats[m][S_LOSERS_MAX_CONS_COUNT]) {
               stats[m][S_LOSERS_MAX_CONS_COUNT     ] = stats[m][S_LOSERS_CUR_CONS_COUNT];
               stats[m][S_LOSERS_MAX_CONS_COUNT_FROM] = stats[m][S_LOSERS_CUR_CONS_FROM ];
               stats[m][S_LOSERS_MAX_CONS_COUNT_TO  ] = stats[m][S_LOSERS_CUR_CONS_TO   ];
               stats[m][S_LOSERS_MAX_CONS_COUNT_LOSS] = stats[m][S_LOSERS_CUR_CONS_LOSS ];
            }
            if (stats[m][S_LOSERS_CUR_CONS_LOSS] < stats[m][S_LOSERS_MAX_CONS_LOSS]) {
               stats[m][S_LOSERS_MAX_CONS_LOSS      ] = stats[m][S_LOSERS_CUR_CONS_LOSS ];
               stats[m][S_LOSERS_MAX_CONS_LOSS_FROM ] = stats[m][S_LOSERS_CUR_CONS_FROM ];
               stats[m][S_LOSERS_MAX_CONS_LOSS_TO   ] = stats[m][S_LOSERS_CUR_CONS_TO   ];
               stats[m][S_LOSERS_MAX_CONS_LOSS_COUNT] = stats[m][S_LOSERS_CUR_CONS_COUNT];
            }
            stats[m][S_TRADES_LAST_TYPE] = -1;
         }

         // scratch
         else {
            stats[m][S_SCRATCH]++;
            if (history[i][H_TYPE] == OP_LONG) stats[m][S_SCRATCH_LONG ]++;
            else                               stats[m][S_SCRATCH_SHORT]++;
            //stats[m][S_TRADES_LAST_TYPE] = unchanged
         }
      }
   }

   // calculate number of trading days the instance was running (don't use OpenTime/CloseTime)
   datetime startTime = instance.started;
   datetime endTime = ifInt(instance.stopped, instance.stopped, Tick.time);
   int days = CountCalendarDays(startTime, endTime);
   if (!days) return(false);

   // calculate summaries, percentages, averages, ratios
   for (m=1; m <= metrics; m++) {
      stats[m][S_TRADES] = hstTrades;
      stats[m][S_DAYS  ] = days;

      stats[m][S_TRADES_LONG_PCT     ] = MathDiv(stats[m][S_TRADES_LONG         ], stats[m][S_TRADES ]);
      stats[m][S_TRADES_SHORT_PCT    ] = MathDiv(stats[m][S_TRADES_SHORT        ], stats[m][S_TRADES ]);
      stats[m][S_WINNERS_PCT         ] = MathDiv(stats[m][S_WINNERS             ], stats[m][S_TRADES ]);
      stats[m][S_WINNERS_LONG_PCT    ] = MathDiv(stats[m][S_WINNERS_LONG        ], stats[m][S_WINNERS]);
      stats[m][S_WINNERS_SHORT_PCT   ] = MathDiv(stats[m][S_WINNERS_SHORT       ], stats[m][S_WINNERS]);
      stats[m][S_LOSERS_PCT          ] = MathDiv(stats[m][S_LOSERS              ], stats[m][S_TRADES ]);
      stats[m][S_LOSERS_LONG_PCT     ] = MathDiv(stats[m][S_LOSERS_LONG         ], stats[m][S_LOSERS ]);
      stats[m][S_LOSERS_SHORT_PCT    ] = MathDiv(stats[m][S_LOSERS_SHORT        ], stats[m][S_LOSERS ]);
      stats[m][S_SCRATCH_PCT         ] = MathDiv(stats[m][S_SCRATCH             ], stats[m][S_TRADES ]);
      stats[m][S_SCRATCH_LONG_PCT    ] = MathDiv(stats[m][S_SCRATCH_LONG        ], stats[m][S_SCRATCH]);
      stats[m][S_SCRATCH_SHORT_PCT   ] = MathDiv(stats[m][S_SCRATCH_SHORT       ], stats[m][S_SCRATCH]);

      stats[m][S_TRADES_AVG_PROFIT   ] = MathDiv(stats[m][S_TRADES_TOTAL_PROFIT ], stats[m][S_TRADES ]);
      stats[m][S_TRADES_AVG_RUNUP    ] = MathDiv(stats[m][S_TRADES_SUM_RUNUP    ], stats[m][S_TRADES ]);
      stats[m][S_TRADES_AVG_DRAWDOWN ] = MathDiv(stats[m][S_TRADES_SUM_DRAWDOWN ], stats[m][S_TRADES ]);

      stats[m][S_WINNERS_AVG_PROFIT  ] = MathDiv(stats[m][S_WINNERS_GROSS_PROFIT], stats[m][S_WINNERS]);
      stats[m][S_WINNERS_AVG_RUNUP   ] = MathDiv(stats[m][S_WINNERS_SUM_RUNUP   ], stats[m][S_WINNERS]);
      stats[m][S_WINNERS_AVG_DRAWDOWN] = MathDiv(stats[m][S_WINNERS_SUM_DRAWDOWN], stats[m][S_WINNERS]);

      stats[m][S_LOSERS_AVG_LOSS     ] = MathDiv(stats[m][S_LOSERS_GROSS_LOSS   ], stats[m][S_LOSERS ]);
      stats[m][S_LOSERS_AVG_RUNUP    ] = MathDiv(stats[m][S_LOSERS_SUM_RUNUP    ], stats[m][S_LOSERS ]);
      stats[m][S_LOSERS_AVG_DRAWDOWN ] = MathDiv(stats[m][S_LOSERS_SUM_DRAWDOWN ], stats[m][S_LOSERS ]);

      stats[m][S_PROFIT_FACTOR] = MathAbs(MathDiv(stats[m][S_WINNERS_GROSS_PROFIT], stats[m][S_LOSERS_GROSS_LOSS], 99999));   // 99999: alias for +Infinity
      stats[m][S_SHARPE_RATIO ] = CalculateSharpeRatio(m);  if (!stats[m][S_SHARPE_RATIO ]) return(false);
      stats[m][S_SORTINO_RATIO] = CalculateSortinoRatio(m); if (!stats[m][S_SORTINO_RATIO]) return(false);
      stats[m][S_CALMAR_RATIO ] = CalculateCalmarRatio(m);  if (!stats[m][S_CALMAR_RATIO ]) return(false);
   }

   return(!catch("CalculateStats(1)"));
}


/**
 * Calculate the annualized Sharpe ratio for the specified metric.
 *
 *  Sharpe ratio = AnnualizedReturn / TotalVolatility
 *  TotalVolatility = StdDeviation(AllReturns)
 *
 * @param  int metric - metric id
 *
 * @return double - positive ratio or -1 if the strategy is not profitable; NULL in case of errors
 *
 * @link   https://investexcel.net/calculating-the-sharpe-ratio-with-excel/
 * @link   https://www.calculator.net/standard-deviation-calculator.html
 * @link   https://investexcel.net/how-to-annualize-volatility/
 * @link   https://stats.stackexchange.com/questions/32318/difference-between-standard-error-and-standard-deviation
 */
double CalculateSharpeRatio(int metric) {
   double totalReturn = stats[metric][S_TRADES_TOTAL_PROFIT];
   if (!totalReturn)    return(0);
   if (totalReturn < 0) return(-1);

   // process trades with updated stats only
   int trades = stats[metric][S_TRADES];
   if (!trades) return(0);
   if (trades > ArrayRange(history, 0)) return(!catch("CalculateSharpeRatio(1)  illegal value of stats["+ metric +"][S_TRADES]: "+ trades +" (out-of-range)", ERR_ILLEGAL_STATE));

   // annualize total return
   int days = stats[metric][S_DAYS];
   if (days <= 0)                       return(!catch("CalculateSharpeRatio(2)  illegal value of stats["+ metric +"][S_DAYS]: "+ days +" (must be positive)", ERR_ILLEGAL_STATE));
   double annualizedReturn = totalReturn/days * 365;

   // prepare dataset for iStdDevOnArray()
   int profitFields[] = {0, H_NETPROFIT_M, H_NETPROFIT_P, H_SIG_PROFIT_P}, iProfit=profitFields[metric];
   double returns[];
   ArrayResize(returns, trades);
   for (int i=0; i < trades; i++) {
      returns[i] = history[i][iProfit];
   }

   // calculate stdDeviation and final ratio
   double stdDev = iStdDevOnArray(returns, WHOLE_ARRAY, trades, 0, MODE_SMA, 0);
   double ratio = MathDiv(annualizedReturn, stdDev, 99999);                   // 99999: alias for +Infinity

   ArrayResize(returns, 0);
   return(ratio);

   // StdDeviation (SD) doesn't change predictably with more data. We can't reliably predict whether SD from a large sample will be
   // bigger or smaller than SD from a small sample. However, annualization of SD as done in std-finance (multiply by square root of
   // the time scaling factor) is based on such a prediction. It assumes a steady degration of investment performance in the future.
   //
   // This approach is not suitable for algo-trading where the task of the algorythm is the opposite: adapt and counter-act degrations.
   // Thus we don't annualize SD and assume consistent volatility as long as system performance (total return) stays consistent.
}


/**
 * Calculate the annualized Sortino ratio for the specified metric.
 *
 *  Sortino ratio = AnnualizedReturn / DownsideVolatility
 *  DownsideVolatility = StdDeviation(NegativeReturns)
 *
 * @param  int metric - metric id
 *
 * @return double - positive ratio or -1 if the strategy is not profitable; NULL in case of errors
 *
 * @link   https://investexcel.net/calculate-the-sortino-ratio-with-excel/
 * @link   https://www.calculator.net/standard-deviation-calculator.html
 * @link   https://investexcel.net/how-to-annualize-volatility/
 * @link   https://stats.stackexchange.com/questions/32318/difference-between-standard-error-and-standard-deviation
 */
double CalculateSortinoRatio(int metric) {
   double totalReturn = stats[metric][S_TRADES_TOTAL_PROFIT];
   if (!totalReturn)    return(0);
   if (totalReturn < 0) return(-1);

   // process trades with updated stats only
   int trades = stats[metric][S_TRADES];
   if (!trades) return(0);
   if (trades > ArrayRange(history, 0)) return(!catch("CalculateSortinoRatio(1)  illegal value of stats["+ metric +"][S_TRADES]: "+ trades +" (out-of-range)", ERR_ILLEGAL_STATE));

   // annualize total return
   int days = stats[metric][S_DAYS];
   if (days <= 0)                       return(!catch("CalculateSortinoRatio(2)  illegal value of stats["+ metric +"][S_DAYS]: "+ days +" (must be positive)", ERR_ILLEGAL_STATE));
   double annualizedReturn = totalReturn/days * 365;

   // prepare dataset for iStdDevOnArray()
   int profitFields[] = {0, H_NETPROFIT_M, H_NETPROFIT_P, H_SIG_PROFIT_P}, iProfit=profitFields[metric];
   double returns[];
   ArrayResize(returns, trades);
   for (int n, i=0; i < trades; i++) {
      if (history[i][iProfit] >= 0) continue;                                 // Don't include 0 (zero) for non-negative returns as we are
      returns[n] = history[i][iProfit];                                       // interested in volatility of negative returns only.
      n++;
   }
   ArrayResize(returns, n);

   // calculate stdDeviation and final ratio                                  // Returns {-2, -2, -2} and {-3, -3, -3} correctly have the same volatility.
   double stdDev = iStdDevOnArray(returns, WHOLE_ARRAY, n, 0, MODE_SMA, 0);   // Size of losses is already accounted for by the nominator.
   double ratio = MathDiv(annualizedReturn, stdDev, 99999);                   // 99999: alias for +Infinity

   ArrayResize(returns, 0);
   return(ratio);

   // StdDeviation (SD) doesn't change predictably with more data. We can't reliably predict whether SD from a large sample will be
   // bigger or smaller than SD from a small sample. However, annualization of SD as done in std-finance (multiply by square root of
   // the time scaling factor) is based on such a prediction. It assumes a steady degration of investment performance in the future.
   //
   // This approach is not suitable for algo-trading where the task of the algorythm is the opposite: adapt and counter-act degrations.
   // Thus we don't annualize SD and assume consistent volatility as long as system performance (total return) stays consistent.
}


/**
 * Calculate the annualized Calmar ratio for the specified metric.
 *
 *  Calmar ratio = AnnualizedReturn / MaxRelativeDrawdown
 *  MaxRelativeDrawdown = Max(EquityPeak - EquityValley)
 *
 * @param  int metric - metric id
 *
 * @return double - positive ratio or -1 if the strategy is not profitable; NULL in case of errors
 *
 * @link  https://investexcel.net/calmar-ratio/
 */
double CalculateCalmarRatio(int metric) {
   double totalReturn = stats[metric][S_TRADES_TOTAL_PROFIT];
   if (!totalReturn)    return(0);
   if (totalReturn < 0) return(-1);

   // process trades with updated stats only
   int trades = stats[metric][S_TRADES];
   if (!trades) return(0);

   // annualize total return
   int days = stats[metric][S_DAYS];
   if (days <= 0) return(!catch("CalculateCalmarRatio(1)  illegal value of stats["+ metric +"][S_DAYS]: "+ days +" (must be positive)", ERR_ILLEGAL_STATE));
   double annualizedReturn = totalReturn/days * 365;

   // calculate final ratio
   double drawdown = stats[metric][S_MAX_REL_DRAWDOWN];
   return(MathDiv(annualizedReturn, -drawdown, 99999));                       // 99999: alias for +Infinity
}
