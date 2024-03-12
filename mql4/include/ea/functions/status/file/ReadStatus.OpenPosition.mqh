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
   open.fromTicket   = GetIniInt   (file, section, "open.fromTicket"  );     // int      open.fromTicket   = 0
   open.toTicket     = GetIniInt   (file, section, "open.toTicket"    );     // int      open.toTicket     = 0
   open.type         = GetIniInt   (file, section, "open.type"        );     // int      open.type         = 1
   open.lots         = GetIniDouble(file, section, "open.lots"        );     // double   open.lots         = 0.01
   open.time         = GetIniInt   (file, section, "open.time"        );     // datetime open.time         = 1624924800 (Mon, 2021.05.12 13:22:34)
   open.price        = GetIniDouble(file, section, "open.price"       );     // double   open.price        = 1.24363
   open.priceSig     = GetIniDouble(file, section, "open.priceSig"    );     // double   open.priceSig     = 1.24363
   open.stopLoss     = GetIniDouble(file, section, "open.stopLoss"    );     // double   open.stopLoss     = 1.24363
   open.takeProfit   = GetIniDouble(file, section, "open.takeProfit"  );     // double   open.takeProfit   = 1.24363
   open.slippage     = GetIniDouble(file, section, "open.slippage"    );     // double   open.slippage     = 0.00002
   open.swap         = GetIniDouble(file, section, "open.swap"        );     // double   open.swap         = -1.23
   open.commission   = GetIniDouble(file, section, "open.commission"  );     // double   open.commission   = -5.50
   open.grossProfit  = GetIniDouble(file, section, "open.grossProfit" );     // double   open.grossProfit  = 12.34
   open.netProfit    = GetIniDouble(file, section, "open.netProfit"   );     // double   open.netProfit    = 12.56
   open.netProfitP   = GetIniDouble(file, section, "open.netProfitP"  );     // double   open.netProfitP   = 0.12345
   open.runupP       = GetIniDouble(file, section, "open.runupP"      );     // double   open.runupP       = 0.12345
   open.drawdownP    = GetIniDouble(file, section, "open.drawdownP"   );     // double   open.drawdownP    = 0.12345
   open.sigProfitP   = GetIniDouble(file, section, "open.sigProfitP"  );     // double   open.sigProfitP   = 0.12345
   open.sigRunupP    = GetIniDouble(file, section, "open.sigRunupP"   );     // double   open.sigRunupP    = 0.12345
   open.sigDrawdownP = GetIniDouble(file, section, "open.sigDrawdownP");     // double   open.sigDrawdownP = 0.12345

   return(!catch("ReadStatus.OpenPosition(1)"));
}
