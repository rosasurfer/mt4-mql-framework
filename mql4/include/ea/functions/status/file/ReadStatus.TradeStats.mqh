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
   instance.openNetProfit    = GetIniDouble(file, section, "openProfit"  );                     // double openProfit   = 23.45
   instance.closedNetProfit  = GetIniDouble(file, section, "closedProfit");                     // double closedProfit = 45.67
   instance.totalNetProfit   = GetIniDouble(file, section, "totalProfit" );                     // double totalProfit  = 123.45
   instance.maxNetProfit     = GetIniDouble(file, section, "maxProfit"   );                     // double maxProfit    = 23.45
   instance.maxNetDrawdown   = GetIniDouble(file, section, "maxDrawdown" );                     // double maxDrawdown  = -11.23

   // [Stats: net in punits]
   section = "Stats: net in "+ spUnit;
   instance.openNetProfitP   = GetIniDouble(file, section, "openProfit"  ) * pUnit;             // double openProfit   = 1234.5
   instance.closedNetProfitP = GetIniDouble(file, section, "closedProfit") * pUnit;             // double closedProfit = -2345.6
   instance.totalNetProfitP  = GetIniDouble(file, section, "totalProfit" ) * pUnit;             // double totalProfit  = 12345.6
   instance.maxNetProfitP    = GetIniDouble(file, section, "maxProfit"   ) * pUnit;             // double maxProfit    = 1234.5
   instance.maxNetDrawdownP  = GetIniDouble(file, section, "maxDrawdown" ) * pUnit;             // double maxDrawdown  = -2345.6

   // [Stats: signal in punits]
   section = "Stats: signal in "+ spUnit;
   instance.openSigProfitP   = GetIniDouble(file, section, "openProfit"  ) * pUnit;             // double openProfit   = 1234.5
   instance.closedSigProfitP = GetIniDouble(file, section, "closedProfit") * pUnit;             // double closedProfit = -2345.6
   instance.totalSigProfitP  = GetIniDouble(file, section, "totalProfit" ) * pUnit;             // double totalProfit  = 12345.6
   instance.maxSigProfitP    = GetIniDouble(file, section, "maxProfit"   ) * pUnit;             // double maxProfit    = 1234.5
   instance.maxSigDrawdownP  = GetIniDouble(file, section, "maxDrawdown" ) * pUnit;             // double maxDrawdown  = -2345.6

   return(!catch("ReadStatus.TradeStats(1)"));
}
