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
   instance.openNetProfit      = GetIniDouble(file, section, "openProfit"  );                   // double openProfit   = 23.45
   instance.closedNetProfit    = GetIniDouble(file, section, "closedProfit");                   // double closedProfit = 45.67
   instance.totalNetProfit     = GetIniDouble(file, section, "totalProfit" );                   // double totalProfit  = 123.45
   instance.maxNetDrawdown     = GetIniDouble(file, section, "minProfit"   );                   // double minProfit    = -11.23
   instance.maxNetProfit       = GetIniDouble(file, section, "maxProfit"   );                   // double maxProfit    = 23.45

   // [Stats: net in punits]
   section = "Stats: net in "+ pUnit;
   instance.openNetProfitP     = GetIniDouble(file, section, "openProfit"  )/pMultiplier;       // double openProfit   = 1234.5
   instance.closedNetProfitP   = GetIniDouble(file, section, "closedProfit")/pMultiplier;       // double closedProfit = -2345.6
   instance.totalNetProfitP    = GetIniDouble(file, section, "totalProfit" )/pMultiplier;       // double totalProfit  = 12345.6
   instance.maxNetDrawdownP    = GetIniDouble(file, section, "minProfit"   )/pMultiplier;       // double minProfit    = -2345.6
   instance.maxNetProfitP      = GetIniDouble(file, section, "maxProfit"   )/pMultiplier;       // double maxProfit    = 1234.5

   // [Stats: synthetic in punits]
   section = "Stats: synthetic in "+ pUnit;
   instance.openSynthProfitP   = GetIniDouble(file, section, "openProfit"  )/pMultiplier;       // double openProfit   = 1234.5
   instance.closedSynthProfitP = GetIniDouble(file, section, "closedProfit")/pMultiplier;       // double closedProfit = -2345.6
   instance.totalSynthProfitP  = GetIniDouble(file, section, "totalProfit" )/pMultiplier;       // double totalProfit  = 12345.6
   instance.maxSynthDrawdownP  = GetIniDouble(file, section, "minProfit"   )/pMultiplier;       // double minProfit    = -2345.6
   instance.maxSynthProfitP    = GetIniDouble(file, section, "maxProfit"   )/pMultiplier;       // double maxProfit    = 1234.5

   return(!catch("ReadStatus.TradeStats(1)"));
}
