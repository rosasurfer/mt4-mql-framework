/**
 * ShowStatus: Update the string representation of the total instance PnL.
 *
 * @param  bool moneyInPercent [optional] - whether to display moneys in percent of instance start equity (default: no)
 */
void SS.TotalProfit(bool moneyInPercent = false) {
   // not before a position was opened
   if (!open.ticket && !ArrayRange(history, 0)) {
      sTotalProfit = "-";
   }
   else {
      switch (status.activeMetric) {
         case METRIC_TOTAL_NET_MONEY:
            if (moneyInPercent) sTotalProfit = NumberToStr(MathDiv(instance.totalNetProfit, instance.startEquity) * 100, "R+.2") +"%";
            else                sTotalProfit = NumberToStr(instance.totalNetProfit, "R+.2") +" "+ AccountCurrency();
            break;
         case METRIC_TOTAL_NET_UNITS:
            sTotalProfit = NumberToStr(instance.totalNetProfitP * pMultiplier, "R+."+ pDigits) +" "+ pUnit;
            break;
         case METRIC_TOTAL_SIG_UNITS:
            sTotalProfit = NumberToStr(instance.totalSigProfitP * pMultiplier, "R+."+ pDigits) +" "+ pUnit;
            break;

         default:
            return(!catch("SS.TotalProfit(1)  "+ instance.name +" illegal value of status.activeMetric: "+ status.activeMetric, ERR_ILLEGAL_STATE));
      }
   }
}
