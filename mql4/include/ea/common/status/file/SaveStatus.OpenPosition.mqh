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
   if (!fileExists) separator = CRLF;                   // an empty line separator

   string section = "Open positions";
   WriteIniString(file, section, "open.ticket",         /*int     */ open.ticket);
   WriteIniString(file, section, "open.type",           /*int     */ open.type);
   WriteIniString(file, section, "open.lots",           /*double  */ NumberToStr(open.lots, ".+"));
   WriteIniString(file, section, "open.time",           /*datetime*/ open.time + ifString(open.time, GmtTimeFormat(open.time, " (%a, %Y.%m.%d %H:%M:%S)"), ""));
   WriteIniString(file, section, "open.price",          /*double  */ DoubleToStr(open.price, Digits));
   WriteIniString(file, section, "open.priceSynth",     /*double  */ DoubleToStr(open.priceSynth, Digits));
   WriteIniString(file, section, "open.slippage",       /*double  */ DoubleToStr(open.slippage, Digits));
   WriteIniString(file, section, "open.swap",           /*double  */ DoubleToStr(open.swap, 2));
   WriteIniString(file, section, "open.commission",     /*double  */ DoubleToStr(open.commission, 2));
   WriteIniString(file, section, "open.grossProfit",    /*double  */ DoubleToStr(open.grossProfit, 2));
   WriteIniString(file, section, "open.netProfit",      /*double  */ DoubleToStr(open.netProfit, 2));
   WriteIniString(file, section, "open.netProfitP",     /*double  */ NumberToStr(open.netProfitP, ".1+"));
   WriteIniString(file, section, "open.runupP",         /*double  */ DoubleToStr(open.runupP, Digits));
   WriteIniString(file, section, "open.drawdownP",      /*double  */ DoubleToStr(open.drawdownP, Digits));
   WriteIniString(file, section, "open.synthProfitP",   /*double  */ DoubleToStr(open.synthProfitP, Digits));
   WriteIniString(file, section, "open.synthRunupP",    /*double  */ DoubleToStr(open.synthRunupP, Digits));
   WriteIniString(file, section, "open.synthDrawdownP", /*double  */ DoubleToStr(open.synthDrawdownP, Digits) + separator);

   return(!catch("SaveStatus.OpenPosition(1)"));
}
