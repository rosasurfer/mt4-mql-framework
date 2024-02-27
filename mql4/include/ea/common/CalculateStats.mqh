/**
 * Update trade statistics.
 */
void CalculateStats() {
   int trades = ArrayRange(history, 0);
   int prevTrades = stats[1][S_TRADES];

   if (!trades || trades < prevTrades) {
      ArrayInitialize(stats, 0);
      prevTrades = 0;
   }

   if (trades > prevTrades) {
      for (int i=prevTrades; i < trades; i++) {                   // speed-up by processing only new history entries
         // all metrics: all trades
         if (history[i][H_TYPE] == OP_LONG) {
            stats[METRIC_TOTAL_NET_MONEY  ][S_TRADES_LONG]++;
            stats[METRIC_TOTAL_NET_UNITS  ][S_TRADES_LONG]++;
            stats[METRIC_TOTAL_SYNTH_UNITS][S_TRADES_LONG]++;
         }
         else {
            stats[METRIC_TOTAL_NET_MONEY  ][S_TRADES_SHORT]++;
            stats[METRIC_TOTAL_NET_UNITS  ][S_TRADES_SHORT]++;
            stats[METRIC_TOTAL_SYNTH_UNITS][S_TRADES_SHORT]++;
         }
         stats[METRIC_TOTAL_NET_MONEY  ][S_TRADES_SUM_RUNUP   ] += history[i][H_RUNUP_P   ];
         stats[METRIC_TOTAL_NET_MONEY  ][S_TRADES_SUM_DRAWDOWN] += history[i][H_DRAWDOWN_P];
         stats[METRIC_TOTAL_NET_MONEY  ][S_TRADES_SUM_PROFIT  ] += history[i][H_NETPROFIT ];

         stats[METRIC_TOTAL_NET_UNITS  ][S_TRADES_SUM_RUNUP   ] += history[i][H_RUNUP_P    ];
         stats[METRIC_TOTAL_NET_UNITS  ][S_TRADES_SUM_DRAWDOWN] += history[i][H_DRAWDOWN_P ];
         stats[METRIC_TOTAL_NET_UNITS  ][S_TRADES_SUM_PROFIT  ] += history[i][H_NETPROFIT_P];

         stats[METRIC_TOTAL_SYNTH_UNITS][S_TRADES_SUM_RUNUP   ] += history[i][H_SYNTH_RUNUP_P   ];
         stats[METRIC_TOTAL_SYNTH_UNITS][S_TRADES_SUM_DRAWDOWN] += history[i][H_SYNTH_DRAWDOWN_P];
         stats[METRIC_TOTAL_SYNTH_UNITS][S_TRADES_SUM_PROFIT  ] += history[i][H_SYNTH_PROFIT_P  ];

         // METRIC_TOTAL_NET_MONEY
         if (GT(history[i][H_NETPROFIT_P], 0.5*Point)) {          // compare against H_NETPROFIT_P to simplify scratch limits
            // winners
            stats[METRIC_TOTAL_NET_MONEY][S_WINNERS]++;
            if (history[i][H_TYPE] == OP_LONG) stats[METRIC_TOTAL_NET_MONEY][S_WINNERS_LONG ]++;
            else                               stats[METRIC_TOTAL_NET_MONEY][S_WINNERS_SHORT]++;
            stats[METRIC_TOTAL_NET_MONEY][S_WINNERS_SUM_RUNUP   ] += history[i][H_RUNUP_P   ];
            stats[METRIC_TOTAL_NET_MONEY][S_WINNERS_SUM_DRAWDOWN] += history[i][H_DRAWDOWN_P];
            stats[METRIC_TOTAL_NET_MONEY][S_WINNERS_SUM_PROFIT  ] += history[i][H_NETPROFIT ];
         }
         else if (LT(history[i][H_NETPROFIT_P], -0.5*Point)) {
            // losers
            stats[METRIC_TOTAL_NET_MONEY][S_LOSERS]++;
            if (history[i][H_TYPE] == OP_LONG) stats[METRIC_TOTAL_NET_MONEY][S_LOSERS_LONG ]++;
            else                               stats[METRIC_TOTAL_NET_MONEY][S_LOSERS_SHORT]++;
            stats[METRIC_TOTAL_NET_MONEY][S_LOSERS_SUM_RUNUP   ] += history[i][H_RUNUP_P   ];
            stats[METRIC_TOTAL_NET_MONEY][S_LOSERS_SUM_DRAWDOWN] += history[i][H_DRAWDOWN_P];
            stats[METRIC_TOTAL_NET_MONEY][S_LOSERS_SUM_PROFIT  ] += history[i][H_NETPROFIT ];
         }
         else {
            // scratch
            stats[METRIC_TOTAL_NET_MONEY][S_SCRATCH]++;
            if (history[i][H_TYPE] == OP_LONG) stats[METRIC_TOTAL_NET_MONEY][S_SCRATCH_LONG ]++;
            else                               stats[METRIC_TOTAL_NET_MONEY][S_SCRATCH_SHORT]++;
         }

         // METRIC_TOTAL_NET_UNITS
         if (GT(history[i][H_NETPROFIT_P], 0.5*Point)) {
            // winners
            stats[METRIC_TOTAL_NET_UNITS][S_WINNERS]++;
            if (history[i][H_TYPE] == OP_LONG) stats[METRIC_TOTAL_NET_UNITS][S_WINNERS_LONG ]++;
            else                               stats[METRIC_TOTAL_NET_UNITS][S_WINNERS_SHORT]++;
            stats[METRIC_TOTAL_NET_UNITS][S_WINNERS_SUM_RUNUP   ] += history[i][H_RUNUP_P    ];
            stats[METRIC_TOTAL_NET_UNITS][S_WINNERS_SUM_DRAWDOWN] += history[i][H_DRAWDOWN_P ];
            stats[METRIC_TOTAL_NET_UNITS][S_WINNERS_SUM_PROFIT  ] += history[i][H_NETPROFIT_P];
         }
         else if (LT(history[i][H_NETPROFIT_P], -0.5*Point)) {
            // losers
            stats[METRIC_TOTAL_NET_UNITS][S_LOSERS]++;
            if (history[i][H_TYPE] == OP_LONG) stats[METRIC_TOTAL_NET_UNITS][S_LOSERS_LONG ]++;
            else                               stats[METRIC_TOTAL_NET_UNITS][S_LOSERS_SHORT]++;
            stats[METRIC_TOTAL_NET_UNITS][S_LOSERS_SUM_RUNUP   ] += history[i][H_RUNUP_P    ];
            stats[METRIC_TOTAL_NET_UNITS][S_LOSERS_SUM_DRAWDOWN] += history[i][H_DRAWDOWN_P ];
            stats[METRIC_TOTAL_NET_UNITS][S_LOSERS_SUM_PROFIT  ] += history[i][H_NETPROFIT_P];
         }
         else {
            // scratch
            stats[METRIC_TOTAL_NET_UNITS][S_SCRATCH]++;
            if (history[i][H_TYPE] == OP_LONG) stats[METRIC_TOTAL_NET_UNITS][S_SCRATCH_LONG ]++;
            else                               stats[METRIC_TOTAL_NET_UNITS][S_SCRATCH_SHORT]++;
         }

         // METRIC_TOTAL_SYNTH_UNITS
         if (GT(history[i][H_SYNTH_PROFIT_P], 0.5*Point)) {
            // winners
            stats[METRIC_TOTAL_SYNTH_UNITS][S_WINNERS]++;
            if (history[i][H_TYPE] == OP_LONG) stats[METRIC_TOTAL_SYNTH_UNITS][S_WINNERS_LONG ]++;
            else                               stats[METRIC_TOTAL_SYNTH_UNITS][S_WINNERS_SHORT]++;
            stats[METRIC_TOTAL_SYNTH_UNITS][S_WINNERS_SUM_RUNUP   ] += history[i][H_SYNTH_RUNUP_P   ];
            stats[METRIC_TOTAL_SYNTH_UNITS][S_WINNERS_SUM_DRAWDOWN] += history[i][H_SYNTH_DRAWDOWN_P];
            stats[METRIC_TOTAL_SYNTH_UNITS][S_WINNERS_SUM_PROFIT  ] += history[i][H_SYNTH_PROFIT_P  ];
         }
         else if (LT(history[i][H_SYNTH_PROFIT_P], -0.5*Point)) {
            // losers
            stats[METRIC_TOTAL_SYNTH_UNITS][S_LOSERS]++;
            if (history[i][H_TYPE] == OP_LONG) stats[METRIC_TOTAL_SYNTH_UNITS][S_LOSERS_LONG ]++;
            else                               stats[METRIC_TOTAL_SYNTH_UNITS][S_LOSERS_SHORT]++;
            stats[METRIC_TOTAL_SYNTH_UNITS][S_LOSERS_SUM_RUNUP   ] += history[i][H_SYNTH_RUNUP_P   ];
            stats[METRIC_TOTAL_SYNTH_UNITS][S_LOSERS_SUM_DRAWDOWN] += history[i][H_SYNTH_DRAWDOWN_P];
            stats[METRIC_TOTAL_SYNTH_UNITS][S_LOSERS_SUM_PROFIT  ] += history[i][H_SYNTH_PROFIT_P  ];
         }
         else {
            // scratch
            stats[METRIC_TOTAL_SYNTH_UNITS][S_SCRATCH]++;
            if (history[i][H_TYPE] == OP_LONG) stats[METRIC_TOTAL_SYNTH_UNITS][S_SCRATCH_LONG ]++;
            else                               stats[METRIC_TOTAL_SYNTH_UNITS][S_SCRATCH_SHORT]++;
         }
      }

      // total number of trades, percentages and averages
      for (i=ArrayRange(stats, 0)-1; i > 0; i--) {                // skip unused index 0
         stats[i][S_TRADES] = trades;

         stats[i][S_TRADES_LONG_PCT     ] = MathDiv(stats[i][S_TRADES_LONG         ], stats[i][S_TRADES ]);
         stats[i][S_TRADES_SHORT_PCT    ] = MathDiv(stats[i][S_TRADES_SHORT        ], stats[i][S_TRADES ]);
         stats[i][S_WINNERS_PCT         ] = MathDiv(stats[i][S_WINNERS             ], stats[i][S_TRADES ]);
         stats[i][S_WINNERS_LONG_PCT    ] = MathDiv(stats[i][S_WINNERS_LONG        ], stats[i][S_WINNERS]);
         stats[i][S_WINNERS_SHORT_PCT   ] = MathDiv(stats[i][S_WINNERS_SHORT       ], stats[i][S_WINNERS]);
         stats[i][S_LOSERS_PCT          ] = MathDiv(stats[i][S_LOSERS              ], stats[i][S_TRADES ]);
         stats[i][S_LOSERS_LONG_PCT     ] = MathDiv(stats[i][S_LOSERS_LONG         ], stats[i][S_LOSERS ]);
         stats[i][S_LOSERS_SHORT_PCT    ] = MathDiv(stats[i][S_LOSERS_SHORT        ], stats[i][S_LOSERS ]);
         stats[i][S_SCRATCH_PCT         ] = MathDiv(stats[i][S_SCRATCH             ], stats[i][S_TRADES ]);
         stats[i][S_SCRATCH_LONG_PCT    ] = MathDiv(stats[i][S_SCRATCH_LONG        ], stats[i][S_SCRATCH]);
         stats[i][S_SCRATCH_SHORT_PCT   ] = MathDiv(stats[i][S_SCRATCH_SHORT       ], stats[i][S_SCRATCH]);

         stats[i][S_TRADES_AVG_RUNUP    ] = MathDiv(stats[i][S_TRADES_SUM_RUNUP    ], stats[i][S_TRADES ]);
         stats[i][S_TRADES_AVG_DRAWDOWN ] = MathDiv(stats[i][S_TRADES_SUM_DRAWDOWN ], stats[i][S_TRADES ]);
         stats[i][S_TRADES_AVG_PROFIT   ] = MathDiv(stats[i][S_TRADES_SUM_PROFIT   ], stats[i][S_TRADES ]);

         stats[i][S_WINNERS_AVG_RUNUP   ] = MathDiv(stats[i][S_WINNERS_SUM_RUNUP   ], stats[i][S_WINNERS]);
         stats[i][S_WINNERS_AVG_DRAWDOWN] = MathDiv(stats[i][S_WINNERS_SUM_DRAWDOWN], stats[i][S_WINNERS]);
         stats[i][S_WINNERS_AVG_PROFIT  ] = MathDiv(stats[i][S_WINNERS_SUM_PROFIT  ], stats[i][S_WINNERS]);

         stats[i][S_LOSERS_AVG_RUNUP    ] = MathDiv(stats[i][S_LOSERS_SUM_RUNUP    ], stats[i][S_LOSERS ]);
         stats[i][S_LOSERS_AVG_DRAWDOWN ] = MathDiv(stats[i][S_LOSERS_SUM_DRAWDOWN ], stats[i][S_LOSERS ]);
         stats[i][S_LOSERS_AVG_PROFIT   ] = MathDiv(stats[i][S_LOSERS_SUM_PROFIT   ], stats[i][S_LOSERS ]);
      }
   }
}
