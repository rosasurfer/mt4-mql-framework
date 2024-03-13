/**
 * Return a human-readable representation of an open position.
 *
 * @return string
 */
string OpenPositionDescr() {
   string sValues[22];

   sValues[ 0] = "ticket="      + open.ticket;
   sValues[ 1] = "fromTicket="  + open.fromTicket;
   sValues[ 2] = "toTicket="    + open.toTicket;
   sValues[ 3] = "type="        + OperationTypeDescription(open.type);
   sValues[ 4] = "lots="        + NumberToStr(open.lots, ".+");
   sValues[ 5] = "part="        + NumberToStr(open.part, ".1+");
   sValues[ 6] = "openTime="    +   ifString(!open.time, "0", TimeToStr(open.time, TIME_FULL));
   sValues[ 7] = "openPrice="   + NumberToStr(open.price, PriceFormat);
   sValues[ 8] = "openPriceSig="+   ifString(!open.priceSig,     "0", NumberToStr(open.priceSig,   PriceFormat));
   sValues[ 9] = "stopLoss="    +   ifString(!open.stopLoss,     "0", NumberToStr(open.stopLoss,   PriceFormat));
   sValues[10] = "takeProfit="  +   ifString(!open.takeProfit,   "0", NumberToStr(open.takeProfit, PriceFormat));
   sValues[11] = "slippage="    +   ifString(!open.slippage,     "0", NumberToStr(open.slippage,   PriceFormat));
   sValues[12] = "swap="        +   ifString(!open.swap,         "0", DoubleToStr(open.swap,        2));
   sValues[13] = "commission="  +   ifString(!open.commission,   "0", DoubleToStr(open.commission,  2));
   sValues[14] = "grossProfit=" +   ifString(!open.grossProfit,  "0", DoubleToStr(open.grossProfit, 2));
   sValues[15] = "netProfit="   +   ifString(!open.netProfit,    "0", DoubleToStr(open.netProfit,   2));
   sValues[16] = "netProfitP="  +   ifString(!open.netProfitP,   "0", NumberToStr(open.netProfitP, ".1+"));
   sValues[17] = "runupP="      +   ifString(!open.runupP,       "0", DoubleToStr(open.runupP,       Digits));
   sValues[18] = "drawdownP="   +   ifString(!open.drawdownP,    "0", DoubleToStr(open.drawdownP,    Digits));
   sValues[19] = "sigProfitP="  +   ifString(!open.sigProfitP,   "0", NumberToStr(open.sigProfitP,    ".1+"));
   sValues[20] = "sigRunupP="   +   ifString(!open.sigRunupP,    "0", DoubleToStr(open.sigRunupP,    Digits));
   sValues[21] = "sigDrawdownP="+   ifString(!open.sigDrawdownP, "0", DoubleToStr(open.sigDrawdownP, Digits));

   return("{"+ JoinStrings(sValues) +"}");
}
