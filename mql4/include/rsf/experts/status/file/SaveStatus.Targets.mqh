/**
 * Write input parameters for StopLoss and TakeProfit targets to the status file.
 *
 * @param  string file       - status filename
 * @param  bool   fileExists - whether the status file exists
 *
 * @return bool - success status
 */
bool SaveStatus.Targets(string file, bool fileExists) {
   fileExists = fileExists!=0;

   string separator = "";
   if (!fileExists) separator = CRLF;                    // an empty line separator

   string section = "Inputs";
   WriteIniString(file, section, "Initial.TakeProfit",   /*int*/ Initial.TakeProfit  );
   WriteIniString(file, section, "Initial.StopLoss",     /*int*/ Initial.StopLoss + separator);
   WriteIniString(file, section, "Target1",              /*int*/ Target1             );
   WriteIniString(file, section, "Target1.ClosePercent", /*int*/ Target1.ClosePercent);
   WriteIniString(file, section, "Target1.MoveStopTo",   /*int*/ Target1.MoveStopTo + separator);
   WriteIniString(file, section, "Target2",              /*int*/ Target2             );
   WriteIniString(file, section, "Target2.ClosePercent", /*int*/ Target2.ClosePercent);
   WriteIniString(file, section, "Target2.MoveStopTo",   /*int*/ Target2.MoveStopTo + separator);
   WriteIniString(file, section, "Target3",              /*int*/ Target3             );
   WriteIniString(file, section, "Target3.ClosePercent", /*int*/ Target3.ClosePercent);
   WriteIniString(file, section, "Target3.MoveStopTo",   /*int*/ Target3.MoveStopTo + separator);
   WriteIniString(file, section, "Target4",              /*int*/ Target4             );
   WriteIniString(file, section, "Target4.ClosePercent", /*int*/ Target4.ClosePercent);
   WriteIniString(file, section, "Target4.MoveStopTo",   /*int*/ Target4.MoveStopTo + separator);

   return(!catch("SaveStatus.Targets(1)"));
}
