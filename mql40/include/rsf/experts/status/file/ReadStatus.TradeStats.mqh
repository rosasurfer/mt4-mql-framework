/**
 * Read and restore trade statistics from the status file.
 *
 * @param  string file - status filename
 *
 * @return bool - success status
 */
bool ReadStatus.TradeStats(string file) {
   ArrayInitialize(stats, 0);

   // [Stats: net in money]
   string section = "Stats: net in money";
   stats[METRIC_NET_MONEY][S_OPEN_PROFIT     ] = GetIniDouble(file, section, "OpenProfit"    );             // double openProfit     = 23.45
   stats[METRIC_NET_MONEY][S_CLOSED_PROFIT   ] = GetIniDouble(file, section, "ClosedProfit"  );             // double closedProfit   = 45.67
   stats[METRIC_NET_MONEY][S_TOTAL_PROFIT    ] = GetIniDouble(file, section, "TotalProfit"   );             // double totalProfit    = 123.45
   stats[METRIC_NET_MONEY][S_MAX_PROFIT      ] = GetIniDouble(file, section, "MaxProfit"     );             // double maxProfit      = 23.45
   stats[METRIC_NET_MONEY][S_MAX_ABS_DRAWDOWN] = GetIniDouble(file, section, "MaxAbsDrawdown");             // double maxAbsDrawdown = -11.23
   stats[METRIC_NET_MONEY][S_MAX_REL_DRAWDOWN] = GetIniDouble(file, section, "MaxRelDrawdown");             // double maxRelDrawdown = -11.23

   // [Stats: net in punits]
   section = "Stats: net in "+ spUnit;
   stats[METRIC_NET_UNITS][S_OPEN_PROFIT     ] = GetIniDouble(file, section, "OpenProfit"    ) * pUnit;     // double openProfit     = 1234.5
   stats[METRIC_NET_UNITS][S_CLOSED_PROFIT   ] = GetIniDouble(file, section, "ClosedProfit"  ) * pUnit;     // double closedProfit   = -2345.6
   stats[METRIC_NET_UNITS][S_TOTAL_PROFIT    ] = GetIniDouble(file, section, "TotalProfit"   ) * pUnit;     // double totalProfit    = 12345.6
   stats[METRIC_NET_UNITS][S_MAX_PROFIT      ] = GetIniDouble(file, section, "MaxProfit"     ) * pUnit;     // double maxProfit      = 1234.5
   stats[METRIC_NET_UNITS][S_MAX_ABS_DRAWDOWN] = GetIniDouble(file, section, "MaxAbsDrawdown") * pUnit;     // double maxAbsDrawdown = -2345.6
   stats[METRIC_NET_UNITS][S_MAX_REL_DRAWDOWN] = GetIniDouble(file, section, "MaxRelDrawdown") * pUnit;     // double maxRelDrawdown = -2345.6

   // [Stats: signal in punits]
   section = "Stats: signal in "+ spUnit;
   stats[METRIC_SIG_UNITS][S_OPEN_PROFIT     ] = GetIniDouble(file, section, "OpenProfit"    ) * pUnit;     // double openProfit     = 1234.5
   stats[METRIC_SIG_UNITS][S_CLOSED_PROFIT   ] = GetIniDouble(file, section, "ClosedProfit"  ) * pUnit;     // double closedProfit   = -2345.6
   stats[METRIC_SIG_UNITS][S_TOTAL_PROFIT    ] = GetIniDouble(file, section, "TotalProfit"   ) * pUnit;     // double totalProfit    = 12345.6
   stats[METRIC_SIG_UNITS][S_MAX_PROFIT      ] = GetIniDouble(file, section, "MaxProfit"     ) * pUnit;     // double maxProfit      = 1234.5
   stats[METRIC_SIG_UNITS][S_MAX_ABS_DRAWDOWN] = GetIniDouble(file, section, "MaxAbsDrawdown") * pUnit;     // double maxAbsDrawdown = -2345.6
   stats[METRIC_SIG_UNITS][S_MAX_REL_DRAWDOWN] = GetIniDouble(file, section, "MaxRelDrawdown") * pUnit;     // double maxRelDrawdown = -2345.6

   if (CalculateStats())
      return(!catch("ReadStatus.TradeStats(1)"));
   return(false);
}
