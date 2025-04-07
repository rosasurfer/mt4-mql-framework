/**
 * Read and restore StopLoss and TakeProfit targets from the status file.
 *
 * @param  string file - status filename
 *
 * @return bool - success status
 */
bool ReadStatus.Targets(string file) {
   string section = "Inputs";

   Initial.TakeProfit   = GetIniInt(file, section, "Initial.TakeProfit"  );      // int Initial.TakeProfit   = 100
   Initial.StopLoss     = GetIniInt(file, section, "Initial.StopLoss"    );      // int Initial.StopLoss     = 50
   Target1              = GetIniInt(file, section, "Target1"             );      // int Target1              = 0
   Target1.ClosePercent = GetIniInt(file, section, "Target1.ClosePercent");      // int Target1.ClosePercent = 0
   Target1.MoveStopTo   = GetIniInt(file, section, "Target1.MoveStopTo"  );      // int Target1.MoveStopTo   = 1
   Target2              = GetIniInt(file, section, "Target2"             );      // int Target2              = 20
   Target2.ClosePercent = GetIniInt(file, section, "Target2.ClosePercent");      // int Target2.ClosePercent = 30
   Target2.MoveStopTo   = GetIniInt(file, section, "Target2.MoveStopTo"  );      // int Target2.MoveStopTo   = 0
   Target3              = GetIniInt(file, section, "Target3"             );      // int Target3              = 40
   Target3.ClosePercent = GetIniInt(file, section, "Target3.ClosePercent");      // int Target3.ClosePercent = 30
   Target3.MoveStopTo   = GetIniInt(file, section, "Target3.MoveStopTo"  );      // int Target3.MoveStopTo   = 0
   Target4              = GetIniInt(file, section, "Target4"             );      // int Target4              = 60
   Target4.ClosePercent = GetIniInt(file, section, "Target4.ClosePercent");      // int Target4.ClosePercent = 30
   Target4.MoveStopTo   = GetIniInt(file, section, "Target4.MoveStopTo"  );      // int Target4.MoveStopTo   = 0

   return(!catch("ReadStatus.Targets(1)"));
}
