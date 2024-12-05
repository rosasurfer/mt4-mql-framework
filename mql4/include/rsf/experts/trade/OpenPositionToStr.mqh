/**
 * Return a string representation of an open position.
 *
 * @param  bool compact [optional] - whether to return the string in compact format suitable for SaveStatus() (default: no)
 *
 * @return string - string representation or an empty string in case of errors
 */
string OpenPositionToStr(bool compact = false) {
   compact = compact!=0;
   // result: ticket,fromTicket,toTicket,type,lots,part,openTime,openPrice,openPriceSig,stopLoss,takeProfit,slippageP,swapM,commissionM,grossProfitM,netProfitM,netProfitP,runupP,rundownP,sigProfitP,sigRunupP,sigRundownP

   string sValues[22], pUnitFormat="."+ pDigits +"+";

   if (compact) {
      sValues[ 0] = open.ticket;
      sValues[ 1] = open.fromTicket;
      sValues[ 2] = open.toTicket;
      sValues[ 3] = open.type;
      sValues[ 4] = NumberToStr(open.lots, ".+");
      sValues[ 5] = NumberToStr(open.part, ".1+");
      sValues[ 6] = open.time;
      sValues[ 7] = DoubleToStr(open.price, Digits);
      sValues[ 8] = ifString(!open.priceSig,     "0", DoubleToStr(open.priceSig, Digits));
      sValues[ 9] = ifString(!open.stopLoss,     "0", DoubleToStr(open.stopLoss, Digits));
      sValues[10] = ifString(!open.takeProfit,   "0", DoubleToStr(open.takeProfit, Digits));
      sValues[11] = ifString(!open.slippageP,    "0", DoubleToStr(open.slippageP, Digits));
      sValues[12] = ifString(!open.swapM,        "0", DoubleToStr(open.swapM, 2));
      sValues[13] = ifString(!open.commissionM,  "0", DoubleToStr(open.commissionM, 2));
      sValues[14] = ifString(!open.grossProfitM, "0", DoubleToStr(open.grossProfitM, 2));
      sValues[15] = ifString(!open.netProfitM,   "0", DoubleToStr(open.netProfitM, 2));
      sValues[16] = ifString(!open.netProfitP,   "0", NumberToStr(open.netProfitP, ".1+"));
      sValues[17] = ifString(!open.runupP,       "0", DoubleToStr(open.runupP, Digits));
      sValues[18] = ifString(!open.rundownP,     "0", DoubleToStr(open.rundownP, Digits));
      sValues[19] = ifString(!open.sigProfitP,   "0", NumberToStr(open.sigProfitP, ".1+"));
      sValues[20] = ifString(!open.sigRunupP,    "0", DoubleToStr(open.sigRunupP, Digits));
      sValues[21] = ifString(!open.sigRundownP,  "0", DoubleToStr(open.sigRundownP, Digits));
   }
   else {
      sValues[ 0] = "ticket="       + open.ticket;
      sValues[ 1] = "fromTicket="   + open.fromTicket;
      sValues[ 2] = "toTicket="     + open.toTicket;
      sValues[ 3] = "type="         + OperationTypeDescription(open.type);
      sValues[ 4] = "lots="         + NumberToStr(open.lots, ".+");
      sValues[ 5] = "part="         + NumberToStr(open.part, ".1+");
      sValues[ 6] = "openTime="     + ifString(!open.time, "0", TimeToStr(open.time, TIME_FULL));
      sValues[ 7] = "openPrice="    + NumberToStr(open.price, PriceFormat);
      sValues[ 8] = "openPriceSig=" + ifString(!open.priceSig,     "0", NumberToStr(open.priceSig,   PriceFormat));
      sValues[ 9] = "stopLoss="     + ifString(!open.stopLoss,     "0", NumberToStr(open.stopLoss,   PriceFormat));
      sValues[10] = "takeProfit="   + ifString(!open.takeProfit,   "0", NumberToStr(open.takeProfit, PriceFormat));
      sValues[11] = "slippageP="    + ifString(!open.slippageP,    "0", NumberToStr(open.slippageP/pUnit, pUnitFormat));
      sValues[12] = "swapM="        + ifString(!open.swapM,        "0", DoubleToStr(open.swapM,        2));
      sValues[13] = "commissionM="  + ifString(!open.commissionM,  "0", DoubleToStr(open.commissionM,  2));
      sValues[14] = "grossProfitM=" + ifString(!open.grossProfitM, "0", DoubleToStr(open.grossProfitM, 2));
      sValues[15] = "netProfitM="   + ifString(!open.netProfitM,   "0", DoubleToStr(open.netProfitM,   2));
      sValues[16] = "netProfitP="   + ifString(!open.netProfitP,   "0", NumberToStr(open.netProfitP /pUnit, pUnitFormat));
      sValues[17] = "runupP="       + ifString(!open.runupP,       "0", DoubleToStr(open.runupP     /pUnit, pUnitFormat));
      sValues[18] = "rundownP="     + ifString(!open.rundownP,     "0", DoubleToStr(open.rundownP   /pUnit, pUnitFormat));
      sValues[19] = "sigProfitP="   + ifString(!open.sigProfitP,   "0", NumberToStr(open.sigProfitP /pUnit, pUnitFormat));
      sValues[20] = "sigRunupP="    + ifString(!open.sigRunupP,    "0", DoubleToStr(open.sigRunupP  /pUnit, pUnitFormat));
      sValues[21] = "sigRundownP="  + ifString(!open.sigRundownP,  "0", DoubleToStr(open.sigRundownP/pUnit, pUnitFormat));
   }

   return("{"+ JoinStrings(sValues) +"}");
}
