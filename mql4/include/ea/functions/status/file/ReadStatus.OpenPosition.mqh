/**
 * Read and restore open position data from the status file.
 *
 * @param  string file - status filename
 *
 * @return bool - success status
 */
bool ReadStatus.OpenPosition(string file) {

   string section = "Open positions";
   open.ticket       = GetIniInt   (file, section, "open.ticket"      );     // int      open.ticket       = 123456
   open.fromTicket   = GetIniInt   (file, section, "open.fromTicket"  );     // int      open.fromTicket   = 123457
   open.toTicket     = GetIniInt   (file, section, "open.toTicket"    );     // int      open.toTicket     = 0
   open.type         = GetIniInt   (file, section, "open.type"        );     // int      open.type         = 1
   open.lots         = GetIniDouble(file, section, "open.lots"        );     // double   open.lots         = 0.01
   open.part         = GetIniDouble(file, section, "open.part",      1);     // double   open.part         = 0.33333333
   open.time         = GetIniInt   (file, section, "open.time"        );     // datetime open.time         = 1624924800 (Mon, 2021.05.12 13:22:34)
   open.price        = GetIniDouble(file, section, "open.price"       );     // double   open.price        = 1.24363
   open.priceSig     = GetIniDouble(file, section, "open.priceSig"    );     // double   open.priceSig     = 1.24363
   open.stopLoss     = GetIniDouble(file, section, "open.stopLoss"    );     // double   open.stopLoss     = 1.24363
   open.takeProfit   = GetIniDouble(file, section, "open.takeProfit"  );     // double   open.takeProfit   = 1.24363
   open.slippageP    = GetIniDouble(file, section, "open.slippageP"   );     // double   open.slippageP    = 0.00002
   open.swapM        = GetIniDouble(file, section, "open.swapM"       );     // double   open.swapM        = -1.23
   open.commissionM  = GetIniDouble(file, section, "open.commissionM" );     // double   open.commissionM  = -5.50
   open.grossProfitM = GetIniDouble(file, section, "open.grossProfitM");     // double   open.grossProfitM = 12.34
   open.netProfitM   = GetIniDouble(file, section, "open.netProfitM"  );     // double   open.netProfitM   = 12.56
   open.netProfitP   = GetIniDouble(file, section, "open.netProfitP"  );     // double   open.netProfitP   = 0.12345
   open.runupP       = GetIniDouble(file, section, "open.runupP"      );     // double   open.runupP       = 0.12345
   open.rundownP     = GetIniDouble(file, section, "open.rundownP"    );     // double   open.rundownP     = 0.12345
   open.sigProfitP   = GetIniDouble(file, section, "open.sigProfitP"  );     // double   open.sigProfitP   = 0.12345
   open.sigRunupP    = GetIniDouble(file, section, "open.sigRunupP"   );     // double   open.sigRunupP    = 0.12345
   open.sigRundownP  = GetIniDouble(file, section, "open.sigRundownP" );     // double   open.sigRundownP  = 0.12345

   return(!catch("ReadStatus.OpenPosition(1)"));
}
