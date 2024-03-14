/**
 * Write open position data to the status file.
 *
 * @param  string file       - status filename
 * @param  bool   fileExists - whether the status file exists
 *
 * @return bool - success status
 */
bool SaveStatus.OpenPosition(string file, bool fileExists) {
   fileExists = fileExists!=0;

   string separator = "";
   if (!fileExists) separator = CRLF;                 // an empty line separator

   string section = "Open positions";
   WriteIniString(file, section, "open.ticket",       /*int     */ open.ticket);
   WriteIniString(file, section, "open.fromTicket",   /*int     */ open.fromTicket);
   WriteIniString(file, section, "open.toTicket",     /*int     */ open.toTicket);
   WriteIniString(file, section, "open.type",         /*int     */ open.type);
   WriteIniString(file, section, "open.lots",         /*double  */ NumberToStr(open.lots, ".+"));
   WriteIniString(file, section, "open.part",         /*double  */ NumberToStr(open.part, ".+"));
   WriteIniString(file, section, "open.time",         /*datetime*/ open.time + ifString(open.time, GmtTimeFormat(open.time, " (%a, %Y.%m.%d %H:%M:%S)"), ""));
   WriteIniString(file, section, "open.price",        /*double  */ DoubleToStr(open.price, Digits));
   WriteIniString(file, section, "open.priceSig",     /*double  */ DoubleToStr(open.priceSig, Digits));
   WriteIniString(file, section, "open.stopLoss",     /*double  */ DoubleToStr(open.stopLoss, Digits));
   WriteIniString(file, section, "open.takeProfit",   /*double  */ DoubleToStr(open.takeProfit, Digits));
   WriteIniString(file, section, "open.slippageP",    /*double  */ DoubleToStr(open.slippageP, Digits));
   WriteIniString(file, section, "open.swapM",        /*double  */ DoubleToStr(open.swapM, 2));
   WriteIniString(file, section, "open.commissionM",  /*double  */ DoubleToStr(open.commissionM, 2));
   WriteIniString(file, section, "open.grossProfitM", /*double  */ DoubleToStr(open.grossProfitM, 2));
   WriteIniString(file, section, "open.netProfitM",   /*double  */ DoubleToStr(open.netProfitM, 2));
   WriteIniString(file, section, "open.netProfitP",   /*double  */ NumberToStr(open.netProfitP, "."+ Digits +"+"));
   WriteIniString(file, section, "open.runupP",       /*double  */ DoubleToStr(open.runupP, Digits));
   WriteIniString(file, section, "open.rundownP",     /*double  */ DoubleToStr(open.rundownP, Digits));
   WriteIniString(file, section, "open.sigProfitP",   /*double  */ NumberToStr(open.sigProfitP, "."+ Digits +"+"));
   WriteIniString(file, section, "open.sigRunupP",    /*double  */ DoubleToStr(open.sigRunupP, Digits));
   WriteIniString(file, section, "open.sigRundownP",  /*double  */ DoubleToStr(open.sigRundownP, Digits) + separator);

   return(!catch("SaveStatus.OpenPosition(1)"));
}
