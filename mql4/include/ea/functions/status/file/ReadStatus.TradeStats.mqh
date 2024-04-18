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
   instance.openNetProfit      = GetIniDouble(file, section, "OpenProfit"    );                 // double openProfit     = 23.45
   instance.closedNetProfit    = GetIniDouble(file, section, "ClosedProfit"  );                 // double closedProfit   = 45.67
   instance.totalNetProfit     = GetIniDouble(file, section, "TotalProfit"   );                 // double totalProfit    = 123.45
   instance.maxNetProfit       = GetIniDouble(file, section, "MaxProfit"     );                 // double maxProfit      = 23.45
   instance.maxNetAbsDrawdown  = GetIniDouble(file, section, "MaxAbsDrawdown");                 // double maxAbsDrawdown = -11.23
   instance.maxNetRelDrawdown  = GetIniDouble(file, section, "MaxRelDrawdown");                 // double maxRelDrawdown = -11.23

   // [Stats: net in punits]
   section = "Stats: net in "+ spUnit;
   instance.openNetProfitP     = GetIniDouble(file, section, "OpenProfit"    ) * pUnit;         // double openProfit     = 1234.5
   instance.closedNetProfitP   = GetIniDouble(file, section, "ClosedProfit"  ) * pUnit;         // double closedProfit   = -2345.6
   instance.totalNetProfitP    = GetIniDouble(file, section, "TotalProfit"   ) * pUnit;         // double totalProfit    = 12345.6
   instance.maxNetProfitP      = GetIniDouble(file, section, "MaxProfit"     ) * pUnit;         // double maxProfit      = 1234.5
   instance.maxNetAbsDrawdownP = GetIniDouble(file, section, "MaxAbsDrawdown") * pUnit;         // double maxAbsDrawdown = -2345.6
   instance.maxNetRelDrawdownP = GetIniDouble(file, section, "MaxRelDrawdown") * pUnit;         // double maxRelDrawdown = -2345.6

   // [Stats: signal in punits]
   section = "Stats: signal in "+ spUnit;
   instance.openSigProfitP     = GetIniDouble(file, section, "OpenProfit"    ) * pUnit;         // double openProfit     = 1234.5
   instance.closedSigProfitP   = GetIniDouble(file, section, "ClosedProfit"  ) * pUnit;         // double closedProfit   = -2345.6
   instance.totalSigProfitP    = GetIniDouble(file, section, "TotalProfit"   ) * pUnit;         // double totalProfit    = 12345.6
   instance.maxSigProfitP      = GetIniDouble(file, section, "MaxProfit"     ) * pUnit;         // double maxProfit      = 1234.5
   instance.maxSigAbsDrawdownP = GetIniDouble(file, section, "MaxAbsDrawdown") * pUnit;         // double maxAbsDrawdown = -2345.6
   instance.maxSigRelDrawdownP = GetIniDouble(file, section, "MaxRelDrawdown") * pUnit;         // double maxRelDrawdown = -2345.6

   return(!catch("ReadStatus.TradeStats(1)"));
}
