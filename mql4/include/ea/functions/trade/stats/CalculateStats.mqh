/**
 * Update trade statistics.
 */
void CalculateStats() {
   int trades = ArrayRange(history, 0);
   int processedTrades = stats[1][S_TRADES];

   if (!trades || trades < processedTrades) {
      ArrayInitialize(stats, 0);
      processedTrades = 0;
   }

   if (trades > processedTrades) {
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
         else if (stats[METRIC_NET_MONEY][S_TRADES_LAST_TRADE_RESULT] > 0) {
            prevNetMisWinner = true;
            prevNetMisLoser = false;
         }
         else if (stats[METRIC_NET_MONEY][S_TRADES_LAST_TRADE_RESULT] < 0) {
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
            stats[METRIC_NET_MONEY][S_TRADES_LAST_TRADE_RESULT] = 1;
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
            stats[METRIC_NET_MONEY][S_TRADES_LAST_TRADE_RESULT] = -1;
         }
         else {
            // scratch
            stats[METRIC_NET_MONEY][S_SCRATCH]++;
            if (history[i][H_TYPE] == OP_LONG) stats[METRIC_NET_MONEY][S_SCRATCH_LONG ]++;
            else                               stats[METRIC_NET_MONEY][S_SCRATCH_SHORT]++;
            stats[METRIC_NET_MONEY][S_TRADES_LAST_TRADE_RESULT] = 0;
         }

         // METRIC_NET_UNITS
         if (i == 0) {
            prevNetUisWinner = true;
            prevNetUisLoser = true;
            stats[METRIC_NET_UNITS][S_WINNERS_CUR_CONS_FROM] = INT_MAX;
            stats[METRIC_NET_UNITS][S_LOSERS_CUR_CONS_FROM ] = INT_MAX;
         }
         else if (stats[METRIC_NET_UNITS][S_TRADES_LAST_TRADE_RESULT] > 0) {
            prevNetUisWinner = true;
            prevNetUisLoser = false;
         }
         else if (stats[METRIC_NET_UNITS][S_TRADES_LAST_TRADE_RESULT] < 0) {
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
            stats[METRIC_NET_UNITS][S_TRADES_LAST_TRADE_RESULT] = 1;
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
            stats[METRIC_NET_UNITS][S_TRADES_LAST_TRADE_RESULT] = -1;
         }
         else {
            // scratch
            stats[METRIC_NET_UNITS][S_SCRATCH]++;
            if (history[i][H_TYPE] == OP_LONG) stats[METRIC_NET_UNITS][S_SCRATCH_LONG ]++;
            else                               stats[METRIC_NET_UNITS][S_SCRATCH_SHORT]++;
            stats[METRIC_NET_UNITS][S_TRADES_LAST_TRADE_RESULT] = 0;
         }

         // METRIC_SIG_UNITS
         if (i == 0) {
            prevSigUisWinner = true;
            prevSigUisLoser = true;
            stats[METRIC_SIG_UNITS][S_WINNERS_CUR_CONS_FROM] = INT_MAX;
            stats[METRIC_SIG_UNITS][S_LOSERS_CUR_CONS_FROM ] = INT_MAX;
         }
         else if (stats[METRIC_SIG_UNITS][S_TRADES_LAST_TRADE_RESULT] > 0) {
            prevSigUisWinner = true;
            prevSigUisLoser = false;
         }
         else if (stats[METRIC_SIG_UNITS][S_TRADES_LAST_TRADE_RESULT] < 0) {
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
            stats[METRIC_SIG_UNITS][S_TRADES_LAST_TRADE_RESULT] = 1;
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
            stats[METRIC_SIG_UNITS][S_TRADES_LAST_TRADE_RESULT] = -1;
         }
         else {
            // scratch
            stats[METRIC_SIG_UNITS][S_SCRATCH]++;
            if (history[i][H_TYPE] == OP_LONG) stats[METRIC_SIG_UNITS][S_SCRATCH_LONG ]++;
            else                               stats[METRIC_SIG_UNITS][S_SCRATCH_SHORT]++;
            stats[METRIC_SIG_UNITS][S_TRADES_LAST_TRADE_RESULT] = 0;
         }
      }

      // percentages and averages
      for (i=ArrayRange(stats, 0)-1; i > 0; i--) {                // skip unused index 0
         stats[i][S_TRADES] = trades;

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
      }
   }
}
