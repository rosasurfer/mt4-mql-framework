/**
 * Read and restore trade statistics from the status file.
 *
 * @param  string file - status filename
 *
 * @return bool - success status
 */
bool ReadStatus.TradeStats(string file) {
   // [Stats: net in money]
   string section = "Stats: net in money";
   stats.openNetProfit      = GetIniDouble(file, section, "OpenProfit"    );              // double openProfit     = 23.45
   stats.closedNetProfit    = GetIniDouble(file, section, "ClosedProfit"  );              // double closedProfit   = 45.67
   stats.totalNetProfit     = GetIniDouble(file, section, "TotalProfit"   );              // double totalProfit    = 123.45
   stats.maxNetProfit       = GetIniDouble(file, section, "MaxProfit"     );              // double maxProfit      = 23.45
   stats.maxNetAbsDrawdown  = GetIniDouble(file, section, "MaxAbsDrawdown");              // double maxAbsDrawdown = -11.23
   stats.maxNetRelDrawdown  = GetIniDouble(file, section, "MaxRelDrawdown");              // double maxRelDrawdown = -11.23

   // [Stats: net in punits]
   section = "Stats: net in "+ spUnit;
   stats.openNetProfitP     = GetIniDouble(file, section, "OpenProfit"    ) * pUnit;      // double openProfit     = 1234.5
   stats.closedNetProfitP   = GetIniDouble(file, section, "ClosedProfit"  ) * pUnit;      // double closedProfit   = -2345.6
   stats.totalNetProfitP    = GetIniDouble(file, section, "TotalProfit"   ) * pUnit;      // double totalProfit    = 12345.6
   stats.maxNetProfitP      = GetIniDouble(file, section, "MaxProfit"     ) * pUnit;      // double maxProfit      = 1234.5
   stats.maxNetAbsDrawdownP = GetIniDouble(file, section, "MaxAbsDrawdown") * pUnit;      // double maxAbsDrawdown = -2345.6
   stats.maxNetRelDrawdownP = GetIniDouble(file, section, "MaxRelDrawdown") * pUnit;      // double maxRelDrawdown = -2345.6

   // [Stats: signal in punits]
   section = "Stats: signal in "+ spUnit;
   stats.openSigProfitP     = GetIniDouble(file, section, "OpenProfit"    ) * pUnit;      // double openProfit     = 1234.5
   stats.closedSigProfitP   = GetIniDouble(file, section, "ClosedProfit"  ) * pUnit;      // double closedProfit   = -2345.6
   stats.totalSigProfitP    = GetIniDouble(file, section, "TotalProfit"   ) * pUnit;      // double totalProfit    = 12345.6
   stats.maxSigProfitP      = GetIniDouble(file, section, "MaxProfit"     ) * pUnit;      // double maxProfit      = 1234.5
   stats.maxSigAbsDrawdownP = GetIniDouble(file, section, "MaxAbsDrawdown") * pUnit;      // double maxAbsDrawdown = -2345.6
   stats.maxSigRelDrawdownP = GetIniDouble(file, section, "MaxRelDrawdown") * pUnit;      // double maxRelDrawdown = -2345.6

   return(!catch("ReadStatus.TradeStats(1)"));
}
