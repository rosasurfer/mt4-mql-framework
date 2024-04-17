/**
 * Update trade statistics.
 *
 *  Profit factor = GrossProfit / GrossLoss
 *  Sharpe ratio  = ReturnPerAnno / TotalVolatility;    TotalVolatility    = StdDeviation(AllReturns)
 *  Sortino ratio = ReturnPerAnno / DownsideVolatility; DownsideVolatility = StdDeviation(NegativeReturns)
 *
 *
 * TODO:
 *  - annualize returns for ratios (255 trading days/year: 365 - 104 Sat/Sun - ~6-non-trading/holidays)
 *  - Calmar ratio = ReturnPerAnno / MaxRelativeDrawdown                  // gain / +max-drawdown
 *  - Z-score
 *  - MaxRecoveryTime
 *  - Zephyr Pain Index: https://investexcel.net/zephyr-pain-index/
 *  - Zephyr K-Ratio:    http://web.archive.org/web/20210116024652/https://www.styleadvisor.com/resources/statfacts/zephyr-k-ratio
 *
 *  @link  https://www.calculator.net/standard-deviation-calculator.html#                                                                           [StdDev calculator with inputs for sample vs. population]
 *  @link  https://www.khanacademy.org/math/statistics-probability/summarizing-quantitative-data/variance-standard-deviation-population/a/calculating-standard-deviation-step-by-step# [Sample vs population]
 */
void CalculateStats() {
   int trades = ArrayRange(history, 0);
   int processedTrades = stats[1][S_TRADES];

   if (!trades || trades < processedTrades) {
      ArrayInitialize(stats, 0);
      processedTrades = 0;
   }

   if (trades > processedTrades) {
      datetime startTime = instance.started;
      datetime endTime   = ifInt(instance.stopped, instance.stopped, Tick.time);
      int workdays = CountWorkdays(startTime, endTime);

      bool prevNetMisWinner, prevNetMisLoser;
      bool prevNetUisWinner, prevNetUisLoser;
      bool prevSigUisWinner, prevSigUisLoser;

      for (int i=processedTrades; i < trades; i++) {              // speed-up by processing only new history entries
         // all metrics: all trades
         if (history[i][H_TYPE] == OP_LONG) {
            stats[METRIC_NET_MONEY][S_TRADES_LONG]++;
            stats[METRIC_NET_UNITS][S_TRADES_LONG]++;
            stats[METRIC_SIG_UNITS][S_TRADES_LONG]++;
         }
         else {
            stats[METRIC_NET_MONEY][S_TRADES_SHORT]++;
            stats[METRIC_NET_UNITS][S_TRADES_SHORT]++;
            stats[METRIC_SIG_UNITS][S_TRADES_SHORT]++;
         }
         stats[METRIC_NET_MONEY][S_TRADES_TOTAL_PROFIT] += history[i][H_NETPROFIT_M];
         stats[METRIC_NET_MONEY][S_TRADES_SUM_RUNUP   ] += history[i][H_RUNUP_P    ];
         stats[METRIC_NET_MONEY][S_TRADES_SUM_DRAWDOWN] += history[i][H_RUNDOWN_P  ];

         stats[METRIC_NET_UNITS][S_TRADES_TOTAL_PROFIT] += history[i][H_NETPROFIT_P];
         stats[METRIC_NET_UNITS][S_TRADES_SUM_RUNUP   ] += history[i][H_RUNUP_P    ];
         stats[METRIC_NET_UNITS][S_TRADES_SUM_DRAWDOWN] += history[i][H_RUNDOWN_P  ];

         stats[METRIC_SIG_UNITS][S_TRADES_TOTAL_PROFIT] += history[i][H_SIG_PROFIT_P ];
         stats[METRIC_SIG_UNITS][S_TRADES_SUM_RUNUP   ] += history[i][H_SIG_RUNUP_P  ];
         stats[METRIC_SIG_UNITS][S_TRADES_SUM_DRAWDOWN] += history[i][H_SIG_RUNDOWN_P];

         // METRIC_NET_MONEY
         if (i == 0) {
            prevNetMisWinner = true;
            prevNetMisLoser = true;
            stats[METRIC_NET_MONEY][S_WINNERS_CUR_CONS_FROM] = INT_MAX;
            stats[METRIC_NET_MONEY][S_LOSERS_CUR_CONS_FROM ] = INT_MAX;
         }
         else if (stats[METRIC_NET_MONEY][S_LAST_TRADE_TYPE] > 0) {
            prevNetMisWinner = true;
            prevNetMisLoser = false;
         }
         else if (stats[METRIC_NET_MONEY][S_LAST_TRADE_TYPE] < 0) {
            prevNetMisWinner = false;
            prevNetMisLoser = true;
         }
         if (history[i][H_NETPROFIT_P] > HalfPoint) {             // compare against H_NETPROFIT_P to simplify scratch limits (to be implemented)
            // winner
            stats[METRIC_NET_MONEY][S_WINNERS]++;
            if (history[i][H_TYPE] == OP_LONG) stats[METRIC_NET_MONEY][S_WINNERS_LONG ]++;
            else                               stats[METRIC_NET_MONEY][S_WINNERS_SHORT]++;
            stats[METRIC_NET_MONEY][S_WINNERS_GROSS_PROFIT] += history[i][H_NETPROFIT_M];
            stats[METRIC_NET_MONEY][S_WINNERS_SUM_RUNUP   ] += history[i][H_RUNUP_P    ];
            stats[METRIC_NET_MONEY][S_WINNERS_SUM_DRAWDOWN] += history[i][H_RUNDOWN_P  ];

            if (prevNetMisLoser) {
               stats[METRIC_NET_MONEY][S_WINNERS_CUR_CONS_COUNT ] = 0;
               stats[METRIC_NET_MONEY][S_WINNERS_CUR_CONS_FROM  ] = INT_MAX;
               stats[METRIC_NET_MONEY][S_WINNERS_CUR_CONS_TO    ] = 0;
               stats[METRIC_NET_MONEY][S_WINNERS_CUR_CONS_PROFIT] = 0;
            }
            stats[METRIC_NET_MONEY][S_WINNERS_CUR_CONS_COUNT ]++;
            stats[METRIC_NET_MONEY][S_WINNERS_CUR_CONS_FROM  ] = MathMin(stats[METRIC_NET_MONEY][S_WINNERS_CUR_CONS_FROM], history[i][H_OPENTIME ]);
            stats[METRIC_NET_MONEY][S_WINNERS_CUR_CONS_TO    ] = MathMax(stats[METRIC_NET_MONEY][S_WINNERS_CUR_CONS_TO  ], history[i][H_CLOSETIME]);
            stats[METRIC_NET_MONEY][S_WINNERS_CUR_CONS_PROFIT] += history[i][H_NETPROFIT_M];

            if (stats[METRIC_NET_MONEY][S_WINNERS_CUR_CONS_COUNT] > stats[METRIC_NET_MONEY][S_WINNERS_MAX_CONS_COUNT]) {
               stats[METRIC_NET_MONEY][S_WINNERS_MAX_CONS_COUNT       ] = stats[METRIC_NET_MONEY][S_WINNERS_CUR_CONS_COUNT ];
               stats[METRIC_NET_MONEY][S_WINNERS_MAX_CONS_COUNT_FROM  ] = stats[METRIC_NET_MONEY][S_WINNERS_CUR_CONS_FROM  ];
               stats[METRIC_NET_MONEY][S_WINNERS_MAX_CONS_COUNT_TO    ] = stats[METRIC_NET_MONEY][S_WINNERS_CUR_CONS_TO    ];
               stats[METRIC_NET_MONEY][S_WINNERS_MAX_CONS_COUNT_PROFIT] = stats[METRIC_NET_MONEY][S_WINNERS_CUR_CONS_PROFIT];
            }
            if (stats[METRIC_NET_MONEY][S_WINNERS_CUR_CONS_PROFIT] > stats[METRIC_NET_MONEY][S_WINNERS_MAX_CONS_PROFIT]) {
               stats[METRIC_NET_MONEY][S_WINNERS_MAX_CONS_PROFIT      ] = stats[METRIC_NET_MONEY][S_WINNERS_CUR_CONS_PROFIT];
               stats[METRIC_NET_MONEY][S_WINNERS_MAX_CONS_PROFIT_FROM ] = stats[METRIC_NET_MONEY][S_WINNERS_CUR_CONS_FROM  ];
               stats[METRIC_NET_MONEY][S_WINNERS_MAX_CONS_PROFIT_TO   ] = stats[METRIC_NET_MONEY][S_WINNERS_CUR_CONS_TO    ];
               stats[METRIC_NET_MONEY][S_WINNERS_MAX_CONS_PROFIT_COUNT] = stats[METRIC_NET_MONEY][S_WINNERS_CUR_CONS_COUNT ];
            }
            stats[METRIC_NET_MONEY][S_LAST_TRADE_TYPE] = 1;
         }
         else if (history[i][H_NETPROFIT_P] < -HalfPoint) {
            // loser
            stats[METRIC_NET_MONEY][S_LOSERS]++;
            if (history[i][H_TYPE] == OP_LONG) stats[METRIC_NET_MONEY][S_LOSERS_LONG ]++;
            else                               stats[METRIC_NET_MONEY][S_LOSERS_SHORT]++;
            stats[METRIC_NET_MONEY][S_LOSERS_GROSS_LOSS  ] += history[i][H_NETPROFIT_M];
            stats[METRIC_NET_MONEY][S_LOSERS_SUM_RUNUP   ] += history[i][H_RUNUP_P    ];
            stats[METRIC_NET_MONEY][S_LOSERS_SUM_DRAWDOWN] += history[i][H_RUNDOWN_P  ];

            if (prevNetMisWinner) {
               stats[METRIC_NET_MONEY][S_LOSERS_CUR_CONS_COUNT] = 0;
               stats[METRIC_NET_MONEY][S_LOSERS_CUR_CONS_FROM ] = INT_MAX;
               stats[METRIC_NET_MONEY][S_LOSERS_CUR_CONS_TO   ] = 0;
               stats[METRIC_NET_MONEY][S_LOSERS_CUR_CONS_LOSS ] = 0;
            }
            stats[METRIC_NET_MONEY][S_LOSERS_CUR_CONS_COUNT]++;
            stats[METRIC_NET_MONEY][S_LOSERS_CUR_CONS_FROM ] = MathMin(stats[METRIC_NET_MONEY][S_LOSERS_CUR_CONS_FROM], history[i][H_OPENTIME ]);
            stats[METRIC_NET_MONEY][S_LOSERS_CUR_CONS_TO   ] = MathMax(stats[METRIC_NET_MONEY][S_LOSERS_CUR_CONS_TO  ], history[i][H_CLOSETIME]);
            stats[METRIC_NET_MONEY][S_LOSERS_CUR_CONS_LOSS ] += history[i][H_NETPROFIT_M];

            if (stats[METRIC_NET_MONEY][S_LOSERS_CUR_CONS_COUNT] > stats[METRIC_NET_MONEY][S_LOSERS_MAX_CONS_COUNT]) {
               stats[METRIC_NET_MONEY][S_LOSERS_MAX_CONS_COUNT     ] = stats[METRIC_NET_MONEY][S_LOSERS_CUR_CONS_COUNT];
               stats[METRIC_NET_MONEY][S_LOSERS_MAX_CONS_COUNT_FROM] = stats[METRIC_NET_MONEY][S_LOSERS_CUR_CONS_FROM ];
               stats[METRIC_NET_MONEY][S_LOSERS_MAX_CONS_COUNT_TO  ] = stats[METRIC_NET_MONEY][S_LOSERS_CUR_CONS_TO   ];
               stats[METRIC_NET_MONEY][S_LOSERS_MAX_CONS_COUNT_LOSS] = stats[METRIC_NET_MONEY][S_LOSERS_CUR_CONS_LOSS ];
            }
            if (stats[METRIC_NET_MONEY][S_LOSERS_CUR_CONS_LOSS] < stats[METRIC_NET_MONEY][S_LOSERS_MAX_CONS_LOSS]) {
               stats[METRIC_NET_MONEY][S_LOSERS_MAX_CONS_LOSS      ] = stats[METRIC_NET_MONEY][S_LOSERS_CUR_CONS_LOSS ];
               stats[METRIC_NET_MONEY][S_LOSERS_MAX_CONS_LOSS_FROM ] = stats[METRIC_NET_MONEY][S_LOSERS_CUR_CONS_FROM ];
               stats[METRIC_NET_MONEY][S_LOSERS_MAX_CONS_LOSS_TO   ] = stats[METRIC_NET_MONEY][S_LOSERS_CUR_CONS_TO   ];
               stats[METRIC_NET_MONEY][S_LOSERS_MAX_CONS_LOSS_COUNT] = stats[METRIC_NET_MONEY][S_LOSERS_CUR_CONS_COUNT];
            }
            stats[METRIC_NET_MONEY][S_LAST_TRADE_TYPE] = -1;
         }
         else {
            // scratch
            stats[METRIC_NET_MONEY][S_SCRATCH]++;
            if (history[i][H_TYPE] == OP_LONG) stats[METRIC_NET_MONEY][S_SCRATCH_LONG ]++;
            else                               stats[METRIC_NET_MONEY][S_SCRATCH_SHORT]++;
            stats[METRIC_NET_MONEY][S_LAST_TRADE_TYPE] = 0;
         }

         // METRIC_NET_UNITS
         if (i == 0) {
            prevNetUisWinner = true;
            prevNetUisLoser = true;
            stats[METRIC_NET_UNITS][S_WINNERS_CUR_CONS_FROM] = INT_MAX;
            stats[METRIC_NET_UNITS][S_LOSERS_CUR_CONS_FROM ] = INT_MAX;
         }
         else if (stats[METRIC_NET_UNITS][S_LAST_TRADE_TYPE] > 0) {
            prevNetUisWinner = true;
            prevNetUisLoser = false;
         }
         else if (stats[METRIC_NET_UNITS][S_LAST_TRADE_TYPE] < 0) {
            prevNetUisWinner = false;
            prevNetUisLoser = true;
         }
         if (history[i][H_NETPROFIT_P] > HalfPoint) {
            // winner
            stats[METRIC_NET_UNITS][S_WINNERS]++;
            if (history[i][H_TYPE] == OP_LONG) stats[METRIC_NET_UNITS][S_WINNERS_LONG ]++;
            else                               stats[METRIC_NET_UNITS][S_WINNERS_SHORT]++;
            stats[METRIC_NET_UNITS][S_WINNERS_GROSS_PROFIT] += history[i][H_NETPROFIT_P];
            stats[METRIC_NET_UNITS][S_WINNERS_SUM_RUNUP   ] += history[i][H_RUNUP_P    ];
            stats[METRIC_NET_UNITS][S_WINNERS_SUM_DRAWDOWN] += history[i][H_RUNDOWN_P  ];

            if (prevNetUisLoser) {
               stats[METRIC_NET_UNITS][S_WINNERS_CUR_CONS_COUNT ] = 0;
               stats[METRIC_NET_UNITS][S_WINNERS_CUR_CONS_FROM  ] = INT_MAX;
               stats[METRIC_NET_UNITS][S_WINNERS_CUR_CONS_TO    ] = 0;
               stats[METRIC_NET_UNITS][S_WINNERS_CUR_CONS_PROFIT] = 0;
            }
            stats[METRIC_NET_UNITS][S_WINNERS_CUR_CONS_COUNT ]++;
            stats[METRIC_NET_UNITS][S_WINNERS_CUR_CONS_FROM  ] = MathMin(stats[METRIC_NET_UNITS][S_WINNERS_CUR_CONS_FROM], history[i][H_OPENTIME ]);
            stats[METRIC_NET_UNITS][S_WINNERS_CUR_CONS_TO    ] = MathMax(stats[METRIC_NET_UNITS][S_WINNERS_CUR_CONS_TO  ], history[i][H_CLOSETIME]);
            stats[METRIC_NET_UNITS][S_WINNERS_CUR_CONS_PROFIT] += history[i][H_NETPROFIT_P];

            if (stats[METRIC_NET_UNITS][S_WINNERS_CUR_CONS_COUNT] > stats[METRIC_NET_UNITS][S_WINNERS_MAX_CONS_COUNT]) {
               stats[METRIC_NET_UNITS][S_WINNERS_MAX_CONS_COUNT       ] = stats[METRIC_NET_UNITS][S_WINNERS_CUR_CONS_COUNT ];
               stats[METRIC_NET_UNITS][S_WINNERS_MAX_CONS_COUNT_FROM  ] = stats[METRIC_NET_UNITS][S_WINNERS_CUR_CONS_FROM  ];
               stats[METRIC_NET_UNITS][S_WINNERS_MAX_CONS_COUNT_TO    ] = stats[METRIC_NET_UNITS][S_WINNERS_CUR_CONS_TO    ];
               stats[METRIC_NET_UNITS][S_WINNERS_MAX_CONS_COUNT_PROFIT] = stats[METRIC_NET_UNITS][S_WINNERS_CUR_CONS_PROFIT];
            }
            if (stats[METRIC_NET_UNITS][S_WINNERS_CUR_CONS_PROFIT] > stats[METRIC_NET_UNITS][S_WINNERS_MAX_CONS_PROFIT]) {
               stats[METRIC_NET_UNITS][S_WINNERS_MAX_CONS_PROFIT      ] = stats[METRIC_NET_UNITS][S_WINNERS_CUR_CONS_PROFIT];
               stats[METRIC_NET_UNITS][S_WINNERS_MAX_CONS_PROFIT_FROM ] = stats[METRIC_NET_UNITS][S_WINNERS_CUR_CONS_FROM  ];
               stats[METRIC_NET_UNITS][S_WINNERS_MAX_CONS_PROFIT_TO   ] = stats[METRIC_NET_UNITS][S_WINNERS_CUR_CONS_TO    ];
               stats[METRIC_NET_UNITS][S_WINNERS_MAX_CONS_PROFIT_COUNT] = stats[METRIC_NET_UNITS][S_WINNERS_CUR_CONS_COUNT ];
            }
            stats[METRIC_NET_UNITS][S_LAST_TRADE_TYPE] = 1;
         }
         else if (history[i][H_NETPROFIT_P] < -HalfPoint) {
            // loser
            stats[METRIC_NET_UNITS][S_LOSERS]++;
            if (history[i][H_TYPE] == OP_LONG) stats[METRIC_NET_UNITS][S_LOSERS_LONG ]++;
            else                               stats[METRIC_NET_UNITS][S_LOSERS_SHORT]++;
            stats[METRIC_NET_UNITS][S_LOSERS_GROSS_LOSS  ] += history[i][H_NETPROFIT_P];
            stats[METRIC_NET_UNITS][S_LOSERS_SUM_RUNUP   ] += history[i][H_RUNUP_P    ];
            stats[METRIC_NET_UNITS][S_LOSERS_SUM_DRAWDOWN] += history[i][H_RUNDOWN_P  ];

            if (prevNetUisWinner) {
               stats[METRIC_NET_UNITS][S_LOSERS_CUR_CONS_COUNT] = 0;
               stats[METRIC_NET_UNITS][S_LOSERS_CUR_CONS_FROM ] = INT_MAX;
               stats[METRIC_NET_UNITS][S_LOSERS_CUR_CONS_TO   ] = 0;
               stats[METRIC_NET_UNITS][S_LOSERS_CUR_CONS_LOSS ] = 0;
            }
            stats[METRIC_NET_UNITS][S_LOSERS_CUR_CONS_COUNT]++;
            stats[METRIC_NET_UNITS][S_LOSERS_CUR_CONS_FROM ] = MathMin(stats[METRIC_NET_UNITS][S_LOSERS_CUR_CONS_FROM], history[i][H_OPENTIME ]);
            stats[METRIC_NET_UNITS][S_LOSERS_CUR_CONS_TO   ] = MathMax(stats[METRIC_NET_UNITS][S_LOSERS_CUR_CONS_TO  ], history[i][H_CLOSETIME]);
            stats[METRIC_NET_UNITS][S_LOSERS_CUR_CONS_LOSS ] += history[i][H_NETPROFIT_P];

            if (stats[METRIC_NET_UNITS][S_LOSERS_CUR_CONS_COUNT] > stats[METRIC_NET_UNITS][S_LOSERS_MAX_CONS_COUNT]) {
               stats[METRIC_NET_UNITS][S_LOSERS_MAX_CONS_COUNT     ] = stats[METRIC_NET_UNITS][S_LOSERS_CUR_CONS_COUNT];
               stats[METRIC_NET_UNITS][S_LOSERS_MAX_CONS_COUNT_FROM] = stats[METRIC_NET_UNITS][S_LOSERS_CUR_CONS_FROM ];
               stats[METRIC_NET_UNITS][S_LOSERS_MAX_CONS_COUNT_TO  ] = stats[METRIC_NET_UNITS][S_LOSERS_CUR_CONS_TO   ];
               stats[METRIC_NET_UNITS][S_LOSERS_MAX_CONS_COUNT_LOSS] = stats[METRIC_NET_UNITS][S_LOSERS_CUR_CONS_LOSS ];
            }
            if (stats[METRIC_NET_UNITS][S_LOSERS_CUR_CONS_LOSS] < stats[METRIC_NET_UNITS][S_LOSERS_MAX_CONS_LOSS]) {
               stats[METRIC_NET_UNITS][S_LOSERS_MAX_CONS_LOSS      ] = stats[METRIC_NET_UNITS][S_LOSERS_CUR_CONS_LOSS ];
               stats[METRIC_NET_UNITS][S_LOSERS_MAX_CONS_LOSS_FROM ] = stats[METRIC_NET_UNITS][S_LOSERS_CUR_CONS_FROM ];
               stats[METRIC_NET_UNITS][S_LOSERS_MAX_CONS_LOSS_TO   ] = stats[METRIC_NET_UNITS][S_LOSERS_CUR_CONS_TO   ];
               stats[METRIC_NET_UNITS][S_LOSERS_MAX_CONS_LOSS_COUNT] = stats[METRIC_NET_UNITS][S_LOSERS_CUR_CONS_COUNT];
            }
            stats[METRIC_NET_UNITS][S_LAST_TRADE_TYPE] = -1;
         }
         else {
            // scratch
            stats[METRIC_NET_UNITS][S_SCRATCH]++;
            if (history[i][H_TYPE] == OP_LONG) stats[METRIC_NET_UNITS][S_SCRATCH_LONG ]++;
            else                               stats[METRIC_NET_UNITS][S_SCRATCH_SHORT]++;
            stats[METRIC_NET_UNITS][S_LAST_TRADE_TYPE] = 0;
         }

         // METRIC_SIG_UNITS
         if (i == 0) {
            prevSigUisWinner = true;
            prevSigUisLoser = true;
            stats[METRIC_SIG_UNITS][S_WINNERS_CUR_CONS_FROM] = INT_MAX;
            stats[METRIC_SIG_UNITS][S_LOSERS_CUR_CONS_FROM ] = INT_MAX;
         }
         else if (stats[METRIC_SIG_UNITS][S_LAST_TRADE_TYPE] > 0) {
            prevSigUisWinner = true;
            prevSigUisLoser = false;
         }
         else if (stats[METRIC_SIG_UNITS][S_LAST_TRADE_TYPE] < 0) {
            prevSigUisWinner = false;
            prevSigUisLoser = true;
         }
         if (history[i][H_SIG_PROFIT_P] > HalfPoint) {
            // winner
            stats[METRIC_SIG_UNITS][S_WINNERS]++;
            if (history[i][H_TYPE] == OP_LONG) stats[METRIC_SIG_UNITS][S_WINNERS_LONG ]++;
            else                               stats[METRIC_SIG_UNITS][S_WINNERS_SHORT]++;
            stats[METRIC_SIG_UNITS][S_WINNERS_GROSS_PROFIT] += history[i][H_SIG_PROFIT_P ];
            stats[METRIC_SIG_UNITS][S_WINNERS_SUM_RUNUP   ] += history[i][H_SIG_RUNUP_P  ];
            stats[METRIC_SIG_UNITS][S_WINNERS_SUM_DRAWDOWN] += history[i][H_SIG_RUNDOWN_P];

            if (prevSigUisLoser) {
               stats[METRIC_SIG_UNITS][S_WINNERS_CUR_CONS_COUNT ] = 0;
               stats[METRIC_SIG_UNITS][S_WINNERS_CUR_CONS_FROM  ] = INT_MAX;
               stats[METRIC_SIG_UNITS][S_WINNERS_CUR_CONS_TO    ] = 0;
               stats[METRIC_SIG_UNITS][S_WINNERS_CUR_CONS_PROFIT] = 0;
            }
            stats[METRIC_SIG_UNITS][S_WINNERS_CUR_CONS_COUNT ]++;
            stats[METRIC_SIG_UNITS][S_WINNERS_CUR_CONS_FROM  ] = MathMin(stats[METRIC_SIG_UNITS][S_WINNERS_CUR_CONS_FROM], history[i][H_OPENTIME ]);
            stats[METRIC_SIG_UNITS][S_WINNERS_CUR_CONS_TO    ] = MathMax(stats[METRIC_SIG_UNITS][S_WINNERS_CUR_CONS_TO  ], history[i][H_CLOSETIME]);
            stats[METRIC_SIG_UNITS][S_WINNERS_CUR_CONS_PROFIT] += history[i][H_SIG_PROFIT_P];

            if (stats[METRIC_SIG_UNITS][S_WINNERS_CUR_CONS_COUNT] > stats[METRIC_SIG_UNITS][S_WINNERS_MAX_CONS_COUNT]) {
               stats[METRIC_SIG_UNITS][S_WINNERS_MAX_CONS_COUNT       ] = stats[METRIC_SIG_UNITS][S_WINNERS_CUR_CONS_COUNT ];
               stats[METRIC_SIG_UNITS][S_WINNERS_MAX_CONS_COUNT_FROM  ] = stats[METRIC_SIG_UNITS][S_WINNERS_CUR_CONS_FROM  ];
               stats[METRIC_SIG_UNITS][S_WINNERS_MAX_CONS_COUNT_TO    ] = stats[METRIC_SIG_UNITS][S_WINNERS_CUR_CONS_TO    ];
               stats[METRIC_SIG_UNITS][S_WINNERS_MAX_CONS_COUNT_PROFIT] = stats[METRIC_SIG_UNITS][S_WINNERS_CUR_CONS_PROFIT];
            }
            if (stats[METRIC_SIG_UNITS][S_WINNERS_CUR_CONS_PROFIT] > stats[METRIC_SIG_UNITS][S_WINNERS_MAX_CONS_PROFIT]) {
               stats[METRIC_SIG_UNITS][S_WINNERS_MAX_CONS_PROFIT      ] = stats[METRIC_SIG_UNITS][S_WINNERS_CUR_CONS_PROFIT];
               stats[METRIC_SIG_UNITS][S_WINNERS_MAX_CONS_PROFIT_FROM ] = stats[METRIC_SIG_UNITS][S_WINNERS_CUR_CONS_FROM  ];
               stats[METRIC_SIG_UNITS][S_WINNERS_MAX_CONS_PROFIT_TO   ] = stats[METRIC_SIG_UNITS][S_WINNERS_CUR_CONS_TO    ];
               stats[METRIC_SIG_UNITS][S_WINNERS_MAX_CONS_PROFIT_COUNT] = stats[METRIC_SIG_UNITS][S_WINNERS_CUR_CONS_COUNT ];
            }
            stats[METRIC_SIG_UNITS][S_LAST_TRADE_TYPE] = 1;
         }
         else if (history[i][H_SIG_PROFIT_P] < -HalfPoint) {
            // loser
            stats[METRIC_SIG_UNITS][S_LOSERS]++;
            if (history[i][H_TYPE] == OP_LONG) stats[METRIC_SIG_UNITS][S_LOSERS_LONG ]++;
            else                               stats[METRIC_SIG_UNITS][S_LOSERS_SHORT]++;
            stats[METRIC_SIG_UNITS][S_LOSERS_GROSS_LOSS  ] += history[i][H_SIG_PROFIT_P ];
            stats[METRIC_SIG_UNITS][S_LOSERS_SUM_RUNUP   ] += history[i][H_SIG_RUNUP_P  ];
            stats[METRIC_SIG_UNITS][S_LOSERS_SUM_DRAWDOWN] += history[i][H_SIG_RUNDOWN_P];

            if (prevSigUisWinner) {
               stats[METRIC_SIG_UNITS][S_LOSERS_CUR_CONS_COUNT] = 0;
               stats[METRIC_SIG_UNITS][S_LOSERS_CUR_CONS_FROM ] = INT_MAX;
               stats[METRIC_SIG_UNITS][S_LOSERS_CUR_CONS_TO   ] = 0;
               stats[METRIC_SIG_UNITS][S_LOSERS_CUR_CONS_LOSS ] = 0;
            }
            stats[METRIC_SIG_UNITS][S_LOSERS_CUR_CONS_COUNT]++;
            stats[METRIC_SIG_UNITS][S_LOSERS_CUR_CONS_FROM ] = MathMin(stats[METRIC_SIG_UNITS][S_LOSERS_CUR_CONS_FROM], history[i][H_OPENTIME ]);
            stats[METRIC_SIG_UNITS][S_LOSERS_CUR_CONS_TO   ] = MathMax(stats[METRIC_SIG_UNITS][S_LOSERS_CUR_CONS_TO  ], history[i][H_CLOSETIME]);
            stats[METRIC_SIG_UNITS][S_LOSERS_CUR_CONS_LOSS ] += history[i][H_SIG_PROFIT_P];

            if (stats[METRIC_SIG_UNITS][S_LOSERS_CUR_CONS_COUNT] > stats[METRIC_SIG_UNITS][S_LOSERS_MAX_CONS_COUNT]) {
               stats[METRIC_SIG_UNITS][S_LOSERS_MAX_CONS_COUNT     ] = stats[METRIC_SIG_UNITS][S_LOSERS_CUR_CONS_COUNT];
               stats[METRIC_SIG_UNITS][S_LOSERS_MAX_CONS_COUNT_FROM] = stats[METRIC_SIG_UNITS][S_LOSERS_CUR_CONS_FROM ];
               stats[METRIC_SIG_UNITS][S_LOSERS_MAX_CONS_COUNT_TO  ] = stats[METRIC_SIG_UNITS][S_LOSERS_CUR_CONS_TO   ];
               stats[METRIC_SIG_UNITS][S_LOSERS_MAX_CONS_COUNT_LOSS] = stats[METRIC_SIG_UNITS][S_LOSERS_CUR_CONS_LOSS ];
            }
            if (stats[METRIC_SIG_UNITS][S_LOSERS_CUR_CONS_LOSS] < stats[METRIC_SIG_UNITS][S_LOSERS_MAX_CONS_LOSS]) {
               stats[METRIC_SIG_UNITS][S_LOSERS_MAX_CONS_LOSS      ] = stats[METRIC_SIG_UNITS][S_LOSERS_CUR_CONS_LOSS ];
               stats[METRIC_SIG_UNITS][S_LOSERS_MAX_CONS_LOSS_FROM ] = stats[METRIC_SIG_UNITS][S_LOSERS_CUR_CONS_FROM ];
               stats[METRIC_SIG_UNITS][S_LOSERS_MAX_CONS_LOSS_TO   ] = stats[METRIC_SIG_UNITS][S_LOSERS_CUR_CONS_TO   ];
               stats[METRIC_SIG_UNITS][S_LOSERS_MAX_CONS_LOSS_COUNT] = stats[METRIC_SIG_UNITS][S_LOSERS_CUR_CONS_COUNT];
            }
            stats[METRIC_SIG_UNITS][S_LAST_TRADE_TYPE] = -1;
         }
         else {
            // scratch
            stats[METRIC_SIG_UNITS][S_SCRATCH]++;
            if (history[i][H_TYPE] == OP_LONG) stats[METRIC_SIG_UNITS][S_SCRATCH_LONG ]++;
            else                               stats[METRIC_SIG_UNITS][S_SCRATCH_SHORT]++;
            stats[METRIC_SIG_UNITS][S_LAST_TRADE_TYPE] = 0;
         }
      }

      // percentages, averages and performance ratios
      int metrics = ArrayRange(stats, 0);
      for (i=1; i < metrics; i++) {                 // skip unused metric/index 0
         stats[i][S_TRADES  ] = trades;
         stats[i][S_WORKDAYS] = workdays;           // used to annualize returns

         stats[i][S_TRADES_LONG_PCT     ] =         MathDiv(stats[i][S_TRADES_LONG         ], stats[i][S_TRADES ]);
         stats[i][S_TRADES_SHORT_PCT    ] =         MathDiv(stats[i][S_TRADES_SHORT        ], stats[i][S_TRADES ]);
         stats[i][S_WINNERS_PCT         ] =         MathDiv(stats[i][S_WINNERS             ], stats[i][S_TRADES ]);
         stats[i][S_WINNERS_LONG_PCT    ] =         MathDiv(stats[i][S_WINNERS_LONG        ], stats[i][S_WINNERS]);
         stats[i][S_WINNERS_SHORT_PCT   ] =         MathDiv(stats[i][S_WINNERS_SHORT       ], stats[i][S_WINNERS]);
         stats[i][S_LOSERS_PCT          ] =         MathDiv(stats[i][S_LOSERS              ], stats[i][S_TRADES ]);
         stats[i][S_LOSERS_LONG_PCT     ] =         MathDiv(stats[i][S_LOSERS_LONG         ], stats[i][S_LOSERS ]);
         stats[i][S_LOSERS_SHORT_PCT    ] =         MathDiv(stats[i][S_LOSERS_SHORT        ], stats[i][S_LOSERS ]);
         stats[i][S_SCRATCH_PCT         ] =         MathDiv(stats[i][S_SCRATCH             ], stats[i][S_TRADES ]);
         stats[i][S_SCRATCH_LONG_PCT    ] =         MathDiv(stats[i][S_SCRATCH_LONG        ], stats[i][S_SCRATCH]);
         stats[i][S_SCRATCH_SHORT_PCT   ] =         MathDiv(stats[i][S_SCRATCH_SHORT       ], stats[i][S_SCRATCH]);

         stats[i][S_TRADES_AVG_PROFIT   ] =         MathDiv(stats[i][S_TRADES_TOTAL_PROFIT ], stats[i][S_TRADES ]);
         stats[i][S_TRADES_AVG_RUNUP    ] =         MathDiv(stats[i][S_TRADES_SUM_RUNUP    ], stats[i][S_TRADES ]);
         stats[i][S_TRADES_AVG_DRAWDOWN ] =         MathDiv(stats[i][S_TRADES_SUM_DRAWDOWN ], stats[i][S_TRADES ]);
         stats[i][S_TRADES_PROFIT_FACTOR] = MathAbs(MathDiv(stats[i][S_WINNERS_GROSS_PROFIT], stats[i][S_LOSERS_GROSS_LOSS], INT_MAX));   // w/o losers: INT_MAX

         stats[i][S_WINNERS_AVG_PROFIT  ] =         MathDiv(stats[i][S_WINNERS_GROSS_PROFIT], stats[i][S_WINNERS]);
         stats[i][S_WINNERS_AVG_RUNUP   ] =         MathDiv(stats[i][S_WINNERS_SUM_RUNUP   ], stats[i][S_WINNERS]);
         stats[i][S_WINNERS_AVG_DRAWDOWN] =         MathDiv(stats[i][S_WINNERS_SUM_DRAWDOWN], stats[i][S_WINNERS]);

         stats[i][S_LOSERS_AVG_LOSS     ] =         MathDiv(stats[i][S_LOSERS_GROSS_LOSS   ], stats[i][S_LOSERS ]);
         stats[i][S_LOSERS_AVG_RUNUP    ] =         MathDiv(stats[i][S_LOSERS_SUM_RUNUP    ], stats[i][S_LOSERS ]);
         stats[i][S_LOSERS_AVG_DRAWDOWN ] =         MathDiv(stats[i][S_LOSERS_SUM_DRAWDOWN ], stats[i][S_LOSERS ]);

         stats[i][S_TRADES_SHARPE_RATIO ] = CalculateSharpeRatio(i);
         stats[i][S_TRADES_SORTINO_RATIO] = CalculateSortinoRatio(i);
      }
   }
}


/**
 * Calculate the annualized Sharpe ratio for the specified metric.
 *
 *  Sharpe ratio = ReturnPerAnno / TotalVolatility
 *  TotalVolatility = StdDeviation(AllReturns)
 *
 * @param  int metric - metric id
 *
 * @return double - positive ratio or -1 if the strategy is not profitable; NULL in case of errors
 */
double CalculateSharpeRatio(int metric) {
   double totalProfit = stats[metric][S_TRADES_TOTAL_PROFIT];
   if (totalProfit < 0) return(-1);

   // process trades with updated stats only
   int trades = stats[metric][S_TRADES];
   if (!trades) return(0);
   if (trades > ArrayRange(history, 0)) return(!catch("CalculateSharpeRatio(1)  illegal value stats["+ metric +"][S_TRADES]: "+ trades +" (out-of-range)", ERR_ILLEGAL_STATE));

   // annualize total profit
   int workdays = stats[metric][S_WORKDAYS];
   if (workdays <= 0)                   return(!catch("CalculateSharpeRatio(2)  illegal value stats["+ metric +"][S_WORKDAYS]: "+ workdays +" (out-of-range)", ERR_ILLEGAL_STATE));
   double annualizedProfit = totalProfit/workdays * 255;          // avg. number of trading days: 365 - 52*2 - 6 Holidays

   // prepare dataset for iStdDevOnArray()
   double profits[];
   ArrayResize(profits, trades);
   int profitFields[] = {0, H_NETPROFIT_M, H_NETPROFIT_P, H_SIG_PROFIT_P}, iProfit=profitFields[metric];
   for (int i=0; i < trades; i++) {
      profits[i] = history[i][iProfit];
   }

   // calculate stdDeviation and final ratio
   double stdDev = iStdDevOnArray(profits, WHOLE_ARRAY, trades, 0, MODE_SMA, 0);
   double ratio = NormalizeDouble(annualizedProfit/stdDev, 2);

   ArrayResize(profits, 0);
   return(ratio);
}


/**
 * Calculate the annualized Sortino ratio for the specified metric.
 *
 *  Sortino ratio = ReturnPerAnno / DownsideVolatility
 *  DownsideVolatility = StdDeviation(NegativeReturns)
 *
 * @param  int metric - metric id
 *
 * @return double - positive ratio or -1 if the strategy is not profitable; NULL in case of errors
 */
double CalculateSortinoRatio(int metric) {
   double totalProfit = stats[metric][S_TRADES_TOTAL_PROFIT];
   if (totalProfit < 0) return(-1);

   // process trades with updated stats only
   int trades = stats[metric][S_TRADES];
   if (!trades) return(0);
   if (trades > ArrayRange(history, 0)) return(!catch("CalculateSortinoRatio(1)  illegal value stats["+ metric +"][S_TRADES]: "+ trades +" (out-of-range)", ERR_ILLEGAL_STATE));

   // annualize total profit
   int workdays = stats[metric][S_WORKDAYS];
   if (workdays <= 0)                   return(!catch("CalculateSortinoRatio(2)  illegal value stats["+ metric +"][S_WORKDAYS]: "+ workdays +" (out-of-range)", ERR_ILLEGAL_STATE));
   double annualizedProfit = totalProfit/workdays * 255;          // avg. number of trading days: 365 - 52*2 - 6 Holidays

   // prepare dataset for iStdDevOnArray()
   double profits[];
   ArrayResize(profits, trades);
   int cmpFields   [] = {0, H_NETPROFIT_P, H_NETPROFIT_P, H_SIG_PROFIT_P}, iCmpField=cmpFields[metric];
   int profitFields[] = {0, H_NETPROFIT_M, H_NETPROFIT_P, H_SIG_PROFIT_P}, iProfit=profitFields[metric], n=0;
   for (int i=0; i < trades; i++) {
      if (history[i][iCmpField] < -HalfPoint) {
         profits[n] = history[i][iProfit];
         n++;
      }
   }
   ArrayResize(profits, n);

   // calculate stdDeviation and final ratio
   double stdDev = iStdDevOnArray(profits, WHOLE_ARRAY, n, 0, MODE_SMA, 0);
   double ratio = NormalizeDouble(annualizedProfit/stdDev, 2);

   ArrayResize(profits, 0);
   return(ratio);
}
