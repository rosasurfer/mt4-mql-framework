/**
 * Return a human-readable representation of an open position.
 *
 * @return string
 */
string OpenPositionDescr() {
   string sValues[22];

   sValues[ 0] = "ticket="       + open.ticket;
   sValues[ 1] = "fromTicket="   + open.fromTicket;
   sValues[ 2] = "toTicket="     + open.toTicket;
   sValues[ 3] = "type="         + OperationTypeDescription(open.type);
   sValues[ 4] = "lots="         + NumberToStr(open.lots, ".+");
   sValues[ 5] = "part="         + NumberToStr(open.part, ".1+");
   sValues[ 6] = "openTime="     +   ifString(!open.time, "0", TimeToStr(open.time, TIME_FULL));
   sValues[ 7] = "openPrice="    + NumberToStr(open.price, PriceFormat);
   sValues[ 8] = "openPriceSig=" +   ifString(!open.priceSig,     "0", NumberToStr(open.priceSig,   PriceFormat));
   sValues[ 9] = "stopLoss="     +   ifString(!open.stopLoss,     "0", NumberToStr(open.stopLoss,   PriceFormat));
   sValues[10] = "takeProfit="   +   ifString(!open.takeProfit,   "0", NumberToStr(open.takeProfit, PriceFormat));
   sValues[11] = "slippageP="    +   ifString(!open.slippageP,    "0", NumberToStr(open.slippageP,  PriceFormat));
   sValues[12] = "swapM="        +   ifString(!open.swapM,        "0", DoubleToStr(open.swapM,        2));
   sValues[13] = "commissionM="  +   ifString(!open.commissionM,  "0", DoubleToStr(open.commissionM,  2));
   sValues[14] = "grossProfitM=" +   ifString(!open.grossProfitM, "0", DoubleToStr(open.grossProfitM, 2));
   sValues[15] = "netProfitM="   +   ifString(!open.netProfitM,   "0", DoubleToStr(open.netProfitM,   2));
   sValues[16] = "netProfitP="   +   ifString(!open.netProfitP,   "0", NumberToStr(open.netProfitP, "."+ Digits +"+"));
   sValues[17] = "runupP="       +   ifString(!open.runupP,       "0", DoubleToStr(open.runupP,      Digits));
   sValues[18] = "rundownP="     +   ifString(!open.rundownP,     "0", DoubleToStr(open.rundownP,    Digits));
   sValues[19] = "sigProfitP="   +   ifString(!open.sigProfitP,   "0", NumberToStr(open.sigProfitP, "."+ Digits +"+"));
   sValues[20] = "sigRunupP="    +   ifString(!open.sigRunupP,    "0", DoubleToStr(open.sigRunupP,   Digits));
   sValues[21] = "sigRundownP="  +   ifString(!open.sigRundownP,  "0", DoubleToStr(open.sigRundownP, Digits));

   return("{"+ JoinStrings(sValues) +"}");
}
